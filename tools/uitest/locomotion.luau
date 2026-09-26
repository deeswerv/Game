--!nocheck
-- The movement clips (LocomotionData, Locomotion, LocomotionAnimator), checked without Studio:
--
--   * every clip converted, and the R6-to-R15 carry is sound: no foot goes through the floor,
--     feet come down to it, and the gun-out variant has no lean left in it;
--   * the mix follows the direction of travel and fades in with speed, and the stride keeps
--     pace with the ground;
--   * on a live rig: standing breathes only the arms, running moves the legs and leans the
--     body, the head is kept level through the lean, a gun leaves the arms alone and turns
--     the chest back on a strafe, and a jump or an emote hands the body back.
--
--   lune run tools/uitest/locomotion.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local Rig = require("./rig")
local R = World.R
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

require("@lune/task").delay(120, function()
	print("\27[31mtimed out\27[0m")
	require("@lune/process").exit(2)
end)

local failures = 0
local function check(ok: boolean, what: string)
	if ok then
		print("  ok    " .. what)
	else
		failures += 1
		print("\27[31m  FAIL  " .. what .. "\27[0m")
	end
end

local place = World.loadPlace("build/Game.rbxl")
local rs = World.service("ReplicatedStorage")
local Locomotion = World.require(rs.Locomotion)
local EmotePlayer = World.require(rs.EmotePlayer)

local function degrees(cf)
	local x, y, z = cf:ToEulerAnglesYXZ()
	return math.deg(x), math.deg(y), math.deg(z)
end

-- ------------------------------------------------------------------ clips --

print("the clips")
local clips = Locomotion.Clips()
local names = {}
for _, name in ipairs(Locomotion.CLIPS) do
	if clips[name] then
		table.insert(names, name)
	end
