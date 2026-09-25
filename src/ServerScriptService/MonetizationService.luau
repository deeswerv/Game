--!strict
-- Robux purchases: developer products (coin bundles) and game passes (permanent perks).
--
-- Product IDs live in ReplicatedStorage.GameConfig and start at 0. Until real IDs are
-- pasted in, nothing here prompts a purchase and the Robux tab shows the entry as
-- unavailable -- an unconfigured id must never reach PromptProductPurchase.

local MarketplaceService = game:GetService("MarketplaceService")
local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.GameConfig)

-- Receipts already granted. Roblox re-sends a receipt until we confirm it, so this
-- is what stops a coin bundle being granted twice after a server crash.
--
-- Fetched under pcall. GetDataStore THROWS in a place that is not published (a .rbxl opened
-- from disk) and when Studio has no API access; unguarded, that killed this whole module at
-- its first line -- before PromptPurchase existed -- and MainUI, waiting on that remote,
-- never built the shop, the inventory hotkeys, the dock or the "+" beside the cash. Every
-- use below is already inside a pcall, so a nil store simply means receipts are not
-- checked (and so products are not granted) until DataStores are available.
local ReceiptStore: DataStore? = nil
do
	local ok, store = pcall(function()
		return DataStoreService:GetDataStore("PurchaseReceipts_v1")
	end)
	if ok then
		ReceiptStore = store
	else
		warn("[Monetization] DataStores unavailable (" .. tostring(store) .. "); purchases will not be granted")
	end
end

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

local PromptPurchase = ensureRemote("RemoteEvent", "PromptPurchase") :: RemoteEvent
local PerksChanged = ensureRemote("RemoteEvent", "PerksChanged") :: RemoteEvent

local MonetizationService = {}

-- ------------------------------------------------------------- game passes --

-- Perks are exposed as player attributes so any system can read them without
-- depending on this module. LevelSystem reads DoubleXP that way.
local function applyPass(player: Player, pass, owned: boolean)
	player:SetAttribute(pass.perk, owned)
end

function MonetizationService.RefreshPasses(player: Player)
	for _, pass in ipairs(GameConfig.GamePasses) do
		if pass.id == 0 then
			applyPass(player, pass, false)
		else
			local ok, owned = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(player.UserId, pass.id)
			end)
			applyPass(player, pass, ok and owned or false)
		end
	end
	PerksChanged:FireClient(player)
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, wasPurchased)
	if wasPurchased then
		MonetizationService.RefreshPasses(player)
	end
end)

-- ------------------------------------------------------ developer products --

local function grantProduct(player: Player, entry): boolean
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if not coins or not coins:IsA("IntValue") then
		return false -- data not ready; tell Roblox to retry later
	end

	coins.Value += entry.coins
	return true
end

MarketplaceService.ProcessReceipt = function(receiptInfo)
	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		-- They left before we could grant. Do not consume the receipt; Roblox will
		-- deliver it again next time they join.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local key = "receipt_" .. receiptInfo.PurchaseId

	local alreadyGranted
	local readOk = pcall(function()
		alreadyGranted = (ReceiptStore :: DataStore):GetAsync(key)
	end)
	if not readOk then
		-- Could not verify. Granting now risks double-granting, so retry later.
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	if alreadyGranted then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local entry = GameConfig.GetProductById(receiptInfo.ProductId)
	if not entry then
		warn("[Monetization] unknown ProductId " .. tostring(receiptInfo.ProductId))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if not grantProduct(player, entry) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Record only after the grant succeeded.
	local writeOk = pcall(function()
		(ReceiptStore :: DataStore):SetAsync(key, true)
	end)
	if not writeOk then
		-- The player has their coins but we could not write the receipt. Retrying
		-- would double-grant, so accept it and take the small risk of a lost record.
		warn("[Monetization] could not record receipt " .. tostring(receiptInfo.PurchaseId))
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

-- --------------------------------------------------------------- prompting --

PromptPurchase.OnServerEvent:Connect(function(player, kind, id)
	if typeof(id) ~= "number" or id == 0 then
		return -- unconfigured or malformed; never prompt on a placeholder id
	end

	if kind == "product" then
		-- Only prompt for ids that are actually in our catalog.
		if not GameConfig.GetProductById(id) then
			return
		end
		MarketplaceService:PromptProductPurchase(player, id)
	elseif kind == "gamepass" then
		local known = false
		for _, pass in ipairs(GameConfig.GamePasses) do
			if pass.id == id then
				known = true
				break
			end
		end
		if not known then
			return
		end
		MarketplaceService:PromptGamePassPurchase(player, id)
	end
end)

local function onPlayerAdded(player: Player)
	task.spawn(MonetizationService.RefreshPasses, player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

return MonetizationService
