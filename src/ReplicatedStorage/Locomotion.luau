--!strict
-- How a player character moves its body: standing, running, strafing and backing up.
--
-- The clips are the uploaded R6 movement animations, carried across to R15 by
-- tools/anims/locomotion.luau into ReplicatedStorage.LocomotionData and played by this game
-- rather than by Roblox's Animator (a KeyframeSequence only plays live once it has been
-- published). This module is the maths: which clips a velocity calls for and in what mix, a
-- shared step phase so a blend of two gaits keeps its feet together, and the pose of every
-- joint that comes out. StarterPlayerScripts.LocomotionAnimator puts it on the joints.
--
-- Blending. Direction picks the clips -- forward runs, back backpedals, left and right
-- strafe, and a diagonal is a mix of its two neighbours -- and speed fades the lot in over
-- standing still. Each clip plays at the rate its authored pace needs for the feet to keep up
-- with the ground. A joint only some clips move (the idle moves only the arms) is left to the
-- default animation in proportion, so standing still still breathes.
--
-- Hand-offs. Two other scripts own parts of the upper body and run after this each frame:
-- WeaponPoseHold has the arms and chest while a gun is out, HeadLook always has the neck.
-- `Upper` tells them what the clip wants of those joints: the neck pose that keeps the head
-- level while the run leans the body, and, with a gun out, the turn to take back out of the
-- chest so the weapon stays square to the aim while the hips face into a strafe.

local EmotePlayer = require(script.Parent:WaitForChild("EmotePlayer"))

local Locomotion = {}

Locomotion.CLIPS = { "Idle", "Run", "WalkLeft", "WalkRight", "WalkBackward" }

-- The ground speed each moving clip was authored at, in studs per second. Played faster or
-- slower from there so a stride covers the ground it should rather than skating.
Locomotion.PACE = { Run = 16, WalkLeft = 9, WalkRight = 9, WalkBackward = 10 } :: { [string]: number }

-- Below MOVING a character is standing; by FULL it is wholly in the movement clips.
Locomotion.MOVING = 1.2
Locomotion.FULL = 5

-- How quickly the mix follows a change of direction or speed, and how quickly the whole thing
-- fades in and out (for a jump, a seat, an emote). Per second, exponential.
local BLEND_RATE = 10
local FADE_RATE = 12

-- Playback rate limits: a crawl should not freeze the legs, a speed boost should not blur them.
local MIN_RATE, MAX_RATE = 0.55, 2

-- The joints a gun takes over, which this leaves alone while one is out.
Locomotion.ARM_JOINTS = {
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
} :: { [string]: boolean }

type Clip = EmotePlayer.Clip
type Pair = { full: Clip, armed: Clip }

local clips: { [string]: Pair }? = nil

local function pairFrom(data: any): Pair
	local full = EmotePlayer.FromData(data)
	local armed = full
	if type(data.armed) == "table" then
		local joints = table.clone(data.joints)
		for name, track in pairs(data.armed) do
			joints[name] = track
		end
		armed = EmotePlayer.FromData({ length = data.length, loop = data.loop, joints = joints })
	end
	return { full = full, armed = armed }
end

--- Every clip, decoded once. Missing clips are simply absent.
function Locomotion.Clips(): { [string]: Pair }
	if clips then
		return clips
	end
	local out: { [string]: Pair } = {}
	local folder = script.Parent:FindFirstChild("LocomotionData")
	for _, name in ipairs(Locomotion.CLIPS) do
		local module = folder and folder:FindFirstChild(name)
		if module and module:IsA("ModuleScript") then
			local ok, data = pcall(require, module)
			if ok and type(data) == "table" then
				out[name] = pairFrom(data)
			end
		end
	end
	clips = out
	return out
end

--- The mix of clips a velocity calls for. `localVelocity` is in the character's own frame:
--- +X its right, -Z its front.
function Locomotion.Weights(localVelocity: Vector3): { [string]: number }
	local flat = Vector3.new(localVelocity.X, 0, localVelocity.Z)
	local speed = flat.Magnitude
	local moving = math.clamp((speed - Locomotion.MOVING) / (Locomotion.FULL - Locomotion.MOVING), 0, 1)
	local weights = { Idle = 1 - moving, Run = 0, WalkLeft = 0, WalkRight = 0, WalkBackward = 0 }
	if moving > 0 and speed > 1e-3 then
		local dir = flat / speed
		local forward, back = math.max(0, -dir.Z), math.max(0, dir.Z)
		local right, left = math.max(0, dir.X), math.max(0, -dir.X)
		local sum = forward + back + right + left
		weights.Run = moving * forward / sum
		weights.WalkBackward = moving * back / sum
		weights.WalkRight = moving * right / sum
		weights.WalkLeft = moving * left / sum
	end
	return weights
end

