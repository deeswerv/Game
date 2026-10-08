--!strict
-- HANAMI CITY, the north: past the north avenue.
--
--   THE THOUSAND GATES  a stair of red torii, one after another, from the gates' little square
--                       up the castle hill between lawns of cherry trees.
--   KUROGANE CASTLE     on its stone base forty studs over the street: white walls and the gate
--                       house, the court of raked gravel where the Shogun waits on his dais,
--                       the palace hall, the tea garden, and the black keep over all of it.
--   HANAMI PARK         the lantern pond: paper lanterns floating on the water, a torii standing
--                       in it, an island and its pavilion over a red bridge, stone lanterns and
--                       cherry trees round the shore, the tea house.
--   KUROGANE HEIGHTS    the clan's towers round their plaza: the headquarters in black glass.
--
-- City frame (HanamiConfig): +Z north, +X west. Real studs throughout.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ServerScriptService.ArenaService.Kit)
local CityKit = require(ServerScriptService.HanamiService.CityKit)
local Blocks = require(ServerScriptService.HanamiService.CityBlocks)
local HanamiConfig = require(ReplicatedStorage.HanamiConfig)

local North = {}

type B = Kit.Builder
local M = Enum.Material
local P = CityKit.P
local darker = CityKit.Darker
local vertical = CityKit.Vertical
local At = CityKit.At
local text = CityKit.Text
local WALK = Blocks.WALK
local S = HanamiConfig.Sites

North.WALK_Z = { 228, 240 }              -- the north avenue's north pavement
North.STAIR = { z0 = 262, z1 = 360, w = 32 }
North.BASE = { x0 = -200, x1 = 200, z0 = 360, z1 = 600 }

-- ------------------------------------------------------------------ the Thousand Gates --

local function gates(root: B)
	local f = root:folder("ThousandGates")
	local St = North.STAIR
	local Y = HanamiConfig.PLATEAU
	Blocks.Walk(f, -600, 600, North.WALK_Z[1], North.WALK_Z[2], { "-z" })
	-- The gates' square: stone paving, the great torii, the stone lanterns.
	Blocks.Walk(f, -44, 44, North.WALK_Z[2], St.z0, { "-x", "+x" }, P.STONE)
	CityKit.Torii(f:within(CFrame.new(0, WALK, 250)), 34, 28, P.VERMILION)
	CityKit.Board(At(f, 0, 249.2, "-z", WALK), CityKit.Stacked("黒金城"), 0, 31.6, 4.4, 8, P.KURO, P.GOLD, 0.4)
	for _, x in ipairs({ -38, -28, 28, 38 }) do
		CityKit.StoneLantern(f:within(CFrame.new(x, WALK, 256)), 2)
	end
	CityKit.Marker(f, "StairFoot", S.StairFoot + Vector3.new(0, 0.5, 0))
	-- The stair up the hill, a torii every few steps -- a tunnel of them, vermilion and black.
	CityKit.Stairs(f, Vector3.new(0, WALK, St.z0), St.w, Y - WALK, St.z1 - St.z0, P.STONE, M.Slate, 1)
	for _, s in ipairs({ -1, 1 }) do
		-- The stair's stone sides, stepping up with it.
		local cf, len = Kit.Span(Vector3.new(s * (St.w / 2 + 1.5), WALK + 1, St.z0), Vector3.new(s * (St.w / 2 + 1.5), Y + 1, St.z1))
		f:part("StairWall", Vector3.new(3, 3, len), cf, P.STONE_DARK, M.Slate)
	end
	local k = 0
	for z = St.z0 + 4, St.z1 - 3, 5 do
		k += 1
		local y = WALK + (z - St.z0) / (St.z1 - St.z0) * (Y - WALK)
		CityKit.Torii(f:within(CFrame.new(0, math.floor(y), z)), St.w - 4, 14, P.VERMILION)
		if k % 3 == 0 then
			for _, x in ipairs({ -St.w / 2 - 1.5, St.w / 2 + 1.5 }) do
				CityKit.StoneLantern(f:within(CFrame.new(x, math.floor(y) + 2.5, z)), 1.2)
			end
		end
	end
	-- The castle park either side of the stair: lawns, gravel paths, cherry trees in rows,
	-- benches, a stone wall along the base's foot.
	for _, s in ipairs({ -1, 1 }) do
		local x0, x1 = if s < 0 then -220 else 44, if s < 0 then -44 else 220
		CityKit.Patch(f, "Lawn", x0, x1, North.WALK_Z[2], North.BASE.z0 - 6, 0.03, Color3.fromRGB(128, 186, 98), M.Grass)
		CityKit.Patch(f, "ParkPath", x0, x1, 296, 306, 0.06, P.GRAVEL, M.Pebble)
		for xi = 0, 4 do
			for zi = 0, 1 do
				local x = s * (64 + xi * 36)
				CityKit.Sakura(f:within(CFrame.new(x, 0, 272 + zi * 56)), xi * 17 + zi * 5 + s, 2.3)
			end
			CityKit.Bench(CityKit.Scaled(f:within(CFrame.new(s * (82 + xi * 36), 0, 291)), 1.3), P.WOOD_LIGHT)
		end
	end
