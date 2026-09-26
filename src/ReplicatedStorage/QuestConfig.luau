--!strict
-- Quest definitions. A new quest is a table entry: nothing about the quest system
-- itself is per-quest, so objectives, rewards and chains all come from here.

local QuestConfig = {}

-- Objective kinds the tracker understands.
-- Kill      -> kill `count` NPCs; `archetype` narrows it, or "Any" for anything
-- KillPlayer-> kill `count` players
-- KillElite -> kill `count` elites, of any archetype
-- KillInZone-> kill `count` NPCs inside `zone`; `archetype` narrows it as above
-- Reach     -> be inside `zone` (preferred), or within `radius` studs of `position`
--              (`minY`, if given, also asks you to be at least that high -- on a roof)
-- KillCrew  -> kill `count` turf-war crew; `zone` narrows it to one patch (TurfWarService)
-- TurfWin   -> win `count` turf wars; `zone` narrows it to one patch, `minThreat` to wars
--              fought at that threat level or higher (TurfWarService reports them)
--
-- The last three read attributes NPCService and the zone table already provide, so they
-- needed no new tracking -- only somewhere to look.
QuestConfig.Quests = {
	{
		id = "ClearTheCamp",
		title = "Clear the Camp",
		giver = "Quartermaster",
		levelRequired = 1,
		summary = "Bandits have set up west of the lobby. Thin them out.",
		dialogue = "That camp west of here has been bleeding us for weeks. Put five of them down and I'll make it worth your while.",
		objective = { kind = "Kill", archetype = "Grunt", count = 5, label = "Bandits defeated" },
		rewards = { coins = 250, xp = 120 },
		next = "TheBrute",
	},
	{
		id = "TheBrute",
		title = "The Brute",
		giver = "Quartermaster",
		levelRequired = 3,
		summary = "Something bigger is holding that camp together.",
		dialogue = "You rattled them. Now the big one is angry. Bring the Brute down and the camp scatters.",
		objective = { kind = "Kill", archetype = "Brute", count = 1, label = "Brute defeated" },
		rewards = { coins = 600, xp = 320 },
		next = "Marksmen",
	},
	{
		id = "Marksmen",
		title = "Eyes on the Ridge",
		giver = "Quartermaster",
		levelRequired = 6,
		summary = "Their marksmen pick off anyone crossing open ground.",
		dialogue = "Their marksmen have the ridge. Three of them, and the road is ours again.",
		objective = { kind = "Kill", archetype = "Marksman", count = 3, label = "Marksmen defeated" },
		rewards = { coins = 900, xp = 500 },
		next = "Proving",
	},
	{
		id = "Proving",
		title = "Proving Ground",
		giver = "Quartermaster",
		levelRequired = 10,
		summary = "Prove yourself against anything that moves.",
		dialogue = "Enough errands. Take down fifteen of anything hostile and I'll call you a soldier.",
		objective = { kind = "Kill", archetype = "Any", count = 15, label = "Enemies defeated" },
		rewards = { coins = 1800, xp = 1200 },
		next = "ScoutTheFlats",
	},

	-- Travel. Deliberately the first thing offered to a fresh character: it teaches the
	-- map exists and that west is where the trouble is, without asking them to fight.
	{
		id = "ScoutTheFlats",
		title = "Scout the Flats",
		giver = "Quartermaster",
		levelRequired = 1,
		summary = "Cross the water and see the Flats for yourself.",
		dialogue = "Before you swing at anything, go and look. Cross to the Flats, west of here, and see what we're dealing with. Come back able to describe it.",
		objective = {
			kind = "Reach",
			-- By zone, not by radius: the zone bounds already describe the island, where a
			-- circle either clipped its ends off or spilled onto the neighbouring one.
			zone = "Flats",
			position = Vector3.new(-573, 1, 88),   -- kept for a map marker
			count = 1,
			label = "Reach the Flats",
		},
		rewards = { coins = 200, xp = 90 },
		next = "CleanTheFlats",
	},

	{
		id = "CleanTheFlats",
		title = "Ground to Hold",
		giver = "Quartermaster",
		levelRequired = 2,
		summary = "Kill them where they live, not where they wander.",
		dialogue = "Seeing it is one thing. Clearing it is another. Eight of them, on the Flats -- not stragglers you caught this side of the water.",
		objective = { kind = "KillInZone", zone = "Flats", archetype = "Any", count = 8, label = "Cleared on the Flats" },
		rewards = { coins = 700, xp = 380 },
		next = "HuntStandouts",
	},

	{
		id = "HuntStandouts",
		title = "The Standouts",
		giver = "Quartermaster",
		levelRequired = 4,
		summary = "Some of them are a cut above. Those are the ones that matter.",
		dialogue = "You'll know them when you see them -- the ones wearing a name. Put two of those down and I'll stop worrying about that camp.",
		objective = { kind = "KillElite", count = 2, label = "Elites defeated" },
		rewards = { coins = 1500, xp = 900 },
	},
}

