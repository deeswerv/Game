--!strict
-- The market: everything for sale, in one shelf per kind of thing.
--
-- Prices shown here are the prices the SERVER will charge. It publishes a
-- ShopPriceMultiplier attribute from the player's standing with the town, and this mirrors
-- the server's own rounding exactly -- `floor(base * mult + 0.5)`. Showing a list price and
-- then charging a different number is the one thing a shop must never do.
--
-- Nothing here grants anything. Every button invokes a purchase remote and redraws from what
-- the server says afterwards, so a client that edits this file can make a card say OWNED and
-- still own nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menu = require(script.Parent.Menu)

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
local WeaponPreview = require(ReplicatedStorage:WaitForChild("WeaponPreview"))
local CamoConfig = require(ReplicatedStorage:WaitForChild("CamoConfig"))
local AttachmentConfig = require(ReplicatedStorage:WaitForChild("AttachmentConfig"))
local CosmeticConfig = require(ReplicatedStorage:WaitForChild("CosmeticConfig"))

local player = Players.LocalPlayer

local Market = {}
Market.__index = Market

-- Each shelf: which ownership field proves you have it, and which remote sells it.
-- The two camo shelves are gone: camos were retired in favour of whole weapon variants.
-- Mastery Weapons replaces them, and it deliberately has no coin remote -- a variant is
-- bought with Robux through Roblox's own prompt, or earned, never bought with coins.
local SHELVES = {
	{ id = "Weapons",     label = "WEAPONS",         field = "OwnedItems",       remote = "PurchaseItem" },
	{ id = "Mastery",     label = "MASTERY WEAPONS", field = "OwnedVariants",    remote = nil },
	{ id = "Attachments", label = "ATTACHMENTS",     field = "OwnedAttachments", remote = "PurchaseAttachment" },
	{ id = "Style",       label = "STYLE",           field = "OwnedCosmetics",   remote = "PurchaseCosmetic" },
	{ id = "Robux",       label = "ROBUX",           field = nil,                remote = nil },
}

local function rarityRank(rarity: string?): number
	local entry = rarity and Theme.Rarity[rarity]
	return entry and entry.order or 0
end

local function byRarityThenPrice(a, b): boolean
	local ra, rb = rarityRank(a.rarity), rarityRank(b.rarity)
	if ra ~= rb then
		return ra < rb
	end
	return (a.price or 0) < (b.price or 0)
end

-- ------------------------------------------------------------- catalogues --

local function weaponCatalog()
	local entries = {}
	for _, item in ipairs(GameConfig.ShopItems) do
		local cfg = WeaponConfig.Weapons[item.item or item.id]
		table.insert(entries, {
			id = item.id,
			name = item.name,
			desc = item.desc,
			price = item.price,
			rarity = cfg and cfg.Rarity,
			levelRequired = item.levelRequired or 1,
			preview = item.item or item.id,
		})
	end
	table.sort(entries, byRarityThenPrice)
	return entries
end

--- `reactive` picks which shelf this is: plain camos, or the ones that wake up on a streak.
--- They are separate tabs because they are a different promise to the buyer.
local function camoCatalog(reactive: boolean)
	local entries = {}
	for _, camo in ipairs(CamoConfig.Camos) do
		-- Factory is the weapon as it left the bench: free, always owned, nothing to sell.
		if not camo.factory and (camo.reactive == true) == reactive then
			table.insert(entries, {
				id = camo.id,
				name = camo.name,
				desc = camo.desc,
				price = camo.price,
				rarity = camo.rarity,
				levelRequired = 1,
				swatch = camo.primary,
			})
		end
	end
	table.sort(entries, byRarityThenPrice)
	return entries
end

local function attachmentCatalog()
	local entries = {}
	for _, slot in ipairs(AttachmentConfig.Slots) do
		for _, option in ipairs(AttachmentConfig.Options[slot] or {}) do
			-- Stock parts are free and fitted already, so there is nothing to sell.
			if not AttachmentConfig.IsStock(slot, option.id) then
				local rarity = AttachmentConfig.Rarity(slot, option.id)
				table.insert(entries, {
					id = AttachmentConfig.Key(slot, option.id),
					name = option.name,
					desc = string.upper(AttachmentConfig.SlotLabels[slot] or slot) .. " - fits every weapon",
					price = AttachmentConfig.Price(slot, option.id),
					rarity = rarity,
					levelRequired = 1,
				})
			end
		end
	end
	table.sort(entries, byRarityThenPrice)
	return entries
