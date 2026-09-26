--!strict
-- ROOFTOPS: a tar roof high over the city on a clear afternoon.
--
-- The play space is one building's roof, fenced by its parapet. Each spawn comes out of the
-- stair hut at its end. From there: two AC condensers shield the door; a water tower on
-- stilts stands over one lane with a duct run beneath it; a raised HVAC deck with stairs
-- gives the other lane its high ground; a chimney beside the centre and the ridge skylight
-- in the middle break the long sightline. The other half is the same, turned round.
--
-- Around it, the neighbourhood: lower roofs with their own tanks and a billboard to either
-- side, a painted wall, streets far below and a skyline beyond.

local Kit = require(script.Parent.Kit)

local Map = {}

Map.Id = "Rooftops"
Map.Name = "ROOFTOPS"
Map.Tagline = "Tar roof over the city"
Map.HalfWidth = 44
Map.HalfLength = 64
Map.Height = 40
Map.Spawns = { Vector3.new(0, 3, -51), Vector3.new(0, 3, 51) }
Map.Mood = "day"
Map.Exposure = 1.0

-- Clear afternoon: a high sun, crisp shadows, a light blue haze over the skyline.
Map.Look = {
	Lighting = {
		ClockTime = 14.3,
		Brightness = 3.1,
		Ambient = Color3.fromRGB(118, 116, 122),
		OutdoorAmbient = Color3.fromRGB(150, 150, 160),
		ColorShift_Top = Color3.fromRGB(255, 238, 212),
		ExposureCompensation = 0,
		EnvironmentDiffuseScale = 0.85,
		EnvironmentSpecularScale = 0.6,
	},
	Atmosphere = {
		Density = 0.3,
		Offset = 0.12,
		Color = Color3.fromRGB(198, 214, 236),
		Decay = Color3.fromRGB(116, 148, 196),
		Glare = 0.25,
		Haze = 1.7,
	},
	Grade = {
		Brightness = 0.02,
		Contrast = 0.12,
		Saturation = 0.2,
		TintColor = Color3.fromRGB(255, 250, 244),
	},
	Bloom = { Intensity = 0.5, Size = 24, Threshold = 1.8 },
	SunRays = { Intensity = 0.06 },
	Clouds = { Cover = 0 },
}

local M = Enum.Material

local ROOF = Color3.fromRGB(84, 86, 92)
local PAVER = Color3.fromRGB(170, 166, 158)
local BRICK = Color3.fromRGB(152, 76, 58)
local BRICK_DARK = Color3.fromRGB(116, 56, 44)
local COPING = Color3.fromRGB(198, 194, 186)
local GALV = Color3.fromRGB(172, 178, 184)
local STEEL = Color3.fromRGB(62, 64, 70)
local AC_WHITE = Color3.fromRGB(216, 218, 214)
local TANK_WOOD = Color3.fromRGB(150, 104, 66)
local GLASS = Color3.fromRGB(96, 126, 150)
local WOOD = Color3.fromRGB(168, 120, 78)
local LEAF = Color3.fromRGB(76, 140, 70)

local SIDE = { Color3.fromRGB(242, 72, 72), Color3.fromRGB(38, 192, 172) }

local function darker(c: Color3, t: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), t)
end

local function vertical(at: Vector3): CFrame
	return CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
end

--- Spray-painted lettering: bright fill, dark outline, lit by the scene like paint.
local function graffiti(b: Kit.Builder, text: string, at: CFrame, w: number, h: number, colour: Color3)
	b:sign(text, at, w, h, colour, { lit = true, brightness = 1.2, font = Enum.Font.Bangers, textColour = colour,
		glow = Color3.fromRGB(20, 18, 24), stroke = 4 })
end

-- ------------------------------------------------------------------ props --

