--!strict
-- NEON COURT: the original duel arena, a night court on a rooftop.
--
-- Dark asphalt, dark concrete, and neon -- magenta on one side, cyan on the other -- with a
-- lit city skyline standing beyond the walls. Colour marks the two halves; it is never tied
-- to who is winning, so it can never disagree with the scoreboard.
--
-- Laid out with 180-degree rotational symmetry, not mirror symmetry: rotate the arena half
-- a turn and it is identical, so each player sees exactly the same thing from their spawn.

local Kit = require(script.Parent.Kit)

local Map = {}

Map.Id = "Court"
Map.Name = "NEON COURT"
Map.Tagline = "Rooftop court after dark"
Map.HalfWidth = 42
Map.HalfLength = 60
Map.Height = 34        -- double jump clears about 14, so the walls are not climbable
Map.Spawns = { Vector3.new(0, 3, -50), Vector3.new(0, 3, 50) }
Map.Mood = "night"
Map.Exposure = 1.0

-- Night: the sun well down, a cool ambient, and the grade leaning into the neon.
Map.Look = {
	Lighting = {
		ClockTime = 21.5,
		Brightness = 1.4,
		Ambient = Color3.fromRGB(70, 66, 96),
		OutdoorAmbient = Color3.fromRGB(96, 92, 132),
		ColorShift_Top = Color3.fromRGB(0, 0, 0),
		ExposureCompensation = 0.1,
		EnvironmentDiffuseScale = 0.4,
		EnvironmentSpecularScale = 0.9,
	},
	Atmosphere = {
		Density = 0.3,
		Offset = 0.1,
		Color = Color3.fromRGB(96, 84, 150),
		Decay = Color3.fromRGB(40, 30, 80),
		Glare = 0,
		Haze = 1.2,
	},
	Grade = {
		Brightness = -0.04,
		Contrast = 0.2,
		Saturation = 0.3,
		TintColor = Color3.fromRGB(226, 218, 255),
	},
	Bloom = { Intensity = 1, Size = 26, Threshold = 1.2 },
	SunRays = { Intensity = 0 },
	Clouds = { Cover = 0 },
}

local FLOOR = Color3.fromRGB(34, 36, 44)
local FLOOR_ALT = Color3.fromRGB(26, 28, 34)
local WALL = Color3.fromRGB(28, 30, 38)
local COVER = Color3.fromRGB(122, 36, 52)        -- painted metal, side A
local COVER_DARK = Color3.fromRGB(26, 92, 110)   -- painted metal, side B
local LINE = Color3.fromRGB(235, 238, 255)
local SIDE_A = Color3.fromRGB(255, 60, 200)      -- magenta
local SIDE_B = Color3.fromRGB(40, 220, 255)      -- cyan
local WINDOW = {
	Color3.fromRGB(255, 214, 140), Color3.fromRGB(255, 214, 140), Color3.fromRGB(150, 220, 255),
	Color3.fromRGB(255, 120, 210), Color3.fromRGB(255, 236, 190),
}

local M = Enum.Material

-- The dressing. Every piece of it is decoration -- no collision, no raycasts -- and stands a
-- few hundredths of a stud off the surface it is fixed to, so it never shares a face with the
-- cover or the wall behind it (which is what makes a detail flicker).
local STEEL = Color3.fromRGB(60, 64, 76)
local STEEL_DARK = Color3.fromRGB(34, 36, 44)
local HAZARD = Color3.fromRGB(246, 196, 48)
local RUBBER = Color3.fromRGB(18, 18, 22)
local SEAM = Color3.fromRGB(22, 24, 30)
local PROUD = 0.06

type Dress = (b: Kit.Builder, size: Vector3, offset: Vector3, paint: Color3, accent: Color3) -> ()

--- The visible height of a piece of cover: from the floor to its top.
local function span(size: Vector3, offset: Vector3): (number, number)
	return math.max(0, offset.Y - size.Y / 2), offset.Y + size.Y / 2
