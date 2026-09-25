--!nocheck
-- NPC tactics (NPCService.AI.Tactics), decided and resolved without Studio:
--
--   * a Soldier lobs a grenade at someone who ducked out of sight, or who has camped one
--     spot, but not onto its own side, not point-blank, not out of range, not without one;
--   * the blast hurts, falls off with distance, and a wall in between takes most of it;
--   * patching up only happens hurt and unseen, and gives the health back;
--   * rounds cracking past suppress; a strafe step goes sideways to the target;
--   * the callouts go out on the effects remote.
--
-- The world is a flat floor at y = 0 plus, where a check needs one, a single wall: this
-- stands in for workspace:Raycast, which the harness does not simulate.
--
--   lune run tools/uitest/tactics.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R
local Vector3 = roblox.Vector3

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
R.ClassMethods.Workspace.Raycast = function(_self, origin, direction)
	local best, bestT, normal = nil, math.huge, nil
	if wall then
		local x0, x1 = slab(origin.X, direction.X, wall.min.X, wall.max.X)
		local y0, y1 = slab(origin.Y, direction.Y, wall.min.Y, wall.max.Y)
		local z0, z1 = slab(origin.Z, direction.Z, wall.min.Z, wall.max.Z)
		local enter, leave = math.max(x0, y0, z0), math.min(x1, y1, z1)
		if enter <= leave and enter >= 0 and enter <= 1 then
			bestT, best, normal = enter, "Wall", Vector3.new(0, 0, -1)
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
R.ClassMethods.Workspace.GetPartBoundsInBox = function()
	return {}
end

local sent = {}
R.ClassMethods.RemoteEvent.FireClient = function(_self, _player, batch)
	for _, event in ipairs(batch) do
		table.insert(sent, event)
	end
end
R.ClassMethods.RemoteEvent.FireAllClients = function() end

-- ------------------------------------------------------------ the modules --

local place = World.loadPlace("build/Game.rbxl")
local sss = World.service("ServerScriptService")
for _, name in ipairs({ "NPCService", "KillCredit", "WeaponPose" }) do
	R.mirror(place:GetService("ServerScriptService"):FindFirstChild(name), sss)
end
local rs = World.service("ReplicatedStorage")
if not rs:FindFirstChild("Remotes") then
	local remotes = R.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = rs
end
local NPCConfig = World.require(rs.NPCConfig)
local Tactics = World.require(sss.NPCService.AI.Tactics)
local Effects = World.require(sss.NPCService.Effects)

-- The player, standing at the origin.
local character = World.character
local root = character:FindFirstChild("HumanoidRootPart")
local target = Vector3.new(0, 3, 0)
root.Position = target
local humanoid = character:FindFirstChildOfClass("Humanoid")

local function makeAgent(archetype: string, at: Vector3)
	local model = R.new("Model")
	model.Name = archetype
	local part = R.new("Part")
	part.Name = "HumanoidRootPart"
	part.Position = at
	part.Parent = model
	local hum = R.new("Humanoid")
	hum.MaxHealth = 150
	hum.Health = 150
	hum.Parent = model
	model.Parent = World.workspace
	local cfg = NPCConfig.Levelled(NPCConfig.Get(archetype), 3)
	return {
		alive = true, model = model, root = part, humanoid = hum, cfg = cfg, scale = 1,
		grenadesLeft = cfg.Grenades, medkits = cfg.Medkits,
		nav = { RecentlyFailed = function()
			return false
		end },
	}
end

local soldier = makeAgent("Soldier", Vector3.new(0, 3, -32))
local roster = { [soldier.model] = soldier }
Tactics.Agents = function()
	return roster
end

local function infoFor(visible: boolean, sinceSeen: number, now: number)
	return {
		model = character, root = root, visible = visible, position = root.Position, lastPosition = root.Position,
		entry = { lastSeen = now - sinceSeen }, distance = (root.Position - soldier.root.Position).Magnitude,
	}
end

-- -------------------------------------------------------------- grenades --

print("config")
check(soldier.cfg.Grenades == 1 and soldier.cfg.Medkits == 1 and soldier.cfg.Strafe == true,
	"a Soldier carries a grenade and a medkit, and strafes")
