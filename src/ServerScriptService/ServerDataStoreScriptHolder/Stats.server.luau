-- SERVICES --
local RS = game:GetService("ReplicatedStorage")
local SSS = game:GetService("ServerScriptService")

-- FOLDERS --
local Remotes = RS:WaitForChild("Remotes")

-- EVENTS --
local statsEvent = Remotes.statsEvent

-- MAIN --
local PlayerDataManager = require(SSS.PlayerDataManager)

-- FUNCTIONS --
statsEvent.OnServerEvent:Connect(function(Player, Action, StatName)
	local pStats = Player:WaitForChild("Stats")
	local pStatus = Player:WaitForChild("Status")
	local pStatPoints = pStats.StatPoints
	
	if Action == "AddPoint" then
		if pStatPoints.Value > 0 then
			if pStatus:FindFirstChild(StatName) then
				PlayerDataManager:GetPlayerDataReplica(Player):andThen(function(Replica)
					Replica:SetValue(StatName, Replica.Data[StatName] + 1)
					Replica:SetValue("StatPoints", Replica.Data.StatPoints - 1)
					pStatus[StatName].Value = Replica.Data[StatName]
					pStatPoints.Value = Replica.Data.StatPoints
				end)
			end
		end
	elseif Action == "Reset" then
		PlayerDataManager:GetPlayerDataReplica(Player):andThen(function(Replica)
			local STR = Replica.Data.Strength
			local DEF = Replica.Data.Defense
			local STA = Replica.Data.Stamina
		
		
			
			local totalPoints = STR + DEF + STA 
			warn("Total Points: "..totalPoints)
			Replica:SetValue("Strength", 0) 
			Replica:SetValue("Defense", 0) 
			Replica:SetValue("Stamina", 0) 
			
			
			Replica:SetValue("StatPoints", Replica.Data.StatPoints + totalPoints) 
		end)
	end
end)
