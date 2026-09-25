--!strict
-- Saved weapon builds, per player.
--
-- A build is a name, a set of attachment ids and a camo id -- nothing else. No instances
-- are stored, so the whole thing is a few hundred bytes per player and a weapon can be
-- rebuilt from it at any time. Adding a weapon or an attachment needs no change here.
--
-- The DEFAULT weapon is not a build. It is the absence of one: with no build equipped the
-- template is cloned untouched. That is what makes "default stays default" true by
-- construction rather than by remembering to copy things -- there is nothing to overwrite.
-- Each build is its own record, so editing one cannot reach another.
--
-- This is per player and lives on their profile. It is separate from WeaponSkinService,
-- which is the owner's game-wide default look for a weapon and applies to the template.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local WeaponConfig = require(ReplicatedStorage.WeaponConfig)
local AttachmentConfig = require(ReplicatedStorage.AttachmentConfig)
local AttachmentBuilder = require(ReplicatedStorage.AttachmentBuilder)
local CamoConfig = require(ReplicatedStorage.CamoConfig)
local WeaponFinish = require(ReplicatedStorage.WeaponFinish)
local WeaponMounts = require(ReplicatedStorage.WeaponMounts)
local WeaponAudio = require(ReplicatedStorage.WeaponAudio)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local KillCredit = require(ServerScriptService.KillCredit)
local ShopService = require(ServerScriptService.ShopService)

local WeaponBuildService = {}

-- Stamp the authored mount points onto every weapon template that has them, once, at
-- startup. Done on the server so the Attachments replicate and the customisation preview
-- on the client lines up with the weapon the server actually builds.
--
-- Templates only. The live copies clone from these, so this never has to run again.
do
	local placed, weapons = 0, 0
	for _, tool in ipairs(ReplicatedStorage.storeitems:GetChildren()) do
		if tool:IsA("Tool") and WeaponMounts.Data[tool.Name] then
			local n = WeaponMounts.Place(tool, tool.Name)
			if n > 0 then
				placed += n
				weapons += 1
			end
		end
	end
	if weapons > 0 then
		print(string.format("[WeaponMounts] %d authored mount points placed across %d weapons",
			placed, weapons))
	end
end

-- Same idea for audio: give every template the fire and reload sound its class calls for.
-- The sounds are already baked into the templates, so this is really here so that a
-- weapon added later is never left on the wrong sample -- or on none at all, which is how
-- every gun in the place ended up sharing one.
do
	local tuned = 0
	for _, tool in ipairs(ReplicatedStorage.storeitems:GetChildren()) do
		if tool:IsA("Tool") and WeaponAudio.Apply(tool, WeaponConfig.Get(tool.Name)) then
			tuned += 1
		end
	end
	print(string.format("[WeaponAudio] %d weapon templates given class-appropriate sound", tuned))
end

local MAX_BUILDS_PER_WEAPON = 8
local MAX_NAME = 24

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local BuildAction = Remotes:FindFirstChild("BuildAction")
if not BuildAction then
	BuildAction = Instance.new("RemoteFunction")
	BuildAction.Name = "BuildAction"
	BuildAction.Parent = Remotes
end

-- ------------------------------------------------------------------ storage --

local function replicaOf(player: Player)
	local ok, replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
	end)
	return ok and replica or nil
end

-- { [weaponName] = { {id=, name=, attachments={}, camo=, createdAt=, updatedAt=}, ... } }
local function buildsOf(player: Player): { [string]: any }
	local replica = replicaOf(player)
	local data = replica and replica.Data.WeaponBuilds
	return type(data) == "table" and data or {}
end

local function equippedOf(player: Player): { [string]: string }
	local replica = replicaOf(player)
	local data = replica and replica.Data.EquippedBuild
	return type(data) == "table" and data or {}
end

local function commit(player: Player, builds, equipped): boolean
	local replica = replicaOf(player)
	if not replica then
		return false
	end
	-- Never write nil over good data: a failed read leaves the profile alone.
	if builds then replica:SetValue("WeaponBuilds", builds) end
	if equipped then replica:SetValue("EquippedBuild", equipped) end
	return true
end

-- ---------------------------------------------------------------- validation --

