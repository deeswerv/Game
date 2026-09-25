--!strict
-- Small helpers for building the interface from code, so every panel in the game gets the
-- same corners, strokes and fonts without repeating itself.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local GameConfig = require(ReplicatedStorage.GameConfig)

-- ------------------------------------------------------------------- palette --

-- The interface's palette now lives in ReplicatedStorage.UI.Modules.Theme, which the rebuilt
-- HUD, inventory, market and workshop all read. The panels still on UIKit -- prompts, quests,
-- chests, the emote wheel -- were drawing a gold-on-black palette out of GameConfig, which is
-- precisely why they looked like a different game sitting next to the new ones.
--
-- MAPPED, not copied. These are the old spellings of the new values, so the two palettes
-- cannot drift apart again; Theme stays the single source of truth.
local function paletteFrom(new): { [string]: any }
	local white = Color3.new(1, 1, 1)
	return {
		Background   = new.Colour.Scrim,
		Panel        = new.Colour.Panel,
		PanelLight   = new.Colour.PanelRaised,
		Elevated     = new.Colour.Hover,
		Stroke       = new.Colour.Stroke,
		-- The old palette's "border catching the light" -- kept, just derived now.
		StrokeLight  = new.Colour.Stroke:Lerp(white, 0.18),

		Accent       = new.Colour.Accent,
		AccentDim    = new.Colour.AccentDim,
		AccentGlow   = new.Colour.Accent:Lerp(white, 0.35),

		Danger       = new.Colour.Danger,
		Success      = new.Colour.Accent,
		Info         = new.Colour.Info,

		Text         = new.Colour.Text,
		TextDim      = new.Colour.TextDim,
		TextFaint    = new.Colour.TextMuted,

		Corner       = UDim.new(0, new.Radius.Small),
		CornerLarge  = UDim.new(0, new.Radius.Card),
		Font         = new.Font.Medium,
		FontBold     = new.Font.Bold,
		FontBlack    = new.Font.Display,
	}
end

-- Guarded lookup, never WaitForChild: UIKit is required early by several panels and must
-- not block. If the UI folder has not replicated, or is missing entirely, it falls back to
-- the original GameConfig palette and every panel still draws -- just in the old colours.
local Theme = GameConfig.Theme
do
	local ui = ReplicatedStorage:FindFirstChild("UI")
	local modules = ui and ui:FindFirstChild("Modules")
	local themeModule = modules and modules:FindFirstChild("Theme")
	if themeModule and themeModule:IsA("ModuleScript") then
		local ok, new = pcall(require, themeModule)
		if ok and type(new) == "table" and new.Colour then
			Theme = paletteFrom(new)
		end
	end
end

local UIKit = {}
UIKit.Theme = Theme

-- ------------------------------------------------------------------ surfaces --

--- A vertical sheen across a surface: very slightly lighter at the top.
---
--- This is the single cheapest thing that separates a modern dark interface from a flat
--- one. A panel of one solid colour has no implied light source, so it reads as a
--- rectangle rather than a surface; three percent of gradient is enough to fix that and
--- little enough that nobody consciously sees it.
function UIKit.sheen(frame: GuiObject, strength: number?)
	local s = strength or 0.06
	local g = Instance.new("UIGradient")
	g.Rotation = 90
	g.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.new(1 - s, 1 - s, 1 - s)),
	})
	g.Parent = frame
	return g
end

--- A soft drop shadow behind a panel, so it sits above the world instead of being pasted
--- onto it. Built from stacked translucent frames rather than an image asset.
function UIKit.shadow(frame: GuiObject, spread: number?)
	local layers = 4
	local reach = spread or 14
	for i = 1, layers do
		local grow = (reach / layers) * i
		local shade = Instance.new("Frame")
		shade.Name = "Shadow" .. i
		shade.AnchorPoint = Vector2.new(0.5, 0.5)
		shade.Position = UDim2.new(0.5, 0, 0.5, math.floor(grow * 0.35))
		shade.Size = UDim2.new(1, grow * 2, 1, grow * 2)
		shade.BackgroundColor3 = Color3.new(0, 0, 0)
		shade.BackgroundTransparency = 0.82 + (i / layers) * 0.15
		shade.BorderSizePixel = 0
		shade.ZIndex = (frame.ZIndex or 1) - 1
		shade.Active = false
		shade.Parent = frame
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(0, 14)
		c.Parent = shade
	end
end

--- Rarity colour, from the one table the whole game shares.
function UIKit.rarity(tier: string?): Color3
	return (GameConfig.RarityColour and GameConfig.RarityColour[tier or ""])
		or Theme.TextDim
end

