--!strict
-- Killstreak rewards, server side: granting them as a streak climbs, and running the ones
-- that touch the world. ReplicatedStorage.StreakConfig has what each one is and when.
--
--   RADAR       the client draws it (every enemy's position is already on every client); this
--               only says when it starts and for how long.
--   OVERSHIELD  "Overshield" / "MaxOvershield" on the character. KillCredit soaks hits out
--               of it before armour and health, like the armour plates; server-written only.
--   AIRSTRIKE   a charge. The client sends "call it here"; the server checks the charge, the
--               distance and the caller, finds the ground under the mark, warns everyone
--               (the red mark, the jet), and then drops the shells through UtilityService's
--               blast -- damage, walls, kill credit and the explosion on every client are
--               the frag's, so an airstrike kill is a kill like any other.
--
-- The streak itself is BountyService's (StreakChanged), so duels and the range's dummies
-- never earn anything here, and dying ends it: an unused airstrike goes too.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local StreakConfig = require(ReplicatedStorage.StreakConfig)
local BountyService = require(ServerScriptService.BountyService)

local StreakRewardService = {}

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
-- Server -> client: "reward", "radar", "reset" (to the one player); "airstrike" and
-- "overshield" (to everyone, so everyone sees them).
local StreakEvent = ensure("StreakEvent")
-- Client -> server: ("airstrike", target: Vector3).
local StreakAction = ensure("StreakAction")

local charges: { [Player]: number } = {}
local lastCall: { [Player]: number } = {}

-- The blast is UtilityService's, looked up on first use rather than at load, the way the
-- other services that lean on another's internals do.
local utility: any = nil
local function blast(thrower: Player, at: Vector3)
	if utility == nil then
		local module = ServerScriptService:FindFirstChild("UtilityService")
		local ok, service = pcall(require, module)
		utility = ok and service or false
	end
	if utility then
		local a = StreakConfig.Airstrike
		utility.Frag(thrower, at, a.damage, a.radius, "Airstrike")
	end
end

local function alive(player: Player): (Model?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if character and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return character, root
	end
	return nil, nil
end

local function finite(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e6 and math.abs(v.Y) < 1e6
		and math.abs(v.Z) < 1e6
end

local function setCharges(player: Player, n: number)
	charges[player] = n
	player:SetAttribute("AirstrikeCharges", n)
end

function StreakRewardService.ChargesOf(player: Player): number
	return charges[player] or 0
end

--- Give `player` the reward `id` now. Returns whether it took (an overshield needs a body).
function StreakRewardService.Grant(player: Player, id: string, streak: number?): boolean
	local reward = StreakConfig.Get(id)
	if not reward then
		return false
	end
	if id == "Radar" then
		local r = StreakConfig.Radar
		StreakEvent:FireClient(player, "radar", { duration = r.duration, range = r.range })
	elseif id == "Overshield" then
		local character = alive(player)
		if not character then
			return false
		end
		local amount = StreakConfig.Overshield.amount
		character:SetAttribute("MaxOvershield", amount)
		character:SetAttribute("Overshield", amount)
		StreakEvent:FireAllClients("overshield", { userId = player.UserId })
	elseif id == "Airstrike" then
		setCharges(player, (charges[player] or 0) + 1)
	end
	StreakEvent:FireClient(player, "reward", { id = id, streak = streak or 0 })
	return true
end

--- Where the shells land: the ground under the mark, looking down past anyone standing on it.
local function groundUnder(target: Vector3): Vector3
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
	local hit = workspace:Raycast(target + Vector3.new(0, 40, 0), Vector3.new(0, -120, 0), params)
	return hit and hit.Position or target
end

--- The line the shells land along: `length` studs centred on the mark, along `dir`.
function StreakRewardService.ShellPoints(centre: Vector3, dir: Vector3): { Vector3 }
	local a = StreakConfig.Airstrike
	local points = {}
	for i = 1, a.shells do
		local t = if a.shells > 1 then (i - 1) / (a.shells - 1) - 0.5 else 0
		table.insert(points, centre + dir * (t * a.length))
	end
	return points
end

--- Call in `player`'s airstrike on `target`. Returns whether it was called, and why not.
function StreakRewardService.CallAirstrike(player: Player, target: unknown): (boolean, string?)
	if typeof(target) ~= "Vector3" or not finite(target :: Vector3) then
		return false, "bad target"
	end
	local mark = target :: Vector3
	if (charges[player] or 0) < 1 then
		return false, "no airstrike"
	end
	if player:GetAttribute("DuelState") == "duel" then
		return false, "in a duel"
	end
	local _, root = alive(player)
	if not root then
		return false, "dead"
	end
	local a = StreakConfig.Airstrike
	local flat = Vector3.new(mark.X - root.Position.X, 0, mark.Z - root.Position.Z)
	if flat.Magnitude > a.range or math.abs(mark.Y - root.Position.Y) > a.range then
		return false, "too far"
	end
	local now = os.clock()
	if lastCall[player] and now - lastCall[player] < 1 then
		return false, "too soon"
	end
	lastCall[player] = now

	setCharges(player, (charges[player] or 0) - 1)
	local centre = groundUnder(mark)
	-- The jet flies from the caller over the mark, so the run reads as coming from you.
	local dir = if flat.Magnitude > 1 then flat.Unit else Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z).Unit
	local points = StreakRewardService.ShellPoints(centre, dir)
	StreakEvent:FireAllClients("airstrike", {
		at = centre, dir = dir, points = points, warning = a.warning, gap = a.gap, radius = a.radius,
		altitude = a.altitude, caller = player.UserId, name = player.DisplayName,
		hitAt = workspace:GetServerTimeNow() + a.warning,
	})
	print(("[Streaks] %s called an airstrike at (%.0f, %.0f, %.0f)"):format(player.Name, centre.X, centre.Y, centre.Z))
	task.delay(a.warning, function()
		for i, point in ipairs(points) do
			if i > 1 then
				task.wait(a.gap)
			end
			blast(player, point)
		end
	end)
	return true
end

BountyService.StreakChanged.Event:Connect(function(player: Player, streak: number)
	if streak <= 0 then
		if (charges[player] or 0) > 0 then
			setCharges(player, 0)
		end
		StreakEvent:FireClient(player, "reset", {})
		return
	end
	if player:GetAttribute("DuelState") == "duel" then
		return
	end
	local reward = StreakConfig.RewardAt(streak)
	if reward then
		StreakRewardService.Grant(player, reward.id, streak)
	end
end)

StreakAction.OnServerEvent:Connect(function(player: Player, action: unknown, a: unknown)
	if action == "airstrike" then
		StreakRewardService.CallAirstrike(player, a)
	end
end)

local function onPlayer(player: Player)
	setCharges(player, 0)
end
Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayer(p)
end
Players.PlayerRemoving:Connect(function(player)
	charges[player] = nil
	lastCall[player] = nil
end)

return StreakRewardService
