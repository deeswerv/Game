--!strict
-- Gear: what ZEE TACTICS sells. Three slots -- the heal you carry, the armour you wear, the
-- bomb in your throw slot -- and six grades of each, Common to Mastery.
--
-- The Common of each is what everybody already has (the medkit, no armour to start with, the
-- frag): owned from the start, free, and what a duel always uses so a duel stays even. Each
-- grade above it is a real step -- more healing, faster; more armour to start a life with and
-- a higher cap; a bomb that does something the frag cannot -- priced so the first upgrade is
-- an afternoon's work and a Mastery piece is a long-term goal.
--
-- Shared: GearService charges and equips, UtilityService plays the numbers, and the shop, the
-- inventory and the HUD all draw from the same table.

local GearConfig = {}

GearConfig.Slots = { "Heal", "Armor", "Bomb" }
GearConfig.SlotInfo = {
	Heal = { label = "Heals", icon = "✚", blurb = "What you patch up with (Z). More healing, faster, more of them." },
	Armor = { label = "Armor", icon = "🛡", blurb = "Armour you start each life with, and how much you can carry." },
	Bomb = { label = "Bombs", icon = "💣", blurb = "What your throw slot (F) holds. Each kind goes off its own way." },
}

GearConfig.Tiers = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mastery" }
GearConfig.TierColour = {
	Common = Color3.fromRGB(150, 158, 172),
	Uncommon = Color3.fromRGB(46, 200, 84),
	Rare = Color3.fromRGB(46, 150, 255),
	Epic = Color3.fromRGB(176, 76, 255),
	Legendary = Color3.fromRGB(255, 170, 20),
	Mastery = Color3.fromRGB(255, 56, 96),
}

export type Gear = {
	id: string,
	slot: string,
	tier: string,
	name: string,
	icon: string,
	blurb: string,
	level: number,
	coins: number,
	crystals: number,
	stats: { [string]: any },
}

