--!strict
-- TURF WAR: four patches of Downtown are claimed ground. Walk onto one and its crew comes out
-- to meet you -- three Bandits, a Soldier and a Brute lieutenant -- and you have four minutes
-- to drive them off it. Once a war is over, won or lost, that patch goes quiet for a few
-- minutes before its crew will come back; the other three are still there to pick a fight in.
--
--   THE CAR PARK   south-east, the lot behind ZEE GUNS
--   THE COURTS     north-east, the basketball court under the apartments
--   THE ALLEY      south-west, the back lane behind the gas station
--   THE PARK       north-west, the gardens by the waterfall
--
-- Each patch is marked on the ground -- a ring of red dashes, orange while its war is on and
-- grey while it cools down -- with a sign over it that says which, and for how long.
--
-- THREAT. The district remembers how the wars have gone. Every crew driven out raises the
-- threat a level (to V), and the next crew, on any patch, comes back bigger -- more bandits,
-- another soldier, at V a second lieutenant -- with a longer clock and a payout that grows
-- with it. A crew that gets away lowers it again.
--
-- Everybody who landed a hit on a crew shares its payout when the last one drops (the one who
-- did the most damage gets a bit extra, called MVP). If the clock runs out, or everyone walks
-- away and leaves them to it, the crew simply leaves. Wars on different patches run side by
-- side, each with its own crew, clock and payout.
--
-- The crew are ordinary NPCs (NPCService.Spawn, no respawn), so they fight, take cover,
-- drop loot and count for contracts and streaks like any other enemy.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local KillCredit = require(ServerScriptService.KillCredit)
local LevelSystem = require(ServerScriptService.LevelSystem)
local GameConfig = require(ReplicatedStorage.GameConfig)

local TurfWarService = {}

TurfWarService.DURATION = 240
TurfWarService.DURATION_PER_THREAT = 20
-- How long a patch stays quiet after its war ends, won or lost.
TurfWarService.COOLDOWN = 180
-- How long a crew waits with nobody near before it gives up and leaves.
TurfWarService.ABANDON_AFTER = 45
-- How far from the patch still counts as "near" for that.
TurfWarService.LEASH = 70
TurfWarService.CHECK_EVERY = 0.5
TurfWarService.CREW = { "Grunt", "Grunt", "Grunt", "Soldier", "Brute" }
-- Who joins the crew at each threat level, on top of everyone from the levels below.
TurfWarService.REINFORCEMENTS = {
	[2] = { "Grunt" },
	[3] = { "Soldier" },
	[4] = { "Grunt", "Soldier" },
	[5] = { "Brute" },
}
TurfWarService.MAX_THREAT = 5
-- Base payout at threat I; each level above adds REWARD_PER_THREAT of it.
TurfWarService.REWARD = { coins = 1100, xp = 800, crystals = 2 }
TurfWarService.REWARD_PER_THREAT = 0.25
TurfWarService.MVP_BONUS = 0.5

-- The clock everything is timed on. A test swaps it for one it can wind forward.
TurfWarService.Clock = os.clock

-- Downtown, in world space (DistrictService.CENTRE), and the four patches, local to it.
local CENTRE = Vector3.new(-155, 1000, 1500)
TurfWarService.Zones = {
	{ id = "CarPark", name = "THE CAR PARK", offset = Vector3.new(47, 0, -161), radius = 20 },
	{ id = "Courts", name = "THE COURTS", offset = Vector3.new(54, 0, 80), radius = 20 },
	{ id = "Alley", name = "THE ALLEY", offset = Vector3.new(-146, 0, -84), radius = 11 },
	{ id = "Park", name = "THE PARK", offset = Vector3.new(-126, 0, 78), radius = 20 },
}

local threat = 1

--- The crew for a threat level: the core five, plus every level's reinforcements up to it.
function TurfWarService.CrewFor(level: number): { string }
	local crew = table.clone(TurfWarService.CREW)
	for l = 2, math.clamp(math.floor(level), 1, TurfWarService.MAX_THREAT) do
		for _, archetype in ipairs(TurfWarService.REINFORCEMENTS[l] or {}) do
			table.insert(crew, archetype)
		end
	end
	return crew