--- The stair hut at an end of the roof. Origin on the end parapet's inner face; the door
--- looks +Z, down the roof.
local function bulkhead(b: Kit.Builder, side: number)
	local accent = SIDE[side]
	b:part("Hut", Vector3.new(16, 11, 7), Vector3.new(0, 5.5, 3.5), BRICK, M.Brick)
	b:decor("Soldier", Vector3.new(16.1, 0.7, 7.1), Vector3.new(0, 10.1, 3.5), BRICK_DARK, M.Brick)
	b:part("Coping", Vector3.new(16.8, 0.5, 7.8), Vector3.new(0, 11.25, 3.5), COPING, M.Concrete)

	-- The door, its frame, a canopy and a lamp over it.
	b:decor("Frame", Vector3.new(4.6, 7.8, 0.3), Vector3.new(0, 3.9, 7.1), STEEL, M.Metal)
	b:decor("Door", Vector3.new(3.8, 7.1, 0.2), Vector3.new(0, 3.55, 7.2), Color3.fromRGB(70, 96, 120), M.Metal)
	b:decor("PushBar", Vector3.new(2.8, 0.25, 0.25), Vector3.new(0, 3.4, 7.4), GALV, M.Metal)
	b:decor("Canopy", Vector3.new(6.4, 0.3, 2.2), Vector3.new(0, 8.3, 8.1), STEEL, M.Metal)
	b:decor("Lamp", Vector3.new(1.2, 0.7, 0.7), Vector3.new(0, 9.2, 7.35), STEEL, M.Metal)
	b:neon("LampGlow", Vector3.new(1, 0.1, 0.5), Vector3.new(0, 8.82, 7.4), Color3.fromRGB(255, 226, 170))
	b:light("Spot", Kit.Look(Vector3.new(0, 8.7, 7.6), Vector3.new(0, 0, 14)), Color3.fromRGB(255, 226, 180), 1.2, 22,
		{ Angle = 100 })
	b:decor("Plate", Vector3.new(4.6, 1, 0.12), Vector3.new(0, 10.1, 7.1), Color3.fromRGB(236, 236, 232))
	b:sign("ROOF ACCESS", CFrame.new(0, 10.1, 7.2) * CFrame.Angles(0, math.pi, 0), 4.2, 0.8, Color3.fromRGB(30, 30, 34),
		{ lit = true, glow = false, font = Enum.Font.GothamBlack, textColour = Color3.fromRGB(34, 34, 40), brightness = 1 })

	-- Paint either side of the door.
	graffiti(b, "ZEE", CFrame.new(-5.3, 4.6, 7.06) * CFrame.Angles(0, math.pi, 0), 5, 3.6, accent)
	graffiti(b, "1V1", CFrame.new(5.3, 5.2, 7.06) * CFrame.Angles(0, math.pi, math.rad(-6)), 4.4, 2.8,
		Color3.fromRGB(255, 214, 60))

	-- On its roof: a small condenser, vent stacks, a dish and an aerial.
	b:decor("Unit", Vector3.new(3.2, 2, 3), Vector3.new(4.2, 12.5, 3), AC_WHITE, M.Metal)
	b:decor("Fan", Vector3.new(0.2, 2.4, 2.4), vertical(Vector3.new(4.2, 13.55, 3)), STEEL, M.Metal, { shape = "Cylinder" })
	for _, x in ipairs({ -1.5, 0.2 }) do
		b:decor("Vent", Vector3.new(2.6, 0.6, 0.6), vertical(Vector3.new(x, 12.8, 1.4)), GALV, M.Metal, { shape = "Cylinder" })
		b:decor("VentCap", Vector3.new(0.3, 1, 1), vertical(Vector3.new(x, 14.2, 1.4)), GALV, M.Metal, { shape = "Cylinder" })
	end
	b:decor("DishArm", Vector3.new(0.3, 1.6, 0.3), Vector3.new(-4.6, 12.3, 4.2), STEEL, M.Metal)
	b:decor("Dish", Vector3.new(0.3, 3, 3), CFrame.new(-4.6, 13.6, 4.4) * CFrame.Angles(0, math.rad(90), math.rad(25)),
		Color3.fromRGB(230, 230, 226), M.SmoothPlastic, { shape = "Cylinder" })
	b:decor("Aerial", Vector3.new(0.2, 9.8, 0.2), Vector3.new(-6.6, 16.2, 1.2), STEEL, M.Metal)
	for i, w in ipairs({ 3.6, 2.8, 2 }) do
		b:decor("AerialBar", Vector3.new(w, 0.15, 0.15), Vector3.new(-6.6, 17 + i * 1.2, 1.2), STEEL, M.Metal)
	end
end

