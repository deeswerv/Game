--!strict
-- HANAMI CITY, built: the world past Downtown. A Japanese city at the scale of a real one next
-- to the Roblox Boy -- avenues 44 studs of road between wide pavements, floors 9.5 studs, a
-- crossing you take a while to walk over -- in the game's painted low-poly look (HanamiConfig
-- has the map):
--
--   THE SOUTH     (CitySouth) the railway on its viaduct, HANAMI STATION, the square with the
--                 Great Sakura, the department store's giant screen, the shrine, HANAMI GINZA,
--                 the rail yard, the fish market, the canal and its bridges.
--   THE MIDDLE    (CityMiddle) THE SCRAMBLE -- the crossing under giant screens, the round
--                 tower, tall signs on every building; LANTERN ROW's drinking alleys under
--                 strings of lanterns round the festival tower; the Kurogane STEELWORKS, its
--                 furnace hall, stacks, the quay, the crane and the ship.
--   THE NORTH     (CityNorth) the Thousand Gates up to KUROGANE CASTLE on its stone base;
--                 HANAMI PARK and its lantern pond; KUROGANE HEIGHTS, the clan's towers.
--
-- Built at run time by HanamiService, in its own folder, in the city's frame. Markers the
-- service and the quests need are invisible named parts. Everything that is not the ground, a
-- building's body, a pole, a vehicle or something to stand on is decoration (no collision, no
-- raycasts).

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ServerScriptService.ArenaService.Kit)
local CityKit = require(ServerScriptService.HanamiService.CityKit)
local South = require(ServerScriptService.HanamiService.CitySouth)
local Middle = require(ServerScriptService.HanamiService.CityMiddle)
local North = require(ServerScriptService.HanamiService.CityNorth)
local HanamiConfig = require(ReplicatedStorage.HanamiConfig)

local City = {}

type B = Kit.Builder
local M = Enum.Material
local P = CityKit.P
local darker, lighter = CityKit.Darker, CityKit.Lighter

-- The city's own light: a warm spring afternoon, a little hazy, pink in the distance.
City.Look = {
	Grade = { Saturation = 0.18, Contrast = 0.08, TintColor = Color3.fromRGB(255, 246, 240) },
	Clouds = { Cover = 0.45, Density = 0.4, Color = Color3.fromRGB(255, 248, 250) },
	Atmosphere = { Density = 0.27, Haze = 1.4, Color = Color3.fromRGB(246, 228, 234), Decay = Color3.fromRGB(150, 146, 176) },
}

