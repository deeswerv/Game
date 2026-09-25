--!strict
-- NPC combat AI: the service that owns every enemy and guard in the world.
--
-- This file is the orchestration -- spawning, the shared tick, damage, death and loot. The
-- behaviour lives in the modules beneath it, one job each:
--
--   Body              the R15 rig, its dressing, its weapons, turning and raising the weapon
--   Combat            magazines, reloads, weapon swaps, firing and melee -- all server side
--   Death             the five death animations, handed on to the existing ragdoll
--   Effects           the single batched remote every visual goes out on
--   Spawner           where an NPC is allowed to appear
--   World             shared raycast filters and "what is under this point" questions
--   AI.StateMachine   the decisions: idle, patrol, alert, engage, cover, search...
--   AI.Perception     sight cones, line of sight, memory, threat, target choice
--   AI.Navigator      pathfinding, waypoint following, getting unstuck
--   AI.Squad          roles and spacing when several fight one target
--   AI.Cover          finding somewhere to stand that a bullet cannot reach
--
-- Every NPC is still driven from ONE shared tick rather than its own loop: a per-NPC
-- Heartbeat connection is what makes crowds expensive. NPCs with no player nearby go
-- dormant and cost nothing, perception runs five times a second, NPCs out of a fight think
-- five times a second, and only those actually fighting think at twenty.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local NPCConfig = require(ReplicatedStorage.NPCConfig)
local CombatDeath = require(ServerScriptService.CombatDeath)
local WeaponDropService = require(ServerScriptService.WeaponDropService)
local KillCredit = require(ServerScriptService.KillCredit)
local ShopService = require(ServerScriptService.ShopService)
local ReputationService = require(ServerScriptService.ReputationService)

local World = require(script.World)
local Body = require(script.Body)
local Effects = require(script.Effects)
local Combat = require(script.Combat)
local Death = require(script.Death)
local Spawner = require(script.Spawner)
local Perception = require(script.AI.Perception)
local Navigator = require(script.AI.Navigator)
local StateMachine = require(script.AI.StateMachine)

local NPCService = {}

local TICK = 1 / 20              -- the shared scheduler; agents think on their own cadence
local DORMANT_RANGE = 220        -- no player this close: skip entirely
local PERCEIVE_INTERVAL = 0.2
local COMBAT_THINK = 0.05
local CALM_THINK = 0.2

local NPC_TAG = "GameNPC"
local SPAWN_TAG = "NPCSpawn"

-- Live NPC state, keyed by model.
local agents: { [Model]: any } = {}
local nextId = 0

local function liveCount(): number
	local count = 0
	for _, agent in pairs(agents) do
		if agent.alive then
			count += 1
		end
	end
	return count
end
NPCService.LiveCount = liveCount

-- ------------------------------------------------------------ being hurt --

-- A bigger reaction may interrupt a smaller one; the same size may not, or automatic fire
-- would restart the flinch ten times a second and the NPC would vibrate.
local REACT_RANK = { Light = 1, Medium = 2, Head = 3, Heavy = 3, Stagger = 4 }

local function sideOf(agent, travel: any): string
	if typeof(travel) ~= "Vector3" then
		return "Front"
	end
	local fromShooter = agent.root.CFrame:VectorToObjectSpace(-(travel :: Vector3))
	if math.abs(fromShooter.X) > math.abs(fromShooter.Z) then
		return fromShooter.X > 0 and "Right" or "Left"
	end
	return fromShooter.Z < 0 and "Front" or "Back"
end

