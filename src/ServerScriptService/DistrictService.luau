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

-- What each shop's clerk wears (NPCService.Outfit): the gun shop's in a work apron and a cap,
-- the gear shop's in a staff polo and cargo trousers. The shirt is the shop's own colour.
local CLERK_LOOKS: { [string]: { [string]: any } } = {
	["ZEE GUNS"] = {
		Skin = Color3.fromRGB(198, 142, 102), Pants = Color3.fromRGB(46, 48, 56), Sleeves = true,
		Outfit = {
			{ "Hair", style = "short" }, { "Cap", colour = Color3.fromRGB(28, 28, 32), logo = Color3.fromRGB(250, 204, 60) },
			{ "Tee" }, { "Apron", colour = Color3.fromRGB(120, 82, 52) }, { "Watch" },
			{ "Sneakers", colour = Color3.fromRGB(34, 34, 38), sole = Color3.fromRGB(236, 234, 228) },
		} :: { any },
	},
	["ZEE TACTICS"] = {
		Skin = Color3.fromRGB(241, 194, 150), Pants = Color3.fromRGB(70, 74, 58), Sleeves = true,
		Outfit = {
			{ "Hair", style = "crop" }, { "Polo", logo = Color3.fromRGB(90, 200, 220) }, { "Belt" }, { "Cargo" },
			{ "Boots", colour = Color3.fromRGB(58, 48, 38) },
		} :: { any },
	},
}

