-- Graphics: the renderer and the light, a step up from the artist's baseline.
--
--   * Future lighting: lamps, lanterns, furnace mouths and neon actually light the world
--     around them (with Shadow Map they only tinted the part itself), and the city at night
--     becomes the point of the day/night cycle rather than a darker copy of noon. Roblox scales
--     it down on devices that cannot afford it, so nobody loses frames for it.
--   * The sky lights the scene: environment diffuse and specular at full, so shade has colour
--     in it instead of grey, and glass and metal catch the sky.
--   * A crisper, brighter, more saturated day -- the references are bright, clean and
--     colourful -- with the haze pulled back so far buildings keep their colour.
-- AmbienceService captures these as the daytime look and runs the day/night cycle from them.
return function(ctx)
	local lighting = ctx.game:GetService("Lighting")
	local Enum = ctx.roblox.Enum

	lighting.Technology = Enum.Technology.Future
	lighting.EnvironmentDiffuseScale = 1
	lighting.EnvironmentSpecularScale = 1
	lighting.ShadowSoftness = 0.15
	lighting.ExposureCompensation = 0.12

	local atmosphere = lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		-- Clear air, like the reference streets: the skyline keeps its colour at a distance.
		atmosphere.Density = 0.26
		atmosphere.Offset = 0.2
		atmosphere.Haze = 1
		atmosphere.Glare = 0.4
	end

	local grade = lighting:FindFirstChild("Grade")
	if grade and grade.ClassName == "ColorCorrectionEffect" then
		grade.Contrast = 0.18
		grade.Saturation = 0.26
	end

	-- Future makes lit things brighter, so the bloom comes down a little to keep neon from
	-- blowing out while still glowing.
	local bloom = lighting:FindFirstChild("Bloom")
	if bloom and bloom.ClassName == "BloomEffect" then
		bloom.Intensity = 0.6
		bloom.Threshold = 1.7
		bloom.Size = 24
	end
	print("graphics: Future lighting, sky-lit shade, crisper day")
end
