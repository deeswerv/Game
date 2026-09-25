--!strict
-- How a character holds what they are carrying.
--
-- Two separate things happen here, and they used to be tangled together:
--
--   1. WHERE THE ARMS GO -- set by rotating the R15 shoulder joints on the SERVER, so
--      everyone sees the pose, not just the holder.
--   2. HOW THE WEAPON SITS IN THE HAND -- solved from the model's own barrel geometry,
--      because a hardcoded grip angle is only ever right for the one pose it was
--      measured against.
--
-- StarterPlayerScripts.WeaponPoseHold is the other half of this: it stops the default
-- Animate script from stacking its own arm motion on top of the pose.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local WeaponConfig = require(ReplicatedStorage.WeaponConfig)

local WeaponPose = {}

-- ------------------------------------------------------------------- rig --
--
-- How an arm on this rig reaches a point lives in ReplicatedStorage.ArmSolver, because the
-- reload needs exactly the same answer -- and when each had its own copy, the reload's went
-- on assuming R6's single-joint arm and put the weapon inside the character's head.
--
-- Aliased to locals so the rest of this file reads the way it did when the maths was here.
local ArmSolver = require(ReplicatedStorage.ArmSolver)

type SideRig = ArmSolver.SideRig

local rigOf = ArmSolver.Rig
local authored = ArmSolver.Authored
local bendCF = ArmSolver.Bend
local armVector = ArmSolver.ArmVector
local bendForReach = ArmSolver.BendForReach

