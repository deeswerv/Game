--!nocheck
-- HANAMI CITY (HanamiService), the world past ZEE TOWER, checked without Studio on the real
-- city the service builds:
--
--   * the city: every marker the jobs and fights need, the area boxes and waypoints, its own
--     look; the Travel menu's arrival, the givers, the captives, the clues, the seals, the raid
--     site, both bosses and every post of the population stand on something solid and not
--     inside anything;
--   * the population wakes when somebody walks in (and only then), refills a fallen post after
--     a while, and goes back to sleep when the city has been empty for a minute;
--   * the shrine's bell heals you -- not mid-fight, and not twice in a row;
--   * Elder Hoshi's story, every step through the real QuestService: walk to the Lantern Row
--     gate; clear Lantern Row (a kill anywhere else does not count); free the three captives
--     (who kneel, tied, until you do -- and the camp takes more later); read four DIFFERENT
--     clues (the same one twice counts once); FOREMAN TETSU and his phases (adds, molten
--     splashes that hurt); hold the market through three waves (and lose it, both ways); find
--     five DIFFERENT seals; climb the Thousand Gates (the foot of the stair does not count);
--     and the IRON SHOGUN: not for anyone under level 12, then an intro, a court of guards,
--     blade waves, the blossom storm, iron fury, and the first clear saved with its title;
--     after a rest he is back for less; an empty court resets him;
--   * Captain Rei's bounties, and the repeatable patrol that counts anywhere in the city.
--
-- NPCService makes bare NPC models (the AI is not what is being checked); the clock is wound
-- by hand.
--
--   lune run tools/uitest/hanami.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

