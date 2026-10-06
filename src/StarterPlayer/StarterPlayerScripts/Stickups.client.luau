--!strict
-- A robbed store, as everyone nearby sees and hears it:
--
--   * the till: its drawer slides out with a ka-chunk and a ching, the screen shows what was
--     taken, and the money jumps out of it -- notes thrown up, tumbling, fluttering down -- then
--     whips across into the robber's hands; "+$620" floats up off the counter. The drawer
--     shuts itself a while later;
--   * a cash machine: the screen goes red, DISPENSING, and it spits a stream of notes out of
--     the slot at the robber, then reads OUT OF CASH until the job is long over;
--   * the alarm: a red light beating over the target and a two-tone ring out into the street,
--     for as long as the robber's heat lasts (or until the job ends).
--
-- The clerk's hands going up is StaffLife.client; the bar and the tags are
-- UI.Modules.Stickups. Everything here is local and cosmetic: the money is already in the
-- bag, server-side, before any of it moves.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local StickupEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StickupEvent") :: RemoteEvent

local RING = "rbxasset://sounds/electronicpingshort.wav"
-- Samples already in the place (the UI's), pitched to the job: the reload's clunk for the
-- drawer's mechanism, the chest's bright ring for the bell, the dash whoosh for the notes.
local CLUNK = "rbxassetid://117963160131194"
local BELL = "rbxassetid://5789211405"
local WHOOSH = "rbxassetid://8653395088"

local SHOW_RANGE = 140      -- past this nobody sees the money fly
local DRAWER_OUT = 0.95     -- studs the till's drawer slides out
local DRAWER_OPEN = 7       -- seconds before it shuts again
local ATM_DOWN = 25         -- seconds a robbed cash machine reads OUT OF CASH

local rng = Random.new()

local function holder(at: Vector3): Part
	local part = Instance.new("Part")
	part.Name = "StickupSound"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(0.2, 0.2, 0.2)
	part.CFrame = CFrame.new(at)
	part.Parent = workspace
	return part
end

--- A one-shot at `at`, `delay` seconds from now.
local function sound(id: string, at: Vector3, volume: number, speed: number, delay: number?)
	task.delay(delay or 0, function()
		local h = holder(at)
		local s = Instance.new("Sound")
		s.SoundId = id
		s.Volume = volume
		s.PlaybackSpeed = speed
		s.RollOffMinDistance = 6
		s.RollOffMaxDistance = 70
		s.Parent = h
		s:Play()
		task.delay(3, function()
			h:Destroy()
		end)
	end)
end

-- --------------------------------------------------------------- the alarm --

local alarms: { [number]: () -> () } = {}

local function alarm(at: Vector3, seconds: number, robberId: number)
	local h = holder(at + Vector3.new(0, 3, 0))
	h.Name = "StickupAlarm"
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 50, 40)
	light.Range = 26
	light.Brightness = 0
	light.Parent = h
	local ring = Instance.new("Sound")
	ring.SoundId = RING
	ring.Volume = 0.9
	ring.RollOffMaxDistance = 160
	ring.Parent = h

	local started = os.clock()
	local lastRing = -1
	local conn: RBXScriptConnection
	local function stop()
		if conn then
			conn:Disconnect()
		end
		h:Destroy()
		if alarms[robberId] == stop then
			alarms[robberId] = nil
		end
	end
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - started
		if t > seconds then
			stop()
			return
		end
		-- Two beats a second, and a hi-lo ring on every other one.
		light.Brightness = if math.floor(t * 4) % 2 == 0 then 4 else 0.3
		local beat = math.floor(t / 0.55)
		if beat ~= lastRing then
			lastRing = beat
			ring.PlaybackSpeed = if beat % 2 == 0 then 1.25 else 0.95
			ring:Play()
		end
	end)
	if alarms[robberId] then
		alarms[robberId]()
	end
	alarms[robberId] = stop
end

-- --------------------------------------------------------------- the money --

local function robberRoot(robberId: number): BasePart?
	local robber = Players:GetPlayerByUserId(robberId)
	local character = robber and robber.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

