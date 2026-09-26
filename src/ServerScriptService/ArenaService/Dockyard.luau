--!strict
-- DOCKYARD: a container quay at sunset.
--
-- The play space is the quay itself: concrete slabs with painted bays, shipping containers
-- set down in them, and a rail gantry spanning the middle with a box hanging from it. Water
-- runs down both long sides (with a moored ship and a crane across it), and each end is a
-- warehouse front with its dock number over the door.
--
-- Layout, from spawn A looking down the map: a pair of jersey barriers shields the spawn; a
-- long 40ft box walls off the left lane; a two-high stack and a parked forklift hold the
-- right; a single box either side of the centre line makes crossing the middle a decision.
-- The other half is the same, turned round (Kit.Both).

local Kit = require(script.Parent.Kit)

local Map = {}

Map.Id = "Dockyard"
Map.Name = "DOCKYARD"
Map.Tagline = "Container quay at sunset"
Map.HalfWidth = 46
Map.HalfLength = 66
Map.Height = 38
Map.Spawns = { Vector3.new(0, 3, -58), Vector3.new(0, 3, 58) }
Map.Mood = "sunset"
Map.Exposure = 1.0

-- Late sun low across the quay: warm key light, long shadows, a hazy orange sky.
Map.Look = {
	Lighting = {
		ClockTime = 17.4,
		Brightness = 2.8,
		Ambient = Color3.fromRGB(104, 88, 96),
		OutdoorAmbient = Color3.fromRGB(156, 122, 112),
		ColorShift_Top = Color3.fromRGB(255, 150, 70),
		ExposureCompensation = 0.12,
		EnvironmentDiffuseScale = 0.6,
		EnvironmentSpecularScale = 0.75,
	},
	Atmosphere = {
		Density = 0.32,
		Offset = 0.22,
		Color = Color3.fromRGB(255, 178, 124),
		Decay = Color3.fromRGB(176, 96, 112),
		Glare = 0.7,
		Haze = 2.2,
	},
	Grade = {
		Brightness = 0,
		Contrast = 0.14,
		Saturation = 0.18,
		TintColor = Color3.fromRGB(255, 234, 216),
	},
	Bloom = { Intensity = 0.8, Size = 24, Threshold = 1.4 },
	SunRays = { Intensity = 0.14 },
	Clouds = { Cover = 0 },
}

local M = Enum.Material

local CONCRETE = Color3.fromRGB(146, 142, 134)
local CONCRETE_LIGHT = Color3.fromRGB(186, 182, 172)
local QUAY_FACE = Color3.fromRGB(108, 104, 98)
local JOINT = Color3.fromRGB(104, 100, 94)
local YELLOW = Color3.fromRGB(242, 188, 40)
local BLACK = Color3.fromRGB(30, 30, 33)
local STEEL = Color3.fromRGB(64, 80, 98)
local STEEL_DARK = Color3.fromRGB(46, 58, 72)
local DOOR = Color3.fromRGB(176, 178, 174)
local WATER = Color3.fromRGB(36, 88, 102)
local CRANE = Color3.fromRGB(236, 176, 34)
local STS = Color3.fromRGB(200, 58, 44)
local WHITE = Color3.fromRGB(232, 232, 226)
local SODIUM = Color3.fromRGB(255, 178, 98)
local WARM_WINDOW = Color3.fromRGB(255, 212, 150)
local WOOD = Color3.fromRGB(176, 130, 82)
local WOOD_DARK = Color3.fromRGB(128, 88, 54)

-- Two halves, two colours: orange for A, blue for B. Used sparingly -- spawn rings, the
-- band along each warehouse, the barrier caps -- so you always know which end is whose.
local SIDE = { Color3.fromRGB(255, 132, 40), Color3.fromRGB(44, 170, 255) }

-- Shipping-line colours, faded the way painted steel gets by the sea.
local RUST = Color3.fromRGB(168, 64, 42)
local NAVY = Color3.fromRGB(38, 68, 120)
local TEAL = Color3.fromRGB(30, 118, 116)
local MUSTARD = Color3.fromRGB(214, 160, 46)
local GREY = Color3.fromRGB(190, 192, 188)
local GREEN = Color3.fromRGB(62, 118, 70)
local PALETTE = { RUST, NAVY, TEAL, MUSTARD, GREY, GREEN }

local function darker(c: Color3, t: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), t)
end

local function vertical(at: Vector3): CFrame
	-- A cylinder's axis is its X; this stands it upright.
	return CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
end

-- ------------------------------------------------------------------ props --
-- Every prop is built in its own space: base on y = 0, centred, then placed with `within`.

