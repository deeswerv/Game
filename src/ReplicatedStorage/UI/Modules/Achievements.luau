--!strict
-- The Achievements panel: every long-term goal, how far along it is, what it pays -- and the
-- CLAIM button that pays it -- plus the title you wear.
--
-- Tabs across the top by category (All, Combat, Duels, World, Progress). Cards sort claimable
-- first, then by how close they are, then the ones already claimed (dimmed, ticked). The
-- strip along the top counts what is unlocked and lets you pick a title from the ones you have
-- earned. AchievementService decides everything; this only draws and asks.

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menu = require(script.Parent.Menu)
local UISound = require(script.Parent.UISound)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local Achievements = {}
Achievements.__index = Achievements

local CARD = Vector2.new(296, 124)

local CATEGORY_COLOUR = {
	Combat = Color3.fromRGB(236, 84, 70),
	Duels = Color3.fromRGB(70, 150, 255),
	World = Color3.fromRGB(88, 200, 110),
	Progress = Color3.fromRGB(250, 190, 60),
}

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function rewardText(reward: any): string
	if type(reward) ~= "table" then
		return ""
	end
	local parts = { "$" .. commas(tonumber(reward.coins) or 0) }
	if tonumber(reward.xp) and reward.xp > 0 then
		table.insert(parts, commas(GameConfig.ShownXP(reward.xp)) .. " XP")
	end
	if tonumber(reward.crystals) and reward.crystals > 0 then
		table.insert(parts, "💎 " .. tostring(reward.crystals))
	end
	if type(reward.title) == "string" then
		table.insert(parts, "🏷 " .. reward.title)
	end
	return table.concat(parts, "  ·  ")
end
Achievements.RewardText = rewardText

function Achievements.new(parent: Instance, remotes, onClaimed: ((any) -> ())?)
	local self = setmetatable({}, Achievements)
	self._remotes = remotes
	self._onClaimed = onClaimed
	self._state = nil :: any
	self._category = "All"
	self._busy = false

	local menu = Menu.new(parent, {
		id = "Achievements",
		title = "Achievements",
		subtitle = "Long-term goals -- claim the reward when one unlocks",
		icon = "🏆",
		size = UDim2.fromOffset(1000, 600),
		categories = {
			{ id = "All", label = "All", icon = "🏆" },
			{ id = "Combat", label = "Combat", icon = "🎯" },
			{ id = "Duels", label = "Duels", icon = "⚔" },
			{ id = "World", label = "World", icon = "🗺" },
			{ id = "Progress", label = "Progress", icon = "⬆" },
		},
		tabs = "top",
	})
	self._menu = menu

	-- The strip: unlocked count and bar on the left, the title picker on the right.
	local strip = Instance.new("Frame")
	strip.Name = "Summary"
	strip.BackgroundColor3 = Theme.Colour.PanelRaised
	strip.BorderSizePixel = 0
	strip.Size = UDim2.new(1, -12, 0, 52)
	strip.Position = UDim2.fromOffset(6, 0)
	strip.Parent = menu.content
	Components.Corner(strip, 12)
	Components.Stroke(strip, Theme.Colour.Outline, 2)
	self._count = Components.Label(strip, {
		text = "",
		face = Theme.Face.HeavyItalic,
		size = 22,
		outline = 2,
	})
	self._count.Position = UDim2.fromOffset(16, 4)
	self._count.Size = UDim2.new(0, 380, 0, 26)
	self._bar = Components.Bar(strip, { height = 8, colour = Theme.Colour.Level })
	self._bar.instance.Position = UDim2.fromOffset(16, 34)
	self._bar.instance.Size = UDim2.new(0, 360, 0, 8)

	local titleLabel = Components.Label(strip, {
		text = "TITLE",
		caps = true,
		size = Theme.Text.Small,
		align = Enum.TextXAlignment.Right,
	})
	titleLabel.AnchorPoint = Vector2.new(1, 0.5)
	titleLabel.Position = UDim2.new(1, -318, 0.5, 0)
	titleLabel.Size = UDim2.fromOffset(60, 20)
	Components.Button(strip, {
		name = "PrevTitle",
		text = "◀",
		textSize = 18,
		size = UDim2.fromOffset(36, 34),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -266, 0.5, 0),
		onActivated = function()
			self:_cycleTitle(-1)
		end,
	})
	self._title = Components.Label(strip, {
		text = "None",
		face = Theme.Face.Condensed,
		size = 20,
		colour = Theme.Colour.Level,
		align = Enum.TextXAlignment.Center,
		outline = 2,
	})
	self._title.AnchorPoint = Vector2.new(1, 0.5)
	self._title.Position = UDim2.new(1, -58, 0.5, 0)
	self._title.Size = UDim2.fromOffset(200, 28)
	Components.Button(strip, {
		name = "NextTitle",
		text = "▶",
		textSize = 18,
		size = UDim2.fromOffset(36, 34),
		anchor = Vector2.new(1, 0.5),
		position = UDim2.new(1, -14, 0.5, 0),
		onActivated = function()
			self:_cycleTitle(1)
		end,
	})

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Grid"
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Position = UDim2.fromOffset(0, 62)
	scroller.Size = UDim2.new(1, 0, 1, -62)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 5
	scroller.ScrollBarImageColor3 = Theme.Colour.Stroke
	scroller.Parent = menu.content
	local grid = Components.Grid(scroller, CARD, 12)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Components.Padding(scroller, 6)
	self._grid = scroller
	self._cards = {}

	menu:OnCategory(function(id: string)
		self._category = id
		if self._state then
			self:_render(self._state)
		end
	end)
	menu:OnOpen(function()
		self:Refresh()
	end)
	return self
