--!strict
-- Quest definitions. A new quest is a table entry: nothing about the quest system
-- itself is per-quest, so objectives, rewards and chains all come from here.

local QuestConfig = {}

-- A quest's fields are read by name (`id`, `giver`, `objective.kind` ...), and the objectives
-- differ by kind, so the list is typed loosely rather than as one fixed shape.
export type Quest = { [string]: any }

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
-- TowerWin  -> beat the Don at the top of ZEE TOWER `count` times (TowerService reports it)
--
-- Hanami City's jobs (HanamiService reports them as events):
-- Rescue    -> free `count` captives from the gang's hideout in the rail shed
-- Inspect   -> read `count` clues in the Steelworks
-- Collect   -> take `count` iron seals from where they are hidden
-- Survive   -> hold the fish market (`site = "Market"`) through every wave of a raid
-- Boss      -> beat a Hanami boss (`boss = "Foreman"` or `"Shogun"`)
-- `unique = true` counts each different thing once (the same clue read twice is one clue);
-- `prefix` narrows which things ("Seal" for the seals). KillInZone also takes `zonePrefix`
-- for a whole region ("Hanami_": anywhere in the city).
-- Any objective with a `position` is marked on the compass there (`where` names it).
--
-- `requires = "Tower"` holds a quest back until the player has beaten the boss at the top of
-- ZEE TOWER (TowerService): the world past Downtown opens then, and so does the work in it.
--
-- The last three read attributes NPCService and the zone table already provide, so they
-- needed no new tracking -- only somewhere to look.
QuestConfig.Quests = ({
	-- The first thing anyone is told at the Crossing: Downtown is where you start.
	{
		id = "WelcomeDowntown",
		title = "Welcome to Downtown",
		giver = "Quartermaster",
		levelRequired = 1,
		summary = "Open the Travel menu and head Downtown. The Fixer by the courts has work.",
		dialogue = "Fresh off the boat? The Crossing's no place to make a name. Open your Travel menu and head Downtown -- walk up to ZEE PLAZA, then find the Fixer by the courts. Everything past this harbour is shut until somebody deals with the man at the top of ZEE TOWER.",
		objective = { kind = "Reach", position = Vector3.new(-155, 1000.5, 1500), radius = 44, count = 1,
			label = "Reach ZEE PLAZA, Downtown" },
		rewards = { coins = 250, xp = 150 },
	},
	{
		id = "ClearTheCamp",
		requires = "Tower",
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
		requires = "Tower",
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
		requires = "Tower",
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
		requires = "Tower",
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
		requires = "Tower",
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
		requires = "Tower",
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
		requires = "Tower",
		title = "The Standouts",
		giver = "Quartermaster",
		levelRequired = 4,
		summary = "Some of them are a cut above. Those are the ones that matter.",
		dialogue = "You'll know them when you see them -- the ones wearing a name. Put two of those down and I'll stop worrying about that camp.",
		objective = { kind = "KillElite", count = 2, label = "Elites defeated" },
		rewards = { coins = 1500, xp = 900 },
	},
} :: { Quest })

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
		id = "TheTopFloor",
		title = "The Top Floor",
		giver = "Fixer",
		levelRequired = 10,
		summary = "Take the elevator up ZEE TOWER and beat the Don on his own roof.",
		dialogue = "You've been knocking on the crews' doors. Time to knock on the man's. The Don runs all of it from the penthouse at the top of ZEE TOWER -- walk in the lobby, take the elevator, and don't go up alone if you can help it. Beat him and this whole city opens up for you.",
		objective = { kind = "TowerWin", count = 1, label = "Beat the Don at the top of ZEE TOWER" },
		rewards = { coins = 3000, xp = 2400, crystals = 6, rep = 15 },
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
} :: { Quest }) do
	table.insert(QuestConfig.Quests, q)
end

