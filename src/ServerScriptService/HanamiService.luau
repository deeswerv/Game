--!strict
-- HANAMI CITY at run time: the world past Downtown, opened by beating the Don at the top of
-- ZEE TOWER (TravelService lists it then).
--
--   * Builds the city (HanamiService.City) and wires what you can use in it: the trader's
--     counter in the arcade opens the market, the shrine's bell heals you, the locals talk.
--   * Keeps the Kurogane clan in it, but only while somebody is there to meet them: the first
--     player in wakes the valley -- every post of HanamiConfig.Population gets its fighter,
--     and the fallen come back after a while -- and an empty valley is cleared again. So the
--     valley costs nothing when nobody is in it, and never counts against the rest of the
--     world's population cap.
--   * Runs its jobs and its fights (HanamiService.Jobs: the rescue, the clues, the seals, the
--     raid; HanamiService.Bosses: Foreman Tetsu and the Iron Shogun).
--
-- Players in the valley carry the InHanami attribute. Everything the client is told goes out on
-- Remotes.HanamiEvent (MainUI shows it).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local HanamiConfig = require(ReplicatedStorage.HanamiConfig)
local KillCredit = require(ServerScriptService.KillCredit)
local City = require(script.City)

local HanamiService = {}

HanamiService.FOLDER = HanamiConfig.FOLDER
HanamiService.Clock = os.clock
HanamiService.RESPAWN = 75          -- a fallen post is filled again after this
HanamiService.EMPTY_AFTER = 60      -- an empty valley is cleared after this
HanamiService.PRAY_COOLDOWN = 30
HanamiService.PRAY_CALM = 6         -- you cannot pray in the middle of a fight

local function ensureRemote(className: string, name: string): Instance
	local folder = ReplicatedStorage:FindFirstChild("Remotes")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Remotes"
		folder.Parent = ReplicatedStorage
	end
	local existing = (folder :: Instance):FindFirstChild(name)
	if existing then
		return existing
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = folder
	return made
end
local hanamiEvent = ensureRemote("RemoteEvent", "HanamiEvent") :: RemoteEvent
HanamiService.Event = hanamiEvent

local function service(name: string): any
	local module = ServerScriptService:FindFirstChild(name)
	if not module then
		return nil
	end
	local ok, loaded = pcall(require, module :: ModuleScript)
	return if ok and type(loaded) == "table" then loaded else nil
end
HanamiService.Service = service

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end
HanamiService.RootOf = rootOf

--- Coins, XP, crystals and Street Cred, the same way every other reward in the game is paid.
function HanamiService.Pay(player: Player, reward: { [string]: number })
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") and (reward.coins or 0) > 0 then
		coins.Value += reward.coins
	end
	local Crystals = service("CrystalService")
	if Crystals and Crystals.Award and (reward.crystals or 0) > 0 then
		Crystals.Award(player, reward.crystals)
	end
	local LevelSystem = service("LevelSystem")
	if LevelSystem and LevelSystem.AwardXP and (reward.xp or 0) > 0 then
		task.spawn(LevelSystem.AwardXP, player, reward.xp)
	end
	local Turf = service("TurfWarService")
	if Turf and Turf.AddCred and (reward.cred or 0) > 0 then
		Turf.AddCred(player, reward.cred)
	end
end

--- Tell the quest tracker something happened (a seal taken, a clue read, a boss down).
function HanamiService.Note(player: Player, kind: string, detail: { [string]: any })
	local Quests = service("QuestService")
	if Quests and Quests.RegisterEvent then
		task.spawn(Quests.RegisterEvent, player, kind, detail)
	end
end

-- ----------------------------------------------------------------- presence --

local inside: { [Player]: boolean } = {}

function HanamiService.Inside(): { Player }
	local list = {}
	for p in pairs(inside) do
		if p.Parent then
			table.insert(list, p)
		end
	end
	return list
end

function HanamiService.IsInside(player: Player): boolean
	return inside[player] == true