-- Only ids the catalogue actually holds survive. A forged or stale loadout cannot put
-- anything unexpected on a weapon, and cannot name an attachment the player has not got.
local function cleanAttachments(player: Player, weaponName: string, incoming): { [string]: string }
	local clean = {}
	if type(incoming) ~= "table" then
		return clean
	end
	local template = ReplicatedStorage.storeitems:FindFirstChild(weaponName)
	for _, slot in ipairs(AttachmentConfig.Slots) do
		local id = incoming[slot]
		-- Three things have to hold. It must exist in the catalogue; the player must own it
		-- -- editing a LocalScript to name an attachment you have not bought gets you
		-- nothing, it is dropped here on the server before it reaches a saved build; and
		-- the weapon must have somewhere to put it, so a build cannot record a stock for a
		-- pistol and carry it in the save forever doing nothing.
		if type(id) == "string" and AttachmentConfig.Find(slot, id)
			and ShopService.OwnsAttachment(player, slot, id)
			and (not template or AttachmentBuilder.Supports(template, slot)) then
			clean[slot] = id
		end
	end
	return clean
end

local function cleanCamo(player: Player, id): string?
	if type(id) == "string" and CamoConfig.Find(id) and ShopService.OwnsCamo(player, id) then
		return id
	end
	return nil
end

local function cleanName(name, fallback: string): string
	if type(name) ~= "string" then
		return fallback
	end
	name = name:gsub("[%c]", ""):sub(1, MAX_NAME)
	name = name:match("^%s*(.-)%s*$") or ""
	return #name > 0 and name or fallback
end

local function findBuild(list, buildId)
	for index, build in ipairs(list) do
		if build.id == buildId then
			return build, index
		end
	end
	return nil, nil
end

local nextId = 0
local function makeId(): string
	nextId += 1
	return string.format("b%d_%d", os.time() % 100000, nextId)
end

-- ------------------------------------------------------------------ applying --

-- Write the build's stats onto the weapon itself.
--
-- This is what stops the workshop's numbers being decoration. The bars, the damage the
-- server deals and the recoil the client draws all read WeaponConfig.For(tool), which
-- prefers these attributes -- so an extended magazine really does hold ten more rounds
-- and a suppressor really does cost range.
--
-- Only ever written on the server. A client setting Stat_Damage on its own copy changes
-- nothing, because the server reads its own.
local function stampStats(tool: Instance, loadout)
	local cfg = WeaponConfig.Get(tool.Name)
	if not cfg then
		return
	end
	local tuned = WeaponConfig.WithAttachments(cfg, loadout)
	for _, row in ipairs(WeaponConfig.TunableStats) do
		local base, value = cfg[row.key], tuned and tuned[row.key]
		-- Only stamp what actually differs, and clear anything left over from a build the
		-- player has since switched away from.
		if type(value) == "number" and type(base) == "number" and math.abs(value - base) > 1e-6 then
			tool:SetAttribute("Stat_" .. row.key, value)
		else
			tool:SetAttribute("Stat_" .. row.key, nil)
		end
	end

	-- What is actually bolted on, by slot. Stats alone cannot answer "is this suppressed?",
	-- and guessing from part names inside the built model is fragile. Server-written, so it
	-- is safe for anything to read -- the noise a shot makes is decided from this.
	for _, slot in ipairs(AttachmentConfig.Slots) do
		local id = loadout and loadout[slot]
		tool:SetAttribute("Att_" .. slot, type(id) == "string" and id or nil)
	end
end

-- Fit a build onto a live weapon. Used on equip, and again whenever a reactive camo's
-- streak changes.
function WeaponBuildService.Dress(tool: Instance, build, streak: number?)
	if not build then
		-- DEFAULT: strip anything a previous build left on the weapon, stats included.
		stampStats(tool, nil)
	else
		AttachmentBuilder.Apply(tool, build.attachments)
		stampStats(tool, build.attachments)
		if build.camo then
			CamoConfig.Apply(tool, build.camo, streak)
		end
	end

	-- A Mastery Weapon wears its own finish whether or not a build is on it. That is the
	-- difference between a variant and the camos it replaced: the look belongs to the weapon,
	-- not to a loadout, so it cannot be taken off by switching to DEFAULT.
	local variant = WeaponConfig.VariantOf(tool.Name)
	if variant and variant.finish then
		WeaponFinish.Apply(tool, variant.finish, 1)
	end
end

