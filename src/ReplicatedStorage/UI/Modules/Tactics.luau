--!strict
-- ZEE TACTICS: the gear counter, and the gear locker in the inventory.
--
-- The counter (Tactics.new) is what the clerk behind the counter opens: a tab per slot --
-- HEALS, ARMOR, BOMBS -- and the six grades of each side by side, Common to Mastery, each
-- card flooded with its grade's colour the way the reference weapon cards are, with what it
-- does, what it costs and one button: BUY, EQUIP, or EQUIPPED. Along the top, what you are
-- carrying now and what you have to spend (and the Street Cred discount, when you have one).
--
-- The locker (Tactics.Locker) is the same gear, smaller, in the inventory's GEAR section:
-- three rows, one per slot, and a click swaps what is in it. Anything you do not own shows
-- its price and where to buy it. Along the top, the RESTOCK strip: run out of frags, heals
-- or armour mid-life and buy one more right there, up to what a fresh life carries.
--
-- GearService owns every number; this only draws its state and names an id.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menu = require(script.Parent.Menu)
local UISound = require(script.Parent.UISound)
local GearConfig = require(ReplicatedStorage:WaitForChild("GearConfig"))
local UtilityConfig = require(ReplicatedStorage:WaitForChild("UtilityConfig"))

local Tactics = {}
Tactics.__index = Tactics

local GOLD = Color3.fromRGB(255, 204, 60)
local CRYSTAL = Color3.fromRGB(150, 210, 255)

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function priceText(state: any, item: GearConfig.Gear): string
	local coins = type(state.prices) == "table" and tonumber(state.prices[item.id]) or item.coins
	local text = "$" .. commas(coins or item.coins)
	if item.crystals > 0 then
		text ..= "  💎" .. item.crystals
	end
	return text
end

