--!nocheck
-- The Downtown chapter's quests, checked without Studio:
--
--   * the Fixer stands in ZEE PLAZA and offers their own chain, separate from the
--     Quartermaster's, in order and by level, with a repeatable job once it runs dry;
--   * talking goes through the same dialogue machinery: the Fixer's offer, accepting it, and
--     lines that change with Street Cred;
--   * the new objectives count what they should: the apartment roof (only ON the roof), a
--     turf war won on a named patch or at a threat level, turf crew killed on a patch, the
--     Kingpin;
--   * a finished job pays coins, XP, crystals and Street Cred.
--
-- PlayerDataManager is stood in for by a plain table profile.
--
--   lune run tools/uitest/fixer.luau

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
local DialogueConfig = World.require(rs.DialogueConfig)
local QuestService = World.require(sss.QuestService)
local DOWNTOWN = Vector3.new(-155, 1000, 1500)

-- --------------------------------------------------------------- the chain --

print("the Fixer's chain")
local fixer = QuestConfig.Givers.Fixer
local offset = fixer and (fixer.position - DOWNTOWN)
check(fixer ~= nil and math.abs(offset.X) < 40 and math.abs(offset.Z) < 40, "the Fixer stands in ZEE PLAZA")
check(fixer and fixer.where ~= nil and DialogueConfig.Tree("Fixer") ~= nil, "with somewhere to be found and something to say")
local chain = {}
for _, q in ipairs(QuestConfig.Quests) do
	if q.giver == "Fixer" then
		table.insert(chain, q.id)
	end
end
check(#chain == 7 and chain[1] == "RooftopRun" and chain[7] == "TheKingpin",
	("seven jobs, the roof first and the Kingpin last (%s)"):format(table.concat(chain, ", ")))
local levelsRise = true
local last = 0
for _, id in ipairs(chain) do
	local q = QuestConfig.Get(id)
	levelsRise = levelsRise and q.levelRequired >= last and q.rewards.rep ~= nil
	last = q.levelRequired
end
check(levelsRise, "each asks a higher level than the last, and each pays Street Cred")
local known = { Kill = true, KillPlayer = true, KillElite = true, KillInZone = true, Reach = true, KillCrew = true, TurfWin = true }
local allKnown = true
for _, q in ipairs(QuestConfig.Quests) do
	allKnown = allKnown and known[q.objective.kind] == true
end
check(allKnown, "every objective is one the tracker understands")

check(QuestConfig.NextAvailable("Fixer", 1, {}).id == "RooftopRun", "a new face is sent up to the roof")
check(QuestConfig.NextAvailable("Fixer", 2, { RooftopRun = true }) == nil, "the next needs level 3")
check(QuestConfig.NextAvailable("Fixer", 3, { RooftopRun = true }).id == "TakeTheCarPark", "then the car park")
local done = {}
for _, id in ipairs(chain) do
	done[id] = true
end
local sweep = QuestConfig.NextAvailable("Fixer", 20, done)
check(sweep ~= nil and sweep.id == "Contract_Sweep" and sweep.repeatable and sweep.cost > 0,
	"the chain done, a paid repeatable job is on the board")
check(QuestConfig.NextAvailable("Quartermaster", 1, {}).giver == "Quartermaster", "the Quartermaster keeps their own")

-- --------------------------------------------------------------- talking --

print("talking to the Fixer")
World.advance(0.3)
local state = QuestService.GetState(player, "Fixer")
check(state and state.offer and state.offer.id == "RooftopRun" and state.offer.rep == 5, "their offer, with its Street Cred")
local node = QuestService.ResolveNode(player, "Fixer")
local canAccept = false
for _, c in ipairs(node and node.choices or {}) do
	canAccept = canAccept or c.id == "accept"
end
check(node and node.body:find("fire escape", 1, true) ~= nil and canAccept, "the pitch, and a way to say yes")
local result = QuestService.Choose(player, "Fixer", "root", "accept")
check(result.ok and profile.CurrentQuest == "RooftopRun", "accepted: " .. tostring(result.reason))
node = QuestService.ResolveNode(player, "Fixer", "cred")
check(node and node.body:find("Nobody knows you", 1, true) ~= nil, "a stranger's name is worth nothing yet")

