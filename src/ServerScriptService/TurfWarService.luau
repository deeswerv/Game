--!strict
-- TURF WAR: every few minutes, while somebody is downtown, a crew rolls in from one of the
-- district's edges -- three Bandits, a Soldier and a Brute lieutenant -- and the players
-- there have four minutes to drive them out.
--
-- THREAT. The district remembers how the wars have gone. Every crew driven out raises the
-- threat a level (to V), and the next crew comes back bigger -- more bandits, another soldier,
-- at V a second lieutenant -- with a longer clock and a payout that grows with it. A crew that
-- gets away lowers it again. So a server that keeps winning gets a climbing fight, not the same
-- five enemies on a loop.
--
-- Everybody who landed a hit on the crew shares the payout when the last one drops (the one
-- who did the most damage gets a bit extra, called MVP); if the clock runs out, the crew
-- simply leaves. Players elsewhere are told it is happening, so the gate at the crossing
-- is a reason to go.
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

-- How often. The first crew comes a minute after someone arrives downtown, and a new one every
-- four and a half minutes from the start of the last (a war runs up to four and a bit), so
-- there is nearly always one on or about to be.
TurfWarService.FIRST_DELAY = 60
TurfWarService.INTERVAL = 270
TurfWarService.IDLE_POLL = 20
TurfWarService.DURATION = 240
TurfWarService.DURATION_PER_THREAT = 20
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

-- Downtown, in world space (DistrictService.CENTRE), and where a crew can come in from.
local CENTRE = Vector3.new(-155, 1000, 1500)
local HALF = 186
TurfWarService.Entries = {
	{ name = "THE EAST TUNNEL", offset = Vector3.new(168, 1, 0) },
	{ name = "THE WEST TUNNEL", offset = Vector3.new(-168, 1, 0) },
	{ name = "ZEE TOWER", offset = Vector3.new(0, 1, 138) },
	{ name = "THE CAR PARK", offset = Vector3.new(46, 1, -162) },
}

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

local function downtown(player: Player): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return false
	end
	local d = root.Position - CENTRE
	return math.abs(d.X) <= HALF and math.abs(d.Z) <= HALF and d.Y > -20 and d.Y < 250
end

local active = false
local crew: { [Humanoid]: Model } = {}
local damage: { [Player]: number } = {}

KillCredit.Damaged.Event:Connect(function(humanoid: Humanoid, dealt: number, attacker: Player?)
	if active and attacker and crew[humanoid] and type(dealt) == "number" then
		damage[attacker] = (damage[attacker] or 0) + dealt
	end
end)

local function remaining(): number
	local n = 0
	for humanoid in pairs(crew) do
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

--- Start one turf war now. Returns false if one is already on or the crew could not spawn.
function TurfWarService.Start(): boolean
	if active then
		return false
	end
	local ok, NPCService = pcall(require, ServerScriptService:FindFirstChild("NPCService") :: ModuleScript)
	if not ok or type(NPCService) ~= "table" or not NPCService.Spawn then
		return false
	end
	local entry = TurfWarService.Entries[math.random(1, #TurfWarService.Entries)]
	local origin = CENTRE + entry.offset
	local level = threat
	local roster = TurfWarService.CrewFor(level)
	table.clear(crew)
	table.clear(damage)
	for i, archetype in ipairs(roster) do
		local angle = i / #roster * math.pi * 2
		local at = origin + Vector3.new(math.cos(angle) * (7 + #roster * 0.4), 0, math.sin(angle) * (7 + #roster * 0.4))
		local model = NPCService.Spawn(archetype, at, { respawn = false, ignoreCap = true })
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if model and humanoid then
			model:SetAttribute("TurfCrew", true)
			if archetype == "Brute" then
				model:SetAttribute("Lieutenant", true)
				model.Name = "Crew Lieutenant"
			end
			crew[humanoid] = model
		end
	end
	if next(crew) == nil then
		return false
	end
	active = true
	local duration = TurfWarService.DURATION + TurfWarService.DURATION_PER_THREAT * (level - 1)
	local endsAt = os.clock() + duration
	local total = #roster
	turfEvent:FireAllClients("start", {
		zone = entry.name, position = origin, left = remaining(), total = total,
		seconds = duration, threat = level,
	})
	print(("[Turf] threat %d: crew of %d in from %s"):format(level, remaining(), entry.name))

	task.spawn(function()
		local last = remaining()
		while active do
			task.wait(1)
			local left = remaining()
			if left ~= last then
				last = left
				turfEvent:FireAllClients("progress", { left = left, total = total,
					seconds = math.max(0, math.floor(endsAt - os.clock())), threat = level })
			end
			if left == 0 then
				active = false
				-- Everyone who fought shares it; the top damage dealer gets the MVP bonus.
				local best, bestDamage = nil, 0
				for player, dealt in pairs(damage) do
					if player.Parent and dealt > bestDamage then
						best, bestDamage = player, dealt
					end
				end
				for player, dealt in pairs(damage) do
					if player.Parent and dealt > 0 then
						local mvp = player == best
						local reward = TurfWarService.RewardFor(level, mvp)
						pay(player, reward)
						local okC, ContractService = pcall(require, ServerScriptService:FindFirstChild("ContractService") :: ModuleScript)
						if okC and type(ContractService) == "table" and ContractService.Note then
							task.spawn(ContractService.Note, player, "turf")
						end
						turfEvent:FireClient(player, "reward", {
							coins = reward.coins,
							xp = GameConfig.ShownXP(reward.xp),
							crystals = reward.crystals,
							mvp = mvp,
							threat = level,
						})
					end
				end
				TurfWarService.SetThreat(level + 1)
				turfEvent:FireAllClients("won", { mvp = best and best.DisplayName or nil, threat = threat })
				print(("[Turf] defended; threat now %d"):format(threat))
			elseif os.clock() >= endsAt then
				active = false
				for humanoid, model in pairs(crew) do
					if humanoid.Parent and humanoid.Health > 0 and model.Parent then
						model:Destroy()
					end
				end
				TurfWarService.SetThreat(level - 1)
				turfEvent:FireAllClients("lost", { threat = threat })
				print(("[Turf] the crew got away; threat now %d"):format(threat))
			end
		end
		table.clear(crew)
	end)
	return true
end

function TurfWarService.IsActive(): boolean
	return active
end

TurfWarService.SetThreat(1)

task.spawn(function()
	task.wait(TurfWarService.FIRST_DELAY)
	while true do
		local anyone = false
		for _, p in ipairs(Players:GetPlayers()) do
			if downtown(p) then
				anyone = true
				break
			end
		end
		if anyone and not active then
			local ok, err = pcall(TurfWarService.Start)
			if not ok then
				warn("[Turf] failed to start: " .. tostring(err))
			end
			task.wait(TurfWarService.INTERVAL)
		else
			-- Nobody downtown: look again shortly, so the first visitor soon has company.
			task.wait(TurfWarService.IDLE_POLL)
		end
	end
end)

return TurfWarService
