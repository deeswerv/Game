--!nocheck
-- Moving the player: the procedural gait, crouch (C) and roll (Q), checked without Studio on
-- the game's own rig.
--
--   * the poses (ReplicatedStorage.Motion), solved through the rig's real joints: running keeps
--     the feet on the floor and alternates them; a strafe steps sideways; crouching brings the
--     hips down with the feet still flat on the floor; a roll turns the body right over and
--     never sinks it into the floor or lifts it off, forward, back or sideways; changing state
--     blends rather than snaps;
--   * ShiftLock: holding C crouches (half speed, camera down, the server told), letting go
--     stands you up; Q rolls the way you are moving (forward when still), pushes you along,
--     and cannot be chained until the cooldown is over; the old dash is gone;
--   * MovementService marks the character for everyone and turns away roll spam;
--   * MotionAnimator lowers your own body when you crouch;
--   * crouched, the gun's cone is tighter.
--
--   lune run tools/uitest/movement.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local Rig = require("./rig")
local R = World.R
local Vector3 = roblox.Vector3
local CFrame = World.CFrame

require("@lune/task").delay(120, function()
	print("\27[31mtimed out\27[0m")
	require("@lune/process").exit(2)
end)

local failures = 0
local function check(ok: boolean, what: string)
	if ok then
		print("  ok    " .. what)
	else
		failures += 1
		print("\27[31m  FAIL  " .. what .. "\27[0m")
	end
end

local place = World.loadPlace("build/Game.rbxl")
local rs = World.service("ReplicatedStorage")
local sss = World.service("ServerScriptService")
local Motion = World.require(rs.Motion)
local GunHandling = World.require(rs.GunHandling)

-- Forward kinematics on a clean copy of the rig: where every part ends up for `poses`.
local source = place:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
local motorsOf = {}
for _, d in ipairs(source:GetDescendants()) do
	if d.ClassName == "Motor6D" and d.Part0 and d.Part1 then
		motorsOf[d.Part1.Name] = { part0 = d.Part0.Name, c0 = d.C0, c1 = d.C1, size = d.Part1.Size }
	end
end
local function solve(poses)
	local at = { HumanoidRootPart = roblox.CFrame.new() }
	local progress = true
	while progress do
		progress = false
		for name, m in pairs(motorsOf) do
			if not at[name] and at[m.part0] then
				at[name] = at[m.part0] * m.c0 * (poses[name] or roblox.CFrame.new()) * m.c1:Inverse()
				progress = true
			end
		end
	end
	return at
end
local function lowest(at)
	local low = math.huge
	for name, cf in pairs(at) do
		local m = motorsOf[name]
		if m then
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						low = math.min(low, cf:PointToWorldSpace(m.size / 2 * Vector3.new(sx, sy, sz)).Y)
					end
				end
			end
		end
	end
	return low
end
local floor = lowest(solve({}))
local function input(over)
	local t = { dt = 1 / 30, velocity = Vector3.new(), grounded = true, crouch = false, sprint = false, armed = false,
		active = true }
	for k, v in pairs(over or {}) do
		t[k] = v
	end
	return t
end

print("running")
local state = Motion.NewState()
local maxOff, leftAhead, rightAhead = 0, 0, 0
for i = 1, 90 do
	local poses = Motion.Step(state, input({ velocity = Vector3.new(0, 0, -16) }))
	if i > 30 then
		local at = solve(poses)
		maxOff = math.max(maxOff, math.abs(lowest(at) - floor))
		local l, r = at.LeftFoot.Position.Z, at.RightFoot.Position.Z
		if l < r - 0.3 then
			leftAhead += 1
		elseif r < l - 0.3 then
			rightAhead += 1
		end
	end
end
check(maxOff < 0.25, ("running, the feet stay on the floor (within %.2f)"):format(maxOff))
check(leftAhead > 10 and rightAhead > 10, ("and take turns in front (%d / %d frames)"):format(leftAhead, rightAhead))

