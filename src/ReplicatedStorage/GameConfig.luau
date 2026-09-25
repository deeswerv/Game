--!strict
-- Single source of truth for the shop, abilities, progression and monetization.
--
-- The client reads this to draw menus; the server reads it to decide what a purchase
-- actually costs. Prices live here and ONLY here -- the old shop took the price from
-- the client, so anyone could buy for zero (or send a negative price and mint coins).

local GameConfig = {}

-- ---------------------------------------------------------------- progression --

GameConfig.Leveling = {
	-- XP awarded for a kill.
	XP_PER_PLAYER_KILL = 50,
	XP_PER_NPC_KILL = 15,
	-- A kill on someone above you is worth more; below you, less. Clamped either way.
	LEVEL_DIFF_BONUS = 0.08,
	MIN_XP_MULTIPLIER = 0.25,
	MAX_XP_MULTIPLIER = 3.0,

	STAT_POINTS_PER_LEVEL = 3,
	MAX_LEVEL = 100,

	-- Heal to full on level up -- a small reward that also reads clearly in combat.
	HEAL_ON_LEVEL_UP = true,

	-- XP from things other than kills. Progression that only moves when you shoot someone
	-- makes every other system in the game feel like a side activity.
	XP_PER_QUEST = 120,
	XP_PER_CHEST = { Common = 15, Uncommon = 30, Rare = 60, Epic = 110, Legendary = 200 },
}

-- ------------------------------------------------------------------ prestige --

GameConfig.Prestige = {
	-- Reaching the level cap unlocks the reset. Nothing happens automatically: prestiging
	-- is always the player's own decision, because it costs them their level.
	REQUIRED_LEVEL = 100,
	MAX_PRESTIGE = 10,

	-- Paid out each time, scaling with the prestige being entered.
	COIN_REWARD_BASE = 5000,
	COIN_REWARD_PER_PRESTIGE = 2500,

	-- What survives a prestige. Everything not listed here is reset.
	--
	-- Written as an explicit allow-list rather than a list of things to clear, so a field
	-- added to the save later is preserved by default. Getting this backwards is how a
	-- progression reset eats somebody's inventory.
	PRESERVE = {
		-- OwnedCamos is retired but still published: a client that has not reloaded its UI
		-- yet reads it, and sending an empty list is cheaper than a special case.
		"OwnedItems", "OwnedAbilities", "OwnedCamos", "OwnedAttachments", "OwnedVariants",
		"WeaponSkins", "WeaponAttachments", "WeaponBuilds", "EquippedBuild",
		"CompletedQuests", "TotalKills", "TotalDeaths", "TimePlayed",
		"Prestige", "LifetimeXP", "Inventory",
	},
}

-- Emblem shown beside a player's level. Deliberately a short ladder of materials rather
-- than ten unrelated designs: the shape stays constant so it is instantly recognisable at
-- HUD size, and only the metal and the ring change.
GameConfig.PrestigeTiers = {
	[0] = { name = "Recruit",   colour = Color3.fromRGB(150, 156, 168), ring = Color3.fromRGB(96, 102, 116), points = 0 },
	[1] = { name = "Bronze",    colour = Color3.fromRGB(198, 124, 68),  ring = Color3.fromRGB(140, 84, 42),  points = 3 },
	[2] = { name = "Silver",    colour = Color3.fromRGB(198, 206, 220), ring = Color3.fromRGB(138, 146, 162), points = 4 },
	[3] = { name = "Gold",      colour = Color3.fromRGB(240, 190, 84),  ring = Color3.fromRGB(176, 132, 44),  points = 5 },
	[4] = { name = "Platinum",  colour = Color3.fromRGB(146, 226, 226), ring = Color3.fromRGB(84, 158, 162),  points = 5 },
	[5] = { name = "Diamond",   colour = Color3.fromRGB(126, 200, 250), ring = Color3.fromRGB(66, 132, 196),  points = 6 },
	[6] = { name = "Onyx",      colour = Color3.fromRGB(96, 96, 112),   ring = Color3.fromRGB(196, 196, 214), points = 6 },
	[7] = { name = "Crimson",   colour = Color3.fromRGB(232, 84, 88),   ring = Color3.fromRGB(158, 44, 50),   points = 7 },
	[8] = { name = "Void",      colour = Color3.fromRGB(150, 106, 240), ring = Color3.fromRGB(94, 62, 168),   points = 7 },
	[9] = { name = "Radiant",   colour = Color3.fromRGB(255, 226, 150), ring = Color3.fromRGB(230, 168, 60),  points = 8 },
	[10] = { name = "Apex",     colour = Color3.fromRGB(255, 255, 255), ring = Color3.fromRGB(238, 190, 98),  points = 8 },
}

