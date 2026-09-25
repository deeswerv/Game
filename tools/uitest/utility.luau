--!nocheck
-- The utility kit (UtilityConfig, UtilityService, SmokeField, the Utility client), checked
-- without Studio:
--
--   * what each level carries; flight paths that land on floors and glance off walls;
--   * frags: damage falls off, a wall takes most of it, the thrower takes half, armour
--     plates soak hits first, and nothing lands through a duel's countdown shield;
--   * throws are counted and spaced; medkits heal after their channel; plates are picked up;
--   * smoke hides you from enemies; a flash stops them seeing;
--   * the tray shows the kit, X switches, holding F draws the arc and letting go throws,
--     a flash whites out the screen you were looking with, smoke stands, a medkit shows its bar.
--
-- The world is a flat floor at y = 0, plus a wall where a check needs one.
--
--   lune run tools/uitest/utility.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local Rig = require("./rig")
local R = World.R
local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local Enum = roblox.Enum

-- UtilityService keeps a plate-collecting loop running, so an error part way through would
-- otherwise leave this hanging instead of failing.
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

-- ------------------------------------------------------------ the world --

local wall = nil -- { min = Vector3, max = Vector3 }
local function slab(o, d, lo, hi)
	if math.abs(d) < 1e-9 then
		return (o >= lo and o <= hi) and -math.huge or math.huge, (o >= lo and o <= hi) and math.huge or -math.huge
	end
	local a, b = (lo - o) / d, (hi - o) / d
	return math.min(a, b), math.max(a, b)
end
local function worldCast(origin, direction)
	local best, bestT, normal = nil, math.huge, nil
	if wall then
		local x0, x1 = slab(origin.X, direction.X, wall.min.X, wall.max.X)
		local y0, y1 = slab(origin.Y, direction.Y, wall.min.Y, wall.max.Y)
		local z0, z1 = slab(origin.Z, direction.Z, wall.min.Z, wall.max.Z)
		local enter, leave = math.max(x0, y0, z0), math.min(x1, y1, z1)
		if enter <= leave and enter >= 0 and enter <= 1 then
			-- Which face: the axis that entered last.
			local n = Vector3.new(0, 0, direction.Z > 0 and -1 or 1)
			if enter == x0 then
				n = Vector3.new(direction.X > 0 and -1 or 1, 0, 0)
			elseif enter == y0 then
				n = Vector3.new(0, direction.Y > 0 and -1 or 1, 0)
			end
			bestT, best, normal = enter, "Wall", n
		end
	end
	if direction.Y < 0 and origin.Y >= 0 then
		local t = -origin.Y / direction.Y
		if t <= 1 and t < bestT then
			bestT, best, normal = t, "Floor", Vector3.new(0, 1, 0)
		end
	end
	if not best then
		return nil
	end
	return { Position = origin + direction * bestT, Normal = normal, Instance = { Name = best }, Distance = bestT }
end
R.ClassMethods.Workspace.Raycast = function(_self, origin, direction)
	return worldCast(origin, direction)
end

local toClients, toServer = {}, {}
R.ClassMethods.RemoteEvent.FireClient = function(self, _player, ...)
	table.insert(toClients, { name = self.Name, args = { ... } })
end
R.ClassMethods.RemoteEvent.FireAllClients = function(self, ...)
	table.insert(toClients, { name = self.Name, args = { ... } })
end
R.ClassMethods.RemoteEvent.FireServer = function(self, ...)
	table.insert(toServer, { name = self.Name, args = { ... } })
end
local function sentTo(kind)
	local out = {}
	for _, e in ipairs(toClients) do
		if e.name == "UtilityEvent" and e.args[1] == kind then
			table.insert(out, e.args)
		end
	end
	return out
end

local place = World.loadPlace("build/Game.rbxl")
local rs = World.service("ReplicatedStorage")
local sss = World.service("ServerScriptService")
local Config = World.require(rs.UtilityConfig)
local player = World.player

