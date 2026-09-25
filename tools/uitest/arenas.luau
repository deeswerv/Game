--!nocheck
-- The duel maps, end to end, without Studio:
--
--   1. ArenaService builds every map (server side) into workspace.Arenas.
--   2. Each map: the spawns sit on the floor, inside the bounds, and no solid prop overlaps
--      the space a character stands in; the zone and look attributes are published.
--   3. Claim hands two bouts two different maps, and does not repeat a pair's last map.
--   4. ArenaMood (client) lights a map while the camera is in it, and puts the world back
--      -- from the World_ attributes AmbienceService publishes -- when it leaves.
--
--   lune run tools/uitest/arenas.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R

local Vector3, CFrame = roblox.Vector3, roblox.CFrame
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
for _, name in ipairs({ "WorldBake", "ArenaService" }) do
	R.mirror(place:GetService("ServerScriptService"):FindFirstChild(name), sss)
end

print("build")
local ArenaService = World.require(sss.ArenaService)
local workspace = World.workspace
local arenas = workspace:FindFirstChild("Arenas")
check(arenas ~= nil, "workspace.Arenas exists")
local maps = ArenaService.List()
check(#maps == 4, ("four maps loaded (%d)"):format(#maps))

-- ------------------------------------------------------------------ maps --

local function corners(part)
	-- Does `part` (an oriented box) contain the point p, shrunk by a small margin?
	return function(p)
		local rel = part.CFrame:PointToObjectSpace(p)
		local s = part.Size / 2
		return math.abs(rel.X) < s.X - 0.05 and math.abs(rel.Y) < s.Y - 0.05 and math.abs(rel.Z) < s.Z - 0.05
	end
end

for _, map in ipairs(maps) do
	print(map.Name)
	local folder = arenas and arenas:FindFirstChild(map.Id)
	check(folder ~= nil, "folder built")
	if folder then
		local parts, solids = 0, {}
		for _, d in ipairs(folder:GetDescendants()) do
			if d:IsA("BasePart") then
				parts += 1
				if d.CanCollide and d.Transparency < 1 then
					table.insert(solids, d)
				end
			end
		end
		check(parts > 200, ("%d parts"):format(parts))
		check(typeof(folder:GetAttribute("ZoneCentre")) == "Vector3", "zone published")
		check(folder:GetAttribute("Look_Lighting_ClockTime") ~= nil, "look published")

		for index = 1, 2 do
			local spawn = ArenaService.SpawnCFrame(map.Id, index)
			local p = spawn.Position
			local d = p - map.centre
			check(math.abs(d.X) < map.HalfWidth and math.abs(d.Z) < map.HalfLength,
				("spawn %d inside the bounds"):format(index))
			check(ArenaService.Contains(p) == map.Id, ("spawn %d is in this map's zone"):format(index))

			-- Something solid under the feet, within a stud or so of where they land.
			local foot = p - Vector3.new(0, 3, 0)
			local grounded = false
			for _, s in ipairs(solids) do
				local rel = s.CFrame:PointToObjectSpace(foot - Vector3.new(0, 0.5, 0))
				local half = s.Size / 2
				if math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z and math.abs(rel.Y) <= half.Y + 0.6 then
					grounded = true
					break
				end
			end
			check(grounded, ("spawn %d stands on the floor"):format(index))

			-- The column a character occupies is clear of solid props.
			local blocked = nil
			for _, s in ipairs(solids) do
				local inside = corners(s)
				for _, y in ipairs({ 0.6, 2.5, 4.5 }) do
					for _, off in ipairs({ Vector3.new(0, 0, 0), Vector3.new(1.2, 0, 0), Vector3.new(-1.2, 0, 0),
						Vector3.new(0, 0, 1.2), Vector3.new(0, 0, -1.2) }) do
						if inside(foot + Vector3.new(0, y, 0) + off) then
							blocked = s:GetFullName()
						end
					end
				end
			end
			check(blocked == nil, ("spawn %d clear%s"):format(index, blocked and (" -- blocked by " .. blocked) or ""))

			-- Facing the other spawn.
			local other = ArenaService.SpawnCFrame(map.Id, 3 - index).Position
			local look = spawn.LookVector
			local want = (Vector3.new(other.X, p.Y, other.Z) - p).Unit
			check(look:Dot(want) > 0.99, ("spawn %d faces the opponent"):format(index))
		end
	end
end

-- -------------------------------------------------------------- claiming --

print("claiming")
local a, b, c, d = { Name = "a" }, { Name = "b" }, { Name = "c" }, { Name = "d" }
local first = ArenaService.Claim({ a, b })
local second = ArenaService.Claim({ c, d })
check(first ~= second, ("two bouts at once get two maps (%s, %s)"):format(first, second))
ArenaService.Release(first)
ArenaService.Release(second)
for _ = 1, 12 do
	local again = ArenaService.Claim({ a, b })
	ArenaService.Release(again)
	check(again ~= first, ("a rematch moves to a new map (%s -> %s)"):format(first, again))
	first = again
end

-- ------------------------------------------------------------------ mood --

print("lighting")
local Lighting = World.service("Lighting")
-- What AmbienceService would have published for a mid-morning world.
Lighting.ClockTime = 9
Lighting:SetAttribute("World_ClockTime", 9)
Lighting:SetAttribute("World_Brightness", 2.2)
Lighting.Brightness = 2.2
local grade = Lighting:FindFirstChild("Grade")
if grade then
	grade:SetAttribute("World_TintColor", grade.TintColor)
end
local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
local worldHaze = atmosphere and atmosphere.Color

local moodScript
for _, s in ipairs(World.service("StarterPlayer").StarterPlayerScripts:GetChildren()) do
	if s.Name == "ArenaMood" then
		moodScript = s
	end
end
check(moodScript ~= nil, "ArenaMood present")
World.run(moodScript)

local camera = workspace.CurrentCamera
local dock = ArenaService.Get("Dockyard")
camera.CFrame = CFrame.new(dock.centre + Vector3.new(0, 6, -40))
World.advance(1.4)
check(math.abs(Lighting.ClockTime - dock.Look.Lighting.ClockTime) < 0.01,
	("in the Dockyard, ClockTime is the map's (%.2f)"):format(Lighting.ClockTime))
check(math.abs(Lighting.Brightness - dock.Look.Lighting.Brightness) < 0.01, "and Brightness")
if atmosphere then
	local want = dock.Look.Atmosphere.Color
	local got = atmosphere.Color
	check(math.abs(got.R - want.R) + math.abs(got.G - want.G) + math.abs(got.B - want.B) < 0.02, "and the haze colour")
end

-- The server moves on meanwhile (its value keeps replicating); the map look must hold.
Lighting.ClockTime = 9.3
Lighting:SetAttribute("World_ClockTime", 9.3)
World.advance(0.2)
check(math.abs(Lighting.ClockTime - dock.Look.Lighting.ClockTime) < 0.01, "the look holds against replication")

camera.CFrame = CFrame.new(Vector3.new(0, 20, 0))
World.advance(1.4)
check(math.abs(Lighting.ClockTime - 9.3) < 0.01, ("back in the world, ClockTime is the world's (%.2f)"):format(Lighting.ClockTime))
check(math.abs(Lighting.Brightness - 2.2) < 0.01, "and Brightness")
if atmosphere and worldHaze then
	local got = atmosphere.Color
	check(math.abs(got.R - worldHaze.R) + math.abs(got.G - worldHaze.G) + math.abs(got.B - worldHaze.B) < 0.02,
		"and the haze colour")
end

local errors = R.errors and #R.errors or 0
check(errors == 0, ("no script errors (%d)"):format(errors))
if R.errors then
	for _, e in ipairs(R.errors) do
		print("   ", e)
	end
end

print(failures == 0 and "\27[32mall arena checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
if failures > 0 then
	error("arena checks failed")
end
