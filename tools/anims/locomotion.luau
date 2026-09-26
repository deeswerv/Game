--!nocheck
-- Turn the uploaded R6 movement clips (assets/animations/*.rbxm) into R15 tracks the game
-- plays itself -- the same way the emote pack is played, because a KeyframeSequence only
-- plays live once it has been published as an animation asset.
--
--   lune run tools/anims/locomotion.luau
--
-- Writes src/ReplicatedStorage/LocomotionData/<Clip>.luau, decoded by EmotePlayer and blended
-- by ReplicatedStorage.Locomotion.
--
-- R6 to R15. The clips were authored on the six-part R6 body; the game's characters are R15.
-- The two share their proportions where it matters -- hips a stud below the root, feet three
-- studs below it, two-stud legs -- so a pose carries straight across once it is re-expressed:
--
--   * Rotations. An R6 joint's pose is in that joint's own frame, and every R6 joint frame is
--     turned (the hips and shoulders a quarter turn about Y, the root and neck onto their
--     side). R15 joint frames are all square to the body. So each rotation is carried into
--     body space: pose15 = R * pose6 * R^-1, with R the R6 joint's C0 rotation.
--   * The torso. R6 turns its torso about the torso's centre; R15 turns the lower torso
--     about a point a stud below that. Re-rooted so the body moves exactly as authored:
--     root15 = P^-1 * M * P, with M the R6 torso's motion and P the R15 root joint's offset.
--   * Legs. R6 legs are rigid, so an animator bends a knee by sliding the whole leg up into
--     the body. Carried across as-is, that pulls an R15 thigh off its hip. Instead each foot
--     is put where the R6 foot was, and the knee is solved (two-bone IK) -- which is exactly
--     what the slide was standing in for. The knee bends the way the foot faces.
--   * Arms turn at the shoulder. The elbow and wrist are held straight, as R6 arms are.
--
-- Each clip also carries an `armed` variant of the torso and legs, with the torso's lean taken
-- out: a gun is aimed in torso space (WeaponPoseHold), so a sprint that pitches the chest
-- fifty degrees forward would point the weapon at the floor. The hips keep their turn and stay
-- where the clip put them, and the legs are re-solved to the same footfalls.

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local Codec = require("../emotes/codec")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local SOURCE = "assets/animations"
local OUT = "src/ReplicatedStorage/LocomotionData"
local CLIPS = { "Idle", "Run", "WalkLeft", "WalkRight", "WalkBackward" }

-- ---------------------------------------------------------------- the rigs --

-- R6's standard joints (every R6 body is built with exactly these).
local R6 = {
	Root = CFrame.new(0, 0, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	Neck = CFrame.new(0, 1, 0, -1, 0, 0, 0, 0, 1, 0, 1, 0),
	RightShoulder = CFrame.new(1, 0.5, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	LeftShoulder = CFrame.new(-1, 0.5, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	RightHipC0 = CFrame.new(1, -1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	RightHipC1 = CFrame.new(0.5, 1, 0, 0, 0, 1, 0, 1, 0, -1, 0, 0),
	LeftHipC0 = CFrame.new(-1, -1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
	LeftHipC1 = CFrame.new(-0.5, 1, 0, 0, 0, -1, 0, 1, 0, 1, 0, 0),
}

-- The game's own R15 body, read from the build so the solve fits it exactly.
local place = roblox.deserializePlace(fs.readFile("build/Game.rbxl"))
local character = place:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
assert(character, "no StarterCharacter in build/Game.rbxl -- build first")
local motor = {}
for _, d in character:GetDescendants() do
	if d:IsA("Motor6D") and d.Part1 then
		motor[d.Part1.Name] = d
	end
end
local function offset(name: string, which: string): Vector3
	return motor[name][which].Position
end

-- The root joint's pivot, relative to the root and to the lower torso.
local rootP = CFrame.new(offset("LowerTorso", "C0"))

-- One leg's rest geometry, in the lower torso's frame (square to the root at rest).
local function legOf(side: string)
	local upper, lower, foot = side .. "UpperLeg", side .. "LowerLeg", side .. "Foot"
	local hipInTorso = offset(upper, "C0")
	local b1 = offset(lower, "C0") - offset(upper, "C1")          -- hip to knee
	local b2 = offset(foot, "C0") - offset(lower, "C1")           -- knee to ankle
	local footPart = character:FindFirstChild(foot)
	local toSole = -offset(foot, "C1") - Vector3.new(0, footPart.Size.Y / 2, 0) -- ankle to sole
	-- Hip in root space at rest: the root pivot, back up the lower torso, out to the hip.
	local hip = offset("LowerTorso", "C0") - offset("LowerTorso", "C1") + hipInTorso
	local reach = b1 + b2
	-- Which side of the hip-to-ankle line the knee sits on at rest, as a direction. Carried
	-- through every solve by the foot's own turn, so a rest pose solves back to rest exactly.
	local along = reach.Unit
	local pole = (b1 - along * along:Dot(b1)).Unit
	return {
		hip = hip, hipInTorso = hipInTorso, b1 = b1, b2 = b2, toSole = toSole, pole = pole,
		l1 = b1.Magnitude, l2 = b2.Magnitude,
		upper = upper, lower = lower, foot = foot,
	}
end
local LEGS = { Right = legOf("Right"), Left = legOf("Left") }

-- The floor, in root space: a standing root is three studs up.
local FLOOR_Y = -3
-- How much of the R6 leg's tilt the foot keeps. An R6 leg is its own foot, so when it swings
-- forty degrees the "sole" does too; a real foot rolls much less than the leg swings.
local FOOT_TILT = 0.6

-- The eight corners of a foot, relative to its ankle, in the foot's own frame.
for _, leg in LEGS do
	local foot = character:FindFirstChild(leg.foot)
	local centre = -offset(leg.foot, "C1")
	leg.corners = {}
	for _, sx in { -1, 1 } do
		for _, sy in { -1, 1 } do
			for _, sz in { -1, 1 } do
				table.insert(leg.corners, centre + Vector3.new(foot.Size.X / 2 * sx, foot.Size.Y / 2 * sy, foot.Size.Z / 2 * sz))
			end
		end
	end
end

-- A foot turned only by the leg's heading, and then tipped back part of the way.
local function dampedFoot(legRot)
	local facing = legRot:VectorToWorldSpace(Vector3.new(0, 0, -1))
	local heading = (math.abs(facing.X) + math.abs(facing.Z) > 1e-4) and math.atan2(-facing.X, -facing.Z) or 0
	return CFrame.Angles(0, heading, 0):Lerp(legRot, FOOT_TILT)
end

-- Where the ankle goes for a foot whose sole centre should be at `sole`: lifted if any corner
-- of the foot block would otherwise be under the floor. The R6 clips dig their rigid legs a
-- third of a stud into the ground at full swing; on a real foot that is the toe through it.
local function ankleFor(leg, sole: Vector3, footRot): Vector3
	local ankle = sole - footRot * leg.toSole
	local lowest = math.huge
	for _, c in leg.corners do
		lowest = math.min(lowest, (ankle + footRot * c).Y)
	end
	if lowest < FLOOR_Y then
		ankle += Vector3.new(0, FLOOR_Y - lowest, 0)
	end
	return ankle
end

-- ------------------------------------------------------------------ maths --

local function rotationOnly(cf)
	return cf - cf.Position
end

-- A rotation carried from an R6 joint's frame into the body's.
local function carry(jointC0, pose)
	local r = rotationOnly(jointC0)
	return r * rotationOnly(pose) * r:Inverse()
end

-- An orthonormal frame from a direction and a second, roughly perpendicular one.
local function frame(a: Vector3, n: Vector3)
	local x = a.Unit
	local y = (n - x * x:Dot(n)).Unit
	local z = x:Cross(y)
	return CFrame.fromMatrix(Vector3.new(), x, y, z)
end

--- Where the leg's joints go for an ankle at `ankle` with the foot turned by `footRot`, with the
--- body's lower torso at `torso` (root space). Returns the hip, knee and ankle poses.
local function solveLeg(leg, torso, ankle: Vector3, footRot)
	local hip = torso * leg.hipInTorso
	local reach = ankle - hip
	local d = math.clamp(reach.Magnitude, math.abs(leg.l1 - leg.l2) + 1e-3, leg.l1 + leg.l2 - 1e-4)
	local along = reach.Unit
	local pole = footRot * leg.pole
	pole = pole - along * along:Dot(pole)
	if pole.Magnitude < 1e-4 then
		pole = torso:VectorToWorldSpace(Vector3.new(0, 0, -1))
		pole = pole - along * along:Dot(pole)
	end
	pole = pole.Unit
	local cosA = math.clamp((leg.l1 * leg.l1 + d * d - leg.l2 * leg.l2) / (2 * leg.l1 * d), -1, 1)
	local knee = hip + along * (leg.l1 * cosA) + pole * (leg.l1 * math.sqrt(1 - cosA * cosA))
	local reached = hip + along * d
	-- Each bone is turned from its rest direction onto its solved one, keeping the knee's
	-- bending plane: the rest plane is (b1, b2), the solved one (thigh, shin).
	local thigh, shin = knee - hip, reached - knee
	local restNormal = leg.b1:Cross(leg.b2)
	local normal = thigh:Cross(shin)
	if normal.Magnitude < 1e-5 then
		normal = torso:VectorToWorldSpace(Vector3.new(1, 0, 0))
	end
	local upperRot = frame(thigh, normal) * frame(leg.b1, restNormal):Inverse()
	local lowerRot = frame(shin, normal) * frame(leg.b2, restNormal):Inverse()
	local torsoRot = rotationOnly(torso)
	return torsoRot:Inverse() * upperRot, upperRot:Inverse() * lowerRot, lowerRot:Inverse() * footRot
end

-- ----------------------------------------------------------------- tracks --

local R6_JOINTS = { "Torso", "Head", "Right Arm", "Left Arm", "Right Leg", "Left Leg" }

--- The clip as R6 tracks (joint -> sorted { t, cf }), its length and whether it loops.
local function readClip(path: string)
	local list = roblox.deserializeModel(fs.readFile(path))
	local seq = list[1]
	assert(seq and seq:IsA("KeyframeSequence"), path .. " is not a KeyframeSequence")
	local tracks, times, seen = {}, {}, {}
	local length = 0
	for _, kf in seq:GetChildren() do
		if kf:IsA("Keyframe") then
			length = math.max(length, kf.Time)
			local key = math.floor(kf.Time * 1000 + 0.5)
			if not seen[key] then
				seen[key] = true
				table.insert(times, key / 1000)
			end
			for _, pose in kf:GetDescendants() do
				if pose:IsA("Pose") and table.find(R6_JOINTS, pose.Name) and pose.Weight > 0 then
					tracks[pose.Name] = tracks[pose.Name] or {}
					table.insert(tracks[pose.Name], { t = kf.Time, cf = pose.CFrame })
				end
			end
		end
	end
	table.sort(times)
	for _, list in tracks do
		table.sort(list, function(a, b)
			return a.t < b.t
		end)
	end
	return tracks, times, length, seq.Loop
end

-- Linear, like every key in these clips. Before the first key and after the last, held.
local function sample(track, t: number)
	if not track then
		return nil
	end
	if t <= track[1].t then
		return track[1].cf
	end
	for i = 2, #track do
		if t <= track[i].t then
			local a, b = track[i - 1], track[i]
			local span = b.t - a.t
			return a.cf:Lerp(b.cf, span > 0 and (t - a.t) / span or 1)
		end
	end
	return track[#track].cf
end

--- Every R15 joint pose for one moment of the clip, and the same with the torso upright.
local function poseAt(tracks, t: number)
	local full, armed = {}, {}
	local torso6 = sample(tracks["Torso"], t)
	-- The R6 torso's motion about the root, and the same motion re-rooted for R15.
	local m = torso6 and (R6.Root * torso6 * R6.Root:Inverse()) or CFrame.new()
	-- Upright -- the lean taken out, the turn kept -- with the hips where the clip put them.
	-- The turn stays because it is the lower body facing into a strafe; the gun arm is kept
	-- square to the aim by turning the chest back at the waist (Locomotion.WaistCounter).
	local facing = m:VectorToWorldSpace(Vector3.new(0, 0, -1))
	local yaw = (math.abs(facing.X) + math.abs(facing.Z) > 1e-4) and math.atan2(-facing.X, -facing.Z) or 0
	local hips = m * Vector3.new(0, -1, 0)
	local turned = CFrame.Angles(0, yaw, 0)
	local upright = CFrame.new(hips - turned * Vector3.new(0, -1, 0)) * turned
	if torso6 then
		full.LowerTorso = rootP:Inverse() * m * rootP
		armed.LowerTorso = rootP:Inverse() * upright * rootP
	end

	local head6 = sample(tracks["Head"], t)
	if head6 then
		full.Head = carry(R6.Neck, head6)
	end

	for _, side in { "Right", "Left" } do
		local arm6 = sample(tracks[side .. " Arm"], t)
		if arm6 then
			full[side .. "UpperArm"] = carry(R6[side .. "Shoulder"], arm6)
			full[side .. "LowerArm"] = CFrame.new()
			full[side .. "Hand"] = CFrame.new()
		end
		local leg6 = sample(tracks[side .. " Leg"], t)
		if leg6 then
			local leg = LEGS[side]
			-- Where the R6 foot is: the bottom of the rigid leg, wherever the pose put it.
			local legCf = m * R6[side .. "HipC0"] * leg6 * R6[side .. "HipC1"]:Inverse()
			local sole = legCf * Vector3.new(0, -1, 0)
			local footRot = dampedFoot(rotationOnly(legCf))
			local ankleAt = ankleFor(leg, sole, footRot)
			local restTorso = rootP * CFrame.new(-offset("LowerTorso", "C1"))
			for variant, body in { [full] = m, [armed] = upright } do
				local torso = body * restTorso
				local hip, knee, ankle = solveLeg(leg, torso, ankleAt, footRot)
				variant[leg.upper] = hip
				variant[leg.lower] = knee
				variant[leg.foot] = ankle
			end
		end
	end
	return full, armed
end

-- ------------------------------------------------------------------ write --

if not fs.isDir(OUT) then
	fs.writeDir(OUT)
end

local function block(frames, pick, indent: string): string
	local names = {}
	for name in frames[1].pose[pick] do
		table.insert(names, name)
	end
	table.sort(names)
	local lines = {}
	for _, name in names do
		local keys = {}
		for _, f in frames do
			table.insert(keys, { t = f.t, cf = f.pose[pick][name], style = 0, direction = 0 })
		end
		table.insert(lines, indent .. name .. " = " .. Codec.lua(Codec.encode(Codec.simplify(keys))) .. ",")
	end
	return table.concat(lines, "\n")
end

-- A rest pose must solve back to rest, or every clip starts from a twisted leg.
do
	local rest = CFrame.new()
	for side, leg in LEGS do
		local torso = rootP * CFrame.new(-offset("LowerTorso", "C1"))
		local hip, knee, ankle = solveLeg(leg, torso, leg.hip + leg.b1 + leg.b2, rest)
		for name, cf in { hip = hip, knee = knee, ankle = ankle } do
			assert(Codec.close(cf, rest), ("%s %s does not solve back to rest"):format(side, name))
		end
	end
end

local index = {}
for _, name in CLIPS do
	local tracks, times, length, loop = readClip(SOURCE .. "/" .. name .. ".rbxm")
	local frames = {}
	for _, t in times do
		local full, armed = poseAt(tracks, t)
		table.insert(frames, { t = t, pose = { full = full, armed = armed } })
	end
	local out = {
		"-- Generated by tools/anims/locomotion.luau from " .. SOURCE .. "/" .. name .. ".rbxm (R6, retargeted",
		"-- to R15). Do not edit; re-run the converter. Decoded by ReplicatedStorage.EmotePlayer.",
		"return {",
		("\tlength = %.3f,"):format(length),
		("\tloop = %s,"):format(tostring(loop == true)),
		"\tjoints = {",
		block(frames, "full", "\t\t"),
		"\t},",
	}
	if next(frames[1].pose.armed) then
		table.insert(out, "\t-- The torso upright, and the legs re-solved to the same footfalls, for when a gun is out.")
		table.insert(out, "\tarmed = {")
		table.insert(out, block(frames, "armed", "\t\t"))
		table.insert(out, "\t},")
	end
	table.insert(out, "}")
	fs.writeFile(OUT .. "/" .. name .. ".luau", table.concat(out, "\n") .. "\n")
	local joints = 0
	for _ in frames[1].pose.full do
		joints += 1
	end
	table.insert(index, name)
	print(("%-13s %.3fs %s, %d keyframes, %d joints"):format(name, length, loop and "loop" or "once", #times, joints))
end
