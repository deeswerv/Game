--!strict
-- How NPCs look while they do what the server decided.
--
-- Presentation only. Nothing in here changes health, ammo, targets or positions -- if this
-- script failed entirely, every NPC would still fight correctly, it would just look stiff.
--
-- Two layers, the same split the player character uses:
--
--   LOCOMOTION -- the real R15 idle, walk, run, jump and fall animations, the exact ones in
--   StarterCharacter.Animate, blended by how fast the NPC is actually moving and played at a
--   rate that matches it, so feet do not skate. Played locally on each client: no
--   replication traffic, and an NPC nobody is near costs nothing.
--
--   PROCEDURAL -- short joint offsets on top: a head that looks around and follows its aim,
--   recoil, hit reactions, melee swings, and the death. Written for nearby NPCs only.
--
-- Arms and waist on anyone holding a gun belong to WeaponPoseHold (the one writer of those
-- joints). This script hands its waist movement to PoseLayers for WeaponPoseHold to fold
-- in, rather than writing those joints itself and silently losing to whichever ran last.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")
local TweenService = game:GetService("TweenService")

local NPCAnimation = require(ReplicatedStorage:WaitForChild("NPCAnimation"))
local PoseLayers = require(ReplicatedStorage:WaitForChild("PoseLayers"))
local ReloadAnimator = require(ReplicatedStorage:WaitForChild("ReloadAnimator"))
local CombatFX = require(ReplicatedStorage:WaitForChild("CombatFX"))
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
local WeaponAudio = require(ReplicatedStorage:WaitForChild("WeaponAudio"))
local ViewKick = require(ReplicatedStorage:WaitForChild("ViewKick"))

local remote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("NPCEffect") :: RemoteEvent
local localPlayer = Players.LocalPlayer

local ANIMATE_RANGE = 200       -- past this the locomotion tracks stop
local POSE_RANGE = 120          -- past this no joint is written at all
local FAR_UPDATE = 0.25         -- how often a distant NPC's blend is revisited

-- -------------------------------------------------------------- animations --

-- Taken from the player's own Animate script, so NPCs move exactly like players and nothing
-- here names an asset id of its own.
local starterCharacter = StarterPlayer:WaitForChild("StarterCharacter", 30)
local animateSource = starterCharacter and starterCharacter:WaitForChild("Animate", 10)

local function sourceAnimation(folder: string, name: string): Animation?
	local holder = animateSource and animateSource:FindFirstChild(folder)
	local anim = holder and holder:FindFirstChild(name)
	if anim and anim:IsA("Animation") and anim.AnimationId ~= "" then
		return anim
	end
	warn("[NPCAnimator] StarterCharacter.Animate has no " .. folder .. "." .. name)
	return nil
end

local LOCOMOTION = {
	idle = sourceAnimation("idle", "Animation1"),
	lookAround = sourceAnimation("idle", "Animation2"),
	walk = sourceAnimation("walk", "WalkAnim"),
	run = sourceAnimation("run", "RunAnim"),
	jump = sourceAnimation("jump", "JumpAnim"),
	fall = sourceAnimation("fall", "FallAnim"),
	tool = sourceAnimation("toolnone", "ToolNoneAnim"),
}

-- Studs per second each clip is authored at, so playback rate matches ground speed. The
-- same numbers the stock R15 Animate script works from.
local WALK_AUTHORED_SPEED = 8
local RUN_AUTHORED_SPEED = 16

local authoredCache: { [string]: Animation } = {}
local function authored(slot: string): Animation?
	local id = NPCAnimation.Authored[slot]
	if type(id) ~= "string" or id == "" then
		return nil
	end
	local anim = authoredCache[slot]
	if not anim then
		anim = Instance.new("Animation")
		anim.AnimationId = id
		authoredCache[slot] = anim
	end
	return anim
end

-- ------------------------------------------------------------------ records --

local records: { [Model]: any } = {}

local function findMotor(part: Instance?, name: string): Motor6D?
	if not part then
		return nil
	end
	for _, child in ipairs(part:GetChildren()) do
		if child:IsA("Motor6D") and child.Name == name then
			return child
		end
	end
	return nil
end

local function stopTracks(record, fade: number)
	for _, track in pairs(record.tracks) do
		if track.IsPlaying then
			track:Stop(fade)
		end
	end
	record.playing = false
	record.weights = {}
end

local function heldTool(model: Model): Tool?
	return model:FindFirstChildOfClass("Tool")
end

