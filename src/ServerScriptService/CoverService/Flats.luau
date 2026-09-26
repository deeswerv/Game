--!strict
-- THE FLATS BATTLEGROUND: the stone courtyard between the four pillars of Map 2, where the
-- raiders and the town guard fight it out.
--
-- It matches the map around it: low-poly, the same grey stone as the pillars, timber, canvas
-- and moss, set in a forest clearing. Five places, each one there for a reason:
--
--   RAIDER CAMP (west)    a palisade of sharpened logs with a gate at the back (where the
--                         Warlord waits), two tents, a campfire and supply piles, and log
--                         barricades at its front edge. The bandits live here.
--   GUARD POST (east)     a crenellated stone wall with a gap in the middle, a wooden
--                         watchtower you can climb by its ramp, and a pavilion. The guard
--                         holds it.
--   THE GATEHOUSE (centre) a ruined stone gateway across the line of fire: the doorway is the
--                         short, exposed way through; round the broken walls is the long way.
--   THE WALLS (north)     overgrown low walls and a fallen tree: the fast flank.
--   THE TERRACE (south)   a raised stone terrace with a parapet: the high ground over the
--                         open middle, reached by steps from the far side.
--
-- The middle stays open on purpose: crossing it has to be a decision.
--
-- Local coordinates: +X east (toward the guard), +Z north, y = 0 the top of the courtyard
-- slab (1.5 in the world). The pillars stand at (+-46.5, +-46.5). Built with the same Kit as
-- the duel maps and Downtown.

local ServerScriptService = game:GetService("ServerScriptService")

local Kit = require(ServerScriptService.ArenaService.Kit)

local Flats = {}

Flats.Name = "THE FLATS"
Flats.HalfWidth = 50
Flats.HalfLength = 50
Flats.Mood = "day"

-- Where each side's fighters stand, in local coordinates. NPCConfig.Spawns carries the same
-- points in world space; tools/uitest/flats.luau checks the two agree and that every post
-- has room around it.
Flats.Posts = {
	Hostile = {
		{ "Brute", Vector3.new(-22, 0, 0) },
		{ "Grunt", Vector3.new(-26, 0, -20) },
		{ "Grunt", Vector3.new(-26, 0, 20) },
		{ "Marksman", Vector3.new(-38, 0, -16) },
		{ "Soldier", Vector3.new(-32, 0, -21) },
		{ "Elite", Vector3.new(-38, 0, 17) },
	},
	Guard = {
		{ "Guard", Vector3.new(28, 0, -11) },
		{ "Guard", Vector3.new(28, 0, 11) },
		{ "Guard", Vector3.new(33, 0, 0) },
	},
}

-- Cameras for tools/mapview (local coordinates).
Flats.Preview = {
	{ pos = { 0, 95, -95 }, look = { 0, 0, 0 }, fov = 60 },
	{ pos = { -8, 5, 0 }, look = { -45, 6, 0 }, fov = 70 },
	{ pos = { 12, 5, 4 }, look = { 40, 6, -8 }, fov = 70 },
	{ pos = { -30, 6, -8 }, look = { 10, 5, 4 }, fov = 70 },
	{ pos = { 20, 12, 30 }, look = { -6, 3, 0 }, fov = 70 },
	{ pos = { 0, 7, -18 }, look = { 0, 4, -38 }, fov = 70 },
}

local M = Enum.Material

-- The pillars' own grey, and stones either side of it.
local STONE = Color3.fromRGB(140, 138, 136)
local STONE_DARK = Color3.fromRGB(108, 106, 104)
local STONE_LIGHT = Color3.fromRGB(172, 170, 166)
local MOSS = Color3.fromRGB(96, 140, 72)
local LEAF = Color3.fromRGB(78, 148, 64)
local LEAF_LIGHT = Color3.fromRGB(112, 178, 84)
local WOOD = Color3.fromRGB(128, 90, 58)
local WOOD_DARK = Color3.fromRGB(92, 64, 42)
local WOOD_LIGHT = Color3.fromRGB(160, 118, 78)
local DIRT = Color3.fromRGB(146, 110, 76)
local CANVAS = Color3.fromRGB(196, 170, 122)
local CANVAS_DARK = Color3.fromRGB(150, 126, 88)
local RAIDER = Color3.fromRGB(150, 50, 44)
local GUARD = Color3.fromRGB(62, 118, 82)
local CREAM = Color3.fromRGB(240, 230, 204)
local HAY = Color3.fromRGB(216, 184, 104)
local IRON = Color3.fromRGB(62, 60, 58)
local FIRE = Color3.fromRGB(255, 150, 50)
local FIRE_CORE = Color3.fromRGB(255, 222, 120)

local function vertical(at: Vector3): CFrame
	return CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
end

local function painted(b: Kit.Builder, text: string, at: CFrame, w: number, h: number, colour: Color3)
	b:sign(text, at, w, h, colour, { lit = true, glow = false, font = Enum.Font.GothamBlack, textColour = colour,
		brightness = 1 })
end

-- ------------------------------------------------------------------ props --

