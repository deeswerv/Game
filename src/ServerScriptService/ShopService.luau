--!strict
-- Server-authoritative shop. Handles coin purchases of tools, abilities, camos and
-- attachments -- all four through one purchase path, so the level gate, coin check,
-- double-buy guard and busy lock cannot drift apart between catalogues.
--
-- The previous shop took the price from the client:
--     BuyItemRE.OnServerEvent:Connect(function(plr, cost, name) ... end)
-- so anyone could buy for 0, or send a negative cost and mint coins. Nothing the
-- client sends here is trusted beyond the id of what they want to buy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.GameConfig)
local WeaponConfig = require(ReplicatedStorage.WeaponConfig)
local CamoConfig = require(ReplicatedStorage.CamoConfig)
local AttachmentConfig = require(ReplicatedStorage.AttachmentConfig)
local CosmeticConfig = require(ReplicatedStorage.CosmeticConfig)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local ReputationService = require(ServerScriptService.ReputationService)

local remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "GameRemotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemote(className: string, name: string)
	local existing = remotes:FindFirstChild(name)
	if existing then
		return existing
	end
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end

local PurchaseItem = ensureRemote("RemoteFunction", "PurchaseItem") :: RemoteFunction
local PurchaseAbility = ensureRemote("RemoteFunction", "PurchaseAbility") :: RemoteFunction
local GetOwnership = ensureRemote("RemoteFunction", "GetOwnership") :: RemoteFunction
local OwnershipChanged = ensureRemote("RemoteEvent", "OwnershipChanged") :: RemoteEvent
local LoadoutAction = ensureRemote("RemoteFunction", "LoadoutAction") :: RemoteFunction

local ShopService = {}

-- Simple per-player cooldown. Stops a spam-clicking client from racing the
-- coin check against itself and buying the same thing twice.
local busy: { [Player]: boolean } = {}

local function getCoins(player: Player): IntValue?
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		return coins
	end
	return nil
end

local function getLevel(player: Player): number
	local stats = player:FindFirstChild("Stats")
	local lv = stats and stats:FindFirstChild("Level")
	if lv and lv:IsA("ValueBase") then
		return (lv :: any).Value
	end
	return 1
end

local function listHas(list, value): boolean
	for _, v in ipairs(list) do
		if v == value then
			return true
		end
	end
	return false
end

-- Give the player the tool for `entry`, unless they already have a copy.
local function grantTool(player: Player, entry): boolean
	local store = ReplicatedStorage:FindFirstChild("storeitems")
	local template = store and store:FindFirstChild(entry.item)
	if not template then
		warn("[ShopService] storeitems is missing '" .. tostring(entry.item) .. "' for shop id " .. entry.id)
		return false
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then
		return false
	end

	local char = player.Character
	if backpack:FindFirstChild(template.Name) or (char and char:FindFirstChild(template.Name)) then
		return true -- already holding it
	end

	-- Clone. The old code re-parented the template itself out of ReplicatedStorage,
	-- which destroyed the master copy for everyone else in the server.
	local tool = template:Clone()
	tool.Parent = backpack
	return true
end

-- Weapons are NOT handed out automatically any more. A player picks what to carry
-- from the inventory, and only that reaches their backpack (and therefore the hotbar
-- and the holster on their back).
local function templateFor(id: string)
	local store = ReplicatedStorage:FindFirstChild("storeitems")
	return store and store:FindFirstChild(id)
end

local function ownsWeapon(player: Player, id: string): boolean
	local wcfg = WeaponConfig.Get(id)
	if wcfg and wcfg.Starter then
		return true
	end
	local ok, Replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
	end)
	if not ok or not Replica then
		return false
	end
	return table.find(Replica.Data.OwnedItems or {}, id) ~= nil
end

-- ---------------------------------------------------------------- loadout --
--
-- Two weapons carried at once -- a primary and a secondary -- remembered across deaths and
-- across sessions.
--
-- Before this, equipping DESTROYED every other weapon the player held, so the hotbar could
-- only ever contain one thing. The slots were real the whole time; there was simply never
-- anything to put in them.
local LOADOUT_SIZE = 2