check(soldier.cfg.GrenadeDamage > 45, ("grenade damage scales with level (%.1f at level 3)"):format(soldier.cfg.GrenadeDamage))
check(NPCConfig.Get("Brute").Grenades == 0 and NPCConfig.Get("Brute").Voice == "Brute", "a Brute has no grenades, and its own voice")
check(NPCConfig.SpawnRules.MaxAlive <= 24, ("population cap lowered (%d)"):format(NPCConfig.SpawnRules.MaxAlive))
for _, name in ipairs({ "Grunt", "Soldier", "Brute", "Marksman", "Elite" }) do
	check(NPCConfig.Get(name).RespawnTime >= 50, ("%s respawns slowly (%ds)"):format(name, NPCConfig.Get(name).RespawnTime))
end

print("when to throw")
local now = 1000
check(Tactics.WantsGrenade(soldier, now, infoFor(false, 2, now)), "throws at someone who ducked out of sight 2s ago")
local plan = soldier.grenadePlan
check(plan ~= nil and (Vector3.new(plan.to.X, 0, plan.to.Z) - Vector3.new(0, 0, 0)).Magnitude < 5,
	("lands near where they were (%.1f studs off)"):format(plan and Vector3.new(plan.to.X, 0, plan.to.Z).Magnitude or -1))
soldier.grenadePlan = nil

now += 1
check(not Tactics.WantsGrenade(soldier, now, infoFor(true, 0, now)), "not at someone in plain sight and moving")
now += 1
check(not Tactics.WantsGrenade(soldier, now, infoFor(false, 0.3, now)), "not the instant they step behind something")
now += 1
check(not Tactics.WantsGrenade(soldier, now, infoFor(false, 9, now)), "not at a memory nine seconds old")

-- Camping: visible, but has not moved for five seconds.
now += 1
Tactics.WantsGrenade(soldier, now, infoFor(true, 0, now))
now += 5
check(Tactics.WantsGrenade(soldier, now, infoFor(true, 0, now)), "throws at someone camping one spot")
soldier.grenadePlan = nil

now += 1
local friend = makeAgent("Grunt", Vector3.new(4, 3, 3))
roster[friend.model] = friend
check(not Tactics.WantsGrenade(soldier, now, infoFor(false, 2, now)), "never onto its own side")
roster[friend.model] = nil

now += 1
soldier.root.Position = Vector3.new(0, 3, -9)
check(not Tactics.WantsGrenade(soldier, now, infoFor(false, 2, now)), "not point-blank")
now += 1
soldier.root.Position = Vector3.new(0, 3, -90)
check(not Tactics.WantsGrenade(soldier, now, infoFor(false, 2, now)), "not out of range")
soldier.root.Position = Vector3.new(0, 3, -32)

now += 1
soldier.grenadesLeft = 0
check(not Tactics.WantsGrenade(soldier, now, infoFor(false, 2, now)), "not without a grenade")
soldier.grenadesLeft = 1

print("the blast")
local function throwAndWait(): number
	local t = os.clock()
	soldier.lastGrenadeAt = nil
	soldier.grenadeCheckAt = nil
	soldier.grenadesLeft = 1
	humanoid.Health = 100
	Tactics.Forget(character)
	local ok = Tactics.WantsGrenade(soldier, t, infoFor(false, 2, t))
	if not ok then
		return -1
	end
	soldier.grenadePlan.to = Vector3.new(0, 0.45, 0)          -- dead on, so the numbers compare
	Tactics.Release(soldier, t)
	World.advance(3.4)
	return 100 - humanoid.Health
end
local open = throwAndWait()
check(open > 30, ("in the open, at the centre: %.1f damage"):format(open))
check(soldier.grenadesLeft == 0, "the grenade is used up")
root.Position = Vector3.new(9, 3, 0)
local edge = throwAndWait()
check(edge > 0 and edge < open, ("further out, less (%.1f)"):format(edge))
root.Position = Vector3.new(30, 3, 0)
check(throwAndWait() == 0, "out of the radius: nothing")
root.Position = Vector3.new(6, 3, 0)
wall = { min = Vector3.new(2, -1, -6), max = Vector3.new(3, 8, 6) }
local covered = throwAndWait()
wall = nil
local bare = throwAndWait()
check(covered < bare * 0.5, ("a wall in between takes most of it (%.1f vs %.1f)"):format(covered, bare))
root.Position = target
humanoid.Health = 100