-- ----------------------------------------------------------- downtown --
--
-- The Fixer's chain: the Downtown story, taught through the district's own systems -- the
-- rooftop stash, the four turf patches, the threat level, and at the top of it, the Kingpin.
-- `rewards.rep` is Street Cred (standing with the "Downtown" faction).
local DOWNTOWN = Vector3.new(-155, 1000, 1500)
for _, q in ipairs({
	{
		id = "RooftopRun",
		title = "Rooftop Run",
		giver = "Fixer",
		levelRequired = 1,
		summary = "Climb the fire escape on the red-brick apartments and get up on the roof.",
		dialogue = "New face. Before anybody down here trusts you, show me you can get around. The red-brick apartments by the courts -- up the fire escape, onto the roof. There's a stash up there too, if you're quick about it.",
		objective = { kind = "Reach", position = DOWNTOWN + Vector3.new(103, 44.5, 80), radius = 16, minY = DOWNTOWN.Y + 42,
			count = 1, label = "Reach the apartment roof" },
		rewards = { coins = 400, xp = 250, rep = 5 },
	},
	{
		id = "TakeTheCarPark",
		title = "The Car Park",
		giver = "Fixer",
		levelRequired = 3,
		summary = "A crew holds the car park behind ZEE GUNS. Step onto their patch and drive them out.",
		dialogue = "The car park behind ZEE GUNS. A crew sits on it like they own it. Walk onto the red ring and they'll come to you -- put every one of them down.",
		objective = { kind = "TurfWin", zone = "CarPark", count = 1, label = "Win the turf war at THE CAR PARK" },
		rewards = { coins = 1200, xp = 900, crystals = 2, rep = 10 },
	},
	{
		id = "AlleyCats",
		title = "Alley Cats",
		giver = "Fixer",
		levelRequired = 5,
		summary = "The alley behind the gas station breeds crews. Thin them out.",
		dialogue = "That alley behind the gas station? Dumpsters, fire escapes and a lot of people who don't want to be found. Put six of the crew down back there.",
		objective = { kind = "KillCrew", zone = "Alley", count = 6, label = "Crew defeated in THE ALLEY" },
		rewards = { coins = 1500, xp = 1100, crystals = 2, rep = 10 },
	},
	{
		id = "ParkLife",
		title = "Park Life",
		giver = "Fixer",
		levelRequired = 7,
		summary = "They've taken Rainbow Park. Take it back.",
		dialogue = "Families used to sit by that waterfall. Now there's a crew on the stage. Win it back and the whole street will hear about it.",
		objective = { kind = "TurfWin", zone = "Park", count = 1, label = "Win the turf war at THE PARK" },
		rewards = { coins = 1800, xp = 1300, crystals = 3, rep = 10 },
	},
	{
		id = "FullCourt",
		title = "Full Court Press",
		giver = "Fixer",
		levelRequired = 9,
		summary = "The courts are the last patch they hold. Clear them.",
		dialogue = "The courts under the apartments. Last patch they've got. Clear it and they'll have to send someone who matters.",
		objective = { kind = "TurfWin", zone = "Courts", count = 1, label = "Win the turf war at THE COURTS" },
		rewards = { coins = 2200, xp = 1600, crystals = 3, rep = 10 },
	},
	{
		id = "TurnUpTheHeat",
		title = "Turn Up the Heat",
		giver = "Fixer",
		levelRequired = 12,
		summary = "Win two turf wars at threat III or higher.",
		dialogue = "Every crew you break, the next one comes back bigger. Good. Push it -- win two wars with the threat at three or more and the one at the top will have to show their face.",
		objective = { kind = "TurfWin", minThreat = 3, count = 2, label = "Turf wars won at threat III+" },
		rewards = { coins = 3500, xp = 2600, crystals = 5, rep = 12 },
	},
	{
		id = "TheKingpin",
		title = "The Kingpin",
		giver = "Fixer",
		levelRequired = 15,
		summary = "Win a war at threat V and the Kingpin steps out. End it.",
		dialogue = "This is it. Drive the threat to five and win -- the Kingpin will come out to settle it personally. White suit, hat, never alone. Put them down and Downtown is ours.",
		objective = { kind = "Kill", archetype = "Kingpin", count = 1, label = "Defeat the Kingpin" },
		rewards = { coins = 8000, xp = 6000, crystals = 15, rep = 20 },
	},
}) do
	table.insert(QuestConfig.Quests, q)
end

