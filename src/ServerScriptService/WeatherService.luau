--!strict
-- Rolls the weather and blends between states.
--
-- Publishes what it picked onto workspace as attributes, so the AI and any client effect
-- read one shared source rather than each deciding for itself.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeatherConfig = require(ReplicatedStorage.WeatherConfig)

local WeatherService = {}

local current = WeatherConfig.States[1]
local previous = WeatherConfig.States[1]
local blend = 1            -- 0 = fully previous, 1 = fully current
local holdUntil = 0

local function lerp(a: number, b: number, t: number): number
	return a + (b - a) * t
end

--- Where the weather currently sits, blended. AmbienceService adds these on top of its own
--- time-of-day values, which is why they are OFFSETS rather than absolutes.
function WeatherService.Current()
	return {
		id = blend < 0.5 and previous.id or current.id,
		density = lerp(previous.density, current.density, blend),
		haze = lerp(previous.haze, current.haze, blend),
		glare = lerp(previous.glare, current.glare, blend),
		cloudCover = lerp(previous.cloudCover, current.cloudCover, blend),
		cloudDensity = lerp(previous.cloudDensity, current.cloudDensity, blend),
		sight = lerp(previous.sight, current.sight, blend),
	}
end

--- Force a state. Used for testing, and later for events that want a fixed sky.
function WeatherService.Set(id: string, instant: boolean?)
	previous = WeatherService.Current() :: any
	previous.density = previous.density
	current = WeatherConfig.Get(id)
	blend = instant and 1 or 0
	holdUntil = os.clock() + math.random(WeatherConfig.MIN_SECONDS, WeatherConfig.MAX_SECONDS)
	WeatherService.Publish()
end

-- Everything the rest of the game needs is published onto workspace, not kept in module
-- locals. `require` caches per Luau VM, so a second copy of this module has its own
-- `current` and `blend` -- state read through the module would then depend on WHICH copy
-- the reader happened to hold. Attributes are the one view everybody shares.
function WeatherService.Publish()
	local now = WeatherService.Current()
	workspace:SetAttribute(WeatherConfig.STATE_ATTRIBUTE, now.id)
	workspace:SetAttribute(WeatherConfig.SIGHT_ATTRIBUTE, now.sight)
	workspace:SetAttribute("WeatherDensity", now.density)
	workspace:SetAttribute("WeatherHaze", now.haze)
	workspace:SetAttribute("WeatherGlare", now.glare)
	workspace:SetAttribute("WeatherCloudCover", now.cloudCover)
	workspace:SetAttribute("WeatherCloudDensity", now.cloudDensity)
end

function WeatherService.Start()
	-- Same guard as AmbienceService: require caches per Luau VM, so a module that starts
	-- itself starts a second loop the moment another context requires it.
	if workspace:GetAttribute("WeatherRunning") then
		return
	end
	workspace:SetAttribute("WeatherRunning", true)

	WeatherService.Set("Clear", true)

	local accumulator = 0
	RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		local step = accumulator
		accumulator = 0

		if blend < 1 then
			blend = math.min(1, blend + step / WeatherConfig.TRANSITION)
			WeatherService.Publish()
		elseif os.clock() >= holdUntil then
			local nextState = WeatherConfig.Roll(current.id)
			previous = current
			current = nextState
			blend = 0
			holdUntil = os.clock() + math.random(WeatherConfig.MIN_SECONDS, WeatherConfig.MAX_SECONDS)
			print(("[Weather] %s -> %s"):format(previous.id, current.id))
		end
	end)

	print("[Weather] running; fog genuinely shortens how far NPCs can see")
end

WeatherService.Start()

return WeatherService
