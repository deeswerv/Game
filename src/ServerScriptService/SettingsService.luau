--!strict
-- Saves the player's settings panel to their profile, so volumes, camera shake and field of
-- view follow them between sessions. The client applies settings itself (they are all local
-- things -- its own camera, its own mix); the server only validates and stores them.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local SettingsConfig = require(ReplicatedStorage.SettingsConfig)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)

local SettingsService = {}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local SettingsAction = remotes:FindFirstChild("SettingsAction") :: RemoteFunction?
if not SettingsAction then
	local created = Instance.new("RemoteFunction")
	created.Name = "SettingsAction"
	created.Parent = remotes
	SettingsAction = created
end

-- A slider dragged across its range asks to save on release, not per pixel -- but a client
-- is not trusted to behave, so writes are spaced out here too.
local MIN_GAP = 0.25
local lastWrite: { [Player]: number } = {}

local function replicaOf(player: Player): any?
	local ok, replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
	end)
	return ok and replica or nil
end

;(SettingsAction :: RemoteFunction).OnServerInvoke = function(player: Player, action: unknown, values: unknown)
	local replica = replicaOf(player)
	if action == "get" then
		return SettingsConfig.Resolve(replica and replica.Data.Settings or nil)
	elseif action == "set" then
		if not replica or typeof(values) ~= "table" then
			return { ok = false }
		end
		local now = os.clock()
		if lastWrite[player] and now - lastWrite[player] < MIN_GAP then
			return { ok = false, reason = "Too fast" }
		end
		lastWrite[player] = now
		local current = SettingsConfig.Resolve(replica.Data.Settings)
		for id, value in pairs(values :: { [any]: any }) do
			if typeof(id) == "string" and SettingsConfig.Get(id) then
				current[id] = SettingsConfig.Clean(id, value) :: number
			end
		end
		replica:SetValue("Settings", current)
		return { ok = true, settings = current }
	end
	return { ok = false }
end

Players.PlayerRemoving:Connect(function(player)
	lastWrite[player] = nil
end)

return SettingsService
