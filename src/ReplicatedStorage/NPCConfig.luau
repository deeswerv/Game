--!strict
-- NPC archetypes. Adding an enemy type is a table entry; the AI reads everything from
-- here so no behaviour is hardcoded per enemy.
--
-- The names the design talks in -- DetectionRange, MovementSpeed -- are accepted as
-- aliases for the fields this file has always used (AggroRange, WalkSpeed), so either
-- spelling works in an archetype and nothing that already reads the old names breaks.

local NPCConfig = {}

NPCConfig.Defaults = {
	DisplayName = "Enemy",
	Faction = "Hostile",        -- Hostile fights Players and Guard; Guard fights Hostile
	MaxHealth = 100,
	WalkSpeed = 12,             -- full running pace; patrols walk at a fraction of it
	Damage = 10,                -- per round for guns, per swing for melee
	AttackRange = 6,
	AttackCooldown = 1.2,       -- melee: rest between swings, on top of the swing itself
	AggroRange = 55,            -- how far it can notice a target (DetectionRange)
	DeaggroRange = 90,          -- gives up past this
	RequiresLineOfSight = true,
	LeashRange = 120,           -- returns home if dragged further than this
	-- Slow on purpose: a cleared camp should STAY cleared long enough to feel like you won
	-- it, not refill behind you while you are still reloading.
	RespawnTime = 50,
	CoinReward = 15,
	XPReward = 15,              -- read by LevelSystem off the model; same default as before
	LootTier = "Common",        -- a label for designers; LootProfile does the rolling
	Colour = Color3.fromRGB(150, 60, 60),
	NameColour = Color3.fromRGB(255, 120, 120),
	-- Ranged enemies fire instead of closing to melee.
	Ranged = false,
	ProjectileSpeed = 180,

	-- The weapon it carries, by name in ReplicatedStorage.storeitems. It is equipped as a
	-- real Tool so the weapon pose, reload and muzzle effects the players use all apply,
	-- and it is what it can drop when killed.
	Weapon = nil,
	Secondary = nil,            -- a sidearm it swaps to when the primary runs dry up close
	SwitchRange = 30,
	DropChance = 0.35,

	-- --------------------------------------------------------------- combat --
	-- How it fights. Every number here is read by the AI modules; none of it is hardcoded.
	Behaviour = "Balanced",     -- Aggressive | Balanced | Keeper | Brawler | Tactical
	Accuracy = 0.5,             -- 0..1, mapped onto an aim cone; nobody is perfect
	HeadAimChance = 0,          -- how often it deliberately aims for the head
	ReactionTime = 0.45,        -- first sighting -> weapon up. Elites are faster.
	AimTime = 0.25,             -- weapon up -> first shot
	FieldOfView = 150,          -- degrees; outside it, only HearingRange notices you
	HearingRange = 14,
	MemoryTime = 6,             -- how long a last known position stays worth chasing
	SearchTime = 9,             -- how long it hunts before giving up
	Armor = 0,                  -- flat reduction per hit (see KillCredit.Mitigate)
	HitReactScale = 1,          -- < 1 needs bigger hits to flinch; Brutes shrug off chip
	Aggression = 0.5,           -- 0..1: pushes vs holds, how readily it takes cover
	RetreatHealth = 0.25,       -- falls back once below this fraction (0 = never)
	UsesCover = false,
	PreferredRange = nil,       -- ranged: the distance it tries to fight from
	RepositionShots = nil,      -- ranged: shots from one spot before it moves
	Burst = { 1, 1 },           -- rounds per trigger pull
	BurstPause = { 0.4, 0.7 },  -- seconds between bursts
	ReloadThreshold = 0.3,      -- out of a fight, tops up below this fraction
	MeleeWindup = 0.3,
	MeleeRecover = 0.35,
	HeavySwing = false,
	PatrolRadius = 14,          -- 0 stands at its post
	Personality = 0.1,          -- +/- spread applied per spawn so no two are identical

	-- ------------------------------------------------------------- tactics --
	-- Read by AI.Tactics.
	Voice = "Soldier",          -- which set of callouts it shouts (Soldier/Bandit/Guard/Brute)
	Grenades = 0,               -- carried per life; thrown at targets hiding or camping
	GrenadeDamage = 45,         -- at the centre, falling off to the edge; scales with level
	GrenadeRadius = 14,
	GrenadeRange = 60,
	GrenadeCooldown = 14,
	Medkits = 0,                -- bandages per life: hurt and out of sight, it patches up
	Strafe = false,             -- sidesteps between bursts while holding its ground

	-- Look. Kept as data so a new enemy type is still just a table entry: body colours,
	-- an overall size, and a few welded blocks that say what it is at a glance.
	Skin = Color3.fromRGB(198, 164, 128),
	Shirt = Color3.fromRGB(90, 92, 100),
	Pants = Color3.fromRGB(58, 60, 68),
	Boots = nil,                -- defaults to a darker Pants
	Sleeves = false,            -- true colours the upper arms with the shirt
	Scale = 1,
	Accents = {},               -- { part = R15 part name, size, offset, colour }
}

