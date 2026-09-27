--!strict
-- STICK-UPS: rob a till or a cash machine in Downtown, then survive long enough to keep it.
--
--   * Hold E at a marked target -- the tills behind the counters at ZEE GUNS and ZEE TACTICS,
--     the cash machines outside them and at the 24/7 (Downtown marks them `Stickup` = where,
--     `StickupKind` = "register" or "atm"; DistrictService hands them to Wire).
--   * You come away with the bag, and the heat: the alarm goes off, the whole server is told
--     where and how much, a gold tag with the amount floats over you through walls, and the
--     crew that runs the block sends three of its own up the avenue after you. They are
--     steered onto you for as long as the heat lasts.
--   * Hold on to it for the heat's length and it is yours (cash and XP): a clean getaway.
--     Die first and it is gone -- and if a player put you down, the bag is theirs.
--   * The target is empty for a while after; one job at a time; not from a duel.
--
-- Server-owned: the bag and the heat are the "Bag" / "Heat" attributes on the player (Heat is
-- the server time it ends), which every client reads for the tag and the robber's own bar.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local KillCredit = require(ServerScriptService.KillCredit)
local LevelSystem = require(ServerScriptService.LevelSystem)

local StickupService = {}

-- How each kind of job goes: how long you hold E, what is in it, how long the heat lasts.
StickupService.Kinds = {
	register = { hold = 4, loot = { 450, 750 }, heat = 60, what = "the till" },
	atm = { hold = 6, loot = { 700, 1100 }, heat = 75, what = "the cash machine" },
}
StickupService.COOLDOWN = 300       -- seconds a target stays empty
StickupService.XP = 300             -- on a clean getaway
StickupService.SQUAD = { "Enforcer", "Gangster", "Shooter" }
StickupService.SQUAD_OUT = 45       -- how far up and down the avenue they come from
StickupService.CALL_EVERY = 2       -- how often the squad is pointed at the robber
StickupService.DISPERSE = 20        -- a squad left standing goes home this long after

-- Swappable for tests.
StickupService.Clock = os.clock
StickupService.Random = math.random

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local StickupEvent = (remotes :: Instance):FindFirstChild("StickupEvent") :: RemoteEvent?
if not StickupEvent then
	local made = Instance.new("RemoteEvent")
	made.Name = "StickupEvent"
	made.Parent = remotes
	StickupEvent = made
end
local stickupEvent = StickupEvent :: RemoteEvent

type Target = { part: BasePart, prompt: ProximityPrompt, name: string, kind: string, readyAt: number, street: Vector3 }
type Job = {
	player: Player, target: Target, loot: number, endsAt: number, serverEndsAt: number,
	squad: { Model }, done: boolean, died: RBXScriptConnection?,
}

local targets: { [BasePart]: Target } = {}
local jobs: { [Player]: Job } = {}

local function lazy(name: string): any?
	local module = ServerScriptService:FindFirstChild(name)
	if not module then
		return nil
	end
	local ok, value = pcall(require, module)
	return ok and value or nil
end

