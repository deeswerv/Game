--!strict
-- HUD: what stays on screen while the player is actually playing.
--
-- This module draws and nothing else. It exposes setters -- SetAmmo, SetHealth, SetWeapon --
-- and knows nothing about tools, remotes or the character. Whatever binds it to the game
-- lives in the MainUI controller, so the interface can be redesigned without touching
-- gameplay and gameplay can change without breaking the interface. The old UI mixed the two,
-- which is why deleting a frame used to be able to break reloading.
--
-- Layout follows the references: information pinned to the corners, the middle of the screen
-- left completely clear, and the weapon block sized to be readable while aiming without
-- covering anything. Nothing animates on a loop -- values tween when they change, then stop.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local Hud = {}
Hud.__index = Hud

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

-- ------------------------------------------------------------------ build --

local function buildIdentity(parent: GuiObject)
	-- Top centre, as in the references: one pill carrying the number that matters, with the
	-- level badge riding beside it rather than claiming its own corner.
	local holder = Instance.new("Frame")
	holder.Name = "Identity"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0)
	holder.Position = UDim2.new(0.5, 0, 0, Theme.Inset.Top)
	holder.Size = UDim2.fromOffset(0, 34)
	holder.AutomaticSize = Enum.AutomaticSize.X
	holder.Parent = parent
	Components.List(holder, Enum.FillDirection.Horizontal, Theme.Space.S, Enum.HorizontalAlignment.Center)

	local pill = Instance.new("Frame")
	pill.Name = "Cash"
	pill.BackgroundColor3 = Theme.Colour.Panel
	pill.BackgroundTransparency = 0.1
	pill.BorderSizePixel = 0
	pill.AutomaticSize = Enum.AutomaticSize.X
	pill.Size = UDim2.fromOffset(0, 34)
	pill.LayoutOrder = 1
	pill.Parent = holder
	Components.Corner(pill, Theme.Radius.Pill)
	Components.Stroke(pill)
	Components.Padding(pill, nil, Theme.Space.M, 0)

	local amount = Components.Label(pill, {
		text = "0",
		font = Theme.Font.Display,
		size = Theme.Text.Large,
		colour = Theme.Colour.Currency,
		autoSize = true,
	})
	amount.AnchorPoint = Vector2.new(0, 0.5)
	amount.Position = UDim2.fromScale(0, 0.5)

	local badge = Instance.new("Frame")
	badge.Name = "Level"
	badge.BackgroundColor3 = Theme.Colour.Warning
	badge.BorderSizePixel = 0
	badge.Size = UDim2.fromOffset(34, 34)
	badge.LayoutOrder = 2
	badge.Parent = holder
	Components.Corner(badge, Theme.Radius.Pill)

	local level = Components.Label(badge, {
		text = "1",
		font = Theme.Font.Display,
		size = Theme.Text.Body,
		colour = Theme.Colour.AccentText,
		align = Enum.TextXAlignment.Center,
	})
	level.Size = UDim2.fromScale(1, 1)

	-- XP is a hairline under the pair. It is progress, not a headline, so it gets 3 pixels.
	local xpHolder = Instance.new("Frame")
	xpHolder.Name = "XP"
	xpHolder.BackgroundTransparency = 1
	xpHolder.AnchorPoint = Vector2.new(0.5, 0)
	xpHolder.Position = UDim2.new(0.5, 0, 0, Theme.Inset.Top + 38)
	xpHolder.Size = UDim2.fromOffset(150, 3)
	xpHolder.Parent = parent
	local xp = Components.Bar(xpHolder, { height = 3, colour = Theme.Colour.Warning })

	return amount, level, xp
end

local function buildHealth(parent: GuiObject)
	-- Bottom left. A number, a meter, and an armour meter that only exists when the player
	-- actually has armour.
	local holder = Instance.new("Frame")
	holder.Name = "Health"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0, 1)
	holder.Position = UDim2.new(0, Theme.Inset.Side, 1, -Theme.Inset.Bottom)
	holder.Size = UDim2.fromOffset(224, 58)
	holder.Parent = parent

	local value = Components.Label(holder, {
		text = "100",
		font = Theme.Font.Display,
		size = Theme.Text.Huge,
	})
	value.Size = UDim2.fromOffset(96, 38)
	value.Position = UDim2.fromOffset(0, 0)

	local unit = Components.Label(holder, { text = "HP", caps = true, size = Theme.Text.Micro })
	unit.Size = UDim2.fromOffset(30, 14)
	unit.Position = UDim2.fromOffset(3, 38)

	local barHolder = Instance.new("Frame")
	barHolder.BackgroundTransparency = 1
	barHolder.Size = UDim2.fromOffset(180, 6)
	barHolder.Position = UDim2.fromOffset(40, 42)
	barHolder.Parent = holder
	local health = Components.Bar(barHolder, { height = 6, colour = Theme.Colour.Accent })

	local armourHolder = Instance.new("Frame")
	armourHolder.Name = "ArmourHolder"
	armourHolder.BackgroundTransparency = 1
	armourHolder.Size = UDim2.fromOffset(180, 4)
	armourHolder.Position = UDim2.fromOffset(40, 52)
	armourHolder.Visible = false
	armourHolder.Parent = holder
	local armour = Components.Bar(armourHolder, { height = 4, colour = Theme.Colour.Info })

	return value, health, armour, armourHolder
end

