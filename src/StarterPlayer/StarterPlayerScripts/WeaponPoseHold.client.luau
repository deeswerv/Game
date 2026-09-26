--!strict
-- Holds the weapon pose steady against the default Animate script.
--
-- The joint that actually gets drawn is C0 * Transform. ServerScriptService.WeaponPose
-- sets C0 for the hold, but the animator owns Transform, and while standing still that
-- is nearly harmless because the idle animation barely moves the shoulders. Falling and
-- swimming are a different story: those animations throw both arms up overhead, that
-- stacked on top of the pose, and the gun ended up behind the player's head pointing at
-- the sky. Which is exactly what it looked like in game.
--
-- The obvious fix -- zero Transform every frame -- does not work. The animator writes
-- these joints AFTER PreRender, so anything written during PreRender is thrown away
-- before the frame is drawn. Measured directly: read back inside PreRender the roll was
-- 0 degrees, and read back immediately after PreRender it was 155.
--
-- So instead of fighting for Transform, divide it back out of C0, which nothing else
-- touches:  C0 = pose * Transform:Inverse()  =>  C0 * Transform = pose.
--
-- Transform is one frame stale when read here, for the same ordering reason, so a fast
-- arm animation leaves a frame of lag. That is invisible next to the arms being flung
-- over the head, and the poses this runs for are static ones.
--
-- Guns only, and the server decides which those are: it publishes the intended pose as
-- character attributes, and their absence means "leave this character's arms alone".

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterPlayer = game:GetService("StarterPlayer")

local ReloadAnimator = require(ReplicatedStorage:WaitForChild("ReloadAnimator"))
local InspectController = require(ReplicatedStorage:WaitForChild("InspectController"))
-- Movement other scripts want on top of the hold -- an NPC's recoil, a flinch, a death. It
-- arrives here as an offset rather than as a second writer on these joints.
local PoseLayers = require(ReplicatedStorage:WaitForChild("PoseLayers"))

-- How an arm on this rig reaches a point lives in ReplicatedStorage.ArmSolver -- the same
-- module the weapon pose and the reload use, so all three agree on where a hand ends up.
-- When they disagreed, the reload put the rifle inside the character's head.
local ArmSolver = require(ReplicatedStorage:WaitForChild("ArmSolver"))

local rigOf = ArmSolver.Rig
local authored = ArmSolver.Authored

-- Keep an arm slightly short of locking out, matching the weapon pose's own slack.
local SUPPORT_SLACK = 0.92

-- R15 splits the arm across three joints. The pose maths assumes the elbow and wrist sit
-- at rest -- that is what makes "where the hand is" a function of the shoulder alone -- so
-- they are held there against the animation the same way the shoulder is.
local function armJoints(character: Model, side: string)
	local upperArm = character:FindFirstChild(side .. "UpperArm")
	local lowerArm = character:FindFirstChild(side .. "LowerArm")
	local hand = character:FindFirstChild(side .. "Hand")
	if not (upperArm and lowerArm and hand) then
		return nil, nil, nil
	end
	return upperArm:FindFirstChild(side .. "Shoulder"),
		lowerArm:FindFirstChild(side .. "Elbow"),
		hand:FindFirstChild(side .. "Wrist")
end

-- How fast the weapon catches up with the camera. Instant tracking looks mechanical.
local AIM_LERP = 12

-- How fast the arms travel between the carry and the ready. Snapping between two poses
-- reads as a glitch; this is quick enough to feel responsive on the aim button.
local STANCE_LERP = 14

local smoothedPitch: { [Model]: number } = {}
local smoothedRight: { [Model]: CFrame } = {}
local smoothedLeft: { [Model]: CFrame } = {}
local smoothedRightElbow: { [Model]: CFrame } = {}
local smoothedLeftElbow: { [Model]: CFrame } = {}
local smoothedWaist: { [Model]: CFrame } = {}

