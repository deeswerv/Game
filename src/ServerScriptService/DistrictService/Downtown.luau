--!strict
-- DOWNTOWN: a city district, built block by block.
--
-- A grid, laid out the way a real downtown is and nothing placed at random:
--
--   * An avenue runs north from the travel gate (south) to ZEE TOWER (north); a cross
--     street runs east-west. Where they meet is ZEE PLAZA, pedestrianised: tiled paving, a
--     fountain, and a four-sided screen tower in the middle.
--   * South-east: ZEE GUNS and the ARMORY, storefronts on the avenue (the shop and the
--     armory panels open at their doors).
--   * South-west: ZEE GAS -- canopy, pumps, and the 24/7 store with the CONTRACTS board.
--   * North-west: the DUEL HALL, 1v1 pads under a marquee.
--   * North-east: a basketball court, and an apartment block whose fire escape climbs to a
--     rooftop stash.
--   * Around it all, a ring of taller buildings and a skyline, so there is no edge to see.
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
-- Where the travel pad sits (the gate home stands on its south side).
Downtown.Arrival = Vector3.new(0, 0.5, -172)
-- Where supply drops may land: open paving only.
Downtown.DropRadius = 150

-- Cameras for tools/mapview (local coordinates).
Downtown.Preview = {
	{ pos = { 150, 190, -230 }, look = { 0, 0, 20 }, fov = 60 },
	{ pos = { 0, 5, -168 }, look = { 0, 8, 0 }, fov = 70 },
	{ pos = { 0, 6, -60 }, look = { 0, 12, 0 }, fov = 70 },
	{ pos = { 10, 6, 60 }, look = { -40, 8, 88 }, fov = 70 },
	{ pos = { -8, 6, -50 }, look = { -60, 6, -70 }, fov = 70 },
	{ pos = { 20, 12, 40 }, look = { 70, 14, 82 }, fov = 70 },
	{ pos = { 12, 5, -40 }, look = { 30, 8, -90 }, fov = 70 },
}

-- Interactive points the service wires up after building: prompt name -> panel.
Downtown.Panels = {
	GunShop = "Market",
	Armory = "Workshop",
	ContractBoard = "Contracts",
}

local M = Enum.Material

local ASPHALT = Color3.fromRGB(56, 58, 64)
local WHITE_LINE = Color3.fromRGB(232, 232, 226)
local YELLOW_LINE = Color3.fromRGB(240, 190, 40)
local SIDEWALK = Color3.fromRGB(178, 174, 166)
local SIDEWALK_EDGE = Color3.fromRGB(160, 156, 148)
local CURB = Color3.fromRGB(196, 192, 184)
local PLAZA_A = Color3.fromRGB(206, 198, 186)
local PLAZA_B = Color3.fromRGB(140, 134, 128)
local GRASS = Color3.fromRGB(88, 146, 72)
local LEAF = Color3.fromRGB(70, 132, 62)
local LEAF_LIGHT = Color3.fromRGB(104, 168, 80)
local BARK = Color3.fromRGB(92, 66, 50)
local STEEL = Color3.fromRGB(58, 60, 66)
local GLASS = Color3.fromRGB(60, 78, 96)
local WARM = Color3.fromRGB(255, 214, 150)
local NEON_PINK = Color3.fromRGB(255, 64, 170)
local NEON_CYAN = Color3.fromRGB(40, 220, 255)
local NEON_GOLD = Color3.fromRGB(255, 196, 40)
local NEON_GREEN = Color3.fromRGB(60, 255, 120)

local CAR_COLOURS = {
	Color3.fromRGB(196, 36, 40), Color3.fromRGB(30, 30, 34), Color3.fromRGB(236, 236, 232),
	Color3.fromRGB(34, 80, 160), Color3.fromRGB(226, 170, 30), Color3.fromRGB(120, 124, 132),
	Color3.fromRGB(40, 120, 90),
}

local function darker(c: Color3, t: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), t)
end

local function vertical(at: Vector3): CFrame
	return CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
end

local function painted(b: Kit.Builder, text: string, at: CFrame, w: number, h: number, colour: Color3, font: Enum.Font?)
	b:sign(text, at, w, h, colour, { lit = true, glow = false, font = font or Enum.Font.GothamBlack,
		textColour = colour, brightness = 1 })
end

local function neonSign(b: Kit.Builder, text: string, at: CFrame, w: number, h: number, colour: Color3, font: Enum.Font?)
	b:sign(text, at, w, h, colour, { font = font or Enum.Font.FredokaOne, brightness = 2.4 })
end

-- ------------------------------------------------------------ street props --

local function lamp(b: Kit.Builder, withLight: boolean)
	-- Stands at the origin, arm reaching toward -X (over the road).
	b:part("Base", Vector3.new(1.4, 1, 1.4), Vector3.new(0, 1, 0), STEEL, M.Metal)
	b:part("Pole", Vector3.new(16, 0.6, 0.6), vertical(Vector3.new(0, 9, 0)), STEEL, M.Metal, { shape = "Cylinder" })
	b:decor("Arm", Vector3.new(5, 0.35, 0.35), Vector3.new(-2.3, 16.6, 0), STEEL, M.Metal)
	b:decor("Head", Vector3.new(3, 0.5, 1.3), Vector3.new(-4.8, 16.5, 0), STEEL, M.Metal)
	b:neon("Lens", Vector3.new(2.6, 0.1, 1), Vector3.new(-4.8, 16.2, 0), WARM)
	b:decor("Banner", Vector3.new(0.1, 3.2, 1.6), Vector3.new(0.4, 12, 0.9), NEON_PINK, M.Fabric)
	if withLight then
		b:light("Spot", CFrame.new(-4.8, 16, 0) * CFrame.Angles(-math.pi / 2, 0, 0), WARM, 1.6, 34, { Angle = 120 })
	end
end

local function tree(b: Kit.Builder, seed: number)
	b:part("Planter", Vector3.new(4.4, 0.9, 4.4), Vector3.new(0, 0.95, 0), CURB, M.Concrete)
	b:decor("Soil", Vector3.new(3.8, 0.1, 3.8), Vector3.new(0, 1.42, 0), Color3.fromRGB(70, 52, 40), M.Ground)
	b:part("Trunk", Vector3.new(7, 0.8, 0.8), vertical(Vector3.new(0, 4.9, 0)), BARK, M.Wood, { shape = "Cylinder" })
	local rng = Random.new(seed)
	for i, blob in ipairs({ { Vector3.new(0, 9.4, 0), 6.4 }, { Vector3.new(1.8, 8.4, 0.8), 4.6 },
		{ Vector3.new(-1.6, 8.6, -1), 4.8 }, { Vector3.new(0.4, 11.2, -0.4), 4 } }) do
		local s = blob[2] * rng:NextNumber(0.9, 1.1)
		b:decor("Leaves", Vector3.new(s, s, s), blob[1], i % 2 == 0 and LEAF_LIGHT or LEAF, M.Grass,
			{ shape = "Ball", shadow = true })
	end
end

local function bench(b: Kit.Builder)
	b:part("Seat", Vector3.new(6, 0.35, 1.6), Vector3.new(0, 1.9, 0), Color3.fromRGB(150, 104, 64), M.Wood)
	b:decor("Back", Vector3.new(6, 1.4, 0.3), CFrame.new(0, 2.9, 0.75) * CFrame.Angles(math.rad(-10), 0, 0),
		Color3.fromRGB(150, 104, 64), M.Wood)
	for _, x in ipairs({ -2.5, 2.5 }) do
		b:decor("Leg", Vector3.new(0.3, 1.4, 1.6), Vector3.new(x, 1.2, 0), STEEL, M.Metal)
	end
end