local function buildWeapon(parent: GuiObject)
	-- Bottom right. The ammo count is the largest thing on the HUD on purpose -- it is the one
	-- number read mid-fight -- and everything around it stays small.
	local holder = Instance.new("Frame")
	holder.Name = "Weapon"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 1)
	holder.Position = UDim2.new(1, -Theme.Inset.Side, 1, -Theme.Inset.Bottom)
	holder.Size = UDim2.fromOffset(270, 96)
	holder.Parent = parent

	local name = Components.Label(holder, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Large,
		align = Enum.TextXAlignment.Right,
	})
	name.Size = UDim2.new(1, 0, 0, 20)
	name.Position = UDim2.fromOffset(0, 8)

	local rarity = Components.Label(holder, {
		text = "",
		caps = true,
		size = Theme.Text.Micro,
		align = Enum.TextXAlignment.Right,
	})
	rarity.Size = UDim2.new(1, 0, 0, 14)
	rarity.Position = UDim2.fromOffset(0, 28)

	local current = Components.Label(holder, {
		text = "0",
		font = Theme.Font.Display,
		size = Theme.Text.Hero,
		align = Enum.TextXAlignment.Right,
	})
	current.Size = UDim2.new(1, -62, 0, 48)
	current.Position = UDim2.fromOffset(0, 46)

	local reserve = Components.Label(holder, {
		text = "/ 0",
		font = Theme.Font.Bold,
		size = Theme.Text.Large,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Right,
	})
	reserve.Size = UDim2.fromOffset(58, 24)
	reserve.Position = UDim2.new(1, -58, 0, 66)

	local mode = Components.Chip(holder, "AUTO", Theme.Colour.TextDim)
	mode.AnchorPoint = Vector2.new(1, 0)
	mode.Position = UDim2.new(1, 0, 0, 44)
	mode.Visible = false

	local reloading = Components.Label(holder, {
		text = "RELOADING",
		caps = true,
		size = Theme.Text.Small,
		colour = Theme.Colour.Warning,
		align = Enum.TextXAlignment.Right,
	})
	reloading.Size = UDim2.new(1, 0, 0, 16)
	reloading.Position = UDim2.fromOffset(0, 96)
	reloading.Visible = false

	return holder, name, rarity, current, reserve, mode, reloading
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

	self._cash, self._level, self._xp = buildIdentity(root)
	self._health, self._healthBar, self._armourBar, self._armourHolder = buildHealth(root)
	self._weapon, self._weaponName, self._weaponRarity, self._ammo, self._reserve,
		self._mode, self._reloading = buildWeapon(root)

	self._maxHealth = 100
	self._weapon.Visible = false
	return self
end

--- Shown only while a weapon is actually equipped, so an unarmed player gets a clean screen.
function Hud:SetWeapon(name: string?, rarity: string?, fireMode: string?)
	local has = name ~= nil and name ~= ""
	self._weapon.Visible = has
	if not has then
		return
	end
	self._weaponName.Text = name
	self._weaponRarity.Text = string.upper(rarity or "")
	self._weaponRarity.TextColor3 = Theme.RarityColour(rarity)

	if fireMode and fireMode ~= "" then
		self._mode.Visible = true
		local label = self._mode:FindFirstChild("Text")
		if label and label:IsA("TextLabel") then
			label.Text = string.upper(fireMode)
		end
	else
		self._mode.Visible = false
	end
end

--- `capacity` is the magazine size. This game has no separate reserve pool, so the second
--- number is what a full magazine holds rather than rounds in a backpack.
function Hud:SetAmmo(current: number, capacity: number)
	local rounds = math.max(0, math.floor(current))
	self._ammo.Text = tostring(rounds)
	self._reserve.Text = "/ " .. tostring(math.max(0, math.floor(capacity)))

	-- Empty goes red, a quarter-magazine goes amber. Colour rather than a flash: something
	-- blinking on every shot at low ammo is the kind of motion that makes a HUD tiring.
	local fraction = capacity > 0 and rounds / capacity or 0
	local colour = rounds <= 0 and Theme.Colour.Danger
		or fraction <= 0.25 and Theme.Colour.Warning
		or Theme.Colour.Text
	self._ammo.TextColor3 = colour
end

function Hud:SetReloading(reloading: boolean)
	self._reloading.Visible = reloading
end

function Hud:SetHealth(current: number, maximum: number?)
	local max = maximum or self._maxHealth
	self._maxHealth = max
	local clamped = math.clamp(current, 0, max)
	self._health.Text = tostring(math.floor(clamped + 0.5))

	local fraction = max > 0 and clamped / max or 0
	self._healthBar:SetFraction(fraction)
	local colour = fraction <= 0.25 and Theme.Colour.Danger
		or fraction <= 0.5 and Theme.Colour.Warning
		or Theme.Colour.Accent
	self._healthBar:SetColour(colour)
	TweenService:Create(self._health, Theme.Tween.Value, { TextColor3 = colour }):Play()
end

--- Pass 0 (or never call it) and the armour meter stays hidden entirely.
function Hud:SetArmour(current: number, maximum: number)
	local visible = maximum > 0 and current > 0
	self._armourHolder.Visible = visible
	if visible then
		self._armourBar:SetFraction(current / maximum)
	end
end

function Hud:SetCurrency(amount: number)
	self._cash.Text = comma(amount)
end

function Hud:SetLevel(level: number, exp: number?, maxExp: number?)
	self._level.Text = tostring(math.floor(level))
	if exp and maxExp then
		self._xp:SetFraction(maxExp > 0 and exp / maxExp or 0)
	end
end

--- Hidden wholesale while a menu is open, so the HUD never shows through a panel.
function Hud:SetVisible(visible: boolean)
	self._root.Visible = visible
end

function Hud:Destroy()
	self._root:Destroy()
end

return Hud