--- A sharpened log standing upright: the palisade's unit.
local function stake(b: Kit.Builder, at: Vector3, height: number, colour: Color3)
	b:part("Stake", Vector3.new(height, 1.3, 1.3), vertical(at + Vector3.new(0, height / 2, 0)), colour, M.Wood,
		{ shape = "Cylinder" })
	b:decor("StakeTip", Vector3.new(0.92, 0.92, 0.92), CFrame.new(at + Vector3.new(0, height + 0.1, 0))
		* CFrame.Angles(math.rad(45), 0, math.rad(45)), colour, M.Wood)
end

--- A run of stakes from `a` to `b`, heights varying so the top edge is ragged.
local function palisade(b: Kit.Builder, from: Vector3, to: Vector3, seed: number)
	local rng = Random.new(seed)
	local length = (to - from).Magnitude
	local count = math.max(2, math.floor(length / 1.35))
	for i = 0, count do
		local p = from:Lerp(to, i / count)
		stake(b, p, 7 + rng:NextNumber(0, 1.8), i % 3 == 0 and WOOD_DARK or WOOD)
	end
	-- Two binding rails along the inside.
	local cf, len = Kit.Span(from + Vector3.new(0, 2, 0), to + Vector3.new(0, 2, 0))
	b:decor("Rail", Vector3.new(0.5, 0.5, len), cf, WOOD_DARK, M.Wood)
	cf, len = Kit.Span(from + Vector3.new(0, 5.2, 0), to + Vector3.new(0, 5.2, 0))
	b:decor("Rail", Vector3.new(0.5, 0.5, len), cf, WOOD_DARK, M.Wood)
end

local function crate(b: Kit.Builder, at: CFrame, size: number)
	b:part("Crate", Vector3.new(size, size, size), at * CFrame.new(0, size / 2, 0), WOOD_LIGHT, M.WoodPlanks)
	for _, y in ipairs({ -size / 2 + 0.2, size / 2 - 0.2 }) do
		b:decor("CrateBand", Vector3.new(size + 0.08, 0.3, size + 0.08), at * CFrame.new(0, size / 2 + y, 0), WOOD_DARK,
			M.Wood)
	end
end

local function barrel(b: Kit.Builder, at: Vector3, colour: Color3?)
	b:part("Barrel", Vector3.new(3, 2.2, 2.2), vertical(at + Vector3.new(0, 1.5, 0)), colour or WOOD, M.Wood,
		{ shape = "Cylinder" })
	for _, y in ipairs({ 0.6, 2.4 }) do
		b:decor("Hoop", Vector3.new(0.25, 2.28, 2.28), vertical(at + Vector3.new(0, y, 0)), IRON, M.Metal,
			{ shape = "Cylinder" })
	end
end

local function hayBale(b: Kit.Builder, at: CFrame)
	b:part("HayBale", Vector3.new(4, 2.4, 2.4), at * CFrame.new(0, 1.2, 0), HAY, M.Grass)
	for _, x in ipairs({ -1.1, 1.1 }) do
		b:decor("Twine", Vector3.new(0.2, 2.46, 2.46), at * CFrame.new(x, 1.2, 0), CANVAS_DARK)
	end
end

--- A faceted bush, `size` across.
local function bush(b: Kit.Builder, at: Vector3, size: number, seed: number)
	local rng = Random.new(seed)
	for i = 1, 3 do
		local s = size * (i == 1 and 1 or 0.7) * rng:NextNumber(0.85, 1.1)
		local offset = i == 1 and Vector3.zero or Vector3.new(rng:NextNumber(-1, 1), 0, rng:NextNumber(-1, 1)) * size * 0.4
		b:decor("Bush", Vector3.new(s, s * 0.8, s), CFrame.new(at + offset + Vector3.new(0, s * 0.35, 0))
			* CFrame.Angles(0, rng:NextNumber(0, math.pi), 0), i % 2 == 0 and LEAF_LIGHT or LEAF, M.SmoothPlastic)
	end
end

--- Grass tufts: three thin blades crossed, for the edges of things.
local function tuft(b: Kit.Builder, at: Vector3, seed: number)
	local rng = Random.new(seed)
	for i = 0, 2 do
		b:decor("Grass", Vector3.new(0.2, 1 + rng:NextNumber(0, 0.6), 0.9), CFrame.new(at + Vector3.new(0, 0.5, 0))
			* CFrame.Angles(0, math.rad(i * 60 + rng:NextNumber(0, 20)), math.rad(rng:NextNumber(-12, 12))),
			i == 1 and LEAF_LIGHT or MOSS)
	end
end

--- A stone bowl with a fire in it and a light.
local function brazier(b: Kit.Builder, at: Vector3)
	b:part("BrazierStand", Vector3.new(3, 1, 1), vertical(at + Vector3.new(0, 1.5, 0)), STONE_DARK, nil,
		{ shape = "Cylinder" })
	b:decor("BrazierBowl", Vector3.new(0.9, 2.6, 2.6), vertical(at + Vector3.new(0, 3.3, 0)), IRON, M.Metal,
		{ shape = "Cylinder" })
	b:decor("Coals", Vector3.new(0.3, 2.2, 2.2), vertical(at + Vector3.new(0, 3.7, 0)), Color3.fromRGB(70, 40, 30), nil,
		{ shape = "Cylinder" })
	b:decor("Flame", Vector3.new(0.9, 1.1, 0.9), CFrame.new(at + Vector3.new(0, 4.2, 0)) * CFrame.Angles(0.4, 0.4, 0.3),
		FIRE)
	b:decor("FlameCore", Vector3.new(0.5, 0.7, 0.5), CFrame.new(at + Vector3.new(0, 4.4, 0)) * CFrame.Angles(0.2, 0.9, 0.1),
		FIRE_CORE)
	b:light("Point", at + Vector3.new(0, 5, 0), Color3.fromRGB(255, 170, 90), 1.4, 20)
