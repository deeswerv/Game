--!nocheck
-- The Warden - Dark Matter Mastery Weapon, checked without Studio:
--
--   * the build put a whole weapon in storeitems from ARCarbineHD_DarkMatter.glb: the Handle
--     and its sounds, a muzzle marker (point and light) out past the front on the bore line,
--     the names the pose solver, the reload and the charge look for, every part welded,
--     massless and out of the way of physics and raycasts, rifle-length, with the carbine's
--     authored flash;
--   * the magazine (and what grows on it) is what the reload takes, every piece findable by
--     its own name;
--   * it is a variant of the Warden: the Warden's numbers, its own Dark Matter look, and the
--     market says how it is earned;
--   * crossing Gold mastery with the Warden grants it, and then it can be equipped.
--
--   lune run tools/uitest/mastery.luau

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

R.ClassMethods.Workspace.Raycast = function()
	return nil
end

local place = World.loadPlace("build/Game.rbxl")
local rs = World.service("ReplicatedStorage")
local sss = World.service("ServerScriptService")
local player = World.player

local WeaponConfig = World.require(rs.WeaponConfig)

-- -------------------------------------------------------------------- the tool --

print("the weapon")
local store = rs:FindFirstChild("storeitems")
local tool = store:FindFirstChild("Warden_DarkMatter")
check(tool ~= nil and tool:IsA("Tool"), "Warden_DarkMatter is a Tool in storeitems")
check(tool:GetAttribute("BuiltFrom") == "ARCarbineHD_DarkMatter.glb", "built from the uploaded GLB")
local handle = tool:FindFirstChild("Handle")
check(handle ~= nil and handle:FindFirstChild("Fire") ~= nil and handle:FindFirstChild("Reload") ~= nil,
	"a Handle with the Fire and Reload sounds")
local muzzle = tool:FindFirstChild("Muzzle")
check(muzzle ~= nil and muzzle.Transparency == 1 and muzzle:FindFirstChild("MuzzlePoint") ~= nil
	and muzzle:FindFirstChild("Flash") ~= nil, "a hidden muzzle marker with its point and light")
local named = {}
for _, n in ipairs({ "Barrel", "Magazine", "Rail", "LowerHandguard", "Grip", "ChargingHandle", "Stock" }) do
	if not tool:FindFirstChild(n) then
		table.insert(named, n)
	end