-- --------------------------------------------------------------- config --

print("the kit")
local k1, k3, k7 = Config.KitFor(1), Config.KitFor(3), Config.KitFor(7)
check(k1.Smoke == 1 and k1.Medkit == 2 and k1.Frag == 0 and k1.Flash == 0, "level 1: a smoke and two medkits")
check(k3.Frag == 2 and k3.Flash == 0, "level 3 adds two frags")
check(k7.Flash == 2, "level 7 adds two flashbangs")

print("flight")
local function cast(a, d)
	return worldCast(a, d)
end
local open = Config.Trajectory(Vector3.new(0, 5, 0), Config.LaunchVelocity(Vector3.new(0, 0.2, -1).Unit), cast)
check(open.landed and math.abs(open.rest.Y - 0.35) < 0.05, ("an open throw lands on the floor (%.2f)"):format(open.rest.Y))
local range = (open.rest - Vector3.new(0, 5, 0)).Magnitude
check(range > 35 and range < 110, ("about a street away (%.0f studs)"):format(range))
local increasing, above = true, true
for i = 2, #open.times do
	if open.times[i] < open.times[i - 1] then
		increasing = false
	end
	if open.points[i].Y < 0 then
		above = false
	end
end
check(increasing and above, "time only runs forward, and it never goes through the floor")
wall = { min = Vector3.new(-10, 0, -22), max = Vector3.new(10, 30, -20) }
local banked = Config.Trajectory(Vector3.new(0, 5, 0), Config.LaunchVelocity(Vector3.new(0, 0.1, -1).Unit), cast)
check(banked.landed and banked.rest.Z > -20 and banked.rest.Z < 0,
	("into a wall it glances back and drops on this side (z %.1f)"):format(banked.rest.Z))
wall = nil
local up = Config.Trajectory(Vector3.new(0, 5, 0), Config.LaunchVelocity(Vector3.new(0, 1, 0)), cast)
check(up.landed and (up.rest - Vector3.new(0, 0.35, 0)).Magnitude < 1, "straight up comes straight down")
local mid = Config.PositionAt(open, open.restAt / 2)
check(mid.Y > 5, "half way through the flight it is up in the air")

print("falloff")
check(Config.FragShare(0) == 1 and Config.FragShare(8) < 1 and Config.FragShare(8) > Config.FragShare(14)
	and Config.FragShare(17) == 0, "a frag hits hardest in the middle, nothing past its radius")
check(Config.BlindFor(10, 1) > Config.BlindFor(10, -1) and Config.BlindFor(10, 1) > Config.BlindFor(40, 1)
	and Config.BlindFor(60, 1) == 0, "a flash blinds most up close and looking at it")
check(Config.SegmentHitsSphere(Vector3.new(-10, 3, 0), Vector3.new(10, 3, 0), Vector3.new(0, 3, 0), 4)
	and not Config.SegmentHitsSphere(Vector3.new(-10, 3, 10), Vector3.new(10, 3, 10), Vector3.new(0, 3, 0), 4),
	"a sight line through a cloud is caught; one beside it is not")

-- --------------------------------------------------------------- server --

for _, name in ipairs({ "KillCredit", "SmokeField", "UtilityService", "NPCService", "WeaponPose" }) do
	R.mirror(place:GetService("ServerScriptService"):FindFirstChild(name), sss)
end
local rig, rests = Rig.character(World, place)
local humanoid = rig:FindFirstChildOfClass("Humanoid")
local root = rig:FindFirstChild("HumanoidRootPart")
root.CFrame = CFrame.new(0, 3, 0)
player:SetAttribute("Level", 10)
local Utility = World.require(sss.UtilityService)
local KillCredit = World.require(sss.KillCredit)
local SmokeField = World.require(sss.SmokeField)
World.advance(0.2)