end

--- A flag on a pole: `colour` cloth with a cream band.
local function flag(b: Kit.Builder, at: Vector3, colour: Color3, height: number)
	b:part("FlagPole", Vector3.new(height, 0.4, 0.4), vertical(at + Vector3.new(0, height / 2, 0)), WOOD_DARK, M.Wood,
		{ shape = "Cylinder" })
	b:decor("Flag", Vector3.new(0.1, 2.6, 4), at + Vector3.new(0, height - 1.6, 2.1), colour, M.Fabric)
	b:decor("FlagBand", Vector3.new(0.16, 0.5, 4), at + Vector3.new(0, height - 1.6, 2.1), CREAM, M.Fabric)
end

--- A ridge tent, ridge along X: canvas roof, triangular ends, a dark doorway on the +X end.
local function tent(b: Kit.Builder, length: number, width: number, height: number, cloth: Color3)
	for _, s in ipairs({ -1, 1 }) do
		local cf, len = Kit.Span(Vector3.new(0, height, 0), Vector3.new(0, 0.2, s * width / 2))
		b:part("TentRoof", Vector3.new(length, 0.3, len + 0.4), cf, cloth, M.Fabric)
		-- Guy ropes out to pegs.
		for _, x in ipairs({ -length / 2 + 0.6, length / 2 - 0.6 }) do
			local rope, rlen = Kit.Span(Vector3.new(x, 0.8, s * width / 2), Vector3.new(x, 0, s * (width / 2 + 1.8)))
			b:decor("GuyRope", Vector3.new(0.1, 0.1, rlen), rope, CANVAS_DARK)
			b:decor("Peg", Vector3.new(0.3, 0.6, 0.3), Vector3.new(x, 0.3, s * (width / 2 + 1.8)), WOOD_DARK)
		end
	end
	-- The two ends: each two wedges back to back.
	for _, x in ipairs({ -length / 2, length / 2 }) do
		for _, s in ipairs({ -1, 1 }) do
			b:decor("TentEnd", Vector3.new(0.25, height, width / 2), CFrame.new(x, height / 2, s * width / 4)
				* CFrame.Angles(0, s > 0 and math.pi or 0, 0), x > 0 and CANVAS_DARK or cloth, M.Fabric,
				{ shape = "Wedge" })
		end
	end
	b:decor("Doorway", Vector3.new(0.3, height * 0.62, width * 0.28), Vector3.new(length / 2 + 0.05, height * 0.31, 0),
		Color3.fromRGB(40, 32, 26))
	b:decor("RidgePole", Vector3.new(length + 1, 0.3, 0.3), Vector3.new(0, height + 0.05, 0), WOOD_DARK, M.Wood)
end

--- A low stone wall along X, `length` long, with a ragged top of cap stones.
local function stoneWall(b: Kit.Builder, length: number, height: number, seed: number, crenellated: boolean?)
	local rng = Random.new(seed)
	b:part("Wall", Vector3.new(length, height, 2), Vector3.new(0, height / 2, 0), STONE)
	b:decor("WallFoot", Vector3.new(length + 0.4, 0.6, 2.4), Vector3.new(0, 0.3, 0), STONE_DARK)
	if crenellated then
		local merlons = math.floor(length / 3)
		for i = 0, merlons - 1 do
			local x = -length / 2 + 1 + i * (length - 2) / math.max(merlons - 1, 1)
			b:part("Merlon", Vector3.new(1.6, 1.2, 2.2), Vector3.new(x, height + 0.6, 0), STONE_LIGHT)
		end
		b:decor("WallCap", Vector3.new(length + 0.2, 0.3, 2.3), Vector3.new(0, height + 0.15, 0), STONE_LIGHT)
	else
		for x = -length / 2 + 1, length / 2 - 1, 2.2 do
			local h = rng:NextNumber(0.4, 0.9)
			b:decor("CapStone", Vector3.new(2, h, 2.2), CFrame.new(x, height + h / 2 - 0.1, 0)
				* CFrame.Angles(0, 0, math.rad(rng:NextNumber(-5, 5))), rng:NextNumber() < 0.3 and MOSS or STONE_LIGHT)
		end
	end
	-- Moss creeping up the foot, grass at the base.
	for x = -length / 2 + 1.5, length / 2 - 1.5, 4.5 do
		local side = rng:NextNumber() < 0.5 and -1 or 1
		b:decor("Moss", Vector3.new(rng:NextNumber(1.2, 2.4), rng:NextNumber(0.6, 1.4), 0.2),
			Vector3.new(x + rng:NextNumber(-1, 1), 0.7, side * 1.05), MOSS)
		tuft(b, Vector3.new(x + rng:NextNumber(-1, 1), 0, side * 1.6), seed + math.floor(x))
	end
