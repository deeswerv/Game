--!strict
-- The quest journal: every contract in the game, where you stand on each, and what it pays.
--
-- Left, the list -- done, in progress, ready to take, or locked behind a level -- in the order
-- the chain runs. Right, the one you picked: the brief, the objective with a progress bar,
-- the rewards as big chips, and what to do next (who to talk to, what level you need).
--
-- The objective card on the HUD shows the active quest in a fight; this is where you read
-- the whole story. Quest definitions come from QuestConfig (already on the client); where
-- you stand comes from QuestService's state, asked for every time the journal opens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menu = require(script.Parent.Menu)
local UISound = require(script.Parent.UISound)
local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local Journal = {}
Journal.__index = Journal

local WHITE = Color3.new(1, 1, 1)
local ROW_HEIGHT = 64

local STATUS = {
	done = { icon = "✅", text = "COMPLETE", colour = Color3.fromRGB(46, 204, 84) },
	active = { icon = "▶️", text = "IN PROGRESS", colour = Color3.fromRGB(255, 190, 32) },
	available = { icon = "❗", text = "AVAILABLE", colour = Color3.fromRGB(64, 170, 255) },
	locked = { icon = "🔒", text = "LOCKED", colour = Color3.fromRGB(122, 127, 140) },
}

local function rewardChip(parent: GuiObject, icon: string, text: string, colour: Color3, order: number, big: boolean?)
	local chip = Instance.new("Frame")
	chip.BackgroundColor3 = Theme.Colour.Sunken
	chip.Size = UDim2.fromOffset(0, big and 40 or 24)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.LayoutOrder = order
	chip.Parent = parent
	Components.Corner(chip, big and 10 or 6)
	Components.Stroke(chip, Theme.Colour.Outline, 1.5)
	Components.Padding(chip, nil, big and 10 or 6, 0)
	local row = Components.List(chip, Enum.FillDirection.Horizontal, 4)
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	Components.Icon(chip, icon, big and 20 or 13).LayoutOrder = 1
	local label = Components.Label(chip, {
		text = text,
		font = Theme.Font.Display,
		size = big and 20 or 14,
		colour = colour,
		autoSize = true,
		layoutOrder = 2,
		outline = big and 2 or 1.5,
	})
	label.LayoutOrder = 2
	return chip
end

local function rewardsInto(parent: GuiObject, rewards, big: boolean?)
	local order = 0
	if rewards.coins and rewards.coins > 0 then
		order += 1
		rewardChip(parent, "💵", string.format("%d", rewards.coins), Theme.Colour.Currency, order, big)
	end
	if rewards.xp and rewards.xp > 0 then
		order += 1
		rewardChip(parent, "⭐", string.format("%d XP", GameConfig.ShownXP(rewards.xp)), Theme.Colour.Xp:Lerp(WHITE, 0.3), order, big)
	end
	if rewards.crystals and rewards.crystals > 0 then
		order += 1
		rewardChip(parent, "💎", string.format("%d", rewards.crystals), Color3.fromRGB(120, 220, 255), order, big)
	end
end