end

function Achievements:Refresh()
	task.spawn(function()
		local ok, state = pcall(function()
			return self._remotes.achievementAction:InvokeServer("state")
		end)
		if ok and type(state) == "table" then
			self._state = state
			self:_render(state)
		end
	end)
end

function Achievements:_cycleTitle(step: number)
	local state = self._state
	if not state or self._busy then
		return
	end
	local options = { "" }
	for _, t in ipairs(state.titles or {}) do
		table.insert(options, t)
	end
	local index = table.find(options, state.equipped or "") or 1
	local nextTitle = options[(index - 1 + step) % #options + 1]
	self._busy = true
	task.spawn(function()
		local ok, result = pcall(function()
			return self._remotes.achievementAction:InvokeServer("equip", nextTitle)
		end)
		self._busy = false
		if ok and type(result) == "table" and type(result.state) == "table" then
			self._state = result.state
			self:_render(result.state)
			UISound.Play("Click")
		end
	end)
end

function Achievements:_claim(id: string)
	if self._busy then
		return
	end
	self._busy = true
	task.spawn(function()
		local ok, result = pcall(function()
			return self._remotes.achievementAction:InvokeServer("claim", id)
		end)
		self._busy = false
		if ok and type(result) == "table" then
			if type(result.state) == "table" then
				self._state = result.state
				self:_render(result.state)
			end
			if result.ok then
				UISound.Play("Ring")
				if self._onClaimed then
					for _, a in ipairs(result.state and result.state.list or {}) do
						if a.id == id then
							self._onClaimed(a)
						end
					end
				end
			end
		end
	end)
end

function Achievements:_card(a: any, order: number)
	local colour = CATEGORY_COLOUR[a.category] or Theme.Colour.Info
	local ready = a.unlocked and not a.claimed
	local card = Instance.new("Frame")
	card.Name = "Achievement_" .. tostring(a.id)
	card.BackgroundColor3 = ready and Theme.Shade(colour, -0.45) or Theme.Colour.PanelRaised
	card.BorderSizePixel = 0
	card.Size = UDim2.fromOffset(CARD.X, CARD.Y)
	card.LayoutOrder = order
	card.Parent = self._grid
	Components.Corner(card, 14)
	Components.Stroke(card, ready and colour:Lerp(Color3.new(1, 1, 1), 0.3) or Theme.Colour.Outline, ready and 3 or 2)

	local strip = Instance.new("Frame")
	strip.Name = "Strip"
	strip.BackgroundColor3 = colour
	strip.BorderSizePixel = 0
	strip.Size = UDim2.new(0, 6, 1, -16)
	strip.Position = UDim2.fromOffset(8, 8)
	strip.Parent = card
	Components.Corner(strip, 3)

	local badge = Instance.new("Frame")
	badge.Name = "Badge"
	badge.BackgroundColor3 = a.unlocked and colour or Theme.Colour.Sunken
	badge.BorderSizePixel = 0
	badge.Position = UDim2.fromOffset(22, 12)
	badge.Size = UDim2.fromOffset(48, 48)
	badge.Parent = card
	Components.Corner(badge, 24)
	Components.Stroke(badge, Theme.Colour.Outline, 2.5)
	local icon = Components.Icon(badge, tostring(a.icon or "🏆"), 26)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)
	if not a.unlocked then
		icon.TextTransparency = 0.45
	end

	local name = Components.Label(card, {
		text = string.upper(tostring(a.title or a.id)),
		face = Theme.Face.HeavyItalic,
		size = 18,
		outline = 2,
	})
	name.Position = UDim2.fromOffset(80, 10)
	name.Size = UDim2.new(1, -90, 0, 22)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local text = Components.Label(card, {
		text = tostring(a.text or ""),
		font = Theme.Font.Medium,
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
	})
	text.Position = UDim2.fromOffset(80, 34)
	text.Size = UDim2.new(1, -90, 0, 18)
	text.TextTruncate = Enum.TextTruncate.AtEnd

	-- Ready: the bar is full anyway, so the CLAIM button takes its place. Otherwise the bar
	-- and the count.
	if ready then
		Components.Button(card, {
			name = "Claim",
			text = "CLAIM",
			primary = true,
			textSize = 18,
			size = UDim2.new(1, -92, 0, 30),
			position = UDim2.fromOffset(80, 54),
			onActivated = function()
				self:_claim(a.id)
			end,
		})
	else
		local bar = Components.Bar(card, { height = 10, colour = colour })
		bar.instance.Position = UDim2.fromOffset(80, 62)
		bar.instance.Size = UDim2.new(1, -150, 0, 10)
		bar:SetFraction((tonumber(a.progress) or 0) / math.max(tonumber(a.goal) or 1, 1), false)
		local count = Components.Label(card, {
			text = ("%s / %s"):format(commas(tonumber(a.progress) or 0), commas(tonumber(a.goal) or 0)),
			font = Theme.Font.Bold,
			size = Theme.Text.Small,
			align = Enum.TextXAlignment.Right,
			outline = 1.5,
		})
		count.AnchorPoint = Vector2.new(1, 0)
		count.Position = UDim2.new(1, -12, 0, 57)
		count.Size = UDim2.fromOffset(64, 20)
	end

	local reward = Components.Label(card, {
		text = rewardText(a.reward),
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		colour = Theme.Colour.Currency,
	})
	reward.Position = UDim2.fromOffset(22, 90)
	reward.Size = UDim2.new(1, a.claimed and -70 or -34, 0, 24)
	reward.TextTruncate = Enum.TextTruncate.AtEnd

	if a.claimed then
		local tick = Instance.new("Frame")
		tick.Name = "Claimed"
		tick.AnchorPoint = Vector2.new(1, 1)
		tick.Position = UDim2.new(1, -10, 1, -10)
		tick.Size = UDim2.fromOffset(28, 28)
		tick.BackgroundColor3 = Theme.Colour.Accent
		tick.BorderSizePixel = 0
		tick.Parent = card
		Components.Corner(tick, 14)
		Components.Stroke(tick, Theme.Colour.Outline, 2)
		local mark = Components.Label(tick, { text = "✓", font = Theme.Font.Display, size = 18,
			align = Enum.TextXAlignment.Center, outline = 1.5 })
		mark.Size = UDim2.fromScale(1, 1)
		card.BackgroundTransparency = 0.35
	end
	return card
