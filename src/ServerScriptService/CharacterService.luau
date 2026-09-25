--!strict
-- Character stats: where the points every level grants actually get spent.
--
-- The profile has carried StatPoints, Strength, Defense and Stamina since the start, and
-- LevelSystem grants three points a level -- but the panel that spent them was gone, so the
-- points piled up and did nothing. This is the other half: the server end of the Character
-- panel, and the stats doing something you can feel.
--
--   Strength   more damage against enemies and bosses (KillCredit.Damage)
--   Defense    more maximum health (LevelSystem.ApplyVitality)
--   Stamina    faster movement (published as SpeedBonus; ShiftLock owns WalkSpeed)
--
-- None of it follows a player into a duel. The arena is a fair fight -- the bonuses read zero
-- while DuelState is "duel", and Strength only ever applies to NPCs anyway.
--
-- The client asks; the server decides. Every request is re-validated against the profile:
-- which stat, how many points, whether they have them, whether the stat has room.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CharacterConfig = require(ReplicatedStorage.CharacterConfig)
local GameConfig = require(ReplicatedStorage.GameConfig)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local LevelSystem = require(ServerScriptService.LevelSystem)

local CharacterService = {}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local StatAction = remotes:FindFirstChild("StatAction") :: RemoteFunction?
if not StatAction then
	local created = Instance.new("RemoteFunction")
	created.Name = "StatAction"
	created.Parent = remotes
	StatAction = created
end

local MAX_BATCH = 10               -- points in one request (the panel's +5 button)
local busy: { [Player]: boolean } = {}

local function replicaOf(player: Player): any?
	local ok, replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
	end)
	return ok and replica or nil
end

local function statValue(data, id: string): number
	return math.max(0, math.floor(tonumber(data[id]) or 0))
end

--- Everything the panel draws, from this player's profile.
local function stateOf(player: Player, data)
	local stats = {}
	for _, stat in ipairs(CharacterConfig.Stats) do
		stats[stat.id] = statValue(data, stat.id)
	end
	return {
		points = statValue(data, "StatPoints"),
		stats = stats,
		level = tonumber(data.Level) or 1,
		exp = tonumber(data.EXP) or 0,
		maxExp = tonumber(data.MaxEXP) or 100,
		prestige = tonumber(data.Prestige) or 0,
		max = CharacterConfig.MAX_PER_STAT,
		perLevel = GameConfig.Leveling.STAT_POINTS_PER_LEVEL,
		inDuel = player:GetAttribute("DuelState") == "duel",
	}
end

--- Stats as attributes: the HUD badge and the movement script read these, and attributes
--- replicate for free. Written only by the server, so nothing a client says can move them.
local function publish(player: Player, data)
	player:SetAttribute("StatPoints", statValue(data, "StatPoints"))
	for _, stat in ipairs(CharacterConfig.Stats) do
		player:SetAttribute(stat.id, statValue(data, stat.id))
	end
	local inDuel = player:GetAttribute("DuelState") == "duel"
	player:SetAttribute("SpeedBonus", inDuel and 0 or CharacterConfig.Bonus("Stamina", data.Stamina))
end

function CharacterService.State(player: Player)
	local replica = replicaOf(player)
	if not replica then
		return nil
	end
	return stateOf(player, replica.Data)
end

function CharacterService.Add(player: Player, id: unknown, count: unknown)
	if typeof(id) ~= "string" or not CharacterConfig.Get(id) then
		return { ok = false, reason = "Unknown stat" }
	end
	local replica = replicaOf(player)
	if not replica then
		return { ok = false, reason = "Your data is still loading" }
	end
	local data = replica.Data
	local wanted = math.clamp(math.floor(tonumber(count) or 1), 1, MAX_BATCH)
	local points = statValue(data, "StatPoints")
	local current = statValue(data, id)
	local spend = math.min(wanted, points, CharacterConfig.MAX_PER_STAT - current)
	if spend <= 0 then
		return {
			ok = false,
			reason = points <= 0 and "No stat points left -- level up to earn more"
				or ("%s is maxed"):format(string.lower(id)),
			state = stateOf(player, data),
		}
	end
	replica:SetValue(id, current + spend)
	replica:SetValue("StatPoints", points - spend)
	publish(player, replica.Data)
	if id == "Defense" then
		LevelSystem.ApplyVitality(player)
	end
	return { ok = true, spent = spend, state = stateOf(player, replica.Data) }
end

--- Every point back, to spend again. Free: experimenting with a build should not cost.
function CharacterService.Reset(player: Player)
	local replica = replicaOf(player)
	if not replica then
		return { ok = false, reason = "Your data is still loading" }
	end
	local data = replica.Data
	local refund = 0
	for _, stat in ipairs(CharacterConfig.Stats) do
		refund += statValue(data, stat.id)
	end
	if refund == 0 then
		return { ok = false, reason = "Nothing to refund", state = stateOf(player, data) }
	end
	for _, stat in ipairs(CharacterConfig.Stats) do
		replica:SetValue(stat.id, 0)
	end
	replica:SetValue("StatPoints", statValue(data, "StatPoints") + refund)
	publish(player, replica.Data)
	LevelSystem.ApplyVitality(player)
	return { ok = true, refunded = refund, state = stateOf(player, replica.Data) }
end

;(StatAction :: RemoteFunction).OnServerInvoke = function(player: Player, action: unknown, id: unknown, count: unknown)
	if action == "state" then
		return CharacterService.State(player)
	end
	-- One change at a time per player, so two quick clicks cannot both spend the last point.
	if busy[player] then
		return { ok = false, reason = "Busy" }
	end
	busy[player] = true
	local ok, result = pcall(function()
		if action == "add" then
			return CharacterService.Add(player, id, count)
		elseif action == "reset" then
			return CharacterService.Reset(player)
		end
		return { ok = false, reason = "Unknown action" }
	end)
	busy[player] = nil
	if not ok then
		warn("[Character] " .. tostring(result))
		return { ok = false, reason = "Something went wrong" }
	end
	return result
end

local function onPlayer(player: Player)
	PlayerDataManager:GetPlayerDataReplica(player):andThen(function(replica)
		publish(player, replica.Data)
		-- Levelling grants points from LevelSystem; keep the attributes in step with that too.
		replica:ListenToChange("StatPoints", function()
			publish(player, replica.Data)
		end)
		-- Crystals, for the HUD. Mines, dailies, milestones and mastery all pay them into the
		-- profile; the client could not see any of it until now.
		player:SetAttribute("Crystals", tonumber(replica.Data.Crystals) or 0)
		replica:ListenToChange("Crystals", function(value)
			player:SetAttribute("Crystals", tonumber(value) or 0)
		end)
	end):catch(function(err)
		warn("[Character] could not load stats for " .. player.Name .. ": " .. tostring(err))
	end)
	-- Entering or leaving a duel switches the bonuses off and on.
	player:GetAttributeChangedSignal("DuelState"):Connect(function()
		local replica = replicaOf(player)
		if replica then
			publish(player, replica.Data)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, player)
end
Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)

print("[Character] stat points open")

return CharacterService
