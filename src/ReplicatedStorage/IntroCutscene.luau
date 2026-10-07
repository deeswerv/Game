--!strict
-- The cutscene you get when you join, before the title screen: a short film of the world.
--
-- PROJECT ZEE PRESENTS on black, then the camera flies DOWNTOWN -- in under the sign at the
-- forecourt, up the avenue and up ZEE TOWER -- whips round the fountain in ZEE PLAZA, flashes
-- to HANAMI CITY (the next chapter) and last of all comes down out of the sky onto you, where
-- the logo lands. About twenty seconds, start to finish.
--
-- Every shot is a camera on rails: keyframes of where the camera is and what it looks at,
-- strung on Catmull-Rom splines so the moves curve rather than zig-zag, eased in and out, with
-- a lens that breathes (field of view), a little roll, and a hand-held drift on top. Between
-- shots a whip pan (a blur and a snap of the camera), a flash or a dip to black. Letterbox bars,
-- a title card per place that types itself in, a progress line, a colour grade and a depth of
-- field that keeps whatever the camera looks at sharp.
--
-- Hold SPACE (or the SKIP button, or A on a pad) to skip. Anything missing -- a district not
-- streamed in yet, no duel arena, no character -- just drops its shot. Everything it adds to
-- the screen and the lighting is removed when it ends, however it ends.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("UI"):WaitForChild("Modules")
local Theme = require(Modules:WaitForChild("Theme"))
local Components = require(Modules:WaitForChild("Components"))
local UISound = require(Modules:WaitForChild("UISound"))

local Intro = {}

local GOLD_TOP = Color3.fromRGB(255, 240, 120)
local GOLD_BOTTOM = Color3.fromRGB(255, 160, 20)
local HANAMI = Vector3.new(1100, 1000, 1500)      -- HanamiConfig.CENTRE
local DOWNTOWN = Vector3.new(-155, 1000, 1500)    -- DistrictService.CENTRE
local ZEE_TOWER = DOWNTOWN + Vector3.new(0, 0.5, 158)

Intro.SKIP_HOLD = 0.7          -- seconds to hold to skip
Intro.OPENER = 1.2             -- the black card before the first shot
Intro.LOGO = 2.4               -- the logo's hold at the end

export type Key = { pos: Vector3, look: Vector3, fov: number?, roll: number? }
export type Shot = {
	id: string, title: string?, sub: string?, length: number, keys: { Key },
	enter: string,              -- "dip", "whip", "flash" or "cut"
	shake: number?,             -- hand-held drift, degrees
	grade: { tint: Color3, saturation: number, contrast: number }?,
	focus: Vector3,             -- where to stream in ahead of the shot
	final: boolean?,
}

-- ------------------------------------------------------------------ the shots --

--- A point in Hanami's own frame (+Z north, +X west), in the world.
local function H(x: number, y: number, z: number): Vector3
	return HANAMI + Vector3.new(x, y, z)
end

--- Keys round a circle: `from` to `to` degrees about `centre`, at radius `r`.
local function orbit(centre: Vector3, r: number, from: number, to: number, y0: number, y1: number, look: Vector3, n: number,
	fov: number): { Key }
	local keys = {}
	for i = 0, n - 1 do
		local t = i / (n - 1)
		local a = math.rad(from + (to - from) * t)
		table.insert(keys, { pos = centre + Vector3.new(math.cos(a) * r, y0 + (y1 - y0) * t, math.sin(a) * r), look = look, fov = fov,
			roll = 2 - 4 * t })
	end
	return keys
end

local WARM = { tint = Color3.fromRGB(255, 240, 236), saturation = 0.12, contrast = 0.08 }
local COOL = { tint = Color3.fromRGB(232, 240, 255), saturation = 0.04, contrast = 0.12 }
local GOLDEN = { tint = Color3.fromRGB(255, 236, 214), saturation = 0.1, contrast = 0.1 }

