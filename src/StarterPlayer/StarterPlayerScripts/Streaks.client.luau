--!strict
-- Killstreak rewards in the world (the meter is UI.Modules.Streaks, fed by MainUI):
--
--   RADAR       every enemy near you outlined in red through walls, for as long as it lasts,
--               with a sweep across the screen when it comes up. Yours alone.
--   OVERSHIELD  a violet shell on anyone wearing one -- everybody can see who is shielded --
--               that flares when it is hit and shatters when it breaks.
--   AIRSTRIKE   hold the key to aim (a red mark follows your crosshair), let go to call it.
--               Everybody then sees the red strike zone with a countdown, and a jet comes in
--               low over it as the shells land. The shells' blasts are the frag's own
--               explosion (UtilityEvent "explode"), drawn by Utility.client.
--
-- Presentation only: the server (StreakRewardService) decides who has what, validates the
-- call and does the damage.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local CollectionService = game:GetService("CollectionService")

local StreakConfig = require(ReplicatedStorage:WaitForChild("StreakConfig"))
local StrikeJet = require(ReplicatedStorage:WaitForChild("StrikeJet"))
local UISound = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Modules"):WaitForChild("UISound"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local StreakEvent = remotes:WaitForChild("StreakEvent") :: RemoteEvent
local StreakAction = remotes:WaitForChild("StreakAction") :: RemoteEvent

local RED = Color3.fromRGB(255, 58, 58)
local VIOLET = StreakConfig.Rewards[2].colour

local fx = Instance.new("Folder")
fx.Name = "StreakFX"
fx.Parent = workspace

local screen = Instance.new("ScreenGui")
screen.Name = "StreakFX"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.DisplayOrder = 4
screen.Parent = player:WaitForChild("PlayerGui")

local function part(props: { [string]: any }): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do
		(p :: any)[k] = v
	end
	p.Parent = props.Parent or fx
	return p
end

local function sound(id: string, at: Vector3 | BasePart, volume: number, speed: number, range: number): Sound
	local holder: BasePart
	if typeof(at) == "Vector3" then
		holder = part({ Size = Vector3.new(0.2, 0.2, 0.2), Transparency = 1, CFrame = CFrame.new(at) })
		task.delay(8, function()
			holder:Destroy()
		end)
	else
		holder = at
	end
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed
	s.RollOffMaxDistance = range
	s.Parent = holder
	s:Play()
	return s
end

local function fade(inst: Instance, time: number, goal: { [string]: any }, destroy: boolean?)
	local tween = TweenService:Create(inst, TweenInfo.new(time, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), goal)
	if destroy then
		tween.Completed:Once(function()
			inst:Destroy()
		end)
	end
	tween:Play()
end

-- --------------------------------------------------------------------- radar --

local radarUntil = 0
local radarMarks: { [Model]: Highlight } = {}

local function clearRadar()
	for model, mark in pairs(radarMarks) do
		mark:Destroy()
		radarMarks[model] = nil
	end
end

--- Everyone the radar can show: other players out in the world, and the fighters.
local function enemies(): { Model }
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character and p:GetAttribute("DuelState") ~= "duel" then
			table.insert(out, p.Character)
		end
	end
	for _, model in ipairs(CollectionService:GetTagged("GameNPC")) do
		if model:IsA("Model") then
			table.insert(out, model)
		end
	end
	return out
end

