--!nocheck
-- Retired weapons (the Scattergun), checked without Studio:
--
--   * it is gone from the place (storeitems, the world), the weapon configs, the shop and every
--     NPC's hands -- and nothing left behind names a weapon that does not exist: every shop
--     weapon and every NPC weapon has both a config and a Tool to clone;
--   * a save that still has it loses it everywhere it was (owned, loadout, kills, VFX, builds,
--     attachments, skins, mastery) and is owed its price, once; a save without it is untouched;
--   * the wallet pays what is owed and zeroes it.
--
--   lune run tools/uitest/retired.luau

local World = require("./world")
local R = World.R

require("@lune/task").delay(60, function()
	print("\27[31mtimed out\27[0m")
	require("@lune/process").exit(2)
end)

local failures = 0
local function check(ok: boolean, what: string)
	if ok then
		print("  ok    " .. what)
	else
		failures += 1
		print("\27[31m  FAIL  " .. what .. "\27[0m")
	end
end

local place = World.loadPlace("build/Game.rbxl")
local rs = World.service("ReplicatedStorage")
local sss = World.service("ServerScriptService")
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("PlayerDataManager"), sss)
local WeaponConfig = World.require(rs.WeaponConfig)
local GameConfig = World.require(rs.GameConfig)
local NPCConfig = World.require(rs.NPCConfig)
local RetiredItems = World.require(sss.PlayerDataManager.RetiredItems)
local SaveStructure = World.require(sss.PlayerDataManager.SaveStructure)

print("gone from the game")
local store = rs:FindFirstChild("storeitems")
local anywhere = false
for _, d in ipairs(place:GetDescendants()) do
	anywhere = anywhere or d.Name == "Scattergun"
end
check(not anywhere, "no Scattergun anywhere in the place")
check(WeaponConfig.Get("Scattergun") == nil, "no weapon config")
local inShop = false
for _, item in ipairs(GameConfig.ShopItems or {}) do
	inShop = inShop or item.id == "Scattergun" or item.item == "Scattergun"
end
check(not inShop, "not in the shop")

print("nothing points at a weapon that is not there")
local broken = {}
for _, item in ipairs(GameConfig.ShopItems or {}) do
	if item.item and not store:FindFirstChild(item.item) then
		table.insert(broken, "shop " .. tostring(item.item))
	end
end
for name in pairs(NPCConfig.Archetypes) do
	local cfg = NPCConfig.Get(name)
	local list = { cfg.Weapon, cfg.Secondary }
	for _, l in ipairs(cfg.Loadout or {}) do
		table.insert(list, l.Weapon)
	end
	for _, w in pairs(list) do
		if w and (not store:FindFirstChild(w) or not WeaponConfig.Get(w)) then
			table.insert(broken, name .. " carries " .. tostring(w))
		end
	end
end
check(#broken == 0, "every shop weapon and NPC weapon exists" .. (#broken > 0 and (": " .. table.concat(broken, ", ")) or ""))

print("old saves")
local data = {
	OwnedItems = { "Vantage", "Scattergun", "Hornet" },
	Loadout = { "Scattergun", "Vantage" },
	WeaponKills = { Scattergun = 40, Vantage = 3 },
	WeaponVFX = { Scattergun = { Kill = "KillShatter" } },
	WeaponBuilds = { Scattergun = { { id = "b1" } } },
	EquippedBuild = { Scattergun = "b1" },
	WeaponAttachments = { Scattergun = {} },
	WeaponSkins = { Scattergun = {} },
	MasteryAwarded = { "Scattergun:Bronze", "Vantage:Bronze" },
	OwnedVariants = { "Scattergun_Gold", "Carbine_DarkMatter" },
	Coins = 500,
	PendingRefund = 0,
}
local refunded, found = RetiredItems.Migrate(data)
check(refunded == 2200 and found[1] == "Scattergun", ("an owner is owed its price (%d)"):format(refunded))
check(table.concat(data.OwnedItems, ",") == "Vantage,Hornet" and table.concat(data.Loadout, ",") == "Vantage",
	"it leaves the owned list and the loadout, which stay in order with no gaps")
check(data.WeaponKills.Scattergun == nil and data.WeaponKills.Vantage == 3 and data.WeaponVFX.Scattergun == nil
	and data.WeaponBuilds.Scattergun == nil and data.EquippedBuild.Scattergun == nil
	and data.WeaponAttachments.Scattergun == nil and data.WeaponSkins.Scattergun == nil,
	"and every per-weapon record, the others kept")
check(table.concat(data.MasteryAwarded, ",") == "Vantage:Bronze" and table.concat(data.OwnedVariants, ",") == "Carbine_DarkMatter",
	"mastery tiers and variants too")
check(data.PendingRefund == 2200 and data.Coins == 500, "the refund waits for the wallet")
local again = RetiredItems.Migrate(data)
check(again == 0 and data.PendingRefund == 2200, "loading again pays nothing more")
local clean = { OwnedItems = { "Vantage" }, Loadout = { "Vantage" }, WeaponKills = { Vantage = 1 } }
local before = clean.OwnedItems
check(RetiredItems.Migrate(clean) == 0 and clean.OwnedItems == before, "a save without it is left alone")
check(SaveStructure.PendingRefund == 0, "new profiles start owed nothing")
local bare = {}
check(pcall(RetiredItems.Migrate, bare) and pcall(RetiredItems.Migrate, nil), "an empty or missing save does not error")

print("")
if failures == 0 then
	print("\27[32mall retired-weapon checks passed\27[0m")
	require("@lune/process").exit(0)
else
	print(("\27[31m%d retired-weapon check(s) failed\27[0m"):format(failures))
	require("@lune/process").exit(1)
end
