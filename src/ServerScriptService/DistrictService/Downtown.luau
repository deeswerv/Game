--!strict
-- DOWNTOWN: a city district, built block by block.
--
-- A grid, laid out the way a real downtown is and nothing placed at random:
--
--   * An avenue runs north from the arrival forecourt (south) to ZEE TOWER (north); a cross
--     street runs east-west. Where they meet is ZEE PLAZA, pedestrianised: tiled paving, a
--     three-tier stone fountain, planted corners and a finger post pointing the way.
--   * South-east: ZEE GUNS and ZEE TACTICS, storefronts on the avenue you can walk into: a
--     clerk behind each counter sells guns (and a workbench fits them out) or heals, armour
--     and bombs.
--   * South-west: ZEE GAS -- canopy, pumps, and the 24/7 store with the CONTRACTS board.
--   * North-west: the DUEL HALL, a sports hall in two team colours with its own 1v1 pads.
--   * North-east: a basketball court, and an apartment block whose fire escape climbs to a
--     rooftop stash.
--   * Around it all, a ring of taller buildings and a skyline, so there is no edge to see.
--
-- The look is painted low-poly, like a toy town: soft facade colours with cream trim,
-- faceted trees, striped awnings, lettering on painted boards. Nothing glows -- no Neon
-- anywhere -- so the city reads in daylight by colour and shape, and at night by its lamps.
--
-- Coordinates are local to the district's centre: +Z north (toward the tower), y = 0 the
-- road surface, 0.5 the kerb. Built with ArenaService.Kit like the duel maps. The compass
-- agrees on north, and so east is -X (on your right as you face the tower); the comments below
-- that call the +X side "east" predate it -- the signs and the compass are what players see.

local ServerScriptService = game:GetService("ServerScriptService")

local Kit = require(ServerScriptService.ArenaService.Kit)

local Downtown = {}

Downtown.Name = "DOWNTOWN"
Downtown.HalfWidth = 200
Downtown.HalfLength = 200
Downtown.Mood = "day"
Downtown.Exposure = 1
-- Where travellers land (TravelService's Downtown place matches it), facing up the avenue.
Downtown.Arrival = Vector3.new(0, 0.5, -172)
-- Where supply drops may land: open paving only.
Downtown.DropRadius = 150

-- Cameras for tools/mapview (local coordinates).
Downtown.Preview = {
	{ pos = { 60, 330, -210 }, look = { 0, 0, 20 }, fov = 55 },
	{ pos = { 0, 5, -168 }, look = { 0, 8, 0 }, fov = 70 },
	{ pos = { 0, 6, -60 }, look = { 0, 8, 0 }, fov = 70 },
	{ pos = { 10, 6, 60 }, look = { -40, 8, 88 }, fov = 70 },
	{ pos = { -8, 6, -50 }, look = { -60, 6, -70 }, fov = 70 },
	{ pos = { 20, 12, 40 }, look = { 70, 14, 82 }, fov = 70 },
	{ pos = { 12, 5, -40 }, look = { 30, 8, -90 }, fov = 70 },
	{ pos = { -58, 5, 30 }, look = { -64, 4, 50 }, fov = 70 },
	{ pos = { -10, 4, 12 }, look = { 0, 5, 0 }, fov = 70 },
	{ pos = { 0, 5, -150 }, look = { 0, 6, -190 }, fov = 70 },
	{ pos = { -84, 6, -86 }, look = { -150, 8, -84 }, fov = 70 },
	{ pos = { -110, 9, 44 }, look = { -132, 7, 88 }, fov = 70 },
	{ pos = { -112, 6, 72 }, look = { -142, 10, 76 }, fov = 70 },
	{ pos = { 24, 5, -24 }, look = { 60, 16, -60 }, fov = 70 },
}

-- People out on the street (DistrictService dresses them; Pedestrians.client walks them):
-- each walks a stretch of sidewalk up and back, between the lamps and the trees -- every
-- stretch checked clear of them. { from, to, look (DistrictService.CIVILIANS), speed }.
Downtown.Walkers = {
	{ Vector3.new(-24, 0.54, 46), Vector3.new(-24, 0.54, 130), 1, 5 },
	{ Vector3.new(-26, 0.54, 128), Vector3.new(-26, 0.54, 48), 2, 4.6 },
	{ Vector3.new(24, 0.54, 47), Vector3.new(24, 0.54, 69), 3, 4.8 },
	{ Vector3.new(24, 0.54, 111), Vector3.new(24, 0.54, 129), 4, 4.4 },
	{ Vector3.new(22, 0.54, -129), Vector3.new(22, 0.54, -81), 5, 5.2 },
	{ Vector3.new(-24, 0.54, -179), Vector3.new(-24, 0.54, -141), 6, 4.6 },
	{ Vector3.new(20.5, 0.54, -141), Vector3.new(20.5, 0.54, -179), 1, 5 },
	{ Vector3.new(110, 0.54, 24), Vector3.new(130, 0.54, 24), 2, 4.4 },
	{ Vector3.new(-130, 0.54, -24), Vector3.new(-110, 0.54, -24), 3, 4.8 },
	{ Vector3.new(-100, 0.54, -24), Vector3.new(-80, 0.54, -24), 4, 4.6 },
	{ Vector3.new(-160, 0.54, 22), Vector3.new(-140, 0.54, 22), 5, 5 },
	{ Vector3.new(80, 0.54, 22), Vector3.new(100, 0.54, 22), 6, 4.4 },
} :: { { any } }

-- The district's grade and sky while you are in it (the time of day is left to the world).
Downtown.Look = {
	Grade = { Saturation = 0.22, Contrast = 0.06 },
	Clouds = { Cover = 0.62, Density = 0.5, Color = Color3.fromRGB(255, 255, 255) },
}

-- Interactive points the service wires up after building: prompt name -> panel.
Downtown.Panels = {
	GunCounter = "Market",          -- ZEE GUNS: the clerk behind the counter sells guns
	GunWorkbench = "Workshop",      -- and the bench by the wall fits them out
	TacticsCounter = "Tactics",     -- ZEE TACTICS: heals, armour and bombs
	ContractBoard = "Contracts",
	BountyBoard = "Bounties",
}

local M = Enum.Material

local ASPHALT = Color3.fromRGB(70, 72, 80)
local WHITE_LINE = Color3.fromRGB(236, 234, 226)
local YELLOW_LINE = Color3.fromRGB(236, 192, 64)
local SIDEWALK = Color3.fromRGB(178, 172, 164)
local SIDEWALK_EDGE = Color3.fromRGB(158, 152, 146)
local CURB = Color3.fromRGB(200, 196, 188)
local PLAZA_A = Color3.fromRGB(214, 200, 178)
local PLAZA_B = Color3.fromRGB(164, 146, 128)
local STONE = Color3.fromRGB(214, 204, 188)
local STONE_LIGHT = Color3.fromRGB(234, 226, 212)
local SOIL = Color3.fromRGB(96, 72, 54)
local GRASS = Color3.fromRGB(108, 168, 86)
local HEDGE = Color3.fromRGB(74, 134, 68)
local BLOSSOM = Color3.fromRGB(240, 168, 192)
local BLOSSOM_LIGHT = Color3.fromRGB(250, 204, 218)
local BARK = Color3.fromRGB(104, 76, 58)
local IRON = Color3.fromRGB(46, 60, 54)          -- painted street iron: lamps, bollards, rails
local STEEL = Color3.fromRGB(78, 82, 90)
local GLASS = Color3.fromRGB(110, 150, 182)
local LAMP_GLASS = Color3.fromRGB(255, 238, 200)
local WARM = Color3.fromRGB(255, 214, 150)
local WATER = Color3.fromRGB(96, 176, 214)
local WOOD = Color3.fromRGB(176, 124, 78)

-- Brand colours, painted on and never lit.
local RED = Color3.fromRGB(214, 64, 58)
local TEAL = Color3.fromRGB(38, 150, 150)
local GOLD = Color3.fromRGB(232, 176, 52)
local GREEN = Color3.fromRGB(58, 150, 96)
local ORANGE = Color3.fromRGB(236, 128, 44)
local BLUE = Color3.fromRGB(54, 118, 214)
local NAVY = Color3.fromRGB(34, 44, 66)
local CREAM = Color3.fromRGB(246, 238, 220)

-- The DUEL HALL's two sides; its pads are painted in them too (DistrictService).
Downtown.PadColours = { BLUE, ORANGE }

-- Flower rows, one colour a row, so a bed reads as planted rather than scattered.
local FLOWERS = {
	Color3.fromRGB(236, 90, 116), Color3.fromRGB(250, 196, 70), Color3.fromRGB(168, 118, 222),
	Color3.fromRGB(250, 248, 240), Color3.fromRGB(246, 146, 70),
}

local CAR_COLOURS = {
	Color3.fromRGB(206, 62, 58), Color3.fromRGB(54, 58, 66), Color3.fromRGB(240, 238, 230),
	Color3.fromRGB(64, 110, 180), Color3.fromRGB(232, 184, 64), Color3.fromRGB(150, 156, 164),
	Color3.fromRGB(70, 140, 110), Color3.fromRGB(236, 150, 120),
}

-- Cartoon-bright facade colours, as in the reference street: every building a clear, saturated
-- colour with white trim, so the street reads as a row of toys.
local FACADE = {
	Color3.fromRGB(240, 132, 58),    -- orange
	Color3.fromRGB(250, 204, 72),    -- yellow
	Color3.fromRGB(104, 190, 104),   -- green
	Color3.fromRGB(72, 156, 226),    -- blue
	Color3.fromRGB(246, 236, 214),   -- cream
	Color3.fromRGB(186, 74, 58),     -- red brick
	Color3.fromRGB(236, 112, 118),   -- coral
	Color3.fromRGB(128, 104, 196),   -- purple
	Color3.fromRGB(56, 176, 172),    -- teal
}
-- Window glass: a deep sky-blue that reads as glass against every one of those colours.
local WINDOW = Color3.fromRGB(58, 104, 160)
local TRIM = Color3.fromRGB(250, 248, 240)
local BENCH_COLOURS = { Color3.fromRGB(150, 96, 214), Color3.fromRGB(250, 196, 50), Color3.fromRGB(64, 170, 230),
	Color3.fromRGB(236, 88, 96) }
-- What the ground-floor shops are called.
local SHOPS = {
	"ZEE BEATS", "PIZZA", "BURGERS", "DONUTS", "COMICS", "ARCADE", "BARBER", "BOBA", "RECORDS", "TACOS",
	"GYM", "BAKERY", "SNEAKERS", "DINER", "FLOWERS", "GAMES", "ICE CREAM", "RAMEN", "BOOKS", "CAFE",
}
local BRICK = FACADE[6]

local AWNINGS = { RED, TEAL, GOLD, GREEN, Color3.fromRGB(70, 104, 170) }

local function darker(c: Color3, t: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), t)
end

local function lighter(c: Color3, t: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), t)
end

local function vertical(at: Vector3): CFrame
	return CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
end

--- Lettering painted straight onto a surface. `at` looks the way it is read from.
local function painted(b: Kit.Builder, text: string, at: CFrame, w: number, h: number, colour: Color3, font: Enum.Font?)
	b:sign(text, at, w, h, colour, { lit = true, glow = false, font = font or Enum.Font.GothamBlack,
		textColour = colour, brightness = 1 })
end

--- A painted signboard: a coloured panel in a darker frame, lettering on it. `at` looks the
--- way the sign is read from; the panel sits just behind it.
local function board(b: Kit.Builder, text: string, at: CFrame, w: number, h: number, bg: Color3, fg: Color3,
	font: Enum.Font?, frame: Color3?)
	local s = b:within(at)
	s:decor("SignFrame", Vector3.new(w + 0.6, h + 0.6, 0.3), Vector3.new(0, 0, 0.36), frame or darker(bg, 0.4))
	s:decor("SignBoard", Vector3.new(w, h, 0.3), Vector3.new(0, 0, 0.2), bg)
	s:sign(text, CFrame.new(), w * 0.9, h * 0.76, fg, { lit = true, glow = false, font = font or Enum.Font.GothamBlack,
		textColour = fg, brightness = 1 })
end

-- ------------------------------------------------------------ street props --

--- A street lamp, kept simple so a row of them reads as a rhythm rather than clutter: an iron
--- post that curls over at the top like a shepherd's crook, a round lantern hanging from its
--- end out over the road (-X), and on some a street banner.
local function lamp(b: Kit.Builder, withLight: boolean, banner: Color3?)
	b:part("Base", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 1.2, 0), IRON)
	b:part("Pole", Vector3.new(14, 0.5, 0.5), vertical(Vector3.new(0, 9, 0)), IRON, nil, { shape = "Cylinder" })
	b:decor("Collar", Vector3.new(0.4, 0.8, 0.8), vertical(Vector3.new(0, 6.2, 0)), IRON, nil, { shape = "Cylinder" })
	-- The crook: four straight pieces round a half circle from the top of the pole, over toward
	-- -X and down, each a little long so the joints close up into one bent tube.
	local r, cx, cy = 1.9, -1.9, 16
	local prev = Vector3.new(0, cy, 0)
	for k = 1, 4 do
		local a = k / 4 * math.pi
		local nextPoint = Vector3.new(cx + math.cos(a) * r, cy + math.sin(a) * r, 0)
		local cf, len = Kit.Span(prev, nextPoint)
		b:decor("Crook", Vector3.new(0.42, 0.42, len + 0.3), cf, IRON)
		prev = nextPoint
	end
	b:decor("Knuckle", Vector3.new(0.5, 0.5, 0.5), Vector3.new(cx, cy + r, 0), IRON, nil, { shape = "Ball" })
	-- The lantern hangs from the crook's end: a cap, a round globe of warm glass, a finial.
	local lx = cx - r
	b:decor("Hanger", Vector3.new(0.2, 0.7, 0.2), Vector3.new(lx, cy - 0.35, 0), IRON)
	b:decor("LanternCap", Vector3.new(1.8, 0.5, 1.8), Vector3.new(lx, cy - 0.85, 0), IRON)
	b:decor("LanternGlass", Vector3.new(1.7, 1.7, 1.7), Vector3.new(lx, cy - 1.9, 0), LAMP_GLASS, nil, { shape = "Ball" })
	b:decor("LanternBase", Vector3.new(0.7, 0.4, 0.7), Vector3.new(lx, cy - 2.85, 0), IRON)
	if banner then
		b:decor("BannerRod", Vector3.new(0.15, 0.15, 2.1), Vector3.new(0, 12.7, 1.15), IRON)
		b:decor("Banner", Vector3.new(0.1, 3.4, 1.7), Vector3.new(0, 10.9, 1.25), banner, M.Fabric)
		b:decor("BannerStripe", Vector3.new(0.18, 0.4, 1.76), Vector3.new(0, 9.6, 1.25), CREAM, M.Fabric)
	end
	if withLight then
		b:light("Spot", CFrame.new(lx, cy - 2.2, 0) * CFrame.Angles(-math.pi / 2, 0, 0), WARM, 1.6, 34, { Angle = 120 })
	end
end

--- A short plaza lamp: an iron post and a lantern on top.
local function postLamp(b: Kit.Builder)
	b:part("Base", Vector3.new(1.4, 1, 1.4), Vector3.new(0, 1, 0), IRON)
	b:part("Post", Vector3.new(7, 0.45, 0.45), vertical(Vector3.new(0, 5, 0)), IRON, nil, { shape = "Cylinder" })
	b:decor("LanternBase", Vector3.new(1.5, 0.3, 1.5), Vector3.new(0, 8.6, 0), IRON)
	b:decor("LanternGlass", Vector3.new(1.3, 1.6, 1.3), Vector3.new(0, 9.55, 0), LAMP_GLASS)
	b:decor("LanternCap", Vector3.new(1.8, 0.4, 1.8), Vector3.new(0, 10.55, 0), IRON)
	b:decor("LanternTop", Vector3.new(0.8, 0.5, 0.8), Vector3.new(0, 10.95, 0), IRON)
	b:light("Point", Vector3.new(0, 9.5, 0), WARM, 1.1, 20)
end

-- Each tree's canopy is one of three shapes, picked by its seed, so a row of them is a row of
-- the same kind of tree rather than one tree copied: round (a full dome), tall (an upright
-- oval) and wide (a spreading umbrella). Clumps as { offset, size, shade (1 dark .. 3 light) }.
local CANOPIES: { { { any } } } = {
	{
		{ Vector3.new(0, 8.6, 0), 6.4, 1 }, { Vector3.new(2.4, 8, 1), 4.6, 1 }, { Vector3.new(-2.3, 8.2, -1.1), 4.8, 1 },
		{ Vector3.new(-0.6, 8, 2.3), 4.2, 2 }, { Vector3.new(1, 10.6, -0.6), 4.8, 2 }, { Vector3.new(-1.3, 10.2, 0.9), 4, 2 },
		{ Vector3.new(0.3, 12.2, 0.2), 3.4, 3 }, { Vector3.new(1.9, 10.2, 1.8), 2.6, 3 },
	},
	{
		{ Vector3.new(0, 8.4, 0), 5.2, 1 }, { Vector3.new(1.4, 9.4, 0.6), 4.2, 1 }, { Vector3.new(-1.3, 9.8, -0.5), 4.2, 2 },
		{ Vector3.new(0.2, 11.4, 0.4), 4.6, 2 }, { Vector3.new(-0.4, 13.2, -0.2), 3.6, 3 }, { Vector3.new(0.8, 12.6, 1.1), 2.6, 3 },
		{ Vector3.new(0.1, 14.6, 0.1), 2.4, 3 },
	},
	{
		{ Vector3.new(0, 8.8, 0), 5.6, 1 }, { Vector3.new(3.2, 8.4, 0.8), 4.4, 1 }, { Vector3.new(-3.1, 8.6, -0.6), 4.4, 1 },
		{ Vector3.new(0.6, 8.5, 3), 4, 2 }, { Vector3.new(-0.8, 8.7, -3), 4, 2 }, { Vector3.new(1.6, 10.4, -1.2), 3.8, 2 },
		{ Vector3.new(-1.4, 10.2, 1.4), 3.6, 3 }, { Vector3.new(0.2, 11, 0.1), 3.2, 3 },
	},
}

--- A low-poly tree in a stone planter (none if `bare`, for a tree in a bed). `blossom` makes it
--- a pink one. In a planter, low shrubs and a tuft of grass round its foot. Like every street
--- prop, its origin is road level: it stands on 0.5.
local function tree(b: Kit.Builder, seed: number, blossom: boolean?, bare: boolean?)
	local rng = Random.new(seed)
	if not bare then
		b:part("Planter", Vector3.new(4.4, 0.9, 4.4), Vector3.new(0, 0.95, 0), CURB)
		b:decor("Soil", Vector3.new(3.8, 0.1, 3.8), Vector3.new(0, 1.42, 0), SOIL, M.Ground)
		for k = 0, 2 do
			local a = k * 2.1 + seed
			b:decor("Shrub", Vector3.new(1.3, 0.9, 1.3), Vector3.new(math.cos(a) * 1.25, 1.75, math.sin(a) * 1.25), HEDGE,
				nil, { shape = "Ball" })
		end
	end
	local canopy = CANOPIES[seed % #CANOPIES + 1]
	local tall = canopy == CANOPIES[2]
	b:part("Trunk", Vector3.new(if tall then 8 else 7, 1, 1), vertical(Vector3.new(0, if tall then 5.4 else 4.9, 0)), BARK,
		M.Wood, { shape = "Cylinder" })
	b:decor("TrunkFoot", Vector3.new(0.8, 1.5, 1.5), vertical(Vector3.new(0, 1.85, 0)), BARK, M.Wood, { shape = "Cylinder" })
	for _, side in ipairs({ 1, -1 }) do
		b:decor("Branch", Vector3.new(2.6, 0.45, 0.45),
			CFrame.new(side * 0.9, 7.4 + side * 0.4, side * 0.3) * CFrame.Angles(0, side * 0.6, side * math.rad(40)), BARK, M.Wood,
			{ shape = "Cylinder" })
	end
	-- A cartoon canopy: round clumps of leaves in three greens, stacked -- the big dark ones
	-- low and wide, lighter ones on top where the sun catches them.
	local shades = { Color3.fromRGB(60, 150, 64), Color3.fromRGB(92, 182, 72), Color3.fromRGB(140, 210, 90) }
	if blossom then
		shades = { Color3.fromRGB(232, 132, 170), BLOSSOM, BLOSSOM_LIGHT }
	end
	-- Leaf-textured clumps (LeafyGrass reads as foliage close up), each with a smaller clump
	-- budding off it, so the outline is bumpy and full rather than a few smooth balls.
	for n, blob in ipairs(canopy) do
		local size = blob[2] * rng:NextNumber(0.88, 1.12)
		local at = blob[1] + Vector3.new(rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.2, 0.2), rng:NextNumber(-0.3, 0.3))
		b:decor("Leaves", Vector3.new(size, size * 0.9, size), at, shades[blob[3]], M.LeafyGrass, { shape = "Ball", shadow = true })
		local a = n * 2.4 + seed
		local out = Vector3.new(at.X, 0, at.Z)
		local dir = if out.Magnitude > 0.5 then out.Unit else Vector3.new(math.cos(a), 0, math.sin(a))
		local bud = size * rng:NextNumber(0.42, 0.55)
		b:decor("Leaves", Vector3.new(bud, bud * 0.9, bud), at + dir * size * 0.42 + Vector3.new(0, size * 0.12, 0),
			shades[math.min(3, blob[3] + 1)], M.LeafyGrass, { shape = "Ball" })
	end
end

--- A slim cypress: a tall column of dark green, pointed at the top, on a short trunk. For
--- pairs at an entrance and the edges of a lawn. Origin on the ground.
local function cypress(b: Kit.Builder, seed: number)
	local rng = Random.new(seed)
	local h = rng:NextNumber(9, 12)
	b:part("Trunk", Vector3.new(2.2, 0.7, 0.7), vertical(Vector3.new(0, 1.1, 0)), BARK, M.Wood, { shape = "Cylinder" })
	local shades = { Color3.fromRGB(44, 112, 62), Color3.fromRGB(58, 132, 70), Color3.fromRGB(80, 156, 80) }
	local n = 5
	for k = 0, n - 1 do
		local t = k / (n - 1)
		local w = 2.9 * (1 - t * 0.72)
		b:decor("Leaves", Vector3.new(w, h / n * 1.7, w), Vector3.new(rng:NextNumber(-0.15, 0.15), 2.2 + t * (h - 2.6), 0),
			shades[math.min(3, 1 + math.floor(t * 3))], M.LeafyGrass, { shape = "Ball", shadow = true })
	end
end

--- A round flowering shrub, a few blooms on it. Origin on the ground.
local function shrub(b: Kit.Builder, seed: number, size: number?)
	local rng = Random.new(seed)
	local s = size or 2.2
	b:decor("Shrub", Vector3.new(s, s * 0.85, s), Vector3.new(0, s * 0.38, 0), HEDGE, M.LeafyGrass, { shape = "Ball", shadow = true })
	b:decor("Shrub", Vector3.new(s * 0.7, s * 0.6, s * 0.7), Vector3.new(s * 0.35, s * 0.3, s * 0.2),
		Color3.fromRGB(96, 160, 80), M.LeafyGrass, { shape = "Ball" })
	local bloom = FLOWERS[rng:NextInteger(1, #FLOWERS)]
	for _ = 1, 3 do
		local a = rng:NextNumber(0, 6.28)
		b:decor("Bloom", Vector3.new(0.45, 0.45, 0.45), Vector3.new(math.cos(a) * s * 0.4, s * 0.62, math.sin(a) * s * 0.4),
			bloom, nil, { shape = "Ball" })
	end
end

--- A park bench in a bright colour (purple, yellow, blue or red), slatted seat and back on
--- curled iron ends. Origin on the ground; it faces -Z.
local benchCount = 0
local function bench(b: Kit.Builder, colour: Color3?)
	benchCount += 1
	local paint = colour or BENCH_COLOURS[(benchCount % #BENCH_COLOURS) + 1]
	b:part("Seat", Vector3.new(6, 0.3, 1.7), Vector3.new(0, 1.85, 0), darker(paint, 0.35))
	for i, z in ipairs({ -0.55, 0, 0.55 }) do
		b:decor("Slat", Vector3.new(6.1, 0.14, 0.44), Vector3.new(0, 2.05, z), if i == 2 then lighter(paint, 0.08) else paint)
	end
	for i, y in ipairs({ 2.6, 3.2 }) do
		b:decor("BackSlat", Vector3.new(6.1, 0.46, 0.18), CFrame.new(0, y, 0.82 + i * 0.1) * CFrame.Angles(math.rad(-12), 0, 0),
			paint)
	end
	for _, x in ipairs({ -2.6, 2.6 }) do
		b:decor("Leg", Vector3.new(0.3, 1.5, 1.6), Vector3.new(x, 1.2, 0), IRON)
		b:decor("Arm", Vector3.new(0.34, 0.3, 1.5), Vector3.new(x, 2.6, 0.05), IRON)
		b:decor("Curl", Vector3.new(0.34, 0.5, 0.5), vertical(Vector3.new(x, 2.6, -0.75)) * CFrame.Angles(math.rad(90), 0, 0),
			IRON, nil, { shape = "Cylinder" })
		b:decor("BackPost", Vector3.new(0.3, 1.6, 0.3), CFrame.new(x, 2.9, 0.95) * CFrame.Angles(math.rad(-12), 0, 0), IRON)
	end
end

--- A cafe table under a striped umbrella, with chairs round it. Origin on the ground.
local function cafeTable(b: Kit.Builder, colour: Color3, seats: number?)
	b:part("TableFoot", Vector3.new(1.6, 0.3, 1.6), Vector3.new(0, 0.15, 0), IRON)
	b:part("TableLeg", Vector3.new(2.6, 0.35, 0.35), vertical(Vector3.new(0, 1.5, 0)), IRON, nil, { shape = "Cylinder" })
	b:decor("TableTop", Vector3.new(0.25, 3.4, 3.4), vertical(Vector3.new(0, 2.9, 0)), TRIM, nil, { shape = "Cylinder" })
	b:decor("Pole", Vector3.new(6.2, 0.2, 0.2), vertical(Vector3.new(0, 5.9, 0)), TRIM, nil, { shape = "Cylinder" })
	-- The canopy: eight wedges round the pole in the colour and white, sloping down and out.
	for i = 0, 7 do
		local yaw = math.rad(i * 45)
		-- A wedge is tall at its +Z end: that end at the pole, sloping down to the rim.
		b:decor("Canopy", Vector3.new(2.5, 1.1, 3), CFrame.Angles(0, yaw, 0) * CFrame.new(0, 8.25, -1.55),
			if i % 2 == 0 then colour else TRIM, M.Fabric, { shape = "Wedge", shadow = true })
	end
	b:decor("Finial", Vector3.new(0.5, 0.5, 0.5), Vector3.new(0, 9, 0), colour, nil, { shape = "Ball" })
	for i = 1, seats or 3 do
		local a = (i / (seats or 3)) * math.pi * 2 + 0.4
		-- Turned so its front (-Z) faces the table.
		local c = b:within(CFrame.new(math.cos(a) * 2.7, 0, math.sin(a) * 2.7)
			* CFrame.Angles(0, math.pi / 2 - a, 0))
		c:part("ChairSeat", Vector3.new(1.4, 0.2, 1.4), Vector3.new(0, 1.5, 0), colour)
		c:decor("ChairBack", Vector3.new(1.4, 1.3, 0.16), Vector3.new(0, 2.25, 0.62), colour)
		for _, x in ipairs({ -0.55, 0.55 }) do
			for _, z in ipairs({ -0.55, 0.55 }) do
				c:decor("ChairLeg", Vector3.new(0.12, 1.4, 0.12), Vector3.new(x, 0.7, z), IRON)
			end
		end
	end
end

local function bin(b: Kit.Builder)
	b:part("Bin", Vector3.new(2.6, 1.6, 1.6), vertical(Vector3.new(0, 1.8, 0)), IRON, nil, { shape = "Cylinder" })
	b:decor("Band", Vector3.new(0.3, 1.66, 1.66), vertical(Vector3.new(0, 2.4, 0)), GOLD, nil, { shape = "Cylinder" })
	b:decor("Lid", Vector3.new(0.2, 1.8, 1.8), vertical(Vector3.new(0, 3.2, 0)), IRON, nil, { shape = "Cylinder" })
end

local function hydrant(b: Kit.Builder)
	local red = Color3.fromRGB(206, 56, 48)
	b:part("Hydrant", Vector3.new(2, 0.9, 0.9), vertical(Vector3.new(0, 1.5, 0)), red, nil, { shape = "Cylinder" })
	b:decor("Cap", Vector3.new(0.4, 1.1, 1.1), vertical(Vector3.new(0, 2.6, 0)), red, nil, { shape = "Cylinder" })
	b:decor("Nozzle", Vector3.new(1.4, 0.4, 0.4), Vector3.new(0, 1.8, 0), darker(red, 0.2), nil, { shape = "Cylinder" })
end

--- A parked car, nose toward -Z.
-- The parts every car shares: glass, tyres, lamps.
-- Tinted, and opaque: see-through glass shows an empty car.
local CAR_GLASS = Color3.fromRGB(36, 46, 62)
local CAR_TRIM = Color3.fromRGB(34, 34, 38)
local CAR_CHROME = Color3.fromRGB(200, 202, 208)

--- Four wheels at `axles` (z of each) with tyres, rims and a hub cap, set `track` out from the
--- middle, `r` the tyre's radius.
local function wheels(b: Kit.Builder, track: number, axles: { number }, r: number)
	for _, x in ipairs({ -track, track }) do
		local side = if x > 0 then 1 else -1
		for _, z in ipairs(axles) do
			-- The well: a dark disc on the body behind the tyre, so each wheel sits in an arch.
			b:decor("WheelWell", Vector3.new(0.05, r * 2.5, r * 2.5), Vector3.new(x + side * 0.36, r, z), Color3.fromRGB(18, 18, 20),
				nil, { shape = "Cylinder" })
			b:decor("Wheel", Vector3.new(0.8, r * 2, r * 2), Vector3.new(x, r, z), CAR_TRIM, M.Rubber, { shape = "Cylinder" })
			b:decor("Rim", Vector3.new(0.84, r * 1.15, r * 1.15), Vector3.new(x, r, z), CAR_CHROME, M.Metal, { shape = "Cylinder" })
			-- Five spokes across the rim, and the hub over them.
			for k = 0, 4 do
				local a = k * math.pi * 2 / 5
				b:decor("Spoke", Vector3.new(0.08, r * 1.05, 0.16),
					CFrame.new(x + side * 0.43, r, z) * CFrame.Angles(a, 0, 0), Color3.fromRGB(150, 152, 158), M.Metal)
			end
			b:decor("HubCap", Vector3.new(0.9, r * 0.4, r * 0.4), Vector3.new(x, r, z), CAR_TRIM, nil, { shape = "Cylinder" })
		end
	end
end

--- Both sides of a car: a chrome strip under the windows from `z0` to `z1` at `belt`, and a
--- door handle at each of `handles` (z), at `y`.
local function carSides(b: Kit.Builder, width: number, belt: number, z0: number, z1: number, y: number, handles: { number })
	for _, x in ipairs({ -1, 1 }) do
		b:decor("BeltLine", Vector3.new(0.06, 0.12, z1 - z0), Vector3.new(x * (width / 2 + 0.03), belt, (z0 + z1) / 2), CAR_CHROME,
			M.Metal)
		for _, z in ipairs(handles) do
			b:decor("Handle", Vector3.new(0.08, 0.14, 0.5), Vector3.new(x * (width / 2 + 0.04), y, z), CAR_CHROME, M.Metal)
		end
	end
end

--- The front and back of a car `length` long and `width` wide: bumpers, the grille, headlamps,
--- tail lamps, number plates, all at `y` (the bumper line).
local function carEnds(b: Kit.Builder, width: number, length: number, y: number, lamp: number)
	local half = length / 2
	for _, s in ipairs({ -1, 1 }) do
		b:decor("Bumper", Vector3.new(width + 0.1, 0.45, 0.4), Vector3.new(0, y, s * (half + 0.05)), CAR_TRIM)
		b:decor("Plate", Vector3.new(1.2, 0.36, 0.06), Vector3.new(0, y, s * (half + 0.27)), Color3.fromRGB(246, 244, 236))
		for _, x in ipairs({ -1, 1 }) do
			b:decor(if s < 0 then "Headlight" else "Taillight", Vector3.new(0.9, 0.36, 0.1),
				Vector3.new(x * (width / 2 - 0.6), lamp, s * (half + 0.03)),
				if s < 0 then Color3.fromRGB(250, 246, 226) else Color3.fromRGB(200, 40, 40), M.Glass, { reflectance = 0.2 })
			b:decor("LampSurround", Vector3.new(1.06, 0.5, 0.06), Vector3.new(x * (width / 2 - 0.6), lamp, s * (half + 0.0)),
				CAR_CHROME, M.Metal)
		end
	end
	-- An exhaust under the back bumper, off to one side.
	b:decor("Exhaust", Vector3.new(0.7, 0.26, 0.26), CFrame.new(width / 2 - 1, y - 0.35, half + 0.2) * CFrame.Angles(0, math.pi / 2, 0),
		Color3.fromRGB(120, 122, 128), M.Metal, { shape = "Cylinder" })
	b:decor("Grille", Vector3.new(width * 0.5, 0.42, 0.08), Vector3.new(0, lamp - 0.05, -half - 0.03), CAR_TRIM)
end

--- A car parked at its origin (on the road), facing -Z. Five kinds, each its own shape so a
--- row of them reads as different cars rather than one car in different paints:
---
---   sedan     long bonnet, a raked windscreen, a cabin with a pillar, a boot
---   hatch     short and tall, the roof running back to a steep hatch
---   suv       high and square, roof rails, a spare wheel on the back
---   pickup    a cab, then an open bed with a tailgate
---   taxi      a sedan in yellow with a checker band and a TAXI light on the roof
---
--- The lower body and the cabin are solid (you cannot walk through a car); the rest is trim.
local function car(b: Kit.Builder, colour: Color3, kind: string?)
	local style = kind or "sedan"
	local W = 4.6
	local trimColour = darker(colour, 0.35)
	if style == "sedan" or style == "taxi" then
		if style == "taxi" then
			colour = Color3.fromRGB(250, 200, 44)
			trimColour = darker(colour, 0.35)
		end
		local L = 10
		b:part("Body", Vector3.new(W, 1.3, L), Vector3.new(0, 1.45, 0), colour, nil, { reflectance = 0.05 })
		b:decor("Skirt", Vector3.new(W + 0.04, 0.32, 5.2), Vector3.new(0, 0.95, 0), CAR_TRIM)
		-- The bonnet slopes down to the nose; the boot is flat.
		b:decor("Bonnet", Vector3.new(W - 0.2, 0.34, 3.1), Vector3.new(0, 2.27, -3.35), colour, nil, { shape = "Wedge" })
		b:decor("Boot", Vector3.new(W - 0.2, 0.28, 2.1), Vector3.new(0, 2.24, 3.9), colour)
		-- The cabin: windscreen, roof, rear screen, the side glass and the pillar between.
		b:decor("Windscreen", Vector3.new(W - 0.6, 1.25, 1.5), Vector3.new(0, 2.72, -1.25), CAR_GLASS, M.SmoothPlastic,
			{ shape = "Wedge", reflectance = 0.25 })
		b:part("Cabin", Vector3.new(W - 0.6, 1.1, 2.6), Vector3.new(0, 2.65, 0.8), CAR_GLASS, M.SmoothPlastic, { reflectance = 0.2 })
		b:decor("Roof", Vector3.new(W - 0.5, 0.22, 2.7), Vector3.new(0, 3.31, 0.8), colour)
		b:decor("RearScreen", Vector3.new(W - 0.6, 1.1, 1.1), CFrame.new(0, 2.65, 2.65) * CFrame.Angles(0, math.pi, 0),
			CAR_GLASS, M.SmoothPlastic, { shape = "Wedge", reflectance = 0.25 })
		b:decor("Pillar", Vector3.new(W - 0.56, 1.1, 0.22), Vector3.new(0, 2.65, 0.6), colour)
		b:decor("DoorLine", Vector3.new(W + 0.03, 1.0, 0.06), Vector3.new(0, 1.5, 0.6), trimColour)
		carEnds(b, W, L, 1.0, 1.8)
		wheels(b, 2.0, { -3.2, 3.2 }, 1.05)
		carSides(b, W, 2.13, -1.9, 2.3, 1.85, { -0.2, 1.4 })
		b:decor("Aerial", Vector3.new(3, 0.08, 0.08), CFrame.new(1.6, 3.6, 4.4) * CFrame.Angles(0, 0, math.rad(80)), CAR_TRIM, nil,
			{ shape = "Cylinder" })
		for _, x in ipairs({ -1, 1 }) do
			b:decor("Mirror", Vector3.new(0.45, 0.3, 0.35), Vector3.new(x * 2.45, 2.55, -1.6), colour)
		end
		if style == "taxi" then
			b:decor("Checker", Vector3.new(W + 0.05, 0.26, 5.6), Vector3.new(0, 1.85, 0.3), CAR_TRIM)
			b:decor("TaxiLight", Vector3.new(1.6, 0.45, 0.6), Vector3.new(0, 3.65, 0.8), Color3.fromRGB(252, 240, 200))
			painted(b, "TAXI", Kit.Look(Vector3.new(0, 3.65, 0.48), Vector3.new(0, 3.65, -5)), 1.4, 0.36, CAR_TRIM)
		end
	elseif style == "hatch" then
		local L = 8.2
		b:part("Body", Vector3.new(W - 0.2, 1.3, L), Vector3.new(0, 1.45, 0), colour, nil, { reflectance = 0.05 })
		b:decor("Skirt", Vector3.new(W - 0.16, 0.32, 3.8), Vector3.new(0, 0.95, 0), CAR_TRIM)
		b:decor("Bonnet", Vector3.new(W - 0.4, 0.3, 2.1), Vector3.new(0, 2.25, -3.0), colour, nil, { shape = "Wedge" })
		b:decor("Windscreen", Vector3.new(W - 0.7, 1.35, 1.4), Vector3.new(0, 2.77, -1.25), CAR_GLASS, M.SmoothPlastic,
			{ shape = "Wedge", reflectance = 0.25 })
		b:part("Cabin", Vector3.new(W - 0.7, 1.2, 3.6), Vector3.new(0, 2.7, 1.25), CAR_GLASS, M.SmoothPlastic, { reflectance = 0.2 })
		b:decor("Roof", Vector3.new(W - 0.6, 0.24, 3.7), Vector3.new(0, 3.42, 1.2), colour)
		b:decor("Hatch", Vector3.new(W - 0.66, 1.2, 0.3), CFrame.new(0, 2.7, 3.1) * CFrame.Angles(math.rad(-8), 0, 0),
			CAR_GLASS, M.SmoothPlastic, { reflectance = 0.25 })
		b:decor("Pillar", Vector3.new(W - 0.66, 1.2, 0.24), Vector3.new(0, 2.7, 0.9), colour)
		b:decor("DoorLine", Vector3.new(W - 0.17, 1.0, 0.06), Vector3.new(0, 1.5, 0.9), trimColour)
		carEnds(b, W - 0.2, L, 1.0, 1.85)
		wheels(b, 1.9, { -2.6, 2.6 }, 1.0)
		carSides(b, W - 0.2, 2.13, -1.9, 3.0, 1.85, { 0, 1.8 })
		for _, x in ipairs({ -1, 1 }) do
			b:decor("Mirror", Vector3.new(0.45, 0.3, 0.35), Vector3.new(x * 2.3, 2.6, -1.5), colour)
		end
	elseif style == "suv" then
		local L = 10.4
		b:part("Body", Vector3.new(W + 0.2, 1.7, L), Vector3.new(0, 1.85, 0), colour, nil, { reflectance = 0.05 })
		b:decor("Cladding", Vector3.new(W + 0.24, 0.5, L - 0.2), Vector3.new(0, 1.15, 0), CAR_TRIM)
		b:decor("Bonnet", Vector3.new(W, 0.25, 2.6), Vector3.new(0, 2.82, -3.8), colour)
		b:decor("Windscreen", Vector3.new(W - 0.4, 1.3, 0.9), Vector3.new(0, 3.35, -2.05), CAR_GLASS, M.SmoothPlastic,
			{ shape = "Wedge", reflectance = 0.25 })
		b:part("Cabin", Vector3.new(W - 0.4, 1.3, 6.2), Vector3.new(0, 3.35, 1.5), CAR_GLASS, M.SmoothPlastic, { reflectance = 0.2 })
		b:decor("Roof", Vector3.new(W - 0.2, 0.26, 6.9), Vector3.new(0, 4.1, 1.15), colour)
		for _, x in ipairs({ -1, 1 }) do
			b:decor("RoofRail", Vector3.new(0.16, 0.16, 5.6), Vector3.new(x * 1.9, 4.32, 1.2), CAR_TRIM)
			b:decor("Mirror", Vector3.new(0.5, 0.36, 0.4), Vector3.new(x * 2.6, 3.15, -1.8), colour)
		end
		for _, z in ipairs({ -0.4, 2.2 }) do
			b:decor("Pillar", Vector3.new(W - 0.36, 1.3, 0.26), Vector3.new(0, 3.35, z), colour)
		end
		b:decor("DoorLine", Vector3.new(W + 0.23, 1.2, 0.06), Vector3.new(0, 2.0, 0.9), trimColour)
		carEnds(b, W + 0.2, L, 1.2, 2.3)
		wheels(b, 2.1, { -3.4, 3.4 }, 1.2)
		carSides(b, W + 0.2, 2.73, -2.5, 4.6, 2.4, { 0.2, 2.6 })
		b:decor("Spare", Vector3.new(0.6, 2, 2), CFrame.new(0, 2.4, L / 2 + 0.35) * CFrame.Angles(0, math.rad(90), 0),
			CAR_TRIM, M.Rubber, { shape = "Cylinder" })
		b:decor("SpareCover", Vector3.new(0.64, 1.4, 1.4), CFrame.new(0, 2.4, L / 2 + 0.38) * CFrame.Angles(0, math.rad(90), 0),
			colour, nil, { shape = "Cylinder" })
	else -- pickup
		local L = 11
		b:part("Body", Vector3.new(W + 0.2, 1.5, L), Vector3.new(0, 1.65, 0), colour, nil, { reflectance = 0.05 })
		b:decor("Skirt", Vector3.new(W + 0.24, 0.34, L - 4.6), Vector3.new(0, 1.0, 0), CAR_TRIM)
		b:decor("Bonnet", Vector3.new(W, 0.3, 2.8), Vector3.new(0, 2.55, -3.9), colour)
		b:decor("Windscreen", Vector3.new(W - 0.4, 1.3, 1.1), Vector3.new(0, 3.05, -2.0), CAR_GLASS, M.SmoothPlastic,
			{ shape = "Wedge", reflectance = 0.25 })
		b:part("Cabin", Vector3.new(W - 0.4, 1.3, 2.4), Vector3.new(0, 3.05, -0.3), CAR_GLASS, M.SmoothPlastic, { reflectance = 0.2 })
		b:decor("Roof", Vector3.new(W - 0.2, 0.26, 3.0), Vector3.new(0, 3.8, -0.6), colour)
		b:decor("CabBack", Vector3.new(W, 1.4, 0.3), Vector3.new(0, 3.05, 1.0), colour)
		-- The bed: a floor, two sides and the tailgate, a crate in it.
		b:decor("BedFloor", Vector3.new(W - 0.2, 0.1, 4.2), Vector3.new(0, 2.45, 3.25), CAR_TRIM)
		for _, x in ipairs({ -1, 1 }) do
			b:decor("BedSide", Vector3.new(0.2, 0.8, 4.4), Vector3.new(x * (W / 2), 2.8, 3.2), colour)
			b:decor("Mirror", Vector3.new(0.5, 0.36, 0.4), Vector3.new(x * 2.6, 2.95, -1.4), colour)
		end
		b:decor("Tailgate", Vector3.new(W + 0.2, 0.8, 0.2), Vector3.new(0, 2.8, L / 2 - 0.1), colour)
		b:decor("Crate", Vector3.new(1.6, 1.0, 1.4), CFrame.new(-0.8, 3.0, 3.4) * CFrame.Angles(0, math.rad(12), 0), WOOD, M.WoodPlanks)
		carEnds(b, W + 0.2, L, 1.05, 2.1)
		wheels(b, 2.1, { -3.6, 3.4 }, 1.15)
		carSides(b, W + 0.2, 2.43, -2.4, 1.1, 2.1, { -0.6 })
	end
end

-- Which kind each parked car is, in turn: mostly saloons and hatches, a few of the rest.
local CAR_KINDS = { "sedan", "hatch", "suv", "sedan", "pickup", "hatch", "taxi", "sedan", "suv" }

--- A raised bed of flowers in rows, one colour a row. Origin at the bed's centre on the ground;
--- the rows run along X.
local function flowerBed(b: Kit.Builder, w: number, d: number, seed: number)
	b:part("Bed", Vector3.new(w, 1, d), Vector3.new(0, 0.5, 0), STONE)
	b:decor("BedCap", Vector3.new(w + 0.3, 0.2, d + 0.3), Vector3.new(0, 1.05, 0), STONE_LIGHT)
	b:decor("Soil", Vector3.new(w - 0.6, 0.1, d - 0.6), Vector3.new(0, 1.12, 0), SOIL, M.Ground)
	local row = 0
	for z = -d / 2 + 1, d / 2 - 1 + 1e-3, 1.5 do
		row += 1
		local colour = FLOWERS[(row + seed) % #FLOWERS + 1]
		for x = -w / 2 + 1, w / 2 - 1 + 1e-3, 1.5 do
			b:decor("Tuft", Vector3.new(1.1, 0.6, 1.1), CFrame.new(x, 1.45, z) * CFrame.Angles(0, math.rad(45), 0), HEDGE)
			b:decor("Bloom", Vector3.new(0.7, 0.35, 0.7), Vector3.new(x, 1.85, z), colour)
		end
	end
end

-- -------------------------------------------------------------- buildings --

-- What each kind of shop puts out front, so a street of them reads as a bakery, a barber and
-- a record shop rather than one shop with different names: its icon on a sign hung out over
-- the pavement, and by the door a chalkboard, a menu stand, a barber's pole, a rack of stock
-- or buckets of flowers.
local SHOP_KIT: { [string]: { icon: string, out: string } } = {
	["ZEE BEATS"] = { icon = "🎧", out = "rack" }, PIZZA = { icon = "🍕", out = "menu" },
	BURGERS = { icon = "🍔", out = "menu" }, DONUTS = { icon = "🍩", out = "chalk" }, COMICS = { icon = "💥", out = "rack" },
	ARCADE = { icon = "🕹", out = "chalk" }, BARBER = { icon = "💈", out = "pole" }, BOBA = { icon = "🧋", out = "chalk" },
	RECORDS = { icon = "💿", out = "rack" }, TACOS = { icon = "🌮", out = "menu" }, GYM = { icon = "💪", out = "chalk" },
	BAKERY = { icon = "🥐", out = "chalk" }, SNEAKERS = { icon = "👟", out = "rack" }, DINER = { icon = "☕", out = "menu" },
	FLOWERS = { icon = "🌷", out = "buckets" }, GAMES = { icon = "🎮", out = "rack" }, ["ICE CREAM"] = { icon = "🍦", out = "chalk" },
	RAMEN = { icon = "🍜", out = "menu" }, BOOKS = { icon = "📚", out = "rack" }, CAFE = { icon = "☕", out = "chalk" },
}

--- A shop's front: a glazed door in the middle of the window, the blade sign with its icon at
--- one end, and its own thing on the pavement at the other. `on(y, out, along)` is a point on
--- the face; `normal` points out of it; `axis` is the face's ("x" or "z"); `span` its width.
local function shopDressing(b: Kit.Builder, name: string, colour: Color3, on: (number, number, number) -> Vector3,
	normal: Vector3, axis: string, span: number)
	local kit = SHOP_KIT[name] or { icon = "★", out = "chalk" }
	local across = if axis == "x" then Vector3.new(0, 0, 1) else Vector3.new(1, 0, 0)
	-- A frame standing on the pavement `along` the face and `out` from it; its -Z is out.
	local function at(along: number, out: number): CFrame
		local p = on(0.5, out, along)
		return Kit.Look(p, p + normal)
	end
	-- The door.
	local door = at(0, 0.56)
	b:decor("ShopDoor", Vector3.new(3, 5.2, 0.12), door * CFrame.new(0, 2.6, 0), darker(colour, 0.45))
	b:decor("ShopDoorGlass", Vector3.new(2.2, 4.2, 0.12), door * CFrame.new(0, 2.9, -0.05), Color3.fromRGB(150, 196, 222),
		nil, { reflectance = 0.2 })
	b:decor("ShopDoorHandle", Vector3.new(0.14, 0.9, 0.14), door * CFrame.new(0.8, 2.6, -0.14), CAR_CHROME, M.Metal)
	-- The blade sign: an iron arm out of the wall at the end of the window, the sign hung under
	-- it edge-on to the street, the icon on both sides.
	local edge = span * 0.44
	local arm = at(edge, 0)
	b:decor("BladeArm", Vector3.new(0.18, 0.18, 2.6), arm * CFrame.new(0, 9.7, -1.3), IRON)
	b:decor("BladeSign", Vector3.new(0.22, 2, 2), arm * CFrame.new(0, 8.4, -1.5), colour)
	b:decor("BladeTrim", Vector3.new(0.26, 2.2, 0.16), arm * CFrame.new(0, 8.4, -2.55), TRIM)
	for _, s in ipairs({ -1, 1 }) do
		local face = on(8.4, 1.5, edge + s * 0.13)
		b:sign(kit.icon, Kit.Look(face, face + across * s), 1.6, 1.6, TRIM, { lit = true, glow = false,
			font = Enum.Font.GothamBlack, textColour = TRIM, brightness = 1 })
	end
	-- What stands by the door, at the window's other end.
	local spot = at(-edge + 1, 1.1)
	if kit.out == "chalk" then
		-- A chalkboard A-frame, OPEN on the street side.
		for _, s in ipairs({ -1, 1 }) do
			b:decor("ChalkBoard", Vector3.new(1.5, 2.4, 0.12),
				spot * CFrame.new(0, 1.15, s * 0.3) * CFrame.Angles(s * math.rad(-12), 0, 0), Color3.fromRGB(44, 52, 48))
		end
		painted(b, "OPEN", spot * CFrame.new(0, 1.3, -0.48) * CFrame.Angles(math.rad(-12), 0, 0), 1.2, 0.5,
			Color3.fromRGB(246, 240, 220), Enum.Font.Cartoon)
	elseif kit.out == "menu" then
		-- A menu on a post.
		b:decor("MenuPost", Vector3.new(0.18, 3.6, 0.18), spot * CFrame.new(0, 1.8, 0), IRON)
		b:decor("MenuBoard", Vector3.new(1.8, 2.2, 0.14), spot * CFrame.new(0, 3.2, -0.12), colour)
		painted(b, "MENU", spot * CFrame.new(0, 3.75, -0.21), 1.4, 0.5, TRIM)
		for k = 0, 2 do
			b:decor("MenuLine", Vector3.new(1.3, 0.12, 0.04), spot * CFrame.new(0, 3.2 - k * 0.35, -0.2), TRIM)
		end
	elseif kit.out == "pole" then
		-- The barber's pole on the wall: white, banded red and blue, a ball on top.
		local pole = at(-edge + 1, 0.55)
		b:decor("BarberPole", Vector3.new(3, 0.6, 0.6), pole * CFrame.new(0, 4.4, 0) * CFrame.Angles(0, 0, math.rad(90)),
			Color3.fromRGB(246, 246, 246), nil, { shape = "Cylinder" })
		for k, c in ipairs({ RED, Color3.fromRGB(54, 96, 200), RED }) do
			b:decor("PoleBand", Vector3.new(0.3, 0.64, 0.64),
				pole * CFrame.new(0, 3.3 + k * 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), c, nil, { shape = "Cylinder" })
		end
		b:decor("PoleCap", Vector3.new(0.7, 0.7, 0.7), pole * CFrame.new(0, 6.1, 0), CAR_CHROME, M.Metal, { shape = "Ball" })
	elseif kit.out == "rack" then
		-- A low rack of stock under the window.
		b:decor("Rack", Vector3.new(2.4, 1.6, 0.9), spot * CFrame.new(0, 0.8, 0), darker(colour, 0.3))
		for k = 0, 2 do
			b:decor("Stock", Vector3.new(0.6, 0.6, 0.5), spot * CFrame.new(-0.75 + k * 0.75, 1.9, 0),
				AWNINGS[(k + #name) % #AWNINGS + 1])
		end
	else
		-- Buckets of flowers.
		for k = 0, 2 do
			local bucket = spot * CFrame.new(-0.8 + k * 0.8, 0, 0)
			b:decor("FlowerBucket", Vector3.new(0.9, 0.7, 0.7), bucket * CFrame.new(0, 0.45, 0) * CFrame.Angles(0, 0, math.rad(90)),
				Color3.fromRGB(70, 90, 110), M.Metal, { shape = "Cylinder" })
			b:decor("Bunch", Vector3.new(0.9, 0.8, 0.9), bucket * CFrame.new(0, 1.15, 0), FLOWERS[(k + 1) % #FLOWERS + 1], nil,
				{ shape = "Ball" })
		end
	end
end

--- A block building from the ground to `top`, drawn like the reference street: a saturated
--- colour with white trim, a ground floor of shopfronts (a painted shop sign and a striped
--- awning on most), and above it rows of real windows -- white frames, sills, arched tops on
--- some buildings, shutters on others, a bay window on the wide ones -- between brick courses,
--- under a heavy two-step cornice. Faces are listed as "+x", "-x", "+z", "-z" or "all".
---
--- `detail` names the faces that get the full treatment (the ones that face a street); the
--- rest get cheaper banded windows, since nobody walks past them. `simple` skips close-up
--- detail altogether, for the far skyline.
local function building(b: Kit.Builder, x0: number, x1: number, z0: number, z1: number, top: number,
	colour: Color3, faces: { string }, seed: number, simple: boolean?, detail: { string }?, plain: { string }?)
	local w, d = x1 - x0, z1 - z0
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local base = -2
	local trim = if colour == FACADE[5] then Color3.fromRGB(214, 120, 86) else TRIM
	-- Painted render (Plaster) or brick: a little texture, so a wall reads as a wall up close.
	b:part("Building", Vector3.new(w, top - base, d), Vector3.new(cx, (top + base) / 2, cz), colour,
		colour == BRICK and M.Brick or M.Plaster)
	-- The cornice: a frieze band, a wide overhanging course, a cap.
	b:decor("Frieze", Vector3.new(w + 0.5, 1.6, d + 0.5), Vector3.new(cx, top - 2.7, cz), darker(colour, 0.18))
	b:decor("Cornice", Vector3.new(w + 1.6, 1, d + 1.6), Vector3.new(cx, top - 1.4, cz), trim)
	b:decor("Cap", Vector3.new(w + 0.8, 0.8, d + 0.8), Vector3.new(cx, top + 0.3, cz), darker(colour, 0.12))
	local rng = Random.new(seed)
	-- The building's window style, the same on every face: framed, arched, or shuttered.
	local style = rng:NextInteger(1, 3)
	local shutter = AWNINGS[rng:NextInteger(1, #AWNINGS)]
	if faces[1] == "all" then
		faces = { "+x", "-x", "+z", "-z" }
	end
	local full: { [string]: boolean } = {}
	for _, f in ipairs(detail or faces) do
		full[f] = true
	end
	-- Faces that are backs (onto a lane, behind a waterfall): real windows, no shop on them.
	local back: { [string]: boolean } = {}
	for _, f in ipairs(plain or {}) do
		back[f] = true
	end
	for _, face in ipairs(faces) do
		local axis, sign = face:sub(2, 2), face:sub(1, 1) == "+" and 1 or -1
		local span = axis == "x" and d or w
		local normal = axis == "x" and Vector3.new(sign, 0, 0) or Vector3.new(0, 0, sign)
		-- A point on the face `out` studs proud of it, `along` studs across it, at height y.
		local function on(y: number, out: number, along: number): Vector3
			if axis == "x" then
				return Vector3.new(cx + sign * (w / 2 + out), y, cz + along)
			end
			return Vector3.new(cx + along, y, cz + sign * (d / 2 + out))
		end
		-- A box flat on the face: `wide` across it, `tall`, `deep` out of it.
		local function slab(name: string, wide: number, tall: number, deep: number, y: number, along: number,
			c: Color3, material: Enum.Material?, opts: Kit.Opts?)
			local size = axis == "x" and Vector3.new(deep, tall, wide) or Vector3.new(wide, tall, deep)
			b:decor(name, size, on(y, deep / 2, along), c, material, opts)
		end
		-- A box standing `out` studs clear of the face (balcony fronts and rails).
		local function stand(name: string, wide: number, tall: number, deep: number, y: number, along: number,
			out: number, c: Color3)
			local size = axis == "x" and Vector3.new(deep, tall, wide) or Vector3.new(wide, tall, deep)
			b:decor(name, size, on(y, out + deep / 2, along), c)
		end
		-- A disc flat on the face (for arched window heads), its axis along the normal.
		local function disc(name: string, diameter: number, deep: number, y: number, along: number, c: Color3)
			local at = on(y, deep / 2, along)
			local cf = if axis == "x" then CFrame.new(at) else CFrame.new(at) * CFrame.Angles(0, math.pi / 2, 0)
			b:decor(name, Vector3.new(deep, diameter, diameter), cf, c, nil, { shape = "Cylinder" })
		end
		local rich = not simple and full[face] == true
		if not simple then
			-- Ground floor, ten studs tall: a darker band, a glass shopfront run, room over it for
			-- an awning and the shop's sign, and a trim course on top.
			slab("Ground", span, 10, 0.3, 5, 0, darker(colour, 0.25))
			if not back[face] then
				slab("Shopfront", span * 0.84, 4.6, 0.5, 3.8, 0, WINDOW, M.Glass, { reflectance = 0.2 })
			end
			slab("Course", span + 0.2, if axis == "x" then 0.86 else 0.8, 0.6, 10.2, 0, trim)
			if back[face] then
				-- A back wall: nothing hung on the ground floor.
			elseif rich and span >= 14 then
				-- The shop: its name on a painted board over the window, and a striped awning.
				local shopColour = AWNINGS[rng:NextInteger(1, #AWNINGS)]
				local name = SHOPS[rng:NextInteger(1, #SHOPS)]
				local signAt = on(8.5, 0.62, 0)
				board(b, name, Kit.Look(signAt, signAt + normal), math.min(span * 0.6, 16), 1.8, shopColour, TRIM)
				shopDressing(b, name, shopColour, on, normal, axis, span)
				if rng:NextNumber() < 0.8 then
					local run = span * 0.78
					local stripes = math.max(4, math.floor(run / 2.4))
					local sw = run / stripes
					for k = 0, stripes - 1 do
						local along = -run / 2 + sw * (k + 0.5)
						local p = on(6.9, 1.6, along)
						local awning = b:part("Awning", Vector3.new(sw, 1.3, 3.2), Kit.Look(p, p + normal),
							if k % 2 == 0 then shopColour else TRIM, M.Fabric, { shape = "Wedge", collide = false })
						awning.CastShadow = true
					end
				end
			elseif rng:NextNumber() < 0.5 then
				local p = on(6.9, 1.6, 0)
				local awning = b:part("Awning", Vector3.new(span * 0.8, 1.4, 3.2), Kit.Look(p, p + normal),
					AWNINGS[rng:NextInteger(1, #AWNINGS)], M.Fabric, { shape = "Wedge", collide = false })
				awning.CastShadow = true
			end
		end
		-- Floors above. On a street face they are rows of real windows all the way up (seven
		-- floors, the tallest street block); every face nobody walks past is a glass band a floor.
		local floor = 0
		for y = 14, top - 5, 7 do
			floor += 1
			if rich and floor <= 7 then
				if floor > 1 then
					slab("BrickCourse", span - 3, 0.35, 0.25, y - 3.4, 0, darker(colour, 0.22))
				end
				local count = math.max(1, math.floor(span / 7))
				local gap = span * 0.9 / count
				local ww = math.min(3.4, gap - 2)
				local bay = style ~= 2 and span >= 26 and floor <= 3 and count >= 3
				for k = 0, count - 1 do
					local along = -span * 0.45 + gap * (k + 0.5)
					local middle = bay and k == math.floor(count / 2)
					if middle then
						-- A bay window: a box stood out from the wall, glass on its three faces.
						slab("Bay", ww + 3, 5, 1.8, y, along, trim)
						slab("BayGlass", ww + 2, 3.8, 1.9, y + 0.2, along, WINDOW, M.Glass, { reflectance = 0.15 })
						slab("BayMullion", 0.3, 3.8, 1.96, y + 0.2, along, trim)
						slab("BayRoof", ww + 3.6, 0.5, 2.3, y + 2.75, along, darker(colour, 0.2))
						slab("BayCorbel", ww + 2, 0.6, 1.4, y - 2.8, along, darker(trim, 0.08))
					else
						local wh = if style == 2 then 3 else 3.6
						slab("Frame", ww + 0.8, wh + 0.8, 0.22, y, along, trim)
						slab("Glass", ww, wh, 0.34, y, along, WINDOW, M.Glass, { reflectance = 0.15 })
						slab("Sill", ww + 1.2, 0.35, 0.6, y - wh / 2 - 0.45, along, trim)
						-- Lived in: now and then an air unit hung under a window, or a box of flowers
						-- on the sill.
						local life = rng:NextNumber()
						if floor >= 2 and life < 0.12 then
							stand("WindowUnit", 1.7, 1.1, 1.1, y - wh / 2 - 1.3, along + ww * 0.15, 0, Color3.fromRGB(214, 216, 212))
							stand("UnitGrille", 1.3, 0.7, 0.06, y - wh / 2 - 1.3, along + ww * 0.15, 1.1, STEEL)
						elseif floor >= 2 and life < 0.24 then
							stand("WindowBox", ww + 0.4, 0.5, 0.6, y - wh / 2 - 0.4, along, 0.6, darker(trim, 0.25))
							stand("WindowBlooms", ww, 0.45, 0.5, y - wh / 2 + 0.05, along, 0.62, FLOWERS[(k + floor) % #FLOWERS + 1])
						end
						if style == 2 then
							-- Arched: a round head on the frame and the glass.
							disc("ArchFrame", ww + 0.8, 0.22, y + wh / 2, along, trim)
							disc("ArchGlass", ww, 0.34, y + wh / 2, along, WINDOW)
							slab("Keystone", 0.7, 0.7, 0.3, y + wh / 2 + ww / 2 + 0.2, along, darker(trim, 0.08))
						elseif style == 3 then
							for _, side in ipairs({ -1, 1 }) do
								slab("Shutter", 0.9, wh + 0.4, 0.2, y, along + side * (ww / 2 + 0.85), shutter)
							end
						else
							slab("Lintel", ww + 1.2, 0.5, 0.45, y + wh / 2 + 0.55, along, darker(colour, 0.2))
							if floor == 2 and k % 2 == 0 then
								-- A little balcony: a slab, an iron front and sides, a rail, a box of flowers.
								local floorY = y - wh / 2 - 0.8
								slab("Balcony", ww + 2, 0.3, 1.6, floorY, along, darker(trim, 0.1))
								stand("BalconyFront", ww + 2, 1.1, 0.12, floorY + 0.7, along, 1.46, IRON)
								stand("BalconyRail", ww + 2.1, 0.16, 0.22, floorY + 1.33, along, 1.42, IRON)
								for _, side in ipairs({ -1, 1 }) do
									stand("BalconySide", 0.12, 1.1, 1.46, floorY + 0.7, along + side * (ww / 2 + 0.94), 0, IRON)
								end
								stand("BalconyFlowers", ww, 0.45, 0.45, floorY + 1.64, along, 1.12, HEDGE)
								stand("BalconyBlooms", ww - 0.4, 0.3, 0.35, floorY + 2, along, 1.17, FLOWERS[(k + floor) % #FLOWERS + 1])
							end
						end
					end
				end
			else
				slab("Windows", span * 0.9, 3, 0.3, y, 0, WINDOW, M.Glass, { reflectance = 0.15 })
			end
		end
		if not simple and top > 16 and not rich then
			local count = math.max(2, math.floor(span / 8))
			for k = 0, count do
				local along = -span * 0.45 + k * (span * 0.9 / count)
				slab("Pilaster", 0.9, top - 12.4, 0.6, (top + 8.8) / 2, along, trim)
			end
		elseif rich then
			-- Corner quoins: trim piers up both edges of a street face.
			for _, edge in ipairs({ -1, 1 }) do
				-- Stopped a little short of the corner and of the frieze, so no face is shared.
				slab("Quoin", 1.2, top - 13, 0.46, (top + 8.2) / 2, edge * (span / 2 - 0.8), trim)
			end
			-- Carved brackets under the cornice, all along it, like a brownstone's.
			local brackets = math.max(2, math.floor((span - 4) / 3.4))
			for k = 0, brackets do
				local along = -(span - 4) / 2 + k * ((span - 4) / brackets)
				stand("Bracket", 0.7, 1.3, 0.55, top - 2.55, along, 0.25, trim)
			end
		end
	end
	-- Something on the roof: a water tank on legs, an air unit, a stair hut.
	if not simple and w > 20 and d > 20 then
		local rx, rz = cx + rng:NextNumber(-w / 5, w / 5), cz + rng:NextNumber(-d / 5, d / 5)
		local pick = rng:NextInteger(1, 3)
		if pick == 1 then
			for _, o in ipairs({ Vector3.new(-1.6, 0, -1.6), Vector3.new(1.6, 0, -1.6), Vector3.new(-1.6, 0, 1.6),
				Vector3.new(1.6, 0, 1.6) }) do
				b:decor("TankLeg", Vector3.new(0.4, 3, 0.4), Vector3.new(rx, top + 2.2, rz) + o, IRON)
			end
			b:decor("Tank", Vector3.new(5, 5, 5), vertical(Vector3.new(rx, top + 6.2, rz)), Color3.fromRGB(150, 104, 66),
				M.WoodPlanks, { shape = "Cylinder" })
			b:decor("TankCap", Vector3.new(0.8, 5.4, 5.4), vertical(Vector3.new(rx, top + 9, rz)), IRON, nil,
				{ shape = "Cylinder" })
		elseif pick == 2 then
			b:decor("RoofUnit", Vector3.new(6, 3, 5), Vector3.new(rx, top + 2.2, rz), Color3.fromRGB(206, 208, 204), M.Metal)
			b:decor("Fan", Vector3.new(0.3, 3.2, 3.2), vertical(Vector3.new(rx, top + 3.8, rz)), STEEL, nil,
				{ shape = "Cylinder" })
		else
			b:decor("StairHut", Vector3.new(6, 4.6, 6), Vector3.new(rx, top + 3, rz), darker(colour, 0.1))
			b:decor("HutRoof", Vector3.new(6.6, 0.5, 6.6), Vector3.new(rx, top + 5.5, rz), trim)
		end
		-- And something else across the roof from it: a pair of chimney stacks, or an aerial.
		local ox, oz = cx - (rx - cx) * 1.6, cz - (rz - cz) * 1.6
		ox = math.clamp(ox, x0 + 3, x1 - 3)
		oz = math.clamp(oz, z0 + 3, z1 - 3)
		if rng:NextNumber() < 0.55 then
			for _, dx in ipairs({ -1.1, 1.1 }) do
				b:decor("Chimney", Vector3.new(1.6, 4.4, 1.6), Vector3.new(ox + dx, top + 2.5, oz), darker(BRICK, 0.1), M.Brick)
				b:decor("ChimneyCap", Vector3.new(2, 0.4, 2), Vector3.new(ox + dx, top + 4.9, oz), STEEL)
			end
		else
			b:decor("Aerial", Vector3.new(9, 0.25, 0.25), vertical(Vector3.new(ox, top + 4.8, oz)), STEEL, M.Metal, { shape = "Cylinder" })
			for _, y in ipairs({ 6.4, 8 }) do
				b:decor("AerialBar", Vector3.new(3, 0.18, 0.18), Vector3.new(ox, top + y, oz), STEEL, M.Metal)
			end
		end
	end
end

--- The faces of a block in quarter (sx, sz) that look onto the avenue and the cross street.
local function streetFaces(sx: number, sz: number): { string }
	return { sx > 0 and "-x" or "+x", sz > 0 and "-z" or "+z" }
end

-- ----------------------------------------------------------------- streets --

local function markings(b: Kit.Builder, from: number, to: number, alongZ: boolean)
	-- Double yellow down the middle, dashed white between lanes.
	local len = to - from
	local mid = (from + to) / 2
	local function strip(name: string, across: number, alongAt: number, alongLen: number, width: number, colour: Color3)
		if alongZ then
			b:decor(name, Vector3.new(width, 0.04, alongLen), Vector3.new(across, 0.02, alongAt), colour)
		else
			b:decor(name, Vector3.new(alongLen, 0.04, width), Vector3.new(alongAt, 0.02, across), colour)
		end
	end
	strip("CentreLine", -0.45, mid, len, 0.3, YELLOW_LINE)
	strip("CentreLine", 0.45, mid, len, 0.3, YELLOW_LINE)
	for _, lane in ipairs({ -9, 9 }) do
		for a = from + 3, to - 5, 10 do
			strip("LaneDash", lane, a + 2, 4, 0.3, WHITE_LINE)
		end
	end
	-- Bright yellow edge lines, as the reference streets have them.
	for _, edge in ipairs({ -16.8, 16.8 }) do
		strip("EdgeLine", edge, mid, len, 0.45, YELLOW_LINE)
	end
end

local function crosswalk(b: Kit.Builder, at: number, alongZ: boolean)
	for i = -5, 5 do
		local across = i * 3
		if alongZ then
			b:decor("Zebra", Vector3.new(1.6, 0.04, 8), Vector3.new(across, 0.03, at), WHITE_LINE)
		else
			b:decor("Zebra", Vector3.new(8, 0.04, 1.6), Vector3.new(at, 0.03, across), WHITE_LINE)
		end
	end
end

--- A raised slab of kerb-level paving with a lighter kerb along the edges that meet roads.
local function pavement(b: Kit.Builder, x0: number, x1: number, z0: number, z1: number, colour: Color3,
	kerbs: { string }?)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	b:part("Pavement", Vector3.new(x1 - x0, 0.5, z1 - z0), Vector3.new(cx, 0.25, cz), colour, M.Pavement)
	-- Kerbs stand a few hundredths proud of the paving's edge. Flush, the kerb's face and the
	-- slab's face were one plane in two colours, and every kerb flickered along its length.
	local proud = 0.03
	for _, edge in ipairs(kerbs or {}) do
		if edge == "-x" then
			b:decor("Kerb", Vector3.new(0.5, 0.56, z1 - z0 + 0.06), Vector3.new(x0 + 0.25 - proud, 0.29, cz), CURB, M.Concrete)
		elseif edge == "+x" then
			b:decor("Kerb", Vector3.new(0.5, 0.56, z1 - z0 + 0.06), Vector3.new(x1 - 0.25 + proud, 0.29, cz), CURB, M.Concrete)
		elseif edge == "-z" then
			b:decor("Kerb", Vector3.new(x1 - x0 + 0.06, 0.56, 0.5), Vector3.new(cx, 0.29, z0 + 0.25 - proud), CURB, M.Concrete)
		elseif edge == "+z" then
			b:decor("Kerb", Vector3.new(x1 - x0 + 0.06, 0.56, 0.5), Vector3.new(cx, 0.29, z1 - 0.25 + proud), CURB, M.Concrete)
		end
	end
end

-- ------------------------------------------------------------------ plaza --

--- The fountain: an octagonal pool with a stone coping wide enough to sit on, a three-tier
--- stone fountain in the middle with water falling from bowl to bowl, and eight arcing jets
--- from the coping. Origin at the pool's centre on the plaza floor.
local function fountain(b: Kit.Builder)
	local R = 12                                     -- the pool's apothem
	local side = 2 * R * math.tan(math.rad(22.5))
	b:part("PoolFloor", Vector3.new(0.6, 2 * R + 1, 2 * R + 1), vertical(Vector3.new(0, 0.3, 0)), STONE, nil,
		{ shape = "Cylinder" })
	b:decor("Water", Vector3.new(0.2, 2 * R + 0.4, 2 * R + 0.4), vertical(Vector3.new(0, 1.3, 0)), WATER, M.Glass,
		{ shape = "Cylinder", transparency = 0.2, reflectance = 0.15 })
	for i = 0, 7 do
		local cf = CFrame.Angles(0, math.rad(i * 45), 0) * CFrame.new(0, 1.1, -R)
		b:part("Coping", Vector3.new(side + 0.9, 2.2, 1.6), cf, STONE)
		b:decor("CopingCap", Vector3.new(side + 1.3, 0.3, 2.1), cf * CFrame.new(0, 1.25, 0), STONE_LIGHT)
	end
	-- The tiers: pedestal, wide bowl, slim pedestal, small bowl, finial.
	b:part("Pedestal", Vector3.new(4.4, 3, 3), vertical(Vector3.new(0, 2.8, 0)), STONE, nil, { shape = "Cylinder" })
	b:part("Bowl", Vector3.new(0.9, 10, 10), vertical(Vector3.new(0, 5.45, 0)), STONE, nil, { shape = "Cylinder" })
	b:decor("BowlLip", Vector3.new(0.3, 10.4, 10.4), vertical(Vector3.new(0, 6.05, 0)), STONE_LIGHT, nil,
		{ shape = "Cylinder" })
	b:decor("BowlWater", Vector3.new(0.1, 9.4, 9.4), vertical(Vector3.new(0, 6.24, 0)), WATER, M.Glass,
		{ shape = "Cylinder", transparency = 0.15 })
	b:part("Stem", Vector3.new(3, 1.6, 1.6), vertical(Vector3.new(0, 7.4, 0)), STONE, nil, { shape = "Cylinder" })
	b:part("TopBowl", Vector3.new(0.7, 5.6, 5.6), vertical(Vector3.new(0, 9.2, 0)), STONE, nil, { shape = "Cylinder" })
	b:decor("TopLip", Vector3.new(0.25, 5.9, 5.9), vertical(Vector3.new(0, 9.65, 0)), STONE_LIGHT, nil,
		{ shape = "Cylinder" })
	b:decor("TopWater", Vector3.new(0.1, 5.1, 5.1), vertical(Vector3.new(0, 9.82, 0)), WATER, M.Glass,
		{ shape = "Cylinder", transparency = 0.15 })
	b:decor("Finial", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 10.3, 0), STONE_LIGHT, nil, { shape = "Ball" })
	b:decor("Jet", Vector3.new(1.8, 0.5, 0.5), vertical(Vector3.new(0, 11.6, 0)), lighter(WATER, 0.5), nil,
		{ shape = "Cylinder", transparency = 0.35 })
	-- Sheets of water falling from each bowl's rim.
	local fall = lighter(WATER, 0.45)
	b:decor("Curtain", Vector3.new(3.6, 9.6, 9.6), vertical(Vector3.new(0, 3.2, 0)), fall, nil,
		{ shape = "Cylinder", transparency = 0.6 })
	b:decor("Curtain", Vector3.new(2.6, 5.3, 5.3), vertical(Vector3.new(0, 7.6, 0)), fall, nil,
		{ shape = "Cylinder", transparency = 0.6 })
	-- Eight small bubbling jets in a ring round the fountain, each out of a stone spout.
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22.5)
		local at = Vector3.new(math.cos(a) * 8, 0, math.sin(a) * 8)
		b:decor("Spout", Vector3.new(0.8, 1.2, 1.2), vertical(at + Vector3.new(0, 1.2, 0)), STONE_LIGHT, nil,
			{ shape = "Cylinder" })
		b:decor("Jet", Vector3.new(1.8, 0.3, 0.3), vertical(at + Vector3.new(0, 2.5, 0)), fall, nil,
			{ shape = "Cylinder", transparency = 0.4 })
	end
end

--- A finger post: arms pointing to each part of the district, readable from both sides.
local function fingerPost(b: Kit.Builder, arms: { { any } })
	b:part("Post", Vector3.new(13, 0.6, 0.6), vertical(Vector3.new(0, 6.5, 0)), IRON, nil, { shape = "Cylinder" })
	b:part("Foot", Vector3.new(1.4, 1, 1.4), Vector3.new(0, 0.5, 0), IRON)
	b:decor("Finial", Vector3.new(1, 1, 1), Vector3.new(0, 13.3, 0), GOLD, nil, { shape = "Ball" })
	for i, arm in ipairs(arms) do
		local text, yaw, colour = arm[1] :: string, arm[2] :: number, arm[3] :: Color3
		local a = b:within(CFrame.new(0, 12.6 - i * 1.4, 0) * CFrame.Angles(0, math.rad(yaw), 0))
		a:decor("Arm", Vector3.new(5.4, 1.1, 0.25), Vector3.new(3, 0, 0), colour)
		a:decor("Tip", Vector3.new(0.78, 0.78, 0.25), CFrame.new(5.7, 0, 0) * CFrame.Angles(0, 0, math.rad(45)), colour)
		for _, s in ipairs({ -1, 1 }) do
			a:sign(text, Kit.Look(Vector3.new(3, 0, s * 0.14), Vector3.new(3, 0, s * 10)), 4.8, 0.75, CREAM,
				{ lit = true, glow = false, font = Enum.Font.GothamBlack, textColour = CREAM, brightness = 1 })
		end
	end
end

--- ZEE PLAZA: tiles, the fountain, benches round it, planted corners, lamps and a finger post.
local function plaza(b: Kit.Builder, half: number)
	pavement(b, -half, half, -half, half, PLAZA_B, { "-x", "+x", "-z", "+z" })
	-- Two-tone tiles in rings: pale outside, dark inside, a pale ring near the middle.
	local tile = 8
	for x = -half + tile / 2, half - tile / 2, tile do
		for z = -half + tile / 2, half - tile / 2, tile do
			local ring = math.max(math.abs(x), math.abs(z))
			local pale = ring > half - 12 or (ring > 12 and ring < 22)
			if pale then
				-- The paving steps up in clear layers where they overlap: slab 0.50, tile 0.52,
				-- walk strip 0.54, kerb 0.56. Level with each other they flickered.
				b:decor("Tile", Vector3.new(tile - 0.3, 0.04, tile - 0.3), Vector3.new(x, 0.5, z), PLAZA_A, M.Slate)
			end
		end
	end

	fountain(b:within(CFrame.new(0, 0.5, 0)))

	-- A bench facing the fountain on each side, a lamp at each corner of the ring, a planted
	-- bed in every corner. The square is for walking across; it is kept open.
	for i = 0, 3 do
		local turn = CFrame.Angles(0, math.rad(i * 90), 0)
		bench(b:within(turn * CFrame.new(0, 0, -22) * CFrame.Angles(0, math.pi, 0)))
		postLamp(b:within(turn * CFrame.new(17, 0, 17)))
		-- The corner bed: a stone planter, a tree in the middle, flowers round it.
		local corner = b:within(turn * CFrame.new(half - 9, 0.5, half - 9))
		corner:part("CornerBed", Vector3.new(12, 1.4, 12), Vector3.new(0, 0.7, 0), STONE)
		corner:decor("CornerCap", Vector3.new(12.4, 0.25, 12.4), Vector3.new(0, 1.45, 0), STONE_LIGHT)
		corner:decor("CornerGrass", Vector3.new(11, 0.1, 11), Vector3.new(0, 1.5, 0), GRASS, M.Grass)
		for k, spot in ipairs({ Vector3.new(-4, 0, -4), Vector3.new(4, 0, 4), Vector3.new(-4, 0, 4) }) do
			local colour = FLOWERS[(k + i) % #FLOWERS + 1]
			corner:decor("Tuft", Vector3.new(1.6, 0.8, 1.6), CFrame.new(spot + Vector3.new(0, 1.9, 0))
				* CFrame.Angles(0, math.rad(45), 0), HEDGE)
			corner:decor("Bloom", Vector3.new(1, 0.45, 1), spot + Vector3.new(0, 2.45, 0), colour)
		end
		tree(corner:within(CFrame.new(0, 0.15, 0)), 40 + i, i % 2 == 1, true)
	end
	-- Cafe tables under striped umbrellas in the square's four quarters.
	for i, spot in ipairs({ { 28, 14 }, { -28, -14 } }) do
		cafeTable(b:within(CFrame.new(spot[1], 0.5, spot[2])), BENCH_COLOURS[i])
	end
	-- The finger post where the avenue comes in from the south.
	fingerPost(b:within(CFrame.new(0, 0.5, -31)), {
		{ "ZEE TOWER", -90, NAVY },
		{ "DUEL HALL", -135, BLUE },
		{ "COURTS", -45, TEAL },
		{ "24/7 · GAS", 135, GREEN },
		{ "ZEE GUNS", 45, RED },
	})
end

-- ------------------------------------------------------------- set pieces --

--- The inside of ZEE GUNS: wood floor, racks of rifles on the back wall, pistols in glass
--- cases, a target sheet, and the workbench where guns are fitted out (the Armory panel).
local function gunsInterior(b: Kit.Builder, depth: number, width: number)
	local plank = Color3.fromRGB(150, 108, 72)
	for i = 0, math.floor((width - 2) / 2) - 1 do
		b:decor("FloorPlank", Vector3.new(depth - 2, 0.06, 1.9), Vector3.new(depth / 2, 0.23, -width / 2 + 2 + i * 2),
			if i % 2 == 0 then plank else darker(plank, 0.08), M.WoodPlanks)
	end
	-- Racks: a dark board on the back wall, rifles hung across it in two rows.
	for _, z in ipairs({ -9, 9 }) do
		local rack = b:within(CFrame.new(depth - 1.2, 0, z))
		rack:decor("RackBoard", Vector3.new(0.3, 7, 12), Vector3.new(0, 7.5, 0), Color3.fromRGB(52, 46, 42), M.Wood)
		for row = 0, 1 do
			for k = -2, 2 do
				local g = rack:within(CFrame.new(-0.35, 5.6 + row * 3.2, k * 2.3) * CFrame.Angles(math.rad(90), 0, 0))
				g:decor("Rifle", Vector3.new(0.3, 5.2, 0.5), Vector3.new(0, 0, 0), Color3.fromRGB(38, 40, 44), M.Metal)
				g:decor("Stock", Vector3.new(0.34, 1.6, 0.9), Vector3.new(0, -2.4, -0.23),
					if (k + row) % 2 == 0 then WOOD else Color3.fromRGB(70, 72, 60), M.Wood)
			end
		end
	end
	-- Pistol cases either side of the aisle up to the counter.
	for _, z in ipairs({ -8, 8 }) do
		local case = b:within(CFrame.new(12, 0, z))
		case:part("CaseBase", Vector3.new(2.4, 2.8, 5), Vector3.new(0, 1.6, 0), Color3.fromRGB(58, 50, 44), M.Wood)
		case:decor("CaseGlass", Vector3.new(2.3, 1, 4.9), Vector3.new(0, 3.5, 0), GLASS, M.Glass, { transparency = 0.6 })
		for k = -1, 1 do
			case:decor("Pistol", Vector3.new(1.1, 0.25, 0.6), CFrame.new(0, 3.12, k * 1.4) * CFrame.Angles(0, math.rad(20), 0),
				Color3.fromRGB(34, 36, 40), M.Metal)
		end
	end
	-- A target sheet on the side wall, and a workbench under it.
	local wall = b:within(CFrame.new(depth / 2 - 3, 0, -width / 2 + 1.2))
	wall:decor("Target", Vector3.new(4, 5, 0.1), Vector3.new(0, 8, 0), CREAM)
	for i, r in ipairs({ 1.8, 1.25, 0.7 }) do
		wall:decor("Ring", Vector3.new(0.1, r * 2, r * 2), CFrame.new(0, 8, 0.06 + i * 0.02) * CFrame.Angles(0, math.rad(90), 0),
			if i % 2 == 1 then Color3.fromRGB(30, 30, 34) else CREAM, nil, { shape = "Cylinder" })
	end
	wall:part("Workbench", Vector3.new(8, 3.2, 3), Vector3.new(0, 1.6, 1.6), Color3.fromRGB(120, 88, 60), M.Wood)
	wall:decor("BenchTop", Vector3.new(8.3, 0.3, 3.3), Vector3.new(0, 3.35, 1.6), Color3.fromRGB(96, 70, 48), M.Wood)
	wall:decor("Vise", Vector3.new(1, 0.9, 0.8), Vector3.new(-2.6, 3.95, 1.2), STEEL, M.Metal)
	wall:decor("BenchGun", Vector3.new(3.6, 0.3, 0.5), Vector3.new(0.6, 3.66, 1.4), Color3.fromRGB(40, 42, 46), M.Metal)
	local bench = wall:decor("Bench", Vector3.new(6, 0.08, 3), Vector3.new(0, 0.3, 4.4), darker(plank, 0.2))
	bench.Name = "GunWorkbench"
	bench.Transparency = 1
	bench:SetAttribute("PromptText", "Customise")
	bench:SetAttribute("PromptObject", "Attachments & builds")
	-- The sign over the racks.
	painted(b, "ZEE GUNS", Kit.Look(Vector3.new(depth - 1.5, 11.2, 0), Vector3.new(0, 11.2, 0)), 10, 1.4, GOLD)
end

--- The inside of ZEE TACTICS: dark rubber floor, a shelf of heals on the back wall, armour on
--- mannequins down one side, bombs on a pegboard down the other, each shelf edged in the
--- colours of the grades it sells.
local function tacticsInterior(b: Kit.Builder, depth: number, width: number)
	local tileA, tileB = Color3.fromRGB(58, 62, 72), Color3.fromRGB(72, 78, 90)
	local nx, nz = math.floor((depth - 2) / 4), math.floor((width - 2) / 4)
	local tx, tz = (depth - 2) / nx, (width - 2) / nz
	for ix = 0, nx - 1 do
		for iz = 0, nz - 1 do
			b:decor("FloorTile", Vector3.new(tx - 0.04, 0.06, tz - 0.04),
				Vector3.new(1 + (ix + 0.5) * tx, 0.23, -width / 2 + 1 + (iz + 0.5) * tz),
				if (ix + iz) % 2 == 0 then tileA else tileB, M.Rubber)
		end
	end
	local tiers = { Color3.fromRGB(150, 158, 172), Color3.fromRGB(46, 200, 84), Color3.fromRGB(46, 150, 255),
		Color3.fromRGB(176, 76, 255), Color3.fromRGB(255, 170, 20), Color3.fromRGB(255, 56, 96) }
	-- Heals: a long shelf unit on the back wall, three shelves of first-aid boxes.
	local shelf = b:within(CFrame.new(depth - 1.6, 0, 0))
	shelf:decor("ShelfBack", Vector3.new(0.3, 8, 16), Vector3.new(0.4, 5, 0), Color3.fromRGB(226, 228, 232))
	for row = 0, 2 do
		local y = 2.6 + row * 2.4
		shelf:decor("Shelf", Vector3.new(1.6, 0.2, 16), Vector3.new(-0.4, y, 0), Color3.fromRGB(236, 238, 242))
		for k = 0, 5 do
			local z = -6.6 + k * 2.64
			shelf:decor("ShelfEdge", Vector3.new(0.1, 0.24, 2.5), Vector3.new(-1.24, y, z), tiers[k + 1])
			local kit = shelf:within(CFrame.new(-0.4, y + 0.1, z))
			kit:decor("HealBox", Vector3.new(1, 0.9, 1.4), Vector3.new(0, 0.45, 0), Color3.fromRGB(246, 246, 248))
			kit:decor("Cross", Vector3.new(0.06, 0.5, 0.16), Vector3.new(-0.52, 0.45, 0), RED)
			kit:decor("Cross", Vector3.new(0.06, 0.16, 0.5), Vector3.new(-0.53, 0.45, 0), RED)
		end
	end
	painted(b, "HEALS", Kit.Look(Vector3.new(depth - 1.4, 10.6, 0), Vector3.new(0, 10.6, 0)), 6, 1.2, Color3.fromRGB(96, 226, 110))

	-- Armour: mannequins in vests down the -Z wall, one per grade, on a low plinth.
	for k = 0, 5 do
		local x = 5 + k * 3.2
		local m = b:within(CFrame.new(x, 0, -width / 2 + 2.6))
		m:part("Plinth", Vector3.new(2.4, 0.6, 2.4), Vector3.new(0, 0.5, 0), Color3.fromRGB(44, 48, 56))
		m:decor("Stand", Vector3.new(0.3, 2.2, 0.3), Vector3.new(0, 1.9, 0), STEEL, M.Metal)
		m:decor("Torso", Vector3.new(1.8, 2.2, 1), Vector3.new(0, 4.1, 0), Color3.fromRGB(214, 206, 196))
		m:decor("MannequinHead", Vector3.new(0.9, 0.9, 0.9), Vector3.new(0, 5.6, 0), Color3.fromRGB(214, 206, 196), nil,
			{ shape = "Ball" })
		m:decor("Vest", Vector3.new(2, 1.9, 1.2), Vector3.new(0, 4.05, 0), darker(tiers[k + 1], 0.25), M.Fabric)
		m:decor("VestPlate", Vector3.new(1.2, 1.1, 0.08), Vector3.new(0, 4.15, 0.62), tiers[k + 1])
	end
	painted(b, "ARMOR", Kit.Look(Vector3.new(13, 10.6, -width / 2 + 1.2), Vector3.new(13, 10.6, 0)), 6, 1.2,
		Color3.fromRGB(52, 214, 240))

	-- Bombs: a pegboard on the +Z wall, a row of grenades per grade.
	local peg = b:within(CFrame.new(13, 0, width / 2 - 1.2) * CFrame.Angles(0, math.pi, 0))
	peg:decor("Pegboard", Vector3.new(18, 6.4, 0.2), Vector3.new(0, 5.8, 0), Color3.fromRGB(196, 164, 120), M.Wood)
	for k = 0, 5 do
		local x = -7.5 + k * 3
		peg:decor("PegLabel", Vector3.new(2.4, 0.3, 0.08), Vector3.new(x, 8.6, 0.14), tiers[k + 1])
		for row = 0, 2 do
			local g = peg:within(CFrame.new(x, 3.6 + row * 1.5, 0.55))
			g:decor("Grenade", Vector3.new(0.8, 0.8, 0.8), Vector3.new(0, 0, 0), Color3.fromRGB(70, 84, 56), M.Metal,
				{ shape = "Ball" })
			g:decor("GrenadeBand", Vector3.new(0.84, 0.18, 0.84), Vector3.new(0, 0.1, 0), tiers[k + 1])
			g:decor("GrenadePin", Vector3.new(0.2, 0.3, 0.2), Vector3.new(0, 0.5, 0), STEEL, M.Metal)
		end
	end
	painted(b, "BOMBS", Kit.Look(Vector3.new(13, 10.6, width / 2 - 1.3), Vector3.new(13, 10.6, 0)), 6, 1.2,
		Color3.fromRGB(236, 84, 70))
	-- Crates of stock in the corner, and the grade chart on the wall behind the counter.
	for i, at in ipairs({ Vector3.new(4, 0.2, width / 2 - 4.6), Vector3.new(6.6, 0.2, width / 2 - 4.2) }) do
		local size = if i == 1 then 2.4 else 2
		local crate = b:within(CFrame.new(at) * CFrame.Angles(0, math.rad(i * 11), 0))
		crate:part("Crate", Vector3.new(size, size * 0.8, size), Vector3.new(0, size * 0.4, 0), Color3.fromRGB(96, 104, 76),
			M.Wood)
		crate:decor("CrateBand", Vector3.new(size + 0.04, 0.2, size * 0.2), Vector3.new(0, size * 0.8 + 0.02, 0), STEEL,
			M.Metal)
	end
	local chart = b:within(CFrame.new(28.5, 0, -width / 2 + 1.2))
	chart:decor("Chart", Vector3.new(4, 6, 0.1), Vector3.new(0, 7, 0), Color3.fromRGB(30, 32, 38))
	for k = 0, 5 do
		chart:decor("ChartBar", Vector3.new(3.4, 0.7, 0.06), Vector3.new(0, 9.2 - k * 0.85, 0.08), tiers[k + 1])
	end
end

--- Mark `part` as something to rob (StickupService); `where` names it. Build adds where the
--- street is once the district stands.
local function stickup(part: BasePart, where: string, kind: string)
	part:SetAttribute("Stickup", where)
	part:SetAttribute("StickupKind", kind)
end

--- A cash machine set into a wall, facing -X, origin on the floor at the wall: a brushed-steel
--- body in a navy surround, the lit ATM header, a screen that says WELCOME sunk between two
--- privacy fins, the card slot with its little green light, a keypad on a sloped shelf, and the
--- cash slot under a steel lip; a cool light over the keypad. Its own model ("CashMachine"),
--- so a robbery can find its screen and its slot (Stickups.client). The body is what gets
--- robbed.
local function atm(b: Kit.Builder, where: string)
	local model = Instance.new("Model")
	model.Name = "CashMachine"
	model.Parent = b.parent
	local m = Kit.new(model, b.frame)
	local dark = Color3.fromRGB(26, 28, 34)
	m:decor("ATMSurround", Vector3.new(0.16, 4.3, 2.3), Vector3.new(-0.08, 2.15, 0), NAVY)
	local housing = m:part("ATM", Vector3.new(0.9, 3.4, 1.4), Vector3.new(-0.45, 1.7, 0), STEEL, M.Metal)
	stickup(housing, where, "atm")
	model.PrimaryPart = housing
	m:decor("ATMHeader", Vector3.new(0.96, 0.55, 1.44), Vector3.new(-0.48, 3.12, 0), NAVY)
	painted(m, "ATM", Kit.Look(Vector3.new(-0.98, 3.12, 0), Vector3.new(-10, 3.12, 0)), 1.1, 0.4, CREAM)
	m:decor("ATMLightBar", Vector3.new(0.06, 0.06, 1.3), Vector3.new(-0.97, 2.8, 0), Color3.fromRGB(150, 214, 255))
	-- The screen.
	m:decor("ATMBezel", Vector3.new(0.06, 0.8, 1.1), Vector3.new(-0.9, 2.33, 0), dark)
	m:decor("ATMScreen", Vector3.new(0.06, 0.64, 0.94), Vector3.new(-0.93, 2.33, 0), Color3.fromRGB(46, 120, 156))
	painted(m, "WELCOME", Kit.Look(Vector3.new(-0.97, 2.38, 0), Vector3.new(-10, 2.38, 0)), 0.8, 0.2, CREAM,
		Enum.Font.GothamBold)
	for _, s in ipairs({ -1, 1 }) do
		m:decor("ATMFin", Vector3.new(0.3, 0.84, 0.05), Vector3.new(-1.04, 2.33, s * 0.58), dark)
	end
	-- The card slot and its light.
	m:decor("ATMCardSlot", Vector3.new(0.06, 0.08, 0.36), Vector3.new(-0.93, 1.84, -0.3), Color3.fromRGB(16, 16, 20))
	m:decor("ATMCardLight", Vector3.new(0.05, 0.06, 0.08), Vector3.new(-0.94, 1.84, -0.56), Color3.fromRGB(90, 230, 120))
	-- The keypad on its shelf: the keys, and the green and red ones.
	m:decor("ATMShelf", Vector3.new(0.5, 0.12, 1.2), Vector3.new(-1.12, 1.6, 0), STEEL, M.Metal)
	local pad = CFrame.new(-1.12, 1.69, 0.12) * CFrame.Angles(0, 0, math.rad(-15))
	m:decor("ATMKeypad", Vector3.new(0.34, 0.06, 0.6), pad, Color3.fromRGB(40, 42, 48))
	m:decor("ATMKeys", Vector3.new(0.26, 0.03, 0.4), pad * CFrame.new(0, 0.04, -0.04), Color3.fromRGB(196, 200, 206))
	m:decor("ATMEnter", Vector3.new(0.08, 0.03, 0.1), pad * CFrame.new(-0.07, 0.04, 0.22), Color3.fromRGB(70, 190, 100))
	m:decor("ATMCancel", Vector3.new(0.08, 0.03, 0.1), pad * CFrame.new(0.07, 0.04, 0.22), Color3.fromRGB(220, 70, 60))
	-- The cash slot, under its lip.
	m:decor("ATMCashSlot", Vector3.new(0.06, 0.12, 0.7), Vector3.new(-0.93, 1.25, 0), Color3.fromRGB(16, 16, 20))
	m:decor("ATMCashLip", Vector3.new(0.14, 0.04, 0.78), Vector3.new(-0.96, 1.17, 0), Color3.fromRGB(150, 154, 162), M.Metal)
	m:decor("ATMKick", Vector3.new(0.05, 0.4, 1.36), Vector3.new(-0.92, 0.25, 0), dark)
	m:light("Spot", CFrame.lookAt(Vector3.new(-1.05, 2.9, 0), Vector3.new(-1.6, 0.6, 0)), Color3.fromRGB(214, 236, 255),
		0.9, 7, { Angle = 100 })
end

--- A shop till on a counter top, facing -X (the customer's side), origin on the counter at its
--- middle: a squat body over a cash drawer, a sloped keypad, the receipt printer, and the
--- customer display on a stalk. The drawer ("RegisterDrawer", with its notes and coins) sits
--- shut inside the body; a robbery slides it out (Stickups.client). Its own model ("Till").
--- The body is what gets robbed.
local function till(b: Kit.Builder, where: string)
	local model = Instance.new("Model")
	model.Name = "Till"
	model.Parent = b.parent
	local t = Kit.new(model, b.frame)
	local body = Color3.fromRGB(44, 46, 52)
	local register = t:decor("Register", Vector3.new(1.5, 0.46, 1.8), Vector3.new(0.05, 0.23, 0), body)
	stickup(register, where, "register")
	model.PrimaryPart = register
	t:decor("RegisterBody", Vector3.new(1, 0.42, 1.6), Vector3.new(0.3, 0.67, 0), Color3.fromRGB(56, 58, 66))
	-- The keypad slopes down toward the customer.
	local pad = CFrame.new(-0.36, 0.56, 0) * CFrame.Angles(0, 0, math.rad(20))
	t:decor("RegisterKeys", Vector3.new(0.62, 0.1, 1.5), pad, Color3.fromRGB(72, 74, 82))
	for i, dx in ipairs({ -0.17, 0, 0.17 }) do
		t:decor("Key", Vector3.new(0.11, 0.05, 0.9), pad * CFrame.new(dx, 0.06, -0.2),
			if i == 1 then Color3.fromRGB(240, 236, 226) else Color3.fromRGB(214, 212, 204))
	end
	t:decor("Key", Vector3.new(0.4, 0.05, 0.22), pad * CFrame.new(0, 0.06, 0.48), Color3.fromRGB(80, 190, 110))
	-- The receipt printer at the back, a curl of paper out of it.
	t:decor("Printer", Vector3.new(0.42, 0.3, 0.5), Vector3.new(0.5, 1.03, -0.52), Color3.fromRGB(34, 36, 40))
	t:decor("Receipt", Vector3.new(0.03, 0.32, 0.3), CFrame.new(0.3, 1.26, -0.52) * CFrame.Angles(0, 0, math.rad(-14)),
		Color3.fromRGB(246, 244, 238))
	-- The customer display.
	t:decor("ScreenStalk", Vector3.new(0.12, 0.5, 0.12), Vector3.new(0.55, 1.12, 0.42), Color3.fromRGB(34, 36, 40))
	t:decor("ScreenBack", Vector3.new(0.12, 0.46, 0.82), Vector3.new(0.5, 1.52, 0.42), Color3.fromRGB(34, 36, 40))
	t:decor("RegisterScreen", Vector3.new(0.04, 0.36, 0.7), Vector3.new(0.43, 1.52, 0.42), Color3.fromRGB(80, 200, 130))
	painted(t, "$0.00", Kit.Look(Vector3.new(0.4, 1.52, 0.42), Vector3.new(-10, 1.52, 0.42)), 0.62, 0.26,
		Color3.fromRGB(18, 60, 34), Enum.Font.GothamBold)
	-- The drawer, shut: its front just proud of the body, the tray and the money inside.
	local drawerModel = Instance.new("Model")
	drawerModel.Name = "RegisterDrawer"
	drawerModel.Parent = model
	local d = Kit.new(drawerModel, b.frame)
	local tray = d:decor("DrawerTray", Vector3.new(1.3, 0.05, 1.62), Vector3.new(0, 0.07, 0), Color3.fromRGB(30, 30, 34))
	drawerModel.PrimaryPart = tray
	d:decor("DrawerFront", Vector3.new(0.08, 0.36, 1.72), Vector3.new(-0.71, 0.22, 0), Color3.fromRGB(150, 154, 162), M.Metal)
	d:decor("DrawerHandle", Vector3.new(0.06, 0.06, 0.6), Vector3.new(-0.77, 0.3, 0), Color3.fromRGB(30, 30, 34))
	for i, z in ipairs({ -0.6, -0.2, 0.2, 0.6 }) do
		d:decor("DrawerCash", Vector3.new(0.85, 0.08, 0.34), Vector3.new(0.12, 0.14, z),
			if i % 2 == 0 then Color3.fromRGB(84, 150, 84) else Color3.fromRGB(110, 176, 100))
	end
	d:decor("DrawerCoins", Vector3.new(0.22, 0.05, 1.4), Vector3.new(-0.48, 0.12, 0), Color3.fromRGB(200, 184, 120), M.Metal)
end

--- A storefront facing -X (toward the avenue) that you can walk into: a painted signboard, a
--- striped awning, two display windows with flower boxes, an open doorway, and inside, a
--- counter with the shop's clerk behind it (DistrictService puts a person on `ClerkSpot`)
--- and the shop's own stock (`interior`: "guns" or "tactics"). The counter's prompt opens
--- the shop's panel. Origin at the front's centre on the pavement.
local function storefront(b: Kit.Builder, name: string, sub: string, colour: Color3, wall: Color3, promptName: string,
	prompt: string, depth: number, width: number, interior: string, clerk: { [string]: any })
	-- Each shop in a folder of its own: its clerk, its counter and its till go together (one
	-- clerk per folder -- with both shops loose in the district, only the first got one).
	local shop = Instance.new("Folder")
	shop.Name = name
	shop.Parent = b.parent
	b = Kit.new(shop, b.frame)
	local h = 22
	local ceil = 12.4
	local trim = lighter(wall, 0.55)
	local shellMaterial = if wall == BRICK then M.Brick else M.SmoothPlastic
	local face = darker(wall, 0.3)
	local lining = if interior == "guns" then Color3.fromRGB(196, 160, 118) else Color3.fromRGB(86, 94, 110)

	-- The shell: the storey above is solid; the ground floor is walls round a room.
	b:part("Upper", Vector3.new(depth, h - ceil, width), Vector3.new(depth / 2, (h + ceil) / 2, 0), wall, shellMaterial)
	b:part("BackWall", Vector3.new(1, ceil, width), Vector3.new(depth - 0.5, ceil / 2, 0), wall, shellMaterial)
	for _, s in ipairs({ -1, 1 }) do
		b:part("SideWall", Vector3.new(depth - 1.4, ceil, 1), Vector3.new((depth + 0.4 - 1) / 2, ceil / 2, s * (width / 2 - 0.5)),
			wall, shellMaterial)
	end
	-- The front wall is the facade itself, with the doorway and the two windows left open in it.
	local winW = width / 2 - 8
	local winZ = width / 4 + 1.5
	b:part("FrontWall", Vector3.new(1, ceil - 9.4, width), Vector3.new(-0.1, (ceil + 9.4) / 2, 0), face)
	for _, s in ipairs({ -1, 1 }) do
		b:part("FrontWall", Vector3.new(1, 1.6, width / 2 - 3.5), Vector3.new(-0.1, 0.8, s * (width / 4 + 1.75)), face)
		b:part("FrontWall", Vector3.new(1, 7.8, winZ - winW / 2 - 3.5),
			Vector3.new(-0.1, 5.5, s * (3.5 + (winZ - winW / 2 - 3.5) / 2)), face)
		b:part("FrontWall", Vector3.new(1, 7.8, width / 2 - (winZ + winW / 2)),
			Vector3.new(-0.1, 5.5, s * (winZ + winW / 2 + (width / 2 - winZ - winW / 2) / 2)), face)
	end
	-- Linings inside, a hair proud of the walls, and the ceiling.
	b:decor("Lining", Vector3.new(0.1, ceil - 0.4, width - 2.2), Vector3.new(depth - 1.06, ceil / 2, 0), lining)
	for _, s in ipairs({ -1, 1 }) do
		b:decor("Lining", Vector3.new(depth - 2.2, ceil - 0.4, 0.1), Vector3.new(depth / 2, ceil / 2, s * (width / 2 - 1.06)),
			lining)
		b:decor("Wainscot", Vector3.new(depth - 2.3, 3, 0.14), Vector3.new(depth / 2, 1.7, s * (width / 2 - 1.1)),
			darker(lining, 0.35))
	end
	b:decor("Ceiling", Vector3.new(depth - 1.8, 0.1, width - 1.8), Vector3.new(depth / 2, ceil - 0.06, 0),
		Color3.fromRGB(232, 232, 228))
	b:part("ShopFloor", Vector3.new(depth - 1, 0.2, width - 1), Vector3.new(depth / 2 - 0.5, 0.1, 0),
		Color3.fromRGB(80, 80, 84))
	for _, x in ipairs({ depth * 0.3, depth * 0.7 }) do
		for _, z in ipairs({ -width / 4, width / 4 }) do
			b:decor("LightPanel", Vector3.new(4, 0.12, 2), Vector3.new(x, ceil - 0.14, z), LAMP_GLASS)
		end
		b:light("Point", Vector3.new(x, ceil - 1.2, 0), WARM, 1.6, 26)
	end

	b:decor("Cornice", Vector3.new(depth + 0.8, 1, width + 0.8), Vector3.new(depth / 2, h - 0.6, 0), trim)
	b:decor("Parapet", Vector3.new(depth + 0.4, 1, width + 0.4), Vector3.new(depth / 2, h + 0.4, 0), darker(wall, 0.15))
	b:decor("RoofDeck", Vector3.new(depth - 1, 0.2, width - 1), Vector3.new(depth / 2, h + 0.95, 0),
		Color3.fromRGB(150, 148, 144))
	b:decor("RoofUnit", Vector3.new(5, 3, 4), Vector3.new(depth * 0.6, h + 1.6, width / 4), Color3.fromRGB(206, 208, 204),
		M.Metal)
	for _, z in ipairs({ -width / 2 + 1, width / 2 - 1 }) do
		b:decor("Pilaster", Vector3.new(0.8, h - 1, 1.6), Vector3.new(-0.9, (h - 1) / 2, z), trim)
	end
	for _, z in ipairs({ -4.6, 4.6 }) do
		b:decor("Pilaster", Vector3.new(0.8, 12.8, 1.2), Vector3.new(-0.9, 6.4, z), trim)
	end
	board(b, name, Kit.Look(Vector3.new(-1.6, 16.2, 0), Vector3.new(-10, 16.2, 0)), width - 10, 4.4, colour, CREAM)
	-- The two windows, the interior lit behind them.
	for _, z in ipairs({ -winZ, winZ }) do
		b:part("Window", Vector3.new(0.3, 7.8, winW), Vector3.new(-0.1, 5.5, z), GLASS, M.Glass,
			{ transparency = 0.55, reflectance = 0.15 })
		b:decor("Mullion", Vector3.new(0.46, 7.9, 0.3), Vector3.new(-0.1, 5.5, z), trim)
		b:decor("Sill", Vector3.new(1.4, 0.3, winW + 0.6), Vector3.new(-0.5, 1.5, z), trim)
		b:part("Display", Vector3.new(3, 1.2, winW - 2), Vector3.new(2.2, 0.8, z), WOOD, M.Wood)
		-- A flower box under the window.
		local fb = b:within(CFrame.new(-1.4, 0, z) * CFrame.Angles(0, math.rad(90), 0))
		fb:decor("FlowerBox", Vector3.new(winW, 1, 1.2), Vector3.new(0, 1.1, 0), WOOD, M.WoodPlanks)
		for x = -(winW / 2 - 0.6), winW / 2 - 0.6 + 1e-3, 1.4 do
			fb:decor("Tuft", Vector3.new(1, 0.6, 1), CFrame.new(x, 1.85, 0) * CFrame.Angles(0, math.rad(45), 0), HEDGE)
			fb:decor("Bloom", Vector3.new(0.6, 0.35, 0.6), Vector3.new(x, 2.25, 0), FLOWERS[(math.floor(x) % 2) + 1])
		end
	end
	-- The doorway: jambs and a head in the shop's colour, a mat outside.
	for _, s in ipairs({ -1, 1 }) do
		b:decor("DoorJamb", Vector3.new(1.3, 9.3, 0.5), Vector3.new(-0.1, 4.65, s * 3.7), colour)
	end
	b:decor("DoorHead", Vector3.new(1.3, 0.76, 8), Vector3.new(-0.1, 9.72, 0), colour)
	b:decor("DoorMat", Vector3.new(3, 0.08, 6), Vector3.new(-2.2, 0.04, 0), darker(colour, 0.3), M.Fabric)
	b:decor("OpenSign", Vector3.new(0.1, 0.9, 2.4), Vector3.new(-0.66, 8.4, -6.2), Color3.fromRGB(236, 70, 60))
	painted(b, "OPEN", Kit.Look(Vector3.new(-0.74, 8.4, -6.2), Vector3.new(-10, 8.4, -6.2)), 2.2, 0.7, CREAM)
	-- The awning: stripes of the shop's colour and cream, sloping out over the windows.
	local run = width - 3
	local stripes = math.max(4, math.floor(run / 2.6))
	local sw = run / stripes
	for i = 0, stripes - 1 do
		local z = -run / 2 + sw * (i + 0.5)
		b:part("Awning", Vector3.new(sw, 1.6, 4), CFrame.new(-2.6, 12.2, z) * CFrame.Angles(0, math.rad(90), 0),
			i % 2 == 0 and colour or CREAM, M.Fabric, { shape = "Wedge", collide = false })
		b:decor("AwningFlap", Vector3.new(0.2, 0.7, sw), Vector3.new(-4.6, 11.05, z), i % 2 == 0 and colour or CREAM,
			M.Fabric)
	end
	painted(b, sub, Kit.Look(Vector3.new(-1.1, 10.4, width / 2 - 4.5), Vector3.new(-10, 10.4, width / 2 - 4.5)), 6, 0.9,
		CREAM)

	-- The counter: a long run across the back third, closed off at both ends so the clerk has
	-- the space behind it to themselves.
	local cx = depth - 11
	b:part("Counter", Vector3.new(2.4, 3.6, 24), Vector3.new(cx, 1.8, 0), colour)
	b:decor("CounterTop", Vector3.new(2.9, 0.3, 24.5), Vector3.new(cx, 3.75, 0), Color3.fromRGB(64, 52, 44), M.Wood)
	b:decor("CounterKick", Vector3.new(0.1, 0.5, 23.6), Vector3.new(cx - 1.22, 0.45, 0), darker(colour, 0.4))
	for _, s in ipairs({ -1, 1 }) do
		b:part("CounterEnd", Vector3.new(depth - 1 - (cx - 1.2), 3.6, 1.2),
			Vector3.new((cx - 1.2 + depth - 1) / 2, 1.8, s * 12.6), colour)
	end
	-- The till, to rob from the customer's side of the counter.
	till(b:within(CFrame.new(cx + 0.1, 3.9, -6)), name)
	-- A cash machine inside the door, on the side wall past the window display.
	atm(b:within(CFrame.new(2.2, 0.2, -(width / 2 - 1.17)) * CFrame.Angles(0, math.rad(90), 0)), name)
	b:decor("Bell", Vector3.new(0.5, 0.35, 0.5), Vector3.new(cx - 0.5, 4.08, 4), GOLD, M.Metal, { shape = "Ball" })
	-- Where the clerk stands (DistrictService puts them there), and where you stand to be served.
	local spot = b:decor("ClerkSpot", Vector3.new(1, 0.1, 1), Vector3.new(cx + 4, 0.25, 0), colour, nil,
		{ transparency = 1 })
	for key, value in pairs(clerk) do
		spot:SetAttribute(key, value)
	end
	local counter = b:decor("Service", Vector3.new(3, 0.08, 6), Vector3.new(cx - 3, 0.28, 0), darker(colour, 0.2), M.Fabric)
	counter.Name = promptName
	counter:SetAttribute("PromptText", prompt)
	counter:SetAttribute("PromptObject", sub)

	if interior == "guns" then
		gunsInterior(b, depth, width)
	else
		tacticsInterior(b, depth, width)
	end
end

--- A job board hung on a wall that faces -Z (the builder's -Z points away from the wall):
--- a wood frame round a cork panel, a painted header, a lamp, what is pinned to it -- notes
--- for contracts, WANTED posters for bounties -- and the spot in front that opens it.
local function jobBoard(b: Kit.Builder, kind: string)
	local dark, cork = Color3.fromRGB(86, 60, 42), Color3.fromRGB(196, 146, 96)
	local bounty = kind == "bounties"
	b:decor("BoardFrame", Vector3.new(9.6, 6.6, 0.3), Vector3.new(0, 5.6, -0.17), dark, M.Wood)
	b:decor("BoardCork", Vector3.new(8.8, 5.8, 0.3), Vector3.new(0, 5.6, -0.3), cork, M.Fabric)
	board(b, if bounty then "BOUNTIES" else "CONTRACTS", Kit.Look(Vector3.new(0, 9.62, -0.62), Vector3.new(0, 9.62, -10)),
		8.8, 1.4, if bounty then Color3.fromRGB(170, 36, 40) else NAVY, if bounty then TRIM else GOLD)
	local rng = Random.new(if bounty then 91 else 77)
	if bounty then
		-- WANTED posters: a silhouette, the word, a price.
		for i = 0, 3 do
			local x = -3.1 + i * 2.07
			local tilt = CFrame.Angles(0, 0, math.rad(rng:NextNumber(-5, 5)))
			local p = b:within(CFrame.new(x, 5.4, -0.5) * tilt)
			p:decor("Poster", Vector3.new(1.8, 2.8, 0.05), Vector3.new(0, 0, 0), Color3.fromRGB(240, 222, 180))
			p:decor("PosterHead", Vector3.new(0.7, 0.7, 0.06), Vector3.new(0, 0.35, -0.03), Color3.fromRGB(46, 40, 38),
				nil, { shape = "Ball" })
			p:decor("PosterBody", Vector3.new(1.1, 0.5, 0.06), Vector3.new(0, -0.18, -0.03), Color3.fromRGB(46, 40, 38))
			p:decor("PosterBand", Vector3.new(1.6, 0.34, 0.06), Vector3.new(0, 1.05, -0.03), Color3.fromRGB(176, 40, 40))
			p:decor("PosterPrice", Vector3.new(1.2, 0.26, 0.06), Vector3.new(0, -0.9, -0.03), Color3.fromRGB(60, 120, 60))
			p:decor("Pin", Vector3.new(0.2, 0.2, 0.12), Vector3.new(0, 1.3, -0.06), RED)
		end
	else
		for i = 0, 5 do
			local x = -3 + (i % 3) * 3
			local y = 4.4 + math.floor(i / 3) * 2.4
			b:decor("Paper", Vector3.new(1.9, 1.8, 0.05), CFrame.new(x, y, -0.5)
				* CFrame.Angles(0, 0, math.rad(rng:NextNumber(-6, 6))), Color3.fromRGB(248, 242, 226))
			b:decor("PaperLines", Vector3.new(1.3, 0.8, 0.06), Vector3.new(x, y - 0.1, -0.53), Color3.fromRGB(190, 196, 210))
			b:decor("Pin", Vector3.new(0.2, 0.2, 0.12), Vector3.new(x, y + 0.7, -0.56), RED)
		end
	end
	-- A lamp over it.
	b:decor("LampArm", Vector3.new(0.2, 0.2, 1.6), Vector3.new(0, 10.95, -0.8), IRON)
	b:decor("LampShade", Vector3.new(1.6, 0.5, 1), Vector3.new(0, 10.75, -1.5), IRON)
	b:light("Spot", Kit.Look(Vector3.new(0, 10.45, -1.5), Vector3.new(0, 5.6, 0)), WARM, 1.4, 16, { Angle = 70 })
	-- Where you stand to read it: the prompt lives here.
	local spot = b:decor(if bounty then "BountyBoard" else "ContractBoard", Vector3.new(6, 0.08, 3),
		Vector3.new(0, 0.04, -2.2), Color3.fromRGB(60, 58, 56), M.Fabric)
	spot:SetAttribute("PromptText", if bounty then "View Bounties" else "View Contracts")
	spot:SetAttribute("PromptObject", if bounty then "Most Wanted" else "Daily jobs")
end

--- One fuel pump on an island, its faces toward -Z and +Z: a plinth, a white body under a red
--- head with a ZEE flash, a screen and the three grade buttons on each face, a nozzle racked
--- at each end with its hose looping down to the base.
local function pump(b: Kit.Builder)
	local white = Color3.fromRGB(240, 238, 232)
	local dark = Color3.fromRGB(30, 32, 36)
	b:part("Pump", Vector3.new(2.2, 4.4, 1.5), Vector3.new(0, 3.5, 0), white)
	b:decor("PumpPlinth", Vector3.new(2.5, 0.35, 1.8), Vector3.new(0, 1.28, 0), Color3.fromRGB(150, 152, 156), M.Concrete)
	b:decor("PumpHead", Vector3.new(2.4, 1.1, 1.66), Vector3.new(0, 6.2, 0), RED)
	b:decor("PumpCap", Vector3.new(2.5, 0.2, 1.76), Vector3.new(0, 6.85, 0), white)
	b:decor("PumpKick", Vector3.new(2.24, 0.5, 1.54), Vector3.new(0, 1.7, 0), Color3.fromRGB(196, 198, 202), M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		local face = s * 0.76
		painted(b, "ZEE", Kit.Look(Vector3.new(0, 6.2, s * 0.85), Vector3.new(0, 6.2, s * 5)), 1.6, 0.6, CREAM)
		b:decor("PumpBezel", Vector3.new(1.5, 1.0, 0.06), Vector3.new(0, 4.75, face), dark)
		b:decor("PumpScreen", Vector3.new(1.3, 0.8, 0.06), Vector3.new(0, 4.75, face + s * 0.02), Color3.fromRGB(40, 70, 64))
		painted(b, "$ 0.00", Kit.Look(Vector3.new(0, 4.78, face + s * 0.06), Vector3.new(0, 4.78, s * 5)), 1.1, 0.4,
			Color3.fromRGB(130, 236, 150), Enum.Font.Code)
		for i, colour in ipairs({ Color3.fromRGB(236, 192, 60), Color3.fromRGB(80, 180, 100), Color3.fromRGB(70, 130, 220) }) do
			b:decor("Grade", Vector3.new(0.34, 0.26, 0.06), Vector3.new((i - 2) * 0.45, 3.9, face + s * 0.01), colour)
		end
		-- The nozzle in its holster at this end, and the hose looping down from it.
		local x = s * 1.18
		b:decor("Holster", Vector3.new(0.2, 0.7, 0.6), Vector3.new(x, 3.8, 0), dark)
		b:decor("Nozzle", Vector3.new(0.26, 0.5, 0.22), CFrame.new(x + s * 0.12, 3.9, 0.25) * CFrame.Angles(0, 0, s * math.rad(20)), dark)
		local points = { Vector3.new(x + s * 0.1, 3.5, 0), Vector3.new(x + s * 0.55, 2.2, 0.2), Vector3.new(x + s * 0.35, 1.5, 0.35),
			Vector3.new(x - s * 0.05, 1.6, 0.4) }
		for k = 1, #points - 1 do
			local cf, len = Kit.Span(points[k], points[k + 1])
			b:decor("Hose", Vector3.new(0.16, 0.16, len + 0.12), cf, Color3.fromRGB(26, 26, 28), M.Rubber)
		end
	end
end

--- ZEE GAS: a canopy over two pump islands, the price pylon on the corner by the road, and the
--- life of a forecourt -- lane arrows, a car filling up, the bins and the squeegee buckets on
--- the islands, the air machine, the gas-bottle cage. Origin at the forecourt's centre; the
--- road is toward +X.
local function gasStation(b: Kit.Builder)
	local white = Color3.fromRGB(240, 238, 232)
	b:decor("Forecourt", Vector3.new(44, 0.05, 36), Vector3.new(0, 0.525, 0), Color3.fromRGB(112, 114, 120), M.Concrete)
	-- Lanes through the canopy, each with an arrow toward the road, and a few oil stains.
	for _, z in ipairs({ 0, -10.5, 10.5 }) do
		b:decor("LaneArrow", Vector3.new(3, 0.03, 0.5), Vector3.new(9.5, 0.56, z), WHITE_LINE)
		b:decor("LaneArrowHead", Vector3.new(1.3, 0.03, 1.3), CFrame.new(11.2, 0.56, z) * CFrame.Angles(0, math.rad(45), 0),
			WHITE_LINE)
	end
	for i, at in ipairs({ Vector3.new(-3, 0, -8.5), Vector3.new(4, 0, 1.5), Vector3.new(-6, 0, 9) }) do
		b:decor("OilStain", Vector3.new(2.4 + i * 0.3, 0.02, 1.6), CFrame.new(at.X, 0.555, at.Z) * CFrame.Angles(0, i, 0),
			Color3.fromRGB(92, 94, 100))
	end
	-- The canopy: white columns with red feet, a deep white roof with a red fascia, lights under.
	for _, x in ipairs({ -12, 12 }) do
		for _, z in ipairs({ -8, 8 }) do
			b:part("Column", Vector3.new(1.4, 13, 1.4), Vector3.new(x, 7, z), white)
			b:decor("ColumnBand", Vector3.new(1.5, 1.2, 1.5), Vector3.new(x, 2, z), RED)
			b:decor("ColumnGuard", Vector3.new(1.7, 0.5, 1.7), Vector3.new(x, 0.8, z), GOLD)
		end
	end
	b:part("Canopy", Vector3.new(36, 2, 26), Vector3.new(0, 14.5, 0), white)
	b:decor("CanopySoffit", Vector3.new(35.6, 0.1, 25.6), Vector3.new(0, 13.45, 0), Color3.fromRGB(226, 226, 222))
	for _, s in ipairs({ -1, 1 }) do
		b:decor("Fascia", Vector3.new(36.2, 0.8, 0.2), Vector3.new(0, 14.3, s * 13.05), RED)
		b:decor("Fascia", Vector3.new(0.2, 0.8, 26.2), Vector3.new(s * 18.05, 14.3, 0), RED)
		b:decor("FasciaStripe", Vector3.new(36.24, 0.18, 0.24), Vector3.new(0, 15.05, s * 13.05), GOLD)
		b:decor("FasciaStripe", Vector3.new(0.24, 0.18, 26.24), Vector3.new(s * 18.05, 15.05, 0), GOLD)
	end
	board(b, "ZEE GAS", Kit.Look(Vector3.new(18.6, 14.8, 0), Vector3.new(30, 14.8, 0)), 12, 1.5, RED, CREAM)
	board(b, "ZEE GAS", Kit.Look(Vector3.new(0, 14.8, -13.6), Vector3.new(0, 14.8, -30)), 12, 1.5, RED, CREAM)
	for x = -12, 12, 8 do
		for _, z in ipairs({ -6, 6 }) do
			b:decor("Downlight", Vector3.new(3, 0.1, 3), Vector3.new(x, 13.38, z), LAMP_GLASS)
		end
	end
	b:light("Spot", CFrame.new(0, 13.2, 0) * CFrame.Angles(-math.pi / 2, 0, 0), Color3.fromRGB(255, 248, 232), 1.4, 30,
		{ Angle = 150 })
	-- The pump islands: a kerbed island with yellow ends, two pumps, and between them the bin,
	-- the squeegee bucket and the paper towels.
	for _, z in ipairs({ -5, 5 }) do
		b:part("Island", Vector3.new(14, 0.6, 3), Vector3.new(0, 0.8, z), CURB)
		for _, x in ipairs({ -6.8, 6.8 }) do
			b:decor("IslandNose", Vector3.new(0.5, 0.64, 3.04), Vector3.new(x, 0.8, z), GOLD)
		end
		for _, x in ipairs({ -3.5, 3.5 }) do
			pump(b:within(CFrame.new(x, 0, z)))
		end
		b:part("IslandBin", Vector3.new(0.9, 1.5, 0.9), Vector3.new(0, 1.85, z - 0.5), Color3.fromRGB(64, 70, 78))
		b:decor("IslandBinLid", Vector3.new(1, 0.15, 1), Vector3.new(0, 2.65, z - 0.5), RED)
		b:decor("Bucket", Vector3.new(0.8, 0.7, 0.7), vertical(Vector3.new(0, 1.45, z + 0.6)), Color3.fromRGB(70, 130, 220), nil,
			{ shape = "Cylinder" })
		b:decor("Squeegee", Vector3.new(0.1, 1.4, 0.1), CFrame.new(0.15, 2.1, z + 0.6) * CFrame.Angles(0, 0, math.rad(12)),
			Color3.fromRGB(30, 30, 30))
		b:decor("TowelPost", Vector3.new(0.14, 2.4, 0.14), Vector3.new(0.6, 2.3, z + 0.8), IRON)
		b:decor("Towels", Vector3.new(0.6, 0.7, 0.4), Vector3.new(0.6, 3.6, z + 0.8), Color3.fromRGB(220, 220, 224))
		-- Round crash posts at the island's ends, standing on the forecourt.
		for _, x in ipairs({ -7.6, 7.6 }) do
			b:part("Barrier", Vector3.new(2.2, 0.6, 0.6), vertical(Vector3.new(x, 1.65, z)), GOLD, nil, { shape = "Cylinder" })
			b:decor("BarrierBand", Vector3.new(0.3, 0.64, 0.64), vertical(Vector3.new(x, 2.2, z)), Color3.fromRGB(30, 30, 34), nil,
				{ shape = "Cylinder" })
		end
	end
	-- Somebody filling up: a car at the outer pump, its tank side to the island.
	car(b:within(CFrame.new(-1, 0.55, -9.6) * CFrame.Angles(0, math.rad(-90), 0)), Color3.fromRGB(64, 110, 180), "hatch")
	-- The air and water machine by the store, and the gas bottles in their cage.
	local air = b:within(CFrame.new(-19.5, 0, 14))
	air:part("AirMachine", Vector3.new(1.6, 3.2, 1.2), Vector3.new(0, 2.1, 0), Color3.fromRGB(60, 130, 210))
	air:decor("AirTop", Vector3.new(1.7, 0.6, 1.3), Vector3.new(0, 3.9, 0), white)
	painted(air, "AIR", Kit.Look(Vector3.new(0, 3.9, -0.68), Vector3.new(0, 3.9, -5)), 1.2, 0.45, RED)
	air:decor("AirDial", Vector3.new(0.1, 0.6, 0.6), CFrame.new(0, 2.9, -0.62) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(246, 244, 238), nil, { shape = "Cylinder" })
	air:decor("AirHose", Vector3.new(0.16, 1.4, 0.16), CFrame.new(0.9, 1.6, -0.2) * CFrame.Angles(0, 0, math.rad(15)),
		Color3.fromRGB(26, 26, 28), M.Rubber)
	local cage = b:within(CFrame.new(-19.5, 0, -14) * CFrame.Angles(0, math.pi, 0))
	cage:part("BottleCage", Vector3.new(4, 3.2, 1.8), Vector3.new(0, 2.1, 0), Color3.fromRGB(190, 194, 200), M.DiamondPlate,
		{ transparency = 0.55 })
	cage:decor("CageTop", Vector3.new(4.2, 0.2, 2), Vector3.new(0, 3.8, 0), Color3.fromRGB(60, 120, 200))
	painted(cage, "GAS BOTTLES", Kit.Look(Vector3.new(0, 4.25, -0.4), Vector3.new(0, 4.25, -5)), 3, 0.5, Color3.fromRGB(60, 120, 200))
	for i = 0, 3 do
		cage:decor("Bottle", Vector3.new(1.5, 0.8, 0.8), vertical(Vector3.new(-1.35 + i * 0.9, 1.3, 0)),
			Color3.fromRGB(70, 130, 220), nil, { shape = "Cylinder" })
		cage:decor("BottleTop", Vector3.new(0.3, 0.4, 0.4), vertical(Vector3.new(-1.35 + i * 0.9, 2.2, 0)),
			Color3.fromRGB(200, 200, 204), M.Metal, { shape = "Cylinder" })
	end
	-- The price pylon on the corner by the road.
	b:part("Pylon", Vector3.new(1.4, 22, 1.4), Vector3.new(20, 11.5, -16), IRON)
	b:decor("PriceBoard", Vector3.new(1, 9, 7), Vector3.new(20, 19, -16), white)
	b:decor("PriceHead", Vector3.new(1.16, 2.6, 7.16), Vector3.new(20, 22.25, -16), RED)
	b:decor("PriceStripe", Vector3.new(1.2, 0.3, 7.2), Vector3.new(20, 20.85, -16), GOLD)
	painted(b, "ZEE", Kit.Look(Vector3.new(20.6, 22.2, -16), Vector3.new(30, 22.2, -16)), 5, 2, CREAM)
	for i, price in ipairs({ "REG  3.49", "PLUS 3.79", "PREM 4.09" }) do
		painted(b, price, Kit.Look(Vector3.new(20.55, 20.2 - i * 1.7, -16), Vector3.new(30, 20.2 - i * 1.7, -16)), 6, 1.2,
			Color3.fromRGB(40, 60, 54), Enum.Font.GothamBold)
	end
	b:decor("PylonFoot", Vector3.new(2.4, 1, 2.4), Vector3.new(20, 1, -16), CURB)
end

--- The 24/7 behind the forecourt: a store you walk into through a glass front. Shelves in
--- rows, the drinks fridges along the back, the coffee machine and the hot case, magazines in
--- the window, the counter by the door with its till and its clerk (robbable, like the shops:
--- the till is a stick-up target, the clerk puts their hands up), the ATM outside, and the
--- CONTRACTS and BOUNTIES boards on its north wall. Origin at the shop front, facing +X.
local function convenience(b: Kit.Builder)
	-- In a folder of its own, so its clerk and its till go together (StickupService.ClerkOf).
	local shop = Instance.new("Folder")
	shop.Name = "ZEE 24/7"
	shop.Parent = b.parent
	local outer = b
	b = Kit.new(shop, b.frame)
	local D, W, H = 26, 30, 14
	local ceil = 10.8
	local wall = Color3.fromRGB(240, 234, 220)
	local tile = Color3.fromRGB(236, 236, 230)
	-- The shell: a back wall, two side walls, a roof, a green fascia round the top.
	b:part("BackWall", Vector3.new(1, H, W), Vector3.new(-D + 0.5, H / 2, 0), wall)
	for _, s in ipairs({ -1, 1 }) do
		b:part("SideWall", Vector3.new(D - 1, H, 1), Vector3.new(-(D - 1) / 2, H / 2, s * (W / 2 - 0.5)), wall)
	end
	b:part("Roof", Vector3.new(D + 0.6, 1, W + 0.6), Vector3.new(-D / 2 + 0.3, H + 0.5, 0), Color3.fromRGB(196, 196, 192))
	b:decor("Roofline", Vector3.new(D + 1.2, 1.6, W + 1.2), Vector3.new(-D / 2 + 0.3, H + 0.2, 0), GREEN)
	b:decor("Stripe", Vector3.new(0.3, 0.5, W + 1.3), Vector3.new(0.95, 13.1, 0), GOLD)
	b:decor("Stripe", Vector3.new(0.3, 0.5, W + 1.3), Vector3.new(0.95, 12.4, 0), RED)
	-- The front: a head over full-height glass, the doorway open between its frames.
	b:part("FrontHead", Vector3.new(1, H - ceil, W), Vector3.new(-0.5, (H + ceil) / 2, 0), wall)
	local doorZ0, doorZ1 = 4, 10
	for _, seg in ipairs({ { -W / 2 + 1, doorZ0 }, { doorZ1, W / 2 - 1 } }) do
		local len = seg[2] - seg[1]
		local zc = (seg[1] + seg[2]) / 2
		b:part("Window", Vector3.new(0.3, ceil - 0.8, len), Vector3.new(-0.3, (ceil + 0.8) / 2, zc), GLASS, M.Glass,
			{ transparency = 0.6, reflectance = 0.15 })
		b:part("Kick", Vector3.new(0.5, 0.8, len), Vector3.new(-0.3, 0.4, zc), Color3.fromRGB(70, 74, 82))
		for z = seg[1], seg[2] + 1e-3, len / math.max(1, math.floor(len / 5)) do
			b:decor("Mullion", Vector3.new(0.5, ceil, 0.35), Vector3.new(-0.3, ceil / 2, z), Color3.fromRGB(70, 74, 82))
		end
	end
	for _, z in ipairs({ doorZ0, doorZ1 }) do
		b:decor("DoorFrame", Vector3.new(0.7, ceil, 0.5), Vector3.new(-0.3, ceil / 2, z), Color3.fromRGB(70, 74, 82))
	end
	b:decor("DoorTrack", Vector3.new(0.6, 0.6, doorZ1 - doorZ0 + 3), Vector3.new(-0.4, ceil - 0.3, (doorZ0 + doorZ1) / 2),
		Color3.fromRGB(70, 74, 82))
	-- The sliding doors, open: tucked behind the glass either side.
	for _, z in ipairs({ doorZ0 - 1.4, doorZ1 + 1.4 }) do
		b:decor("SlidingDoor", Vector3.new(0.2, ceil - 1, 2.8), Vector3.new(-0.75, (ceil - 1) / 2, z), GLASS, M.Glass,
			{ transparency = 0.5 })
	end
	b:decor("DoorMat", Vector3.new(3, 0.06, doorZ1 - doorZ0), Vector3.new(1.6, 0.03, (doorZ0 + doorZ1) / 2), Color3.fromRGB(60, 62, 68),
		M.Fabric)
	-- Posters on the glass, the name over it.
	for i, p in ipairs({ { "ICE COLD", Color3.fromRGB(60, 140, 220), -11 }, { "HOT COFFEE", RED, -5 }, { "OPEN 24H", GREEN, 12.6 } } :: { { any } }) do
		local z = p[3] :: number
		b:decor("Poster", Vector3.new(0.06, 1.6, 3.2), Vector3.new(-0.5, 7.6 - (i % 2) * 0.3, z), p[2] :: Color3)
		painted(b, p[1] :: string, Kit.Look(Vector3.new(-0.56, 7.6 - (i % 2) * 0.3, z), Vector3.new(-10, 7.6 - (i % 2) * 0.3, z)),
			2.9, 0.9, CREAM)
	end
	board(b, "ZEE 24/7", Kit.Look(Vector3.new(0.5, 12.2, -3), Vector3.new(10, 12.2, -3)), 12, 2.6, GREEN, CREAM)
	painted(b, "MARKET · COFFEE · ATM", Kit.Look(Vector3.new(1.0, 12.2, 9), Vector3.new(10, 12.2, 9)), 8, 0.8, CREAM, Enum.Font.GothamBold)

	-- Inside: the floor, the ceiling and its lights, the walls lined.
	b:part("ShopFloor", Vector3.new(D - 1, 0.2, W - 2), Vector3.new(-D / 2, 0.1, 0), tile)
	for x = -22, -2, 4 do
		b:decor("FloorLine", Vector3.new(0.1, 0.02, W - 2.2), Vector3.new(x, 0.21, 0), Color3.fromRGB(214, 214, 208))
	end
	b:decor("Ceiling", Vector3.new(D - 1.2, 0.1, W - 2.2), Vector3.new(-D / 2 - 0.1, ceil - 0.05, 0), Color3.fromRGB(246, 246, 244))
	for x = -20, -4, 8 do
		for _, z in ipairs({ -6, 4 }) do
			b:decor("LightPanel", Vector3.new(5, 0.12, 1.2), Vector3.new(x, ceil - 0.12, z), LAMP_GLASS)
		end
	end
	b:light("Point", Vector3.new(-12, ceil - 1.2, 0), Color3.fromRGB(246, 250, 255), 1.4, 28)
	for _, s in ipairs({ -1, 1 }) do
		b:decor("Lining", Vector3.new(D - 2, ceil - 0.2, 0.1), Vector3.new(-D / 2, ceil / 2, s * (W / 2 - 1.06)), Color3.fromRGB(232, 236, 230))
	end
	-- The drinks fridges along the back: glass doors on rows of bright cans and bottles.
	local fz0, fz1 = -6, W / 2 - 1.2
	b:part("Fridges", Vector3.new(2.4, 8, fz1 - fz0), Vector3.new(-D + 2.2, 4, (fz0 + fz1) / 2), Color3.fromRGB(226, 228, 232))
	local drinks = { Color3.fromRGB(220, 52, 52), Color3.fromRGB(250, 204, 44), Color3.fromRGB(40, 96, 204), Color3.fromRGB(36, 156, 92),
		Color3.fromRGB(244, 128, 34), Color3.fromRGB(236, 86, 150) }
	for k, y in ipairs({ 1.6, 3.2, 4.8, 6.4 }) do
		for j = 0, 3 do
			local z = fz0 + (j + 0.5) * (fz1 - fz0) / 4
			b:decor("Drinks", Vector3.new(0.2, 1.1, (fz1 - fz0) / 4 - 0.6), Vector3.new(-D + 3.5, y, z), drinks[(k + j) % #drinks + 1])
		end
	end
	b:decor("FridgeGlass", Vector3.new(0.15, 7, fz1 - fz0 - 0.4), Vector3.new(-D + 3.48, 4.1, (fz0 + fz1) / 2), Color3.fromRGB(200, 226, 240),
		M.Glass, { transparency = 0.6 })
	for j = 1, 3 do
		b:decor("FridgeFrame", Vector3.new(0.3, 7.2, 0.3), Vector3.new(-D + 3.55, 4.1, fz0 + j * (fz1 - fz0) / 4), Color3.fromRGB(150, 156, 164))
	end
	b:decor("FridgeSign", Vector3.new(0.2, 1.2, 8), Vector3.new(-D + 3.4, 8.9, (fz0 + fz1) / 2), Color3.fromRGB(60, 140, 220))
	painted(b, "COLD DRINKS", Kit.Look(Vector3.new(-D + 3.52, 8.9, (fz0 + fz1) / 2), Vector3.new(10, 8.9, (fz0 + fz1) / 2)), 7, 0.9, CREAM)
	-- Three rows of shelves, stocked both sides (solid: cover, if it comes to that).
	local goods = { Color3.fromRGB(240, 196, 70), Color3.fromRGB(220, 90, 70), Color3.fromRGB(90, 160, 220), Color3.fromRGB(120, 190, 100),
		Color3.fromRGB(236, 236, 230), Color3.fromRGB(200, 120, 200) }
	for r, z in ipairs({ -1.5, 4.5, 10.5 }) do
		b:part("Gondola", Vector3.new(11, 4.4, 1.6), Vector3.new(-14.5, 2.2, z), Color3.fromRGB(210, 212, 216), M.Metal)
		b:decor("GondolaCap", Vector3.new(11.2, 0.3, 1.8), Vector3.new(-14.5, 4.55, z), Color3.fromRGB(70, 160, 110))
		for k, y in ipairs({ 1, 2.3, 3.6 }) do
			for _, side in ipairs({ -1, 1 }) do
				b:decor("Goods", Vector3.new(10.4, 0.8, 0.2), Vector3.new(-14.5, y, z + side * 0.85), goods[(r + k + side) % #goods + 1])
			end
		end
	end
	-- The counter by the door: a long run with its end closed, the till on it, the coffee
	-- machine and the hot case at the far end, the shelf of smokes and lottery behind.
	local cz = -9
	b:part("Counter", Vector3.new(10, 3.6, 2.4), Vector3.new(-5.6, 1.8, cz), Color3.fromRGB(64, 120, 90))
	b:decor("CounterTop", Vector3.new(10.4, 0.3, 2.9), Vector3.new(-5.6, 3.75, cz), Color3.fromRGB(230, 226, 214))
	b:part("CounterEnd", Vector3.new(1.2, 3.6, W / 2 - 1 + cz - 1.2), Vector3.new(-11, 1.8, (cz - 1.2 - (W / 2 - 1)) / 2), Color3.fromRGB(64, 120, 90))
	till(b:within(CFrame.new(-4, 3.9, cz) * CFrame.Angles(0, math.pi / 2, 0)), "the 24/7")
	b:decor("CoffeeMachine", Vector3.new(1.4, 2.2, 1.6), Vector3.new(-9, 5, cz), Color3.fromRGB(40, 42, 48))
	b:decor("CoffeeLight", Vector3.new(0.6, 0.4, 0.1), Vector3.new(-9, 5.6, cz + 0.82), Color3.fromRGB(240, 120, 60))
	b:decor("HotCase", Vector3.new(2.4, 1.6, 1.6), Vector3.new(-1.6, 4.7, cz), Color3.fromRGB(240, 170, 90), M.Glass, { transparency = 0.2 })
	b:decor("BackShelf", Vector3.new(9, 6, 1), Vector3.new(-5.6, 5, -W / 2 + 1.6), Color3.fromRGB(110, 76, 54))
	for k, y in ipairs({ 3.4, 5, 6.6 }) do
		b:decor("Smokes", Vector3.new(8.4, 1, 0.2), Vector3.new(-5.6, y, -W / 2 + 2.2), goods[k + 2])
	end
	-- Where the clerk stands, behind the counter looking out over it at the shop.
	local spot = b:decor("ClerkSpot", Vector3.new(1, 0.1, 1), Vector3.new(-5, 0.25, -11.6), GREEN, nil, { transparency = 1 })
	spot:SetAttribute("ClerkName", "Mae")
	spot:SetAttribute("ClerkTitle", "ZEE 24/7")
	spot:SetAttribute("ClerkShirt", GREEN)
	spot:SetAttribute("ClerkFacing", b:world(CFrame.new(0, 0, 1)).Position - b:world(CFrame.new()).Position)
	-- The magazine rack in the window and a basket stack by the door.
	b:part("MagazineRack", Vector3.new(1.2, 3.2, 7), Vector3.new(-2, 1.6, 13.4 - 3.5 - 0.6), Color3.fromRGB(200, 202, 206))
	for k = 0, 2 do
		b:decor("Magazines", Vector3.new(0.2, 0.9, 6.4), Vector3.new(-1.32, 1 + k * 1, 9.3), goods[k + 1])
	end
	b:decor("Baskets", Vector3.new(1.4, 1.4, 1.8), Vector3.new(-2.2, 0.9, 2.6), RED)

	-- Outside: the ATM in the wall past the door, the ice chest, the paper stand, a bench.
	atm(outer:within(CFrame.new(0.02, 0, 14.25) * CFrame.Angles(0, math.pi, 0)), "the 24/7")
	b:part("IceChest", Vector3.new(2.4, 3.2, 4), Vector3.new(1.6, 1.6, -12.4), Color3.fromRGB(236, 242, 248))
	painted(b, "ICE", Kit.Look(Vector3.new(2.82, 2, -12.4), Vector3.new(10, 2, -12.4)), 2.4, 1, Color3.fromRGB(60, 120, 200))
	b:part("PaperStand", Vector3.new(1.4, 3, 1.6), Vector3.new(1.2, 1.5, 12), BLUE)
	b:part("BenchSeat", Vector3.new(1.6, 0.3, 5), Vector3.new(1.6, 1.6, -5), WOOD)
	for _, z in ipairs({ -7, -3 }) do
		b:decor("BenchLeg", Vector3.new(1.4, 1.5, 0.3), Vector3.new(1.6, 0.75, z), IRON)
	end
	b:part("Bin", Vector3.new(1.2, 2.4, 1.2), Vector3.new(1.4, 1.2, 2.2), Color3.fromRGB(64, 70, 78))
	b:decor("BinLid", Vector3.new(1.3, 0.2, 1.3), Vector3.new(1.4, 2.5, 2.2), GREEN)

	-- The job boards on the store's north wall, facing the cross street: CONTRACTS and
	-- BOUNTIES, side by side under their own lamps.
	jobBoard(outer:within(CFrame.new(-19, 0, 15) * CFrame.Angles(0, math.pi, 0)), "contracts")
	jobBoard(outer:within(CFrame.new(-7, 0, 15) * CFrame.Angles(0, math.pi, 0)), "bounties")
end

--- The DUEL HALL: an open-fronted sports hall facing +X, the floor split into a blue half and
--- an orange half, bleachers in each side's colour, banners and pendant lights, the pads
--- (placed by the service) on the halfway line. Origin at the front's centre.
local function duelHall(b: Kit.Builder)
	local W, D, H = 56, 64, 26
	local floorWood = Color3.fromRGB(214, 170, 118)
	local wallIn = Color3.fromRGB(232, 224, 210)
	local wallOut = Color3.fromRGB(96, 104, 126)
	local line = Color3.fromRGB(248, 246, 240)
	b:part("Floor", Vector3.new(D, 0.9, W), Vector3.new(-D / 2, 0.45, 0), floorWood, M.WoodPlanks)
	-- Each side's half painted on the boards, a white boundary round both, a halfway line.
	for _, s in ipairs({ -1, 1 }) do
		local team = s > 0 and BLUE or ORANGE
		b:decor("Half", Vector3.new(D - 16, 0.04, 14), Vector3.new(-D / 2, 0.92, s * 8.5), team:Lerp(floorWood, 0.3))
		b:decor("Line", Vector3.new(D - 15, 0.05, 0.4), Vector3.new(-D / 2, 0.93, s * 16), line)
		b:decor("Line", Vector3.new(0.4, 0.05, 32), Vector3.new(-D / 2 + s * (D / 2 - 7.5), 0.93, 0), line)
	end
	b:decor("Line", Vector3.new(D - 15, 0.05, 0.4), Vector3.new(-D / 2, 0.93, 0), line)
	-- Walls: painted slate outside, cream inside with a wood wainscot.
	b:part("Back", Vector3.new(2, H, W), Vector3.new(-D - 1, H / 2, 0), wallOut)
	b:decor("BackInside", Vector3.new(0.2, H - 1, W - 0.2), Vector3.new(-D + 0.1, H / 2, 0), wallIn)
	b:decor("Wainscot", Vector3.new(0.3, 4, W - 0.4), Vector3.new(-D + 0.15, 2.9, 0), WOOD, M.Wood)
	for _, s in ipairs({ -1, 1 }) do
		local team = s > 0 and BLUE or ORANGE
		b:part("Side", Vector3.new(D, H, 2), Vector3.new(-D / 2, H / 2, s * (W / 2 + 1)), wallOut)
		-- Outside, the long wall is dressed like a sports hall: a band in the side's colour, a
		-- row of high windows, a dark plinth, and the hall's name painted big.
		local out = s * (W / 2 + 2)
		b:decor("OuterBand", Vector3.new(D - 1, 2, 0.3), Vector3.new(-D / 2, H - 4, out + s * 0.15), team)
		b:decor("OuterPlinth", Vector3.new(D, 1.6, 0.3), Vector3.new(-D / 2, 0.8, out + s * 0.15), darker(wallOut, 0.3))
		for k = 0, 5 do
			local x = -6.5 - k * 10.2
			b:decor("HighFrame", Vector3.new(6.2, 4.2, 0.22), Vector3.new(x, H - 9.5, out + s * 0.11), CREAM)
			b:decor("HighGlass", Vector3.new(5.4, 3.4, 0.34), Vector3.new(x, H - 9.5, out + s * 0.17), WINDOW, M.Glass,
				{ reflectance = 0.15 })
		end
		local face = Vector3.new(-D / 2, 0, out + s * 0.06)
		painted(b, "DUEL HALL", Kit.Look(face + Vector3.new(0, 8.5, 0), face + Vector3.new(0, 8.5, s * 10)), 34, 5.5, CREAM,
			Enum.Font.FredokaOne)
		painted(b, "1V1  ·  STEP ON A PAD  ·  WINNER STAYS ON", Kit.Look(face + Vector3.new(0, 4.4, 0),
			face + Vector3.new(0, 4.4, s * 10)), 30, 1.6, team, Enum.Font.GothamBlack)
		b:decor("SideInside", Vector3.new(D - 0.2, H - 1, 0.2), Vector3.new(-D / 2, H / 2, s * (W / 2 - 0.1)), wallIn)
		b:decor("SideStripe", Vector3.new(D - 0.4, 1.6, 0.3), Vector3.new(-D / 2, H - 5, s * (W / 2 - 0.15)), team)
		-- The front piers either side of the opening.
		b:part("Pier", Vector3.new(3, H, 10), Vector3.new(-1.45, H / 2 + 0.02, s * (W / 2 - 4)), wallOut)
		b:decor("PierBand", Vector3.new(3.1, 1.6, 10.1), Vector3.new(-1.42, H - 5, s * (W / 2 - 4)), team)
		-- Bleachers along the side walls, stepped up toward the wall, in the side's colour.
		for row = 0, 3 do
			local seat = 1.2 * (4 - row)
			b:part("Bleacher", Vector3.new(D - 20, seat, 2.4), Vector3.new(-D / 2 - 4, 0.9 + seat / 2,
				s * (W / 2 - 1.5 - row * 2.4)), row % 2 == 0 and team or lighter(team, 0.25))
		end
		-- Banners hanging on the side walls.
		for k = 0, 2 do
			local x = -12 - k * 18
			b:decor("BannerRod", Vector3.new(4.4, 0.3, 0.3), Vector3.new(x, H - 7.4, s * (W / 2 - 0.6)), IRON)
			b:decor("Banner", Vector3.new(3.8, 7, 0.15), Vector3.new(x, H - 11, s * (W / 2 - 0.5)), team, M.Fabric)
			b:decor("BannerBand", Vector3.new(3.86, 0.6, 0.24), Vector3.new(x, H - 13, s * (W / 2 - 0.5)), CREAM, M.Fabric)
		end
	end
	b:part("Roof", Vector3.new(D + 4, 1.4, W + 4), Vector3.new(-D / 2, H + 0.7, 0), Color3.fromRGB(120, 126, 140))
	-- The roof as seen from the towers round it: a cream parapet round the edge, the court's two
	-- colours painted across it, and a skylight down the ridge.
	for _, z in ipairs({ -1, 1 }) do
		b:decor("RoofTrim", Vector3.new(D + 4.4, 0.6, 1.2), Vector3.new(-D / 2, H + 1.6, z * (W / 2 + 1.6)), CREAM)
	end
	for _, x in ipairs({ 1.6, -D - 1.6 }) do
		b:decor("RoofTrim", Vector3.new(1.2, 0.62, W + 2), Vector3.new(x, H + 1.6, 0), CREAM)
	end
	b:decor("RoofPaint", Vector3.new(D / 2 - 4, 0.05, W - 8), Vector3.new(-D / 4 + 1, H + 1.42, 0), BLUE)
	b:decor("RoofPaint", Vector3.new(D / 2 - 4, 0.05, W - 8), Vector3.new(-3 * D / 4 - 1, H + 1.42, 0), ORANGE)
	b:decor("Skylight", Vector3.new(D - 16, 0.5, 4), Vector3.new(-D / 2, H + 1.6, 0), GLASS, M.Glass, { reflectance = 0.2 })
	for _, x in ipairs({ -D * 0.3, -D * 0.7 }) do
		b:decor("RoofUnit", Vector3.new(6, 3, 5), Vector3.new(x, H + 2.88, W / 2 - 5), Color3.fromRGB(206, 208, 204), M.Metal)
	end
	-- Trusses under the roof, and a pendant light hanging from each.
	for x = -8, -D + 8, -14 do
		b:decor("Truss", Vector3.new(1, 1.2, W), Vector3.new(x, H - 0.6, 0), STEEL, M.Metal)
		for _, z in ipairs({ -10, 10 }) do
			b:decor("Cord", Vector3.new(0.12, 5, 0.12), Vector3.new(x, H - 3.7, z), IRON)
			b:decor("Shade", Vector3.new(1.2, 2.6, 2.6), vertical(Vector3.new(x, H - 6.6, z)), IRON, nil, { shape = "Cylinder" })
			b:decor("Bulb", Vector3.new(1, 1, 1), Vector3.new(x, H - 7.3, z), LAMP_GLASS, nil, { shape = "Ball" })
		end
		b:light("Spot", CFrame.new(x, H - 7.6, 0) * CFrame.Angles(-math.pi / 2, 0, 0), Color3.fromRGB(255, 244, 226),
			1.2, 34, { Angle = 110 })
	end
	-- The marquee over the opening: a painted board in a ring of bulbs.
	b:decor("Marquee", Vector3.new(2, 7, W - 4), Vector3.new(-0.5, H - 4.5, 0), NAVY)
	board(b, "DUEL HALL", Kit.Look(Vector3.new(0.7, H - 4.5, 0), Vector3.new(10, H - 4.5, 0)), W - 14, 4.4, RED, CREAM)
	for z = -W / 2 + 4, W / 2 - 4, 2.2 do
		b:decor("Bulb", Vector3.new(0.5, 0.5, 0.5), Vector3.new(0.6, H - 7.6, z), LAMP_GLASS, nil, { shape = "Ball" })
		b:decor("Bulb", Vector3.new(0.5, 0.5, 0.5), Vector3.new(0.6, H - 1.4, z), LAMP_GLASS, nil, { shape = "Ball" })
	end
	-- The big 1V1 on the back wall: blue half, orange half.
	for _, s in ipairs({ -1, 1 }) do
		b:decor("Backdrop", Vector3.new(0.3, 12, 15), Vector3.new(-D + 0.45, 14, s * 7.5), s > 0 and BLUE or ORANGE)
	end
	b:decor("BackdropFrame", Vector3.new(0.25, 12.8, 30.8), Vector3.new(-D + 0.35, 14, 0), NAVY)
	painted(b, "1V1", Kit.Look(Vector3.new(-D + 0.7, 14.6, 0), Vector3.new(0, 14.6, 0)), 20, 8.4, CREAM)
	board(b, "STAND ON A PAD TO QUEUE", Kit.Look(Vector3.new(-D + 0.7, 6.4, 0), Vector3.new(0, 6.4, 0)), 22, 1.8, NAVY,
		CREAM)
	for _, z in ipairs({ -14, 14 }) do
		b:light("Spot", Kit.Look(Vector3.new(-20, H - 2, z), Vector3.new(-26, 0, z * 0.4)), Color3.fromRGB(236, 240, 255),
			1.2, 40, { Angle = 90 })
	end
	local padSite = b:decor("PadSite", Vector3.new(1, 0.1, 1), Vector3.new(-D / 2 + 4, 0.95, 0), floorWood, nil,
		{ transparency = 1 })
	padSite.Name = "DuelPadSite"
end

--- A fenced basketball court. Origin at the court's centre; length along Z.
local function court(b: Kit.Builder)
	local L, W = 44, 26
	local courtBlue = Color3.fromRGB(64, 124, 180)
	local key = Color3.fromRGB(214, 110, 66)
	b:part("Court", Vector3.new(W + 6, 0.8, L + 6), Vector3.new(0, 0.4, 0), courtBlue)
	b:decor("Key", Vector3.new(W, 0.04, L), Vector3.new(0, 0.82, 0), key)
	local line = Color3.fromRGB(244, 244, 240)
	for _, s in ipairs({ -1, 1 }) do
		-- Key 0.84, paint 0.86, lines 0.88: each a clear step over the one under it.
		b:decor("Line", Vector3.new(0.3, 0.04, L), Vector3.new(s * W / 2, 0.86, 0), line)
		b:decor("Line", Vector3.new(W, 0.04, 0.3), Vector3.new(0, 0.86, s * L / 2), line)
		b:decor("Paint", Vector3.new(8, 0.04, 8.9), Vector3.new(0, 0.84, s * (L / 2 - 4.55)), courtBlue)
		-- Hoop: pole, arm, backboard, rim.
		local h = b:within(CFrame.new(0, 0.8, s * (L / 2 + 2)) * CFrame.Angles(0, s > 0 and 0 or math.pi, 0))
		h:part("Pole", Vector3.new(0.6, 11, 0.6), Vector3.new(0, 5.5, 0), IRON)
		h:decor("Arm", Vector3.new(0.4, 0.4, 3), Vector3.new(0, 10.6, -1.5), IRON)
		h:decor("Backboard", Vector3.new(6, 3.6, 0.2), Vector3.new(0, 10.8, -3), Color3.fromRGB(244, 244, 244), M.Glass,
			{ transparency = 0.2 })
		h:decor("Square", Vector3.new(2.4, 1.6, 0.28), Vector3.new(0, 10.2, -3.06), RED)
		h:decor("Rim", Vector3.new(0.12, 1.8, 1.8), vertical(Vector3.new(0, 9.6, -4)), ORANGE, M.Metal,
			{ shape = "Cylinder" })
	end
	b:decor("CentreCircle", Vector3.new(0.05, 7, 7), vertical(Vector3.new(0, 0.84, 0)), line, nil, { shape = "Cylinder" })
	b:decor("CentreFill", Vector3.new(0.06, 6.4, 6.4), vertical(Vector3.new(0, 0.85, 0)), key, nil, { shape = "Cylinder" })
	b:decor("CentreLine", Vector3.new(W, 0.05, 0.3), Vector3.new(0, 0.84, 0), line)
	-- Chain-link fence round it, gaps at the middle of the long sides.
	local fenceColour = Color3.fromRGB(160, 166, 170)
	local fx, fz = W / 2 + 3, L / 2 + 3
	for _, s in ipairs({ -1, 1 }) do
		b:part("Fence", Vector3.new(W + 6, 10, 0.2), Vector3.new(0, 5.8, s * fz), fenceColour, M.DiamondPlate,
			{ transparency = 0.6 })
		for _, half in ipairs({ -1, 1 }) do
			b:part("Fence", Vector3.new(0.2, 10, fz - 5), Vector3.new(s * fx, 5.8, half * (fz + 5) / 2), fenceColour,
				M.DiamondPlate, { transparency = 0.6 })
		end
		for z = -fz, fz, 8 do
			b:decor("FencePost", Vector3.new(0.3, 10.4, 0.3), Vector3.new(s * fx, 5.8, z), IRON)
		end
		b:decor("FenceRail", Vector3.new(0.3, 0.3, fz * 2), Vector3.new(s * fx, 10.9, 0), IRON)
	end
	board(b, "ZEE COURTS", Kit.Look(Vector3.new(-fx - 0.3, 8.2, -fz + 7), Vector3.new(-fx - 10, 8.2, -fz + 7)), 9, 1.8,
		TEAL, CREAM)
	-- Floodlights on two corners.
	for _, s in ipairs({ -1, 1 }) do
		b:part("LightPole", Vector3.new(0.7, 22, 0.7), Vector3.new(s * (fx + 2), 11.5, s * (fz - 2)), IRON)
		b:decor("Flood", Vector3.new(3, 1.6, 0.5), Vector3.new(s * (fx + 1.2), 22, s * (fz - 2)), LAMP_GLASS)
		b:decor("FloodHood", Vector3.new(3.2, 0.3, 1), Vector3.new(s * (fx + 1.2), 22.9, s * (fz - 2)), IRON)
		b:light("Spot", Kit.Look(Vector3.new(s * (fx + 1), 21.6, s * (fz - 2)), Vector3.new(0, 0, 0)),
			Color3.fromRGB(255, 250, 236), 1.5, 50, { Angle = 70 })
	end
end

--- An apartment block with a fire escape up its -X face to the roof, where the stash is.
--- Origin at the block's -X face centre on the pavement.
local function apartments(b: Kit.Builder)
	local W, D, H = 40, 30, 44
	local trim = lighter(BRICK, 0.55)
	b:part("Block", Vector3.new(D, H, W), Vector3.new(D / 2, H / 2, 0), BRICK, M.Brick)
	b:decor("Cornice", Vector3.new(D + 1, 1.2, W + 1), Vector3.new(D / 2, H - 0.2, 0), trim)
	b:part("Parapet", Vector3.new(D, 2.4, 1), Vector3.new(D / 2, H + 1.2, W / 2 - 0.5), darker(BRICK, 0.1), M.Brick)
	b:part("Parapet", Vector3.new(D, 2.4, 1), Vector3.new(D / 2, H + 1.2, -W / 2 + 0.5), darker(BRICK, 0.1), M.Brick)
	b:part("Parapet", Vector3.new(1, 2.4, W), Vector3.new(D - 0.5, H + 1.2, 0), darker(BRICK, 0.1), M.Brick)
	-- Windows in a grid on the -X face: glass, a few with their curtains drawn, cream sills.
	local curtains = { Color3.fromRGB(240, 222, 170), Color3.fromRGB(228, 170, 160), Color3.fromRGB(170, 200, 180) }
	for y = 6, H - 6, 8 do
		for z = -W / 2 + 4, W / 2 - 4, 6 do
			local drawn = ((y * 7 + z * 3) % 5) == 0
			b:decor("Window", Vector3.new(0.2, 3.6, 3), Vector3.new(-0.1, y, z),
				drawn and curtains[(y + z) % #curtains + 1] or GLASS, drawn and M.Fabric or M.Glass,
				{ reflectance = drawn and 0 or 0.2 })
			b:decor("Lintel", Vector3.new(0.4, 0.4, 3.4), Vector3.new(-0.2, y + 2, z), trim)
			b:decor("Sill", Vector3.new(0.5, 0.3, 3.4), Vector3.new(-0.25, y - 2, z), trim)
		end
	end
	-- The fire escape: a switchback of stairs in two columns against the wall, a landing at
	-- each end of every flight, and the last landing level with the roof. Flights alternate
	-- columns, so nobody walking up ever meets the underside of the flight above.
	local rail = Color3.fromRGB(44, 46, 50)
	local floorH = H / 5
	local END = 14
	local columns = { -6, -2 }      -- outer, inner
	for level = 1, 5 do
		local y = level * floorH
		local e = level % 2 == 1 and -END or END
		b:part("Landing", Vector3.new(8, 0.4, 5), Vector3.new(-4, y - 0.2, e + math.sign(e) * 1.5), rail, M.DiamondPlate)
		local zc = e + math.sign(e) * 1.5
		b:decor("LandingRail", Vector3.new(0.2, 0.2, 5), Vector3.new(-8, y + 3, zc), rail, M.Metal)
		b:decor("LandingRail", Vector3.new(8, 0.2, 0.2), Vector3.new(-4, y + 3, e + math.sign(e) * 4), rail, M.Metal)
		for _, px in ipairs({ -8, -4 }) do
			b:decor("RailPost", Vector3.new(0.18, 3, 0.18), Vector3.new(px, y + 1.5, e + math.sign(e) * 4), rail, M.Metal)
		end
		b:part("RailGuard", Vector3.new(0.2, 3, 5), Vector3.new(-8, y + 1.5, zc), rail, nil,
			{ transparency = 1, query = false, shadow = false })
	end
	for level = 0, 4 do
		local fromE = level % 2 == 0 and END or -END
		local toE = -fromE
		local x = columns[level % 2 + 1]
		local a = Vector3.new(x, level * floorH, fromE)
		local c = Vector3.new(x, (level + 1) * floorH, toE)
		local cf, len = Kit.Span(a, c)
		b:part("Stair", Vector3.new(3.6, 0.4, len + 0.6), cf * CFrame.new(0, -0.2, 0), rail, M.DiamondPlate)
		-- Treads drawn across it, so it reads as steps.
		local steps = math.floor(len / 1.4)
		for i = 1, steps - 1 do
			local p = a:Lerp(c, i / steps)
			b:decor("Tread", Vector3.new(3.6, 0.12, 0.25), CFrame.new(p) * (cf - cf.Position), Color3.fromRGB(74, 74, 80), M.Metal)
		end
		local rcf, rlen = Kit.Span(a + Vector3.new(x < -4 and -1.8 or 1.8, 3, 0), c + Vector3.new(x < -4 and -1.8 or 1.8, 3, 0))
		b:decor("StairRail", Vector3.new(0.15, 0.15, rlen), rcf, rail, M.Metal)
	end
	-- Uprights holding it to the wall.
	for _, z in ipairs({ -END - 3, 0, END + 3 }) do
		b:decor("Upright", Vector3.new(0.3, H, 0.3), Vector3.new(-8, H / 2, z), rail, M.Metal)
	end
	-- The rooftop: a water tank, a dish, and the stash crate with a lamp over it.
	b:decor("Tank", Vector3.new(6, 6, 6), vertical(Vector3.new(D - 8, H + 3, -W / 2 + 8)), Color3.fromRGB(150, 104, 66),
		M.WoodPlanks, { shape = "Cylinder" })
	b:decor("TankCap", Vector3.new(0.8, 6.4, 6.4), vertical(Vector3.new(D - 8, H + 6.4, -W / 2 + 8)), IRON, nil,
		{ shape = "Cylinder" })
	b:decor("DishMast", Vector3.new(0.3, 2.4, 0.3), Vector3.new(D - 6, H + 1.4, W / 2 - 6), IRON)
	b:decor("Dish", Vector3.new(0.4, 3, 3), CFrame.new(D - 6, H + 2.6, W / 2 - 6) * CFrame.Angles(0, 0, math.rad(60)),
		Color3.fromRGB(236, 236, 232), nil, { shape = "Cylinder" })
	local stash = b:part("RooftopStash", Vector3.new(4, 3, 3), Vector3.new(D / 2, H + 1.5, 0), Color3.fromRGB(96, 108, 66),
		M.Metal)
	stash:SetAttribute("PromptText", "Search")
	stash:SetAttribute("PromptObject", "Rooftop Stash")
	b:decor("StashLid", Vector3.new(4.2, 0.4, 3.2), Vector3.new(D / 2, H + 3.2, 0), Color3.fromRGB(64, 72, 44), M.Metal)
	b:decor("StashBand", Vector3.new(4.1, 0.5, 3.1), Vector3.new(D / 2, H + 1.6, 0), GOLD)
	b:decor("StashLamp", Vector3.new(0.7, 0.7, 0.7), Vector3.new(D / 2, H + 3.8, 0), LAMP_GLASS, nil, { shape = "Ball" })
	b:light("Point", Vector3.new(D / 2, H + 4.5, 0), WARM, 1.2, 16)
end

--- THE PENTHOUSE, on the roof of ZEE TOWER: the Don's floor, and the arena for the fight with
--- him. A black-marble deck well wider than the shaft all round (112 x 84), edged in gold and
--- glass. Laid out for a gunfight first and a penthouse second: an open ring of floor all the
--- way round, with cover in it rather than walls --
---
---   front    an infinity pool along the edge looking down the avenue, a terrace of loungers
---   middle   a glass-roofed pavilion on gold columns over the Don's lounge (a U of low sofas,
---            a table of money) and his desk under a chandelier
---   flanks   the bar down the east edge, the grand piano by the glass on the west, marble
---            planters with hedges -- waist-high things to fight round
---   back     a short feature wall with the gold Z and the vault, open at both ends, the
---            helipad (the Don's helicopter is `DonHeli`) and the elevator you arrive by
---
--- Four pylons carry the crown and the spire over it all. The only walls you cannot see are at
--- the very edge of the deck (and a lid): nothing invisible stands anywhere on the floor.
---
--- Origin at the middle of the roof, on the roof; -Z toward the avenue. The deck's top is y 1.
local function penthouse(b: Kit.Builder)
	local W, D = 112, 84
	local HW_, HD = W / 2, D / 2
	local marble = Color3.fromRGB(34, 32, 40)
	local marbleLight = Color3.fromRGB(236, 232, 226)
	local gold = Color3.fromRGB(236, 184, 64)
	local deckTop = 1
	b:part("PenthouseDeck", Vector3.new(W, 2, D), Vector3.new(0, 0, 0), marble, M.Marble)
	-- Gold inlay across the floor, and a gold band round the deck's edge.
	for x = -48, 48, 12 do
		b:decor("Inlay", Vector3.new(0.3, 0.04, D - 2), Vector3.new(x, deckTop + 0.02, 0), gold, M.Metal)
	end
	for z = -36, 36, 12 do
		b:decor("Inlay", Vector3.new(W - 2, 0.04, 0.3), Vector3.new(0, deckTop + 0.03, z), gold, M.Metal)
	end
	-- The underside, as the street sees it: a cream soffit with a ring of lamps round its edge.
	b:decor("Soffit", Vector3.new(W - 0.4, 0.1, D - 0.4), Vector3.new(0, -1.06, 0), Color3.fromRGB(236, 226, 206))
	for x = -HW_ + 4, HW_ - 4 + 1e-3, 8 do
		for _, s in ipairs({ -1, 1 }) do
			b:decor("SoffitLamp", Vector3.new(0.8, 0.2, 0.8), Vector3.new(x, -1.2, s * (HD - 1.2)), LAMP_GLASS)
		end
	end
	for z = -HD + 6, HD - 6 + 1e-3, 8 do
		for _, s in ipairs({ -1, 1 }) do
			b:decor("SoffitLamp", Vector3.new(0.8, 0.2, 0.8), Vector3.new(s * (HW_ - 1.2), -1.2, z), LAMP_GLASS)
		end
	end
	for _, at in ipairs({ Vector3.new(-36, -3, -34), Vector3.new(36, -3, -34), Vector3.new(0, -3, -38) }) do
		b:light("Point", at, WARM, 1.1, 24)
	end
	for _, s in ipairs({ -1, 1 }) do
		b:decor("Fascia", Vector3.new(W + 0.3, 0.6, 0.2), Vector3.new(0, 0.2, s * (HD + 0.05)), gold, M.Metal)
		b:decor("Fascia", Vector3.new(0.2, 0.6, D + 0.3), Vector3.new(s * (HW_ + 0.05), 0.2, 0), gold, M.Metal)
		-- Struts carrying the cantilevers: from the shaft's sides out to the deck's side edges,
		-- and from its front and back out to the deck's front and back.
		for _, z in ipairs({ -16, 0, 16 }) do
			local cf, len = Kit.Span(Vector3.new(s * 30, -12, z), Vector3.new(s * (HW_ - 1), -1, z))
			b:decor("Strut", Vector3.new(0.9, 0.9, len), cf, gold, M.Metal)
		end
		for _, x in ipairs({ -24, 0, 24 }) do
			local cf, len = Kit.Span(Vector3.new(x, -12, s * 20), Vector3.new(x, -1, s * (HD - 1)))
			b:decor("Strut", Vector3.new(0.9, 0.9, len), cf, gold, M.Metal)
		end
	end

	-- The glass balustrade round the edge, gold posts and a gold rail on top.
	local rail = 3.6
	for _, s in ipairs({ -1, 1 }) do
		b:part("Balustrade", Vector3.new(W - 1.2, rail, 0.3), Vector3.new(0, deckTop + rail / 2, s * (HD - 0.6)), GLASS,
			M.Glass, { transparency = 0.6, reflectance = 0.1 })
		b:part("Balustrade", Vector3.new(0.3, rail, D - 1.8), Vector3.new(s * (HW_ - 0.6), deckTop + rail / 2, 0), GLASS,
			M.Glass, { transparency = 0.6, reflectance = 0.1 })
		b:decor("HandRail", Vector3.new(W - 0.9, 0.3, 0.5), Vector3.new(0, deckTop + rail + 0.15, s * (HD - 0.6)), gold,
			M.Metal)
		b:decor("HandRail", Vector3.new(0.5, 0.3, D - 1.5), Vector3.new(s * (HW_ - 0.6), deckTop + rail + 0.16, 0), gold,
			M.Metal)
		for x = -HW_ + 0.6, HW_ - 0.6 + 1e-3, 8 do
			b:decor("RailPost", Vector3.new(0.45, rail, 0.45), Vector3.new(x, deckTop + rail / 2, s * (HD - 0.6)), gold,
				M.Metal)
		end
		for z = -HD + 0.6, HD - 0.6 + 1e-3, 8 do
			b:decor("RailPost", Vector3.new(0.45, rail, 0.45), Vector3.new(s * (HW_ - 0.6), deckTop + rail / 2, z), gold,
				M.Metal)
		end
	end
	-- Nobody leaves by the edge: invisible walls just outside the rail, and a lid. These are
	-- the ONLY invisible walls up here (TowerService and tools/uitest/tower.luau hold that).
	for _, s in ipairs({ -1, 1 }) do
		b:part("TowerBound", Vector3.new(W + 2, 50, 1), Vector3.new(0, deckTop + 25, s * (HD + 0.5)), gold, nil,
			{ transparency = 1, query = false, shadow = false })
		b:part("TowerBound", Vector3.new(1, 50, D + 2), Vector3.new(s * (HW_ + 0.5), deckTop + 25, 0), gold, nil,
			{ transparency = 1, query = false, shadow = false })
	end
	b:part("TowerBound", Vector3.new(W + 2, 1, D + 2), Vector3.new(0, deckTop + 50.5, 0), gold, nil,
		{ transparency = 1, query = false, shadow = false })

	-- The infinity pool along the front edge, looking down the avenue.
	local pool = b:within(CFrame.new(0, deckTop, -HD + 7.4))
	pool:decor("PoolTile", Vector3.new(72, 0.04, 6.4), Vector3.new(0, 0.09, 0), Color3.fromRGB(120, 206, 230))
	pool:decor("PoolWater", Vector3.new(72, 0.1, 6.4), Vector3.new(0, 0.56, 0), Color3.fromRGB(70, 180, 226), M.Glass,
		{ transparency = 0.35, reflectance = 0.2 })
	for _, s in ipairs({ -1, 1 }) do
		pool:part("PoolRim", Vector3.new(73.6, 0.7, 0.8), Vector3.new(0, 0.35, s * 3.6), marbleLight, M.Marble)
		pool:part("PoolRim", Vector3.new(0.8, 0.7, 6.4), Vector3.new(s * 36.4, 0.35, 0), marbleLight, M.Marble)
	end
	b:light("Point", Vector3.new(0, deckTop + 0.4, -HD + 7.4), Color3.fromRGB(120, 210, 255), 1.4, 30)

	-- The terrace: loungers facing the view in pairs, a gold umbrella over each pair. Low
	-- enough to shoot over, solid enough to duck behind.
	for _, pair in ipairs({ -38, -22, 22, 38 }) do
		for i, dx in ipairs({ -2.2, 2.2 }) do
			local l = b:within(CFrame.new(pair + dx, deckTop, -24))
			l:part("Lounger", Vector3.new(2.4, 0.9, 6), Vector3.new(0, 0.65, 0), marbleLight)
			l:decor("LoungerBack", Vector3.new(2.4, 0.4, 2.6), CFrame.new(0, 1.6, 2.2) * CFrame.Angles(math.rad(35), 0, 0),
				marbleLight)
			l:decor("Towel", Vector3.new(1.8, 0.06, 3), Vector3.new(0, 1.13, -0.8), if i == 1 then gold else TEAL, M.Fabric)
		end
		local u = b:within(CFrame.new(pair, deckTop, -21))
		u:decor("UmbrellaPole", Vector3.new(0.25, 7, 0.25), Vector3.new(0, 3.5, 0), gold, M.Metal)
		u:decor("Umbrella", Vector3.new(1.2, 7.4, 7.4), CFrame.new(0, 7.2, 0) * CFrame.Angles(0, 0, math.rad(90)), CREAM,
			M.Fabric, { shape = "Cylinder" })
		u:decor("UmbrellaTrim", Vector3.new(0.3, 7.6, 7.6), CFrame.new(0, 6.6, 0) * CFrame.Angles(0, 0, math.rad(90)),
			gold, M.Fabric, { shape = "Cylinder" })
	end

	-- The pavilion: a glass roof on gold columns; the four corner columns run on up as the
	-- crown's pylons. Columns are the only things inside it taller than a sofa, so it is a
	-- room you can see and shoot across.
	local roofY = deckTop + 15
	local PZ = 2 -- the pavilion's middle
	for _, x in ipairs({ -24, -8, 8, 24 }) do
		for _, z in ipairs({ PZ - 12, PZ + 12 }) do
			local corner = math.abs(x) > 20
			local height = if corner then 40 else roofY - deckTop
			b:part("Column", Vector3.new(height, 1.6, 1.6), CFrame.new(x, deckTop + height / 2, z)
				* CFrame.Angles(0, 0, math.rad(90)), marbleLight, M.Marble, { shape = "Cylinder" })
			b:decor("ColumnBase", Vector3.new(2.4, 0.8, 2.4), Vector3.new(x, deckTop + 0.4, z), gold, M.Metal)
			b:decor("ColumnCap", Vector3.new(2.4, 0.8, 2.4), Vector3.new(x, roofY - 0.4, z), gold, M.Metal)
			b:light("Spot", Kit.Look(Vector3.new(x, deckTop + 1, z - 1.4), Vector3.new(x, roofY, z - 1.4)), WARM, 1, 16,
				{ Angle = 35 })
		end
	end
	b:decor("GlassRoof", Vector3.new(50, 0.3, 26), Vector3.new(0, roofY + 0.3, PZ), Color3.fromRGB(190, 220, 236), M.Glass,
		{ transparency = 0.55, reflectance = 0.2 })
	for _, z in ipairs({ PZ - 12, PZ, PZ + 12 }) do
		b:decor("RoofBeam", Vector3.new(50.6, 0.6, 0.5), Vector3.new(0, roofY + 0.1, z), gold, M.Metal)
	end
	for _, x in ipairs({ -24, -8, 8, 24 }) do
		b:decor("RoofBeam", Vector3.new(0.5, 0.6, 24.5), Vector3.new(x, roofY + 0.11, PZ), gold, M.Metal)
	end
	-- The chandelier over the lounge.
	local ch = b:within(CFrame.new(-12, roofY - 3.2, PZ))
	ch:decor("ChandelierChain", Vector3.new(0.15, 2.6, 0.15), Vector3.new(0, 1.9, 0), gold, M.Metal)
	for i, r in ipairs({ 3, 2 }) do
		ch:decor("ChandelierRing", Vector3.new(0.25, r * 2, r * 2), CFrame.new(0, -i * 0.7, 0)
			* CFrame.Angles(0, 0, math.rad(90)), gold, M.Metal, { shape = "Cylinder" })
		for k = 0, 7 do
			local a = k * math.pi / 4
			ch:decor("Crystal", Vector3.new(0.5, 0.5, 0.5), Vector3.new(math.cos(a) * r, -i * 0.7 - 0.45, math.sin(a) * r),
				LAMP_GLASS, M.Glass, { shape = "Ball", transparency = 0.1 })
		end
	end
	ch:light("Point", Vector3.new(0, -1.6, 0), WARM, 2, 34)

	-- The lounge: a U of low white sofas round a table of money, open toward the front.
	local lounge = b:within(CFrame.new(-13, deckTop, PZ + 2))
	lounge:decor("Rug", Vector3.new(12.4, 0.06, 11), Vector3.new(0, 0.06, 0), Color3.fromRGB(150, 36, 44), M.Fabric)
	for _, spec in ipairs({ { Vector3.new(10, 1.6, 2.2), Vector3.new(0, 0.8, 4.6) }, { Vector3.new(2.2, 1.6, 8), Vector3.new(-5.4, 0.8, 0.4) },
		{ Vector3.new(2.2, 1.6, 8), Vector3.new(5.4, 0.8, 0.4) } }) do
		lounge:part("Sofa", spec[1], spec[2], marbleLight, M.Fabric)
	end
	lounge:decor("SofaBack", Vector3.new(10, 1.4, 0.8), Vector3.new(0, 2.3, 5.4), marbleLight, M.Fabric)
	lounge:part("CoffeeTable", Vector3.new(4.4, 1.1, 3), Vector3.new(0, 0.55, 0), Color3.fromRGB(20, 20, 24), M.Marble)
	for k = 0, 4 do
		lounge:decor("CashStack", Vector3.new(0.9, 0.35 + (k % 2) * 0.2, 0.45), Vector3.new(-1.6 + k * 0.8, 1.3, -0.3 + (k % 2) * 0.6),
			Color3.fromRGB(110, 170, 96))
	end
	lounge:decor("Briefcase", Vector3.new(1.6, 0.5, 1.1), Vector3.new(1.4, 1.35, 0.7), Color3.fromRGB(40, 30, 26))

	-- The Don's desk, facing the front, under the glass.
	local desk = b:within(CFrame.new(10, deckTop, PZ + 8))
	desk:part("Desk", Vector3.new(9, 3, 3.4), Vector3.new(0, 1.5, 0), Color3.fromRGB(62, 36, 24), M.Wood)
	desk:decor("DeskTop", Vector3.new(9.4, 0.25, 3.8), Vector3.new(0, 3.1, 0), Color3.fromRGB(20, 18, 20), M.Marble)
	desk:decor("DeskLamp", Vector3.new(0.9, 1.4, 0.9), Vector3.new(-3.4, 3.9, 0.6), gold, M.Metal)
	desk:decor("Globe", Vector3.new(1.2, 1.2, 1.2), Vector3.new(3.4, 3.85, 0.4), Color3.fromRGB(60, 120, 170), nil,
		{ shape = "Ball" })
	desk:part("DeskChair", Vector3.new(2.4, 5, 2.4), Vector3.new(0, 2.5, 2.8), Color3.fromRGB(120, 30, 36), M.Fabric)

	-- The grand piano, lid up, by the glass on the west side.
	local piano = b:within(CFrame.new(-44, deckTop, 10) * CFrame.Angles(0, math.rad(70), 0))
	piano:part("Piano", Vector3.new(4.6, 1.6, 6), Vector3.new(0, 2.6, 0), Color3.fromRGB(14, 14, 18))
	piano:decor("PianoLid", Vector3.new(4.4, 0.15, 5.6), CFrame.new(0.6, 4.2, 0) * CFrame.Angles(0, 0, math.rad(32)),
		Color3.fromRGB(20, 20, 26))
	piano:decor("Keys", Vector3.new(4, 0.2, 1), Vector3.new(0, 3.2, -3.4), CREAM)
	for _, at in ipairs({ Vector3.new(-1.8, 0.9, -2.4), Vector3.new(1.8, 0.9, -2.4), Vector3.new(0, 0.9, 2.4) }) do
		piano:decor("PianoLeg", Vector3.new(0.4, 1.8, 0.4), at, Color3.fromRGB(14, 14, 18))
	end
	piano:part("PianoBench", Vector3.new(3, 1.4, 1.2), Vector3.new(0, 0.7, -5), Color3.fromRGB(14, 14, 18))

	-- The bar down the east edge, bottles on a mirrored shelf behind it: a long counter to fight
	-- along, with the shelf against the glass.
	local bar = b:within(CFrame.new(46, deckTop, 4))
	bar:part("Bar", Vector3.new(2.2, 3.6, 16), Vector3.new(0, 1.8, 0), Color3.fromRGB(26, 24, 30), M.Marble)
	bar:decor("BarTop", Vector3.new(2.6, 0.3, 16.4), Vector3.new(0, 3.75, 0), gold, M.Metal)
	bar:part("BarShelf", Vector3.new(0.6, 6.4, 16), Vector3.new(6.4, 3.2, 0), Color3.fromRGB(26, 24, 30), M.Marble)
	bar:decor("BarMirror", Vector3.new(0.2, 4.4, 15), Vector3.new(6.05, 4.4, 0), Color3.fromRGB(150, 170, 186), M.Glass,
		{ reflectance = 0.3 })
	for k = 0, 13 do
		bar:decor("Bottle", Vector3.new(0.4, 1.1, 0.4), Vector3.new(5.8, 2.6 + (k % 2) * 2.2, -7 + k * 1.08),
			({ Color3.fromRGB(60, 120, 60), Color3.fromRGB(150, 90, 40), Color3.fromRGB(200, 200, 210),
				Color3.fromRGB(140, 30, 40) })[k % 4 + 1], M.Glass, { transparency = 0.2 })
	end
	for _, z in ipairs({ -5, 0, 5 }) do
		bar:decor("Stool", Vector3.new(1.3, 0.3, 1.3), Vector3.new(-2.2, 2.6, z), gold, M.Metal, { shape = "Cylinder" })
		bar:decor("StoolLeg", Vector3.new(0.2, 2.4, 0.2), Vector3.new(-2.2, 1.2, z), gold, M.Metal)
	end

	-- Marble planters with clipped hedges: waist-high cover across both flanks.
	for _, at in ipairs({ Vector3.new(-32, 0, -10), Vector3.new(32, 0, -10), Vector3.new(-30, 0, 24),
		Vector3.new(30, 0, 18) }) do
		local pl = b:within(CFrame.new(at.X, deckTop, at.Z))
		pl:part("Planter", Vector3.new(7, 2.2, 2.6), Vector3.new(0, 1.1, 0), marbleLight, M.Marble)
		pl:decor("PlanterTrim", Vector3.new(7.3, 0.3, 2.9), Vector3.new(0, 2.25, 0), gold, M.Metal)
		pl:decor("Hedge", Vector3.new(6.4, 1.2, 2), Vector3.new(0, 2.9, 0), HEDGE, M.Grass)
	end

	-- The feature wall: marble, the gold Z in a ring, the vault. Short enough to run round at
	-- both ends, so the back of the roof is never cut off from the front.
	local wall = b:within(CFrame.new(0, deckTop, 24))
	wall:part("FeatureWall", Vector3.new(30, 13, 1.4), Vector3.new(0, 6.5, 0), marbleLight, M.Marble)
	wall:decor("WallTrim", Vector3.new(30.4, 0.6, 1.6), Vector3.new(0, 13.1, 0), gold, M.Metal)
	wall:decor("ZRing", Vector3.new(0.2, 9, 9), CFrame.new(-6, 7, -0.75) * CFrame.Angles(0, math.rad(90), 0), gold, M.Metal,
		{ shape = "Cylinder" })
	wall:decor("ZDisc", Vector3.new(0.2, 8, 8), CFrame.new(-6, 7, -0.8) * CFrame.Angles(0, math.rad(90), 0), marble, M.Marble,
		{ shape = "Cylinder" })
	painted(wall, "Z", Kit.Look(Vector3.new(-6, 7, -0.95), Vector3.new(-6, 7, -10)), 6, 6.4, gold)
	painted(wall, "THE PENTHOUSE", Kit.Look(Vector3.new(-6, 1.6, -0.76), Vector3.new(-6, 1.6, -10)), 10, 1, gold)
	wall:decor("Vault", Vector3.new(0.5, 7, 7), CFrame.new(8, 5.2, -0.9) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(150, 156, 164), M.DiamondPlate, { shape = "Cylinder" })
	wall:decor("VaultRim", Vector3.new(0.3, 7.8, 7.8), CFrame.new(8, 5.2, -0.75) * CFrame.Angles(0, math.rad(90), 0), gold,
		M.Metal, { shape = "Cylinder" })
	for k = 0, 2 do
		wall:decor("VaultSpoke", Vector3.new(4.6, 0.35, 0.3),
			CFrame.new(8, 5.2, -1.25) * CFrame.Angles(0, 0, k * math.pi / 3), gold, M.Metal)
	end
	wall:decor("VaultHub", Vector3.new(0.4, 1.2, 1.2), CFrame.new(8, 5.2, -1.3) * CFrame.Angles(0, math.rad(90), 0), gold,
		M.Metal, { shape = "Cylinder" })

	-- Palms in gold planters at the four corners of the floor.
	for _, at in ipairs({ Vector3.new(-50, 0, -14), Vector3.new(50, 0, -14), Vector3.new(-50, 0, 28),
		Vector3.new(50, 0, 30) }) do
		local palm = b:within(CFrame.new(at.X, deckTop, at.Z))
		palm:part("Planter", Vector3.new(4, 2.2, 4), Vector3.new(0, 1.1, 0), gold, M.Metal)
		palm:decor("PlanterSoil", Vector3.new(3.6, 0.1, 3.6), Vector3.new(0, 2.2, 0), SOIL)
		for k = 0, 4 do
			palm:decor("PalmTrunk", Vector3.new(0.9 - k * 0.08, 1.6, 0.9 - k * 0.08),
				CFrame.new(k * 0.18, 3 + k * 1.5, 0) * CFrame.Angles(0, 0, math.rad(-4)), BARK, M.Wood)
		end
		for k = 0, 5 do
			local a = k * math.pi / 3
			palm:decor("Frond", Vector3.new(1.4, 0.3, 5),
				CFrame.new(0.9, 10.2, 0) * CFrame.Angles(0, a, 0) * CFrame.new(0, 0, -2.3) * CFrame.Angles(math.rad(-22), 0, 0),
				HEDGE, M.Grass)
		end
	end

	-- The helipad in the back corner, and the Don's helicopter on it.
	local pad = b:within(CFrame.new(24, deckTop, 34))
	pad:part("Helipad", Vector3.new(30, 0.4, 12), Vector3.new(0, 0.2, 0), Color3.fromRGB(46, 50, 58))
	pad:decor("PadEdge", Vector3.new(30.2, 0.06, 12.2), Vector3.new(0, 0.43, 0), Color3.fromRGB(250, 204, 60))
	pad:decor("PadInner", Vector3.new(29, 0.06, 11.2), Vector3.new(0, 0.47, 0), Color3.fromRGB(46, 50, 58))
	pad:decor("PadH", Vector3.new(0.8, 0.06, 5), Vector3.new(-2, 0.53, 0), CREAM)
	pad:decor("PadH", Vector3.new(0.8, 0.06, 5), Vector3.new(2, 0.53, 0), CREAM)
	pad:decor("PadH", Vector3.new(4, 0.06, 0.8), Vector3.new(0, 0.545, 0), CREAM)
	local heli = pad:folder("DonHeli")
	heli:decor("HeliBody", Vector3.new(9, 4, 4.4), Vector3.new(0, 2.8, 0), Color3.fromRGB(22, 22, 26))
	heli:decor("HeliNose", Vector3.new(3, 3, 4.2), CFrame.new(-6, 2.6, 0) * CFrame.Angles(0, math.rad(-90), 0),
		Color3.fromRGB(22, 22, 26), nil, { shape = "Wedge" })
	heli:decor("HeliGlass", Vector3.new(2.4, 2.2, 4.3), Vector3.new(-4.6, 3.2, 0), Color3.fromRGB(110, 160, 196), M.Glass,
		{ transparency = 0.3 })
	heli:decor("HeliStripe", Vector3.new(9.1, 0.5, 4.5), Vector3.new(0, 2.2, 0), gold)
	heli:decor("HeliTail", Vector3.new(10, 1, 1), Vector3.new(9.4, 3.6, 0), Color3.fromRGB(22, 22, 26))
	heli:decor("HeliFin", Vector3.new(1.6, 3, 0.3), Vector3.new(14, 4.7, 0), gold)
	heli:decor("HeliMast", Vector3.new(0.6, 1.2, 0.6), Vector3.new(0, 5.4, 0), STEEL, M.Metal)
	for k = 0, 1 do
		heli:decor("Rotor", Vector3.new(22, 0.2, 0.8), CFrame.new(0, 6.1, 0) * CFrame.Angles(0, k * math.pi / 2, 0),
			Color3.fromRGB(40, 40, 44), M.Metal)
	end
	for _, z in ipairs({ -1.8, 1.8 }) do
		heli:decor("Skid", Vector3.new(8, 0.3, 0.3), Vector3.new(0, 0.6, z), STEEL, M.Metal)
	end

	-- The elevator you come up in, and leave by, in the other back corner -- facing straight
	-- down the roof at the pavilion, nothing in the way.
	local lift = b:within(CFrame.new(-42, deckTop, 36))
	lift:part("ElevatorCore", Vector3.new(12, 13, 8), Vector3.new(0, 6.5, 0), marbleLight, M.Marble)
	lift:decor("ElevatorTrim", Vector3.new(12.4, 0.6, 8.4), Vector3.new(0, 13.1, 0), gold, M.Metal)
	lift:decor("ElevatorFrame", Vector3.new(6.4, 9.4, 0.4), Vector3.new(0, 4.7, -4.1), gold, M.Metal)
	for _, x in ipairs({ -1.4, 1.4 }) do
		lift:decor("ElevatorDoor", Vector3.new(2.7, 8.6, 0.2), Vector3.new(x, 4.3, -4.35), Color3.fromRGB(210, 170, 90),
			M.Metal, { reflectance = 0.2 })
	end
	painted(lift, "88", Kit.Look(Vector3.new(0, 10.2, -4.45), Vector3.new(0, 10.2, -10)), 2.4, 1.2, gold)
	local arrive = lift:decor("TowerArrival", Vector3.new(4, 0.06, 3), Vector3.new(0, 0.04, -9), marble, nil,
		{ transparency = 1 })
	arrive:SetAttribute("Facing", "-Z")
	local leave = lift:decor("TowerExit", Vector3.new(5, 0.08, 2.4), Vector3.new(0, 0.05, -5.6), gold, M.Fabric)
	leave:SetAttribute("PromptText", "Take the elevator down")
	leave:SetAttribute("PromptObject", "Leave ZEE TOWER")
	-- Where the Don stands to start with (in front of the pavilion), and where his people come
	-- from: the elevator, the helipad, both flanks and the terrace.
	b:decor("TowerBossSpot", Vector3.new(2, 0.06, 2), Vector3.new(0, deckTop + 0.04, -6), marble, nil, { transparency = 1 })
	for i, at in ipairs({ Vector3.new(-42, 0, 24), Vector3.new(24, 0, 26), Vector3.new(44, 0, -16), Vector3.new(-44, 0, -16),
		Vector3.new(0, 0, -18) }) do
		local spot = b:decor("TowerAddSpot", Vector3.new(2, 0.06, 2), at + Vector3.new(0, deckTop + 0.04, 0), marble, nil,
			{ transparency = 1 })
		spot:SetAttribute("Order", i)
	end

	-- The crown: the four corner columns carry a gold frame, and the spire rises out of it.
	local crownY = deckTop + 40
	for _, s in ipairs({ -1, 1 }) do
		b:decor("CrownBeam", Vector3.new(50, 1.4, 1.4), Vector3.new(0, crownY, PZ + s * 12), gold, M.Metal)
		b:decor("CrownBeam", Vector3.new(1.4, 1.4, 25.4), Vector3.new(s * 24, crownY + 0.02, PZ), gold, M.Metal)
		local cf, len = Kit.Span(Vector3.new(s * 24, crownY, PZ), Vector3.new(0, crownY + 12, PZ))
		b:decor("CrownArch", Vector3.new(1, 1, len), cf, gold, M.Metal)
	end
	b:part("Spire", Vector3.new(26, 1.4, 1.4), vertical(Vector3.new(0, crownY + 12 + 13, PZ)), Color3.fromRGB(226, 216, 196),
		nil, { shape = "Cylinder" })
	b:decor("SpireBand", Vector3.new(1, 2.4, 2.4), vertical(Vector3.new(0, crownY + 13, PZ)), gold, nil, { shape = "Cylinder" })
	b:decor("Beacon", Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, crownY + 38.8, PZ), RED, nil, { shape = "Ball" })
	b:light("Point", Vector3.new(0, crownY + 38.8, PZ), RED, 1.5, 20)
	for _, at in ipairs({ Vector3.new(-28, deckTop + 7, -20), Vector3.new(28, deckTop + 7, -20), Vector3.new(-30, deckTop + 8, 28),
		Vector3.new(30, deckTop + 8, 28) }) do
		b:light("Point", at, WARM, 1.1, 40)
	end
end

--- ZEE TOWER at the north end of the avenue: a stone-and-glass skyscraper with three
--- setbacks and a spire, its name painted on a board at the top. Origin at the front's
--- centre, facing -Z.
local function tower(b: Kit.Builder)
	local W, D, H = 60, 40, 150
	local stone = Color3.fromRGB(226, 216, 196)
	local glass = Color3.fromRGB(104, 146, 176)
	b:part("Tower", Vector3.new(W, H, D), Vector3.new(0, H / 2, D / 2), glass, M.Glass, { reflectance = 0.2 })
	-- Stone piers up the front and sides, spandrels across at every floor.
	for x = -W / 2, W / 2 + 1e-3, 7.5 do
		b:decor("Pier", Vector3.new(1.8, H - 16, 1), Vector3.new(x, (H + 16) / 2, -0.5), stone)
	end
	for _, s in ipairs({ -1, 1 }) do
		for z = 0, D + 1e-3, 8 do
			b:decor("Pier", Vector3.new(1, H - 16, 1.8), Vector3.new(s * (W / 2 + 0.5), (H + 16) / 2, z), stone)
		end
	end
	for y = 22, H - 4, 7 do
		b:decor("Spandrel", Vector3.new(W + 1, 1.4, 0.8), Vector3.new(0, y, -0.4), stone)
		for _, s in ipairs({ -1, 1 }) do
			b:decor("Spandrel", Vector3.new(0.8, 1.4, D + 1), Vector3.new(s * (W / 2 + 0.4), y, D / 2), stone)
		end
	end
	-- The base: stone pylons either side of a tall glass lobby, a canopy over the doors.
	b:decor("ShaftCornice", Vector3.new(W + 2, 3, D + 2), Vector3.new(0, H - 1.5, D / 2), stone)
	for _, s in ipairs({ -1, 1 }) do
		b:decor("Base", Vector3.new(12, 16, 1.4), Vector3.new(s * (W / 2 - 6), 8.03, -0.7), stone)
	end
	b:decor("Lobby", Vector3.new(W - 24, 14, 0.4), Vector3.new(0, 7, -0.5), Color3.fromRGB(200, 220, 236), M.Glass,
		{ transparency = 0.4 })
	b:decor("LobbyBand", Vector3.new(W + 1, 2, 1.4), Vector3.new(0, 15, -0.7), stone)
	b:part("Canopy", Vector3.new(24, 0.8, 10), Vector3.new(0, 12.4, -5), NAVY)
	b:decor("CanopyTrim", Vector3.new(24.2, 0.4, 0.3), Vector3.new(0, 12.15, -10.1), GOLD)
	board(b, "ZEE TOWER", Kit.Look(Vector3.new(0, 14.9, -1.6), Vector3.new(0, 14.9, -10)), 22, 1.8, NAVY, GOLD)
	-- The top floor: THE PENTHOUSE, where the Don sits (penthouse, below). It is built on the
	-- roof, a little wider than the shaft all round, so from the street it reads as a crown.
	penthouse(b:within(CFrame.new(0, H, D / 2)))
	-- The way up: the lobby doors take you to the top floor (TowerService).
	-- A stone stoop out front, so the doors meet the avenue on a step rather than the road.
	b:part("TowerStoop", Vector3.new(34, 0.5, 8), Vector3.new(0, -0.25, -4), STONE, M.Concrete)
	-- A clipped cypress in a stone planter at each end of the stoop.
	for _, x in ipairs({ -14.5, 14.5 }) do
		b:part("TowerPlanter", Vector3.new(3.2, 1.2, 3.2), Vector3.new(x, 0.6, -5), STONE_LIGHT, M.Concrete)
		b:decor("Soil", Vector3.new(2.7, 0.1, 2.7), Vector3.new(x, 1.21, -5), SOIL, M.Ground)
		cypress(b:within(CFrame.new(x, 1.2, -5)), if x > 0 then 71 else 17)
	end
	local door = b:decor("TowerDoor", Vector3.new(8, 0.08, 4), Vector3.new(0, 0.04, -3.4), NAVY, M.Fabric)
	door:SetAttribute("PromptText", "Take the elevator")
	door:SetAttribute("PromptObject", "ZEE TOWER · The Penthouse")
	-- The name, high up, facing down the avenue.
	board(b, "ZEE", Kit.Look(Vector3.new(0, H - 14, -1.4), Vector3.new(0, H - 14, -10)), 26, 11, TEAL, CREAM)
	b:light("Point", Vector3.new(0, 14, -4), WARM, 1.2, 36)

	-- The spine: the middle bay up the front in deeper glass between gold-edged piers, from the
	-- lobby to the name, so the shaft has a centre line to it.
	local gold = Color3.fromRGB(236, 184, 64)
	local spineTop = H - 22
	b:decor("Spine", Vector3.new(14.4, spineTop - 17, 0.3), Vector3.new(0, (spineTop + 17) / 2, -0.15), Color3.fromRGB(40, 110, 130),
		M.Glass, { reflectance = 0.25 })
	for _, x in ipairs({ -7.5, 7.5 }) do
		b:decor("SpineEdge", Vector3.new(0.5, spineTop - 17, 1.4), Vector3.new(x, (spineTop + 17) / 2, -1.2), gold, M.Metal)
	end
	-- Lit strips up the spine's edges (they glow at night with the rest of the city).
	for _, x in ipairs({ -7.9, 7.9 }) do
		b:decor("LightPanel", Vector3.new(0.2, spineTop - 20, 0.2), Vector3.new(x, (spineTop + 20) / 2, -1.95), LAMP_GLASS)
	end
	-- Gold fins on all four corners, the full height of the shaft.
	for _, x in ipairs({ -W / 2 - 0.7, W / 2 + 0.7 }) do
		for _, z in ipairs({ -0.7, D + 0.7 }) do
			b:decor("CornerFin", Vector3.new(1.4, H - 18, 1.4), Vector3.new(x, (H + 18) / 2, z), gold, M.Metal)
		end
	end
	-- Two setbacks: a deep ledge all round with a gold lip, a row of clipped shrubs on it, and
	-- a lit band under it.
	for _, y in ipairs({ 64, 106 }) do
		b:decor("Ledge", Vector3.new(W + 4, 1.4, D + 4), Vector3.new(0, y, D / 2), stone)
		b:decor("LedgeLip", Vector3.new(W + 4.3, 0.4, D + 4.3), Vector3.new(0, y + 0.8, D / 2), gold, M.Metal)
		b:decor("LightPanel", Vector3.new(W + 3.6, 0.2, 0.2), Vector3.new(0, y - 0.9, -2.05), LAMP_GLASS)
		for x = -W / 2, W / 2, 6 do
			if math.abs(x) > 9 then
				b:decor("LedgeShrub", Vector3.new(2, 2, 2), Vector3.new(x, y + 1.9, -1.2), HEDGE, nil, { shape = "Ball" })
			end
		end
	end
	-- Balconies on the side faces every few floors: glass fronts on gold rails.
	for _, side in ipairs({ -1, 1 }) do
		for y = 36, H - 30, 21 do
			b:decor("Balcony", Vector3.new(3, 0.5, D - 10), Vector3.new(side * (W / 2 + 1.5), y, D / 2), stone)
			b:decor("BalconyGlass", Vector3.new(0.2, 2.4, D - 10), Vector3.new(side * (W / 2 + 2.9), y + 1.4, D / 2), Color3.fromRGB(200, 226, 236),
				M.Glass, { transparency = 0.4 })
			b:decor("BalconyRail", Vector3.new(0.3, 0.3, D - 10), Vector3.new(side * (W / 2 + 2.9), y + 2.7, D / 2), gold, M.Metal)
		end
	end
	-- At street level: a revolving door in the lobby, gold lettering, flags on three poles,
	-- and lamps either side of the steps.
	b:decor("RevolvingDoor", Vector3.new(9, 6, 6), CFrame.new(0, 4.5, -1.6) * CFrame.Angles(0, 0, math.rad(90)),
		Color3.fromRGB(200, 226, 236), M.Glass, { shape = "Cylinder", transparency = 0.45 })
	b:decor("RevolvingCap", Vector3.new(0.6, 6.4, 6.4), CFrame.new(0, 9.2, -1.6) * CFrame.Angles(0, 0, math.rad(90)), gold, M.Metal,
		{ shape = "Cylinder" })
	b:decor("RevolvingWing", Vector3.new(5.8, 8.6, 0.2), CFrame.new(0, 4.5, -1.6) * CFrame.Angles(0, math.rad(45), 0), gold, M.Metal)
	b:decor("RevolvingWing", Vector3.new(5.8, 8.6, 0.2), CFrame.new(0, 4.5, -1.6) * CFrame.Angles(0, math.rad(-45), 0), gold, M.Metal)
	for i, fx in ipairs({ -27, -21.5, 21.5, 27 }) do
		b:part("FlagPole", Vector3.new(0.4, 30, 0.4), Vector3.new(fx, 15, -8), Color3.fromRGB(220, 222, 226), M.Metal)
		b:decor("PoleTop", Vector3.new(0.8, 0.8, 0.8), Vector3.new(fx, 30.3, -8), gold, M.Metal, { shape = "Ball" })
		local flag = b:decor("Flag", Vector3.new(0.12, 4, 6.4), Vector3.new(fx, 27.6, -11.3), if i % 2 == 0 then NAVY else TEAL, M.Fabric)
		flag.CastShadow = true
		painted(b, "ZEE", Kit.Look(Vector3.new(fx - 0.1, 27.6, -11.3), Vector3.new(fx - 10, 27.6, -11.3)), 4, 2, GOLD)
	end
	for _, x in ipairs({ -17, 17 }) do
		b:part("TowerLamp", Vector3.new(0.6, 8, 0.6), Vector3.new(x, 4, -7.4), IRON)
		b:decor("LanternGlass", Vector3.new(1.4, 1.8, 1.4), Vector3.new(x, 8.8, -7.4), LAMP_GLASS)
		b:decor("LampCap", Vector3.new(1.8, 0.4, 1.8), Vector3.new(x, 9.9, -7.4), gold, M.Metal)
	end
	painted(b, "EST. ZEE", Kit.Look(Vector3.new(0, 16.6, -1.6), Vector3.new(0, 16.6, -10)), 10, 1, GOLD, Enum.Font.GothamBold)
end

--- A car park: painted bays in two rows, a few cars in them, a light at each end.
local function carPark(b: Kit.Builder, x0: number, x1: number, z0: number, z1: number, cars: number)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	b:decor("Lot", Vector3.new(x1 - x0 - 2, 0.06, z1 - z0 - 2), Vector3.new(cx, 0.53, cz), Color3.fromRGB(84, 86, 92), M.Asphalt)
	local rows = { x0 + 7, x1 - 7 }
	local n = 0
	for r, x in ipairs(rows) do
		for z = z0 + 4, z1 - 8, 6 do
			b:decor("Bay", Vector3.new(10, 0.04, 0.25), Vector3.new(x, 0.57, z), WHITE_LINE)
			n += 1
			if n % 3 == 1 and cars > 0 then
				cars -= 1
				car(b:within(CFrame.new(x, 0.5, z + 3) * CFrame.Angles(0, math.rad(r == 1 and 90 or -90), 0)),
					CAR_COLOURS[(n * 5) % #CAR_COLOURS + 1], CAR_KINDS[(n * 2) % #CAR_KINDS + 1])
			end
		end
	end
	for _, z in ipairs({ z0 + 2, z1 - 2 }) do
		lamp(b:within(CFrame.new(cx, 0, z) * CFrame.Angles(0, math.rad(90), 0)), false)
	end
end

--- A pocket park: a hedged lawn, crossing paths, trees at the corners, flower beds, benches
--- and a statue in the middle.
local function pocketPark(b: Kit.Builder)
	local W, D = 60, 20
	b:decor("Lawn", Vector3.new(W, 0.1, D), Vector3.new(0, 0.55, 0), GRASS, M.Grass)
	b:decor("Path", Vector3.new(W - 0.1, 0.12, 3), Vector3.new(0, 0.57, 0), PLAZA_A, M.Slate)
	b:decor("Path", Vector3.new(3, 0.1, D - 0.1), Vector3.new(0, 0.58, 0), PLAZA_A, M.Slate)
	-- A low clipped hedge round the lawn, open where the paths come in.
	for _, s in ipairs({ -1, 1 }) do
		for _, h in ipairs({ -1, 1 }) do
			-- Set down into the lawn and in from its edge, so no face lies on one of the lawn's.
			b:part("Hedge", Vector3.new(W / 2 - 2.6, 1.8, 1.2), Vector3.new(h * (W / 4 + 1.2), 1.45, s * (D / 2 - 0.7)), HEDGE)
			b:part("Hedge", Vector3.new(1.2, 1.8, D / 2 - 2.6), Vector3.new(s * (W / 2 - 0.7), 1.45, h * (D / 4 + 1.2)), HEDGE)
		end
	end
	for _, x in ipairs({ -W / 2 + 5, W / 2 - 5 }) do
		for _, z in ipairs({ -D / 2 + 4, D / 2 - 4 }) do
			tree(b:within(CFrame.new(x, 0, z)), math.floor(x + z), x > 0)
		end
	end
	-- Flower beds either side of the long path.
	for _, x in ipairs({ -19, 19 }) do
		for _, z in ipairs({ -4.6, 4.6 }) do
			flowerBed(b:within(CFrame.new(x, 0.5, z)), 8, 3, math.floor(x + z * 3))
		end
	end
	for _, x in ipairs({ -8, 8 }) do
		bench(b:within(CFrame.new(x, 0, 3.2)))
		bench(b:within(CFrame.new(x, 0, -3.2) * CFrame.Angles(0, math.pi, 0)))
		-- A flowering shrub at the end of each bench.
		for _, z in ipairs({ -3.6, 3.6 }) do
			shrub(b:within(CFrame.new(x + (if x > 0 then 4.4 else -4.4), 0.55, z)), math.floor(x * 7 + z * 3))
		end
	end
	-- Cypresses either side of the long path where it comes in through the hedge.
	for _, x in ipairs({ -W / 2 + 3.4, W / 2 - 3.4 }) do
		for _, z in ipairs({ -3.4, 3.4 }) do
			cypress(b:within(CFrame.new(x, 0.5, z)), math.floor(x + z * 5))
		end
	end
	-- The statue: a figure on a plinth, arm raised with a torch.
	b:part("Plinth", Vector3.new(4, 3, 4), Vector3.new(0, 2, 0), STONE, M.Granite)
	b:decor("PlinthCap", Vector3.new(4.4, 0.4, 4.4), Vector3.new(0, 3.6, 0), STONE_LIGHT)
	local bronze = Color3.fromRGB(140, 110, 72)
	b:part("Legs", Vector3.new(1.6, 3, 1), Vector3.new(0, 5.3, 0), bronze, M.Metal)
	b:part("Torso", Vector3.new(2, 2.6, 1.1), Vector3.new(0, 8.1, 0), bronze, M.Metal)
	b:decor("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 10.1, 0), bronze, M.Metal, { shape = "Ball" })
	b:decor("Arm", Vector3.new(0.6, 3, 0.6), CFrame.new(1.4, 9.7, 0) * CFrame.Angles(0, 0, math.rad(-20)), bronze, M.Metal)
	b:decor("Torch", Vector3.new(0.5, 0.9, 0.5), Vector3.new(1.9, 11.3, 0), bronze, M.Metal)
	b:decor("Flame", Vector3.new(0.8, 0.8, 0.8), CFrame.new(1.9, 12.1, 0) * CFrame.Angles(math.rad(45), 0, math.rad(45)),
		GOLD)
	painted(b, "THE FIRST DUELLIST", Kit.Look(Vector3.new(0, 2, -2.05), Vector3.new(0, 2, -10)), 3.8, 0.7,
		Color3.fromRGB(60, 52, 40), Enum.Font.Garamond)
end

-- ------------------------------------------------------------------- alley --

local CARDBOARD = Color3.fromRGB(196, 150, 96)
local DUMPSTER = Color3.fromRGB(46, 128, 84)
local BAG = Color3.fromRGB(36, 38, 44)

--- A fire escape up a wall that faces -Z: a landing at each floor with a railing, stairs
--- zig-zagging between them, and a drop ladder hooked up under the lowest. Origin at the
--- wall's foot, in the middle of the escape.
local function fireEscape(b: Kit.Builder, floors: { number }, width: number)
	local black = Color3.fromRGB(40, 42, 48)
	for i, y in ipairs(floors) do
		-- Named apart from the apartments' climbable escape (its Stair/Landing parts are the
		-- stash route, and the district test counts them).
		b:decor("EscapeLanding", Vector3.new(width, 0.3, 3.4), Vector3.new(0, y, -1.8), black, M.DiamondPlate)
		b:decor("Rail", Vector3.new(width, 0.2, 0.2), Vector3.new(0, y + 3, -3.4), black)
		b:decor("Rail", Vector3.new(width, 0.15, 0.15), Vector3.new(0, y + 1.6, -3.4), black)
		for _, x in ipairs({ -width / 2, width / 2 }) do
			b:decor("RailEnd", Vector3.new(0.2, 0.2, 3.4), Vector3.new(x, y + 3, -1.8), black)
		end
		for x = -width / 2, width / 2 + 1e-3, width / 4 do
			b:decor("Baluster", Vector3.new(0.14, 3, 0.14), Vector3.new(x, y + 1.5, -3.4), black)
		end
		b:decor("Bracket", Vector3.new(0.3, 1.8, 3), CFrame.new(-width / 2 + 0.6, y - 1, -1.6) * CFrame.Angles(math.rad(-30), 0, 0),
			black)
		b:decor("Bracket", Vector3.new(0.3, 1.8, 3), CFrame.new(width / 2 - 0.6, y - 1, -1.6) * CFrame.Angles(math.rad(-30), 0, 0),
			black)
		local nextY = floors[i + 1]
		if nextY then
			-- A flight up to the next landing, alternating ends.
			local s = if i % 2 == 1 then 1 else -1
			local from = Vector3.new(s * (width / 2 - 2.6), y + 0.2, -2.2)
			local to = Vector3.new(-s * (width / 2 - 2.6), nextY + 0.2, -2.2)
			local cf, len = Kit.Span(from, to)
			b:decor("EscapeStair", Vector3.new(1.8, 0.25, len), cf, black, M.DiamondPlate)
			b:decor("StairRail", Vector3.new(0.14, 0.14, len), cf * CFrame.new(0.9, 2.2, 0), black)
		end
	end
	-- The drop ladder, hooked up under the first landing.
	local low = floors[1]
	for _, x in ipairs({ -0.7, 0.7 }) do
		b:decor("LadderRail", Vector3.new(0.14, 6, 0.14), Vector3.new(width / 2 - 1.6 + x, low - 3, -3.2), black)
	end
	for y = low - 5.5, low - 0.5, 1 do
		b:decor("Rung", Vector3.new(1.4, 0.12, 0.12), Vector3.new(width / 2 - 1.6, y, -3.2), black)
	end
end

local function dumpster(b: Kit.Builder, colour: Color3)
	b:part("Dumpster", Vector3.new(6, 3.6, 3.4), Vector3.new(0, 2.2, 0), colour, M.Metal)
	b:decor("Rim", Vector3.new(6.2, 0.3, 3.6), Vector3.new(0, 4.05, 0), darker(colour, 0.2), M.Metal)
	b:decor("Lid", Vector3.new(2.95, 0.2, 3.7), CFrame.new(-1.5, 4.35, 0.1) * CFrame.Angles(math.rad(-6), 0, 0),
		darker(colour, 0.35), M.Plastic)
	b:decor("Lid", Vector3.new(2.95, 0.2, 3.7), CFrame.new(1.5, 4.9, 1.2) * CFrame.Angles(math.rad(-58), 0, 0),
		darker(colour, 0.35), M.Plastic)
	for _, x in ipairs({ -2.4, 2.4 }) do
		b:decor("Wheel", Vector3.new(0.4, 0.8, 0.8), Vector3.new(x, 0.4, -1.3), BAG, nil, { shape = "Cylinder" })
		b:decor("Wheel", Vector3.new(0.4, 0.8, 0.8), Vector3.new(x, 0.4, 1.3), BAG, nil, { shape = "Cylinder" })
		b:decor("Pocket", Vector3.new(1.2, 0.8, 0.25), Vector3.new(x, 2.4, -1.8), darker(colour, 0.25), M.Metal)
	end
	painted(b, "WASTE", Kit.Look(Vector3.new(0, 2.6, -1.72), Vector3.new(0, 2.6, -10)), 2.6, 0.6, TRIM)
end

local function pallet(b: Kit.Builder)
	local wood = Color3.fromRGB(190, 150, 100)
	for _, z in ipairs({ -1.6, 0, 1.6 }) do
		b:decor("Block", Vector3.new(4, 0.4, 0.6), Vector3.new(0, 0.2, z), darker(wood, 0.15), M.Wood)
	end
	for x = -1.6, 1.6 + 1e-3, 0.8 do
		b:decor("Board", Vector3.new(0.6, 0.14, 4), Vector3.new(x, 0.47, 0), wood, M.WoodPlanks)
	end
end

local function box(b: Kit.Builder, size: number, seed: number)
	local shade = CARDBOARD:Lerp(Color3.fromRGB(150, 110, 70), (seed % 3) * 0.2)
	b:part("Box", Vector3.new(size, size * 0.8, size), Vector3.new(0, size * 0.4, 0), shade, M.Cardboard)
	b:decor("Tape", Vector3.new(size + 0.04, 0.1, size * 0.22), Vector3.new(0, size * 0.8 + 0.02, 0), Color3.fromRGB(222, 206, 160))
end

local function trashBags(b: Kit.Builder, count: number, seed: number)
	local rng = Random.new(seed)
	for i = 1, count do
		local sz = rng:NextNumber(1.6, 2.3)
		local at = Vector3.new(rng:NextNumber(-1.6, 1.6), sz * 0.4, rng:NextNumber(-1.2, 1.2))
		b:decor("Bag", Vector3.new(sz, sz * 0.85, sz), at, if i % 4 == 0 then Color3.fromRGB(70, 90, 120) else BAG,
			M.Plastic, { shape = "Ball", shadow = true })
		b:decor("Tie", Vector3.new(0.4, 0.5, 0.4), at + Vector3.new(0, sz * 0.45, 0), BAG, M.Plastic)
	end
end

--- A muscle car: long, low, racing stripes over the bonnet, a spoiler and fat rear tyres.
--- Nose toward -Z.
local function muscleCar(b: Kit.Builder, colour: Color3)
	local trim = Color3.fromRGB(28, 28, 32)
	b:part("Body", Vector3.new(5, 1.5, 11.5), Vector3.new(0, 1.55, 0), colour, nil, { reflectance = 0.08 })
	b:part("Cabin", Vector3.new(4.3, 1.3, 4.6), Vector3.new(0, 2.95, 1), colour)
	b:decor("Glass", Vector3.new(4.36, 0.9, 4.66), Vector3.new(0, 2.95, 1), Color3.fromRGB(40, 52, 70), M.Glass,
		{ transparency = 0.1, reflectance = 0.25 })
	b:decor("Roof", Vector3.new(4.32, 0.25, 3.8), Vector3.new(0, 3.65, 1.1), colour)
	b:decor("Scoop", Vector3.new(1.8, 0.5, 2.4), Vector3.new(0, 2.5, -3.2), darker(colour, 0.2))
	for _, x in ipairs({ -0.55, 0.55 }) do
		b:decor("Stripe", Vector3.new(0.5, 0.06, 11.52), Vector3.new(x, 2.32, 0), TRIM)
	end
	b:decor("Spoiler", Vector3.new(4.8, 0.25, 1), Vector3.new(0, 3, 5.4), trim)
	for _, x in ipairs({ -1.9, 1.9 }) do
		b:decor("SpoilerPost", Vector3.new(0.25, 0.6, 0.5), Vector3.new(x, 2.55, 5.4), trim)
	end
	b:decor("Grille", Vector3.new(4.2, 0.8, 0.12), Vector3.new(0, 1.6, -5.8), trim)
	for _, x in ipairs({ -1.7, 1.7 }) do
		b:decor("Headlight", Vector3.new(0.9, 0.9, 0.1), Vector3.new(x, 1.7, -5.82), Color3.fromRGB(250, 246, 226), nil,
			{ shape = "Cylinder" })
		b:decor("Taillight", Vector3.new(1.2, 0.4, 0.1), Vector3.new(x, 1.8, 5.78), Color3.fromRGB(210, 40, 40))
		b:decor("Exhaust", Vector3.new(0.9, 0.35, 0.35), CFrame.new(x * 0.6, 0.9, 5.9) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(170, 170, 176), M.Metal, { shape = "Cylinder" })
	end
	for _, x in ipairs({ -2.2, 2.2 }) do
		b:decor("Wheel", Vector3.new(1, 2.1, 2.1), Vector3.new(x, 1.05, -3.6), trim, M.Rubber, { shape = "Cylinder" })
		b:decor("Wheel", Vector3.new(1.3, 2.5, 2.5), Vector3.new(x, 1.25, 3.4), trim, M.Rubber, { shape = "Cylinder" })
		b:decor("Hub", Vector3.new(1.04, 1, 1), Vector3.new(x, 1.05, -3.6), Color3.fromRGB(210, 210, 214), M.Metal,
			{ shape = "Cylinder" })
		b:decor("Hub", Vector3.new(1.34, 1.2, 1.2), Vector3.new(x, 1.25, 3.4), Color3.fromRGB(210, 210, 214), M.Metal,
			{ shape = "Cylinder" })
	end
end

--- THE ALLEY: the back lane behind the gas station, running west from the car park to the
--- district wall -- brick backs of buildings with fire escapes up them, dumpsters, pallets and
--- boxes to fight round, bin bags, washing strung across overhead, a muscle car parked up, a
--- red light over a back door, yellow bollards where it meets the car park, and tags on the
--- walls. Origin at the lane's middle on the ground; the lane runs along X (east +X), its
--- walls at z = +-`half`.
--- The Fixer's corner, on the paving south of the courts: a purple pop-up canopy over a card
--- table (cards, a cash stack, a burner phone), two folding chairs, crates with a boombox on
--- top, a work lamp. The Fixer stands at the front of it (QuestConfig.Givers.Fixer).
--- Origin at the canopy's centre on the pavement, +Z toward the court.
local function fixerCorner(b: Kit.Builder)
	local purple = Color3.fromRGB(128, 64, 170)
	local W, D, H = 12, 10, 8.6
	for _, x in ipairs({ -W / 2, W / 2 }) do
		for _, z in ipairs({ -D / 2, D / 2 }) do
			b:part("CanopyPole", Vector3.new(0.35, H, 0.35), Vector3.new(x, H / 2, z), STEEL, M.Metal)
			b:decor("PoleFoot", Vector3.new(1, 0.3, 1), Vector3.new(x, 0.15, z), IRON)
		end
	end
	-- The roof: a shallow pyramid read as two pitched halves, a valance round the edge.
	for _, s in ipairs({ -1, 1 }) do
		b:decor("CanopyRoof", Vector3.new(W + 0.6, 1.4, D / 2 + 0.3),
			CFrame.new(0, H + 0.7, s * (D / 4 + 0.075)) * CFrame.Angles(0, s > 0 and math.pi or 0, 0), purple, M.Fabric,
			{ shape = "Wedge" })
	end
	for _, s in ipairs({ -1, 1 }) do
		b:decor("Valance", Vector3.new(W + 0.6, 0.8, 0.12), Vector3.new(0, H - 0.4, s * (D / 2 + 0.3)), purple, M.Fabric)
		b:decor("Valance", Vector3.new(0.12, 0.8, D + 0.6), Vector3.new(s * (W / 2 + 0.3), H - 0.4, 0), purple, M.Fabric)
	end
	painted(b, "JOBS", Kit.Look(Vector3.new(0, H - 0.4, -D / 2 - 0.42), Vector3.new(0, H - 0.4, -D)), 4, 0.7, CREAM)

	-- The card table.
	local t = b:within(CFrame.new(3, 0, 1.5))
	t:part("CardTable", Vector3.new(3.4, 0.2, 3.4), Vector3.new(0, 2.6, 0), Color3.fromRGB(40, 110, 70), M.Fabric)
	t:decor("TableRim", Vector3.new(3.6, 0.16, 3.6), Vector3.new(0, 2.44, 0), Color3.fromRGB(36, 30, 26))
	for _, x in ipairs({ -1.5, 1.5 }) do
		for _, z in ipairs({ -1.5, 1.5 }) do
			t:decor("TableLeg", Vector3.new(0.14, 2.4, 0.14), Vector3.new(x, 1.2, z), STEEL, M.Metal)
		end
	end
	for i, at in ipairs({ Vector3.new(-0.8, 2.72, -0.5), Vector3.new(0.3, 2.72, 0.7), Vector3.new(0.9, 2.72, -0.6) }) do
		t:decor("Card", Vector3.new(0.5, 0.03, 0.72), CFrame.new(at) * CFrame.Angles(0, math.rad(i * 37), 0),
			Color3.fromRGB(250, 250, 246))
	end
	t:decor("Cash", Vector3.new(0.9, 0.3, 0.45), Vector3.new(-0.6, 2.85, 0.8), Color3.fromRGB(110, 170, 96))
	t:decor("CashBand", Vector3.new(0.2, 0.36, 0.51), Vector3.new(-0.6, 2.85, 0.8), Color3.fromRGB(236, 220, 150))
	t:decor("Phone", Vector3.new(0.3, 0.06, 0.6), Vector3.new(1.1, 2.73, 0.9), Color3.fromRGB(24, 24, 28))
	-- Folding chairs either side.
	for _, s in ipairs({ -1, 1 }) do
		local c = t:within(CFrame.new(s * 2.6, 0, 0) * CFrame.Angles(0, s > 0 and math.rad(90) or math.rad(-90), 0))
		c:part("ChairSeat", Vector3.new(1.6, 0.16, 1.6), Vector3.new(0, 1.6, 0), Color3.fromRGB(70, 74, 82), M.Metal)
		c:decor("ChairBack", Vector3.new(1.6, 1.6, 0.14), Vector3.new(0, 2.5, 0.8), Color3.fromRGB(70, 74, 82), M.Metal)
		for _, x in ipairs({ -0.7, 0.7 }) do
			c:decor("ChairLeg", Vector3.new(0.1, 1.6, 0.1), Vector3.new(x, 0.8, -0.6), STEEL, M.Metal)
			c:decor("ChairLeg", Vector3.new(0.1, 3.2, 0.1), Vector3.new(x, 1.6, 0.74), STEEL, M.Metal)
		end
	end

	-- Crates at the back, a boombox on top.
	local crates = b:within(CFrame.new(-3.4, 0, 3))
	box(crates:within(CFrame.new(0, 0, 0)), 2.6, 1)
	box(crates:within(CFrame.new(2.4, 0, 0.6) * CFrame.Angles(0, math.rad(12), 0)), 2.2, 2)
	box(crates:within(CFrame.new(0.4, 2.08, 0.1) * CFrame.Angles(0, math.rad(-8), 0)), 1.9, 3)
	local boom = crates:within(CFrame.new(0.4, 3.6, 0.1))
	boom:decor("Boombox", Vector3.new(1.8, 0.9, 0.6), Vector3.new(0, 0.45, 0), Color3.fromRGB(34, 34, 40))
	for _, x in ipairs({ -0.5, 0.5 }) do
		boom:decor("Speaker", Vector3.new(0.06, 0.62, 0.62), CFrame.new(x, 0.45, -0.31) * CFrame.Angles(0, math.rad(90), 0),
			Color3.fromRGB(90, 90, 96), M.Metal, { shape = "Cylinder" })
	end
	boom:decor("Handle", Vector3.new(1.2, 0.12, 0.12), Vector3.new(0, 1.0, 0), STEEL, M.Metal)

	-- A work lamp on a tripod, pointed at the table.
	local lamp = b:within(CFrame.new(-5, 0, -3.6))
	for i = 0, 2 do
		local a = i * math.pi * 2 / 3
		lamp:decor("TripodLeg", Vector3.new(0.12, 4.4, 0.12),
			CFrame.new(math.cos(a) * 0.6, 2.1, math.sin(a) * 0.6) * CFrame.Angles(math.sin(a) * 0.28, 0, -math.cos(a) * 0.28),
			IRON, M.Metal)
	end
	lamp:decor("LampHead", Vector3.new(1.2, 0.9, 0.5), Kit.Look(Vector3.new(0, 4.6, 0), Vector3.new(8, 2.6, 5)),
		Color3.fromRGB(236, 190, 40), M.Metal)
	lamp:light("Spot", Kit.Look(Vector3.new(0, 4.6, 0), Vector3.new(8, 2.6, 5)), WARM, 1.4, 18, { Angle = 60 })
end

local function alley(b: Kit.Builder, length: number, half: number)
	local floorColour = Color3.fromRGB(78, 80, 88)
	b:decor("AlleyFloor", Vector3.new(length, 0.04, half * 2), Vector3.new(0, 0.02, 0), floorColour, M.Asphalt)
	b:decor("Gutter", Vector3.new(length, 0.05, 1), Vector3.new(0, 0.03, 0), darker(floorColour, 0.25), M.Concrete)
	for x = -length / 2 + 8, length / 2 - 8, 16 do
		b:decor("Drain", Vector3.new(1.6, 0.07, 1.4), Vector3.new(x, 0.04, 0), Color3.fromRGB(40, 40, 44), M.DiamondPlate)
	end
	for i, spot in ipairs({ Vector3.new(-30, 0, 4), Vector3.new(6, 0, -5), Vector3.new(30, 0, 3) }) do
		b:decor("Puddle", Vector3.new(0.06, 5 + i, 3.6 + i * 0.6), vertical(spot + Vector3.new(0, 0.05, 0)),
			Color3.fromRGB(70, 96, 130), M.Glass, { shape = "Cylinder", transparency = 0.3, reflectance = 0.35 })
	end

	-- Fire escapes: three up the north wall, two up the south.
	for _, x in ipairs({ -36, -6, 24 }) do
		fireEscape(b:within(CFrame.new(x, 0, half) * CFrame.Angles(0, 0, 0)), { 12, 19, 26, 33 }, 10)
	end
	for _, x in ipairs({ -22, 12 }) do
		fireEscape(b:within(CFrame.new(x, 0, -half) * CFrame.Angles(0, math.pi, 0)), { 12, 19, 26 }, 10)
	end

	-- The back door with its red light, and pipes and air units on the walls.
	local door = b:within(CFrame.new(-18, 0, half))
	door:decor("BackDoorFrame", Vector3.new(4.6, 8, 0.4), Vector3.new(0, 4, -0.2), darker(BRICK, 0.3))
	door:decor("BackDoor", Vector3.new(3.6, 7.2, 0.4), Vector3.new(0, 3.6, -0.3), Color3.fromRGB(70, 84, 96), M.Metal)
	door:decor("Handle", Vector3.new(0.3, 0.3, 0.3), Vector3.new(1.2, 3.6, -0.6), Color3.fromRGB(200, 200, 204), M.Metal)
	door:decor("LampCage", Vector3.new(1.3, 1.3, 1.1), Vector3.new(0, 9, -0.7), Color3.fromRGB(40, 40, 44), M.Metal)
	door:decor("RedLamp", Vector3.new(1, 1, 1), Vector3.new(0, 9, -0.8), Color3.fromRGB(236, 40, 40), nil, { shape = "Ball" })
	door:light("Point", Vector3.new(0, 8.6, -2), Color3.fromRGB(255, 60, 50), 1.4, 16)
	for _, spec in ipairs({ { -44, half }, { 2, half }, { 36, half }, { -30, -half }, { 28, -half } }) do
		local zSign = if spec[2] > 0 then -1 else 1
		b:decor("Pipe", Vector3.new(0.6, 30, 0.6), Vector3.new(spec[1], 15, spec[2] + zSign * 0.4), Color3.fromRGB(120, 124, 130),
			M.Metal)
		b:decor("PipeShoe", Vector3.new(0.9, 0.9, 1.4), Vector3.new(spec[1], 0.5, spec[2] + zSign * 0.8),
			Color3.fromRGB(120, 124, 130), M.Metal)
	end
	for _, spec in ipairs({ { -28, half, 9 }, { 10, half, 16 }, { 40, -half, 9 }, { -8, -half, 16 } }) do
		local zSign = if spec[2] > 0 then -1 else 1
		b:decor("AirUnit", Vector3.new(3.2, 2.4, 1.6), Vector3.new(spec[1], spec[3], spec[2] + zSign * 0.8),
			Color3.fromRGB(206, 208, 204), M.Metal)
		-- A fan grille facing the lane: a disc with its axis along Z.
		b:decor("AirGrille", Vector3.new(0.1, 1.8, 1.8), CFrame.new(spec[1], spec[3], spec[2] + zSign * 1.62)
			* CFrame.Angles(0, math.rad(90), 0), STEEL, nil, { shape = "Cylinder" })
	end

	-- Things to fight round: dumpsters, pallets, boxes, bags.
	dumpster(b:within(CFrame.new(-26, 0, half - 3)), DUMPSTER)
	dumpster(b:within(CFrame.new(18, 0, -half + 3) * CFrame.Angles(0, math.pi, 0)), Color3.fromRGB(60, 92, 150))
	trashBags(b:within(CFrame.new(-20.5, 0, half - 2.6)), 5, 7)
	trashBags(b:within(CFrame.new(23.5, 0, -half + 2.4)), 4, 11)
	trashBags(b:within(CFrame.new(-44, 0, -half + 2.4)), 3, 19)
	for i, spot in ipairs({ { -38, -half + 3, 0 }, { -3, half - 3, 15 }, { 31, half - 3, -8 } }) do
		local p = b:within(CFrame.new(spot[1], 0, spot[2]) * CFrame.Angles(0, math.rad(spot[3]), 0))
		for k = 0, 2 + (i % 2) do
			pallet(p:within(CFrame.new(0, k * 0.55, 0)))
		end
	end
	pallet(b:within(CFrame.new(-49.5, 2, half - 0.9) * CFrame.Angles(math.rad(-78), 0, 0)))
	local boxes = {
		{ -12, -half + 2.2, 2.6 }, { -9.3, -half + 2, 2 }, { -11, -half + 2.2, 1.8, 2.1 }, { 4, half - 2, 2.4 },
		{ 6.4, half - 2.3, 1.6 }, { 40, -half + 2.4, 2.8 }, { 42.6, -half + 2, 1.8 }, { 40.4, -half + 2.3, 2, 2.25 },
	}
	for i, spec in ipairs(boxes) do
		box(b:within(CFrame.new(spec[1], spec[4] or 0, spec[2]) * CFrame.Angles(0, math.rad(i * 17), 0)), spec[3], i)
	end

	-- Washing strung across overhead, wall to wall.
	for _, spec in ipairs({ { -14, 17 }, { 30, 15 } }) do
		local x, y = spec[1], spec[2]
		local cf, len = Kit.Span(Vector3.new(x, y, -half), Vector3.new(x + 3, y - 0.6, half))
		b:decor("Line", Vector3.new(0.08, 0.08, len), cf, Color3.fromRGB(230, 230, 230))
		for k = 1, 6 do
			local t = k / 7
			local at = Vector3.new(x + 3 * t, y - 0.6 * t, -half + half * 2 * t)
			local colour = ({ RED, TRIM, BLUE, GOLD, Color3.fromRGB(236, 112, 170), GREEN })[k]
			local sized = if k % 3 == 0 then Vector3.new(1.2, 2.2, 0.08) else Vector3.new(1.8, 1.6, 0.08)
			b:decor("Washing", sized, CFrame.new(at - Vector3.new(0, sized.Y / 2, 0)) * CFrame.Angles(0, math.rad(80), 0),
				colour, M.Fabric)
		end
	end

	-- A muscle car parked up by the south wall.
	muscleCar(b:within(CFrame.new(-2, 0, -half + 4.2) * CFrame.Angles(0, math.rad(90), 0)), Color3.fromRGB(236, 110, 36))

	-- Tags on the walls.
	for _, spec in ipairs({
		{ "ZEE", -40, half, 5, Color3.fromRGB(236, 60, 150) }, { "RAT KINGS", 30, half, 4, Color3.fromRGB(80, 220, 255) },
		{ "NO BALLING", -32, -half, 3.6, Color3.fromRGB(250, 214, 60) }, { "Z!", 4, -half, 5, Color3.fromRGB(120, 240, 110) },
	} :: { { any } }) do
		local zSign = if spec[3] > 0 then -1 else 1
		local at = Vector3.new(spec[2], spec[4], spec[3] + zSign * 0.06)
		painted(b, spec[1], Kit.Look(at, at + Vector3.new(0, 0, zSign * 10)), #spec[1] * 1.3 + 2, 2.6, spec[5],
			Enum.Font.FredokaOne)
	end

	-- Yellow bollards and a chain across where it meets the car park, a gap to walk through.
	for _, z in ipairs({ -8, -4, 4, 8 }) do
		local post = b:within(CFrame.new(length / 2 - 1.5, 0, z))
		post:part("Bollard", Vector3.new(3, 0.8, 0.8), vertical(Vector3.new(0, 1.5, 0)), Color3.fromRGB(250, 200, 40), nil,
			{ shape = "Cylinder" })
		post:decor("Band", Vector3.new(0.4, 0.84, 0.84), vertical(Vector3.new(0, 2.3, 0)), BAG, nil, { shape = "Cylinder" })
	end
	-- The dead end: a chain-link fence across in front of the district wall.
	local fence = b:within(CFrame.new(-length / 2 + 1, 0, 0))
	for z = -half + 1, half - 1 + 1e-3, (half * 2 - 2) / 6 do
		fence:part("FencePost", Vector3.new(0.3, 8, 0.3), Vector3.new(0, 4, z), Color3.fromRGB(150, 154, 160), M.Metal)
	end
	fence:decor("FenceTop", Vector3.new(0.2, 0.2, half * 2 - 2), Vector3.new(0, 8, 0), Color3.fromRGB(150, 154, 160), M.Metal)
	fence:part("Mesh", Vector3.new(0.1, 7.6, half * 2 - 2), Vector3.new(0, 3.9, 0), Color3.fromRGB(170, 174, 180),
		M.DiamondPlate, { transparency = 0.55 })
end

-- -------------------------------------------------------------------- park --

local ROCK = Color3.fromRGB(128, 122, 130)
local ROCK_LIGHT = Color3.fromRGB(160, 154, 160)
local FALL = Color3.fromRGB(170, 222, 250)
local FOAM = Color3.fromRGB(242, 250, 255)
local RAINBOW_FLAGS = {
	Color3.fromRGB(236, 64, 64), Color3.fromRGB(250, 146, 44), Color3.fromRGB(250, 214, 60),
	Color3.fromRGB(96, 200, 90), Color3.fromRGB(64, 150, 236), Color3.fromRGB(170, 104, 230), Color3.fromRGB(240, 110, 170),
}
local RAINBOW = {
	Color3.fromRGB(236, 64, 64), Color3.fromRGB(250, 146, 44), Color3.fromRGB(250, 222, 60),
	Color3.fromRGB(96, 200, 90), Color3.fromRGB(64, 150, 236), Color3.fromRGB(150, 96, 220),
}

--- A path laid through `points` (on the ground, y ignored): a slab between each pair and a
--- round pad at each bend so it reads as one curving walk.
local function curvedPath(b: Kit.Builder, points: { Vector3 }, width: number, colour: Color3)
	for i = 1, #points - 1 do
		local a, c = points[i], points[i + 1]
		local cf, len = Kit.Span(Vector3.new(a.X, 0.07, a.Z), Vector3.new(c.X, 0.07, c.Z))
		b:decor("Path", Vector3.new(width, 0.12, len), cf, colour, M.Slate)
		b:decor("PathEdge", Vector3.new(width + 0.6, 0.1, len + 0.4), cf * CFrame.new(0, -0.01, 0), darker(colour, 0.18), M.Slate)
	end
	for _, pt in ipairs(points) do
		b:decor("PathBend", Vector3.new(0.12, width, width), vertical(Vector3.new(pt.X, 0.07, pt.Z)), colour, M.Slate,
			{ shape = "Cylinder" })
	end
end

--- A clump of flowers: leafy tufts with blooms in one colour on top.
local function flowerClump(b: Kit.Builder, colour: Color3, seed: number)
	local rng = Random.new(seed)
	for _ = 1, 5 do
		local at = Vector3.new(rng:NextNumber(-1.4, 1.4), 0, rng:NextNumber(-1.4, 1.4))
		b:decor("Tuft", Vector3.new(1, 0.7, 1), CFrame.new(at + Vector3.new(0, 0.45, 0)) * CFrame.Angles(0, rng:NextNumber(0, 3), 0),
			HEDGE)
		b:decor("Bloom", Vector3.new(0.6, 0.6, 0.6), at + Vector3.new(0, 1, 0), colour, nil, { shape = "Ball" })
	end
end

--- A tuft of long grass: three blades fanned out.
local function grassTuft(b: Kit.Builder, seed: number)
	local shade = if seed % 2 == 0 then Color3.fromRGB(96, 176, 76) else Color3.fromRGB(122, 196, 84)
	for k = -1, 1 do
		b:decor("Blade", Vector3.new(0.3, 1.3, 0.12), CFrame.new(k * 0.25, 0.6, 0) * CFrame.Angles(0, seed + k, math.rad(k * 22)),
			shade)
	end
end

--- The rainbow waterfall: a cliff of stacked rock against a wall (the wall toward -X), water
--- pouring off its lip into a round stone-rimmed pond, foam where it lands, and a rainbow
--- arching over the pond. Origin at the pond's centre on the ground.
local function rainbowFalls(b: Kit.Builder)
	local R = 7
	b:part("PondFloor", Vector3.new(0.4, R * 2, R * 2), vertical(Vector3.new(0, 0.2, 0)), Color3.fromRGB(70, 110, 120), nil,
		{ shape = "Cylinder" })
	b:decor("PondWater", Vector3.new(0.2, R * 2 - 0.4, R * 2 - 0.4), vertical(Vector3.new(0, 0.55, 0)), WATER, M.Glass,
		{ shape = "Cylinder", transparency = 0.25, reflectance = 0.2 })
	for i = 0, 11 do
		local a = i / 12 * math.pi * 2
		local cf = CFrame.Angles(0, a, 0) * CFrame.new(0, 0.7, -R)
		-- Alternate stones a step apart in height, so neighbours never share a top face.
		b:part("Rim", Vector3.new(4, if i % 2 == 0 then 1.4 else 1.52, if i % 2 == 0 then 1.6 else 1.7),
			cf * CFrame.new(0, if i % 2 == 0 then 0 else 0.06, 0), if i % 2 == 0 then STONE else STONE_LIGHT, M.Slate)
	end
	-- The cliff: rough rock stacked up the wall behind the pond.
	local rng = Random.new(77)
	local cliffX = -R - 2
	for layer = 0, 4 do
		for k = -2, 2 do
			local sz = rng:NextNumber(4, 6)
			local at = Vector3.new(cliffX - 2 + layer * -0.3 + rng:NextNumber(-0.6, 0.6), 2 + layer * 4.2,
				k * 3.6 + rng:NextNumber(-0.6, 0.6))
			b:part("Rock", Vector3.new(sz, sz * 0.9, sz), CFrame.new(at) * CFrame.Angles(rng:NextNumber(-0.3, 0.3),
				rng:NextNumber(0, 3), rng:NextNumber(-0.3, 0.3)), if (layer + k) % 2 == 0 then ROCK else ROCK_LIGHT, M.Slate)
		end
	end
	b:part("Lip", Vector3.new(6, 1.6, 7), Vector3.new(cliffX - 0.5, 21.4, 0), ROCK_LIGHT, M.Slate)
	b:decor("Moss", Vector3.new(6.2, 0.4, 7.2), Vector3.new(cliffX - 0.5, 22.3, 0), Color3.fromRGB(96, 170, 80), M.Grass)
	for _, z in ipairs({ -3.2, 3.4 }) do
		b:decor("Fern", Vector3.new(2.4, 2, 2.4), CFrame.new(cliffX - 1, 23, z) * CFrame.Angles(0, math.rad(45), 0), HEDGE)
	end
	-- The fall: a sheet from the lip to the pond, brighter streaks down it, foam at the foot.
	b:decor("RunOff", Vector3.new(3.4, 0.3, 4.6), Vector3.new(cliffX + 1.6, 21.3, 0), FALL, M.Glass, { transparency = 0.2 })
	b:decor("Fall", Vector3.new(0.5, 20.6, 4.6), Vector3.new(cliffX + 3.4, 11, 0), FALL, M.Glass,
		{ transparency = 0.25, reflectance = 0.1 })
	for _, z in ipairs({ -1.6, 0.2, 1.8 }) do
		b:decor("Streak", Vector3.new(0.56, 19, 0.5), Vector3.new(cliffX + 3.45, 11.6, z), FOAM, nil, { transparency = 0.35 })
	end
	for k = 0, 6 do
		local a = k / 7 * math.pi * 2
		b:decor("Foam", Vector3.new(2.2, 1.2, 2.2), Vector3.new(cliffX + 4.4 + math.cos(a) * 1.4, 0.8, math.sin(a) * 2.2),
			FOAM, nil, { shape = "Ball", transparency = 0.15 })
	end
	-- The rainbow: six bands arching across the pond, in the plane of the fall.
	for band, colour in ipairs(RAINBOW) do
		local radius = 12 - (band - 1) * 0.6
		local prev: Vector3? = nil
		for k = 0, 16 do
			local a = k / 16 * math.pi
			local pt = Vector3.new(cliffX + 5.6, math.sin(a) * radius, math.cos(a) * radius)
			if prev then
				local cf, len = Kit.Span(prev, pt)
				b:decor("Rainbow", Vector3.new(0.3, 0.6, len + 0.08), cf, colour, nil, { transparency = 0.15 })
			end
			prev = pt
		end
	end
	b:light("Point", Vector3.new(cliffX + 5, 4, 0), Color3.fromRGB(190, 230, 255), 0.8, 20)
end

--- A five-pointed star-shaped stage facing -Z, with a backdrop, a lighting truss and speakers.
--- Origin at the star's centre on the ground.
local function starStage(b: Kit.Builder)
	local purple, yellow = Color3.fromRGB(130, 88, 210), Color3.fromRGB(252, 206, 56)
	local H = 1.4
	local apothem = 5
	local halfBase = apothem * math.tan(math.rad(36))
	local reach = 6.5
	-- The middle is a disc a step proud of the points, so its top never shares their plane.
	b:part("StageCore", Vector3.new(H + 0.2, apothem / math.cos(math.rad(36)) * 2, apothem / math.cos(math.rad(36)) * 2),
		vertical(Vector3.new(0, (H + 0.2) / 2, 0)), purple, nil, { shape = "Cylinder" })
	b:decor("CoreRing", Vector3.new(0.1, 5, 5), vertical(Vector3.new(0, H + 0.23, 0)), yellow, nil, { shape = "Cylinder" })
	-- Each point: two right-angled wedges laid flat, mirrored, from the pentagon's side out.
	for k = 0, 4 do
		local turn = CFrame.Angles(0, math.rad(k * 72), 0) * CFrame.new(0, 0, -apothem)
		b:part("StarPoint", Vector3.new(H, halfBase, reach), turn * CFrame.new(-halfBase / 2, H / 2, -reach / 2)
			* CFrame.Angles(0, 0, math.pi / 2), yellow, nil, { shape = "Wedge" })
		b:part("StarPoint", Vector3.new(H, halfBase, reach), turn * CFrame.new(halfBase / 2, H / 2, -reach / 2)
			* CFrame.Angles(0, 0, -math.pi / 2), yellow, nil, { shape = "Wedge" })
	end
	-- The backdrop behind the stage (+Z), the name across it.
	b:part("Backdrop", Vector3.new(20, 11, 1), Vector3.new(0, 5.5, 9.5), NAVY)
	b:decor("BackdropTrim", Vector3.new(20.6, 0.8, 1.2), Vector3.new(0, 11.2, 9.5), yellow)
	board(b, "ZEE BEATS", Kit.Look(Vector3.new(0, 8.4, 8.6), Vector3.new(0, 8.4, -10)), 13, 2.6, purple, TRIM)
	painted(b, "LIVE  ·  EVERY  NIGHT", Kit.Look(Vector3.new(0, 5.6, 8.94), Vector3.new(0, 5.6, -10)), 11, 1.1, yellow,
		Enum.Font.FredokaOne)
	-- The truss: two towers and a beam, coloured spotlights hanging off it.
	local black = Color3.fromRGB(34, 34, 40)
	for _, x in ipairs({ -10.5, 10.5 }) do
		b:part("TrussTower", Vector3.new(1, 13, 1), Vector3.new(x, 6.5, 6), STEEL, M.Metal)
		b:decor("TrussFoot", Vector3.new(2, 0.4, 2), Vector3.new(x, 0.2, 6), black)
		-- A speaker stack on the ground in the notch beside the stage.
		b:part("Speaker", Vector3.new(3, 5, 2.4), Vector3.new(x * 0.86, 2.5, 3), black)
		for i, y in ipairs({ 1.9, 3.8 }) do
			b:decor("Cone", Vector3.new(0.2, if i == 1 then 1.8 else 1.1, if i == 1 then 1.8 else 1.1),
				CFrame.new(x * 0.86, y, 1.76) * CFrame.Angles(0, math.rad(90), 0), Color3.fromRGB(70, 70, 78), nil,
				{ shape = "Cylinder" })
		end
	end
	b:decor("TrussBeam", Vector3.new(22, 1, 1), Vector3.new(0, 13, 6), STEEL, M.Metal)
	for i, x in ipairs({ -7, -2.5, 2.5, 7 }) do
		local colour = RAINBOW[(i * 2) % #RAINBOW + 1]
		b:decor("SpotBody", Vector3.new(1.4, 1, 1), CFrame.new(x, 12, 5.4) * CFrame.Angles(math.rad(-50), 0, 0), black)
		b:decor("SpotLens", Vector3.new(0.1, 0.8, 0.8), CFrame.new(x, 11.7, 4.9) * CFrame.Angles(math.rad(-50), math.rad(90), 0),
			colour, nil, { shape = "Cylinder" })
		b:light("Spot", CFrame.new(x, 11.6, 4.8) * CFrame.Angles(math.rad(-140), 0, 0), colour, 1.2, 22, { Angle = 50 })
	end
	-- A mic stand at the front.
	b:decor("MicBase", Vector3.new(0.12, 1, 1), vertical(Vector3.new(0, H + 0.26, -3)), black, nil, { shape = "Cylinder" })
	b:decor("MicStand", Vector3.new(0.12, 4, 0.12), Vector3.new(0, H + 2.2, -3), black)
	b:decor("Mic", Vector3.new(0.4, 0.4, 0.7), Vector3.new(0, H + 4.3, -3.2), Color3.fromRGB(180, 180, 186), M.Metal)
end

--- THE PARK: a lawn with a curving path from the street, round trees, flowers and long grass,
--- the rainbow waterfall against the west wall, and the star stage at the far end with
--- benches facing it and cafe tables to the side. Origin at the park's centre on the pavement;
--- X across (the west wall at -X), Z along (the street at -Z).
local function park(b: Kit.Builder, halfX: number, halfZ: number)
	-- Lawn top 0.09, path edging 0.11, path 0.13: each a clear step over the one below.
	b:decor("Lawn", Vector3.new(halfX * 2, 0.1, halfZ * 2), Vector3.new(0, 0.04, 0), GRASS, M.Grass)
	curvedPath(b, {
		Vector3.new(0, 0, -halfZ), Vector3.new(4, 0, -32), Vector3.new(6, 0, -20), Vector3.new(3, 0, -8),
		Vector3.new(2, 0, 4), Vector3.new(3, 0, 14), Vector3.new(4, 0, 20),
	}, 5, PLAZA_A)
	curvedPath(b, { Vector3.new(3, 0, -8), Vector3.new(12, 0, -4), Vector3.new(halfX, 0, 2) }, 4, PLAZA_A)

	rainbowFalls(b:within(CFrame.new(-10, 0, -2)))
	starStage(b:within(CFrame.new(5, 0, 31)))

	-- Two benches facing the stage, one by the path, one table under an umbrella: the lawn is
	-- the point, so it is left mostly lawn.
	for _, spot in ipairs({ { -7, 15 }, { 13, 15 } }) do
		bench(b:within(CFrame.new(spot[1], 0, spot[2]) * CFrame.Angles(0, math.pi, 0)))
	end
	bench(b:within(CFrame.new(10, 0, -24) * CFrame.Angles(0, math.rad(90), 0)))
	cafeTable(b:within(CFrame.new(15, 0, -12)), Color3.fromRGB(236, 88, 96))

	-- Round trees, flowers and grass.
	for i, spot in ipairs({ { -13, -34 }, { 14, -36 }, { -8, -20 }, { 17, -24 }, { -17, 24 }, { -16, 38 }, { 18, 40 },
		{ 19, 31 } }) do
		tree(b:within(CFrame.new(spot[1], 0.1, spot[2])), 300 + i, i == 3 or i == 6, true)
	end
	local rng = Random.new(505)
	for i = 1, 8 do
		local at = Vector3.new(rng:NextNumber(-halfX + 2, halfX - 2), 0.1, rng:NextNumber(-halfZ + 2, halfZ - 2))
		if math.abs(at.X - 4) > 5 and (at - Vector3.new(-10, 0.1, -2)).Magnitude > 13 and (at - Vector3.new(5, 0.1, 31)).Magnitude > 14 then
			flowerClump(b:within(CFrame.new(at)), FLOWERS[(i % #FLOWERS) + 1], i)
		end
	end
	for i = 1, 18 do
		local at = Vector3.new(rng:NextNumber(-halfX + 1, halfX - 1), 0.1, rng:NextNumber(-halfZ + 1, halfZ - 1))
		if math.abs(at.X - 4) > 4 then
			grassTuft(b:within(CFrame.new(at)), i)
		end
	end

	-- Low hedges round the edges, open to the street and at the side gate.
	b:part("Hedge", Vector3.new(halfX * 2 - 0.2, 2, 1.4), Vector3.new(0, 1.04, halfZ - 0.8), HEDGE)
	b:part("Hedge", Vector3.new(1.4, 2, halfZ - 12.2), Vector3.new(-halfX + 0.8, 1.04, -halfZ / 2 - 5.9), HEDGE)
	b:part("Hedge", Vector3.new(1.4, 2, halfZ - 16.2), Vector3.new(-halfX + 0.8, 1.04, halfZ / 2 + 7.9), HEDGE)
	b:part("Hedge", Vector3.new(1.4, 2, halfZ - 4.2), Vector3.new(halfX - 0.8, 1.04, -halfZ / 2 - 2), HEDGE)
	b:part("Hedge", Vector3.new(1.4, 2, halfZ - 12.2), Vector3.new(halfX - 0.8, 1.04, halfZ / 2 + 6), HEDGE)
	for _, spot in ipairs({ { -7, -38 }, { 9, -14 }, { -4, 6 }, { 11, 24 } }) do
		postLamp(b:within(CFrame.new(spot[1], 0, spot[2])))
	end
	bin(b:within(CFrame.new(8, 0, -30)))
	-- The park's name over the gate from the street.
	for _, x in ipairs({ -4.5, 4.5 }) do
		b:part("GatePost", Vector3.new(1.2, 9, 1.2), Vector3.new(x, 4.5, -halfZ + 1), IRON)
		b:decor("GateCap", Vector3.new(1.6, 0.6, 1.6), Vector3.new(x, 9.3, -halfZ + 1), GOLD)
	end
	b:decor("GateBeam", Vector3.new(10.4, 0.6, 0.6), Vector3.new(0, 8.4, -halfZ + 1), IRON)
	board(b, "RAINBOW PARK", Kit.Look(Vector3.new(0, 7.2, -halfZ + 0.6), Vector3.new(0, 7.2, -halfZ - 10)), 9, 1.6,
		Color3.fromRGB(96, 170, 80), TRIM)
end

-- ----------------------------------------------------------- street kit --

local SIGNAL_BLACK = Color3.fromRGB(30, 32, 36)

--- A traffic light on the kerb: a pole with a mast arm reaching over the road (-X), a signal
--- head at its end showing both ways (red, amber, green -- green on), a crossing signal on the
--- pole, and street-name blades on top. Origin at road level, on the kerb.
local function trafficLight(b: Kit.Builder, avenueName: string, streetName: string)
	b:part("SignalBase", Vector3.new(1.3, 0.8, 1.3), Vector3.new(0, 0.9, 0), SIGNAL_BLACK)
	b:part("SignalPole", Vector3.new(15, 0.55, 0.55), vertical(Vector3.new(0, 8, 0)), SIGNAL_BLACK, nil, { shape = "Cylinder" })
	b:decor("MastArm", Vector3.new(9, 0.4, 0.4), Vector3.new(-4.5, 14.6, 0), SIGNAL_BLACK)
	local brace, len = Kit.Span(Vector3.new(0, 12.6, 0), Vector3.new(-3.5, 14.4, 0))
	b:decor("MastBrace", Vector3.new(0.2, 0.2, len), brace, SIGNAL_BLACK)
	-- The head: a box, a visor over each lamp, lamps on both faces.
	local hx = -8.2
	b:decor("SignalHead", Vector3.new(1.2, 3.64, 1.1), Vector3.new(hx, 12.6, 0), Color3.fromRGB(236, 196, 40))
	b:decor("HeadBack", Vector3.new(1.5, 3.9, 0.2), Vector3.new(hx, 12.6, 0), SIGNAL_BLACK)
	for i, spec in ipairs({ { 13.7, Color3.fromRGB(120, 34, 34) }, { 12.6, Color3.fromRGB(130, 96, 30) },
		{ 11.5, Color3.fromRGB(80, 236, 120) } } :: { { any } }) do
		for _, face in ipairs({ -1, 1 }) do
			b:decor("SignalLamp", Vector3.new(0.16, 0.8, 0.8), CFrame.new(hx, spec[1], face * 0.62) * CFrame.Angles(0, math.rad(90), 0),
				spec[2], nil, { shape = "Cylinder" })
			if i == 3 then
				b:decor("Visor", Vector3.new(1, 0.14, 0.5), Vector3.new(hx, spec[1] + 0.52, face * 0.9), SIGNAL_BLACK)
			end
		end
	end
	-- The crossing signal on the pole, facing along the kerb.
	b:decor("WalkBox", Vector3.new(0.9, 1.3, 0.9), Vector3.new(0, 8.4, 0.72), SIGNAL_BLACK)
	b:decor("WalkLamp", Vector3.new(0.1, 0.7, 0.7), CFrame.new(0, 8.4, 1.2) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(250, 250, 244), nil, { shape = "Cylinder" })
	b:decor("PushButton", Vector3.new(0.4, 0.6, 0.3), Vector3.new(0.35, 4, 0.4), Color3.fromRGB(236, 196, 40))
	-- Street-name blades crossing on top.
	local green = Color3.fromRGB(34, 118, 76)
	b:decor("BladePost", Vector3.new(0.3, 2.6, 0.3), Vector3.new(0, 16.6, 0), SIGNAL_BLACK)
	b:decor("BladeX", Vector3.new(5.2, 0.9, 0.14), Vector3.new(-2, 16.2, 0), green)
	b:decor("BladeZ", Vector3.new(0.14, 0.9, 5.2), Vector3.new(0, 17.2, -2), green)
	for _, face in ipairs({ -1, 1 }) do
		b:sign(streetName, Kit.Look(Vector3.new(-2, 16.2, face * 0.09), Vector3.new(-2, 16.2, face * 10)), 4.8, 0.7, TRIM,
			{ lit = true, glow = false, font = Enum.Font.GothamBold, textColour = TRIM, brightness = 1 })
		b:sign(avenueName, Kit.Look(Vector3.new(face * 0.09, 17.2, -2), Vector3.new(face * 10, 17.2, -2)), 4.8, 0.7, TRIM,
			{ lit = true, glow = false, font = Enum.Font.GothamBold, textColour = TRIM, brightness = 1 })
	end
end

--- A red phone booth, its door toward -Z.
local function phoneBooth(b: Kit.Builder)
	local red = Color3.fromRGB(206, 44, 44)
	b:part("Booth", Vector3.new(3, 7.6, 3), Vector3.new(0, 3.8, 0), red)
	b:decor("BoothRoof", Vector3.new(3.4, 0.5, 3.4), Vector3.new(0, 7.85, 0), darker(red, 0.15))
	b:decor("BoothDome", Vector3.new(0.6, 2.6, 2.6), vertical(Vector3.new(0, 8.3, 0)), red, nil, { shape = "Cylinder" })
	for _, face in ipairs({ { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
		local fx, fz = face[1], face[2]
		local size = if fz ~= 0 then Vector3.new(2.2, 4.6, 0.12) else Vector3.new(0.12, 4.6, 2.2)
		b:decor("BoothGlass", size, Vector3.new(fx * 1.52, 3.8, fz * 1.52), Color3.fromRGB(180, 210, 230), M.Glass,
			{ transparency = 0.3 })
		local band = if fz ~= 0 then Vector3.new(2.4, 0.6, 0.14) else Vector3.new(0.14, 0.6, 2.4)
		b:decor("BoothBand", band, Vector3.new(fx * 1.53, 6.9, fz * 1.53), Color3.fromRGB(30, 30, 34))
		local at = Vector3.new(fx * 1.62, 6.9, fz * 1.62)
		painted(b, "PHONE", Kit.Look(at, at + Vector3.new(fx, 0, fz) * 10), 2, 0.45, TRIM, Enum.Font.GothamBold)
	end
end

--- A billboard on a roof: legs, a catwalk, a framed board with the ad painted on it. `at`
--- stands on the roof and looks the way the ad faces.
local function billboard(b: Kit.Builder, at: CFrame, w: number, h: number, bg: Color3, fg: Color3, text: string,
	sub: string?)
	local s = b:within(at)
	for _, x in ipairs({ -w / 3, w / 3 }) do
		s:decor("BillboardLeg", Vector3.new(0.6, 4.2, 0.6), Vector3.new(x, 2.1, 0.8), STEEL, M.Metal)
		local cf, len = Kit.Span(Vector3.new(x, 0.2, 2.6), Vector3.new(x, 4, 0.9))
		s:decor("BillboardStrut", Vector3.new(0.3, 0.3, len), cf, STEEL, M.Metal)
	end
	s:decor("Catwalk", Vector3.new(w, 0.2, 1.2), Vector3.new(0, 3.9, -0.2), STEEL, M.DiamondPlate)
	s:decor("BillboardFrame", Vector3.new(w + 0.8, h + 0.8, 0.4), Vector3.new(0, 4.4 + h / 2, 0.6), darker(bg, 0.45))
	s:decor("BillboardFace", Vector3.new(w, h, 0.4), Vector3.new(0, 4.4 + h / 2, 0.45), bg)
	s:decor("BillboardStripe", Vector3.new(w - 0.1, h * 0.16, 0.44), Vector3.new(0, 4.4 + h * 0.1, 0.44), fg)
	s:sign(text, Kit.Look(Vector3.new(0, 4.4 + h * 0.6, 0.22), Vector3.new(0, 4.4 + h * 0.6, -10)), w * 0.9, h * 0.5, fg,
		{ lit = true, glow = false, font = Enum.Font.FredokaOne, textColour = fg, brightness = 1 })
	if sub then
		s:sign(sub, Kit.Look(Vector3.new(0, 4.4 + h * 0.1, 0.2), Vector3.new(0, 4.4 + h * 0.1, -10)), w * 0.8, h * 0.13, bg,
			{ lit = true, glow = false, font = Enum.Font.GothamBlack, textColour = bg, brightness = 1 })
	end
end

--- A street-food truck parked with its serving hatch toward -Z: a boxy body, a cab at -X, a
--- striped awning over the hatch, a menu board, and its name on a sign on the roof.
local function foodTruck(b: Kit.Builder, colour: Color3, name: string, accent: Color3)
	local trim = Color3.fromRGB(34, 34, 38)
	b:part("TruckBody", Vector3.new(11, 6, 6), Vector3.new(1.5, 4, 0), colour)
	b:part("TruckCab", Vector3.new(4, 4.6, 5.8), Vector3.new(-5.5, 3.3, 0), colour)
	b:decor("Windshield", Vector3.new(0.12, 2, 5), CFrame.new(-7.52, 4.3, 0), Color3.fromRGB(60, 84, 110), M.Glass,
		{ reflectance = 0.25 })
	for _, z in ipairs({ -2.93, 2.93 }) do
		b:decor("CabWindow", Vector3.new(2.6, 1.7, 0.08), Vector3.new(-5.4, 4.4, z), Color3.fromRGB(60, 84, 110), M.Glass)
	end
	b:decor("Bumper", Vector3.new(0.4, 0.7, 6), Vector3.new(-7.7, 1.4, 0), trim)
	for _, x in ipairs({ -5.4, 4.2 }) do
		for _, z in ipairs({ -2.7, 2.7 }) do
			b:decor("Wheel", Vector3.new(0.8, 2.2, 2.2), CFrame.new(x, 1.1, z) * CFrame.Angles(0, math.rad(90), 0), trim,
				M.Rubber, { shape = "Cylinder" })
			b:decor("Hub", Vector3.new(0.84, 1, 1), CFrame.new(x, 1.1, z) * CFrame.Angles(0, math.rad(90), 0),
				Color3.fromRGB(206, 206, 210), M.Metal, { shape = "Cylinder" })
		end
	end
	-- The hatch, open, with a counter and the menu.
	b:decor("Hatch", Vector3.new(6, 2.6, 0.1), Vector3.new(1.5, 4.9, -3.02), Color3.fromRGB(40, 36, 34))
	b:decor("Counter", Vector3.new(6.4, 0.3, 1), Vector3.new(1.5, 3.5, -3.4), TRIM)
	for k = 0, 5 do
		-- Tall at its +Z end, against the truck; sloping down and out over the counter.
		b:decor("TruckAwning", Vector3.new(1.1, 0.9, 2), CFrame.new(-1.25 + k * 1.1, 6.9, -3.9),
			if k % 2 == 0 then accent else TRIM, M.Fabric, { shape = "Wedge" })
	end
	b:decor("Stripe", Vector3.new(11.06, 0.6, 6.06), Vector3.new(1.5, 2.2, 0), accent)
	board(b, name, Kit.Look(Vector3.new(1.5, 8.2, -0.6), Vector3.new(1.5, 8.2, -10)), 7.5, 1.6, accent, TRIM)
	b:decor("SignPost", Vector3.new(0.3, 1.2, 0.3), Vector3.new(-1.2, 7.4, -0.2), trim)
	b:decor("SignPost", Vector3.new(0.3, 1.2, 0.3), Vector3.new(4.2, 7.4, -0.2), trim)
	b:decor("MenuBoard", Vector3.new(0.3, 2.4, 1.8), CFrame.new(6.6, 1.3, -4.4) * CFrame.Angles(0, 0, math.rad(8)), trim)
	painted(b, "MENU", Kit.Look(Vector3.new(6.78, 1.9, -4.4), Vector3.new(16, 1.9, -4.4)), 1.5, 0.45, TRIM,
		Enum.Font.GothamBold)
end

--- An ice-cream van: pastel, a big cone on the roof, the hatch toward -Z.
local function iceCreamVan(b: Kit.Builder)
	foodTruck(b, Color3.fromRGB(250, 236, 226), "ICE CREAM", Color3.fromRGB(240, 128, 170))
	b:decor("ConeBase", Vector3.new(1.6, 1.4, 1.4), vertical(Vector3.new(3.5, 7.75, 1.6)), Color3.fromRGB(214, 164, 96), nil,
		{ shape = "Cylinder" })
	b:decor("ConeMid", Vector3.new(1.2, 2, 2), vertical(Vector3.new(3.5, 9.1, 1.6)), Color3.fromRGB(226, 176, 104), nil,
		{ shape = "Cylinder" })
	b:decor("Scoop", Vector3.new(2.6, 2.4, 2.6), Vector3.new(3.5, 10.6, 1.6), Color3.fromRGB(250, 196, 214), nil,
		{ shape = "Ball" })
	b:decor("Scoop", Vector3.new(2, 1.8, 2), Vector3.new(3.5, 11.9, 1.6), Color3.fromRGB(140, 220, 180), nil,
		{ shape = "Ball" })
	b:decor("Cherry", Vector3.new(0.7, 0.7, 0.7), Vector3.new(3.5, 13, 1.6), Color3.fromRGB(220, 40, 60), nil,
		{ shape = "Ball" })
end

--- The ZEE BANK armoured truck, parked: a cab and a riveted strongbox on three axles, the bank's
--- gold band and name down both sides, a light bar on the cab, and the double doors at the
--- back with the vault lock between them -- a stick-up target (StickupService "truck": a long
--- hold, a big bag, and a bigger squad). Its own Model, so the robbery can swing its doors
--- open. Faces -Z; origin on the road.
local function armouredTruck(b: Kit.Builder)
	local model = Instance.new("Model")
	model.Name = "ArmouredTruck"
	model.Parent = b.parent
	local m = Kit.new(model, b.frame)
	local armour = Color3.fromRGB(70, 82, 96)
	local panel = darker(armour, 0.18)
	local dark = Color3.fromRGB(26, 28, 32)
	m:part("TruckBox", Vector3.new(6.6, 7.2, 10.5), Vector3.new(0, 5.0, 2.25), armour, M.DiamondPlate)
	m:part("TruckCab", Vector3.new(6.2, 5.2, 4.5), Vector3.new(0, 4.0, -5.25), armour, M.Metal)
	m:decor("Chassis", Vector3.new(5.8, 1, 15), Vector3.new(0, 1.3, 0), dark)
	m:decor("CabRoof", Vector3.new(6.3, 0.3, 4.6), Vector3.new(0, 6.75, -5.25), panel)
	-- The cab: a barred windscreen, side windows, the grille, the bumper and the lamps.
	m:decor("Windscreen", Vector3.new(5.6, 2.2, 0.12), Vector3.new(0, 5.1, -7.52), CAR_GLASS, M.Glass, { reflectance = 0.25 })
	for _, x in ipairs({ -1.4, 0, 1.4 }) do
		m:decor("ScreenBar", Vector3.new(0.14, 2.2, 0.1), Vector3.new(x, 5.1, -7.6), dark)
	end
	for _, x in ipairs({ -1, 1 }) do
		m:decor("CabWindow", Vector3.new(0.08, 1.6, 2.2), Vector3.new(x * 3.12, 5.2, -5.4), CAR_GLASS, M.Glass)
		m:decor("Mirror", Vector3.new(0.3, 0.9, 0.5), Vector3.new(x * 3.45, 5.0, -7.0), dark)
		m:decor("Headlight", Vector3.new(1, 0.6, 0.08), Vector3.new(x * 2.3, 3.1, -7.56), Color3.fromRGB(250, 246, 226), M.Glass)
		m:decor("Taillight", Vector3.new(0.6, 1, 0.08), Vector3.new(x * 2.9, 2.6, 7.54), Color3.fromRGB(200, 40, 40), M.Glass)
	end
	m:decor("Grille", Vector3.new(4.4, 1.6, 0.1), Vector3.new(0, 2.6, -7.55), dark)
	m:decor("Bumper", Vector3.new(6.6, 0.8, 0.5), Vector3.new(0, 1.5, -7.75), dark)
	m:decor("RearBumper", Vector3.new(6.6, 0.6, 0.5), Vector3.new(0, 1.4, 7.75), dark)
	m:decor("Step", Vector3.new(4.6, 0.3, 0.8), Vector3.new(0, 1.9, 8.0), STEEL, M.DiamondPlate)
	-- The light bar on the cab.
	m:decor("LightBar", Vector3.new(3, 0.4, 0.7), Vector3.new(0, 7.1, -5.6), dark)
	for _, x in ipairs({ -1, 1 }) do
		m:decor("Beacon", Vector3.new(0.7, 0.45, 0.6), Vector3.new(x * 1.1, 7.35, -5.6), Color3.fromRGB(255, 170, 40), M.Glass)
	end
	-- The strongbox: riveted ribs, the gold band, the name on both sides, a roof hatch.
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1.6, 1.4, 4.4 }) do
			m:decor("Rib", Vector3.new(0.14, 4.6, 0.32), Vector3.new(x * 3.37, 6.15, z), panel)
		end
		local at = Vector3.new(x * 3.42, 6.6, 2.25)
		painted(m, "ZEE BANK", Kit.Look(at, at + Vector3.new(x * 10, 0, 0)), 7, 1.3, GOLD, Enum.Font.GothamBlack)
		local sub = Vector3.new(x * 3.42, 4.4, 2.25)
		painted(m, "SECURE TRANSPORT", Kit.Look(sub, sub + Vector3.new(x * 10, 0, 0)), 6, 0.5, CREAM, Enum.Font.GothamBold)
	end
	m:decor("Band", Vector3.new(6.74, 0.9, 10.6), Vector3.new(0, 3.3, 2.25), GOLD, M.Metal)
	m:decor("RoofHatch", Vector3.new(2.4, 0.3, 2.4), Vector3.new(0, 8.75, 3.5), panel)
	-- The back: a dark frame, two heavy doors, their hinges and handles, and the vault lock.
	m:decor("DoorFrame", Vector3.new(6.4, 6.8, 0.15), Vector3.new(0, 5.0, 7.55), dark)
	for _, x in ipairs({ -1, 1 }) do
		m:decor(if x < 0 then "TruckDoorL" else "TruckDoorR", Vector3.new(3.0, 6.4, 0.22), Vector3.new(x * 1.55, 5.0, 7.7),
			lighter(armour, 0.08), M.DiamondPlate)
		for _, y in ipairs({ 3, 7 }) do
			m:decor("Hinge", Vector3.new(0.3, 0.6, 0.3), Vector3.new(x * 3.1, y, 7.75), dark)
		end
		m:decor("DoorHandle", Vector3.new(0.2, 1.2, 0.2), Vector3.new(x * 0.6, 5.0, 7.88), CAR_CHROME, M.Metal)
	end
	local lock = m:part("TruckVault", Vector3.new(1.1, 1.1, 0.4), Vector3.new(0, 6.2, 7.95), GOLD, M.Metal)
	stickup(lock, "the ZEE BANK truck", "truck")
	m:decor("LockWheel", Vector3.new(0.12, 0.9, 0.9), CFrame.new(0, 6.2, 8.2) * CFrame.Angles(0, math.rad(90), 0), STEEL, M.Metal,
		{ shape = "Cylinder" })
	model.PrimaryPart = lock
	wheels(m, 3.0, { -5.0, 1.2, 4.6 }, 1.4)
	return model
end

--- A bus shelter at the kerb: glass back and sides on a steel frame, a roof with a lip, a
--- bench inside, a lit advert panel on one end and the stop's sign on a pole. Faces -Z (the
--- road); origin on the pavement at its middle.
local function busShelter(b: Kit.Builder, stopName: string)
	local frame = Color3.fromRGB(52, 58, 66)
	for _, x in ipairs({ -4, 4 }) do
		for _, z in ipairs({ -1.3, 1.3 }) do
			b:part("ShelterPost", Vector3.new(0.3, 7, 0.3), Vector3.new(x, 3.5, z), frame, M.Metal)
		end
	end
	b:part("ShelterRoof", Vector3.new(9, 0.35, 3.4), Vector3.new(0, 7.15, -0.1), frame, M.Metal)
	b:decor("ShelterLip", Vector3.new(9.1, 0.5, 0.15), Vector3.new(0, 7.0, -1.85), TEAL)
	b:part("ShelterBack", Vector3.new(8, 5.6, 0.15), Vector3.new(0, 3.6, 1.3), Color3.fromRGB(170, 200, 214), M.Glass,
		{ transparency = 0.55, reflectance = 0.15 })
	b:part("ShelterSide", Vector3.new(0.15, 5.6, 2.4), Vector3.new(-4, 3.6, 0.1), Color3.fromRGB(170, 200, 214), M.Glass,
		{ transparency = 0.55, reflectance = 0.15 })
	-- The advert: a lit panel in a frame at the other end.
	b:part("AdFrame", Vector3.new(0.5, 5.8, 2.6), Vector3.new(4, 3.6, 0.1), frame, M.Metal)
	b:decor("AdPanel", Vector3.new(0.12, 5, 2.1), Vector3.new(4.3, 3.6, 0.1), Color3.fromRGB(250, 196, 70))
	painted(b, "ZEE COLA", Kit.Look(Vector3.new(4.37, 4.6, 0.1), Vector3.new(10, 4.6, 0.1)), 2, 0.6, RED)
	painted(b, "ICE COLD", Kit.Look(Vector3.new(4.37, 3.2, 0.1), Vector3.new(10, 3.2, 0.1)), 1.8, 0.4, NAVY, Enum.Font.GothamBold)
	-- The bench inside, against the glass.
	b:part("ShelterBench", Vector3.new(6, 0.25, 1), Vector3.new(-0.4, 1.9, 0.6), WOOD, M.WoodPlanks)
	for _, x in ipairs({ -3, 2.2 }) do
		b:decor("BenchLeg", Vector3.new(0.2, 1.8, 0.8), Vector3.new(x, 0.9, 0.6), frame, M.Metal)
	end
	-- The stop's sign on its own pole at the kerb.
	b:part("StopPole", Vector3.new(0.25, 9, 0.25), Vector3.new(-5.4, 4.5, -1.3), frame, M.Metal)
	b:decor("StopSign", Vector3.new(1.6, 1.6, 0.12), Vector3.new(-5.4, 8.2, -1.3), TEAL)
	painted(b, "BUS", Kit.Look(Vector3.new(-5.4, 8.45, -1.37), Vector3.new(-5.4, 8.45, -10)), 1.3, 0.5, CREAM)
	painted(b, stopName, Kit.Look(Vector3.new(-5.4, 7.85, -1.37), Vector3.new(-5.4, 7.85, -10)), 1.4, 0.3, CREAM,
		Enum.Font.GothamBold)
end

local function manhole(b: Kit.Builder)
	b:decor("Manhole", Vector3.new(0.05, 2.6, 2.6), vertical(Vector3.new(0, 0.035, 0)), Color3.fromRGB(58, 58, 64), M.DiamondPlate,
		{ shape = "Cylinder" })
end

--- The welcome wall across the south end, behind where travellers arrive: a low stone wall
--- with the district's name on it, piers with lanterns, flower beds in front.
local function welcomeWall(b: Kit.Builder)
	local W = 84      -- it stands against the district's south edge, behind the car park and offices
	b:part("Wall", Vector3.new(W, 9, 2.4), Vector3.new(0, 4.5, 0), STONE)
	b:decor("WallCap", Vector3.new(W + 0.6, 0.6, 3), Vector3.new(0, 9.3, 0), STONE_LIGHT)
	b:decor("Plinth", Vector3.new(W + 0.4, 1.2, 2.8), Vector3.new(0, 0.6, 0), darker(STONE, 0.15))
	for _, x in ipairs({ -W / 2, -14, 14, W / 2 }) do
		b:part("Pier", Vector3.new(3, 12, 3), Vector3.new(x, 6, 0), STONE_LIGHT)
		b:decor("PierCap", Vector3.new(3.6, 0.6, 3.6), Vector3.new(x, 12.3, 0), STONE)
		b:decor("LanternGlass", Vector3.new(1.3, 1.6, 1.3), Vector3.new(x, 13.4, 0), LAMP_GLASS)
		b:decor("LanternCap", Vector3.new(1.8, 0.4, 1.8), Vector3.new(x, 14.4, 0), IRON)
	end
	b:light("Point", Vector3.new(0, 10, 3), WARM, 1.1, 30)
	board(b, "DOWNTOWN", Kit.Look(Vector3.new(0, 5.6, 1.6), Vector3.new(0, 5.6, 10)), 22, 4.4, TEAL, CREAM)
	painted(b, "SHOP  ·  EAT  ·  DUEL", Kit.Look(Vector3.new(0, 2.4, 1.25), Vector3.new(0, 2.4, 10)), 16, 1, NAVY,
		Enum.Font.GothamBold)
	for _, x in ipairs({ -21, 21 }) do
		flowerBed(b:within(CFrame.new(x, 0, 3.4)), 11, 3, x > 0 and 2 or 0)
	end
end

-- ------------------------------------------------------------------- build --

function Downtown.Build(parent: Instance, centre: Vector3)
	local root = Kit.new(parent, CFrame.new(centre))
	local HW = Downtown.HalfWidth

	-- The district's own look while you are in it (ArenaMood reads these): punchier colour and
	-- a sky of big puffy clouds, like the reference street. The time of day stays the world's.
	parent:SetAttribute("ZoneCentre", centre + Vector3.new(0, 90, 0))
	parent:SetAttribute("ZoneHalf", Vector3.new(HW + 40, 130, HW + 40))
	for group, values in pairs(Downtown.Look) do
		for property, value in pairs(values) do
			parent:SetAttribute(("Look_%s_%s"):format(group, property), value)
		end
	end

	-- The ground: asphalt everywhere, kerb-level paving laid over it block by block.
	root:part("Asphalt", Vector3.new(HW * 2 + 120, 2, HW * 2 + 120), Vector3.new(0, -1, 0), ASPHALT, M.Asphalt)
	local ROAD = 18                  -- half the road width
	local WALK = 10                  -- pavement strip along each road
	local PLAZA = 40                 -- half the plaza

	-- The four blocks, each a paved slab with kerbs where it meets the roads.
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local x0, x1 = ROAD, HW + 40
			local z0, z1 = ROAD, HW + 40
			if sx < 0 then
				x0, x1 = -(HW + 40), -ROAD
			end
			if sz < 0 then
				z0, z1 = -(HW + 40), -ROAD
			end
			pavement(root, x0, x1, z0, z1, SIDEWALK, { sx > 0 and "-x" or "+x", sz > 0 and "-z" or "+z" })
			-- A darker strip marks the walk along each road.
			local wx = sx > 0 and ROAD + WALK / 2 or -(ROAD + WALK / 2)
			local wz = sz > 0 and ROAD + WALK / 2 or -(ROAD + WALK / 2)
			root:decor("Walk", Vector3.new(WALK, 0.04, z1 - z0), Vector3.new(wx, 0.52, (z0 + z1) / 2), SIDEWALK_EDGE, M.Concrete)
			root:decor("Walk", Vector3.new(x1 - x0, 0.04, WALK), Vector3.new((x0 + x1) / 2, 0.52, wz), SIDEWALK_EDGE, M.Concrete)
		end
	end
	plaza(root, PLAZA)

	-- Road markings on the four arms, crossings where they meet the plaza.
	markings(root, PLAZA + 12, HW, true)
	markings(root, -HW + 50, -(PLAZA + 12), true)
	markings(root, PLAZA + 12, HW, false)
	markings(root, -HW, -(PLAZA + 12), false)
	for _, s in ipairs({ -1, 1 }) do
		crosswalk(root, s * (PLAZA + 6), true)
		crosswalk(root, s * (PLAZA + 6), false)
	end

	-- The arrival forecourt at the south end of the avenue, where travellers land.
	pavement(root, -ROAD, ROAD, -HW - 40, -HW + 48, PLAZA_B, { "+z" })
	root:decor("Forecourt", Vector3.new(ROAD * 2 - 2, 0.04, 40), Vector3.new(0, 0.52, -HW + 24), PLAZA_A, M.Slate)
	welcomeWall(root:within(CFrame.new(0, 0.5, -HW + 13)))
	-- An overhead sign across the avenue pointing the way.
	for _, s in ipairs({ -1, 1 }) do
		root:part("SignPost", Vector3.new(1, 20, 1), Vector3.new(s * (ROAD + 2), 10.5, -HW + 62), IRON)
	end
	root:decor("Gantry", Vector3.new(ROAD * 2 + 5, 1, 1), Vector3.new(0, 19, -HW + 62), IRON)
	local sign = root:within(CFrame.new(0, 15.6, -HW + 61.4))
	-- Each layer a clear step proud of the one behind, on both faces. They were a hundredth of
	-- a stud apart, which the depth buffer cannot tell apart past a few studs.
	sign:decor("Board", Vector3.new(34, 6, 0.4), Vector3.new(0, 0, 0), Color3.fromRGB(34, 118, 76))
	sign:decor("Border", Vector3.new(33, 5.2, 0.5), Vector3.new(0, 0, 0), Color3.fromRGB(240, 240, 236))
	sign:decor("Inner", Vector3.new(32.4, 4.6, 0.6), Vector3.new(0, 0, 0), Color3.fromRGB(34, 118, 76))
	sign:sign("↑ ZEE PLAZA     ↖ DUEL HALL     ↗ COURTS", Kit.Look(Vector3.new(0, 0.9, -0.3), Vector3.new(0, 0.9, -10)),
		31, 1.8, Color3.new(1, 1, 1), { lit = true, glow = false, font = Enum.Font.GothamBold, brightness = 1.2 })
	sign:sign("← ZEE GAS  ·  24/7         ZEE GUNS  ·  TACTICS →", Kit.Look(Vector3.new(0, -1.3, -0.3), Vector3.new(0, -1.3, -10)),
		31, 1.6, Color3.new(1, 1, 1), { lit = true, glow = false, font = Enum.Font.GothamBold, brightness = 1.2 })
	-- A bus shelter on the forecourt.
	local shelter = root:within(CFrame.new(-ROAD + 4, 0.5, -HW + 36))
	shelter:part("Roof", Vector3.new(5, 0.4, 12), Vector3.new(0, 8, 0), TEAL)
	shelter:decor("RoofTrim", Vector3.new(5.2, 0.3, 12.2), Vector3.new(0, 8.3, 0), CREAM)
	for _, z in ipairs({ -5.6, 5.6 }) do
		shelter:part("ShelterPost", Vector3.new(0.4, 7.6, 0.4), Vector3.new(-2.2, 4, z), IRON)
	end
	shelter:decor("BackGlass", Vector3.new(0.2, 6.6, 11), Vector3.new(-2.4, 4.2, 0), GLASS, M.Glass, { transparency = 0.5 })
	shelter:decor("Ad", Vector3.new(0.3, 5.6, 3.6), Vector3.new(-2.2, 4.2, 3.6), Color3.fromRGB(248, 246, 240))
	shelter:decor("AdBand", Vector3.new(0.36, 1.4, 3.66), Vector3.new(-2.2, 2.2, 3.6), RED)
	painted(shelter, "ZEE COLA", Kit.Look(Vector3.new(-2, 5.4, 3.6), Vector3.new(10, 5.4, 3.6)), 3.2, 1.2, RED)
	bench(shelter:within(CFrame.new(-1, -0.5, -1.5) * CFrame.Angles(0, math.rad(-90), 0)))

	-- Street furniture, on a rhythm: a lamp every 30 studs, a tree between, the odd hydrant
	-- and bin. Lamps on both sides of every arm, arms reaching over the road. The avenue
	-- has green trees and teal banners, the cross street pink blossom and red banners.
	local doors = {
		{ 16, 32, -72, -56 }, { 16, 32, -118, -102 },     -- ZEE GUNS, ZEE TACTICS
		{ -32, -16, 64, 112 },                             -- the DUEL HALL's opening
	}
	local function clear(p: Vector3): boolean
		for _, r in ipairs(doors) do
			if p.X >= r[1] and p.X <= r[2] and p.Z >= r[3] and p.Z <= r[4] then
				return false
			end
		end
		return true
	end
	local count = 0
	for _, arm in ipairs({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
		local ax, az = arm[1], arm[2]
		local avenue = ax == 0
		for d = PLAZA + 20, HW - 10, 30 do
			if not (az == -1 and d > HW - 60) then
				for _, side in ipairs({ -1, 1 }) do
					count += 1
					local off = ROAD + 2
					local p: Vector3
					local yaw: number
					if ax == 0 then
						p = Vector3.new(side * off, 0, az * d)
						yaw = side > 0 and 0 or 180
					else
						p = Vector3.new(ax * d, 0, side * off)
						yaw = side > 0 and -90 or 90
					end
					-- A banner on every other lamp: the avenue's teal, the cross street's red.
					lamp(root:within(CFrame.new(p) * CFrame.Angles(0, math.rad(yaw), 0)), count % 2 == 0,
						if count % 4 < 2 then (if avenue then TEAL else RED) else nil)
					local t = ax == 0 and Vector3.new(side * (off + 4), 0, az * (d + 15))
						or Vector3.new(ax * (d + 15), 0, side * (off + 4))
					if clear(t) then
						tree(root:within(CFrame.new(t)), count, not avenue)
					end
					if count % 4 == 1 then
						local h = ax == 0 and Vector3.new(side * (off + 1), 0, az * (d + 6))
							or Vector3.new(ax * (d + 6), 0, side * (off + 1))
						if clear(h) then
							hydrant(root:within(CFrame.new(h)))
						end
					elseif count % 4 == 3 then
						local h = ax == 0 and Vector3.new(side * (off + 1), 0, az * (d + 8))
							or Vector3.new(ax * (d + 8), 0, side * (off + 1))
						if clear(h) then
							bin(root:within(CFrame.new(h)))
						end
					end
				end
			end
		end
	end

	-- A few parked cars along the kerbs, well spaced, never in front of a door: enough that
	-- the street is lived in, few enough that the kerb still reads as a clean line.
	local carIndex = 0
	local function parkRow(alongZ: boolean, across: number, from: number, to: number, step: number, facing: number)
		for d = from, to, step do
			carIndex += 1
			local colour = CAR_COLOURS[(carIndex * 3) % #CAR_COLOURS + 1]
			local cf = alongZ and (CFrame.new(across, 0, d) * CFrame.Angles(0, math.rad(facing), 0))
				or (CFrame.new(d, 0, across) * CFrame.Angles(0, math.rad(facing), 0))
			car(root:within(cf), colour, CAR_KINDS[(carIndex - 1) % #CAR_KINDS + 1])
		end
	end
	parkRow(true, 14.5, 80, 180, 54, 180)
	parkRow(true, -14.5, -150, -70, 54, 0)
	parkRow(false, 14.5, 80, 170, 66, 90)
	parkRow(false, -14.5, -180, -70, 66, -90)

	-- ------------------------------------------------------------ street kit --

	-- A traffic light where each arm meets the plaza crossing, the street names on top: one per
	-- arm, on the right-hand kerb, so the corners stay open.
	for _, arm in ipairs({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
		local ax, az = arm[1], arm[2]
		for _, side in ipairs({ 1 }) do
			local d = PLAZA + 10
			if ax == 0 then
				trafficLight(root:within(CFrame.new(side * (ROAD + 1.5), 0, az * d) * CFrame.Angles(0, math.rad(side > 0 and 0 or 180), 0)),
					"ZEE AVE", "MAIN ST")
			else
				trafficLight(root:within(CFrame.new(ax * d, 0, side * (ROAD + 1.5)) * CFrame.Angles(0, math.rad(side > 0 and -90 or 90), 0)),
					"MAIN ST", "ZEE AVE")
			end
		end
	end

	-- Along the walks, on the building side, a little street furniture -- a bench, a planter, a
	-- phone booth -- one piece every so often, alternating sides, so the walks stay clear to run.
	local kitCount = 0
	for _, arm in ipairs({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
		local ax, az = arm[1], arm[2]
		for i, d in ipairs({ 97, 157 }) do
			if not (az == -1 and d > HW - 60) then
				for _, side in ipairs({ if i == 1 then 1 else -1 }) do
					kitCount += 1
					local off = ROAD + WALK - 2.5
					local p: Vector3
					local yaw: number
					if ax == 0 then
						p = Vector3.new(side * off, 0.51, az * d)
						yaw = side > 0 and 90 or -90
					else
						p = Vector3.new(ax * d, 0.51, side * off)
						yaw = side > 0 and 0 or 180
					end
					if clear(p) then
						local k = root:within(CFrame.new(p) * CFrame.Angles(0, math.rad(yaw), 0))
						local pick = kitCount % 3
						if pick == 1 then
							bench(k:within(CFrame.new(0, -0.51, 0)))
						elseif pick == 2 then
							flowerBed(k:within(CFrame.new(0, -0.01, 0)), 6, 2.4, kitCount)
						else
							phoneBooth(k)
						end
					end
				end
			end
		end
	end

	-- (No bunting over the roads: the sky over the street stays open, which is what lets ZEE
	-- TOWER be seen from everywhere.)

	-- Manhole covers in the lanes.
	for _, arm in ipairs({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
		for k, d in ipairs({ 70, 130 }) do
			local lane = if k == 1 then 4.5 else -4.5
			local at = if arm[1] == 0 then Vector3.new(lane, 0, arm[2] * d) else Vector3.new(arm[1] * d, 0, lane)
			manhole(root:within(CFrame.new(at)))
		end
	end

	-- A taco truck at the kerb on the east arm, an ice-cream van outside Rainbow Park.
	foodTruck(root:within(CFrame.new(60, 0, -13.5)), Color3.fromRGB(250, 200, 48), "TACOS ZEE", Color3.fromRGB(220, 60, 50))
	iceCreamVan(root:within(CFrame.new(-110, 0, 13.5) * CFrame.Angles(0, math.pi, 0)))
	-- Bus shelters on the avenue, between the lamps, open to the road.
	busShelter(root:within(CFrame.new(-20.3, 0.54, 138) * CFrame.Angles(0, math.rad(-90), 0)), "ZEE TOWER")
	busShelter(root:within(CFrame.new(20.3, 0.54, 100) * CFrame.Angles(0, math.rad(90), 0)), "THE COURTS")
	-- The ZEE BANK truck at the kerb up the west arm, its back doors toward the plaza.
	armouredTruck(root:within(CFrame.new(-150, 0, 13.8) * CFrame.Angles(0, math.rad(90), 0)))

	-- Billboards on the roofs, facing the streets.
	for _, spec in ipairs({
		{ 88, 30, -40, 1, "ZEE COLA", "ICE COLD  ·  ALWAYS", Color3.fromRGB(214, 44, 48), TRIM },
		{ 55, 40, 124, -1, "DUEL NIGHT", "EVERY NIGHT  ·  DUEL HALL", NAVY, GOLD },
		{ -168, 50, 40, -1, "PIZZA PALACE", "HOT SLICES 24/7", Color3.fromRGB(250, 200, 48), Color3.fromRGB(200, 40, 40) },
		{ -148, 40, -38, 1, "BEATS FM 99.9", "LIVE FROM RAINBOW PARK", Color3.fromRGB(130, 88, 210), TRIM },
		{ 154, 34, 40, -1, "ZEE BURGER", "THE BIG ONE", ORANGE, TRIM },
		{ 128, 44, -40, 1, "GET IN THE RING", "1V1  ·  STEP ON A PAD", TEAL, TRIM },
	} :: { { any } }) do
		local at = Vector3.new(spec[1], spec[2] + 0.7, spec[3])
		billboard(root, Kit.Look(at, at + Vector3.new(0, 0, spec[4])), 18, 7, spec[7], spec[8], spec[5], spec[6])
	end

	-- ---------------------------------------------------------------- blocks --

	-- South-east: ZEE GUNS and ZEE TACTICS on the avenue, a car park south of them, and a
	-- street wall of offices behind.
	storefront(root:within(CFrame.new(ROAD + WALK + 2, 0.5, -64)), "ZEE GUNS", "Guns & Builds", GREEN, BRICK, "GunCounter",
		"Open Shop", 34, 40, "guns", { ClerkName = "Rico", ClerkTitle = "ZEE GUNS", ClerkShirt = GREEN })
	storefront(root:within(CFrame.new(ROAD + WALK + 2, 0.5, -110)), "ZEE TACTICS", "Heals · Armor · Bombs", ORANGE,
		FACADE[8], "TacticsCounter", "Open Shop", 34, 40, "tactics",
		{ ClerkName = "Vic", ClerkTitle = "ZEE TACTICS", ClerkShirt = Color3.fromRGB(44, 52, 66) })
	carPark(root, ROAD + WALK + 2, 64, -186, -136, 2)
	for _, spec in ipairs({
		{ 68, 108, -150, -34, 30, 1 }, { 108, 148, -150, -34, 44, 3 }, { 148, 186, -150, -34, 26, 5 },
		{ 68, 128, -186, -154, 22, 2 }, { 128, 186, -186, -154, 36, 7 },
	}) do
		building(root, spec[1], spec[2], spec[3], spec[4], spec[5], FACADE[spec[6]], { "all" }, spec[1] + spec[3], false,
			streetFaces(1, -1))
	end

	-- South-west: ZEE GAS on the corner, the 24/7 behind it, a car park, offices.
	gasStation(root:within(CFrame.new(-(ROAD + WALK + 26), 0, -52)))
	convenience(root:within(CFrame.new(-(ROAD + WALK + 52), 0.5, -52)))
	carPark(root, -76, -(ROAD + WALK + 2), -132, -80, 3)
	-- The back lane between the offices: its walls are the brick backs of the blocks either side.
	for _, spec in ipairs({
		{ -186, -110, -72, -34, 40, 6, { "+x", "+z", "-z" }, { "-z" } }, { -186, -110, -150, -96, 32, 6, { "+z" }, { "+z" } },
		{ -106, -80, -150, -96, 24, 7, { "+z", "+x" }, { "+z" } },
		{ -186, -120, -186, -154, 34, 3, { "+z" } }, { -120, -34, -186, -140, 26, 1, { "+z", "+x" } },
	} :: { { any } }) do
		building(root, spec[1], spec[2], spec[3], spec[4], spec[5], FACADE[spec[6]], { "all" }, spec[2] + spec[4], false,
			spec[7], spec[8])
	end
	alley(root:within(CFrame.new(-133, 0.5, -84)), 106, 12)

	-- North-west: the DUEL HALL, open to the avenue, a pocket park on the corner.
	duelHall(root:within(CFrame.new(-(ROAD + WALK + 4), 0.5, 88)))
	pocketPark(root:within(CFrame.new(-64, 0, 45)))
	-- RAINBOW PARK where a block of offices stood, the waterfall against the tall block west of it.
	park(root:within(CFrame.new(-125, 0.5, 77)), 21, 43)
	for _, spec in ipairs({
		{ -186, -150, 34, 110, 50, 5 }, { -186, -150, 110, 186, 38, 1 },
		{ -146, -104, 124, 186, 26, 2 }, { -96, -62, 124, 186, 32, 3 }, { -62, -34, 124, 150, 24, 7 },
	}) do
		-- The tall block west of the park has the waterfall against its east face: a back.
		building(root, spec[1], spec[2], spec[3], spec[4], spec[5], FACADE[spec[6]], { "all" }, spec[1] - spec[3], false,
			{ "+x", "-z" }, if spec[1] == -186 and spec[3] == 34 then { "+x" } else nil)
	end

	-- North-east: the court, the apartments with the fire escape, offices round them.
	court(root:within(CFrame.new(ROAD + WALK + 26, 0.5, 80)))
	fixerCorner(root:within(CFrame.new(48, 0.5, 43)))
	apartments(root:within(CFrame.new(ROAD + WALK + 60, 0.5, 80)))
	for _, spec in ipairs({
		{ 34, 76, 118, 186, 40, 8 }, { 76, 130, 118, 186, 28, 9 }, { 130, 186, 118, 186, 52, 3 },
		{ 122, 186, 34, 76, 34, 4 }, { 122, 186, 76, 114, 24, 7 },
	}) do
		building(root, spec[1], spec[2], spec[3], spec[4], spec[5], FACADE[spec[6]], { "all" }, spec[2] - spec[4], false,
			streetFaces(1, 1))
	end

	-- The north end: ZEE TOWER closing the avenue.
	tower(root:within(CFrame.new(0, 0.5, HW - 42)))

	-- ------------------------------------------------------------ the ring --

	-- Tall buildings all the way round, faces turned inward, so the district is a place and
	-- not a platform. Heights step so the skyline has a rhythm.
	local heights = { 70, 96, 60, 120, 84, 150, 76, 104 }
	local i = 0
	for _, side in ipairs({ "n", "s", "e", "w" }) do
		for a = -HW + 20, HW - 20, 40 do
			i += 1
			local h = heights[(i % #heights) + 1]
			local colour = FACADE[(i % #FACADE) + 1]
			local gap = math.abs(a) < ROAD + WALK
			local box: { number }? = nil
			if side == "n" and not gap and math.abs(a) > 32 then
				box = { a - 19, a + 19, HW - 10, HW + 30 }
				building(root, a - 19, a + 19, HW - 10, HW + 30, h, colour, { "-z" }, i)
			elseif side == "s" and not gap then
				box = { a - 19, a + 19, -HW - 30, -HW + 10 }
				building(root, a - 19, a + 19, -HW - 30, -HW + 10, h, colour, { "+z" }, i)
			elseif side == "e" and not gap then
				box = { HW - 10, HW + 30, a - 19, a + 19 }
				building(root, HW - 10, HW + 30, a - 19, a + 19, h, colour, { "-x" }, i)
			elseif side == "w" and not gap then
				box = { -HW - 30, -HW + 10, a - 19, a + 19 }
				building(root, -HW - 30, -HW + 10, a - 19, a + 19, h, colour, { "+x" }, i)
			end
			if box then
				-- Up the inward face above the shops: piers in a lighter tone, so a tall face reads
				-- as floors and bays instead of one flat wall; a name band near the top of some, a
				-- billboard on a frame on the roof of others.
				local inward = if side == "n" then Vector3.new(0, 0, -1) elseif side == "s" then Vector3.new(0, 0, 1)
					elseif side == "e" then Vector3.new(-1, 0, 0) else Vector3.new(1, 0, 0)
				local bx, bz = (box[1] + box[2]) / 2, (box[3] + box[4]) / 2
				local halfDepth = if inward.X ~= 0 then (box[2] - box[1]) / 2 else (box[4] - box[3]) / 2
				local span = if inward.X ~= 0 then box[4] - box[3] else box[2] - box[1]
				local faceAt = Vector3.new(bx, 0, bz) + inward * (halfDepth + 0.35)
				local across = Vector3.new(inward.Z, 0, -inward.X)
				-- A curtain wall above the shop floors: slim mullions up the face between the
				-- glass bands, with a heavier pier every third, so it reads as a grid of windows.
				local fin = lighter(colour, 0.32)
				local finTop = h - 3.4
				for k = -4, 4 do
					local at = faceAt + across * (k * span / 9.6)
					local heavy = k % 3 == 0
					local wide, deep = if heavy then 1.3 else 0.45, if heavy then 1.3 else 0.8
					root:decor(if heavy then "TowerPier" else "Mullion",
						if inward.X ~= 0 then Vector3.new(deep, finTop - 38, wide) else Vector3.new(wide, finTop - 38, deep),
						at + Vector3.new(0, (finTop + 38) / 2, 0), if heavy then fin else lighter(colour, 0.5))
				end
				local brands = { "ZEE BANK", "NOVA", "PIXEL", "METRO", "BLOX", "SKYLINE", "CRUNCH", "ORBIT" }
				if i % 3 == 1 then
					local bandAt = faceAt + inward * 0.4 + Vector3.new(0, h - 8, 0)
					local bc = ({ TEAL, RED, NAVY, GOLD, ORANGE })[(i % 5) + 1]
					root:decor("NameBand", if inward.X ~= 0 then Vector3.new(0.6, 5, span * 0.7) else Vector3.new(span * 0.7, 5, 0.6), bandAt, bc)
					painted(root, brands[(i % #brands) + 1], Kit.Look(bandAt + inward * 0.4, bandAt + inward * 10), span * 0.62, 3.6,
						if bc == GOLD then NAVY else CREAM)
				elseif i % 3 == 2 then
					local bb = Vector3.new(bx, h + 1, bz) + inward * (halfDepth - 4)
					for _, k in ipairs({ -1, 1 }) do
						root:decor("BillboardLeg", Vector3.new(0.6, 10, 0.6), bb + across * (k * span * 0.3) + Vector3.new(0, 4, 0) - inward * 1.5, IRON)
					end
					local bc = ({ ORANGE, BLUE, RED, GREEN })[(i % 4) + 1]
					root:decor("Billboard", if inward.X ~= 0 then Vector3.new(0.6, 8, span * 0.7) else Vector3.new(span * 0.7, 8, 0.6),
						bb + Vector3.new(0, 9, 0), bc)
					painted(root, brands[((i + 3) % #brands) + 1], Kit.Look(bb + Vector3.new(0, 9, 0) + inward * 0.4,
						bb + Vector3.new(0, 9, 0) + inward * 10), span * 0.6, 5, CREAM)
				end
				-- The top. A tall tower steps back: an upper tier, inset, with its own glass and
				-- mullions; then an Art Deco crown in stepped tiers, and on the tallest a spire with
				-- a beacon. A shorter one gets a set-back top storey and, now and then, a mast.
				local cx, cz = (box[1] + box[2]) / 2, (box[3] + box[4]) / 2
				local bw, bd = box[2] - box[1], box[4] - box[3]
				local roof = h
				if h >= 84 then
					local tw, td = bw - 12, bd - 12
					local th = math.floor(h * 0.22 / 7) * 7 + 7
					local tierColour = lighter(colour, 0.12)
					root:part("Tier", Vector3.new(tw, th, td), Vector3.new(cx, h + th / 2, cz), tierColour)
					local tierHalf = if inward.X ~= 0 then tw / 2 else td / 2
					local tierSpan = if inward.X ~= 0 then td else tw
					local tierSide = if inward.X ~= 0 then tw else td
					for y = h + 4, h + th - 3, 7 do
						-- Glass on the inward face and both sides, so it reads from any angle.
						local front = Vector3.new(cx, y, cz) + inward * (tierHalf + 0.17)
						root:decor("TierGlass", if inward.X ~= 0 then Vector3.new(0.34, 3, tierSpan * 0.88)
							else Vector3.new(tierSpan * 0.88, 3, 0.34), front, WINDOW, M.Glass, { reflectance = 0.15 })
						for _, sd in ipairs({ -1, 1 }) do
							local sideAt = Vector3.new(cx, y, cz) + across * (sd * (tierSpan / 2 + 0.17))
							root:decor("TierGlass", if inward.X ~= 0 then Vector3.new(tierSide * 0.85, 3, 0.34)
								else Vector3.new(0.34, 3, tierSide * 0.85), sideAt, WINDOW, M.Glass, { reflectance = 0.15 })
						end
					end
					for k = -2, 2 do
						local at = Vector3.new(cx, 0, cz) + inward * (tierHalf + 0.4) + across * (k * tierSpan / 5.2)
						root:decor("Mullion", if inward.X ~= 0 then Vector3.new(0.8, th - 2, 0.5) else Vector3.new(0.5, th - 2, 0.8),
							at + Vector3.new(0, h + th / 2, 0), lighter(colour, 0.5))
					end
					root:decor("TierCornice", Vector3.new(tw + 1.4, 1, td + 1.4), Vector3.new(cx, h + th - 0.3, cz), TRIM)
					roof = h + th
					-- The crown in steps, each narrower than the last, with a trim lip on each.
					local cw, cd = tw, td
					for step = 1, 3 do
						cw, cd = cw * 0.72, cd * 0.72
						local sh = 7 - step
						root:decor("Crown", Vector3.new(cw, sh, cd), Vector3.new(cx, roof + sh / 2, cz),
							if step % 2 == 1 then lighter(colour, 0.26) else darker(colour, 0.08))
						root:decor("CrownLip", Vector3.new(cw + 0.8, 0.5, cd + 0.8), Vector3.new(cx, roof + sh - 0.1, cz), TRIM)
						roof += sh
					end
					if h >= 104 then
						root:decor("Spire", Vector3.new(26, 1.2, 1.2), vertical(Vector3.new(cx, roof + 13, cz)), STEEL, M.Metal,
							{ shape = "Cylinder" })
						root:decor("SpireFoot", Vector3.new(4, 2.6, 2.6), vertical(Vector3.new(cx, roof + 2, cz)), lighter(colour, 0.26),
							nil, { shape = "Cylinder" })
						root:decor("Beacon", Vector3.new(1.4, 1.4, 1.4), Vector3.new(cx, roof + 26.5, cz), RED, nil, { shape = "Ball" })
					end
				else
					local cw, cd = bw * 0.56, bd * 0.56
					root:decor("Crown", Vector3.new(cw, 9, cd), Vector3.new(cx, h + 4.9, cz), lighter(colour, 0.22))
					root:decor("CrownBand", Vector3.new(cw + 0.3, 1.2, cd + 0.3), Vector3.new(cx, h + 7, cz), darker(colour, 0.15))
					root:decor("CrownCap", Vector3.new(cw + 1.2, 0.8, cd + 1.2), Vector3.new(cx, h + 9.7, cz), TRIM)
					if i % 3 == 0 then
						root:decor("Mast", Vector3.new(16, 0.5, 0.5), vertical(Vector3.new(cx, h + 18, cz)), STEEL, M.Metal,
							{ shape = "Cylinder" })
						root:decor("Beacon", Vector3.new(1.1, 1.1, 1.1), Vector3.new(cx, h + 26.3, cz), RED, nil, { shape = "Ball" })
					end
				end
			end
		end
	end
	-- Where the cross street leaves the district east and west, a tunnel mouth under a
	-- bridge building, so the road seems to go on.
	for _, s in ipairs({ -1, 1 }) do
		-- A brick block bridging the road, its inward face dressed like any street front:
		-- rows of framed windows, a cornice, and the way out named over the tunnel.
		local span = ROAD * 2 + WALK * 2 + 4
		root:part("Bridge", Vector3.new(40, 60, span), Vector3.new(s * (HW + 10), 45, 0), BRICK, M.Brick)
		root:decor("BridgeCourse", Vector3.new(40.6, 1.2, span + 0.6), Vector3.new(s * (HW + 10), 16, 0), TRIM)
		root:decor("BridgeCornice", Vector3.new(41.2, 1.4, span + 1.2), Vector3.new(s * (HW + 10), 73.6, 0), TRIM)
		root:decor("BridgeFrieze", Vector3.new(40.5, 2, span + 0.5), Vector3.new(s * (HW + 10), 71.4, 0), darker(BRICK, 0.2))
		local face = s * (HW - 10)
		for y = 26, 64, 7 do
			for z = -24, 24, 8 do
				root:decor("BridgeFrame", Vector3.new(0.22, 4.4, 4.2), Vector3.new(face - s * 0.11, y, z), TRIM)
				root:decor("BridgeGlass", Vector3.new(0.34, 3.6, 3.4), Vector3.new(face - s * 0.17, y, z), WINDOW, M.Glass,
					{ reflectance = 0.15 })
			end
		end
		local signAt = Vector3.new(face - s * 0.62, 20.5, 0)
		-- Named for the compass (north is +Z, up the avenue to ZEE TOWER, so east is -X).
		board(root, if s > 0 then "WEST END" else "EAST END", Kit.Look(signAt, signAt - Vector3.new(s, 0, 0)), 18, 3,
			TEAL, TRIM)
		root:decor("Tunnel", Vector3.new(4, 14, ROAD * 2), Vector3.new(s * (HW - 8), 7, 0), Color3.fromRGB(24, 24, 28))
		root:part("TunnelWall", Vector3.new(4, 15, 2), Vector3.new(s * (HW - 8), 7.5, ROAD + 1), darker(BRICK, 0.2), M.Brick)
		root:part("TunnelWall", Vector3.new(4, 15, 2), Vector3.new(s * (HW - 8), 7.5, -ROAD - 1), darker(BRICK, 0.2), M.Brick)
		root:part("TunnelBlock", Vector3.new(2, 14, ROAD * 2), Vector3.new(s * (HW - 5), 7, 0), Color3.fromRGB(10, 10, 12),
			nil, { transparency = 1 })
		for z = -ROAD + 3, ROAD - 3, 6 do
			root:decor("TunnelLamp", Vector3.new(0.3, 0.5, 2), Vector3.new(s * (HW - 10.1), 13, z), LAMP_GLASS)
		end
		root:light("Point", Vector3.new(s * (HW - 12), 11, 0), WARM, 1, 24)
	end

	-- A far skyline ring beyond, for the horizon.
	local sky = root:folder("Skyline")
	for k = 0, 27 do
		local a = k / 28 * math.pi * 2
		local r = 330 + (k % 3) * 40
		local x, z = math.cos(a) * r, math.sin(a) * r
		local w = 34 + (k * 11) % 20
		local h = 120 + ((k * 37) % 6) * 30
		local colour = FACADE[(k % #FACADE) + 1]
		local face = math.abs(x) > math.abs(z) and (x > 0 and "-x" or "+x") or (z > 0 and "-z" or "+z")
		building(sky, x - w / 2, x + w / 2, z - w / 2, z + w / 2, h, colour, { face }, 100 + k, true)
		-- Dressed for the distance: mullions up the face that looks in, glass bands round the
		-- sides, and a stepped crown (a spire on every other one) for the silhouette.
		local inward = if face == "-x" then Vector3.new(-1, 0, 0) elseif face == "+x" then Vector3.new(1, 0, 0)
			elseif face == "-z" then Vector3.new(0, 0, -1) else Vector3.new(0, 0, 1)
		local across = Vector3.new(inward.Z, 0, -inward.X)
		for m = -3, 3 do
			local at = Vector3.new(x, (h + 4) / 2, z) + inward * (w / 2 + 0.4) + across * (m * w / 7.4)
			sky:decor("Mullion", if inward.X ~= 0 then Vector3.new(0.8, h - 6, 0.7) else Vector3.new(0.7, h - 6, 0.8), at,
				lighter(colour, 0.4))
		end
		for _, sd in ipairs({ -1, 1 }) do
			for y = 14, h - 6, 14 do
				local at = Vector3.new(x, y, z) + across * (sd * (w / 2 + 0.17))
				sky:decor("Windows", if inward.X ~= 0 then Vector3.new(w * 0.86, 3, 0.34) else Vector3.new(0.34, 3, w * 0.86), at,
					WINDOW, M.Glass, { reflectance = 0.15 })
			end
		end
		local roof, cw = h + 0.7, w * 0.8
		for step = 1, 2 do
			cw *= 0.72
			local sh = 8 - step * 2
			sky:decor("Crown", Vector3.new(cw, sh, cw), Vector3.new(x, roof + sh / 2, z), lighter(colour, 0.2 + step * 0.06))
			sky:decor("CrownLip", Vector3.new(cw + 0.8, 0.5, cw + 0.8), Vector3.new(x, roof + sh - 0.1, z), TRIM)
			roof += sh
		end
		if k % 2 == 0 then
			sky:decor("Spire", Vector3.new(22, 1, 1), vertical(Vector3.new(x, roof + 11, z)), STEEL, M.Metal, { shape = "Cylinder" })
		end
	end

	-- The edge: nothing to fall off. The north wall stops below ZEE TOWER's roof: left full
	-- height it ran straight through the penthouse (the tower's back is past it), and split
	-- the Don's roof in two -- you came out of the elevator behind an invisible wall, with the
	-- Don and his people on the other side of it. Nothing at street level is up that high.
	Kit.Bounds(root, HW - 12, HW - 12, 200)
	local bounds = root.parent:FindFirstChild("Bounds")
	for _, wall in ipairs(if bounds then bounds:GetChildren() else {}) do
		local at = if wall:IsA("BasePart") then root.frame:PointToObjectSpace(wall.CFrame.Position) else nil
		if wall:IsA("BasePart") and wall.Name == "BoundZ" and at and at.Z > 0 then
			local top, bottom = 140, -5
			wall.Size = Vector3.new(wall.Size.X, top - bottom, wall.Size.Z)
			wall.CFrame = root.frame * CFrame.new(at.X, (top + bottom) / 2, at.Z)
		end
	end

	-- ------------------------------------------------------------ finding your way --
	--
	-- Landmarks for the compass (UI.Modules.Wayfinding): an invisible marker at each place worth
	-- heading for, tagged "Waypoint", with its name and icon. And the named areas: an invisible
	-- box over each, tagged "Area" -- walk into one and its name comes up on screen.
	local function waypoint(name: string, icon: string, at: Vector3)
		local marker = root:decor("Waypoint", Vector3.new(1, 1, 1), at, TRIM, nil, { transparency = 1 })
		marker:SetAttribute("WaypointName", name)
		marker:SetAttribute("WaypointIcon", icon)
		marker:AddTag("Waypoint")
	end
	local function area(name: string, sub: string, centreAt: Vector3, size: Vector3)
		local box = root:decor("Area", size, centreAt, TRIM, nil, { transparency = 1 })
		box:SetAttribute("AreaName", name)
		box:SetAttribute("AreaSub", sub)
		box:AddTag("Area")
	end
	local STORE = ROAD + WALK + 2
	waypoint("ZEE TOWER", "🏙", Vector3.new(0, 3, HW - 44))
	waypoint("ZEE PLAZA", "⛲", Vector3.new(0, 3, 0))
	waypoint("ZEE GUNS", "🔫", Vector3.new(STORE, 3, -64))
	waypoint("ZEE TACTICS", "🛡", Vector3.new(STORE, 3, -110))
	waypoint("DUEL HALL", "⚔", Vector3.new(-(ROAD + WALK + 4), 3, 88))
	waypoint("JOB BOARDS", "📋", Vector3.new(-(ROAD + WALK + 58), 3, -37))
	waypoint("THE FIXER", "💼", Vector3.new(48, 3, 43))
	waypoint("RAINBOW PARK", "🌈", Vector3.new(-125, 3, 77))
	waypoint("ZEE BANK TRUCK", "🚚", Vector3.new(-150, 3, 13.8))

	area("DOWNTOWN", "ZEE CITY", Vector3.new(0, 60, 0), Vector3.new(HW * 2 + 80, 170, HW * 2 + 80))
	area("ZEE PLAZA", "THE HEART OF DOWNTOWN", Vector3.new(0, 12, 0), Vector3.new(PLAZA * 2, 30, PLAZA * 2))
	area("ZEE GUNS", "GUNS & BUILDS", Vector3.new(STORE + 17, 7, -64), Vector3.new(34, 14, 40))
	area("ZEE TACTICS", "HEALS · ARMOR · BOMBS", Vector3.new(STORE + 17, 7, -110), Vector3.new(34, 14, 40))
	area("ZEE GAS", "24/7 · CONTRACTS · BOUNTIES", Vector3.new(-(ROAD + WALK + 40), 10, -50), Vector3.new(52, 26, 40))
	area("THE ALLEY", "CREW TURF", Vector3.new(-133, 12, -84), Vector3.new(106, 30, 16))
	area("RAINBOW PARK", "CREW TURF · THE STAR STAGE", Vector3.new(-125, 12, 77), Vector3.new(44, 30, 88))
	area("THE COURTS", "CREW TURF · THE FIXER", Vector3.new(ROAD + WALK + 26, 12, 72), Vector3.new(44, 30, 72))
	area("THE CAR PARK", "CREW TURF", Vector3.new(47, 10, -161), Vector3.new(36, 24, 52))
	area("DUEL HALL", "1V1 · STEP ON A PAD", Vector3.new(-(ROAD + WALK + 4) - 32, 13, 88), Vector3.new(64, 30, 56))
	area("ZEE TOWER", "THE DON'S HOUSE", Vector3.new(0, 20, HW - 22), Vector3.new(64, 44, 44))

	-- Everything there is to rob learns where the street is: the point on the avenue (x = 0)
	-- level with it, which is where StickupService sends the squad up from.
	for _, d in ipairs(parent:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("Stickup") then
			local z = root.frame:PointToObjectSpace(d.CFrame.Position).Z
			d:SetAttribute("StickupStreet", root:world(Vector3.new(0, 0.5, z)).Position)
		end
	end
end

return Downtown