--- A shipping container, `length` long along Z, doors on the +Z end.
local function container(b: Kit.Builder, length: number, colour: Color3, label: string?)
	local W, H = 8, 8.6
	local frame = darker(colour, 0.3)
	local rib = darker(colour, 0.12)
	b:part("Container", Vector3.new(W - 0.3, H - 0.4, length - 0.3), Vector3.new(0, H / 2, 0), colour, M.Metal)

	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			b:part("Post", Vector3.new(0.5, H, 0.5), Vector3.new(sx * (W / 2 - 0.25), H / 2, sz * (length / 2 - 0.25)),
				frame, M.Metal)
		end
		for _, y in ipairs({ 0.25, H - 0.25 }) do
			b:part("Rail", Vector3.new(0.5, 0.5, length - 1), Vector3.new(sx * (W / 2 - 0.25), y, 0), frame, M.Metal)
		end
	end
	for _, sz in ipairs({ -1, 1 }) do
		for _, y in ipairs({ 0.25, H - 0.25 }) do
			b:part("Rail", Vector3.new(W - 1, 0.5, 0.5), Vector3.new(0, y, sz * (length / 2 - 0.25)), frame, M.Metal)
		end
	end

	-- Corrugation down both long sides.
	local ribs = math.floor((length - 2) / 2.2)
	for _, sx in ipairs({ -1, 1 }) do
		Kit.Run(Vector3.new(sx * (W / 2 - 0.08), H / 2, -(length / 2 - 1.4)),
			Vector3.new(sx * (W / 2 - 0.08), H / 2, length / 2 - 1.4), ribs, function(p)
				b:decor("Rib", Vector3.new(0.3, H - 1.2, 0.8), p, rib, M.Metal)
			end)
	end

	-- Doors: two leaves, four locking bars, two handles.
	local z = length / 2 - 0.1
	for _, sx in ipairs({ -1, 1 }) do
		b:decor("Door", Vector3.new(3.7, H - 1.1, 0.16), Vector3.new(sx * 1.9, H / 2, z), rib, M.Metal)
	end
	for _, x in ipairs({ -2.9, -0.8, 0.8, 2.9 }) do
		b:decor("LockBar", Vector3.new(H - 1.3, 0.22, 0.22), vertical(Vector3.new(x, H / 2, z + 0.14)),
			Color3.fromRGB(200, 200, 196), M.Metal, { shape = "Cylinder" })
	end
	for _, x in ipairs({ -0.8, 0.8 }) do
		b:decor("Handle", Vector3.new(0.2, 1.1, 0.2), Vector3.new(x + (x > 0 and 0.35 or -0.35), 3.4, z + 0.18),
			Color3.fromRGB(200, 200, 196), M.Metal)
	end

	if label then
		for _, sx in ipairs({ -1, 1 }) do
			local p = Vector3.new(sx * (W / 2 + 0.12), H * 0.62, 0)
			b:sign(label, Kit.Look(p, p + Vector3.new(sx, 0, 0)), math.min(length * 0.62, 15), 2.6,
				Color3.new(1, 1, 1), { lit = true, glow = false, font = Enum.Font.GothamBlack,
					textColour = Color3.fromRGB(240, 240, 236), brightness = 1 })
		end
	end
end

--- Yellow bay lines painted round a footprint.
local function bay(b: Kit.Builder, at: Vector3, sizeX: number, sizeZ: number)
	local w = 0.35
	for _, s in ipairs({ -1, 1 }) do
		b:decor("Bay", Vector3.new(sizeX + w, 0.04, w), at + Vector3.new(0, 0.02, s * sizeZ / 2), YELLOW)
		b:decor("Bay", Vector3.new(w, 0.04, sizeZ + w), at + Vector3.new(s * sizeX / 2, 0.02, 0), YELLOW)
	end
end

--- A concrete jersey barrier, 10 long along X.
local function jersey(b: Kit.Builder, accent: Color3)
	b:part("Barrier", Vector3.new(10, 1.1, 2.4), Vector3.new(0, 0.55, 0), CONCRETE_LIGHT, M.Concrete)
	b:part("Barrier", Vector3.new(10, 2.3, 1.1), Vector3.new(0, 2.25, 0), CONCRETE_LIGHT, M.Concrete)
	for _, s in ipairs({ -1, 1 }) do
		b:part("Slope", Vector3.new(10, 0.9, 0.65),
			CFrame.new(0, 1.55, s * 0.875) * CFrame.Angles(0, s == 1 and math.pi or 0, 0),
			CONCRETE_LIGHT, M.Concrete, { shape = "Wedge" })
	end
	b:decor("Cap", Vector3.new(10.02, 0.14, 1.12), Vector3.new(0, 3.43, 0), accent)
	-- Lifting slots at the foot, which is what makes a barrier read as a barrier.
	for _, x in ipairs({ -3, 3 }) do
		b:decor("Slot", Vector3.new(1.6, 0.5, 2.44), Vector3.new(x, 0.25, 0), darker(CONCRETE_LIGHT, 0.45))
	end
end

local function drum(b: Kit.Builder, at: CFrame, colour: Color3)
	local d = b:within(at)
	d:part("Drum", Vector3.new(3.4, 2.4, 2.4), vertical(Vector3.new(0, 1.7, 0)), colour, M.Metal, { shape = "Cylinder" })
	for _, y in ipairs({ 1.15, 2.3 }) do
		d:decor("Hoop", Vector3.new(0.16, 2.52, 2.52), vertical(Vector3.new(0, y, 0)), darker(colour, 0.25), M.Metal,
			{ shape = "Cylinder" })
	end
	d:decor("Lid", Vector3.new(0.06, 2.2, 2.2), vertical(Vector3.new(0, 3.42, 0)), darker(colour, 0.35), M.Metal,
		{ shape = "Cylinder" })
end

local function drums(b: Kit.Builder)
	local BLUE = Color3.fromRGB(38, 92, 168)
	local RED = Color3.fromRGB(176, 52, 40)
	drum(b, CFrame.new(-1.35, 0, -0.9), BLUE)
	drum(b, CFrame.new(1.35, 0, -0.9), RED)
	drum(b, CFrame.new(0, 0, 1.35), BLUE)
	-- One on its side, rolled up against the others.
	local lying = b:within(CFrame.new(3.5, 0, 2.2) * CFrame.Angles(0, math.rad(90), 0))
	lying:part("Drum", Vector3.new(3.4, 2.4, 2.4), CFrame.new(0, 1.2, 0), RED, M.Metal, { shape = "Cylinder" })
	for _, x in ipairs({ -0.55, 0.6 }) do
		lying:decor("Hoop", Vector3.new(0.16, 2.52, 2.52), CFrame.new(x, 1.2, 0), darker(RED, 0.25), M.Metal,
			{ shape = "Cylinder" })
	end
end