NPCConfig.Archetypes = {
	-- Fast, close in, and usually carries a knife -- sometimes a cheap pistol instead. Hood
	-- and mask read as "rogue" instantly.
	Grunt = {
		DisplayName = "Bandit",
		Voice = "Bandit",
		Strafe = true,
		RespawnTime = 50,
		MaxHealth = 90,
		WalkSpeed = 15,
		Damage = 9,
		AttackRange = 6,
		AttackCooldown = 0.9,
		AggroRange = 55,
		CoinReward = 12,
		XPReward = 15,
		Colour = Color3.fromRGB(150, 70, 60),
		Weapon = "Fang",
		DropChance = 0.3,
		Behaviour = "Aggressive",
		Accuracy = 0.35,
		ReactionTime = 0.55,
		AimTime = 0.3,
		FieldOfView = 140,
		Aggression = 0.9,
		RetreatHealth = 0,
		MeleeWindup = 0.28,
		MeleeRecover = 0.35,
		-- One in three trades the knife for a pistol and fights at short range instead.
		Loadout = {
			{ weight = 65 },
			{ weight = 35, Weapon = "Vantage", Ranged = true, AttackRange = 42,
			  PreferredRange = 16, Damage = 6, Burst = { 1, 2 }, BurstPause = { 0.5, 0.85 },
			  DropChance = 0.2 },
		},
		Skin = Color3.fromRGB(190, 152, 118),
		Shirt = Color3.fromRGB(96, 46, 44),
		Pants = Color3.fromRGB(52, 40, 38),
		Accents = {
			{ part = "Head", size = Vector3.new(1.34, 0.5, 1.34), offset = Vector3.new(0, 0.42, 0.04),
			  colour = Color3.fromRGB(72, 34, 34) },                       -- hood
			{ part = "Head", size = Vector3.new(1.26, 0.4, 0.3), offset = Vector3.new(0, -0.14, -0.52),
			  colour = Color3.fromRGB(38, 34, 34) },                       -- mask over the face
			{ part = "UpperTorso", size = Vector3.new(1.9, 0.28, 1.2), offset = Vector3.new(0, 0.32, 0),
			  colour = Color3.fromRGB(64, 44, 38) },                       -- bandolier
		},
	},

	-- The rank and file. An assault rifle, a sidearm, bursts rather than a hose, and the
	-- sense to get behind something when it starts taking hits.
	Soldier = {
		DisplayName = "Soldier",
		MaxHealth = 150,
		WalkSpeed = 14,
		Damage = 5,
		Ranged = true,
		AttackRange = 75,
		PreferredRange = 34,
		AggroRange = 80,
		DeaggroRange = 120,
		CoinReward = 22,
		XPReward = 25,
		RespawnTime = 70,
		Grenades = 1,
		Medkits = 1,
		Strafe = true,
		Colour = Color3.fromRGB(96, 104, 76),
		NameColour = Color3.fromRGB(226, 214, 160),
		Weapon = "Redwood",
		Secondary = "Vantage",
		DropChance = 0.1,
		Behaviour = "Balanced",
		Accuracy = 0.55,
		ReactionTime = 0.42,
		AimTime = 0.22,
		UsesCover = true,
		Burst = { 3, 5 },
		BurstPause = { 0.45, 0.8 },
		Aggression = 0.55,
		RetreatHealth = 0.3,
		Armor = 1,
		Skin = Color3.fromRGB(186, 150, 118),
		Shirt = Color3.fromRGB(104, 110, 80),
		Pants = Color3.fromRGB(70, 74, 56),
		Sleeves = true,
		Accents = {
			{ part = "Head", size = Vector3.new(1.36, 0.46, 1.36), offset = Vector3.new(0, 0.47, 0),
			  colour = Color3.fromRGB(78, 84, 60) },                       -- helmet
			{ part = "UpperTorso", size = Vector3.new(1.94, 1.2, 1.24), offset = Vector3.new(0, -0.05, 0),
			  colour = Color3.fromRGB(88, 92, 70) },                       -- vest
		},
	},

	-- Slow, heavy, and swings a warhammer. Oversized and armoured so it reads as a threat
	-- from across the map, and chip damage barely makes it flinch.
	Brute = {
		DisplayName = "Brute",
		MaxHealth = 260,
		WalkSpeed = 10,
		Damage = 22,
		AttackRange = 8.5,
		AttackCooldown = 1.8,
		AggroRange = 50,
		DeaggroRange = 110,          -- it commits once it has seen you
		CoinReward = 40,
		XPReward = 40,
		RespawnTime = 100,
		Voice = "Brute",
		Colour = Color3.fromRGB(96, 52, 52),
		NameColour = Color3.fromRGB(255, 90, 90),
		Weapon = "Ironjaw",
		DropChance = 0.22,
		Scale = 1.35,
		Behaviour = "Brawler",
		Armor = 3,
		HitReactScale = 0.45,
		ReactionTime = 0.6,
		Aggression = 1,
		RetreatHealth = 0,
		MeleeWindup = 0.5,
		MeleeRecover = 0.55,
		HeavySwing = true,
		Skin = Color3.fromRGB(156, 118, 96),
		Shirt = Color3.fromRGB(74, 40, 40),
		Pants = Color3.fromRGB(46, 30, 30),
		Accents = {
			{ part = "Head", size = Vector3.new(1.36, 0.62, 1.36), offset = Vector3.new(0, 0.38, 0),
			  colour = Color3.fromRGB(58, 56, 62) },                       -- iron helm
			{ part = "UpperTorso", size = Vector3.new(2.0, 1.1, 1.3), offset = Vector3.new(0, 0.15, 0),
			  colour = Color3.fromRGB(66, 64, 70) },                       -- chest plate
			{ part = "LeftUpperArm", size = Vector3.new(0.8, 0.5, 0.95), offset = Vector3.new(0, 0.38, 0),
			  colour = Color3.fromRGB(58, 56, 62) },                       -- pauldrons
			{ part = "RightUpperArm", size = Vector3.new(0.8, 0.5, 0.95), offset = Vector3.new(0, 0.38, 0),
			  colour = Color3.fromRGB(58, 56, 62) },
		},
	},

	-- Keeps its distance and takes slow, deliberate shots. Looks for long sightlines, gives
	-- ground when rushed, and does not stay in one spot for long.
	Marksman = {
		DisplayName = "Marksman",
		RespawnTime = 75,
		Medkits = 1,
		MaxHealth = 70,
		WalkSpeed = 11,
		Damage = 14,
		Ranged = true,
		AttackRange = 95,
		AggroRange = 95,
		DeaggroRange = 130,
		-- Holds its ground instead of closing: it fights at a range no melee enemy would.
		PreferredRange = 55,
		RepositionShots = 4,
		CoinReward = 25,
		XPReward = 22,
		Colour = Color3.fromRGB(70, 90, 130),
		NameColour = Color3.fromRGB(140, 190, 255),
		Weapon = "Kestrel",
		DropChance = 0.28,
		Behaviour = "Keeper",
		Accuracy = 0.86,
		HeadAimChance = 0.18,
		ReactionTime = 0.65,
		AimTime = 0.55,
		Burst = { 1, 1 },
		BurstPause = { 1.4, 2.0 },
		Aggression = 0.25,
		RetreatHealth = 0.45,
		Skin = Color3.fromRGB(202, 168, 132),
		Shirt = Color3.fromRGB(62, 74, 92),
		Pants = Color3.fromRGB(44, 52, 64),
		Sleeves = true,
		Accents = {
			{ part = "Head", size = Vector3.new(1.3, 0.3, 1.3), offset = Vector3.new(0, 0.5, 0),
			  colour = Color3.fromRGB(48, 58, 74) },                       -- cap
			{ part = "Head", size = Vector3.new(1.2, 0.12, 0.5), offset = Vector3.new(0, 0.4, -0.72),
			  colour = Color3.fromRGB(48, 58, 74) },                       -- peak
			{ part = "UpperTorso", size = Vector3.new(1.92, 1.0, 1.22), offset = Vector3.new(0, -0.1, 0),
			  colour = Color3.fromRGB(74, 88, 108) },                      -- webbing vest
		},
	},

	-- The dangerous one. A top-tier rifle, fast reactions, uses cover, flanks, and reloads
	-- when it is safe to rather than when it is empty.
	Elite = {
		DisplayName = "Elite",
		NeverElite = true,           -- an Elite that also rolls "Veteran" would be absurd
		MaxHealth = 230,
		WalkSpeed = 15,
		Damage = 8,
		Ranged = true,
		AttackRange = 85,
		PreferredRange = 38,
		AggroRange = 95,
		DeaggroRange = 140,
		LeashRange = 150,
		CoinReward = 60,
		XPReward = 60,
		RespawnTime = 180,
		Grenades = 2,
		GrenadeCooldown = 10,
		Medkits = 1,
		Strafe = true,
		Colour = Color3.fromRGB(40, 44, 52),
		NameColour = Color3.fromRGB(196, 226, 255),
		Weapon = "Warden",
		Secondary = "Sentinel",
		DropChance = 0.05,
		Behaviour = "Tactical",
		Accuracy = 0.78,
		HeadAimChance = 0.1,
		ReactionTime = 0.25,
		AimTime = 0.14,
		FieldOfView = 170,
		UsesCover = true,
		Burst = { 3, 6 },
		BurstPause = { 0.3, 0.55 },
		Aggression = 0.6,
		RetreatHealth = 0.3,
		ReloadThreshold = 0.5,
		Armor = 2,
		Skin = Color3.fromRGB(176, 140, 112),
		Shirt = Color3.fromRGB(42, 46, 54),
		Pants = Color3.fromRGB(34, 36, 42),
		Sleeves = true,
		Accents = {
			{ part = "Head", size = Vector3.new(1.36, 0.5, 1.36), offset = Vector3.new(0, 0.45, 0),
			  colour = Color3.fromRGB(26, 28, 34) },                       -- helmet
			{ part = "Head", size = Vector3.new(1.1, 0.26, 0.2), offset = Vector3.new(0, 0.06, -0.6),
			  colour = Color3.fromRGB(60, 150, 170) },                     -- visor
			{ part = "UpperTorso", size = Vector3.new(1.96, 1.25, 1.26), offset = Vector3.new(0, -0.05, 0),
			  colour = Color3.fromRGB(30, 32, 38) },                       -- plate carrier
		},
	},

	-- Friendly patrol that fights Hostiles; proves NPC-vs-NPC combat. Now actually fires the
	-- pistol it carries rather than walking up and clubbing with it.
	Guard = {
		DisplayName = "Town Guard",
		Faction = "Guard",
		MaxHealth = 180,
		WalkSpeed = 12,
		Damage = 8,
		Ranged = true,
		AttackRange = 55,
		PreferredRange = 24,
		AggroRange = 60,
		CoinReward = 0,
		RespawnTime = 45,
		Voice = "Guard",
		Medkits = 1,
		Strafe = true,
		Colour = Color3.fromRGB(80, 110, 90),
		NameColour = Color3.fromRGB(140, 230, 160),
		Weapon = "Vantage",
		DropChance = 0.15,
		Behaviour = "Balanced",
		Accuracy = 0.6,
		ReactionTime = 0.4,
		UsesCover = true,
		Burst = { 1, 2 },
		BurstPause = { 0.5, 0.9 },
		Aggression = 0.5,
		Skin = Color3.fromRGB(196, 160, 124),
		Shirt = Color3.fromRGB(66, 88, 72),
		Pants = Color3.fromRGB(44, 58, 48),
		Sleeves = true,
		Accents = {
			{ part = "Head", size = Vector3.new(1.34, 0.42, 1.34), offset = Vector3.new(0, 0.48, 0),
			  colour = Color3.fromRGB(120, 124, 118) },                    -- helmet
			{ part = "UpperTorso", size = Vector3.new(1.9, 1.3, 1.2), offset = Vector3.new(0, -0.1, 0),
			  colour = Color3.fromRGB(96, 118, 100) },                     -- tabard
		},
	},

	-- Zone bosses. One per island, standing at a landmark rather than wandering: a boss you
	-- can bump into by accident is just a very hard Bandit. Stats are deliberately far
	-- above an elite of the same zone so the fight reads as a different category, not a
	-- longer version of the same one.
	Warlord = {
		DisplayName = "Warlord",
		Voice = "Brute",
		-- A boss must not ALSO roll elite: its difficulty would then depend on a coin
		-- flip, and two Warlords of the same zone would not be the same fight.
		NeverElite = true,
		-- Sized against the weapon that will actually shoot it. A Warden does 24 a body
		-- shot, so 900 base becomes ~1550 at the Flats ceiling and ~2200 at the Reach's:
		-- roughly 65-90 body shots, or 32-46 headshots. The first pass used 2400, which
		-- the level curve turned into 5856 -- over 240 body shots, a slog rather than a
		-- fight.
		MaxHealth = 900,
		WalkSpeed = 11,
		Damage = 34,
		AttackRange = 9,
		AttackCooldown = 1.4,
		AggroRange = 90,
		DeaggroRange = 160,
		LeashRange = 150,
		RespawnTime = 900,
		CoinReward = 1200,
		XPReward = 400,
		Colour = Color3.fromRGB(120, 40, 40),
		NameColour = Color3.fromRGB(255, 96, 96),
		Weapon = "Ironjaw",
		DropChance = 1.0,
		Scale = 1.35,
		Behaviour = "Brawler",
		-- No armour: the shot counts above were tuned against the raw Warden number, and
		-- flat armour would quietly add a fifth to every one of them.
		Armor = 0,
		HitReactScale = 0.3,
		ReactionTime = 0.3,
		Aggression = 1,
		RetreatHealth = 0,
		MeleeWindup = 0.55,
		MeleeRecover = 0.6,
		HeavySwing = true,
		PatrolRadius = 0,
		Personality = 0,
		Skin = Color3.fromRGB(148, 116, 96),
		Shirt = Color3.fromRGB(58, 30, 34),
		Pants = Color3.fromRGB(38, 22, 26),
	},
}

