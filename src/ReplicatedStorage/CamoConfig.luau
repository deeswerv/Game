--!strict
-- Weapon camos.
--
-- A camo is three colours and a material, plus a rule for which parts get which colour.
-- Nothing here names a weapon, so every camo works on every gun -- including ones added
-- later -- and a new camo is one table entry.
--
-- Parts are sorted into three roles by name. Those names are the same ones the pose
-- solver and the attachment mounts already rely on, so the roles come for free.

local WeaponFinish = require(script.Parent.WeaponFinish)

local CamoConfig = {}

local M = Enum.Material

local SECONDARY = { Magazine = true, MagBase = true, MagFloor = true, MagMid = true,
	Stock = true, StockNeck = true, ButtPad = true, LowerHandguard = true,
	UpperHandguard = true, Handguard = true, Grip = true, Handle = true, Pump = true }

local ACCENT = { Rail = true, SightFront = true, SightRear = true, RearSight = true,
	FrontSightPost = true, FrontSightBlock = true, Muzzle = true, Barrel = true,
	Trigger = true, ChargingHandle = true, Bolt = true, Selector = true,
	GripStripe = true, Serrations = true, EjectPort = true, EjectionPort = true }

function CamoConfig.RoleOf(partName: string): string
	if ACCENT[partName] then
		return "accent"
	elseif SECONDARY[partName] then
		return "secondary"
	end
	return "primary"
end

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

-- RETIRED 2026-09-19. Camos are out of the game: weapons now come as whole Mastery Weapon
-- variants, sold for Robux or earned, rather than as paint over a shared model.
--
-- The definitions are kept rather than deleted, the same way GameConfig.RetiredAbilities
-- kept the ability kit. Two reasons, and neither is sentiment: players' OwnedCamos lists
-- still name these ids, so this table is the only way to say what someone earned if they
-- are ever to be compensated for a Ronin they ground 1000 kills for -- and the authored
-- finishes (Gold, Diamond, Ronin) are the same WeaponFinish data a variant wants, so the
-- variant work reads this rather than reinventing it.
--
-- Nothing reads Retired. The live catalogue below is empty, which is what takes camos out
-- of the market, the workshop, the customise panel, loot rolls and chests all at once --
-- every one of those paths already handles an empty list, because they had to handle a
-- player who owned everything.
CamoConfig.Retired = {
	{
		id = "Default", name = "Factory", rarity = "Common", price = 0, factory = true,
		desc = "The weapon as it left the bench.",
	},
	{
		id = "Steel", name = "Steel", rarity = "Common", price = 400,
		desc = "Plain gunmetal, honestly finished.",
		primary = rgb(96, 104, 118), secondary = rgb(58, 64, 76), accent = rgb(150, 158, 170),
		material = M.Metal,
	},
	{
		id = "Ash", name = "Ash", rarity = "Common", price = 400,
		desc = "Cold grey with a burnt edge.",
		primary = rgb(78, 80, 86), secondary = rgb(46, 48, 54), accent = rgb(214, 118, 96),
		material = M.SmoothPlastic,
	},
	{
		id = "Sand", name = "Sand", rarity = "Uncommon", price = 900,
		desc = "Desert tan over dark furniture.",
		primary = rgb(198, 160, 106), secondary = rgb(142, 112, 72), accent = rgb(72, 68, 60),
		material = M.SmoothPlastic,
	},
	{
		id = "Arctic", name = "Arctic", rarity = "Uncommon", price = 900,
		desc = "Bone white, for weather nobody enjoys.",
		primary = rgb(232, 234, 238), secondary = rgb(186, 190, 198), accent = rgb(120, 128, 140),
		material = M.SmoothPlastic,
	},
	{
		id = "Mire", name = "Mire", rarity = "Uncommon", price = 900,
		desc = "Swamp green, quietly unpleasant.",
		primary = rgb(150, 168, 68), secondary = rgb(96, 112, 46), accent = rgb(206, 220, 120),
		material = M.SmoothPlastic,
	},
	{
		id = "Acid", name = "Acid", rarity = "Rare", price = 1800,
		desc = "Red body, green everything else. Subtlety is not the point.",
		primary = rgb(226, 62, 62), secondary = rgb(96, 214, 74), accent = rgb(160, 246, 96),
		material = M.SmoothPlastic,
	},
	{
		id = "Cyber", name = "Cyber", rarity = "Rare", price = 1800,
		desc = "Magenta and cyan, straight off an arcade cabinet.",
		primary = rgb(232, 72, 200), secondary = rgb(60, 214, 226), accent = rgb(120, 240, 250),
		material = M.SmoothPlastic,
	},
	{
		id = "Neon", name = "Neon", rarity = "Rare", price = 1800,
		desc = "Electric blue with a burnt-orange trim.",
		primary = rgb(56, 108, 240), secondary = rgb(248, 152, 40), accent = rgb(255, 196, 84),
		material = M.SmoothPlastic,
	},
	{
		id = "Sunset", name = "Sunset", rarity = "Epic", price = 3200,
		desc = "Deep violet running into orange.",
		primary = rgb(112, 74, 224), secondary = rgb(240, 108, 56), accent = rgb(255, 168, 96),
		material = M.SmoothPlastic,
	},
	{
		id = "Gold", name = "Gold", rarity = "Legendary", price = 7500,
		desc = "Solid gold. Tasteless, and everyone will know.",
		primary = rgb(240, 190, 62), secondary = rgb(186, 138, 30), accent = rgb(255, 226, 140),
		material = M.Metal,
	},

	-- ------------------------------------------------------------------ authored --
	--
	-- These three came off the same bench as the weapons themselves, as full material
	-- repaints rather than three colours. On a weapon with authored materials they use
	-- that data; on an older hand-built gun the three colours below stand in.
	{
		id = "GoldPlate", name = "Gold Plated", rarity = "Legendary", price = 12000,
		desc = "Struck from the armourer's own plating. Every screw included.",
		finish = "Gold",
		primary = rgb(216, 165, 58), secondary = rgb(244, 237, 221), accent = rgb(246, 221, 147),
		material = M.Metal,
	},
	{
		id = "Diamond", name = "Diamond", rarity = "Mythic", price = 20000,
		desc = "Cut white, lit from inside. Costs about what it looks like it costs.",
		finish = "Diamond",
		primary = rgb(214, 227, 240), secondary = rgb(244, 249, 255), accent = rgb(255, 255, 255),
		material = M.Glass,
	},
	{
		id = "Ronin", name = "Ronin", rarity = "Mythic", price = 26000, reactive = true,
		desc = "Black steel with a circuit that wakes up as the streak climbs.",
		finish = "Ronin", peak = 8,
		primary = rgb(34, 36, 42), secondary = rgb(23, 24, 27), accent = rgb(44, 77, 57),
		hot = { primary = rgb(34, 36, 42), secondary = rgb(23, 24, 27), accent = rgb(98, 252, 170) },
		hotMaterial = M.Neon, material = M.SmoothPlastic,
	},

	-- ------------------------------------------------------------------ reactive --
	--
	-- A reactive camo reads the kill streak the server publishes on the character and
	-- moves between two colour sets. The work is a colour lerp on equip and on each
	-- streak change -- no per-frame cost, which is what keeps them affordable.
	{
		id = "Ember", name = "Ember", rarity = "Epic", price = 4200, reactive = true,
		desc = "Charcoal when cold. Burns brighter the longer you live.",
		primary = rgb(58, 54, 56), secondary = rgb(38, 36, 38), accent = rgb(196, 88, 40),
		hot = { primary = rgb(248, 128, 48), secondary = rgb(196, 62, 30), accent = rgb(255, 238, 190) },
		hotMaterial = M.Neon, peak = 6, material = M.SmoothPlastic,
	},
	{
		id = "Voltage", name = "Voltage", rarity = "Legendary", price = 8500, reactive = true,
		desc = "Dull steel that charges brighter with every elimination.",
		primary = rgb(70, 78, 92), secondary = rgb(44, 50, 60), accent = rgb(96, 150, 200),
		hot = { primary = rgb(96, 200, 255), secondary = rgb(48, 120, 200), accent = rgb(210, 250, 255) },
		hotMaterial = M.Neon, peak = 8, material = M.SmoothPlastic,
	},
}