end

--- Rubber guards down the four vertical edges, standing just proud of both faces.
local function cornerGuards(b: Kit.Builder, size: Vector3, offset: Vector3, colour: Color3)
	local low, top = span(size, offset)
	local h = top - low - 0.2
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			b:decor("Guard", Vector3.new(0.7, h, 0.7),
				Vector3.new(offset.X + sx * (size.X / 2 - 0.35 + PROUD), low + h / 2, offset.Z + sz * (size.Z / 2 - 0.35 + PROUD)),
				colour, M.Rubber)
		end
	end
end

--- A band round all four faces at height `y`, between the corner guards.
local function band(b: Kit.Builder, size: Vector3, offset: Vector3, y: number, h: number, colour: Color3,
	material: Enum.Material?, inset: number?)
	local gap = inset or 1.5
	for _, sx in ipairs({ -1, 1 }) do
		b:decor("Band", Vector3.new(PROUD, h, size.Z - gap), Vector3.new(offset.X + sx * (size.X / 2 + PROUD / 2), y, offset.Z),
			colour, material)
	end
	for _, sz in ipairs({ -1, 1 }) do
		b:decor("Band", Vector3.new(size.X - gap, h, PROUD), Vector3.new(offset.X, y, offset.Z + sz * (size.Z / 2 + PROUD / 2)),
			colour, material)
	end
end

--- A low equipment case: corner guards, a painted stripe, latches and a lid seam.
local function caseDress(b: Kit.Builder, size: Vector3, offset: Vector3, paint: Color3, accent: Color3)
	local low, top = span(size, offset)
	cornerGuards(b, size, offset, RUBBER)
	band(b, size, offset, top - 0.45, 0.14, SEAM)
	band(b, size, offset, low + (top - low) * 0.42, 0.7, accent:Lerp(paint, 0.55), M.SmoothPlastic)
	for _, sx in ipairs({ -1, 1 }) do
		for _, dz in ipairs({ -1.8, 1.8 }) do
			b:decor("Latch", Vector3.new(0.12, 0.6, 0.5),
				Vector3.new(offset.X + sx * (size.X / 2 + PROUD + 0.06), top - 0.75, offset.Z + dz), STEEL, M.Metal)
		end
	end
	for _, sz in ipairs({ -1, 1 }) do
		b:decor("Handle", Vector3.new(1.6, 0.18, 0.18), Vector3.new(offset.X, low + (top - low) * 0.72,
			offset.Z + sz * (size.Z / 2 + 0.09)), STEEL, M.Metal)
	end
end

--- Stacked crates: seams between the tiers, corner posts, a hazard panel on each face.
local function stackDress(b: Kit.Builder, size: Vector3, offset: Vector3, paint: Color3, accent: Color3)
	local low, top = span(size, offset)
	cornerGuards(b, size, offset, STEEL_DARK)
	local tier = (top - low) / 3
	for i = 1, 2 do
		band(b, size, offset, low + tier * i, 0.22, SEAM)
	end
	-- Hazard panel: alternating blocks, low on two opposite faces.
	for _, sz in ipairs({ -1, 1 }) do
		for k = 0, 4 do
			local x = offset.X - 1.6 + k * 0.8
			b:decor("Hazard", Vector3.new(0.8, 0.6, PROUD), Vector3.new(x, low + tier * 0.5,
				offset.Z + sz * (size.Z / 2 + PROUD / 2)), k % 2 == 0 and HAZARD or RUBBER)
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		b:decor("Stencil", Vector3.new(PROUD, 1.1, 2.6), Vector3.new(offset.X + sx * (size.X / 2 + PROUD / 2),
			low + tier * 1.5, offset.Z), accent:Lerp(paint, 0.4))
	end
end

