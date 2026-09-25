--!strict
-- Short, additive camera impulses: the jolt of firing, the thump of landing, the hit
-- you just took. Anything that wants to shove the view for a fraction of a second adds
-- an impulse here, and the camera script folds them all into one CFrame per frame.
--
-- Kept separate from recoil on purpose. Recoil is a lasting aim change the player has to
-- pull back down; this is decoration that always returns to zero, so the two must not be
-- the same number. Mixing them is how a gun ends up drifting the crosshair permanently.

local ViewKick = {}

type Impulse = {
	pitch: number,
	yaw: number,
	roll: number,
	sway: number,
	duration: number,
	elapsed: number,
	seed: number,
}

local impulses: { Impulse } = {}

-- A hard cap. A minigun firing into a crowd should not be able to queue a hundred live
-- impulses and turn the frame into a trigonometry benchmark.
local MAX_LIVE = 12

--- Add a one-shot camera shove.
--- pitch/yaw/roll are peak degrees; sway adds a small random wobble on top.
function ViewKick.Punch(pitch: number, yaw: number, roll: number, duration: number, sway: number?)
	if #impulses >= MAX_LIVE then
		table.remove(impulses, 1)
	end
	table.insert(impulses, {
		pitch = pitch,
		yaw = yaw,
		roll = roll,
		sway = sway or 0,
		duration = math.max(duration, 0.01),
		elapsed = 0,
		seed = math.random() * 1000,
	})
end

-- Presets, so callers describe the event rather than tuning six numbers at the call site.
function ViewKick.Fire(strength: number)
	local s = math.clamp(strength, 0.2, 3)
	ViewKick.Punch(0.85 * s, (math.random() - 0.5) * 0.7 * s, (math.random() - 0.5) * 0.9 * s, 0.13, 0.25 * s)
end

function ViewKick.Land(strength: number)
	local s = math.clamp(strength, 0.2, 2.5)
	ViewKick.Punch(-1.9 * s, 0, (math.random() - 0.5) * 0.6 * s, 0.28, 0)
end

function ViewKick.Hurt(strength: number)
	local s = math.clamp(strength, 0.3, 2.5)
	ViewKick.Punch((math.random() - 0.5) * 2.4 * s, (math.random() - 0.5) * 2.4 * s, (math.random() - 0.5) * 2.0 * s, 0.34, 0.8 * s)
end

function ViewKick.Melee(strength: number)
	local s = math.clamp(strength, 0.2, 2.5)
	ViewKick.Punch(1.1 * s, 0, (math.random() - 0.5) * 1.6 * s, 0.2, 0.3 * s)
end

-- Where the camera has actually been pushed to so far. Everything below works in
-- absolute angles and then hands back only the change since last frame -- see Consume.
local appliedPitch, appliedYaw, appliedRoll = 0, 0, 0

-- Absolute recoil offset, owned by the weapon script (see SetAimOffset).
local aimPitch, aimYaw = 0, 0
local bobPitch, bobYaw, bobRoll = 0, 0, 0

--- Advance every live impulse and return their combined absolute offset for this frame.
local function sampleImpulses(dt: number): (number, number, number)
	if #impulses == 0 then
		return 0, 0, 0
	end

	local pitch, yaw, roll = 0, 0, 0

	for i = #impulses, 1, -1 do
		local imp = impulses[i]
		imp.elapsed += dt
		local a = imp.elapsed / imp.duration
		if a >= 1 then
			table.remove(impulses, i)
		else
			-- Snap out, ease back: a fast rise over the first fifth, then a smooth decay.
			-- A plain linear fade reads as mushy, which is the usual reason a gun with the
			-- right numbers still feels like it has no punch.
			local envelope
			if a < 0.2 then
				envelope = a / 0.2
			else
				local b = (a - 0.2) / 0.8
				envelope = (1 - b) * (1 - b)
			end

			pitch += imp.pitch * envelope
			yaw += imp.yaw * envelope
			roll += imp.roll * envelope

			if imp.sway > 0 then
				local t = imp.seed + imp.elapsed * 42
				pitch += math.sin(t) * imp.sway * envelope
				yaw += math.cos(t * 1.37) * imp.sway * envelope
			end
		end
	end

	return pitch, yaw, roll
end

--- Advance everything and return the rotation to apply to the camera THIS frame.
---
--- The delta, not the absolute offset. Roblox's camera module does not rebuild its CFrame
--- from scratch here -- measured, not assumed: applying a constant 3 degrees for six
--- frames leaves the camera eighteen degrees off, and it never comes back. So writing the
--- absolute offset every frame would accumulate into a permanent aim drift. Handing back
--- only the change means the pushes sum to zero across the life of an impulse and the
--- camera returns to exactly where the player was pointing it.
function ViewKick.Consume(dt: number): CFrame
	local kp, ky, kr = sampleImpulses(dt)

	local wantPitch = kp + aimPitch + bobPitch
	local wantYaw = ky + aimYaw + bobYaw
	local wantRoll = kr + bobRoll

	local dp = wantPitch - appliedPitch
	local dy = wantYaw - appliedYaw
	local dr = wantRoll - appliedRoll

	appliedPitch, appliedYaw, appliedRoll = wantPitch, wantYaw, wantRoll

	if math.abs(dp) < 1e-5 and math.abs(dy) < 1e-5 and math.abs(dr) < 1e-5 then
		return CFrame.identity
	end
	return CFrame.Angles(math.rad(dp), math.rad(dy), math.rad(dr))
end

-- ------------------------------------------------------------------- aim offset --

--- Recoil, published by the weapon script as an absolute angle in degrees.
---
--- Kept separate from the impulses because it is a lasting aim change the shooter has to
--- pull back down, whereas an impulse always returns by itself. Both are folded into the
--- same delta in Consume, so the two can never fight over the camera.
function ViewKick.SetAimOffset(pitch: number, yaw: number)
	aimPitch = pitch
	aimYaw = yaw
end

--- Walk bob, published by the bob controller as an absolute angle in degrees.
---
--- Absolute rather than an impulse, for the reason Consume documents: an impulse decays to
--- zero by itself, but bob is a continuous offset that has to be able to sit at a non-zero
--- value frame after frame. Feeding it through the same absolute-to-delta conversion as
--- recoil means it can never accumulate into permanent aim drift, and it costs the camera
--- exactly one writer -- still Consume.
function ViewKick.SetBobOffset(pitch: number, yaw: number, roll: number)
	bobPitch = pitch
	bobYaw = yaw
	bobRoll = roll
end

--- Drop everything immediately -- used on respawn so a death shake does not carry over.
--- The applied state is deliberately left alone: the next Consume then returns the delta
--- back to zero, which unwinds whatever was still on the camera rather than stranding it.
function ViewKick.Clear()
	table.clear(impulses)
	aimPitch, aimYaw = 0, 0
	bobPitch, bobYaw, bobRoll = 0, 0, 0
end

return ViewKick
