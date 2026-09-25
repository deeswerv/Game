--!strict
-- Coins, kept on the profile so they save.
--
-- Coins predate the profile. They live on leaderstats.Coins (which the HUD, the shop and a
-- dozen payouts read and write) and were saved by two legacy scripts into two different
-- DataStores -- "Stats" and "SaveLeaderstats" -- each of which loaded its own copy back on
-- join. Whichever load answered last won, so a balance could come back as the other
-- store's older figure: exactly how coins set from the owner panel "only lasted a while".
--
-- Now the profile is the one record. On join the balance is read from it and put on
-- leaderstats; every change to leaderstats is written straight back, so every existing
-- `coins.Value += n` in the game saves without being touched. The first time a profile is
-- seen, the legacy stores are read once and the HIGHEST of all the figures is kept, so
-- nobody loses coins in the move. The legacy scripts no longer load or save coins.

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataManager = require(ServerScriptService.PlayerDataManager)

local WalletService = {}

WalletService.MAX = 1e9

local ready: { [Player]: boolean } = {}

local function legacyBalance(player: Player): number
	local best = 0
	pcall(function()
		local store = DataStoreService:GetDataStore("Stats")
		best = math.max(best, tonumber(store:GetAsync(player.UserId .. "-Coins")) or 0)
	end)
	pcall(function()
		local store = DataStoreService:GetDataStore("SaveLeaderstats")
		local saved = store:GetAsync(tostring(player.UserId))
		if type(saved) == "table" then
			best = math.max(best, tonumber(saved.Coins) or 0)
		end
	end)
	return best
end

local function coinsOf(player: Player): IntValue?
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	return (coins and coins:IsA("IntValue")) and coins or nil
end

local function attach(player: Player)
	local stats = player:WaitForChild("leaderstats", 30)
	local coins = stats and stats:WaitForChild("Coins", 10)
	if not coins or not coins:IsA("IntValue") then
		warn("[Wallet] no leaderstats.Coins for " .. player.Name)
		return
	end
	local ok, Replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
	end)
	if not ok or not Replica or not player.Parent then
		return
	end

	local balance = math.max(0, math.floor(tonumber(Replica.Data.Coins) or 0))
	if Replica.Data.CoinsMigrated ~= true then
		balance = math.max(balance, legacyBalance(player), coins.Value)
		Replica:SetValue("CoinsMigrated", true)
		print(("[Wallet] %s: coins moved onto the profile (%d)"):format(player.Name, balance))
	end
	balance = math.clamp(balance, 0, WalletService.MAX)
	Replica:SetValue("Coins", balance)
	coins.Value = balance
	ready[player] = true

	coins:GetPropertyChangedSignal("Value"):Connect(function()
		local value = math.clamp(math.floor(coins.Value), 0, WalletService.MAX)
		if value ~= coins.Value then
			coins.Value = value
			return
		end
		if Replica:IsActive() and Replica.Data.Coins ~= value then
			Replica:SetValue("Coins", value)
		end
	end)
end

--- Whether a player's balance has been loaded from their profile yet.
function WalletService.IsReady(player: Player): boolean
	return ready[player] == true
end

--- Set a balance outright. Returns the balance it was set to, or nil if not loaded yet.
function WalletService.Set(player: Player, amount: number): number?
	local coins = coinsOf(player)
	if not coins or not ready[player] then
		return nil
	end
	coins.Value = math.clamp(math.floor(tonumber(amount) or 0), 0, WalletService.MAX)
	return coins.Value
end

--- Add (or with a negative amount, take) coins. Returns the new balance.
function WalletService.Add(player: Player, amount: number): number?
	local coins = coinsOf(player)
	if not coins or not ready[player] then
		return nil
	end
	return WalletService.Set(player, coins.Value + math.floor(tonumber(amount) or 0))
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(attach, player)
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(attach, player)
end
Players.PlayerRemoving:Connect(function(player)
	ready[player] = nil
end)

return WalletService