--- An AC condenser: louvred box, fan on top, on two rails. Long side along X.
local function condenser(b: Kit.Builder)
	b:part("Rail", Vector3.new(7.4, 0.5, 0.6), Vector3.new(0, 0.25, -1.6), STEEL, M.Metal)
	b:part("Rail", Vector3.new(7.4, 0.5, 0.6), Vector3.new(0, 0.25, 1.6), STEEL, M.Metal)
	b:part("Body", Vector3.new(7, 3.6, 4.6), Vector3.new(0, 2.3, 0), AC_WHITE, M.Metal)
	b:decor("Top", Vector3.new(7.1, 0.3, 4.7), Vector3.new(0, 4.25, 0), darker(AC_WHITE, 0.1), M.Metal)
	for _, sz in ipairs({ -1, 1 }) do
		for i = 0, 5 do
			b:decor("Louvre", Vector3.new(6, 0.14, 0.12), Vector3.new(0, 1.1 + i * 0.48, sz * 2.33),
				darker(AC_WHITE, 0.3), M.Metal)
		end
	end
	for _, x in ipairs({ -1.8, 1.8 }) do
		b:decor("Fan", Vector3.new(0.3, 3, 3), vertical(Vector3.new(x, 4.45, 0)), Color3.fromRGB(40, 42, 46), M.Metal,
			{ shape = "Cylinder" })
		b:decor("Grille", Vector3.new(0.12, 3.2, 3.2), vertical(Vector3.new(x, 4.62, 0)), GALV, M.Metal,
			{ shape = "Cylinder", transparency = 0.55 })
		b:decor("Hub", Vector3.new(0.2, 0.7, 0.7), vertical(Vector3.new(x, 4.72, 0)), GALV, M.Metal, { shape = "Cylinder" })
	end
	b:decor("Badge", Vector3.new(1.4, 0.6, 0.1), Vector3.new(-2.6, 3.4, -2.33), Color3.fromRGB(40, 110, 200))
	-- Refrigerant lines dropping into the roof.
	for _, z in ipairs({ -0.5, 0.4 }) do
		b:decor("Line", Vector3.new(0.3, 0.3, 1.6), Vector3.new(3.8, 1.4, z), Color3.fromRGB(40, 40, 42), M.Rubber)
		b:decor("Line", Vector3.new(0.3, 1.2, 0.3), Vector3.new(4.5, 0.8, z), Color3.fromRGB(40, 40, 42), M.Rubber)
	end
end

--- A timber water tank on a steel stand, the rooftop landmark.
local function waterTower(b: Kit.Builder)
	local legY = 16
	for _, x in ipairs({ -3.6, 3.6 }) do
		for _, z in ipairs({ -3.6, 3.6 }) do
			b:part("Leg", Vector3.new(0.8, legY, 0.8), Vector3.new(x, legY / 2, z), STEEL, M.Metal)
			b:decor("Foot", Vector3.new(1.6, 0.6, 1.6), Vector3.new(x, 0.3, z), COPING, M.Concrete)
		end
	end
	for _, y in ipairs({ 5.5, 11 }) do
		for _, s in ipairs({ -1, 1 }) do
			b:decor("Tie", Vector3.new(7.6, 0.35, 0.35), Vector3.new(0, y, s * 3.6), STEEL, M.Metal)
			b:decor("Tie", Vector3.new(0.35, 0.35, 7.6), Vector3.new(s * 3.6, y, 0), STEEL, M.Metal)
		end
	end
	-- Cross bracing on the two faces you see from the lanes.
	for _, s in ipairs({ -1, 1 }) do
		for _, d in ipairs({ -1, 1 }) do
			local cf, len = Kit.Span(Vector3.new(s * 3.6, 0.8, -3.6 * d), Vector3.new(s * 3.6, 5.2, 3.6 * d))
			b:decor("Brace", Vector3.new(0.2, 0.2, len), cf, STEEL, M.Metal)
			local cf2, len2 = Kit.Span(Vector3.new(-3.6 * d, 6, s * 3.6), Vector3.new(3.6 * d, 10.6, s * 3.6))
			b:decor("Brace", Vector3.new(0.2, 0.2, len2), cf2, STEEL, M.Metal)
		end
	end
	b:decor("Deck", Vector3.new(0.4, 11.6, 11.6), vertical(Vector3.new(0, legY + 0.2, 0)), STEEL, M.DiamondPlate,
		{ shape = "Cylinder" })
	b:part("Tank", Vector3.new(11, 10, 10), vertical(Vector3.new(0, legY + 5.9, 0)), TANK_WOOD, M.WoodPlanks,
		{ shape = "Cylinder" })
	for _, y in ipairs({ 1.2, 3.6, 6, 8.4, 10.6 }) do
		b:decor("Hoop", Vector3.new(0.25, 10.15, 10.15), vertical(Vector3.new(0, legY + 0.4 + y, 0)), STEEL, M.Metal,
			{ shape = "Cylinder" })
	end
	-- The conical roof, stepped.
	for i, d in ipairs({ 10.8, 8.4, 5.8, 3.2 }) do
		b:decor("Roof", Vector3.new(0.9, d, d), vertical(Vector3.new(0, legY + 11.3 + i * 0.85, 0)),
			Color3.fromRGB(64, 58, 54), M.Slate, { shape = "Cylinder" })
	end
	b:decor("Finial", Vector3.new(1.4, 0.5, 0.5), vertical(Vector3.new(0, legY + 15.6, 0)), STEEL, M.Metal,
		{ shape = "Cylinder" })
	-- A ladder up one leg, and a little painted number on the tank.
	b:decor("Ladder", Vector3.new(0.15, legY + 10, 0.15), Vector3.new(4.25, (legY + 10) / 2, -0.5), STEEL, M.Metal)
	b:decor("Ladder", Vector3.new(0.15, legY + 10, 0.15), Vector3.new(4.25, (legY + 10) / 2, 0.5), STEEL, M.Metal)
	for y = 1, legY + 9, 1.2 do
		b:decor("Rung", Vector3.new(0.12, 0.12, 1), Vector3.new(4.25, y, 0), STEEL, M.Metal)
	end