-- Each pose is a pair of extra rotations applied to the shoulders.
--
-- The two shoulders mirror each other: a POSITIVE roll swings the RIGHT arm forward
-- and a NEGATIVE roll swings the LEFT arm forward. 90 degrees is straight out front,
-- so anything much past that starts pushing the arm up over the shoulder.
local POSES = {
	-- Both hands on the weapon: rifles and shotguns.
	--
	-- The heavy across-the-body angle this used to carry was an R6 workaround, not a
	-- stylistic choice: held square-on the handguard sits 2.55 studs from the left shoulder
	-- against an arm that reached a fixed 1.58, so the off hand could not touch the weapon
	-- anywhere along it, and swinging the muzzle down and left was the only way to bring it
	-- into reach. R15 bends its elbow, so the hand reaches the handguard where the handguard
	-- actually is, and the weapon can come round to something much closer to level -- which
	-- is how it is carried in the reference footage.
	--
	-- Kept rather than squared up completely: an earlier R6 attempt at a fully tucked-in
	-- carry dropped the whole gun to waist height and left the stock poking out behind the
	-- player. The lesson still holds -- where the weapon SITS is the thing to get right, not
	-- the hand-to-weapon distance, which the elbow now takes care of on its own.
	--
	-- `carry` is the weapon's own aim relative to the torso: yaw positive to the left,
	-- pitch negative for muzzle-down. `elbow` is how far the gun arm is folded, in degrees.
	-- `left` is only a fallback -- for a gun, solveSupportArm replaces it with an arm placed
	-- on the weapon itself.
	TwoHanded = {
		right = CFrame.Angles(0, 0, math.rad(74)) * CFrame.Angles(math.rad(-10), 0, 0),
		left  = CFrame.Angles(0, 0, math.rad(-74)) * CFrame.Angles(math.rad(-8), 0, 0),
		-- Yaw is NEGATIVE here, swinging the muzzle out to the right, where every earlier
		-- version of this file swung it left across the body. Left was the R6 answer: it
		-- pulled the handguard back into a short arm's reach. It also put the whole weapon
		-- behind the character from the only camera that matters -- the player's own, which
		-- sits directly behind them -- and measured 0% of the gun visible in every stance,
		-- carry and aim alike.
		--
		-- The geometry does not allow both: a 2.9-stud rifle, a 1.63-stud arm and a 1.8-wide
		-- torso cannot put both hands on the gun AND clear the silhouette. Swinging the
		-- muzzle right splits the difference -- the barrel, which is the half that reads as
		-- "gun", comes out into the open while the grip stays where the off hand can hold it.
		-- Sign note, because it wastes an hour otherwise: positive yaw swings the muzzle LEFT,
		-- so a NEGATIVE value here is what points the weapon out to the right where the player
		-- can see it. And the bore you end up with is -(carry.yaw + whatever the reach fit adds)
		-- -- measured exactly, across three settings -- so read the fitted yaw before concluding
		-- this number is being ignored. It is not; the fit is simply outvoting it.
		-- Measured, and left where it started -- which is the finding, not a failure to change
		-- anything. The bore the player actually sees is
		--
		--     bore relative to facing = -(carry.yaw + whatever the reach fit adds) + blade
		--
		-- and the fit term dominates: it spends its full 42 degree budget at most settings, so
		-- this number does far less than it looks like it does. Do not reason about the sign of
		-- it from first principles; read the fitted yaw and measure. Two separate attempts to
		-- predict which way it would move were both wrong.
		--
		-- Swept across four settings:
		--
		--    carry  bore vs facing   visible   support hand
		--     -52        +76           55%        on
		--     -26        +50           52%        on
		--      -9         -9           47%        on     <- this one
		--     +12        -30            4%        on
		--
		-- Swinging the weapon far right buys 8 points of visibility and costs a gun pointing
		-- half a right angle away from where the player is looking. -9 keeps the bore within ten
		-- degrees of forward and gives up almost nothing for it.
		carry = { yaw = -9, pitch = -7 },
		blade = 24,
		-- A bent gun arm pulls the whole weapon in towards the chest, which is what brings
		-- the handguard inside the off hand's reach. Held at full stretch the rifle sits so
		-- far out that the support arm cannot touch it at any angle -- which is exactly what
		-- R6 was stuck with. Folded too hard, though, and the gun ends up behind the player.
		elbow = 48,
		-- Aimed at, not placed at: the arm lands the hand along this direction at whatever
		-- length the elbow bend leaves it, rather than at the point itself.
		--
		-- Tuned against two measurements, neither of them "does it look right from here":
		--
		--   1. How far the weapon ends up from the LEFT shoulder. Past that arm's reach the
		--      off hand comes off the gun and slides back down the barrel.
		--   2. How much of the weapon the PLAYER can see, raycast from their own camera.
		--      Tucked across the chest this read as perfectly correct from the side and was
		--      100% hidden behind the character's own back from the one angle that matters.
		--
		-- So the gun hand sits out to the right of the centreline rather than on it, and the
		-- weapon points much closer to straight ahead. Check both numbers in the same pass:
		-- moving the weapon to satisfy either one will break the other.
		gripToward = Vector3.new(0.46, -0.04, -1.00),
	},
	-- Brought up to the ready: the weapon comes level and the hands rise to the eye line.
	-- Still angled across the body, because that angle is what keeps the off hand on the
	-- gun -- squared up to the front, the handguard leaves the left arm's reach entirely.
	--
	-- The gun hand is aimed a good deal higher than the carry pose, which is what makes
	-- aiming read as bringing the weapon UP rather than just levelling it out.
	TwoHandedAim = {
		right = CFrame.Angles(0, 0, math.rad(74)) * CFrame.Angles(math.rad(-10), 0, 0),
		left  = CFrame.Angles(0, 0, math.rad(-74)) * CFrame.Angles(math.rad(-8), 0, 0),
		-- Pitch is well below level on purpose, and it is a correction rather than a look.
		--
		-- The carry pose lands its bore exactly where `carry` asks. This one does not: raising
		-- the hand makes armToward take a bigger swing, and the minimal rotation it picks
		-- carries an arbitrary roll about the arm's own axis that nothing else pins down. That
		-- roll tilts the weapon, measured at about 15 degrees nose-up on the Warden.
		--
		-- Measure the BARREL's axis if you retune this, never handle-to-muzzle: the muzzle
		-- sits above the grip, so that line reads a further 13 degrees high and will send you
		-- chasing an error that is not there.
		-- Do not read this as "the weapon points 6 degrees down". The carry angle feeds both
		-- the grip solve and the arm swing, so the bore moves about 2.5 degrees for every one
		-- degree here -- measured, by moving it 15 and watching the bore move 38. Solve for
		-- the bore you want rather than nudging this and hoping.
		-- Trimmed against a measurement of the bore against the camera line. Once the aim
		-- rotation was put back on the camera's own axis (see WeaponPoseHold) the tracking went
		-- 1:1 -- 59.1 degrees of bore for a 60 degree camera sweep -- and what was left was a
		-- CONSTANT +6 pitch, -9 yaw at every angle. A constant offset is exactly what a wrong
		-- carry angle looks like, so it is divided by the 2.5x gain above and subtracted here.
	-- Zero pitch, and that is the whole point of the aim stance: the bore belongs ON the
		-- camera line, not a few degrees under it. Anything nonzero here shows up as a constant
		-- error at every camera angle -- with pitch at -8 the bore sat exactly 8.0 degrees low
		-- whether you looked up, down or level.
		--
		-- Yaw 12 is not an offset either: the aim stance blades the torso by 13, so 12 lands the
		-- bore about 1 degree off the camera. The two very nearly cancel.
		--
		-- These numbers only started behaving once the weld bug was fixed (see WeaponPoseHold:
		-- Tool.Grip does not propagate to an existing RightGrip weld). Before that they did
		-- nothing whatsoever, and setting pitch to -60 moved the bore not one tenth of a degree.
		-- If they ever appear to be ignored again, check weld.C1 before re-tuning anything.
		--
		-- Measure the BARREL's axis, never handle-to-muzzle -- that reads a phantom 13 degrees
		-- high. And hold the aim button for real: setting the Aiming attribute by hand is
		-- overwritten within a tenth of a second by the client's own stance report, and you end
		-- up measuring the carry pose and declaring the aim fine.
		carry = { yaw = 12, pitch = 0 },
		elbow = 50,
		-- Less bladed than the carry: bringing the weapon up squares the shoulders towards
		-- what is being aimed at, which is both what a shooter does and what keeps the sights
		-- in line with the crosshair.
		blade = 13,
		gripToward = Vector3.new(0.30, 0.42, -1.02),
	},

	-- Running with it. The weapon drops out of the aim line and tucks in across the body,
	-- muzzle down -- both because that is what anyone actually sprinting with a rifle does,
	-- and because it gets the barrel out of the middle of the screen while the camera is
	-- moving fastest. The off hand stays on the gun: this is a carry, not a let-go.
	TwoHandedSprint = {
		right = CFrame.Angles(0, 0, math.rad(52)) * CFrame.Angles(math.rad(-14), 0, 0),
		left  = CFrame.Angles(0, 0, math.rad(-52)) * CFrame.Angles(math.rad(-10), 0, 0),
		carry = { yaw = 30, pitch = -38 },
		elbow = 74,
		blade = 30,
		gripToward = Vector3.new(0.16, -0.80, -0.62),
	},

	-- A sidearm is small enough to hold out level in one hand, so it needs no carry angle.
	OneHanded = {
		right = CFrame.Angles(0, 0, math.rad(92)) * CFrame.Angles(math.rad(-5), 0, 0),
		left  = CFrame.Angles(0, 0, math.rad(-6)),
		carry = { yaw = 0, pitch = 0 },
		elbow = 14,
	},
	-- A sidearm punched out towards the eye line.
	OneHandedAim = {
		right = CFrame.Angles(0, 0, math.rad(97)) * CFrame.Angles(math.rad(-2), 0, 0),
		left  = CFrame.Angles(0, 0, math.rad(-6)),
		carry = { yaw = 0, pitch = 0 },
		elbow = 10,
	},

	-- A sidearm gets dropped to the thigh rather than swung across the chest; there is no
	-- off hand on it to keep in place, so it can go further down than the rifle does.
	OneHandedSprint = {
		right = CFrame.Angles(0, 0, math.rad(34)) * CFrame.Angles(math.rad(-8), 0, 0),
		left  = CFrame.Angles(0, 0, math.rad(-10)),
		carry = { yaw = 12, pitch = -46 },
		elbow = 40,
	},

	-- Blade down at the side.
	Melee = {
		right = CFrame.Angles(0, 0, math.rad(24)),
		left  = CFrame.Angles(0, 0, math.rad(-18)),
		elbow = 12,
	},
}