--- Emblem description for a prestige count, clamped so an out-of-range value still draws.
function GameConfig.GetPrestigeTier(prestige: number)
	local tiers = GameConfig.PrestigeTiers
	local n = math.clamp(math.floor(prestige or 0), 0, GameConfig.Prestige.MAX_PRESTIGE)
	return tiers[n] or tiers[0]
end

-- XP needed to go from `level` to `level + 1`.
function GameConfig.GetRequiredEXP(level: number): number
	return math.floor(100 * (level ^ 1.35))
end

-- ---------------------------------------------------------------------- shop --

-- Tools bought with in-game Coins. `item` must name a child of ReplicatedStorage.storeitems.
-- Everything here is a one-time purchase: once owned it is re-granted free on every spawn.
GameConfig.ShopItems = {
	{
		id = "BloodSword",
		name = "Blood Sword",
		desc = "A blade that drinks what it cuts. Heavier swing, deeper bite.",
		price = 250,
		item = "BloodSword",
		image = "rbxassetid://12653182981",
		levelRequired = 1,
	},
	{
		id = "Hornet",
		name = "Hornet",
		desc = "Automatic SMG. 30 rounds, high rate, low damage per shot.",
		price = 1400,
		item = "Hornet",
		image = "",
		levelRequired = 8,
	},
	{
		id = "Redwood",
		name = "Redwood",
		desc = "Automatic battle rifle. 30 rounds, scoped, hits hard at any range.",
		price = 4200,
		item = "Redwood",
		image = "",
		levelRequired = 16,
	},
	{
		id = "Carbine",
		name = "Carbine",
		desc = "Short-barrelled carbine. Accurate, controllable, and quietly expensive.",
		price = 9000,
		item = "Carbine",
		image = "",
		levelRequired = 25,
	},
	{
		id = "Warden",
		name = "Warden",
		desc = "Full-length rifle, optic already mounted. Nothing about it is a compromise.",
		price = 11500,
		item = "Warden",
		image = "",
		levelRequired = 30,
	},
	{
		id = "Blackwood",
		name = "Blackwood",
		desc = "Walnut and blued steel. Seven pellets a shell and a very short argument.",
		price = 6800,
		item = "Blackwood",
		image = "",
		levelRequired = 18,
	},
	{
		id = "Sentinel",
		name = "Sentinel",
		desc = "Railed service pistol. Fifteen rounds and no bad habits.",
		price = 2600,
		item = "Sentinel",
		image = "",
		levelRequired = 9,
	},
	{
		id = "Wasp",
		name = "Wasp",
		desc = "Machine pistol. No range, no manners, empties in two seconds.",
		price = 1800,
		item = "Wasp",
		image = "",
		levelRequired = 7,
	},
	{
		id = "Talon",
		name = "Talon",
		desc = "Hand cannon. Seven rounds, and every one of them means it.",
		price = 3600,
		item = "Talon",
		image = "",
		levelRequired = 14,
	},
	{
		id = "Kestrel",
		name = "Kestrel",
		desc = "Cut-down rifle. Rifle punch in something you can swing round a corner.",
		price = 5400,
		item = "Kestrel",
		image = "",
		levelRequired = 20,
	},
	{
		id = "Sparrow",
		name = "Sparrow",
		desc = "Compact submachine gun. Fast, close, and unfussy about range.",
		price = 3000,
		item = "Sparrow",
		image = "",
		levelRequired = 11,
	},
	{
		id = "Scattergun",
		name = "Scattergun",
		desc = "Eight pellets a shot. Lethal in a corridor, hopeless across a field.",
		price = 2200,
		item = "Scattergun",
		image = "",
		levelRequired = 11,
	},
	{
		id = "Fang",
		name = "Fang",
		desc = "Fast dagger. Backstabs deal triple damage.",
		price = 1100,
		item = "Fang",
		image = "",
		levelRequired = 6,
	},
	{
		id = "Ironjaw",
		name = "Ironjaw",
		desc = "Two-handed warhammer. Slow, enormous, launches whatever it hits.",
		price = 3000,
		item = "Ironjaw",
		image = "",
		levelRequired = 14,
	},
	{
		id = "Vantage",
		name = "Vantage",
		desc = "Semi-automatic sidearm. 12 rounds, R to reload, headshots hurt.",
		price = 800,
		item = "Vantage",
		image = "",
		levelRequired = 6,
	},
}

