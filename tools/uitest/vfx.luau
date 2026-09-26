--!nocheck
-- The VFX shelf, and the turf war and XP changes that came with it, checked without Studio:
--
--   * the catalogue: two slots, five of each, every one priced and drawn;
--   * buying through the shop's own purchase path charges the standing price, records it, and
--     puts it straight into an empty slot; equipping checks ownership and the slot;
--   * the equipped effects are published on the player, and a credited kill sends the killer's
--     effect to everyone; each kill effect plays; a bought tracer changes the round's look;
--   * turf wars are on four patches, and the threat level grows the crew and the payout;
--   * XP is paid at the new rate, and shown that way.
--
-- PlayerDataManager is stood in for by a plain table profile, as in progression.luau.
--
--   lune run tools/uitest/vfx.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R
local Vector3, CFrame, Color3 = roblox.Vector3, roblox.CFrame, roblox.Color3

-- The harness has no particle system; an emitter asked to emit is simply counted.
R.ClassMethods.ParticleEmitter = R.ClassMethods.ParticleEmitter or {}
R.ClassMethods.ParticleEmitter.Emit = function() end

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

-- Nothing in this world is solid; effects look for ground and find none.
R.ClassMethods.Workspace.Raycast = function()
	return nil
end

local place = World.loadPlace("build/Game.rbxl")
local rs = World.service("ReplicatedStorage")
local sss = World.service("ServerScriptService")
local player = World.player

local profile = {
	Level = 10, EXP = 0, MaxEXP = 100, StatPoints = 0, Prestige = 0, LifetimeXP = 0,
	Crystals = 0, Titles = {}, OwnedItems = {}, Coins = 0, CoinsMigrated = true, TotalKills = 0,
	Reputation = {}, OwnedVFX = {}, EquippedVFX = {}, WeaponVFX = {},
}
local saves = 0
local stub = R.new("ModuleScript")
stub.Name = "PlayerDataManager"
stub.Source = [[
local data = {}
local onSave = function() end
local listeners = {}
local Replica = { Data = data }
function Replica:SetValue(key, value)
	data[key] = value
	for _, fn in ipairs(listeners[key] or {}) do
		fn(value)
	end
end
function Replica:ListenToChange(key, fn)
	listeners[key] = listeners[key] or {}
	table.insert(listeners[key], fn)
end
function Replica:IsActive()
	return true
end
local function promise()
	local p = {}
	function p:andThen(fn)
		local ok, err = pcall(fn, Replica)
		return { catch = function(_, handler)
			if not ok then
				handler(err)
			end
		end }
	end
	function p:expect()
		return Replica
	end
	return p
end
local PDM = {}
function PDM.Bind(profile, saved)
	data = profile
	Replica.Data = profile
	onSave = saved
end
function PDM:GetPlayerDataReplica(_player)
	return promise()
end
function PDM:SaveNow(_player)
	onSave()
	return true
end
function PDM:IsSaving()
	return true
end
return PDM
]]
stub.Parent = sss
World.require(stub).Bind(profile, function()
	saves += 1
end)

-- Server-side remote calls, which the client harness does not model: recorded, not sent.
local toClients = {}
R.ClassMethods.RemoteEvent.FireClient = function(self, _player, ...)
	table.insert(toClients, { name = self.Name, args = { ... } })
end
R.ClassMethods.RemoteEvent.FireAllClients = function(self, ...)
	table.insert(toClients, { name = self.Name, args = { ... } })
end

for _, name in ipairs({ "KillCredit", "ShopService", "ReputationService", "LevelSystem", "WalletService",
	"AbilityService", "VFXService", "TurfWarService", "CrystalService", "NPCService", "ContractService" }) do
	R.mirror(place:GetService("ServerScriptService"):FindFirstChild(name), sss)
end


local leaderstats = player:FindFirstChild("leaderstats")
local coins = leaderstats:FindFirstChild("Coins")
coins.Value = 20000
player:SetAttribute("Level", 10)

local VFXConfig = World.require(rs.VFXConfig)
local GameConfig = World.require(rs.GameConfig)

-- --------------------------------------------------------------- catalogue --

print("the catalogue")
local kills, tracers = 0, 0
local drawnOk = true
for _, item in ipairs(VFXConfig.Items) do
	if item.slot == "Kill" then
		kills += 1
	elseif item.slot == "Tracer" then
		tracers += 1
		drawnOk = drawnOk and typeof(item.colour) == "Color3"
	end
	drawnOk = drawnOk and item.price > 0 and type(item.icon) == "string"
end
check(kills == 5 and tracers == 5, ("five kill effects and five tracers (%d, %d)"):format(kills, tracers))
check(drawnOk, "every one priced, with an icon; every tracer has a colour")
local a, b = VFXConfig.TracerStyle("TracerPrismatic", 1), VFXConfig.TracerStyle("TracerPrismatic", 2)
check(a and b and a.colour ~= b.colour, "a Prismatic tracer is a different colour shot to shot")
check(VFXConfig.TracerStyle("KillShatter", 1) == nil and VFXConfig.TracerStyle(nil, 1) == nil,
	"a kill effect or nothing is not a tracer")

