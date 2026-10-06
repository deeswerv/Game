--!nocheck
-- The player's procedural poses (ReplicatedStorage.Motion) on the game's own rig, frame by
-- frame in a row, for the viewer.
--
--   lune run tools/mapview/poses.luau -- out.json [sequence]
--
-- Sequences: run (a stride at running speed), sprint, walk, strafe (moving right), back
-- (backpedalling), crouch (standing, then crouched, then crouch-walking), roll (forward),
-- rollside (to the right), air (a jump and the landing), idle; and the clerks' and quest
-- givers' (ReplicatedStorage.StaffPose): handsup (a robbery, from the jolt to held), folded (a
-- clerk at rest), talk, wave. Each frame is the rig posed by
-- forward kinematics through its real Motor6Ds, so what shows is what the joints would do.
-- Also prints the lowest point of every frame (feet should stay near the floor; a roll should
-- not sink into it).

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local Export = require("./export")

local args = {}
for _, a in ipairs(process.args) do
	if a ~= "--" then
		table.insert(args, a)
	end
end
local outPath = args[1] or "out/poses.json"
local sequence = args[2] or "run"

local game = roblox.deserializePlace(fs.readFile("build/Game.rbxl"))
local env = { game = game, Instance = roblox.Instance }
for key, value in pairs(roblox) do
	if type(key) == "string" and key:match("^%u") and env[key] == nil then
		env[key] = value
	end
end
setmetatable(env, { __index = _G })
local Motion = luau.load(fs.readFile("src/ReplicatedStorage/Motion.luau"), { debugName = "Motion", environment = env })()
local StaffPose = luau.load(fs.readFile("src/ReplicatedStorage/StaffPose.luau"), { debugName = "StaffPose", environment = env })()

local source = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")

--- Pose a fresh copy of the rig: `poses` by Part1 name, HRP at `at`.
local function posed(poses, at)
	local rig = source:Clone()
	local motors = {}
	for _, d in ipairs(rig:GetDescendants()) do
		if d.ClassName == "Motor6D" and d.Part0 and d.Part1 then
			motors[d.Part1.Name] = d
		end
	end
	local root = rig:FindFirstChild("HumanoidRootPart")
	root.CFrame = at
	-- Solve outward from the root, parents before children.
	local done = { HumanoidRootPart = true }
	local progress = true
	while progress do
		progress = false
		for name, m in pairs(motors) do
			if not done[name] and done[m.Part0.Name] then
				local pose = poses[name] or roblox.CFrame.new()
				m.Part1.CFrame = m.Part0.CFrame * m.C0 * pose * m.C1:Inverse()
				done[name] = true
				progress = true
			end
		end
	end
	root.Transparency = 1
	local lowest = math.huge
	for _, p in ipairs(rig:GetDescendants()) do
		if p:IsA("BasePart") and p ~= root then
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local w = p.CFrame:PointToWorldSpace(p.Size / 2 * roblox.Vector3.new(sx, sy, sz))
						lowest = math.min(lowest, w.Y)
					end
				end
			end
		end
	end
	return rig, lowest
end

if sequence == "bake" then
	-- How far the curled body's lowest point sits above the standing feet at each twentieth of
	-- a roll, with no drop: that is how far the hips must come down to keep it on the floor.
	local _, restLow = posed({}, roblox.CFrame.new())
	local out = {}
	for _, spec in ipairs({ { "forward", roblox.Vector3.new(0, 0, -1) }, { "back", roblox.Vector3.new(0, 0, 1) },
		{ "side", roblox.Vector3.new(1, 0, 0) } }) do
		local values = {}
		for i = 0, 20 do
			local poses = Motion.RollPose(i / 20, spec[2], 0)
			local _, low = posed(poses, roblox.CFrame.new())
			table.insert(values, ("%.2f"):format(math.max(-0.5, low - restLow)))
		end
		table.insert(out, ("\t%s = { %s },"):format(spec[1], table.concat(values, ", ")))
	end
	print("Motion.ROLL_GROUND = {\n" .. table.concat(out, "\n") .. "\n}")
	process.exit(0)
end

local STAFF = { handsup = true, folded = true, talk = true, wave = true }
local frames = {}
local function input(over)
	local t = {
		dt = 1 / 30, velocity = roblox.Vector3.new(), grounded = true, crouch = false, sprint = false,
		armed = false, active = true,
	}
	for k, v in pairs(over or {}) do
		t[k] = v
	end
	return t
end
local function run(steps, make, every)
	local state = Motion.NewState()
	for i = 1, steps do
		local poses = Motion.Step(state, make(i))
		if i % (every or 1) == 0 then
			local copy = {}
			for k, v in pairs(poses) do
				copy[k] = v
			end
			table.insert(frames, copy)
		end
	end
