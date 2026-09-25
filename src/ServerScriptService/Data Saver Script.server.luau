local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
-- Guarded: GetDataStore throws in an unpublished place and without Studio API access.
local okStore, Saver = pcall(function()
	return DataStoreService:GetDataStore("SaveLeaderstats")
end)
if not okStore then
	warn("[DataSaver] DataStores unavailable; leaderstats will not be saved this session")
	return
end

Players.PlayerAdded:Connect(function(player)
	local Data = nil
	local success, errormessage = pcall(function()
		Data = Saver:GetAsync(tostring(player.UserId))
	end)

	if success then
		if Data then
			for i, v in pairs(Data) do
				player:WaitForChild("leaderstats"):WaitForChild(i).Value = v
			end
		end
	else
		warn("[DataSaver] could not load " .. player.Name .. ": " .. tostring(errormessage))
	end
end)

local function Save(player)
	local SavedData = {}
	for _, v in pairs(player.leaderstats:GetChildren()) do
		SavedData[v.Name] = v.Value
	end

	local success, errormessage = pcall(function()
		Saver:SetAsync(tostring(player.UserId), SavedData)
	end)
	if not success then
		warn("[DataSaver] could not save " .. player.Name .. ": " .. tostring(errormessage))
	end
end

Players.PlayerRemoving:Connect(Save)

game:BindToClose(function()
	for _, v in pairs(Players:GetPlayers()) do
		Save(v)
	end
end)
