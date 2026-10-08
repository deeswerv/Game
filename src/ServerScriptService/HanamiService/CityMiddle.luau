--!strict
-- HANAMI CITY, the middle: from the canal to the north avenue.
--
--   THE SCRAMBLE   Hanami-dori meets Station Boulevard at the big crossing: zebras on every
--                  side and both diagonals, four corners stood round with the city's loudest
--                  buildings -- the screen building, the round tower, the tower of signs, the
--                  glass tower over the corner cafe -- and blocks of shops and offices behind,
--                  tall signs on every one.
--   LANTERN ROW    the drinking alleys east of it: stone paving, two-storey wooden izakaya
--                  under strings of red lanterns, noren and crates and bikes, the festival
--                  tower in its little square, roof terraces up ladders.
--   THE STEELWORKS the Kurogane foundry west of it: warehouses, containers, the furnace hall
--                  and its striped stacks, the yard, the quay with its crane and a ship
--                  alongside.
--
-- City frame (HanamiConfig): +Z north, +X west. Real studs throughout.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ServerScriptService.ArenaService.Kit)
local CityKit = require(ServerScriptService.HanamiService.CityKit)
local Blocks = require(ServerScriptService.HanamiService.CityBlocks)
local HanamiConfig = require(ReplicatedStorage.HanamiConfig)

local Middle = {}

type B = Kit.Builder
local M = Enum.Material
local P = CityKit.P
local darker = CityKit.Darker
local vertical = CityKit.Vertical
local At = CityKit.At
local text = CityKit.Text
local WALK = Blocks.WALK
local S = HanamiConfig.Sites

-- The lines the middle is laid out on.
Middle.CANAL_ROAD = { z0 = -148, z1 = -124 }     -- along the canal's north bank
Middle.DORI = 22                                 -- Hanami-dori: z -22..22
Middle.BLVD = 22                                 -- Station Boulevard: x -22..22
Middle.SIDE = 106                                -- the side streets: x = +-106, 20 wide
Middle.CROSS = 110                               -- the cross street: z = 110, 20 wide
Middle.NORTH = { z0 = 200, z1 = 228 }            -- the north avenue
Middle.EDGE = 176                                -- where the Scramble meets Lantern Row and the Steelworks
Middle.DOCK = { x0 = 556, z0 = -124, z1 = 186 }  -- the Steelworks' dock basin, out to the city's west edge

-- ------------------------------------------------------------------ the Scramble's corners --

--- THE SCREEN BUILDING on the south-west corner: glass over a dark lobby, and a giant screen
--- filling the face it turns to the crossing, another down its side.
local function screenBuilding(root: B)
	local b = At(root, 61, -36, "+z", WALK)
	CityKit.Tower(b, { w = 50, d = 44, floors = 6, seed = 611, glass = Color3.fromRGB(70, 96, 120), body = Color3.fromRGB(46, 50, 58),
		fin = Color3.fromRGB(90, 96, 106), accent = Color3.fromRGB(250, 90, 140), name = "Q-FRONT", crown = "flat", right = true, left = true })
	CityKit.Screen(b, 0, 46, 42, 38, 1, 1.4)
	-- Down its side to the boulevard, a tall screen; a band of lettering round the top.
	local side = b:within(CFrame.new(25, 0, 22) * CFrame.Angles(0, -math.pi / 2, 0))
	CityKit.Screen(side, 0, 44, 16, 44, 4, 1.4)
	b:decor("NameBand", Vector3.new(50.6, 3.2, 44.6), Vector3.new(0, 74, 22), Color3.fromRGB(250, 90, 140))
	text(b, "QFRONT  キューフロント", CFrame.new(0, 74, -0.36), 40, 2.6, P.WHITE, Enum.Font.GothamBlack)
end

--- THE ROUND TOWER on the north-west corner, its sign and its name turned to the crossing, in
--- its own little paved square.
local function roundTower(root: B)
	local c = Vector3.new(62, WALK, 62)
	local t = root:within(CFrame.lookAt(c, Vector3.new(0, WALK, 0)))
	CityKit.RoundTower(t, { r = 22, floors = 10, seed = 621, sign = "ハナミ109", head = "109", signColour = Color3.fromRGB(30, 30, 36),
		ring = Color3.fromRGB(236, 86, 150) })
	-- A giant screen wrapped on the drum's front, over the shop windows.
	local s = t:within(CFrame.new(0, 0, -22) * CFrame.Angles(0, 0, 0))
	CityKit.Screen(s:within(CFrame.new(-13, 0, 2.6) * CFrame.Angles(0, math.rad(-30), 0)), 0, 34, 14, 22, 2, 0.4)
	CityKit.Screen(s:within(CFrame.new(13, 0, 2.6) * CFrame.Angles(0, math.rad(30), 0)), 0, 34, 14, 22, 6, 0.4)
	for i, at in ipairs({ { 30, 92 }, { 92, 30 }, { 88, 92 } }) do
		CityKit.TreeBed(root:within(CFrame.new(at[1], WALK, at[2])), 620 + i, i == 3, 2.3)
	end
	for _, at in ipairs({ { 30, 74 }, { 74, 30 } }) do
		CityKit.Bench(CityKit.Scaled(root:within(CFrame.new(at[1], WALK, at[2]) * CFrame.Angles(0, math.rad(45), 0)), 1.3))
	end
end

--- THE TOWER OF SIGNS on the north-east corner: a tall zakkyo with a sign for every tenant, a
--- tall sign down its corner, a screen down its boulevard side and a screen on its roof.
local function signTower(root: B)
	local top = Blocks.Building(root, -61, 36, "-z", {
		w = 50, d = 54, floors = 9, style = "zakkyo", colour = Color3.fromRGB(196, 214, 230), seed = 631,
		shop = { jp = "ゲームセンター", en = "ARCADE", colour = Color3.fromRGB(40, 96, 204), kind = "glass", awning = false },
		tenants = { "2F 漫画喫茶", "3F ネイル", "4F 麻雀", "5F 歯科", "6F ダンス", "7F 占い", "8F カラオケ", "9F BAR", "10F スナック" },
		vsign = "カラオケ", vcolour = Color3.fromRGB(250, 204, 44), vside = 1,
		sideShops = { Blocks.AnyShop(Random.new(631), true), Blocks.AnyShop(Random.new(632)) }, left = true, right = true, back = true,
	})
	local side = At(root, -36, 63, "+x", WALK)
	CityKit.Screen(side, 0, 50, 22, 40, 3, 0.6)
	-- The roof screen on its frame, turned to the crossing.
	local roof = At(root, -61, 50, "-z", WALK + top)
	for _, x in ipairs({ -16, 16 }) do
		roof:decor("ScreenLeg", Vector3.new(1.2, 26, 1.2), Vector3.new(x, 13, 2), P.IRON)
	end
	roof:decor("ScreenBrace", Vector3.new(34, 1, 1), Vector3.new(0, 6, 2), P.IRON)
	CityKit.Screen(roof, 0, 16, 38, 20, 5, 0)
