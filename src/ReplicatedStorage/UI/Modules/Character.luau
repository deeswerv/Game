--!strict
-- The Character panel: who you are and what your levels have bought you.
--
-- Left, the character card -- your full-body avatar, level diamond, XP bar and prestige.
-- Right, the stat points you have to spend in a big gold pill, and a card per stat: what one
-- point does, how far along the stat is (0 - 50), the total it gives you now, and +1 / +5.
-- Refunding everything is one button and costs nothing, so trying a different build is free.
--
-- The server owns every number (CharacterService). A click asks; the panel redraws from the
-- answer. The effects shown come from CharacterConfig, the same table the server applies.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menu = require(script.Parent.Menu)
local UISound = require(script.Parent.UISound)
local CharacterConfig = require(ReplicatedStorage:WaitForChild("CharacterConfig"))

local Character = {}
Character.__index = Character

local WHITE = Color3.new(1, 1, 1)
local GOLD_TOP = Color3.fromRGB(255, 244, 150)
local GOLD_BOTTOM = Color3.fromRGB(255, 166, 20)
local CARD_HEIGHT = 112

local function pop(object: any, from: number)
	local s = object:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Parent = object
	end
	local scale = s :: UIScale
	scale.Scale = from
	TweenService:Create(scale, Theme.Tween.Pop, { Scale = 1 }):Play()
end

-- ----------------------------------------------------------------- card --

local function buildIdentity(self, parent: GuiObject)
	local card = Components.Panel(parent, {
		name = "Identity",
		size = UDim2.new(0, 290, 1, 0),
		colour = Theme.Colour.PanelRaised,
		radius = Theme.Radius.Card,
	})

	-- The avatar stands on a lit floor, the way the reference character screens frame it.
	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BackgroundColor3 = Color3.fromRGB(56, 64, 92)
	stage.Position = UDim2.fromOffset(10, 10)
	stage.Size = UDim2.new(1, -20, 0, 250)
	stage.Parent = card
	Components.Corner(stage, Theme.Radius.Small)
	Components.Stroke(stage, Theme.Colour.Outline, 2)
	local light = Components.Gradient(stage, Color3.fromRGB(150, 170, 255), Color3.fromRGB(40, 36, 60))
	light.Rotation = 90

	local floor = Instance.new("Frame")
	floor.Name = "Floor"
	floor.BackgroundColor3 = WHITE
	floor.BackgroundTransparency = 0.8
	floor.AnchorPoint = Vector2.new(0.5, 1)
	floor.Position = UDim2.new(0.5, 0, 1, -10)
	floor.Size = UDim2.new(0.8, 0, 0, 22)
	floor.Parent = stage
	Components.Corner(floor, 11)

	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundTransparency = 1
	avatar.AnchorPoint = Vector2.new(0.5, 1)
	avatar.Position = UDim2.new(0.5, 0, 1, -4)
	avatar.Size = UDim2.fromOffset(240, 240)
	avatar.ScaleType = Enum.ScaleType.Fit
	avatar.Image = string.format("rbxthumb://type=Avatar&id=%d&w=420&h=420", math.max(Players.LocalPlayer.UserId, 1))
	avatar.Parent = stage

	local badge, levelText = Components.LevelBadge(card, 54)
	badge.Position = UDim2.fromOffset(12, 268)
	self._levelText = levelText

	local name = Components.Label(card, {
		text = Players.LocalPlayer.DisplayName,
		face = Theme.Face.Heavy,
		size = 26,
		outline = 2.5,
	})
	name.Position = UDim2.fromOffset(72, 270)
	name.Size = UDim2.new(1, -82, 0, 28)
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local prestige = Components.Label(card, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		colour = Theme.Colour.Level,
	})
	prestige.Position = UDim2.fromOffset(72, 298)
	prestige.Size = UDim2.new(1, -82, 0, 18)
	self._prestige = prestige

	local xpHolder = Instance.new("Frame")
	xpHolder.BackgroundTransparency = 1
	xpHolder.Position = UDim2.fromOffset(12, 330)
	xpHolder.Size = UDim2.new(1, -24, 0, 16)
	xpHolder.Parent = card
	local xpBar = Components.Bar(xpHolder, { height = 16, colour = Theme.Colour.Xp })
	self._xpBar = xpBar
	local xpText = Components.Label(card, {
		text = "",
		font = Theme.Font.Display,
		size = 16,
		align = Enum.TextXAlignment.Center,
		outline = 2,
	})
	xpText.Position = UDim2.fromOffset(12, 350)
	xpText.Size = UDim2.new(1, -24, 0, 20)
	self._xpText = xpText

	-- Fair play: say plainly that none of this follows you into a duel.
	local fair = Instance.new("Frame")
	fair.Name = "FairPlay"
	fair.BackgroundColor3 = Theme.Colour.Sunken
	fair.AnchorPoint = Vector2.new(0.5, 1)
	fair.Position = UDim2.new(0.5, 0, 1, -10)
	fair.Size = UDim2.new(1, -20, 0, 44)
	fair.Parent = card
	Components.Corner(fair, Theme.Radius.Small)
	Components.Stroke(fair, Theme.Colour.Outline, 1.5)
	local fairText = Components.Label(fair, {
		text = "⚖️  Duels are fair: stats switch off in the arena",
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
		wrap = true,
	})
	fairText.Size = UDim2.new(1, -12, 1, 0)
	fairText.Position = UDim2.fromOffset(6, 0)
