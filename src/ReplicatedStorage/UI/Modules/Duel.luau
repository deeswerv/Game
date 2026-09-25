--!strict
-- Duels, front to back, the way the reference game presents them:
--
--   free roam   a big green PLAY diamond with "Click Play To Queue Up!" over it, and on a
--               keyboard its key (J) and how to get a cursor out of shift lock (hold ALT)
--   queued      the diamond turns gold and cancels; a small card says it is searching
--   countdown   the VS screen -- both fighters thrown in on red and blue slabs -- then
--               3 - 2 - 1 - FIGHT! slammed into the middle of the screen
--   live        a scoreboard across the top: your avatar and a red bar with your score, the
--               clock, a blue bar with theirs and their avatar
--   rounds      every point is a round: ROUND WON / ROUND LOST, then ROUND 2 (MATCH POINT,
--               FINAL ROUND) and a fresh count while the server resets both fighters
--   over        a results screen -- VICTORY / DEFEAT, both fighters' full-body avatars on
--               name plates with their level diamonds, and the reference's stat tiles:
--               Eliminations, Deaths, Damage Dealt, Damage Taken, KDR
--
-- Draws and asks; decides nothing. Queueing and leaving are requests to MatchService, which
-- owns the queue, the score and every teleport. Everything shown is what it was told.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local UISound = require(script.Parent.UISound)

local Duel = {}
Duel.__index = Duel

local WHITE = Color3.new(1, 1, 1)
local RED = Color3.fromRGB(236, 44, 52)
local BLUE = Color3.fromRGB(40, 110, 255)
local GOLD_TOP = Color3.fromRGB(255, 244, 150)
local GOLD_BOTTOM = Color3.fromRGB(255, 166, 20)
local RESULTS_TIME = 7
local MATCH_ROUND_HOLD = 2.4

export type Hooks = {
	onScoreboard: ((visible: boolean) -> ())?,   -- the HUD makes room at the top
	onPlayVisible: ((visible: boolean) -> ())?,  -- the kill banner moves out of PLAY's way
}

local function headshot(userId: number): string
	if userId <= 0 then
		return ""
	end
	return string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId)
end

local function fullBody(userId: number): string
	if userId <= 0 then
		return ""
	end
	return string.format("rbxthumb://type=Avatar&id=%d&w=420&h=420", userId)
end

local function levelOf(userId: number): number?
	local p = Players:GetPlayerByUserId(userId)
	local level = p and p:GetAttribute("Level")
	return type(level) == "number" and level or nil
end

local function scaled(object: GuiObject): UIScale
	local s = object:FindFirstChildOfClass("UIScale")
	if not s then
		s = Instance.new("UIScale")
		s.Parent = object
	end
	return s :: UIScale
end

