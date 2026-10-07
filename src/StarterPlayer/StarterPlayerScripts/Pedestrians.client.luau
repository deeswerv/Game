--!strict
-- Downtown's people, walking. DistrictService stands each one at the start of its stretch of
-- sidewalk ("Pedestrian" tag; WalkFrom / WalkTo / WalkSpeed / WalkPhase); this walks them up
-- it, pauses, turns and walks back -- timed off the server clock, so everybody sees the same
-- person in the same place. A walk cycle on their own joints (legs swinging, knees bending,
-- arms swinging against the legs, a little bob), the same conventions as the players' Motion:
-- +a about X swings a hanging limb forward; a knee bends with -a about X.
--
-- Gunfire sends them running: a shot or an impact within SCARE_RADIUS (CombatFX.Gunfire) and
-- anyone near it breaks into a run -- faster, arms pumping, leaning into it -- until it has been
-- quiet for SCARE_TIME. Each keeps its own clock from then on, so a scare never makes anyone
-- jump along the pavement.
--
-- Local only and cheap: nobody further than RANGE is touched, and the server copy never moves.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RANGE = 220           -- studs from the camera past which nobody is walked
local STRIDE = 4.4          -- studs a full gait cycle covers
local PAUSE = 1.6           -- seconds at each end, looking about, before turning back
local TURN = 0.7            -- seconds the turn takes
local SCARE_RADIUS = 45     -- studs from a shot or an impact that sends someone running
local SCARE_TIME = 8        -- seconds of quiet before they slow down again
local RUN = 2.4             -- how much faster a frightened walker goes

type Walker = {
	model: Model, root: BasePart, from: Vector3, to: Vector3, speed: number, phase: number,
	motors: { [string]: Motor6D }, clock: number, scaredUntil: number, pace: number,
}

local walkers: { [Model]: Walker } = {}

local JOINTS = { "LeftHip", "RightHip", "LeftKnee", "RightKnee", "LeftShoulder", "RightShoulder", "LeftElbow", "RightElbow",
	"Waist" }

local function motorOf(model: Model, name: string): Motor6D?
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Name == name then
			return d
		end
	end
	return nil
end

local function add(model: Instance)
	if not model:IsA("Model") or walkers[model] then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	local from, to = model:GetAttribute("WalkFrom"), model:GetAttribute("WalkTo")
	if not (root and root:IsA("BasePart") and typeof(from) == "Vector3" and typeof(to) == "Vector3") then
		return
	end
	local motors: { [string]: Motor6D } = {}
	for _, name in ipairs(JOINTS) do
		local motor = motorOf(model, name)
		if motor then
			motors[name] = motor
		end
	end
	walkers[model] = {
		model = model, root = root, from = from, to = to, motors = motors,
		speed = math.max(1, tonumber(model:GetAttribute("WalkSpeed")) or 4.8),
		phase = tonumber(model:GetAttribute("WalkPhase")) or 0,
		clock = workspace:GetServerTimeNow(), scaredUntil = 0, pace = 1,
	}
end

local function remove(model: Instance)
	walkers[model :: Model] = nil
end

--- Where a walker is at server time `t`: position, the way it faces, distance walked this
--- leg (for the gait), and whether it is walking.
local function sample(w: Walker, t: number): (Vector3, Vector3, number, boolean)
	local span = w.to - w.from
	local length = math.max(span.Magnitude, 0.01)
	local dir = span / length
	local walkTime = length / w.speed
	local period = 2 * (walkTime + PAUSE)
	local tau = (t + w.phase * period) % period
	-- Turning round is a half turn through the side, not a flip.
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local function turned(angle: number): Vector3
		return dir * math.cos(angle) + side * math.sin(angle)
	end
	if tau < PAUSE then
		-- At the start, turning from facing back the way it came to facing out.
		local k = math.clamp(tau / TURN, 0, 1)
		return w.from, turned(math.pi * (1 - k)), 0, false
	elseif tau < PAUSE + walkTime then
		local d = (tau - PAUSE) * w.speed
		return w.from + dir * d, dir, d, true
	elseif tau < 2 * PAUSE + walkTime then
		local k = math.clamp((tau - PAUSE - walkTime) / TURN, 0, 1)
		return w.to, turned(math.pi * k), 0, false
	end
	local d = (tau - 2 * PAUSE - walkTime) * w.speed
	return w.to - dir * d, -dir, d, true
