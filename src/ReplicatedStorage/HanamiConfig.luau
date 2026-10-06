--!strict
-- HANAMI CITY: the world past Downtown, opened by beating the Don at the top of ZEE TOWER.
--
-- One source of truth for where everything in it is, shared by the server (the builder in
-- HanamiService.City, the population and the fights in HanamiService, the quests) and the
-- client (the area titles, the boss bar). Everything is given in the city's own frame -- +Z
-- north, Y up from the street -- and `At` turns it into a world position. (Facing north, +X is
-- on your left: the compass calls it west.)
--
--                               north
--      +-------------------------------------------------------+
--      |  hotel   |      KUROGANE CASTLE (y 30)      | KUROGANE |   the Shogun's black keep on
--      |  towers  |  the court, the keep, the walls  |   HQ     |   its stone base, behind a moat
--      |          |~~~~ moat ~~ THE THOUSAND GATES ~~|          |   and up a stair of red torii
--      |-------------------------------------------------------|
--      |  THE STEELWORKS  |   THE SCRAMBLE   |  LANTERN ROW    |   the foundry and the docks /
--      |  foundry, docks  |  the big crossing |  izakaya alleys |   the crossing / the alleys
--      |~~~~~~~~~~~~~~~~~~~~~~ the canal ~~~~~~~~~~~~~~~~~~~~~~~|   cherry trees on both banks
--      |  THE FISH MARKET |  HANAMI STATION  |  THE RAIL YARD  |   the market / the station
--      |   (+X ... west)  |  square, arcade  |   (-X ... east) |   square, the arcade / sidings
--      |================= the railway viaduct =================|
--      +-------------------------------------------------------+
--                         south (you arrive here)

local HanamiConfig = {}

HanamiConfig.NAME = "HANAMI CITY"
HanamiConfig.FOLDER = "Hanami"
HanamiConfig.CENTRE = Vector3.new(1100, 1000, 1500)
HanamiConfig.HALF = 262                 -- the city is 524 studs square
HanamiConfig.PLATEAU = 30               -- how high the castle's stone base stands over the street
HanamiConfig.CANAL = { z0 = -86, z1 = -64, floor = -6, water = -2.6 }
HanamiConfig.RIVER = { z0 = -86, z1 = -64, depth = 6 } -- (the canal, by its old name)

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
	{ id = "Station", name = "HANAMI STATION", sub = "EKIMAE · THE STATION SQUARE", x0 = -98, x1 = 98, z0 = -258, z1 = -88,
	  safe = true, level = { 10, 10 } },
	{ id = "RailYard", name = "THE RAIL YARD", sub = "THE SIDINGS & THE OLD SHED", x0 = -258, x1 = -98, z0 = -258, z1 = -88,
	  level = { 10, 12 } },
	{ id = "Market", name = "THE FISH MARKET", sub = "UOICHIBA · THE DAWN AUCTION", x0 = 98, x1 = 258, z0 = -258, z1 = -88,
	  level = { 10, 12 } },
	{ id = "LanternRow", name = "LANTERN ROW", sub = "THE OLD DRINKING ALLEYS", x0 = -258, x1 = -50, z0 = -64, z1 = 96,
	  level = { 11, 13 } },
	{ id = "Scramble", name = "THE SCRAMBLE", sub = "HANAMI CROSSING", x0 = -50, x1 = 50, z0 = -64, z1 = 96,
	  level = { 11, 13 } },
	{ id = "Ironworks", name = "THE STEELWORKS", sub = "KUROGANE FOUNDRY & DOCKS", x0 = 50, x1 = 258, z0 = -64, z1 = 96,
	  level = { 12, 14 } },
	{ id = "Keep", name = "KUROGANE CASTLE", sub = "THE SHOGUN'S STRONGHOLD", x0 = -140, x1 = 140, z0 = 116, z1 = 258,
	  y = 30, level = { 14, 16 } },
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
	Arrival = Vector3.new(0, 0, -210),            -- the station square, in front of the doors: where Travel lands you
	Station = Vector3.new(0, 0, -232),
	GreatSakura = Vector3.new(0, 0, -186),        -- the square's tree
	Shrine = Vector3.new(-86, 1.5, -200),         -- the shrine off the square, through its torii
	Elder = Vector3.new(-71, 0, -189),            -- Elder Hoshi, inside the shrine's torii
	Captain = Vector3.new(-15, 0, -96),           -- Captain Rei, at the station end of the red bridge
	Merchant = Vector3.new(4, 0, -127),           -- the trader's counter, in the arcade
	Arcade = Vector3.new(0, 0, -126),             -- HANAMI GINZA, the covered shopping street
	RedBridge = Vector3.new(0, 0, -75),           -- the red bridge north over the canal
	WestBridge = Vector3.new(160, 0, -75),
	EastBridge = Vector3.new(-160, 0, -75),
	Scramble = Vector3.new(0, 0, 10),             -- the big crossing
	LanternGate = Vector3.new(-52, 0, 10),        -- the arch into Lantern Row
	IronGate = Vector3.new(52, 0, 10),            -- the gate into the Steelworks
	Foundry = Vector3.new(160, 0, 50),            -- the furnace yard: Foreman Tetsu
	Crane = Vector3.new(204, 0, -14),             -- the dock crane
	Camp = Vector3.new(-178, 0, -210),            -- the gang's hideout in the old rail shed
	SignalBox = Vector3.new(-124, 0, -186),
	Market = Vector3.new(183, 0, -204),           -- the auction floor the raiders come for
	StairFoot = Vector3.new(0, 0, 62),            -- the foot of the Thousand Gates
	KeepGate = Vector3.new(0, 30, 130),           -- the top of the stair, the castle's gate
	Court = Vector3.new(0, 30, 182),              -- the Shogun's court: the final fight
	Throne = Vector3.new(0, 30, 214),             -- where the Shogun waits
}

