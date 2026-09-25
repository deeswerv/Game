--!strict
-- Daily contracts, server side: dealing them, counting toward them, paying them.
--
-- Today's three come from ContractConfig.Deal(day) -- the same three everywhere. Progress
-- lives on the profile (ContractDay / ContractProgress / ContractsPaid) and resets when the
-- UTC day turns, so a contract half done at midnight does not carry into tomorrow's set.
--
-- Everything is counted HERE from things the server already decided: a kill KillCredit
-- awarded, damage it applied, a duel MatchService resolved, a headshot or a wallbang the
-- gun handler ruled on. The client is told what changed; it is never asked.
--
-- Pays the moment a contract completes -- coins, XP, crystals -- and all three in a day pay
-- a bonus on top.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ContractConfig = require(ReplicatedStorage.ContractConfig)
local WeaponConfig = require(ReplicatedStorage.WeaponConfig)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local KillCredit = require(ServerScriptService.KillCredit)
local LevelSystem = require(ServerScriptService.LevelSystem)

local ContractService = {}

-- Everything counted here, re-broadcast: AchievementService listens to the same stream of
-- kills, headshots, duels and drops, plus kinds only it counts (places travelled to, turf
-- wars won, stashes found, bounties claimed) that other services report through Note too.
ContractService.Noted = Instance.new("BindableEvent")

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function ensure(className: string, name: string): Instance
	local existing = (remotes :: Instance):FindFirstChild(name)
	if existing then
		return existing
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = remotes
	return made
end

local ContractAction = ensure("RemoteFunction", "ContractAction") :: RemoteFunction
local ContractUpdate = ensure("RemoteEvent", "ContractUpdate") :: RemoteEvent

-- Profiles, resolved once per player so counting a hit never waits on a load.
local replicas: { [Player]: any } = {}
-- Kills since the player last died, for streak contracts.
local streaks: { [Player]: number } = {}
-- The weapon each attacker last hurt each humanoid with, so a kill knows what made it.
local lastWeapon: { [Humanoid]: { [Player]: string } } = setmetatable({}, { __mode = "k" }) :: any
-- Damage progress is reported in steps, not on every bullet.
local lastReported: { [Player]: { [string]: number } } = {}

--- Only real fights count: another player, or one of the world's fighters. The range's
--- practice dummies die and come back forever, and would farm every contract.
local function counts(humanoid: Humanoid): boolean
	local model = humanoid.Parent
	if not model then
		return false
	end
	return Players:GetPlayerFromCharacter(model) ~= nil or CollectionService:HasTag(model, "GameNPC")
end

local function copy(t: any): { [string]: any }
	local out = {}
	if type(t) == "table" then
		for k, v in pairs(t) do
			out[k] = v
		end
	end
	return out
end

--- Start today's set if the profile is still on another day.
local function ensureDay(replica: any): number
	local day = ContractConfig.Day()
	if replica.Data.ContractDay ~= day then
		replica:SetValue("ContractDay", day)
		replica:SetValue("ContractProgress", {})
		replica:SetValue("ContractsPaid", {})
	end
	return day
end

local function pay(player: Player, replica: any, reward: { coins: number, xp: number, crystals: number? })
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value += reward.coins
	end
	if reward.crystals and reward.crystals > 0 then
		replica:SetValue("Crystals", (tonumber(replica.Data.Crystals) or 0) + reward.crystals)
	end
	if reward.xp > 0 then
		task.spawn(LevelSystem.AwardXP, player, reward.xp)
	end
end

local function secondsLeft(): number
	return (ContractConfig.Day() + 1) * 86400 - os.time()
end

--- Everything the panel shows, from the player's side.
function ContractService.State(player: Player)
	local replica = replicas[player]
	if not replica then
		return nil
	end
	local day = ensureDay(replica)
	local progress = replica.Data.ContractProgress or {}
	local paid = replica.Data.ContractsPaid or {}
	local list = {}
	local done = 0
	for _, id in ipairs(ContractConfig.Deal(day)) do
		local c = ContractConfig.Get(id)
		if c then
			local isPaid = paid[id] == true
			if isPaid then
				done += 1
			end
			table.insert(list, {
				id = c.id, tier = c.tier, title = c.title, text = c.text, icon = c.icon,
				target = c.target, progress = math.min(c.target, tonumber(progress[id]) or 0),
				paid = isPaid, reward = c.reward,
			})
		end
	end
	return {
		contracts = list,
		done = done,
		bonus = ContractConfig.Bonus,
		bonusPaid = paid.__bonus == true,
		secondsLeft = secondsLeft(),
		lifetime = tonumber(replica.Data.ContractsDone) or 0,
	}
end

