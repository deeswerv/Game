--!nocheck
-- Killstreak rewards (StreakConfig, BountyService's streak, StreakRewardService, KillCredit's
-- overshield, the Streaks client and the meter), checked without Studio:
--
--   * the rewards come at 3, 5 and 8 kills out in the world, and another airstrike every 4
--     after; the streak is on the player for the HUD;
--   * 3: the radar starts, for the one who earned it;
--   * 5: an overshield of 60 goes on, everyone is told, and hits come off it before armour
--     and health (and the damage preview agrees);
--   * 8: an airstrike charge. Calling it: refused without one, too far away or in a duel;
--     called, everyone is warned where and when, a line of shells lands after the warning --
--     the frag's blast, so the kills are the caller's and the streak runs on;
--   * dying ends it: the streak and an unused airstrike both go;
--   * the client: holding the key with a charge shows the aim mark, letting go calls it on
--     the crosshair; the radar outlines the fighters in range; the warning draws the zone
--     and a jet; the meter shows the streak, lights what is earned and says what it does.
--
-- The world is a flat floor at y = 0.
--
--   lune run tools/uitest/streaks.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local Rig = require("./rig")
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

R.ClassMethods.Workspace.Raycast = function(_self, origin, direction)
	if direction.Y < 0 and origin.Y >= 0 then
		local t = -origin.Y / direction.Y
		if t <= 1 then
			return { Position = origin + direction * t, Normal = Vector3.new(0, 1, 0), Instance = World.workspace,
				Material = roblox.Enum.Material.Concrete, Distance = t }
		end
	end
	return nil
end

local sent, toServer = {}, {}
R.ClassMethods.RemoteEvent.FireClient = function(self, target, ...)
	table.insert(sent, { name = self.Name, to = target, args = { ... } })
end
R.ClassMethods.RemoteEvent.FireAllClients = function(self, ...)
	table.insert(sent, { name = self.Name, all = true, args = { ... } })
end
R.ClassMethods.RemoteEvent.FireServer = function(self, ...)
	table.insert(toServer, { name = self.Name, args = { ... } })
end
local function events(remote, kind)
	local out = {}
	for _, e in ipairs(sent) do
		if e.name == remote and e.args[1] == kind then
			table.insert(out, e)
		end
	end
	return out
end

local place = World.loadPlace("build/Game.rbxl")
local rs = World.service("ReplicatedStorage")
local sss = World.service("ServerScriptService")
local player = World.player
local Config = World.require(rs.StreakConfig)

-- ---------------------------------------------------------------- the table --

print("when")
check(Config.RewardAt(3).id == "Radar" and Config.RewardAt(5).id == "Overshield" and Config.RewardAt(8).id == "Airstrike",
	"radar at 3, overshield at 5, airstrike at 8")
check(Config.RewardAt(12).id == "Airstrike" and Config.RewardAt(16).id == "Airstrike" and Config.RewardAt(13) == nil
	and Config.RewardAt(4) == nil, "another airstrike every 4 after (12, 16), nothing between")
check(Config.NextAt(0) == 3 and Config.NextAt(3) == 5 and Config.NextAt(8) == 12 and Config.NextAt(13) == 16,
	"and the meter can say what is next")

-- ------------------------------------------------------------------- server --

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
function Replica:SetValue(key, value) data[key] = value end
function Replica:ListenToChange() end
function Replica:IsActive() return true end
local PDM = {}
function PDM.Bind(profile) data = profile Replica.Data = profile end
function PDM:GetPlayerDataReplica()
	return { expect = function() return Replica end, andThen = function(_, fn) pcall(fn, Replica) return { catch = function() end } end }
end
function PDM:SaveNow() return true end
function PDM:IsSaving() return true end
return PDM
]]
stub.Parent = sss
World.require(stub).Bind(profile)
local npcStub = R.new("ModuleScript")
npcStub.Name = "NPCService"
npcStub.Source = "local N = {} function N.Noise() end return N"
npcStub.Parent = sss

for _, name in ipairs({ "KillCredit", "SmokeField", "UtilityService", "ShopService", "ReputationService",
	"LevelSystem", "WalletService", "AbilityService", "VFXService", "BountyService", "StreakRewardService" }) do
	R.mirror(place:GetService("ServerScriptService"):FindFirstChild(name), sss)