-- A real stride, not a shuffle: the feet well apart, a heel kicked up behind, the body leaning
-- into it -- for a run and harder for a sprint; a walk always keeps a foot down.
local function gait(velocity, sprint, armed)
	local st = Motion.NewState()
	local spread, kick, lean, off = 0, 0, 0, 0
	for i = 1, 120 do
		local poses = Motion.Step(st, input({ velocity = velocity, sprint = sprint, armed = armed }))
		if i > 40 then
			local at = solve(poses)
			spread = math.max(spread, math.abs(at.LeftFoot.Position.Z - at.RightFoot.Position.Z))
			kick = math.max(kick, math.max(at.LeftFoot.Position.Y, at.RightFoot.Position.Y) - (floor + 0.35))
			lean = math.max(lean, at.LowerTorso.Position.Z - at.Head.Position.Z)
			off = math.max(off, math.abs(lowest(at) - floor))
		end
	end
	return spread, kick, lean, off, st
end
local wSpread, _, _, wOff = gait(Vector3.new(0, 0, -8), false, false)
local rSpread, rKick, rLean = gait(Vector3.new(0, 0, -16), false, false)
local sSpread, sKick, sLean = gait(Vector3.new(0, 0, -26), true, false)
check(wOff < 0.12, ("walking, a foot is always down (within %.2f)"):format(wOff))
check(rSpread > 1.2 and sSpread > rSpread, ("a run strides out (%.2f studs foot to foot), a sprint further (%.2f)"):format(rSpread, sSpread))
check(rKick > 0.6 and sKick > rKick, ("the heel kicks up behind (%.2f, sprinting %.2f)"):format(rKick, sKick))
check(rLean > 0.25 and sLean > rLean, ("and the body leans into it (head %.2f ahead, sprinting %.2f)"):format(rLean, sLean))
local back = Motion.NewState()
local backOff, ahead = 0, { 0, 0 }
for i = 1, 90 do
	local at = solve(Motion.Step(back, input({ velocity = Vector3.new(0, 0, 10) })))
	if i > 40 then
		backOff = math.max(backOff, math.abs(lowest(at) - floor))
		ahead[if at.LeftFoot.Position.Z < at.RightFoot.Position.Z then 1 else 2] += 1
	end
end
check(backOff < 0.2 and ahead[1] > 10 and ahead[2] > 10, ("backing up steps foot over foot (off the floor by %.2f)"):format(backOff))

-- A gun out: the hold keeps the chest square to the aim while the hips run under it; sprinting,
-- the gun comes down and across into the carry.
local _, _, _, _, armedRun = gait(Vector3.new(0, 0, -16), false, true)
local pelvis = armedRun.poses.LowerTorso
local square = (pelvis - pelvis.Position) * armedRun.chest
local squareAngle = math.deg(math.acos(math.clamp((square.LookVector:Dot(Vector3.new(0, 0, -1))), -1, 1)))
check(squareAngle < 3, ("running with a gun up, the chest stays square to the aim (%.1f degrees off)"):format(squareAngle))
local _, _, _, _, armedSprint = gait(Vector3.new(0, 0, -26), true, true)
local carry = ((armedSprint.poses.LowerTorso - armedSprint.poses.LowerTorso.Position) * armedSprint.chest).LookVector
check(carry.X < -0.25 and carry.Y < -0.1, ("sprinting, it turns into the carry (chest facing %.2f, %.2f, %.2f)")
	:format(carry.X, carry.Y, carry.Z))
local strafe = Motion.NewState()
local sideways, forwards = 0, 0
for i = 1, 60 do
	local at = solve(Motion.Step(strafe, input({ velocity = Vector3.new(14, 0, 0) })))
	if i > 30 then
		sideways = math.max(sideways, math.abs(at.LeftFoot.Position.X - at.RightFoot.Position.X))
		forwards = math.max(forwards, math.abs(at.LeftFoot.Position.Z - at.RightFoot.Position.Z))
	end
