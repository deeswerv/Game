--!strict
-- The level road: every level that pays something, in a line, with you on it.
--
-- Levels 1-30 unlock weapons in the shop (GameConfig.ShopItems' levelRequired); from 31 to the
-- cap (50) every level pays coins and most pay attachments, crystals and titles
-- (ProgressionConfig.RewardFor). Both are already what the server pays -- this only lays
-- them out, so the reason to play the next match is on screen: the next gun, three levels
-- away.
--
-- At the end of the road is prestige, and the card under it is where you take it: your
-- emblem, what the next prestige pays (GameConfig.PrestigeReward, the same table the server
-- pays from) and the button, which asks twice because it resets your level to 1.
--
-- Draws from the shared configs; the live inputs are the level and XP MainUI passes in and
-- the Prestige attribute.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menu = require(script.Parent.Menu)

local LevelRoad = {}
LevelRoad.__index = LevelRoad

local CARD_W, CARD_H, GAP = 132, 196, 12

export type Node = {
	level: number,
	kind: string,          -- "weapon" | "milestone"
	title: string,
	detail: string,
	icon: string,
	colour: Color3,
}

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

--- Every level with something to show, in order.
function LevelRoad.Nodes(): { Node }
	local nodes: { Node } = {}
	local okGame, GameConfig = pcall(require, ReplicatedStorage:WaitForChild("GameConfig", 5) :: ModuleScript)
	local okWeapons, WeaponConfig = pcall(require, ReplicatedStorage:WaitForChild("WeaponConfig", 5) :: ModuleScript)
	local okProgress, ProgressionConfig = pcall(require, ReplicatedStorage:WaitForChild("ProgressionConfig", 5) :: ModuleScript)

	if okGame and type(GameConfig) == "table" then
		for _, item in ipairs(GameConfig.ShopItems or {}) do
			local level = tonumber(item.levelRequired) or 1
			if level > 1 then
				local cfg = okWeapons and WeaponConfig.Weapons[item.id] or nil
				local rarity = cfg and cfg.Rarity or "Common"
				table.insert(nodes, {
					level = level,
					kind = "weapon",
					title = string.upper(tostring(item.name)),
					detail = cfg and tostring(cfg.Class or "") or "Weapon",
					icon = cfg and cfg.Type == "Melee" and "🗡" or "🔫",
					colour = Theme.RarityColour(rarity),
				})
			end
		end
	end
	local cap = okGame and type(GameConfig) == "table" and GameConfig.Leveling.MAX_LEVEL or 50
	if okProgress and type(ProgressionConfig) == "table" then
		for level = ProgressionConfig.FirstMilestoneLevel, cap do
			local special = ProgressionConfig.Milestones[level]
			if special then
				local reward = ProgressionConfig.RewardFor(level)
				local title, icon, colour = "", "💎", Theme.Rarity.Epic.colour
				if special.title then
					title, icon, colour = '"' .. special.title .. '"', "🏷", Theme.Colour.Level
				elseif special.attachment then
					local name = tostring(special.attachment):match(":(.+)$") or tostring(special.attachment)
					title, icon, colour = string.upper(name), "🔧", Theme.Rarity.Rare.colour
				else
					title = string.format("%d CRYSTALS", special.crystals or 0)
				end
				local parts = { "$" .. commas(reward and reward.coins or 0) }
				if special.crystals and special.title then
					table.insert(parts, "💎 " .. special.crystals)
				end
				table.insert(nodes, {
					level = level, kind = "milestone", title = title, detail = table.concat(parts, "  "),
					icon = icon, colour = colour,
				})
			end
		end
	end
	-- The end of the road.
	table.insert(nodes, {
		level = cap, kind = "prestige", title = "PRESTIGE", detail = "Reset for rewards",
		icon = "⭐", colour = Theme.Colour.Level,
	})
	table.sort(nodes, function(a, b)
		if a.level ~= b.level then
			return a.level < b.level
		end
		if (a.kind == "prestige") ~= (b.kind == "prestige") then
			return b.kind == "prestige"
		end
		return a.title < b.title
	end)
	return nodes
end

--- What reaching exactly `level` unlocks, for the level-up call.
function LevelRoad.At(level: number): { Node }
	local out = {}
	for _, node in ipairs(LevelRoad.Nodes()) do
		if node.level == level then
			table.insert(out, node)
		end
	end
	return out
end

function LevelRoad.new(parent: Instance)
	local self = setmetatable({}, LevelRoad)
	self._level, self._exp, self._maxExp = 1, 0, 100
	self._cards = {}

	local menu = Menu.new(parent, {
		id = "LevelRoad",
		title = "Level Road",
		subtitle = "Every level pays -- here is what is coming",
		icon = "🛣",
		size = UDim2.fromOffset(1000, 500),
	})
	self._menu = menu

	-- Where you are: your diamond, the bar to the next level, the next thing it pays.
	local head = Instance.new("Frame")
	head.Name = "Progress"
	head.BackgroundColor3 = Theme.Colour.PanelRaised
	head.BorderSizePixel = 0
	head.Size = UDim2.new(1, 0, 0, 64)
	head.Parent = menu.content
	Components.Corner(head, 12)
	Components.Stroke(head, Theme.Colour.Outline, 2)
	local badge, number = Components.LevelBadge(head, 56)
	badge.Position = UDim2.fromOffset(8, 4)
	self._number = number
	self._bar = Components.Bar(head, { height = 18, colour = Theme.Colour.Level })
	self._bar.instance.Position = UDim2.fromOffset(76, 30)
	self._bar.instance.Size = UDim2.new(1, -92, 0, 18)
	self._xpText = Components.Label(self._bar.instance, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		align = Enum.TextXAlignment.Center,
		outline = 1.5,
	})
	self._xpText.Size = UDim2.fromScale(1, 1)
	self._xpText.ZIndex = 5
	self._next = Components.Label(head, {
		text = "",
		face = Theme.Face.Condensed,
		size = 18,
		colour = Theme.Colour.Level,
	})
	self._next.Position = UDim2.fromOffset(76, 4)
	self._next.Size = UDim2.new(1, -92, 0, 24)

	local track = Instance.new("ScrollingFrame")
	track.Name = "Track"
	track.BackgroundTransparency = 1
	track.BorderSizePixel = 0
	track.Position = UDim2.fromOffset(0, 76)
	track.Size = UDim2.new(1, 0, 0, CARD_H + 24)
	track.ScrollingDirection = Enum.ScrollingDirection.X
	track.ScrollBarThickness = 6
	track.ScrollBarImageColor3 = Theme.Colour.Level
	track.CanvasSize = UDim2.fromOffset(0, 0)
	track.Parent = menu.content
	self._track = track

	-- The road itself: a line behind the cards, filled up to where you are.
	local line = Instance.new("Frame")
	line.Name = "Line"
	line.BackgroundColor3 = Theme.Colour.Sunken
	line.BorderSizePixel = 0
	line.Position = UDim2.fromOffset(0, 26)
	line.Size = UDim2.fromOffset(0, 8)
	line.Parent = track
	local filled = Instance.new("Frame")
	filled.Name = "Filled"
	filled.BackgroundColor3 = Theme.Colour.Level
	filled.BorderSizePixel = 0
	filled.Size = UDim2.fromScale(0, 1)
	filled.Parent = line
	self._line, self._filled = line, filled

	self:_buildPrestige(menu.content)

	menu:OnOpen(function()
		self:_render()
	end)
	Players.LocalPlayer:GetAttributeChangedSignal("Prestige"):Connect(function()
		if menu:IsOpen() then
			self:_render()
		end
	end)
	return self
