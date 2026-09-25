--!nocheck
-- Levels, prestige, coins and the owner panel's commands, checked without Studio:
--
--   * the cap is 50 and every level gate, milestone and road node fits under it;
--   * XP rolls over by the real curve and stops at the cap; each prestige adds 5% to XP;
--   * a profile above the old cap lands on 50 with its extra XP banked, not lost;
--   * prestige needs the cap, resets the level only, and pays coins, crystals and a title;
--   * a level set from the owner panel reaches everything that reads a level -- the profile,
--     the Stats mirror, the Level attribute the shop reads -- so the shop's gate opens;
--   * coins are kept on the profile (WalletService): migrated once, then every change saved;
--   * the owner commands go through those paths and save the profile at once.
--
-- PlayerDataManager is stood in for by a plain table profile (the real one needs DataStores);
-- everything else is the game's own code.
--
--   lune run tools/uitest/progression.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R

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
local player = World.player

-- ------------------------------------------------------ a stand-in profile --

local profile = {
	Level = 73, EXP = 1200, MaxEXP = 100, StatPoints = 0, Prestige = 0, LifetimeXP = 0,
	Crystals = 0, Titles = {}, OwnedItems = {}, Coins = 0, CoinsMigrated = false, TotalKills = 0,
	Reputation = {},
}
local saves = 0
local stub = R.new("ModuleScript")
stub.Name = "PlayerDataManager"
stub.Source = [[
local data = {}
local onSave = function() end
local listeners = {}
local Replica = { Data = data }
function Replica:SetValue(key, value)
	data[key] = value
	for _, fn in ipairs(listeners[key] or {}) do
		fn(value)
	end
end
function Replica:ListenToChange(key, fn)
	listeners[key] = listeners[key] or {}
	table.insert(listeners[key], fn)
end
function Replica:IsActive()
	return true
end
local function promise()
	local p = {}
	function p:andThen(fn)
		local ok, err = pcall(fn, Replica)
		return { catch = function(_, handler)
			if not ok then
				handler(err)
			end
		end }
	end
	function p:expect()
		return Replica
	end
	return p
end
local PDM = {}
function PDM.Bind(profile, saved)
	data = profile
	Replica.Data = profile
	onSave = saved
end
function PDM:GetPlayerDataReplica(_player)
	return promise()
end
function PDM:SaveNow(_player)
	onSave()
	return true
end
function PDM:IsSaving()
	return true
end
return PDM
]]
stub.Parent = sss
World.require(stub).Bind(profile, function()
	saves += 1
end)

-- Server-side remote calls, which the client harness does not model: recorded, not sent.
local toClients = {}
R.ClassMethods.RemoteEvent.FireClient = function(self, _player, ...)
	table.insert(toClients, { name = self.Name, args = { ... } })
end
R.ClassMethods.RemoteEvent.FireAllClients = function(self, ...)
	table.insert(toClients, { name = self.Name, args = { ... } })
end

for _, name in ipairs({ "KillCredit", "ShopService", "ReputationService", "LevelSystem", "WalletService", "AdminService",
	"AbilityService" }) do
	R.mirror(place:GetService("ServerScriptService"):FindFirstChild(name), sss)
end

-- The player's leaderstats and Stats mirror, as the legacy scripts make them.
local leaderstats = player:FindFirstChild("leaderstats")
local coins = leaderstats:FindFirstChild("Coins")
coins.Value = 0
local statsFolder = R.new("Folder")
statsFolder.Name = "Stats"
for _, key in ipairs({ "Level", "EXP", "MaxEXP", "StatPoints" }) do
	local v = R.new("IntValue")
	v.Name = key
	v.Parent = statsFolder
end
statsFolder.Parent = player

local GameConfig = World.require(rs.GameConfig)
local ProgressionConfig = World.require(rs.ProgressionConfig)

-- ---------------------------------------------------------------- config --

print("the cap")
local cap = GameConfig.Leveling.MAX_LEVEL
check(cap == 50 and GameConfig.Prestige.REQUIRED_LEVEL == 50, "max level 50, and prestige opens there")
local gatesOk = true
for _, item in ipairs(GameConfig.ShopItems) do
	if (item.levelRequired or 1) > cap then
		gatesOk = false
		print("    " .. item.id .. " needs level " .. item.levelRequired)
	end
end
check(gatesOk, "every weapon's level gate is reachable")
local milestonesOk = true
for level in pairs(ProgressionConfig.Milestones) do
	if level > cap or level < ProgressionConfig.FirstMilestoneLevel then
		milestonesOk = false
	end
end
check(milestonesOk and ProgressionConfig.RewardFor(cap).title == "Centurion", "every milestone is at 31-50; 50 pays Centurion")
local total = 0
for lv = 1, cap - 1 do
	total += GameConfig.GetRequiredEXP(lv)
end
check(total > 250000 and total < 600000, ("level 1 to 50 is %d XP"):format(total))
local r1, r2 = GameConfig.PrestigeReward(1), GameConfig.PrestigeReward(2)
check(r1.coins == 5000 and r1.crystals == 10 and r1.title == "Bronze Prestige" and r2.coins > r1.coins,
	"prestige pays more each time, with the tier's title")
check(math.abs(GameConfig.PrestigeXPMultiplier(3) - 1.15) < 1e-9, "three prestiges make XP worth 15% more")

-- ----------------------------------------------------------- level system --

local LevelSystem = World.require(sss.LevelSystem)
World.advance(0.2)

print("loading a profile from above the old cap")
check(profile.Level == 50 and profile.EXP == 0, ("level 73 comes back as 50 (%d)"):format(profile.Level))
check(profile.LifetimeXP > 1200, "with the XP past the cap banked in the lifetime total")
check(player:GetAttribute("Level") == 50 and statsFolder.Level.Value == 50, "and published as 50")

