--!nocheck
-- The shops' people and a robbery as it looks, checked without Studio on the real Downtown
-- (DistrictService builds it and puts the clerks in; StickupService wires the targets):
--
--   * each shop is its own folder with its own clerk (there used to be only one: both shops
--     shared a folder and the second clerk was never made), its till -- a model with a drawer
--     shut inside its body -- and its cash machine; the clerks stand anchored at the root
--     only, so they can be posed, tagged Staff;
--   * the prompts say what they do: "Rob Register" / "Rob ATM" over the shop's name, "Open
--     Shop" at the counters;
--   * robbing the till at ZEE GUNS: the clerk jolts, a "!" pops up, they turn to the robber
--     and put both hands up and keep them there; the drawer slides out, the screen shows what
--     went, the notes fly out and into the robber's hands, "+$..." floats up; the drawer
--     shuts itself again, and when the time is up the hands come down;
--   * robbing the cash machine at the 24/7: its screen goes red, DISPENSING then OUT OF CASH,
--     and the notes come out of the slot toward the street;
--   * the prompt: the key, the action in big type, what it is on and HOLD underneath, the
--     danger colour for a robbery, the thing outlined while it is up, the text following the
--     prompt when it changes, gone when it hides.
--
--   lune run tools/uitest/staff.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

