--!strict
-- Poses everyone doing a keyframe emote.
--
-- The emote pack is not made of animation assets (see EmoteConfig), so nothing replicates a
-- track. The server marks a character instead -- `Emote` = which, `EmoteAt` = the server
-- time it started -- and this, on every client, works out where each joint is from
-- ReplicatedStorage.EmoteData and puts it there. Everyone counts from the same server
-- clock, so everyone sees the same moment of the same dance.
--
-- How a joint is posed. The drawn joint is C0 * Transform, the default Animate script owns
-- Transform, and it writes it after PreRender (measured -- see WeaponPoseHold), so writing
-- Transform from here would be thrown away. So the emote goes in C0 with the animation
-- divided back out:  C0 = rest * pose * Transform^-1  =>  C0 * Transform = rest * pose.
-- The rest C0s come from the locked StarterCharacter, never from the live joint, which
-- other scripts lean and turn.
--
-- Blending is done the same way: `pose` is eased from whatever the animator is doing (or
-- the emote before this one) into the emote over FADE_IN, and back out over FADE_OUT, so
-- starting and stopping is a movement, not a snap.
--
-- Bound after WeaponPoseHold and the head look, so while a character emotes this is the
-- last word on its joints. Nothing else needs to know -- except that the head look stands
-- aside while EmotePlayer.Posing says a character is busy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local EmotePlayer = require(ReplicatedStorage:WaitForChild("EmotePlayer"))
local EmoteConfig = require(ReplicatedStorage:WaitForChild("EmoteConfig"))
local EmoteProps = require(ReplicatedStorage:WaitForChild("EmoteProps"))

local localPlayer = Players.LocalPlayer
local EmotePlay = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EmotePlay") :: RemoteEvent

local FADE_IN = 0.2
local FADE_OUT = 0.25
-- Past this, nobody can make out a dance; the character keeps its last pose until it comes
-- back into range or the emote ends.
local RANGE = 320

type Joint = { motor: Motor6D, rest: CFrame }
type State = {
	id: string,
	startedAt: number,
	clip: EmotePlayer.Clip,
	joints: { [string]: Joint },
	poses: { [string]: CFrame },
	from: { [string]: CFrame }?,   -- the previous emote's pose, when one hands over to another
	seenAt: number,
	endingAt: number?,
	weight: number,
	prop: EmoteProps.Prop?,
}

local states: { [Model]: State } = {}
-- Emotes this client let go of early (the player moved) and should not pick up again while
-- the server catches up: character -> the start time of the one let go.
local dismissed: { [Model]: number } = setmetatable({}, { __mode = "k" }) :: any

-- ------------------------------------------------------------------ joints --

-- Rest C0 of every joint on the locked rig, by the part it moves.
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

-- By class, not by name: this build also rigs R15 with AnimationConstraints carrying the
-- same names as the Motor6Ds.
local function jointsOf(character: Model): { [string]: Joint }
	local rests = restC0s()
	local joints = {}
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part1 and d.Part1.Parent == character then
			local name = d.Part1.Name
			joints[name] = { motor = d, rest = rests[name] or d.C0 }
		end
	end
	return joints
end

local function restore(state: State)
	for _, joint in pairs(state.joints) do
		if joint.motor.Parent then
			joint.motor.C0 = joint.rest
		end
	end
end

-- ------------------------------------------------------------------ states --

local function finish(character: Model)
	local state = states[character]
	if not state then
		return
	end
	restore(state)
	if state.prop then
		EmoteProps.Destroy(state.prop)
	end
	states[character] = nil
	EmotePlayer.Posing[character] = nil
end