type Bill = {
	part: BasePart,
	pos: Vector3,
	vel: Vector3,
	rot: CFrame,
	spin: Vector3,
	delay: number,
	fly: number,
	from: Vector3?,
	sway: number,
}

local FLUTTER = -7          -- a note falls no faster than this: it is paper
local GRAVITY = 34
local COLLECT = 0.32        -- seconds a note takes to reach the robber's hands
local BILL = Vector3.new(0.55, 0.03, 0.26)

--- Throw `count` notes out from `from`: `push` is how they leave (outward and up), `spread`
--- how much they fan sideways along `side`, `gap` the time between one note and the next.
--- They tumble and flutter down to `floor`, then fly to the robber (or, with nobody to catch
--- them, lie a moment and fade).
local function throwMoney(from: Vector3, push: Vector3, side: Vector3, spread: number, count: number, gap: number,
	floor: number, robberId: number)
	local bills: { Bill } = {}
	for i = 1, count do
		local part = Instance.new("Part")
		part.Name = "StickupCash"
		part.Size = BILL
		part.Color = if i % 3 == 0 then Color3.fromRGB(86, 152, 88) else Color3.fromRGB(122, 192, 112)
		part.Material = Enum.Material.SmoothPlastic
		part.Anchored = true
		part.CanCollide = false
		part.CanQuery = false
		part.CanTouch = false
		part.CastShadow = false
		part.Transparency = 1
		part.CFrame = CFrame.new(from)
		part.Parent = workspace
		local vel = push * rng:NextNumber(0.75, 1.15) + side * rng:NextNumber(-spread, spread)
			+ Vector3.new(0, rng:NextNumber(-0.15, 0.15) * push.Y, 0)
		local bill: Bill = {
			part = part, pos = from + side * rng:NextNumber(-0.25, 0.25), vel = vel,
			rot = CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28)),
			spin = Vector3.new(rng:NextNumber(-12, 12), rng:NextNumber(-8, 8), rng:NextNumber(-12, 12)),
			delay = (i - 1) * gap, fly = rng:NextNumber(0.55, 0.8), from = nil, sway = rng:NextNumber(0, 6.28),
		}
		table.insert(bills, bill)
	end
	local started = os.clock()
	local caught = 0
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function(dt: number)
		local t = os.clock() - started
		local live = 0
		local root = robberRoot(robberId)
		for _, b in ipairs(bills) do
			local life = t - b.delay
			if b.part.Parent == nil or life < 0 then
				if b.part.Parent then
					live += 1
				end
				continue
			end
			live += 1
			b.part.Transparency = 0
			if life < b.fly or not root then
				-- Thrown: up, over and down, turning over, then floating like paper.
				b.vel -= Vector3.new(0, GRAVITY * dt, 0)
				if b.vel.Y < FLUTTER then
					b.vel = Vector3.new(b.vel.X * 0.9, FLUTTER, b.vel.Z * 0.9)
				end
				local sway = if b.vel.Y < 0 then Vector3.new(math.sin(life * 9 + b.sway), 0, math.cos(life * 7 + b.sway)) * 0.8
					else Vector3.zero
				b.pos += (b.vel + sway) * dt
				if b.pos.Y < floor then
					b.pos = Vector3.new(b.pos.X, floor, b.pos.Z)
					b.vel = Vector3.new(b.vel.X * 0.3, 0, b.vel.Z * 0.3)
					b.spin *= 0.3
				end
				b.rot *= CFrame.Angles(b.spin.X * dt, b.spin.Y * dt, b.spin.Z * dt)
				b.part.CFrame = CFrame.new(b.pos) * b.rot
				-- Nobody to catch it: it lies there a moment and fades.
				if not root and life > b.fly + 1.2 then
					b.part.Transparency = math.clamp((life - b.fly - 1.2) / 0.5, 0, 1)
					if life > b.fly + 1.7 then
						b.part:Destroy()
					end
				end
			else
				-- Caught: a quick arc into the robber's hands, shrinking as it goes.
				local start = b.from or b.pos
				b.from = start
				local u = math.clamp((life - b.fly) / COLLECT, 0, 1)
				local into = root.Position + Vector3.new(0, 0.4, 0)
				local eased = u * u
				local p = start:Lerp(into, eased) + Vector3.new(0, math.sin(math.pi * u) * 1.1, 0)
				b.rot *= CFrame.Angles(b.spin.X * dt * 1.5, b.spin.Y * dt * 1.5, 0)
				b.part.Size = BILL * (1 - 0.65 * u)
				b.part.CFrame = CFrame.new(p) * b.rot
				if u >= 1 then
					b.part:Destroy()
					caught += 1
					if robberId == Players.LocalPlayer.UserId and caught % 3 == 1 then
						sound(RING, into, 0.25, 2.1 + caught * 0.04)
					end
				end
			end
		end
		if live == 0 or t > 10 then
			conn:Disconnect()
			for _, b in ipairs(bills) do
				if b.part.Parent then
					b.part:Destroy()
				end
			end
		end
	end)