--- The film, for this player right now (a shot whose place is not there is left out). Short on
--- purpose: Downtown -- where you are about to play -- then the next chapter, then you.
function Intro.Shots(): { Shot }
	local list: { Shot } = {}
	if workspace:FindFirstChild("Downtown") then
		-- In under the sign at the forecourt, up the avenue, and up ZEE TOWER.
		table.insert(list, { id = "Downtown", title = "DOWNTOWN", sub = "ZEE TOWER  ·  THE DON'S CITY", length = 5.2, enter = "dip",
			shake = 0.5, grade = WARM, focus = DOWNTOWN, keys = {
				{ pos = DOWNTOWN + Vector3.new(7, 5, -186), look = DOWNTOWN + Vector3.new(0, 9, -100), fov = 64, roll = 2 },
				{ pos = DOWNTOWN + Vector3.new(4, 7, -128), look = DOWNTOWN + Vector3.new(0, 14, -20), fov = 66, roll = 1 },
				{ pos = DOWNTOWN + Vector3.new(2, 24, -60), look = ZEE_TOWER + Vector3.new(0, 60, 0), fov = 68, roll = 0 },
				{ pos = DOWNTOWN + Vector3.new(0, 54, 14), look = ZEE_TOWER + Vector3.new(0, 150, 0), fov = 74, roll = -1 },
			} })
		-- Round the fountain in ZEE PLAZA, the heart of it.
		table.insert(list, { id = "Plaza", title = "THE STREETS", sub = "TURF WARS  ·  STICK-UPS  ·  MOST WANTED", length = 3.6,
			enter = "whip", shake = 0.8, grade = COOL, focus = DOWNTOWN,
			keys = orbit(DOWNTOWN, 24, 230, 310, 7, 11, DOWNTOWN + Vector3.new(0, 7, 0), 5, 74) })
	end
	if workspace:FindFirstChild("Hanami") then
		-- The next chapter: down Hanami's boulevard toward the station.
		table.insert(list, { id = "Hanami", title = "HANAMI CITY", sub = "花見市  ·  THE NEXT CHAPTER", length = 4, enter = "flash",
			shake = 0.5, grade = WARM, focus = H(0, 0, -400), keys = {
				{ pos = H(-30, 140, -150), look = H(0, 0, -400), fov = 58, roll = -4 },
				{ pos = H(-8, 70, -300), look = H(0, 20, -440), fov = 64, roll = -1 },
				{ pos = H(-10, 28, -362), look = H(0, 30, -446), fov = 68, roll = 0 },
			} })
	end
	-- Last: you. Down out of the sky behind you, round, and to your face.
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		local p = root.Position
		local look = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
		look = if look.Magnitude > 0.01 then look.Unit else Vector3.new(0, 0, -1)
		local right = look:Cross(Vector3.new(0, 1, 0))
		local head = p + Vector3.new(0, 1.8, 0)
		table.insert(list, { id = "You", length = 3.6, enter = "dip", shake = 0.3, grade = GOLDEN, focus = p, final = true, keys = {
			{ pos = p - look * 70 + right * 40 + Vector3.new(0, 60, 0), look = head, fov = 60, roll = 6 },
			{ pos = p - look * 18 + right * 26 + Vector3.new(0, 16, 0), look = head, fov = 56, roll = 2 },
			{ pos = p + look * 5 + right * 12 + Vector3.new(0, 4, 0), look = head, fov = 50, roll = 0 },
			{ pos = p + look * 9 + right * 3 + Vector3.new(0, 2.6, 0), look = head, fov = 44, roll = 0 },
		} })
	end
	return list
end

-- ------------------------------------------------------------------ the camera --

--- Catmull-Rom through `points` at u in [0, 1] (the ends held, so it starts and stops on them).
local function spline(points: { Vector3 }, u: number): Vector3
	local n = #points
	if n == 1 then
		return points[1]
	end
	local f = math.clamp(u, 0, 1) * (n - 1)
	local i = math.min(math.floor(f), n - 2)
	local t = f - i
	local p0 = points[math.max(i, 1)]
	local p1 = points[i + 1]
	local p2 = points[i + 2]
	local p3 = points[math.min(i + 3, n)]
	local t2, t3 = t * t, t * t * t
	return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
end
Intro.Spline = spline

