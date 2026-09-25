--!strict
-- Drives the sky.
--
-- Server side so every client agrees what time it is -- a day/night cycle run locally
-- means two players in the same firefight see different light.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AmbienceConfig = require(ReplicatedStorage.AmbienceConfig)

local AmbienceService = {}

local clock = AmbienceConfig.START_CLOCK
local elapsed = 0
local UPDATE_INTERVAL = 0.25      -- four times a second is smooth; per-frame is waste

-- The place uses a STATIC Sky plus a colour grade, and neither responds to ClockTime: set
-- to 22:00 the scene came out indistinguishable from noon. Night is therefore carried by
-- the GRADE, modulated RELATIVE to whatever the artist set rather than replacing it. These
-- baselines are captured once so the artist's look is still the daytime look.
local grade = Lighting:FindFirstChild("Grade")
local baseBrightness = grade and grade.Brightness or 0
local baseContrast = grade and grade.Contrast or 0
local baseSaturation = grade and grade.Saturation or 0
local baseTint = grade and grade.TintColor or Color3.new(1, 1, 1)
local baseAmbient = Lighting.Ambient

-- Atmosphere is what actually darkens a fixed skybox, so its daytime values are captured
-- the same way and lerped toward the night set.
local atmos = Lighting:FindFirstChildOfClass("Atmosphere")
local baseAtmos = atmos and {
	Density = atmos.Density,
	Offset = atmos.Offset,
	Color = atmos.Color,
	Decay = atmos.Decay,
	Haze = atmos.Haze,
	Glare = atmos.Glare,
} or nil

local function ensureClouds()
	local terrain = workspace.Terrain
	local clouds = terrain:FindFirstChildOfClass("Clouds")
	if not clouds then
		clouds = Instance.new("Clouds")
		clouds.Parent = terrain
	end
	clouds.Cover = AmbienceConfig.CLOUD_COVER
	clouds.Density = AmbienceConfig.CLOUD_DENSITY
	clouds.Color = AmbienceConfig.CLOUD_COLOUR
	return clouds
end

--- Apply the look for a given hour. Public so the time can be set directly when testing
--- rather than waiting a quarter of an hour for dusk to come round.
function AmbienceService.Apply(hour: number)
	clock = hour % 24
	Lighting.ClockTime = clock

	local day = AmbienceConfig.Daylight(clock)
	Lighting.Brightness = AmbienceConfig.NIGHT_BRIGHTNESS
		+ (AmbienceConfig.DAY_BRIGHTNESS - AmbienceConfig.NIGHT_BRIGHTNESS) * day
	Lighting.OutdoorAmbient = AmbienceConfig.NIGHT_AMBIENT:Lerp(AmbienceConfig.DAY_AMBIENT, day)

	local night = 1 - day
	-- 0 at full day and full night, 1 halfway through dawn or dusk.
	local golden = 1 - math.abs(day * 2 - 1)
	Lighting.Ambient = baseAmbient:Lerp(AmbienceConfig.NIGHT_AMBIENT, night * 0.5)
	if grade then
		grade.Brightness = baseBrightness - AmbienceConfig.NIGHT_GRADE_DROP * night
		grade.Contrast = baseContrast + AmbienceConfig.NIGHT_GRADE_CONTRAST * night
		grade.Saturation = baseSaturation + AmbienceConfig.NIGHT_SATURATION * night + 0.08 * golden
		grade.TintColor = baseTint:Lerp(AmbienceConfig.NIGHT_TINT,
			night * AmbienceConfig.NIGHT_TINT_STRENGTH)
			:Lerp(AmbienceConfig.GOLDEN_TINT, golden * AmbienceConfig.GOLDEN_STRENGTH)
	end

	if atmos and baseAtmos then
		local n = AmbienceConfig.NIGHT_ATMOSPHERE
		atmos.Density = baseAtmos.Density + (n.Density - baseAtmos.Density) * night
		atmos.Offset = baseAtmos.Offset + (n.Offset - baseAtmos.Offset) * night
		atmos.Haze = baseAtmos.Haze + (n.Haze - baseAtmos.Haze) * night
		atmos.Glare = baseAtmos.Glare + (n.Glare - baseAtmos.Glare) * night
		atmos.Color = baseAtmos.Color:Lerp(n.Color, night)
			:Lerp(AmbienceConfig.GOLDEN_ATMOSPHERE, golden * AmbienceConfig.GOLDEN_STRENGTH)
		atmos.Decay = baseAtmos.Decay:Lerp(n.Decay, night)

		-- Weather rides ON TOP of the time of day, as offsets, so fog at midnight still
		-- looks like midnight rather than replacing the night look wholesale.
		-- Read from the published attributes, never by requiring WeatherService: a second
		-- copy of that module would have its own blend state and this would silently track
		-- the wrong one.
		local function attr(name, fallback)
			local v = workspace:GetAttribute(name)
			return type(v) == "number" and v or fallback
		end
		atmos.Density += attr("WeatherDensity", 0)
		atmos.Haze += attr("WeatherHaze", 0)
		atmos.Glare += attr("WeatherGlare", 0)
		local clouds = workspace.Terrain:FindFirstChildOfClass("Clouds")
		if clouds then
			clouds.Cover = attr("WeatherCloudCover", AmbienceConfig.CLOUD_COVER)
			clouds.Density = attr("WeatherCloudDensity", AmbienceConfig.CLOUD_DENSITY)
		end
	end
