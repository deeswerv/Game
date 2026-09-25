--!strict
-- The kill feed, and the elimination call.
--
-- Two different jobs that are easy to confuse. The feed is a LOG: it sits down the left where
-- the eye can ignore it until it chooses to read it. The elimination call is a MOMENT: it
-- takes the centre of the screen, briefly, and it is the only thing allowed there. Putting
-- the log in the middle is how a shooter HUD ends up feeling noisy.
--
-- Entries expire on their own timers and remove themselves, so nothing accumulates.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local KillFeed = {}
KillFeed.__index = KillFeed

local MAX_ROWS = 5
local ROW_LIFETIME = 6

function KillFeed.new(parent: GuiObject)
	local self = setmetatable({}, KillFeed)

	local feed = Instance.new("Frame")
	feed.Name = "KillFeed"
	feed.BackgroundTransparency = 1
	feed.AnchorPoint = Vector2.new(0, 0)
	feed.Position = UDim2.new(0, Theme.Inset.Side, 0, Theme.Inset.Top + 12)
	feed.Size = UDim2.fromOffset(300, 140)
	feed.Parent = parent
	local layout = Components.List(feed, Enum.FillDirection.Vertical, Theme.Space.XS)
	layout.VerticalAlignment = Enum.VerticalAlignment.Top

	local banner = Instance.new("Frame")
	banner.Name = "Elimination"
	banner.BackgroundTransparency = 1
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.new(0.5, 0, 0.32, 0)
	banner.Size = UDim2.fromOffset(520, 60)
	banner.Visible = false
	banner.ZIndex = Theme.Layer.Overlay
	banner.Parent = parent

	local word = Components.Label(banner, {
		text = "ELIMINATED",
		font = Theme.Font.Display,
		size = Theme.Text.Small,
		colour = Theme.Colour.Danger,
		align = Enum.TextXAlignment.Center,
	})
	word.Size = UDim2.new(1, 0, 0, 16)
	word.ZIndex = Theme.Layer.Overlay

	local who = Components.Label(banner, {
		text = "",
		font = Theme.Font.Display,
		size = Theme.Text.Title,
		align = Enum.TextXAlignment.Center,
	})
	who.Size = UDim2.new(1, 0, 0, 30)
	who.Position = UDim2.fromOffset(0, 18)
	who.ZIndex = Theme.Layer.Overlay

	self._feed = feed
	self._banner = banner
	self._word = word
	self._who = who
	self._rows = {}
	self._token = 0
	self._order = 0
	return self
end

--- One line in the log. `weapon` is optional -- an environmental death has no weapon and the
--- row simply omits it rather than printing a blank.
function KillFeed:Push(victim: string, weapon: string?)
	self._order += 1

	local row = Instance.new("Frame")
	row.Name = "Row"
	row.BackgroundColor3 = Theme.Colour.Panel
	row.BackgroundTransparency = 0.15
	row.BorderSizePixel = 0
	row.Size = UDim2.new(0, 0, 0, 26)
	row.AutomaticSize = Enum.AutomaticSize.X
	-- Newest at the top: the layout sorts ascending, so a decreasing order puts the latest
	-- row first without reshuffling the ones already there.
	row.LayoutOrder = -self._order
	row.Parent = self._feed
	Components.Corner(row, Theme.Radius.Chip)
	Components.Stroke(row)
	Components.Padding(row, nil, Theme.Space.S, 0)
	Components.List(row, Enum.FillDirection.Horizontal, Theme.Space.XS)

	local tag = Components.Label(row, {
		text = "YOU",
		font = Theme.Font.Bold,
		size = Theme.Text.Micro,
		colour = Theme.Colour.Accent,
		autoSize = true,
		layoutOrder = 1,
	})
	tag.Size = UDim2.fromOffset(0, 26)

	if weapon then
		local with = Components.Label(row, {
			text = weapon,
			size = Theme.Text.Micro,
			colour = Theme.Colour.TextMuted,
			autoSize = true,
			layoutOrder = 2,
		})
		with.Size = UDim2.fromOffset(0, 26)
	end

	local name = Components.Label(row, {
		text = victim,
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		autoSize = true,
		layoutOrder = 3,
	})
	name.Size = UDim2.fromOffset(0, 26)

	table.insert(self._rows, row)
	while #self._rows > MAX_ROWS do
		local oldest = table.remove(self._rows, 1)
		if oldest then
			oldest:Destroy()
		end
	end

	task.delay(ROW_LIFETIME, function()
		if row.Parent then
			local fade = TweenService:Create(row, Theme.Tween.Close, { BackgroundTransparency = 1 })
			fade.Completed:Once(function()
				local at = table.find(self._rows, row)
				if at then
					table.remove(self._rows, at)
				end
				row:Destroy()
			end)
			fade:Play()
		end
	end)
