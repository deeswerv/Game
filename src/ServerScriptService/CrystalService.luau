--!strict
-- Builds crystal nodes and hands out what they yield.
--
-- The node is scenery with a prompt on it. Everything that matters -- whether the node is
-- still standing, how much it gives, and writing the total -- happens here, so a client
-- that spams the prompt gets one payout and then an empty rock.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CrystalConfig = require(ReplicatedStorage.CrystalConfig)
local MineService = require(ServerScriptService.MineService)
local WorldBake = require(ServerScriptService.WorldBake)

local CrystalService = {}

-- Pulled in on first use rather than at the top. Building the nodes must not drag the data
-- layer in with it: baking the geometry happens in Edit mode, where ProfileService has no
-- DataStore to talk to and blocks.
local PlayerDataManager
local function data()
	if not PlayerDataManager then
		PlayerDataManager = require(ServerScriptService.PlayerDataManager)
	end
	return PlayerDataManager
end

local ROCK = Color3.fromRGB(104, 108, 118)
local harvested: { [Model]: boolean } = {}

local function folder(): Folder
	local f = workspace:FindFirstChild("Crystals")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Crystals"
		f.Parent = workspace
	end
	return f :: Folder
end

local function shard(parent: Instance, size: Vector3, cf: CFrame, colour: Color3)
	local p = Instance.new("Part")
	p.Name = "Shard"
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = Enum.Material.Neon
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false      -- shards never stop a bullet; the base rock is the solid bit
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

--- Attach the mining prompt to a node.
--
-- Split out of build() so a node that came from the saved place -- one you dragged
-- somewhere else in Studio -- behaves exactly like a freshly generated one. The zone rides
-- on the model as an attribute, so the yield follows the rock wherever you put it.
local function wire(model: Model): boolean
	local rock = model:FindFirstChild("Base")
	local prompt = rock and rock:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		return false
	end
	local zoneId = model:GetAttribute("Zone") or "Mine"
	prompt.Triggered:Connect(function(player)
		CrystalService.Harvest(player, model, { zone = zoneId })
	end)
	return true
end

local function build(spec, index: number): Model
	local zone = CrystalConfig.Zones[spec.zone]
	local model = Instance.new("Model")
	model.Name = ("Node_%s_%d"):format(spec.zone, index)

	local base = CFrame.new(spec.position)

	local rock = Instance.new("Part")
	rock.Name = "Base"
	rock.Size = Vector3.new(3.4, 1.1, 3.4)
	rock.CFrame = base * CFrame.new(0, 0.55, 0)
	rock.Color = ROCK
	rock.Material = Enum.Material.Slate
	rock.Anchored = true
	rock.CanCollide = true
	rock.TopSurface = Enum.SurfaceType.Smooth
	rock.BottomSurface = Enum.SurfaceType.Smooth
	rock.Parent = model

	local rng = Random.new(index * 977)
	for i = 1, 4 do
		local h = rng:NextNumber(1.6, 3.1)
		shard(model, Vector3.new(0.62, h, 0.62),
			base * CFrame.new(rng:NextNumber(-0.9, 0.9), 1.0 + h / 2, rng:NextNumber(-0.9, 0.9))
				* CFrame.Angles(math.rad(rng:NextNumber(-16, 16)), rng:NextNumber(0, math.pi), math.rad(rng:NextNumber(-16, 16))),
			zone.colour)
	end

	local light = Instance.new("PointLight")
	light.Color = zone.colour
	light.Brightness = 1.9
	light.Range = 16
	light.Parent = rock

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Mine"
	prompt.ObjectText = "Crystal"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = CrystalConfig.HARVEST_SECONDS
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = rock

	model.PrimaryPart = rock
	model:SetAttribute("Zone", spec.zone)
	model.Parent = folder()
	wire(model)
	return model
end

-- Fired when a player mines a node: (player, amount). Contracts count these.
CrystalService.Harvested = Instance.new("BindableEvent")

--- Award crystals for a node, once.
function CrystalService.Harvest(player: Player, model: Model, spec): boolean
	if harvested[model] then
		return false
	end
	local ok, replica = pcall(function()
		return data():GetPlayerDataReplica(player):expect()
	end)
	if not ok or not replica then
		return false
	end
	harvested[model] = true

	local zone = CrystalConfig.Zones[spec.zone]
	local amount = math.random(zone.yield[1], zone.yield[2])
	replica:SetValue("Crystals", (replica.Data.Crystals or 0) + amount)
	CrystalService.Harvested:Fire(player, amount)

	-- Hide rather than destroy: the same model comes back, so nothing has to be rebuilt
	-- and the prompt connection survives.
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CanCollide = false
		elseif d:IsA("ProximityPrompt") then
			d.Enabled = false
		elseif d:IsA("PointLight") then
			d.Enabled = false
		end
	end

	task.delay(math.random(CrystalConfig.RESPAWN_MIN, CrystalConfig.RESPAWN_MAX), function()
		harvested[model] = nil
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				d.Transparency = 0
				d.CanCollide = d.Name == "Base"
			elseif d:IsA("ProximityPrompt") then
				d.Enabled = true
			elseif d:IsA("PointLight") then
				d.Enabled = true
			end
		end
	end)
	return true
end

function CrystalService.Get(player: Player): number
	local ok, replica = pcall(function()
		return data():GetPlayerDataReplica(player):expect()
	end)
	return (ok and replica and replica.Data.Crystals) or 0
end

--- Add crystals. Harvesting is not the only way in any more -- a paid contract pays out in
--- these, which is what gives coins a route to the one repeatable thing to spend on.
function CrystalService.Award(player: Player, amount: number): boolean
	if amount <= 0 then
		return false
	end
	local ok, replica = pcall(function()
		return data():GetPlayerDataReplica(player):expect()
	end)
	if not ok or not replica then
		return false
	end
	replica:SetValue("Crystals", (replica.Data.Crystals or 0) + math.floor(amount))
	return true
end

--- Spend, refusing rather than going negative.
function CrystalService.Spend(player: Player, amount: number): boolean
	local ok, replica = pcall(function()
		return data():GetPlayerDataReplica(player):expect()
	end)
	if not ok or not replica then
		return false
	end
	local have = replica.Data.Crystals or 0
	if have < amount then
		return false
	end
	replica:SetValue("Crystals", have - amount)
	return true
end

function CrystalService.Build()
	if WorldBake.IsBaked("Crystals") then
		harvested = {}
		local wired = 0
		for _, model in ipairs(folder():GetChildren()) do
			if model:IsA("Model") and wire(model) then
				wired += 1
			end
		end
		print(("[Crystals] baked copy kept -- %d nodes rewired where they stand"):format(wired))
		return
	end
	local f = folder()
	f:ClearAllChildren()
	harvested = {}
	-- Positions come from the mine itself, so the seam always matches the room it is in.
	local spots = MineService.NodePositions()
	for i, position in ipairs(spots) do
		build({ zone = "Mine", position = position }, i)
	end
	print(("[Crystals] " .. #spots .. " nodes set into the mine"))
end

CrystalService.Build()

return CrystalService
