--!strict
-- Somewhere to fight over, in Map 2.
--
-- Measured first: the whole battle corridor -- x -640 to -520, z 40 to 140 -- is flat at y 1
-- to 2 with nothing standing above four studs anywhere in it. Two lines of NPCs shooting
-- across a car park, which is why the cover system had nothing to find and why every fight
-- there reads the same.
--
-- This is NOT a scattering of blocks. Four deliberate spaces, each of which asks a question:
--
--   THE RUIN (centre)      breaks the long sightline. Its doorway is the short route, and
--                          the short route is the exposed one.
--   THE PENS (south lane)   container stacks: a covered flank that costs you distance.
--   THE WALLS (north lane)  staggered low walls: the other flank, lower, faster, and only
--                          cover if you keep moving between them.
--   THE PLATFORM (south)    the one piece of high ground, with a ramp anyone can take. A
--                          marksman that owns it dominates the open middle -- which is what
--                          makes taking it off them worth doing.
--
-- The middle stays OPEN on purpose. Cover everywhere is the same as cover nowhere: the
-- decision only exists if crossing the gap is genuinely dangerous.
--
-- Every piece is tagged "Cover", which is what NPCService's cover search prefers, and every
-- piece is something a player can use too -- none of it is AI-only furniture.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local NPCConfig = require(ReplicatedStorage.NPCConfig)
local WorldBake = require(ServerScriptService.WorldBake)

local CoverService = {}

CoverService.FOLDER = "Map2Cover"
CoverService.TAG = "Cover"

-- Low-poly, and borrowed from what the world already uses so this reads as part of the map
-- rather than a grey blockout dropped on top of it.
local STONE = Color3.fromRGB(129, 128, 122)
local STONE_DARK = Color3.fromRGB(96, 95, 92)
local RUST = Color3.fromRGB(139, 88, 62)
local RUST_DARK = Color3.fromRGB(104, 66, 47)
local WOOD = Color3.fromRGB(104, 72, 46)
local SANDBAG = Color3.fromRGB(150, 138, 106)

-- Nothing may be built within this of an NPC post, or enemies would spawn inside the
-- furniture. The spawner would shuffle them clear, but a bandit permanently standing in a
-- crate is exactly the kind of thing nobody notices until a player films it.
local SPAWN_CLEARANCE = 8

local function spawnPoints(): { Vector3 }
	local points = {}
	for _, spec in ipairs(NPCConfig.Spawns) do
		table.insert(points, spec.position)
	end
	-- The boss posts too; BossService owns those numbers, so they are read rather than copied.
	local ok, BossService = pcall(require, ServerScriptService.BossService)
	if ok and BossService and BossService.Posts then
		for _, post in ipairs(BossService.Posts) do
			table.insert(points, post.position)
		end
	end
	return points
end

local function folder(): Folder
	local existing = workspace:FindFirstChild(CoverService.FOLDER)
	if existing then
		return existing :: Folder
	end
	local f = Instance.new("Folder")
	f.Name = CoverService.FOLDER
	f.Parent = workspace
	return f
end

local blocked: { Vector3 } = {}
local skipped = 0

local function clearOfSpawns(position: Vector3, size: Vector3): boolean
	for _, point in ipairs(blocked) do
		local flat = Vector3.new(position.X - point.X, 0, position.Z - point.Z).Magnitude
		if flat < SPAWN_CLEARANCE + math.max(size.X, size.Z) / 2 then
			return false
		end
	end
	return true
end

--- One anchored piece of cover. `rotation` is degrees about Y, because every wall in here is
--- placed by where it faces rather than by a raw CFrame.
local function block(parent: Folder, name: string, size: Vector3, position: Vector3,
	colour: Color3, rotation: number?, material: Enum.Material?)
	if not clearOfSpawns(position, size) then
		skipped += 1
		return nil
	end
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(rotation or 0), 0)
	p.Anchored = true
	p.Color = colour
	p.Material = material or Enum.Material.Slate
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	-- What the AI's cover search prefers. A player does not need the tag: geometry is geometry.
	CollectionService:AddTag(p, CoverService.TAG)
	return p
