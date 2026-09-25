--!strict
-- HUD: what stays on screen while the player is actually playing.
--
-- This module draws and nothing else. It exposes setters -- SetAmmo, SetHealth, SetWeapon --
-- and knows nothing about tools, remotes or the character. Whatever binds it to the game
-- lives in the MainUI controller, so the interface can be redesigned without touching
-- gameplay and gameplay can change without breaking the interface.
--
-- Layout follows the references:
--   bottom-left   the player's name, armour segments and a thick rimmed health bar
--   bottom-right  a big condensed ammo count beside the weapon slots (the dock)
--   top-centre    cash in outlined green with a "+" into the shop, and the gold level diamond
-- The middle of the screen stays clear. Values tween when they change, then stop.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local Hud = {}
Hud.__index = Hud

local WHITE = Color3.new(1, 1, 1)
local HEALTH_WIDTH = 300
local ARMOUR_SEGMENTS = 3

-- Thousands separators, so 12450 reads as 12,450 at a glance.
local function comma(n: number): string
	local s = string.format("%d", math.floor(n))
	local sign = ""
	if s:sub(1, 1) == "-" then
		sign, s = "-", s:sub(2)
	end
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return sign .. (out:gsub("^,", ""))
end

local function pop(object: any, amount: number?)
	local scale = object:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = object
	end
	(scale :: UIScale).Scale = amount or 1.18
	TweenService:Create(scale :: UIScale, Theme.Tween.Pop, { Scale = 1 }):Play()
end

-- ------------------------------------------------------------------ build --

