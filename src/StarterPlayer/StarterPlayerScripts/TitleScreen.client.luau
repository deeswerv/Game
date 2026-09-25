--!strict
-- The title screen: the first thing after the loading bar, once per session.
--
-- The camera flies slow passes over the best of the world -- Downtown's plaza, the Flats
-- battleground, a duel map, the harbour -- behind a PROJECT ZEE logo, a big PLAY button and
-- three shortcuts (straight into the 1v1 queue, straight to Downtown, straight to the Flats).
-- Your card sits on the right with your level, title and money, and under it what is new in
-- this update. PLAY (or Space, Enter, Escape) drops you in.
--
-- While it is up it counts as an open panel (UIState), so the HUD steps aside and the mouse
-- is free. Nothing here is required to play: every path out restores the camera, and if the
-- world never streams in the shots simply show sky.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("UI"):WaitForChild("Modules")
local Theme = require(Modules:WaitForChild("Theme"))
local Components = require(Modules:WaitForChild("Components"))
local UISound = require(Modules:WaitForChild("UISound"))
local UIState = require(ReplicatedStorage:WaitForChild("UIState"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- Wait for the loading screen to come down (it always does, within its own limit).
do
	local started = os.clock()
	while playerGui:FindFirstChild("LoadingScreen") and os.clock() - started < 25 do
		task.wait(0.1)
	end
end

local GOLD_TOP = Color3.fromRGB(255, 240, 120)
local GOLD_BOTTOM = Color3.fromRGB(255, 160, 20)
local INK = Color3.fromRGB(10, 10, 14)

-- -------------------------------------------------------------- the shots --

type Shot = { name: string, from: CFrame, to: CFrame, focus: Vector3 }

local function look(from: Vector3, at: Vector3): CFrame
	return CFrame.lookAt(from, at)
end

local function shots(): { Shot }
	local list: { Shot } = {}
	-- Downtown's plaza and ZEE TOWER (DistrictService.CENTRE).
	local dt = Vector3.new(-155, 1000, 1500)
	table.insert(list, {
		name = "DOWNTOWN",
		from = look(dt + Vector3.new(26, 18, -86), dt + Vector3.new(0, 24, 60)),
		to = look(dt + Vector3.new(8, 14, -52), dt + Vector3.new(0, 26, 60)),
		focus = dt,
	})
	-- The Flats battleground (CoverService.CENTRE).
	local flats = Vector3.new(-573, 1.5, 88)
	table.insert(list, {
		name = "THE FLATS",
		from = look(flats + Vector3.new(62, 34, -58), flats + Vector3.new(-8, 0, 4)),
		to = look(flats + Vector3.new(38, 26, -74), flats + Vector3.new(-12, 0, 2)),
		focus = flats,
	})
	-- A duel map, whichever the arenas folder offers first.
	local arenas = workspace:FindFirstChild("Arenas")
	if arenas then
		for _, map in ipairs(arenas:GetChildren()) do
			local centre = map:GetAttribute("ZoneCentre")
			if typeof(centre) == "Vector3" then
				table.insert(list, {
					name = "1V1 DUELS",
					from = look(centre + Vector3.new(46, 26, -50), centre + Vector3.new(0, 2, 0)),
					to = look(centre + Vector3.new(52, 22, -30), centre + Vector3.new(0, 2, 4)),
					focus = centre,
				})
				break
			end
		end
	end
	-- The harbour, where everyone starts (TravelService's Hub).
	local hub = Vector3.new(-155, 1.25, 275)
	table.insert(list, {
		name = "THE CROSSING",
		from = look(hub + Vector3.new(-46, 28, -44), hub + Vector3.new(0, 4, 18)),
		to = look(hub + Vector3.new(-30, 22, -52), hub + Vector3.new(4, 4, 20)),
		focus = hub,
	})
	return list
end

-- ------------------------------------------------------------------ build --

-- Three layers: the washes behind (unscaled, so they always fill the screen), the content
-- (authored at 1280x720 and scaled like every other screen), and the fade on top.
local function layer(name: string, order: number): ScreenGui
	local gui = Instance.new("ScreenGui")
	gui.Name = name
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = order
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	return gui
end
local backdrop = layer("TitleBackdrop", 899)
local screen = layer("TitleScreen", 900)
local fader = layer("TitleFade", 901)
Components.BindScale(screen)
UIState.SetOpen("Title", true)

-- A dark wash from the left, so the logo and buttons read over any shot.
local wash = Instance.new("Frame")
wash.Name = "Wash"
wash.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
wash.BorderSizePixel = 0
wash.Size = UDim2.fromScale(0.62, 1)
wash.Parent = backdrop
local washFade = Instance.new("UIGradient")
washFade.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.2),
	NumberSequenceKeypoint.new(0.7, 0.72),
	NumberSequenceKeypoint.new(1, 1),
})
washFade.Parent = wash
local floor = Instance.new("Frame")
floor.Name = "Floor"
floor.BackgroundColor3 = Color3.fromRGB(8, 10, 16)
floor.BorderSizePixel = 0
floor.AnchorPoint = Vector2.new(0, 1)
floor.Position = UDim2.fromScale(0, 1)
floor.Size = UDim2.new(1, 0, 0, 160)
floor.Parent = backdrop
local floorFade = Instance.new("UIGradient")
floorFade.Rotation = -90
floorFade.Transparency = NumberSequence.new(0.35, 1)
floorFade.Parent = floor