-- --------------------------------------------------------------- the roof --

print("the roof")
local root = World.character:FindFirstChild("HumanoidRootPart")
local function standAt(at: Vector3)
	root.CFrame = CFrame.new(at)
	root.Position = at
end
local roof = QuestConfig.Get("RooftopRun").objective.position
standAt(Vector3.new(roof.X, DOWNTOWN.Y + 3, roof.Z))
QuestService.RegisterReach(player)
check(profile.CurrentQuest == "RooftopRun", "standing in the street under it does not count")
local coinsBefore = coins.Value
standAt(roof + Vector3.new(0, 3, 0))
QuestService.RegisterReach(player)
check(profile.CurrentQuest == "" and table.find(profile.CompletedQuests, "RooftopRun") ~= nil, "up on the roof, it does")
check(coins.Value - coinsBefore == 400, ("paid $%d"):format(coins.Value - coinsBefore))
check(profile.Reputation.Downtown == 5 and player:GetAttribute("StreetCred") == 5, "and five Street Cred")

-- --------------------------------------------------------------- turf wars --

print("turf wars")
local carPark = QuestConfig.Get("TakeTheCarPark").objective
check(QuestService.EventMatches(carPark, "turf", { zone = "CarPark", threat = 1 }), "a war won at the car park counts")
check(not QuestService.EventMatches(carPark, "turf", { zone = "Park", threat = 4 }), "one won in the park does not")
local heat = QuestConfig.Get("TurnUpTheHeat").objective
check(QuestService.EventMatches(heat, "turf", { zone = "Courts", threat = 3 })
	and not QuestService.EventMatches(heat, "turf", { zone = "Courts", threat = 2 }), "threat III or higher, anywhere")

levelValue.Value = 3
check(QuestService.Choose(player, "Fixer", "root", "accept").ok and profile.CurrentQuest == "TakeTheCarPark",
	"level 3: the car park job taken")
QuestService.RegisterEvent(player, "turf", { zone = "Park", threat = 2 })
check(profile.CurrentQuest == "TakeTheCarPark", "the wrong patch leaves it open")
QuestService.RegisterEvent(player, "turf", { zone = "CarPark", threat = 2 })
check(profile.CurrentQuest == "" and table.find(profile.CompletedQuests, "TakeTheCarPark") ~= nil,
	"the car park won: done")
check(profile.Reputation.Downtown == 15, ("Street Cred now %s"):format(tostring(profile.Reputation.Downtown)))

-- --------------------------------------------------------------- crew and kingpin --

print("the crew and the Kingpin")
local alley = QuestConfig.Get("AlleyCats").objective
check(QuestService.ObjectiveMatches(alley, "Grunt", { crew = true, turf = "Alley" }), "a crew Bandit in the alley counts")
check(not QuestService.ObjectiveMatches(alley, "Grunt", { crew = true, turf = "Park" }), "one in the park does not")
check(not QuestService.ObjectiveMatches(alley, "Grunt", { crew = false, turf = "Alley" }), "nor an ordinary Bandit")
check(not QuestService.ObjectiveMatches(alley, nil, nil), "nor a player")
check(QuestService.ObjectiveMatches(QuestConfig.Get("TheKingpin").objective, "Kingpin", {}), "the Kingpin job counts the Kingpin")

-- --------------------------------------------------------------- standing --

print("standing")
profile.Reputation.Downtown = 80
node = QuestService.ResolveNode(player, "Fixer", "cred")
check(node and node.body:find("legend", 1, true) ~= nil, "Honoured: the Fixer calls you a legend")
levelValue.Value = 5
node = QuestService.ResolveNode(player, "Fixer")
check(node and node.body:find("whole street knows your name", 1, true) ~= nil, "and greets you like one")

print(failures == 0 and "\27[32mall fixer checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
require("@lune/process").exit(failures == 0 and 0 or 1)