local function isMelee(model: Model): boolean
	local tool = heldTool(model)
	local cfg = tool and WeaponConfig.Get(tool.Name)
	return cfg ~= nil and cfg.Type == "Melee"
end

local function attach(model: Model)
	if records[model] then
		return
	end
	local humanoid = model:WaitForChild("Humanoid", 10)
	local root = model:WaitForChild("HumanoidRootPart", 10)
	if not humanoid or not humanoid:IsA("Humanoid") or not root or not root:IsA("BasePart") then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator", 5)
	if not model.Parent or records[model] or not animator or not animator:IsA("Animator") then
		return
	end

	local tracks = {}
	local function load(name: string, anim: Animation?, priority: Enum.AnimationPriority, looped: boolean)
		if not anim then
			return
		end
		local ok, track = pcall(function()
			return (animator :: Animator):LoadAnimation(anim)
		end)
		if ok and track then
			track.Priority = priority
			track.Looped = looped
			tracks[name] = track
		end
	end
	load("idle", LOCOMOTION.idle, Enum.AnimationPriority.Idle, true)
	load("lookAround", LOCOMOTION.lookAround, Enum.AnimationPriority.Idle, false)
	load("walk", LOCOMOTION.walk, Enum.AnimationPriority.Movement, true)
	load("run", LOCOMOTION.run, Enum.AnimationPriority.Movement, true)
	load("jump", LOCOMOTION.jump, Enum.AnimationPriority.Movement, false)
	load("fall", LOCOMOTION.fall, Enum.AnimationPriority.Movement, true)
	-- Holding a melee weapon: the arm stays up and forward while the legs walk.
	load("tool", LOCOMOTION.tool, Enum.AnimationPriority.Action, true)

	local joints = {}
	for jointName, partName in pairs(NPCAnimation.JointPart) do
		local motor = findMotor(model:FindFirstChild(partName), jointName)
		if motor then
			joints[jointName] = { motor = motor, rest = motor.C0, dirty = false }
		end
	end

	local record = {
		model = model,
		humanoid = humanoid,
		root = root,
		animator = animator,
		tracks = tracks,
		joints = joints,
		weights = {},
		playing = false,
		dead = humanoid.Health <= 0 or model:GetAttribute("DeathStyle") ~= nil,
		scale = model:GetScale(),
		seed = math.random() * 100,
		hits = {},
		recoil = nil,
		swing = nil,
		death = nil,
		look = { yaw = 0, pitch = 0, targetYaw = 0, targetPitch = 0, nextAt = 0 },
		nextFar = 0,
		nextLookAround = os.clock() + 6 + math.random() * 10,
		melee = isMelee(model),
		jumped = false,
	}
	records[model] = record

	model.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			record.melee = isMelee(model)
		end
	end)
	model.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			record.melee = isMelee(model)
		end
	end)
	humanoid.Died:Connect(function()
		record.dead = true
		stopTracks(record, 0.15)
	end)
	model.AncestryChanged:Connect(function(_, parent)
		if not parent then
			records[model] = nil
			PoseLayers.Clear(model)
		end
	end)
end

local function watchFolder(folder: Instance)
	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			task.spawn(attach, child)
		end
	end)
	for _, child in ipairs(folder:GetChildren()) do
		if child:IsA("Model") then
			task.spawn(attach, child)
		end
	end
end

task.spawn(function()
	local folder = workspace:WaitForChild("NPCs", 120)
	if folder then
		watchFolder(folder)
	end
end)

-- -------------------------------------------------------------- locomotion --

local function setWeight(record, name: string, weight: number, speed: number?)
	local track = record.tracks[name]
	if not track then
		return
	end
	local previous = record.weights[name] or 0
	if weight > 0.01 and not track.IsPlaying then
		track:Play(0.2, math.max(weight, 0.01), speed or 1)
	elseif math.abs(previous - weight) > 0.04 then
		track:AdjustWeight(math.max(weight, 0.001), 0.2)
	end
	record.weights[name] = weight
	if speed and track.IsPlaying and math.abs(track.Speed - speed) > 0.05 then
		track:AdjustSpeed(speed)
	end
end

