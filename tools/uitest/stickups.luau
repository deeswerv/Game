--!nocheck
-- Stick-ups (Downtown's tills and cash machines, StickupService, the HUD), checked without
-- Studio:
--
--   * Downtown has five things to rob -- the tills at ZEE GUNS and ZEE TACTICS, a cash
--     machine inside each and one outside the 24/7 -- each with a hold-E prompt, room to
--     stand at it, and nothing built through it;
--   * robbing one: the bag and the heat go on you, everyone is told where and how much, a
--     squad of three comes up the avenue and is steered onto you; the target is empty for a
--     while, and you cannot start another job while you hold a bag;
--   * hold it for the heat's length: the bag is yours (cash and XP), and the heat is off;
--   * die with it: a player who put you down takes it, otherwise it is gone; the squad goes
--     home afterwards;
--   * the HUD: your bar counts the heat down; a gold tag goes over anyone else with a bag.
--
-- NPCService is stood in for (it records spawns and noise); clocks are wound by hand.
--
--   lune run tools/uitest/stickups.luau

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

local sent = {}
R.ClassMethods.RemoteEvent.FireClient = function(self, target, ...)
	table.insert(sent, { name = self.Name, to = target, args = { ... } })
end
R.ClassMethods.RemoteEvent.FireAllClients = function(self, ...)
	table.insert(sent, { name = self.Name, all = true, args = { ... } })
end
local function events(kind)
	local out = {}
	for _, e in ipairs(sent) do
		if e.name == "StickupEvent" and e.args[1] == kind then
			table.insert(out, e)
		end
	end
	return out
end

local place = World.loadPlace("build/Game.rbxl")
local rs = World.service("ReplicatedStorage")
local sss = World.service("ServerScriptService")
local player = World.player

-- ------------------------------------------------------------------- the city --

R.mirror(place:GetService("ServerScriptService"):FindFirstChild("ArenaService"), sss)
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("DistrictService"), sss)
local Downtown = World.require(sss.DistrictService.Downtown)
local centre = Vector3.new(-155, 1000, 1500)
local folder = R.new("Folder")
folder.Name = "Downtown"
folder.Parent = World.workspace
Downtown.Build(folder, centre)

local solids = {}
for _, d in ipairs(folder:GetDescendants()) do
	if d:IsA("BasePart") and d.CanCollide and d.Transparency < 1 then
		table.insert(solids, d)
	end
end
local function inside(part, p, margin)
	local rel = part.CFrame:PointToObjectSpace(p)
	local s = part.Size / 2
	local m = margin or 0.05
	return math.abs(rel.X) < s.X - m and math.abs(rel.Y) < s.Y - m and math.abs(rel.Z) < s.Z - m
end
local function blockedAt(p, except)
	for _, s in ipairs(solids) do
		if s ~= except and inside(s, p) then
			return s.Name
		end
	end
	return nil
end

-- ------------------------------------------------------------------- services --

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
local npc = R.new("ModuleScript")
npc.Name = "NPCService"
npc.Source = [[
local NPCService = { spawned = {}, noise = {} }
function NPCService.Spawn(archetype, position, options)
	local model = Instance.new("Model")
	model.Name = archetype
	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.CFrame = CFrame.new(position)
	root.Parent = model
	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = 200
	humanoid.Health = 200
	humanoid.Parent = model
	for key, value in pairs(options and options.attributes or {}) do
		model:SetAttribute(key, value)
	end
	model.Parent = workspace
	table.insert(NPCService.spawned, { archetype = archetype, position = position, options = options, model = model })
	return model
end
function NPCService.Noise(position, radius, source)
	table.insert(NPCService.noise, { position = position, radius = radius, source = source })
end
return NPCService
]]
npc.Parent = sss
local NPCService = World.require(npc)
for _, name in ipairs({ "KillCredit", "ShopService", "ReputationService", "LevelSystem", "WalletService",
	"AbilityService", "VFXService", "StickupService" }) do
	R.mirror(place:GetService("ServerScriptService"):FindFirstChild(name), sss)
end
local Rig = require("./rig")
local rig = Rig.character(World, place)
local humanoid = rig:FindFirstChildOfClass("Humanoid")
local root = rig:FindFirstChild("HumanoidRootPart")
local KillCredit = World.require(sss.KillCredit)
local Stickups = World.require(sss.StickupService)
local now = 0
Stickups.Clock = function()
	return now
end
Stickups.Random = function(lo, hi)
	return math.floor((lo + hi) / 2)
end
Stickups.CALL_EVERY = 0.05
Stickups.DISPERSE = 0.1
local coins = player:FindFirstChild("leaderstats"):FindFirstChild("Coins")

-- --------------------------------------------------------------- the targets --

print("what there is to rob")
-- The service wired the district the moment it started (it was already standing).
check(Stickups.Wire(folder) == 0, "wiring the same district again adds nothing")
local wired = #Stickups.Targets()
local tills, atms = {}, {}
for _, t in ipairs(Stickups.Targets()) do
	if t.kind == "atm" then
		atms[t.name] = t
	else
		tills[t.name] = t
	end