-- ------------------------------------------------------------------ sway --
--
-- The weapon lags the camera when you turn and settles once you stop. It is the cheapest
-- thing on this whole HUD that makes the gun feel like an object with weight rather than a
-- decal welded to the screen.
--
-- Deliberately small. Sway that reads as "alive" in a screenshot reads as "broken" after a
-- minute of play, and it fights the player's aim if it goes much past this.
local SWAY_GAIN = 2.2          -- how far it lags, per radian/second of turn
local SWAY_MAX = math.rad(7)   -- and never further than this
local SWAY_RECOVER = 9         -- how briskly it settles back

local localPlayer = Players.LocalPlayer
local swayYaw, swayPitch = 0, 0
local lastLook: Vector3? = nil

local function yawOf(v: Vector3): number
	return math.atan2(v.X, -v.Z)
end

local function pitchOf(v: Vector3): number
	return math.asin(math.clamp(v.Y, -1, 1))
end

-- Driven off the camera rather than the character, because the camera is what the player
-- is actually moving; the character's facing follows it a frame later and would sway late.
local function updateSway(dt: number)
	local look = workspace.CurrentCamera.CFrame.LookVector
	if lastLook and dt > 0 then
		local deltaYaw = yawOf(look) - yawOf(lastLook)
		-- Wrap, so spinning through south does not fling the weapon.
		deltaYaw = (deltaYaw + math.pi) % (2 * math.pi) - math.pi
		local deltaPitch = pitchOf(look) - pitchOf(lastLook)
		swayYaw = math.clamp(swayYaw - deltaYaw * SWAY_GAIN, -SWAY_MAX, SWAY_MAX)
		swayPitch = math.clamp(swayPitch - deltaPitch * SWAY_GAIN, -SWAY_MAX, SWAY_MAX)
	end
	lastLook = look

	local recover = math.clamp(SWAY_RECOVER * dt, 0, 1)
	swayYaw -= swayYaw * recover
	swayPitch -= swayPitch * recover
end

-- The waist rest, for the bladed stance the server publishes. Read from the locked
-- StarterCharacter for the same reason the arms are: a live character may already be
-- turned, and capturing a turned waist as "rest" would bake the turn in permanently.
local waistRest: CFrame? = nil

-- Find a joint by name AND class. FindFirstChild is not enough: this Roblox build rigs R15
-- characters with AnimationConstraints carrying the SAME names as the Motor6Ds, so there
-- are two things called "Waist" on the UpperTorso and the plain lookup returns whichever it
-- meets first.
local function findMotor(parent: Instance?, name: string): Motor6D?
	if not parent then
		return nil
	end
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("Motor6D") and child.Name == name then
			return child
		end
	end
	return nil
end

local function waistRestC0(): CFrame?
	if not waistRest then
		local source = StarterPlayer:FindFirstChild("StarterCharacter")
		local waist = findMotor(source and source:FindFirstChild("UpperTorso"), "Waist")
		if waist then
			waistRest = waist.C0
		end
	end
	return waistRest
end

