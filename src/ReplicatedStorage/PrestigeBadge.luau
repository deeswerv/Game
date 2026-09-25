--!strict
-- The level badge, and the prestige emblem around it.
--
-- Drawn from Frames rather than an image, for three reasons: it stays crisp at any size
-- from a 28px player-list row to a 120px prestige screen, a new prestige tier is a config
-- entry rather than an art request, and it needs no upload -- which matters here, because
-- assets uploaded by someone else do not load in this place (two free-model animations had
-- to be removed for exactly that reason).
--
-- The silhouette is deliberately identical at every tier. Only the metal and the number of
-- points change, so the badge is recognisable at a glance and the tier is read from its
-- colour rather than from having to identify a different shape each time.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local GameConfig = require(ReplicatedStorage.GameConfig)

local PrestigeBadge = {}

export type Badge = {
	root: Frame,
	SetLevel: (self: Badge, level: number) -> (),
	SetPrestige: (self: Badge, prestige: number) -> (),
	Pulse: (self: Badge) -> (),
}

--- Build a badge inside `parent`. `size` is the square edge in pixels.
function PrestigeBadge.Create(parent: GuiObject, size: number): Badge
	local root = Instance.new("Frame")
	root.Name = "PrestigeBadge"
	root.Size = UDim2.fromOffset(size, size)
	root.BackgroundTransparency = 1
	root.Active = false
	root.Parent = parent

	-- Points radiate from behind the disc. Built once at the maximum any tier uses and
	-- shown or hidden per tier, so changing prestige never rebuilds instances.
	local MAX_POINTS = 8
	local points: { Frame } = {}
	for i = 1, MAX_POINTS do
		local spike = Instance.new("Frame")
		spike.Name = "Point" .. i
		spike.AnchorPoint = Vector2.new(0.5, 0.5)
		spike.Size = UDim2.fromOffset(math.max(3, size * 0.11), math.max(3, size * 0.11))
		spike.Rotation = 45
		spike.BorderSizePixel = 0
		spike.Visible = false
		spike.Active = false
		spike.ZIndex = (parent.ZIndex or 1) + 1
		spike.Parent = root
		points[i] = spike
	end

	-- Outer ring.
	local ring = Instance.new("Frame")
	ring.Name = "Ring"
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(size * 0.86, size * 0.86)
	ring.BorderSizePixel = 0
	ring.Active = false
	ring.ZIndex = (parent.ZIndex or 1) + 2
	ring.Parent = root
	local ringCorner = Instance.new("UICorner")
	ringCorner.CornerRadius = UDim.new(1, 0)
	ringCorner.Parent = ring

	-- Face, inset inside the ring so the ring reads as a rim rather than an outline.
	local face = Instance.new("Frame")
	face.Name = "Face"
	face.AnchorPoint = Vector2.new(0.5, 0.5)
	face.Position = UDim2.fromScale(0.5, 0.5)
	face.Size = UDim2.fromScale(0.82, 0.82)
	face.BackgroundColor3 = Color3.fromRGB(18, 19, 25)
	face.BorderSizePixel = 0
	face.Active = false
	face.ZIndex = (parent.ZIndex or 1) + 3
	face.Parent = ring
	local faceCorner = Instance.new("UICorner")
	faceCorner.CornerRadius = UDim.new(1, 0)
	faceCorner.Parent = face

	-- A top-down sheen on the rim so the metal looks lit rather than printed.
	local ringShade = Instance.new("UIGradient")
	ringShade.Rotation = 90
	ringShade.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.new(1, 1, 1)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 150, 150)),
	})
	ringShade.Parent = ring

	local levelText = Instance.new("TextLabel")
	levelText.Name = "Level"
	levelText.Size = UDim2.fromScale(1, 1)
	levelText.BackgroundTransparency = 1
	levelText.Font = Enum.Font.GothamBlack
	levelText.TextScaled = true
	levelText.TextColor3 = Color3.fromRGB(244, 244, 240)
	levelText.Text = "1"
	levelText.ZIndex = (parent.ZIndex or 1) + 4
	levelText.Parent = face
	local textPad = Instance.new("UIPadding")
	local inset = math.max(2, size * 0.2)
	textPad.PaddingTop = UDim.new(0, inset)
	textPad.PaddingBottom = UDim.new(0, inset)
	textPad.PaddingLeft = UDim.new(0, inset)
	textPad.PaddingRight = UDim.new(0, inset)
	textPad.Parent = levelText

	local scale = Instance.new("UIScale")
	scale.Parent = root

	local badge = {} :: any
	badge.root = root

	function badge:SetLevel(level: number)
		levelText.Text = tostring(math.max(1, math.floor(level or 1)))
	end

	function badge:SetPrestige(prestige: number)
		local tier = GameConfig.GetPrestigeTier(prestige or 0)
		ring.BackgroundColor3 = tier.colour

		local count = tier.points or 0
		for i, spike in ipairs(points) do
			if i <= count then
				spike.Visible = true
				spike.BackgroundColor3 = tier.ring
				-- Spread evenly, first point at the top.
				local angle = (i - 1) / count * math.pi * 2 - math.pi / 2
				local radius = size * 0.45
				spike.Position = UDim2.new(
					0.5, math.cos(angle) * radius,
					0.5, math.sin(angle) * radius
				)
			else
				spike.Visible = false
			end
		end
	end

	--- A short bounce, for a level-up or a prestige.
	function badge:Pulse()
		scale.Scale = 1
		TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Scale = 1.22,
		}):Play()
		task.delay(0.18, function()
			if scale.Parent then
				TweenService:Create(scale, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
					Scale = 1,
				}):Play()
			end
		end)
	end

	badge:SetPrestige(0)
	badge:SetLevel(1)
	return badge
end

return PrestigeBadge