--- Something happened that a contract might count. `amount` defaults to 1; `detail` narrows
--- kills (the weapon class, the distance).
function ContractService.Note(player: Player, kind: string, amount: number?,
	detail: { class: string?, distance: number?, place: string? }?)
	ContractService.Noted:Fire(player, kind, amount, detail)
	local replica = replicas[player]
	if not replica then
		return
	end
	local day = ensureDay(replica)
	local progress = copy(replica.Data.ContractProgress)
	local paid = copy(replica.Data.ContractsPaid)
	local changed = false

	for _, id in ipairs(ContractConfig.Deal(day)) do
		local c = ContractConfig.Get(id)
		if c and c.kind == kind and paid[id] ~= true then
			local counts = true
			if c.classes and not (detail and detail.class and c.classes[detail.class]) then
				counts = false
			end
			if c.minDistance and not (detail and detail.distance and detail.distance >= c.minDistance) then
				counts = false
			end
			if counts then
				local before = tonumber(progress[id]) or 0
				local now = math.min(c.target, before + (amount or 1))
				-- A streak contract counts the best run, not the total.
				if kind == "streak" then
					now = math.min(c.target, math.max(before, amount or 0))
				end
				if now ~= before then
					progress[id] = now
					changed = true
					if now >= c.target then
						paid[id] = true
						replica:SetValue("ContractsDone", (tonumber(replica.Data.ContractsDone) or 0) + 1)
						ContractService.Noted:Fire(player, "contract", 1, nil)
						pay(player, replica, c.reward)
						ContractUpdate:FireClient(player, "complete", {
							id = c.id, title = c.title, icon = c.icon, tier = c.tier, reward = c.reward,
						})
						print(("[Contracts] %s completed %s"):format(player.Name, c.id))
					else
						-- Progress pings: every step for counts, every tenth for damage.
						local step = kind == "damage" and math.max(1, math.floor(c.target / 10)) or 1
						local seen = lastReported[player] or {}
						lastReported[player] = seen
						if math.floor(now / step) > math.floor((seen[id] or before) / step) then
							seen[id] = now
							ContractUpdate:FireClient(player, "progress", {
								id = c.id, title = c.title, icon = c.icon, tier = c.tier,
								progress = now, target = c.target,
							})
						end
					end
				end
			end
		end
	end

	if not changed then
		return
	end
	-- All three done today: the bonus, once.
	if paid.__bonus ~= true then
		local all = true
		for _, id in ipairs(ContractConfig.Deal(day)) do
			if paid[id] ~= true then
				all = false
			end
		end
		if all then
			paid.__bonus = true
			pay(player, replica, ContractConfig.Bonus)
			ContractUpdate:FireClient(player, "bonus", { reward = ContractConfig.Bonus })
		end
	end
	replica:SetValue("ContractProgress", progress)
	replica:SetValue("ContractsPaid", paid)
end

-- ------------------------------------------------------------------ hooks --

KillCredit.Damaged.Event:Connect(function(humanoid: Humanoid, dealt: number, attacker: Player?, weapon: string?)
	if not attacker or type(dealt) ~= "number" or dealt <= 0 then
		return
	end
	if not counts(humanoid) or Players:GetPlayerFromCharacter(humanoid.Parent :: Instance) == attacker then
		return
	end
	if weapon then
		local byAttacker = lastWeapon[humanoid] or {}
		lastWeapon[humanoid] = byAttacker
		byAttacker[attacker] = weapon
	end
	ContractService.Note(attacker, "damage", math.floor(dealt + 0.5))
end)

KillCredit.KillAwarded.Event:Connect(function(killer: Player, humanoid: Humanoid, _victim: Player?)
	if not counts(humanoid) then
		return
	end
	local weapon = lastWeapon[humanoid] and lastWeapon[humanoid][killer]
	local cfg = weapon and WeaponConfig.Weapons[weapon]
	local distance: number? = nil
	local model = humanoid.Parent
	local root = model and model:FindFirstChild("HumanoidRootPart")
	local mine = killer.Character and killer.Character:FindFirstChild("HumanoidRootPart")
	if root and mine and root:IsA("BasePart") and mine:IsA("BasePart") then
		distance = (root.Position - mine.Position).Magnitude
	end
	ContractService.Note(killer, "kill", 1, { class = cfg and cfg.Class or nil, distance = distance })

	streaks[killer] = (streaks[killer] or 0) + 1
	ContractService.Note(killer, "streak", streaks[killer])

	if model and model:GetAttribute("Boss") == true then
		ContractService.Note(killer, "boss")
	end
end)

-- MatchService resolves duels; both fighters played one, the winner won one.
task.spawn(function()
	local ok, MatchService = pcall(require, ServerScriptService:WaitForChild("MatchService", 30) :: ModuleScript)
	if not ok or type(MatchService) ~= "table" or not MatchService.Finished then
		return
	end
	MatchService.Finished.Event:Connect(function(players: { Player }, winner: Player?, _reason: string)
		for _, p in ipairs(players) do
			if p.Parent then
				ContractService.Note(p, "duel_played")
			end
		end
		if winner and winner.Parent then
			ContractService.Note(winner, "duel_win")
		end
	end)
end)

-- Crystal nodes mined.
task.spawn(function()
	local ok, CrystalService = pcall(require, ServerScriptService:WaitForChild("CrystalService", 30) :: ModuleScript)
	if ok and type(CrystalService) == "table" and CrystalService.Harvested then
		CrystalService.Harvested.Event:Connect(function(player: Player)
			ContractService.Note(player, "crystal")
		end)
	end
end)

ContractAction.OnServerInvoke = function(player: Player, action: unknown)
	if action == "state" then
		return ContractService.State(player)
	end
	return nil
end

local function onPlayer(player: Player)
	streaks[player] = 0
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				streaks[player] = 0
			end)
		end
	end)
	task.spawn(function()
		local ok, replica = pcall(function()
			return PlayerDataManager:GetPlayerDataReplica(player):expect()
		end)
		if ok and replica and player.Parent then
			replicas[player] = replica
			ensureDay(replica)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end
Players.PlayerRemoving:Connect(function(player)
	replicas[player] = nil
	streaks[player] = nil
	lastReported[player] = nil
end)

return ContractService
