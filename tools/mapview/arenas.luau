--!nocheck
-- Build duel maps in Lune and export them for the viewer.
--
--   lune run tools/mapview/arenas.luau -- <map id or "court"> out.json
--
-- Maps live in src/ServerScriptService/ArenaService/<Id>.luau (see ArenaService). Each is loaded the
-- way the engine would load it, with Roblox's datatypes, built into a Lune DataModel, and
-- everything it made is exported with a set of cameras: a high overview and each spawn's
-- eye-level view down the map.

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
local id, outPath = args[1] or "Court", args[2] or "out/map.json"

local game = roblox.deserializePlace(fs.readFile("build/Game.rbxl"))

-- Roblox's Random, enough for NextNumber / NextInteger.
local Random = {}
function Random.new(seed)
	local s = (tonumber(seed) or 7) % 2147483647
	local r = {}
	local function nxt()
		s = (s * 1103515245 + 12345) % 2147483648
		return s / 2147483648
	end
	function r:NextNumber(a, b)
		a = a or 0
		b = b or 1
		return a + (b - a) * nxt()
	end
	function r:NextInteger(a, b)
		return a + math.floor(nxt() * (b - a + 1))
	end
	return r
end

-- Lune ignores a metatable on the environment, so every global is a real key.
local env = {
	game = game,
	workspace = game.Workspace,
	Instance = roblox.Instance,
	Random = Random,
	warn = print,
	print = print,
	task = require("@lune/task"),
}
for key, value in pairs(roblox) do
	if type(key) == "string" and key:match("^%u") and env[key] == nil then
		env[key] = value
	end
end
setmetatable(env, { __index = _G })

local loaded = {}
local function load(path: string)
	if loaded[path] then
		return loaded[path]
	end
	local fn = luau.load(fs.readFile(path), { debugName = path, environment = env })
	local value = fn()
	loaded[path] = value
	return value
end

-- `require` inside a map resolves shared helpers by name, and anything else to a stub.
env.require = function(target)
	if type(target) == "table" and target.__path then
		return load(target.__path)
	end
	-- A real ModuleScript from the built place: load its source file instead.
	if typeof(target) == "Instance" and target:IsA("ModuleScript") then
		local path = "src/" .. target:GetFullName():gsub("%.", "/") .. ".luau"
		if fs.isFile(path) then
			return load(path)
		end
	end
	return { Skip = function()
		return false
	end }
end
env.script = setmetatable({}, { __index = function(_, k)
	if k == "Parent" then
		return setmetatable({}, { __index = function(_, name)
			return { __path = "src/ServerScriptService/ArenaService/" .. name .. ".luau" }
		end })
	end
	return nil
end })

local root, map
local spawns, centre, mood, exposure
if id == "Court" and not fs.isFile("src/ServerScriptService/ArenaService/Court.luau") then
	-- The original single arena: ArenaService builds itself when it loads.
	local module = load("src/ServerScriptService/ArenaService.luau")
	root = game.Workspace:FindFirstChild("Arena")
	centre = module.CENTRE
	spawns = { module.SpawnCFrame(1).Position, module.SpawnCFrame(2).Position }
	mood = "night"
else
	map = load(id:match("%.luau$") and id or ("src/ServerScriptService/ArenaService/" .. id .. ".luau"))
	local folder = roblox.Instance.new("Folder")
	folder.Name = "Arena_" .. id
	folder.Parent = game.Workspace
	centre = roblox.Vector3.new(0, 3000, 0)
	map.Build(folder, centre)
	root = folder
	spawns = {}
	for _, offset in ipairs(map.Spawns or { map.Arrival or roblox.Vector3.new(0, 3, -40), roblox.Vector3.new(0, 3, 40) }) do
		table.insert(spawns, centre + offset)
	end
	mood = map.Mood or "day"
	exposure = map.Exposure
end

local data = Export.Parts(root, centre)
data.mood = mood
data.exposure = exposure
local a, b = spawns[1] - centre, spawns[2] - centre
local hw, hl = 42, 60
if map then
	hw, hl = map.HalfWidth or hw, map.HalfLength or hl
end
data.cameras = {
	{ pos = { hw * 1.5, hl * 1.25, hl * 1.45 }, look = { 0, 0, 0 }, fov = 55 },
	{ pos = { a.X, a.Y + 4.5, a.Z }, look = { b.X, b.Y + 3, b.Z }, fov = 70 },
	{ pos = { b.X, b.Y + 4.5, b.Z }, look = { a.X, a.Y + 3, a.Z }, fov = 70 },
	-- From a high corner inside the map, across the middle.
	{ pos = { -(hw - 3), 24, -(hl - 12) }, look = { hw * 0.3, 0, hl * 0.35 }, fov = 62 },
}
for _, extra in ipairs(map and map.Preview or {}) do
	table.insert(data.cameras, extra)
end
fs.writeFile(outPath, serde.encode("json", data))
print(("%s: %d parts, %d lights, %d signs"):format(id, #data.parts, #data.lights, #data.signs))