--- One gear card. `compact` is the locker's small tile; otherwise the counter's full card.
--- Returns the frame and the action button (nil on a compact card: the tile is the button).
local function card(parent: GuiObject, item: GearConfig.Gear, state: any, compact: boolean, order: number,
	onAction: (item: GearConfig.Gear, action: string) -> ()): Frame
	local tier = item.tier
	local colour = GearConfig.TierColour[tier] or Theme.Colour.Stroke
	local owned = type(state.owned) == "table" and state.owned[item.id] == true
	local equipped = type(state.equipped) == "table" and state.equipped[item.slot] == item.id
	local level = tonumber(state.level) or 1
	local lockedByLevel = not owned and level < item.level
	local w, h = if compact then 104 else 146, if compact then 124 else 294

	local tile = Instance.new("Frame")
	tile.Name = "Gear_" .. item.id
	tile.BackgroundColor3 = if owned or not compact then Theme.Shade(colour, -0.38) else Theme.Colour.Sunken
	tile.BorderSizePixel = 0
	tile.Size = UDim2.fromOffset(w, h)
	tile.LayoutOrder = order
	tile.Parent = parent
	Components.Corner(tile, if compact then 12 else 16)
	local rim = Components.Stroke(tile, if equipped then GOLD else colour:Lerp(Color3.new(1, 1, 1), 0.25),
		if equipped then 4 else 2.5)
	rim.Transparency = if owned or not compact then 0 else 0.4
	local wash = Components.Gradient(tile, Color3.new(1, 1, 1), Color3.fromRGB(140, 140, 150), 90)
	if tier == "Mastery" then
		-- The top grade shimmers: a slow sweep of light across the card.
		local sheen = Instance.new("UIGradient")
		sheen.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 90, 140)),
			ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 220, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(170, 90, 255)),
		})
		sheen.Rotation = 35
		sheen.Parent = rim
		TweenService:Create(sheen, TweenInfo.new(2.4, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1),
			{ Rotation = 395 }):Play()
	end
	local _ = wash

	local chip = Components.Chip(tile, if compact then string.sub(tier, 1, 3) else tier, colour, { filled = true })
	chip.Position = UDim2.fromOffset(8, 8)
	if equipped then
		local tick = Components.Chip(tile, "✓", GOLD, { filled = true })
		tick.AnchorPoint = Vector2.new(1, 0)
		tick.Position = UDim2.new(1, -8, 0, 8)
	end

	local icon = Components.Icon(tile, item.icon, if compact then 34 else 50)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, if compact then 26 else 36)
	if not owned and compact then
		icon.TextTransparency = 0.45
	end

	local name = Components.Label(tile, {
		text = string.upper(item.name),
		face = Theme.Face.HeavyItalic,
		size = if compact then 14 else 19,
		align = Enum.TextXAlignment.Center,
		colour = if owned or not compact then Theme.Colour.Text else Theme.Colour.TextDim,
		outline = 2,
		wrap = true,
	})
	name.Position = UDim2.fromOffset(4, if compact then 66 else 96)
	name.Size = UDim2.new(1, -8, 0, if compact then 30 else 44)

	if not compact then
		-- What it does, a line each.
		local lines = GearConfig.Describe(item)
		for i, line in ipairs(lines) do
			local l = Components.Label(tile, { text = line, size = 14, font = Theme.Font.Bold,
				colour = Theme.Colour.TextDim, align = Enum.TextXAlignment.Center, outline = 1.2 })
			l.Position = UDim2.fromOffset(4, 140 + (i - 1) * 16)
			l.Size = UDim2.new(1, -8, 0, 16)
		end
	end

	-- Price, or what the button is going to do.
	local bottom = if compact then h - 26 else h - 82
	local price = Components.Label(tile, {
		text = if owned then (if equipped then "EQUIPPED" else "OWNED") elseif GearConfig.IsFree(item.id) then "FREE"
			else priceText(state, item),
		font = Theme.Font.Display,
		size = if compact then 14 else 17,
		colour = if owned then (if equipped then GOLD else Theme.Colour.Accent) else Theme.Colour.Currency,
		align = Enum.TextXAlignment.Center,
		outline = false,
	})
	Components.Outline(price, 1.8, if owned then Theme.Colour.Outline else Theme.Colour.CurrencyEdge, 0)
	price.Position = UDim2.fromOffset(0, bottom)
	price.Size = UDim2.new(1, 0, 0, 20)

	if compact then
		local hit = Instance.new("TextButton")
		hit.Name = "Hit"
		hit.BackgroundTransparency = 1
		hit.Text = ""
		hit.Size = UDim2.fromScale(1, 1)
		hit.ZIndex = 6
		hit.Parent = tile
		hit.Activated:Connect(function()
			if owned and not equipped then
				onAction(item, "equip")
			else
				UISound.Play("Clunk", 1, 0.4)
			end
		end)
		return tile
	end

	local text, primary, enabled, action = "BUY", true, true, "buy"
	if equipped then
		text, primary, enabled, action = "✓ EQUIPPED", false, false, ""
	elseif owned then
		text, primary, enabled, action = "EQUIP", true, true, "equip"
	elseif lockedByLevel then
		text, primary, enabled, action = "🔒 LV " .. item.level, false, false, ""
	end
	local button = Components.Button(tile, {
		name = "Action",
		text = text,
		primary = primary,
		colour = if owned and not equipped then Theme.Colour.Info else nil,
		textSize = 18,
		size = UDim2.new(1, -20, 0, 36),
		position = UDim2.new(0, 10, 1, -48),
		onActivated = function()
			if action ~= "" then
				onAction(item, action)
			end
		end,
	})
	button:SetEnabled(enabled)
	if equipped then
		button:SetSelected(true)
	end
	return tile
end

-- ------------------------------------------------------------ the counter --

