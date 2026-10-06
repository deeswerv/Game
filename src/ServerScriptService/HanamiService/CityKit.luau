--!strict
-- The pieces HANAMI CITY is built from (HanamiService.City lays them out).
--
-- A Japanese city in the game's painted low-poly look: narrow mid-rise buildings in pale tile
-- and painted render, each floor a little different -- an office band of glass, a block of
-- flats with a balcony per floor and the washing out, a "zakkyo" building with a sign for every
-- tenant and a tall vertical sign hung off its corner -- over a ground floor that is always a
-- shop: glass, a rolled-down shutter, a wooden front with noren curtains, a konbini's bright
-- window. On the street: utility poles strung with wires, vending machines, bicycles, curve
-- mirrors, paper lanterns, cherry trees.
--
-- Every building is drawn in its own frame: its street face is the plane z = 0 and it looks
-- down -Z, `w` wide along X (centred) and `d` deep toward +Z, standing on y = 0. Place one with
-- `CityKit.At(builder, x, z, facing)`. Decoration is `decor` (no collision, no raycasts); the
-- body of every building, every pole and every vehicle is a solid part, so cover is real.

local ServerScriptService = game:GetService("ServerScriptService")

local Kit = require(ServerScriptService.ArenaService.Kit)

local CityKit = {}

type B = Kit.Builder
local M = Enum.Material

-- ------------------------------------------------------------------ palette --

local P = {
	ROAD = Color3.fromRGB(86, 88, 96),
	ROAD_DARK = Color3.fromRGB(72, 74, 82),
	LINE = Color3.fromRGB(240, 238, 230),
	LINE_YELLOW = Color3.fromRGB(240, 196, 58),
	WALK = Color3.fromRGB(206, 200, 190),
	WALK_DARK = Color3.fromRGB(184, 178, 170),
	TACTILE = Color3.fromRGB(246, 204, 60),
	KERB = Color3.fromRGB(222, 218, 210),
	CONCRETE = Color3.fromRGB(176, 176, 172),
	CONCRETE_DARK = Color3.fromRGB(140, 140, 138),
	STONE = Color3.fromRGB(190, 184, 172),
	STONE_DARK = Color3.fromRGB(132, 128, 124),
	GRAVEL = Color3.fromRGB(214, 206, 190),
	STEEL = Color3.fromRGB(124, 130, 140),
	IRON = Color3.fromRGB(52, 56, 64),
	FRAME = Color3.fromRGB(70, 74, 82),
	FRAME_LIGHT = Color3.fromRGB(214, 214, 210),
	GLASS = Color3.fromRGB(120, 160, 190),
	GLASS_DARK = Color3.fromRGB(78, 106, 132),
	GLASS_TEAL = Color3.fromRGB(96, 168, 176),
	INTERIOR = Color3.fromRGB(62, 50, 44),
	INTERIOR_LIT = Color3.fromRGB(246, 236, 210),
	SHUTTER = Color3.fromRGB(176, 180, 184),
	WOOD = Color3.fromRGB(116, 78, 52),
	WOOD_DARK = Color3.fromRGB(70, 46, 34),
	WOOD_LIGHT = Color3.fromRGB(196, 150, 104),
	PAPER = Color3.fromRGB(250, 242, 220),
	PLASTER = Color3.fromRGB(246, 240, 228),
	TILE_ROOF = Color3.fromRGB(62, 68, 86),
	TILE_ROOF_EDGE = Color3.fromRGB(44, 48, 62),
	VERMILION = Color3.fromRGB(222, 70, 48),
	LANTERN = Color3.fromRGB(228, 66, 54),
	GOLD = Color3.fromRGB(236, 190, 80),
	SAKURA = Color3.fromRGB(246, 176, 202),
	SAKURA_LIGHT = Color3.fromRGB(252, 212, 226),
	SAKURA_DEEP = Color3.fromRGB(232, 132, 170),
	LEAF = Color3.fromRGB(96, 158, 84),
	LEAF_DARK = Color3.fromRGB(66, 124, 70),
	PINE = Color3.fromRGB(58, 108, 74),
	BARK = Color3.fromRGB(88, 62, 48),
	WATER = Color3.fromRGB(78, 156, 186),
	CREAM = Color3.fromRGB(250, 244, 226),
	BLACK = Color3.fromRGB(30, 32, 38),
	WHITE = Color3.fromRGB(248, 248, 246),
	KURO = Color3.fromRGB(34, 36, 44),
	CRIMSON = Color3.fromRGB(170, 38, 46),
}
CityKit.P = P

-- Facade colours: pale tile and painted render, the city's mid-tones.
CityKit.FACADES = {
	Color3.fromRGB(242, 236, 224), Color3.fromRGB(230, 214, 190), Color3.fromRGB(204, 206, 210),
	Color3.fromRGB(236, 204, 200), Color3.fromRGB(196, 224, 212), Color3.fromRGB(240, 226, 176),
	Color3.fromRGB(196, 132, 108), Color3.fromRGB(160, 116, 96), Color3.fromRGB(184, 208, 228),
	Color3.fromRGB(222, 222, 216), Color3.fromRGB(214, 186, 156), Color3.fromRGB(176, 182, 196),
}
-- Sign colours: bright and saturated, never neon.
CityKit.SIGNS = {
	Color3.fromRGB(220, 52, 52), Color3.fromRGB(250, 204, 44), Color3.fromRGB(40, 96, 204),
	Color3.fromRGB(36, 156, 92), Color3.fromRGB(244, 128, 34), Color3.fromRGB(132, 72, 176),
	Color3.fromRGB(236, 86, 150), Color3.fromRGB(28, 30, 36), Color3.fromRGB(248, 248, 244),
	Color3.fromRGB(30, 160, 190),
}

local function darker(c: Color3, t: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), t)
end
local function lighter(c: Color3, t: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), t)
end
CityKit.Darker, CityKit.Lighter = darker, lighter

--- Black or white, whichever reads on `bg`.
local function ink(bg: Color3): Color3
	local l = 0.3 * bg.R + 0.59 * bg.G + 0.11 * bg.B
	return if l > 0.62 then Color3.fromRGB(28, 30, 36) else Color3.fromRGB(252, 250, 244)
end
CityKit.Ink = ink

local function vertical(at: Vector3): CFrame
	return CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
end
CityKit.Vertical = vertical