end

-- ------------------------------------------------------------------ prestige --

local function gameConfig(): any?
	local module = ReplicatedStorage:FindFirstChild("GameConfig")
	if not module then
		return nil
	end
	local ok, cfg = pcall(require, module :: ModuleScript)
	return ok and cfg or nil
end

function LevelRoad:_buildPrestige(parent: GuiObject)
	local card = Instance.new("Frame")
	card.Name = "Prestige"
	card.BackgroundColor3 = Theme.Colour.PanelRaised
	card.BorderSizePixel = 0
	card.Position = UDim2.fromOffset(0, CARD_H + 108)
	card.Size = UDim2.new(1, 0, 0, 96)
	card.Parent = parent
	Components.Corner(card, 14)
	self._prestigeStroke = Components.Stroke(card, Theme.Colour.Outline, 2)
	Components.Gradient(card)

	local okBadge, PrestigeBadge = pcall(function()
		return require(ReplicatedStorage:WaitForChild("PrestigeBadge", 5) :: ModuleScript) :: any
	end)
	if okBadge and PrestigeBadge then
		local badge = PrestigeBadge.Create(card, 80)
		badge.root.Position = UDim2.fromOffset(10, 8)
		self._emblem = badge
	end

	self._prestigeTitle = Components.Label(card, {
		text = "PRESTIGE 0",
		face = Theme.Face.HeavyItalic,
		size = 26,
		outline = 2.4,
	})
	self._prestigeTitle.Position = UDim2.fromOffset(104, 10)
	self._prestigeTitle.Size = UDim2.fromOffset(560, 30)
	self._prestigeTitle.TextXAlignment = Enum.TextXAlignment.Left

	self._prestigeReward = Components.Label(card, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		colour = Theme.Colour.Currency,
		outline = 1.5,
	})
	self._prestigeReward.Position = UDim2.fromOffset(104, 42)
	self._prestigeReward.Size = UDim2.fromOffset(580, 22)
	self._prestigeReward.TextXAlignment = Enum.TextXAlignment.Left

	self._prestigeNote = Components.Label(card, {
		text = "",
		font = Theme.Font.Medium,
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
	})
	self._prestigeNote.Position = UDim2.fromOffset(104, 66)
	self._prestigeNote.Size = UDim2.fromOffset(580, 18)
	self._prestigeNote.TextXAlignment = Enum.TextXAlignment.Left

	self._armedUntil = 0
	self._prestigeButton = Components.Button(card, {
		name = "PrestigeButton",
		text = "PRESTIGE",
		textSize = 20,
		size = UDim2.fromOffset(250, 58),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -18, 0.5, 0),
		colour = Theme.Colour.Level,
		onActivated = function()
			self:_pressPrestige()
		end,
	})
