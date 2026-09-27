--!nocheck
-- The authored Dark Matter attachments, checked without Studio:
--
--   * the catalogue is the twelve GLB attachments and nothing else -- six slots (a side rail
--     for the laser and light, no charms), every one priced, statted and modelled for the
--     Dark Matter carbine; the retired ones are listed for refunds; old loadouts normalise;
--   * fitting one onto the real Carbine_DarkMatter puts every piece exactly where the model
--     says, hides the stock parts it replaces, moves the muzzle out to the end of a muzzle
--     device, makes the extended mag the one the reload takes -- and Clear undoes all of it;
--   * guns nothing is modelled for take nothing, and are left untouched;
--   * the shop sells only what exists, the laser bought under the barrel still counts,
--     a pre-change profile is migrated once (moved, refunded, builds rewritten), and a
--     Mastery Weapon can be granted and counts as an owned weapon;
--   * the market has no attachment shelf any more.
--
--   lune run tools/uitest/attachments.luau

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

local AttachmentConfig = World.require(rs.AttachmentConfig)
local AttachmentModels = World.require(rs.AttachmentModels)
local AttachmentBuilder = World.require(rs.AttachmentBuilder)
local WeaponConfig = World.require(rs.WeaponConfig)
local ProgressionConfig = World.require(rs.ProgressionConfig)

-- --------------------------------------------------------------- catalogue --

print("the catalogue")
local slots = table.concat(AttachmentConfig.Slots, ",")
check(slots == "Sight,Muzzle,Underbarrel,Side,Magazine,Stock", "six slots, a side rail and no charms: " .. slots)
check(AttachmentConfig.Options.Charm == nil and AttachmentConfig.Pricing.Charm == nil, "charms are gone")

local SOURCES = {
	"Optic_RedDot.glb", "Optic_Holographic.glb", "Optic_Scope4x.glb", "Muzzle_Compensator.glb",
	"Muzzle_Suppressor.glb", "Under_VerticalGrip.glb", "Under_AngledGrip.glb", "Under_Bipod.glb",
	"Side_Laser.glb", "Side_Light.glb", "Mag_Extended.glb", "Stock_Skeleton.glb",
}
local sold, modelled, sources = 0, 0, {}
local everyPriced, everyModelled, stockFree = true, true, true
for _, slot in ipairs(AttachmentConfig.Slots) do
	local options = AttachmentConfig.Options[slot]
	if AttachmentConfig.Price(slot, options[1].id) ~= 0 then
		stockFree = false
	end
	for _, option in ipairs(options) do
		if not AttachmentConfig.IsStock(slot, option.id) then
			sold += 1
			if AttachmentConfig.Price(slot, option.id) <= 0 then
				everyPriced = false
			end
			local fitted = AttachmentModels.Get("Carbine_DarkMatter", slot, option.id)
			if fitted and #fitted.parts > 0 then
				modelled += 1
				sources[fitted.source] = true
			else
				everyModelled = false
				print("    no model for " .. slot .. ":" .. option.id)
			end
		end
	end
end
check(sold == 12, "twelve attachments for sale (" .. sold .. ")")
check(everyPriced and stockFree, "every one priced; every stock part free")
check(everyModelled and modelled == 12, "every one modelled for the Dark Matter carbine")
local allSources = true
for _, name in ipairs(SOURCES) do
	allSources = allSources and sources[name] == true
end
check(allSources, "one model per uploaded GLB, all twelve")

local retiredGone = true
for key in pairs(AttachmentConfig.Retired) do
	local slot, id = key:match("^(%a+):(%w+)$")
	if AttachmentConfig.Find(slot, id) then
		retiredGone = false
	end
end
check(retiredGone, "nothing retired is still for sale")
check(AttachmentConfig.Retired["Sight:Sniper"] == 5000 and AttachmentConfig.Retired["Charm:Skull"] == 1600,
	"a retired attachment remembers what it sold for")

local n = AttachmentConfig.Normalise({ Underbarrel = "Laser", Sight = "Sniper", Muzzle = "Suppressor", Charm = "Dice" })
check(n.Side == "Laser" and n.Underbarrel == nil and n.Sight == nil and n.Muzzle == "Suppressor" and n.Charm == nil,
	"an old loadout: the laser moves to the side rail, retired ids drop")
