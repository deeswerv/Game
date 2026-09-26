--!strict
-- Heads turn to look where their player is looking.
--
-- Built from the "Realistic Head-Camera" script (bonjourdev): the head follows the camera
-- and the chest turns a little with it, eased so it drifts rather than snaps. That script
-- only ever moved your own head, on your own screen -- a joint moved on one client moves on
-- that client alone -- so here it is extended to everyone:
--
--   * your client works out where your head should point from your camera, poses it, and
--     sends the angles (a few times a second, only when they change) to HeadLookService;
--   * the server publishes them as each character's `HeadLook` attribute;
--   * every client eases every nearby head towards its published angles.
--
-- It fits the rest of the rig rather than fighting it:
--   * rest poses come from the locked StarterCharacter, never from the live joint;
--   * with a gun out, WeaponPoseHold owns the chest, so only the neck turns (and the arms are
--     already following the camera's pitch);
--   * while EmoteAnimator is posing a character, it owns every joint -- the head look stands
--     aside and comes back in smoothly afterwards;
--   * looking behind yourself fades the turn out instead of snapping it across at 180 degrees.
--
-- The Settings panel's HEAD FOLLOWS CAMERA scales how far (0% turns it off), for your head as
-- everyone else sees it too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local EmotePlayer = require(ReplicatedStorage:WaitForChild("EmotePlayer"))

local localPlayer = Players.LocalPlayer
local LookUpdate = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("LookUpdate") :: RemoteEvent

-- How far a head can go, in degrees, and how the turn is shared between chest and neck.
local MAX_YAW = 75
local MAX_PITCH = 45
local PITCH_FOLLOW = 0.75       -- of the camera's own pitch
local CHEST_YAW = 0.4           -- of the turn, when the chest is free to move
local CHEST_PITCH = 0.25
-- Past this much of a turn the camera is behind you; by FADE_TO the head faces front again.
local FADE_FROM, FADE_TO = 115, 150
local EASE = 10                 -- per second
local RANGE = 200               -- other players' heads, past this, are not worth posing

-- Sending: at most this often, and only when the look has moved this far.
local SEND_EVERY = 0.1
local SEND_STEP = 1.5
local SETTLE_AFTER = 0.5

-- ------------------------------------------------------------------ joints --

local rests: { [string]: CFrame }? = nil
-- If the locked rig cannot be read, a joint's C0 the first time it is seen stands in for rest.
local firstSeen: { [Motor6D]: CFrame } = setmetatable({}, { __mode = "k" }) :: any
local function restOf(partName: string, joint: Motor6D): CFrame
	if not rests then
		local out = {}
		local source = StarterPlayer:FindFirstChild("StarterCharacter")
		if source then
			for _, d in ipairs(source:GetDescendants()) do
				if d:IsA("Motor6D") and d.Part1 then
					out[d.Part1.Name] = d.C0
				end
			end
		end
		rests = out
	end
	local rest = (rests :: { [string]: CFrame })[partName]
	if rest then
		return rest
	end
	local seen = firstSeen[joint]
	if not seen then
		seen = joint.C0
		firstSeen[joint] = seen
	end
	return seen
end

-- By class AND name: this build also rigs R15 with AnimationConstraints named like the joints.
local function motor(parent: Instance?, name: string): Motor6D?
	if not parent then
		return nil
	end
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("Motor6D") and child.Name == name then
			return child
		end
	end
	return nil
end

type Look = { yaw: number, pitch: number, neck: Motor6D?, waist: Motor6D? }
local looks: { [Model]: Look } = setmetatable({}, { __mode = "k" }) :: any

local function lookFor(character: Model): Look
	local existing = looks[character]
	if existing and existing.neck and existing.neck.Parent then
		return existing
	end
	-- New, or the rig was rebuilt under it (a respawn keeps no joints).
	local fresh: Look = {
		yaw = existing and existing.yaw or 0,
		pitch = existing and existing.pitch or 0,
		neck = motor(character:FindFirstChild("Head"), "Neck"),
		waist = motor(character:FindFirstChild("UpperTorso"), "Waist"),
	}
	looks[character] = fresh
	return fresh
end

-- ------------------------------------------------------------ your own look --

--- Where your head should point, in degrees: yaw to the character's left, pitch up.
local function ownTarget(character: Model): (number, number)
	local strength = localPlayer:GetAttribute("HeadLookSetting")
	strength = typeof(strength) == "number" and math.clamp(strength, 0, 1) or 1
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local camera = workspace.CurrentCamera
	if strength <= 0 or not root or not camera then
		return 0, 0
	end
	-- The camera's direction in the body's own frame (the root's, which nothing here moves).
	local rel = root.CFrame:VectorToObjectSpace(camera.CFrame.LookVector)
	local yaw = math.deg(math.atan2(-rel.X, -rel.Z))
	local pitch = math.deg(math.asin(math.clamp(rel.Y, -1, 1)))
	local fade = 1 - math.clamp((math.abs(yaw) - FADE_FROM) / (FADE_TO - FADE_FROM), 0, 1)
	yaw = math.clamp(yaw, -MAX_YAW, MAX_YAW) * fade
	pitch = math.clamp(pitch * PITCH_FOLLOW, -MAX_PITCH, MAX_PITCH)
	return yaw * strength, pitch * strength
end

local lastSentYaw, lastSentPitch, lastSentAt = 0, 0, -math.huge

local function send(yaw: number, pitch: number)
	local now = os.clock()
	local moved = math.max(math.abs(yaw - lastSentYaw), math.abs(pitch - lastSentPitch))
	if moved < 0.5 or now - lastSentAt < SEND_EVERY then
		return
	end
	-- Small drifts wait to settle, so a still camera costs nothing.
	if moved < SEND_STEP and now - lastSentAt < SETTLE_AFTER then
		return
	end
	lastSentYaw, lastSentPitch, lastSentAt = yaw, pitch, now
	LookUpdate:FireServer(math.floor(yaw + 0.5), math.floor(pitch + 0.5))
end

-- --------------------------------------------------------------------- pose --

local function pose(character: Model, look: Look, yaw: number, pitch: number, dt: number)
	local alpha = 1 - math.exp(-EASE * dt)
	look.yaw += (yaw - look.yaw) * alpha
	look.pitch += (pitch - look.pitch) * alpha

	-- A gun out means WeaponPoseHold has the chest; the whole turn goes to the neck.
	local armed = character:GetAttribute("PoseRightC0") ~= nil
	local chestYaw = armed and 0 or look.yaw * CHEST_YAW
	local chestPitch = armed and 0 or look.pitch * CHEST_PITCH

	local neck = look.neck
	if neck then
		neck.C0 = restOf("Head", neck)
			* CFrame.fromEulerAnglesYXZ(math.rad(look.pitch - chestPitch), math.rad(look.yaw - chestYaw), 0)
	end
	local waist = look.waist
	if waist and not armed then
		waist.C0 = restOf("UpperTorso", waist) * CFrame.fromEulerAnglesYXZ(math.rad(chestPitch), math.rad(chestYaw), 0)
	end
end

local function busy(character: Model): boolean
	return EmotePlayer.Posing[character] == true or character:GetAttribute("Emote") ~= nil
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not character or not humanoid or humanoid.Health <= 0 then
			continue
		end
		local look = lookFor(character)
		if player == localPlayer then
			local yaw, pitch = ownTarget(character)
			send(yaw, pitch)
			if busy(character) then
				look.yaw, look.pitch = 0, 0
			else
				pose(character, look, yaw, pitch, dt)
			end
		else
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if not root or (root.Position - eye).Magnitude > RANGE then
				continue
			end
			if busy(character) then
				look.yaw, look.pitch = 0, 0
				continue
			end
			local published = character:GetAttribute("HeadLook")
			local yaw, pitch = 0, 0
			if typeof(published) == "Vector2" then
				yaw = math.clamp(published.X, -MAX_YAW, MAX_YAW)
				pitch = math.clamp(published.Y, -MAX_PITCH, MAX_PITCH)
			end
			pose(character, look, yaw, pitch, dt)
		end
	end
end

-- After WeaponPoseHold (Last), before EmoteAnimator (Last + 2).
RunService:BindToRenderStep("HeadLook", Enum.RenderPriority.Last.Value + 1, step)
