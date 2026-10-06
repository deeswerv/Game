--!strict
-- Every player's body -- and every NPC's, on the same Roblox Boy rig -- posed from how it is
-- moving: the game's own walk, run, sprint, crouch, jump, landing and roll
-- (ReplicatedStorage.Motion) in place of Roblox's default movement animations.
--
-- Nothing is replicated per frame, and nothing needs to be: every client already sees every
-- character's velocity and footing, and poses each one locally from them. The two things it
-- cannot see are replicated as character attributes by the server (MovementService):
-- Crouching, and RollAt/RollDir for a roll. The local player's own body reads ShiftLock's state
-- through Motion.Local instead, so its crouch and roll start the instant the key goes down.
--
-- How a joint is posed is the same as the emotes and the weapon hold: the default Animate
-- script owns Transform and writes it before this runs, so the pose goes in C0 with the
-- animation divided back out -- C0 = rest * Transform:Lerp(pose, cover) * Transform^-1. A
-- `cover` below one leaves that much of the default animation showing, which is how sitting,
-- climbing or an emote take over without a snap.
--
-- Bound just before WeaponPoseHold (Last), HeadLook (Last + 1) and EmoteAnimator (Last + 2).
-- With a gun out the weapon hold owns the arms and the chest, so they are left to it -- the
-- gait only hands it a chest offset (PoseLayers); the neck is always HeadLook's (an NPC's,
-- NPCAnimator's).
--
-- NPCs (workspace.NPCs) are posed the same way, nearer in, scaled to their size. NPCAnimator
-- still owns how they look around, flinch, recoil and swing: while we pose an NPC
-- (Motion.Posing) it publishes those as joint offsets (Motion.Offsets) and they go in under
-- the gait -- C0 = rest * offset * gait -- rather than one of us overwriting the other.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Motion = require(ReplicatedStorage:WaitForChild("Motion"))
local PoseLayers = require(ReplicatedStorage:WaitForChild("PoseLayers"))
local EmotePlayer = require(ReplicatedStorage:WaitForChild("EmotePlayer"))
local CombatFX = require(ReplicatedStorage:WaitForChild("CombatFX"))

local player = Players.LocalPlayer

-- Past this nobody can make out a gait, and each body is a dozen joint writes a frame.
local RANGE = 260
local NPC_RANGE = 150

-- Humanoid states in which the body is not on its feet or in a jump: the default animation
-- (a seat, a ladder, swimming, a ragdoll) is left to play.
local NOT_OURS: { [string]: boolean } = {
	Seated = true, Climbing = true, Swimming = true, Dead = true, Ragdoll = true, Physics = true,
	PlatformStanding = true, FallingDown = true, GettingUp = true,
}

type Joint = { motor: Motor6D, rest: CFrame, touched: boolean }
type Entry = {
	state: Motion.State,
	scale: number,
	joints: { [string]: Joint },
	grounded: boolean,
	fall: number,
	rollAt: number?,
	layered: boolean,          -- a chest offset is handed to the gun hold (PoseLayers)
}

local entries: { [Model]: Entry } = {}

-- Rest C0 of every joint on the locked rig, by the part it moves. From the StarterCharacter,
-- never the live joint, which this and other scripts are busy rewriting.
local restByPart: { [string]: CFrame }? = nil
local function restC0s(): { [string]: CFrame }
	if restByPart then
		return restByPart
	end
	local out = {}
	local source = StarterPlayer:FindFirstChild("StarterCharacter")
	if source then
		for _, d in ipairs(source:GetDescendants()) do
			if d:IsA("Motor6D") and d.Part1 then
				out[d.Part1.Name] = d.C0
			end
		end
	end
	restByPart = out
	return out
end

-- By class: this rig also carries AnimationConstraints with the Motor6Ds' names. A scaled
-- body (a big NPC) has its joints that much further apart.
local function jointsOf(character: Model, scale: number): { [string]: Joint }
	local rests = restC0s()
	local joints = {}
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part1 and d.Part1.Parent == character and d.Part1.Name ~= "Head" then
			local name = d.Part1.Name
			local rest = rests[name]
			if rest and scale ~= 1 then
				rest = rest.Rotation + rest.Position * scale
			end
			joints[name] = { motor = d, rest = rest or d.C0, touched = false }
		end
	end
	return joints
end

local function entryFor(character: Model): Entry
	local entry = entries[character]
	if entry then
		-- A respawn or a rebuilt rig leaves joints that are no longer in the character.
		local _, any = next(entry.joints)
		if not any or any.motor.Parent == nil or not any.motor:IsDescendantOf(character) then
			entry.joints = jointsOf(character, entry.scale)
		end
		return entry
	end
	local scale = character:GetScale()
	local created: Entry = { state = Motion.NewState(), scale = scale, joints = jointsOf(character, scale),
		grounded = true, fall = 0, rollAt = character:GetAttribute("RollAt") :: number?, layered = false }
	entries[character] = created
	return created
end

local function release(entry: Entry, character: Model)
	Motion.Posing[character] = nil
	if entry.layered then
		PoseLayers.Clear(character)
		entry.layered = false
	end
	for _, joint in pairs(entry.joints) do
		if joint.touched and joint.motor.Parent then
			joint.motor.C0 = joint.rest
		end
		joint.touched = false
		Motion.Waist[joint.motor] = nil
	end
end

