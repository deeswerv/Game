--!strict
-- How a player's body moves: a stylised, procedural gait for the game's blocky characters.
--
-- Not motion capture. The uploaded movement clips were tried and taken out because they looked
-- out of place on these bodies; this is drawn the way the rest of the game is -- bold, simple
-- shapes, a little exaggerated -- and computed, so it fits any speed and any direction:
--
--   idle      a slow breath, arms relaxed a touch off the body
--   walk/run  keyframed cycles, the way an animator draws them, blended by speed: a walk
--             (heel down, roll over, push off), a run (land ahead, soak it, drive off the
--             toes, heel kicked up behind, knee driven through, a moment in the air) and a
--             sprint (all of it further). The hips sit as high as the planted leg reaches, so
--             the feet stay on the floor; the body leans into it (hard when sprinting), the
--             hips turn with the swinging leg and the chest back against them, a strafe banks
--             and steps sideways, backing up plays the cycle in reverse. With a gun out the
--             hold keeps the chest square to the aim (`state.chest`), and a sprint drops the
--             gun into a carry across the body.
--   crouch    hips down, knees bent, feet kept flat under you; walking crouched is a shorter,
--             lower stride
--   air       knees tucked, arms out for balance (higher when dropping fast)
--   land      a dip through the knees, scaled by how hard you came down
--   roll      a tucked somersault toward the roll's direction (forward, back, or a side roll),
--             the body dropping into it so it stays on the ground -- and about 18 studs of
--             ground covered (ShiftLock holds the push with a constraint)
--
-- Every pose is a set of joint rotations keyed by the part each joint moves (R15 names).
-- Step smooths toward the target each frame, so changes of state blend instead of snapping.
-- Pure: no instances, nothing replicated. MotionAnimator poses every character from this.
--
-- Joint frames on this rig are axis-aligned with their parts (every C0 rotation is identity):
-- +X is the body's right, +Y up, -Z forward. A rotation of +a about X swings a hanging limb
-- forward; a knee bends with -a about X.

local Motion = {}

Motion.ROLL_TIME = 0.55           -- seconds, start to standing
Motion.ROLL_COOLDOWN = 0.9        -- after a roll ends, before another
Motion.ROLL_SPEED = { 54, 22 }    -- studs/s at the start and the end of the push (~18 studs)
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
	chest: CFrame,             -- with a gun up: the waist offset the hold folds in
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
		cover = 0, poses = poses, chest = CFrame.identity }
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

-- ------------------------------------------------------------------ the gait --
--
-- One leg's cycle, keyframed the way an animator draws it, from the moment its foot strikes
-- the ground (t = 0) round to the next strike (t = 1); the other leg runs half a cycle behind.
-- Angles are degrees in the WORLD's frame, not the hip's, so the body can lean without the
-- stride leaning with it: `thigh` forward of straight down, `knee` its bend, `foot` the sole's
-- pitch (+ toes up). `stance` is when the foot leaves the ground.
type Key = { t: number, thigh: number, knee: number, foot: number }
type Cycle = { keys: { Key }, stance: number }

-- A walk: heel down, roll over the foot, push off the toes, swing through. Always a foot down.
local WALK: Cycle = { stance = 0.6, keys = {
	{ t = 0.00, thigh = 22, knee = 4, foot = 12 },
	{ t = 0.14, thigh = 13, knee = 16, foot = 0 },
	{ t = 0.36, thigh = -5, knee = 6, foot = 0 },
	{ t = 0.56, thigh = -21, knee = 18, foot = -26 },
	{ t = 0.72, thigh = -6, knee = 56, foot = -14 },
	{ t = 0.87, thigh = 20, knee = 26, foot = 2 },
} }
-- A run: the foot lands ahead, the knee soaks the weight, the toes drive off, the heel kicks up
-- behind, the knee drives through high, the shin swings out to reach -- and both feet are off
-- the ground in between.
local RUN: Cycle = { stance = 0.34, keys = {
	{ t = 0.00, thigh = 30, knee = 14, foot = 8 },
	{ t = 0.14, thigh = 6, knee = 40, foot = 0 },
	{ t = 0.34, thigh = -36, knee = 16, foot = -42 },
	{ t = 0.52, thigh = -14, knee = 112, foot = -38 },
	{ t = 0.71, thigh = 58, knee = 96, foot = -14 },
	{ t = 0.88, thigh = 44, knee = 34, foot = 4 },
} }
-- A sprint: everything further -- a longer reach, a harder drive, the heel right up.
local SPRINT: Cycle = { stance = 0.3, keys = {
	{ t = 0.00, thigh = 40, knee = 12, foot = 10 },
	{ t = 0.13, thigh = 10, knee = 42, foot = 0 },
	{ t = 0.30, thigh = -48, knee = 16, foot = -50 },
	{ t = 0.48, thigh = -22, knee = 134, foot = -42 },
	{ t = 0.68, thigh = 70, knee = 104, foot = -16 },
	{ t = 0.86, thigh = 56, knee = 34, foot = 6 },
} }
Motion.WALK, Motion.RUN, Motion.SPRINT = WALK, RUN, SPRINT

