--!strict
-- HANAMI VALLEY: the world past Downtown, opened by beating the Don at the top of ZEE TOWER.
--
-- One source of truth for where everything in it is, shared by the server (the builder in
-- HanamiService.Valley, the population and the fights in HanamiService, the quests) and the
-- client (the area titles, the boss bar). Everything is given in the valley's own frame --
-- X east, Z north, Y up from the valley floor -- and `At` turns it into a world position.
--
--                    north
--      +--------------------------------------+
--      |          KUROGANE KEEP (y 30)        |   the Shogun's stronghold on its plateau,
--      |       the Thousand Gates stair       |   reached by a stair of red torii
--      |--------------------------------------|
--      |  LANTERN ROW  |  square  | IRONWORKS |   dangerous streets / the foundry and docks
--      |~~~~~~~~~~~~ the river ~~~~~~~~~~~~~~~|
--      | BAMBOO HOLLOW |  HANAMURA |  PADDIES  |   the outskirts / the village / the outskirts
--      +--------------------------------------+
--                    south (you arrive here)

local HanamiConfig = {}

HanamiConfig.NAME = "HANAMI VALLEY"
HanamiConfig.FOLDER = "Hanami"
HanamiConfig.CENTRE = Vector3.new(1100, 1000, 1500)
HanamiConfig.HALF = 262                 -- the valley is 524 studs square
HanamiConfig.PLATEAU = 30               -- how high the keep stands over the valley floor
HanamiConfig.RIVER = { z0 = -86, z1 = -64, depth = 3.5 }

--- A point in the valley's frame, in the world.
function HanamiConfig.At(x: number, y: number, z: number): Vector3
	return HanamiConfig.CENTRE + Vector3.new(x, y, z)
end

--- A point in the world, in the valley's frame.
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
	{ id = "Hanamura", name = "HANAMURA", sub = "THE VILLAGE UNDER THE GREAT SAKURA", x0 = -98, x1 = 98, z0 = -258, z1 = -90,
	  safe = true, level = { 10, 10 } },
	{ id = "BambooHollow", name = "BAMBOO HOLLOW", sub = "THE OUTSKIRTS", x0 = -258, x1 = -98, z0 = -258, z1 = -90,
	  level = { 10, 12 } },
	{ id = "Paddies", name = "THE PADDIES", sub = "THE OUTSKIRTS", x0 = 98, x1 = 258, z0 = -258, z1 = -90,
	  level = { 10, 12 } },
	{ id = "LanternRow", name = "LANTERN ROW", sub = "KUROGANE STREETS", x0 = -258, x1 = -36, z0 = -62, z1 = 114,
	  level = { 11, 13 } },
	{ id = "Square", name = "THE CROSSROADS", sub = "THE ROAD TO THE KEEP", x0 = -36, x1 = 36, z0 = -62, z1 = 114,
	  level = { 11, 13 } },
	{ id = "Ironworks", name = "THE IRONWORKS", sub = "KUROGANE FOUNDRY & DOCKS", x0 = 36, x1 = 258, z0 = -62, z1 = 114,
	  level = { 12, 14 } },
	{ id = "Keep", name = "KUROGANE KEEP", sub = "THE SHOGUN'S STRONGHOLD", x0 = -140, x1 = 140, z0 = 114, z1 = 258,
	  y = 30, level = { 14, 16 } },
} :: { Area }

--- The area a valley-frame point is in, or nil.
function HanamiConfig.AreaAt(p: Vector3): Area?
	for _, a in ipairs(HanamiConfig.Areas) do
		if p.X >= a.x0 and p.X <= a.x1 and p.Z >= a.z0 and p.Z <= a.z1 then
			return a
		end
	end
	return nil
end

--- Is a world position inside the valley at all (and not far below or above it)?
function HanamiConfig.Inside(world: Vector3): boolean
	local p = HanamiConfig.Local(world)
	local h = HanamiConfig.HALF
	return math.abs(p.X) <= h and math.abs(p.Z) <= h and p.Y > -40 and p.Y < 200
end

-- Where things are (valley frame, on the ground). The builder puts the landmarks here; the
-- service, the quests and the tests read them from here, so nothing drifts apart.
HanamiConfig.Sites = {
	Arrival = Vector3.new(0, 0, -236),            -- the south gate: where Travel lands you
	GreatSakura = Vector3.new(0, 0, -168),        -- the village's tree
	Shrine = Vector3.new(0, 1.5, -128),           -- the shrine behind it
	Elder = Vector3.new(-9, 0, -139),             -- Elder Hoshi, at the foot of the shrine steps
	Captain = Vector3.new(-20, 0, -100),          -- Captain Rei, at the village end of the red bridge
	Merchant = Vector3.new(26, 0, -186),          -- the trader's stall, on the square
	Pagoda = Vector3.new(62, 0, -150),
	Teahouse = Vector3.new(-56, 0, -198),
	RedBridge = Vector3.new(0, 0, -75),           -- the arched bridge north out of the village
	WestBridge = Vector3.new(-160, 0, -75),
	EastBridge = Vector3.new(160, 0, -75),
	LanternGate = Vector3.new(-48, 0, 20),        -- the arch into Lantern Row
	IronGate = Vector3.new(48, 0, 20),            -- the yard gate into the Ironworks
	Foundry = Vector3.new(150, 0, 58),            -- the foundry yard: Foreman Tetsu
	Crane = Vector3.new(196, 0, -20),
	Camp = Vector3.new(-178, 0, -176),            -- the bandit camp in the bamboo
	Waterfall = Vector3.new(-246, 0, -110),
	Farmhouse = Vector3.new(176, 0, -186),        -- the farm the raiders come for
	StairFoot = Vector3.new(0, 0, 64),            -- the foot of the Thousand Gates
	KeepGate = Vector3.new(0, 30, 130),           -- the top of the stair, the keep's gate
	Court = Vector3.new(0, 30, 182),              -- the Shogun's court: the final fight
	Throne = Vector3.new(0, 30, 214),             -- where the Shogun waits
}

