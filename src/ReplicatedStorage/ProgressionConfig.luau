--!strict
-- What a level is worth, and what a weapon is worth once you have carried it long enough.
--
-- This exists because of a measurement: reaching level 100 costs 2,107,657 XP, and levels
-- 31 to 100 are 1,976,764 of that -- 94% of the whole curve -- while the last weapon unlock
-- sits at level 30. Ninety-four per cent of the climb paid nothing.
--
-- The answer is deliberately NOT seventy invented weapon unlocks. Sixteen weapons is a
-- coherent arsenal; thirty would be a list. Instead the late game pays in the two things the
-- game already has a place to show: what your weapon looks like, and what people see next to
-- your name. Both already exist as owned-item fields, so nothing here invents a new economy.

local ProgressionConfig = {}

-- ----------------------------------------------------------------- mastery --
--
-- Kills with ONE weapon, tracked already by StatsService as WeaponKills -- this only reads
-- it. Thresholds are steep on purpose: Gold is a few hundred fights with the same gun, not
-- an afternoon, and the camos it pays out are ones the market sells for real money, so
-- mastery is an alternative route to them rather than a giveaway.
--
-- `title` is formatted with the weapon's name: "Warden Veteran".
-- Camos used to be the reward here. They have been removed from the game in favour of
-- Mastery Weapons, so these pay CRYSTALS instead -- which buy cosmetics through the
-- Quartermaster and are what contracts pay, so the reward still reaches something.
ProgressionConfig.MasteryTiers = {
	{ id = "Bronze", kills = 25, title = "%s Initiate", crystals = 3 },
	{ id = "Silver", kills = 100, title = "%s Adept", crystals = 8 },
	{ id = "Gold", kills = 250, title = "%s Veteran", crystals = 16 },
	{ id = "Diamond", kills = 500, title = "%s Master", crystals = 30 },
	{ id = "Ronin", kills = 1000, title = "%s Ronin", crystals = 60 },
}

--- The tier a weapon is at now, or nil below the first one.
function ProgressionConfig.MasteryTierFor(kills: number)
	local current = nil
	for _, tier in ipairs(ProgressionConfig.MasteryTiers) do
		if kills >= tier.kills then
			current = tier
		end
	end
	return current
end

--- The next tier and how many kills are left, for the profile card to show a bar.
function ProgressionConfig.MasteryNext(kills: number)
	for _, tier in ipairs(ProgressionConfig.MasteryTiers) do
		if kills < tier.kills then
			return tier, tier.kills - kills
		end
	end
	return nil, 0
end

--- Every tier crossed by going from `before` to `after` kills. Usually one, but a big
--- multi-kill should not be able to skip a reward.
function ProgressionConfig.MasteryCrossed(before: number, after: number)
	local crossed = {}
	for _, tier in ipairs(ProgressionConfig.MasteryTiers) do
		if before < tier.kills and after >= tier.kills then
			table.insert(crossed, tier)
		end
	end
	return crossed
end

-- -------------------------------------------------------------- milestones --
--
-- Levels 31 to 100. Every one of them pays coins that scale, so no level is empty, and the
-- multiples of five pay something you keep. Attachments come first (they change how a
-- weapon handles), then crystals and titles, because a reward that alters play is worth
-- more early and a reward that alters identity is worth more late.
--
-- The camo slots here are gone with the camo system. Every one of them now pays crystals,
-- sized so the ladder still climbs: the rungs that used to be a rare camo are worth more
-- than the ones that used to be a common.
--
-- Ids are real entries from AttachmentConfig; nothing here names an item that does not exist.
ProgressionConfig.LevelCoinsBase = 150
ProgressionConfig.LevelCoinsPerLevel = 25
ProgressionConfig.FirstMilestoneLevel = 31

ProgressionConfig.Milestones = {
	[35] = { attachment = "Muzzle:Suppressor", note = "Quiet rounds: enemies hear half as far" },
	[40] = { crystals = 8 },
	[45] = { attachment = "Sight:Scope4x" },
	[50] = { title = "Seasoned", crystals = 18 },
	[55] = { attachment = "Magazine:Drum" },
	[60] = { crystals = 12 },
	[65] = { attachment = "Underbarrel:Bipod" },
	[70] = { title = "Relentless", crystals = 25 },
	[75] = { attachment = "Sight:Sniper" },
	[80] = { crystals = 16 },
	[85] = { attachment = "Stock:Skeleton" },
	[90] = { title = "Warbound", crystals = 40 },
	[95] = { attachment = "Underbarrel:Laser" },
	[100] = { title = "Centurion", crystals = 80, coins = 10000 },
}

--- What reaching `level` pays. Returns nil below the first milestone level, so levels 2-30
--- keep paying exactly what they always did: the unlock ladder in GameConfig.
function ProgressionConfig.RewardFor(level: number)
	if level < ProgressionConfig.FirstMilestoneLevel then
		return nil
	end
	local reward = ProgressionConfig.Milestones[level]
	local coins = ProgressionConfig.LevelCoinsBase
		+ ProgressionConfig.LevelCoinsPerLevel * (level - ProgressionConfig.FirstMilestoneLevel)
	if not reward then
		return { coins = coins }
	end
	local out = table.clone(reward)
	out.coins = (out.coins or 0) + coins
	return out
end

return ProgressionConfig