-- --------------------------------------------------------------- abilities --

-- Sold by the vendor NPC. These are stored on the profile and are one-time buys.
-- RETIRED 2026-09-18.
--
-- These ten abilities ran on bespoke scripts whose server remotes validated nothing: any
-- client could call BarrageSlash or DimensionBreak directly, without owning the ability or
-- even holding the sword, as often as it liked, and ragdoll anyone it reached.
-- AbilityService only disabled the LocalScript that bound the key, which stopped the honest
-- player and nobody else.
--
-- The definitions are kept here, not deleted, so a rebuilt server-authoritative ability
-- system can restore them by name. Nobody's OwnedAbilities data was touched.
GameConfig.RetiredAbilities = {
	{
		id = "BarrageSlash",
		name = "Barrage Slash",
		desc = "A flurry of cuts that ragdolls everything in front of you.",
		price = 300,
		levelRequired = 2,
		key = "E",
		script = "BarrageSlash",
		tools = { "Greatsword" },
		icon = "",
		color = Color3.fromRGB(235, 225, 200),
	},
	{
		id = "HeavenlyDash",
		name = "Heavenly Dash",
		desc = "Hold to aim, release to blink through anything in the way.",
		price = 600,
		levelRequired = 5,
		key = "Z",
		script = "HeavenlyDash",
		tools = { "Greatsword" },
		icon = "",
		color = Color3.fromRGB(120, 200, 255),
	},
	{
		id = "SwordSkyFall",
		name = "Sky Fall",
		desc = "Launch up and bring the blade down through the ground.",
		price = 1000,
		levelRequired = 8,
		key = "C",
		script = "SwordSkyFall",
		tools = { "Greatsword" },
		icon = "",
		color = Color3.fromRGB(255, 190, 90),
	},
	{
		id = "JudgementCut",
		name = "Judgement Cut",
		desc = "Charge, then tear the space around your target apart.",
		price = 1600,
		levelRequired = 12,
		key = "X",
		script = "JudgementCut",
		tools = { "Greatsword" },
		icon = "",
		color = Color3.fromRGB(190, 150, 255),
	},
	{
		id = "DimensionBreak",
		name = "Dimension Break",
		desc = "Split the world open in a line ahead of you.",
		price = 2500,
		levelRequired = 18,
		key = "T",
		script = "DimensionBreak",
		tools = { "Greatsword" },
		icon = "",
		color = Color3.fromRGB(255, 120, 200),
	},

	-- Blood Sword line: the same shapes, recoloured and renamed for the blade that
	-- drinks what it cuts.
	{
		id = "CrimsonSlash",
		name = "Crimson Slash",
		desc = "A bleeding arc of red that leaves wounds open.",
		price = 500,
		levelRequired = 4,
		key = "E",
		script = "CrimsonSlash",
		tools = { "BloodSword" },
		icon = "",
		color = Color3.fromRGB(214, 48, 60),
	},
	{
		id = "CrimsonDash",
		name = "Crimson Dash",
		desc = "Blink forward in a smear of blood, cutting all the way through.",
		price = 900,
		levelRequired = 7,
		key = "Z",
		script = "CrimsonDash",
		tools = { "BloodSword" },
		icon = "",
		color = Color3.fromRGB(255, 90, 90),
	},
}

-- ------------------------------------------------------------ monetization --

-- IMPORTANT: these IDs are placeholders. Create the products on the Roblox creator
-- dashboard, paste the real IDs in, and the Robux tab turns itself on. Anything left
-- at 0 is shown as unavailable rather than silently failing on the player.
GameConfig.DeveloperProducts = {
	{ id = 0, name = "Pouch of Coins", coins = 500, robux = 25, icon = "" },
	{ id = 0, name = "Sack of Coins", coins = 1500, robux = 65, icon = "" },
	{ id = 0, name = "Chest of Coins", coins = 4000, robux = 150, icon = "" },
	{ id = 0, name = "Hoard of Coins", coins = 10000, robux = 350, icon = "" },
}

GameConfig.GamePasses = {
	{
		id = 0,
		name = "Double XP",
		desc = "Every kill is worth twice the experience, forever.",
		robux = 199,
		perk = "DoubleXP",
		icon = "", -- put real artwork here; blank falls back to a lettered badge
	},
	{
		id = 0,
		name = "VIP",
		desc = "A golden nameplate, a VIP-only spawn, and 25% more coins.",
		robux = 399,
		perk = "VIP",
		icon = "", -- put real artwork here; blank falls back to a lettered badge
	},
}