--- A clerk behind a shop counter, standing on `spot` and facing the door, with a nameplate:
--- the players' own rig in the shop's work clothes (or, if the place has no such rig, one
--- borrowed from the world and painted the shop's colour).
local function clerk(spot: BasePart)
	local parent = spot.Parent
	if not parent or parent:FindFirstChild("Clerk") then
		return
	end
	local shirt = spot:GetAttribute("ClerkShirt")
	local shirtColour = if typeof(shirt) == "Color3" then shirt else Color3.fromRGB(60, 60, 70)
	local npc: Model? = nil
	local outfitModule = ServerScriptService:FindFirstChild("NPCService")
	outfitModule = outfitModule and outfitModule:FindFirstChild("Outfit")
	if outfitModule and outfitModule:IsA("ModuleScript") then
		local ok, Outfit = pcall(require, outfitModule)
		if ok and type(Outfit) == "table" then
			local look = table.clone(CLERK_LOOKS[tostring(spot:GetAttribute("ClerkTitle"))] or CLERK_LOOKS["ZEE GUNS"])
			look.Shirt = shirtColour
			npc = Outfit.Standing(look, 7)
		end
	end
	if not npc then
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
		local borrowed = template:Clone()
		for _, d in ipairs(borrowed:GetDescendants()) do
			if d:IsA("LuaSourceContainer") or d:IsA("BodyColors") or d:IsA("BillboardGui") or d:IsA("ProximityPrompt")
				or d.Name == "Signpost" then
				d:Destroy()
			end
		end
		for _, p in ipairs(borrowed:GetDescendants()) do
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
		npc = borrowed
	end
	local figure = npc :: Model
	figure.Name = "Clerk"
	local humanoid = figure:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.MaxHealth = math.huge
		humanoid.Health = math.huge
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end
	-- Facing out over the counter toward the door: -X, unless the shop says otherwise.
	local stand = spot.Position + Vector3.new(0, 3, 0)
	local facing = spot:GetAttribute("ClerkFacing")
	local look = if typeof(facing) == "Vector3" and facing.Magnitude > 0.01 then Vector3.new(facing.X, 0, facing.Z).Unit
		else Vector3.new(-1, 0, 0)
	figure:PivotTo(CFrame.lookAt(stand, stand + look))
	figure.Parent = parent
	local head = figure:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		-- The same look as every other name tag: white name, gold role, a dark edge on both.
		local plate = Instance.new("BillboardGui")
		plate.Name = "Nameplate"
		plate.Size = UDim2.fromOffset(170, 46)
		plate.StudsOffsetWorldSpace = Vector3.new(0, 2.4, 0)
		plate.MaxDistance = 40
		plate.LightInfluence = 0
		plate.Parent = head
		local function line(text: string, y: number, h: number, size: number, colour: Color3, font: Enum.Font)
			local label = Instance.new("TextLabel")
			label.BackgroundTransparency = 1
			label.Position = UDim2.new(0, 0, 0, y)
			label.Size = UDim2.new(1, 0, 0, h)
			label.Font = font
			label.TextSize = size
			label.TextColor3 = colour
			label.Text = text
			label.Parent = plate
			local edge = Instance.new("UIStroke")
			edge.Color = Color3.fromRGB(8, 8, 12)
			edge.Thickness = 2
			edge.LineJoinMode = Enum.LineJoinMode.Round
			edge.Parent = label
		end
		line(tostring(spot:GetAttribute("ClerkName") or "Clerk"), 0, 26, 22, Color3.new(1, 1, 1), Enum.Font.SourceSansBold)
		line(tostring(spot:GetAttribute("ClerkTitle") or ""), 26, 18, 15, Color3.fromRGB(255, 194, 30), Enum.Font.FredokaOne)
	end
end

-- What Downtown's people wear (NPCService.Outfit): street clothes, nothing a crew wears, each
-- drawing its own colours so no two are the same.
DistrictService.CIVILIANS = {
	{   -- a student: hoodie, bag, sneakers
		Palette = { Skin = "tones", Shirt = { Color3.fromRGB(120, 170, 220), Color3.fromRGB(240, 196, 90),
			Color3.fromRGB(150, 210, 160) }, Pants = { Color3.fromRGB(64, 84, 120), Color3.fromRGB(52, 52, 60) } },
		Outfit = { { "Hair", style = "short" }, { "Hoodie" }, { "StrapBag", colour = Color3.fromRGB(40, 40, 46) },
			{ "Sneakers", colour = Color3.fromRGB(240, 238, 232) } } :: { any },
	},
	{   -- office: a suit, slick hair, loafers, a watch
		Palette = { Skin = "tones", Shirt = { Color3.fromRGB(52, 60, 82), Color3.fromRGB(96, 98, 104) },
			Pants = { Color3.fromRGB(44, 48, 62) } },
		Outfit = { { "Hair", style = "slick" }, { "Suit" }, { "Watch" }, { "Loafers" } } :: { any },
	},
	{   -- weekend: a tee, a cap, a watch
		Palette = { Skin = "tones", Shirt = { Color3.fromRGB(236, 120, 120), Color3.fromRGB(246, 244, 236),
			Color3.fromRGB(120, 200, 190) }, Pants = { Color3.fromRGB(70, 92, 130), Color3.fromRGB(196, 176, 140) } },
		Outfit = { { "Hair", style = "top" }, { "Tee" }, { "Cap", colour = Color3.fromRGB(46, 70, 120) }, { "Watch" },
			{ "Sneakers", colour = Color3.fromRGB(60, 60, 66) } } :: { any },
	},
	{   -- a jogger: a tracksuit, not red
		Palette = { Skin = "tones", Shirt = { Color3.fromRGB(60, 110, 200), Color3.fromRGB(110, 110, 118) },
			Pants = { Color3.fromRGB(40, 44, 52) } },
		Outfit = { { "Hair", style = "crop" }, { "Tracksuit", stripe = Color3.fromRGB(240, 240, 236) },
			{ "Sneakers", colour = Color3.fromRGB(240, 240, 236) } } :: { any },
	},
	{   -- an old gent: grey hair, a jacket, a fedora
		Palette = { Skin = "tones", Shirt = { Color3.fromRGB(200, 184, 150), Color3.fromRGB(130, 110, 90) },
			Pants = { Color3.fromRGB(90, 84, 76) } },
		Outfit = { { "Hair", style = "grey" }, { "Jacket", colour = Color3.fromRGB(150, 120, 90), inner = Color3.fromRGB(236, 230, 214) },
			{ "Fedora", colour = Color3.fromRGB(70, 60, 52) }, { "Loafers" } } :: { any },
	},
	{   -- a tourist: a tee, shades, a cap
		Palette = { Skin = "tones", Shirt = { Color3.fromRGB(250, 210, 80), Color3.fromRGB(200, 120, 220),
			Color3.fromRGB(90, 200, 230) }, Pants = { Color3.fromRGB(210, 196, 160), Color3.fromRGB(60, 80, 110) } },
		Outfit = { { "Hair", style = "short" }, { "Tee" }, { "Shades" }, { "Cap", colour = Color3.fromRGB(240, 238, 230) },
			{ "Sneakers", colour = Color3.fromRGB(230, 90, 80) } } :: { any },
	},
}

--- Downtown's people: a dressed figure for each of Downtown.Walkers, standing at the start of
--- its stretch of sidewalk, tagged "Pedestrian" with the stretch on it (WalkFrom / WalkTo in
--- the world, WalkSpeed, WalkPhase) -- Pedestrians.client walks them, the same on every client
--- because it times them off the server clock. Not part of any fight: nothing can hit, touch
--- or stand on them, and they are not Staff (nobody poses them but their walk).
local function pedestrians(folder: Instance)
	if folder:FindFirstChild("Pedestrians") or not Downtown.Walkers then
		return
	end
	local outfitModule = ServerScriptService:FindFirstChild("NPCService")
	outfitModule = outfitModule and outfitModule:FindFirstChild("Outfit")
	if not (outfitModule and outfitModule:IsA("ModuleScript")) then
		return
	end
	local ok, Outfit = pcall(require, outfitModule)
	if not ok or type(Outfit) ~= "table" then
		return
	end
	local holder = Instance.new("Folder")
	holder.Name = "Pedestrians"
	for i, walk in ipairs(Downtown.Walkers) do
		local look = DistrictService.CIVILIANS[walk[3]] or DistrictService.CIVILIANS[1]
		local figure = Outfit.Standing(look, 200 + i * 7)
		if figure then
			figure.Name = "Pedestrian"
			figure:RemoveTag("Staff")
			for _, p in ipairs(figure:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
				end
			end
			local from = DistrictService.CENTRE + walk[1]
			local to = DistrictService.CENTRE + walk[2]
			local root = figure:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = figure:FindFirstChildOfClass("Humanoid")
			local lift = (if humanoid then humanoid.HipHeight else 2) + (if root then root.Size.Y / 2 else 1)
			figure:PivotTo(CFrame.lookAt(from + Vector3.new(0, lift, 0), to + Vector3.new(0, lift, 0)))
			figure:SetAttribute("WalkFrom", from + Vector3.new(0, lift, 0))
			figure:SetAttribute("WalkTo", to + Vector3.new(0, lift, 0))
			figure:SetAttribute("WalkSpeed", walk[4])
			figure:SetAttribute("WalkPhase", (i * 0.37) % 1)
			figure:AddTag("Pedestrian")
			figure.Parent = holder
		end
	end
	holder.Parent = folder
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

	local okPeople, peopleErr = pcall(pedestrians, folder)
	if not okPeople then
		warn("[Downtown] pedestrians: " .. tostring(peopleErr))
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