end

function LevelRoad:_renderPrestige()
	local cfg = gameConfig()
	if not cfg or not self._prestigeButton then
		return
	end
	local prestige = tonumber(Players.LocalPlayer:GetAttribute("Prestige")) or 0
	local tier = cfg.GetPrestigeTier(prestige)
	local cap = cfg.Leveling.MAX_LEVEL
	local maxPrestige = cfg.Prestige.MAX_PRESTIGE
	if self._emblem then
		self._emblem:SetLevel(self._level)
		self._emblem:SetPrestige(prestige)
	end
	self._prestigeStroke.Color = prestige > 0 and tier.colour or Theme.Colour.Outline
	self._prestigeTitle.Text = string.format("PRESTIGE %d  ·  %s", prestige, string.upper(tier.name))
	self._prestigeTitle.TextColor3 = prestige > 0 and tier.colour:Lerp(Color3.new(1, 1, 1), 0.3) or Theme.Colour.Text

	local button = self._prestigeButton
	if prestige >= maxPrestige then
		self._prestigeReward.Text = "The highest prestige there is."
		self._prestigeNote.Text = string.format("+%d%% XP on everything, for good",
			math.floor(cfg.PrestigeXPMultiplier(prestige) * 100 - 100 + 0.5))
		button:SetText("MAX PRESTIGE")
		button:SetEnabled(false)
		return
	end
	local nextTier = cfg.GetPrestigeTier(prestige + 1)
	local pay = cfg.PrestigeReward(prestige + 1)
	self._prestigeReward.Text = string.format("NEXT: %s  -  $%s  ·  💎 %d  ·  \"%s\"  ·  +%d%% XP forever",
		string.upper(nextTier.name), commas(pay.coins), pay.crystals, pay.title, math.floor(pay.xpBonus * 100 + 0.5))
	if self._level >= cap then
		local armed = os.clock() < self._armedUntil
		if armed then
			self._prestigeNote.Text = "Press again to confirm: your level goes back to 1."
			self._prestigeNote.TextColor3 = Theme.Colour.Warning
		elseif not self._busyNote then
			self._prestigeNote.Text = "Resets your level to 1. Weapons, attachments, coins, titles and stats all stay."
			self._prestigeNote.TextColor3 = Theme.Colour.TextDim
		end
		button:SetText(armed and "CONFIRM PRESTIGE" or "PRESTIGE NOW")
		button:SetEnabled(true)
	else
		self._prestigeNote.Text = string.format("Reach level %d to prestige  ·  %d level%s to go", cap, cap - self._level,
			cap - self._level == 1 and "" or "s")
		button:SetText("REACH LEVEL " .. cap)
		button:SetEnabled(false)
	end