local function crate(b: Kit.Builder, at: Vector3)
	local c = b:within(CFrame.new(at))
	local s = 3.6
	c:part("Crate", Vector3.new(s, s, s), Vector3.new(0, s / 2, 0), WOOD, M.WoodPlanks)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			c:decor("Post", Vector3.new(0.42, s + 0.04, 0.42), Vector3.new(sx * (s / 2 - 0.19), s / 2, sz * (s / 2 - 0.19)),
				WOOD_DARK, M.Wood)
		end
	end
	for _, y in ipairs({ 0.22, s - 0.22 }) do
		for _, sx in ipairs({ -1, 1 }) do
			c:decor("Band", Vector3.new(0.44, 0.44, s + 0.04), Vector3.new(sx * (s / 2 - 0.2), y, 0), WOOD_DARK, M.Wood)
			c:decor("Band", Vector3.new(s + 0.04, 0.44, 0.44), Vector3.new(0, y, sx * (s / 2 - 0.2)), WOOD_DARK, M.Wood)
		end
	end
end

local function pallet(b: Kit.Builder, at: Vector3)
	b:part("Pallet", Vector3.new(4.6, 0.22, 4.6), at + Vector3.new(0, 0.39, 0), WOOD, M.Wood)
	for _, x in ipairs({ -1.9, 0, 1.9 }) do
		b:part("Skid", Vector3.new(0.6, 0.28, 4.6), at + Vector3.new(x, 0.14, 0), WOOD_DARK, M.Wood)
	end
end

--- Two pallets of crates: one stacked two high, one a single crate with a box on top.
local function crates(b: Kit.Builder)
	pallet(b, Vector3.new(-2.5, 0, 0))
	pallet(b, Vector3.new(2.5, 0, 0))
	crate(b, Vector3.new(-2.5, 0.5, 0))
	crate(b, Vector3.new(-2.5, 4.1, 0))
	crate(b, Vector3.new(2.5, 0.5, 0))
	b:part("Box", Vector3.new(2.4, 1.8, 2.4), Vector3.new(2.3, 5.0, 0.2), Color3.fromRGB(190, 152, 104), M.Cardboard)
	b:decor("Tape", Vector3.new(2.42, 0.06, 0.5), Vector3.new(2.3, 5.91, 0.2), Color3.fromRGB(214, 190, 140))
end

--- A forklift, forks toward -Z, carrying a boxed pallet.
local function forklift(b: Kit.Builder)
	local GREY_DARK = Color3.fromRGB(58, 58, 62)
	b:part("Chassis", Vector3.new(4.2, 1.6, 6), Vector3.new(0, 1.6, 0), YELLOW, M.SmoothPlastic)
	b:part("Weight", Vector3.new(4.2, 2.6, 1.4), Vector3.new(0, 2.2, 3.4), GREY_DARK, M.Metal)
	b:part("Hood", Vector3.new(4, 1.1, 2.4), Vector3.new(0, 2.95, 1.8), YELLOW, M.SmoothPlastic)
	b:decor("Seat", Vector3.new(1.8, 0.4, 1.6), Vector3.new(0, 2.6, 0), BLACK, M.Fabric)
	b:decor("SeatBack", Vector3.new(1.8, 1.6, 0.4), Vector3.new(0, 3.4, 0.7), BLACK, M.Fabric)
	for _, x in ipairs({ -1.95, 1.95 }) do
		for _, z in ipairs({ -1.6, 2.2 }) do
			b:decor("Guard", Vector3.new(0.28, 4.4, 0.28), Vector3.new(x, 4.6, z), GREY_DARK, M.Metal)
		end
		b:part("Mast", Vector3.new(0.5, 8.4, 0.5), Vector3.new(x * 0.62, 4.6, -3.3), GREY_DARK, M.Metal)
		b:part("Wheel", Vector3.new(0.9, 2.2, 2.2), Vector3.new(x * 1.08, 1.1, -1.7), BLACK, M.Rubber,
			{ shape = "Cylinder" })
		b:part("Wheel", Vector3.new(0.9, 1.8, 1.8), Vector3.new(x * 1.08, 0.9, 2.5), BLACK, M.Rubber,
			{ shape = "Cylinder" })
	end
	b:decor("Roof", Vector3.new(4.2, 0.3, 4.2), Vector3.new(0, 6.9, 0.3), GREY_DARK, M.DiamondPlate)
	b:decor("Beacon", Vector3.new(0.5, 0.5, 0.5), Vector3.new(0, 7.3, 1.8), SIDE[1], M.Neon)
	b:decor("MastBar", Vector3.new(1.9, 0.4, 0.4), Vector3.new(0, 8.6, -3.3), GREY_DARK, M.Metal)
	b:decor("Carriage", Vector3.new(3.4, 1.4, 0.3), Vector3.new(0, 1.3, -3.75), GREY_DARK, M.Metal)
	for _, x in ipairs({ -0.9, 0.9 }) do
		b:decor("Fork", Vector3.new(0.5, 0.2, 4.2), Vector3.new(x, 0.5, -5.9), GREY_DARK, M.Metal)
	end
	b:decor("Wheel", Vector3.new(0.14, 1, 1), CFrame.new(0, 3.9, -1.1) * CFrame.Angles(0, math.rad(90), math.rad(55)),
		BLACK, M.Rubber, { shape = "Cylinder" })
	-- The load.
	b:part("Pallet", Vector3.new(3.8, 0.35, 3.8), Vector3.new(0, 0.78, -6), WOOD, M.Wood)
	b:part("Load", Vector3.new(3.2, 2.6, 3.2), Vector3.new(0, 2.25, -6), Color3.fromRGB(190, 152, 104), M.Cardboard)
	b:decor("Wrap", Vector3.new(3.26, 0.5, 3.26), Vector3.new(0, 2.6, -6), Color3.fromRGB(220, 226, 230), M.Glass,
		{ transparency = 0.4 })
end

