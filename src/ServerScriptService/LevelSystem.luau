--!strict
-- Progression: kills grant XP, XP grants levels, levels grant stat points.
--
-- Level/EXP/MaxEXP/StatPoints already existed on the ProfileService profile and were
-- only ever moved by the stat-point UI. This is the piece that actually fills them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.GameConfig)
local ProgressionConfig = require(ReplicatedStorage.ProgressionConfig)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local KillCredit = require(ServerScriptService.KillCredit)
local ShopService = require(ServerScriptService.ShopService)

local Cfg = GameConfig.Leveling

-- Client-facing signals. Created here so ordering never matters for the UI scripts.
local remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "GameRemotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemote(className: string, name: string)
	local existing = remotes:FindFirstChild(name)
	if existing then
		return existing
	end
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end

local XPGained = ensureRemote("RemoteEvent", "XPGained")
local LevelUp = ensureRemote("RemoteEvent", "LevelUp")
-- Client asks to prestige; server decides and answers with the result.
-- One channel for "you have earned something", whatever earned it: a level milestone here,
-- a weapon mastery tier in StatsService. The client shows them the same way.
local ProgressionReward = ensureRemote("RemoteEvent", "ProgressionReward")

local PrestigeRequest = ensureRemote("RemoteFunction", "PrestigeRequest")
local PrestigeChanged = ensureRemote("RemoteEvent", "PrestigeChanged")

local LevelSystem = {}

-- Mirror profile values onto Player-parented IntValues.
-- The existing combat and stat scripts read Player.Stats / Player.Status, so keeping
-- these in sync means progression works with the systems already in the game.
local function mirrorToPlayer(player: Player, data)
	local stats = player:FindFirstChild("Stats")
	if stats then
		for _, key in ipairs({ "Level", "EXP", "MaxEXP", "StatPoints" }) do
			local v = stats:FindFirstChild(key)
			if v and v:IsA("ValueBase") and data[key] ~= nil then
				(v :: any).Value = data[key]
			end
		end
	end
end

-- How much a kill is worth, given who died.
local function computeXP(killer: Player, victimPlayer: Player?, killerLevel: number, victimLevel: number,
	npcReward: number?): number
	-- An NPC states its own worth (NPCService stamps XPReward from its archetype, level and
	-- elite roll); anything that does not falls back to the flat rate it always had.
	local base = victimPlayer and Cfg.XP_PER_PLAYER_KILL or (npcReward or Cfg.XP_PER_NPC_KILL)

	-- Killing up is worth more than farming players far below you. PLAYERS, as written --
	-- this rule was never meant for NPCs, and applying it to them quietly broke the curve.
	--
	-- The highest-level NPC in the game is level 9 (the Reach zone ceiling) and the cap is
	-- 100, so the -0.08 per level bottomed out at the 0.25 floor from player level 19 and
	-- never came back: 98.1% of the 2,107,657 XP needed for level 100 was being earned at a
	-- quarter rate, against content that cannot level with you. Measured at the arena's
	-- respawn ceiling that is 204 hours to cap, and about 620 at a realistic pace.
	--
	-- An NPC already states its own worth: NPCConfig.Levelled scales XPReward by 25% a level,
	-- so harder zones still pay more. That is the scaling NPCs are meant to have.
	local mult = 1
	if victimPlayer then
		local diff = victimLevel - killerLevel
		mult = math.clamp(1 + (diff * Cfg.LEVEL_DIFF_BONUS), Cfg.MIN_XP_MULTIPLIER, Cfg.MAX_XP_MULTIPLIER)
	end

	-- Game-pass perk. MonetizationService keeps this attribute in sync with ownership,
	-- so progression never has to talk to MarketplaceService itself.
	if killer:GetAttribute("DoubleXP") then
		mult *= 2
	end

	return math.max(1, math.floor(base * mult))
end

