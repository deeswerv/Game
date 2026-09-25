--!strict
-- Utility, client side: the tray, aiming a throw, and drawing everyone's utility.
--
--   hold F     an arc shows where the selected throwable will go; let go to throw it
--   X          switch throwable (Frag, Flashbang, Smoke -- whichever you have)
--   Z          patch up with a medkit
--
-- The tray sits above the weapon slots, like the reference hotbar's Grenade / Flashbang /
-- Medkit: each kind with how many you have left, the selected throwable lit gold.
--
-- The server decides everything (UtilityService); this asks, and draws what it is told:
-- every thrown thing flies along the path the server worked out, frags go off with the same
-- blast as the enemies' grenades (ExplosionFX), a flash whites out THIS screen by how
-- directly it was looked at (only this client knows where its camera points), smoke stands
-- as a cloud, and a medkit shows its bar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UtilityConfig = require(ReplicatedStorage:WaitForChild("UtilityConfig"))
local ExplosionFX = require(ReplicatedStorage:WaitForChild("ExplosionFX"))
local Modules = ReplicatedStorage:WaitForChild("UI"):WaitForChild("Modules")
local Theme = require(Modules:WaitForChild("Theme")) :: any
local Components = require(Modules:WaitForChild("Components")) :: any

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local UtilityAction = Remotes:WaitForChild("UtilityAction") :: RemoteEvent
local UtilityEvent = Remotes:WaitForChild("UtilityEvent") :: RemoteEvent

local GOLD = Color3.fromRGB(255, 196, 40)
local WHITE = Color3.new(1, 1, 1)

local kit: { [string]: number } = { Frag = 0, Flash = 0, Smoke = 0, Medkit = 0 }
local selected = "Frag"

-- ------------------------------------------------------------------ tray --

local gui = Instance.new("ScreenGui")
gui.Name = "UtilityHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 5
gui.Parent = playerGui
Components.BindScale(gui)

local tray = Instance.new("Frame")
tray.Name = "Tray"
tray.BackgroundTransparency = 1
-- Bottom row, between the health bar and the weapon slots: the space the reference hotbar's
-- utility sits in, and clear of the menu tiles down the right.
local TRAY_LEFT = Theme.Inset.Side + 330
tray.AnchorPoint = Vector2.new(0, 1)
tray.Position = UDim2.new(0, TRAY_LEFT, 1, -Theme.Inset.Bottom)
tray.Size = UDim2.fromOffset(0, 58)
tray.AutomaticSize = Enum.AutomaticSize.X
tray.Parent = gui
local trayList = Components.List(tray, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Left)
trayList.VerticalAlignment = Enum.VerticalAlignment.Bottom

type Tile = { frame: Frame, count: TextLabel, key: TextLabel, rim: UIStroke, scale: UIScale }
local tiles: { [string]: Tile } = {}

local function tile(id: string, order: number): Tile
	local cfg = UtilityConfig.Get(id)
	local frame = Instance.new("Frame")
	frame.Name = id
	frame.BackgroundColor3 = Theme.Colour.Panel
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromOffset(60, 58)
	frame.LayoutOrder = order
	frame.Parent = tray
	Components.Corner(frame, 10)
	local rim = Components.Stroke(frame, Theme.Colour.Outline, 2)
	Components.Gradient(frame)
	local scale = Instance.new("UIScale")
	scale.Parent = frame
	local icon = Components.Label(frame, { text = cfg.icon, size = 24, align = Enum.TextXAlignment.Center })
	icon.Position = UDim2.fromOffset(0, 4)
	icon.Size = UDim2.new(1, 0, 0, 28)
	local count = Components.Label(frame, { text = "0", face = Theme.Face.HeavyItalic, size = 18, outline = 2,
		align = Enum.TextXAlignment.Center })
	count.Name = "Count"
	count.Position = UDim2.fromOffset(0, 32)
	count.Size = UDim2.new(1, 0, 0, 20)
	local key = Components.Label(frame, { text = "", font = Theme.Font.Bold, size = 11, colour = Theme.Colour.TextDim })
	key.Name = "Key"
	key.Position = UDim2.fromOffset(5, 2)
	key.Size = UDim2.fromOffset(20, 14)
	return { frame = frame, count = count, key = key, rim = rim, scale = scale }