end

function LevelRoad:_pressPrestige()
	local cfg = gameConfig()
	if not cfg or self._level < cfg.Leveling.MAX_LEVEL or self._prestiging then
		return
	end
	-- Asks twice: it resets the level.
	if os.clock() >= self._armedUntil then
		self._armedUntil = os.clock() + 4
		self:_renderPrestige()
		task.delay(4.1, function()
			if self._menu:IsOpen() then
				self:_renderPrestige()
			end
		end)
		return
	end
	self._armedUntil = 0
	self._prestiging = true
	self._prestigeButton:SetText("PRESTIGING...")
	task.spawn(function()
		local remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
		local request = remotes and remotes:FindFirstChild("PrestigeRequest")
		local ok, result = false, nil
		if request and request:IsA("RemoteFunction") then
			ok, result = pcall(function()
				return request:InvokeServer()
			end)
		end
		self._prestiging = false
		self._busyNote = true
		if ok and type(result) == "table" and result.ok ~= false and result.prestige then
			self._prestigeNote.Text = string.format("PRESTIGE %d!  +$%s, 💎 %d and the \"%s\" title", result.prestige,
				commas(tonumber(result.reward) or 0), tonumber(result.crystals) or 0, tostring(result.title or ""))
			self._prestigeNote.TextColor3 = Theme.Colour.Accent
		else
			self._prestigeNote.Text = type(result) == "table" and tostring(result.reason or "Could not prestige")
				or "Could not prestige"
			self._prestigeNote.TextColor3 = Theme.Colour.Danger
		end
		self:_renderPrestige()
		task.delay(6, function()
			self._busyNote = false
		end)
	end)
end

function LevelRoad:SetLevel(level: number, exp: number, maxExp: number)
	self._level, self._exp, self._maxExp = level, exp, math.max(maxExp, 1)
	if self._menu:IsOpen() then
		self:_render()
	end
end

local function card(parent: GuiObject, node: Node, x: number, state: string)
	local reached = state == "reached"
	local isNext = state == "next"
	local tile = Instance.new("Frame")
	tile.Name = "Level" .. node.level
	tile.BackgroundColor3 = reached and Theme.Shade(node.colour, -0.45) or (isNext and Theme.Shade(node.colour, -0.2)
		or Theme.Colour.PanelRaised)
	tile.BorderSizePixel = 0
	tile.Position = UDim2.fromOffset(x, 44)
	tile.Size = UDim2.fromOffset(CARD_W, CARD_H - 44)
	tile.Parent = parent
	Components.Corner(tile, 14)
	Components.Stroke(tile, isNext and Color3.new(1, 1, 1) or (reached and node.colour or Theme.Colour.Stroke), isNext and 3 or 2)
	if not reached then
		Components.Gradient(tile)
	end

	-- The level on the road above the card.
	local badge, number = Components.LevelBadge(parent, 40)
	badge.Position = UDim2.fromOffset(x + CARD_W / 2 - 20, 10)
	number.Text = tostring(node.level)
	if not reached and not isNext then
		for _, d in ipairs(badge:GetDescendants()) do
			if d:IsA("Frame") then
				d.BackgroundColor3 = Color3.fromRGB(120, 124, 136)
			end
		end
	end

	local icon = Components.Icon(tile, node.icon, 36)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 12)

	local kind = Components.Label(tile, {
		text = node.kind == "weapon" and "UNLOCK" or node.kind == "prestige" and "THE FINISH" or "REWARD",
		font = Theme.Font.Bold,
		size = Theme.Text.Micro,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
	})
	kind.Position = UDim2.fromOffset(0, 56)
	kind.Size = UDim2.new(1, 0, 0, 14)

	local title = Components.Label(tile, {
		text = node.title,
		face = Theme.Face.HeavyItalic,
		size = 20,
		align = Enum.TextXAlignment.Center,
		colour = reached and Theme.Colour.TextDim or Theme.Colour.Text,
		outline = 2.2,
	})
	title.Position = UDim2.fromOffset(4, 72)
	title.Size = UDim2.new(1, -8, 0, 24)
	title.TextScaled = true

	local detail = Components.Label(tile, {
		text = node.detail,
		font = Theme.Font.Medium,
		size = Theme.Text.Small,
		colour = node.kind == "milestone" and Theme.Colour.Currency or node.colour:Lerp(Color3.new(1, 1, 1), 0.3),
		align = Enum.TextXAlignment.Center,
	})
	detail.Position = UDim2.fromOffset(4, 100)
	detail.Size = UDim2.new(1, -8, 0, 18)

	if reached then
		local tick = Components.Label(tile, {
			text = "✓ UNLOCKED",
			font = Theme.Font.Bold,
			size = Theme.Text.Small,
			colour = Theme.Colour.Accent,
			align = Enum.TextXAlignment.Center,
		})
		tick.Position = UDim2.fromOffset(0, 124)
		tick.Size = UDim2.new(1, 0, 0, 18)
	elseif isNext then
		local chip = Components.Chip(tile, "NEXT", Theme.Colour.Level)
		chip.AnchorPoint = Vector2.new(0.5, 0)
		chip.Position = UDim2.new(0.5, 0, 0, 124)
	end
	return tile, badge
