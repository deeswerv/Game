--!nocheck
-- Gun handling numbers (GunHandling), checked against every real weapon:
--
--   running and jumping open the cone, aiming steadies only part of that, a rested weapon
--   fires its first round tighter (a sniper only when scoped), shotguns get no first-shot
--   bonus, tactical reloads are quicker than dry ones, and penetration follows the class.
--
--   lune run tools/uitest/guns.luau

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
local WeaponConfig = World.require(rs.WeaponConfig)
local GunHandling = World.require(rs.GunHandling)

local names = {}
for name, entry in pairs(WeaponConfig.Weapons) do
	if (entry.Type or "Gun") == "Gun" then
		table.insert(names, name)
	end
end
table.sort(names)

for _, name in ipairs(names) do
	local cfg = WeaponConfig.Get(name)
	local traits = GunHandling.Traits(cfg)
	print(("%s (%s)"):format(name, cfg.Class))
	local rest = GunHandling.RestTime(cfg) + 0.01
	local still = GunHandling.Spread(cfg, 0, false, 0, false, rest)
	local busy = GunHandling.Spread(cfg, 0, false, 0, false, 0)
	local running = GunHandling.Spread(cfg, 0, false, 20, false, 0)
	local jumping = GunHandling.Spread(cfg, 0, false, 0, true, 0)
	local adsRunning = GunHandling.Spread(cfg, 0, true, 20, false, 0)
	local adsStill = GunHandling.Spread(cfg, 0, true, 0, false, 0)

	check(running > busy, ("running opens the cone (%.2f -> %.2f)"):format(busy, running))
	check(jumping > running or traits.JumpSpread >= traits.MoveSpread, ("jumping opens it more (%.2f)"):format(jumping))
	check(adsRunning - adsStill < running - busy, "aiming steadies the movement part")
	check(adsRunning - adsStill > 0, "but not all of it")
	if cfg.Class == "Shotgun" then
		check(math.abs(still - busy) < 1e-6, "no first-shot bonus for pellets")
	elseif cfg.Class == "Sniper" then
		check(math.abs(still - busy) < 1e-6, "no free no-scope: hip fire gets no first-shot bonus")
		local adsRested = GunHandling.Spread(cfg, 0, true, 0, false, rest)
		check(adsRested < adsStill, "scoped and rested is tighter")
	else
		check(still < busy, ("a rested weapon fires tighter (%.2f vs %.2f)"):format(still, busy))
	end
	-- Heat past the threshold loses the bonus.
	local hot = GunHandling.Spread(cfg, cfg.SpreadPerShot, false, 0, false, rest)
	check(hot >= busy - 1e-6, "a hot weapon is not rested")

	local tactical, isTactical = GunHandling.ReloadTime(cfg, 3)
	local dry, isDry = GunHandling.ReloadTime(cfg, 0)
	check(isTactical and not isDry and tactical < dry, ("tactical reload %.2fs < dry %.2fs"):format(tactical, dry))
end

local rifle = GunHandling.Traits({ Class = "Rifle" })
local pistol = GunHandling.Traits({ Class = "Pistol" })
local shotgun = GunHandling.Traits({ Class = "Shotgun" })
local sniper = GunHandling.Traits({ Class = "Sniper" })
print("penetration")
check(sniper.Penetration > rifle.Penetration and rifle.Penetration > pistol.Penetration
	and shotgun.Penetration == 0, "sniper > rifle > pistol, shotgun none")
local crateCost = 3.6 * GunHandling.Hardness.WoodPlanks
local barrierCost = 2.4 * GunHandling.Hardness.Concrete
check(sniper.Penetration >= crateCost and rifle.Penetration < crateCost, "a sniper goes through a wooden crate, a rifle does not")
check(sniper.Penetration < barrierCost, "nothing goes through a concrete barrier")
check(rifle.Penetration >= 0.5 * GunHandling.Hardness.Wood, "a rifle goes through a plank door")

print(failures == 0 and "\27[32mall gun checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
if failures > 0 then
	error("gun checks failed")
end
