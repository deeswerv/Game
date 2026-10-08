--!strict
-- HANAMI CITY: the world past Downtown, opened by beating the Don at the top of ZEE TOWER.
--
-- One source of truth for where everything in it is, shared by the server (the builder in
-- HanamiService.City, the population and the fights in HanamiService, the quests) and the
-- client (the area titles, the boss bar). Everything is given in the city's own frame -- +Z
-- north, Y up from the street -- and `At` turns it into a world position. (Facing north, +X is
-- on your left: the compass calls it west.)
--
-- 1,200 studs square, at the scale of a real city next to the Roblox Boy (a stud is about a
-- third of a metre): avenues 44 studs of road between pavements 14 wide, floors 9.5 studs.
--
--                                    north
--   +--------------------------------------------------------------------------+
--   |  KUROGANE HEIGHTS      |   KUROGANE CASTLE (on its base, y 40)  |  HANAMI PARK   |
--   |  towers, the HQ        |   the court, the keep, the walls       |  the lantern   |
--   |                        |        THE THOUSAND GATES (stair)      |  pond, torii   |
--   |--------------------------- north avenue ------------------------------------|
--   |  THE STEELWORKS        |        THE SCRAMBLE                    |  LANTERN ROW   |
--   |  foundry, docks, crane |  the crossing, screens, the round tower|  izakaya alleys|
--   |--------------------------------- the canal ----------------------------------|
--   |  THE FISH MARKET       |  HANAMI STATION: the square, the Great |  THE RAIL YARD |
--   |  the hall, the quay    |  Sakura, the arcade, the shrine        |  sidings, shed |
--   |==================== the railway viaduct (south edge) ======================|
--   +--------------------------------------------------------------------------+
--     (+X ... west)                 south (you arrive here)          (-X ... east)

local HanamiConfig = {}

HanamiConfig.NAME = "HANAMI CITY"
HanamiConfig.FOLDER = "Hanami"
HanamiConfig.CENTRE = Vector3.new(1100, 1000, 1500)
HanamiConfig.HALF = 600                 -- the city is 1,200 studs square
HanamiConfig.PLATEAU = 40               -- how high the castle's stone base stands over the street
HanamiConfig.CANAL = { z0 = -200, z1 = -160, floor = -8, water = -3 }
HanamiConfig.RIVER = { z0 = -200, z1 = -160, depth = 8 } -- (the canal, by its old name)
-- The avenues: Station Boulevard runs north from the square through the Scramble to the
-- Thousand Gates (x = 0); Hanami-dori runs east-west through the Scramble (z = 0).
HanamiConfig.AVENUE = { road = 22, walk = 14 }   -- half the road's width, the pavement's width

--- A point in the city's frame, in the world.
function HanamiConfig.At(x: number, y: number, z: number): Vector3
	return HanamiConfig.CENTRE + Vector3.new(x, y, z)
end

--- A point in the world, in the city's frame.
function HanamiConfig.Local(world: Vector3): Vector3
	return world - HanamiConfig.CENTRE
end

export type Area = {
	id: string, name: string, sub: string, x0: number, x1: number, z0: number, z1: number,
	y: number?, safe: boolean?, level: { number },
}