end

--- What one fighter is paid at a threat level (the MVP gets MVP_BONUS more).
function TurfWarService.RewardFor(level: number, mvp: boolean): { coins: number, xp: number, crystals: number }
	local scale = (1 + TurfWarService.REWARD_PER_THREAT * (math.clamp(level, 1, TurfWarService.MAX_THREAT) - 1))
		* (if mvp then 1 + TurfWarService.MVP_BONUS else 1)
	local base = TurfWarService.REWARD
	return {
		coins = math.floor(base.coins * scale),
		xp = math.floor(base.xp * scale),
		crystals = math.floor(base.crystals * scale + 0.5),
	}
end

function TurfWarService.Threat(): number
	return threat
end

--- Set the threat level (clamped) and publish it for the HUD.
function TurfWarService.SetThreat(level: number)
	threat = math.clamp(math.floor(level), 1, TurfWarService.MAX_THREAT)
	ReplicatedStorage:SetAttribute("TurfThreat", threat)
end

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local TurfEvent = (remotes :: Instance):FindFirstChild("TurfEvent") :: RemoteEvent?
if not TurfEvent then
	local made = Instance.new("RemoteEvent")
	made.Name = "TurfEvent"
	made.Parent = remotes
	TurfEvent = made
end
local turfEvent = TurfEvent :: RemoteEvent

type Zone = { id: string, name: string, offset: Vector3, radius: number }

type War = {
	level: number,
	total: number,
	endsAt: number,
	crew: { [Humanoid]: Model },
	damage: { [Player]: number },
	left: number,
	lastSeen: number,
	over: boolean,
}

type Turf = {
	zone: Zone,
	centre: Vector3,
	status: string,          -- "idle" | "active" | "cooldown"
	readyAt: number,
	war: War?,
	marker: Model?,
	dashes: { BasePart },
	statusLabel: TextLabel?,
	shown: string?,
}

local turfs: { Turf } = {}
local byId: { [string]: Turf } = {}
for _, zone in ipairs(TurfWarService.Zones) do
	local turf: Turf = {
		zone = zone,
		centre = CENTRE + zone.offset,
		status = "idle",
		readyAt = 0,
		war = nil,
		marker = nil,
		dashes = {},
		statusLabel = nil,
		shown = nil,
	}
	table.insert(turfs, turf)
	byId[zone.id] = turf
end

-- Which war a crew member belongs to, so a hit on them counts toward the right payout.
local warOf: { [Humanoid]: War } = {}

KillCredit.Damaged.Event:Connect(function(humanoid: Humanoid, dealt: number, attacker: Player?)
	local war = warOf[humanoid]
	if war and not war.over and attacker and type(dealt) == "number" then
		war.damage[attacker] = (war.damage[attacker] or 0) + dealt
	end
end)

local function rootOf(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if root and root:IsA("BasePart") and (not humanoid or humanoid.Health > 0) then
		return root
	end
	return nil
end

-- Flat distance from a patch's centre, and whether the height is about street level (so a
-- rooftop or a duel arena in the sky above it does not count).
local function within(turf: Turf, at: Vector3, reach: number): boolean
	local d = at - turf.centre
	return Vector3.new(d.X, 0, d.Z).Magnitude <= reach and d.Y > -10 and d.Y < 30
end

local function standingOn(player: Player, turf: Turf): boolean
	local root = rootOf(player)
	return root ~= nil and within(turf, root.Position, turf.zone.radius)
end

local function anyoneNear(turf: Turf): boolean
	for _, player in ipairs(Players:GetPlayers()) do
		local root = rootOf(player)
		if root and within(turf, root.Position, turf.zone.radius + TurfWarService.LEASH) then
			return true
		end
	end
	return false
end

local function remaining(war: War): number
	local n = 0
	for humanoid in pairs(war.crew) do
		if humanoid.Parent and humanoid.Health > 0 then
			n += 1
		end
	end
	return n
end

