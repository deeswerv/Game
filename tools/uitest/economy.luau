--!nocheck
-- The economy, modelled from the real configs, without Studio: what a level is worth in coins
-- and what the shop asks, so prices stay matched to how fast money comes in.
--
--   * a level's coins from kills: the XP it needs, over the XP a kill pays, times the coins a
--     kill pays -- for the enemies of the level's own zone (NPCConfig, levelled), at the
--     game's XP rate (GameConfig);
--   * everything else (quests, stick-ups, bounties, bosses, contracts) about as much again;
--   * every gun costs between two and six levels of that at the level it unlocks -- a goal,
--     not loose change -- and each one dearer than the one before it unlocks;
--   * gear upgrades are dearer than the gun of the same level band, coin packs keep pace;
--   * a mid-life restock costs a small share of a level, so it is worth doing.
--
--   lune run tools/uitest/economy.luau

local World = require("./world")

local failures = 0
local function check(ok: boolean, what: string)
	if ok then
		print("  ok    " .. what)
	else
		failures += 1
		print("\27[31m  FAIL  " .. what .. "\27[0m")
	end
end

World.loadPlace("build/Game.rbxl")
local rs = World.service("ReplicatedStorage")
local GameConfig = World.require(rs.GameConfig)
local NPCConfig = World.require(rs.NPCConfig)
local GearConfig = World.require(rs.GearConfig)
local UtilityConfig = World.require(rs.UtilityConfig)

-- The ordinary enemies (not bosses, not guards): what a kill pays at enemy level `level`.
local crowd = {}
for name in pairs(NPCConfig.Archetypes) do
	local cfg = NPCConfig.Get(name)
	if cfg.CoinReward >= 10 and cfg.CoinReward <= 150 then
		table.insert(crowd, cfg)
	end
end
local function perKill(level: number): (number, number)
	local coins, xp = 0, 0
	for _, cfg in ipairs(crowd) do
		local l = NPCConfig.Levelled(cfg, level)
		coins += l.CoinReward
		xp += l.XPReward
	end
	return coins / #crowd, xp / #crowd * GameConfig.Leveling.XP_RATE
end
local OTHER = 2      -- quests, stick-ups, bounties, bosses: about as much again as kills

local function levelIncome(level: number): number
	local coins, xp = perKill(math.min(level, 16))
	local kills = GameConfig.GetRequiredEXP(level) / xp
	return kills * coins * OTHER
end

print("what a level is worth")
for _, l in ipairs({ 5, 10, 20, 30 }) do
	print(("    level %2d: about $%d a level (%d kills)"):format(l, levelIncome(l),
		GameConfig.GetRequiredEXP(l) / select(2, perKill(math.min(l, 16)))))
end

print("guns")
local guns = {}
for _, item in ipairs(GameConfig.ShopItems) do
	if item.price > 0 and item.levelRequired >= 6 then
		table.insert(guns, item)
	end
end
table.sort(guns, function(a, b)
	return a.levelRequired < b.levelRequired
end)
local allPriced, lastPrice, lastLevel = true, 0, 0
for _, item in ipairs(guns) do
	local levels = item.price / levelIncome(item.levelRequired)
	local fine = levels >= 2 and levels <= 6
	if not fine then
		allPriced = false
	end
	print(("    %-10s level %2d  $%6d  = %.1f levels of income%s"):format(item.name, item.levelRequired, item.price,
		levels, fine and "" or "  <-- out of band"))
end
check(allPriced, "every gun costs two to six levels of income at the level it unlocks")
local rising = true
for _, item in ipairs(guns) do
	if item.levelRequired > lastLevel and item.price < lastPrice * 0.75 then
		rising = false
		print("    falls: " .. item.name)
	end
	lastPrice, lastLevel = math.max(lastPrice, item.price), item.levelRequired
end
check(rising, "and a later gun is not a bargain next to an earlier one")

print("gear")
local gearFine = true
for _, item in ipairs(GearConfig.Items) do
	if item.coins > 0 then
		local levels = item.coins / levelIncome(item.level)
		if levels < 1.5 or levels > 12 then
			gearFine = false
			print(("    %s: %.1f levels"):format(item.id, levels))
		end
	end
end
check(gearFine, "each gear upgrade costs a few levels' income at its level, the top grades a long goal")

print("restocking")
local cheap = true
for _, item in ipairs(UtilityConfig.Restock.order) do
	for tier, _ in pairs(UtilityConfig.Restock.tierScale) do
		local price = UtilityConfig.RestockPrice(item, tier)
		if price <= 0 or price > levelIncome(10) * 0.5 then
			cheap = false
		end
	end
end
check(cheap, ("a restock is a small share of a level ($%d-$%d; a level at 10 pays $%d)"):format(
	UtilityConfig.RestockPrice("Smoke"), UtilityConfig.RestockPrice("Armour", "Mastery"), levelIncome(10)))

print("coin packs")
local packs = GameConfig.DeveloperProducts or {}
local pack = packs[1]
check(pack ~= nil and pack.coins >= levelIncome(10) * 0.5, ("the smallest coin pack keeps pace: $%d, half a level at 10"):format(pack and pack.coins or 0))

print(failures == 0 and "\27[32mall economy checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
require("@lune/process").exit(failures == 0 and 0 or 1)