-- The logo.
local logo = Components.Label(screen, {
	text = "PROJECT ZEE",
	face = Theme.Face.HeavyItalic,
	size = 84,
	outline = 6,
})
logo.Name = "Logo"
logo.Position = UDim2.fromOffset(56, 60)
logo.Size = UDim2.fromOffset(620, 96)
local shine = Instance.new("UIGradient")
shine.Rotation = 90
shine.Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM)
shine.Parent = logo
local tagline = Components.Label(screen, {
	text = "DUELS  ·  RAIDS  ·  DOWNTOWN",
	face = Theme.Face.Condensed,
	size = 24,
	colour = Theme.Colour.TextDim,
	outline = 2.5,
})
tagline.Position = UDim2.fromOffset(62, 152)
tagline.Size = UDim2.fromOffset(560, 28)

-- Where the camera is.
local where = Instance.new("Frame")
where.Name = "Where"
where.BackgroundColor3 = INK
where.BackgroundTransparency = 0.25
where.BorderSizePixel = 0
where.Position = UDim2.fromOffset(62, 194)
where.Size = UDim2.fromOffset(250, 30)
where.Parent = screen
Components.Corner(where, 10)
Components.Stroke(where, Theme.Colour.Outline, 2)
local whereText = Components.Label(where, {
	text = "",
	face = Theme.Face.Condensed,
	size = 17,
	colour = Theme.Colour.TextDim,
	align = Enum.TextXAlignment.Center,
	outline = 1.5,
})
whereText.Size = UDim2.fromScale(1, 1)

local fade = Instance.new("Frame")
fade.Name = "Fade"
fade.BackgroundColor3 = Color3.new(0, 0, 0)
fade.BackgroundTransparency = 0
fade.BorderSizePixel = 0
fade.Size = UDim2.fromScale(1, 1)
fade.Parent = fader

-- ---------------------------------------------------------------- buttons --

local closing = false
local close: (string?) -> () = function() end

local play = Components.Button(screen, {
	name = "Play",
	text = "PLAY",
	primary = true,
	textSize = 40,
	size = UDim2.fromOffset(340, 78),
	position = UDim2.fromOffset(60, 262),
	radius = 16,
	onActivated = function()
		close(nil)
	end,
})

local shortcuts = Instance.new("Frame")
shortcuts.Name = "Shortcuts"
shortcuts.BackgroundTransparency = 1
shortcuts.Position = UDim2.fromOffset(60, 356)
shortcuts.Size = UDim2.fromOffset(340, 92)
shortcuts.Parent = screen
Components.List(shortcuts, Enum.FillDirection.Horizontal, 10, Enum.HorizontalAlignment.Left)