-- ----------------------------------------------------------- the stance --
--
-- Nobody fires a rifle square-on to the target; they stand bladed, weapon side turned
-- back. Turning the upper torso towards the weapon side buys two things at once, which is
-- why it is worth doing rather than tuning arm angles forever:
--
--   1. The weapon is carried in front of the chest, so rotating the chest swings it out to
--      the RIGHT -- clear of the character's own silhouette, which is the only reason the
--      player can see their own gun from a camera sitting directly behind them.
-- It does NOT help the off hand reach, though it looks like it should. Everything the pose
-- maths does is expressed relative to the UpperTorso, and blading rotates the UpperTorso
-- itself -- so the weapon and both shoulders turn together and nothing moves relative to
-- anything else. The reach problem is settled entirely by gripToward and the elbow fit
-- below; this is a world-space change, bought purely for what the player can see.
local waistRest: CFrame? = nil

-- Find a joint by name AND class. FindFirstChild is not enough: this Roblox build rigs R15
-- characters with AnimationConstraints that carry the SAME names as the Motor6Ds -- there
-- are two things called "Waist" on the UpperTorso -- and the plain lookup returns whichever
-- it meets first. That silently handed back a constraint here, and the bladed stance simply
-- never published.
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

local function bladedWaist(blade: number?): CFrame?
	if not waistRest then
		local source = StarterPlayer:FindFirstChild("StarterCharacter")
		local waist = findMotor(source and source:FindFirstChild("UpperTorso"), "Waist")
		if waist then
			waistRest = waist.C0
		end
	end
	if not waistRest then
		return nil
	end
	-- Negative, so the chest turns towards the weapon side. Positive swings the right
	-- shoulder forwards instead, which pushes the weapon further behind the player.
	return waistRest * CFrame.Angles(0, -math.rad(blade or 0), 0)
end

-- Returns the pose and the name it is cached under. Aiming picks the raised variant and
-- sprinting the lowered one, where the hold style has them; anything without a variant
-- falls back to the ordinary carry rather than needing one written for it.
local function poseFor(cfg, aiming: boolean?, sprinting: boolean?)
	if not cfg then
		return nil, nil
	end
	if cfg.Type == "Melee" then
		return POSES.Melee, "Melee"
	end
	local hold = cfg.Hold or "TwoHanded"
	-- Aiming wins over sprinting. Pulling the aim button mid-run means bring the weapon UP,
	-- and the humanoid takes a moment to drop back to walking pace -- so checking sprint
	-- first would leave the gun down for that moment, exactly when the player wants it up.
	if aiming and POSES[hold .. "Aim"] then
		return POSES[hold .. "Aim"], hold .. "Aim"
	end
	if sprinting and POSES[hold .. "Sprint"] then
		return POSES[hold .. "Sprint"], hold .. "Sprint"
	end
	return POSES[hold] or POSES.TwoHanded, hold
end

-- ------------------------------------------------------------------- grip --

-- An orthonormal CFrame whose LookVector is `forward` and whose UpVector is as close
-- to `up` as being perpendicular allows.
local function frame(forward: Vector3, up: Vector3): CFrame
	local f = forward.Unit
	local u = up - f * up:Dot(f)
	if u.Magnitude < 1e-4 then
		-- `up` was parallel to the bore; any perpendicular will do.
		local fallback = math.abs(f.Y) < 0.9 and Vector3.new(0, 1, 0) or Vector3.new(1, 0, 0)
		u = fallback - f * fallback:Dot(f)
	end
	u = u.Unit
	return CFrame.fromMatrix(Vector3.zero, f:Cross(u), u, -f)
end

-- Where to measure a weapon's geometry: the stored template rather than the equipped
-- copy, because the template's parts are never simulated and so sit exactly as built.
local function axesSource(tool: Tool): Instance
	local store = ReplicatedStorage:FindFirstChild("storeitems")
	local template = store and store:FindFirstChild(tool.Name)
	if template and template:IsA("Tool") and template:FindFirstChild("Handle") then
		return template
	end
	return tool
end

-- The barrel's own long axis, turned to point at the muzzle.
--
-- Taking barrel-centre -> muzzle-centre seems more obvious but is wrong on any weapon
-- whose muzzle is not centred on the barrel part: the Scattergun stacks two barrels and
-- puts the muzzle between them, which tilted its "bore" four degrees nose-down. And
-- handle -> muzzle, the first thing tried here, folds in the whole drop from the grip up
-- to the barrel. The part's own axis carries neither error; the muzzle is only used to
-- decide which end is the front.
local function barrelAxis(barrel: BasePart, muzzle: BasePart): Vector3
	local size = barrel.Size
	local axis
	if size.Z >= size.X and size.Z >= size.Y then
		axis = barrel.CFrame.LookVector
	elseif size.Y >= size.X then
		axis = barrel.CFrame.UpVector
	else
		axis = barrel.CFrame.RightVector
	end
	if axis:Dot(muzzle.Position - barrel.Position) < 0 then
		axis = -axis
	end
	return axis
end