end

--- THE GLASS TOWER on the south-east corner, over the corner cafe in its own little plaza:
--- a screen on its face to the crossing.
local function glassTower(root: B)
	local b = At(root, -61, -70, "+z", WALK)
	CityKit.Tower(b, { w = 50, d = 40, floors = 12, seed = 641, glass = Color3.fromRGB(110, 160, 196), body = Color3.fromRGB(226, 230, 234),
		accent = Color3.fromRGB(40, 160, 200), name = "HANAMI MARK CITY", jp = "マークシティ", left = true, right = true, back = true })
	CityKit.Screen(b, 0, 58, 36, 26, 8, 1.4)
	-- The cafe on the corner: two floors of glass, the green awning, tables out front.
	Blocks.Building(root, -51, -40, "+z", { w = 30, d = 26, floors = 1, style = "office", colour = Color3.fromRGB(236, 232, 224),
		trim = Color3.fromRGB(30, 110, 80), seed = 642, left = true, right = true,
		shop = { jp = "スターカフェ", en = "STAR COFFEE", colour = Color3.fromRGB(30, 110, 80), kind = "glass", awning = true } })
	for k = 0, 2 do
		local t = CityKit.Scaled(root:within(CFrame.new(-44 - k * 8, WALK, -32)), 1.3)
		t:part("CafeTable", Vector3.new(0.4, 2.4, 0.4), Vector3.new(0, 1.2, 0), P.STEEL)
		t:decor("CafeTop", Vector3.new(0.2, 2, 2), vertical(Vector3.new(0, 2.5, 0)), P.WHITE, nil, { shape = "Cylinder" })
		t:decor("Parasol", Vector3.new(0.3, 5, 5), vertical(Vector3.new(0, 6, 0)), Color3.fromRGB(30, 110, 80), M.Fabric, { shape = "Cylinder" })
		t:decor("ParasolPole", Vector3.new(0.15, 6, 0.15), Vector3.new(0, 3, 0), P.STEEL)
	end
	for i, at in ipairs({ { -76, -46 }, { -80, -62 } }) do
		CityKit.TreeBed(root:within(CFrame.new(at[1], WALK, at[2])), 640 + i, i == 1, 2.2)
	end
end

-- ------------------------------------------------------------------ the Scramble's blocks --