end
check(sideways > forwards + 0.4, ("strafing right steps sideways (%.2f across, %.2f front to back)"):format(sideways, forwards))

print("crouching")
local crouched = Motion.NewState()
local before = solve(Motion.Step(crouched, input({}))).LowerTorso.Position.Y
local biggestJump, prevY = 0, before
local last
for _ = 1, 40 do
	last = solve(Motion.Step(crouched, input({ crouch = true })))
	biggestJump = math.max(biggestJump, math.abs(last.LowerTorso.Position.Y - prevY))
	prevY = last.LowerTorso.Position.Y
end
local drop = before - last.LowerTorso.Position.Y
check(drop > 0.6 and drop < 1, ("the hips come down %.2f"):format(drop))
check(math.abs(lowest(last) - floor) < 0.15, "with the feet still on the floor")
check(biggestJump < 0.25, ("easing down rather than snapping (%.2f a frame at most)"):format(biggestJump))

print("rolling")
for _, spec in ipairs({ { "forward", Vector3.new(0, 0, -1) }, { "backward", Vector3.new(0, 0, 1) },
	{ "sideways", Vector3.new(1, 0, 0) } }) do
	local roll = Motion.NewState()
	local worst, inverted = 0, false
	local t = 0
	while t < Motion.ROLL_TIME do
		local at = solve(Motion.Step(roll, input({ roll = { dir = spec[2], t = t }, velocity = spec[2] * 20 })))
		worst = math.max(worst, math.abs(lowest(at) - floor))
		-- Upside down: the head below the hips.
		inverted = inverted or at.Head.Position.Y < at.LowerTorso.Position.Y
		t += 1 / 60
	end
	check(inverted and worst < 0.3, ("a %s roll turns right over on the floor (off it by %.2f at most)"):format(spec[1], worst))
end
check(Motion.RollDirection(Vector3.new()) == Vector3.new(0, 0, -1), "nothing held: a forward roll")
check(Motion.RollSpeed(0) > Motion.RollSpeed(Motion.ROLL_TIME * 0.9), "the push is strongest at the start")
local covered, step = 0, 1 / 120
for t = 0, Motion.ROLL_TIME - step, step do
	covered += Motion.RollSpeed(t) * step
end
check(covered > 15, ("a roll covers real ground (%.1f studs)"):format(covered))

print("ShiftLock: crouch and roll")
local rig = Rig.character(World, place)
local humanoid = rig:FindFirstChildOfClass("Humanoid")
humanoid.WalkSpeed = 16
local root = rig:FindFirstChild("HumanoidRootPart")
local remotes = rs:FindFirstChild("Remotes") or R.new("Folder")
remotes.Name = "Remotes"
remotes.Parent = rs
local sent = {}
local movementRemote = R.new("RemoteEvent")
movementRemote.Name = "Movement"
movementRemote.Parent = remotes
R.ClassMethods.RemoteEvent.FireServer = function(self, ...)
	if self.Name == "Movement" then
		table.insert(sent, { ... })
	end
