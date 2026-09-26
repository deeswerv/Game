--!strict
-- SAKURA TEMPLE: a temple courtyard at dusk, cherry trees in bloom.
--
-- Each spawn stands inside its own gate house, a great red lantern hanging over it, with a
-- torii ahead. A stone path runs down the middle past pairs of lanterns to the koi pond,
-- crossed by an arched red bridge. Either lane has its piece: on one, a raised kagura stage
-- under its own roof; on the other, the bell tower and a length of temple wall. Rocks at
-- the pond's corners and trees in the gravel beds finish the cover. The other half is the
-- same, turned round (Kit.Both).
--
-- Beyond the plastered walls: more trees, a five-storey pagoda to either side, and hills.

local Kit = require(script.Parent.Kit)

local Map = {}

Map.Id = "Temple"
Map.Name = "SAKURA TEMPLE"
Map.Tagline = "Temple courtyard at dusk"
Map.HalfWidth = 46
Map.HalfLength = 66
Map.Height = 40
Map.Spawns = { Vector3.new(0, 3, -57), Vector3.new(0, 3, 57) }
Map.Mood = "sunset"
Map.Exposure = 1.05

-- Dusk: the sun on the horizon, a pink haze, the lanterns doing most of the work.
Map.Look = {
	Lighting = {
		ClockTime = 17.85,
		Brightness = 2.3,
		Ambient = Color3.fromRGB(112, 92, 120),
		OutdoorAmbient = Color3.fromRGB(152, 122, 152),
		ColorShift_Top = Color3.fromRGB(255, 158, 168),
		ExposureCompensation = 0.15,
		EnvironmentDiffuseScale = 0.6,
		EnvironmentSpecularScale = 0.6,
	},
	Atmosphere = {
		Density = 0.34,
		Offset = 0.2,
		Color = Color3.fromRGB(255, 186, 206),
		Decay = Color3.fromRGB(150, 108, 172),
		Glare = 0.5,
		Haze = 2.3,
	},
	Grade = {
		Brightness = 0.01,
		Contrast = 0.12,
		Saturation = 0.22,
		TintColor = Color3.fromRGB(255, 236, 244),
	},
	Bloom = { Intensity = 0.9, Size = 26, Threshold = 1.3 },
	SunRays = { Intensity = 0.1 },
	Clouds = { Cover = 0 },
}

local M = Enum.Material

local PAVING = Color3.fromRGB(176, 172, 164)
local FLAG = Color3.fromRGB(150, 146, 140)
local GRAVEL = Color3.fromRGB(208, 198, 180)
local VERMILION = Color3.fromRGB(196, 50, 38)
local BLACK = Color3.fromRGB(28, 26, 26)
local WOOD = Color3.fromRGB(150, 104, 66)
local WOOD_DARK = Color3.fromRGB(78, 50, 38)
local PLASTER = Color3.fromRGB(236, 228, 212)
local TILE = Color3.fromRGB(56, 62, 76)
local STONE = Color3.fromRGB(150, 148, 142)
local MOSS = Color3.fromRGB(96, 128, 70)
local GOLD = Color3.fromRGB(222, 176, 74)
local BRONZE = Color3.fromRGB(116, 88, 54)
local WATER = Color3.fromRGB(64, 128, 144)
local GLOW = Color3.fromRGB(255, 188, 112)
local BARK = Color3.fromRGB(74, 52, 46)
local SAKURA = {
	Color3.fromRGB(255, 186, 208), Color3.fromRGB(250, 164, 194), Color3.fromRGB(255, 206, 222),
	Color3.fromRGB(242, 146, 182),
}

-- The halves: red-orange for A, violet for B, on the spawn rings and the gate banners.
local SIDE = { Color3.fromRGB(255, 108, 60), Color3.fromRGB(150, 110, 255) }

local function darker(c: Color3, t: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), t)
end

local function vertical(at: Vector3): CFrame
	return CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
end

local function post(b: Kit.Builder, at: Vector3, height: number, diameter: number, colour: Color3, collide: boolean?)
	local opts = { shape = "Cylinder" }
	if collide == false then
		b:decor("Post", Vector3.new(height, diameter, diameter), vertical(at + Vector3.new(0, height / 2, 0)), colour,
			M.Wood, opts)
	else
		b:part("Post", Vector3.new(height, diameter, diameter), vertical(at + Vector3.new(0, height / 2, 0)), colour,
			M.Wood, opts)
	end
end

--- A tiled roof with its ridge along X: flared eaves, two slopes, a ridge and end tiles.
--- `at` is the eave line's centre.
local function roof(b: Kit.Builder, at: CFrame, w: number, d: number, h: number)
	local r = b:within(at)
	r:part("Eave", Vector3.new(w + 2.4, 0.6, d + 2.4), Vector3.new(0, 0.3, 0), WOOD_DARK, M.Wood)
	r:decor("Fascia", Vector3.new(w + 2.6, 0.35, d + 2.6), Vector3.new(0, 0.65, 0), TILE, M.Slate)
	for _, s in ipairs({ -1, 1 }) do
		r:part("Slope", Vector3.new(w + 2, h, (d + 2) / 2),
			CFrame.new(0, 0.8 + h / 2, s * (d + 2) / 4) * CFrame.Angles(0, s == 1 and math.pi or 0, 0),
			TILE, M.Slate, { shape = "Wedge" })
		-- Tile rows: thin ribs down the slope.
		for i = 1, 3 do
			local t = i / 4
			local y = 0.8 + h * (1 - t)
			local z = s * (d + 2) / 2 * t
			r:decor("Course", Vector3.new(w + 2.05, 0.18, 0.3), Vector3.new(0, y + 0.02, z), darker(TILE, 0.25), M.Slate)
		end
		-- Upswept corners: the flick that makes the roof read as a temple roof.
		for _, sx in ipairs({ -1, 1 }) do
			r:decor("Flick", Vector3.new(1.4, 1.2, 2.2),
				CFrame.new(sx * (w / 2 + 1.1), 0.9, s * (d / 2 + 1.1))
					* CFrame.Angles(0, s == 1 and 0 or math.pi, 0) * CFrame.Angles(math.rad(-10), 0, 0),
				TILE, M.Slate, { shape = "Wedge" })
		end
	end
	r:part("Ridge", Vector3.new(w + 2.6, 1, 1.2), Vector3.new(0, 0.8 + h + 0.3, 0), darker(TILE, 0.3), M.Slate)
	for _, sx in ipairs({ -1, 1 }) do
		r:decor("Onigawara", Vector3.new(0.8, 2, 1.6), Vector3.new(sx * (w / 2 + 1.4), 0.8 + h + 0.9, 0),
			darker(TILE, 0.35), M.Slate)
	end
