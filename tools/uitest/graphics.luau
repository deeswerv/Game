--!nocheck
-- The GRAPHICS setting (GraphicsQuality.client), in the client emulator:
--
--   * ULTRA (the default) leaves everything drawn and every effect on;
--   * PERFORMANCE turns off depth of field, sun rays and bloom, and stops drawing a city's far
--     skyline and its small trim -- including trim that streams in afterwards -- but not the
--     buildings you play among;
--   * BALANCED keeps bloom and draws everything; back up to ULTRA, it is all as it was;
--   * the Settings panel offers it, under GRAPHICS.
--
--   lune run tools/uitest/graphics.luau

local process = require("@lune/process")
local task = require("@lune/task")
local World = require("./world")
local Vector3 = require("@lune/roblox").Vector3
local R = World.R

task.delay(60, function()
	print("\27[31mtimed out\27[0m")
	process.exit(2)
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

World.loadPlace("build/Game.rbxl")
local workspace = World.service("Workspace")
local lighting = World.service("Lighting")
local rs = World.service("ReplicatedStorage")

local function part(name, parent)
	local p = R.new("Part")
	p.Name = name
	p.Size = Vector3.new(1, 1, 1)
	p.Parent = parent
	return p
end
local city = R.new("Folder")
city.Name = "Downtown"
city.Parent = workspace
local skyline = R.new("Folder")
skyline.Name = "Skyline"
skyline.Parent = city
local far = part("Building", skyline)
local bracket = part("Bracket", city)
local wall = part("Building", city)

local sps = World.service("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
World.run(sps:FindFirstChild("GraphicsQuality"))
World.advance(0.2)

local function effectsOn()
	local dof, rays, bloom = lighting:FindFirstChild("DepthOfField"), lighting:FindFirstChildOfClass("SunRaysEffect"),
		lighting:FindFirstChild("Bloom")
	return (dof == nil or dof.Enabled), (rays == nil or rays.Enabled), (bloom == nil or bloom.Enabled)
end

print("ultra")
local d, r, b = effectsOn()
check(d and r and b, "every effect on")
local function ltm(p)
	return p.LocalTransparencyModifier or 0
end
check(ltm(far) == 0 and ltm(bracket) == 0, "everything drawn")

print("performance")
World.player:SetAttribute("GraphicsQuality", 1)
World.advance(0.2)
d, r, b = effectsOn()
check(not d and not r and not b, "no depth of field, sun rays or bloom")
check(far.LocalTransparencyModifier == 1, "the far skyline is not drawn")
check(bracket.LocalTransparencyModifier == 1, "nor the small trim")
check(ltm(wall) == 0, "but the buildings you play among are")
local landmark = R.new("Part")
landmark.Name = "Chimney"
landmark.Size = Vector3.new(130, 9, 9)
landmark.Parent = city
World.player:SetAttribute("GraphicsQuality", 3)
World.advance(0.2)
World.player:SetAttribute("GraphicsQuality", 1)
World.advance(0.2)
check(ltm(landmark) == 0, "a landmark that shares a trim's name (Hanami's chimney) stays")
local late = part("Spoke", city)
World.advance(0.2)
check(late.LocalTransparencyModifier == 1, "trim that streams in later is caught too")

print("balanced, then ultra")
World.player:SetAttribute("GraphicsQuality", 2)
World.advance(0.2)
d, r, b = effectsOn()
check(not d and not r and b, "balanced: bloom back, no depth of field or sun rays")
check(far.LocalTransparencyModifier == 0 and late.LocalTransparencyModifier == 0, "and everything drawn again")
World.player:SetAttribute("GraphicsQuality", 3)
World.advance(0.2)
d, r, b = effectsOn()
check(d and r and b, "ultra: as it was")

print("the panel")
local SettingsConfig = World.require(rs:FindFirstChild("SettingsConfig"))
local setting = SettingsConfig.Get("Graphics")
check(setting ~= nil and setting.group == "GRAPHICS" and setting.default == 3 and setting.format == "quality",
	"the Settings panel offers GRAPHICS, ULTRA by default")
check(SettingsConfig.GraphicsLevels[1] == "PERFORMANCE" and SettingsConfig.GraphicsLevels[3] == "ULTRA", "named PERFORMANCE to ULTRA")
check(SettingsConfig.Clean("Graphics", 7) == 3 and SettingsConfig.Clean("Graphics", 0) == 1, "and kept in range")

print(if failures == 0 then "\27[32mall graphics checks passed\27[0m" else ("\27[31m%d failed\27[0m"):format(failures))
process.exit(if failures == 0 then 0 else 1)
