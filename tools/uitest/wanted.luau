--!nocheck
-- The first-stop changes, checked without Studio:
--
--   * MOST WANTED: a named crime boss goes up on the board after a while, with two of their
--     crew, tagged so every client can mark them; the board says who, where and for how
--     long, and lists the WANTED players; taking them down pays the one who did it (and
--     Street Cred), the next name goes up after a rest, and one left alone skips town;
--   * supply drops come down near a player -- a short run away, never on their head -- and
--     not near anybody in a duel;
--   * the world past Downtown is shut until ZEE TOWER is beaten: the Travel menu's far places
--     and the Quartermaster's work there; the first job sends a new player Downtown.
--
-- NPCService is stood in for by a module that makes bare NPC models; clocks are wound by hand.
--
--   lune run tools/uitest/wanted.luau

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

-- Flat ground at kerb height everywhere.
local GROUND_Y = 1000.5
R.ClassMethods.Workspace.Raycast = function(_, origin)
	return { Position = Vector3.new(origin.X, GROUND_Y, origin.Z), Normal = Vector3.new(0, 1, 0),
		Material = roblox.Enum.Material.Concrete, Instance = World.workspace }
end

local place = World.loadPlace("build/Game.rbxl")
local rs = World.service("ReplicatedStorage")
local sss = World.service("ServerScriptService")
local player = World.player

