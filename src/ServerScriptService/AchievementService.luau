--!strict
-- Achievements, server side: counting toward them, unlocking them, paying them when claimed,
-- and wearing the titles they give.
--
-- What is counted comes from ContractService.Noted -- the same kills, headshots, duels and
-- drops the daily contracts hear, plus the kinds other services report through it only for
-- this (places travelled to, turf wars, stashes, bounties, contracts finished) -- and from
-- the player's Level attribute. Nothing the client says is counted.
--
-- Progress, unlocks and claims live on the profile (SaveStructure: AchievementStats,
-- AchievementsUnlocked, AchievementsClaimed, AchievementPlaces). An unlock tells the client
-- straight away (AchievementEvent "unlocked"); the reward is paid when the player claims it
-- from the panel (AchievementAction "claim"), and a title reward joins the profile's Titles,
-- which "equip" can then wear.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AchievementConfig = require(ReplicatedStorage.AchievementConfig)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local LevelSystem = require(ServerScriptService.LevelSystem)
local ContractService = require(ServerScriptService.ContractService)

local AchievementService = {}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local function ensure(className: string, name: string): Instance
	local existing = (remotes :: Instance):FindFirstChild(name)
	if existing then
		return existing
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = remotes
	return made
end
local AchievementAction = ensure("RemoteFunction", "AchievementAction") :: RemoteFunction
local AchievementEvent = ensure("RemoteEvent", "AchievementEvent") :: RemoteEvent

local KINDS = AchievementConfig.Kinds()

local replicas: { [Player]: any } = {}

local function copy(t: any): { [string]: any }
	local out = {}
	if type(t) == "table" then
		for k, v in pairs(t) do
			out[k] = v
		end
	end
	return out
end

local function unlockFrom(player: Player, replica: any, stats: { [string]: any })
	local newly = AchievementConfig.Evaluate(stats, replica.Data.AchievementsUnlocked or {})
	if #newly == 0 then
		return
	end
	local unlocked = copy(replica.Data.AchievementsUnlocked)
	for _, id in ipairs(newly) do
		unlocked[id] = true
	end
	replica:SetValue("AchievementsUnlocked", unlocked)
	for _, id in ipairs(newly) do
		local a = AchievementConfig.Get(id)
		if a then
			AchievementEvent:FireClient(player, "unlocked", { id = a.id, title = a.title, icon = a.icon,
				category = a.category, reward = a.reward })
			print(("[Achievements] %s unlocked %s"):format(player.Name, a.id))
		end
	end
end

--- Count something toward achievements. `detail.distance` on a kill can make it a long shot;
--- `detail.place` names where a "travel" went.
function AchievementService.Note(player: Player, kind: string, amount: number?, detail: any?)
	local replica = replicas[player]
	if not replica then
		return
	end
	if kind == "kill" and type(detail) == "table" and type(detail.distance) == "number" and detail.distance >= 120 then
		AchievementService.Note(player, "longkill", 1)
	end
	if kind == "travel" then
		local place = type(detail) == "table" and detail.place or nil
		if type(place) ~= "string" then
			return
		end
		local visited = copy(replica.Data.AchievementPlaces)
		if visited[place] then
			return
		end
		visited[place] = true
		replica:SetValue("AchievementPlaces", visited)
		local count = 0
		for _ in pairs(visited) do
			count += 1
		end
		kind, amount = "place", count
		local stats = copy(replica.Data.AchievementStats)
		stats.place = count
		replica:SetValue("AchievementStats", stats)
		unlockFrom(player, replica, stats)
		return
	end
	if not KINDS[kind] then
		return
	end
	local stats = AchievementConfig.Count(replica.Data.AchievementStats or {}, kind, amount or 1)
	replica:SetValue("AchievementStats", stats)
	unlockFrom(player, replica, stats)
end

local function pay(player: Player, replica: any, reward: AchievementConfig.Reward)
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value += reward.coins
	end
	if reward.crystals and reward.crystals > 0 then
		replica:SetValue("Crystals", (tonumber(replica.Data.Crystals) or 0) + reward.crystals)
	end
	if reward.xp and reward.xp > 0 then
		task.spawn(LevelSystem.AwardXP, player, reward.xp)
	end
	if reward.title then
		local titles = table.clone(replica.Data.Titles or {})
		if not table.find(titles, reward.title) then
			table.insert(titles, reward.title)
			replica:SetValue("Titles", titles)
		end
	end