local function onHurt(agent, amount: number)
	local now = os.clock()
	local humanoid = agent.humanoid
	agent.lastHurtAt = now
	agent.lastHitAmount = amount
	-- Look around right away rather than at the next scheduled glance.
	agent.nextPerceive = 0

	-- Who did it. Another NPC reports itself just before it deals damage; a player is
	-- whoever KillCredit last tagged.
	local attacker: Model? = nil
	local pending = agent.pendingAttacker
	if pending and now - pending.at < 0.3 and pending.model.Parent then
		attacker = pending.model
	else
		local killer = KillCredit.GetKiller(humanoid)
		attacker = killer and killer.Character or nil
	end
	agent.pendingAttacker = nil
	if attacker and attacker ~= agent.model then
		Perception.NoteThreat(agent, attacker, amount, now)
		local attackerRoot = attacker:FindFirstChild("HumanoidRootPart")
		if attackerRoot and attackerRoot:IsA("BasePart") then
			Perception.Hear(agent, attacker, attackerRoot.Position, now)
		end
	end

	local part = humanoid:GetAttribute("LastHitPart")
	agent.lastHitPart = part
	if humanoid.Health <= 0 then
		return                                   -- the death reads what it needs from here
	end
	-- Consumed, so a later hit that does not say where it landed is not read as this one.
	humanoid:SetAttribute("LastHitPart", nil)

	local share = amount / math.max(humanoid.MaxHealth, 1) * math.max(agent.cfg.HitReactScale or 1, 0.05)
	local kind
	if part == "Head" then
		kind = "Head"
	elseif share < 0.05 then
		kind = "Light"
	elseif share < 0.12 then
		kind = "Medium"
	elseif share < 0.25 then
		kind = "Heavy"
	else
		kind = "Stagger"
	end

	if now - (agent.lastReactAt or -math.huge) < 0.14
		and REACT_RANK[kind] <= REACT_RANK[agent.lastReactKind or "Light"] then
		return
	end
	agent.lastReactAt, agent.lastReactKind = now, kind

	local travel = humanoid:GetAttribute("LastHitDirection")
	Effects.Send(agent.root.Position, "Hit", agent.model, kind, sideOf(agent, travel))

	-- Only the big ones cost it anything more than its aim. Most hits are a flinch.
	agent.flinchUntil = now + (kind == "Light" and 0.15 or 0.4)
	if kind == "Head" then
		StateMachine.Stun(agent, now, 0.15)
	elseif kind == "Heavy" then
		StateMachine.Stun(agent, now, 0.3)
	elseif kind == "Stagger" then
		StateMachine.Stun(agent, now, 0.65)
		if typeof(travel) == "Vector3" then
			local push = World.Flat(travel)
			if push.Magnitude > 0.01 then
				agent.root.AssemblyLinearVelocity += push.Unit * 14
			end
		end
	end
end

-- ------------------------------------------------------------------ noise --
--
-- Gunfire carries. An NPC that hears a shot is NOT told who fired or where they are -- it is
-- told something happened over there, and goes to look. That is the difference between a
-- firefight that spreads and one that stays politely inside the room it started in.
--
-- Enemies already in a fight ignore it: they have a target, and running off to investigate
-- the shots they are personally being shot at with would look ridiculous.

local function factionOf(model: Model?): string?
	if not model then
		return nil
	end
	local agent = agents[model]
	if agent then
		return agent.cfg.Faction
	end
	if Players:GetPlayerFromCharacter(model) then
		return "Player"
	end
	return nil
end

--- Something loud happened at `position`. `source` is who made the noise, when known.
function NPCService.Noise(position: Vector3, radius: number, source: Model?)
	if radius <= 0 then
		return
	end
	local now = os.clock()
	local sourceFaction = factionOf(source)
	for model, agent in pairs(agents) do
		if agent.alive and not agent.dormant and not agent.target and model ~= source then
			if (agent.root.Position - position).Magnitude <= radius then
				if source and sourceFaction and NPCConfig.IsHostileTo(agent.cfg.Faction, sourceFaction) then
					-- An enemy made that noise: it now has a rough idea where they are, which
					-- is a place to search, not a lock-on.
					Perception.Hear(agent, source, position, now)
					agent.nextPerceive = 0
				else
					agent.alert = { position = position, at = now }
				end
			end
		end
	end
end

-- NPCs hear each other's gunfire through the same door players' shots come in by.
Combat.OnNoise = function(position: Vector3, radius: number, source: Model?)
	NPCService.Noise(position, radius, source)
end

