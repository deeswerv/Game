--!strict
-- The airstrike's jet: a low-poly strike fighter built from parts, nose down -Z, up +Y,
-- centred on its fuselage. Anchored and out of the way of everything (no collision, no
-- queries), because it is only ever flown by hand, client side, by Streaks.client.
--
-- Wings and fins are WedgeParts. A wedge's cross-section is a right triangle in its own Y-Z
-- plane: the square corner at the bottom-back, the slope rising from the front-bottom to the
-- back-top. Stood up as it is, that is a tail fin; turned a quarter about Z it lies flat and
-- is a swept wing, the full chord against the fuselage and the tip at the trailing edge.

local StrikeJet = {}

local GREY = Color3.fromRGB(86, 92, 104)
local DARK = Color3.fromRGB(42, 46, 54)
local STRIPE = Color3.fromRGB(255, 122, 58)
local GLASS = Color3.fromRGB(44, 70, 104)

local function piece(model: Model, class: string, name: string, size: Vector3, cf: CFrame, colour: Color3,
	material: Enum.Material?, shape: Enum.PartType?): BasePart
	local p = Instance.new(class) :: BasePart
	p.Name = name
	if shape and p:IsA("Part") then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

--- A new jet in `parent`, at the origin. Its PrimaryPart is the fuselage.
function StrikeJet.Build(parent: Instance): Model
	local jet = Instance.new("Model")
	jet.Name = "StrikeJet"

	-- Fuselage, tapering to the nose in steps, and the canopy over the front of it.
	local body = piece(jet, "Part", "Fuselage", Vector3.new(3.2, 2.8, 20), CFrame.new(0, 0, 0), GREY)
	piece(jet, "Part", "Spine", Vector3.new(2, 0.8, 14), CFrame.new(0, 1.7, 2), GREY)
	piece(jet, "Part", "Nose", Vector3.new(2.5, 2.2, 5), CFrame.new(0, -0.15, -12.4), GREY)
	piece(jet, "Part", "NoseTip", Vector3.new(1.4, 1.2, 3), CFrame.new(0, -0.3, -16.2), DARK)
	piece(jet, "Part", "Probe", Vector3.new(0.25, 0.25, 2.4), CFrame.new(0, -0.3, -18.8), DARK)
	piece(jet, "Part", "Canopy", Vector3.new(1.8, 1.2, 4.6), CFrame.new(0, 1.85, -7.6), GLASS,
		Enum.Material.Glass)
	-- Intakes either side of the cockpit.
	for _, s in ipairs({ -1, 1 }) do
		piece(jet, "Part", "Intake", Vector3.new(1, 1.8, 5), CFrame.new(s * 2.05, -0.3, -3.5), DARK)
	end

	-- Swept wings: span 8 out from the fuselage, a 10-stud root chord, the tip at the back.
	local span, chord = 8, 10
	for _, s in ipairs({ -1, 1 }) do
		piece(jet, "WedgePart", "Wing", Vector3.new(0.5, span, chord),
			CFrame.new(s * (1.6 + span / 2), -0.35, 2.5) * CFrame.Angles(0, 0, -s * math.rad(90)), GREY)
		-- A stripe along the wingtip, and a missile under each wing.
		piece(jet, "Part", "WingTip", Vector3.new(0.6, 0.55, 2.2), CFrame.new(s * (1.6 + span), -0.35, 6.4), STRIPE)
		piece(jet, "Part", "Missile", Vector3.new(0.5, 0.5, 5), CFrame.new(s * 4.6, -1, 3), DARK,
			nil, Enum.PartType.Block)
		piece(jet, "Part", "Seeker", Vector3.new(0.5, 0.5, 0.5), CFrame.new(s * 4.6, -1, 0.3), STRIPE,
			nil, Enum.PartType.Ball)
		-- Tailplanes, the same shape smaller.
		piece(jet, "WedgePart", "Tailplane", Vector3.new(0.35, 3.6, 4),
			CFrame.new(s * (1.6 + 1.8), -0.2, 9) * CFrame.Angles(0, 0, -s * math.rad(90)), GREY)
		-- Twin fins, canted out.
		piece(jet, "WedgePart", "Fin", Vector3.new(0.35, 4, 4.6),
			CFrame.new(s * 1.1, 3.2, 8.2) * CFrame.Angles(0, 0, s * math.rad(-18)), DARK)
	end

	-- The engine's glow out of the back.
	local nozzle = piece(jet, "Part", "Nozzle", Vector3.new(2.4, 2.4, 1.2), CFrame.new(0, 0, 10.5), DARK)
	local flame = piece(jet, "Part", "Afterburner", Vector3.new(2.2, 2.2, 2.2), CFrame.new(0, 0, 11.8),
		Color3.fromRGB(255, 166, 74), Enum.Material.Neon, Enum.PartType.Ball)
	flame.Transparency = 0.15
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = 30
	light.Brightness = 3
	light.Parent = flame
	nozzle.Transparency = 0

	jet.PrimaryPart = body
	jet.Parent = parent
	return jet
end

return StrikeJet