end

-- The floor sits at y = 2 across the corridor (measured), so a piece of height h is centred
-- at 2 + h/2.
local FLOOR = 2
local function standing(x: number, z: number, height: number): Vector3
	return Vector3.new(x, FLOOR + height / 2, z)
end

-- ------------------------------------------------------------------ the ruin --
--
-- Centre of the corridor, across the line of fire. Two wall sections with a doorway between
-- them and a collapsed third, so there are three ways past it: through the door (fast,
-- exposed), round the short end (medium), or round the long end into a flank lane.
local function buildRuin(f: Folder)
	local z = 88
	block(f, "RuinWallNorth", Vector3.new(2, 7, 14), standing(-580, z + 11, 7), STONE)
	block(f, "RuinWallSouth", Vector3.new(2, 7, 14), standing(-580, z - 11, 7), STONE)
	-- The doorway lintel: it reads as a building rather than two loose walls, and it stops the
	-- gap being a clean firing slot from distance.
	block(f, "RuinLintel", Vector3.new(2, 2, 8), standing(-580, z, 12) + Vector3.new(0, 1, 0), STONE_DARK)
	-- The collapsed end: waist-high rubble you can shoot over but not walk through quickly.
	block(f, "RuinRubbleA", Vector3.new(2, 3, 6), standing(-580, z + 21, 3), STONE_DARK, 6)
	block(f, "RuinRubbleB", Vector3.new(3, 2, 4), standing(-578, z + 25, 2), STONE_DARK, -12)
	block(f, "RuinRubbleC", Vector3.new(3, 2, 5), standing(-582, z - 22, 2), STONE_DARK, 9)
	-- A buttress on each face gives something to stand behind while shooting down the corridor,
	-- rather than only across it.
	block(f, "RuinButtressEast", Vector3.new(4, 5, 2), standing(-577, z + 6, 5), STONE)
	block(f, "RuinButtressWest", Vector3.new(4, 5, 2), standing(-583, z - 6, 5), STONE)
end

-- ------------------------------------------------------------------ the pens --
--
-- South flank (low z). Container stacks: tall, solid, and arranged as a staggered corridor,
-- so moving along it is safe but slow and you arrive on the enemy's flank rather than in
-- front of them.
local function buildPens(f: Folder)
	local z = 55
	block(f, "PenCrateA", Vector3.new(10, 6, 6), standing(-598, z, 6), RUST, 4, Enum.Material.Metal)
	block(f, "PenCrateB", Vector3.new(10, 6, 6), standing(-586, z + 7, 6), RUST_DARK, -6, Enum.Material.Metal)
	block(f, "PenCrateC", Vector3.new(10, 6, 6), standing(-572, z, 6), RUST, 3, Enum.Material.Metal)
	block(f, "PenCrateD", Vector3.new(8, 6, 6), standing(-560, z + 6, 6), RUST_DARK, -4, Enum.Material.Metal)
	-- Stacked one high in two places, so the silhouette is not a flat row and there is a spot
	-- to climb for a look over.
	block(f, "PenStackA", Vector3.new(8, 5, 5), standing(-586, z + 7, 5) + Vector3.new(0, 6, 0), RUST, -6, Enum.Material.Metal)
	block(f, "PenRampA", Vector3.new(6, 1, 8), standing(-592, z + 7, 1) + Vector3.new(0, 1.6, 0), WOOD, 0, Enum.Material.WoodPlanks)
	block(f, "PenBarrelA", Vector3.new(3, 4, 3), standing(-578, z - 6, 4), RUST_DARK, 0, Enum.Material.Metal)
	block(f, "PenBarrelB", Vector3.new(3, 4, 3), standing(-575, z - 8, 4), RUST, 0, Enum.Material.Metal)
end

