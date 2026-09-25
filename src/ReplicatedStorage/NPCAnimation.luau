--!strict
-- What an NPC's body does, written down as data both sides of the network read.
--
-- There are no authored animation assets for aiming, shooting, reloading, flinching or
-- dying in this place, and inventing AnimationIds would only produce silent failures. So
-- everything past walking is procedural: short joint offsets, keyed over time, layered on
-- top of whatever the locomotion tracks are doing.
--
-- It lives in ReplicatedStorage because the SERVER needs the last frame of every death. A
-- body plays its death on each client, then the server turns it into a ragdoll -- and a
-- ragdoll starts from wherever the server thinks the limbs are. If the server's idea of the
-- pose differed from what players had just watched, every body would snap upright for a
-- frame before falling. Both read the same keys here, so the hand-off is seamless.
--
-- Conventions, derived from the rig rather than guessed: every R15 joint on the locked
-- ROBLOX Boy body has an identity C0 rotation, so offsets are in the parent part's own axes.
--   rx > 0  tips the child BACK (head up, torso leaning back, thigh forward, shin forward)
--   ry > 0  turns the child to ITS LEFT
--   rz > 0  rolls the top of the child to ITS LEFT
--   pz > 0  moves the child backwards; py < 0 lowers it
-- Knees therefore bend with NEGATIVE rx.

local NPCAnimation = {}

-- Which part each joint lives in, so a joint can be found by name AND class. This Roblox
-- build can put an AnimationConstraint with the same name beside a Motor6D.
NPCAnimation.JointPart = {
	Neck = "Head",
	Waist = "UpperTorso",
	Root = "LowerTorso",
	LeftShoulder = "LeftUpperArm",
	RightShoulder = "RightUpperArm",
	LeftHip = "LeftUpperLeg",
	RightHip = "RightUpperLeg",
	LeftKnee = "LeftLowerLeg",
	RightKnee = "RightLowerLeg",
	LeftAnkle = "LeftFoot",
	RightAnkle = "RightFoot",
}

-- Optional authored clips. Every slot is empty on purpose: REQUIRED ASSET -- NOT PROVIDED.
-- Paste an id you own and that moment plays the clip instead of the procedural version;
-- leave it empty and nothing changes. Aim, fire and reload are not here because the solved
-- weapon hold (WeaponPose / WeaponPoseHold / ReloadAnimator) already owns the arms.
NPCAnimation.Authored = {
	MeleeLight = "",
	MeleeHeavy = "",
	HitLight = "",
	HitHeavy = "",
	HitHead = "",
	DeathBackward = "",
	DeathForward = "",
	DeathSideways = "",
	DeathKnees = "",
	DeathStagger = "",
}

-- ------------------------------------------------------------------ helpers --

export type Key = { rx: number?, ry: number?, rz: number?, px: number?, py: number?, pz: number? }
export type Pose = { [string]: Key }

local FIELDS = { "rx", "ry", "rz", "px", "py", "pz" }

local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end
NPCAnimation.Smooth = smooth

--- One key as a CFrame. `scale` stretches the translation for a scaled body.
function NPCAnimation.ToCFrame(key: Key, scale: number?): CFrame
	local s = scale or 1
	return CFrame.new((key.px or 0) * s, (key.py or 0) * s, (key.pz or 0) * s)
		* CFrame.Angles(math.rad(key.rx or 0), math.rad(key.ry or 0), math.rad(key.rz or 0))
end

local function mirrorName(joint: string): string
	if joint:sub(1, 4) == "Left" then
		return "Right" .. joint:sub(5)
	elseif joint:sub(1, 5) == "Right" then
		return "Left" .. joint:sub(6)
	end
	return joint
end

--- Left for right: swap the limbs and flip the sideways components.
function NPCAnimation.Mirror(pose: Pose): Pose
	local out: Pose = {}
	for joint, key in pairs(pose) do
		out[mirrorName(joint)] = {
			rx = key.rx, ry = key.ry and -key.ry, rz = key.rz and -key.rz,
			px = key.px and -key.px, py = key.py, pz = key.pz,
		}
	end
	return out