--- A builder at (x, z) on the ground whose -Z (a building's street face) looks `facing`:
--- "-z", "+z", "-x" or "+x".
function CityKit.At(b: B, x: number, z: number, facing: string, y: number?): B
	local yaw = if facing == "+z" then math.pi elseif facing == "+x" then -math.pi / 2 elseif facing == "-x" then math.pi / 2 else 0
	return b:within(CFrame.new(x, y or 0, z) * CFrame.Angles(0, yaw, 0))
end

--- Written top to bottom: one character a line (for the tall signs).
local function stacked(text: string): string
	local out = {}
	for _, code in utf8.codes(text) do
		local ch = utf8.char(code)
		if ch == "ー" then
			ch = "｜"
		end
		table.insert(out, ch)
	end
	return table.concat(out, "\n")
end
CityKit.Stacked = stacked

--- Lettering on a surface; `at` looks the way it is read from.
function CityKit.Text(b: B, text: string, at: CFrame, w: number, h: number, colour: Color3, font: Enum.Font?): BasePart
	return b:sign(text, at, w, h, colour, { lit = true, glow = false, font = font or Enum.Font.GothamBlack,
		textColour = colour, brightness = 1 })
end
local text = CityKit.Text

--- A sign board on the front face of whatever is behind (0, y, 0): `w` x `h`, `deep` proud of
--- the face, lettering on it.
function CityKit.Board(b: B, label: string, x: number, y: number, w: number, h: number, bg: Color3, fg: Color3?,
	deep: number?, font: Enum.Font?): BasePart
	local dz = deep or 0.4
	local panel = b:decor("SignBoard", Vector3.new(w, h, dz), Vector3.new(x, y, -dz / 2), bg)
	text(b, label, CFrame.new(x, y, -dz - 0.06), w * 0.92, h * 0.8, fg or ink(bg), font)
	return panel
end
local board = CityKit.Board

-- ------------------------------------------------------------------ buildings --

export type Shop = {
	en: string?,          -- the shop's name in English, on the band over the window
	jp: string?,          -- and in Japanese, bigger (either or both)
	colour: Color3,       -- the band's colour
	kind: string?,        -- "glass" (default), "shutter", "noren", "konbini", "open", "lobby"
	awning: boolean?,
}

export type Spec = {
	w: number, d: number,
	floors: number,       -- floors above the ground floor
	style: string,        -- "tile", "mansion", "zakkyo", "office"
	colour: Color3,
	trim: Color3?,
	shop: Shop?,
	tenants: { string }?, -- zakkyo: a sign for each floor
	vsign: string?,       -- a tall sign hung off the front corner, written top to bottom
	vcolour: Color3?,
	vside: number?,       -- which corner: -1 left (as you face it), 1 right (default)
	roof: string?,        -- "flat" (default), "terrace" (walkable, railed, solid parapet)
	billboard: string?,   -- a painted board on a frame on the roof
	bcolour: Color3?,
	left: boolean?,       -- side faces that can be seen (windows on them)
	right: boolean?,
	back: boolean?,       -- the back can be seen too (a service lane): windows, units, pipes
	open: number?,        -- a terrace's side (-1 / 1) with no solid parapet (a ladder comes up there)
	sideShops: { Shop }?, -- shops on the ground floor of the sides you can see (a corner building)
	seed: number,
}

CityKit.GROUND = 10      -- the shop floor's height
CityKit.FLOOR = 7.5      -- every floor above

--- The height of a building with this many floors over the shop.
function CityKit.Height(floors: number): number
	return CityKit.GROUND + floors * CityKit.FLOOR
end

--- A window air-conditioner unit hung on a wall: its back against the plane z = 0 at (x, y).
local function acUnit(b: B, x: number, y: number)
	b:decor("AirUnit", Vector3.new(2.2, 1.6, 0.9), Vector3.new(x, y, -0.6), Color3.fromRGB(226, 226, 220))
	b:decor("AirFan", Vector3.new(0.12, 1.2, 1.2), CFrame.new(x - 0.3, y, -1.08) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(120, 124, 130), nil, { shape = "Cylinder" })
end
CityKit.AirUnit = acUnit

--- A shop's banner flag (nobori) on its pole, standing at the origin, its face to -Z.
function CityKit.Nobori(b: B, label: string, colour: Color3)
	b:part("NoboriPole", Vector3.new(0.25, 9, 0.25), Vector3.new(0, 4.5, 0), P.FRAME_LIGHT, nil, { collide = false, query = false })
	b:decor("NoboriArm", Vector3.new(1.9, 0.15, 0.15), Vector3.new(0.95, 8.8, 0), P.FRAME_LIGHT)
	local flag = b:decor("Nobori", Vector3.new(1.8, 6, 0.08), Vector3.new(1, 5.7, 0), colour, M.Fabric)
	flag.CastShadow = true
	b:decor("NoboriEdge", Vector3.new(1.8, 0.5, 0.1), Vector3.new(1, 8.4, 0), lighter(colour, 0.6), M.Fabric)
	text(b, stacked(label), CFrame.new(1, 5.5, -0.06), 1.4, 5, ink(colour), Enum.Font.GothamBlack)
end

--- The ground floor's shopfront across the face, `sw` wide.
local function shopfront(b: B, w: number, shop: Shop?, rng: Random, trim: Color3)
	local G = CityKit.GROUND
	local sw = w - 2.4
	local kind = if shop then shop.kind or "glass" else "glass"
	local function front(name: string, wide: number, tall: number, deep: number, x: number, y: number, c: Color3,
		material: Enum.Material?, opts: Kit.Opts?): BasePart
		return b:decor(name, Vector3.new(wide, tall, deep), Vector3.new(x, y, -deep / 2), c, material, opts)
	end
	-- Piers either side, and the sill under it all.
	front("Pier", 1.2, G, 0.6, -w / 2 + 0.6, G / 2, trim)
	front("Pier", 1.2, G, 0.6, w / 2 - 0.6, G / 2, trim)
	if kind == "glass" or kind == "konbini" or kind == "lobby" then
		local lit = kind == "konbini"
		front("Interior", sw, 6.8, 0.1, 0, 3.6, if lit then P.INTERIOR_LIT else P.INTERIOR)
		if kind ~= "lobby" then
			-- Shelves of goods behind the glass.
			for k, y in ipairs({ 2.2, 3.8, 5.2 }) do
				front("Goods", sw - 2, 0.7, 0.2, 0, y, CityKit.SIGNS[(rng:NextInteger(1, #CityKit.SIGNS) + k) % #CityKit.SIGNS + 1])
			end
		end
		front("ShopGlass", sw, 6.6, 0.3, 0, 3.7, P.GLASS, M.Glass, { transparency = 0.55, reflectance = 0.12 })
		local n = math.max(1, math.floor(sw / 5))
		for k = 1, n - 1 do
			front("Mullion", 0.3, 6.6, 0.4, -sw / 2 + k * sw / n, 3.7, P.FRAME)
		end
		front("Kick", sw, 0.7, 0.4, 0, 0.35, P.FRAME)
		front("Transom", sw, 0.4, 0.4, 0, 7.15, P.FRAME)
		-- The door: a darker pane with a push bar.
		local dx = if n > 1 then -sw / 2 + sw / n / 2 else 0
		front("DoorBar", 1.6, 0.2, 0.5, dx, 3.4, P.FRAME_LIGHT)
	elseif kind == "shutter" then
		-- A roller shutter, half up: the shop's dark mouth under it.
		local up = rng:NextNumber() < 0.5
		front("Interior", sw, 6.8, 0.1, 0, 3.6, P.INTERIOR)
		local h = if up then 3.6 else 7
		front("Shutter", sw, h, 0.3, 0, 7.2 - h / 2, P.SHUTTER, M.DiamondPlate)
		front("ShutterBox", sw + 0.4, 0.8, 0.6, 0, 7.6, darker(P.SHUTTER, 0.2))
		for k = 1, 3 do
			front("ShutterRib", sw, 0.12, 0.36, 0, 7.2 - h * k / 4, darker(P.SHUTTER, 0.25))
		end
	elseif kind == "noren" then
		-- A wooden front, a doorway with a noren curtain, a paper window.
		front("Wood", sw, 7.2, 0.2, 0, 3.6, P.WOOD)
		local dx = -sw / 4
		front("Doorway", 4, 6.4, 0.3, dx, 3.2, P.INTERIOR)
		for k = -1, 1 do
			local cloth = b:decor("Noren", Vector3.new(1.25, 2.4, 0.1), Vector3.new(dx + k * 1.3, 5.2, -0.6),
				if shop then shop.colour else P.KURO, M.Fabric)
			cloth.CastShadow = true
		end
		front("NorenRod", 4.4, 0.18, 0.7, dx, 6.45, P.WOOD_DARK)
		local wx = sw / 4
		front("Paper", sw / 2 - 1.6, 3.6, 0.3, wx, 4.4, P.PAPER)
		for k = -2, 2 do
			front("Slat", 0.18, 3.6, 0.4, wx + k * (sw / 2 - 1.6) / 5, 4.4, P.WOOD_DARK)
		end
	elseif kind == "open" then
		-- Open to the street: the dark shop, and its goods out on tables in front.
		front("Interior", sw, 6.8, 0.1, 0, 3.6, P.INTERIOR)
		for k = 0, 1 do
			local x = (k - 0.5) * sw * 0.5
			b:part("GoodsTable", Vector3.new(sw * 0.42, 2.4, 2.4), Vector3.new(x, 1.2, -1.6), P.WOOD, M.WoodPlanks)
			for j = 0, 3 do
				b:decor("Crate", Vector3.new(sw * 0.09, 0.7, 1.8), Vector3.new(x - sw * 0.15 + j * sw * 0.1, 2.75, -1.6),
					({ Color3.fromRGB(232, 92, 60), Color3.fromRGB(250, 196, 70), Color3.fromRGB(120, 180, 80),
						Color3.fromRGB(240, 140, 60) })[j + 1])
			end
		end
	end
	-- A banner flag or two out on the pavement.
	if shop and shop.jp and kind ~= "konbini" and rng:NextNumber() < 0.45 then
		local fx = (if rng:NextNumber() < 0.5 then -1 else 1) * (w / 2 - 1.6)
		CityKit.Nobori(b:within(CFrame.new(fx, 0, -2.2)), shop.jp, lighter(shop.colour, 0.05))
	end
	-- The band over the window, with the shop's name on it.
	if shop then
		local bandH = 2.4
		b:decor("SignBand", Vector3.new(w - 0.6, bandH, 0.7), Vector3.new(0, 8.6, -0.35), shop.colour)
		local fg = ink(shop.colour)
		if shop.jp and shop.en then
			-- (Local +X is on the left of somebody facing the front: the Japanese reads first.)
			text(b, shop.jp, CFrame.new(w * 0.18, 8.6, -0.76), w * 0.5, bandH * 0.78, fg, Enum.Font.GothamBlack)
			text(b, shop.en, CFrame.new(-w * 0.27, 8.6, -0.76), w * 0.38, bandH * 0.5, fg, Enum.Font.GothamBold)
		else
			text(b, shop.jp or shop.en or "", CFrame.new(0, 8.6, -0.76), w * 0.8, bandH * 0.74, fg, Enum.Font.GothamBlack)
		end
		if shop.awning then
			local a = b:decor("Awning", Vector3.new(sw, 1.1, 2.6), CFrame.new(0, 6.95, -1.3), lighter(shop.colour, 0.08), M.Fabric,
				{ shape = "Wedge" })
			a.CastShadow = true
		end
	else
		b:decor("Course", Vector3.new(w, 1.2, 0.5), Vector3.new(0, 8.2, -0.25), trim)
	end
	b:decor("Course", Vector3.new(w - 0.04, 0.5, 0.8), Vector3.new(0, G - 0.25, -0.4), trim)
end

--- A building (see Spec). Returns its height.
function CityKit.Building(b: B, s: Spec): number
	local w, d = s.w, s.d
	local G, F = CityKit.GROUND, CityKit.FLOOR
	local top = G + s.floors * F
	local rng = Random.new(s.seed)
	local wall = s.colour
	local trim = s.trim or darker(wall, 0.16)
	b:part("Building", Vector3.new(w, top + 1, d), Vector3.new(0, (top - 1) / 2, d / 2), wall)

	local function front(name: string, wide: number, tall: number, deep: number, x: number, y: number, c: Color3,
		material: Enum.Material?, opts: Kit.Opts?): BasePart
		return b:decor(name, Vector3.new(wide, tall, deep), Vector3.new(x, y, -deep / 2), c, material, opts)
	end

	shopfront(b, w, s.shop, rng, trim)

	-- The floors above.
	local style = s.style
	local tenants = s.tenants or {}
	local glassTint = if rng:NextNumber() < 0.5 then P.GLASS else P.GLASS_DARK
	for i = 1, s.floors do
		local y0 = G + (i - 1) * F
		if style == "mansion" then
			-- A balcony per floor: slab, a solid front, a rail; sliding doors behind; washing
			-- out on some, an air unit on others.
			front("Windows", w - 3, 5, 0.2, 0, y0 + 3.3, glassTint, M.Glass, { reflectance = 0.12 })
			local slab = b:decor("Balcony", Vector3.new(w - 0.6, 0.5, 2.6), Vector3.new(0, y0 + 0.25, -1.3), trim)
			slab.CastShadow = true
			b:decor("BalconyFront", Vector3.new(w - 0.6, 2.2, 0.25), Vector3.new(0, y0 + 1.6, -2.48),
				if i % 2 == 0 then lighter(wall, 0.25) else darker(wall, 0.06))
			b:decor("BalconyRail", Vector3.new(w - 0.4, 0.2, 0.4), Vector3.new(0, y0 + 2.8, -2.48), P.FRAME_LIGHT)
			if w >= 14 then
				b:decor("Partition", Vector3.new(0.3, 3.6, 2.4), Vector3.new(0, y0 + 2.2, -1.3), trim)
			end
			local roll = rng:NextNumber()
			if roll < 0.35 then
				-- Washing on a pole.
				local x = rng:NextNumber(-w / 4, w / 4)
				b:decor("LaundryPole", Vector3.new(w * 0.4, 0.14, 0.14), Vector3.new(x, y0 + 5, -1.6), P.STEEL)
				for k = -1, 1 do
					b:decor("Laundry", Vector3.new(1.4, 1.8, 0.1), Vector3.new(x + k * 2, y0 + 4.1, -1.6),
						CityKit.SIGNS[rng:NextInteger(1, #CityKit.SIGNS)], M.Fabric)
				end
			elseif roll < 0.7 then
				local x = (if rng:NextNumber() < 0.5 then -1 else 1) * (w / 2 - 2.6)
				b:decor("AirUnit", Vector3.new(2.2, 1.6, 0.9), Vector3.new(x, y0 + 1.3, -1.2), Color3.fromRGB(226, 226, 220))
				b:decor("AirFan", Vector3.new(0.12, 1.2, 1.2), CFrame.new(x - 0.3, y0 + 1.3, -1.68) * CFrame.Angles(0, math.rad(90), 0),
					Color3.fromRGB(120, 124, 130), nil, { shape = "Cylinder" })
			end
		elseif style == "zakkyo" then
			-- A window and a tenant's sign on every floor.
			local tc = CityKit.SIGNS[(s.seed + i * 3) % #CityKit.SIGNS + 1]
			front("Windows", w * 0.62, 3.6, 0.2, -w * 0.1, y0 + 4.4, glassTint, M.Glass, { reflectance = 0.12 })
			front("WindowFrame", w * 0.62 + 0.6, 0.4, 0.35, -w * 0.1, y0 + 6.3, trim)
			local label = tenants[i]
			if label then
				b:decor("Tenant", Vector3.new(w - 1.4, 1.7, 0.5), Vector3.new(0, y0 + 1.4, -0.25), tc)
				text(b, label, CFrame.new(0, y0 + 1.4, -0.56), w * 0.8, 1.3, ink(tc), Enum.Font.GothamBlack)
			else
				front("Band", w, 0.6, 0.3, 0, y0 + 0.4, trim)
			end
			if rng:NextNumber() < 0.4 then
				acUnit(b, w * 0.34, y0 + 4)
			end
		elseif style == "office" then
			-- (the glass is one sheet, below) a mullion band at each floor
			front("Band", w - 0.6, 0.7, 0.5, 0, y0 + 0.35, trim)
		else -- "tile": a band of windows per floor, a sill under it
			front("Windows", w - 3, 3.8, 0.2, 0, y0 + 4.2, glassTint, M.Glass, { reflectance = 0.12 })
			local n = math.max(2, math.floor((w - 3) / 5))
			for k = 1, n - 1 do
				front("Mullion", 0.35, 3.8, 0.32, -(w - 3) / 2 + k * (w - 3) / n, y0 + 4.2, P.FRAME_LIGHT)
			end
			front("Sill", w - 2.4, 0.4, 0.6, 0, y0 + 2.1, trim)
			if rng:NextNumber() < 0.3 then
				acUnit(b, (if rng:NextNumber() < 0.5 then -1 else 1) * (w / 2 - 2), y0 + 1)
			end
		end
	end
	if style == "office" and s.floors > 0 then
		local h = s.floors * F - 0.8
		front("Windows", w - 1.2, h, 0.25, 0, G + h / 2 + 0.4, P.GLASS_TEAL, M.Glass, { reflectance = 0.2 })
		local n = math.max(2, math.floor(w / 4))
		for k = 0, n do
			front("Fin", 0.45, h, 0.7, -(w - 1.2) / 2 + k * (w - 1.2) / n, G + h / 2 + 0.4, P.FRAME_LIGHT)
		end
	end

	-- The sides you can see: a column of windows each floor, and a drainpipe up the corner.
	for _, side in ipairs({ -1, 1 }) do
		local seen = if side < 0 then s.left else s.right
		if seen and s.floors > 0 then
			-- The side, drawn as a front: its own frame looking out sideways.
			local sb = b:within(CFrame.new(side * w / 2, 0, d / 2) * CFrame.Angles(0, -side * math.pi / 2, 0))
			local span = d - 4
			for i = 1, s.floors do
				local y0 = G + (i - 1) * F
				if style == "office" then
					sb:decor("Windows", Vector3.new(span, F - 1.6, 0.2), Vector3.new(0, y0 + F / 2 + 0.3, -0.1), P.GLASS_TEAL, M.Glass,
						{ reflectance = 0.15 })
					sb:decor("Band", Vector3.new(span + 2, 0.7, 0.4), Vector3.new(0, y0 + 0.35, -0.2), trim)
				else
					sb:decor("Windows", Vector3.new(span, 3.2, 0.2), Vector3.new(0, y0 + 4.2, -0.1), glassTint, M.Glass, { reflectance = 0.1 })
					local n = math.max(2, math.floor(span / 9))
					for k = 1, n - 1 do
						sb:decor("Mullion", Vector3.new(0.35, 3.2, 0.3), Vector3.new(-span / 2 + k * span / n, y0 + 4.2, -0.15), P.FRAME_LIGHT)
					end
					sb:decor("Sill", Vector3.new(span + 0.6, 0.35, 0.5), Vector3.new(0, y0 + 2.4, -0.25), trim)
				end
				if rng:NextNumber() < 0.18 then
					acUnit(sb, (if rng:NextNumber() < 0.5 then -1 else 1) * span * 0.3, y0 + 1.2)
				end
			end
			-- The ground floor's side: on a corner, more shops; otherwise a band and a window.
			local shops = s.sideShops
			if shops and #shops > 0 and d >= 14 then
				local n = math.max(1, math.floor(d / 14))
				local sw2 = d / n
				for k = 1, n do
					local cell = sb:within(CFrame.new(-d / 2 + sw2 * (k - 0.5), 0, 0))
					shopfront(cell, sw2, shops[(k - 1) % #shops + 1], rng, trim)
				end
			else
				sb:decor("SideBase", Vector3.new(d - 0.4, G - 1, 0.15), Vector3.new(0, (G - 1) / 2, -0.07), darker(wall, 0.1))
				sb:decor("SideWindow", Vector3.new(span * 0.5, 3.6, 0.25), Vector3.new(-span * 0.15, 4.6, -0.12), glassTint, M.Glass)
			end
			b:decor("Drainpipe", Vector3.new(top, 0.5, 0.5), vertical(Vector3.new(side * (w / 2 + 0.3), top / 2, 0.6)), P.CONCRETE_DARK,
				nil, { shape = "Cylinder" })
		end
	end

	-- A back you can see (onto a service lane): a window per floor, air units, a pipe.
	if s.back and s.floors > 0 then
		local back = b:within(CFrame.new(0, 0, d) * CFrame.Angles(0, math.pi, 0))
		back:decor("BackWall", Vector3.new(w - 0.4, G - 1, 0.2), Vector3.new(0, (G - 1) / 2, -0.1), darker(wall, 0.12))
		back:decor("BackDoor", Vector3.new(2.6, 6, 0.3), Vector3.new(w * 0.25, 3, -0.15), P.FRAME)
		for i = 1, s.floors do
			local y0 = G + (i - 1) * F
			back:decor("Windows", Vector3.new(math.min(w * 0.4, 6), 2.8, 0.2), Vector3.new(-w * 0.2, y0 + 4.2, -0.1), glassTint, M.Glass)
			if rng:NextNumber() < 0.3 then
				acUnit(back, w * 0.22, y0 + 1.4)
			end
		end
		back:decor("Drainpipe", Vector3.new(top, 0.5, 0.5), vertical(Vector3.new(w / 2 - 0.8, top / 2, -0.3)), P.CONCRETE_DARK, nil,
			{ shape = "Cylinder" })
		acUnit(back, -w * 0.3, 2.2)
	end

	-- The tall sign off the corner, out over the street, read from both ways along it.
	if s.vsign and s.floors > 0 then
		local side = s.vside or 1
		local vc = s.vcolour or CityKit.SIGNS[s.seed % #CityKit.SIGNS + 1]
		local h = math.min(s.floors * F - 1, 6 + utf8.len(s.vsign) :: number * 3.4)
		local x = side * (w / 2 - 1.2)
		local y = G + 1 + h / 2
		local panel = b:decor("TallSign", Vector3.new(0.8, h, 3), Vector3.new(x, y, -1.7), vc)
		panel.CastShadow = true
		b:decor("TallSignTrim", Vector3.new(0.9, 0.4, 3.2), Vector3.new(x, y + h / 2 + 0.2, -1.7), darker(vc, 0.35))
		b:decor("TallSignTrim", Vector3.new(0.9, 0.4, 3.2), Vector3.new(x, y - h / 2 - 0.2, -1.7), darker(vc, 0.35))
		local fg = ink(vc)
		for _, dir in ipairs({ -1, 1 }) do
			text(b, stacked(s.vsign), CFrame.new(x + dir * 0.46, y, -1.7) * CFrame.Angles(0, dir * math.pi / 2, 0) * CFrame.Angles(0, math.pi, 0),
				2.4, h * 0.94, fg, Enum.Font.GothamBlack)
		end
		b:decor("TallSignArm", Vector3.new(0.3, 0.3, 3.4), Vector3.new(x, y + h / 2 + 0.8, -1.7), P.STEEL)
	end

	-- The roof: a parapet, and what sits on a city roof.
	local terrace = s.roof == "terrace"
	local pOpts: Kit.Opts? = if terrace then nil else { collide = false, query = false, shadow = true }
	local ph = if terrace then 3.4 else 1.4
	local function parapet(size: Vector3, at: Vector3)
		if terrace then
			b:part("Parapet", size, at, trim)
		else
			b:part("Parapet", size, at, trim, nil, pOpts)
		end
	end
	parapet(Vector3.new(w, ph, 0.6), Vector3.new(0, top + ph / 2, 0.3))
	parapet(Vector3.new(w, ph, 0.6), Vector3.new(0, top + ph / 2, d - 0.3))
	for _, side in ipairs({ -1, 1 }) do
		if terrace and s.open == side then
			-- The side a ladder comes up: a low kerb to see, nothing to stop you.
			b:decor("Parapet", Vector3.new(0.6, 0.6, d - 1.2), Vector3.new(side * (w / 2 - 0.3), top + 0.3, d / 2), trim)
		else
			parapet(Vector3.new(0.6, ph, d - 1.2), Vector3.new(side * (w / 2 - 0.3), top + ph / 2, d / 2))
		end
	end
	if terrace then
		b:decor("Rail", Vector3.new(w, 0.2, 0.3), Vector3.new(0, top + ph + 0.9, 0.3), P.FRAME_LIGHT)
		b:decor("RoofDeck", Vector3.new(w - 1.4, 0.1, d - 1.4), Vector3.new(0, top + 0.05, d / 2), Color3.fromRGB(150, 156, 150))
	else
		b:decor("RoofDeck", Vector3.new(w - 1.2, 0.1, d - 1.2), Vector3.new(0, top + 0.05, d / 2), Color3.fromRGB(164, 168, 166))
	end
	-- Something on it: a water tank on its stand, air units, a stair hut, an aerial.
	if not terrace then
		local pick = rng:NextInteger(1, 4)
		local rx = rng:NextNumber(-w / 4, w / 4)
		local rz = d * rng:NextNumber(0.45, 0.7)
		if pick == 1 and w >= 10 then
			b:decor("TankStand", Vector3.new(4, 2.4, 4), Vector3.new(rx, top + 1.2, rz), P.STEEL, M.DiamondPlate)
			b:decor("Tank", Vector3.new(4.6, 4.6, 4.6), vertical(Vector3.new(rx, top + 4.7, rz)), Color3.fromRGB(226, 232, 236), nil,
				{ shape = "Cylinder" })
			b:decor("TankBand", Vector3.new(0.4, 4.8, 4.8), vertical(Vector3.new(rx, top + 5.6, rz)), Color3.fromRGB(70, 120, 180), nil,
				{ shape = "Cylinder" })
		elseif pick == 2 then
			for k = 0, math.min(2, math.floor(w / 6)) do
				local x = -w / 2 + 3 + k * 3
				b:decor("RoofUnit", Vector3.new(2.6, 2, 2), Vector3.new(x, top + 1, d - 2.4), Color3.fromRGB(222, 222, 216))
				b:decor("AirFan", Vector3.new(0.12, 1.5, 1.5), CFrame.new(x, top + 1, d - 3.46) * CFrame.Angles(0, math.rad(90), 0),
					Color3.fromRGB(110, 114, 120), nil, { shape = "Cylinder" })
			end
		elseif pick == 3 and w >= 9 then
			b:decor("StairHut", Vector3.new(5, 4.6, 5), Vector3.new(-w / 2 + 3.6, top + 2.3, d - 3.6), darker(wall, 0.08))
			b:decor("HutRoof", Vector3.new(5.6, 0.5, 5.6), Vector3.new(-w / 2 + 3.6, top + 4.85, d - 3.6), trim)
		else
			b:decor("Aerial", Vector3.new(0.25, 6, 0.25), Vector3.new(rx, top + 3, rz), P.STEEL)
			for k = 0, 2 do
				b:decor("AerialBar", Vector3.new(2.4 - k * 0.5, 0.15, 0.15), Vector3.new(rx, top + 4 + k * 0.9, rz), P.STEEL)
			end
		end
	end
	-- A painted board on a frame, facing the street.
	if s.billboard then
		local bw = math.min(w - 2, 22)
		local bh = math.max(5, bw * 0.38)
		for _, x in ipairs({ -bw / 2 + 1, bw / 2 - 1 }) do
			b:decor("BillboardLeg", Vector3.new(0.5, 4 + bh, 0.5), Vector3.new(x, top + (4 + bh) / 2, 2.2), P.IRON)
			b:decor("BillboardBrace", Vector3.new(0.4, 0.4, 3.2), Vector3.new(x, top + 2.2, 3.4), P.IRON)
		end
		local bc = s.bcolour or CityKit.SIGNS[(s.seed * 7) % #CityKit.SIGNS + 1]
		local panel = b:decor("Billboard", Vector3.new(bw, bh, 0.6), Vector3.new(0, top + 4 + bh / 2, 1.8), bc)
		panel.CastShadow = true
		b:decor("BillboardFrame", Vector3.new(bw + 0.6, 0.5, 0.8), Vector3.new(0, top + 4 + bh + 0.25, 1.8), P.FRAME_LIGHT)
		b:decor("BillboardFrame", Vector3.new(bw + 0.6, 0.5, 0.8), Vector3.new(0, top + 3.75, 1.8), P.FRAME_LIGHT)
		text(b, s.billboard, CFrame.new(0, top + 4 + bh / 2, 1.44), bw * 0.9, bh * 0.7, ink(bc), Enum.Font.GothamBlack)
	end
	return top
end

--- An izakaya, a two-storey wooden shophouse (machiya): a slatted front, the noren over the
--- door, red lanterns either side, a tiled eave between the floors, a paper-screened window
--- above with its sign board, a gabled tile roof -- or a flat roof terrace with a rail (for
--- the ones you can climb onto, `terrace`). Returns its height.
export type IzakayaSpec = {
	w: number, d: number, seed: number, jp: string?, en: string?,
	noren: Color3?, wall: Color3?, terrace: boolean?, lanterns: boolean?, upper: boolean?,
	open: number?,        -- the terrace side (-1 / 1) left unrailed, for a ladder
	left: boolean?, right: boolean?,
}
function CityKit.Izakaya(b: B, s: IzakayaSpec): number
	local w, d = s.w, s.d
	local rng = Random.new(s.seed)
	local G = 9
	local twoStorey = s.upper ~= false
	local top = if twoStorey then 16.5 else G
	local wood = if rng:NextNumber() < 0.5 then P.WOOD else P.WOOD_DARK
	local upperWall = s.wall or (if rng:NextNumber() < 0.5 then P.PLASTER else Color3.fromRGB(226, 208, 176))
	b:part("Building", Vector3.new(w, top + 1, d), Vector3.new(0, (top - 1) / 2, d / 2), wood, M.Wood)
	local function front(name: string, wide: number, tall: number, deep: number, x: number, y: number, c: Color3,
		material: Enum.Material?, opts: Kit.Opts?): BasePart
		return b:decor(name, Vector3.new(wide, tall, deep), Vector3.new(x, y, -deep / 2), c, material, opts)
	end
	-- Ground floor: posts, the doorway and its noren, a slatted window.
	front("Post", 0.8, G, 0.6, -w / 2 + 0.4, G / 2, P.WOOD_DARK)
	front("Post", 0.8, G, 0.6, w / 2 - 0.4, G / 2, P.WOOD_DARK)
	local dx = if rng:NextNumber() < 0.5 then -w / 4 else w / 4
	front("Doorway", 3.8, 6.6, 0.25, dx, 3.3, Color3.fromRGB(96, 60, 40))
	front("DoorGlow", 3.2, 5.6, 0.3, dx, 2.9, Color3.fromRGB(246, 214, 160))
	local nc = s.noren or ({ Color3.fromRGB(40, 58, 110), P.CRIMSON, Color3.fromRGB(48, 96, 74), P.KURO })[rng:NextInteger(1, 4)]
	for k = -1, 1 do
		local cloth = b:decor("Noren", Vector3.new(1.22, 2.3, 0.1), Vector3.new(dx + k * 1.27, 5.5, -0.62), nc, M.Fabric)
		cloth.CastShadow = true
	end
	if s.jp then
		text(b, s.jp, CFrame.new(dx, 5.6, -0.69), 3.6, 1.7, P.WHITE, Enum.Font.GothamBlack)
	end
	front("NorenRod", 4.4, 0.18, 0.75, dx, 6.75, P.WOOD_DARK)
	local wx = -dx
	local ww = w / 2 - 2
	front("Paper", ww, 4.2, 0.3, wx, 4.2, P.PAPER)
	for k = 1, 3 do
		front("Slat", 0.2, 4.6, 0.42, wx - ww / 2 + k * ww / 4, 4.2, P.WOOD_DARK)
	end
	front("Sill", ww + 0.6, 0.4, 0.6, wx, 1.9, P.WOOD_DARK)
	-- Red lanterns either side of the door, and a standing sign board.
	if s.lanterns ~= false then
		for _, side in ipairs({ -1, 1 }) do
			CityKit.Chochin(b, Vector3.new(dx + side * 2.6, 7.7, -1.1), P.LANTERN, 1)
		end
	end
	if s.en then
		local sb = b:within(CFrame.new(wx + ww / 2 - 0.8, 0, -2.2))
		sb:part("StandSign", Vector3.new(1.4, 3.6, 0.5), Vector3.new(0, 1.8, 0), P.PAPER)
		sb:decor("StandSignFrame", Vector3.new(1.6, 3.8, 0.4), Vector3.new(0, 1.8, 0.1), P.WOOD_DARK)
		text(sb, stacked(s.en), CFrame.new(0, 1.9, -0.3), 1.2, 3.3, P.KURO, Enum.Font.GothamBlack)
	end
	-- The eave: a tiled skirt roof over the street.
	local eave = b:decor("Eave", Vector3.new(w + 0.8, 1.4, 3.2), CFrame.new(0, G + 0.5, -1.6), P.TILE_ROOF, M.Slate, { shape = "Wedge" })
	eave.CastShadow = true
	b:decor("EaveEdge", Vector3.new(w + 0.8, 0.35, 0.4), Vector3.new(0, G - 0.15, -3.1), P.TILE_ROOF_EDGE)
	if twoStorey then
		-- The upper floor: plaster, a latticed window, the shop's board.
		front("Upper", w - 0.4, top - G - 1.2, 0.15, 0, (top + G) / 2 + 0.4, upperWall)
		front("UpperWindow", w * 0.5, 3.4, 0.25, 0, G + 3.8, P.PAPER)
		for k = 1, 2 do
			front("Lattice", 0.2, 3.4, 0.36, -w * 0.25 + k * w * (0.5 / 3), G + 3.8, P.WOOD_DARK)
		end
		front("Lattice", w * 0.5, 0.18, 0.36, 0, G + 3.8, P.WOOD_DARK)
		front("Beam", w, 0.6, 0.5, 0, top - 0.6, P.WOOD_DARK)
		if s.jp and rng:NextNumber() < 0.6 then
			-- A hanging board off the upper storey.
			local x = (if dx < 0 then 1 else -1) * (w / 2 - 0.9)
			local hb = b:decor("HangingSign", Vector3.new(0.4, 4.2, 1.8), Vector3.new(x, G + 3.6, -1.2), P.WOOD_LIGHT)
			hb.CastShadow = true
			for _, dir in ipairs({ -1, 1 }) do
				text(b, stacked(s.jp), CFrame.new(x + dir * 0.23, G + 3.6, -1.2) * CFrame.Angles(0, dir * math.pi / 2, 0)
					* CFrame.Angles(0, math.pi, 0), 1.4, 3.9, P.KURO, Enum.Font.GothamBlack)
			end
		end
	end
	-- Sides you can see from an alley: a small paper window, an air unit, a pipe.
	for _, side in ipairs({ -1, 1 }) do
		if (side < 0 and s.left) or (side > 0 and s.right) then
			local sb = b:within(CFrame.new(side * w / 2, 0, d / 2) * CFrame.Angles(0, -side * math.pi / 2, 0))
			sb:decor("SideWindow", Vector3.new(3, 2.4, 0.2), Vector3.new(0, 5.4, -0.1), P.PAPER)
			sb:decor("SideWindowFrame", Vector3.new(3.4, 0.3, 0.3), Vector3.new(0, 6.7, -0.15), P.WOOD_DARK)
			if twoStorey then
				sb:decor("SideWindow", Vector3.new(2.4, 2, 0.2), Vector3.new(-d * 0.25, 13, -0.1), P.PAPER)
			end
			acUnit(sb, d * 0.28, 2.2)
			sb:decor("Drainpipe", Vector3.new(top, 0.4, 0.4), vertical(Vector3.new(-d / 2 + 0.6, top / 2, -0.25)), P.CONCRETE_DARK, nil,
				{ shape = "Cylinder" })
		end
	end
	if s.terrace then
		-- A flat roof you can stand on, railed round (but for a ladder's side).
		b:part("TerraceRail", Vector3.new(w, 3, 0.4), Vector3.new(0, top + 1.5, 0.2), P.WOOD_DARK, M.Wood)
		b:part("TerraceRail", Vector3.new(w, 3, 0.4), Vector3.new(0, top + 1.5, d - 0.2), P.WOOD_DARK, M.Wood)
		for _, side in ipairs({ -1, 1 }) do
			if s.open ~= side then
				b:part("TerraceRail", Vector3.new(0.4, 3, d), Vector3.new(side * (w / 2 - 0.2), top + 1.5, d / 2), P.WOOD_DARK, M.Wood)
			end
		end
		b:decor("TerraceDeck", Vector3.new(w - 0.8, 0.1, d - 0.8), Vector3.new(0, top + 0.05, d / 2), P.WOOD_LIGHT, M.WoodPlanks)
		-- Beer crates and a table, where the staff take their break.
		b:part("Crates", Vector3.new(2, 2, 2), Vector3.new(-w / 2 + 2, top + 1, d - 2.4), Color3.fromRGB(220, 170, 40))
	else
		-- A gable of dark tile, ridge along the street.
		local rise = 3.6
		local r1 = b:part("Roof", Vector3.new(w + 1, rise, d / 2 + 0.6), CFrame.new(0, top + rise / 2, d / 4 - 0.3), P.TILE_ROOF, M.Slate,
			{ shape = "Wedge" })
		r1.CastShadow = true
		local r2 = b:part("Roof", Vector3.new(w + 1, rise, d / 2 + 0.6), CFrame.new(0, top + rise / 2, d * 3 / 4 + 0.3)
			* CFrame.Angles(0, math.pi, 0), P.TILE_ROOF, M.Slate, { shape = "Wedge" })
		r2.CastShadow = true
		b:decor("Ridge", Vector3.new(w + 1.4, 0.7, 0.9), Vector3.new(0, top + rise + 0.2, d / 2), P.TILE_ROOF_EDGE)
	end
	return top
end

-- ------------------------------------------------------------------ props --

--- A red paper lantern (chochin) hanging with its middle at `at`, a character painted on it.
function CityKit.Chochin(b: B, at: Vector3, colour: Color3?, size: number?, mark: string?)
	local s = size or 1
	b:decor("Chochin", Vector3.new(1.7 * s, 1.2 * s, 1.2 * s), vertical(at), colour or P.LANTERN, nil, { shape = "Cylinder" })
	b:decor("ChochinCap", Vector3.new(0.24 * s, 0.8 * s, 0.8 * s), vertical(at + Vector3.new(0, 0.95 * s, 0)), P.KURO, nil,
		{ shape = "Cylinder" })

	if mark then
		text(b, mark, CFrame.new(at - Vector3.new(0, 0, 0.6 * s)), 0.9 * s, 0.9 * s, P.KURO, Enum.Font.GothamBlack)
	end
end

--- A string of lanterns between two points, sagging a little.
function CityKit.LanternString(b: B, a: Vector3, c: Vector3, count: number, colours: { Color3 }?)
	local mid = (a + c) / 2 - Vector3.new(0, 1.2, 0)
	for _, seg in ipairs({ { a, mid }, { mid, c } }) do
		local cf, len = Kit.Span(seg[1], seg[2])
		b:decor("Wire", Vector3.new(0.1, 0.1, len), cf, P.KURO)
	end
	for k = 1, count do
		local t = k / (count + 1)
		local p = if t < 0.5 then a:Lerp(mid, t * 2) else mid:Lerp(c, t * 2 - 1)
		local col = if colours then colours[(k - 1) % #colours + 1] else P.LANTERN
		CityKit.Chochin(b, p - Vector3.new(0, 1, 0), col, 0.62)
	end
end

--- A concrete utility pole on the ground at `at`, its cross-arm across X (or across Z,
--- `turned`). Returns where its wires hang from, in the same builder's space.
function CityKit.Pole(root: B, at: Vector3, height: number?, transformer: boolean?, turned: boolean?): { Vector3 }
	local h = height or 24
	local b = root:within(CFrame.new(at) * CFrame.Angles(0, if turned then math.pi / 2 else 0, 0))
	b:part("Pole", Vector3.new(h, 0.9, 0.9), vertical(Vector3.new(0, h / 2, 0)), P.CONCRETE, M.Concrete, { shape = "Cylinder" })
	b:decor("PoleBand", Vector3.new(1.4, 0.98, 0.98), vertical(Vector3.new(0, 2.2, 0)), P.LINE_YELLOW, nil, { shape = "Cylinder" })
	b:decor("PoleBand", Vector3.new(0.5, 0.98, 0.98), vertical(Vector3.new(0, 3.2, 0)), P.KURO, nil, { shape = "Cylinder" })
	b:decor("CrossArm", Vector3.new(5.2, 0.35, 0.35), Vector3.new(0, h - 1.4, 0), P.STEEL)
	b:decor("CrossArm", Vector3.new(3.6, 0.3, 0.3), Vector3.new(0, h - 3.6, 0), P.STEEL)

	if transformer then
		b:decor("Transformer", Vector3.new(2.6, 1.6, 1.6), vertical(Vector3.new(0, h - 6.6, 1.3)), Color3.fromRGB(150, 156, 160),
			nil, { shape = "Cylinder" })
		b:decor("TransformerCap", Vector3.new(0.3, 1.8, 1.8), vertical(Vector3.new(0, h - 5.15, 1.3)), Color3.fromRGB(120, 126, 130),
			nil, { shape = "Cylinder" })
	end
	b:decor("CableBox", Vector3.new(1, 1.4, 0.6), Vector3.new(0, h - 9, -0.7), Color3.fromRGB(200, 200, 196))
	local back = root.frame:Inverse() * b.frame
	return { back * Vector3.new(-2.3, h - 1, 0), back * Vector3.new(0, h - 1, 0), back * Vector3.new(2.3, h - 1, 0),
		back * Vector3.new(-1.6, h - 3.6, 0) }
end

--- Wires from one pole's hanging points to another's, sagging.
function CityKit.Wires(b: B, from: { Vector3 }, to: { Vector3 })
	for k = 1, math.min(#from, #to) do
		local a, c = from[k], to[k]
		local mid = (a + c) / 2 - Vector3.new(0, 1.4 + (a - c).Magnitude * 0.025, 0)
		for _, seg in ipairs({ { a, mid }, { mid, c } }) do
			local cf, len = Kit.Span(seg[1], seg[2])
			b:decor("Wire", Vector3.new(0.12, 0.12, len), cf, P.KURO)
		end
	end
end

--- A drinks vending machine, its front looking down -Z, its back on z = 0... standing on the
--- ground with its front at the origin.
function CityKit.Vending(b: B, colour: Color3, seed: number)
	b:part("Vending", Vector3.new(3, 6.4, 2.2), Vector3.new(0, 3.2, 1.1), colour)
	b:decor("LightPanel", Vector3.new(2.6, 2.8, 0.12), Vector3.new(0, 4.5, -0.05), Color3.fromRGB(246, 246, 240))
	local rng = Random.new(seed)
	for k, y in ipairs({ 3.6, 4.5, 5.4 }) do
		for j = 0, 2 do
			b:decor("Can", Vector3.new(0.5, 0.6, 0.14), Vector3.new(-0.8 + j * 0.8, y, -0.14),
				CityKit.SIGNS[(rng:NextInteger(1, 9) + k + j) % #CityKit.SIGNS + 1])
		end
	end
	b:decor("Buttons", Vector3.new(2.4, 0.2, 0.16), Vector3.new(0, 3.05, -0.12), P.IRON)
	b:decor("Slot", Vector3.new(2.2, 0.8, 0.2), Vector3.new(0, 0.9, -0.08), P.KURO)
	b:decor("VendingTop", Vector3.new(3, 0.7, 0.2), Vector3.new(0, 6.0, -0.08), darker(colour, 0.25))
end

--- A bicycle standing on the ground, front wheel toward -Z: the city's mamachari, basket and all.
function CityKit.Bike(b: B, colour: Color3)
	for _, z in ipairs({ -1.45, 1.45 }) do
		b:decor("Wheel", Vector3.new(0.18, 2.3, 2.3), Vector3.new(0, 1.15, z), P.KURO, nil, { shape = "Cylinder" })
	end
	b:part("BikeFrame", Vector3.new(0.25, 0.25, 2.9), CFrame.new(0, 1.7, 0) * CFrame.Angles(math.rad(10), 0, 0), colour,
		nil, { collide = false, query = false })
	b:decor("BikePost", Vector3.new(0.2, 1.4, 0.2), Vector3.new(0, 2.1, 0.7), colour)
	b:decor("Saddle", Vector3.new(0.5, 0.2, 0.9), Vector3.new(0, 2.85, 0.7), P.KURO)
	b:decor("Handlebar", Vector3.new(1.6, 0.16, 0.16), Vector3.new(0, 3, -1.2), P.STEEL)
	b:decor("Basket", Vector3.new(1, 0.7, 0.8), Vector3.new(0, 2.5, -1.8), Color3.fromRGB(196, 200, 204), M.DiamondPlate)
end

--- A row of bikes parked side by side along +X, front wheels to -Z.
function CityKit.BikeRow(b: B, count: number, seed: number)
	local rng = Random.new(seed)
	local cols = { Color3.fromRGB(220, 220, 214), Color3.fromRGB(196, 60, 56), Color3.fromRGB(60, 100, 170), Color3.fromRGB(40, 42, 48),
		Color3.fromRGB(236, 196, 80), Color3.fromRGB(100, 170, 120) }
	for k = 0, count - 1 do
		CityKit.Bike(b:within(CFrame.new(k * 1.4 - (count - 1) * 0.7, 0, 0) * CFrame.Angles(0, rng:NextNumber(-0.08, 0.08), 0)),
			cols[rng:NextInteger(1, #cols)])
	end
end

--- An orange curve mirror on its pole, the mirror looking down -Z.
function CityKit.CurveMirror(b: B)
	b:part("MirrorPole", Vector3.new(0.4, 9, 0.4), Vector3.new(0, 4.5, 0), Color3.fromRGB(236, 120, 40))
	b:decor("MirrorBack", Vector3.new(0.4, 2.8, 2.8), CFrame.new(0, 9.4, -0.3) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(236, 120, 40), nil, { shape = "Cylinder" })
	b:decor("Mirror", Vector3.new(0.2, 2.3, 2.3), CFrame.new(0, 9.4, -0.55) * CFrame.Angles(0, math.rad(90), 0),
		Color3.fromRGB(210, 226, 236), M.Glass, { shape = "Cylinder", reflectance = 0.5 })
end

--- A red post box (the cylinder kind), standing at the origin.
function CityKit.PostBox(b: B)
	b:part("PostBox", Vector3.new(4.2, 2, 2), vertical(Vector3.new(0, 2.1, 0)), Color3.fromRGB(214, 48, 44), nil, { shape = "Cylinder" })
	b:decor("PostBoxTop", Vector3.new(0.6, 2.2, 2.2), vertical(Vector3.new(0, 4.4, 0)), Color3.fromRGB(190, 40, 38), nil,
		{ shape = "Cylinder" })
	b:decor("PostSlot", Vector3.new(1.2, 0.2, 0.2), Vector3.new(0, 3.5, -1), P.KURO)
	text(b, "〒", CFrame.new(0, 2.6, -1.04), 1, 1, P.WHITE, Enum.Font.GothamBlack)
end

--- A Japanese traffic light on a pole at the origin, the arm out over -Z... the lamps (green,
--- amber, red, left to right) face +Z, to the traffic coming.
function CityKit.TrafficLight(b: B, reach: number)
	b:part("SignalPole", Vector3.new(15, 0.7, 0.7), vertical(Vector3.new(0, 7.5, 0)), P.STEEL, nil, { shape = "Cylinder" })
	b:decor("SignalArm", Vector3.new(0.4, 0.4, reach), Vector3.new(0, 14, -reach / 2), P.STEEL)
	local at = Vector3.new(0, 14, -reach + 1)
	b:decor("SignalBox", Vector3.new(5.2, 1.6, 1), at, Color3.fromRGB(196, 198, 194))
	b:decor("SignalHood", Vector3.new(5.4, 0.3, 1.4), at + Vector3.new(0, 0.9, 0.3), Color3.fromRGB(196, 198, 194))
	for k, c in ipairs({ Color3.fromRGB(60, 210, 170), Color3.fromRGB(80, 74, 50), Color3.fromRGB(110, 50, 46) }) do
		b:decor("SignalLamp", Vector3.new(0.2, 1.1, 1.1), CFrame.new(at + Vector3.new(-1.7 + (k - 1) * 1.7, 0, 0.55))
			* CFrame.Angles(0, math.rad(90), 0), c, nil, { shape = "Cylinder" })
	end
	-- The walk signal on the pole.
	b:decor("WalkSignal", Vector3.new(1.1, 2, 0.9), Vector3.new(0, 9, 0.8), Color3.fromRGB(196, 198, 194))
	b:decor("WalkMan", Vector3.new(0.7, 0.7, 0.1), Vector3.new(0, 9.4, 1.28), Color3.fromRGB(70, 200, 150))
end

--- A street lamp: a tall grey pole and a head out over -Z.
function CityKit.StreetLamp(b: B, withLight: boolean?)
	b:part("LampPole", Vector3.new(16, 0.6, 0.6), vertical(Vector3.new(0, 8, 0)), Color3.fromRGB(170, 174, 180), nil,
		{ shape = "Cylinder" })
	b:decor("LampArm", Vector3.new(0.35, 0.35, 3.4), CFrame.new(0, 16.1, -1.5) * CFrame.Angles(math.rad(-8), 0, 0),
		Color3.fromRGB(170, 174, 180))
	b:decor("LampHead", Vector3.new(1.2, 0.5, 2.2), Vector3.new(0, 15.9, -3.3), Color3.fromRGB(246, 240, 220))
	if withLight then
		b:light("Spot", CFrame.new(0, 15.4, -3.3) * CFrame.Angles(math.rad(-90), 0, 0), Color3.fromRGB(255, 226, 180), 1.4, 30,
			{ Angle = 110 })
	end
end

--- A cherry tree with its foot at the origin.
function CityKit.Sakura(b: B, seed: number, scale: number?)
	local s = scale or 1
	local rng = Random.new(seed)
	b:part("Trunk", Vector3.new(6 * s, 1 * s, 1 * s), vertical(Vector3.new(0, 3 * s, 0)), P.BARK, M.Wood, { shape = "Cylinder" })
	for k = 1, 3 do
		local a = seed + k * 2.1
		local from = Vector3.new(0, 5.4 * s, 0)
		local to = Vector3.new(math.cos(a) * 2.6 * s, 8 * s, math.sin(a) * 2.6 * s)
		local cf, len = Kit.Span(from, to)
		b:decor("Branch", Vector3.new(0.55 * s, 0.55 * s, len), cf, P.BARK, M.Wood)
	end
	local shades = { P.SAKURA_DEEP, P.SAKURA, P.SAKURA_LIGHT }
	for _, blob in ipairs({
		{ Vector3.new(0, 8.6, 0), 6.4, 2 }, { Vector3.new(2.8, 8, 1), 4.8, 1 }, { Vector3.new(-2.7, 8.1, -1), 5, 2 },
		{ Vector3.new(-0.5, 7.7, 2.8), 4.4, 1 }, { Vector3.new(0.9, 10.2, -0.9), 4.6, 3 }, { Vector3.new(-1.5, 10, 1.1), 4, 3 },
	} :: { { any } }) do
		local size = blob[2] * rng:NextNumber(0.88, 1.12) * s
		local at = blob[1] * s + Vector3.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.4, 0.4))
		b:decor("Blossom", Vector3.new(size, size, size), at, shades[blob[3]], nil, { shape = "Ball", shadow = true })
	end
	b:decor("Petals", Vector3.new(0.06, 7.4 * s, 7.4 * s), CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.rad(90)), P.SAKURA_LIGHT,
		nil, { shape = "Cylinder", transparency = 0.3 })
end

--- A street tree: a trunk in a grate and a round green crown.
function CityKit.StreetTree(b: B, seed: number, scale: number?)
	local s = scale or 1
	local rng = Random.new(seed)
	b:decor("TreeGrate", Vector3.new(3.4, 0.12, 3.4), Vector3.new(0, 0.06, 0), P.IRON)
	b:part("Trunk", Vector3.new(7 * s, 0.8 * s, 0.8 * s), vertical(Vector3.new(0, 3.5 * s, 0)), P.BARK, M.Wood, { shape = "Cylinder" })
	for k, blob in ipairs({ { Vector3.new(0, 8.4, 0), 5.4 }, { Vector3.new(1.6, 7.4, 0.8), 3.8 }, { Vector3.new(-1.5, 7.6, -0.8), 4 },
		{ Vector3.new(0.2, 10, 0.4), 3.6 } } :: { { any } }) do
		local size = blob[2] * rng:NextNumber(0.9, 1.1) * s
		b:decor("Leaves", Vector3.new(size, size, size), blob[1] * s, if k % 2 == 0 then P.LEAF else P.LEAF_DARK, nil,
			{ shape = "Ball", shadow = true })
	end
end

--- A garden pine, cloud-pruned: a leaning trunk and flat pads of needles.
function CityKit.Pine(b: B, seed: number, scale: number?)
	local s = scale or 1
	local rng = Random.new(seed)
	local lean = rng:NextNumber(-0.25, 0.25)
	local cf, len = Kit.Span(Vector3.new(0, 0, 0), Vector3.new(lean * 6 * s, 9 * s, 0))
	b:part("Trunk", Vector3.new(1.1 * s, 1.1 * s, len), cf, P.BARK, M.Wood)
	for k, pad in ipairs({ { Vector3.new(lean * 6, 9.4, 0), 6.4 }, { Vector3.new(lean * 3 + 2.6, 6.4, 0.6), 4.6 },
		{ Vector3.new(lean * 4 - 2.8, 7.6, -0.6), 4.4 }, { Vector3.new(lean * 6 + 0.4, 11.2, 0.2), 3.6 } } :: { { any } }) do
		local size = pad[2] * s
		b:decor("PinePad", Vector3.new(size * 0.34, size, size), vertical(pad[1] * s), if k % 2 == 0 then P.PINE else darker(P.PINE, 0.15),
			nil, { shape = "Cylinder", shadow = true })
	end
end

--- A torii gate across the origin: `w` between the posts, `h` to the lower beam, its posts
--- along X.
function CityKit.Torii(b: B, w: number, h: number, colour: Color3?)
	local c = colour or P.VERMILION
	local r = math.max(0.6, w * 0.055)
	for _, x in ipairs({ -w / 2, w / 2 }) do
		b:part("ToriiPost", Vector3.new(h + 2, r * 2, r * 2), vertical(Vector3.new(x, (h + 2) / 2, 0)), c, nil, { shape = "Cylinder" })
		b:decor("ToriiFoot", Vector3.new(r * 2.6, 1.2, r * 2.6), Vector3.new(x, 0.6, 0), P.KURO)
	end
	b:decor("Nuki", Vector3.new(w + r * 3, r * 0.9, r * 0.9), Vector3.new(0, h, 0), c)
	b:decor("Kasagi", Vector3.new(w + r * 7, r * 1.1, r * 1.6), Vector3.new(0, h + 2 + r * 0.55, 0), c)
	b:decor("KasagiTop", Vector3.new(w + r * 8, r * 0.7, r * 1.9), Vector3.new(0, h + 2 + r * 1.45, 0), P.KURO)
	for _, side in ipairs({ -1, 1 }) do
		b:decor("KasagiTip", Vector3.new(r * 2, r * 0.7, r * 1.9),
			CFrame.new(side * (w / 2 + r * 4.5), h + 2 + r * 1.7, 0) * CFrame.Angles(0, 0, side * math.rad(14)), P.KURO)
	end
	b:decor("Gakuzuka", Vector3.new(r * 0.8, 2, r * 0.6), Vector3.new(0, h + 1, 0), c)
end

--- A stone lantern (toro) standing at the origin.
function CityKit.StoneLantern(b: B, scale: number?)
	local s = scale or 1
	b:part("ToroBase", Vector3.new(1.6 * s, 0.5 * s, 1.6 * s), Vector3.new(0, 0.25 * s, 0), P.STONE, M.Slate)
	b:part("ToroPost", Vector3.new(2.2 * s, 0.7 * s, 0.7 * s), vertical(Vector3.new(0, 1.6 * s, 0)), P.STONE, M.Slate,
		{ shape = "Cylinder" })
	b:decor("ToroShelf", Vector3.new(1.5 * s, 0.3 * s, 1.5 * s), Vector3.new(0, 2.85 * s, 0), P.STONE, M.Slate)
	b:decor("LanternGlass", Vector3.new(0.9 * s, 0.9 * s, 0.9 * s), Vector3.new(0, 3.45 * s, 0), P.PAPER)
	b:decor("ToroCap", Vector3.new(2 * s, 0.35 * s, 2 * s), Vector3.new(0, 4.1 * s, 0), P.STONE, M.Slate)
	b:decor("ToroCap", Vector3.new(1.2 * s, 0.35 * s, 1.2 * s), CFrame.new(0, 4.4 * s, 0) * CFrame.Angles(0, math.rad(45), 0), P.STONE,
		M.Slate)
	b:decor("ToroJewel", Vector3.new(0.45 * s, 0.45 * s, 0.45 * s), Vector3.new(0, 4.75 * s, 0), P.STONE, M.Slate, { shape = "Ball" })
end

--- A car, its nose to -Z: "kei" (a tall little box), "taxi", "van", "truck" (a kei truck).
function CityKit.Car(b: B, kind: string, colour: Color3)
	local long = if kind == "van" then 10 elseif kind == "kei" or kind == "truck" then 7.2 else 9
	local wide = if kind == "kei" or kind == "truck" then 3.8 else 4.4
	-- The body (solid: cars are cover), the cabin, glass, wheels, lamps.
	b:part("CarBody", Vector3.new(wide, 1.8, long), Vector3.new(0, 1.6, 0), colour, M.SmoothPlastic)
	b:decor("CarSkirt", Vector3.new(wide + 0.04, 0.4, long + 0.04), Vector3.new(0, 0.9, 0), P.KURO)
	local glass = Color3.fromRGB(64, 84, 104)
	if kind == "truck" then
		b:decor("Cab", Vector3.new(wide - 0.2, 2.2, 2.6), Vector3.new(0, 3.6, -long / 2 + 1.4), colour)
		b:decor("CabGlass", Vector3.new(wide - 0.5, 1.4, 0.2), Vector3.new(0, 3.9, -long / 2 + 0.06), glass, M.Glass)
		b:decor("Bed", Vector3.new(wide, 1, long - 3), Vector3.new(0, 3, 1.4), darker(colour, 0.1))
		b:decor("Load", Vector3.new(wide - 1, 1.2, 2.4), Vector3.new(0, 3.6, 2), Color3.fromRGB(150, 110, 70), M.WoodPlanks)
	elseif kind == "van" then
		b:decor("VanBox", Vector3.new(wide - 0.1, 3, long - 2.4), Vector3.new(0, 4, 1.1), colour)
		b:decor("Windscreen", Vector3.new(wide - 0.6, 1.6, 0.2), CFrame.new(0, 4, -long / 2 + 1.25) * CFrame.Angles(math.rad(-16), 0, 0),
			glass, M.Glass)
		b:decor("SideGlass", Vector3.new(wide + 0.02, 1.3, 1.8), Vector3.new(0, 4.4, -long / 2 + 2.6), glass, M.Glass)
	else
		local cabinLen = if kind == "kei" then long - 1.6 else long * 0.5
		local cabinH = if kind == "kei" then 2.4 else 1.7
		local cz = if kind == "kei" then 0.5 else 0.4
		b:decor("Cabin", Vector3.new(wide - 0.4, cabinH, cabinLen), Vector3.new(0, 2.5 + cabinH / 2, cz), colour)
		b:decor("CarGlass", Vector3.new(wide - 0.36, cabinH * 0.62, cabinLen - 0.6), Vector3.new(0, 2.56 + cabinH * 0.55, cz), glass, M.Glass)
		b:decor("CarRoof", Vector3.new(wide - 0.5, 0.2, cabinLen - 0.4), Vector3.new(0, 2.5 + cabinH + 0.05, cz), darker(colour, 0.08))
		if kind == "taxi" then
			b:decor("TaxiSign", Vector3.new(1.6, 0.8, 0.6), Vector3.new(0, 2.5 + cabinH + 0.5, cz), Color3.fromRGB(250, 206, 60))
			b:decor("TaxiStripe", Vector3.new(wide + 0.06, 0.25, long - 2), Vector3.new(0, 2.2, 0), Color3.fromRGB(250, 206, 60))
		end
	end
	for _, x in ipairs({ -wide / 2 + 0.3, wide / 2 - 0.3 }) do
		for _, z in ipairs({ -long / 2 + 1.6, long / 2 - 1.6 }) do
			b:decor("CarWheel", Vector3.new(0.7, 1.7, 1.7), Vector3.new(x, 0.85, z), P.KURO, nil, { shape = "Cylinder" })
		end
		b:decor("HeadLamp", Vector3.new(0.9, 0.5, 0.1), Vector3.new(x * 0.7, 1.9, -long / 2 - 0.05), Color3.fromRGB(250, 246, 220))
		b:decor("TailLamp", Vector3.new(0.9, 0.5, 0.1), Vector3.new(x * 0.7, 1.9, long / 2 + 0.05), Color3.fromRGB(210, 50, 44))
	end
	b:decor("Plate", Vector3.new(1.4, 0.7, 0.1), Vector3.new(0, 1.3, -long / 2 - 0.06), Color3.fromRGB(240, 240, 234))
end

--- A bench: a slatted seat on two legs, along X.
function CityKit.Bench(b: B, colour: Color3?)
	b:part("Bench", Vector3.new(5, 0.4, 1.6), Vector3.new(0, 1.5, 0), colour or P.WOOD_LIGHT, M.Wood)
	b:decor("BenchBack", Vector3.new(5, 1.2, 0.3), CFrame.new(0, 2.4, 0.75) * CFrame.Angles(math.rad(-10), 0, 0), colour or P.WOOD_LIGHT, M.Wood)
	for _, x in ipairs({ -2, 2 }) do
		b:decor("BenchLeg", Vector3.new(0.3, 1.3, 1.4), Vector3.new(x, 0.65, 0), P.IRON)
	end
end

--- A low planter box of shrubs, `w` long along X.
function CityKit.Planter(b: B, w: number, seed: number, flowers: boolean?)
	local rng = Random.new(seed)
	b:part("Planter", Vector3.new(w, 1.6, 2.2), Vector3.new(0, 0.8, 0), P.CONCRETE, M.Concrete)
	b:decor("Soil", Vector3.new(w - 0.4, 0.1, 1.8), Vector3.new(0, 1.62, 0), Color3.fromRGB(90, 70, 54))
	local n = math.max(1, math.floor(w / 2.2))
	for k = 0, n - 1 do
		local size = rng:NextNumber(1.6, 2.2)
		b:decor("Shrub", Vector3.new(size, size, size), Vector3.new(-w / 2 + 1.1 + k * (w - 2.2) / math.max(1, n - 1), 2.2, 0),
			if k % 2 == 0 then P.LEAF else P.LEAF_DARK, nil, { shape = "Ball" })
		if flowers and k % 2 == 1 then
			b:decor("Flowers", Vector3.new(0.9, 0.9, 0.9), Vector3.new(-w / 2 + 1.1 + k * (w - 2.2) / math.max(1, n - 1), 3, 0.3),
				CityKit.SIGNS[(seed + k) % 7 + 1], nil, { shape = "Ball" })
		end
	end
end

--- Potted plants by a doorstep (two or three pots of different sizes).
function CityKit.Pots(b: B, seed: number)
	local rng = Random.new(seed)
	for k = 0, rng:NextInteger(1, 2) do
		local s = rng:NextNumber(0.8, 1.3)
		local x = k * 1.6
		b:decor("Pot", Vector3.new(1 * s, 1.1 * s, 1.1 * s), vertical(Vector3.new(x, 0.5 * s, 0)), Color3.fromRGB(176, 104, 70), nil,
			{ shape = "Cylinder" })
		b:decor("PotPlant", Vector3.new(1.5 * s, 1.5 * s, 1.5 * s), Vector3.new(x, 1.5 * s, 0), if k % 2 == 0 then P.LEAF else P.LEAF_DARK,
			nil, { shape = "Ball" })
	end
end

--- Stacked beer crates and a couple of upturned ones with a board on top for a table.
function CityKit.Crates(b: B, seed: number)
	local rng = Random.new(seed)
	local cols = { Color3.fromRGB(220, 170, 40), Color3.fromRGB(200, 60, 50), Color3.fromRGB(60, 120, 190) }
	local c = cols[rng:NextInteger(1, 3)]
	b:part("Crates", Vector3.new(1.6, 2.6, 1.6), Vector3.new(0, 1.3, 0), c)
	b:decor("CrateLines", Vector3.new(1.64, 0.15, 1.64), Vector3.new(0, 1.3, 0), darker(c, 0.25))
	b:part("CrateTable", Vector3.new(2.4, 0.2, 2.4), Vector3.new(2.6, 2.1, 0), P.WOOD_LIGHT, M.WoodPlanks)
	b:part("Crate", Vector3.new(1.6, 2, 1.6), Vector3.new(2.6, 1, 0), cols[(rng:NextInteger(1, 3) % 3) + 1])
end

--- Rubbish out for collection under a green net.
function CityKit.Rubbish(b: B, seed: number)
	local rng = Random.new(seed)
	for k = 0, 2 do
		local s = rng:NextNumber(1.1, 1.6)
		b:decor("Bag", Vector3.new(s, s, s), Vector3.new(k * 1.2 - 1.2, s / 2, rng:NextNumber(-0.4, 0.4)),
			if k % 2 == 0 then Color3.fromRGB(236, 236, 228) else Color3.fromRGB(214, 220, 200), nil, { shape = "Ball" })
	end
	b:decor("Net", Vector3.new(4.4, 0.3, 2.4), Vector3.new(0, 1.5, 0), Color3.fromRGB(70, 140, 90), M.Fabric, { transparency = 0.3 })
end

--- A traffic cone.
function CityKit.Cone(b: B)
	b:decor("ConeBase", Vector3.new(1.4, 0.2, 1.4), Vector3.new(0, 0.1, 0), Color3.fromRGB(230, 90, 40))
	b:decor("Cone", Vector3.new(1.8, 0.9, 0.9), vertical(Vector3.new(0, 1.1, 0)), Color3.fromRGB(236, 100, 44), nil, { shape = "Cylinder" })
	b:decor("ConeBand", Vector3.new(0.4, 0.94, 0.94), vertical(Vector3.new(0, 1.3, 0)), P.WHITE, nil, { shape = "Cylinder" })
end

--- A yellow-and-black barrier on two feet, along X.
function CityKit.Barrier(b: B, w: number)
	for _, x in ipairs({ -w / 2 + 0.4, w / 2 - 0.4 }) do
		b:decor("BarrierFoot", Vector3.new(0.6, 2.6, 1.4), Vector3.new(x, 1.3, 0), P.KURO)
	end
	b:part("Barrier", Vector3.new(w, 0.6, 0.3), Vector3.new(0, 2.2, 0), Color3.fromRGB(246, 204, 50))
	for k = 0, math.floor(w / 1.4) - 1 do
		b:decor("BarrierStripe", Vector3.new(0.5, 0.62, 0.32), CFrame.new(-w / 2 + 0.7 + k * 1.4, 2.2, 0) * CFrame.Angles(0, 0, math.rad(35)),
			P.KURO)
	end
end

--- A bus or taxi shelter, `w` along X, open to -Z.
function CityKit.Shelter(b: B, w: number, label: string)
	b:decor("ShelterRoof", Vector3.new(w + 1, 0.4, 4), Vector3.new(0, 8.2, 0.6), Color3.fromRGB(196, 200, 204))
	b:decor("ShelterBack", Vector3.new(w, 6.6, 0.2), Vector3.new(0, 4.6, 2.4), P.GLASS, M.Glass, { transparency = 0.5 })
	for _, x in ipairs({ -w / 2, w / 2 }) do
		b:part("ShelterPost", Vector3.new(0.4, 8, 0.4), Vector3.new(x, 4, 2.3), P.STEEL)
	end
	b:part("ShelterSeat", Vector3.new(w - 2, 0.3, 1.2), Vector3.new(0, 1.6, 1.6), P.STEEL)
	board(b:within(CFrame.new(0, 0, 0.6 - 2.05)), label, 0, 7.4, w * 0.6, 1.2, Color3.fromRGB(40, 96, 204), P.WHITE, 0.2)
end

--- A row of zebra stripes across a road: the road runs along `along` ("x" or "z"), the
--- crossing at `at` on it, `width` across.
function CityKit.Crosswalk(b: B, cx: number, cz: number, alongX: boolean, width: number, depth: number?)
	local dd = depth or 7
	local n = math.floor(width / 2.2)
	for k = 0, n - 1 do
		local o = -width / 2 + 1.1 + k * 2.2
		if alongX then
			b:decor("Zebra", Vector3.new(dd, 0.06, 1.2), Vector3.new(cx, 0.04, cz + o), P.LINE)
		else
			b:decor("Zebra", Vector3.new(1.2, 0.06, dd), Vector3.new(cx + o, 0.04, cz), P.LINE)
		end
	end
end

--- Writing painted on the road, read from -Z... `at` is where, `yaw` turns it.
function CityKit.RoadText(b: B, label: string, at: Vector3, yaw: number, w: number, h: number, colour: Color3?)
	text(b, label, CFrame.new(at + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(90), 0, 0), w, h,
		colour or P.LINE, Enum.Font.GothamBlack)
end

--- A painted kerb-side line of tactile paving: yellow, a stud wide, from a to c (on the ground).
function CityKit.Tactile(b: B, a: Vector3, c: Vector3)
	local cf, len = Kit.Span(a + Vector3.new(0, 0.04, 0), c + Vector3.new(0, 0.04, 0))
	b:decor("Tactile", Vector3.new(1, 0.06, len), cf, P.TACTILE)
end

--- A flat slab laid on the ground (paving, a patch): seen, not solid.
function CityKit.Patch(b: B, name: string, x0: number, x1: number, z0: number, z1: number, y: number, colour: Color3,
	material: Enum.Material?): BasePart
	return b:decor(name, Vector3.new(x1 - x0, 0.1, z1 - z0), Vector3.new((x0 + x1) / 2, y + 0.05, (z0 + z1) / 2), colour,
		material or M.SmoothPlastic)
end

--- A slab of solid ground, its top at `top`.
function CityKit.Ground(b: B, name: string, x0: number, x1: number, z0: number, z1: number, top: number, colour: Color3,
	material: Enum.Material?, depth: number?): BasePart
	local d = depth or 6
	return b:part(name, Vector3.new(x1 - x0, d, z1 - z0), Vector3.new((x0 + x1) / 2, top - d / 2, (z0 + z1) / 2), colour,
		material or M.Asphalt)
end

--- An invisible marker the service or the quests look for by name.
function CityKit.Marker(b: B, name: string, at: Vector3, attributes: { [string]: any }?): BasePart
	local p = b:decor(name, Vector3.new(1, 1, 1), at, P.CREAM, nil, { transparency = 1 })
	for k, v in pairs(attributes or {}) do
		p:SetAttribute(k, v)
	end
	return p
end

--- A climbable ladder (a truss) with its foot at `at`, `height` tall.
function CityKit.Ladder(b: B, at: Vector3, height: number, colour: Color3?): BasePart
	local h = math.max(2, math.floor(height / 2 + 0.5) * 2)
	local truss = Instance.new("TrussPart")
	truss.Name = "Ladder"
	truss.Size = Vector3.new(2, h, 2)
	truss.CFrame = b:world(CFrame.new(at + Vector3.new(0, h / 2, 0)))
	truss.Color = colour or P.STEEL
	truss.Anchored = true
	truss.TopSurface = Enum.SurfaceType.Smooth
	truss.BottomSurface = Enum.SurfaceType.Smooth
	truss.Parent = b.parent
	return truss
end

--- A flight of steps you can walk up: from `foot` (the bottom step's front edge, on the
--- ground) rising `rise` over `run` along the builder's +Z, `w` wide. Real steps to look at,
--- and an invisible ramp under the feet so nobody catches on an edge.
function CityKit.Stairs(b: B, foot: Vector3, w: number, rise: number, run: number, colour: Color3, material: Enum.Material?,
	stepRise: number?)
	local sr = stepRise or 1
	local n = math.max(1, math.floor(rise / sr + 0.5))
	local h = rise / n
	local r = run / n
	for k = 0, n - 1 do
		-- Each step a block from the ground up, so there is nothing to see under it.
		local top = foot.Y + h * (k + 1)
		b:decor("Step", Vector3.new(w, top - foot.Y, r + 0.02), Vector3.new(foot.X, (top + foot.Y) / 2, foot.Z + r * (k + 0.5)), colour,
			material, { shadow = true })
	end
	-- The ramp the feet use.
	local len = math.sqrt(rise * rise + run * run)
	local cf = CFrame.new(foot + Vector3.new(0, rise / 2, run / 2)) * CFrame.Angles(-math.atan2(rise, run), 0, 0)
	b:part("StairRamp", Vector3.new(w, 0.4, len), cf * CFrame.new(0, 0.05, 0), colour, nil, { transparency = 1, shadow = false })
end

--- A steel stair up the outside of a building to its roof, its foot at `at`, climbing along
--- the builder's +Z beside a wall... `rise` high, `w` wide, with a landing at the top `land`
--- long. Returns the landing's top.
function CityKit.FireStair(b: B, at: Vector3, rise: number, w: number?)
	local width = w or 3.4
	local run = rise * 1.25
	CityKit.Stairs(b, at, width, rise, run, Color3.fromRGB(120, 126, 132), M.DiamondPlate, 0.9)
	-- A rail on the open side.
	local a = at + Vector3.new(-width / 2, 3, 0)
	local c = at + Vector3.new(-width / 2, rise + 3, run)
	local cf, len = Kit.Span(a, c)
	b:decor("StairRail", Vector3.new(0.2, 0.2, len), cf, P.STEEL)
	for k = 0, 3 do
		local p = at:Lerp(at + Vector3.new(0, rise, run), k / 3)
		b:decor("StairPost", Vector3.new(0.2, 3, 0.2), p + Vector3.new(-width / 2, 1.5 + 0.4, 0), P.STEEL)
	end
end

return CityKit
