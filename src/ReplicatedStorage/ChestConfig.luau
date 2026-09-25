--!strict
-- Supply crates in Map 2: what they look like, what they can hold, and how likely each
-- outcome is. Everything tunable lives here so the loot can be rebalanced without
-- touching the service that rolls it.
--
-- Rarity is rolled first, then an item of that rarity is drawn from whatever the game
-- actually contains. Nothing is hardcoded to a specific camo or attachment id, so adding
-- a Legendary camo to CamoConfig puts it in the Legendary chest pool automatically and
-- removing one cannot leave a chest pointing at an item that no longer exists.

local WeaponConfig = require(script.Parent.WeaponConfig)

local ChestConfig = {}

-- Chance of each chest rolling at each tier. Must sum to 1.
ChestConfig.RarityChance = {
	Common = 0.44,
	Uncommon = 0.28,
	Rare = 0.17,
	Epic = 0.08,
	Legendary = 0.03,
}

-- Highest first: the order a roll walks, and the order used for presentation.
ChestConfig.RarityOrder = { "Legendary", "Epic", "Rare", "Uncommon", "Common" }

-- How each tier presents. Only the chest-specific parts are declared here.
--
-- The colour deliberately is NOT: it comes from WeaponConfig.RarityColors, which is
-- already what the market cards, the inventory tiles and the rarity chips use. A second
-- copy of those colours had drifted a few units off within a day of being written, which
-- is exactly how a game ends up with two slightly different Legendaries.
local COIN_RANGE = {
	Common = { 90, 180 },
	Uncommon = { 180, 340 },
	Rare = { 340, 620 },
	Epic = { 620, 1150 },
	Legendary = { 1150, 2200 },
}

local GLOW = {
	Common = 0.0,
	Uncommon = 0.15,
	Rare = 0.3,
	Epic = 0.5,
	Legendary = 0.75,
}

ChestConfig.Rarity = {}
for tier, coins in pairs(COIN_RANGE) do
	ChestConfig.Rarity[tier] = {
		colour = (WeaponConfig.RarityColors and WeaponConfig.RarityColors[tier])
			or Color3.fromRGB(170, 176, 186),
		glow = GLOW[tier] or 0,
		coins = coins,
	}
end

-- What a chest of a given tier can contain, and how likely each kind is.
--
-- Coins are always a possible outcome and always the fallback: if a tier's item pools
-- turn out to be empty -- every camo of that rarity already owned, say -- the chest pays
-- coins rather than opening to nothing, which is the worst possible reward.
ChestConfig.Contents = {
	Common = { coins = 1.00 },
	Uncommon = { coins = 0.75, attachment = 0.25 },
	Rare = { coins = 0.55, attachment = 0.30, camo = 0.15 },
	Epic = { coins = 0.40, attachment = 0.32, camo = 0.28 },
	Legendary = { coins = 0.30, attachment = 0.25, camo = 0.45 },
}

-- Seconds before an opened crate comes back. Long enough that clearing the map is not
-- the optimal loop, short enough that a returning player finds something.
ChestConfig.RespawnSeconds = 150

-- How long the player must hold E.
ChestConfig.HoldDuration = 0.9

-- Where crates sit in Map 2. XZ only -- the service raycasts down to find the ground, so
-- these do not have to be measured against the terrain by hand and stay correct if the
-- map moves underneath them.
--
-- Map 2 spans roughly X -681..-442, Z 6..164. These are spread across it rather than
-- clustered, and deliberately kept away from the NPC camp around (-595, 88) so looting
-- and fighting are separate decisions rather than the same one.
ChestConfig.Spawns = {
	Vector3.new(-470, 0, 30),
	Vector3.new(-505, 0, 140),
	Vector3.new(-560, 0, 25),
	Vector3.new(-585, 0, 150),
	Vector3.new(-628, 0, 60),
	Vector3.new(-655, 0, 128),
	Vector3.new(-450, 0, 95),
	Vector3.new(-672, 0, 20),
}

--- Roll a rarity. Walks highest-first so the rarest tier is checked against its own slice
--- rather than being whatever is left over after rounding.
function ChestConfig.RollRarity(): string
	local roll = math.random()
	local floor = 0
	for _, tier in ipairs(ChestConfig.RarityOrder) do
		floor += ChestConfig.RarityChance[tier] or 0
		if roll <= floor then
			return tier
		end
	end
	return "Common"
end

--- Roll which kind of reward a chest of this tier gives: "coins", "attachment" or "camo".
function ChestConfig.RollKind(tier: string): string
	local table_ = ChestConfig.Contents[tier] or ChestConfig.Contents.Common
	local roll = math.random()
	local floor = 0
	for _, kind in ipairs({ "coins", "attachment", "camo" }) do
		local weight = table_[kind]
		if weight then
			floor += weight
			if roll <= floor then
				return kind
			end
		end
	end
	return "coins"
end

return ChestConfig