end

--- A red paper lantern hanging from `top`.
local function chochin(b: Kit.Builder, top: Vector3, size: number, lit: boolean)
	b:decor("Cord", Vector3.new(0.08, 0.8, 0.08), top - Vector3.new(0, 0.4, 0), BLACK)
	local c = top - Vector3.new(0, 0.8 + size * 0.7, 0)
	b:decor("Lantern", Vector3.new(size * 1.4, size, size), vertical(c), Color3.fromRGB(214, 48, 40), M.SmoothPlastic,
		{ shape = "Cylinder" })
	b:decor("Inner", Vector3.new(size * 1.3, size * 0.9, size * 0.9), vertical(c), Color3.fromRGB(255, 120, 80), M.Neon,
		{ shape = "Cylinder", transparency = 0.55 })
	for _, dy in ipairs({ -1, 1 }) do
		b:decor("Ring", Vector3.new(0.2, size * 0.8, size * 0.8), vertical(c + Vector3.new(0, dy * size * 0.7, 0)), BLACK,
			M.SmoothPlastic, { shape = "Cylinder" })
	end
	if lit then
		b:light("Point", c, Color3.fromRGB(255, 150, 100), 1.1, 14)
	end
end

-- ------------------------------------------------------------------ props --

local function stoneLantern(b: Kit.Builder, withLight: boolean)
	b:part("Base", Vector3.new(0.7, 2.6, 2.6), vertical(Vector3.new(0, 0.35, 0)), STONE, M.Granite, { shape = "Cylinder" })
	b:part("Pillar", Vector3.new(2.8, 1, 1), vertical(Vector3.new(0, 2.1, 0)), STONE, M.Granite, { shape = "Cylinder" })
	b:part("Platform", Vector3.new(2.4, 0.6, 2.4), Vector3.new(0, 3.8, 0), STONE, M.Granite)
	b:part("Firebox", Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, 4.9, 0), STONE, M.Granite)
	for _, f in ipairs({ Vector3.new(0, 0, -0.81), Vector3.new(0, 0, 0.81) }) do
		b:neon("Window", Vector3.new(0.9, 0.9, 0.05), Vector3.new(0, 4.95, 0) + f, GLOW)
	end
	for _, f in ipairs({ Vector3.new(-0.81, 0, 0), Vector3.new(0.81, 0, 0) }) do
		b:neon("Window", Vector3.new(0.05, 0.6, 0.6), Vector3.new(0, 5, 0) + f, GLOW)
	end
	b:part("Kasa", Vector3.new(3.2, 0.4, 3.2), Vector3.new(0, 5.9, 0), STONE, M.Granite)
	b:decor("Kasa", Vector3.new(2.3, 0.4, 2.3), Vector3.new(0, 6.3, 0), STONE, M.Granite)
	b:decor("Kasa", Vector3.new(1.3, 0.4, 1.3), Vector3.new(0, 6.7, 0), STONE, M.Granite)
	b:decor("Hoju", Vector3.new(0.8, 0.8, 0.8), Vector3.new(0, 7.2, 0), STONE, M.Granite, { shape = "Ball" })
	b:decor("Moss", Vector3.new(3.24, 0.08, 3.24), Vector3.new(0, 6.12, 0), MOSS, M.Grass, { transparency = 0.3 })
	if withLight then
		b:light("Point", Vector3.new(0, 4.9, 0), GLOW, 1.2, 16)
	end
end

