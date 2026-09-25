--!strict
-- Biome dressing: gives each zone a look of its own.
--
-- Deliberately ADDITIVE. Everything lives in one `workspace.BiomeDressing` folder and
-- nothing that already existed is moved, recoloured or deleted -- an earlier attempt at
-- reshaping finished terrain produced plateaus sitting on top of a completed island and had
-- to be reverted wholesale. Delete the folder and the world is exactly as it was.
--
-- Placement uses the same rule as the crystal nodes: cast for REAL walkable ground, which
-- means skipping non-collidable hits, or props end up planted on tree canopies.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WorldBake = require(game:GetService("ServerScriptService").WorldBake)

local BiomeService = {}

BiomeService.FOLDER = "BiomeDressing"

-- Per zone: what grows there, and how much of it.
BiomeService.Biomes = {
	Flats = {
		count = 26,
		-- Pale, fungal, slightly wrong -- the island the bandits have had to themselves.
		props = { "Mushroom", "Mushroom", "DeadTree", "Boulder" },
		palette = {
			cap = Color3.fromRGB(168, 96, 150),
			stalk = Color3.fromRGB(226, 216, 198),
			wood = Color3.fromRGB(92, 78, 66),
			rock = Color3.fromRGB(122, 118, 126),
		},
	},
	Reach = {
		count = 22,
		-- Harder, colder, mineral. The far end of the difficulty curve should look like it.
		props = { "Spire", "Spire", "Boulder", "Brazier" },
		palette = {
			cap = Color3.fromRGB(120, 160, 210),
			stalk = Color3.fromRGB(210, 220, 235),
			wood = Color3.fromRGB(74, 70, 82),
			rock = Color3.fromRGB(96, 104, 122),
		},
	},
}

-- Ground something else owns: the Flats battleground's courtyard (CoverService.Footprint).
BiomeService.KeepClear = {
	{ minX = -624, maxX = -521, minZ = 36, maxZ = 140 },
}

local function keptClear(x: number, z: number): boolean
	for _, r in ipairs(BiomeService.KeepClear) do
		if x >= r.minX and x <= r.maxX and z >= r.minZ and z <= r.maxZ then
			return true
		end
	end
	return false
end

BiomeService.Zones = {
	Flats = { minX = -753, maxX = -381, minZ = -87, maxZ = 321, cx = -573, cz = 88, y = 6 },
	Reach = { minX = -56,  maxX = 436,  minZ = 44,  maxZ = 560, cx = 244,  cz = 344, y = 10 },
}

local function folder(): Folder
	local f = workspace:FindFirstChild(BiomeService.FOLDER)
	if not f then
		f = Instance.new("Folder")
		f.Name = BiomeService.FOLDER
		f.Parent = workspace
	end
	return f :: Folder
end

local function block(parent: Instance, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?)
	local p = Instance.new("Part")
	p.Name = "Prop"
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	-- Dressing is scenery: it must never block a shot or catch a player on a corner.
	p.CanCollide = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local builders = {}

function builders.Mushroom(parent, base, pal, rng)
	local h = rng:NextNumber(1.4, 3.2)
	block(parent, Vector3.new(0.5, h, 0.5), base * CFrame.new(0, h / 2, 0), pal.stalk)
	local r = rng:NextNumber(1.5, 2.6)
	block(parent, Vector3.new(r, r * 0.45, r), base * CFrame.new(0, h + r * 0.2, 0), pal.cap)
end

function builders.DeadTree(parent, base, pal, rng)
	local h = rng:NextNumber(6, 11)
	block(parent, Vector3.new(0.8, h, 0.8), base * CFrame.new(0, h / 2, 0), pal.wood)
	for _ = 1, rng:NextInteger(2, 3) do
		local len = rng:NextNumber(2, 3.6)
		block(parent, Vector3.new(len, 0.42, 0.42),
			base * CFrame.new(0, rng:NextNumber(h * 0.55, h * 0.92), 0)
				* CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), math.rad(rng:NextNumber(15, 42)))
				* CFrame.new(len / 2, 0, 0), pal.wood)
	end
