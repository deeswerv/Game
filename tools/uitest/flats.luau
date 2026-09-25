--!nocheck
-- The Flats battleground (CoverService + CoverService.Flats), built and checked without Studio:
--
--   * it builds inside the courtyard between the pillars, with no neon;
--   * NPCConfig.Spawns and Flats.Posts are the same posts, and every post (and the Warlord's)
--     has room to stand -- nothing solid within a few studs;
--   * the ways through are open: the gatehouse doorway, the camp gate, the guards' gap;
--   * the high ground can be reached: the tower ramp meets its deck, the terrace steps climb
--     one stud at a time to its top;
--   * the solid pieces are tagged as cover for the AI.
--
--   lune run tools/uitest/flats.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R
local Vector3 = roblox.Vector3

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
for _, name in ipairs({ "WorldBake", "ArenaService", "CoverService" }) do
	R.mirror(place:GetService("ServerScriptService"):FindFirstChild(name), sss)
end
local rs = World.service("ReplicatedStorage")
local NPCConfig = World.require(rs.NPCConfig)
local CoverService = World.require(sss.CoverService)
local Flats = CoverService.Flats
local centre = CoverService.CENTRE
local folder = World.workspace:FindFirstChild(CoverService.FOLDER)

print("build")
check(folder ~= nil, "workspace." .. CoverService.FOLDER .. " built")
local parts, solids, glowing, outside = 0, {}, 0, 0
for _, d in ipairs(folder:GetDescendants()) do
	if d:IsA("BasePart") then
		parts += 1
		if d.Material.Name == "Neon" then
			glowing += 1
		end
		local rel = d.Position - centre
		if math.abs(rel.X) > 50 or math.abs(rel.Z) > 50 then
			outside += 1
		end
		if d.CanCollide and d.Transparency < 1 then
			table.insert(solids, d)
		end
	end
end
check(parts > 450, ("%d parts"):format(parts))
check(glowing == 0, "no neon")
check(outside == 0, ("everything inside the courtyard (%d outside)"):format(outside))

-- The world-space box of a part, and the flat gap from a point to it.
local function box(part)
	local cf, s = part.CFrame, part.Size
	local ext = Vector3.new(
		math.abs(cf.XVector.X) * s.X + math.abs(cf.YVector.X) * s.Y + math.abs(cf.ZVector.X) * s.Z,
		math.abs(cf.XVector.Y) * s.X + math.abs(cf.YVector.Y) * s.Y + math.abs(cf.ZVector.Y) * s.Z,
		math.abs(cf.XVector.Z) * s.X + math.abs(cf.YVector.Z) * s.Y + math.abs(cf.ZVector.Z) * s.Z) / 2
	return cf.Position - ext, cf.Position + ext
end
local function gap(p, part): number
	local lo, hi = box(part)
	if hi.Y < p.Y + 0.4 or lo.Y > p.Y + 5.5 then
		return math.huge                            -- under foot or over head
	end
	local dx = math.max(lo.X - p.X, 0, p.X - hi.X)
	local dz = math.max(lo.Z - p.Z, 0, p.Z - hi.Z)
	return math.sqrt(dx * dx + dz * dz)
end
local function nearest(p)
	local best, name = math.huge, nil
	for _, s in ipairs(solids) do
		local g = gap(p, s)
		if g < best then
			best, name = g, s.Name
		end
	end
	return best, name
end

print("posts")
local posts = {}
for _, side in ipairs({ "Hostile", "Guard" }) do
	for _, post in ipairs(Flats.Posts[side]) do
		table.insert(posts, { archetype = post[1], at = centre + post[2] })
	end
end
check(#posts == #NPCConfig.Spawns, ("as many posts as spawns (%d / %d)"):format(#posts, #NPCConfig.Spawns))
for i, post in ipairs(posts) do
	local spec = NPCConfig.Spawns[i]
	local same = spec and spec.archetype == post.archetype
		and math.abs(spec.position.X - post.at.X) < 0.01 and math.abs(spec.position.Z - post.at.Z) < 0.01
	check(same, ("spawn %d is the %s post at (%d, %d)"):format(i, post.archetype, post.at.X, post.at.Z))
	local room, what = nearest(Vector3.new(post.at.X, centre.Y, post.at.Z))
	check(room >= 4.5, ("%s post has room (%.1f to %s)"):format(post.archetype, room, tostring(what)))
end
local hostile = 0
for _, spec in ipairs(NPCConfig.Spawns) do
	if NPCConfig.Get(spec.archetype).Faction == "Hostile" then
		hostile += 1
	end
end
check(hostile <= 6, ("no more than six raiders (%d)"):format(hostile))
local BossPost = Vector3.new(-625, centre.Y, 88)
local room, what = nearest(BossPost)
check(room >= 5, ("the Warlord has room at the camp gate (%.1f to %s)"):format(room, tostring(what)))

print("ways through")
local function clearLine(from, to, label)
	local steps = math.ceil((to - from).Magnitude / 1)
	for i = 0, steps do
		local p = from:Lerp(to, i / steps)
		local g, name = nearest(p)
		if g < 0.9 then
			check(false, ("%s blocked by %s at (%.0f, %.0f)"):format(label, tostring(name), p.X - centre.X, p.Z - centre.Z))
			return
		end
	end
	check(true, label .. " is open")
end
local y = centre.Y
clearLine(centre + Vector3.new(-6, 0, 0), centre + Vector3.new(6, 0, 0), "the gatehouse doorway")
clearLine(centre + Vector3.new(-50, 0, 0), centre + Vector3.new(-40, 0, 0), "the camp gate")
clearLine(centre + Vector3.new(16, 0, 0), centre + Vector3.new(26, 0, 0), "the guards' gap")
clearLine(centre + Vector3.new(-14, 0, -2.5), centre + Vector3.new(-14, 0, 22), "the camp's front, north of the fire")
_ = y

print("high ground")
local deck, ramp, terrace, steps = nil, nil, nil, {}
for _, s in ipairs(solids) do
	if s.Name == "TowerDeck" then
		deck = s
	elseif s.Name == "TowerRamp" then
		ramp = s
	elseif s.Name == "Terrace" then
		terrace = s
	elseif s.Name == "Step" then
		table.insert(steps, s)
	end
end
if deck and ramp then
	local _, deckTop = box(deck)
	local _, rampTop = box(ramp)
	check(math.abs(rampTop.Y - deckTop.Y) < 0.8, ("the tower ramp reaches its deck (%.1f vs %.1f)"):format(rampTop.Y, deckTop.Y))
	local lo = box(ramp)
	check(lo.Y - centre.Y < 0.3, "and starts on the ground")
else
	check(false, "the tower has a deck and a ramp")
end
table.sort(steps, function(a, b)
	return a.Size.Y < b.Size.Y
end)
local climbs = #steps == 5
for i, s in ipairs(steps) do
	local _, top = box(s)
	if math.abs(top.Y - centre.Y - i) > 0.05 then
		climbs = false
	end
end
local terraceTop = terrace and select(2, box(terrace)).Y - centre.Y or -1
check(climbs and math.abs(terraceTop - 5) < 0.05, ("the terrace steps climb a stud at a time to its top (%.1f)"):format(terraceTop))

print("cover")
local inHere = 0
for _, d in ipairs(folder:GetDescendants()) do
	if d:IsA("BasePart") and CoverService.IsCover(d) then
		inHere += 1
	end
end
check(inHere >= 60, ("%d pieces count as cover"):format(inHere))

print(failures == 0 and "\27[32mall flats checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
require("@lune/process").exit(failures == 0 and 0 or 1)
