--!strict
-- ZEE TOWER: the elevator to the penthouse, and the fight with the Don up there.
--
-- The lobby doors at the foot of the tower take you up (level 8 and over); the elevator on
-- the roof brings you down. The first person up wakes the room: a few seconds of the Don's
-- welcome, then he steps out with two bodyguards, his health scaled to however many of you
-- came up. Three phases, read off his health:
--
--   I    THE NEGOTIATION   the Don and his bodyguards
--   II   FAMILY BUSINESS   (70%) the family comes up the elevator, and money bombs land where
--                          you stand -- a red ring on the floor, then the blast
--   III  LAST STAND        (40%) more of the family, the bombs come faster, and his helicopter
--                          lifts off the pad and circles the roof, strafing a line across it
--                          (a red strip first -- get off it)
--
-- Beat him and everyone up there (and anyone who put damage in) is paid, and the FIRST time
-- you beat him the world past Downtown opens: TowerCleared is saved on your profile, and
-- the Travel menu and the Quartermaster read it. Nobody left on the roof for a while and the
-- fight resets; beaten, the Don is back after a rest.
--
-- Server-owned throughout. Players on the roof carry the InTower attribute (supply drops and
-- the HUD read it); TowerCleared is published as an attribute from the profile on join.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local KillCredit = require(ServerScriptService.KillCredit)
local LevelSystem = require(ServerScriptService.LevelSystem)
local GameConfig = require(ReplicatedStorage.GameConfig)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)

local TowerService = {}

TowerService.Clock = os.clock
TowerService.MIN_LEVEL = 8
TowerService.INTRO = 6                -- the welcome, before the Don steps out
TowerService.RESET_AFTER = 25         -- an empty roof resets the fight
TowerService.COOLDOWN = 60            -- after he falls, before he is back
TowerService.BASE_HEALTH = 5200
TowerService.PER_EXTRA = 0.6          -- health added per extra player on the roof, as a share
TowerService.BODYGUARDS = { "Enforcer", "Enforcer" }
TowerService.PHASES = {
	{ at = 0.7, name = "FAMILY BUSINESS", line = "\"Boys! We've got company on the roof.\"",
	  adds = { "Capo", "Shooter", "Gangster" }, bombEvery = 7 },
	{ at = 0.4, name = "LAST STAND", line = "\"Get the chopper up. Nobody walks off my roof.\"",
	  adds = { "Enforcer", "Shooter", "Gangster", "Gangster" }, bombEvery = 5, heli = true },
}
TowerService.BOMB = { radius = 8, damage = 42, warn = 1.6 }
TowerService.STRAFE = { every = 6, warn = 1.5, width = 5, length = 100, damage = 38 }
TowerService.FIRST_REWARD = { coins = 8000, xp = 4000, crystals = 25, cred = 25 }
TowerService.REPEAT_REWARD = { coins = 2000, xp = 1500, crystals = 4, cred = 5 }

local function ensure(className: string, name: string): Instance
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
local towerEvent = ensure("RemoteEvent", "TowerEvent") :: RemoteEvent
local utilityEvent = ensure("RemoteEvent", "UtilityEvent") :: RemoteEvent

local function service(name: string): any
	local module = ServerScriptService:FindFirstChild(name)
	if not module then
		return nil
	end
	local ok, loaded = pcall(require, module :: ModuleScript)
	return if ok and type(loaded) == "table" then loaded else nil
end

local function replicaOf(player: Player): any
	local ok, replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
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

-- ------------------------------------------------------------------ the roof --

local markers: { [string]: any } = {}

--- The roof's markers, found once in the built district.
local function marker(name: string): BasePart?
	local cached = markers[name]
	if cached and cached.Parent then
		return cached
	end
	local district = workspace:FindFirstChild("Downtown")
	local found = district and district:FindFirstChild(name, true)
	if found and found:IsA("BasePart") then
		markers[name] = found
		return found
	end
	return nil
end

local function addSpots(): { Vector3 }
	local district = workspace:FindFirstChild("Downtown")
	local out = {}
	for _, d in ipairs(district and district:GetDescendants() or {}) do
		if d:IsA("BasePart") and d.Name == "TowerAddSpot" then
			table.insert(out, d.Position)
		end
	end
	return out
end

local function hazards(): Folder
	local f = workspace:FindFirstChild("TowerHazards")
	if f and f:IsA("Folder") then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "TowerHazards"
	made.Parent = workspace
	return made
end

-- ------------------------------------------------------------------ state --

