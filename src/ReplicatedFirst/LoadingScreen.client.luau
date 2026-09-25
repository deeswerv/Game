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
local PANEL = Color3.fromRGB(23, 26, 33)
local STROKE = Color3.fromRGB(46, 52, 65)
local TEXT = Color3.fromRGB(255, 255, 255)
local TEXT_DIM = Color3.fromRGB(167, 174, 188)
local ACCENT = Color3.fromRGB(55, 214, 122)

local MAX_WAIT = 20          -- hard ceiling on the whole screen, whatever else happens
-- Long enough that the screen is read rather than flashed, and no longer. It was 8, from
-- back when the profile took ~2s to load and the number was picked by hand; with HD Admin's
-- boot-time asset fetch gone the profile lands in under a second, so 8 was six seconds of
-- staring at a finished bar. A loading screen that waits for nothing is just a toll gate.
local MIN_SHOW = 2.2

-- ------------------------------------------------------------------ build --

local screen = Instance.new("ScreenGui")
screen.Name = "LoadingScreen"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.DisplayOrder = 1000        -- above everything, including the killcam
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.BackgroundColor3 = SCRIM
backdrop.BorderSizePixel = 0
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.Parent = screen

local card = Instance.new("Frame")
card.Name = "Card"
card.BackgroundColor3 = PANEL
card.BorderSizePixel = 0
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.5)
card.Size = UDim2.fromOffset(420, 150)
card.Parent = backdrop

local corner = Instance.new("UICorner")
corner.CornerRadius = UDim.new(0, 14)
corner.Parent = card

local stroke = Instance.new("UIStroke")
stroke.Color = STROKE
stroke.Thickness = 1
stroke.Parent = card

local title = Instance.new("TextLabel")
title.BackgroundTransparency = 1
title.Font = Enum.Font.GothamBlack
title.Text = "PROJECT ZEE"
title.TextSize = 30
title.TextColor3 = TEXT
title.Size = UDim2.new(1, 0, 0, 34)
title.Position = UDim2.fromOffset(0, 30)
title.Parent = card

local status = Instance.new("TextLabel")
status.Name = "Status"
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamMedium
status.Text = "Connecting"
status.TextSize = 13
status.TextColor3 = TEXT_DIM
status.Size = UDim2.new(1, 0, 0, 16)
status.Position = UDim2.fromOffset(0, 68)
status.Parent = card

local track = Instance.new("Frame")
track.BackgroundColor3 = SCRIM
track.BorderSizePixel = 0
track.AnchorPoint = Vector2.new(0.5, 0)
track.Position = UDim2.new(0.5, 0, 0, 102)
track.Size = UDim2.fromOffset(340, 4)
track.Parent = card
local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(1, 0)
trackCorner.Parent = track

local fill = Instance.new("Frame")
fill.BackgroundColor3 = ACCENT
fill.BorderSizePixel = 0
fill.Size = UDim2.fromScale(0, 1)
fill.Parent = track
local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(1, 0)
fillCorner.Parent = fill

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
	fill.Size = UDim2.fromScale(math.clamp(math.min(stageTarget, byTime), 0, 1), 1)
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

	local fade = TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	TweenService:Create(backdrop, fade, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(card, fade, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(stroke, fade, { Transparency = 1 }):Play()
	for _, label in ipairs({ title, status }) do
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
	end
	TweenService:Create(track, fade, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(fill, fade, { BackgroundTransparency = 1 }):Play()

	task.wait(0.5)
	barDriver:Disconnect()
	screen:Destroy()
	print(("[Loading] done in %.2fs"):format(elapsed()))
end)