local function slam(object: GuiObject, from: number, time: number?)
	local s = scaled(object)
	s.Scale = from
	TweenService:Create(s, TweenInfo.new(time or 0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
end

local function fadeText(label: TextLabel, to: number, time: number)
	local info = TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(label, info, { TextTransparency = to }):Play()
	local edge = label:FindFirstChildOfClass("UIStroke")
	if edge then
		TweenService:Create(edge, info, { Transparency = to }):Play()
	end
end

-- ------------------------------------------------------------------ build --

local function buildPlay(self, parent: GuiObject)
	local holder = Instance.new("TextButton")
	holder.Name = "Play"
	holder.AutoButtonColor = false
	holder.Text = ""
	holder.BackgroundTransparency = 1
	-- Bottom-left, just above your name and health: where the eye already goes for "me",
	-- and clear of the middle of the screen where the fighting is.
	holder.AnchorPoint = Vector2.new(0, 1)
	holder.Position = UDim2.new(0, 24, 1, -122)
	holder.Size = UDim2.fromOffset(104, 104)
	holder.Parent = parent

	local diamond = Instance.new("Frame")
	diamond.Name = "Diamond"
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromScale(0.5, 0.5)
	diamond.Size = UDim2.fromOffset(72, 72)
	diamond.Rotation = 45
	diamond.BackgroundColor3 = Theme.Colour.Accent
	diamond.Parent = holder
	Components.Corner(diamond, 12)
	local rim = Components.Stroke(diamond, WHITE, 4)
	rim.Transparency = 0.05
	local g = Components.Gradient(diamond, Color3.fromRGB(220, 255, 220), Color3.fromRGB(120, 170, 120))
	g.Rotation = 45

	-- A soft green glow behind it.
	local glow = Instance.new("Frame")
	glow.Name = "Glow"
	glow.AnchorPoint = Vector2.new(0.5, 0.5)
	glow.Position = UDim2.fromScale(0.5, 0.5)
	glow.Size = UDim2.fromOffset(130, 130)
	glow.BackgroundColor3 = Theme.Colour.Accent
	glow.BackgroundTransparency = 0.75
	glow.ZIndex = 0
	glow.Parent = holder
	Components.Corner(glow, 65)
	local glowFade = Instance.new("UIGradient")
	glowFade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.2),
		NumberSequenceKeypoint.new(1, 1),
	})
	glowFade.Parent = glow

	local label = Components.Label(holder, {
		text = "PLAY",
		face = Theme.Face.Condensed,
		size = 34,
		align = Enum.TextXAlignment.Center,
		outline = 3,
	})
	label.Size = UDim2.fromScale(1, 1)
	label.ZIndex = 3

	-- The shift-lock camera pins the cursor to the middle of the screen, so on a keyboard the
	-- diamond says which key presses it, and a tip beside it says how to get a cursor back.
	local keyboard = UserInputService.KeyboardEnabled
	local key = Components.KeyCap(holder, "J", 26)
	key.AnchorPoint = Vector2.new(0.5, 0.5)
	key.Position = UDim2.new(0.5, 30, 0.5, 30)
	key.ZIndex = 4
	for _, d in ipairs(key:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = 4
		end
	end
	key.Visible = keyboard

	local tip = Instance.new("Frame")
	tip.Name = "CursorTip"
	tip.BackgroundColor3 = Theme.Colour.Panel
	tip.BackgroundTransparency = 0.15
	tip.AnchorPoint = Vector2.new(0, 0.5)
	tip.Position = UDim2.new(1, 8, 0.5, 0)
	tip.Size = UDim2.fromOffset(0, 34)
	tip.AutomaticSize = Enum.AutomaticSize.X
	tip.Visible = keyboard
	tip.Parent = holder
	Components.Corner(tip, 8)
	Components.Stroke(tip, Theme.Colour.Outline, 2)
	Components.Padding(tip, nil, 8, 0)
	local tipRow = Components.List(tip, Enum.FillDirection.Horizontal, 6)
	tipRow.VerticalAlignment = Enum.VerticalAlignment.Center
	Components.Label(tip, {
		text = "HOLD", face = Theme.Face.Condensed, size = 17, autoSize = true, layoutOrder = 1, outline = 1.5,
	})
	Components.KeyCap(tip, "ALT", 22).LayoutOrder = 2
	Components.Label(tip, {
		text = "FOR MOUSE", face = Theme.Face.Condensed, size = 17, autoSize = true, layoutOrder = 3, outline = 1.5,
	})
	-- Once someone has used it they know; the tip goes quiet rather than nagging forever.
	local player = Players.LocalPlayer
	local tipConnection: RBXScriptConnection? = nil
	tipConnection = player:GetAttributeChangedSignal("CursorFree"):Connect(function()
		if player:GetAttribute("CursorFree") == true then
			tip.Visible = false
			if tipConnection then
				tipConnection:Disconnect()
			end
		end
	end)

	-- The reference's speech bubble over the button.
	local bubble = Instance.new("Frame")
	bubble.Name = "Hint"
	bubble.BackgroundColor3 = WHITE
	bubble.AnchorPoint = Vector2.new(0, 1)
	bubble.Position = UDim2.new(0, 4, 0, -6)
	bubble.Size = UDim2.fromOffset(0, 32)
	bubble.AutomaticSize = Enum.AutomaticSize.X
	bubble.Parent = holder
	Components.Corner(bubble, 6)
	Components.Stroke(bubble, Theme.Colour.Outline, 2).Transparency = 0.1
	Components.Padding(bubble, nil, 12, 0)
	local hintText = Components.Label(bubble, {
		text = UserInputService.KeyboardEnabled and "Click Play Or Press J To Queue Up!" or "Tap Play To Queue Up!",
		font = Theme.Font.Bold,
		size = 19,
		colour = Theme.Colour.Outline,
		autoSize = true,
		outline = false,
	})
	hintText.AnchorPoint = Vector2.new(0, 0.5)
	hintText.Position = UDim2.fromScale(0, 0.5)
	local pointer = Instance.new("Frame")
	pointer.BackgroundColor3 = WHITE
	pointer.AnchorPoint = Vector2.new(0.5, 0.5)
	pointer.Position = UDim2.new(0, 48, 1, 1)
	pointer.Size = UDim2.fromOffset(10, 10)
	pointer.Rotation = 45
	pointer.Parent = bubble
	local bob = TweenService:Create(bubble, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = UDim2.new(0, 4, 0, -12),
	})
	bob:Play()

	-- Breathing, so the eye keeps finding it.
	local breathe = TweenService:Create(scaled(diamond), TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Scale = 1.06,
	})
	breathe:Play()

	local hover = scaled(holder)
	holder.MouseEnter:Connect(function()
		TweenService:Create(hover, Theme.Tween.Hover, { Scale = 1.1 }):Play()
	end)
	holder.MouseLeave:Connect(function()
		TweenService:Create(hover, Theme.Tween.Hover, { Scale = 1 }):Play()
	end)
	holder.MouseButton1Down:Connect(function()
		TweenService:Create(hover, Theme.Tween.Press, { Scale = 0.92 }):Play()
	end)
	holder.Activated:Connect(function()
		UISound.Play("Click")
		TweenService:Create(hover, Theme.Tween.Pop, { Scale = 1 }):Play()
		self:_dismissHint()
		self:Toggle()
	end)

	self._play, self._playDiamond, self._playLabel, self._playGlow, self._hint =
		holder, diamond, label, glow, bubble
	task.delay(150, function()
		self:_dismissHint()
	end)
end

local function buildQueueCard(self, parent: GuiObject)
	local card = Instance.new("Frame")
	card.Name = "Queue"
	card.BackgroundColor3 = Theme.Colour.Panel
	card.BackgroundTransparency = 0.2
	card.AnchorPoint = Vector2.new(1, 0)
	card.Position = UDim2.new(1, -Theme.Inset.Side, 0, Theme.Inset.Top)
	card.Size = UDim2.fromOffset(250, 76)
	card.Visible = false
	card.Parent = parent
	Components.Corner(card, Theme.Radius.Card)
	Components.Gradient(card)
	Components.Stroke(card, Theme.Colour.Level, 2.5)

	local title = Components.Label(card, {
		text = "SEARCHING",
		font = Theme.Font.Display,
		size = 26,
		colour = Theme.Colour.Level,
		align = Enum.TextXAlignment.Center,
	})
	title.Size = UDim2.new(1, 0, 0, 30)
	title.Position = UDim2.fromOffset(0, 8)

	local sub = Components.Label(card, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
	})
	sub.Size = UDim2.new(1, 0, 0, 18)
	sub.Position = UDim2.fromOffset(0, 44)

	self._queueCard, self._queueTitle, self._queueSub = card, title, sub
end

