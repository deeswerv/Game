--!strict
-- Notifications: small cards that slide in on the left for things worth knowing (a
-- contract ticking up, somebody looting a drop), and one big banner across the top for
-- things worth stopping for (CONTRACT COMPLETE, SUPPLY DROP INBOUND).
--
-- Draws only; whoever has news calls Push or Banner.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local UISound = require(script.Parent.UISound)

local Toast = {}
Toast.__index = Toast

local CARD_WIDTH = 310
local CARD_HEIGHT = 52
local MAX_CARDS = 4

export type PushOptions = {
	title: string,
	text: string?,
	icon: string?,
	colour: Color3?,
	duration: number?,
	progress: number?,        -- 0..1, draws a thin bar along the bottom
}

export type BannerOptions = {
	title: string,
	subtitle: string?,
	colour: Color3?,
	duration: number?,
	sound: string?,
}

function Toast.new(parent: GuiObject)
	local self = setmetatable({}, Toast)

	local stack = Instance.new("Frame")
	stack.Name = "Toasts"
	stack.BackgroundTransparency = 1
	stack.Position = UDim2.new(0, 16, 0, 118)
	stack.Size = UDim2.fromOffset(CARD_WIDTH + 40, (CARD_HEIGHT + 8) * MAX_CARDS)
	stack.Parent = parent
	local list = Components.List(stack, Enum.FillDirection.Vertical, 8)
	list.VerticalAlignment = Enum.VerticalAlignment.Top
	self._stack = stack
	self._order = 0

	local banner = Instance.new("Frame")
	banner.Name = "Banner"
	banner.BackgroundColor3 = Color3.fromRGB(8, 9, 12)
	banner.BackgroundTransparency = 0.25
	banner.BorderSizePixel = 0
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 92)
	banner.Size = UDim2.fromOffset(760, 84)
	banner.Visible = false
	banner.ZIndex = Theme.Layer.Toast
	banner.Parent = parent
	-- A band that fades out at both ends, the way the reference's round banners sit.
	local wash = Instance.new("UIGradient")
	wash.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.22, 0.1),
		NumberSequenceKeypoint.new(0.78, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	wash.Parent = banner
	local edgeTop = Instance.new("Frame")
	edgeTop.BorderSizePixel = 0
	edgeTop.Size = UDim2.new(1, 0, 0, 3)
	edgeTop.Parent = banner
	local edgeBottom = edgeTop:Clone()
	edgeBottom.AnchorPoint = Vector2.new(0, 1)
	edgeBottom.Position = UDim2.fromScale(0, 1)
	edgeBottom.Parent = banner
	for _, edge in ipairs({ edgeTop, edgeBottom }) do
		local fade = wash:Clone()
		fade.Parent = edge
	end

	local title = Components.Label(banner, {
		text = "",
		face = Theme.Face.HeavyItalic,
		size = 42,
		align = Enum.TextXAlignment.Center,
		outline = 4,
	})
	title.Position = UDim2.fromOffset(0, 4)
	title.Size = UDim2.new(1, 0, 0, 46)
	title.ZIndex = banner.ZIndex + 1
	local titleGradient = Instance.new("UIGradient")
	titleGradient.Rotation = 90
	titleGradient.Parent = title
	local titleScale = Instance.new("UIScale")
	titleScale.Parent = title

	local subtitle = Components.Label(banner, {
		text = "",
		face = Theme.Face.Condensed,
		size = 20,
		align = Enum.TextXAlignment.Center,
		outline = 2,
	})
	subtitle.Position = UDim2.fromOffset(0, 52)
	subtitle.Size = UDim2.new(1, 0, 0, 24)
	subtitle.ZIndex = banner.ZIndex + 1

	self._banner, self._bannerTitle, self._bannerSub = banner, title, subtitle
	self._bannerGradient, self._bannerScale = titleGradient, titleScale
	self._bannerEdges = { edgeTop, edgeBottom }
	self._bannerQueue = {} :: { BannerOptions }
	self._bannerBusy = false
	return self
end

--- A small card on the left.
function Toast:Push(options: PushOptions)
	local colour = options.colour or Theme.Colour.Info
	self._order += 1

	-- Drop the oldest when the stack is full.
	local cards = {}
	for _, child in ipairs(self._stack:GetChildren()) do
		if child:IsA("Frame") then
			table.insert(cards, child)
		end
	end
	table.sort(cards, function(a, b)
		return a.LayoutOrder < b.LayoutOrder
	end)
	while #cards >= MAX_CARDS do
		table.remove(cards, 1):Destroy()
	end

	local holder = Instance.new("Frame")
	holder.Name = "Toast"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(CARD_WIDTH, CARD_HEIGHT)
	holder.LayoutOrder = self._order
	holder.Parent = self._stack

	local card = Instance.new("Frame")
	card.Name = "Card"
	card.BackgroundColor3 = Theme.Colour.Panel
	card.BackgroundTransparency = 0.12
	card.BorderSizePixel = 0
	card.Size = UDim2.fromScale(1, 1)
	card.Position = UDim2.fromOffset(-CARD_WIDTH - 30, 0)
	card.Parent = holder
	Components.Corner(card, 10)
	Components.Stroke(card, Theme.Colour.Outline, 2)

	local bar = Instance.new("Frame")
	bar.Name = "Accent"
	bar.BackgroundColor3 = colour
	bar.BorderSizePixel = 0
	bar.Size = UDim2.new(0, 6, 1, -12)
	bar.Position = UDim2.fromOffset(6, 6)
	bar.Parent = card
	Components.Corner(bar, 3)

	local icon = Components.Icon(card, options.icon or "⭐", 26)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 18, 0.5, 0)

	local title = Components.Label(card, {
		text = options.title,
		face = Theme.Face.Condensed,
		size = 19,
		colour = colour:Lerp(Color3.new(1, 1, 1), 0.25),
		outline = 2,
	})
	title.Position = UDim2.fromOffset(54, options.text and 4 or 13)
	title.Size = UDim2.new(1, -62, 0, 22)
	title.TextTruncate = Enum.TextTruncate.AtEnd

	if options.text then
		local text = Components.Label(card, {
			text = options.text,
			size = Theme.Text.Small,
			colour = Theme.Colour.TextDim,
			outline = 1.2,
		})
		text.Position = UDim2.fromOffset(54, 26)
		text.Size = UDim2.new(1, -62, 0, 18)
		text.TextTruncate = Enum.TextTruncate.AtEnd
	end

	if options.progress then
		local track = Instance.new("Frame")
		track.BackgroundColor3 = Theme.Colour.Sunken
		track.BorderSizePixel = 0
		track.AnchorPoint = Vector2.new(0, 1)
		track.Position = UDim2.new(0, 54, 1, -5)
		track.Size = UDim2.new(1, -66, 0, 4)
		track.Parent = card
		Components.Corner(track, 2)
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = colour
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(math.clamp(options.progress, 0, 1), 1)
		fill.Parent = track
		Components.Corner(fill, 2)
	end

	TweenService:Create(card, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Position = UDim2.fromOffset(0, 0) }):Play()
	UISound.Play("Tick", 1.2, 0.35)

	task.delay(options.duration or 4, function()
		if not holder.Parent then
			return
		end
		local out = TweenService:Create(card, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ Position = UDim2.fromOffset(-CARD_WIDTH - 30, 0) })
		out.Completed:Once(function()
			holder:Destroy()
		end)
		out:Play()
	end)