-- Which factions attack which.
NPCConfig.Hostility = {
	Hostile = { Player = true, Guard = true },
	Guard = { Hostile = true },
}

-- Spawn points: the Flats battleground (CoverService.Flats), the stone courtyard between
-- Map 2's pillars, centred on (-573, 1.5, 88). The raiders hold their camp in the west, the
-- town guard its post in the east; Flats.Posts has the same points in the battleground's own
-- coordinates, and tools/uitest/flats.luau checks the two agree and that every post has room.
-- NPCService drops them in from three studs up, so y = 1 lands them on the slab.
--
-- Six raiders, not eight: the camp is meant to be cleared and to stay cleared for a while.
-- The front lines start ~45 studs apart, inside everyone's aggro range, so they actually
-- fight; the Marksman and the Elite sit back in the camp.
--
-- Parts tagged "NPCSpawn" with an Archetype attribute (and optionally Count) are spawned
-- too, so new posts can be placed in Studio without touching this table.
NPCConfig.Spawns = {
	-- The raider camp, west.
	{ archetype = "Brute",    position = Vector3.new(-595, 1, 88) },
	{ archetype = "Grunt",    position = Vector3.new(-599, 1, 68) },
	{ archetype = "Grunt",    position = Vector3.new(-599, 1, 108) },
	{ archetype = "Marksman", position = Vector3.new(-611, 1, 72) },
	{ archetype = "Soldier",  position = Vector3.new(-605, 1, 67) },
	{ archetype = "Elite",    position = Vector3.new(-611, 1, 105) },

	-- The guard post, east.
	{ archetype = "Guard",    position = Vector3.new(-545, 1, 77) },
	{ archetype = "Guard",    position = Vector3.new(-545, 1, 99) },
	{ archetype = "Guard",    position = Vector3.new(-540, 1, 88) },
}

