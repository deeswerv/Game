--!strict
-- Time of day, wind and cloud. The world was completely static: ClockTime pinned at 15.2,
-- GlobalWind at zero so no foliage moved, and no clouds at all -- which is most of why it
-- read as a diorama rather than a place.

local AmbienceConfig = {}

-- A full day in real minutes. Long enough that a firefight happens in one light, short
-- enough that a session sees more than one.
AmbienceConfig.DAY_MINUTES = 16

AmbienceConfig.START_CLOCK = 7.5

-- Night is atmospheric, not unplayable. These numbers were tuned by LOOKING: the first
-- pass (grade drop 0.30, atmosphere density 0.42) produced a genuinely pretty night in
-- which the foreground was solid black and nothing was readable. Values below are the
-- point where it still says night but you can still fight in it. This is a SHOOTER: if a player cannot see an enemy
-- at forty studs the cycle stops being ambience and starts being a handicap, so the ambient
-- floor is deliberately high.
AmbienceConfig.NIGHT_AMBIENT = Color3.fromRGB(104, 112, 140)
AmbienceConfig.DAY_AMBIENT = Color3.fromRGB(128, 128, 128)
AmbienceConfig.NIGHT_BRIGHTNESS = 1.85
AmbienceConfig.DAY_BRIGHTNESS = 2.2

AmbienceConfig.DAWN = 6.0
AmbienceConfig.DUSK = 18.0
AmbienceConfig.BLEND = 1.5        -- hours either side that cross-fade

-- A steady breeze with a slow wander, so foliage never loops visibly.
AmbienceConfig.WIND_BASE = Vector3.new(12, 0, 5)
AmbienceConfig.WIND_VARIANCE = 6
AmbienceConfig.WIND_PERIOD = 23


-- The place uses a STATIC Sky and a colour grade, and neither responds to ClockTime: set to
-- 22:00 the scene came out indistinguishable from noon. Night therefore has to be carried
-- by the grade rather than by the sun, and these are the offsets that do it.
AmbienceConfig.NIGHT_GRADE_DROP = 0.13       -- subtracted from the artist's Brightness
AmbienceConfig.NIGHT_GRADE_CONTRAST = 0.05
AmbienceConfig.NIGHT_TINT = Color3.fromRGB(150, 170, 225)
AmbienceConfig.NIGHT_TINT_STRENGTH = 0.40
AmbienceConfig.NIGHT_SATURATION = -0.15


-- The Sky is a fixed daytime skybox, so the grade alone barely moved it. Atmosphere DOES
-- tint and fog the sky itself, which is what actually sells dusk without swapping the sky
-- asset -- that would need a night skybox chosen deliberately rather than guessed at.
AmbienceConfig.NIGHT_ATMOSPHERE = {
	Density = 0.33,
	Offset = 0.15,
	Color = Color3.fromRGB(118, 132, 178),
	Decay = Color3.fromRGB(52, 62, 102),
	Haze = 1.9,
	Glare = 0.15,
}

AmbienceConfig.CLOUD_COVER = 0.52
AmbienceConfig.CLOUD_DENSITY = 0.62
AmbienceConfig.CLOUD_COLOUR = Color3.fromRGB(255, 255, 255)

--- 0 at full night, 1 at full day, blended across dawn and dusk.
function AmbienceConfig.Daylight(clock: number): number
	local b = AmbienceConfig.BLEND
	if clock >= AmbienceConfig.DAWN + b and clock <= AmbienceConfig.DUSK - b then
		return 1
	end
	if clock <= AmbienceConfig.DAWN - b or clock >= AmbienceConfig.DUSK + b then
		return 0
	end
	if clock < AmbienceConfig.DAWN + b then
		return math.clamp((clock - (AmbienceConfig.DAWN - b)) / (b * 2), 0, 1)
	end
	return math.clamp(((AmbienceConfig.DUSK + b) - clock) / (b * 2), 0, 1)
end

return AmbienceConfig
