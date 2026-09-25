--!strict
-- Owner-only admin tools.
--
-- Security note: hiding the UI is NOT the control. Every command re-checks ownership
-- on the server before doing anything, so a player who fires the remote by hand gets
-- nothing. The client check exists only so non-owners are not shown a menu they
-- cannot use.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local WeaponConfig = require(ReplicatedStorage.WeaponConfig)
local NPCConfig = require(ReplicatedStorage.NPCConfig)
-- Admin-only waypoints. These are a debugging tool, not a travel system: there are no pads,
-- no prompts and no way to reach them except by passing the owner check below. Kept here
-- rather than in a shared config so nothing on the client can even enumerate them -- the
-- list itself is only handed out through an owner-gated command.
--
-- Every ground-level landing was raycast rather than guessed, skipping non-collidable hits,
-- which is how you avoid dropping a teleport onto a tree canopy. Ordered, because the menu
-- shows them in this order.
local ADMIN_WAYPOINTS = {
	{ id = "Spawn",    name = "Spawn / Lobby",   landing = Vector3.new(-134, 6, 280) },
	{ id = "Harbour",  name = "The Harbour",     landing = Vector3.new(-213, 31, 117) },
	{ id = "Flats",    name = "The Flats",       landing = Vector3.new(-567, 6, 117) },
	{ id = "Reach",    name = "The Reach",       landing = Vector3.new(190, 6, 302) },
	{ id = "Map2",     name = "Map 2",           landing = Vector3.new(-561, 24, 85) },
	{ id = "Islets",   name = "Satellite Islets", landing = Vector3.new(-254, 66, 299) },

	-- Authored coordinates, not raycast: the mine head sits BEHIND the waterfall, and a ray
	-- from above lands on the overhang above it instead (measured y=17.8 against the real
	-- 0.5). MineService owns these numbers, so they are the ones to trust.
	{ id = "MineHead", name = "Mine Entrance",   landing = Vector3.new(-101, 4, 61) },
	{ id = "Cavern",   name = "Crystal Cavern",  landing = Vector3.new(-101, -36, 40) },

	{ id = "Arena",    name = "Duel Arena",      landing = Vector3.new(0, 3004, -50) },
	{ id = "DevRange", name = "Dev Range",       landing = Vector3.new(0, 2002, 10) },
}

local function waypoint(id: string)
	for _, entry in ipairs(ADMIN_WAYPOINTS) do
		if entry.id == id then
			return entry
		end
	end
	return nil
end

local AdminService = {}

local remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "GameRemotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemote(className: string, name: string)
	local existing = remotes:FindFirstChild(name)
	if existing then
		return existing
	end
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end

local AdminCheck = ensureRemote("RemoteFunction", "AdminCheck") :: RemoteFunction
local AdminCommand = ensureRemote("RemoteFunction", "AdminCommand") :: RemoteFunction

-- Extra UserIds allowed alongside the place owner. Keep this short.
local ALLOWLIST: { [number]: boolean } = {}

-- The single source of truth for "is this person allowed".
function AdminService.IsOwner(player: Player): boolean
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	if ALLOWLIST[player.UserId] then
		return true
	end

	if game.CreatorType == Enum.CreatorType.User then
		if game.CreatorId ~= 0 and player.UserId == game.CreatorId then
			return true
		end
	elseif game.CreatorType == Enum.CreatorType.Group then
		local ok, rank = pcall(function()
			return player:GetRankInGroup(game.CreatorId)
		end)
		if ok and rank >= 250 then
			return true
		end
	end

	-- In Studio the place is only reachable by the person running it, and CreatorId is
	-- often 0 on an unpublished file, so allow testing there. This never applies live.
	if RunService:IsStudio() then
		return true
	end

	return false
end

-- ------------------------------------------------------------------ commands --

local godmode: { [Player]: boolean } = {}

