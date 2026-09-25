--!strict
-- The questions every part of the NPC AI asks the world, answered in one place.
--
-- Raycast filters in particular: rebuilding a RaycastParams for every ray is the kind of
-- small allocation that turns into a real cost once twenty enemies are each casting a few
-- a second. These are built once and refreshed only when the things they exclude change.

local Players = game:GetService("Players")

local World = {}

local NPC_FOLDER = "NPCs"

function World.NPCFolder(): Folder
	local folder = workspace:FindFirstChild(NPC_FOLDER)
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = NPC_FOLDER
		folder.Parent = workspace
	end
	return folder :: Folder
end

--- Everything that is never cover and never blocks a shot: dropped weapons, debris, the
--- effect bins. Looked up each refresh because some of them are created lazily.
local function clutter(): { Instance }
	local out: { Instance } = {}
	for _, name in ipairs({ "WeaponDrops", "Debris", "HitFlashes" }) do
		local inst = workspace:FindFirstChild(name)
		if inst then
			table.insert(out, inst)
		end
	end
	return out
end

local sight = RaycastParams.new()
sight.FilterType = Enum.RaycastFilterType.Exclude
sight.IgnoreWater = true

local ground = RaycastParams.new()
ground.FilterType = Enum.RaycastFilterType.Exclude
ground.IgnoreWater = false

local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Exclude
overlap.RespectCanCollide = true

local lastRefresh = -math.huge

-- Characters move in and out constantly, so rather than track every change these are
-- rebuilt at most twice a second -- far below anything a player could notice.
local function refresh()
	local now = os.clock()
	if now - lastRefresh < 0.5 then
		return
	end
	lastRefresh = now

	-- Sight: NPC bodies do not block other NPCs' view (a crowd would otherwise blind
	-- itself), and neither does clutter. Walls and terrain do.
	local sightList = clutter()
	table.insert(sightList, World.NPCFolder())
	sight.FilterDescendantsInstances = sightList

	-- Ground: never stand on a character.
	local groundList = clutter()
	table.insert(groundList, World.NPCFolder())
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(groundList, player.Character)
		end
	end
	ground.FilterDescendantsInstances = groundList
	overlap.FilterDescendantsInstances = groundList
end

function World.SightParams(): RaycastParams
	refresh()
	return sight
end

function World.GroundParams(): RaycastParams
	refresh()
	return ground
end

-- Shots pass through allies. Friendly fire inside a squad that is spreading out and
-- flanking would have them cutting each other down, which reads as broken AI, not realism.
local shotParams: { [string]: RaycastParams } = {}
local shotDirty: { [string]: boolean } = {}
local factionModels: { [string]: { [Model]: boolean } } = {}

function World.Register(model: Model, faction: string)
	factionModels[faction] = factionModels[faction] or {}
	factionModels[faction][model] = true
	shotDirty[faction] = true
end

function World.Unregister(model: Model, faction: string)
	local set = factionModels[faction]
	if set then
		set[model] = nil
	end
	shotDirty[faction] = true
end

function World.ShotParams(faction: string): RaycastParams
	local params = shotParams[faction]
	if not params then
		params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.IgnoreWater = true
		shotParams[faction] = params
		shotDirty[faction] = true
	end
	if shotDirty[faction] then
		shotDirty[faction] = false
		local list = clutter()
		for model in pairs(factionModels[faction] or {}) do
			table.insert(list, model)
		end
		params.FilterDescendantsInstances = list
	end
	return params
end

--- The Humanoid a part belongs to, if it is part of a character at all.
function World.CharacterOf(part: Instance): (Model?, Humanoid?)
	local model = part:FindFirstAncestorOfClass("Model")
	while model do
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if humanoid then
			return model, humanoid
		end
		model = model:FindFirstAncestorOfClass("Model")
	end
	return nil, nil
end

function World.Flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

--- The floor under a point, or nil over a drop. `up` is how far above to start looking.
function World.GroundAt(point: Vector3, up: number?, depth: number?): RaycastResult?
	local lift = up or 6
	local start = point + Vector3.new(0, lift, 0)
	local result = workspace:Raycast(start, Vector3.new(0, -(lift + (depth or 14)), 0), World.GroundParams())
	if result and result.Normal.Y > 0.65 then
		return result
	end
	return nil
end

--- Is anything solid standing in a person-sized box at `floor`?
function World.IsClear(floor: Vector3, size: Vector3): boolean
	refresh()
	local centre = CFrame.new(floor + Vector3.new(0, size.Y / 2 + 0.4, 0))
	return #workspace:GetPartBoundsInBox(centre, size, overlap) == 0
end

--- Every player character that is alive, with its root.
function World.LivingPlayers(): { { model: Model, root: BasePart, humanoid: Humanoid, player: Player } }
	local out = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and root and root:IsA("BasePart") and humanoid.Health > 0 then
			table.insert(out, { model = character :: Model, root = root, humanoid = humanoid, player = player })
		end
	end
	return out
end

return World