local function buildIdentity(self, parent: GuiObject)
	local holder = Instance.new("Frame")
	holder.Name = "Identity"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, Theme.Inset.Top - 38)
	holder.Size = UDim2.fromOffset(0, 50)
	holder.AutomaticSize = Enum.AutomaticSize.X
	holder.Parent = parent
	local row = Components.List(holder, Enum.FillDirection.Horizontal, Theme.Space.S, Enum.HorizontalAlignment.Center)
	row.VerticalAlignment = Enum.VerticalAlignment.Center

	-- The cash pill: dark glass, a banknote breaking out of its left edge, and the amount in
	-- outlined bright green -- the most-read number in the references.
	local pill = Instance.new("Frame")
	pill.Name = "Cash"
	pill.BackgroundColor3 = Theme.Colour.Panel
	pill.BackgroundTransparency = 0.35
	pill.BorderSizePixel = 0
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(150, 42)
	pill.LayoutOrder = 1
	pill.Parent = holder
	Components.Corner(pill, 10)
	local pad = Components.Padding(pill, nil, 0, 0)
	pad.PaddingLeft = UDim.new(0, 52)
	pad.PaddingRight = UDim.new(0, 16)

	local note = Components.Icon(pill, "💵", 34)
	note.AnchorPoint = Vector2.new(0.5, 0.5)
	note.Position = UDim2.new(0, -44, 0.5, -2)
	note.Rotation = -24

	local amount = Components.Label(pill, {
		text = "0",
		font = Theme.Font.Display,
		size = 30,
		colour = Theme.Colour.Currency,
		autoSize = true,
		outline = false,
	})
	amount.AnchorPoint = Vector2.new(0, 0.5)
	amount.Position = UDim2.fromScale(0, 0.5)
	Components.Outline(amount, 2.6, Theme.Colour.CurrencyEdge, 0)
	-- The label sizes itself; this keeps the pill from collapsing to nothing before it does.
	local minWidth = Instance.new("UISizeConstraint")
	minWidth.MinSize = Vector2.new(120, 42)
	minWidth.Parent = pill

	-- The "+" into the shop.
	local plus = Instance.new("TextButton")
	plus.Name = "Shop"
	plus.AutoButtonColor = false
	plus.Text = "+"
	plus.Font = Theme.Font.Display
	plus.TextSize = 30
	plus.TextColor3 = WHITE
	plus.BackgroundColor3 = Theme.Colour.Accent
	plus.Size = UDim2.fromOffset(40, 40)
	plus.LayoutOrder = 2
	plus.Parent = holder
	Components.Corner(plus, 10)
	Components.Stroke(plus, Theme.Colour.Outline, 2.5).Transparency = 0.1
	Components.Gradient(plus, Color3.fromRGB(210, 255, 210), Color3.fromRGB(140, 170, 140))
	Components.Outline(plus, 2)
	local plusScale = Instance.new("UIScale")
	plusScale.Parent = plus
	plus.MouseEnter:Connect(function()
		TweenService:Create(plusScale, Theme.Tween.Hover, { Scale = 1.1 }):Play()
	end)
	plus.MouseLeave:Connect(function()
		TweenService:Create(plusScale, Theme.Tween.Hover, { Scale = 1 }):Play()
	end)
	plus.Activated:Connect(function()
		if self._onShop then
			self._onShop()
		end
	end)

	local badge, level = Components.LevelBadge(holder, 50)
	badge.LayoutOrder = 3

	-- The diamond is a button: it opens your profile card.
	local levelButton = Instance.new("TextButton")
	levelButton.Name = "LevelButton"
	levelButton.BackgroundTransparency = 1
	levelButton.Text = ""
	levelButton.Size = UDim2.fromScale(1, 1)
	levelButton.ZIndex = 5
	levelButton.Parent = badge
	levelButton.Activated:Connect(function()
		if self._onLevel then
			self._onLevel()
		end
	end)

	-- Crystals, the second currency: mined, looted from dailies and milestones.
	local crystals = Instance.new("Frame")
	crystals.Name = "Crystals"
	crystals.BackgroundColor3 = Theme.Colour.Panel
	crystals.BackgroundTransparency = 0.35
	crystals.Size = UDim2.fromOffset(0, 34)
	crystals.AutomaticSize = Enum.AutomaticSize.X
	crystals.LayoutOrder = 4
	crystals.Visible = false
	crystals.Parent = holder
	Components.Corner(crystals, 10)
	Components.Padding(crystals, nil, 8, 0)
	local crystalRow = Components.List(crystals, Enum.FillDirection.Horizontal, 4)
	crystalRow.VerticalAlignment = Enum.VerticalAlignment.Center
	Components.Icon(crystals, "💎", 20).LayoutOrder = 1
	local crystalText = Components.Label(crystals, {
		text = "0",
		font = Theme.Font.Display,
		size = 22,
		colour = Color3.fromRGB(130, 225, 255),
		autoSize = true,
		layoutOrder = 2,
		outline = false,
	})
	Components.Outline(crystalText, 2.2, Color3.fromRGB(10, 50, 80), 0)
	self._crystals, self._crystalText = crystals, crystalText

	-- XP is a hairline under the pair. It is progress, not a headline.
	local xpHolder = Instance.new("Frame")
	xpHolder.Name = "XP"
	xpHolder.BackgroundTransparency = 1
	xpHolder.AnchorPoint = Vector2.new(0.5, 0)
	xpHolder.Position = UDim2.new(0.5, 0, 0, Theme.Inset.Top + 16)
	xpHolder.Size = UDim2.fromOffset(190, 6)
	xpHolder.Parent = parent
	local xp = Components.Bar(xpHolder, { height = 6, colour = Theme.Colour.Level, radius = 3 })

	-- "+$250" drops out of the pill and fades whenever cash arrives.
	local popups = Instance.new("Frame")
	popups.Name = "CashPopups"
	popups.BackgroundTransparency = 1
	popups.AnchorPoint = Vector2.new(0.5, 0)
	popups.Position = UDim2.new(0.5, -40, 0, Theme.Inset.Top + 20)
	popups.Size = UDim2.fromOffset(200, 40)
	popups.Parent = parent

	self._cash, self._level, self._xp, self._badge = amount, level, xp, badge
	self._cashPill, self._cashPopups = pill, popups
	self._identity, self._xpHolder = holder, xpHolder
end