end

--- Everything the panel shows.
function AchievementService.State(player: Player)
	local replica = replicas[player]
	if not replica then
		return nil
	end
	local data = replica.Data
	local stats = data.AchievementStats or {}
	local unlocked = data.AchievementsUnlocked or {}
	local claimed = data.AchievementsClaimed or {}
	local others = 0
	for id in pairs(unlocked) do
		local a = AchievementConfig.Get(id)
		if a and a.kind ~= "achievement" then
			others += 1
		end
	end
	local list = {}
	local done, ready = 0, 0
	for _, a in ipairs(AchievementConfig.List) do
		local value = a.kind == "achievement" and others or (tonumber(stats[a.kind]) or 0)
		local isUnlocked = unlocked[a.id] == true
		local isClaimed = claimed[a.id] == true
		if isUnlocked then
			done += 1
			if not isClaimed then
				ready += 1
			end
		end
		table.insert(list, {
			id = a.id, category = a.category, icon = a.icon, title = a.title, text = a.text,
			goal = a.goal, progress = math.min(value, a.goal), unlocked = isUnlocked, claimed = isClaimed,
			reward = a.reward,
		})
	end
	return {
		list = list, done = done, total = #AchievementConfig.List, ready = ready,
		titles = table.clone(data.Titles or {}), equipped = data.EquippedTitle or "",
	}
end

function AchievementService.Claim(player: Player, id: string): (boolean, string?)
	local replica = replicas[player]
	local a = AchievementConfig.Get(id)
	if not replica or not a then
		return false, "Unknown achievement"
	end
	local unlocked = replica.Data.AchievementsUnlocked or {}
	local claimed = copy(replica.Data.AchievementsClaimed)
	if unlocked[id] ~= true then
		return false, "Not unlocked yet"
	end
	if claimed[id] == true then
		return false, "Already claimed"
	end
	claimed[id] = true
	replica:SetValue("AchievementsClaimed", claimed)
	pay(player, replica, a.reward)
	print(("[Achievements] %s claimed %s"):format(player.Name, id))
	return true, nil
end

function AchievementService.Equip(player: Player, title: string): boolean
	local replica = replicas[player]
	if not replica then
		return false
	end
	if title ~= "" and not table.find(replica.Data.Titles or {}, title) then
		return false
	end
	replica:SetValue("EquippedTitle", title)
	player:SetAttribute("Title", title ~= "" and title or nil)
	return true
end

AchievementAction.OnServerInvoke = function(player: Player, action: unknown, arg: unknown)
	if action == "state" then
		return AchievementService.State(player)
	elseif action == "claim" and type(arg) == "string" then
		local ok, why = AchievementService.Claim(player, arg)
		return { ok = ok, reason = why, state = AchievementService.State(player) }
	elseif action == "equip" and type(arg) == "string" then
		local ok = AchievementService.Equip(player, arg)
		return { ok = ok, state = AchievementService.State(player) }
	end
	return nil
end

ContractService.Noted.Event:Connect(function(player: Player, kind: string, amount: number?, detail: any?)
	if typeof(player) == "Instance" and player:IsA("Player") and type(kind) == "string" then
		AchievementService.Note(player, kind, amount, detail)
	end
end)

local function onPlayer(player: Player)
	task.spawn(function()
		local ok, replica = pcall(function()
			return PlayerDataManager:GetPlayerDataReplica(player):expect()
		end)
		if not ok or not replica or not player.Parent then
			return
		end
		replicas[player] = replica
		local title = replica.Data.EquippedTitle
		if type(title) == "string" and title ~= "" then
			player:SetAttribute("Title", title)
		end
		-- Everyone starts at the crossing, so it counts as visited.
		AchievementService.Note(player, "travel", 1, { place = "Hub" })
		local function level()
			local lv = tonumber(player:GetAttribute("Level"))
			if lv then
				AchievementService.Note(player, "level", lv)
			end
		end
		level()
		player:GetAttributeChangedSignal("Level"):Connect(level)
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end
Players.PlayerRemoving:Connect(function(player)
	replicas[player] = nil
end)

return AchievementService