-- --------------------------------------------------------------------- gore --

-- Stylised, not realistic: a handful of low-poly chunks and a flat splatter, drawn
-- on each client so nothing replicates. Every number here is a performance dial.
GameConfig.Gore = {
	Enabled = true,
	ChunkCount = 7,           -- pieces per death
	ChunkLifetime = 2.5,
	ChunkSize = 0.55,
	SplatterCount = 4,        -- flat marks left on the ground
	SplatterLifetime = 6,
	MaxConcurrent = 10,       -- bursts allowed to START within BurstWindow
	BurstWindow = 0.5,        -- how long a burst holds one of those slots
	MaxDistance = 220,        -- past this the client does not bother drawing it
	BloodColor = Color3.fromRGB(138, 18, 24),
	MistColor = Color3.fromRGB(180, 30, 38),
}

-- ------------------------------------------------------------------- theme --

-- Dark, gold-on-black to match the anime-sword feel of the map and the Blood Sword.
--
-- The surface tones carry a slight blue lean rather than being pure neutral grey. Flat
-- grey is what makes a dark interface read as unfinished -- there is no such thing as a
-- neutral shadow in a lit scene, and the eye notices its absence even when it cannot say
-- why. The hue is the same family throughout so nothing looks tinted, just less dead.
GameConfig.Theme = {
	Background   = Color3.fromRGB(13, 14, 19),   -- deepest layer: page behind everything
	Panel        = Color3.fromRGB(23, 25, 32),   -- default surface
	PanelLight   = Color3.fromRGB(33, 36, 46),   -- raised surface: buttons, cards
	Elevated     = Color3.fromRGB(44, 48, 60),   -- hovered or selected surface
	Stroke       = Color3.fromRGB(58, 62, 76),   -- ordinary border
	StrokeLight  = Color3.fromRGB(92, 98, 118),  -- border catching the light from above

	Accent       = Color3.fromRGB(238, 190, 98),
	AccentDim    = Color3.fromRGB(146, 114, 56),
	AccentGlow   = Color3.fromRGB(255, 214, 140), -- for text or strokes that must read hot

	Danger       = Color3.fromRGB(226, 74, 74),
	Success      = Color3.fromRGB(104, 206, 120),
	Info         = Color3.fromRGB(96, 166, 246),

	Text         = Color3.fromRGB(240, 240, 236),
	TextDim      = Color3.fromRGB(150, 154, 168),
	TextFaint    = Color3.fromRGB(102, 106, 120),

	Corner       = UDim.new(0, 8),
	CornerLarge  = UDim.new(0, 12),
	Font         = Enum.Font.GothamMedium,
	FontBold     = Enum.Font.GothamBold,
	FontBlack    = Enum.Font.GothamBlack,
}

-- One place every part of the interface reads rarity colour from, so a Legendary weapon
-- card, a Legendary crate and a Legendary chip cannot end up three different golds.
GameConfig.RarityColour = {
	Common    = Color3.fromRGB(170, 176, 186),
	Uncommon  = Color3.fromRGB(104, 198, 122),
	Rare      = Color3.fromRGB(88, 156, 245),
	Epic      = Color3.fromRGB(176, 112, 240),
	Legendary = Color3.fromRGB(245, 176, 66),
	Mythic    = Color3.fromRGB(248, 92, 116),
}

-- Look up helpers -------------------------------------------------------------

function GameConfig.GetShopItem(id: string)
	for _, entry in ipairs(GameConfig.ShopItems) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

function GameConfig.GetAbilitiesForTool(toolName: string)
	local list = {}
	for _, entry in ipairs(GameConfig.Abilities) do
		for _, t in ipairs(entry.tools or {}) do
			if t == toolName then
				table.insert(list, entry)
				break
			end
		end
	end
	return list
end

function GameConfig.GetAbility(id: string)
	for _, entry in ipairs(GameConfig.Abilities) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

function GameConfig.GetProductById(productId: number)
	for _, entry in ipairs(GameConfig.DeveloperProducts) do
		if entry.id == productId and entry.id ~= 0 then
			return entry
		end
	end
	return nil
end

-- Nothing is for sale here while the ability system is being rebuilt. Everything that reads
-- abilities -- the market, AbilityService, the tool attributes -- walks this list, so an
-- empty one retires the feature cleanly instead of leaving dead buttons in the shop.
GameConfig.Abilities = {}

return GameConfig
