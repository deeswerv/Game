--!strict
-- HANAMI CITY's two fights. Both bosses are NPCs (NPCService does their moving, swinging and
-- dying); this decides when they appear, what their phases do, the hazards they throw, and
-- who gets paid.
--
-- FOREMAN TETSU, in the furnace yard of the Steelworks -- the mini-boss. A hammer and a temper:
--
--   I    THE SHIFT           him and his hammer
--   II   STOKE THE FURNACE   (60%) two Ronin come off the line, and molten splashes land where
--                            you stand -- an orange ring first, then the burn
--   III  OVERTIME            (30%) a Juggernaut joins, the splashes come faster, he speeds up
--
-- THE IRON SHOGUN, in his court at the top of the castle -- the final fight. Step into the court
-- and he rises from the throne (level 12 and over):
--
--   I    THE IRON BLADE      him and two Oni; every few seconds he draws back and sends a
--                            BLADE WAVE across the court -- a red strip, then the cut
--   II   BLOSSOM STORM       (66%) Shinobi drop from the walls and riflemen take the corners;
--                            petal storms open under everyone in the court -- pink rings
--   III  IRON FURY           (33%) a Juggernaut and more blades; two waves at once, faster
--                            storms, and he is quicker on his feet
--
-- Beating him the first time marks HanamiCleared on your profile, gives you the title
-- "Shogun Slayer", and pays the biggest purse in the game; after that, a smaller one. An empty
-- court resets the fight; beaten, he is back after a rest.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local TweenService = game:GetService("TweenService")

local HanamiConfig = require(ReplicatedStorage.HanamiConfig)
local KillCredit = require(ServerScriptService.KillCredit)

local Bosses = {}

Bosses.FOREMAN = {
	respawn = 480,
	phases = {
		{ at = 0.6, name = "STOKE THE FURNACE", line = "\"More heat! Pour it on 'em!\"", adds = { "Ronin", "Ronin" }, splashEvery = 6 },
		{ at = 0.3, name = "OVERTIME", line = "\"Nobody clocks off till you're scrap!\"", adds = { "Juggernaut", "Ronin" },
		  splashEvery = 3.5, speed = 1.25 },
	},
	splash = { radius = 7, damage = 34, warn = 1.4 },
	reach = 70,
	reward = { coins = 1500, xp = 1200, crystals = 6, cred = 8 },
}

Bosses.SHOGUN = {
	minLevel = 12,
	intro = 6,
	resetAfter = 25,
	cooldown = 90,
	baseHealth = 6000,
	perExtra = 0.6,
	guards = { "Oni", "Oni" },
	firstWaveEvery = 9,
	phases = {
		{ at = 0.66, name = "BLOSSOM STORM", line = "\"The blossoms fall for me. So will you.\"",
		  adds = { "Shinobi", "Shinobi", "Shinobi", "Rifleman", "Rifleman" }, ringEvery = 5, waveEvery = 8 },
		{ at = 0.33, name = "IRON FURY", line = "\"ENOUGH. Kneel before the Kurogane!\"",
		  adds = { "Juggernaut", "Ronin", "Ronin", "Shinobi" }, ringEvery = 3.2, waveEvery = 5.5, speed = 1.3, double = true },
	},
	ring = { radius = 6.5, damage = 32, warn = 1.3 },
	wave = { length = 50, width = 6, damage = 46, warn = 1.2 },
	first = { coins = 15000, xp = 8000, crystals = 40, cred = 40 },
	again = { coins = 3500, xp = 2500, crystals = 8, cred = 8 },
	title = "Shogun Slayer",
}

local H: any = nil

local function ensure(className: string, name: string): Instance
	local folder = ReplicatedStorage:FindFirstChild("Remotes") :: Instance
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = folder
	return made
end

local utilityEvent: RemoteEvent? = nil

local function replicaOf(player: Player): any
	local module = ServerScriptService:FindFirstChild("PlayerDataManager")
	if not module then
		return nil
	end
	local ok, replica = pcall(function()
		return (require(module :: ModuleScript) :: any):GetPlayerDataReplica(player):expect()
	end)
	return if ok then replica else nil
end

local function levelOf(player: Player): number
	local stats = player:FindFirstChild("Stats")
	local lv = stats and stats:FindFirstChild("Level")
	if lv and lv:IsA("IntValue") then
		return lv.Value
	end
	return math.max(1, math.floor(tonumber(player:GetAttribute("Level")) or 1))
