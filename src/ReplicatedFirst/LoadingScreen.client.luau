--!strict
-- The first thing a player sees.
--
-- DELIBERATELY SELF-CONTAINED. This runs out of ReplicatedFirst, which executes before the
-- rest of the game has replicated -- so it must not require anything from ReplicatedStorage.
-- A WaitForChild on the UI modules here would block on exactly the loading this screen
-- exists to cover, and the player would stare at a frozen default screen instead. The few
-- palette values below are therefore copied from Theme rather than read from it; they are
-- the only duplicated constants in the interface and this comment is why.
--
-- It also never traps the player. Every exit path is time-bounded: if preloading stalls, if
-- the character never arrives, if an asset is broken, the screen still comes down.

local ContentProvider = game:GetService("ContentProvider")
local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

ReplicatedFirst:RemoveDefaultLoadingScreen()

-- Copied from Theme -- see the header.
local SCRIM = Color3.fromRGB(8, 10, 14)
local OUTLINE = Color3.fromRGB(8, 8, 12)
local TEXT = Color3.fromRGB(255, 255, 255)
local TEXT_DIM = Color3.fromRGB(186, 190, 200)
local ACCENT = Color3.fromRGB(46, 204, 84)
local GOLD_TOP = Color3.fromRGB(255, 240, 120)
local GOLD_BOTTOM = Color3.fromRGB(255, 160, 20)

local MAX_WAIT = 20          -- hard ceiling on the whole screen, whatever else happens
-- Long enough that the screen is read rather than flashed, and no longer.
local MIN_SHOW = 2.6

-- What a first-time player most needs to know, one line at a time while they wait.
local TIPS = {
	"Press  M  to open the Shop and unlock new guns",
	"Hold  Right Click  to aim down sights",
	"Press  J  to queue for a 1v1 duel",
	"Press  K  to fit attachments in the Armory",
	"Press  N  to claim your free daily reward",
	"Press  B  to equip weapons from your Inventory",
}

-- ------------------------------------------------------------------ build --

local screen = Instance.new("ScreenGui")
screen.Name = "LoadingScreen"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.DisplayOrder = 1000        -- above everything, including the killcam
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

-- One CanvasGroup holds everything, so the whole screen fades out as a single layer.
local backdrop = Instance.new("CanvasGroup")
backdrop.Name = "Backdrop"
backdrop.BackgroundColor3 = SCRIM
backdrop.BorderSizePixel = 0
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.Parent = screen

-- A soft lift in the middle so the title sits in light rather than on flat black.
local glow = Instance.new("UIGradient")
glow.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 120, 130)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 120, 130)),
})
glow.Rotation = 90
glow.Parent = backdrop

-- Slow diagonal stripes drifting across, so the screen is never a still image.
local stripes = Instance.new("Frame")
stripes.Name = "Stripes"
stripes.BackgroundTransparency = 1
stripes.AnchorPoint = Vector2.new(0.5, 0.5)
stripes.Position = UDim2.fromScale(0.5, 0.5)
stripes.Size = UDim2.fromScale(1.6, 1.6)
stripes.Rotation = -18
stripes.Parent = backdrop
for i = 0, 11 do
	local band = Instance.new("Frame")
	band.BackgroundColor3 = Color3.fromRGB(40, 44, 58)
	band.BackgroundTransparency = 0.55
	band.BorderSizePixel = 0
	band.Size = UDim2.new(0.035, 0, 1, 0)
	band.Position = UDim2.fromScale(i / 12, 0)
	band.Parent = stripes
end
TweenService:Create(stripes, TweenInfo.new(18, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1), {
	Position = UDim2.fromScale(0.5 + 1 / 12 * 1.6, 0.5),
}):Play()

local function edge(label: GuiObject, thickness: number, colour: Color3?)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Color = colour or OUTLINE
	s.Thickness = thickness
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = label
end

local card = Instance.new("Frame")
card.Name = "Card"
card.BackgroundTransparency = 1
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.46)
card.Size = UDim2.fromOffset(640, 260)
card.Parent = backdrop

local titleRow = Instance.new("Frame")
titleRow.BackgroundTransparency = 1
titleRow.Size = UDim2.new(1, 0, 0, 96)
titleRow.Parent = card
local titleList = Instance.new("UIListLayout")
titleList.FillDirection = Enum.FillDirection.Horizontal
titleList.HorizontalAlignment = Enum.HorizontalAlignment.Center
titleList.VerticalAlignment = Enum.VerticalAlignment.Center
titleList.Padding = UDim.new(0, 18)
titleList.SortOrder = Enum.SortOrder.LayoutOrder
titleList.Parent = titleRow

local function titleWord(text: string, order: number, gold: boolean): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = text
	label.TextSize = 84
	label.TextColor3 = TEXT
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.LayoutOrder = order
	label.Parent = titleRow
	edge(label, 5)
	if gold then
		local g = Instance.new("UIGradient")
		g.Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM)
		g.Rotation = 90
		g.Parent = label
	end
	return label
end
titleWord("PROJECT", 1, false)
titleWord("ZEE", 2, true)

