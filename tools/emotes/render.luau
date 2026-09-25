--!nocheck
-- Pose the game's own character with a converted emote and export it for the map viewer, to
-- see that an emote decodes into the pose it should.
--
--   lune run tools/emotes/render.luau -- out.json Emote1 [Emote2 ...]
--   lune run tools/emotes/render.luau -- out.json sheet [fraction]    every emote, one figure each
--   node tools/mapview/shoot.mjs out.json prefix
--
-- Each emote gets a row of five figures, left to right at 10%, 30%, 50%, 70% and 90% of the
-- way through it (its intro, if it has one, counted in), posed exactly the way EmoteAnimator
-- poses a character: every joint's Part1 = Part0 * C0 * pose * C1^-1, down from the root.
-- Rows run away from the camera, first emote nearest.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")
local Export = require("../mapview/export")

local args = {}
for _, a in ipairs(process.args) do
	if a ~= "--" then
		table.insert(args, a)
	end
end
local outPath = table.remove(args, 1) or "out/emotes.json"
local ids = args
local sheetAt = nil
local propsMode = false
if ids[1] == "props" then
	-- Every emote with a prop, one figure each, far enough apart that props do not overlap,
	-- with a camera on each.
	propsMode = true
	sheetAt = tonumber(ids[2]) or 0.4
	ids = { "ToiletSit", "CouchNap", "Sunbath", "IceCreamCart", "Surfer", "CoconutLaunch", "ReapersRide", "FloatingMeditation" }
elseif ids[1] == "sheet" then
	-- A contact sheet: every emote in the index, eight to a row, each at one moment.
	sheetAt = tonumber(ids[2]) or 0.4
	ids = {}
	for line in string.gmatch(fs.readFile("src/ReplicatedStorage/EmoteData/Index.luau"), "[^\n]+") do
		local id = line:match("^%s*(%w+) = {")
		if id then
			table.insert(ids, id)
		end
	end
end

local env = { math = math, string = string, table = table }
for key, value in pairs(roblox) do
	if type(key) == "string" and key:match("^%u") then
		env[key] = value
	end
end
env.workspace = { Gravity = 196.2 }
setmetatable(env, { __index = _G })
local function load(path: string)
	return luau.load(fs.readFile(path), { debugName = path, environment = env })()
end
local EmotePlayer = load("src/ReplicatedStorage/EmotePlayer.luau")
local EmoteConfig = load("src/ReplicatedStorage/EmoteConfig.luau")
local EmoteProps = load("src/ReplicatedStorage/EmoteProps.luau")

local game = roblox.deserializePlace(fs.readFile("build/Game.rbxl"))
local template = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
assert(template, "no StarterCharacter in build/Game.rbxl")

local stage = roblox.Instance.new("Folder")
stage.Name = "Stage"
stage.Parent = game.Workspace

local function motorsOf(model)
	local list = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			table.insert(list, d)
		end
	end
	return list
end

local function pose(model, rootCf, poses)
	local root = model:FindFirstChild("HumanoidRootPart")
	root.CFrame = rootCf
	local done = { [root] = true }
	local motors = motorsOf(model)
	-- Parents before children: keep sweeping until every joint's Part0 is placed.
	local left = #motors
	while left > 0 do
		local progressed = false
		for _, m in ipairs(motors) do
			if done[m.Part0] and not done[m.Part1] then
				local t = poses[m.Part1.Name] or roblox.CFrame.new()
				m.Part1.CFrame = m.Part0.CFrame * m.C0 * t * m.C1:Inverse()
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

