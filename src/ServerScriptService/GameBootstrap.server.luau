-- Starts the server-side systems. ModuleScripts do nothing until something requires
-- them, so this is the single place that brings them up, in dependency order.

local ServerScriptService = game:GetService("ServerScriptService")

local systems = {
	"KillCredit",          -- kill attribution; others listen to its KillAwarded signal
	"LevelSystem",         -- XP and levels, driven by KillCredit
	"ShopService",         -- coin purchases, ownership, re-granting on spawn
	"AbilityService",      -- enables/disables ability scripts by ownership
	"MeleeHandler",        -- generic melee combat for config-driven weapons
	"CombatDeath",         -- ragdoll on death, thrown by whatever weapon killed you
	"WeaponDropService",   -- weapons NPCs leave behind, and picking them up
	"WeaponPose",          -- how characters hold what they carry
	"GoreService",         -- announces deaths so clients can draw the effect
	"MonetizationService", -- Robux products and game passes
	"HolsterService",     -- shows stowed weapons on the body
	"VendorNPC",           -- builds the market stall on the main path
	"BiomeService",         -- per-zone dressing; additive, one folder, fully reversible
	"AscentService",        -- stairs onto existing high ground
	"MineService",          -- the crystal mine behind the falls
	"WeatherService",      -- fog, rain and overcast; fog really does shorten sight
	"AmbienceService",     -- day/night, wind and cloud; the world stops being static
	"MapExpansion",        -- satellite islets, bridges and landmarks
	"CoverService",        -- Map 2's combat spaces: the ruin, the flanks, the high ground
	"TravelService",       -- the Travel menu's server half: the places, and the one door that moves you
	"LandmarkService",     -- one tall, distinct silhouette per island, lit in its gate's colour
	"LeaderboardService",  -- global kill/money/time boards in the hub
	"AdminService",        -- owner-only tools, validated server side
	"WeaponSkinService",   -- owner-only weapon customisation, applied to the templates
	"ReputationService",   -- standing with each faction; no remote, server writes only
	"NPCService",          -- combat NPCs and their shared AI tick
	"BossService",          -- one Warlord per island, with phases
	"QuestService",        -- quests, the giver NPC, and kill tracking
	"CrystalService",       -- crystal nodes; a reason to look at the world
	"CosmeticService",      -- hats and backs over the locked body; massless, never block shots
	"AvatarLook",          -- each player's own clothes, skin, hair and hats on the locked body
	"EmoteService",         -- emote wheel; the server owns which emotes exist
	"HeadLookService",     -- where each player is looking, so everyone sees heads turn
	"CombatFeedService",   -- aim replication and the kill feed, both for the combat HUD
	"WeaponBuildService",  -- per-player saved builds, camos, and dressing weapons on equip
	"KillcamService",      -- tells the victim who killed them, and with what
	"ArenaService",        -- the bounded duel arena at y=3000
	"MatchService",        -- the duel queue, and a match that actually resolves
	"RankService",         -- Elo on the result of a duel, and the tier it puts you in
	"StatsService",        -- deaths, weapon usage, and the record the profile card shows
	"RangeService",        -- the gun range: damage and DPS read off the targets themselves
	"DailyService",        -- the daily reward ladder, timed on the server
	"ContractService",     -- three daily contracts, counted from what the server decides
	"AchievementService",  -- long-term goals and the titles they give, from the same events
	"SupplyDropService",   -- a crate on a parachute every few minutes: a race across the map
	"BountyService",       -- kill streaks, WANTED players and the price on their heads
	"SettingsService",     -- saves the settings panel (volumes, camera shake, field of view)
	"DuelPads",            -- 1v1 pads by the spawn: stand on one to queue (last: it looks for clear ground)
	"DistrictService",     -- Downtown: the city district (Travel menu), its shops, hall and stash
	"TurfWarService",      -- a crew rolls into Downtown every few minutes; drive them out for a payout
}

for _, name in ipairs(systems) do
	local module = ServerScriptService:FindFirstChild(name)
	if not module then
		warn("[Bootstrap] missing system: " .. name)
	else
		local ok, err = pcall(require, module)
		if ok then
			print("[Bootstrap] started " .. name)
		else
			warn("[Bootstrap] " .. name .. " failed: " .. tostring(err))
		end
	end
end
