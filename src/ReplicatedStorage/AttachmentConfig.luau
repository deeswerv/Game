--!strict
-- Weapon attachments: what they are, where they go, and which weapons take them.
--
-- Everything here is data. An attachment is a list of blocks described relative to a
-- mount point, and a mount point is worked out from the weapon's own geometry rather than
-- hand-placed per gun -- so a new weapon supports the whole catalogue as soon as it has a
-- barrel and a receiver, and a new attachment is one table entry.
--
-- Offsets are in the weapon's own frame: -Z is down the barrel, +Y is up, +X is right.

local AttachmentConfig = {}

-- Tuned to sit against the weapons rather than on top of them: the guns are dark gunmetal
-- with steel furniture, so the attachments are too. The old tan palette belonged to the
-- blockier models these replaced and read as plastic next to the new ones.
local DARK = Color3.fromRGB(38, 41, 48)          -- housings, bodies
local BODY = Color3.fromRGB(52, 57, 66)          -- large surfaces
local STEEL = Color3.fromRGB(112, 120, 132)      -- rings, collars, hardware
local DARKSTEEL = Color3.fromRGB(72, 78, 90)
local GLASS = Color3.fromRGB(96, 172, 200)
local ACCENT = Color3.fromRGB(206, 158, 74)      -- used sparingly, for a little warmth
local LASER = Color3.fromRGB(255, 58, 58)
local LAMP = Color3.fromRGB(255, 244, 200)
local TAN = Color3.fromRGB(198, 152, 96)
local TAN_DARK = Color3.fromRGB(150, 112, 68)

local M = Enum.Material

-- Slots, in the order the customisation screen shows them.
AttachmentConfig.Slots = {
	"Sight", "Muzzle", "Underbarrel", "Magazine", "Stock", "Charm",
}

AttachmentConfig.SlotLabels = {
	Sight = "Sight",
	Muzzle = "Muzzle",
	Underbarrel = "Underbarrel",
	Magazine = "Magazine",
	Stock = "Stock",
	Charm = "Charm",
}

-- Which part of a weapon each slot hangs off, best match first, and which face of it.
AttachmentConfig.Mounts = {
	Sight = { hosts = { "Rail", "DustCover", "Upper", "Slide", "Receiver", "Frame" }, face = "Top" },
	Muzzle = { hosts = { "Muzzle" }, face = "Front" },
	Underbarrel = { hosts = { "LowerHandguard", "Handguard", "Pump", "Barrel", "Frame" }, face = "Bottom" },
	Magazine = { hosts = { "Magazine", "MagBase", "MagFloor" }, face = "Bottom" },
	Stock = { hosts = { "ButtPad", "Stock", "StockNeck", "Receiver", "Serrations" }, face = "Rear" },
	Charm = { hosts = { "Handle", "Receiver", "Frame" }, face = "Side" },
}

-- A part of an attachment. `shape` defaults to a block.
type PartSpec = {
	size: Vector3,
	offset: Vector3,
	colour: Color3,
	material: Enum.Material?,
	shape: string?,
	transparency: number?,
}

local function block(size: Vector3, offset: Vector3, colour: Color3, material: Enum.Material?): PartSpec
	return { size = size, offset = offset, colour = colour, material = material or M.SmoothPlastic }
end

local function tube(size: Vector3, offset: Vector3, colour: Color3, material: Enum.Material?): PartSpec
	return { size = size, offset = offset, colour = colour, material = material or M.Metal, shape = "Cylinder" }
end

-- "None" is a real option in every slot, so a slot can always be cleared.
local NONE = { id = "None", name = "None", parts = {} }