local profile = {
	Level = 10, EXP = 0, MaxEXP = 100, StatPoints = 0, Prestige = 0, LifetimeXP = 0,
	Crystals = 0, Titles = {}, OwnedItems = {}, Coins = 0, CoinsMigrated = true, TotalKills = 0,
	Reputation = {}, OwnedVFX = {}, EquippedVFX = {}, CurrentQuest = "", QuestProgress = 0, CompletedQuests = {},
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

local npc = R.new("ModuleScript")
npc.Name = "NPCService"
npc.Source = [[
local NPCService = { spawned = {} }
function NPCService.Spawn(archetype, position, options)
	local model = Instance.new("Model")
	model.Name = archetype
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.new(position)
	root.Parent = model
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 420
	humanoid.Health = 420
	humanoid.Parent = model
	for key, value in pairs(options and options.attributes or {}) do
		model:SetAttribute(key, value)
	end
	model.Parent = workspace
	table.insert(NPCService.spawned, { archetype = archetype, position = position, options = options, model = model })
	return model
end
return NPCService
]]
npc.Parent = sss
local NPCService = World.require(npc)

local sent = {}
R.ClassMethods.RemoteEvent.FireClient = function(self, _player, ...)
	table.insert(sent, { name = self.Name, args = { ... } })
end
R.ClassMethods.RemoteEvent.FireAllClients = function(self, ...)
	table.insert(sent, { name = self.Name, args = { ... } })
end
local function wantedSent(stage: string)
	for i = #sent, 1, -1 do
		local s = sent[i]
		if s.name == "BountyEvent" and s.args[1] == "mostwanted" and s.args[2].stage == stage then
			return s.args[2]
		end
	end
	return nil
end

for _, name in ipairs({ "KillCredit", "ShopService", "ReputationService", "LevelSystem", "WalletService",
	"AbilityService", "VFXService", "CrystalService", "ContractService", "TurfWarService", "MostWantedService",
	"TravelService", "SupplyDropService" }) do
	R.mirror(place:GetService("ServerScriptService"):FindFirstChild(name), sss)
end

local KillCredit = World.require(sss.KillCredit)
local Wanted = World.require(sss.MostWantedService)
local now = 0
Wanted.Clock = function()
	return now
end
local CENTRE = Vector3.new(-155, 1000, 1500)
local coins = player:FindFirstChild("leaderstats"):FindFirstChild("Coins")

-- --------------------------------------------------------------- most wanted --

print("most wanted")
check(#Wanted.TARGETS >= 6 and #Wanted.HIDEOUTS >= 4, ("%d names, %d hideouts"):format(#Wanted.TARGETS, #Wanted.HIDEOUTS))
for _, h in ipairs(Wanted.HIDEOUTS) do
	local turf = World.require(sss.TurfWarService).PatchAt(CENTRE + h.at, 2)
	check(turf == nil and math.abs(h.at.X) < 190 and math.abs(h.at.Z) < 190, h.name .. ": inside the district, off the turf patches")
end
Wanted.Step()
check(Wanted.Current() == nil, "nobody on the board at first")
local board = Wanted.Board(player)
check(board.target == nil and board.nextIn == Wanted.FIRST_AFTER, ("the board counts down to the first (%ss)"):format(
	tostring(board.nextIn)))

now = Wanted.FIRST_AFTER
Wanted.Step()
local target = Wanted.Current()
check(target ~= nil, "a name goes up")
local capo = NPCService.spawned[1]
check(capo and capo.archetype == "Capo" and capo.options.respawn == false and capo.options.ignoreCap == true,
	"a Capo who does not come back")
check(#NPCService.spawned == 3, ("with an escort (%d spawned)"):format(#NPCService.spawned))
local named = false
for _, t in ipairs(Wanted.TARGETS) do
	named = named or (target and target.Name == t.name and target:GetAttribute("MostWanted") == t.name
		and target:GetAttribute("MostWantedAlias") == t.alias)
end
check(named, "named, with their street name on them")
check(target and World.service("CollectionService"):HasTag(target, "MostWanted"), "tagged for the clients' marker")
local out = wantedSent("out")
check(out and out.name == target.Name and type(out.where) == "string" and out.coins == Wanted.REWARD.coins,
	"everyone is told who, where and the price")

player:SetAttribute("Bounty", 800)
board = Wanted.Board(player)
check(board.target and board.target.name == target.Name and board.target.secondsLeft == Wanted.AT_LARGE
	and type(board.target.crime) == "string", "the board shows them, what they did and how long")
check(#board.wanted == 1 and board.wanted[1].amount == 800 and board.wanted[1].you == true, "and the WANTED players")
player:SetAttribute("Bounty", nil)

-- Taking them down.
local before = coins.Value
local humanoid = target:FindFirstChildOfClass("Humanoid")
KillCredit.Damaged:Fire(humanoid, 420, player)
KillCredit.Tag(humanoid, player)
humanoid.Health = 0
now += 10
Wanted.Step()
check(Wanted.Current() == nil, "taken down: off the board")
check(coins.Value - before == Wanted.REWARD.coins, ("the one who did it is paid $%d"):format(coins.Value - before))
check(player:GetAttribute("StreetCred") == Wanted.CRED, ("and gets Street Cred (%s)"):format(
	tostring(player:GetAttribute("StreetCred"))))
local paid = wantedSent("paid")
check(paid and paid.coins == Wanted.REWARD.coins and paid.cred == Wanted.CRED, "and told so")
local down = wantedSent("down")
check(down and down.by == player.DisplayName, "the server hears who brought them in")
board = Wanted.Board(player)
check(board.last and board.last.by == player.DisplayName and not board.last.escaped and board.takedowns == 1,
	"the board remembers, and counts your takedowns")
check(board.nextIn == Wanted.REST, ("the next name in %ss"):format(tostring(board.nextIn)))

now += Wanted.REST - 1
Wanted.Step()
check(Wanted.Current() == nil, "not before the rest is up")
now += 1
Wanted.Step()
local second = Wanted.Current()
check(second ~= nil and second.Name ~= target.Name, ("then a different name (%s)"):format(second and second.Name or "none"))

-- Left alone.
now += Wanted.AT_LARGE
Wanted.Step()
check(Wanted.Current() == nil and second.Parent == nil, "left alone, they skip town")
check(wantedSent("gone") ~= nil and Wanted.Board(player).last.escaped == true, "and the board says they got away")

-- --------------------------------------------------------------- supply drops --

print("supply drops")
local Supply = World.require(sss.SupplyDropService)
local root = World.character:FindFirstChild("HumanoidRootPart")
local stand = CENTRE + Vector3.new(0, 3.5, -100)
root.CFrame = CFrame.new(stand)
root.Position = stand
check(Supply.Eligible(player), "a player out in the street can have one")
check(Supply.PickPlayer() == player, "and is picked")
local zone = Supply.ZoneNear(player)
check(zone and zone.name == "DOWNTOWN" and zone.minRadius >= 20 and zone.radius <= 80,
	("a ring round them, named for where they are (%s)"):format(zone and zone.name or "none"))
local okDrop, landing = pcall(Supply.Drop)
if okDrop and landing then
	local d = (Vector3.new(landing.X, 0, landing.Z) - Vector3.new(stand.X, 0, stand.Z)).Magnitude
	check(d >= Supply.NEAR.min - 0.01 and d <= Supply.NEAR.max + 0.01, ("it lands %.0f studs from them"):format(d))
else
	check(false, "a drop near them: " .. tostring(landing))
end
player:SetAttribute("DuelState", "duel")
check(not Supply.Eligible(player) and Supply.PickPlayer() == nil, "nobody in a duel gets one")
player:SetAttribute("DuelState", nil)
player:SetAttribute("InTower", true)
check(not Supply.Eligible(player), "nor anybody up in ZEE TOWER")
player:SetAttribute("InTower", nil)

-- --------------------------------------------------------------- the first stop --

print("downtown first")
local Travel = World.require(sss.TravelService)
check(Travel.Places[1].id == "Hub" and Travel.Places[2].id == "Downtown", "the Crossing, then Downtown")
check(Travel.Locked(player, "Downtown") == nil and Travel.Locked(player, "Mine") == nil, "both open from the start")
local shut = 0
for _, p in ipairs(Travel.Places) do
	if Travel.Locked(player, p.id) then
		shut += 1
	end
end
check(shut == 3 and Travel.Locked(player, "Flats"):find("ZEE TOWER", 1, true) ~= nil,
	("the rest (%d) wait on ZEE TOWER"):format(shut))
local ok, why = Travel.Go(player, "Reach")
check(not ok and why and why:find("ZEE TOWER", 1, true) ~= nil, "and the server will not send you: " .. tostring(why))
player:SetAttribute("TowerCleared", true)
check(Travel.Locked(player, "Flats") == nil and Travel.Locked(player, "Reach") == nil, "the tower beaten, they open")
player:SetAttribute("TowerCleared", nil)

local QuestConfig = World.require(rs.QuestConfig)
local first = QuestConfig.NextAvailable("Quartermaster", 1, {})
check(first and first.id == "WelcomeDowntown" and first.objective.kind == "Reach"
	and (first.objective.position - CENTRE).Magnitude < 5, "the Quartermaster's first job: get to ZEE PLAZA")
local nextQ, lockedBy = QuestConfig.NextAvailable("Quartermaster", 20, { WelcomeDowntown = true })
check(nextQ == nil and lockedBy == "Tower", "after it, their work waits on the tower")
nextQ = QuestConfig.NextAvailable("Quartermaster", 20, { WelcomeDowntown = true }, { Tower = true })
check(nextQ and nextQ.id == "ClearTheCamp", "and opens once it falls")
check(QuestConfig.NextAvailable("Fixer", 1, {}).id == "RooftopRun", "the Fixer's work needs nothing")

print(failures == 0 and "\27[32mall wanted checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
require("@lune/process").exit(failures == 0 and 0 or 1)