local FRACTIONS = sheetAt and { sheetAt } or { 0.1, 0.3, 0.5, 0.7, 0.9 }
local SPACING_X, SPACING_Z = propsMode and 14 or 5, 8
local COLUMNS = propsMode and #ids or sheetAt and 8 or #FRACTIONS
local ROWS = sheetAt and math.ceil(#ids / COLUMNS) or #ids

-- A floor under everything.
local floor = roblox.Instance.new("Part")
floor.Name = "Floor"
floor.Size = roblox.Vector3.new(SPACING_X * COLUMNS + 6, 1, SPACING_Z * math.max(1, ROWS) + 6)
floor.CFrame = roblox.CFrame.new(0, -0.5, SPACING_Z * (ROWS - 1) / 2)
floor.Color = roblox.Color3.fromRGB(96, 104, 112)
floor.Material = roblox.Enum.Material.SmoothPlastic
floor.Parent = stage

-- Hip height: the root sits this far above the floor when the rig stands at rest.
local rest = template:Clone()
rest.Parent = stage
pose(rest, roblox.CFrame.new(), {})
local lowest = math.huge
for _, p in ipairs(rest:GetDescendants()) do
	if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
		lowest = math.min(lowest, p.CFrame.Position.Y - p.Size.Y / 2)
	end
end
rest.Parent = nil
local hip = -lowest

for row, id in ipairs(ids) do
	local path = "src/ReplicatedStorage/EmoteData/" .. id .. ".luau"
	assert(fs.isFile(path), "no emote " .. id)
	local clip = EmotePlayer.FromData(load(path))
	local total = EmotePlayer.Duration(clip)
	for i, f in ipairs(FRACTIONS) do
		local figure = template:Clone()
		figure.Name = id .. "_" .. i
		figure.Parent = stage
		local column, line = i, row
		if sheetAt then
			column, line = (row - 1) % COLUMNS + 1, (row - 1) // COLUMNS + 1
		end
		local x = (column - (COLUMNS + 1) / 2) * SPACING_X
		local z = (line - 1) * SPACING_Z
		-- Facing the camera: a rig faces -Z, and the camera stands at -Z looking back along +Z.
		local cf = roblox.CFrame.new(x, hip, z)
		pose(figure, cf, EmotePlayer.PoseAt(clip, total * f))
		-- The emote's prop, placed the way EmoteAnimator places it.
		local spec = EmoteConfig.Get(id)
		if spec and spec.prop then
			local prop = EmoteProps.Build(spec.prop, stage)
			if prop then
				local elapsed = total * f
				if spec.prop == "Cannon" then
					-- Just after it fires, so the shot and the kick are in the picture.
					elapsed = 1.45 + 0.12
					EmoteProps.Update(prop, figure, EmoteProps.FloorOf(cf), 1.46)
				end
				EmoteProps.Update(prop, figure, EmoteProps.FloorOf(cf), elapsed)
			end
		end
	end
	print(("%d  %s  (%.2fs%s)"):format(row, id, total, clip.loop and ", loops" or ""))
end

local data = Export.Parts(stage, roblox.Vector3.new(0, 0, 0))
data.mood = "day"
local depth = SPACING_Z * (ROWS - 1)
data.cameras = {
	{ pos = { 0, 5 + ROWS * 3, -16 - ROWS * 2 }, look = { 0, 2, depth * 0.4 }, fov = 50 },
	{ pos = { 18, 7, -10 }, look = { 0, 2, depth * 0.3 }, fov = 50 },
}
if propsMode then
	data.cameras = {}
	for i = 1, #ids do
		local x = (i - (COLUMNS + 1) / 2) * SPACING_X
		table.insert(data.cameras, { pos = { x - 7.5, 6.5, -9.5 }, look = { x, 2.2, 0 }, fov = 55 })
	end
	-- And each from its right-hand side, where the prop is not behind the body.
	for i = 1, #ids do
		local x = (i - (COLUMNS + 1) / 2) * SPACING_X
		table.insert(data.cameras, { pos = { x + 10, 4.5, 1.5 }, look = { x, 2.2, 0.5 }, fov = 55 })
	end
end
-- Each row on its own, from the front and a little above, so nothing stands behind anything.
for line = 1, propsMode and 0 or ROWS do
	local z = (line - 1) * SPACING_Z
	table.insert(data.cameras, { pos = { 4, 6, z - 17 }, look = { 0, 2, z }, fov = 55 })
end
if #data.lights == 0 then
	data.lights = nil
end
if #data.signs == 0 then
	data.signs = nil
end
fs.writeFile(outPath, serde.encode("json", data))
print(("wrote %s: %d parts"):format(outPath, #data.parts))
