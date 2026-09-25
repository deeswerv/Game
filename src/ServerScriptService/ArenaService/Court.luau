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

--- A piece of cover and its rotational twin, neon along the top edges in each side's colour.
local function pair(root: Kit.Builder, name: string, size: Vector3, offset: Vector3, material: Enum.Material?)
	Kit.Both(root, function(b, side)
		local sideColour = side == 1 and SIDE_A or SIDE_B
		local paint = side == 1 and COVER or COVER_DARK
		b:part(name .. (side == 1 and "_A" or "_B"), size, offset,
			material == M.Slate and WALL or paint, material or M.Metal)
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
	root:part("Midfield", Vector3.new(W * 2, 2.1, 16), Vector3.new(0, -0.95, 0), FLOOR_ALT, M.Asphalt)
	root:neon("Centreline", Vector3.new(W * 2, 2.2, 0.5), Vector3.new(0, -0.9, 0), LINE)

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

	pair(root, "CrateLow", Vector3.new(8, 4, 8), Vector3.new(14, 1, 22))
	pair(root, "CrateTall", Vector3.new(6, 9, 6), Vector3.new(-20, 3.5, 12))
	pair(root, "Pillar", Vector3.new(5, 14, 5), Vector3.new(26, 6, -6), M.Slate)
	pair(root, "Barricade", Vector3.new(16, 5, 3), Vector3.new(-8, 1.5, -26), M.Concrete)
	pair(root, "MidBlock", Vector3.new(4, 7, 12), Vector3.new(16, 2.5, 0))

	-- ----------------------------------------------------------- spawns --

	Kit.Both(root, function(b, side)
		Kit.SpawnPad(b, Vector3.new(0, 0, -50), side == 1 and SIDE_A or SIDE_B)
	end)

	skyline(root:folder("Skyline"))
end

return Map