local function bin(b: Kit.Builder)
	b:part("Bin", Vector3.new(2.6, 1.6, 1.6), vertical(Vector3.new(0, 1.8, 0)), Color3.fromRGB(46, 90, 60), M.Metal,
		{ shape = "Cylinder" })
	b:decor("Lid", Vector3.new(0.2, 1.8, 1.8), vertical(Vector3.new(0, 3.2, 0)), STEEL, M.Metal, { shape = "Cylinder" })
end

local function hydrant(b: Kit.Builder)
	local red = Color3.fromRGB(200, 40, 36)
	b:part("Hydrant", Vector3.new(2, 0.9, 0.9), vertical(Vector3.new(0, 1.5, 0)), red, M.Metal, { shape = "Cylinder" })
	b:decor("Cap", Vector3.new(0.4, 1.1, 1.1), vertical(Vector3.new(0, 2.6, 0)), red, M.Metal, { shape = "Cylinder" })
	b:decor("Nozzle", Vector3.new(1.4, 0.4, 0.4), Vector3.new(0, 1.8, 0), darker(red, 0.2), M.Metal, { shape = "Cylinder" })
end

local function bollard(b: Kit.Builder)
	b:part("Bollard", Vector3.new(2.6, 0.8, 0.8), vertical(Vector3.new(0, 1.8, 0)), STEEL, M.Metal, { shape = "Cylinder" })
	b:decor("Band", Vector3.new(0.3, 0.84, 0.84), vertical(Vector3.new(0, 2.7, 0)), NEON_GOLD, M.Neon, { shape = "Cylinder" })
end

--- A parked car, nose toward -Z.
local function car(b: Kit.Builder, colour: Color3)
	local trim = Color3.fromRGB(26, 26, 30)
	b:part("Body", Vector3.new(4.6, 1.5, 10), Vector3.new(0, 1.55, 0), colour, M.SmoothPlastic, { reflectance = 0.05 })
	b:part("Cabin", Vector3.new(4.1, 1.5, 5), Vector3.new(0, 3.05, 0.4), colour, M.SmoothPlastic)
	b:decor("Glass", Vector3.new(4.16, 1.1, 5.06), Vector3.new(0, 3.05, 0.4), Color3.fromRGB(30, 40, 52), M.Glass,
		{ transparency = 0.1, reflectance = 0.2 })
	b:decor("Roof", Vector3.new(4.12, 0.3, 4.2), Vector3.new(0, 3.85, 0.5), colour, M.SmoothPlastic)
	for _, z in ipairs({ -5.05, 5.05 }) do
		b:decor("Bumper", Vector3.new(4.7, 0.6, 0.3), Vector3.new(0, 1.1, z), trim, M.SmoothPlastic)
	end
	for _, x in ipairs({ -1.6, 1.6 }) do
		b:neon("Headlight", Vector3.new(1, 0.4, 0.1), Vector3.new(x, 1.8, -5.02), Color3.fromRGB(255, 250, 230))
		b:neon("Taillight", Vector3.new(1, 0.4, 0.1), Vector3.new(x, 1.8, 5.02), Color3.fromRGB(255, 40, 40))
	end
	for _, x in ipairs({ -2.05, 2.05 }) do
		for _, z in ipairs({ -3.2, 3.2 }) do
			b:decor("Wheel", Vector3.new(0.8, 2, 2), Vector3.new(x, 1, z), trim, M.Rubber, { shape = "Cylinder" })
			b:decor("Hub", Vector3.new(0.84, 0.9, 0.9), Vector3.new(x, 1, z), Color3.fromRGB(190, 190, 196), M.Metal,
				{ shape = "Cylinder" })
		end
		b:decor("Mirror", Vector3.new(0.5, 0.3, 0.4), Vector3.new(x * 1.12, 2.7, -1.8), colour, M.SmoothPlastic)
	end
end

-- -------------------------------------------------------------- buildings --

local FACADE = {
	Color3.fromRGB(184, 146, 108), Color3.fromRGB(150, 76, 58), Color3.fromRGB(164, 162, 156),
	Color3.fromRGB(214, 202, 178), Color3.fromRGB(110, 96, 90), Color3.fromRGB(96, 112, 128),
}

--- A block building from the ground to `top`, windows on the faces listed ("+x", "-x",
--- "+z", "-z"), a ground-floor band, a cornice and a few things on the roof.
local function building(b: Kit.Builder, x0: number, x1: number, z0: number, z1: number, top: number,
	colour: Color3, faces: { string }, seed: number)
	local w, d = x1 - x0, z1 - z0
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local base = -2
	b:part("Building", Vector3.new(w, top - base, d), Vector3.new(cx, (top + base) / 2, cz), colour,
		colour == FACADE[2] and M.Brick or M.Concrete)
	b:decor("Cornice", Vector3.new(w + 1, 1.2, d + 1), Vector3.new(cx, top - 0.2, cz), darker(colour, 0.25), M.Concrete)
	local rng = Random.new(seed)
	if faces[1] == "all" then
		faces = { "+x", "-x", "+z", "-z" }
	end
	for _, face in ipairs(faces) do
		local axis, sign = face:sub(2, 2), face:sub(1, 1) == "+" and 1 or -1
		local span = axis == "x" and d or w
		local function at(y: number, depth: number): (Vector3, Vector3)
			if axis == "x" then
				return Vector3.new(cx + sign * (w / 2 + depth / 2), y, cz), Vector3.new(depth, 0, span)
			end
			return Vector3.new(cx, y, cz + sign * (d / 2 + depth / 2)), Vector3.new(span, 0, depth)
		end
		-- Ground floor: a darker band with a glass shopfront run.
		local p, s = at(3.5, 0.3)
		b:decor("Ground", Vector3.new(math.max(s.X, 0.3), 7, math.max(s.Z, 0.3)), p, darker(colour, 0.35), M.Concrete)
		local g, gs = at(3.8, 0.5)
		b:decor("Shopfront", Vector3.new(math.max(gs.X * 0.9, 0.5), 4.6, math.max(gs.Z * 0.9, 0.5)), g, GLASS, M.Glass,
			{ reflectance = 0.25 })
		-- Floors above: window bands, some lit warm.
		for y = 11, top - 5, 7 do
			local wp, ws = at(y, 0.3)
			local lit = rng:NextNumber() < 0.28
			b:decor(lit and "WindowsLit" or "Windows", Vector3.new(math.max(ws.X * 0.86, 0.3), 2.8, math.max(ws.Z * 0.86, 0.3)),
				wp, lit and WARM or GLASS, lit and M.Neon or M.Glass, { reflectance = lit and 0 or 0.2,
					transparency = lit and 0.35 or 0 })
		end
	end
	-- Something on the roof.
	if w > 20 and d > 20 then
		b:decor("RoofUnit", Vector3.new(6, 3, 5), Vector3.new(cx + rng:NextNumber(-w / 5, w / 5), top + 1.5,
			cz + rng:NextNumber(-d / 5, d / 5)), Color3.fromRGB(200, 202, 198), M.Metal)
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

local function screenFace(b: Kit.Builder, at: CFrame, title: string, sub: string, colour: Color3)
	local s = b:within(at)
	s:decor("Bezel", Vector3.new(9.6, 12.6, 0.4), Vector3.new(0, 0, 0), Color3.fromRGB(16, 16, 20), M.SmoothPlastic)
	s:decor("Screen", Vector3.new(9, 12, 0.1), Vector3.new(0, 0, -0.22), darker(colour, 0.78), M.Neon)
	s:sign(title, CFrame.new(0, 2.2, -0.3), 8.4, 3.4, colour,
		{ font = Enum.Font.FredokaOne, brightness = 2.2 })
	s:sign(sub, CFrame.new(0, -1.8, -0.3), 8.2, 1.6, Color3.new(1, 1, 1),
		{ font = Enum.Font.GothamBlack, brightness = 1.6, glow = false })
	s:neon("Bar", Vector3.new(8.4, 0.3, 0.05), Vector3.new(0, -4.4, -0.3), colour)
