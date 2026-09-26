--!strict
-- MOST WANTED: the bounty board on the side of the 24/7.
--
-- Every few minutes a named crime boss sets up somewhere in Downtown -- a Capo with two of
-- their crew round them -- and their face goes up on the board. They stay out for a while;
-- take them down and the board pays whoever did it (the one credited with the kill gets the
-- full price, anyone else who put real damage in gets a cut), and the next name goes up
-- after a rest. Leave them long enough and they skip town.
--
-- The target carries a "MostWanted" attribute and CollectionService tag, so every client can
-- pin a marker over their head (UI.Modules.Bounties) -- the board says where they were last
-- seen, the marker finds them.
--
-- The board itself also lists the WANTED players (BountyService's streak prices), so there
-- is one place in the city to see every price on every head.
--
-- Everything is server-side: the board's state is read through the BountyBoard function.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local CollectionService = game:GetService("CollectionService")

local KillCredit = require(ServerScriptService.KillCredit)
local LevelSystem = require(ServerScriptService.LevelSystem)
local GameConfig = require(ReplicatedStorage.GameConfig)

local MostWantedService = {}

MostWantedService.Clock = os.clock
MostWantedService.CENTRE = Vector3.new(-155, 1000, 1500)   -- DistrictService.CENTRE
MostWantedService.FIRST_AFTER = 45     -- the first name goes up this long after the server starts
MostWantedService.REST = 210           -- between one target going down (or away) and the next
MostWantedService.AT_LARGE = 420       -- how long a target stays before skipping town
MostWantedService.REWARD = { coins = 1500, xp = 600, crystals = 3 }
MostWantedService.CUT = 0.35           -- what an assist earns, as a share of the price
MostWantedService.ASSIST_DAMAGE = 60   -- damage it takes to count as an assist
MostWantedService.CRED = 6             -- Street Cred for the takedown
MostWantedService.ESCORT = { "Gangster", "Thug" }

-- Where they hole up, in Downtown's own coordinates (pavement top is y 0.5). Kept off the
-- turf patches, the plaza and the arrival forecourt.
MostWantedService.HIDEOUTS = {
	{ name = "the ZEE GAS car park", at = Vector3.new(-54, 0.5, -104) },
	{ name = "the corner pocket park", at = Vector3.new(-64, 0.5, 44) },
	{ name = "the east tunnel", at = Vector3.new(164, 0.5, 0) },
	{ name = "the west tunnel", at = Vector3.new(-166, 0.5, 0) },
	{ name = "outside the DUEL HALL", at = Vector3.new(-23, 0.5, 112) },
	{ name = "the offices on the east arm", at = Vector3.new(96, 0.5, -30) },
}

-- The faces on the posters.
MostWantedService.TARGETS = {
	{ name = "Vinnie Russo", alias = "THE VICE", crime = "Runs the protection racket on every shop on the avenue." },
	{ name = "Marco Bellini", alias = "TWO-TONE", crime = "Moves stolen cars through the tunnels by night." },
	{ name = "Sal Moretti", alias = "BIG SAL", crime = "Owns half the card games in the city and the debts that come with them." },
	{ name = "Dre Walker", alias = "LEDGER", crime = "Keeps the books for the crews -- and cooks every one of them." },
	{ name = "Rosa Cruz", alias = "REDLINE", crime = "Wheel woman for three bank jobs and counting." },
	{ name = "Jax Monroe", alias = "SNAKE EYES", crime = "Fixed the fights at the court and took the whole pot." },
	{ name = "Tony Vance", alias = "TAP-OUT", crime = "Collector. Nobody who owes him keeps their knees for long." },
	{ name = "Nico Sharpe", alias = "THE SURGEON", crime = "Strips a car in six minutes flat. Wanted for forty of them." },
}

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
local bountyEvent = ensure("RemoteEvent", "BountyEvent") :: RemoteEvent
local BountyBoard = ensure("RemoteFunction", "BountyBoard") :: RemoteFunction

local function service(name: string): any
	local module = ServerScriptService:FindFirstChild(name)
	if not module then
		return nil
	end
	local ok, loaded = pcall(require, module :: ModuleScript)
	return if ok and type(loaded) == "table" then loaded else nil
end

type Target = {
	info: { name: string, alias: string, crime: string },
	hideout: { name: string, at: Vector3 },
	model: Model,
	humanoid: Humanoid,
	escort: { Model },
	endsAt: number,
	damage: { [Player]: number },
}

local current: Target? = nil
local nextAt = MostWantedService.FIRST_AFTER
local lastIndex = 0
local last: { name: string, alias: string, by: string?, escaped: boolean }? = nil
local takedowns: { [Player]: number } = {}

KillCredit.Damaged.Event:Connect(function(humanoid: Humanoid, dealt: number, attacker: Player?)
	local t = current
	if t and humanoid == t.humanoid and attacker and type(dealt) == "number" then
		t.damage[attacker] = (t.damage[attacker] or 0) + dealt
	end
end)

local function pay(player: Player, k: number): { coins: number, xp: number, crystals: number }
	local base = MostWantedService.REWARD
	local reward = {
		coins = math.floor(base.coins * k + 0.5),
		xp = math.floor(base.xp * k + 0.5),
		crystals = if k >= 1 then base.crystals else 0,
	}
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value += reward.coins
	end
	if reward.crystals > 0 then
		local Crystals = service("CrystalService")
		if Crystals and Crystals.Award then
			Crystals.Award(player, reward.crystals)
		end
	end
	task.spawn(LevelSystem.AwardXP, player, reward.xp)
	return reward
end

--- Who is on the board right now (nil between targets).
function MostWantedService.Current(): Model?
	local t = current
	return t and t.model or nil
end

--- Put the next name up. False if one is already out or the crew could not be spawned.
function MostWantedService.Summon(): boolean
	if current then
		return false
	end
	local NPCService = service("NPCService")
	if not NPCService or not NPCService.Spawn then
		return false
	end
	local targets = MostWantedService.TARGETS
	local index = (lastIndex % #targets) + 1
	if #targets > 2 then
		index = math.random(1, #targets - 1)
		if index >= lastIndex then
			index += 1
		end
	end
	lastIndex = index
	local info = targets[index]
	local hideouts = MostWantedService.HIDEOUTS
	local hideout = hideouts[math.random(1, #hideouts)]
	local at = MostWantedService.CENTRE + hideout.at + Vector3.new(0, 3, 0)

	local model = NPCService.Spawn("Capo", at, { respawn = false, ignoreCap = true,
		attributes = { MostWanted = info.name, MostWantedAlias = info.alias } })
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not model or not humanoid then
		return false
	end
	model.Name = info.name
	CollectionService:AddTag(model, "MostWanted")
	local escort = {}
	for i, archetype in ipairs(MostWantedService.ESCORT) do
		local angle = i / #MostWantedService.ESCORT * math.pi * 2
		local guard = NPCService.Spawn(archetype, at + Vector3.new(math.cos(angle) * 6, 0, math.sin(angle) * 6),
			{ respawn = false, ignoreCap = true, attributes = { MostWantedCrew = true } })
		if guard then
			table.insert(escort, guard)
		end
	end
	current = {
		info = info,
		hideout = hideout,
		model = model,
		humanoid = humanoid,
		escort = escort,
		endsAt = MostWantedService.Clock() + MostWantedService.AT_LARGE,
		damage = {},
	}
	bountyEvent:FireAllClients("mostwanted", {
		stage = "out", name = info.name, alias = info.alias, where = hideout.name,
		coins = MostWantedService.REWARD.coins, seconds = MostWantedService.AT_LARGE,
	})
	print(("[MostWanted] %s (%s) is out at %s"):format(info.name, info.alias, hideout.name))
	return true
end

local function finish(escaped: boolean)
	local t = current
	if not t then
		return
	end
	current = nil
	nextAt = MostWantedService.Clock() + MostWantedService.REST
	if escaped then
		for _, m in ipairs(t.escort) do
			if m.Parent then
				m:Destroy()
			end
		end
		if t.model.Parent then
			t.model:Destroy()
		end
		last = { name = t.info.name, alias = t.info.alias, escaped = true }
		bountyEvent:FireAllClients("mostwanted", { stage = "gone", name = t.info.name, alias = t.info.alias })
		print(("[MostWanted] %s skipped town"):format(t.info.name))
		return
	end

	local killer = KillCredit.GetKiller(t.humanoid)
	if killer and not killer.Parent then
		killer = nil
	end
	if not killer then
		-- Nobody was credited (a fall): the biggest damage dealer takes it.
		local best = 0
		for player, dealt in pairs(t.damage) do
			if player.Parent and dealt > best then
				killer, best = player, dealt
			end
		end
	end
	if killer then
		local reward = pay(killer, 1)
		takedowns[killer] = (takedowns[killer] or 0) + 1
		local Turf = service("TurfWarService")
		local cred = Turf and Turf.AddCred and Turf.AddCred(killer, MostWantedService.CRED) or nil
		bountyEvent:FireClient(killer, "mostwanted", {
			stage = "paid", name = t.info.name, alias = t.info.alias, coins = reward.coins,
			xp = GameConfig.ShownXP(reward.xp), crystals = reward.crystals, cred = MostWantedService.CRED, credTotal = cred,
		})
		local Contracts = service("ContractService")
		if Contracts and Contracts.Note then
			task.spawn(Contracts.Note, killer, "mostwanted")
		end
		local Quests = service("QuestService")
		if Quests and Quests.RegisterEvent then
			task.spawn(Quests.RegisterEvent, killer, "mostwanted", { name = t.info.name })
		end
	end
	for player, dealt in pairs(t.damage) do
		if player ~= killer and player.Parent and dealt >= MostWantedService.ASSIST_DAMAGE then
			local reward = pay(player, MostWantedService.CUT)
			bountyEvent:FireClient(player, "mostwanted", {
				stage = "assist", name = t.info.name, alias = t.info.alias, coins = reward.coins,
				xp = GameConfig.ShownXP(reward.xp),
			})
		end
	end
	last = { name = t.info.name, alias = t.info.alias, by = killer and killer.DisplayName or nil, escaped = false }
	bountyEvent:FireAllClients("mostwanted", { stage = "down", name = t.info.name, alias = t.info.alias,
		by = killer and killer.DisplayName or nil, byId = killer and killer.UserId or nil })
	print(("[MostWanted] %s taken down by %s"):format(t.info.name, killer and killer.Name or "nobody"))
end

--- One tick: put a name up when it is time, settle the one that is out.
function MostWantedService.Step()
	local now = MostWantedService.Clock()
	local t = current
	if t then
		if not t.humanoid.Parent or not t.model.Parent or t.humanoid.Health <= 0 then
			finish(false)
		elseif now >= t.endsAt then
			finish(true)
		end
	elseif now >= nextAt then
		if not MostWantedService.Summon() then
			nextAt = now + 30
		end
	end
end

--- The board, as the panel draws it.
function MostWantedService.Board(player: Player?): { [string]: any }
	local now = MostWantedService.Clock()
	local state: { [string]: any } = {
		reward = { coins = MostWantedService.REWARD.coins, xp = GameConfig.ShownXP(MostWantedService.REWARD.xp),
			crystals = MostWantedService.REWARD.crystals, cred = MostWantedService.CRED },
		takedowns = player and takedowns[player] or 0,
	}
	local t = current
	if t then
		local root = t.model:FindFirstChild("HumanoidRootPart")
		state.target = {
			name = t.info.name, alias = t.info.alias, crime = t.info.crime, where = t.hideout.name,
			secondsLeft = math.max(0, math.floor(t.endsAt - now)),
			health = t.humanoid.Health / math.max(1, t.humanoid.MaxHealth),
			position = if root and root:IsA("BasePart") then root.Position else nil,
		}
	else
		state.nextIn = math.max(0, math.floor(nextAt - now))
	end
	state.last = last
	local wanted = {}
	for _, p in ipairs(Players:GetPlayers()) do
		local price = tonumber(p:GetAttribute("Bounty")) or 0
		if price > 0 then
			table.insert(wanted, { name = p.DisplayName, userId = p.UserId, amount = price, you = p == player })
		end
	end
	table.sort(wanted, function(a, b)
		return a.amount > b.amount
	end)
	state.wanted = wanted
	return state
end

BountyBoard.OnServerInvoke = function(player: Player, action: unknown)
	if action == "state" then
		return MostWantedService.Board(player)
	end
	return nil
end

Players.PlayerRemoving:Connect(function(player)
	takedowns[player] = nil
	local t = current
	if t then
		t.damage[player] = nil
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		local ok, err = pcall(MostWantedService.Step)
		if not ok then
			warn("[MostWanted] " .. tostring(err))
		end
	end
end)

return MostWantedService