end

--- The HVAC deck: a plant box under a steel grating deck, stairs up at the -Z end, a big
--- air handler at the far end, rails round the outside.
local function hvacDeck(b: Kit.Builder, accent: Color3)
	local DECK_Y = 5
	b:part("Plenum", Vector3.new(12, DECK_Y, 20), Vector3.new(0, DECK_Y / 2, 0), Color3.fromRGB(150, 156, 160), M.Metal)
	for z = -8, 8, 4 do
		for _, sx in ipairs({ -1, 1 }) do
			b:decor("Louvre", Vector3.new(0.12, 3, 2.8), Vector3.new(sx * 6.02, 2.4, z), darker(GALV, 0.3), M.Metal)
		end
	end
	b:part("Deck", Vector3.new(12.6, 0.4, 20.6), Vector3.new(0, DECK_Y + 0.2, 0), Color3.fromRGB(120, 124, 128),
		M.DiamondPlate)
	-- Toe boards in the side's colour, so you can tell whose deck you are looking at.
	for _, sx in ipairs({ -1, 1 }) do
		b:decor("Toe", Vector3.new(0.14, 0.5, 20.6), Vector3.new(sx * 6.36, DECK_Y + 0.15, 0), accent)
	end

	-- The air handler: cover at the front of the deck.
	b:part("Handler", Vector3.new(9, 4.6, 5), Vector3.new(0, DECK_Y + 2.7, 6.8), GALV, M.Metal)
	b:decor("HandlerCap", Vector3.new(9.3, 0.3, 5.3), Vector3.new(0, DECK_Y + 5.15, 6.8), darker(GALV, 0.15), M.Metal)
	for x = -3, 3, 2 do
		b:decor("Panel", Vector3.new(0.1, 3.6, 0.1), Vector3.new(x, DECK_Y + 2.7, 4.27), darker(GALV, 0.3), M.Metal)
	end
	b:part("Riser", Vector3.new(3, DECK_Y + 4.4, 3), Vector3.new(-3, (DECK_Y + 4.4) / 2, 11.6), GALV, M.Metal)
	b:decor("RiserSeam", Vector3.new(3.14, 0.25, 3.14), Vector3.new(-3, 4, 11.6), darker(GALV, 0.14), M.Metal)

	-- Rails on the outer side and the far end.
	local rail = Color3.fromRGB(242, 196, 40)
	for z = -9.5, 9.5, 3.8 do
		b:decor("Post", Vector3.new(0.25, 3.6, 0.25), Vector3.new(6.1, DECK_Y + 2.2, z), rail, M.Metal)
	end
	for _, y in ipairs({ 2, 3.9 }) do
		b:part("RailTop", Vector3.new(0.25, 0.25, 19.4), Vector3.new(6.1, DECK_Y + y, 0), rail, M.Metal,
			{ query = false })
	end

	-- Stairs up from the -Z end, along the inner edge: an invisible ramp you walk up and
	-- the steps you see.
	local stairX, width = -4, 4
	local run = 8
	b:part("Ramp", Vector3.new(width, DECK_Y + 0.4, run), Vector3.new(stairX, (DECK_Y + 0.4) / 2, -10 - run / 2),
		GALV, nil, { shape = "Wedge", transparency = 1, shadow = false })
	local steps = 7
	-- Stringers down both sides, so the treads are carried by something.
	for _, sx in ipairs({ -1, 1 }) do
		local cf, len = Kit.Span(Vector3.new(stairX + sx * width / 2, 0.1, -10 - run), Vector3.new(stairX + sx * width / 2,
			DECK_Y + 0.1, -10))
		b:decor("Stringer", Vector3.new(0.2, 0.7, len), cf, STEEL, M.Metal)
	end
	for i = 1, steps do
		local h = (DECK_Y + 0.4) * i / steps
		b:decor("Step", Vector3.new(width, 0.3, run / steps + 0.05),
			Vector3.new(stairX, h - 0.15, -10 - run + (i - 0.5) * run / steps), Color3.fromRGB(120, 124, 128),
			M.DiamondPlate)
	end
	for _, sx in ipairs({ -1, 1 }) do
		local from = Vector3.new(stairX + sx * width / 2, 3.4, -10 - run)
		local to = Vector3.new(stairX + sx * width / 2, DECK_Y + 3.4, -10)
		local cf, len = Kit.Span(from, to)
		b:decor("Handrail", Vector3.new(0.2, 0.2, len), cf, rail, M.Metal)
		b:decor("Newel", Vector3.new(0.25, 3.4, 0.25), from - Vector3.new(0, 1.7, 0), rail, M.Metal)
	end