end

--- A log barricade: three logs stacked along Z between two pairs of stakes.
local function logBarricade(b: Kit.Builder, length: number)
	for i, y in ipairs({ 0.6, 1.6, 2.6 }) do
		b:part("BarricadeLog", Vector3.new(length - (i - 1) * 0.6, 1.1, 1.1), CFrame.new(0, y, 0)
			* CFrame.Angles(0, math.rad(90), 0), i % 2 == 0 and WOOD_DARK or WOOD, M.Wood, { shape = "Cylinder" })
	end
	for _, z in ipairs({ -length / 2 + 0.8, length / 2 - 0.8 }) do
		for _, x in ipairs({ -0.9, 0.9 }) do
			b:part("BarricadeStake", Vector3.new(0.5, 3.8, 0.5), CFrame.new(x, 1.7, z) * CFrame.Angles(0, 0, math.rad(x * 10)),
				WOOD_DARK, M.Wood)
		end
	end
end

-- ------------------------------------------------------------ raider camp --

local function raiderCamp(b: Kit.Builder)
	-- The ground is trodden dirt here, not courtyard stone.
	b:decor("CampDirt", Vector3.new(30, 0.06, 90), Vector3.new(-31, 0.03, 0), DIRT, M.Ground)
	-- The palisade: the back wall with its gate, and short returns along the sides.
	palisade(b, Vector3.new(-45, 0, -44), Vector3.new(-45, 0, -7.5), 11)
	palisade(b, Vector3.new(-45, 0, 7.5), Vector3.new(-45, 0, 44), 12)
	palisade(b, Vector3.new(-43.6, 0, -44), Vector3.new(-30, 0, -44), 13)
	palisade(b, Vector3.new(-43.6, 0, 44), Vector3.new(-30, 0, 44), 14)
	-- The gate: two tall posts, a crossbeam with the camp's name, skull-red banners.
	for _, z in ipairs({ -6.5, 6.5 }) do
		b:part("GatePost", Vector3.new(12, 1.9, 1.9), vertical(Vector3.new(-45, 6, z)), WOOD_DARK, M.Wood, { shape = "Cylinder" })
		b:decor("GateBanner", Vector3.new(0.12, 5, 2.4), Vector3.new(-44, 6.5, z * 0.72), RAIDER, M.Fabric)
		b:decor("GateBannerBand", Vector3.new(0.18, 0.5, 2.4), Vector3.new(-44, 5, z * 0.72), CREAM, M.Fabric)
	end
	b:decor("GateBeam", Vector3.new(1.2, 1.2, 15), Vector3.new(-45, 11.2, 0), WOOD, M.Wood)
	b:decor("GateSign", Vector3.new(0.3, 2, 8), Vector3.new(-44.4, 9.6, 0), WOOD_LIGHT, M.WoodPlanks)
	painted(b, "RAIDER CAMP", Kit.Look(Vector3.new(-44.2, 9.6, 0), Vector3.new(-30, 9.6, 0)), 7.4, 1.5, RAIDER)
	brazier(b, Vector3.new(-41, 0, -9.5))
	brazier(b, Vector3.new(-41, 0, 9.5))

	-- Two tents, doorways facing the fire.
	tent(b:within(CFrame.new(-37, 0, 30)), 9, 6.4, 5, CANVAS)
	tent(b:within(CFrame.new(-37, 0, -30)), 9, 6.4, 5, CANVAS)
	b:decor("TentPatch", Vector3.new(2.2, 0.32, 1.6), CFrame.new(-38, 3, 31.6) * CFrame.Angles(math.rad(-58), 0, 0), RAIDER,
		M.Fabric)

	-- The campfire: a ring of stones, crossed logs, the fire, two logs to sit on.
	local fire = b:within(CFrame.new(-34, 0, 0))
	for i = 0, 7 do
		local a = i / 8 * math.pi * 2
		fire:part("FireStone", Vector3.new(1, 0.7, 0.9), CFrame.new(math.cos(a) * 1.9, 0.35, math.sin(a) * 1.9)
			* CFrame.Angles(0, -a, 0), i % 2 == 0 and STONE or STONE_DARK)
	end
	for i = 0, 2 do
		fire:decor("FireLog", Vector3.new(2.6, 0.5, 0.5), CFrame.new(0, 0.4, 0) * CFrame.Angles(0, math.rad(i * 60), math.rad(12)),
			WOOD_DARK, M.Wood, { shape = "Cylinder" })
	end
	fire:decor("Flame", Vector3.new(1.6, 1.6, 1.6), CFrame.new(0, 1.2, 0) * CFrame.Angles(0.6, 0.4, 0.5), FIRE)
	fire:decor("FlameCore", Vector3.new(0.9, 0.9, 0.9), CFrame.new(0, 1.7, 0) * CFrame.Angles(0.3, 0.9, 0.2), FIRE_CORE)
	fire:light("Point", Vector3.new(0, 2.5, 0), Color3.fromRGB(255, 170, 90), 1.6, 24)
	for _, z in ipairs({ -4.5, 4.5 }) do
		fire:part("SeatLog", Vector3.new(6, 1.1, 1.1), CFrame.new(0, 0.55, z), WOOD, M.Wood, { shape = "Cylinder" })
	end

	-- Supply piles in the corners: crates, barrels, sacks.
	for _, s in ipairs({ -1, 1 }) do
		local pile = b:within(CFrame.new(-27, 0, s * 38))
		crate(pile, CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(8), 0), 3.2)
		crate(pile, CFrame.new(3.4, 0, 0.4) * CFrame.Angles(0, math.rad(-6), 0), 2.8)
		crate(pile, CFrame.new(1.6, 3.2, 0.2) * CFrame.Angles(0, math.rad(20), 0), 2.4)
		barrel(pile, Vector3.new(-2.6, 0, -2 * s))
		barrel(pile, Vector3.new(-0.4, 0, -2.6 * s), RAIDER)
	end

	-- Log barricades along the camp's front edge.
	for _, z in ipairs({ -11, 11 }) do
		logBarricade(b:within(CFrame.new(-17, 0, z)), 8)
	end
	flag(b, Vector3.new(-19, 0, -30), RAIDER, 11)
	flag(b, Vector3.new(-19, 0, 30), RAIDER, 11)