end

local function alive(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

local function marker(name: string): BasePart?
	local folder = H and H.Folder()
	local found = folder and folder:FindFirstChild(name, true)
	return if found and found:IsA("BasePart") then found else nil
end

local function markers(name: string): { BasePart }
	local out = {}
	local folder = H and H.Folder()
	for _, d in ipairs(folder and folder:GetDescendants() or {}) do
		if d:IsA("BasePart") and d.Name == name then
			table.insert(out, d)
		end
	end
	return out
end

-- Damage each boss has taken, by who dealt it.
local dealtTo: { [Humanoid]: { [Player]: number } } = {}
KillCredit.Damaged.Event:Connect(function(humanoid: Humanoid, dealt: number, attacker: Player?)
	local book = dealtTo[humanoid]
	if book and attacker and type(dealt) == "number" then
		book[attacker] = (book[attacker] or 0) + dealt
	end
end)

-- ----------------------------------------------------------------- hazards --

local function hazards(): Folder
	local f = workspace:FindFirstChild("HanamiHazards")
	if f and f:IsA("Folder") then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "HanamiHazards"
	made.Parent = workspace
	return made
end

local function flatPart(name: string, size: Vector3, cf: CFrame, colour: Color3, transparency: number, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = Enum.Material.Neon
	p.Transparency = transparency
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = hazards()
	return p
end

--- Where the floor is under `at` (so a ring lies on whatever it is over).
local function floorUnder(at: Vector3): Vector3
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude: { Instance } = { hazards() }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(exclude, p.Character)
		end
	end
	local npcs = workspace:FindFirstChild("NPCs")
	if npcs then
		table.insert(exclude, npcs)
	end
	params.FilterDescendantsInstances = exclude
	local hit = workspace:Raycast(at + Vector3.new(0, 4, 0), Vector3.new(0, -14, 0), params)
	return if hit then hit.Position else at - Vector3.new(0, 2.8, 0)
end

--- A ring on the floor under `at`; after the warning, it bursts and hurts anyone in it.
function Bosses.Ring(at: Vector3, spec: { radius: number, damage: number, warn: number }, colour: Color3, cause: string)
	local floor = floorUnder(at)
	local ring = flatPart("BossRing", Vector3.new(0.14, spec.radius * 2, spec.radius * 2),
		CFrame.new(floor + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.rad(90)), colour, 0.45, Enum.PartType.Cylinder)
	local core = flatPart("BossRingCore", Vector3.new(0.16, 0.6, 0.6),
		CFrame.new(floor + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)), colour, 0.1, Enum.PartType.Cylinder)
	TweenService:Create(core, TweenInfo.new(spec.warn, Enum.EasingStyle.Linear), { Size = Vector3.new(0.16, spec.radius * 2, spec.radius * 2) }):Play()
	task.delay(spec.warn, function()
		if not ring.Parent then
			return
		end
		ring:Destroy()
		core:Destroy()
		if utilityEvent then
			utilityEvent:FireAllClients("explode", floor + Vector3.new(0, 0.6, 0), spec.radius)
		end
		for _, p in ipairs(Players:GetPlayers()) do
			local humanoid, root = alive(p)
			if humanoid and root then
				local d = root.Position - floor
				if Vector3.new(d.X, 0, d.Z).Magnitude <= spec.radius + 0.8 and math.abs(d.Y) < 8 then
					KillCredit.Damage(humanoid, spec.damage, nil, cause, Vector3.new(0, 1, 0))
				end
			end
		end
	end)
end

--- A blade wave from `from` along `dir`: a red strip on the floor, then the cut runs down it
--- and hurts anyone standing in it.
function Bosses.Wave(from: Vector3, dir: Vector3, spec: { length: number, width: number, damage: number, warn: number }, cause: string)
	local flat = Vector3.new(dir.X, 0, dir.Z)
	if flat.Magnitude < 0.1 then
		return
	end
	flat = flat.Unit
	local floor = floorUnder(from)
	local mid = floor + flat * (spec.length / 2)
	local frame = CFrame.lookAt(mid, mid + flat)
	local strip = flatPart("BladeStrip", Vector3.new(spec.width, 0.12, spec.length), frame + Vector3.new(0, 0.1, 0),
		Color3.fromRGB(230, 40, 50), 0.5)
	task.delay(spec.warn, function()
		if not strip.Parent then
			return
		end
		strip:Destroy()
		local slash = flatPart("BladeSlash", Vector3.new(spec.width + 2, 3.4, 1.2), CFrame.lookAt(floor + Vector3.new(0, 1.6, 0),
			floor + Vector3.new(0, 1.6, 0) + flat), Color3.fromRGB(255, 236, 240), 0.2)
		TweenService:Create(slash, TweenInfo.new(0.32, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			CFrame = slash.CFrame + flat * spec.length, Transparency = 0.8,
		}):Play()
		task.delay(0.4, function()
			slash:Destroy()
		end)
		for _, p in ipairs(Players:GetPlayers()) do
			local humanoid, root = alive(p)
			if humanoid and root then
				local rel = frame:PointToObjectSpace(root.Position)
				if math.abs(rel.X) <= spec.width / 2 + 0.8 and math.abs(rel.Z) <= spec.length / 2 and math.abs(rel.Y) < 8 then
					KillCredit.Damage(humanoid, spec.damage, nil, cause, flat)
				end
			end
		end
	end)
end

local function clearHazards()
	for _, h in ipairs(hazards():GetChildren()) do
		h:Destroy()
	end
end

-- ------------------------------------------------------------ the winners --

local function winnersOf(humanoid: Humanoid, near: Vector3, reach: number): { Player }
	local set: { [Player]: boolean } = {}
	for p, dealt in pairs(dealtTo[humanoid] or {}) do
		if p.Parent and dealt > 0 then
			set[p] = true
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		local _, root = alive(p)
		if root and (root.Position - near).Magnitude <= reach then
			set[p] = true
		end
	end
	local list = {}
	for p in pairs(set) do
		table.insert(list, p)
	end
	return list
end

local function spawnAdds(list: { string }, spots: { Vector3 }, into: { Model }, tag: string)
	for i, archetype in ipairs(list) do
		local spot = spots[(i - 1) % math.max(#spots, 1) + 1]
		if spot then
			local model = H.Spawn(archetype, HanamiConfig.Local(spot), { [tag] = true })
			if model then
				table.insert(into, model)
			end
		end
	end
end

local function clearList(list: { Model })
	for _, m in ipairs(list) do
		if m.Parent then
			m:Destroy()
		end
	end
	table.clear(list)
end

-- ----------------------------------------------------------------- foreman --

type Foreman = { model: Model?, humanoid: Humanoid?, phase: number, nextSplash: number, adds: { Model }, deadAt: number? }
local foreman: Foreman = { model = nil, humanoid = nil, phase = 1, nextSplash = math.huge, adds = {}, deadAt = nil }

local function foremanDown()
	local f = foreman
	local humanoid = f.humanoid
	local model = f.model
	f.model, f.humanoid = nil, nil
	f.deadAt = H.Clock()
	clearHazards()
	task.delay(5, function()
		clearList(f.adds)
	end)
	if not humanoid then
		return
	end
	local root = model and model:FindFirstChild("HumanoidRootPart")
	local near = if root and root:IsA("BasePart") then root.Position else HanamiConfig.Site("Foundry")
	local reward = Bosses.FOREMAN.reward
	local names = {}
	for _, p in ipairs(winnersOf(humanoid, near, Bosses.FOREMAN.reach + 20)) do
		H.Pay(p, reward)
		H.Note(p, "boss", { boss = "Foreman" })
		H.Event:FireClient(p, "bossWon", { name = "FOREMAN TETSU", coins = reward.coins, xp = reward.xp, crystals = reward.crystals,
			cred = reward.cred })
		table.insert(names, p.DisplayName)
	end
	dealtTo[humanoid] = nil
	for _, p in ipairs(H.Inside()) do
		H.Event:FireClient(p, "announce", { title = "FOREMAN TETSU IS DOWN", names = names })
	end
	print(("[Hanami] Foreman Tetsu is down (%s)"):format(table.concat(names, ", ")))
end

local function spawnForeman()
	local spot = marker("ForemanSpot")
	if not spot then
		return
	end
	local marks = {}
	for _, phase in ipairs(Bosses.FOREMAN.phases) do
		table.insert(marks, tostring(phase.at))
	end
	local model = H.Spawn("Foreman", HanamiConfig.Local(spot.Position), { Boss = true, PhaseMarks = table.concat(marks, ","), Phase = 1,
		HanamiBoss = "Foreman" })
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not model or not humanoid then
		foreman.deadAt = H.Clock() - Bosses.FOREMAN.respawn + 15
		return
	end
	foreman.model, foreman.humanoid, foreman.phase, foreman.nextSplash, foreman.deadAt = model, humanoid, 1, math.huge, nil
	dealtTo[humanoid] = {}
	humanoid.Died:Connect(function()
		if foreman.humanoid == humanoid then
			foremanDown()
		end
	end)
end

local function stepForeman(now: number)
	local f = foreman
	if not H.Awake() then
		if f.model and f.model.Parent then
			f.model:Destroy()
		end
		f.model, f.humanoid = nil, nil
		clearList(f.adds)
		return
	end
	if not f.model then
		if not f.deadAt or now - f.deadAt >= Bosses.FOREMAN.respawn then
			spawnForeman()
		end
		return
	end
	local humanoid = f.humanoid :: Humanoid
	if humanoid.Health <= 0 then
		-- Down (Died normally gets here first; this catches the rest).
		foremanDown()
		return
	end
	if not f.model.Parent then
		-- Gone without dying (cleared away): back after the usual rest, nobody paid.
		f.model, f.humanoid, f.deadAt = nil, nil, now
		dealtTo[humanoid] = nil
		clearList(f.adds)
		return
	end
	local root = f.model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local fraction = humanoid.Health / math.max(humanoid.MaxHealth, 1)
	local nextPhase = Bosses.FOREMAN.phases[f.phase]
	if nextPhase and fraction <= nextPhase.at then
		f.phase += 1
		f.model:SetAttribute("Phase", f.phase)
		f.nextSplash = now + 2
		if nextPhase.speed then
			humanoid.WalkSpeed *= nextPhase.speed
		end
		local spots = {}
		for _, m in ipairs(markers("ForemanAddSpot")) do
			table.insert(spots, m.Position)
		end
		spawnAdds(nextPhase.adds, spots, f.adds, "ForemanCrew")
		for _, p in ipairs(H.Inside()) do
			local _, r = alive(p)
			if r and (r.Position - root.Position).Magnitude < 120 then
				H.Event:FireClient(p, "bossPhase", { name = nextPhase.name, line = nextPhase.line, boss = "FOREMAN TETSU" })
			end
		end
	end
	local phase = Bosses.FOREMAN.phases[f.phase - 1]
	if phase and now >= f.nextSplash then
		f.nextSplash = now + phase.splashEvery
		for _, p in ipairs(H.Inside()) do
			local _, r = alive(p)
			if r and (r.Position - root.Position).Magnitude <= Bosses.FOREMAN.reach then
				Bosses.Ring(r.Position, Bosses.FOREMAN.splash, Color3.fromRGB(255, 130, 40), "Foreman Tetsu's Molten Splash")
			end
		end
	end
end

-- ------------------------------------------------------------------ shogun --

type Shogun = {
	state: string,               -- idle | intro | fight | cooldown
	model: Model?, humanoid: Humanoid?,
	phase: number,
	adds: { Model },
	startAt: number, readyAt: number, emptySince: number?,
	nextWave: number, nextRing: number,
	warned: { [Player]: number },
}
local shogun: Shogun = { state = "idle", model = nil, humanoid = nil, phase = 1, adds = {}, startAt = 0, readyAt = 0,
	emptySince = nil, nextWave = math.huge, nextRing = math.huge, warned = {} }

--- Players standing in the Shogun's court right now.
function Bosses.InCourt(): { Player }
	local box = HanamiConfig.CourtBox
	local list = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local _, root = alive(p)
		if root then
			local l = HanamiConfig.Local(root.Position)
			if l.X >= box.x0 and l.X <= box.x1 and l.Z >= box.z0 and l.Z <= box.z1 and l.Y > HanamiConfig.PLATEAU - 6 then
				table.insert(list, p)
			end
		end
	end
	return list
end

local function tellCourt(kind: string, data: { [string]: any })
	for _, p in ipairs(Bosses.InCourt()) do
		H.Event:FireClient(p, kind, data)
	end
end

local function shogunEnd(won: boolean)
	local s = shogun
	local model, humanoid = s.model, s.humanoid
	s.model, s.humanoid = nil, nil
	clearHazards()
	if not won then
		clearList(s.adds)
		if model and model.Parent then
			model:Destroy()
		end
		if humanoid then
			dealtTo[humanoid] = nil
		end
		s.state = "idle"
		return
	end
	s.state = "cooldown"
	s.readyAt = H.Clock() + Bosses.SHOGUN.cooldown
	task.delay(6, function()
		clearList(s.adds)
	end)
	if not humanoid then
		return
	end
	local root = model and model:FindFirstChild("HumanoidRootPart")
	local near = if root and root:IsA("BasePart") then root.Position else HanamiConfig.Site("Court")
	local names = {}
	for _, p in ipairs(winnersOf(humanoid, near, 110)) do
		local replica = replicaOf(p)
		local first = not (replica and replica.Data.HanamiCleared == true) and p:GetAttribute("HanamiCleared") ~= true
		local reward = if first then Bosses.SHOGUN.first else Bosses.SHOGUN.again
		H.Pay(p, reward)
		if replica then
			replica:SetValue("HanamiCleared", true)
			replica:SetValue("HanamiClears", (tonumber(replica.Data.HanamiClears) or 0) + 1)
			local titles = table.clone(replica.Data.Titles or {})
			if not table.find(titles, Bosses.SHOGUN.title) then
				table.insert(titles, Bosses.SHOGUN.title)
				replica:SetValue("Titles", titles)
			end
		end
		p:SetAttribute("HanamiCleared", true)
		H.Note(p, "boss", { boss = "Shogun" })
		H.Event:FireClient(p, "bossWon", { name = "THE IRON SHOGUN", first = first, coins = reward.coins, xp = reward.xp,
			crystals = reward.crystals, cred = reward.cred, title = if first then Bosses.SHOGUN.title else nil, final = true })
		table.insert(names, p.DisplayName)
	end
	dealtTo[humanoid] = nil
	for _, p in ipairs(Players:GetPlayers()) do
		H.Event:FireClient(p, "announce", { title = "THE IRON SHOGUN HAS FALLEN", names = names, big = true })
	end
	print(("[Hanami] the Iron Shogun is down (%s)"):format(table.concat(names, ", ")))
end

local function shogunStart()
	local s = shogun
	local spot = marker("ShogunSpot")
	if not spot then
		s.state = "idle"
		return
	end
	local count = math.max(1, #Bosses.InCourt())
	local marks = {}
	for _, phase in ipairs(Bosses.SHOGUN.phases) do
		table.insert(marks, tostring(phase.at))
	end
	local model = H.Spawn("Shogun", HanamiConfig.Local(spot.Position), { Boss = true, PhaseMarks = table.concat(marks, ","), Phase = 1,
		HanamiBoss = "Shogun" })
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not model or not humanoid then
		s.state = "idle"
		return
	end
	model.Name = "The Iron Shogun"
	local health = math.floor(Bosses.SHOGUN.baseHealth * (1 + Bosses.SHOGUN.perExtra * (count - 1)))
	humanoid.MaxHealth = health
	humanoid.Health = health
	dealtTo[humanoid] = {}
	s.model, s.humanoid, s.phase = model, humanoid, 1
	s.state = "fight"
	local now = H.Clock()
	s.nextWave = now + 4
	s.nextRing = math.huge
	local spots = {}
	for i, side in ipairs({ -1, 1 }) do
		spots[i] = spot.Position + Vector3.new(side * 8, 0, -4)
	end
	spawnAdds(Bosses.SHOGUN.guards, spots, s.adds, "ShogunGuard")
	humanoid.Died:Connect(function()
		if shogun.humanoid == humanoid then
			shogunEnd(true)
		end
	end)
	tellCourt("bossStart", { name = "THE IRON SHOGUN", health = health, players = count })
	print(("[Hanami] the Iron Shogun rises: %d health for %d"):format(health, count))
end

local function stepShogun(now: number)
	local s = shogun
	local court = Bosses.InCourt()
	local anyone = #court > 0
	if anyone then
		s.emptySince = nil
	elseif s.emptySince == nil then
		s.emptySince = now
	end
	if s.state == "cooldown" then
		if now < s.readyAt then
			return
		end
		s.state = "idle"
	end
	if s.state == "idle" then
		local ready = {}
		for _, p in ipairs(court) do
			if levelOf(p) >= Bosses.SHOGUN.minLevel then
				table.insert(ready, p)
			elseif now - (s.warned[p] or -math.huge) > 20 then
				s.warned[p] = now
				H.Event:FireClient(p, "note", { title = "The Shogun does not look up",
					text = ("He fights no one under level %d"):format(Bosses.SHOGUN.minLevel) })
			end
		end
		if #ready > 0 then
			s.state = "intro"
			s.startAt = now + Bosses.SHOGUN.intro
			tellCourt("bossIntro", { name = "THE IRON SHOGUN", seconds = Bosses.SHOGUN.intro,
				line = "\"You climbed the Thousand Gates to die in my court? Then kneel -- or draw.\"" })
		end
		return
	end
	if s.state == "intro" then
		if not anyone then
			s.state = "idle"
		elseif now >= s.startAt then
			shogunStart()
		end
		return
	end
	local model, humanoid = s.model, s.humanoid
	if model and humanoid and humanoid.Health <= 0 then
		-- Down (Died normally gets here first; this catches the rest).
		shogunEnd(true)
		return
	end
	if not model or not humanoid or not model.Parent then
		shogunEnd(false)
		return
	end
	if not anyone and s.emptySince and now - s.emptySince >= Bosses.SHOGUN.resetAfter then
		shogunEnd(false)
		for _, p in ipairs(H.Inside()) do
			H.Event:FireClient(p, "bossReset", { name = "THE IRON SHOGUN" })
		end
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	-- Phases, off his health.
	local fraction = humanoid.Health / math.max(humanoid.MaxHealth, 1)
	local nextPhase = Bosses.SHOGUN.phases[s.phase]
	if nextPhase and fraction <= nextPhase.at then
		s.phase += 1
		model:SetAttribute("Phase", s.phase)
		s.nextRing = now + 2
		if nextPhase.speed then
			humanoid.WalkSpeed *= nextPhase.speed
		end
		local spots = {}
		for _, m in ipairs(markers("CourtAddSpot")) do
			table.insert(spots, m.Position)
		end
		spawnAdds(nextPhase.adds, spots, s.adds, "ShogunGuard")
		tellCourt("bossPhase", { name = nextPhase.name, line = nextPhase.line, boss = "THE IRON SHOGUN" })
	end
	local phase = Bosses.SHOGUN.phases[s.phase - 1]
	-- The blade wave, at whoever is nearest; two at once in his fury.
	if now >= s.nextWave and #court > 0 then
		s.nextWave = now + (if phase then phase.waveEvery else Bosses.SHOGUN.firstWaveEvery)
		local target, best = nil, math.huge
		for _, p in ipairs(court) do
			local _, r = alive(p)
			if r and (r.Position - root.Position).Magnitude < best then
				target, best = r, (r.Position - root.Position).Magnitude
			end
		end
		if target then
			local dir = target.Position - root.Position
			Bosses.Wave(root.Position, dir, Bosses.SHOGUN.wave, "The Iron Shogun's Blade Wave")
			if phase and phase.double then
				for _, turn in ipairs({ -0.45, 0.45 }) do
					Bosses.Wave(root.Position, CFrame.Angles(0, turn, 0):VectorToWorldSpace(dir), Bosses.SHOGUN.wave,
						"The Iron Shogun's Blade Wave")
				end
			end
		end
	end
	-- The petal storms, under everyone in the court.
	if phase and now >= s.nextRing then
		s.nextRing = now + phase.ringEvery
		for _, p in ipairs(court) do
			local _, r = alive(p)
			if r then
				Bosses.Ring(r.Position, Bosses.SHOGUN.ring, Color3.fromRGB(255, 120, 170), "The Iron Shogun's Petal Storm")
			end
		end
	end
end

function Bosses.State(): string
	return shogun.state
end

function Bosses.Shogun(): Model?
	return shogun.model
end

function Bosses.Foreman(): Model?
	return foreman.model
end

-- ------------------------------------------------------------------ wiring --

function Bosses.Init(service: any)
	H = service
	utilityEvent = ensure("RemoteEvent", "UtilityEvent") :: RemoteEvent
	-- HanamiCleared is published from the profile on join (the Travel menu and quests read it).
	local function publish(player: Player)
		task.spawn(function()
			local replica = replicaOf(player)
			if replica and player.Parent then
				player:SetAttribute("HanamiCleared", replica.Data.HanamiCleared == true or nil)
			end
		end)
	end
	Players.PlayerAdded:Connect(publish)
	for _, p in ipairs(Players:GetPlayers()) do
		publish(p)
	end
end

function Bosses.Wire(_folder: Instance)
	-- Nothing to wire: the bosses find their markers when they need them.
end

function Bosses.Step(now: number)
	stepForeman(now)
	stepShogun(now)
end

return Bosses
