--!strict
-- Gear, server side: buying it at ZEE TACTICS, owning it, and which piece is in each slot.
--
--   OwnedGear    = { "Heal_TraumaKit", "Bomb_Sticky" }          (the Common ones are free, never listed)
--   EquippedGear = { Heal = "Heal_TraumaKit", Bomb = "Bomb_Sticky" }   (a missing slot = its Common)
--
-- The choice is published on the player as GearHeal / GearArmor / GearBomb, which is what
-- UtilityService reads when it fills a kit -- so the next life (or a restock at the counter)
-- carries it. Prices come from GearConfig; Street Cred knocks a little off at the counter
-- (the shop knows who you are). The client names an id and nothing else.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GearConfig = require(ReplicatedStorage.GearConfig)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)

local GearService = {}

GearService.RESTOCK_EVERY = 20                       -- seconds between free restocks at the counter
GearService.CRED_DISCOUNT = { Honoured = 0.15, Friendly = 0.08 }

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local GearAction = (remotes :: Instance):FindFirstChild("GearAction") :: RemoteFunction?
if not GearAction then
	local made = Instance.new("RemoteFunction")
	made.Name = "GearAction"
	made.Parent = remotes
	GearAction = made
end

local busy: { [Player]: boolean } = {}
local lastRestock: { [Player]: number } = {}

local function service(name: string): any
	local module = ServerScriptService:FindFirstChild(name)
	if not module then
		return nil
	end
	local ok, loaded = pcall(require, module :: ModuleScript)
	return if ok and type(loaded) == "table" then loaded else nil
end

local function replicaOf(player: Player): any
	local ok, replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
	end)
	return if ok then replica else nil
end

local function levelOf(player: Player): number
	local stats = player:FindFirstChild("Stats")
	local lv = stats and stats:FindFirstChild("Level")
	if lv and lv:IsA("IntValue") then
		return lv.Value
	end
	return math.max(1, math.floor(tonumber(player:GetAttribute("Level")) or 1))
end

local function coinsOf(player: Player): IntValue?
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	return if coins and coins:IsA("IntValue") then coins else nil
end

function GearService.Owns(player: Player, id: string): boolean
	if GearConfig.IsFree(id) then
		return GearConfig.Get(id) ~= nil
	end
	local replica = replicaOf(player)
	return replica ~= nil and table.find(replica.Data.OwnedGear or {}, id) ~= nil
end

--- What `player` has in `slot`: their choice if they own it, else the Common one.
function GearService.Equipped(player: Player, slot: string): GearConfig.Gear
	local replica = replicaOf(player)
	local chosen = replica and type(replica.Data.EquippedGear) == "table" and replica.Data.EquippedGear[slot] or nil
	return GearConfig.Resolve(slot, chosen, function(id)
		return GearService.Owns(player, id)
	end)
end

local function publish(player: Player)
	for _, slot in ipairs(GearConfig.Slots) do
		player:SetAttribute("Gear" .. slot, GearService.Equipped(player, slot).id)
	end
end

--- The discount Street Cred earns at the counter (0 to 0.15).
function GearService.Discount(player: Player): number
	local Turf = service("TurfWarService")
	if not Turf or not Turf.Cred then
		return 0
	end
	local ok, _, band = pcall(Turf.Cred, player)
	return ok and GearService.CRED_DISCOUNT[band] or 0
end

function GearService.PriceOf(player: Player, item: GearConfig.Gear): number
	return math.floor(item.coins * (1 - GearService.Discount(player)) / 50 + 0.5) * 50
end

--- Everything the shop and the inventory draw: owned, equipped, the price you pay, and what
--- you have to pay with.
function GearService.State(player: Player): { [string]: any }
	local owned, prices = {}, {}
	for _, item in ipairs(GearConfig.Items) do
		owned[item.id] = GearService.Owns(player, item.id)
		prices[item.id] = GearService.PriceOf(player, item)
	end
	local equipped = {}
	for _, slot in ipairs(GearConfig.Slots) do
		equipped[slot] = GearService.Equipped(player, slot).id
	end
	local Crystals = service("CrystalService")
	local coins = coinsOf(player)
	return {
		owned = owned, equipped = equipped, prices = prices, level = levelOf(player),
		coins = coins and coins.Value or 0,
		crystals = Crystals and Crystals.Get and Crystals.Get(player) or 0,
		discount = GearService.Discount(player),
	}
