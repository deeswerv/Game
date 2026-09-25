--!strict
-- Daily contracts: three jobs a day -- one easy, one medium, one hard -- the same three for
-- everybody on every server, so "did you get the Long Shot one today?" is a conversation.
--
-- Each contract counts one kind of thing (ContractService.Note is told about them as they
-- happen) and pays the moment it is done. Finishing all three pays a bonus on top.
--
-- Shared, so the panel can describe a contract without asking the server what it means.

local ContractConfig = {}

export type Contract = {
	id: string,
	tier: string,          -- "Easy" | "Medium" | "Hard"
	title: string,
	text: string,
	icon: string,
	kind: string,          -- what ContractService.Note counts
	target: number,
	-- Optional narrowing on kills: a weapon class (or several), or a minimum distance.
	classes: { [string]: boolean }?,
	minDistance: number?,
	reward: { coins: number, xp: number, crystals: number? },
}

ContractConfig.Pool = {
	-- Easy ---------------------------------------------------------------------
	{ id = "hunter", tier = "Easy", title = "Hunter", icon = "🎯", kind = "kill", target = 8,
		text = "Eliminate 8 enemies", reward = { coins = 700, xp = 350 } },
	{ id = "heavy", tier = "Easy", title = "Heavy Hitter", icon = "💥", kind = "damage", target = 1500,
		text = "Deal 1,500 damage", reward = { coins = 700, xp = 350 } },
	{ id = "salvage", tier = "Easy", title = "Salvage", icon = "📦", kind = "supply", target = 1,
		text = "Open a supply drop", reward = { coins = 800, xp = 400 } },
	{ id = "prospector", tier = "Easy", title = "Prospector", icon = "💎", kind = "crystal", target = 3,
		text = "Mine 3 crystal nodes", reward = { coins = 600, xp = 300, crystals = 2 } },
	{ id = "sparring", tier = "Easy", title = "Sparring", icon = "🥊", kind = "duel_played", target = 2,
		text = "Play 2 duels", reward = { coins = 700, xp = 350 } },

	-- Medium -------------------------------------------------------------------
	{ id = "marksman", tier = "Medium", title = "Marksman", icon = "🎖", kind = "headshot", target = 10,
		text = "Land 10 headshots", reward = { coins = 1400, xp = 700, crystals = 2 } },
	{ id = "rifleman", tier = "Medium", title = "Rifleman", icon = "🔫", kind = "kill", target = 8,
		classes = { Rifle = true }, text = "Get 8 kills with a rifle", reward = { coins = 1300, xp = 650, crystals = 2 } },
	{ id = "closequarters", tier = "Medium", title = "Close Quarters", icon = "💢", kind = "kill", target = 8,
		classes = { Shotgun = true, SMG = true }, text = "Get 8 kills with a shotgun or SMG",
		reward = { coins = 1300, xp = 650, crystals = 2 } },
	{ id = "duelist", tier = "Medium", title = "Duelist", icon = "⚔", kind = "duel_win", target = 2,
		text = "Win 2 duels", reward = { coins = 1500, xp = 750, crystals = 3 } },
	{ id = "sidearm", tier = "Medium", title = "Sidearm", icon = "🔫", kind = "kill", target = 6,
		classes = { Pistol = true }, text = "Get 6 kills with a pistol", reward = { coins = 1300, xp = 650, crystals = 2 } },

	-- Hard ---------------------------------------------------------------------
	{ id = "longshot", tier = "Hard", title = "Long Shot", icon = "🔭", kind = "kill", target = 4,
		minDistance = 120, text = "Get 4 kills from over 120 studs", reward = { coins = 2600, xp = 1300, crystals = 5 } },
	{ id = "wallbanger", tier = "Hard", title = "Through the Wall", icon = "🧱", kind = "wallbang", target = 4,
		text = "Hit enemies through walls 4 times", reward = { coins = 2400, xp = 1200, crystals = 5 } },
	{ id = "onfire", tier = "Hard", title = "On Fire", icon = "🔥", kind = "streak", target = 5,
		text = "Get 5 kills without dying", reward = { coins = 2600, xp = 1300, crystals = 5 } },
	{ id = "kingslayer", tier = "Hard", title = "Kingslayer", icon = "👑", kind = "boss", target = 1,
		text = "Take down a Warlord", reward = { coins = 3000, xp = 1500, crystals = 6 } },
	{ id = "champion", tier = "Hard", title = "Champion", icon = "🏆", kind = "duel_win", target = 4,
		text = "Win 4 duels", reward = { coins = 3000, xp = 1500, crystals = 6 } },
} :: { Contract }

-- All three in a day.
ContractConfig.Bonus = { coins = 2500, xp = 1000, crystals = 5 }

ContractConfig.TIERS = { "Easy", "Medium", "Hard" }
ContractConfig.TierColour = {
	Easy = Color3.fromRGB(88, 214, 110),
	Medium = Color3.fromRGB(70, 160, 255),
	Hard = Color3.fromRGB(190, 110, 255),
}

local byId: { [string]: Contract } = {}
for _, c in ipairs(ContractConfig.Pool) do
	byId[c.id] = c
end

function ContractConfig.Get(id: string): Contract?
	return byId[id]
end

--- The UTC day number contracts are dealt on.
function ContractConfig.Day(now: number?): number
	return math.floor((now or os.time()) / 86400)
end

--- Today's three: one of each tier, picked from the day number so every server agrees.
function ContractConfig.Deal(day: number): { string }
	local picks = {}
	for index, tier in ipairs(ContractConfig.TIERS) do
		local options = {}
		for _, c in ipairs(ContractConfig.Pool) do
			if c.tier == tier then
				table.insert(options, c.id)
			end
		end
		-- A small, stable hash of the day and the tier, so consecutive days differ.
		local h = (day * 2654435761 + index * 40503) % 2147483647
		table.insert(picks, options[(h % #options) + 1])
	end
	return picks
end

return ContractConfig
