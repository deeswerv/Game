--!strict
-- TURF WAR: every few minutes, while somebody is downtown, a crew rolls in from one of the
-- district's edges -- three Bandits, a Soldier and a Brute lieutenant -- and the players
-- there have four minutes to drive them out.
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

local TurfWarService = {}

TurfWarService.FIRST_DELAY = 150
TurfWarService.INTERVAL = 420
TurfWarService.DURATION = 240
TurfWarService.CREW = { "Grunt", "Grunt", "Grunt", "Soldier", "Brute" }
TurfWarService.REWARD = { coins = 900, xp = 500, crystals = 2 }
TurfWarService.MVP_BONUS = 0.5

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

local function pay(player: Player, scale: number)
	local reward = TurfWarService.REWARD
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value += math.floor(reward.coins * scale)
	end
	local ok, CrystalService = pcall(require, ServerScriptService:FindFirstChild("CrystalService") :: ModuleScript)
	if ok and type(CrystalService) == "table" and CrystalService.Award then
		CrystalService.Award(player, math.floor(reward.crystals * scale + 0.5))
	end
	task.spawn(LevelSystem.AwardXP, player, math.floor(reward.xp * scale))
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
	table.clear(crew)
	table.clear(damage)
	for i, archetype in ipairs(TurfWarService.CREW) do
		local angle = i / #TurfWarService.CREW * math.pi * 2
		local at = origin + Vector3.new(math.cos(angle) * 7, 0, math.sin(angle) * 7)
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
	local endsAt = os.clock() + TurfWarService.DURATION
	turfEvent:FireAllClients("start", {
		zone = entry.name, position = origin, left = remaining(), total = #TurfWarService.CREW,
		seconds = TurfWarService.DURATION,
	})
	print(("[Turf] crew of %d in from %s"):format(remaining(), entry.name))

	task.spawn(function()
		local last = remaining()
		while active do
			task.wait(1)
			local left = remaining()
			if left ~= last then
				last = left
				turfEvent:FireAllClients("progress", { left = left, total = #TurfWarService.CREW,
					seconds = math.max(0, math.floor(endsAt - os.clock())) })
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
						pay(player, mvp and (1 + TurfWarService.MVP_BONUS) or 1)
						turfEvent:FireClient(player, "reward", {
							coins = math.floor(TurfWarService.REWARD.coins * (mvp and 1 + TurfWarService.MVP_BONUS or 1)),
							xp = math.floor(TurfWarService.REWARD.xp * (mvp and 1 + TurfWarService.MVP_BONUS or 1)),
							mvp = mvp,
						})
					end
				end
				turfEvent:FireAllClients("won", { mvp = best and best.DisplayName or nil })
				print("[Turf] defended")
			elseif os.clock() >= endsAt then
				active = false
				for humanoid, model in pairs(crew) do
					if humanoid.Parent and humanoid.Health > 0 and model.Parent then
						model:Destroy()
					end
				end
				turfEvent:FireAllClients("lost", {})
				print("[Turf] the crew got away")
			end
		end
		table.clear(crew)
	end)
	return true
end

function TurfWarService.IsActive(): boolean
	return active
end

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
			task.wait(30)
		end
	end
end)

return TurfWarService
