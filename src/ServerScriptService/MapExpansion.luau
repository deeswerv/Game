--!strict
-- Expands the middle island outward with three purposeful satellite islets, each
-- reached by a bridge.
--
-- Colours and materials are sampled from the island the game already has, so the new
-- ground reads as part of the same world. Nothing is scattered at random: every islet
-- exists to do a job -- fight on, navigate by, or sit down in.

local WorldBake = require(game:GetService("ServerScriptService").WorldBake)

local MapExpansion = {}

local GRASS = Color3.fromRGB(0, 150, 5)
local GRASS_DARK = Color3.fromRGB(0, 135, 0)
local DIRT_1 = Color3.fromRGB(154, 95, 0)
local DIRT_2 = Color3.fromRGB(135, 74, 0)
local DIRT_3 = Color3.fromRGB(120, 66, 0)
local ROCK = Color3.fromRGB(163, 162, 165)
local WOOD = Color3.fromRGB(96, 63, 42)
local GOLD = Color3.fromRGB(226, 180, 92)

local ISLAND_CENTRE = Vector3.new(-180, 2, 260)

local function part(parent, name, size, cf, colour, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Grass on top, dirt layers tapering underneath, matching the existing cliffs.
local function buildIslet(parent, centre: Vector3, radius: number, name: string)
	local islet = Instance.new("Model")
	islet.Name = name
	islet.Parent = parent

	local layers = {
		{ y = 0.0,   r = 1.00, colour = GRASS,  h = 2.2 },
		{ y = -2.2,  r = 0.94, colour = DIRT_1, h = 3.0 },
		{ y = -5.2,  r = 0.84, colour = DIRT_2, h = 3.4 },
		{ y = -8.6,  r = 0.68, colour = DIRT_3, h = 4.0 },
		{ y = -12.6, r = 0.44, colour = DIRT_3, h = 5.0 },
	}
	for _, layer in ipairs(layers) do
		local r = radius * layer.r
		for i = 0, 3 do
			part(islet, "Land", Vector3.new(r * 1.62, layer.h, r * 1.62),
				CFrame.new(centre + Vector3.new(0, layer.y - layer.h / 2, 0)) * CFrame.Angles(0, math.rad(i * 45), 0),
				layer.colour)
		end
	end

	for i = 1, 5 do
		local a = math.rad(math.random(0, 360))
		local d = radius * (0.2 + math.random() * 0.55)
		local patch = part(islet, "Patch", Vector3.new(math.random(6, 13), 0.25, math.random(6, 13)),
			CFrame.new(centre + Vector3.new(math.cos(a) * d, 1.15, math.sin(a) * d)) * CFrame.Angles(0, a, 0),
			GRASS_DARK)
		patch.CanCollide = false
	end
	return islet
end

local function buildTree(parent, pos: Vector3, scale: number)
	part(parent, "Trunk", Vector3.new(1.4 * scale, 7 * scale, 1.4 * scale),
		CFrame.new(pos + Vector3.new(0, 3.5 * scale, 0)), WOOD, Enum.Material.Wood)
	local c1 = part(parent, "Canopy", Vector3.new(9 * scale, 4.5 * scale, 9 * scale),
		CFrame.new(pos + Vector3.new(0, 8.5 * scale, 0)) * CFrame.Angles(0, math.rad(math.random(0, 45)), 0), GRASS)
	c1.CanCollide = false
	local c2 = part(parent, "CanopyTop", Vector3.new(6 * scale, 3.6 * scale, 6 * scale),
		CFrame.new(pos + Vector3.new(0, 11.6 * scale, 0)) * CFrame.Angles(0, math.rad(math.random(0, 45)), 0), GRASS_DARK)
	c2.CanCollide = false
end

local function buildRock(parent, pos: Vector3, scale: number)
	return part(parent, "Rock", Vector3.new(4 * scale, 3 * scale, 4.5 * scale),
		CFrame.new(pos + Vector3.new(0, 1.4 * scale, 0))
			* CFrame.Angles(math.rad(math.random(-12, 12)), math.rad(math.random(0, 360)), math.rad(math.random(-12, 12))),
		ROCK, Enum.Material.Slate)
end

local function buildBridge(parent, fromPos: Vector3, toPos: Vector3, name: string)
	local bridge = Instance.new("Model")
	bridge.Name = name
	bridge.Parent = parent

	local delta = toPos - fromPos
	local length = delta.Magnitude
	local steps = math.max(4, math.floor(length / 6))
	local dir = delta.Unit

	for i = 0, steps do
		local t = i / steps
		local pos = fromPos + delta * t
		local sag = math.sin(t * math.pi) * 1.6
		local cf = CFrame.lookAt(pos + Vector3.new(0, -sag, 0), pos + dir + Vector3.new(0, -sag, 0))
		part(bridge, "Plank", Vector3.new(8, 0.6, 6.4), cf, WOOD, Enum.Material.WoodPlanks)
		if i % 2 == 0 then
			for _, side in ipairs({ -1, 1 }) do
				part(bridge, "Post", Vector3.new(0.6, 4, 0.6), cf * CFrame.new(side * 3.6, 2.2, 0), WOOD, Enum.Material.Wood)
			end
		end
	end

	for _, side in ipairs({ -1, 1 }) do
		local mid = fromPos + delta * 0.5
		local cf = CFrame.lookAt(mid + Vector3.new(0, 3.6, 0), mid + dir + Vector3.new(0, 3.6, 0))
		local rail = part(bridge, "Rail", Vector3.new(0.3, 0.3, length), cf * CFrame.new(side * 3.6, 0, 0),
			Color3.fromRGB(120, 96, 60), Enum.Material.Fabric)
		rail.CanCollide = false
	end
	return bridge
end

local function buildArena(parent, centre: Vector3, radius: number)
	for i = 0, 11 do
		local a = math.rad(i * 30)
		local pos = centre + Vector3.new(math.cos(a) * radius * 0.72, 0, math.sin(a) * radius * 0.72)
		part(parent, "Pillar", Vector3.new(4, math.random(6, 11), 4),
			CFrame.new(pos + Vector3.new(0, 4, 0)) * CFrame.Angles(0, a, 0), ROCK, Enum.Material.Slate)
	end
	for i = 1, 6 do
		local a = math.rad(math.random(0, 360))
		buildRock(parent, centre + Vector3.new(math.cos(a) * radius * 0.4, 1, math.sin(a) * radius * 0.4), 0.8 + math.random() * 0.8)
	end
	part(parent, "Dais", Vector3.new(radius * 0.5, 1.6, radius * 0.5),
		CFrame.new(centre + Vector3.new(0, 1.9, 0)) * CFrame.Angles(0, math.rad(45), 0), ROCK, Enum.Material.Slate)
end

local function buildTower(parent, base: Vector3)
	local height = 46
	for i = 0, 7 do
		local w = 12 - i * 1.1
		part(parent, "TowerBlock", Vector3.new(w, 6, w),
			CFrame.new(base + Vector3.new(0, 3 + i * 6, 0)) * CFrame.Angles(0, math.rad(i * 11), 0),
			i % 2 == 0 and ROCK or Color3.fromRGB(140, 140, 145), Enum.Material.Slate)
	end
	part(parent, "TowerDeck", Vector3.new(15, 1.2, 15), CFrame.new(base + Vector3.new(0, height + 2, 0)), WOOD, Enum.Material.WoodPlanks)
	for _, off in ipairs({ Vector3.new(6.5,0,6.5), Vector3.new(-6.5,0,6.5), Vector3.new(6.5,0,-6.5), Vector3.new(-6.5,0,-6.5) }) do
		part(parent, "DeckPost", Vector3.new(0.7, 5, 0.7), CFrame.new(base + Vector3.new(0, height + 5, 0) + off), WOOD, Enum.Material.Wood)
	end
	local beacon = part(parent, "Beacon", Vector3.new(3, 3, 3),
		CFrame.new(base + Vector3.new(0, height + 9, 0)) * CFrame.Angles(math.rad(35), math.rad(35), 0), GOLD, Enum.Material.Neon)
	beacon.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = GOLD light.Brightness = 5 light.Range = 90 light.Parent = beacon
end

local function buildGrove(parent, centre: Vector3, radius: number)
	for i = 1, 7 do
		local a = math.rad(i * 51 + math.random(-12, 12))
		local d = radius * (0.45 + math.random() * 0.4)
		buildTree(parent, centre + Vector3.new(math.cos(a) * d, 1, math.sin(a) * d), 0.9 + math.random() * 0.5)
	end
	part(parent, "FireRing", Vector3.new(7, 1, 7), CFrame.new(centre + Vector3.new(0, 1.4, 0)) * CFrame.Angles(0, math.rad(45), 0), ROCK, Enum.Material.Slate)
	local fire = part(parent, "Fire", Vector3.new(3, 2.4, 3), CFrame.new(centre + Vector3.new(0, 2.6, 0)), Color3.fromRGB(255, 150, 60), Enum.Material.Neon)
	fire.CanCollide = false
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 160, 70) l.Brightness = 3 l.Range = 40 l.Parent = fire
	for i = 0, 3 do
		local base = CFrame.new(centre) * CFrame.Angles(0, math.rad(i * 90 + 45), 0) * CFrame.new(9, 0, 0)
		part(parent, "LogSeat", Vector3.new(1.8, 1.8, 6), base * CFrame.new(0, 1.9, 0), WOOD, Enum.Material.Wood)
	end
