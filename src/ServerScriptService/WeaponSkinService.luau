--!strict
-- Owner-only weapon customisation: what the skins are, who may change them, and getting
-- them onto the weapons people actually carry.
--
-- Skins are applied to the TEMPLATES in ReplicatedStorage.storeitems, not to individual
-- tools. Everything that hands out a weapon -- the shop, the spawn re-grant, NPC drops,
-- the inventory previews -- clones those templates, so one write reaches all of them and
-- nothing has to be hunted down and repainted.
--
-- They are game-wide, and only the owner can set them. That is enforced here on the
-- server; the GUI hiding itself is a convenience, not the check.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local AdminService = require(ServerScriptService.AdminService)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local WeaponConfig = require(ReplicatedStorage.WeaponConfig)
local AttachmentConfig = require(ReplicatedStorage.AttachmentConfig)
local AttachmentBuilder = require(ReplicatedStorage.AttachmentBuilder)

local storeitems = ReplicatedStorage:WaitForChild("storeitems")
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local WeaponSkinService = {}

-- Materials the screen offers. Anything not on this list is refused, so a crafted remote
-- cannot set a material that breaks rendering.
local ALLOWED_MATERIALS = {
	SmoothPlastic = true, Plastic = true, Metal = true, DiamondPlate = true,
	Neon = true, Wood = true, WoodPlanks = true, Marble = true, Slate = true,
	CorrodedMetal = true, Glass = true, Foil = true,
}

-- The live, game-wide tables. Loaded from the owner's profile at startup.
local skins: { [string]: any } = {}
local attachments: { [string]: { [string]: string } } = {}

local function isColourTriple(v): boolean
	return type(v) == "table" and #v == 3
		and type(v[1]) == "number" and type(v[2]) == "number" and type(v[3]) == "number"
end

local function toColor3(triple): Color3
	return Color3.fromRGB(
		math.clamp(triple[1], 0, 255),
		math.clamp(triple[2], 0, 255),
		math.clamp(triple[3], 0, 255))
end

-- Which parts of a weapon can be recoloured, and what they are currently set to. Read
-- straight off the model, so it lists what genuinely exists rather than a made-up menu.
function WeaponSkinService.Describe(weaponName: string)
	local template = storeitems:FindFirstChild(weaponName)
	if not template then
		return nil
	end
	local parts = {}
	for _, part in ipairs(template:GetDescendants()) do
		if part:IsA("BasePart") then
			table.insert(parts, {
				Name = part.Name,
				Colour = { math.floor(part.Color.R * 255 + 0.5),
					math.floor(part.Color.G * 255 + 0.5),
					math.floor(part.Color.B * 255 + 0.5) },
				Material = part.Material.Name,
			})
		end
	end
	table.sort(parts, function(a, b)
		return a.Name < b.Name
	end)
	return parts
end

-- Paint a weapon template from its skin entry.
function WeaponSkinService.Apply(weaponName: string)
	local template = storeitems:FindFirstChild(weaponName)
	local skin = skins[weaponName]
	if not template or not skin then
		return
	end
	for _, part in ipairs(template:GetDescendants()) do
		if part:IsA("BasePart") then
			local entry = skin[part.Name]
			if entry then
				if isColourTriple(entry.Colour) then
					part.Color = toColor3(entry.Colour)
				end
				if type(entry.Material) == "string" and ALLOWED_MATERIALS[entry.Material] then
					part.Material = (Enum.Material :: any)[entry.Material]
				end
			end
		end
	end
end

-- Fit the saved attachments to a weapon template. Everything that hands out a weapon
-- clones these templates, so this reaches the shop, the spawn re-grant and NPC drops.
function WeaponSkinService.ApplyAttachments(weaponName: string)
	local template = storeitems:FindFirstChild(weaponName)
	if not template then
		return
	end
	AttachmentBuilder.Apply(template, attachments[weaponName])
end

function WeaponSkinService.ApplyAll()
	for name in pairs(skins) do
		WeaponSkinService.Apply(name)
	end
	for name in pairs(attachments) do
		WeaponSkinService.ApplyAttachments(name)
	end
end

-- Only ids the catalogue actually contains survive, so a stale or forged loadout cannot
-- put anything unexpected on a weapon.
local function sanitiseLoadout(incoming): { [string]: string }?
	if type(incoming) ~= "table" then
		return nil
	end
	local clean = {}
	for _, slot in ipairs(AttachmentConfig.Slots) do
		local id = incoming[slot]
		if type(id) == "string" and AttachmentConfig.Find(slot, id) then
			clean[slot] = id
		end
	end
	return clean
end

function WeaponSkinService.GetSkins()
	return skins
end