end

--- ZEE PLAZA: tiles, a fountain round a four-sided screen tower, benches and trees.
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

	-- The fountain: an octagonal basin of two crossed squares, water, a lit lip.
	for i = 0, 1 do
		local rot = CFrame.Angles(0, math.rad(i * 45), 0)
		b:part("Basin", Vector3.new(24, 1.6, 24), CFrame.new(0, 1.3, 0) * rot, CURB, M.Concrete)
		b:decor("Water", Vector3.new(22.4, 0.3, 22.4), CFrame.new(0, 2.05, 0) * rot, Color3.fromRGB(70, 150, 200),
			M.Glass, { transparency = 0.25, reflectance = 0.2 })
		b:neon("Lip", Vector3.new(24.1, 0.15, 24.1), CFrame.new(0, 2.13, 0) * rot, NEON_CYAN, 0.55)
	end

	-- The screen tower in the middle of the water.
	b:part("TowerBase", Vector3.new(8, 3, 8), Vector3.new(0, 3.6, 0), STEEL, M.Metal)
	b:part("Tower", Vector3.new(10, 14, 10), Vector3.new(0, 12, 0), Color3.fromRGB(24, 24, 30), M.Metal)
	local faces = {
		{ "PROJECT ZEE", "WELCOME TO DOWNTOWN", NEON_PINK },
		{ "1V1 DUELS", "DUEL HALL  ·  NORTH-WEST", NEON_CYAN },
		{ "CONTRACTS", "24/7  ·  SOUTH-WEST", NEON_GOLD },
		{ "ZEE GUNS", "SHOP  ·  SOUTH-EAST", NEON_GREEN },
	}
	for i, f in ipairs(faces) do
		local yaw = (i - 1) * 90
		local cf = CFrame.Angles(0, math.rad(yaw), 0) * CFrame.new(0, 12, -5.25)
		screenFace(b, cf, f[1], f[2], f[3])
	end
	b:decor("Crown", Vector3.new(11, 1, 11), Vector3.new(0, 19.5, 0), STEEL, M.Metal)
	b:neon("CrownRing", Vector3.new(11.2, 0.4, 11.2), Vector3.new(0, 19.2, 0), NEON_PINK)
	b:decor("Spire", Vector3.new(6, 0.8, 0.8), vertical(Vector3.new(0, 23, 0)), NEON_CYAN, M.Neon, { shape = "Cylinder" })
	b:light("Point", Vector3.new(0, 16, 0), NEON_PINK, 1.2, 40)

	-- Sprays: fans of glowing water from the basin corners.
	for i = 0, 7 do
		local a = math.rad(i * 45 + 22.5)
		local p = Vector3.new(math.cos(a) * 9.4, 2.2, math.sin(a) * 9.4)
		local top = p + Vector3.new(-math.cos(a) * 2.4, 4.4, -math.sin(a) * 2.4)
		local cf, len = Kit.Span(p, top)
		b:decor("Spray", Vector3.new(0.35, 0.35, len), cf, Color3.fromRGB(170, 230, 255), M.Neon, { transparency = 0.45 })
	end

	-- Benches facing the fountain and trees at the corners.
	for i = 0, 3 do
		local yaw = math.rad(i * 90)
		for _, off in ipairs({ -8, 8 }) do
			bench(b:within(CFrame.Angles(0, yaw, 0) * CFrame.new(off, 0.5, -22) * CFrame.Angles(0, math.pi, 0)))
		end
		tree(b:within(CFrame.Angles(0, yaw, 0) * CFrame.new(half - 7, 0.5, half - 7)), 40 + i)
		tree(b:within(CFrame.Angles(0, yaw, 0) * CFrame.new(half - 18, 0.5, half - 7)), 50 + i)
		tree(b:within(CFrame.Angles(0, yaw, 0) * CFrame.new(half - 7, 0.5, half - 18)), 60 + i)
	end
	-- Bollards where the roads meet the square, so it reads as a place for people.
	for i = 0, 3 do
		local yaw = math.rad(i * 90)
		for x = -15, 15, 5 do
			bollard(b:within(CFrame.Angles(0, yaw, 0) * CFrame.new(x, 0.5, -half + 1.2)))
		end
	end
end

-- ------------------------------------------------------------- set pieces --

--- A storefront facing -X (toward the avenue): glass front, awning, neon name, a lit interior
--- and a prompt at the door. Origin at the front's centre on the pavement.
local function storefront(b: Kit.Builder, name: string, sub: string, colour: Color3, promptName: string,
	prompt: string, depth: number, width: number)
	local h = 22
	b:part("Shell", Vector3.new(depth, h, width), Vector3.new(depth / 2, h / 2, 0), Color3.fromRGB(128, 124, 118), M.Concrete)
	b:decor("Parapet", Vector3.new(depth + 0.6, 1, width + 0.6), Vector3.new(depth / 2, h + 0.3, 0), STEEL, M.Metal)
	b:decor("RoofDeck", Vector3.new(depth - 1, 0.2, width - 1), Vector3.new(depth / 2, h + 0.85, 0),
		Color3.fromRGB(150, 148, 144), M.Concrete)
	b:decor("RoofUnit", Vector3.new(5, 3, 4), Vector3.new(depth * 0.6, h + 1.6, width / 4), Color3.fromRGB(200, 202, 198),
		M.Metal)
	-- The facade: pillars, a sign band, the glass.
	b:decor("Facade", Vector3.new(0.6, h, width + 0.4), Vector3.new(-0.3, h / 2, 0), Color3.fromRGB(32, 34, 40), M.Metal)
	b:decor("SignBand", Vector3.new(0.4, 5, width - 2), Vector3.new(-0.8, 15.5, 0), Color3.fromRGB(16, 16, 20),
		M.SmoothPlastic)
	neonSign(b, name, Kit.Look(Vector3.new(-1.1, 15.8, 0), Vector3.new(-10, 15.8, 0)), width - 6, 4.2, colour)
	b:neon("SignEdge", Vector3.new(0.1, 0.3, width - 2), Vector3.new(-1.05, 13.1, 0), colour)
	for _, z in ipairs({ -width / 2 + 1.5, width / 2 - 1.5 }) do
		b:decor("Pillar", Vector3.new(1, 12.6, 3), Vector3.new(-0.8, 6.3, z), Color3.fromRGB(28, 28, 32), M.Metal)
	end
	-- Two big windows either side of the door, the interior lit behind them.
	for _, z in ipairs({ -width / 4 - 1.5, width / 4 + 1.5 }) do
		b:decor("Window", Vector3.new(0.3, 9, width / 2 - 8), Vector3.new(-0.5, 5.8, z), GLASS, M.Glass,
			{ transparency = 0.55, reflectance = 0.15 })
		b:decor("Display", Vector3.new(3, 1.2, width / 2 - 10), Vector3.new(1.8, 1.1, z), Color3.fromRGB(26, 26, 30), M.Wood)
		-- Racks of guns on the back wall of the display.
		for i = -2, 2 do
			b:decor("RackItem", Vector3.new(0.4, 0.5, 3.2), Vector3.new(4, 4 + (i % 2) * 1.6, z + i * 1.8),
				Color3.fromRGB(40, 40, 44), M.Metal)
		end
		b:neon("Interior", Vector3.new(0.1, 0.4, width / 2 - 8), Vector3.new(6, 10.5, z), WARM)
	end
	b:light("Point", Vector3.new(5, 8, 0), WARM, 1.1, 26)
	-- The door and its prompt.
	b:decor("DoorFrame", Vector3.new(0.5, 9.4, 7), Vector3.new(-0.6, 4.7, 0), colour, M.SmoothPlastic)
	b:decor("Door", Vector3.new(0.3, 8.6, 6), Vector3.new(-0.7, 4.3, 0), GLASS, M.Glass, { transparency = 0.4 })
	local mat = b:decor("Mat", Vector3.new(3, 0.08, 6), Vector3.new(-2.2, 0.04, 0), darker(colour, 0.3), M.Fabric)
	mat.Name = promptName
	mat:SetAttribute("PromptText", prompt)
	mat:SetAttribute("PromptObject", sub)
	-- The awning: a slope in the shop's colour over the windows.
	b:part("Awning", Vector3.new(width - 3, 1.6, 4), CFrame.new(-2.6, 12.2, 0) * CFrame.Angles(0, math.rad(90), 0),
		colour, M.Fabric, { shape = "Wedge", collide = false })
	b:decor("AwningEdge", Vector3.new(0.2, 0.5, width - 3), Vector3.new(-4.6, 11.2, 0), darker(colour, 0.3), M.Fabric)
	painted(b, sub, Kit.Look(Vector3.new(-0.75, 11, width / 2 - 4.5), Vector3.new(-10, 11, width / 2 - 4.5)), 6, 0.9,
		Color3.fromRGB(230, 230, 230))
