--!strict
-- How the people who stand still for a living hold themselves: shop clerks and quest givers
-- (NPCService.Outfit figures). Pure: every function returns joint poses by the name of the
-- part each joint moves -- the same convention as ReplicatedStorage.Motion -- for
-- StaffLife.client to write as C0 = rest * pose. Nothing here touches an instance, so the
-- poses can be checked and drawn outside the game (tools/mapview/poses.luau).
--
-- The rig's joint frames are axis-aligned: the body faces -Z, its right is +X. A positive X
-- turn swings a hanging limb forward (and tips a head up, and leans a chest back); a positive
-- Z turn swings a right arm out to the side (a left arm in).
--
--   Idle      breathing, a slow shift of weight, arms easy; a clerk stands with their hands
--             folded in front of them.
--   HandsUp   a robbery: the jolt, both hands thrown up beside the head and held there,
--             shaking, leaning away.
--   Talk      telling you something: one hand making the point, the other following.
--   Wave      a hello.

local StaffPose = {}

export type Poses = { [string]: CFrame }

local rad, sin = math.rad, math.sin

-- How long the jolt at the start of a robbery lasts, and how long the hands take to go up.
StaffPose.FLINCH = 0.45
StaffPose.RAISE = 0.32
-- A wave, start to finish.
StaffPose.WAVE = 1.6

local function smoothstep(x: number): number
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

-- Up past the mark and back: hands thrown up, not lifted.
local function overshoot(x: number): number
	x = math.clamp(x, 0, 1)
	local s = 1.9
	local y = x - 1
	return 1 + y * y * ((s + 1) * y + s)
end

--- At rest. `t` is a running clock; `seed` keeps two people from breathing in step. `style`
--- "folded" is a clerk's: hands together in front.
function StaffPose.Idle(t: number, seed: number, style: string?): Poses
	local breath = sin(t * 1.7 + seed)
	local sway = sin(t * 0.37 + seed * 2.3)
	local poses: Poses = {
		LowerTorso = CFrame.new(0, 0.015 * breath, 0) * CFrame.Angles(0, rad(2) * sway, rad(0.8) * sway),
		UpperTorso = CFrame.Angles(rad(1.4) * breath, rad(-1.2) * sway, 0),
		LeftUpperLeg = CFrame.Angles(0, 0, rad(-0.8) * sway),
		RightUpperLeg = CFrame.Angles(0, 0, rad(-0.8) * sway),
	}
	for _, side in ipairs({ "Left", "Right" }) do
		local out = if side == "Right" then 1 else -1
		if style == "folded" then
			-- Upper arms a little forward and in, forearms across: the hands meet at the belt.
			-- (The turn in comes after the swing forward: turned first, it only twists the arm.)
			poses[side .. "UpperArm"] = CFrame.Angles(rad(10 + 1.5 * breath), 0, out * rad(-4))
			poses[side .. "LowerArm"] = CFrame.Angles(0, out * rad(48), 0) * CFrame.Angles(rad(70), 0, 0)
			poses[side .. "Hand"] = CFrame.identity
		else
			poses[side .. "UpperArm"] = CFrame.Angles(rad(3 + 1.5 * breath), 0, out * rad(5))
			poses[side .. "LowerArm"] = CFrame.Angles(rad(12), 0, 0)
			poses[side .. "Hand"] = CFrame.identity
		end
	end
	return poses
end