local function buildVitals(self, parent: GuiObject)
	local holder = Instance.new("Frame")
	holder.Name = "Vitals"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0, 1)
	holder.Position = UDim2.new(0, Theme.Inset.Side, 1, -Theme.Inset.Bottom)
	holder.Size = UDim2.fromOffset(HEALTH_WIDTH + 10, 90)
	holder.Parent = parent

	local name = Components.Label(holder, {
		text = "",
		face = Theme.Face.Condensed,
		size = 30,
		outline = 2.4,
	})
	name.Size = UDim2.new(1, 0, 0, 34)
	name.Position = UDim2.fromOffset(2, 0)
	name.TextTruncate = Enum.TextTruncate.AtEnd

	-- Armour as three cyan segments above the health bar. Only shown when armour exists.
	local armourRow = Instance.new("Frame")
	armourRow.Name = "Armour"
	armourRow.BackgroundTransparency = 1
	armourRow.Size = UDim2.fromOffset(HEALTH_WIDTH, 9)
	armourRow.Position = UDim2.fromOffset(0, 40)
	armourRow.Visible = false
	armourRow.Parent = holder
	Components.List(armourRow, Enum.FillDirection.Horizontal, 5)
	local segments = {}
	local segWidth = math.floor((HEALTH_WIDTH - 5 * (ARMOUR_SEGMENTS - 1)) / ARMOUR_SEGMENTS)
	for i = 1, ARMOUR_SEGMENTS do
		local seg = Instance.new("Frame")
		seg.BackgroundTransparency = 1
		seg.Size = UDim2.fromOffset(segWidth, 9)
		seg.LayoutOrder = i
		seg.Parent = armourRow
		local bar = Components.Bar(seg, { height = 9, colour = Theme.Colour.Armour, radius = 3 })
		table.insert(segments, bar)
	end

	-- The health bar: thick, dark-rimmed, green, with a white "chip" that trails behind the
	-- fill after a hit so the size of the hit is readable, and the number printed inside.
	local barHolder = Instance.new("Frame")
	barHolder.Name = "Health"
	barHolder.BackgroundTransparency = 1
	barHolder.Size = UDim2.fromOffset(HEALTH_WIDTH, 30)
	barHolder.Position = UDim2.fromOffset(0, 55)
	barHolder.Parent = holder

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
	track.BackgroundTransparency = 0.2
	track.BorderSizePixel = 0
	track.Size = UDim2.fromScale(1, 1)
	track.Parent = barHolder
	Components.Corner(track, 8)
	Components.Stroke(track, Theme.Colour.Outline, 3).Transparency = 0

	local chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.BackgroundColor3 = WHITE
	chip.BackgroundTransparency = 0.1
	chip.BorderSizePixel = 0
	chip.Size = UDim2.fromScale(1, 1)
	chip.Parent = track
	Components.Corner(chip, 8)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = Theme.Colour.Health
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.Parent = track
	Components.Corner(fill, 8)
	Components.Gradient(fill, Color3.fromRGB(235, 255, 235), Color3.fromRGB(160, 180, 160))

	-- A thin light line across the top of the fill: the glassy highlight on the reference bar.
	local shine = Instance.new("Frame")
	shine.Name = "Shine"
	shine.BackgroundColor3 = WHITE
	shine.BackgroundTransparency = 0.7
	shine.BorderSizePixel = 0
	shine.Size = UDim2.new(1, -10, 0, 4)
	shine.Position = UDim2.fromOffset(5, 3)
	shine.Parent = fill
	Components.Corner(shine, 2)

	local value = Components.Label(track, {
		text = "100",
		font = Theme.Font.Display,
		size = 20,
		align = Enum.TextXAlignment.Center,
		outline = 2,
	})
	value.Size = UDim2.fromScale(1, 1)
	value.ZIndex = 3

	self._vitals = holder
	self._playerName = name
	self._armourRow, self._armourSegments = armourRow, segments
	self._healthFill, self._healthChip, self._health = fill, chip, value
end