-- Heal stats:  heal (HP), channel (seconds), perLife, armour (added on use)
-- Armor stats: start (armour each life begins with), max (the cap), plate (a pickup's worth)
-- Bomb stats:  style, damage, radius, fuse, perLife, and whatever the style needs:
--   frag        bounces, then goes off on its fuse
--   impact      goes off the moment it lands
--   sticky      stops dead on the first thing it hits, then goes off
--   cluster     a blast, then `bomblets` smaller ones scattered round it
--   incendiary  a blast, then a patch of fire (`burn` damage a second, for `burnTime`)
--   singularity drags everyone near it in, then goes off hard
GearConfig.Items = {
	-- ------------------------------------------------------------------ heals --
	{ id = "Heal_FieldMedkit", slot = "Heal", tier = "Common", name = "Field Medkit", icon = "✚",
		blurb = "The kit everybody carries. Patches you up, eventually.",
		level = 1, coins = 0, crystals = 0, stats = { heal = 50, channel = 1.2, perLife = 2 } },
	{ id = "Heal_TraumaKit", slot = "Heal", tier = "Uncommon", name = "Trauma Kit", icon = "🩹",
		blurb = "Proper dressings. More back, a little quicker.",
		level = 3, coins = 2500, crystals = 0, stats = { heal = 65, channel = 1.05, perLife = 2 } },
	{ id = "Heal_CombatStim", slot = "Heal", tier = "Rare", name = "Combat Stim", icon = "💉",
		blurb = "A shot to the leg and back in the fight. Three a life.",
		level = 6, coins = 7500, crystals = 0, stats = { heal = 70, channel = 0.8, perLife = 3 } },
	{ id = "Heal_NanoInjector", slot = "Heal", tier = "Epic", name = "Nano Injector", icon = "🧪",
		blurb = "Stitches you from the inside. Nearly a full bar in under a second.",
		level = 10, coins = 16500, crystals = 0, stats = { heal = 85, channel = 0.7, perLife = 3 } },
	{ id = "Heal_PhoenixSerum", slot = "Heal", tier = "Legendary", name = "Phoenix Serum", icon = "🔥",
		blurb = "Everything back, fast. Street doctors would kill for it.",
		level = 15, coins = 36000, crystals = 8, stats = { heal = 100, channel = 0.6, perLife = 3 } },
	{ id = "Heal_ZeeElixir", slot = "Heal", tier = "Mastery", name = "Zee Elixir", icon = "💠",
		blurb = "A full heal and a plate of armour in one. Four a life.",
		level = 22, coins = 72000, crystals = 30, stats = { heal = 100, channel = 0.5, perLife = 4, armour = 25 } },

	-- ------------------------------------------------------------------ armor --
	{ id = "Armor_Padded", slot = "Armor", tier = "Common", name = "Padded Jacket", icon = "🧥",
		blurb = "No armour to start with; plates you pick up fill three bars.",
		level = 1, coins = 0, crystals = 0, stats = { start = 0, max = 75, plate = 25 } },
	{ id = "Armor_Kevlar", slot = "Armor", tier = "Uncommon", name = "Kevlar Vest", icon = "🦺",
		blurb = "Start every life with one bar of armour already on.",
		level = 3, coins = 3500, crystals = 0, stats = { start = 25, max = 75, plate = 25 } },
	{ id = "Armor_Carrier", slot = "Armor", tier = "Rare", name = "Plate Carrier", icon = "🛡",
		blurb = "Two bars on from the start, and room for a fourth.",
		level = 6, coins = 9000, crystals = 0, stats = { start = 50, max = 100, plate = 25 } },
	{ id = "Armor_Riot", slot = "Armor", tier = "Epic", name = "Riot Rig", icon = "🪖",
		blurb = "Built to walk into a crew's fire. Carries five bars.",
		level = 10, coins = 19500, crystals = 0, stats = { start = 50, max = 125, plate = 25 } },
	{ id = "Armor_Juggernaut", slot = "Armor", tier = "Legendary", name = "Juggernaut Plates", icon = "🏋",
		blurb = "Three bars on from the start, six at most. Heavy, and worth it.",
		level = 15, coins = 42000, crystals = 8, stats = { start = 75, max = 150, plate = 30 } },
	{ id = "Armor_TitanWeave", slot = "Armor", tier = "Mastery", name = "Titan Weave", icon = "💎",
		blurb = "Four bars from the start, and every plate you find is worth more.",
		level = 22, coins = 78000, crystals = 30, stats = { start = 100, max = 150, plate = 40 } },

	-- ------------------------------------------------------------------ bombs --
	{ id = "Bomb_Frag", slot = "Bomb", tier = "Common", name = "Frag Grenade", icon = "💣",
		blurb = "Bounces, then goes off. The one everybody knows.",
		level = 1, coins = 0, crystals = 0,
		stats = { style = "frag", damage = 110, radius = 16, fuse = 2.1, perLife = 2 } },
	{ id = "Bomb_Impact", slot = "Bomb", tier = "Uncommon", name = "Impact Grenade", icon = "🎯",
		blurb = "No fuse to wait out: it goes off the moment it lands.",
		level = 4, coins = 3000, crystals = 0,
		stats = { style = "impact", damage = 100, radius = 14, fuse = 0.1, perLife = 2 } },
	{ id = "Bomb_Sticky", slot = "Bomb", tier = "Rare", name = "Sticky Bomb", icon = "🧲",
		blurb = "Sticks to whatever it hits -- a wall, a car, a Capo -- and goes off hard.",
		level = 7, coins = 8000, crystals = 0,
		stats = { style = "sticky", damage = 140, radius = 15, fuse = 1.6, perLife = 2 } },
	{ id = "Bomb_Cluster", slot = "Bomb", tier = "Epic", name = "Cluster Bomb", icon = "🎆",
		blurb = "One blast, then four more scattered round it. Clears a crew off a corner.",
		level = 11, coins = 18000, crystals = 0,
		stats = { style = "cluster", damage = 90, radius = 14, fuse = 1.8, perLife = 2,
			bomblets = 4, bombletDamage = 50, bombletRadius = 9, spread = 8 } },
	{ id = "Bomb_Incendiary", slot = "Bomb", tier = "Legendary", name = "Incendiary", icon = "🧯",
		blurb = "A blast and a patch of fire nobody wants to stand in for six seconds.",
		level = 16, coins = 39000, crystals = 8,
		stats = { style = "incendiary", damage = 70, radius = 12, fuse = 1.4, perLife = 2,
			burn = 24, burnTime = 6, burnRadius = 11 } },
	{ id = "Bomb_Singularity", slot = "Bomb", tier = "Mastery", name = "Singularity Charge", icon = "🌀",
		blurb = "Drags everything near it into one spot, then erases the spot.",
		level = 24, coins = 75000, crystals = 30,
		stats = { style = "singularity", damage = 170, radius = 20, fuse = 1.5, perLife = 2, pull = 24, pullTime = 1 } },
} :: { Gear }

local byId: { [string]: Gear } = {}
for _, item in ipairs(GearConfig.Items) do
	byId[item.id] = item
end

GearConfig.Default = { Heal = "Heal_FieldMedkit", Armor = "Armor_Padded", Bomb = "Bomb_Frag" }

function GearConfig.Get(id: string?): Gear?
	return id and byId[id] or nil
end

--- The items of one slot, cheapest (Common) first.
function GearConfig.ForSlot(slot: string): { Gear }
	local out = {}
	for _, item in ipairs(GearConfig.Items) do
		if item.slot == slot then
			table.insert(out, item)
		end
	end
	return out
end

--- Owned from the start: the Common of each slot.
function GearConfig.IsFree(id: string): boolean
	local item = byId[id]
	return item ~= nil and item.coins == 0 and item.crystals == 0
end

--- The equipped item of `slot` given a saved choice, falling back to the Common one when the
--- choice is missing, unknown, in another slot or not owned.
function GearConfig.Resolve(slot: string, chosen: string?, owns: ((string) -> boolean)?): Gear
	local item = chosen and byId[chosen]
	if item and item.slot == slot and (GearConfig.IsFree(item.id) or owns == nil or owns(item.id)) then
		return item
	end
	return byId[GearConfig.Default[slot]]
end

function GearConfig.TierIndex(tier: string): number
	return table.find(GearConfig.Tiers, tier) or 1
end

--- One line of what an item does, for the shop card.
function GearConfig.Describe(item: Gear): { string }
	local s = item.stats
	if item.slot == "Heal" then
		local lines = { ("+%d HP"):format(s.heal), ("%.1fs to use"):format(s.channel), ("%d a life"):format(s.perLife) }
		if s.armour then
			table.insert(lines, ("+%d armour"):format(s.armour))
		end
		return lines
	elseif item.slot == "Armor" then
		return { ("starts at %d"):format(s.start), ("carries %d"):format(s.max), ("plates +%d"):format(s.plate) }
	end
	local lines = { ("%d damage"):format(s.damage), ("%d stud blast"):format(s.radius), ("%d a life"):format(s.perLife) }
	if s.style == "cluster" then
		table.insert(lines, ("+%d bomblets"):format(s.bomblets))
	elseif s.style == "incendiary" then
		table.insert(lines, ("fire %ds"):format(s.burnTime))
	elseif s.style == "singularity" then
		table.insert(lines, "pulls them in")
	end
	return lines
end

return GearConfig
