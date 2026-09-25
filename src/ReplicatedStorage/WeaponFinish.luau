--!strict
-- The authored finishes, read out of the .glb sources the weapons were exported from.
--
-- Every weapon in "Gun Models" is painted from the same small material vocabulary --
-- ParkerizedSteel, InsetBlack, BrightSteel, Polymer, PolymerFDE, OpticGlass, Walnut,
-- Rubber. The special-camo exports are the SAME geometry with only those materials
-- repainted. So a camo does not need its own mesh: it is a material -> finish map, and
-- it applies to every weapon we have and every weapon we add later.
--
-- Parts are matched to a material by their imported colour rather than by a table of
-- part names, so a new weapon from the same exporter needs no work here at all.

local WeaponFinish = {}

local function c3(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

-- The factory finish, straight off the exporter.
WeaponFinish.Stock = {
	ParkerizedSteel = { color = c3(107, 112, 121), metal = 0.38, rough = 0.44, alpha = 1.00 },
	InsetBlack      = { color = c3(14, 15, 17),    metal = 0.20, rough = 0.60, alpha = 1.00 },
	BrightSteel     = { color = c3(154, 161, 169), metal = 0.40, rough = 0.28, alpha = 1.00 },
	Polymer         = { color = c3(51, 54, 59),    metal = 0.04, rough = 0.72, alpha = 1.00 },
	PolymerFDE      = { color = c3(74, 69, 61),    metal = 0.03, rough = 0.78, alpha = 1.00 },
	OpticGlass      = { color = c3(42, 74, 85),    metal = 0.25, rough = 0.08, alpha = 0.72 },
	Walnut          = { color = c3(107, 67, 38),   metal = 0.00, rough = 0.55, alpha = 1.00 },
	Rubber          = { color = c3(25, 26, 28),    metal = 0.00, rough = 0.95, alpha = 1.00 },
}

-- Special camos. Each is that same vocabulary repainted. `glow` is the emissive the
-- artist authored; reactive camos scale it with the player's streak.
WeaponFinish.Camos = {
	Gold = {
		ParkerizedSteel = { color = c3(216, 165, 58),  metal = 0.40, rough = 0.24, alpha = 1.00 },
		InsetBlack      = { color = c3(109, 79, 20),   metal = 0.30, rough = 0.42, alpha = 1.00 },
		BrightSteel     = { color = c3(246, 221, 147), metal = 0.40, rough = 0.16, alpha = 1.00 },
		Polymer         = { color = c3(236, 228, 210), metal = 0.06, rough = 0.52, alpha = 1.00 },
		PolymerFDE      = { color = c3(244, 237, 221), metal = 0.06, rough = 0.50, alpha = 1.00 },
		OpticGlass      = { color = c3(107, 85, 24),   metal = 0.30, rough = 0.08, alpha = 0.72 },
		Walnut          = { color = c3(201, 146, 43),  metal = 0.30, rough = 0.34, alpha = 1.00 },
		Rubber          = { color = c3(185, 140, 44),  metal = 0.10, rough = 0.72, alpha = 1.00 },
	},
	Diamond = {
		ParkerizedSteel = { color = c3(214, 227, 240), metal = 0.34, rough = 0.10, alpha = 1.00, glow = c3(29, 42, 58),  glowStrength = 0.35 },
		InsetBlack      = { color = c3(127, 149, 173), metal = 0.30, rough = 0.12, alpha = 1.00, glow = c3(47, 74, 102), glowStrength = 0.50 },
		BrightSteel     = { color = c3(255, 255, 255), metal = 0.34, rough = 0.05, alpha = 1.00, glow = c3(43, 61, 82),  glowStrength = 0.45 },
		Polymer         = { color = c3(232, 241, 251), metal = 0.14, rough = 0.16, alpha = 1.00, glow = c3(22, 34, 47),  glowStrength = 0.30 },
		PolymerFDE      = { color = c3(244, 249, 255), metal = 0.14, rough = 0.14, alpha = 1.00, glow = c3(22, 34, 47),  glowStrength = 0.30 },
		OpticGlass      = { color = c3(159, 200, 221), metal = 0.30, rough = 0.04, alpha = 0.72 },
		-- The shotgun's woodwork is not in the authored set; ice it over to match.
		Walnut          = { color = c3(206, 224, 240), metal = 0.20, rough = 0.14, alpha = 1.00, glow = c3(29, 42, 58),  glowStrength = 0.30 },
		Rubber          = { color = c3(191, 206, 221), metal = 0.10, rough = 0.30, alpha = 1.00 },
	},
	Ronin = {
		ParkerizedSteel = { color = c3(34, 36, 42),    metal = 0.40, rough = 0.36, alpha = 1.00 },
		InsetBlack      = { color = c3(44, 77, 57),    metal = 0.25, rough = 0.35, alpha = 1.00, glow = c3(98, 252, 170), glowStrength = 1.06 },
		BrightSteel     = { color = c3(126, 142, 132), metal = 0.40, rough = 0.24, alpha = 1.00 },
		Polymer         = { color = c3(23, 24, 27),    metal = 0.05, rough = 0.68, alpha = 1.00 },
		PolymerFDE      = { color = c3(27, 29, 32),    metal = 0.05, rough = 0.66, alpha = 1.00 },
		OpticGlass      = { color = c3(18, 48, 68),    metal = 0.30, rough = 0.06, alpha = 0.72, glow = c3(56, 226, 143), glowStrength = 0.78 },
		Walnut          = { color = c3(38, 33, 28),    metal = 0.05, rough = 0.60, alpha = 1.00 },
		Rubber          = { color = c3(16, 17, 19),    metal = 0.00, rough = 0.94, alpha = 1.00 },
	},
	-- Dark Matter. Read straight out of CompactCarbine_DarkMatterVFX.glb rather than matched
	-- by eye: colours converted from glTF's linear space to sRGB, and metal/rough taken from
	-- the material's own PBR factors.
	--
	-- Which stock material each one replaces was DERIVED, not guessed. All 132 parts of the
	-- Gold export exist in the Dark Matter export with the same names, so comparing the two
	-- files part by part gives the mapping unambiguously:
	--
	--   ParkerizedSteel -> DM_Obsidian (56 parts)   InsetBlack -> DM_Inset (33)
	--   BrightSteel -> DM_Gunmetal (19)             Rubber -> DM_Rubber (12)
	--   Polymer and PolymerFDE -> DM_PolymerDark (11)
	--
	-- One part in the export is InsetBlack -> DM_Energy, an emissive violet. A finish maps by
	-- material rather than per part, so that single part reads as plain inset here and its
	-- glow is the one thing lost in the translation.
	DarkMatter = {
		ParkerizedSteel = { color = c3(12, 13, 19),    metal = 0.62, rough = 0.34, alpha = 1.00 },
		InsetBlack      = { color = c3(9, 10, 18),     metal = 0.25, rough = 0.55, alpha = 1.00 },
		BrightSteel     = { color = c3(25, 27, 38),    metal = 0.78, rough = 0.20, alpha = 1.00 },
		Polymer         = { color = c3(15, 16, 23),    metal = 0.10, rough = 0.52, alpha = 1.00 },
		PolymerFDE      = { color = c3(15, 16, 23),    metal = 0.10, rough = 0.52, alpha = 1.00 },
		Rubber          = { color = c3(8, 8, 12),      metal = 0.00, rough = 0.92, alpha = 1.00 },
		-- Not in the authored set: this gun has no glass or woodwork. Authored to match so the
		-- finish still works on the optics and on the shotgun, the same way Diamond ices over
		-- woodwork it was never given.
		OpticGlass      = { color = c3(24, 14, 52),    metal = 0.30, rough = 0.06, alpha = 0.72, glow = c3(164, 52, 234), glowStrength = 0.85 },
		Walnut          = { color = c3(16, 14, 22),    metal = 0.05, rough = 0.60, alpha = 1.00 },
	},
}

-- ------------------------------------------------------------------ classifying --

-- Nearest stock colour wins. The eight stock colours are far apart (the closest pair
-- is 19/255 away) and the importer writes them exactly, so in practice this is an
-- exact match with slack for any colour-space drift the importer introduces.
local MAX_DISTANCE = 0.06 -- in 0..1 colour space

function WeaponFinish.Classify(part: BasePart): string?
	local stamped = part:GetAttribute("Finish")
	if type(stamped) == "string" then
		return stamped
	end

	local c = part.Color
	local best, bestD = nil, math.huge
	for name, f in pairs(WeaponFinish.Stock) do
		local d = (c.R - f.color.R) ^ 2 + (c.G - f.color.G) ^ 2 + (c.B - f.color.B) ^ 2
		if d < bestD then
			best, bestD = name, d
		end
	end
	if bestD > MAX_DISTANCE then
		return nil
	end
	return best
end

-- Record what each part is made of, once, at import. After this a camo costs a single
-- attribute read per part instead of a colour search, and it survives recolouring --
-- which matters, because a camo destroys the evidence a later Classify would need.
function WeaponFinish.Stamp(tool: Instance): number
	local n = 0
	for _, part in ipairs(tool:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("Finish") == nil then
			local m = WeaponFinish.Classify(part)
			if m then
				part:SetAttribute("Finish", m)
				n += 1
			end
		end
	end
	return n
end

-- True when this weapon carries authored materials, i.e. a finish camo will look right
-- on it. Older hand-built guns fall back to the colour-role camos in CamoConfig.
function WeaponFinish.IsAuthored(tool: Instance): boolean
	for _, part in ipairs(tool:GetDescendants()) do
		if part:IsA("BasePart") and part:GetAttribute("Finish") ~= nil then
			return true
		end
	end
	return false
end

-- ------------------------------------------------------------------- painting --

local function robloxMaterial(f): EnumItem
	-- Lit first: a glowing lens should read as a lit reticle rather than as glass, and
	-- Neon keeps its transparency anyway, so nothing is lost by preferring it.
	if f.lit then
		return Enum.Material.Neon
	elseif f.alpha < 0.95 then
		return Enum.Material.Glass
	elseif f.metal >= 0.30 then
		return Enum.Material.Metal
	elseif f.rough >= 0.60 then
		return Enum.Material.SmoothPlastic
	end
	return Enum.Material.Plastic
end

-- Fold a finish's emissive into something Roblox can actually show. `intensity` is the
-- reactive dial: 0 leaves a reactive camo cold, 1 lights it fully. Static camos pass 1.
local function resolve(f, intensity: number)
	local glow = f.glow
	if not glow then
		return { color = f.color, metal = f.metal, rough = f.rough, alpha = f.alpha, lit = false }
	end
	local strength = math.max((f.glowStrength or 1) * intensity, 0)
	-- Emissive ADDS light in the source material; it does not replace the base colour.
	-- Lerping toward it instead would darken Diamond, whose glow is a dim blue tint over
	-- a near-white body.
	local c = f.color
	return {
		color = Color3.new(
			math.min(c.R + glow.R * strength, 1),
			math.min(c.G + glow.G * strength, 1),
			math.min(c.B + glow.B * strength, 1)
		),
		metal = f.metal, rough = f.rough, alpha = f.alpha,
		-- Below this the emissive only tints; above it the part is genuinely a light source.
		lit = strength >= 0.60,
	}
end

-- Paint a weapon in an authored camo. `intensity` only matters for reactive camos.
-- Returns false if the weapon has no authored materials, so the caller can fall back.
function WeaponFinish.Apply(tool: Instance, camoId: string?, intensity: number?): boolean
	local camo = camoId and WeaponFinish.Camos[camoId]
	if not camo then
		return false
	end
	local t = math.clamp(intensity or 1, 0, 1)

	local painted = 0
	for _, part in ipairs(tool:GetDescendants()) do
		if part:IsA("BasePart") then
			local material = part:GetAttribute("Finish")
			local f = type(material) == "string" and camo[material]
			if f then
				local look = resolve(f, t)
				part.Color = look.color
				part.Material = robloxMaterial(look)
				part.Reflectance = math.clamp(look.metal * (1 - look.rough), 0, 1) * 0.5
				-- Only glass carries its opacity from the camo. Everything else keeps the
				-- transparency it already has, because a reload hides magazine parts by
				-- setting exactly that and a camo must not undo it.
				if look.alpha < 1 then
					part.Transparency = 1 - look.alpha
				end
				painted += 1
			end
		end
	end
	return painted > 0
end

-- Put a weapon back to how it was exported.
function WeaponFinish.Restore(tool: Instance): boolean
	local painted = 0
	for _, part in ipairs(tool:GetDescendants()) do
		if part:IsA("BasePart") then
			local material = part:GetAttribute("Finish")
			local f = type(material) == "string" and WeaponFinish.Stock[material]
			if f then
				part.Color = f.color
				part.Material = robloxMaterial(f)
				part.Reflectance = math.clamp(f.metal * (1 - f.rough), 0, 1) * 0.5
				if f.alpha < 1 then
					part.Transparency = 1 - f.alpha
				end
				painted += 1
			end
		end
	end
	return painted > 0
end

return WeaponFinish