end
local rig = Rig.character(World, place)
local humanoid = rig:FindFirstChildOfClass("Humanoid")
local root = rig:FindFirstChild("HumanoidRootPart")
root.CFrame = CFrame.new(0, 3, 0)
player:SetAttribute("Level", 10)
local KillCredit = World.require(sss.KillCredit)
World.require(sss.UtilityService)
World.require(sss.BountyService)
local Streaks = World.require(sss.StreakRewardService)
World.advance(0.2)

local npcs = World.workspace:FindFirstChild("NPCs") or R.new("Folder")
npcs.Name = "NPCs"
npcs.Parent = World.workspace
local CS = World.service("CollectionService")
local made = 0
local function fighter(at)
	made += 1
	local model = R.new("Model")
	model.Name = "Thug" .. made
	local r = R.new("Part")
	r.Name = "HumanoidRootPart"
	r.Size = Vector3.new(2, 2, 1)
	r.CFrame = CFrame.new(at)
	World.force(r, "AssemblyLinearVelocity", Vector3.new(0, 0, 0))
	r.Parent = model
	local h = R.new("Humanoid")
	h.MaxHealth = 150
	h.Health = 150
	h.Parent = model
	model.PrimaryPart = r
	model.Parent = npcs
	CS:AddTag(model, "GameNPC")
	return model, h
end
-- The harness does not raise Died by itself; the engine does the moment health reaches 0.
local function died(h)
	if h.Health <= 0 and not h:GetAttribute("_died") then
		h:SetAttribute("_died", true)
		R.fire(h, "Died")
	end
end
local function kill()
	local _, h = fighter(Vector3.new(200 + made * 5, 3, 200))
	KillCredit.Damage(h, 1000, player, "Carbine")
	died(h)
	World.advance(0.05)
end

print("earning them")
for _ = 1, 2 do
	kill()
end
check(player:GetAttribute("Streak") == 2 and #events("StreakEvent", "reward") == 0,
	"two kills: the streak is on you, nothing earned yet")
kill()
local radar = events("StreakEvent", "radar")[1]
check(radar and radar.to == player and radar.args[2].duration == Config.Radar.duration,
	("three: the radar, for you alone, for %ds"):format(radar and radar.args[2].duration or -1))
local reward = events("StreakEvent", "reward")[1]
check(reward and reward.args[2].id == "Radar" and reward.args[2].streak == 3, "and you are told what you earned")
kill()
kill()
check(rig:GetAttribute("Overshield") == Config.Overshield.amount and rig:GetAttribute("MaxOvershield") == Config.Overshield.amount,
	("five: an overshield of %d"):format(rig:GetAttribute("Overshield") or -1))
local shown = events("StreakEvent", "overshield")[1]
check(shown and shown.all and shown.args[2].userId == player.UserId, "and everyone sees it go up")

print("the overshield")
rig:SetAttribute("Armour", 50)
humanoid.Health = 100
check(KillCredit.Mitigate(humanoid, 100) == 0, "the damage preview counts it (a 100 hit lands nothing)")
KillCredit.Damage(humanoid, 40, nil, "Test")
check(rig:GetAttribute("Overshield") == 20 and rig:GetAttribute("Armour") == 50 and humanoid.Health == 100,
	"a hit comes off the shield first, armour and health untouched")
KillCredit.Damage(humanoid, 50, nil, "Test")
check(rig:GetAttribute("Overshield") == 0 and rig:GetAttribute("Armour") == 20 and humanoid.Health == 100,
	"the next breaks it and runs on into the armour")
KillCredit.Damage(humanoid, 30, nil, "Test")
check(rig:GetAttribute("Armour") == 0 and humanoid.Health == 90, "then armour, then health, as before")
rig:SetAttribute("Armour", 0)
humanoid.Health = 100

print("the airstrike")
kill()
kill()
check(Streaks.ChargesOf(player) == 0, "seven: not yet")
kill()
check(Streaks.ChargesOf(player) == 1 and player:GetAttribute("AirstrikeCharges") == 1, "eight: one airstrike to call")

local ok, why = Streaks.CallAirstrike(player, Vector3.new(0, 0, -(Config.Airstrike.range + 40)))
check(not ok and why == "too far" and Streaks.ChargesOf(player) == 1, "not further away than " .. Config.Airstrike.range)
ok, why = Streaks.CallAirstrike(player, "over there")
check(not ok and Streaks.ChargesOf(player) == 1, "not somewhere that is not a place")
player:SetAttribute("DuelState", "duel")
ok, why = Streaks.CallAirstrike(player, Vector3.new(0, 0, -60))
check(not ok and why == "in a duel", "not from a duel")
player:SetAttribute("DuelState", nil)

