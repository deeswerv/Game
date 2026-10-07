--!nocheck
-- Turf wars on four patches of Downtown, checked without Studio:
--
--   * four patches, one in each quarter of the district, each marked on the ground with a ring
--     of dashes and a sign that says what it is doing;
--   * stepping onto a patch starts its war (its own crew, tagged with the patch), and only that
--     patch's -- the others stay open;
--   * two patches can be at war at once, each with its own crew and clock;
--   * clearing the crew pays the fighters and the street holds the patch: its sign goes green,
--     standing on it starts nothing, and it pays its holders tribute while they are in Downtown;
--   * a few minutes on its crew comes back for it (a raid, bigger at the higher threat); lose
--     that and the patch goes quiet, theirs again; with nobody in Downtown they just take it;
--   * a crew left alone for long enough leaves, and that patch cools down;
--   * every patch's state and the street's hold are published for the HUD.
--
-- NPCService is stood in for by a module that makes bare NPC models; the clock is wound by hand.
--
--   lune run tools/uitest/turf.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R
local Vector3, CFrame, Color3 = roblox.Vector3, roblox.CFrame, roblox.Color3

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

-- Flat ground at kerb height everywhere downtown.
local GROUND_Y = 1000.5
R.ClassMethods.Workspace.Raycast = function(_, origin)
	return { Position = Vector3.new(origin.X, GROUND_Y, origin.Z), Normal = Vector3.new(0, 1, 0),
		Material = roblox.Enum.Material.Concrete }
end

local place = World.loadPlace("build/Game.rbxl")
local rs = World.service("ReplicatedStorage")
local sss = World.service("ServerScriptService")
local player = World.player
local workspace = World.workspace