require("@lune/task").delay(240, function()
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

-- The server's broadcasts reach this client, as they would.
local sent = {}
R.ClassMethods.RemoteEvent.FireAllClients = function(self, ...)
	table.insert(sent, { name = self.Name, args = { ... } })
	R.fire(self, "OnClientEvent", ...)
end
R.ClassMethods.RemoteEvent.FireClient = function(self, _, ...)
	table.insert(sent, { name = self.Name, args = { ... } })
	R.fire(self, "OnClientEvent", ...)
end

local place = World.loadPlace("build/Game.rbxl")
local sss = World.service("ServerScriptService")
local Rig = require("./rig")
Rig.starter(World, place)

local stub = R.new("ModuleScript")
stub.Name = "PlayerDataManager"
stub.Source = [[
local data = { Level = 10, EXP = 0, MaxEXP = 100, Coins = 0, OwnedItems = {}, CompletedQuests = {}, Reputation = {} }
local Replica = { Data = data }
function Replica:SetValue(key, value) data[key] = value end
function Replica:ListenToChange() end
function Replica:IsActive() return true end
local PDM = {}
function PDM:GetPlayerDataReplica()
	return { expect = function() return Replica end, andThen = function(_, fn) pcall(fn, Replica) return { catch = function() end } end }
end
function PDM:SaveNow() return true end
function PDM:IsSaving() return true end
return PDM
]]
stub.Parent = sss
for _, name in ipairs({ "ArenaService", "DistrictService", "NPCService", "WorldBake", "StickupService", "KillCredit",
	"LevelSystem", "ShopService", "ReputationService", "WalletService", "AbilityService", "VFXService", "TowerService" }) do
	R.mirror(place:GetService("ServerScriptService"):FindFirstChild(name), sss)
end
-- The response squad is somebody else's suite: a stand-in that spawns nothing.
sss.NPCService:Destroy()
local npc = R.new("ModuleScript")
npc.Name = "NPCService"
npc.Source = "return { Spawn = function() return nil end, Noise = function() end }"
npc.Parent = sss
local outfit = place:GetService("ServerScriptService"):FindFirstChild("NPCService"):FindFirstChild("Outfit")
R.mirror(outfit, npc)

World.require(sss.DistrictService)
local Stickups = World.require(sss.StickupService)
local downtown = World.workspace:FindFirstChild("Downtown")

-- ------------------------------------------------------------------ the shops --

print("the shops")
local shops = {}
for _, name in ipairs({ "ZEE GUNS", "ZEE TACTICS" }) do
	local shop = downtown and downtown:FindFirstChild(name)
	local clerk = shop and shop:FindFirstChild("Clerk")
	local till = shop and shop:FindFirstChild("Till")
	local machine = shop and shop:FindFirstChild("CashMachine")
	shops[name] = { shop = shop, clerk = clerk, till = till, machine = machine }
	check(shop and shop:IsA("Folder"), name .. ": a folder of its own")
	check(clerk and clerk:IsA("Model") and clerk:HasTag("Staff"), name .. ": its own clerk, tagged Staff")
	if clerk then
		local rootOnly = true
		for _, p in ipairs(clerk:GetDescendants()) do
			if p:IsA("BasePart") and p.Parent == clerk and p.Name ~= "Signpost" then
				rootOnly = rootOnly and (p.Anchored == (p.Name == "HumanoidRootPart"))
			end
		end
		check(rootOnly, name .. ": the clerk is held by the root alone")
	end
	local register = till and till:FindFirstChild("Register")
	local drawer = till and till:FindFirstChild("RegisterDrawer")
	check(register and register:GetAttribute("Stickup") == name and register:GetAttribute("StickupKind") == "register"
		and till.PrimaryPart == register, name .. ": the till is a model round the register")
	if register and drawer then
		-- Shut, everything in the drawer is inside the body but its front.
		local inside = true
		for _, p in ipairs(drawer:GetChildren()) do
			if p:IsA("BasePart") and p.Name ~= "DrawerFront" and p.Name ~= "DrawerHandle" then
				local rel = register.CFrame:PointToObjectSpace(p.Position)
				local half = register.Size / 2
				inside = inside and math.abs(rel.X) < half.X and math.abs(rel.Y) < half.Y and math.abs(rel.Z) < half.Z
			end
		end
		check(drawer:IsA("Model") and drawer:FindFirstChild("DrawerCash") and inside, name .. ": its drawer, with money in, shut inside it")
	end
	check(machine and machine:FindFirstChild("ATM") and machine:FindFirstChild("ATMScreen")
		and machine:FindFirstChild("Sign_WELCOME") and machine:FindFirstChild("ATMCashSlot"),
		name .. ": a cash machine model, its screen saying WELCOME, its cash slot")
	local counter = shop and shop:FindFirstChild(if name == "ZEE GUNS" then "GunCounter" else "TacticsCounter")
	local counterPrompt = counter and counter:FindFirstChildOfClass("ProximityPrompt")
	check(counterPrompt and counterPrompt.ActionText == "Open Shop", name .. ": the counter says Open Shop")
	local robPrompt = register and register:FindFirstChild("StickupPrompt")
	check(robPrompt and robPrompt.ActionText == "Rob Register" and robPrompt.ObjectText == name,
		("%s: the till says %s / %s"):format(name, robPrompt and robPrompt.ActionText or "?", robPrompt and robPrompt.ObjectText or "?"))
end
local corner = nil
for _, d in ipairs(downtown:GetDescendants()) do
	if d.Name == "ATM" and d:GetAttribute("Stickup") == "the 24/7" then
		corner = d
	end
end
local cornerPrompt = corner and corner:FindFirstChild("StickupPrompt")
check(cornerPrompt and cornerPrompt.ActionText == "Rob ATM" and cornerPrompt.ObjectText == "24/7",
	"the 24/7's cash machine says Rob ATM / 24/7")

-- -------------------------------------------------------------- the clients --

local rig = Rig.character(World, place)
local root = rig:FindFirstChild("HumanoidRootPart")
local humanoid = rig:FindFirstChildOfClass("Humanoid")
local guns = shops["ZEE GUNS"]
local register = guns.till.Register
-- Stand at the till, on the customer's side, looking at it.
root.CFrame = CFrame.new(register.Position + Vector3.new(-3.2, -1.2, 0))
World.force(World.workspace.CurrentCamera, "CFrame", CFrame.lookAt(root.Position + Vector3.new(-6, 4, 0), register.Position))
local sps = World.service("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
for _, name in ipairs({ "StaffLife", "Stickups", "PromptUI" }) do
	World.run(sps:FindFirstChild(name))
end
World.advance(0.5)

local function motor(model, part)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part1 and d.Part1.Name == part then
			return d
		end
	end
	return nil
end
local starter = World.service("StarterPlayer"):FindFirstChild("StarterCharacter")
local function rest(part)
	local m = motor(starter, part)
	return m and m.C0
end
-- How far a joint is turned from its rest, in degrees.
local function turned(model, part)
	local m = motor(model, part)
	local r = rest(part)
	if not m or not r then
		return 0
	end
	local _, angle = (r:Inverse() * m.C0):ToAxisAngle()
	return math.deg(math.abs(angle))
end

print("at rest")
local clerk = guns.clerk
check(turned(clerk, "RightUpperArm") > 100, ("the clerk waves the first time you come close (shoulder %.0f°)"):format(
	turned(clerk, "RightUpperArm")))
World.advance(1.6)
check(turned(clerk, "RightUpperArm") < 40 and turned(clerk, "RightLowerArm") > 60 and turned(clerk, "UpperTorso") < 6,
	("then stands easy, arms folded (shoulder %.0f°, elbow %.0f°)"):format(turned(clerk, "RightUpperArm"),
		turned(clerk, "RightLowerArm")))
check(turned(clerk, "Head") > 3, ("and looks at you, close by (neck %.0f°)"):format(turned(clerk, "Head")))

-- ------------------------------------------------------------------ the till --

print("robbing the till at ZEE GUNS")
local drawer = guns.till.RegisterDrawer
local shut = drawer:GetPivot()
check(Stickups.Rob(World.player, register) == true, "the job starts")
local alarm = nil
for _, e in ipairs(sent) do
	if e.name == "StickupEvent" and e.args[1] == "alarm" then
		alarm = e.args[2]
	end
end
check(alarm and alarm.part == register and alarm.kind == "register", "the alarm carries the till, so clients can open it")
check(type(clerk:GetAttribute("HandsUpAt")) == "number" and clerk:GetAttribute("HandsUpFor") == Stickups.HANDS_UP
	and clerk:GetAttribute("RobberId") == World.player.UserId, "the clerk is told: hands up, for how long, for whom")
World.advance(0.6)
local head = clerk:FindFirstChild("Head")
check(head and head:FindFirstChild("Startled"), "a \"!\" pops up over the clerk")
check(turned(clerk, "RightUpperArm") > 60 and turned(clerk, "LeftUpperArm") > 60 and turned(clerk, "RightLowerArm") > 60,
	("both hands go up (shoulders %.0f° / %.0f°, elbow %.0f°)"):format(turned(clerk, "RightUpperArm"),
		turned(clerk, "LeftUpperArm"), turned(clerk, "RightLowerArm")))
-- Facing the robber: the root joint turned toward where you stand.
local rootMotor = motor(clerk, "LowerTorso")
local clerkRoot = clerk:FindFirstChild("HumanoidRootPart")
local toRobber = clerkRoot.CFrame:PointToObjectSpace(root.Position)
local wantYaw = math.atan2(-toRobber.X, -toRobber.Z)
local _, yaw = (rest("LowerTorso"):Inverse() * rootMotor.C0):ToEulerAnglesYXZ()
check(math.abs(yaw - wantYaw) < math.rad(25), ("and turns to face you (%.0f° of %.0f°)"):format(math.deg(yaw), math.deg(wantYaw)))

local out = -register.CFrame.RightVector
local moved = (drawer:GetPivot().Position - shut.Position):Dot(out)
check(moved > 0.8, ("the drawer slides out toward you (%.2f studs)"):format(moved))
local cash, popped, screen = 0, nil, nil
for _, d in ipairs(World.workspace:GetChildren()) do
	if d.Name == "StickupCash" and d.Transparency < 1 then
		cash += 1
	elseif d.Name == "StickupAmount" then
		local label = d:FindFirstChildWhichIsA("TextLabel", true)
		popped = label and label.Text
	end
end
local sign = guns.till:FindFirstChild("Sign_$0.00")
screen = sign and sign:FindFirstChildWhichIsA("TextLabel", true)
check(cash >= 6, ("the notes are in the air (%d)"):format(cash))
check(popped == ("+$%d"):format(alarm.amount), "the take floats up: " .. tostring(popped))
check(screen and screen.Text == ("-$%d.00"):format(alarm.amount), "the till's screen shows it: " .. tostring(screen and screen.Text))
-- Where the notes are, a moment later: up out of the drawer, and then into your hands.
local highest = -math.huge
for _ = 1, 6 do
	World.advance(0.05)
	for _, d in ipairs(World.workspace:GetChildren()) do
		if d.Name == "StickupCash" then
			highest = math.max(highest, d.Position.Y - register.Position.Y)
		end
	end
end
check(highest > 1, ("thrown up out of the drawer (%.1f studs up)"):format(highest))
World.advance(1.6)
local left = 0
for _, d in ipairs(World.workspace:GetChildren()) do
	if d.Name == "StickupCash" then
		left += 1
	end
end
check(left == 0, ("and every note ends up with you (%d left)"):format(left))
World.advance(5.5)
check((drawer:GetPivot().Position - shut.Position).Magnitude < 0.05, "the drawer shuts itself again")
check(screen and screen.Text == "$0.00", "and the screen clears")
check(turned(clerk, "RightUpperArm") > 60, "the hands are still up while the time lasts")
clerk:SetAttribute("HandsUpAt", World.workspace:GetServerTimeNow() - Stickups.HANDS_UP - 1)
World.advance(2.5)
check(turned(clerk, "RightUpperArm") < 40, ("and come down when it is up (shoulder %.0f°)"):format(turned(clerk, "RightUpperArm")))

-- End the job (busted) so the next can start.
humanoid.Health = 0
R.fire(humanoid, "Died")
World.advance(0.2)
humanoid.Health = 100

-- -------------------------------------------------------------- the machine --

print("robbing the cash machine at the 24/7")
local machine = corner.Parent
local atmScreen = machine:FindFirstChild("ATMScreen")
local was = atmScreen.Color
local face = -corner.CFrame.RightVector
root.CFrame = CFrame.new(corner.Position + face * 2.5)
World.force(World.workspace.CurrentCamera, "CFrame", CFrame.lookAt(root.Position + face * 6 + Vector3.new(0, 3, 0), corner.Position))
check(Stickups.Rob(World.player, corner) == true, "the job starts")
World.advance(0.15)
local label = machine:FindFirstChild("Sign_WELCOME"):FindFirstChildWhichIsA("TextLabel", true)
check(atmScreen.Color ~= was and atmScreen.Color.R > atmScreen.Color.G, "its screen goes red")
check(label.Text == "DISPENSING", "and says DISPENSING")
World.advance(0.45)
local slot = machine:FindFirstChild("ATMCashSlot").Position
local outward, notes = 0, 0
for _, d in ipairs(World.workspace:GetChildren()) do
	if d.Name == "StickupCash" and d.Transparency < 1 then
		notes += 1
		outward += (d.Position - slot):Dot(face)
	end
end
check(notes >= 3 and outward / math.max(notes, 1) > 0.3,
	("the notes come out of the slot toward the street (%d, %.1f studs out)"):format(notes, outward / math.max(notes, 1)))
World.advance(1.4)
check(label.Text == "OUT OF CASH", "then it reads OUT OF CASH")

-- ---------------------------------------------------------------- the prompt --

print("the prompt")
local pps = World.service("ProximityPromptService")
-- Back in the shops, at the other till (this one has not been robbed).
local tactics = shops["ZEE TACTICS"]
register = tactics.till.Register
root.CFrame = CFrame.new(register.Position + Vector3.new(-3.2, -1.2, 0))
World.force(World.workspace.CurrentCamera, "CFrame", CFrame.lookAt(root.Position + Vector3.new(-6, 4, 0), register.Position))
local tillPrompt = register:FindFirstChild("StickupPrompt")
R.fire(pps, "PromptShown", tillPrompt)
World.advance(0.4)
local gui = register:FindFirstChild("PromptUI")
local function text(name)
	local l = gui and gui:FindFirstChild(name, true)
	return l and l.Text
end
check(gui and text("Key") == "E", "a key cap with E on it")
check(text("Action") == "Rob Register" and text("Object") == "ZEE TACTICS  ·  HOLD",
	("the action, and what it is on: %s / %s"):format(tostring(text("Action")), tostring(text("Object"))))
local Theme = World.require(World.service("ReplicatedStorage"):FindFirstChild("UIKit")).Theme
local edge = gui and gui:FindFirstChild("Edge", true)
check(edge and edge.BackgroundColor3 == Theme.Danger, "a robbery wears the danger colour")
local focus = World.workspace.CurrentCamera:FindFirstChild("PromptFocus")
check(focus and focus.Enabled and focus.Adornee == tactics.till, "the till is outlined while the prompt is up")
local holder = gui and gui:FindFirstChild("Holder")
local scale = holder and holder:FindFirstChildOfClass("UIScale")
check(scale and math.abs(scale.Scale - 1) < 0.02 and holder.Position.Y.Offset == 0, "grown and risen into place")
tillPrompt.ActionText = "Emptied"
World.advance(0.05)
check(text("Action") == "Emptied", "the text follows the prompt")
R.fire(pps, "PromptButtonHoldBegan", tillPrompt)
World.advance(tillPrompt.HoldDuration + 0.2)
local fill = gui:FindFirstChild("Fill", true)
local bar = gui:FindFirstChild("Bar", true)
check(fill and fill.Size.Y.Scale == 1 and bar.Size.X.Scale == 1, "holding fills the key and the bar")
R.fire(pps, "PromptButtonHoldEnded", tillPrompt)
World.advance(0.2)
check(fill.Size.Y.Scale == 0 and bar.Size.X.Scale == 0, "and letting go empties them")
R.fire(pps, "PromptHidden", tillPrompt)
World.advance(0.4)
check(register:FindFirstChild("PromptUI") == nil and not focus.Enabled, "hidden: gone, and the outline with it")
local counterPrompt = tactics.shop:FindFirstChild("TacticsCounter"):FindFirstChildOfClass("ProximityPrompt")
clerk = tactics.clerk
R.fire(pps, "PromptShown", counterPrompt)
World.advance(0.3)
local counterGui = counterPrompt.Parent:FindFirstChild("PromptUI")
local counterEdge = counterGui and counterGui:FindFirstChild("Edge", true)
local counterAction = counterGui and counterGui:FindFirstChild("Action", true)
check(counterAction and counterAction.Text == "Open Shop" and counterEdge.BackgroundColor3 == Theme.Accent,
	"the counter: Open Shop, in the accent colour")
-- Talking to the clerk: they turn to you and talk with their hands.
-- (Folded arms keep the upper arm near the body; making a point lifts it well forward.)
local before = turned(clerk, "RightUpperArm")
R.fire(pps, "PromptTriggered", counterPrompt, World.player)
World.advance(0.5)
local most = 0
for _ = 1, 12 do
	World.advance(0.1)
	most = math.max(most, turned(clerk, "RightUpperArm"))
end
check(most - before > 15,
	("open the shop and the clerk talks with their hands (shoulder %.0f° -> up to %.0f°)"):format(before, most))

print("")
local errors = R.errors or {}
for _, e in ipairs(errors) do
	print("    error: " .. tostring(e):sub(1, 300))
end
check(#errors == 0, "no script errors")
if failures == 0 then
	print("\27[32mall staff checks passed\27[0m")
	require("@lune/process").exit(0)
else
	print(("\27[31m%d staff check(s) failed\27[0m"):format(failures))
	require("@lune/process").exit(1)
end