end

for i, id in ipairs(UtilityConfig.Order) do
	tiles[id] = tile(id, i)
end
tiles.Medkit = tile("Medkit", 10)
tiles.Medkit.key.Text = "Z"

local hint = Components.Label(gui, { text = "HOLD F  ·  X SWITCH  ·  Z HEAL", font = Theme.Font.Bold, size = 11,
	colour = Theme.Colour.TextDim, align = Enum.TextXAlignment.Left, outline = false })
hint.Name = "TrayHint"
hint.AnchorPoint = Vector2.new(0, 1)
hint.Position = UDim2.new(0, TRAY_LEFT + 2, 1, -(Theme.Inset.Bottom + 62))
hint.Size = UDim2.fromOffset(260, 14)

local function redraw()
	for id, t in pairs(tiles) do
		local n = kit[id] or 0
		t.count.Text = "×" .. tostring(n)
		t.count.TextColor3 = n > 0 and WHITE or Theme.Colour.TextMuted
		local isSelected = id == selected
		t.rim.Color = isSelected and GOLD or Theme.Colour.Outline
		t.rim.Thickness = isSelected and 3 or 2
		if id ~= "Medkit" then
			t.key.Text = isSelected and "F" or ""
		end
		t.frame.BackgroundTransparency = n > 0 and 0.12 or 0.45
	end
end