local function begin(character: Model, id: string, startedAt: number)
	local clip = EmotePlayer.Load(id)
	if not clip then
		return
	end
	local previous = states[character]
	local from: { [string]: CFrame }? = nil
	local weight = 0
	if previous then
		-- Hand over from wherever the last emote had the body, rather than snapping to idle.
		from = {}
		for name, joint in pairs(previous.joints) do
			local pose = previous.poses[name]
			if pose then
				(from :: any)[name] = joint.motor.Transform:Lerp(pose, previous.weight)
			end
		end
		if previous.prop then
			EmoteProps.Destroy(previous.prop)
		end
		restore(previous)
	end
	local spec = EmoteConfig.Get(id)
	local prop = nil
	if spec and spec.prop then
		prop = EmoteProps.Build(spec.prop, workspace)
	end
	states[character] = {
		id = id,
		startedAt = startedAt,
		clip = clip,
		joints = jointsOf(character),
		poses = {},
		from = from,
		seenAt = os.clock(),
		endingAt = nil,
		weight = weight,
		prop = prop,
	}
	EmotePlayer.Posing[character] = true
end

local function wantsToMove(character: Model): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return true
	end
	if character == localPlayer.Character then
		if humanoid.MoveDirection.Magnitude > 0.1 or humanoid.Jump then
			return true
		end
	end
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if root then
		local v = root.AssemblyLinearVelocity
		if Vector3.new(v.X, 0, v.Z).Magnitude > 3 or math.abs(v.Y) > 8 then
			return true
		end
	end
	return false
end

-- ------------------------------------------------------------------- frame --

local function step()
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero

	-- Who has started (or switched) an emote since the last frame.
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local id = character:GetAttribute("Emote")
			local at = character:GetAttribute("EmoteAt")
			if type(id) == "string" and type(at) == "number" then
				local state = states[character]
				if (not state or state.id ~= id or state.startedAt ~= at) and dismissed[character] ~= at then
					begin(character, id, at)
				end
			end
		end
	end

	for character, state in pairs(states) do
		if not character.Parent then
			finish(character)
			continue
		end
		-- A weapon coming out takes the arms straight back.
		if character:GetAttribute("PoseRightC0") ~= nil then
			finish(character)
			continue
		end
		if not state.endingAt then
			local stillOn = character:GetAttribute("Emote") == state.id and character:GetAttribute("EmoteAt") == state.startedAt
			if not stillOn then
				state.endingAt = now
			elseif wantsToMove(character) then
				-- Do not wait a round trip for the server to notice: let go now, and tell it.
				state.endingAt = now
				dismissed[character] = state.startedAt
				if character == localPlayer.Character then
					EmotePlay:FireServer("")
				end
			end
			if state.endingAt then
				-- Ease back to what the animator is doing, not to the emote before this one.
				state.from = nil
			end
		end

		local weight
		if state.endingAt then
			weight = math.clamp(state.weight * (1 - (now - state.endingAt) / FADE_OUT), 0, 1)
			if weight <= 0 then
				finish(character)
				continue
			end
		else
			weight = math.clamp((now - state.seenAt) / FADE_IN, 0, 1)
			state.weight = weight
		end

		local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not root then
			continue
		end
		if (root.Position - eye).Magnitude > RANGE and not state.endingAt then
			continue
		end

		local elapsed = math.max(0, serverNow - state.startedAt)
		if not state.endingAt then
			EmotePlayer.PoseAt(state.clip, elapsed, state.poses)
		end
		local from = state.from
		for name, joint in pairs(state.joints) do
			local pose = state.poses[name]
			if pose then
				local motor = joint.motor
				local transform = motor.Transform
				local base = from and from[name] or transform
				motor.C0 = joint.rest * base:Lerp(pose, weight) * transform:Inverse()
			end
		end
		if state.prop then
			EmoteProps.Update(state.prop, character, EmoteProps.FloorOf(root.CFrame), elapsed)
		end
	end
end

RunService:BindToRenderStep("EmoteAnimator", Enum.RenderPriority.Last.Value + 2, step)

Players.PlayerRemoving:Connect(function(player)
	local character = player.Character
	if character and states[character] then
		finish(character)
	end
end)
