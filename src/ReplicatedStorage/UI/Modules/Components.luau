--!strict
-- Components: the small set of parts every screen is assembled from.
--
-- The old interface was rebuilt by hand on each screen, which is why no two panels agreed on
-- a grey or a gap. Here a panel is a function. If the market and the inventory both call
-- Components.Card they cannot drift apart, and fixing a card fixes both.
--
-- Nothing here polls. Hover and press are input-driven, values tween and stop, and every
-- component returns a Destroy that disconnects what it made, so a closed screen leaves
-- nothing running.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)

local Components = {}

-- --------------------------------------------------------------- primitives --

local function corner(parent: GuiObject, radius: number): UICorner
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
	return c
end
Components.Corner = corner

local function stroke(parent: GuiObject, colour: Color3?, thickness: number?): UIStroke
	local s = Instance.new("UIStroke")
	s.Color = colour or Theme.Colour.Stroke
	s.Thickness = thickness or Theme.Stroke.Hair
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end
Components.Stroke = stroke

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
	-- Always explicit. The default is SortOrder.Name, which silently ignores LayoutOrder and
	-- has cost this project a day before now.
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
	layoutOrder: number?, autoSize: boolean?,
}

function Components.Label(parent: GuiObject, options: LabelOptions): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Text = options.text or ""
	l.Font = options.font or Theme.Font.Medium
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

	if options.autoSize then
		l.AutomaticSize = Enum.AutomaticSize.XY
		l.Size = UDim2.fromOffset(0, 0)
	end

	l.Parent = parent
	return l
end

-- ------------------------------------------------------------------ panel --

export type PanelOptions = {
	size: UDim2?, position: UDim2?, anchor: Vector2?, colour: Color3?,
	radius: number?, stroked: boolean?, pad: number?, layoutOrder: number?, name: string?,
}

function Components.Panel(parent: GuiObject, options: PanelOptions): Frame
	local f = Instance.new("Frame")
	f.Name = options.name or "Panel"
	f.BackgroundColor3 = options.colour or Theme.Colour.Panel
	f.BorderSizePixel = 0
	f.Size = options.size or UDim2.fromScale(1, 1)
	f.Position = options.position or UDim2.fromScale(0, 0)
	f.AnchorPoint = options.anchor or Vector2.zero
	f.LayoutOrder = options.layoutOrder or 0
	corner(f, options.radius or Theme.Radius.Panel)
	if options.stroked ~= false then
		stroke(f)
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
-- That second return matters more than it looks. Selection used to be painted straight onto
-- BackgroundColor3, which this hover logic also owns -- so the first time the mouse crossed a
-- selected chip, MouseLeave tweened it back to the unselected colour and the highlight simply
-- vanished. Two writers, one property, last one wins. Selection now moves the resting colour
-- itself, so hover has somewhere correct to return to.
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
		tint = hoverColour or colour:Lerp(Color3.new(1, 1, 1), 0.10)
		visual.BackgroundColor3 = colour
	end

	return disconnect, setBase
end
Components.MakeInteractive = makeInteractive

-- ----------------------------------------------------------------- button --

export type ButtonOptions = {
	text: string?, primary: boolean?, danger: boolean?, size: UDim2?, position: UDim2?,
	anchor: Vector2?, radius: number?, layoutOrder: number?, textSize: number?,
	onActivated: (() -> ())?, name: string?,
}

function Components.Button(parent: GuiObject, options: ButtonOptions)
	local primary = options.primary == true
	local danger = options.danger == true

	local base = primary and Theme.Colour.Accent or danger and Theme.Colour.Danger or Theme.Colour.PanelRaised
	local hover = primary and Theme.Colour.Accent:Lerp(Color3.new(1, 1, 1), 0.12)
		or danger and Theme.Colour.Danger:Lerp(Color3.new(1, 1, 1), 0.12)
		or Theme.Colour.Hover
	local fg = primary and Theme.Colour.AccentText or Theme.Colour.Text

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
	if not primary and not danger then
		stroke(b)
	end

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
		elseif selected then
			setBase(Theme.Colour.Accent)
			b.TextColor3 = Theme.Colour.AccentText
		else
			setBase(base, hover)
			b.TextColor3 = fg
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

	--- Selection is a RESTING state, not a paint job -- see makeInteractive for why that
	--- distinction is the entire bug.
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