local function scoreSide(parent: GuiObject, colour: Color3, order: number, mirrored: boolean)
	local side = Instance.new("Frame")
	side.BackgroundTransparency = 1
	side.Size = UDim2.fromOffset(250, 70)
	side.LayoutOrder = order
	side.Parent = parent

	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundColor3 = Theme.Shade(colour, -0.4)
	avatar.Size = UDim2.fromOffset(58, 58)
	avatar.AnchorPoint = Vector2.new(mirrored and 1 or 0, 0)
	avatar.Position = mirrored and UDim2.new(1, 0, 0, 0) or UDim2.fromOffset(0, 0)
	avatar.ZIndex = 3
	avatar.Parent = side
	Components.Corner(avatar, 29)
	Components.Stroke(avatar, colour, 3)

	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.BackgroundColor3 = colour
	bar.AnchorPoint = Vector2.new(mirrored and 1 or 0, 0)
	bar.Position = mirrored and UDim2.new(1, -48, 0, 12) or UDim2.fromOffset(48, 12)
	bar.Size = UDim2.fromOffset(190, 34)
	bar.Parent = side
	Components.Corner(bar, 17)
	Components.Stroke(bar, Theme.Colour.Outline, 3)
	Components.Gradient(bar, Color3.fromRGB(255, 255, 255), Color3.fromRGB(140, 140, 150))

	local score = Components.Label(bar, {
		text = "0",
		font = Theme.Font.Display,
		size = 28,
		align = Enum.TextXAlignment.Center,
		outline = 2.6,
	})
	score.Size = UDim2.fromScale(1, 1)

	local name = Components.Label(side, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		align = mirrored and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left,
	})
	name.Size = UDim2.fromOffset(180, 16)
	name.AnchorPoint = Vector2.new(mirrored and 1 or 0, 0)
	name.Position = mirrored and UDim2.new(1, -62, 0, 50) or UDim2.fromOffset(62, 50)
	name.TextTruncate = Enum.TextTruncate.AtEnd

	return { avatar = avatar, bar = bar, score = score, name = name }
end

local function buildScoreboard(self, parent: GuiObject)
	local board = Instance.new("Frame")
	board.Name = "Scoreboard"
	board.BackgroundTransparency = 1
	board.AnchorPoint = Vector2.new(0.5, 0)
	board.Position = UDim2.new(0.5, 0, 0, 10)
	board.Size = UDim2.fromOffset(0, 70)
	board.AutomaticSize = Enum.AutomaticSize.X
	board.Visible = false
	board.Parent = parent
	local row = Components.List(board, Enum.FillDirection.Horizontal, 8, Enum.HorizontalAlignment.Center)
	row.VerticalAlignment = Enum.VerticalAlignment.Top

	local mine = scoreSide(board, RED, 1, false)

	local clock = Instance.new("Frame")
	clock.BackgroundTransparency = 1
	clock.Size = UDim2.fromOffset(96, 70)
	clock.LayoutOrder = 2
	clock.Parent = board
	local time = Components.Label(clock, {
		text = "3:00",
		font = Theme.Font.Display,
		size = 28,
		align = Enum.TextXAlignment.Center,
		outline = 2.6,
	})
	time.Size = UDim2.new(1, 0, 0, 32)
	time.Position = UDim2.fromOffset(0, 12)
	local hourglass = Components.Icon(clock, "⏳", 16)
	hourglass.AnchorPoint = Vector2.new(0.5, 0)
	hourglass.Position = UDim2.new(0.5, 0, 0, -6)
	local target = Components.Label(clock, {
		text = "FIRST TO 3",
		font = Theme.Font.Bold,
		size = Theme.Text.Micro,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
	})
	target.Size = UDim2.new(1, 0, 0, 14)
	target.Position = UDim2.fromOffset(0, 48)

	local theirs = scoreSide(board, BLUE, 3, true)

	self._board, self._mine, self._theirs, self._clock, self._target = board, mine, theirs, time, target
end

local function buildCountdown(self, parent: GuiObject)
	local big = Components.Label(parent :: any, {
		text = "",
		font = Theme.Font.Display,
		size = 140,
		align = Enum.TextXAlignment.Center,
		outline = 7,
	})
	big.Name = "Countdown"
	big.AnchorPoint = Vector2.new(0.5, 0.5)
	big.Position = UDim2.fromScale(0.5, 0.42)
	big.Size = UDim2.fromOffset(600, 150)
	big.Visible = false
	big.ZIndex = Theme.Layer.Overlay
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM)
	g.Rotation = 90
	g.Parent = big

	self._count, self._countGradient = big, g

	-- ROUND WON / ROUND LOST / ROUND 2, and a smaller line under it (the score, MATCH POINT).
	local banner = Components.Label(parent :: any, {
		text = "",
		face = Theme.Face.HeavyItalic,
		size = 62,
		align = Enum.TextXAlignment.Center,
		outline = 5,
	})
	banner.Name = "RoundBanner"
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	-- Below the middle, not at the top: the player who just lost the round is looking at the
	-- death card up there at that moment.
	banner.Position = UDim2.fromScale(0.5, 0.64)
	banner.Size = UDim2.fromOffset(820, 70)
	banner.Visible = false
	banner.ZIndex = Theme.Layer.Overlay
	local bannerGradient = Instance.new("UIGradient")
	bannerGradient.Rotation = 90
	bannerGradient.Parent = banner

	local sub = Components.Label(parent :: any, {
		text = "",
		face = Theme.Face.Condensed,
		size = 30,
		align = Enum.TextXAlignment.Center,
		outline = 3,
	})
	sub.Name = "RoundSub"
	sub.AnchorPoint = Vector2.new(0.5, 0.5)
	sub.Position = UDim2.fromScale(0.5, 0.705)
	sub.Size = UDim2.fromOffset(600, 34)
	sub.Visible = false
	sub.ZIndex = Theme.Layer.Overlay

	self._banner, self._bannerGradient, self._bannerSub = banner, bannerGradient, sub
end

