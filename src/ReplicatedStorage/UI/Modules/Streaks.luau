--!strict
-- The killstreak meter: your streak and the three rewards it is climbing toward, over the
-- weapon dock (bottom right).
--
--   [ STREAK 4 ]  [📡 RADAR · ONLINE 9s]  [🛡 OVERSHIELD · 5 KILLS]  [✈ AIRSTRIKE · 8 KILLS]
--
-- Each reward is a chip that fills toward its kill count, lights in its own colour when it is
-- earned, and says what it is doing: the radar's seconds, the shield left, the key to call an
-- airstrike in. The whole meter sits back (faded) at a streak of 0 so it reads as there but
-- not asking for anything, and is hidden in a duel, where streaks do not count.
--
-- Draws only (StreakConfig for the numbers); MainUI feeds it the streak, the charges, the
-- shield and the rewards as they come.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local StreakConfig = require(ReplicatedStorage:WaitForChild("StreakConfig"))

local Streaks = {}
Streaks.__index = Streaks

local WHITE = Color3.new(1, 1, 1)
local CHIP_W, CHIP_H = 142, 42
local LOCKED_ICON = Color3.fromRGB(70, 74, 86)

type Chip = {
	reward: StreakConfig.Reward,
	frame: Frame,
	stroke: UIStroke,
	disc: Frame,
	icon: TextLabel,
	title: TextLabel,
	status: TextLabel,
	fill: Frame,
	key: Frame,
	scale: UIScale,
	lit: boolean,
}

local function chipFor(parent: GuiObject, reward: StreakConfig.Reward, order: number): Chip
	local frame = Instance.new("Frame")
	frame.Name = reward.id
	frame.Size = UDim2.fromOffset(CHIP_W, CHIP_H)
	frame.BackgroundColor3 = Theme.Colour.Panel
	frame.BackgroundTransparency = 0.25
	frame.BorderSizePixel = 0
	frame.LayoutOrder = order
	frame.ClipsDescendants = false
	frame.Parent = parent
	Components.Corner(frame, 10)
	local stroke = Components.Stroke(frame, Theme.Colour.Outline, 2.5)
	local scale = Instance.new("UIScale")
	scale.Parent = frame

	-- The icon in a round disc of the reward's colour (grey until it is earned).
	local disc = Instance.new("Frame")
	disc.Name = "Disc"
	disc.AnchorPoint = Vector2.new(0, 0.5)
	disc.Position = UDim2.new(0, 5, 0.5, -1)
	disc.Size = UDim2.fromOffset(30, 30)
	disc.BackgroundColor3 = LOCKED_ICON
	disc.BorderSizePixel = 0
	disc.Parent = frame
	Components.Corner(disc, 15)
	Components.Stroke(disc, Theme.Colour.Outline, 2)
	local icon = Components.Icon(disc, reward.icon, 17)
	icon.AnchorPoint = Vector2.new(0.5, 0.5)
	icon.Position = UDim2.fromScale(0.5, 0.5)

	local title = Components.Label(frame, {
		text = reward.name,
		face = Theme.Face.HeavyItalic,
		size = 15,
		outline = 1.6,
	})
	title.Position = UDim2.fromOffset(40, 3)
	title.Size = UDim2.new(1, -44, 0, 18)
	title.TextTruncate = Enum.TextTruncate.AtEnd

	local status = Components.Label(frame, {
		text = string.format("%d KILLS", reward.kills),
		font = Theme.Font.Bold,
		size = 13,
		colour = Theme.Colour.TextDim,
		outline = 1.1,
	})
	status.Position = UDim2.fromOffset(40, 19)
	status.Size = UDim2.new(1, -44, 0, 15)

	-- The key to call it in, for the one reward you use by hand.
	local key = Components.KeyCap(frame, StreakConfig.Airstrike.key.Name, 17)
	key.AnchorPoint = Vector2.new(1, 0.5)
	key.Position = UDim2.new(1, -6, 0, 27)
	key.Visible = false

	-- Progress toward it, along the bottom edge.
	local track = Instance.new("Frame")
	track.Name = "Progress"
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.new(0.5, 0, 1, -3)
	track.Size = UDim2.new(1, -12, 0, 3)
	track.BackgroundColor3 = Color3.fromRGB(12, 13, 17)
	track.BackgroundTransparency = 0.2
	track.BorderSizePixel = 0
	track.Parent = frame
	Components.Corner(track, 2)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(0, 1)
	fill.BackgroundColor3 = reward.colour
	fill.BorderSizePixel = 0
	fill.Parent = track
	Components.Corner(fill, 2)

	return {
		reward = reward, frame = frame, stroke = stroke, disc = disc, icon = icon, title = title,
		status = status, fill = fill, key = key, scale = scale, lit = false,
	}
end