-- ----------------------------------------------------------------- the walls --
--
-- North flank (high z). Staggered low walls: they only work while you keep moving from one
-- to the next, which makes this the fast flank and the pens the safe one.
local function buildWalls(f: Folder)
	local z = 122
	for index, x in ipairs({ -600, -588, -576, -564 }) do
		local offset = (index % 2 == 0) and 6 or -6
		block(f, "FlankWall" .. index, Vector3.new(11, 4, 1.6), standing(x, z + offset, 4), STONE, 90 + offset)
	end
	block(f, "FlankPostA", Vector3.new(2, 5, 2), standing(-594, z, 5), WOOD, 0, Enum.Material.WoodPlanks)
	block(f, "FlankPostB", Vector3.new(2, 5, 2), standing(-570, z, 5), WOOD, 0, Enum.Material.WoodPlanks)
end

-- ------------------------------------------------------------- the platform --
--
-- The only high ground, on the south side, with a ramp anyone can walk up. Deliberately
-- modest: seven studs is enough to see over the ruin's rubble and shoot into the open middle,
-- and low enough that it can be taken off whoever holds it.
local function buildPlatform(f: Folder)
	local x, z = -566, 62
	block(f, "PlatformDeck", Vector3.new(16, 1.5, 12), Vector3.new(x, FLOOR + 7, z), STONE)
	block(f, "PlatformLegA", Vector3.new(2, 7, 2), standing(x - 6, z - 4, 7), STONE_DARK)
	block(f, "PlatformLegB", Vector3.new(2, 7, 2), standing(x + 6, z - 4, 7), STONE_DARK)
	block(f, "PlatformLegC", Vector3.new(2, 7, 2), standing(x - 6, z + 4, 7), STONE_DARK)
	block(f, "PlatformLegD", Vector3.new(2, 7, 2), standing(x + 6, z + 4, 7), STONE_DARK)
	-- A parapet, so the deck is cover and not just a stage to be shot on.
	block(f, "PlatformParapet", Vector3.new(16, 2.5, 1), Vector3.new(x, FLOOR + 9, z - 5.5), STONE)
	-- The ramp faces AWAY from the hostile line: taking the high ground means exposing your
	-- back to the open middle on the way up.
	local ramp = block(f, "PlatformRamp", Vector3.new(6, 1, 15), Vector3.new(x + 11, FLOOR + 3.6, z), WOOD, 0, Enum.Material.WoodPlanks)
	if ramp then
		ramp.CFrame = CFrame.new(ramp.Position) * CFrame.Angles(math.rad(-27), math.rad(90), 0)
	end
end

-- ------------------------------------------------------------ staging lines --
--
-- Sandbags in front of each faction's posts. These are what an NPC under fire reaches for
-- first, and they give each side an identity: something to defend rather than open ground to
-- stand on.
local function buildStaging(f: Folder)
	for index, spec in ipairs({
		{ x = -606, z = 76 }, { x = -606, z = 100 },     -- hostile side
		{ x = -558, z = 74 }, { x = -558, z = 102 },     -- guard side
	}) do
		block(f, "Sandbags" .. index, Vector3.new(9, 2.6, 2), standing(spec.x, spec.z, 2.6), SANDBAG, 90, Enum.Material.Sand)
		block(f, "SandbagsEnd" .. index, Vector3.new(4, 2.2, 2), standing(spec.x + 2, spec.z + (index % 2 == 0 and 5 or -5), 2.2), SANDBAG, 55, Enum.Material.Sand)
	end
end

function CoverService.Build()
	local f = folder()
	blocked = spawnPoints()
	skipped = 0

	buildRuin(f)
	buildPens(f)
	buildWalls(f)
	buildPlatform(f)
	buildStaging(f)

	local count = #f:GetChildren()
	print(("[Cover] Map 2: %d pieces in four spaces%s"):format(count,
		skipped > 0 and (", %d skipped as too close to a spawn post"):format(skipped) or ""))
	return count
end

if not WorldBake.Skip(CoverService.FOLDER, "Cover") then
	local existing = workspace:FindFirstChild(CoverService.FOLDER)
	if existing then
		existing:Destroy()
	end
	CoverService.Build()
end

return CoverService
