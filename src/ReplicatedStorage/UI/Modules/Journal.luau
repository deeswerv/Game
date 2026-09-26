--!strict
-- The quest journal: the story told as chapters, where you stand in each, and what the next
-- job pays.
--
-- Three tabs across the top -- DOWNTOWN (the Fixer's chain, and the first step there),
-- BEYOND (the Quartermaster's work past ZEE TOWER) and CONTRACTS (the paid, repeatable end of
-- the board). Left, the chapter: a banner with how far through it you are, then the jobs as a
-- timeline -- a line down the side, a node per job: ticked when done, glowing gold while it
-- is the one you are on, blue when it is yours to take, grey and padlocked while a level (or
-- the tower) stands in the way. Right, the job you picked: who gives it and where to find
-- them, their pitch in their own words, the objective with a segmented tracker, the rewards
-- as big chips, and what to do next.
--
-- The HUD's objective card shows the active job in a fight; this is where you read the
-- whole story. Quest definitions come from QuestConfig (already on the client); where you
-- stand comes from QuestService's state, asked for every time the journal opens.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menu = require(script.Parent.Menu)
local UISound = require(script.Parent.UISound)
local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local Journal = {}
Journal.__index = Journal

local WHITE = Color3.new(1, 1, 1)
local ROW_HEIGHT = 62
local GOLD = Color3.fromRGB(255, 196, 40)

local STATUS = {
	done = { glyph = "✓", text = "COMPLETE", colour = Color3.fromRGB(46, 204, 84) },
	active = { glyph = "▶", text = "IN PROGRESS", colour = GOLD },
	available = { glyph = "!", text = "AVAILABLE", colour = Color3.fromRGB(64, 170, 255) },
	repeatable = { glyph = "↻", text = "REPEATABLE", colour = Color3.fromRGB(190, 110, 255) },
	locked = { glyph = "🔒", text = "LOCKED", colour = Color3.fromRGB(122, 127, 140) },
}

local CHAPTERS = {
	{ id = "Downtown", label = "Downtown", icon = "🏙", kicker = "CHAPTER 1", title = "DOWNTOWN",
	  blurb = "MAKE A NAME, THEN TAKE ZEE TOWER",
	  colour = Color3.fromRGB(214, 84, 150) },
	{ id = "Beyond", label = "Beyond", icon = "🗺", kicker = "CHAPTER 2", title = "BEYOND THE CITY",
	  blurb = "OPENS ONCE THE DON IS BEATEN",
	  colour = Color3.fromRGB(40, 160, 150) },
	{ id = "Contracts", label = "Contracts", icon = "📋", kicker = "ANY TIME", title = "CONTRACTS",
	  blurb = "PAID UP FRONT, TAKEN FOREVER",
	  colour = Color3.fromRGB(190, 120, 40) },
}

local GIVER_FACE = { Quartermaster = "⚓", Fixer = "🕶" }

local OBJECTIVE_ICON = {
	Kill = "🎯", KillPlayer = "⚔", KillElite = "💀", KillInZone = "🎯", Reach = "📍", KillCrew = "👊",
	TurfWin = "🏴", TowerWin = "🏙",
}

local LOCKS = { Tower = "Beat the Don at the top of ZEE TOWER" }

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function rewardChip(parent: GuiObject, icon: string, text: string, colour: Color3, order: number, big: boolean?)
	local chip = Instance.new("Frame")
	chip.BackgroundColor3 = Theme.Colour.Sunken
	chip.Size = UDim2.fromOffset(0, big and 40 or 24)
	chip.AutomaticSize = Enum.AutomaticSize.X
	chip.LayoutOrder = order
	chip.Parent = parent
	Components.Corner(chip, big and 10 or 6)
	Components.Stroke(chip, colour:Lerp(Theme.Colour.Outline, 0.55), 2)
	Components.Padding(chip, nil, big and 12 or 6, 0)
	local row = Components.List(chip, Enum.FillDirection.Horizontal, 5)
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
		rewardChip(parent, "💵", "$" .. commas(rewards.coins), Theme.Colour.Currency, order, big)
	end
	if rewards.xp and rewards.xp > 0 then
		order += 1
		rewardChip(parent, "⭐", commas(GameConfig.ShownXP(rewards.xp)) .. " XP", Theme.Colour.Xp:Lerp(WHITE, 0.3), order, big)
	end
	if rewards.crystals and rewards.crystals > 0 then
		order += 1
		rewardChip(parent, "💎", tostring(rewards.crystals), Color3.fromRGB(120, 220, 255), order, big)
	end
	if rewards.rep and rewards.rep > 0 then
		order += 1
		rewardChip(parent, "🌆", string.format("+%d CRED", rewards.rep), Color3.fromRGB(255, 208, 72), order, big)
	end
end

-- "the Quartermaster", "the Fixer": a giver's name for the middle of a sentence.
local function giverName(quest): string
	local giver = QuestConfig.Givers[quest.giver or "Quartermaster"]
	local name = tostring(giver and giver.displayName or quest.giver or "Quartermaster")
	if name:sub(1, 4) == "The " then
		name = name:sub(5)
	end
	return "the " .. name
end

--- Which chapter a job belongs to.
local function chapterOf(quest): string
	if quest.repeatable then
		return "Contracts"
	end
	if quest.giver == "Fixer" or quest.id == "WelcomeDowntown" then
		return "Downtown"
	end
	return "Beyond"
end

local function jobsIn(chapter: string): { any }
	local out = {}
	for _, q in ipairs(QuestConfig.Quests) do
		if chapterOf(q) == chapter then
			table.insert(out, q)
		end
	end
	if chapter == "Contracts" then
		for _, c in ipairs(QuestConfig.Contracts) do
			table.insert(out, c)
		end
		table.sort(out, function(a, b)
			return (a.levelRequired or 1) < (b.levelRequired or 1)
		end)
	end
	return out
end

function Journal.new(parent: Instance, remotes)
	local self = setmetatable({}, Journal)
	self._remotes = remotes
	self._rows = {} :: { [string]: any }
	self._state = nil :: any
	self._selected = nil :: string?
	self._chapter = "Downtown"
	self._picked = false

	local categories = {}
	for _, c in ipairs(CHAPTERS) do
		table.insert(categories, { id = c.id, label = c.label, icon = c.icon })
	end
	local menu = Menu.new(parent, {
		id = "Journal",
		title = "Quests",
		subtitle = "The story so far, and the next job on the board",
		icon = "📜",
		size = UDim2.fromOffset(1060, 610),
		categories = categories,
		tabs = "top",
	})
	self._menu = menu
	local content = menu.content

	-- ------------------------------------------------------------ the chapter --
	local banner = Instance.new("Frame")
	banner.Name = "Chapter"
	banner.BorderSizePixel = 0
	banner.Size = UDim2.fromOffset(420, 96)
	banner.Parent = content
	Components.Corner(banner, 14)
	Components.Stroke(banner, Theme.Colour.Outline, 2.5)
	self._bannerGradient = Components.Gradient(banner)
	self._banner = banner
	local kicker = Components.Label(banner, { text = "", face = Theme.Face.Condensed, size = 14,
		colour = Color3.fromRGB(255, 236, 200), outline = 1.4 })
	kicker.Position = UDim2.fromOffset(16, 8)
	kicker.Size = UDim2.new(1, -32, 0, 16)
	kicker.TextTruncate = Enum.TextTruncate.AtEnd
	local chapterTitle = Components.Label(banner, { text = "", face = Theme.Face.HeavyItalic, size = 30, outline = 2.6 })
	chapterTitle.Position = UDim2.fromOffset(16, 24)
	chapterTitle.Size = UDim2.new(1, -120, 0, 34)
	local percent = Components.Label(banner, { text = "", font = Theme.Font.Display, size = 30,
		align = Enum.TextXAlignment.Right, outline = 2.6 })
	percent.AnchorPoint = Vector2.new(1, 0)
	percent.Position = UDim2.new(1, -16, 0, 22)
	percent.Size = UDim2.fromOffset(110, 36)
	local chapterBar = Components.Bar(banner, { height = 10, colour = WHITE })
	chapterBar.instance.Position = UDim2.new(0, 16, 1, -30)
	chapterBar.instance.Size = UDim2.new(1, -32, 0, 10)
	local chapterCount = Components.Label(banner, { text = "", font = Theme.Font.Bold, size = 13,
		colour = Color3.fromRGB(255, 240, 220), outline = 1.3 })
	chapterCount.Position = UDim2.new(0, 16, 1, -18)
	chapterCount.Size = UDim2.new(1, -32, 0, 14)
	self._kicker, self._chapterTitle, self._percent = kicker, chapterTitle, percent
	self._chapterBar, self._chapterCount = chapterBar, chapterCount

	-- ------------------------------------------------------------- the timeline --
	local list = Instance.new("ScrollingFrame")
	list.Name = "List"
	list.BackgroundColor3 = Theme.Colour.Sunken
	list.BackgroundTransparency = 0.25
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(0, 106)
	list.Size = UDim2.new(0, 420, 1, -106)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 5
	list.ScrollBarImageColor3 = Theme.Colour.Stroke
	list.Parent = content
	Components.Corner(list, Theme.Radius.Card)
	Components.Padding(list, 8)
	Components.List(list, Enum.FillDirection.Vertical, 0)
	self._list = list

	-- --------------------------------------------------------------- the job --
	local detail = Components.Panel(content, {
		name = "Detail",
		colour = Theme.Colour.PanelRaised,
		radius = Theme.Radius.Card,
		size = UDim2.new(1, -436, 1, 0),
		position = UDim2.fromOffset(436, 0),
	})
	detail.ClipsDescendants = true
	self._detail = detail

	-- Who gives it: a face in a ring, their name, where to find them, the status on the right.
	local hero = Instance.new("Frame")
	hero.Name = "Giver"
	hero.BackgroundColor3 = WHITE -- the gradient carries the giver's colour
	hero.BorderSizePixel = 0
	hero.Size = UDim2.new(1, 0, 0, 76)
	hero.Parent = detail
	self._heroGradient = Components.Gradient(hero)
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0, 0.5)
	face.Position = UDim2.new(0, 16, 0.5, 0)
	face.Size = UDim2.fromOffset(52, 52)
	face.BackgroundColor3 = Theme.Colour.Sunken
	face.BorderSizePixel = 0
	face.Parent = hero
	Components.Corner(face, 26)
	self._faceRim = Components.Stroke(face, GOLD, 3)
	self._face = Components.Icon(face, "", 28)
	self._face.AnchorPoint = Vector2.new(0.5, 0.5)
	self._face.Position = UDim2.fromScale(0.5, 0.5)
	self._giver = Components.Label(hero, { text = "", face = Theme.Face.Condensed, size = 22, outline = 2 })
	self._giver.Position = UDim2.fromOffset(80, 14)
	self._giver.Size = UDim2.new(1, -260, 0, 26)
	self._where = Components.Label(hero, { text = "", size = 14, colour = Theme.Colour.TextDim })
	self._where.Position = UDim2.fromOffset(80, 42)
	self._where.Size = UDim2.new(1, -260, 0, 18)
	local status = Instance.new("Frame")
	status.Name = "Status"
	status.AnchorPoint = Vector2.new(1, 0.5)
	status.Position = UDim2.new(1, -16, 0.5, 0)
	status.Size = UDim2.fromOffset(0, 30)
	status.AutomaticSize = Enum.AutomaticSize.X
	status.Parent = hero
	Components.Corner(status, 8)
	Components.Stroke(status, Theme.Colour.Outline, 2)
	Components.Padding(status, nil, 12, 0)
	Components.Gradient(status)
	local statusText = Components.Label(status, { text = "", face = Theme.Face.Condensed, size = 17, autoSize = true,
		outline = 1.8 })
	statusText.AnchorPoint = Vector2.new(0, 0.5)
	statusText.Position = UDim2.fromScale(0, 0.5)
	self._status, self._statusText = status, statusText

	local title = Components.Label(detail, { text = "", face = Theme.Face.HeavyItalic, size = 36, outline = 3 })
	title.Position = UDim2.fromOffset(20, 86)
	title.Size = UDim2.new(1, -40, 0, 42)
	title.TextTruncate = Enum.TextTruncate.AtEnd
	self._title = title

	-- Their pitch, in their words: a quote with a bar down its side.
	local quote = Instance.new("Frame")
	quote.Name = "Pitch"
	quote.BackgroundColor3 = Theme.Colour.Sunken
	quote.BackgroundTransparency = 0.35
	quote.BorderSizePixel = 0
	quote.Position = UDim2.fromOffset(20, 134)
	quote.Size = UDim2.new(1, -40, 0, 92)
	quote.Parent = detail
	Components.Corner(quote, 10)
	local quoteBar = Instance.new("Frame")
	quoteBar.BackgroundColor3 = GOLD
	quoteBar.BorderSizePixel = 0
	quoteBar.Size = UDim2.new(0, 4, 1, 0)
	quoteBar.Parent = quote
	self._quoteBar = quoteBar
	local brief = Components.Label(quote, { text = "", font = Theme.Font.Medium, size = 16, colour = Theme.Colour.TextDim,
		wrap = true, outline = false })
	brief.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.SemiBold,
		Enum.FontStyle.Italic)
	brief.Position = UDim2.fromOffset(16, 8)
	brief.Size = UDim2.new(1, -28, 1, -16)
	brief.TextYAlignment = Enum.TextYAlignment.Top
	brief.TextTruncate = Enum.TextTruncate.AtEnd
	self._brief = brief

	-- The objective: its icon, what it asks, how far along, a segmented tracker.
	local objectiveCard = Components.Panel(detail, { name = "Objective", colour = Theme.Colour.Panel, radius = 12,
		size = UDim2.new(1, -40, 0, 86), position = UDim2.fromOffset(20, 236) })
	self._objectiveIcon = Components.Icon(objectiveCard, "🎯", 30)
	self._objectiveIcon.Position = UDim2.fromOffset(10, 8)
	local objectiveCaption = Components.Label(objectiveCard, { text = "OBJECTIVE", face = Theme.Face.Condensed, size = 14,
		colour = Theme.Colour.TextMuted })
	objectiveCaption.Position = UDim2.fromOffset(54, 8)
	objectiveCaption.Size = UDim2.fromOffset(200, 16)
	local objective = Components.Label(objectiveCard, { text = "", font = Theme.Font.Bold, size = 20, outline = 2 })
	objective.Position = UDim2.fromOffset(54, 24)
	objective.Size = UDim2.new(1, -180, 0, 24)
	objective.TextTruncate = Enum.TextTruncate.AtEnd
	self._objective = objective
	local count = Components.Label(objectiveCard, { text = "", font = Theme.Font.Display, size = 26,
		align = Enum.TextXAlignment.Right, outline = 2.2 })
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.new(1, -14, 0, 14)
	count.Size = UDim2.fromOffset(120, 30)
	self._count = count
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundTransparency = 1
	track.Position = UDim2.new(0, 14, 1, -28)
	track.Size = UDim2.new(1, -28, 0, 14)
	track.Parent = objectiveCard
	self._track = track

	local rewardsCaption = Components.Label(detail, { text = "REWARDS", face = Theme.Face.Condensed, size = 16,
		colour = Theme.Colour.TextMuted })
	rewardsCaption.Position = UDim2.fromOffset(20, 330)
	rewardsCaption.Size = UDim2.fromOffset(200, 18)
	local rewards = Instance.new("Frame")
	rewards.Name = "Rewards"
	rewards.BackgroundTransparency = 1
	rewards.Position = UDim2.fromOffset(20, 350)
	rewards.Size = UDim2.new(1, -40, 0, 40)
	rewards.Parent = detail
	Components.List(rewards, Enum.FillDirection.Horizontal, 8)
	self._rewards = rewards

	local hint = Components.Label(detail, { text = "", font = Theme.Font.Bold, size = Theme.Text.Body,
		colour = Theme.Colour.TextDim, wrap = true })
	hint.AnchorPoint = Vector2.new(0, 1)
	hint.Position = UDim2.new(0, 20, 1, -16)
	hint.Size = UDim2.new(1, -230, 0, 40)
	self._hint = hint

	self._abandon = Components.Button(detail, {
		name = "Abandon",
		text = "ABANDON",
		danger = true,
		textSize = 18,
		size = UDim2.fromOffset(180, 42),
		anchor = Vector2.new(1, 1),
		position = UDim2.new(1, -20, 1, -14),
		onActivated = function()
			self:Abandon()
		end,
	})
	self._abandon.instance.Visible = false

	menu:OnCategory(function(id: string)
		if self._chapter ~= id then
			self._chapter = id
			self._selected = nil
			self._picked = true
		end
		self:_draw()
	end)
	menu:OnOpen(function()
		self._picked = false
		self:Refresh()
	end)

	return self