local function shortcut(name: string, icon: string, label: string, colour: Color3, order: number, onGo: () -> ())
	local tile = Instance.new("TextButton")
	tile.Name = name
	tile.AutoButtonColor = false
	tile.Text = ""
	tile.BackgroundColor3 = Theme.Shade(colour, -0.35)
	tile.BorderSizePixel = 0
	tile.Size = UDim2.fromOffset(106, 92)
	tile.LayoutOrder = order
	tile.Parent = shortcuts
	Components.Corner(tile, 14)
	Components.Stroke(tile, colour:Lerp(Color3.new(1, 1, 1), 0.3), 2.5)
	Components.Gradient(tile, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 160), 90)
	local glyph = Components.Icon(tile, icon, 30)
	glyph.AnchorPoint = Vector2.new(0.5, 0)
	glyph.Position = UDim2.new(0.5, 0, 0, 8)
	local text = Components.Label(tile, {
		text = label,
		face = Theme.Face.Condensed,
		size = 16,
		align = Enum.TextXAlignment.Center,
		outline = 2,
	})
	text.Position = UDim2.new(0, 0, 1, -34)
	text.Size = UDim2.new(1, 0, 0, 26)
	tile.MouseEnter:Connect(function()
		TweenService:Create(tile, TweenInfo.new(0.12), { BackgroundColor3 = Theme.Shade(colour, -0.15) }):Play()
	end)
	tile.MouseLeave:Connect(function()
		TweenService:Create(tile, TweenInfo.new(0.12), { BackgroundColor3 = Theme.Shade(colour, -0.35) }):Play()
	end)
	tile.Activated:Connect(onGo)
	return tile
end
shortcut("Duel", "⚔", "1V1 DUEL", Color3.fromRGB(70, 150, 255), 1, function()
	close("duel")
end)
shortcut("Downtown", "🏙", "DOWNTOWN", Color3.fromRGB(236, 120, 150), 2, function()
	close("Downtown")
end)
shortcut("Flats", "🏕", "THE FLATS", Color3.fromRGB(214, 150, 70), 3, function()
	close("Flats")
end)

local hint = Components.Label(screen, {
	text = "SPACE / ENTER TO PLAY",
	caps = true,
	size = Theme.Text.Small,
	colour = Theme.Colour.TextMuted,
})
hint.Position = UDim2.fromOffset(62, 458)
hint.Size = UDim2.fromOffset(340, 18)

-- ---------------------------------------------------------- your card --

local side = Instance.new("Frame")
side.Name = "Side"
side.BackgroundTransparency = 1
side.AnchorPoint = Vector2.new(1, 0)
side.Position = UDim2.new(1, -40, 0, 60)
side.Size = UDim2.fromOffset(360, 520)
side.Parent = screen

local card = Instance.new("Frame")
card.Name = "Card"
card.BackgroundColor3 = Theme.Colour.Panel
card.BackgroundTransparency = 0.08
card.BorderSizePixel = 0
card.Size = UDim2.fromOffset(360, 118)
card.Parent = side
Components.Corner(card, 16)
Components.Stroke(card, Theme.Colour.Outline, 2.5)
local avatar = Instance.new("ImageLabel")
avatar.Name = "Avatar"
avatar.BackgroundColor3 = Theme.Colour.Sunken
avatar.BorderSizePixel = 0
avatar.Position = UDim2.fromOffset(14, 14)
avatar.Size = UDim2.fromOffset(90, 90)
avatar.Parent = card
Components.Corner(avatar, 45)
Components.Stroke(avatar, Theme.Colour.Outline, 2.5)
task.spawn(function()
	local ok, image = pcall(function()
		return Players:GetUserThumbnailAsync(player.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size150x150)
	end)
	if ok and type(image) == "string" then
		avatar.Image = image
	end
end)
local name = Components.Label(card, {
	text = player.DisplayName,
	face = Theme.Face.HeavyItalic,
	size = 26,
	outline = 2.5,
})
name.Position = UDim2.fromOffset(118, 14)
name.Size = UDim2.new(1, -130, 0, 30)
name.TextTruncate = Enum.TextTruncate.AtEnd
local titleText = Components.Label(card, {
	text = "",
	face = Theme.Face.Condensed,
	size = 17,
	colour = Theme.Colour.Level,
	outline = 1.5,
})
titleText.Position = UDim2.fromOffset(118, 44)
titleText.Size = UDim2.new(1, -130, 0, 20)
local money = Components.Label(card, {
	text = "",
	font = Theme.Font.Display,
	size = 20,
	colour = Theme.Colour.Currency,
	outline = 2,
})
money.Position = UDim2.fromOffset(118, 74)
money.Size = UDim2.new(1, -130, 0, 26)

