--!strict
-- The third-person shooter camera: permanent shift lock, an over-the-shoulder framing
-- that reacts to what the player is doing, and the single place where anything is
-- allowed to shove the view.
--
-- Roblox only ships shift lock as a toggle the player has to hold, so the lock itself is
-- the usual custom version: lock the cursor, stop the Humanoid auto-rotating, and turn
-- the root part to the camera's yaw each frame.
--
-- The rest of this file exists because the stock camera sits far behind the character and
-- centres them in frame, which reads as an adventure game. A shooter wants the character
-- pushed off to one side and the camera close, so the crosshair -- not the avatar -- is
-- what the eye tracks.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local ViewKick = require(ReplicatedStorage:WaitForChild("ViewKick"))
local CombatFX = require(ReplicatedStorage:WaitForChild("CombatFX"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Framing per stance. X pushes the character left on screen, Y raises the eyeline.
-- Aiming pulls in and straightens up so the sights sit near the middle of the screen;
-- sprinting swings out and drops slightly, which is what sells the speed.
-- How far the character is pushed off the centre of the screen.
--
-- Bigger than it looks like it needs to be, and deliberately so: the weapon is held on
-- the character's right, in FRONT of them, and the camera is behind. Anything in front of
-- a body seen from behind is hidden by that body unless it clears the silhouette, and at
-- 1.95 the rifle was measured 100% occluded -- the player could not see their own gun at
-- all. Pushing the character further left opens the space the weapon lives in, which is
-- also how the reference footage frames it: character in the left third, weapon and
-- crosshair in the open right.
local OFFSET_HIP = Vector3.new(2.85, 0.45, 0)
local OFFSET_ADS = Vector3.new(1.55, 0.35, 0)
local OFFSET_SPRINT = Vector3.new(3.05, 0.20, 0)
-- Slide drops the camera and pulls it in, so the ground rushes past close to the lens.
local OFFSET_SLIDE = Vector3.new(2.35, -1.05, 0)

-- How fast the framing catches up, per second. Aiming has to be noticeably snappier than
-- coming out of it, or the weapon reaches the shoulder before the camera does.
local OFFSET_TO_ADS = 14
local OFFSET_FROM_ADS = 9

-- The zoom band. The place shipped with a 128-stud ceiling, so the player could sit far
-- enough out that their own character was a speck and the gun was unreadable.
--
-- The floor is not just taste. Occlusion mode Zoom pulls the camera in whenever anything
-- gets between it and the player, and standing next to a wall was dragging it to 4 studs,
-- which puts the character's shoulder across half the screen mid-fight. The occlusion
-- mode is switched to Invisicam below so the framing holds still and the wall fades
-- instead, but the floor stays as a second line of defence.
local ZOOM_MIN = 7
local ZOOM_MAX = 12
local ZOOM_DEFAULT = 10

-- Sprint.
-- Slide: sprint, then crouch. A committed burst of momentum you cannot steer out of.
--
-- Deliberately does NOT touch WalkSpeed. This script already owns that property and hands
-- it back to other systems by only ever writing the two values it recognises; a slide that
-- zeroed it would have to remember to give it back, and the one thing worse than no slide
-- is a player left frozen because a slide ended in a state nobody handled. The momentum
-- comes from driving velocity directly for the length of the slide instead, which expires
-- on its own whatever happens.
local SLIDE_SPEED = 46         -- studs/sec at the moment it starts
local SLIDE_TIME = 0.7         -- and how long it takes to bleed back to walking pace
local SLIDE_COOLDOWN = 0.85    -- before another is allowed, so it cannot be spammed

local SPRINT_MULTIPLIER = 1.5
local SPRINT_FOV_ADD = 8
local SPRINT_FOV_RATE = 6

local character: Model? = nil
local humanoid: Humanoid? = nil
local root: BasePart? = nil

local currentOffset = OFFSET_HIP
local sprintLatched = false   -- set by double-tapping W, cleared when W is released
local lastForwardTap = 0
local sprinting = false
local baseWalkSpeed = 16
local slideUntil = 0
local slideReadyAt = 0
local slideDir = Vector3.zero
local fovBoost = 0
local wasAirborne = false

-- The fastest the character was falling during the current descent.
--
-- Sampled while airborne rather than read at the moment of landing, because by the time
-- the Landed state fires the Humanoid has already arrested the fall and the velocity is
-- back to nearly zero -- so reading it there scored every landing, from a kerb hop to a
-- rooftop drop, as the weakest possible impact.
local peakFallSpeed = 0

-- Menus set this attribute so the player can actually click buttons.
local function menuIsOpen(): boolean
	return player:GetAttribute("UIOpen") == true
end

local function isAiming(): boolean
	return player:GetAttribute("ADS") == true
end

local function onCharacterAdded(char: Model)
	character = char
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	humanoid = hum
	root = char:WaitForChild("HumanoidRootPart") :: BasePart

	hum.AutoRotate = false
	hum.CameraOffset = OFFSET_HIP
	currentOffset = OFFSET_HIP
	baseWalkSpeed = hum.WalkSpeed > 0 and hum.WalkSpeed or 16

	sprinting = false
	sprintLatched = false
	fovBoost = 0
	wasAirborne = false
	player:SetAttribute("Sprinting", false)

	-- A shake left running through a death would otherwise still be decaying when the
	-- replacement character spawns, which looks like the new body is already hurt.
	ViewKick.Clear()

	-- Landing has to feel like weight arriving. Freefall to Landed is the only reliable
	-- edge for it; Humanoid.StateChanged fires for a lot of states that are not a landing.
	peakFallSpeed = 0

	hum.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Freefall then
			wasAirborne = true
		elseif new == Enum.HumanoidStateType.Landed and wasAirborne then
			wasAirborne = false
			-- Scale the thump by how hard the arrival actually was rather than kicking a
			-- fixed amount, so hopping a kerb does not look like a rooftop drop.
			local force = math.clamp(peakFallSpeed / 70, 0.25, 2)
			peakFallSpeed = 0
			ViewKick.Land(force)
			-- Dust as well as a camera dip, so the weight is visible from outside the
			-- player's own view too.
			if hum.RootPart then
				CombatFX.LandDust(hum.RootPart.Position - Vector3.new(0, 2.6, 0), force, char)
			end
		end
	end)
end

if player.Character then
	task.spawn(onCharacterAdded, player.Character)
end
player.CharacterAdded:Connect(onCharacterAdded)

-- ---------------------------------------------------------------------- zoom --

-- Clamped on the Player as well as in StarterPlayer, because a player who has already
-- scrolled all the way out keeps that distance across a rejoin.
player.CameraMinZoomDistance = ZOOM_MIN
player.CameraMaxZoomDistance = ZOOM_MAX

-- Occlusion is set to Invisicam on StarterPlayer, not here: a script cannot write
-- DevCameraOcclusionMode at runtime (it needs RobloxScript capability and throws), so the
-- property has to be authored on StarterPlayer instead. It fades whatever comes between
-- the camera and the player rather than shoving the camera through their back, which in a
-- shooter matters -- a camera that lunges forward every time you brush a doorframe moves
-- the crosshair's frame of reference mid-aim.

task.defer(function()
	-- Nudge the starting distance into the band. Setting both ends momentarily is the
	-- only way to move the stock camera's own zoom state from outside it.
	player.CameraMinZoomDistance = ZOOM_DEFAULT
	player.CameraMaxZoomDistance = ZOOM_DEFAULT
	task.wait(0.1)
	player.CameraMinZoomDistance = ZOOM_MIN
	player.CameraMaxZoomDistance = ZOOM_MAX
end)

-- -------------------------------------------------------------------- sprint --

-- Two ways in, on purpose.
--
-- Shift is the modern convention and what every reference shooter uses. Double-tapping W
-- was what this game already had, in a separate script that set WalkSpeed and FieldOfView
-- itself -- so the two were fighting over the same two properties, and whichever ran last
-- won. That script is disabled now and its input lives here instead, which removes the
-- conflict without taking away a control anyone was already using.
local DOUBLE_TAP_WINDOW = 0.4

-- Shift is POLLED, not listened for.
--
-- Roblox's own shift-lock feature binds LeftShift at CoreScript level, so InputBegan
-- receives it with gameProcessedEvent already true and the `if processed then return end`
-- guard below dropped it on the floor -- sprint simply never engaged. Measured with the key
-- physically down: IsKeyDown(LeftShift) true, character moving forwards at dot 1.000, UIOpen
-- false, ADS false, full health, and WalkSpeed still sat at 16.
--
-- StarterPlayer.EnableMouseLockOption is now false, which removes that consumer, but polling
-- the key state is immune to it either way and to anything else that ever claims Shift.
--
-- The guard that actually matters is the text box: a player typing in chat is not asking to
-- sprint, and that is the only thing `processed` was protecting against here.
local function sprintKeyDown(): boolean
	if UserInputService:GetFocusedTextBox() then
		return false
	end
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightShift)
end