end

-- ------------------------------------------------------------ stat card --

local function statCard(self, parent: GuiObject, stat: CharacterConfig.Stat, order: number)
	local card = Instance.new("Frame")
	card.Name = stat.id
	card.BackgroundColor3 = Theme.Colour.PanelRaised
	card.Size = UDim2.new(1, 0, 0, CARD_HEIGHT)
	card.LayoutOrder = order
	card.Parent = parent
	Components.Corner(card, Theme.Radius.Card)
	Components.Stroke(card, Theme.Colour.Outline, 2)
	Components.Gradient(card, WHITE, Color3.fromRGB(170, 170, 180))

	-- The stat's colour as a block down the left, with its icon.
	local block = Instance.new("Frame")
	block.Name = "Block"
	block.BackgroundColor3 = stat.colour
	block.Size = UDim2.new(0, 84, 1, 0)
	block.Parent = card
	Components.Corner(block, Theme.Radius.Card)
	Components.Gradient(block, WHITE, Color3.fromRGB(150, 150, 150)).Rotation = 90
	local icon = Components.Icon(block, stat.icon, 40)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)

	local title = Components.Label(card, {
		text = stat.label,
		face = Theme.Face.HeavyItalic,
		size = 28,
		colour = stat.colour:Lerp(WHITE, 0.35),
		outline = 2.5,
	})
	title.Position = UDim2.fromOffset(98, 8)
	title.Size = UDim2.fromOffset(260, 30)

	local effect = Components.Label(card, {
		text = stat.effect .. " per point",
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
	})
	effect.Position = UDim2.fromOffset(98, 38)
	effect.Size = UDim2.fromOffset(300, 18)

	-- 0 - 50 as a bar with the count printed on it.
	local barHolder = Instance.new("Frame")
	barHolder.BackgroundTransparency = 1
	barHolder.Position = UDim2.fromOffset(98, 64)
	barHolder.Size = UDim2.fromOffset(300, 18)
	barHolder.Parent = card
	local bar = Components.Bar(barHolder, { height = 18, colour = stat.colour })
	local count = Components.Label(barHolder, {
		text = "0 / 50",
		font = Theme.Font.Display,
		size = 15,
		align = Enum.TextXAlignment.Center,
		outline = 2,
	})
	count.Size = UDim2.fromScale(1, 1)
	count.ZIndex = 3

	local total = Components.Label(card, {
		text = "",
		font = Theme.Font.Display,
		size = 24,
		colour = stat.colour:Lerp(WHITE, 0.2),
		align = Enum.TextXAlignment.Right,
		outline = 2.5,
	})
	total.AnchorPoint = Vector2.new(1, 0)
	total.Position = UDim2.new(1, -150, 0, 12)
	total.Size = UDim2.fromOffset(170, 28)

	local plusOne = Components.Button(card, {
		name = "AddOne",
		text = "+1",
		primary = true,
		textSize = 24,
		size = UDim2.fromOffset(62, 44),
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -78, 1, -14),
		onActivated = function()
			self:Spend(stat.id, 1)
		end,
	})
	local plusFive = Components.Button(card, {
		name = "AddFive",
		text = "+5",
		primary = true,
		textSize = 24,
		size = UDim2.fromOffset(62, 44),
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -12, 1, -14),
		onActivated = function()
			self:Spend(stat.id, 5)
		end,
	})

	self._cards[stat.id] = { bar = bar, count = count, total = total, plusOne = plusOne, plusFive = plusFive, card = card }
