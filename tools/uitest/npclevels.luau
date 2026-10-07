--!nocheck
-- Enemy levels (NPCConfig.Levelled): a higher-level enemy is tougher AND fights better --
-- more accurate, quicker to react, quicker to settle its aim -- within limits, so a level-30
-- Thug is dangerous rather than a turret.
--
--   lune run tools/uitest/npclevels.luau

local process = require("@lune/process")
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
local NPCConfig = World.require(World.service("ReplicatedStorage").NPCConfig)

for _, name in ipairs({ "Thug", "Gangster", "Shooter", "Enforcer" }) do
	local cfg = NPCConfig.Get(name)
	local one, ten, fifty = NPCConfig.Levelled(cfg, 1), NPCConfig.Levelled(cfg, 10), NPCConfig.Levelled(cfg, 50)
	check(one.ReactionTime == (cfg.ReactionTime or 0.45) and one.AimTime == (cfg.AimTime or 0.25),
		name .. ": level 1 is the archetype as written")
	check(ten.ReactionTime < one.ReactionTime and ten.AimTime < one.AimTime and ten.Accuracy > one.Accuracy and ten.MaxHealth > one.MaxHealth,
		("%s: level 10 is quicker (%.2fs -> %.2fs), steadier and tougher"):format(name, one.ReactionTime, ten.ReactionTime))
	check(fifty.ReactionTime >= one.ReactionTime * 0.65 and fifty.Accuracy <= 0.92,
		name .. ": but never inhuman, however high")
end

print(if failures == 0 then "\27[32mall npc level checks passed\27[0m" else ("\27[31m%d failed\27[0m"):format(failures))
process.exit(if failures == 0 then 0 else 1)