-- ------------------------------------------------------------ buying --

print("buying and equipping")
local ShopService = World.require(sss.ShopService)
local VFXService = World.require(sss.VFXService)
World.advance(0.2)
local result = ShopService.AttemptPurchase(player, "vfx", "KillShatter")
check(result.ok and coins.Value == 20000 - 900, ("bought Shatter for 900 (%s, $%d left)"):format(tostring(result.reason),
	coins.Value))
check(table.find(profile.OwnedVFX, "KillShatter") ~= nil, "and it is recorded as owned")
check(not ShopService.AttemptPurchase(player, "vfx", "KillShatter").ok, "not twice")
check(not ShopService.AttemptPurchase(player, "vfx", "NoSuchThing").ok, "an unknown id is refused")
VFXService.EquipIfEmpty(player, "KillShatter")
check(profile.EquippedVFX.Kill == "KillShatter" and player:GetAttribute("VFX_Kill") == "KillShatter",
	"it goes straight into the empty Kill slot, and everyone can see it")
check(not VFXService.Equip(player, "Kill", "KillVoid").ok, "something not owned cannot be equipped")
ShopService.AttemptPurchase(player, "vfx", "TracerGold")
check(not VFXService.Equip(player, "Kill", "TracerGold").ok, "a tracer does not go in the Kill slot")
check(VFXService.Equip(player, "Tracer", "TracerGold").ok and player:GetAttribute("VFX_Tracer") == "TracerGold",
	"a tracer equips into the Tracer slot")
ShopService.AttemptPurchase(player, "vfx", "KillVoid")
VFXService.EquipIfEmpty(player, "KillVoid")
check(player:GetAttribute("VFX_Kill") == "KillShatter", "buying another does not replace the one you chose")
check(VFXService.Equip(player, "Tracer", nil).ok and player:GetAttribute("VFX_Tracer") == nil, "a slot can be emptied")
profile.EquippedVFX = { Kill = "KillGemstone" }
VFXService.Publish(player)
check(player:GetAttribute("VFX_Kill") == nil, "a saved effect you do not own is not shown")
VFXService.Equip(player, "Kill", "KillShatter")

print("kills")
table.clear(toClients)
local KillCredit = World.require(sss.KillCredit)
local victim = R.new("Model")
local vroot = R.new("Part")
vroot.Name = "HumanoidRootPart"
vroot.CFrame = CFrame.new(10, 3, 0)
vroot.Parent = victim
local vh = R.new("Humanoid")
vh.Parent = victim
victim.Parent = World.workspace
KillCredit.KillAwarded:Fire(player, vh, nil)
World.advance(0.1)
local sent = nil
for _, e in ipairs(toClients) do
	if e.name == "VFXEvent" and e.args[1] == "kill" then
		sent = e.args
	end
end
check(sent ~= nil and sent[2] == "KillShatter" and sent[3] == victim and (sent[4] - Vector3.new(10, 3, 0)).Magnitude < 1e-3,
	"a credited kill sends the killer's effect, on the body, to everyone")

print("per gun")
check(VFXService.EquipWeapon(player, "Carbine", "Kill", "KillVoid").ok, "the Carbine gets its own kill effect")
check(VFXConfig.Resolve(player, "Kill", "Carbine") == "KillVoid", "kills with the Carbine play Void")
check(VFXConfig.Resolve(player, "Kill", "Scattergun") == "KillShatter", "every other gun keeps the equipped Shatter")
check(not VFXService.EquipWeapon(player, "Carbine", "Kill", "KillLightning").ok, "an effect you do not own is refused")
check(not VFXService.EquipWeapon(player, "Carbine", "Kill", "TracerGold").ok, "a tracer is not a kill effect")
check(not VFXService.EquipWeapon(player, "NoSuchGun", "Kill", "KillVoid").ok, "nor a gun that does not exist")
check(VFXService.EquipWeapon(player, "Scattergun", "Tracer", "TracerGold").ok
	and VFXConfig.Resolve(player, "Tracer", "Scattergun") == "TracerGold" and VFXConfig.Resolve(player, "Tracer", "Carbine") == nil,
	"a tracer on one gun only")
check(VFXService.EquipWeapon(player, "Fang", "Kill", "none").ok and VFXConfig.Resolve(player, "Kill", "Fang") == nil,
	"\"none\" plays nothing on that gun")
check(profile.WeaponVFX.Carbine.Kill == "KillVoid" and type(player:GetAttribute("VFX_Guns")) == "string",
	"saved on the profile, and published for every client")
table.clear(toClients)
vh:SetAttribute("LastHitWeapon", "Carbine")
KillCredit.KillAwarded:Fire(player, vh, nil)
World.advance(0.1)
sent = nil
for _, e in ipairs(toClients) do
	if e.name == "VFXEvent" and e.args[1] == "kill" then
		sent = e.args
	end