local function updateRadar()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if os.clock() >= radarUntil or not (root and root:IsA("BasePart")) then
		clearRadar()
		return
	end
	local r = StreakConfig.Radar
	local found = {}
	for _, model in ipairs(enemies()) do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		local body = model:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and body and body:IsA("BasePart") then
			local d = (body.Position - root.Position).Magnitude
			if d <= r.range then
				table.insert(found, { model = model, d = d })
			end
		end
	end
	table.sort(found, function(a, b)
		return a.d < b.d
	end)
	local keep: { [Model]: boolean } = {}
	for i = 1, math.min(#found, r.maxShown) do
		local model = found[i].model
		keep[model] = true
		if not radarMarks[model] or radarMarks[model].Parent ~= model then
			local mark = Instance.new("Highlight")
			mark.Name = "RadarMark"
			mark.FillColor = RED
			mark.FillTransparency = 0.72
			mark.OutlineColor = Color3.fromRGB(255, 120, 120)
			mark.OutlineTransparency = 0
			mark.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			mark.Adornee = model
			mark.Parent = model
			radarMarks[model] = mark
		end
	end
	for model, mark in pairs(radarMarks) do
		if not keep[model] then
			mark:Destroy()
			radarMarks[model] = nil
		end
	end
end

--- The sweep: a ring that rolls out from the crosshair to the edges of the screen.
local function sweep()
	local ring = Instance.new("Frame")
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(40, 40)
	ring.BackgroundTransparency = 1
	ring.Parent = screen
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = ring
	local stroke = Instance.new("UIStroke")
	stroke.Color = StreakConfig.Rewards[1].colour
	stroke.Thickness = 6
	stroke.Transparency = 0.1
	stroke.Parent = ring
	local size = math.max(camera.ViewportSize.X, camera.ViewportSize.Y) * 1.3
	fade(ring, 0.9, { Size = UDim2.fromOffset(size, size) }, true)
	fade(stroke, 0.9, { Transparency = 1, Thickness = 1 })
	UISound.Play("Tick", 0.9, 0.8)
	task.delay(0.25, function()
		UISound.Play("Tick", 0.6, 1.1)
	end)
end

-- ---------------------------------------------------------------- overshield --

local shells: { [Model]: Highlight } = {}

local function shellOf(character: Model): Highlight
	local shell = shells[character]
	if shell and shell.Parent == character then
		return shell
	end
	local made = Instance.new("Highlight")
	made.Name = "Overshield"
	made.FillColor = VIOLET
	made.FillTransparency = 0.8
	made.OutlineColor = VIOLET
	made.OutlineTransparency = 0.3
	made.DepthMode = Enum.HighlightDepthMode.Occluded
	made.Adornee = character
	made.Parent = character
	shells[character] = made
	return made
end

--- A burst of violet round a body: the shield going up, or shattering.
local function burst(character: Model, colour: Color3, size: number)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local ball = part({
		Shape = Enum.PartType.Ball, Size = Vector3.new(3, 3, 3), Color = colour,
		Material = Enum.Material.ForceField, Transparency = 0.1, CFrame = root.CFrame,
	})
	fade(ball, 0.5, { Size = Vector3.new(size, size, size), Transparency = 1 }, true)
end

local function watchShield(character: Model)
	local last = tonumber(character:GetAttribute("Overshield")) or 0
	local function refresh()
		local now = tonumber(character:GetAttribute("Overshield")) or 0
		if now > 0 then
			local shell = shellOf(character)
			if now < last then
				-- Hit: the shell flares, then settles.
				shell.FillTransparency = 0.35
				fade(shell, 0.35, { FillTransparency = 0.8 })
			end
		elseif last > 0 then
			-- Broken.
			local shell = shells[character]
			if shell then
				shells[character] = nil
				shell.FillTransparency = 0.2
				fade(shell, 0.4, { FillTransparency = 1, OutlineTransparency = 1 }, true)
			end
			burst(character, VIOLET, 9)
		end
		last = now
	end
	refresh()
	character:GetAttributeChangedSignal("Overshield"):Connect(refresh)
end

local function watchPlayer(p: Player)
	if p.Character then
		watchShield(p.Character)
	end
	p.CharacterAdded:Connect(watchShield)
end
Players.PlayerAdded:Connect(watchPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	watchPlayer(p)
end

-- ----------------------------------------------------------------- airstrike --

--- A red disc flat on the ground.
local function disc(at: Vector3, radius: number, transparency: number): Part
	return part({
		Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.12, radius * 2, radius * 2), Color = RED,
		Material = Enum.Material.Neon, Transparency = transparency,
		CFrame = CFrame.new(at + Vector3.new(0, 0.08, 0)) * CFrame.Angles(0, 0, math.rad(90)),
	})
end

--- The aiming mark while the key is held: a ring and a post where the crosshair meets the world.
local aimMark: Model? = nil
local function showAim(at: Vector3?, inRange: boolean)
	if not at then
		if aimMark then
			aimMark:Destroy()
			aimMark = nil
		end
		return
	end
	if not aimMark then
		local m = Instance.new("Model")
		m.Name = "AirstrikeAim"
		local ring = disc(Vector3.zero, StreakConfig.Airstrike.radius, 0.55)
		ring.Name = "Ring"
		ring.Parent = m
		part({ Name = "Post", Size = Vector3.new(0.35, 30, 0.35), Color = RED,
			Material = Enum.Material.Neon, Transparency = 0.35, Parent = m })
		m.Parent = fx
		aimMark = m
	end
	local m = aimMark :: Model
	local colour = if inRange then RED else Color3.fromRGB(120, 120, 130)
	local ring = m:FindFirstChild("Ring") :: Part
	local post = m:FindFirstChild("Post") :: Part
	ring.Color, post.Color = colour, colour
	ring.CFrame = CFrame.new(at + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	post.CFrame = CFrame.new(at + Vector3.new(0, 15, 0))
end

--- The jet's pass: in low along the run, over the zone as the shells land, and away.
local function flyJet(centre: Vector3, dir: Vector3, altitude: number, overheadIn: number)
	local jet = StrikeJet.Build(fx)
	local speed = 190
	local span = 520
	local total = span / speed
	-- Its flight is timed so it is right overhead `overheadIn` seconds from now.
	local startIn = overheadIn - total / 2
	local up = Vector3.new(0, altitude, 0)
	local from = centre + up - dir * (span / 2)
	local look = CFrame.lookAt(Vector3.zero, dir)
	jet:PivotTo(CFrame.new(from) * look)
	local born = os.clock() + startIn
	local roared = false
	local conn: RBXScriptConnection
	conn = RunService.RenderStepped:Connect(function()
		local t = os.clock() - born
		if t < 0 then
			return
		end
		if not roared then
			roared = true
			local primary = jet.PrimaryPart
			if primary then
				sound("rbxassetid://8653395088", primary, 3, 0.32, 700)
			end
		end
		if t > total then
			conn:Disconnect()
			jet:Destroy()
			return
		end
		-- A shallow dive into the run and a climb out of it; a little roll for life.
		local u = t / total
		local dip = math.sin(u * math.pi) * 18
		jet:PivotTo(CFrame.new(from + dir * (speed * t) - Vector3.new(0, dip, 0)) * look
			* CFrame.Angles(0, 0, math.sin(u * math.pi * 2) * 0.25))
	end)
end

local function strikeZone(data: any)
	local centre = data.at :: Vector3
	local points = data.points :: { Vector3 }
	local radius = tonumber(data.radius) or StreakConfig.Airstrike.radius
	local now = workspace:GetServerTimeNow()
	local untilHit = math.max(0.2, (tonumber(data.hitAt) or now) - now)
	local gap = tonumber(data.gap) or StreakConfig.Airstrike.gap
	local lasts = untilHit + gap * #points + 0.6

	-- The zone: a disc under every shell, pulsing, and a beam at the centre.
	local marks = {}
	for _, point in ipairs(points) do
		local d = disc(point, radius * 0.8, 0.7)
		table.insert(marks, d)
		TweenService:Create(d, TweenInfo.new(0.35, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Transparency = 0.35 }):Play()
	end
	local beam = part({ Size = Vector3.new(0.6, 90, 0.6), Color = RED, Material = Enum.Material.Neon,
		Transparency = 0.4, CFrame = CFrame.new(centre + Vector3.new(0, 45, 0)) })
	table.insert(marks, beam)

	-- The warning over it, with whose it is and the seconds left.
	local label = Instance.new("BillboardGui")
	label.Size = UDim2.fromOffset(240, 60)
	label.StudsOffsetWorldSpace = Vector3.new(0, 12, 0)
	label.AlwaysOnTop = true
	label.MaxDistance = 600
	label.Adornee = beam
	label.Parent = beam
	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Font = Enum.Font.FredokaOne
	text.TextScaled = true
	text.TextColor3 = Color3.new(1, 1, 1)
	text.TextStrokeTransparency = 0
	text.TextStrokeColor3 = Color3.fromRGB(120, 0, 0)
	text.Parent = label
	local mine = data.caller == player.UserId
	local title = if mine then "YOUR AIRSTRIKE" else "⚠ AIRSTRIKE · " .. string.upper(tostring(data.name or "?"))
	local started = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local left = untilHit - (os.clock() - started)
		text.Text = if left > 0 then string.format("%s\n%.1f", title, left) else title
		if os.clock() - started > lasts then
			conn:Disconnect()
		end
	end)
	-- Anyone standing in it hears the warning.
	sound("rbxasset://sounds/electronicpingshort.wav", centre, 1.2, 0.6, 180)
	task.delay(math.max(0, untilHit - 0.9), function()
		sound("rbxassetid://8653395088", centre, 2, 1.8, 260)
	end)

	flyJet(centre, (data.dir :: Vector3?) or Vector3.new(0, 0, -1), tonumber(data.altitude) or 110, untilHit)

	task.delay(lasts, function()
		for _, m in ipairs(marks) do
			if m.Parent then
				fade(m, 0.4, { Transparency = 1 }, true)
			end
		end
	end)
end

-- --------------------------------------------------------------------- input --

local aiming = false

--- Where the crosshair meets the world, and whether an airstrike can be called there.
local function aimPoint(): (Vector3?, boolean)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return nil, false
	end
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, fx, workspace:FindFirstChild("Debris") :: Instance }
	local range = StreakConfig.Airstrike.range
	local hit = workspace:Raycast(ray.Origin, ray.Direction * (range + 80), params)
	if not hit then
		return nil, false
	end
	local flat = Vector3.new(hit.Position.X - root.Position.X, 0, hit.Position.Z - root.Position.Z)
	return hit.Position, flat.Magnitude <= range