local function holdOne(character: Model, dt: number)
	local rightPose = character:GetAttribute("PoseRightC0")
	if typeof(rightPose) ~= "CFrame" then
		smoothedPitch[character] = nil
		smoothedRight[character] = nil
		smoothedLeft[character] = nil
		smoothedRightElbow[character] = nil
		smoothedLeftElbow[character] = nil
		smoothedWaist[character] = nil
		return
	end
	local r = rigOf()
	if not r then
		return
	end
	local rightShoulder, rightElbow, rightWrist = armJoints(character, "Right")
	if not rightShoulder then
		return
	end

	-- The reload adds its arm movement on top of the hold pose rather than replacing it,
	-- so the two systems never argue over these joints. Identity when nothing is
	-- reloading, which is the overwhelmingly common case.
	local reloadRight, reloadLeft, reloadRightWeight, reloadLeftWeight =
		ReloadAnimator.Targets(character)
	local rightOffset, leftOffset = CFrame.identity, CFrame.identity

	-- Sway rides on the gun arm only. The off hand is re-solved onto the weapon every frame
	-- further down, so it follows the sway for free rather than needing its own copy.
	--
	-- Local player only: sway comes from the camera, and we do not have anyone else's.
	if character == localPlayer.Character then
		rightOffset = rightOffset
			* CFrame.Angles(0, swayYaw, 0)
			* CFrame.Angles(0, 0, swayPitch)
	end

	-- Inspection layers on top of the reload rather than replacing it, so the two can
	-- overlap without either snapping. Identity unless the weapon is actually up.
	InspectController.Step(character)
	local inspectRight, inspectLeft = InspectController.Offsets(character)
	rightOffset = rightOffset * inspectRight
	leftOffset = leftOffset * inspectLeft

	local layerRight, layerLeft, layerWaist = PoseLayers.Get(character)
	rightOffset = rightOffset * layerRight
	leftOffset = leftOffset * layerLeft

	-- Aim. The server publishes each player's camera pitch, so everyone sees everyone
	-- else's weapon track where they are actually looking, not just their own.
	--
	-- This goes UNDER the pose rather than on top of it: the pose is expressed in the
	-- joint's own frame, so composing after it would tilt the weapon about an axis that
	-- has already been rotated. Inserted here it is a clean pitch in torso space.
	local target = character:GetAttribute("AimPitch")
	target = typeof(target) == "number" and target or 0
	local current = smoothedPitch[character] or target
	current += (target - current) * math.clamp(AIM_LERP * dt, 0, 1)
	smoothedPitch[character] = current

	local pitch = math.rad(current)

	-- The aim pitch has to tilt the weapon about the axis the CAMERA calls "right", and the
	-- bladed stance has turned the torso away from that axis. Applied about the torso's own X
	-- instead, part of the rotation bleeds into yaw: measured, the bore covered only 49 of a
	-- 60 degree camera sweep and sat up to 11 degrees nose-high at the extremes.
	--
	-- The waist pose IS the torso's rotation relative to the root, so undoing it either side
	-- of the pitch puts the rotation back on the camera's axis. No angle has to be recovered
	-- or sign-guessed -- the CFrame the server already published is exactly the correction.
	local waistHome = waistRestC0()
	local publishedWaist = character:GetAttribute("PoseWaist")
	local waistDelta = CFrame.identity
	if waistHome and typeof(publishedWaist) == "CFrame" then
		waistDelta = waistHome:Inverse() * publishedWaist
	end
	local aimTorso = waistDelta:Inverse() * CFrame.Angles(pitch, 0, 0) * waistDelta

	-- Both arms take the SAME rotation. R6 wrote these mirrored because its two shoulder
	-- frames were mirrored; expressed in torso space they were always the same world tilt.
	local rightAim = r.right.jointAxes:Inverse() * aimTorso * r.right.jointAxes
	local leftAim = r.left.jointAxes:Inverse() * aimTorso * r.left.jointAxes

	local blend = math.clamp(STANCE_LERP * dt, 0, 1)

	-- Ease the weapon's own seating in the hand towards the published target. The server
	-- deliberately does not write this onto the Tool, because that replicates at once and
	-- the gun would jump between the carry and the aim instead of swinging across.
	local heldTool: Tool? = nil
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			heldTool = child
			break
		end
	end

	local gripTarget = character:GetAttribute("PoseGrip")
	if heldTool and typeof(gripTarget) == "CFrame" then
		if not heldTool.Grip:FuzzyEq(gripTarget, 1e-3) then
			heldTool.Grip = heldTool.Grip:Lerp(gripTarget, blend)
		end

		-- Writing Tool.Grip is not enough, and this is why every stance change looked like it
		-- was being ignored.
		--
		-- Roblox builds the RightGrip weld once, at the moment the tool is equipped, copying
		-- Tool.Grip into the weld's C1 as it does so. Later writes to Tool.Grip do NOT reach a
		-- weld that already exists. So the eased aim grip was arriving at Tool.Grip, matching
		-- the published target to three decimals, and moving absolutely nothing.
		--
		-- Measured: Tool.Grip holding the aim value (43.0, 38.4, -29.0) while weld.C1 still had
		-- the carry grip (15.8, 8.9, -22.0) -- and the bore sitting 55 degrees of yaw and 21 of
		-- pitch away from what the aim pose had asked for. The arm was in exactly the right
		-- place the whole time; only the weapon in its hand was stale.
		local hand = character:FindFirstChild("RightHand")
		local weld = hand and hand:FindFirstChild("RightGrip")
		if weld and weld:IsA("Weld") and not weld.C1:FuzzyEq(heldTool.Grip, 1e-4) then
			weld.C1 = heldTool.Grip
		end
	end

	-- Hold the lower joints against the animation, so the arm below the shoulder is the
	-- shape the pose was solved for. Without this the R15 walk and tool animations bend the
	-- elbow under the hold and the weapon swings with it.
	local function steady(joint, restC0: CFrame)
		if joint and joint:IsA("Motor6D") then
			joint.C0 = restC0 * joint.Transform:Inverse()
		end
	end

	-- The elbow is a published pose in its own right, not just something to neutralise:
	-- the support arm's bend is what puts the off hand ON the handguard, and the gun arm
	-- carries a fixed fold so it does not read as the stiff plank an R6 arm had to be.
	-- Eased like the shoulder, so changing stance is a movement rather than a cut.
	local function bendJoint(cache, joint, target: CFrame)
		if not (joint and joint:IsA("Motor6D")) then
			return
		end
		local eased = (cache[character] or target):Lerp(target, blend)
		cache[character] = eased
		joint.C0 = eased * joint.Transform:Inverse()
	end

	local function published(name: string, fallback: CFrame): CFrame
		local value = character:GetAttribute(name)
		return typeof(value) == "CFrame" and value or fallback
	end

	-- One path for both arms. Work out where the published pose puts the hand, pull that
	-- towards the reload's target by however far through the reload we are, then solve the
	-- shoulder AND elbow that actually put the hand there.
	--
	-- Blending the POSITION rather than the rotation is what keeps the reload attached to
	-- the weapon: a half-applied rotation points the arm somewhere nobody asked for, while
	-- a half-applied position is still a real place for the hand to be.
	local function applyArm(elbowAttr: string, side, shoulder, elbow, wrist,
		poseC0, aimCF: CFrame, offset: CFrame, shoulderCache, elbowCache,
		reloadTarget: Vector3?, reloadWeight: number)
		if not (shoulder and shoulder:IsA("Motor6D") and typeof(poseC0) == "CFrame") then
			return
		end
		-- The server publishes the target pose; ease towards it rather than jumping, so
		-- raising and lowering the weapon is a movement instead of a cut.
		local rot = (side.shoulderC0:Inverse() * poseC0).Rotation
		local poseRot = (shoulderCache[character] or rot):Lerp(rot, blend)
		shoulderCache[character] = poseRot

		local shoulderC0 = side.shoulderC0 * aimCF * poseRot * authored(side, offset)
		local elbowC0 = published(elbowAttr, side.elbowC0)

		if reloadTarget and reloadWeight > 0 then
			local bend = side.elbowC0:Inverse() * elbowC0
			local posed = (shoulderC0 * side.upper * bend * side.fore).Position
			local wanted = posed:Lerp(reloadTarget, math.clamp(reloadWeight, 0, 1))
			local solvedShoulder, solvedElbow = ArmSolver.SolveTo(side, wanted, SUPPORT_SLACK)
			if solvedShoulder and solvedElbow then
				shoulderC0, elbowC0 = solvedShoulder, solvedElbow
			end
		end

		shoulder.C0 = shoulderC0 * shoulder.Transform:Inverse()
		bendJoint(elbowCache, elbow, elbowC0)
		steady(wrist, side.wristC0)
		return shoulderC0, elbowC0
	end

	-- The bladed stance. Turning the chest has to happen before the arms are read back for
	-- the support hand, because the arms hang off the UpperTorso this moves.
	local waistJoint = findMotor(character:FindFirstChild("UpperTorso"), "Waist")
	local waistHome = waistRestC0()
	if waistJoint and waistHome then
		local waistTarget = published("PoseWaist", waistHome)
		local eased = (smoothedWaist[character] or waistTarget):Lerp(waistTarget, blend)
		smoothedWaist[character] = eased
		waistJoint.C0 = eased * layerWaist * waistJoint.Transform:Inverse()
	end

	local rightShoulderC0, rightElbowC0 = applyArm("PoseRightElbow", r.right,
		rightShoulder, rightElbow, rightWrist,
		rightPose, rightAim, rightOffset, smoothedRight, smoothedRightElbow,
		reloadRight, reloadRightWeight)

	-- Keep the off hand ON the weapon as the weapon moves.
	--
	-- The server picks WHICH part of the gun the hand belongs on -- that needs the reach
	-- maths and the slide along the barrel -- but it solves against the pose it published,
	-- and the client then adds aim pitch, recoil and inspect on top. The off hand was left
	-- behind by all three: measured 1.49 studs off the weapon during an inspect.
	--
	-- Rebuilding the weapon's frame from the arm just written -- rather than reading the
	-- Handle, which is a physics step behind -- puts the hand back on the gun every frame.
	local leftTarget, leftWeight = reloadLeft, reloadLeftWeight
	local onWeapon = character:GetAttribute("PoseSupportOnWeapon")
	if not leftTarget and typeof(onWeapon) == "Vector3" and rightShoulderC0 and heldTool then
		local hand = character:FindFirstChild("RightHand")
		local weld = hand and hand:FindFirstChild("RightGrip")
		if weld and weld:IsA("Weld") then
			local bend = r.right.elbowC0:Inverse() * rightElbowC0
			local handRel = rightShoulderC0 * r.right.upper * bend * r.right.fore
			local weaponRel = handRel * weld.C0 * heldTool.Grip:Inverse()
			leftTarget, leftWeight = weaponRel * onWeapon, 1
		end
	end

	local leftPose = character:GetAttribute("PoseLeftC0")
	local leftShoulder, leftElbow, leftWrist = armJoints(character, "Left")
	applyArm("PoseLeftElbow", r.left, leftShoulder, leftElbow, leftWrist,
		leftPose, leftAim, leftOffset, smoothedLeft, smoothedLeftElbow,
		leftTarget, leftWeight)
