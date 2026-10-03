--!strict
-- Weapons taken out of the game, and what happens to the saves that still mention them.
--
-- A profile saved while a weapon existed can name it in a dozen places: owned, in the
-- loadout, kill counts, per-weapon VFX, builds, attachments, skins, mastery tiers. Every
-- one of those is read somewhere that expects the weapon to exist (the hotbar asks for its
-- config, the profile card for its rarity, the workshop for its parts), so a stale entry
-- is an error waiting for whoever owned it. This strips them all on load, before anything
-- reads the profile, and pays back what the weapon cost -- once, because a second load no
-- longer finds it to refund.

local RetiredItems = {}

-- Id -> what an owner is paid back for it.
RetiredItems.Weapons = {
	Scattergun = { refund = 2200 },
} :: { [string]: { refund: number } }

local function stripArray(list: any, drop: (any) -> boolean): (any, boolean)
	if type(list) ~= "table" then
		return list, false
	end
	local out = {}
	local changed = false
	for _, value in ipairs(list) do
		if drop(value) then
			changed = true
		else
			table.insert(out, value)
		end
	end
	return if changed then out else list, changed
end

-- Per-weapon dictionaries: keyed by the weapon's id.
local KEYED = {
	"WeaponKills", "WeaponVFX", "WeaponBuilds", "EquippedBuild", "WeaponAttachments", "WeaponSkins",
}

--- Clean `data` (a profile's Data, before it is replicated) of every retired weapon. Returns
--- the coins refunded and the ids that were found.
function RetiredItems.Migrate(data: any): (number, { string })
	local refunded, found = 0, {}
	if type(data) ~= "table" then
		return 0, found
	end
	for id, info in pairs(RetiredItems.Weapons) do
		local owned = false
		data.OwnedItems, owned = stripArray(data.OwnedItems, function(v)
			return v == id
		end)
		data.Loadout = (stripArray(data.Loadout, function(v)
			return v == id
		end))
		data.Inventory = (stripArray(data.Inventory, function(v)
			return v == id
		end))
		data.OwnedVariants = (stripArray(data.OwnedVariants, function(v)
			return type(v) == "string" and v:sub(1, #id + 1) == id .. "_"
		end))
		data.MasteryAwarded = (stripArray(data.MasteryAwarded, function(v)
			return type(v) == "string" and v:sub(1, #id + 1) == id .. ":"
		end))
		for _, key in ipairs(KEYED) do
			local dict = data[key]
			if type(dict) == "table" and dict[id] ~= nil then
				dict[id] = nil
			end
		end
		if owned then
			table.insert(found, id)
			refunded += info.refund
		end
	end
	if refunded > 0 then
		-- Paid by WalletService once the balance is settled (it may still be moving off the
		-- old leaderstats store, which takes the highest figure and would swallow it).
		data.PendingRefund = (tonumber(data.PendingRefund) or 0) + refunded
	end
	return refunded, found
end

return RetiredItems
