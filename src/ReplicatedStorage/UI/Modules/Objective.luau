--!strict
-- The objective card: what you are currently meant to be doing.
--
-- Modelled on the reference shots -- a small quest name, the objective itself as the line you
-- actually read, a progress bar, and the rewards as chips beside it. Pinned to the left edge
-- and vertically centred so it sits clear of the kill feed above and the health block below.
--
-- Draws only. The controller feeds it the state QuestService already broadcasts; this module
-- has no opinion about quests and never talks to the server.
--
-- Rewards are looked up from QuestConfig on the client rather than added to the remote
-- payload. The active-quest block QuestService sends carries no coins or xp -- only the offer
-- block does -- and QuestConfig is in ReplicatedStorage anyway, so reading it here costs no
-- extra traffic and no server change.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local Objective = {}
Objective.__index = Objective

local WIDTH = 268

function Objective.new(parent: GuiObject)
	local self = setmetatable({}, Objective)

	local card = Instance.new("Frame")
	card.Name = "Objective"
	card.BackgroundColor3 = Theme.Colour.Panel
	card.BackgroundTransparency = 0.12
	card.BorderSizePixel = 0
	card.AnchorPoint = Vector2.new(0, 0.5)
	card.Position = UDim2.new(0, Theme.Inset.Side, 0.5, 0)
	card.Size = UDim2.fromOffset(WIDTH, 92)
	card.Visible = false
	card.Parent = parent
	Components.Corner(card, Theme.Radius.Card)
	Components.Stroke(card)
	self._card = card

	-- A coloured spine rather than an icon: it reads as "this is a tracked thing" at a glance
	-- and costs no asset.
	local spine = Instance.new("Frame")
	spine.Name = "Spine"
	spine.BackgroundColor3 = Theme.Colour.Warning
	spine.BorderSizePixel = 0
	spine.Size = UDim2.new(0, 3, 1, -16)
	spine.Position = UDim2.fromOffset(0, 8)
	spine.Parent = card

	self._title = Components.Label(card, {
		text = "",
		caps = true,
		size = Theme.Text.Micro,
		colour = Theme.Colour.Warning,
	})
	self._title.Size = UDim2.new(1, -24, 0, 14)
	self._title.Position = UDim2.fromOffset(14, 10)

	-- The line the player actually reads, so it gets the weight.
	self._label = Components.Label(card, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Large,
		wrap = true,
	})
	self._label.Size = UDim2.new(1, -24, 0, 40)
	self._label.Position = UDim2.fromOffset(14, 24)
	self._label.TextYAlignment = Enum.TextYAlignment.Top

	local barHolder = Instance.new("Frame")
	barHolder.BackgroundTransparency = 1
	barHolder.Size = UDim2.new(1, -80, 0, 5)
	barHolder.Position = UDim2.new(0, 14, 1, -22)
	barHolder.Parent = card
	self._bar = Components.Bar(barHolder, { height = 5, colour = Theme.Colour.Warning })

	self._count = Components.Label(card, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		align = Enum.TextXAlignment.Right,
		colour = Theme.Colour.TextDim,
	})
	self._count.Size = UDim2.fromOffset(56, 14)
	self._count.Position = UDim2.new(1, -66, 1, -27)

	-- Reward chips, laid out right to left from the card's bottom corner.
	self._rewards = Instance.new("Frame")
	self._rewards.Name = "Rewards"
	self._rewards.BackgroundTransparency = 1
	self._rewards.AnchorPoint = Vector2.new(1, 0)
	self._rewards.Position = UDim2.new(1, -10, 0, 8)
	self._rewards.Size = UDim2.fromOffset(0, 20)
	self._rewards.AutomaticSize = Enum.AutomaticSize.X
	self._rewards.Parent = card
	Components.List(self._rewards, Enum.FillDirection.Horizontal, Theme.Space.XS,
		Enum.HorizontalAlignment.Right)

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
		return
	end

	local fresh = self._id ~= active.id
	self._id = active.id

	self._card.Visible = true
	self._title.Text = active.title or "OBJECTIVE"
	self._label.Text = active.label or ""

	local goal = tonumber(active.goal) or 0
	local progress = math.clamp(tonumber(active.progress) or 0, 0, math.max(goal, 0))
	self._count.Text = goal > 0 and string.format("%d / %d", progress, goal) or ""
	-- Snap on a new quest, animate on progress: tweening from the last quest's fill to the new
	-- one's would read as progress the player did not make.
	self._bar:SetFraction(goal > 0 and progress / goal or 0, not fresh)

	-- Complete turns the spine and bar green; the card is otherwise amber throughout.
	local done = goal > 0 and progress >= goal
	local accent = done and Theme.Colour.Accent or Theme.Colour.Warning
	self._bar:SetColour(accent)
	TweenService:Create(self._title, Theme.Tween.Value, { TextColor3 = accent }):Play()

	if fresh or self._lastRewards ~= rewards then
		self._lastRewards = rewards
		clearChips(self)
		if rewards then
			if tonumber(rewards.xp) then
				table.insert(self._chips, Components.Chip(self._rewards,
					"XP +" .. tostring(rewards.xp), Theme.Colour.Info, { layoutOrder = 1 }))
			end
			if tonumber(rewards.coins) then
				table.insert(self._chips, Components.Chip(self._rewards,
					"$" .. tostring(rewards.coins), Theme.Colour.Currency, { layoutOrder = 2 }))
			end
		end
	end
end

function Objective:SetVisible(visible: boolean)
	-- Only ever shows when there is something to show; SetVisible cannot resurrect an empty
	-- card, it only hides a populated one while a menu is open.
	self._card.Visible = visible and self._id ~= nil
end

function Objective:Destroy()
	clearChips(self)
	self._card:Destroy()
end

return Objective