end

-- ------------------------------------------------------------- guard post --

local function guardPost(b: Kit.Builder)
	-- Laid stone underfoot.
	b:decor("PostPaving", Vector3.new(26, 0.06, 90), Vector3.new(33, 0.03, 0), STONE_LIGHT, M.SmoothPlastic)
	for z = -42, 42, 6 do
		-- Mortar lines stand a little above both the paving (0.06) and the flagstones (0.08)
		-- they cross; level with the flagstones they flickered where the two overlap.
		b:decor("PavingJoint", Vector3.new(26, 0.08, 0.2), Vector3.new(33, 0.06, z), STONE)
	end
	-- The front wall, crenellated, with the gap in the middle and a brazier each side of it.
	stoneWall(b:within(CFrame.new(20, 0, -14) * CFrame.Angles(0, math.rad(90), 0)), 16, 3.4, 21, true)
	stoneWall(b:within(CFrame.new(20, 0, 14) * CFrame.Angles(0, math.rad(90), 0)), 16, 3.4, 22, true)
	brazier(b, Vector3.new(22.5, 0, -7.5))
	brazier(b, Vector3.new(22.5, 0, 7.5))
	b:decor("PostSign", Vector3.new(0.3, 1.8, 7), Vector3.new(18.85, 2.2, -14), WOOD_LIGHT, M.WoodPlanks)
	painted(b, "GUARD POST", Kit.Look(Vector3.new(18.65, 2.2, -14), Vector3.new(0, 2.2, -14)), 6.4, 1.3, GUARD)

	-- The watchtower: four legs, braces, a railed platform, a peaked roof, and a ramp up.
	local tower = b:within(CFrame.new(37, 0, -31))
	local TOP = 10
	for _, x in ipairs({ -3.2, 3.2 }) do
		for _, z in ipairs({ -3.2, 3.2 }) do
			tower:part("TowerLeg", Vector3.new(1.2, TOP + 5.6, 1.2), Vector3.new(x, (TOP + 5.6) / 2, z), WOOD_DARK, M.Wood)
		end
		local brace, len = Kit.Span(Vector3.new(x, 1, -3.2), Vector3.new(x, TOP - 1, 3.2))
		tower:decor("TowerBrace", Vector3.new(0.4, 0.4, len), brace, WOOD, M.Wood)
	end
	local brace, len = Kit.Span(Vector3.new(-3.2, 1, -3.2), Vector3.new(3.2, TOP - 1, -3.2))
	tower:decor("TowerBrace", Vector3.new(0.4, 0.4, len), brace, WOOD, M.Wood)
	tower:part("TowerDeck", Vector3.new(8.4, 0.8, 8.4), Vector3.new(0, TOP - 0.4, 0), WOOD_LIGHT, M.WoodPlanks)
	for _, side in ipairs({ { -4, 0, 0.3, 8.4 }, { 4, 0, 0.3, 8.4 }, { 0, -4, 8.4, 0.3 } }) do
		tower:part("TowerRail", Vector3.new(side[3], 1.4, side[4]), Vector3.new(side[1], TOP + 0.7, side[2]), WOOD, M.WoodPlanks)
	end
	-- The +Z side is open where the ramp arrives; a half rail either side of it.
	for _, x in ipairs({ -3, 3 }) do
		tower:part("TowerRail", Vector3.new(2.4, 1.4, 0.3), Vector3.new(x, TOP + 0.7, 4), WOOD, M.WoodPlanks)
	end
	for _, s in ipairs({ -1, 1 }) do
		local roof, rlen = Kit.Span(Vector3.new(0, TOP + 7.4, 0), Vector3.new(s * 5, TOP + 5.2, 0))
		tower:decor("TowerRoof", Vector3.new(9.6, 0.35, rlen + 0.4), roof, GUARD, M.Fabric)
	end
	flag(tower, Vector3.new(0, TOP + 5.6, 0), GUARD, 4)
	-- The ramp, from the ground inside the post up to the open side of the deck.
	local ramp, rampLen = Kit.Span(Vector3.new(0, 0.25, 22), Vector3.new(0, TOP - 0.1, 4))
	tower:part("TowerRamp", Vector3.new(3.6, 0.5, rampLen + 0.6), ramp, WOOD_LIGHT, M.WoodPlanks)
	for i = 1, math.floor(rampLen / 1.5) - 1 do
		local p = Vector3.new(0, 0.25, 22):Lerp(Vector3.new(0, TOP - 0.1, 4), i / math.floor(rampLen / 1.5))
		tower:decor("RampCleat", Vector3.new(3.6, 0.2, 0.3), CFrame.new(p + ramp.UpVector * 0.3) * (ramp - ramp.Position),
			WOOD_DARK, M.Wood)
	end

	-- The pavilion: four posts, a striped canopy, a table with maps on it, a weapon rack.
	local pav = b:within(CFrame.new(37, 0, 30))
	for _, x in ipairs({ -4.5, 4.5 }) do
		for _, z in ipairs({ -4, 4 }) do
			pav:part("PavilionPost", Vector3.new(0.6, 7, 0.6), Vector3.new(x, 3.5, z), WOOD_DARK, M.Wood)
		end
	end
	for i = 0, 4 do
		pav:decor("Canopy", Vector3.new(10, 0.3, 1.8), Vector3.new(0, 7.1, -3.6 + i * 1.8), i % 2 == 0 and GUARD or CREAM,
			M.Fabric)
	end
	pav:part("Table", Vector3.new(4, 0.3, 2.4), Vector3.new(0, 2.6, 0), WOOD_LIGHT, M.WoodPlanks)
	for _, x in ipairs({ -1.7, 1.7 }) do
		pav:decor("TableLeg", Vector3.new(0.3, 2.5, 2), Vector3.new(x, 1.25, 0), WOOD_DARK, M.Wood)
	end
	pav:decor("Map", Vector3.new(2, 0.05, 1.4), CFrame.new(0.3, 2.78, 0) * CFrame.Angles(0, math.rad(12), 0), CREAM)
	pav:part("Rack", Vector3.new(0.4, 3.4, 5), Vector3.new(-4.2, 1.7, 0), WOOD, M.Wood)
	for z = -1.8, 1.8, 1.2 do
		pav:decor("RackRifle", Vector3.new(0.3, 3, 0.35), CFrame.new(-3.9, 1.8, z) * CFrame.Angles(0, 0, math.rad(-8)), IRON,
			M.Metal)
	end

	-- Stores against the back.
	crate(b:within(CFrame.new(41, 0, 8)), CFrame.new(0, 0, 0), 3)
	crate(b:within(CFrame.new(41, 0, 11.4)), CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(10), 0), 2.6)
	barrel(b, Vector3.new(41.5, 0, -8), GUARD)
	barrel(b, Vector3.new(41.5, 0, -10.6))