-- The reference's VS screen: the two fighters thrown in from either side on red and blue
-- slabs, full-body, name and level under each, and a gold VS slammed between them.
local function versusSide(band: Frame, colour: Color3, left: boolean)
	local slab = Instance.new("Frame")
	slab.Name = left and "Left" or "Right"
	slab.BackgroundColor3 = colour
	slab.BorderSizePixel = 0
	slab.AnchorPoint = Vector2.new(left and 1 or 0, 0.5)
	slab.Size = UDim2.new(0.5, 80, 0, 200)
	slab.Rotation = -4
	slab.ZIndex = Theme.Layer.Overlay
	slab.Parent = band
	Components.Stroke(slab, Theme.Colour.Outline, 4)
	local fade = Instance.new("UIGradient")
	fade.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(120, 120, 130))
	fade.Rotation = left and 0 or 180
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.55),
		NumberSequenceKeypoint.new(0.6, 0.05),
		NumberSequenceKeypoint.new(1, 0),
	})
	fade.Parent = slab
	-- A bright edge along the inner side, where the two slabs meet.
	local edge = Instance.new("Frame")
	edge.BackgroundColor3 = WHITE
	edge.BorderSizePixel = 0
	edge.AnchorPoint = Vector2.new(left and 1 or 0, 0)
	edge.Position = left and UDim2.fromScale(1, 0) or UDim2.fromScale(0, 0)
	edge.Size = UDim2.new(0, 6, 1, 0)
	edge.ZIndex = Theme.Layer.Overlay + 1
	edge.Parent = slab

	-- Children of a rotated frame turn with it; the avatar and the name are turned back
	-- upright so only the slab is slanted.
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundTransparency = 1
	avatar.AnchorPoint = Vector2.new(0.5, 1)
	avatar.Position = left and UDim2.new(1, -170, 1, 10) or UDim2.new(0, 170, 1, 10)
	avatar.Size = UDim2.fromOffset(270, 270)
	avatar.ScaleType = Enum.ScaleType.Fit
	avatar.Rotation = 4
	avatar.ZIndex = Theme.Layer.Overlay + 2
	avatar.Parent = slab

	local plate = Instance.new("Frame")
	plate.Name = "Plate"
	plate.BackgroundTransparency = 1
	plate.AnchorPoint = Vector2.new(left and 1 or 0, 1)
	plate.Position = left and UDim2.new(1, -320, 1, -24) or UDim2.new(0, 320, 1, -24)
	plate.Size = UDim2.fromOffset(300, 44)
	plate.Rotation = 4
	plate.ZIndex = Theme.Layer.Overlay + 2
	plate.Parent = slab
	local badge, levelText = Components.LevelBadge(plate, 44)
	badge.AnchorPoint = Vector2.new(left and 1 or 0, 0)
	badge.Position = left and UDim2.fromScale(1, 0) or UDim2.fromScale(0, 0)
	local name = Components.Label(plate, {
		text = "",
		face = Theme.Face.HeavyItalic,
		size = 34,
		align = left and Enum.TextXAlignment.Right or Enum.TextXAlignment.Left,
		outline = 3,
	})
	name.AnchorPoint = Vector2.new(left and 1 or 0, 0)
	name.Position = left and UDim2.new(1, -50, 0, 0) or UDim2.fromOffset(50, 0)
	name.Size = UDim2.new(1, -50, 1, 0)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	for _, d in ipairs(plate:GetDescendants()) do
		if d:IsA("GuiObject") then
			d.ZIndex = Theme.Layer.Overlay + 3
		end
	end

	return { slab = slab, avatar = avatar, name = name, badge = badge, level = levelText }
end

local function buildVersus(self, parent: GuiObject)
	local band = Instance.new("Frame")
	band.Name = "VersusSplash"
	band.BackgroundTransparency = 1
	band.AnchorPoint = Vector2.new(0.5, 0.5)
	band.Position = UDim2.fromScale(0.5, 0.5)
	band.Size = UDim2.new(1, 0, 0, 220)
	band.Visible = false
	band.ZIndex = Theme.Layer.Overlay
	band.Parent = parent

	local left = versusSide(band, RED, true)
	local right = versusSide(band, BLUE, false)

	local vs = Components.Label(band, {
		text = "VS",
		face = Theme.Face.HeavyItalic,
		size = 120,
		align = Enum.TextXAlignment.Center,
		outline = 7,
	})
	vs.AnchorPoint = Vector2.new(0.5, 0.5)
	vs.Position = UDim2.fromScale(0.5, 0.5)
	vs.Size = UDim2.fromOffset(260, 130)
	vs.ZIndex = Theme.Layer.Overlay + 5
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM)
	g.Rotation = 90
	g.Parent = vs

	-- Where the fight is: the map's name on a dark plate under the slabs.
	local plate = Instance.new("Frame")
	plate.Name = "MapPlate"
	plate.BackgroundColor3 = Color3.fromRGB(16, 17, 22)
	plate.BackgroundTransparency = 0.1
	plate.AnchorPoint = Vector2.new(0.5, 0)
	plate.Position = UDim2.new(0.5, 0, 1, 18)
	plate.Size = UDim2.fromOffset(420, 68)
	plate.ZIndex = Theme.Layer.Overlay + 4
	plate.Parent = band
	Components.Corner(plate, 12)
	Components.Stroke(plate, Theme.Colour.Outline, 3)
	local mapName = Components.Label(plate, {
		text = "",
		face = Theme.Face.HeavyItalic,
		size = 34,
		align = Enum.TextXAlignment.Center,
		outline = 3,
	})
	mapName.Position = UDim2.fromOffset(0, 4)
	mapName.Size = UDim2.new(1, 0, 0, 38)
	mapName.ZIndex = Theme.Layer.Overlay + 5
	local mapGold = Instance.new("UIGradient")
	mapGold.Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM)
	mapGold.Rotation = 90
	mapGold.Parent = mapName
	local tagline = Components.Label(plate, {
		text = "",
		size = 17,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
		outline = 2,
	})
	tagline.Position = UDim2.fromOffset(0, 42)
	tagline.Size = UDim2.new(1, 0, 0, 20)
	tagline.ZIndex = Theme.Layer.Overlay + 5

	self._vsBand, self._vsLeft, self._vsRight, self._vsText = band, left, right, vs
	self._vsMap, self._vsMapName, self._vsTagline = plate, mapName, tagline
end

-- -------------------------------------------------------------- results --

