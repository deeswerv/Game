--!nocheck
-- Daily contracts are dealt fairly: one of each tier, the same for a given day everywhere,
-- different from one day to the next, and every contract in the pool turns up.
--
--   lune run tools/uitest/contracts.luau

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
local ContractConfig = World.require(World.service("ReplicatedStorage").ContractConfig)

local seen, repeats = {}, 0
local previous = nil
for day = 20000, 20120 do
	local deal = ContractConfig.Deal(day)
	local tiers = {}
	for i, id in ipairs(deal) do
		local c = ContractConfig.Get(id)
		tiers[i] = c and c.tier
		seen[id] = true
	end
	if tiers[1] ~= "Easy" or tiers[2] ~= "Medium" or tiers[3] ~= "Hard" then
		check(false, ("day %d deals one of each tier"):format(day))
	end
	local again = ContractConfig.Deal(day)
	if table.concat(again, ",") ~= table.concat(deal, ",") then
		check(false, ("day %d deals the same set twice"):format(day))
	end
	if previous and table.concat(previous, ",") == table.concat(deal, ",") then
		repeats += 1
	end
	previous = deal
end
check(true, "every day deals Easy, Medium, Hard, deterministically")
check(repeats < 12, ("consecutive days rarely repeat the whole set (%d of 120)"):format(repeats))
local missing = {}
for _, c in ipairs(ContractConfig.Pool) do
	if not seen[c.id] then
		table.insert(missing, c.id)
	end
	check(c.target > 0 and c.reward.coins > 0 and c.reward.xp > 0, c.id .. " has a target and pays")
end
check(#missing == 0, "every contract comes up over four months" .. (#missing > 0 and (": missing " .. table.concat(missing, ", ")) or ""))

print(failures == 0 and "\27[32mall contract checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
if failures > 0 then
	error("contract checks failed")
end