end

--- The ridge skylight over the stairwell, dead centre. Symmetric by itself.
local function skylight(b: Kit.Builder)
	b:part("Curb", Vector3.new(16, 1.4, 10), Vector3.new(0, 0.7, 0), COPING, M.Concrete)
	for _, s in ipairs({ -1, 1 }) do
		b:part("Glazing", Vector3.new(15.4, 2.2, 4.7),
			CFrame.new(0, 1.4 + 1.1, s * 2.35) * CFrame.Angles(0, s == 1 and math.pi or 0, 0),
			GLASS, M.Glass, { shape = "Wedge", transparency = 0.3, reflectance = 0.15 })
		for x = -6, 6, 3 do
			local cf, len = Kit.Span(Vector3.new(x, 1.45, s * 4.75), Vector3.new(x, 3.6, 0))
			b:decor("Mullion", Vector3.new(0.2, 0.2, len + 0.2), cf, STEEL, M.Metal)
		end
	end
	b:decor("Ridge", Vector3.new(15.6, 0.3, 0.4), Vector3.new(0, 3.62, 0), STEEL, M.Metal)
	for _, x in ipairs({ -7.8, 7.8 }) do
		b:decor("Gable", Vector3.new(0.3, 2.2, 9.4), Vector3.new(x, 2.5, 0), STEEL, M.Metal, { transparency = 0.2 })
	end
end

local function chimney(b: Kit.Builder)
	b:part("Stack", Vector3.new(4, 12, 4), Vector3.new(0, 6, 0), BRICK, M.Brick)
	b:decor("Band", Vector3.new(4.1, 0.6, 4.1), Vector3.new(0, 10.4, 0), BRICK_DARK, M.Brick)
	b:decor("Cap", Vector3.new(4.6, 0.5, 4.6), Vector3.new(0, 12.25, 0), COPING, M.Concrete)
	for _, x in ipairs({ -0.9, 0.9 }) do
		b:decor("Pot", Vector3.new(1.6, 1.1, 1.1), vertical(Vector3.new(x, 13.3, 0)), Color3.fromRGB(176, 96, 64), M.Slate,
			{ shape = "Cylinder" })
	end
	-- A TV aerial strapped to it.
	b:decor("Mast", Vector3.new(0.18, 7, 0.18), Vector3.new(1.9, 14, 1.9), STEEL, M.Metal)
	b:decor("Boom", Vector3.new(0.14, 0.14, 4), Vector3.new(1.9, 17, 1.9), STEEL, M.Metal)
	for z = -1.5, 1.5, 0.75 do
		b:decor("Element", Vector3.new(1.6 - math.abs(z) * 0.3, 0.1, 0.1), Vector3.new(1.9, 17, 1.9 + z), STEEL, M.Metal)
	end
end

--- A galvanised duct run on low supports, 38 long along Z, with its drops into the roof.
local function ductRun(b: Kit.Builder, length: number)
	b:part("Duct", Vector3.new(3, 3, length), Vector3.new(0, 2.2, 0), GALV, M.Metal)
	for z = -length / 2 + 2, length / 2 - 2, 4 do
		b:decor("Seam", Vector3.new(3.14, 3.14, 0.25), Vector3.new(0, 2.2, z), darker(GALV, 0.14), M.Metal)
	end
	for z = -length / 2 + 4, length / 2 - 4, 8 do
		b:decor("Support", Vector3.new(4, 0.7, 0.5), Vector3.new(0, 0.35, z), STEEL, M.Metal)
	end
	for _, s in ipairs({ -1, 1 }) do
		b:part("Drop", Vector3.new(3, 0.8, 3), Vector3.new(0, 0.3, s * (length / 2 + 1.5)), GALV, M.Metal)
		b:part("Elbow", Vector3.new(3, 2.2, 3), Vector3.new(0, 1.6, s * (length / 2 + 1.5)), GALV, M.Metal)
	end
end