local both = AttachmentConfig.Normalise({ Underbarrel = "Foregrip", Side = "Light" })
check(both.Underbarrel == "Foregrip" and both.Side == "Light", "a grip and a light can be run together")

local base = WeaponConfig.Get("Carbine_DarkMatter")
local tuned = WeaponConfig.WithAttachments(base, { Magazine = "Extended", Side = "Laser" })
check(tuned.MagazineSize == base.MagazineSize + 10, "the extended mag holds ten more")
check(tuned.SpreadMin < base.SpreadMin, "the laser tightens hip fire")

local milestonesReal = true
for level, reward in pairs(ProgressionConfig.Milestones) do
	if reward.attachment then
		local slot, id = reward.attachment:match("^(%a+):(%w+)$")
		if not (slot and AttachmentConfig.Find(slot, id)) then
			milestonesReal = false
			print("    level " .. level .. " pays " .. reward.attachment)
		end
	end
end
check(milestonesReal, "every level reward names an attachment that exists")

-- ----------------------------------------------------------------- fitting --

print("fitting them to the Dark Matter carbine")
local store = rs:FindFirstChild("storeitems")
local template = store:FindFirstChild("Carbine_DarkMatter")
check(template ~= nil, "the carbine is in storeitems")

local tool = template:Clone()
tool.Parent = World.workspace
local handle = tool:FindFirstChild("Handle")
local supportsAll = true
for _, slot in ipairs(AttachmentConfig.Slots) do
	supportsAll = supportsAll and AttachmentBuilder.Supports(tool, slot)
end
check(supportsAll, "it takes every slot")

local function rel(part)
	return handle.CFrame:ToObjectSpace(part.CFrame)
end
local function snapshot()
	local out = {}
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") then
			out[d] = { t = d.Transparency, cf = rel(d), mag = d:GetAttribute("MagPart") }
		end
	end
	return out
end
local before = snapshot()
local muzzle = tool:FindFirstChild("Muzzle")
local muzzleBefore = rel(muzzle)
local flashes = {}
for _, d in ipairs(tool:GetDescendants()) do
	if d:IsA("BasePart") and d:GetAttribute("DMRole") == "MuzzleFlash" then
		table.insert(flashes, d)
	end
end

local FULL = { Sight = "Scope4x", Muzzle = "Suppressor", Underbarrel = "Bipod", Side = "Laser",
	Magazine = "Extended", Stock = "Skeleton" }
local expected = 0
for slot, id in pairs(FULL) do
	expected += #AttachmentModels.Get("Carbine_DarkMatter", slot, id).parts
end
local added = AttachmentBuilder.Apply(tool, FULL)
check(added == expected, ("every piece fitted (%d of %d)"):format(added, expected))

-- Every piece at its modelled place and size.
local worst, missing = 0, 0
for slot, id in pairs(FULL) do
	local fitted = AttachmentModels.Get("Carbine_DarkMatter", slot, id)
	for _, piece in ipairs(fitted.parts) do
		local found = nil
		for _, d in ipairs(tool:GetDescendants()) do
			if d:IsA("BasePart") and d:GetAttribute("AttachmentId") == id and d:GetAttribute("AttachmentSlot") == slot
				and d.Name == piece.name and (d.Size - piece.size).Magnitude < 1e-4 then
				local err = (rel(d).Position - piece.cf.Position).Magnitude
				if not found or err < found then
					found = err
				end
			end
		end
		if found then
			worst = math.max(worst, found)
		else
			missing += 1
		end
	end
end
check(missing == 0 and worst < 1e-3, ("each piece where the model puts it (worst %.5f studs, %d missing)"):format(worst, missing))

local hiddenOk = true
for slot, id in pairs(FULL) do
	for _, name in ipairs(AttachmentModels.Get("Carbine_DarkMatter", slot, id).hides) do
		local part = tool:FindFirstChild(name, true)
		if not part or part.Transparency ~= 1 then
			hiddenOk = false
			print("    not hidden: " .. name)
		end
	end
end
check(hiddenOk, "the irons, brake, standard mag and stock they replace are hidden")