AttachmentConfig.Options = {

	-- ------------------------------------------------------------------ sights --
	Sight = {
		{ id = "Irons", name = "Iron Sights", parts = {} },

		-- Clamp, hood walls, canted glass and a lit dot. The hood is two walls and a roof
		-- rather than one block, so it reads as an optic you could look through.
		--
		-- Kept deliberately low. The first version stood 0.45 studs off the rail -- most of
		-- the height of the weapon it was bolted to -- and read as a scope rather than a red
		-- dot. This one is a little over half that, which is the proportion a micro sight
		-- actually has, and it leaves the Holo and the magnified optics somewhere to go.
		{ id = "RedDot", name = "Red Dot", parts = {
			block(Vector3.new(0.26, 0.04, 0.38), Vector3.new(0, 0.02, 0), STEEL, M.Metal),
			block(Vector3.new(0.09, 0.05, 0.10), Vector3.new(0, 0.05, 0.14), DARKSTEEL, M.Metal),
			block(Vector3.new(0.09, 0.05, 0.10), Vector3.new(0, 0.05, -0.14), DARKSTEEL, M.Metal),
			block(Vector3.new(0.19, 0.07, 0.24), Vector3.new(0, 0.075, 0), DARK, M.Metal),
			block(Vector3.new(0.035, 0.13, 0.21), Vector3.new(-0.093, 0.165, 0), DARK, M.Metal),
			block(Vector3.new(0.035, 0.13, 0.21), Vector3.new(0.093, 0.165, 0), DARK, M.Metal),
			block(Vector3.new(0.22, 0.03, 0.22), Vector3.new(0, 0.245, 0), DARK, M.Metal),
			block(Vector3.new(0.16, 0.12, 0.025), Vector3.new(0, 0.165, -0.09), GLASS, M.Glass),
			{ size = Vector3.new(0.035, 0.035, 0.035), offset = Vector3.new(0, 0.165, -0.07),
			  colour = LASER, material = M.Neon, shape = "Ball" },
			tube(Vector3.new(0.07, 0.07, 0.07), Vector3.new(0.105, 0.20, 0.07), STEEL),
		} },

		-- Wide square window with a raised hood and a battery cap on the side.
		{ id = "Holo", name = "Holographic", parts = {
			block(Vector3.new(0.32, 0.05, 0.60), Vector3.new(0, 0.03, 0), STEEL, M.Metal),
			block(Vector3.new(0.30, 0.16, 0.34), Vector3.new(0, 0.13, 0.14), DARK, M.Metal),
			block(Vector3.new(0.05, 0.30, 0.05), Vector3.new(-0.13, 0.32, -0.14), DARK, M.Metal),
			block(Vector3.new(0.05, 0.30, 0.05), Vector3.new(0.13, 0.32, -0.14), DARK, M.Metal),
			block(Vector3.new(0.31, 0.05, 0.05), Vector3.new(0, 0.46, -0.14), DARK, M.Metal),
			block(Vector3.new(0.26, 0.26, 0.02), Vector3.new(0, 0.31, -0.14), GLASS, M.Glass),
			block(Vector3.new(0.30, 0.26, 0.06), Vector3.new(0, 0.31, 0.28), DARK, M.Metal),
			tube(Vector3.new(0.12, 0.10, 0.12), Vector3.new(0.16, 0.20, 0.16), DARKSTEEL),
			block(Vector3.new(0.34, 0.03, 0.20), Vector3.new(0, 0.46, 0.14), DARKSTEEL, M.Metal),
		} },

		-- The magnified optics share a shape: two clamp rings with bolts, a tube, a bell at
		-- the objective, an ocular at the back and two turrets. Only the proportions differ.
		{ id = "Scope2x", name = "2x Prism", parts = {
			block(Vector3.new(0.28, 0.05, 0.54), Vector3.new(0, 0.03, 0), STEEL, M.Metal),
			block(Vector3.new(0.22, 0.16, 0.10), Vector3.new(0, 0.12, 0.20), DARKSTEEL, M.Metal),
			block(Vector3.new(0.22, 0.16, 0.10), Vector3.new(0, 0.12, -0.20), DARKSTEEL, M.Metal),
			tube(Vector3.new(0.22, 0.86, 0.22), Vector3.new(0, 0.28, 0), DARK),
			tube(Vector3.new(0.30, 0.18, 0.30), Vector3.new(0, 0.28, -0.46), DARK),
			tube(Vector3.new(0.26, 0.14, 0.26), Vector3.new(0, 0.28, 0.44), DARK),
			tube(Vector3.new(0.25, 0.03, 0.25), Vector3.new(0, 0.28, -0.54), GLASS, M.Glass),
			tube(Vector3.new(0.21, 0.03, 0.21), Vector3.new(0, 0.28, 0.50), GLASS, M.Glass),
			tube(Vector3.new(0.13, 0.10, 0.13), Vector3.new(0, 0.40, 0.06), STEEL),
			tube(Vector3.new(0.12, 0.09, 0.12), Vector3.new(0.14, 0.28, 0.06), STEEL),
		} },
		{ id = "Scope4x", name = "4x Marksman", parts = {
			block(Vector3.new(0.28, 0.05, 0.70), Vector3.new(0, 0.03, 0), STEEL, M.Metal),
			block(Vector3.new(0.24, 0.18, 0.10), Vector3.new(0, 0.13, 0.28), DARKSTEEL, M.Metal),
			block(Vector3.new(0.24, 0.18, 0.10), Vector3.new(0, 0.13, -0.28), DARKSTEEL, M.Metal),
			tube(Vector3.new(0.24, 1.30, 0.24), Vector3.new(0, 0.31, -0.04), DARK),
			tube(Vector3.new(0.38, 0.24, 0.38), Vector3.new(0, 0.31, -0.72), DARK),
			tube(Vector3.new(0.30, 0.18, 0.30), Vector3.new(0, 0.31, 0.62), DARK),
			tube(Vector3.new(0.33, 0.03, 0.33), Vector3.new(0, 0.31, -0.83), GLASS, M.Glass),
			tube(Vector3.new(0.25, 0.03, 0.25), Vector3.new(0, 0.31, 0.70), GLASS, M.Glass),
			tube(Vector3.new(0.28, 0.10, 0.28), Vector3.new(0, 0.31, 0.14), DARKSTEEL),
			tube(Vector3.new(0.15, 0.12, 0.15), Vector3.new(0, 0.45, 0.02), STEEL),
			tube(Vector3.new(0.14, 0.11, 0.14), Vector3.new(0.15, 0.31, 0.02), STEEL),
			block(Vector3.new(0.06, 0.05, 0.06), Vector3.new(0, 0.52, 0.02), ACCENT, M.Metal),
		} },
		{ id = "Sniper", name = "8x Sniper", parts = {
			block(Vector3.new(0.30, 0.05, 0.86), Vector3.new(0, 0.03, 0), STEEL, M.Metal),
			block(Vector3.new(0.26, 0.20, 0.11), Vector3.new(0, 0.14, 0.36), DARKSTEEL, M.Metal),
			block(Vector3.new(0.26, 0.20, 0.11), Vector3.new(0, 0.14, -0.36), DARKSTEEL, M.Metal),
			tube(Vector3.new(0.26, 1.80, 0.26), Vector3.new(0, 0.35, -0.04), DARK),
			tube(Vector3.new(0.46, 0.30, 0.46), Vector3.new(0, 0.35, -1.00), DARK),
			tube(Vector3.new(0.50, 0.16, 0.50), Vector3.new(0, 0.35, -1.20), DARKSTEEL),
			tube(Vector3.new(0.34, 0.22, 0.34), Vector3.new(0, 0.35, 0.86), DARK),
			tube(Vector3.new(0.41, 0.03, 0.41), Vector3.new(0, 0.35, -1.14), GLASS, M.Glass),
			tube(Vector3.new(0.29, 0.03, 0.29), Vector3.new(0, 0.35, 0.95), GLASS, M.Glass),
			tube(Vector3.new(0.30, 0.12, 0.30), Vector3.new(0, 0.35, 0.22), DARKSTEEL),
			tube(Vector3.new(0.17, 0.14, 0.17), Vector3.new(0, 0.51, 0.06), STEEL),
			tube(Vector3.new(0.16, 0.13, 0.16), Vector3.new(0.17, 0.35, 0.06), STEEL),
			block(Vector3.new(0.07, 0.05, 0.07), Vector3.new(0, 0.59, 0.06), ACCENT, M.Metal),
		} },
	},

	-- ----------------------------------------------------------------- muzzles --
	Muzzle = {
		NONE,
		-- Mount collar, main can, three cooling bands and a recessed front aperture.
		{ id = "Suppressor", name = "Suppressor", parts = {
			tube(Vector3.new(0.30, 0.12, 0.30), Vector3.new(0, 0, -0.08), STEEL),
			tube(Vector3.new(0.27, 1.05, 0.27), Vector3.new(0, 0, -0.62), DARK),
			tube(Vector3.new(0.30, 0.05, 0.30), Vector3.new(0, 0, -0.34), DARKSTEEL),
			tube(Vector3.new(0.30, 0.05, 0.30), Vector3.new(0, 0, -0.62), DARKSTEEL),
			tube(Vector3.new(0.30, 0.05, 0.30), Vector3.new(0, 0, -0.90), DARKSTEEL),
			tube(Vector3.new(0.29, 0.07, 0.29), Vector3.new(0, 0, -1.13), STEEL),
			tube(Vector3.new(0.15, 0.04, 0.15), Vector3.new(0, 0, -1.16), Color3.fromRGB(16, 16, 18)),
		} },
		-- Ported body: the ports are cut as gaps between four top plates.
		{ id = "Compensator", name = "Compensator", parts = {
			tube(Vector3.new(0.28, 0.10, 0.28), Vector3.new(0, 0, -0.06), STEEL),
			tube(Vector3.new(0.25, 0.52, 0.25), Vector3.new(0, 0, -0.37), DARK),
			block(Vector3.new(0.28, 0.06, 0.07), Vector3.new(0, 0.11, -0.20), DARKSTEEL, M.Metal),
			block(Vector3.new(0.28, 0.06, 0.07), Vector3.new(0, 0.11, -0.34), DARKSTEEL, M.Metal),
			block(Vector3.new(0.28, 0.06, 0.07), Vector3.new(0, 0.11, -0.48), DARKSTEEL, M.Metal),
			tube(Vector3.new(0.29, 0.06, 0.29), Vector3.new(0, 0, -0.60), STEEL),
		} },
		-- Big squared brake with side baffles.
		{ id = "Brake", name = "Muzzle Brake", parts = {
			tube(Vector3.new(0.28, 0.10, 0.28), Vector3.new(0, 0, -0.06), STEEL),
			block(Vector3.new(0.30, 0.26, 0.60), Vector3.new(0, 0, -0.40), DARK, M.Metal),
			block(Vector3.new(0.36, 0.08, 0.09), Vector3.new(0, 0.07, -0.26), STEEL, M.Metal),
			block(Vector3.new(0.36, 0.08, 0.09), Vector3.new(0, 0.07, -0.42), STEEL, M.Metal),
			block(Vector3.new(0.36, 0.08, 0.09), Vector3.new(0, 0.07, -0.58), STEEL, M.Metal),
			block(Vector3.new(0.32, 0.28, 0.06), Vector3.new(0, 0, -0.71), DARKSTEEL, M.Metal),
			tube(Vector3.new(0.13, 0.05, 0.13), Vector3.new(0, 0, -0.73), Color3.fromRGB(16, 16, 18)),
		} },
		-- Four-prong hider.
		{ id = "Flash", name = "Flash Hider", parts = {
			tube(Vector3.new(0.27, 0.10, 0.27), Vector3.new(0, 0, -0.06), STEEL),
			tube(Vector3.new(0.23, 0.30, 0.23), Vector3.new(0, 0, -0.25), DARK),
			block(Vector3.new(0.05, 0.05, 0.30), Vector3.new(0, 0.10, -0.52), DARKSTEEL, M.Metal),
			block(Vector3.new(0.05, 0.05, 0.30), Vector3.new(0, -0.10, -0.52), DARKSTEEL, M.Metal),
			block(Vector3.new(0.05, 0.05, 0.30), Vector3.new(0.10, 0, -0.52), DARKSTEEL, M.Metal),
			block(Vector3.new(0.05, 0.05, 0.30), Vector3.new(-0.10, 0, -0.52), DARKSTEEL, M.Metal),
			tube(Vector3.new(0.26, 0.05, 0.26), Vector3.new(0, 0, -0.66), STEEL),
		} },
	},

	-- ------------------------------------------------------------- underbarrel --
	Underbarrel = {
		NONE,
		-- Rail clamp, neck, and a grip with three finger grooves cut as raised ribs.
		{ id = "Foregrip", name = "Vertical Grip", parts = {
			block(Vector3.new(0.26, 0.08, 0.30), Vector3.new(0, -0.04, 0), STEEL, M.Metal),
			block(Vector3.new(0.14, 0.10, 0.16), Vector3.new(0, -0.12, 0), DARKSTEEL, M.Metal),
			block(Vector3.new(0.18, 0.44, 0.20), Vector3.new(0, -0.38, 0), DARK),
			block(Vector3.new(0.20, 0.04, 0.22), Vector3.new(0, -0.26, 0), DARKSTEEL),
			block(Vector3.new(0.20, 0.04, 0.22), Vector3.new(0, -0.38, 0), DARKSTEEL),
			block(Vector3.new(0.20, 0.04, 0.22), Vector3.new(0, -0.50, 0), DARKSTEEL),
			block(Vector3.new(0.21, 0.05, 0.23), Vector3.new(0, -0.62, 0), STEEL, M.Metal),
		} },
		{ id = "Angled", name = "Angled Grip", parts = {
			block(Vector3.new(0.26, 0.08, 0.34), Vector3.new(0, -0.04, 0), STEEL, M.Metal),
			block(Vector3.new(0.18, 0.34, 0.20), Vector3.new(0, -0.24, -0.06), DARK),
			block(Vector3.new(0.18, 0.18, 0.26), Vector3.new(0, -0.36, -0.16), DARK),
			block(Vector3.new(0.20, 0.04, 0.24), Vector3.new(0, -0.30, -0.10), DARKSTEEL),
			block(Vector3.new(0.19, 0.05, 0.10), Vector3.new(0, -0.44, -0.24), STEEL, M.Metal),
		} },
		-- Housing, lens bezel, emitter and the beam itself.
		{ id = "Laser", name = "Laser Sight", parts = {
			block(Vector3.new(0.24, 0.07, 0.30), Vector3.new(0, -0.04, 0), STEEL, M.Metal),
			block(Vector3.new(0.18, 0.16, 0.34), Vector3.new(0, -0.15, -0.02), DARK, M.Metal),
			tube(Vector3.new(0.14, 0.06, 0.14), Vector3.new(0, -0.15, -0.20), DARKSTEEL),
			block(Vector3.new(0.06, 0.05, 0.05), Vector3.new(0.09, -0.09, 0.10), ACCENT, M.Metal),
			{ size = Vector3.new(0.06, 0.06, 0.06), offset = Vector3.new(0, -0.15, -0.23),
			  colour = LASER, material = M.Neon, shape = "Ball" },
			{ size = Vector3.new(0.03, 0.03, 5.0), offset = Vector3.new(0, -0.15, -2.7),
			  colour = LASER, material = M.Neon, transparency = 0.5 },
		} },
		{ id = "Light", name = "Flashlight", parts = {
			block(Vector3.new(0.24, 0.07, 0.28), Vector3.new(0, -0.04, 0), STEEL, M.Metal),
			tube(Vector3.new(0.20, 0.40, 0.20), Vector3.new(0, -0.16, -0.06), DARK),
			tube(Vector3.new(0.23, 0.06, 0.23), Vector3.new(0, -0.16, -0.24), DARKSTEEL),
			tube(Vector3.new(0.19, 0.04, 0.19), Vector3.new(0, -0.16, -0.28), LAMP, M.Neon),
			block(Vector3.new(0.05, 0.06, 0.06), Vector3.new(0.11, -0.16, 0.10), ACCENT, M.Metal),
		} },
		-- Hinged mount with two swept legs and feet.
		{ id = "Bipod", name = "Bipod", parts = {
			block(Vector3.new(0.24, 0.08, 0.26), Vector3.new(0, -0.04, 0), STEEL, M.Metal),
			block(Vector3.new(0.16, 0.12, 0.18), Vector3.new(0, -0.13, 0), DARK, M.Metal),
			tube(Vector3.new(0.09, 0.22, 0.09), Vector3.new(0, -0.13, 0), DARKSTEEL),
			block(Vector3.new(0.05, 0.48, 0.05), Vector3.new(-0.15, -0.38, -0.05), STEEL, M.Metal),
			block(Vector3.new(0.05, 0.48, 0.05), Vector3.new(0.15, -0.38, -0.05), STEEL, M.Metal),
			block(Vector3.new(0.07, 0.05, 0.13), Vector3.new(-0.17, -0.62, -0.07), DARK),
			block(Vector3.new(0.07, 0.05, 0.13), Vector3.new(0.17, -0.62, -0.07), DARK),
		} },
	},

	-- --------------------------------------------------------------- magazines --
	Magazine = {
		{ id = "Standard", name = "Standard", parts = {} },
		-- Extension body with witness holes down the side and a floor plate.
		{ id = "Extended", name = "Extended", parts = {
			block(Vector3.new(0.24, 0.44, 0.30), Vector3.new(0, -0.22, 0), DARK),
			block(Vector3.new(0.26, 0.05, 0.32), Vector3.new(0, -0.02, 0), DARKSTEEL, M.Metal),
			block(Vector3.new(0.25, 0.04, 0.06), Vector3.new(0, -0.16, -0.10), DARKSTEEL),
			block(Vector3.new(0.25, 0.04, 0.06), Vector3.new(0, -0.28, -0.10), DARKSTEEL),
			block(Vector3.new(0.28, 0.07, 0.34), Vector3.new(0, -0.47, 0), STEEL, M.Metal),
			block(Vector3.new(0.10, 0.05, 0.09), Vector3.new(0, -0.52, 0.14), ACCENT, M.Metal),
		} },
		-- Drum with a hub, cover plate and a feed neck up into the magwell.
		{ id = "Drum", name = "Drum", parts = {
			block(Vector3.new(0.22, 0.22, 0.24), Vector3.new(0, -0.10, 0), DARK),
			{ size = Vector3.new(0.28, 0.66, 0.66), offset = Vector3.new(0, -0.44, 0.04),
			  colour = DARK, material = M.SmoothPlastic, shape = "Cylinder" },
			{ size = Vector3.new(0.31, 0.52, 0.52), offset = Vector3.new(0, -0.44, 0.04),
			  colour = DARKSTEEL, material = M.SmoothPlastic, shape = "Cylinder" },
			{ size = Vector3.new(0.33, 0.20, 0.20), offset = Vector3.new(0, -0.44, 0.04),
			  colour = STEEL, material = M.Metal, shape = "Cylinder" },
			{ size = Vector3.new(0.35, 0.07, 0.07), offset = Vector3.new(0, -0.44, 0.04),
			  colour = ACCENT, material = M.Metal, shape = "Cylinder" },
		} },
		{ id = "Quick", name = "Quickdraw", parts = {
			block(Vector3.new(0.26, 0.16, 0.34), Vector3.new(0, -0.08, 0), DARK, M.Metal),
			block(Vector3.new(0.30, 0.06, 0.36), Vector3.new(0, -0.18, 0), STEEL, M.Metal),
			block(Vector3.new(0.28, 0.07, 0.16), Vector3.new(0, -0.22, 0.18), DARKSTEEL),
			block(Vector3.new(0.29, 0.04, 0.10), Vector3.new(0, -0.26, 0.22), ACCENT, M.Metal),
		} },
	},

	-- ------------------------------------------------------------------ stocks --
	Stock = {
		{ id = "Standard", name = "Standard", parts = {} },
		-- Solid stock with a raised cheek rest, rubber pad and a sling loop.
		{ id = "Heavy", name = "Heavy Stock", parts = {
			block(Vector3.new(0.20, 0.24, 0.20), Vector3.new(0, 0.02, 0.10), DARKSTEEL, M.Metal),
			block(Vector3.new(0.28, 0.42, 0.62), Vector3.new(0, 0, 0.44), DARK),
			block(Vector3.new(0.24, 0.10, 0.44), Vector3.new(0, 0.24, 0.44), BODY),
			block(Vector3.new(0.30, 0.50, 0.09), Vector3.new(0, -0.02, 0.78), DARKSTEEL),
			block(Vector3.new(0.31, 0.10, 0.05), Vector3.new(0, 0.18, 0.80), STEEL, M.Metal),
			tube(Vector3.new(0.09, 0.06, 0.09), Vector3.new(0.14, -0.14, 0.68), STEEL),
		} },
		-- Two tubes, a cross brace and a pad. Light, and you can see through it.
		{ id = "Skeleton", name = "Skeleton", parts = {
			block(Vector3.new(0.22, 0.22, 0.18), Vector3.new(0, 0.06, 0.09), DARKSTEEL, M.Metal),
			tube(Vector3.new(0.08, 0.66, 0.08), Vector3.new(-0.09, 0.18, 0.44), STEEL),
			tube(Vector3.new(0.08, 0.66, 0.08), Vector3.new(0.09, 0.18, 0.44), STEEL),
			tube(Vector3.new(0.07, 0.58, 0.07), Vector3.new(0, -0.08, 0.42), STEEL),
			block(Vector3.new(0.24, 0.06, 0.10), Vector3.new(0, 0.05, 0.52), DARKSTEEL, M.Metal),
			block(Vector3.new(0.26, 0.44, 0.08), Vector3.new(0, 0.08, 0.76), DARK),
			block(Vector3.new(0.27, 0.10, 0.04), Vector3.new(0, 0.24, 0.78), ACCENT, M.Metal),
		} },
		-- Side-folder: hinge block, tube arm and a thin pad, all offset to one side.
		{ id = "Folding", name = "Folding", parts = {
			block(Vector3.new(0.18, 0.30, 0.16), Vector3.new(0.10, 0.06, 0.10), DARK, M.Metal),
			tube(Vector3.new(0.13, 0.16, 0.13), Vector3.new(0.16, 0.06, 0.10), STEEL),
			tube(Vector3.new(0.09, 0.58, 0.09), Vector3.new(0.22, 0.06, 0.42), STEEL),
			tube(Vector3.new(0.09, 0.58, 0.09), Vector3.new(0.22, -0.12, 0.42), STEEL),
			block(Vector3.new(0.13, 0.36, 0.08), Vector3.new(0.22, -0.03, 0.74), DARK),
			block(Vector3.new(0.06, 0.08, 0.07), Vector3.new(0.10, 0.20, 0.16), ACCENT, M.Metal),
		} },
	},

	-- ------------------------------------------------------------------ charms --
	Charm = {
		NONE,
		{ id = "Melon", name = "Watermelon", parts = {
			block(Vector3.new(0.03, 0.14, 0.03), Vector3.new(0, -0.07, 0), STEEL, M.Metal),
			block(Vector3.new(0.05, 0.16, 0.18), Vector3.new(0, -0.22, 0), Color3.fromRGB(232, 74, 88)),
			block(Vector3.new(0.06, 0.05, 0.19), Vector3.new(0, -0.29, 0), Color3.fromRGB(96, 176, 84)),
		} },
		{ id = "Skull", name = "Skull", parts = {
			block(Vector3.new(0.03, 0.14, 0.03), Vector3.new(0, -0.07, 0), STEEL, M.Metal),
			block(Vector3.new(0.14, 0.15, 0.14), Vector3.new(0, -0.22, 0), Color3.fromRGB(236, 230, 214)),
			block(Vector3.new(0.12, 0.05, 0.10), Vector3.new(0, -0.31, -0.02), Color3.fromRGB(236, 230, 214)),
		} },
		{ id = "Star", name = "Star", parts = {
			block(Vector3.new(0.03, 0.14, 0.03), Vector3.new(0, -0.07, 0), STEEL, M.Metal),
			block(Vector3.new(0.05, 0.20, 0.07), Vector3.new(0, -0.24, 0), Color3.fromRGB(246, 92, 178)),
			block(Vector3.new(0.05, 0.07, 0.20), Vector3.new(0, -0.24, 0), Color3.fromRGB(246, 92, 178)),
		} },
		{ id = "Dice", name = "Lucky Dice", parts = {
			block(Vector3.new(0.03, 0.14, 0.03), Vector3.new(0, -0.07, 0), STEEL, M.Metal),
			block(Vector3.new(0.15, 0.15, 0.15), Vector3.new(0, -0.22, 0), Color3.fromRGB(238, 96, 196)),
		} },
		{ id = "Bolt", name = "Bolt", parts = {
			block(Vector3.new(0.03, 0.14, 0.03), Vector3.new(0, -0.07, 0), STEEL, M.Metal),
			block(Vector3.new(0.05, 0.16, 0.09), Vector3.new(0, -0.20, 0.03), Color3.fromRGB(72, 142, 245)),
			block(Vector3.new(0.05, 0.14, 0.09), Vector3.new(0, -0.30, -0.03), Color3.fromRGB(72, 142, 245)),
		} },
	},
}