--- A small hangout in a corner: decking, two benches, a planter and a string of lights.
local function hangout(b: Kit.Builder)
	b:part("Decking", Vector3.new(10, 0.3, 8), Vector3.new(0, 0.15, 0), WOOD, M.WoodPlanks)
	for _, z in ipairs({ -2.6, 2.6 }) do
		b:part("Bench", Vector3.new(6, 0.4, 1.6), Vector3.new(-1, 1.7, z), WOOD, M.Wood)
		for _, x in ipairs({ -3.4, 1.4 }) do
			b:decor("BenchLeg", Vector3.new(0.4, 1.4, 1.4), Vector3.new(x, 0.9, z), STEEL, M.Metal)
		end
	end
	b:part("Planter", Vector3.new(2.4, 2.4, 7), Vector3.new(4, 1.5, 0), Color3.fromRGB(120, 84, 56), M.WoodPlanks)
	for _, z in ipairs({ -2.2, 0, 2.2 }) do
		b:decor("Shrub", Vector3.new(2.6, 2.6, 2.6), Vector3.new(4, 3.4, z), LEAF, M.Grass, { shape = "Ball" })
	end
	-- Lights strung between two poles, sagging.
	local a, c = Vector3.new(-5, 9, -3.8), Vector3.new(-5, 9, 3.8)
	for _, p in ipairs({ a, c }) do
		b:decor("Pole", Vector3.new(0.3, 9, 0.3), p - Vector3.new(0, 4.5, 0), STEEL, M.Metal)
	end
	local far = Vector3.new(5, 8, 0)
	for _, from in ipairs({ a, c }) do
		local count = 7
		local last = from
		for i = 1, count do
			local t = i / count
			local p = from:Lerp(far, t) - Vector3.new(0, math.sin(t * math.pi) * 1.2, 0)
			local cf, len = Kit.Span(last, p)
			b:decor("Wire", Vector3.new(0.06, 0.06, len), cf, Color3.fromRGB(30, 30, 30), M.SmoothPlastic)
			if i < count then
				b:neon("Bulb", Vector3.new(0.35, 0.35, 0.35), p - Vector3.new(0, 0.25, 0), Color3.fromRGB(255, 214, 140))
			end
			last = p
		end
	end
end

-- -------------------------------------------------------------- the city --

local BUILDING = {
	Color3.fromRGB(184, 146, 108), Color3.fromRGB(150, 76, 58), Color3.fromRGB(162, 160, 154),
	Color3.fromRGB(214, 202, 178), Color3.fromRGB(118, 96, 86), Color3.fromRGB(128, 140, 150),
}
local BASE_Y = -90

--- An axis-aligned block from the street up to `top`, with window bands on the faces that
--- look toward the map and a parapet cap.
local function building(b: Kit.Builder, x0: number, x1: number, z0: number, z1: number, top: number,
	colour: Color3, floors: number?)
	local w, d = x1 - x0, z1 - z0
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	b:decor("Building", Vector3.new(w, top - BASE_Y, d), Vector3.new(cx, (top + BASE_Y) / 2, cz), colour,
		colour == BUILDING[2] and M.Brick or M.Concrete)
	b:decor("Cap", Vector3.new(w + 0.8, 1, d + 0.8), Vector3.new(cx, top + 0.3, cz), darker(colour, 0.2), M.Concrete)
	local glass = Color3.fromRGB(58, 72, 88)
	local faces = {}
	if math.abs(cx) > w / 2 then
		table.insert(faces, { axis = "x", at = cx - math.sign(cx) * (w / 2 + 0.1), span = d, centre = cz })
	end
	if math.abs(cz) > d / 2 then
		table.insert(faces, { axis = "z", at = cz - math.sign(cz) * (d / 2 + 0.1), span = w, centre = cx })
	end
	for f = 0, (floors or 6) - 1 do
		local y = top - 5 - f * 7
		if y < BASE_Y + 4 then
			break
		end
		for _, face in ipairs(faces) do
			if face.axis == "x" then
				b:decor("Windows", Vector3.new(0.2, 2.6, face.span * 0.86), Vector3.new(face.at, y, face.centre), glass,
					M.Glass, { reflectance = 0.2 })
			else
				b:decor("Windows", Vector3.new(face.span * 0.86, 2.6, 0.2), Vector3.new(face.centre, y, face.at), glass,
					M.Glass, { reflectance = 0.2 })
			end
		end
	end
end