end

-- When each player was last hurt, for the shrine (no healing mid-fight).
local lastHurt: { [Player]: number } = {}
KillCredit.Damaged.Event:Connect(function(humanoid: Humanoid)
	local player = humanoid.Parent and Players:GetPlayerFromCharacter(humanoid.Parent)
	if player then
		lastHurt[player] = HanamiService.Clock()
	end
end)

-- --------------------------------------------------------------- population --

type Slot = { spec: { archetype: string, at: Vector3 }, model: Model?, diedAt: number? }
local slots: { Slot } = {}
for _, spec in ipairs(HanamiConfig.Population) do
	table.insert(slots, { spec = spec, model = nil, diedAt = nil })
end
local awake = false
local emptySince: number? = nil

--- Bring a Kurogane fighter in at a valley-frame point: through NPCService, outside its cap,
--- marked Hanami (and not respawned by NPCService -- the valley does that itself).
function HanamiService.Spawn(archetype: string, at: Vector3, attributes: { [string]: any }?): Model?
	local NPCService = service("NPCService")
	if not NPCService or not NPCService.Spawn then
		return nil
	end
	local attrs = { Hanami = true }
	for k, v in pairs(attributes or {}) do
		attrs[k] = v
	end
	local ok, model = pcall(NPCService.Spawn, archetype, HanamiConfig.CENTRE + at + Vector3.new(0, 3, 0),
		{ respawn = false, ignoreCap = true, attributes = attrs })
	return if ok then model else nil
end

local function fill(slot: Slot)
	local model = HanamiService.Spawn(slot.spec.archetype, slot.spec.at)
	slot.model = model
	slot.diedAt = nil
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			if slot.model == model then
				slot.model = nil
				slot.diedAt = HanamiService.Clock()
			end
		end)
	elseif not model then
		-- Could not place it this time: try again later.
		slot.diedAt = HanamiService.Clock()
	end
end

local function wake()
	awake = true
	for _, slot in ipairs(slots) do
		if not slot.model then
			fill(slot)
		end
	end
	print("[Hanami] the valley wakes")
end

local function sleep()
	awake = false
	for _, slot in ipairs(slots) do
		if slot.model and slot.model.Parent then
			slot.model:Destroy()
		end
		slot.model = nil
		slot.diedAt = nil
	end
	local Jobs = HanamiService.Jobs
	if Jobs and Jobs.Reset then
		Jobs.Reset()
	end
	print("[Hanami] the valley sleeps")
end

function HanamiService.Awake(): boolean
	return awake
end

--- One tick: who is in the valley, and whether it should be awake.
function HanamiService.Step()
	local now = HanamiService.Clock()
	for _, player in ipairs(Players:GetPlayers()) do
		local root = rootOf(player)
		local here = root ~= nil and HanamiConfig.Inside(root.Position)
		if here and not inside[player] then
			inside[player] = true
			player:SetAttribute("InHanami", true)
			hanamiEvent:FireClient(player, "enter", { cleared = player:GetAttribute("HanamiCleared") == true })
		elseif not here and inside[player] then
			inside[player] = nil
			player:SetAttribute("InHanami", nil)
		end
	end
	if next(inside) then
		emptySince = nil
		if not awake then
			wake()
		end
		for _, slot in ipairs(slots) do
			local model = slot.model
			local humanoid = model and model:FindFirstChildOfClass("Humanoid")
			if model and (not model.Parent or not humanoid or humanoid.Health <= 0) then
				-- Dead or cleared away (Died normally gets here first).
				slot.model = nil
				slot.diedAt = now
			end
			if not slot.model and slot.diedAt and now - slot.diedAt >= HanamiService.RESPAWN then
				fill(slot)
			end
		end
	elseif awake then
		emptySince = emptySince or now
		if now - (emptySince :: number) >= HanamiService.EMPTY_AFTER then
			sleep()
		end
	end
	local Jobs = HanamiService.Jobs
	if Jobs and Jobs.Step then
		Jobs.Step(now)
	end
	local Bosses = HanamiService.Bosses
	if Bosses and Bosses.Step then
		Bosses.Step(now)
	end