-- Award XP and roll over as many levels as the amount covers.
function LevelSystem.AwardXP(player: Player, amount: number)
	if amount <= 0 then
		return
	end

	PlayerDataManager:GetPlayerDataReplica(player):andThen(function(Replica)
		local data = Replica.Data
		if data.Level >= Cfg.MAX_LEVEL then
			return
		end

		local level = data.Level
		local exp = data.EXP + amount
		local maxExp = data.MaxEXP
		local gainedLevels = 0

		-- A big kill can cross more than one level, so loop rather than branch.
		while exp >= maxExp and level < Cfg.MAX_LEVEL do
			exp -= maxExp
			level += 1
			gainedLevels += 1
			maxExp = GameConfig.GetRequiredEXP(level)
		end

		if level >= Cfg.MAX_LEVEL then
			exp = 0
		end

		Replica:SetValue("EXP", exp)
		Replica:SetValue("MaxEXP", maxExp)

		if gainedLevels > 0 then
			Replica:SetValue("Level", level)
			Replica:SetValue("StatPoints", data.StatPoints + gainedLevels * Cfg.STAT_POINTS_PER_LEVEL)

			-- Every level from 31 up pays something. Each level crossed is paid separately, so
			-- one enormous XP award cannot skip past a milestone without handing it over.
			for crossed = level - gainedLevels + 1, level do
				local reward = ProgressionConfig.RewardFor(crossed)
				if reward then
					LevelSystem.GrantMilestone(player, Replica, crossed, reward)
				end
			end

			if Cfg.HEAL_ON_LEVEL_UP then
				local char = player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					hum.Health = hum.MaxHealth
				end
			end

			LevelUp:FireClient(player, level, gainedLevels * Cfg.STAT_POINTS_PER_LEVEL)
		end

		mirrorToPlayer(player, Replica.Data)
		XPGained:FireClient(player, amount, exp, maxExp, level)
	end):catch(function(err)
		warn("[LevelSystem] could not award XP to " .. player.Name .. ": " .. tostring(err))
	end)
end

-- Read a player's level without yielding the caller for long.
local function getLevel(player: Player?): number
	if not player then
		return 1
	end
	local stats = player:FindFirstChild("Stats")
	local lv = stats and stats:FindFirstChild("Level")
	if lv and lv:IsA("ValueBase") then
		return (lv :: any).Value
	end
	return 1
end

KillCredit.KillAwarded.Event:Connect(function(killer: Player, victimHumanoid: Humanoid, victimPlayer: Player?)
	local killerLevel = getLevel(killer)
	local victimLevel = getLevel(victimPlayer)
	-- Server-written attributes on the NPC's model. Never read off anything a client owns.
	local npcReward: number? = nil
	local victimModel = victimHumanoid and victimHumanoid.Parent
	if not victimPlayer and victimModel then
		local reward = victimModel:GetAttribute("XPReward")
		if type(reward) == "number" and reward > 0 then
			npcReward = reward
		end
		local level = victimModel:GetAttribute("Level")
		if type(level) == "number" then
			victimLevel = level
		end
	end
	local xp = computeXP(killer, victimPlayer, killerLevel, victimLevel, npcReward)

	LevelSystem.AwardXP(killer, xp)

	-- Lifetime counters, kept on the profile so they survive a leaderstats reset.
	PlayerDataManager:GetPlayerDataReplica(killer):andThen(function(Replica)
		Replica:SetValue("TotalKills", (Replica.Data.TotalKills or 0) + 1)
	end):catch(function() end)
end)

-- Push profile values onto the player's mirror instances once they are ready.
local function onPlayerAdded(player: Player)
	PlayerDataManager:GetPlayerDataReplica(player):andThen(function(Replica)
		-- MaxEXP may predate the current curve; correct it on load.
		local expected = GameConfig.GetRequiredEXP(Replica.Data.Level)
		if Replica.Data.MaxEXP ~= expected then
			Replica:SetValue("MaxEXP", expected)
		end
		mirrorToPlayer(player, Replica.Data)
		-- Published as an attribute so any UI -- the HUD badge, a player list, a nameplate --
		-- can read someone's prestige without another remote or another round trip.
		player:SetAttribute("Prestige", Replica.Data.Prestige or 0)
		XPGained:FireClient(player, 0, Replica.Data.EXP, Replica.Data.MaxEXP, Replica.Data.Level)
	end):catch(function() end)