local function linear(values: { number }, u: number): number
	local n = #values
	if n == 1 then
		return values[1]
	end
	local f = math.clamp(u, 0, 1) * (n - 1)
	local i = math.min(math.floor(f), n - 2)
	local t = f - i
	t = t * t * (3 - 2 * t)
	return values[i + 1] + (values[i + 2] - values[i + 1]) * t
end

--- A move that starts and stops softly but never quite stands still.
local function ease(t: number): number
	local smooth = t * t * t * (t * (t * 6 - 15) + 10)
	return t + (smooth - t) * 0.7
end

--- Where the camera is at u (0..1 through the shot), and its lens, with the hand-held drift.
function Intro.Frame(shot: Shot, u: number, clock: number): (CFrame, number)
	local e = ease(u)
	local pos, look, fov, roll = {}, {}, {}, {}
	for _, k in ipairs(shot.keys) do
		table.insert(pos, k.pos)
		table.insert(look, k.look)
		table.insert(fov, k.fov or 70)
		table.insert(roll, k.roll or 0)
	end
	local at = spline(pos, e)
	local target = spline(look, e)
	if (target - at).Magnitude < 0.01 then
		target = at + Vector3.new(0, 0, -1)
	end
	local amp = math.rad(shot.shake or 0.5)
	local seed = #shot.id * 7.3
	local cf = CFrame.lookAt(at, target)
		* CFrame.Angles(math.noise(clock * 0.45, seed) * amp, math.noise(seed, clock * 0.4) * amp,
			math.rad(linear(roll, e)) + math.noise(clock * 0.3, seed, 3.1) * amp * 0.6)
	return cf, linear(fov, e)
end

-- ------------------------------------------------------------------ the screen --

type Ui = {
	gui: ScreenGui, top: Frame, bottom: Frame, progress: Frame, fade: Frame, flash: Frame,
	card: Frame, index: TextLabel, rule: Frame, title: TextLabel, sub: TextLabel,
	skip: TextButton, skipFill: Frame, skipText: TextLabel, logo: Frame, logoScale: UIScale, shine: UIGradient,
	opener: TextLabel, unbind: () -> (),
}