function Journal.new(parent: Instance, remotes)
	local self = setmetatable({}, Journal)
	self._remotes = remotes
	self._rows = {}
	self._state = nil
	self._selected = nil

	local menu = Menu.new(parent, {
		id = "Journal",
		title = "Quests",
		subtitle = "Contracts from the Quartermaster -- and what they pay",
		icon = "📜",
		size = UDim2.fromOffset(1000, 560),
	})
	self._menu = menu

	-- ------------------------------------------------------------ the list --
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundColor3 = Theme.Colour.Sunken
	list.BackgroundTransparency = 0.2
	list.BorderSizePixel = 0
	list.Size = UDim2.new(0, 400, 1, -30)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = Theme.Colour.Stroke
	list.Parent = menu.content
	Components.Corner(list, Theme.Radius.Card)
	Components.Padding(list, 8)
	Components.List(list, Enum.FillDirection.Vertical, 6)
	self._list = list

	local progress = Components.Label(menu.content, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
	})
	progress.AnchorPoint = Vector2.new(0, 1)
	progress.Position = UDim2.fromScale(0, 1)
	progress.Size = UDim2.fromOffset(400, 22)
	self._progress = progress

	-- ---------------------------------------------------------- the detail --
	local detail = Components.Panel(menu.content, {
		name = "Detail",
		colour = Theme.Colour.PanelRaised,
		radius = Theme.Radius.Card,
		size = UDim2.new(1, -416, 1, 0),
		position = UDim2.fromOffset(416, 0),
	})
	self._detail = detail

	local status = Instance.new("Frame")
	status.Name = "Status"
	status.Position = UDim2.fromOffset(20, 18)
	status.Size = UDim2.fromOffset(0, 26)
	status.AutomaticSize = Enum.AutomaticSize.X
	status.Parent = detail
	Components.Corner(status, 6)
	Components.Stroke(status, Theme.Colour.Outline, 2)
	Components.Padding(status, nil, 10, 0)
	local statusText = Components.Label(status, {
		text = "",
		face = Theme.Face.Condensed,
		size = 17,
		autoSize = true,
		outline = 1.8,
	})
	statusText.AnchorPoint = Vector2.new(0, 0.5)
	statusText.Position = UDim2.fromScale(0, 0.5)
	self._status, self._statusText = status, statusText

	local title = Components.Label(detail, {
		text = "",
		face = Theme.Face.HeavyItalic,
		size = 40,
		outline = 3,
	})
	title.Position = UDim2.fromOffset(20, 52)
	title.Size = UDim2.new(1, -40, 0, 46)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	self._title = title

	local giver = Components.Label(detail, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		colour = Theme.Colour.Level,
	})
	giver.Position = UDim2.fromOffset(20, 98)
	giver.Size = UDim2.new(1, -40, 0, 20)
	self._giver = giver

	local brief = Components.Label(detail, {
		text = "",
		font = Theme.Font.Medium,
		size = 18,
		colour = Theme.Colour.TextDim,
		wrap = true,
	})
	brief.Position = UDim2.fromOffset(20, 128)
	brief.Size = UDim2.new(1, -40, 0, 96)
	brief.TextYAlignment = Enum.TextYAlignment.Top
	self._brief = brief

	local objectiveCaption = Components.Label(detail, {
		text = "OBJECTIVE",
		face = Theme.Face.Condensed,
		size = 18,
		colour = Theme.Colour.TextMuted,
	})
	objectiveCaption.Position = UDim2.fromOffset(20, 234)
	objectiveCaption.Size = UDim2.fromOffset(200, 20)
	local objective = Components.Label(detail, {
		text = "",
		font = Theme.Font.Bold,
		size = 22,
		outline = 2,
	})
	objective.Position = UDim2.fromOffset(20, 256)
	objective.Size = UDim2.new(1, -140, 0, 28)
	self._objective = objective
	local count = Components.Label(detail, {
		text = "",
		font = Theme.Font.Display,
		size = 24,
		align = Enum.TextXAlignment.Right,
		outline = 2.2,
	})
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.new(1, -20, 0, 256)
	count.Size = UDim2.fromOffset(120, 28)
	self._count = count
	local barHolder = Instance.new("Frame")
	barHolder.BackgroundTransparency = 1
	barHolder.Position = UDim2.fromOffset(20, 290)
	barHolder.Size = UDim2.new(1, -40, 0, 16)
	barHolder.Parent = detail
	self._bar = Components.Bar(barHolder, { height = 16, colour = Theme.Colour.Level })

	local rewardsCaption = Components.Label(detail, {
		text = "REWARDS",
		face = Theme.Face.Condensed,
		size = 18,
		colour = Theme.Colour.TextMuted,
	})
	rewardsCaption.Position = UDim2.fromOffset(20, 322)
	rewardsCaption.Size = UDim2.fromOffset(200, 20)
	local rewards = Instance.new("Frame")
	rewards.Name = "Rewards"
	rewards.BackgroundTransparency = 1
	rewards.Position = UDim2.fromOffset(20, 346)
	rewards.Size = UDim2.new(1, -40, 0, 40)
	rewards.Parent = detail
	Components.List(rewards, Enum.FillDirection.Horizontal, 8)
	self._rewards = rewards

	local hint = Components.Label(detail, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		colour = Theme.Colour.TextDim,
		wrap = true,
	})
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0, 20, 1, -20)
	hint.Size = UDim2.new(1, -240, 0, 44)
	self._hint = hint

	self._abandon = Components.Button(detail, {
		name = "Abandon",
		text = "ABANDON",
		danger = true,
		textSize = 18,
		size = UDim2.fromOffset(180, 44),
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -20, 1, -18),
		onActivated = function()
			self:Abandon()
		end,
	})
	self._abandon.instance.Visible = false

	menu:OnOpen(function()
		self._picked = false
		self:Refresh()
	end)

	return self
