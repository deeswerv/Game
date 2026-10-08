--!strict
-- HANAMI CITY, the south: where you arrive. The railway on its viaduct along the city's edge,
-- a train standing at the platform; HANAMI STATION under it; the station square with the Great
-- Sakura, the taxi rank and the bus bay, the department store with its giant screen, the
-- shrine through its torii; HANAMI GINZA, the covered shopping street; the blocks down to the
-- canal; the rail yard to the east and the fish market to the west; the canal across the city
-- with its three bridges.
--
-- City frame (HanamiConfig): +Z north, +X west. Real studs throughout (CityBlocks scales the
-- drawn buildings).

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ServerScriptService.ArenaService.Kit)
local CityKit = require(ServerScriptService.HanamiService.CityKit)
local Blocks = require(ServerScriptService.HanamiService.CityBlocks)
local HanamiConfig = require(ReplicatedStorage.HanamiConfig)

local South = {}

type B = Kit.Builder
local M = Enum.Material
local P = CityKit.P
local darker, lighter = CityKit.Darker, CityKit.Lighter
local vertical = CityKit.Vertical
local At = CityKit.At
local text = CityKit.Text
local WALK = Blocks.WALK
local S = HanamiConfig.Sites

-- The lines everything here is laid out on.
South.VIADUCT = { z0 = -594, z1 = -558, deck = 30 }
South.STATION_FRONT = -480
South.EKIMAE = { z0 = -360, z1 = -336 }          -- the station road along the square's north side
South.CANAL_ROAD = { z0 = -236, z1 = -212 }      -- along the canal's south bank
South.SIDE = { -252, 252 }                       -- the side streets either side (24 wide)

-- ------------------------------------------------------------------ the railway --

local function trainCar(t: B, cab: number)
	local white = Color3.fromRGB(238, 240, 242)
	t:part("TrainCar", Vector3.new(60, 11, 9), Vector3.new(0, 7.5, 0), white, M.Metal)
	t:decor("TrainWindows", Vector3.new(52, 3.4, 9.1), Vector3.new(0, 9.2, 0), Color3.fromRGB(50, 66, 86), M.Glass, { reflectance = 0.15 })
	t:decor("TrainStripe", Vector3.new(60.1, 1.2, 9.12), Vector3.new(0, 5.4, 0), Color3.fromRGB(40, 160, 90))
	t:decor("TrainStripe", Vector3.new(60.1, 0.6, 9.12), Vector3.new(0, 4.4, 0), P.SAKURA_DEEP)
	for _, dx in ipairs({ -21, -7, 7, 21 }) do
		t:decor("TrainDoor", Vector3.new(3.8, 8.4, 9.14), Vector3.new(dx, 6.2, 0), Color3.fromRGB(206, 210, 214))
	end
	t:decor("TrainRoof", Vector3.new(58, 0.8, 8), Vector3.new(0, 13.4, 0), Color3.fromRGB(160, 166, 172))
	t:decor("Bogie", Vector3.new(12, 2.6, 7), Vector3.new(-20, 1.3, 0), P.KURO)
	t:decor("Bogie", Vector3.new(12, 2.6, 7), Vector3.new(20, 1.3, 0), P.KURO)
	if cab == 0 then
		t:decor("Pantograph", Vector3.new(5, 2.4, 0.4), Vector3.new(0, 15, 0), P.IRON)
	else
		local x = cab * 30
		t:decor("TrainNose", Vector3.new(2.4, 10, 8.6), Vector3.new(x + cab * 1.2, 7.4, 0), Color3.fromRGB(40, 160, 90))
		t:decor("TrainScreen", Vector3.new(0.4, 3.6, 7), Vector3.new(x + cab * 2.5, 9.4, 0), Color3.fromRGB(40, 52, 66), M.Glass)
		for _, z in ipairs({ -2.8, 2.8 }) do
			t:decor("HeadLamp", Vector3.new(0.3, 0.8, 1.4), Vector3.new(x + cab * 2.5, 4.2, z), Color3.fromRGB(252, 248, 226))
		end
	end
end