--- Hands up, `since` seconds into it. `t` is the running clock (for the shaking).
function StaffPose.HandsUp(since: number, t: number): Poses
	local up = overshoot(since / StaffPose.RAISE)
	-- The jolt: up on the toes and back, then settling into a slight crouch.
	local jolt = if since < StaffPose.FLINCH then sin(math.pi * since / StaffPose.FLINCH) else 0
	local settle = smoothstep((since - 0.2) / 0.6)
	local shake = sin(t * 41) * 0.6 + sin(t * 27 + 1.3) * 0.4
	local poses: Poses = {}
	-- Knees give a little; the hips drop to match (CrouchAngles for 0.12 studs, by hand).
	local hip = rad(22) * settle
	poses.LowerTorso = CFrame.new(0, 0.1 * jolt - 0.12 * settle, 0.12 * jolt) * CFrame.Angles(rad(4) * jolt, 0, 0)
	poses.UpperTorso = CFrame.Angles(rad(7) * settle + rad(10) * jolt + rad(0.6) * shake, 0, 0)
	for _, side in ipairs({ "Left", "Right" }) do
		local out = if side == "Right" then 1 else -1
		poses[side .. "UpperLeg"] = CFrame.Angles(hip, 0, 0)
		poses[side .. "LowerLeg"] = CFrame.Angles(-2 * hip, 0, 0)
		poses[side .. "Foot"] = CFrame.Angles(hip, 0, 0)
		-- Upper arm out to the side, near level and a touch forward; the forearm straight up
		-- from the elbow, a little out; palms to the robber.
		local abduct = rad(82) * up
		local forward = rad(18) * up
		local elbow = rad(92) * up
		local tremble = rad(2.2) * shake * up
		poses[side .. "UpperArm"] = CFrame.Angles(0, out * forward, 0) * CFrame.Angles(tremble, 0, out * (abduct + tremble))
		poses[side .. "LowerArm"] = CFrame.Angles(0, 0, out * elbow)
		poses[side .. "Hand"] = CFrame.Angles(rad(-18) * up, 0, 0)
	end
	return poses
end

--- Mid-conversation, `t` seconds in.
function StaffPose.Talk(t: number): Poses
	local beat = sin(t * 2.6)
	local beat2 = sin(t * 1.9 + 1.1)
	return {
		RightUpperArm = CFrame.Angles(rad(30 + 12 * beat), 0, rad(10)),
		RightLowerArm = CFrame.Angles(0, rad(22), 0) * CFrame.Angles(rad(66 + 24 * math.max(0, beat)), 0, 0),
		RightHand = CFrame.Angles(rad(-14 * beat), 0, rad(10)),
		LeftUpperArm = CFrame.Angles(rad(12 + 6 * beat2), 0, rad(-8)),
		LeftLowerArm = CFrame.Angles(0, rad(-12), 0) * CFrame.Angles(rad(34 + 14 * math.max(0, beat2)), 0, 0),
		UpperTorso = CFrame.Angles(rad(-2) - rad(2) * math.max(0, beat), rad(4) * beat2, 0),
	}
end

--- A wave, `t` seconds in (0 .. WAVE): the right arm up, the hand going side to side.
function StaffPose.Wave(t: number): Poses
	local w = smoothstep(t / 0.3) * (1 - smoothstep((t - (StaffPose.WAVE - 0.35)) / 0.35))
	local wag = sin(t * 11) * w
	return {
		RightUpperArm = CFrame.Angles(rad(20) * w, 0, rad(150) * w),
		RightLowerArm = CFrame.Angles(0, 0, rad(-20) * w + rad(22) * wag),
		RightHand = CFrame.Angles(rad(-10) * w, 0, rad(8) * wag),
		UpperTorso = CFrame.Angles(0, 0, rad(-3) * w),
	}
end

--- `a` toward `b` by `w` (0..1), joint by joint; a joint only one side has is blended with
--- standing straight.
function StaffPose.Blend(a: Poses, b: Poses, w: number): Poses
	if w <= 0 then
		return a
	end
	local out: Poses = {}
	for name, pose in pairs(a) do
		out[name] = pose:Lerp(b[name] or CFrame.identity, w)
	end
	for name, pose in pairs(b) do
		if not out[name] then
			out[name] = CFrame.identity:Lerp(pose, w)
		end
	end
	return out
end

--- Where the head turns to look along `dir` (in the body's own frame), kept to what a neck can
--- do: `maxYaw` either way, and a little up or down.
function StaffPose.Look(dir: Vector3, maxYaw: number?): (number, number)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 1e-3 then
		return 0, 0
	end
	local limit = maxYaw or rad(70)
	local yaw = math.clamp(math.atan2(-dir.X, -dir.Z), -limit, limit)
	local pitch = math.clamp(math.atan2(dir.Y, flat.Magnitude), rad(-25), rad(30))
	return yaw, pitch
end

--- The neck's pose for a look: turned `yaw`, tipped `pitch`.
function StaffPose.Neck(yaw: number, pitch: number): CFrame
	return CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
end

return StaffPose
