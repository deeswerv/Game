--!strict
-- Supply drops: every few minutes a crate comes down on a parachute somewhere out in the
-- world, a pillar of light marking where it will land. First to get there and hold E on it
-- takes what is inside -- cash, crystals and XP, doubled in the rare golden one.
--
-- The point is a reason to MOVE: a race across the map that pulls players (and fights)
-- toward one place. Everyone is told where and when it lands (SupplyEvent), so the client
-- can put a marker on it; the crate itself, the timing and the loot are all server side.
--
-- Landing spots are found at run time -- a ray down from the sky inside one of the named
-- zones, open sky above it, solid ground (not water) below -- so a change to the map moves
-- the drops with it rather than dropping crates into a wall.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local LevelSystem = require(ServerScriptService.LevelSystem)
local GameConfig = require(ReplicatedStorage.GameConfig)

local SupplyDropService = {}

SupplyDropService.FIRST_DELAY = 75      -- seconds after the server starts
SupplyDropService.INTERVAL = 240        -- between drops
SupplyDropService.FALL_TIME = 16        -- from the sky to the ground
SupplyDropService.LIFETIME = 240        -- an unopened crate waits this long
SupplyDropService.GOLDEN_CHANCE = 0.12

-- Where drops come down: named places with open ground, from the admin waypoints (which
-- were raycast, not guessed).
SupplyDropService.Zones = {
	{ name = "THE HARBOUR", centre = Vector3.new(-213, 31, 117), radius = 45 },
	{ name = "THE FLATS", centre = Vector3.new(-567, 6, 117), radius = 55 },
	{ name = "THE REACH", centre = Vector3.new(190, 6, 302), radius = 50 },
	{ name = "SATELLITE ISLETS", centre = Vector3.new(-254, 66, 299), radius = 35 },
	{ name = "MAP 2", centre = Vector3.new(-561, 24, 85), radius = 40 },
	-- Downtown's streets and plaza only (maxRise keeps crates off the rooftops).
	{ name = "DOWNTOWN", centre = Vector3.new(-155, 1000.5, 1500), radius = 150, maxRise = 3 },
}

SupplyDropService.Loot = {
	normal = { coins = { 1200, 2200 }, crystals = { 3, 6 }, xp = 600 },
	golden = { coins = { 2800, 4500 }, crystals = { 8, 12 }, xp = 1400 },
}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local SupplyEvent = (remotes :: Instance):FindFirstChild("SupplyEvent") :: RemoteEvent?
if not SupplyEvent then
	local made = Instance.new("RemoteEvent")
	made.Name = "SupplyEvent"
	made.Parent = remotes
	SupplyEvent = made
end
local supplyEvent = SupplyEvent :: RemoteEvent

local OLIVE = Color3.fromRGB(88, 100, 62)
local OLIVE_DARK = Color3.fromRGB(58, 66, 42)
local GOLD = Color3.fromRGB(226, 178, 60)
local GOLD_DARK = Color3.fromRGB(150, 110, 34)
local STRAP = Color3.fromRGB(232, 184, 44)
local BEAM = Color3.fromRGB(90, 220, 255)

local function folder(): Folder
	local f = workspace:FindFirstChild("SupplyDrops")
	if not f then
		f = Instance.new("Folder")
		f.Name = "SupplyDrops"
		f.Parent = workspace
	end
	return f :: Folder
end

-- ------------------------------------------------------------ finding ground --

local function rayParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { folder() }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(ignore, p.Character)
		end
	end
	for _, name in ipairs({ "NPCs", "Debris" }) do
		local f = workspace:FindFirstChild(name)
		if f then
			table.insert(ignore, f)
		end
	end
	params.FilterDescendantsInstances = ignore
	params.IgnoreWater = false
	return params
end

--- A spot in `zone` with solid, level ground and nothing overhead, or nil.
local function findLanding(zone): Vector3?
	local params = rayParams()
	for _ = 1, 16 do
		local angle = math.random() * math.pi * 2
		local r = math.sqrt(math.random()) * zone.radius
		local x, z = zone.centre.X + math.cos(angle) * r, zone.centre.Z + math.sin(angle) * r
		local top = Vector3.new(x, zone.centre.Y + 300, z)
		local hit = workspace:Raycast(top, Vector3.new(0, -600, 0), params)
		if hit and hit.Normal.Y > 0.8 and math.abs(hit.Position.Y - zone.centre.Y) < (zone.maxRise or 70) then
			local ground = hit.Position
			local solid = hit.Material ~= Enum.Material.Water
			if hit.Instance:IsA("BasePart") and not hit.Instance:IsA("Terrain") then
				solid = solid and (hit.Instance :: BasePart).CanCollide
			end
			-- Open sky: the ray came straight down to this, so nothing above it blocks.
			if solid then
				return ground
			end
		end
	end
	return nil
