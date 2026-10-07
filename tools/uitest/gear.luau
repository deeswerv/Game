--!nocheck
-- ZEE TACTICS gear (GearConfig, GearService, UtilityService's use of it), checked without
-- Studio:
--
--   * three slots, six grades each (Common to Mastery), the Common free and owned by all,
--     each grade dearer and later than the one under it, Mastery wanting crystals too;
--   * buying: the level, the coins and the crystals are all checked on the server, what you
--     own you cannot buy twice, and a bought piece goes straight into its slot; Street Cred
--     knocks a little off; equipping something you do not own is refused;
--   * in play: armour starts a life with what the vest gives and caps where it says, a heal
--     heals what it says in the time it says (the Mastery one adds armour), a bomb goes off
--     its own way -- sticky stops dead, cluster scatters, incendiary burns, a singularity
--     pulls; and a duel always uses the Common of each.
--
--   lune run tools/uitest/gear.luau

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

-- A flat floor at y = 0, and a wall at z = -30 when asked for.
local wallOn = false
R.ClassMethods.Workspace.Raycast = function(_self, origin, direction)
	if wallOn and direction.Z < 0 and origin.Z > -30 and origin.Z + direction.Z <= -30 then
		local t = (-30 - origin.Z) / direction.Z
		return { Position = origin + direction * t, Normal = Vector3.new(0, 0, 1), Instance = { Name = "Wall" } }
	end
	if direction.Y < 0 and origin.Y >= 0 then
		local t = -origin.Y / direction.Y
		if t <= 1 then
			return { Position = origin + direction * t, Normal = Vector3.new(0, 1, 0), Instance = { Name = "Floor" } }
		end
	end
	return nil
end
local toClients = {}
R.ClassMethods.RemoteEvent.FireClient = function(self, _player, ...)
	table.insert(toClients, { name = self.Name, args = { ... } })
end
R.ClassMethods.RemoteEvent.FireAllClients = function(self, ...)
	table.insert(toClients, { name = self.Name, args = { ... } })
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
local player = World.player

local profile = {
	Level = 1, EXP = 0, MaxEXP = 100, Crystals = 0, OwnedGear = {}, EquippedGear = {}, Reputation = {},
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
return PDM
]]
stub.Parent = sss
World.require(stub).Bind(profile)

-- Crystals on the profile, and Street Cred we can set.
local crystals = R.new("ModuleScript")
crystals.Name = "CrystalService"
crystals.Source = [[
local PDM = require(script.Parent.PlayerDataManager)
local CrystalService = {}
local function data()
	return PDM:GetPlayerDataReplica():expect().Data
end
function CrystalService.Get()
	return data().Crystals or 0
end
function CrystalService.Spend(_player, n)
	local d = data()
	if (d.Crystals or 0) < n then
		return false
	end
	d.Crystals -= n
	return true
end
function CrystalService.Award(_player, n)
	local d = data()
	d.Crystals = (d.Crystals or 0) + n
end
return CrystalService
]]
crystals.Parent = sss
local turf = R.new("ModuleScript")
turf.Name = "TurfWarService"
turf.Source = [[
local T = { band = "Neutral" }
function T.Cred()
	return 0, T.band
end
return T
]]
turf.Parent = sss
local Turf = World.require(turf)

for _, name in ipairs({ "KillCredit", "SmokeField", "UtilityService", "NPCService", "WeaponPose", "GearService" }) do
	R.mirror(place:GetService("ServerScriptService"):FindFirstChild(name), sss)
end
local rig = Rig.character(World, place)
local humanoid = rig:FindFirstChildOfClass("Humanoid")
local root = rig:FindFirstChild("HumanoidRootPart")
root.CFrame = CFrame.new(0, 3, 0)
local statsFolder = R.new("Folder")
statsFolder.Name = "Stats"
local levelValue = R.new("IntValue")
levelValue.Name = "Level"
levelValue.Value = 1
levelValue.Parent = statsFolder
statsFolder.Parent = player
player:SetAttribute("Level", 1)
local coins = player:FindFirstChild("leaderstats"):FindFirstChild("Coins")
coins.Value = 0

