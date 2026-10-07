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
--
-- Behind it, Downtown itself: as soon as the district has streamed in, the dark screen opens
-- onto a slow camera drifting up the avenue toward ZEE TOWER, with the title, the bar and the
-- tips laid over it in letterbox. The camera is handed back when the screen comes down (the
-- intro film picks it up from there).

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
local MIN_SHOW = 3.2

-- Downtown (DistrictService.CENTRE) and ZEE TOWER, for the camera behind the screen.
local DOWNTOWN = Vector3.new(-155, 1000, 1500)
local TOWER_TOP = DOWNTOWN + Vector3.new(0, 120, 158)

-- What a first-time player most needs to know, one line at a time while they wait.
local TIPS = {
	"Press  M  to open the Shop and unlock new guns",
	"Hold  Right Click  to aim down sights",
	"Press  J  to queue for a 1v1 duel",
	"Press  K  to fit attachments in the Armory",
	"Press  N  to claim your free daily reward",
	"Press  B  to equip weapons from your Inventory",
	"Win a turf war and the street holds it -- and pays you tribute",
	"Rob a till twice in ten minutes and they know your face",
	"Restock bombs and plates from your Inventory, under Gear",
	"Beat the Don on top of ZEE TOWER to open Hanami City",
}

-- ------------------------------------------------------------------ build --

local screen = Instance.new("ScreenGui")
screen.Name = "LoadingScreen"
screen.IgnoreGuiInset = true
screen.ResetOnSpawn = false
screen.DisplayOrder = 1000        -- above everything, including the killcam
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.Parent = playerGui

-- One CanvasGroup holds everything, so the whole screen fades out as a single layer. It starts
-- as solid night; when Downtown is in, the night thins away and the city shows through.
local backdrop = Instance.new("CanvasGroup")
backdrop.Name = "Backdrop"
backdrop.BackgroundColor3 = SCRIM
backdrop.BorderSizePixel = 0
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.Parent = screen

-- The night: a full-screen cover the city is revealed from behind.
local night = Instance.new("Frame")
night.Name = "Night"
night.BackgroundColor3 = SCRIM
night.BorderSizePixel = 0
night.Size = UDim2.fromScale(1, 1)
night.Parent = backdrop

-- Slow diagonal stripes drifting across the night, so it is never a still image.
local stripes = Instance.new("Frame")
stripes.Name = "Stripes"
stripes.BackgroundTransparency = 1
stripes.AnchorPoint = Vector2.new(0.5, 0.5)
stripes.Position = UDim2.fromScale(0.5, 0.5)
stripes.Size = UDim2.fromScale(1.6, 1.6)
stripes.Rotation = -18
stripes.Parent = night
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

-- Shade top and bottom (over the city), and the letterbox bars.
local function shade(name: string, top: boolean)
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.AnchorPoint = Vector2.new(0, if top then 0 else 1)
	f.Position = UDim2.fromScale(0, if top then 0 else 1)
	f.Size = UDim2.fromScale(1, if top then 0.42 else 0.5)
	f.ZIndex = 2
	f.Parent = backdrop
	local g = Instance.new("UIGradient")
	g.Rotation = if top then 90 else -90
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(0.35, 0.45),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
end
shade("ShadeTop", true)
shade("ShadeBottom", false)
for _, top in ipairs({ true, false }) do
	local bar = Instance.new("Frame")
	bar.Name = if top then "BarTop" else "BarBottom"
	bar.BackgroundColor3 = Color3.new(0, 0, 0)
	bar.BorderSizePixel = 0
	bar.AnchorPoint = Vector2.new(0, if top then 0 else 1)
	bar.Position = UDim2.fromScale(0, if top then 0 else 1)
	bar.Size = UDim2.fromScale(1, 0.06)
	bar.ZIndex = 3
	bar.Parent = backdrop
end

local function edge(label: GuiObject, thickness: number, colour: Color3?)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Color = colour or OUTLINE
	s.Thickness = thickness
	s.LineJoinMode = Enum.LineJoinMode.Round
	s.Parent = label
end

local function corner(g: GuiObject, r: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, r)
	c.Parent = g
end

local card = Instance.new("Frame")
card.Name = "Card"
card.BackgroundTransparency = 1
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.4)
card.Size = UDim2.fromOffset(700, 170)
card.ZIndex = 4
card.Parent = backdrop

local titleRow = Instance.new("Frame")
titleRow.BackgroundTransparency = 1
titleRow.Size = UDim2.new(1, 0, 0, 100)
titleRow.ZIndex = 4
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
	label.TextSize = 92
	label.TextColor3 = TEXT
	label.AutomaticSize = Enum.AutomaticSize.XY
	label.Size = UDim2.fromOffset(0, 0)
	label.LayoutOrder = order
	label.ZIndex = 4
	label.Parent = titleRow
	edge(label, 6)
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