end

function Achievements:_render(state: any)
	for _, c in ipairs(self._cards) do
		c:Destroy()
	end
	table.clear(self._cards)
	self._count.Text = ("%d / %d UNLOCKED"):format(tonumber(state.done) or 0, tonumber(state.total) or 0)
		.. ((tonumber(state.ready) or 0) > 0 and ("   ·   %d TO CLAIM"):format(state.ready) or "")
	self._bar:SetFraction((tonumber(state.done) or 0) / math.max(tonumber(state.total) or 1, 1), false)
	self._title.Text = (type(state.equipped) == "string" and state.equipped ~= "") and state.equipped or "None"

	local list = {}
	for _, a in ipairs(state.list or {}) do
		if self._category == "All" or a.category == self._category then
			table.insert(list, a)
		end
	end
	-- Ready to claim first, then the closest to done, claimed last.
	local function rank(a): number
		if a.unlocked and not a.claimed then
			return 0
		elseif a.claimed then
			return 2
		end
		return 1
	end
	table.sort(list, function(x, y)
		local rx, ry = rank(x), rank(y)
		if rx ~= ry then
			return rx < ry
		end
		local fx = (tonumber(x.progress) or 0) / math.max(tonumber(x.goal) or 1, 1)
		local fy = (tonumber(y.progress) or 0) / math.max(tonumber(y.goal) or 1, 1)
		if math.abs(fx - fy) > 1e-6 then
			return fx > fy
		end
		return tostring(x.id) < tostring(y.id)
	end)
	for i, a in ipairs(list) do
		table.insert(self._cards, self:_card(a, i))
	end
end

--- How many are waiting to be claimed, from the last state seen (for the nav badge).
function Achievements:Ready(): number
	return self._state and tonumber(self._state.ready) or 0
end

function Achievements:Toggle()
	self._menu:Toggle()
end

function Achievements:Close()
	self._menu:Close()
end

function Achievements:IsOpen(): boolean
	return self._menu:IsOpen()
end

return Achievements
