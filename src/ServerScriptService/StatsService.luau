--!strict
-- The record a player is identified by: wins, win rate, kills, K/D, favourite weapons.
--
-- Two of these were not actually being kept. `TotalKills` was incremented by LevelSystem, but
-- **TotalDeaths was declared in the save template, preserved across a prestige, and written by
-- nothing** -- so it was zero for everyone and a K/D built on it would have been infinite. And
-- nothing recorded which weapon got a kill, so "most played" had no data behind it.
--
-- This fills both gaps and serves the numbers read-only to the client. Nothing here trusts the
-- client: every figure is derived on the server from the profile.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local KillCredit = require(ServerScriptService.KillCredit)
local ShopService = require(ServerScriptService.ShopService)
local GameConfig = require(ReplicatedStorage.GameConfig)
local ProgressionConfig = require(ReplicatedStorage.ProgressionConfig)
local WeaponConfig = require(ReplicatedStorage.WeaponConfig)

local StatsService = {}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local ProfileRequest = remotes:FindFirstChild("ProfileRequest")
if not ProfileRequest then
	local rf = Instance.new("RemoteFunction")
	rf.Name = "ProfileRequest"
	rf.Parent = remotes
	ProfileRequest = rf
end

local function replicaOf(player: Player)
	local ok, replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
	end)
	return ok and replica or nil
end

-- ------------------------------------------------------------------ record --

local function bumpDeath(player: Player)
	local replica = replicaOf(player)
	if not replica then
		return
	end
	replica:SetValue("TotalDeaths", (tonumber(replica.Data.TotalDeaths) or 0) + 1)
end

local function bumpWeapon(player: Player, weapon: string)
	local replica = replicaOf(player)
	if not replica then
		return
	end
	-- Replica replicates whole values, so the table is rewritten rather than mutated in place.
	local tally = {}
	for name, count in pairs(replica.Data.WeaponKills or {}) do
		if type(name) == "string" and type(count) == "number" then
			tally[name] = count
		end
	end
	local before = tally[weapon] or 0
	tally[weapon] = before + 1
	replica:SetValue("WeaponKills", tally)

	StatsService.CheckMastery(player, replica, weapon, before, tally[weapon])
end

-- ----------------------------------------------------------------- mastery --
--
-- Mastery is not a second counter: it is a reading of the WeaponKills tally that was
-- already being kept, so nothing new is tracked and old profiles are already "in progress"
-- the moment this ships.
--
-- Rewards are granted at the kill that crosses the line and recorded in MasteryAwarded, so
-- re-checking on every kill is safe and a reward is never handed over twice.

-- Fired for both mastery tiers and level milestones; LevelSystem creates it.
local gameRemotes = ReplicatedStorage:FindFirstChild("GameRemotes")
if not gameRemotes then
	local folder = Instance.new("Folder")
	folder.Name = "GameRemotes"
	folder.Parent = ReplicatedStorage
	gameRemotes = folder
end
local ProgressionReward = gameRemotes:FindFirstChild("ProgressionReward")
if not ProgressionReward then
	local remote = Instance.new("RemoteEvent")
	remote.Name = "ProgressionReward"
	remote.Parent = gameRemotes
	ProgressionReward = remote
end

function StatsService.CheckMastery(player: Player, replica, weapon: string, before: number, after: number)
	local crossed = ProgressionConfig.MasteryCrossed(before, after)
	if #crossed == 0 then
		return
	end

	local awarded = table.clone(replica.Data.MasteryAwarded or {})
	local titles = table.clone(replica.Data.Titles or {})
	local changedAwards, changedTitles = false, false

	for _, tier in ipairs(crossed) do
		local key = weapon .. ":" .. tier.id
		if not table.find(awarded, key) then
			table.insert(awarded, key)
			changedAwards = true

			local earned = {}
			-- Crystals, not camos. Lazily required so this module does not pull the crystal
			-- service in at load just to hand out a mastery reward.
			if tier.crystals and tier.crystals > 0 then
				local ok, Crystals = pcall(function()
					return require(game:GetService("ServerScriptService").CrystalService)
				end)
				if ok and Crystals and Crystals.Award(player, tier.crystals) then
					table.insert(earned, tier.crystals .. " crystals")
				end
			end
			-- A Mastery Weapon earned at this tier on this weapon. The other route to the same
			-- variant is Robux, and both land in OwnedVariants, so nothing downstream can tell
			-- -- or needs to tell -- which way it was got.
			for _, variant in ipairs(WeaponConfig.Variants or {}) do
				local earn = variant.earn
				if earn and earn.mastery == tier.id and earn.weapon == weapon then
					if ShopService.Grant(player, "OwnedVariants", variant.id) then
						table.insert(earned, variant.name)
					end
				end
			end

			local title = tier.title and tier.title:format(weapon)
			if title and not table.find(titles, title) then
				table.insert(titles, title)
				changedTitles = true
				table.insert(earned, '"' .. title .. '"')
			end

			ProgressionReward:FireClient(player, "Mastery", weapon, tier.id, earned, after)
		end
	end

	if changedAwards then
		replica:SetValue("MasteryAwarded", awarded)
	end
	if changedTitles then
		replica:SetValue("Titles", titles)
	end
end

-- ------------------------------------------------------------------ derive --