-- Where you are going: a dark pill with a gold edge under the title.
local place = Instance.new("Frame")
place.Name = "Place"
place.AnchorPoint = Vector2.new(0.5, 0)
place.Position = UDim2.new(0.5, 0, 0, 110)
place.Size = UDim2.fromOffset(0, 36)
place.AutomaticSize = Enum.AutomaticSize.X
place.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
place.BackgroundTransparency = 0.15
place.BorderSizePixel = 0
place.ZIndex = 4
place.Parent = card
corner(place, 18)
local placeStroke = Instance.new("UIStroke")
placeStroke.Color = GOLD_BOTTOM
placeStroke.Thickness = 1.5
placeStroke.Transparency = 0.25
placeStroke.Parent = place
local placePad = Instance.new("UIPadding")
placePad.PaddingLeft = UDim.new(0, 18)
placePad.PaddingRight = UDim.new(0, 18)
placePad.Parent = place
local placeText = Instance.new("TextLabel")
placeText.Name = "Text"
placeText.BackgroundTransparency = 1
placeText.Font = Enum.Font.GothamBlack
placeText.Text = "NOW ENTERING  ·  DOWNTOWN"
placeText.TextSize = 18
placeText.TextColor3 = TEXT
placeText.AutomaticSize = Enum.AutomaticSize.X
placeText.Size = UDim2.fromScale(0, 1)
placeText.ZIndex = 5
placeText.Parent = place

-- The foot: status on the left, the percentage on the right, a thin glowing bar between.
local foot = Instance.new("Frame")
foot.Name = "Foot"
foot.BackgroundTransparency = 1
foot.AnchorPoint = Vector2.new(0.5, 1)
foot.Position = UDim2.new(0.5, 0, 0.94, -26)
foot.Size = UDim2.new(0.62, 0, 0, 64)
foot.ZIndex = 4
foot.Parent = backdrop

local status = Instance.new("TextLabel")
status.Name = "Status"
status.BackgroundTransparency = 1
status.Font = Enum.Font.GothamBold
status.Text = "Connecting"
status.TextSize = 18
status.TextColor3 = TEXT_DIM
status.TextXAlignment = Enum.TextXAlignment.Left
status.Size = UDim2.new(0.6, 0, 0, 22)
status.Position = UDim2.fromOffset(0, 30)
status.ZIndex = 4
status.Parent = foot
edge(status, 1.5)

local percent = Instance.new("TextLabel")
percent.Name = "Percent"
percent.BackgroundTransparency = 1
percent.Font = Enum.Font.FredokaOne
percent.Text = "0%"
percent.TextSize = 22
percent.TextColor3 = TEXT
percent.TextXAlignment = Enum.TextXAlignment.Right
percent.AnchorPoint = Vector2.new(1, 0)
percent.Position = UDim2.new(1, 0, 0, 28)
percent.Size = UDim2.new(0.3, 0, 0, 24)
percent.ZIndex = 4
percent.Parent = foot
edge(percent, 2)

local track = Instance.new("Frame")
track.Name = "Track"
track.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
track.BackgroundTransparency = 0.82
track.BorderSizePixel = 0
track.AnchorPoint = Vector2.new(0, 1)
track.Position = UDim2.fromScale(0, 1)
track.Size = UDim2.new(1, 0, 0, 6)
track.ZIndex = 4
track.Parent = foot
corner(track, 3)

local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
fill.BorderSizePixel = 0
fill.Size = UDim2.fromScale(0, 1)
fill.ZIndex = 5
fill.Parent = track
corner(fill, 3)
local fillColour = Instance.new("UIGradient")
fillColour.Color = ColorSequence.new(GOLD_BOTTOM, ACCENT)
fillColour.Parent = fill
-- A soft glow under the fill.
local glowBar = Instance.new("Frame")
glowBar.Name = "Glow"
glowBar.BackgroundColor3 = ACCENT
glowBar.BackgroundTransparency = 0.7
glowBar.BorderSizePixel = 0
glowBar.AnchorPoint = Vector2.new(0, 0.5)
glowBar.Position = UDim2.fromScale(0, 0.5)
glowBar.Size = UDim2.new(1, 0, 0, 16)
glowBar.ZIndex = 4
glowBar.Parent = fill
corner(glowBar, 8)
local glowFade = Instance.new("UIGradient")
glowFade.Rotation = 90
glowFade.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0.2), NumberSequenceKeypoint.new(1, 1),
})
glowFade.Parent = glowBar

-- A spinner in the corner, so a stalled stage still visibly lives.
local spinner = Instance.new("Frame")
spinner.Name = "Spinner"
spinner.BackgroundTransparency = 1
spinner.AnchorPoint = Vector2.new(1, 1)
spinner.Position = UDim2.new(1, -34, 0.94, -24)
spinner.Size = UDim2.fromOffset(30, 30)
spinner.ZIndex = 4
spinner.Parent = backdrop
corner(spinner, 15)
local spinStroke = Instance.new("UIStroke")
spinStroke.Color = GOLD_TOP
spinStroke.Thickness = 3
spinStroke.Parent = spinner
local spinGrad = Instance.new("UIGradient")
spinGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.6), NumberSequenceKeypoint.new(1, 1),
})
spinGrad.Parent = spinStroke

