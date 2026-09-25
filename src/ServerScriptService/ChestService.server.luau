--!strict
-- Supply crates in Map 2.
--
-- The whole point of the loot is that it cannot be faked, so everything that decides
-- anything happens here: the rarity roll, the item drawn, the ownership write. The client
-- is told what it won only after it has already been recorded. A player who edits their
-- client can make a crate *look* like it opened; they cannot make it pay.
--
-- Crates are built from Parts rather than a model asset, so they match the flat-shaded
-- art and need nothing imported.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local ChestConfig = require(ReplicatedStorage.ChestConfig)
local CamoConfig = require(ReplicatedStorage.CamoConfig)
local AttachmentConfig = require(ReplicatedStorage.AttachmentConfig)
local ShopService = require(ServerScriptService.ShopService)
local LevelSystem = require(ServerScriptService.LevelSystem)
local GameConfig = require(ReplicatedStorage.GameConfig)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local ChestEffect = Remotes:FindFirstChild("ChestEffect")
if not ChestEffect then
	ChestEffect = Instance.new("RemoteEvent")
	ChestEffect.Name = "ChestEffect"
	ChestEffect.Parent = Remotes
end

local folder = workspace:FindFirstChild("SupplyCrates")
if not folder then
	folder = Instance.new("Folder")
	folder.Name = "SupplyCrates"
	folder.Parent = workspace
end
folder:ClearAllChildren()

-- ------------------------------------------------------------------ loot pools --

-- Built once at startup by reading the live catalogues, so the pools cannot drift out of
-- step with what the game actually contains.
local camosByRarity: { [string]: { string } } = {}
local attachmentsByRarity: { [string]: { string } } = {}

local function buildPools()
	for _, camo in pairs(CamoConfig.Camos or {}) do
		local id = camo.id
		if id and not camo.factory then
			local tier = camo.rarity or "Common"
			camosByRarity[tier] = camosByRarity[tier] or {}
			table.insert(camosByRarity[tier], id)
		end
	end

	for _, slot in ipairs(AttachmentConfig.Slots or {}) do
		for _, option in ipairs((AttachmentConfig.Options or {})[slot] or {}) do
			local id = option.id
			if id and not AttachmentConfig.IsStock(slot, id) then
				local ok, tier = pcall(function()
					return AttachmentConfig.Rarity(slot, id)
				end)
				tier = (ok and type(tier) == "string") and tier or "Common"
				attachmentsByRarity[tier] = attachmentsByRarity[tier] or {}
				-- Stored the way ownership is stored, "Slot:Id".
				table.insert(attachmentsByRarity[tier], AttachmentConfig.Key(slot, id))
			end
		end
	end
end

buildPools()

-- Draw an unowned id of this tier, falling back down the tiers before giving up. A player
-- who owns every Legendary camo should still get *something* from a Legendary crate.
local function drawUnowned(player: Player, pools: { [string]: { string } }, field: string, tier: string): string?
	local order = ChestConfig.RarityOrder
	local startAt = 1
	for i, name in ipairs(order) do
		if name == tier then
			startAt = i
			break
		end
	end

	for i = startAt, #order do
		local pool = pools[order[i]]
		if pool and #pool > 0 then
			-- Shuffle a copy so repeated draws do not always offer the same id first.
			local candidates = table.clone(pool)
			for j = #candidates, 2, -1 do
				local k = math.random(j)
				candidates[j], candidates[k] = candidates[k], candidates[j]
			end
			for _, id in ipairs(candidates) do
				if not ShopService.OwnsInField(player, field, id) then
					return id
				end
			end
		end
	end
	return nil
end

-- ---------------------------------------------------------------- crate model --

local function buildCrate(position: Vector3, tier: string): Model
	local spec = ChestConfig.Rarity[tier] or ChestConfig.Rarity.Common

	local model = Instance.new("Model")
	model.Name = "SupplyCrate"

	local base = Instance.new("Part")
	base.Name = "Base"
	base.Size = Vector3.new(3.4, 1.7, 2.4)
	base.CFrame = CFrame.new(position + Vector3.new(0, 0.85, 0))
	base.Anchored = true
	base.Material = Enum.Material.WoodPlanks
	base.Color = Color3.fromRGB(104, 74, 48)
	base.TopSurface = Enum.SurfaceType.Smooth
	base.BottomSurface = Enum.SurfaceType.Smooth
	base.Parent = model

	-- The lid is a separate part so it can hinge open.
	local lid = Instance.new("Part")
	lid.Name = "Lid"
	lid.Size = Vector3.new(3.5, 0.4, 2.5)
	lid.CFrame = CFrame.new(position + Vector3.new(0, 1.9, 0))
	lid.Anchored = true
	lid.Material = Enum.Material.WoodPlanks
	lid.Color = Color3.fromRGB(126, 90, 58)
	lid.TopSurface = Enum.SurfaceType.Smooth
	lid.BottomSurface = Enum.SurfaceType.Smooth
	lid.Parent = model

	-- A banded strip in the tier colour: the only part that changes per rarity, which is
	-- enough to read the tier across the map without every crate glowing.
	local band = Instance.new("Part")
	band.Name = "Band"
	band.Size = Vector3.new(3.5, 0.34, 2.5)
	band.CFrame = CFrame.new(position + Vector3.new(0, 1.35, 0))
	band.Anchored = true
	band.Material = spec.glow > 0.4 and Enum.Material.Neon or Enum.Material.SmoothPlastic
	band.Color = spec.colour
	band.TopSurface = Enum.SurfaceType.Smooth
	band.BottomSurface = Enum.SurfaceType.Smooth
	band.Parent = model

	-- Only the upper tiers get a light, and even then a small one. A field of glowing
	-- boxes stops reading as "something worth walking to".
	if spec.glow > 0.25 then
		local light = Instance.new("PointLight")
		light.Color = spec.colour
		light.Brightness = spec.glow * 2
		light.Range = 8 + spec.glow * 6
		light.Shadows = false
		light.Parent = band
	end

	model.PrimaryPart = base

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "Open"
	prompt.ActionText = "Open Crate"
	prompt.ObjectText = tier .. " Supply"
	prompt.HoldDuration = ChestConfig.HoldDuration
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Parent = base

	model:SetAttribute("Tier", tier)
	model:SetAttribute("Opened", false)
	model.Parent = folder
	return model