--- Interlocking concrete blocks: three along the bottom, two on top, studs showing.
local function blocks(b: Kit.Builder)
	local c = Color3.fromRGB(162, 158, 150)
	for _, z in ipairs({ -5, 0, 5 }) do
		b:part("Block", Vector3.new(2.5, 2.5, 5), Vector3.new(0, 1.25, z), c, M.Concrete)
	end
	for _, z in ipairs({ -2.5, 2.5 }) do
		b:part("Block", Vector3.new(2.5, 2.5, 5), Vector3.new(0, 3.75, z), darker(c, 0.06), M.Concrete)
	end
	for _, z in ipairs({ -6.25, 6.25 }) do
		b:decor("Stud", Vector3.new(0.35, 1.2, 1.2), vertical(Vector3.new(0, 2.67, z)), c, M.Concrete, { shape = "Cylinder" })
	end
	for _, z in ipairs({ -3.75, -1.25, 1.25, 3.75 }) do
		b:decor("Stud", Vector3.new(0.35, 1.2, 1.2), vertical(Vector3.new(0, 5.17, z)), c, M.Concrete, { shape = "Cylinder" })
	end
end

--- A sodium street lamp whose arm reaches toward -X.
local function lamp(b: Kit.Builder, shadows: boolean)
	b:part("Plinth", Vector3.new(1.6, 1.2, 1.6), Vector3.new(0, 0.6, 0), CONCRETE_LIGHT, M.Concrete)
	b:part("Pole", Vector3.new(23, 0.7, 0.7), vertical(Vector3.new(0, 12.7, 0)), STEEL_DARK, M.Metal, { shape = "Cylinder" })
	b:decor("Arm", Vector3.new(4, 0.35, 0.35), Vector3.new(-1.8, 24, 0), STEEL_DARK, M.Metal)
	b:decor("Head", Vector3.new(2.8, 0.6, 1.4), Vector3.new(-3.6, 23.9, 0), STEEL_DARK, M.Metal)
	b:neon("Lens", Vector3.new(2.4, 0.1, 1.1), Vector3.new(-3.6, 23.56, 0), SODIUM)
	b:light("Spot", CFrame.new(-3.6, 23.3, 0) * CFrame.Angles(-math.pi / 2, 0, 0), SODIUM, 2.4, 46,
		{ Angle = 120, Shadows = shadows })
end

local function hazard(b: Kit.Builder, at: Vector3, size: Vector3, segments: number)
	-- Alternating yellow and black bands up a post (size.Y is split).
	local h = size.Y / segments
	for i = 0, segments - 1 do
		b:decor("Hazard", Vector3.new(size.X, h, size.Z), at + Vector3.new(0, -size.Y / 2 + h * (i + 0.5), 0),
			i % 2 == 0 and YELLOW or BLACK)
	end
end

-- -------------------------------------------------------------- set pieces --

--- The warehouse front closing off one end. Origin on the end line; the face looks +Z.
local function warehouse(b: Kit.Builder, side: number)
	local accent = SIDE[side]
	local W, H = Map.HalfWidth * 2, 34
	b:part("Wall", Vector3.new(W, H, 3), Vector3.new(0, H / 2 - 1, -2.5), STEEL, M.Metal)
	b:part("Parapet", Vector3.new(W + 1, 1.2, 4), Vector3.new(0, H - 0.8, -2.5), STEEL_DARK, M.Metal)
	b:decor("Roof", Vector3.new(W, 1, 40), Vector3.new(0, H - 1.5, -21), STEEL, M.Metal)
	for _, sx in ipairs({ -1, 1 }) do
		b:part("SideWall", Vector3.new(2, H, 40), Vector3.new(sx * (W / 2 - 1), H / 2 - 1, -21), STEEL, M.Metal)
	end

	-- Cladding ribs, skipping the door and the sign.
	for x = -W / 2 + 1.5, W / 2 - 1.5, 2.6 do
		if math.abs(x) > 14 then
			b:decor("Rib", Vector3.new(0.6, H - 2, 0.45), Vector3.new(x, H / 2 - 1, -0.8), darker(STEEL, 0.14), M.Metal)
		else
			b:decor("Rib", Vector3.new(0.6, 5.2, 0.45), Vector3.new(x, H - 4.6, -0.8), darker(STEEL, 0.14), M.Metal)
		end
	end
	-- Structural columns, proud of the cladding.
	for _, x in ipairs({ -32, 32 }) do
		b:decor("Column", Vector3.new(3, H, 1.4), Vector3.new(x, H / 2 - 1, -0.4), STEEL_DARK, M.Metal)
		hazard(b, Vector3.new(x, 2.5, 0.33), Vector3.new(3.04, 5, 0.1), 6)
	end

	-- The roller door, its frame striped, and the slats across it.
	b:decor("Door", Vector3.new(24, 20, 0.3), Vector3.new(0, 10, -0.9), DOOR, M.Metal)
	for y = 1.2, 19.2, 1.25 do
		b:decor("Slat", Vector3.new(24, 0.12, 0.1), Vector3.new(0, y, -0.7), darker(DOOR, 0.22), M.Metal)
	end
	b:decor("Seal", Vector3.new(24, 0.4, 0.4), Vector3.new(0, 0.2, -0.6), BLACK, M.Rubber)
	for _, sx in ipairs({ -1, 1 }) do
		hazard(b, Vector3.new(sx * 12.7, 10.5, -0.5), Vector3.new(1.4, 21, 1), 10)
	end
	b:decor("Header", Vector3.new(26.8, 1.4, 1), Vector3.new(0, 21.6, -0.5), STEEL_DARK, M.Metal)

	-- Number board: a dark panel with white stencil lettering, a strip of the side's colour.
	b:decor("Board", Vector3.new(30, 7, 0.4), Vector3.new(0, 27.4, -0.5), Color3.fromRGB(24, 28, 34), M.SmoothPlastic)
	b:sign(side == 1 and "DOCK 01" or "DOCK 02", CFrame.new(0, 27.6, -0.25) * CFrame.Angles(0, math.pi, 0), 27, 5.6, Color3.new(1, 1, 1),
		{ glow = false, font = Enum.Font.GothamBlack, textColour = Color3.fromRGB(246, 246, 240), brightness = 1.6 })
	b:neon("Strip", Vector3.new(30, 0.3, 0.2), Vector3.new(0, 23.75, -0.25), accent)

	-- A painted band in the side's colour at waist height, both sides of the door.
	for _, sx in ipairs({ -1, 1 }) do
		b:decor("Band", Vector3.new(W / 2 - 14, 1.4, 0.12), Vector3.new(sx * (14 + (W / 2 - 14) / 2), 4.4, -0.52),
			accent, M.SmoothPlastic)
	end

	-- Lit windows high on the wall.
	for _, sx in ipairs({ -1, 1 }) do
		for i = 0, 2 do
			local x = sx * (19 + i * 4.3)
			b:decor("Window", Vector3.new(3.4, 2.4, 0.2), Vector3.new(x, 27.5, -0.45), darker(STEEL, 0.5))
			b:neon("Glow", Vector3.new(3, 2, 0.1), Vector3.new(x, 27.5, -0.34), WARM_WINDOW, 0.25)
		end
		for i = 0, 1 do
			local x = sx * (38.5 + i * 4.3)
			b:decor("Window", Vector3.new(3.4, 2.4, 0.2), Vector3.new(x, 27.5, -0.45), darker(STEEL, 0.5))
			b:neon("Glow", Vector3.new(3, 2, 0.1), Vector3.new(x, 27.5, -0.34), WARM_WINDOW, 0.25)
		end
	end

	-- Wall packs either side of the door, washing the spawn in warm light.
	for _, sx in ipairs({ -1, 1 }) do
		local x = sx * 18
		b:decor("WallPack", Vector3.new(2.2, 1.2, 1.4), Vector3.new(x, 21, -0.4), STEEL_DARK, M.Metal)
		b:neon("Lens", Vector3.new(1.8, 0.1, 1), Vector3.new(x, 20.38, -0.3), WARM_WINDOW)
		b:light("Spot", Kit.Look(Vector3.new(x, 20.2, 0.2), Vector3.new(x, 0, 16)), WARM_WINDOW, 2, 38,
			{ Angle = 95 })
	end

	-- A pedestrian door and a fire extinguisher sign, off to one side.
	b:decor("ManDoor", Vector3.new(4, 7.5, 0.3), Vector3.new(-22, 3.75, -0.3), darker(DOOR, 0.3), M.Metal)
	b:decor("DoorFrame", Vector3.new(4.8, 8, 0.2), Vector3.new(-22, 4, -0.4), STEEL_DARK, M.Metal)
	b:decor("ExitSign", Vector3.new(2.4, 0.9, 0.2), Vector3.new(-22, 8.8, -0.475), Color3.fromRGB(40, 190, 90), M.Neon)