--- A site, in the world.
function HanamiConfig.Site(name: string): Vector3
	local p = HanamiConfig.Sites[name]
	assert(p, "no Hanami site " .. name)
	return HanamiConfig.CENTRE + p
end

-- The court's floor: the final fight happens inside this box (valley frame).
HanamiConfig.CourtBox = { x0 = -72, x1 = 72, z0 = 144, z1 = 218 }

-- Missing villagers, held at the camp in the bamboo (the rescue job), and where they run to.
HanamiConfig.Captives = {
	Vector3.new(-186, 0, -168), Vector3.new(-170, 0, -186), Vector3.new(-192, 0, -190),
}

-- The ledger pages, the shipping tags and the furnace log: what the investigation finds in
-- the Ironworks. Each is a prop with an Inspect prompt.
HanamiConfig.Clues = {
	{ id = "Ledger", at = Vector3.new(112, 0, 30), title = "A burnt ledger",
	  text = "Weekly shipments \"to the Keep\" -- signed with an iron crest." },
	{ id = "Crate", at = Vector3.new(202, 0, -36), title = "Crates stamped ZEE",
	  text = "The Don's crates. He was only ever a supplier." },
	{ id = "Orders", at = Vector3.new(176, 0, 70), title = "Sealed orders",
	  text = "\"Raise the levy on Hanamura. -- S.\"" },
	{ id = "Map", at = Vector3.new(74, 0, -30), title = "A map of the Keep",
	  text = "The Thousand Gates lead straight to the Shogun's court." },
}

-- Iron seals the Kurogane use as passes, hidden round the valley's high and hidden places,
-- to find (the collection job). Each is reachable on foot.
HanamiConfig.Seals = {
	Vector3.new(-60, 16.5, -198),     -- on the teahouse's roof terrace (the stair round the back)
	Vector3.new(-170, 16.6, 86),      -- a Lantern Row roof terrace
	Vector3.new(192, 27, -16),        -- on the crane's walkway (the ladder up its leg)
	Vector3.new(-252, 0, -110),       -- in the nook behind the waterfall
	Vector3.new(240, 9.6, -240),      -- on top of the knoll in the paddies' far corner
}

-- Where the raiders come from when they hit the farm (the survival job), and how many waves.
HanamiConfig.Raid = {
	site = Vector3.new(176, 0, -186),
	radius = 34,
	waves = {
		{ "Ronin", "Ronin", "Ronin" },
		{ "Ronin", "Shinobi", "Shinobi", "Rifleman" },
		{ "Shieldbearer", "Ronin", "Shinobi", "Rifleman", "Juggernaut" },
	},
	from = { Vector3.new(246, 0, -150), Vector3.new(120, 0, -246), Vector3.new(246, 0, -246) },
}

-- Who lives where, while somebody is in the valley to meet them. Kept modest: a street of
-- four is a fight, a street of twelve is a wall.
HanamiConfig.Population = {
	{ archetype = "Ronin", at = Vector3.new(-120, 0, -10) }, { archetype = "Ronin", at = Vector3.new(-150, 0, 20) },
	{ archetype = "Shieldbearer", at = Vector3.new(-96, 0, 60) }, { archetype = "Rifleman", at = Vector3.new(-118, 16.6, 86) },
	{ archetype = "Shinobi", at = Vector3.new(-184, 0, -30) }, { archetype = "Ronin", at = Vector3.new(-200, 0, -30) },
	{ archetype = "Juggernaut", at = Vector3.new(120, 0, 10) }, { archetype = "Rifleman", at = Vector3.new(120, 0, 102) },
	{ archetype = "Shieldbearer", at = Vector3.new(190, 0, 40) }, { archetype = "Ronin", at = Vector3.new(220, 0, 80) },
	{ archetype = "Oni", at = Vector3.new(130, 0, -30) },
	{ archetype = "Shinobi", at = Vector3.new(-160, 0, -200) }, { archetype = "Ronin", at = Vector3.new(-200, 0, -150) },
	{ archetype = "Ronin", at = Vector3.new(150, 0, -150) }, { archetype = "Shinobi", at = Vector3.new(210, 0, -220) },
	{ archetype = "Oni", at = Vector3.new(-40, 30, 140) }, { archetype = "Oni", at = Vector3.new(40, 30, 140) },
	{ archetype = "Rifleman", at = Vector3.new(-110, 30, 160) }, { archetype = "Rifleman", at = Vector3.new(110, 30, 160) },
} :: { { archetype: string, at: Vector3 } }

return HanamiConfig