local GearConfig = World.require(rs.GearConfig)
local UtilityConfig = World.require(rs.UtilityConfig)
local Gear = World.require(sss.GearService)
local Utility = World.require(sss.UtilityService)
World.advance(0.3)

-- --------------------------------------------------------------- catalogue --

print("the catalogue")
local wellFormed = true
for _, slot in ipairs(GearConfig.Slots) do
	local items = GearConfig.ForSlot(slot)
	local lastCoins, lastLevel = -1, 0
	wellFormed = wellFormed and #items == 6
	for i, item in ipairs(items) do
		wellFormed = wellFormed and item.tier == GearConfig.Tiers[i] and item.coins > lastCoins and item.level >= lastLevel
		lastCoins, lastLevel = item.coins, item.level
	end
	wellFormed = wellFormed and GearConfig.IsFree(items[1].id) and items[6].crystals > 0
	check(GearConfig.Default[slot] == items[1].id, slot .. ": the Common one is the default")
end
check(wellFormed, "three slots, six grades each, each dearer and later than the last, Mastery wants crystals")
check(GearConfig.Get("Heal_FieldMedkit").stats.heal == 50 and GearConfig.Get("Armor_Padded").stats.max == 75
	and GearConfig.Get("Bomb_Frag").stats.damage == 110, "the Commons are exactly the old kit")

-- --------------------------------------------------------------- buying --

print("buying")
check(Gear.Owns(player, "Heal_FieldMedkit") and not Gear.Owns(player, "Heal_TraumaKit"), "everyone owns the Commons")
local r = Gear.Buy(player, "Heal_TraumaKit")
check(not r.ok and r.reason:find("level", 1, true), "too low a level: " .. tostring(r.reason))
levelValue.Value = 30
player:SetAttribute("Level", 30)
r = Gear.Buy(player, "Heal_TraumaKit")
check(not r.ok and r.reason:find("more", 1, true) and coins.Value == 0, "no money: " .. tostring(r.reason))
coins.Value = 600000
local price = Gear.PriceOf(player, GearConfig.Get("Armor_Carrier"))
check(price == GearConfig.Get("Armor_Carrier").coins, ("full price with no Street Cred ($%d)"):format(price))
r = Gear.Buy(player, "Armor_Carrier")
check(r.ok and coins.Value == 600000 - price and Gear.Owns(player, "Armor_Carrier"), "bought: " .. tostring(r.reason))
check(Gear.Equipped(player, "Armor").id == "Armor_Carrier" and player:GetAttribute("GearArmor") == "Armor_Carrier",
	"and straight into its slot")
r = Gear.Buy(player, "Armor_Carrier")
check(not r.ok and coins.Value == 600000 - price, "not twice")
r = Gear.Buy(player, "Heal_ZeeElixir")
check(not r.ok and r.reason:find("crystals", 1, true), "Mastery wants crystals: " .. tostring(r.reason))
profile.Crystals = 40
Turf.band = "Honoured"
local elixir = GearConfig.Get("Heal_ZeeElixir")
check(Gear.PriceOf(player, elixir) < elixir.coins * 0.9, "Honoured Street Cred knocks some off")
local before = coins.Value
r = Gear.Buy(player, "Heal_ZeeElixir")
check(r.ok and profile.Crystals == 40 - elixir.crystals and before - coins.Value == Gear.PriceOf(player, elixir),
	"bought with coins and crystals")
Turf.band = "Neutral"
r = Gear.Equip(player, "Bomb_Singularity")
check(not r.ok, "you cannot equip what you do not own")
for _, id in ipairs({ "Bomb_Sticky", "Bomb_Cluster", "Bomb_Incendiary", "Bomb_Singularity" }) do
	profile.Crystals = 100
	check(Gear.Buy(player, id).ok, "bought " .. id)
end
local state = Gear.State(player)
check(state.owned.Bomb_Cluster and state.equipped.Bomb == "Bomb_Singularity" and state.equipped.Heal == "Heal_ZeeElixir",
	"the state the counter draws")

-- --------------------------------------------------------------- in play --