end

--- Where the player stands on one job.
function Journal:_statusOf(quest): string
	local state = self._state or {}
	if state.active and state.active.id == quest.id then
		return "active"
	end
	local level = tonumber(state.level) or 1
	if quest.requires == "Tower" and state.towerCleared ~= true then
		return "locked"
	end
	if level < (quest.levelRequired or 1) then
		return "locked"
	end
	if quest.repeatable then
		return "repeatable"
	end
	for _, id in ipairs(state.completed or {}) do
		if id == quest.id then
			return "done"
		end
	end
	return "available"
end

local function lockText(quest, state): string
	if quest.requires and state.towerCleared ~= true then
		return LOCKS[quest.requires] or "Locked"
	end
	return string.format("Level %d required", quest.levelRequired or 1)
end

function Journal:_row(quest, order: number, last: boolean)
	local row = self._rows[quest.id]
	if not row then
		local b = Instance.new("TextButton")
		b.Name = quest.id
		b.AutoButtonColor = false
		b.Text = ""
		b.BackgroundTransparency = 1
		b.Size = UDim2.new(1, -4, 0, ROW_HEIGHT)
		b.Parent = self._list
		-- The line down the side, and the node on it.
		local line = Instance.new("Frame")
		line.Name = "Line"
		line.BorderSizePixel = 0
		line.AnchorPoint = Vector2.new(0.5, 0)
		line.Position = UDim2.new(0, 22, 0, 0)
		line.Size = UDim2.new(0, 4, 1, 0)
		line.Parent = b
		local node = Instance.new("Frame")
		node.Name = "Node"
		node.AnchorPoint = Vector2.new(0.5, 0.5)
		node.Position = UDim2.new(0, 22, 0.5, 0)
		node.Size = UDim2.fromOffset(30, 30)
		node.BorderSizePixel = 0
		node.ZIndex = 3
		node.Parent = b
		Components.Corner(node, 15)
		local nodeRim = Components.Stroke(node, Theme.Colour.Outline, 2.5)
		Components.Gradient(node)
		local nodeScale = Instance.new("UIScale")
		nodeScale.Parent = node
		local glyph = Components.Label(node, { text = "", font = Theme.Font.Display, size = 16,
			align = Enum.TextXAlignment.Center, outline = 1.6 })
		glyph.Size = UDim2.fromScale(1, 1)
		glyph.ZIndex = 4
		-- The card beside it.
		local card = Instance.new("Frame")
		card.Name = "Card"
		card.BackgroundColor3 = Theme.Colour.PanelRaised
		card.BorderSizePixel = 0
		card.Position = UDim2.fromOffset(46, 4)
		card.Size = UDim2.new(1, -48, 1, -8)
		card.Parent = b
		Components.Corner(card, 10)
		local rim = Components.Stroke(card, Theme.Colour.Outline, 2)
		Components.Gradient(card, WHITE, Color3.fromRGB(176, 176, 186))
		local name = Components.Label(card, { text = quest.title, font = Theme.Font.Bold, size = 18, outline = 1.8 })
		name.Position = UDim2.fromOffset(12, 5)
		name.Size = UDim2.new(1, -120, 0, 22)
		name.TextTruncate = Enum.TextTruncate.AtEnd
		local sub = Components.Label(card, { text = "", font = Theme.Font.Bold, size = 13, colour = Theme.Colour.TextMuted,
			outline = false })
		sub.Position = UDim2.fromOffset(12, 29)
		sub.Size = UDim2.new(1, -24, 0, 16)
		sub.TextTruncate = Enum.TextTruncate.AtEnd
		local tag = Components.Label(card, { text = "", face = Theme.Face.Condensed, size = 14,
			align = Enum.TextXAlignment.Right, outline = 1.5 })
		tag.AnchorPoint = Vector2.new(1, 0)
		tag.Position = UDim2.new(1, -10, 0, 7)
		tag.Size = UDim2.fromOffset(104, 18)
		Components.MakeInteractive(b, card, { lift = false })
		b.Activated:Connect(function()
			self._picked = true
			self:Select(quest.id)
		end)
		row = { button = b, rim = rim, node = node, nodeRim = nodeRim, nodeScale = nodeScale, glyph = glyph, line = line,
			card = card, name = name, sub = sub, tag = tag, pulse = nil }
		self._rows[quest.id] = row
	end
	row.button.LayoutOrder = order
	row.button.Visible = true
	local key = self:_statusOf(quest)
	local status = STATUS[key]
	row.node.BackgroundColor3 = status.colour
	row.glyph.Text = status.glyph
	row.line.BackgroundColor3 = if key == "done" then STATUS.done.colour else Theme.Colour.StrokeSoft
	-- The line runs from the node down to the next one; the last job's stops at its node.
	row.line.Size = if last then UDim2.new(0, 4, 0.5, 0) else UDim2.new(0, 4, 1, 0)
	row.line.Position = if order == 1 then UDim2.new(0, 22, 0.5, 0) else UDim2.new(0, 22, 0, 0)
	if order == 1 and not last then
		row.line.Size = UDim2.new(0, 4, 0.5, 0)
	end
	row.tag.Text = status.text
	row.tag.TextColor3 = status.colour
	row.name.TextColor3 = if key == "locked" then Theme.Colour.TextMuted else WHITE
	local r = quest.rewards or {}
	local state = self._state or {}
	if key == "locked" then
		row.sub.Text = "🔒 " .. lockText(quest, state)
	else
		local bits = { "💵 " .. commas(r.coins or 0), "⭐ " .. commas(GameConfig.ShownXP(r.xp or 0)) .. " XP" }
		if (r.crystals or 0) > 0 then
			table.insert(bits, "💎 " .. r.crystals)
		end
		if (r.rep or 0) > 0 then
			table.insert(bits, "🌆 +" .. r.rep)
		end
		if quest.cost then
			table.insert(bits, 1, "costs $" .. commas(quest.cost))
		end
		row.sub.Text = table.concat(bits, "   ")
	end
	local selected = self._selected == quest.id
	row.rim.Color = if selected then WHITE elseif key == "active" then GOLD else Theme.Colour.Outline
	row.rim.Thickness = if selected then 3 else 2
	row.card.BackgroundColor3 = if selected then Theme.Colour.Hover else Theme.Colour.PanelRaised
	-- The job you are on breathes.
	if key == "active" and not row.pulse then
		row.pulse = TweenService:Create(row.nodeScale, TweenInfo.new(0.7, Enum.EasingStyle.Sine,
			Enum.EasingDirection.InOut, -1, true), { Scale = 1.18 })
		row.pulse:Play()
	elseif key ~= "active" and row.pulse then
		row.pulse:Cancel()
		row.pulse = nil
		row.nodeScale.Scale = 1
	end