-- ---------------------------------------------------------------- variants --
--
-- A Mastery Weapon is published as its own Tool, cloned from the weapon it is a variant of
-- and painted with its finish.
--
-- No mesh is imported and nothing is uploaded, because there is nothing new to upload: the
-- Dark Matter export is the same 132 parts as the base Carbine with its materials repainted,
-- which is what the whole WeaponFinish system exists to express. Cloning also means a variant
-- inherits every mount point, weld, sound and magazine tag the base already has, so it cannot
-- drift from the gun it came from.
-- What a crystal is made of. Colours are the authored materials converted from the export's
-- linear space to sRGB; the material is chosen for how each one should read -- deep crystal
-- is solid, mid catches light, bright and the energy veins are genuinely lit.
local CRYSTAL = {
	CrystalDeep   = { colour = Color3.fromRGB(22, 18, 58),    material = Enum.Material.SmoothPlastic, reflect = 0.25 },
	CrystalMid    = { colour = Color3.fromRGB(58, 35, 133),   material = Enum.Material.Glass,         reflect = 0.35 },
	CrystalBright = { colour = Color3.fromRGB(122, 73, 232),  material = Enum.Material.Neon,          reflect = 0.00 },
	Energy        = { colour = Color3.fromRGB(164, 52, 234),  material = Enum.Material.Neon,          reflect = 0.00 },
}

--- Grow the crystals onto a variant.
--
-- Rows are handle-local and already scaled, so this only has to place and weld them. Every
-- piece is non-colliding, non-query and massless: crystals must not stop a bullet, catch a
-- raycast or change how the weapon handles. They are decoration with no say in the game.
local function growOverlay(tool: Tool, moduleName: string): number
	local folder = ReplicatedStorage:FindFirstChild("WeaponParts")
	local source = folder and folder:FindFirstChild(moduleName)
	if not source then
		warn("[Variants] overlay module missing: " .. moduleName)
		return 0
	end
	local ok, rows = pcall(require, source)
	if not ok or type(rows) ~= "table" then
		warn("[Variants] overlay module would not load: " .. moduleName)
		return 0
	end
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		warn("[Variants] " .. tool.Name .. " has no Handle to grow crystals from")
		return 0
	end

	local grown = 0
	for _, row in ipairs(rows) do
		local name, kind, tint = row[1], row[2], row[3]
		local look = CRYSTAL[tint]
		if look then
			local part = Instance.new(kind == "Wedge" and "WedgePart" or "Part")
			part.Name = name
			part.Size = Vector3.new(row[4], row[5], row[6])
			part.CFrame = handle.CFrame * CFrame.new(
				row[7], row[8], row[9],
				row[10], row[11], row[12], row[13], row[14], row[15], row[16], row[17], row[18])
			part.Color = look.colour
			part.Material = look.material
			part.Reflectance = look.reflect
			part.CanCollide = false
			part.CanQuery = false
			part.CanTouch = false
			part.Massless = true
			part.CastShadow = false
			part.TopSurface = Enum.SurfaceType.Smooth
			part.BottomSurface = Enum.SurfaceType.Smooth
			-- Marked so the finish system leaves them alone: a crystal is not one of the eight
			-- stock materials and must not be repainted as if it were.
			part:SetAttribute("Crystal", tint)
			part.Parent = tool
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = part
			weld.Parent = part
			grown += 1
		end
	end
	return grown
end

local function publishVariants()
	local store = ReplicatedStorage:FindFirstChild("storeitems")
	if not store then
		return 0
	end
	local made = 0
	for _, variant in ipairs(WeaponConfig.Variants or {}) do
		if not store:FindFirstChild(variant.id) then
			local source = store:FindFirstChild(variant.model or variant.base)
			if source and source:IsA("Tool") then
				local copy = source:Clone()
				copy.Name = variant.id
				if variant.finish then
					-- Stamp what each part is MADE of before painting it.
					--
					-- WeaponFinish.Apply repaints from a part's "Finish" attribute and nothing
					-- else. Weapons built by WeaponBuilder get that attribute stamped as they
					-- are built, but a weapon that came through Roblox's 3D importer -- the
					-- Carbine is the only one -- has none at all, so Apply silently painted
					-- zero parts and the variant came out identical to the base.
					--
					-- Classify recovers it from the exported colour, which is what it is for.
					-- Stamped on the CLONE only: the base weapon is left exactly as it was.
					local unknown = 0
					for _, part in ipairs(copy:GetDescendants()) do
						if part:IsA("BasePart") and part:GetAttribute("Finish") == nil then
							local material = WeaponFinish.Classify(part)
							if material then
								part:SetAttribute("Finish", material)
							else
								unknown += 1
							end
						end
					end
					if unknown > 0 then
						warn(("[Variants] %s: %d part(s) had no recognisable stock colour and keep "
							.. "their own"):format(variant.id, unknown))
					end
					WeaponFinish.Apply(copy, variant.finish, 1)
				end
				if variant.overlay then
					local grown = growOverlay(copy, variant.overlay)
					if grown > 0 then
						print(("[Variants] %s grew %d crystals"):format(variant.id, grown))
					end
				end
				copy.Parent = store
				made += 1
			else
				warn(("[Variants] %s has no source weapon to clone: %s")
					:format(variant.id, tostring(variant.model or variant.base)))
			end
		end
	end
	return made
