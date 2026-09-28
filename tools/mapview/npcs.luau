--!nocheck
-- A lineup of every NPC archetype, dressed the way the server dresses them, for the viewer.
--
--   lune run tools/mapview/npcs.luau -- out.json [Archetype,Archetype...] [draws]
--
-- Each archetype stands in a row facing the camera (front row), with `draws` more of the same
-- archetype behind it wearing other draws from its palette (default 3), so a crew's variety
-- shows. The body parts are meshes in the game and boxes here, so judge the clothes and the
-- colours, not the silhouette of the body under them. Cameras: the whole lineup from the
-- front and from three-quarters, then a close-up on every archetype.

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
local outPath = args[1] or "out/npcs.json"
local only = args[2]
local draws = tonumber(args[3]) or 3

local game = roblox.deserializePlace(fs.readFile("build/Game.rbxl"))

local env = {
	game = game,
	workspace = game.Workspace,
	Instance = roblox.Instance,
	warn = print,
	print = print,
}
for key, value in pairs(roblox) do
	if type(key) == "string" and key:match("^%u") and env[key] == nil then
		env[key] = value
	end
end
setmetatable(env, { __index = _G })
local loaded = {}
local function load(path)
	if not loaded[path] then
		loaded[path] = luau.load(fs.readFile(path), { debugName = path, environment = env })()
	end
	return loaded[path]
end
env.require = function(target)
	if type(target) == "table" and target.__path then
		return load(target.__path)
	end
	return {}
end
env.script = { Parent = setmetatable({}, { __index = function(_, name)
	return { __path = "src/ReplicatedStorage/" .. name .. ".luau" }
end }) }

local NPCConfig = load("src/ReplicatedStorage/NPCConfig.luau")
local Outfit = load("src/ServerScriptService/NPCService/Outfit.luau")

local source = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
local template = source:Clone()
for _, d in ipairs(template:GetDescendants()) do
	if d:IsA("LuaSourceContainer") or d:IsA("AnimationConstraint") or d:IsA("BallSocketConstraint") then
		d.Parent = nil
	end
end

local names = {}
if only and only ~= "all" then
	for name in string.gmatch(only, "[^,]+") do
		table.insert(names, name)
	end
else
	for name in pairs(NPCConfig.Archetypes) do
		table.insert(names, name)
	end
	table.sort(names)
end

local stage = roblox.Instance.new("Folder")
local SPACING = 5
local counts = {}
local width = (#names - 1) * SPACING
for i, name in ipairs(names) do
	local cfg = NPCConfig.Get(name)
	for row = 0, draws do
		local body = template:Clone()
		body.Name = name .. "_" .. row
		local pieces = Outfit.Dress(body, cfg, 1000 + row * 7919 + i)
		if row == 0 then
			counts[name] = pieces
		end
		local scale = cfg.Scale or 1
		-- Stand it on the ground at its spot, scaled like the game does, turned to face +Z: the
		-- viewer's sun is on that side, and the camera goes there.
		local rootPart = body:FindFirstChild("HumanoidRootPart")
		local base = rootPart.CFrame
		local x, z = (i - 1) * SPACING - width / 2, -row * 6
		for _, p in ipairs(body:GetDescendants()) do
			if p:IsA("BasePart") then
				local rel = base:ToObjectSpace(p.CFrame)
				rel = rel - rel.Position + rel.Position * scale
				p.Size = p.Size * scale
				p.CFrame = roblox.CFrame.new(x, 3.05 * scale, z) * roblox.CFrame.Angles(0, math.pi, 0) * rel
			end
		end
		rootPart.Transparency = 1
		body.Parent = stage
	end
end
-- A floor and a wall to read the colours against.
local floor = roblox.Instance.new("Part")
floor.Size = roblox.Vector3.new(width + 20, 1, 40)
floor.CFrame = roblox.CFrame.new(0, -0.5, -12)
floor.Color = roblox.Color3.fromRGB(196, 200, 206)
floor.Parent = stage

local data = Export.Parts(stage, roblox.Vector3.new(0, 0, 0))
data.mood = "day"
data.cameras = {
	{ pos = { 0, 5, width * 0.62 + 10 }, look = { 0, 3, -4 }, fov = 50 },
	{ pos = { width * 0.5, 8, width * 0.45 + 8 }, look = { 0, 3, -3 }, fov = 50 },
}
for i, name in ipairs(names) do
	local x = (i - 1) * SPACING - width / 2
	local s = NPCConfig.Get(name).Scale or 1
	table.insert(data.cameras, { pos = { x + 3.4 * s, 5.2 * s, 7.5 * s }, look = { x, 3.3 * s, 0 }, fov = 40 })
end
if #data.lights == 0 then
	data.lights = nil
end
if #data.signs == 0 then
	data.signs = nil
end
fs.writeFile(outPath, serde.encode("json", data))
local summary = {}
for _, name in ipairs(names) do
	table.insert(summary, ("%s %d"):format(name, counts[name]))
end
print(("wrote %s: %d parts; pieces per body: %s"):format(outPath, #data.parts, table.concat(summary, ", ")))
