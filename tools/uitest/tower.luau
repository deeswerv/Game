--!nocheck
-- ZEE TOWER (TowerService), checked without Studio:
--
--   * the lobby lets nobody under level 8 up; at 8 you are taken to the roof and marked as
--     up there;
--   * the first one up wakes the room: a welcome, then the Don and two bodyguards, his health
--     scaled to the room;
--   * his health drives the phases: the family comes up at 70% and money bombs start landing
--     under you (and hurt); at 40% the helicopter lifts off and strafes a line across the roof;
--   * beating him pays everyone up there, the first time for real -- TowerCleared is saved,
--     the Travel menu opens the world past Downtown -- and after a rest he is back, paying
--     less; an empty roof resets the fight; the elevator takes you back down to the street.
--
-- The roof is stood in for by its markers (the district check covers the real geometry);
-- NPCService makes bare NPC models; the clock is wound by hand.
--
--   lune run tools/uitest/tower.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

require("@lune/task").delay(150, function()
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

local ROOF_Y = 1151.5
R.ClassMethods.Workspace.Raycast = function(_, origin)
	return { Position = Vector3.new(origin.X, ROOF_Y, origin.Z), Normal = Vector3.new(0, 1, 0),
		Material = roblox.Enum.Material.Marble, Instance = World.workspace }
end

local place = World.loadPlace("build/Game.rbxl")
local rs = World.service("ReplicatedStorage")
local sss = World.service("ServerScriptService")
local player = World.player
local workspace = World.workspace

local profile = {
	Level = 1, EXP = 0, MaxEXP = 100, StatPoints = 0, Prestige = 0, LifetimeXP = 0,
	Crystals = 0, Titles = {}, OwnedItems = {}, Coins = 0, CoinsMigrated = true, TotalKills = 0,
	Reputation = {}, OwnedVFX = {}, EquippedVFX = {}, CurrentQuest = "", QuestProgress = 0, CompletedQuests = {},
	TowerCleared = false, TowerClears = 0,
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
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 400
	humanoid.Health = 400
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

local crystals = R.new("ModuleScript")
crystals.Name = "CrystalService"
crystals.Source = [[
local C = { awarded = 0 }
function C.Award(_player, n)
	C.awarded += n
end
function C.Get()
	return C.awarded
end
function C.Spend()
	return false
end
return C
]]
crystals.Parent = sss
local Crystals = World.require(crystals)

local sent = {}
R.ClassMethods.RemoteEvent.FireClient = function(self, _player, ...)
	table.insert(sent, { name = self.Name, args = { ... } })
end
R.ClassMethods.RemoteEvent.FireAllClients = function(self, ...)
	table.insert(sent, { name = self.Name, args = { ... } })
end
local function towerSent(kind: string)
	for i = #sent, 1, -1 do
		local s = sent[i]
		if s.name == "TowerEvent" and s.args[1] == kind then
			return s.args[2]
		end
	end
	return nil
end

for _, name in ipairs({ "KillCredit", "ShopService", "ReputationService", "LevelSystem", "WalletService",
	"AbilityService", "VFXService", "QuestService", "TurfWarService", "TravelService", "TowerService" }) do
	R.mirror(place:GetService("ServerScriptService"):FindFirstChild(name), sss)
end

-- The roof's markers, where the district puts them.
local CENTRE = Vector3.new(-155, 1000, 1500)
local roof = CENTRE + Vector3.new(0, 151.5, 178)
local district = R.new("Folder")
district.Name = "Downtown"
district.Parent = workspace
local function marker(name: string, at: Vector3, parent)
	local p = R.new("Part")
	p.Name = name
	p.Size = Vector3.new(2, 0.06, 2)
	p.CFrame = CFrame.new(at)
	p.Position = at
	p.Parent = parent or district
	return p
end
local arrival = marker("TowerArrival", roof + Vector3.new(-34, 0.04, 17))
local door = marker("TowerDoor", CENTRE + Vector3.new(0, 0.54, 158 - 3.4))
local bossSpot = marker("TowerBossSpot", roof + Vector3.new(-2, 0.04, 8))
for _, at in ipairs({ Vector3.new(-34, 0, 14), Vector3.new(14, 0, 22), Vector3.new(30, 0, -4), Vector3.new(-30, 0, -4) }) do
	marker("TowerAddSpot", roof + at + Vector3.new(0, 0.04, 0))
end
local heli = R.new("Folder")
heli.Name = "DonHeli"
heli.Parent = district
local heliBody = marker("HeliBody", roof + Vector3.new(14, 2.8, 24.5), heli)
local rotor = marker("Rotor", roof + Vector3.new(14, 6.1, 24.5), heli)
local heliRest = heliBody.CFrame

local statsFolder = R.new("Folder")
statsFolder.Name = "Stats"
local levelValue = R.new("IntValue")
levelValue.Name = "Level"
levelValue.Value = 1
levelValue.Parent = statsFolder
statsFolder.Parent = player
local coins = player:FindFirstChild("leaderstats"):FindFirstChild("Coins")

local KillCredit = World.require(sss.KillCredit)
local Tower = World.require(sss.TowerService)
local Travel = World.require(sss.TravelService)
local now = 1000
Tower.Clock = function()
	return now
end
local character = World.character
local root = character:FindFirstChild("HumanoidRootPart")
local humanoid = character:FindFirstChildOfClass("Humanoid")
local function spawnedOf(archetype: string): number
	local n = 0
	for _, s in ipairs(NPCService.spawned) do
		if s.archetype == archetype and s.model.Parent then
			n += 1
		end
	end
	return n
end
World.advance(0.3)

-- --------------------------------------------------------------- the lobby --

print("the lobby")
check(Tower.MIN_LEVEL == 8, "the tower wants level 8")
local ok, why = Tower.Enter(player)
check(not ok and why:find("level", 1, true) and towerSent("denied"), "level 1 is turned away: " .. tostring(why))
levelValue.Value = 8
ok = Tower.Enter(player)
check(ok and player:GetAttribute("InTower") == true, "level 8 is taken up")
check((root.CFrame.Position - arrival.Position).Magnitude < 6, ("and stands at the elevator on the roof (%.1f away)"):format(
	(root.CFrame.Position - arrival.Position).Magnitude))
check(towerSent("enter") ~= nil, "with the title card")
check(Travel.Locked(player, "Flats") ~= nil, "the world past Downtown is still shut")

-- --------------------------------------------------------------- the fight --

print("the Don")
Tower.Step()
check(Tower.State() == "intro" and towerSent("intro") ~= nil, "the first one up gets the welcome")
now += Tower.INTRO
Tower.Step()
local don = Tower.Don()
local donH = don and don:FindFirstChildOfClass("Humanoid")
check(Tower.State() == "fight" and don ~= nil and don.Name == "THE DON" and don:GetAttribute("Boss") == true,
	"then the Don steps out, with a boss bar")
check(donH and donH.MaxHealth == Tower.BASE_HEALTH and donH.Health == donH.MaxHealth,
	("his health for one of you: %s"):format(donH and tostring(donH.MaxHealth) or "?"))
check(spawnedOf("Enforcer") == 2 and don:GetAttribute("PhaseMarks") == "0.7,0.4" and don:GetAttribute("Phase") == 1,
	"two bodyguards, and the phases marked on the bar")

print("family business")
KillCredit.Damaged:Fire(donH, donH.MaxHealth * 0.31, player)
donH.Health = donH.MaxHealth * 0.69
Tower.Step()
check(don:GetAttribute("Phase") == 2 and towerSent("phase").name == "FAMILY BUSINESS", "at 70% the family is called")
check(spawnedOf("Capo") == 1 and spawnedOf("Shooter") >= 1, "and comes up")
root.CFrame = CFrame.new(bossSpot.Position + Vector3.new(10, 3, -10))
root.Position = bossSpot.Position + Vector3.new(10, 3, -10)
now += 2.1
Tower.Step()
local hazards = workspace:FindFirstChild("TowerHazards")
check(hazards and hazards:FindFirstChild("MoneyBomb") ~= nil, "a money bomb lands under you")
local before = humanoid.Health
World.advance(Tower.BOMB.warn + 0.3)
check(humanoid.Health < before, ("and hurts if you stay (%.0f -> %.0f)"):format(before, humanoid.Health))
humanoid.Health = humanoid.MaxHealth

print("last stand")
donH.Health = donH.MaxHealth * 0.39
Tower.Step()
check(don:GetAttribute("Phase") == 3 and towerSent("phase").name == "LAST STAND", "at 40%: the last stand")
now += 2
Tower.Step()
check((heliBody.CFrame.Position - heliRest.Position).Magnitude > 5, "the helicopter lifts off the pad")
now += 3
Tower.Step()
check(hazards:FindFirstChild("StrafeLine") ~= nil, "and marks a strafing run across the roof")
World.advance(Tower.STRAFE.warn + 0.3)
humanoid.Health = humanoid.MaxHealth

print("the win")
local coinsBefore = coins.Value
donH.Health = 0
Tower.Step()
check(Tower.State() == "cooldown", "he falls")
check(profile.TowerCleared == true and profile.TowerClears == 1 and player:GetAttribute("TowerCleared") == true,
	"TowerCleared saved to the profile")
check(coins.Value - coinsBefore == Tower.FIRST_REWARD.coins and Crystals.awarded == Tower.FIRST_REWARD.crystals,
	("the first clear pays $%d and %d crystals"):format(coins.Value - coinsBefore, Crystals.awarded))
local cleared = towerSent("cleared")
check(cleared and cleared.first == true, "and says it was the first")
check(towerSent("announce") and table.find(towerSent("announce").names, player.DisplayName), "the server hears who did it")
check(Travel.Locked(player, "Flats") == nil and Travel.Locked(player, "Reach") == nil, "the world past Downtown opens")
check((heliBody.CFrame.Position - heliRest.Position).Magnitude < 0.01, "the helicopter is back on its pad")
check(not hazards:FindFirstChild("MoneyBomb") and not hazards:FindFirstChild("StrafeLine"), "the hazards are cleared away")

print("again")
now += Tower.COOLDOWN - 1
Tower.Step()
check(Tower.State() == "cooldown", "he rests")
now += 1
Tower.Step()
check(Tower.State() == "intro", "then the room wakes again")
now += Tower.INTRO
Tower.Step()
don = Tower.Don()
donH = don:FindFirstChildOfClass("Humanoid")
coinsBefore = coins.Value
donH.Health = 0
Tower.Step()
check(coins.Value - coinsBefore == Tower.REPEAT_REWARD.coins and towerSent("cleared").first == false
	and profile.TowerClears == 2, "a repeat pays less, and counts")

print("down, and an empty roof")
check(Tower.Leave(player) and player:GetAttribute("InTower") == nil, "the elevator takes you down")
check((root.CFrame.Position - door.Position).Magnitude < 10, "out onto the street by the lobby doors")
now += Tower.COOLDOWN
Tower.Step()
Tower.Enter(player)
Tower.Step()
now += Tower.INTRO
Tower.Step()
local third = Tower.Don()
check(third ~= nil, "a fresh fight")
Tower.Leave(player)
Tower.Step()
now += Tower.RESET_AFTER + 1
Tower.Step()
check(Tower.State() == "idle" and third.Parent == nil, "nobody left up there: the fight resets")

print(failures == 0 and "\27[32mall tower checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
require("@lune/process").exit(failures == 0 and 0 or 1)