-- Look up one option by id.
-- What each attachment costs and how rare it is.
--
-- Kept as one table rather than a field on every option so the catalogue above stays
-- readable as pure geometry. The FIRST option in each slot is the stock part -- iron
-- sights, a bare muzzle, the standard magazine -- which is free and owned by everyone
-- without a purchase record, so a player can always strip a weapon back to standard.
AttachmentConfig.Pricing = {
	Sight = {
		Irons = { 0, "Common" }, RedDot = { 900, "Uncommon" }, Holo = { 1500, "Rare" },
		Scope2x = { 2000, "Rare" }, Scope4x = { 3200, "Epic" }, Sniper = { 5000, "Legendary" },
	},
	Muzzle = {
		None = { 0, "Common" }, Flash = { 700, "Common" }, Compensator = { 1400, "Uncommon" },
		Brake = { 2000, "Rare" }, Suppressor = { 3400, "Epic" },
	},
	Underbarrel = {
		None = { 0, "Common" }, Angled = { 800, "Common" }, Foregrip = { 1100, "Uncommon" },
		Light = { 1500, "Uncommon" }, Laser = { 2200, "Rare" }, Bipod = { 2800, "Epic" },
	},
	Magazine = {
		Standard = { 0, "Common" }, Quick = { 1000, "Uncommon" },
		Extended = { 1800, "Rare" }, Drum = { 3000, "Epic" },
	},
	Stock = {
		Standard = { 0, "Common" }, Folding = { 900, "Common" },
		Skeleton = { 1400, "Uncommon" }, Heavy = { 1900, "Rare" },
	},
	Charm = {
		None = { 0, "Common" }, Dice = { 500, "Common" }, Bolt = { 700, "Common" },
		Melon = { 1000, "Uncommon" }, Star = { 1200, "Uncommon" }, Skull = { 1600, "Rare" },
	},
}