function Tactics.new(parent: Instance, remotes: { gearAction: RemoteFunction }, toast: any?)
	local self = setmetatable({}, Tactics)
	self._remotes = remotes
	self._toast = toast
	self._cards = {} :: { Instance }
	self._state = nil :: any
	self._slot = "Heal"

	local categories = {}
	for _, slot in ipairs(GearConfig.Slots) do
		local info = GearConfig.SlotInfo[slot]
		table.insert(categories, { id = slot, label = info.label, icon = info.icon })
	end
	local menu = Menu.new(parent, {
		id = "Tactics",
		title = "Zee Tactics",
		subtitle = "Heals, armour and bombs -- Common to Mastery",
		icon = "🎒",
		size = UDim2.fromOffset(980, 590),
		categories = categories,
		tabs = "top",
	})
	self._menu = menu
	local content = menu.content

	-- What you carry now, and what you have to spend.
	local strip = Components.Panel(content, { name = "Loadout", colour = Theme.Colour.PanelRaised, radius = 12,
		size = UDim2.new(1, 0, 0, 44) })
	local list = Components.List(strip, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Left)
	list.VerticalAlignment = Enum.VerticalAlignment.Center
	Components.Padding(strip, nil, 12, 0)
	local carrying = Components.Label(strip, { text = "CARRYING", caps = true, size = 12 })
	carrying.AutomaticSize = Enum.AutomaticSize.X
	carrying.Size = UDim2.fromOffset(0, 20)
	self._loadout = {} :: { [string]: TextLabel }
	for i, slot in ipairs(GearConfig.Slots) do
		local l = Components.Label(strip, { text = "", size = 16, layoutOrder = i })
		l.AutomaticSize = Enum.AutomaticSize.X
		l.Size = UDim2.fromOffset(0, 22)
		self._loadout[slot] = l
	end
	-- Pinned right over the strip (not part of its row).
	self._wallet = Components.Label(content, { text = "", font = Theme.Font.Display, size = 18,
		colour = Theme.Colour.Currency, align = Enum.TextXAlignment.Right, outline = false })
	Components.Outline(self._wallet, 2, Theme.Colour.CurrencyEdge, 0)
	self._wallet.AnchorPoint = Vector2.new(1, 0.5)
	self._wallet.Position = UDim2.new(1, -14, 0, 22)
	self._wallet.Size = UDim2.fromOffset(420, 24)
	self._wallet.ZIndex = 3

	self._row = Instance.new("Frame")
	self._row.Name = "Cards"
	self._row.BackgroundTransparency = 1
	self._row.Position = UDim2.fromOffset(0, 54)
	self._row.Size = UDim2.new(1, 0, 0, 298)
	self._row.Parent = content
	local row = Components.List(self._row, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	row.VerticalAlignment = Enum.VerticalAlignment.Center

	self._blurb = Components.Label(content, { text = "", size = Theme.Text.Body, colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center })
	self._blurb.Position = UDim2.fromOffset(0, 360)
	self._blurb.Size = UDim2.new(1, 0, 0, 20)
	self._status = Components.Label(content, { text = "", size = Theme.Text.Body, font = Theme.Font.Bold,
		align = Enum.TextXAlignment.Center, colour = Theme.Colour.TextMuted })
	self._status.Position = UDim2.fromOffset(0, 382)
	self._status.Size = UDim2.new(1, 0, 0, 20)

	menu:OnCategory(function(id: string)
		self._slot = id
		if self._state then
			self:_render(self._state)
		end
	end)
	menu:OnOpen(function()
		self:Refresh()
	end)
	return self
end

function Tactics:Refresh()
	task.spawn(function()
		local ok, state = pcall(function()
			return self._remotes.gearAction:InvokeServer("state")
		end)
		if ok and type(state) == "table" then
			self._state = state
			self:_render(state)
		else
			self._status.Text = "The counter is loading -- try again in a moment"
		end
	end)
end

function Tactics:_act(item: GearConfig.Gear, action: string)
	task.spawn(function()
		local ok, result = pcall(function()
			return self._remotes.gearAction:InvokeServer(action, item.id)
		end)
		if ok and type(result) == "table" then
			if type(result.state) == "table" then
				self._state = result.state
				self:_render(result.state)
			end
			if result.ok then
				UISound.Play(if action == "buy" then "Ring" else "Click", 1, 0.6)
				self._status.TextColor3 = Theme.Colour.Accent
				self._status.Text = (if action == "buy" then "Bought " else "Equipped ") .. item.name
					.. (if result.restocked then "  ·  kit restocked" else "  ·  ready on your next life")
				if self._toast and action == "buy" then
					self._toast:Push({ title = item.name, text = "Bought and equipped", icon = item.icon,
						colour = GearConfig.TierColour[item.tier] })
				end
			else
				UISound.Play("Clunk", 1, 0.5)
				self._status.TextColor3 = Theme.Colour.Danger
				self._status.Text = tostring(result.reason or "Can't do that")
			end
		end
	end)
end

function Tactics:_render(state: any)
	for _, c in ipairs(self._cards) do
		c:Destroy()
	end
	table.clear(self._cards)
	for i, item in ipairs(GearConfig.ForSlot(self._slot)) do
		table.insert(self._cards, card(self._row, item, state, false, i, function(it, action)
			self:_act(it, action)
		end))
	end
	for _, slot in ipairs(GearConfig.Slots) do
		local item = GearConfig.Get(type(state.equipped) == "table" and state.equipped[slot] or nil)
			or GearConfig.Resolve(slot, nil)
		local label = self._loadout[slot]
		label.Text = item.icon .. " " .. item.name
		label.TextColor3 = GearConfig.TierColour[item.tier]
	end
	local wallet = "$" .. commas(tonumber(state.coins) or 0) .. "   💎 " .. tostring(state.crystals or 0)
	local discount = tonumber(state.discount) or 0
	if discount > 0 then
		wallet = ("STREET CRED -%d%%   "):format(math.floor(discount * 100 + 0.5)) .. wallet
	end
	self._wallet.Text = wallet
	self._blurb.Text = GearConfig.SlotInfo[self._slot].blurb
	if self._status.Text == "" then
		self._status.Text = "Equipping at the counter restocks your kit (once every 20 seconds)"
	end
end

function Tactics:Toggle()
	self._menu:Toggle()
end

function Tactics:Close()
	self._menu:Close()
end

function Tactics:IsOpen(): boolean
	return self._menu:IsOpen()
end

-- ------------------------------------------------------------- the locker --

--- The inventory's GEAR section: a row per slot, a click to swap. Returns an object with
--- :Refresh() and the frame (hidden until the section is picked).
-- The restock strip's tiles: what each refills, in the kit's own words and colours.
local RESTOCK_LOOK = {
	Frag = { icon = UtilityConfig.Throwables.Frag.icon, name = "FRAG", colour = UtilityConfig.Throwables.Frag.colour },
	Flash = { icon = UtilityConfig.Throwables.Flash.icon, name = "FLASH", colour = UtilityConfig.Throwables.Flash.colour },
	Smoke = { icon = UtilityConfig.Throwables.Smoke.icon, name = "SMOKE", colour = UtilityConfig.Throwables.Smoke.colour },
	Medkit = { icon = UtilityConfig.Medkit.icon, name = "HEAL", colour = UtilityConfig.Medkit.colour },
	Armour = { icon = "🛡", name = "ARMOUR", colour = Color3.fromRGB(80, 200, 255) },
}
local WHY_TEXT = { full = "FULL", locked = "LOCKED", duel = "NOT IN A DUEL", dead = "—", coins = "NEED $" }

--- One restock tile: icon, what you carry of what you could, and the price -- the whole tile
--- is the buy button.
local function restockTile(parent: GuiObject, id: string, info: any, order: number, onBuy: (string) -> ()): TextButton
	local look = RESTOCK_LOOK[id]
	local can = info.why == nil
	local tile = Instance.new("TextButton")
	tile.Name = "Restock_" .. id
	tile.Text = ""
	tile.AutoButtonColor = false
	tile.LayoutOrder = order
	tile.Size = UDim2.fromOffset(128, 74)
	tile.BackgroundColor3 = if can then Theme.Shade(look.colour, -0.55) else Theme.Colour.Sunken
	tile.BorderSizePixel = 0
	tile.Parent = parent
	Components.Corner(tile, 12)
	local rim = Components.Stroke(tile, look.colour, if can then 2.5 else 1.5)
	rim.Transparency = if can then 0 else 0.55
	Components.Gradient(tile, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 160), 90)

	local icon = Components.Label(tile, { text = look.icon, size = 26 })
	icon.Position = UDim2.fromOffset(8, 6)
	icon.Size = UDim2.fromOffset(34, 34)
	local name = Components.Label(tile, { text = look.name, face = Theme.Face.HeavyItalic, size = 16 })
	name.Position = UDim2.fromOffset(46, 6)
	name.Size = UDim2.new(1, -52, 0, 18)
	local count = if id == "Armour" then ("%d / %d"):format(info.have, info.cap) else ("%d / %d"):format(info.have, info.cap)
	local carried = Components.Label(tile, { text = count, size = 14, colour = Theme.Colour.TextMuted })
	carried.Name = "Count"
	carried.Position = UDim2.fromOffset(46, 24)
	carried.Size = UDim2.new(1, -52, 0, 16)
	local priceLine = if can then "+1  ·  $" .. commas(info.price)
		elseif info.why == "coins" then WHY_TEXT.coins .. commas(info.price)
		else WHY_TEXT[info.why] or ""
	if id == "Armour" and can then
		priceLine = ("+%d  ·  $%s"):format(info.plate or 25, commas(info.price))
	end
	local price = Components.Label(tile, { text = priceLine, face = Theme.Face.Condensed, size = 15,
		colour = if can then GOLD elseif info.why == "coins" then Color3.fromRGB(255, 120, 110) else Theme.Colour.TextMuted })
	price.Name = "Price"
	price.Position = UDim2.fromOffset(8, 48)
	price.Size = UDim2.new(1, -16, 0, 20)
	tile.MouseEnter:Connect(function()
		if can then
			TweenService:Create(tile, TweenInfo.new(0.12), { BackgroundColor3 = Theme.Shade(look.colour, -0.4) }):Play()
		end
	end)
	tile.MouseLeave:Connect(function()
		TweenService:Create(tile, TweenInfo.new(0.12),
			{ BackgroundColor3 = if can then Theme.Shade(look.colour, -0.55) else Theme.Colour.Sunken }):Play()
	end)
	tile.Activated:Connect(function()
		if can then
			onBuy(id)
		else
			UISound.Play("Clunk", 0.8, 0.35)
		end
	end)
	return tile