-- How the population is kept in bounds. A respawn that finds the world full, or a player
-- standing on the spot, waits and tries again rather than piling in.
NPCConfig.SpawnRules = {
	MaxAlive = 24,               -- across the whole server, bosses and adds included
	MinPlayerDistance = 45,      -- never appears right in front of a living player
	RetryDelay = 4,
	MaxRetries = 45,             -- three minutes of quick retries, then every 15 seconds
	Clearance = Vector3.new(3, 5, 3),
}

-- -------------------------------------------------------------------- zones --
--
-- Where an enemy stands is what decides how dangerous it is, so a spawn entry never has
-- to state a level. The bounds are the world's real walkable regions, measured rather than
-- guessed: the harbour the player spawns on, the flats across the water, and the town.
--
-- This is what gives the map a direction to travel in -- walk west and things get harder.
-- `level` is { normal, ceiling }. Ordinary enemies take the first number; the headroom is
-- there for elites and named enemies to sit in later without moving the zone.
NPCConfig.Zones = {
	{ id = "Harbour", name = "The Harbour", minX = -380, maxX = -46,  minZ = -87, maxZ = 321, level = { 1, 2 } },
	{ id = "Flats",   name = "The Flats",   minX = -753, maxX = -381, minZ = -87, maxZ = 321, level = { 3, 5 } },
	{ id = "Reach",   name = "The Reach",   minX = -56,  maxX = 436,  minZ = 44,  maxZ = 560, level = { 6, 9 } },
	-- The Downtown district in the sky (DistrictService); only turf-war crews ever stand here.
	{ id = "Downtown", name = "Downtown",   minX = -355, maxX = 45,   minZ = 1300, maxZ = 1700, level = { 4, 7 } },
}