--- The billboard on the neighbour's roof, facing -X toward the map.
local function billboard(b: Kit.Builder)
	for _, z in ipairs({ -12, 12 }) do
		b:decor("Column", Vector3.new(1, 20, 1), Vector3.new(1, 0, z), STEEL, M.Metal)
		local cf, len = Kit.Span(Vector3.new(6, -10, z), Vector3.new(1, 6, z))
		b:decor("Strut", Vector3.new(0.6, 0.6, len), cf, STEEL, M.Metal)
	end
	b:decor("Catwalk", Vector3.new(2.4, 0.3, 34), Vector3.new(-0.6, 9.8, 0), STEEL, M.DiamondPlate)
	b:decor("Back", Vector3.new(0.8, 15, 36), Vector3.new(0.4, 17.6, 0), STEEL, M.Metal)
	b:decor("Face", Vector3.new(0.2, 14, 35), Vector3.new(-0.1, 17.6, 0), Color3.fromRGB(46, 26, 96), M.SmoothPlastic)
	b:decor("Stripe", Vector3.new(0.22, 14, 8), Vector3.new(-0.12, 17.6, 12.5), Color3.fromRGB(255, 70, 140))
	b:decor("Sun", Vector3.new(0.24, 10, 10), CFrame.new(-0.2, 17.6, 12.5), Color3.fromRGB(255, 196, 60),
		M.SmoothPlastic, { shape = "Cylinder" })
	b:sign("ZEE COLA", Kit.Look(Vector3.new(-0.36, 19, -5), Vector3.new(-10, 19, -5)), 24, 7,
		Color3.new(1, 1, 1), { lit = true, font = Enum.Font.Bangers, textColour = Color3.new(1, 1, 1),
			glow = Color3.fromRGB(20, 10, 40), stroke = 5, brightness = 1.3 })
	b:sign("ICE COLD SINCE 2025", Kit.Look(Vector3.new(-0.36, 13.2, -5), Vector3.new(-10, 13.2, -5)), 22, 2.2,
		Color3.new(1, 1, 1), { lit = true, font = Enum.Font.GothamBlack, textColour = Color3.fromRGB(255, 214, 90),
			glow = false, brightness = 1.2 })
	for _, z in ipairs({ -11, 0, 11 }) do
		b:decor("LampArm", Vector3.new(3, 0.25, 0.25), Vector3.new(-1.5, 25.6, z), STEEL, M.Metal)
		b:decor("LampHead", Vector3.new(1, 0.6, 1.6), Vector3.new(-3, 25.4, z), STEEL, M.Metal)
	end
end

--- The painted gable wall of the tall neighbour, facing -X toward the map.
local function mural(b: Kit.Builder, accent: Color3)
	b:decor("Primer", Vector3.new(0.2, 26, 40), Vector3.new(0, 0, 0), Color3.fromRGB(34, 36, 48), M.SmoothPlastic)
	-- Each coat of paint stands proud of the one under it. At one depth the two splashes (and
	-- the primer a hundredth of a stud behind them) fought over the same pixels.
	b:decor("Splash", Vector3.new(0.22, 26, 10), Vector3.new(-0.05, 0, -13), accent)
	b:decor("Splash", Vector3.new(0.22, 8, 30), Vector3.new(-0.09, -9, 5), Color3.fromRGB(255, 196, 60))
	graffiti(b, "PROJECT", Kit.Look(Vector3.new(-0.2, 6, 2), Vector3.new(-10, 6, 2)), 30, 7, Color3.new(1, 1, 1))
	graffiti(b, "ZEE", Kit.Look(Vector3.new(-0.2, -1.5, 2), Vector3.new(-10, -1.5, 2)), 22, 10,
		Color3.fromRGB(120, 230, 255))
end

-- ------------------------------------------------------------------- build --