end

local function pose(w: Walker, walked: number, moving: boolean)
	local m = w.motors
	local g = walked / STRIDE * math.pi * 2
	local swing = if moving then math.sin(g) else 0
	local running = w.pace > 1.5
	local amp = if moving then (if running then 0.95 else 0.55) else 0
	local function set(name: string, cf: CFrame)
		local motor = m[name]
		if motor then
			motor.Transform = cf
		end
	end
	set("LeftHip", CFrame.Angles(swing * amp, 0, 0))
	set("RightHip", CFrame.Angles(-swing * amp, 0, 0))
	-- Each knee bends as its leg swings through, straight when it plants.
	set("LeftKnee", CFrame.Angles(-math.max(0, math.sin(g - 1.2)) * 0.8 * (if moving then 1 else 0), 0, 0))
	set("RightKnee", CFrame.Angles(-math.max(0, math.sin(g - 1.2 + math.pi)) * 0.8 * (if moving then 1 else 0), 0, 0))
	set("LeftShoulder", CFrame.Angles(-swing * amp * 0.7, 0, 0))
	set("RightShoulder", CFrame.Angles(swing * amp * 0.7, 0, 0))
	-- Walking, the elbows hang easy; running, they bend and pump.
	local elbow = if running and moving then 1.3 elseif moving then 0.25 else 0.08
	set("LeftElbow", CFrame.Angles(elbow, 0, 0))
	set("RightElbow", CFrame.Angles(elbow, 0, 0))
	set("Waist", CFrame.Angles(if running then -0.18 else 0, swing * 0.08, 0))
end

--- A shot or an impact at `at`: everyone near it runs.
local function gunfire(at: Vector3)
	local now = os.clock()
	for _, w in pairs(walkers) do
		if (w.root.Position - at).Magnitude < SCARE_RADIUS then
			w.scaredUntil = now + SCARE_TIME
		end
	end
end
task.spawn(function()
	local ok, CombatFX = pcall(function()
		return require(ReplicatedStorage:WaitForChild("CombatFX")) :: any
	end)
	if ok and CombatFX and CombatFX.Gunfire then
		CombatFX.Gunfire.Event:Connect(gunfire)
	end
end)

RunService.RenderStepped:Connect(function(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local now = os.clock()
	for model, w in pairs(walkers) do
		-- Their own clock: the server's at first, faster while they run (and it eases between).
		local target = if now < w.scaredUntil then RUN else 1
		w.pace += (target - w.pace) * math.min(1, dt * 3)
		w.clock += dt * w.pace
		if not model.Parent or not w.root.Parent then
			walkers[model] = nil
		elseif (w.from - eye).Magnitude < RANGE or (w.to - eye).Magnitude < RANGE then
			local at, facing, walked, moving = sample(w, w.clock)
			local bob = if moving then math.abs(math.sin(walked / STRIDE * math.pi * 2)) * 0.12 else 0
			local flat = Vector3.new(facing.X, 0, facing.Z)
			if flat.Magnitude < 0.01 then
				flat = w.to - w.from
			end
			w.root.CFrame = CFrame.lookAt(at + Vector3.new(0, bob, 0), at + Vector3.new(0, bob, 0) + flat)
			pose(w, walked, moving)
		end
	end
end)

CollectionService:GetInstanceAddedSignal("Pedestrian"):Connect(add)
CollectionService:GetInstanceRemovedSignal("Pedestrian"):Connect(remove)
for _, model in ipairs(CollectionService:GetTagged("Pedestrian")) do
	add(model)
end