local function loadoutOf(player: Player): { string }
	local ok, Replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
	end)
	if not ok or not Replica then
		return {}
	end
	local saved = Replica.Data.Loadout or {}
	if #saved <= LOADOUT_SIZE then
		return saved
	end
	-- Clamped on read, because a profile saved when the loadout held more weapons than it
	-- does now must not hand back the extras. The surplus is dropped from the end, so the
	-- player keeps the weapons they chose first.
	local trimmed = {}
	for i = 1, LOADOUT_SIZE do
		trimmed[i] = saved[i]
	end
	return trimmed
end

local function saveLoadout(player: Player, list: { string })
	local ok, Replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
	end)
	if ok and Replica then
		Replica:SetValue("Loadout", list)
	end
end

local function heldWeaponName(player: Player): string?
	local character = player.Character
	if not character then
		return nil
	end
	for _, t in ipairs(character:GetChildren()) do
		if t:IsA("Tool") and WeaponConfig.IsWeapon(t.Name) then
			return t.Name
		end
	end
	return nil
end

-- Make the player's carried weapons match their saved loadout, and nothing else.
--
-- Ownership is re-checked here rather than trusted from the save: a loadout written before
-- a weapon was removed from the game, or before the player's entitlement changed, must not
-- hand it back. Anything that fails the check is silently dropped.
function ShopService.ApplyLoadout(player: Player): boolean
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not character or not backpack then
		return false
	end

	-- Write the clamp back once, so an over-long profile is tidied rather than re-trimmed on
	-- every read for the rest of its life.
	local ok, Replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
	end)
	if ok and Replica and #(Replica.Data.Loadout or {}) > LOADOUT_SIZE then
		saveLoadout(player, loadoutOf(player))
	end

	local missing: { [string]: boolean } = {}
	for _, id in ipairs(loadoutOf(player)) do
		if ownsWeapon(player, id) and templateFor(id) then
			missing[id] = true
		end
	end

	-- Anything carried that is not in the loadout goes; anything that is, is ticked off.
	for _, container in ipairs({ backpack, character }) do
		for _, t in ipairs(container:GetChildren()) do
			if t:IsA("Tool") and WeaponConfig.IsWeapon(t.Name) then
				if missing[t.Name] == nil then
					t:Destroy()
				else
					missing[t.Name] = false
				end
			end
		end
	end

	for id, stillMissing in pairs(missing) do
		if stillMissing then
			local template = templateFor(id)
			if template then
				template:Clone().Parent = backpack
			end
		end
	end
	return true
end

-- Put a weapon in the player's hands, and remember it.
function ShopService.EquipWeapon(player: Player, id: string)
	if typeof(id) ~= "string" then
		return { ok = false, reason = "Invalid request" }
	end
	if not ownsWeapon(player, id) then
		return { ok = false, reason = "You do not own that" }
	end

	local template = templateFor(id)
	if not template then
		return { ok = false, reason = "Weapon is missing from storage" }
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not character or not humanoid or not backpack then
		return { ok = false, reason = "Respawning; try again" }
	end

	local loadout = table.clone(loadoutOf(player))
	if not table.find(loadout, id) then
		if #loadout >= LOADOUT_SIZE then
			-- Full. The new weapon takes the slot of whatever is in hand right now, which is
			-- the one the player has just demonstrated they are finished with.
			local held = heldWeaponName(player)
			local slot = (held and table.find(loadout, held)) or LOADOUT_SIZE
			loadout[slot] = id
		else
			table.insert(loadout, id)
		end
		saveLoadout(player, loadout)
	end

	humanoid:UnequipTools()
	ShopService.ApplyLoadout(player)

	local tool = backpack:FindFirstChild(id)
	if tool then
		task.wait(0.1)
		humanoid:EquipTool(tool)
	end

	local ok2, AbilityService = pcall(require, ServerScriptService.AbilityService)
	if ok2 then
		task.spawn(AbilityService.Refresh, player)
	end

	return { ok = true, reason = "Equipped " .. id }