end

function Journal:Select(id: string)
	self._selected = id
	self:_draw()
end

--- The tracker: one segment per step when there are a handful, a bar when there are many.
function Journal:_drawTrack(have: number, goal: number, colour: Color3)
	for _, child in ipairs(self._track:GetChildren()) do
		child:Destroy()
	end
	if goal <= 12 then
		Components.List(self._track, Enum.FillDirection.Horizontal, 4)
		local width = (1 / goal)
		for i = 1, goal do
			local seg = Instance.new("Frame")
			seg.Name = "Segment"
			seg.BorderSizePixel = 0
			seg.BackgroundColor3 = if i <= have then colour else Theme.Colour.Sunken
			seg.Size = UDim2.new(width, -4, 1, 0)
			seg.LayoutOrder = i
			seg.Parent = self._track
			Components.Corner(seg, 4)
			Components.Stroke(seg, Theme.Colour.Outline, 1.5)
			if i <= have then
				Components.Gradient(seg)
			end
		end
	else
		local bar = Components.Bar(self._track, { height = 14, colour = colour })
		bar:SetFraction(have / goal, false)
	end
end

function Journal:_draw()
	local state = self._state or {}
	local chapter = CHAPTERS[1]
	for _, c in ipairs(CHAPTERS) do
		if c.id == self._chapter then
			chapter = c
		end
	end
	local jobs = jobsIn(chapter.id)

	-- Hide rows from other chapters; lay out this one's.
	local shown = {}
	for i, quest in ipairs(jobs) do
		shown[quest.id] = true
		self:_row(quest, i, i == #jobs)
	end
	for id, row in pairs(self._rows) do
		if not shown[id] then
			row.button.Visible = false
		end
	end

	-- The chapter banner.
	local done, total = 0, 0
	for _, quest in ipairs(jobs) do
		if not quest.repeatable then
			total += 1
			if self:_statusOf(quest) == "done" then
				done += 1
			end
		end
	end
	self._banner.BackgroundColor3 = chapter.colour
	self._kicker.Text = chapter.kicker .. "  ·  " .. chapter.blurb
	self._chapterTitle.Text = chapter.title
	if total > 0 then
		self._percent.Text = string.format("%d%%", math.floor(done / total * 100 + 0.5))
		self._chapterCount.Text = string.format("%d of %d jobs done", done, total)
		self._chapterBar:SetFraction(done / total)
	else
		self._percent.Text = "↻"
		self._chapterCount.Text = string.format("%d contracts on the board", #jobs)
		self._chapterBar:SetFraction(1)
	end

	-- Pick something sensible to show: the active job, else the first you can take.
	if not self._selected or not shown[self._selected] then
		local pick = nil
		for _, quest in ipairs(jobs) do
			if self:_statusOf(quest) == "active" then
				pick = quest.id
			end
		end
		if not pick then
			for _, quest in ipairs(jobs) do
				local key = self:_statusOf(quest)
				if key == "available" or key == "repeatable" then
					pick = quest.id
					break
				end
			end
		end
		self._selected = pick or (jobs[1] and jobs[1].id)
		for i, quest in ipairs(jobs) do
			self:_row(quest, i, i == #jobs)
		end
	end

	local quest = self._selected and QuestConfig.Get(self._selected)
	if not quest then
		return
	end
	local key = self:_statusOf(quest)
	local status = STATUS[key]
	local giver = QuestConfig.Givers[quest.giver or "Quartermaster"]
	self._status.BackgroundColor3 = status.colour
	self._statusText.Text = status.glyph .. "  " .. status.text
	self._face.Text = GIVER_FACE[quest.giver or "Quartermaster"] or "🧑"
	local giverColour = giver and giver.colour or GOLD
	self._faceRim.Color = giverColour:Lerp(WHITE, 0.25)
	self._heroGradient.Color = ColorSequence.new(giverColour:Lerp(Theme.Colour.Panel, 0.35), Theme.Colour.Panel)
	self._quoteBar.BackgroundColor3 = giverColour:Lerp(WHITE, 0.3)
	self._giver.Text = string.upper(tostring(giver and giver.displayName or quest.giver or ""))
	self._where.Text = "📍 " .. tostring(giver and giver.where or "")
	self._title.Text = quest.title
	self._brief.Text = "“" .. tostring(quest.dialogue or quest.summary or "") .. "”"
	self._objective.Text = quest.objective and quest.objective.label or ""
	self._objectiveIcon.Text = OBJECTIVE_ICON[quest.objective and quest.objective.kind or ""] or "🎯"

	local goal = quest.objective and quest.objective.count or 1
	local have = 0
	if key == "active" and state.active then
		have = tonumber(state.active.progress) or 0
	elseif key == "done" then
		have = goal
	end
	self._count.Text = string.format("%d / %d", have, goal)
	self:_drawTrack(have, goal, if key == "done" then STATUS.done.colour else GOLD)

	for _, child in ipairs(self._rewards:GetChildren()) do
		if child:IsA("Frame") then
			child:Destroy()
		end
	end
	if quest.cost then
		rewardChip(self._rewards, "🏷", "COSTS $" .. commas(quest.cost), Theme.Colour.Danger:Lerp(WHITE, 0.2), 0, true)
	end
	rewardsInto(self._rewards, quest.rewards or {}, true)

	local where = tostring(giver and giver.where or "")
	if key == "active" then
		self._hint.Text = "Finish the objective -- it pays out the moment it's done."
	elseif key == "available" then
		self._hint.Text = "Talk to " .. giverName(quest) .. " " .. where .. " to take this job."
	elseif key == "repeatable" then
		self._hint.Text = "Offered by " .. giverName(quest) .. " once their story is done. Take it as often as you like."
	elseif key == "locked" then
		self._hint.Text = if quest.requires and state.towerCleared ~= true
			then "Opens when you " .. string.lower(LOCKS[quest.requires] or "unlock it") .. "."
			else string.format("Reach level %d to unlock this job.", quest.levelRequired or 1)
	else
		local name = giverName(quest)
		self._hint.Text = "Done. " .. name:sub(1, 1):upper() .. name:sub(2) .. " remembers."
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
			-- The first draw happened before the state arrived; unless the player has picked
			-- a job since, open on the chapter of the one they are on.
			if not self._picked then
				self._selected = nil
				local active = state.active and QuestConfig.Get(state.active.id)
				if active then
					local chapter = chapterOf(active)
					if chapter ~= self._chapter then
						self._chapter = chapter
						self._menu:SelectCategory(chapter)
					end
				end
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