--- The favourite weapons, most-used first.
local function topWeapons(tally, count: number)
	local list = {}
	for name, kills in pairs(tally or {}) do
		if type(name) == "string" and type(kills) == "number" then
			table.insert(list, { name = name, kills = kills })
		end
	end
	-- Alphabetical as the tie-break, so the order is stable between opens rather than
	-- shuffling whenever two weapons are level.
	table.sort(list, function(a, b)
		if a.kills ~= b.kills then
			return a.kills > b.kills
		end
		return a.name < b.name
	end)
	while #list > count do
		table.remove(list)
	end
	return list
end

--- The next weapon a player's level will open up.
---
--- Every shop item already carries a `levelRequired`, and the market already refuses a
--- purchase below it -- but nothing ever SHOWED a player what the next rung was, so levelling
--- had no visible destination. This finds the cheapest gate they have not yet passed.
local function nextUnlock(level: number, owned)
	local best
	for _, item in ipairs(GameConfig.ShopItems) do
		local required = tonumber(item.levelRequired) or 1
		-- Only things still out of reach, and only things not already owned -- an item bought
		-- early through some other route should not be dangled as a goal.
		if required > level and not owned[item.id] then
			if not best or required < best.level then
				best = { name = item.name or item.id, level = required, price = item.price }
			end
		end
	end
	return best
end

--- Everything the profile card shows, derived on the server.
function StatsService.Summary(player: Player)
	local replica = replicaOf(player)
	if not replica then
		return nil
	end
	local data = replica.Data

	local wins = tonumber(data.DuelWins) or 0
	local losses = tonumber(data.DuelLosses) or 0
	local draws = tonumber(data.DuelDraws) or 0
	local decided = wins + losses

	local kills = tonumber(data.TotalKills) or 0
	local deaths = tonumber(data.TotalDeaths) or 0

	return {
		name = player.DisplayName,
		handle = "@" .. player.Name,
		level = tonumber(data.Level) or 1,
		prestige = tonumber(data.Prestige) or 0,

		rating = tonumber(data.Rating) or 1000,
		tier = player:GetAttribute("RankTier") or "Bronze",

		wins = wins,
		losses = losses,
		draws = draws,
		-- Draws are excluded from the denominator: a win rate is about decided games, and
		-- counting draws as half a loss makes the number harder to read, not more honest.
		winRate = decided > 0 and (wins / decided) * 100 or 0,
		decided = decided,
		streak = tonumber(data.DuelStreak) or 0,
		bestStreak = tonumber(data.DuelBestStreak) or 0,

		kills = kills,
		deaths = deaths,
		-- Never divide by zero, and never claim an infinite ratio: with no deaths yet the
		-- honest answer is simply the kill count.
		kd = deaths > 0 and kills / deaths or kills,
		flawless = deaths == 0 and kills > 0,

		weapons = topWeapons(data.WeaponKills, 3),
		mastery = StatsService.MasteryFor(data),
		titles = data.Titles or {},
		title = data.EquippedTitle or "",
		nextUnlock = nextUnlock(tonumber(data.Level) or 1, (function()
			local set = {}
			for _, id in ipairs(data.OwnedItems or {}) do
				set[id] = true
			end
			return set
		end)()),
	}
end

--- The mastery standing of the weapons this player actually uses, best first, for the
--- profile card: what tier each is at, and how far the next one is.
function StatsService.MasteryFor(data)
	local out = {}
	for _, entry in ipairs(topWeapons(data.WeaponKills, 3)) do
		local tier = ProgressionConfig.MasteryTierFor(entry.kills)
		local nextTier, remaining = ProgressionConfig.MasteryNext(entry.kills)
		table.insert(out, {
			name = entry.name,
			kills = entry.kills,
			tier = tier and tier.id or nil,
			nextTier = nextTier and nextTier.id or nil,
			remaining = remaining,
		})
	end
	return out
end

-- ------------------------------------------------------------------ hooks --

-- Kills come through KillCredit's own award event, so credit is decided in exactly one place.
-- The weapon was recorded on the victim's humanoid by KillCredit.Damage at the moment of the
-- hit, which is the only thing that knows it.
KillCredit.KillAwarded.Event:Connect(function(killer: Player?, humanoid: Humanoid?, _victim: Player?)
	if not killer or not humanoid then
		return
	end
	local weapon = humanoid:GetAttribute("LastHitWeapon")
	if type(weapon) == "string" and weapon ~= "" then
		task.spawn(bumpWeapon, killer, weapon)
	end
end)

local function watchCharacter(player: Player, character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
		or character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	-- Once per character. Humanoid.Died is not once per death -- going limp re-fires it, which
	-- CombatDeath measured at seven times for a single kill.
	local counted = false
	humanoid.Died:Connect(function()
		if counted then
			return
		end
		counted = true
		task.spawn(bumpDeath, player)
	end)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(watchCharacter, player, character)
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayer(p)
end

-- Read-only, and only ever about yourself: the caller is the player argument the engine
-- supplies, so there is no id to spoof.
local profileRemote = ProfileRequest :: RemoteFunction
profileRemote.OnServerInvoke = function(player: Player)
	return StatsService.Summary(player)
end

print("[Stats] record keeping online")

return StatsService
