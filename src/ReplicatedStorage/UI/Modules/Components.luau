--!strict
-- Components: the small set of parts every screen is assembled from.
--
-- Here a panel is a function. If the market and the inventory both call Components.Card
-- they cannot drift apart, and fixing a card fixes both.
--
-- Nothing here polls. Hover and press are input-driven, values tween and stop, and every
-- component returns a Destroy that disconnects what it made, so a closed screen leaves
-- nothing running.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local UISound = require(script.Parent.UISound)

local Components = {}

local WHITE = Color3.new(1, 1, 1)

-- --------------------------------------------------------------- primitives --

local function corner(parent: GuiObject, radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end
Components.Corner = corner

--- A border around a frame. (Text outlines are Components.Outline.)
local function stroke(parent: GuiObject, colour: Color3?, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Name = "Edge"
	s.Color = colour or Theme.Colour.Stroke
	s.Thickness = thickness or Theme.Stroke.Hair
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = parent
	return s
end
Components.Stroke = stroke

--- The dark edge around text -- the thing that lets type float over the world with nothing
--- behind it. Contextual mode strokes the glyphs, not the label's box.
local function outline(label: GuiObject, thickness: number?, colour: Color3?, transparency: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Name = "TextOutline"
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Color = colour or Theme.Colour.Outline
	s.Thickness = thickness or 1.5
	s.Transparency = transparency or 0.1
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = label
	return s
end
Components.Outline = outline

--- A vertical light-to-dark sheen. UIGradient multiplies the background colour, so white at
--- the top keeps the colour and a grey at the bottom darkens it -- one gradient works on any
--- fill, which is what lets rarity cards and buttons share it.
local function gradient(parent: GuiObject, top: Color3?, bottom: Color3?, rotation: number?): UIGradient
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top or WHITE, bottom or Color3.fromRGB(170, 170, 176))
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end
Components.Gradient = gradient

local function padding(parent: GuiObject, all: number?, x: number?, y: number?): UIPadding
	local p = Instance.new("UIPadding")
	local px, py = x or all or 0, y or all or 0
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.PaddingTop = UDim.new(0, py)
	p.PaddingBottom = UDim.new(0, py)
	p.Parent = parent
	return p
end
Components.Padding = padding

local function list(parent: GuiObject, direction: Enum.FillDirection, gap: number, align: Enum.HorizontalAlignment?): UIListLayout
	local l = Instance.new("UIListLayout")
	l.FillDirection = direction
	l.Padding = UDim.new(0, gap)
	-- Always explicit. The default is SortOrder.Name, which silently ignores LayoutOrder.
	l.SortOrder = Enum.SortOrder.LayoutOrder
	l.HorizontalAlignment = align or Enum.HorizontalAlignment.Left
	l.VerticalAlignment = Enum.VerticalAlignment.Top
	l.Parent = parent
	return l
end
Components.List = list

function Components.Grid(parent: GuiObject, cell: Vector2, gap: number): UIGridLayout
	local g = Instance.new("UIGridLayout")
	g.CellSize = UDim2.fromOffset(cell.X, cell.Y)
	g.CellPadding = UDim2.fromOffset(gap, gap)
	g.SortOrder = Enum.SortOrder.LayoutOrder
	g.Parent = parent
	return g
end

-- ------------------------------------------------------------------- text --

export type LabelOptions = {
	text: string?, font: Enum.Font?, size: number?, colour: Color3?,
	align: Enum.TextXAlignment?, caps: boolean?, wrap: boolean?,
	layoutOrder: number?, autoSize: boolean?, outline: (boolean | number)?, face: Font?,
}

function Components.Label(parent: GuiObject, options: LabelOptions): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = options.text or ""
	l.Font = options.font or Theme.Font.Bold
	l.TextSize = options.size or Theme.Text.Body
	l.TextColor3 = options.colour or Theme.Colour.Text
	l.TextXAlignment = options.align or Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.TextWrapped = options.wrap == true
	l.Size = UDim2.new(1, 0, 0, (options.size or Theme.Text.Body) + 6)
	l.LayoutOrder = options.layoutOrder or 0

	if options.caps then
		l.Text = string.upper(l.Text)
		l.Font = Theme.Font.Bold
		l.TextSize = options.size or Theme.Text.Micro
		l.TextColor3 = options.colour or Theme.Colour.TextDim
	end
	if options.face then
		l.FontFace = options.face
	end

	if options.autoSize then
		l.AutomaticSize = Enum.AutomaticSize.XY
		l.Size = UDim2.fromOffset(0, 0)
	end

	-- Outlined by default, sized to the text. Pass outline = false for type sitting on a
	-- solid light surface, or a number to force a thickness.
	if options.outline ~= false then
		local thickness = type(options.outline) == "number" and options.outline or Theme.OutlineFor(l.TextSize)
		outline(l, thickness)
	end

	l.Parent = parent
	return l
end

--- An emoji used as an icon. Never outlined: a stroke around a colour glyph reads as a
--- sticker border rather than an icon.
function Components.Icon(parent: GuiObject, glyph: string, size: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = "Icon"
	l.BackgroundTransparency = 1
	l.Text = glyph
	l.Font = Theme.Font.Bold
	l.TextSize = size
	l.TextColor3 = WHITE
	l.Size = UDim2.fromOffset(size + 6, size + 6)
	l.TextXAlignment = Enum.TextXAlignment.Center
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.Parent = parent
	return l
end

-- ------------------------------------------------------------------ panel --

export type PanelOptions = {
	size: UDim2?, position: UDim2?, anchor: Vector2?, colour: Color3?,
	radius: number?, stroked: boolean?, pad: number?, layoutOrder: number?, name: string?,
	transparency: number?, sheen: boolean?,
}

function Components.Panel(parent: GuiObject, options: PanelOptions): Frame
	local f = Instance.new("Frame")
	f.Name = options.name or "Panel"
	f.BackgroundColor3 = options.colour or Theme.Colour.Panel
	f.BackgroundTransparency = options.transparency or 0
	f.BorderSizePixel = 0
	f.Size = options.size or UDim2.fromScale(1, 1)
	f.Position = options.position or UDim2.fromScale(0, 0)
	f.AnchorPoint = options.anchor or Vector2.zero
	f.LayoutOrder = options.layoutOrder or 0
	corner(f, options.radius or Theme.Radius.Panel)
	if options.stroked ~= false then
		stroke(f, Theme.Colour.Outline, 2).Transparency = 0.35
	end
	if options.sheen ~= false then
		gradient(f, WHITE, Color3.fromRGB(150, 150, 158))
	end
	if options.pad then
		padding(f, options.pad)
	end
	f.Parent = parent
	return f
end

-- ------------------------------------------------ interaction (hover/press) --

-- One place that knows how a pressable thing behaves, so a market card and a HUD button feel
-- identical. Returns a disconnect, plus a setter for the RESTING colour.
--
-- Selection moves the resting colour itself rather than painting BackgroundColor3, which the
-- hover logic also owns -- two writers on one property and the highlight dies the first time
-- the mouse crosses it.
local function makeInteractive(button: GuiButton, visual: GuiObject, options: { lift: boolean?, tint: Color3?, base: Color3? }): (() -> (), (Color3, Color3?) -> ())
	local base = options.base or visual.BackgroundColor3
	local tint = options.tint or Theme.Colour.Hover
	local lift = options.lift ~= false
	local baseOffset = visual.Position

	local connections: { RBXScriptConnection } = {}
	local function on(signal: RBXScriptSignal, fn: (...any) -> ())
		table.insert(connections, signal:Connect(fn))
	end

	local function goTo(colour: Color3, dy: number, info: TweenInfo)
		TweenService:Create(visual, info, { BackgroundColor3 = colour }):Play()
		if lift then
			TweenService:Create(visual, info, { Position = baseOffset + UDim2.fromOffset(0, dy) }):Play()
		end
	end

	on(button.MouseEnter, function()
		goTo(tint, -Theme.Motion.HoverLift, Theme.Tween.Hover)
	end)
	on(button.MouseLeave, function()
		goTo(base, 0, Theme.Tween.Hover)
	end)
	on(button.MouseButton1Down, function()
		goTo(tint, Theme.Motion.PressSink, Theme.Tween.Press)
	end)
	on(button.MouseButton1Up, function()
		goTo(tint, -Theme.Motion.HoverLift, Theme.Tween.Press)
	end)
	-- Every button clicks. Activated rather than the mouse events, so a tap and a gamepad
	-- press click too.
	on(button.Activated, function()
		UISound.Play("Click")
	end)

	-- Touch never fires MouseEnter, so a phone would otherwise get no press feedback at all.
	on(button.InputBegan, function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			goTo(tint, Theme.Motion.PressSink, Theme.Tween.Press)
		end
	end)
	on(button.InputEnded, function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.Touch then
			goTo(base, 0, Theme.Tween.Press)
		end
	end)

	local function disconnect()
		for _, c in ipairs(connections) do
			c:Disconnect()
		end
		table.clear(connections)
	end

	local function setBase(colour: Color3, hoverColour: Color3?)
		base = colour
		tint = hoverColour or colour:Lerp(WHITE, 0.12)
		visual.BackgroundColor3 = colour
	end

	return disconnect, setBase
end
Components.MakeInteractive = makeInteractive

-- ----------------------------------------------------------------- button --

export type ButtonOptions = {
	text: string?, primary: boolean?, danger: boolean?, size: UDim2?, position: UDim2?,
	anchor: Vector2?, radius: number?, layoutOrder: number?, textSize: number?,
	onActivated: (() -> ())?, name: string?, colour: Color3?,
}

--- A chunky button: a sheen from top to bottom, a dark rim, and outlined type -- the way
--- the reference "+" and DUEL buttons read as physical things you can press.
function Components.Button(parent: GuiObject, options: ButtonOptions)
	local primary = options.primary == true
	local danger = options.danger == true

	local base = options.colour
		or primary and Theme.Colour.Accent
		or danger and Theme.Colour.Danger
		or Theme.Colour.PanelRaised
	local hover = base:Lerp(WHITE, 0.14)
	local fg = Theme.Colour.Text

	local b = Instance.new("TextButton")
	b.Name = options.name or "Button"
	b.AutoButtonColor = false
	b.BackgroundColor3 = base
	b.BorderSizePixel = 0
	b.Size = options.size or UDim2.new(1, 0, 0, Theme.Size.ButtonHeight)
	b.Position = options.position or UDim2.fromScale(0, 0)
	b.AnchorPoint = options.anchor or Vector2.zero
	b.LayoutOrder = options.layoutOrder or 0
	b.Font = Theme.Font.Bold
	b.Text = options.text or ""
	b.TextSize = options.textSize or Theme.Text.Body
	b.TextColor3 = fg
	b.Parent = parent

	corner(b, options.radius or Theme.Radius.Small)
	local rim = stroke(b, Theme.Colour.Outline, 2)
	rim.Transparency = 0.2
	gradient(b, WHITE, Color3.fromRGB(176, 176, 182))
	local textEdge = outline(b, Theme.OutlineFor(b.TextSize))

	local disconnect, setBase = makeInteractive(b, b, { base = base, tint = hover })
	local activated: RBXScriptConnection? = nil
	if options.onActivated then
		activated = b.Activated:Connect(options.onActivated)
	end

	local enabled = true
	local selected = false
	local api = {} :: any
	api.instance = b

	local function repaint()
		if not enabled then
			setBase(Theme.Colour.Sunken)
			b.TextColor3 = Theme.Colour.TextMuted
			textEdge.Transparency = 0.6
		elseif selected then
			-- Selected reads as the reference's lit tab: near-white, dark type.
			setBase(Color3.fromRGB(236, 238, 242), WHITE)
			b.TextColor3 = Theme.Colour.Outline
			textEdge.Transparency = 1
		else
			setBase(base, hover)
			b.TextColor3 = fg
			textEdge.Transparency = 0.1
		end
	end

	function api:SetText(text: string)
		b.Text = text
	end

	function api:SetEnabled(value: boolean)
		if enabled == value then
			return
		end
		enabled = value
		b.Active = value
		repaint()
	end

	--- Selection is a RESTING state, not a paint job -- see makeInteractive.
	function api:SetSelected(value: boolean)
		if selected == value then
			return
		end
		selected = value
		repaint()
	end

	function api:Destroy()
		disconnect()
		if activated then
			activated:Disconnect()
		end
		b:Destroy()
	end

	return api
end

--- The round red close button from the references: a white X on red, dark-rimmed.
function Components.CloseButton(parent: GuiObject, onActivated: () -> (), size: number?)
	local s = size or 46
	local b = Instance.new("TextButton")
	b.Name = "Close"
	b.AutoButtonColor = false
	b.Text = "✕"
	b.Font = Theme.Font.Display
	b.TextSize = math.floor(s * 0.55)
	b.TextColor3 = WHITE
	b.BackgroundColor3 = Theme.Colour.Danger
	b.Size = UDim2.fromOffset(s, s)
	b.Parent = parent
	corner(b, s)
	local rim = stroke(b, Theme.Colour.Outline, 3)
	rim.Transparency = 0.05
	gradient(b, Color3.fromRGB(255, 190, 190), Color3.fromRGB(190, 190, 190))
	outline(b, 2)

	local scale = Instance.new("UIScale")
	scale.Parent = b
	local connections = {
		b.MouseEnter:Connect(function()
			TweenService:Create(scale, Theme.Tween.Hover, { Scale = 1.08 }):Play()
		end),
		b.MouseLeave:Connect(function()
			TweenService:Create(scale, Theme.Tween.Hover, { Scale = 1 }):Play()
		end),
		b.MouseButton1Down:Connect(function()
			TweenService:Create(scale, Theme.Tween.Press, { Scale = 0.92 }):Play()
		end),
		b.Activated:Connect(onActivated),
	}

	local api = {} :: any
	api.instance = b
	function api:Destroy()
		for _, c in ipairs(connections) do
			c:Disconnect()
		end
		b:Destroy()
	end
	return api
end

-- ------------------------------------------------------------------ chip --

--- A small pill: rarity, fire mode, EQUIPPED, a count.
function Components.Chip(parent: GuiObject, text: string, colour: Color3, options: { layoutOrder: number?, filled: boolean? }?): Frame
	local opts = options or {}
	local filled = opts.filled ~= false

	local f = Instance.new("Frame")
	f.Name = "Chip"
	f.BackgroundColor3 = filled and colour or Theme.Colour.Sunken
	f.BackgroundTransparency = filled and 0 or 0.2
	f.BorderSizePixel = 0
	f.AutomaticSize = Enum.AutomaticSize.X
	f.Size = UDim2.fromOffset(0, 22)
	f.LayoutOrder = opts.layoutOrder or 0
	f.Parent = parent
	corner(f, Theme.Radius.Chip)
	padding(f, nil, Theme.Space.S, 0)
	local rim = stroke(f, filled and Theme.Colour.Outline or colour, filled and 1.5 or 1.5)
	rim.Transparency = filled and 0.3 or 0.2
	if filled then
		gradient(f, WHITE, Color3.fromRGB(160, 160, 166))
	end

	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.BackgroundTransparency = 1
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromScale(0, 1)
	l.Font = Theme.Font.Bold
	l.Text = string.upper(text)
	l.TextSize = Theme.Text.Micro + 1
	l.TextColor3 = filled and WHITE or colour
	l.Parent = f
	outline(l, 1.2)

	return f
end

-- ------------------------------------------------------------------- bar --

--- A meter. Health, a weapon stat and quest progress all use it, so all three read the same:
--- a dark rimmed track and a fill with a sheen on it.
function Components.Bar(parent: GuiObject, options: { height: number?, colour: Color3?, layoutOrder: number?, radius: number?, rim: boolean? })
	local height = options.height or 8
	local track = Instance.new("Frame")
	track.Name = "Bar"
	track.BackgroundColor3 = Theme.Colour.Sunken
	track.BackgroundTransparency = 0.15
	track.BorderSizePixel = 0
	track.Size = UDim2.new(1, 0, 0, height)
	track.LayoutOrder = options.layoutOrder or 0
	track.ClipsDescendants = false
	track.Parent = parent
	corner(track, options.radius or math.min(Theme.Radius.Chip, height))
	if options.rim ~= false then
		local rim = stroke(track, Theme.Colour.Outline, height >= 12 and 2.5 or 1.5)
		rim.Transparency = 0.1
	end

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = options.colour or Theme.Colour.Accent
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	corner(fill, options.radius or math.min(Theme.Radius.Chip, height))
	gradient(fill, WHITE, Color3.fromRGB(176, 176, 176))

	local api = {} :: any
	api.instance = track
	api.fill = fill

	function api:SetFraction(fraction: number, animate: boolean?)
		local clamped = math.clamp(fraction, 0, 1)
		if animate == false then
			fill.Size = UDim2.fromScale(clamped, 1)
		else
			TweenService:Create(fill, Theme.Tween.Value, { Size = UDim2.fromScale(clamped, 1) }):Play()
		end
		fill.Visible = clamped > 0.001
	end

	function api:SetColour(colour: Color3)
		TweenService:Create(fill, Theme.Tween.Value, { BackgroundColor3 = colour }):Play()
	end

	return api
end

-- ------------------------------------------------------------- stat row --

--- "Accuracy  [██████ 92 ]" -- the weapon stat line of the reference armory: a bold label,
--- a white bar on a grey track, and the value printed dark inside the bar.
function Components.StatRow(parent: GuiObject, label: string, value: number, maximum: number, options: { layoutOrder: number?, colour: Color3?, suffix: string?, display: string?, height: number? }?): Frame
	local opts = options or {}
	local height = opts.height or 26
	local row = Instance.new("Frame")
	row.Name = "StatRow"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, height)
	row.LayoutOrder = opts.layoutOrder or 0
	row.Parent = parent

	local name = Components.Label(row, { text = label, size = Theme.Text.Body, align = Enum.TextXAlignment.Right })
	name.Size = UDim2.new(0.36, 0, 1, 0)

	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = Color3.fromRGB(92, 96, 108)
	track.BackgroundTransparency = 0.25
	track.BorderSizePixel = 0
	track.Size = UDim2.new(0.6, 0, 0, height - 8)
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0.4, 0, 0.5, 0)
	track.Parent = row
	corner(track, 3)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = opts.colour or WHITE
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	corner(fill, 3)
	TweenService:Create(fill, Theme.Tween.Value, {
		Size = UDim2.fromScale(maximum > 0 and math.clamp(value / maximum, 0.02, 1) or 0, 1),
	}):Play()

	local readout = Instance.new("TextLabel")
	readout.Name = "Value"
	readout.BackgroundTransparency = 1
	readout.Size = UDim2.fromScale(1, 1)
	readout.Font = Theme.Font.Bold
	readout.TextSize = Theme.Text.Small
	readout.TextColor3 = Theme.Colour.Outline
	readout.Text = opts.display or (tostring(value) .. (opts.suffix or ""))
	readout.ZIndex = 2
	readout.Parent = track
	-- A pale halo, so the number reads over both the white fill and the grey track.
	outline(readout, 1.2, WHITE, 0.35)

	return row
end

-- ------------------------------------------------------------------ card --

export type CardOptions = {
	title: string, subtitle: string?, rarity: string?, image: string?,
	badge: string?, locked: boolean?, layoutOrder: number?, onActivated: (() -> ())?,
	colour: Color3?,
}

--- The grid tile shared by the inventory, the market and the profile: flooded with its
--- rarity as a gradient and rimmed in a lighter shade of it, exactly the way the reference
--- weapon cards are green. Locked cards drop to charcoal and carry a padlock.
function Components.Card(parent: GuiObject, options: CardOptions)
	local rarityColour = options.colour or Theme.RarityColour(options.rarity)
	local locked = options.locked == true
	local fillColour = locked and Theme.Colour.PanelRaised or Theme.Shade(rarityColour, -0.15)

	local b = Instance.new("TextButton")
	b.Name = "Card"
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = fillColour
	b.BorderSizePixel = 0
	b.Size = UDim2.fromOffset(Theme.Size.SlotTile.X, Theme.Size.SlotTile.Y)
	b.LayoutOrder = options.layoutOrder or 0
	b.ClipsDescendants = false
	b.Parent = parent
	corner(b, Theme.Radius.Card)
	-- Flooded top-light to bottom-dark, as the references do it.
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 150, 150)),
		ColorSequenceKeypoint.new(0.55, Color3.fromRGB(215, 215, 215)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 255, 255)),
	})
	g.Rotation = -90
	g.Parent = b
	local edge = stroke(b, locked and Theme.Colour.Stroke or Theme.Shade(rarityColour, 0.35), 2.5)

	-- Gloss across the top third: the "toy" highlight every reference card carries.
	local gloss = Instance.new("Frame")
	gloss.Name = "Gloss"
	gloss.BackgroundColor3 = WHITE
	gloss.BackgroundTransparency = 0.88
	gloss.BorderSizePixel = 0
	gloss.Size = UDim2.new(1, -6, 0.38, 0)
	gloss.Position = UDim2.fromOffset(3, 3)
	gloss.Parent = b
	corner(gloss, Theme.Radius.Card - 2)

	if options.image and options.image ~= "" then
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Image = options.image
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Size = UDim2.fromScale(0.78, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.42)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.ImageTransparency = locked and 0.65 or 0
		icon.Parent = b
	end

	local title = Components.Label(b, {
		text = options.title,
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		align = Enum.TextXAlignment.Center,
		colour = locked and Theme.Colour.TextDim or Theme.Colour.Text,
	})
	title.Name = "Title"
	title.Size = UDim2.new(1, -Theme.Space.S, 0, 18)
	title.Position = UDim2.new(0, Theme.Space.XS, 1, -38)
	title.TextTruncate = Enum.TextTruncate.AtEnd

	local sub = Components.Label(b, {
		text = options.subtitle or (options.rarity or ""),
		size = Theme.Text.Micro,
		align = Enum.TextXAlignment.Center,
		colour = locked and Theme.Colour.TextMuted or Theme.Shade(rarityColour, 0.55),
	})
	sub.Name = "Subtitle"
	sub.Size = UDim2.new(1, -Theme.Space.S, 0, 14)
	sub.Position = UDim2.new(0, Theme.Space.XS, 1, -19)
	sub.TextTruncate = Enum.TextTruncate.AtEnd

	if locked then
		local lock = Components.Icon(b, "🔒", 18)
		lock.AnchorPoint = Vector2.new(1, 0)
		lock.Position = UDim2.new(1, -4, 0, 4)
		lock.ZIndex = 3
	end

	if options.badge then
		local badge = Components.Chip(b, options.badge, Theme.Colour.Accent, { filled = true })
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, -Theme.Space.XS, 0, Theme.Space.XS + 2)
		badge.ZIndex = 3
	end

	local scale = Instance.new("UIScale")
	scale.Parent = b
	local hoverBase = fillColour:Lerp(WHITE, 0.12)
	local disconnect = makeInteractive(b, b, { base = fillColour, tint = hoverBase, lift = false })
	local connections = {
		b.MouseEnter:Connect(function()
			TweenService:Create(scale, Theme.Tween.Hover, { Scale = 1.04 }):Play()
		end),
		b.MouseLeave:Connect(function()
			TweenService:Create(scale, Theme.Tween.Hover, { Scale = 1 }):Play()
		end),
	}
	if options.onActivated then
		table.insert(connections, b.Activated:Connect(options.onActivated))
	end

	local restEdge = edge.Color
	local api = {} :: any
	api.instance = b
	api.title = title

	function api:SetSelected(selected: boolean)
		TweenService:Create(edge, Theme.Tween.Hover, {
			Color = selected and WHITE or restEdge,
			Thickness = selected and 4 or 2.5,
		}):Play()
	end

	function api:Destroy()
		disconnect()
		for _, c in ipairs(connections) do
			c:Disconnect()
		end
		b:Destroy()
	end

	return api
