--!nocheck
-- Turf wars and the quests that ask for them, end to end -- the real TurfWarService and the
-- real QuestService together, where fixer.luau checks the matching rules on their own:
--
--   * holding THE PARK job, clearing THE PARK's crew completes it and says so;
--   * it does however the crew went down: a crew member who falls, drowns or is finished off
--     by someone else still leaves the player who fought there credited;
--   * a player who stood on the patch through the fight but never landed a recorded hit is
--     still one of the fighters;
--   * winning a DIFFERENT patch than the job names is not silent: the player is told which
--     patch the job wants.
--
--   lune run tools/uitest/turfquest.luau

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

local sent = {}
R.ClassMethods.RemoteEvent.FireClient = function(self, _player, ...)
	table.insert(sent, { name = self.Name, args = { ... } })
end
R.ClassMethods.RemoteEvent.FireAllClients = function(self, ...)
	table.insert(sent, { name = self.Name, args = { ... } })
end

-- Flat ground at kerb height everywhere downtown.
R.ClassMethods.Workspace.Raycast = function(_, origin)
	return { Position = Vector3.new(origin.X, 1000.5, origin.Z), Normal = Vector3.new(0, 1, 0),
		Material = roblox.Enum.Material.Concrete }
end

-- The crew: bare models with a humanoid, recorded as they are made.
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
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.Parent = model
	model.Parent = workspace
	table.insert(NPCService.spawned, { archetype = archetype, position = position, options = options, model = model })
	return model
end
return NPCService
]]
npc.Parent = sss

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
	"AbilityService", "VFXService", "QuestService", "ContractService", "TurfWarService" }) do
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

local KillCredit = World.require(sss.KillCredit)
local Turf = World.require(sss.TurfWarService)
local NPCService = World.require(sss.NPCService)
local now = 1000
Turf.Clock = function()
	return now
end

local root = World.character:FindFirstChild("HumanoidRootPart")
local function standAt(offset: Vector3)
	local at = DOWNTOWN + offset + Vector3.new(0, 3, 0)
	root.CFrame = CFrame.new(at)
	root.Position = at
end
local function zone(id: string)
	for _, z in ipairs(Turf.Zones) do
		if z.id == id then
			return z
		end
	end
	return nil
end
local function crewOf(id: string)
	local list = {}
	for _, s in ipairs(NPCService.spawned) do
		local humanoid = s.model:FindFirstChildOfClass("Humanoid")
		if s.model.Parent and s.model:GetAttribute("TurfZone") == id and humanoid and humanoid.Health > 0 then
			table.insert(list, s.model)
		end
	end
	return list
end
local function questNotes()
	local out = {}
	for _, s in ipairs(sent) do
		if s.name == "QuestUpdated" and type(s.args[2]) == "table" then
			table.insert(out, s.args[2])
		end
	end
	return out
end
local function take(id: string)
	profile.CurrentQuest = id
	profile.QuestProgress = 0
end
local function cooldownOver()
	now += Turf.COOLDOWN + 1
	Turf.Step()
end

levelValue.Value = 12

-- ---------------------------------------------------------------- the park --

print("holding the Park job, winning THE PARK")
take("ParkLife")
standAt(zone("Park").offset)
Turf.Step()
local crew = crewOf("Park")
check(Turf.Status("Park") == "active" and #crew > 0, ("stepping onto THE PARK starts its war (%d crew)"):format(#crew))
table.clear(sent)
for _, model in ipairs(crew) do
	KillCredit.Damage(model:FindFirstChildOfClass("Humanoid"), 1000, player, "Carbine")
end
Turf.Step()
World.advance(0.3)
check(Turf.Status("Park") == "cooldown", "the crew down: THE PARK is won")
check(profile.CurrentQuest == "" and table.find(profile.CompletedQuests, "ParkLife") ~= nil,
	"and Park Life is complete")
local notes = questNotes()
check(#notes > 0 and notes[#notes].completed == "Park Life", "the player is told the job is done")

-- ----------------------------------------------------- however the crew fell --

print("however the crew went down")
cooldownOver()
take("FullCourt")
standAt(zone("Courts").offset)
Turf.Step()
crew = crewOf("Courts")
check(Turf.Status("Courts") == "active", "THE COURTS at war")
-- The player drops one; the rest fall off something, or someone else finishes them.
KillCredit.Damage(crew[1]:FindFirstChildOfClass("Humanoid"), 1000, player, "Carbine")
for i = 2, #crew do
	crew[i]:FindFirstChildOfClass("Humanoid").Health = 0
end
Turf.Step()
World.advance(0.3)
check(table.find(profile.CompletedQuests, "FullCourt") ~= nil, "one kill of your own and the rest by the fall: it counts")

print("standing on the patch the whole fight")
cooldownOver()
take("TakeTheCarPark")
standAt(zone("CarPark").offset)
Turf.Step()
crew = crewOf("CarPark")
-- Nothing the player did was recorded (a hit that went through something else, say) --
-- but they stood their ground on the patch while the crew went down.
for _, model in ipairs(crew) do
	model:FindFirstChildOfClass("Humanoid").Health = 0
end
Turf.Step()
World.advance(0.3)
check(table.find(profile.CompletedQuests, "TakeTheCarPark") ~= nil,
	"a player on the patch when it is won is one of the fighters, and their job counts")

print("the wrong patch")
cooldownOver()
profile.CompletedQuests = {}
take("ParkLife")
standAt(zone("Alley").offset)
Turf.Step()
table.clear(sent)
for _, model in ipairs(crewOf("Alley")) do
	KillCredit.Damage(model:FindFirstChildOfClass("Humanoid"), 1000, player, "Carbine")
end
Turf.Step()
World.advance(0.3)
check(profile.CurrentQuest == "ParkLife", "winning THE ALLEY leaves the Park job open")
local hint, title = nil, nil
for _, n in ipairs(questNotes()) do
	hint = hint or n.hint
	title = title or n.hintTitle
end
check(title == "THE ALLEY doesn't count" and hint == "Wants THE PARK, by the waterfall",
	("and says so, and where the job is instead (%q / %q)"):format(tostring(title), tostring(hint)))
check(#tostring(title) <= 30 and #tostring(hint) <= 36, "short enough to fit a toast without being cut off")
local t2, h2 = QuestService.MissHint(QuestConfig.Get("TakeTheCarPark").objective, "turf", { zone = "Park", threat = 2 })
check(t2 == "THE PARK doesn't count" and h2 == "Wants THE CAR PARK, behind ZEE GUNS",
	"the car park job, won at the park: the two are told apart")

print(failures == 0 and "\27[32mall turf quest checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
require("@lune/process").exit(failures == 0 and 0 or 1)