--- The railway along the south edge: a concrete viaduct on its piers the whole width of the
--- city, two tracks and the overhead line on it, the island platform over the station with its
--- canopy and a train standing in it; under it, arches -- bars in the ones by the market.
local function viaduct(root: B)
	local f = root:folder("Railway")
	local V = South.VIADUCT
	local zc = (V.z0 + V.z1) / 2
	local deck = V.deck
	local span = 1300
	f:part("Viaduct", Vector3.new(span, 3, V.z1 - V.z0), Vector3.new(0, deck - 1.5, zc), P.CONCRETE, M.Concrete)
	for _, z in ipairs({ V.z0 + 0.6, V.z1 - 0.6 }) do
		f:part("ViaductWall", Vector3.new(span, 4.4, 1.2), Vector3.new(0, deck + 2.2, z), P.CONCRETE, M.Concrete)
	end
	f:decor("ViaductBand", Vector3.new(span, 1.8, 0.8), Vector3.new(0, deck - 3.4, V.z1 + 0.4), P.CONCRETE_DARK, M.Concrete)
	f:decor("ArchBack", Vector3.new(span, deck - 3, 1), Vector3.new(0, (deck - 3) / 2, V.z0 + 3), Color3.fromRGB(150, 96, 80), M.Brick)
	for x = -640, 640, 40 do
		f:part("Pier", Vector3.new(5, deck - 3, V.z1 - V.z0 - 2), Vector3.new(x, (deck - 3) / 2, zc), P.CONCRETE, M.Concrete)
		f:decor("Soffit", Vector3.new(36, 3, V.z1 - V.z0 - 4), Vector3.new(x + 20, deck - 4.5, zc), P.CONCRETE_DARK, M.Concrete)
		if (x + 640) % 80 == 0 then
			-- The overhead line: a mast and an arm over both tracks.
			f:decor("Mast", Vector3.new(0.9, 18, 0.9), Vector3.new(x, deck + 9, V.z0 + 2), P.STEEL)
			f:decor("MastArm", Vector3.new(0.6, 0.6, V.z1 - V.z0 - 4), Vector3.new(x, deck + 17.6, zc), P.STEEL)
		end
	end
	for _, tz in ipairs({ zc - 10, zc + 10 }) do
		f:decor("Ballast", Vector3.new(span, 0.6, 9), Vector3.new(0, deck + 0.3, tz), Color3.fromRGB(150, 140, 130), M.Pebble)
		for _, o in ipairs({ -2.4, 2.4 }) do
			f:decor("Rail", Vector3.new(span, 0.5, 0.45), Vector3.new(0, deck + 0.85, tz + o), P.STEEL, M.Metal)
		end
		f:decor("Catenary", Vector3.new(span, 0.18, 0.18), Vector3.new(0, deck + 16.8, tz), P.KURO)
	end
	-- The island platform over the station, its canopy, the train in at the north track.
	f:part("Platform", Vector3.new(240, 3.6, 10), Vector3.new(0, deck + 1.8, zc), Color3.fromRGB(204, 200, 192), M.Concrete)
	for _, s in ipairs({ -1, 1 }) do
		f:decor("PlatformEdge", Vector3.new(240, 0.12, 1.2), Vector3.new(0, deck + 3.66, zc + s * 4.3), P.TACTILE)
	end
	for x = -110, 110, 20 do
		f:decor("CanopyPost", Vector3.new(0.9, 12, 0.9), Vector3.new(x, deck + 9.6, zc), P.STEEL)
	end
	local canopy = f:decor("Canopy", Vector3.new(250, 1, 30), Vector3.new(0, deck + 16, zc), Color3.fromRGB(228, 230, 232), M.Metal)
	canopy.CastShadow = true
	f:decor("CanopyEdge", Vector3.new(250, 1.6, 0.8), Vector3.new(0, deck + 15.6, V.z1 - 1), Color3.fromRGB(40, 150, 90))
	CityKit.Board(At(f, 0, V.z1 - 1.4, "+z", deck + 10), "花見  HANAMI", 0, 2.4, 14, 2.6, P.WHITE, Color3.fromRGB(40, 150, 90), 0.3)
	for k, x in ipairs({ -64, 0, 64 }) do
		trainCar(f:within(CFrame.new(x, deck + 1.4, zc + 10)), if k == 1 then -1 elseif k == 3 then 1 else 0)
	end
	-- Under the arches at the market end: bars, a lantern and a noren each, one arch left
	-- open as a passage (the bars along it, and what is hidden at its end).
	for x = 300, 580, 40 do
		local open = x == 500
		local a = At(f, x, V.z1, "+z")
		if not open then
			a:part("ArchShop", Vector3.new(34, deck - 6, 6), Vector3.new(0, (deck - 6) / 2, 3), Color3.fromRGB(176, 116, 92), M.Brick)
			local name = Blocks.IZAKAYA[(x // 40) % #Blocks.IZAKAYA + 1]
			CityKit.Board(a, name[1] .. "  " .. name[2], 0, 15, 20, 3.4, P.KURO, P.WHITE, 0.4)
			a:decor("DoorGlow", Vector3.new(6, 9, 0.3), Vector3.new(-8, 4.5, -0.15), Color3.fromRGB(246, 214, 160))
			for k = -1, 1 do
				local cloth = a:decor("Noren", Vector3.new(1.9, 3.4, 0.12), Vector3.new(-8 + k * 2, 7.4, -0.7), Color3.fromRGB(40, 58, 110), M.Fabric)
				cloth.CastShadow = true
			end
			a:decor("ArchWindow", Vector3.new(10, 5, 0.3), Vector3.new(7, 6, -0.15), Color3.fromRGB(246, 214, 160))
			CityKit.Chochin(a, Vector3.new(-1, 9.4, -1.2), P.LANTERN, 1.5)
			CityKit.Crates(At(f, x - 6, V.z1 + 3, "+z"), x)
		end
	end
end

-- ------------------------------------------------------------------ the station --

--- HANAMI STATION: a long hall under the viaduct, a glass atrium in its middle with the name
--- over it, stone wings with their windows either side, a canopy over the doors on slim
--- columns, the clock, the ticket gates through the glass.
local function station(root: B)
	local s = At(root, 0, South.STATION_FRONT, "+z")
	local stone = Color3.fromRGB(232, 228, 218)
	local dark = Color3.fromRGB(58, 62, 70)
	s:part("StationHall", Vector3.new(268, 26, 78), Vector3.new(0, 13, 39), stone)
	-- The atrium: higher than the wings, glass all down its front.
	s:part("Atrium", Vector3.new(104, 36, 40), Vector3.new(0, 18, 20), stone)
	s:decor("AtriumRoof", Vector3.new(112, 2, 48), Vector3.new(0, 37, 18), dark)
	s:decor("Interior", Vector3.new(96, 24, 0.2), Vector3.new(0, 12.4, -0.1), Color3.fromRGB(236, 230, 214))
	for x = -40, 40, 10 do
		s:decor("TicketGate", Vector3.new(1.4, 3.4, 4), Vector3.new(x, 1.7, 0.4), Color3.fromRGB(150, 156, 166))
		s:decor("GateLamp", Vector3.new(1.42, 0.3, 1.2), Vector3.new(x, 3.4, -1.2), Color3.fromRGB(70, 200, 150))
	end
	s:decor("Departures", Vector3.new(30, 4, 0.4), Vector3.new(0, 15, -0.4), Color3.fromRGB(28, 32, 42))
	text(s, "発車  10:42 快速 HANAMI LINER   10:48 各停 LOCAL", CFrame.new(0, 15, -0.66), 28, 2.6, Color3.fromRGB(250, 196, 70),
		Enum.Font.Code)
	s:decor("StationGlass", Vector3.new(98, 30, 0.4), Vector3.new(0, 15, -1.2), P.GLASS, M.Glass, { transparency = 0.55, reflectance = 0.15 })
	for k = 0, 12 do
		s:decor("Mullion", Vector3.new(0.6, 30, 1), Vector3.new(-48 + k * 8, 15, -1.4), dark)
	end
	for _, y in ipairs({ 10.6, 21 }) do
		s:decor("Transom", Vector3.new(98, 0.6, 1), Vector3.new(0, y, -1.4), dark)
	end
	-- The name over the glass.
	s:decor("NameBand", Vector3.new(104, 6, 1.2), Vector3.new(0, 33, -0.6), dark)
	s:decor("NameStripe", Vector3.new(104, 0.8, 1.3), Vector3.new(0, 29.6, -0.65), Color3.fromRGB(40, 160, 90))
	text(s, "花見駅", CFrame.new(-26, 33, -1.26), 34, 5, P.WHITE, Enum.Font.GothamBlack)
	text(s, "HANAMI STATION", CFrame.new(24, 33, -1.26), 42, 3.4, P.WHITE, Enum.Font.GothamBold)
	-- The canopy over the doors, on its columns.
	local canopy = s:decor("StationCanopy", Vector3.new(96, 1, 14), Vector3.new(0, 12.4, -7.6), dark)
	canopy.CastShadow = true
	s:decor("CanopyTrim", Vector3.new(96, 0.6, 0.6), Vector3.new(0, 12.9, -14.6), Color3.fromRGB(40, 160, 90))
	for x = -44, 44, 22 do
		s:part("CanopyColumn", Vector3.new(12, 1, 1), vertical(Vector3.new(x, 6, -13.6)), Color3.fromRGB(196, 200, 206), M.Metal,
			{ shape = "Cylinder" })
	end
	-- The wings: stone, two bands of windows, louvres, the station's other doors.
	for _, side in ipairs({ -1, 1 }) do
		local x0 = side * 52
		local w = 82
		local cx = x0 + side * w / 2
		for _, y in ipairs({ 8, 18 }) do
			s:decor("Windows", Vector3.new(w - 6, 4.6, 0.3), Vector3.new(cx, y, -0.15), P.GLASS_DARK, M.Glass, { reflectance = 0.15 })
			s:decor("Louvre", Vector3.new(w - 4, 0.6, 1.4), Vector3.new(cx, y + 3, -0.7), dark)
		end
		for k = -3, 3 do
			s:decor("Pilaster", Vector3.new(1.4, 26, 0.8), Vector3.new(cx + k * 12, 13, -0.4), lighter(stone, 0.3))
		end
		s:decor("WingCornice", Vector3.new(w + 2, 1.6, 2), Vector3.new(cx, 25.4, -1), dark)
	end
	-- The clock on the atrium's corner pier.
	for _, side in ipairs({ -1, 1 }) do
		s:decor("ClockPier", Vector3.new(6, 36, 3), Vector3.new(side * 55, 18, -1.5), stone)
	end
	local clock = s:within(CFrame.new(-55, 28, -3.2))
	clock:decor("Clock", Vector3.new(0.6, 6, 6), CFrame.Angles(0, math.rad(90), 0), P.WHITE, nil, { shape = "Cylinder" })
	clock:decor("ClockRim", Vector3.new(0.5, 6.6, 6.6), CFrame.new(0, 0, 0.2) * CFrame.Angles(0, math.rad(90), 0), P.KURO, nil,
		{ shape = "Cylinder" })
	clock:decor("ClockHand", Vector3.new(0.3, 2.4, 0.12), CFrame.new(0, 0.9, -0.38), P.KURO)
	clock:decor("ClockHand", Vector3.new(1.9, 0.3, 0.12), CFrame.new(0.7, 0, -0.38), P.KURO)
	-- Ticket machines and lockers along the wings, bike parks under their roofs.
	for k = 0, 3 do
		s:part("TicketMachine", Vector3.new(3.4, 7, 2.2), Vector3.new(60 + k * 4, 3.5 + WALK, -1.4), Color3.fromRGB(222, 226, 232))
		s:decor("TicketScreen", Vector3.new(2.4, 2, 0.12), Vector3.new(60 + k * 4, 4.8 + WALK, -2.56), Color3.fromRGB(70, 140, 210))
	end
	s:part("Lockers", Vector3.new(12, 8.4, 2.6), Vector3.new(-66, 4.2 + WALK, -1.6), Color3.fromRGB(110, 150, 196))
	for k = -5, 5 do
		s:decor("LockerSeam", Vector3.new(0.12, 8.4, 0.12), Vector3.new(-66 + k * 1.1, 4.2 + WALK, -2.94), darker(Color3.fromRGB(110, 150, 196), 0.3))
	end
	for _, x in ipairs({ -104, 104 }) do
		local bp = s:within(CFrame.new(x, WALK, -8))
		bp:decor("BikeRoof", Vector3.new(34, 0.5, 10), Vector3.new(0, 9.6, 0), Color3.fromRGB(196, 200, 204), M.Metal)
		for _, px in ipairs({ -16, 16 }) do
			bp:part("BikeRoofPost", Vector3.new(0.5, 9.6, 0.5), Vector3.new(px, 4.8, 4.4), P.STEEL)
		end
		CityKit.BikeRow(bp:within(CFrame.new(-8, 0, 0)), 9, x)
		CityKit.BikeRow(bp:within(CFrame.new(8, 0, 0)), 8, x + 1)
	end
end

-- ------------------------------------------------------------------ the square --

--- The Great Sakura: a trunk you could not reach round, limbs out like an umbrella, a canopy
--- wider than the road, the sacred rope round it, in a raised stone ring you can sit on.
local function greatSakura(t: B)
	t:part("TreeRing", Vector3.new(2, 32, 32), vertical(Vector3.new(0, 1, 0)), P.STONE, M.Granite, { shape = "Cylinder" })
	t:decor("TreeRingCap", Vector3.new(0.4, 33, 33), vertical(Vector3.new(0, 2.1, 0)), lighter(P.STONE, 0.2), M.Granite, { shape = "Cylinder" })
	t:decor("TreeSoil", Vector3.new(0.2, 28, 28), vertical(Vector3.new(0, 2.2, 0)), Color3.fromRGB(104, 80, 58), M.Ground, { shape = "Cylinder" })
	t:part("GreatTrunk", Vector3.new(22, 6.4, 6.4), vertical(Vector3.new(0, 13, 0)), P.BARK, M.Wood, { shape = "Cylinder" })
	t:decor("TrunkFlare", Vector3.new(4, 9, 9), vertical(Vector3.new(0, 4, 0)), P.BARK, M.Wood, { shape = "Cylinder" })
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + 0.4
		local cf, len = Kit.Span(Vector3.new(0, 19, 0), Vector3.new(math.cos(a) * 11, 27 + (k % 2) * 3, math.sin(a) * 11))
		t:decor("GreatLimb", Vector3.new(2.4, 2.4, len + 1), cf, P.BARK, M.Wood)
	end
	t:decor("Shimenawa", Vector3.new(1.4, 8, 8), vertical(Vector3.new(0, 9, 0)), Color3.fromRGB(216, 190, 130), nil, { shape = "Cylinder" })
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		t:decor("Shide", Vector3.new(0.8, 2.2, 0.1), CFrame.new(math.cos(a) * 4.1, 7.4, math.sin(a) * 4.1) * CFrame.Angles(0, -a, 0), P.PAPER)
	end
	-- The canopy in three layers: a deep-pink ring underneath, the body, a pale crown; sprays
	-- reaching out at the rim.
	local rng = Random.new(77)
	for _, layer in ipairs({ { 10, 15, 27, 22, P.SAKURA_DEEP }, { 8, 9, 32, 23, P.SAKURA }, { 4, 4, 37, 20, P.SAKURA_LIGHT },
		{ 14, 23, 28, 12, P.SAKURA } } :: { { any } }) do
		local n: number = layer[1]
		for k = 0, n - 1 do
			local a = (k + 0.5 * (layer[2] % 2)) / n * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
			local r: number = layer[2]
			local size = layer[4] * rng:NextNumber(0.85, 1.15)
			t:decor("Blossom", Vector3.new(size, size * 0.62, size), Vector3.new(math.cos(a) * r, layer[3] + rng:NextNumber(-1.5, 1.5),
				math.sin(a) * r), layer[5], nil, { shape = "Ball", shadow = true })
		end
	end
	t:decor("Petals", Vector3.new(0.06, 64, 64), vertical(Vector3.new(0, WALK + 0.06, 0)), P.SAKURA_LIGHT, nil,
		{ shape = "Cylinder", transparency = 0.45 })
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2 + math.pi / 8
		local at = Vector3.new(math.cos(a) * 21, WALK, math.sin(a) * 21)
		CityKit.Bench(CityKit.Scaled(t:within(CFrame.lookAt(at, at * 2)), 1.3), Color3.fromRGB(196, 150, 104))
	end
end

--- The station square: granite paving from the station doors to the station road, the Great
--- Sakura, the dog statue everybody meets at, the taxi rank and the bus bay either side, the
--- koban on the corner, planters and lamps.
local function square(root: B)
	local f = root:folder("Square")
	local z0, z1 = South.STATION_FRONT, South.EKIMAE.z0
	Blocks.Walk(f, -104, 104, z0, z1, { "-x", "+x", "+z" }, Color3.fromRGB(192, 186, 178))
	for x = -96, 96, 12 do
		f:decor("PavingLine", Vector3.new(0.3, 0.05, z1 - z0), Vector3.new(x, WALK + 0.03, (z0 + z1) / 2), Color3.fromRGB(178, 170, 160))
	end
	for z = z0 + 12, z1 - 6, 12 do
		f:decor("PavingLine", Vector3.new(208, 0.05, 0.3), Vector3.new(0, WALK + 0.03, z), Color3.fromRGB(178, 170, 160))
	end
	greatSakura(f:within(CFrame.new(S.GreatSakura.X, WALK, S.GreatSakura.Z)))
	-- The dog statue.
	local dog = CityKit.Scaled(f:within(CFrame.new(-48, WALK, -462) * CFrame.Angles(0, math.rad(-130), 0)), 1.5)
	dog:part("StatuePlinth", Vector3.new(5, 3.4, 4), Vector3.new(0, 1.7, 0), P.STONE, M.Granite)
	local bronze = Color3.fromRGB(110, 92, 70)
	dog:decor("DogBody", Vector3.new(1.6, 1.6, 3.2), Vector3.new(0, 4.6, 0.2), bronze, M.Metal)
	dog:decor("DogChest", Vector3.new(1.6, 2.4, 1.4), Vector3.new(0, 5, -1.2), bronze, M.Metal)
	dog:decor("DogHead", Vector3.new(1.4, 1.4, 1.6), Vector3.new(0, 6.6, -1.6), bronze, M.Metal)
	dog:decor("DogSnout", Vector3.new(0.8, 0.7, 0.9), Vector3.new(0, 6.3, -2.6), bronze, M.Metal)
	for _, x in ipairs({ -0.5, 0.5 }) do
		dog:decor("DogEar", Vector3.new(0.4, 0.7, 0.3), Vector3.new(x, 7.5, -1.4), bronze, M.Metal)
		dog:decor("DogLeg", Vector3.new(0.5, 1.6, 0.5), Vector3.new(x, 4.2, -1.4), bronze, M.Metal)
	end
	dog:decor("DogTail", Vector3.new(0.4, 0.4, 1.4), CFrame.new(0, 5.6, 1.9) * CFrame.Angles(math.rad(-40), 0, 0), bronze, M.Metal)
	CityKit.Board(dog:within(CFrame.new(0, 0, -2)), "ハチ公", 0, 2.2, 2.8, 1, Color3.fromRGB(90, 76, 60), P.CREAM, 0.1)
	-- The taxi rank (west) and the bus bay (east): road level, an island down the middle of each.
	for _, side in ipairs({ 1, -1 }) do
		f:part("Island", Vector3.new(8, WALK + 0.4, 84), Vector3.new(side * 112, (WALK + 0.4) / 2, -430), P.KERB, M.Granite)
		if side > 0 then
			CityKit.Shelter(CityKit.Scaled(At(f, side * 112, -404, "-x", WALK + 0.4), 1.4), 12, "TAXI のりば")
			for k, z in ipairs({ -462, -444, -426 }) do
				CityKit.BigCar(f:within(CFrame.new(132, 0, z)), "taxi", if k == 2 then Color3.fromRGB(240, 196, 40) else Color3.fromRGB(30, 32, 38))
			end
		else
			CityKit.Shelter(CityKit.Scaled(At(f, side * 112, -404, "+x", WALK + 0.4), 1.4), 12, "BUS のりば")
			CityKit.Bus(f:within(CFrame.new(-132, 0, -440)), Color3.fromRGB(40, 120, 200), "急行 KUROGANE CASTLE")
		end
		for z = -470, -372, 14 do
			f:decor("BayLine", Vector3.new(0.5, 0.06, 7), Vector3.new(side * 120, 0.03, z), P.LINE)
		end
	end
	-- The koban on the corner: the police box, its red lamp over the door.
	local koban = Blocks.Site(f, 72, -372, "+z")
	koban:part("Koban", Vector3.new(12, 10, 10), Vector3.new(0, 5, 5), Color3.fromRGB(196, 180, 160))
	koban:decor("KobanDoor", Vector3.new(4.6, 7, 0.3), Vector3.new(0, 3.5, -0.15), P.GLASS, M.Glass, { transparency = 0.3 })
	koban:decor("KobanRoof", Vector3.new(13.4, 1.2, 11.4), Vector3.new(0, 10.6, 5), Color3.fromRGB(80, 82, 90))
	koban:decor("KobanLamp", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 9, -0.7), Color3.fromRGB(230, 50, 46), nil, { shape = "Ball" })
	CityKit.Board(koban, "交番 KOBAN", 0, 7.8, 7, 1.3, P.WHITE, P.KURO, 0.2)
	-- Planters and trees along the station road, lamps at the corners.
	for _, x in ipairs({ -84, -56, 56, 84 }) do
		CityKit.Planter(CityKit.Scaled(f:within(CFrame.new(x, WALK, -368)), 1.5), 10, x, true)
	end
	for _, at in ipairs({ { -96, -470 }, { 96, -470 }, { -96, -372 }, { 96, -372 } }) do
		CityKit.TreeBed(f:within(CFrame.new(at[1], WALK, at[2])), at[1] + at[2], at[2] > -400, 2.2)
	end
	for _, at in ipairs({ { -30, -470 }, { 30, -470 }, { -64, -420 }, { 64, -420 }, { -30, -366 }, { 30, -366 } }) do
		CityKit.StreetLamp(CityKit.Scaled(At(f, at[1], at[2], "+z", WALK), 1.5), at[2] == -420)
	end
	CityKit.Vending(Blocks.Site(f, -84, -476, "+z"), Color3.fromRGB(220, 52, 52), 1)
	CityKit.Vending(Blocks.Site(f, -79, -476, "+z"), Color3.fromRGB(40, 96, 204), 2)
	CityKit.PostBox(CityKit.Scaled(At(f, 80, -474, "+z", WALK), 1.2))
end

--- The department store over the square: six floors over display windows, a giant screen down
--- its front, banners, its name on the roof.
local function department(root: B)
	local x = 156
	local front = At(root, x, -420, "-x", WALK)
	local top = Blocks.Building(root, x, -420, "-x", {
		w = 112, d = 76, floors = 6, style = "office", colour = Color3.fromRGB(240, 234, 222), trim = Color3.fromRGB(196, 170, 120),
		shop = { jp = "花見百貨店", en = "HANAMI DEPT. STORE", colour = Color3.fromRGB(150, 30, 46), kind = "glass", awning = true },
		left = true, right = true, back = true, seed = 101,
	})
	CityKit.Screen(front, 0, 40, 58, 32, 1, 1.4)
	for k, z in ipairs({ -48, -40, 40, 48 }) do
		local c = if k % 2 == 0 then P.SAKURA_DEEP else Color3.fromRGB(150, 30, 46)
		front:decor("Banner", Vector3.new(5, 30, 0.4), Vector3.new(z, 40, -1.6), c, M.Fabric)
		text(front, CityKit.Stacked(if k % 2 == 0 then "春の祭" else "桜まつり"), CFrame.new(z, 40, -1.84), 4.2, 27, P.WHITE,
			Enum.Font.GothamBlack)
	end
	-- Its name on the roof, in a frame.
	local roof = At(root, x, -420, "-x", WALK + top)
	for _, xx in ipairs({ -26, 26 }) do
		roof:decor("BillboardLeg", Vector3.new(0.8, 16, 0.8), Vector3.new(xx, 8, 6), P.IRON)
	end
	roof:decor("NameBoard", Vector3.new(60, 11, 1), Vector3.new(0, 11, 6), Color3.fromRGB(150, 30, 46))
	text(roof, "花見百貨店  HANAMI", CFrame.new(0, 11, 5.44), 56, 8, P.WHITE, Enum.Font.GothamBlack)
end

--- The shrine off the square: a red torii in its wall, a stone path between pines and cherry
--- trees to the hall on its stone floor, its bell (pull it to rest and heal).
local function shrine(root: B)
	local f = root:folder("Shrine")
	local x0, x1, z0, z1 = -232, -156, -476, -364
	CityKit.Patch(f, "Gravel", x0, x1, z0, z1, 0.02, P.GRAVEL, M.Pebble)
	CityKit.Patch(f, "Approach", -200, x1, -425, -415, 0.08, P.STONE, M.Slate)
	CityKit.Life(f, "PigeonFlock", Vector3.new(-186, 0.6, -440), Vector3.new(1, 1, 1), { Radius = 20, Inner = 3, Count = 7 })
	-- The wall round the grounds, the torii in its square-side.
	local function wall(a: Vector3, c: Vector3)
		local cf, len = Kit.Span(a, c)
		f:part("ShrineWall", Vector3.new(1.8, 4.4, len), cf * CFrame.new(0, 2.2, 0), P.STONE, M.Slate)
		f:decor("ShrineWallCap", Vector3.new(2.8, 0.7, len + 0.6), cf * CFrame.new(0, 4.7, 0), P.TILE_ROOF)
	end
	wall(Vector3.new(x1, 0, z0), Vector3.new(x1, 0, -428))
	wall(Vector3.new(x1, 0, -412), Vector3.new(x1, 0, z1))
	wall(Vector3.new(x0, 0, z1), Vector3.new(x1, 0, z1))
	wall(Vector3.new(x0, 0, z0), Vector3.new(x1, 0, z0))
	CityKit.Torii(At(f, x1 + 3, -420, "-x"), 16, 17)
	CityKit.Board(At(f, x1 + 3.4, -420, "+x"), CityKit.Stacked("花見社"), 0, 18.6, 2, 3.4, P.KURO, P.GOLD, 0.3)
	-- The hall: a stone floor, steps, red pillars, white walls, a green copper roof.
	local h = CityKit.Scaled(At(f, -200, -420, "+x"), 1.3)
	h:part("ShrineFloor", Vector3.new(20, 1.15, 22), Vector3.new(0, 0.575, 11), P.STONE, M.Slate)
	for k = 0, 2 do
		h:part("ShrineStep", Vector3.new(8, 0.38 * (k + 1), 1.2), Vector3.new(0, 0.19 * (k + 1), -1.2 * (3 - k) + 0.6), P.STONE, M.Slate)
	end
	h:part("Honden", Vector3.new(16, 8, 11), Vector3.new(0, 5.15, 15.5), P.PLASTER)
	for _, x in ipairs({ -8, -3, 3, 8 }) do
		h:part("ShrinePillar", Vector3.new(8, 0.9, 0.9), vertical(Vector3.new(x, 5.15, 4.4)), P.VERMILION, nil, { shape = "Cylinder" })
	end
	h:decor("ShrineDoor", Vector3.new(6, 6, 0.2), Vector3.new(0, 4.2, 9.9), P.WOOD_DARK)
	local copper = Color3.fromRGB(80, 140, 118)
	h:part("ShrineRoof", Vector3.new(22, 4.6, 12), CFrame.new(0, 11.5, 4), copper, M.Slate, { shape = "Wedge", collide = false })
	h:part("ShrineRoof", Vector3.new(22, 4.6, 12), CFrame.new(0, 11.5, 16) * CFrame.Angles(0, math.pi, 0), copper, M.Slate,
		{ shape = "Wedge", collide = false })
	h:decor("RoofRidge", Vector3.new(23, 1, 1.2), Vector3.new(0, 14.2, 10), darker(copper, 0.2))
	h:decor("Shimenawa", Vector3.new(0.8, 12, 0.8), CFrame.new(0, 8.7, 4) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(216, 190, 130))
	h:part("OfferingBox", Vector3.new(4, 2, 2), Vector3.new(0, 2.15, 2.2), P.WOOD, M.Wood)
	local bell = h:decor("ShrineBell", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 8.1, 3), P.GOLD, M.Metal, { shape = "Ball" })
	bell:SetAttribute("PromptText", "Pray")
	bell:SetAttribute("PromptObject", "The Shrine · rest and heal")
	h:decor("BellRope", Vector3.new(0.3, 5, 0.3), Vector3.new(0, 5.3, 3), P.CRIMSON, M.Fabric)
	for _, x in ipairs({ -6, 6 }) do
		local dog = h:within(CFrame.new(x, 0, -6))
		dog:part("KomainuBase", Vector3.new(2.2, 1.2, 2.2), Vector3.new(0, 0.6, 0), P.STONE_DARK, M.Slate)
		dog:decor("KomainuBody", Vector3.new(1.6, 1.8, 1.4), Vector3.new(0, 2.1, 0.2), P.STONE, M.Slate)
		dog:decor("KomainuHead", Vector3.new(1.5, 1.3, 1.3), Vector3.new(0, 3.5, -0.3), P.STONE, M.Slate)
		CityKit.StoneLantern(h:within(CFrame.new(x * 1.35, 0, -11)), 1.1)
	end
	local ema = CityKit.Scaled(At(f, -186, -446, "+z"), 1.3)
	ema:part("EmaRack", Vector3.new(8, 4.4, 0.6), Vector3.new(0, 2.2, 0), P.WOOD, M.Wood)
	for k = -3, 3 do
		ema:decor("Ema", Vector3.new(0.9, 0.7, 0.1), Vector3.new(k * 1.05, 3 + (k % 2) * 0.8, -0.35), P.WOOD_LIGHT)
	end
	local basin = CityKit.Scaled(At(f, -184, -394, "-z"), 1.3)
	basin:part("Chozuya", Vector3.new(4, 2.2, 2.4), Vector3.new(0, 1.1, 0), P.STONE, M.Slate)
	basin:decor("ChozuyaWater", Vector3.new(3.4, 0.1, 1.8), Vector3.new(0, 2.16, 0), P.WATER)
	for _, x in ipairs({ -2.4, 2.4 }) do
		basin:decor("ChozuyaPost", Vector3.new(0.4, 6, 0.4), Vector3.new(x, 3, 0), P.WOOD_DARK)
	end
	basin:decor("ChozuyaRoof", Vector3.new(6, 0.4, 4), Vector3.new(0, 6.2, 0), copper)
	for i, at in ipairs({ { -230, -468 }, { -206, -470 }, { -176, -468 }, { -230, -372 }, { -206, -370 }, { -176, -372 },
		{ -232, -440 }, { -232, -398 }, { -166, -450 }, { -166, -390 } }) do
		if i % 2 == 0 then
			CityKit.Sakura(f:within(CFrame.new(at[1], 0, at[2])), i * 11, 2)
		else
			CityKit.Pine(f:within(CFrame.new(at[1], 0, at[2])), i * 7, 1.9)
		end
	end