end

--- ZEE GAS: canopy over two pump islands, the 24/7 store behind, the price pylon on the
--- corner. Origin at the forecourt's centre; the road is toward +X.
local function gasStation(b: Kit.Builder)
	b:decor("Forecourt", Vector3.new(44, 0.06, 36), Vector3.new(0, 0.53, 0), Color3.fromRGB(96, 98, 104), M.Concrete)
	-- Canopy.
	for _, x in ipairs({ -12, 12 }) do
		for _, z in ipairs({ -8, 8 }) do
			b:part("Column", Vector3.new(1.4, 13, 1.4), Vector3.new(x, 7, z), Color3.fromRGB(236, 236, 232), M.Metal)
		end
	end
	b:part("Canopy", Vector3.new(36, 2, 26), Vector3.new(0, 14.5, 0), Color3.fromRGB(236, 236, 232), M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		b:neon("Fascia", Vector3.new(36.2, 0.8, 0.2), Vector3.new(0, 14.3, s * 13.05), NEON_GOLD)
		b:neon("Fascia", Vector3.new(0.2, 0.8, 26.2), Vector3.new(s * 18.05, 14.3, 0), NEON_GOLD)
	end
	b:sign("ZEE GAS", Kit.Look(Vector3.new(18.2, 15.1, 0), Vector3.new(30, 15.1, 0)), 14, 1.8, Color3.fromRGB(220, 30, 40),
		{ font = Enum.Font.GothamBlack, brightness = 1.8, glow = false, textColour = Color3.fromRGB(220, 30, 40) })
	for x = -12, 12, 8 do
		b:neon("Downlight", Vector3.new(4, 0.1, 4), Vector3.new(x, 13.45, 0), Color3.fromRGB(255, 250, 236))
	end
	b:light("Spot", CFrame.new(0, 13.2, 0) * CFrame.Angles(-math.pi / 2, 0, 0), Color3.fromRGB(255, 250, 236), 1.6, 30,
		{ Angle = 150 })
	-- Pump islands.
	for _, z in ipairs({ -5, 5 }) do
		b:part("Island", Vector3.new(14, 0.6, 3), Vector3.new(0, 0.8, z), CURB, M.Concrete)
		for _, x in ipairs({ -3.5, 3.5 }) do
			b:part("Pump", Vector3.new(2.2, 5, 1.6), Vector3.new(x, 3.6, z), Color3.fromRGB(220, 30, 40), M.SmoothPlastic)
			b:decor("PumpScreen", Vector3.new(1.4, 1, 0.1), Vector3.new(x, 4.6, z - 0.82), Color3.fromRGB(20, 40, 30), M.Neon)
			b:decor("PumpTop", Vector3.new(2.4, 0.5, 1.8), Vector3.new(x, 6.3, z), Color3.fromRGB(236, 236, 232), M.SmoothPlastic)
			b:decor("Hose", Vector3.new(0.2, 3, 0.2), Vector3.new(x + 1.2, 3.2, z), Color3.fromRGB(20, 20, 20), M.Rubber)
		end
		b:part("Barrier", Vector3.new(0.5, 2, 0.5), Vector3.new(-7.4, 2, z), Color3.fromRGB(255, 200, 30), M.Metal)
		b:part("Barrier", Vector3.new(0.5, 2, 0.5), Vector3.new(7.4, 2, z), Color3.fromRGB(255, 200, 30), M.Metal)
	end
	-- The price pylon on the corner by the road.
	b:part("Pylon", Vector3.new(1.4, 22, 1.4), Vector3.new(20, 11.5, -16), STEEL, M.Metal)
	b:decor("PriceBoard", Vector3.new(1, 9, 7), Vector3.new(20, 19, -16), Color3.fromRGB(236, 236, 232), M.SmoothPlastic)
	b:sign("ZEE", Kit.Look(Vector3.new(20.55, 21.6, -16), Vector3.new(30, 21.6, -16)), 6, 3, Color3.fromRGB(220, 30, 40),
		{ font = Enum.Font.GothamBlack, brightness = 1.4, glow = false, textColour = Color3.fromRGB(220, 30, 40) })
	for i, price in ipairs({ "REG  3.49", "PLUS 3.79", "PREM 4.09" }) do
		b:sign(price, Kit.Look(Vector3.new(20.55, 19.6 - i * 1.6, -16), Vector3.new(30, 19.6 - i * 1.6, -16)), 6, 1.2,
			NEON_GREEN, { font = Enum.Font.Code, brightness = 2, glow = false, textColour = NEON_GREEN })
	end
end

--- The 24/7 store with the contracts board outside. Origin at the shop front, facing +X.
local function convenience(b: Kit.Builder)
	b:part("Store", Vector3.new(26, 14, 30), Vector3.new(-13, 7, 0), Color3.fromRGB(230, 226, 214), M.Concrete)
	b:decor("Roofline", Vector3.new(26.6, 1, 30.6), Vector3.new(-13, 14.3, 0), Color3.fromRGB(60, 150, 70), M.SmoothPlastic)
	b:decor("Glass", Vector3.new(0.3, 8, 20), Vector3.new(0.1, 5, -2), GLASS, M.Glass, { transparency = 0.45, reflectance = 0.2 })
	b:neon("Interior", Vector3.new(0.1, 0.4, 18), Vector3.new(-4, 9, -2), Color3.fromRGB(240, 250, 255))
	for i = 0, 3 do
		b:decor("Shelf", Vector3.new(1.2, 5, 16), Vector3.new(-6 - i * 4, 2.5, -2), Color3.fromRGB(200, 200, 204), M.Metal)
	end
	b:light("Point", Vector3.new(-8, 9, -2), Color3.fromRGB(240, 250, 255), 1, 22)
	neonSign(b, "24/7", Kit.Look(Vector3.new(0.4, 11.4, -2), Vector3.new(10, 11.4, -2)), 10, 3.4, NEON_GREEN)
	b:decor("Door", Vector3.new(0.3, 7.6, 5), Vector3.new(0.12, 3.8, 11), GLASS, M.Glass, { transparency = 0.35 })

	-- The contracts board: a cork board on posts, papers pinned, a header, a lamp over it.
	local board = b:within(CFrame.new(5, 0, 11.5))
	for _, z in ipairs({ -4, 4 }) do
		board:part("Post", Vector3.new(0.5, 9, 0.5), Vector3.new(0, 4.5, z), Color3.fromRGB(90, 62, 44), M.Wood)
	end
	board:decor("Board", Vector3.new(0.4, 5, 8.6), Vector3.new(0, 5.6, 0), Color3.fromRGB(176, 128, 82), M.Wood)
	board:decor("Frame", Vector3.new(0.5, 5.4, 9), Vector3.new(-0.05, 5.6, 0), Color3.fromRGB(90, 62, 44), M.Wood)
	local rng = Random.new(77)
	for i = 0, 5 do
		local z = -3 + (i % 3) * 3
		local y = 4.4 + math.floor(i / 3) * 2.4
		board:decor("Paper", Vector3.new(0.05, 1.8, 1.9),
			CFrame.new(0.23, y, z) * CFrame.Angles(math.rad(rng:NextNumber(-6, 6)), 0, 0),
			Color3.fromRGB(246, 240, 222), M.SmoothPlastic)
		board:decor("Pin", Vector3.new(0.12, 0.2, 0.2), Vector3.new(0.28, y + 0.7, z), NEON_PINK, M.Neon)
	end
	board:decor("Header", Vector3.new(0.4, 1.4, 9.4), Vector3.new(0, 8.8, 0), Color3.fromRGB(20, 20, 24), M.SmoothPlastic)
	neonSign(board, "CONTRACTS", Kit.Look(Vector3.new(0.25, 8.8, 0), Vector3.new(10, 8.8, 0)), 8.6, 1.2, NEON_GOLD)
	local spot = board:decor("ContractBoard", Vector3.new(3, 0.08, 6), Vector3.new(2, 0.54, 0), Color3.fromRGB(40, 40, 44),
		M.Fabric)
	spot:SetAttribute("PromptText", "Contracts")
	spot:SetAttribute("PromptObject", "Daily jobs")
	board:light("Spot", Kit.Look(Vector3.new(1.4, 10.4, 0), Vector3.new(0, 5.6, 0)), WARM, 1.4, 16, { Angle = 70 })
end

--- The DUEL HALL: an open-fronted hall facing +X with a marquee, bleachers and the pads
--- (placed by the service). Origin at the front's centre.
local function duelHall(b: Kit.Builder)
	local W, D, H = 56, 64, 26
	local floorColour = Color3.fromRGB(26, 26, 34)
	b:part("Floor", Vector3.new(D, 0.4, W), Vector3.new(-D / 2, 0.7, 0), floorColour, M.SmoothPlastic)
	-- Neon grid on the floor.
	for x = -D + 8, -8, 8 do
		b:neon("Grid", Vector3.new(0.12, 0.04, W - 4), Vector3.new(x, 0.92, 0), NEON_CYAN, 0.7)
	end
	for z = -W / 2 + 8, W / 2 - 8, 8 do
		b:neon("Grid", Vector3.new(D - 4, 0.04, 0.12), Vector3.new(-D / 2, 0.92, z), NEON_PINK, 0.7)
	end
	b:part("Back", Vector3.new(2, H, W), Vector3.new(-D - 1, H / 2, 0), Color3.fromRGB(30, 30, 38), M.Concrete)
	for _, s in ipairs({ -1, 1 }) do
		b:part("Side", Vector3.new(D, H, 2), Vector3.new(-D / 2, H / 2, s * (W / 2 + 1)), Color3.fromRGB(30, 30, 38), M.Concrete)
		-- The front piers either side of the opening.
		b:part("Pier", Vector3.new(3, H, 10), Vector3.new(-1.5, H / 2, s * (W / 2 - 4)), Color3.fromRGB(36, 36, 46), M.Concrete)
		-- Bleachers along the side walls.
		for row = 0, 3 do
			-- Stepped up toward the wall: each row a solid block from the floor to its seat.
			local seat = 1.2 * (4 - row)
			b:part("Bleacher", Vector3.new(D - 20, seat, 2.4), Vector3.new(-D / 2 - 4, 0.9 + seat / 2,
				s * (W / 2 - 1.5 - row * 2.4)), row % 2 == 0 and Color3.fromRGB(60, 62, 74) or Color3.fromRGB(70, 72, 86),
				M.Metal)
		end
		b:neon("SideTrim", Vector3.new(D, 0.4, 0.2), Vector3.new(-D / 2, H - 3, s * W / 2), s < 0 and NEON_PINK or NEON_CYAN)
	end
	b:part("Roof", Vector3.new(D + 4, 1.4, W + 4), Vector3.new(-D / 2, H + 0.7, 0), Color3.fromRGB(96, 98, 110), M.Metal)
	for _, s in ipairs({ -1, 1 }) do
		b:neon("RoofEdge", Vector3.new(D + 4.1, 0.4, 0.3), Vector3.new(-D / 2, H + 1.2, s * (W / 2 + 2)),
			s < 0 and NEON_PINK or NEON_CYAN)
	end
	for _, x in ipairs({ -D * 0.3, -D * 0.7 }) do
		b:decor("RoofUnit", Vector3.new(6, 3, 5), Vector3.new(x, H + 2.9, 0), Color3.fromRGB(200, 202, 198), M.Metal)
	end
	-- Marquee over the opening.
	b:decor("Marquee", Vector3.new(2, 7, W - 4), Vector3.new(-0.5, H - 4.5, 0), Color3.fromRGB(16, 16, 22), M.SmoothPlastic)
	neonSign(b, "DUEL HALL", Kit.Look(Vector3.new(0.6, H - 4, 0), Vector3.new(10, H - 4, 0)), W - 12, 5, NEON_CYAN)
	for z = -W / 2 + 4, W / 2 - 4, 2.2 do
		b:neon("Bulb", Vector3.new(0.4, 0.4, 0.4), Vector3.new(0.6, H - 7.8, z), NEON_GOLD)
		b:neon("Bulb", Vector3.new(0.4, 0.4, 0.4), Vector3.new(0.6, H - 1.2, z), NEON_GOLD)
	end
	-- The big 1V1 on the back wall.
	b:decor("Screen", Vector3.new(0.4, 12, 30), Vector3.new(-D + 0.2, 13, 0), Color3.fromRGB(12, 12, 18), M.SmoothPlastic)
	neonSign(b, "1V1", Kit.Look(Vector3.new(-D + 0.5, 14, 0), Vector3.new(0, 14, 0)), 22, 9, NEON_PINK)
	b:sign("STAND ON A PAD TO QUEUE", Kit.Look(Vector3.new(-D + 0.5, 8.4, 0), Vector3.new(0, 8.4, 0)), 26, 1.8,
		Color3.new(1, 1, 1), { font = Enum.Font.GothamBlack, brightness = 1.6, glow = false })
	for _, z in ipairs({ -14, 14 }) do
		b:light("Spot", Kit.Look(Vector3.new(-20, H - 2, z), Vector3.new(-26, 0, z * 0.4)), Color3.fromRGB(230, 236, 255),
			1.4, 40, { Angle = 90 })
	end
	local padSite = b:decor("PadSite", Vector3.new(1, 0.1, 1), Vector3.new(-D / 2 + 4, 0.95, 0), floorColour, nil,
		{ transparency = 1 })
	padSite.Name = "DuelPadSite"
end

--- A fenced basketball court. Origin at the court's centre; length along Z.
local function court(b: Kit.Builder)
	local L, W = 44, 26
	b:part("Court", Vector3.new(W + 6, 0.3, L + 6), Vector3.new(0, 0.65, 0), Color3.fromRGB(46, 110, 170), M.SmoothPlastic)
	b:decor("Key", Vector3.new(W, 0.04, L), Vector3.new(0, 0.82, 0), Color3.fromRGB(190, 90, 50), M.SmoothPlastic)
	local line = Color3.fromRGB(240, 240, 236)
	for _, s in ipairs({ -1, 1 }) do
		b:decor("Line", Vector3.new(0.3, 0.05, L), Vector3.new(s * W / 2, 0.84, 0), line)
		b:decor("Line", Vector3.new(W, 0.05, 0.3), Vector3.new(0, 0.84, s * L / 2), line)
		b:decor("Paint", Vector3.new(8, 0.05, 9), Vector3.new(0, 0.85, s * (L / 2 - 4.5)), Color3.fromRGB(46, 110, 170))
		-- Hoop: pole, arm, backboard, rim.
		local h = b:within(CFrame.new(0, 0.8, s * (L / 2 + 2)) * CFrame.Angles(0, s > 0 and 0 or math.pi, 0))
		h:part("Pole", Vector3.new(0.6, 11, 0.6), Vector3.new(0, 5.5, 0), STEEL, M.Metal)
		h:decor("Arm", Vector3.new(0.4, 0.4, 3), Vector3.new(0, 10.6, -1.5), STEEL, M.Metal)
		h:decor("Backboard", Vector3.new(6, 3.6, 0.2), Vector3.new(0, 10.8, -3), Color3.fromRGB(240, 240, 240), M.Glass,
			{ transparency = 0.2 })
		h:decor("Square", Vector3.new(2.4, 1.6, 0.22), Vector3.new(0, 10.2, -3.02), Color3.fromRGB(220, 60, 40))
		h:decor("Rim", Vector3.new(0.12, 1.8, 1.8), vertical(Vector3.new(0, 9.6, -4)), Color3.fromRGB(240, 110, 30), M.Metal,
			{ shape = "Cylinder" })
	end
	b:decor("CentreCircle", Vector3.new(0.05, 7, 7), vertical(Vector3.new(0, 0.84, 0)), line, M.SmoothPlastic,
		{ shape = "Cylinder" })
	b:decor("CentreFill", Vector3.new(0.06, 6.4, 6.4), vertical(Vector3.new(0, 0.85, 0)), Color3.fromRGB(190, 90, 50),
		M.SmoothPlastic, { shape = "Cylinder" })
	b:decor("CentreLine", Vector3.new(W, 0.05, 0.3), Vector3.new(0, 0.84, 0), line)
	-- Chain-link fence round it, gaps at the middle of the long sides.
	local fenceColour = Color3.fromRGB(150, 156, 160)
	local fx, fz = W / 2 + 3, L / 2 + 3
	for _, s in ipairs({ -1, 1 }) do
		b:part("Fence", Vector3.new(W + 6, 10, 0.2), Vector3.new(0, 5.8, s * fz), fenceColour, M.DiamondPlate,
			{ transparency = 0.6 })
		for _, half in ipairs({ -1, 1 }) do
			b:part("Fence", Vector3.new(0.2, 10, fz - 5), Vector3.new(s * fx, 5.8, half * (fz + 5) / 2), fenceColour,
				M.DiamondPlate, { transparency = 0.6 })
		end
		for z = -fz, fz, 8 do
			b:decor("FencePost", Vector3.new(0.3, 10.4, 0.3), Vector3.new(s * fx, 5.8, z), STEEL, M.Metal)
		end
	end
	-- Floodlights on two corners.
	for _, s in ipairs({ -1, 1 }) do
		b:part("LightPole", Vector3.new(0.7, 22, 0.7), Vector3.new(s * (fx + 2), 11.5, s * (fz - 2)), STEEL, M.Metal)
		b:neon("Flood", Vector3.new(3, 1.6, 0.5), Vector3.new(s * (fx + 1.2), 22, s * (fz - 2)), Color3.fromRGB(255, 250, 236))
		b:light("Spot", Kit.Look(Vector3.new(s * (fx + 1), 21.6, s * (fz - 2)), Vector3.new(0, 0, 0)),
			Color3.fromRGB(255, 250, 236), 1.5, 50, { Angle = 70 })
	end
	-- Graffiti on the wall behind.
end

--- An apartment block with a fire escape up its -X face to the roof, where the stash is.
--- Origin at the block's -X face centre on the pavement.
local function apartments(b: Kit.Builder)
	local W, D, H = 40, 30, 44
	b:part("Block", Vector3.new(D, H, W), Vector3.new(D / 2, H / 2, 0), FACADE[2], M.Brick)
	b:decor("Cornice", Vector3.new(D + 1, 1.2, W + 1), Vector3.new(D / 2, H - 0.2, 0), darker(FACADE[2], 0.3), M.Concrete)
	b:part("Parapet", Vector3.new(D, 2.4, 1), Vector3.new(D / 2, H + 1.2, W / 2 - 0.5), darker(FACADE[2], 0.2), M.Brick)
	b:part("Parapet", Vector3.new(D, 2.4, 1), Vector3.new(D / 2, H + 1.2, -W / 2 + 0.5), darker(FACADE[2], 0.2), M.Brick)
	b:part("Parapet", Vector3.new(1, 2.4, W), Vector3.new(D - 0.5, H + 1.2, 0), darker(FACADE[2], 0.2), M.Brick)
	-- Windows in a grid on the -X face.
	for y = 6, H - 6, 8 do
		for z = -W / 2 + 4, W / 2 - 4, 6 do
			local lit = ((y * 7 + z * 3) % 5) == 0
			b:decor("Window", Vector3.new(0.2, 3.6, 3), Vector3.new(-0.1, y, z), lit and WARM or GLASS,
				lit and M.Neon or M.Glass, { transparency = lit and 0.3 or 0, reflectance = lit and 0 or 0.2 })
			b:decor("Sill", Vector3.new(0.5, 0.3, 3.4), Vector3.new(-0.25, y - 2, z), CURB, M.Concrete)
		end
	end
	-- The fire escape: a switchback of stairs in two columns against the wall, a landing at
	-- each end of every flight, and the last landing level with the roof. Flights alternate
	-- columns, so nobody walking up ever meets the underside of the flight above.
	local rail = Color3.fromRGB(40, 40, 44)
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
			b:decor("Tread", Vector3.new(3.6, 0.12, 0.25), CFrame.new(p) * (cf - cf.Position), Color3.fromRGB(70, 70, 76), M.Metal)
		end
		local rcf, rlen = Kit.Span(a + Vector3.new(x < -4 and -1.8 or 1.8, 3, 0), c + Vector3.new(x < -4 and -1.8 or 1.8, 3, 0))
		b:decor("StairRail", Vector3.new(0.15, 0.15, rlen), rcf, rail, M.Metal)
	end
	-- Uprights holding it to the wall.
	for _, z in ipairs({ -END - 3, 0, END + 3 }) do
		b:decor("Upright", Vector3.new(0.3, H, 0.3), Vector3.new(-8, H / 2, z), rail, M.Metal)
	end
	-- The rooftop: a water tank, an aerial, and the stash crate with a light on it.
	b:decor("Tank", Vector3.new(6, 6, 6), vertical(Vector3.new(D - 8, H + 3, -W / 2 + 8)), Color3.fromRGB(150, 104, 66),
		M.WoodPlanks, { shape = "Cylinder" })
	local stash = b:part("RooftopStash", Vector3.new(4, 3, 3), Vector3.new(D / 2, H + 1.5, 0), Color3.fromRGB(88, 100, 62),
		M.Metal)
	stash:SetAttribute("PromptText", "Search")
	stash:SetAttribute("PromptObject", "Rooftop Stash")
	b:decor("StashLid", Vector3.new(4.2, 0.4, 3.2), Vector3.new(D / 2, H + 3.2, 0), Color3.fromRGB(58, 66, 42), M.Metal)
	b:neon("StashLight", Vector3.new(0.6, 0.6, 0.6), Vector3.new(D / 2, H + 3.8, 0), NEON_GOLD)
	b:light("Point", Vector3.new(D / 2, H + 4.5, 0), NEON_GOLD, 1.4, 16)
end

--- ZEE TOWER at the north end of the avenue. Origin at the front's centre, facing -Z.
local function tower(b: Kit.Builder)
	local W, D, H = 60, 40, 170
	b:part("Tower", Vector3.new(W, H, D), Vector3.new(0, H / 2, D / 2), Color3.fromRGB(58, 72, 90), M.Glass,
		{ reflectance = 0.25 })
	-- Vertical fins up the glass.
	for x = -W / 2 + 3, W / 2 - 3, 6 do
		b:decor("Fin", Vector3.new(0.6, H - 20, 0.8), Vector3.new(x, H / 2 + 8, -0.4), Color3.fromRGB(200, 204, 210), M.Metal)
	end
	-- Lobby: a double-height glass base with a canopy.
	b:decor("Lobby", Vector3.new(W - 8, 14, 0.4), Vector3.new(0, 7, -0.5), Color3.fromRGB(200, 220, 240), M.Glass,
		{ transparency = 0.4 })
	b:neon("LobbyGlow", Vector3.new(W - 10, 0.3, 0.2), Vector3.new(0, 13.6, -0.7), WARM)
	b:part("Canopy", Vector3.new(24, 0.8, 10), Vector3.new(0, 14.4, -5), Color3.fromRGB(34, 36, 44), M.Metal)
	b:neon("CanopyEdge", Vector3.new(24.2, 0.3, 0.2), Vector3.new(0, 14.1, -10.05), NEON_CYAN)
	neonSign(b, "ZEE TOWER", Kit.Look(Vector3.new(0, 16.4, -0.9), Vector3.new(0, 16.4, -10)), 26, 3.4, NEON_CYAN)
	-- The crown: setbacks, a neon ring and the logo facing down the avenue.
	b:part("Setback", Vector3.new(W - 10, 12, D - 10), Vector3.new(0, H + 6, D / 2), Color3.fromRGB(40, 50, 64), M.Metal)
	b:neon("Ring", Vector3.new(W + 0.4, 1, D + 0.4), Vector3.new(0, H - 2, D / 2), NEON_PINK)
	b:neon("Ring", Vector3.new(W - 9.6, 0.8, D - 9.6), Vector3.new(0, H + 11.6, D / 2), NEON_CYAN)
	neonSign(b, "ZEE", Kit.Look(Vector3.new(0, H - 12, -0.9), Vector3.new(0, H - 12, -10)), 36, 16, NEON_PINK)
	b:part("Mast", Vector3.new(34, 1.2, 1.2), vertical(Vector3.new(0, H + 29, D / 2)), Color3.fromRGB(200, 204, 210), M.Metal,
		{ shape = "Cylinder" })
	b:neon("Beacon", Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, H + 46.5, D / 2), Color3.fromRGB(255, 60, 60))
	b:light("Point", Vector3.new(0, 18, -4), NEON_CYAN, 1.4, 40)