type Fight = {
	don: Model,
	humanoid: Humanoid,
	phase: number,
	adds: { Model },
	damage: { [Player]: number },
	nextBomb: number,
	nextStrafe: number,
	heliAt: number?,
}

local inside: { [Player]: boolean } = {}
local state = "idle"                 -- idle | intro | fight | cooldown
local startAt = 0
local readyAt = 0
local emptySince: number? = nil
local fight: Fight? = nil

function TowerService.State(): string
	return state
end

function TowerService.Inside(): { Player }
	local list = {}
	for p in pairs(inside) do
		if p.Parent then
			table.insert(list, p)
		end
	end
	return list
end

function TowerService.Don(): Model?
	local f = fight
	return f and f.don or nil
end

local function tell(kind: string, data: { [string]: any })
	for _, p in ipairs(TowerService.Inside()) do
		towerEvent:FireClient(p, kind, data)
	end
end

KillCredit.Damaged.Event:Connect(function(humanoid: Humanoid, dealt: number, attacker: Player?)
	local f = fight
	if f and humanoid == f.humanoid and attacker and type(dealt) == "number" then
		f.damage[attacker] = (f.damage[attacker] or 0) + dealt
	end
end)

-- ------------------------------------------------------------------ in and out --

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function placeAt(player: Player, cf: CFrame)
	local character = player.Character
	local root = rootOf(player)
	if not character or not root then
		return
	end
	root.AssemblyLinearVelocity = Vector3.zero
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 3)
	end)
	character:PivotTo(cf)
end

--- Why `player` may not go up right now, or nil.
function TowerService.Blocked(player: Player): string?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return "You need to be alive"
	end
	if player:GetAttribute("DuelState") == "duel" then
		return "Finish your duel first"
	end
	if levelOf(player) < TowerService.MIN_LEVEL then
		return ("The Don's people don't let just anyone up. Come back at level %d."):format(TowerService.MIN_LEVEL)
	end
	if not marker("TowerArrival") then
		return "The elevator is out of order"
	end
	return nil
end

--- Up the elevator to the penthouse.
function TowerService.Enter(player: Player): (boolean, string?)
	if inside[player] then
		return false, "You are already up there"
	end
	local why = TowerService.Blocked(player)
	if why then
		towerEvent:FireClient(player, "denied", { reason = why })
		return false, why
	end
	local arrival = marker("TowerArrival") :: BasePart
	local at = arrival.Position + Vector3.new((math.random() - 0.5) * 3, 3.2, (math.random() - 0.5) * 2)
	placeAt(player, CFrame.lookAt(at, at + Vector3.new(0, 0, -1)))
	inside[player] = true
	player:SetAttribute("InTower", true)
	emptySince = nil
	towerEvent:FireClient(player, "enter", {
		state = state, cleared = player:GetAttribute("TowerCleared") == true,
		readyIn = if state == "cooldown" then math.max(0, math.ceil(readyAt - TowerService.Clock())) else nil,
	})
	return true, nil
end

--- Down the elevator, out onto the street at the foot of the tower.
function TowerService.Leave(player: Player): boolean
	if not inside[player] then
		return false
	end
	inside[player] = nil
	player:SetAttribute("InTower", nil)
	local door = marker("TowerDoor")
	if door then
		local at = door.Position + Vector3.new(0, 3.2, -6)
		placeAt(player, CFrame.lookAt(at, at + Vector3.new(0, 0, -1)))
	end
	towerEvent:FireClient(player, "left", {})
	return true
end

local function forget(player: Player)
	inside[player] = nil
	if player.Parent then
		player:SetAttribute("InTower", nil)
	end
end

-- ------------------------------------------------------------------ the fight --

local function spawnAt(archetype: string, at: Vector3, attributes: { [string]: any }?): Model?
	local NPCService = service("NPCService")
	if not NPCService or not NPCService.Spawn then
		return nil
	end
	local model = NPCService.Spawn(archetype, at + Vector3.new(0, 3, 0), { respawn = false, ignoreCap = true,
		attributes = attributes })
	return model
end