end

--- A line that is not a kill: something earned. Same feed, same shape, different tag, so a
--- reward reads as part of the fight rather than as a popup interrupting it.
---
--- `tag` is the short word on the left ("MASTERY", "LEVEL 35"), `text` what was earned.
function KillFeed:Notice(tag: string, text: string, colour: Color3?)
	self._order += 1

	local row = Instance.new("Frame")
	row.Name = "Notice"
	row.BackgroundColor3 = Theme.Colour.Panel
	row.BackgroundTransparency = 0.15
	row.BorderSizePixel = 0
	row.Size = UDim2.new(0, 0, 0, 26)
	row.AutomaticSize = Enum.AutomaticSize.X
	row.LayoutOrder = -self._order
	row.Parent = self._feed
	Components.Corner(row, Theme.Radius.Chip)
	Components.Stroke(row)
	Components.Padding(row, nil, Theme.Space.S, 0)
	Components.List(row, Enum.FillDirection.Horizontal, Theme.Space.XS)

	local badge = Components.Label(row, {
		text = string.upper(tag),
		font = Theme.Font.Bold,
		size = Theme.Text.Micro,
		colour = colour or Theme.Colour.Warning,
		autoSize = true,
		layoutOrder = 1,
	})
	badge.Size = UDim2.fromOffset(0, 26)

	local body = Components.Label(row, {
		text = text,
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		autoSize = true,
		layoutOrder = 2,
	})
	body.Size = UDim2.fromOffset(0, 26)

	table.insert(self._rows, row)
	while #self._rows > MAX_ROWS do
		local oldest = table.remove(self._rows, 1)
		if oldest then
			oldest:Destroy()
		end
	end

	-- Rewards linger a little longer than a kill line: they are worth reading.
	task.delay(ROW_LIFETIME * 1.8, function()
		if row.Parent then
			local fade = TweenService:Create(row, Theme.Tween.Close, { BackgroundTransparency = 1 })
			fade.Completed:Once(function()
				local at = table.find(self._rows, row)
				if at then
					table.remove(self._rows, at)
				end
				row:Destroy()
			end)
			fade:Play()
		end
	end)
end

--- The centre-screen call. A token guards it so a second kill during the first one's fade
--- does not get hidden by the first one's timer.
function KillFeed:Eliminated(victim: string)
	self._token += 1
	local token = self._token

	self._who.Text = victim
	self._banner.Visible = true
	for _, label in ipairs({ self._word, self._who }) do
		label.TextTransparency = 0
	end

	task.delay(1.4, function()
		if token ~= self._token then
			return
		end
		for _, label in ipairs({ self._word, self._who }) do
			TweenService:Create(label, Theme.Tween.Close, { TextTransparency = 1 }):Play()
		end
		task.delay(0.2, function()
			if token == self._token then
				self._banner.Visible = false
			end
		end)
	end)
end

function KillFeed:SetVisible(visible: boolean)
	self._feed.Visible = visible
	if not visible then
		self._banner.Visible = false
	end
end

function KillFeed:Destroy()
	self._feed:Destroy()
	self._banner:Destroy()
end

return KillFeed