--- A concrete column: a wider foot, steel collars, and a lit slot down two faces.
local function pillarDress(b: Kit.Builder, size: Vector3, offset: Vector3, _paint: Color3, accent: Color3)
	local low, top = span(size, offset)
	b:decor("Foot", Vector3.new(size.X + 0.5, 0.9, size.Z + 0.5), Vector3.new(offset.X, low + 0.45, offset.Z),
		STEEL_DARK, M.Concrete)
	for _, y in ipairs({ low + (top - low) * 0.34, low + (top - low) * 0.68 }) do
		band(b, size, offset, y, 0.35, STEEL, M.Metal, 0.2)
	end
	for _, sx in ipairs({ -1, 1 }) do
		b:neon("Slot", Vector3.new(PROUD, (top - low) * 0.26, 0.3), Vector3.new(offset.X + sx * (size.X / 2 + PROUD / 2),
			low + (top - low) * 0.51, offset.Z), accent, 0.1)
	end
end

--- A jersey barrier: a heavier foot and a hazard band down both long faces.
local function barrierDress(b: Kit.Builder, size: Vector3, offset: Vector3, _paint: Color3, _accent: Color3)
	local low, top = span(size, offset)
	b:decor("Foot", Vector3.new(size.X + 0.3, 0.7, size.Z + 0.4), Vector3.new(offset.X, low + 0.35, offset.Z),
		STEEL_DARK, M.Concrete)
	local blocks = 10
	local w = (size.X - 1) / blocks
	for _, sz in ipairs({ -1, 1 }) do
		for k = 0, blocks - 1 do
			b:decor("Hazard", Vector3.new(w, 0.7, PROUD), Vector3.new(offset.X - (size.X - 1) / 2 + w * (k + 0.5),
				top - 1.2, offset.Z + sz * (size.Z / 2 + PROUD / 2)), k % 2 == 0 and HAZARD or RUBBER)
		end
	end
	for _, sx in ipairs({ -1, 1 }) do
		b:decor("EndCap", Vector3.new(PROUD, top - low - 0.9, size.Z - 0.6), Vector3.new(offset.X + sx * (size.X / 2 + PROUD / 2),
			low + 0.9 + (top - low - 0.9) / 2 - 0.1, offset.Z), STEEL, M.Metal)
	end
end

--- A rooftop plant unit: louvred sides and a grille on each end.
local function ventDress(b: Kit.Builder, size: Vector3, offset: Vector3, _paint: Color3, _accent: Color3)
	local low, top = span(size, offset)
	cornerGuards(b, size, offset, STEEL_DARK)
	for _, sx in ipairs({ -1, 1 }) do
		for y = low + 1.2, top - 1.2, 0.55 do
			b:decor("Louvre", Vector3.new(0.12, 0.16, size.Z - 2.2), Vector3.new(offset.X + sx * (size.X / 2 + PROUD + 0.04), y,
				offset.Z), SEAM, M.Metal)
		end
	end
	for _, sz in ipairs({ -1, 1 }) do
		b:decor("Grille", Vector3.new(size.X - 1.6, (top - low) * 0.45, PROUD), Vector3.new(offset.X, low + (top - low) * 0.55,
			offset.Z + sz * (size.Z / 2 + PROUD / 2)), STEEL, M.DiamondPlate)
	end
end

--- A piece of cover and its rotational twin, neon along the top edges in each side's colour.
local function pair(root: Kit.Builder, name: string, size: Vector3, offset: Vector3, material: Enum.Material?,
	dress: Dress?)
	Kit.Both(root, function(b, side)
		local sideColour = side == 1 and SIDE_A or SIDE_B
		local paint = side == 1 and COVER or COVER_DARK
		b:part(name .. (side == 1 and "_A" or "_B"), size, offset,
			material == M.Slate and WALL or paint, material or M.Metal)
		if dress then
			dress(b, size, offset, material == M.Slate and WALL or paint, sideColour)
		end
		local top = offset.Y + size.Y / 2
		for _, dx in ipairs({ -1, 1 }) do
			b:neon("Edge", Vector3.new(0.25, 0.25, size.Z + 0.1),
				Vector3.new(offset.X + dx * (size.X / 2), top, offset.Z), sideColour)
		end
		for _, dz in ipairs({ -1, 1 }) do
			b:neon("Edge", Vector3.new(size.X + 0.1, 0.25, 0.25),
				Vector3.new(offset.X, top, offset.Z + dz * (size.Z / 2)), sideColour)
		end
	end)