-- -------------------------------------------------------------- healing --

print("patching up")
soldier.humanoid.Health = 50
soldier.lastHurtAt = now - 5
soldier.medkits = 1
check(Tactics.WantsHeal(soldier, now, infoFor(false, 3, now)), "hurt and unseen: patches up")
check(not Tactics.WantsHeal(soldier, now, infoFor(true, 0, now)), "not while it can be seen")
soldier.lastHurtAt = now - 1
check(not Tactics.WantsHeal(soldier, now, nil), "not straight after being hit")
soldier.lastHurtAt = now - 5
soldier.humanoid.Health = 120
check(not Tactics.WantsHeal(soldier, now, nil), "not when barely scratched")
soldier.humanoid.Health = 50
Tactics.StartHeal(soldier, now)
check(soldier.medkits == 0, "uses the medkit")
check(not Tactics.UpdateHeal(soldier, now + 1), "takes time")
check(Tactics.UpdateHeal(soldier, now + 3.1) and soldier.humanoid.Health == 110,
	("then gives the health back (%d)"):format(soldier.humanoid.Health))
check(not Tactics.WantsHeal(soldier, now + 10, nil), "only as many times as it has medkits")

-- ------------------------------------------------------ suppression / strafe --

print("suppression and strafing")
check(not Tactics.Suppressed(soldier, now), "not suppressed to begin with")
Tactics.Suppress(soldier, now)
check(Tactics.Suppressed(soldier, now + 1), "rounds cracking past suppress it")
check(not Tactics.Suppressed(soldier, now + 2), "and it wears off")
local strafe = Tactics.StrafePoint(soldier, infoFor(true, 0, now), now)
if strafe then
	local step = Vector3.new(strafe.X - soldier.root.Position.X, 0, strafe.Z - soldier.root.Position.Z)
	local toTarget = Vector3.new(-soldier.root.Position.X, 0, -soldier.root.Position.Z).Unit
	check(step.Magnitude >= 2.9 and step.Magnitude <= 6.1, ("a strafe step is a few studs (%.1f)"):format(step.Magnitude))
	check(math.abs(step.Unit:Dot(toTarget)) < 0.2, "and sideways to the target")
else
	check(false, "strafes when holding its ground")
end
check(Tactics.StrafePoint(soldier, infoFor(false, 1, now), now + 5) == nil, "no strafing at someone it cannot see")

-- -------------------------------------------------------------- callouts --

print("callouts")
table.clear(sent)
soldier.lastCalloutAt = nil
Tactics.Say(soldier, now + 100, "Grenade", true)
Tactics.Mark(soldier, "!")
Effects.Flush()
local callout, mark = nil, nil
for _, event in ipairs(sent) do
	if event[1] == "Callout" then
		callout = event
	elseif event[1] == "Mark" then
		mark = event
	end
end
check(callout ~= nil and table.find(Tactics.Lines.Soldier.Grenade, callout[3]) ~= nil,
	("a grenade is always called out (\"%s\")"):format(callout and callout[3] or "?"))
check(callout ~= nil and callout[4] == true, "and in the urgent colour")
check(mark ~= nil and mark[3] == "!", "the ! mark goes out")
table.clear(sent)
Tactics.Say(soldier, now + 101, "Reload")
Effects.Flush()
check(#sent == 0, "a second line a moment later is held back")
for voice, events in pairs(Tactics.Lines) do
	for event, lines in pairs(events) do
		for _, line in ipairs(lines) do
			if #line > 26 then
				check(false, ("%s/%s line fits a bubble: \"%s\""):format(voice, event, line))
			end
		end
	end
end
check(true, "every line fits a bubble")

print(failures == 0 and "\27[32mall tactics checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
-- KillCredit and the effects queue leave timers running; do not wait on them.
require("@lune/process").exit(failures == 0 and 0 or 1)