local function frame(parent: Instance, name: string, colour: Color3, transparency: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = colour
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.Parent = parent
	return f
end

local function build(playerGui: Instance): Ui
	local gui = Instance.new("ScreenGui")
	gui.Name = "IntroCutscene"
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 950
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui
	local unbind = Components.BindScale(gui)
	-- Letterbox bars (unscaled: they always reach the screen's edges).
	local top = frame(gui, "BarTop", Color3.new(0, 0, 0), 0)
	top.Size = UDim2.fromScale(1, 0)
	local bottom = frame(gui, "BarBottom", Color3.new(0, 0, 0), 0)
	bottom.AnchorPoint = Vector2.new(0, 1)
	bottom.Position = UDim2.fromScale(0, 1)
	bottom.Size = UDim2.fromScale(1, 0)
	local progress = frame(bottom, "Progress", GOLD_BOTTOM, 0)
	progress.Size = UDim2.new(0, 0, 0, 3)
	-- Edges darkened a little, like a lens.
	for i, spec in ipairs({ { UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0), 90 }, { UDim2.fromScale(1, 0.22), UDim2.fromScale(0, 0.78), -90 },
		{ UDim2.fromScale(0.16, 1), UDim2.fromScale(0, 0), 0 }, { UDim2.fromScale(0.16, 1), UDim2.fromScale(0.84, 0), 180 } } :: { { any } }) do
		local v = frame(gui, "Vignette" .. i, Color3.new(0, 0, 0), 0)
		v.Size = spec[1]
		v.Position = spec[2]
		local g = Instance.new("UIGradient")
		g.Rotation = spec[3]
		g.Transparency = NumberSequence.new(0.55, 1)
		g.Parent = v
	end
	-- The title card, bottom left, over the bar.
	local card = frame(gui, "Card", Color3.new(0, 0, 0), 1)
	card.AnchorPoint = Vector2.new(0, 1)
	card.Position = UDim2.new(0, 64, 0.86, -8)
	card.Size = UDim2.fromOffset(760, 150)
	local index = Components.Label(card, { text = "01", face = Theme.Face.Condensed, size = 20, colour = GOLD_TOP, outline = 2 })
	index.Name = "Index"
	index.Position = UDim2.fromOffset(2, 0)
	index.Size = UDim2.fromOffset(60, 24)
	local rule = frame(card, "Rule", GOLD_BOTTOM, 0)
	rule.Position = UDim2.fromOffset(44, 11)
	rule.Size = UDim2.fromOffset(0, 3)
	local title = Components.Label(card, { text = "", face = Theme.Face.HeavyItalic, size = 76, outline = 5 })
	title.Name = "Title"
	title.Position = UDim2.fromOffset(0, 26)
	title.Size = UDim2.fromOffset(760, 84)
	local titleShine = Instance.new("UIGradient")
	titleShine.Rotation = 90
	titleShine.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(255, 226, 190))
	titleShine.Parent = title
	local sub = Components.Label(card, { text = "", face = Theme.Face.Condensed, size = 22, colour = Theme.Colour.TextDim, outline = 2 })
	sub.Name = "Sub"
	sub.Position = UDim2.fromOffset(4, 112)
	sub.Size = UDim2.fromOffset(760, 28)
	card.Visible = false
	-- Hold to skip, top right.
	local skip = Instance.new("TextButton")
	skip.Name = "Skip"
	skip.AutoButtonColor = false
	skip.Text = ""
	skip.AnchorPoint = Vector2.new(1, 0)
	skip.Position = UDim2.new(1, -36, 0, 30)
	skip.Size = UDim2.fromOffset(220, 40)
	skip.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	skip.BackgroundTransparency = 0.35
	skip.BorderSizePixel = 0
	skip.ZIndex = 5
	skip.Parent = gui
	Components.Corner(skip, 20)
	Components.Stroke(skip, Color3.fromRGB(255, 255, 255), 1.5).Transparency = 0.6
	local skipFill = frame(skip, "Fill", GOLD_BOTTOM, 0.25)
	skipFill.Size = UDim2.fromScale(0, 1)
	skipFill.ZIndex = 5
	Components.Corner(skipFill, 20)
	local skipText = Components.Label(skip, { text = "HOLD SPACE TO SKIP", face = Theme.Face.Condensed, size = 17,
		align = Enum.TextXAlignment.Center, outline = 1.5 })
	skipText.Name = "SkipText"
	skipText.Size = UDim2.fromScale(1, 1)
	skipText.ZIndex = 6
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		skipText.Text = "TAP TO SKIP"
	end
	-- The opener and the logo, in the middle.
	local opener = Components.Label(gui :: any, { text = "PROJECT ZEE  PRESENTS", face = Theme.Face.Condensed, size = 26, colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center, outline = false })
	opener.Name = "Opener"
	opener.AnchorPoint = Vector2.new(0.5, 0.5)
	opener.Position = UDim2.fromScale(0.5, 0.5)
	opener.Size = UDim2.fromOffset(700, 40)
	opener.TextTransparency = 1
	opener.ZIndex = 8
	local logo = frame(gui, "Logo", Color3.new(0, 0, 0), 1)
	logo.AnchorPoint = Vector2.new(0.5, 0.5)
	logo.Position = UDim2.fromScale(0.5, 0.47)
	logo.Size = UDim2.fromOffset(900, 220)
	logo.Visible = false
	logo.ZIndex = 7
	local logoScale = Instance.new("UIScale")
	logoScale.Parent = logo
	local word = Components.Label(logo, { text = "PROJECT ZEE", face = Theme.Face.HeavyItalic, size = 128, align = Enum.TextXAlignment.Center,
		outline = 8 })
	word.Name = "Word"
	word.Size = UDim2.fromOffset(900, 150)
	word.ZIndex = 7
	local gold = Instance.new("UIGradient")
	gold.Rotation = 90
	gold.Color = ColorSequence.new(GOLD_TOP, GOLD_BOTTOM)
	gold.Parent = word
	-- A sweep of light across the letters.
	local gleam = Components.Label(logo, { text = "PROJECT ZEE", face = Theme.Face.HeavyItalic, size = 128, align = Enum.TextXAlignment.Center,
		outline = false })
	gleam.Name = "Gleam"
	gleam.Size = UDim2.fromOffset(900, 150)
	gleam.ZIndex = 8
	local shine = Instance.new("UIGradient")
	shine.Rotation = 20
	shine.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.42, 1), NumberSequenceKeypoint.new(0.5, 0.15),
		NumberSequenceKeypoint.new(0.58, 1), NumberSequenceKeypoint.new(1, 1),
	})
	shine.Offset = Vector2.new(-1, 0)
	shine.Parent = gleam
	local tag = Components.Label(logo, { text = "DUELS  ·  RAIDS  ·  DOWNTOWN  ·  HANAMI CITY", face = Theme.Face.Condensed, size = 24,
		colour = Theme.Colour.TextDim, align = Enum.TextXAlignment.Center, outline = 2 })
	tag.Name = "Tagline"
	tag.Position = UDim2.fromOffset(0, 154)
	tag.Size = UDim2.fromOffset(900, 30)
	tag.ZIndex = 7
	local flash = frame(gui, "Flash", Color3.new(1, 1, 1), 1)
	flash.Size = UDim2.fromScale(1, 1)
	flash.ZIndex = 9
	local fade = frame(gui, "Fade", Color3.new(0, 0, 0), 0)
	fade.Size = UDim2.fromScale(1, 1)
	fade.ZIndex = 10
	return {
		gui = gui, top = top, bottom = bottom, progress = progress, fade = fade, flash = flash, card = card, index = index, rule = rule,
		title = title, sub = sub, skip = skip, skipFill = skipFill, skipText = skipText, logo = logo, logoScale = logoScale, shine = shine,
		opener = opener, unbind = unbind,
	}