local function buildWeapon(self, parent: GuiObject)
	-- Bottom right: one row, ammo on the left of the slots, bottoms aligned. The hotbar
	-- module is handed `dock` and simply joins the row.
	local dock = Instance.new("Frame")
	dock.Name = "WeaponDock"
	dock.BackgroundTransparency = 1
	dock.AnchorPoint = Vector2.new(1, 1)
	dock.Position = UDim2.new(1, -Theme.Inset.Side, 1, -Theme.Inset.Bottom)
	dock.Size = UDim2.fromOffset(0, 86)
	dock.AutomaticSize = Enum.AutomaticSize.X
	dock.Parent = parent
	local row = Components.List(dock, Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Right)
	row.VerticalAlignment = Enum.VerticalAlignment.Bottom

	local block = Instance.new("Frame")
	block.Name = "Ammo"
	block.BackgroundTransparency = 1
	block.Size = UDim2.fromOffset(170, 86)
	block.LayoutOrder = 1
	block.Parent = dock

	local reloading = Components.Label(block, {
		text = "RELOADING",
		face = Theme.Face.Condensed,
		size = 18,
		colour = Theme.Colour.Level,
		align = Enum.TextXAlignment.Right,
	})
	reloading.Size = UDim2.new(1, 0, 0, 20)
	reloading.Position = UDim2.fromOffset(0, 0)
	reloading.Visible = false

	-- "18 /20 |||" -- the magazine in a heavy condensed face, the capacity small beside it.
	local numbers = Instance.new("Frame")
	numbers.Name = "Numbers"
	numbers.BackgroundTransparency = 1
	numbers.AnchorPoint = Vector2.new(1, 0)
	numbers.Position = UDim2.new(1, 0, 0, 12)
	numbers.Size = UDim2.fromOffset(0, 54)
	numbers.AutomaticSize = Enum.AutomaticSize.X
	numbers.Parent = block
	local numbersRow = Components.List(numbers, Enum.FillDirection.Horizontal, 4, Enum.HorizontalAlignment.Right)
	numbersRow.VerticalAlignment = Enum.VerticalAlignment.Bottom

	local current = Components.Label(numbers, {
		text = "0",
		face = Theme.Face.Condensed,
		size = 54,
		align = Enum.TextXAlignment.Right,
		autoSize = true,
		layoutOrder = 1,
		outline = 3,
	})
	local reserve = Components.Label(numbers, {
		text = "/0",
		face = Theme.Face.Condensed,
		size = 22,
		colour = Theme.Colour.TextDim,
		autoSize = true,
		layoutOrder = 2,
	})
	local rounds = Components.Label(numbers, {
		text = "|||",
		face = Theme.Face.Condensed,
		size = 22,
		colour = Theme.Colour.TextDim,
		autoSize = true,
		layoutOrder = 3,
	})
	-- Nudge the small type down onto the big number's baseline.
	for _, small in ipairs({ reserve, rounds }) do
		local p = Instance.new("UIPadding")
		p.PaddingBottom = UDim.new(0, 8)
		p.Parent = small
	end

	local name = Components.Label(block, {
		text = "",
		font = Theme.Font.Bold,
		size = 20,
		align = Enum.TextXAlignment.Right,
	})
	name.Size = UDim2.new(1, 0, 0, 22)
	name.Position = UDim2.new(0, 0, 1, -22)
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local mode = Components.Chip(block, "AUTO", Theme.Colour.PanelRaised)
	mode.AnchorPoint = Vector2.new(0, 1)
	mode.Position = UDim2.new(0, 0, 1, -24)
	mode.Visible = false

	self._dock = dock
	self._weapon, self._weaponName, self._ammo, self._reserve = block, name, current, reserve
	self._rounds, self._mode, self._reloading = rounds, mode, reloading
end

-- ------------------------------------------------------------------- api --

function Hud.new(parent: Instance)
	local self = setmetatable({}, Hud)

	local root = Instance.new("Frame")
	root.Name = "HUD"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromScale(1, 1)
	root.ZIndex = Theme.Layer.HUD
	root.Parent = parent
	self._root = root

	buildIdentity(self, root)
	buildVitals(self, root)
	buildWeapon(self, root)

	-- The dock stays visible (the hotbar lives in it); only the ammo block comes and goes.
	self.dock = self._dock
	self._maxHealth = 100
	self._lastHealth = nil
	self._cashValue = nil
	self._levelValue = nil
	self._weapon.Visible = false

	local player = Players.LocalPlayer
	if player then
		self._playerName.Text = player.DisplayName
	end
	return self
end

--- The "+" beside the cash opens whatever the controller says the shop is.
function Hud:OnShop(handler: () -> ())
	self._onShop = handler
end

--- Clicking the level diamond opens whatever the controller says (the profile card).
function Hud:OnLevel(handler: () -> ())
	self._onLevel = handler
end

function Hud:SetCrystals(amount: number)
	local n = math.max(0, math.floor(amount))
	self._crystals.Visible = n > 0
	if self._crystalText.Text ~= tostring(n) then
		self._crystalText.Text = tostring(n)
		pop(self._crystals, 1.2)
	end
end

function Hud:SetPlayerName(name: string)
	self._playerName.Text = name
end