-- Holding Alt frees the cursor without leaving shift lock.
--
-- The lock is permanent, which is right for fighting and wrong for everything on screen that
-- wants a click -- the PLAY diamond, the nav buttons -- because a cursor pinned to the centre
-- of the screen can only ever click the centre of the screen. Alt is the key other Roblox
-- shooters use for this, and it is otherwise unbound here. Only the cursor changes: the camera
-- framing, sprint and the character turning with the camera all carry on as normal, so letting
-- go drops you straight back into the fight. Polled, like Shift, so nothing that claims the key
-- first can swallow it.
local function cursorKeyDown(): boolean
	if UserInputService:GetFocusedTextBox() then
		return false
	end
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftAlt)
		or UserInputService:IsKeyDown(Enum.KeyCode.RightAlt)
end
local cursorFree = false

-- Crouch is POLLED with a rising-edge check, for exactly the reason Shift is (see above):
-- an InputBegan handler guarded by `processed` never saw the key, because something at
-- CoreScript level had already claimed it. Measured: the slide silently never fired.
local crouchWasDown = false

local function crouchKeyDown(): boolean
	if UserInputService:GetFocusedTextBox() then
		return false
	end
	return UserInputService:IsKeyDown(Enum.KeyCode.LeftControl)
		or UserInputService:IsKeyDown(Enum.KeyCode.C)