end

--- "+$620" lifting off `at` and fading.
local function amountPop(at: Vector3, amount: number)
	local h = holder(at)
	h.Name = "StickupAmount"
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.fromOffset(160, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 0.6, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.Parent = h
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 30
	label.Text = ("+$%d"):format(amount)
	label.TextColor3 = Color3.fromRGB(132, 236, 128)
	label.Parent = gui
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(12, 30, 14)
	edge.Thickness = 3
	edge.Parent = label
	local scale = Instance.new("UIScale")
	scale.Scale = 0.4
	scale.Parent = label
	TweenService:Create(scale, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(gui, TweenInfo.new(1.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ StudsOffsetWorldSpace = Vector3.new(0, 3, 0) }):Play()
	task.delay(1.1, function()
		local fade = TweenInfo.new(0.6)
		TweenService:Create(label, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(edge, fade, { Transparency = 1 }):Play()
	end)
	task.delay(1.9, function()
		h:Destroy()
	end)
end

--- The lettering on a sign built by the district (Kit `sign`: a board named "Sign_<text>").
local function signLabel(model: Instance, text: string): TextLabel?
	local board = model:FindFirstChild("Sign_" .. text)
	local gui = board and board:FindFirstChildOfClass("SurfaceGui")
	local label = gui and gui:FindFirstChildOfClass("TextLabel")
	return label
end

-- Each drawer's shut position, the first time it is opened; and which opening is current.
local shut: { [Model]: CFrame } = {}
local opening: { [Model]: number } = {}

--- Slide `drawer` along `dir` from shut to `out` studs out over `time`, easing with `style`.
local function slide(drawer: Model, from: number, to: number, dir: Vector3, time: number, style: Enum.EasingStyle)
	local closed = shut[drawer]
	local started = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		if drawer.Parent == nil then
			conn:Disconnect()
			return
		end
		local u = math.clamp((os.clock() - started) / time, 0, 1)
		local k = TweenService:GetValue(u, style, Enum.EasingDirection.Out)
		drawer:PivotTo(closed + dir * (from + (to - from) * k))
		if u >= 1 then
			conn:Disconnect()
		end
	end)
end

local function robTill(till: Model, register: BasePart, amount: number, robberId: number)
	local drawer = till:FindFirstChild("RegisterDrawer")
	local out = -register.CFrame.RightVector
	local mouth = register.Position + out * 0.4 + Vector3.new(0, 0.25, 0)
	local floor = register.Position.Y - register.Size.Y / 2 + 0.04
	if drawer and drawer:IsA("Model") then
		shut[drawer] = shut[drawer] or drawer:GetPivot()
		local token = os.clock()
		opening[drawer] = token
		-- Ka-chunk, ching: the drawer springs out.
		slide(drawer, 0, DRAWER_OUT, out, 0.32, Enum.EasingStyle.Back)
		mouth = shut[drawer].Position + out * (DRAWER_OUT + 0.1) + Vector3.new(0, 0.15, 0)
		task.delay(DRAWER_OPEN, function()
			if opening[drawer] == token then
				slide(drawer, DRAWER_OUT, 0, out, 0.4, Enum.EasingStyle.Quad)
				sound(CLUNK, register.Position, 0.35, 1.6, 0.3)
			end
		end)
	end
	sound(CLUNK, register.Position, 0.55, 1.45)
	sound(BELL, register.Position, 0.5, 1.35, 0.1)
	sound(WHOOSH, register.Position, 0.22, 1.9, 0.18)
	-- The screen shows what went.
	local screen = signLabel(till, "$0.00")
	if screen then
		screen.Text = ("-$%d.00"):format(amount)
		task.delay(DRAWER_OPEN + 0.4, function()
			screen.Text = "$0.00"
		end)
	end
	-- The notes jump up out of the drawer and over toward the robber.
	task.delay(0.12, function()
		throwMoney(mouth, out * 3.5 + Vector3.new(0, 10, 0), register.CFrame.LookVector, 2.2, 10, 0.03, floor, robberId)
	end)
	amountPop(register.Position + Vector3.new(0, 1.4, 0), amount)
end

local function robMachine(machine: Model, body: BasePart, amount: number, robberId: number)
	local out = -body.CFrame.RightVector
	local slot = machine:FindFirstChild("ATMCashSlot")
	local mouth = if slot and slot:IsA("BasePart") then slot.Position + out * 0.1 else body.Position + out * 0.5
	local floor = body.Position.Y - body.Size.Y / 2 + 0.05
	sound(CLUNK, body.Position, 0.5, 0.85)
	sound(WHOOSH, body.Position, 0.3, 1.6, 0.25)
	sound(WHOOSH, body.Position, 0.22, 2.1, 0.7)
	-- The screen: red, DISPENSING, then OUT OF CASH until long after.
	local screen = machine:FindFirstChild("ATMScreen")
	local label = signLabel(machine, "WELCOME")
	local was = if screen and screen:IsA("BasePart") then screen.Color else nil
	if screen and screen:IsA("BasePart") then
		screen.Color = Color3.fromRGB(196, 52, 46)
	end
	if label then
		label.Text = "DISPENSING"
		task.delay(1.6, function()
			label.Text = "OUT OF CASH"
		end)
	end
	task.delay(ATM_DOWN, function()
		if screen and screen:IsA("BasePart") and was then
			screen.Color = was
		end
		if label then
			label.Text = "WELCOME"
		end
	end)
	-- A stream of notes out of the slot.
	task.delay(0.3, function()
		throwMoney(mouth, out * 8 + Vector3.new(0, 4, 0), body.CFrame.LookVector, 1.6, 12, 0.06, floor, robberId)
	end)
	amountPop(body.Position + Vector3.new(0, 2.2, 0) + out * 0.6, amount)
end

local function showRobbery(part: Instance, kind: string, amount: number, robberId: number)
	if not part:IsA("BasePart") then
		return
	end
	local camera = workspace.CurrentCamera
	if camera and (camera.CFrame.Position - part.Position).Magnitude > SHOW_RANGE then
		return
	end
	local model = part.Parent
	if not model or not model:IsA("Model") then
		return
	end
	if kind == "atm" then
		robMachine(model, part, amount, robberId)
	else
		robTill(model, part, amount, robberId)
	end
end

StickupEvent.OnClientEvent:Connect(function(kind: unknown, data: unknown)
	if type(data) ~= "table" then
		return
	end
	local d = data :: any
	local robberId = tonumber(d.robberId) or 0
	if kind == "alarm" and typeof(d.at) == "Vector3" then
		alarm(d.at, tonumber(d.seconds) or 60, robberId)
		-- The target may not be here at all (streamed out): then there is nothing to see.
		if typeof(d.part) == "Instance" then
			local ok, err = pcall(function()
				showRobbery(d.part, tostring(d.kind), tonumber(d.amount) or 0, robberId)
			end)
			if not ok then
				warn("[Stickups] " .. tostring(err))
			end
		end
	elseif (kind == "getaway" or kind == "stolen" or kind == "busted") and alarms[robberId] then
		alarms[robberId]()
	end
end)