local function refreshCard()
	local level = tonumber(player:GetAttribute("Level")) or 1
	local title = player:GetAttribute("Title")
	titleText.Text = ("LEVEL %d%s"):format(level, type(title) == "string" and title ~= "" and ("  ·  " .. string.upper(title)) or "")
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	local cash = coins and coins:IsA("IntValue") and coins.Value or 0
	local s = tostring(math.floor(cash)):reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
	money.Text = ("$%s     💎 %d"):format(s, tonumber(player:GetAttribute("Crystals")) or 0)
end
refreshCard()

-- What's new.
local news = Instance.new("Frame")
news.Name = "WhatsNew"
news.BackgroundColor3 = Theme.Colour.Panel
news.BackgroundTransparency = 0.08
news.BorderSizePixel = 0
news.Position = UDim2.fromOffset(0, 132)
news.Size = UDim2.fromOffset(360, 330)
news.Parent = side
Components.Corner(news, 16)
Components.Stroke(news, Theme.Colour.Outline, 2.5)
local newsTitle = Components.Label(news, {
	text = "WHAT'S NEW",
	face = Theme.Face.HeavyItalic,
	size = 24,
	outline = 2.5,
})
newsTitle.Position = UDim2.fromOffset(16, 10)
newsTitle.Size = UDim2.new(1, -32, 0, 28)
local newsShine = Instance.new("UIGradient")
newsShine.Rotation = 90
newsShine.Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM)
newsShine.Parent = newsTitle
local NEWS = {
	{ "🏙", "DOWNTOWN, REBUILT", "A painted city: new plaza, fountain, parks" },
	{ "🧠", "SMARTER ENEMIES", "Grenades, callouts, flanking and medkits" },
	{ "⚔", "THE FLATS", "The raider camp against the guard post" },
	{ "🏅", "ACHIEVEMENTS", "25 goals and titles to earn -- press H" },
	{ "🗺", "TRAVEL", "Press T to go anywhere in the world" },
}
for i, item in ipairs(NEWS) do
	local row = Instance.new("Frame")
	row.Name = "News" .. i
	row.BackgroundTransparency = 1
	row.Position = UDim2.fromOffset(14, 46 + (i - 1) * 55)
	row.Size = UDim2.new(1, -28, 0, 50)
	row.Parent = news
	local glyph = Components.Icon(row, item[1], 26)
	glyph.Position = UDim2.fromOffset(0, 6)
	local head = Components.Label(row, { text = item[2], face = Theme.Face.Condensed, size = 18, outline = 1.8 })
	head.Position = UDim2.fromOffset(42, 2)
	head.Size = UDim2.new(1, -42, 0, 22)
	local body = Components.Label(row, {
		text = item[3],
		font = Theme.Font.Medium,
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
	})
	body.Position = UDim2.fromOffset(42, 24)
	body.Size = UDim2.new(1, -42, 0, 18)
	body.TextTruncate = Enum.TextTruncate.AtEnd
end

-- ----------------------------------------------------------------- camera --

local camera = workspace.CurrentCamera
local previousType = camera and camera.CameraType or Enum.CameraType.Custom
local reel = shots()
local shotIndex = 0
local shotStart = os.clock()
local SHOT_LENGTH = 7