end

--- The long edge of the quay (the +X side as written): capping beam, face, fenders,
--- bollards, and the water beyond.
local function quayEdge(b: Kit.Builder)
	local L = Map.HalfLength * 2 + 8
	local x = Map.HalfWidth
	b:part("Capping", Vector3.new(1.6, 0.8, L), Vector3.new(x - 0.8, 0.4, 0), CONCRETE_LIGHT, M.Concrete)
	b:decor("EdgePaint", Vector3.new(1.62, 0.06, L), Vector3.new(x - 0.8, 0.82, 0), YELLOW)
	b:part("QuayFace", Vector3.new(1.2, 9, L), Vector3.new(x + 0.6, -5.5, 0), QUAY_FACE, M.Concrete)
	for z = -60, 60, 20 do
		b:decor("Fender", Vector3.new(4.5, 1.9, 1.9), CFrame.new(x + 2.1, -3.2, z) * CFrame.Angles(0, math.rad(90), 0),
			BLACK, M.Rubber, { shape = "Cylinder" })
	end
	for _, z in ipairs({ -44, -14, 16, 46 }) do
		b:part("Bollard", Vector3.new(1.4, 1.2, 1.2), vertical(Vector3.new(x - 3, 0.7, z)), BLACK, M.Metal,
			{ shape = "Cylinder" })
		b:decor("BollardCap", Vector3.new(0.4, 1.8, 1.8), vertical(Vector3.new(x - 3, 1.5, z)), BLACK, M.Metal,
			{ shape = "Cylinder" })
		b:decor("BollardBand", Vector3.new(0.3, 1.24, 1.24), vertical(Vector3.new(x - 3, 0.9, z)), YELLOW, M.SmoothPlastic,
			{ shape = "Cylinder" })
	end
	-- Mooring lines from the two middle bollards out to the ship.
	for _, z in ipairs({ -14, 16 }) do
		local from = Vector3.new(x - 3, 1.3, z)
		local to = Vector3.new(73, 5.5, z + (z < 0 and -12 or 12))
		local cf, len = Kit.Span(from, to)
		b:decor("Rope", Vector3.new(0.3, 0.3, len), cf, Color3.fromRGB(208, 194, 158), M.Fabric)
	end

	b:decor("Water", Vector3.new(300, 1, 820), Vector3.new(x + 150, -7.5, 0), WATER, M.SmoothPlastic,
		{ reflectance = 0.18, transparency = 0.05 })
end

