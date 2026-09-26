--!strict
-- The objective tracker: what you are currently meant to be doing.
--
-- Modelled on the reference quest card -- a clipboard, the quest's name small and orange,
-- the objective itself big and white in the condensed face, then a progress bar with the
-- count inside it and the rewards beside it. No box: a dark wash that fades out to the right
-- carries it over the world, as in the reference.
--
-- Draws only. The controller feeds it the state QuestService already broadcasts; this module
-- has no opinion about quests and never talks to the server.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local Objective = {}
Objective.__index = Objective

local WIDTH = 360
local ORANGE = Color3.fromRGB(255, 164, 28)

function Objective.new(parent: GuiObject)
	local self = setmetatable({}, Objective)

	local card = Instance.new("Frame")
	card.Name = "Objective"
	card.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	card.BackgroundTransparency = 0.25
	card.BorderSizePixel = 0
	card.AnchorPoint = Vector2.new(0, 0.5)
	card.Position = UDim2.new(0, 0, 0.44, 0)
	card.Size = UDim2.fromOffset(WIDTH, 112)
	card.Visible = false
	card.Parent = parent
	-- Solid at the screen edge, gone by the right-hand side.
	local wash = Instance.new("UIGradient")
	wash.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.6, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	wash.Parent = card
	self._card = card

	local scale = Instance.new("UIScale")
	scale.Parent = card
	self._scale = scale

	local clipboard = Components.Icon(card, "📋", 38)
	clipboard.Position = UDim2.fromOffset(Theme.Inset.Side - 4, 10)
	clipboard.Rotation = -12

	self._title = Components.Label(card, {
		text = "",
		face = Theme.Face.Condensed,
		size = 20,
		colour = ORANGE,
	})
	self._title.Size = UDim2.new(1, -80, 0, 22)
	self._title.Position = UDim2.fromOffset(70, 8)

	-- The line the player actually reads, so it gets the weight.
	self._label = Components.Label(card, {
		text = "",
		face = Theme.Face.Condensed,
		size = 28,
		wrap = true,
		outline = 2.4,
	})
	self._label.Size = UDim2.new(1, -86, 0, 34)
	self._label.Position = UDim2.fromOffset(70, 30)
	self._label.TextScaled = false
	self._label.TextTruncate = Enum.TextTruncate.AtEnd

	local barHolder = Instance.new("Frame")
	barHolder.BackgroundTransparency = 1
	barHolder.Size = UDim2.fromOffset(150, 18)
	barHolder.Position = UDim2.fromOffset(Theme.Inset.Side, 80)
	barHolder.Parent = card
	self._bar = Components.Bar(barHolder, { height = 18, colour = ORANGE, radius = 6 })

	self._count = Components.Label(barHolder, {
		text = "",
		font = Theme.Font.Display,
		size = 15,
		align = Enum.TextXAlignment.Center,
	})
	self._count.Size = UDim2.fromScale(1, 1)
	self._count.ZIndex = 3

	-- Reward chips, laid out left to right after the bar.
	self._rewards = Instance.new("Frame")
	self._rewards.Name = "Rewards"
	self._rewards.BackgroundTransparency = 1
	self._rewards.Position = UDim2.fromOffset(Theme.Inset.Side + 162, 77)
	self._rewards.Size = UDim2.fromOffset(0, 24)
	self._rewards.AutomaticSize = Enum.AutomaticSize.X
	self._rewards.Parent = card
	local row = Components.List(self._rewards, Enum.FillDirection.Horizontal, 6)
	row.VerticalAlignment = Enum.VerticalAlignment.Center

	self._chips = {}
	return self
end

local function clearChips(self)
	for _, chip in ipairs(self._chips) do
		chip:Destroy()
	end
	table.clear(self._chips)
end

--- `active` is the block QuestService sends: { id, title, label, progress, goal }.
--- `rewards` is optional: { coins = n, xp = n }.
function Objective:Set(active, rewards)
	if not active then
		self._card.Visible = false
		self._id = nil
		return
	end

	local fresh = self._id ~= active.id
	self._id = active.id

	self._card.Visible = self._hidden ~= true
	self._title.Text = tostring(active.title or "Objective")
	self._label.Text = tostring(active.label or "")

	local goal = tonumber(active.goal) or 0
	local progress = math.clamp(tonumber(active.progress) or 0, 0, math.max(goal, 0))
	self._count.Text = goal > 0 and string.format("%d/%d", progress, goal) or ""
	-- Snap on a new quest, animate on progress.
	self._bar:SetFraction(goal > 0 and progress / goal or 0, not fresh)

	-- Complete turns the bar green; the card is otherwise orange throughout.
	local done = goal > 0 and progress >= goal
	self._bar:SetColour(done and Theme.Colour.Accent or ORANGE)
	TweenService:Create(self._title, Theme.Tween.Value, { TextColor3 = done and Theme.Colour.Accent or ORANGE }):Play()

	-- A new quest slides in; progress on the current one gives the card a nudge.
	if fresh then
		self._card.Position = UDim2.new(0, -WIDTH, 0.44, 0)
		TweenService:Create(self._card, Theme.Tween.Open, { Position = UDim2.new(0, 0, 0.44, 0) }):Play()
	else
		self._scale.Scale = 1.06
		TweenService:Create(self._scale, Theme.Tween.Pop, { Scale = 1 }):Play()
	end

	if fresh or self._lastRewards ~= rewards then
		self._lastRewards = rewards
		clearChips(self)
		if rewards then
			if tonumber(rewards.xp) then
				table.insert(self._chips, Components.Chip(self._rewards,
					"XP +" .. tostring(GameConfig.ShownXP(rewards.xp)), Theme.Colour.Xp, { layoutOrder = 1 }))
			end
			if tonumber(rewards.coins) then
				table.insert(self._chips, Components.Chip(self._rewards,
					"$" .. tostring(rewards.coins), Theme.Colour.AccentDim, { layoutOrder = 2 }))
			end
		end
	end
end

function Objective:SetVisible(visible: boolean)
	-- Only ever shows when there is something to show; SetVisible cannot resurrect an empty
	-- card, it only hides a populated one while a menu is open.
	self._hidden = not visible
	self._card.Visible = visible and self._id ~= nil
end

function Objective:Destroy()
	clearChips(self)
	self._card:Destroy()
end

return Objective