end
check(#names == 5, "all five clips are in the build (" .. table.concat(names, ", ") .. ")")
check(clips.Run and clips.Run.full.loop and math.abs(clips.Run.full.length - 0.667) < 0.01, "the run loops every 0.67s")

-- Forward kinematics on the game's own rig, root three studs up as a live one stands.
local source = place:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
local motorOf = {}
for _, d in ipairs(source:GetDescendants()) do
	if d:IsA("Motor6D") and d.Part1 then
		motorOf[d.Part1.Name] = d
	end
end
local function solePositions(poses)
	local placed = { HumanoidRootPart = CFrame.new(0, 3, 0) }
	local function at(name)
		if placed[name] then
			return placed[name]
		end
		local m = motorOf[name]
		local cf = at(m.Part0.Name) * m.C0 * (poses[name] or CFrame.new()) * m.C1:Inverse()
		placed[name] = cf
		return cf
	end
	local out = {}
	for _, side in ipairs({ "Right", "Left" }) do
		local foot = source:FindFirstChild(side .. "Foot")
		local cf = at(side .. "Foot")
		-- The lowest corner of the foot block.
		local lowest = math.huge
		for _, sx in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				for _, sz in ipairs({ -1, 1 }) do
					local p = cf * Vector3.new(foot.Size.X / 2 * sx, foot.Size.Y / 2 * sy, foot.Size.Z / 2 * sz)
					lowest = math.min(lowest, p.Y)
				end
			end
		end
		out[side] = lowest
	end
	return out
end

local restFeet = solePositions({})
check(math.abs(restFeet.Right) < 0.08 and math.abs(restFeet.Left) < 0.08,
	("at rest the feet stand on the floor (%.2f, %.2f)"):format(restFeet.Right, restFeet.Left))

for _, name in ipairs({ "Run", "WalkLeft", "WalkRight", "WalkBackward" }) do
	local pair = clips[name]
	for _, variant in ipairs({ "full", "armed" }) do
		local clip = pair[variant]
		local lowest, grounded = math.huge, 0
		local steps = 24
		for i = 0, steps - 1 do
			local feet = solePositions(EmotePlayer.PoseAt(clip, clip.length * i / steps))
			lowest = math.min(lowest, feet.Right, feet.Left)
			if math.min(feet.Right, feet.Left) < 0.35 then
				grounded += 1
			end
		end
		check(lowest > -0.06 and grounded >= steps * 0.4,
			("%s (%s): no foot through the floor, and a foot down most of the cycle (lowest %.2f, down %d/%d)")
				:format(name, variant, lowest, grounded, steps))
	end
end

local maxLean, armedLean = 0, 0
for i = 0, 11 do
	local t = clips.Run.full.length * i / 12
	local full = EmotePlayer.PoseAt(clips.Run.full, t).LowerTorso
	local armed = EmotePlayer.PoseAt(clips.Run.armed, t).LowerTorso
	local fx, _, fz = degrees(full)
	local ax, _, az = degrees(armed)
	maxLean = math.max(maxLean, math.abs(fx), math.abs(fz))
	armedLean = math.max(armedLean, math.abs(ax), math.abs(az))
end
check(maxLean > 30, ("the run leans hard into it, as authored (%.0f degrees)"):format(maxLean))
check(armedLean < 0.5, ("with a gun out the torso stays upright for the aim (%.1f degrees)"):format(armedLean))

-- ------------------------------------------------------------------ blend --

print("the mix")
local function close(a, b)
	return math.abs(a - b) < 1e-3
end
local w = Locomotion.Weights(Vector3.new(0, 0, 0))
check(close(w.Idle, 1) and close(w.Run, 0), "standing: all idle")
w = Locomotion.Weights(Vector3.new(0, 0, -16))
check(close(w.Run, 1) and close(w.Idle, 0), "forward at speed: all run")
w = Locomotion.Weights(Vector3.new(-12, 0, 0))
check(close(w.WalkLeft, 1), "to the left: the left strafe")
w = Locomotion.Weights(Vector3.new(12, 0, 0))
check(close(w.WalkRight, 1), "to the right: the right strafe")
w = Locomotion.Weights(Vector3.new(0, 0, 12))
check(close(w.WalkBackward, 1), "backwards: the backpedal")
w = Locomotion.Weights(Vector3.new(10, 0, -10))
check(close(w.Run, 0.5) and close(w.WalkRight, 0.5), "forward and right: half each")
w = Locomotion.Weights(Vector3.new(0, 0, -3))
check(w.Idle > 0.1 and w.Run > 0.1 and close(w.Idle + w.Run, 1), "a slow walk is part idle, part run")
w = Locomotion.Weights(Vector3.new(0, -40, 0))
check(close(w.Idle, 1), "falling straight down is not running")

local state = Locomotion.NewState()
for _ = 1, 60 do
	Locomotion.Step(state, 1 / 60, Vector3.new(0, 0, -16), false, true)
end
check(state.alpha > 0.99 and state.weights.Run > 0.99, "after a second of running the body is all run")
local before = state.phase
Locomotion.Step(state, 0.1, Vector3.new(0, 0, -16), false, true)
local advanced = (state.phase - before) % 1
check(math.abs(advanced - 0.1 / 0.667) < 0.01, ("at its authored pace the stride plays at 1x (%.3f of a cycle in 0.1s)")
	:format(advanced))
before = state.phase
Locomotion.Step(state, 0.1, Vector3.new(0, 0, -24), false, true)
advanced = (state.phase - before) % 1
check(advanced > 0.2, ("sprinting quickens it (%.3f)"):format(advanced))
for _ = 1, 30 do
	Locomotion.Step(state, 1 / 60, Vector3.new(0, 0, -16), false, false)
end
check(state.alpha < 0.01, "off its feet, it fades out")

-- --------------------------------------------------------------- the rig --

print("on a character")
local rig, rests = Rig.character(World, place)
local humanoid = rig:FindFirstChildOfClass("Humanoid")
local root = rig:FindFirstChild("HumanoidRootPart")
local stateName = "Running"
R.ClassMethods.Humanoid.GetState = function()
	return roblox.Enum.HumanoidStateType[stateName]
end
local function moving(v)
	World.force(root, "AssemblyLinearVelocity", v)
end
local function joint(name)
	return Rig.motor(rig, name)
end
local function offRest(name)
	local m = joint(name)
	local delta = rests[name]:Inverse() * m.C0
	return math.deg(math.acos(math.clamp((delta.XVector.X + delta.YVector.Y + delta.ZVector.Z - 1) / 2, -1, 1)))
		+ delta.Position.Magnitude * 10
end

World.serverRemotes({ Remotes = { LookUpdate = "RemoteEvent" } })
World.run(World.service("StarterPlayer").StarterPlayerScripts.LocomotionAnimator)
moving(Vector3.new(0, 0, 0))
World.advance(0.6)
check(offRest("RightUpperLeg") < 0.5 and offRest("LowerTorso") < 0.5, "standing, the legs and hips are left alone")
check(offRest("RightUpperArm") > 1, "but the arms breathe with the idle")

moving(Vector3.new(0, 0, -16))
World.advance(0.6)
check(offRest("RightUpperLeg") > 5 and offRest("RightLowerLeg") > 5, "running, the legs stride and the knees bend")
check(offRest("LowerTorso") > 20, "and the body leans into it")
local upper = Locomotion.Upper[rig]
local nx = upper and degrees(upper.neck) or 0
check(upper ~= nil and math.abs(nx) > 15, ("the head is handed a pose that keeps it level (%.0f degrees)"):format(nx))

rig:SetAttribute("PoseRightC0", CFrame.new())
local armBefore = joint("RightUpperArm").C0
moving(Vector3.new(-12, 0, 0))
World.advance(0.6)
check(joint("RightUpperArm").C0 == armBefore, "with a gun out, the arms are left to the gun hold")
upper = Locomotion.Upper[rig]
local _, hipYaw = degrees(EmotePlayer.PoseAt(clips.WalkLeft.armed, 0).LowerTorso)
local _, counterYaw = degrees(upper.waist)
check(math.abs(hipYaw) > 10 and math.abs(counterYaw) > 5 and upper.neck == CFrame.new(),
	("strafing armed, the chest is turned back against the hips (%.0f)"):format(counterYaw))
rig:SetAttribute("PoseRightC0", nil)

stateName = "Freefall"
World.advance(0.6)
check(offRest("RightUpperLeg") < 0.5, "in the air the legs go back to the default animation")
stateName = "Running"
World.advance(0.6)
check(offRest("RightUpperLeg") > 5, "and pick up again on landing")
rig:SetAttribute("Emote", "Breakdance")
World.advance(0.6)
check(offRest("RightUpperLeg") < 0.5 and offRest("LowerTorso") < 0.5, "an emote gets the whole body")
rig:SetAttribute("Emote", nil)

print(failures == 0 and "\27[32mall locomotion checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
require("@lune/process").exit(failures == 0 and 0 or 1)