local function prefetch(shot: Shot)
	task.spawn(function()
		pcall(function()
			player:RequestStreamAroundAsync(shot.focus, 2)
		end)
	end)
end

local function nextShot()
	shotIndex = shotIndex % math.max(#reel, 1) + 1
	shotStart = os.clock()
	local shot = reel[shotIndex]
	if shot then
		whereText.Text = "NOW SHOWING  ·  " .. shot.name
		prefetch(reel[shotIndex % #reel + 1])
	end
end

if camera then
	camera.CameraType = Enum.CameraType.Scriptable
end
if reel[1] then
	prefetch(reel[1])
end
nextShot()
TweenService:Create(fade, TweenInfo.new(0.8), { BackgroundTransparency = 1 }):Play()

local cutting = false
local stepper = RunService.RenderStepped:Connect(function()
	local shot = reel[shotIndex]
	if not shot or not camera or closing then
		return
	end
	local t = math.clamp((os.clock() - shotStart) / SHOT_LENGTH, 0, 1)
	local eased = t * t * (3 - 2 * t)
	camera.CFrame = shot.from:Lerp(shot.to, eased)
	-- Dip to black between shots.
	if t >= 0.94 and not cutting then
		cutting = true
		local out = TweenService:Create(fade, TweenInfo.new(0.35), { BackgroundTransparency = 0 })
		out.Completed:Once(function()
			if closing then
				return
			end
			nextShot()
			TweenService:Create(fade, TweenInfo.new(0.45), { BackgroundTransparency = 1 }):Play()
			cutting = false
		end)
		out:Play()
	end
end)

-- ------------------------------------------------------------------ leave --

close = function(go: string?)
	if closing then
		return
	end
	closing = true
	UISound.Play("Whoosh", 1.1, 0.5)
	local out = TweenService:Create(fade, TweenInfo.new(0.35), { BackgroundTransparency = 0 })
	out.Completed:Once(function()
		stepper:Disconnect()
		screen:Destroy()
		backdrop:Destroy()
		if camera then
			camera.CameraType = previousType == Enum.CameraType.Scriptable and Enum.CameraType.Custom or previousType
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if humanoid then
				camera.CameraSubject = humanoid
			end
		end
		UIState.SetOpen("Title", false)
		-- A shortcut: straight into the queue, or straight to a place while the screen is dark.
		if go == "duel" then
			player:SetAttribute("TitleAction", "duel")
		elseif go then
			local remotes = ReplicatedStorage:FindFirstChild("Remotes")
			local travel = remotes and remotes:FindFirstChild("TravelAction")
			if travel and travel:IsA("RemoteFunction") then
				pcall(function()
					travel:InvokeServer("go", go)
				end)
			end
		end
		task.wait(0.15)
		local back = TweenService:Create(fade, TweenInfo.new(0.5), { BackgroundTransparency = 1 })
		back.Completed:Once(function()
			fader:Destroy()
		end)
		back:Play()
	end)
	out:Play()
end

UserInputService.InputBegan:Connect(function(input: InputObject)
	if closing then
		return
	end
	local key = input.KeyCode
	if key == Enum.KeyCode.Space or key == Enum.KeyCode.Return or key == Enum.KeyCode.Escape
		or key == Enum.KeyCode.ButtonA or key == Enum.KeyCode.ButtonStart then
		close(nil)
	end
end)

-- Keep the card honest while it is up (money and level may still be loading in).
task.spawn(function()
	while not closing do
		refreshCard()
		task.wait(1)
	end
end)

-- The play button breathes, so the eye goes to it.
task.spawn(function()
	local scale = Instance.new("UIScale")
	scale.Parent = play.instance or play
	while not closing do
		TweenService:Create(scale, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Scale = 1.04 }):Play()
		task.wait(0.9)
		TweenService:Create(scale, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Scale = 1 }):Play()
		task.wait(0.9)
	end
end)