-- Anywhere not inside a zone is treated as starter ground rather than erroring.
NPCConfig.DefaultZoneLevel = { 1, 2 }

function NPCConfig.ZoneAt(position: Vector3)
	for _, z in ipairs(NPCConfig.Zones) do
		if position.X >= z.minX and position.X <= z.maxX
			and position.Z >= z.minZ and position.Z <= z.maxZ then
			return z
		end
	end
	return nil
end

-- Level comes from the ZONE alone, never from the archetype. A Brute already has three
-- times a Grunt's health and twice its damage; adding an archetype rank on top of that
-- counts the same difficulty twice and sent the Brute to 541 health in a level 4-7 zone.
-- A level 3 Brute and a level 3 Grunt are both level 3 -- one is simply a worse thing to
-- meet, which is what the base stats already say.
function NPCConfig.LevelFor(archetype: string, position: Vector3): number
	local zone = NPCConfig.ZoneAt(position)
	local range = zone and zone.level or NPCConfig.DefaultZoneLevel
	return range[1]
end

local cache = {}

function NPCConfig.Get(name: string)
	if cache[name] then
		return cache[name]
	end
	local entry = NPCConfig.Archetypes[name]
	if not entry then
		return nil
	end
	local merged = {}
	for k, v in pairs(NPCConfig.Defaults) do
		merged[k] = v
	end
	for k, v in pairs(entry) do
		merged[k] = v
	end
	-- The design vocabulary, accepted either way round.
	if entry.DetectionRange then
		merged.AggroRange = entry.DetectionRange
	end
	if entry.MovementSpeed then
		merged.WalkSpeed = entry.MovementSpeed
	end
	merged.DetectionRange = merged.AggroRange
	merged.MovementSpeed = merged.WalkSpeed
	merged.Archetype = name
	cache[name] = merged
	return merged