local function bump(id: string, colour: Color3?)
	local t = tiles[id]
	if not t then
		return
	end
	t.scale.Scale = 1.18
	TweenService:Create(t.scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	if colour then
		local was = t.rim.Color
		t.rim.Color = colour
		task.delay(0.3, function()
			if t.rim.Color == colour then
				t.rim.Color = was
			end
		end)
	end
end

--- The next throwable along that you have any of (or the next at all, if you have none).
local function cycle()
	local start = table.find(UtilityConfig.Order, selected) or 1
	for step = 1, #UtilityConfig.Order do
		local id = UtilityConfig.Order[(start - 1 + step) % #UtilityConfig.Order + 1]
		if (kit[id] or 0) > 0 then
			selected = id
			redraw()
			bump(id)
			return
		end
	end
end

local function trayVisible()
	gui.Enabled = player:GetAttribute("UIOpen") ~= true
end
player:GetAttributeChangedSignal("UIOpen"):Connect(trayVisible)
trayVisible()
redraw()

-- --------------------------------------------------------------- sounds --

local function sound(id: string, at: Vector3?, volume: number, speed: number)
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed
	if at then
		local holder = Instance.new("Part")
		holder.Anchored = true
		holder.CanCollide = false
		holder.CanQuery = false
		holder.CanTouch = false
		holder.Transparency = 1
		holder.Size = Vector3.new(0.2, 0.2, 0.2)
		holder.CFrame = CFrame.new(at)
		holder.Parent = workspace
		s.RollOffMaxDistance = 220
		s.Parent = holder
		task.delay(4, function()
			holder:Destroy()
		end)
	else
		s.Parent = gui
		task.delay(4, function()
			s:Destroy()
		end)
	end
	s:Play()
end

-- ------------------------------------------------------------- aiming --

local function castParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local skip: { Instance } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	for _, name in ipairs({ "NPCs", "WeaponDrops", "Debris", "HitFlashes", "ArmourPlates", "UtilityFX" }) do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(skip, folder)
		end
	end
	params.FilterDescendantsInstances = skip
	return params
end

local fxFolder = workspace:FindFirstChild("UtilityFX") or Instance.new("Folder")
fxFolder.Name = "UtilityFX"
fxFolder.Parent = workspace

local function part(name: string, size: Vector3, colour: Color3, shape: Enum.PartType?, transparency: number?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = colour
	p.Material = Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Transparency = transparency or 0
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = fxFolder
	return p
end

-- The arc: a string of small beads, and a ring where it lands.
local beads: { Part } = {}
for i = 1, 28 do
	local bead = part("ArcBead", Vector3.new(0.28, 0.28, 0.28), WHITE, Enum.PartType.Ball, 1)
	beads[i] = bead
end
local landing = part("ArcLanding", Vector3.new(0.08, 3, 3), GOLD, Enum.PartType.Cylinder, 1)

local aiming = false

local function handOrigin(): Vector3?
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return nil
	end
	local camera = workspace.CurrentCamera
	local right = camera and camera.CFrame.RightVector or Vector3.xAxis
	return head.Position + right * 0.9 + Vector3.new(0, -0.3, 0)
end

local function hideArc()
	for _, bead in ipairs(beads) do
		bead.Transparency = 1
	end
	landing.Transparency = 1
end

local function drawArc()
	local camera = workspace.CurrentCamera
	local origin = handOrigin()
	if not camera or not origin then
		hideArc()
		return
	end
	local dir = camera.CFrame.LookVector
	local params = castParams()
	local path = UtilityConfig.Trajectory(origin + dir * 1.2, UtilityConfig.LaunchVelocity(dir), function(a, delta)
		return workspace:Raycast(a, delta, params)
	end)
	local colour = UtilityConfig.Throwables[selected].colour
	local n = #path.points
	for i, bead in ipairs(beads) do
		local index = math.floor((i - 1) / #beads * (n - 1)) + 1
		local point = path.points[index]
		if point and index < n then
			bead.CFrame = CFrame.new(point)
			bead.Color = colour:Lerp(WHITE, 0.4)
			bead.Transparency = 0.15 + 0.6 * (i / #beads)
		else
			bead.Transparency = 1
		end
	end
	landing.CFrame = CFrame.new(path.rest + Vector3.new(0, -0.3, 0)) * CFrame.Angles(0, 0, math.pi / 2)
	landing.Color = colour
	local radius = selected == "Frag" and UtilityConfig.Throwables.Frag.radius * 0.5
		or selected == "Smoke" and UtilityConfig.Throwables.Smoke.radius or 3
	landing.Size = Vector3.new(0.08, radius * 2, radius * 2)
	landing.Transparency = path.landed and 0.55 or 1
end

RunService.RenderStepped:Connect(function()
	if aiming then
		drawArc()
	end
end)

local function canAct(): boolean
	if UserInputService:GetFocusedTextBox() or player:GetAttribute("UIOpen") == true then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0
end

local function startAim()
	if not canAct() then
		return
	end
	if (kit[selected] or 0) <= 0 then
		cycle()
	end
	if (kit[selected] or 0) <= 0 then
		bump(selected, Theme.Colour.Danger)
		return
	end
	aiming = true
	drawArc()
end

local function release()
	if not aiming then
		return
	end
	aiming = false
	hideArc()
	local camera = workspace.CurrentCamera
	local origin = handOrigin()
	if not camera or not origin or (kit[selected] or 0) <= 0 then
		return
	end
	UtilityAction:FireServer("throw", selected, origin, camera.CFrame.LookVector)
	bump(selected, GOLD)
	sound("rbxasset://sounds/swoosh.wav", nil, 0.5, 1.2)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == UtilityConfig.Keys.Throw then
		startAim()
	elseif input.KeyCode == UtilityConfig.Keys.Cycle then
		if canAct() then
			cycle()
		end
	elseif input.KeyCode == UtilityConfig.Keys.Medkit then
		if canAct() then
			if (kit.Medkit or 0) <= 0 then
				bump("Medkit", Theme.Colour.Danger)
			else
				UtilityAction:FireServer("medkit")
				bump("Medkit", Theme.Colour.Accent)
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == UtilityConfig.Keys.Throw then
		release()
	end
end)

-- ------------------------------------------------------------ in flight --

local SHELL = {
	Frag = { colour = Color3.fromRGB(78, 94, 60), band = Color3.fromRGB(46, 50, 44), shape = Enum.PartType.Ball,
		size = Vector3.new(0.9, 0.9, 0.9) },
	Flash = { colour = Color3.fromRGB(150, 156, 166), band = Color3.fromRGB(255, 226, 90), shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.1, 0.7, 0.7) },
	Smoke = { colour = Color3.fromRGB(120, 128, 138), band = Color3.fromRGB(236, 238, 240), shape = Enum.PartType.Cylinder,
		size = Vector3.new(1.2, 0.75, 0.75) },
}

local function flight(data: any)
	if type(data) ~= "table" or type(data.points) ~= "table" or type(data.times) ~= "table" then
		return
	end
	local look = SHELL[data.kind]
	if not look then
		return
	end
	local path = { points = data.points, times = data.times, rest = data.points[#data.points], restAt = 0, landed = true }
	local shell = part("Thrown" .. tostring(data.kind), look.size, look.colour, look.shape)
	-- A frag's pin cap sits on top of the ball; the canisters wear a band round the middle.
	local isBall = look.shape == Enum.PartType.Ball
	local band = isBall and part("Cap", Vector3.new(0.4, 0.3, 0.4), look.band)
		or part("Band", look.size * Vector3.new(0.35, 1.05, 1.05), look.band, look.shape)
	local bandOffset = isBall and CFrame.new(0, 0.5, 0) or CFrame.new()
	local fuse = tonumber(data.fuse) or 2
	local start = os.clock()
	local spin = 0
	local lastBeep = 0
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - start
		if t >= fuse or not shell.Parent then
			connection:Disconnect()
			shell:Destroy()
			band:Destroy()
			return
		end
		local at = UtilityConfig.PositionAt(path :: any, t)
		local moving = t < (path.times[#path.times] or 0)
		spin += dt * (moving and 14 or 0)
		shell.CFrame = CFrame.new(at) * CFrame.Angles(spin, spin * 0.6, 0)
		band.CFrame = shell.CFrame * bandOffset
		-- A frag lying there blinks and beeps faster and faster.
		if data.kind == "Frag" and not moving then
			local left = fuse - t
			local rate = left > 0.7 and 0.35 or 0.1
			if os.clock() - lastBeep > rate then
				lastBeep = os.clock()
				band.Color = band.Color == Theme.Colour.Danger and look.band or Theme.Colour.Danger
				sound("rbxasset://sounds/electronicpingshort.wav", at, 0.45, 1.7)
			end
		end
	end)
	sound("rbxasset://sounds/swoosh.wav", path.points[1], 0.35, 0.9)
end

-- ----------------------------------------------------------------- flash --

local whiteout = Instance.new("Frame")
whiteout.Name = "Whiteout"
whiteout.BackgroundColor3 = WHITE
whiteout.BackgroundTransparency = 1
whiteout.BorderSizePixel = 0
whiteout.Size = UDim2.fromScale(1, 1)
whiteout.ZIndex = 50

local whiteGui = Instance.new("ScreenGui")
whiteGui.Name = "FlashWhiteout"
whiteGui.ResetOnSpawn = false
whiteGui.IgnoreGuiInset = true
whiteGui.DisplayOrder = 60
whiteGui.Parent = playerGui
whiteout.Parent = whiteGui

local blindTween: Tween? = nil

--- How long this screen is blinded by a flash at `centre` (0 if it could not be seen).
local function blindnessFrom(centre: Vector3): number
	local camera = workspace.CurrentCamera
	if not camera then
		return 0
	end
	local eye = camera.CFrame.Position
	local offset = centre - eye
	local d = offset.Magnitude
	if d > UtilityConfig.Throwables.Flash.radius then
		return 0
	end
	local hit = workspace:Raycast(eye, offset, castParams())
	if hit and (hit.Position - centre).Magnitude > 1.5 then
		return 0
	end
	local facing = d > 0.1 and camera.CFrame.LookVector:Dot(offset.Unit) or 1
	return UtilityConfig.BlindFor(d, facing)
end

local function flash(centre: Vector3)
	-- Everyone sees the pop itself.
	local pop = part("FlashPop", Vector3.new(1, 1, 1), WHITE, Enum.PartType.Ball, 0)
	pop.CFrame = CFrame.new(centre)
	local light = Instance.new("PointLight")
	light.Brightness = 10
	light.Range = 40
	light.Color = Color3.fromRGB(255, 250, 230)
	light.Parent = pop
	TweenService:Create(pop, TweenInfo.new(0.25), { Size = Vector3.new(7, 7, 7), Transparency = 1 }):Play()
	TweenService:Create(light, TweenInfo.new(0.35), { Brightness = 0 }):Play()
	task.delay(0.5, function()
		pop:Destroy()
	end)
	sound("rbxassetid://9117893517", centre, 0.9, 1.4)
	local blind = blindnessFrom(centre)
	if blind <= 0.15 then
		return
	end
	if blindTween then
		blindTween:Cancel()
	end
	whiteout.BackgroundTransparency = math.clamp(0.05 + (1 - blind / 3.4) * 0.3, 0, 0.6)
	-- Held white, then an ease back to sight.
	local hold = blind * 0.45
	local tween = TweenService:Create(whiteout, TweenInfo.new(blind - hold, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 })
	blindTween = tween
	task.delay(hold, function()
		if blindTween == tween then
			tween:Play()
		end
	end)
	-- The ringing.
	sound("rbxasset://sounds/electronicpingshort.wav", nil, 0.35, 3.2)
	player:SetAttribute("FlashedUntil", os.clock() + blind)
end

-- ----------------------------------------------------------------- smoke --

local SMOKE_GREYS = { Color3.fromRGB(196, 200, 206), Color3.fromRGB(178, 184, 192), Color3.fromRGB(214, 216, 220) }

local function smoke(centre: Vector3, radius: number, duration: number)
	local puffs: { Part } = {}
	local rng = Random.new(math.floor(centre.X * 7 + centre.Z * 13))
	for i = 1, 16 do
		local a = rng:NextNumber(0, math.pi * 2)
		local r = rng:NextNumber(0, radius * 0.7)
		local y = rng:NextNumber(0.5, radius * 0.55)
		local size = rng:NextNumber(radius * 0.55, radius * 0.9)
		local puff = part("Smoke", Vector3.new(1, 1, 1), SMOKE_GREYS[i % #SMOKE_GREYS + 1], Enum.PartType.Ball, 0.05)
		puff.CFrame = CFrame.new(centre + Vector3.new(0, 1, 0))
		TweenService:Create(puff, TweenInfo.new(0.9 + i * 0.04, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(size, size, size),
			CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)),
		}):Play()
		table.insert(puffs, puff)
	end
	sound("rbxasset://sounds/swoosh.wav", centre, 0.7, 0.5)
	task.delay(math.max(1, duration - 2.5), function()
		for _, puff in ipairs(puffs) do
			local fade = TweenService:Create(puff, TweenInfo.new(2.5), { Transparency = 1,
				CFrame = puff.CFrame + Vector3.new(0, 2, 0) })
			fade.Completed:Once(function()
				puff:Destroy()
			end)
			fade:Play()
		end
	end)
end

-- ---------------------------------------------------------------- medkit --

local healBar = Instance.new("Frame")
healBar.Name = "HealBar"
healBar.AnchorPoint = Vector2.new(0.5, 0)
healBar.Position = UDim2.new(0.5, 0, 0.5, 44)
healBar.Size = UDim2.fromOffset(200, 26)
healBar.BackgroundTransparency = 1
healBar.Visible = false
healBar.Parent = gui
local healLabel = Components.Label(healBar, { text = "✚ PATCHING UP", font = Theme.Font.Bold, size = 13,
	colour = UtilityConfig.Medkit.colour, align = Enum.TextXAlignment.Center, outline = 1.5 })
healLabel.Size = UDim2.new(1, 0, 0, 14)
local healFill = Components.Bar(healBar, { height = 8, colour = UtilityConfig.Medkit.colour, radius = 4 })
healFill.instance.Position = UDim2.fromOffset(0, 17)
healFill.instance.Size = UDim2.new(1, 0, 0, 8)

local function heal(character: any, channel: number)
	if typeof(character) ~= "Instance" or not character:IsA("Model") then
		return
	end
	local head = character:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local plus = Instance.new("BillboardGui")
		plus.Adornee = head
		plus.Size = UDim2.fromOffset(40, 40)
		plus.StudsOffsetWorldSpace = Vector3.new(0, 2.6, 0)
		plus.MaxDistance = 120
		plus.ResetOnSpawn = false
		plus.Parent = playerGui
		local glyph = Components.Label(plus, { text = "✚", size = 30, colour = UtilityConfig.Medkit.colour,
			align = Enum.TextXAlignment.Center, outline = 2 })
		glyph.Size = UDim2.fromScale(1, 1)
		task.delay(channel + 0.2, function()
			plus:Destroy()
		end)
	end
	if character == player.Character then
		healBar.Visible = true
		healFill:SetFraction(0, false)
		local started = os.clock()
		local connection
		connection = RunService.RenderStepped:Connect(function()
			local f = math.clamp((os.clock() - started) / channel, 0, 1)
			healFill:SetFraction(f, false)
			if f >= 1 then
				connection:Disconnect()
				healBar.Visible = false
			end
		end)
	end
end

local function popup(text: string, colour: Color3)
	local label = Components.Label(gui, { text = text, face = Theme.Face.HeavyItalic, size = 26, colour = colour,
		align = Enum.TextXAlignment.Center, outline = 2.4 })
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.new(0.5, 0, 0.5, 90)
	label.Size = UDim2.fromOffset(300, 32)
	TweenService:Create(label, TweenInfo.new(1.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Position = UDim2.new(0.5, 0, 0.5, 60), TextTransparency = 1 }):Play()
	task.delay(1.2, function()
		label:Destroy()
	end)
end

-- ---------------------------------------------------------------- plates --

-- Plates on the ground turn slowly so they read as something to pick up.
RunService.RenderStepped:Connect(function(dt)
	local folder = workspace:FindFirstChild("ArmourPlates")
	if not folder then
		return
	end
	for _, plate in ipairs(folder:GetChildren()) do
		if plate:IsA("BasePart") then
			plate.CFrame = plate.CFrame * CFrame.Angles(0, dt * 1.6, 0)
			local stripe = plate:FindFirstChild("Stripe")
			if stripe and stripe:IsA("BasePart") then
				stripe.CFrame = plate.CFrame
			end
		end
	end
end)

-- ---------------------------------------------------------------- events --

UtilityEvent.OnClientEvent:Connect(function(kind: unknown, a: any, b: any, c: any)
	if kind == "kit" and type(a) == "table" then
		for id in pairs(kit) do
			kit[id] = tonumber(a[id]) or 0
		end
		if (kit[selected] or 0) <= 0 then
			cycle()
		end
		redraw()
	elseif kind == "thrown" then
		flight(a)
	elseif kind == "explode" and typeof(a) == "Vector3" and type(b) == "number" then
		ExplosionFX.Play(a, b)
	elseif kind == "flash" and typeof(a) == "Vector3" then
		flash(a)
	elseif kind == "smoke" and typeof(a) == "Vector3" and type(b) == "number" and type(c) == "number" then
		smoke(a, b, c)
	elseif kind == "heal" and type(b) == "number" then
		heal(a, b)
	elseif kind == "healed" and type(a) == "number" then
		popup(("+%d HP"):format(a), UtilityConfig.Medkit.colour)
	elseif kind == "plate" and type(a) == "number" then
		popup("+ARMOUR", Theme.Colour.Armour)
		sound("rbxasset://sounds/electronicpingshort.wav", nil, 0.4, 0.8)
	end
end)

-- Ask for the kit once the server knows about us (it also sends it on every spawn).
UtilityAction:FireServer("kit")