--- A container ship moored beyond the water. Origin on the hull's centre line.
local function ship(b: Kit.Builder)
	local HULL = Color3.fromRGB(30, 42, 62)
	local ANTIFOUL = Color3.fromRGB(150, 44, 38)
	b:decor("Hull", Vector3.new(28, 12, 140), Vector3.new(0, 0, 0), HULL, M.Metal)
	b:decor("Boot", Vector3.new(28.1, 3, 140.1), Vector3.new(0, -6, 0), ANTIFOUL, M.Metal)
	b:decor("Stripe", Vector3.new(28.12, 0.5, 140.12), Vector3.new(0, 4.4, 0), WHITE)
	-- The bow: two wedges laid flat meet in a point.
	for _, sx in ipairs({ -1, 1 }) do
		b:decor("Bow", Vector3.new(15, 14, 22),
			CFrame.new(sx * 7, -1, -81) * CFrame.Angles(0, 0, math.rad(-sx * 90)),
			HULL, M.Metal, { shape = "Wedge" })
	end
	b:decor("Deck", Vector3.new(27.6, 0.4, 140), Vector3.new(0, 6.2, 0), Color3.fromRGB(96, 54, 48), M.Metal)

	-- Containers on deck, stepped up toward the middle.
	local tiers = { { 2, 3, 3, 3, 2 }, { 3, 4, 4, 4, 3 }, { 2, 3, 3, 3, 2 } }
	local bays = { -52, -30, -8, 14, 36 }
	for r, x in ipairs({ -8.6, 0, 8.6 }) do
		for i, z in ipairs(bays) do
			for t = 1, tiers[r][i] do
				local colour = PALETTE[(r * 3 + i * 5 + t * 2) % #PALETTE + 1]
				b:decor("Box", Vector3.new(8.2, 8.4, 20), Vector3.new(x, 6.4 + (t - 0.5) * 8.6, z), colour, M.Metal)
			end
		end
	end

	-- The accommodation block and funnel at the stern.
	b:decor("House", Vector3.new(24, 20, 12), Vector3.new(0, 16.4, 60), WHITE, M.SmoothPlastic)
	b:decor("Bridge", Vector3.new(30, 4, 10), Vector3.new(0, 28.4, 58), WHITE, M.SmoothPlastic)
	for y = 10, 26, 4 do
		b:decor("Windows", Vector3.new(24.1, 1.2, 12.1), Vector3.new(0, y, 60), Color3.fromRGB(40, 50, 64), M.Glass)
	end
	b:neon("BridgeGlass", Vector3.new(30.1, 1.4, 10.1), Vector3.new(0, 28.8, 58), WARM_WINDOW, 0.35)
	b:decor("Funnel", Vector3.new(7, 12, 7), Vector3.new(0, 35, 64), Color3.fromRGB(40, 40, 44), M.Metal)
	b:decor("FunnelBand", Vector3.new(7.1, 3, 7.1), Vector3.new(0, 36, 64), SIDE[1])
	b:neon("MastLight", Vector3.new(0.6, 0.6, 0.6), Vector3.new(0, 41.3, 64), Color3.fromRGB(255, 70, 60))
	b:decor("Mast", Vector3.new(0.4, 16, 0.4), Vector3.new(0, 14, -66), Color3.fromRGB(200, 200, 196), M.Metal)
	b:neon("MastLight", Vector3.new(0.5, 0.5, 0.5), Vector3.new(0, 22.2, -66), Color3.fromRGB(255, 244, 220))
end

--- A ship-to-shore crane on the far quay, its boom reaching out over the ship (-X).
local function stsCrane(b: Kit.Builder)
	local legH = 50
	for _, x in ipairs({ -12, 12 }) do
		for _, z in ipairs({ -10, 10 }) do
			b:decor("Leg", Vector3.new(2.4, legH, 2.4), Vector3.new(x, legH / 2, z), STS, M.Metal)
		end
		b:decor("Sill", Vector3.new(2.6, 2.4, 22.4), Vector3.new(x, legH - 1.2, 0), STS, M.Metal)
		b:decor("Tie", Vector3.new(2, 1.6, 20), Vector3.new(x, 18, 0), STS, M.Metal)
		b:decor("Bogie", Vector3.new(3, 2.2, 5), Vector3.new(x, 1.1, -10), Color3.fromRGB(50, 50, 54), M.Metal)
		b:decor("Bogie", Vector3.new(3, 2.2, 5), Vector3.new(x, 1.1, 10), Color3.fromRGB(50, 50, 54), M.Metal)
	end
	for _, z in ipairs({ -10, 10 }) do
		b:decor("Portal", Vector3.new(26.4, 3, 2.6), Vector3.new(0, legH - 1.5, z), STS, M.Metal)
	end
	-- Boom: two girders from the backreach out over the water.
	for _, z in ipairs({ -3.4, 3.4 }) do
		b:decor("Boom", Vector3.new(104, 3.4, 2), Vector3.new(-22, legH + 3, z), WHITE, M.Metal)
	end
	b:decor("MachineHouse", Vector3.new(16, 7, 12), Vector3.new(20, legH + 8.2, 0), WHITE, M.Metal)
	-- A-frame apex and the stays down to the boom tip.
	for _, z in ipairs({ -8, 8 }) do
		local foot = Vector3.new(0, legH + 1, z)
		local apex = Vector3.new(4, legH + 30, z * 0.35)
		local cf, len = Kit.Span(foot, apex)
		b:decor("Apex", Vector3.new(1.6, 1.6, len), cf, STS, M.Metal)
		local tip = Vector3.new(-72, legH + 4.5, z * 0.4)
		local cf2, len2 = Kit.Span(apex, tip)
		b:decor("Stay", Vector3.new(0.5, 0.5, len2), cf2, Color3.fromRGB(60, 60, 64), M.Metal)
	end
	-- A tie across the two apexes, which the beacon sits on (it hung in the air between them).
	b:decor("ApexTie", Vector3.new(1.2, 1.2, 6.8), Vector3.new(4, legH + 30, 0), STS, M.Metal)
	b:neon("Beacon", Vector3.new(1, 1, 1), Vector3.new(4, legH + 31, 0), Color3.fromRGB(255, 60, 50))
	-- The trolley and its spreader, lowered to the ship.
	b:decor("Trolley", Vector3.new(8, 3, 9), Vector3.new(-34, legH + 0.5, 0), Color3.fromRGB(60, 60, 64), M.Metal)
	for _, z in ipairs({ -2, 2 }) do
		local cf, len = Kit.Span(Vector3.new(-34, legH - 1, z), Vector3.new(-34, 46, z))
		b:decor("Hoist", Vector3.new(0.25, 0.25, len), cf, Color3.fromRGB(40, 40, 42), M.Metal)
	end
	b:decor("Spreader", Vector3.new(8.4, 1, 20), Vector3.new(-34, 45.5, 0), CRANE, M.Metal)
end

--- The rail gantry spanning the centre, with a box hanging from it. Symmetric by itself.
local function gantry(root: Kit.Builder)
	local top = 31.5
	for _, z in ipairs({ -3.2, 3.2 }) do
		root:part("Girder", Vector3.new(Map.HalfWidth * 2 - 1, 3, 1.6), Vector3.new(0, top, z), CRANE, M.Metal)
	end
	for _, x in ipairs({ -30, -15, 0, 15, 30 }) do
		root:decor("Tie", Vector3.new(1.2, 1, 6.4), Vector3.new(x, top + 1.95, 0), CRANE, M.Metal)
	end
	root:decor("Trolley", Vector3.new(9, 3, 9.5), Vector3.new(0, top + 3, 0), Color3.fromRGB(62, 64, 70), M.Metal)
	for _, x in ipairs({ -2.6, 2.6 }) do
		for _, z in ipairs({ -2, 2 }) do
			local cf, len = Kit.Span(Vector3.new(x, top - 1.5, z), Vector3.new(x, 27.6, z))
			root:decor("Hoist", Vector3.new(0.2, 0.2, len), cf, Color3.fromRGB(34, 34, 36), M.Metal)
		end
	end
	root:part("Spreader", Vector3.new(20.4, 0.8, 8.4), Vector3.new(0, 27.2, 0), CRANE, M.Metal)
	container(root:within(CFrame.new(0, 18.2, 0) * CFrame.Angles(0, math.rad(90), 0)), 20, GREY, "ZEE LINE")
	-- Work lights under the girders, onto the centre.
	for _, x in ipairs({ -16, 16 }) do
		root:decor("Flood", Vector3.new(2, 1, 1.6), Vector3.new(x, top - 2, 0), Color3.fromRGB(50, 52, 58), M.Metal)
		root:neon("FloodLens", Vector3.new(1.6, 0.1, 1.2), Vector3.new(x, top - 2.55, 0), Color3.fromRGB(255, 240, 214))
		root:light("Spot", CFrame.new(x, top - 2.8, 0) * CFrame.Angles(-math.pi / 2, 0, 0),
			Color3.fromRGB(255, 236, 206), 1.6, 40, { Angle = 100, Shadows = x < 0 })
	end
end

--- One side's gantry leg frame (at +X as written).
local function gantryLegs(b: Kit.Builder)
	local x = Map.HalfWidth - 3
	for _, z in ipairs({ -3.2, 3.2 }) do
		b:part("Leg", Vector3.new(1.8, 30.5, 1.8), Vector3.new(x, 15.25 + 1.2, z), CRANE, M.Metal)
		hazard(b, Vector3.new(x, 4.2, z), Vector3.new(1.84, 5, 1.84), 6)
	end
	b:part("Bogie", Vector3.new(2.6, 1.4, 11), Vector3.new(x, 0.7, 0), Color3.fromRGB(56, 58, 62), M.Metal)
	-- The rail it runs on, set into the quay the whole length of the map.
	b:decor("RailBed", Vector3.new(1.6, 0.04, Map.HalfLength * 2), Vector3.new(x, 0.02, 0), Color3.fromRGB(88, 86, 82),
		M.Concrete)
	b:decor("Rail", Vector3.new(0.45, 0.22, Map.HalfLength * 2), Vector3.new(x, 0.11, 0), Color3.fromRGB(150, 150, 154),
		M.Metal)
	for _, z in ipairs({ -4, -1.4, 1.4, 4 }) do
		b:decor("Wheel", Vector3.new(2.7, 1.3, 1.3), Vector3.new(x, 0.5, z), BLACK, M.Metal, { shape = "Cylinder" })
	end
	-- X-bracing between the legs.
	for _, s in ipairs({ -1, 1 }) do
		local cf, len = Kit.Span(Vector3.new(x, 4, s * 3.2), Vector3.new(x, 28, -s * 3.2))
		b:decor("Brace", Vector3.new(0.6, 0.6, len), cf, darker(CRANE, 0.12), M.Metal)
	end
	-- The operator's cab under the girder.
	b:decor("Cab", Vector3.new(4.4, 3.6, 4), Vector3.new(x - 6, 28, 0), Color3.fromRGB(230, 230, 224), M.SmoothPlastic)
	b:decor("CabGlass", Vector3.new(4.5, 1.6, 4.1), Vector3.new(x - 6, 28.4, 0), Color3.fromRGB(40, 60, 80), M.Glass,
		{ transparency = 0.2 })
end

--- The far quay across the water: a crane over the ship and a stacked yard behind it.
local function farQuay(b: Kit.Builder)
	b:decor("FarQuay", Vector3.new(230, 3, 820), Vector3.new(104 + 115, -1.5, 0), CONCRETE, M.Concrete)
	b:decor("FarFace", Vector3.new(1, 7, 820), Vector3.new(104, -5, 0), QUAY_FACE, M.Concrete)
	stsCrane(b:within(CFrame.new(124, 0, -24)))
	stsCrane(b:within(CFrame.new(124, 0, 44)))

	-- The stacked yard: neat rows of boxes, stepped heights, never random.
	local heights = { 2, 3, 2, 4, 3, 2, 3, 4, 2, 3, 3 }
	for r, x in ipairs({ 160, 168.6, 185, 193.6 }) do
		for i = 1, #heights do
			local z = -115 + (i - 1) * 23
			local h = heights[(i + r) % #heights + 1]
			for t = 1, h do
				local colour = PALETTE[(i * 2 + r + t * 3) % #PALETTE + 1]
				b:decor("Stack", Vector3.new(8.2, 8.4, 20), Vector3.new(x, (t - 0.5) * 8.6, z), colour, M.Metal)
			end
		end
	end
	-- Light towers over the yard.
	for _, z in ipairs({ -90, 0, 90 }) do
		b:decor("Mast", Vector3.new(1.4, 70, 1.4), Vector3.new(176, 35, z), Color3.fromRGB(150, 152, 150), M.Metal)
		b:decor("MastHead", Vector3.new(8, 3, 1.6), Vector3.new(176, 70, z), Color3.fromRGB(60, 62, 66), M.Metal)
		b:neon("Lamps", Vector3.new(7.4, 2.2, 0.2), Vector3.new(175.1, 70, z), Color3.fromRGB(255, 226, 170))
	end
end

-- ------------------------------------------------------------------- build --

function Map.Build(parent: Instance, centre: Vector3)
	local root = Kit.new(parent, CFrame.new(centre))
	local HW, HL = Map.HalfWidth, Map.HalfLength

	Kit.Bounds(root, HW, HL, Map.Height)

	-- The quay: one slab, with expansion joints scored across it every sixteen studs.
	root:part("Quay", Vector3.new(HW * 2, 2, HL * 2 + 8), Vector3.new(0, -1, 0), CONCRETE, M.Concrete)
	for z = -48, 48, 16 do
		root:decor("Joint", Vector3.new(HW * 2 - 2, 0.04, 0.25), Vector3.new(0, 0.02, z), JOINT, M.Concrete)
	end
	for x = -32, 32, 16 do
		root:decor("Joint", Vector3.new(0.25, 0.04, HL * 2), Vector3.new(x, 0.02, 0), JOINT, M.Concrete)
	end

	-- The centre: a KEEP CLEAR box painted under the hanging load.
	bay(root, Vector3.new(0, 0, 0), 19, 11)
	for _, side in ipairs({ 1, 2 }) do
		local z = side == 1 and -7.6 or 7.6
		local p = Vector3.new(0, 0.05, z)
		local board = root:decor("Paint", Vector3.new(16, 0.04, 3.2), p, CONCRETE, nil, { transparency = 1 })
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Top
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 12
		gui.LightInfluence = 1
		gui.Parent = board
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Rotation = side == 1 and 180 or 0
		label.Text = "KEEP CLEAR"
		label.TextScaled = true
		label.Font = Enum.Font.GothamBlack
		label.TextColor3 = YELLOW
		label.Parent = gui
	end

	gantry(root)

	Kit.Both(root, function(b, side)
		local accent = SIDE[side]

		warehouse(b:within(CFrame.new(0, 0, -HL)), side)
		quayEdge(b)
		ship(b:within(CFrame.new(86, 0, 0)))
		farQuay(b)
		gantryLegs(b)

		-- Spawn: a ring on the floor, two barriers in front of it.
		Kit.SpawnPad(b, Vector3.new(0, 0, -58), accent)
		jersey(b:within(CFrame.new(-9, 0, -46)), accent)
		jersey(b:within(CFrame.new(9, 0, -46)), accent)

		-- Left lane: a 40ft box, doors toward the spawn.
		bay(b, Vector3.new(-32, 0, -28), 9.4, 41.4)
		container(b:within(CFrame.new(-32, 0, -28) * CFrame.Angles(0, math.pi, 0)), 40, RUST, "ZEE LINE")

		-- Right lane: a two-high stack across the lane, a forklift parked behind it.
		bay(b, Vector3.new(26, 0, -36), 21.4, 9.4)
		container(b:within(CFrame.new(26, 0, -36) * CFrame.Angles(0, math.rad(90), 0)), 20, NAVY, "ZEE LINE")
		container(b:within(CFrame.new(26, 8.6, -36) * CFrame.Angles(0, math.rad(-90), 0)), 20, TEAL, "OCEANIC")
		forklift(b:within(CFrame.new(24, 0, -52) * CFrame.Angles(0, math.rad(-30), 0)))

		-- Middle: one box beside the centre line, crates and blocks on the approaches.
		bay(b, Vector3.new(-14, 0, -5), 9.4, 21.4)
		container(b:within(CFrame.new(-14, 0, -5)), 20, MUSTARD, "PORT ZEE")
		crates(b:within(CFrame.new(12, 0, -24)))
		-- A short barrier across the centre line, so spawn never sees spawn standing up.
		b:part("Barrier", Vector3.new(7, 1.1, 2.4), Vector3.new(-2, 0.55, -24), CONCRETE_LIGHT, M.Concrete)
		b:part("Barrier", Vector3.new(7, 2.3, 1.1), Vector3.new(-2, 2.25, -24), CONCRETE_LIGHT, M.Concrete)
		for _, s in ipairs({ -1, 1 }) do
			b:part("Slope", Vector3.new(7, 0.9, 0.65),
				CFrame.new(-2, 1.55, -24 + s * 0.875) * CFrame.Angles(0, s == 1 and math.pi or 0, 0),
				CONCRETE_LIGHT, M.Concrete, { shape = "Wedge" })
		end
		b:decor("Cap", Vector3.new(7.02, 0.14, 1.12), Vector3.new(-2, 3.43, -24), accent)
		blocks(b:within(CFrame.new(34, 0, -12)))
		drums(b:within(CFrame.new(-19, 0, -54)))

		lamp(b:within(CFrame.new(HW - 3.2, 0, -40)), side == 1)
		lamp(b:within(CFrame.new(HW - 3.2, 0, 20)), false)
	end)
end

return Map