local function updateLocomotion(record, now: number)
	local velocity = record.root.AssemblyLinearVelocity
	local scale = record.scale
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude / scale
	local vertical = velocity.Y

	local airborne = vertical < -14 or vertical > 12
	local moving = speed > 0.8

	-- Walk and run cross-fade over a band rather than switching at one speed, so an NPC
	-- accelerating from a walk into a sprint does not visibly change gait in one frame.
	local runShare = math.clamp((speed - 9) / 5, 0, 1)
	local walkWeight = (moving and not airborne) and (1 - runShare) or 0
	local runWeight = (moving and not airborne) and runShare or 0

	setWeight(record, "idle", 1)
	setWeight(record, "walk", walkWeight, math.clamp(speed / WALK_AUTHORED_SPEED, 0.4, 2))
	setWeight(record, "run", runWeight, math.clamp(speed / RUN_AUTHORED_SPEED, 0.5, 1.8))
	setWeight(record, "fall", vertical < -14 and 1 or 0)
	if vertical > 12 and not record.jumped then
		record.jumped = true
		local jump = record.tracks.jump
		if jump then
			jump:Play(0.1, 1, 1)
		end
	elseif vertical < 4 then
		record.jumped = false
	end
	setWeight(record, "tool", record.melee and 1 or 0)

	-- Now and then, while standing still and calm, the stock "look around" idle plays once.
	if not moving and now >= record.nextLookAround then
		record.nextLookAround = now + 9 + math.random() * 12
		local state = record.model:GetAttribute("State")
		local lookAround = record.tracks.lookAround
		if lookAround and (state == "Idle" or state == "Search") then
			lookAround:Play(0.4, 1, 1)
		end
	end
	record.playing = true
end

-- ------------------------------------------------------------- procedural --

local function addOffset(offsets: { [string]: CFrame }, joint: string, cf: CFrame)
	offsets[joint] = (offsets[joint] or CFrame.identity) * cf
end

local function addPose(offsets: { [string]: CFrame }, pose, weight: number, scale: number)
	if weight <= 0 then
		return
	end
	local scaled = weight == 1 and pose or NPCAnimation.Scale(pose, weight)
	for joint, key in pairs(scaled) do
		addOffset(offsets, joint, NPCAnimation.ToCFrame(key, scale))
	end
end

local function localYawTo(root: BasePart, point: Vector3): number
	local rel = root.CFrame:PointToObjectSpace(point)
	return math.deg(math.atan2(-rel.X, -rel.Z))
end

local CALM_STATES = { Idle = true, Patrol = true, Search = true, Investigate = true, Returning = true }

local function updateLook(record, now: number, dt: number, offsets)
	local model = record.model
	local look = record.look
	local aiming = model:GetAttribute("Aiming") == true
	local state = model:GetAttribute("State")
	local velocity = record.root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

	if aiming or not CALM_STATES[state] then
		-- In a fight the head follows the aim. The arms already carry the pitch; the head
		-- takes a share so the eyes line up without the neck bending like a periscope.
		local pitch = model:GetAttribute("AimPitch")
		look.targetYaw = 0
		look.targetPitch = typeof(pitch) == "number" and pitch * 0.45 or 0
	elseif now >= look.nextAt then
		look.nextAt = now + 2.5 + math.random() * 3.5
		look.targetPitch = -4 + math.random() * 10
		look.targetYaw = 0
		-- Half the time, glance at a player passing close by -- a guard watching you walk
		-- past reads as alive in a way a fixed stare never does.
		local character = localPlayer.Character
		local head = character and character:FindFirstChild("Head")
		if head and head:IsA("BasePart") and (head.Position - record.root.Position).Magnitude < 28
			and math.random() < 0.5 then
			look.targetYaw = math.clamp(localYawTo(record.root, head.Position), -55, 55)
		elseif math.random() < 0.7 then
			look.targetYaw = -40 + math.random() * 80
		end
	end
	if speed > 9 and not aiming then
		look.targetYaw = 0
	end

	local blend = math.clamp(dt * 3.5, 0, 1)
	look.yaw += (look.targetYaw - look.yaw) * blend
	look.pitch += (look.targetPitch - look.pitch) * blend
	addOffset(offsets, "Neck", CFrame.Angles(math.rad(look.pitch), math.rad(look.yaw), 0))

	-- Weight shifting from foot to foot while standing. A degree and a bit; more reads as
	-- swaying drunk.
	if speed < 0.8 and not aiming then
		local t = now + record.seed
		addOffset(offsets, "Waist", CFrame.Angles(0, 0, math.rad(math.sin(t * 0.7) * 1.2)))
		addOffset(offsets, "Root", CFrame.new(math.sin(t * 0.7) * 0.03, 0, 0))
	end
end