-- ------------------------------------------------------------------- stats --
--
-- What each attachment does to the weapon. Kept out of the geometry tables above for the
-- same reason as the pricing: those tables are the shape of the thing, this is the
-- balance, and they change for different reasons.
--
-- `mul` scales, `add` offsets. Both are applied to whatever the weapon's own config says,
-- so one table works across every gun rather than being tuned per weapon.
--
-- Every attachment worth buying is a TRADE. Nothing here is a free upgrade -- a scope
-- costs you the speed of getting on target, a drum costs you the reload, a suppressor
-- costs you range and a little damage. Charms cost nothing and do nothing; not every
-- slot has to be a stat decision.
--
-- Bear in mind which way is better for each number: Damage, MagazineSize and Range are
-- better higher; FireRate, ReloadTime, the spreads and the recoils are better LOWER, so a
-- multiplier below 1 on those is an improvement.
AttachmentConfig.Stats = {
	Sight = {
		Irons = nil,
		RedDot  = { SpreadMin = { mul = 0.92 } },
		Holo    = { SpreadMin = { mul = 0.88 }, AdsFov = { mul = 0.97 } },
		Scope2x = { SpreadMin = { mul = 0.82 }, AdsFov = { mul = 0.90 },
		            AdsWalkSpeedScale = { mul = 0.95 } },
		Scope4x = { SpreadMin = { mul = 0.72 }, AdsFov = { mul = 0.78 },
		            AdsWalkSpeedScale = { mul = 0.90 }, AdsSpeed = { mul = 0.85 } },
		Sniper  = { SpreadMin = { mul = 0.60 }, AdsFov = { mul = 0.62 },
		            AdsWalkSpeedScale = { mul = 0.82 }, AdsSpeed = { mul = 0.72 } },
	},
	Muzzle = {
		None = nil,
		Flash       = { SpreadPerShot = { mul = 0.94 } },
		Compensator = { RecoilPitch = { mul = 0.82 }, RecoilYaw = { mul = 0.85 } },
		Brake       = { RecoilPitch = { mul = 0.70 }, RecoilYaw = { mul = 0.72 },
		                SpreadMax = { mul = 1.08 } },
		-- Quiet, and you pay for it at the far end of the range band.
		Suppressor  = { Range = { mul = 0.88 }, Damage = { mul = 0.94 },
		                RecoilPitch = { mul = 0.88 }, SpreadMin = { mul = 0.94 } },
	},
	Underbarrel = {
		None = nil,
		Foregrip = { RecoilPitch = { mul = 0.86 }, SpreadPerShot = { mul = 0.90 },
		             AdsSpeed = { mul = 0.96 } },
		Angled   = { AdsSpeed = { mul = 1.12 }, SpreadMin = { mul = 1.04 } },
		Laser    = { SpreadMin = { mul = 0.80 }, SpreadMax = { mul = 0.92 } },
		Light    = { SpreadMin = { mul = 0.95 } },
		Bipod    = { RecoilPitch = { mul = 0.72 }, RecoilRecovery = { mul = 1.15 },
		             AdsWalkSpeedScale = { mul = 0.90 } },
	},
	Magazine = {
		Standard = nil,
		Quick    = { ReloadTime = { mul = 0.78 } },
		Extended = { MagazineSize = { add = 10 }, ReloadTime = { mul = 1.12 },
		             AdsSpeed = { mul = 0.96 } },
		Drum     = { MagazineSize = { add = 25 }, ReloadTime = { mul = 1.40 },
		             AdsSpeed = { mul = 0.88 }, AdsWalkSpeedScale = { mul = 0.94 } },
	},
	Stock = {
		Standard = nil,
		Heavy    = { RecoilPitch = { mul = 0.78 }, RecoilYaw = { mul = 0.80 },
		             AdsSpeed = { mul = 0.90 }, AdsWalkSpeedScale = { mul = 0.94 } },
		Skeleton = { AdsSpeed = { mul = 1.15 }, AdsWalkSpeedScale = { mul = 1.06 },
		             RecoilPitch = { mul = 1.08 } },
		Folding  = { AdsSpeed = { mul = 1.08 }, AdsWalkSpeedScale = { mul = 1.03 },
		             RecoilYaw = { mul = 1.05 } },
	},
	-- Charms are cosmetic. Deliberately.
	Charm = {},
}

