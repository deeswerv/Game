--!strict
-- The kill feed, and the elimination call.
--
-- Two different jobs that are easy to confuse. The feed is a LOG: small dark chips down the
-- left where the eye can ignore it until it chooses to read it. The elimination call is a
-- MOMENT: "ELIMINATED  name" slammed in heavy italic at the bottom centre, exactly where the
-- references put it -- close enough to the crosshair to register without looking away, low
-- enough to never cover the next target. Kills in quick succession stack a streak call above
-- it (DOUBLE KILL, TRIPLE KILL...).
--
-- Entries expire on their own timers and remove themselves, so nothing accumulates.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local UISound = require(script.Parent.UISound)
local Components = require(script.Parent.Components)

local KillFeed = {}
KillFeed.__index = KillFeed

local MAX_ROWS = 5
local ROW_LIFETIME = 6
local STREAK_WINDOW = 4.5          -- seconds between kills that still count as one streak
local BANNER_HOLD = 1.7

local STREAK_CALLS = {
	[2] = "DOUBLE KILL",
	[3] = "TRIPLE KILL",
	[4] = "QUAD KILL",
	[5] = "RAMPAGE",
}

local function fadeOut(row: Frame, after: number, rows: { Frame })
	task.delay(after, function()
		if not row.Parent then
			return
		end
		local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		local fade = TweenService:Create(row, info, { BackgroundTransparency = 1 })
		for _, d in ipairs(row:GetDescendants()) do
			if d:IsA("TextLabel") then
				TweenService:Create(d, info, { TextTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, info, { Transparency = 1 }):Play()
			end
		end
		fade.Completed:Once(function()
			local at = table.find(rows, row)
			if at then
				table.remove(rows, at)
			end
			row:Destroy()
		end)
		fade:Play()
	end)
end

function KillFeed.new(parent: GuiObject)
	local self = setmetatable({}, KillFeed)

	local feed = Instance.new("Frame")
	feed.Name = "KillFeed"
	feed.BackgroundTransparency = 1
	feed.Position = UDim2.new(0, Theme.Inset.Side, 0, Theme.Inset.Top + 14)
	feed.Size = UDim2.fromOffset(340, 170)
	feed.Parent = parent
	Components.List(feed, Enum.FillDirection.Vertical, 4)

	-- The elimination call: one line, two colours, heavy italic.
	local banner = Instance.new("Frame")
	banner.Name = "Elimination"
	banner.BackgroundTransparency = 1
	banner.AnchorPoint = Vector2.new(0.5, 1)
	banner.Position = UDim2.new(0.5, 0, 1, -150)
	banner.Size = UDim2.fromOffset(0, 44)
	banner.AutomaticSize = Enum.AutomaticSize.X
	banner.Visible = false
	banner.ZIndex = Theme.Layer.Overlay
	banner.Parent = parent
	local bannerRow = Components.List(banner, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Center)
	bannerRow.VerticalAlignment = Enum.VerticalAlignment.Center
	local bannerScale = Instance.new("UIScale")
	bannerScale.Parent = banner

	local word = Components.Label(banner, {
		text = "ELIMINATED",
		face = Theme.Face.HeavyItalic,
		size = 34,
		autoSize = true,
		layoutOrder = 1,
		outline = 3,
	})
	word.ZIndex = Theme.Layer.Overlay

	local who = Components.Label(banner, {
		text = "",
		face = Theme.Face.HeavyItalic,
		size = 34,
		colour = Theme.Colour.Kill,
		autoSize = true,
		layoutOrder = 2,
		outline = 3,
	})
	who.ZIndex = Theme.Layer.Overlay

	-- The streak call sits above the banner.
	local streak = Components.Label(parent :: any, {
		text = "",
		font = Theme.Font.Display,
		size = 30,
		colour = Theme.Colour.Level,
		align = Enum.TextXAlignment.Center,
		outline = false,
	})
	streak.Name = "Streak"
	Components.Outline(streak, 3, Theme.Colour.LevelEdge:Lerp(Color3.new(0, 0, 0), 0.4), 0)
	streak.AnchorPoint = Vector2.new(0.5, 1)
	streak.Position = UDim2.new(0.5, 0, 1, -196)
	streak.Size = UDim2.fromOffset(420, 36)
	streak.Visible = false
	streak.ZIndex = Theme.Layer.Overlay
	local streakScale = Instance.new("UIScale")
	streakScale.Parent = streak

	self._feed = feed
	self._banner = banner
	self._bannerScale = bannerScale
	self._word = word
	self._who = who
	self._streak = streak
	self._streakScale = streakScale
	self._rows = {}
	self._token = 0
	self._order = 0
	self._streakCount = 0
	self._lastKillAt = -math.huge
	return self
end

local function newRow(self, name: string): Frame
	self._order += 1
	local row = Instance.new("Frame")
	row.Name = name
	row.BackgroundColor3 = Color3.fromRGB(18, 16, 20)
	row.BackgroundTransparency = 0.3
	row.BorderSizePixel = 0
	row.Size = UDim2.new(0, 0, 0, 28)
	row.AutomaticSize = Enum.AutomaticSize.X
	-- Newest at the top: a decreasing order puts the latest row first without reshuffling.
	row.LayoutOrder = -self._order
	row.Parent = self._feed
	Components.Corner(row, 6)
	local rim = Components.Stroke(row, Theme.Colour.Outline, 1.5)
	rim.Transparency = 0.3
	Components.Padding(row, nil, 10, 0)
	local list = Components.List(row, Enum.FillDirection.Horizontal, 6)
	list.VerticalAlignment = Enum.VerticalAlignment.Center

	local pad = row:FindFirstChildOfClass("UIPadding")
	if pad then
		pad.PaddingLeft = UDim.new(0, 6)
	end
	-- A red spine leading the row (first in its list), so a kill line is recognisable
	-- before it is read.
	local spine = Instance.new("Frame")
	spine.Name = "Spine"
	spine.BackgroundColor3 = Theme.Colour.Kill
	spine.BorderSizePixel = 0
	spine.Size = UDim2.new(0, 4, 1, -8)
	spine.LayoutOrder = 0
	spine.Parent = row
	Components.Corner(spine, 2)

	table.insert(self._rows, row)
	while #self._rows > MAX_ROWS do
		local oldest = table.remove(self._rows, 1)
		if oldest then
			oldest:Destroy()
		end
	end
	return row
end

--- One line in the log. `weapon` is optional -- an environmental death has no weapon and the
--- row simply omits it rather than printing a blank.
function KillFeed:Push(victim: string, weapon: string?)
	local row = newRow(self, "Row")

	Components.Label(row, {
		text = "YOU",
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		colour = Theme.Colour.Text,
		autoSize = true,
		layoutOrder = 1,
	})

	if weapon then
		Components.Label(row, {
			text = "[" .. weapon .. "]",
			font = Theme.Font.Bold,
			size = Theme.Text.Small,
			colour = Theme.Colour.TextDim,
			autoSize = true,
			layoutOrder = 2,
		})
	else
		Components.Label(row, {
			text = "»",
			font = Theme.Font.Bold,
			size = Theme.Text.Body,
			colour = Theme.Colour.TextDim,
			autoSize = true,
			layoutOrder = 2,
		})
	end

	Components.Label(row, {
		text = victim,
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		colour = Theme.Colour.Kill:Lerp(Color3.new(1, 1, 1), 0.2),
		autoSize = true,
		layoutOrder = 3,
	})

	fadeOut(row, ROW_LIFETIME, self._rows)
end

--- Somebody else's kill, from the server-wide feed: "Killer [weapon] Victim". When the victim
--- is you, the row is lit red so your own death stands out from the traffic.
function KillFeed:PushOther(killer: string, victim: string, weapon: string?, victimIsMe: boolean?)
	local row = newRow(self, "Other")
	if victimIsMe then
		row.BackgroundColor3 = Color3.fromRGB(110, 14, 20)
		row.BackgroundTransparency = 0.15
	else
		local spine = row:FindFirstChild("Spine")
		if spine and spine:IsA("Frame") then
			spine.BackgroundColor3 = Theme.Colour.TextMuted
		end
	end

	Components.Label(row, {
		text = killer,
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		autoSize = true,
		layoutOrder = 1,
	})
	Components.Label(row, {
		text = weapon and ("[" .. weapon .. "]") or "»",
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
		autoSize = true,
		layoutOrder = 2,
	})
	Components.Label(row, {
		text = victimIsMe and "YOU" or victim,
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		colour = Theme.Colour.Kill:Lerp(Color3.new(1, 1, 1), 0.2),
		autoSize = true,
		layoutOrder = 3,
	})

	fadeOut(row, ROW_LIFETIME, self._rows)
end

--- The call sits low, just over the bottom row, as the references have it -- unless the PLAY
--- diamond is on screen there, in which case it lifts clear of it.
function KillFeed:SetLift(lifted: boolean)
	local lift = lifted and 96 or 0
	self._banner.Position = UDim2.new(0.5, 0, 1, -150 - lift)
	self._streak.Position = UDim2.new(0.5, 0, 1, -196 - lift)
end

--- A line that is not a kill: something earned. Same feed, same shape, gold spine, so a
--- reward reads as part of the fight rather than as a popup interrupting it.
function KillFeed:Notice(tag: string, text: string, colour: Color3?)
	local row = newRow(self, "Notice")
	local spine = row:FindFirstChild("Spine")
	if spine and spine:IsA("Frame") then
		spine.BackgroundColor3 = colour or Theme.Colour.Level
	end

	Components.Label(row, {
		text = string.upper(tag),
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		colour = colour or Theme.Colour.Level,
		autoSize = true,
		layoutOrder = 1,
	})
	Components.Label(row, {
		text = text,
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		autoSize = true,
		layoutOrder = 2,
	})

	-- Rewards linger a little longer than a kill line: they are worth reading.
	fadeOut(row, ROW_LIFETIME * 1.8, self._rows)
end

local function setTransparency(label: TextLabel, t: number, info: TweenInfo?)
	local edge = label:FindFirstChildOfClass("UIStroke")
	if info then
		TweenService:Create(label, info, { TextTransparency = t }):Play()
		if edge then
			TweenService:Create(edge, info, { Transparency = t }):Play()
		end
	else
		label.TextTransparency = t
		if edge then
			edge.Transparency = t
		end
	end
end

--- The centre-bottom call. A token guards it so a second kill during the first one's fade
--- does not get hidden by the first one's timer.
function KillFeed:Eliminated(victim: string)
	-- The kill sting: a bright ring over a thump, so a kill is heard as well as seen.
	UISound.Play("Ring", 1.35, 0.8)
	UISound.Play("Slam", 1.3, 0.6)
	self._token += 1
	local token = self._token

	-- Streak bookkeeping.
	local now = os.clock()
	if now - self._lastKillAt <= STREAK_WINDOW then
		self._streakCount += 1
	else
		self._streakCount = 1
	end
	self._lastKillAt = now

	self._who.Text = victim
	self._banner.Visible = true
	setTransparency(self._word, 0)
	setTransparency(self._who, 0)

	-- Slammed in: oversized, then snapping to size.
	self._bannerScale.Scale = 1.45
	TweenService:Create(self._bannerScale, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }):Play()

	local call = STREAK_CALLS[math.min(self._streakCount, 5)]
	if call and self._streakCount >= 2 then
		self._streak.Text = call
		self._streak.Visible = true
		setTransparency(self._streak, 0)
		self._streakScale.Scale = 1.8
		self._streak.Rotation = math.random(-4, 4)
		TweenService:Create(self._streakScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }):Play()
	end

	task.delay(BANNER_HOLD, function()
		if token ~= self._token then
			return
		end
		local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		setTransparency(self._word, 1, info)
		setTransparency(self._who, 1, info)
		if self._streak.Visible then
			setTransparency(self._streak, 1, info)
		end
		task.delay(0.28, function()
			if token == self._token then
				self._banner.Visible = false
				self._streak.Visible = false
			end
		end)
	end)
end

function KillFeed:SetVisible(visible: boolean)
	self._feed.Visible = visible
	if not visible then
		self._banner.Visible = false
		self._streak.Visible = false
	end
end

function KillFeed:Destroy()
	self._feed:Destroy()
	self._banner:Destroy()
	self._streak:Destroy()
end

return KillFeed
