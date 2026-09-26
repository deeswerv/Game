--!strict
-- Downtown: the city district, and everything in it that does something.
--
-- The geometry is DistrictService.Downtown (a pure builder the map previewer can render).
-- This service puts it in the sky north of the hub -- clear of the islands, the range and
-- the duel maps -- and wires it up:
--
--   * ZEE GUNS, the ARMORY and the CONTRACTS board carry prompts that open the shop, the
--     armory and the contracts panel (the client opens them; nothing to validate).
--   * The DUEL HALL gets its own pair of 1v1 pads (DuelPads), into the same queue.
--   * The ROOFTOP STASH at the top of the fire escape pays once a day per player.
--
-- You get there from the Travel menu (TravelService's "Downtown" place lands on the forecourt);
-- supply drops come down in its streets too (SupplyDropService).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local WorldBake = require(ServerScriptService.WorldBake)
local LevelSystem = require(ServerScriptService.LevelSystem)
local GameConfig = require(ReplicatedStorage.GameConfig)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local Downtown = require(script.Downtown)

local DistrictService = {}

DistrictService.FOLDER = "Downtown"
-- Travellers land at CENTRE + Downtown.Arrival; TravelService's Downtown place matches it.
DistrictService.CENTRE = Vector3.new(-155, 1000, 1500)
DistrictService.STASH = { coins = 750, crystals = 3, xp = 400 }

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local WorldReward = (remotes :: Instance):FindFirstChild("WorldReward") :: RemoteEvent?
if not WorldReward then
	local made = Instance.new("RemoteEvent")
	made.Name = "WorldReward"
	made.Parent = remotes
	WorldReward = made
end
local worldReward = WorldReward :: RemoteEvent

local function today(): number
	return math.floor(os.time() / 86400)
end

--- Once a day per player: cash, crystals and XP for having climbed up there.
local function openStash(player: Player, stash: BasePart)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") or (root.Position - stash.Position).Magnitude > 14 then
		return
	end
	local ok, replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
	end)
	if not ok or not replica then
		return
	end
	local day = today()
	if tonumber(replica.Data.StashDay) == day then
		worldReward:FireClient(player, { kind = "empty", title = "STASH EMPTY", text = "Come back tomorrow" })
		return
	end
	replica:SetValue("StashDay", day)
	local reward = DistrictService.STASH
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value += reward.coins
	end
	replica:SetValue("Crystals", (tonumber(replica.Data.Crystals) or 0) + reward.crystals)
	task.spawn(LevelSystem.AwardXP, player, reward.xp)
	worldReward:FireClient(player, {
		kind = "reward", title = "ROOFTOP STASH", coins = reward.coins, crystals = reward.crystals,
		xp = GameConfig.ShownXP(reward.xp),
	})
	print(("[Downtown] %s opened the rooftop stash"):format(player.Name))
	local okC, ContractService = pcall(require, ServerScriptService:FindFirstChild("ContractService") :: ModuleScript)
	if okC and type(ContractService) == "table" and ContractService.Note then
		task.spawn(ContractService.Note, player, "stash")
	end
end

--- Prompts on everything marked for one, pads in the hall. Safe to run on a baked copy.
local function wire(folder: Instance)
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("PromptText") and not d:FindFirstChildOfClass("ProximityPrompt") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = tostring(d:GetAttribute("PromptText"))
			prompt.ObjectText = tostring(d:GetAttribute("PromptObject") or "")
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.RequiresLineOfSight = false
			prompt.MaxActivationDistance = 10
			local panel = Downtown.Panels[d.Name]
			if panel then
				-- The client opens the panel (StarterPlayerScripts.MainUI reads this).
				prompt:SetAttribute("OpenPanel", panel)
				prompt.HoldDuration = 0
			elseif d.Name == "RooftopStash" then
				prompt.HoldDuration = 1.2
				prompt.Triggered:Connect(function(player)
					openStash(player, d)
				end)
			end
			prompt.Parent = d
		end
	end

	local site = folder:FindFirstChild("DuelPadSite", true)
	if site and site:IsA("BasePart") then
		local ok, DuelPads = pcall(require, ServerScriptService:FindFirstChild("DuelPads") :: ModuleScript)
		if ok and type(DuelPads) == "table" and DuelPads.AddPair then
			local at = site.Position - Vector3.new(0, site.Size.Y / 2, 0)
			-- Painted in the hall's team colours, like the rest of downtown: no glow.
			DuelPads.AddPair(folder, CFrame.new(at) * CFrame.Angles(0, math.rad(90), 0),
				{ plain = true, colours = Downtown.PadColours })
		end
	end
end

function DistrictService.Build()
	local existing = workspace:FindFirstChild(DistrictService.FOLDER)
	if WorldBake.Skip(DistrictService.FOLDER, "Downtown") and existing then
		wire(existing)
		return
	end
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = DistrictService.FOLDER
	local ok, err = pcall(Downtown.Build, folder, DistrictService.CENTRE)
	if not ok then
		warn("[Downtown] failed to build: " .. tostring(err))
	end
	folder.Parent = workspace
	wire(folder)
	print(("[Downtown] built at %s, %d parts"):format(tostring(DistrictService.CENTRE), #folder:GetDescendants()))
end

DistrictService.Build()

return DistrictService