end

-- Crouch while sprinting. Grounded and actually moving, or it is not a slide.
local function beginSlide()
	local hum, rootPart = humanoid, root
	if not hum or not rootPart or hum.Health <= 0 then
		return
	end
	local now = os.clock()
	if now < slideReadyAt or not sprinting then
		return
	end
	local state = hum:GetState()
	if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
		return
	end
	local move = hum.MoveDirection
	if move.Magnitude < 0.1 then
		return
	end

	slideDir = move.Unit
	slideUntil = now + SLIDE_TIME
	slideReadyAt = slideUntil + SLIDE_COOLDOWN
	-- Reuse the landing impulse for the jolt as the player drops. It is the same event as
	-- far as the camera is concerned: weight arriving.
	ViewKick.Land(0.55)
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then
		return
	end
	if input.KeyCode == Enum.KeyCode.W then
		local now = os.clock()
		if now - lastForwardTap <= DOUBLE_TAP_WINDOW then
			sprintLatched = true
		end
		lastForwardTap = now
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.W then
		-- Letting go of forward ends a latched sprint; holding shift is unaffected.
		sprintLatched = false
	end
end)

-- Sprinting only counts while actually moving forward under your own power. Holding
-- shift while standing still, falling, or aiming should not widen the FOV.
local function wantsSprint(hum: Humanoid): boolean
	if not (sprintKeyDown() or sprintLatched) or menuIsOpen() or isAiming() then
		return false
	end
	if hum.Health <= 0 then
		return false
	end
	local move = hum.MoveDirection
	if move.Magnitude < 0.1 then
		return false
	end
	local rootPart = hum.RootPart
	if not rootPart then
		return false
	end
	-- Backpedalling at sprint speed looks wrong and plays wrong, so require the input to
	-- be broadly forward of where the character is facing.
	return move.Unit:Dot(rootPart.CFrame.LookVector) > 0.35
end

-- ------------------------------------------------------------------ per-frame --

