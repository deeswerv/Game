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
local LEAF = Color3.fromRGB(86, 152, 72)
local LEAF_LIGHT = Color3.fromRGB(128, 186, 94)
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

-- Soft facade colours; every building gets cream-ish trim from its own colour.
local FACADE = {
	Color3.fromRGB(204, 120, 92),    -- terracotta
	Color3.fromRGB(226, 202, 160),   -- sand
	Color3.fromRGB(154, 176, 146),   -- sage
	Color3.fromRGB(124, 154, 184),   -- dusty blue
	Color3.fromRGB(236, 226, 206),   -- cream
	Color3.fromRGB(170, 92, 74),     -- brick
	Color3.fromRGB(220, 176, 100),   -- mustard
	Color3.fromRGB(116, 124, 140),   -- slate
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

--- A street lamp: an iron post with a lantern on an arm reaching toward -X (over the road),
--- a street banner and a basket of flowers.
local function lamp(b: Kit.Builder, withLight: boolean, banner: Color3?)
	b:part("Base", Vector3.new(1.6, 1.2, 1.6), Vector3.new(0, 1.1, 0), IRON)
	b:decor("Plinth", Vector3.new(1.1, 0.8, 1.1), Vector3.new(0, 2.1, 0), IRON)
	b:part("Pole", Vector3.new(15, 0.5, 0.5), vertical(Vector3.new(0, 9.5, 0)), IRON, nil, { shape = "Cylinder" })
	b:decor("Collar", Vector3.new(0.4, 0.8, 0.8), vertical(Vector3.new(0, 6.2, 0)), IRON, nil, { shape = "Cylinder" })
	b:decor("Arm", Vector3.new(4.6, 0.3, 0.3), Vector3.new(-2.1, 16.4, 0), IRON)
	local brace, len = Kit.Span(Vector3.new(0, 14.6, 0), Vector3.new(-2.6, 16.3, 0))
	b:decor("Brace", Vector3.new(0.2, 0.2, len), brace, IRON)
	-- The lantern hangs from the arm's end: a cap, four panes of warm glass, a base.
	b:decor("Hanger", Vector3.new(0.2, 0.8, 0.2), Vector3.new(-4.2, 16, 0), IRON)
	b:decor("LanternCap", Vector3.new(1.8, 0.4, 1.8), Vector3.new(-4.2, 15.5, 0), IRON)
	b:decor("LanternTop", Vector3.new(1, 0.4, 1), Vector3.new(-4.2, 15.85, 0), IRON)
	b:decor("LanternGlass", Vector3.new(1.3, 1.6, 1.3), Vector3.new(-4.2, 14.5, 0), LAMP_GLASS)
	b:decor("LanternBase", Vector3.new(1.5, 0.3, 1.5), Vector3.new(-4.2, 13.55, 0), IRON)
	if banner then
		b:decor("BannerRod", Vector3.new(0.15, 0.15, 2.1), Vector3.new(0, 12.7, 1.15), IRON)
		b:decor("Banner", Vector3.new(0.1, 3.4, 1.7), Vector3.new(0, 10.9, 1.25), banner, M.Fabric)
		b:decor("BannerStripe", Vector3.new(0.12, 0.4, 1.7), Vector3.new(0, 9.6, 1.25), CREAM, M.Fabric)
	end
	b:decor("Bracket", Vector3.new(1.2, 0.15, 0.15), Vector3.new(0.7, 8.9, 0), IRON)
	b:decor("Basket", Vector3.new(1.4, 0.8, 1.4), Vector3.new(1.3, 8.1, 0), WOOD, M.WoodPlanks)
	b:decor("Trailing", Vector3.new(1.8, 1, 1.8), CFrame.new(1.3, 8.7, 0) * CFrame.Angles(0, math.rad(45), 0), HEDGE)
	b:decor("Bloom", Vector3.new(1.2, 0.5, 1.2), Vector3.new(1.3, 9.3, 0), FLOWERS[1])
	if withLight then
		b:light("Spot", CFrame.new(-4.2, 13.4, 0) * CFrame.Angles(-math.pi / 2, 0, 0), WARM, 1.6, 34, { Angle = 120 })
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
	b:part("Trunk", Vector3.new(7, 0.8, 0.8), vertical(Vector3.new(0, 4.9, 0)), BARK, M.Wood, { shape = "Cylinder" })
	local rng = Random.new(seed)
	local dark, light = LEAF, LEAF_LIGHT
	if blossom then
		dark, light = BLOSSOM, BLOSSOM_LIGHT
	end
	for i, blob in ipairs({ { Vector3.new(0, 9.2, 0), 5.8 }, { Vector3.new(1.9, 8.2, 0.9), 4.2 },
		{ Vector3.new(-1.7, 8.4, -1), 4.4 }, { Vector3.new(0.3, 11.2, -0.3), 3.8 } }) do
		local s = blob[2] * rng:NextNumber(0.9, 1.1)
		local turn = CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, math.pi), rng:NextNumber(-0.6, 0.6))
		b:decor("Leaves", Vector3.new(s, s, s), CFrame.new(blob[1]) * turn, i % 2 == 0 and light or dark,
			M.SmoothPlastic, { shadow = true })
	end