local function pay(player: Player, reward: { coins: number, xp: number, crystals: number })
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value += reward.coins
	end
	local ok, CrystalService = pcall(require, ServerScriptService:FindFirstChild("CrystalService") :: ModuleScript)
	if ok and type(CrystalService) == "table" and CrystalService.Award then
		CrystalService.Award(player, reward.crystals)
	end
	task.spawn(LevelSystem.AwardXP, player, reward.xp)
end

-- ------------------------------------------------------------- markers --

local IDLE_RED = Color3.fromRGB(226, 52, 48)
local WAR_ORANGE = Color3.fromRGB(255, 142, 36)
local COOL_GREY = Color3.fromRGB(150, 150, 156)
local DASHES = 28

local function markerFolder(): Folder
	local f = workspace:FindFirstChild("TurfZones")
	if f and f:IsA("Folder") then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = "TurfZones"
	made.Parent = workspace
	return made
end

local function clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", s // 60, s % 60)
end

-- The ring and the sign for one patch. Built the first time the ground under it is there
-- (the district is built from code at start, perhaps after this service), so the dashes
-- sit on whatever surface is there -- road, paving, grass -- rather than a guessed height.
local function buildMarker(turf: Turf)
	if turf.marker and turf.marker.Parent then
		return
	end
	local folder = markerFolder()
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ignore: { Instance } = { folder }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local npcs = workspace:FindFirstChild("NPCs")
	if npcs then
		table.insert(ignore, npcs)
	end
	params.FilterDescendantsInstances = ignore
	local function ground(at: Vector3): Vector3?
		local hit = workspace:Raycast(at + Vector3.new(0, 40, 0), Vector3.new(0, -60, 0), params)
		return hit and hit.Position or nil
	end
	local middle = ground(turf.centre)
	if not middle then
		return
	end
	local streetY = middle.Y

	local model = Instance.new("Model")
	model.Name = turf.zone.id
	model:SetAttribute("TurfZone", turf.zone.id)
	local dashes: { BasePart } = {}
	local r = turf.zone.radius
	for i = 0, DASHES - 1 do
		local a = i / DASHES * math.pi * 2
		local at = turf.centre + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
		-- A dash whose ray landed on something tall (a roof, a car, a bench) is laid at street
		-- height instead, so the ring stays a ring on the ground.
		local g = ground(at)
		if g and math.abs(g.Y - streetY) > 1.5 then
			g = Vector3.new(at.X, streetY, at.Z)
		end
		if g then
			local dash = Instance.new("Part")
			dash.Name = "Dash"
			dash.Anchored = true
			dash.CanCollide = false
			dash.CanQuery = false
			dash.CanTouch = false
			dash.CastShadow = false
			dash.Material = Enum.Material.SmoothPlastic
			dash.Color = IDLE_RED
			-- Long along the ring, a clear 0.07 proud of the surface so it never shimmers.
			dash.Size = Vector3.new(0.6, 0.1, (2 * math.pi * r / DASHES) * 0.55)
			dash.CFrame = CFrame.new(g + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, -a, 0)
			dash.Parent = model
			table.insert(dashes, dash)
		end
	end

	-- The sign: an invisible anchor over the middle, a billboard on it.
	local anchor = Instance.new("Part")
	anchor.Name = "Sign"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.CFrame = CFrame.new(middle + Vector3.new(0, 16, 0))
	anchor.Parent = model
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.new(22, 0, 5, 0)
	gui.MaxDistance = 260
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Parent = anchor
	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.fromScale(1, 0.58)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.new(1, 1, 1)
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Color3.fromRGB(60, 8, 10)
	title.Text = "⚔ " .. turf.zone.name
	title.Parent = gui
	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromScale(0, 0.6)
	status.Size = UDim2.fromScale(1, 0.4)
	status.Font = Enum.Font.GothamBold
	status.TextScaled = true
	status.TextColor3 = IDLE_RED
	status.TextStrokeTransparency = 0
	status.Text = ""
	status.Parent = gui

	model.Parent = folder
	turf.marker, turf.dashes, turf.statusLabel, turf.shown = model, dashes, status, nil