end

--- Hold the clock where it is. Needed to look at a given hour at all: the cycle runs a
--- game-hour every 40 real seconds, so setting 22:00 and then taking a screenshot two tool
--- calls later shows breakfast time, which is exactly the mistake that made the first
--- night check meaningless.
function AmbienceService.SetPaused(value: boolean)
	-- Kept on Lighting rather than in a local, so pausing works no matter which copy of
	-- this module you are holding. See the guard in Start for why that matters.
	Lighting:SetAttribute("AmbiencePaused", value == true)
end

function AmbienceService.IsPaused(): boolean
	return Lighting:GetAttribute("AmbiencePaused") == true
end

function AmbienceService.GetClock(): number
	return clock
end

function AmbienceService.Start()
	-- Guard on a property of the datamodel, not a module-local flag. `require` caches per
	-- Luau VM, so a module that starts itself will start a SECOND loop the moment anything
	-- in another context requires it -- a test script, the command bar, a plugin. Two loops
	-- then fight over Lighting and the one you are holding is not the one you can see.
	if Lighting:GetAttribute("AmbienceRunning") then
		return
	end
	Lighting:SetAttribute("AmbienceRunning", true)

	ensureClouds()
	AmbienceService.Apply(AmbienceConfig.START_CLOCK)

	local accumulator = 0
	local hoursPerSecond = 24 / (AmbienceConfig.DAY_MINUTES * 60)

	RunService.Heartbeat:Connect(function(dt)
		elapsed += dt
		accumulator += dt
		if accumulator < UPDATE_INTERVAL then
			return
		end
		if Lighting:GetAttribute("AmbiencePaused") == true then
			accumulator = 0
			return
		end
		AmbienceService.Apply(clock + accumulator * hoursPerSecond)
		accumulator = 0

		-- Wind wanders on a slow sine so the foliage never settles into a visible loop.
		local t = elapsed * (math.pi * 2 / AmbienceConfig.WIND_PERIOD)
		workspace.GlobalWind = AmbienceConfig.WIND_BASE
			+ Vector3.new(math.sin(t) * AmbienceConfig.WIND_VARIANCE, 0,
				math.cos(t * 0.7) * AmbienceConfig.WIND_VARIANCE)
	end)

	print(("[Ambience] day/night running, %d real minutes per day; wind and cloud on"):format(
		AmbienceConfig.DAY_MINUTES))
end

AmbienceService.Start()

return AmbienceService