-- Two fighters standing where it lands, one a long way off it.
local _, underA = fighter(Vector3.new(0, 3, -60))
local _, underB = fighter(Vector3.new(4, 3, -66))
local _, clear = fighter(Vector3.new(60, 3, -60))
local streakBefore = player:GetAttribute("Streak")
table.clear(sent)
local called = os.clock()
ok = Streaks.CallAirstrike(player, Vector3.new(0, 7, -60))
check(ok == true and Streaks.ChargesOf(player) == 0 and player:GetAttribute("AirstrikeCharges") == 0, "called: the charge is spent")
local warn = events("StreakEvent", "airstrike")[1]
local w = warn and warn.args[2]
check(warn and warn.all, "everyone is warned")
check(w and w.at.Y == 0 and math.abs(w.at.Z + 60) < 0.01, "on the ground under the mark")
check(w and #w.points == Config.Airstrike.shells and math.abs((w.points[1] - w.points[#w.points]).Magnitude - Config.Airstrike.length) < 0.01,
	("a line of %d shells, %d studs long"):format(w and #w.points or 0, Config.Airstrike.length))
check(w and w.dir.Z < -0.99, "along the run from the caller")
check(w and math.abs(w.hitAt - called - Config.Airstrike.warning) < 0.2 and w.name == player.DisplayName,
	"with when, and whose")
World.advance(Config.Airstrike.warning * 0.5)
check(#events("UtilityEvent", "explode") == 0 and underA.Health == 150, "nothing lands during the warning")
World.advance(Config.Airstrike.warning * 0.5 + Config.Airstrike.gap * Config.Airstrike.shells + 0.6)
check(#events("UtilityEvent", "explode") == Config.Airstrike.shells, ("then %d blasts"):format(#events("UtilityEvent", "explode")))
check(underA.Health <= 0 and underB.Health <= 0 and clear.Health == 150, "the two under it are dead, the one clear of it untouched")
died(underA)
died(underB)
World.advance(0.1)
check(player:GetAttribute("Streak") == streakBefore + 2, ("and they are your kills: the streak runs on (%d)"):format(
	player:GetAttribute("Streak") or -1))
ok, why = Streaks.CallAirstrike(player, Vector3.new(0, 0, -60))
check(not ok and why == "no airstrike", "one call per charge")

print("dying")
for _ = 1, 2 do
	kill()
end
check(player:GetAttribute("Streak") == 12 and Streaks.ChargesOf(player) == 1, "twelve: another airstrike")
table.clear(sent)
humanoid.Health = 0
died(humanoid)
World.advance(0.2)
check(player:GetAttribute("Streak") == 0 and Streaks.ChargesOf(player) == 0, "dying ends the streak and takes the airstrike")
check(#events("StreakEvent", "reset") == 1, "and your screen is told")

-- ------------------------------------------------------------------- client --

print("the client")
humanoid.Health = 100
local screen = R.new("ScreenGui")
screen.Parent = World.service("Players").LocalPlayer:FindFirstChild("PlayerGui")
local Meter = World.require(rs.UI.Modules.Streaks)
local meter = Meter.new(screen)
local group = screen:FindFirstChild("Streaks")
check(group and group.GroupTransparency > 0.3, "at a streak of 0 the meter sits back")
meter:SetStreak(4)
meter:Radar(12)
check(group.GroupTransparency == 0 and group.Count:FindFirstChildWhichIsA("TextLabel", true) ~= nil, "on a streak it comes forward")
local radarChip, shieldChip, strikeChip = group:FindFirstChild("Radar"), group:FindFirstChild("Overshield"), group:FindFirstChild("Airstrike")
local function statusOf(chip)
	local best = nil
	for _, l in ipairs(chip:GetDescendants()) do
		if l:IsA("TextLabel") and l.Position.Y.Offset == 19 then
			best = l.Text
		end
	end
	return best
end
check(statusOf(radarChip):match("^ONLINE") ~= nil, "the radar says it is up: " .. statusOf(radarChip))
check(statusOf(shieldChip) == "5 KILLS", "the shield says what it takes: " .. statusOf(shieldChip))
meter:SetOvershield(35, 60)
check(statusOf(shieldChip) == "SHIELD  35", "and what is left once it is on: " .. statusOf(shieldChip))
meter:SetOvershield(0, 60)
check(statusOf(shieldChip):match("BROKEN") ~= nil, "and that it broke")
meter:SetStreak(8)
meter:SetCharges(1)
check(statusOf(strikeChip) == "CALL IN" and strikeChip:FindFirstChild("KeyCap").Visible, "an airstrike shows the key to call it")
meter:SetCharges(0)
check(statusOf(strikeChip) == "NEXT AT 12", "spent, it says when the next one comes")
meter:SetHidden(true)
check(not group.Visible, "hidden in a duel")
screen:Destroy()

-- The world side: its remotes are the server's, above; the client script runs as the player.
World.run(World.service("StarterPlayer"):FindFirstChild("StarterPlayerScripts"):FindFirstChild("Streaks"))
World.advance(0.3)
local fx = World.workspace:FindFirstChild("StreakFX")
check(fx ~= nil, "the client script starts")

-- Radar: a fighter in range is outlined, one out of range is not.
local nearModel = fighter(Vector3.new(30, 3, 0))
local farModel = fighter(Vector3.new(Config.Radar.range + 100, 3, 0))
World.serverFire("Remotes", "StreakEvent", "radar", { duration = 12, range = Config.Radar.range })
World.advance(0.7)

check(nearModel:FindFirstChild("RadarMark") ~= nil, "radar: the fighter in range is outlined")
check(farModel:FindFirstChild("RadarMark") == nil, "the one out of range is not")

-- The warning.
World.serverFire("Remotes", "StreakEvent", "airstrike", {
	at = Vector3.new(0, 0, -60), dir = Vector3.new(0, 0, -1), points = { Vector3.new(0, 0, -70), Vector3.new(0, 0, -50) },
	warning = 2.6, gap = 0.2, radius = 12, altitude = 110, caller = 999, name = "Rival",
	hitAt = os.clock() + 2.6,
})
World.advance(0.2)
local zone, jet = 0, nil
for _, d in ipairs(fx:GetChildren()) do
	if d:IsA("Part") and d.Shape == roblox.Enum.PartType.Cylinder then
		zone += 1
	elseif d.Name == "StrikeJet" then
		jet = d
	end
end
check(zone >= 2, ("the strike zone is drawn (%d marks)"):format(zone))
check(jet ~= nil and #jet:GetChildren() > 15, "and a jet is on its way in")
local label = fx:FindFirstChildWhichIsA("BillboardGui", true)
local text = label and label:FindFirstChildWhichIsA("TextLabel")
check(text and text.Text:match("AIRSTRIKE") and text.Text:match("RIVAL"), "with whose it is: " .. (text and text.Text or "none"))

-- Calling one in: hold the key with a charge, let go -- looking down the street at the ground.
local camera = World.workspace.CurrentCamera
World.force(camera, "CFrame", World.CFrame.lookAt(Vector3.new(0, 14, 12), Vector3.new(0, 0, -40)))
player:SetAttribute("AirstrikeCharges", 1)
table.clear(toServer)
World.holdKey(Config.Airstrike.key, true)
World.advance(0.2)
local aim = fx:FindFirstChild("AirstrikeAim")
World.holdKey(Config.Airstrike.key, false)
World.advance(0.1)
check(aim ~= nil, "holding the key shows the aim mark")
local call = nil
for _, e in ipairs(toServer) do
	if e.name == "StreakAction" and e.args[1] == "airstrike" then
		call = e
	end
end
check(call and typeof(call.args[2]) == "Vector3", "letting go calls it where the crosshair meets the ground")
check(fx:FindFirstChild("AirstrikeAim") == nil, "and the mark goes")
player:SetAttribute("AirstrikeCharges", 0)
table.clear(toServer)
World.holdKey(Config.Airstrike.key, true)
World.advance(0.1)
World.holdKey(Config.Airstrike.key, false)
World.advance(0.1)
check(#toServer == 0, "without a charge the key does nothing")

local bad = {}
for _, r in ipairs(R.errors or {}) do
	if tostring(r):match("Streak") then
		table.insert(bad, tostring(r))
	end
end
check(#bad == 0, "no errors from the streak scripts" .. (#bad > 0 and (": " .. bad[1]) or ""))

print("")
if failures == 0 then
	print("\27[32mall streak checks passed\27[0m")
	require("@lune/process").exit(0)
else
	print(("\27[31m%d streak check(s) failed\27[0m"):format(failures))
	require("@lune/process").exit(1)
end