end

-- ------------------------------------------------------------- gatehouse --

local function gatehouse(b: Kit.Builder)
	-- The two piers of the gateway and what is left of the lintel over it.
	for _, z in ipairs({ -5, 5 }) do
		b:part("Pier", Vector3.new(3.4, 10, 3.4), Vector3.new(0, 5, z), STONE)
		b:decor("PierCap", Vector3.new(4, 0.8, 4), Vector3.new(0, 10.4, z), STONE_LIGHT)
		b:decor("PierFoot", Vector3.new(4, 1, 4), Vector3.new(0, 0.5, z), STONE_DARK)
	end
	b:part("Lintel", Vector3.new(3, 1.8, 8), Vector3.new(0, 11.7, -1.2), STONE_LIGHT)
	b:part("FallenLintel", Vector3.new(2.6, 1.6, 4.4), CFrame.new(4.4, 0.8, 7.4) * CFrame.Angles(0, math.rad(28), math.rad(8)),
		STONE_LIGHT)
	-- North wing: stepping down as it goes, broken.
	for _, seg in ipairs({ { 6.8, 10.5, 8.5 }, { 10.5, 14.5, 6.2 }, { 14.5, 18, 3.8 } }) do
		local z0, z1, h = seg[1], seg[2], seg[3]
		b:part("GateWall", Vector3.new(2, h, z1 - z0), Vector3.new(0, h / 2, (z0 + z1) / 2), STONE)
	end
	-- South wing: full height with a window through it, broken at the end.
	b:part("GateWall", Vector3.new(2, 7.5, 3.5), Vector3.new(0, 3.75, -8.5), STONE)
	b:part("GateWall", Vector3.new(2, 3, 3), Vector3.new(0, 1.5, -11.75), STONE)
	b:part("GateWall", Vector3.new(2, 1.6, 3), Vector3.new(0, 6.7, -11.75), STONE)
	b:decor("WindowSill", Vector3.new(2.4, 0.3, 3.2), Vector3.new(0, 3.1, -11.75), STONE_LIGHT)
	b:part("GateWall", Vector3.new(2, 7.5, 2.5), Vector3.new(0, 3.75, -14.5), STONE)
	b:part("GateWall", Vector3.new(2, 5, 2.4), Vector3.new(0, 2.5, -16.9), STONE)
	-- Rubble at the broken ends, some of it big enough to crouch behind.
	local rng = Random.new(31)
	for _, spot in ipairs({ Vector3.new(1.6, 0, 19.4), Vector3.new(-1.4, 0, 20.4), Vector3.new(0.4, 0, 22),
		Vector3.new(-1.6, 0, -18.8), Vector3.new(1.8, 0, -19.6), Vector3.new(-0.2, 0, -21.4) }) do
		local s = rng:NextNumber(1.2, 2.2)
		b:part("Rubble", Vector3.new(s * 1.3, s, s), CFrame.new(spot + Vector3.new(0, s / 2 - 0.1, 0))
			* CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, math.pi), rng:NextNumber(-0.3, 0.3)),
			rng:NextNumber() < 0.5 and STONE or STONE_DARK)
	end
	-- A fallen column on one side, the stump of one on the other.
	b:part("FallenColumn", Vector3.new(8, 2.4, 2.4), CFrame.new(-7.6, 1.2, 13) * CFrame.Angles(0, math.rad(20), 0), STONE_LIGHT, nil,
		{ shape = "Cylinder" })
	b:decor("ColumnRing", Vector3.new(0.4, 2.6, 2.6), CFrame.new(-7.6, 1.2, 13) * CFrame.Angles(0, math.rad(20), 0)
		* CFrame.new(2.4, 0, 0), STONE, nil, { shape = "Cylinder" })
	b:part("ColumnStump", Vector3.new(4.2, 2.8, 2.8), vertical(Vector3.new(9, 2.1, -13)), STONE_LIGHT, nil, { shape = "Cylinder" })
	b:decor("StumpBase", Vector3.new(0.8, 3.6, 3.6), vertical(Vector3.new(9, 0.4, -13)), STONE, nil, { shape = "Cylinder" })
	-- Moss on the ruin.
	for _, m in ipairs({ { Vector3.new(0, 8.6, 8.6), Vector3.new(2.1, 0.3, 3) }, { Vector3.new(0, 6.3, 12.5), Vector3.new(2.1, 0.3, 2.4) },
		{ Vector3.new(1.05, 2.2, -8.6), Vector3.new(0.2, 1.6, 2.2) }, { Vector3.new(-1.05, 1.4, 16), Vector3.new(0.2, 1.2, 1.8) },
		{ Vector3.new(0, 10.9, 5), Vector3.new(3.6, 0.2, 2) } }) do
		b:decor("Moss", m[2], m[1], MOSS)
	end
	for i, spot in ipairs({ Vector3.new(1.6, 0, 7.5), Vector3.new(-1.6, 0, -7), Vector3.new(-1.6, 0, 10), Vector3.new(1.7, 0, -15),
		Vector3.new(-2.6, 0, 4.4), Vector3.new(2.8, 0, -4.8) }) do
		tuft(b, spot, 40 + i)
	end
