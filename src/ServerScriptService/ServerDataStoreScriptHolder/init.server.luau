local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local Remotes = RS:WaitForChild("Remotes")

local statsEvent = Remotes.statsEvent
local replicate = Remotes.Replicate
local uiReplicator = Remotes.UIReplicator

local questModule = require(script:WaitForChild("Quests"))

local PlayerDataManager = require(game:GetService("ServerScriptService").PlayerDataManager)

Players.PlayerAdded:Connect(function(Player)
	local pStats = Instance.new("Folder")
	pStats.Name = "Stats"
	pStats.Parent = Player

	local pStatus = Instance.new("Folder")
	pStatus.Name = "Status"
	pStatus.Parent = Player

	local pQuests = Instance.new("Folder")
	pQuests.Name = "Quests"
	pQuests.Parent = Player
	
	local goldValue = Instance.new("IntValue")
	goldValue.Name = "Gold"
	goldValue.Parent = pStats

	local levelValue = Instance.new("IntValue")
	levelValue.Name = "Level"
	levelValue.Parent = pStats

	local expVal = Instance.new("IntValue")
	expVal.Name = "EXP"
	expVal.Parent = pStats

	local maxExpVal = Instance.new("IntValue")
	maxExpVal.Name = "MaxEXP"
	maxExpVal.Parent = pStats

	local maxStaminaVal = Instance.new("IntValue")
	maxStaminaVal.Name = "MaxStamina"
	maxStaminaVal.Parent = pStats

	local staminaVal = Instance.new("IntValue")
	staminaVal.Name = "Stamina"
	staminaVal.Parent = Player

	local staminaStatVal = Instance.new("IntValue")
	staminaStatVal.Name = "Stamina"
	staminaStatVal.Parent = pStatus

	local strengthVal = Instance.new("IntValue")
	strengthVal.Name = "Strength"
	strengthVal.Parent = pStatus

	local defenseVal = Instance.new("IntValue")
	defenseVal.Name = "Defense"
	defenseVal.Parent = pStatus



	local statPointsVal = Instance.new("IntValue")
	statPointsVal.Name = "StatPoints"
	statPointsVal.Parent = pStats

	local currentQuest = Instance.new("StringValue")
	currentQuest.Name = "CurrentQuest"
	currentQuest.Parent = pQuests

	local questProgress = Instance.new("IntValue")
	questProgress.Name = "QuestProgress"
	questProgress.Parent = pQuests

	--Listening for changes
	PlayerDataManager:GetPlayerDataReplica(Player):andThen(function(Replica)
		Replica:ListenToChange("Gold", function(NewValue, OldValue)
			goldValue.Value = NewValue
		end)

		Replica:ListenToChange("Level", function(NewValue, OldValue)
			levelValue.Value = NewValue
		end)

		Replica:ListenToChange("CurrentQuest", function(NewValue, OldValue)
			currentQuest.Value = NewValue
			local quest = questModule.Quests[NewValue]
			if quest and NewValue ~= OldValue then
				Replica:SetValue("QuestProgress", 0)
				uiReplicator:FireClient(Player, "Quest", Replica.Data.QuestProgress, Replica.Data.CurrentQuest, quest.Target, quest.Rewards, quest.Amount)
			end
		end)

		Replica:ListenToChange("QuestProgress", function(NewValue, OldValue)
			questProgress.Value = NewValue
			local quest = questModule.Quests[Replica.Data.CurrentQuest]
			if quest then
				if NewValue >= quest.Amount then
					Replica:SetValue("QuestProgress", 0)
					Replica:SetValue("Gold", (Replica.Data.Gold or 0) + (quest.Gold or 0))
					-- Through LevelSystem, like every other XP award, so it levels up by the
					-- real curve and stops at the cap.
					local LevelSystem = require(game:GetService("ServerScriptService").LevelSystem) :: any
					LevelSystem.AwardXP(Player, quest.EXP or 0)
					Replica:SetValue("CurrentQuest", "None") 
					uiReplicator:FireClient(Player, "Quest", Replica.Data.QuestProgress, Replica.Data.CurrentQuest, quest.Target, quest.Rewards, quest.Amount)

				elseif NewValue < quest.Amount then
					uiReplicator:FireClient(Player, "Quest", Replica.Data.QuestProgress, Replica.Data.CurrentQuest, quest.Target, quest.Rewards, quest.Amount)
				end
			end
		end)
		
		if not Player.Character then
			Player.CharacterAdded:Connect(function()
				local quest = questModule.Quests[Replica.Data.CurrentQuest]
				if quest then
					uiReplicator:FireClient(Player, "Quest", Replica.Data.QuestProgress, Replica.Data.CurrentQuest, quest.Target, quest.Rewards, quest.Amount)
				end
				
				uiReplicator:FireClient(Player, "EXP", Replica.Data.EXP, Replica.Data.MaxEXP, Replica.Data.Level)
			end)
		else
			local quest = questModule.Quests[Replica.Data.CurrentQuest]
			if quest then
				uiReplicator:FireClient(Player, "Quest", Replica.Data.QuestProgress, Replica.Data.CurrentQuest, quest.Target, quest.Rewards, quest.Amount)
			end
			
			uiReplicator:FireClient(Player, "EXP", Replica.Data.EXP, Replica.Data.MaxEXP, Replica.Data.Level)
		end
		
		
		-- Mirror only. This used to run its own level-up whenever EXP reached MaxEXP -- a
		-- second rule beside LevelSystem's, on a different curve (MaxEXP * 1.1) and with no
		-- cap. LevelSystem writes EXP before MaxEXP, so a remainder between the old and new
		-- bar sizes tripped it: one kill, two levels, and nothing stopped it passing the cap.
		-- LevelSystem is the only thing that levels anyone up now.
		Replica:ListenToChange("EXP", function(NewValue, OldValue)
			expVal.Value = NewValue
		end)

		Replica:ListenToChange("MaxStamina", function(NewValue, OldValue)
			maxStaminaVal.Value = NewValue
		end)

		Replica:ListenToChange("MaxEXP", function(NewValue, OldValue)
			maxExpVal.Value = NewValue
		end)

		Replica:ListenToChange("Strength", function(NewValue, OldValue)
			print(Player.Name .. "'s Strength has been changed on the server: " .. tostring(NewValue))
			strengthVal.Value = NewValue
		end)

		Replica:ListenToChange("Defense", function(NewValue, OldValue)
			print(Player.Name .. "'s Defense has been changed on the server: " .. tostring(NewValue))
			defenseVal.Value = NewValue
		end)

		Replica:ListenToChange("Stamina", function(NewValue, OldValue)
			print(Player.Name .. "'s Stamina has been changed on the server: " .. tostring(NewValue))
			staminaStatVal.Value = NewValue
		end)

	

		Replica:ListenToChange("StatPoints", function(NewValue, OldValue)
			print(Player.Name .. "'s Stat Points has been changed on the server: " .. tostring(NewValue))
			statPointsVal.Value = NewValue
		end)
	end)

	task.delay(.15, function()
		PlayerDataManager:GetPlayerProfile(Player):andThen(function(Profile)
			local data = Profile.Data

			-- This used to be warn(Profile.Data), which dumped the entire profile -- every
			-- quest, every build, every skin, every owned item -- into the console on every
			-- single join. One line saying it loaded is the useful part of that.
			print(string.format("[Data] %s loaded: level %s, %s builds, %s owned items",
				Player.Name, tostring(data.Level),
				tostring(data.WeaponBuilds and #(next(data.WeaponBuilds) and data.WeaponBuilds or {}) or 0),
				tostring(data.OwnedItems and #data.OwnedItems or 0)))

			-- Defaults on every read.
			--
			-- goldValue was being assigned Profile.Data.Gold, and there is no Gold field in
			-- the save structure -- currency is Coins, on leaderstats. So this line threw
			-- "value of type nil cannot be converted to a number" on every join, and because
			-- it threw, every assignment BELOW it was skipped: stamina, strength, defense,
			-- stat points and quest progress were silently never loaded at all.
			expVal.Value = data.EXP or 0
			levelValue.Value = data.Level or 1
			maxStaminaVal.Value = data.MaxStamina or 100
			maxExpVal.Value = data.MaxEXP or 100
			goldValue.Value = data.Gold or 0
			staminaVal.Value = data.MaxStamina or 100
			strengthVal.Value = data.Strength or 0
			staminaStatVal.Value = data.Stamina or 0
			defenseVal.Value = data.Defense or 0

			statPointsVal.Value = data.StatPoints or 0
			currentQuest.Value = data.CurrentQuest or ""
			questProgress.Value = data.QuestProgress or 0
		end)
	end)

end)