local function updateLayers(record, now: number, offsets)
	local scale = record.scale

	local recoil = record.recoil
	if recoil then
		local t = (now - recoil.at) / NPCAnimation.RecoilDuration
		if t >= 1 then
			record.recoil = nil
		else
			local amount = NPCAnimation.Pulse(t, 0.15) * recoil.strength
			addOffset(offsets, "Waist", CFrame.Angles(math.rad(amount), math.rad(amount * recoil.twist), 0))
			addOffset(offsets, "Neck", CFrame.Angles(math.rad(amount * 0.4), 0, 0))
		end
	end

	for i = #record.hits, 1, -1 do
		local hit = record.hits[i]
		local t = (now - hit.at) / hit.duration
		if t >= 1 then
			table.remove(record.hits, i)
		else
			addPose(offsets, hit.pose, NPCAnimation.Pulse(t, hit.kind == "Head" and 0.1 or 0.2), scale)
		end
	end

	local swing = record.swing
	if swing then
		local pose = NPCAnimation.SwingPose(now - swing.at, swing.windup, swing.recover, swing.heavy)
		if pose then
			addPose(offsets, pose, 1, scale)
		else
			record.swing = nil
		end
	end
end

local function writeJoints(record, offsets: { [string]: CFrame })
	local model = record.model
	-- A gun holder's arms and waist are WeaponPoseHold's. Hand the waist over; leave the arms.
	local posed = model:GetAttribute("PoseRightC0") ~= nil
	if posed then
		PoseLayers.Set(model, nil, nil, offsets.Waist)
	else
		PoseLayers.Clear(model)
	end
	for name, joint in pairs(record.joints) do
		local skip = posed and (name == "Waist" or name == "LeftShoulder" or name == "RightShoulder")
		if not skip then
			local offset = offsets[name]
			if offset then
				joint.motor.C0 = joint.rest * offset
				joint.dirty = true
			elseif joint.dirty then
				joint.motor.C0 = joint.rest
				joint.dirty = false
			end
		end
	end
end

local function updateDeath(record, now: number)
	local death = record.death
	local clip = death and NPCAnimation.Deaths[death.style]
	if not death or not clip then
		return
	end
	local t = math.clamp((now - death.at) / clip.duration, 0, 1)
	local pose = NPCAnimation.Sample(clip.keys, t)
	if death.mirror then
		pose = NPCAnimation.Mirror(pose)
	end
	local offsets = {}
	addPose(offsets, pose, 1, record.scale)
	writeJoints(record, offsets)
end

-- ---------------------------------------------------------------- the frame --

RunService:BindToRenderStep("NPCAnimator", Enum.RenderPriority.Character.Value + 1, function(dt: number)
	local now = os.clock()
	local camera = workspace.CurrentCamera
	local eye = camera and camera.CFrame.Position or Vector3.zero

	for model, record in pairs(records) do
		if not model.Parent or not record.root.Parent then
			records[model] = nil
			PoseLayers.Clear(model)
			continue
		end
		local distance = (record.root.Position - eye).Magnitude

		if record.dead then
			if record.playing then
				stopTracks(record, 0.15)
			end
			if record.death and distance < ANIMATE_RANGE then
				updateDeath(record, now)
			end
			continue
		end

		if distance > ANIMATE_RANGE then
			if record.playing then
				stopTracks(record, 0.3)
			end
			continue
		end

		if distance > POSE_RANGE then
			-- Far: locomotion only, and not every frame.
			if now >= record.nextFar then
				record.nextFar = now + FAR_UPDATE
				updateLocomotion(record, now)
			end
			continue
		end

		updateLocomotion(record, now)
		local offsets: { [string]: CFrame } = {}
		updateLook(record, now, dt, offsets)
		updateLayers(record, now, offsets)
		writeJoints(record, offsets)
	end
end)

-- ------------------------------------------------------------------ events --

local function playAuthored(record, slot: string): boolean
	local anim = authored(slot)
	if not anim then
		return false
	end
	local ok, track = pcall(function()
		return record.animator:LoadAnimation(anim)
	end)
	if ok and track then
		track.Priority = Enum.AnimationPriority.Action
		track:Play(0.08)
		return true
	end
	return false
end

local function recordOf(model: any)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return nil
	end
	return records[model]
end

local handlers = {}

