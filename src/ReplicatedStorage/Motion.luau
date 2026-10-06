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
--             sprint (all of it further). The stride fits the speed so planted feet stay
--             planted, and the hips sit as high as the planted leg reaches, so the feet stay on
--             the floor; the body leans into it (hard when sprinting), the arms pump from the
--             shoulder with the elbows bent, the hips turn with the swinging leg and the chest
--             back against them, a strafe turns the hips and legs into it (the chest stays to
--             the front), backing up plays the cycle in reverse. With a gun out the hold keeps
--             the chest square to the aim (`state.chest`), and a sprint drops the gun into a
--             carry across the body.
--   crouch    hips down, knees bent, feet kept flat under you; walking crouched is a shorter,
--             lower stride
--   air       knees tucked, arms up and out for balance
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

Motion.EASE = 16                  -- how fast the joints ease toward the pose, per second
-- The hips and legs ease faster: the hips' height is worked out from where the legs are, so
-- the more the two lag behind the pose, the further a planted foot sinks or floats.
Motion.LEG_EASE = 45
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
-- The waist C0 MotionAnimator wrote this frame, by joint (client only), so HeadLook can turn
-- the chest toward the camera on top of the gait's own chest pose instead of replacing it.
Motion.Waist = (setmetatable({}, { __mode = "k" }) :: any) :: { [Motor6D]: CFrame }
-- Characters MotionAnimator posed last frame (client only). Another script with movement of
-- its own for one of them -- NPCAnimator's flinches, recoil and swings -- publishes it in
-- Motion.Offsets instead of writing the joints, and MotionAnimator folds it in under the gait.
Motion.Posing = (setmetatable({}, { __mode = "k" }) :: any) :: { [Model]: boolean }
-- Joint offsets by character, then by the part each joint moves.
Motion.Offsets = (setmetatable({}, { __mode = "k" }) :: any) :: { [Model]: { [string]: CFrame } }

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
local LEGS = {
	LowerTorso = true, LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
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
	{ t = 0.00, thigh = 26, knee = 4, foot = 14 },
	{ t = 0.12, thigh = 16, knee = 18, foot = 0 },
	{ t = 0.36, thigh = -8, knee = 6, foot = 0 },
	{ t = 0.56, thigh = -26, knee = 20, foot = -28 },
	{ t = 0.72, thigh = -6, knee = 60, foot = -14 },
	{ t = 0.88, thigh = 24, knee = 22, foot = 4 },
} }
-- A run: the foot lands ahead, the knee soaks the weight, the toes drive off, the heel kicks up
-- behind, the knee drives through high, the shin swings out to reach -- and both feet are off
-- the ground in between. A short contact and a long, bounding stride: the Roblox Boy's legs
-- are short for his body, so a run built on a human's proportions reads as a jog on him.
local RUN: Cycle = { stance = 0.3, keys = {
	{ t = 0.00, thigh = 36, knee = 16, foot = 8 },
	{ t = 0.12, thigh = 12, knee = 44, foot = 0 },
	{ t = 0.30, thigh = -42, knee = 16, foot = -44 },
	{ t = 0.48, thigh = -16, knee = 122, foot = -40 },
	{ t = 0.68, thigh = 64, knee = 104, foot = -16 },
	{ t = 0.86, thigh = 54, knee = 36, foot = 4 },
} }
-- A sprint: everything further -- a longer reach, a harder drive, the heel right up.
local SPRINT: Cycle = { stance = 0.27, keys = {
	{ t = 0.00, thigh = 42, knee = 14, foot = 8 },
	{ t = 0.11, thigh = 16, knee = 38, foot = 0 },
	{ t = 0.27, thigh = -48, knee = 14, foot = -50 },
	{ t = 0.45, thigh = -20, knee = 138, foot = -44 },
	{ t = 0.66, thigh = 76, knee = 112, foot = -18 },
	{ t = 0.85, thigh = 62, knee = 36, foot = 6 },
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

--- How far the foot travels back under the hip while it is on the ground, for a cycle: the
--- distance the body must cover in that time for the planted foot not to slide.
local function sweepOf(cycle: Cycle): number
	local function ahead(t: number): number
		local thigh, knee = sample(cycle, t)
		return THIGH * sin(thigh) + SHIN * sin(thigh - knee)
	end
	return ahead(0) - ahead(cycle.stance)
end
local SWEEP = { walk = sweepOf(WALK), run = sweepOf(RUN), sprint = sweepOf(SPRINT) }
Motion.SWEEP = SWEEP

--- The gait at `speed` (studs a second), and the stride that fits it.
---
--- How much it is moving at all, and in which gait: a walk turns into a run between 9 and 15,
--- a run into a sprint past 17 with sprint held (crouched, or backing up, it stays nearer a
--- walk). Then the stride and its frequency, the way a body chooses them: each gait has a
--- natural cadence that rises a little with speed, and the stride stretches or shortens until
--- the planted foot sweeps back under the hips exactly as fast as the body goes over it -- so
--- the feet stay planted. Past the longest stride a gait has, the cadence rises instead.
--- Returns move, runW, sprintW, the stride (scales every leg angle) and cycles a second.
function Motion.Gait(speed: number, sprinting: boolean, crouch: number, back: number): (number, number, number, number, number)
	local move = smoothstep(speed / 5)
	local runW = smoothstep((speed - 9) / 6)
	local sprintW = if sprinting then smoothstep((speed - 17) / 6) else 0
	runW *= (1 - crouch) * (1 - 0.6 * back)
	sprintW *= (1 - crouch) * (1 - back)
	local natural = 1.5 + 0.09 * speed
	natural += (1.45 + 0.048 * speed - natural) * runW
	natural += (1.5 + 0.045 * speed - natural) * sprintW
	natural *= 1 + 0.12 * crouch
	local sweep = SWEEP.walk + (SWEEP.run - SWEEP.walk) * runW
	sweep += (SWEEP.sprint - sweep) * sprintW
	local stance = WALK.stance + (RUN.stance - WALK.stance) * runW
	stance += (SPRINT.stance - stance) * sprintW
	local longest = 1.25 * (1 - 0.15 * crouch) * (1 - 0.2 * back)
	local stride = math.clamp(speed * stance / (natural * sweep), 0.3, longest)
	local frequency = math.clamp(speed * stance / (sweep * stride), 0.9, 3.2)
	return move, runW, sprintW, stride * move, frequency
end

--- How far below the hip the lowest corner of the foot is, for a leg at these world angles.
local function legReach(thigh: number, knee: number, foot: number): number
	local tip = if foot < 0 then TOE * sin(-foot) else HEEL * sin(foot)
	return THIGH * cos(thigh) + SHIN * cos(thigh - knee) + SOLE * cos(foot) + tip
end

--- The body on its feet (or in the air) for the smoothed state. Also returns the pelvis's turn
--- (lean, bank and twist, without the bob), which the gun hold takes back out of the chest.
local function groundPose(state: State, input: Input): ({ [string]: CFrame }, CFrame)
	local speed = state.speed
	local crouch = state.crouch
	local air, land = state.air, state.land
	local armed = input.armed

	-- Which way the legs travel. Backing up is the forward cycle played in reverse.
	local dir = state.dir
	local forwardness = -dir.Z
	local back = smoothstep((-forwardness - 0.25) / 0.5)
	local travel = if back > 0.5 then -dir else dir
	-- How much it is moving, in which gait, and how long the stride is.
	local move, runW, sprintW, stride = Motion.Gait(speed, input.sprint, crouch, back)
	-- Going sideways, the hips turn toward the way the legs travel and the legs and feet turn
	-- further, so the legs run rather than swinging out to the side like a jumping jack; the
	-- chest turns back to face the front. (Faded out where backing up and stepping sideways
	-- meet, where the legs' way of going flips over.)
	local travelYaw = math.atan2(-travel.X, -travel.Z)
	local turnIn = move * smoothstep(math.abs(back - 0.5) / 0.25)
	local hipYaw = math.clamp(0.5 * travelYaw, -rad(40), rad(40)) * turnIn
	local legYaw = math.clamp(0.7 * travelYaw, -rad(60), rad(60)) * turnIn
	local legFrame = CFrame.Angles(0, legYaw, 0)
	local axis = stepAxis(legFrame:VectorToObjectSpace(travel))

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
	stance += (SPRINT.stance - stance) * sprintW
	local flight = 0
	for _, leg in pairs(legs) do
		if leg.t >= stance and leg.t < 0.5 then
			flight = math.max(flight, sin(math.pi * (leg.t - stance) / (0.5 - stance)))
		end
	end
	local lift = flight * (0.1 * runW + 0.06 * sprintW) * stride
	local breathe = 0.03 * sin(state.time * 2.2) * (1 - move)
	local height = (reach - REST_LEG) * (1 - air) + lift + breathe - 0.12 * air

	-- Lean into the run (harder sprinting, less with a gun up), bank into a strafe, and turn
	-- the hips with the leg that is swinging through.
	local leanDeg = 3 * move + 12 * runW + 5 * sprintW + 10 * crouch
	if armed then
		leanDeg *= 0.75
	end
	local lean = rad(leanDeg) * (0.35 + 0.65 * math.max(forwardness, 0))
	local bank = rad(6) * dir.X * runW
	-- (+1 when the left leg is furthest forward: a smooth swing that never stalls at the ends.)
	local swing = math.cos(2 * math.pi * (legs.Left.t - 0.94)) * move
	local twist = -rad(6 + 3 * runW) * swing * (0.4 + 0.6 * math.abs(dir.Z))
	local pelvis = CFrame.Angles(0, hipYaw + twist, 0) * CFrame.Angles(-lean, 0, -bank)

	local poses: { [string]: CFrame } = {}
	poses.LowerTorso = CFrame.new(0, height, 0) * pelvis
	-- The legs hang straight down in the world, whatever the pelvis is doing, then swing.
	local unturn = pelvis:Inverse()
	for _, side in ipairs({ "Left", "Right" }) do
		local leg = legs[side]
		local spread = (if side == "Left" then -1 else 1) * rad(2 + 3 * crouch)
		local thigh = legFrame * around(axis, leg.thigh) * CFrame.Angles(0, 0, spread)
		local knee = CFrame.Angles(-leg.knee, 0, 0)
		poses[side .. "UpperLeg"] = unturn * thigh
		poses[side .. "LowerLeg"] = knee
		-- The sole at its own pitch in the world, pointing the way the leg is turned: whatever
		-- the thigh and shin are doing, taken back out.
		poses[side .. "Foot"] = (thigh * knee):Inverse() * legFrame * CFrame.Angles(leg.foot, 0, 0)
	end

	-- Arms (no gun): each swings from the shoulder with the opposite leg, a smooth pendulum.
	-- Walking, loose and nearly straight. Running, a real pump: the elbow bent past a right
	-- angle, the hand coming up to the chest in front and the elbow driving well back behind.
	-- The swing is centred on straight down in the WORLD: leaning the body forward tips the
	-- shoulders with it, and without taking that back out the arms hang behind and never come
	-- through in front -- the bent forearm just sticks out level, like a jab. The elbow closes
	-- as the arm comes forward and opens as it goes back, the hand comes a little in across the
	-- body at the front, and the fist is curled at the wrist (the Roblox Boy's hands are big:
	-- held straight out at the end of a bent arm they read as a block pointing forward).
	local armS = swing / math.max(move, 1e-3)
	local facingSwing = 0.35 + 0.65 * math.abs(dir.Z)
	for _, side in ipairs({ "Left", "Right" }) do
		local out = if side == "Left" then -1 else 1
		local s = (if side == "Right" then armS else -armS) * move
		local fwd, bwd = math.max(s, 0), math.max(-s, 0)
		local reachF = rad(18 + 22 * runW + 12 * sprintW)
		local reachB = rad(16 + 20 * runW + 14 * sprintW)
		-- In the air the stride stops (the phase holds), so the pump eases out into arms up and
		-- out for balance, elbows soft -- not one fist frozen up in front.
		local ground = 1 - 0.8 * air
		local pitch = lean + (reachF * fwd - reachB * bwd) * facingSwing * ground + rad(42) * air + rad(10) * crouch
		local elbow = (rad(10) + rad(8) * move + rad(50) * runW + rad(14) * sprintW
			+ (rad(8) * move + rad(18) * runW + rad(8) * sprintW) * fwd - rad(14) * runW * bwd) * ground
			+ rad(24) * air
		local spread = rad(6 + 34 * air) + rad(3) * (1 - move) + rad(4) * runW
		local across = rad(8) * fwd * runW
		poses[side .. "UpperArm"] = CFrame.Angles(pitch, 0, out * (spread - across))
		poses[side .. "LowerArm"] = CFrame.Angles(elbow + rad(20) * crouch, 0, 0)
		poses[side .. "Hand"] = CFrame.Angles(-0.25 * elbow, 0, 0)
	end
	-- The chest turns back against the hips (and rounds a little crouched).
	poses.UpperTorso = CFrame.Angles(rad(-6) * crouch + rad(2) * sin(state.time * 2.2) * (1 - move), -twist * 1.25 - hipYaw, 0)
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
	-- The stride's frequency follows the speed, so that a planted foot stays planted: in stance
	-- the body covers exactly the distance the foot sweeps back under it (Motion.Gait).
	local backing = smoothstep((state.dir.Z - 0.25) / 0.5)
	local _, _, _, _, frequency = Motion.Gait(state.speed, input.sprint, state.crouch, backing)
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
	local rate, legRate = Motion.EASE, Motion.LEG_EASE
	local exactRoot = false
	if input.roll and input.roll.t >= 0 and input.roll.t < Motion.ROLL_TIME then
		local rollPoses, weight = Motion.RollPose(input.roll.t / Motion.ROLL_TIME, input.roll.dir)
		for name, pose in pairs(rollPoses) do
			target[name] = (target[name] or CFrame.identity):Lerp(pose, weight)
		end
		rate, legRate = 60, 60
		rolling = weight
		exactRoot = true
	end

	local k = 1 - math.exp(-rate * dt)
	local kLeg = 1 - math.exp(-legRate * dt)
	for _, name in ipairs(Motion.JOINTS) do
		local want = target[name] or CFrame.identity
		-- The roll's full turn cannot be eased toward (a lerp takes the short way round), so
		-- the root follows it exactly while rolling.
		if name == "LowerTorso" and exactRoot then
			state.poses[name] = want
		else
			state.poses[name] = state.poses[name]:Lerp(want, if LEGS[name] then kLeg else k)
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