-- Which way a weapon fires and which way is up on it, in the Handle's own space.
local function modelAxes(tool: Instance): (Vector3, Vector3)
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		return Vector3.new(0, 0, -1), Vector3.new(0, 1, 0)
	end

	local bore = Vector3.new(0, 0, -1)
	local barrel = (tool:FindFirstChild("Barrel") or tool:FindFirstChild("BarrelTop")) :: BasePart?
	local muzzle = tool:FindFirstChild("Muzzle") :: BasePart?
	if barrel and muzzle and (muzzle.Position - barrel.Position).Magnitude > 0.05 then
		bore = handle.CFrame:VectorToObjectSpace(barrelAxis(barrel, muzzle))
	end

	-- The magazine hangs below the receiver, so magazine -> rail points up the gun.
	local up = Vector3.new(0, 1, 0)
	local mag = (tool:FindFirstChild("Magazine") or tool:FindFirstChild("MagBase")) :: BasePart?
	local rail = (tool:FindFirstChild("Rail")
		or tool:FindFirstChild("Upper")
		or tool:FindFirstChild("Slide")
		or tool:FindFirstChild("Receiver")) :: BasePart?
	if mag and rail and (rail.Position - mag.Position).Magnitude > 0.05 then
		up = handle.CFrame:VectorToObjectSpace((rail.Position - mag.Position).Unit)
	end

	return bore, up
end

-- How far above the hand the bore should sit. On a real weapon the barrel runs just
-- over the top of the fist; these models put it most of a stud higher, which read as
-- the gun hovering above the hand rather than being held by it. At 0.55 the fist ends
-- up wrapped round the top of the grip with the magazine hanging below, as it should.
local TARGET_BORE_HEIGHT = 0.55

-- How far to lower the weapon in the hand so its bore lands at that height. Derived
-- from the model, so a weapon with a taller grip is dropped further without anyone
-- having to hand-tune a number per gun.
local function gripDrop(tool: Instance, up: Vector3): number
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	local muzzle = tool:FindFirstChild("Muzzle") :: BasePart?
	if not (handle and muzzle) then
		return 0
	end
	-- The muzzle sits on the bore line, so its height above the grip is the bore height.
	local boreHeight = handle.CFrame:PointToObjectSpace(muzzle.Position):Dot(up)
	return math.max(boreHeight - TARGET_BORE_HEIGHT, 0)
end

-- The Grip that makes this weapon point level and straight ahead in the given pose.
--
-- Roblox welds the Handle to the hand as `handle = arm * A0 * Grip:Inverse()`, where A0
-- is the weld's own offset. So for a wanted handle orientation M (relative to the
-- torso) the grip is `M:Inverse() * armRelTorso * A0`.
--
-- armRelTorso is computed from the shoulder joint rather than read off the character.
-- Reading the live arm would fold in whatever animation happened to be playing, and the
-- grip would then come out different every time the player jumped or went in the water.
--
-- Every input is a constant of the rig, the pose or the model, so the answer is too and
-- it only has to be worked out once per weapon.
local gripCache: { [string]: CFrame } = {}

-- The gun-arm bend each weapon actually needs, per stance. Depends only on the weapon's
-- geometry and the authored pose, so it is worked out once and kept.
local elbowFit: { [string]: { theta: number, yaw: number } } = {}

-- Extra across-the-body yaw the fit may spend, in degrees, tried in this order. Zero first
-- so nothing pays for visibility it does not need.
local FIT_YAWS = { 0, 10, 20, 30, 42 }

-- The furthest the fit below will fold the gun arm. ArmSolver will bend further than this
-- on request, but past here the weapon is pulled right into the chest and reads as a hug
-- rather than a carry -- better to leave the off hand slightly short than to do that.
local MAX_FIT_BEND = math.rad(105)

-- How far the off hand may slide back from the weapon's authored grip point before the fit
-- decides the weapon is being held too far out.
--
-- The test is the SLIDE, not the raw reach. Most weapons put their grip point a little
-- beyond a straight arm and the hand simply slides a few tenths of a stud along the barrel
-- to meet it, which is both normal and invisible. Bending the arm whenever the exact point
-- was out of reach re-folded the Warden from 48 degrees to 96 and spoiled a hold that was
-- already correct. Only a LONG slide -- the one that ends up on the stock -- is a problem.
local MAX_COMFORTABLE_SLIDE = 0.55

local function cfgOf(tool: Tool)
	return WeaponConfig.Get(tool.Name) or WeaponConfig.Defaults
end

local function solveGrip(character: Model, tool: Tool, pose, poseName: string): CFrame?
	-- R15 welds the tool to the hand part, where R6 welded it to the whole arm.
	local hand = character:FindFirstChild("RightHand") :: BasePart?
	if not hand then
		return nil
	end
	-- Nothing to solve until the tool is actually welded into the hand.
	local weld = hand:FindFirstChild("RightGrip")
	if not (weld and weld:IsA("Weld")) then
		return nil
	end
	local r = rigOf(character)
	if not r then
		return nil
	end

	-- The bend is part of the key. The grip is solved against the arm's exact shape, so two
	-- different elbow angles are two different grips -- and the reach fit in Apply asks for
	-- several bends in a row before it settles on one.
	local carryYaw = pose.carry and pose.carry.yaw or 0
	local key = ("%s|%s|%d|%d"):format(tool.Name, poseName,
		math.floor(math.deg(pose.elbow or 0) + 0.5), math.floor(carryYaw + 0.5))
	local cached = gripCache[key]
	if cached then
		return cached
	end

	-- The weld's C0 IS the hand-to-handle offset, and it is a stored property, so this is
	-- exact. The first version of this recovered the same value from the live CFrames of
	-- the arm and the handle -- across a joint -- which picked up whatever the physics
	-- step had got round to. The solved grip then flipped between correct and 23 degrees
	-- nose-up from one tick to the next, and the gun visibly twitched in the hand.
	local a0 = weld.C0
	local armRelTorso = (r.right.shoulderC0 * pose.right)
		* (r.right.upper * bendCF(pose.elbow or 0) * r.right.fore)

	local source = axesSource(tool)
	local bore, rawUp = modelAxes(source)

	-- Square the basis up before anything is measured along it. "Up" is taken from the
	-- line between the magazine and the rail, which on a real weapon leans forward, so
	-- using it raw made a nudge along one axis quietly bleed into another: asking the gun
	-- to come forward moved it slightly backward instead.
	bore = bore.Unit
	local up = rawUp - bore * rawUp:Dot(bore)
	up = up.Magnitude > 1e-4 and up.Unit or Vector3.new(0, 1, 0)

	-- Wanted: the weapon sitting at its carry angle, upright about its own barrel.
	local carry = pose.carry or { yaw = 0, pitch = 0 }
	local aim = CFrame.Angles(0, math.rad(carry.yaw), 0) * CFrame.Angles(math.rad(carry.pitch), 0, 0)
	local M = frame(aim * Vector3.new(0, 0, -1), aim * Vector3.new(0, 1, 0))
		* frame(bore, up):Inverse()
	local rotation = M:Inverse() * armRelTorso.Rotation * a0.Rotation

	-- Where the weapon sits in the fist, along all three of its own axes:
	--
	--   drop        slides it DOWN so the grip beds into the hand rather than hovering
	--   GripLateral shifts it ACROSS the palm -- the hand is a whole stud wide, so a grip
	--               centred on the arm still reads as hanging off the outer edge of it
	--   GripForward slides it ALONG the barrel, to bring the grip under the fist instead
	--               of leaving the fist closed around the frame
	--
	-- The signs are set up so positive is the intuitive direction in each case.
	local weaponCfg = cfgOf(tool)
	local lateral = bore:Cross(up).Unit          -- the weapon's own right
	local offset = up * gripDrop(source, up)
		+ lateral * (weaponCfg.GripLateral or 0)
		- bore * (weaponCfg.GripForward or 0)

	local grip = CFrame.new(offset) * rotation
	gripCache[key] = grip
	return grip