end

-- Take a weapon out of the loadout entirely.
function ShopService.UnequipWeapon(player: Player, id: string)
	if typeof(id) ~= "string" then
		return { ok = false, reason = "Invalid request" }
	end
	local loadout = table.clone(loadoutOf(player))
	local slot = table.find(loadout, id)
	if not slot then
		return { ok = false, reason = "Not in your loadout" }
	end
	table.remove(loadout, slot)       -- remove, not nil: the array must stay contiguous
	saveLoadout(player, loadout)
	ShopService.ApplyLoadout(player)
	return { ok = true, reason = "Removed " .. id }
end

-- Put everything away: nothing in the hotbar, nothing on the back.
function ShopService.StowWeapons(player: Player)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local backpack = player:FindFirstChildOfClass("Backpack")
	if humanoid then
		humanoid:UnequipTools()
	end
	for _, container in ipairs({ backpack, character }) do
		if container then
			for _, t in ipairs(container:GetChildren()) do
				if t:IsA("Tool") and WeaponConfig.IsWeapon(t.Name) then
					t:Destroy()
				end
			end
		end
	end
	return { ok = true, reason = "Put away" }
end

LoadoutAction.OnServerInvoke = function(player, action, id)
	if action == "equip" then
		return ShopService.EquipWeapon(player, id)
	elseif action == "stow" then
		return ShopService.StowWeapons(player)
	end
	return { ok = false, reason = "Unknown action" }
end

-- Kept so buying an item still puts it straight into your hands.
function ShopService.GrantOwned(player: Player)
end

--- Give a player an item without charging for it -- chest loot, rewards, anything earned
--- rather than bought.
---
--- Deliberately routed through the same ownership record and the same OwnershipChanged
--- signal as a purchase, so the shop and the workshop cannot disagree about what someone
--- owns. `field` is one of the SaveStructure ownership arrays.
---
--- Returns false when the player already had it, which is what lets a caller re-roll
--- rather than silently handing over a duplicate.
function ShopService.Grant(player: Player, field: string, id: string): boolean
	if typeof(id) ~= "string" or id == "" then
		return false
	end
	if field ~= "OwnedItems" and field ~= "OwnedCamos"
		and field ~= "OwnedAttachments" and field ~= "OwnedAbilities"
		and field ~= "OwnedCosmetics" then
		return false
	end

	local ok, granted = pcall(function()
		local Replica = PlayerDataManager:GetPlayerDataReplica(player):expect()
		local owned = Replica.Data[field] or {}
		if listHas(owned, id) then
			return false
		end
		local updated = table.clone(owned)
		table.insert(updated, id)
		Replica:SetValue(field, updated)
		OwnershipChanged:FireClient(player, field, updated)
		return true
	end)

	if not ok then
		warn("[ShopService] grant failed for " .. player.Name .. ": " .. tostring(granted))
		return false
	end
	return granted == true
end

--- Does this player already own it? Used to avoid rolling duplicate loot.
function ShopService.OwnsInField(player: Player, field: string, id: string): boolean
	local ok, owned = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect().Data[field]
	end)
	return ok and listHas(owned or {}, id) or false
end

--- Add coins. Kept here so the leaderstats lookup lives in one place.
function ShopService.AwardCoins(player: Player, amount: number): boolean
	local coins = getCoins(player)
	if not coins or amount <= 0 then
		return false
	end
	coins.Value += math.floor(amount)
	return true
end