end

function LevelRoad:_render()
	for _, c in ipairs(self._cards) do
		c:Destroy()
	end
	table.clear(self._cards)

	local level = self._level
	local cfg = gameConfig()
	local cap = cfg and cfg.Leveling.MAX_LEVEL or 50
	self._number.Text = tostring(level)
	if level >= cap then
		self._bar:SetFraction(1)
		self._xpText.Text = "MAX LEVEL"
	else
		self._bar:SetFraction(self._exp / self._maxExp)
		self._xpText.Text = string.format("%s / %s XP", commas(self._exp), commas(self._maxExp))
	end
	if not self._busyNote then
		self._prestigeNote.TextColor3 = Theme.Colour.TextDim
	end
	self:_renderPrestige()

	local nodes = LevelRoad.Nodes()
	local nextNode: Node? = nil
	local nextIndex = #nodes + 1
	for i, node in ipairs(nodes) do
		if node.level > level then
			nextNode, nextIndex = node, i
			break
		end
	end
	if level >= cap then
		self._next.Text = "MAX LEVEL  ·  PRESTIGE BELOW FOR THE NEXT EMBLEM"
	elseif nextNode then
		local away = nextNode.level - level
		self._next.Text = string.format("NEXT: %s at level %d  ·  %d level%s to go", nextNode.title, nextNode.level, away,
			away == 1 and "" or "s")
	else
		self._next.Text = "EVERYTHING ON THE ROAD IS YOURS"
	end

	local x = GAP
	local lastReachedX = 0
	for i, node in ipairs(nodes) do
		local state = node.level <= level and "reached" or (i == nextIndex and "next" or "locked")
		if nextNode and node.level == nextNode.level and i ~= nextIndex then
			state = "next"
		end
		local tile, badge = card(self._track, node, x, state)
		table.insert(self._cards, tile)
		table.insert(self._cards, badge)
		if state == "reached" then
			lastReachedX = x + CARD_W / 2
		end
		x += CARD_W + GAP
	end
	self._track.CanvasSize = UDim2.fromOffset(x, 0)
	self._line.Size = UDim2.fromOffset(x, 8)
	self._filled.Size = UDim2.fromScale(x > 0 and lastReachedX / x or 0, 1)
	-- Start with where you are in view: the last thing you unlocked near the left.
	self._track.CanvasPosition = Vector2.new(math.max(0, lastReachedX - CARD_W * 1.5), 0)
end

function LevelRoad:Toggle()
	self._menu:Toggle()
end

function LevelRoad:Close()
	self._menu:Close()
end

function LevelRoad:IsOpen(): boolean
	return self._menu:IsOpen()
end

return LevelRoad