end
check(wired == 5, ("five targets (%d)"):format(wired))
check(tills["ZEE GUNS"] and tills["ZEE TACTICS"], "the tills at ZEE GUNS and ZEE TACTICS")
check(atms["ZEE GUNS"] and atms["ZEE TACTICS"] and atms["the 24/7"], "cash machines inside both, and outside the 24/7")
for _, t in ipairs(Stickups.Targets()) do
	local prompt = t.part:FindFirstChild("StickupPrompt")
	check(prompt and prompt.HoldDuration == Stickups.Kinds[t.kind].hold and prompt.ActionText:match("^Rob"),
		("%s %s: a hold-E prompt (%s, %.0fs)"):format(t.name, t.kind, prompt and prompt.ActionText or "none",
			prompt and prompt.HoldDuration or 0))
	if t.kind == "atm" then
		-- The machine's face is its -X; where you stand to use it is in front of that.
		local face = -t.part.CFrame.RightVector
		local standAt = t.part.Position + face * 2.2 + Vector3.new(0, 0.3, 0)
		local wallBehind = blockedAt(t.part.Position - face * 0.8, t.part)
		check(blockedAt(standAt, t.part) == nil and wallBehind ~= nil,
			("%s ATM: set in a wall (%s), room to stand at it"):format(t.name, tostring(wallBehind)))
		check(blockedAt(t.part.Position + face * 0.2, t.part) == nil, t.name .. " ATM: nothing built through its face")
	end
end

-- ------------------------------------------------------------------- the job --

print("robbing the till at ZEE GUNS")
local till = tills["ZEE GUNS"]
root.CFrame = CFrame.new(till.part.Position + Vector3.new(-3.5, -1.5, 0))
local before = coins.Value
local ok = Stickups.Rob(player, till.part)
local loot = player:GetAttribute("Bag")
local range = Stickups.Kinds.register.loot
check(ok == true and loot and loot >= range[1] and loot <= range[2], ("the bag: $%s"):format(tostring(loot)))
check(type(player:GetAttribute("Heat")) == "number" and player:GetAttribute("HeatPlace") == "ZEE GUNS",
	"the heat is on you, and where from")
local alarm = events("alarm")[1]
check(alarm and alarm.all and alarm.args[2].amount == loot and alarm.args[2].place == "ZEE GUNS"
	and alarm.args[2].seconds == Stickups.Kinds.register.heat, "everyone hears the alarm: where, how much, how long")