-- Shared purchase path for both catalogs. Public so it can be tested without a
-- client: RemoteFunction.OnServerInvoke is write-only and cannot be called back.
function ShopService.AttemptPurchase(player: Player, kind: string, id: string)
	if busy[player] then
		return { ok = false, reason = "Please wait..." }
	end
	if typeof(id) ~= "string" then
		return { ok = false, reason = "Invalid request" }
	end

	-- Each catalogue answers the same three questions: does it exist, what does it cost,
	-- and where is ownership recorded. Keeping that in one shape is what lets camos and
	-- attachments share the whole purchase path -- the level gate, the coin check, the
	-- double-buy guard and the busy lock -- rather than growing a second one.
	local entry, field
	if kind == "item" then
		entry, field = GameConfig.GetShopItem(id), "OwnedItems"
	elseif kind == "ability" then
		entry, field = GameConfig.GetAbility(id), "OwnedAbilities"
	elseif kind == "camo" then
		local camo = CamoConfig.Find(id)
		if camo and not camo.factory then
			entry = { name = camo.name, price = camo.price or 0, levelRequired = 1 }
		end
		field = "OwnedCamos"
	elseif kind == "cosmetic" then
		local item = CosmeticConfig.Get(id)
		if item then
			entry = { name = item.name, price = item.price, levelRequired = 1 }
		end
		field = "OwnedCosmetics"
	elseif kind == "attachment" then
		-- Sent as "Slot:Id", which is also how ownership is stored.
		local slot, optionId = id:match("^(%a+):(%w+)$")
		local option = slot and optionId and AttachmentConfig.Find(slot, optionId)
		if option and not AttachmentConfig.IsStock(slot, optionId) then
			entry = {
				name = option.name,
				price = AttachmentConfig.Price(slot, optionId),
				levelRequired = 1,
			}
		end
		field = "OwnedAttachments"
	end

	if not entry then
		return { ok = false, reason = "No such item" }
	end

	-- Standing decides what it costs, and whether they will sell at all. Computed here on
	-- the server from the profile, never taken from the client: the UI is told the
	-- multiplier only so it can draw the same number.
	local multiplier = ReputationService.PriceMultiplier(player)
	if not multiplier then
		return { ok = false, reason = "They won't trade with you after what you've done" }
	end
	local price = ReputationService.AdjustedPrice(entry.price, multiplier)

	local coins = getCoins(player)
	if not coins then
		return { ok = false, reason = "Your data is still loading" }
	end

	if getLevel(player) < (entry.levelRequired or 1) then
		return { ok = false, reason = "Requires level " .. entry.levelRequired }
	end

	busy[player] = true

	local ok, result = pcall(function()
		local Replica = PlayerDataManager:GetPlayerDataReplica(player):expect()
		local owned = Replica.Data[field] or {}

		if listHas(owned, id) then
			return { ok = false, reason = "You already own this" }
		end

		-- Price comes from the server catalog, never from the client, and the standing
		-- adjustment is applied to both the check and the charge from the same variable so
		-- they cannot drift apart.
		if coins.Value < price then
			return { ok = false, reason = "Not enough coins" }
		end

		coins.Value -= price

		local updated = table.clone(owned)
		table.insert(updated, id)
		Replica:SetValue(field, updated)

		if kind == "item" then
			-- Buying equips it straight away; after that it is the inventory's job.
			task.spawn(ShopService.EquipWeapon, player, id)
		elseif kind == "ability" then
			-- Enable the ability's script right away instead of waiting for a respawn.
			local loaded, AbilityService = pcall(require, ServerScriptService.AbilityService)
			if loaded then
				task.spawn(AbilityService.Refresh, player)
			end
		end
		-- Camos and attachments need nothing here: they take effect when the player fits
		-- them to a build, and the workshop checks ownership at that point.

		OwnershipChanged:FireClient(player, field, updated)
		return { ok = true, reason = "Purchased " .. entry.name }
	end)

	busy[player] = nil

	if not ok then
		warn("[ShopService] purchase failed for " .. player.Name .. ": " .. tostring(result))
		return { ok = false, reason = "Something went wrong" }
	end
	return result
end

PurchaseItem.OnServerInvoke = function(player, id)
	return ShopService.AttemptPurchase(player, "item", id)
end

PurchaseAbility.OnServerInvoke = function(player, id)
	return ShopService.AttemptPurchase(player, "ability", id)
end

local PurchaseCamo = ensureRemote("RemoteFunction", "PurchaseCamo")
PurchaseCamo.OnServerInvoke = function(player, id)
	return ShopService.AttemptPurchase(player, "camo", id)
end