function AttachmentConfig.StatsFor(slot: string, id: string)
	local row = AttachmentConfig.Stats[slot]
	return row and row[id] or nil
end

-- Fold a whole loadout into one set of modifiers, so the caller applies them once rather
-- than walking the slots itself. Multipliers compound; offsets sum.
function AttachmentConfig.Modifiers(loadout: { [string]: string }?)
	local out: { [string]: { mul: number, add: number } } = {}
	if not loadout then
		return out
	end
	for _, slot in ipairs(AttachmentConfig.Slots) do
		local stats = AttachmentConfig.StatsFor(slot, loadout[slot] or "")
		if stats then
			for key, effect in pairs(stats) do
				local acc = out[key]
				if not acc then
					acc = { mul = 1, add = 0 }
					out[key] = acc
				end
				acc.mul *= effect.mul or 1
				acc.add += effect.add or 0
			end
		end
	end
	return out
end

-- Attachments are bought once and then fit to any weapon, so ownership is stored per
-- attachment rather than per weapon. This is the id that ownership is recorded under.
function AttachmentConfig.Key(slot: string, id: string): string
	return slot .. ":" .. id
end

function AttachmentConfig.Price(slot: string, id: string): number
	local row = AttachmentConfig.Pricing[slot]
	local entry = row and row[id]
	return entry and entry[1] or 0
end

function AttachmentConfig.Rarity(slot: string, id: string): string
	local row = AttachmentConfig.Pricing[slot]
	local entry = row and row[id]
	return entry and entry[2] or "Common"
end

-- The stock part for a slot: free, and never needs buying.
function AttachmentConfig.IsStock(slot: string, id: string): boolean
	local list = AttachmentConfig.Options[slot]
	return list ~= nil and list[1] ~= nil and list[1].id == id
end

function AttachmentConfig.Find(slot: string, id: string)
	for _, option in ipairs(AttachmentConfig.Options[slot] or {}) do
		if option.id == id then
			return option
		end
	end
	return nil
end

-- The default for a slot is always its first entry.
function AttachmentConfig.Default(slot: string): string?
	local list = AttachmentConfig.Options[slot]
	return list and list[1] and list[1].id or nil
end

return AttachmentConfig