local titleScale = Instance.new("UIScale")
titleScale.Scale = 0.6
titleScale.Parent = titleRow
TweenService:Create(titleScale, TweenInfo.new(0.6, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()

local status = Instance.new("TextLabel")
status.Name = "Status"
status.BackgroundTransparency = 1
status.Font = Enum.Font.SourceSansBold
status.Text = "Connecting"
status.TextSize = 24
status.TextColor3 = TEXT_DIM
status.Size = UDim2.new(1, 0, 0, 28)
status.Position = UDim2.fromOffset(0, 112)
status.Parent = card
edge(status, 1.8)

local track = Instance.new("Frame")
track.BackgroundColor3 = Color3.fromRGB(20, 22, 26)
track.BorderSizePixel = 0
track.AnchorPoint = Vector2.new(0.5, 0)
track.Position = UDim2.new(0.5, 0, 0, 152)
track.Size = UDim2.fromOffset(460, 26)
track.Parent = card
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(0, 9)
trackCorner.Parent = track
local rim = Instance.new("UIStroke")
rim.Color = OUTLINE
rim.Thickness = 3
rim.Parent = track

local fill = Instance.new("Frame")
fill.BackgroundColor3 = ACCENT
fill.BorderSizePixel = 0
fill.Size = UDim2.fromScale(0, 1)
fill.Parent = track
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 9)
fillCorner.Parent = fill
local sheen = Instance.new("UIGradient")
sheen.Color = ColorSequence.new(Color3.fromRGB(220, 255, 220), Color3.fromRGB(150, 180, 150))
sheen.Rotation = 90
sheen.Parent = fill

local percent = Instance.new("TextLabel")
percent.BackgroundTransparency = 1
percent.Font = Enum.Font.FredokaOne
percent.Text = "0%"
percent.TextSize = 18
percent.TextColor3 = TEXT
percent.Size = UDim2.fromScale(1, 1)
percent.ZIndex = 3
percent.Parent = track
edge(percent, 2)

local tip = Instance.new("TextLabel")
tip.Name = "Tip"
tip.BackgroundTransparency = 1
tip.Font = Enum.Font.SourceSansBold
tip.Text = ""
tip.TextSize = 22
tip.TextColor3 = Color3.fromRGB(255, 196, 40)
tip.Size = UDim2.new(1, 0, 0, 26)
tip.Position = UDim2.fromOffset(0, 206)
tip.Parent = card
edge(tip, 1.8)

task.spawn(function()
	local index = math.random(1, #TIPS)
	while screen.Parent do
		tip.Text = "TIP:  " .. TIPS[index]
		tip.TextTransparency = 1
		TweenService:Create(tip, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		task.wait(2.4)
		index = index % #TIPS + 1
	end
end)

-- The bar shows the SLOWER of two things: how much has actually loaded, and how far through
-- the minimum hold we are. Without the second, a fast join fills the bar in two seconds and
-- then leaves it sitting full and motionless for the rest of the hold, which reads as frozen
-- rather than as loading. Without the first, a genuinely slow join would show a full bar
-- while still waiting. Taking the minimum is correct in both directions.
local stageTarget = 0

local function setStage(fraction: number, text: string?)
	stageTarget = math.clamp(fraction, 0, 1)
	if text then
		status.Text = text
	end
end

-- ---------------------------------------------------------------- loading --

local started = os.clock()

local function elapsed(): number
	return os.clock() - started
end

print("[Loading] screen shown")

-- One place drives the bar, every frame, from those two numbers. Nothing else writes its
-- size, so the stages cannot fight the hold over it.
local barDriver = RunService.RenderStepped:Connect(function()
	-- The bar shows real progress, with time only as a floor on how fast it may APPEAR to
	-- move: a bar that jumps to full in one frame reads as broken rather than fast.
	local byTime = elapsed() / MIN_SHOW
	local shown = math.clamp(math.min(stageTarget, byTime), 0, 1)
	fill.Size = UDim2.fromScale(shown, 1)
	percent.Text = string.format("%d%%", math.floor(shown * 100 + 0.5))
end)

task.spawn(function()
	-- 1. The game itself.
	setStage(0.1, "Connecting")
	if not game:IsLoaded() then
		local loaded = false
		task.spawn(function()
			game.Loaded:Wait()
			loaded = true
		end)
		while not loaded and elapsed() < MAX_WAIT * 0.5 do
			task.wait(0.1)
		end
	end
	setStage(0.35, "Loading the world")

	-- 2. Preload what the player sees first. Only things that already exist -- this never
	--    invents an asset id, and a missing folder simply means less to preload.
	local queue: { Instance } = {}
	local lobby = workspace:FindFirstChild("Lobby")
	if lobby then
		for _, d in ipairs(lobby:GetDescendants()) do
			if d:IsA("Decal") or d:IsA("Texture") or d:IsA("Sound") then
				table.insert(queue, d)
			end
		end
	end

	if #queue > 0 then
		-- PreloadAsync is synchronous and can hang on a bad asset, so it runs on its own
		-- thread and the screen moves on when the budget expires rather than waiting on it.
		local done = false
		task.spawn(function()
			pcall(function()
				ContentProvider:PreloadAsync(queue)
			end)
			done = true
		end)
		while not done and elapsed() < MAX_WAIT * 0.8 do
			setStage(0.35 + 0.4 * math.clamp(elapsed() / (MAX_WAIT * 0.8), 0, 1))
			task.wait(0.1)
		end
	end
	setStage(0.8, "Dropping in")

	-- 3. A character to actually stand on.
	while not player.Character and elapsed() < MAX_WAIT do
		task.wait(0.1)
	end

	-- Everything real is done; the bar is now gated purely by the hold and keeps moving.
	setStage(1, "Preparing")
	while elapsed() < MIN_SHOW do
		task.wait(0.1)
	end

	status.Text = "Ready"
	task.wait(0.2)

	-- The whole screen is one CanvasGroup, so it fades as a single layer.
	TweenService:Create(backdrop, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		GroupTransparency = 1,
	}):Play()

	task.wait(0.5)
	barDriver:Disconnect()
	screen:Destroy()
	print(("[Loading] done in %.2fs"):format(elapsed()))
end)
