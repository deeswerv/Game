--!strict
-- DOWNTOWN: a city district, built block by block.
--
-- A grid, laid out the way a real downtown is and nothing placed at random:
--
--   * An avenue runs north from the arrival forecourt (south) to ZEE TOWER (north); a cross
--     street runs east-west. Where they meet is ZEE PLAZA, pedestrianised: tiled paving, a
--     three-tier stone fountain, planted corners and a finger post pointing the way.
--   * South-east: ZEE GUNS and the ARMORY, storefronts on the avenue (the shop and the
--     armory panels open at their doors).
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
-- road surface, 0.5 the kerb. Built with ArenaService.Kit like the duel maps.

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

-- The district's grade and sky while you are in it (the time of day is left to the world).
Downtown.Look = {
	Grade = { Saturation = 0.22, Contrast = 0.06 },
	Clouds = { Cover = 0.62, Density = 0.5, Color = Color3.fromRGB(255, 255, 255) },
}

-- Interactive points the service wires up after building: prompt name -> panel.
Downtown.Panels = {
	GunShop = "Market",
	Armory = "Workshop",
	ContractBoard = "Contracts",
}

local M = Enum.Material

local ASPHALT = Color3.fromRGB(70, 72, 80)
local WHITE_LINE = Color3.fromRGB(236, 234, 226)
local YELLOW_LINE = Color3.fromRGB(236, 192, 64)
local SIDEWALK = Color3.fromRGB(200, 192, 180)
local SIDEWALK_EDGE = Color3.fromRGB(186, 178, 166)
local CURB = Color3.fromRGB(218, 212, 202)
local PLAZA_A = Color3.fromRGB(232, 220, 200)
local PLAZA_B = Color3.fromRGB(184, 166, 146)
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

--- A street lamp: an iron post that curls over at the top like a shepherd's crook, a round
--- lantern hanging from its end out over the road (-X), a street banner and a basket of flowers.
local function lamp(b: Kit.Builder, withLight: boolean, banner: Color3?)
	b:part("Base", Vector3.new(1.6, 1.2, 1.6), Vector3.new(0, 1.1, 0), IRON)
	b:decor("Plinth", Vector3.new(1.1, 0.8, 1.1), Vector3.new(0, 2.1, 0), IRON)
	b:part("Pole", Vector3.new(14, 0.5, 0.5), vertical(Vector3.new(0, 9, 0)), IRON, nil, { shape = "Cylinder" })
	b:decor("Collar", Vector3.new(0.4, 0.8, 0.8), vertical(Vector3.new(0, 6.2, 0)), IRON, nil, { shape = "Cylinder" })
	-- The crook: short straight pieces round a half circle from the top of the pole, over
	-- toward -X and down, each joint covered by a ball so the curve reads as one bent tube.
	local r, cx, cy = 1.9, -1.9, 16
	local prev = Vector3.new(0, cy, 0)
	for k = 1, 6 do
		local a = k / 6 * math.pi
		local nextPoint = Vector3.new(cx + math.cos(a) * r, cy + math.sin(a) * r, 0)
		local cf, len = Kit.Span(prev, nextPoint)
		b:decor("Crook", Vector3.new(0.42, 0.42, len + 0.1), cf, IRON)
		b:decor("Knuckle", Vector3.new(0.46, 0.46, 0.46), nextPoint, IRON, nil, { shape = "Ball" })
		prev = nextPoint
	end
	b:decor("Scroll", Vector3.new(0.9, 0.9, 0.9), Vector3.new(-0.6, 14.9, 0), IRON, nil, { shape = "Ball" })
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
	b:decor("Bracket", Vector3.new(1.2, 0.15, 0.15), Vector3.new(0.7, 8.9, 0), IRON)
	b:decor("Basket", Vector3.new(1.4, 0.8, 1.4), Vector3.new(1.3, 8.1, 0), WOOD, M.WoodPlanks)
	b:decor("Trailing", Vector3.new(1.8, 1, 1.8), CFrame.new(1.3, 8.7, 0) * CFrame.Angles(0, math.rad(45), 0), HEDGE)
	b:decor("Bloom", Vector3.new(1.2, 0.5, 1.2), Vector3.new(1.3, 9.3, 0), FLOWERS[1])
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

