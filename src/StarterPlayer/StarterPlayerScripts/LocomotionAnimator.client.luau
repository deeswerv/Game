--!strict
-- Walks, runs, strafes and backpedals every player character, from the uploaded movement
-- clips (see ReplicatedStorage.Locomotion for the blending and LocomotionData for the clips).
--
-- Nothing here is replicated, and nothing needs to be: every client already knows every
-- character's velocity and facing, and poses each one locally from them -- so a player
-- strafing left is seen strafing left by everyone, with no remote traffic at all.
--
-- How a joint is posed is the same as the emotes and the weapon hold: the default Animate
-- script owns Transform and writes it after PreRender, so the clip goes in C0 with the
-- animation divided back out -- C0 = rest * Transform:Lerp(pose, cover) * Transform^-1. A
-- `cover` below one leaves that much of the default animation showing, which is how a fade
-- or a joint the clips do not move hands back without a snap.
--
-- Bound just before WeaponPoseHold (Last) and HeadLook (Last + 1), which own the arms and
-- chest with a gun out and the neck always; what the clip wants of those joints is passed to
-- them through Locomotion.Upper rather than written here. EmoteAnimator (Last + 2) has the
-- whole body while an emote plays, and this fades out for it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local Locomotion = require(ReplicatedStorage:WaitForChild("Locomotion"))
local EmotePlayer = require(ReplicatedStorage:WaitForChild("EmotePlayer"))

-- Past this nobody can make out a gait, and each character is a dozen joint writes a frame.
local RANGE = 300

-- Humanoid states in which the body is not walking on its feet. The default animation (the
-- jump, the fall, the climb, the swim, the seat) plays instead.
local OFF_FEET: { [string]: boolean } = {
	Jumping = true, Freefall = true, FallingDown = true, Climbing = true, Swimming = true,
	Seated = true, PlatformStanding = true, Ragdoll = true, Physics = true, Dead = true, GettingUp = true,
	Flying = true,
}

type Joint = { motor: Motor6D, rest: CFrame, touched: boolean }
type Entry = { state: Locomotion.State, joints: { [string]: Joint } }

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

-- By class: this rig also carries AnimationConstraints with the Motor6Ds' names.
local function jointsOf(character: Model): { [string]: Joint }
	local rests = restC0s()
	local joints = {}
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part1 and d.Part1.Parent == character and d.Part1.Name ~= "Head" then
			local name = d.Part1.Name
			joints[name] = { motor = d, rest = rests[name] or d.C0, touched = false }
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
			entry.joints = jointsOf(character)
		end
		return entry
	end
	local created: Entry = { state = Locomotion.NewState(), joints = jointsOf(character) }
	entries[character] = created
	return created
end

local function release(entry: Entry)
	for _, joint in pairs(entry.joints) do
		if joint.touched and joint.motor.Parent then
			joint.motor.C0 = joint.rest
		end
		joint.touched = false
	end
end

local function emoting(character: Model): boolean
	return EmotePlayer.Posing[character] == true or character:GetAttribute("Emote") ~= nil
end

local function animate(character: Model, dt: number, eye: Vector3)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root or not root:IsA("BasePart") then
		return
	end
	local entry = entries[character]
	if humanoid.Health <= 0 or (root.Position - eye).Magnitude > RANGE then
		if entry then
			release(entry)
			entries[character] = nil
			Locomotion.Upper[character] = nil
		end
		return
	end
	entry = entryFor(character)

	local active = not OFF_FEET[humanoid:GetState().Name] and not humanoid.Sit and not emoting(character)
	local armed = character:GetAttribute("PoseRightC0") ~= nil
	local velocity = root.AssemblyLinearVelocity
	local localVelocity = root.CFrame:VectorToObjectSpace(velocity)
	local poses, cover = Locomotion.Step(entry.state, dt, localVelocity, armed, active)

	for name, joint in pairs(entry.joints) do
		local motor = joint.motor
		local amount = cover[name] or 0
		local pose = poses[name]
		if armed and Locomotion.ARM_JOINTS[name] then
			-- The gun hold writes these after this, from its own rest; nothing to undo.
			joint.touched = false
		elseif pose and amount > 1e-3 then
			local transform = motor.Transform
			motor.C0 = joint.rest * transform:Lerp(pose, amount) * transform:Inverse()
			joint.touched = true
		elseif joint.touched then
			motor.C0 = joint.rest
			joint.touched = false
		end
	end
	Locomotion.Upper[character] = Locomotion.UpperFrom(poses, cover, armed)
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			animate(character, dt, eye)
		end
	end
	-- Characters that are gone (a respawn, a leaver) are let go of.
	for character, entry in pairs(entries) do
		if not character.Parent then
			release(entry)
			entries[character] = nil
		end
	end
end

RunService:BindToRenderStep("LocomotionAnimator", Enum.RenderPriority.Last.Value - 1, step)