RunService:BindToRenderStep("TacticalCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	camera = workspace.CurrentCamera
	if not camera then
		return
	end

	-- Everything that shoves the view -- firing, landing, taking a hit, recoil -- is
	-- applied here, in one place, after the stock camera module has written its CFrame for
	-- the frame. Consume returns the change since last frame rather than the total, so
	-- these pushes cancel out as they decay instead of walking the aim off target.
	local kick = ViewKick.Consume(dt)
	if kick ~= CFrame.identity then
		camera.CFrame = camera.CFrame * kick
	end

	if menuIsOpen() then
		-- Hand the cursor back while a menu is up, and let the character rest.
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		if not UserInputService.MouseIconEnabled then
			UserInputService.MouseIconEnabled = true
		end
		return
	end

	-- Published for anything that must not treat a click on the HUD as a trigger pull.
	local wantFree = cursorKeyDown()
	if wantFree ~= cursorFree then
		cursorFree = wantFree
		player:SetAttribute("CursorFree", cursorFree)
	end

	if cursorFree then
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.Default then
			UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		end
		if not UserInputService.MouseIconEnabled then
			UserInputService.MouseIconEnabled = true
		end
	else
		if UserInputService.MouseBehavior ~= Enum.MouseBehavior.LockCenter then
			UserInputService.MouseBehavior = Enum.MouseBehavior.LockCenter
		end

		-- The pointer is hidden entirely; WeaponController draws a centred white dot that
		-- acts as the reticle, so an OS cursor on top of it would just be noise.
		if UserInputService.MouseIconEnabled then
			UserInputService.MouseIconEnabled = false
		end
	end

	local hum, rootPart = humanoid, root
	if not hum or not rootPart or hum.Health <= 0 or not rootPart.Parent then
		return
	end

	-- Sample the descent while it is happening; see peakFallSpeed.
	local rootVel = rootPart.AssemblyLinearVelocity
	if rootVel.Y < 0 then
		peakFallSpeed = math.max(peakFallSpeed, -rootVel.Y)
	end

	-- ------------------------------------------------------------------ slide --

	-- Rising edge only: holding crouch must not re-trigger a slide every frame.
	local crouchDown = crouchKeyDown()
	if crouchDown and not crouchWasDown then
		beginSlide()
	end
	crouchWasDown = crouchDown

	local now = os.clock()
	local sliding = now < slideUntil
	if sliding then
		local state = hum:GetState()
		if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
			-- Jumping out of a slide cancels it rather than carrying the speed into the air.
			slideUntil = 0
			sliding = false
		else
			-- Bleed from the slide speed back to walking pace over the slide's length, and
			-- leave the vertical component alone so gravity still applies normally.
			local remaining = (slideUntil - now) / SLIDE_TIME
			local speed = baseWalkSpeed + (SLIDE_SPEED - baseWalkSpeed) * remaining
			local velocity = rootPart.AssemblyLinearVelocity
			rootPart.AssemblyLinearVelocity =
				Vector3.new(slideDir.X * speed, velocity.Y, slideDir.Z * speed)
		end
	end

	-- ------------------------------------------------------------ sprint state --

	local shouldSprint = wantsSprint(hum)
	if shouldSprint ~= sprinting then
		sprinting = shouldSprint
		player:SetAttribute("Sprinting", sprinting)
	end

	-- Only drive WalkSpeed between the two values this script owns. Anything else has
	-- been set by another system -- a slow effect, a stun -- and must be left alone.
	local sprintSpeed = baseWalkSpeed * SPRINT_MULTIPLIER
	local want = sprinting and sprintSpeed or baseWalkSpeed
	if hum.WalkSpeed ~= want and (hum.WalkSpeed == baseWalkSpeed or hum.WalkSpeed == sprintSpeed) then
		hum.WalkSpeed = want
	end

	-- ---------------------------------------------------------------- framing --

	local targetOffset
	if sliding then
		targetOffset = OFFSET_SLIDE
	elseif isAiming() then
		targetOffset = OFFSET_ADS
	elseif sprinting then
		targetOffset = OFFSET_SPRINT
	else
		targetOffset = OFFSET_HIP
	end

	local rate = isAiming() and OFFSET_TO_ADS or OFFSET_FROM_ADS
	currentOffset = currentOffset:Lerp(targetOffset, math.clamp(rate * dt, 0, 1))
	hum.CameraOffset = currentOffset

	-- The sprint FOV widen is PUBLISHED here, not applied.
	--
	-- Adding a delta to FieldOfView from this script did not survive: WeaponController lerps
	-- the camera towards an ABSOLUTE target every frame for aim-down-sights, so it dragged
	-- the widen straight back out again. Measured 70 degrees while sprinting where it should
	-- have read 78. Two owners for one property, and the one seeking an absolute always wins.
	--
	-- WeaponController owns FieldOfView; it folds this number into its own target.
	local wantBoost = sprinting and SPRINT_FOV_ADD or 0
	fovBoost += (wantBoost - fovBoost) * math.clamp(SPRINT_FOV_RATE * dt, 0, 1)
	player:SetAttribute("SprintFovAdd", fovBoost)

	hum.AutoRotate = false

	-- Yaw only: keep the character upright no matter where the camera is pitched.
	local look = camera.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.001 then
		return
	end

	rootPart.CFrame = CFrame.lookAt(rootPart.Position, rootPart.Position + flat.Unit)
end)
