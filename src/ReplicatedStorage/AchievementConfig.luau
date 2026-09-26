--!strict
-- Achievements: long-term goals that pay out, and the titles that say you did them.
--
-- Each one counts one kind of thing, told to AchievementService through the same events the
-- daily contracts already hear (ContractService.Noted), plus a few of its own: places
-- travelled to, turf wars won, stashes found, bounties claimed, the player's level.
--
-- Unlocking one is automatic; the reward is CLAIMED from the Achievements panel (H), which is
-- the moment that feels like a reward. A title reward joins the player's titles, and any
-- title can be worn from that panel.
--
-- Shared by the server (which counts and pays) and the panel (which draws), so the two can
-- never disagree about what an achievement asks for or pays.

local AchievementConfig = {}

export type Reward = { coins: number, xp: number?, crystals: number?, title: string? }
export type Achievement = {
	id: string,
	category: string,
	icon: string,
	title: string,
	text: string,
	kind: string,          -- what is counted
	goal: number,
	best: boolean?,        -- the best single value counts (a streak, a level), not a running total
	reward: Reward,
}

AchievementConfig.Categories = { "Combat", "Duels", "World", "Progress" }

AchievementConfig.CategoryColour = {
	Combat = Color3.fromRGB(236, 84, 70),
	Duels = Color3.fromRGB(70, 150, 255),
	World = Color3.fromRGB(88, 200, 110),
	Progress = Color3.fromRGB(250, 190, 60),
}

AchievementConfig.List = {
	-- ------------------------------------------------------------ combat --
	{ id = "first_blood", category = "Combat", icon = "🩸", title = "First Blood", text = "Take down your first enemy",
		kind = "kill", goal = 1, reward = { coins = 250, xp = 100 } },
	{ id = "hunter", category = "Combat", icon = "🎯", title = "Hunter", text = "Take down 50 enemies",
		kind = "kill", goal = 50, reward = { coins = 1500, xp = 600, crystals = 3 } },
	{ id = "veteran", category = "Combat", icon = "🎖", title = "Veteran", text = "Take down 250 enemies",
		kind = "kill", goal = 250, reward = { coins = 5000, xp = 1500, crystals = 10, title = "Veteran" } },
	{ id = "legend", category = "Combat", icon = "👑", title = "Legend", text = "Take down 1,000 enemies",
		kind = "kill", goal = 1000, reward = { coins = 15000, xp = 5000, crystals = 30, title = "Legend" } },
	{ id = "sharpshooter", category = "Combat", icon = "🔫", title = "Sharpshooter", text = "Land 25 headshots",
		kind = "headshot", goal = 25, reward = { coins = 1200, xp = 400, crystals = 2 } },
	{ id = "deadeye", category = "Combat", icon = "👁", title = "Deadeye", text = "Land 200 headshots",
		kind = "headshot", goal = 200, reward = { coins = 6000, xp = 2000, crystals = 12, title = "Deadeye" } },
	{ id = "wallbanger", category = "Combat", icon = "🧱", title = "Through and Through", text = "Land 10 wallbang hits",
		kind = "wallbang", goal = 10, reward = { coins = 1500, xp = 500, crystals = 3 } },
	{ id = "on_a_roll", category = "Combat", icon = "🔥", title = "On a Roll", text = "5 kills without dying",
		kind = "streak", goal = 5, best = true, reward = { coins = 1000, xp = 400 } },
	{ id = "unstoppable", category = "Combat", icon = "⚡", title = "Unstoppable", text = "15 kills without dying",
		kind = "streak", goal = 15, best = true, reward = { coins = 5000, xp = 1500, crystals = 8, title = "Unstoppable" } },
	{ id = "long_shot", category = "Combat", icon = "🔭", title = "Long Shot", text = "10 kills from over 120 studs",
		kind = "longkill", goal = 10, reward = { coins = 2500, xp = 800, crystals = 4 } },

	-- ------------------------------------------------------------- duels --
	{ id = "challenger", category = "Duels", icon = "⚔", title = "Challenger", text = "Win your first 1v1 duel",
		kind = "duel_win", goal = 1, reward = { coins = 500, xp = 250 } },
	{ id = "regular", category = "Duels", icon = "🎟", title = "Regular", text = "Play 25 duels",
		kind = "duel_played", goal = 25, reward = { coins = 2000, xp = 800, crystals = 3 } },
	{ id = "duelist", category = "Duels", icon = "🥇", title = "Duelist", text = "Win 10 duels",
		kind = "duel_win", goal = 10, reward = { coins = 3000, xp = 1000, crystals = 5, title = "Duelist" } },
	{ id = "champion", category = "Duels", icon = "🏆", title = "Champion", text = "Win 50 duels",
		kind = "duel_win", goal = 50, reward = { coins = 10000, xp = 3000, crystals = 20, title = "Champion" } },

	-- ------------------------------------------------------------- world --
	{ id = "explorer", category = "World", icon = "🗺", title = "Explorer", text = "Travel to all six places",
		kind = "place", goal = 6, reward = { coins = 2000, xp = 800, crystals = 4, title = "Explorer" } },
	{ id = "warlord_slayer", category = "World", icon = "💀", title = "Warlord Slayer", text = "Defeat a Warlord",
		kind = "boss", goal = 1, reward = { coins = 3000, xp = 1200, crystals = 6, title = "Warlord Slayer" } },
	{ id = "scavenger", category = "World", icon = "📦", title = "Scavenger", text = "Loot 5 supply drops",
		kind = "supply", goal = 5, reward = { coins = 2000, xp = 700, crystals = 3 } },
	{ id = "street_defender", category = "World", icon = "🛡", title = "Street Defender", text = "Win 3 turf wars downtown",
		kind = "turf", goal = 3, reward = { coins = 3000, xp = 1000, crystals = 5, title = "Defender" } },
	{ id = "kingpin_slayer", category = "World", icon = "🎩", title = "Kingpin Slayer", text = "Take down the Kingpin downtown",
		kind = "kingpin", goal = 1, reward = { coins = 6000, xp = 2500, crystals = 15, title = "Kingpin Slayer" } },
	{ id = "street_legend", category = "World", icon = "🌆", title = "Street Legend", text = "Reach Honoured Street Cred (75)",
		kind = "streetcred", goal = 75, best = true, reward = { coins = 8000, xp = 3000, crystals = 15, title = "Street Legend" } },
	{ id = "rooftop_runner", category = "World", icon = "🏙", title = "Rooftop Runner", text = "Find the rooftop stash 3 times",
		kind = "stash", goal = 3, reward = { coins = 1500, xp = 500, crystals = 3 } },
	{ id = "prospector", category = "World", icon = "💎", title = "Prospector", text = "Mine 50 crystal nodes",
		kind = "crystal", goal = 50, reward = { coins = 2500, xp = 800, crystals = 5 } },
	{ id = "bounty_hunter", category = "World", icon = "💰", title = "Bounty Hunter", text = "Claim 3 bounties",
		kind = "bounty", goal = 3, reward = { coins = 3000, xp = 1000, crystals = 5, title = "Bounty Hunter" } },

	-- ---------------------------------------------------------- progress --
	{ id = "contractor", category = "Progress", icon = "📋", title = "Contractor", text = "Finish 10 daily contracts",
		kind = "contract", goal = 10, reward = { coins = 3000, xp = 1000, crystals = 6 } },
	{ id = "rising", category = "Progress", icon = "⬆", title = "Rising", text = "Reach level 10",
		kind = "level", goal = 10, best = true, reward = { coins = 2000, xp = 0, crystals = 4 } },
	{ id = "seasoned", category = "Progress", icon = "🌟", title = "Seasoned Fighter", text = "Reach level 25",
		kind = "level", goal = 25, best = true, reward = { coins = 6000, xp = 0, crystals = 12, title = "Seasoned Fighter" } },
	{ id = "completionist", category = "Progress", icon = "🏅", title = "Completionist", text = "Unlock 20 other achievements",
		kind = "achievement", goal = 20, reward = { coins = 20000, crystals = 40, title = "Completionist" } },
} :: { Achievement }