end
check(sent ~= nil and sent[2] == "KillVoid", "a kill with the Carbine sends ITS effect")
check(VFXService.EquipWeapon(player, "Carbine", "Kill", nil).ok and VFXConfig.Resolve(player, "Kill", "Carbine") == "KillShatter",
	"and Default puts it back on the equipped one")
vh:SetAttribute("LastHitWeapon", nil)

local CombatFX = World.require(rs.CombatFX)
local bin = World.workspace:FindFirstChild("CombatFX")
local allPlayed = true
for _, item in ipairs(VFXConfig.Items) do
	if item.slot == "Kill" then
		local before = #bin:GetChildren()
		local okPlay, err = pcall(CombatFX.KillEffect, item.id, Vector3.new(0, 5, 0), victim)
		World.advance(0.05)
		if not okPlay or #bin:GetChildren() <= before then
			allPlayed = false
			print("    " .. item.id .. ": " .. tostring(err))
		end
	end
end
check(allPlayed, "every kill effect plays and puts something in the world")
World.advance(2.5)
do
	local before = #bin:GetChildren()
	CombatFX.KillEffect("KillLightning", Vector3.new(0, 5, 0), victim)
	World.advance(0.3)
	local cylinders, bolts = 0, 0
	for _, c in ipairs(bin:GetChildren()) do
		if c.ClassName == "Part" and c.Shape == roblox.Enum.PartType.Cylinder then
			cylinders += 1
		elseif c.ClassName == "Part" and c.Size.Z > 3 then
			bolts += 1
		end
	end
	check(#bin:GetChildren() - before >= 40 and bolts >= 12 and cylinders >= 2,
		("Thunderstrike comes down hard: %d parts, %d bolt segments, a shockwave and a scorch"):format(
			#bin:GetChildren() - before, bolts))
end
check(CombatFX.KillEffect("NoSuchEffect", Vector3.new(), nil) == false, "an unknown effect is ignored")
World.advance(2.5)

print("tracers")
local from, to = Vector3.new(0, 5, 0), Vector3.new(0, 5, -200)
CombatFX.Tracer(from, to, Color3.fromRGB(255, 196, 60), 0.12, "Carbine", { streak = 1.6, trail = 0.6 })
local host = bin:FindFirstChild("TracerHost")
local beams = 0
for _, c in ipairs(host:GetChildren()) do
	if c.ClassName == "Beam" then
		beams += 1
	end
end
check(beams == 4, ("a bought tracer adds a glow and a vapour line in its colour to a rifle round (%d beams)"):format(beams))
World.advance(0.08)
local longest = 0
for _, c in ipairs(host:GetChildren()) do
	if c.ClassName == "Beam" and c.Attachment0 and c.Attachment1 then
		longest = math.max(longest, (c.Attachment1.Position - c.Attachment0.Position).Magnitude)
	end
end
check(longest > 12 * 1.3, ("and its streak is longer than the weapon's own (%.1f)"):format(longest))
World.advance(1.2)
check(CombatFX.HasOwnTracer("Carbine_DarkMatter") and not CombatFX.HasOwnTracer("Carbine"),
	"a Mastery Weapon with its own tracer keeps it")

-- --------------------------------------------------------------- turf --

print("turf wars")
local Turf = World.require(sss.TurfWarService)
check(#Turf.Zones == 4 and Turf.COOLDOWN <= 180, ("four patches to start one on, each quiet for %ds after")
	:format(Turf.COOLDOWN))
local sizes = {}
for level = 1, 5 do
	sizes[level] = #Turf.CrewFor(level)
end
check(sizes[1] == 5 and sizes[2] == 6 and sizes[3] == 7 and sizes[4] == 9 and sizes[5] == 10,
	("the crew grows with the threat (%s)"):format(table.concat(sizes, ", ")))
local r1, r5, mvp1 = Turf.RewardFor(1, false), Turf.RewardFor(5, false), Turf.RewardFor(1, true)
check(r1.coins == 1100 and r1.xp == 800 and r5.coins == 2200 and r5.xp == 1600,
	("and so does the payout (I: $%d/%d XP, V: $%d/%d XP)"):format(r1.coins, r1.xp, r5.coins, r5.xp))
check(mvp1.coins == 1650, "the MVP gets half as much again")
Turf.SetThreat(9)
check(Turf.Threat() == 5 and rs:GetAttribute("TurfThreat") == 5, "the threat tops out at V, and the HUD is told")
Turf.SetThreat(0)
check(Turf.Threat() == 1, "and never drops below I")

-- --------------------------------------------------------------- XP --

print("XP")
local LevelSystem = World.require(sss.LevelSystem)
profile.Level, profile.EXP, profile.MaxEXP, profile.Prestige = 5, 0, GameConfig.GetRequiredEXP(5), 0
LevelSystem.AwardXP(player, 20)
check(profile.EXP == 30, ("20 XP pays 30 at the 1.5x rate (%d)"):format(profile.EXP))
check(GameConfig.ShownXP(800) == 1200, "and a turf war's 800 is shown as the 1,200 it pays")

print(failures == 0 and "\27[32mall vfx checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
require("@lune/process").exit(failures == 0 and 0 or 1)