end
local sps = World.service("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
World.run(sps:FindFirstChild("ShiftLock"))
World.run(sps:FindFirstChild("MotionAnimator"))
World.advance(0.3)
local rootMotor = Rig.motor(rig, "LowerTorso")
local standingC0 = rootMotor.C0

World.holdKey(roblox.Enum.KeyCode.C, true)
World.advance(0.6)
check(Motion.Local.crouch and humanoid.WalkSpeed == 8, ("holding C crouches, at half speed (%s)"):format(tostring(humanoid.WalkSpeed)))
check(humanoid.CameraOffset.Y < 0, "the camera comes down with you")
local told = false
for _, s in ipairs(sent) do
	told = told or (s[1] == "crouch" and s[2] == true)
end
check(told, "the server is told")
check(standingC0.Position.Y - rootMotor.C0.Position.Y > 0.5, ("your body goes down (%.2f)"):format(standingC0.Position.Y - rootMotor.C0.Position.Y))
World.holdKey(roblox.Enum.KeyCode.C, false)
World.advance(0.6)
check(not Motion.Local.crouch and humanoid.WalkSpeed == 16, "letting go stands you back up, at walking pace")

sent = {}
World.force(humanoid, "MoveDirection", Vector3.new(0, 0, 0))
World.force(root, "AssemblyMass", 14) -- the engine works this out; the stand-in rig has none
World.pressKey(roblox.Enum.KeyCode.Q, 0.05)
World.advance(0.1)
local roll = Motion.Local.roll
check(roll ~= nil and roll.dir == Vector3.new(0, 0, -1), "Q while standing still: a forward roll")
local v = root.AssemblyLinearVelocity
check(Vector3.new(v.X, 0, v.Z).Magnitude > 20, ("pushed along (%.0f studs/s)"):format(Vector3.new(v.X, 0, v.Z).Magnitude))
local push = root:FindFirstChild("RollPush")
check(push and push.ClassName == "LinearVelocity" and push.PlaneVelocity.Magnitude > 30
	and push.VelocityConstraintMode == roblox.Enum.VelocityConstraintMode.Plane,
	"held along the floor by a constraint the walk cannot pull back (up and down left to gravity)")
check(#sent == 1 and sent[1][1] == "roll", "the server is told")
World.advance(0.3)
World.pressKey(roblox.Enum.KeyCode.Q, 0.05)
World.advance(0.1)
check(#sent == 1, "a second Q mid-roll does nothing")
World.advance(Motion.ROLL_TIME + Motion.ROLL_COOLDOWN)
check(Motion.Local.roll == nil, "the roll ends on its own")
check(root:FindFirstChild("RollPush") == nil, "and the push is taken off")
World.force(humanoid, "MoveDirection", root.CFrame.RightVector)
World.pressKey(roblox.Enum.KeyCode.Q, 0.05)
World.advance(0.1)
roll = Motion.Local.roll
check(#sent == 2 and roll and roll.dir.X > 0.9, "after the cooldown, D + Q rolls to the right")
local oldDash = place:GetService("StarterPlayer"):FindFirstChild("Dash", true)
check(oldDash == nil and place:GetService("ServerScriptService"):FindFirstChild("DashFX") == nil,
	"the old dash and its trail are gone")

print("MovementService")
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("MovementService"), sss)
World.run(sss:FindFirstChild("MovementService"))
World.advance(0.1)
local serverRemote = remotes:FindFirstChild("Movement")
local player = World.player
R.fire(serverRemote, "OnServerEvent", player, "crouch", true)
check(rig:GetAttribute("Crouching") == true, "a crouch marks the character")
R.fire(serverRemote, "OnServerEvent", player, "crouch", "yes")
check(rig:GetAttribute("Crouching") == true, "nonsense is ignored")
R.fire(serverRemote, "OnServerEvent", player, "roll", Vector3.new(0, 0, -1))
local firstAt = rig:GetAttribute("RollAt")
check(typeof(firstAt) == "number" and rig:GetAttribute("RollDir") == Vector3.new(0, 0, -1), "a roll is marked with when and which way")
R.fire(serverRemote, "OnServerEvent", player, "roll", Vector3.new(1, 0, 0))
check(rig:GetAttribute("RollAt") == firstAt, "and another straight after is turned away")
R.fire(serverRemote, "OnServerEvent", player, "crouch", false)

print("aim")
local cfg = { SpreadMin = 2, SpreadMax = 8, AdsSpreadScale = 0.6 }
check(GunHandling.Spread(cfg, 0, false, 0, false, 0, true) < GunHandling.Spread(cfg, 0, false, 0, false, 0, false),
	"crouched, the cone is tighter")
check(GunHandling.Spread(cfg, 0, false, 0, true, 0, true) == GunHandling.Spread(cfg, 0, false, 0, true, 0, false),
	"but not in the air")

-- NPCs run on the same gait, on the same body, scaled to their size, with NPCAnimator's
-- flinches folded in under it rather than fighting it.
print("NPCs: the players' gait")
local npcs = R.new("Folder")
npcs.Name = "NPCs"
npcs.Parent = World.workspace
local npc = Rig.npc(World, place, npcs, 1.3)
local npcRoot = npc:FindFirstChild("HumanoidRootPart")
World.force(npcRoot, "AssemblyLinearVelocity", Vector3.new(0, 0, -13))
local hip = Rig.motor(npc, "LeftUpperLeg")
local starterHip = Rig.motor(World.service("StarterPlayer"):FindFirstChild("StarterCharacter"), "LeftUpperLeg")
local swingSeen, lo, hi = 0, math.huge, -math.huge
for _ = 1, 30 do
	World.advance(1 / 30)
	-- (A thigh swung forward by a: its up vector leans back by sin a.)
	local up = hip.C0.UpVector
	lo, hi = math.min(lo, up.Z), math.max(hi, up.Z)
end
swingSeen = math.deg(math.asin(math.clamp(hi, -1, 1)) - math.asin(math.clamp(lo, -1, 1)))
check(Motion.Posing[npc] == true, "an NPC near you is posed by the gait")
check(swingSeen > 40, ("its legs run (the thigh swings through %.0f degrees)"):format(swingSeen))
local expected = starterHip.C0.Position.Magnitude * 1.3
check(math.abs(hip.C0.Position.Magnitude - expected) < 0.05,
	("a big NPC's joints stay where its size puts them (%.2f, want %.2f)"):format(hip.C0.Position.Magnitude, expected))
-- Standing still, a flinch handed over as an offset lands on top of the pose.
World.force(npcRoot, "AssemblyLinearVelocity", Vector3.new())
World.advance(1)
local waist = Rig.motor(npc, "LowerTorso")
local before = waist.C0.Position.Y
Motion.Offsets[npc] = { LowerTorso = CFrame.new(0, -0.5, 0) }
World.advance(1 / 30)
local dip = before - waist.C0.Position.Y
check(dip > 0.4 and dip < 0.6, ("NPCAnimator's movement goes in under the gait (a %.2f dip)"):format(dip))
Motion.Offsets[npc] = nil
-- Dying, it is let go of: the death is NPCAnimator's to play.
npc:SetAttribute("DeathStyle", "Backward")
World.advance(1 / 30)
local atRest = (hip.C0.Position - starterHip.C0.Position * 1.3).Magnitude < 1e-3
	and (hip.C0.LookVector - starterHip.C0.LookVector).Magnitude < 1e-3
	and (hip.C0.UpVector - starterHip.C0.UpVector).Magnitude < 1e-3
check(not Motion.Posing[npc] and atRest, "a dying NPC is handed back, joints at rest")
npcs:Destroy()

local bad = {}
for _, e in ipairs(R.errors or {}) do
	local text = tostring(e)
	if text:match("ShiftLock") or text:match("MotionAnimator") or text:match("MovementService") or text:match("Motion")
		or text:match("TacticalCamera") then
		table.insert(bad, text)
	end
end
for _, e in ipairs(R.errors or {}) do print("    error: " .. tostring(e):sub(1, 300)) end
check(#bad == 0, "no errors" .. (#bad > 0 and (": " .. bad[1]) or ""))

print("")
if failures == 0 then
	print("\27[32mall movement checks passed\27[0m")
	require("@lune/process").exit(0)
else
	print(("\27[31m%d movement check(s) failed\27[0m"):format(failures))
	require("@lune/process").exit(1)
end