handlers.Shot = function(model, origin, endPoint)
	if typeof(origin) ~= "Vector3" or typeof(endPoint) ~= "Vector3" then
		return
	end
	local tool = (typeof(model) == "Instance" and model:IsA("Model")) and heldTool(model) or nil
	local wcfg = tool and WeaponConfig.Get(tool.Name)
	if tool and wcfg then
		CombatFX.MuzzleFlash(tool, wcfg.MuzzleFlashColor)
		CombatFX.EjectShell(tool)
		local handle = tool:FindFirstChild("Handle")
		local sound = handle and handle:FindFirstChild("Fire")
		if sound and sound:IsA("Sound") then
			WeaponAudio.Vary(sound)
			sound:Play()
		end
		local record = recordOf(model)
		if record then
			record.recoil = {
				at = os.clock(),
				strength = NPCAnimation.RecoilByClass[wcfg.Class] or 2,
				twist = (math.random() - 0.5) * 0.6,
			}
		end
	end
	-- NPCs get the authored effects too, so a bandit carrying a Mastery Weapon fires the
	-- same round a player does.
	local weaponName = tool and tool.Name
	-- From the barrel as this client draws the fighter, not the server's origin: the server
	-- does not pose an NPC's arms, so its muzzle is not where anyone sees the gun.
	local from = CombatFX.MuzzlePoint(tool, origin) or origin
	local flight = CombatFX.Tracer(from, endPoint,
		wcfg and wcfg.TracerColor or Color3.fromRGB(255, 220, 150),
		wcfg and wcfg.TracerWidth or 0.08,
		weaponName)
	task.delay(flight, CombatFX.Impact, endPoint, origin, weaponName)
end

handlers.Reload = function(model, tool, needsCharge, duration)
	if typeof(model) ~= "Instance" or not model:IsA("Model") or typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
		return
	end
	local wcfg = WeaponConfig.For(tool)
	if not wcfg then
		return
	end
	local handle = tool:FindFirstChild("Handle")
	local sound = handle and handle:FindFirstChild("Reload")
	if sound and sound:IsA("Sound") and sound.SoundId ~= "" then
		sound:Play()
	end
	-- The same staged reload players get: magazine out and thrown clear, a fresh one in,
	-- the action racked when it ran dry. Hand targets flow to WeaponPoseHold.
	ReloadAnimator.Play(model, tool, wcfg, needsCharge == true,
		type(duration) == "number" and duration or wcfg.ReloadTime)
end

handlers.ReloadCancel = function(model)
	if typeof(model) == "Instance" and model:IsA("Model") then
		ReloadAnimator.Cancel(model)
	end
end

handlers.Equip = function(_model, tool)
	if typeof(tool) == "Instance" and tool:IsA("Tool") then
		WeaponAudio.Play(tool, "Equip")
	end
end

handlers.Swing = function(model, windup, recover, heavy)
	local record = recordOf(model)
	if not record or type(windup) ~= "number" or type(recover) ~= "number" then
		return
	end
	if playAuthored(record, heavy and "MeleeHeavy" or "MeleeLight") then
		return
	end
	record.swing = { at = os.clock(), windup = windup, recover = recover, heavy = heavy == true }
	-- The whoosh lands with the strike, not the windup.
	local tool = heldTool(model)
	local handle = tool and tool:FindFirstChild("Handle")
	local sound = handle and handle:FindFirstChild("Fire")
	if sound and sound:IsA("Sound") then
		task.delay(windup * 0.8, function()
			if sound.Parent then
				sound:Play()
			end
		end)
	end
end

handlers.Hit = function(model, kind, side)
	local record = recordOf(model)
	if not record or record.dead or type(kind) ~= "string" then
		return
	end
	local slot = kind == "Head" and "HitHead" or ((kind == "Heavy" or kind == "Stagger") and "HitHeavy" or "HitLight")
	if playAuthored(record, slot) then
		return
	end
	local pose, duration = NPCAnimation.HitPose(kind, type(side) == "string" and side or "Front")
	-- Keep at most three reactions stacked; past that the newest replaces the oldest.
	if #record.hits >= 3 then
		table.remove(record.hits, 1)
	end
	table.insert(record.hits, { at = os.clock(), duration = duration, pose = pose, kind = kind })
end

handlers.Death = function(model, style, mirror)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return
	end
	ReloadAnimator.Cancel(model)
	local record = records[model]
	if not record then
		return
	end
	record.dead = true
	record.hits = {}
	record.swing = nil
	record.recoil = nil
	stopTracks(record, 0.15)
	if type(style) == "string" and not playAuthored(record, "Death" .. style) then
		record.death = { style = style, mirror = mirror == true, at = os.clock() }
	end
end

