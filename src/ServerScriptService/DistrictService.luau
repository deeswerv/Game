--!strict
-- Downtown: the city district, and everything in it that does something.
--
-- The geometry is DistrictService.Downtown (a pure builder the map previewer can render).
-- This service puts it in the sky north of the hub -- clear of the islands, the range and
-- the duel maps -- and wires it up:
--
--   * ZEE GUNS and ZEE TACTICS are shops you walk into: a clerk stands behind each counter
--     (a rig borrowed from the world, like the quest givers), and the counter's prompt opens
--     the gun shop or the gear counter; the workbench in ZEE GUNS opens the armory. The
--     CONTRACTS and MOST WANTED boards on the 24/7 open theirs (the client opens them).
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

--- A clerk behind a shop counter: a rig borrowed from the world (as the quest givers are),
--- dressed in the shop's shirt, standing on `spot` and facing the door, with a nameplate.
local function clerk(spot: BasePart)
	local parent = spot.Parent
	if not parent or parent:FindFirstChild("Clerk") then
		return
	end
	local template: Model? = nil
	for _, d in ipairs(workspace:GetChildren()) do
		if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") and d:FindFirstChild("Head")
			and not game:GetService("Players"):GetPlayerFromCharacter(d) and d.Name:sub(1, 11) ~= "QuestGiver_" then
			template = d
			break
		end
	end
	if not template then
		return
	end
	local npc = template:Clone()
	npc.Name = "Clerk"
	for _, d in ipairs(npc:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("BodyColors") or d:IsA("BillboardGui") or d:IsA("ProximityPrompt")
			or d.Name == "Signpost" then
			d:Destroy()
		end
	end
	local shirt = spot:GetAttribute("ClerkShirt")
	local shirtColour = if typeof(shirt) == "Color3" then shirt else Color3.fromRGB(60, 60, 70)
	for _, p in ipairs(npc:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			if p.Name == "Head" or p.Name:find("Arm") or p.Name:find("Hand") then
				p.Color = Color3.fromRGB(214, 170, 128)
			elseif p.Name:find("Leg") or p.Name:find("Foot") then
				p.Color = Color3.fromRGB(46, 48, 56)
			else
				p.Color = shirtColour
			end
		end
	end
	local humanoid = npc:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.MaxHealth = math.huge
		humanoid.Health = math.huge
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	-- Facing -X: out over the counter toward the door.
	local stand = spot.Position + Vector3.new(0, 3, 0)
	npc:PivotTo(CFrame.lookAt(stand, stand + Vector3.new(-1, 0, 0)))
	npc.Parent = parent
	local head = npc:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local plate = Instance.new("BillboardGui")
		plate.Name = "Nameplate"
		plate.Size = UDim2.fromOffset(160, 44)
		plate.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
		plate.MaxDistance = 40
		plate.Parent = head
		local name = Instance.new("TextLabel")
		name.BackgroundTransparency = 1
		name.Size = UDim2.new(1, 0, 0.55, 0)
		name.Font = Enum.Font.FredokaOne
		name.TextScaled = true
		name.TextColor3 = Color3.new(1, 1, 1)
		name.TextStrokeTransparency = 0.2
		name.Text = tostring(spot:GetAttribute("ClerkName") or "Clerk")
		name.Parent = plate
		local title = Instance.new("TextLabel")
		title.BackgroundTransparency = 1
		title.Position = UDim2.fromScale(0, 0.55)
		title.Size = UDim2.new(1, 0, 0.45, 0)
		title.Font = Enum.Font.GothamBold
		title.TextScaled = true
		title.TextColor3 = Color3.fromRGB(255, 214, 90)
		title.TextStrokeTransparency = 0.3
		title.Text = tostring(spot:GetAttribute("ClerkTitle") or "")
		title.Parent = plate
	end
end

--- Prompts on everything marked for one, clerks behind the counters, pads in the hall. Safe
--- to run on a baked copy.
local function wire(folder: Instance)
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") and d.Name == "ClerkSpot" then
			local ok, err = pcall(clerk, d)
			if not ok then
				warn("[Downtown] clerk: " .. tostring(err))
			end
		end
	end
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
			elseif d.Name == "TowerDoor" or d.Name == "TowerExit" then
				-- The elevator up ZEE TOWER and back down (TowerService decides who may go).
				prompt.HoldDuration = 0.6
				prompt.MaxActivationDistance = 12
				prompt.Triggered:Connect(function(player)
					local ok, Tower = pcall(require, ServerScriptService:FindFirstChild("TowerService") :: ModuleScript)
					if ok and type(Tower) == "table" then
						if d.Name == "TowerDoor" then
							Tower.Enter(player)
						else
							Tower.Leave(player)
						end
					end
				end)
			elseif d.Name == "RooftopStash" then
				prompt.HoldDuration = 1.2
				prompt.Triggered:Connect(function(player)
					openStash(player, d)
				end)
			end
			prompt.Parent = d
		end
	end

	-- The tills and cash machines are there to be robbed (StickupService).
	local okStickup, Stickups = pcall(require, ServerScriptService:FindFirstChild("StickupService") :: ModuleScript)
	if okStickup and type(Stickups) == "table" and Stickups.Wire then
		Stickups.Wire(folder)
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