export type State = {
	weights: { [string]: number },
	alpha: number,
	phase: number,
	idleClock: number,
	scratch: { [string]: CFrame },
	poses: { [string]: CFrame },
	cover: { [string]: number },
}

function Locomotion.NewState(): State
	return {
		weights = { Idle = 1, Run = 0, WalkLeft = 0, WalkRight = 0, WalkBackward = 0 },
		alpha = 0,
		phase = 0,
		idleClock = 0,
		scratch = {},
		poses = {},
		cover = {},
	}
end

--- Advances one character by `dt` and returns every joint's pose with how much of it to
--- apply (0 = leave the joint to the default animation, 1 = the clip entirely).
---
--- `active` false fades the whole thing out -- in the air, seated, swimming, emoting -- so
--- whatever else animates the body then takes over smoothly.
function Locomotion.Step(state: State, dt: number, localVelocity: Vector3, armed: boolean,
	active: boolean): ({ [string]: CFrame }, { [string]: number })
	local all = Locomotion.Clips()
	local target = Locomotion.Weights(localVelocity)
	local blend = 1 - math.exp(-BLEND_RATE * dt)
	for name, w in pairs(target) do
		local current = state.weights[name] or 0
		state.weights[name] = current + (w - current) * blend
	end
	local fade = 1 - math.exp(-FADE_RATE * dt)
	state.alpha += ((active and 1 or 0) - state.alpha) * fade

	-- One step phase shared by every moving clip, advanced at the pace the mix calls for.
	local speed = Vector3.new(localVelocity.X, 0, localVelocity.Z).Magnitude
	local paceSum, lengthSum, movingSum = 0, 0, 0
	for name, pace in pairs(Locomotion.PACE) do
		local pair = all[name]
		local w = state.weights[name] or 0
		if pair and w > 0 then
			paceSum += pace * w
			lengthSum += pair.full.length * w
			movingSum += w
		end
	end
	if movingSum > 1e-3 and lengthSum > 0 then
		local rate = math.clamp(speed / (paceSum / movingSum), MIN_RATE, MAX_RATE)
		state.phase = (state.phase + dt * rate / (lengthSum / movingSum)) % 1
	end
	state.idleClock += dt

	local poses, cover = state.poses, state.cover
	table.clear(poses)
	table.clear(cover)
	local total = 0
	for _, name in ipairs(Locomotion.CLIPS) do
		local pair = all[name]
		local w = state.weights[name] or 0
		if pair and w > 1e-3 then
			total += w
			local clip = armed and pair.armed or pair.full
			local t = if name == "Idle" then state.idleClock % math.max(clip.length, 1e-3) else state.phase * clip.length
			local sampled = EmotePlayer.PoseAt(clip, t, state.scratch)
			for joint, cf in pairs(sampled) do
				local had = cover[joint]
				if had then
					poses[joint] = poses[joint]:Lerp(cf, w / (had + w))
					cover[joint] = had + w
				else
					poses[joint] = cf
					cover[joint] = w
				end
			end
			table.clear(state.scratch)
		end
	end
	for joint, w in pairs(cover) do
		cover[joint] = total > 0 and state.alpha * math.clamp(w / total, 0, 1) or 0
	end
	return poses, cover
end

-- ------------------------------------------------------------------ hand-offs --

export type Upper = { neck: CFrame, waist: CFrame }

--- What the clip wants of the joints other scripts own, per character, refreshed each frame
--- by LocomotionAnimator before they run. Weak, so a character that is gone is let go of.
Locomotion.Upper = setmetatable({}, { __mode = "k" }) :: any

local IDENTITY = CFrame.new()

--- The neck pose and the chest counter-turn for the poses `Step` just returned.
function Locomotion.UpperFrom(poses: { [string]: CFrame }, cover: { [string]: number }, armed: boolean): Upper
	if armed then
		-- The hips turn into a strafe; the chest turns back so the gun stays on the aim. The
		-- armed torso carries no lean, so its rotation is exactly that turn.
		local torso = poses.LowerTorso
		local c = cover.LowerTorso or 0
		local turn = torso and IDENTITY:Lerp(torso - torso.Position, c) or IDENTITY
		return { neck = IDENTITY, waist = turn:Inverse() }
	end
	local head = poses.Head
	return { neck = head and IDENTITY:Lerp(head - head.Position, cover.Head or 0) or IDENTITY, waist = IDENTITY }
end

--- The neck pose HeadLook should build on for a character (identity if none).
function Locomotion.NeckFor(character: Model): CFrame
	local upper = Locomotion.Upper[character]
	return upper and upper.neck or IDENTITY
end

--- The turn WeaponPoseHold should take back out of the chest (identity if none).
function Locomotion.WaistCounterFor(character: Model): CFrame
	local upper = Locomotion.Upper[character]
	return upper and upper.waist or IDENTITY
end

return Locomotion