local tip = Instance.new("TextLabel")
tip.Name = "Tip"
tip.BackgroundTransparency = 1
tip.Font = Enum.Font.GothamBold
tip.Text = ""
tip.TextSize = 19
tip.TextColor3 = TEXT
tip.AnchorPoint = Vector2.new(0.5, 1)
tip.Position = UDim2.new(0.5, 0, 0.94, -104)
tip.Size = UDim2.new(0.8, 0, 0, 24)
tip.RichText = true
tip.ZIndex = 4
tip.Parent = backdrop
edge(tip, 1.6)

-- Where the camera is, top left under the bar.
local caption = Instance.new("TextLabel")
caption.Name = "Caption"
caption.BackgroundTransparency = 1
caption.Font = Enum.Font.GothamBlack
caption.Text = ""
caption.TextSize = 15
caption.TextColor3 = TEXT_DIM
caption.TextXAlignment = Enum.TextXAlignment.Left
caption.AnchorPoint = Vector2.new(0, 0)
caption.Position = UDim2.new(0, 34, 0.06, 18)
caption.Size = UDim2.fromOffset(420, 20)
caption.ZIndex = 4
caption.Parent = backdrop
edge(caption, 1.4)

task.spawn(function()
	local index = math.random(1, #TIPS)
	while screen.Parent do
		tip.Text = '<font color="#FFC428">TIP</font>   ' .. TIPS[index]
		tip.TextTransparency = 1
		TweenService:Create(tip, TweenInfo.new(0.3), { TextTransparency = 0 }):Play()
		task.wait(2.6)
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

-- ---------------------------------------------------------------- the city --

-- Behind the screen: Downtown, once it is here. The camera drifts up the avenue toward ZEE
-- TOWER; the night thins away to show it. Bounded like everything else -- no Downtown, no
-- reveal, and the screen is just the screen.
local camera = workspace.CurrentCamera
local cityShown = false
local cityStarted = 0
local cameraTaken = false

local function cityCamera(t: number): CFrame
	local z = -132 + t * 2.6
	local x = math.sin(t * 0.18) * 10
	local at = DOWNTOWN + Vector3.new(x, 30 + t * 0.6, z)
	return CFrame.lookAt(at, TOWER_TOP + Vector3.new(0, -t * 1.5, 0))
end

task.spawn(function()
	local downtown = nil
	while not downtown and screen.Parent do
		downtown = workspace:FindFirstChild("Downtown")
		if not downtown then
			task.wait(0.2)
		end
	end
	if not downtown or not screen.Parent then
		return
	end
	-- Have the district streamed in around the camera's path (streaming is on).
	local streamed = false
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(DOWNTOWN + Vector3.new(0, 0, -90), 4)
		end)
		streamed = true
	end)
	local waited = os.clock()
	while not streamed and os.clock() - waited < 4 and screen.Parent do
		task.wait(0.1)
	end
	if not screen.Parent or not camera then
		return
	end
	cameraTaken = true
	cityStarted = os.clock()
	camera.CameraType = Enum.CameraType.Scriptable
	camera.FieldOfView = 62
	camera.CFrame = cityCamera(0)
	cityShown = true
	caption.Text = "DOWNTOWN  ·  ZEE TOWER"
	TweenService:Create(night, TweenInfo.new(1.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	TweenService:Create(backdrop, TweenInfo.new(1.2), { BackgroundTransparency = 1 }):Play()
	for _, band in ipairs(stripes:GetChildren()) do
		if band:IsA("Frame") then
			TweenService:Create(band, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()
		end
	end
end)

-- ---------------------------------------------------------------- loading --

local started = os.clock()

local function elapsed(): number
	return os.clock() - started
end

print("[Loading] screen shown")

-- One place drives the bar, every frame, from those two numbers. Nothing else writes its
-- size, so the stages cannot fight the hold over it.
local barDriver = RunService.RenderStepped:Connect(function(dt: number)
	-- The bar shows real progress, with time only as a floor on how fast it may APPEAR to
	-- move: a bar that jumps to full in one frame reads as broken rather than fast.
	local byTime = elapsed() / MIN_SHOW
	local shown = math.clamp(math.min(stageTarget, byTime), 0, 1)
	fill.Size = UDim2.fromScale(shown, 1)
	percent.Text = string.format("%d%%", math.floor(shown * 100 + 0.5))
	spinGrad.Rotation = (spinGrad.Rotation + dt * 360) % 360
	if cityShown and camera then
		camera.CFrame = cityCamera(os.clock() - cityStarted)
	end
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
	-- Hand the camera back (the intro film, if there is one, takes it from here).
	if cameraTaken and camera then
		camera.CameraType = Enum.CameraType.Custom
		camera.FieldOfView = 70
		local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			camera.CameraSubject = humanoid
		end
	end
	screen:Destroy()
	print(("[Loading] done in %.2fs"):format(elapsed()))
end)