end

-- ------------------------------------------------------------------ crate --

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3,
	material: Enum.Material?, shape: Enum.PartType?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function stencil(parent: BasePart, face: Enum.NormalId, text: string, colour: Color3)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.LightInfluence = 1
	gui.Parent = parent
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.AnchorPoint = Vector2.new(0.5, 0.5)
	label.Position = UDim2.fromScale(0.5, 0.52)
	label.Size = UDim2.fromScale(0.86, 0.34)
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.GothamBlack
	label.TextColor3 = colour
	label.Parent = gui
end

--- Build the crate (and its parachute) at `cf`. Everything is welded to an anchored root,
--- so moving the root moves the lot.
local function buildCrate(cf: CFrame, golden: boolean): (Model, BasePart, Model)
	local model = Instance.new("Model")
	model.Name = golden and "GoldenSupplyDrop" or "SupplyDrop"
	local body = golden and GOLD or OLIVE
	local trim = golden and GOLD_DARK or OLIVE_DARK

	local root = part(model, "Crate", Vector3.new(5, 3.4, 5), cf, body, Enum.Material.Metal)
	root.Anchored = true
	model.PrimaryPart = root

	local function weld(p: BasePart)
		local w = Instance.new("WeldConstraint")
		w.Part0 = root
		w.Part1 = p
		w.Parent = p
	end
	local function add(name: string, size: Vector3, offset: CFrame, colour: Color3, material: Enum.Material?,
		shape: Enum.PartType?): BasePart
		local p = part(model, name, size, cf * offset, colour, material, shape)
		weld(p)
		return p
	end

	add("Lid", Vector3.new(5.3, 0.5, 5.3), CFrame.new(0, 1.95, 0), trim, Enum.Material.Metal)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			for _, sy in ipairs({ -1, 1 }) do
				add("Corner", Vector3.new(0.8, 0.8, 0.8), CFrame.new(sx * 2.35, sy * 1.45, sz * 2.35), trim,
					Enum.Material.DiamondPlate)
			end
		end
	end
	for _, x in ipairs({ -1.3, 1.3 }) do
		add("Strap", Vector3.new(0.5, 3.5, 5.08), CFrame.new(x, 0, 0), STRAP, Enum.Material.Fabric)
	end
	for _, s in ipairs({ -1, 1 }) do
		add("Handle", Vector3.new(0.3, 0.3, 1.6), CFrame.new(s * 2.62, 0.6, 0), Color3.fromRGB(40, 40, 42),
			Enum.Material.Metal)
	end
	stencil(root, Enum.NormalId.Front, golden and "ELITE SUPPLY" or "ZEE SUPPLY", Color3.fromRGB(242, 240, 226))
	stencil(root, Enum.NormalId.Back, golden and "ELITE SUPPLY" or "ZEE SUPPLY", Color3.fromRGB(242, 240, 226))

	local beacon = add("Beacon", Vector3.new(0.5, 0.9, 0.9), CFrame.new(0, 2.5, 0) * CFrame.Angles(0, 0, math.rad(90)),
		golden and GOLD or Color3.fromRGB(255, 70, 60), Enum.Material.Neon, Enum.PartType.Cylinder)
	local light = Instance.new("PointLight")
	light.Color = golden and GOLD or Color3.fromRGB(255, 90, 70)
	light.Range = 18
	light.Brightness = 2
	light.Parent = beacon

	-- The parachute: a stepped dome in alternating panels, lines to the corners.
	local chute = Instance.new("Model")
	chute.Name = "Parachute"
	chute.Parent = model
	local canopyColours = golden and { GOLD, Color3.fromRGB(255, 250, 236), GOLD }
		or { Color3.fromRGB(255, 120, 40), Color3.fromRGB(245, 245, 240), Color3.fromRGB(255, 120, 40) }
	for i, d in ipairs({ 17, 13.5, 8.5 }) do
		local disc = part(chute, "Canopy", Vector3.new(1.2, d, d), cf * CFrame.new(0, 14 + i * 1.1, 0)
			* CFrame.Angles(0, 0, math.rad(90)), canopyColours[i], Enum.Material.Fabric, Enum.PartType.Cylinder)
		weld(disc)
	end
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local from = (cf * CFrame.new(sx * 2.3, 1.8, sz * 2.3)).Position
			local to = (cf * CFrame.new(sx * 7.6, 14.4, sz * 7.6)).Position
			local line = part(chute, "Line", Vector3.new(0.12, 0.12, (to - from).Magnitude),
				CFrame.lookAt((from + to) / 2, to), Color3.fromRGB(230, 230, 230), Enum.Material.Fabric)
			weld(line)
		end
	end

	return model, root, chute