end

local V = roblox.Vector3.new
if sequence == "run" or sequence == "sprint" or sequence == "walk" then
	local speed = if sequence == "walk" then 9 elseif sequence == "sprint" then 24 else 16
	run(60, function()
		return input({ velocity = V(0, 0, -speed), sprint = sequence == "sprint" })
	end)
	local keep = {}
	for i = 46, 60, 2 do
		table.insert(keep, frames[i])
	end
	frames = keep
elseif sequence == "strafe" or sequence == "back" then
	local v = if sequence == "strafe" then V(14, 0, 0) else V(0, 0, 12)
	run(60, function()
		return input({ velocity = v })
	end)
	local keep = {}
	for i = 46, 60, 2 do
		table.insert(keep, frames[i])
	end
	frames = keep
elseif sequence == "crouch" then
	run(20, function()
		return input({})
	end, 20)
	run(20, function()
		return input({ crouch = true })
	end, 20)
	run(50, function(i)
		return input({ crouch = true, velocity = V(0, 0, -8) })
	end)
	local last = {}
	for i = 3, #frames do
		if (i - 3) % 4 == 0 and i > 30 then
			table.insert(last, frames[i])
		end
	end
	frames = { frames[1], frames[2], table.unpack(last) }
elseif sequence == "roll" or sequence == "rollside" or sequence == "rollback" then
	local dir = if sequence == "rollside" then V(1, 0, 0) elseif sequence == "rollback" then V(0, 0, 1) else V(0, 0, -1)
	local t = 0
	run(16, function()
		t += Motion.ROLL_TIME / 15
		return input({ roll = { dir = dir, t = t - Motion.ROLL_TIME / 15 }, velocity = dir * 20 })
	end, 2)
elseif sequence == "handsup" then
	for _, since in ipairs({ 0, 0.08, 0.16, 0.26, 0.4, 0.8, 2.0 }) do
		table.insert(frames, StaffPose.Blend(StaffPose.Idle(since, 0, "folded"), StaffPose.HandsUp(since, since), 1))
	end
elseif sequence == "folded" or sequence == "talk" or sequence == "wave" then
	for i = 0, 6 do
		local t = i * 0.22
		local base = StaffPose.Idle(t, 0, if sequence == "folded" then "folded" else nil)
		if sequence == "talk" then
			base = StaffPose.Blend(base, StaffPose.Talk(t), 1)
		elseif sequence == "wave" then
			base = StaffPose.Blend(base, StaffPose.Wave(0.3 + t * 0.9), 1)
		end
		table.insert(frames, base)
	end
elseif sequence == "air" then
	run(24, function(i)
		return input({ grounded = i > 16, landed = if i == 17 then 0.8 else nil, velocity = V(0, 0, -6) })
	end, 3)
else
	run(60, function()
		return input({})
	end, 10)
end

local stage = roblox.Instance.new("Folder")
local floor = roblox.Instance.new("Part")
floor.Size = roblox.Vector3.new(#frames * 5 + 10, 1, 14)
floor.CFrame = roblox.CFrame.new((#frames - 1) * 2.5, -0.5, 0)
floor.Color = roblox.Color3.fromRGB(196, 200, 206)
floor.Parent = stage
-- Stand the rig with its feet on the floor (y 0), facing +Z toward the camera (the viewer's sun
-- is on that side), turned a little so the limbs read.
local _, restLow = posed({}, roblox.CFrame.new())
local lows = {}
for i, f in ipairs(frames) do
	local at = roblox.CFrame.new((i - 1) * 5, -restLow, 0) * roblox.CFrame.Angles(0, math.rad(if sequence == "strafe" or sequence == "rollside" then 180
		elseif STAFF[sequence] then 155 else 130), 0)
	local rig, low = posed(f, at)
	rig.Parent = stage
	table.insert(lows, ("%.2f"):format(low))
end
local data = Export.Parts(stage, roblox.Vector3.new(0, 0, 0))
data.mood = "day"
local mid = (#frames - 1) * 2.5
data.cameras = {
	{ pos = { mid, 3.2, #frames * 2.4 + 9 }, look = { mid, 2.2, 0 }, fov = 50 },
	{ pos = { mid + #frames * 1.8 + 6, 3.4, 8 }, look = { mid, 2.2, 0 }, fov = 50 },
}
data.lights = nil
data.signs = nil
fs.writeFile(outPath, serde.encode("json", data))
print(("%s: %d frames; lowest point per frame: %s"):format(sequence, #frames, table.concat(lows, " ")))