end

--- Dark towers with lit windows standing beyond the walls, some with a neon sign on the
--- roof. Seeded, so every server builds the same city.
local function skyline(root: Kit.Builder)
	local rng = Random.new(3000)
	local names = { "ZEE", "24/7", "MOTEL", "ARCADE", "GG", "HOTEL", "PLAY", "1V1", "BAR", "NEON" }
	local count = 0

	local function tower(x: number, z: number)
		local w = rng:NextNumber(14, 26)
		local d = rng:NextNumber(14, 24)
		local h = rng:NextNumber(70, 150)
		local base = Vector3.new(x, -60 + h / 2, z)
		local cf = Kit.Look(base, Vector3.new(0, base.Y, 0))
		root:decor("Tower", Vector3.new(w, h, d), cf,
			Color3.fromRGB(18 + rng:NextInteger(0, 8), 20 + rng:NextInteger(0, 8), 30 + rng:NextInteger(0, 10)))

		local rows = math.floor(h / 9)
		for r = 1, rows do
			if rng:NextNumber() < 0.7 then
				local y = -h / 2 + 6 + r * 8
				if y < h / 2 - 3 then
					root:decor("Windows", Vector3.new(w * rng:NextNumber(0.4, 0.85), 1.2, 0.2),
						cf * CFrame.new(rng:NextNumber(-w * 0.1, w * 0.1), y, -d / 2 - 0.12),
						WINDOW[rng:NextInteger(1, #WINDOW)], M.Neon, { transparency = rng:NextNumber(0, 0.35) })
				end
			end
		end

		count += 1
		if count % 3 == 0 then
			local roof = cf * CFrame.new(0, h / 2 + 5, -d / 2 + 1)
			root:sign(names[(count // 3 - 1) % #names + 1], Kit.Look(roof.Position, roof.Position + roof.LookVector),
				w * 0.9, 8, rng:NextNumber() < 0.5 and SIDE_A or SIDE_B)
		end
	end

	for _, side in ipairs({ -1, 1 }) do
		for z = -150, 150, 30 do
			tower(side * rng:NextNumber(82, 120), z + rng:NextNumber(-6, 6))
		end
		for x = -90, 90, 30 do
			tower(x + rng:NextNumber(-6, 6), side * rng:NextNumber(110, 140))
		end
	end
end

function Map.Build(parent: Instance, centre: Vector3)
	local root = Kit.new(parent, CFrame.new(centre))
	local L, W, H = Map.HalfLength, Map.HalfWidth, Map.Height

	-- ------------------------------------------------------------- shell --

	local floor = root:part("Floor", Vector3.new(W * 2, 2, L * 2), Vector3.new(0, -1, 0), FLOOR, M.Asphalt)

	-- A darker band across the middle, so both players can see where half way is.
	-- Each a little short of the floor's ends, so their ends are not the floor's ends too.
	root:part("Midfield", Vector3.new(W * 2 - 0.1, 2.1, 16), Vector3.new(0, -0.95, 0), FLOOR_ALT, M.Asphalt)
	root:neon("Centreline", Vector3.new(W * 2 - 0.2, 2.2, 0.5), Vector3.new(0, -0.9, 0), LINE)

	for _, sx in ipairs({ -1, 1 }) do
		root:decor("CourtLine", Vector3.new(0.4, 0.05, L * 2 - 6), Vector3.new(sx * (W - 3), 0.03, 0), LINE, nil,
			{ transparency = 0.35 })
	end
	for _, sz in ipairs({ -1, 1 }) do
		root:decor("CourtLine", Vector3.new(W * 2 - 6, 0.05, 0.4), Vector3.new(0, 0.03, sz * (L - 3)), LINE, nil,
			{ transparency = 0.35 })
	end

	-- A big faded logo painted on each half, each turned to face its own spawn.
	local logo = Instance.new("SurfaceGui")
	logo.Face = Enum.NormalId.Top
	logo.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	logo.PixelsPerStud = 6
	logo.LightInfluence = 1
	logo.Parent = floor
	for i, y in ipairs({ 0.24, 0.76 }) do
		local logoText = Instance.new("TextLabel")
		logoText.BackgroundTransparency = 1
		logoText.AnchorPoint = Vector2.new(0.5, 0.5)
		logoText.Position = UDim2.fromScale(0.5, y)
		logoText.Size = UDim2.fromScale(0.8, 0.22)
		logoText.Rotation = i == 1 and 180 or 0
		logoText.Text = "ZEE"
		logoText.TextScaled = true
		logoText.Font = Enum.Font.FredokaOne
		logoText.TextColor3 = Color3.fromRGB(255, 255, 255)
		logoText.TextTransparency = 0.86
		logoText.Parent = logo
	end

	for _, side in ipairs({ -1, 1 }) do
		root:part("WallX", Vector3.new(2, H, L * 2 + 4), Vector3.new(side * (W + 1), H / 2 - 1, 0), WALL, M.Concrete)
		root:part("WallZ", Vector3.new(W * 2 + 4, H, 2), Vector3.new(0, H / 2 - 1, side * (L + 1)), WALL, M.Concrete)
	end
	Kit.Bounds(root, W, L, H - 1)

	-- ------------------------------------------------------------- neon --

	for _, y in ipairs({ H - 2.5, 5 }) do
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				root:neon("Trim", Vector3.new(0.3, 0.5, L), Vector3.new(sx * (W - 0.1), y, sz * L / 2),
					sz < 0 and SIDE_A or SIDE_B)
			end
		end
		for _, sz in ipairs({ -1, 1 }) do
			root:neon("Trim", Vector3.new(W * 2, 0.5, 0.3), Vector3.new(0, y, sz * (L - 0.1)), sz < 0 and SIDE_A or SIDE_B)
		end
	end
	for z = -48, 48, 24 do
		for _, sx in ipairs({ -1, 1 }) do
			root:neon("LightBar", Vector3.new(0.3, H - 8, 0.6), Vector3.new(sx * (W - 0.1), (H - 8) / 2 + 2, z),
				z < 0 and SIDE_A or SIDE_B, 0.15)
		end
	end

	local function wallSign(text: string, at: Vector3, facing: Vector3, w: number, h: number, colour: Color3)
		root:sign(text, Kit.Look(at, at + facing), w, h, colour, { brightness = 2.6 })
	end
	wallSign("1V1", Vector3.new(0, H - 11, -(L - 0.4)), Vector3.new(0, 0, 1), 34, 13, SIDE_A)
	wallSign("1V1", Vector3.new(0, H - 11, L - 0.4), Vector3.new(0, 0, -1), 34, 13, SIDE_B)
	wallSign("PROJECT ZEE", Vector3.new(-(W - 0.4), H - 11, 0), Vector3.new(1, 0, 0), 60, 9, SIDE_B)
	wallSign("PROJECT ZEE", Vector3.new(W - 0.4, H - 11, 0), Vector3.new(-1, 0, 0), 60, 9, SIDE_A)

	-- ----------------------------------------------------------- lights --

	for i, z in ipairs({ -30, 30 }) do
		for _, x in ipairs({ -18, 18 }) do
			root:neon("Lamp", Vector3.new(4, 0.6, 2), Vector3.new(x, H - 3, z), Color3.fromRGB(240, 244, 255))
			root:light("Spot", CFrame.new(x, H - 3.4, z) * CFrame.Angles(-math.pi / 2, 0, 0),
				Color3.fromRGB(235, 240, 255), 1.6, 48,
				{ Angle = 80, Shadows = (i == 1 and x < 0) or (i == 2 and x > 0) })
		end
	end
	for _, sz in ipairs({ -1, 1 }) do
		root:light("Point", Vector3.new(0, 10, sz * (L - 8)), sz < 0 and SIDE_A or SIDE_B, 1.2, 40)
	end

	-- ------------------------------------------------------------ cover --

	pair(root, "CrateLow", Vector3.new(8, 4, 8), Vector3.new(14, 1, 22), nil, caseDress)
	pair(root, "CrateTall", Vector3.new(6, 9, 6), Vector3.new(-20, 3.5, 12), nil, stackDress)
	pair(root, "Pillar", Vector3.new(5, 14, 5), Vector3.new(26, 6, -6), M.Slate, pillarDress)
	pair(root, "Barricade", Vector3.new(16, 5, 3), Vector3.new(-8, 1.5, -26), M.Concrete, barrierDress)
	pair(root, "MidBlock", Vector3.new(4, 7, 12), Vector3.new(16, 2.5, 0), nil, ventDress)

	-- ---------------------------------------------------------- dressing --

	-- Floor: the slab is laid in twelve-stud panels. Seams sit just above the slab and below
	-- every painted line, so where they cross, the paint wins cleanly.
	for x = -W + 12, W - 12, 12 do
		root:decor("Seam", Vector3.new(0.12, 0.03, L * 2 - 0.4), Vector3.new(x, 0.005, 0), SEAM, M.Asphalt)
	end
	for z = -L + 12, L - 12, 12 do
		if math.abs(z) > 9 then
			root:decor("Seam", Vector3.new(W * 2 - 0.4, 0.03, 0.12), Vector3.new(0, 0.005, z), SEAM, M.Asphalt)
		end
	end
	-- A centre circle on the midfield band, and an arc round each spawn: segments of a
	-- low-poly ring, painted like the court lines.
	local function ring(centre: Vector3, radius: number, from: number, to: number, pieces: number, y: number)
		for i = 0, pieces - 1 do
			local a0 = from + (to - from) * i / pieces
			local a1 = from + (to - from) * (i + 1) / pieces
			local p0 = centre + Vector3.new(math.cos(a0) * radius, 0, math.sin(a0) * radius)
			local p1 = centre + Vector3.new(math.cos(a1) * radius, 0, math.sin(a1) * radius)
			local cf, len = Kit.Span(p0, p1)
			root:decor("CourtLine", Vector3.new(0.4, 0.04, len + 0.08), cf + Vector3.new(0, y, 0), LINE, nil,
				{ transparency = 0.35 })
		end
	end
	ring(Vector3.new(0, 0, 0), 7, 0, math.pi * 2, 20, 0.14)
	for _, sz in ipairs({ -1, 1 }) do
		ring(Vector3.new(0, 0, sz * L), 16, sz < 0 and 0 or math.pi, sz < 0 and math.pi or math.pi * 2, 14, 0.025)
	end

	-- Walls: a dark kickboard, steel pilasters between the light bars, and speakers high up.
	Kit.Both(root, function(b, _side)
		for _, sx in ipairs({ -1, 1 }) do
			b:decor("Kickboard", Vector3.new(0.1, 1.6, L - 1), Vector3.new(sx * (W - 0.05), 0.8, -L / 2), STEEL_DARK, M.Metal)
			for _, z in ipairs({ -36, -12 }) do
				b:decor("Pilaster", Vector3.new(0.14, H - 6, 0.9), Vector3.new(sx * (W - 0.07), (H - 6) / 2 + 1.7, z), STEEL, M.Metal)
				b:decor("Bolt", Vector3.new(0.1, 0.3, 0.3), Vector3.new(sx * (W - 0.19), 3, z), STEEL_DARK, M.Metal)
			end
			local speaker = Vector3.new(sx * (W - 0.8), H - 7, -L + 6)
			b:decor("Speaker", Vector3.new(1.4, 2.4, 1.6), speaker, RUBBER, M.Metal)
			b:decor("Cone", Vector3.new(0.12, 1.3, 1.3), speaker + Vector3.new(-sx * 0.76, 0.2, 0), STEEL_DARK, M.Fabric,
				{ shape = "Cylinder" })
		end
		b:decor("Kickboard", Vector3.new(W * 2 - 0.3, 1.6, 0.1), Vector3.new(0, 0.8, -(L - 0.05)), STEEL_DARK, M.Metal)
		-- A team bench and a bank of lockers against the end wall behind each spawn.
		b:part("Bench", Vector3.new(10, 1.1, 1.6), Vector3.new(-14, 0.55, -(L - 1.6)), STEEL, M.Metal)
		b:decor("BenchPad", Vector3.new(9.6, 0.2, 1.3), Vector3.new(-14, 1.2, -(L - 1.6)), RUBBER, M.Fabric)
		for i = 0, 3 do
			local x = 12 + i * 2.1
			b:part("Locker", Vector3.new(2, 7, 1.4), Vector3.new(x, 3.5, -(L - 0.7)), i % 2 == 0 and STEEL or STEEL_DARK, M.Metal)
			b:decor("Vent", Vector3.new(1.2, 0.5, PROUD), Vector3.new(x, 5.8, -(L - 1.4 - PROUD / 2)), SEAM, M.Metal)
			b:decor("Handle", Vector3.new(0.14, 0.9, 0.14), Vector3.new(x + 0.6, 3.6, -(L - 1.52)), STEEL, M.Metal)
		end
	end)

	-- Lighting rigs: a truss across the court at each pair of lamps, so the lamps hang from
	-- something instead of floating under the lid.
	for _, z in ipairs({ -30, 30 }) do
		local top, bottom = H - 1.6, H - 3.6
		for _, y in ipairs({ top, bottom }) do
			for _, dz in ipairs({ -0.8, 0.8 }) do
				root:decor("Chord", Vector3.new(W * 2, 0.35, 0.35), Vector3.new(0, y, z + dz), STEEL_DARK, M.Metal)
			end
		end
		for x = -W + 3, W - 3, 4 do
			for _, dz in ipairs({ -0.8, 0.8 }) do
				local cf, len = Kit.Span(Vector3.new(x, bottom, z + dz), Vector3.new(x + 2, top, z + dz))
				root:decor("Web", Vector3.new(0.2, 0.2, len), cf, STEEL, M.Metal)
				local cf2, len2 = Kit.Span(Vector3.new(x + 2, top, z + dz), Vector3.new(x + 4, bottom, z + dz))
				root:decor("Web", Vector3.new(0.2, 0.2, len2), cf2, STEEL, M.Metal)
			end
		end
		for _, x in ipairs({ -18, 18 }) do
			root:decor("Hanger", Vector3.new(0.15, 0.5, 0.15), Vector3.new(x, H - 3.5, z), STEEL, M.Metal)
			root:decor("LampHood", Vector3.new(4.4, 0.35, 2.4), Vector3.new(x, H - 2.53, z), STEEL_DARK, M.Metal)
		end
	end

	-- ----------------------------------------------------------- spawns --

	Kit.Both(root, function(b, side)
		Kit.SpawnPad(b, Vector3.new(0, 0, -50), side == 1 and SIDE_A or SIDE_B)
	end)

	skyline(root:folder("Skyline"))
end

return Map