end

-- ----------------------------------------------------------------- flanks --

local function northWalls(b: Kit.Builder)
	for i, spec in ipairs({ { -22, 31, 10 }, { -8, 37, 9 }, { 8, 31, 10 }, { 22, 37, 9 } }) do
		stoneWall(b:within(CFrame.new(spec[1], 0, spec[2])), spec[3], 3.6, 50 + i)
		bush(b, Vector3.new(spec[1] + spec[3] / 2 + 1.2, 0, spec[2] + 1.8), 2.6, 60 + i)
	end
	-- The fallen tree: trunk, a root plate at one end, the stub of a branch.
	local tree = b:within(CFrame.new(-2, 0, 25) * CFrame.Angles(0, math.rad(-8), 0))
	tree:part("FallenTrunk", Vector3.new(15, 2.2, 2.2), CFrame.new(0, 1.1, 0), WOOD_DARK, M.Wood, { shape = "Cylinder" })
	tree:part("RootPlate", Vector3.new(1, 4.4, 4.4), vertical(Vector3.new(-7.8, 2, 0)) * CFrame.Angles(math.rad(90), 0, 0),
		Color3.fromRGB(84, 62, 44), M.Ground, { shape = "Cylinder" })
	tree:decor("Branch", Vector3.new(0.7, 3.4, 0.7), CFrame.new(3, 2.6, 0.6) * CFrame.Angles(math.rad(30), 0, math.rad(-25)),
		WOOD_DARK, M.Wood)
	bush(tree, Vector3.new(6.6, 0.4, 0.8), 2.8, 71)
	-- Bushes along the north edge soften it into the forest beyond.
	for i, x in ipairs({ -36, -14, 0, 15, 34 }) do
		bush(b, Vector3.new(x, 0, 44), 3.2, 80 + i)
	end
end