end

local function canCall(): boolean
	return (tonumber(player:GetAttribute("AirstrikeCharges")) or 0) > 0
		and player:GetAttribute("UIOpen") ~= true
		and player:GetAttribute("DuelState") ~= "duel"
end

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	if gameProcessed or input.KeyCode ~= StreakConfig.Airstrike.key then
		return
	end
	if canCall() then
		aiming = true
	end
end)

UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.KeyCode ~= StreakConfig.Airstrike.key or not aiming then
		return
	end
	aiming = false
	showAim(nil, false)
	if not canCall() then
		return
	end
	local at, inRange = aimPoint()
	if at and inRange then
		StreakAction:FireServer("airstrike", at)
		UISound.Play("Slam", 0.5, 1.2)
	else
		UISound.Play("Clunk", 0.6, 1.3)
	end
end)

RunService.RenderStepped:Connect(function()
	if aiming then
		if canCall() then
			local at, inRange = aimPoint()
			showAim(at, inRange)
		else
			aiming = false
			showAim(nil, false)
		end
	end
end)

-- -------------------------------------------------------------------- events --

StreakEvent.OnClientEvent:Connect(function(kind: unknown, data: unknown)
	if type(data) ~= "table" then
		return
	end
	local d = data :: any
	if kind == "radar" then
		radarUntil = os.clock() + (tonumber(d.duration) or 0)
		sweep()
		updateRadar()
	elseif kind == "reset" then
		radarUntil = 0
		clearRadar()
		aiming = false
		showAim(nil, false)
	elseif kind == "overshield" then
		local who = Players:GetPlayerByUserId(tonumber(d.userId) or 0)
		if who and who.Character then
			burst(who.Character, VIOLET, 11)
			shellOf(who.Character)
			if who == player then
				UISound.Play("Ring", 0.7, 0.8)
			end
		end
	elseif kind == "airstrike" and typeof(d.at) == "Vector3" and type(d.points) == "table" then
		strikeZone(d)
	end
end)

-- The radar follows people as they move; twice a second is plenty for an outline.
task.spawn(function()
	while true do
		task.wait(0.5)
		if radarUntil > 0 then
			updateRadar()
			if os.clock() >= radarUntil then
				radarUntil = 0
			end
		end
	end
end)