-- ------------------------------------------------------------------ chip --

--- A small pill: rarity, fire mode, EQUIPPED, a count. Deliberately tiny -- a chip that grows
--- into a badge is how a clean screen turns noisy.
function Components.Chip(parent: GuiObject, text: string, colour: Color3, options: { layoutOrder: number?, filled: boolean? }?): Frame
	local opts = options or {}
	local filled = opts.filled == true

	local f = Instance.new("Frame")
	f.Name = "Chip"
	f.BackgroundColor3 = filled and colour or Theme.Colour.Sunken
	f.BackgroundTransparency = filled and 0 or 0.25
	f.BorderSizePixel = 0
	f.AutomaticSize = Enum.AutomaticSize.X
	f.Size = UDim2.fromOffset(0, 20)
	f.LayoutOrder = opts.layoutOrder or 0
	f.Parent = parent
	corner(f, Theme.Radius.Chip)
	padding(f, nil, Theme.Space.S, 0)
	if not filled then
		stroke(f, colour:Lerp(Theme.Colour.Panel, 0.45))
	end

	local l = Instance.new("TextLabel")
	l.Name = "Text"
	l.BackgroundTransparency = 1
	l.AutomaticSize = Enum.AutomaticSize.X
	l.Size = UDim2.fromScale(0, 1)
	l.Font = Theme.Font.Bold
	l.Text = string.upper(text)
	l.TextSize = Theme.Text.Micro
	l.TextColor3 = filled and Theme.Colour.AccentText or colour
	l.Parent = f

	return f
end

-- ------------------------------------------------------------------- bar --

--- A meter. Health, a weapon stat and quest progress all use it, so all three read the same.
function Components.Bar(parent: GuiObject, options: { height: number?, colour: Color3?, layoutOrder: number?, radius: number? })
	local height = options.height or 6
	local track = Instance.new("Frame")
	track.Name = "Bar"
	track.BackgroundColor3 = Theme.Colour.Sunken
	track.BorderSizePixel = 0
	track.Size = UDim2.new(1, 0, 0, height)
	track.LayoutOrder = options.layoutOrder or 0
	track.Parent = parent
	corner(track, options.radius or Theme.Radius.Chip)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = options.colour or Theme.Colour.Accent
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = track
	corner(fill, options.radius or Theme.Radius.Chip)

	local api = {} :: any
	api.instance = track

	function api:SetFraction(fraction: number, animate: boolean?)
		local clamped = math.clamp(fraction, 0, 1)
		if animate == false then
			fill.Size = UDim2.fromScale(clamped, 1)
		else
			TweenService:Create(fill, Theme.Tween.Value, { Size = UDim2.fromScale(clamped, 1) }):Play()
		end
	end

	function api:SetColour(colour: Color3)
		TweenService:Create(fill, Theme.Tween.Value, { BackgroundColor3 = colour }):Play()
	end

	return api
end

-- ------------------------------------------------------------- stat row --

--- "ACCURACY  [=====   ]  92" -- label, meter, value on one line, as in the weapon panel of
--- the references. The value sits in a fixed right-hand column so a stack of these lines up.
function Components.StatRow(parent: GuiObject, label: string, value: number, maximum: number, options: { layoutOrder: number?, colour: Color3?, suffix: string? }?): Frame
	local opts = options or {}
	local row = Instance.new("Frame")
	row.Name = "StatRow"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 22)
	row.LayoutOrder = opts.layoutOrder or 0
	row.Parent = parent

	local name = Components.Label(row, { text = label, caps = true, size = Theme.Text.Micro })
	name.Size = UDim2.new(0.34, 0, 1, 0)

	local track = Instance.new("Frame")
	track.BackgroundTransparency = 1
	track.Size = UDim2.new(0.42, 0, 1, 0)
	track.Position = UDim2.new(0.36, 0, 0, 0)
	track.Parent = row

	local bar = Components.Bar(track, { height = 6, colour = opts.colour or Theme.Colour.Text })
	bar.instance.AnchorPoint = Vector2.new(0, 0.5)
	bar.instance.Position = UDim2.fromScale(0, 0.5)
	bar:SetFraction(maximum > 0 and value / maximum or 0, false)

	local readout = Components.Label(row, {
		text = tostring(value) .. (opts.suffix or ""),
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		align = Enum.TextXAlignment.Right,
	})
	readout.Size = UDim2.new(0.2, 0, 1, 0)
	readout.Position = UDim2.new(0.8, 0, 0, 0)

	return row