-- --------------------------------------------------------------- selection --

-- Tabs and category rails were the weakest part of the interface: every option rendered
-- identically, so the selected one was only distinguishable by remembering what you had
-- clicked. `selectable` gives a control three states that actually look different.
local SELECT_TWEEN = TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

--- Mark a button as selected or not. Adds an accent bar down its leading edge the first
--- time it is called, so callers do not have to build one.
function UIKit.selectable(button: GuiButton, active: boolean, accent: Color3?)
	local colour = accent or Theme.Accent

	local bar = button:FindFirstChild("SelectBar") :: Frame?
	if not bar then
		bar = Instance.new("Frame")
		bar.Name = "SelectBar"
		bar.AnchorPoint = Vector2.new(0, 0.5)
		bar.Position = UDim2.new(0, 0, 0.5, 0)
		bar.Size = UDim2.new(0, 3, 0, 0)
		bar.BackgroundColor3 = colour
		bar.BorderSizePixel = 0
		bar.ZIndex = (button.ZIndex or 1) + 1
		bar.Active = false
		bar.Parent = button
		local c = Instance.new("UICorner")
		c.CornerRadius = UDim.new(1, 0)
		c.Parent = bar
	end

	bar.BackgroundColor3 = colour
	TweenService:Create(bar, SELECT_TWEEN, {
		Size = active and UDim2.new(0, 3, 0.62, 0) or UDim2.new(0, 3, 0, 0),
	}):Play()
	TweenService:Create(button, SELECT_TWEEN, {
		BackgroundColor3 = active and Theme.Elevated or Theme.PanelLight,
	}):Play()
	button.TextColor3 = active and Theme.Text or Theme.TextDim
	button.Font = active and Theme.FontBold or Theme.Font
end

--- A small pill showing a rarity word in its own colour.
function UIKit.rarityChip(parent: GuiObject, tier: string, size: UDim2?, position: UDim2?): Frame
	local colour = UIKit.rarity(tier)
	local chip = Instance.new("Frame")
	chip.Name = "RarityChip"
	chip.Size = size or UDim2.fromOffset(72, 16)
	chip.Position = position or UDim2.fromOffset(0, 0)
	chip.BackgroundColor3 = colour
	chip.BackgroundTransparency = 0.82
	chip.BorderSizePixel = 0
	chip.Active = false
	chip.Parent = parent

	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = chip

	local stroke = Instance.new("UIStroke")
	stroke.Color = colour
	stroke.Thickness = 1
	stroke.Transparency = 0.45
	stroke.Parent = chip

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Theme.FontBold
	label.TextSize = 10
	label.TextColor3 = colour
	label.Text = string.upper(tier)
	label.Parent = chip

	return chip
end

--- A section title with a hairline rule after it, for grouping inside a panel.
function UIKit.sectionHeader(parent: GuiObject, text: string, y: number): TextLabel
	local label = Instance.new("TextLabel")
	label.Name = "Section_" .. text
	label.Position = UDim2.fromOffset(0, y)
	label.Size = UDim2.new(1, 0, 0, 14)
	label.BackgroundTransparency = 1
	label.Font = Theme.FontBold
	label.TextSize = 10
	label.TextColor3 = Theme.TextFaint
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Text = string.upper(text)
	label.Parent = parent

	local rule = Instance.new("Frame")
	rule.Name = "Rule"
	rule.AnchorPoint = Vector2.new(0, 0.5)
	rule.Position = UDim2.new(0, 0, 0, y + 20)
	rule.Size = UDim2.new(1, 0, 0, 1)
	rule.BackgroundColor3 = Theme.Stroke
	rule.BackgroundTransparency = 0.4
	rule.BorderSizePixel = 0
	rule.Active = false
	rule.Parent = parent

	return label
end

function UIKit.corner(parent: Instance, radius: UDim?)
	local c = Instance.new("UICorner")
	c.CornerRadius = radius or Theme.Corner
	c.Parent = parent
	return c
end

function UIKit.stroke(parent: Instance, color: Color3?, thickness: number?, transparency: number?)
	local s = Instance.new("UIStroke")
	s.Color = color or Theme.Stroke
	s.Thickness = thickness or 1
	s.Transparency = transparency or 0
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = parent
	return s
end

function UIKit.pad(parent: Instance, px: number)
	local p = Instance.new("UIPadding")
	p.PaddingTop = UDim.new(0, px)
	p.PaddingBottom = UDim.new(0, px)
	p.PaddingLeft = UDim.new(0, px)
	p.PaddingRight = UDim.new(0, px)
	p.Parent = parent
	return p
end

