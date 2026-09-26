--!strict
-- The market: everything for sale, one shelf per kind of thing.
--
-- Styled on the reference shop: a row of chunky tabs across the top, then big cards flooded
-- with colour -- the item's name outlined in the corner, the thing itself large in the
-- middle, and the price on a green button. Owned and locked states read at a glance.
--
-- Prices shown here are the prices the SERVER will charge. It publishes a
-- ShopPriceMultiplier attribute from the player's standing with the town, and this mirrors
-- the server's own rounding exactly -- `floor(base * mult + 0.5)`.
--
-- Nothing here grants anything. Every button invokes a purchase remote and redraws from what
-- the server says afterwards, so a client that edits this file can make a card say OWNED and
-- still own nothing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menu = require(script.Parent.Menu)

local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
local WeaponPreview = require(ReplicatedStorage:WaitForChild("WeaponPreview"))
local AttachmentConfig = require(ReplicatedStorage:WaitForChild("AttachmentConfig"))
local VFXConfig = require(ReplicatedStorage:WaitForChild("VFXConfig"))

local player = Players.LocalPlayer

local Market = {}
Market.__index = Market

local CARD = Vector2.new(292, 196)

-- Each shelf: which ownership field proves you have it, and which remote sells it. Mastery
-- Weapons deliberately have no coin remote -- a variant is bought with Robux through
-- Roblox's own prompt, or earned, never bought with coins.
local SHELVES = {
	{ id = "Weapons",     label = "Guns",        icon = nil,  preview = "Warden", field = "OwnedItems",       remote = "PurchaseItem", equip = false },
	{ id = "Mastery",     label = "Mastery",     icon = "⭐", field = "OwnedVariants",    remote = nil, equip = false },
	{ id = "Attachments", label = "Attachments", icon = "🔧", field = "OwnedAttachments", remote = "PurchaseAttachment", equip = false },
	{ id = "VFX",         label = "VFX",         icon = "✨", field = "OwnedVFX",         remote = "PurchaseVFX", equip = true },
	{ id = "Robux",       label = "Cash",        icon = "💰", field = nil,                remote = nil, equip = false },
}

local SLOT_ICON = {
	Sight = "🔭", Muzzle = "🔇", Underbarrel = "✊", Magazine = "📦", Stock = "🪵", Charm = "🍀",
}

