--!nocheck
-- The city at night (CityLights.client), checked without Studio on the real Downtown:
--
--   * by day nothing is touched -- not a part, not a light;
--   * at night every lamp globe glows, the lights under them are brighter, and a share of
--     the facade windows is lit (not all, not none), in warm colours with the odd blue one;
--   * after midnight most of those windows go dark again, but not every one;
--   * in the morning every part is back exactly as it was built.
--
--   lune run tools/uitest/citylights.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R
local Vector3 = roblox.Vector3

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
local sss = World.service("ServerScriptService")
local lighting = World.service("Lighting")
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("ArenaService"), sss)
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("DistrictService"), sss)
local Downtown = World.require(sss.DistrictService.Downtown)
local folder = R.new("Folder")
folder.Name = "Downtown"
folder.Parent = World.workspace
Downtown.Build(folder, Vector3.new(-155, 1000, 1500))

local LAMPS = { LanternGlass = true, SoffitLamp = true, TunnelLamp = true, WalkLamp = true, LightPanel = true }
local WINDOWS = { Windows = true, ArchGlass = true, BayGlass = true }
local built = {}
local lamps, windows, lights = {}, {}, {}
for _, d in ipairs(folder:GetDescendants()) do
	if d:IsA("BasePart") then
		built[d] = { material = d.Material, colour = d.Color, transparency = d.Transparency }
		if LAMPS[d.Name] then
			table.insert(lamps, d)
		elseif WINDOWS[d.Name] then
			table.insert(windows, d)
		end
	elseif d:IsA("PointLight") or d:IsA("SpotLight") then
		lights[d] = d.Brightness
	end
end
print(("%d lamp globes, %d windows"):format(#lamps, #windows))

local function changed(): number
	local n = 0
	for part, was in pairs(built) do
		if part.Material ~= was.material or part.Color ~= was.colour or part.Transparency ~= was.transparency then
			n += 1
		end
	end
	return n
end
local function litWindows(): number
	local n = 0
	for _, w in ipairs(windows) do
		if w.Material == roblox.Enum.Material.Neon then
			n += 1
		end
	end
	return n
end

print("by day")
lighting.ClockTime = 13
World.run(World.service("StarterPlayer"):FindFirstChild("StarterPlayerScripts"):FindFirstChild("CityLights"))
World.advance(1.5)
check(changed() == 0, "at one in the afternoon nothing is touched")
local lightsSame = true
for light, b in pairs(lights) do
	lightsSame = lightsSame and math.abs(light.Brightness - b) < 1e-6
end
check(lightsSame, "and the lights are as built")

print("at night")
lighting.ClockTime = 21.5
World.advance(1.5)
local glowing = 0
for _, l in ipairs(lamps) do
	if l.Material == roblox.Enum.Material.Neon then
		glowing += 1
	end
end
check(glowing == #lamps, ("every lamp globe glows (%d of %d)"):format(glowing, #lamps))
local brighter = true
for light, b in pairs(lights) do
	brighter = brighter and light.Brightness > b * 1.4
end
check(brighter, "the lights under them are brighter")
local evening = litWindows()
local share = evening / #windows
check(share > 0.25 and share < 0.5, ("a share of the windows is lit, not all (%d of %d, %.0f%%)"):format(evening, #windows, share * 100))
local colours = {}
for _, w in ipairs(windows) do
	if w.Material == roblox.Enum.Material.Neon then
		colours[tostring(w.Color)] = true
	end
end
local kinds = 0
for _ in pairs(colours) do
	kinds += 1
end
check(kinds >= 3, ("in more than one colour (%d)"):format(kinds))

print("after midnight")
lighting.ClockTime = 3.5
World.advance(1.5)
local late = litWindows()
check(late < evening * 0.6 and late > 0, ("most go dark, not every one (%d lit, from %d)"):format(late, evening))

print("morning")
lighting.ClockTime = 10
World.advance(1.5)
check(changed() == 0, "every part is back exactly as it was built")
lightsSame = true
for light, b in pairs(lights) do
	lightsSame = lightsSame and math.abs(light.Brightness - b) < 1e-6
end
check(lightsSame, "and so are the lights")

local bad = {}
for _, e in ipairs(R.errors or {}) do
	if tostring(e):match("CityLights") then
		table.insert(bad, tostring(e))
	end
end
check(#bad == 0, "no errors from the script" .. (#bad > 0 and (": " .. bad[1]) or ""))

print("")
if failures == 0 then
	print("\27[32mall city light checks passed\27[0m")
	require("@lune/process").exit(0)
else
	print(("\27[31m%d city light check(s) failed\27[0m"):format(failures))
	require("@lune/process").exit(1)
end