function UIKit.frame(props: { [string]: any }): Frame
	local f = Instance.new("Frame")
	f.BackgroundColor3 = Theme.Panel
	f.BorderSizePixel = 0
	for k, v in pairs(props) do
		(f :: any)[k] = v
	end
	return f
end

function UIKit.label(props: { [string]: any }): TextLabel
	local l = Instance.new("TextLabel")
	l.BackgroundTransparency = 1
	l.Font = Theme.Font
	l.TextColor3 = Theme.Text
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.TextYAlignment = Enum.TextYAlignment.Center
	l.RichText = true
	for k, v in pairs(props) do
		(l :: any)[k] = v
	end
	return l
end

-- Every button gets the same treatment: a hard dark edge, a vertical fill, a text stroke
-- and a press that actually moves.
--
-- The old buttons were a flat grey rectangle with plain text, which is what made the
-- interface read as unfinished no matter how well the panels were laid out. The look this
-- game is aiming at is built from weight -- thick outlines, fills that catch light at the
-- top, type heavy enough to hold its own against a bright world behind it.
--
-- Deliberately does NOT add a UICorner: callers already choose their own radius, and a
-- second corner on the same object is a coin toss over which one wins.
function UIKit.button(props: { [string]: any }): TextButton
	local b = Instance.new("TextButton")
	b.BackgroundColor3 = Theme.PanelLight
	b.BorderSizePixel = 0
	b.Font = Theme.FontBold
	b.TextColor3 = Theme.Text
	b.AutoButtonColor = false
	for k, v in pairs(props) do
		(b :: any)[k] = v
	end

	-- Hard edge. Near-black rather than a lighter grey, because the outline is doing the
	-- same job a drop shadow does in a lighter interface: separating the control from
	-- whatever is behind it, including a bright green field.
	local edge = Instance.new("UIStroke")
	edge.Name = "Edge"
	edge.Color = Color3.fromRGB(8, 9, 13)
	edge.Thickness = 2
	edge.Transparency = 0.15
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = b

	-- Lit from above.
	local fill = Instance.new("UIGradient")
	fill.Name = "Fill"
	fill.Rotation = 90
	fill.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(196, 196, 204)),
	})
	fill.Parent = b

	b.TextStrokeColor3 = Color3.fromRGB(8, 9, 13)
	b.TextStrokeTransparency = 0.6

	UIKit.press(b)
	return b
end