function Map.Build(parent: Instance, centre: Vector3)
	local root = Kit.new(parent, CFrame.new(centre))
	local HW, HL = Map.HalfWidth, Map.HalfLength
	local IN_X, IN_Z = HW - 1, HL - 1      -- the parapets' inner faces

	Kit.Bounds(root, HW, HL, Map.Height)

	-- The roof, and a paver walkway down its centre.
	root:part("Roof", Vector3.new(HW * 2 + 1, 2, HL * 2 + 1), Vector3.new(0, -1, 0), ROOF, M.Asphalt)
	root:decor("Walkway", Vector3.new(7, 0.16, IN_Z * 2), Vector3.new(0, 0.08, 0), PAVER, M.Concrete)
	for z = -IN_Z + 3.5, IN_Z - 3.5, 3.5 do
		root:decor("PaverJoint", Vector3.new(7.02, 0.18, 0.12), Vector3.new(0, 0.09, z), darker(PAVER, 0.2), M.Concrete)
	end
	-- Membrane seams across the tar, every eight studs.
	for i = 1, 5 do
		for _, s in ipairs({ -1, 1 }) do
			root:decor("Seam", Vector3.new(0.3, 0.05, IN_Z * 2), Vector3.new(s * (4 + i * 7.6), 0.02, 0),
				darker(ROOF, 0.18), M.Asphalt)
		end
	end

	-- Parapets, coping and the building's face going down to the street.
	for _, s in ipairs({ -1, 1 }) do
		root:part("Parapet", Vector3.new(1.4, 3.6, HL * 2 + 0.8), Vector3.new(s * (IN_X + 0.7), 1.8, 0), BRICK, M.Brick)
		root:part("Parapet", Vector3.new(HW * 2 + 0.8, 3.6, 1.4), Vector3.new(0, 1.8, s * (IN_Z + 0.7)), BRICK, M.Brick)
		root:decor("Coping", Vector3.new(2, 0.4, HL * 2 + 1.4), Vector3.new(s * (IN_X + 0.7), 3.8, 0), COPING, M.Concrete)
		root:decor("Coping", Vector3.new(HW * 2 + 1.4, 0.4, 2), Vector3.new(0, 3.8, s * (IN_Z + 0.7)), COPING, M.Concrete)
		-- Stopped just under the roof's top, which overhangs it: level with it, the two made a
		-- flickering seam all the way round the roof edge.
		root:decor("Facade", Vector3.new(1, 90, HL * 2 + 2), Vector3.new(s * (HW + 0.9), -45.06, 0), BRICK, M.Brick)
		root:decor("Facade", Vector3.new(HW * 2 + 2, 90, 1), Vector3.new(0, -45.06, s * (HL + 0.9)), BRICK, M.Brick)
		root:decor("Cornice", Vector3.new(1.6, 1.2, HL * 2 + 3), Vector3.new(s * (HW + 1.2), -1.2, 0), COPING, M.Concrete)
		root:decor("Cornice", Vector3.new(HW * 2 + 3, 1.2, 1.6), Vector3.new(0, -1.2, s * (HL + 1.2)), COPING, M.Concrete)
	end
	root:decor("Street", Vector3.new(900, 1, 900), Vector3.new(0, BASE_Y - 0.5, 0), Color3.fromRGB(58, 60, 64), M.Asphalt)

	skylight(root:within(CFrame.new(0, 0, 0)))

	Kit.Both(root, function(b, side)
		local accent = SIDE[side]

		bulkhead(b:within(CFrame.new(0, 0, -IN_Z)), side)
		Kit.SpawnPad(b, Vector3.new(0, 0.12, -51), accent)

		condenser(b:within(CFrame.new(-11.5, 0, -41)))
		condenser(b:within(CFrame.new(11.5, 0, -41)))

		waterTower(b:within(CFrame.new(-29, 0, -26)))
		ductRun(b:within(CFrame.new(-38, 0, -30)), 32)
		hangout(b:within(CFrame.new(-26, 0, -54)))

		hvacDeck(b:within(CFrame.new(29, 0, -17)), accent)

		-- A roof hatch just off the centre line: crouch cover on the long walk to the middle.
		b:part("Hatch", Vector3.new(4.4, 2.6, 4.4), Vector3.new(-1.6, 1.3, -25), COPING, M.Concrete)
		b:part("HatchLid", Vector3.new(4.8, 0.4, 4.8), Vector3.new(-1.6, 2.8, -25), Color3.fromRGB(96, 110, 124), M.Metal)
		b:decor("HatchHandle", Vector3.new(1.4, 0.25, 0.25), Vector3.new(-1.6, 3.1, -23), GALV, M.Metal)
		chimney(b:within(CFrame.new(-14, 0, -9)))

		-- The neighbourhood on this side: a lower roof carrying the billboard, and a taller
		-- block with its gable painted.
		building(b, 56, 110, -70, 18, -14, BUILDING[1])
		billboard(b:within(CFrame.new(66, -14 + 10, -20)))
		waterTower(b:within(CFrame.new(90, -14, 0)))
		building(b, 56, 104, 24, 84, 26, BUILDING[3])
		mural(b:within(CFrame.new(55.4, 8, 54)), accent)
		building(b, 118, 170, -80, 10, 42, BUILDING[6], 8)
		building(b, 118, 160, 16, 90, 12, BUILDING[4])

		-- Across the street at this end.
		building(b, -70, -18, -140, -84, 22, BUILDING[2])
		building(b, -12, 34, -130, -84, -8, BUILDING[4])
		building(b, 40, 96, -150, -86, 48, BUILDING[5], 8)
		building(b, -120, -76, -150, -92, 64, BUILDING[6], 9)
	end)

	-- The skyline further out: towers on a ring, heights stepping up and down.
	local sky = root:folder("Skyline")
	local rng = Random.new(2024)
	for i = 0, 23 do
		local angle = i / 24 * math.pi * 2
		local r = 230 + (i % 3) * 30
		local x, z = math.cos(angle) * r, math.sin(angle) * r
		local w = 30 + (i * 7) % 18
		local top = 60 + ((i * 37) % 7) * 18 + rng:NextNumber(0, 10)
		building(sky, x - w / 2, x + w / 2, z - w / 2, z + w / 2, top, BUILDING[(i % #BUILDING) + 1], 10)
	end
end

return Map