end
check(#named == 0, "the parts the game finds by name are there (" .. (#named == 0 and "all" or table.concat(named, ", ") .. " missing") .. ")")

local unwelded, physics, total = 0, 0, 0
local minZ, maxZ = math.huge, -math.huge
local frontGun = math.huge
for _, p in ipairs(tool:GetDescendants()) do
	if p:IsA("BasePart") and p ~= handle then
		total += 1
		if p.CanCollide or p.CanQuery or p.CanTouch or not p.Massless or p.Anchored then
			physics += 1
		end
		local rel = handle.CFrame:ToObjectSpace(p.CFrame)
		local reach = 0.5 * (math.abs(rel.ZVector.Z) * p.Size.Z + math.abs(rel.YVector.Z) * p.Size.Y
			+ math.abs(rel.XVector.Z) * p.Size.X)
		if p ~= muzzle and p:GetAttribute("DMRole") == nil then
			minZ = math.min(minZ, rel.Position.Z - reach)
			maxZ = math.max(maxZ, rel.Position.Z + reach)
			local g = p:GetAttribute("DMGroup")
			if g ~= "DarkMatterCrystals" and g ~= "DarkMatterEnergy" and g ~= "DarkMatterShimmer" then
				frontGun = math.min(frontGun, rel.Position.Z - reach)
			end
		end
	end
end
-- Welds are checked on the place file itself: the harness does not carry a WeldConstraint's
-- Part0/Part1 references across.
local rawStore = place:GetService("ReplicatedStorage"):FindFirstChild("storeitems")
local rawTool = rawStore:FindFirstChild("Warden_DarkMatter")
local rawHandle = rawTool:FindFirstChild("Handle")
for _, p in ipairs(rawTool:GetDescendants()) do
	if p:IsA("BasePart") and p ~= rawHandle then
		local w = p:FindFirstChildOfClass("WeldConstraint")
		if not w or w.Part0 ~= rawHandle or w.Part1 ~= p then
			unwelded += 1
		end
	end
end
check(unwelded == 0, ("every one of %d parts welded to the Handle"):format(total))
-- Saved the way Studio saves a live weld (State 1: hold the parts where they are). A weld
-- left in State 3 loads at its stored offset -- none -- and the whole gun piles onto the
-- Handle in game. Every weapon is checked, the imported ones being the reference.
local stateOff = {}
for _, t in ipairs(rawStore:GetChildren()) do
	for _, w in ipairs(t:GetDescendants()) do
		if w:IsA("WeldConstraint") and w.Part0 and w.Part1 and w.State ~= 1 then
			stateOff[t.Name] = (stateOff[t.Name] or 0) + 1
		end
	end
end
local offList = {}
for n, c in pairs(stateOff) do
	table.insert(offList, ("%s x%d"):format(n, c))
end
check(#offList == 0, "every weapon's welds hold its parts where they were built ("
	.. (#offList == 0 and "all State 1" or table.concat(offList, ", ")) .. ")")
check(physics == 0, "none collides, blocks a raycast, touches or weighs anything")
check(total > 400 and total < 900, ("a real rebuild, and not an absurd one (%d parts)"):format(total))
local length = maxZ - minZ
check(math.abs(length - 4.2) < 0.4, ("rifle length, like the Warden (%.2f studs)"):format(length))
local mz = handle.CFrame:PointToObjectSpace(muzzle.Position)
check(mz.Z < frontGun and frontGun - mz.Z < 0.2, ("the muzzle marker is just past the front (%.2f vs %.2f)"):format(mz.Z, frontGun))
local barrel = tool:FindFirstChild("Barrel")
local bore = handle.CFrame:VectorToObjectSpace((muzzle.Position - barrel.Position).Unit)
check(bore.Z < -0.98, ("and on the bore line, down -Z (%.2f, %.2f, %.2f)"):format(bore.X, bore.Y, bore.Z))
local flash = 0
for _, d in ipairs(tool:GetDescendants()) do
	if d:IsA("BasePart") and d:GetAttribute("DMRole") == "MuzzleFlash" then
		flash += 1
	end
end
check(flash == 4, ("the Dark Matter carbine's authored flash rides on it (%d pieces)"):format(flash))

print("the reload")
local mags, names, dupes = 0, {}, 0
for _, p in ipairs(tool:GetChildren()) do
	if p:IsA("BasePart") and p:GetAttribute("MagPart") == true then
		mags += 1
		if names[p.Name] then
			dupes += 1
		end
		names[p.Name] = true
	end
end
check(mags >= 40, ("the magazine is tagged for the reload (%d pieces, crystals included)"):format(mags))
check(dupes == 0, "every piece has its own name, so the reload can find each one")
local magwellTagged = false
for _, p in ipairs(tool:GetChildren()) do
	if p:IsA("BasePart") and p.Name:match("^Magwell") and p:GetAttribute("MagPart") == true then
		magwellTagged = true
	end
end
check(not magwellTagged, "the magwell's crystals stay on the gun")

-- ------------------------------------------------------------------ the config --

print("the variant")
local cfg = WeaponConfig.Get("Warden_DarkMatter")
local warden = WeaponConfig.Get("Warden")
check(cfg ~= nil and WeaponConfig.VariantOf("Warden_DarkMatter") ~= nil, "a Mastery Weapon")
local same = true
for _, key in ipairs({ "FireRate", "MagazineSize", "ReloadTime", "Range", "SpreadMin", "Class", "Hold" }) do
	if cfg[key] ~= warden[key] then
		same = false
		print("    differs: " .. key)
	end
end
check(same, "it handles exactly like the Warden")
check(cfg.Damage >= warden.Damage * 1.3, ("and hits a third harder (%d a round, the Warden %d)"):format(cfg.Damage, warden.Damage))
local carbineDM, carbine = WeaponConfig.Get("Carbine_DarkMatter"), WeaponConfig.Get("Carbine")
check(carbineDM and carbineDM.Damage > carbine.Damage, ("the Carbine's too (%d over %d)"):format(carbineDM and carbineDM.Damage or 0, carbine.Damage))
check(WeaponConfig.DamageText(WeaponConfig.VariantOf("Warden_DarkMatter")) == "+33% DAMAGE", "and the card says by how much")
check(cfg.Rarity == "Mythic" and cfg.DisplayName == "Warden - Dark Matter", "Mythic, and named for what it is")
check(cfg.HeadshotVFX == "gemstoneCharge" and cfg.TracerColor ~= warden.TracerColor, "its own Dark Matter shots")
check(WeaponConfig.HasModel == nil or WeaponConfig.HasModel("Warden_DarkMatter"), "the armory and inventory can show it")
local earn = WeaponConfig.EarnText(WeaponConfig.VariantOf("Warden_DarkMatter"))
check(earn == "Earn at Gold mastery: 250 Warden kills", ("the market says how it is earned (%q)"):format(tostring(earn)))

-- ------------------------------------------------------------------- earning it --

print("earning it")
local profile = {
	Level = 30, EXP = 0, MaxEXP = 100, Coins = 0, CoinsMigrated = true, Crystals = 0, Titles = {},
	OwnedItems = { "Warden" }, OwnedVariants = {}, Reputation = {}, MasteryAwarded = {}, WeaponKills = {},
	AttachmentsMigrated = true, Loadout = {},
}
local stub = R.new("ModuleScript")
stub.Name = "PlayerDataManager"
stub.Source = [[
local data = {}
local Replica = { Data = data }
function Replica:SetValue(key, value) data[key] = value end
function Replica:ListenToChange() end
function Replica:IsActive() return true end
local function promise()
	local p = {}
	function p:andThen(fn) pcall(fn, Replica) return { catch = function() end } end
	function p:expect() return Replica end
	return p
end
local PDM = { Replica = Replica }
function PDM.Bind(profile) data = profile Replica.Data = profile end
function PDM:GetPlayerDataReplica() return promise() end
function PDM:SaveNow() return true end
function PDM:IsSaving() return true end
return PDM
]]
stub.Parent = sss
local PDM = World.require(stub)
PDM.Bind(profile)
R.ClassMethods.RemoteEvent.FireClient = function() end
R.ClassMethods.RemoteEvent.FireAllClients = function() end
for _, name in ipairs({ "KillCredit", "ReputationService", "AbilityService", "ShopService", "StatsService" }) do
	R.mirror(place:GetService("ServerScriptService"):FindFirstChild(name), sss)
end
local ShopService = World.require(sss.ShopService)
local StatsService = World.require(sss.StatsService)

local refused = ShopService.EquipWeapon(player, "Warden_DarkMatter")
check(refused.ok == false and refused.reason == "You do not own that", "not yours before it is earned")
StatsService.CheckMastery(player, PDM.Replica, "Warden", 99, 100)
check(table.find(profile.OwnedVariants, "Warden_DarkMatter") == nil, "Silver with the Warden is not enough")
StatsService.CheckMastery(player, PDM.Replica, "Warden", 249, 250)
check(table.find(profile.OwnedVariants, "Warden_DarkMatter") ~= nil, "Gold with the Warden earns it")
check(table.find(profile.OwnedVariants, "Carbine_DarkMatter") == nil, "and nothing else")
local owned = ShopService.GetOwnership(player)
check(table.find(owned.OwnedItems, "Warden_DarkMatter") ~= nil, "it is among your guns")
local equipped = ShopService.EquipWeapon(player, "Warden_DarkMatter")
check(equipped.reason ~= "You do not own that", ("and it can be equipped (%s)"):format(tostring(equipped.reason)))

print("")
if failures == 0 then
	print("\27[32mall mastery checks passed\27[0m")
	require("@lune/process").exit(0)
else
	print(("\27[31m%d mastery check(s) failed\27[0m"):format(failures))
	require("@lune/process").exit(1)
end
