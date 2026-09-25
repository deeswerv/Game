--!strict
-- Kill streaks and bounties: the longer you survive out in the world, the more you are worth.
--
--   3 kills without dying   KILLING SPREE (just for you)
--   5                       WANTED: a price goes on your head, everybody is told, and a red
--                           tag floats over you that shows through walls
--   every kill after        the price climbs, up to a cap
--   8, 12                   RAMPAGE, UNSTOPPABLE
--
-- Whoever takes a WANTED player down collects the price (cash and XP), and the whole server
-- hears about it. Dying any other way just ends the streak. Duels do not count -- they are
-- their own fight with their own reward -- and nor do the range's practice dummies.
--
-- Server-owned: the price lives on the player as the "Bounty" attribute (so every client can
-- draw the tag), and this service is the only thing that sets it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local KillCredit = require(ServerScriptService.KillCredit)
local LevelSystem = require(ServerScriptService.LevelSystem)

local BountyService = {}

BountyService.WANTED_AT = 5
BountyService.BASE = 600
BountyService.PER_KILL = 200
BountyService.MAX = 4000
BountyService.CLAIM_XP = 400
BountyService.CALLS = { [3] = "KILLING SPREE", [5] = "WANTED", [8] = "RAMPAGE", [12] = "UNSTOPPABLE" }

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local BountyEvent = (remotes :: Instance):FindFirstChild("BountyEvent") :: RemoteEvent?
if not BountyEvent then
	local made = Instance.new("RemoteEvent")
	made.Name = "BountyEvent"
	made.Parent = remotes
	BountyEvent = made
end
local bountyEvent = BountyEvent :: RemoteEvent

local streaks: { [Player]: number } = {}
-- The price a player carried at the moment they died, kept until the kill has been credited
-- (the two events do not arrive in a guaranteed order).
local priceAtDeath: { [Player]: number } = {}

local MatchService: any = nil
local function inDuel(player: Player): boolean
	if MatchService == nil then
		local module = ServerScriptService:FindFirstChild("MatchService")
		local ok, service = pcall(require, module)
		MatchService = (ok and service) or false
	end
	return MatchService ~= false and MatchService.InBout(player) == true
end

local function realFight(humanoid: Humanoid): boolean
	local model = humanoid.Parent
	return model ~= nil and (Players:GetPlayerFromCharacter(model) ~= nil or CollectionService:HasTag(model, "GameNPC"))
end

local function priceFor(streak: number): number
	return math.min(BountyService.MAX, BountyService.BASE + (streak - BountyService.WANTED_AT) * BountyService.PER_KILL)
end

local function payCoins(player: Player, amount: number)
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value += amount
	end
end

function BountyService.StreakOf(player: Player): number
	return streaks[player] or 0
end

KillCredit.KillAwarded.Event:Connect(function(killer: Player, humanoid: Humanoid, victim: Player?)
	if not realFight(humanoid) or inDuel(killer) then
		return
	end

	-- Collect the price on a WANTED player.
	if victim and victim ~= killer then
		local price = priceAtDeath[victim] or tonumber(victim:GetAttribute("Bounty")) or 0
		priceAtDeath[victim] = nil
		victim:SetAttribute("Bounty", nil)
		if price > 0 then
			payCoins(killer, price)
			task.spawn(LevelSystem.AwardXP, killer, BountyService.CLAIM_XP)
			bountyEvent:FireAllClients("claimed", {
				killer = killer.DisplayName, killerId = killer.UserId,
				victim = victim.DisplayName, victimId = victim.UserId, amount = price,
			})
			print(("[Bounty] %s claimed %s's $%d"):format(killer.Name, victim.Name, price))
			local okC, ContractService = pcall(require, ServerScriptService:FindFirstChild("ContractService") :: ModuleScript)
			if okC and type(ContractService) == "table" and ContractService.Note then
				task.spawn(ContractService.Note, killer, "bounty")
			end
		end
	end

	-- The killer's streak, and what it makes them worth.
	local streak = (streaks[killer] or 0) + 1
	streaks[killer] = streak
	local call = BountyService.CALLS[streak]
	if streak >= BountyService.WANTED_AT then
		local price = priceFor(streak)
		killer:SetAttribute("Bounty", price)
		if streak == BountyService.WANTED_AT then
			bountyEvent:FireAllClients("wanted", { name = killer.DisplayName, userId = killer.UserId, amount = price })
		end
	end
	if call then
		bountyEvent:FireClient(killer, "streak", { call = call, streak = streak,
			amount = streak >= BountyService.WANTED_AT and priceFor(streak) or nil })
	end
end)

local function onCharacter(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.Died:Connect(function()
		local price = tonumber(player:GetAttribute("Bounty")) or 0
		if price > 0 then
			priceAtDeath[player] = price
			-- If nobody was credited (a fall, an NPC), the price simply lapses.
			task.delay(3, function()
				if priceAtDeath[player] == price then
					priceAtDeath[player] = nil
				end
			end)
		end
		streaks[player] = 0
		player:SetAttribute("Bounty", nil)
	end)
end

local function onPlayer(player: Player)
	streaks[player] = 0
	player:SetAttribute("Bounty", nil)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end
Players.PlayerRemoving:Connect(function(player)
	streaks[player] = nil
	priceAtDeath[player] = nil
end)

return BountyService