local byId: { [string]: Achievement } = {}
for _, a in ipairs(AchievementConfig.List) do
	byId[a.id] = a
end

function AchievementConfig.Get(id: string): Achievement?
	return byId[id]
end

--- Which achievements count this kind of thing.
function AchievementConfig.ForKind(kind: string): { Achievement }
	local out = {}
	for _, a in ipairs(AchievementConfig.List) do
		if a.kind == kind then
			table.insert(out, a)
		end
	end
	return out
end

--- The kinds any achievement counts, so the service ignores everything else.
function AchievementConfig.Kinds(): { [string]: boolean }
	local kinds = {}
	for _, a in ipairs(AchievementConfig.List) do
		kinds[a.kind] = true
	end
	return kinds
end

--- Every title an achievement can give, in list order.
function AchievementConfig.Titles(): { string }
	local out = {}
	for _, a in ipairs(AchievementConfig.List) do
		if a.reward.title then
			table.insert(out, a.reward.title)
		end
	end
	return out
end

-- Kinds where the best single value counts (a streak, a level) rather than the total.
local BEST: { [string]: boolean } = {}
for _, a in ipairs(AchievementConfig.List) do
	if a.best then
		BEST[a.kind] = true
	end
end

local function copy(t: any): { [string]: any }
	local out = {}
	if type(t) == "table" then
		for k, v in pairs(t) do
			out[k] = v
		end
	end
	return out
end

--- A stats table with one more `kind` counted (or, for a best-value kind, the new value
--- kept if it beats the old).
function AchievementConfig.Count(stats: { [string]: any }, kind: string, amount: number): { [string]: any }
	local out = copy(stats)
	if BEST[kind] then
		out[kind] = math.max(tonumber(out[kind]) or 0, amount)
	else
		out[kind] = (tonumber(out[kind]) or 0) + amount
	end
	return out
end

--- Given the stats and what is already unlocked, the ids that unlock now. Completionist
--- counts the others, so it is looked at after them.
function AchievementConfig.Evaluate(stats: { [string]: any }, unlocked: { [string]: any }): { string }
	local newly = {}
	local have = copy(unlocked)
	for pass = 1, 2 do
		local others = 0
		for id in pairs(have) do
			local a = byId[id]
			if a and a.kind ~= "achievement" then
				others += 1
			end
		end
		for _, a in ipairs(AchievementConfig.List) do
			local value = a.kind == "achievement" and others or (tonumber(stats[a.kind]) or 0)
			if not have[a.id] and value >= a.goal and (pass == 2 or a.kind ~= "achievement") then
				have[a.id] = true
				table.insert(newly, a.id)
			end
		end
	end
	return newly
end

return AchievementConfig