print("armour and heals")
Utility.Refill(player)
check(rig:GetAttribute("MaxArmour") == 100 and rig:GetAttribute("Armour") == 50,
	("the Plate Carrier: a life starts at 50 of 100 (%s/%s)"):format(tostring(rig:GetAttribute("Armour")),
		tostring(rig:GetAttribute("MaxArmour"))))
check(Utility.Kit(player).Medkit == 4, "the Zee Elixir: four a life")
humanoid.Health = 10
rig:SetAttribute("Armour", 0)
check(Utility.Medkit(player), "a heal starts")
World.advance(0.3)
check(humanoid.Health == 10, "not before its time")
World.advance(0.4)
check(humanoid.Health == 100 and rig:GetAttribute("Armour") == 25, ("healed 100 and 25 armour in half a second (%s, %s)")
	:format(tostring(humanoid.Health), tostring(rig:GetAttribute("Armour"))))
rig:SetAttribute("Armour", 60)
Utility.CollectPlates()
local plate = Utility.DropPlate(root.Position - Vector3.new(0, 2.4, 0))
Utility.CollectPlates()
check(not plate.Parent and rig:GetAttribute("Armour") == 85, "a plate tops you past 75 when the vest carries more")

print("bombs")
local npcs = World.workspace:FindFirstChild("NPCs") or R.new("Folder")
npcs.Name = "NPCs"
npcs.Parent = World.workspace
local function dummy(name, at)
	local model = R.new("Model")
	model.Name = name
	local r2 = R.new("Part")
	r2.Name = "HumanoidRootPart"
	r2.Size = Vector3.new(2, 2, 1)
	r2.CFrame = CFrame.new(at)
	World.force(r2, "AssemblyLinearVelocity", Vector3.new(0, 0, 0))
	r2.Parent = model
	local h = R.new("Humanoid")
	h.MaxHealth = 400
	h.Health = 400
	h.Parent = model
	model.PrimaryPart = r2
	model.Parent = npcs
	return model, h
end