end

-- ------------------------------------------------------ the supporting arm --

-- The shortest rotation carrying `from` onto `to`.
local function rotationBetween(from: Vector3, to: Vector3): CFrame
	local u, v = from.Unit, to.Unit
	local dot = math.clamp(u:Dot(v), -1, 1)
	if dot > 0.9999 then
		return CFrame.identity
	end
	if dot < -0.9999 then
		-- Exactly opposed: any perpendicular axis is as good as any other.
		local seed = math.abs(u.Y) < 0.9 and Vector3.new(0, 1, 0) or Vector3.new(1, 0, 0)
		return CFrame.fromAxisAngle(u:Cross(seed).Unit, math.pi)
	end
	return CFrame.fromAxisAngle(u:Cross(v).Unit, math.acos(dot))
end

-- Where the off hand belongs on the weapon, in the Handle's own space: the handguard if
-- the model has one, otherwise a point part way along the bore.
local function supportOffset(source: Instance, bore: Vector3, up: Vector3): Vector3?
	local handle = source:FindFirstChild("Handle") :: BasePart?
	if not handle then
		return nil
	end
	-- First choice: the point the weapon's author marked.
	--
	-- WeaponMounts stamps Mount_Underbarrel onto the Handle from the source model's own
	-- underbarrel node -- where a foregrip bolts on, which is exactly where a support hand
	-- belongs -- already in Handle space, which is the space this function returns.
	--
	-- It beats guessing from part names on every count: it is the artist's intent rather
	-- than ours, it is per-weapon, and a new weapon earns a correct support hand by adding a
	-- row to WeaponMounts.Data instead of hoping it happened to name its handguard something
	-- on the list below. The Sentinel has no handguard part at all and was falling through to
	-- the muzzle fraction at the bottom of this function.
	local mount = handle:FindFirstChild("Mount_Underbarrel")
	if mount and mount:IsA("Attachment") then
		-- Wrapped under the rail rather than floating on the centre line of it.
		return mount.Position - up * 0.12
	end

	for _, name in ipairs({ "LowerHandguard", "Handguard", "Foregrip", "Pump", "UpperHandguard" }) do
		local p = source:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			-- The hand wraps under the handguard rather than through the middle of it.
			return handle.CFrame:PointToObjectSpace(p.Position) - up * (p.Size.Y * 0.4)
		end
	end
	local muzzle = source:FindFirstChild("Muzzle") :: BasePart?
	if muzzle then
		return handle.CFrame:PointToObjectSpace(muzzle.Position) * 0.55
	end
	return nil
end

-- Put the left hand ON the weapon, wherever along it the arm can actually reach.
--
-- Aiming straight at the handguard is not enough: the arm has a fixed length when the
-- elbow is straight, and on a rifle held out to the right the handguard can sit further
-- away than that, so the hand would stop in mid-air short of the gun. Instead of a fixed
-- target, this walks along the weapon's own axis and finds the point exactly one arm's
-- length from the left shoulder. The hand then lands on the weapon every time, sliding
-- forward or back along it as the pose changes rather than missing it altogether.
--
-- R15 reaches 1.78 studs where R6 reached 1.58, and unlike R6 it has an elbow, so it can
-- also reach anything NEARER than full stretch -- see solveSupportElbow.

-- How far along the weapon axis the hand may slide from the handguard, in studs, so it
-- stays somewhere a hand could plausibly hold. The backward limit reaches the magazine
-- well, which is a real grip and the one that keeps the hand ON a rifle held close in;
-- stopping it at 1.1 left the hand hanging a stud short of the weapon instead.
--
-- It does NOT reach the stock. Opened up to 1.9 the solver happily slid the off hand all
-- the way back onto the butt pad, which is not a grip anyone uses.
-- Tightened from 1.6. At 1.6 the hand could slide far enough back to grip the Blackwood's
-- stock, the Scattergun's trigger and the Carbine's grip collar -- it was touching the
-- weapon, which is what the solver was asked for, but nowhere a hand belongs. Held to 1.15
-- it stays in the handguard-to-magwell band, which is the range of real support grips.
local SUPPORT_MIN, SUPPORT_MAX = -1.15, 0.9

-- How far forward of the grip the support hand must stay, in studs. Keeps it out on the
-- weapon rather than folded back over the trigger hand.
local MIN_SUPPORT_FORWARD = 0.55

