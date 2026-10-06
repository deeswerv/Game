--!nocheck
-- A movement clip: the player's procedural gait (ReplicatedStorage.Motion) played over time on
-- the game's own rig -- the locked Roblox Boy body, every joint solved through its real
-- Motor6Ds -- moving across the ground the way a player does, for clip.mjs to render into a
-- video. A playthrough of the animation rather than single poses: what it looks like from
-- the camera behind you, with the ground going by under the feet.
--
--   lune run tools/mapview/motionclip.luau -- out.json [timeline] [camera]
--
-- Timelines: "tour" (idle, run, sprint, stop, strafe, backpedal, turn), "run", "sprint",
-- "walk", "idle", "crouch" (crouched still, walking, strafing), "jump" (running jumps, a
-- standing jump). Cameras: "chase" (the game's shoulder camera), "side", "front".

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")
local roblox = require("@lune/roblox")

local args = {}
for _, a in ipairs(process.args) do
	if a ~= "--" then
		table.insert(args, a)
	end
end
local outPath = args[1] or "out/clip.json"
local timeline = args[2] or "tour"
local cameraKind = args[3] or "chase"
local FPS = 30

local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local game = roblox.deserializePlace(fs.readFile("build/Game.rbxl"))
local env = { game = game, Instance = roblox.Instance }
for key, value in pairs(roblox) do
	if type(key) == "string" and key:match("^%u") and env[key] == nil then
		env[key] = value
	end
end
setmetatable(env, { __index = _G })
local Motion = luau.load(fs.readFile("src/ReplicatedStorage/Motion.luau"), { debugName = "Motion", environment = env })()

local source = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
local motors, parts = {}, {}
for _, d in ipairs(source:GetDescendants()) do
	if d.ClassName == "Motor6D" and d.Part0 and d.Part1 then
		motors[d.Part1.Name] = { part0 = d.Part0.Name, c0 = d.C0, c1 = d.C1 }
	elseif d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
		parts[d.Name] = d
	end
end

local function solve(root: CFrame, poses)
	local at = { HumanoidRootPart = root }
	local progress = true
	while progress do
		progress = false
		for name, m in pairs(motors) do
			if not at[name] and at[m.part0] then
				at[name] = at[m.part0] * m.c0 * (poses[name] or CFrame.new()) * m.c1:Inverse()
				progress = true
			end
		end
	end
	return at
end

-- The height the root stands at so the feet rest on the floor at y = 0.
local function lowestOf(at)
	local low = math.huge
	for name, cf in pairs(at) do
		local p = parts[name]
		if p then
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						low = math.min(low, cf:PointToWorldSpace(p.Size / 2 * Vector3.new(sx, sy, sz)).Y)
					end
				end
			end
		end
	end
	return low
end
local standY = -lowestOf(solve(CFrame.new(), {}))

-- What the player is doing, second by second: { from, to, speed, direction (root space), sprint,
-- yawRate, crouch, jump (leaves the ground at the start of the segment) }.
local TIMELINES = {
	tour = {
		{ 0, 1.2, 0, Vector3.new(0, 0, -1), false },
		{ 1.2, 5.2, 16, Vector3.new(0, 0, -1), false },
		{ 5.2, 8.4, 24, Vector3.new(0, 0, -1), true },
		{ 8.4, 9.4, 16, Vector3.new(0, 0, -1), false, 70 },
		{ 9.4, 10.4, 0, Vector3.new(0, 0, -1), false },
		{ 10.4, 12.2, 16, Vector3.new(1, 0, 0), false },
		{ 12.2, 14.0, 16, Vector3.new(0, 0, 1), false },
		{ 14.0, 15.0, 0, Vector3.new(0, 0, -1), false },
	},
	run = { { 0, 0.6, 0, Vector3.new(0, 0, -1), false }, { 0.6, 6, 16, Vector3.new(0, 0, -1), false } },
	sprint = { { 0, 0.6, 0, Vector3.new(0, 0, -1), false }, { 0.6, 6, 24, Vector3.new(0, 0, -1), true } },
	walk = { { 0, 0.6, 0, Vector3.new(0, 0, -1), false }, { 0.6, 6, 7, Vector3.new(0, 0, -1), false } },
	idle = { { 0, 4, 0, Vector3.new(0, 0, -1), false } },
	crouch = {
		{ 0, 1, 0, Vector3.new(0, 0, -1), false, 0, true },
		{ 1, 4, 8, Vector3.new(0, 0, -1), false, 0, true },
		{ 4, 5.5, 8, Vector3.new(1, 0, 0), false, 0, true },
		{ 5.5, 6.5, 0, Vector3.new(0, 0, -1), false, 0, true },
	},
	jump = {
		{ 0, 0.6, 0, Vector3.new(0, 0, -1), false },
		{ 0.6, 2, 16, Vector3.new(0, 0, -1), false },
		{ 2, 3.4, 16, Vector3.new(0, 0, -1), false, 0, false, true },
		{ 3.4, 4.8, 24, Vector3.new(0, 0, -1), true, 0, false, true },
		{ 4.8, 5.6, 0, Vector3.new(0, 0, -1), false },
		{ 5.6, 7, 0, Vector3.new(0, 0, -1), false, 0, false, true },
	},
}
local plan = TIMELINES[timeline] or TIMELINES.tour
local duration = plan[#plan][2]

local state = Motion.NewState()
local pos = Vector3.new(0, 0, 0)
local yaw = 0
local velocity = Vector3.new()
-- A jump the way a Roblox humanoid does one: up at 50 studs a second, under the game's gravity.
local GRAVITY, JUMP = 196.2, 50
local height, rise, lastSeg = 0, 0, nil
local frames = {}
local dt = 1 / FPS
for i = 0, math.floor(duration * FPS) - 1 do
	local t = i * dt
	local seg = plan[#plan]
	for _, s in ipairs(plan) do
		if t >= s[1] and t < s[2] then
			seg = s
			break
		end
	end
	local speed, dir, sprint, yawRate = seg[3], seg[4], seg[5], seg[6] or 0
	local crouching, jumping = seg[7] == true, seg[8] == true
	if seg ~= lastSeg and jumping and height <= 0 then
		rise = JUMP
	end
	lastSeg = seg
	local landed = nil
	if height > 0 or rise > 0 then
		rise -= GRAVITY * dt
		height += rise * dt
		if height <= 0 then
			-- How hard it came down, as MotionAnimator measures it.
			landed = math.clamp(-rise / 60, 0.2, 1)
			height, rise = 0, 0
		end
	end
	local grounded = height <= 0 and rise <= 0
	yaw += math.rad(yawRate) * dt
	local facing = CFrame.Angles(0, yaw, 0)
	-- A Roblox humanoid gets to its speed almost at once: about a tenth of a second.
	local want = facing:VectorToWorldSpace(dir.Unit * speed)
	velocity = velocity:Lerp(want, math.min(1, dt * 12))
	pos += velocity * dt
	local root = CFrame.new(pos + Vector3.new(0, standY + height, 0)) * facing
	local poses = Motion.Step(state, {
		dt = dt, velocity = root:VectorToObjectSpace(velocity), grounded = grounded, crouch = crouching, sprint = sprint,
		armed = false, active = true, landed = landed,
	})
	local at = solve(root, poses)
	local frame = { parts = {} }
	for name, cf in pairs(at) do
		if parts[name] then
			local x, y, z = cf.XVector, cf.YVector, cf.ZVector
			local p = cf.Position
			frame.parts[name] = { p.X, p.Y, p.Z, x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z }
		end
	end
	-- The camera.
	local eye, look
	local body = Vector3.new(pos.X, standY + 1.5, pos.Z)
	local up = height * 0.85
	if cameraKind == "side" then
		eye = Vector3.new(pos.X + 8, 2.6 + up, pos.Z)
		look = Vector3.new(pos.X, 2.4 + up, pos.Z)
	elseif cameraKind == "front" then
		eye = Vector3.new(pos.X, 2.9 + up, pos.Z) + facing:VectorToWorldSpace(Vector3.new(0.5, 0, -10))
		look = Vector3.new(pos.X, 2.6 + up, pos.Z)
	else
		-- The game's shoulder camera: behind and a little right, fixed to the body the way
		-- Roblox's camera follows its subject.
		eye = (CFrame.new(body) * facing * CFrame.new(2.4, 1.2, 12)).Position
		look = (CFrame.new(body) * facing * CFrame.new(2.4, -0.6, -8)).Position
	end
	frame.cam = { eye.X, eye.Y, eye.Z, look.X, look.Y, look.Z }
	frame.t = t
	table.insert(frames, frame)
end

local rig = {}
for name, p in pairs(parts) do
	local c = p.Color
	table.insert(rig, { n = name, z = { p.Size.X, p.Size.Y, p.Size.Z }, c = { math.floor(c.R * 255), math.floor(c.G * 255), math.floor(c.B * 255) } })
end
fs.writeFile(outPath, serde.encode("json", { fps = FPS, rig = rig, frames = frames, timeline = timeline,
	fov = if cameraKind == "chase" then 50 else 45 }))
print(("%s: %d frames, %.1fs, %d parts"):format(timeline, #frames, #frames / FPS, #rig))