-- The named places, south to north. `level` is the enemy level range there; `safe` places
-- have no enemies at all.
HanamiConfig.Areas = {
	{ id = "Station", name = "HANAMI STATION", sub = "EKIMAE · THE STATION SQUARE", x0 = -240, x1 = 240, z0 = -600, z1 = -200,
	  safe = true, level = { 10, 10 } },
	{ id = "RailYard", name = "THE RAIL YARD", sub = "THE SIDINGS & THE OLD SHED", x0 = -600, x1 = -240, z0 = -600, z1 = -200,
	  level = { 10, 12 } },
	{ id = "Market", name = "THE FISH MARKET", sub = "UOICHIBA · THE DAWN AUCTION", x0 = 240, x1 = 600, z0 = -600, z1 = -200,
	  level = { 10, 12 } },
	{ id = "LanternRow", name = "LANTERN ROW", sub = "THE OLD DRINKING ALLEYS", x0 = -600, x1 = -176, z0 = -160, z1 = 200,
	  level = { 11, 13 } },
	{ id = "Scramble", name = "THE SCRAMBLE", sub = "HANAMI CROSSING", x0 = -176, x1 = 176, z0 = -160, z1 = 200,
	  level = { 11, 13 } },
	{ id = "Ironworks", name = "THE STEELWORKS", sub = "KUROGANE FOUNDRY & DOCKS", x0 = 176, x1 = 600, z0 = -160, z1 = 200,
	  level = { 12, 14 } },
	{ id = "Park", name = "HANAMI PARK", sub = "THE LANTERN POND", x0 = -600, x1 = -220, z0 = 236, z1 = 600,
	  safe = true, level = { 10, 10 } },
	{ id = "Keep", name = "KUROGANE CASTLE", sub = "THE SHOGUN'S STRONGHOLD", x0 = -220, x1 = 220, z0 = 236, z1 = 600,
	  y = 40, level = { 14, 16 } },
	{ id = "Heights", name = "KUROGANE HEIGHTS", sub = "THE CLAN'S TOWERS", x0 = 220, x1 = 600, z0 = 236, z1 = 600,
	  level = { 13, 15 } },
} :: { Area }

--- The area a city-frame point is in, or nil.
function HanamiConfig.AreaAt(p: Vector3): Area?
	for _, a in ipairs(HanamiConfig.Areas) do
		if p.X >= a.x0 and p.X <= a.x1 and p.Z >= a.z0 and p.Z <= a.z1 then
			return a
		end
	end
	return nil
end

--- Is a world position inside the city at all (and not far below or above it)?
function HanamiConfig.Inside(world: Vector3): boolean
	local p = HanamiConfig.Local(world)
	local h = HanamiConfig.HALF
	return math.abs(p.X) <= h and math.abs(p.Z) <= h and p.Y > -40 and p.Y < 200
end

-- Where things are (city frame, on the ground). The builder puts the landmarks here; the
-- service, the quests and the tests read them from here, so nothing drifts apart.
HanamiConfig.Sites = {
	Arrival = Vector3.new(0, 0, -446),            -- the station square, in front of the doors: where Travel lands you
	Station = Vector3.new(0, 0, -500),
	GreatSakura = Vector3.new(0, 0, -400),        -- the square's tree
	Shrine = Vector3.new(-214, 1.5, -420),        -- the shrine off the square, through its torii
	Elder = Vector3.new(-180, 0, -406),           -- Elder Hoshi, inside the shrine's torii
	Captain = Vector3.new(-46, 0.5, -206),        -- Captain Rei, on the canal walk by the red bridge
	Merchant = Vector3.new(114, 0, -300),         -- the trader's counter, in the arcade
	Arcade = Vector3.new(108, 0, -286),           -- HANAMI GINZA, the covered shopping street
	RedBridge = Vector3.new(0, 0, -180),          -- the red bridge north over the canal
	WestBridge = Vector3.new(330, 0, -180),
	EastBridge = Vector3.new(-330, 0, -180),
	Scramble = Vector3.new(0, 0, 0),              -- the big crossing
	LanternGate = Vector3.new(-178, 0, 0),        -- the arch into Lantern Row
	LanternHeart = Vector3.new(-360, 0, 0),       -- the middle of Lantern Row, by the festival tower
	IronGate = Vector3.new(178, 0, 0),            -- the gate into the Steelworks
	SteelworksHeart = Vector3.new(330, 0, 0),     -- the middle of the Steelworks, on its yard road
	Foundry = Vector3.new(400, 0, 96),            -- the furnace yard: Foreman Tetsu
	Crane = Vector3.new(540, 0, -60),             -- the dock crane
	Camp = Vector3.new(-430, 0, -420),            -- the gang's hideout in the old engine shed
	SignalBox = Vector3.new(-300, 0, -330),
	Market = Vector3.new(420, 0, -420),           -- the auction floor the raiders come for
	StairFoot = Vector3.new(0, 0, 252),           -- the foot of the Thousand Gates
	KeepGate = Vector3.new(0, 40, 380),           -- the top of the stair, the castle's gate
	Court = Vector3.new(0, 40, 470),              -- the Shogun's court: the final fight
	Throne = Vector3.new(0, 40, 540),             -- where the Shogun waits
	Pond = Vector3.new(-400, 0, 420),             -- the lantern pond in Hanami Park
}