print("server: kit and throws")
Utility.Refill(player)
local kit = Utility.Kit(player)
check(kit.Frag == 2 and kit.Flash == 2 and kit.Smoke == 1 and kit.Medkit == 2, "level 10 carries the full kit")
check(rig:GetAttribute("MaxArmour") == 75 and rig:GetAttribute("Armour") == 0, "armour bar up, empty out in the world")
table.clear(toClients)
check(Utility.Throw(player, "Frag", Vector3.new(0, 4.5, 0), Vector3.new(0, 0.2, -1)) == true, "a frag goes")
local thrown = sentTo("thrown")[1]
check(thrown and thrown[2].kind == "Frag" and #thrown[2].points > 5 and thrown[2].fuse > 2,
	"everyone is sent its path and fuse")
check(kit.Frag == 1, "and it is counted")
check(Utility.Throw(player, "Frag", Vector3.new(0, 4.5, 0), Vector3.new(0, 0, -1)) == false, "not again straight away")
check(Utility.Throw(player, "Nuke", Vector3.new(0, 4.5, 0), Vector3.new(0, 0, -1)) == false, "an unknown kind is refused")
World.advance(0.9)
check(Utility.Throw(player, "Frag", Vector3.new(500, 4.5, 0), Vector3.new(0, 0.2, -1)) == true,
	"a claimed hand far from the head is ignored, not refused")
World.advance(0.9)
check(Utility.Throw(player, "Frag", Vector3.new(0, 4.5, 0), Vector3.new(0, 0, -1)) == false, "none left")

print("server: frags and armour")
local npcs = World.workspace:FindFirstChild("NPCs") or R.new("Folder")
npcs.Name = "NPCs"
npcs.Parent = World.workspace
local function dummy(name, at)
	local model = R.new("Model")
	model.Name = name
	local r = R.new("Part")
	r.Name = "HumanoidRootPart"
	r.Size = Vector3.new(2, 2, 1)
	r.CFrame = CFrame.new(at)
	World.force(r, "AssemblyLinearVelocity", Vector3.new(0, 0, 0))
	r.Parent = model
	local h = R.new("Humanoid")
	h.MaxHealth = 200
	h.Health = 200
	h.Parent = model
	model.PrimaryPart = r
	model.Parent = npcs
	return model, h