-- Where the quest giver stands.
--
-- On the grass inside the bend in the main path, facing back across it toward the market
-- stall. The two of them flank the bend, so a player walking the path passes both without
-- having to go looking for either.
QuestConfig.Givers = {
	Quartermaster = {
		displayName = "Quartermaster",
		position = Vector3.new(-62, 1.0, 158),
		lookAt = Vector3.new(-75, 1.0, 153),
		colour = Color3.fromRGB(78, 96, 120),
		signText = "QUESTS",
		where = "in the lobby",
	},
	-- Downtown's fixer, in ZEE PLAZA by the finger post, looking at the fountain.
	Fixer = {
		displayName = "The Fixer",
		position = DOWNTOWN + Vector3.new(-14, 0.5, -30),
		lookAt = DOWNTOWN + Vector3.new(0, 0.5, 0),
		colour = Color3.fromRGB(128, 64, 170),
		signText = "JOBS",
		where = "in ZEE PLAZA, Downtown",
	},
}

-- Contracts: the repeatable end of the board, and the game's only coin sink that does not
-- run out.
--
-- The story quests are a finite chain and the economy audit found the hole they leave.
-- Everything purchasable in the game costs 184,350 coins across 45 items; reaching level 100
-- earns roughly 7.7 million. You can afford the lot by about level 26, and every purchase is
-- one-time, so levels 26-100 had nothing at all to spend on.
--
-- A contract inverts the usual quest: you PAY to take it, and it pays back in XP and crystals
-- rather than coins. That turns money into progress instead of making more money, and it can
-- be taken again forever.
--
-- Crystals on purpose. The Quartermaster already works twelve of them into a cosmetic, which
-- is the one repeatable thing to spend on that the game already had. Coins now reach it.
QuestConfig.Contracts = {
	{
		id = "Contract_Standing", title = "Standing Contract", giver = "Quartermaster",
		levelRequired = 12, cost = 3000, repeatable = true,
		summary = "Routine work, paid for up front. Thin them out and come back.",
		dialogue = "There is always work. Three thousand buys the contract -- twelve of them down, and what you take off them is yours.",
		objective = { kind = "Kill", archetype = "Any", count = 12, label = "Hostiles put down" },
		rewards = { xp = 2600, crystals = 4 },
	},
	{
		id = "Contract_Hazard", title = "Hazard Contract", giver = "Quartermaster",
		levelRequired = 26, cost = 15000, repeatable = true,
		summary = "The work nobody sober takes. Twenty-five of them.",
		dialogue = "Fifteen thousand, and I will not pretend it is safe. Twenty-five hostiles. The pay is in what you learn and what you dig out of them.",
		objective = { kind = "Kill", archetype = "Any", count = 25, label = "Hostiles put down" },
		rewards = { xp = 13000, crystals = 12 },
	},
	{
		id = "Contract_Blacklist", title = "Blacklist Contract", giver = "Quartermaster",
		levelRequired = 45, cost = 60000, repeatable = true,
		summary = "Their best, by name. Expensive, and worth it.",
		dialogue = "Sixty thousand. Six of their best, by name. Bring me that and I will call us square -- until the next one.",
		objective = { kind = "Kill", archetype = "Elite", count = 6, label = "Elites put down" },
		rewards = { xp = 48000, crystals = 30 },
	},
	-- The Fixer's repeatable job: pay up front, win two wars anywhere, keep the streets clean.
	{
		id = "Contract_Sweep", title = "Street Sweep", giver = "Fixer",
		levelRequired = 10, cost = 4000, repeatable = true,
		summary = "Win two turf wars, anywhere downtown. Paid for up front.",
		dialogue = "Four thousand buys the job. Win me two turf wars, any patch, and the street pays you back in ways money doesn't.",
		objective = { kind = "TurfWin", count = 2, label = "Turf wars won" },
		rewards = { xp = 4200, crystals = 6, rep = 6 },
	},
}

local byId = {}
for _, q in ipairs(QuestConfig.Quests) do
	byId[q.id] = q
end
for _, c in ipairs(QuestConfig.Contracts) do
	byId[c.id] = c
end

function QuestConfig.Get(id: string)
	return byId[id]
end

--- The first quest from `giver` the player can take, given what they have done -- and once
--- the chain is exhausted, the best contract they qualify for.
---
--- Contracts come last on purpose: while there is still a story quest to do, that is what the
--- Quartermaster offers. They only appear when the board would otherwise be empty, which is
--- exactly where the progression hole was.
function QuestConfig.NextAvailable(giver: string, level: number, completed: { [string]: boolean })
	for _, q in ipairs(QuestConfig.Quests) do
		if q.giver == giver and not completed[q.id] and level >= q.levelRequired then
			return q
		end
	end
	-- Highest tier first, so a veteran is not offered the beginner's contract.
	local best
	for _, c in ipairs(QuestConfig.Contracts) do
		if c.giver == giver and level >= c.levelRequired then
			if not best or c.levelRequired > best.levelRequired then
				best = c
			end
		end
	end
	return best
end

return QuestConfig