end

-- ------------------------------------------------------------- badges --

--- The gold level diamond from the references: a rotated square with a sheen and a dark
--- orange rim, the number upright on top of it.
function Components.LevelBadge(parent: GuiObject, size: number): (Frame, TextLabel)
	local holder = Instance.new("Frame")
	holder.Name = "LevelBadge"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(size, size)
	holder.Parent = parent

	local diamond = Instance.new("Frame")
	diamond.Name = "Diamond"
	diamond.BackgroundColor3 = Theme.Colour.Level
	diamond.BorderSizePixel = 0
	diamond.AnchorPoint = Vector2.new(0.5, 0.5)
	diamond.Position = UDim2.fromScale(0.5, 0.5)
	diamond.Size = UDim2.fromScale(0.7, 0.7)
	diamond.Rotation = 45
	diamond.Parent = holder
	corner(diamond, math.max(3, math.floor(size * 0.1)))
	local rim = stroke(diamond, Theme.Colour.LevelEdge, math.max(2, size * 0.07))
	rim.Transparency = 0
	local g = gradient(diamond, Color3.fromRGB(255, 250, 200), Color3.fromRGB(230, 150, 40))
	g.Rotation = 45

	local number = Instance.new("TextLabel")
	number.Name = "Number"
	number.BackgroundTransparency = 1
	number.Size = UDim2.fromScale(1, 1)
	number.Font = Theme.Font.Display
	number.TextSize = math.floor(size * 0.46)
	number.TextColor3 = Color3.fromRGB(255, 236, 120)
	number.Text = "1"
	number.ZIndex = 2
	number.Parent = holder
	outline(number, math.max(1.5, size * 0.06), Theme.Colour.LevelEdge:Lerp(Color3.new(0, 0, 0), 0.35), 0)

	return holder, number
