--!strict
-- Cosmetics worn over the locked ROBLOX Boy body.
--
-- The avatar is deliberately locked so every player reads the same silhouette at a glance,
-- which matters in a shooter. Cosmetics sit ON TOP of that: they change how you look
-- without changing how big you are or how easy you are to hit.
--
-- Every piece is BUILT FROM PARTS rather than referencing a catalogue asset. Nothing here
-- depends on an asset id that might be off-sale, private, or simply wrong -- a bad id does
-- not error, it just silently renders nothing.

local CosmeticConfig = {}

-- Slots. One item per slot at a time.
CosmeticConfig.Slots = { "Hat", "Back" }

-- Where each slot attaches, and the offset from that part's centre.
CosmeticConfig.Mounts = {
	Hat = { part = "Head", offset = CFrame.new(0, 0.72, 0) },
	Back = { part = "UpperTorso", offset = CFrame.new(0, 0.15, 0.62) },
}

-- `shape` entries are { size, offset, colour, material?, shape? } relative to the mount.
CosmeticConfig.Items = {
	{
		id = "Cap", name = "Ball Cap", slot = "Hat", price = 450, rarity = "Common",
		parts = {
			{ size = Vector3.new(1.30, 0.42, 1.30), offset = CFrame.new(0, 0.10, 0), colour = Color3.fromRGB(196, 64, 64) },
			{ size = Vector3.new(1.20, 0.16, 0.78), offset = CFrame.new(0, -0.05, -0.90), colour = Color3.fromRGB(150, 46, 46) },
		},
	},
	{
		id = "Beanie", name = "Beanie", slot = "Hat", price = 450, rarity = "Common",
		parts = {
			{ size = Vector3.new(1.32, 0.58, 1.32), offset = CFrame.new(0, 0.08, 0), colour = Color3.fromRGB(72, 92, 140) },
			{ size = Vector3.new(1.38, 0.20, 1.38), offset = CFrame.new(0, -0.18, 0), colour = Color3.fromRGB(52, 68, 108) },
		},
	},
	{
		id = "Helmet", name = "Field Helmet", slot = "Hat", price = 1400, rarity = "Uncommon",
		parts = {
			{ size = Vector3.new(1.40, 0.70, 1.44), offset = CFrame.new(0, 0.12, 0), colour = Color3.fromRGB(92, 102, 82) },
			{ size = Vector3.new(1.50, 0.16, 1.54), offset = CFrame.new(0, -0.16, 0), colour = Color3.fromRGB(70, 78, 62) },
			{ size = Vector3.new(0.24, 0.40, 0.24), offset = CFrame.new(0.62, 0.30, 0.20), colour = Color3.fromRGB(48, 54, 44) },
		},
	},
	{
		id = "Crown", name = "Gilded Crown", slot = "Hat", price = 9000, rarity = "Legendary",
		parts = {
			{ size = Vector3.new(1.34, 0.34, 1.34), offset = CFrame.new(0, 0.14, 0), colour = Color3.fromRGB(226, 180, 92), material = Enum.Material.Metal },
			{ size = Vector3.new(0.22, 0.40, 0.22), offset = CFrame.new(0, 0.44, 0.56), colour = Color3.fromRGB(240, 202, 120), material = Enum.Material.Metal },
			{ size = Vector3.new(0.22, 0.40, 0.22), offset = CFrame.new(0.56, 0.44, 0), colour = Color3.fromRGB(240, 202, 120), material = Enum.Material.Metal },
			{ size = Vector3.new(0.22, 0.40, 0.22), offset = CFrame.new(-0.56, 0.44, 0), colour = Color3.fromRGB(240, 202, 120), material = Enum.Material.Metal },
			{ size = Vector3.new(0.22, 0.40, 0.22), offset = CFrame.new(0, 0.44, -0.56), colour = Color3.fromRGB(240, 202, 120), material = Enum.Material.Metal },
		},
	},
	{
		id = "Headset", name = "Comms Headset", slot = "Hat", price = 2200, rarity = "Rare",
		parts = {
			{ size = Vector3.new(1.44, 0.18, 0.24), offset = CFrame.new(0, 0.30, 0), colour = Color3.fromRGB(42, 46, 54) },
			{ size = Vector3.new(0.22, 0.46, 0.46), offset = CFrame.new(0.66, 0.02, 0), colour = Color3.fromRGB(42, 46, 54) },
			{ size = Vector3.new(0.22, 0.46, 0.46), offset = CFrame.new(-0.66, 0.02, 0), colour = Color3.fromRGB(42, 46, 54) },
			{ size = Vector3.new(0.14, 0.14, 0.62), offset = CFrame.new(0.52, -0.16, -0.42), colour = Color3.fromRGB(30, 34, 40) },
		},
	},
	{
		id = "Pack", name = "Field Pack", slot = "Back", price = 1100, rarity = "Uncommon",
		parts = {
			{ size = Vector3.new(1.10, 1.20, 0.56), offset = CFrame.new(0, 0, 0.30), colour = Color3.fromRGB(96, 84, 62) },
			{ size = Vector3.new(1.18, 0.26, 0.62), offset = CFrame.new(0, 0.42, 0.32), colour = Color3.fromRGB(74, 64, 48) },
			{ size = Vector3.new(0.20, 0.90, 0.16), offset = CFrame.new(0.62, -0.05, 0.18), colour = Color3.fromRGB(74, 64, 48) },
		},
	},
	{
		id = "Cloak", name = "Traveller's Cloak", slot = "Back", price = 3400, rarity = "Rare",
		parts = {
			{ size = Vector3.new(1.70, 1.90, 0.22), offset = CFrame.new(0, -0.45, 0.26), colour = Color3.fromRGB(104, 56, 64) },
			{ size = Vector3.new(1.84, 0.30, 0.30), offset = CFrame.new(0, 0.52, 0.24), colour = Color3.fromRGB(78, 40, 48) },
		},
	},
	{
		-- Swept BACK and outward, in tapering segments. The first version was two flat
		-- slabs angled only on Z, which from behind read as a pair of yellow boards
		-- stapled to the character rather than wings.
		id = "Wings", name = "Ember Wings", slot = "Back", price = 12000, rarity = "Legendary",
		parts = {
			{ size = Vector3.new(1.50, 0.80, 0.14),
			  offset = CFrame.new(1.00, 0.35, 0.34) * CFrame.Angles(0, math.rad(-34), math.rad(26)),
			  colour = Color3.fromRGB(236, 132, 62), material = Enum.Material.Neon },
			{ size = Vector3.new(1.50, 0.80, 0.14),
			  offset = CFrame.new(-1.00, 0.35, 0.34) * CFrame.Angles(0, math.rad(34), math.rad(-26)),
			  colour = Color3.fromRGB(236, 132, 62), material = Enum.Material.Neon },
			{ size = Vector3.new(1.15, 0.58, 0.14),
			  offset = CFrame.new(1.95, -0.20, 0.74) * CFrame.Angles(0, math.rad(-46), math.rad(44)),
			  colour = Color3.fromRGB(248, 168, 88), material = Enum.Material.Neon },
			{ size = Vector3.new(1.15, 0.58, 0.14),
			  offset = CFrame.new(-1.95, -0.20, 0.74) * CFrame.Angles(0, math.rad(46), math.rad(-44)),
			  colour = Color3.fromRGB(248, 168, 88), material = Enum.Material.Neon },
			{ size = Vector3.new(0.78, 0.40, 0.14),
			  offset = CFrame.new(2.68, -0.78, 1.10) * CFrame.Angles(0, math.rad(-56), math.rad(58)),
			  colour = Color3.fromRGB(252, 204, 130), material = Enum.Material.Neon },
			{ size = Vector3.new(0.78, 0.40, 0.14),
			  offset = CFrame.new(-2.68, -0.78, 1.10) * CFrame.Angles(0, math.rad(56), math.rad(-58)),
			  colour = Color3.fromRGB(252, 204, 130), material = Enum.Material.Neon },
		},
	},
}

function CosmeticConfig.Get(id: string)
	for _, item in ipairs(CosmeticConfig.Items) do
		if item.id == id then
			return item
		end
	end
	return nil
end

function CosmeticConfig.InSlot(slot: string)
	local out = {}
	for _, item in ipairs(CosmeticConfig.Items) do
		if item.slot == slot then
			table.insert(out, item)
		end
	end
	return out
end

return CosmeticConfig