-- For tools/mapview: the city's own cameras only (city frame), and people standing about for
-- scale (the players' own rig).
City.PreviewOnly = true
City.Preview = {
	{ pos = { 0, 5.6, -446 }, look = { 0, 20, -380 }, fov = 70 },          -- 0 arriving: the square, the Great Sakura
	{ pos = { 40, 6, -372 }, look = { 0, 22, -490 }, fov = 70 },           -- 1 the station from the square
	{ pos = { -130, 70, -330 }, look = { 0, 0, -440 }, fov = 60 },         -- 2 over the square
	{ pos = { 108, 5.6, -330 }, look = { 108, 12, -250 }, fov = 70 },      -- 3 inside Hanami Ginza
	{ pos = { -30, 6, -350 }, look = { 0, 14, -150 }, fov = 70 },          -- 4 up the boulevard to the bridge
	{ pos = { -90, 6, -206 }, look = { 60, 10, -180 }, fov = 70 },         -- 5 the canal walk
	{ pos = { -140, 6, -404 }, look = { -220, 12, -420 }, fov = 70 },      -- 6 the shrine through its torii
	{ pos = { -280, 10, -310 }, look = { -430, 12, -420 }, fov = 70 },     -- 7 the rail yard and its shed
	{ pos = { 300, 9, -330 }, look = { 430, 12, -420 }, fov = 70 },        -- 8 the fish market
	{ pos = { 0, 320, -60 }, look = { 0, 0, -420 }, fov = 60 },            -- 9 over the south
	{ pos = { 30, 6, -120 }, look = { 0, 30, 20 }, fov = 72 },             -- 10 the Scramble from the bridge end
	{ pos = { 40, 6, 40 }, look = { -10, 26, -10 }, fov = 75 },            -- 11 the Scramble from its corner
	{ pos = { -200, 6, 2 }, look = { -330, 10, 4 }, fov = 70 },            -- 12 into Lantern Row
	{ pos = { -352, 6, -6 }, look = { -360, 14, 40 }, fov = 72 },          -- 13 the festival tower
	{ pos = { 200, 7, 4 }, look = { 330, 14, 40 }, fov = 70 },             -- 14 into the Steelworks
	{ pos = { 470, 8, -40 }, look = { 560, 24, -60 }, fov = 70 },          -- 15 the quay and the crane
	{ pos = { 0, 6, 230 }, look = { 0, 34, 330 }, fov = 70 },              -- 16 the Thousand Gates
	{ pos = { 0, 46, 400 }, look = { 0, 60, 540 }, fov = 72 },             -- 17 the court and the keep
	{ pos = { -300, 7, 330 }, look = { -400, 6, 430 }, fov = 70 },         -- 18 the lantern pond
	{ pos = { 260, 7, 260 }, look = { 400, 60, 420 }, fov = 70 },          -- 19 Kurogane Heights
	{ pos = { 0, 360, -700 }, look = { 0, 0, 0 }, fov = 60 },              -- 20 the whole city
}
City.Figures = {
	{ 0, 0.5, -440, 0 }, { 6, 0.5, -436, 0.6 }, { -10, 0.5, -420, 3 }, { 30, 0.5, -470, 2 },
	{ 104, 0.5, -310, 0 }, { 112, 0.5, -296, -1.6 }, { 100, 0.5, -280, 3.1 },
	{ -20, 0.5, -205, 1.5 }, { 20, 0.5, -152, 0 },
	{ 28, 0.5, -30, 0.8 }, { -6, 0, 14, 2.4 }, { 4, 0, -4, 0.3 }, { 30, 0.5, 30, -2 },
	{ -300, 0.5, 2, 1.2 }, { -360, 0.5, -8, 3 },
	{ 0, 0.5, 248, 0 }, { -390, 0.5, 350, 0.4 },
}

-- ------------------------------------------------------------------ the ground --

local function ground(root: B)
	local g = root:folder("Ground")
	local H = HanamiConfig.HALF
	local C = HanamiConfig.CANAL
	-- (Cut round the canal, and round the Steelworks' dock basin at the city's west edge.)
	local dock = Middle.DOCK
	CityKit.Ground(g, "Street", -H, H, -H, C.z0 - 1.2, 0, P.ROAD, M.Asphalt, 10)
	CityKit.Ground(g, "Street", -H, H, C.z1 + 1.2, dock.z0, 0, P.ROAD, M.Asphalt, 10)
	CityKit.Ground(g, "Street", -H, dock.x0, dock.z0, dock.z1, 0, P.ROAD, M.Asphalt, 10)
	CityKit.Ground(g, "Street", -H, H, dock.z1, H, 0, P.ROAD, M.Asphalt, 10)
end

-- ------------------------------------------------------------------ the skyline --

--- The city going on past its edges: a ring of towers, HANAMI TOWER (a lattice spire with its
--- two decks) to the north-east, the snow-capped mountain far to the north-west.
local function skyline(root: B)
	local f = root:folder("Skyline")
	local rng = Random.new(4242)
	local H = HanamiConfig.HALF
	for k = 0, 83 do
		local a = k / 84 * math.pi * 2 + rng:NextNumber(-0.015, 0.015)
		-- Out past the corners the ring reaches further (the city is square).
		local edge = H / math.max(math.abs(math.cos(a)), math.abs(math.sin(a)))
		-- (Close in on the east: Downtown floats at the same height not far that way.)
		local r = edge + rng:NextNumber(70, if math.cos(a) < -0.45 then 120 else 260)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local w = rng:NextNumber(40, 80)
		local d = rng:NextNumber(40, 80)
		local h = rng:NextNumber(70, 240)
		local glassy = rng:NextNumber() < 0.45
		local c = if glassy then ({ Color3.fromRGB(120, 156, 186), Color3.fromRGB(96, 146, 156), Color3.fromRGB(80, 94, 116) })[rng:NextInteger(1, 3)]
			else CityKit.FACADES[rng:NextInteger(1, #CityKit.FACADES)]
		local b = f:within(CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(0, 0, 0)))
		b:decor("Tower", Vector3.new(w, h, d), Vector3.new(0, h / 2, 0), c, if glassy then M.Glass else nil,
			{ reflectance = if glassy then 0.12 else 0 })
		local band = if glassy then lighter(c, 0.35) else (if rng:NextNumber() < 0.5 then P.GLASS_DARK else P.GLASS)
		local step = if glassy then 10 else 9.5
		for y = 14, h - 8, step * 2 do
			b:decor(if glassy then "Band" else "Windows", Vector3.new(w + 0.3, if glassy then 1.2 else 4, d + 0.3), Vector3.new(0, y, 0), band,
				if glassy then nil else M.Glass)
		end
		if h > 160 then
			local sh = h * 0.16
			b:decor("Setback", Vector3.new(w * 0.68, sh, d * 0.68), Vector3.new(0, h + sh / 2, 0), c, if glassy then M.Glass else nil)
			b:decor("NameBand", Vector3.new(w * 0.72, 2.4, d * 0.72), Vector3.new(0, h + sh, 0), CityKit.SIGNS[rng:NextInteger(1, 7)])
			h += sh
			b:decor("Mast", Vector3.new(0.8, 20, 0.8), Vector3.new(0, h + 10, 0), P.STEEL)
			b:decor("AirLight", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, h + 20, 0), Color3.fromRGB(240, 60, 50), M.Neon)
		else
			b:decor("TowerTop", Vector3.new(w * 0.5, 6, d * 0.5), Vector3.new(0, h + 3, 0), darker(c, 0.2))
		end
		if rng:NextNumber() < 0.35 then
			local sc = CityKit.SIGNS[rng:NextInteger(1, 7)]
			b:decor("Billboard", Vector3.new(w * 0.8, w * 0.3, 0.8), Vector3.new(0, h - w * 0.2, -d / 2 - 0.5), sc)
		end
	end
	-- The ground the skyline stands on, round the city; the harbour off the Steelworks' dock.
	-- Narrow on the east, where Downtown is (its own skyline reaches to about 220 studs short
	-- of this one).
	local o, oe = 690, 150             -- (a part is at most 2,048 studs long)
	local dock = Middle.DOCK
	for _, spec in ipairs({ { (o - oe) / 2, -H - o / 2, H * 2 + o + oe, o }, { (o - oe) / 2, H + o / 2, H * 2 + o + oe, o },
		{ -H - oe / 2, 0, oe, H * 2 },
		{ H + o / 2, (-H + dock.z0) / 2, o, dock.z0 + H }, { H + o / 2, (dock.z1 + H) / 2, o, H - dock.z1 } }) do
		f:decor("OuterGround", Vector3.new(math.min(2048, spec[3]), 1, spec[4]), Vector3.new(spec[1], -0.6, spec[2]), Color3.fromRGB(96, 98, 104),
			M.Asphalt)
	end
	f:decor("Harbour", Vector3.new(o, 1, dock.z1 - dock.z0), Vector3.new(H + o / 2, -3.5, (dock.z0 + dock.z1) / 2), Color3.fromRGB(64, 128, 160),
		M.Glass, { transparency = 0.1 })
	-- HANAMI TOWER: a white lattice tapering up off a triangular foot, two decks, the spire.
	local t = f:within(CFrame.new(-700, 0, 1000))
	local white, steel = Color3.fromRGB(242, 244, 246), Color3.fromRGB(200, 206, 214)
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		local foot = Vector3.new(math.cos(a) * 48, 0, math.sin(a) * 48)
		local cf, len = Kit.Span(foot, Vector3.new(math.cos(a) * 14, 330, math.sin(a) * 14))
		t:decor("TowerLeg", Vector3.new(6, 6, len), cf, white)
	end
	for _, band in ipairs({ { 60, 76 }, { 140, 54 }, { 220, 36 } }) do
		t:decor("TowerRing", Vector3.new(4, band[2], band[2]), CityKit.Vertical(Vector3.new(0, band[1], 0)), steel, nil, { shape = "Cylinder" })
	end
	for _, deck in ipairs({ { 300, 44, 22 }, { 420, 28, 12 } }) do
		t:decor("Deck", Vector3.new(deck[3], deck[2], deck[2]), CityKit.Vertical(Vector3.new(0, deck[1], 0)), white, nil, { shape = "Cylinder" })
		t:decor("DeckGlass", Vector3.new(deck[3] * 0.4, deck[2] + 0.6, deck[2] + 0.6), CityKit.Vertical(Vector3.new(0, deck[1], 0)), P.GLASS_DARK,
			M.Glass, { shape = "Cylinder" })
	end
	t:decor("Shaft", Vector3.new(140, 18, 18), CityKit.Vertical(Vector3.new(0, 360, 0)), white, nil, { shape = "Cylinder" })
	t:decor("Spire", Vector3.new(120, 6, 6), CityKit.Vertical(Vector3.new(0, 492, 0)), steel, nil, { shape = "Cylinder" })
	t:decor("AirLight", Vector3.new(3, 3, 3), Vector3.new(0, 554, 0), Color3.fromRGB(240, 60, 50), M.Neon)
	-- The mountain, far off: a snow-capped cone over the city's north-west.
	local fuji = f:within(CFrame.new(1500, -10, 2600))
	local n = 12
	local R, Hh = 1000, 760
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2
		local w = 2 * R * math.tan(math.pi / n) * 1.04
		local cf = CFrame.Angles(0, a, 0) * CFrame.new(0, Hh / 2, -R / 2)
		fuji:decor("Mountain", Vector3.new(w, Hh, R), cf, Color3.fromRGB(116, 134, 172), M.Slate, { shape = "Wedge" })
		local r2, h2 = R * 0.3, Hh * 0.3
		local w2 = 2 * r2 * math.tan(math.pi / n) * 1.04
		local cf2 = CFrame.Angles(0, a, 0) * CFrame.new(0, Hh - h2 / 2 + 0.5, -r2 / 2)
		fuji:decor("Snow", Vector3.new(w2, h2, r2), cf2, Color3.fromRGB(244, 246, 252), M.Snow, { shape = "Wedge" })
	end
end

-- ------------------------------------------------------------------ build --

function City.Build(parent: Instance, centre: Vector3)
	local root = Kit.new(parent, CFrame.new(centre))
	local H = HanamiConfig.HALF

	-- The city's look while you are in it (ArenaMood.client reads these).
	parent:SetAttribute("ZoneCentre", centre + Vector3.new(0, 90, 0))
	parent:SetAttribute("ZoneHalf", Vector3.new(H + 40, 200, H + 40))
	for group, values in pairs(City.Look) do
		for property, value in pairs(values) do
			parent:SetAttribute(("Look_%s_%s"):format(group, property), value)
		end
	end

	ground(root)
	South.Build(root)
	Middle.Build(root)
	North.Build(root)
	skyline(root)

	CityKit.Marker(root, "HanamiArrival", HanamiConfig.Sites.Arrival + Vector3.new(0, 0.5, 0))
	Kit.Bounds(root, H - 2, H - 2, 320)

	-- Finding your way: landmarks on the compass, and the named areas.
	local function waypoint(name: string, icon: string, at: Vector3)
		local m = CityKit.Marker(root, "Waypoint", at + Vector3.new(0, 3, 0))
		m:SetAttribute("WaypointName", name)
		m:SetAttribute("WaypointIcon", icon)
		m:AddTag("Waypoint")
	end
	local S = HanamiConfig.Sites
	waypoint("GREAT SAKURA", "🌸", S.GreatSakura)
	waypoint("SHRINE", "⛩", S.Shrine)
	waypoint("HANAMI GINZA", "🏮", S.Arcade)
	waypoint("THE SCRAMBLE", "🚦", S.Scramble)
	waypoint("LANTERN ROW", "🏮", S.LanternGate)
	waypoint("STEELWORKS", "🏭", S.IronGate)
	waypoint("THE THOUSAND GATES", "⛩", S.StairFoot)
	waypoint("KUROGANE CASTLE", "🏯", S.Court)
	waypoint("RAIL YARD", "🚃", S.Camp)
	waypoint("FISH MARKET", "🐟", S.Market)
	waypoint("LANTERN POND", "🏮", S.Pond)
	for _, a in ipairs(HanamiConfig.Areas) do
		local y = a.y or 0
		local box = root:decor("Area", Vector3.new(a.x1 - a.x0, 60, a.z1 - a.z0), Vector3.new((a.x0 + a.x1) / 2, y + 26, (a.z0 + a.z1) / 2),
			P.CREAM, nil, { transparency = 1 })
		box:SetAttribute("AreaName", a.name)
		box:SetAttribute("AreaSub", a.sub)
		box:AddTag("Area")
	end
	local all = root:decor("Area", Vector3.new(H * 2, 240, H * 2), Vector3.new(0, 100, 0), P.CREAM, nil, { transparency = 1 })
	all:SetAttribute("AreaName", HanamiConfig.NAME)
	all:SetAttribute("AreaSub", "THE NEXT CHAPTER")
	all:AddTag("Area")

	-- Clues and seals: their props, and a marker for the service to wire.
	for _, clue in ipairs(HanamiConfig.Clues) do
		local c = CityKit.Scaled(root:within(CFrame.new(clue.at)), 1.3)
		c:part("ClueTable", Vector3.new(3.4, 2.6, 2.2), Vector3.new(0, 1.3, 0), P.WOOD, M.WoodPlanks)
		local paper = c:decor("Clue", Vector3.new(1.4, 0.1, 1), Vector3.new(0, 2.66, 0), P.PAPER)
		paper:SetAttribute("ClueId", clue.id)
		c:decor("ClueWeight", Vector3.new(0.5, 0.4, 0.5), Vector3.new(0.6, 2.85, 0.2), P.KURO)
	end
	for i, at in ipairs(HanamiConfig.Seals) do
		CityKit.Marker(root, "SealSpot", at + Vector3.new(0, 1.6, 0), { Index = i })
	end
end

return City