end

function builders.Boulder(parent, base, pal, rng)
	for i = 1, rng:NextInteger(2, 3) do
		local s = rng:NextNumber(1.6, 3.4)
		block(parent, Vector3.new(s, s * 0.8, s),
			base * CFrame.new(rng:NextNumber(-1.2, 1.2), s * 0.35, rng:NextNumber(-1.2, 1.2))
				* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), pal.rock)
	end
end

function builders.Spire(parent, base, pal, rng)
	local h = rng:NextNumber(4, 9)
	block(parent, Vector3.new(1.1, h, 1.1),
		base * CFrame.new(0, h / 2, 0) * CFrame.Angles(math.rad(rng:NextNumber(-8, 8)), rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-8, 8))),
		pal.rock)
	block(parent, Vector3.new(0.7, h * 0.5, 0.7),
		base * CFrame.new(rng:NextNumber(-0.8, 0.8), h * 0.32, rng:NextNumber(-0.8, 0.8)), pal.cap, Enum.Material.Neon)
end

function builders.Brazier(parent, base, pal, rng)
	block(parent, Vector3.new(1.3, 1.8, 1.3), base * CFrame.new(0, 0.9, 0), pal.wood)
	local fire = block(parent, Vector3.new(0.9, 0.9, 0.9), base * CFrame.new(0, 2.1, 0), Color3.fromRGB(244, 158, 74), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(244, 158, 74)
	light.Brightness = 1.5
	light.Range = 14
	light.Parent = fire
end

local function groundNear(x, z, fromY)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { workspace:FindFirstChild(BiomeService.FOLDER) }
	for _ = 1, 10 do
		local r = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -90, 0), params)
		if not r then return nil end
		if r.Instance.CanCollide then return r.Position.Y end
		local c = table.clone(params.FilterDescendantsInstances)
		table.insert(c, r.Instance)
		params.FilterDescendantsInstances = c
	end
	return nil
end

function BiomeService.Build()
	if WorldBake.Skip("BiomeDressing", "Biome") then
		return
	end
	local f = folder()
	f:ClearAllChildren()

	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Exclude
	overlap.FilterDescendantsInstances = { f }

	local placed = 0
	for zoneId, biome in pairs(BiomeService.Biomes) do
		local zn = BiomeService.Zones[zoneId]
		local group = Instance.new("Folder")
		group.Name = zoneId
		group.Parent = f
		local rng = Random.new(#zoneId * 7919)
		local tries = 0
		local made = 0
		while made < biome.count and tries < biome.count * 60 do
			tries += 1
			local x = zn.cx + rng:NextNumber(-170, 170)
			local z = zn.cz + rng:NextNumber(-170, 170)
			if x >= zn.minX and x <= zn.maxX and z >= zn.minZ and z <= zn.maxZ and not keptClear(x, z) then
				local y = groundNear(x, z, zn.y + 40)
				if y and y > -10 then
					local hits = workspace:GetPartBoundsInBox(CFrame.new(x, y + 4, z), Vector3.new(6, 7, 6), overlap)
					local blocked = false
					for _, p in ipairs(hits) do
						if p.CanCollide then blocked = true break end
					end
					if not blocked then
						local kind = biome.props[rng:NextInteger(1, #biome.props)]
						local model = Instance.new("Model")
						model.Name = kind
						model.Parent = group
						builders[kind](model, CFrame.new(x, y, z), biome.palette, rng)
						made += 1
						placed += 1
					end
				end
			end
		end
	end
	print(("[Biome] %d dressing props placed (additive; delete workspace.%s to undo)"):format(placed, BiomeService.FOLDER))
	return placed
end

BiomeService.Build()

return BiomeService