end

local function refreshMarker(turf: Turf, now: number)
	local label = turf.statusLabel
	if not label or not turf.marker or not turf.marker.Parent then
		return
	end
	local colour, text
	local war = turf.war
	if turf.status == "active" and war then
		colour = WAR_ORANGE
		text = string.format("TURF WAR · %d LEFT · %s", war.left, clock(war.endsAt - now))
	elseif turf.status == "cooldown" then
		colour = COOL_GREY
		text = "QUIET FOR " .. clock(turf.readyAt - now)
	else
		colour = IDLE_RED
		text = "STEP IN TO START A TURF WAR"
	end
	if text ~= turf.shown then
		turf.shown = text
		label.Text = text
		label.TextColor3 = colour
		for _, dash in ipairs(turf.dashes) do
			dash.Color = colour
		end
	end
end

-- ---------------------------------------------------------------- wars --

local function finish(turf: Turf, war: War, won: boolean)
	war.over = true
	local zone = turf.zone
	if won then
		-- Everyone who fought shares it; the top damage dealer gets the MVP bonus.
		local best, bestDamage = nil, 0
		for player, dealt in pairs(war.damage) do
			if player.Parent and dealt > bestDamage then
				best, bestDamage = player, dealt
			end
		end
		for player, dealt in pairs(war.damage) do
			if player.Parent and dealt > 0 then
				local mvp = player == best
				local reward = TurfWarService.RewardFor(war.level, mvp)
				pay(player, reward)
				local okC, ContractService = pcall(require, ServerScriptService:FindFirstChild("ContractService") :: ModuleScript)
				if okC and type(ContractService) == "table" and ContractService.Note then
					task.spawn(ContractService.Note, player, "turf")
				end
				turfEvent:FireClient(player, "reward", {
					id = zone.id,
					zone = zone.name,
					coins = reward.coins,
					xp = GameConfig.ShownXP(reward.xp),
					crystals = reward.crystals,
					mvp = mvp,
					threat = war.level,
				})
			end
		end
		TurfWarService.SetThreat(war.level + 1)
		turfEvent:FireAllClients("won", { id = zone.id, zone = zone.name, position = turf.centre,
			mvp = best and best.DisplayName or nil, threat = threat, cooldown = TurfWarService.COOLDOWN })
		print(("[Turf] %s defended; threat now %d"):format(zone.name, threat))
	else
		for humanoid, model in pairs(war.crew) do
			if humanoid.Parent and humanoid.Health > 0 and model.Parent then
				model:Destroy()
			end
		end
		TurfWarService.SetThreat(war.level - 1)
		turfEvent:FireAllClients("lost", { id = zone.id, zone = zone.name, position = turf.centre, threat = threat,
			cooldown = TurfWarService.COOLDOWN })
		print(("[Turf] the crew held %s; threat now %d"):format(zone.name, threat))
	end
	for humanoid in pairs(war.crew) do
		warOf[humanoid] = nil
	end
	turf.war = nil
	turf.status = "cooldown"
	turf.readyAt = TurfWarService.Clock() + TurfWarService.COOLDOWN
	refreshMarker(turf, TurfWarService.Clock())
end