end

-- NPCs carrying guns wear the same body and the same solved hold, so they are held here too.
-- Only the ones near enough for the detail to be visible: past this, arm poses are not
-- something anyone can make out, and each one is several joint writes a frame.
local NPC_HOLD_RANGE = 160
local caches = { smoothedPitch, smoothedRight, smoothedLeft, smoothedRightElbow, smoothedLeftElbow, smoothedWaist }
local nextPrune = 0

-- Every player, not just the local one: the pose has to look right on the people you
-- are shooting at as much as on yourself.
local function hold(dt: number)
	updateSway(dt)
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			holdOne(character, dt)
		end
	end

	local npcs = workspace:FindFirstChild("NPCs")
	if npcs then
		local eye = workspace.CurrentCamera.CFrame.Position
		for _, model in ipairs(npcs:GetChildren()) do
			if model:IsA("Model") and model:GetAttribute("PoseRightC0") ~= nil then
				local root = model.PrimaryPart
				if root and (root.Position - eye).Magnitude < NPC_HOLD_RANGE then
					holdOne(model, dt)
				end
			end
		end
	end

	-- NPC bodies come and go all game; do not keep easing state for ones that are gone.
	local now = os.clock()
	if now >= nextPrune then
		nextPrune = now + 5
		for _, cache in ipairs(caches) do
			for key in pairs(cache) do
				if not key.Parent then
					cache[key] = nil
				end
			end
		end
	end
end

RunService:BindToRenderStep("WeaponPoseHold", Enum.RenderPriority.Last.Value, hold)