end

Players.PlayerRemoving:Connect(function(player)
	inside[player] = nil
	lastHurt[player] = nil
end)

-- ---------------------------------------------------------------- the shrine --

local prayedAt: { [Player]: number } = {}

--- Ring the shrine's bell: out of a fight, it heals you to full (every so often).
function HanamiService.Pray(player: Player): (boolean, string?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false, "dead"
	end
	local now = HanamiService.Clock()
	if now - (lastHurt[player] or -math.huge) < HanamiService.PRAY_CALM then
		hanamiEvent:FireClient(player, "note", { title = "Not now", text = "Catch your breath first -- you're still in a fight" })
		return false, "fighting"
	end
	local wait = HanamiService.PRAY_COOLDOWN - (now - (prayedAt[player] or -math.huge))
	if wait > 0 then
		hanamiEvent:FireClient(player, "note", { title = "The bell is still ringing", text = ("Pray again in %ds"):format(math.ceil(wait)) })
		return false, "cooldown"
	end
	prayedAt[player] = now
	humanoid.Health = humanoid.MaxHealth
	hanamiEvent:FireClient(player, "blessed", {})
	return true, nil
end

-- ---------------------------------------------------------------- villagers --

-- The people of the station quarter: where they stand (city frame, turned to face `face`), how
-- they dress, and what they will tell you.
HanamiService.Villagers = {
	{ name = "Grandma Ume", role = "LOCAL", at = Vector3.new(-18, 0.5, -384), face = Vector3.new(0, 0.5, -400),
	  look = { Shirt = Color3.fromRGB(110, 90, 140), Pants = Color3.fromRGB(70, 60, 80), Sleeves = true,
		Outfit = { { "Hair", style = "grey", colour = Color3.fromRGB(200, 200, 204) }, { "Obi", colour = Color3.fromRGB(236, 190, 80) },
			{ "Loafers" } } :: { any } },
	  lines = { "The blossoms came early this year. So did the Kurogane.", "Sixty years I've sat under this tree. They tax the benches now.",
		"If you're going up to the castle, child, eat something first. The ramen by the canal is good." } },
	{ name = "Little Sora", role = "LOCAL", at = Vector3.new(24, 0.5, -432), face = Vector3.new(0, 0.5, -446),
	  look = { Shirt = Color3.fromRGB(240, 150, 60), Pants = Color3.fromRGB(60, 80, 120), Sleeves = false, Scale = 0.8,
		Outfit = { { "Hair", style = "top" }, { "Sneakers" } } :: { any } },
	  lines = { "My brother went into the rail yard to look for the others. He hasn't come back.",
		"The men in the straw hats took Mr. Kenta's whole catch AND his truck!", "Is it true you beat the Don? Show me how!" } },
	{ name = "Jiro", role = "FISHMONGER", at = Vector3.new(72, 0.5, -205), face = Vector3.new(72, 0.5, -180),
	  look = { Shirt = Color3.fromRGB(70, 110, 130), Pants = Color3.fromRGB(60, 60, 64), Sleeves = true,
		Outfit = { { "Hachimaki", colour = Color3.fromRGB(240, 240, 236) }, { "Beard", style = "full", colour = Color3.fromRGB(60, 50, 44) },
			{ "Apron", colour = Color3.fromRGB(40, 70, 130) }, { "Boots" } } :: { any } },
	  lines = { "The trains bring their crates at night. Iron, all of it, going up to the castle.",
		"Foreman Tetsu runs the Steelworks with a hammer. On the workers, mostly.", "Nobody buys fish when the furnace smoke comes down the canal." } },
	{ name = "Brother Ryo", role = "SHRINE MONK", at = Vector3.new(-192, 0, -432), face = Vector3.new(-160, 0, -432),
	  look = { Shirt = Color3.fromRGB(236, 190, 80), Pants = Color3.fromRGB(236, 190, 80), Sleeves = true,
		Outfit = { { "Hair", style = "bald" }, { "Obi", colour = Color3.fromRGB(160, 36, 44) }, { "Loafers" } } :: { any } },
	  lines = { "Ring the bell if you're wounded. The shrine still keeps its own.",
		"The Shogun was a guardian of this city once. Iron got into him.", "Breathe. The blossoms will still be here tomorrow." } },
	{ name = "Aiko", role = "CAFE OWNER", at = Vector3.new(100, 0.5, -262), face = Vector3.new(120, 0.5, -262),
	  look = { Shirt = Color3.fromRGB(196, 80, 110), Pants = Color3.fromRGB(80, 40, 60), Sleeves = true,
		Outfit = { { "Hair", style = "slick", colour = Color3.fromRGB(30, 26, 30) }, { "Apron", colour = Color3.fromRGB(246, 236, 214) },
			{ "Loafers" } } :: { any } },
	  lines = { "Coffee? The arcade's the only street the clan doesn't patrol.",
		"A Kurogane courier left something on the ramen shop's roof last night. There's a ladder up the side.", "Lantern Row used to be lovely, before the clan." } },
}

local function speak(figure: Model, text: string)
	local head = figure:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local old = head:FindFirstChild("Speech")
	if old then
		old:Destroy()
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Speech"
	gui.Size = UDim2.fromOffset(260, 64)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.4, 0)
	gui.MaxDistance = 50
	gui.LightInfluence = 0
	gui.Parent = head
	local bubble = Instance.new("TextLabel")
	bubble.Size = UDim2.fromScale(1, 1)
	bubble.BackgroundColor3 = Color3.fromRGB(252, 248, 240)
	bubble.TextColor3 = Color3.fromRGB(30, 30, 36)
	bubble.Font = Enum.Font.GothamMedium
	bubble.TextSize = 15
	bubble.TextWrapped = true
	bubble.Text = text
	bubble.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = bubble
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0, 10)
	pad.PaddingRight = UDim.new(0, 10)
	pad.Parent = bubble
	task.delay(5, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
end
HanamiService.Speak = speak

--- A standing person (the players' rig, dressed): for villagers and captives.
function HanamiService.Figure(look: { [string]: any }, seed: number, name: string, role: string?): Model?
	local outfitModule = ServerScriptService:FindFirstChild("NPCService")
	outfitModule = outfitModule and outfitModule:FindFirstChild("Outfit")
	if not outfitModule or not outfitModule:IsA("ModuleScript") then
		return nil
	end
	local ok, Outfit = pcall(require, outfitModule)
	if not ok or type(Outfit) ~= "table" then
		return nil
	end
	local figure = Outfit.Standing(look, seed)
	if not figure then
		return nil
	end
	figure.Name = name
	local humanoid = figure:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.MaxHealth = math.huge
		humanoid.Health = math.huge
	end
	if look.Scale and look.Scale ~= 1 then
		pcall(function()
			figure:ScaleTo(look.Scale)
		end)
	end
	local head = figure:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
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
		line(name, 0, 26, 22, Color3.new(1, 1, 1), Enum.Font.SourceSansBold)
		if role then
			line(role, 26, 18, 15, Color3.fromRGB(255, 194, 30), Enum.Font.FredokaOne)
		end
	end
	return figure
end

local function placeFigure(figure: Model, at: Vector3, face: Vector3, parent: Instance)
	local stand = HanamiConfig.CENTRE + at + Vector3.new(0, 3, 0)
	local look = HanamiConfig.CENTRE + Vector3.new(face.X, at.Y, face.Z) + Vector3.new(0, 3, 0)
	figure:PivotTo(CFrame.lookAt(stand, look))
	figure.Parent = parent
end
HanamiService.PlaceFigure = placeFigure

local function villagers(folder: Instance)
	local people: Instance = folder:FindFirstChild("Villagers") or Instance.new("Folder")
	people.Name = "Villagers"
	people.Parent = folder
	for i, v in ipairs(HanamiService.Villagers) do
		if not people:FindFirstChild(v.name) then
			local figure = HanamiService.Figure(v.look, 300 + i, v.name, v.role)
			if figure then
				placeFigure(figure, v.at, v.face, people)
				local root = figure:FindFirstChild("HumanoidRootPart")
				if root and root:IsA("BasePart") then
					local prompt = Instance.new("ProximityPrompt")
					prompt.ActionText = "Talk"
					prompt.ObjectText = v.name
					prompt.KeyboardKeyCode = Enum.KeyCode.E
					prompt.HoldDuration = 0
					prompt.MaxActivationDistance = 10
					prompt.RequiresLineOfSight = false
					prompt.Parent = root
					local nextLine = 1
					prompt.Triggered:Connect(function()
						speak(figure, v.lines[nextLine])
						nextLine = nextLine % #v.lines + 1
					end)
				end
			end
		end
	end
end

-- ------------------------------------------------------------------- wiring --

local function wire(folder: Instance)
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("PromptText") and not d:FindFirstChildOfClass("ProximityPrompt") then
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = tostring(d:GetAttribute("PromptText"))
			prompt.ObjectText = tostring(d:GetAttribute("PromptObject") or "")
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.RequiresLineOfSight = false
			prompt.MaxActivationDistance = 11
			prompt.HoldDuration = 0
			local panel = d:GetAttribute("OpenPanel")
			if type(panel) == "string" then
				-- The client opens the panel (StarterPlayerScripts.MainUI reads this).
				prompt:SetAttribute("OpenPanel", panel)
			elseif d.Name == "ShrineBell" then
				prompt.Triggered:Connect(function(player)
					HanamiService.Pray(player)
				end)
			end
			prompt.Parent = d
		end
	end
	pcall(villagers, folder)
	local Jobs = HanamiService.Jobs
	if Jobs and Jobs.Wire then
		local ok, err = pcall(function()
			Jobs.Wire(folder)
		end)
		if not ok then
			warn("[Hanami] jobs: " .. tostring(err))
		end
	end
	local Bosses = HanamiService.Bosses
	if Bosses and Bosses.Wire then
		local ok, err = pcall(function()
			Bosses.Wire(folder)
		end)
		if not ok then
			warn("[Hanami] bosses: " .. tostring(err))
		end
	end
end

function HanamiService.Folder(): Instance?
	return workspace:FindFirstChild(HanamiService.FOLDER)
end

--- Build the valley (or wire the one already standing, if it was baked into the place).
function HanamiService.Build()
	local existing = workspace:FindFirstChild(HanamiService.FOLDER)
	if existing and existing:GetAttribute("Baked") then
		wire(existing)
		return
	end
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = HanamiService.FOLDER
	local ok, err = pcall(function()
		City.Build(folder, HanamiConfig.CENTRE)
	end)
	if not ok then
		warn("[Hanami] failed to build: " .. tostring(err))
	end
	folder.Parent = workspace
	wire(folder)
	print(("[Hanami] built at %s, %d parts"):format(tostring(HanamiConfig.CENTRE), #folder:GetDescendants()))
end

-- The jobs and the fights live in their own modules; they read this one back for its helpers.
HanamiService.Jobs = require(script.Jobs)
HanamiService.Bosses = require(script.Bosses)
HanamiService.Jobs.Init(HanamiService)
HanamiService.Bosses.Init(HanamiService)

HanamiService.Build()

task.spawn(function()
	while true do
		task.wait(1)
		local ok, err = pcall(function()
			HanamiService.Step()
		end)
		if not ok then
			warn("[Hanami] " .. tostring(err))
		end
	end
end)

return HanamiService