-- Never let the support arm lock out straight. A real one keeps a bend, and an arm solved
-- to exactly full stretch has no give left either -- the hand pops off the weapon the
-- moment the aim pitches, because there is nowhere further for it to go. Solving against a
-- slightly shorter arm leaves the elbow bent and the hand able to follow the gun.
local SUPPORT_SLACK = 0.92

-- The point on the line `origin + direction * t` exactly `reach` away from `from`,
-- choosing the solution nearest the handguard. When the whole line is out of reach it
-- returns the closest approach instead, which is the best the arm can do.
local function reachableAlong(origin: Vector3, direction: Vector3, from: Vector3, reach: number): number
	local w = origin - from
	local b = w:Dot(direction)
	local disc = b * b - w:Dot(w) + reach * reach
	if disc <= 0 then
		return -b
	end
	local root = math.sqrt(disc)
	local t1, t2 = -b + root, -b - root
	return math.abs(t1) < math.abs(t2) and t1 or t2
end

-- Where the off hand belongs on the weapon, in UpperTorso space, BEFORE any clamping for
-- reach -- plus the weapon's own forward, which is the line the hand may slide along.
--
-- Split out so the reach fit in Apply and the support solve below agree by construction:
-- the fit asks "could the hand reach this weapon at that elbow angle", and it has to be
-- asking about exactly the point the solve will later aim at.
local function supportPoint(character: Model, tool: Tool, pose, grip: CFrame): (Vector3?, Vector3?, CFrame?)
	local hand = character:FindFirstChild("RightHand") :: BasePart?
	local weld = hand and hand:FindFirstChild("RightGrip")
	local r = rigOf(character)
	if not (weld and weld:IsA("Weld")) or not r then
		return nil, nil, nil
	end

	local source = axesSource(tool)
	local bore, rawUp = modelAxes(source)
	bore = bore.Unit
	local up = rawUp - bore * rawUp:Dot(bore)
	up = up.Magnitude > 1e-4 and up.Unit or Vector3.new(0, 1, 0)

	local offset = supportOffset(source, bore, up)
	if not offset then
		return nil, nil, nil
	end

	-- Where the weapon ends up, given the right arm's pose and the solved grip.
	local armRelTorso = (r.right.shoulderC0 * pose.right)
		* (r.right.upper * bendCF(pose.elbow or 0) * r.right.fore)
	local weaponRelTorso = armRelTorso * weld.C0 * grip:Inverse()

	return weaponRelTorso * offset, weaponRelTorso:VectorToWorldSpace(bore).Unit, weaponRelTorso
end

local function solveSupportArm(character: Model, tool: Tool, pose, grip: CFrame): (CFrame?, CFrame?, Vector3?)
	local r = rigOf(character)
	if not r then
		return nil
	end
	local left = r.left

	local handguard, axis, weaponRelTorso = supportPoint(character, tool, pose, grip)
	if not handguard or not axis or not weaponRelTorso then
		return nil
	end

	-- With an elbow the hand can reach anything inside full stretch, so aim straight at the
	-- handguard and let the arm fold to suit. Sliding along the barrel is now only the
	-- fallback for a weapon genuinely held too far away -- on R6 it was the every-pose case,
	-- because a straight arm can only ever touch one radius.
	local usable = left.reach * SUPPORT_SLACK
	local target = handguard
	if (target - left.shoulderPos).Magnitude > usable then
		local t = reachableAlong(handguard, axis, left.shoulderPos, usable)
		target = handguard + axis * math.clamp(t, SUPPORT_MIN, SUPPORT_MAX)

		-- The support hand is never behind the firing hand.
		--
		-- Sliding back down the barrel to find something reachable is fine right up until it
		-- slides PAST the grip: the Blackwood ended up holding its own stock and the Scattergun
		-- its trigger. Both were genuinely touching the weapon, which is all the solver had been
		-- asked for -- it had no notion that some parts of a gun are not handholds.
		--
		-- The weapon's own frame is centred on the Handle, so the grip is simply its origin, and
		-- "forward of the grip along the bore" is the whole constraint.
		local gripPos = weaponRelTorso.Position
		local forward = (target - gripPos):Dot(axis)
		if forward < MIN_SUPPORT_FORWARD then
			target += axis * (MIN_SUPPORT_FORWARD - forward)
		end
	end

	local desired = target - left.shoulderPos
	if desired.Magnitude < 1e-3 then
		return nil
	end

	local theta = bendForReach(left, desired.Magnitude)
	local M = rotationBetween(armVector(left, theta), desired)

	-- The chosen point, expressed back in the WEAPON's own space. Deciding WHICH part of the
	-- gun the off hand belongs on needs the reach maths and the slide along the barrel, so
	-- the server does it -- but the client is what has to keep the hand there as the weapon
	-- moves under aim, recoil and inspect, and it can only do that if it knows the spot.
	local onWeapon = weaponRelTorso:PointToObjectSpace(target)

	return left.shoulderC0 * (left.jointAxes:Inverse() * M * left.jointAxes), bendCF(theta), onWeapon
end

-- The extra shoulder rotation that swings an arm so its hand lies along `toward`.
-- The arm cannot change length, so the hand ends up on that ray at full stretch rather
-- than at the point itself.
--
-- `twist` rolls the arm about its own length. That is the one degree of freedom left over
-- once the hand position is fixed, and it costs nothing: the hand does not move a
-- thousandth of a stud at any twist, while the weapon welded to it swings right round.
-- It is the only way to aim the gun without also moving the hand without going through
-- the wrist as well.
local function armToward(shoulder: Vector3, restHand: Vector3, jointAxes: CFrame,
	toward: Vector3, twist: number?): CFrame?
	local desired = toward - shoulder
	if desired.Magnitude < 1e-3 then
		return nil
	end
	local M = rotationBetween(restHand - shoulder, desired)
	if twist and twist ~= 0 then
		M = CFrame.fromAxisAngle(desired.Unit, math.rad(twist)) * M
	end
	return jointAxes:Inverse() * M * jointAxes
