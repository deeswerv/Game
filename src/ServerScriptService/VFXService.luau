--!strict
-- VFX: equipping the kill effects and tracers the shop sells, and playing kill effects.
--
-- Buying goes through ShopService (the "vfx" catalogue, so it shares the level gate, the
-- standing price, the coin check and the double-buy guard with everything else). This keeps
-- the other half: which effect is in each slot, published on the player as VFX_Kill and
-- VFX_Tracer so every client draws them, and a kill effect sent to everyone the moment a kill
-- is credited -- from any weapon, since it listens to KillCredit rather than to one gun.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local VFXConfig = require(ReplicatedStorage.VFXConfig)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local KillCredit = require(ServerScriptService.KillCredit)

local VFXService = {}

local function folder(name: string): Instance
	local f = ReplicatedStorage:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = ReplicatedStorage
	end
	return f :: Instance
end

local function remote(parent: Instance, className: string, name: string): Instance
	local existing = parent:FindFirstChild(name)
	if existing then
		return existing
	end
	local r = Instance.new(className)
	r.Name = name
	r.Parent = parent
	return r
end

local VFXAction = remote(folder("GameRemotes"), "RemoteFunction", "VFXAction") :: RemoteFunction
local VFXEvent = remote(folder("Remotes"), "RemoteEvent", "VFXEvent") :: RemoteEvent

local function replicaOf(player: Player)
	local ok, replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
	end)
	return ok and replica or nil
end

local function ownedSet(replica): { [string]: boolean }
	local set = {}
	for _, id in ipairs(replica.Data.OwnedVFX or {}) do
		if type(id) == "string" then
			set[id] = true
		end
	end
	return set
end

--- Put what the profile says is equipped onto the player's attributes -- only what they own,
--- and only in the slot it belongs in, whatever the save says.
function VFXService.Publish(player: Player)
	local replica = replicaOf(player)
	if not replica then
		return
	end
	local owned = ownedSet(replica)
	local equipped = replica.Data.EquippedVFX or {}
	for _, slot in ipairs(VFXConfig.Slots) do
		local id = equipped[slot]
		local item = VFXConfig.Get(id)
		local valid = item ~= nil and item.slot == slot and owned[id] == true
		player:SetAttribute(VFXConfig.Attribute[slot], if valid then id else nil)
	end
end

--- Equip `id` in `slot`, or clear the slot with nil.
function VFXService.Equip(player: Player, slot: string, id: string?)
	if not VFXConfig.Attribute[slot] then
		return { ok = false, reason = "No such slot" }
	end
	local replica = replicaOf(player)
	if not replica then
		return { ok = false, reason = "Your data is still loading" }
	end
	local equipped = table.clone(replica.Data.EquippedVFX or {})
	if id == nil then
		equipped[slot] = nil
	else
		local item = VFXConfig.Get(id)
		if not item or item.slot ~= slot then
			return { ok = false, reason = "That does not go there" }
		end
		if not ownedSet(replica)[id] then
			return { ok = false, reason = "You do not own that" }
		end
		equipped[slot] = id
	end
	replica:SetValue("EquippedVFX", equipped)
	VFXService.Publish(player)
	local item = VFXConfig.Get(id)
	return { ok = true, reason = if item then ("Equipped " .. item.name) else "Removed" }
end

--- After a purchase: equip it if that slot is empty, so what you bought is what you see.
function VFXService.EquipIfEmpty(player: Player, id: string)
	local item = VFXConfig.Get(id)
	local replica = replicaOf(player)
	if item and replica and not (replica.Data.EquippedVFX or {})[item.slot] then
		VFXService.Equip(player, item.slot, id)
	end
end

VFXAction.OnServerInvoke = function(player, action, slot, id)
	if action == "equip" then
		if typeof(slot) ~= "string" then
			return { ok = false, reason = "Bad request" }
		end
		return VFXService.Equip(player, slot, if typeof(id) == "string" then id else nil)
	end
	return { ok = false, reason = "Bad request" }
end

-- A credited kill: the killer's effect, played on the body for everyone.
KillCredit.KillAwarded.Event:Connect(function(killer: Player, humanoid: Humanoid)
	if typeof(killer) ~= "Instance" or not killer:IsA("Player") then
		return
	end
	local id = killer:GetAttribute(VFXConfig.Attribute.Kill)
	local item = VFXConfig.Get(if type(id) == "string" then id else nil)
	local model = humanoid and humanoid.Parent
	if not item or not model or not model:IsA("Model") then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Head")
	local at = if root and root:IsA("BasePart") then root.Position else model:GetPivot().Position
	VFXEvent:FireAllClients("kill", item.id, model, at)
end)

local function onPlayer(player: Player)
	task.spawn(VFXService.Publish, player)
end
Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayer(player)
end

return VFXService