local function scrambleBlocks(root: B)
	local E, X, Z, C, N = Middle.EDGE, Middle.SIDE, Middle.CROSS, Middle.CANAL_ROAD, Middle.NORTH
	local tall = Blocks.CityPick(5, 9, 0.55)
	local mid = Blocks.CityPick(4, 7, 0.45)
	local function towerPick(every: number, floors: number)
		return function(k: number, n: number, w: number, rng: Random): any
			if k % every == 0 and w > 30 then
				return { tower = { floors = floors + rng:NextInteger(-2, 2), glass = ({ P.GLASS, P.GLASS_TEAL, P.GLASS_DARK })[rng:NextInteger(1, 3)],
					body = CityKit.FACADES[rng:NextInteger(1, #CityKit.FACADES)], accent = CityKit.SIGNS[rng:NextInteger(1, 7)], crown = "flat" } }
			end
			return tall(k, n, w, rng)
		end
	end
	-- The four corners: the hero buildings and what is behind them.
	Blocks.Walk(root, Middle.BLVD, X - 10, C.z1, -Middle.DORI)
	screenBuilding(root)
	Blocks.Row(root, 36, X - 20, C.z1 + 10, "-z", 34, 650, mid, 26)
	Blocks.Walk(root, Middle.BLVD, X - 10, Middle.DORI, Z - 10)
	roundTower(root)
	Blocks.Walk(root, -(X - 10), -Middle.BLVD, Middle.DORI, Z - 10)
	signTower(root)
	Blocks.Walk(root, -(X - 10), -Middle.BLVD, C.z1, -Middle.DORI)
	glassTower(root)
	-- The blocks between the side streets and the edges, and north of the cross street.
	for _, s in ipairs({ 1, -1 }) do
		local outer = if s > 0 then "+x" else "-x"
		local inner = if s > 0 then "-x" else "+x"
		local x0, x1 = math.min(s * (X + 10), s * E), math.max(s * (X + 10), s * E)
		Blocks.Block(root, x0, x1, C.z1, -Middle.DORI, { seed = 660 + s, pick = tall, walk = 10, walks = { [outer] = 4 },
			sides = { "-z", "+z", inner }, depth = 28, size = 24 })
		Blocks.Block(root, x0, x1, Middle.DORI, Z - 10, { seed = 670 + s, pick = towerPick(2, 11), walk = 10, walks = { [outer] = 4 },
			sides = { "-z", "+z", inner }, depth = 30, size = 26 })
		Blocks.Block(root, x0, x1, Z + 10, N.z0, { seed = 680 + s, pick = mid, walk = 10, walks = { [outer] = 4, ["+z"] = 14 },
			sides = { "-z", "+z", inner }, depth = 28, size = 24 })
	end
	-- North of the cross street, on the boulevard: HANAMI HILLS (west) and the hotel (east).
	Blocks.Walk(root, Middle.BLVD, X - 10, Z + 10, N.z0)
	CityKit.Tower(At(root, 36, 158, "-x", WALK), { w = 56, d = 50, floors = 15, seed = 690, glass = Color3.fromRGB(96, 140, 170),
		body = Color3.fromRGB(200, 206, 214), accent = P.SAKURA_DEEP, name = "HANAMI HILLS", jp = "花見ヒルズ", left = true, right = true, back = true })
	Blocks.Walk(root, -(X - 10), -Middle.BLVD, Z + 10, N.z0)
	Blocks.Building(root, -36, 158, "+x", { w = 56, d = 50, floors = 11, style = "tile", colour = Color3.fromRGB(240, 232, 214), seed = 692,
		shop = { jp = "ホテル桜", en = "HOTEL SAKURA", colour = Color3.fromRGB(150, 30, 46), kind = "lobby", awning = true }, left = true,
		right = true, back = true, vsign = "ホテル桜", vcolour = Color3.fromRGB(150, 30, 46), billboard = "HOTEL SAKURA",
		bcolour = Color3.fromRGB(150, 30, 46) })
end

-- ------------------------------------------------------------------ the Scramble's streets --

local function scrambleStreets(root: B)
	local f = root:folder("ScrambleStreets")
	local D, X, Z, C, N, E = Middle.DORI, Middle.SIDE, Middle.CROSS, Middle.CANAL_ROAD, Middle.NORTH, Middle.EDGE
	-- Road paint between the junctions.
	for _, seg in ipairs({ { C.z1, -D }, { D, Z - 10 }, { Z + 10, N.z0 } }) do
		Blocks.Lanes(f, false, seg[1], seg[2], 0, Middle.BLVD)
		for _, s in ipairs({ -1, 1 }) do
			Blocks.Lanes(f, false, seg[1], seg[2], s * X, 10)
		end
	end
	Blocks.Lanes(f, false, C.z0, C.z1, 0, Middle.BLVD)
	for _, seg in ipairs({ { -E, -(X + 10) }, { -(X - 10), -Middle.BLVD }, { Middle.BLVD, X - 10 }, { X + 10, E } }) do
		Blocks.Lanes(f, true, seg[1], seg[2], 0, D)
		Blocks.Lanes(f, true, seg[1], seg[2], Z, 10)
	end
	-- THE CROSSING: wide zebras on all four sides, and both diagonals across the middle.
	Blocks.Zebra(f, 0, D + 7, false, 44, 12)
	Blocks.Zebra(f, 0, -D - 7, false, 44, 12)
	Blocks.Zebra(f, D + 7, 0, true, 44, 12)
	Blocks.Zebra(f, -D - 7, 0, true, 44, 12)
	for _, d in ipairs({ 1, -1 }) do
		for k = -7, 7 do
			local at = Vector3.new(k * 3.6 * 0.7071, 0.05, k * 3.6 * 0.7071 * d)
			f:decor("Zebra", Vector3.new(1.9, 0.07, 10), CFrame.new(at) * CFrame.Angles(0, math.rad(-45 * d), 0), P.LINE)
		end
	end
	-- Crossings at the other junctions.
	for _, s in ipairs({ -1, 1 }) do
		Blocks.Zebra(f, s * X, D + 7, false, 20, 10)
		Blocks.Zebra(f, s * X, -D - 7, false, 20, 10)
		Blocks.Zebra(f, s * (X - 17), 0, true, 44, 10)
		Blocks.Zebra(f, s * (X + 17), 0, true, 44, 10)
		Blocks.Zebra(f, s * 34, Z, true, 20, 10)
		Blocks.Zebra(f, s * X, N.z0 - 7, false, 20, 10)
		Blocks.Zebra(f, s * X, C.z1 + 7, false, 20, 10)
	end
	Blocks.Zebra(f, 0, Z + 17, false, 44, 10)
	Blocks.Zebra(f, 0, Z - 17, false, 44, 10)
	Blocks.Zebra(f, 0, C.z1 + 8, false, 44, 10)
	-- Traffic lights on the crossing's four corners, the arms out over the boulevard.
	for _, c in ipairs({ { -24, -24, "+x" }, { 24, 24, "-x" }, { 24, -24, "-x" }, { -24, 24, "+x" } } :: { { any } }) do
		CityKit.TrafficLight(CityKit.Scaled(At(f, c[1], c[2], c[3], WALK), 1.3), 12)
	end
	for _, c in ipairs({ { -24, -24, "-z" }, { 24, 24, "+z" } } :: { { any } }) do
		CityKit.TrafficLight(CityKit.Scaled(At(f, c[1], c[2], c[3], WALK), 1.3), 12)
	end
	-- Lamps, trees and rails along the avenues (the crossings left clear).
	for _, s in ipairs({ -1, 1 }) do
		local face = if s < 0 then "+x" else "-x"
		Blocks.Avenue(f, false, C.z1 + 18, -36, s * 24.5, face, 18, 700 + s, nil, false, true)
		Blocks.Avenue(f, false, 40, Z - 22, s * 24.5, face, 18, 710 + s, nil, false, true)
		Blocks.Avenue(f, false, Z + 22, N.z0 - 14, s * 24.5, face, 18, 720 + s, nil, true, true)
		local zf = if s < 0 then "+z" else "-z"
		Blocks.Avenue(f, true, 40, X - 22, s * 24.5, zf, 18, 730 + s, nil, false, true)
		Blocks.Avenue(f, true, -(X - 22), -40, s * 24.5, zf, 18, 740 + s, nil, false, true)
		Blocks.Avenue(f, true, X + 22, E - 8, s * 24.5, zf, 18, 750 + s, nil, false, false)
		Blocks.Avenue(f, true, -(E - 8), -(X + 22), s * 24.5, zf, 18, 760 + s, nil, false, false)
	end
	-- Cars and buses on the avenues, keeping left.
	for _, spec in ipairs({ { 11, 70, 0, "taxi", Color3.fromRGB(30, 32, 38) }, { 11, 150, 0, "kei", Color3.fromRGB(240, 240, 236) },
		{ -11, -80, 2, "van", Color3.fromRGB(236, 236, 230) }, { -60, 11, -1, "taxi", Color3.fromRGB(240, 196, 40) },
		{ 70, -11, 1, "kei", Color3.fromRGB(196, 60, 56) }, { 140, -11, 1, "truck", Color3.fromRGB(236, 236, 230) },
		{ -140, 11, -1, "taxi", Color3.fromRGB(30, 32, 38) } } :: { { any } }) do
		local dir: number = spec[3]
		local yaw = if dir == 0 then 0 elseif dir == 2 then math.pi elseif dir < 0 then math.pi / 2 else -math.pi / 2
		CityKit.BigCar(f:within(CFrame.new(spec[1], 0, spec[2]) * CFrame.Angles(0, yaw, 0)), spec[4], spec[5])
	end
	CityKit.Bus(f:within(CFrame.new(-11, 0, 150) * CFrame.Angles(0, math.pi, 0)), Color3.fromRGB(40, 120, 200), "急行 KUROGANE CASTLE")
	-- The canal road along the north bank.
	local cz = (C.z0 + C.z1) / 2
	for _, seg in ipairs({ { -600, -(X + 10) }, { -(X - 10), -Middle.BLVD }, { Middle.BLVD, X - 10 }, { X + 10, 600 } }) do
		Blocks.Lanes(f, true, seg[1], seg[2], cz, 12)
	end
	-- The north avenue.
	local nz = (N.z0 + N.z1) / 2
	for _, seg in ipairs({ { -600, -(X + 10) }, { -(X - 10), -Middle.BLVD }, { Middle.BLVD, X - 10 }, { X + 10, 600 } }) do
		Blocks.Lanes(f, true, seg[1], seg[2], nz, 14)
	end
	Blocks.Zebra(f, -30, nz, true, 28, 10)
	Blocks.Zebra(f, 30, nz, true, 28, 10)
end

-- ------------------------------------------------------------------ Lantern Row --

local function izakayaPick(rng0: number?)
	return function(k: number, n: number, w: number, rng: Random): any
		local name = Blocks.IZAKAYA[rng:NextInteger(1, #Blocks.IZAKAYA)]
		return { izakaya = true, jp = name[1], en = name[2], upper = not (w < 13 and rng:NextNumber() < 0.4),
			noren = ({ Color3.fromRGB(40, 58, 110), P.CRIMSON, Color3.fromRGB(48, 96, 74), P.KURO, Color3.fromRGB(110, 60, 120) })[rng:NextInteger(1, 5)] }
	end
end

local function lanternRow(root: B)
	local f = root:folder("LanternRow")
	local x0, x1, z0, z1 = -600, -Middle.EDGE, Middle.CANAL_ROAD.z1, Middle.NORTH.z0
	local paving = Color3.fromRGB(150, 142, 134)
	Blocks.Walk(f, x0, x1, z0, z1, { "-z", "+z", "+x" }, paving)
	for x = x0 + 8, x1 - 4, 8 do
		f:decor("GutterLine", Vector3.new(0.4, 0.05, 22), Vector3.new(x, WALK + 0.03, 0), darker(paving, 0.14))
	end
	-- The gate over the alley's mouth, the name on it both ways.
	local g = At(f, x1 - 4, 0, "+x", WALK)
	for _, x in ipairs({ -13, 13 }) do
		g:part("GatePost", Vector3.new(2, 26, 2), Vector3.new(x, 13, 0), P.KURO)
	end
	g:decor("GateBeam", Vector3.new(32, 6, 1.6), Vector3.new(0, 24, 0), P.CRIMSON)
	g:decor("GateCap", Vector3.new(36, 1.2, 2.6), Vector3.new(0, 27.6, 0), P.KURO)
	text(g, "ちょうちん横丁", CFrame.new(0, 24.4, -0.86), 28, 3.8, P.WHITE, Enum.Font.GothamBlack)
	text(At(f, x1 - 4, 0, "-x", WALK), "LANTERN ROW", CFrame.new(0, 24.2, -0.86), 26, 3.4, P.GOLD, Enum.Font.GothamBlack)
	for x = -12, 12, 3 do
		CityKit.Chochin(g, Vector3.new(x, 19.6, -1.2), P.LANTERN, 1.3)
	end
	-- The alleys: the main one (z -12..12), a south one, a north one, two across them.
	local xs = { { -284, x1 }, { -424, -300 }, { x0, -440 } }
	for i, xr in ipairs(xs) do
		local a0, a1 = xr[1], xr[2]
		local seed = 800 + i * 20
		-- Plaza for the festival tower on the main alley's north side, in the middle segment.
		if i == 2 then
			Blocks.Row(f, a0, -390, 12, "-z", 24, seed, izakayaPick(), 15)
			Blocks.Row(f, -330, a1, 12, "-z", 24, seed + 1, izakayaPick(), 15)
		else
			Blocks.Row(f, a0, a1, 12, "-z", 24, seed, izakayaPick(), 15)
		end
		Blocks.Row(f, a0, a1, -12, "+z", 22, seed + 2, izakayaPick(), 15)
		Blocks.Row(f, a0, a1, -60, "-z", 24, seed + 3, function(k: number, n: number, w: number, rng: Random): any
			if k % 3 == 0 then
				return Blocks.CityPick(3, 5, 0.6, { "zakkyo" })(k, n, w, rng)
			end
			return izakayaPick()(k, n, w, rng)
		end, 16)
		Blocks.Row(f, a0, a1, -76, "+z", 40, seed + 4, Blocks.CityPick(3, 6, 0.55, { "zakkyo", "mansion", "tile" }), 22)
		Blocks.Row(f, a0, a1, 92, "+z", 30, seed + 5, Blocks.CityPick(3, 6, 0.65, { "zakkyo", "zakkyo", "tile" }), 20)
		if i == 2 then
			-- The two roof terraces with their ladders (the rifleman's post, and a seal).
			-- (a gap either side of the pair for the ladders)
			Blocks.Row(f, a0, -352, 108, "-z", 28, seed + 6, izakayaPick(), 15)
			Blocks.Row(f, -308, a1, 108, "-z", 28, seed + 7, izakayaPick(), 15)
			for k, x in ipairs({ -338, -322 }) do
				local side = if k == 1 then -1 else 1
				local b = At(f, x, 108, "-z", WALK)
				local top = Blocks.Building(f, x, 108, "-z", { izakaya = true, w = 16, d = 28, seed = 790 + k, jp = "焼鳥", en = "YAKITORI",
					terrace = true, open = side, left = side < 0, right = side > 0 })
				CityKit.Ladder(b, Vector3.new(side * 9.2, 0, 14), top + 1, P.STEEL)
			end
		else
			Blocks.Row(f, a0, a1, 108, "-z", 28, seed + 6, izakayaPick(), 15)
		end
		Blocks.Row(f, a0, a1, z1 - 14, "+z", 40, seed + 8, Blocks.CityPick(4, 7, 0.4, { "mansion", "tile", "zakkyo" }), 24)
		-- Low roofscapes in the middles (round the festival square in the middle segment).
		local spans: { { number } } = if i == 2 then { { a0, -390 }, { -330, a1 } } else { { a0, a1 } }
		for _, sp in ipairs(spans) do
			for _, band in ipairs({ { 36, 62 }, { 136, 146 } }) do
				f:part("BlockCore", Vector3.new(sp[2] - sp[1], 12, band[2] - band[1]), Vector3.new((sp[1] + sp[2]) / 2, WALK + 6,
					(band[1] + band[2]) / 2), P.CONCRETE_DARK, M.Concrete)
			end
		end
	end
	-- Lantern strings across the main alley, wires and poles down the side alleys.
	for x = x1 - 14, x0 + 10, -14 do
		if not (x < -384 and x > -336) then
			CityKit.LanternString(f, Vector3.new(x, 19, -11), Vector3.new(x - 5, 19, 11), 6)
		end
	end
	for x = x1 - 20, x0 + 20, -28 do
		CityKit.LanternString(f, Vector3.new(x, 17, -59), Vector3.new(x - 4, 17, -77), 4, { P.LANTERN, P.PAPER })
		CityKit.LanternString(f, Vector3.new(x, 17, 93), Vector3.new(x - 4, 17, 107), 4, { P.LANTERN, P.PAPER })
	end
	for _, x in ipairs({ -292, -432 }) do
		Blocks.Poles(f, Vector3.new(x + 6, WALK, -110), Vector3.new(x + 6, WALK, 186), 7, false)
	end
	-- What stands at the doors: crates, bikes, rubbish under its net, potted plants.
	local rng = Random.new(77)
	for x = x1 - 10, x0 + 10, -11 do
		for _, z in ipairs({ -9.6, 9.6 }) do
			local roll = rng:NextNumber()
			local b = CityKit.Scaled(At(f, x + rng:NextNumber(-2, 2), z, if z < 0 then "+z" else "-z", WALK), 1.25)
			if roll < 0.22 then
				CityKit.Crates(b, x)
			elseif roll < 0.36 then
				CityKit.BikeRow(b, rng:NextInteger(1, 3), x)
			elseif roll < 0.44 then
				CityKit.Pots(b, x)
			end
		end
	end
	CityKit.Vending(Blocks.Site(f, -280, -10, "+z"), Color3.fromRGB(220, 52, 52), 71)
	CityKit.Vending(Blocks.Site(f, -284.5, -10, "+z"), Color3.fromRGB(236, 236, 230), 73)
	CityKit.Vending(Blocks.Site(f, -446, 10, "-z"), Color3.fromRGB(40, 96, 204), 72)
	-- An inari shrine in a nook on the north alley: little red torii and a fox each side.
	local inari = CityKit.Scaled(At(f, -560, 92, "-z", WALK), 1.3)
	for k = 0, 3 do
		CityKit.Torii(inari:within(CFrame.new(0, 0, 2 + k * 2.5)), 3.4, 4, P.VERMILION)
	end
	-- THE FESTIVAL TOWER: a yagura in the little square, lantern strings out from its top to
	-- the eaves round it, a drum on its stage.
	local plaza = f:within(CFrame.new(-360, WALK, 36))
	CityKit.Patch(plaza, "PlazaStone", -30, 30, -24, 24, 0.02, Color3.fromRGB(190, 180, 166), M.Slate)
	CityKit.Life(plaza, "PigeonFlock", Vector3.new(0, 0.1, 0), Vector3.new(1, 1, 1), { Radius = 22, Inner = 9, Count = 6 })
	local y = CityKit.Scaled(plaza, 1.6)
	for _, x in ipairs({ -4.4, 4.4 }) do
		for _, z in ipairs({ -4.4, 4.4 }) do
			y:part("YaguraPost", Vector3.new(0.7, 12, 0.7), Vector3.new(x, 6, z), P.WOOD_DARK, M.Wood)
		end
	end
	y:part("YaguraStage", Vector3.new(10, 0.6, 10), Vector3.new(0, 5, 0), P.WOOD, M.WoodPlanks)
	y:decor("YaguraSkirt", Vector3.new(10.2, 1.8, 10.2), Vector3.new(0, 4, 0), P.WHITE, M.Fabric)
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		y:decor("YaguraStripe", Vector3.new(1.2, 1.82, 0.2), CFrame.Angles(0, a, 0) * CFrame.new(0, 4, -5.12), P.CRIMSON)
	end
	y:decor("YaguraRoof", Vector3.new(12, 0.6, 12), Vector3.new(0, 12.3, 0), P.TILE_ROOF)
	y:decor("YaguraRoofTop", Vector3.new(6, 1.4, 6), Vector3.new(0, 13.2, 0), P.TILE_ROOF_EDGE)
	y:decor("Taiko", Vector3.new(1.6, 2.4, 2.4), CFrame.new(0, 6.6, 0) * CFrame.Angles(0, 0, math.rad(0)), P.WOOD_LIGHT, nil, { shape = "Cylinder" })
	y:decor("YaguraStair", Vector3.new(2.4, 0.4, 6), CFrame.new(0, 2.5, -7.4) * CFrame.Angles(math.rad(40), 0, 0), P.WOOD, M.WoodPlanks)
	for k = -3, 3 do
		CityKit.Chochin(y, Vector3.new(k * 1.4, 11.2, -5.4), if k % 2 == 0 then P.LANTERN else P.PAPER, 0.7)
		CityKit.Chochin(y, Vector3.new(k * 1.4, 11.2, 5.4), if k % 2 == 0 then P.LANTERN else P.PAPER, 0.7)
	end
	local apex = Vector3.new(-360, WALK + 22, 36)
	for _, to in ipairs({ { -392, 14 }, { -376, 14 }, { -344, 14 }, { -328, 14 }, { -392, 58 }, { -328, 58 }, { -360, 60 } }) do
		CityKit.LanternString(f, apex, Vector3.new(to[1], 19, to[2]), 6, { P.LANTERN, P.PAPER, P.SAKURA })
	end
	for _, at in ipairs({ { -384, 56 }, { -336, 56 } }) do
		CityKit.Sakura(f:within(CFrame.new(at[1], WALK, at[2])), at[1], 1.8)
	end
	for _, at in ipairs({ { -378, 22 }, { -342, 22 } }) do
		CityKit.Bench(CityKit.Scaled(f:within(CFrame.new(at[1], WALK, at[2])), 1.3), P.WOOD_LIGHT)
	end
end

-- ------------------------------------------------------------------ the Steelworks --

local function shed(f: B, x: number, z: number, w: number, d: number, h: number, colour: Color3, open: boolean, label: string)
	-- An industrial shed at (x, z): corrugated walls, a pitched roof, its front to the yard road (+Z).
	local b = f:within(CFrame.new(x, 0, z) * CFrame.Angles(0, math.pi, 0))
	local hz = d / 2
	b:part("ShedWall", Vector3.new(w, h, 1.2), Vector3.new(0, h / 2, hz - 0.6), colour, M.CorrodedMetal)
	for _, s in ipairs({ -1, 1 }) do
		b:part("ShedWall", Vector3.new(1.2, h, d), Vector3.new(s * (w / 2 - 0.6), h / 2, 0), colour, M.CorrodedMetal)
	end
	if open then
		for _, s in ipairs({ -1, 1 }) do
			b:part("ShedWall", Vector3.new(w * 0.18, h, 1.2), Vector3.new(s * (w / 2 - w * 0.09), h / 2, -hz + 0.6), colour, M.CorrodedMetal)
		end
		b:decor("Lintel", Vector3.new(w * 0.64, h * 0.22, 1.4), Vector3.new(0, h - h * 0.11, -hz + 0.6), colour, M.CorrodedMetal)
	else
		b:part("ShedWall", Vector3.new(w, h, 1.2), Vector3.new(0, h / 2, -hz + 0.6), colour, M.CorrodedMetal)
		for _, s in ipairs({ -1, 1 }) do
			b:decor("Shutter", Vector3.new(w * 0.26, h * 0.6, 0.3), Vector3.new(s * w * 0.22, h * 0.3, -hz - 0.1), P.SHUTTER, M.DiamondPlate)
		end
	end
	local rise = h * 0.32
	for _, s in ipairs({ -1, 1 }) do
		local r = b:part("ShedRoof", Vector3.new(w + 2, rise, hz + 1), CFrame.new(0, h + rise / 2, s * (hz + 1) / 2)
			* CFrame.Angles(0, if s < 0 then 0 else math.pi, 0), Color3.fromRGB(150, 160, 170), M.CorrodedMetal, { shape = "Wedge" })
		r.CastShadow = true
	end
	b:decor("ShedRidge", Vector3.new(w + 2.4, 1, 2), Vector3.new(0, h + rise + 0.3, 0), darker(colour, 0.25))
	for k = -2, 2 do
		b:decor("ShedRib", Vector3.new(0.5, h, 0.5), Vector3.new(k * w / 5, h / 2, -hz - 0.1), darker(colour, 0.15))
	end
	CityKit.Board(At(b, 0, -hz, "-z"), label, 0, h * 0.86, math.min(w * 0.5, 40), 3.6, Color3.fromRGB(60, 110, 170), P.WHITE, 0.4)
	return b
end

local function container(f: B, at: CFrame, c: Color3)
	local b = f:within(at)
	b:part("Container", Vector3.new(8, 8.6, 20), Vector3.new(0, 4.3, 0), c, M.CorrodedMetal)
	for z = -8, 8, 4 do
		b:decor("ContainerRib", Vector3.new(8.08, 8, 0.3), Vector3.new(0, 4.3, z), darker(c, 0.15))
	end
	b:decor("ContainerDoor", Vector3.new(7.4, 8, 0.2), Vector3.new(0, 4.3, -10.06), darker(c, 0.2))
end

local function steelworks(root: B)
	local f = root:folder("Steelworks")
	local x0, x1, z0, z1 = Middle.EDGE, 600, Middle.CANAL_ROAD.z1, Middle.NORTH.z0
	local quay = Middle.DOCK.x0
	CityKit.Patch(f, "YardFloor", x0 + 4, quay, z0, z1 - 14, 0.01, Color3.fromRGB(128, 126, 122), M.Concrete)
	Blocks.Walk(f, x0 + 4, x1, z1 - 14, z1, { "+z" })
	Blocks.Walk(f, x0 + 4, quay, z0, z0 + 6, { "-z" })
	-- The wall along the Scramble, the gate in it at the end of Hanami-dori.
	for _, seg in ipairs({ { z0 + 6, -22 }, { 22, z1 - 14 } }) do
		f:part("YardWall", Vector3.new(1.6, 12, seg[2] - seg[1]), Vector3.new(x0 + 5, 6, (seg[1] + seg[2]) / 2), P.CONCRETE, M.Concrete)
		f:decor("WallCap", Vector3.new(2.2, 0.6, seg[2] - seg[1]), Vector3.new(x0 + 5, 12.3, (seg[1] + seg[2]) / 2), P.CONCRETE_DARK)
	end
	local g = At(f, x0 + 5, 0, "-x")
	for _, x in ipairs({ -24, 24 }) do
		g:part("GatePier", Vector3.new(4, 18, 4), Vector3.new(x, 9, 0), Color3.fromRGB(150, 150, 146), M.Concrete)
	end
	g:decor("GateBeam", Vector3.new(52, 5, 2), Vector3.new(0, 20, 0), P.KURO)
	text(g, "黒金製鉄所  KUROGANE STEEL", CFrame.new(0, 20, -1.06), 46, 3.4, P.GOLD, Enum.Font.GothamBlack)
	g:decor("SlidingGate", Vector3.new(20, 8, 0.4), Vector3.new(-14, 4, 3), Color3.fromRGB(200, 200, 196), M.DiamondPlate, { transparency = 0.35 })
	-- The guard booth by the gate, the map someone left on a table outside it.
	local booth = CityKit.Scaled(f:within(CFrame.new(206, 0, 34)), 1.3)
	booth:part("Booth", Vector3.new(8, 8, 8), Vector3.new(0, 4, 0), Color3.fromRGB(226, 228, 220))
	booth:decor("BoothWindow", Vector3.new(8.1, 3, 6), Vector3.new(0, 5, 0), P.GLASS, M.Glass)
	booth:decor("BoothRoof", Vector3.new(9, 0.6, 9), Vector3.new(0, 8.3, 0), Color3.fromRGB(70, 110, 160))
	-- The yard road from the gate to the quay, a pipe rack along it.
	Blocks.Lanes(f, true, x0 + 8, quay, 0, 12)
	for x = 200, 500, 20 do
		f:part("RackPost", Vector3.new(1, 18, 1), Vector3.new(x, 9, 26), P.STEEL)
		f:decor("RackArm", Vector3.new(0.8, 0.8, 7), Vector3.new(x, 17.6, 26), P.STEEL)
	end
	for k, c in ipairs({ Color3.fromRGB(200, 196, 180), Color3.fromRGB(110, 140, 180), Color3.fromRGB(230, 200, 60) }) do
		f:decor("Pipe", Vector3.new(300, 1.4, 1.4), Vector3.new(350, 18.6, 23.6 + k * 1.6), c, nil, { shape = "Cylinder" })
	end
	-- Warehouse one, open to the road (the ledger in it); warehouse two, shut.
	local tin = Color3.fromRGB(196, 206, 214)
	shed(f, 250, -76, 96, 64, 24, tin, true, "第一倉庫  WAREHOUSE 1")
	for k = 0, 5 do
		f:part("Crate", Vector3.new(5, 5, 5), Vector3.new(218 + (k % 3) * 6.5, 2.5, -92 + (k // 3) * 7), P.WOOD_LIGHT, M.WoodPlanks)
	end
	local lift = CityKit.Scaled(f:within(CFrame.new(266, 0, -62) * CFrame.Angles(0, 0.6, 0)), 1.3)
	lift:part("Forklift", Vector3.new(4, 3, 6), Vector3.new(0, 1.8, 0), Color3.fromRGB(240, 180, 40))
	lift:decor("ForkMast", Vector3.new(3, 8, 0.6), Vector3.new(0, 4, -3.2), P.KURO)
	lift:decor("Forks", Vector3.new(2.6, 0.3, 3), Vector3.new(0, 0.8, -5), P.KURO)
	shed(f, 372, -76, 96, 64, 28, Color3.fromRGB(150, 176, 196), false, "第二倉庫  WAREHOUSE 2")
	local cols = { Color3.fromRGB(196, 78, 62), Color3.fromRGB(60, 112, 168), Color3.fromRGB(226, 170, 62), Color3.fromRGB(72, 136, 104) }
	for k = 0, 3 do
		container(f, CFrame.new(452 + (k % 2) * 10, 0, -96 + (k // 2) * 24), cols[k % 4 + 1])
		if k ~= 2 then
			container(f, CFrame.new(452 + (k % 2) * 10, 8.6, -96 + (k // 2) * 24), cols[(k + 2) % 4 + 1])
		end
	end
	-- The site office, the sealed orders on the table under its awning.
	Blocks.Building(f, 240, 120, "-z", { w = 56, d = 34, floors = 2, style = "tile", colour = Color3.fromRGB(226, 228, 220), seed = 802,
		shop = { jp = "現場事務所", en = "SITE OFFICE", colour = Color3.fromRGB(60, 110, 170), kind = "glass", awning = true }, left = true,
		right = true }, 0)
	-- THE FURNACE HALL across the yard's north, the furnace mouth glowing, its stacks.
	CityKit.Patch(f, "FurnaceYard", 318, 482, 56, 130, 0.03, Color3.fromRGB(110, 106, 102), M.Concrete)
	local hall = At(f, 400, 130, "-z")
	hall:part("FurnaceHall", Vector3.new(160, 46, 56), Vector3.new(0, 23, 28), Color3.fromRGB(120, 92, 80), M.CorrodedMetal)
	hall:decor("HallBand", Vector3.new(160.2, 4, 56.2), Vector3.new(0, 40, 28), Color3.fromRGB(80, 60, 52))
	hall:decor("FurnaceMouth", Vector3.new(22, 16, 0.4), Vector3.new(0, 8, -0.2), Color3.fromRGB(255, 120, 40), M.Neon)
	hall:decor("FurnaceHood", Vector3.new(28, 3, 6), Vector3.new(0, 17.5, -3), P.KURO)
	hall:light("Point", Vector3.new(0, 8, -6), Color3.fromRGB(255, 130, 60), 3, 50)
	text(hall, "黒金", CFrame.new(0, 31, -0.1), 26, 10, Color3.fromRGB(240, 220, 200), Enum.Font.GothamBlack)
	for x = -72, 72, 16 do
		hall:decor("HallWindow", Vector3.new(11, 4.4, 0.3), Vector3.new(x, 37, -0.1), Color3.fromRGB(240, 170, 90), M.Glass)
	end
	for _, x in ipairs({ -50, -45, 45, 50 }) do
		hall:decor("HallPipe", Vector3.new(40, 1.8, 1.8), vertical(Vector3.new(x, 20, -1.3)), Color3.fromRGB(150, 150, 150), nil, { shape = "Cylinder" })
	end
	hall:part("Catwalk", Vector3.new(110, 0.8, 4.4), Vector3.new(0, 22, -2.2), Color3.fromRGB(110, 116, 122), M.DiamondPlate)
	hall:decor("CatwalkRail", Vector3.new(110, 0.3, 0.3), Vector3.new(0, 25.4, -4.3), P.LINE_YELLOW)
	for x = -54, 54, 12 do
		hall:decor("CatwalkPost", Vector3.new(0.3, 3.4, 0.3), Vector3.new(x, 23.8, -4.3), P.LINE_YELLOW)
	end
	CityKit.Stairs(hall:within(CFrame.new(-62, 0, -6) * CFrame.Angles(0, math.pi / 2, 0)), Vector3.new(0, 0, 0), 4, 22, 26,
		Color3.fromRGB(110, 116, 122), M.DiamondPlate, 1)
	CityKit.Board(hall, "安全第一  SAFETY FIRST", 30, 28.5, 22, 3, Color3.fromRGB(40, 150, 90), P.WHITE, 0.4)
	for _, x in ipairs({ -50, 50 }) do
		local stack = hall:within(CFrame.new(x, 0, 40))
		stack:part("Chimney", Vector3.new(130, 9, 9), vertical(Vector3.new(0, 65, 0)), P.WHITE, M.Concrete, { shape = "Cylinder" })
		for yy = 80, 122, 20 do
			stack:decor("ChimneyBand", Vector3.new(10, 9.4, 9.4), vertical(Vector3.new(0, yy, 0)), Color3.fromRGB(220, 60, 50), nil, { shape = "Cylinder" })
		end
		for k = 0, 2 do
			stack:decor("Smoke", Vector3.new(14 + k * 7, 14 + k * 7, 14 + k * 7), Vector3.new(k * 5, 140 + k * 12, -k * 6),
				Color3.fromRGB(230, 230, 232), nil, { shape = "Ball", transparency = 0.35 + k * 0.15 })
		end
	end
	-- The conveyor up to the hall's roof.
	local cf, len = Kit.Span(Vector3.new(500, 2, 70), Vector3.new(480, 40, 150))
	f:decor("Conveyor", Vector3.new(4, 1.4, len), cf, Color3.fromRGB(70, 76, 84))
	for _, t in ipairs({ 0.2, 0.5, 0.8 }) do
		local p = Vector3.new(500, 2, 70):Lerp(Vector3.new(480, 40, 150), t)
		f:part("ConveyorLeg", Vector3.new(1, p.Y, 1), Vector3.new(p.X, p.Y / 2, p.Z), P.STEEL)
	end
	CityKit.Marker(f, "ForemanSpot", S.Foundry + Vector3.new(0, 0.5, 16))
	for _, at in ipairs({ { 360, 100 }, { 440, 100 }, { 400, 80 } }) do
		CityKit.Marker(f, "ForemanAddSpot", Vector3.new(at[1], 0.5, at[2]))
	end
	-- Ladles, ingots and a skip in the yard: cover for the fight.
	for _, at in ipairs({ { 340, 74 }, { 462, 76 } }) do
		f:part("Ladle", Vector3.new(9, 9, 9), vertical(Vector3.new(at[1], 4.5, at[2])), Color3.fromRGB(70, 66, 64), M.CorrodedMetal, { shape = "Cylinder" })
		f:decor("Molten", Vector3.new(0.4, 7.6, 7.6), vertical(Vector3.new(at[1], 9.1, at[2])), Color3.fromRGB(255, 140, 50), M.Neon, { shape = "Cylinder" })
	end
	for _, at in ipairs({ { 370, 66 }, { 430, 66 } }) do
		f:part("Ingots", Vector3.new(9, 3.6, 6), Vector3.new(at[1], 1.8, at[2]), Color3.fromRGB(110, 114, 122), M.Metal)
	end
	-- The quay: its edge, bollards, the crane, containers, the ship alongside.
	local water = 8
	f:part("DockBed", Vector3.new(120, 2, z1 - z0 + 40), Vector3.new(quay + 60, -water - 1, (z0 + z1) / 2), Color3.fromRGB(60, 80, 90), M.Slate)
	f:decor("DockWater", Vector3.new(120, water - 3, z1 - z0 + 40), Vector3.new(quay + 60, -water + (water - 3) / 2, (z0 + z1) / 2),
		Color3.fromRGB(64, 128, 160), M.Glass, { transparency = 0.25 })
	f:part("QuayWall", Vector3.new(1.2, water, z1 - z0), Vector3.new(quay + 0.6, -water / 2, (z0 + z1) / 2), P.CONCRETE_DARK, M.Concrete)
	f:part("QuayEdge", Vector3.new(1.6, 1.4, z1 - z0), Vector3.new(quay - 0.8, 0.7, (z0 + z1) / 2), P.LINE_YELLOW)
	for z = z0 + 10, z1 - 20, 20 do
		f:part("Bollard", Vector3.new(2, 2.2, 2), vertical(Vector3.new(quay - 3, 1.1, z)), P.KURO, nil, { shape = "Cylinder" })
	end
	-- The ground under the quay's far side is gone: the dock basin, then the city's edge.
	local ship = f:within(CFrame.new(quay + 34, 0, 30))
	local hullC = Color3.fromRGB(40, 60, 100)
	ship:part("ShipHull", Vector3.new(40, 18, 200), Vector3.new(0, 1, 0), hullC, M.Metal)
	ship:decor("ShipBoot", Vector3.new(40.2, 3, 200.2), Vector3.new(0, -6.5, 0), Color3.fromRGB(170, 50, 46))
	ship:part("ShipBow", Vector3.new(28, 18, 16), Vector3.new(0, 1, -108), hullC, M.Metal)
	ship:part("ShipBow", Vector3.new(12, 18, 10), Vector3.new(0, 1, -121), hullC, M.Metal)
	ship:decor("ShipDeck", Vector3.new(38, 0.6, 196), Vector3.new(0, 10.2, 0), Color3.fromRGB(150, 70, 60))
	ship:part("ShipBridge", Vector3.new(32, 22, 16), Vector3.new(0, 21, 84), P.WHITE)
	ship:decor("BridgeWindows", Vector3.new(32.2, 3, 16.2), Vector3.new(0, 28, 84), P.GLASS_DARK, M.Glass)
	ship:decor("Funnel", Vector3.new(8, 14, 8), Vector3.new(0, 39, 90), Color3.fromRGB(220, 60, 50))
	text(At(ship, -20.1, 0, "-x"), "KUROGANE MARU", CFrame.new(0, 3, 0), 60, 6, P.WHITE, Enum.Font.GothamBlack)
	for k = 0, 6 do
		for j = 0, 1 do
			container(ship, CFrame.new(-8.6 + j * 17.2, 10.5, -70 + k * 22) * CFrame.Angles(0, 0, 0), cols[(k + j) % 4 + 1])
		end
	end
	-- The crane: four legs on the quay, the machinery house, the boom out over the water, a
	-- walkway between the legs with a ladder up to it.
	local crane = f:within(CFrame.new(S.Crane))
	local craneC = Color3.fromRGB(230, 120, 50)
	local walkTop = HanamiConfig.Seals[3].Y
	for _, x in ipairs({ -10, 10 }) do
		for _, z in ipairs({ -10, 10 }) do
			crane:part("CraneLeg", Vector3.new(2.2, 50, 2.2), Vector3.new(x, 25, z), craneC)
		end
		crane:decor("CraneBrace", Vector3.new(1.4, 1.4, 20), Vector3.new(x, 20, 0), craneC)
	end
	crane:part("CraneWalk", Vector3.new(22, 1, 22), Vector3.new(0, walkTop - 0.5, 0), Color3.fromRGB(120, 126, 132), M.DiamondPlate)
	for _, spec in ipairs({ { Vector3.new(22, 3.4, 0.4), Vector3.new(0, walkTop + 1.7, -11) }, { Vector3.new(22, 3.4, 0.4), Vector3.new(0, walkTop + 1.7, 11) },
		{ Vector3.new(0.4, 3.4, 22), Vector3.new(11, walkTop + 1.7, 0) } }) do
		crane:part("CraneRail", spec[1], spec[2], P.LINE_YELLOW)
	end
	crane:part("CraneHouse", Vector3.new(18, 9, 14), Vector3.new(0, 55, 0), craneC)
	crane:part("CraneBoom", Vector3.new(110, 3.4, 4), Vector3.new(44, 60, 0), craneC)
	crane:decor("CraneApex", Vector3.new(3, 18, 3), Vector3.new(-4, 68, 0), craneC)
	local tcf, tlen = Kit.Span(Vector3.new(-4, 76, 0), Vector3.new(96, 61.7, 0))
	crane:decor("CraneTie", Vector3.new(0.5, 0.5, tlen), tcf, P.STEEL)
	crane:decor("Hook", Vector3.new(1.4, 16, 1.4), Vector3.new(76, 50, 0), P.KURO)
	CityKit.Ladder(crane, Vector3.new(-12.2, 0, -10), walkTop + 1, P.LINE_YELLOW)
	-- Containers on the quay, the crates with ZEE on them among them.
	for k = 0, 2 do
		container(f, CFrame.new(530, 0, 60 + k * 26), cols[k % 4 + 1])
	end
	container(f, CFrame.new(530, 8.6, 86), cols[4])
	local crate = CityKit.Scaled(f:within(CFrame.new(S.Crane.X - 44, 0, 30)), 1.3)
	crate:part("ZeeCrate", Vector3.new(3, 3, 3), Vector3.new(-3.6, 1.5, 0), P.WOOD_LIGHT, M.WoodPlanks)
	text(At(crate, -3.6, -1.56, "-z"), "ZEE", CFrame.new(0, 1.6, 0), 2.4, 1.2, P.CRIMSON, Enum.Font.GothamBlack)
end

function Middle.Build(root: B)
	scrambleBlocks(root)
	scrambleStreets(root)
	lanternRow(root)
	steelworks(root)
end

return Middle