end

-- Per level above the first. Deliberately gentle: a level 12 Brute should be a real fight,
-- not a different species, and health climbing faster than damage keeps a high-level enemy
-- something you can still out-play rather than something that one-shots you.
local HEALTH_PER_LEVEL = 0.18
local DAMAGE_PER_LEVEL = 0.12
local REWARD_PER_LEVEL = 0.25
-- Aim improves slowly and caps well short of perfect, and armour grows only a little: the
-- point of a higher level is a longer, sharper fight, not an enemy that never misses.
local ACCURACY_PER_LEVEL = 0.012
local ACCURACY_CAP = 0.92
local ARMOR_PER_LEVEL = 0.08

-- Returns a COPY with its stats scaled for `level`. Never mutates the cached archetype --
-- Get hands out one shared table per archetype, so scaling it in place would level up
-- every enemy of that type in the world, permanently, every time one spawned.
function NPCConfig.Levelled(cfg, level: number)
	local out = {}
	for k, v in pairs(cfg) do
		out[k] = v
	end
	local steps = math.max(0, level - 1)
	out.Level = level
	out.MaxHealth = math.floor(cfg.MaxHealth * (1 + HEALTH_PER_LEVEL * steps) + 0.5)
	out.Damage = cfg.Damage * (1 + DAMAGE_PER_LEVEL * steps)
	out.GrenadeDamage = (cfg.GrenadeDamage or 0) * (1 + DAMAGE_PER_LEVEL * steps)
	out.CoinReward = math.floor(cfg.CoinReward * (1 + REWARD_PER_LEVEL * steps) + 0.5)
	out.XPReward = math.floor((cfg.XPReward or 15) * (1 + REWARD_PER_LEVEL * steps) + 0.5)
	out.Accuracy = math.min(ACCURACY_CAP, (cfg.Accuracy or 0.5) + ACCURACY_PER_LEVEL * steps)
	out.Armor = (cfg.Armor or 0) * (1 + ARMOR_PER_LEVEL * steps)
	return out
end

-- -------------------------------------------------------------------- elites --
--
-- This is what the second number in a zone's `level` range was reserved for. An elite is
-- an ordinary archetype pushed to the zone ceiling and given one modifier, so no new enemy
-- types are needed and a Bandit stays a Bandit -- just the wrong Bandit to walk into.
--
-- The modifiers trade against each other rather than being strictly better, so an elite is
-- a different fight and not simply a longer one.
NPCConfig.EliteChance = 0.18
NPCConfig.EliteLootRolls = 2       -- extra rarity rolls, on top of the archetype's own
NPCConfig.EliteRewardMultiplier = 2.25
NPCConfig.EliteNameColour = Color3.fromRGB(255, 196, 92)

NPCConfig.EliteModifiers = {
	{ id = "Armoured", prefix = "Armoured", health = 1.85, damage = 1.00, speed = 0.88, armor = 3 },
	{ id = "Veteran",  prefix = "Veteran",  health = 1.30, damage = 1.35, speed = 1.00, reaction = 0.8 },
	{ id = "Quick",    prefix = "Quick",    health = 0.85, damage = 1.10, speed = 1.35, reaction = 0.7 },
	{ id = "Deadeye",  prefix = "Deadeye",  health = 1.00, damage = 1.50, speed = 0.95, accuracy = 0.12 },
}

