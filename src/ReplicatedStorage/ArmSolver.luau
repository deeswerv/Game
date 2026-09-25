--!strict
-- One place that knows how an arm on this rig reaches a point.
--
-- R6 had a single joint between torso and hand, so "put the hand there" was one shoulder
-- rotation, and every system that needed it worked that out inline. R15 has three joints,
-- and a shoulder rotation on its own no longer says where the hand ends up -- that depends
-- on the elbow as well.
--
-- Which is exactly what broke the reload: it kept rotating the shoulder the R6 way while
-- the weapon pose held the elbow bent 68 degrees underneath it, and the hand (with the
-- rifle welded to it) swung up and back into the character's head -- measured at 0.29
-- studs from the head centre, well inside it.
--
-- So the maths lives here once, and both ServerScriptService.WeaponPose and
-- ReplicatedStorage.ReloadAnimator ask this module instead of each keeping their own copy.

local StarterPlayer = game:GetService("StarterPlayer")

local ArmSolver = {}

-- The frame the angles in WeaponPose.POSES and ReloadAnimator were authored against. R6's
-- shoulder sat a quarter turn about Y; R15's sits square with the torso. Conjugating
-- through this reproduces the original arm position exactly, so none of those tuned
-- numbers had to be measured again.
local R6_AXES = {
	Right = CFrame.Angles(0, math.pi / 2, 0),
	Left = CFrame.Angles(0, -math.pi / 2, 0),
}

export type SideRig = {
	shoulderC0: CFrame,   -- the joint's built C0, and the pose's starting point
	shoulderPos: Vector3, -- the shoulder pivot, in UpperTorso space
	jointAxes: CFrame,    -- rotation of the above; world rotations conjugate through this
	elbowC0: CFrame,      -- the elbow's built C0, which a bend is applied on top of
	wristC0: CFrame,      -- held at rest, so the chain below the elbow stays rigid
	upper: CFrame,        -- shoulder pivot -> elbow pivot
	fore: CFrame,         -- elbow pivot -> hand origin
	tail: CFrame,         -- everything below the shoulder, elbow straight
	restHand: Vector3,    -- where the hand sits with no pose applied, in UpperTorso space
	reach: number,        -- shoulder to hand, elbow straight: the furthest it can go
	convert: CFrame,      -- carries an R6-authored angle into this rig's shoulder frame
}

local rig: { right: SideRig, left: SideRig }? = nil

local function measureSide(source: Instance, side: string): SideRig?
	local upperArm = source:FindFirstChild(side .. "UpperArm")
	local lowerArm = source:FindFirstChild(side .. "LowerArm")
	local hand = source:FindFirstChild(side .. "Hand")
	if not (upperArm and lowerArm and hand) then
		return nil
	end
	local shoulder = upperArm:FindFirstChild(side .. "Shoulder") :: Motor6D?
	local elbow = lowerArm:FindFirstChild(side .. "Elbow") :: Motor6D?
	local wrist = hand:FindFirstChild(side .. "Wrist") :: Motor6D?
	if not (shoulder and elbow and wrist) then
		return nil
	end

	local upper = shoulder.C1:Inverse() * elbow.C0
	local fore = elbow.C1:Inverse() * wrist.C0 * wrist.C1:Inverse()
	local tail = upper * fore
	local restHand = (shoulder.C0 * tail).Position

	return {
		shoulderC0 = shoulder.C0,
		shoulderPos = shoulder.C0.Position,
		jointAxes = shoulder.C0.Rotation,
		elbowC0 = elbow.C0,
		wristC0 = wrist.C0,
		upper = upper,
		fore = fore,
		tail = tail,
		restHand = restHand,
		reach = (restHand - shoulder.C0.Position).Magnitude,
		convert = shoulder.C0.Rotation:Inverse() * R6_AXES[side],
	}
end

-- Measured off StarterPlayer.StarterCharacter, never off a live character: the avatar body
-- is locked, so that model IS every player's rig, and a live one may already be posed --
-- capturing a posed C0 as "rest" would bake the pose in permanently.
function ArmSolver.Rig()
	if rig then
		return rig
	end
	local source = StarterPlayer:FindFirstChild("StarterCharacter")
	if not source then
		return nil
	end
	local right = measureSide(source, "Right")
	local left = measureSide(source, "Left")
	if right and left then
		rig = { right = right, left = left }
	end
	return rig
end

-- An angle authored against R6's shoulder frame, expressed in this rig's.
function ArmSolver.Authored(side: SideRig, cf: CFrame): CFrame
	return side.convert * cf * side.convert:Inverse()
end

-- The elbow folds about its own X axis, positive carrying the hand forwards. Measured
-- rather than assumed: bending about X shortens the arm exactly as the law of cosines says
-- a hinge must, and both arms fold the same way.
function ArmSolver.Bend(theta: number): CFrame
	return CFrame.Angles(theta, 0, 0)
end

-- Where the hand sits relative to the shoulder pivot, in UpperTorso space, at a bend.
function ArmSolver.ArmVector(side: SideRig, theta: number): Vector3
	return side.jointAxes * (side.upper * ArmSolver.Bend(theta) * side.fore).Position
end

local MAX_BEND = math.rad(135)

-- The bend that makes the arm exactly `want` long. Reach falls off monotonically as the
-- elbow closes, so bisection is simple and exact enough, and this runs on a pose change
-- rather than every frame.
function ArmSolver.BendForReach(side: SideRig, want: number): number
	if want >= ArmSolver.ArmVector(side, 0).Magnitude then
		return 0
	end
	if want <= ArmSolver.ArmVector(side, MAX_BEND).Magnitude then
		return MAX_BEND
	end
	local lo, hi = 0, MAX_BEND
	for _ = 1, 24 do
		local mid = (lo + hi) * 0.5
		if ArmSolver.ArmVector(side, mid).Magnitude > want then
			lo = mid
		else
			hi = mid
		end
	end
	return (lo + hi) * 0.5
end

-- The shortest rotation carrying `from` onto `to`.
function ArmSolver.RotationBetween(from: Vector3, to: Vector3): CFrame
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

-- Put the hand AT `target` (a point in UpperTorso space): bend the elbow until the arm is
-- exactly the right length, then swing the shoulder so it points there.
--
-- `slack` keeps the arm slightly short of locking out. A real arm keeps a bend, and one
-- solved to exact full stretch has no give left either -- the hand pops off whatever it
-- was holding the moment that thing moves.
--
-- Returns the shoulder and elbow C0 values to write, or nil if the target is degenerate.
function ArmSolver.SolveTo(side: SideRig, target: Vector3, slack: number?): (CFrame?, CFrame?)
	local desired = target - side.shoulderPos
	local distance = desired.Magnitude
	if distance < 1e-3 then
		return nil, nil
	end
	local usable = side.reach * (slack or 1)
	local theta = ArmSolver.BendForReach(side, math.min(distance, usable))
	local M = ArmSolver.RotationBetween(ArmSolver.ArmVector(side, theta), desired)
	return side.shoulderC0 * (side.jointAxes:Inverse() * M * side.jointAxes),
		side.elbowC0 * ArmSolver.Bend(theta)
end

return ArmSolver