local function statTile(parent: GuiObject, caption: string, value: string, colour: Color3, order: number)
	local tile = Instance.new("Frame")
	tile.BackgroundColor3 = Color3.fromRGB(20, 21, 26)
	tile.BackgroundTransparency = 0.2
	tile.Size = UDim2.fromOffset(122, 58)
	tile.LayoutOrder = order
	tile.Parent = parent
	Components.Corner(tile, 8)
	Components.Stroke(tile, Theme.Colour.Outline, 2).Transparency = 0.3
	local v = Components.Label(tile, {
		text = value,
		font = Theme.Font.Display,
		size = 28,
		colour = colour,
		align = Enum.TextXAlignment.Center,
		outline = 2.4,
	})
	v.Size = UDim2.new(1, 0, 0, 32)
	v.Position = UDim2.fromOffset(0, 4)
	local c = Components.Label(tile, {
		text = caption,
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
	})
	c.Size = UDim2.new(1, 0, 0, 16)
	c.Position = UDim2.fromOffset(0, 36)
end

local function resultColumn(parent: GuiObject, info, order: number)
	local column = Instance.new("Frame")
	column.BackgroundTransparency = 1
	column.Size = UDim2.fromOffset(260, 470)
	column.LayoutOrder = order
	column.Parent = parent

	local avatar = Instance.new("ImageLabel")
	avatar.BackgroundTransparency = 1
	avatar.Image = fullBody(info.userId)
	avatar.Size = UDim2.fromOffset(260, 260)
	avatar.ScaleType = Enum.ScaleType.Fit
	avatar.Parent = column

	if info.winner then
		local crown = Components.Icon(column, "👑", 40)
		crown.AnchorPoint = Vector2.new(0.5, 0)
		crown.Position = UDim2.new(0.5, 0, 0, -10)
		crown.Rotation = -10
		crown.ZIndex = 3
	end

	-- The name plate: a level diamond and the name on a bar, gold for you as in the
	-- reference's highlighted player.
	local plate = Instance.new("Frame")
	plate.BackgroundColor3 = info.me and Color3.fromRGB(255, 208, 90) or Color3.fromRGB(236, 238, 244)
	plate.Size = UDim2.fromOffset(260, 40)
	plate.Position = UDim2.fromOffset(0, 262)
	plate.Parent = column
	Components.Corner(plate, 8)
	Components.Stroke(plate, Theme.Colour.Outline, 2.5)
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.8, 0.1),
		NumberSequenceKeypoint.new(1, 0.5),
	})
	fade.Parent = plate
	local badge, levelText = Components.LevelBadge(plate, 38)
	badge.Position = UDim2.fromOffset(2, 1)
	levelText.Text = info.level and tostring(info.level) or "?"
	local name = Components.Label(plate, {
		text = info.name,
		font = Theme.Font.Bold,
		size = 22,
		outline = 2,
	})
	name.Size = UDim2.new(1, -52, 1, 0)
	name.Position = UDim2.fromOffset(46, 0)
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local grid = Instance.new("Frame")
	grid.BackgroundTransparency = 1
	grid.Size = UDim2.fromOffset(260, 124)
	grid.Position = UDim2.fromOffset(0, 310)
	grid.Parent = column
	local layout = Components.Grid(grid, Vector2.new(122, 58), 8)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	statTile(grid, "Eliminations", tostring(info.kills), Theme.Colour.Kill, 1)
	statTile(grid, "Deaths", tostring(info.deaths), Theme.Colour.Kill, 2)
	statTile(grid, "Damage Dealt", tostring(info.dealt), WHITE, 3)
	statTile(grid, "Damage Taken", tostring(info.taken), WHITE, 4)

	local kdr = Components.Label(column, {
		text = string.format("%.2f KDR", info.kills / math.max(info.deaths, 1)),
		face = Theme.Face.Condensed,
		size = 28,
		align = Enum.TextXAlignment.Center,
		outline = 2.6,
	})
	kdr.Size = UDim2.new(1, 0, 0, 32)
	kdr.Position = UDim2.fromOffset(0, 438)

	return column
end

local REASONS = {
	score = "First to the target",
	time = "Time's up",
	forfeit = "Forfeit",
	["opponent left"] = "Opponent left",
}