-- Sticky: stops on the wall it hits.
local sticky = GearConfig.Get("Bomb_Sticky")
player:SetAttribute("GearBomb", "Bomb_Sticky")
Utility.Refill(player)
wallOn = true
table.clear(toClients)
check(Utility.Throw(player, "Frag", Vector3.new(0, 4.5, 0), Vector3.new(0, 0.1, -1)), "a sticky bomb goes")
local thrown = sentTo("thrown")[1]
local points = thrown and thrown[2].points
local rest = points and points[#points]
check(rest and math.abs(rest.Z - (-30)) < 0.05 and rest.Y > 1,
	("and sticks to the wall, off the ground (%s)"):format(tostring(rest)))
check(thrown and thrown[2].bomb == "Bomb_Sticky" and math.abs(thrown[2].fuse - (thrown[2].times[#thrown[2].times]
	+ sticky.stats.fuse)) < 0.01, "going off its fuse after it sticks")
wallOn = false

-- Cluster: one blast, then the bomblets.
local _, clusterH = dummy("Cluster", Vector3.new(0, 3, -60))
table.clear(toClients)
Utility.Detonate(player, Vector3.new(0, 1, -60), GearConfig.Get("Bomb_Cluster"))
check(#sentTo("explode") == 1 and clusterH.Health < 400, "a cluster bomb: the first blast")
World.advance(1.4)
check(#sentTo("explode") == 1 + GearConfig.Get("Bomb_Cluster").stats.bomblets, ("then %d more (%d blasts)"):format(
	GearConfig.Get("Bomb_Cluster").stats.bomblets, #sentTo("explode")))

-- Incendiary: a blast, then fire that keeps burning.
local _, fireH = dummy("Burning", Vector3.new(0, 3, -90))
table.clear(toClients)
Utility.Detonate(player, Vector3.new(0, 1, -90), GearConfig.Get("Bomb_Incendiary"))
local afterBlast = fireH.Health
World.advance(3)
check(#sentTo("fire") == 1 and fireH.Health < afterBlast - 30,
	("an incendiary: the fire keeps burning (%.0f after the blast, %.0f now)"):format(afterBlast, fireH.Health))

-- Singularity: pulled in, then the blast.
local pulled, pulledH = dummy("Pulled", Vector3.new(14, 3, -120))
table.clear(toClients)
Utility.Detonate(player, Vector3.new(0, 1, -120), GearConfig.Get("Bomb_Singularity"))
World.advance(0.2)
local v = pulled.PrimaryPart.AssemblyLinearVelocity
check(#sentTo("singularity") == 1 and v.X < -5, ("a singularity drags them in (%s)"):format(tostring(v)))
World.advance(1.2)
check(#sentTo("explode") == 1 and pulledH.Health < 400, "and then goes off")

print("duels stay even")
player:SetAttribute("DuelState", "duel")
World.advance(0.1)
check(rig:GetAttribute("MaxArmour") == 75 and rig:GetAttribute("Armour") == 50 and Utility.Kit(player).Medkit == 2,
	"in a duel: the Common armour and heals, whatever you own")
check(Utility.GearOf(player, "Bomb").id == "Bomb_Frag", "and a plain frag")
player:SetAttribute("DuelState", nil)

print("restocking mid-life")
World.advance(0.1)
Utility.Refill(player)
local kit = Utility.Kit(player)
local fullFrags = kit.Frag
local stock = Gear.State(player).restock
check(stock ~= nil and stock.items.Frag.why == "full" and stock.items.Medkit.why == "full",
	"a fresh life is full: nothing to restock")
kit.Frag = 0
kit.Medkit = 1
rig:SetAttribute("Armour", 0)
coins.Value = 100
stock = Gear.State(player).restock
check(stock.items.Frag.have == 0 and stock.items.Frag.cap == fullFrags and stock.items.Frag.why == "coins",
	("out of bombs, and short of the price ($%d)"):format(stock.items.Frag.price))
check(stock.items.Frag.price > UtilityConfig.RestockPrice("Frag", "Common"),
	("a Singularity Charge costs more to restock than a frag ($%d)"):format(stock.items.Frag.price))
check(UtilityConfig.RestockPrice("Smoke") == UtilityConfig.Restock.price.Smoke, "a smoke is always the Common price")
coins.Value = 100000
local before2 = coins.Value
local ok, why = Utility.Buy(player, "Frag")
check(ok and Utility.Kit(player).Frag == 1 and before2 - coins.Value == stock.items.Frag.price,
	"one more, for its price: " .. tostring(why))
check(#sentTo("kit") > 0, "and the hotbar is told")
ok, why = Utility.Buy(player, "Frag")
check(not ok and why == "busy", "not two in the same instant")
World.advance(0.5)
check(Utility.Buy(player, "Frag") and Utility.Kit(player).Frag == fullFrags, "up to a fresh life's worth")
World.advance(0.5)
ok, why = Utility.Buy(player, "Frag")
check(not ok and why == "full", "and no further")
World.advance(0.5)
check(Utility.Buy(player, "Medkit") and Utility.Kit(player).Medkit == 2, "a heal")
World.advance(0.5)
local plate = GearConfig.Get("Armor_Carrier").stats.plate
check(Utility.Buy(player, "Armour") and rig:GetAttribute("Armour") == plate, ("a plate of armour (+%d)"):format(plate))
ok, why = Utility.Buy(player, "Nuke")
check(not ok, "nothing that is not on the strip")
-- Through the remote the inventory uses.
World.advance(0.5)
kit.Smoke = 0
local reply = Gear.Invoke and Gear.Invoke(player, "restock", "Smoke") or nil
check(reply == nil or (reply.ok and reply.state and reply.state.restock.items.Smoke.have == 1),
	"the inventory's GearAction answers with the new state")
player:SetAttribute("DuelState", "duel")
World.advance(0.6)
Utility.Kit(player).Frag = 0
ok, why = Utility.Buy(player, "Frag")
check(not ok and why == "duel", "never in a duel")
player:SetAttribute("DuelState", nil)

print(failures == 0 and "\27[32mall gear checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
require("@lune/process").exit(failures == 0 and 0 or 1)