end

local published = publishVariants()
if published > 0 then
	print(("[Variants] %d Mastery Weapon(s) published from their base guns"):format(published))
end

-- The build a player currently has equipped for a weapon, or nil for DEFAULT.
function WeaponBuildService.Equipped(player: Player, weaponName: string)
	local buildId = equippedOf(player)[weaponName]
	if not buildId then
		return nil
	end
	local list = buildsOf(player)[weaponName]
	if type(list) ~= "table" then
		return nil
	end
	return (findBuild(list, buildId))
end

local function streakOf(player: Player): number
	local character = player.Character
	local value = character and character:GetAttribute("KillStreak")
	return type(value) == "number" and value or 0
end

-- Dress a tool the moment it reaches a character.
local function onToolAdded(player: Player, tool: Instance)
	if not tool:IsA("Tool") or not WeaponConfig.IsWeapon(tool.Name) then
		return
	end
	local build = WeaponBuildService.Equipped(player, tool.Name)
	if build then
		WeaponBuildService.Dress(tool, build, streakOf(player))
	end
end

local function watch(player: Player)
	local function hook(container: Instance)
		container.ChildAdded:Connect(function(child)
			task.wait(0.05)          -- let the tool finish assembling
			onToolAdded(player, child)
		end)
		for _, child in ipairs(container:GetChildren()) do
			task.spawn(onToolAdded, player, child)
		end
	end

	local function onCharacter(character: Model)
		hook(character)
		local backpack = player:WaitForChild("Backpack", 10)
		if backpack then
			hook(backpack)
		end
	end
	if player.Character then
		task.spawn(onCharacter, player.Character)
	end
	player.CharacterAdded:Connect(onCharacter)
end

Players.PlayerAdded:Connect(watch)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(watch, player)
end

-- Reactive camos: repaint when the streak moves. Kills are already announced, so this
-- costs one repaint per kill rather than anything per frame.
KillCredit.KillAwarded.Event:Connect(function(killer)
	if not killer or not killer:IsA("Player") then
		return
	end
	local character = killer.Character
	if not character then
		return
	end
	character:SetAttribute("KillStreak", streakOf(killer) + 1)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") and WeaponConfig.IsWeapon(child.Name) then
			local build = WeaponBuildService.Equipped(killer, child.Name)
			if build and build.camo then
				local camo = CamoConfig.Find(build.camo)
				if camo and camo.reactive then
					CamoConfig.Apply(child, build.camo, streakOf(killer))
				end
			end
		end
	end
end)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		character:SetAttribute("KillStreak", 0)   -- a streak dies with you
	end)
end)

-- ------------------------------------------------------------------- remote --

local handlers = {}

function handlers.list(player, weaponName)
	if not WeaponConfig.IsWeapon(weaponName) then
		return { ok = false, reason = "Unknown weapon" }
	end
	return {
		ok = true,
		builds = buildsOf(player)[weaponName] or {},
		equipped = equippedOf(player)[weaponName],
		max = MAX_BUILDS_PER_WEAPON,
	}
end