local function startFight()
	local spot = marker("TowerBossSpot")
	if not spot then
		state = "idle"
		return
	end
	local count = math.max(1, #TowerService.Inside())
	local don = spawnAt("TheDon", spot.Position, { TowerBoss = true, Boss = true })
	local humanoid = don and don:FindFirstChildOfClass("Humanoid")
	if not don or not humanoid then
		state = "idle"
		return
	end
	don.Name = "THE DON"
	local health = math.floor(TowerService.BASE_HEALTH * (1 + TowerService.PER_EXTRA * (count - 1)))
	humanoid.MaxHealth = health
	humanoid.Health = health
	local marks = {}
	for _, phase in ipairs(TowerService.PHASES) do
		table.insert(marks, tostring(phase.at))
	end
	don:SetAttribute("PhaseMarks", table.concat(marks, ","))
	don:SetAttribute("Phase", 1)
	local now = TowerService.Clock()
	local f: Fight = { don = don, humanoid = humanoid, phase = 1, adds = {}, damage = {}, nextBomb = math.huge,
		nextStrafe = math.huge, heliAt = nil }
	for i, archetype in ipairs(TowerService.BODYGUARDS) do
		local side = if i % 2 == 0 then 1 else -1
		local guard = spawnAt(archetype, spot.Position + Vector3.new(side * 6, 0, -3), { TowerCrew = true })
		if guard then
			table.insert(f.adds, guard)
		end
	end
	fight = f
	state = "fight"
	startAt = now
	tell("start", { name = "THE DON", health = health, players = count })
	print(("[Tower] the Don steps out: %d health for %d"):format(health, count))
end

-- The helicopter: every part of DonHeli, where it rests, and the pose it is in now.
local heliParts: { { part: BasePart, rest: CFrame } }? = nil
local heliRest: CFrame? = nil
local function heli(): ({ { part: BasePart, rest: CFrame } }?, CFrame?)
	if heliParts then
		return heliParts, heliRest
	end
	local district = workspace:FindFirstChild("Downtown")
	local folder = district and district:FindFirstChild("DonHeli", true)
	local body = folder and folder:FindFirstChild("HeliBody")
	if not folder or not body or not body:IsA("BasePart") then
		return nil, nil
	end
	local list = {}
	for _, d in ipairs(folder:GetChildren()) do
		if d:IsA("BasePart") then
			table.insert(list, { part = d, rest = d.CFrame })
		end
	end
	heliParts, heliRest = list, body.CFrame
	return list, body.CFrame
end

local function poseHeli(pose: CFrame?, spin: number)
	local parts, rest = heli()
	if not parts or not rest then
		return
	end
	for _, entry in ipairs(parts) do
		if pose then
			local rel = rest:ToObjectSpace(entry.rest)
			if entry.part.Name == "Rotor" then
				rel = CFrame.new(rel.Position) * CFrame.Angles(0, spin, 0) * rel.Rotation
			end
			entry.part.CFrame = pose * rel
		else
			entry.part.CFrame = entry.rest
		end
	end
end

--- A money bomb: a red ring on the floor under `at`, then the blast -- players only.
local function moneyBomb(at: Vector3)
	local b = TowerService.BOMB
	local ring = Instance.new("Part")
	ring.Name = "MoneyBomb"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.12, b.radius * 2, b.radius * 2)
	ring.CFrame = CFrame.new(at.X, at.Y + 0.08, at.Z) * CFrame.Angles(0, 0, math.rad(90))
	ring.Color = Color3.fromRGB(232, 40, 40)
	ring.Material = Enum.Material.SmoothPlastic
	ring.Transparency = 0.45
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.Parent = hazards()
	local bag = ring:Clone()
	bag.Name = "MoneyBag"
	bag.Shape = Enum.PartType.Ball
	bag.Size = Vector3.new(1.4, 1.4, 1.4)
	bag.CFrame = CFrame.new(at.X, at.Y + 0.7, at.Z)
	bag.Color = Color3.fromRGB(110, 170, 96)
	bag.Transparency = 0
	bag.Parent = ring
	task.delay(b.warn, function()
		if not ring.Parent then
			return
		end
		ring:Destroy()
		utilityEvent:FireAllClients("explode", at + Vector3.new(0, 0.6, 0), b.radius)
		for _, p in ipairs(TowerService.Inside()) do
			local root = rootOf(p)
			local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				local d = (root.Position - at).Magnitude
				if d <= b.radius + 1 then
					local share = math.max(0.35, 1 - d / (b.radius + 1))
					KillCredit.Damage(humanoid, b.damage * share, nil, "The Don's Money Bomb", (root.Position - at).Unit)
				end
			end
		end
	end)
end