end

local function cosmeticCatalog()
	local entries = {}
	for _, item in ipairs(CosmeticConfig.Items) do
		table.insert(entries, {
			id = item.id,
			name = item.name,
			desc = string.format("%s - worn on the %s", item.rarity, string.lower(item.slot)),
			price = item.price,
			rarity = item.rarity,
			levelRequired = 1,
		})
	end
	table.sort(entries, byRarityThenPrice)
	return entries
end

--- Robux is a different shelf in kind: nothing is "owned", the server never quotes a coin
--- price, and buying opens Roblox's own prompt rather than invoking one of our remotes.
local function robuxCatalog()
	local entries = {}
	for _, product in ipairs(GameConfig.Products or {}) do
		table.insert(entries, {
			id = product.id,
			name = product.name,
			desc = string.format("%d coins", product.coins or 0),
			robux = product.robux,
			kind = "product",
		})
	end
	for _, pass in ipairs(GameConfig.GamePasses or {}) do
		table.insert(entries, {
			id = pass.id,
			name = pass.name,
			desc = pass.desc,
			robux = pass.robux,
			kind = "gamepass",
		})
	end
	return entries
end

--- Mastery Weapons: whole variants of a gun rather than paint over one. Each is either a
--- Robux purchase or something earned, so the card shows a Robux price or how it is won.
local function masteryCatalog()
	local entries = {}
	local store = ReplicatedStorage:FindFirstChild("storeitems")
	for _, variant in ipairs(WeaponConfig.Variants or {}) do
		-- Only list a variant whose Tool is actually in the game. An entry can be written
		-- before its model is imported without putting a card on the shelf that cannot be
		-- equipped, and the card appears by itself the moment the model lands.
		local ready = store and store:FindFirstChild(variant.id) ~= nil
		if ready then
		table.insert(entries, {
			id = variant.id,
			name = variant.name,
			desc = variant.desc,
			rarity = variant.rarity,
			robux = variant.robux,
			levelRequired = variant.levelRequired or 1,
			preview = variant.preview or variant.base,
			kind = variant.robux and "variant" or nil,
		})
		end
	end
	table.sort(entries, byRarityThenPrice)
	return entries
end

local CATALOGUES = {
	Weapons = weaponCatalog,
	Mastery = masteryCatalog,
	Attachments = attachmentCatalog,
	Style = cosmeticCatalog,
	Robux = robuxCatalog,
}

local function catalogueFor(shelfId: string)
	local build = CATALOGUES[shelfId]
	return build and build() or {}
end

-- ------------------------------------------------------------------- api --

function Market.new(parent: Instance, remotes)
	local self = setmetatable({}, Market)

	self._remotes = remotes
	self._cards = {}
	self._owned = {}
	self._coins = 0
	self._level = 1

	-- A shelf with nothing on it is not a shelf. This is what stops Mastery Weapons showing
	-- as an empty tab before the first variant exists, and it is also why retiring the camo
	-- catalogue was enough to take camos out of the market on its own.
	local categories = {}
	for _, shelf in ipairs(SHELVES) do
		if #catalogueFor(shelf.id) > 0 then
			table.insert(categories, { id = shelf.id, label = shelf.label })
		end
	end

	local menu = Menu.new(parent, {
		id = "Market",
		title = "MARKET",
		-- No subtitle: the standing line below occupies that slot and says something useful.
		subtitle = nil,
		size = UDim2.fromOffset(940, 560),
		categories = categories,
	})
	self._menu = menu

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Grid"
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 3
	scroller.ScrollBarImageColor3 = Theme.Colour.Stroke
	scroller.Parent = menu.content
	Components.Grid(scroller, Vector2.new(210, 150), Theme.Space.M)
	self._grid = scroller

	-- Standing is shown, not hidden. If the town is charging you more, you should be able to
	-- see that is why -- otherwise the prices just look wrong.
	self._standing = Components.Label(menu.header, {
		text = "",
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
	})
	self._standing.Size = UDim2.new(1, -140, 0, 16)
	self._standing.Position = UDim2.fromOffset(Theme.Space.L, Theme.Space.M + 26)

	menu:OnCategory(function(id: string)
		self:_fill(id)
	end)
	menu:OnOpen(function()
		self:Refresh()
	end)

	-- A purchase made anywhere -- here, or by a vendor NPC -- redraws the shelf.
	if remotes.ownershipChanged then
		remotes.ownershipChanged.OnClientEvent:Connect(function()
			if menu:IsOpen() then
				self:Refresh()
			end
		end)
	end

	-- Standing can move while the shop is open (a guard kill, a quest turn-in), and the prices
	-- on screen must move with it.
	for _, attribute in ipairs({ "ShopPriceMultiplier", "TownStanding" }) do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if menu:IsOpen() then
				-- Both, not just the cards. Redrawing prices without redrawing the line that
				-- explains them leaves the player looking at numbers that changed for no
				-- visible reason.
				self:_refreshStanding()
				self:_fill(self._menu._category or "Weapons")
			end
		end)
	end

	return self