end

--- Where the player stands on one quest.
function Journal:_statusOf(quest): string
	local state = self._state or {}
	if state.active and state.active.id == quest.id then
		return "active"
	end
	for _, id in ipairs(state.completed or {}) do
		if id == quest.id and not quest.repeatable then
			return "done"
		end
	end
	local level = tonumber(state.level) or 1
	if level < (quest.levelRequired or 1) then
		return "locked"
	end
	return "available"
end

function Journal:_row(quest, order: number)
	local row = self._rows[quest.id]
	if not row then
		local b = Instance.new("TextButton")
		b.Name = quest.id
		b.AutoButtonColor = false
		b.Text = ""
		b.BackgroundColor3 = Theme.Colour.PanelRaised
		b.Size = UDim2.new(1, -6, 0, ROW_HEIGHT)
		b.Parent = self._list
		Components.Corner(b, Theme.Radius.Small)
		local rim = Components.Stroke(b, Theme.Colour.Outline, 2)
		Components.Gradient(b, WHITE, Color3.fromRGB(170, 170, 180))
		local icon = Components.Icon(b, "", 24)
		icon.AnchorPoint = Vector2.new(0, 0.5)
		icon.Position = UDim2.new(0, 8, 0.5, 0)
		local name = Components.Label(b, {
			text = quest.title,
			font = Theme.Font.Bold,
			size = 19,
			outline = 1.8,
		})
		name.Position = UDim2.fromOffset(46, 8)
		name.Size = UDim2.new(1, -150, 0, 22)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local sub = Components.Label(b, {
			text = "",
			font = Theme.Font.Bold,
			size = 13,
			colour = Theme.Colour.TextMuted,
			outline = false,
		})
		sub.Position = UDim2.fromOffset(46, 34)
		sub.Size = UDim2.new(1, -150, 0, 16)
		local tag = Components.Label(b, {
			text = "",
			face = Theme.Face.Condensed,
			size = 15,
			align = Enum.TextXAlignment.Right,
			outline = 1.6,
		})
		tag.AnchorPoint = Vector2.new(1, 0.5)
		tag.Position = UDim2.new(1, -12, 0.5, 0)
		tag.Size = UDim2.fromOffset(100, 18)
		Components.MakeInteractive(b, b, { lift = false })
		b.Activated:Connect(function()
			self._picked = true
			self:Select(quest.id)
		end)
		row = { button = b, rim = rim, icon = icon, name = name, sub = sub, tag = tag }
		self._rows[quest.id] = row
	end
	row.button.LayoutOrder = order
	local status = STATUS[self:_statusOf(quest)]
	row.icon.Text = status.icon
	row.tag.Text = status.text
	row.tag.TextColor3 = status.colour
	row.name.TextColor3 = status == STATUS.locked and Theme.Colour.TextMuted or WHITE
	local r = quest.rewards or {}
	row.sub.Text = status == STATUS.locked and string.format("Level %d required", quest.levelRequired or 1)
		or string.format("💵 %d   ⭐ %d XP%s", r.coins or 0, r.xp or 0, (r.crystals or 0) > 0 and ("   💎 " .. r.crystals) or "")
	local selected = self._selected == quest.id
	row.rim.Color = selected and WHITE or Theme.Colour.Outline
	row.rim.Thickness = selected and 3 or 2