function Duel:_showResults(state)
	if self._results then
		self._results:Destroy()
		self._results = nil
	end
	local player = Players.LocalPlayer
	local won, draw = state.won == true, state.draw == true

	local gui = Instance.new("ScreenGui")
	gui.Name = "DuelResults"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.DisplayOrder = 40
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = player:WaitForChild("PlayerGui")
	local unbind = Components.BindScale(gui)
	self._results = gui
	gui.Destroying:Connect(unbind)

	local backdrop = Instance.new("TextButton")
	backdrop.Name = "Backdrop"
	backdrop.AutoButtonColor = false
	backdrop.Text = ""
	backdrop.BackgroundColor3 = Theme.Colour.Scrim
	backdrop.BackgroundTransparency = 1
	backdrop.Size = UDim2.fromScale(1, 1)
	backdrop.Parent = gui
	local dark = Instance.new("UIGradient")
	dark.Transparency = NumberSequence.new(0.6, 0.1)
	dark.Rotation = 90
	dark.Parent = backdrop
	TweenService:Create(backdrop, Theme.Tween.Value, { BackgroundTransparency = 0 }):Play()

	local headline = Components.Label(backdrop, {
		text = draw and "DRAW" or (won and "VICTORY" or "DEFEAT"),
		font = Theme.Font.Display,
		size = 76,
		align = Enum.TextXAlignment.Center,
		outline = 5,
	})
	headline.AnchorPoint = Vector2.new(0.5, 0)
	headline.Position = UDim2.new(0.5, 0, 0, 36)
	headline.Size = UDim2.fromOffset(700, 84)
	local hg = Instance.new("UIGradient")
	hg.Rotation = 90
	hg.Color = draw and ColorSequence.new(WHITE, Color3.fromRGB(170, 176, 190))
		or won and ColorSequence.new(GOLD_TOP, GOLD_BOTTOM)
		or ColorSequence.new(Color3.fromRGB(255, 120, 120), Color3.fromRGB(190, 20, 30))
	hg.Parent = headline
	slam(headline, 2.2, 0.4)

	local because = REASONS[tostring(state.reason)] or tostring(state.reason or "")
	if type(state.map) == "string" and state.map ~= "" then
		because = because ~= "" and (because .. "   ·   " .. state.map) or state.map
	end
	local reason = Components.Label(backdrop, {
		text = because,
		font = Theme.Font.Bold,
		size = 22,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
	})
	reason.AnchorPoint = Vector2.new(0.5, 0)
	reason.Position = UDim2.new(0.5, 0, 0, 118)
	reason.Size = UDim2.fromOffset(600, 26)

	local row = Instance.new("Frame")
	row.BackgroundTransparency = 1
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, 150)
	row.Size = UDim2.fromOffset(0, 470)
	row.AutomaticSize = Enum.AutomaticSize.X
	row.Parent = backdrop
	Components.List(row, Enum.FillDirection.Horizontal, 60, Enum.HorizontalAlignment.Center)

	local you = tonumber(state.you) or 0
	local them = tonumber(state.them) or 0
	local opponentId = tonumber(state.opponentUserId) or 0
	local mine = resultColumn(row, {
		userId = player.UserId, name = player.DisplayName, level = levelOf(player.UserId),
		kills = you, deaths = them, dealt = tonumber(state.dealt) or 0, taken = tonumber(state.taken) or 0,
		me = true, winner = won,
	}, 1)
	local other = resultColumn(row, {
		userId = opponentId, name = tostring(state.opponentName or "?"), level = levelOf(opponentId),
		kills = them, deaths = you, dealt = tonumber(state.theirDealt) or 0, taken = tonumber(state.theirTaken) or 0,
		me = false, winner = not won and not draw,
	}, 2)
	-- The columns rise in one after the other.
	for i, column in ipairs({ mine, other }) do
		local s = scaled(column)
		s.Scale = 0.6
		task.delay(0.15 * i, function()
			TweenService:Create(s, TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
		end)
	end

	local foot = Components.Label(backdrop, {
		text = "Click anywhere to continue",
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
	})
	foot.AnchorPoint = Vector2.new(0.5, 1)
	foot.Position = UDim2.new(0.5, 0, 1, -18)
	foot.Size = UDim2.fromOffset(500, 20)

	if won then
		self:_confetti(backdrop)
		UISound.Sequence("Ring", { 1, 1.26, 1.5, 2 }, 0.11)
	elseif draw then
		UISound.Play("Slam", 0.9)
	else
		UISound.Play("Clunk", 0.45)
		UISound.Play("Slam", 0.6, 0.8)
	end

	local function close()
		if self._results ~= gui then
			return
		end
		self._results = nil
		TweenService:Create(backdrop, Theme.Tween.Close, { BackgroundTransparency = 1 }):Play()
		for _, d in ipairs(gui:GetDescendants()) do
			if d:IsA("TextLabel") then
				fadeText(d, 1, 0.2)
			elseif d:IsA("ImageLabel") then
				TweenService:Create(d, Theme.Tween.Close, { ImageTransparency = 1, BackgroundTransparency = 1 }):Play()
			elseif d:IsA("Frame") then
				TweenService:Create(d, Theme.Tween.Close, { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, Theme.Tween.Close, { Transparency = 1 }):Play()
			end
		end
		task.delay(0.25, function()
			gui:Destroy()
		end)
	end
	backdrop.Activated:Connect(close)
	task.delay(RESULTS_TIME, close)
end

-- Paper falling over a win. Plain frames on tweens: a few dozen of them, alive for a few
-- seconds, parented to the results screen so closing it takes them all away.
local CONFETTI = {
	Color3.fromRGB(255, 214, 40), Color3.fromRGB(255, 70, 90), Color3.fromRGB(60, 200, 255),
	Color3.fromRGB(80, 230, 110), Color3.fromRGB(200, 90, 255), Color3.fromRGB(255, 255, 255),
}

function Duel:_confetti(parent: GuiObject)
	local rng = Random.new()
	for i = 1, 70 do
		local bit = Instance.new("Frame")
		bit.BorderSizePixel = 0
		bit.BackgroundColor3 = CONFETTI[rng:NextInteger(1, #CONFETTI)]
		bit.Size = UDim2.fromOffset(rng:NextInteger(7, 13), rng:NextInteger(12, 20))
		bit.AnchorPoint = Vector2.new(0.5, 0.5)
		bit.Position = UDim2.new(rng:NextNumber(0.02, 0.98), 0, 0, -rng:NextInteger(10, 260))
		bit.Rotation = rng:NextNumber(0, 360)
		bit.ZIndex = 20
		bit.Parent = parent
		local fall = rng:NextNumber(2.6, 4.4)
		local drift = rng:NextInteger(-120, 120)
		local info = TweenInfo.new(fall, Enum.EasingStyle.Sine, Enum.EasingDirection.In, 0, false, i * 0.012)
		TweenService:Create(bit, info, {
			Position = bit.Position + UDim2.new(0, drift, 1.1, 300),
			Rotation = bit.Rotation + rng:NextNumber(-540, 540),
		}):Play()
		task.delay(fall + i * 0.012 + 0.1, function()
			bit:Destroy()
		end)
	end
end

-- ------------------------------------------------------------------- api --

function Duel.new(parent: GuiObject, remotes, hooks: Hooks?)
	local self = setmetatable({}, Duel)
	self._remotes = remotes
	self._hooks = hooks or {}
	self._mode = "idle"            -- idle | queue | countdown | live
	self._hidden = false

	buildPlay(self, parent)
	buildQueueCard(self, parent)
	buildScoreboard(self, parent)
	buildCountdown(self, parent)
	buildVersus(self, parent)

	if remotes.matchUpdate then
		remotes.matchUpdate.OnClientEvent:Connect(function(state)
			self:_render(state)
		end)
	end

	-- Ask once on join, so a rejoin mid-queue shows the right thing.
	task.spawn(function()
		local ok, state = pcall(function()
			return remotes.matchAction:InvokeServer("state")
		end)
		if ok then
			self:_render(state)
		end
	end)

	self:_apply()
	return self
end

function Duel:_dismissHint()
	local bubble = self._hint
	if not bubble then
		return
	end
	self._hint = nil
	bubble:Destroy()
end

--- Show exactly what the current mode calls for.
function Duel:_apply()
	local mode = self._mode
	local hidden = self._hidden
	local playVisible = not hidden and not self._playBlocked and (mode == "idle" or mode == "queue")
	self._play.Visible = playVisible
	self._queueCard.Visible = not hidden and mode == "queue"
	local boardVisible = not hidden and (mode == "live" or (mode == "countdown" and (self._round or 1) > 1))
	if self._board.Visible ~= boardVisible then
		self._board.Visible = boardVisible
		if self._hooks.onScoreboard then
			self._hooks.onScoreboard(boardVisible)
		end
	end
	if self._playShown ~= playVisible then
		self._playShown = playVisible
		if self._hooks.onPlayVisible then
			self._hooks.onPlayVisible(playVisible)
		end
	end

	-- Queued: the diamond turns gold and becomes the cancel button.
	local queued = mode == "queue"
	self._playDiamond.BackgroundColor3 = queued and Theme.Colour.Level or Theme.Colour.Accent
	self._playGlow.BackgroundColor3 = queued and Theme.Colour.Level or Theme.Colour.Accent
	self._playLabel.Text = queued and "CANCEL" or "PLAY"
	self._playLabel.TextSize = queued and 24 or 34
end

local VS_HOLD = 2.1

--- Throw the VS screen up for the opening count of a bout, and take it down again.
function Duel:_splash(state)
	local player = Players.LocalPlayer
	local opponentId = tonumber(state.opponentUserId) or 0
	local left, right = self._vsLeft, self._vsRight
	left.avatar.Image = fullBody(player.UserId)
	left.name.Text = player.DisplayName
	local myLevel = levelOf(player.UserId)
	left.badge.Visible = myLevel ~= nil
	left.level.Text = myLevel and tostring(myLevel) or ""
	right.avatar.Image = fullBody(opponentId)
	right.name.Text = tostring(state.opponentName or "?")
	local theirLevel = levelOf(opponentId)
	right.badge.Visible = theirLevel ~= nil
	right.level.Text = theirLevel and tostring(theirLevel) or ""
	local mapName = type(state.map) == "string" and state.map or nil
	self._vsMap.Visible = mapName ~= nil
	self._vsMapName.Text = mapName or ""
	self._vsTagline.Text = type(state.mapTagline) == "string" and string.upper(state.mapTagline) or ""

	local token = {}
	self._vsToken = token
	self._vsUp = true
	self._vsBand.Visible = true
	local inInfo = TweenInfo.new(0.38, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
	left.slab.Position = UDim2.new(-0.1, 0, 0.5, 0)
	right.slab.Position = UDim2.new(1.1, 0, 0.5, 0)
	TweenService:Create(left.slab, inInfo, { Position = UDim2.new(0.5, 6, 0.5, 0) }):Play()
	TweenService:Create(right.slab, inInfo, { Position = UDim2.new(0.5, -6, 0.5, 0) }):Play()
	UISound.Play("Whoosh", 0.9)
	self._vsText.TextTransparency = 1
	task.delay(0.22, function()
		if self._vsToken ~= token then
			return
		end
		fadeText(self._vsText, 0, 0.01)
		slam(self._vsText, 3, 0.34)
		UISound.Play("Slam", 0.75)
	end)

	task.delay(VS_HOLD, function()
		if self._vsToken ~= token then
			return
		end
		self:_hideSplash(true)
	end)
end

function Duel:_hideSplash(animated: boolean)
	self._vsToken = nil
	if not self._vsUp then
		return
	end
	self._vsUp = false
	local band = self._vsBand
	if not animated then
		band.Visible = false
		return
	end
	local outInfo = TweenInfo.new(0.3, Enum.EasingStyle.Quart, Enum.EasingDirection.In)
	UISound.Play("Whoosh", 1.25, 0.6)
	TweenService:Create(self._vsLeft.slab, outInfo, { Position = UDim2.new(-0.1, 0, 0.5, 0) }):Play()
	TweenService:Create(self._vsRight.slab, outInfo, { Position = UDim2.new(1.1, 0, 0.5, 0) }):Play()
	fadeText(self._vsText, 1, 0.2)
	task.delay(0.32, function()
		if not self._vsUp then
			band.Visible = false
		end
	end)
	-- The count kept running under the splash; show where it has got to.
	if self._mode == "countdown" and self._pendingCount then
		self:_showCount(self._pendingCount)
	end
end

function Duel:_showCount(n: number)
	self._pendingCount = nil
	UISound.Play("Tick", math.clamp(1.25 - n * 0.1, 0.8, 1.3))
	self._count.Visible = true
	self._count.Text = tostring(n)
	self._countGradient.Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM)
	fadeText(self._count, 0, 0.01)
	slam(self._count, 2.4, 0.3)
end

--- A big call across the top of the screen that clears itself.
function Duel:_banner(text: string, top: Color3, bottom: Color3, subText: string?, subColour: Color3?, hold: number?)
	local token = {}
	self._bannerToken = token
	self._banner.Text = text
	self._bannerGradient.Color = ColorSequence.new(top, bottom)
	self._banner.Visible = true
	fadeText(self._banner, 0, 0.01)
	slam(self._banner, 1.9, 0.32)
	self._bannerSub.Visible = subText ~= nil
	if subText then
		self._bannerSub.Text = subText
		self._bannerSub.TextColor3 = subColour or WHITE
		fadeText(self._bannerSub, 0, 0.01)
	end
	task.delay(hold or 1.6, function()
		if self._bannerToken ~= token then
			return
		end
		fadeText(self._banner, 1, 0.3)
		fadeText(self._bannerSub, 1, 0.3)
		task.delay(0.32, function()
			if self._bannerToken == token then
				self._banner.Visible = false
				self._bannerSub.Visible = false
			end
		end)
	end)
end

function Duel:_clearBanner()
	self._bannerToken = nil
	self._banner.Visible = false
	self._bannerSub.Visible = false
end

function Duel:_countdown(state)
	local n = tonumber(state.countdown) or 0
	local round = tonumber(state.round) or 1
	local entering = self._mode ~= "countdown"
	self._round = round

	if entering then
		self._lastCount = nil
		if round <= 1 then
			self:_splash(state)
		else
			-- Between rounds: ROUND N, and whether it could end here.
			local target = tonumber(state.target) or 3
			local you = tonumber(state.you) or 0
			local them = tonumber(state.them) or 0
			local sub, colour = nil, nil
			if you == target - 1 and them == target - 1 then
				sub, colour = "FINAL ROUND", Theme.Colour.Level
			elseif you == target - 1 or them == target - 1 then
				sub, colour = "MATCH POINT", you == target - 1 and Theme.Colour.Accent or Theme.Colour.Danger
			end
			self:_banner(string.format("ROUND %d", round), WHITE, Color3.fromRGB(190, 196, 210), sub, colour,
				MATCH_ROUND_HOLD)
			UISound.Play("Slam", 0.9)
		end
	end

	if n > 0 and n ~= self._lastCount then
		self._lastCount = n
		if self._vsUp then
			self._pendingCount = n      -- shown when the splash clears
		else
			self:_showCount(n)
		end
	end
end

function Duel:_fight()
	self:_hideSplash(false)
	UISound.Play("Tick", 1.7)
	UISound.Play("Slam", 1.1)
	self._lastCount = nil
	self._count.Visible = true
	self._count.Text = "FIGHT!"
	self._countGradient.Color = ColorSequence.new(Color3.fromRGB(200, 255, 200), Color3.fromRGB(40, 200, 80))
	fadeText(self._count, 0, 0.01)
	slam(self._count, 2.8, 0.35)
	local token = {}
	self._fightToken = token
	task.delay(0.9, function()
		if self._fightToken ~= token then
			return
		end
		fadeText(self._count, 1, 0.3)
		task.delay(0.32, function()
			if self._fightToken == token then
				self._count.Visible = false
			end
		end)
	end)
end

function Duel:_scoreboard(state)
	local player = Players.LocalPlayer
	local you = tonumber(state.you) or 0
	local them = tonumber(state.them) or 0
	local opponentId = tonumber(state.opponentUserId) or 0

	self._mine.avatar.Image = headshot(player.UserId)
	self._mine.name.Text = player.DisplayName
	self._theirs.avatar.Image = headshot(opponentId)
	self._theirs.name.Text = tostring(state.opponentName or "?")

	local scored = self._lastYou ~= nil and you > self._lastYou
	local conceded = self._lastThem ~= nil and them > self._lastThem
	if scored then
		slam(self._mine.bar, 1.25)
	end
	if conceded then
		slam(self._theirs.bar, 1.25)
	end
	-- The last point goes to the results screen instead of a banner.
	local target = tonumber(state.target) or 3
	if (scored or conceded) and you < target and them < target then
		local line = string.format("%d  -  %d", you, them)
		if scored and conceded then
			self:_banner("TRADED", GOLD_TOP, GOLD_BOTTOM, line)
			UISound.Play("Slam", 1)
		elseif scored then
			self:_banner("ROUND WON", GOLD_TOP, GOLD_BOTTOM, line)
			UISound.Sequence("Ring", { 1.1, 1.4 }, 0.1)
		else
			self:_banner("ROUND LOST", Color3.fromRGB(255, 130, 130), Color3.fromRGB(200, 20, 30), line)
			UISound.Play("Clunk", 0.55)
		end
	end
	self._lastYou, self._lastThem = you, them
	self._mine.score.Text = tostring(you)
	self._theirs.score.Text = tostring(them)

	local left = tonumber(state.secondsLeft) or 0
	self._clock.Text = string.format("%d:%02d", math.floor(left / 60), left % 60)
	self._clock.TextColor3 = left <= 15 and Theme.Colour.Danger or WHITE
	self._target.Text = string.format("FIRST TO %d", tonumber(state.target) or 3)
end

function Duel:_render(state)
	if type(state) ~= "table" then
		return
	end
	if state.in_match then
		if state.state == "countdown" then
			self:_countdown(state)
			self._mode = "countdown"
			-- Between rounds the scoreboard stays up; only the opening count hides it.
			if (tonumber(state.round) or 1) > 1 then
				self:_scoreboard(state)
			end
		elseif state.state == "live" then
			if self._mode == "countdown" then
				self:_fight()
			end
			self._mode = "live"
			self:_scoreboard(state)
		elseif state.state == "over" then
			if self._mode ~= "idle" then
				self._mode = "idle"
				self._lastYou, self._lastThem = nil, nil
				self._count.Visible = false
				self:_hideSplash(false)
				self:_clearBanner()
				self:_showResults(state)
			end
		end
	elseif state.in_queue then
		self._mode = "queue"
		self._queueSub.Text = string.format("%d in queue  ·  click CANCEL or press J", tonumber(state.queued) or 1)
	else
		self._mode = "idle"
	end
	self:_apply()
end

--- Ask to join the queue, or to leave whatever we are in. One button does both, because
--- the answer to "what does it do right now" should always be "the opposite of what is on
--- screen".
function Duel:Toggle()
	local action = self._mode == "idle" and "queue" or "leave"
	task.spawn(function()
		local ok, state = pcall(function()
			self._remotes.matchAction:InvokeServer(action)
			return self._remotes.matchAction:InvokeServer("state")
		end)
		if ok then
			self:_render(state)
		end
	end)
end

--- PLAY steps aside while you are dead -- the death card has the middle of the screen --
--- without hiding a live duel's scoreboard the way SetVisible would.
function Duel:SetPlayAllowed(allowed: boolean)
	self._playBlocked = not allowed
	self:_apply()
end

function Duel:SetVisible(visible: boolean)
	self._hidden = not visible
	self:_apply()
end

function Duel:Destroy()
	self._play:Destroy()
	self._queueCard:Destroy()
	self._board:Destroy()
	self._count:Destroy()
	self._banner:Destroy()
	self._bannerSub:Destroy()
	self._vsBand:Destroy()
	if self._results then
		self._results:Destroy()
	end
end

return Duel