end

-- ------------------------------------------------------------------ Kurogane Castle --

local function castle(root: B)
	local f = root:folder("Castle")
	local Bs = North.BASE
	local Y = HanamiConfig.PLATEAU
	local stone = Color3.fromRGB(150, 146, 140)
	local plaster = Color3.fromRGB(244, 240, 230)
	-- The stone base: a block with its walls battered outward at the foot, courses picked out.
	local w, d = Bs.x1 - Bs.x0, Bs.z1 - Bs.z0
	f:part("CastleBase", Vector3.new(w, Y + 6, d), Vector3.new(0, (Y - 6) / 2, (Bs.z0 + Bs.z1) / 2), stone, M.Slate)
	local half = North.STAIR.w / 2 + 3
	for _, s in ipairs({ -1, 1 }) do
		local seg = Bs.x1 - half
		f:part("Batter", Vector3.new(seg, Y, 8), CFrame.new(s * (half + seg / 2), Y / 2, Bs.z0 - 4), stone, M.Slate, { shape = "Wedge" })
		f:part("Batter", Vector3.new(d, Y, 8), CFrame.new(s * (Bs.x1 + 4), Y / 2, (Bs.z0 + Bs.z1) / 2) * CFrame.Angles(0, s * math.pi / 2, 0),
			stone, M.Slate, { shape = "Wedge" })
	end
	for y = 5, Y - 3, 6 do
		f:decor("Course", Vector3.new(w + 0.4, 0.4, 0.4), Vector3.new(0, y, Bs.z0 + 0.1), darker(stone, 0.18))
	end
	f:decor("Lawn", Vector3.new(w - 8, 0.1, d - 8), Vector3.new(0, Y + 0.05, (Bs.z0 + Bs.z1) / 2), Color3.fromRGB(128, 180, 98), M.Grass)
	-- The outer wall: white plaster on a stone footing, a dark tiled cap, loopholes.
	local function wallRun(a: Vector3, c: Vector3)
		local cf, len = Kit.Span(a, c)
		f:part("CastleWall", Vector3.new(3, 12, len), cf * CFrame.new(0, 6, 0), plaster)
		f:decor("WallFoot", Vector3.new(3.6, 2.6, len), cf * CFrame.new(0, 1.3, 0), stone, M.Slate)
		f:decor("WallCap", Vector3.new(5.4, 1.4, len + 1.4), cf * CFrame.new(0, 12.5, 0), P.TILE_ROOF)
		f:decor("WallCapRidge", Vector3.new(1.8, 0.8, len + 1.4), cf * CFrame.new(0, 13.4, 0), P.TILE_ROOF_EDGE)
		for t = 6, len - 6, 10 do
			f:decor("Loophole", Vector3.new(3.2, 1.4, 1), cf * CFrame.new(0, 8, -len / 2 + t), P.KURO)
		end
	end
	local x0, x1, z0, z1 = Bs.x0 + 6, Bs.x1 - 6, Bs.z0 + 6, Bs.z1 - 6
	wallRun(Vector3.new(x0, Y, z0), Vector3.new(-18, Y, z0))
	wallRun(Vector3.new(18, Y, z0), Vector3.new(x1, Y, z0))
	wallRun(Vector3.new(x0, Y, z0), Vector3.new(x0, Y, z1))
	wallRun(Vector3.new(x1, Y, z0), Vector3.new(x1, Y, z1))
	wallRun(Vector3.new(x0, Y, z1), Vector3.new(x1, Y, z1))
	-- The gate house over the opening, its great doors standing open.
	local gate = f:within(CFrame.new(0, Y, z0))
	for _, x in ipairs({ -16, 16 }) do
		gate:part("GatePier", Vector3.new(5, 18, 10), Vector3.new(x, 9, 0), stone, M.Slate)
	end
	gate:part("GateHouse", Vector3.new(44, 11, 13), Vector3.new(0, 23.5, 0), plaster)
	gate:decor("GateHouseBand", Vector3.new(44.2, 1.8, 13.2), Vector3.new(0, 19, 0), P.KURO)
	gate:part("GateRoof", Vector3.new(50, 6, 9), CFrame.new(0, 32, -4.5), P.TILE_ROOF, M.Slate, { shape = "Wedge" })
	gate:part("GateRoof", Vector3.new(50, 6, 9), CFrame.new(0, 32, 4.5) * CFrame.Angles(0, math.pi, 0), P.TILE_ROOF, M.Slate, { shape = "Wedge" })
	for _, s in ipairs({ -1, 1 }) do
		gate:decor("GateDoor", Vector3.new(12, 16, 1), CFrame.new(s * 13, 8, 6) * CFrame.Angles(0, s * math.rad(75), 0), P.WOOD_DARK, M.Wood)
	end
	CityKit.Board(At(gate, 0, -6.6, "-z"), "黒金", 0, 24, 8, 4, P.KURO, P.GOLD, 0.3)
	CityKit.Marker(f, "KeepGate", S.KeepGate + Vector3.new(0, 0.5, 0))
	-- Corner turrets on the front.
	for _, x in ipairs({ x0 + 8, x1 - 8 }) do
		local t = f:within(CFrame.new(x, Y, z0 + 8))
		t:part("Turret", Vector3.new(20, 16, 20), Vector3.new(0, 8, 0), plaster)
		t:decor("TurretBand", Vector3.new(20.2, 2, 20.2), Vector3.new(0, 4, 0), P.KURO)
		for _, spec in ipairs({ { 26, 7, 13, 19.5 }, { 16, 5, 8, 31 } }) do
			t:part("TurretRoof", Vector3.new(spec[1], spec[2], spec[3]), CFrame.new(0, spec[4], -spec[3] / 2), P.TILE_ROOF, M.Slate, { shape = "Wedge" })
			t:part("TurretRoof", Vector3.new(spec[1], spec[2], spec[3]), CFrame.new(0, spec[4], spec[3] / 2) * CFrame.Angles(0, math.pi, 0), P.TILE_ROOF,
				M.Slate, { shape = "Wedge" })
		end
		t:part("TurretTop", Vector3.new(12, 8, 12), Vector3.new(0, 26, 0), plaster)
	end
	-- The court: raked gravel, the stone path, banners down both sides, fire baskets.
	local box = HanamiConfig.CourtBox
	CityKit.Patch(f, "CourtGravel", box.x0, box.x1, box.z0, box.z1, Y + 0.02, P.GRAVEL, M.Pebble)
	CityKit.Patch(f, "CourtPath", -7, 7, z0 + 6, box.z1, Y + 0.06, P.STONE, M.Slate)
	for z = box.z0 + 4, box.z1 - 4, 5 do
		f:decor("Raked", Vector3.new(box.x1 - box.x0 - 4, 0.05, 0.4), Vector3.new(0, Y + 0.14, z), darker(P.GRAVEL, 0.08))
	end
	for z = box.z0 + 8, box.z1 - 8, 18 do
		for _, x in ipairs({ box.x0 + 3, box.x1 - 3 }) do
			f:decor("BannerPole", Vector3.new(0.6, 22, 0.6), Vector3.new(x, Y + 11, z), P.KURO)
			f:decor("Nobori", Vector3.new(0.3, 15, 4.6), Vector3.new(x, Y + 13, z + 2.6), P.CRIMSON, M.Fabric)
			text(At(f, x + (if x < 0 then 0.18 else -0.18), z + 2.6, if x < 0 then "+x" else "-x"), CityKit.Stacked("黒金"), CFrame.new(0, Y + 13.6, 0),
				3.6, 11, P.WHITE, Enum.Font.GothamBlack)
		end
	end
	for _, x in ipairs({ -40, 40 }) do
		local fb = CityKit.Scaled(f:within(CFrame.new(x, Y, box.z0 - 6)), 1.4)
		fb:part("Brazier", Vector3.new(3, 3, 3), vertical(Vector3.new(0, 3.5, 0)), P.KURO, M.Metal, { shape = "Cylinder" })
		fb:decor("BrazierLegs", Vector3.new(2, 2, 2), Vector3.new(0, 1, 0), P.KURO)
		fb:decor("Flame", Vector3.new(2.4, 2.4, 2.4), Vector3.new(0, 5.6, 0), Color3.fromRGB(255, 150, 60), M.Neon, { shape = "Ball", transparency = 0.2 })
		fb:light("Point", Vector3.new(0, 7, 0), Color3.fromRGB(255, 160, 90), 2, 26)
	end
	CityKit.Marker(f, "CourtCentre", S.Court + Vector3.new(0, 0.5, 0))
	for _, at in ipairs({ { -50, 440 }, { 50, 440 }, { -60, 480 }, { 60, 480 }, { -24, 500 }, { 24, 500 } }) do
		CityKit.Marker(f, "CourtAddSpot", Vector3.new(at[1], Y + 0.5, at[2]))
	end
	-- Low hedges round the court, gaps to come and go through; stone lanterns down the path.
	for _, x in ipairs({ box.x0 - 2, box.x1 + 2 }) do
		for _, seg in ipairs({ { box.z0, 466 }, { 480, box.z1 } }) do
			f:part("Hedge", Vector3.new(3.4, 3.4, seg[2] - seg[1]), Vector3.new(x, Y + 1.7, (seg[1] + seg[2]) / 2), P.LEAF_DARK, M.Grass)
		end
	end
	for _, x in ipairs({ -12, 12 }) do
		for z = box.z0 - 30, box.z0 + 10, 20 do
			CityKit.StoneLantern(f:within(CFrame.new(x, Y, z)), 1.6)
		end
	end
	-- The throne on its dais, gold screens behind it.
	local dais = CityKit.Scaled(f:within(CFrame.new(S.Throne)), 1.3)
	dais:part("Dais", Vector3.new(24, 1.2, 12), Vector3.new(0, 0.6, 0), P.KURO, M.Wood)
	dais:part("DaisStep", Vector3.new(16, 0.6, 2), Vector3.new(0, 0.3, -7), P.KURO, M.Wood)
	dais:part("Throne", Vector3.new(5, 3, 3), Vector3.new(0, 2.7, 2), P.CRIMSON)
	dais:decor("ThroneBack", Vector3.new(5, 5, 0.8), Vector3.new(0, 5, 3.4), P.KURO)
	for k = -2, 2 do
		dais:decor("Byobu", Vector3.new(4.4, 7, 0.3), CFrame.new(k * 4.3, 4.7, 5.2) * CFrame.Angles(0, (k % 2) * 0.3 - 0.15, 0), P.GOLD, M.Metal)
	end
	CityKit.Marker(f, "ShogunSpot", S.Throne + Vector3.new(0, 1.2 * 1.3 + 0.5, -5))
	-- THE KEEP: a black castle on its own stone base -- five tiers, each with a skirt roof,
	-- white trim, gables on the front, the gold fish on the ridge.
	local keep = f:within(CFrame.new(0, Y, 572))
	keep:part("KeepBase", Vector3.new(96, 14, 40), Vector3.new(0, 7, 0), stone, M.Slate)
	local black = Color3.fromRGB(42, 42, 48)
	local tiers = { { 84, 32, 16 }, { 70, 27, 14 }, { 56, 22, 13 }, { 42, 18, 12 }, { 30, 14, 12 } }
	local yy = 14
	for i, t in ipairs(tiers) do
		local tw, td, th = t[1], t[2], t[3]
		keep:part("KeepTier", Vector3.new(tw, th, td), Vector3.new(0, yy + th / 2, 0), black)
		keep:decor("KeepTrim", Vector3.new(tw + 0.3, 1.1, td + 0.3), Vector3.new(0, yy + th - 1.8, 0), plaster)
		for x = -tw / 2 + 5, tw / 2 - 5, 8 do
			keep:decor("KeepWindow", Vector3.new(2.6, 3.2, td + 0.4), Vector3.new(x, yy + th / 2, 0), plaster)
		end
		local ry = yy + th + 1.6
		for _, s in ipairs({ -1, 1 }) do
			keep:part("KeepRoof", Vector3.new(tw + 8, 4, 5.4), CFrame.new(0, ry, s * (td / 2 + 1.4)) * CFrame.Angles(0, if s < 0 then 0 else math.pi, 0),
				P.TILE_ROOF, M.Slate, { shape = "Wedge" })
			keep:part("KeepRoof", Vector3.new(td + 8, 4, 5.4), CFrame.new(s * (tw / 2 + 1.4), ry, 0) * CFrame.Angles(0, s * -math.pi / 2, 0),
				P.TILE_ROOF, M.Slate, { shape = "Wedge" })
		end
		if i == 2 or i == 4 then
			keep:part("KeepGable", Vector3.new(tw * 0.4, 5.4, 4), CFrame.new(0, ry + 2.2, -td / 2 - 1.8), P.TILE_ROOF, M.Slate, { shape = "Wedge" })
			keep:decor("GableFace", Vector3.new(tw * 0.3, 3.2, 0.3), Vector3.new(0, ry + 1.4, -td / 2 - 0.3), plaster)
		end
		yy += th + 4
	end
	keep:part("KeepCap", Vector3.new(32, 6, 16), CFrame.new(0, yy + 1.5, -4), P.TILE_ROOF, M.Slate, { shape = "Wedge" })
	keep:part("KeepCap", Vector3.new(32, 6, 16), CFrame.new(0, yy + 1.5, 4) * CFrame.Angles(0, math.pi, 0), P.TILE_ROOF, M.Slate, { shape = "Wedge" })
	for _, x in ipairs({ -14, 14 }) do
		keep:decor("Shachihoko", Vector3.new(2, 4.4, 3), CFrame.new(x, yy + 6, 0) * CFrame.Angles(0, 0, x / 140), P.GOLD, M.Metal)
	end
	-- The palace hall along the court's west side, its long engawa and paper screens.
	local palace = CityKit.Scaled(At(f, 104, 470, "-x", Y), 1.35)
	palace:part("PalaceFooting", Vector3.new(60, 1.6, 24), Vector3.new(0, 0.8, 12), stone, M.Slate)
	palace:part("Palace", Vector3.new(56, 10, 18), Vector3.new(0, 6.6, 13), plaster)
	for k = -7, 7 do
		palace:decor("PalacePost", Vector3.new(0.8, 10, 0.6), Vector3.new(k * 4, 6.6, 3.8), P.WOOD_DARK)
		if k < 7 then
			palace:decor("Shoji", Vector3.new(3, 6, 0.2), Vector3.new(k * 4 + 2, 5.2, 3.9), P.PAPER)
		end
	end
	palace:decor("Engawa", Vector3.new(58, 0.4, 3), Vector3.new(0, 1.8, 2.3), P.WOOD_LIGHT, M.WoodPlanks)
	palace:part("PalaceRoof", Vector3.new(62, 6, 13), CFrame.new(0, 14.6, 6.5), P.TILE_ROOF, M.Slate, { shape = "Wedge" })
	palace:part("PalaceRoof", Vector3.new(62, 6, 13), CFrame.new(0, 14.6, 19.5) * CFrame.Angles(0, math.pi, 0), P.TILE_ROOF, M.Slate,
		{ shape = "Wedge" })
	palace:decor("PalaceRidge", Vector3.new(63, 1, 1.4), Vector3.new(0, 17.8, 13), P.TILE_ROOF_EDGE)
	-- The tea garden on the east: a pond, its red bridge, the tea house.
	local tea = f:within(CFrame.new(-138, Y, 470))
	tea:decor("PondWater", Vector3.new(0.3, 44, 44), vertical(Vector3.new(0, 0.2, 0)), P.WATER, nil, { shape = "Cylinder" })
	for k = 0, 17 do
		local a = k / 18 * math.pi * 2
		tea:part("PondStone", Vector3.new(4, 1.2, 2.6), CFrame.new(math.cos(a) * 22.4, 0.6, math.sin(a) * 22.4) * CFrame.Angles(0, -a, 0), P.STONE, M.Slate)
	end
	tea:decor("PondBridge", Vector3.new(6, 1.6, 48), CFrame.new(0, 1.8, 0), P.VERMILION)
	local house = CityKit.Scaled(tea:within(CFrame.new(-8, 0, -38)), 1.4)
	house:part("TeaHouse", Vector3.new(12, 7, 10), Vector3.new(0, 3.5, 0), P.PLASTER)
	house:part("TeaRoof", Vector3.new(15, 4, 7), CFrame.new(0, 9, -3.5), Color3.fromRGB(150, 120, 80), M.Grass, { shape = "Wedge" })
	house:part("TeaRoof", Vector3.new(15, 4, 7), CFrame.new(0, 9, 3.5) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(150, 120, 80), M.Grass,
		{ shape = "Wedge" })
	-- Gardens round the court: pines and cherry trees.
	for i, at in ipairs({ { -120, 410 }, { -160, 420 }, { -110, 530 }, { -160, 540 }, { 130, 400 }, { 160, 420 }, { 130, 545 }, { 170, 560 },
		{ -60, 395 }, { 60, 395 }, { -70, 560 }, { 70, 560 } }) do
		local b = f:within(CFrame.new(at[1], Y, at[2]))
		if i % 2 == 0 then
			CityKit.Pine(b, i * 3, 2)
		else
			CityKit.Sakura(b, i * 5, 2.2)
		end
	end