local profile = {
	Level = 10, EXP = 0, MaxEXP = 100, StatPoints = 0, Prestige = 0, LifetimeXP = 0,
	Crystals = 0, Titles = {}, OwnedItems = {}, Coins = 0, CoinsMigrated = true, TotalKills = 0,
	Reputation = {}, OwnedVFX = {}, EquippedVFX = {},
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
local NPCService = World.require(npc)

-- Server-side remote calls, which the client harness does not model: recorded, not sent.
local sent = {}
R.ClassMethods.RemoteEvent.FireClient = function(self, _player, ...)
	table.insert(sent, { name = self.Name, args = { ... } })
end
R.ClassMethods.RemoteEvent.FireAllClients = function(self, ...)
	table.insert(sent, { name = self.Name, args = { ... } })
end
local function turfSent(kind: string, id: string?)
	for _, s in ipairs(sent) do
		if s.name == "TurfEvent" and s.args[1] == kind and (id == nil or s.args[2].id == id) then
			return s.args[2]
		end
	end
	return nil
end

for _, name in ipairs({ "KillCredit", "ShopService", "ReputationService", "LevelSystem", "WalletService",
	"AbilityService", "VFXService", "CrystalService", "ContractService", "TurfWarService" }) do
	R.mirror(place:GetService("ServerScriptService"):FindFirstChild(name), sss)
end

local GameConfig = World.require(rs.GameConfig)
local KillCredit = World.require(sss.KillCredit)
local Turf = World.require(sss.TurfWarService)
local now = 1000
Turf.Clock = function()
	return now
end

local CENTRE = Vector3.new(-155, 1000, 1500)
local root = World.character:FindFirstChild("HumanoidRootPart")
local function standAt(offset: Vector3)
	local at = CENTRE + offset + Vector3.new(0, 3, 0)
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
local function signText(id: string): string
	local model = workspace:FindFirstChild("TurfZones") and workspace:FindFirstChild("TurfZones"):FindFirstChild(id)
	local label = model and World.find(model, "Status", "TextLabel")
	return label and label.Text or ""
end
local function dashColour(id: string): Color3?
	local model = workspace:FindFirstChild("TurfZones") and workspace:FindFirstChild("TurfZones"):FindFirstChild(id)
	local dash = model and model:FindFirstChild("Dash")
	return dash and dash.Color or nil
end

-- --------------------------------------------------------------- the patches --

print("four patches")
check(#Turf.Zones == 4, ("four patches (%d)"):format(#Turf.Zones))
local quarters = {}
for _, z in ipairs(Turf.Zones) do
	quarters[(z.offset.X > 0 and "E" or "W") .. (z.offset.Z > 0 and "N" or "S")] = z.id
	check(z.radius >= 10 and z.offset.Magnitude < 190, ("%s is a real patch inside the district"):format(z.name))
end
check(quarters.EN and quarters.WN and quarters.ES and quarters.WS, "one in each quarter of the district")
check(Turf.COOLDOWN >= 60, ("a war leaves its patch quiet for %ds"):format(Turf.COOLDOWN))

standAt(Vector3.new(0, 0, 0)) -- the plaza: on none of them
Turf.Step()
local folder = workspace:FindFirstChild("TurfZones")
check(folder ~= nil and #folder:GetChildren() == 4, "each patch is marked in the world")
local dashes = 0
for _, c in ipairs(folder and folder:FindFirstChild("CarPark"):GetChildren() or {}) do
	if c.Name == "Dash" then
		dashes += 1
		check(c.CanCollide == false and c.CanQuery == false and c.Anchored,
			"a dash is paint: nothing walks into it or shoots it")
		check(math.abs(c.CFrame.Position.Y - (GROUND_Y + 0.12)) < 0.01, "sitting just proud of the ground under it")
		break
	end
end
check(dashes > 0 and #folder:FindFirstChild("CarPark"):GetChildren() >= 20, "a ring of dashes round it")
check(signText("CarPark") == "STEP IN TO START A TURF WAR", ("its sign invites you in (%q)"):format(signText("CarPark")))
for _, z in ipairs(Turf.Zones) do
	check(Turf.Status(z.id) == "idle", z.name .. " is open")
end
check(#NPCService.spawned == 0, "nobody standing on a patch: no crew")

-- --------------------------------------------------------------- stepping in --

print("stepping in")
Turf.SetThreat(1)
standAt(zone("CarPark").offset + Vector3.new(4, 0, 3))
Turf.Step()
check(Turf.Status("CarPark") == "active", "stepping onto THE CAR PARK starts its war")
local crew = crewOf("CarPark")
check(#crew == 5, ("its crew comes out: %d"):format(#crew))
local furthest = 0
for _, s in ipairs(NPCService.spawned) do
	furthest = math.max(furthest, (Vector3.new(s.position.X, 0, s.position.Z)
		- Vector3.new(CENTRE.X + zone("CarPark").offset.X, 0, CENTRE.Z + zone("CarPark").offset.Z)).Magnitude)
	check(s.options.respawn == false and s.options.ignoreCap == true, "a crew member who does not come back")
	break
end
check(furthest <= zone("CarPark").radius, "round the edge of the patch")
local started = turfSent("start", "CarPark")
check(started ~= nil and started.zone == "THE CAR PARK" and started.total == 5 and typeof(started.position) == "Vector3",
	"everyone is told which patch, how many, and where")
check(Turf.Status("Courts") == "idle" and Turf.Status("Alley") == "idle" and Turf.Status("Park") == "idle",
	"the other three stay open")
check(signText("CarPark"):find("TURF WAR · 5 LEFT", 1, true) ~= nil, ("its sign counts them (%q)"):format(signText("CarPark")))
check(dashColour("CarPark") ~= dashColour("Courts"), "and its ring changes colour")
Turf.Step()
check(#crewOf("CarPark") == 5, "standing there longer does not start another")

-- A second patch, while the first is still on.
standAt(zone("Courts").offset)
Turf.Step()
check(Turf.Status("Courts") == "active" and Turf.Status("CarPark") == "active", "two patches can be at war at once")
check(#crewOf("Courts") == 5, "each with its own crew")

-- --------------------------------------------------------------- winning --

print("clearing a crew")
standAt(zone("CarPark").offset)
local coins = player:FindFirstChild("leaderstats"):FindFirstChild("Coins")
local before = coins.Value
for i, model in ipairs(crewOf("CarPark")) do
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	KillCredit.Damaged:Fire(humanoid, 100, player)
	if i < 5 then
		humanoid.Health = 0
	end
end
Turf.Step()
local progress = turfSent("progress", "CarPark")
check(progress ~= nil and progress.left == 1, "the count comes down as they drop")
local last = crewOf("CarPark")
for _, model in ipairs(last) do
	model:FindFirstChildOfClass("Humanoid").Health = 0
end
Turf.Step()
check(Turf.Status("CarPark") == "held", "the last one down: the street holds the patch")
local won = turfSent("won", "CarPark")
check(won ~= nil and won.mvp == "Tester" and won.held == true and won.control == 1 and won.total == 4,
	"a win, with the MVP, and the street holds 1 of 4")
local reward = turfSent("reward", "CarPark")
check(reward ~= nil and reward.mvp == true and reward.coins == 1650, "the fighter is paid, with the MVP bonus")
check(coins.Value - before == 1650, ("coins +%d"):format(coins.Value - before))
check(reward and reward.xp == GameConfig.ShownXP(1200), "and XP, shown at the rate it pays")
check(Turf.Threat() == 2, "the threat rises")
check(reward and reward.cred == Turf.CRED.win + Turf.CRED.mvp and player:GetAttribute("StreetCred") == reward.cred,
	("Street Cred for the win and the MVP (%s)"):format(tostring(player:GetAttribute("StreetCred"))))
check(reward and reward.bonus == 0 and reward.band == "Neutral", "an unknown name gets no bonus yet")
check(Turf.Status("Courts") == "active", "the other war carries on")
local rs = World.service("ReplicatedStorage")
check(rs:GetAttribute("Turf_CarPark") == "held" and rs:GetAttribute("Turf_Courts") == "war" and rs:GetAttribute("TurfControl") == 1,
	"each patch's state is published, and the street's hold")
local _, raidIn = Turf.Status("CarPark")
check(raidIn >= Turf.HOLD.raidAfter[1] - 1 and raidIn <= Turf.HOLD.raidAfter[2] + 1, ("its crew will be back in %ds"):format(raidIn))
check(signText("CarPark") == ("HELD BY THE STREET · $%d TRIBUTE"):format(Turf.TributeFor(2, false)),
	("the sign says whose it is (%q)"):format(signText("CarPark")))
check(dashColour("CarPark") ~= dashColour("Park"), "and its ring goes green")

-- --------------------------------------------------------------- holding it --

print("holding it")
local count = #NPCService.spawned
now += 60
Turf.Step()
check(Turf.Status("CarPark") == "held" and #NPCService.spawned == count, "standing on it a minute later: nothing starts")

-- Meanwhile the crew at THE COURTS has had nobody near it for over a minute: it has left.
check(Turf.Status("Courts") == "cooldown", "a crew left alone walks off, and its patch cools down")
check(#crewOf("Courts") == 0, "taking its crew with it")
check(turfSent("lost", "Courts") ~= nil, "everyone is told")
check(Turf.Threat() == 1, "and the threat falls back")
check(rs:GetAttribute("Turf_Courts") == "quiet", "THE COURTS shows quiet")

-- Tribute, every minute and a half, while the holder is in Downtown.
before = coins.Value
table.clear(sent)
now += Turf.HOLD.tributeEvery - 60 + 1
Turf.Step()
local tribute = turfSent("tribute", "CarPark")
check(tribute ~= nil and tribute.coins == Turf.TributeFor(1, false) and coins.Value - before == tribute.coins,
	("the patch pays its holder tribute ($%d)"):format(coins.Value - before))
check(Turf.TributeFor(1, true) > Turf.TributeFor(1, false), "more while the street holds every patch")
check(Turf.TributeFor(Turf.MAX_THREAT, true) * Turf.HOLD.raidAfter[2] / Turf.HOLD.tributeEvery < Turf.REWARD.coins,
	"a patch's tribute between raids, at its best, is less than one war pays: holding is a bonus, not the job")

-- The raid: the crew back for it, bigger at the threat by then.
Turf.SetThreat(3)
table.clear(sent)
now += Turf.HOLD.raidAfter[2] + 1
Turf.Step()
check(Turf.Status("CarPark") == "active", "a few minutes on, its crew comes back for it")
local raid = turfSent("start", "CarPark")
check(raid ~= nil and raid.raid == true and rs:GetAttribute("Turf_CarPark") == "raid", "a raid, and everyone is told")
check(#crewOf("CarPark") == #Turf.CrewFor(3), ("bigger at threat III (%d)"):format(#crewOf("CarPark")))
check(Turf.Control() == 1, "it is still the street's while they fight for it")

-- The clock running out on the raid: the crew have it back.
table.clear(sent)
now += Turf.DURATION + Turf.DURATION_PER_THREAT * 2 + 1
Turf.Step()
check(Turf.Status("CarPark") == "cooldown" and #crewOf("CarPark") == 0, "out of time: the crew take it back and leave")
local lostIt = turfSent("lost", "CarPark")
check(lostIt ~= nil and lostIt.raid == true and rs:GetAttribute("TurfControl") == 0, "the street holds none now")

-- --------------------------------------------------------------- street cred --

print("street cred")
check(Turf.CredBonus("Friendly") == 0.1 and Turf.CredBonus("Honoured") == 0.25 and Turf.CredBonus("Neutral") == 0,
	"a known name is paid a tenth more, a legend a quarter")
Turf.AddCred(player, 80)
local credNow, band = Turf.Cred(player)
check(band == "Honoured" and player:GetAttribute("StreetCred") == credNow, ("Honoured at %d"):format(credNow))

-- --------------------------------------------------------------- the kingpin --

print("the kingpin")
-- A war at threat V, won.
Turf.SetThreat(5)
now += Turf.COOLDOWN + 1
standAt(zone("CarPark").offset)
Turf.Step()
check(Turf.Status("CarPark") == "active" and #crewOf("CarPark") == 10, "a threat V crew of ten")
table.clear(sent)
before = coins.Value
for _, model in ipairs(crewOf("CarPark")) do
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	KillCredit.Damaged:Fire(humanoid, 100, player)
	humanoid.Health = 0
end
Turf.Step()
reward = turfSent("reward", "CarPark")
local expected = math.floor(Turf.RewardFor(5, true).coins * 1.25 + 0.5)
check(reward ~= nil and reward.bonus == 0.25 and coins.Value - before == expected,
	("Honoured: the war pays a quarter more ($%d)"):format(coins.Value - before))
local out, where = Turf.KingpinOut()
check(out and where == "CarPark", "winning at threat V brings the Kingpin out onto that patch")
local arrive = nil
for _, e in ipairs(sent) do
	if e.name == "TurfEvent" and e.args[1] == "kingpin" and e.args[2].stage == "arrive" then
		arrive = e.args[2]
	end
end
check(arrive ~= nil and arrive.zone == "THE CAR PARK" and arrive.seconds == Turf.KINGPIN_TIME, "everyone is told, with the clock")
local boss = nil
for _, s in ipairs(NPCService.spawned) do
	if s.archetype == "Kingpin" and s.model.Parent then
		boss = s.model
	end
end
check(boss ~= nil and boss:GetAttribute("Boss") == true and boss:GetAttribute("PhaseMarks") == "0.66,0.33",
	"a boss the health bar knows, with its phase marks")
check(not Turf.SummonKingpin("Park"), "only one Kingpin at a time")

local bossHumanoid = boss:FindFirstChildOfClass("Humanoid")
KillCredit.Damaged:Fire(bossHumanoid, 40, player)
local spawnedBefore = #NPCService.spawned
bossHumanoid.Health = 60
Turf.Step()
check(boss:GetAttribute("Phase") == 2 and #NPCService.spawned - spawnedBefore == #Turf.KINGPIN_PHASES[1].adds,
	"two thirds down: phase two, and backup is called in")
bossHumanoid.Health = 30
Turf.Step()
check(boss:GetAttribute("Phase") == 3, "one third: phase three")
before = coins.Value
local credBefore = Turf.Cred(player)
table.clear(sent)
bossHumanoid.Health = 0
Turf.Step()
reward = nil
for _, e in ipairs(sent) do
	if e.name == "TurfEvent" and e.args[1] == "reward" and e.args[2].kingpin then
		reward = e.args[2]
	end
end
check(reward ~= nil and reward.mvp and coins.Value - before == math.floor(Turf.KINGPIN_REWARD.coins * 1.5 + 0.5),
	("the Kingpin down: the bounty, with the MVP share ($%d)"):format(coins.Value - before))
check(Turf.Cred(player) - credBefore == math.min(Turf.CRED.kingpin, 100 - credBefore), "and Street Cred")
check(Turf.Threat() == Turf.THREAT_AFTER_KINGPIN, ("the crews scatter: threat back to %d"):format(Turf.Threat()))
check(not (Turf.KingpinOut()), "and the Kingpin is gone")
check(not Turf.SummonKingpin("Park"), "not back for a while")

now += Turf.KINGPIN_COOLDOWN + 1
check(Turf.SummonKingpin("Park"), "until the cooldown is up")
now += Turf.KINGPIN_TIME + 1
Turf.Step()
check(not (Turf.KingpinOut()) and Turf.Threat() == Turf.MAX_THREAT - 1, "left alone too long, the Kingpin walks away")

-- --------------------------------------------------------------- nobody home --

print("nobody home")
Turf.SetThreat(1)
standAt(zone("Alley").offset)
Turf.Step()
check(Turf.Status("Alley") == "active", "THE ALLEY's war")
for _, model in ipairs(crewOf("Alley")) do
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	KillCredit.Damaged:Fire(humanoid, 100, player)
	humanoid.Health = 0
end
Turf.Step()
check(Turf.Status("Alley") == "held" and rs:GetAttribute("Turf_Alley") == "held", "won: the street holds THE ALLEY")
standAt(Vector3.new(0, 0, 2000))
table.clear(sent)
now += Turf.HOLD.raidAfter[2] + 1
Turf.Step()
check(Turf.Status("Alley") == "idle" and turfSent("retaken", "Alley") ~= nil and rs:GetAttribute("Turf_Alley") == "crew",
	"nobody in Downtown when its crew comes back: they simply have it again")

print(failures == 0 and "\27[32mall turf checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
require("@lune/process").exit(failures == 0 and 0 or 1)