end

--- The server's own arithmetic, mirrored. Returns the price and whether they will trade at all.
function Market:_priceFor(basePrice: number): (number, boolean)
	local mult = player:GetAttribute("ShopPriceMultiplier")
	if mult == nil then
		return basePrice, true          -- not published yet: show the list price
	end
	if type(mult) ~= "number" or mult <= 0 then
		return basePrice, false         -- standing too low; they refuse to trade
	end
	return math.floor(basePrice * mult + 0.5), true
end

function Market:Refresh()
	task.spawn(function()
		local ok, result = pcall(function()
			return self._remotes.getOwnership:InvokeServer()
		end)
		self._owned = (ok and type(result) == "table") and result or {}

		local stats = player:FindFirstChild("leaderstats")
		local coins = stats and stats:FindFirstChild("Coins")
		self._coins = (coins and coins:IsA("ValueBase") and (coins :: any).Value) or 0
		self._level = tonumber(player:GetAttribute("Level")) or self._level

		self:_refreshStanding()
		self:_fill(self._menu._category or "Weapons")
	end)
end

--- The one line that explains why the prices are what they are.
function Market:_refreshStanding()
	local standing = player:GetAttribute("TownStanding")
	local mult = player:GetAttribute("ShopPriceMultiplier")
	if type(mult) ~= "number" then
		self._standing.Text = ""
		self._standing.TextColor3 = Theme.Colour.TextDim
	elseif mult <= 0 then
		self._standing.Text = "They will not trade with you"
		self._standing.TextColor3 = Theme.Colour.Danger
	elseif math.abs(mult - 1) > 0.001 then
		local cheaper = mult < 1
		self._standing.Text = string.format("%s  -  prices %s %d%%",
			tostring(standing or "Neutral"),
			cheaper and "down" or "up",
			math.floor(math.abs(1 - mult) * 100 + 0.5))
		self._standing.TextColor3 = cheaper and Theme.Colour.Accent or Theme.Colour.Warning
	else
		self._standing.Text = tostring(standing or "Neutral") .. "  -  list prices"
		self._standing.TextColor3 = Theme.Colour.TextDim
	end
end

function Market:_owns(field: string?, id: string): boolean
	if not field then
		return false
	end
	local list = self._owned[field]
	return type(list) == "table" and table.find(list, id) ~= nil
end

function Market:_fill(shelfId: string)
	for _, card in ipairs(self._cards) do
		card:Destroy()
	end
	table.clear(self._cards)

	local shelf
	for _, candidate in ipairs(SHELVES) do
		if candidate.id == shelfId then
			shelf = candidate
			break
		end
	end
	if not shelf then
		return
	end

	local entries = catalogueFor(shelfId)

	for index, entry in ipairs(entries) do
		self:_buildCard(shelf, entry, index)
	end
end

