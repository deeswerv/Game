--!strict
-- STICK-UPS: rob a till or a cash machine in Downtown, then survive long enough to keep it.
--
--   * Hold E at a marked target -- the tills behind the counters at ZEE GUNS and ZEE TACTICS,
--     the cash machines outside them and at the 24/7 (Downtown marks them `Stickup` = where,
--     `StickupKind` = "register" or "atm"; DistrictService hands them to Wire).
--   * The clerk behind the counter puts their hands up and the till's drawer slides out, the
--     money flying out of it into your hands (or the cash machine spits it at you) -- all
--     presentation, on every client (StaffLife.client, Stickups.client).
--   * You come away with the bag, and the heat: the alarm goes off, the whole server is told
--     where and how much, a gold tag with the amount floats over you through walls, and the
--     crew that runs the block sends three of its own up the avenue after you. They are
--     steered onto you for as long as the heat lasts.
--   * Hold on to it for the heat's length and it is yours (cash and XP): a clean getaway.
--     Die first and it is gone -- and if a player put you down, the bag is theirs.
--   * The target is empty for a while after; one job at a time; not from a duel.
--   * NOTORIETY. Pull another job within ten minutes of the last and your stars go up (to
--     three): every star puts a third more in the bag and more XP on a getaway, but the heat
--     lasts longer and more of the crew come after you. Go quiet for ten minutes, or get
--     put down, and you are back to one. Your stars are the "Stars" attribute while you
--     hold a bag, and every alarm says how many you have.
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
-- Notoriety: stars from jobs pulled close together (see above).
StickupService.STARS = {
	max = 3,
	window = 600,                    -- a job within this long of the last one adds a star
	loot = 0.3,                      -- each star past the first puts this much more in the bag
	xp = 0.5,                        -- and this much more XP on a clean getaway
	heat = 15,                       -- seconds more heat per star
	extra = { { "Thug", "Shooter" }, { "Enforcer", "Gangster", "Shooter" } },   -- more crew at 2 and 3 stars
}
StickupService.HANDS_UP = 14        -- how long the shop's clerk keeps their hands up

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
	squad: { Model }, done: boolean, died: RBXScriptConnection?, stars: number,
}

local targets: { [BasePart]: Target } = {}
local jobs: { [Player]: Job } = {}
-- Notoriety: each player's stars and when their last job was pulled.
local notoriety: { [Player]: { stars: number, at: number } } = {}

--- The stars the next job would carry for `player` (what they have now if it is soon enough,
--- plus one).
function StickupService.NextStars(player: Player): number
	local n = notoriety[player]
	if n and StickupService.Clock() - n.at <= StickupService.STARS.window then
		return math.min(StickupService.STARS.max, n.stars + 1)
	end
	return 1
end

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
	target.prompt.ActionText = if empty then "Emptied" else (if target.kind == "atm" then "Rob ATM" else "Rob Register")
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
	job.player:SetAttribute("Stars", nil)
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
	-- Put down: the notoriety goes with the bag.
	notoriety[job.player] = nil
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
	local xp = math.floor(StickupService.XP * (1 + StickupService.STARS.xp * (job.stars - 1)) + 0.5)
	task.spawn(LevelSystem.AwardXP, job.player, xp)
	stickupEvent:FireAllClients("getaway", {
		robber = job.player.DisplayName, robberId = job.player.UserId, amount = job.loot, xp = xp,
		place = describe(job.target), stars = job.stars,
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

--- The shop's clerk, if the target has one: the "Clerk" model in the shop the target stands
--- in (the till and the cash machine are models of their own inside it).
function StickupService.ClerkOf(part: BasePart): Model?
	local at: Instance? = part.Parent
	for _ = 1, 3 do
		if not at then
			return nil
		end
		local clerk = at:FindFirstChild("Clerk")
		if clerk and clerk:IsA("Model") then
			return clerk
		end
		at = at.Parent
	end
	return nil
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
	local St = StickupService.STARS
	local stars = StickupService.NextStars(player)
	notoriety[player] = { stars = stars, at = now }
	local loot = math.floor(StickupService.Random(kind.loot[1], kind.loot[2]) * (1 + St.loot * (stars - 1)) + 0.5)
	local heat = kind.heat + St.heat * (stars - 1)
	target.readyAt = now + StickupService.COOLDOWN
	refreshPrompt(target)

	local serverEndsAt = workspace:GetServerTimeNow() + heat
	local job: Job = {
		player = player, target = target, loot = loot, endsAt = now + heat, serverEndsAt = serverEndsAt,
		squad = {}, done = false, died = nil, stars = stars,
	}
	jobs[player] = job
	player:SetAttribute("Bag", loot)
	player:SetAttribute("Heat", serverEndsAt)
	player:SetAttribute("HeatPlace", describe(target))
	player:SetAttribute("Stars", stars)
	job.died = humanoid.Died:Connect(function()
		onRobberDied(job)
	end)

	-- The crew that runs the block comes up the avenue.
	local NPCService = lazy("NPCService")
	if NPCService and NPCService.Spawn then
		-- The squad, and more of them for every star.
		local roster = table.clone(StickupService.SQUAD)
		for s = 2, stars do
			for _, archetype in ipairs(St.extra[s - 1] or {}) do
				table.insert(roster, archetype)
			end
		end
		local points = StickupService.SquadPoints(target.street)
		for i, archetype in ipairs(roster) do
			local base = points[(i - 1) % #points + 1]
			-- Later ones fan out a little from the same three approaches.
			local spread = (i - 1) // #points
			local at = base + Vector3.new(spread * 4 * (if i % 2 == 0 then 1 else -1), 0, spread * 6)
			local ok, model = pcall(NPCService.Spawn, archetype, at,
				{ respawn = false, ignoreCap = true, attributes = { StickupSquad = player.UserId } })
			if ok and model then
				table.insert(job.squad, model)
			end
		end
	end

	-- Whoever is behind the counter puts their hands up and keeps them there, facing the
	-- robber (StaffLife.client poses it from these).
	local clerk = StickupService.ClerkOf(part)
	if clerk then
		clerk:SetAttribute("HandsUpAt", workspace:GetServerTimeNow())
		clerk:SetAttribute("HandsUpFor", StickupService.HANDS_UP)
		clerk:SetAttribute("RobberId", player.UserId)
	end

	-- `part` lets every client open the till or the machine and throw the money out of it.
	stickupEvent:FireAllClients("alarm", {
		at = part.Position, part = part, place = describe(target), kind = target.kind, robber = player.DisplayName,
		robberId = player.UserId, amount = loot, seconds = heat, endsAt = serverEndsAt, stars = stars,
	})
	print(("[Stickup] %s robbed %s for $%d (%d star%s)"):format(player.Name, describe(target), loot, stars,
		if stars == 1 then "" else "s"))

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
			-- "[E] Rob Register / ZEE GUNS", "[E] Rob ATM / 24/7".
			prompt.ObjectText = (tostring(d:GetAttribute("Stickup")):gsub("^the ", ""))
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
	notoriety[player] = nil
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