local function southTerrace(b: Kit.Builder)
	-- The terrace: a raised block of stone with a crenellated parapet facing the middle.
	local W, D, H = 16, 10, 5
	local cz = -31
	b:part("Terrace", Vector3.new(W, H, D), Vector3.new(0, H / 2, cz), STONE)
	b:decor("TerraceCap", Vector3.new(W + 0.4, 0.3, D + 0.4), Vector3.new(0, H + 0.15, cz), STONE_LIGHT)
	b:decor("TerraceFoot", Vector3.new(W + 0.6, 0.8, D + 0.6), Vector3.new(0, 0.4, cz), STONE_DARK)
	for i = 0, 5 do
		local x = -W / 2 + 1 + i * (W - 2) / 5
		-- A hair shallower than the parapet it stands on, so their faces are not one plane.
		b:part("Merlon", Vector3.new(1.8, 1.6, 1.16), Vector3.new(x, H + 1.1, cz + D / 2 - 0.6), STONE_LIGHT)
	end
	b:part("ParapetLow", Vector3.new(W, 0.8, 1.2), Vector3.new(0, H + 0.4, cz + D / 2 - 0.6), STONE)
	-- Steps up the back (south) side, away from the open middle.
	for k = 1, H do
		local z = cz - D / 2 - (H - k + 0.5) * 1.5
		b:part("Step", Vector3.new(6, k, 1.5), Vector3.new(0, k / 2, z), k % 2 == 0 and STONE or STONE_DARK)
	end
	for i, spot in ipairs({ Vector3.new(-W / 2 - 0.8, 0, cz), Vector3.new(W / 2 + 0.8, 0, cz - 2), Vector3.new(-5, 0, cz + D / 2 + 0.9) }) do
		tuft(b, spot, 90 + i)
	end
	bush(b, Vector3.new(W / 2 + 2.4, 0, cz + 3), 3, 95)

	-- Bandit-side cover on the south flank: a cart and hay.
	local cart = b:within(CFrame.new(-23, 0, -31) * CFrame.Angles(0, math.rad(12), 0))
	cart:part("CartBed", Vector3.new(6.4, 0.6, 3.8), Vector3.new(0, 2, 0), WOOD_LIGHT, M.WoodPlanks)
	for _, z in ipairs({ -1.8, 1.8 }) do
		cart:part("CartSide", Vector3.new(6.4, 1.2, 0.3), Vector3.new(0, 2.9, z), WOOD, M.WoodPlanks)
		cart:decor("Wheel", Vector3.new(0.4, 3.2, 3.2), CFrame.new(-0.8, 1.6, z * 1.18) * CFrame.Angles(0, math.rad(90), 0),
			WOOD_DARK, M.Wood, { shape = "Cylinder" })
		cart:decor("Shaft", Vector3.new(4.6, 0.3, 0.3), CFrame.new(5, 1.4, z * 0.5) * CFrame.Angles(0, 0, math.rad(-12)), WOOD_DARK,
			M.Wood)
	end
	cart:decor("CartLoad", Vector3.new(4.4, 1.2, 3), CFrame.new(-0.6, 3, 0) * CFrame.Angles(0, math.rad(4), 0), HAY, M.Grass)
	hayBale(b, CFrame.new(-17, 0, -36) * CFrame.Angles(0, math.rad(80), 0))
	hayBale(b, CFrame.new(-17.4, 0, -39.4) * CFrame.Angles(0, math.rad(95), 0))
	hayBale(b, CFrame.new(-17.2, 2.4, -37.6) * CFrame.Angles(0, math.rad(88), 0))
	-- Guard-side: a stack of crates.
	crate(b:within(CFrame.new(20, 0, -37)), CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(-10), 0), 3.2)
	crate(b:within(CFrame.new(23, 0, -38.6)), CFrame.new(0, 0, 0) * CFrame.Angles(0, math.rad(14), 0), 2.8)
	for i, x in ipairs({ -36, -8, 12, 36 }) do
		bush(b, Vector3.new(x, 0, -44), 3, 100 + i)
	end
end

-- ------------------------------------------------------------ the courtyard --

local function courtyard(b: Kit.Builder)
	-- A worn flagstone path from the camp gate to the guards' gap, straight through the
	-- gateway: the way the fighting always goes.
	local rng = Random.new(7)
	for x = -42, 42, 3.2 do
		for _, z in ipairs({ -1.6, 1.6 }) do
			if rng:NextNumber() < 0.86 then
				b:decor("Flagstone", Vector3.new(2.9, 0.08, 2.9), CFrame.new(x + rng:NextNumber(-0.2, 0.2), 0.04, z)
					* CFrame.Angles(0, math.rad(rng:NextNumber(-6, 6)), 0), rng:NextNumber() < 0.5 and STONE_LIGHT or STONE)
			end
		end
	end
	-- A darker border of big stones round the courtyard's edge.
	for _, s in ipairs({ -1, 1 }) do
		b:decor("Border", Vector3.new(100, 0.07, 3), Vector3.new(0, 0.035, s * 48.5), STONE_DARK)
		b:decor("Border", Vector3.new(3, 0.07, 100), Vector3.new(s * 48.5, 0.035, 0), STONE_DARK)
	end
	-- Grass pushing up between the stones where nobody walks.
	for i, spot in ipairs({ Vector3.new(-10, 0, 30), Vector3.new(12, 0, 22), Vector3.new(-14, 0, -20), Vector3.new(10, 0, -24),
		Vector3.new(-6, 0, 42), Vector3.new(26, 0, 42), Vector3.new(-2, 0, -42), Vector3.new(14, 0, 8) }) do
		tuft(b, spot, 200 + i)
		tuft(b, spot + Vector3.new(1.1, 0, 0.7), 300 + i)
	end
end

-- ------------------------------------------------------------------ build --

function Flats.Build(parent: Instance, centre: Vector3)
	local root = Kit.new(parent, CFrame.new(centre))
	courtyard(root)
	raiderCamp(root)
	guardPost(root)
	gatehouse(root)
	northWalls(root)
	southTerrace(root)
end

return Flats