-- Validate an incoming skin table. Anything unrecognised is dropped rather than trusted.
local function sanitise(weaponName: string, incoming): any?
	if not WeaponConfig.IsWeapon(weaponName) then
		return nil
	end
	local template = storeitems:FindFirstChild(weaponName)
	if not template or type(incoming) ~= "table" then
		return nil
	end

	local valid = {}
	for _, part in ipairs(template:GetDescendants()) do
		if part:IsA("BasePart") then
			valid[part.Name] = true
		end
	end

	local clean = {}
	local count = 0
	for partName, entry in pairs(incoming) do
		if valid[partName] and type(entry) == "table" and count < 64 then
			local out = {}
			if isColourTriple(entry.Colour) then
				out.Colour = {
					math.clamp(math.floor(entry.Colour[1]), 0, 255),
					math.clamp(math.floor(entry.Colour[2]), 0, 255),
					math.clamp(math.floor(entry.Colour[3]), 0, 255),
				}
			end
			if type(entry.Material) == "string" and ALLOWED_MATERIALS[entry.Material] then
				out.Material = entry.Material
			end
			if next(out) then
				clean[partName] = out
				count += 1
			end
		end
	end
	return clean
end

-- ------------------------------------------------------------------ remote --

local CustomiseAction = Remotes:FindFirstChild("CustomiseAction")
if not CustomiseAction then
	CustomiseAction = Instance.new("RemoteFunction")
	CustomiseAction.Name = "CustomiseAction"
	CustomiseAction.Parent = Remotes
end

CustomiseAction.OnServerInvoke = function(player: Player, action: string, weaponName: any, payload: any)
	-- "authorised" is answerable by anyone: the GUI asks it to decide whether to exist.
	if action == "authorised" then
		return AdminService.IsOwner(player)
	end

	-- Everything else is owner-only, checked here rather than trusted from the client.
	if not AdminService.IsOwner(player) then
		warn(string.format("[WeaponSkin] refused %s from %s (%d): not the owner",
			tostring(action), player.Name, player.UserId))
		return { ok = false, reason = "Not authorised" }
	end

	if action == "describe" then
		if type(weaponName) ~= "string" then
			return { ok = false, reason = "Bad weapon" }
		end
		return {
			ok = true,
			parts = WeaponSkinService.Describe(weaponName),
			skin = skins[weaponName],
			attachments = attachments[weaponName],
		}
	end

	if action == "attach" then
		if type(weaponName) ~= "string" or not WeaponConfig.IsWeapon(weaponName) then
			return { ok = false, reason = "Bad weapon" }
		end
		local clean = sanitiseLoadout(payload)
		if not clean then
			return { ok = false, reason = "Bad loadout" }
		end
		attachments[weaponName] = clean
		WeaponSkinService.ApplyAttachments(weaponName)
		-- Skins are painted per part, and an attachment brings new parts, so repaint after.
		WeaponSkinService.Apply(weaponName)

		local saved = pcall(function()
			local replica = PlayerDataManager:GetPlayerDataReplica(player):expect()
			replica:SetValue("WeaponAttachments", attachments)
		end)
		return { ok = true, saved = saved }
	end

	if action == "save" then
		if type(weaponName) ~= "string" then
			return { ok = false, reason = "Bad weapon" }
		end
		local clean = sanitise(weaponName, payload)
		if not clean then
			return { ok = false, reason = "Nothing valid to save" }
		end

		skins[weaponName] = clean
		WeaponSkinService.Apply(weaponName)

		local ok = pcall(function()
			local replica = PlayerDataManager:GetPlayerDataReplica(player):expect()
			replica:SetValue("WeaponSkins", skins)
		end)
		return { ok = true, saved = ok }
	end

	if action == "reset" then
		if type(weaponName) ~= "string" then
			return { ok = false, reason = "Bad weapon" }
		end
		skins[weaponName] = nil
		attachments[weaponName] = nil
		AttachmentBuilder.Clear(storeitems:FindFirstChild(weaponName) or Instance.new("Folder"))
		pcall(function()
			local replica = PlayerDataManager:GetPlayerDataReplica(player):expect()
			replica:SetValue("WeaponSkins", skins)
			replica:SetValue("WeaponAttachments", attachments)
		end)
		return { ok = true, note = "Attachments cleared; colours return on the next server start" }
	end

	return { ok = false, reason = "Unknown action" }
end

-- ------------------------------------------------------------------- load --

-- Pull the saved skins off the owner's profile when they join and paint the templates.
local function loadFrom(player: Player)
	if not AdminService.IsOwner(player) then
		return
	end
	local ok, replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
	end)
	if not ok or not replica then
		return
	end
	local savedSkins = replica.Data.WeaponSkins
	if type(savedSkins) == "table" then
		for weaponName, entry in pairs(savedSkins) do
			local clean = sanitise(weaponName, entry)
			if clean and next(clean) then
				skins[weaponName] = clean
			end
		end
	end

	local savedAttachments = replica.Data.WeaponAttachments
	if type(savedAttachments) == "table" then
		for weaponName, entry in pairs(savedAttachments) do
			if WeaponConfig.IsWeapon(weaponName) then
				local clean = sanitiseLoadout(entry)
				if clean and next(clean) then
					attachments[weaponName] = clean
				end
			end
		end
	end

	WeaponSkinService.ApplyAll()
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadFrom, player)
end)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(loadFrom, player)
end

return WeaponSkinService