end

-- Real island ground between an islet and the centre, to anchor a bridge on.
local function findShore(from: Vector3, root: Instance?)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = root and { root } or {}

	local toCentre = ISLAND_CENTRE - from
	local flat = Vector3.new(toCentre.X, 0, toCentre.Z)
	local dir, dist = flat.Unit, flat.Magnitude

	for step = 10, dist, 4 do
		local probe = from + dir * step
		local hit = workspace:Raycast(probe + Vector3.new(0, 70, 0), Vector3.new(0, -140, 0), params)
		if hit and hit.Instance.CanCollide and hit.Instance.Name ~= "Baseplate" then
			return hit.Position
		end
	end
	return nil
end

function MapExpansion.Build()
	if WorldBake.Skip("MapExpansion", "MapExpansion") then
		return
	end
	local existing = workspace:FindFirstChild("MapExpansion")
	if existing then existing:Destroy() end

	local root = Instance.new("Folder")
	root.Name = "MapExpansion"
	root.Parent = workspace

	local sites = {
		{ name = "ProvingGround", centre = Vector3.new(-268, 6, 206), radius = 44, kind = "arena" },
		{ name = "WatchPoint",    centre = Vector3.new(-318, 6, 306), radius = 34, kind = "tower" },
		{ name = "Hollow",        centre = Vector3.new(-196, 6, 398), radius = 38, kind = "grove" },
	}

	for _, site in ipairs(sites) do
		local islet = buildIslet(root, site.centre, site.radius, site.name)
		if site.kind == "arena" then
			buildArena(islet, site.centre, site.radius)
		elseif site.kind == "tower" then
			buildTower(islet, site.centre + Vector3.new(0, 1, 0))
			for i = 1, 4 do
				local a = math.rad(i * 90 + 30)
				buildRock(islet, site.centre + Vector3.new(math.cos(a) * site.radius * 0.6, 1, math.sin(a) * site.radius * 0.6), 1.1)
			end
		else
			buildGrove(islet, site.centre, site.radius)
		end

		local shore = findShore(site.centre, root)
		if shore then
			local toShore = Vector3.new(shore.X - site.centre.X, 0, shore.Z - site.centre.Z)
			local edge = site.centre + toShore.Unit * (site.radius * 0.92) + Vector3.new(0, 1, 0)
			buildBridge(root, edge, shore + Vector3.new(0, 1.4, 0), "Bridge_" .. site.name)
		end
	end

	return root
end

MapExpansion.Build()

return MapExpansion