--- A site, in the world.
function HanamiConfig.Site(name: string): Vector3
	local p = HanamiConfig.Sites[name]
	assert(p, "no Hanami site " .. name)
	return HanamiConfig.CENTRE + p
end

-- The court's floor: the final fight happens inside this box (city frame).
HanamiConfig.CourtBox = { x0 = -90, x1 = 90, z0 = 420, z1 = 545 }

-- The missing townsfolk, held in the gang's hideout in the old rail shed (the rescue job).
HanamiConfig.Captives = {
	Vector3.new(-446, 0, -412), Vector3.new(-430, 0, -432), Vector3.new(-414, 0, -412),
}

-- The ledger, the shipping tags, the orders and the map: what the investigation finds in
-- the Steelworks. Each is a prop with an Inspect prompt.
HanamiConfig.Clues = {
	{ id = "Ledger", at = Vector3.new(240, 0, -80), title = "A burnt ledger",
	  text = "Weekly shipments \"to the Castle\" -- signed with an iron crest." },
	{ id = "Crate", at = Vector3.new(490, 0, 38), title = "Crates stamped ZEE",
	  text = "The Don's crates. He was only ever a supplier." },
	{ id = "Orders", at = Vector3.new(240, 0, 110), title = "Sealed orders",
	  text = "\"Raise the levy on the market. -- S.\"" },
	{ id = "Map", at = Vector3.new(218, 0, 46), title = "A map of the Castle",
	  text = "The Thousand Gates lead straight to the Shogun's court." },
}

-- Iron seals the Kurogane use as passes, hidden round the city's high and hidden places, to
-- find (the collection job). Each is reachable on foot (a ladder or a stair).
HanamiConfig.Seals = {
	Vector3.new(161, 32.25, -259),    -- on the roof of the ramen shop on the canal road (the ladder up its side)
	Vector3.new(-322, 21.455, 122),   -- a Lantern Row roof terrace on the north alley (the ladder beside it)
	Vector3.new(540, 36, -60),        -- on the dock crane's walkway (the ladder up its leg)
	Vector3.new(-296, 14, -335),      -- on the signal box's balcony in the rail yard (its stair)
	Vector3.new(500, 0, -584),        -- under the railway, past the bars in its arches, at the market's far end
}

-- Where the raiders come from when they hit the market (the survival job), and how many waves;
-- `workers` are the market hands on the auction floor who put their hands up.
HanamiConfig.Raid = {
	site = Vector3.new(420, 0, -420),
	radius = 44,
	waves = {
		{ "Ronin", "Ronin", "Ronin" },
		{ "Ronin", "Shinobi", "Shinobi", "Rifleman" },
		{ "Shieldbearer", "Ronin", "Shinobi", "Rifleman", "Juggernaut" },
	},
	from = { Vector3.new(420, 0, -330), Vector3.new(290, 0, -420), Vector3.new(560, 0, -340) },
	workers = {
		{ at = Vector3.new(410, 0, -408), name = "Auctioneer Kenta" },
		{ at = Vector3.new(432, 0, -408), name = "Haru" },
	},
}