end

local function tween(inst: Instance, seconds: number, goal: { [string]: any }, style: Enum.EasingStyle?, dir: Enum.EasingDirection?): Tween
	local t = TweenService:Create(inst, TweenInfo.new(seconds, style or Enum.EasingStyle.Quad, dir or Enum.EasingDirection.Out), goal)
	t:Play()
	return t
end

local function showCard(ui: Ui, n: number, shot: Shot)
	if not shot.title then
		return
	end
	ui.card.Visible = true
	ui.index.Text = ("%02d"):format(n)
	ui.title.Text = shot.title
	ui.sub.Text = shot.sub or ""
	ui.title.MaxVisibleGraphemes = 0
	ui.rule.Size = UDim2.fromOffset(0, 3)
	ui.card.Position = UDim2.new(0, 64, 0.86, -8)
	for _, l in ipairs({ ui.index, ui.title, ui.sub }) do
		l.TextTransparency = 0
	end
	ui.sub.TextTransparency = 1
	tween(ui.rule, 0.45, { Size = UDim2.fromOffset(160, 3) })
	-- The title types itself in, a letter at a time.
	local count = utf8.len(shot.title) or #shot.title
	task.spawn(function()
		for k = 1, count do
			if ui.title.Text ~= shot.title then
				return
			end
			ui.title.MaxVisibleGraphemes = k
			task.wait(0.035)
		end
		ui.title.MaxVisibleGraphemes = -1
	end)
	task.delay(0.35, function()
		tween(ui.sub, 0.4, { TextTransparency = 0 })
	end)
end

