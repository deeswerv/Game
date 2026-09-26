--!nocheck
-- Export one or more workspace folders of the built place for the viewer, with cameras.
--
--   lune run tools/mapview/region.luau -- out.json Folder[,Folder...] [x,y,z:lx,ly,lz ...]
--
-- Each camera is "x,y,z:lx,ly,lz" (position, then the point it looks at). With none given, a
-- high overview of the folders' bounds from each of the four diagonals.

local fs = require("@lune/fs")
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
local outPath = assert(args[1], "out.json")
local names = assert(args[2], "Folder[,Folder]")
local game = roblox.deserializePlace(fs.readFile("build/Game.rbxl"))
local stage = roblox.Instance.new("Folder")
for name in string.gmatch(names, "[^,]+") do
	local f = game.Workspace:FindFirstChild(name)
	assert(f, "no workspace." .. name)
	f:Clone().Parent = stage
end
local data = Export.Parts(stage, roblox.Vector3.new(0, 0, 0))
data.mood = "day"
data.cameras = {}
for i = 3, #args do
	local px, py, pz, lx, ly, lz = string.match(args[i], "([-%d.]+),([-%d.]+),([-%d.]+):([-%d.]+),([-%d.]+),([-%d.]+)")
	table.insert(data.cameras, { pos = { tonumber(px), tonumber(py), tonumber(pz) },
		look = { tonumber(lx), tonumber(ly), tonumber(lz) }, fov = 60 })
end
if #data.cameras == 0 then
	local lo, hi = { math.huge, math.huge, math.huge }, { -math.huge, -math.huge, -math.huge }
	for _, p in ipairs(data.parts) do
		for k = 1, 3 do
			lo[k] = math.min(lo[k], p.p[k])
			hi[k] = math.max(hi[k], p.p[k])
		end
	end
	local c = { (lo[1] + hi[1]) / 2, lo[2], (lo[3] + hi[3]) / 2 }
	local r = math.max(hi[1] - lo[1], hi[3] - lo[3])
	for _, d in ipairs({ { 1, 1 }, { -1, 1 }, { 1, -1 }, { -1, -1 } }) do
		table.insert(data.cameras, { pos = { c[1] + d[1] * r * 0.55, c[2] + r * 0.45, c[3] + d[2] * r * 0.55 },
			look = c, fov = 55 })
	end
end
if #data.lights == 0 then
	data.lights = nil
end
if #data.signs == 0 then
	data.signs = nil
end
fs.writeFile(outPath, serde.encode("json", data))
print(("wrote %s: %d parts"):format(outPath, #data.parts))
