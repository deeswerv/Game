--!strict
-- How a player's body moves: a stylised, procedural gait for the game's blocky characters.
--
-- Not motion capture. The uploaded movement clips were tried and taken out because they looked
-- out of place on these bodies; this is drawn the way the rest of the game is -- bold, simple
-- shapes, a little exaggerated -- and computed, so it fits any speed and any direction:
--
--   idle      a slow breath, arms relaxed a touch off the body
--   walk/run  legs swing round the direction you are actually moving (so strafing and
--             backpedalling step the right way), knees lift on the forward swing, arms pump
--             against the legs, the body bobs twice a stride and leans into the run; a
--             sprint leans harder and pumps harder
--   crouch    hips down, knees bent, feet kept flat under you; walking crouched is a shorter,
--             lower stride
--   air       knees tucked, arms out for balance (higher when dropping fast)
--   land      a dip through the knees, scaled by how hard you came down
--   roll      a tucked somersault toward the roll's direction (forward, back, or a side roll),
--             the body dropping into it so it stays on the ground
--
-- Every pose is a set of joint rotations keyed by the part each joint moves (R15 names).
-- Step smooths toward the target each frame, so changes of state blend instead of snapping.
-- Pure: no instances, nothing replicated. MotionAnimator poses every character from this.
--
-- Joint frames on this rig are axis-aligned with their parts (every C0 rotation is identity):
-- +X is the body's right, +Y up, -Z forward. A rotation of +a about X swings a hanging limb
-- forward; a knee bends with -a about X.

local Motion = {}