end

-- ------------------------------------------------------------------ api --

function Character.new(parent: Instance, remotes)
	local self = setmetatable({}, Character)
	self._remotes = remotes
	self._cards = {}
	self._state = nil
	self._confirmReset = false

	local menu = Menu.new(parent, {
		id = "Character",
		title = "Character",
		subtitle = "Every level earns stat points -- spend them here",
		icon = "💪",
		size = UDim2.fromOffset(1000, 560),
	})
	self._menu = menu

	buildIdentity(self, menu.content)

	local right = Instance.new("Frame")
	right.Name = "Stats"
	right.BackgroundTransparency = 1
	right.Position = UDim2.fromOffset(306, 0)
	right.Size = UDim2.new(1, -306, 1, 0)
	right.Parent = menu.content

	-- The points to spend, as a big gold pill -- the one number this panel is about.
	local pill = Instance.new("Frame")
	pill.Name = "Points"
	pill.BackgroundColor3 = Theme.Colour.Level
	pill.Size = UDim2.fromOffset(250, 56)
	pill.Parent = right
	Components.Corner(pill, 28)
	Components.Stroke(pill, Theme.Colour.LevelEdge, 3)
	Components.Gradient(pill, GOLD_TOP, GOLD_BOTTOM).Rotation = 90
	local pointsCaption = Components.Label(pill, {
		text = "STAT POINTS",
		face = Theme.Face.Condensed,
		size = 22,
		outline = 2.5,
	})
	pointsCaption.Position = UDim2.fromOffset(20, 0)
	pointsCaption.Size = UDim2.new(1, -90, 1, 0)
	local points = Components.Label(pill, {
		text = "0",
		font = Theme.Font.Display,
		size = 36,
		align = Enum.TextXAlignment.Right,
		outline = 3,
	})
	points.AnchorPoint = Vector2.new(1, 0)
	points.Position = UDim2.new(1, -20, 0, 0)
	points.Size = UDim2.fromOffset(70, 56)
	self._points, self._pill = points, pill

	local perLevel = Components.Label(right, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
	})
	perLevel.Position = UDim2.fromOffset(264, 8)
	perLevel.Size = UDim2.fromOffset(250, 18)
	self._perLevel = perLevel
	local message = Components.Label(right, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		colour = Theme.Colour.TextMuted,
	})
	message.Position = UDim2.fromOffset(264, 30)
	message.Size = UDim2.fromOffset(260, 18)
	self._message = message

	self._reset = Components.Button(right, {
		name = "Reset",
		text = "RESET POINTS",
		danger = true,
		textSize = 18,
		size = UDim2.fromOffset(170, 40),
		anchor = Vector2.new(1, 0),
		position = UDim2.new(1, 0, 0, 8),
		onActivated = function()
			self:Reset()
		end,
	})

	local list = Instance.new("Frame")
	list.Name = "Cards"
	list.BackgroundTransparency = 1
	list.Position = UDim2.fromOffset(0, 70)
	list.Size = UDim2.new(1, 0, 1, -70)
	list.Parent = right
	Components.List(list, Enum.FillDirection.Vertical, 10)
	for i, stat in ipairs(CharacterConfig.Stats) do
		statCard(self, list, stat, i)
	end

	menu:OnOpen(function()
		self._confirmReset = false
		self._reset:SetText("RESET POINTS")
		self:Refresh()
	end)

	return self