--- A strafing run: a red strip across the roof through `through`, then the guns.
local function strafe(through: Vector3, deckY: number)
	local s = TowerService.STRAFE
	local angle = math.random() * math.pi
	local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local strip = Instance.new("Part")
	strip.Name = "StrafeLine"
	strip.Size = Vector3.new(s.width, 0.1, s.length)
	strip.CFrame = CFrame.lookAt(Vector3.new(through.X, deckY + 0.1, through.Z),
		Vector3.new(through.X, deckY + 0.1, through.Z) + dir)
	strip.Color = Color3.fromRGB(232, 40, 40)
	strip.Material = Enum.Material.SmoothPlastic
	strip.Transparency = 0.5
	strip.Anchored = true
	strip.CanCollide = false
	strip.CanQuery = false
	strip.CanTouch = false
	strip.CastShadow = false
	strip.Parent = hazards()
	task.delay(s.warn, function()
		if not strip.Parent then
			return
		end
		local cf = strip.CFrame
		strip:Destroy()
		for k = -3, 3 do
			utilityEvent:FireAllClients("explode", (cf * CFrame.new(0, 0.5, k * s.length / 7)).Position, 3)
		end
		for _, p in ipairs(TowerService.Inside()) do
			local root = rootOf(p)
			local humanoid = p.Character and p.Character:FindFirstChildOfClass("Humanoid")
			if root and humanoid and humanoid.Health > 0 then
				local rel = cf:PointToObjectSpace(root.Position)
				if math.abs(rel.X) <= s.width / 2 + 1 and math.abs(rel.Z) <= s.length / 2 and math.abs(rel.Y) < 8 then
					KillCredit.Damage(humanoid, s.damage, nil, "The Don's Helicopter", nil)
				end
			end
		end
	end)
end

local function clearAdds(f: Fight)
	for _, m in ipairs(f.adds) do
		if m.Parent then
			m:Destroy()
		end
	end
	table.clear(f.adds)
end

local function pay(player: Player, reward: { [string]: number })
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value += reward.coins
	end
	local Crystals = service("CrystalService")
	if Crystals and Crystals.Award then
		Crystals.Award(player, reward.crystals)
	end
	task.spawn(LevelSystem.AwardXP, player, reward.xp)
	local Turf = service("TurfWarService")
	if Turf and Turf.AddCred then
		Turf.AddCred(player, reward.cred)
	end
end

local function finish(won: boolean)
	local f = fight
	fight = nil
	poseHeli(nil, 0)
	for _, h in ipairs(hazards():GetChildren()) do
		h:Destroy()
	end
	if not f then
		state = "idle"
		return
	end
	if not won then
		clearAdds(f)
		if f.don.Parent then
			f.don:Destroy()
		end
		state = "idle"
		print("[Tower] nobody left on the roof; the fight resets")
		return
	end

	state = "cooldown"
	readyAt = TowerService.Clock() + TowerService.COOLDOWN
	local winners: { [Player]: boolean } = {}
	for _, p in ipairs(TowerService.Inside()) do
		winners[p] = true
	end
	for p, dealt in pairs(f.damage) do
		if p.Parent and dealt > 0 then
			winners[p] = true
		end
	end
	local names = {}
	for p in pairs(winners) do
		local replica = replicaOf(p)
		local first = not (replica and replica.Data.TowerCleared == true) and p:GetAttribute("TowerCleared") ~= true
		local reward = if first then TowerService.FIRST_REWARD else TowerService.REPEAT_REWARD
		pay(p, reward)
		if replica then
			replica:SetValue("TowerCleared", true)
			replica:SetValue("TowerClears", (tonumber(replica.Data.TowerClears) or 0) + 1)
		end
		p:SetAttribute("TowerCleared", true)
		towerEvent:FireClient(p, "cleared", {
			first = first, coins = reward.coins, xp = GameConfig.ShownXP(reward.xp), crystals = reward.crystals,
			cred = reward.cred, damage = math.floor(f.damage[p] or 0),
		})
		local Contracts = service("ContractService")
		if Contracts and Contracts.Note then
			task.spawn(Contracts.Note, p, "tower")
		end
		local Quests = service("QuestService")
		if Quests and Quests.RegisterEvent then
			task.spawn(Quests.RegisterEvent, p, "tower", {})
		end
		table.insert(names, p.DisplayName)
	end
	towerEvent:FireAllClients("announce", { names = names })
	print(("[Tower] the Don is down (%s)"):format(table.concat(names, ", ")))
	-- His people do not stay long without him.
	task.delay(6, function()
		clearAdds(f)
	end)
end