local function hideCard(ui: Ui)
	tween(ui.card, 0.35, { Position = UDim2.new(0, 34, 0.86, -8) }, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	for _, l in ipairs({ ui.index, ui.title, ui.sub }) do
		tween(l, 0.3, { TextTransparency = 1 })
	end
	tween(ui.rule, 0.3, { Size = UDim2.fromOffset(0, 3) })
end

-- ------------------------------------------------------------------ play --

local playing = false
local skipRequested = false

--- Skip whatever is playing (the button and the held key call this).
function Intro.Skip()
	skipRequested = true
end

function Intro.Playing(): boolean
	return playing
end

--- Play the film. Yields until it has finished or been skipped; leaves the screen black and
--- the camera scriptable, for whatever comes next to fade in from.
function Intro.Play(options: { shots: { Shot }? }?)
	if playing then
		return
	end
	playing = true
	skipRequested = false
	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local camera = workspace.CurrentCamera
	local shots = (options and options.shots) or Intro.Shots()
	if #shots > 0 then
		-- Whatever comes last holds for the logo.
		shots[#shots].final = true
	end
	local ui = build(playerGui)
	local oldFov = if camera then camera.FieldOfView else 70
	if camera then
		camera.CameraType = Enum.CameraType.Scriptable
	end
	-- The film's own light: a grade, a depth of field, a blur for the whips.
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "IntroGrade"
	grade.Parent = Lighting
	local focus = Instance.new("DepthOfFieldEffect")
	focus.Name = "IntroFocus"
	focus.FarIntensity = 0.32
	focus.NearIntensity = 0.12
	focus.InFocusRadius = 60
	focus.Parent = Lighting
	local blur = Instance.new("BlurEffect")
	blur.Name = "IntroBlur"
	blur.Size = 0
	blur.Parent = Lighting

	local function stream(shot: Shot?)
		if shot then
			task.spawn(function()
				pcall(function()
					player:RequestStreamAroundAsync(shot.focus, 3)
				end)
			end)
		end
	end
	stream(shots[1])
	stream(shots[2])

	-- Skipping: hold the key (the bar fills), or press the button.
	local held = false
	local heldFor = 0
	local connections: { RBXScriptConnection } = {}
	table.insert(connections, UserInputService.InputBegan:Connect(function(input: InputObject)
		local k = input.KeyCode
		if k == Enum.KeyCode.Space or k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonA or k == Enum.KeyCode.Escape then
			held = true
		end
	end))
	table.insert(connections, UserInputService.InputEnded:Connect(function(input: InputObject)
		local k = input.KeyCode
		if k == Enum.KeyCode.Space or k == Enum.KeyCode.Return or k == Enum.KeyCode.ButtonA or k == Enum.KeyCode.Escape then
			held = false
		end
	end))
	table.insert(connections, ui.skip.Activated:Connect(function()
		Intro.Skip()
	end))

	-- The running state: which shot, how far in, what the camera does.
	local total = Intro.OPENER + Intro.LOGO
	for _, s in ipairs(shots) do
		total += s.length
	end
	local elapsed = 0
	local current = 0
	local shotTime = 0
	local whipOut = 0         -- the end-of-shot whip: a turn and a blur building up
	local finished = false
	local logoShown = false
	local looks: { Vector3 } = {}
	local cardOut = false

	local function enter(n: number)
		current = n
		shotTime = 0
		local shot = shots[n]
		if not shot then
			return
		end
		looks = {}
		for _, k in ipairs(shot.keys) do
			table.insert(looks, k.look)
		end
		cardOut = false
		stream(shots[n + 1])
		if shot.grade then
			tween(grade, 0.6, { TintColor = shot.grade.tint, Saturation = shot.grade.saturation, Contrast = shot.grade.contrast })
		end
		if shot.enter == "dip" then
			ui.fade.BackgroundTransparency = 0
			tween(ui.fade, 0.6, { BackgroundTransparency = 1 })
		elseif shot.enter == "flash" then
			ui.flash.BackgroundTransparency = 0.1
			tween(ui.flash, 0.55, { BackgroundTransparency = 1 })
			UISound.Play("Whoosh", 0.8, 0.5)
		elseif shot.enter == "whip" then
			blur.Size = 24
			tween(blur, 0.32, { Size = 0 })
			UISound.Play("Whoosh", 1.25, 0.45)
		end
		task.delay(0.45, function()
			if current == n and not finished then
				showCard(ui, n, shot)
			end
		end)
	end

	local function finish()
		finished = true
	end

	local function logo()
		if logoShown then
			return
		end
		logoShown = true
		hideCard(ui)
		ui.logo.Visible = true
		ui.logoScale.Scale = 1.35
		ui.flash.BackgroundTransparency = 0
		tween(ui.flash, 0.7, { BackgroundTransparency = 1 })
		tween(ui.logoScale, 0.7, { Scale = 1 }, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
		UISound.Play("Slam", 0.9, 0.6)
		task.delay(0.6, function()
			ui.shine.Offset = Vector2.new(-1, 0)
			tween(ui.shine, 1.1, { Offset = Vector2.new(1, 0) }, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
		end)
	end

	-- Open: the bars come in, the opener on black.
	tween(ui.top, 0.9, { Size = UDim2.fromScale(1, 0.115) }, Enum.EasingStyle.Quint)
	tween(ui.bottom, 0.9, { Size = UDim2.fromScale(1, 0.115) }, Enum.EasingStyle.Quint)
	tween(ui.opener, 0.8, { TextTransparency = 0 })
	task.delay(Intro.OPENER - 0.7, function()
		tween(ui.opener, 0.5, { TextTransparency = 1 })
	end)

	local stepper = RunService.RenderStepped:Connect(function(dt: number)
		if finished then
			return
		end
		elapsed += dt
		-- Skip: hold to fill the bar.
		heldFor = if held then heldFor + dt else math.max(0, heldFor - dt * 2)
		ui.skipFill.Size = UDim2.fromScale(math.clamp(heldFor / Intro.SKIP_HOLD, 0, 1), 1)
		if heldFor >= Intro.SKIP_HOLD then
			skipRequested = true
		end
		if skipRequested then
			finish()
			return
		end
		ui.progress.Size = UDim2.new(math.clamp(elapsed / total, 0, 1), 0, 0, 3)
		if current == 0 then
			if elapsed >= Intro.OPENER then
				if #shots == 0 then
					logo()
					current = 1
				else
					enter(1)
				end
			end
			return
		end
		local shot = shots[current]
		if not shot then
			-- (no shots at all: just the logo's hold on black)
			shotTime += dt
			if shotTime >= Intro.LOGO then
				finish()
			end
			return
		end
		shotTime += dt
		local holdLogo = shot.final and shotTime > shot.length
		local u = math.clamp(shotTime / shot.length, 0, 1)
		local cf, fov = Intro.Frame(shot, u, elapsed)
		if holdLogo then
			-- The last frame drifts in a little more while the logo holds.
			local extra = math.min(1, (shotTime - shot.length) / Intro.LOGO)
			cf = cf * CFrame.new(0, 0, -extra * 1.6)
		end
		-- The whip out of a shot whose next one whips in: the camera snaps sideways, blurring.
		local nextShot = shots[current + 1]
		if nextShot and nextShot.enter == "whip" and shot.length - shotTime < 0.25 then
			whipOut = 1 - (shot.length - shotTime) / 0.25
			cf = cf * CFrame.Angles(0, -whipOut * whipOut * math.rad(50), 0)
			blur.Size = whipOut * 24
		end
		if camera then
			camera.CFrame = cf
			camera.FieldOfView = fov
			-- Keep what the camera looks at sharp, the far distance soft.
			focus.FocusDistance = math.clamp((spline(looks, ease(u)) - cf.Position).Magnitude, 4, 500)
			focus.InFocusRadius = math.max(18, focus.FocusDistance * 0.45)
		end
		if shot.title and not cardOut and shotTime > shot.length - 0.55 then
			cardOut = true
			hideCard(ui)
		end
		if shot.final and shotTime > shot.length - 0.6 then
			logo()
		end
		if shotTime >= shot.length + (if shot.final then Intro.LOGO else 0) then
			if current < #shots then
				enter(current + 1)
			else
				finish()
			end
		end
	end)

	-- Wait for the end, then fade to black and put everything back.
	while not finished do
		task.wait(0.05)
	end
	stepper:Disconnect()
	for _, c in ipairs(connections) do
		c:Disconnect()
	end
	local out = tween(ui.fade, 0.45, { BackgroundTransparency = 0 })
	tween(ui.top, 0.45, { Size = UDim2.fromScale(1, 0) })
	tween(ui.bottom, 0.45, { Size = UDim2.fromScale(1, 0) })
	local waited = 0
	while out.PlaybackState == Enum.PlaybackState.Playing and waited < 1 do
		waited += task.wait(0.05)
	end
	grade:Destroy()
	focus:Destroy()
	blur:Destroy()
	if camera then
		camera.FieldOfView = oldFov
	end
	ui.unbind()
	ui.gui:Destroy()
	playing = false
end

return Intro