function Streaks.new(parent: GuiObject)
	local self = setmetatable({}, Streaks)

	local group = Instance.new("CanvasGroup")
	group.Name = "Streaks"
	group.BackgroundTransparency = 1
	group.AnchorPoint = Vector2.new(1, 1)
	group.Position = UDim2.new(1, -Theme.Inset.Side, 1, -(Theme.Inset.Bottom + 84))
	group.Size = UDim2.fromOffset(0, CHIP_H + 8)
	group.AutomaticSize = Enum.AutomaticSize.X
	group.GroupTransparency = 0.45
	group.Parent = parent
	local row = Components.List(group, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Right)
	row.VerticalAlignment = Enum.VerticalAlignment.Center

	-- The streak count.
	local count = Instance.new("Frame")
	count.Name = "Count"
	count.Size = UDim2.fromOffset(64, CHIP_H)
	count.BackgroundColor3 = Theme.Colour.Panel
	count.BackgroundTransparency = 0.25
	count.BorderSizePixel = 0
	count.LayoutOrder = 0
	count.Parent = group
	Components.Corner(count, 10)
	Components.Stroke(count, Theme.Colour.Outline, 2.5)
	local caption = Components.Label(count, { text = "STREAK", caps = true, size = 11, colour = Theme.Colour.TextDim })
	caption.Position = UDim2.fromOffset(0, 2)
	caption.Size = UDim2.new(1, 0, 0, 13)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	local number = Components.Label(count, {
		text = "0",
		font = Theme.Font.Display,
		size = 24,
		align = Enum.TextXAlignment.Center,
		outline = 2.2,
	})
	number.Position = UDim2.fromOffset(0, 13)
	number.Size = UDim2.new(1, 0, 0, 26)
	local countScale = Instance.new("UIScale")
	countScale.Parent = count

	self._group = group
	self._number = number
	self._countScale = countScale
	self._chips = {} :: { [string]: Chip }
	for i, reward in ipairs(StreakConfig.Rewards) do
		self._chips[reward.id] = chipFor(group, reward, i)
	end
	self._streak = 0
	self._charges = 0
	self._radarUntil = 0
	self._radarUsed = false
	self._shield = 0
	self._shieldMax = 0
	self._shieldUsed = false
	self._hidden = false
	self:_refresh()
	return self
end

local function light(chip: Chip, on: boolean)
	chip.lit = on
	local colour = chip.reward.colour
	chip.disc.BackgroundColor3 = if on then colour else LOCKED_ICON
	chip.stroke.Color = if on then colour else Theme.Colour.Outline
	chip.stroke.Thickness = if on then 3 else 2.5
	chip.frame.BackgroundColor3 = if on then Theme.Colour.Panel:Lerp(colour, 0.22) else Theme.Colour.Panel
	chip.status.TextColor3 = if on then WHITE else Theme.Colour.TextDim
end

function Streaks:_refresh()
	local streak = self._streak
	self._number.Text = tostring(streak)
	for id, chip in pairs(self._chips) do
		local kills = chip.reward.kills
		local progress = math.clamp(streak / kills, 0, 1)
		chip.fill.Size = UDim2.fromScale(progress, 1)
		chip.key.Visible = false
		local status, on = string.format("%d KILLS", kills), false
		if id == "Radar" then
			local left = math.ceil(self._radarUntil - os.clock())
			if left > 0 then
				status, on = string.format("ONLINE  %ds", left), true
			elseif self._radarUsed then
				status = "✓ USED"
			end
		elseif id == "Overshield" then
			if self._shield > 0 then
				status, on = string.format("SHIELD  %d", math.ceil(self._shield)), true
			elseif self._shieldUsed then
				status = "✓ BROKEN"
			end
		elseif id == "Airstrike" then
			if self._charges > 0 then
				status, on = if self._charges > 1 then string.format("CALL IN  x%d", self._charges) else "CALL IN", true
				chip.key.Visible = true
			elseif streak >= kills then
				status = string.format("NEXT AT %d", StreakConfig.NextAt(streak))
				chip.fill.Size = UDim2.fromScale(0, 1)
			end
		end
		chip.status.Text = status
		light(chip, on)
	end
	local active = streak > 0 or self._charges > 0 or self._shield > 0 or os.clock() < self._radarUntil
	self._group.GroupTransparency = if active then 0 else 0.45
	self._group.Visible = not self._hidden
end

function Streaks:SetStreak(streak: number)
	local previous = self._streak
	self._streak = math.max(0, math.floor(streak))
	if self._streak > previous then
		self._countScale.Scale = 1.3
		TweenService:Create(self._countScale, Theme.Tween.Pop, { Scale = 1 }):Play()
	elseif self._streak == 0 then
		-- A new life: what the last streak earned is gone with it.
		self._radarUsed, self._shieldUsed = false, false
	end
	self:_refresh()
end

function Streaks:SetCharges(n: number)
	self._charges = math.max(0, math.floor(n))
	self:_refresh()
end

function Streaks:SetOvershield(current: number, maximum: number)
	if current <= 0 and self._shield > 0 then
		self._shieldUsed = true
	end
	self._shield, self._shieldMax = math.max(0, current), maximum
	self:_refresh()
end

function Streaks:Radar(duration: number)
	self._radarUntil = os.clock() + duration
	self._radarUsed = true
	self:_refresh()
end

--- A reward just landed: its chip jumps.
function Streaks:Reward(id: string)
	local chip = self._chips[id]
	if not chip then
		return
	end
	self:_refresh()
	chip.scale.Scale = 1.35
	TweenService:Create(chip.scale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

--- Once a second is plenty: the only thing that moves on its own is the radar's clock.
function Streaks:Tick()
	if self._radarUntil > 0 then
		self:_refresh()
		if os.clock() >= self._radarUntil then
			self._radarUntil = 0
			self:_refresh()
		end
	end
end

function Streaks:SetHidden(hidden: boolean)
	self._hidden = hidden
	self._group.Visible = not hidden
end

return Streaks