require("@lune/task").delay(400, function()
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

-- A hazard's floor is whatever the ring or the wave was cast over: under the feet.
R.ClassMethods.Workspace.Raycast = function(_, origin)
	return { Position = origin - Vector3.new(0, 7, 0), Normal = Vector3.new(0, 1, 0),
		Material = roblox.Enum.Material.Slate, Instance = World.workspace }
end

local sent = {}
R.ClassMethods.RemoteEvent.FireClient = function(self, _player, ...)
	table.insert(sent, { name = self.Name, args = { ... } })
end
R.ClassMethods.RemoteEvent.FireAllClients = function(self, ...)
	table.insert(sent, { name = self.Name, args = { ... } })
end
local function last(kind: string, remote: string?)
	for i = #sent, 1, -1 do
		local s = sent[i]
		if s.name == (remote or "HanamiEvent") and s.args[1] == kind then
			return s.args[2]
		end
	end
	return nil
end
local function count(kind: string, remote: string?): number
	local n = 0
	for _, s in ipairs(sent) do
		if s.name == (remote or "HanamiEvent") and s.args[1] == kind then
			n += 1
		end
	end
	return n
end

local place = World.loadPlace("build/Game.rbxl")
local rs = World.service("ReplicatedStorage")
local sss = World.service("ServerScriptService")
local player = World.player
local workspace = World.workspace
local Rig = require("./rig")
Rig.starter(World, place)

local profile = {
	Level = 1, EXP = 0, MaxEXP = 100, StatPoints = 0, Prestige = 0, LifetimeXP = 0,
	Crystals = 0, Titles = {}, OwnedItems = {}, Coins = 0, CoinsMigrated = true, TotalKills = 0,
	Reputation = {}, OwnedVFX = {}, EquippedVFX = {}, WeaponVFX = {}, OwnedCosmetics = {},
	CurrentQuest = "", QuestProgress = 0, QuestSeen = {}, CompletedQuests = {},
	TowerCleared = true, TowerClears = 1, HanamiCleared = false, HanamiClears = 0,
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

-- Bare NPCs: a root and a humanoid, stamped like NPCService stamps them (the zone they stand
-- in, their archetype, and whatever the caller asked for).
local npc = R.new("ModuleScript")
npc.Name = "NPCService"
npc.Source = [[
local NPCConfig = require(game:GetService("ReplicatedStorage").NPCConfig)
local NPCService = { spawned = {}, noise = 0 }
function NPCService.Spawn(archetype, position, options)
	local model = Instance.new("Model")
	local cfg = NPCConfig.Get(archetype)
	model.Name = cfg and cfg.DisplayName or archetype
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.new(position)
	root.Parent = model
	model.PrimaryPart = root
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = cfg and cfg.MaxHealth or 400
	humanoid.Health = humanoid.MaxHealth
	humanoid.WalkSpeed = 16
	humanoid.Parent = model
	local zone = NPCConfig.ZoneAt(position)
	model:SetAttribute("Archetype", archetype)
	model:SetAttribute("Zone", zone and zone.id or "None")
	for key, value in pairs(options and options.attributes or {}) do
		model:SetAttribute(key, value)
	end
	model.Parent = workspace
	table.insert(NPCService.spawned, { archetype = archetype, position = position, options = options, model = model })
	return model
end
function NPCService.Noise()
	NPCService.noise += 1
end
return NPCService
]]
npc.Parent = sss
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("NPCService"):FindFirstChild("Outfit"), npc)
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

for _, name in ipairs({ "ArenaService", "KillCredit", "ShopService", "ReputationService", "LevelSystem", "WalletService",
	"AbilityService", "VFXService", "QuestService", "TurfWarService", "TravelService", "HanamiService" }) do
	R.mirror(place:GetService("ServerScriptService"):FindFirstChild(name), sss)
end

local statsFolder = R.new("Folder")
statsFolder.Name = "Stats"
local levelValue = R.new("IntValue")
levelValue.Name = "Level"
levelValue.Value = 10
levelValue.Parent = statsFolder
statsFolder.Parent = player
player:SetAttribute("TowerCleared", true)
local coins = player:FindFirstChild("leaderstats"):FindFirstChild("Coins")
-- The level the game reads: LevelSystem keeps the player's Stats.Level in step with the profile.
local function setLevel(n: number)
	profile.Level = n
	levelValue.Value = n
	for _, f in ipairs(player:GetChildren()) do
		local lv = f.Name == "Stats" and f:FindFirstChild("Level")
		if lv then
			lv.Value = n
		end
	end
end

local HanamiConfig = World.require(rs.HanamiConfig)
local NPCConfig = World.require(rs.NPCConfig)
local QuestConfig = World.require(rs.QuestConfig)
local KillCredit = World.require(sss.KillCredit)
local QuestService = World.require(sss.QuestService)
local Travel = World.require(sss.TravelService)
local Hanami = World.require(sss.HanamiService)
local Jobs, Bosses = Hanami.Jobs, Hanami.Bosses
local now = 5000
Hanami.Clock = function()
	return now
end
World.advance(0.3)

local character = World.character
local root = character:FindFirstChild("HumanoidRootPart")
local humanoid = character:FindFirstChildOfClass("Humanoid")
humanoid.MaxHealth = 100
humanoid.Health = 100
local function standAt(world: Vector3)
	root.CFrame = CFrame.new(world + Vector3.new(0, 3, 0))
end
local function site(name: string): Vector3
	return HanamiConfig.Site(name)
end
local function step(times: number?)
	for _ = 1, times or 1 do
		Hanami.Step()
	end
	World.advance(0.05)
end
local function kill(model: Model)
	local h = model:FindFirstChildOfClass("Humanoid")
	KillCredit.Damage(h, h.Health + 10, player, "Carbine")
	-- The engine fires Died when health reaches zero; the harness leaves that to us.
	if h.Health <= 0 then
		R.fire(h, "Died")
	end
	World.advance(0.05)
end
local function hurt(model: Model, toFraction: number)
	local h = model:FindFirstChildOfClass("Humanoid")
	KillCredit.Damage(h, h.Health - h.MaxHealth * toFraction, player, "Carbine")
	World.advance(0.05)
end
local function living(filter: (Model) -> boolean): { Model }
	local out = {}
	for _, s in ipairs(NPCService.spawned) do
		local h = s.model:FindFirstChildOfClass("Humanoid")
		if s.model.Parent and h and h.Health > 0 and filter(s.model) then
			table.insert(out, s.model)
		end
	end
	return out
end
local function population(): { Model }
	return living(function(m)
		return m:GetAttribute("Hanami") == true and m:GetAttribute("Boss") == nil and m:GetAttribute("ForemanCrew") == nil
			and m:GetAttribute("ShogunGuard") == nil and m:GetAttribute("HanamiRaid") == nil
	end)
end
local function take(id: string)
	profile.CurrentQuest = ""
	local result = QuestService.Accept(player, id)
	World.advance(0.05)
	return result
end
local function done(id: string): boolean
	return table.find(profile.CompletedQuests, id) ~= nil
end
local function promptOn(inst: Instance): ProximityPrompt?
	return inst and inst:FindFirstChildWhichIsA("ProximityPrompt", true)
end
local function trigger(prompt: ProximityPrompt)
	R.fire(prompt, "Triggered", player)
	World.advance(0.05)
end

-- ------------------------------------------------------------------ the valley --

print("the valley")
local folder = workspace:FindFirstChild("Hanami")
check(folder ~= nil, "HanamiService builds the valley into workspace.Hanami")
local named: { [string]: { BasePart } } = {}
local solids = {}
local parts = 0
for _, d in ipairs(folder:GetDescendants()) do
	if d:IsA("BasePart") then
		parts += 1
		named[d.Name] = named[d.Name] or {}
		table.insert(named[d.Name], d)
		if d.CanCollide and d.Transparency < 0.95 then
			table.insert(solids, d)
		end
	end
end
print(("  (%d parts, %d solid)"):format(parts, #solids))
for name, want in pairs({ HanamiArrival = 1, CaptiveSpot = #HanamiConfig.Captives, RaidSite = 1, ForemanSpot = 1,
	ForemanAddSpot = 3, ShogunSpot = 1, CourtAddSpot = 6, KeepGate = 1, StairFoot = 1, HanamiCounter = 1, ShrineBell = 1,
	Clue = #HanamiConfig.Clues, SealSpot = #HanamiConfig.Seals }) do
	local have = named[name] and #named[name] or 0
	check(have == want, ("%s: %d (wants %d)"):format(name, have, want))
end
check(parts < 20000, ("a sane part count (%d)"):format(parts))
local counter = named.HanamiCounter and named.HanamiCounter[1]
check(counter and counter:GetAttribute("OpenPanel") == "Market" and promptOn(counter) ~= nil,
	"the trader's counter opens the shop")
check(typeof(folder:GetAttribute("ZoneCentre")) == "Vector3" and typeof(folder:GetAttribute("ZoneHalf")) == "Vector3"
	and folder:GetAttribute("Look_Grade_TintColor") ~= nil, "the valley has a look of its own (ArenaMood reads it)")
local areas, waypoints = {}, 0
for _, d in ipairs(folder:GetDescendants()) do
	if d:HasTag("Area") then
		areas[d:GetAttribute("AreaName")] = true
	end
	if d:HasTag("Waypoint") then
		waypoints += 1
	end
end
local allNamed = true
for _, a in ipairs(HanamiConfig.Areas) do
	allNamed = allNamed and areas[a.name] == true
end
check(allNamed and areas[HanamiConfig.NAME], "every area has its name box, and the whole valley one")
check(waypoints >= 8, ("%d landmarks on the compass"):format(waypoints))

-- Solid ground under a point, and nothing solid where a body would stand on it.
local function boxContains(p: BasePart, world: Vector3, pad: number): boolean
	local rel = p.CFrame:PointToObjectSpace(world)
	local h = p.Size / 2
	return math.abs(rel.X) <= h.X + pad and math.abs(rel.Y) <= h.Y + pad and math.abs(rel.Z) <= h.Z + pad
end
local function groundUnder(world: Vector3, below: number): number?
	local best = nil
	for _, p in ipairs(solids) do
		local rel = p.CFrame:PointToObjectSpace(world)
		local h = p.Size / 2
		if math.abs(rel.X) <= h.X and math.abs(rel.Z) <= h.Z then
			-- The top of the part under this point (axis-aligned parts, or near enough).
			local top = p.Position.Y + math.abs(p.CFrame.UpVector.Y) * h.Y + math.abs(p.CFrame.RightVector.Y) * h.X
				+ math.abs(p.CFrame.LookVector.Y) * h.Z
			if top <= world.Y + 0.6 and top >= world.Y - below and (not best or top > best) then
				best = top
			end
		end
	end
	return best
end
local function standable(world: Vector3, what: string)
	local ground = groundUnder(world, 2.5)
	local stuck = nil
	for _, p in ipairs(solids) do
		for _, y in ipairs({ 1.2, 3, 4.6 }) do
			if not stuck and boxContains(p, Vector3.new(world.X, (ground or world.Y) + y, world.Z), -0.3) then
				stuck = p.Name
			end
		end
	end
	check(ground ~= nil and stuck == nil, ("%s: on the ground%s"):format(what,
		if ground == nil then " -- NOTHING UNDER IT" elseif stuck then " -- but inside " .. stuck else ""))
end
local arrival = Travel.Arrival("Hanami")
check(arrival and HanamiConfig.Inside(arrival.Position), "the Travel menu lands you in the valley")
standable(arrival.Position - Vector3.new(0, 3.4, 0), "the Travel arrival")
for _, name in ipairs({ "Elder", "Captain" }) do
	standable(QuestConfig.Givers[name].position, QuestConfig.Givers[name].displayName)
	check(workspace:FindFirstChild("QuestGiver_" .. name) ~= nil, QuestConfig.Givers[name].displayName .. " is standing there")
end
for i, c in ipairs(HanamiConfig.Captives) do
	standable(HanamiConfig.CENTRE + c, "captive " .. i)
end
standable(site("Market"), "the auction floor")
standable(named.ForemanSpot[1].Position, "Foreman Tetsu's spot")
standable(named.ShogunSpot[1].Position, "the Shogun's spot")
for i, p in ipairs(named.CourtAddSpot) do
	standable(p.Position, "court add spot " .. i)
end
standable(site("KeepGate"), "the gate of the Keep")
for i, s in ipairs(HanamiConfig.Seals) do
	standable(HanamiConfig.CENTRE + s, "seal " .. i)
end
for _, spec in ipairs(HanamiConfig.Population) do
	standable(HanamiConfig.CENTRE + spec.at, ("%s's post at (%d, %d, %d)"):format(spec.archetype, spec.at.X, spec.at.Y, spec.at.Z))
	local area = HanamiConfig.AreaAt(spec.at)
	if area and area.safe then
		check(false, spec.archetype .. " posted in the village, where nobody fights")
	end
end
for _, clue in ipairs(named.Clue or {}) do
	check(groundUnder(clue.Position, 4) ~= nil, clue:GetAttribute("ClueId") .. ": the clue lies on something")
end

print("the enemies")
for _, archetype in ipairs({ "Ronin", "Rifleman", "Juggernaut", "Shinobi", "Shieldbearer", "Oni", "Foreman", "Shogun" }) do
	local cfg = NPCConfig.Get(archetype)
	check(cfg ~= nil and cfg.Clan == true, archetype .. " is a Kurogane archetype")
end
check(NPCConfig.Get("Shieldbearer").Shield and NPCConfig.Get("Shieldbearer").Behaviour == "Shield",
	"the Shieldbearer carries a shield and fights behind it")
check(NPCConfig.Get("Shinobi").Charge ~= nil, "the Shinobi dashes in")
local lantern = NPCConfig.ZoneAt(HanamiConfig.At(-150, 0, 30))
local keep = NPCConfig.ZoneAt(HanamiConfig.At(0, 30, 180))
check(lantern and lantern.id == "Hanami_LanternRow" and keep and keep.id == "Hanami_Keep"
	and keep.level[1] > lantern.level[1], "the valley's zones, tougher toward the Keep")

-- ------------------------------------------------------------- the population --

print("the population")
standAt(HanamiConfig.At(0, 0, 400) + Vector3.new(0, 0, 400))
step()
check(not Hanami.Awake() and #population() == 0, "nobody in the valley: nobody posted")
table.clear(sent)
standAt(site("Arrival"))
step()
check(Hanami.Awake() and #population() == #HanamiConfig.Population,
	("walk in and it wakes: %d of %d posts filled"):format(#population(), #HanamiConfig.Population))
check(player:GetAttribute("InHanami") == true and last("enter") ~= nil, "the player is marked as in the valley, and told")
check(Bosses.Foreman() ~= nil, "Foreman Tetsu is in his yard")
local first = population()[1]
local firstArchetype = first:GetAttribute("Archetype")
kill(first)
step()
check(#population() == #HanamiConfig.Population - 1, "a post falls")
now += Hanami.RESPAWN + 1
step()
check(#population() == #HanamiConfig.Population, "and is filled again after a while (" .. tostring(firstArchetype) .. ")")
standAt(Vector3.new(-155, 1000.5, 1500))
step()
check(Hanami.Awake(), "leave, and it stays awake for a bit")
now += Hanami.EMPTY_AFTER + 1
step()
check(not Hanami.Awake() and #population() == 0 and player:GetAttribute("InHanami") == nil,
	"empty for a minute: everyone goes home")
standAt(site("Arrival"))
step()
check(Hanami.Awake() and #population() == #HanamiConfig.Population, "and comes back when you do")

-- ----------------------------------------------------------------- the shrine --

print("the shrine")
standAt(site("Shrine"))
humanoid.Health = 40
local ok, why = Hanami.Pray(player)
check(ok and humanoid.Health == humanoid.MaxHealth and last("blessed") ~= nil, "the bell heals you to full")
humanoid.Health = 40
ok, why = Hanami.Pray(player)
check(not ok and why == "cooldown", "not twice in a row")
now += Hanami.PRAY_COOLDOWN + 1
KillCredit.Damage(humanoid, 5, nil, "Test")
ok, why = Hanami.Pray(player)
check(not ok and why == "fighting", "nor in the middle of a fight")
now += Hanami.PRAY_CALM + 1
ok = Hanami.Pray(player)
check(ok and humanoid.Health == humanoid.MaxHealth, "a breath later, it does")
local bell = named.ShrineBell[1]
check(promptOn(bell) and promptOn(bell).ActionText == "Pray", "the bell's prompt says Pray")

-- ------------------------------------------------------------ Elder Hoshi --

print("the story starts")
setLevel(10)
player:SetAttribute("TowerCleared", nil)
profile.TowerCleared = false
check(Travel.Locked(player, "Hanami") ~= nil, "the valley is shut until ZEE TOWER falls")
local state = QuestService.GetState(player, "Elder")
check(state and state.offer == nil and state.locked == "Tower", "and so is the Elder's story")
player:SetAttribute("TowerCleared", true)
profile.TowerCleared = true
check(Travel.Locked(player, "Hanami") == nil, "the Don beaten, the valley is on the Travel menu")
state = QuestService.GetState(player, "Elder")
check(state.offer and state.offer.id == "PetalsAndIron", "Elder Hoshi starts the story: " .. tostring(state.offer and state.offer.id))
check(QuestService.ResolveNode(player, "Elder") ~= nil and QuestService.ResolveNode(player, "Captain") ~= nil,
	"both givers have something to say")
for _, q in ipairs(QuestConfig.Quests) do
	if (q.giver == "Elder" or q.giver == "Captain") and q.objective.position then
		local w = QuestService.WaypointFor(q.objective)
		check(w and HanamiConfig.Inside(w), q.id .. ": the compass points into the valley")
	end
end

print("Petals and Iron: walk to the Lantern Row gate")
take("PetalsAndIron")
standAt(site("Arrival"))
QuestService.RegisterReach(player)
check(profile.CurrentQuest == "PetalsAndIron", "not from the village")
standAt(site("LanternGate"))
QuestService.RegisterReach(player)
check(done("PetalsAndIron"), "at the gate: done")

print("Lantern Row: eight of them, there")
take("LanternRow")
local outside = living(function(m)
	return m:GetAttribute("Zone") == "Hanami_Ironworks"
end)[1]
kill(outside)
check(profile.QuestProgress == 0, "a kill in the Ironworks does not count")
local row = living(function(m)
	return m:GetAttribute("Zone") == "Hanami_LanternRow"
end)
for i = #row + 1, 8 do
	table.insert(row, Hanami.Spawn("Ronin", Vector3.new(-90 - i * 6, 0, 20)))
end
for i = 1, 8 do
	kill(row[i])
end
check(done("LanternRow"), "eight on Lantern Row: done")

print("Taken in the Night: the captives")
setLevel(11)
take("TakenInTheNight")
local captives = {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Model") and d:GetAttribute("Captive") == true then
		table.insert(captives, d)
	end
end
check(#captives == 3, ("three captives at the camp (%d)"):format(#captives))
check(captives[1] and captives[1]:HasTag("Staff") and promptOn(captives[1])
	and promptOn(captives[1]).ActionText == "Free" and promptOn(captives[1]).HoldDuration >= 1,
	"each one tied up (posed like staff), with a held \"Free\" prompt")
trigger(promptOn(captives[1]))
check(captives[1]:GetAttribute("Captive") == nil and captives[1]:GetAttribute("Freed") == true and last("rescued").left == 2,
	"cut loose, and told how many are left")
check(profile.QuestProgress == 1, "one freed")
QuestService.RegisterEvent(player, "rescue", { id = "Captive1" })
check(profile.QuestProgress == 1, "the same captive does not count twice")
trigger(promptOn(captives[2]))
trigger(promptOn(captives[3]))
check(done("TakenInTheNight"), "all three: done")
World.advance(3)
check(captives[1].Parent == nil, "they run for home")
now += Jobs.RETIE + 1
step()
local retied = 0
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Model") and d:GetAttribute("Captive") == true then
		retied += 1
	end
end
check(retied == 3, "and the camp takes more, later")

print("Iron and Ash: four different clues")
take("IronAndAsh")
local clues = {}
for _, c in ipairs(named.Clue) do
	clues[c:GetAttribute("ClueId")] = c
end
trigger(promptOn(clues.Ledger))
trigger(promptOn(clues.Ledger))
local clue = last("clue")
check(clue and clue.title == "A burnt ledger" and clue.total == 4 and #clue.text > 10, "a clue is read out to you")
check(profile.QuestProgress == 1, "reading the same one twice counts once")
for _, id in ipairs({ "Crate", "Orders", "Map" }) do
	trigger(promptOn(clues[id]))
end
check(done("IronAndAsh"), "four different ones: done")

print("The Foreman")
setLevel(12)
take("TheForeman")
local foreman = Bosses.Foreman()
check(foreman and foreman.Name == "Foreman Tetsu" and foreman:GetAttribute("Boss") == true
	and foreman:GetAttribute("PhaseMarks") == "0.6,0.3", "Foreman Tetsu, on the boss bar with his phase marks")
standAt(foreman.PrimaryPart.Position - Vector3.new(0, 3, 0) + Vector3.new(10, 0, 0))
table.clear(sent)
hurt(foreman, 0.55)
step()
local crew = living(function(m)
	return m:GetAttribute("ForemanCrew") == true
end)
check(foreman:GetAttribute("Phase") == 2 and #crew == 2 and last("bossPhase").name == "STOKE THE FURNACE",
	"60%: STOKE THE FURNACE, and two of the line come off it")
now += 2
humanoid.Health = 100
step()
local hazards = workspace:FindFirstChild("HanamiHazards")
check(hazards and hazards:FindFirstChild("BossRing") ~= nil, "a molten splash is marked under you")
World.advance(Bosses.FOREMAN.splash.warn + 0.2)
check(humanoid.Health < 100 and last("explode", "UtilityEvent") ~= nil,
	("and bursts: you are burned (%d health)"):format(humanoid.Health))
humanoid.Health = 100
local speed = foreman:FindFirstChildOfClass("Humanoid").WalkSpeed
hurt(foreman, 0.25)
step()
check(foreman:GetAttribute("Phase") == 3 and foreman:FindFirstChildOfClass("Humanoid").WalkSpeed > speed
	and last("bossPhase").name == "OVERTIME", "30%: OVERTIME, and he speeds up")
local before = coins.Value
kill(foreman)
step()
check(last("bossWon") and last("bossWon").name == "FOREMAN TETSU" and coins.Value >= before + Bosses.FOREMAN.reward.coins,
	"down: the fighters are paid")
check(done("TheForeman"), "and the job is done")
check(Bosses.Foreman() == nil, "he is gone from the yard")
now += Bosses.FOREMAN.respawn + 1
step()
check(Bosses.Foreman() ~= nil and Bosses.Foreman() ~= foreman, "and back on shift after a long rest")

print("Hold the Market")
take("HoldTheFarm")
local raidSite = named.RaidSite[1]
standAt(site("Market"))
table.clear(sent)
trigger(promptOn(raidSite))
local farmers = {}
for _, d in ipairs(workspace:GetDescendants()) do
	if d:IsA("Model") and d:GetAttribute("HandsUpAt") ~= nil then
		table.insert(farmers, d)
	end
end
check(Jobs.Raid() ~= nil and last("raid") ~= nil, "the raid starts on the auction floor")
check(#farmers == 2, "the market hands put their hands up")
local waves = #HanamiConfig.Raid.waves
for w = 1, waves do
	now += Jobs.RAID_BREAK + 4
	step()
	local raiders = living(function(m)
		return m:GetAttribute("HanamiRaid") == true
	end)
	check(#raiders == #HanamiConfig.Raid.waves[w] and Jobs.Raid().wave == w, ("wave %d: %d raiders"):format(w, #raiders))
	if w == 1 then
		check(NPCService.noise > 0, "they are drawn to the market")
	end
	for _, m in ipairs(raiders) do
		kill(m)
	end
	now += 1
	step()
end
check(Jobs.Raid() == nil and last("raidWon") ~= nil, "three waves held: the market stands")
check(done("HoldTheFarm"), "and the job is done")
local handsDown = true
for _, f in ipairs(farmers) do
	handsDown = handsDown and f:GetAttribute("HandsUpAt") == nil
end
check(handsDown, "the market hands put their hands down")
ok, why = Jobs.StartRaid(player)
check(not ok and why == "cooldown", "the raiders need time to regroup")
now += Jobs.RAID_COOLDOWN + 1
ok = Jobs.StartRaid(player)
now += 5
step()
local raider = living(function(m)
	return m:GetAttribute("HanamiRaid") == true
end)[1]
raider.PrimaryPart.CFrame = CFrame.new(site("Market") + Vector3.new(0, 3, 6))
for _ = 1, 30 do
	now += 2
	step()
	if not Jobs.Raid() then
		break
	end
end
check(Jobs.Raid() == nil and last("raidLost") and last("raidLost").why == "The market fell",
	"a raider left on the auction floor wears it down, and the market falls")
now += 31
ok, why = Jobs.StartRaid(player)
check(ok, "the raiders come back: " .. tostring(why))
standAt(site("Arrival"))
for _ = 1, 15 do
	now += 2
	step()
end
check(Jobs.Raid() == nil and last("raidLost").why == "Nobody held the market", "and nobody in the hall loses it too")

print("Iron Seals: five different seals")
setLevel(13)
take("IronSeals")
local seals = {}
for _, d in ipairs(folder:GetDescendants()) do
	if d.Name == "IronSeal" then
		table.insert(seals, d)
	end
end
check(#seals == #HanamiConfig.Seals, ("%d seals, glowing where they are hidden"):format(#seals))
trigger(promptOn(seals[1]))
trigger(promptOn(seals[1]))
check(profile.QuestProgress == 1 and last("seal").total == 5, "the same seal twice counts once")
for i = 2, #seals do
	trigger(promptOn(seals[i]))
end
check(done("IronSeals"), "five: done")

print("The Thousand Gates")
setLevel(14)
take("ThousandGates")
standAt(site("StairFoot"))
QuestService.RegisterReach(player)
check(profile.CurrentQuest == "ThousandGates", "the foot of the stair is not the top")
standAt(site("KeepGate"))
QuestService.RegisterReach(player)
check(done("ThousandGates"), "the gate of the Keep: done")

print("The Iron Shogun")
take("IronShogun")
setLevel(11)
standAt(site("Court"))
table.clear(sent)
step()
check(Bosses.State() == "idle" and last("note") and last("note").title == "The Shogun does not look up",
	"under level 12 he does not even look up")
setLevel(14)
step()
check(Bosses.State() == "intro" and last("bossIntro") ~= nil, "level 14 walks in: the intro")
now += Bosses.SHOGUN.intro + 0.1
step()
local shogun = Bosses.Shogun()
local sh = shogun and shogun:FindFirstChildOfClass("Humanoid")
local guards = living(function(m)
	return m:GetAttribute("ShogunGuard") == true
end)
check(Bosses.State() == "fight" and shogun and shogun.Name == "The Iron Shogun" and shogun:GetAttribute("Boss") == true,
	"the Iron Shogun rises, on the boss bar")
check(sh and sh.MaxHealth == Bosses.SHOGUN.baseHealth and #guards == 2 and last("bossStart").health == sh.MaxHealth,
	("%d health for one, and two Oni at his side"):format(sh and sh.MaxHealth or 0))
humanoid.Health = 100
standAt(shogun.PrimaryPart.Position - Vector3.new(0, 3, 0) + Vector3.new(0, 0, -20))
now += 4.1
step()
check(hazards:FindFirstChild("BladeStrip") ~= nil, "a blade wave is marked across the court, at you")
World.advance(Bosses.SHOGUN.wave.warn + 0.5)
check(humanoid.Health <= 100 - Bosses.SHOGUN.wave.damage + 0.01, ("and cuts (%d health)"):format(humanoid.Health))
humanoid.Health = 100
hurt(shogun, 0.6)
step()
local storm = living(function(m)
	return m:GetAttribute("ShogunGuard") == true
end)
check(shogun:GetAttribute("Phase") == 2 and last("bossPhase").name == "BLOSSOM STORM" and #storm == 2 + 5,
	"66%: BLOSSOM STORM, and the walls fill with Shinobi and riflemen")
now += 2.1
step()
check(hazards:FindFirstChild("BossRing") ~= nil, "a petal storm opens under you")
World.advance(Bosses.SHOGUN.ring.warn + 0.2)
check(humanoid.Health < 100, "and hurts")
humanoid.Health = 100
local pace = sh.WalkSpeed
hurt(shogun, 0.3)
step()
check(shogun:GetAttribute("Phase") == 3 and last("bossPhase").name == "IRON FURY" and sh.WalkSpeed > pace,
	"33%: IRON FURY, and he is quicker")
for _, c in ipairs(hazards:GetChildren()) do
	c:Destroy()
end
local strips = 0
for _ = 1, 12 do
	now += 1
	step()
	for _, c in ipairs(hazards:GetChildren()) do
		if c.Name == "BladeStrip" then
			strips += 1
		end
	end
	if strips > 0 then
		break
	end
end
check(strips == 3, ("in his fury the blades come three at a time (%d)"):format(strips))
World.advance(2)
humanoid.Health = 100
before = coins.Value
local crystalsBefore = Crystals.awarded
kill(shogun)
step()
local won = last("bossWon")
check(won and won.final and won.first and won.title == "Shogun Slayer", "THE IRON SHOGUN DEFEATED, the first time")
check(coins.Value >= before + Bosses.SHOGUN.first.coins and Crystals.awarded >= crystalsBefore + Bosses.SHOGUN.first.crystals,
	"the biggest purse in the game")
check(profile.HanamiCleared == true and profile.HanamiClears == 1 and table.find(profile.Titles, "Shogun Slayer")
	and player:GetAttribute("HanamiCleared") == true, "saved: the valley is free, and the title is yours")
check(done("IronShogun"), "the story is done")
check(last("announce") and last("announce").big, "and the whole server hears about it")
check(Bosses.State() == "cooldown", "he rests")
now += Bosses.SHOGUN.cooldown + 1
step()
check(Bosses.State() == "intro", "and comes back")
now += Bosses.SHOGUN.intro + 0.1
step()
before = coins.Value
kill(Bosses.Shogun())
step()
check(last("bossWon") and not last("bossWon").first and coins.Value >= before + Bosses.SHOGUN.again.coins
	and coins.Value < before + Bosses.SHOGUN.first.coins and profile.HanamiClears == 2, "beaten again, for less")
now += Bosses.SHOGUN.cooldown + 1
step()
now += Bosses.SHOGUN.intro + 0.1
step()
check(Bosses.State() == "fight", "a third fight")
standAt(site("KeepGate"))
step()
now += Bosses.SHOGUN.resetAfter + 1
step()
check(Bosses.State() == "idle" and Bosses.Shogun() == nil and last("bossReset") ~= nil, "an empty court resets him")

-- ----------------------------------------------------------------- Captain Rei --

print("Captain Rei")
state = QuestService.GetState(player, "Captain")
check(state.offer and state.offer.id == "ShieldWall", "Captain Rei's first bounty: " .. tostring(state.offer and state.offer.id))
take("ShieldWall")
local shield = Hanami.Spawn("Shieldbearer", Vector3.new(-100, 0, 60))
kill(shield)
check(profile.QuestProgress == 1, "a Shieldbearer counts")
for _, id in ipairs({ "ShieldWall", "Shadows", "Giants", "OniAtTheGate" }) do
	if not done(id) then
		table.insert(profile.CompletedQuests, id)
	end
end
profile.CurrentQuest = ""
local patrol = QuestConfig.NextAvailable("Captain", 14, (function()
	local set = {}
	for _, id in ipairs(profile.CompletedQuests) do
		set[id] = true
	end
	return set
end)(), { Tower = true })
check(patrol and patrol.id == "Contract_Patrol" and patrol.repeatable, "then the repeatable patrol")
check(QuestService.ObjectiveMatches(patrol.objective, "Ronin", { zone = "Hanami_Keep" })
	and not QuestService.ObjectiveMatches(patrol.objective, "Grunt", { zone = "Downtown" }),
	"which counts anywhere in the valley, and only there")

print(failures == 0 and "\27[32mall hanami checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
require("@lune/process").exit(failures == 0 and 0 or 1)