--- A cherry tree. `seed` varies the lean and the canopy so no two are twins of each other.
local function sakura(b: Kit.Builder, seed: number, collide: boolean)
	local rng = Random.new(seed)
	local lean = math.rad(rng:NextNumber(-10, 10))
	local turn = math.rad(rng:NextNumber(0, 360))
	local t = b:within(CFrame.Angles(0, turn, 0))
	local low = CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, lean)
	local trunk = t:part("Trunk", Vector3.new(5.6, 1.7, 1.7), low * CFrame.Angles(0, 0, math.rad(90)), BARK, M.Wood,
		{ shape = "Cylinder", collide = collide })
	trunk.Name = "Trunk"
	local top = low * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, -lean * 1.8)
	t:decor("Trunk", Vector3.new(4.4, 1.3, 1.3), top * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.rad(90)), BARK,
		M.Wood, { shape = "Cylinder" })
	local crown = (top * CFrame.new(0, 4.2, 0)).Position
	for i = 1, 3 do
		local a = i / 3 * math.pi * 2 + rng:NextNumber(-0.4, 0.4)
		local tip = crown + Vector3.new(math.cos(a) * 4, rng:NextNumber(1.5, 3), math.sin(a) * 4)
		local cf, len = Kit.Span(crown, tip)
		t:decor("Branch", Vector3.new(0.6, 0.6, len), cf, BARK, M.Wood)
	end
	local blobs = {
		{ Vector3.new(0, 3.2, 0), 8.5 }, { Vector3.new(3.6, 2.2, 1.2), 6.5 }, { Vector3.new(-3.4, 2.4, -1.4), 6.8 },
		{ Vector3.new(1, 2, -3.6), 6 }, { Vector3.new(-1.2, 1.8, 3.6), 6.2 }, { Vector3.new(0.5, 5.2, 0.4), 5.4 },
		{ Vector3.new(4.4, 0.2, -1.8), 4 }, { Vector3.new(-4.2, 0.3, 2.2), 3.8 },
	}
	for i, blob in ipairs(blobs) do
		local size = blob[2] * rng:NextNumber(0.92, 1.08)
		t:decor("Blossom", Vector3.new(size, size, size), crown + blob[1] - Vector3.new(0, size * 0.1, 0),
			SAKURA[(i + seed) % #SAKURA + 1], M.SmoothPlastic, { shape = "Ball", shadow = true })
	end
	-- Fallen petals: a soft pink disc on the ground under it.
	t:decor("Petals", Vector3.new(0.05, 13, 13), vertical(Vector3.new(0, 0.04, 0)), SAKURA[1], M.SmoothPlastic,
		{ shape = "Cylinder", transparency = 0.45 })
end

local function torii(b: Kit.Builder)
	for _, x in ipairs({ -6.5, 6.5 }) do
		post(b, Vector3.new(x, 1.2, 0), 13.4, 1.4, VERMILION)
		b:part("Kamaki", Vector3.new(1.2, 1.9, 1.9), vertical(Vector3.new(x, 0.6, 0)), BLACK, M.SmoothPlastic,
			{ shape = "Cylinder" })
	end
	b:decor("Nuki", Vector3.new(17.4, 0.9, 0.8), Vector3.new(0, 11.2, 0), VERMILION, M.Wood)
	b:decor("Shimaki", Vector3.new(19, 0.8, 1.4), Vector3.new(0, 14.1, 0), VERMILION, M.Wood)
	b:decor("Kasagi", Vector3.new(20.6, 1, 1.8), Vector3.new(0, 15, 0), BLACK, M.Wood)
	for _, sx in ipairs({ -1, 1 }) do
		b:decor("Tip", Vector3.new(1.8, 0.9, 1.8),
			CFrame.new(sx * 10.9, 15.2, 0) * CFrame.Angles(0, sx == 1 and math.rad(90) or math.rad(-90), 0)
				* CFrame.Angles(0, 0, 0),
			BLACK, M.Wood, { shape = "Wedge" })
	end
	b:decor("Gakuzuka", Vector3.new(0.8, 2.2, 0.8), Vector3.new(0, 12.7, 0), VERMILION, M.Wood)
	b:decor("Plaque", Vector3.new(2, 2.6, 0.3), Vector3.new(0, 12.7, -0.5), BLACK, M.Wood)
	b:sign("禅", CFrame.new(0, 12.7, -0.7), 1.6, 2.2, GOLD, { lit = true, glow = false, font = Enum.Font.Garamond,
		textColour = GOLD, brightness = 1.6 })
	b:sign("禅", CFrame.new(0, 12.7, -0.3) * CFrame.Angles(0, math.pi, 0), 1.6, 2.2, GOLD, { lit = true, glow = false,
		font = Enum.Font.Garamond, textColour = GOLD, brightness = 1.6 })
end

--- The gate house closing an end. Origin on the end line, facing +Z into the courtyard.
local function gateHouse(b: Kit.Builder, side: number)
	local accent = SIDE[side]
	local W = 36
	-- The house itself: plaster panels between red posts, closed doors in the middle.
	b:part("Body", Vector3.new(W, 16, 8), Vector3.new(0, 8, -5), PLASTER, M.Plaster)
	b:decor("Plinth", Vector3.new(W + 1, 1.2, 9), Vector3.new(0, 0.6, -4.8), STONE, M.Granite)
	for _, x in ipairs({ -17, -6, 6, 17 }) do
		post(b, Vector3.new(x, 1.2, -0.6), 14.8, 1.7, VERMILION)
	end
	for _, y in ipairs({ 11.6, 15.4 }) do
		b:decor("Beam", Vector3.new(W + 1, 0.9, 0.9), Vector3.new(0, y, -0.5), VERMILION, M.Wood)
	end
	b:decor("Brackets", Vector3.new(W + 2, 1.4, 4), Vector3.new(0, 16.6, -2.4), WOOD_DARK, M.Wood)
	for x = -16, 16, 2.4 do
		b:decor("Bracket", Vector3.new(0.9, 0.9, 1.2), Vector3.new(x, 16.8, -0.2), darker(VERMILION, 0.2), M.Wood)
	end
	-- The doors, with gold bands.
	b:decor("Doors", Vector3.new(11, 11, 0.4), Vector3.new(0, 6.7, -0.9), WOOD_DARK, M.WoodPlanks)
	b:decor("Split", Vector3.new(0.2, 11, 0.45), Vector3.new(0, 6.7, -0.85), BLACK)
	for _, y in ipairs({ 3, 10 }) do
		b:decor("Band", Vector3.new(11, 0.4, 0.45), Vector3.new(0, y, -0.8), GOLD, M.Metal)
	end
	-- Lattice windows in the side bays.
	for _, sx in ipairs({ -1, 1 }) do
		local cx = sx * 11.5
		b:decor("Window", Vector3.new(6, 5, 0.2), Vector3.new(cx, 7.5, -0.95), WOOD_DARK, M.Wood)
		for i = -2, 2 do
			b:decor("Lattice", Vector3.new(0.18, 5, 0.12), Vector3.new(cx + i * 1.2, 7.5, -0.8), WOOD, M.Wood)
		end
		for i = -1, 1 do
			b:decor("Lattice", Vector3.new(6, 0.18, 0.12), Vector3.new(cx, 7.5 + i * 1.6, -0.8), WOOD, M.Wood)
		end
		-- Banners in the side's colour, hung on the posts either side of the doors.
		b:decor("Banner", Vector3.new(1.6, 7, 0.1), Vector3.new(sx * 6, 7.2, 0.4), accent, M.Fabric)
		b:decor("BannerPole", Vector3.new(2.2, 0.15, 0.15), Vector3.new(sx * 6, 10.8, 0.45), BLACK)
	end
	-- The plaque between the beams.
	b:decor("Plaque", Vector3.new(6, 3, 0.3), Vector3.new(0, 13.5, -0.1), BLACK, M.Wood)
	b:sign("禅 ZEE 禅", CFrame.new(0, 13.5, 0.08) * CFrame.Angles(0, math.pi, 0), 5.4, 2.4, GOLD,
		{ lit = true, glow = false, font = Enum.Font.Garamond, textColour = GOLD, brightness = 1.8 })

	roof(b, CFrame.new(0, 17.3, -4.5), W + 2, 10, 7)

	-- The great lantern hanging in front of the doors.
	local LZ = 2.2
	b:decor("Cord", Vector3.new(0.2, 5.6, 0.2), Vector3.new(0, 13.2, LZ), BLACK)
	b:decor("Lantern", Vector3.new(6, 4.6, 4.6), vertical(Vector3.new(0, 7.4, LZ)), Color3.fromRGB(200, 38, 34),
		M.SmoothPlastic, { shape = "Cylinder" })
	b:decor("Inner", Vector3.new(5.8, 4.4, 4.4), vertical(Vector3.new(0, 7.4, LZ)), Color3.fromRGB(255, 110, 70), M.Neon,
		{ shape = "Cylinder", transparency = 0.6 })
	for _, dy in ipairs({ -3.1, 3.1 }) do
		b:decor("Ring", Vector3.new(0.6, 3.8, 3.8), vertical(Vector3.new(0, 7.4 + dy, LZ)), BLACK, M.SmoothPlastic,
			{ shape = "Cylinder" })
	end
	b:sign("禅", CFrame.new(0, 7.4, LZ + 2.35) * CFrame.Angles(0, math.pi, 0), 2.8, 3.4, BLACK, { lit = true,
		glow = false, font = Enum.Font.Garamond, textColour = Color3.fromRGB(24, 18, 18), brightness = 1 })
	b:light("Point", Vector3.new(0, 7.4, LZ + 1), Color3.fromRGB(255, 150, 100), 1.6, 22)

	-- Plastered walls from the gate out to the corners.
	for _, sx in ipairs({ -1, 1 }) do
		local len = Map.HalfWidth - W / 2 + 1
		local cx = sx * (W / 2 + len / 2)
		b:part("EndWall", Vector3.new(len, 9, 1.8), Vector3.new(cx, 4.5, -1.2), PLASTER, M.Plaster)
		b:decor("Footing", Vector3.new(len, 1.4, 2), Vector3.new(cx, 0.7, -1.2), STONE, M.Granite)
		for i = 1, 4 do
			b:decor("Line", Vector3.new(len, 0.15, 0.05), Vector3.new(cx, 5 + i * 0.8, -0.28), darker(PLASTER, 0.12))
		end
		roof(b, CFrame.new(cx, 9, -1.2), len - 2, 0.6, 1.1)
	end
end

--- The plastered temple wall along a long side (at +X as written), its inner face on the
--- boundary, with a tiled coping.
local function sideWall(b: Kit.Builder)
	local L = Map.HalfLength * 2 + 2
	local x = Map.HalfWidth + 0.9
	b:part("Wall", Vector3.new(1.8, 9, L), Vector3.new(x, 4.5, 0), PLASTER, M.Plaster)
	b:decor("Footing", Vector3.new(2, 1.4, L), Vector3.new(x, 0.7, 0), STONE, M.Granite)
	for i = 1, 4 do
		b:decor("Line", Vector3.new(0.05, 0.15, L), Vector3.new(x - 0.92, 5 + i * 0.8, 0), darker(PLASTER, 0.12))
	end
	roof(b:within(CFrame.new(x, 9, 0) * CFrame.Angles(0, math.rad(90), 0)), CFrame.new(), L - 2, 0.6, 1.1)
end

local function rock(b: Kit.Builder, seed: number)
	local rng = Random.new(seed)
	local pieces = {
		{ Vector3.new(0, 1.9, 0), Vector3.new(6, 4.4, 5) },
		{ Vector3.new(2.4, 1.2, 1.8), Vector3.new(4, 2.8, 3.6) },
		{ Vector3.new(-2.6, 0.9, -1.2), Vector3.new(3.6, 2.2, 3.2) },
		{ Vector3.new(0.6, 0.5, -2.8), Vector3.new(2.4, 1.4, 2.2) },
	}
	for _, p in ipairs(pieces) do
		local cf = CFrame.new(p[1]) * CFrame.Angles(rng:NextNumber(-0.25, 0.25), rng:NextNumber(0, 6.28),
			rng:NextNumber(-0.25, 0.25))
		b:part("Rock", p[2], cf, STONE:Lerp(Color3.fromRGB(120, 124, 120), rng:NextNumber()), M.Slate)
		b:decor("Moss", Vector3.new(p[2].X * 0.6, 0.12, p[2].Z * 0.55), cf * CFrame.new(-p[2].X * 0.1, p[2].Y / 2, 0),
			MOSS:Lerp(Color3.fromRGB(150, 170, 110), 0.3), M.Grass)
	end
end

--- The kagura stage: a raised wooden floor under its own roof, steps down toward +X.
local function stage(b: Kit.Builder)
	local W, D, H = 12, 18, 2.2
	b:part("Stage", Vector3.new(W, H, D), Vector3.new(0, H / 2, 0), WOOD, M.WoodPlanks)
	for x = -W / 2 + 1.2, W / 2 - 1.2, 1.2 do
		b:decor("Board", Vector3.new(0.08, 0.04, D), Vector3.new(x, H + 0.02, 0), darker(WOOD, 0.25), M.Wood)
	end
	-- The skirt's top sits a hair under the deck. Flush, the two tops were one plane in two
	-- colours and the whole stage flickered between wood and red as the camera moved.
	b:decor("Skirt", Vector3.new(W + 0.2, 0.5, D + 0.2), Vector3.new(0, H - 0.3, 0), VERMILION, M.Wood)
	for _, x in ipairs({ -W / 2 + 0.4, W / 2 - 0.4 }) do
		for _, z in ipairs({ -D / 2 + 0.4, 0, D / 2 - 0.4 }) do
			post(b, Vector3.new(x, H, z), 9, 0.8, VERMILION)
		end
		b:decor("Beam", Vector3.new(0.7, 0.7, D), Vector3.new(x, H + 8.6, 0), VERMILION, M.Wood)
	end
	-- Rail along the back.
	b:part("Rail", Vector3.new(0.3, 0.3, D - 1), Vector3.new(-W / 2 + 0.4, H + 3, 0), VERMILION, M.Wood, { query = false })
	for z = -D / 2 + 1.5, D / 2 - 1.5, 3 do
		b:decor("Baluster", Vector3.new(0.25, 3, 0.25), Vector3.new(-W / 2 + 0.4, H + 1.5, z), VERMILION, M.Wood)
	end
	roof(b:within(CFrame.new(0, H + 9, 0) * CFrame.Angles(0, math.rad(90), 0)), CFrame.new(), D, W, 3.6)
	-- Steps down the +X side, and the ramp you actually walk on.
	b:part("Ramp", Vector3.new(4, H, 4.5), CFrame.new(W / 2 + 2.25, H / 2, 0) * CFrame.Angles(0, math.rad(-90), 0),
		WOOD, nil, { shape = "Wedge", transparency = 1, shadow = false })
	for i = 1, 3 do
		b:decor("Step", Vector3.new(1.5, H * i / 3, 6), Vector3.new(W / 2 + 4.5 - i * 1.5 + 0.75, H * i / 6, 0),
			WOOD, M.WoodPlanks)
	end
	-- A taiko drum on its stand at the back, lanterns along the front eave.
	b:decor("Stand", Vector3.new(1.2, 2.4, 3.4), Vector3.new(-3, H + 1.2, 0), WOOD_DARK, M.Wood)
	b:part("Taiko", Vector3.new(2.4, 3.6, 3.6), CFrame.new(-3, H + 3.4, 0), Color3.fromRGB(120, 60, 36), M.Wood,
		{ shape = "Cylinder" })
	for _, s in ipairs({ -1, 1 }) do
		b:decor("Skin", Vector3.new(0.1, 3.3, 3.3), CFrame.new(-3 + s * 1.22, H + 3.4, 0), Color3.fromRGB(230, 214, 186),
			M.Fabric, { shape = "Cylinder" })
	end
	for _, z in ipairs({ -6, 0, 6 }) do
		chochin(b, Vector3.new(W / 2 + 0.2, H + 8.4, z), 1.2, z == 0)
	end
end

local function bellTower(b: Kit.Builder)
	b:part("Plinth", Vector3.new(9, 2, 9), Vector3.new(0, 1, 0), STONE, M.Granite)
	b:decor("PlinthCap", Vector3.new(9.3, 0.3, 9.3), Vector3.new(0, 2.05, 0), darker(STONE, 0.1), M.Granite)
	for _, x in ipairs({ -3.5, 3.5 }) do
		for _, z in ipairs({ -3.5, 3.5 }) do
			post(b, Vector3.new(x, 2, z), 9.4, 0.9, VERMILION)
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		b:decor("Tie", Vector3.new(7.8, 0.6, 0.6), Vector3.new(0, 10.6, s * 3.5), VERMILION, M.Wood)
		b:decor("Tie", Vector3.new(0.6, 0.6, 7.8), Vector3.new(s * 3.5, 10.6, 0), VERMILION, M.Wood)
		b:decor("Tie", Vector3.new(7.8, 0.4, 0.4), Vector3.new(0, 4.2, s * 3.5), VERMILION, M.Wood)
	end
	b:decor("Yoke", Vector3.new(0.5, 0.5, 7.8), Vector3.new(0, 11, 0), WOOD_DARK, M.Wood)
	roof(b, CFrame.new(0, 11.4, 0), 9, 9, 3.8)
	-- The bell and the log that strikes it.
	b:decor("Hanger", Vector3.new(0.4, 1, 0.4), Vector3.new(0, 10.3, 0), BRONZE, M.Metal)
	b:part("Bell", Vector3.new(4.2, 3.4, 3.4), vertical(Vector3.new(0, 7.6, 0)), BRONZE, M.Metal, { shape = "Cylinder" })
	b:decor("Crown", Vector3.new(0.8, 3, 3), vertical(Vector3.new(0, 9.9, 0)), BRONZE, M.Metal, { shape = "Cylinder" })
	b:decor("Knob", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 10.4, 0), BRONZE, M.Metal, { shape = "Ball" })
	b:decor("Lip", Vector3.new(0.3, 3.6, 3.6), vertical(Vector3.new(0, 5.6, 0)), darker(BRONZE, 0.2), M.Metal,
		{ shape = "Cylinder" })
	for _, y in ipairs({ 6.6, 8.6 }) do
		b:decor("Band", Vector3.new(0.2, 3.46, 3.46), vertical(Vector3.new(0, y, 0)), darker(BRONZE, 0.25), M.Metal,
			{ shape = "Cylinder" })
	end
	b:decor("Log", Vector3.new(3.4, 0.7, 0.7), CFrame.new(3.4, 7, 0), WOOD, M.Wood, { shape = "Cylinder" })
	for _, x in ipairs({ 2.4, 4.4 }) do
		b:decor("Rope", Vector3.new(0.1, 3.8, 0.1), Vector3.new(x, 9, 0), Color3.fromRGB(214, 196, 150), M.Fabric)
	end
end

--- The purification fountain: a stone basin under a little roof.
local function chozuya(b: Kit.Builder)
	b:decor("Pad", Vector3.new(7.6, 0.3, 7.6), Vector3.new(0, 0.15, 0), FLAG, M.Slate)
	for _, x in ipairs({ -2.9, 2.9 }) do
		for _, z in ipairs({ -2.9, 2.9 }) do
			post(b, Vector3.new(x, 0.3, z), 7.2, 0.6, VERMILION)
		end
	end
	roof(b, CFrame.new(0, 7.5, 0), 6.4, 6.4, 2.6)
	b:part("Basin", Vector3.new(4.2, 1.8, 2.4), Vector3.new(0, 1.2, 0), STONE, M.Granite)
	b:decor("Water", Vector3.new(3.6, 0.1, 1.8), Vector3.new(0, 2.12, 0), WATER, M.Glass, { transparency = 0.2 })
	b:decor("Spout", Vector3.new(3, 0.3, 0.3), CFrame.new(-1.2, 3, 0) * CFrame.Angles(0, 0, math.rad(-20)),
		Color3.fromRGB(116, 150, 72), M.Wood, { shape = "Cylinder" })
	-- The bamboo post the spout is lashed to.
	b:decor("SpoutPost", Vector3.new(0.3, 3.4, 0.3), Vector3.new(-2.7, 2, 0), Color3.fromRGB(96, 128, 60), M.Wood)
	for i, x in ipairs({ -0.6, 0.4, 1.4 }) do
		b:decor("Dipper", Vector3.new(0.5, 0.5, 0.5), vertical(Vector3.new(x, 2.4, 0.9)), WOOD, M.Wood,
			{ shape = "Cylinder" })
		b:decor("Handle", Vector3.new(0.08, 0.08, 1.6), CFrame.new(x, 2.3, 1.7) * CFrame.Angles(math.rad(15 * i), 0, 0),
			WOOD, M.Wood)
	end
end

--- A rack of wooden prayer boards.
local function ema(b: Kit.Builder)
	for _, x in ipairs({ -2.6, 2.6 }) do
		b:part("Post", Vector3.new(0.4, 5, 0.4), Vector3.new(x, 2.5, 0), WOOD_DARK, M.Wood)
	end
	b:decor("Top", Vector3.new(6.4, 0.3, 1.4), Vector3.new(0, 5.2, 0), TILE, M.Slate)
	for row, y in ipairs({ 4.2, 3 }) do
		b:decor("Bar", Vector3.new(5.6, 0.12, 0.12), Vector3.new(0, y, 0), WOOD_DARK, M.Wood)
		for i = -3, 3 do
			local x = i * 0.74 + (row == 2 and 0.37 or 0)
			if math.abs(x) < 2.4 then
				b:decor("Board", Vector3.new(0.62, 0.48, 0.06),
					CFrame.new(x, y - 0.35, 0.05) * CFrame.Angles(math.rad(6), 0, math.rad(((i * 7) % 5) - 2)),
					Color3.fromRGB(214, 176, 126), M.Wood)
			end
		end
	end
end

--- The koi pond and its bridge. Symmetric by itself; built once, from the root.
local function pond(root: Kit.Builder, PW: number, PD: number)
	root:part("PondBed", Vector3.new(PW, 1, PD), Vector3.new(0, -1.7, 0), Color3.fromRGB(46, 62, 64), M.Slate)
	root:decor("Water", Vector3.new(PW, 0.2, PD), Vector3.new(0, -0.35, 0), WATER, M.SmoothPlastic,
		{ transparency = 0.3, reflectance = 0.12 })
	-- Kerb stones round the edge.
	for _, s in ipairs({ -1, 1 }) do
		root:part("Kerb", Vector3.new(PW + 2, 0.4, 1), Vector3.new(0, 0.2, s * (PD / 2 + 0.5)), FLAG, M.Granite)
		root:part("Kerb", Vector3.new(1, 0.4, PD), Vector3.new(s * (PW / 2 + 0.5), 0.2, 0), FLAG, M.Granite)
	end
	-- Koi and lily pads.
	local koi = {
		{ Vector3.new(-9, -0.6, 3), 20, Color3.fromRGB(255, 120, 40) }, { Vector3.new(-6, -0.65, -4), 150, Color3.fromRGB(250, 246, 240) },
		{ Vector3.new(7, -0.6, -3), 200, Color3.fromRGB(255, 120, 40) }, { Vector3.new(10, -0.65, 4), 320, Color3.fromRGB(240, 70, 50) },
		{ Vector3.new(4, -0.62, 5), 80, Color3.fromRGB(250, 246, 240) }, { Vector3.new(-4, -0.6, -6), 260, Color3.fromRGB(255, 160, 60) },
	}
	for _, k in ipairs(koi) do
		root:decor("Koi", Vector3.new(1.8, 0.5, 0.5), CFrame.new(k[1]) * CFrame.Angles(0, math.rad(k[2]), 0), k[3],
			M.SmoothPlastic, { shape = "Cylinder" })
		root:decor("Tail", Vector3.new(0.5, 0.1, 0.7), CFrame.new(k[1]) * CFrame.Angles(0, math.rad(k[2]), 0)
			* CFrame.new(-1.1, 0, 0), k[3], M.SmoothPlastic)
	end
	for _, p in ipairs({ Vector3.new(-11, -0.22, -5), Vector3.new(11, -0.22, 5), Vector3.new(-7.5, -0.22, 5.5),
		Vector3.new(7.5, -0.22, -5.5) }) do
		root:decor("Pad", Vector3.new(0.06, 2.2, 2.2), vertical(p), Color3.fromRGB(70, 130, 60), M.SmoothPlastic,
			{ shape = "Cylinder" })
		root:decor("Flower", Vector3.new(0.5, 0.5, 0.5), p + Vector3.new(0.4, 0.2, 0.3), Color3.fromRGB(255, 200, 220),
			M.SmoothPlastic, { shape = "Ball" })
	end
	-- Stepping stones across either side of the bridge.
	for _, x in ipairs({ -9, 9 }) do
		for _, z in ipairs({ -5.4, -1.8, 1.8, 5.4 }) do
			root:part("SteppingStone", Vector3.new(1.3, 2.4, 2.4), vertical(Vector3.new(x + (z > 0 and 0.4 or -0.4), -0.6, z)),
				FLAG, M.Slate, { shape = "Cylinder" })
		end
	end

	-- The bridge: an arch of plank segments along Z, red rails, gold caps on the end posts.
	local half, rise, width = PD / 2 + 3, 2, 5
	local segments = 8
	local function heightAt(z: number): number
		return rise * math.cos(z / half * math.pi / 2)
	end
	for i = 0, segments - 1 do
		local z0 = -half + i * (2 * half / segments)
		local z1 = z0 + 2 * half / segments
		local a = Vector3.new(0, heightAt(z0), z0)
		local c = Vector3.new(0, heightAt(z1), z1)
		local cf, len = Kit.Span(a, c)
		root:part("Deck", Vector3.new(width, 0.5, len + 0.1), cf * CFrame.new(0, 0.05, 0), WOOD, M.WoodPlanks)
		root:decor("Beam", Vector3.new(width + 0.3, 0.5, len + 0.1), cf * CFrame.new(0, -0.4, 0), VERMILION, M.Wood)
		for _, sx in ipairs({ -1, 1 }) do
			local railA = a + Vector3.new(sx * (width / 2 - 0.15), 2.6, 0)
			local railC = c + Vector3.new(sx * (width / 2 - 0.15), 2.6, 0)
			local rcf, rlen = Kit.Span(railA, railC)
			root:part("Rail", Vector3.new(0.35, 0.35, rlen + 0.1), rcf, VERMILION, M.Wood, { query = false })
			root:decor("Baluster", Vector3.new(0.4, 2.6, 0.4), a + Vector3.new(sx * (width / 2 - 0.15), 1.3, 0),
				VERMILION, M.Wood)
		end
	end
	-- Under the arch the pond would be a trap; fill it with the bridge's stone footing.
	root:part("Footing", Vector3.new(width, 1.6, PD + 0.2), Vector3.new(0, -0.9, 0), STONE, M.Granite)
	for _, sz in ipairs({ -1, 1 }) do
		for _, sx in ipairs({ -1, 1 }) do
			local base = Vector3.new(sx * (width / 2 - 0.15), 0, sz * half)
			root:decor("EndPost", Vector3.new(0.6, 3.2, 0.6), base + Vector3.new(0, 1.6, 0), VERMILION, M.Wood)
			root:decor("Giboshi", Vector3.new(0.8, 0.8, 0.8), base + Vector3.new(0, 3.5, 0), GOLD, M.Metal,
				{ shape = "Ball" })
		end
	end
end

--- A five-storey pagoda, far outside the walls.
local function pagoda(b: Kit.Builder)
	b:decor("Base", Vector3.new(20, 3, 20), Vector3.new(0, 1.5, 0), STONE, M.Granite)
	local y = 3
	for i = 0, 4 do
		local s = 13 - i * 1.8
		local h = 6.4 - i * 0.3
		b:decor("Storey", Vector3.new(s, h, s), Vector3.new(0, y + h / 2, 0), VERMILION, M.Wood)
		for _, f in ipairs({ -1, 1 }) do
			b:decor("Panel", Vector3.new(s * 0.5, h * 0.62, 0.12), Vector3.new(0, y + h * 0.48, f * (s / 2 + 0.05)),
				PLASTER, M.Plaster)
			b:decor("Panel", Vector3.new(0.12, h * 0.62, s * 0.5), Vector3.new(f * (s / 2 + 0.05), y + h * 0.48, 0),
				PLASTER, M.Plaster)
		end
		y += h
		local e = s + 8 - i * 0.6
		b:decor("Eave", Vector3.new(e, 0.8, e), Vector3.new(0, y + 0.4, 0), WOOD_DARK, M.Wood)
		b:decor("Tiles", Vector3.new(e - 1.6, 0.8, e - 1.6), Vector3.new(0, y + 1.2, 0), TILE, M.Slate)
		b:decor("Tiles", Vector3.new(e - 4, 0.8, e - 4), Vector3.new(0, y + 2, 0), TILE, M.Slate)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				b:decor("Flick", Vector3.new(1.4, 1, 2.6),
					CFrame.new(sx * e / 2, y + 0.9, sz * e / 2) * CFrame.Angles(0, math.atan2(sx, sz), 0)
						* CFrame.Angles(math.rad(-14), 0, 0),
					TILE, M.Slate, { shape = "Wedge" })
				b:neon("Bell", Vector3.new(0.5, 0.7, 0.5), Vector3.new(sx * (e / 2 - 0.6), y - 0.3, sz * (e / 2 - 0.6)), GLOW)
			end
		end
		y += 2.4
	end
	-- The spire: a mast with nine rings and a jewel on top.
	b:decor("Spire", Vector3.new(14, 0.6, 0.6), vertical(Vector3.new(0, y + 7, 0)), BRONZE, M.Metal, { shape = "Cylinder" })
	for i = 1, 9 do
		b:decor("Ring", Vector3.new(0.3, 2.2 - i * 0.12, 2.2 - i * 0.12), vertical(Vector3.new(0, y + 1.5 + i * 1.1, 0)),
			GOLD, M.Metal, { shape = "Cylinder" })
	end
	b:decor("Jewel", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, y + 14.6, 0), GOLD, M.Metal, { shape = "Ball" })