print("prestige")
local ok, result = LevelSystem.Prestige(player)
check(ok and type(result) == "table" and result.prestige == 1, "at the cap, prestige goes through")
check(profile.Level == 1 and profile.Prestige == 1 and player:GetAttribute("Prestige") == 1, "level back to 1, prestige 1")
check(coins.Value == 5000 and profile.Crystals == 10 and table.find(profile.Titles, "Bronze Prestige") ~= nil,
	"paid 5,000 coins, 10 crystals and the Bronze Prestige title")
local announced = false
for _, sent in ipairs(toClients) do
	if sent.name == "PrestigeChanged" and sent.args[2] == 1 then
		announced = true
	end
end
check(announced, "and everyone is told")
local again, why = LevelSystem.Prestige(player)
check(not again and tostring(why):find("50") ~= nil, "not again until level 50 (" .. tostring(why) .. ")")

print("XP")
profile.Prestige = 2
LevelSystem.AwardXP(player, 50)
check(profile.EXP == 55, ("with two prestiges, 50 XP is worth 55 (%d)"):format(profile.EXP))
profile.Prestige = 1
LevelSystem.AwardXP(player, 10000000)
check(profile.Level == 50 and profile.EXP == 0, "a huge award stops at the cap, bar empty")
check(profile.Level == statsFolder.Level.Value and player:GetAttribute("Level") == 50, "and the mirrors agree")

print("setting a level")
local setOk, level = LevelSystem.SetLevel(player, 5)
check(setOk and level == 5 and profile.Level == 5 and profile.MaxEXP == GameConfig.GetRequiredEXP(5),
	"SetLevel 5 writes the profile")
check(statsFolder.Level.Value == 5 and player:GetAttribute("Level") == 5,
	"and reaches the Stats mirror AND the Level attribute the shop reads")
local _, capped = LevelSystem.SetLevel(player, 999)
check(capped == 50, "past the cap is the cap")
local ready = false
for _, sent in ipairs(toClients) do
	if sent.name == "ProgressionReward" and sent.args[1] == "PrestigeReady" then
		ready = true
	end
end
check(ready, "reaching the cap tells the player prestige is open")

-- ------------------------------------------------------------------ shop --

print("the shop's level gate")
local ShopService = World.require(sss.ShopService)
local gated = nil
for _, item in ipairs(GameConfig.ShopItems) do
	if (item.levelRequired or 1) >= 20 then
		gated = item
		break
	end
end
LevelSystem.SetLevel(player, 3)
coins.Value = 10000000
local refused = ShopService.AttemptPurchase(player, "item", gated.id)
check(not refused.ok and tostring(refused.reason):find("level") ~= nil,
	("%s is refused at level 3 (%s)"):format(gated.id, tostring(refused.reason)))
LevelSystem.SetLevel(player, gated.levelRequired)
World.advance(0.5)
local bought = ShopService.AttemptPurchase(player, "item", gated.id)
check(bought.ok == true, ("and sold at level %d, straight after the level is set (%s)"):format(gated.levelRequired,
	tostring(bought.reason)))

-- ---------------------------------------------------------------- wallet --

print("coins on the profile")
coins.Value = 777
profile.Coins = 0
profile.CoinsMigrated = false
local WalletService = World.require(sss.WalletService)
World.advance(0.5)
check(profile.CoinsMigrated == true and profile.Coins == 777 and coins.Value == 777,
	"first load keeps the highest balance and marks it moved")
coins.Value = 2500
World.advance(0.1)
check(profile.Coins == 2500, "a change on leaderstats is saved to the profile")
check(WalletService.Add(player, 500) == 3000 and profile.Coins == 3000, "Add")
check(WalletService.Set(player, -50) == 0 and profile.Coins == 0, "Set, never below zero")

-- ----------------------------------------------------------------- owner --

print("owner commands")
local Admin = World.require(sss.AdminService)
local C = Admin.Commands
saves = 0
local res = C.SetCoins(player, { value = "250000" })
check(res.ok and coins.Value == 250000 and profile.Coins == 250000 and saves == 1, "SetCoins lands on the profile and saves")
res = C.AddCoins(player, { value = 1000 })
check(res.ok and profile.Coins == 251000, "AddCoins")
res = C.SetLevel(player, { value = "30" })
check(res.ok and profile.Level == 30 and player:GetAttribute("Level") == 30 and saves == 3, "SetLevel reaches the attribute and saves")
res = C.AddLevels(player, { value = 5 })
check(res.ok and profile.Level == 35, "AddLevels")
res = C.SetPrestige(player, { value = 4 })
check(res.ok and profile.Prestige == 4 and player:GetAttribute("Prestige") == 4, "SetPrestige")
res = C.SetCrystals(player, { value = 99 })
check(res.ok and profile.Crystals == 99 and player:GetAttribute("Crystals") == 99, "SetCrystals")
res = C.DoPrestige(player, {})
check(not res.ok and res.confirm == true and profile.Level == 35, "a real prestige on yourself asks for confirmation")
local weapon = nil
for name in pairs(World.require(rs.WeaponConfig).Weapons) do
	weapon = name
	break
end
res = C.GiveWeapon(player, { value = weapon })
check(res.ok and table.find(profile.OwnedItems, weapon) ~= nil, "GiveWeapon makes it owned (" .. tostring(weapon) .. ")")
local state = C.State(player, {})
check(state.ok and state.level == 35 and state.coins == 251000 and state.prestige == 4 and state.maxLevel == 50
	and state.saving == true, "State reports the live numbers and that saving is on")

print(failures == 0 and "\27[32mall progression checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
require("@lune/process").exit(failures == 0 and 0 or 1)
