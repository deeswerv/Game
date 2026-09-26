--!strict
-- Utility, server side: the kit each life starts with, throws, what they do when they go
-- off, medkits, and armour plates. See ReplicatedStorage.UtilityConfig for the numbers.
--
-- The client says only "throw this kind, from about here, this way" and "use a medkit". The
-- server checks you have one and are alive, works out the flight itself against the real
-- world (UtilityConfig.Trajectory), tells everyone the path so they can all draw the same
-- throw, and on the fuse decides what it did:
--
--   Frag   damage that falls off with distance, mostly stopped by a wall, through
--          KillCredit like every other hit (so kills, XP and the kill feed all work); the
--          thrower takes half. Drawn with the same blast as the enemies' grenades.
--   Flash  each client works out its own blindness from its own camera (only it knows where
--          it is looking); enemies in sight of it are blinded here -- they stop seeing and
--          their aim goes to pieces for a few seconds.
--   Smoke  a cloud every client draws, and SmokeField, which is what stops enemies seeing
--          through it.
--
-- Armour: `Armour` / `MaxArmour` on the character (the HUD's cyan segments). KillCredit
-- takes hits out of it before health. Enemies drop plates that top it up; a duel gives both
-- fighters the same armour every round.
--
-- Gear (GearConfig, bought at ZEE TACTICS): the heal, the armour and the bomb in the throw
-- slot are whatever the player has equipped -- GearService publishes the choice as the
-- GearHeal / GearArmor / GearBomb attributes. A duel always uses the Common of each, so a
-- duel is still decided by the fighters, not their wallets.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local UtilityConfig = require(ReplicatedStorage.UtilityConfig)
local GearConfig = require(ReplicatedStorage.GearConfig)
local KillCredit = require(ServerScriptService.KillCredit)
local SmokeField = require(ServerScriptService.SmokeField)

local UtilityService = {}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local function ensure(name: string): RemoteEvent
	local existing = (remotes :: Instance):FindFirstChild(name)
	if existing and existing:IsA("RemoteEvent") then
		return existing
	end
	local made = Instance.new("RemoteEvent")
	made.Name = name
	made.Parent = remotes
	return made
end
local UtilityAction = ensure("UtilityAction")
local UtilityEvent = ensure("UtilityEvent")

type Kit = { [string]: number }
local kits: { [Player]: Kit } = {}
local lastThrow: { [Player]: number } = {}
local healing: { [Player]: number } = {}
local nextId = 0

local Armour = UtilityConfig.Armour

-- ----------------------------------------------------------------- helpers --

local function lazy(name: string): any?
	local module = ServerScriptService:FindFirstChild(name)
	if not module then
		return nil
	end
	local ok, value = pcall(require, module)
	return ok and value or nil
end

local function levelOf(player: Player): number
	return math.max(1, math.floor(tonumber(player:GetAttribute("Level")) or 1))
end

local function alive(player: Player): (Model?, Humanoid?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if character and humanoid and humanoid.Health > 0 then
		return character, humanoid
	end
	return nil, nil
end

local function finite(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6
		and math.abs(v.Z) < 1e6
end

--- The gear `player` is using in `slot` right now: the Common one in a duel, else what they
--- have equipped.
local function gearOf(player: Player, slot: string): GearConfig.Gear
	if player:GetAttribute("DuelState") == "duel" then
		return GearConfig.Resolve(slot, nil)
	end
	local chosen = player:GetAttribute("Gear" .. slot)
	return GearConfig.Resolve(slot, if type(chosen) == "string" then chosen else nil)
end
UtilityService.GearOf = gearOf

local function maxArmourOf(character: Model): number
	return tonumber(character:GetAttribute("MaxArmour")) or Armour.max
end

local function sendKit(player: Player)
	local kit = kits[player]
	if kit then
		UtilityEvent:FireClient(player, "kit", table.clone(kit))
	end
end

-- What a throw flies through: the world, not bodies or loose clutter.
local function worldParams(): RaycastParams
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.IgnoreWater = true
	local skip: { Instance } = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then
			table.insert(skip, p.Character)
		end
	end
	for _, name in ipairs({ "NPCs", "WeaponDrops", "Debris", "HitFlashes", "ArmourPlates" }) do
		local folder = workspace:FindFirstChild(name)
		if folder then
			table.insert(skip, folder)
		end
	end
	params.FilterDescendantsInstances = skip
	return params
end

-- ------------------------------------------------------------------- kit --

--- A fresh kit for this life (or duel round): throwables and medkits by level and gear, and
--- armour -- a duel's even amount, or what the equipped armour starts a life with.
function UtilityService.Refill(player: Player, keepArmour: boolean?)
	local kit = UtilityConfig.KitFor(levelOf(player))
	local inDuel = player:GetAttribute("DuelState") == "duel"
	local bomb, heal, armor = gearOf(player, "Bomb"), gearOf(player, "Heal"), gearOf(player, "Armor")
	if bomb.id ~= GearConfig.Default.Bomb then
		kit.Frag = bomb.stats.perLife
	end
	if (kit.Medkit or 0) > 0 then
		kit.Medkit = heal.stats.perLife
	end
	kits[player] = kit
	local character = player.Character
	if character then
		local cap = if inDuel then Armour.max else armor.stats.max
		character:SetAttribute("MaxArmour", cap)
		if inDuel then
			character:SetAttribute("Armour", Armour.duel)
		elseif keepArmour then
			local have = tonumber(character:GetAttribute("Armour")) or 0
			character:SetAttribute("Armour", math.clamp(math.max(have, armor.stats.start), 0, cap))
		else
			character:SetAttribute("Armour", armor.stats.start)
		end
	end
	sendKit(player)
	UtilityEvent:FireClient(player, "gear", { Heal = heal.id, Armor = armor.id, Bomb = bomb.id })
end

function UtilityService.Kit(player: Player): Kit?
	return kits[player]
end

--- Top armour up by `amount` (to the cap). Returns what it is now.
function UtilityService.AddArmour(player: Player, amount: number): number
	local character = player.Character
	if not character then
		return 0
	end
	local now = math.clamp((tonumber(character:GetAttribute("Armour")) or 0) + amount, 0, maxArmourOf(character))
	character:SetAttribute("Armour", now)
	return now
end

-- ---------------------------------------------------------------- blasts --

local function targets(): { { model: Model, humanoid: Humanoid, root: BasePart, player: Player? } }
	local out = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local character, humanoid = alive(p)
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if character and humanoid and root and root:IsA("BasePart") then
			table.insert(out, { model = character, humanoid = humanoid, root = root, player = p })
		end
	end
	local npcs = workspace:FindFirstChild("NPCs")
	if npcs then
		for _, model in ipairs(npcs:GetChildren()) do
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local root = model:FindFirstChild("HumanoidRootPart")
			if model:IsA("Model") and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
				table.insert(out, { model = model, humanoid = humanoid, root = root, player = nil })
			end
		end
	end
	return out
end

--- Is there a wall between `centre` and `root`?
local function walled(centre: Vector3, root: BasePart, params: RaycastParams): boolean
	local offset = root.Position - centre
	local hit = workspace:Raycast(centre, offset, params)
	return hit ~= nil and (hit.Position - root.Position).Magnitude > 1.5
end

--- A blast: damage that falls off with distance, mostly stopped by a wall, through KillCredit
--- like every other hit; the thrower takes half. The frag's numbers unless told otherwise.
function UtilityService.Frag(thrower: Player?, centre: Vector3, damageOverride: number?, radiusOverride: number?,
	weaponName: string?)
	local frag = UtilityConfig.Throwables.Frag
	local radius = radiusOverride or frag.radius
	local damage = damageOverride or frag.damage or 100
	UtilityEvent:FireAllClients("explode", centre, radius)
	local params = worldParams()
	for _, t in ipairs(targets()) do
		local offset = t.root.Position - centre
		local d = offset.Magnitude
		local share = if d > radius then 0 else math.max(0.1, 1 - (d / radius) ^ 1.25)
		if share > 0 then
			if walled(centre, t.root, params) then
				share *= 0.2
			end
			if t.player and t.player == thrower then
				share *= 0.5
			end
			local dir = d > 0.1 and offset.Unit or Vector3.new(0, 1, 0)
			KillCredit.Damage(t.humanoid, damage * share, thrower, weaponName or "Frag Grenade", dir)
			-- A shove, for the ones it did not kill.
			if t.humanoid.Health > 0 and d < radius * 0.7 then
				local flat = Vector3.new(offset.X, 0, offset.Z)
				if flat.Magnitude > 0.1 then
					t.root.AssemblyLinearVelocity += flat.Unit * 22 + Vector3.new(0, 14, 0)
				end
			end
		end
	end
	local NPCService = lazy("NPCService")
	if NPCService and NPCService.Noise then
		pcall(NPCService.Noise, centre, 140, thrower and thrower.Character or nil)
	end
end

--- Enemies that can see the flash lose their sight and their aim for a while. Players' own
--- screens are the clients' to work out.
function UtilityService.Flash(thrower: Player?, centre: Vector3)
	UtilityEvent:FireAllClients("flash", centre)
	local NPCService = lazy("NPCService")
	local agents = NPCService and NPCService.GetAgents and NPCService.GetAgents() or {}
	local params = worldParams()
	local now = os.clock()
	for model, agent in pairs(agents) do
		local root = agent.root
		if agent.alive ~= false and root and root.Parent then
			local head = model:FindFirstChild("Head")
			local eye = (head and head:IsA("BasePart")) and head.Position or root.Position + Vector3.new(0, 1.5, 0)
			local toFlash = centre - eye
			local d = toFlash.Magnitude
			if d <= UtilityConfig.Throwables.Flash.radius then
				local hit = workspace:Raycast(eye, toFlash, params)
				if not hit or (hit.Position - centre).Magnitude < 1.5 then
					local facing = d > 0.1 and root.CFrame.LookVector:Dot(toFlash.Unit) or 1
					local blind = UtilityConfig.BlindFor(d, facing)
					if blind > 0.2 then
						agent.blindUntil = math.max(agent.blindUntil or 0, now + blind)
						model:SetAttribute("BlindUntil", workspace:GetServerTimeNow() + blind)
					end
				end
			end
		end
	end
	if NPCService and NPCService.Noise then
		pcall(NPCService.Noise, centre, 90, thrower and thrower.Character or nil)
	end
end

function UtilityService.Smoke(_thrower: Player?, centre: Vector3)
	local smoke = UtilityConfig.Throwables.Smoke
	local duration = smoke.duration or 15
	-- The cloud sits a little off the ground, where heads are.
	local middle = centre + Vector3.new(0, 3, 0)
	SmokeField.Add(middle, smoke.radius, duration)
	UtilityEvent:FireAllClients("smoke", centre, smoke.radius, duration)
end

-- ------------------------------------------------------------------ bombs --

--- A patch of fire: every half second, anyone standing in it (and not behind a wall from its
--- middle) burns. The thrower burns at half rate.
function UtilityService.Burn(thrower: Player?, centre: Vector3, radius: number, perSecond: number, duration: number,
	weaponName: string?)
	UtilityEvent:FireAllClients("fire", centre, radius, duration)
	local tick = 0.5
	task.spawn(function()
		local params = worldParams()
		local elapsed = 0
		while elapsed < duration do
			task.wait(tick)
			elapsed += tick
			for _, t in ipairs(targets()) do
				local offset = t.root.Position - centre
				if Vector3.new(offset.X, 0, offset.Z).Magnitude <= radius and math.abs(offset.Y) < 7
					and not walled(centre + Vector3.new(0, 1.5, 0), t.root, params) then
					local share = if t.player and t.player == thrower then 0.5 else 1
					KillCredit.Damage(t.humanoid, perSecond * tick * share, thrower, weaponName or "Incendiary", nil)
				end
			end
		end
	end)
end

--- Everything near it is dragged in toward the middle for a moment, then it goes off.
function UtilityService.Singularity(thrower: Player?, centre: Vector3, gear: GearConfig.Gear)
	local s = gear.stats
	UtilityEvent:FireAllClients("singularity", centre, s.pull, s.pullTime)
	local steps = math.max(1, math.floor(s.pullTime / 0.1))
	task.spawn(function()
		for _ = 1, steps do
			for _, t in ipairs(targets()) do
				local offset = centre - t.root.Position
				local flat = Vector3.new(offset.X, 0, offset.Z)
				if flat.Magnitude < s.pull and flat.Magnitude > 1.5 and t.player ~= thrower then
					t.root.AssemblyLinearVelocity = flat.Unit * math.min(38, flat.Magnitude * 4)
						+ Vector3.new(0, 4, 0)
				end
			end
			task.wait(0.1)
		end
		UtilityService.Frag(thrower, centre, s.damage, s.radius, gear.name)
	end)
end

--- The bomb in the throw slot goes off at `centre`, the way its kind does.
function UtilityService.Detonate(thrower: Player?, centre: Vector3, gear: GearConfig.Gear)
	local s = gear.stats
	local style = s.style
	if style == "singularity" then
		UtilityService.Singularity(thrower, centre, gear)
		return
	end
	UtilityService.Frag(thrower, centre, s.damage, s.radius, gear.name)
	if style == "cluster" then
		local params = worldParams()
		for i = 1, s.bomblets do
			local angle = (i / s.bomblets) * math.pi * 2 + math.random() * 0.6
			local out = Vector3.new(math.cos(angle), 0, math.sin(angle)) * s.spread * (0.7 + math.random() * 0.5)
			local at = centre + out
			local down = workspace:Raycast(at + Vector3.new(0, 6, 0), Vector3.new(0, -16, 0), params)
			if down then
				at = down.Position + Vector3.new(0, 0.6, 0)
			end
			task.delay(0.35 + i * 0.12, function()
				UtilityService.Frag(thrower, at, s.bombletDamage, s.bombletRadius, gear.name)
			end)
		end
	elseif style == "incendiary" then
		UtilityService.Burn(thrower, centre - Vector3.new(0, 0.6, 0), s.burnRadius, s.burn, s.burnTime, gear.name)
	end
end

-- ----------------------------------------------------------------- throw --

--- Throw one. Returns false (and nothing happens) if the player cannot.
function UtilityService.Throw(player: Player, kind: unknown, origin: unknown, direction: unknown): boolean
	if type(kind) ~= "string" or not UtilityConfig.Throwables[kind] then
		return false
	end
	if typeof(direction) ~= "Vector3" or not finite(direction) or direction.Magnitude < 0.01 then
		return false
	end
	local character = alive(player)
	if not character then
		return false
	end
	-- Not through a duel's countdown shield.
	if character:FindFirstChildOfClass("ForceField") then
		return false
	end
	local kit = kits[player]
	if not kit or (kit[kind] or 0) <= 0 then
		return false
	end
	local now = os.clock()
	if now - (lastThrow[player] or -math.huge) < UtilityConfig.COOLDOWN then
		return false
	end
	local head = character:FindFirstChild("Head")
	local headAt = (head and head:IsA("BasePart")) and head.Position
		or (character:GetPivot().Position + Vector3.new(0, 1.5, 0))
	-- The hand is near the head; a client claiming to throw from somewhere else is ignored.
	local from = headAt
	if typeof(origin) == "Vector3" and finite(origin) and (origin - headAt).Magnitude <= 5 then
		from = origin
	end
	local dir = direction.Unit
	from += dir * 1.2

	kit[kind] -= 1
	lastThrow[player] = now
	sendKit(player)
	local EmoteService = lazy("EmoteService")
	if EmoteService and EmoteService.Stop then
		pcall(EmoteService.Stop, player)
	end

	local params = worldParams()
	-- The bomb slot throws whatever bomb is equipped; a sticky one stops on the first thing it
	-- touches (the path is told every surface is a floor).
	local bomb = if kind == "Frag" then gearOf(player, "Bomb") else nil
	local sticky = bomb ~= nil and bomb.stats.style == "sticky"
	local path = UtilityConfig.Trajectory(from, UtilityConfig.LaunchVelocity(dir), function(a: Vector3, delta: Vector3)
		local hit = workspace:Raycast(a, delta, params)
		if hit and sticky then
			return { Position = hit.Position, Normal = Vector3.new(0, 1, 0), Instance = hit.Instance }
		end
		return hit
	end)
	local cfg = UtilityConfig.Throwables[kind]
	local goesOffAt = kind == "Smoke" and (path.restAt + cfg.fuse) or cfg.fuse
	if bomb then
		local style = bomb.stats.style
		if style == "impact" then
			goesOffAt = path.restAt + bomb.stats.fuse
		elseif style == "sticky" then
			goesOffAt = path.restAt + bomb.stats.fuse
		else
			goesOffAt = math.max(bomb.stats.fuse, 0.2)
		end
	end
	nextId += 1
	UtilityEvent:FireAllClients("thrown", {
		id = nextId,
		kind = kind,
		by = player.UserId,
		points = path.points,
		times = path.times,
		fuse = goesOffAt,
		bomb = bomb and bomb.id or nil,
	})
	task.delay(goesOffAt, function()
		local at = UtilityConfig.PositionAt(path, goesOffAt)
		if kind == "Frag" and bomb and bomb.id ~= GearConfig.Default.Bomb then
			UtilityService.Detonate(player, at + Vector3.new(0, 0.6, 0), bomb)
		elseif kind == "Frag" then
			UtilityService.Frag(player, at + Vector3.new(0, 0.6, 0))
		elseif kind == "Flash" then
			UtilityService.Flash(player, at + Vector3.new(0, 0.6, 0))
		else
			UtilityService.Smoke(player, at)
		end
	end)
	return true
end

-- ---------------------------------------------------------------- medkit --

function UtilityService.Medkit(player: Player): boolean
	local character, humanoid = alive(player)
	local kit = kits[player]
	if not character or not humanoid or not kit or (kit.Medkit or 0) <= 0 or healing[player] then
		return false
	end
	local gear = gearOf(player, "Heal")
	local armourBonus = tonumber(gear.stats.armour) or 0
	local armourRoom = armourBonus > 0
		and (tonumber(character:GetAttribute("Armour")) or 0) < maxArmourOf(character)
	if humanoid.Health >= humanoid.MaxHealth and not armourRoom then
		return false
	end
	local medkit = { channel = gear.stats.channel, heal = gear.stats.heal }
	kit.Medkit -= 1
	sendKit(player)
	local token = os.clock()
	healing[player] = token
	character:SetAttribute("HealingUntil", workspace:GetServerTimeNow() + medkit.channel)
	UtilityEvent:FireAllClients("heal", character, medkit.channel)
	task.delay(medkit.channel, function()
		if healing[player] ~= token then
			return
		end
		healing[player] = nil
		if character.Parent then
			character:SetAttribute("HealingUntil", nil)
		end
		if humanoid.Parent and humanoid.Health > 0 and player.Character == character then
			humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + medkit.heal)
			UtilityEvent:FireClient(player, "healed", medkit.heal)
			if armourBonus > 0 then
				UtilityEvent:FireClient(player, "plate", UtilityService.AddArmour(player, armourBonus))
			end
		end
	end)
	return true
end

-- ---------------------------------------------------------------- plates --

local plateFolder: Folder? = nil
local function plates(): Folder
	if plateFolder and plateFolder.Parent then
		return plateFolder
	end
	local folder = workspace:FindFirstChild("ArmourPlates")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "ArmourPlates"
		folder.Parent = workspace
	end
	plateFolder = folder :: Folder
	return folder :: Folder
end

--- Drop a plate on the ground here. Anyone who walks over it takes it, if they have room.
function UtilityService.DropPlate(at: Vector3): BasePart
	local plate = Instance.new("Part")
	plate.Name = "ArmourPlate"
	plate.Size = Vector3.new(1.6, 0.35, 2)
	plate.Color = Color3.fromRGB(52, 214, 240)
	plate.Material = Enum.Material.SmoothPlastic
	plate.Anchored = true
	plate.CanCollide = false
	plate.CanQuery = false
	plate.CanTouch = false
	plate.CFrame = CFrame.new(at + Vector3.new(0, 0.6, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, math.rad(12))
	plate:SetAttribute("DroppedAt", os.clock())
	plate.Parent = plates()
	local stripe = Instance.new("Part")
	stripe.Name = "Stripe"
	stripe.Size = Vector3.new(1.62, 0.37, 0.4)
	stripe.Color = Color3.fromRGB(236, 250, 255)
	stripe.Material = Enum.Material.SmoothPlastic
	stripe.Anchored = true
	stripe.CanCollide = false
	stripe.CanQuery = false
	stripe.CanTouch = false
	stripe.CFrame = plate.CFrame
	stripe.Parent = plate
	return plate
end

--- Hand out any plate someone is standing on, and clear old ones. Run every so often.
function UtilityService.CollectPlates()
	local folder = workspace:FindFirstChild("ArmourPlates")
	if not folder then
		return
	end
	local now = os.clock()
	for _, plate in ipairs(folder:GetChildren()) do
		if plate:IsA("BasePart") then
			local dropped = tonumber(plate:GetAttribute("DroppedAt")) or now
			if now - dropped > Armour.lifetime then
				plate:Destroy()
				continue
			end
			for _, p in ipairs(Players:GetPlayers()) do
				local character = alive(p)
				local root = character and character:FindFirstChild("HumanoidRootPart")
				if character and root and root:IsA("BasePart")
					and (root.Position - plate.Position).Magnitude <= Armour.pickupRadius then
					local have = tonumber(character:GetAttribute("Armour")) or 0
					if have < maxArmourOf(character) then
						local now2 = UtilityService.AddArmour(p, gearOf(p, "Armor").stats.plate)
						UtilityEvent:FireClient(p, "plate", now2)
						plate:Destroy()
						break
					end
				end
			end
		end
	end
end

--- An enemy died here: maybe it leaves a plate.
function UtilityService.OnEnemyDeath(model: Model)
	local root = model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local archetype = model:GetAttribute("Archetype")
	local chance = (type(archetype) == "string" and Armour.dropChance[archetype]) or Armour.defaultDrop
	if math.random() < chance then
		UtilityService.DropPlate(root.Position - Vector3.new(0, 2.4, 0))
	end
end

--- ZEE TACTICS restocks you: a fresh kit, and armour up to what your armour starts a life
--- with (never down). Not in a duel.
function UtilityService.Restock(player: Player): boolean
	if player:GetAttribute("DuelState") == "duel" or not alive(player) then
		return false
	end
	UtilityService.Refill(player, true)
	return true
end

-- ---------------------------------------------------------------- wiring --

UtilityAction.OnServerEvent:Connect(function(player: Player, action: unknown, a: unknown, b: unknown, c: unknown)
	if action == "throw" then
		UtilityService.Throw(player, a, b, c)
	elseif action == "medkit" then
		UtilityService.Medkit(player)
	elseif action == "kit" then
		sendKit(player)
	end
end)

local function onCharacter(player: Player, character: Model)
	healing[player] = nil
	character:SetAttribute("MaxArmour", gearOf(player, "Armor").stats.max)
	character:SetAttribute("Armour", 0)
	UtilityService.Refill(player)
end

local function onPlayer(player: Player)
	if player.Character then
		task.spawn(onCharacter, player, player.Character)
	end
	player.CharacterAdded:Connect(function(character)
		onCharacter(player, character)
	end)
	-- Into a duel: a fresh kit and the duel's armour. Out of one: a fresh kit, armour back to
	-- what the world gives.
	local wasDuel = player:GetAttribute("DuelState") == "duel"
	player:GetAttributeChangedSignal("DuelState"):Connect(function()
		local inDuel = player:GetAttribute("DuelState") == "duel"
		if inDuel ~= wasDuel then
			wasDuel = inDuel
			UtilityService.Refill(player)
		end
	end)
	-- A level that unlocks a kind hands it over now, not at the next life.
	local lastLevel = levelOf(player)
	player:GetAttributeChangedSignal("Level"):Connect(function()
		local level = levelOf(player)
		local kit = kits[player]
		if kit and level > lastLevel then
			local fresh = UtilityConfig.KitFor(level)
			local old = UtilityConfig.KitFor(lastLevel)
			for id, count in pairs(fresh) do
				if (old[id] or 0) == 0 and count > 0 then
					kit[id] = math.max(kit[id] or 0, count)
				end
			end
			sendKit(player)
		end
		lastLevel = level
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end
Players.PlayerRemoving:Connect(function(player)
	kits[player] = nil
	lastThrow[player] = nil
	healing[player] = nil
end)

-- Enemies drop plates.
local npcs = workspace:FindFirstChild("NPCs")
local function watchNPCs(folder: Instance)
	folder.ChildAdded:Connect(function(model)
		if not model:IsA("Model") then
			return
		end
		local humanoid = model:WaitForChild("Humanoid", 5)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Once(function()
				UtilityService.OnEnemyDeath(model)
			end)
		end
	end)
end
if npcs then
	watchNPCs(npcs)
else
	workspace.ChildAdded:Connect(function(child)
		if child.Name == "NPCs" then
			watchNPCs(child)
		end
	end)
end

task.spawn(function()
	while true do
		task.wait(0.25)
		UtilityService.CollectPlates()
	end
end)

return UtilityService
