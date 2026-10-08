--!nocheck
-- Car alarms (CarAlarms.client) in Downtown, in the client emulator:
--
--   * a shot that lands on a parked car sets it off: its showing lamps flash amber (neon), a
--     glow comes on, the alarm sounds -- on the kit's lamps where the kit is drawn;
--   * no other car goes off, and a shot in the open sets nothing off;
--   * a few seconds later it settles: the lamps are as they were, the glow and the sound gone;
--   * it works on the part-built cars too, where a device cannot draw the kit.
--
--   lune run tools/uitest/caralarms.luau

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local World = require("./world")
local R = World.R

local Vector3 = roblox.Vector3

task.delay(240, function()
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

local place = World.loadPlace("build/Game.rbxl")
local sss = World.service("ServerScriptService")
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("ArenaService"), sss)
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("DistrictService"), sss)
local rs = World.service("ReplicatedStorage")
local Downtown = World.require(sss.DistrictService.Downtown)
local folder = R.new("Folder")
folder.Name = "Downtown"
folder.Parent = World.workspace
Downtown.Build(folder, Vector3.new(-155, 1000, 1500))

local CARS = { Sedan = true, Hatch = true, SUV = true, MuscleCar = true, Pickup = true }
local cars = {}
for _, d in ipairs(folder:GetDescendants()) do
	if d:IsA("Model") and CARS[d:GetAttribute("KitModel")] then
		table.insert(cars, d)
	end
end
check(#cars >= 8, ("%d parked cars"):format(#cars))

-- A device that can draw meshes (a stand-in AssetService, as the citymeshes suite's).
R.ClassMethods.AssetService = {
	CreateEditableMesh = function()
		local mesh = { verts = {} }
		function mesh.AddVertex(self, p)
			table.insert(self.verts, p)
			return #self.verts
		end
		function mesh.AddNormal(_, n)
			return n
		end
		function mesh.AddTriangle()
			return 1
		end
		function mesh.SetFaceNormals() end
		return mesh
	end,
	CreateMeshPartAsync = function(_, mesh)
		local lo, hi = Vector3.new(1e9, 1e9, 1e9), Vector3.new(-1e9, -1e9, -1e9)
		for _, v in ipairs(mesh.verts) do
			lo, hi = lo:Min(v), hi:Max(v)
		end
		local part = R.new("MeshPart")
		part.Size = hi - lo
		return part
	end,
}
local sps = World.service("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
World.run(sps:FindFirstChild("CityMeshes"))
World.advance(1)
World.run(sps:FindFirstChild("CarAlarms"))
World.advance(0.2)

local CombatFX = World.require(rs:FindFirstChild("CombatFX"))
local AMBER = roblox.Color3.fromRGB(255, 168, 36)

local function showingLamps(car)
	local list = {}
	for _, d in ipairs(car:GetDescendants()) do
		if d:IsA("BasePart") and (d.Name == "Headlight" or d.Name == "Taillight") and d.Transparency < 1
			and (d.LocalTransparencyModifier or 0) < 1 then
			table.insert(list, d)
		end
	end
	return list
end
local function sounding(car)
	for _, d in ipairs(car:GetDescendants()) do
		if d.Name == "CarAlarm" and d:IsA("Sound") then
			return true
		end
	end
	return false
end
local function flashing(car)
	for _, lamp in ipairs(showingLamps(car)) do
		if lamp.Color == AMBER and lamp.Material == roblox.Enum.Material.Neon then
			return true
		end
	end
	return false
end

print("a shot into a car")
local car, other = cars[1], cars[2]
local lamps = showingLamps(car)
local before = {}
for _, lamp in ipairs(lamps) do
	before[lamp] = { lamp.Color, lamp.Material }
end
local inKit = #lamps > 0 and lamps[1]:IsDescendantOf(car:FindFirstChild("KitMeshes"))
check(#lamps >= 2 and inKit, ("its lamps are the kit's (%d showing)"):format(#lamps))
local body = car:FindFirstChild("Body")
CombatFX.Gunfire:Fire(body.Position + Vector3.new(0, 0.3, 0))
World.advance(0.1)
check(flashing(car), "the hazards flash amber")
check(sounding(car), "the alarm sounds")
local glow = false
for _, d in ipairs(car:GetDescendants()) do
	if d:IsA("PointLight") and d.Name == "AlarmGlow" then
		glow = true
	end
end
check(glow, "and the lamps throw an amber glow")
local seenOff = false
for _ = 1, 10 do
	World.advance(0.1)
	if not flashing(car) then
		seenOff = true
	end
end
check(seenOff, "on, off, on: they blink")
check(not sounding(other) and not flashing(other), "the car next to it stays quiet")

print("a shot in the open")
CombatFX.Gunfire:Fire(Vector3.new(-155, 1300, 1500))
World.advance(0.2)
local any = 0
for _, c in ipairs(cars) do
	if c ~= car and sounding(c) then
		any += 1
	end
end
check(any == 0, "sets nothing off")

print("a few seconds later")
World.advance(8)
local restored = not sounding(car)
for lamp, was in pairs(before) do
	if lamp.Color ~= was[1] or lamp.Material ~= was[2] then
		restored = false
	end
end
for _, d in ipairs(car:GetDescendants()) do
	if d.Name == "AlarmGlow" then
		restored = false
	end
end
check(restored, "it settles: lamps as they were, the glow and the sound gone")

print("a car where the kit is not drawn")
local plain = nil
for _, c in ipairs(cars) do
	if c ~= car and c ~= other then
		local meshes = c:FindFirstChild("KitMeshes")
		if meshes then
			meshes:Destroy()
		end
		for _, d in ipairs(c:GetDescendants()) do
			if d:IsA("BasePart") then
				d.LocalTransparencyModifier = 0
			end
		end
		plain = c
		break
	end
end
local plainBody = plain:FindFirstChild("Body")
CombatFX.Gunfire:Fire(plainBody.Position)
World.advance(0.1)
check(#showingLamps(plain) >= 2 and flashing(plain) and sounding(plain), "its part-built lamps flash and it sounds")

print(if failures == 0 then "\27[32mall car alarm checks passed\27[0m" else ("\27[31m%d failed\27[0m"):format(failures))
process.exit(if failures == 0 then 0 else 1)