end

-- ------------------------------------------------------------------ the streets north of the square --

--- HANAMI GINZA: the covered shopping street from the station road to the canal road. A glass
--- roof on arched ribs over the second floor, lanterns and banners all the way along, shops
--- both sides; the trader's counter out in front of the hardware shop that is not one.
local function arcade(root: B)
	local f = root:folder("Arcade")
	local cx = S.Arcade.X
	local z0, z1 = South.EKIMAE.z1, South.CANAL_ROAD.z0
	Blocks.Walk(f, cx - 12, cx + 12, z0, z1, { "-z", "+z" }, Color3.fromRGB(214, 200, 180))
	for z = z0 + 5, z1 - 5, 10 do
		f:decor("FloorBand", Vector3.new(24, 0.05, 1.4), Vector3.new(cx, WALK + 0.03, z), Color3.fromRGB(184, 120, 110))
	end
	-- The roof: a gable of glass on arched ribs, at the second floor.
	local ribC = Color3.fromRGB(110, 120, 130)
	local eave, ridge = 24, 30
	for z = z0, z1, 10 do
		for _, side in ipairs({ -1, 1 }) do
			local cf, len = Kit.Span(Vector3.new(cx + side * 12, eave, z), Vector3.new(cx + side * 4, ridge, z))
			f:decor("Rib", Vector3.new(0.7, 0.7, len), cf, ribC)
		end
		f:decor("Rib", Vector3.new(8, 0.7, 0.7), Vector3.new(cx, ridge, z), ribC)
	end
	for _, side in ipairs({ -1, 1 }) do
		local cf, len = Kit.Span(Vector3.new(side * 12, eave + 0.3, 0), Vector3.new(side * 4, ridge + 0.3, 0))
		local pane = f:decor("ArcadeGlass", Vector3.new(z1 - z0, 0.4, len), CFrame.new(cx, 0, (z0 + z1) / 2) * cf,
			Color3.fromRGB(200, 226, 236), M.Glass, { transparency = 0.55 })
		pane.CastShadow = false
	end
	f:decor("ArcadeGlass", Vector3.new(8, 0.4, z1 - z0), Vector3.new(cx, ridge + 0.3, (z0 + z1) / 2), Color3.fromRGB(200, 226, 236), M.Glass,
		{ transparency = 0.55 })
	-- The gates at each end with the street's name.
	for _, gz in ipairs({ z0, z1 }) do
		local g = At(f, cx, gz, if gz == z0 then "-z" else "+z")
		g:decor("GateBeam", Vector3.new(26, 6, 1.6), Vector3.new(0, eave + 4, -0.8), Color3.fromRGB(150, 30, 46))
		text(g, "花見銀座", CFrame.new(-4.6, eave + 4.2, -1.66), 13, 4.6, P.WHITE, Enum.Font.GothamBlack)
		text(g, "HANAMI GINZA", CFrame.new(7.6, eave + 3.8, -1.66), 9, 1.8, P.GOLD, Enum.Font.GothamBold)
		for _, x in ipairs({ -12.4, 12.4 }) do
			g:part("GatePost", Vector3.new(1.4, eave + 7, 1.4), Vector3.new(x, (eave + 7) / 2, -0.8), Color3.fromRGB(150, 30, 46))
		end
	end
	for z = z0 + 8, z1 - 6, 12 do
		CityKit.Chochin(f, Vector3.new(cx - 6, 21, z), P.LANTERN, 1.3)
		CityKit.Chochin(f, Vector3.new(cx + 6, 21, z), P.PAPER, 1.3)
		local c = CityKit.SIGNS[(z // 12) % 7 + 1]
		f:decor("Banner", Vector3.new(7, 4.4, 0.2), Vector3.new(cx, 22.6, z + 6), c, M.Fabric)
		text(f, "SALE  春", CFrame.new(cx, 22.6, z + 5.86), 6, 2.6, CityKit.Ink(c), Enum.Font.GothamBlack)
	end
	-- The trader's counter, out under the arcade in front of his shop.
	local stall = Blocks.Site(f, S.Merchant.X, S.Merchant.Z, "-x")
	stall:part("StallCounter", Vector3.new(7, 3.2, 2), Vector3.new(0, 1.6, 0), P.WOOD, M.WoodPlanks)
	stall:decor("StallTop", Vector3.new(7.4, 0.3, 2.4), Vector3.new(0, 3.35, 0), P.WOOD_DARK)
	for k = 0, 2 do
		stall:decor("Goods", Vector3.new(1.4, 1, 1.4), Vector3.new(-2.4 + k * 2.4, 4, 0.2), CityKit.SIGNS[k + 1])
	end
	stall:decor("StallSign", Vector3.new(5, 1.4, 0.2), Vector3.new(0, 6.4, 0.8), Color3.fromRGB(40, 58, 110))
	text(stall, "銃 GUNS & GEAR", CFrame.new(0, 6.4, 0.66), 4.6, 1, P.WHITE, Enum.Font.GothamBlack)
	stall:decor("StallPost", Vector3.new(0.3, 6.6, 0.3), Vector3.new(-2.4, 3.3, 0.8), P.WOOD_DARK)
	stall:decor("StallPost", Vector3.new(0.3, 6.6, 0.3), Vector3.new(2.4, 3.3, 0.8), P.WOOD_DARK)
	local counter = At(f, S.Merchant.X, S.Merchant.Z, "-x", WALK):decor("HanamiCounter", Vector3.new(7.6, 0.1, 3.8),
		Vector3.new(0, 0.05, -3.4), Color3.fromRGB(40, 58, 110), M.Fabric)
	counter:SetAttribute("PromptText", "Open Shop")
	counter:SetAttribute("PromptObject", "Trader · guns & gear")
	counter:SetAttribute("OpenPanel", "Market")
	for _, z in ipairs({ -316, -258 }) do
		CityKit.Planter(CityKit.Scaled(f:within(CFrame.new(cx, WALK, z) * CFrame.Angles(0, math.pi / 2, 0)), 1.3), 7, z, true)
	end
	CityKit.Vending(Blocks.Site(f, cx - 10.2, -280, "+x"), Color3.fromRGB(40, 96, 204), 7)
end

--- The blocks between the station road and the canal road, either side of Station Boulevard.
local function stationBlocks(root: B)
	local E, C = South.EKIMAE, South.CANAL_ROAD
	local cx = S.Arcade.X
	local z0, z1 = E.z1, C.z0
	local shopsOnly = Blocks.CityPick(3, 6, 0.45)
	-- West of the boulevard, to the arcade: a ring of shops and offices, their backs together.
	Blocks.Block(root, 22, cx - 12, z0, z1, { seed = 300, pick = shopsOnly, walks = { ["-x"] = 14, ["+x"] = 4 }, walk = 10, depth = 26,
		size = 22 })
	-- West of the arcade: its shops; on the canal road the cafe, the ramen shop (a ladder up its
	-- side to the roof, where a seal is), the coin car park, the pachinko hall.
	local W2x0, W2x1 = cx + 12, South.SIDE[2] - 12
	Blocks.Walk(root, W2x0, W2x1, z0, z1)
	local arcadePick = function(k: number, n: number, w: number, rng: Random): any
		local spec = Blocks.CityPick(2, 4, 0.3, { "tile", "zakkyo", "mansion" })(k, n, w, rng)
		if k == 3 then
			-- The trader's: an arms dealer that looks like a hardware shop.
			spec.shop = { jp = "金物", en = "TRADER", colour = Color3.fromRGB(40, 58, 110), kind = "glass", awning = false }
			spec.style = "tile"
			spec.vsign = nil
		end
		return spec
	end
	Blocks.Row(root, z0 + 10, z1 - 36, W2x0 + 4, "-x", 26, 310, arcadePick, 18)
	Blocks.Row(root, W2x0 + 30, W2x1 - 10, z0 + 10, "-z", 26, 311, Blocks.CityPick(4, 7, 0.4), 24)
	Blocks.Row(root, z0 + 36, z1 - 36, W2x1 - 10, "+x", 26, 312, Blocks.CityPick(3, 5, 0.3), 24)
	local line = z1 - 10
	local canal: { { any } } = {
		{ W2x0 + 4, W2x0 + 30, { style = "tile", floors = 3, colour = CityKit.FACADES[3],
			shop = { jp = "喫茶", en = "CAFE", colour = Color3.fromRGB(120, 76, 50), kind = "glass", awning = true } } },
		{ W2x0 + 30, W2x0 + 52, { style = "zakkyo", floors = 2, colour = Color3.fromRGB(240, 226, 176), roof = "terrace", open = -1,
			shop = { jp = "ラーメン", en = "RAMEN", colour = Color3.fromRGB(214, 52, 44), kind = "noren" }, vsign = "ラーメン",
			vcolour = Color3.fromRGB(214, 52, 44), tenants = { "2F 麺屋" } } },
		{ W2x0 + 74, W2x1 - 10, { style = "office", floors = 4, colour = Color3.fromRGB(250, 246, 240), shop = { jp = "パチンコ",
			en = "PACHINKO", colour = Color3.fromRGB(230, 40, 120), kind = "glass" }, billboard = "パチンコ 777", bcolour = Color3.fromRGB(250, 204, 44),
			vsign = "パチンコ", vcolour = Color3.fromRGB(230, 40, 120) } },
	}
	for i, c in ipairs(canal) do
		local spec = c[3] :: any
		local mid = (c[1] + c[2]) / 2
		spec.w, spec.d, spec.seed = c[2] - c[1], 26, 320 + i
		spec.left, spec.right, spec.back = true, true, true
		local top = Blocks.Building(root, mid, line, "+z", spec)
		if spec.roof == "terrace" then
			-- The ladder up its side (the car park side), onto the roof.
			local b = At(root, mid, line, "+z", WALK)
			CityKit.Ladder(b, Vector3.new(-((c[2] - c[1]) / 2 + 1.2), 0, 14), top + 1)
		end
	end
	-- The coin car park between them.
	local px0, px1 = W2x0 + 52, W2x0 + 74
	CityKit.Patch(root, "CarPark", px0, px1, line - 26, line, WALK, P.ROAD_DARK, M.Asphalt)
	for x = px0 + 7, px1 - 4, 7 do
		root:decor("BayLine", Vector3.new(0.4, 0.06, 14), Vector3.new(x, WALK + 0.13, line - 16), P.LINE)
	end
	CityKit.BigCar(root:within(CFrame.new(px0 + 10.5, WALK + 0.1, line - 15)), "kei", Color3.fromRGB(240, 240, 236))
	CityKit.BigCar(root:within(CFrame.new(px0 + 17.5, WALK + 0.1, line - 15)), "kei", Color3.fromRGB(150, 196, 220))
	local sign = At(root, px1 - 2, line - 2, "+z", WALK)
	sign:part("ParkSign", Vector3.new(0.5, 11, 0.5), Vector3.new(0, 5.5, 0), P.STEEL)
	CityKit.Board(sign, "P  ¥300/h", 0, 10, 5, 2.8, Color3.fromRGB(250, 204, 44), P.KURO, 0.4)
	local cx0, cx1 = W2x0 + 30, W2x1 - 36
	root:part("BlockCore", Vector3.new(cx1 - cx0, 12, z1 - z0 - 72), Vector3.new((cx0 + cx1) / 2, WALK + 6, (z0 + z1) / 2),
		P.CONCRETE_DARK, M.Concrete)

	-- East of the boulevard: shops on the boulevard and the roads; the bathhouse and its
	-- chimney; a narrow street with its poles and wires through to the canal road.
	Blocks.Block(root, -100, -22, z0, z1, { seed = 330, pick = Blocks.CityPick(3, 6, 0.45), walks = { ["+x"] = 14 }, walk = 10,
		depth = 26, size = 22 })
	Blocks.Block(root, South.SIDE[1] + 12, -120, z0, z1, { seed = 340, walk = 10, depth = 28, size = 22,
		pick = function(k: number, n: number, w: number, rng: Random): any
			if k == 1 and rng:NextNumber() < 0.8 then
				return { style = "tile", floors = 1, colour = Color3.fromRGB(244, 236, 222),
					shop = { jp = "ゆ", en = "SENTO", colour = Color3.fromRGB(40, 70, 140), kind = "noren" }, back = true }
			end
			return Blocks.CityPick(2, 5, 0.3)(k, n, w, rng)
		end })
	root:part("SentoChimney", Vector3.new(6, 70, 6), Vector3.new(-186, 35, -286), Color3.fromRGB(176, 120, 96), M.Brick)
	root:decor("ChimneyBand", Vector3.new(6.4, 3, 6.4), Vector3.new(-186, 62, -286), P.WHITE)
	text(At(root, -186, -289.3, "-z"), CityKit.Stacked("ゆ"), CFrame.new(0, 52, 0), 4.6, 4.6, P.KURO, Enum.Font.GothamBlack)
	-- The narrow street: no pavement, poles and wires, a curve mirror at the end.
	Blocks.Lanes(root, false, z0, z1, -110, 9)
	Blocks.Poles(root, Vector3.new(-119, 0, z0 + 6), Vector3.new(-119, 0, z1 - 6), 4, false)
	CityKit.CurveMirror(CityKit.Scaled(At(root, -101, z1 - 3, "-z"), 1.3))
	CityKit.RoadText(root, "止まれ", Vector3.new(-110, 0, z1 - 12), math.pi, 7, 3)
end

-- ------------------------------------------------------------------ the rail yard --

local function railYard(root: B)
	local f = root:folder("RailYard")
	local x0, x1 = -600, South.SIDE[1] - 12
	local brick = Color3.fromRGB(150, 80, 64)
	local fz = -300           -- the yard's fence, the flats' gardens beyond it
	CityKit.Patch(f, "YardGround", x0, x1, South.VIADUCT.z1, fz, 0.01, Color3.fromRGB(150, 146, 136), M.Pebble)
	-- The sidings: five tracks along the viaduct, buffer stops at their ends, wagons of
	-- containers standing on them (cover in the yard).
	local cols = { Color3.fromRGB(64, 120, 200), Color3.fromRGB(220, 120, 60), Color3.fromRGB(60, 150, 100), Color3.fromRGB(196, 60, 60) }
	for i, z in ipairs({ -544, -528, -512, -496, -480 }) do
		for _, o in ipairs({ -2.4, 2.4 }) do
			f:decor("Rail", Vector3.new(x1 - x0 - 30, 0.5, 0.45), Vector3.new((x0 + x1 - 30) / 2, 0.25, z + o), P.STEEL, M.Metal)
		end
		f:decor("Sleepers", Vector3.new(x1 - x0 - 30, 0.2, 7), Vector3.new((x0 + x1 - 30) / 2, 0.08, z), Color3.fromRGB(110, 92, 74), M.WoodPlanks)
		local stop = At(f, x1 - 30, z, "-x")
		stop:part("BufferStop", Vector3.new(7, 3.6, 2), Vector3.new(0, 1.8, 1), Color3.fromRGB(200, 60, 50))
		stop:decor("BufferStripe", Vector3.new(7.02, 0.8, 2.02), Vector3.new(0, 3, 1), P.LINE_YELLOW)
		if i ~= 3 then
			for k = 0, (if i % 2 == 0 then 1 else 2) do
				local x = -580 + k * 70 + i * 9
				local w = f:within(CFrame.new(x, 0, z))
				w:part("Wagon", Vector3.new(40, 2.4, 8), Vector3.new(0, 3.4, 0), Color3.fromRGB(70, 76, 86))
				w:decor("WagonWheels", Vector3.new(34, 2, 6.4), Vector3.new(0, 1.2, 0), P.KURO)
				for j = 0, 1 do
					local c = cols[(i + k + j) % 4 + 1]
					w:part("Container", Vector3.new(19, 9, 7.8), Vector3.new(-9.8 + j * 19.6, 9.1, 0), c, M.CorrodedMetal)
					w:decor("ContainerDoor", Vector3.new(0.1, 8.4, 7.2), Vector3.new(-9.8 + j * 19.6 + 9.56, 9.1, 0), darker(c, 0.2))
					text(At(w, -9.8 + j * 19.6, -3.96, "-z"), "JR貨物", CFrame.new(0, 10.6, 0), 9, 2, P.WHITE, Enum.Font.GothamBlack)
				end
			end
		end
	end
	-- The old brick engine shed the gang has taken over: open at both ends.
	local shed = f:within(CFrame.new(S.Camp.X, 0, S.Camp.Z))
	for _, z in ipairs({ -34, 34 }) do
		shed:part("ShedWall", Vector3.new(110, 24, 2.4), Vector3.new(0, 12, z), brick, M.Brick)
		for x = -48, 48, 12 do
			shed:decor("ShedWindow", Vector3.new(6, 9, 2.6), Vector3.new(x, 14, z), Color3.fromRGB(70, 80, 90), M.Glass)
			shed:decor("ShedArch", Vector3.new(7.2, 1, 2.8), Vector3.new(x, 19, z), darker(brick, 0.2))
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		shed:part("ShedRoof", Vector3.new(112, 10, 36), CFrame.new(0, 29, side * 18) * CFrame.Angles(0, if side < 0 then 0 else math.pi, 0),
			Color3.fromRGB(120, 124, 130), M.CorrodedMetal, { shape = "Wedge" })
	end
	for _, x in ipairs({ -55, 55 }) do
		shed:part("ShedGable", Vector3.new(1, 6, 68), Vector3.new(x, 27, 0), brick, M.Brick)
		shed:decor("ShedName", Vector3.new(1.2, 3, 28), Vector3.new(x, 21, 0), Color3.fromRGB(240, 230, 210))
	end
	text(At(shed, 55.7, 0, "+x"), "第二機関庫", CFrame.new(0, 21, 0), 26, 2.4, P.KURO, Enum.Font.GothamBlack)
	for _, z in ipairs({ -10, 10 }) do
		for _, o in ipairs({ -2.4, 2.4 }) do
			shed:decor("Rail", Vector3.new(130, 0.5, 0.45), Vector3.new(0, 0.25, z + o), P.STEEL, M.Metal)
		end
	end
	-- Inside: the gang's camp -- a fire in a drum, tarps, crates, a table with plans on it.
	local camp = CityKit.Scaled(f:within(CFrame.new(S.Camp)), 1.3)
	camp:part("FireDrum", Vector3.new(2.4, 1.8, 1.8), vertical(Vector3.new(6, 1.2, 2)), Color3.fromRGB(90, 70, 60), M.CorrodedMetal,
		{ shape = "Cylinder" })
	camp:decor("Fire", Vector3.new(1.6, 1.6, 1.6), Vector3.new(6, 2.8, 2), Color3.fromRGB(255, 150, 60), M.Neon, { shape = "Ball", transparency = 0.2 })
	camp:light("Point", Vector3.new(6, 4, 2), Color3.fromRGB(255, 160, 80), 2, 22)
	camp:part("CampTable", Vector3.new(6, 2.6, 3), Vector3.new(-6, 1.3, 8), P.WOOD, M.WoodPlanks)
	camp:decor("CampPlans", Vector3.new(3, 0.1, 2), Vector3.new(-6, 2.66, 8), P.PAPER)
	for k = 0, 3 do
		camp:part("Crate", Vector3.new(3, 3, 3), Vector3.new(-14 + k * 3.2, 1.5, -10), P.WOOD_LIGHT, M.WoodPlanks)
	end
	camp:decor("Tarp", Vector3.new(10, 0.2, 8), CFrame.new(-12, 6, 12) * CFrame.Angles(0, 0, math.rad(10)), Color3.fromRGB(60, 100, 160), M.Fabric)
	for i, c in ipairs(HanamiConfig.Captives) do
		local post = f:within(CFrame.new(c))
		post:part("CaptivePost", Vector3.new(0.9, 8, 0.9), Vector3.new(0, 4, 1.6), P.WOOD_DARK)
		CityKit.Marker(post, "CaptiveSpot", Vector3.new(0, 0.5, 0), { Index = i })
	end
	-- The signal box on its stilts, a stair up to its balcony from the south.
	local box = f:within(CFrame.new(S.SignalBox))
	local floorTop = HanamiConfig.Seals[4].Y
	for _, x in ipairs({ -8, 8 }) do
		for _, z in ipairs({ -8, 8 }) do
			box:part("Stilt", Vector3.new(1.2, floorTop - 1, 1.2), Vector3.new(x, (floorTop - 1) / 2, z), P.STEEL)
		end
	end
	box:part("BoxFloor", Vector3.new(18, 1, 18), Vector3.new(0, floorTop - 0.5, 0), Color3.fromRGB(120, 126, 132), M.DiamondPlate)
	box:part("BoxHut", Vector3.new(14, 9, 11), Vector3.new(0, floorTop + 4.5, 3.4), Color3.fromRGB(230, 222, 200))
	box:decor("BoxWindows", Vector3.new(14.1, 3.4, 11.1), Vector3.new(0, floorTop + 5.6, 3.4), Color3.fromRGB(80, 110, 130), M.Glass)
	box:decor("BoxRoof", Vector3.new(15.6, 1, 12.6), Vector3.new(0, floorTop + 9.5, 3.4), Color3.fromRGB(110, 60, 50))
	box:part("BoxRail", Vector3.new(8, 3.4, 0.3), Vector3.new(5, floorTop + 1.7, -8.85), P.STEEL)
	for _, x in ipairs({ -8.85, 8.85 }) do
		box:part("BoxRail", Vector3.new(0.3, 3.4, 7), Vector3.new(x, floorTop + 1.7, -5.3), P.STEEL)
	end
	local run = floorTop * 1.3
	CityKit.Stairs(f, Vector3.new(S.SignalBox.X - 4, 0, S.SignalBox.Z - 9 - run), 4.4, floorTop, run, Color3.fromRGB(120, 126, 132),
		M.DiamondPlate, 0.9)
	-- The fence between the yard and the flats, open at its gate.
	for _, seg in ipairs({ { x0, -470 }, { -440, x1 } }) do
		f:decor("Fence", Vector3.new(seg[2] - seg[1], 8, 0.2), Vector3.new((seg[1] + seg[2]) / 2, 4, fz), Color3.fromRGB(150, 160, 160),
			M.DiamondPlate, { transparency = 0.55 })
		f:part("FenceRail", Vector3.new(seg[2] - seg[1], 0.4, 0.4), Vector3.new((seg[1] + seg[2]) / 2, 8, fz), P.STEEL)
		for x = seg[1] + 4, seg[2] - 2, 12 do
			f:part("FencePost", Vector3.new(0.5, 8.4, 0.5), Vector3.new(x, 4.2, fz), P.STEEL)
		end
	end
	-- The danchi: two long slabs of flats facing the canal road over their gardens, a
	-- playground between them.
	Blocks.Walk(f, x0, x1, fz, South.CANAL_ROAD.z0, { "+z" }, Color3.fromRGB(200, 196, 186))
	for i, seg in ipairs({ { -592, -480 }, { -390, -300 } }) do
		local w = seg[2] - seg[1]
		local mid = (seg[1] + seg[2]) / 2
		Blocks.Building(root, mid, -248, "+z", { w = w, d = 30, floors = 5, style = "mansion", colour = Color3.fromRGB(226, 228, 220),
			trim = Color3.fromRGB(190, 196, 196), left = true, right = true, back = true, seed = 400 + i })
		text(At(root, mid, -248, "+z", WALK), (if i == 1 then "3" else "4") .. "号棟", CFrame.new(w / 2 - 6, 52, -0.3), 8, 5,
			Color3.fromRGB(60, 110, 180), Enum.Font.GothamBlack)
	end
	local park = CityKit.Scaled(f:within(CFrame.new(-435, WALK, -270)), 1.3)
	CityKit.Patch(park, "Playground", -30, 30, -14, 14, 0.02, Color3.fromRGB(214, 190, 150), M.Sand)
	park:part("SlideTower", Vector3.new(4, 6, 4), Vector3.new(-18, 3, 0), Color3.fromRGB(60, 140, 210))
	park:decor("Slide", Vector3.new(2.4, 0.4, 10), CFrame.new(-18, 3, 7) * CFrame.Angles(math.rad(-30), 0, 0), Color3.fromRGB(250, 196, 50))
	for _, x in ipairs({ 0, 8 }) do
		park:decor("SwingFrame", Vector3.new(0.4, 9, 0.4), Vector3.new(x - 3, 4.5, 0), Color3.fromRGB(220, 70, 60))
		park:decor("SwingFrame", Vector3.new(0.4, 9, 0.4), Vector3.new(x + 3, 4.5, 0), Color3.fromRGB(220, 70, 60))
	end
	park:decor("SwingBar", Vector3.new(14.4, 0.4, 0.4), Vector3.new(4, 9, 0), Color3.fromRGB(220, 70, 60))
	for _, x in ipairs({ 1, 7 }) do
		park:decor("SwingSeat", Vector3.new(1.8, 0.3, 1), Vector3.new(x, 2, 0), Color3.fromRGB(250, 204, 60))
		park:decor("SwingChain", Vector3.new(0.1, 7, 0.1), Vector3.new(x, 5.5, 0), P.STEEL)
	end
	park:decor("Dome", Vector3.new(8, 8, 8), Vector3.new(20, 0, 2), Color3.fromRGB(80, 180, 120), nil, { shape = "Ball", transparency = 0.45 })
	for _, x in ipairs({ -26, 26 }) do
		CityKit.StreetTree(park:within(CFrame.new(x, 0, -10)), x, 1.4)
	end
end

-- ------------------------------------------------------------------ the fish market --

local function fishMarket(root: B)
	local f = root:folder("FishMarket")
	local x0, x1 = South.SIDE[2] + 12, 600
	CityKit.Patch(f, "MarketGround", x0, x1, South.VIADUCT.z1, -300, 0.01, Color3.fromRGB(148, 152, 156), M.Concrete)
	-- The auction hall: a long roof on steel columns, open all round.
	local hx0, hx1, hz0, hz1 = 340, 520, -486, -354
	local blue = Color3.fromRGB(70, 120, 160)
	for x = hx0, hx1, 20 do
		for _, z in ipairs({ hz0, hz1 }) do
			f:part("HallColumn", Vector3.new(1.6, 24, 1.6), Vector3.new(x, 12, z), blue)
		end
	end
	local zc, half = (hz0 + hz1) / 2, (hz1 - hz0) / 2
	for _, side in ipairs({ -1, 1 }) do
		local r = f:part("HallRoof", Vector3.new(hx1 - hx0 + 8, 9, half + 4), CFrame.new((hx0 + hx1) / 2, 28.5, zc + side * (half + 4) / 2)
			* CFrame.Angles(0, if side < 0 then 0 else math.pi, 0), Color3.fromRGB(150, 176, 190), M.CorrodedMetal, { shape = "Wedge" })
		r.CastShadow = true
	end
	for _, z in ipairs({ hz0, hz1 }) do
		f:decor("HallBeam", Vector3.new(hx1 - hx0, 1.6, 1.6), Vector3.new((hx0 + hx1) / 2, 24, z), blue)
	end
	CityKit.Board(At(f, (hx0 + hx1) / 2, hz1, "+z"), "魚市場  UOICHIBA", 0, 21, 44, 4.4, Color3.fromRGB(30, 60, 120), P.WHITE, 0.6)
	-- Stalls along both long sides: counters of fish on ice, blue tubs, white boxes.
	local fish = { Color3.fromRGB(200, 210, 220), Color3.fromRGB(236, 120, 80), Color3.fromRGB(150, 160, 176), Color3.fromRGB(220, 70, 60) }
	for _, rz in ipairs({ hz0 + 8, hz1 - 8 }) do
		for x = hx0 + 14, hx1 - 14, 17 do
			local st = CityKit.Scaled(f:within(CFrame.new(x, 0, rz)), 1.35)
			st:part("StallCounter", Vector3.new(9, 3, 4), Vector3.new(0, 1.5, 0), Color3.fromRGB(230, 232, 234))
			st:decor("Ice", Vector3.new(8.4, 0.3, 3.4), Vector3.new(0, 3.1, 0), Color3.fromRGB(236, 246, 250))
			for k = 0, 3 do
				st:decor("Fish", Vector3.new(1.6, 0.5, 0.8), CFrame.new(-3 + k * 2, 3.4, (k % 2) * 0.8 - 0.4) * CFrame.Angles(0, 0.3 * k, 0),
					fish[(x // 17 + k) % 4 + 1])
			end
			st:decor("Tub", Vector3.new(2, 1.2, 2), Vector3.new(5.6, 0.6, 0), Color3.fromRGB(60, 120, 200))
			st:decor("FoamBoxes", Vector3.new(2.4, 2.4, 1.8), Vector3.new(-5.8, 1.2, 0), Color3.fromRGB(244, 246, 248))
		end
	end
	-- The auction floor in the middle: tuna laid out in rows, the bell on its post.
	for k = 0, 5 do
		for j = 0, 1 do
			local t = CityKit.Scaled(f:within(CFrame.new(380 + k * 9, 0, -440 + j * 14)), 1.3)
			t:decor("Pallet", Vector3.new(3, 0.4, 5), Vector3.new(0, 0.2, 0), P.WOOD_LIGHT)
			t:decor("Tuna", Vector3.new(2, 1.8, 4.4), Vector3.new(0, 1.3, 0), Color3.fromRGB(110, 120, 140))
			t:decor("TunaTag", Vector3.new(0.8, 0.1, 0.6), Vector3.new(0, 2.24, -1), Color3.fromRGB(230, 60, 60))
		end
	end
	local bell = f:within(CFrame.new(S.Market.X, 0, S.Market.Z + 24))
	bell:part("BellPost", Vector3.new(0.8, 9, 0.8), Vector3.new(0, 4.5, 0), P.STEEL)
	bell:decor("AuctionBell", Vector3.new(1.6, 1.6, 1.6), Vector3.new(0, 9.6, 0), P.GOLD, M.Metal, { shape = "Ball" })
	CityKit.Marker(f, "RaidSite", S.Market + Vector3.new(0, 1.4, 0))
	-- Turret trucks and stacks of foam boxes about the yard.
	for i, at in ipairs({ { 300, -440, 0.4 }, { 560, -420, -0.8 }, { 540, -520, 1.6 }, { 310, -520, 0.2 }, { 430, -330, 1.2 } }) do
		local t = CityKit.Scaled(f:within(CFrame.new(at[1], 0, at[2]) * CFrame.Angles(0, at[3], 0)), 1.35)
		t:part("TurretBed", Vector3.new(4, 1.4, 7), Vector3.new(0, 1.3, 1), Color3.fromRGB(60, 110, 190))
		t:decor("TurretDrum", Vector3.new(2.4, 2.4, 2.4), vertical(Vector3.new(0, 2.4, -3)), Color3.fromRGB(220, 220, 214), nil, { shape = "Cylinder" })
		t:decor("TurretWheel", Vector3.new(0.5, 1.2, 1.2), CFrame.new(0, 0.6, -3), P.KURO, nil, { shape = "Cylinder" })
		if i % 2 == 0 then
			t:decor("FoamBoxes", Vector3.new(3.4, 1.6, 5), Vector3.new(0, 2.8, 1.4), Color3.fromRGB(244, 246, 248))
		end
	end
	for _, at in ipairs({ { 290, -480 }, { 570, -470 }, { 575, -380 }, { 300, -380 } }) do
		f:part("BoxStack", Vector3.new(6, 7, 4.4), Vector3.new(at[1], 3.5, at[2]), Color3.fromRGB(244, 246, 248))
		f:decor("BoxLines", Vector3.new(6.04, 0.2, 4.44), Vector3.new(at[1], 3.5, at[2]), Color3.fromRGB(200, 210, 220))
	end
	-- The wholesalers along the canal road: sushi counters, ice, knives, the office.
	Blocks.Walk(f, x0, x1, -300, South.CANAL_ROAD.z0, { "+z", "-x" })
	Blocks.Row(f, x0 + 6, x1, South.CANAL_ROAD.z0 - 10, "+z", 30, 520, function(k: number, n: number, w: number, rng: Random): any
		local spec = Blocks.CityPick(1, 3, 0.25, { "tile", "tile", "zakkyo" })(k, n, w, rng)
		if k == 2 then
			spec.shop = { jp = "寿司", en = "SUSHI", colour = Color3.fromRGB(32, 60, 110), kind = "noren" }
		elseif k == 4 then
			spec.shop = { jp = "事務所", en = "MARKET OFFICE", colour = Color3.fromRGB(30, 60, 120), kind = "glass" }
		end
		return spec
	end, 26)
end

-- ------------------------------------------------------------------ the canal --

local function canal(root: B)
	local f = root:folder("Canal")
	local C = HanamiConfig.CANAL
	local H = HanamiConfig.HALF
	local span = H * 2 + 40
	f:part("CanalBed", Vector3.new(span, 2, C.z1 - C.z0), Vector3.new(0, C.floor - 1, (C.z0 + C.z1) / 2), Color3.fromRGB(70, 90, 96), M.Slate)
	local water = f:decor("Water", Vector3.new(span, C.water - C.floor, C.z1 - C.z0 - 0.4), Vector3.new(0, (C.water + C.floor) / 2,
		(C.z0 + C.z1) / 2), P.WATER, M.Glass, { transparency = 0.3, reflectance = 0.15 })
	water.Name = "CanalWater"
	for _, z in ipairs({ C.z0, C.z1 }) do
		f:part("CanalWall", Vector3.new(span, -C.floor + WALK, 1.2), Vector3.new(0, (C.floor + WALK) / 2, z + (if z == C.z0 then -0.6 else 0.6)),
			P.STONE, M.Slate)
		f:decor("CanalCoping", Vector3.new(span, 0.5, 2), Vector3.new(0, WALK + 0.25, z + (if z == C.z0 then -0.6 else 0.6)), lighter(P.STONE, 0.15), M.Granite)
	end
	-- The promenades either side: a pavement, a railing, cherry trees, festival lanterns.
	Blocks.Walk(f, -H, H, South.CANAL_ROAD.z1, C.z0 - 1.2, { "-z" }, Color3.fromRGB(198, 192, 182))
	Blocks.Walk(f, -H, H, C.z1 + 1.2, C.z1 + 12, { "+z" }, Color3.fromRGB(198, 192, 182))
	local railC = Color3.fromRGB(70, 74, 82)
	for _, z in ipairs({ C.z0 - 2, C.z1 + 2 }) do
		for _, seg in ipairs({ { -H, -342 }, { -318, -38 }, { 38, 318 }, { 342, H } }) do
			f:part("CanalRail", Vector3.new(seg[2] - seg[1], 0.4, 0.4), Vector3.new((seg[1] + seg[2]) / 2, WALK + 3.6, z), railC)
			f:part("CanalRailLow", Vector3.new(seg[2] - seg[1], 3.6, 0.2), Vector3.new((seg[1] + seg[2]) / 2, WALK + 1.8, z), railC, nil,
				{ transparency = 0.85 })
			for x = seg[1] + 4, seg[2] - 2, 12 do
				f:decor("RailPost", Vector3.new(0.4, 3.6, 0.4), Vector3.new(x, WALK + 1.8, z), railC)
			end
		end
	end
	local k = 0
	local last: Vector3? = nil
	for x = -H + 14, H - 14, 28 do
		k += 1
		local clear = math.abs(x) < 44 or math.abs(math.abs(x) - 330) < 20
		if not clear then
			CityKit.Sakura(f:within(CFrame.new(x, WALK, C.z0 - 7)), k * 13, 2.1)
			CityKit.Sakura(f:within(CFrame.new(x + 14, WALK, C.z1 + 6)), k * 17, 2.1)
		end
		local hang = Vector3.new(x, 15, C.z0 - 6)
		if last and not clear and (last :: Vector3).X > x - 29 then
			CityKit.LanternString(f, last :: Vector3, hang, 5, { P.SAKURA_LIGHT, P.WHITE, P.SAKURA })
		end
		last = if clear then nil else hang
	end
	-- The bridges: the red one carrying the boulevard, steel and stone footbridges either side.
	for _, spec in ipairs({ { 0, "red" }, { 330, "steel" }, { -330, "stone" } } :: { { any } }) do
		local x: number = spec[1]
		local kind: string = spec[2]
		local b = f:within(CFrame.new(x, 0, (C.z0 + C.z1) / 2))
		local w = if kind == "red" then 74 else 22
		local len = C.z1 - C.z0 + 4
		b:part("BridgeDeck", Vector3.new(w, 1.6, len), Vector3.new(0, -0.8, 0), if kind == "red" then P.ROAD else P.STONE,
			if kind == "red" then M.Asphalt else M.Slate)
		local rail = if kind == "red" then P.VERMILION elseif kind == "steel" then Color3.fromRGB(60, 110, 170) else P.STONE
		if kind == "red" then
			for _, s in ipairs({ -1, 1 }) do
				b:part("BridgeWalk", Vector3.new(14, WALK + 1.6, len), Vector3.new(s * 30, (WALK - 1.6) / 2, 0), Color3.fromRGB(198, 192, 182), M.Pavement)
			end
			Blocks.Lanes(b, false, -len / 2, len / 2, 0, 22)
		end
		for _, s in ipairs({ -1, 1 }) do
			b:part("BridgeRail", Vector3.new(1, 3.6, len), Vector3.new(s * (w / 2 - 0.5), WALK + 1.8, 0), rail, if kind == "stone" then M.Slate else nil)
			b:decor("BridgeBeam", Vector3.new(1.6, 4, len), Vector3.new(s * (w / 2 - 0.8), -3, 0), darker(rail, 0.2))
			if kind == "red" then
				for _, z in ipairs({ -len / 2 + 0.8, len / 2 - 0.8, 0 }) do
					b:decor("Giboshi", Vector3.new(1.6, 1.6, 1.6), Vector3.new(s * (w / 2 - 0.5), WALK + 4.4, z), P.GOLD, M.Metal, { shape = "Ball" })
				end
				for _, z in ipairs({ -len / 4, len / 4 }) do
					b:decor("BridgeLamp", Vector3.new(0.6, 10, 0.6), Vector3.new(s * (w / 2 - 0.5), WALK + 8.6, z), P.KURO)
					CityKit.Chochin(b, Vector3.new(s * (w / 2 - 0.5), WALK + 12.6, z), P.PAPER, 1.8)
				end
			end
		end
		b:decor("BridgeArch", Vector3.new(w - 3, 2.4, len - 2), Vector3.new(0, -2.6, 0), darker(rail, 0.1))
		if kind == "red" then
			CityKit.Board(At(b, 0, len / 2, "+z"), "花見橋  HANAMI BRIDGE", 0, -4.6, 22, 2.4, P.VERMILION, P.WHITE, 0.3)
		end
	end
	-- Boats moored along the canal.
	for i, at in ipairs({ { -150, -186 }, { 180, -174 }, { -470, -184 }, { 470, -176 } }) do
		local boat = CityKit.Scaled(f:within(CFrame.new(at[1], C.water, at[2]) * CFrame.Angles(0, if i % 2 == 0 then math.pi else 0, 0)), 1.6)
		boat:decor("Hull", Vector3.new(16, 1.6, 4.6), Vector3.new(0, 0.2, 0), Color3.fromRGB(240, 236, 226))
		boat:decor("HullStripe", Vector3.new(16.04, 0.4, 4.64), Vector3.new(0, 0.6, 0), Color3.fromRGB(40, 90, 160))
		boat:decor("Cabin", Vector3.new(7, 2.4, 3.6), Vector3.new(-2, 2.2, 0), Color3.fromRGB(226, 232, 236))
		boat:decor("CabinRoof", Vector3.new(7.6, 0.3, 4.2), Vector3.new(-2, 3.55, 0), Color3.fromRGB(200, 70, 60))
		for j = -2, 2 do
			CityKit.Chochin(boat, Vector3.new(-2 + j * 1.5, 4.4, 2.2), if j % 2 == 0 then P.LANTERN else P.PAPER, 0.6)
		end
	end
end

-- ------------------------------------------------------------------ the roads --

--- The south's roads: the station road, the canal road, the boulevard to the bridge, the side
--- streets by the market and the yard; their paint, crossings, lamps and trees.
local function roads(root: B)
	local f = root:folder("SouthRoads")
	local E, C = South.EKIMAE, South.CANAL_ROAD
	local H = HanamiConfig.HALF
	local ez = (E.z0 + E.z1) / 2
	local cz = (C.z0 + C.z1) / 2
	Blocks.Lanes(f, true, South.SIDE[1] - 12, South.SIDE[2] + 12, ez, 12)
	Blocks.Lanes(f, true, -H, H, cz, 12)
	Blocks.Lanes(f, false, E.z1, C.z0, 0, 22)
	for _, x in ipairs(South.SIDE) do
		Blocks.Lanes(f, false, South.VIADUCT.z1, C.z0, x, 12)
	end
	-- The boulevard's median: a planted kerb down its middle, trees in it.
	f:part("Median", Vector3.new(5, 1, C.z0 - E.z1 - 30), Vector3.new(0, 0.5, (E.z1 + C.z0) / 2), P.KERB, M.Granite)
	for z = E.z1 + 22, C.z0 - 18, 20 do
		CityKit.StreetTree(f:within(CFrame.new(0, 1, z)), z, 1.7)
	end
	-- Crossings.
	for _, x in ipairs({ -36, 36, S.Arcade.X, -110 }) do
		Blocks.Zebra(f, x, ez, true, 24, 10)
	end
	Blocks.Zebra(f, 0, E.z1 + 7, false, 44, 10)
	Blocks.Zebra(f, 0, C.z0 - 7, false, 44, 10)
	for _, x in ipairs({ -36, 36, S.Arcade.X, -330, 330 }) do
		Blocks.Zebra(f, x, cz, true, 24, 10)
	end
	for _, x in ipairs(South.SIDE) do
		Blocks.Zebra(f, x, E.z1 + 7, false, 24, 10)
		Blocks.Zebra(f, x, ez, true, 24, 10)
	end
	-- Lamps and trees down the boulevard's pavements, guard rails along its kerbs.
	for _, s in ipairs({ -1, 1 }) do
		Blocks.Avenue(f, false, E.z1 + 16, C.z0 - 14, s * 24.5, if s < 0 then "+x" else "-x", 20, 30 + s, nil, false, true)
	end
	-- Traffic lights where the boulevard meets the roads.
	for _, c in ipairs({ { -24, E.z1 + 2, "+x" }, { 24, E.z1 + 2, "-x" }, { -24, C.z0 - 2, "+x" }, { 24, C.z0 - 2, "-x" } } :: { { any } }) do
		CityKit.TrafficLight(CityKit.Scaled(At(f, c[1], c[2], c[3], WALK), 1.3), 12)
	end
	-- The side streets by the market and the yard: pavements along them, poles and wires.
	for _, x in ipairs(South.SIDE) do
		local s = if x > 0 then 1 else -1
		Blocks.Walk(f, x - s * 12 - (if s > 0 then 8 else 0), x - s * 12 + (if s < 0 then 8 else 0), South.VIADUCT.z1, E.z0, { if s > 0 then "+x" else "-x" })
		Blocks.Poles(f, Vector3.new(x - s * 15, WALK, South.VIADUCT.z1 + 20), Vector3.new(x - s * 15, WALK, E.z0 - 10), 5, false)
	end
	-- Cars on the roads.
	-- (They keep left: heading east (-X) on the north half of a road, south (-Z) on its east half.)
	for _, spec in ipairs({ { -60, cz + 6, -1, "kei", Color3.fromRGB(240, 196, 60) }, { 160, cz - 6, 1, "van", Color3.fromRGB(236, 236, 230) },
		{ -300, cz - 6, 1, "taxi", Color3.fromRGB(30, 32, 38) }, { 420, cz + 6, -1, "truck", Color3.fromRGB(236, 236, 230) },
		{ -11, -300, 0, "taxi", Color3.fromRGB(240, 196, 40) }, { 11, -270, 2, "kei", Color3.fromRGB(196, 60, 56) },
		{ -150, ez - 6, 1, "van", Color3.fromRGB(70, 110, 170) } } :: { { any } }) do
		local dir: number = spec[3]
		local yaw = if dir == 0 then 0 elseif dir == 2 then math.pi elseif dir < 0 then math.pi / 2 else -math.pi / 2
		CityKit.BigCar(f:within(CFrame.new(spec[1], 0, spec[2]) * CFrame.Angles(0, yaw, 0)), spec[4], spec[5])
	end
end

function South.Build(root: B)
	viaduct(root)
	station(root)
	square(root)
	department(root)
	shrine(root)
	arcade(root)
	stationBlocks(root)
	railYard(root)
	fishMarket(root)
	canal(root)
	roads(root)
end

return South
