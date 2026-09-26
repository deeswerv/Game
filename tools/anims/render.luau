--!nocheck
-- Pose the game's own character with the converted movement clips and export them for the
-- map viewer, to see that the R6 clips came across to R15 the way they were authored.
--
--   lune run tools/anims/render.luau -- out.json [Clip[:armed] ...]
--   node tools/mapview/shoot.mjs out.json prefix
--
-- One row per clip, six moments through its cycle left to right. Each figure is turned side
-- on, facing screen right, so the row reads as a profile -- which is how a gait is judged:
-- the lean, the knee bend, where the feet land. The strafes are also shown from the front
-- (a second row), since they move sideways. One camera per row.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local Export = require("../mapview/export")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local args = {}
for _, a in ipairs(process.args) do
	if a ~= "--" then
		table.insert(args, a)
	end
end
local outPath = table.remove(args, 1) or "out/locomotion.json"
local ids = #args > 0 and args or { "Idle", "Run", "Run:armed", "WalkLeft", "WalkRight", "WalkBackward" }

local env = { math = math, string = string, table = table }
for key, value in pairs(roblox) do
	if type(key) == "string" and key:match("^%u") then
		env[key] = value
	end
end
setmetatable(env, { __index = _G })
local function load(path: string)
	return luau.load(fs.readFile(path), { debugName = path, environment = env })()
end
local EmotePlayer = load("src/ReplicatedStorage/EmotePlayer.luau")

local game = roblox.deserializePlace(fs.readFile("build/Game.rbxl"))
local template = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
local stage = roblox.Instance.new("Folder")
stage.Parent = game.Workspace

local function pose(model, rootCf, poses)
	local root = model:FindFirstChild("HumanoidRootPart")
	root.CFrame = rootCf
	root.Transparency = 1
	local motors = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			table.insert(motors, d)
		end
	end
	local done = { [root] = true }
	local left = #motors
	while left > 0 do
		local progressed = false
		for _, m in ipairs(motors) do
			if done[m.Part0] and not done[m.Part1] then
				m.Part1.CFrame = m.Part0.CFrame * m.C0 * (poses[m.Part1.Name] or CFrame.new()) * m.C1:Inverse()
				done[m.Part1] = true
				left -= 1
				progressed = true
			end
		end
		if not progressed then
			break
		end
	end
end

local FRAMES = { 0, 1 / 6, 2 / 6, 3 / 6, 4 / 6, 5 / 6 }
local SPACING_X, SPACING_Z = 4.2, 12
local rows = {}
for _, id in ipairs(ids) do
	table.insert(rows, { id = id, facing = math.pi / 2 })
	if id == "WalkLeft" or id == "WalkRight" then
		-- Facing +Z, seen from the far side, so the profile row is behind the camera's subject.
		table.insert(rows, { id = id, facing = math.pi })
	end
end

local floor = roblox.Instance.new("Part")
floor.Name = "Floor"
floor.Size = Vector3.new(SPACING_X * #FRAMES + 8, 1, SPACING_Z * #rows + 8)
floor.CFrame = CFrame.new(0, -0.5, SPACING_Z * (#rows - 1) / 2)
floor.Color = roblox.Color3.fromRGB(96, 104, 112)
floor.Parent = stage

local data = nil
local cameras = {}
for line, row in ipairs(rows) do
	local name, variant = string.match(row.id, "^(%w+):?(%w*)$")
	local raw = load("src/ReplicatedStorage/LocomotionData/" .. name .. ".luau")
	if variant == "armed" and raw.armed then
		local joints = table.clone(raw.joints)
		for k, v in pairs(raw.armed) do
			joints[k] = v
		end
		raw = { length = raw.length, loop = raw.loop, joints = joints }
	end
	local clip = EmotePlayer.FromData(raw)
	local z = (line - 1) * SPACING_Z
	for i, f in ipairs(FRAMES) do
		local figure = template:Clone()
		figure.Parent = stage
		local x = (i - (#FRAMES + 1) / 2) * SPACING_X
		-- The root stands three studs up, as a live character's does.
		pose(figure, CFrame.new(x, 3, z) * CFrame.Angles(0, row.facing, 0), EmotePlayer.PoseAt(clip, clip.length * f))
	end
	local front = row.facing == math.pi
	table.insert(cameras, { pos = { 0, 4.5, front and z + 17 or z - 17 }, look = { 0, 2.2, z }, fov = 52 })
	print(("%d  %s%s"):format(line, row.id, front and " (front)" or ""))
end

data = Export.Parts(stage, Vector3.new(0, 0, 0))
data.mood = "day"
data.cameras = cameras
if #data.lights == 0 then
	data.lights = nil
end
if #data.signs == 0 then
	data.signs = nil
end
fs.writeFile(outPath, serde.encode("json", data))
print(("wrote %s: %d parts"):format(outPath, #data.parts))
