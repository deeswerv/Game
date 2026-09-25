--!strict
-- Camera bob: the walk cycle you feel rather than watch.
--
-- Publishes an absolute angle to ViewKick every frame and nothing else. It never touches
-- camera.CFrame -- ViewKick.Consume is the only thing allowed to, and it folds bob in with
-- recoil and the one-shot impulses so the three can never fight over the same property.
-- That is not a style preference: this project has already lost a camera shake and a sprint
-- FOV boost to two scripts writing the same value, and the fix both times was one owner.
--
-- The shape is the standard figure-of-eight: roll runs at the step frequency (one sway per
-- footfall, alternating left and right) and pitch runs at twice that (the head dips on every
-- step, not every other one). Getting that 2:1 wrong is what makes bob read as a wobble.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ViewKick = require(ReplicatedStorage:WaitForChild("ViewKick"))

local player = Players.LocalPlayer

-- ------------------------------------------------------------------ tuning --

local Config = {
	-- Peak degrees at a full sprint. Deliberately small -- bob is meant to be felt at the
	-- edge of attention, and anything past about a degree starts to read as motion sickness.
	PITCH = 0.32,
	ROLL = 0.55,
	YAW = 0.18,

	-- Steps per second at the reference speed below. A walk is a little under two.
	STEP_HZ = 1.85,
	REFERENCE_SPEED = 16,      -- the walk speed the tuning above is calibrated against

	-- How fast the amplitude follows the player's actual speed. Low enough that stopping
	-- eases out over a few frames instead of snapping the camera straight.
	RAMP = 6,

	-- Aiming steadies the hands: bob drops to this fraction while ADS is held.
	ADS_SCALE = 0.18,

	-- Airborne has no footfalls, so there is nothing to bob to.
	AIR_SCALE = 0,
}

-- ----------------------------------------------------------------- state --

local phase = 0          -- radians through the step cycle; kept continuous across frames
local amplitude = 0      -- eased 0..1, so speed changes do not jump

local function currentHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

-- Reset on respawn rather than carrying a half-finished step into the new character, and
-- unwind whatever offset was on the camera.
player.CharacterAdded:Connect(function()
	phase = 0
	amplitude = 0
	ViewKick.SetBobOffset(0, 0, 0)
end)

RunService.RenderStepped:Connect(function(dt: number)
	local humanoid = currentHumanoid()
	if not humanoid or humanoid.Health <= 0 then
		amplitude = 0
		ViewKick.SetBobOffset(0, 0, 0)
		return
	end

	local root = humanoid.RootPart
	if not root then
		return
	end

	-- Horizontal speed only. Falling is not walking, and including Y would make a jump read
	-- as a very fast sprint.
	local velocity = root.AssemblyLinearVelocity
	local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude

	-- Measured intent, not input: reading the actual velocity means bob is correct when the
	-- player is slowed, knocked back, or standing on something that moves.
	local grounded = humanoid.FloorMaterial ~= Enum.Material.Air
	local target = grounded and math.clamp(speed / Config.REFERENCE_SPEED, 0, 1.35) or Config.AIR_SCALE

	if player:GetAttribute("ADS") == true then
		target *= Config.ADS_SCALE
	end

	amplitude += (target - amplitude) * math.clamp(Config.RAMP * dt, 0, 1)

	-- Advance the phase by how far the feet actually travelled, so the cycle stays locked to
	-- the stride instead of drifting out of step when the player speeds up or slows down.
	local stepRate = Config.STEP_HZ * math.clamp(speed / Config.REFERENCE_SPEED, 0, 1.6)
	phase = (phase + stepRate * dt * math.pi * 2) % (math.pi * 2)

	if amplitude < 0.001 then
		ViewKick.SetBobOffset(0, 0, 0)
		return
	end

	-- Roll at the step frequency, pitch at double it. Yaw gets a fraction of the roll so the
	-- motion traces a figure of eight rather than a flat side-to-side rock.
	local roll = math.sin(phase) * Config.ROLL * amplitude
	local pitch = math.cos(phase * 2) * Config.PITCH * amplitude
	local yaw = math.sin(phase) * Config.YAW * amplitude

	ViewKick.SetBobOffset(pitch, yaw, roll)
end)