--- Make a control physically respond to being clicked.
---
--- Depressing on press and springing back is the difference between an interface that
--- feels responsive and one that merely works. Cheap: one UIScale, two tweens.
function UIKit.press(button: GuiButton)
	local scale = button:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = button
	end
	button.MouseButton1Down:Connect(function()
		TweenService:Create(scale, TweenInfo.new(0.07, Enum.EasingStyle.Quad), { Scale = 0.95 }):Play()
	end)
	local function release()
		TweenService:Create(scale, TweenInfo.new(0.13, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end
	button.MouseButton1Up:Connect(release)
	button.MouseLeave:Connect(release)
end

--- Give any frame the same weight the buttons have: hard edge, lit fill, chunky radius.
--- For cards and panels that are not buttons.
function UIKit.chunky(frame: GuiObject, radius: number?, edgeColour: Color3?)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = frame

	local edge = Instance.new("UIStroke")
	edge.Name = "Edge"
	edge.Color = edgeColour or Color3.fromRGB(8, 9, 13)
	edge.Thickness = 2
	edge.Transparency = 0.2
	edge.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	edge.Parent = frame

	UIKit.sheen(frame, 0.1)
	return edge
end

-- ------------------------------------------------------------------ motion --
--
-- One place for the timings, so every panel in the game moves at the same speed and a
-- menu never feels slower than the one before it. These are deliberately short: the
-- brief asks for polish, not for waiting.
UIKit.Motion = {
	Quick = TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
	Panel = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
	Fade = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
}

local function tween(object: Instance, info: TweenInfo, goal: { [string]: any })
	local t = TweenService:Create(object, info, goal)
	t:Play()
	return t
end
UIKit.tween = tween

-- Hover/press feedback without writing the same three connections everywhere.
function UIKit.hover(button: TextButton, base: Color3, hot: Color3)
	button.BackgroundColor3 = base
	button.MouseEnter:Connect(function()
		tween(button, UIKit.Motion.Quick, { BackgroundColor3 = hot })
	end)
	button.MouseLeave:Connect(function()
		tween(button, UIKit.Motion.Quick, { BackgroundColor3 = base })
	end)
end

-- Hover for a card in a grid. A card cannot move -- the layout owns its position -- so
-- the feedback is its edge lighting up and its face lifting a shade.
function UIKit.cardHover(card: GuiObject, stroke: UIStroke?, restTransparency: number?)
	local restStroke = restTransparency or (stroke and stroke.Transparency) or 0.3
	local restFill = card.BackgroundColor3
	local hotFill = restFill:Lerp(Color3.new(1, 1, 1), 0.07)
	card.MouseEnter:Connect(function()
		if stroke then
			tween(stroke, UIKit.Motion.Quick, { Transparency = 0 })
		end
		tween(card, UIKit.Motion.Quick, { BackgroundColor3 = hotFill })
	end)
	card.MouseLeave:Connect(function()
		if stroke then
			tween(stroke, UIKit.Motion.Quick, { Transparency = restStroke })
		end
		tween(card, UIKit.Motion.Quick, { BackgroundColor3 = restFill })
	end)
end

-- Grow a panel into place. Called on open; the panel should already be Visible.
function UIKit.openPanel(panel: GuiObject, finalSize: UDim2)
	panel.Size = UDim2.fromOffset(
		math.floor(finalSize.X.Offset * 0.94), math.floor(finalSize.Y.Offset * 0.94))
	tween(panel, UIKit.Motion.Panel, { Size = finalSize })
end

-- Fade a freshly built card in, staggered by its position in the list. Twelve cards
-- appearing together reads as a flicker; appearing over a fifth of a second reads as the
-- shelf being restocked. Capped so a long list does not crawl in.
function UIKit.appear(card: GuiObject, order: number)
	local delay = math.min((order - 1) * 0.012, 0.16)
	local restore = {}
	for _, d in ipairs(card:GetDescendants()) do
		if d:IsA("TextLabel") or d:IsA("TextButton") then
			table.insert(restore, { d, d.TextTransparency })
			d.TextTransparency = 1
		end
	end
	local fill = card.BackgroundTransparency
	card.BackgroundTransparency = 1
	task.delay(delay, function()
		if not card.Parent then
			return
		end
		tween(card, UIKit.Motion.Fade, { BackgroundTransparency = fill })
		for _, entry in ipairs(restore) do
			local object, value = entry[1], entry[2]
			if object.Parent then
				tween(object, UIKit.Motion.Fade, { TextTransparency = value })
			end
		end
	end)
end

-- A one-shot colour flash, for "that worked": equipped, saved, bought.
function UIKit.pulse(object: GuiObject, colour: Color3)
	local was = object.BackgroundColor3
	object.BackgroundColor3 = colour
	tween(object, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundColor3 = was })
end

-- Turn a button into a two-press confirmation. The first press arms it and starts a
-- timeout; the second within that window commits. Nothing destructive in this game should
-- happen on one click, and a modal dialogue for deleting a loadout is heavier than the
-- action deserves.
function UIKit.confirm(button: TextButton, armedText: string, danger: Color3, action: () -> ())
	local idleText = button.Text
	local idleColour = button.TextColor3
	local armed = false
	local token = 0

	local function disarm()
		armed = false
		button.Text = idleText
		button.TextColor3 = idleColour
	end

	button.MouseButton1Click:Connect(function()
		if armed then
			token += 1
			disarm()
			action()
			return
		end
		armed = true
		button.Text = armedText
		button.TextColor3 = danger
		token += 1
		local mine = token
		task.delay(2.5, function()
			if token == mine and armed and button.Parent then
				disarm()
			end
		end)
	end)
end

-- Keep a fixed-size panel usable on any screen.
--
-- These panels are laid out at a design size on purpose: a workbench full of small
-- controls is far easier to reason about that way than as a reflowing grid. They stay
-- usable on smaller screens by scaling the whole panel down, which keeps every control in
-- the same relative place on a phone as on a monitor. Never scales UP past the design
-- size, or a big monitor would get a blurry oversized panel.
function UIKit.fitToScreen(panel: GuiObject, designW: number, designH: number, margin: number?)
	local scale = panel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	scale.Parent = panel
	local pad = margin or 40

	local function fit()
		local camera = workspace.CurrentCamera
		local view = camera and camera.ViewportSize
		if not view or view.X < 1 then
			return
		end
		scale.Scale = math.min(1, (view.X - pad) / designW, (view.Y - pad) / designH)
	end

	fit()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	end
	-- The camera is replaced on respawn, and the old connection goes with it.
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if workspace.CurrentCamera then
			workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
			fit()
		end
	end)
	return scale
end

function UIKit.gradient(parent: Instance, a: Color3, b: Color3, rotation: number?)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(a, b)
	g.Rotation = rotation or 90
	g.Parent = parent
	return g
end

return UIKit