end

-- ------------------------------------------------------------------- opening --

local function openCrate(model: Model, player: Player)
	-- Attribute flag, not a lua table: two players holding E on the same crate in the same
	-- frame both reach here, and whichever loses this check must get nothing.
	if model:GetAttribute("Opened") then
		return
	end
	model:SetAttribute("Opened", true)

	local tier = model:GetAttribute("Tier") or "Common"
	local spec = ChestConfig.Rarity[tier] or ChestConfig.Rarity.Common
	local base = model:FindFirstChild("Base") :: BasePart?
	local lid = model:FindFirstChild("Lid") :: BasePart?
	local prompt = base and base:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end

	-- Decide the reward. Coins are the fallback whenever an item pool has nothing left
	-- to give, so a crate can never open to nothing.
	local kind = ChestConfig.RollKind(tier)
	local rewardLabel, rewardKind, rewardId

	if kind == "camo" then
		rewardId = drawUnowned(player, camosByRarity, "OwnedCamos", tier)
		if rewardId and ShopService.Grant(player, "OwnedCamos", rewardId) then
			local camo = CamoConfig.Find(rewardId)
			rewardKind, rewardLabel = "camo", (camo and camo.name) or rewardId
		end
	elseif kind == "attachment" then
		rewardId = drawUnowned(player, attachmentsByRarity, "OwnedAttachments", tier)
		if rewardId and ShopService.Grant(player, "OwnedAttachments", rewardId) then
			local slot, optionId = rewardId:match("^(%a+):(%w+)$")
			local option = slot and optionId and AttachmentConfig.Find(slot, optionId)
			rewardKind, rewardLabel = "attachment", (option and option.name) or rewardId
		end
	end

	if not rewardKind then
		local range = spec.coins
		local amount = math.random(range[1], range[2])
		ShopService.AwardCoins(player, amount)
		rewardKind, rewardLabel = "coins", tostring(amount) .. " Coins"
	end

	-- Lid hinges back rather than sliding, which is what makes it read as a crate opening
	-- instead of a box dissolving.
	if lid and base then
		local hinge = lid.CFrame * CFrame.new(0, 0, -1.25)
		TweenService:Create(lid, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			CFrame = hinge * CFrame.Angles(math.rad(-105), 0, 0) * CFrame.new(0, 0, 1.25),
		}):Play()
	end

	-- XP as well as loot, scaled by tier. Progression that only moves when you shoot
	-- someone makes exploring the map feel like a detour from levelling rather than part
	-- of it.
	local xp = (GameConfig.Leveling.XP_PER_CHEST or {})[tier] or 0
	if xp > 0 then
		LevelSystem.AwardXP(player, xp)
	end

	-- Everyone nearby sees the burst; only the opener gets the reveal card.
	ChestEffect:FireAllClients("Open", model, tier)
	ChestEffect:FireClient(player, "Reward", tier, rewardKind, rewardLabel, xp)

	-- Fade the crate out, then bring a fresh one back on the same spot with a new roll.
	task.delay(1.1, function()
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				TweenService:Create(p, TweenInfo.new(0.5), { Transparency = 1 }):Play()
			end
		end
	end)

	local spot = base and base.Position or Vector3.zero
	task.delay(1.8, function()
		model:Destroy()
	end)
	task.delay(ChestConfig.RespawnSeconds, function()
		buildCrate(spot - Vector3.new(0, 0.85, 0), ChestConfig.RollRarity())
	end)
end

-- --------------------------------------------------------------- placement --

-- Drop each configured XZ onto whatever is actually beneath it, so the crates sit on the
-- ground without anyone having measured the terrain by hand.
local placeParams = RaycastParams.new()
placeParams.FilterType = Enum.RaycastFilterType.Exclude
placeParams.FilterDescendantsInstances = { folder }

local placed = 0
for _, spot in ipairs(ChestConfig.Spawns) do
	local hit = workspace:Raycast(Vector3.new(spot.X, 250, spot.Z), Vector3.new(0, -400, 0), placeParams)
	if hit then
		buildCrate(hit.Position, ChestConfig.RollRarity())
		placed += 1
	else
		warn(("[Chests] no ground under (%d, %d) -- crate skipped"):format(spot.X, spot.Z))
	end
end

-- One connection for every crate, present and future, instead of one per crate.
folder.DescendantAdded:Connect(function(d)
	if d:IsA("ProximityPrompt") then
		d.Triggered:Connect(function(player)
			local model = d:FindFirstAncestorOfClass("Model")
			if model and model.Parent == folder then
				openCrate(model, player)
			end
		end)
	end
end)

-- The crates built above already exist, so they need hooking up directly.
for _, model in ipairs(folder:GetChildren()) do
	local base = model:FindFirstChild("Base")
	local prompt = base and base:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Triggered:Connect(function(player)
			openCrate(model :: Model, player)
		end)
	end
end

print(("[Chests] %d supply crates placed in Map 2"):format(placed))
