local Players = game:GetService("Players")
-- Coins used to be loaded and saved here, from the "Stats" DataStore. They are on the
-- player's profile now (WalletService), which migrated this store's figure once.

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

	-- The balance is loaded (and saved) by WalletService, from the player's profile. This
	-- used to load its own copy from the "Stats" store, racing a second legacy script that
	-- loaded another copy from "SaveLeaderstats" -- whichever answered last won.

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

-- Coins are saved with the profile by WalletService; nothing to write here any more.
local function onPlayerRemoving(_player) end

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
