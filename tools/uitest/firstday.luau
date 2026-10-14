--!nocheck
-- The First Day: a new player's first ten minutes, checked without Studio:
--
--   * a brand-new player is put on the first job when they join; anyone who has done
--     anything is left alone;
--   * the chain runs Downtown -> the Alley -> ZEE TACTICS -> a till -> the Fixer, each step
--     taken on by itself a moment after the last is done, every step marked on the compass;
--   * its steps are never offered on a giver's board (they are only reached by the chain);
--   * each step counts only what it asks: crew in the Alley (not elsewhere), the ZEE TACTICS
--     counter (not the gun shop's), a robbery;
--   * it ends at the Fixer, whose first job is then on offer.
--
-- PlayerDataManager is stood in for by a plain table profile.
--
--   lune run tools/uitest/firstday.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

require("@lune/task").delay(120, function()
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
local player = World.player

local profile = {
	Level = 1, EXP = 0, MaxEXP = 100, StatPoints = 0, Prestige = 0, LifetimeXP = 0,
	Crystals = 0, Titles = {}, OwnedItems = {}, Coins = 0, CoinsMigrated = true, TotalKills = 0,
	Reputation = {}, OwnedVFX = {}, EquippedVFX = {}, WeaponVFX = {}, OwnedCosmetics = {},
	CurrentQuest = "", QuestProgress = 0, CompletedQuests = {},
}
local stub = R.new("ModuleScript")
stub.Name = "PlayerDataManager"
stub.Source = [[
local data = {}
local Replica = { Data = data }
function Replica:SetValue(key, value)
	data[key] = value
end
function Replica:ListenToChange() end
function Replica:IsActive()
	return true
end
local PDM = {}
function PDM.Bind(profile)
	data = profile
	Replica.Data = profile
end
function PDM:GetPlayerDataReplica(_player)
	return { expect = function()
		return Replica
	end, andThen = function(_, fn)
		pcall(fn, Replica)
		return { catch = function() end }
	end }
end
function PDM:SaveNow()
	return true
end
function PDM:IsSaving()
	return true
end
return PDM
]]
stub.Parent = sss
World.require(stub).Bind(profile)

R.ClassMethods.RemoteEvent.FireClient = function() end
R.ClassMethods.RemoteEvent.FireAllClients = function() end

-- Crystals, counted on the profile (the real service pulls in the whole mine).
local crystals = R.new("ModuleScript")
crystals.Name = "CrystalService"
crystals.Source = [[
local CrystalService = { awarded = 0 }
function CrystalService.Award(_player, n)
	CrystalService.awarded += n
end
function CrystalService.Get()
	return CrystalService.awarded
end
function CrystalService.Spend()
	return false
end
return CrystalService
]]
crystals.Parent = sss

for _, name in ipairs({ "KillCredit", "ShopService", "ReputationService", "LevelSystem", "WalletService",
	"AbilityService", "VFXService", "QuestService" }) do
	R.mirror(place:GetService("ServerScriptService"):FindFirstChild(name), sss)
end

local statsFolder = R.new("Folder")
statsFolder.Name = "Stats"
local levelValue = R.new("IntValue")
levelValue.Name = "Level"
levelValue.Value = 1
levelValue.Parent = statsFolder
statsFolder.Parent = player

local coins = player:FindFirstChild("leaderstats"):FindFirstChild("Coins")
coins.Value = 20000

local QuestConfig = World.require(rs.QuestConfig)
local QuestService = World.require(sss.QuestService)
local DOWNTOWN = Vector3.new(-155, 1000, 1500)

print("the chain")
local chain, id = {}, "WelcomeDowntown"
while id and #chain < 10 do
	local q = QuestConfig.Get(id)
	if not q then
		break
	end
	table.insert(chain, q)
	id = q.autoNext
end
local ids = {}
for _, q in ipairs(chain) do
	table.insert(ids, q.id)
end
check(#chain == 5 and chain[5].id == "FirstDayFixer" and chain[5].autoNext == nil,
	("five steps, ending at the Fixer (%s)"):format(table.concat(ids, " > ")))
local marked = true
for _, q in ipairs(chain) do
	marked = marked and QuestService.WaypointFor(q.objective) ~= nil
end
check(marked, "every step is marked on the compass")
local offered = false
for _, giver in ipairs({ "Quartermaster", "Fixer", "Elder", "Captain" }) do
	local q = QuestConfig.NextAvailable(giver, 50, { WelcomeDowntown = true }, { Tower = true })
	offered = offered or (q ~= nil and q.auto == true)
end
check(not offered, "no First Day step is ever offered on a board")
local fixerAt = QuestConfig.Givers.Fixer.position
check((chain[5].objective.position - fixerAt).Magnitude < 2, "the last step is where the Fixer stands")

print("a veteran")
profile.CompletedQuests = { "RooftopRun" }
check(QuestService.StartFirstDay(player) == false and profile.CurrentQuest == "", "is left alone")

print("a new player")
profile.CompletedQuests = {}
profile.CurrentQuest = ""
check(QuestService.StartFirstDay(player) == true and profile.CurrentQuest == "WelcomeDowntown", "starts on the first job")
check(QuestService.StartFirstDay(player) == false, "and is not started twice")

local root = World.character:FindFirstChild("HumanoidRootPart")
root.CFrame = CFrame.new(DOWNTOWN + Vector3.new(0, 3, 0))
QuestService.RegisterReach(player)
check(profile.CurrentQuest == "" and table.find(profile.CompletedQuests, "WelcomeDowntown") ~= nil, "reaching ZEE PLAZA finishes it")
World.advance(QuestService.CHAIN_DELAY + 0.5)
check(profile.CurrentQuest == "FirstDayAlley", "and the Alley job goes up by itself")

QuestService.RegisterKill(player, "Thug", { crew = true, turf = "Park" })
check(profile.QuestProgress == 0, "crew killed in THE PARK does not count")
QuestService.RegisterKill(player, "Thug", { crew = true, turf = "Alley" })
QuestService.RegisterKill(player, "Gangster", { crew = true, turf = "Alley" })
World.advance(QuestService.CHAIN_DELAY + 0.5)
check(profile.CurrentQuest == "FirstDayGear", "two in THE ALLEY does; then ZEE TACTICS")

QuestService.RegisterEvent(player, "shop", { panel = "Market" })
check(profile.CurrentQuest == "FirstDayGear", "the gun shop's counter does not count")
QuestService.RegisterEvent(player, "shop", { panel = "Tactics" })
World.advance(QuestService.CHAIN_DELAY + 0.5)
check(profile.CurrentQuest == "FirstDayScore", "ZEE TACTICS' does; then a till")

QuestService.RegisterEvent(player, "stickup", { kind = "till" })
World.advance(QuestService.CHAIN_DELAY + 0.5)
check(profile.CurrentQuest == "FirstDayFixer", "a robbery counts; then the Fixer")

root.CFrame = CFrame.new(fixerAt + Vector3.new(4, 3, 0))
QuestService.RegisterReach(player)
World.advance(QuestService.CHAIN_DELAY + 0.5)
check(profile.CurrentQuest == "" and table.find(profile.CompletedQuests, "FirstDayFixer") ~= nil, "finding the Fixer ends the day")
local next = QuestConfig.NextAvailable("Fixer", 1, (function()
	local set = {}
	for _, done in ipairs(profile.CompletedQuests) do
		set[done] = true
	end
	return set
end)())
check(next ~= nil and next.id == "RooftopRun", "and the Fixer's first job is on offer")
check(coins.Value > 20000, ("it paid along the way ($%d)"):format(coins.Value - 20000))

print(if failures == 0 then "\27[32mall first day checks passed\27[0m" else ("\27[31m%d failed\27[0m"):format(failures))
require("@lune/process").exit(if failures == 0 then 0 else 1)