--- A faceted low-poly tree in a stone planter (none if `bare`, for a tree in a bed). `blossom`
--- makes it a pink one. Like every street prop, its origin is road level: it stands on 0.5.
local function tree(b: Kit.Builder, seed: number, blossom: boolean?, bare: boolean?)
	if not bare then
		b:part("Planter", Vector3.new(4.4, 0.9, 4.4), Vector3.new(0, 0.95, 0), CURB)
		b:decor("Soil", Vector3.new(3.8, 0.1, 3.8), Vector3.new(0, 1.42, 0), SOIL, M.Ground)
	end
	b:part("Trunk", Vector3.new(7, 1, 1), vertical(Vector3.new(0, 4.9, 0)), BARK, M.Wood, { shape = "Cylinder" })
	b:decor("Branch", Vector3.new(2.6, 0.5, 0.5), CFrame.new(0.9, 7.6, 0) * CFrame.Angles(0, 0, math.rad(40)), BARK, M.Wood,
		{ shape = "Cylinder" })
	local rng = Random.new(seed)
	-- A cartoon canopy: round clumps of leaves in three greens, stacked -- the big dark ones
	-- low and wide, lighter ones on top where the sun catches them.
	local shades = { Color3.fromRGB(60, 150, 64), Color3.fromRGB(92, 182, 72), Color3.fromRGB(140, 210, 90) }
	if blossom then
		shades = { Color3.fromRGB(232, 132, 170), BLOSSOM, BLOSSOM_LIGHT }
	end
	for _, blob in ipairs({
		{ Vector3.new(0, 8.6, 0), 6.4, 1 }, { Vector3.new(2.4, 8, 1), 4.6, 1 }, { Vector3.new(-2.3, 8.2, -1.1), 4.8, 1 },
		{ Vector3.new(-0.6, 8, 2.3), 4.2, 2 }, { Vector3.new(1, 10.6, -0.6), 4.8, 2 }, { Vector3.new(-1.3, 10.2, 0.9), 4, 2 },
		{ Vector3.new(0.3, 12.2, 0.2), 3.4, 3 }, { Vector3.new(1.9, 10.2, 1.8), 2.6, 3 },
	} :: { { any } }) do
		local s = blob[2] * rng:NextNumber(0.88, 1.12)
		local at = blob[1] + Vector3.new(rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.2, 0.2), rng:NextNumber(-0.3, 0.3))
		b:decor("Leaves", Vector3.new(s, s * 0.9, s), at, shades[blob[3]], M.SmoothPlastic, { shape = "Ball", shadow = true })
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

local function bollard(b: Kit.Builder)
	b:part("Bollard", Vector3.new(2.6, 0.8, 0.8), vertical(Vector3.new(0, 1.8, 0)), IRON, nil, { shape = "Cylinder" })
	b:decor("Band", Vector3.new(0.3, 0.84, 0.84), vertical(Vector3.new(0, 2.7, 0)), GOLD, nil, { shape = "Cylinder" })
	b:decor("Top", Vector3.new(0.7, 0.7, 0.7), Vector3.new(0, 3.1, 0), IRON, nil, { shape = "Ball" })
end

--- A parked car, nose toward -Z.
local function car(b: Kit.Builder, colour: Color3)
	local trim = Color3.fromRGB(34, 34, 38)
	b:part("Body", Vector3.new(4.6, 1.5, 10), Vector3.new(0, 1.55, 0), colour, nil, { reflectance = 0.05 })
	b:part("Cabin", Vector3.new(4.1, 1.5, 5), Vector3.new(0, 3.05, 0.4), colour)
	b:decor("Glass", Vector3.new(4.16, 1.1, 5.06), Vector3.new(0, 3.05, 0.4), Color3.fromRGB(56, 72, 90), M.Glass,
		{ transparency = 0.1, reflectance = 0.2 })
	b:decor("Roof", Vector3.new(4.12, 0.3, 4.2), Vector3.new(0, 3.85, 0.5), colour)
	for _, z in ipairs({ -5.05, 5.05 }) do
		b:decor("Bumper", Vector3.new(4.7, 0.6, 0.3), Vector3.new(0, 1.13, z), trim)
	end
	for _, x in ipairs({ -1.6, 1.6 }) do
		b:decor("Headlight", Vector3.new(1, 0.4, 0.1), Vector3.new(x, 1.8, -5.02), Color3.fromRGB(246, 242, 226))
		b:decor("Taillight", Vector3.new(1, 0.4, 0.1), Vector3.new(x, 1.8, 5.02), Color3.fromRGB(196, 44, 44))
	end
	for _, x in ipairs({ -2.05, 2.05 }) do
		for _, z in ipairs({ -3.2, 3.2 }) do
			b:decor("Wheel", Vector3.new(0.8, 2, 2), Vector3.new(x, 1, z), trim, M.Rubber, { shape = "Cylinder" })
			b:decor("Hub", Vector3.new(0.84, 0.9, 0.9), Vector3.new(x, 1, z), Color3.fromRGB(196, 196, 200), M.Metal,
				{ shape = "Cylinder" })
		end
		b:decor("Mirror", Vector3.new(0.5, 0.3, 0.4), Vector3.new(x * 1.12, 2.7, -1.8), colour)
	end