end

local function shoulders(character: Model)
	-- R15 parents each joint to the limb it drives, so the shoulders live on the upper arms
	-- rather than all together on the torso the way R6's did.
	local rightArm = character:FindFirstChild("RightUpperArm")
	local leftArm = character:FindFirstChild("LeftUpperArm")
	return rightArm and rightArm:FindFirstChild("RightShoulder"),
		leftArm and leftArm:FindFirstChild("LeftShoulder")
end

function WeaponPose.Clear(character: Model)
	local r = rigOf(character)
	local right, left = shoulders(character)
	if r then
		if right and right:IsA("Motor6D") then right.C0 = r.right.shoulderC0 end
		if left and left:IsA("Motor6D") then left.C0 = r.left.shoulderC0 end
	end
	character:SetAttribute("PoseRightC0", nil)
	character:SetAttribute("PoseLeftC0", nil)
	character:SetAttribute("PoseRightElbow", nil)
	character:SetAttribute("PoseLeftElbow", nil)
	character:SetAttribute("PoseSupportOnWeapon", nil)
	character:SetAttribute("PoseWaist", nil)
end

function WeaponPose.Apply(character: Model, toolName: string)
	local cfg = WeaponConfig.Get(toolName)
	-- Set by the client while the player holds the aim button.
	local aiming = character:GetAttribute("Aiming") == true
	local sprinting = character:GetAttribute("Sprinting") == true
	local pose, stance = poseFor(cfg, aiming, sprinting)
	if not pose then
		WeaponPose.Clear(character)
		return
	end
	-- A pose may either state the shoulder rotation outright or name where the hand should
	-- go; the second is far easier to reason about for a two-handed carry.
	local r = rigOf(character)
	if not r then
		return
	end
	local function resolve(p, thetaOverride: number?, yawExtra: number?)
		-- gripToward is solved directly in torso space, so it needs no conversion; the
		-- hand-authored angles do.
		local theta = thetaOverride or math.rad(p.elbow or 0)
		local rot = authored(r.right, p.right)
		if p.gripToward then
			-- Aim from where the hand actually sits at this bend, not from full stretch.
			local restPoint = r.right.shoulderPos + armVector(r.right, theta)
			rot = armToward(r.right.shoulderPos, restPoint, r.right.jointAxes, p.gripToward, p.twist) or rot
		end
		-- A weapon too long for the off hand to reach is swung further across the body, which
		-- is the one thing that genuinely brings its handguard towards the LEFT shoulder.
		-- Positive yaw is muzzle-left.
		local carry = p.carry
		if carry and yawExtra and yawExtra ~= 0 then
			carry = { yaw = carry.yaw + yawExtra, pitch = carry.pitch }
		end
		return {
			right = rot,
			left = authored(r.left, p.left),
			carry = carry,
			elbow = theta,
			blade = p.blade,
		}
	end
	local authoredPose = pose
	pose = resolve(authoredPose)

	local tool = character:FindFirstChild(toolName)

	-- Fold the gun arm in until the off hand can actually reach the weapon.
	--
	-- gripToward and elbow are authored once, against a rifle about the Warden's length. A
	-- longer weapon puts its grip point further from the left shoulder than the arm can
	-- reach, and the support hand then slides back down the barrel towards the stock -- the
	-- Blackwood ended up on its stock comb, with the authored grip point 2.42 studs away
	-- against a 1.63 reach.
	--
	-- Rather than author a separate carry for every weapon, bend the elbow further: that
	-- pulls the whole weapon in towards the chest, which is exactly what a person does with a
	-- long gun. A new weapon then needs no pose of its own.
	--
	-- Solved once per weapon and stance and cached, because it depends only on the weapon's
	-- geometry and the authored pose, and both are constants.
	if cfg and cfg.Type == "Gun" and (cfg.Hold or "TwoHanded") == "TwoHanded"
		and tool and tool:IsA("Tool") and authoredPose.gripToward
	then
		local fitKey = toolName .. "|" .. (stance or "TwoHanded")
		local fit = elbowFit[fitKey]
		if not fit then
			local base = math.rad(authoredPose.elbow or 0)
			local usable = r.left.reach * SUPPORT_SLACK

			-- How far back down the barrel the hand would have to slide, for a candidate.
			-- Zero means it lands on the authored grip point itself.
			local function slideFor(theta: number, yawExtra: number): number?
				local candidate = resolve(authoredPose, theta, yawExtra)
				local candidateGrip = solveGrip(character, tool, candidate, stance or "TwoHanded")
				if not candidateGrip then
					return nil
				end
				local point, axis = supportPoint(character, tool, candidate, candidateGrip)
				if not (point and axis) then
					return nil
				end
				if (point - r.left.shoulderPos).Magnitude <= usable then
					return 0
				end
				return math.abs(reachableAlong(point, axis, r.left.shoulderPos, usable))
			end

			-- Yaw is the outer loop and is tried from zero upwards, so a weapon short enough to
			-- be held open-carry keeps the open carry. Only a weapon that cannot be reached any
			-- other way pays visibility for a correct grip, and only as much as it needs.
			-- Aiming may not buy a grip with yaw. Swinging the weapon across the body is fine
			-- for a carry, where nothing depends on where the barrel points, but the whole
			-- contract of the aim stance is that the bore lines up with the crosshair. The fit
			-- was spending up to 42 degrees of it and putting the shot 29 degrees off aim.
			local yawBudget = FIT_YAWS
			if stance and stance:sub(-3) == "Aim" then
				yawBudget = { 0 }
			end

			local best, bestSlide = { theta = base, yaw = 0 }, math.huge
			for _, yawExtra in ipairs(yawBudget) do
				for extra = 0, 48, 8 do
					local theta = math.min(base + math.rad(extra), MAX_FIT_BEND)
					local slide = slideFor(theta, yawExtra)
					if slide and slide < bestSlide then
						best, bestSlide = { theta = theta, yaw = yawExtra }, slide
					end
					if slide and slide <= MAX_COMFORTABLE_SLIDE then
						break
					end
				end
				if bestSlide <= MAX_COMFORTABLE_SLIDE then
					break
				end
			end
			fit = best
			elbowFit[fitKey] = fit
		end
		pose = resolve(authoredPose, fit.theta, fit.yaw)
	end

	local rightC0 = r.right.shoulderC0 * pose.right
	local leftC0 = r.left.shoulderC0 * pose.left

	-- The grip has to be solved before the left arm, because where the handguard ends up
	-- depends on how the weapon sits in the right hand.
	--
	-- Solved per stance. An earlier version shared one grip between the carry and the aim
	-- so the weapon would swing up with the arm, and used a roll about the arm to point it
	-- forward -- but a roll about the ARM is not a roll about the BORE, so straightening
	-- the aim laid the weapon over on its side. Only the grip has the freedom to set the
	-- weapon's direction and its upright separately, so each stance gets its own and the
	-- change between them is smoothed on the client instead.
	local grip: CFrame? = nil
	local leftBend: CFrame? = nil
	local supportOnWeapon: Vector3? = nil
	if cfg and cfg.Type == "Gun" and tool and tool:IsA("Tool") then
		grip = solveGrip(character, tool, pose, stance or "TwoHanded")
		if grip and (cfg.Hold or "TwoHanded") == "TwoHanded" then
			-- The support arm still tracks the ACTIVE stance, so the off hand follows the
			-- weapon up rather than being left behind at the carry position.
			local solvedC0, solvedBend, onWeapon = solveSupportArm(character, tool, pose, grip)
			if solvedC0 then
				leftC0 = solvedC0
				leftBend = solvedBend
				supportOnWeapon = onWeapon
			end
		end
	end

	-- Written only when it actually changes. The client owns these joints frame to frame
	-- (see below), and a server write replicates over whatever the client has done, so
	-- rewriting the same pose ten times a second would make the arms stutter.
	local right, left = shoulders(character)
	if right and right:IsA("Motor6D") and not right.C0:FuzzyEq(rightC0, 1e-4) then
		right.C0 = rightC0
	end
	if left and left:IsA("Motor6D") and not left.C0:FuzzyEq(leftC0, 1e-4) then
		left.C0 = leftC0
	end

	-- Published for StarterPlayerScripts.WeaponPoseHold. The drawn joint is C0 * Transform
	-- and the animator owns Transform, so the client has to divide the animation back out
	-- of C0 every frame to hold the pose. It needs to know what the pose was meant to be,
	-- and reading it back off C0 is no good once the client has started editing C0.
	--
	-- Guns only: the swords animate these joints for their attacks and must keep them.
	-- The elbows are published the same way and for the same reason. Without them the
	-- client holds the forearm straight, which is the R6 arm all over again.
	if cfg and cfg.Type == "Gun" then
		character:SetAttribute("PoseRightC0", rightC0)
		character:SetAttribute("PoseLeftC0", leftC0)
		character:SetAttribute("PoseRightElbow", r.right.elbowC0 * bendCF(pose.elbow or 0))
		character:SetAttribute("PoseLeftElbow", r.left.elbowC0 * (leftBend or CFrame.identity))
		character:SetAttribute("PoseSupportOnWeapon", supportOnWeapon)
		character:SetAttribute("PoseWaist", bladedWaist(pose.blade))
	else
		character:SetAttribute("PoseRightC0", nil)
		character:SetAttribute("PoseLeftC0", nil)
		character:SetAttribute("PoseRightElbow", nil)
		character:SetAttribute("PoseLeftElbow", nil)
		character:SetAttribute("PoseSupportOnWeapon", nil)
		character:SetAttribute("PoseWaist", nil)
	end

	-- The grip is published rather than written straight onto the Tool, because writing it
	-- replicates instantly and the weapon would jump in the hand the moment the stance
	-- changed. StarterPlayerScripts.WeaponPoseHold eases the Tool's own Grip towards this.
	--
	-- The Tool still gets the carry grip once, as a sane baseline for anything that reads
	-- it without the client script running.
	if grip then
		character:SetAttribute("PoseGrip", grip)
		if tool and tool:IsA("Tool") and tool.Grip == CFrame.identity then
			tool.Grip = grip
		end
	else
		character:SetAttribute("PoseGrip", nil)
	end