end

-- ------------------------------------------------------------------ Hanami Park --

local function park(root: B)
	local f = root:folder("Park")
	local x0, x1, z0, z1 = -600, -220, North.WALK_Z[2], 600
	CityKit.Patch(f, "Lawn", x0, x1, z0, z1, 0.03, Color3.fromRGB(108, 158, 84), M.Grass)
	-- Gravel paths: in from the avenue, round the pond.
	CityKit.Patch(f, "ParkPath", -408, -392, z0, 340, 0.06, P.GRAVEL, M.Pebble)
	CityKit.Patch(f, "ParkPath", x1 - 160, x1, 300, 312, 0.06, P.GRAVEL, M.Pebble)
	local pc = S.Pond
	local R = 70
	-- The pond: stone rim, dark water, the lanterns floating on it.
	local pond = f:within(CFrame.new(pc.X, 0, pc.Z))
	-- Fireflies over the water and the path round it after dark (CityLife.client).
	CityKit.Life(pond, "FireflyField", Vector3.new(0, 3, 0), Vector3.new(R * 2 + 20, 5, R * 2 + 20))
	pond:decor("PondPath", Vector3.new(0.1, R * 2 + 24, R * 2 + 24), vertical(Vector3.new(0, 0.07, 0)), P.GRAVEL, M.Pebble, { shape = "Cylinder" })
	pond:decor("PondWater", Vector3.new(0.4, R * 2, R * 2), vertical(Vector3.new(0, 0.3, 0)), Color3.fromRGB(58, 120, 150), M.Glass,
		{ shape = "Cylinder", reflectance = 0.2 })
	pond:decor("PondBed", Vector3.new(0.2, R * 2 - 1, R * 2 - 1), vertical(Vector3.new(0, 0.12, 0)), Color3.fromRGB(40, 70, 80), nil, { shape = "Cylinder" })
	for k = 0, 35 do
		local a = k / 36 * math.pi * 2
		pond:part("PondStone", Vector3.new(7, 1.4, 3.4), CFrame.new(math.cos(a) * (R + 1), 0.7, math.sin(a) * (R + 1)) * CFrame.Angles(0, -a + math.pi / 2, 0),
			P.STONE, M.Slate)
	end
	local rng = Random.new(1717)
	for k = 1, 40 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber(0.04, 0.9)) * (R - 6)
		local at = Vector3.new(math.cos(a) * r, 0.6, math.sin(a) * r)
		local l = pond:within(CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi), 0))
		l:decor("FloatBase", Vector3.new(2, 0.4, 2), Vector3.new(0, 0, 0), P.WOOD_DARK)
		l:decor("LanternGlass", Vector3.new(1.5, 1.8, 1.5), Vector3.new(0, 1.1, 0), if k % 3 == 0 then Color3.fromRGB(255, 196, 120) else P.PAPER)
		l:decor("FloatCap", Vector3.new(1.8, 0.2, 1.8), Vector3.new(0, 2.1, 0), P.WOOD_DARK)
	end
	-- The torii standing in the water.
	CityKit.Torii(pond:within(CFrame.new(0, 0, R - 18)), 22, 20, P.VERMILION)
	-- The island and its pavilion, the red bridge out to it.
	local isle = pond:within(CFrame.new(-18, 0, -14))
	isle:part("Island", Vector3.new(2.4, 34, 34), vertical(Vector3.new(0, 1.2, 0)), P.STONE, M.Slate, { shape = "Cylinder" })
	isle:decor("IslandLawn", Vector3.new(0.2, 32, 32), vertical(Vector3.new(0, 2.5, 0)), Color3.fromRGB(122, 180, 94), M.Grass, { shape = "Cylinder" })
	local pav = CityKit.Scaled(isle:within(CFrame.new(0, 2.4, 0)), 1.4)
	for _, x in ipairs({ -4, 4 }) do
		for _, z in ipairs({ -4, 4 }) do
			pav:part("PavilionPost", Vector3.new(0.6, 7, 0.6), Vector3.new(x, 3.5, z), P.VERMILION)
		end
	end
	pav:part("PavilionFloor", Vector3.new(10, 0.6, 10), Vector3.new(0, 0.3, 0), P.WOOD, M.WoodPlanks)
	for _, s in ipairs({ -1, 1 }) do
		pav:decor("PavilionRoof", Vector3.new(13, 3, 6.5), CFrame.new(0, 8.5, s * 3.25) * CFrame.Angles(0, if s < 0 then 0 else math.pi, 0), P.TILE_ROOF, nil,
			{ shape = "Wedge" })
	end
	CityKit.Chochin(pav, Vector3.new(0, 6, 0), P.LANTERN, 1.2)
	local cf, len = Kit.Span(Vector3.new(pc.X - 18 + 14, 2.4, pc.Z - 14 - 10), Vector3.new(pc.X - 18 + 40, 0.6, pc.Z - 14 - 60))
	f:part("ParkBridge", Vector3.new(6, 1, len), cf, P.VERMILION)
	for _, s in ipairs({ -1, 1 }) do
		f:decor("BridgeRail", Vector3.new(0.4, 2.4, len), cf * CFrame.new(s * 2.8, 1.6, 0), P.VERMILION)
	end
	-- Stone lanterns round the shore, cherry trees round them, benches facing the water.
	for k = 0, 13 do
		local a = k / 14 * math.pi * 2
		CityKit.StoneLantern(pond:within(CFrame.new(math.cos(a) * (R + 8), 0, math.sin(a) * (R + 8))), 1.6)
		local tr = R + 24 + (k % 2) * 8
		CityKit.Sakura(pond:within(CFrame.new(math.cos(a + 0.1) * tr, 0, math.sin(a + 0.1) * tr)), 900 + k, 2.4)
		if k % 3 == 0 then
			local at = Vector3.new(math.cos(a + 0.2) * (R + 14), 0, math.sin(a + 0.2) * (R + 14))
			CityKit.Bench(CityKit.Scaled(pond:within(CFrame.lookAt(at, Vector3.new(0, 0, 0))), 1.3), P.WOOD_LIGHT)
		end
	end
	-- The park's gate on the avenue, and the tea house by the water.
	CityKit.Torii(f:within(CFrame.new(-400, 0, z0 + 6)), 18, 16, P.VERMILION)
	CityKit.Board(At(f, -400, z0 + 5.2, "-z"), "花見公園  HANAMI PARK", 0, 19.2, 14, 2.4, P.KURO, P.WHITE, 0.3)
	local tea = CityKit.Scaled(At(f, -520, 330, "+x"), 1.5)
	tea:part("TeaHouse", Vector3.new(14, 7, 10), Vector3.new(0, 3.5, 5), P.PLASTER)
	tea:decor("TeaFront", Vector3.new(12, 5, 0.2), Vector3.new(0, 3.2, -0.1), P.PAPER)
	for k = -2, 2 do
		tea:decor("TeaPost", Vector3.new(0.5, 7, 0.4), Vector3.new(k * 3, 3.5, -0.2), P.WOOD_DARK)
	end
	tea:part("TeaRoof", Vector3.new(17, 4, 7), CFrame.new(0, 9, 1.5), Color3.fromRGB(150, 120, 80), M.Grass, { shape = "Wedge" })
	tea:part("TeaRoof", Vector3.new(17, 4, 7), CFrame.new(0, 9, 8.5) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(150, 120, 80), M.Grass,
		{ shape = "Wedge" })
	CityKit.Chochin(tea, Vector3.new(-4, 6, -1), P.LANTERN, 1)
	CityKit.Chochin(tea, Vector3.new(4, 6, -1), P.LANTERN, 1)
	-- More cherry trees about the lawns.
	for i = 0, 15 do
		local x = x0 + 20 + (i % 4) * 36 + (i // 4 % 2) * 18
		local z = if i < 8 then z0 + 20 + (i // 4) * 30 else z1 - 30 - ((i - 8) // 4) * 30
		CityKit.Sakura(f:within(CFrame.new(x, 0, z)), 950 + i, 2.2)
	end
end

-- ------------------------------------------------------------------ Kurogane Heights --

local function heights(root: B)
	local f = root:folder("Heights")
	local x0, x1, z0, z1 = 220, 600, North.WALK_Z[2], 600
	Blocks.Walk(f, x0, x1, z0, z1, { "-x" }, Color3.fromRGB(150, 148, 146))
	for x = x0 + 20, x1 - 10, 20 do
		f:decor("PlazaLine", Vector3.new(0.4, 0.05, z1 - z0), Vector3.new(x, WALK + 0.03, (z0 + z1) / 2), Color3.fromRGB(150, 146, 140))
	end
	-- Kurogane HQ: a tower of black glass, its name on the crown, a spire.
	CityKit.Tower(At(f, 400, 330, "-z", WALK), { w = 76, d = 70, floors = 22, seed = 901, glass = Color3.fromRGB(40, 46, 58),
		body = Color3.fromRGB(24, 26, 32), fin = Color3.fromRGB(70, 74, 84), podium = P.KURO, accent = Color3.fromRGB(200, 40, 50),
		name = "KUROGANE HOLDINGS", jp = "黒金", crown = "spire", left = true, right = true, back = true })
	CityKit.Tower(At(f, 280, 470, "-x", WALK), { w = 70, d = 54, floors = 16, seed = 902, glass = Color3.fromRGB(84, 110, 140),
		body = Color3.fromRGB(70, 76, 88), accent = Color3.fromRGB(200, 40, 50), left = true, right = true, back = true })
	CityKit.Tower(At(f, 520, 500, "-z", WALK), { w = 70, d = 64, floors = 13, seed = 903, glass = Color3.fromRGB(110, 140, 160),
		body = Color3.fromRGB(150, 156, 164), accent = P.GOLD, crown = "flat", left = true, right = true, back = true })
	-- The plaza: a ring of steel, planters, benches.
	local ring = f:within(CFrame.new(400, WALK, 270))
	ring:decor("Sculpture", Vector3.new(3, 30, 30), CFrame.new(0, 17, 0) * CFrame.Angles(0, math.rad(30), 0), Color3.fromRGB(190, 40, 50),
		M.Metal, { shape = "Cylinder" })
	ring:part("SculptureBase", Vector3.new(14, 2, 6), Vector3.new(0, 1, 0), P.KURO, M.Granite)
	for _, x in ipairs({ 300, 340, 460, 500 }) do
		CityKit.TreeBed(f:within(CFrame.new(x, WALK, 262)), x, false, 2.3)
	end
	-- A row along the avenue at its far west.
	Blocks.Row(f, 500, x1, 252, "-z", 40, 910, Blocks.CityPick(6, 9, 0.3, { "office", "tile" }), 30)
end

function North.Build(root: B)
	gates(root)
	castle(root)
	park(root)
	heights(root)
end

return North