end

-- ---------------------------------------------------------------- milestones --
--
-- Levels 31 to 100 used to unlock nothing at all: the last weapon gate is level 30, and the
-- climb past it is 94% of the entire XP curve. These pay it out -- coins on every level,
-- attachments, crystals and titles on the fives -- all from ProgressionConfig, so the ladder
-- is balanced by editing data rather than this file.
--
-- The camo branch is gone with the camo system; those rungs pay crystals now.
function LevelSystem.GrantMilestone(player: Player, Replica, level: number, reward)
	local awarded = {}

	if reward.coins and reward.coins > 0 then
		ShopService.AwardCoins(player, reward.coins)
		table.insert(awarded, reward.coins .. " coins")
	end

	if reward.crystals and reward.crystals > 0 then
		Replica:SetValue("Crystals", (tonumber(Replica.Data.Crystals) or 0) + reward.crystals)
		table.insert(awarded, reward.crystals .. " crystals")
	end

	-- Ownership goes through the same door a purchase uses, so the market and the workshop
	-- cannot end up disagreeing about what was handed over.
	if reward.attachment then
		if ShopService.Grant(player, "OwnedAttachments", reward.attachment) then
			table.insert(awarded, reward.attachment)
		end
	end

	if reward.title then
		local titles = table.clone(Replica.Data.Titles or {})
		if not table.find(titles, reward.title) then
			table.insert(titles, reward.title)
			Replica:SetValue("Titles", titles)
			table.insert(awarded, '"' .. reward.title .. '"')
		end
	end

	if #awarded > 0 then
		ProgressionReward:FireClient(player, "Milestone", level, awarded, reward.note)
	end
end

-- ------------------------------------------------------------------ vitality --
--
-- Defense used to be applied by a legacy character script that also ran the retired
-- blocking system, so retiring that kit would have silently taken the stat's only effect
-- with it. The rule is unchanged -- ten per cent of base health per point -- it just lives
-- with the rest of progression now, and is re-applied on every spawn rather than only the
-- first one of a session.
local BASE_HEALTH = 100
local HEALTH_PER_DEFENSE = 0.1

local function applyVitality(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	PlayerDataManager:GetPlayerDataReplica(player):andThen(function(Replica)
		if not humanoid.Parent then
			return
		end
		local defense = tonumber(Replica.Data.Defense) or 0
		local maximum = BASE_HEALTH * (1 + defense * HEALTH_PER_DEFENSE)
		if math.abs(humanoid.MaxHealth - maximum) < 0.01 then
			return
		end
		-- Keep the share of health they had, so gaining a point mid-fight neither heals
		-- them to full nor leaves them on a sliver.
		local share = humanoid.MaxHealth > 0 and humanoid.Health / humanoid.MaxHealth or 1
		humanoid.MaxHealth = maximum
		humanoid.Health = maximum * share
	end):catch(function() end)
end

local function watchVitality(player: Player)
	player.CharacterAdded:Connect(function(character)
		applyVitality(player, character)
	end)
	if player.Character then
		task.spawn(applyVitality, player, player.Character)
	end
end

-- Hooked here rather than from onPlayerAdded above, which is declared earlier in the file
-- and could not see this function.
Players.PlayerAdded:Connect(watchVitality)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(watchVitality, player)
end

-- ------------------------------------------------------------------ prestige --

local PrestigeCfg = GameConfig.Prestige

-- One prestige at a time per player. Two requests arriving together would otherwise both
-- pass the level check and both reset, costing the player a whole level bar for one
-- prestige count.
local prestiging: { [Player]: boolean } = {}

--- Can this player prestige right now, and if not, why not?
function LevelSystem.CanPrestige(player: Player): (boolean, string)
	local ok, data = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect().Data
	end)
	if not ok or not data then
		return false, "Your data is still loading"
	end
	if (data.Prestige or 0) >= PrestigeCfg.MAX_PRESTIGE then
		return false, "You have reached the highest prestige"
	end
	if (data.Level or 1) < PrestigeCfg.REQUIRED_LEVEL then
		return false, string.format("Reach level %d to prestige", PrestigeCfg.REQUIRED_LEVEL)
	end
	return true, ""