-- The reload collects the Tool's direct children tagged MagPart: the extended mag's pieces,
-- plus the crystals grown on the magazine (they ride on it), and none of the hidden
-- standard magazine.
local extendedCount, crystalCount, hiddenTaken = 0, 0, 0
for _, p in ipairs(tool:GetChildren()) do
	if p:IsA("BasePart") and p:GetAttribute("MagPart") == true then
		if p:GetAttribute("AttachmentId") == "Extended" then
			extendedCount += 1
		elseif p.Transparency >= 1 then
			hiddenTaken += 1
		elseif p:GetAttribute("DMGroup") == "DarkMatterCrystals" then
			crystalCount += 1
		else
			hiddenTaken += 1
			print("    still tagged: " .. p.Name)
		end
	end
end
check(extendedCount == #AttachmentModels.Get("Carbine_DarkMatter", "Magazine", "Extended").parts and hiddenTaken == 0,
	("the reload takes out the extended mag (%d parts, with its %d crystals), not the hidden standard one")
		:format(extendedCount, crystalCount))

local shift = AttachmentModels.Get("Carbine_DarkMatter", "Muzzle", "Suppressor").shift
local moved = rel(muzzle).Position - muzzleBefore.Position
check(math.abs(moved.Z - shift) < 1e-3 and math.abs(moved.X) < 1e-4 and math.abs(moved.Y) < 1e-4,
	("the muzzle moves out to the end of the suppressor (%.3f, wanted %.3f)"):format(moved.Z, shift))
local flashMoved = #flashes > 0
for _, f in ipairs(flashes) do
	local d = rel(f).Position - before[f].cf.Position
	flashMoved = flashMoved and math.abs(d.Z - shift) < 1e-3
end
check(flashMoved, "and the authored flash goes with it (" .. #flashes .. " pieces)")

-- Swapping one device for another does not stack the moves.
AttachmentBuilder.Apply(tool, { Muzzle = "Compensator" })
local comp = AttachmentModels.Get("Carbine_DarkMatter", "Muzzle", "Compensator").shift
local now = rel(muzzle).Position - muzzleBefore.Position
check(math.abs(now.Z - comp) < 1e-3, ("swapping to the compensator moves it to %.3f, not further (%.3f)"):format(comp, now.Z))
check(tool:FindFirstChild("FrontSightPost", true).Transparency == before[tool:FindFirstChild("FrontSightPost", true)].t,
	"and the irons come back when the optic comes off")

AttachmentBuilder.Clear(tool)
local restored, leftovers = true, 0
for part, was in pairs(before) do
	if part.Parent == nil then
		restored = false
	elseif part.Transparency ~= was.t or part:GetAttribute("MagPart") ~= was.mag
		or (rel(part).Position - was.cf.Position).Magnitude > 1e-4 then
		restored = false
		print("    not restored: " .. part.Name)
	end
end
for _, d in ipairs(tool:GetDescendants()) do
	if d:GetAttribute("AttachmentPart") == true then
		leftovers += 1
	end
end
check(restored and leftovers == 0 and tool:FindFirstChild("Attachments") == nil,
	"Clear puts the carbine back exactly as it was")

print("guns nothing is made for")
local others, untouched = 0, true
for _, t in ipairs(store:GetChildren()) do
	if t:IsA("Tool") and t.Name ~= "Carbine_DarkMatter" then
		others += 1
		if AttachmentBuilder.SupportsAny(t) then
			untouched = false
			print("    " .. t.Name .. " claims a slot")
		end
	end
end
local warden = store:FindFirstChild("Warden"):Clone()
local partsBefore = #warden:GetDescendants()
check(AttachmentBuilder.Apply(warden, FULL) == 0 and #warden:GetDescendants() == partsBefore,
	"fitting the set to the Warden adds nothing")
check(untouched and others > 5, ("no other gun (%d) offers a slot"):format(others))

-- ------------------------------------------------------------------ server --

print("buying, owning and the migration")
local profile = {
	Level = 20, EXP = 0, MaxEXP = 100, Coins = 20000, CoinsMigrated = true, Crystals = 0,
	OwnedItems = {}, Reputation = {}, OwnedVariants = {},
	OwnedAttachments = { "Underbarrel:Laser", "Charm:Skull", "Sight:Sniper", "Sight:RedDot", "Magazine:Drum" },
	WeaponBuilds = { Carbine_DarkMatter = { { id = "b1", name = "OLD",
		attachments = { Underbarrel = "Laser", Sight = "Sniper", Muzzle = "Suppressor" } } } },
	WeaponAttachments = { Redwood = { Magazine = "Drum", Sight = "RedDot" } },
	AttachmentsMigrated = false,
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
local PDM = {}
function PDM.Bind(profile) data = profile Replica.Data = profile end
function PDM:GetPlayerDataReplica() return promise() end
function PDM:SaveNow() return true end
function PDM:IsSaving() return true end
return PDM
]]
stub.Parent = sss
World.require(stub).Bind(profile)