--- Shown only while a weapon is actually equipped, so an unarmed player gets a clean screen.
function Hud:SetWeapon(name: string?, rarity: string?, fireMode: string?)
	local has = name ~= nil and name ~= ""
	self._weapon.Visible = has
	if not has then
		return
	end
	self._weaponName.Text = name
	-- The name wears its rarity, the way the selected slot name is tinted in the references.
	self._weaponName.TextColor3 = rarity and Theme.Shade(Theme.RarityColour(rarity), 0.35) or Theme.Colour.Text

	if fireMode and fireMode ~= "" then
		self._mode.Visible = true
		local label = self._mode:FindFirstChild("Text")
		if label and label:IsA("TextLabel") then
			label.Text = string.upper(fireMode)
		end
	else
		self._mode.Visible = false
	end
	pop(self._weapon, 1.08)
end

--- `capacity` is the magazine size. This game has no separate reserve pool, so the second
--- number is what a full magazine holds rather than rounds in a backpack.
function Hud:SetAmmo(current: number, capacity: number)
	local rounds = math.max(0, math.floor(current))
	local previous = self._ammoValue
	self._ammoValue = rounds
	self._ammo.Text = tostring(rounds)
	self._reserve.Text = "/" .. tostring(math.max(0, math.floor(capacity)))
	self._rounds.Visible = capacity > 0

	-- Empty goes red, a quarter-magazine goes amber.
	local fraction = capacity > 0 and rounds / capacity or 0
	local colour = rounds <= 0 and Theme.Colour.Danger
		or fraction <= 0.25 and Theme.Colour.Level
		or Theme.Colour.Text
	self._ammo.TextColor3 = colour

	-- Each round spent gives the number a tiny kick; a full magazine landing gives it a big one.
	if previous ~= nil then
		if rounds > previous then
			pop(self._ammo, 1.25)
		elseif rounds < previous then
			pop(self._ammo, 1.07)
		end
	end
end

function Hud:SetReloading(reloading: boolean)
	self._reloading.Visible = reloading
	if reloading then
		pop(self._reloading, 1.15)
	end
end

function Hud:SetHealth(current: number, maximum: number?)
	local max = maximum or self._maxHealth
	self._maxHealth = max
	local clamped = math.clamp(current, 0, max)
	self._health.Text = tostring(math.floor(clamped + 0.5))

	local fraction = max > 0 and clamped / max or 0
	local colour = fraction <= 0.25 and Theme.Colour.Danger
		or fraction <= 0.5 and Theme.Colour.Level
		or Theme.Colour.Health
	TweenService:Create(self._healthFill, Theme.Tween.Value, {
		Size = UDim2.fromScale(fraction, 1),
		BackgroundColor3 = colour,
	}):Play()
	self._healthFill.Visible = fraction > 0.001

	-- The chip holds the old value for a beat, then drains: damage reads as a chunk bitten
	-- out of the bar rather than the bar simply being shorter. Healing snaps it forward.
	local previous = self._lastHealth
	self._lastHealth = clamped
	if previous and clamped < previous then
		self._chipToken = (self._chipToken or 0) + 1
		local token = self._chipToken
		task.delay(0.4, function()
			if token == self._chipToken then
				TweenService:Create(self._healthChip, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
					Size = UDim2.fromScale(fraction, 1),
				}):Play()
			end
		end)
		-- A big hit jolts the whole block.
		if previous - clamped >= max * 0.12 then
			local base = UDim2.new(0, Theme.Inset.Side, 1, -Theme.Inset.Bottom)
			self._vitals.Position = base + UDim2.fromOffset(math.random(-5, 5), math.random(-4, 2))
			TweenService:Create(self._vitals, TweenInfo.new(0.18, Enum.EasingStyle.Elastic), { Position = base }):Play()
		end
	else
		self._healthChip.Size = UDim2.fromScale(fraction, 1)
	end
end

--- Pass 0 (or never call it) and the armour segments stay hidden entirely.
function Hud:SetArmour(current: number, maximum: number)
	local visible = maximum > 0
	self._armourRow.Visible = visible
	if not visible then
		return
	end
	-- Each segment holds an equal share and fills in turn, left to right.
	local per = maximum / #self._armourSegments
	for i, seg in ipairs(self._armourSegments) do
		local inSegment = math.clamp(current - per * (i - 1), 0, per)
		seg:SetFraction(per > 0 and inSegment / per or 0)
	end