Motion.ROLL_TIME = 0.5            -- seconds, start to standing
Motion.ROLL_COOLDOWN = 0.9        -- after a roll ends, before another
Motion.ROLL_SPEED = { 40, 13 }    -- studs/s at the start and the end of the push
Motion.CROUCH_SPEED = 0.5         -- of walking pace
Motion.CROUCH_DROP = 0.8          -- how far the hips come down, studs
Motion.CROUCH_SPREAD = 0.75       -- crouched, the cone is this much of standing
-- The roll turns round this point above the hips joint (the curled body's middle).
Motion.ROLL_CENTRE = Vector3.new(0, 0.9, -0.25)

-- The local player's own crouch and roll, as ShiftLock has them this frame (client only), so
-- MotionAnimator can pose our body without waiting for the server's attributes.
type LocalMotion = { crouch: boolean, roll: { dir: Vector3, start: number }? }
Motion.Local = { crouch = false, roll = nil } :: LocalMotion

-- Leg segments of the locked rig (hip to knee, knee to ankle), for keeping the feet down.
local THIGH, SHIN = 0.98, 0.69

local rad = math.rad
local sin, cos = math.sin, math.cos

export type Input = {
	dt: number,
	velocity: Vector3,         -- in the body's own frame (forward is -Z)
	grounded: boolean,
	crouch: boolean,
	sprint: boolean,
	armed: boolean,            -- a gun out: the gun hold owns the arms and the waist
	landed: number?,           -- this frame's landing, 0..1 by how hard
	roll: { dir: Vector3, t: number }?, -- body-frame direction, seconds since it began
	active: boolean,           -- on its feet and ours to pose (not seated, swimming, emoting)
}

export type State = {
	phase: number,
	time: number,
	speed: number,
	dir: Vector3,
	crouch: number,
	air: number,
	land: number,
	cover: number,
	poses: { [string]: CFrame },
}

Motion.JOINTS = {
	"LowerTorso", "UpperTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}
-- The joints a held gun owns (WeaponPoseHold writes them after this).
Motion.ARMED_SKIP = {
	UpperTorso = true, LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
}

function Motion.NewState(): State
	local poses = {}
	for _, name in ipairs(Motion.JOINTS) do
		poses[name] = CFrame.identity
	end
	return { phase = 0, time = 0, speed = 0, dir = Vector3.new(0, 0, -1), crouch = 0, air = 0, land = 0,
		cover = 0, poses = poses }
end

--- The axis a leg swings round to step toward `dir` (body frame, flat): +angle moves the foot
--- that way.
local function stepAxis(dir: Vector3): Vector3
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 1e-3 then
		return Vector3.new(1, 0, 0)
	end
	flat = flat.Unit
	return Vector3.new(-flat.Z, 0, flat.X)
end

local function around(axis: Vector3, angle: number): CFrame
	return CFrame.fromAxisAngle(axis, angle)
end

--- Hip, knee and ankle angles that drop the hips `drop` studs with the foot flat under them.
function Motion.CrouchAngles(drop: number): (number, number, number)
	local c = math.clamp(1 - drop / (THIGH + SHIN), -1, 1)
	local a = math.acos(c)
	return a, 2 * a, a
end

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

--- The roll's own pose at fraction `r` (0..1) toward body-frame `dir`. Returns the joint poses
--- and how much of the body it takes (eases in and out).
-- How far the hips come down at each twentieth of a roll so the curled body's lowest point is
-- on the floor -- forward, backward and sideways. Baked from the rig by forward kinematics
-- (`lune run tools/mapview/poses.luau -- out.json bake`); re-bake if the roll's shape changes.
Motion.ROLL_GROUND = {
	forward = { 0.00, 0.41, 0.65, 0.74, 0.85, 1.05, 0.78, 0.54, 0.52, 0.59, 0.93, 1.62, 2.34, 2.07, 1.95, 1.68, 0.99, 0.29, -0.05, -0.02, 0.00 },
	back = { 0.00, 0.42, 0.78, 1.13, 1.50, 1.77, 2.05, 2.20, 2.44, 1.77, 0.93, 0.51, 0.37, 0.40, 0.52, 0.54, 0.21, -0.04, -0.10, -0.03, 0.00 },
	side = { 0.00, 0.40, 0.62, 0.78, 0.96, 1.18, 0.98, 0.77, 0.60, 0.80, 0.93, 0.77, 0.53, 0.67, 0.80, 0.85, 0.39, 0.01, -0.12, -0.04, 0.00 },
}

local function groundAt(curve: { number }, r: number): number
	local n = #curve
	if n == 1 then
		return curve[1]
	end
	local x = math.clamp(r, 0, 1) * (n - 1) + 1
	local i = math.clamp(math.floor(x), 1, n - 1)
	local f = x - i
	return curve[i] + (curve[i + 1] - curve[i]) * f
end

--- How far down the hips go at fraction `r` of a roll toward body-frame `dir`.
function Motion.RollDrop(r: number, dir: Vector3): number
	local fwd, back, side = math.max(0, -dir.Z), math.max(0, dir.Z), math.abs(dir.X)
	local total = fwd + back + side
	if total < 1e-6 then
		fwd, total = 1, 1
	end
	local g = Motion.ROLL_GROUND
	return (groundAt(g.forward, r) * fwd + groundAt(g.back, r) * back + groundAt(g.side, r) * side) / total
end

function Motion.RollPose(r: number, dir: Vector3, dropOverride: number?): ({ [string]: CFrame }, number)
	local axis = stepAxis(dir)
	-- Tucked from the moment it starts until it is nearly round, then unfolding.
	local tuck = sin(math.pi * math.clamp(r * 1.15, 0, 1)) ^ 0.5
	local spin = -2 * math.pi * smoothstep(r)
	-- It turns over round the middle of the curled-up body (above the hips: the chest and head
	-- fold down onto the knees), which is dropped toward the floor so the ball rolls on it
	-- rather than spinning in the air.
	local centre = Motion.ROLL_CENTRE * tuck
	local drop = dropOverride or Motion.RollDrop(r, dir)
	local hip, knee = rad(115) * tuck, rad(135) * tuck
	local poses = {
		LowerTorso = CFrame.new(0, -drop, 0) * CFrame.new(centre) * around(axis, spin) * CFrame.new(-centre),
		UpperTorso = CFrame.Angles(rad(-45) * tuck, 0, 0),
		LeftUpperLeg = CFrame.Angles(hip, 0, rad(-6) * tuck),
		RightUpperLeg = CFrame.Angles(hip, 0, rad(6) * tuck),
		LeftLowerLeg = CFrame.Angles(-knee, 0, 0),
		RightLowerLeg = CFrame.Angles(-knee, 0, 0),
		LeftFoot = CFrame.Angles(rad(30) * tuck, 0, 0),
		RightFoot = CFrame.Angles(rad(30) * tuck, 0, 0),
		LeftUpperArm = CFrame.Angles(rad(95) * tuck, 0, rad(-14) * tuck),
		RightUpperArm = CFrame.Angles(rad(95) * tuck, 0, rad(14) * tuck),
		LeftLowerArm = CFrame.Angles(rad(85) * tuck, 0, 0),
		RightLowerArm = CFrame.Angles(rad(85) * tuck, 0, 0),
		LeftHand = CFrame.identity,
		RightHand = CFrame.identity,
	}
	local weight = smoothstep(r / 0.08) * (1 - smoothstep((r - 0.88) / 0.12))
	return poses, weight
end

--- The body on its feet (or in the air) for the smoothed state.
local function groundPose(state: State, input: Input): { [string]: CFrame }
	local speed = state.speed
	local run = math.clamp(speed / 18, 0, 1) ^ 0.8
	local sprint = if input.sprint then math.clamp((speed - 18) / 8, 0, 1) else 0
	local crouch = state.crouch
	local phase = state.phase
	local axis = stepAxis(state.dir)
	-- How much of the movement is forward/back (arms pump for that, not for a side-step).
	local forward = math.abs(state.dir.Z)
	local armed = input.armed

	-- The stride: smaller and lower crouched.
	local stride = run * (1 - 0.4 * crouch)
	local hipSwing = rad(42 + 10 * sprint) * stride
	local kneeLift = rad(70 + 15 * sprint) * stride * (1 - 0.35 * crouch)
	local armSwing = rad(38 + 14 * sprint) * stride * (0.35 + 0.65 * forward)

	-- Crouch: hips down, legs folded, feet flat.
	local cHip, cKnee, cAnkle = Motion.CrouchAngles(Motion.CROUCH_DROP * crouch)

	-- Air: knees up, alternating a little; landing: a dip.
	local air, land = state.air, state.land
	local lHip, lKnee, lAnkle = Motion.CrouchAngles(0.55 * land)

	local poses: { [string]: CFrame } = {}
	for _, side in ipairs({ "Left", "Right" }) do
		local p = if side == "Left" then phase else phase + math.pi
		local swing = hipSwing * sin(p)
		local lift = kneeLift * math.max(0, cos(p))
		local airHip = rad(28 + (if side == "Left" then 14 else -6)) * air
		local airKnee = rad(55 + (if side == "Left" then 20 else 0)) * air
		local hip = cHip + lHip + airHip
		local knee = rad(8) * run + lift + cKnee + lKnee + airKnee
		local shin = swing + hip - knee
		poses[side .. "UpperLeg"] = CFrame.Angles(hip, 0, 0) * around(axis, swing * (1 - air))
		poses[side .. "LowerLeg"] = CFrame.Angles(-knee, 0, 0)
		-- The foot follows the shin part way, so it rolls through the step instead of staying
		-- glued at one angle.
		poses[side .. "Foot"] = CFrame.Angles(cAnkle + lAnkle - 0.35 * shin * (1 - crouch), 0, 0)

		-- Arms pump against the leg on the same side; relaxed a touch off the body at rest.
		local outward = if side == "Left" then -1 else 1
		local armP = -sin(p)
		local spread = rad(6 + 22 * air) + rad(4) * (1 - run)
		local raise = rad(18) * air
		poses[side .. "UpperArm"] = CFrame.Angles(armSwing * armP + raise + rad(10) * crouch, 0, outward * spread)
		poses[side .. "LowerArm"] = CFrame.Angles(rad(12) + rad(40) * run + rad(20) * crouch
			+ rad(18) * stride * math.max(0, armP), 0, 0)
		poses[side .. "Hand"] = CFrame.identity
	end

	-- The body: bob twice a stride, lean into the run (less with a gun up), breathe at rest.
	local breathe = 0.03 * sin(state.time * 2.2) * (1 - run)
	local bob = 0.11 * stride * math.abs(sin(phase)) - 0.05 * stride
	local lean = rad(if armed then 3 + 3 * crouch else 7 + 10 * sprint + 10 * crouch) * math.max(run, crouch)
	local leanAxis = stepAxis(state.dir)
	local drop = Motion.CROUCH_DROP * crouch + 0.55 * land + 0.12 * air
	poses.LowerTorso = CFrame.new(0, breathe + bob - drop, 0)
		* around(leanAxis, -lean * (0.4 + 0.6 * forward))
		* CFrame.Angles(0, rad(6) * stride * sin(phase), 0)
	-- The chest turns back against the hips (counter-rotation), and curls a little crouched.
	poses.UpperTorso = CFrame.Angles(rad(-6) * crouch + rad(2) * sin(state.time * 2.2) * (1 - run), rad(-9) * stride * sin(phase), 0)
	return poses
end

--- Advance `state` by one frame of `input`. Returns the joint poses and how much of the body
--- they should cover (0 = leave the default animation, 1 = all ours).
function Motion.Step(state: State, input: Input): ({ [string]: CFrame }, number)
	local dt = math.clamp(input.dt, 0, 0.1)
	state.time += dt
	local flat = Vector3.new(input.velocity.X, 0, input.velocity.Z)
	local speed = flat.Magnitude

	-- Smoothed speed and direction: the gait never jumps between strides.
	state.speed += (speed - state.speed) * math.clamp(dt * 10, 0, 1)
	if speed > 0.6 then
		local want = flat.Unit
		state.dir = state.dir:Lerp(want, math.clamp(dt * 12, 0, 1))
		if state.dir.Magnitude > 1e-3 then
			state.dir = state.dir.Unit
		else
			state.dir = want
		end
	end
	-- The stride's frequency follows the speed: a walk ambles, a sprint churns.
	local frequency = 1.25 + 0.075 * state.speed
	if input.grounded then
		state.phase = (state.phase + 2 * math.pi * frequency * dt) % (2 * math.pi)
	end
	state.crouch += ((if input.crouch then 1 else 0) - state.crouch) * math.clamp(dt * 11, 0, 1)
	state.air += ((if input.grounded then 0 else 1) - state.air) * math.clamp(dt * (if input.grounded then 14 else 7), 0, 1)
	if input.landed and input.landed > 0 then
		state.land = math.max(state.land, math.clamp(input.landed, 0, 1))
	end
	state.land = math.max(0, state.land - dt * 4)
	state.cover += ((if input.active then 1 else 0) - state.cover) * math.clamp(dt * 9, 0, 1)

	local target = groundPose(state, input)
	local rate = 16
	if input.roll and input.roll.t >= 0 and input.roll.t < Motion.ROLL_TIME then
		local rollPoses, weight = Motion.RollPose(input.roll.t / Motion.ROLL_TIME, input.roll.dir)
		for name, pose in pairs(rollPoses) do
			target[name] = (target[name] or CFrame.identity):Lerp(pose, weight)
		end
		rate = 60
	end

	local k = math.clamp(dt * rate, 0, 1)
	for _, name in ipairs(Motion.JOINTS) do
		local want = target[name] or CFrame.identity
		-- The roll's full turn cannot be eased toward (a lerp takes the short way round), so
		-- the root follows it exactly while rolling.
		if name == "LowerTorso" and rate > 20 then
			state.poses[name] = want
		else
			state.poses[name] = state.poses[name]:Lerp(want, k)
		end
	end
	return state.poses, state.cover
end

--- Where a roll toward a body-frame `dir` sends the character, as a world-space push for a
--- moment `t` seconds in (flat; gravity is left alone).
function Motion.RollSpeed(t: number): number
	local r = math.clamp(t / Motion.ROLL_TIME, 0, 1)
	local ease = 1 - (1 - r) * (1 - r)
	return Motion.ROLL_SPEED[1] + (Motion.ROLL_SPEED[2] - Motion.ROLL_SPEED[1]) * ease
end

--- The direction a roll goes from the keys held: W/S/A/D (as a body-frame move vector), or
--- forward when nothing is held.
function Motion.RollDirection(move: Vector3): Vector3
	local flat = Vector3.new(move.X, 0, move.Z)
	if flat.Magnitude < 0.1 then
		return Vector3.new(0, 0, -1)
	end
	return flat.Unit
end

return Motion