-- Who lives where, while somebody is in the city to meet them. Kept modest: a street of four
-- is a fight, a street of twelve is a wall.
HanamiConfig.Population = {
	-- Lantern Row: the alleys and a roof.
	{ archetype = "Ronin", at = Vector3.new(-230, 0.5, 0) }, { archetype = "Ronin", at = Vector3.new(-360, 0.5, 6) },
	{ archetype = "Shieldbearer", at = Vector3.new(-292, 0.5, 100) }, { archetype = "Rifleman", at = Vector3.new(-338, 21.455, 122) },
	{ archetype = "Shinobi", at = Vector3.new(-470, 0.5, -68) }, { archetype = "Ronin", at = Vector3.new(-500, 0.5, 100) },
	-- The Scramble's corners.
	{ archetype = "Ronin", at = Vector3.new(86, 0.5, 44) }, { archetype = "Shinobi", at = Vector3.new(-100, 0, -60) },
	-- The Steelworks.
	{ archetype = "Juggernaut", at = Vector3.new(260, 0, 0) }, { archetype = "Rifleman", at = Vector3.new(290, 0, 150) },
	{ archetype = "Shieldbearer", at = Vector3.new(440, 0, 12) }, { archetype = "Ronin", at = Vector3.new(500, 0, 120) },
	{ archetype = "Oni", at = Vector3.new(310, 0, -20) },
	-- The rail yard and the market.
	{ archetype = "Shinobi", at = Vector3.new(-330, 0, -400) }, { archetype = "Ronin", at = Vector3.new(-520, 0, -330) },
	{ archetype = "Ronin", at = Vector3.new(330, 0, -330) }, { archetype = "Shinobi", at = Vector3.new(500, 0, -320) },
	-- Kurogane Heights: the clan's own plaza.
	{ archetype = "Rifleman", at = Vector3.new(320, 0.5, 290) }, { archetype = "Ronin", at = Vector3.new(470, 0.5, 290) },
	-- The castle.
	{ archetype = "Oni", at = Vector3.new(-40, 40, 400) }, { archetype = "Oni", at = Vector3.new(40, 40, 400) },
	{ archetype = "Rifleman", at = Vector3.new(-120, 40, 440) }, { archetype = "Rifleman", at = Vector3.new(96, 40, 410) },
} :: { { archetype: string, at: Vector3 } }

-- The crowd (HanamiService spawns them, Pedestrians.client walks them, as Downtown's): people
-- crossing the Scramble on both diagonals and all four zebras, and walking the pavements
-- round it. { from, to, look (DistrictService.Crowd.CIVILIANS), speed }, about CENTRE; the crossings
-- on the road (y 0.1), the pavements on the kerb (y 0.5). The Hanami suite checks every
-- stretch is clear.
HanamiConfig.Walkers = {
	{ Vector3.new(-20, 0.1, -20), Vector3.new(20, 0.1, 20), 1, 4.6 },
	{ Vector3.new(19, 0.1, 21), Vector3.new(-21, 0.1, -19), 2, 5 },
	{ Vector3.new(20, 0.1, -20), Vector3.new(-20, 0.1, 20), 3, 4.4 },
	{ Vector3.new(-21, 0.1, 19), Vector3.new(19, 0.1, -21), 6, 4.8 },
	{ Vector3.new(-20, 0.1, 29), Vector3.new(20, 0.1, 29), 2, 5.2 },
	{ Vector3.new(20, 0.1, -29), Vector3.new(-20, 0.1, -29), 4, 5.4 },
	{ Vector3.new(29, 0.1, -20), Vector3.new(29, 0.1, 20), 5, 4.2 },
	{ Vector3.new(-29, 0.1, 20), Vector3.new(-29, 0.1, -20), 1, 4.8 },
	{ Vector3.new(32.5, 0.5, 40), Vector3.new(32.5, 0.5, 92), 3, 4.6 },
	{ Vector3.new(-30.5, 0.5, 92), Vector3.new(-30.5, 0.5, 40), 6, 5 },
	{ Vector3.new(32.5, 0.5, -40), Vector3.new(32.5, 0.5, -110), 2, 4.8 },
	{ Vector3.new(-32.5, 0.5, -110), Vector3.new(-32.5, 0.5, -40), 4, 4.4 },
	{ Vector3.new(40, 0.5, 32.5), Vector3.new(92, 0.5, 32.5), 5, 5 },
	{ Vector3.new(-92, 0.5, -30.5), Vector3.new(-40, 0.5, -30.5), 1, 4.6 },
	{ Vector3.new(-40, 0.5, 32.5), Vector3.new(-92, 0.5, 32.5), 6, 4.8 },
	{ Vector3.new(92, 0.5, -32.5), Vector3.new(40, 0.5, -32.5), 3, 5.2 },
} :: { { any } }

return HanamiConfig