end
local near, nearH = dummy("Near", Vector3.new(0, 3, -44))
local far, farH = dummy("Far", Vector3.new(0, 3, -54))
local hidden, hiddenH = dummy("Hidden", Vector3.new(6, 3, -40))
wall = { min = Vector3.new(3, 0, -45), max = Vector3.new(4, 30, -35) }
root.CFrame = CFrame.new(0, 3, 400)
Utility.Frag(player, Vector3.new(0, 1, -40))
local nearLost, farLost, hiddenLost = 200 - nearH.Health, 200 - farH.Health, 200 - hiddenH.Health
check(nearLost > 60, ("4 studs away takes most of it (%.0f)"):format(nearLost))
check(farLost > 0 and farLost < nearLost, ("14 away takes less (%.0f)"):format(farLost))
check(hiddenLost > 0 and hiddenLost < nearLost * 0.35, ("behind a wall, a fraction (%.0f)"):format(hiddenLost))
wall = nil
check(#sentTo("explode") >= 1, "and everyone is told to draw the blast")

root.CFrame = CFrame.new(0, 3, -38)
humanoid.Health = 100
rig:SetAttribute("Armour", 25)
Utility.Frag(player, Vector3.new(0, 1, -40))
local armourLeft = rig:GetAttribute("Armour")
check(armourLeft == 0 and humanoid.Health < 100 and humanoid.Health > 30,
	("your own frag: half damage, the plates soak it first (hp %.0f, armour %s)"):format(humanoid.Health, tostring(armourLeft)))
humanoid.Health = 100
rig:SetAttribute("Armour", 50)
KillCredit.Damage(humanoid, 30, nil, "Test")
check(rig:GetAttribute("Armour") == 20 and humanoid.Health == 100, "a hit smaller than the armour takes only armour")
KillCredit.Damage(humanoid, 30, nil, "Test")
check(rig:GetAttribute("Armour") == 0 and humanoid.Health == 90, "a bigger one runs through the last of it into health")
check(KillCredit.Mitigate(humanoid, 40) == 40, "and the preview agrees once it is gone")
local shield = R.new("ForceField")
shield.Parent = rig
rig:SetAttribute("Armour", 50)
KillCredit.Damage(humanoid, 30, nil, "Test")
check(rig:GetAttribute("Armour") == 50 and humanoid.Health == 90 and KillCredit.Mitigate(humanoid, 30) == 0,
	"a duel countdown's shield keeps armour and health both")
shield:Destroy()
rig:SetAttribute("Armour", 0)

print("server: medkits and plates")
humanoid.Health = 40
check(Utility.Medkit(player) == true, "a medkit starts")
check(Utility.Medkit(player) == false, "one at a time")
World.advance(1.4)
check(humanoid.Health == 90 and kit.Medkit == 1, ("healed 50 after the channel (%.0f)"):format(humanoid.Health))
humanoid.Health = humanoid.MaxHealth
check(Utility.Medkit(player) == false, "not at full health")
local plate = Utility.DropPlate(root.Position - Vector3.new(0, 2.4, 0))
Utility.CollectPlates()
check(rig:GetAttribute("Armour") == 25 and not plate.Parent, "walking over a plate takes it")
rig:SetAttribute("Armour", 75)
local spare = Utility.DropPlate(root.Position - Vector3.new(0, 2.4, 0))
Utility.CollectPlates()
check(spare.Parent ~= nil and rig:GetAttribute("Armour") == 75, "with full armour it is left for someone else")
spare:Destroy()

print("server: duels")
player:SetAttribute("DuelState", "duel")
World.advance(0.1)
check(rig:GetAttribute("Armour") == 50 and Utility.Kit(player).Frag == 2, "a duel hands both fighters the same armour and kit")
player:SetAttribute("DuelState", nil)
World.advance(0.1)

print("server: smoke and flash against enemies")
SmokeField.Clear()
Utility.Smoke(player, Vector3.new(0, 0, -10))
check(SmokeField.Blocks(Vector3.new(-12, 3, -10), Vector3.new(12, 3, -10)), "a sight line through the smoke is blocked")
check(not SmokeField.Blocks(Vector3.new(-12, 3, 20), Vector3.new(12, 3, 20)), "one well clear of it is not")
check(#sentTo("smoke") >= 1, "and everyone draws the cloud")
local Perception = World.require(sss.NPCService.AI.Perception)
local eyeModel = R.new("Model")
local head = R.new("Part")
head.Name = "Head"
head.CFrame = CFrame.new(-14, 4.5, -10)
head.Parent = eyeModel
local agentRoot = R.new("Part")
agentRoot.Name = "HumanoidRootPart"
agentRoot.CFrame = CFrame.new(-14, 3, -10)
agentRoot.Parent = eyeModel
eyeModel.Parent = World.workspace
local target = R.new("Model")
local targetHumanoid = R.new("Humanoid")
targetHumanoid.MaxHealth = 100
targetHumanoid.Health = 100
targetHumanoid.Parent = target
local chest = R.new("Part")
chest.Name = "UpperTorso"
chest.CFrame = CFrame.new(14, 3, -10)
chest.Parent = target
target.Parent = World.workspace
local agent = { model = eyeModel, root = agentRoot }
check(Perception.CanSee(agent, target) == false, "an enemy cannot see you through smoke")
SmokeField.Clear()
check(Perception.CanSee(agent, target) == true, "and can once it clears")
local candidateRoot = chest
local seenAgent = {
	model = eyeModel, root = agentRoot, memory = {}, threat = {},
	cfg = { AggroRange = 200, FieldOfView = 360, RequiresLineOfSight = true, MemoryTime = 6 },
	blindUntil = os.clock() + 5,
}
Perception.Update(seenAgent, os.clock(), { { model = target, root = candidateRoot } })
check(next(seenAgent.memory) == nil, "a flashed enemy sees nothing")
seenAgent.blindUntil = nil
Perception.Update(seenAgent, os.clock(), { { model = target, root = candidateRoot } })
check(seenAgent.memory[target] ~= nil and seenAgent.memory[target].visible, "and sees you again once its eyes come back")

-- --------------------------------------------------------------- client --

print("client")
table.clear(toServer)
World.run(World.service("StarterPlayer").StarterPlayerScripts.Utility)
World.advance(0.3)
local gui = World.playerGui:FindFirstChild("UtilityHUD")
check(gui ~= nil and World.find(gui, "Tray") ~= nil, "the tray is built")
World.serverFire("Remotes", "UtilityEvent", "kit", { Frag = 2, Flash = 1, Smoke = 0, Medkit = 2 })
World.advance(0.1)
local fragCount = World.find(gui, "Frag"):FindFirstChild("Count")
check(fragCount.Text == "×2" and World.find(gui, "Medkit"):FindFirstChild("Count").Text == "×2", "it shows what you carry")
check(World.find(gui, "Frag"):FindFirstChild("Key").Text == "F", "the frag is selected, on F")
World.pressKey(Enum.KeyCode.X)
check(World.find(gui, "Flash"):FindFirstChild("Key").Text == "F", "X switches to the flashbang")
World.pressKey(Enum.KeyCode.X)
check(World.find(gui, "Frag"):FindFirstChild("Key").Text == "F", "and skips the smoke you have none of")

local camera = World.workspace.CurrentCamera
camera.CFrame = CFrame.new(0, 5, 10)
root.CFrame = CFrame.new(0, 3, 0)
World.holdKey(Enum.KeyCode.F, true)
World.advance(0.2)
local fx = World.workspace:FindFirstChild("UtilityFX")
local shown = 0
for _, b in ipairs(fx:GetChildren()) do
	if b.Name == "ArcBead" and b.Transparency < 1 then
		shown += 1
	end
end
check(shown > 10, ("holding F draws the arc (%d beads)"):format(shown))
World.holdKey(Enum.KeyCode.F, false)
World.advance(0.1)
local throwCall = nil
for _, e in ipairs(toServer) do
	if e.name == "UtilityAction" and e.args[1] == "throw" then
		throwCall = e.args
	end
end
check(throwCall and throwCall[2] == "Frag" and typeof(throwCall[4]) == "Vector3", "letting go asks the server to throw it")
World.pressKey(Enum.KeyCode.Z)
local medkitCall = false
for _, e in ipairs(toServer) do
	if e.name == "UtilityAction" and e.args[1] == "medkit" then
		medkitCall = true
	end
end
check(medkitCall, "Z asks for a medkit")

-- A flash in front of the camera whites the screen out; one behind it barely does.
camera.CFrame = CFrame.new(Vector3.new(0, 5, 10)) -- looking along -Z
World.serverFire("Remotes", "UtilityEvent", "flash", Vector3.new(0, 5, -2))
World.advance(0.2)
local white = World.find(World.playerGui:FindFirstChild("FlashWhiteout"), "Whiteout")
check(white.BackgroundTransparency < 0.5, ("a flash you are looking at whites the screen (%.2f)"):format(white.BackgroundTransparency))
World.serverFire("Remotes", "UtilityEvent", "smoke", Vector3.new(0, 0, -30), 13, 15)
World.advance(0.3)
local puffs = 0
for _, p in ipairs(fx:GetChildren()) do
	if p.Name == "Smoke" then
		puffs += 1
	end
end
check(puffs >= 12, ("smoke stands as a cloud (%d puffs)"):format(puffs))
World.serverFire("Remotes", "UtilityEvent", "heal", rig, 1.2)
World.advance(0.2)
check(World.find(gui, "HealBar").Visible, "your medkit shows its bar")

print(failures == 0 and "\27[32mall utility checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
require("@lune/process").exit(failures == 0 and 0 or 1)