-- The foot of the locked rig, from the ankle: how far down the sole is, how far forward the
-- toes reach and back the heel (for keeping the lowest corner on the floor).
local SOLE, TOE, HEEL = 0.35, 0.88, 0.36
local REST_LEG = THIGH + SHIN + SOLE

--- Where `cycle` has the leg at `t` (0..1, wrapping): thigh, knee and foot, in radians. Smooth
--- through the keys (Catmull-Rom), so there are no corners in the motion.
local function sample(cycle: Cycle, t: number): (number, number, number)
	local keys = cycle.keys
	local n = #keys
	t = t % 1
	-- The key at or before t (the last one wraps round to the first).
	local i = n
	for k = n, 1, -1 do
		if keys[k].t <= t then
			i = k
			break
		end
	end
	local function at(k: number): Key
		return keys[((i - 1 + k) % n) + 1]
	end
	local k0, k1, k2, k3 = at(-1), at(0), at(1), at(2)
	local t1, t2 = k1.t, k2.t
	if t2 <= t1 then
		t2 += 1
	end
	local u = math.clamp((t - t1) / (t2 - t1), 0, 1)
	local u2, u3 = u * u, u * u * u
	local function cr(a: number, b: number, c: number, d: number): number
		return 0.5 * (2 * b + (c - a) * u + (2 * a - 5 * b + 4 * c - d) * u2 + (3 * b - a - 3 * c + d) * u3)
	end
	return rad(cr(k0.thigh, k1.thigh, k2.thigh, k3.thigh)), rad(cr(k0.knee, k1.knee, k2.knee, k3.knee)),
		rad(cr(k0.foot, k1.foot, k2.foot, k3.foot))
end
Motion.Sample = sample

--- How far below the hip the lowest corner of the foot is, for a leg at these world angles.
local function legReach(thigh: number, knee: number, foot: number): number
	local tip = if foot < 0 then TOE * sin(-foot) else HEEL * sin(foot)
	return THIGH * cos(thigh) + SHIN * cos(thigh - knee) + SOLE * cos(foot) + tip
end