end

function Character:_render(state)
	if type(state) ~= "table" then
		return
	end
	local previous = self._state
	self._state = state
	local points = tonumber(state.points) or 0
	local max = tonumber(state.max) or CharacterConfig.MAX_PER_STAT

	self._points.Text = tostring(points)
	if previous and previous.points ~= points then
		pop(self._points, 1.4)
	end
	self._perLevel.Text = string.format("+%d every level", tonumber(state.perLevel) or 3)
	self._levelText.Text = tostring(tonumber(state.level) or 1)
	local prestige = tonumber(state.prestige) or 0
	self._prestige.Text = prestige > 0 and (string.rep("★", math.min(prestige, 5)) .. string.format("  Prestige %d", prestige))
		or "Level " .. tostring(tonumber(state.level) or 1)
	local exp, maxExp = tonumber(state.exp) or 0, math.max(tonumber(state.maxExp) or 1, 1)
	self._xpBar:SetFraction(exp / maxExp)
	self._xpText.Text = string.format("%d / %d XP", math.floor(exp), math.floor(maxExp))

	for _, stat in ipairs(CharacterConfig.Stats) do
		local card = self._cards[stat.id]
		local value = tonumber(state.stats and state.stats[stat.id]) or 0
		card.bar:SetFraction(value / max)
		card.count.Text = string.format("%d / %d", value, max)
		card.total.Text = value > 0 and stat.total(value) or "--"
		local room = max - value
		card.plusOne:SetEnabled(points >= 1 and room >= 1)
		card.plusFive:SetEnabled(points >= 1 and room >= 1)
		card.plusFive:SetText(string.format("+%d", math.max(1, math.min(5, points, room))))
		if previous and previous.stats and (tonumber(previous.stats[stat.id]) or 0) < value then
			pop(card.total, 1.5)
		end
	end
	if state.inDuel then
		self._message.Text = "In a duel: your stats are switched off"
	end
end

function Character:Refresh()
	task.spawn(function()
		local ok, state = pcall(function()
			return self._remotes.statAction:InvokeServer("state")
		end)
		if ok then
			self:_render(state)
		end
	end)
end

function Character:Spend(id: string, count: number)
	local state = self._state
	if state and (tonumber(state.points) or 0) <= 0 then
		self._message.Text = "No stat points left -- level up to earn more"
		UISound.Play("Clunk", 0.8, 0.5)
		return
	end
	task.spawn(function()
		local ok, result = pcall(function()
			return self._remotes.statAction:InvokeServer("add", id, count)
		end)
		if not ok or type(result) ~= "table" then
			return
		end
		if result.ok then
			self._message.Text = ""
			UISound.Sequence("Ring", { 1.2, 1.45 }, 0.06, 0.7)
		else
			self._message.Text = tostring(result.reason or "")
			UISound.Play("Clunk", 0.8, 0.5)
		end
		if result.state then
			self:_render(result.state)
		end
	end)
end

--- Two presses: the first asks, the second refunds.
function Character:Reset()
	if not self._confirmReset then
		self._confirmReset = true
		self._reset:SetText("PRESS TO CONFIRM")
		task.delay(3, function()
			if self._confirmReset then
				self._confirmReset = false
				self._reset:SetText("RESET POINTS")
			end
		end)
		return
	end
	self._confirmReset = false
	self._reset:SetText("RESET POINTS")
	task.spawn(function()
		local ok, result = pcall(function()
			return self._remotes.statAction:InvokeServer("reset")
		end)
		if ok and type(result) == "table" then
			self._message.Text = result.ok and string.format("%d points refunded", tonumber(result.refunded) or 0)
				or tostring(result.reason or "")
			if result.state then
				self:_render(result.state)
			end
		end
	end)
end

function Character:Open()
	self._menu:Open()
end
function Character:Close()
	self._menu:Close()
end
function Character:Toggle()
	self._menu:Toggle()
end
function Character:IsOpen(): boolean
	return self._menu:IsOpen()
end

return Character