end

--- A keyboard key, drawn as one: a white cap with a darker lip under it and the key's name
--- on top. Sized to the text, so "J" and "ALT" both come out right. Only makes sense on a
--- keyboard, so callers hide it when UserInputService.KeyboardEnabled is false.
function Components.KeyCap(parent: GuiObject, key: string, height: number?): Frame
	local h = height or 24
	local cap = Instance.new("Frame")
	cap.Name = "KeyCap"
	cap.BackgroundColor3 = Color3.fromRGB(150, 156, 170)       -- the lip
	cap.Size = UDim2.fromOffset(0, h)
	cap.AutomaticSize = Enum.AutomaticSize.X
	cap.Parent = parent
	corner(cap, math.max(4, math.floor(h * 0.22)))
	stroke(cap, Theme.Colour.Outline, 2)

	local face = Instance.new("TextLabel")
	face.Name = "Face"
	face.BackgroundColor3 = WHITE
	face.Size = UDim2.new(0, 0, 1, -math.max(3, math.floor(h * 0.14)))
	face.AutomaticSize = Enum.AutomaticSize.X
	face.Font = Theme.Font.Display
	face.TextSize = math.floor(h * 0.62)
	face.TextColor3 = Theme.Colour.Outline
	face.Text = key
	face.Parent = cap
	corner(face, math.max(4, math.floor(h * 0.22)))
	padding(face, nil, math.max(6, math.floor(h * 0.3)), 0)

	-- The cap's width follows its face; the lip shows along the bottom edge.
	return cap
end

-- ------------------------------------------------------------- responsive --

--- One UIScale per ScreenGui, driven by viewport changes only -- no polling. The design is
--- authored once at 1280x720 and scaled to fit.
function Components.BindScale(gui: ScreenGui): () -> ()
	local scale = gui:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = gui

	local connections: { RBXScriptConnection } = {}

	local function apply()
		local cam = workspace.CurrentCamera
		if cam then
			scale.Scale = Theme.ScaleFor(cam.ViewportSize)
		end
	end

	local function bindCamera()
		local cam = workspace.CurrentCamera
		if cam then
			table.insert(connections, cam:GetPropertyChangedSignal("ViewportSize"):Connect(apply))
		end
		apply()
	end

	bindCamera()
	-- The camera is replaced on respawn, and a stale connection would silently stop updating.
	table.insert(connections, workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera))

	return function()
		for _, c in ipairs(connections) do
			c:Disconnect()
		end
		table.clear(connections)
	end
end

return Components
