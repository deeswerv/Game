-- Lighting: small, deliberate moves on the artist's baseline (AmbienceService captures these
-- at start and modulates day/night relative to them, so they stay the daytime look).
return function(ctx)
	local lighting = ctx.game:GetService("Lighting")

	-- Crisper shadows suit flat-shaded low poly: soft shadow edges read as blur, not light.
	lighting.ShadowSoftness = 0.2

	-- Bloom low enough that Neon -- muzzle flashes, tracers, kill bursts, crystals -- actually
	-- glows, and still well above anything a lit surface reaches in daylight.
	local bloom = lighting:FindFirstChild("Bloom")
	if bloom and bloom.ClassName == "BloomEffect" then
		bloom.Intensity = 0.75
		bloom.Threshold = 1.5
		bloom.Size = 22
	end

	-- A touch more shafting through the trees.
	local rays = lighting:FindFirstChild("SunRays")
	if rays and rays.ClassName == "SunRaysEffect" then
		rays.Intensity = 0.1
	end
	print("lighting tuned")
end