--- The body on its feet (or in the air) for the smoothed state. Also returns the pelvis's turn
--- (lean, bank and twist, without the bob), which the gun hold takes back out of the chest.
local function groundPose(state: State, input: Input): ({ [string]: CFrame }, CFrame)
	local speed = state.speed
	-- How much it is moving at all, and in which gait: a walk turns into a run between 9 and 15
	-- studs a second, and a run into a sprint past 17 with sprint held.
	local move = smoothstep(speed / 5)
	local runW = smoothstep((speed - 9) / 6)
	local sprintW = if input.sprint then smoothstep((speed - 17) / 6) else 0
	local crouch = state.crouch
	local air, land = state.air, state.land
	local armed = input.armed

	-- Which way the legs travel. Backing up is the forward cycle played in reverse.
	local dir = state.dir
	local forwardness = -dir.Z
	local back = smoothstep((-forwardness - 0.25) / 0.5)
	local travel = if back > 0.5 then -dir else dir
	local axis = stepAxis(travel)
	-- Crouched, or backing up, the stride stays nearer a walk.
	runW *= (1 - crouch) * (1 - 0.6 * back)
	sprintW *= (1 - crouch) * (1 - back)
	local stride = move * (1 - 0.35 * crouch) * (1 - 0.25 * back)

	local tCycle = state.phase / (2 * math.pi)
	if back > 0.5 then
		tCycle = 1 - tCycle
	end

	-- Crouch and landing: thigh forward, knee folded twice as far, sole flat -- the hips drop
	-- by exactly the leg's shortening.
	local cHip = Motion.CrouchAngles(Motion.CROUCH_DROP * crouch)
	local lHip = Motion.CrouchAngles(0.55 * land)

	local legs = {}
	for _, side in ipairs({ "Left", "Right" }) do
		local t = if side == "Left" then tCycle else tCycle + 0.5
		local wt, wk, wf = sample(WALK, t)
		local rt, rk, rf = sample(RUN, t)
		local st, sk, sf = sample(SPRINT, t)
		local thigh = wt + (rt - wt) * runW
		local knee = wk + (rk - wk) * runW
		local foot = wf + (rf - wf) * runW
		thigh += (st - thigh) * sprintW
		knee += (sk - knee) * sprintW
		foot += (sf - foot) * sprintW
		thigh *= stride
		knee *= stride
		foot *= stride
		-- In the air: knees up, one a little ahead of the other.
		local tuck = if side == "Left" then 1 else 0.4
		thigh += rad(34) * air * tuck
		knee += rad(70) * air * tuck
		foot -= rad(15) * air
		-- Crouched, and landing.
		local bend = cHip + lHip
		thigh += bend
		knee += 2 * bend
		legs[side] = { thigh = thigh, knee = knee, foot = foot, t = t % 1 }
	end

	-- The hips sit as high as the longer leg reaches, so the planted foot is on the floor and
	-- never through it -- and in the run's flight, a little higher still.
	local reach = math.max(legReach(legs.Left.thigh, legs.Left.knee, legs.Left.foot),
		legReach(legs.Right.thigh, legs.Right.knee, legs.Right.foot))
	local stance = WALK.stance + (RUN.stance - WALK.stance) * runW
	local flight = 0
	for _, leg in pairs(legs) do
		if leg.t >= stance and leg.t < 0.5 then
			flight = math.max(flight, sin(math.pi * (leg.t - stance) / (0.5 - stance)))
		end
	end
	local lift = flight * (0.07 * runW + 0.06 * sprintW) * stride
	local breathe = 0.03 * sin(state.time * 2.2) * (1 - move)
	local height = (reach - REST_LEG) * (1 - air) + lift + breathe - 0.12 * air

	-- Lean into the run (harder sprinting, less with a gun up), bank into a strafe, and turn
	-- the hips with the leg that is swinging through.
	local leanDeg = 3 * move + 9 * runW + 9 * sprintW + 10 * crouch
	if armed then
		leanDeg *= 0.75
	end
	local lean = rad(leanDeg) * (0.35 + 0.65 * math.max(forwardness, 0))
	local bank = rad(6) * dir.X * runW
	local swing = math.clamp((legs.Left.thigh - legs.Right.thigh) / rad(70), -1, 1) * move
	local twist = -rad(7 + 3 * runW) * swing * (0.4 + 0.6 * math.abs(dir.Z))
	local pelvis = CFrame.Angles(0, twist, 0) * CFrame.Angles(-lean, 0, -bank)

	local poses: { [string]: CFrame } = {}
	poses.LowerTorso = CFrame.new(0, height, 0) * pelvis
	-- The legs hang straight down in the world, whatever the pelvis is doing, then swing.
	local unturn = pelvis:Inverse()
	for _, side in ipairs({ "Left", "Right" }) do
		local leg = legs[side]
		local spread = (if side == "Left" then -1 else 1) * rad(2 + 3 * crouch)
		poses[side .. "UpperLeg"] = unturn * around(axis, leg.thigh) * CFrame.Angles(0, 0, spread)
		poses[side .. "LowerLeg"] = CFrame.Angles(-leg.knee, 0, 0)
		-- The sole's pitch in the world, less the shin's.
		poses[side .. "Foot"] = CFrame.Angles(leg.foot - (leg.thigh - leg.knee), 0, 0)
	end

	-- Arms (no gun): pump against the legs, elbows bent -- loose at a walk, driving in a run.
	for _, side in ipairs({ "Left", "Right" }) do
		local out = if side == "Left" then -1 else 1
		local opposite = if side == "Left" then -swing else swing
		local amp = rad(24 + 12 * runW + 10 * sprintW) * (0.3 + 0.7 * math.abs(dir.Z))
		local elbow = rad(12) * move + rad(56) * runW + rad(10) * sprintW + rad(16) * runW * math.max(0, opposite)
		local spread = rad(5 + 20 * air) + rad(4) * (1 - move)
		poses[side .. "UpperArm"] = CFrame.Angles(amp * opposite + rad(8) * runW + rad(18) * air + rad(10) * crouch, 0,
			out * spread)
		poses[side .. "LowerArm"] = CFrame.Angles(rad(10) + elbow + rad(20) * crouch, 0, 0)
		poses[side .. "Hand"] = CFrame.identity
	end
	-- The chest turns back against the hips (and rounds a little crouched).
	poses.UpperTorso = CFrame.Angles(rad(-6) * crouch + rad(2) * sin(state.time * 2.2) * (1 - move), -twist * 1.6, 0)
	return poses, pelvis
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
	local frequency = 0.9 + 0.08 * state.speed
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
	local rolling = 0
	local rate = 16
	if input.roll and input.roll.t >= 0 and input.roll.t < Motion.ROLL_TIME then
		local rollPoses, weight = Motion.RollPose(input.roll.t / Motion.ROLL_TIME, input.roll.dir)
		for name, pose in pairs(rollPoses) do
			target[name] = (target[name] or CFrame.identity):Lerp(pose, weight)
		end
		rate = 60
		rolling = weight
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

	-- With a gun up, the hold keeps the chest square to the aim: the pelvis's turn (as posed
	-- this frame) comes back out at the waist -- MotionAnimator hands this to the hold through
	-- PoseLayers. Sprinting, the gun comes down and across the chest (the carry) and the chest
	-- keeps some of the lean. Tumbling in a roll, the chest goes round with the body.
	local pelvis = state.poses.LowerTorso
	local sprinting = if input.sprint then smoothstep((state.speed - 17) / 6) else 0
	state.chest = ((pelvis - pelvis.Position):Inverse()
		* CFrame.Angles(rad(-9) * sprinting, 0, 0)
		* CFrame.Angles(rad(-16) * sprinting, rad(26) * sprinting, rad(-8) * sprinting)):Lerp(CFrame.identity, rolling)
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
