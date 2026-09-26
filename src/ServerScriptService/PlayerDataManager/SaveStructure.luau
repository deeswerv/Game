-- Profile template. ProfileService:Reconcile() fills any key added here into
-- existing profiles on load, so new fields are safe to append.
local SaveStructure = {
	Level = 1,
	MaxEXP = 100,
	EXP = 0,
	MaxStamina = 100,
	Strength = 0,
	Stamina = 0,
	Defense = 0,
	StatPoints = 3,
	Inventory = {"Basic Combat"},
	CurrentQuest = "",
	QuestProgress = 0,

	-- Shop tools the player owns. One-time purchases: re-granted free on every spawn.
	OwnedItems = {},
	-- Abilities bought from the vendor NPC.
	OwnedAbilities = {},

	-- The weapons the player carries, in hotbar order: a primary and a secondary.
	--
	--   Loadout = { "Warden", "Sentinel" }
	--
	-- Ids only, validated against OwnedItems on every spawn, so a loadout saved before a
	-- weapon was lost (or before it existed) simply drops that entry rather than granting
	-- anything. Reconcile() fills this in for existing profiles as an empty list, which is
	-- exactly the old single-weapon behaviour until the player equips something.
	--
	-- Deliberately a contiguous array: Replica warns against numeric tables with gaps.
	Loadout = {},
	-- Lifetime stats, useful for leaderboards later.
	TotalKills = 0,
	TotalDeaths = 0,

	-- Duel record and ladder rating.
	--
	-- Rating starts at 1000 rather than 0 so a loss early on cannot drive it negative and so
	-- the number reads as a rating rather than a score. Reconcile() backfills all of these
	-- into existing profiles, so nobody's record is lost by adding them.
	Rating = 1000,
	DuelWins = 0,
	DuelLosses = 0,
	DuelDraws = 0,
	DuelStreak = 0,       -- current, negative while losing
	DuelBestStreak = 0,

	-- Kills per weapon name, for "most played weapons". A dictionary keyed by weapon id, so a
	-- weapon that is renamed or removed simply stops appearing rather than corrupting a list.
	WeaponKills = {},

	-- Daily reward.
	--
	-- Stored as a UTC DAY NUMBER (os.time() // 86400), not a timestamp. "Have they claimed
	-- today" is then a plain integer comparison, immune to clock drift within a day, and a
	-- streak is just whether the numbers are consecutive.
	LastDailyDay = 0,
	DailyStreak = 0,
	BestDailyStreak = 0,

	-- Daily contracts (ContractService): the UTC day the current set belongs to, progress and
	-- payment per contract id (dictionaries, so Replica never sees a gappy array), and the
	-- lifetime count for the profile card.
	ContractDay = 0,
	ContractProgress = {},
	ContractsPaid = {},
	ContractsDone = 0,

	-- The UTC day the Downtown rooftop stash was last opened (once a day).
	StashDay = 0,

	-- Achievements (AchievementService / AchievementConfig): running counts per kind
	-- ("kill" = 412, "streak" = best run), which are unlocked, which have been claimed, and
	-- the places travelled to for Explorer. All dictionaries, so Replica never sees a gappy
	-- array; Reconcile() fills them into existing profiles empty.
	AchievementStats = {},
	AchievementsUnlocked = {},
	AchievementsClaimed = {},
	AchievementPlaces = {},

	-- How many times this player has reset their level at the cap. Drives the emblem shown
	-- beside their name, and is the one number that never resets.
	--
	-- ProfileService:Reconcile() fills this into existing profiles on load, so players who
	-- were already at level 100 before prestige existed simply start at Prestige 0 with
	-- their level intact -- nothing is taken from them by this field appearing.
	Prestige = 0,
	-- Lifetime XP across every prestige, so progress is never actually erased, only the
	-- level counter is.
	LifetimeXP = 0,

	-- Seconds played, accumulated across sessions.
	TimePlayed = 0,

	-- Quests the player has finished, by id.
	CompletedQuests = {},

	-- Standing with each faction, keyed by the faction names NPCConfig already uses:
	--
	--   Reputation = { Guard = -40, Hostile = 25 }
	--
	-- A plain number per faction, clamped to [-100, 100] by ReputationService -- never by
	-- the client, which cannot write this at all. A missing key means neutral (0), so
	-- Reconcile() filling this in as an empty table leaves every existing player exactly
	-- where they were: neutral with everyone, nothing gained and nothing lost.
	Reputation = {},

	-- Weapon skins set from the owner-only customisation screen. Game-wide rather than
	-- personal, but kept on the owner's profile so this reuses the existing save instead
	-- of opening a second datastore.
	--
	--   WeaponSkins = { Redwood = { Slide = { Colour = {r, g, b}, Material = "Metal" } } }
	--
	-- Colours are plain number triples: ProfileService stores JSON-safe values only, and a
	-- Color3 would not survive the round trip.
	WeaponSkins = {},

	-- Attachments fitted from the same screen, by slot:
	--
	--   WeaponAttachments = { Redwood = { Sight = "Scope4x", Muzzle = "Suppressor" } }
	WeaponAttachments = {},

	-- Per-player saved builds. Ids and names only -- no instances -- so a whole locker of
	-- them is a few hundred bytes and the weapon is rebuilt from the ids on equip:
	--
	--   WeaponBuilds = {
	--     Redwood = {
	--       { id = "b1", name = "CLOSE RANGE", camo = "Acid",
	--         attachments = { Sight = "RedDot", Muzzle = "Compensator" } },
	--     },
	--   }
	--
	-- The default weapon is deliberately NOT stored here. No entry means the template is
	-- cloned untouched, so "default stays default" holds by construction.
	WeaponBuilds = {},

	-- Which build is live per weapon. A missing entry means DEFAULT.
	EquippedBuild = {},

	-- Camos and attachments are bought once and then fit to any weapon, so ownership is
	-- recorded per item rather than per weapon. Attachments are keyed "Slot:Id", because
	-- the same id can appear in more than one slot.
	--
	--   OwnedCamos = { "Gold", "Acid" }
	--   OwnedAttachments = { "Sight:RedDot", "Muzzle:Suppressor" }
	--
	-- Stock parts and the factory finish are deliberately absent: they are free to
	-- everyone, so there is nothing to record and nothing that can be lost.
	-- RETIRED. Camos left the game on 2026-09-19, replaced by Mastery Weapon variants.
	-- This list is KEPT rather than dropped: it is the only record of what anyone earned,
	-- and someone who ground 1000 kills for Ronin should be findable if they are ever to be
	-- compensated. Nothing reads it any more, and removing a field would delete that history
	-- from every profile the first time they saved.
	OwnedCamos = {},
	OwnedAttachments = {},

	-- Mastery Weapons: whole variants of a gun, bought with Robux or earned. Separate from
	-- OwnedItems because a variant is not a weapon you can buy with coins, and the market
	-- needs to be able to tell those apart.
	--
	--   OwnedVariants = { "Carbine_DarkMatter" }
	OwnedVariants = {},

	-- Cosmetics worn over the locked body, and which one is in each slot:
	--
	--   OwnedCosmetics = { "Cap", "Wings" }
	--   EquippedCosmetics = { Hat = "Cap", Back = "Wings" }
	--
	-- A slot with no entry means nothing worn, which is what every existing profile gets
	-- from Reconcile() -- nobody is given anything and nobody loses anything.
	OwnedCosmetics = {},
	EquippedCosmetics = {},

	-- VFX bought in the shop (VFXConfig): kill effects and tracers, and which is in each slot.
	--
	--   OwnedVFX = { "KillShatter", "TracerGold" }
	--   EquippedVFX = { Kill = "KillShatter", Tracer = "TracerGold" }
	OwnedVFX = {},
	EquippedVFX = {},

	-- Crystals prised out of nodes in the world. A second currency deliberately kept
	-- separate from coins: coins come from killing, crystals come from looking, so the
	-- things they buy can be different in kind rather than just dearer.
	Crystals = 0,

	-- The player's own settings panel: volumes, camera shake, field of view. Stored as
	-- numbers only, validated against SettingsService's schema on every write.
	--   Settings = { Master = 0.8, Weapons = 1, World = 0.6, Interface = 1, Shake = 0.5, Fov = 80 }
	Settings = {},

	-- Names earned rather than bought: weapon mastery tiers and level milestones both pay
	-- one. `EquippedTitle` is the one shown; an empty string means none.
	--
	--   Titles = { "Warden Veteran", "Seasoned" }
	--
	-- Reconcile() fills both into existing profiles -- an empty list and an empty string --
	-- so nobody is given anything and nobody loses anything.
	Titles = {},
	EquippedTitle = "",

	-- Coins predate this profile: they live in leaderstats and were persisted by two legacy
	-- scripts writing two different DataStores. This field is where they are going to live,
	-- filled by the owner-only MigrateCoins command, which takes the highest of the three
	-- sources and never lowers anything. NOTHING reads it yet -- the switch-over is a
	-- separate, deliberate step, so that a bad migration cannot cost anyone their money.
	Coins = 0,
	CoinsMigrated = false,

	-- Which mastery tiers have already paid out, as "Weapon:Tier" keys. Rewards are granted
	-- once, at the kill that crosses the line; this is what makes that safe to re-check on
	-- every kill without handing out a camo a second time.
	MasteryAwarded = {},
}

return SaveStructure