end

function Journal:Select(id: string)
	self._selected = id
	self:_draw()
end

function Journal:_draw()
	local state = self._state or {}
	local done = 0
	for order, quest in ipairs(QuestConfig.Quests) do
		self:_row(quest, order)
		if self:_statusOf(quest) == "done" then
			done += 1
		end
	end
	self._progress.Text = string.format("%d of %d contracts complete", done, #QuestConfig.Quests)

	-- Pick something sensible to show: the active quest, else the first one you can take.
	if not self._selected then
		local pick = state.active and state.active.id
		if not pick then
			for _, quest in ipairs(QuestConfig.Quests) do
				if self:_statusOf(quest) == "available" then
					pick = quest.id
					break
				end
			end
		end
		self._selected = pick or (QuestConfig.Quests[1] and QuestConfig.Quests[1].id)
		for order, quest in ipairs(QuestConfig.Quests) do
			self:_row(quest, order)
		end
	end

	local quest = self._selected and QuestConfig.Get(self._selected)
	if not quest then
		return
	end
	local key = self:_statusOf(quest)
	local status = STATUS[key]
	self._status.BackgroundColor3 = status.colour
	self._statusText.Text = status.icon .. "  " .. status.text
	self._title.Text = quest.title
	self._giver.Text = "From the " .. tostring(quest.giver or "Quartermaster")
	self._brief.Text = quest.summary or ""
	self._objective.Text = quest.objective and quest.objective.label or ""

	local goal = quest.objective and quest.objective.count or 1
	local have = 0
	if key == "active" and state.active then
		have = tonumber(state.active.progress) or 0
	elseif key == "done" then
		have = goal
	end
	self._count.Text = string.format("%d / %d", have, goal)
	self._bar:SetFraction(have / math.max(goal, 1))
	self._bar:SetColour(key == "done" and Theme.Colour.Accent or Theme.Colour.Level)

	for _, child in ipairs(self._rewards:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	rewardsInto(self._rewards, quest.rewards or {}, true)

	if key == "active" then
		self._hint.Text = "Finish the objective -- the reward pays out the moment it's done."
	elseif key == "available" then
		self._hint.Text = "Talk to the " .. tostring(quest.giver or "Quartermaster") .. " in the lobby to take this contract."
	elseif key == "locked" then
		self._hint.Text = string.format("Reach level %d to unlock this contract.", quest.levelRequired or 1)
	else
		self._hint.Text = "Done. The Quartermaster remembers."
	end
	self._abandon.instance.Visible = key == "active"
end

function Journal:SetState(state)
	if type(state) ~= "table" then
		return
	end
	self._state = state
	if self._menu:IsOpen() then
		self:_draw()
	end
end

function Journal:Refresh()
	self:_draw()
	task.spawn(function()
		local ok, state = pcall(function()
			return self._remotes.questAction:InvokeServer("state")
		end)
		if ok and type(state) == "table" then
			self._state = state
			-- The first draw happened before the state arrived; unless the player has
			-- picked a quest since, re-pick now that we know which one is active.
			if not self._picked then
				self._selected = nil
			end
			self:_draw()
		end
	end)
end

function Journal:Abandon()
	task.spawn(function()
		local ok, result = pcall(function()
			return self._remotes.questAction:InvokeServer("abandon")
		end)
		if ok then
			UISound.Play("Clunk", 0.7, 0.6)
			if type(result) == "table" and result.state then
				self._state = result.state
			end
			self:Refresh()
		end
	end)
end

function Journal:Open()
	self._menu:Open()
end
function Journal:Close()
	self._menu:Close()
end
function Journal:Toggle()
	self._menu:Toggle()
end
function Journal:IsOpen(): boolean
	return self._menu:IsOpen()
end

return Journal