local function emoting(character: Model): boolean
	return EmotePlayer.Posing[character] == true or character:GetAttribute("Emote") ~= nil
end

local function animate(character: Model, dt: number, eye: Vector3, isLocal: boolean, range: number)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	local entry = entries[character]
	-- (An NPC's death is NPCAnimator's to play.)
	if humanoid.Health <= 0 or character:GetAttribute("DeathStyle") ~= nil or (root.Position - eye).Magnitude > range then
		if entry then
			release(entry, character)
			entries[character] = nil
		end
		return
	end
	entry = entryFor(character)

	local velocity = root.AssemblyLinearVelocity
	local scale = entry.scale
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	-- The landing, scaled by how fast it was coming down.
	local landed: number? = nil
	if grounded then
		if not entry.grounded and entry.fall > 8 then
			landed = math.clamp(entry.fall / 60, 0.2, 1)
		end
		entry.fall = 0
	else
		entry.fall = math.max(entry.fall, -velocity.Y)
	end
	entry.grounded = grounded

	-- The roll: our own from ShiftLock the instant it starts; anyone else's from the server.
	local roll: { dir: Vector3, t: number }? = nil
	local crouch: boolean
	if isLocal then
		local mine = Motion.Local.roll
		if mine then
			roll = { dir = mine.dir, t = os.clock() - mine.start }
		end
		crouch = Motion.Local.crouch
	else
		local at = character:GetAttribute("RollAt")
		local dir = character:GetAttribute("RollDir")
		if typeof(at) == "number" and typeof(dir) == "Vector3" then
			local t = workspace:GetServerTimeNow() - at
			if t >= 0 and t < Motion.ROLL_TIME then
				roll = { dir = dir, t = t }
			end
			-- A new roll kicks up a little dust where it starts.
			if at ~= entry.rollAt and t >= 0 and t < 0.3 then
				CombatFX.LandDust(root.Position - Vector3.new(0, 2.6, 0), 0.45, character)
			end
			entry.rollAt = at
		end
		crouch = character:GetAttribute("Crouching") == true
	end

	local stateName = humanoid:GetState().Name
	local armed = character:GetAttribute("PoseRightC0") ~= nil
	local sprint = if isLocal then player:GetAttribute("Sprinting") == true else velocity.Magnitude > 21
	local poses, cover = Motion.Step(entry.state, {
		dt = dt,
		-- A bigger body takes the same steps at a proportionally higher speed.
		velocity = root.CFrame:VectorToObjectSpace(velocity) / scale,
		grounded = grounded,
		crouch = crouch,
		sprint = sprint,
		armed = armed,
		landed = landed,
		roll = roll,
		active = not NOT_OURS[stateName] and not humanoid.Sit and not emoting(character),
	})

	-- With a gun out the hold owns the chest, so the gait's say in it goes through PoseLayers: the
	-- pelvis's lean and twist taken back out (the gun stays on the aim while the legs run), and
	-- sprinting, the carry. The hold folds the layer in after the stance's own waist turn, so
	-- it is expressed in that frame.
	local offsets = Motion.Offsets[character]
	if armed and cover > 1e-3 then
		local stance = character:GetAttribute("PoseWaist")
		local turn = if typeof(stance) == "CFrame" then stance.Rotation else CFrame.identity
		local layer = turn:Inverse() * entry.state.chest * turn
		local waist = offsets and offsets.UpperTorso or CFrame.identity
		PoseLayers.Set(character, nil, nil, CFrame.identity:Lerp(layer, cover) * waist)
		entry.layered = true
	elseif entry.layered then
		PoseLayers.Clear(character)
		entry.layered = false
	end

	for name, joint in pairs(entry.joints) do
		local motor = joint.motor
		local pose = poses[name]
		if armed and Motion.ARMED_SKIP[name] then
			-- The gun hold writes these after this, from its own rest; nothing to undo.
			joint.touched = false
			Motion.Waist[motor] = nil
		elseif pose and cover > 1e-3 then
			local transform = motor.Transform
			if scale ~= 1 then
				pose = pose.Rotation + pose.Position * scale
			end
			local extra = offsets and offsets[name]
			local rest = if extra then joint.rest * extra else joint.rest
			motor.C0 = rest * transform:Lerp(pose, cover) * transform:Inverse()
			joint.touched = true
			if name == "UpperTorso" then
				-- HeadLook turns the chest on top of this, after us.
				Motion.Waist[motor] = motor.C0
			end
		elseif joint.touched then
			motor.C0 = joint.rest
			joint.touched = false
			Motion.Waist[motor] = nil
		end
	end
	Motion.Posing[character] = cover > 1e-3
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	for _, p in ipairs(Players:GetPlayers()) do
		local character = p.Character
		if character then
			animate(character, dt, eye, p == player, RANGE)
		end
	end
	local npcs = workspace:FindFirstChild("NPCs")
	if npcs then
		for _, model in ipairs(npcs:GetChildren()) do
			if model:IsA("Model") then
				animate(model, dt, eye, false, NPC_RANGE)
			end
		end
	end
	-- Characters that are gone (a respawn, a leaver) are let go of.
	for character, entry in pairs(entries) do
		if not character.Parent then
			release(entry, character)
			entries[character] = nil
		end
	end
end

RunService:BindToRenderStep("MotionAnimator", Enum.RenderPriority.Last.Value - 1, step)