end

--- The pillar of light over the landing spot, up until the crate is opened.
local function pillar(at: Vector3, golden: boolean): BasePart
	local p = Instance.new("Part")
	p.Name = "SupplyBeam"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(420, 3, 3)
	p.CFrame = CFrame.new(at + Vector3.new(0, 210, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Color = golden and GOLD or BEAM
	p.Material = Enum.Material.Neon
	p.Transparency = 0.55
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = folder()
	return p
end

local function smoke(root: BasePart, golden: boolean)
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Flare"
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(golden and GOLD or Color3.fromRGB(255, 90, 60))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 9) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(4, 6)
	emitter.Rate = 7
	emitter.Speed = NumberRange.new(5, 8)
	emitter.SpreadAngle = Vector2.new(12, 12)
	emitter.Acceleration = Vector3.new(2, 1, 0)
	emitter.LightEmission = 0.2
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Parent = root
end

-- ------------------------------------------------------------------ a drop --

local nextId = 0
local lastZone: string? = nil
local active: { [number]: boolean } = {}

local function award(player: Player, golden: boolean)
	local loot = golden and SupplyDropService.Loot.golden or SupplyDropService.Loot.normal
	local coins = math.random(loot.coins[1], loot.coins[2])
	coins = math.floor(coins / 50) * 50
	local crystals = math.random(loot.crystals[1], loot.crystals[2])
	local stats = player:FindFirstChild("leaderstats")
	local cash = stats and stats:FindFirstChild("Coins")
	if cash and cash:IsA("IntValue") then
		cash.Value += coins
	end
	local okCrystal, CrystalService = pcall(require, ServerScriptService:FindFirstChild("CrystalService") :: ModuleScript)
	if okCrystal and type(CrystalService) == "table" and CrystalService.Award then
		CrystalService.Award(player, crystals)
	end
	task.spawn(LevelSystem.AwardXP, player, loot.xp)
	local okContracts, ContractService = pcall(require, ServerScriptService:FindFirstChild("ContractService") :: ModuleScript)
	if okContracts and type(ContractService) == "table" and ContractService.Note then
		ContractService.Note(player, "supply")
	end
	return { coins = coins, crystals = crystals, xp = GameConfig.ShownXP(loot.xp), golden = golden }
end

--- Drop one crate now. Returns the landing position, or nil if no zone had room.
function SupplyDropService.Drop(zoneName: string?): Vector3?
	local zones = SupplyDropService.Zones
	local options = {}
	for _, zone in ipairs(zones) do
		if (zoneName and zone.name == zoneName) or (not zoneName and zone.name ~= lastZone) then
			table.insert(options, zone)
		end
	end
	if #options == 0 then
		options = zones
	end
	local zone = options[math.random(1, #options)]
	local landing = findLanding(zone)
	if not landing then
		warn(("[Supply] no clear ground found in %s"):format(zone.name))
		return nil
	end
	lastZone = zone.name

	nextId += 1
	local id = nextId
	active[id] = true
	local golden = math.random() < SupplyDropService.GOLDEN_CHANCE
	local restCf = CFrame.new(landing + Vector3.new(0, 1.7, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0)
	local startCf = restCf + Vector3.new(0, 260, 0)

	local beam = pillar(landing, golden)
	local model, root, chute = buildCrate(startCf, golden)
	model.Parent = folder()

	supplyEvent:FireAllClients("inbound", {
		id = id, position = landing, zone = zone.name, landsIn = SupplyDropService.FALL_TIME, golden = golden,
	})
	print(("[Supply] %s drop %d inbound to %s at %s"):format(golden and "GOLDEN" or "normal", id, zone.name,
		tostring(landing)))

	-- The fall: eased so it floats in rather than stopping dead.
	local fall = TweenService:Create(root, TweenInfo.new(SupplyDropService.FALL_TIME, Enum.EasingStyle.Sine,
		Enum.EasingDirection.Out), { CFrame = restCf })
	fall:Play()
	fall.Completed:Wait()

	if not model.Parent then
		return landing
	end
	-- Down: lose the parachute, go solid, start the flare, and wait for somebody.
	for _, d in ipairs(chute:GetDescendants()) do
		if d:IsA("BasePart") then
			TweenService:Create(d, TweenInfo.new(1.2), { Transparency = 1 }):Play()
		end
	end
	task.delay(1.3, function()
		chute:Destroy()
	end)
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and d.Name ~= "Beacon" then
			d.CanCollide = true
		end
	end
	smoke(root, golden)
	supplyEvent:FireAllClients("landed", { id = id, position = landing })

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = golden and "Elite Supply Drop" or "Supply Drop"
	prompt.HoldDuration = 2.5
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.Parent = root

	local opened = false
	local function finish(delaySeconds: number)
		active[id] = nil
		if beam.Parent then
			beam:Destroy()
		end
		task.delay(delaySeconds, function()
			if model.Parent then
				model:Destroy()
			end
			supplyEvent:FireAllClients("gone", { id = id })
		end)
	end

	prompt.Triggered:Connect(function(player: Player)
		if opened then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not humanoid or humanoid.Health <= 0 or not rootPart or not rootPart:IsA("BasePart")
			or (rootPart.Position - root.Position).Magnitude > 16 then
			return
		end
		opened = true
		prompt.Enabled = false
		local loot = award(player, golden)
		supplyEvent:FireClient(player, "loot", loot)
		supplyEvent:FireAllClients("opened", { id = id, by = player.DisplayName, position = landing, golden = golden })
		print(("[Supply] %s opened drop %d"):format(player.Name, id))

		-- The lid flies off, the flare dies down.
		local lid = model:FindFirstChild("Lid")
		if lid and lid:IsA("BasePart") then
			local weldTo = lid:FindFirstChildOfClass("WeldConstraint")
			if weldTo then
				weldTo:Destroy()
			end
			lid.Anchored = true
			TweenService:Create(lid, TweenInfo.new(0.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				CFrame = lid.CFrame * CFrame.new(1.5, 2.6, 0) * CFrame.Angles(0, 0, math.rad(-70)),
			}):Play()
		end
		local flare = root:FindFirstChild("Flare")
		if flare and flare:IsA("ParticleEmitter") then
			flare.Enabled = false
		end
		finish(20)
	end)

	-- Nobody came.
	task.delay(SupplyDropService.LIFETIME, function()
		if not opened then
			opened = true
			finish(0)
		end
	end)

	-- The beacon blinks.
	task.spawn(function()
		local beacon = model:FindFirstChild("Beacon")
		while model.Parent and not opened and beacon and beacon:IsA("BasePart") do
			beacon.Transparency = beacon.Transparency == 0 and 0.7 or 0
			task.wait(0.5)
		end
	end)

	return landing
end

--- Seconds until the next drop, for the HUD's "next drop" line.
local nextAt = os.clock() + SupplyDropService.FIRST_DELAY
function SupplyDropService.SecondsUntilNext(): number
	return math.max(0, nextAt - os.clock())
end

local function worldPlayers(): number
	local count = 0
	for _, p in ipairs(Players:GetPlayers()) do
		if p:GetAttribute("DuelState") ~= "duel" and p.Character then
			count += 1
		end
	end
	return count
end

task.spawn(function()
	while true do
		task.wait(math.max(1, nextAt - os.clock()))
		nextAt = os.clock() + SupplyDropService.INTERVAL
		-- Only when somebody is out in the world to race for it, and one at a time.
		if worldPlayers() > 0 and next(active) == nil then
			local ok, err = pcall(SupplyDropService.Drop)
			if not ok then
				warn("[Supply] drop failed: " .. tostring(err))
			end
		end
	end
end)

-- A player who joins mid-drop still gets the marker.
Players.PlayerAdded:Connect(function(player)
	task.wait(8)
	for _, crate in ipairs(folder():GetChildren()) do
		if crate:IsA("Model") and crate.PrimaryPart and crate:FindFirstChildWhichIsA("ProximityPrompt", true) then
			local prompt = crate:FindFirstChildWhichIsA("ProximityPrompt", true) :: ProximityPrompt
			if prompt.Enabled then
				supplyEvent:FireClient(player, "landed", {
					id = -1, position = crate.PrimaryPart.Position - Vector3.new(0, 1.7, 0),
					golden = crate.Name == "GoldenSupplyDrop", late = true,
				})
			end
		end
	end
end)

return SupplyDropService