function handlers.create(player, weaponName, payload)
	if not WeaponConfig.IsWeapon(weaponName) then
		return { ok = false, reason = "Unknown weapon" }
	end
	local builds = buildsOf(player)
	local list = builds[weaponName] or {}
	if #list >= MAX_BUILDS_PER_WEAPON then
		return { ok = false, reason = "Build slots full (" .. MAX_BUILDS_PER_WEAPON .. ")" }
	end

	payload = type(payload) == "table" and payload or {}
	local build = {
		id = makeId(),
		name = cleanName(payload.name, string.format("BUILD %02d", #list + 1)),
		attachments = cleanAttachments(player, weaponName, payload.attachments),
		camo = cleanCamo(player, payload.camo),
		createdAt = os.time(),
		updatedAt = os.time(),
	}
	table.insert(list, build)
	builds[weaponName] = list
	local saved = commit(player, builds, nil)
	return { ok = true, saved = saved, build = build }
end

function handlers.save(player, weaponName, payload)
	if type(payload) ~= "table" or type(payload.id) ~= "string" then
		return { ok = false, reason = "Bad build" }
	end
	local builds = buildsOf(player)
	local list = builds[weaponName]
	if type(list) ~= "table" then
		return { ok = false, reason = "No builds for this weapon" }
	end
	local build = findBuild(list, payload.id)
	if not build then
		return { ok = false, reason = "No such build" }
	end
	-- Only this record is touched, so the other builds and the default are untouched.
	build.name = cleanName(payload.name, build.name)
	build.attachments = cleanAttachments(player, weaponName, payload.attachments)
	build.camo = cleanCamo(player, payload.camo)
	build.updatedAt = os.time()
	local saved = commit(player, builds, nil)
	return { ok = true, saved = saved, build = build }
end

function handlers.duplicate(player, weaponName, payload)
	local builds = buildsOf(player)
	local list = builds[weaponName]
	if type(list) ~= "table" then
		return { ok = false, reason = "No builds for this weapon" }
	end
	if #list >= MAX_BUILDS_PER_WEAPON then
		return { ok = false, reason = "Build slots full" }
	end
	local source = findBuild(list, type(payload) == "table" and payload.id or nil)
	if not source then
		return { ok = false, reason = "No such build" }
	end
	local copy = {
		id = makeId(),
		name = cleanName(source.name .. " COPY", "BUILD COPY"),
		attachments = cleanAttachments(player, weaponName, source.attachments), -- a fresh table, not a reference
		camo = source.camo,
		createdAt = os.time(), updatedAt = os.time(),
	}
	table.insert(list, copy)
	local saved = commit(player, builds, nil)
	return { ok = true, saved = saved, build = copy }
end

function handlers.delete(player, weaponName, payload)
	local builds = buildsOf(player)
	local list = builds[weaponName]
	if type(list) ~= "table" then
		return { ok = false, reason = "No builds for this weapon" }
	end
	local build, index = findBuild(list, type(payload) == "table" and payload.id or nil)
	if not build then
		return { ok = false, reason = "No such build" }
	end
	table.remove(list, index)
	local equipped = equippedOf(player)
	if equipped[weaponName] == build.id then
		equipped[weaponName] = nil          -- deleting what you had on returns you to default
	end
	local saved = commit(player, builds, equipped)
	return { ok = true, saved = saved }
end

function handlers.equip(player, weaponName, payload)
	if not WeaponConfig.IsWeapon(weaponName) then
		return { ok = false, reason = "Unknown weapon" }
	end
	local equipped = equippedOf(player)
	local buildId = type(payload) == "table" and payload.id or nil

	if buildId == nil then
		equipped[weaponName] = nil          -- back to DEFAULT
	else
		local list = buildsOf(player)[weaponName]
		if type(list) ~= "table" or not findBuild(list, buildId) then
			return { ok = false, reason = "No such build" }
		end
		equipped[weaponName] = buildId
	end
	local saved = commit(player, nil, equipped)

	-- Re-dress anything the player is already carrying, so the change is immediate.
	local build = WeaponBuildService.Equipped(player, weaponName)
	for _, container in ipairs({ player.Character, player:FindFirstChildOfClass("Backpack") }) do
		local tool = container and container:FindFirstChild(weaponName)
		if tool and tool:IsA("Tool") then
			if build then
				WeaponBuildService.Dress(tool, build, streakOf(player))
			else
				-- DEFAULT: strip back to the template's own look.
				AttachmentBuilder.Clear(tool)
				local template = ReplicatedStorage.storeitems:FindFirstChild(weaponName)
				if template then
					for _, part in ipairs(tool:GetDescendants()) do
						if part:IsA("BasePart") then
							local original = template:FindFirstChild(part.Name)
							if original and original:IsA("BasePart") then
								part.Color = original.Color
								part.Material = original.Material
							end
						end
					end
				end
			end
		end
	end
	return { ok = true, saved = saved }
end

BuildAction.OnServerInvoke = function(player, action, weaponName, payload)
	if type(action) ~= "string" or type(weaponName) ~= "string" then
		return { ok = false, reason = "Bad request" }
	end
	local handler = handlers[action]
	if not handler then
		return { ok = false, reason = "Unknown action" }
	end
	local ok, result = pcall(handler, player, weaponName, payload)
	if not ok then
		warn("[WeaponBuildService] " .. action .. " failed: " .. tostring(result))
		return { ok = false, reason = "Server error" }
	end
	return result
end

return WeaponBuildService