local function targetOf(name: string?): Player?
	if not name or name == "" or name == "me" then
		return nil
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Name:lower():sub(1, #name) == name:lower() then
			return p
		end
	end
	return nil
end

local commands = {}

commands.SetCoins = function(player, args)
	local target = targetOf(args.target) or player
	local stats = target:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if not coins then return { ok = false, reason = "No leaderstats yet" } end
	coins.Value = math.clamp(math.floor(tonumber(args.value) or 0), 0, 1e9)
	return { ok = true, reason = string.format("%s coins = %d", target.Name, coins.Value) }
end

commands.SetKills = function(player, args)
	local target = targetOf(args.target) or player
	local stats = target:FindFirstChild("leaderstats")
	local kills = stats and stats:FindFirstChild("Kills")
	if not kills then return { ok = false, reason = "No leaderstats yet" } end
	kills.Value = math.clamp(math.floor(tonumber(args.value) or 0), 0, 1e7)
	return { ok = true, reason = string.format("%s kills = %d", target.Name, kills.Value) }
end

-- The HUD only redraws when it is told to. Writing the profile alone leaves the badge and
-- the XP bar showing the old numbers until something else happens to refresh them, which
-- makes an admin command look like it silently failed.
local function pushProgression(target: Player, level: number, exp: number, maxExp: number)
	local remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
	local xpGained = remotes and remotes:FindFirstChild("XPGained")
	if xpGained and xpGained:IsA("RemoteEvent") then
		xpGained:FireClient(target, 0, exp, maxExp, level)
	end
end

commands.SetLevel = function(player, args)
	local target = targetOf(args.target) or player
	local GameConfig = require(ReplicatedStorage.GameConfig)
	local level = math.clamp(math.floor(tonumber(args.value) or 1), 1, GameConfig.Leveling.MAX_LEVEL)
	local maxExp = GameConfig.GetRequiredEXP(level)
	local ok = pcall(function()
		local PDM = require(ServerScriptService.PlayerDataManager)
		local replica = PDM:GetPlayerDataReplica(target):expect()
		replica:SetValue("Level", level)
		replica:SetValue("EXP", 0)
		replica:SetValue("MaxEXP", maxExp)
	end)
	local stats = target:FindFirstChild("Stats")
	if stats then
		for key, val in pairs({ Level = level, EXP = 0, MaxEXP = maxExp }) do
			local v = stats:FindFirstChild(key)
			if v and v:IsA("ValueBase") then
				(v :: any).Value = val
			end
		end
	end
	if ok then
		pushProgression(target, level, 0, maxExp)
	end
	return { ok = ok, reason = ok and string.format("%s level = %d", target.Name, level) or "Data not ready" }
end

-- Sets the rank directly, without the level reset a real prestige performs. This is a
-- testing tool: it is for seeing an emblem, not for taking the prestige route.
commands.SetPrestige = function(player, args)
	local target = targetOf(args.target) or player
	local GameConfig = require(ReplicatedStorage.GameConfig)
	local prestige = math.clamp(math.floor(tonumber(args.value) or 0), 0, GameConfig.Prestige.MAX_PRESTIGE)
	local ok = pcall(function()
		local PDM = require(ServerScriptService.PlayerDataManager)
		local replica = PDM:GetPlayerDataReplica(target):expect()
		replica:SetValue("Prestige", prestige)
	end)
	if not ok then
		return { ok = false, reason = "Data not ready" }
	end
	-- The attribute is what every piece of UI actually reads.
	target:SetAttribute("Prestige", prestige)
	local remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
	local changed = remotes and remotes:FindFirstChild("PrestigeChanged")
	if changed and changed:IsA("RemoteEvent") then
		changed:FireAllClients(target, prestige)
	end
	local tier = GameConfig.GetPrestigeTier(prestige)
	return { ok = true, reason = string.format("%s prestige = %d (%s)", target.Name, prestige, tier.name) }
end

-- Runs the genuine prestige path, level reset and all, so the real flow can be exercised
-- without grinding to the cap first.
--
-- Guarded against firing on yourself by accident. This command defaults its target to the
-- caller, and it performs a REAL reset -- it has twice taken a level-100 profile back to 1
-- during testing, because "run the prestige flow" and "destroy my own progress" are the
-- same call with no argument. Anyone deliberately prestiging themselves can say so.
commands.DoPrestige = function(player, args)
	local target = targetOf(args.target) or player
	if target == player and args.confirm ~= true then
		return {
			ok = false,
			reason = "DoPrestige resets YOUR level to 1. Pass confirm=true to do it anyway, "
				.. "or name another target to test the flow on.",
		}
	end
	local LevelSystem = require(ServerScriptService.LevelSystem)
	local ok, result = LevelSystem.Prestige(target)
	if ok and type(result) == "table" then
		return { ok = true, reason = string.format("%s -> prestige %d (%s), +%d coins",
			target.Name, result.prestige, result.name, result.reward) }
	end
	return { ok = false, reason = tostring(result) }
end

commands.GiveWeapon = function(player, args)
	local target = targetOf(args.target) or player
	local id = tostring(args.value or "")
	if not WeaponConfig.IsWeapon(id) then
		return { ok = false, reason = "Unknown weapon: " .. id }
	end
	local template = ReplicatedStorage.storeitems:FindFirstChild(id)
	if not template then return { ok = false, reason = "No template for " .. id } end
	local backpack = target:FindFirstChildOfClass("Backpack")
	if not backpack then return { ok = false, reason = "No backpack" } end
	template:Clone().Parent = backpack
	return { ok = true, reason = "Gave " .. id .. " to " .. target.Name }
end

commands.SpawnNPC = function(player, args)
	local archetype = tostring(args.value or "Grunt")
	if not NPCConfig.Get(archetype) then
		return { ok = false, reason = "Unknown archetype: " .. archetype }
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return { ok = false, reason = "No character" } end

	local ok, err = pcall(function()
		local NPCService = require(ServerScriptService.NPCService)
		-- A test spawn is a one-off: it must not keep coming back at that spot after it dies.
		NPCService.Spawn(archetype, root.Position + root.CFrame.LookVector * 16, { respawn = false, ignoreCap = true })
	end)
	return { ok = ok, reason = ok and ("Spawned " .. archetype) or tostring(err) }
end

commands.ClearNPCs = function()
	local folder = workspace:FindFirstChild("NPCs")
	if not folder then return { ok = false, reason = "No NPC folder" } end
	local n = 0
	for _, c in ipairs(folder:GetChildren()) do
		local h = c:FindFirstChildOfClass("Humanoid")
		if h then h.Health = 0 n += 1 end
	end
	return { ok = true, reason = "Killed " .. n .. " NPCs" }
end

--- The waypoint list, for the menu to build its buttons from.
---
--- Owner-gated like every other command, so the destinations are not something a client can
--- enumerate -- and there is one list rather than a server copy and a menu copy to drift.
commands.Waypoints = function(_player, _args)
	local out = {}
	for _, entry in ipairs(ADMIN_WAYPOINTS) do
		table.insert(out, { id = entry.id, name = entry.name })
	end
	return { ok = true, waypoints = out }
end

commands.Teleport = function(player, args)
	local dest = tostring(args.value or "")
	local character = player.Character
	if not character then return { ok = false, reason = "No character" } end

	local other = targetOf(dest)
	if other and other.Character then
		local r = other.Character:FindFirstChild("HumanoidRootPart")
		if r then
			character:PivotTo(CFrame.new(r.Position + Vector3.new(0, 4, 4)))
			return { ok = true, reason = "Teleported to " .. other.Name }
		end
	end

	-- Reaching this line already means the caller passed the owner check at the top of
	-- AdminCommand, so a waypoint is no more exposed than any other admin command.
	local spec = waypoint(dest)
	if spec then
		-- Stream the destination in first. With StreamingEnabled a far waypoint -- the arena
		-- at 3000, the range at 2000, the cavern underground -- is simply not loaded on the
		-- client, and arriving before the floor does means falling through it.
		pcall(function()
			player:RequestStreamAroundAsync(spec.landing, 5)
		end)
		character:PivotTo(CFrame.new(spec.landing + Vector3.new(0, 3, 0)))
		local root = character:FindFirstChild("HumanoidRootPart")
		if root and root:IsA("BasePart") then
			-- Arrive stationary. Keeping fall speed across a teleport is how you land at the
			-- arena already plummeting.
			root.AssemblyLinearVelocity = Vector3.zero
		end
		return { ok = true, reason = "Moved to " .. spec.name }
	end
	return { ok = false, reason = "No player or waypoint called: " .. dest }
end

commands.Godmode = function(player, args)
	local target = targetOf(args.target) or player
	local on = not godmode[target]
	godmode[target] = on or nil

	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if on then
			humanoid.MaxHealth = math.huge
			humanoid.Health = math.huge
		else
			humanoid.MaxHealth = 100
			humanoid.Health = 100
		end
	end
	return { ok = true, reason = target.Name .. " godmode " .. (on and "ON" or "OFF") }
end

commands.Heal = function(player, args)
	local target = targetOf(args.target) or player
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return { ok = false, reason = "No character" } end
	humanoid.Health = humanoid.MaxHealth
	return { ok = true, reason = "Healed " .. target.Name }
end

-- ------------------------------------------------------------------- world --

commands.Weather = function(_player, args)
	local WeatherService = require(ServerScriptService.WeatherService)
	local id = tostring(args.value or "Clear")
	local ok = WeatherService.Set(id, true)
	if ok == false then
		return { ok = false, reason = "Unknown weather: " .. id }
	end
	return { ok = true, reason = "Weather -> " .. id }
end

commands.TimeOfDay = function(_player, args)
	local AmbienceService = require(ServerScriptService.AmbienceService)
	local hour = math.clamp(tonumber(args.value) or 12, 0, 24)
	-- Paused first, or the running clock walks straight off the hour that was asked for.
	AmbienceService.SetPaused(true)
	AmbienceService.Apply(hour)
	return { ok = true, reason = string.format("Time -> %04.1f (clock paused)", hour) }
end

commands.ResumeTime = function()
	local AmbienceService = require(ServerScriptService.AmbienceService)
	AmbienceService.SetPaused(false)
	return { ok = true, reason = "Day/night clock running again" }
end

commands.ClearDrops = function()
	local folder = workspace:FindFirstChild("WeaponDrops")
	if not folder then
		return { ok = true, reason = "No drops" }
	end
	local n = #folder:GetChildren()
	folder:ClearAllChildren()
	return { ok = true, reason = "Cleared " .. n .. " dropped weapons" }
end

commands.SpawnBoss = function(player, args)
	local BossService = require(ServerScriptService.BossService)
	local zone = tostring(args.value or "Flats")
	for _, post in ipairs(BossService.Posts) do
		if post.zone:lower() == zone:lower() then
			local model = BossService.SpawnAt(post)
			return { ok = model ~= nil, reason = model and ("Spawned " .. post.title) or "Already standing" }
		end
	end
	return { ok = false, reason = "No boss post in zone: " .. zone }
end

commands.Speed = function(player, args)
	local target = targetOf(args.target) or player
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if not humanoid then return { ok = false, reason = "No character" } end
	humanoid.WalkSpeed = math.clamp(tonumber(args.value) or 16, 1, 200)
	return { ok = true, reason = string.format("%s walk speed = %d", target.Name, humanoid.WalkSpeed) }
end

-- --------------------------------------------------------------- diagnostics --
--
-- The numbers worth knowing while testing, read live rather than guessed: population, what
-- the AI costs, how heavy the world is, and how the server is keeping up.
commands.Diagnostics = function()
	local npcs = workspace:FindFirstChild("NPCs")
	local parts, humanoids = 0, 0
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
		elseif d:IsA("Humanoid") then
			humanoids += 1
		end
	end
	local drops = workspace:FindFirstChild("WeaponDrops")
	local lines = {
		string.format("NPCs alive %s of %s, AI tick %s ms",
			tostring(npcs and npcs:GetAttribute("LiveCount") or 0),
			tostring(npcs and npcs:GetAttribute("AgentCount") or 0),
			tostring(npcs and npcs:GetAttribute("TickMs") or "?")),
		string.format("workspace %d parts, %d humanoids, %d drops", parts, humanoids,
			drops and #drops:GetChildren() or 0),
		string.format("players %d, uptime %d min", #Players:GetPlayers(), math.floor(time() / 60)),
	}
	return { ok = true, reason = table.concat(lines, "  |  ") }
end

-- ----------------------------------------------------------------- coin data --
--
-- Coins predate the profile: they live in leaderstats and were persisted by TWO legacy
-- scripts writing two different DataStores, which can disagree with each other. This copies
-- the best of what exists onto the profile, where the rest of progression already lives.
--
-- Deliberately manual, and deliberately never lowers anything: it takes the HIGHEST of the
-- three sources, so running it twice is harmless and running it cannot cost anyone coins.
-- Nothing reads the profile figure yet -- flipping the game over to it is a separate step,
-- once you have run this and seen the numbers it reports.
commands.MigrateCoins = function(player, args)
	local DataStoreService = game:GetService("DataStoreService")
	local target = targetOf(args.target) or player

	local stats = target:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	local live = coins and coins.Value or 0

	local legacyStats, legacySave = 0, 0
	pcall(function()
		local store = DataStoreService:GetDataStore("Stats")
		legacyStats = tonumber(store:GetAsync(target.UserId .. "-Coins")) or 0
	end)
	pcall(function()
		local store = DataStoreService:GetDataStore("SaveLeaderstats")
		local saved = store:GetAsync(tostring(target.UserId))
		if type(saved) == "table" then
			legacySave = tonumber(saved.Coins) or 0
		end
	end)

	local best = math.max(live, legacyStats, legacySave)
	local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
	local ok, err = pcall(function()
		local Replica = PlayerDataManager:GetPlayerDataReplica(target):expect()
		Replica:SetValue("Coins", best)
		Replica:SetValue("CoinsMigrated", true)
	end)
	if not ok then
		return { ok = false, reason = "Profile write failed: " .. tostring(err) }
	end
	if coins then
		coins.Value = best
	end
	return { ok = true, reason = string.format("%s: live %d, Stats store %d, SaveLeaderstats %d -> profile %d",
		target.Name, live, legacyStats, legacySave, best) }
end

-- Keep godmode across respawns while it is on.
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		if godmode[player] then
			local h = character:WaitForChild("Humanoid", 5)
			if h then h.MaxHealth = math.huge h.Health = math.huge end
		end
	end)
end)
Players.PlayerRemoving:Connect(function(player)
	godmode[player] = nil
end)

-- ------------------------------------------------------------------ remotes --

AdminCheck.OnServerInvoke = function(player)
	return AdminService.IsOwner(player)
end

AdminCommand.OnServerInvoke = function(player, name, args)
	-- Re-validated here, every single call. This is the actual security boundary.
	if not AdminService.IsOwner(player) then
		warn(string.format("[Admin] REJECTED '%s' from %s (%d) -- not the owner",
			tostring(name), player.Name, player.UserId))
		return { ok = false, reason = "Not authorised" }
	end

	local fn = commands[name]
	if not fn then
		return { ok = false, reason = "Unknown command" }
	end
	if typeof(args) ~= "table" then
		args = {}
	end

	local ok, result = pcall(fn, player, args)
	if not ok then
		return { ok = false, reason = "Error: " .. tostring(result) }
	end
	return result
end

AdminService.Commands = commands

return AdminService