--- Start a turf war on one patch now (by id; a random ready one if none given). Returns false
--- if that patch is already at war or cooling down, or the crew could not spawn.
function TurfWarService.Start(zoneId: string?): boolean
	local turf: Turf? = nil
	if zoneId then
		turf = byId[zoneId]
	else
		local ready = {}
		for _, t in ipairs(turfs) do
			if t.status == "idle" then
				table.insert(ready, t)
			end
		end
		turf = if #ready > 0 then ready[math.random(1, #ready)] else nil
	end
	if not turf or turf.status ~= "idle" then
		return false
	end
	local ok, NPCService = pcall(require, ServerScriptService:FindFirstChild("NPCService") :: ModuleScript)
	if not ok or type(NPCService) ~= "table" or not NPCService.Spawn then
		return false
	end
	local zone = turf.zone
	local level = threat
	local roster = TurfWarService.CrewFor(level)
	local now = TurfWarService.Clock()
	local war: War = {
		level = level,
		total = #roster,
		endsAt = now + TurfWarService.DURATION + TurfWarService.DURATION_PER_THREAT * (level - 1),
		crew = {},
		damage = {},
		left = 0,
		lastSeen = now,
		over = false,
	}
	-- The crew comes out round the edge of the patch, facing in.
	for i, archetype in ipairs(roster) do
		local angle = i / #roster * math.pi * 2 + math.random() * 0.3
		local reach = zone.radius * 0.8
		local at = turf.centre + Vector3.new(math.cos(angle) * reach, 1, math.sin(angle) * reach)
		local model = NPCService.Spawn(archetype, at, { respawn = false, ignoreCap = true })
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if model and humanoid then
			model:SetAttribute("TurfCrew", true)
			model:SetAttribute("TurfZone", zone.id)
			if archetype == "Brute" then
				model:SetAttribute("Lieutenant", true)
				model.Name = "Crew Lieutenant"
			end
			war.crew[humanoid] = model
			warOf[humanoid] = war
		end
	end
	if next(war.crew) == nil then
		return false
	end
	war.left = remaining(war)
	turf.war = war
	turf.status = "active"
	turfEvent:FireAllClients("start", {
		id = zone.id, zone = zone.name, position = turf.centre, left = war.left, total = war.total,
		seconds = war.endsAt - now, threat = level,
	})
	refreshMarker(turf, now)
	print(("[Turf] threat %d: a crew of %d holds %s"):format(level, war.left, zone.name))
	return true
end

--- "idle", "active" or "cooldown", and the seconds left on the clock that applies.
function TurfWarService.Status(zoneId: string): (string?, number)
	local turf = byId[zoneId]
	if not turf then
		return nil, 0
	end
	local now = TurfWarService.Clock()
	if turf.status == "active" and turf.war then
		return "active", math.max(0, turf.war.endsAt - now)
	elseif turf.status == "cooldown" then
		return "cooldown", math.max(0, turf.readyAt - now)
	end
	return "idle", 0
end

--- Is a war on (on that patch, or anywhere if none given)?
function TurfWarService.IsActive(zoneId: string?): boolean
	for _, turf in ipairs(turfs) do
		if (zoneId == nil or turf.zone.id == zoneId) and turf.status == "active" then
			return true
		end
	end
	return false
end

--- One look round: cooled-down patches reopen, a player standing on an open one starts its
--- war, running wars are counted down and settled, and the signs are brought up to date.
function TurfWarService.Step()
	local now = TurfWarService.Clock()
	for _, turf in ipairs(turfs) do
		buildMarker(turf)
		if turf.status == "cooldown" and now >= turf.readyAt then
			turf.status = "idle"
		end
		if turf.status == "idle" then
			for _, player in ipairs(Players:GetPlayers()) do
				if standingOn(player, turf) then
					local ok, err = pcall(TurfWarService.Start, turf.zone.id)
					if not ok then
						warn("[Turf] failed to start: " .. tostring(err))
					end
					break
				end
			end
		end
		local war = turf.war
		if turf.status == "active" and war then
			local left = remaining(war)
			if left ~= war.left then
				war.left = left
				turfEvent:FireAllClients("progress", { id = turf.zone.id, zone = turf.zone.name, left = left,
					total = war.total, seconds = math.max(0, war.endsAt - now), threat = war.level })
			end
			if anyoneNear(turf) then
				war.lastSeen = now
			end
			if left == 0 then
				finish(turf, war, true)
			elseif now >= war.endsAt or now - war.lastSeen >= TurfWarService.ABANDON_AFTER then
				finish(turf, war, false)
			end
		end
		refreshMarker(turf, now)
	end
end

TurfWarService.SetThreat(1)

task.spawn(function()
	while true do
		task.wait(TurfWarService.CHECK_EVERY)
		local ok, err = pcall(TurfWarService.Step)
		if not ok then
			warn("[Turf] " .. tostring(err))
		end
	end
end)

return TurfWarService