end

--- A car park: painted bays in two rows, a few cars in them, a light at each end.
local function carPark(b: Kit.Builder, x0: number, x1: number, z0: number, z1: number, cars: number)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	b:decor("Lot", Vector3.new(x1 - x0 - 2, 0.06, z1 - z0 - 2), Vector3.new(cx, 0.53, cz), Color3.fromRGB(70, 72, 78), M.Asphalt)
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
		lamp(b:within(CFrame.new(cx, 0.5, z) * CFrame.Angles(0, math.rad(90), 0)), false)
	end
end

--- A pocket park: lawn, crossing paths, trees at the corners, benches, a statue.
local function pocketPark(b: Kit.Builder)
	local W, D = 60, 20
	b:decor("Lawn", Vector3.new(W, 0.1, D), Vector3.new(0, 0.55, 0), GRASS, M.Grass)
	b:decor("Path", Vector3.new(W, 0.12, 3), Vector3.new(0, 0.56, 0), PLAZA_A, M.Slate)
	b:decor("Path", Vector3.new(3, 0.12, D), Vector3.new(0, 0.56, 0), PLAZA_A, M.Slate)
	for _, x in ipairs({ -W / 2 + 5, W / 2 - 5 }) do
		for _, z in ipairs({ -D / 2 + 4, D / 2 - 4 }) do
			tree(b:within(CFrame.new(x, 0, z)), math.floor(x + z))
		end
	end
	for _, x in ipairs({ -12, 12 }) do
		bench(b:within(CFrame.new(x, 0, 3.2)))
		bench(b:within(CFrame.new(x, 0, -3.2) * CFrame.Angles(0, math.pi, 0)))
	end
	-- The statue: a figure on a plinth, arm raised.
	b:part("Plinth", Vector3.new(4, 3, 4), Vector3.new(0, 2, 0), CURB, M.Granite)
	local bronze = Color3.fromRGB(120, 96, 64)
	b:part("Legs", Vector3.new(1.6, 3, 1), Vector3.new(0, 5, 0), bronze, M.Metal)
	b:part("Torso", Vector3.new(2, 2.6, 1.1), Vector3.new(0, 7.8, 0), bronze, M.Metal)
	b:decor("Head", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 9.8, 0), bronze, M.Metal, { shape = "Ball" })
	b:decor("Arm", Vector3.new(0.6, 3, 0.6), CFrame.new(1.4, 9.4, 0) * CFrame.Angles(0, 0, math.rad(-20)), bronze, M.Metal)
	b:decor("Torch", Vector3.new(0.8, 0.8, 0.8), Vector3.new(1.9, 11, 0), NEON_GOLD, M.Neon, { shape = "Ball" })
	painted(b, "THE FIRST DUELLIST", Kit.Look(Vector3.new(0, 2, -2.05), Vector3.new(0, 2, -10)), 3.8, 0.7,
		Color3.fromRGB(40, 36, 30), Enum.Font.Garamond)
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

	-- The arrival forecourt at the south end of the avenue, where the travel gate lands.
	pavement(root, -ROAD, ROAD, -HW - 40, -HW + 48, PLAZA_B, { "+z" })
	root:decor("Forecourt", Vector3.new(ROAD * 2 - 2, 0.04, 40), Vector3.new(0, 0.52, -HW + 24), PLAZA_A, M.Slate)
	-- An overhead sign across the avenue pointing the way.
	for _, s in ipairs({ -1, 1 }) do
		root:part("SignPost", Vector3.new(1, 20, 1), Vector3.new(s * (ROAD + 2), 10.5, -HW + 62), STEEL, M.Metal)
	end
	root:decor("Gantry", Vector3.new(ROAD * 2 + 5, 1, 1), Vector3.new(0, 19, -HW + 62), STEEL, M.Metal)
	local sign = root:within(CFrame.new(0, 15.6, -HW + 61.4))
	sign:decor("Board", Vector3.new(34, 6, 0.4), Vector3.new(0, 0, 0), Color3.fromRGB(20, 110, 60), M.SmoothPlastic)
	sign:decor("Border", Vector3.new(33, 5.2, 0.42), Vector3.new(0, 0, 0), Color3.fromRGB(236, 236, 232), M.SmoothPlastic)
	sign:decor("Inner", Vector3.new(32.4, 4.6, 0.44), Vector3.new(0, 0, 0), Color3.fromRGB(20, 110, 60), M.SmoothPlastic)
	sign:sign("↑ ZEE PLAZA     ↖ DUEL HALL     ↗ COURTS", Kit.Look(Vector3.new(0, 0.9, -0.3), Vector3.new(0, 0.9, -10)),
		31, 1.8, Color3.new(1, 1, 1), { lit = true, glow = false, font = Enum.Font.GothamBold, brightness = 1.2 })
	sign:sign("← ZEE GAS  ·  24/7         ZEE GUNS  ·  ARMORY →", Kit.Look(Vector3.new(0, -1.3, -0.3), Vector3.new(0, -1.3, -10)),
		31, 1.6, Color3.new(1, 1, 1), { lit = true, glow = false, font = Enum.Font.GothamBold, brightness = 1.2 })
	-- A bus shelter on the forecourt.
	local shelter = root:within(CFrame.new(-ROAD + 4, 0.5, -HW + 30))
	shelter:part("Roof", Vector3.new(5, 0.4, 12), Vector3.new(0, 8, 0), STEEL, M.Metal)
	shelter:decor("BackGlass", Vector3.new(0.2, 7, 12), Vector3.new(-2.4, 4, 0), GLASS, M.Glass, { transparency = 0.5 })
	shelter:decor("Ad", Vector3.new(0.3, 6, 3.6), Vector3.new(-2.2, 4, 4), Color3.fromRGB(255, 255, 255), M.Neon,
		{ transparency = 0.1 })
	painted(shelter, "ZEE COLA", Kit.Look(Vector3.new(-2, 5.5, 4), Vector3.new(10, 5.5, 4)), 3.4, 1.2, Color3.fromRGB(220, 30, 60))
	bench(shelter:within(CFrame.new(-1, 0, -1) * CFrame.Angles(0, math.rad(-90), 0)))

	-- Street furniture, on a rhythm: a lamp every 30 studs, a tree between, the odd hydrant
	-- and bin. Lamps on both sides of every arm, arms reaching over the road. Nothing but
	-- lamps in front of a door.
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
		for d = PLAZA + 20, HW - 10, 30 do
			if not (az == -1 and d > HW - 60) then
				for _, side in ipairs({ -1, 1 }) do
					count += 1
					local off = ROAD + 2
					local p: Vector3
					local yaw: number
					if ax == 0 then
						p = Vector3.new(side * off, 0.5, az * d)
						yaw = side > 0 and 0 or 180
					else
						p = Vector3.new(ax * d, 0.5, side * off)
						yaw = side > 0 and -90 or 90
					end
					lamp(root:within(CFrame.new(p) * CFrame.Angles(0, math.rad(yaw), 0)), count % 2 == 0)
					local t = ax == 0 and Vector3.new(side * (off + 4), 0.5, az * (d + 15))
						or Vector3.new(ax * (d + 15), 0.5, side * (off + 4))
					if clear(t) then
						tree(root:within(CFrame.new(t)), count)
					end
					if count % 4 == 1 then
						local h = ax == 0 and Vector3.new(side * (off + 1), 0.5, az * (d + 6))
							or Vector3.new(ax * (d + 6), 0.5, side * (off + 1))
						if clear(h) then
							hydrant(root:within(CFrame.new(h)))
						end
					elseif count % 4 == 3 then
						local h = ax == 0 and Vector3.new(side * (off + 1), 0.5, az * (d + 8))
							or Vector3.new(ax * (d + 8), 0.5, side * (off + 1))
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
	storefront(root:within(CFrame.new(ROAD + WALK + 2, 0.5, -64)), "ZEE GUNS", "Gun Shop", NEON_GREEN, "GunShop",
		"Browse guns", 34, 40)
	storefront(root:within(CFrame.new(ROAD + WALK + 2, 0.5, -110)), "ARMORY", "Attachments & Camos", NEON_GOLD, "Armory",
		"Customise", 34, 40)
	carPark(root, ROAD + WALK + 2, 64, -186, -136, 4)
	for _, spec in ipairs({
		{ 68, 108, -150, -34, 30, 1 }, { 108, 148, -150, -34, 44, 3 }, { 148, 186, -150, -34, 26, 5 },
		{ 68, 128, -186, -154, 22, 2 }, { 128, 186, -186, -154, 36, 6 },
	}) do
		building(root, spec[1], spec[2], spec[3], spec[4], spec[5], FACADE[spec[6]], { "all" }, spec[1] + spec[3])
	end

	-- South-west: ZEE GAS on the corner, the 24/7 behind it, a car park, offices.
	gasStation(root:within(CFrame.new(-(ROAD + WALK + 26), 0, -52)))
	convenience(root:within(CFrame.new(-(ROAD + WALK + 52), 0.5, -52)))
	carPark(root, -76, -(ROAD + WALK + 2), -132, -80, 5)
	for _, spec in ipairs({
		{ -186, -110, -72, -34, 40, 4 }, { -186, -110, -150, -76, 28, 2 }, { -106, -80, -150, -76, 24, 6 },
		{ -186, -120, -186, -154, 34, 3 }, { -120, -34, -186, -140, 26, 1 },
	}) do
		building(root, spec[1], spec[2], spec[3], spec[4], spec[5], FACADE[spec[6]], { "all" }, spec[2] + spec[4])
	end

	-- North-west: the DUEL HALL, open to the avenue, a pocket park on the corner.
	duelHall(root:within(CFrame.new(-(ROAD + WALK + 4), 0.5, 88)))
	pocketPark(root:within(CFrame.new(-64, 0.5, 45)))
	for _, spec in ipairs({
		{ -186, -150, 34, 110, 50, 5 }, { -186, -150, 110, 186, 38, 1 }, { -146, -104, 34, 120, 34, 4 },
		{ -146, -104, 124, 186, 26, 2 }, { -96, -62, 124, 186, 32, 3 }, { -62, -34, 124, 150, 24, 6 },
	}) do
		building(root, spec[1], spec[2], spec[3], spec[4], spec[5], FACADE[spec[6]], { "all" }, spec[1] - spec[3])
	end

	-- North-east: the court, the apartments with the fire escape, offices round them.
	court(root:within(CFrame.new(ROAD + WALK + 26, 0.5, 80)))
	apartments(root:within(CFrame.new(ROAD + WALK + 60, 0.5, 80)))
	for _, spec in ipairs({
		{ 34, 76, 118, 186, 40, 6 }, { 76, 130, 118, 186, 28, 1 }, { 130, 186, 118, 186, 52, 3 },
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
		root:part("Bridge", Vector3.new(40, 60, ROAD * 2 + WALK * 2 + 4), Vector3.new(s * (HW + 10), 45, 0),
			FACADE[3], M.Concrete)
		root:decor("Tunnel", Vector3.new(4, 14, ROAD * 2), Vector3.new(s * (HW - 8), 7, 0), Color3.fromRGB(10, 10, 12),
			M.SmoothPlastic)
		root:part("TunnelWall", Vector3.new(4, 15, 2), Vector3.new(s * (HW - 8), 7.5, ROAD + 1), FACADE[3], M.Concrete)
		root:part("TunnelWall", Vector3.new(4, 15, 2), Vector3.new(s * (HW - 8), 7.5, -ROAD - 1), FACADE[3], M.Concrete)
		root:part("TunnelBlock", Vector3.new(2, 14, ROAD * 2), Vector3.new(s * (HW - 5), 7, 0), Color3.fromRGB(10, 10, 12),
			nil, { transparency = 1 })
		for z = -ROAD + 3, ROAD - 3, 6 do
			root:neon("TunnelLight", Vector3.new(0.2, 0.4, 2), Vector3.new(s * (HW - 10.1), 13, z), WARM)
		end
	end

	-- A far skyline ring beyond, for the horizon.
	local sky = root:folder("Skyline")
	for k = 0, 27 do
		local a = k / 28 * math.pi * 2
		local r = 330 + (k % 3) * 40
		local x, z = math.cos(a) * r, math.sin(a) * r
		local w = 34 + (k * 11) % 20
		building(sky, x - w / 2, x + w / 2, z - w / 2, z + w / 2, 120 + ((k * 37) % 6) * 30, FACADE[(k % #FACADE) + 1],
			{ math.abs(x) > math.abs(z) and (x > 0 and "-x" or "+x") or (z > 0 and "-z" or "+z") }, 100 + k)
	end

	-- The edge: nothing to fall off.
	Kit.Bounds(root, HW - 12, HW - 12, 200)
end

return Downtown