function Market:_buildCard(shelf, entry, index: number)
	local rarityColour = Theme.RarityColour(entry.rarity)
	local owned = self:_owns(shelf.field, entry.id)
	local locked = self._level < (entry.levelRequired or 1)
	local price, willTrade = 0, true
	if entry.price then
		price, willTrade = self:_priceFor(entry.price)
	end

	local card = Instance.new("Frame")
	card.Name = entry.name
	card.BackgroundColor3 = Theme.Colour.PanelRaised
	card.BorderSizePixel = 0
	card.Size = UDim2.fromOffset(210, 150)
	card.LayoutOrder = index
	card.Parent = self._grid
	Components.Corner(card, Theme.Radius.Card)
	Components.Stroke(card)

	local cap = Instance.new("Frame")
	cap.Name = "RarityCap"
	cap.BackgroundColor3 = entry.swatch or rarityColour
	cap.BorderSizePixel = 0
	cap.Size = UDim2.new(1, 0, 0, 2)
	cap.Parent = card

	-- Weapons get a real render; everything else gets its name doing the work, which is what
	-- the reference shop does for anything that is not a gun.
	if entry.preview then
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(1, -16, 0, 52)
		holder.Position = UDim2.fromOffset(8, 10)
		holder.Parent = card
		pcall(function()
			WeaponPreview.Render(holder, entry.preview)
		end)
	end

	local name = Components.Label(card, {
		text = entry.name,
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
	})
	name.Size = UDim2.new(1, -20, 0, 20)
	name.Position = UDim2.fromOffset(10, entry.preview and 64 or 12)

	local desc = Components.Label(card, {
		text = entry.desc or "",
		size = Theme.Text.Micro,
		colour = Theme.Colour.TextDim,
		wrap = true,
	})
	desc.Size = UDim2.new(1, -20, 0, 30)
	desc.Position = UDim2.fromOffset(10, entry.preview and 84 or 34)
	desc.TextYAlignment = Enum.TextYAlignment.Top

	if entry.rarity then
		local chip = Components.Chip(card, entry.rarity, rarityColour)
		chip.AnchorPoint = Vector2.new(1, 0)
		chip.Position = UDim2.new(1, -8, 0, 8)
	end

	-- ------------------------------------------------------------- action --

	local label, enabled
	if entry.robux then
		label, enabled = string.format("R$ %d", entry.robux), true
	elseif owned then
		label, enabled = "OWNED", false
	elseif locked then
		label, enabled = "LEVEL " .. tostring(entry.levelRequired), false
	elseif not willTrade then
		label, enabled = "WON'T TRADE", false
	elseif self._coins < price then
		label, enabled = string.format("%d COINS", price), false
	else
		label, enabled = string.format("BUY  %d", price), true
	end

	-- Declared BEFORE the constructor, deliberately. `local button = Components.Button{...}`
	-- does not bring `button` into scope until after the expression is evaluated, so the
	-- onActivated closure inside that table captured a nil global instead of this button.
	-- Every coin purchase in the market died on `button:SetText` before it ever reached the
	-- server: "attempt to index nil with 'SetText'", Market:455.
	local button
	button = Components.Button(card, {
		name = "Action",
		text = label,
		primary = enabled and not entry.robux,
		size = UDim2.new(1, -20, 0, Theme.Size.ButtonHeightS),
		position = UDim2.new(0, 10, 1, -10),
		anchor = Vector2.new(0, 1),
		textSize = Theme.Text.Small,
		onActivated = function()
			self:_buy(shelf, entry, button)
		end,
	})
	button:SetEnabled(enabled)

	table.insert(self._cards, {
		Destroy = function()
			button:Destroy()
			card:Destroy()
		end,
	})
end

function Market:_buy(shelf, entry, button)
	if entry.robux then
		-- Roblox owns this transaction; we only ask for the prompt.
		if self._remotes.promptPurchase then
			self._remotes.promptPurchase:FireServer(entry.kind, entry.id)
		end
		return
	end

	local remote = shelf.remote and self._remotes[shelf.remote]
	if not remote then
		return
	end

	-- The purchase itself must not depend on the button still being there. A card can be
	-- rebuilt by a Refresh mid-flight, and losing the label is not a reason to lose the buy.
	local function say(text: string)
		if button then
			pcall(function()
				button:SetText(text)
			end)
		end
	end

	say("...")
	if button then
		pcall(function()
			button:SetEnabled(false)
		end)
	end
	task.spawn(function()
		local ok, result = pcall(function()
			return remote:InvokeServer(entry.id)
		end)
		-- The server decides. Whatever it says, redraw from ownership rather than assuming the
		-- purchase landed.
		say(ok and result ~= false and "BOUGHT" or "REFUSED")
		task.wait(0.6)
		self:Refresh()
	end)
end

function Market:Toggle()
	self._menu:Toggle()
end

function Market:Close()
	self._menu:Close()
end

function Market:Destroy()
	for _, card in ipairs(self._cards) do
		card:Destroy()
	end
	self._menu:Destroy()
end

return Market