--- The highest level a zone goes to. Elites sit here; ordinary enemies never do.
function NPCConfig.ZoneCeiling(position: Vector3): number
	local zone = NPCConfig.ZoneAt(position)
	local range = zone and zone.level or NPCConfig.DefaultZoneLevel
	return range[2]
end

function NPCConfig.RollElite(cfg): boolean
	if cfg and cfg.NeverElite then
		return false
	end
	return math.random() < NPCConfig.EliteChance
end

--- Turn a levelled config into an elite one. Takes and returns a COPY for the same reason
--- Levelled does: the archetype table from Get is shared.
function NPCConfig.MakeElite(cfg, modifier)
	local out = {}
	for k, v in pairs(cfg) do
		out[k] = v
	end
	out.Elite = true
	out.EliteId = modifier.id
	out.DisplayName = modifier.prefix .. " " .. cfg.DisplayName
	out.MaxHealth = math.floor(cfg.MaxHealth * modifier.health + 0.5)
	out.Damage = cfg.Damage * modifier.damage
	out.WalkSpeed = cfg.WalkSpeed * modifier.speed
	out.CoinReward = math.floor(cfg.CoinReward * NPCConfig.EliteRewardMultiplier + 0.5)
	out.XPReward = math.floor((cfg.XPReward or 15) * NPCConfig.EliteRewardMultiplier + 0.5)
	out.NameColour = NPCConfig.EliteNameColour
	if modifier.armor then
		out.Armor = (cfg.Armor or 0) + modifier.armor
	end
	if modifier.reaction then
		out.ReactionTime = (cfg.ReactionTime or 0.45) * modifier.reaction
	end
	if modifier.accuracy then
		out.Accuracy = math.min(ACCURACY_CAP, (cfg.Accuracy or 0.5) + modifier.accuracy)
	end
	return out
end

-- -------------------------------------------------------------- individuals --

--- Pick one of an archetype's weapon loadouts, weighted. Returns a COPY with that
--- loadout's fields folded in, or `cfg` itself when it has none.
function NPCConfig.ResolveLoadout(cfg)
	local options = cfg.Loadout
	if type(options) ~= "table" or #options == 0 then
		return cfg
	end
	local total = 0
	for _, option in ipairs(options) do
		total += option.weight or 1
	end
	local roll = math.random() * total
	for _, option in ipairs(options) do
		roll -= option.weight or 1
		if roll <= 0 then
			local out = table.clone(cfg)
			for k, v in pairs(option) do
				if k ~= "weight" then
					out[k] = v
				end
			end
			out.Loadout = nil
			return out
		end
	end
	return cfg
end

--- Small, bounded differences so a squad of Soldiers is a squad of people. Returns a COPY.
--- Nothing moves by more than `Personality` of its value, so balance holds on average.
function NPCConfig.Personalise(cfg)
	local spread = cfg.Personality or 0
	if spread <= 0 then
		return cfg
	end
	local function vary(value: number?, amount: number): number?
		if type(value) ~= "number" then
			return value
		end
		return value * (1 + (math.random() * 2 - 1) * amount)
	end
	local out = table.clone(cfg)
	out.AggroRange = vary(cfg.AggroRange, spread)
	out.Accuracy = math.clamp(vary(cfg.Accuracy, spread * 0.6) :: number, 0.05, ACCURACY_CAP)
	out.ReactionTime = math.max(0.12, vary(cfg.ReactionTime, spread * 2) :: number)
	out.Aggression = math.clamp(vary(cfg.Aggression, spread * 1.5) :: number, 0, 1)
	out.WalkSpeed = vary(cfg.WalkSpeed, spread * 0.5)
	out.PreferredRange = vary(cfg.PreferredRange, spread * 1.5)
	out.AttackRange = vary(cfg.AttackRange, spread * 0.3)
	out.ReloadThreshold = math.clamp(vary(cfg.ReloadThreshold, spread * 3) :: number, 0.05, 0.7)
	return out
end

-- --------------------------------------------------------------- reputation --
--
-- Killing something moves your standing with the factions that cared about it. Keyed by
-- the VICTIM's faction, then by whose opinion changes.
--
-- The asymmetry is the point: clearing bandits earns the town's regard slowly, and killing
-- a Town Guard costs you far more than a bandit ever earned. Seven bandits to undo one
-- guard is what makes turning on the town a decision rather than an experiment.
NPCConfig.ReputationOnKill = {
	Hostile = { Guard = 2 },
	Guard   = { Guard = -15, Hostile = 4 },
}