end

-- The default Animate script keeps writing to these joints, so the pose is refreshed
-- on a slow tick while something is held. 10 Hz is invisible to the player and costs
-- nothing next to re-posing every frame.
local held: { [Player]: string } = {}

local function currentTool(character: Model): string?
	for _, c in ipairs(character:GetChildren()) do
		if c:IsA("Tool") then
			return c.Name
		end
	end
	return nil
end

local function watchCharacter(player: Player, character: Model)
	character:WaitForChild("UpperTorso", 10)

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			task.wait(0.15)
			held[player] = child.Name
			WeaponPose.Apply(character, child.Name)
		end
	end)

	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			task.wait(0.1)
			if not currentTool(character) then
				held[player] = nil
				WeaponPose.Clear(character)
			end
		end
	end)

	local existing = currentTool(character)
	if existing then
		held[player] = existing
		WeaponPose.Apply(character, existing)
	end
end

local function onPlayerAdded(player: Player)
	player.CharacterAdded:Connect(function(character)
		held[player] = nil
		task.spawn(watchCharacter, player, character)
	end)
	if player.Character then
		task.spawn(watchCharacter, player, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end
Players.PlayerRemoving:Connect(function(player)
	held[player] = nil
end)

-- Re-assert the pose against the Animate script.
task.spawn(function()
	while true do
		task.wait(0.1)
		for player, toolName in pairs(held) do
			local character = player.Character
			if character and currentTool(character) == toolName then
				WeaponPose.Apply(character, toolName)
			end
		end
	end
end)

return WeaponPose
