--!strict
local Players = game:GetService("Players")

local ReplicaService = require(game:GetService("ReplicatedStorage").Replica.ReplicaServiceListeners)
local ProfileService = require(game:GetService("ReplicatedStorage").AutoSave)
local Promise = require(game:GetService("ReplicatedStorage").InterceptValue)
local SaveStructure = require(script.SaveStructure)

local Profiles = {}
local Replicas = {}
local PlayerProfileClassToken = ReplicaService.NewClassToken("PlayerData")
local ProfileStore = ProfileService.GetProfileStore("PlayerData", SaveStructure)

local PlayerDataManager = {}

function PlayerDataManager:GetPlayerDataReplica(Player: Player)
	return Promise.new(function(Resolve, Reject)
		assert(typeof(Player) == "Instance" and Player:IsDescendantOf(Players), "Value passed is not a valid player")

		if not Profiles[Player] and not Replicas[Player] then
			repeat 
				if Player and Player:IsDescendantOf(Players) then
					wait()
				else
					Reject("Player left the game")
				end
			until Profiles[Player] and Replicas[Player]
		end

		local Profile = Profiles[Player]
		local Replica = Replicas[Player]
		if Profile and Profile:IsActive() then
			if Replica and Replica:IsActive() then
				Resolve(Replica)
			else
				Reject("Replica did not exist or wasn't active")

			end
		else
			Reject("Profile did not exist or wasn't active")
		end
	end)
end

function PlayerDataManager:GetPlayerProfile(Player: Player)
	return Promise.new(function(Resolve, Reject)
		assert(typeof(Player) == "Instance" and Player:IsDescendantOf(Players), "Value passed is not a valid player")

		if not Profiles[Player] and not Replicas[Player] then
			repeat 
				if Player and Player:IsDescendantOf(Players) then
					wait()
				else
					Reject("Player left the game")
				end
			until Profiles[Player] and Replicas[Player]
		end

		local Profile = Profiles[Player]
		local Replica = Replicas[Player]
		if Profile and Profile:IsActive() then
			if Replica and Replica:IsActive() then
				Resolve(Profile)
			else
				Reject("Replica did not exist or wasn't active")

			end
		else
			Reject("Profile did not exist or wasn't active")
		end
	end)
end


--- Write the profile to the DataStore now rather than at the next autosave. For changes
--- worth not losing to a crash in the next thirty seconds -- an owner grant, a prestige.
function PlayerDataManager:SaveNow(Player: Player): boolean
	local profile = Profiles[Player]
	if profile and profile:IsActive() then
		local ok = pcall(function()
			profile:Save()
		end)
		return ok
	end
	return false
end

--- Whether profiles are really being saved. False in Studio without API access, where
--- ProfileService quietly runs on a mock store and nothing outlives the session. Can yield.
function PlayerDataManager:IsSaving(): boolean
	local ok, live = pcall(function()
		return ProfileService.IsLive()
	end)
	return ok and live == true
end

local function PlayerAdded(Player: Player)
	local StartTime = tick()
	local Profile = ProfileStore:LoadProfileAsync("Player_" .. Player.UserId)

	if Profile then
		Profile:AddUserId(Player.UserId)
		Profile:Reconcile()

		Profile:ListenToRelease(function()
			Profiles[Player] = nil
			Replicas[Player]:Destroy()
			Replicas[Player]= nil
			Player:Kick("Profile was released")

		end)

		if Player:IsDescendantOf(Players) == true then
			Profiles[Player] = Profile
			local Replica = ReplicaService.NewReplica({
				ClassToken = PlayerProfileClassToken,
				Tags = {["Player"] = Player},
				Data = Profile.Data,
				Replication = "All"
			})

			Replicas[Player] = Replica
			warn(Player.Name.. "'s profile has been loaded. ".."("..string.sub(tostring(tick()-StartTime),1,5)..")")
		else
			Profile:Release()
		end
	else
		Player:Kick("Profile == nil") 
	end
end

-- Say plainly, once, if nothing this session will be kept. A place opened from a file has
-- never been published, so Roblox gives it no DataStores at all; a published place still needs
-- Studio's API access turned on. Either way ProfileService quietly runs on a stand-in store
-- and every level, coin and unlock is gone when the test stops -- which looks exactly like
-- "the owner panel does not save".
task.spawn(function()
	if not PlayerDataManager:IsSaving() then
		warn("[Data] NOT SAVING THIS SESSION: DataStores are unavailable. Publish the place (File > Publish to"
			.. " Roblox) and turn on Game Settings > Security > Enable Studio Access to API Services, or test in"
			.. " the live game. Until then levels, coins and unlocks last only until the test stops.")
	else
		print("[Data] saving to DataStores")
	end
end)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(PlayerAdded, player)
end

Players.PlayerAdded:Connect(PlayerAdded)

Players.PlayerRemoving:Connect(function(Player)
	if Profiles[Player] then
		Profiles[Player]:Release()
	end
end)


return PlayerDataManager