end

--- The big banner across the top. Banners queue rather than overwrite each other.
function Toast:Banner(options: BannerOptions)
	table.insert(self._bannerQueue, options)
	if not self._bannerBusy then
		self:_nextBanner()
	end
end

function Toast:_nextBanner()
	local options = table.remove(self._bannerQueue, 1)
	if not options then
		self._bannerBusy = false
		return
	end
	self._bannerBusy = true
	local colour = options.colour or Theme.Colour.Level
	local banner = self._banner
	self._bannerTitle.Text = options.title
	self._bannerSub.Text = options.subtitle or ""
	self._bannerGradient.Color = ColorSequence.new(colour:Lerp(Color3.new(1, 1, 1), 0.55), colour)
	for _, edge in ipairs(self._bannerEdges) do
		edge.BackgroundColor3 = colour
	end

	banner.Visible = true
	banner.BackgroundTransparency = 1
	self._bannerTitle.TextTransparency = 1
	self._bannerSub.TextTransparency = 1
	self._bannerScale.Scale = 1.8
	TweenService:Create(banner, TweenInfo.new(0.2), { BackgroundTransparency = 0.25 }):Play()
	TweenService:Create(self._bannerTitle, TweenInfo.new(0.12), { TextTransparency = 0 }):Play()
	TweenService:Create(self._bannerScale, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }):Play()
	TweenService:Create(self._bannerSub, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.15),
		{ TextTransparency = 0 }):Play()
	UISound.Play(options.sound or "Slam", 1, 0.5)

	task.delay(options.duration or 3.2, function()
		local fade = TweenInfo.new(0.3)
		TweenService:Create(banner, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(self._bannerTitle, fade, { TextTransparency = 1 }):Play()
		local last = TweenService:Create(self._bannerSub, fade, { TextTransparency = 1 })
		last.Completed:Once(function()
			banner.Visible = false
			self:_nextBanner()
		end)
		last:Play()
	end)
end

function Toast:SetVisible(visible: boolean)
	self._stack.Visible = visible
end

return Toast
