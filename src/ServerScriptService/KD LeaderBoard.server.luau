local Players = game:GetService("Players")
local dataStore = game:GetService("DataStoreService")
local data = dataStore:GetDataStore("Stats")

-- This script owns leaderstats setup and Deaths.
-- Kills are awarded by ServerScriptService.KillCredit, which tags the attacker onto
-- the victim before damage lands and credits them when the victim dies. That covers
-- players and NPCs, so nothing here needs to know where the damage came from.

local function onCharacterAdded(player, deaths, character)
	local humanoid = character:WaitForChild("Humanoid")

	-- One connection per humanoid. A respawn brings a new humanoid, so this is safe.
	humanoid.Died:Connect(function()
		-- Every death counts, however it happened -- combat, falling, the void.
		deaths.Value += 1
	end)
end

local function onPlayerAdded(player)
	-- Create leaderstats
	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	-- Kills stat
	local kills = Instance.new("IntValue")
	kills.Name = "Kills"
	kills.Value = 0
	kills.Parent = leaderstats

	-- Deaths stat
	local deaths = Instance.new("IntValue")
	deaths.Name = "Deaths"
	deaths.Value = 0
	deaths.Parent = leaderstats

	-- Coin stat
	local Coins = Instance.new("IntValue")
	Coins.Name = "Coins"
	Coins.Value = 0
	Coins.Parent = leaderstats

	local ok, CoinsValue = pcall(function()
		return data:GetAsync(player.UserId .. "-Coins")
	end)

	if ok then
		if CoinsValue ~= nil then
			Coins.Value = CoinsValue
		end
	else
		warn("Could not load Coins for " .. player.Name .. ": " .. tostring(CoinsValue))
	end

	player.CharacterAdded:Connect(function(character)
		onCharacterAdded(player, deaths, character)
	end)

	-- In Studio playtests the character often exists before this script connects,
	-- and CharacterAdded never fires for it. Without this, the first life of the
	-- session records no death.
	if player.Character then
		task.spawn(onCharacterAdded, player, deaths, player.Character)
	end
end

local function onPlayerRemoving(player)
	local stats = player:FindFirstChild("leaderstats")
	local Coins = stats and stats:FindFirstChild("Coins")
	if not Coins then
		return
	end

	local success, errorMsg = pcall(function()
		data:SetAsync(player.UserId .. "-Coins", Coins.Value)
	end)

	if not success then
		warn("Could not save Coins for " .. player.Name .. ": " .. tostring(errorMsg))
	end
end

-- Connected once at the top level. Previously PlayerRemoving was connected inside
-- PlayerAdded, so every join added another handler and one player leaving fired a
-- duplicate DataStore write for each player who had ever joined that server.
Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

-- Same race as the character one: catch anybody who joined before this ran.
for _, player in ipairs(Players:GetPlayers()) do
	if not player:FindFirstChild("leaderstats") then
		task.spawn(onPlayerAdded, player)
	end
end