--- A site, in the world.
function HanamiConfig.Site(name: string): Vector3
	local p = HanamiConfig.Sites[name]
	assert(p, "no Hanami site " .. name)
	return HanamiConfig.CENTRE + p
end

-- The court's floor: the final fight happens inside this box (city frame).
HanamiConfig.CourtBox = { x0 = -72, x1 = 72, z0 = 144, z1 = 218 }

-- The missing townsfolk, held in the gang's hideout in the old rail shed (the rescue job).
HanamiConfig.Captives = {
	Vector3.new(-190, 0, -204), Vector3.new(-176, 0, -218), Vector3.new(-164, 0, -202),
}

-- The ledger, the shipping tags, the orders and the map: what the investigation finds in
-- the Steelworks. Each is a prop with an Inspect prompt.
HanamiConfig.Clues = {
	{ id = "Ledger", at = Vector3.new(98, 0, -38), title = "A burnt ledger",
	  text = "Weekly shipments \"to the Castle\" -- signed with an iron crest." },
	{ id = "Crate", at = Vector3.new(200, 0, 44), title = "Crates stamped ZEE",
	  text = "The Don's crates. He was only ever a supplier." },
	{ id = "Orders", at = Vector3.new(80, 0, 52), title = "Sealed orders",
	  text = "\"Raise the levy on the market. -- S.\"" },
	{ id = "Map", at = Vector3.new(62, 0, 32), title = "A map of the Castle",
	  text = "The Thousand Gates lead straight to the Shogun's court." },
}

-- Iron seals the Kurogane use as passes, hidden round the city's high and hidden places, to
-- find (the collection job). Each is reachable on foot (a ladder or a stair).
HanamiConfig.Seals = {
	Vector3.new(50, 25, -112),        -- on the roof of the ramen shop by the canal (the ladder up its side)
	Vector3.new(-110, 16.5, 44),      -- a Lantern Row roof terrace (the ladder in the side alley)
	Vector3.new(204, 28, -14),        -- on the dock crane's walkway (the ladder up its leg)
	Vector3.new(-124, 10, -191),      -- on the signal box's balcony in the rail yard (its stair)
	Vector3.new(240, 0, -250),        -- under the railway, past the bars in its arches, at the market's far end
}

-- Where the raiders come from when they hit the market (the survival job), and how many waves;
-- `workers` are the market hands on the auction floor who put their hands up.
HanamiConfig.Raid = {
	site = Vector3.new(183, 0, -204),
	radius = 34,
	waves = {
		{ "Ronin", "Ronin", "Ronin" },
		{ "Ronin", "Shinobi", "Shinobi", "Rifleman" },
		{ "Shieldbearer", "Ronin", "Shinobi", "Rifleman", "Juggernaut" },
	},
	from = { Vector3.new(180, 0, -120), Vector3.new(118, 0, -160), Vector3.new(250, 0, -180) },
	workers = {
		{ at = Vector3.new(176, 0, -196), name = "Auctioneer Kenta" },
		{ at = Vector3.new(190, 0, -196), name = "Haru" },
	},
}

-- Who lives where, while somebody is in the city to meet them. Kept modest: a street of four
-- is a fight, a street of twelve is a wall.
HanamiConfig.Population = {
	{ archetype = "Ronin", at = Vector3.new(-84, 0, 10) }, { archetype = "Ronin", at = Vector3.new(-150, 0, 10) },
	{ archetype = "Shieldbearer", at = Vector3.new(-100, 0, 40) }, { archetype = "Rifleman", at = Vector3.new(-110, 16.5, 28) },
	{ archetype = "Shinobi", at = Vector3.new(-196, 0, -32) }, { archetype = "Ronin", at = Vector3.new(-210, 0, 56) },
	{ archetype = "Juggernaut", at = Vector3.new(120, 0, 10) }, { archetype = "Rifleman", at = Vector3.new(112, 0, 76) },
	{ archetype = "Shieldbearer", at = Vector3.new(186, 0, 12) }, { archetype = "Ronin", at = Vector3.new(198, 0, 70) },
	{ archetype = "Oni", at = Vector3.new(140, 0, -24) },
	{ archetype = "Shinobi", at = Vector3.new(-150, 0, -180) }, { archetype = "Ronin", at = Vector3.new(-220, 0, -160) },
	{ archetype = "Ronin", at = Vector3.new(150, 0, -160) }, { archetype = "Shinobi", at = Vector3.new(180, 0, -128) },
	{ archetype = "Oni", at = Vector3.new(-40, 30, 138) }, { archetype = "Oni", at = Vector3.new(40, 30, 138) },
	{ archetype = "Rifleman", at = Vector3.new(-96, 30, 152) }, { archetype = "Rifleman", at = Vector3.new(82, 30, 168) },
} :: { { archetype: string, at: Vector3 } }

return HanamiConfig
