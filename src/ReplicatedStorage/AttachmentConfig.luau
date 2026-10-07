--!strict
-- Weapon attachments: what they are, which weapons take them, what they cost and do.
--
-- The catalogue is the twelve authored attachments for the Dark Matter carbine. Their
-- geometry is not here: each one is modelled for the weapon it was made for, piece by piece,
-- in AttachmentModels (generated from the artist's GLBs by tools/attachments/convert.py).
-- A weapon takes an attachment only when AttachmentModels has it fitted to that weapon, so
-- nothing is ever bolted on by guesswork.
--
-- The earlier catalogue -- block-built sights, muzzles, drums, stocks and the charms -- was
-- retired with this one. `Retired` below keeps what each of those sold for, so owners are
-- refunded in coins (ShopService.MigrateAttachments) rather than silently losing them.

local AttachmentConfig = {}

-- Slots, in the order the customisation screen shows them. "Side" is the rail on the side
-- of the handguard: the laser and the light live there, so either can be run with a grip.
AttachmentConfig.Slots = {
	"Sight", "Muzzle", "Underbarrel", "Side", "Magazine", "Stock",
}

AttachmentConfig.SlotLabels = {
	Sight = "Optic",
	Muzzle = "Muzzle",
	Underbarrel = "Underbarrel",
	Side = "Side Rail",
	Magazine = "Magazine",
	Stock = "Stock",
}

-- "None" is a real option in every slot that can be empty, so a slot can always be cleared.
-- The FIRST option in each slot is the stock part: free, owned by everyone.
local NONE = { id = "None", name = "None" }

AttachmentConfig.Options = {
	Sight = {
		{ id = "Irons", name = "Iron Sights" },
		{ id = "RedDot", name = "Red Dot" },
		{ id = "Holo", name = "Holographic" },
		{ id = "Scope4x", name = "4x Scope" },
	},
	Muzzle = {
		NONE,
		{ id = "Compensator", name = "Compensator" },
		{ id = "Suppressor", name = "Suppressor" },
	},
	Underbarrel = {
		NONE,
		{ id = "Foregrip", name = "Vertical Grip" },
		{ id = "Angled", name = "Angled Grip" },
		{ id = "Bipod", name = "Bipod" },
	},
	Side = {
		NONE,
		{ id = "Laser", name = "Laser Sight" },
		{ id = "Light", name = "Flashlight" },
	},
	Magazine = {
		{ id = "Standard", name = "Standard" },
		{ id = "Extended", name = "Extended Mag" },
	},
	Stock = {
		{ id = "Standard", name = "Standard" },
		{ id = "Skeleton", name = "Skeleton Stock" },
	},
}

-- What each attachment costs and how rare it is.
--
-- Kept as one table rather than a field on every option so the catalogue above stays a
-- plain list of what exists. The FIRST option in each slot is the stock part -- iron
-- sights, a bare muzzle, the standard magazine -- which is free and owned by everyone
-- without a purchase record, so a player can always strip a weapon back to standard.
AttachmentConfig.Pricing = {
	Sight = {
		Irons = { 0, "Common" }, RedDot = { 2200, "Uncommon" }, Holo = { 3800, "Rare" },
		Scope4x = { 8000, "Epic" },
	},
	Muzzle = {
		None = { 0, "Common" }, Compensator = { 3500, "Uncommon" }, Suppressor = { 8500, "Epic" },
	},
	Underbarrel = {
		None = { 0, "Common" }, Angled = { 2000, "Common" }, Foregrip = { 2800, "Uncommon" },
		Bipod = { 7000, "Epic" },
	},
	Side = {
		None = { 0, "Common" }, Light = { 3800, "Uncommon" }, Laser = { 5500, "Rare" },
	},
	Magazine = {
		Standard = { 0, "Common" }, Extended = { 4500, "Rare" },
	},
	Stock = {
		Standard = { 0, "Common" }, Skeleton = { 3500, "Uncommon" },
	},
}

-- The retired catalogue: every "Slot:Id" that used to exist and does not any more, with what
-- it sold for. An owner of one is refunded that many coins, once. Kept as data so the refund
-- is auditable and a key that was never sold (a stock part) can never be paid out.
AttachmentConfig.Retired = {
	["Sight:Scope2x"] = 2000, ["Sight:Sniper"] = 5000,
	["Muzzle:Flash"] = 700, ["Muzzle:Brake"] = 2000,
	["Magazine:Quick"] = 1000, ["Magazine:Drum"] = 3000,
	["Stock:Heavy"] = 1900, ["Stock:Folding"] = 900,
	["Charm:Dice"] = 500, ["Charm:Bolt"] = 700, ["Charm:Melon"] = 1000,
	["Charm:Star"] = 1200, ["Charm:Skull"] = 1600,
}

-- Attachments that kept their id but changed slot. The laser and the light hung under the
-- barrel in the old catalogue; the authored ones clamp to the side rail.
AttachmentConfig.Moved = {
	["Underbarrel:Laser"] = "Side:Laser",
	["Underbarrel:Light"] = "Side:Light",
}

--- A saved loadout brought up to the current catalogue: moved attachments follow their new
--- slot (unless that slot is already taken) and anything that no longer exists is dropped.
function AttachmentConfig.Normalise(loadout: { [string]: any }?): { [string]: string }
	local out: { [string]: string } = {}
	if type(loadout) ~= "table" then
		return out
	end
	for slot, id in pairs(loadout) do
		if type(slot) == "string" and type(id) == "string" and AttachmentConfig.Find(slot, id) then
			out[slot] = id
		end
	end
	for slot, id in pairs(loadout) do
		if type(slot) == "string" and type(id) == "string" then
			local moved = AttachmentConfig.Moved[slot .. ":" .. id]
			local newSlot, newId = (moved or ""):match("^(%a+):(%w+)$")
			if newSlot and newId and out[newSlot] == nil then
				out[newSlot] = newId
			end
		end
	end
	return out
end

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
-- costs you the speed of getting on target, an extended mag costs you the reload, a
-- suppressor costs you range and a little damage.
--
-- Bear in mind which way is better for each number: Damage, MagazineSize and Range are
-- better higher; FireRate, ReloadTime, the spreads and the recoils are better LOWER, so a
-- multiplier below 1 on those is an improvement.
AttachmentConfig.Stats = {
	Sight = {
		Irons = nil,
		RedDot  = { SpreadMin = { mul = 0.92 } },
		Holo    = { SpreadMin = { mul = 0.88 }, AdsFov = { mul = 0.97 } },
		Scope4x = { SpreadMin = { mul = 0.72 }, AdsFov = { mul = 0.78 },
		            AdsWalkSpeedScale = { mul = 0.90 }, AdsSpeed = { mul = 0.85 } },
	},
	Muzzle = {
		None = nil,
		Compensator = { RecoilPitch = { mul = 0.82 }, RecoilYaw = { mul = 0.85 } },
		-- Quiet, and you pay for it at the far end of the range band.
		Suppressor  = { Range = { mul = 0.88 }, Damage = { mul = 0.94 },
		                RecoilPitch = { mul = 0.88 }, SpreadMin = { mul = 0.94 } },
	},
	Underbarrel = {
		None = nil,
		Foregrip = { RecoilPitch = { mul = 0.86 }, SpreadPerShot = { mul = 0.90 },
		             AdsSpeed = { mul = 0.96 } },
		Angled   = { AdsSpeed = { mul = 1.12 }, SpreadMin = { mul = 1.04 } },
		Bipod    = { RecoilPitch = { mul = 0.72 }, RecoilRecovery = { mul = 1.15 },
		             AdsWalkSpeedScale = { mul = 0.90 } },
	},
	-- The side rail is hip-fire help: a laser tightens the cone you shoot from the hip, a
	-- light a little less so.
	Side = {
		None = nil,
		Laser = { SpreadMin = { mul = 0.80 }, SpreadMax = { mul = 0.92 } },
		Light = { SpreadMin = { mul = 0.95 } },
	},
	Magazine = {
		Standard = nil,
		Extended = { MagazineSize = { add = 10 }, ReloadTime = { mul = 1.12 },
		             AdsSpeed = { mul = 0.96 } },
	},
	Stock = {
		Standard = nil,
		Skeleton = { AdsSpeed = { mul = 1.15 }, AdsWalkSpeedScale = { mul = 1.06 },
		             RecoilPitch = { mul = 1.08 } },
	},
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