end

function Tactics.Locker(parent: GuiObject, remote: RemoteFunction)
	local locker = {} :: any
	-- Scrolls: the restock strip on top, the three gear rows under it.
	local frame = Instance.new("ScrollingFrame")
	frame.Name = "GearLocker"
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.CanvasSize = UDim2.fromOffset(0, 140 + #GearConfig.Slots * 144)
	frame.ScrollBarThickness = 6
	frame.ScrollBarImageColor3 = Theme.Colour.Stroke
	frame.ScrollingDirection = Enum.ScrollingDirection.Y
	frame.Visible = false
	frame.Parent = parent
	locker.frame = frame
	local rows: { [string]: Frame } = {}
	local cards: { Instance } = {}

	-- RESTOCK: one more of anything you have run out of, without waiting for the next life.
	local strip = Components.Panel(frame, { name = "Restock", colour = Theme.Colour.Sunken, radius = 12,
		transparency = 0.2, size = UDim2.new(1, -10, 0, 100), position = UDim2.fromOffset(0, 30) })
	local stripTitle = Components.Label(strip, { text = "RESTOCK", face = Theme.Face.HeavyItalic, size = 20 })
	stripTitle.Position = UDim2.fromOffset(12, 8)
	stripTitle.Size = UDim2.fromOffset(102, 24)
	local stripBlurb = Components.Label(strip, { text = "Out mid-fight? One more, up to what a fresh life carries.",
		size = 12, colour = Theme.Colour.TextMuted, wrap = true })
	stripBlurb.Position = UDim2.fromOffset(12, 34)
	stripBlurb.Size = UDim2.fromOffset(100, 60)
	stripBlurb.TextYAlignment = Enum.TextYAlignment.Top
	local restockRow = Instance.new("Frame")
	restockRow.Name = "Row"
	restockRow.BackgroundTransparency = 1
	restockRow.Position = UDim2.fromOffset(120, 6)
	restockRow.Size = UDim2.new(1, -126, 1, -12)
	restockRow.Parent = strip
	local restockList = Components.List(restockRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left)
	restockList.VerticalAlignment = Enum.VerticalAlignment.Center
	local restockTiles: { Instance } = {}

	local head = Components.Label(frame, { text = "GEAR  ·  click something you own to carry it",
		face = Theme.Face.Condensed, size = 20 })
	head.Size = UDim2.new(1, 0, 0, 24)
	local where = Components.Label(frame, { text = "Buy more at ZEE TACTICS, Downtown", size = 14,
		colour = Theme.Colour.TextMuted, align = Enum.TextXAlignment.Right })
	where.Size = UDim2.new(1, -6, 0, 24)

	for i, slot in ipairs(GearConfig.Slots) do
		local info = GearConfig.SlotInfo[slot]
		local band = Components.Panel(frame, { name = slot, colour = Theme.Colour.Sunken, radius = 12, transparency = 0.2,
			size = UDim2.new(1, -10, 0, 136), position = UDim2.fromOffset(0, 138 + (i - 1) * 144) })
		local label = Components.Label(band, { text = info.icon .. "  " .. string.upper(info.label),
			face = Theme.Face.HeavyItalic, size = 20 })
		label.Position = UDim2.fromOffset(12, 8)
		label.Size = UDim2.fromOffset(102, 24)
		-- Kept inside its column: "BOMBS" at full size ran in under the first card.
		label.TextScaled = true
		local fit = Instance.new("UITextSizeConstraint")
		fit.MaxTextSize = 20
		fit.MinTextSize = 12
		fit.Parent = label
		local slotBlurb = Components.Label(band, { text = info.blurb, size = 12, colour = Theme.Colour.TextMuted,
			wrap = true })
		slotBlurb.Position = UDim2.fromOffset(12, 36)
		slotBlurb.Size = UDim2.fromOffset(100, 90)
		slotBlurb.TextYAlignment = Enum.TextYAlignment.Top
		local row = Instance.new("Frame")
		row.Name = "Row"
		row.BackgroundTransparency = 1
		row.Position = UDim2.fromOffset(120, 6)
		row.Size = UDim2.new(1, -126, 1, -12)
		row.Parent = band
		local l = Components.List(row, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left)
		l.VerticalAlignment = Enum.VerticalAlignment.Center
		rows[slot] = row
	end

	local render: (any) -> ()
	local function renderRestock(state: any)
		for _, t in ipairs(restockTiles) do
			t:Destroy()
		end
		table.clear(restockTiles)
		local restock = type(state.restock) == "table" and state.restock or nil
		strip.Visible = restock ~= nil
		if not restock then
			return
		end
		for i, id in ipairs(UtilityConfig.Restock.order) do
			local info = restock.items and restock.items[id]
			if info then
				table.insert(restockTiles, restockTile(restockRow, id, info, i, function(item)
					task.spawn(function()
						local ok, result = pcall(function()
							return remote:InvokeServer("restock", item)
						end)
						if ok and type(result) == "table" then
							UISound.Play(if result.ok then "Ring" else "Clunk", if result.ok then 1.4 else 0.8, 0.5)
							if type(result.state) == "table" then
								render(result.state)
							end
						end
					end)
				end))
			end
		end
	end

	function render(state: any)
		renderRestock(state)
		for _, c in ipairs(cards) do
			c:Destroy()
		end
		table.clear(cards)
		for _, slot in ipairs(GearConfig.Slots) do
			for i, item in ipairs(GearConfig.ForSlot(slot)) do
				table.insert(cards, card(rows[slot], item, state, true, i, function(it)
					task.spawn(function()
						local ok, result = pcall(function()
							return remote:InvokeServer("equip", it.id)
						end)
						if ok and type(result) == "table" and type(result.state) == "table" then
							UISound.Play("Click", 1, 0.6)
							render(result.state)
						end
					end)
				end))
			end
		end
	end

	function locker:Refresh()
		task.spawn(function()
			local ok, state = pcall(function()
				return remote:InvokeServer("state")
			end)
			if ok and type(state) == "table" then
				render(state)
			end
		end)
	end
	return locker
end

Tactics.Card = card
Tactics.CRYSTAL = CRYSTAL

return Tactics
