--!strict
-- Weather, with teeth.
--
-- Atmosphere here is not decoration: `sight` is a real multiplier on how far an NPC can
-- notice you, applied to AggroRange. Fog that looks thick but changes nothing is a filter;
-- fog that hides you from a Marksman is a tactic. It cuts both ways -- you cannot see them
-- either -- which is what keeps it fair rather than a handicap.
--
-- Layered ON TOP of the day/night cycle: these are offsets the AmbienceService applies
-- after its own time-of-day pass, so weather at midnight still looks like midnight.

local WeatherConfig = {}

WeatherConfig.MIN_SECONDS = 150      -- how long a state lasts, at least
WeatherConfig.MAX_SECONDS = 420
WeatherConfig.TRANSITION = 12        -- seconds to blend between states

-- The attribute clients and the AI read.
WeatherConfig.STATE_ATTRIBUTE = "Weather"
WeatherConfig.SIGHT_ATTRIBUTE = "WeatherSight"

WeatherConfig.States = {
	{
		id = "Clear",
		weight = 46,
		sight = 1.0,
		density = 0.00, haze = 0.0, glare = 0.0,
		cloudCover = 0.45, cloudDensity = 0.55,
	},
	{
		id = "Overcast",
		weight = 28,
		sight = 0.92,
		density = 0.06, haze = 0.5, glare = -0.05,
		cloudCover = 0.88, cloudDensity = 0.85,
	},
	{
		id = "Fog",
		weight = 14,
		-- The headline one: enemies notice you at little over half their usual range.
		sight = 0.55,
		density = 0.24, haze = 2.4, glare = -0.1,
		cloudCover = 0.72, cloudDensity = 0.7,
	},
	{
		id = "Rain",
		weight = 12,
		sight = 0.78,
		density = 0.14, haze = 1.3, glare = -0.15,
		cloudCover = 0.95, cloudDensity = 0.95,
	},
}

function WeatherConfig.Get(id: string)
	for _, s in ipairs(WeatherConfig.States) do
		if s.id == id then
			return s
		end
	end
	return WeatherConfig.States[1]
end

--- Pick a state by weight, never the one already running -- weather that can roll the same
--- state twice reads as weather that never changes.
function WeatherConfig.Roll(currentId: string?)
	local total = 0
	for _, s in ipairs(WeatherConfig.States) do
		if s.id ~= currentId then
			total += s.weight
		end
	end
	local roll = math.random() * total
	local floor = 0
	for _, s in ipairs(WeatherConfig.States) do
		if s.id ~= currentId then
			floor += s.weight
			if roll <= floor then
				return s
			end
		end
	end
	return WeatherConfig.States[1]
end

return WeatherConfig