end

--- Multiply every component of a pose, for reactions that share a shape but not a size.
function NPCAnimation.Scale(pose: Pose, amount: number): Pose
	local out: Pose = {}
	for joint, key in pairs(pose) do
		local k = {}
		for _, f in ipairs(FIELDS) do
			local v = (key :: any)[f]
			if v then
				k[f] = v * amount
			end
		end
		out[joint] = k :: any
	end
	return out
end

local function lerpKey(a: Key?, b: Key?, alpha: number): Key
	local out = {}
	for _, f in ipairs(FIELDS) do
		local va = a and (a :: any)[f] or 0
		local vb = b and (b :: any)[f] or 0
		if va ~= 0 or vb ~= 0 then
			out[f] = va + (vb - va) * alpha
		end
	end
	return out :: any
end

--- Sample a keyed clip at normalised time `t`. Keys are { t = 0..1, pose = Pose }, sorted.
function NPCAnimation.Sample(keys, t: number): Pose
	t = math.clamp(t, 0, 1)
	local prev, nextKey = keys[1], keys[#keys]
	for i = 1, #keys - 1 do
		if t >= keys[i].t and t <= keys[i + 1].t then
			prev, nextKey = keys[i], keys[i + 1]
			break
		end
	end
	local span = nextKey.t - prev.t
	local alpha = span > 0 and smooth((t - prev.t) / span) or 1
	local out: Pose = {}
	local seen = {}
	for joint in pairs(prev.pose) do
		seen[joint] = true
	end
	for joint in pairs(nextKey.pose) do
		seen[joint] = true
	end
	for joint in pairs(seen) do
		out[joint] = lerpKey(prev.pose[joint], nextKey.pose[joint], alpha)
	end
	return out
end

-- ------------------------------------------------------------------- deaths --
--
-- Five ways to go down. Each ends on a pose the ragdoll then takes over from, and `push`
-- says which way the body is thrown when it does -- in the NPC's own space.

NPCAnimation.Deaths = {
	Backward = {
		duration = 0.55,
		push = Vector3.new(0, 0, 1),
		keys = {
			{ t = 0, pose = {} },
			{ t = 0.35, pose = {
				Waist = { rx = 12 }, Neck = { rx = 16 },
				LeftKnee = { rx = -10 }, RightKnee = { rx = -8 },
			} },
			{ t = 1, pose = {
				Waist = { rx = 28 }, Neck = { rx = 30 }, Root = { rx = 8, py = -0.25 },
				LeftHip = { rx = 10 }, RightHip = { rx = 6 },
				LeftKnee = { rx = -22 }, RightKnee = { rx = -18 },
			} },
		},
	},

	Forward = {
		duration = 0.5,
		push = Vector3.new(0, 0, -1),
		keys = {
			{ t = 0, pose = {} },
			{ t = 0.4, pose = { Waist = { rx = -12 }, Neck = { rx = -12 }, LeftKnee = { rx = -12 }, RightKnee = { rx = -12 } } },
			{ t = 1, pose = {
				Waist = { rx = -32 }, Neck = { rx = -26 }, Root = { rx = -10, py = -0.35 },
				LeftHip = { rx = 18 }, RightHip = { rx = 14 },
				LeftKnee = { rx = -26 }, RightKnee = { rx = -22 },
			} },
		},
	},

	-- Authored falling to the body's LEFT. Mirrored for a fall to the right.
	Sideways = {
		duration = 0.5,
		push = Vector3.new(-1, 0, 0),
		keys = {
			{ t = 0, pose = {} },
			{ t = 0.4, pose = { Waist = { rz = 10, ry = 6 }, Neck = { rz = 8 }, LeftKnee = { rx = -14 } } },
			{ t = 1, pose = {
				Waist = { rz = 26, ry = 12 }, Neck = { rz = 20 }, Root = { rz = 9, py = -0.2 },
				LeftHip = { rx = 8 }, LeftKnee = { rx = -32 }, RightKnee = { rx = -8 },
			} },
		},
	},

	-- Drops onto both knees, then folds forward. The torso comes down by roughly the
	-- knee's height off the ground, so the shins land flat rather than through the floor.
	Knees = {
		duration = 1.0,
		push = Vector3.new(0, 0, -1),
		keys = {
			{ t = 0, pose = {} },
			{ t = 0.55, pose = {
				Root = { py = -1.0 }, Waist = { rx = -6 }, Neck = { rx = -10 },
				LeftHip = { rx = 4 }, RightHip = { rx = 4 },
				LeftKnee = { rx = -85 }, RightKnee = { rx = -85 },
				LeftAnkle = { rx = 40 }, RightAnkle = { rx = 40 },
			} },
			{ t = 1, pose = {
				Root = { py = -1.0, rx = -6 }, Waist = { rx = -32 }, Neck = { rx = -28 },
				LeftHip = { rx = 4 }, RightHip = { rx = 4 },
				LeftKnee = { rx = -85 }, RightKnee = { rx = -85 },
				LeftAnkle = { rx = 40 }, RightAnkle = { rx = 40 },
			} },
		},
	},

	-- Two short steps back under the impact, then over. The steps are a translation of the
	-- whole body relative to its anchored root, so they cost no physics at all.
	Stagger = {
		duration = 0.85,
		push = Vector3.new(0, 0, 1),
		keys = {
			{ t = 0, pose = {} },
			{ t = 0.3, pose = {
				Root = { pz = 0.7, rx = 6 }, Waist = { rx = 14 }, Neck = { rx = 10 },
				LeftHip = { rx = -18 }, RightHip = { rx = 22 }, RightKnee = { rx = -30 },
			} },
			{ t = 0.62, pose = {
				Root = { pz = 1.4, rx = 4 }, Waist = { rx = 20 }, Neck = { rx = 16 },
				LeftHip = { rx = 20 }, LeftKnee = { rx = -30 }, RightHip = { rx = -10 },
			} },
			{ t = 1, pose = {
				Root = { pz = 1.9, rx = 10, py = -0.2 }, Waist = { rx = 30 }, Neck = { rx = 28 },
				LeftKnee = { rx = -20 }, RightKnee = { rx = -24 },
			} },
		},
	},
}

--- The pose a death ends on, mirrored when asked. What the server writes before ragdolling.
function NPCAnimation.DeathFinal(style: string, mirror: boolean?): Pose
	local clip = NPCAnimation.Deaths[style] or NPCAnimation.Deaths.Backward
	local pose = clip.keys[#clip.keys].pose
	return mirror and NPCAnimation.Mirror(pose) or pose
end

-- ------------------------------------------------------------ hit reactions --
--
-- A reaction is a direction (where the hit came from) and a severity (how much it hurt).
-- The shape comes from the direction; the size and the duration from the severity. Every one
-- is a pulse: in fast, out slow, back to nothing -- none of them hold a pose.

local HIT_DIRECTION: { [string]: Pose } = {
	Front = { Waist = { rx = 8 }, Neck = { rx = 8 } },
	Back = { Waist = { rx = -8 }, Neck = { rx = -6 } },
	-- Struck on the left shoulder: that shoulder goes back, and the body leans away.
	Left = { Waist = { ry = 11, rz = -5 }, Neck = { ry = 6, rz = -4 } },
	Right = { Waist = { ry = -11, rz = 5 }, Neck = { ry = -6, rz = 4 } },
}

local HIT_SEVERITY = {
	Light = { size = 0.55, duration = 0.18 },
	Medium = { size = 1.0, duration = 0.28 },
	Heavy = { size = 1.6, duration = 0.42 },
	Stagger = { size = 2.1, duration = 0.7 },
}

function NPCAnimation.HitPose(kind: string, side: string): (Pose, number)
	if kind == "Head" then
		local back = side == "Back"
		return {
			Neck = { rx = back and -18 or 24, ry = side == "Left" and 8 or side == "Right" and -8 or 0 },
			Waist = { rx = back and -4 or 6 },
		}, 0.32
	end
	local severity = HIT_SEVERITY[kind] or HIT_SEVERITY.Light
	local pose = NPCAnimation.Scale(HIT_DIRECTION[side] or HIT_DIRECTION.Front, severity.size)
	if kind == "Heavy" or kind == "Stagger" then
		-- Big hits reach the legs: the knees give a little and the hips are driven back.
		local drive = (side == "Back") and -1 or 1
		pose.Root = { pz = 0.14 * severity.size * drive, py = -0.06 * severity.size }
		pose.LeftKnee = { rx = -7 * severity.size }
		pose.RightKnee = { rx = -7 * severity.size }
		pose.LeftHip = { rx = 4 * severity.size }
		pose.RightHip = { rx = 4 * severity.size }
	end
	return pose, severity.duration
end

--- In fast, out slow. `t` is 0..1 across the whole reaction.
function NPCAnimation.Pulse(t: number, attack: number?): number
	local a = attack or 0.18
	if t <= 0 or t >= 1 then
		return 0
	end
	if t < a then
		local x = t / a
		return 1 - (1 - x) * (1 - x)
	end
	return 1 - smooth((t - a) / (1 - a))
end

-- -------------------------------------------------------------------- melee --
--
-- A swing is windup, strike, recovery. Timings come from the archetype; this is only the
-- shape. Offsets on the shoulders apply on top of the tool-hold animation, so a positive
-- rx raises the already-forward arm up and back overhead.

local LIGHT_SWING = {
	{ t = 0, pose = {} },
	{ t = 0.45, pose = { RightShoulder = { rx = 55, rz = -10 }, Waist = { ry = -14 }, Neck = { ry = 4 } } },
	{ t = 0.62, pose = { RightShoulder = { rx = -30, rz = 8 }, Waist = { ry = 18, rx = -6 }, Root = { pz = -0.25 } } },
	{ t = 1, pose = {} },
}

local HEAVY_SWING = {
	{ t = 0, pose = {} },
	{ t = 0.5, pose = {
		RightShoulder = { rx = 140 }, LeftShoulder = { rx = 120 },
		Waist = { rx = 10, ry = -12 }, Neck = { rx = -4 },
	} },
	{ t = 0.66, pose = {
		RightShoulder = { rx = -45 }, LeftShoulder = { rx = -30 },
		Waist = { rx = -20, ry = 10 }, Root = { pz = -0.35, py = -0.15 },
		LeftKnee = { rx = -14 }, RightKnee = { rx = -10 },
	} },
	{ t = 1, pose = {} },
}

--- The pose `elapsed` seconds into a swing. The strike key lands exactly at the end of
--- the windup, which is the moment the server resolves the hit.
function NPCAnimation.SwingPose(elapsed: number, windup: number, recover: number, heavy: boolean): Pose?
	local total = windup + recover
	if elapsed < 0 or elapsed >= total then
		return nil
	end
	local keys = heavy and HEAVY_SWING or LIGHT_SWING
	local strikeKey = keys[3].t
	local t
	if elapsed <= windup then
		t = (elapsed / windup) * strikeKey
	else
		t = strikeKey + ((elapsed - windup) / recover) * (1 - strikeKey)
	end
	return NPCAnimation.Sample(keys, t)
end

-- ------------------------------------------------------------------- recoil --

-- How hard each class of weapon rocks the upper body per shot, in degrees at the waist.
NPCAnimation.RecoilByClass = {
	Pistol = 2.6,
	SMG = 1.4,
	Rifle = 2.0,
	Shotgun = 4.5,
	Sniper = 4.0,
	Marksman = 3.2,
}
NPCAnimation.RecoilDuration = 0.14

return NPCAnimation