end

-- ------------------------------------------------------------------ card --

export type CardOptions = {
	title: string, subtitle: string?, rarity: string?, image: string?,
	badge: string?, locked: boolean?, layoutOrder: number?, onActivated: (() -> ())?,
}

--- The grid tile shared by the inventory and the market. Rarity is a top edge and a chip --
--- never a coloured background, which is what keeps a full grid readable.
function Components.Card(parent: GuiObject, options: CardOptions)
	local rarityColour = Theme.RarityColour(options.rarity)

	local b = Instance.new("TextButton")
	b.Name = "Card"
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = Theme.Colour.PanelRaised
	b.BorderSizePixel = 0
	b.Size = UDim2.fromOffset(Theme.Size.SlotTile.X, Theme.Size.SlotTile.Y)
	b.LayoutOrder = options.layoutOrder or 0
	b.Parent = parent
	corner(b, Theme.Radius.Card)
	local edge = stroke(b, Theme.Colour.Stroke)

	local cap = Instance.new("Frame")
	cap.Name = "RarityCap"
	cap.BackgroundColor3 = rarityColour
	cap.BorderSizePixel = 0
	cap.Size = UDim2.new(1, 0, 0, 2)
	cap.Parent = b
	corner(cap, Theme.Radius.Chip)

	if options.image and options.image ~= "" then
		local icon = Instance.new("ImageLabel")
		icon.Name = "Icon"
		icon.BackgroundTransparency = 1
		icon.Image = options.image
		icon.ScaleType = Enum.ScaleType.Fit
		icon.Size = UDim2.fromScale(0.78, 0.5)
		icon.Position = UDim2.fromScale(0.5, 0.42)
		icon.AnchorPoint = Vector2.new(0.5, 0.5)
		icon.ImageTransparency = options.locked and 0.65 or 0
		icon.Parent = b
	end

	local title = Components.Label(b, {
		text = options.title,
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		align = Enum.TextXAlignment.Center,
		colour = options.locked and Theme.Colour.TextMuted or Theme.Colour.Text,
	})
	title.Size = UDim2.new(1, -Theme.Space.S, 0, 16)
	title.Position = UDim2.new(0, Theme.Space.XS, 1, -34)

	local sub = Components.Label(b, {
		text = options.subtitle or (options.rarity or ""),
		size = Theme.Text.Micro,
		align = Enum.TextXAlignment.Center,
		colour = rarityColour,
	})
	sub.Size = UDim2.new(1, -Theme.Space.S, 0, 14)
	sub.Position = UDim2.new(0, Theme.Space.XS, 1, -18)

	if options.badge then
		local badge = Components.Chip(b, options.badge, Theme.Colour.Accent, { filled = true })
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, -Theme.Space.XS, 0, Theme.Space.XS + 2)
	end

	local disconnect = makeInteractive(b, b, { base = Theme.Colour.PanelRaised })
	local activated: RBXScriptConnection? = nil
	if options.onActivated then
		activated = b.Activated:Connect(options.onActivated)
	end

	local api = {} :: any
	api.instance = b

	function api:SetSelected(selected: boolean)
		TweenService:Create(edge, Theme.Tween.Hover, {
			Color = selected and Theme.Colour.Info or Theme.Colour.Stroke,
			Thickness = selected and Theme.Stroke.Emphasis or Theme.Stroke.Hair,
		}):Play()
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

-- ------------------------------------------------------------- responsive --

--- One UIScale per ScreenGui, driven by viewport changes only -- no polling. This is what
--- makes the interface correct on a phone and on a 4K monitor without a second layout: the
--- design is authored once at 1280x720 and scaled to fit.
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