end

local function bench(b: Kit.Builder)
	b:part("Seat", Vector3.new(6, 0.35, 1.6), Vector3.new(0, 1.9, 0), WOOD, M.Wood)
	b:decor("Back", Vector3.new(6, 1.4, 0.3), CFrame.new(0, 2.9, 0.75) * CFrame.Angles(math.rad(-10), 0, 0), WOOD, M.Wood)
	for _, x in ipairs({ -2.5, 2.5 }) do
		b:decor("Leg", Vector3.new(0.3, 1.4, 1.6), Vector3.new(x, 1.2, 0), IRON)
		b:decor("Arm", Vector3.new(0.3, 0.25, 1.4), Vector3.new(x, 2.5, 0.1), IRON)
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
		b:decor("Bumper", Vector3.new(4.7, 0.6, 0.3), Vector3.new(0, 1.1, z), trim)
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

--- A block building from the ground to `top`: a ground-floor band with shopfronts (and on
--- some an awning), window bands between trim pilasters on the faces listed ("+x", "-x",
--- "+z", "-z", or "all"), a stepped cornice and a few things on the roof. `simple` skips the
--- close-up detail, for the far skyline.
local function building(b: Kit.Builder, x0: number, x1: number, z0: number, z1: number, top: number,
	colour: Color3, faces: { string }, seed: number, simple: boolean?)
	local w, d = x1 - x0, z1 - z0
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local base = -2
	local trim = lighter(colour, 0.5)
	b:part("Building", Vector3.new(w, top - base, d), Vector3.new(cx, (top + base) / 2, cz), colour,
		colour == BRICK and M.Brick or M.SmoothPlastic)
	b:decor("Cornice", Vector3.new(w + 1.2, 1, d + 1.2), Vector3.new(cx, top - 1.4, cz), trim)
	b:decor("Cap", Vector3.new(w + 0.6, 0.8, d + 0.6), Vector3.new(cx, top + 0.3, cz), darker(colour, 0.12))
	local rng = Random.new(seed)
	if faces[1] == "all" then
		faces = { "+x", "-x", "+z", "-z" }
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
		if not simple then
			-- Ground floor: a darker band, a glass shopfront run, a trim course over it.
			slab("Ground", span, 7, 0.3, 3.5, 0, darker(colour, 0.25))
			slab("Shopfront", span * 0.84, 4.6, 0.5, 3.8, 0, GLASS, M.Glass, { reflectance = 0.2 })
			slab("Course", span + 0.2, 0.8, 0.6, 7.4, 0, trim)
			if rng:NextNumber() < 0.55 then
				local p = on(6.6, 1.6, 0)
				local awning = b:part("Awning", Vector3.new(span * 0.8, 1.4, 3.2), Kit.Look(p, p + normal),
					AWNINGS[rng:NextInteger(1, #AWNINGS)], M.Fabric, { shape = "Wedge", collide = false })
				awning.CastShadow = true
			end
		end
		-- Floors above: a band of glass each, split into windows by trim pilasters.
		for y = 11, top - 5, 7 do
			slab("Windows", span * 0.9, 3, 0.3, y, 0, GLASS, M.Glass, { reflectance = 0.15 })
		end
		if not simple and top > 14 then
			local count = math.max(2, math.floor(span / 8))
			for k = 0, count do
				local along = -span * 0.45 + k * (span * 0.9 / count)
				slab("Pilaster", 0.9, top - 9.6, 0.6, (top + 7.8 - 1.8) / 2, along, trim)
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
	for _, edge in ipairs({ -16.8, 16.8 }) do
		strip("EdgeLine", edge, mid, len, 0.3, WHITE_LINE)
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
	for _, edge in ipairs(kerbs or {}) do
		if edge == "-x" then
			b:decor("Kerb", Vector3.new(0.5, 0.56, z1 - z0), Vector3.new(x0 + 0.25, 0.28, cz), CURB, M.Concrete)
		elseif edge == "+x" then
			b:decor("Kerb", Vector3.new(0.5, 0.56, z1 - z0), Vector3.new(x1 - 0.25, 0.28, cz), CURB, M.Concrete)
		elseif edge == "-z" then
			b:decor("Kerb", Vector3.new(x1 - x0, 0.56, 0.5), Vector3.new(cx, 0.28, z0 + 0.25), CURB, M.Concrete)
		elseif edge == "+z" then
			b:decor("Kerb", Vector3.new(x1 - x0, 0.56, 0.5), Vector3.new(cx, 0.28, z1 - 0.25), CURB, M.Concrete)
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
				b:decor("Tile", Vector3.new(tile - 0.3, 0.04, tile - 0.3), Vector3.new(x, 0.52, z), PLAZA_A, M.Slate)
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
		b:decor("Pilaster", Vector3.new(0.8, 12.6, 1.2), Vector3.new(-0.4, 6.3, z), trim)
	end
	board(b, name, Kit.Look(Vector3.new(-1.1, 16.2, 0), Vector3.new(-10, 16.2, 0)), width - 10, 4.4, colour, CREAM)
	-- Two big windows either side of the door, the interior lit behind them.
	for _, z in ipairs({ -width / 4 - 1.5, width / 4 + 1.5 }) do
		b:decor("Window", Vector3.new(0.3, 8, width / 2 - 8), Vector3.new(-0.6, 5.6, z), GLASS, M.Glass,
			{ transparency = 0.55, reflectance = 0.15 })
		b:decor("Mullion", Vector3.new(0.4, 8, 0.3), Vector3.new(-0.7, 5.6, z), trim)
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
	b:decor("Door", Vector3.new(0.3, 8.6, 6), Vector3.new(-0.7, 4.3, 0), GLASS, M.Glass, { transparency = 0.4 })
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
	b:decor("Forecourt", Vector3.new(44, 0.06, 36), Vector3.new(0, 0.53, 0), Color3.fromRGB(112, 114, 120), M.Concrete)
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
		b:part("Barrier", Vector3.new(0.5, 2, 0.5), Vector3.new(-7.4, 2, z), GOLD)
		b:part("Barrier", Vector3.new(0.5, 2, 0.5), Vector3.new(7.4, 2, z), GOLD)
	end
	-- The price pylon on the corner by the road.
	b:part("Pylon", Vector3.new(1.4, 22, 1.4), Vector3.new(20, 11.5, -16), IRON)
	b:decor("PriceBoard", Vector3.new(1, 9, 7), Vector3.new(20, 19, -16), white)
	b:decor("PriceHead", Vector3.new(1.1, 2.6, 7.1), Vector3.new(20, 22.2, -16), RED)
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
		cork:part("Post", Vector3.new(0.5, 9, 0.5), Vector3.new(0, 4.5, z), Color3.fromRGB(96, 68, 48), M.Wood)
	end
	cork:decor("Board", Vector3.new(0.4, 5, 8.6), Vector3.new(0, 5.6, 0), Color3.fromRGB(188, 138, 90), M.Wood)
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
		b:decor("SideInside", Vector3.new(D - 0.2, H - 1, 0.2), Vector3.new(-D / 2, H / 2, s * (W / 2 - 0.1)), wallIn)
		b:decor("SideStripe", Vector3.new(D - 0.4, 1.6, 0.3), Vector3.new(-D / 2, H - 5, s * (W / 2 - 0.15)), team)
		-- The front piers either side of the opening.
		b:part("Pier", Vector3.new(3, H, 10), Vector3.new(-1.5, H / 2, s * (W / 2 - 4)), wallOut)
		b:decor("PierBand", Vector3.new(3.1, 1.6, 10.1), Vector3.new(-1.5, H - 5, s * (W / 2 - 4)), team)
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
			b:decor("BannerBand", Vector3.new(3.8, 0.6, 0.18), Vector3.new(x, H - 13, s * (W / 2 - 0.5)), CREAM, M.Fabric)
		end
	end
	b:part("Roof", Vector3.new(D + 4, 1.4, W + 4), Vector3.new(-D / 2, H + 0.7, 0), Color3.fromRGB(120, 126, 140))
	b:decor("RoofTrim", Vector3.new(D + 4.4, 0.6, W + 4.4), Vector3.new(-D / 2, H + 1.6, 0), CREAM)
	for _, x in ipairs({ -D * 0.3, -D * 0.7 }) do
		b:decor("RoofUnit", Vector3.new(6, 3, 5), Vector3.new(x, H + 3.4, 0), Color3.fromRGB(206, 208, 204), M.Metal)
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
		b:decor("Line", Vector3.new(0.3, 0.05, L), Vector3.new(s * W / 2, 0.84, 0), line)
		b:decor("Line", Vector3.new(W, 0.05, 0.3), Vector3.new(0, 0.84, s * L / 2), line)
		b:decor("Paint", Vector3.new(8, 0.05, 9), Vector3.new(0, 0.85, s * (L / 2 - 4.5)), courtBlue)
		-- Hoop: pole, arm, backboard, rim.
		local h = b:within(CFrame.new(0, 0.8, s * (L / 2 + 2)) * CFrame.Angles(0, s > 0 and 0 or math.pi, 0))
		h:part("Pole", Vector3.new(0.6, 11, 0.6), Vector3.new(0, 5.5, 0), IRON)
		h:decor("Arm", Vector3.new(0.4, 0.4, 3), Vector3.new(0, 10.6, -1.5), IRON)
		h:decor("Backboard", Vector3.new(6, 3.6, 0.2), Vector3.new(0, 10.8, -3), Color3.fromRGB(244, 244, 244), M.Glass,
			{ transparency = 0.2 })
		h:decor("Square", Vector3.new(2.4, 1.6, 0.22), Vector3.new(0, 10.2, -3.02), RED)
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
		b:decor("Base", Vector3.new(12, 16, 1.4), Vector3.new(s * (W / 2 - 6), 8, -0.7), stone)
	end
	b:decor("Lobby", Vector3.new(W - 24, 14, 0.4), Vector3.new(0, 7, -0.5), Color3.fromRGB(200, 220, 236), M.Glass,
		{ transparency = 0.4 })
	b:decor("LobbyBand", Vector3.new(W + 1, 2, 1.4), Vector3.new(0, 15, -0.7), stone)
	b:part("Canopy", Vector3.new(24, 0.8, 10), Vector3.new(0, 12.4, -5), NAVY)
	b:decor("CanopyTrim", Vector3.new(24.2, 0.4, 0.3), Vector3.new(0, 12.2, -10.05), GOLD)
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
		b:decor("SetbackCornice", Vector3.new(tw + 1, 1, td + 1), Vector3.new(0, y + th - 0.5, D / 2), stone)
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
	b:decor("Path", Vector3.new(W, 0.12, 3), Vector3.new(0, 0.56, 0), PLAZA_A, M.Slate)
	b:decor("Path", Vector3.new(3, 0.12, D), Vector3.new(0, 0.56, 0), PLAZA_A, M.Slate)
	-- A low clipped hedge round the lawn, open where the paths come in.
	for _, s in ipairs({ -1, 1 }) do
		for _, h in ipairs({ -1, 1 }) do
			b:part("Hedge", Vector3.new(W / 2 - 2.5, 1.8, 1.2), Vector3.new(h * (W / 4 + 1.25), 1.4, s * (D / 2 - 0.6)), HEDGE)
			b:part("Hedge", Vector3.new(1.2, 1.8, D / 2 - 2.5), Vector3.new(s * (W / 2 - 0.6), 1.4, h * (D / 4 + 1.25)), HEDGE)
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
	sign:decor("Board", Vector3.new(34, 6, 0.4), Vector3.new(0, 0, 0), Color3.fromRGB(34, 118, 76))
	sign:decor("Border", Vector3.new(33, 5.2, 0.42), Vector3.new(0, 0, 0), Color3.fromRGB(240, 240, 236))
	sign:decor("Inner", Vector3.new(32.4, 4.6, 0.44), Vector3.new(0, 0, 0), Color3.fromRGB(34, 118, 76))
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
	shelter:decor("AdBand", Vector3.new(0.32, 1.4, 3.6), Vector3.new(-2.2, 2.2, 3.6), RED)
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
		end
	end
	parkRow(true, 14.5, 70, 180, 27, 180)
	parkRow(true, -14.5, -150, -70, 27, 0)
	parkRow(false, 14.5, 70, 170, 33, 90)
	parkRow(false, -14.5, -180, -70, 33, -90)

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
		building(root, spec[1], spec[2], spec[3], spec[4], spec[5], FACADE[spec[6]], { "all" }, spec[1] + spec[3])
	end

	-- South-west: ZEE GAS on the corner, the 24/7 behind it, a car park, offices.
	gasStation(root:within(CFrame.new(-(ROAD + WALK + 26), 0, -52)))
	convenience(root:within(CFrame.new(-(ROAD + WALK + 52), 0.5, -52)))
	carPark(root, -76, -(ROAD + WALK + 2), -132, -80, 5)
	for _, spec in ipairs({
		{ -186, -110, -72, -34, 40, 4 }, { -186, -110, -150, -76, 28, 2 }, { -106, -80, -150, -76, 24, 7 },
		{ -186, -120, -186, -154, 34, 3 }, { -120, -34, -186, -140, 26, 1 },
	}) do
		building(root, spec[1], spec[2], spec[3], spec[4], spec[5], FACADE[spec[6]], { "all" }, spec[2] + spec[4])
	end

	-- North-west: the DUEL HALL, open to the avenue, a pocket park on the corner.
	duelHall(root:within(CFrame.new(-(ROAD + WALK + 4), 0.5, 88)))
	pocketPark(root:within(CFrame.new(-64, 0, 45)))
	for _, spec in ipairs({
		{ -186, -150, 34, 110, 50, 5 }, { -186, -150, 110, 186, 38, 1 }, { -146, -104, 34, 120, 34, 4 },
		{ -146, -104, 124, 186, 26, 2 }, { -96, -62, 124, 186, 32, 3 }, { -62, -34, 124, 150, 24, 7 },
	}) do
		building(root, spec[1], spec[2], spec[3], spec[4], spec[5], FACADE[spec[6]], { "all" }, spec[1] - spec[3])
	end

	-- North-east: the court, the apartments with the fire escape, offices round them.
	court(root:within(CFrame.new(ROAD + WALK + 26, 0.5, 80)))
	apartments(root:within(CFrame.new(ROAD + WALK + 60, 0.5, 80)))
	for _, spec in ipairs({
		{ 34, 76, 118, 186, 40, 8 }, { 76, 130, 118, 186, 28, 1 }, { 130, 186, 118, 186, 52, 3 },
		{ 122, 186, 34, 76, 34, 4 }, { 122, 186, 76, 114, 24, 5 },
	}) do
		building(root, spec[1], spec[2], spec[3], spec[4], spec[5], FACADE[spec[6]], { "all" }, spec[2] - spec[4])
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
			if side == "n" and not gap and math.abs(a) > 32 then
				building(root, a - 19, a + 19, HW - 10, HW + 30, h, colour, { "-z" }, i)
			elseif side == "s" and not gap then
				building(root, a - 19, a + 19, -HW - 30, -HW + 10, h, colour, { "+z" }, i)
			elseif side == "e" and not gap then
				building(root, HW - 10, HW + 30, a - 19, a + 19, h, colour, { "-x" }, i)
			elseif side == "w" and not gap then
				building(root, -HW - 30, -HW + 10, a - 19, a + 19, h, colour, { "+x" }, i)
			end
		end
	end
	-- Where the cross street leaves the district east and west, a tunnel mouth under a
	-- bridge building, so the road seems to go on.
	for _, s in ipairs({ -1, 1 }) do
		root:part("Bridge", Vector3.new(40, 60, ROAD * 2 + WALK * 2 + 4), Vector3.new(s * (HW + 10), 45, 0), FACADE[2])
		root:decor("BridgeCourse", Vector3.new(40.6, 1.2, ROAD * 2 + WALK * 2 + 4.6), Vector3.new(s * (HW + 10), 16, 0),
			lighter(FACADE[2], 0.5))
		root:decor("Tunnel", Vector3.new(4, 14, ROAD * 2), Vector3.new(s * (HW - 8), 7, 0), Color3.fromRGB(24, 24, 28))
		root:part("TunnelWall", Vector3.new(4, 15, 2), Vector3.new(s * (HW - 8), 7.5, ROAD + 1), FACADE[2])
		root:part("TunnelWall", Vector3.new(4, 15, 2), Vector3.new(s * (HW - 8), 7.5, -ROAD - 1), FACADE[2])
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