check(#NPCService.spawned == 3, ("a squad of three comes (%d)"):format(#NPCService.spawned))
local onAvenue = true
for _, s in ipairs(NPCService.spawned) do
	onAvenue = onAvenue and math.abs(s.position.X - centre.X) <= 6 and math.abs(s.position.Z - till.part.Position.Z) >= 40
		and s.options.respawn == false and s.model:GetAttribute("StickupSquad") == player.UserId
end
check(onAvenue, "up and down the avenue, not out of a wall, and they do not come back")
World.advance(0.2)
local steered = NPCService.noise[#NPCService.noise]
check(steered and (steered.position - root.Position).Magnitude < 0.01 and steered.source == rig, "and they are pointed at you")

check(till.prompt.ActionText == "Emptied" and till.prompt.HoldDuration == 0, "the till reads empty")
table.clear(sent)
check(Stickups.Rob(player, till.part) == false and #events("refused") == 1, "and robbing it again is refused, with why")
table.clear(sent)
root.CFrame = CFrame.new(atms["ZEE GUNS"].part.Position)
local busy, why = Stickups.Rob(player, atms["ZEE GUNS"].part)
check(busy == false and why == "busy", "one bag at a time")

print("the getaway")
now += Stickups.Kinds.register.heat - 1
World.advance(0.2)
check(player:GetAttribute("Bag") == loot and coins.Value == before, "a second short: still yours to lose")
now += 2
World.advance(0.2)
check(coins.Value == before + loot, ("held it: +$%d"):format(coins.Value - before))
check(player:GetAttribute("Bag") == nil and player:GetAttribute("Heat") == nil, "the heat is off")
local away = events("getaway")[1]
check(away and away.all and away.args[2].amount == loot, "and everyone hears you got away")
World.advance(0.3)
local gone = 0
for _, s in ipairs(NPCService.spawned) do
	if s.model.Parent == nil then
		gone += 1
	end
end
check(gone == 3, "the squad goes home")

print("losing it")
table.clear(sent)
table.clear(NPCService.spawned)
local atm = atms["the 24/7"]
root.CFrame = CFrame.new(atm.part.Position - atm.part.CFrame.RightVector * 2)
humanoid.Health = 100
ok = Stickups.Rob(player, atm.part)
local bag = player:GetAttribute("Bag")
local atmRange = Stickups.Kinds.atm.loot
check(ok == true and bag >= atmRange[1] and bag <= atmRange[2], ("the ATM: a bigger bag ($%s)"):format(tostring(bag)))
-- Another player puts the robber down.
local rival = R.new("Player")
rival.Name = "Rival"
World.force(rival, "UserId", 777)
World.force(rival, "DisplayName", "Rival")
local stats = R.new("Folder")
stats.Name = "leaderstats"
stats.Parent = rival
local rivalCoins = R.new("IntValue")
rivalCoins.Name = "Coins"
rivalCoins.Parent = stats
rival.Parent = World.service("Players")
local coinsBefore = coins.Value
KillCredit.Tag(humanoid, rival)
humanoid.Health = 0
R.fire(humanoid, "Died")
World.advance(0.2)
check(rivalCoins.Value == bag and coins.Value == coinsBefore, ("the one who put you down takes the bag (+$%d to them)"):format(rivalCoins.Value))
local stolen = events("stolen")[1]
check(stolen and stolen.args[2].killer == "Rival" and stolen.args[2].amount == bag, "and everyone is told who has it now")
check(player:GetAttribute("Bag") == nil and Stickups.JobOf(player) == nil, "the job is over")

print("busted")
table.clear(sent)
humanoid.Health = 100
local tactics = tills["ZEE TACTICS"]
root.CFrame = CFrame.new(tactics.part.Position + Vector3.new(-3.5, -1.5, 0))
check(Stickups.Rob(player, tactics.part) == true, "another job")
humanoid:FindFirstChild("creator"):Destroy()
coinsBefore = coins.Value
humanoid.Health = 0
R.fire(humanoid, "Died")
World.advance(0.2)
check(#events("busted") == 1 and coins.Value == coinsBefore and player:GetAttribute("Bag") == nil,
	"killed by the squad (no player): busted, the bag is lost")

print("restocked")
now += Stickups.COOLDOWN + 1
Stickups.Refresh()
check(Stickups.Rob ~= nil and till.prompt.ActionText == "Rob the till", "the till fills up again: " .. till.prompt.ActionText)

-- ----------------------------------------------------------------------- HUD --

print("the HUD")
local screen = R.new("ScreenGui")
screen.Parent = World.service("Players").LocalPlayer:FindFirstChild("PlayerGui")
local toasts = {}
local toast = {
	Push = function(_, o)
		table.insert(toasts, { kind = "push", title = o.title, text = o.text })
	end,
	Banner = function(_, o)
		table.insert(toasts, { kind = "banner", title = o.title, text = o.subtitle })
	end,
}
local Hud = World.require(rs.UI.Modules.Stickups)
local hud = Hud.new(screen, World.service("Players").LocalPlayer:FindFirstChild("PlayerGui"), toast)
local bar = screen:FindFirstChild("HeatBar")
World.advance(0.1)
check(bar and not bar.Visible, "no bag, no bar")
humanoid.Health = 100
player:SetAttribute("Bag", 620)
player:SetAttribute("Heat", World.workspace:GetServerTimeNow() + 45)
player:SetAttribute("HeatPlace", "ZEE GUNS")
hud:Handle("alarm", { robberId = player.UserId, amount = 620, seconds = 60, place = "ZEE GUNS" })
World.advance(0.1)
local timer = nil
for _, l in ipairs(bar:GetDescendants()) do
	if l:IsA("TextLabel") and l.Text:match("^%d:%d%d$") then
		timer = l.Text
	end
end
check(bar.Visible and timer == "0:45", "your bar counts the heat down: " .. tostring(timer))
check(toasts[#toasts].kind == "banner" and toasts[#toasts].title == "STICK-UP", "and the job is called on your screen")
hud:Handle("alarm", { robberId = 777, robber = "Rival", amount = 900, seconds = 75, place = "the ATM at ZEE GUNS" })
check(toasts[#toasts].kind == "push" and toasts[#toasts].title:match("ROBBERY"), "someone else's: a card with where and how much")
-- A tag over the other robber.
local rivalChar = R.new("Model")
rivalChar.Name = "Rival"
local head = R.new("Part")
head.Name = "Head"
head.Parent = rivalChar
rivalChar.Parent = World.workspace
World.force(rival, "Character", rivalChar)
rival:SetAttribute("Bag", 900)
World.advance(0.1)
local tag = nil
for _, g in ipairs(World.service("Players").LocalPlayer:FindFirstChild("PlayerGui"):GetChildren()) do
	if g.Name == "BagTag" then
		tag = g
	end
end
check(tag and tag.Adornee == head and tag.AlwaysOnTop, "a gold tag over anyone else holding a bag, through walls")
rival:SetAttribute("Bag", nil)
World.advance(0.1)
check(tag and tag.Parent == nil, "gone when they lose it")
player:SetAttribute("Bag", nil)
World.advance(0.1)
check(not bar.Visible, "and your bar goes when the heat does")

print("")
if failures == 0 then
	print("\27[32mall stick-up checks passed\27[0m")
	require("@lune/process").exit(0)
else
	print(("\27[31m%d stick-up check(s) failed\27[0m"):format(failures))
	require("@lune/process").exit(1)
end