-- ------------------------------------------------------------ hanami --
--
-- Chapter two: HANAMI CITY, opened by beating the Don. Elder Hoshi tells the story -- what
-- the Kurogane clan did to the city, up the Thousand Gates to the Iron Shogun -- and every
-- step is a different kind of job: walk somewhere, clear a street, free the captives, read
-- the clues, a mini-boss, hold the market through a raid, find the hidden seals, the climb, and
-- the final fight. Captain Rei, at the red bridge over the canal, pays for the clan's specialists.
local Hanami = require(script.Parent:WaitForChild("HanamiConfig"))
local HANAMI_FLOOR = Hanami.CENTRE.Y
for _, q in ipairs({
	{
		id = "PetalsAndIron",
		requires = "Tower",
		title = "Petals and Iron",
		giver = "Elder",
		levelRequired = 10,
		summary = "Cross the red bridge over the canal, through the Scramble, and see what the Kurogane clan has made of Lantern Row.",
		dialogue = "So you're the one who brought down the Don. Then hear an old man. The year his crates started coming in on the trains, the Kurogane clan came with them -- and their Shogun took the castle. Up the arcade, over the red bridge, through the Scramble: Lantern Row's gate is on your left. Go and see for yourself.",
		objective = { kind = "Reach", position = Hanami.Site("LanternGate"), radius = 18, count = 1,
			label = "Reach the Lantern Row gate" },
		rewards = { coins = 1200, xp = 900 },
	},
	{
		id = "LanternRow",
		requires = "Tower",
		title = "Lantern Row",
		giver = "Elder",
		levelRequired = 10,
		summary = "Drive the Kurogane out of Lantern Row: eight of them, on its streets and roofs.",
		dialogue = "Those alleys were the liveliest in the city. Now the clan drinks there, and the lanterns burn for them. Put eight of them down in Lantern Row. Mind the roofs -- their riflemen like a high place.",
		objective = { kind = "KillInZone", zone = "Hanami_LanternRow", archetype = "Any", count = 8,
			position = Hanami.At(-150, 0, 30), where = "LANTERN ROW", label = "Kurogane driven out of Lantern Row" },
		rewards = { coins = 1800, xp = 1400, crystals = 2 },
	},
	{
		id = "TakenInTheNight",
		requires = "Tower",
		title = "Taken in the Night",
		giver = "Elder",
		levelRequired = 11,
		summary = "Three townsfolk are tied up in the gang's hideout, the old brick shed in the rail yard. Cut them loose.",
		dialogue = "Three of ours went missing. Little Sora's brother went to look and found them: tied to posts in the old engine shed in the rail yard, past the shrine on the other side of the station. The ronin guard them. Get them out -- hold still beside each one long enough to cut the rope.",
		objective = { kind = "Rescue", unique = true, prefix = "Captive", count = 3, position = Hanami.Site("Camp"),
			where = "THE RAIL SHED", label = "Townsfolk freed" },
		rewards = { coins = 2000, xp = 1600, crystals = 3 },
	},
	{
		id = "IronAndAsh",
		requires = "Tower",
		title = "Iron and Ash",
		giver = "Elder",
		levelRequired = 11,
		summary = "Search the Steelworks for proof of where the steel goes: four different clues.",
		dialogue = "Everything the foundry makes goes up to the castle, and nobody knows why. Search the Steelworks past the Scramble -- the warehouse ledgers, the crates on the quay, the site office, the gate.  Bring me four things that tell the story.",
		objective = { kind = "Inspect", unique = true, count = 4, position = Hanami.At(120, 0, 10), where = "THE STEELWORKS",
			label = "Clues found in the Steelworks" },
		rewards = { coins = 2200, xp = 1800, crystals = 3 },
	},
	{
		id = "TheForeman",
		requires = "Tower",
		title = "The Foreman",
		giver = "Elder",
		levelRequired = 12,
		summary = "Foreman Tetsu runs the foundry with a hammer. Take him down in his own yard.",
		dialogue = "Foreman Tetsu. Built like a furnace door and twice as hot. He keeps the Steelworks running for the Shogun -- with his hammer, on the workers. He stands in the furnace yard. When he's hurt he calls for help and the ground cracks around him. Stay moving.",
		objective = { kind = "Boss", boss = "Foreman", count = 1, position = Hanami.Site("Foundry"), where = "THE FOUNDRY",
			label = "Defeat Foreman Tetsu" },
		rewards = { coins = 3000, xp = 2400, crystals = 5 },
	},
	{
		id = "HoldTheFarm",
		requires = "Tower",
		title = "Hold the Market",
		giver = "Elder",
		levelRequired = 12,
		summary = "The clan is coming for the fish market. Stand on the auction floor and hold it through three waves.",
		dialogue = "With Tetsu gone the clan wants its levy, and it will take it from the fish market, west of the station. Go to the auction floor and tell them you'll defend it. Three waves, and they'll be after the catch on the floor -- keep them off it.",
		objective = { kind = "Survive", site = "Market", count = 1, position = Hanami.Site("Market"), where = "THE FISH MARKET",
			label = "Hold the market through the raid" },
		rewards = { coins = 3200, xp = 2600, crystals = 5 },
	},
	{
		id = "IronSeals",
		requires = "Tower",
		title = "Iron Seals",
		giver = "Elder",
		levelRequired = 13,
		summary = "Five iron seals open the castle gate. Find them: the ramen shop's roof by the canal, a Lantern Row terrace, the dock crane, the signal box in the rail yard, under the railway at the market's far end.",
		dialogue = "The castle gate opens for a Kurogane seal and nothing else. Their couriers hide them all over the city -- Aiko saw one on the ramen shop's roof by the canal. Others: up a Lantern Row terrace, on the crane in the docks, in the nook behind the waterfall, on the hill in the far corner of the paddies. Look for the red glow. Bring me five.",
		objective = { kind = "Collect", unique = true, prefix = "Seal", count = 5, label = "Iron seals found" },
		rewards = { coins = 3400, xp = 2800, crystals = 6 },
	},
	{
		id = "ThousandGates",
		requires = "Tower",
		title = "The Thousand Gates",
		giver = "Elder",
		levelRequired = 14,
		summary = "Climb the Thousand Gates, the red stair north of the Scramble, to the gate of Kurogane Castle.",
		dialogue = "With the seals, the gate will open. The stair to the castle starts north of the Scramble -- a thousand red gates, they say, though I never counted. The Oni guard the top. Climb it.",
		objective = { kind = "Reach", position = Hanami.Site("KeepGate"), radius = 18, minY = HANAMI_FLOOR + 24, count = 1,
			label = "Climb to the gate of Kurogane Castle" },
		rewards = { coins = 3000, xp = 2600, crystals = 4 },
	},
	{
		id = "IronShogun",
		requires = "Tower",
		title = "The Iron Shogun",
		giver = "Elder",
		levelRequired = 14,
		summary = "Walk into the Shogun's court and end it. Three phases; bring friends.",
		dialogue = "He was the city's guardian once. The iron got into him. He waits in the court at the top of the castle, and he will not fight anyone who hasn't earned it. When he's hurt the blossoms turn to blades, and at the end he fights like iron itself. End it, and let the Sakura bloom again.",
		objective = { kind = "Boss", boss = "Shogun", count = 1, position = Hanami.Site("Court"), where = "THE SHOGUN'S COURT",
			label = "Defeat the Iron Shogun" },
		rewards = { coins = 6000, xp = 5000, crystals = 12 },
	},

	-- Captain Rei: what is left of the city guard, paying for the clan's specialists.
	{
		id = "ShieldWall",
		requires = "Tower",
		title = "Shield Wall",
		giver = "Captain",
		levelRequired = 10,
		summary = "Break four Shieldbearers. Shoot the shield until it shatters, or get round it.",
		dialogue = "The clan's Shieldbearers hold the streets with a wall of iron. Bullets stop dead on it -- until it breaks. Hammer the shield, or get round the side. Four of them.",
		objective = { kind = "Kill", archetype = "Shieldbearer", count = 4, label = "Shieldbearers defeated" },
		rewards = { coins = 1600, xp = 1200, crystals = 2 },
	},
	{
		id = "Shadows",
		requires = "Tower",
		title = "Shadows on the Roofs",
		giver = "Captain",
		levelRequired = 11,
		summary = "Five Shinobi. They dash at you from range -- sidestep, then shoot.",
		dialogue = "Shinobi. Light, quick, and they close the gap in a heartbeat -- you'll see the dust kick up before they come. Step aside when they dash and they're open. Five of them.",
		objective = { kind = "Kill", archetype = "Shinobi", count = 5, label = "Shinobi defeated" },
		rewards = { coins = 2000, xp = 1500, crystals = 2 },
	},
	{
		id = "Giants",
		requires = "Tower",
		title = "Giants of the Foundry",
		giver = "Captain",
		levelRequired = 12,
		summary = "Two Juggernauts walk the Steelworks. Bring them down.",
		dialogue = "The Juggernauts are the size of a door and wear plate under the coat. They don't hurry and they don't stop. Two of them patrol the Steelworks. Take your time, take cover, take them down.",
		objective = { kind = "Kill", archetype = "Juggernaut", count = 2, label = "Juggernauts defeated" },
		rewards = { coins = 2400, xp = 1800, crystals = 3 },
	},
	{
		id = "OniAtTheGate",
		requires = "Tower",
		title = "Oni at the Gate",
		giver = "Captain",
		levelRequired = 14,
		summary = "Four Oni, the Shogun's own guard, masked and throwing grenades.",
		dialogue = "The Oni are his own. Masks, good rifles, and grenades when you hide. They hold the castle and the docks. Four of them and the Shogun sleeps a little worse.",
		objective = { kind = "Kill", archetype = "Oni", count = 4, label = "Oni defeated" },
		rewards = { coins = 3000, xp = 2400, crystals = 4 },
	},
} :: { Quest }) do
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
		where = "at the Crossing, by the harbour",
	},
	-- Hanami City: the elder inside the shrine's torii, off the station square; the captain at
	-- the station end of the red bridge, looking back down the arcade.
	Elder = {
		displayName = "Elder Hoshi",
		position = Hanami.Site("Elder"),
		lookAt = Hanami.Site("GreatSakura"),
		colour = Color3.fromRGB(236, 150, 180),
		signText = "STORY",
		where = "at the shrine by the station, Hanami City",
	},
	Captain = {
		displayName = "Captain Rei",
		position = Hanami.Site("Captain"),
		lookAt = Hanami.At(0, 0, -112),
		colour = Color3.fromRGB(196, 54, 60),
		signText = "BOUNTIES",
		where = "at the red bridge, Hanami City",
	},
	-- Downtown's fixer, on the grey paving south of ZEE COURTS (by the card table), looking
	-- back down the cross street at the plaza.
	Fixer = {
		displayName = "The Fixer",
		position = DOWNTOWN + Vector3.new(46, 0.5, 42),
		lookAt = DOWNTOWN + Vector3.new(0, 0.5, 0),
		colour = Color3.fromRGB(128, 64, 170),
		signText = "JOBS",
		where = "by ZEE COURTS, Downtown",
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
QuestConfig.Contracts = ({
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
	-- Captain Rei's: pay up front, thin the clan out anywhere in the city.
	{
		id = "Contract_Patrol", title = "City Patrol", giver = "Captain",
		levelRequired = 12, cost = 5000, repeatable = true,
		summary = "Fifteen Kurogane, anywhere in Hanami City. Paid for up front.",
		dialogue = "Five thousand for the patrol, and I'll owe you. Fifteen of the clan, anywhere in the city. Keep them looking over their shoulders.",
		objective = { kind = "KillInZone", zonePrefix = "Hanami_", archetype = "Any", count = 15, label = "Kurogane put down in the city" },
		rewards = { xp = 5600, crystals = 7 },
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
} :: { Quest })

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
--- `flags` says what the player has opened up (`{ Tower = true }` once ZEE TOWER is beaten).
--- A quest that needs something they have not got stops the chain there: nothing past it,
--- no contract either, and the second value names what it is waiting for.
---
--- Contracts come last on purpose: while there is still a story quest to do, that is what the
--- Quartermaster offers. They only appear when the board would otherwise be empty, which is
--- exactly where the progression hole was.
function QuestConfig.NextAvailable(giver: string, level: number, completed: { [string]: boolean },
	flags: { [string]: boolean }?): (any, string?)
	local lockedBy: string? = nil
	for _, q in ipairs(QuestConfig.Quests) do
		if q.giver == giver and not completed[q.id] then
			if q.requires and not (flags and flags[q.requires]) then
				lockedBy = lockedBy or q.requires
			elseif level >= q.levelRequired then
				return q, nil
			end
		end
	end
	if lockedBy then
		return nil, lockedBy
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