--- One tick of the roof.
function TowerService.Step()
	local now = TowerService.Clock()
	for p in pairs(inside) do
		local character = p.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not p.Parent or not humanoid or humanoid.Health <= 0 then
			forget(p)
		end
	end
	local anyone = next(inside) ~= nil
	if anyone then
		emptySince = nil
	elseif emptySince == nil then
		emptySince = now
	end

	if state == "cooldown" then
		if now < readyAt then
			return
		end
		state = "idle"
	end
	if state == "idle" then
		if anyone then
			state = "intro"
			startAt = now + TowerService.INTRO
			tell("intro", { seconds = TowerService.INTRO,
				line = "\"So. The one who's been breaking my crews. Come in -- enjoy the view. It's the last one you'll get.\"" })
		end
		return
	end
	if state == "intro" then
		if not anyone then
			state = "idle"
		elseif now >= startAt then
			startFight()
		end
		return
	end

	local f = fight
	if not f then
		state = "idle"
		return
	end
	if not f.humanoid.Parent or not f.don.Parent or f.humanoid.Health <= 0 then
		finish(true)
		return
	end
	if not anyone and emptySince and now - emptySince >= TowerService.RESET_AFTER then
		finish(false)
		tell("reset", {})
		return
	end

	-- Phases.
	local fraction = f.humanoid.Health / math.max(1, f.humanoid.MaxHealth)
	local nextPhase = TowerService.PHASES[f.phase]
	if nextPhase and fraction <= nextPhase.at then
		f.phase += 1
		f.don:SetAttribute("Phase", f.phase)
		local spots = addSpots()
		for i, archetype in ipairs(nextPhase.adds) do
			local at = spots[(i - 1) % math.max(1, #spots) + 1]
			if at then
				local add = spawnAt(archetype, at + Vector3.new((math.random() - 0.5) * 4, 0, (math.random() - 0.5) * 4),
					{ TowerCrew = true })
				if add then
					table.insert(f.adds, add)
				end
			end
		end
		f.nextBomb = now + 2
		if nextPhase.heli then
			f.heliAt = now
			f.nextStrafe = now + 4
		end
		tell("phase", { phase = f.phase, name = nextPhase.name, line = nextPhase.line })
	end

	-- Money bombs, under whoever is up there.
	local phase = TowerService.PHASES[f.phase - 1]
	if phase and now >= f.nextBomb then
		f.nextBomb = now + phase.bombEvery
		for i, p in ipairs(TowerService.Inside()) do
			local root = rootOf(p)
			if root and i <= 4 then
				moneyBomb(Vector3.new(root.Position.X, root.Position.Y - 3, root.Position.Z)
					+ Vector3.new((math.random() - 0.5) * 4, 0, (math.random() - 0.5) * 4))
			end
		end
	end

	-- The helicopter: up off the pad, round the roof, a strafing run every few seconds.
	if f.heliAt then
		local _, rest = heli()
		local spot = marker("TowerBossSpot")
		if rest and spot then
			local t = now - f.heliAt
			local centre = Vector3.new(spot.Position.X, spot.Position.Y, spot.Position.Z + 6)
			local lift = math.clamp(t / 3, 0, 1)
			local angle = t * 0.32
			-- Round the roof, just outside its rail (the deck is 112 x 84).
			local orbit = centre + Vector3.new(math.cos(angle) * 66, 22, math.sin(angle) * 52)
			local at = rest.Position:Lerp(orbit, lift)
			local ahead = centre + Vector3.new(math.cos(angle + 0.2) * 66, 22, math.sin(angle + 0.2) * 52)
			local facing = CFrame.lookAt(at, Vector3.new(ahead.X, at.Y, ahead.Z)) * CFrame.Angles(0, math.rad(90), 0)
			poseHeli(facing * CFrame.Angles(0, 0, math.rad(-8 * lift)), t * 18)
		end
		if now >= f.nextStrafe and spot then
			f.nextStrafe = now + TowerService.STRAFE.every
			local list = TowerService.Inside()
			local target = list[math.random(1, math.max(1, #list))]
			local root = target and rootOf(target)
			if root then
				strafe(root.Position, spot.Position.Y - 0.04)
			end
		end
	end
end

-- ------------------------------------------------------------------ players --

local function publish(player: Player)
	task.spawn(function()
		for _ = 1, 30 do
			if not player.Parent then
				return
			end
			local replica = replicaOf(player)
			if replica then
				player:SetAttribute("TowerCleared", replica.Data.TowerCleared == true or nil)
				return
			end
			task.wait(1)
		end
	end)
end

local function onPlayer(player: Player)
	publish(player)
	player.CharacterAdded:Connect(function()
		-- A new life starts at the spawn, not on the roof.
		forget(player)
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end
Players.PlayerRemoving:Connect(function(player)
	inside[player] = nil
	local f = fight
	if f then
		f.damage[player] = nil
	end
end)

task.spawn(function()
	while true do
		task.wait(0.1)
		local ok, err = pcall(TowerService.Step)
		if not ok then
			warn("[Tower] " .. tostring(err))
		end
	end
end)

return TowerService