local PurchaseCosmetic = ensureRemote("RemoteFunction", "PurchaseCosmetic")
PurchaseCosmetic.OnServerInvoke = function(player, id)
	local result = ShopService.AttemptPurchase(player, "cosmetic", typeof(id) == "string" and id or "")
	-- Wearing it straight away: a cosmetic you have bought but cannot see is
	-- indistinguishable from one that failed to buy. Only fills an EMPTY slot, so buying a
	-- second hat never silently replaces the one you chose.
	if result and result.ok then
		task.spawn(function()
			local ok, CosmeticService = pcall(require, ServerScriptService.CosmeticService)
			if not ok then
				return
			end
			local item = CosmeticConfig.Get(id)
			local replica = PlayerDataManager:GetPlayerDataReplica(player):expect()
			if item and not (replica.Data.EquippedCosmetics or {})[item.slot] then
				CosmeticService.Equip(player, item.slot, id)
			end
		end)
	end
	return result
end

local PurchaseAttachment = ensureRemote("RemoteFunction", "PurchaseAttachment")
PurchaseAttachment.OnServerInvoke = function(player, id)
	return ShopService.AttemptPurchase(player, "attachment", id)
end

-- Does a player have this camo? The factory finish is free to everyone.
function ShopService.OwnsCamo(player: Player, id: string): boolean
	local camo = CamoConfig.Find(id)
	if not camo or camo.factory then
		return true
	end
	local ok, owned = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect().Data.OwnedCamos
	end)
	return ok and listHas(owned or {}, id) or false
end

-- Does a player have this attachment? Stock parts are free to everyone.
function ShopService.OwnsAttachment(player: Player, slot: string, id: string): boolean
	if AttachmentConfig.IsStock(slot, id) then
		return true
	end
	local ok, owned = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect().Data.OwnedAttachments
	end)
	return ok and listHas(owned or {}, AttachmentConfig.Key(slot, id)) or false
end

function ShopService.GetOwnership(player: Player)
	local ok, result = pcall(function()
		local Replica = PlayerDataManager:GetPlayerDataReplica(player):expect()
		local items = table.clone(Replica.Data.OwnedItems or {})
		-- Starter weapons are owned by everyone without a purchase record.
		for _, entry in ipairs(GameConfig.ShopItems) do
			local wcfg = WeaponConfig.Get(entry.id)
			if wcfg and wcfg.Starter and not table.find(items, entry.id) then
				table.insert(items, entry.id)
			end
		end
		for name in pairs(WeaponConfig.Weapons) do
			local wcfg = WeaponConfig.Get(name)
			if wcfg and wcfg.Starter and not table.find(items, name) then
				table.insert(items, name)
			end
		end
		return {
			OwnedItems = items,
			OwnedAbilities = Replica.Data.OwnedAbilities or {},
			OwnedCamos = Replica.Data.OwnedCamos or {},
			OwnedAttachments = Replica.Data.OwnedAttachments or {},
		}
	end)
	if not ok then
		return { OwnedItems = {}, OwnedAbilities = {}, OwnedCamos = {}, OwnedAttachments = {} }
	end
	return result
end

GetOwnership.OnServerInvoke = function(player)
	return ShopService.GetOwnership(player)
end

local function onPlayerAdded(player: Player)
	-- The saved loadout is restored on every spawn, so a death costs you your position and
	-- nothing else. A player who has never equipped anything has an empty loadout, which
	-- restores as an empty hotbar -- exactly the old starting state.
	local function restore()
		-- The Backpack is replaced on respawn, so wait for the new one rather than racing it.
		player:WaitForChild("Backpack", 10)
		local ok, err = pcall(function()
			ShopService.ApplyLoadout(player)
		end)
		if not ok then
			warn("[ShopService] could not restore loadout for " .. player.Name .. ": " .. tostring(err))
		end
	end

	player.CharacterAdded:Connect(function()
		task.spawn(restore)
	end)
	if player.Character then
		task.spawn(restore)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

Players.PlayerRemoving:Connect(function(player)
	busy[player] = nil
end)

return ShopService