-- --------------------------------------------------------------------- loot --
--
-- Reuses the CHEST rarity vocabulary on purpose (ChestConfig.RarityOrder / Contents /
-- RollKind) rather than inventing a second one, so "Rare" means the same thing whether it
-- came off a body or out of a crate. What differs is how OFTEN: a chest is a reward you
-- went looking for, a bandit is routine, so these odds are far stingier and the payouts
-- well below a chest's for the same tier.
--
-- This is IN ADDITION to the weapon an NPC drops; it does not replace it.
local ChestConfig = require(script.Parent.ChestConfig)

NPCConfig.LootRarity = {
	Common = 0.66,
	Uncommon = 0.22,
	Rare = 0.09,
	Epic = 0.028,
	Legendary = 0.002,
}

-- How often a kill drops anything, and how many rarity rolls it keeps the best of. Extra
-- rolls are what make a Brute worth killing without giving it its own loot table.
NPCConfig.LootProfile = {
	Grunt    = { chance = 0.28, rolls = 1 },
	Guard    = { chance = 0.28, rolls = 1 },
	Soldier  = { chance = 0.32, rolls = 2 },
	Marksman = { chance = 0.36, rolls = 2 },
	Brute    = { chance = 0.55, rolls = 3 },
	Elite    = { chance = 0.6,  rolls = 3 },
}
NPCConfig.DefaultLootProfile = { chance = 0.25, rolls = 1 }

NPCConfig.LootCoins = {
	Common    = { 6, 14 },
	Uncommon  = { 15, 30 },
	Rare      = { 30, 60 },
	Epic      = { 60, 120 },
	Legendary = { 120, 260 },
}

-- NOTE: ChestConfig.RarityOrder runs RAREST FIRST -- index 1 is Legendary, index 5 is
-- Common. So the BEST of several rolls is the LOWEST index, not the highest. Getting this
-- backwards is silent and looks plausible: every tier still appears at a believable rate,
-- it is only the "best of N" that inverts, and a Brute ends up 96% Common while a Grunt
-- sits at 66%.
local WORST_TIER_INDEX = #ChestConfig.RarityOrder

-- Index into RarityOrder for one roll.
local function rollTierIndex(): number
	local roll = math.random()
	local floor = 0
	for i, tier in ipairs(ChestConfig.RarityOrder) do
		floor += NPCConfig.LootRarity[tier] or 0
		if roll <= floor then
			return i
		end
	end
	return WORST_TIER_INDEX
end

--- Roll what a kill drops, or nil for nothing. `cfg` is the LEVELLED config, so a higher
--- level enemy buys extra rolls and therefore better tiers, not just more health.
function NPCConfig.RollLoot(cfg): { tier: string, kind: string }?
	local profile = NPCConfig.LootProfile[cfg.Archetype] or NPCConfig.DefaultLootProfile
	if math.random() > profile.chance then
		return nil
	end
	local rolls = profile.rolls + math.floor((cfg.Level or 1) / 4)
		+ (cfg.Elite and NPCConfig.EliteLootRolls or 0)
	local best = WORST_TIER_INDEX
	for _ = 1, math.max(1, rolls) do
		local idx = rollTierIndex()
		if idx < best then
			best = idx
		end
	end
	local tier = ChestConfig.RarityOrder[best] or "Common"
	return { tier = tier, kind = ChestConfig.RollKind(tier) }
end

--- How many coins a `tier` payout is worth.
function NPCConfig.LootCoinAmount(tier: string): number
	local band = NPCConfig.LootCoins[tier] or NPCConfig.LootCoins.Common
	return math.random(band[1], band[2])
end

-- Does `a` attack `b`?
function NPCConfig.IsHostileTo(a: string, b: string): boolean
	local t = NPCConfig.Hostility[a]
	return t ~= nil and t[b] == true
end

-- ------------------------------------------------------- standing and steel --
--
-- Reputation used to be a number that moved vendor prices and nothing else, which made
-- killing a Town Guard a pricing decision rather than a choice. Below this standing, that
-- faction stops tolerating you: its NPCs add you to the list of things they shoot on sight,
-- and they stop the moment your standing climbs back over the line.
--
-- ReputationOnKill above sets the exchange rate: a guard costs 15, a bandit earns 2, so it
-- takes two dead guards to turn the town hostile and about fifteen bandits to be forgiven.
NPCConfig.HostileReputation = {
	Guard = -25,
}

--- Is `standing` low enough that `faction` treats the player as an enemy?
function NPCConfig.StandingIsHostile(faction: string, standing: number?): boolean
	local threshold = NPCConfig.HostileReputation[faction]
	return threshold ~= nil and (standing or 0) <= threshold
end

return NPCConfig