-- The live catalogue. Empty on purpose -- see the note above Retired.
CamoConfig.Camos = {}

function CamoConfig.Find(id: string)
	for _, camo in ipairs(CamoConfig.Camos) do
		if camo.id == id then
			return camo
		end
	end
	return nil
end

-- The colours a camo shows at a given streak. Non-reactive camos ignore the streak.
function CamoConfig.Resolve(camo, streak: number?)
	if not camo or camo.factory then
		return nil
	end
	if not camo.reactive or not camo.hot then
		return {
			finish = camo.finish,
			primary = camo.primary, secondary = camo.secondary, accent = camo.accent,
			-- A static camo is always fully lit; only reactive ones dim.
			material = camo.material, intensity = 1,
		}
	end
	local t = math.clamp((streak or 0) / (camo.peak or 6), 0, 1)
	return {
		finish = camo.finish,
		primary = camo.primary:Lerp(camo.hot.primary, t),
		secondary = camo.secondary:Lerp(camo.hot.secondary, t),
		accent = camo.accent:Lerp(camo.hot.accent, t),
		-- Only goes neon once it is genuinely lit, so a cold weapon does not glow.
		material = (t > 0.6 and camo.hotMaterial) or camo.material,
		intensity = t,
	}
end

-- Paint a weapon. Safe on any tool: parts it does not recognise take the primary colour.
--
-- A camo with an authored finish is applied material-by-material when the weapon has
-- the materials to match. Everything else -- older guns, and the colour camos -- goes
-- through the three-colour role sort below.
function CamoConfig.Apply(tool: Instance, camoId: string?, streak: number?)
	local camo = camoId and CamoConfig.Find(camoId)
	if camo and camo.factory then
		-- "Factory" means put it back, not leave it wearing the last camo.
		WeaponFinish.Restore(tool)
		return true
	end

	local look = CamoConfig.Resolve(camo, streak)
	if not look then
		return false
	end

	if look.finish and WeaponFinish.Apply(tool, look.finish, look.intensity) then
		return true
	end

	for _, part in ipairs(tool:GetDescendants()) do
		if part:IsA("BasePart") and part.Transparency < 1 then
			part.Color = look[CamoConfig.RoleOf(part.Name)] or look.primary
			part.Material = look.material
		end
	end
	return true
end

return CamoConfig