end

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
	b:part("Building", Vector3.new(w, top - base, d), Vector3.new(cx, (top + base) / 2, cz), colour,
		colour == BRICK and M.Brick or M.SmoothPlastic)
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
		-- Floors above. On a street face the first few are rows of real windows; the rest of
		-- the height (and every face nobody walks past) is a glass band per floor.
		local floor = 0
		for y = 14, top - 5, 7 do
			floor += 1
			if rich and floor <= 4 then
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
	b:part("Pavement", Vector3.new(x1 - x0, 0.5, z1 - z0), Vector3.new(cx, 0.25, cz), colour, M.Concrete)
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

	-- Benches facing the fountain, a lamp between each pair, a planted bed in every corner.
	for i = 0, 3 do
		local turn = CFrame.Angles(0, math.rad(i * 90), 0)
		for _, off in ipairs({ -8, 8 }) do
			bench(b:within(turn * CFrame.new(off, 0, -22) * CFrame.Angles(0, math.pi, 0)))
		end
		postLamp(b:within(turn * CFrame.new(17, 0, 17)))
		-- The corner bed: a stone planter, a tree in the middle, flowers round it.
		local corner = b:within(turn * CFrame.new(half - 9, 0.5, half - 9))
		corner:part("CornerBed", Vector3.new(12, 1.4, 12), Vector3.new(0, 0.7, 0), STONE)
		corner:decor("CornerCap", Vector3.new(12.4, 0.25, 12.4), Vector3.new(0, 1.45, 0), STONE_LIGHT)
		corner:decor("CornerGrass", Vector3.new(11, 0.1, 11), Vector3.new(0, 1.5, 0), GRASS, M.Grass)
		for k, spot in ipairs({ Vector3.new(-4, 0, -4), Vector3.new(4, 0, -4), Vector3.new(-4, 0, 4), Vector3.new(4, 0, 4),
			Vector3.new(0, 0, -4.2), Vector3.new(-4.2, 0, 0) }) do
			local colour = FLOWERS[(k + i) % #FLOWERS + 1]
			corner:decor("Tuft", Vector3.new(1.6, 0.8, 1.6), CFrame.new(spot + Vector3.new(0, 1.9, 0))
				* CFrame.Angles(0, math.rad(45), 0), HEDGE)
			corner:decor("Bloom", Vector3.new(1, 0.45, 1), spot + Vector3.new(0, 2.45, 0), colour)
		end
		tree(corner:within(CFrame.new(0, 0.15, 0)), 40 + i, i % 2 == 1, true)
	end
	-- Cafe tables under striped umbrellas in the square's four quarters.
	for i, spot in ipairs({ { 28, 14 }, { -28, -14 }, { -14, 28 }, { 14, -28 } }) do
		cafeTable(b:within(CFrame.new(spot[1], 0.5, spot[2])), BENCH_COLOURS[i])
	end
	-- Bollards where the roads meet the square, so it reads as a place for people.
	for i = 0, 3 do
		local yaw = math.rad(i * 90)
		for x = -15, 15, 5 do
			bollard(b:within(CFrame.Angles(0, yaw, 0) * CFrame.new(x, 0, -half + 1.2)))
		end
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

--- A storefront facing -X (toward the avenue): a brick or painted shell, a painted signboard,
--- a striped awning, two display windows with flower boxes, and a prompt at the door.
--- Origin at the front's centre on the pavement.
local function storefront(b: Kit.Builder, name: string, sub: string, colour: Color3, wall: Color3, promptName: string,
	prompt: string, depth: number, width: number)
	local h = 22
	local trim = lighter(wall, 0.55)
	b:part("Shell", Vector3.new(depth, h, width), Vector3.new(depth / 2, h / 2, 0), wall,
		wall == BRICK and M.Brick or M.SmoothPlastic)
	b:decor("Cornice", Vector3.new(depth + 0.8, 1, width + 0.8), Vector3.new(depth / 2, h - 0.6, 0), trim)
	b:decor("Parapet", Vector3.new(depth + 0.4, 1, width + 0.4), Vector3.new(depth / 2, h + 0.4, 0), darker(wall, 0.15))
	b:decor("RoofDeck", Vector3.new(depth - 1, 0.2, width - 1), Vector3.new(depth / 2, h + 0.95, 0),
		Color3.fromRGB(150, 148, 144))
	b:decor("RoofUnit", Vector3.new(5, 3, 4), Vector3.new(depth * 0.6, h + 1.6, width / 4), Color3.fromRGB(206, 208, 204),
		M.Metal)
	-- The facade: trim pilasters, the painted signboard, the glass.
	b:decor("Facade", Vector3.new(0.6, 12.6, width + 0.4), Vector3.new(-0.3, 6.3, 0), darker(wall, 0.3))
	for _, z in ipairs({ -width / 2 + 1, width / 2 - 1 }) do
		b:decor("Pilaster", Vector3.new(0.8, h - 1, 1.6), Vector3.new(-0.4, (h - 1) / 2, z), trim)
	end
	for _, z in ipairs({ -4.6, 4.6 }) do
		b:decor("Pilaster", Vector3.new(0.8, 12.8, 1.2), Vector3.new(-0.4, 6.4, z), trim)
	end
	board(b, name, Kit.Look(Vector3.new(-1.1, 16.2, 0), Vector3.new(-10, 16.2, 0)), width - 10, 4.4, colour, CREAM)
	-- Two big windows either side of the door, the interior lit behind them.
	for _, z in ipairs({ -width / 4 - 1.5, width / 4 + 1.5 }) do
		b:decor("Window", Vector3.new(0.3, 8, width / 2 - 8), Vector3.new(-0.6, 5.6, z), GLASS, M.Glass,
			{ transparency = 0.55, reflectance = 0.15 })
		b:decor("Mullion", Vector3.new(0.46, 8.1, 0.3), Vector3.new(-0.72, 5.6, z), trim)
		b:decor("Display", Vector3.new(3, 1.2, width / 2 - 10), Vector3.new(1.8, 1.1, z), WOOD, M.Wood)
		-- Racks of guns on the back wall of the display.
		for i = -2, 2 do
			b:decor("RackItem", Vector3.new(0.4, 0.5, 3.2), Vector3.new(4, 4 + (i % 2) * 1.6, z + i * 1.8),
				Color3.fromRGB(44, 44, 48), M.Metal)
		end
		b:decor("CeilingLight", Vector3.new(0.4, 0.2, width / 2 - 8), Vector3.new(6, 10.4, z), LAMP_GLASS)
		-- A flower box under the window.
		local box = b:within(CFrame.new(-1.2, 0, z) * CFrame.Angles(0, math.rad(90), 0))
		box:decor("FlowerBox", Vector3.new(width / 2 - 8, 1, 1.2), Vector3.new(0, 1.1, 0), WOOD, M.WoodPlanks)
		for x = -(width / 4 - 4.6), width / 4 - 4.6 + 1e-3, 1.4 do
			box:decor("Tuft", Vector3.new(1, 0.6, 1), CFrame.new(x, 1.85, 0) * CFrame.Angles(0, math.rad(45), 0), HEDGE)
			box:decor("Bloom", Vector3.new(0.6, 0.35, 0.6), Vector3.new(x, 2.25, 0), FLOWERS[(math.floor(x) % 2) + 1])
		end
	end
	b:light("Point", Vector3.new(5, 8, 0), WARM, 1.1, 26)
	-- The door and its prompt.
	b:decor("DoorFrame", Vector3.new(0.5, 9.4, 7), Vector3.new(-0.6, 4.7, 0), colour)
	b:decor("Door", Vector3.new(0.3, 8.6, 6), Vector3.new(-0.66, 4.3, 0), GLASS, M.Glass, { transparency = 0.4 })
	local mat = b:decor("Mat", Vector3.new(3, 0.08, 6), Vector3.new(-2.2, 0.04, 0), darker(colour, 0.3), M.Fabric)
	mat.Name = promptName
	mat:SetAttribute("PromptText", prompt)
	mat:SetAttribute("PromptObject", sub)
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
	painted(b, sub, Kit.Look(Vector3.new(-0.95, 10.4, width / 2 - 4.5), Vector3.new(-10, 10.4, width / 2 - 4.5)), 6, 0.9,
		CREAM)
end

--- ZEE GAS: canopy over two pump islands, the price pylon on the corner. Origin at the
--- forecourt's centre; the road is toward +X.
local function gasStation(b: Kit.Builder)
	local white = Color3.fromRGB(240, 238, 232)
	b:decor("Forecourt", Vector3.new(44, 0.05, 36), Vector3.new(0, 0.525, 0), Color3.fromRGB(112, 114, 120), M.Concrete)
	-- Canopy.
	for _, x in ipairs({ -12, 12 }) do
		for _, z in ipairs({ -8, 8 }) do
			b:part("Column", Vector3.new(1.4, 13, 1.4), Vector3.new(x, 7, z), white)
			b:decor("ColumnBand", Vector3.new(1.5, 1.2, 1.5), Vector3.new(x, 2, z), RED)
		end
	end
	b:part("Canopy", Vector3.new(36, 2, 26), Vector3.new(0, 14.5, 0), white)
	for _, s in ipairs({ -1, 1 }) do
		b:decor("Fascia", Vector3.new(36.2, 0.8, 0.2), Vector3.new(0, 14.3, s * 13.05), RED)
		b:decor("Fascia", Vector3.new(0.2, 0.8, 26.2), Vector3.new(s * 18.05, 14.3, 0), RED)
	end
	board(b, "ZEE GAS", Kit.Look(Vector3.new(18.6, 14.8, 0), Vector3.new(30, 14.8, 0)), 12, 1.5, RED, CREAM)
	for x = -12, 12, 8 do
		b:decor("Downlight", Vector3.new(3, 0.1, 3), Vector3.new(x, 13.45, 0), LAMP_GLASS)
	end
	b:light("Spot", CFrame.new(0, 13.2, 0) * CFrame.Angles(-math.pi / 2, 0, 0), Color3.fromRGB(255, 248, 232), 1.4, 30,
		{ Angle = 150 })
	-- Pump islands.
	for _, z in ipairs({ -5, 5 }) do
		b:part("Island", Vector3.new(14, 0.6, 3), Vector3.new(0, 0.8, z), CURB)
		for _, x in ipairs({ -3.5, 3.5 }) do
			b:part("Pump", Vector3.new(2.2, 5, 1.6), Vector3.new(x, 3.6, z), RED)
			b:decor("PumpScreen", Vector3.new(1.4, 1, 0.1), Vector3.new(x, 4.6, z - 0.82), Color3.fromRGB(40, 70, 64))
			b:decor("PumpTop", Vector3.new(2.4, 0.5, 1.8), Vector3.new(x, 6.3, z), white)
			b:decor("Hose", Vector3.new(0.2, 3, 0.2), Vector3.new(x + 1.2, 3.2, z), Color3.fromRGB(30, 30, 30), M.Rubber)
		end
		-- Crash posts at the island's ends, standing on the forecourt.
		b:part("Barrier", Vector3.new(0.5, 2, 0.5), Vector3.new(-7.4, 1.55, z), GOLD)
		b:part("Barrier", Vector3.new(0.5, 2, 0.5), Vector3.new(7.4, 1.55, z), GOLD)
	end
	-- The price pylon on the corner by the road.
	b:part("Pylon", Vector3.new(1.4, 22, 1.4), Vector3.new(20, 11.5, -16), IRON)
	b:decor("PriceBoard", Vector3.new(1, 9, 7), Vector3.new(20, 19, -16), white)
	b:decor("PriceHead", Vector3.new(1.16, 2.6, 7.16), Vector3.new(20, 22.25, -16), RED)
	painted(b, "ZEE", Kit.Look(Vector3.new(20.6, 22.2, -16), Vector3.new(30, 22.2, -16)), 5, 2, CREAM)
	for i, price in ipairs({ "REG  3.49", "PLUS 3.79", "PREM 4.09" }) do
		painted(b, price, Kit.Look(Vector3.new(20.55, 20.2 - i * 1.7, -16), Vector3.new(30, 20.2 - i * 1.7, -16)), 6, 1.2,
			Color3.fromRGB(40, 60, 54), Enum.Font.GothamBold)
	end
end

--- The 24/7 store with the contracts board outside. Origin at the shop front, facing +X.
local function convenience(b: Kit.Builder)
	b:part("Store", Vector3.new(26, 14, 30), Vector3.new(-13, 7, 0), Color3.fromRGB(240, 234, 220))
	b:decor("Roofline", Vector3.new(26.6, 1.2, 30.6), Vector3.new(-13, 14.2, 0), GREEN)
	b:decor("Stripe", Vector3.new(0.2, 0.6, 30.2), Vector3.new(0.02, 12.9, 0), GOLD)
	b:decor("Glass", Vector3.new(0.3, 8, 20), Vector3.new(0.1, 5, -2), GLASS, M.Glass, { transparency = 0.45, reflectance = 0.2 })
	b:decor("CeilingLight", Vector3.new(0.3, 0.2, 18), Vector3.new(-4, 9.6, -2), LAMP_GLASS)
	for i = 0, 3 do
		b:decor("Shelf", Vector3.new(1.2, 5, 16), Vector3.new(-6 - i * 4, 2.5, -2), Color3.fromRGB(206, 206, 210), M.Metal)
	end
	b:light("Point", Vector3.new(-8, 9, -2), Color3.fromRGB(246, 250, 255), 1, 22)
	board(b, "24/7", Kit.Look(Vector3.new(0.5, 11.1, -2), Vector3.new(10, 11.1, -2)), 9, 2.8, GREEN, CREAM)
	b:decor("Door", Vector3.new(0.3, 7.6, 5), Vector3.new(0.12, 3.8, 11), GLASS, M.Glass, { transparency = 0.35 })
	-- An ice chest and a paper stand by the door.
	b:part("IceChest", Vector3.new(2.4, 3.2, 4), Vector3.new(1.4, 1.6, -14), Color3.fromRGB(236, 242, 248))
	painted(b, "ICE", Kit.Look(Vector3.new(2.62, 2, -14), Vector3.new(10, 2, -14)), 2.4, 1, Color3.fromRGB(60, 120, 200))
	b:part("PaperStand", Vector3.new(1.4, 3, 1.6), Vector3.new(1, 1.5, 7), BLUE)

	-- The contracts board: a cork board on posts, papers pinned, a header, a lamp over it.
	local cork = b:within(CFrame.new(5, 0, 11.5))
	for _, z in ipairs({ -4, 4 }) do
		cork:part("Post", Vector3.new(0.5, 9, 0.5), Vector3.new(0, 4.5, z * 1.175), Color3.fromRGB(96, 68, 48), M.Wood)
	end
	cork:decor("Board", Vector3.new(0.4, 5, 8.6), Vector3.new(0.04, 5.6, 0), Color3.fromRGB(188, 138, 90), M.Wood)
	cork:decor("Frame", Vector3.new(0.5, 5.4, 9), Vector3.new(-0.05, 5.6, 0), Color3.fromRGB(96, 68, 48), M.Wood)
	local rng = Random.new(77)
	for i = 0, 5 do
		local z = -3 + (i % 3) * 3
		local y = 4.4 + math.floor(i / 3) * 2.4
		cork:decor("Paper", Vector3.new(0.05, 1.8, 1.9),
			CFrame.new(0.23, y, z) * CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), 0, 0), Color3.fromRGB(248, 242, 226))
		cork:decor("Pin", Vector3.new(0.12, 0.2, 0.2), Vector3.new(0.28, y + 0.7, z), RED)
	end
	board(cork, "CONTRACTS", Kit.Look(Vector3.new(0.3, 8.9, 0), Vector3.new(10, 8.9, 0)), 8.6, 1.3, NAVY, GOLD)
	local spot = cork:decor("ContractBoard", Vector3.new(3, 0.08, 6), Vector3.new(2, 0.04, 0), Color3.fromRGB(60, 58, 56),
		M.Fabric)
	spot:SetAttribute("PromptText", "Contracts")
	spot:SetAttribute("PromptObject", "Daily jobs")
	cork:decor("LampArm", Vector3.new(1.6, 0.2, 0.2), Vector3.new(0.7, 10.4, 0), IRON)
	cork:decor("LampShade", Vector3.new(1, 0.5, 1.4), Vector3.new(1.4, 10.2, 0), IRON)
	cork:light("Spot", Kit.Look(Vector3.new(1.4, 10, 0), Vector3.new(0, 5.6, 0)), WARM, 1.4, 16, { Angle = 70 })
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
	-- The setbacks, each narrower, each with its own cornice.
	local tiers = { { W - 12, 22, D - 10 }, { W - 26, 16, D - 20 }, { W - 40, 10, D - 28 } }
	local y = H
	for i, t in ipairs(tiers) do
		local tw, th, td = t[1], t[2], t[3]
		b:part("Setback", Vector3.new(tw, th, td), Vector3.new(0, y + th / 2, D / 2), i % 2 == 1 and stone or glass,
			i % 2 == 1 and M.SmoothPlastic or M.Glass)
		for k = 1, math.floor(th / 6) do
			b:decor("SetbackWindows", Vector3.new(tw * 0.8, 2.4, 0.3), Vector3.new(0, y + k * 6 - 1, D / 2 - td / 2 - 0.1),
				i % 2 == 1 and glass or stone, i % 2 == 1 and M.Glass or M.SmoothPlastic)
		end
		b:decor("SetbackCornice", Vector3.new(tw + 1, 1, td + 1), Vector3.new(0, y + th - 0.55, D / 2), stone)
		y += th
	end
	b:part("Spire", Vector3.new(30, 1.4, 1.4), vertical(Vector3.new(0, y + 15, D / 2)), stone, nil, { shape = "Cylinder" })
	b:decor("SpireBand", Vector3.new(1, 2.2, 2.2), vertical(Vector3.new(0, y + 4, D / 2)), GOLD, nil, { shape = "Cylinder" })
	b:decor("Beacon", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, y + 30.5, D / 2), RED, nil, { shape = "Ball" })
	-- The name, high up, facing down the avenue.
	board(b, "ZEE", Kit.Look(Vector3.new(0, H - 14, -1.4), Vector3.new(0, H - 14, -10)), 26, 11, TEAL, CREAM)
	b:light("Point", Vector3.new(0, 14, -4), WARM, 1.2, 36)
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
					CAR_COLOURS[(n * 5) % #CAR_COLOURS + 1])
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

	-- Benches facing the stage, and more along the path.
	for _, spot in ipairs({ { -7, 17 }, { 13, 17 }, { -7, 11 }, { 13, 11 } }) do
		bench(b:within(CFrame.new(spot[1], 0, spot[2]) * CFrame.Angles(0, math.pi, 0)))
	end
	bench(b:within(CFrame.new(10, 0, -24) * CFrame.Angles(0, math.rad(90), 0)))
	bench(b:within(CFrame.new(-3, 0, -30) * CFrame.Angles(0, math.rad(-90), 0)))
	cafeTable(b:within(CFrame.new(15, 0, -12)), Color3.fromRGB(236, 88, 96))
	cafeTable(b:within(CFrame.new(16, 0, 6)), Color3.fromRGB(64, 170, 230))

	-- Round trees, flowers and grass.
	for i, spot in ipairs({ { -13, -34 }, { 14, -36 }, { -8, -20 }, { 17, -24 }, { -17, 24 }, { -16, 38 }, { 18, 40 },
		{ 19, 31 } }) do
		tree(b:within(CFrame.new(spot[1], 0.1, spot[2])), 300 + i, i == 3 or i == 6, true)
	end
	local rng = Random.new(505)
	for i = 1, 14 do
		local at = Vector3.new(rng:NextNumber(-halfX + 2, halfX - 2), 0.1, rng:NextNumber(-halfZ + 2, halfZ - 2))
		if math.abs(at.X - 4) > 5 and (at - Vector3.new(-10, 0.1, -2)).Magnitude > 13 and (at - Vector3.new(5, 0.1, 31)).Magnitude > 14 then
			flowerClump(b:within(CFrame.new(at)), FLOWERS[(i % #FLOWERS) + 1], i)
		end
	end
	for i = 1, 40 do
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

local function mailbox(b: Kit.Builder)
	local blue = Color3.fromRGB(40, 92, 176)
	for _, x in ipairs({ -0.55, 0.55 }) do
		b:decor("MailLeg", Vector3.new(0.2, 1, 1.1), Vector3.new(x, 0.5, 0), SIGNAL_BLACK)
	end
	b:part("MailBox", Vector3.new(1.7, 2, 1.5), Vector3.new(0, 2, 0), blue)
	b:decor("MailTop", Vector3.new(1.44, 1.7, 1.7), CFrame.new(0, 3, 0) * CFrame.Angles(0, math.rad(90), 0), blue, nil,
		{ shape = "Cylinder" })
	b:decor("MailSlot", Vector3.new(1, 0.2, 0.1), Vector3.new(0, 2.7, -0.78), SIGNAL_BLACK)
	b:decor("MailBadge", Vector3.new(0.9, 0.9, 0.08), Vector3.new(0, 1.9, -0.78), TRIM)
end

local function newsStands(b: Kit.Builder)
	for i, colour in ipairs({ Color3.fromRGB(214, 52, 52), Color3.fromRGB(250, 196, 50), Color3.fromRGB(56, 140, 220) }) do
		local x = (i - 2) * 1.35
		b:part("NewsBox", Vector3.new(1.2, 2.4, 1.1), Vector3.new(x, 1.2, 0), colour)
		b:decor("NewsWindow", Vector3.new(0.9, 0.9, 0.08), Vector3.new(x, 1.8, -0.56), Color3.fromRGB(236, 236, 230))
		b:decor("NewsCoin", Vector3.new(0.3, 0.4, 0.1), Vector3.new(x + 0.3, 1, -0.57), SIGNAL_BLACK)
	end
end

local function bikeRack(b: Kit.Builder)
	b:decor("RackRail", Vector3.new(6, 0.2, 0.2), Vector3.new(0, 0.1, 0), STEEL, M.Metal)
	for x = -2.4, 2.4 + 1e-3, 1.2 do
		b:decor("Hoop", Vector3.new(0.18, 2.4, 0.18), Vector3.new(x, 1.2, -0.7), STEEL, M.Metal)
		b:decor("Hoop", Vector3.new(0.18, 2.4, 0.18), Vector3.new(x, 1.2, 0.7), STEEL, M.Metal)
		b:decor("HoopTop", Vector3.new(0.18, 0.18, 1.58), Vector3.new(x, 2.4, 0), STEEL, M.Metal)
	end
end

local function parkingMeter(b: Kit.Builder)
	b:decor("MeterPost", Vector3.new(0.25, 3, 0.25), Vector3.new(0, 1.5, 0), STEEL, M.Metal)
	b:decor("MeterHead", Vector3.new(0.7, 1, 0.5), Vector3.new(0, 3.4, 0), Color3.fromRGB(150, 156, 164), M.Metal)
	b:decor("MeterDial", Vector3.new(0.5, 0.4, 0.06), Vector3.new(0, 3.5, -0.26), Color3.fromRGB(236, 196, 40))
end

--- Pennant bunting strung between two points with a sag, flags in rainbow colours. The
--- flags are right-angled wedges turned 45 degrees, so each hangs as a point-down triangle.
local function bunting(b: Kit.Builder, from: Vector3, to: Vector3, sag: number)
	local segments = 8
	local prev = from
	local function at(t: number): Vector3
		return from:Lerp(to, t) - Vector3.new(0, math.sin(t * math.pi) * sag, 0)
	end
	for k = 1, segments do
		local p = at(k / segments)
		local cf, len = Kit.Span(prev, p)
		b:decor("BuntingLine", Vector3.new(0.08, 0.08, len + 0.04), cf, Color3.fromRGB(240, 240, 236))
		prev = p
	end
	local along = (to - from)
	local flat = Vector3.new(along.X, 0, along.Z).Unit
	local normal = Vector3.new(-flat.Z, 0, flat.X)
	local count = math.floor(along.Magnitude / 2.6)
	for k = 1, count - 1 do
		local p = at(k / count)
		local colour = if k % 5 == 0 then TRIM else RAINBOW_FLAGS[(k % #RAINBOW_FLAGS) + 1]
		local frame = CFrame.fromMatrix(p, normal, Vector3.new(0, 1, 0)) * CFrame.Angles(math.rad(45), 0, 0)
		b:decor("Pennant", Vector3.new(0.06, 1.3, 1.3), frame, colour, M.Fabric, { shape = "Wedge" })
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
	sign:sign("← ZEE GAS  ·  24/7         ZEE GUNS  ·  ARMORY →", Kit.Look(Vector3.new(0, -1.3, -0.3), Vector3.new(0, -1.3, -10)),
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
		{ 16, 32, -72, -56 }, { 16, 32, -118, -102 },     -- ZEE GUNS, ARMORY
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
					lamp(root:within(CFrame.new(p) * CFrame.Angles(0, math.rad(yaw), 0)), count % 2 == 0,
						avenue and TEAL or RED)
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

	-- Parked cars along the kerbs, nose to tail with gaps, never in front of a door.
	local carIndex = 0
	local function parkRow(alongZ: boolean, across: number, from: number, to: number, step: number, facing: number)
		for d = from, to, step do
			carIndex += 1
			local colour = CAR_COLOURS[(carIndex * 3) % #CAR_COLOURS + 1]
			local cf = alongZ and (CFrame.new(across, 0, d) * CFrame.Angles(0, math.rad(facing), 0))
				or (CFrame.new(d, 0, across) * CFrame.Angles(0, math.rad(facing), 0))
			car(root:within(cf), colour)
			-- A parking meter at the kerb beside every car.
			local meter = alongZ and Vector3.new(across + math.sign(across) * 4.6, 0.51, d)
				or Vector3.new(d, 0.51, across + math.sign(across) * 4.6)
			parkingMeter(root:within(CFrame.new(meter)))
		end
	end
	parkRow(true, 14.5, 70, 180, 27, 180)
	parkRow(true, -14.5, -150, -70, 27, 0)
	parkRow(false, 14.5, 70, 170, 33, 90)
	parkRow(false, -14.5, -180, -70, 33, -90)

	-- ------------------------------------------------------------ street kit --

	-- Traffic lights where each arm meets the plaza crossing, the street names on top.
	for _, arm in ipairs({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
		local ax, az = arm[1], arm[2]
		for _, side in ipairs({ -1, 1 }) do
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

	-- Along the walks, between the lamps and trees, on the building side: phone booths,
	-- mailboxes and news stands, bike racks, benches and planters, in turn.
	local kitCount = 0
	for _, arm in ipairs({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
		local ax, az = arm[1], arm[2]
		for _, d in ipairs({ 82, 112, 142, 172 }) do
			if not (az == -1 and d > HW - 60) then
				for _, side in ipairs({ -1, 1 }) do
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
						local pick = kitCount % 5
						if pick == 1 then
							phoneBooth(k)
						elseif pick == 2 then
							mailbox(k:within(CFrame.new(-2.2, 0, 0)))
							newsStands(k:within(CFrame.new(1.6, 0, 0)))
						elseif pick == 3 then
							bikeRack(k)
						elseif pick == 4 then
							bench(k:within(CFrame.new(0, -0.51, 0)))
						else
							flowerBed(k:within(CFrame.new(0, -0.01, 0)), 6, 2.4, kitCount)
						end
					end
				end
			end
		end
	end

	-- Bunting strung across every arm between the first and third pairs of lamps.
	for _, arm in ipairs({ { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }) do
		local ax, az = arm[1], arm[2]
		for _, d in ipairs({ PLAZA + 20, PLAZA + 80 }) do
			if ax == 0 then
				bunting(root, Vector3.new(-(ROAD + 2), 12.4, az * d), Vector3.new(ROAD + 2, 12.4, az * d), 1.2)
			else
				bunting(root, Vector3.new(ax * d, 12.4, -(ROAD + 2)), Vector3.new(ax * d, 12.4, ROAD + 2), 1.2)
			end
		end
	end

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

	-- South-east: ZEE GUNS and the ARMORY on the avenue, a car park south of them, and a
	-- street wall of offices behind.
	storefront(root:within(CFrame.new(ROAD + WALK + 2, 0.5, -64)), "ZEE GUNS", "Gun Shop", GREEN, BRICK, "GunShop",
		"Browse guns", 34, 40)
	storefront(root:within(CFrame.new(ROAD + WALK + 2, 0.5, -110)), "ARMORY", "Attachments & Camos", ORANGE, FACADE[8],
		"Armory", "Customise", 34, 40)
	carPark(root, ROAD + WALK + 2, 64, -186, -136, 4)
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
	carPark(root, -76, -(ROAD + WALK + 2), -132, -80, 5)
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
				-- A crown on every tower: a set-back top storey in a lighter tone with a trim cap,
				-- and on every third a mast with a red beacon, so the skyline has a silhouette.
				local cx, cz = (box[1] + box[2]) / 2, (box[3] + box[4]) / 2
				local cw, cd = (box[2] - box[1]) * 0.56, (box[4] - box[3]) * 0.56
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
		board(root, if s > 0 then "EAST END" else "WEST END", Kit.Look(signAt, signAt - Vector3.new(s, 0, 0)), 18, 3,
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
		building(sky, x - w / 2, x + w / 2, z - w / 2, z + w / 2, 120 + ((k * 37) % 6) * 30, FACADE[(k % #FACADE) + 1],
			{ math.abs(x) > math.abs(z) and (x > 0 and "-x" or "+x") or (z > 0 and "-z" or "+z") }, 100 + k, true)
	end

	-- The edge: nothing to fall off.
	Kit.Bounds(root, HW - 12, HW - 12, 200)
end

return Downtown