end

-- ------------------------------------------------------------------- build --

function Map.Build(parent: Instance, centre: Vector3)
	local root = Kit.new(parent, CFrame.new(centre))
	local HW, HL = Map.HalfWidth, Map.HalfLength
	local PW, PD = 28, 16      -- the pond

	Kit.Bounds(root, HW, HL, Map.Height)

	-- The courtyard floor, leaving a hole for the pond.
	for _, s in ipairs({ -1, 1 }) do
		root:part("Paving", Vector3.new(HW * 2 + 2, 2, HL - PD / 2 + 2), Vector3.new(0, -1, s * (PD / 2 + (HL + 2 - PD / 2) / 2)),
			PAVING, M.Slate)
		root:part("Paving", Vector3.new(HW + 1 - PW / 2, 2, PD), Vector3.new(s * (PW / 2 + (HW + 1 - PW / 2) / 2), -1, 0),
			PAVING, M.Slate)
	end
	-- Beyond the walls: moss and grass, so the view over them is never a void.
	root:decor("Grounds", Vector3.new(800, 1, 800), Vector3.new(0, -2.2, 0), Color3.fromRGB(88, 116, 70), M.Grass)

	-- The stone path down the middle, in big flags.
	for _, s in ipairs({ -1, 1 }) do
		for z = PD / 2 + 3 + 2.2, HL - 2, 4.4 do
			root:decor("Flag", Vector3.new(6.6, 0.12, 4.2), Vector3.new(0, 0.06, s * z), FLAG, M.Slate)
		end
	end

	-- Gravel beds down the sides, raked in long lines.
	for _, sx in ipairs({ -1, 1 }) do
		local x0, x1 = 20, HW
		local cx = sx * (x0 + x1) / 2
		root:decor("Gravel", Vector3.new(x1 - x0, 0.1, HL * 2 - 4), Vector3.new(cx, 0.05, 0), GRAVEL, M.Pebble)
		root:decor("GravelEdge", Vector3.new(0.5, 0.2, HL * 2 - 4), Vector3.new(sx * x0, 0.1, 0), FLAG, M.Slate)
		for i = 1, 11 do
			root:decor("Rake", Vector3.new(0.18, 0.04, HL * 2 - 6), Vector3.new(sx * (x0 + i * (x1 - x0) / 12), 0.11, 0),
				darker(GRAVEL, 0.12), M.Pebble)
		end
	end

	pond(root, PW, PD)

	Kit.Both(root, function(b, side)
		local accent = SIDE[side]

		gateHouse(b:within(CFrame.new(0, 0, -HL)), side)
		sideWall(b)
		Kit.SpawnPad(b, Vector3.new(0, 0.12, -57), accent)
		torii(b:within(CFrame.new(0, 0, -47)))

		-- Lanterns lining the path.
		for _, z in ipairs({ -38, -24 }) do
			for _, x in ipairs({ -6.5, 6.5 }) do
				stoneLantern(b:within(CFrame.new(x, 0, z)), x < 0)
			end
		end

		chozuya(b:within(CFrame.new(-19, 0, -47)))
		ema(b:within(CFrame.new(18, 0, -51)))

		stage(b:within(CFrame.new(-32, 0, -24)))
		bellTower(b:within(CFrame.new(31, 0, -34)))
		-- A length of temple wall across the lane from the stage.
		local wall = b:within(CFrame.new(31, 0, -12))
		wall:part("Wall", Vector3.new(1.8, 6.4, 14), Vector3.new(0, 3.2, 0), PLASTER, M.Plaster)
		wall:decor("Footing", Vector3.new(2, 1.2, 14), Vector3.new(0, 0.6, 0), STONE, M.Granite)
		roof(wall:within(CFrame.new(0, 6.4, 0) * CFrame.Angles(0, math.rad(90), 0)), CFrame.new(), 13, 0.6, 1.1)

		rock(b:within(CFrame.new(17.5, 0, -7)), 11 + side)
		rock(b:within(CFrame.new(-17.5, 0, -8) * CFrame.Angles(0, math.rad(140), 0)), 21 + side)

		sakura(b:within(CFrame.new(-38, 0, -46)), 3, true)
		sakura(b:within(CFrame.new(38, 0, -52)), 5, true)
		sakura(b:within(CFrame.new(22, 0, -24)), 7, true)
		sakura(b:within(CFrame.new(-24, 0, -2)), 9, true)

		-- Outside the walls: a row of trees over the side wall, and the pagoda beyond.
		for i, z in ipairs({ -54, -32, -10, 12, 34, 56 }) do
			sakura(b:within(CFrame.new(HW + 9, 0, z)), 30 + i, false)
		end
		pagoda(b:within(CFrame.new(HW + 44, -2, -30)))
	end)

	-- Hills all round, and one tall peak off to the side.
	local hills = root:folder("Hills")
	for i = 0, 17 do
		local a = i / 18 * math.pi * 2
		local r = 420 + (i % 3) * 60
		local size = 180 + ((i * 53) % 5) * 30
		hills:decor("Hill", Vector3.new(size, size, size), Vector3.new(math.cos(a) * r, -size * 0.36, math.sin(a) * r),
			Color3.fromRGB(96 + (i % 3) * 8, 88 + (i % 2) * 10, 128), M.SmoothPlastic, { shape = "Ball" })
	end
	for i, d in ipairs({ 300, 230, 160, 100, 50 }) do
		local colour = i >= 4 and Color3.fromRGB(246, 242, 250) or Color3.fromRGB(110, 100, 146)
		hills:decor("Peak", Vector3.new(34, d, d), vertical(Vector3.new(520, -20 + (i - 1) * 34, -60)), colour,
			M.SmoothPlastic, { shape = "Cylinder" })
	end
end

return Map