-- ------------------------------------------------------------------ tactics --
--
-- What AI.Tactics decides, drawn: speech bubbles, the "?" and "!" marks, a grenade's flight
-- and fuse, the blast, and the bandage bar. All local, all short-lived.

local playerGui = localPlayer:WaitForChild("PlayerGui")
local tacticsGui = Instance.new("ScreenGui")
tacticsGui.Name = "NPCTactics"
tacticsGui.ResetOnSpawn = false
tacticsGui.IgnoreGuiInset = true
tacticsGui.DisplayOrder = 6
tacticsGui.Parent = playerGui

local INK = Color3.fromRGB(24, 22, 28)
local DANGER = Color3.fromRGB(232, 56, 52)
local CALLOUT_RANGE = 90

local function myRoot(): BasePart?
	local character = localPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return (root and root:IsA("BasePart")) and root or nil
end

local function headOf(model: any): BasePart?
	if typeof(model) ~= "Instance" or not model:IsA("Model") then
		return nil
	end
	local head = model:FindFirstChild("Head")
	return (head and head:IsA("BasePart")) and head or nil
end

local function inRange(position: Vector3, range: number): boolean
	local root = myRoot()
	return not root or (root.Position - position).Magnitude <= range
end

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function stroke(parent: Instance, colour: Color3, thickness: number)
	local st = Instance.new("UIStroke")
	st.Color = colour
	st.Thickness = thickness
	st.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	st.Parent = parent
end

-- A billboard over a head, `lift` studs up, that pops in, holds and fades out.
local function billboard(head: BasePart, size: UDim2, lift: number, life: number): (BillboardGui, UIScale)
	local gui = Instance.new("BillboardGui")
	gui.Adornee = head
	gui.Size = size
	gui.StudsOffsetWorldSpace = Vector3.new(0, lift, 0)
	gui.MaxDistance = CALLOUT_RANGE
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	-- Straight under PlayerGui: a BillboardGui nested inside a ScreenGui does not draw.
	gui.Parent = playerGui
	local frame = Instance.new("Frame")
	frame.Name = "Body"
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = gui
	local scale = Instance.new("UIScale")
	scale.Scale = 0.3
	scale.Parent = frame
	TweenService:Create(scale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(life, function()
		if gui.Parent then
			TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = 0 }):Play()
			task.delay(0.22, function()
				gui:Destroy()
			end)
		end
	end)
	return gui, scale
end

-- Weak keys: an NPC that dies and is cleaned away takes its entries with it.
local bubbles: { [Model]: BillboardGui } = setmetatable({}, { __mode = "k" }) :: any
local marks: { [Model]: BillboardGui } = setmetatable({}, { __mode = "k" }) :: any

