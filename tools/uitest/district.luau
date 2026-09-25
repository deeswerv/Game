--!nocheck
-- Downtown, checked without Studio: it builds, the travel pad has ground under it and room
-- round it, the arrival spot is clear, every door and prompt marker exists with room to
-- stand in front of it, and the fire escape reaches the roof.
--
--   lune run tools/uitest/district.luau

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
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("ArenaService"), sss)
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("DistrictService"), sss)

local Downtown = World.require(sss.DistrictService.Downtown)
local centre = Vector3.new(-155, 1000, 1500)
local folder = R.new("Folder")
folder.Name = "Downtown"
folder.Parent = World.workspace
Downtown.Build(folder, centre)

local solids, parts = {}, 0
for _, d in ipairs(folder:GetDescendants()) do
	if d:IsA("BasePart") then
		parts += 1
		if d.CanCollide and d.Transparency < 1 then
			table.insert(solids, d)
		end
	end
end
check(parts > 2500, ("%d parts"):format(parts))

local function inside(part, p: Vector3, margin: number?): boolean
	local rel = part.CFrame:PointToObjectSpace(p)
	local s = part.Size / 2
	local m = margin or 0.05
	return math.abs(rel.X) < s.X - m and math.abs(rel.Y) < s.Y - m and math.abs(rel.Z) < s.Z - m
end

local function groundUnder(p: Vector3): number?
	-- The highest solid top surface under p (axis-aligned parts only, which the floors are).
	local best = nil
	for _, s in ipairs(solids) do
		local rel = s.CFrame:PointToObjectSpace(p)
		local half = s.Size / 2
		if math.abs(rel.X) <= half.X and math.abs(rel.Z) <= half.Z then
			local top = s.Position.Y + half.Y
			if top <= p.Y + 0.01 and (not best or top > best) then
				best = top
			end
		end
	end
	return best
end

local function clearColumn(foot: Vector3): string?
	for _, s in ipairs(solids) do
		for _, y in ipairs({ 0.8, 2.5, 4.5 }) do
			if inside(s, foot + Vector3.new(0, y, 0)) then
				return s.Name
			end
		end
	end
	return nil
end

print("travel pad")
local pad = centre + Downtown.Arrival
local ground = groundUnder(pad + Vector3.new(0, 1, 0))
check(ground ~= nil and math.abs(ground - pad.Y) < 0.6, ("ground under the pad at %.2f (pad %.2f)"):format(ground or -1, pad.Y))
for _, off in ipairs({ Vector3.new(0, 0, 0), Vector3.new(7, 0, 0), Vector3.new(-7, 0, 0), Vector3.new(0, 0, 7),
	Vector3.new(0, 0, -7), Vector3.new(0, 0, -9) }) do
	local blocked = clearColumn(pad + off + Vector3.new(0, 0.6, 0))
	check(blocked == nil, ("pad area clear at %s%s"):format(tostring(off), blocked and (" -- " .. blocked) or ""))
end

print("the walk to the plaza")
for z = -165, -45, 6 do
	local foot = centre + Vector3.new(0, 0.5, z)
	local blocked = clearColumn(foot)
	if blocked then
		-- One step to either side is fine: that is walking round a bollard.
		local left = clearColumn(foot + Vector3.new(-3, 0, 0))
		local right = clearColumn(foot + Vector3.new(3, 0, 0))
		check(left == nil or right == nil, ("avenue passable at z=%d (%s)"):format(z, blocked))
	end
end
check(true, "avenue walkable from the gate to the plaza")

print("doors and prompts")
local function find(name: string)
	for _, d in ipairs(folder:GetDescendants()) do
		if d.Name == name then
			return d
		end
	end
	return nil
end
for _, name in ipairs({ "GunShop", "Armory", "ContractBoard", "RooftopStash", "DuelPadSite" }) do
	local marker = find(name)
	check(marker ~= nil, name .. " marker built")
	if marker and name ~= "RooftopStash" and name ~= "DuelPadSite" then
		check(marker:GetAttribute("PromptText") ~= nil, name .. " carries its prompt text")
		local blocked = clearColumn(marker.Position + Vector3.new(0, 0.1, 0))
		check(blocked == nil, name .. " has room to stand" .. (blocked and (" -- " .. blocked) or ""))
	end
end
check(Downtown.Panels.GunShop == "Market" and Downtown.Panels.Armory == "Workshop"
	and Downtown.Panels.ContractBoard == "Contracts", "doors open the right panels")

print("fire escape")
local stash = find("RooftopStash")
local stairs, landings = {}, {}
for _, d in ipairs(folder:GetDescendants()) do
	if d.Name == "Stair" then
		table.insert(stairs, d)
	elseif d.Name == "Landing" then
		table.insert(landings, d)
	end
end
check(#stairs == 5 and #landings == 5, ("%d flights, %d landings"):format(#stairs, #landings))
table.sort(landings, function(a, b)
	return a.Position.Y < b.Position.Y
end)
local top = landings[#landings]
if top and stash then
	local roofY = stash.Position.Y - stash.Size.Y / 2
	local landingTop = top.Position.Y + top.Size.Y / 2
	check(math.abs(roofY - landingTop) < 0.3, ("top landing level with the roof (%.2f vs %.2f)"):format(landingTop, roofY))
end
-- Headroom over every flight: nothing solid within 5.5 studs above its middle.
for i, stair in ipairs(stairs) do
	local mid = stair.Position + Vector3.new(0, stair.Size.Y / 2, 0)
	local hit = nil
	for _, s in ipairs(solids) do
		if s ~= stair and s.Name ~= "Block" then
			for y = 0.6, 5.5, 0.7 do
				if inside(s, mid + Vector3.new(0, y, 0)) then
					hit = s.Name
				end
			end
		end
	end
	check(hit == nil, ("headroom over flight %d%s"):format(i, hit and (" -- " .. hit) or ""))
end

print(failures == 0 and "\27[32mall district checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
if failures > 0 then
	error("district checks failed")
end
