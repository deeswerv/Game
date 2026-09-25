--!strict
-- Builds and wears cosmetics.
--
-- Everything is decided here: whether the player owns the item, whether the slot is real,
-- and what geometry gets welded on. The client sends an id and a slot and nothing else.
--
-- Worn parts are massless, non-collidable and non-queryable, so a hat can never block a
-- bullet, change how the character falls, or give anyone a bigger hitbox than the locked
-- body they are all wearing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CosmeticConfig = require(ReplicatedStorage.CosmeticConfig)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)

local CosmeticService = {}

local FOLDER_NAME = "Cosmetics"

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local CosmeticAction = remotes:FindFirstChild("CosmeticAction")
if not CosmeticAction then
	CosmeticAction = Instance.new("RemoteFunction")
	CosmeticAction.Name = "CosmeticAction"
	CosmeticAction.Parent = remotes
end

local function replicaOf(player: Player)
	local ok, replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
	end)
	return ok and replica or nil
end

local function owns(player: Player, id: string): boolean
	local replica = replicaOf(player)
	if not replica then
		return false
	end
	for _, owned in ipairs(replica.Data.OwnedCosmetics or {}) do
		if owned == id then
			return true
		end
	end
	return false
end

CosmeticService.Owns = owns

local function clearWorn(character: Model)
	local folder = character:FindFirstChild(FOLDER_NAME)
	if folder then
		folder:Destroy()
	end
end

--- Build one item onto the character. Returns how many parts were welded.
local function wear(character: Model, item): number
	local mount = CosmeticConfig.Mounts[item.slot]
	if not mount then
		return 0
	end
	local anchorPart = character:FindFirstChild(mount.part)
	if not anchorPart or not anchorPart:IsA("BasePart") then
		return 0
	end

	local folder = character:FindFirstChild(FOLDER_NAME)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = FOLDER_NAME
		folder.Parent = character
	end

	local built = 0
	for _, spec in ipairs(item.parts) do
		local p = Instance.new("Part")
		p.Name = item.id
		p.Size = spec.size
		p.Color = spec.colour
		p.Material = spec.material or Enum.Material.SmoothPlastic
		p.Anchored = false
		p.CanCollide = false
		p.CanQuery = false      -- never stops a bullet
		p.CanTouch = false
		p.Massless = true       -- never changes how the character moves
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.CFrame = anchorPart.CFrame * mount.offset * spec.offset
		p.Parent = folder

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = anchorPart
		weld.Part1 = p
		weld.Parent = p
		built += 1
	end
	return built
end

--- Put on whatever the profile says this player is wearing.
function CosmeticService.Apply(player: Player)
	local character = player.Character
	if not character then
		return 0
	end
	clearWorn(character)

	local replica = replicaOf(player)
	if not replica then
		return 0
	end
	local equipped = replica.Data.EquippedCosmetics or {}
	local ownedSet = {}
	for _, id in ipairs(replica.Data.OwnedCosmetics or {}) do
		ownedSet[id] = true
	end

	local total = 0
	for _, slot in ipairs(CosmeticConfig.Slots) do
		local id = equipped[slot]
		-- Ownership is re-checked on every spawn, not just at the moment of equipping, so
		-- an item that stops being owned stops being worn.
		if type(id) == "string" and ownedSet[id] then
			local item = CosmeticConfig.Get(id)
			if item and item.slot == slot then
				total += wear(character, item)
			end
		end
	end
	return total
end

--- Equip `id` into its own slot, or nil to clear `slot`.
function CosmeticService.Equip(player: Player, slot: string, id: string?)
	local mount = CosmeticConfig.Mounts[slot]
	if not mount then
		return { ok = false, reason = "No such slot" }
	end
	local replica = replicaOf(player)
	if not replica then
		return { ok = false, reason = "Your data is still loading" }
	end

	local equipped = {}
	for k, v in pairs(replica.Data.EquippedCosmetics or {}) do
		equipped[k] = v
	end

	if id == nil then
		equipped[slot] = nil
	else
		local item = CosmeticConfig.Get(id)
		if not item or item.slot ~= slot then
			return { ok = false, reason = "That does not go there" }
		end
		if not owns(player, id) then
			return { ok = false, reason = "You do not own that" }
		end
		equipped[slot] = id
	end

	replica:SetValue("EquippedCosmetics", equipped)
	CosmeticService.Apply(player)
	return { ok = true, reason = id and ("Wearing " .. id) or ("Removed " .. slot) }
end

CosmeticAction.OnServerInvoke = function(player, action, slot, id)
	if action == "equip" then
		if typeof(slot) ~= "string" then
			return { ok = false, reason = "Bad request" }
		end
		return CosmeticService.Equip(player, slot, typeof(id) == "string" and id or nil)
	elseif action == "state" then
		local replica = replicaOf(player)
		if not replica then
			return nil
		end
		return {
			owned = replica.Data.OwnedCosmetics or {},
			equipped = replica.Data.EquippedCosmetics or {},
		}
	end
	return { ok = false, reason = "Unknown action" }
end

local function onPlayer(player: Player)
	player.CharacterAppearanceLoaded:Connect(function()
		task.wait(0.2)
		CosmeticService.Apply(player)
	end)
	player.CharacterAdded:Connect(function()
		task.wait(0.6)
		CosmeticService.Apply(player)
	end)
	if player.Character then
		task.spawn(CosmeticService.Apply, player)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end

return CosmeticService