R.ClassMethods.RemoteEvent.FireClient = function() end
R.ClassMethods.RemoteEvent.FireAllClients = function() end

local coins = player:FindFirstChild("leaderstats"):FindFirstChild("Coins")
coins.Value = 20000
for _, name in ipairs({ "WalletService", "ReputationService", "ShopService" }) do
	R.mirror(place:GetService("ServerScriptService"):FindFirstChild(name), sss)
end
local ShopService = World.require(sss.ShopService)
World.require(sss.WalletService)
World.advance(1.5)

local owned = table.concat(profile.OwnedAttachments, ",")
check(profile.AttachmentsMigrated == true, "the profile is migrated on join")
check(owned == "Side:Laser,Sight:RedDot", "the laser moves to the side rail; the retired ones go: " .. owned)
check(coins.Value == 20000 + 1600 + 5000 + 3000, ("and are refunded at what they sold for (%d)"):format(coins.Value))
local build = profile.WeaponBuilds.Carbine_DarkMatter[1]
check(build.attachments.Side == "Laser" and build.attachments.Sight == nil and build.attachments.Muzzle == "Suppressor",
	"a saved build follows: laser on the side, the sniper scope gone, the suppressor kept")
check(profile.WeaponAttachments.Redwood.Magazine == nil and profile.WeaponAttachments.Redwood.Sight == "RedDot",
	"per-weapon loadouts are pruned the same way")
local again1, again2 = ShopService.MigrateAttachments(player)
check(again1 == 0 and again2 == 0 and coins.Value == 29600, "and it only ever happens once")

local paid = coins.Value
local r1 = ShopService.AttemptPurchase(player, "attachment", "Side:Light")
World.advance(0.2)
check(r1.ok == true and table.find(profile.OwnedAttachments, "Side:Light") ~= nil
	and coins.Value == paid - AttachmentConfig.Price("Side", "Light"),
	"buying the flashlight charges its price and records it")
local r2 = ShopService.AttemptPurchase(player, "attachment", "Charm:Skull")
World.advance(0.2)
local r3 = ShopService.AttemptPurchase(player, "attachment", "Sight:Sniper")
World.advance(0.2)
check(r2.ok == false and r3.ok == false, "a retired attachment cannot be bought")

profile.OwnedAttachments = { "Underbarrel:Laser" }
check(ShopService.OwnsAttachment(player, "Side", "Laser"), "a laser recorded under the barrel still counts as owned")
check(not ShopService.OwnsAttachment(player, "Side", "Light"), "and owning it does not give you the light")

check(ShopService.Grant(player, "OwnedVariants", "Carbine_DarkMatter"), "a Mastery Weapon can be granted")
local ownership = ShopService.GetOwnership(player)
check(table.find(ownership.OwnedVariants, "Carbine_DarkMatter") ~= nil
	and table.find(ownership.OwnedItems, "Carbine_DarkMatter") ~= nil,
	"and is owned: in OwnedVariants for the market, among the guns for the armory")

-- ------------------------------------------------------------------ market --

print("the market")
local marketSource = place:GetService("ReplicatedStorage"):FindFirstChild("UI"):FindFirstChild("Modules")
	:FindFirstChild("Market").Source
check(not marketSource:find('id = "Attachments"', 1, true) and not marketSource:find("PurchaseAttachment", 1, true),
	"there is no attachment shelf")

print("")
if failures == 0 then
	print("\27[32mall attachment checks passed\27[0m")
	require("@lune/process").exit(0)
else
	print(("\27[31m%d attachment check(s) failed\27[0m"):format(failures))
	require("@lune/process").exit(1)
end
