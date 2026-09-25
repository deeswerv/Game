--!strict
-- Life in the air: dust drifting through the light by day, fireflies after dark.
--
-- One emitter on one invisible part that follows the camera around, so the air near the
-- player is never empty and nothing is placed in the map. It reads the clock AmbienceService
-- replicates on Lighting and crossfades between the two looks through dusk and dawn.
--
-- Local only, uncollidable, unqueryable, and repositioned four times a second rather than
-- every frame -- a cloud of motes forty studs across does not need to track the camera
-- exactly, it just needs to be where the player is.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local BOX = Vector3.new(70, 22, 70)
local STEP = 0.25

local holder = Instance.new("Part")
holder.Name = "AtmosphereMotes"
holder.Size = BOX
holder.Transparency = 1
holder.Anchored = true
holder.CanCollide = false
holder.CanQuery = false
holder.CanTouch = false
holder.CastShadow = false
holder.Parent = workspace.CurrentCamera or workspace

local motes = Instance.new("ParticleEmitter")
motes.Name = "Motes"
motes.Shape = Enum.ParticleEmitterShape.Box
motes.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
motes.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
motes.Lifetime = NumberRange.new(4, 7)
motes.Speed = NumberRange.new(0.2, 0.9)
motes.SpreadAngle = Vector2.new(180, 180)
motes.RotSpeed = NumberRange.new(-20, 20)
motes.Acceleration = Vector3.new(0, 0.12, 0)
motes.Drag = 0.4
motes.LightInfluence = 0
motes.Parent = holder

-- The two looks. Night flickers in and out; day is a faint, slow shimmer.
local function applyNight()
	motes.Color = ColorSequence.new(Color3.fromRGB(214, 255, 120), Color3.fromRGB(255, 226, 90))
	motes.LightEmission = 1
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.2, 0.22),
		NumberSequenceKeypoint.new(0.5, 0.12),
		NumberSequenceKeypoint.new(0.8, 0.24),
		NumberSequenceKeypoint.new(1, 0),
	})
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.2, 0.05),
		NumberSequenceKeypoint.new(0.5, 0.6),
		NumberSequenceKeypoint.new(0.8, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
end

local function applyDay()
	motes.Color = ColorSequence.new(Color3.fromRGB(255, 250, 235))
	motes.LightEmission = 0.4
	motes.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.3, 0.1),
		NumberSequenceKeypoint.new(1, 0),
	})
	motes.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.3, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
end

-- Matches AmbienceConfig's dawn and dusk.
local function isNight(clock: number): boolean
	return clock < 6 or clock > 18.5
end

local night: boolean? = nil
local accumulator = 0

RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < STEP then
		return
	end
	accumulator = 0

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if holder.Parent ~= camera then
		holder.Parent = camera
	end
	holder.CFrame = CFrame.new(camera.CFrame.Position)

	local nowNight = isNight(Lighting.ClockTime)
	if nowNight ~= night then
		night = nowNight
		if nowNight then
			applyNight()
			motes.Rate = 9
		else
			applyDay()
			motes.Rate = 5
		end
	end
end)