local function comma(n: number): string
	local s = string.format("%d", math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function rarityRank(rarity: string?): number
	local entry = rarity and Theme.Rarity[rarity]
	return entry and entry.order or 0
end

local function byRarityThenPrice(a, b): boolean
	local ra, rb = rarityRank(a.rarity), rarityRank(b.rarity)
	if ra ~= rb then
		return ra < rb
	end
	return (a.price or a.robux or 0) < (b.price or b.robux or 0)
end

-- ------------------------------------------------------------- catalogues --

local function weaponCatalog()
	local entries = {}
	for _, item in ipairs(GameConfig.ShopItems) do
		local name = item.item or item.id
		local cfg = WeaponConfig.Weapons[name]
		table.insert(entries, {
			id = item.id,
			name = item.name,
			desc = item.desc,
			price = item.price,
			rarity = cfg and cfg.Rarity,
			levelRequired = item.levelRequired or 1,
			preview = name,
		})
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
				table.insert(entries, {
					id = AttachmentConfig.Key(slot, option.id),
					name = option.name,
					desc = string.upper(AttachmentConfig.SlotLabels[slot] or slot) .. "  -  fits every weapon",
					price = AttachmentConfig.Price(slot, option.id),
					rarity = AttachmentConfig.Rarity(slot, option.id),
					levelRequired = 1,
					icon = SLOT_ICON[slot] or "🔧",
				})
			end
		end
	end
	table.sort(entries, byRarityThenPrice)
	return entries
end

--- Kill effects and tracers (VFXConfig). Kill effects first, then tracers, each by rarity.
local function vfxCatalog()
	local entries = {}
	for _, slot in ipairs(VFXConfig.Slots) do
		local shelf = {}
		for _, item in ipairs(VFXConfig.Items) do
			if item.slot == slot then
				table.insert(shelf, {
					id = item.id,
					name = item.name,
					desc = string.upper(VFXConfig.SlotLabels[slot] or slot) .. "  -  " .. item.desc,
					price = item.price,
					rarity = item.rarity,
					levelRequired = 1,
					icon = item.icon,
					slot = slot,
				})
			end
		end
		table.sort(shelf, byRarityThenPrice)
		for _, entry in ipairs(shelf) do
			table.insert(entries, entry)
		end
	end
	return entries
end

--- Robux is a different shelf in kind: nothing is "owned", the server never quotes a coin
--- price, and buying opens Roblox's own prompt rather than invoking one of our remotes. An
--- entry whose product id has not been filled in yet is shown as coming soon rather than
--- offering a button the server will ignore.
local function robuxCatalog()
	local entries = {}
	for index, product in ipairs(GameConfig.DeveloperProducts or {}) do
		table.insert(entries, {
			id = product.id,
			name = product.name,
			desc = "Instant cash, straight into your pocket",
			amount = product.coins,
			robux = product.robux,
			kind = "product",
			rarity = Theme.RarityOrder[math.min(index + 1, #Theme.RarityOrder)],
			icon = "💵",
			ready = product.id ~= 0,
		})
	end
	for _, pass in ipairs(GameConfig.GamePasses or {}) do
		table.insert(entries, {
			id = pass.id,
			name = pass.name,
			desc = pass.desc,
			robux = pass.robux,
			kind = "gamepass",
			rarity = "Mythic",
			icon = pass.perk == "VIP" and "👑" or "⚡",
			ready = pass.id ~= 0,
		})
	end
	return entries
end

--- Mastery Weapons: whole variants of a gun rather than paint over one.
local function masteryCatalog()
	local entries = {}
	local store = ReplicatedStorage:FindFirstChild("storeitems")
	for _, variant in ipairs(WeaponConfig.Variants or {}) do
		-- Only list a variant whose Tool is actually in the game.
		if store and store:FindFirstChild(variant.id) ~= nil then
			table.insert(entries, {
				id = variant.id,
				name = variant.name,
				desc = variant.desc,
				rarity = variant.rarity,
				robux = variant.robux,
				levelRequired = variant.levelRequired or 1,
				preview = variant.id,
				kind = variant.robux and "variant" or nil,
				ready = true,
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
	VFX = vfxCatalog,
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

	-- A shelf with nothing on it is not a shelf.
	local categories = {}
	for _, shelf in ipairs(SHELVES) do
		if #catalogueFor(shelf.id) > 0 then
			table.insert(categories, { id = shelf.id, label = shelf.label, icon = shelf.icon, preview = shelf.preview })
		end
	end

	local menu = Menu.new(parent, {
		id = "Market",
		title = "Shop",
		icon = "🛒",
		size = UDim2.fromOffset(1000, 610),
		categories = categories,
		tabs = "top",
	})
	self._menu = menu

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Grid"
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = UDim2.fromScale(1, 1)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 5
	scroller.ScrollBarImageColor3 = Theme.Colour.Stroke
	scroller.Parent = menu.content
	local grid = Components.Grid(scroller, CARD, 14)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Components.Padding(scroller, 6)
	self._grid = scroller

	-- Standing is shown, not hidden: if the town is charging you more, you can see why.
	self._standing = menu.subtitle

	menu:OnCategory(function(id: string)
		self:_fill(id)
	end)
	menu:OnOpen(function()
		self:Refresh()
	end)
	-- A level gained with the shop open -- a kill, a quest, the owner panel -- unlocks guns
	-- there and then, rather than on the next time the shop is opened.
	player:GetAttributeChangedSignal("Level"):Connect(function()
		if menu:IsOpen() then
			self:Refresh()
		end
	end)

	-- A purchase made anywhere -- here, or by a vendor NPC -- redraws the shelf.
	if remotes.ownershipChanged then
		remotes.ownershipChanged.OnClientEvent:Connect(function()
			if menu:IsOpen() then
				self:Refresh()
			end
		end)
	end

	-- Equipping a VFX (here or anywhere) redraws its shelf, so EQUIPPED moves with it.
	for _, slot in ipairs(VFXConfig.Slots) do
		player:GetAttributeChangedSignal(VFXConfig.Attribute[slot]):Connect(function()
			if menu:IsOpen() and self._menu._category == "VFX" then
				self:_fill("VFX")
			end
		end)
	end

	-- Standing can move while the shop is open, and the prices on screen must move with it.
	for _, attribute in ipairs({ "ShopPriceMultiplier", "TownStanding" }) do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			if menu:IsOpen() then
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
		return basePrice, true
	end
	if type(mult) ~= "number" or mult <= 0 then
		return basePrice, false
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
	local line = "Unlock new guns, gear and VFX"
	local colour = Theme.Colour.TextDim
	if type(mult) == "number" and mult <= 0 then
		line, colour = "The town will not trade with you", Theme.Colour.Danger
	elseif type(mult) == "number" and math.abs(mult - 1) > 0.001 then
		local cheaper = mult < 1
		line = string.format("%s  -  prices %s %d%%", tostring(standing or "Neutral"),
			cheaper and "down" or "up", math.floor(math.abs(1 - mult) * 100 + 0.5))
		colour = cheaper and Theme.Colour.Accent or Theme.Colour.Warning
	end
	self._standing.Text = string.format("%s   ·   💵 %s", line, comma(self._coins))
	self._standing.TextColor3 = colour
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
		card.Destroy()
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

	for index, entry in ipairs(catalogueFor(shelfId)) do
		self:_buildCard(shelf, entry, index)
	end
	self._grid.CanvasPosition = Vector2.zero
end

function Market:_buildCard(shelf, entry, index: number)
	local rarityColour = Theme.RarityColour(entry.rarity)
	local owned = self:_owns(shelf.field, entry.id)
	local locked = self._level < (entry.levelRequired or 1)
	local price, willTrade = 0, true
	if entry.price then
		price, willTrade = self:_priceFor(entry.price)
	end

	-- The card: flooded in its rarity, bright at the top, a lighter rim, a gloss band.
	local card = Instance.new("Frame")
	card.Name = entry.name
	card.BackgroundColor3 = Theme.Shade(rarityColour, -0.1)
	card.BorderSizePixel = 0
	card.Size = UDim2.fromOffset(CARD.X, CARD.Y)
	card.LayoutOrder = index
	card.Parent = self._grid
	Components.Corner(card, 16)
	Components.Stroke(card, Theme.Shade(rarityColour, 0.45), 3)
	local flood = Instance.new("UIGradient")
	flood.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(200, 200, 200)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 120, 124)),
	})
	flood.Rotation = 90
	flood.Parent = card

	local scale = Instance.new("UIScale")
	scale.Parent = card

	-- Diagonal light streaks across the card, the "shine" the reference bundle cards carry.
	for i = 0, 1 do
		local streak = Instance.new("Frame")
		streak.Name = "Shine"
		streak.BackgroundColor3 = Color3.new(1, 1, 1)
		streak.BackgroundTransparency = 0.86 + i * 0.06
		streak.BorderSizePixel = 0
		streak.AnchorPoint = Vector2.new(0.5, 0.5)
		streak.Position = UDim2.fromScale(0.62 + i * 0.16, 0.45)
		streak.Size = UDim2.new(0, 26 - i * 12, 1.6, 0)
		streak.Rotation = 28
		streak.Parent = card
	end
	card.ClipsDescendants = true

	-- The thing itself, big in the middle.
	if entry.preview then
		local holder = Instance.new("Frame")
		holder.Name = "Preview"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(1, -24, 0, 104)
		holder.Position = UDim2.fromOffset(12, 34)
		holder.Parent = card
		pcall(function()
			WeaponPreview.Icon(holder, entry.preview, { Zoom = 1.1, Dim = locked and 0.35 or 0 })
		end)
	else
		local icon = Components.Icon(card, entry.icon or "🎁", 64)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.Position = UDim2.new(0.5, 0, 0, 88)
		icon.Rotation = -8
		if entry.amount then
			local amount = Components.Label(card, {
				text = comma(entry.amount),
				font = Theme.Font.Display,
				size = 40,
				colour = Theme.Colour.Currency,
				align = Enum.TextXAlignment.Center,
				outline = false,
			})
			Components.Outline(amount, 3, Theme.Colour.CurrencyEdge, 0)
			amount.Size = UDim2.new(1, 0, 0, 44)
			amount.Position = UDim2.fromOffset(0, 92)
			amount.ZIndex = 3
		end
	end

	local name = Components.Label(card, {
		text = entry.name,
		font = Theme.Font.Bold,
		size = 24,
		outline = 2.4,
	})
	name.Size = UDim2.new(1, -110, 0, 28)
	name.Position = UDim2.fromOffset(12, 6)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	name.ZIndex = 3

	if entry.rarity then
		local chip = Components.Chip(card, entry.rarity, Theme.Shade(rarityColour, -0.25))
		chip.AnchorPoint = Vector2.new(1, 0)
		chip.Position = UDim2.new(1, -10, 0, 10)
		chip.ZIndex = 3
	end

	local desc = Components.Label(card, {
		text = entry.desc or "",
		font = Theme.Font.Bold,
		size = Theme.Text.Micro + 1,
		colour = Color3.fromRGB(230, 232, 238),
		wrap = true,
	})
	desc.Size = UDim2.new(1, -150, 0, 34)
	desc.Position = UDim2.new(0, 12, 1, -42)
	desc.TextYAlignment = Enum.TextYAlignment.Center
	desc.ZIndex = 3

	if owned then
		local badge = Components.Chip(card, "✓ OWNED", Theme.Colour.AccentDim)
		badge.Position = UDim2.fromOffset(12, 36)
		badge.ZIndex = 3
	elseif locked then
		local badge = Components.Chip(card, "🔒 LEVEL " .. tostring(entry.levelRequired), Theme.Colour.Outline)
		badge.Position = UDim2.fromOffset(12, 36)
		badge.ZIndex = 3
	end

	-- ------------------------------------------------------------- action --

	local label, enabled, colour = "", true, Theme.Colour.Accent
	local equipped = shelf.equip and entry.slot ~= nil
		and player:GetAttribute(VFXConfig.Attribute[entry.slot]) == entry.id
	if shelf.equip and owned then
		-- Owned VFX: the button puts it on, or (when it is on) takes it off.
		if equipped then
			label, colour = "EQUIPPED", Theme.Colour.AccentDim
		else
			label, colour = "EQUIP", Theme.Colour.Accent
		end
	elseif entry.robux then
		if entry.ready == false then
			label, enabled = "SOON", false
		else
			label, colour = string.format("R$ %s", comma(entry.robux)), Color3.fromRGB(255, 196, 30)
		end
	elseif owned then
		label, enabled = "OWNED", false
	elseif locked then
		label, enabled = "LVL " .. tostring(entry.levelRequired), false
	elseif not willTrade then
		label, enabled = "NO TRADE", false
	elseif self._coins < price then
		label, enabled, colour = "$" .. comma(price), true, Theme.Colour.PanelRaised
	else
		label = "$" .. comma(price)
	end

	-- Declared BEFORE the constructor, deliberately: a closure inside the constructor's
	-- table must capture the variable, not a nil global.
	local button
	button = Components.Button(card, {
		name = "Action",
		text = label,
		colour = colour,
		size = UDim2.fromOffset(126, 40),
		position = UDim2.new(1, -10, 1, -10),
		anchor = Vector2.new(1, 1),
		textSize = 22,
		onActivated = function()
			self:_buy(shelf, entry, button, price)
		end,
	})
	button.instance.Font = Theme.Font.Display
	button.instance.ZIndex = 3
	button:SetEnabled(enabled)

	local connections = {
		card.MouseEnter:Connect(function()
			TweenService:Create(scale, Theme.Tween.Hover, { Scale = 1.03 }):Play()
		end),
		card.MouseLeave:Connect(function()
			TweenService:Create(scale, Theme.Tween.Hover, { Scale = 1 }):Play()
		end),
	}

	table.insert(self._cards, {
		Destroy = function()
			for _, c in ipairs(connections) do
				c:Disconnect()
			end
			button:Destroy()
			card:Destroy()
		end,
	})
end

function Market:_buy(shelf, entry, button, price: number)
	-- An owned VFX: equip it, or take it off if it is the one on.
	if shelf.equip and self:_owns(shelf.field, entry.id) then
		local action = self._remotes.VFXAction
		if not action or not entry.slot then
			return
		end
		local on = player:GetAttribute(VFXConfig.Attribute[entry.slot]) == entry.id
		task.spawn(function()
			pcall(function()
				action:InvokeServer("equip", entry.slot, if on then nil else entry.id)
			end)
			self:_fill("VFX")
		end)
		return
	end
	if entry.robux then
		-- Roblox owns this transaction; we only ask for the prompt.
		if self._remotes.promptPurchase and entry.ready ~= false then
			self._remotes.promptPurchase:FireServer(entry.kind, entry.id)
		end
		return
	end

	local remote = shelf.remote and self._remotes[shelf.remote]
	if not remote then
		return
	end

	local function say(text: string)
		if button then
			pcall(function()
				button:SetText(text)
			end)
		end
	end

	-- Not enough cash: say how much more, rather than a dead button.
	if self._coins < price then
		say("NEED $" .. comma(price - self._coins))
		task.delay(1.2, function()
			say("$" .. comma(price))
		end)
		return
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
		-- The server decides; redraw from ownership rather than assuming.
		say(ok and result ~= false and "BOUGHT ✓" or "REFUSED")
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
		card.Destroy()
	end
	self._menu:Destroy()
end

return Market