local function alive(player: Player): (Model?, Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return character, humanoid, root
	end
	return nil, nil, nil
end

local function describe(target: Target): string
	if target.kind == "atm" then
		return "the ATM at " .. target.name
	end
	return target.name
end

local function payCoins(player: Player, amount: number)
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") then
		coins.Value += amount
	end
end

--- Where the squad comes from: up and down the street from `street` (the point on the avenue
--- level with the target, which Downtown marks it with), so they arrive along the road rather
--- than out of a wall. The avenue runs north-south.
function StickupService.SquadPoints(street: Vector3): { Vector3 }
	local out = StickupService.SQUAD_OUT
	local up = Vector3.new(0, 1, 0)
	return {
		street + up + Vector3.new(-5, 0, -out),
		street + up + Vector3.new(5, 0, out),
		street + up + Vector3.new(0, 0, -out - 14),
	}
end

local function refreshPrompt(target: Target)
	local empty = StickupService.Clock() < target.readyAt
	local kind = StickupService.Kinds[target.kind]
	target.prompt.ActionText = if empty then "Emptied" else "Rob " .. (if target.kind == "atm" then "the ATM" else "the till")
	target.prompt.HoldDuration = if empty then 0 else kind.hold
end

local function endJob(job: Job)
	if job.done then
		return
	end
	job.done = true
	if job.died then
		job.died:Disconnect()
	end
	if jobs[job.player] == job then
		jobs[job.player] = nil
	end
	job.player:SetAttribute("Bag", nil)
	job.player:SetAttribute("Heat", nil)
	job.player:SetAttribute("HeatPlace", nil)
	-- Whoever of the squad is still standing goes home after a while, so a job cannot leave
	-- the district full of enforcers.
	task.delay(StickupService.DISPERSE, function()
		for _, model in ipairs(job.squad) do
			local humanoid = model.Parent and model:FindFirstChildOfClass("Humanoid")
			if humanoid and humanoid.Health > 0 then
				model:Destroy()
			end
		end
	end)
end

--- The robber went down with the bag: it goes to the player who did it, or it is lost.
local function onRobberDied(job: Job)
	if job.done then
		return
	end
	local character = job.player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local killer = humanoid and KillCredit.GetKiller(humanoid)
	local place = describe(job.target)
	if killer and killer ~= job.player then
		payCoins(killer, job.loot)
		stickupEvent:FireAllClients("stolen", {
			killer = killer.DisplayName, killerId = killer.UserId, robber = job.player.DisplayName,
			robberId = job.player.UserId, amount = job.loot, place = place,
		})
		print(("[Stickup] %s took %s's bag ($%d)"):format(killer.Name, job.player.Name, job.loot))
	else
		stickupEvent:FireAllClients("busted", {
			robber = job.player.DisplayName, robberId = job.player.UserId, amount = job.loot, place = place,
		})
	end
	endJob(job)
end

local function getaway(job: Job)
	if job.done then
		return
	end
	payCoins(job.player, job.loot)
	task.spawn(LevelSystem.AwardXP, job.player, StickupService.XP)
	stickupEvent:FireAllClients("getaway", {
		robber = job.player.DisplayName, robberId = job.player.UserId, amount = job.loot, xp = StickupService.XP,
		place = describe(job.target),
	})
	print(("[Stickup] %s got away with $%d"):format(job.player.Name, job.loot))
	endJob(job)
end

--- One pass over a job: pay out when the heat is over, point the squad at the robber otherwise.
function StickupService.Step(job: Job)
	if job.done then
		return
	end
	if not job.player.Parent then
		endJob(job)
		return
	end
	if StickupService.Clock() >= job.endsAt then
		getaway(job)
		return
	end
	local character, _, root = alive(job.player)
	if character and root then
		local NPCService = lazy("NPCService")
		if NPCService and NPCService.Noise then
			pcall(NPCService.Noise, root.Position, 220, character)
		end
	end
end

--- Rob `part` as `player`. Returns whether the job started, and why not.
function StickupService.Rob(player: Player, part: BasePart): (boolean, string?)
	local target = targets[part]
	if not target then
		return false, "not a target"
	end
	local now = StickupService.Clock()
	if now < target.readyAt then
		local left = math.ceil(target.readyAt - now)
		stickupEvent:FireClient(player, "refused", { text = ("Already cleaned out. Back in %d:%02d."):format(
			left // 60, left % 60) })
		return false, "empty"
	end
	if jobs[player] then
		stickupEvent:FireClient(player, "refused", { text = "You are already holding a bag. Lose the heat first." })
		return false, "busy"
	end
	if player:GetAttribute("DuelState") == "duel" then
		return false, "in a duel"
	end
	local character, humanoid, root = alive(player)
	if not (character and humanoid and root) then
		return false, "dead"
	end
	if (root.Position - part.Position).Magnitude > 16 then
		return false, "too far"
	end

	local kind = StickupService.Kinds[target.kind]
	local loot = StickupService.Random(kind.loot[1], kind.loot[2])
	target.readyAt = now + StickupService.COOLDOWN
	refreshPrompt(target)

	local serverEndsAt = workspace:GetServerTimeNow() + kind.heat
	local job: Job = {
		player = player, target = target, loot = loot, endsAt = now + kind.heat, serverEndsAt = serverEndsAt,
		squad = {}, done = false, died = nil,
	}
	jobs[player] = job
	player:SetAttribute("Bag", loot)
	player:SetAttribute("Heat", serverEndsAt)
	player:SetAttribute("HeatPlace", describe(target))
	job.died = humanoid.Died:Connect(function()
		onRobberDied(job)
	end)

	-- The crew that runs the block comes up the avenue.
	local NPCService = lazy("NPCService")
	if NPCService and NPCService.Spawn then
		for i, at in ipairs(StickupService.SquadPoints(target.street)) do
			local archetype = StickupService.SQUAD[(i - 1) % #StickupService.SQUAD + 1]
			local ok, model = pcall(NPCService.Spawn, archetype, at,
				{ respawn = false, ignoreCap = true, attributes = { StickupSquad = player.UserId } })
			if ok and model then
				table.insert(job.squad, model)
			end
		end
	end

	stickupEvent:FireAllClients("alarm", {
		at = part.Position, place = describe(target), kind = target.kind, robber = player.DisplayName,
		robberId = player.UserId, amount = loot, seconds = kind.heat, endsAt = serverEndsAt,
	})
	print(("[Stickup] %s robbed %s for $%d"):format(player.Name, describe(target), loot))

	task.spawn(function()
		while not job.done do
			StickupService.Step(job)
			task.wait(StickupService.CALL_EVERY)
		end
	end)
	return true
end

function StickupService.JobOf(player: Player): Job?
	return jobs[player]
end

--- Every part marked `Stickup` under `folder` becomes a target, with a hold-E prompt on it.
--- Safe to call again on the same folder (a rebuilt or baked district).
function StickupService.Wire(folder: Instance): number
	local n = 0
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") and type(d:GetAttribute("Stickup")) == "string" and not targets[d] then
			local kind = tostring(d:GetAttribute("StickupKind") or "register")
			if not StickupService.Kinds[kind] then
				kind = "register"
			end
			local prompt = Instance.new("ProximityPrompt")
			prompt.Name = "StickupPrompt"
			prompt.ObjectText = if kind == "atm" then "ATM" else tostring(d:GetAttribute("Stickup"))
			prompt.KeyboardKeyCode = Enum.KeyCode.E
			prompt.RequiresLineOfSight = false
			prompt.MaxActivationDistance = 8
			prompt.Parent = d
			local street = d:GetAttribute("StickupStreet")
			local target: Target = {
				part = d, prompt = prompt, name = tostring(d:GetAttribute("Stickup")), kind = kind, readyAt = 0,
				street = if typeof(street) == "Vector3" then street else d.Position,
			}
			targets[d] = target
			refreshPrompt(target)
			prompt.Triggered:Connect(function(player: Player)
				StickupService.Rob(player, d)
			end)
			d.Destroying:Connect(function()
				targets[d] = nil
			end)
			n += 1
		end
	end
	return n
end

--- Put every target's prompt right: "Emptied" while it restocks, "Rob ..." once it has.
function StickupService.Refresh()
	for _, target in pairs(targets) do
		refreshPrompt(target)
	end
end

function StickupService.Targets(): { Target }
	local out = {}
	for _, t in pairs(targets) do
		table.insert(out, t)
	end
	return out
end

Players.PlayerRemoving:Connect(function(player)
	local job = jobs[player]
	if job then
		endJob(job)
	end
end)

-- Targets fill back up on their own; a few seconds late is fine.
task.spawn(function()
	while true do
		task.wait(5)
		StickupService.Refresh()
	end
end)

-- The district may already be standing (it is built before this starts).
local existing = workspace:FindFirstChild("Downtown")
if existing then
	StickupService.Wire(existing)
end

return StickupService
