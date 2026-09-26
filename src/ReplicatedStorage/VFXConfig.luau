--!strict
-- VFX sold in the shop: what your kills and your rounds look like to everyone.
--
-- Two slots, one effect in each:
--
--   Kill    plays on the body of anyone you eliminate, for everyone who can see it.
--   Tracer  the look of every round you fire: its colour, how long its streak is, whether
--           it leaves a vapour line, and for the top tier, a colour that changes every shot.
--
-- Purely visual, and deliberately so: a tracer never changes how fast a round travels or
-- where it goes, and a kill effect never hides the body for longer than a death already does.
-- Mastery Weapons that ship their own authored tracer keep it -- that look is what the
-- weapon is.
--
-- Owned ids are saved in the profile's OwnedVFX; the equipped one per slot in EquippedVFX, and
-- published as the player attributes VFX_Kill and VFX_Tracer so every client can draw them.

local VFXConfig = {}

VFXConfig.Slots = { "Kill", "Tracer" }

VFXConfig.SlotLabels = { Kill = "Kill effect", Tracer = "Tracer" }

-- The attribute each slot is published as.
VFXConfig.Attribute = { Kill = "VFX_Kill", Tracer = "VFX_Tracer" }

export type Item = {
	id: string,
	name: string,
	slot: string,
	price: number,
	rarity: string,
	icon: string,
	desc: string,
	-- Tracer look: colour, and multipliers on the weapon's own width and streak length.
	colour: Color3?,
	width: number?,
	streak: number?,
	trail: number?,       -- vapour line strength (0 none .. 1 a sniper's)
	prismatic: boolean?,  -- a new hue every shot
}

VFXConfig.Items = {
	-- Kill effects, cheapest first.
	{ id = "KillShatter", name = "Shatter", slot = "Kill", price = 900, rarity = "Common", icon = "💥",
		desc = "The body breaks into shards" },
	{ id = "KillConfetti", name = "Confetti", slot = "Kill", price = 1800, rarity = "Uncommon", icon = "🎉",
		desc = "A party popper goes off" },
	{ id = "KillLightning", name = "Thunderstrike", slot = "Kill", price = 3200, rarity = "Rare", icon = "⚡",
		desc = "Lightning comes down on them" },
	{ id = "KillVoid", name = "Void", slot = "Kill", price = 5500, rarity = "Epic", icon = "🌀",
		desc = "Pulled into a collapsing void" },
	{ id = "KillGemstone", name = "Gem Charge", slot = "Kill", price = 9000, rarity = "Legendary", icon = "💎",
		desc = "Crystal draws in, then bursts" },

	-- Tracers.
	{ id = "TracerCrimson", name = "Crimson", slot = "Tracer", price = 700, rarity = "Common", icon = "🔴",
		desc = "Hot red rounds", colour = Color3.fromRGB(255, 70, 64) },
	{ id = "TracerGold", name = "Gold Rush", slot = "Tracer", price = 1500, rarity = "Uncommon", icon = "🟡",
		desc = "Heavier gold rounds", colour = Color3.fromRGB(255, 196, 60), width = 1.25 },
	{ id = "TracerPlasma", name = "Plasma", slot = "Tracer", price = 2800, rarity = "Rare", icon = "🔵",
		desc = "Long electric-blue streaks", colour = Color3.fromRGB(70, 200, 255), width = 1.2, streak = 1.6 },
	{ id = "TracerToxic", name = "Toxic", slot = "Tracer", price = 4200, rarity = "Epic", icon = "🟢",
		desc = "Acid green, leaves a haze", colour = Color3.fromRGB(120, 255, 90), width = 1.3, streak = 1.3, trail = 0.6 },
	{ id = "TracerPrismatic", name = "Prismatic", slot = "Tracer", price = 8000, rarity = "Legendary", icon = "🌈",
		desc = "A new colour every shot", colour = Color3.fromRGB(255, 120, 220), width = 1.35, streak = 1.5,
		trail = 0.4, prismatic = true },
} :: { Item }

local byId: { [string]: Item } = {}
for _, item in ipairs(VFXConfig.Items) do
	byId[item.id] = item
end

function VFXConfig.Get(id: string?): Item?
	return if type(id) == "string" then byId[id] else nil
end

--- The tracer look for a shot, or nil to keep the weapon's own. `shot` varies the prismatic
--- colour from one round to the next.
function VFXConfig.TracerStyle(id: string?, shot: number?): Item?
	local item = VFXConfig.Get(id)
	if not item or item.slot ~= "Tracer" then
		return nil
	end
	if item.prismatic then
		local hue = ((shot or 0) * 0.137) % 1
		local tinted = table.clone(item)
		tinted.colour = Color3.fromHSV(hue, 0.75, 1)
		return tinted
	end
	return item
end

return VFXConfig