-- An NPC about to damage another NPC says so first, so the victim knows who to turn on.
Combat.OnDamage = function(victimModel: Model, attackerModel: Model, _amount: number)
	local victim = agents[victimModel]
	if victim then
		victim.pendingAttacker = { model = attackerModel, at = os.clock() }
	end
end

-- ------------------------------------------------------------------ spawning --

local function scheduleRespawn(archetype: string, home: Vector3, delay: number)
	task.delay(delay, function()
		local rules = NPCConfig.SpawnRules
		for _ = 1, rules.MaxRetries do
			if liveCount() < rules.MaxAlive and not Spawner.PlayerTooClose(home, rules.MinPlayerDistance) then
				NPCService.Spawn(archetype, home)
				return
			end
			task.wait(rules.RetryDelay)
		end
	end)
end

--- Bring an NPC into the world. `options.respawn = false` for anything that must not come
--- back on its own (boss adds, admin spawns, bosses that manage their own return), and
--- `options.ignoreCap = true` for spawns that must happen even at the population cap.
function NPCService.Spawn(archetype: string, position: Vector3, options: { respawn: boolean?, ignoreCap: boolean? }?): Model?
	local opts = options or {}
	local base = NPCConfig.Get(archetype)
	if not base then
		warn("[NPC] unknown archetype " .. tostring(archetype))
		return nil
	end
	if not opts.ignoreCap and liveCount() >= NPCConfig.SpawnRules.MaxAlive then
		warn(("[NPC] population cap (%d) reached; %s not spawned"):format(NPCConfig.SpawnRules.MaxAlive, archetype))
		return nil
	end

	-- Levelled for where it is standing. Every read below -- and every read the AI does
	-- later through agent.cfg -- goes through this copy, so health, damage and payout all
	-- scale from one place. Respawns land on the same spot and so come back the same level.
	local cfg
	if NPCConfig.RollElite(base) then
		-- Elites sit at the zone CEILING and carry one modifier, so the same archetype can
		-- be a routine kill or a problem depending on the roll.
		local mods = NPCConfig.EliteModifiers
		cfg = NPCConfig.MakeElite(
			NPCConfig.Levelled(base, NPCConfig.ZoneCeiling(position)),
			mods[math.random(#mods)])
	elseif base.NeverElite then
		-- Bosses sit at the zone CEILING by definition rather than by chance, so the
		-- Warlord of a level 3-5 zone is always a level 5 Warlord.
		cfg = NPCConfig.Levelled(base, NPCConfig.ZoneCeiling(position))
	else
		cfg = NPCConfig.Levelled(base, NPCConfig.LevelFor(archetype, position))
	end
	-- Which weapon this one carries, then the small differences that make it an individual.
	cfg = NPCConfig.Personalise(NPCConfig.ResolveLoadout(cfg))

	local scale = cfg.Scale or 1
	local spot = Spawner.Resolve(position, scale)
	if not spot then
		warn(("[NPC] no clear ground near %s for %s; spawning on the point as given"):format(tostring(position), archetype))
		spot = position
	end

	local model, humanoid, root = Body.Build(cfg)
	if not model or not humanoid or not root then
		return nil
	end
	model.Name = cfg.DisplayName
	model:SetAttribute("Archetype", archetype)
	model:SetAttribute("Faction", cfg.Faction)
	model:SetAttribute("Level", cfg.Level)
	model:SetAttribute("Elite", cfg.Elite == true)
	if cfg.EliteId then
		model:SetAttribute("EliteModifier", cfg.EliteId)
	end
	local zone = NPCConfig.ZoneAt(position)
	model:SetAttribute("Zone", zone and zone.id or "None")
	-- Server-written only; LevelSystem pays this, KillCredit.Mitigate reads the armour.
	model:SetAttribute("XPReward", cfg.XPReward or 15)
	model:SetAttribute("ArmorRating", cfg.Armor or 0)
	model:SetAttribute("Behaviour", cfg.Behaviour)
	model:SetAttribute("NameColour", cfg.NameColour)
	model:SetAttribute("State", "Idle")

	local ground = spot :: Vector3
	model:PivotTo(CFrame.new(ground + Vector3.new(0, 3.05 * scale, 0)) * CFrame.Angles(0, math.random() * math.pi * 2, 0))
	-- Tagged before parenting, so RigNormalise sees it the moment it enters the world.
	CollectionService:AddTag(model, NPC_TAG)
	model.Parent = World.NPCFolder()
	-- The server simulates every NPC. Left on automatic, ownership drifts to whichever
	-- player walks up to it -- which makes its movement stutter on everyone else's screen
	-- and hands that player's client the physics of an enemy.
	pcall(function()
		root:SetNetworkOwner(nil)
	end)
	-- Joints have to be swapped for constraints while the rig is still whole, so this
	-- happens on spawn rather than at the moment of death.
	CombatDeath.Prepare(model)

	nextId += 1
	local now = os.clock()
	local agent = {
		id = nextId,
		model = model,
		humanoid = humanoid,
		root = root,
		cfg = cfg,
		archetype = archetype,
		home = ground,
		scale = scale,
		alive = true,
		respawn = opts.respawn ~= false,
		memory = {},
		threat = {},
		state = "Spawning",
		stateAt = now,
		nextThink = now + math.random() * 0.2,
		nextPerceive = now + math.random() * PERCEIVE_INTERVAL,
		nextDormantCheck = 0,
		lastHealth = humanoid.Health,
	}
	agent.nav = Navigator.new(agent)
	Body.CaptureRest(agent)
	Combat.Setup(agent)
	World.Register(model, cfg.Faction)
	agents[model] = agent

	humanoid.HealthChanged:Connect(function(health: number)
		local previous = agent.lastHealth
		agent.lastHealth = health
		if agent.alive and health < previous then
			onHurt(agent, previous - health)
		end
	end)
	humanoid.Died:Connect(function()
		NPCService.OnDeath(model)
	end)
	model.Destroying:Connect(function()
		-- Removed without dying (an admin clear, a cleanup): stop thinking about it.
		if agents[model] == agent then
			agents[model] = nil
			agent.alive = false
			World.Unregister(model, cfg.Faction)
			StateMachine.Kill(agent, os.clock())
		end
	end)

	StateMachine.Set(agent, "Idle", now)
	return model
end

-- ---------------------------------------------------------------------- loot --
--
-- Every decision here is the server's: what tier rolled, what kind it was, which item was
-- picked and whether the player already owned it. The client is told what it got, never
-- asked. Ownership goes through ShopService.Grant, which is the same path a purchase uses.

local AttachmentConfig = require(ReplicatedStorage.AttachmentConfig)
local CamoConfig = require(ReplicatedStorage.CamoConfig)

-- An item the player does not already own, or nil if they own the lot.
local function pickUnownedAttachment(player: Player): string?
	local pool = {}
	for slot, options in pairs(AttachmentConfig.Options) do
		for _, opt in ipairs(options) do
			local id = opt.id
			-- Stock parts are what every weapon already has; winning "Irons" is not a prize.
			if id and not AttachmentConfig.IsStock(slot, id) then
				local key = AttachmentConfig.Key(slot, id)
				if not ShopService.OwnsInField(player, "OwnedAttachments", key) then
					table.insert(pool, key)
				end
			end
		end
	end
	return #pool > 0 and pool[math.random(#pool)] or nil
end

local function pickUnownedCamo(player: Player): string?
	local pool = {}
	for _, entry in ipairs(CamoConfig.Camos) do
		local id = entry.id
		if id and id ~= "Default" and not ShopService.OwnsInField(player, "OwnedCamos", id) then
			table.insert(pool, id)
		end
	end
	return #pool > 0 and pool[math.random(#pool)] or nil
end

--- Hand `loot` to `player`. Falls back to coins whenever the item roll has nothing left to
--- give, so a player who already owns every camo still gets paid rather than silently
--- receiving nothing.
function NPCService.GrantLoot(player: Player, loot, cfg)
	local tier, kind = loot.tier, loot.kind
	local granted, label

	if kind == "attachment" then
		local key = pickUnownedAttachment(player)
		if key and ShopService.Grant(player, "OwnedAttachments", key) then
			granted, label = true, key
		end
	elseif kind == "camo" then
		local id = pickUnownedCamo(player)
		if id and ShopService.Grant(player, "OwnedCamos", id) then
			granted, label = true, id
		end
	end

	if not granted then
		kind = "coins"
		local amount = NPCConfig.LootCoinAmount(tier)
		ShopService.AwardCoins(player, amount)
		label = amount .. " coins"
	end

	-- No bespoke remote: ShopService.Grant already fires OwnershipChanged at the player,
	-- and coins are a leaderstats value the client is watching, so both arrive by the same
	-- path a shop purchase uses.
	return kind, label
end

-- --------------------------------------------------------------------- death --

function NPCService.OnDeath(model: Model)
	local agent = agents[model]
	-- Humanoid.Died fires several times per death on this rig; only the first counts.
	if not agent or not agent.alive then
		return
	end
	agent.alive = false
	agents[model] = nil
	World.Unregister(model, agent.cfg.Faction)
	-- The AI stops before anything else happens: no shot, reload or swing lands after this.
	StateMachine.Kill(agent, os.clock())

	local cfg = agent.cfg
	local killer = KillCredit.GetKiller(agent.humanoid)
	if killer and cfg.CoinReward > 0 then
		local stats = killer:FindFirstChild("leaderstats")
		local coins = stats and stats:FindFirstChild("Coins")
		if coins and coins:IsA("IntValue") then
			coins.Value += cfg.CoinReward
		end
	end

	-- Standing moves with whoever cared about the victim. Read from the victim's faction
	-- so an NPC type added later only has to say which side it is on.
	if killer then
		local shifts = NPCConfig.ReputationOnKill[cfg.Faction]
		if shifts then
			for faction, delta in pairs(shifts) do
				ReputationService.Add(killer, faction, delta)
			end
		end
	end

	-- Rarity loot, on top of the carried weapon below. Rolled and granted entirely on the
	-- server; the client is only told the result.
	if killer then
		local loot = NPCConfig.RollLoot(cfg)
		if loot then
			NPCService.GrantLoot(killer, loot, cfg)
		end
	end

	-- Drop what it was carrying, sometimes. Done before the death plays so the weapon
	-- leaves the hands as the body goes down, rather than tangled in a ragdoll.
	local root = agent.root
	if cfg.Weapon and root and math.random() < (cfg.DropChance or 0) then
		local held = model:FindFirstChildOfClass("Tool")
		if held then
			held:Destroy()                -- the held copy is scenery; the drop is the real one
		end
		WeaponDropService.Drop(cfg.Weapon, root.Position + Vector3.new(0, 1.5, 0),
			Vector3.new((math.random() - 0.5) * 8, 10, (math.random() - 0.5) * 8))
	end
	-- A stowed sidearm lives outside the world; do not leave it behind in memory.
	for _, weapon in ipairs(agent.weapons or {}) do
		if weapon.tool.Parent == nil then
			weapon.tool:Destroy()
		end
	end

	-- Plays the death, then goes limp through CombatDeath, which also clears the body away.
	Death.Play(agent)

	-- Respawn at the post it was assigned to, when nobody is standing on it.
	if agent.respawn then
		scheduleRespawn(agent.archetype, agent.home, cfg.RespawnTime)
	end
end

-- ------------------------------------------------------------------ the tick --

-- Everything a faction fights, built once per tick and shared by every NPC of that faction.
local function candidatesFor(faction: string, players, cache)
	local list = cache[faction]
	if list then
		return list
	end
	list = {}
	if NPCConfig.IsHostileTo(faction, "Player") then
		for _, entry in ipairs(players) do
			table.insert(list, entry)
		end
	elseif NPCConfig.HostileReputation[faction] then
		-- A faction that normally tolerates players stops tolerating one who has been
		-- killing them. Checked per tick against live standing, so making amends calls
		-- the guns off again without anything having to remember it did this.
		for _, entry in ipairs(players) do
			if NPCConfig.StandingIsHostile(faction, ReputationService.Get(entry.player, faction)) then
				table.insert(list, entry)
			end
		end
	end
	for model, other in pairs(agents) do
		if other.alive and NPCConfig.IsHostileTo(faction, other.cfg.Faction) then
			table.insert(list, { model = model, root = other.root, humanoid = other.humanoid })
		end
	end
	cache[faction] = list
	return list
end

local function think(agent, now: number, players, cache)
	if agent.humanoid.Health <= 0 or not agent.root.Parent then
		return
	end

	-- Nobody around to see it: stay dormant and cost nothing.
	if now >= agent.nextDormantCheck then
		agent.nextDormantCheck = now + 1
		local near = false
		for _, entry in ipairs(players) do
			if (entry.root.Position - agent.root.Position).Magnitude < DORMANT_RANGE then
				near = true
				break
			end
		end
		agent.dormant = not near
	end
	if agent.dormant then
		agent.nextThink = now + 0.5
		return
	end

	if now >= agent.nextPerceive then
		agent.nextPerceive = now + PERCEIVE_INTERVAL + math.random() * 0.05
		Perception.Update(agent, now, candidatesFor(agent.cfg.Faction, players, cache))
		Perception.ChooseTarget(agent, now)
	end

	StateMachine.Think(agent, now, agents)
	agent.nextThink = now + (StateMachine.InCombat(agent) and COMBAT_THINK or CALM_THINK)
end

local accumulator = 0
local averageCost = 0
RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < TICK then
		return
	end
	accumulator = 0

	local started = os.clock()
	local now = started
	local players = World.LivingPlayers()
	local cache = {}
	for model, agent in pairs(agents) do
		if not model.Parent then
			agents[model] = nil
		elseif agent.alive and now >= agent.nextThink then
			-- One bad agent must not stop the rest of the crowd.
			local ok, err = pcall(think, agent, now, players, cache)
			if not ok then
				agent.nextThink = now + 1
				warn("[NPC] " .. tostring(model.Name) .. ": " .. tostring(err))
			end
		end
	end
	Effects.Flush()
	averageCost = averageCost * 0.95 + (os.clock() - started) * 0.05
end)

function NPCService.GetAgents()
	return agents
end

-- Mirror the population onto the folder so it can be inspected without requiring
-- this module from another context.
task.spawn(function()
	while true do
		task.wait(1)
		local folder = World.NPCFolder()
		local count, live = 0, 0
		for model, agent in pairs(agents) do
			count += 1
			if model.Parent and agent.alive then
				live += 1
			end
		end
		-- Only the instance that actually owns agents reports. A module required
		-- from another Luau context has its own empty table and must not clobber
		-- the real numbers.
		if count > 0 then
			folder:SetAttribute("AgentCount", count)
			folder:SetAttribute("LiveCount", live)
			folder:SetAttribute("TickMs", math.floor(averageCost * 100000 + 0.5) / 100)
		end
	end
end)

function NPCService.SpawnAll()
	local folder = World.NPCFolder()
	-- Guard on the folder, not a module-local flag: module state is per-Luau-context,
	-- so a require from elsewhere would otherwise populate the world a second time.
	if folder:GetAttribute("Populated") then
		return
	end
	folder:SetAttribute("Populated", true)

	for _, spec in ipairs(NPCConfig.Spawns) do
		NPCService.Spawn(spec.archetype, spec.position)
	end

	-- Posts placed in Studio: any part tagged NPCSpawn with an Archetype attribute.
	for _, marker in ipairs(CollectionService:GetTagged(SPAWN_TAG)) do
		if marker:IsA("BasePart") then
			local archetype = marker:GetAttribute("Archetype")
			local count = marker:GetAttribute("Count")
			if type(archetype) == "string" and NPCConfig.Archetypes[archetype] then
				for _ = 1, (type(count) == "number" and math.clamp(math.floor(count), 1, 10) or 1) do
					NPCService.Spawn(archetype, marker.Position)
				end
			else
				warn("[NPC] NPCSpawn marker " .. marker:GetFullName() .. " has no valid Archetype attribute")
			end
		end
	end
end

NPCService.SpawnAll()

return NPCService