end

function Hud:_cashPopup(delta: number)
	local label = Components.Label(self._cashPopups, {
		text = "+$" .. comma(delta),
		font = Theme.Font.Display,
		size = 24,
		colour = Theme.Colour.Currency,
		align = Enum.TextXAlignment.Center,
		outline = false,
	})
	Components.Outline(label, 2.2, Theme.Colour.CurrencyEdge, 0)
	label.Size = UDim2.new(1, 0, 0, 28)
	label.Position = UDim2.fromOffset(math.random(-30, 30), 0)
	pop(label, 1.5)
	TweenService:Create(label, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = label.Position + UDim2.fromOffset(0, 46),
	}):Play()
	task.delay(0.7, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			local edge = label:FindFirstChildOfClass("UIStroke")
			if edge then
				TweenService:Create(edge, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end
	end)
	task.delay(1.2, function()
		label:Destroy()
	end)
end

function Hud:SetCurrency(amount: number)
	local previous = self._cashValue
	self._cashValue = amount
	if previous == nil then
		self._cash.Text = comma(amount)
		return
	end
	if amount > previous then
		self:_cashPopup(amount - previous)
		pop(self._cashPill, 1.12)
	end
	-- Count to the new figure rather than jumping to it.
	self._cashToken = (self._cashToken or 0) + 1
	local token = self._cashToken
	local counter = Instance.new("NumberValue")
	counter.Value = previous
	counter.Changed:Connect(function(v)
		if token == self._cashToken then
			self._cash.Text = comma(v)
		end
	end)
	local tween = TweenService:Create(counter, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Value = amount })
	tween.Completed:Once(function()
		if token == self._cashToken then
			self._cash.Text = comma(amount)
		end
		counter:Destroy()
	end)
	tween:Play()
end

function Hud:SetLevel(level: number, exp: number?, maxExp: number?)
	local whole = math.floor(level)
	local previous = self._levelValue
	self._levelValue = whole
	self._level.Text = tostring(whole)
	if exp and maxExp then
		-- At the cap the bar is full, not empty: there is nothing left to fill, only prestige.
		local okConfig, GameConfig = pcall(function()
			return require(game:GetService("ReplicatedStorage"):WaitForChild("GameConfig", 2) :: ModuleScript) :: any
		end)
		local cap = okConfig and GameConfig and GameConfig.Leveling.MAX_LEVEL or math.huge
		self._xp:SetFraction(whole >= cap and 1 or (maxExp > 0 and exp / maxExp or 0))
	end
	if previous and whole > previous then
		pop(self._badge, 1.6)
	end
end

--- "+15 XP" pops out beside the level diamond whenever experience lands.
function Hud:XpPopup(amount: number)
	if amount <= 0 or not self._identity.Visible then
		return
	end
	local label = Components.Label(self._cashPopups, {
		text = string.format("+%d XP", math.floor(amount)),
		font = Theme.Font.Display,
		size = 20,
		colour = Theme.Colour.Xp,
		align = Enum.TextXAlignment.Center,
		outline = false,
	})
	Components.Outline(label, 2.2, Color3.fromRGB(50, 10, 70), 0)
	label.Size = UDim2.new(1, 0, 0, 24)
	label.Position = UDim2.fromOffset(150 + math.random(-10, 10), -34)
	pop(label, 1.6)
	TweenService:Create(label, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = label.Position + UDim2.fromOffset(0, 40),
	}):Play()
	task.delay(0.8, function()
		if label.Parent then
			TweenService:Create(label, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			local edge = label:FindFirstChildOfClass("UIStroke")
			if edge then
				TweenService:Create(edge, TweenInfo.new(0.4), { Transparency = 1 }):Play()
			end
		end
	end)
	task.delay(1.3, function()
		label:Destroy()
	end)
end

--- During a duel the scoreboard takes the top of the screen, as in the references, and the
--- cash and level step aside for it.
function Hud:SetIdentityVisible(visible: boolean)
	self._identity.Visible = visible
	self._xpHolder.Visible = visible
end

--- Hidden wholesale while a menu is open, so the HUD never shows through a panel.
function Hud:SetVisible(visible: boolean)
	self._root.Visible = visible
end

function Hud:Destroy()
	self._root:Destroy()
end

return Hud
