--!nocheck
-- ZEE TOWER's roof as a place to fight, checked without Studio on the real Downtown:
--
--   * nothing invisible that you can bump into stands anywhere on the floor -- the only
--     invisible walls are the ones just outside the rail (and the district's own edge stops
--     below the roof: it used to cut the roof in two, behind the elevator);
--   * walking from where the elevator lets you out, you can reach the Don's spot and every spot
--     his people come from, and most of the floor -- a 1-stud grid flood-filled round
--     everything solid at body height;
--   * it is big enough to move in: the deck is at least 110 x 80, and the open floor is most
--     of it.
--
--   lune run tools/uitest/penthouse.luau

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
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("ArenaService"), sss)
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("DistrictService"), sss)
local Downtown = World.require(sss.DistrictService.Downtown)
local CENTRE = Vector3.new(-155, 1000, 1500)
local folder = R.new("Folder")
folder.Name = "Downtown"
folder.Parent = World.workspace
Downtown.Build(folder, CENTRE)

local deck, arrival, boss = nil, nil, nil
local adds = {}
for _, d in ipairs(folder:GetDescendants()) do
	if d:IsA("BasePart") then
		if d.Name == "PenthouseDeck" then
			deck = d
		elseif d.Name == "TowerArrival" then
			arrival = d
		elseif d.Name == "TowerBossSpot" then
			boss = d
		elseif d.Name == "TowerAddSpot" then
			table.insert(adds, d)
		end
	end
end
check(deck and arrival and boss and #adds >= 4, ("the roof is there, with the arrival, the Don's spot and %d add spots"):format(#adds))
local frame = deck.CFrame
local top = deck.Size.Y / 2
check(deck.Size.X >= 110 and deck.Size.Z >= 80, ("the deck is %d x %d"):format(deck.Size.X, deck.Size.Z))

-- Everything solid near the roof, in the deck's own frame, as boxes.
local function corners(p)
	local half = p.Size / 2
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sy in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				local w = frame:PointToObjectSpace(p.CFrame:PointToWorldSpace(Vector3.new(sx * half.X, sy * half.Y, sz * half.Z)))
				lo = Vector3.new(math.min(lo.X, w.X), math.min(lo.Y, w.Y), math.min(lo.Z, w.Z))
				hi = Vector3.new(math.max(hi.X, w.X), math.max(hi.Y, w.Y), math.max(hi.Z, w.Z))
			end
		end
	end
	return lo, hi
end
local W, D = deck.Size.X, deck.Size.Z
local solids = {}
local invisible = {}
for _, p in ipairs(World.workspace:GetDescendants()) do
	if p:IsA("BasePart") and p ~= deck and p.CanCollide then
		local lo, hi = corners(p)
		-- Body height above the floor: knees to head.
		if hi.Y > top + 1 and lo.Y < top + 5.5 and hi.X > -W / 2 and lo.X < W / 2 and hi.Z > -D / 2 and lo.Z < D / 2 then
			table.insert(solids, { lo = lo, hi = hi, name = p.Name })
			if p.Transparency >= 0.95 then
				-- The edge walls sit just outside the rail; anything else invisible is a trap.
				local inside = lo.X < W / 2 - 1.5 and hi.X > -W / 2 + 1.5 and lo.Z < D / 2 - 1.5 and hi.Z > -D / 2 + 1.5
				if inside then
					table.insert(invisible, p:GetFullName())
				end
			end
		end
	end
end
check(#invisible == 0, "nothing invisible stands on the floor" .. (#invisible > 0 and (": " .. invisible[1]) or ""))

-- Flood fill from the arrival on a 1-stud grid; a cell is blocked if a solid covers its middle
-- (padded a little for a body's width).
local PAD = 0.9
local function blocked(x, z)
	for _, s in ipairs(solids) do
		if x > s.lo.X - PAD and x < s.hi.X + PAD and z > s.lo.Z - PAD and z < s.hi.Z + PAD then
			return true
		end
	end
	return false
end
local cols, rows = math.floor(W) - 2, math.floor(D) - 2
local function cellOf(world)
	local l = frame:PointToObjectSpace(world)
	return math.clamp(math.floor(l.X + W / 2) - 1, 0, cols - 1), math.clamp(math.floor(l.Z + D / 2) - 1, 0, rows - 1)
end
local function centreOf(i, j)
	return -W / 2 + 1.5 + i, -D / 2 + 1.5 + j
end
local open, seen = {}, {}
local total, free = 0, 0
for i = 0, cols - 1 do
	open[i] = {}
	seen[i] = {}
	for j = 0, rows - 1 do
		local x, z = centreOf(i, j)
		open[i][j] = not blocked(x, z)
		total += 1
		if open[i][j] then
			free += 1
		end
	end
end
local si, sj = cellOf(arrival.Position)
local queue, head = { { si, sj } }, 1
seen[si][sj] = true
local reached = 0
while queue[head] do
	local c = queue[head]
	head += 1
	reached += 1
	for _, d in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		local i, j = c[1] + d[1], c[2] + d[2]
		if i >= 0 and i < cols and j >= 0 and j < rows and open[i][j] and not seen[i][j] then
			seen[i][j] = true
			table.insert(queue, { i, j })
		end
	end
end
check(open[si][sj], "the elevator lets you out onto open floor")
local function reachable(part)
	local i, j = cellOf(part.Position)
	-- The spot itself, or a cell right next to it.
	for di = -1, 1 do
		for dj = -1, 1 do
			if seen[i + di] and seen[i + di][j + dj] then
				return true
			end
		end
	end
	return false
end
check(reachable(boss), "from the elevator you can walk to the Don")
local allAdds = true
for _, a in ipairs(adds) do
	allAdds = allAdds and reachable(a)
end
check(allAdds, "and to every spot his people come from")
check(free / total > 0.75, ("open floor is %.0f%% of the deck"):format(free / total * 100))
check(reached / free > 0.97, ("and nearly all of it joins up (%.0f%%)"):format(reached / free * 100))

print("")
if failures == 0 then
	print("\27[32mall penthouse checks passed\27[0m")
	require("@lune/process").exit(0)
else
	print(("\27[31m%d penthouse check(s) failed\27[0m"):format(failures))
	require("@lune/process").exit(1)
end
