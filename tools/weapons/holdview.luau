--!nocheck
-- A character holding a weapon, posed by the game's own WeaponPose, exported for
-- tools/weapons/preview.mjs to draw -- so how a gun sits in the hands can be seen without
-- Studio. The posing itself is tools/weapons/hold.luau.
--
--   lune run tools/weapons/holdview.luau -- Warden out/warden_hold.json [carry|aim]
--   node tools/weapons/preview.mjs out/warden_hold.json out/warden_hold.png hold
local fs = require("@lune/fs")
local serde = require("@lune/serde")
local process = require("@lune/process")
local World = require("../uitest/world")
local Rig = require("../uitest/rig")
local Hold = require("./hold")

local args = {}
for _, a in ipairs(process.args) do
	if a ~= "--" then
		table.insert(args, a)
	end
end
local toolName, outPath, stance = args[1], args[2], args[3]

local place = World.loadPlace("build/Game.rbxl")
local ctx = Hold.setup(World, Rig, place)
local result = Hold.pose(ctx, toolName, stance)
fs.writeFile(outPath, serde.encode("json", result))
print(serde.encode("json", result.report))
process.exit(0)