end

--- A free resupply at the counter, at most every RESTOCK_EVERY seconds.
function GearService.Restock(player: Player): boolean
	local now = os.clock()
	if now - (lastRestock[player] or -math.huge) < GearService.RESTOCK_EVERY then
		return false
	end
	local Utility = service("UtilityService")
	if Utility and Utility.Restock and Utility.Restock(player) then
		lastRestock[player] = now
		return true
	end
	return false
end

function GearService.Equip(player: Player, id: string): { [string]: any }
	local item = GearConfig.Get(id)
	if not item then
		return { ok = false, reason = "No such gear" }
	end
	if not GearService.Owns(player, id) then
		return { ok = false, reason = "You don't own that yet" }
	end
	local replica = replicaOf(player)
	if not replica then
		return { ok = false, reason = "Your data is still loading" }
	end
	local equipped = table.clone(type(replica.Data.EquippedGear) == "table" and replica.Data.EquippedGear or {})
	equipped[item.slot] = item.id
	replica:SetValue("EquippedGear", equipped)
	publish(player)
	return { ok = true, restocked = GearService.Restock(player) }
end

function GearService.Buy(player: Player, id: string): { [string]: any }
	local item = GearConfig.Get(id)
	if not item then
		return { ok = false, reason = "No such gear" }
	end
	if GearService.Owns(player, id) then
		return { ok = false, reason = "You already own that" }
	end
	if levelOf(player) < item.level then
		return { ok = false, reason = "Requires level " .. item.level }
	end
	if busy[player] then
		return { ok = false, reason = "Please wait..." }
	end
	local replica = replicaOf(player)
	local coins = coinsOf(player)
	if not replica or not coins then
		return { ok = false, reason = "Your data is still loading" }
	end
	local price = GearService.PriceOf(player, item)
	if coins.Value < price then
		return { ok = false, reason = ("You need $%d more"):format(price - coins.Value) }
	end
	local Crystals = service("CrystalService")
	if item.crystals > 0 and (not Crystals or (Crystals.Get(player) or 0) < item.crystals) then
		return { ok = false, reason = ("You need %d crystals"):format(item.crystals) }
	end
	busy[player] = true
	if item.crystals > 0 and not Crystals.Spend(player, item.crystals) then
		busy[player] = nil
		return { ok = false, reason = "Not enough crystals" }
	end
	coins.Value -= price
	local owned = table.clone(replica.Data.OwnedGear or {})
	table.insert(owned, item.id)
	replica:SetValue("OwnedGear", owned)
	busy[player] = nil
	print(("[Gear] %s bought %s for $%d%s"):format(player.Name, item.id, price,
		item.crystals > 0 and (" + " .. item.crystals .. " crystals") or ""))
	-- Straight into its slot: that is why they bought it.
	local equipped = GearService.Equip(player, item.id)
	return { ok = true, restocked = equipped.restocked }
end

local gearRemote = GearAction :: RemoteFunction
gearRemote.OnServerInvoke = function(player: Player, action: unknown, id: unknown)
	if action == "state" then
		return GearService.State(player)
	elseif action == "buy" and type(id) == "string" then
		local result = GearService.Buy(player, id)
		result.state = GearService.State(player)
		return result
	elseif action == "equip" and type(id) == "string" then
		local result = GearService.Equip(player, id)
		result.state = GearService.State(player)
		return result
	end
	return nil
end

local function onPlayer(player: Player)
	task.spawn(function()
		for _ = 1, 30 do
			if not player.Parent then
				return
			end
			if replicaOf(player) then
				publish(player)
				-- The life already under way picks it up too (armour up to what it starts with).
				local Utility = service("UtilityService")
				if Utility and Utility.Restock and player.Character then
					pcall(Utility.Restock, player)
				end
				return
			end
			task.wait(1)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end
Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
	lastRestock[player] = nil
end)

return GearService