end

--- Reset the level track and advance the prestige count.
---
--- What survives is decided by GameConfig.Prestige.PRESERVE, which is an allow-list of
--- fields to keep rather than a list to wipe. That direction matters: a field added to the
--- save later is preserved by default, so a future addition cannot be silently destroyed
--- by a reset written before it existed.
function LevelSystem.Prestige(player: Player): (boolean, string)
	if prestiging[player] then
		return false, "Please wait..."
	end

	local allowed, reason = LevelSystem.CanPrestige(player)
	if not allowed then
		return false, reason
	end

	prestiging[player] = true

	local ok, result = pcall(function()
		local Replica = PlayerDataManager:GetPlayerDataReplica(player):expect()
		local data = Replica.Data

		-- Re-check inside the write, not just before it: the level could have changed
		-- between the guard above and here.
		if (data.Level or 1) < PrestigeCfg.REQUIRED_LEVEL then
			return { ok = false, reason = "Reach level " .. PrestigeCfg.REQUIRED_LEVEL .. " to prestige" }
		end

		local newPrestige = (data.Prestige or 0) + 1

		-- Banked before the reset so the bar the player just filled is not simply thrown
		-- away -- the level counter resets, the lifetime total never does.
		local banked = (data.LifetimeXP or 0)
		for lv = 1, (data.Level or 1) - 1 do
			banked += GameConfig.GetRequiredEXP(lv)
		end
		banked += (data.EXP or 0)

		Replica:SetValue("LifetimeXP", banked)
		Replica:SetValue("Prestige", newPrestige)
		Replica:SetValue("Level", 1)
		Replica:SetValue("EXP", 0)
		Replica:SetValue("MaxEXP", GameConfig.GetRequiredEXP(1))
		Replica:SetValue("StatPoints", Cfg.STAT_POINTS_PER_LEVEL)

		-- Weapons, camos, attachments, builds and completed quests are all on the preserve
		-- list and are deliberately not touched here.

		local reward = PrestigeCfg.COIN_REWARD_BASE
			+ PrestigeCfg.COIN_REWARD_PER_PRESTIGE * (newPrestige - 1)
		local stats = player:FindFirstChild("leaderstats")
		local coins = stats and stats:FindFirstChild("Coins")
		if coins and coins:IsA("IntValue") then
			coins.Value += reward
		end

		mirrorToPlayer(player, Replica.Data)
		player:SetAttribute("Prestige", newPrestige)
		XPGained:FireClient(player, 0, 0, GameConfig.GetRequiredEXP(1), 1)
		PrestigeChanged:FireAllClients(player, newPrestige)

		local tier = GameConfig.GetPrestigeTier(newPrestige)
		return { ok = true, prestige = newPrestige, reward = reward, name = tier.name }
	end)

	prestiging[player] = nil

	if not ok then
		warn("[LevelSystem] prestige failed for " .. player.Name .. ": " .. tostring(result))
		return false, "Something went wrong"
	end
	if not result.ok then
		return false, result.reason
	end
	return true, result
end

-- The client can ask, but never decide.
PrestigeRequest.OnServerInvoke = function(player)
	local ok, result = LevelSystem.Prestige(player)
	if ok then
		return result
	end
	return { ok = false, reason = result }
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

return LevelSystem