-- A speech bubble: white, dark lettering, a little tail; red for the urgent ones.
handlers.Callout = function(model, text, urgent)
	local head = headOf(model)
	if not head or type(text) ~= "string" or not inRange(head.Position, CALLOUT_RANGE) then
		return
	end
	local old = bubbles[model]
	if old then
		old:Destroy()
	end
	local width = math.clamp(#text * 9 + 30, 80, 280)
	local gui = billboard(head, UDim2.fromOffset(width, 42), 3.2, 2.2)
	bubbles[model] = gui
	local body = gui:FindFirstChild("Body") :: Frame
	local bubble = Instance.new("Frame")
	bubble.BackgroundColor3 = urgent and DANGER or Color3.fromRGB(252, 250, 244)
	bubble.Size = UDim2.new(1, 0, 0, 32)
	bubble.Parent = body
	corner(bubble, 12)
	stroke(bubble, INK, 2.5)
	local tail = Instance.new("Frame")
	tail.AnchorPoint = Vector2.new(0.5, 0.5)
	tail.Position = UDim2.new(0.5, 0, 0, 32)
	tail.Size = UDim2.fromOffset(12, 12)
	tail.Rotation = 45
	tail.BackgroundColor3 = bubble.BackgroundColor3
	tail.ZIndex = 0
	tail.Parent = body
	stroke(tail, INK, 2.5)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 17
	label.Text = text
	label.TextColor3 = urgent and Color3.new(1, 1, 1) or INK
	label.ZIndex = 2
	label.Parent = bubble
end

-- "?" heard something, "!" seen you.
handlers.Mark = function(model, glyph)
	local head = headOf(model)
	if not head or type(glyph) ~= "string" or not inRange(head.Position, CALLOUT_RANGE) then
		return
	end
	local old = marks[model]
	if old then
		old:Destroy()
	end
	local alarm = glyph == "!"
	local gui = billboard(head, UDim2.fromOffset(40, 40), 5.6, alarm and 1.4 or 2)
	marks[model] = gui
	local body = gui:FindFirstChild("Body") :: Frame
	local disc = Instance.new("Frame")
	disc.BackgroundColor3 = alarm and DANGER or Color3.fromRGB(250, 196, 50)
	disc.Size = UDim2.fromScale(1, 1)
	disc.Parent = body
	corner(disc, 20)
	stroke(disc, INK, 3)
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 28
	label.Text = glyph
	label.TextColor3 = alarm and Color3.new(1, 1, 1) or INK
	label.Parent = disc
end

-- The arm coming over for a throw: the melee swing pose, without a weapon's whoosh.
handlers.Throw = function(model, windup, recover)
	local record = recordOf(model)
	if record and type(windup) == "number" and type(recover) == "number" then
		record.swing = { at = os.clock(), windup = windup, recover = recover, heavy = false }
	end
end

local function sound(id: string, at: Vector3, volume: number, speed: number, range: number)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(at)
	holder.Parent = workspace
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed
	s.RollOffMaxDistance = range
	s.Parent = holder
	s:Play()
	task.delay(4, function()
		holder:Destroy()
	end)
end

-- The "GRENADE" warning while one is lying near you.
local alert = Instance.new("TextLabel")
alert.Name = "GrenadeAlert"
alert.AnchorPoint = Vector2.new(0.5, 0)
alert.Position = UDim2.new(0.5, 0, 0, 150)
alert.Size = UDim2.fromOffset(300, 46)
alert.BackgroundColor3 = DANGER
alert.Font = Enum.Font.GothamBlack
alert.TextSize = 26
alert.TextColor3 = Color3.new(1, 1, 1)
alert.Text = "⚠  GRENADE  —  MOVE!"
alert.Visible = false
alert.Parent = tacticsGui
corner(alert, 12)
stroke(alert, INK, 3)
local nearGrenades = 0

-- A grenade: out of the hand on an arc, a bounce and a roll, then a fuse that blinks faster
-- and faster. Where it lands gets a marker you can see through walls if you are close.
handlers.Grenade = function(_model, from, to, apex, flight, fuse)
	if typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" or type(apex) ~= "number"
		or type(flight) ~= "number" or type(fuse) ~= "number" then
		return
	end
	local shell = Instance.new("Part")
	shell.Name = "Grenade"
	shell.Shape = Enum.PartType.Ball
	shell.Size = Vector3.new(0.9, 0.9, 0.9)
	shell.Color = Color3.fromRGB(78, 94, 60)
	shell.Material = Enum.Material.SmoothPlastic
	shell.Anchored = true
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.CFrame = CFrame.new(from)
	shell.Parent = workspace
	local cap = Instance.new("Part")
	cap.Size = Vector3.new(0.4, 0.3, 0.4)
	cap.Color = Color3.fromRGB(46, 50, 44)
	cap.Material = Enum.Material.SmoothPlastic
	cap.Anchored = true
	cap.CanCollide = false
	cap.CanQuery = false
	cap.CanTouch = false
	cap.Parent = shell
	local marker = Instance.new("BillboardGui")
	marker.Adornee = shell
	marker.Size = UDim2.fromOffset(34, 34)
	marker.StudsOffsetWorldSpace = Vector3.new(0, 2.2, 0)
	marker.AlwaysOnTop = true
	marker.MaxDistance = 45
	marker.Enabled = false
	marker.ResetOnSpawn = false
	marker.Parent = playerGui
	local icon = Instance.new("TextLabel")
	icon.Size = UDim2.fromScale(1, 1)
	icon.BackgroundColor3 = DANGER
	icon.Font = Enum.Font.GothamBlack
	icon.TextSize = 22
	icon.TextColor3 = Color3.new(1, 1, 1)
	icon.Text = "!"
	icon.Parent = marker
	corner(icon, 17)
	stroke(icon, INK, 3)

	local start = os.clock()
	local flat = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
	local roll = flat.Magnitude > 0.1 and flat.Unit * 1.4 or Vector3.zero
	local spin = 0
	local lastBeep = 0
	local close = false
	local connection
	connection = RunService.RenderStepped:Connect(function(dt)
		local t = os.clock() - start
		local position: Vector3
		if t < flight then
			local u = t / flight
			position = from:Lerp(to, u) + Vector3.new(0, 4 * apex * u * (1 - u), 0)
			spin += dt * 14
		else
			local landed = t - flight
			local r = math.clamp(landed / 0.35, 0, 1)
			position = to + roll * (1 - (1 - r) ^ 2) + Vector3.new(0, math.sin(math.min(landed / 0.25, 1) * math.pi) * 0.5, 0)
			spin += dt * 10 * (1 - r)
			marker.Enabled = true
			-- Blinks and beeps faster as the fuse burns down.
			local left = fuse - landed
			local rate = left > 0.6 and 0.4 or 0.12
			if os.clock() - lastBeep > rate then
				lastBeep = os.clock()
				cap.Color = cap.Color == DANGER and Color3.fromRGB(46, 50, 44) or DANGER
				sound("rbxasset://sounds/electronicpingshort.wav", position, 0.5, 1.6, 60)
			end
			local root = myRoot()
			local near = root ~= nil and (root.Position - position).Magnitude < 17
			if near ~= close then
				close = near
				nearGrenades += near and 1 or -1
				alert.Visible = nearGrenades > 0
			end
			if landed >= fuse then
				connection:Disconnect()
				if close then
					nearGrenades -= 1
					alert.Visible = nearGrenades > 0
				end
				shell:Destroy()
				marker:Destroy()
				return
			end
		end
		shell.CFrame = CFrame.new(position) * CFrame.Angles(spin, spin * 0.6, 0)
		cap.CFrame = shell.CFrame * CFrame.new(0, 0.5, 0)
	end)
end

-- The blast is drawn by ExplosionFX, which the players' own grenades use too, so a frag
-- looks the same whoever threw it.
local ExplosionFX = require(ReplicatedStorage:WaitForChild("ExplosionFX"))
handlers.Explode = function(centre, radius)
	if typeof(centre) ~= "Vector3" or type(radius) ~= "number" then
		return
	end
	ExplosionFX.Play(centre, radius)
end

-- Bandaging: a green bar over its head that fills; cancelled if it is hit.
local heals: { [Model]: BillboardGui } = setmetatable({}, { __mode = "k" }) :: any

handlers.Heal = function(model, duration)
	local head = headOf(model)
	if not head or type(duration) ~= "number" or not inRange(head.Position, CALLOUT_RANGE) then
		return
	end
	local old = heals[model]
	if old then
		old:Destroy()
	end
	local gui = billboard(head, UDim2.fromOffset(120, 22), 4.4, duration + 0.2)
	heals[model] = gui
	local body = gui:FindFirstChild("Body") :: Frame
	local back = Instance.new("Frame")
	back.BackgroundColor3 = INK
	back.Size = UDim2.fromScale(1, 1)
	back.Parent = body
	corner(back, 8)
	stroke(back, Color3.new(1, 1, 1), 1.5)
	local fill = Instance.new("Frame")
	fill.BackgroundColor3 = Color3.fromRGB(80, 210, 110)
	fill.Size = UDim2.fromScale(0, 1)
	fill.Parent = back
	corner(fill, 8)
	TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) }):Play()
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.GothamBlack
	label.TextSize = 13
	label.Text = "✚ PATCHING UP"
	label.TextColor3 = Color3.new(1, 1, 1)
	label.ZIndex = 2
	label.Parent = back
end

handlers.HealCancel = function(model)
	if typeof(model) == "Instance" and model:IsA("Model") and heals[model] then
		heals[model]:Destroy()
		heals[model] = nil
	end
end

handlers.Healed = function(model, amount)
	handlers.HealCancel(model)
	local head = headOf(model)
	if head and type(amount) == "number" and inRange(head.Position, CALLOUT_RANGE) then
		local gui = billboard(head, UDim2.fromOffset(90, 30), 4.4, 1)
		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.GothamBlack
		label.TextSize = 24
		label.Text = "+" .. tostring(amount)
		label.TextColor3 = Color3.fromRGB(90, 230, 120)
		label.TextStrokeTransparency = 0.2
		label.Parent = gui:FindFirstChild("Body")
	end
end

remote.OnClientEvent:Connect(function(batch)
	if type(batch) ~= "table" then
		return
	end
	for _, event in ipairs(batch) do
		if type(event) == "table" then
			local handler = handlers[event[1]]
			if handler then
				local ok, err = pcall(handler, table.unpack(event, 2))
				if not ok then
					warn("[NPCAnimator] " .. tostring(event[1]) .. ": " .. tostring(err))
				end
			end
		end
	end
end)
