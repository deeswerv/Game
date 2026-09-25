--!strict
-- Duels: a queue, a bout that resolves, and a way home.
--
-- The reference game's whole identity -- a rank, a win rate, a record -- only exists because
-- its matches END. That is what this provides: a bounded fight with a winner, which the
-- ladder and the profile card can then be built on.
--
-- Entirely server-owned. The client may ask to join or leave the queue and may ask what the
-- state is; it decides nothing. Scores, the win, and every teleport happen here.
--
-- The hardest requirement is not the fighting, it is that NOBODY IS EVER STRANDED. A player
-- who disconnects mid-duel, whose opponent leaves, who dies at the moment the clock expires,
-- or who is in the arena when the server shuts down, must still end up back where they were
-- standing with the loadout they had. Every exit path below routes through `release`.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local ArenaService = require(ServerScriptService.ArenaService)
local KillCredit = require(ServerScriptService.KillCredit)

local MatchService = {}

MatchService.SCORE_TO_WIN = 3
MatchService.TIME_LIMIT = 180        -- seconds; a duel that cannot end is a soft-lock
MatchService.COUNTDOWN = 4

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local function ensure(className: string, name: string)
	local existing = remotes:FindFirstChild(name)
	if existing then
		return existing
	end
	local made = Instance.new(className)
	made.Name = name
	made.Parent = remotes
	return made
end

local MatchAction = ensure("RemoteFunction", "MatchAction") :: RemoteFunction
local MatchUpdate = ensure("RemoteEvent", "MatchUpdate") :: RemoteEvent

-- ------------------------------------------------------------------ state --

type Bout = {
	id: number,
	players: { Player },
	score: { [Player]: number },
	state: string,             -- "countdown" | "live" | "over"
	endsAt: number,
	winner: Player?,
	dealt: { [Player]: number },   -- damage each duellist landed on the other
	taken: { [Player]: number },
}

local queue: { Player } = {}
local bouts: { [number]: Bout } = {}
local boutOf: { [Player]: Bout } = {}
local homeOf: { [Player]: CFrame } = {}
local nextId = 0

local function indexOf(list, value): number?
	for i, v in ipairs(list) do
		if v == value then
			return i
		end
	end
	return nil
end

-- ------------------------------------------------------------------ report --

local function describe(player: Player)
	local bout = boutOf[player]
	if not bout then
		return {
			in_queue = indexOf(queue, player) ~= nil,
			queued = #queue,
		}
	end
	local opponent = bout.players[1] == player and bout.players[2] or bout.players[1]
	local now = os.clock()
	return {
		in_match = true,
		state = bout.state,
		you = bout.score[player] or 0,
		them = (opponent and bout.score[opponent]) or 0,
		target = MatchService.SCORE_TO_WIN,
		opponentName = opponent and opponent.DisplayName or "?",
		opponentUserId = opponent and opponent.UserId or 0,
		-- The match clock only, not the countdown in front of it.
		secondsLeft = math.max(0, math.floor(math.min(bout.endsAt - now, MatchService.TIME_LIMIT))),
		-- Seconds until the fight starts, while it has not.
		countdown = bout.state == "countdown"
			and math.max(0, math.ceil(bout.endsAt - MatchService.TIME_LIMIT - now)) or 0,
		won = bout.winner ~= nil and bout.winner == player or nil,
	}
end

local function push(player: Player)
	if player.Parent then
		MatchUpdate:FireClient(player, describe(player))
	end
end

local function pushAll(bout: Bout)
	for _, p in ipairs(bout.players) do
		push(p)
	end
end

-- ------------------------------------------------------------------ places --

--- Move a player somewhere far away, safely.
---
--- Public because the gun range needs exactly the same thing and the risky part -- waiting
--- for the destination to stream in before moving anyone -- should exist once, not twice.
function MatchService.PlaceAt(player: Player, cf: CFrame): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not root then
		return false
	end
	local basePart = root :: BasePart

	-- Ask for the destination to stream in BEFORE moving, not after.
	--
	-- StreamingEnabled is on and the arena is 3000 studs up. Measured from a client standing
	-- in the world: the Arena folder existed with ZERO parts in it. Teleporting first means
	-- arriving above a floor that has not loaded, which is a player falling out of the map at
	-- the start of their duel. The same applies to the trip home.
	--
	-- pcall'd and time-limited because a streaming request that fails must not abort the
	-- teleport -- landing badly is recoverable, being stuck in the queue forever is not.
	pcall(function()
		player:RequestStreamAroundAsync(cf.Position, 5)
	end)

	character:PivotTo(cf)
	-- Assigned through a local on purpose: a line beginning with "(" straight after a call is
	-- parsed as that call's argument list, which is the "Ambiguous syntax" error.
	basePart.AssemblyLinearVelocity = Vector3.zero
	return true
end

local placeAt = MatchService.PlaceAt

--- Send a player back to where they were before the duel, and forget them.
---
--- Called from every exit: a win, a forfeit, a disconnect, a shutdown. It is deliberately
--- safe to call twice and safe to call for somebody who was never in a bout.
local function release(player: Player)
	local home = homeOf[player]
	homeOf[player] = nil
	boutOf[player] = nil
	if home then
		-- Lift slightly: returning to the exact floor CFrame can drop a character through a
		-- thin platform on a bad frame.
		placeAt(player, home + Vector3.new(0, 3, 0))
	end
	push(player)
end

-- ------------------------------------------------------------------ bout --

local function finish(bout: Bout, winner: Player?, reason: string)
	if bout.state == "over" then
		return
	end
	bout.state = "over"
	bout.winner = winner
	bouts[bout.id] = nil

	for _, p in ipairs(bout.players) do
		if p.Parent then
			local opponent = bout.players[1] == p and bout.players[2] or bout.players[1]
			-- Everything the results screen shows, from this player's side. In a duel your
			-- deaths are exactly your opponent's kills.
			MatchUpdate:FireClient(p, {
				in_match = true,
				state = "over",
				won = winner ~= nil and winner == p or false,
				draw = winner == nil,
				reason = reason,
				opponentName = opponent and opponent.DisplayName or "?",
				opponentUserId = opponent and opponent.UserId or 0,
				target = MatchService.SCORE_TO_WIN,
				you = bout.score[p] or 0,
				them = (opponent and bout.score[opponent]) or 0,
				dealt = math.floor(bout.dealt[p] or 0),
				taken = math.floor(bout.taken[p] or 0),
				theirDealt = math.floor((opponent and bout.dealt[opponent]) or 0),
				theirTaken = math.floor((opponent and bout.taken[opponent]) or 0),
			})
		end
	end

	MatchService.Finished:Fire(bout.players, winner, reason)

	-- A short beat on the result screen before the trip home.
	task.delay(3, function()
		for _, p in ipairs(bout.players) do
			release(p)
		end
	end)

	print(("[Match] bout %d over: %s (%s)"):format(bout.id,
		winner and (winner.Name .. " wins") or "draw", reason))
end

local function scorePoint(scorer: Player)
	local bout = boutOf[scorer]
	if not bout or bout.state ~= "live" then
		return
	end
	bout.score[scorer] = (bout.score[scorer] or 0) + 1
	pushAll(bout)
	if bout.score[scorer] >= MatchService.SCORE_TO_WIN then
		finish(bout, scorer, "score")
	end
end

local function begin(a: Player, b: Player)
	nextId += 1
	local bout: Bout = {
		id = nextId,
		players = { a, b },
		score = { [a] = 0, [b] = 0 },
		state = "countdown",
		endsAt = os.clock() + MatchService.COUNTDOWN + MatchService.TIME_LIMIT,
		winner = nil,
		dealt = { [a] = 0, [b] = 0 },
		taken = { [a] = 0, [b] = 0 },
	}
	bouts[bout.id] = bout

	for index, p in ipairs(bout.players) do
		boutOf[p] = bout
		-- Remember home BEFORE moving them, or there is nowhere to send them back to.
		local character = p.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if root then
			homeOf[p] = (root :: BasePart).CFrame
		end
		placeAt(p, ArenaService.SpawnCFrame(index))
	end
	pushAll(bout)

	print(("[Match] bout %d: %s vs %s"):format(bout.id, a.Name, b.Name))

	task.delay(MatchService.COUNTDOWN, function()
		if bout.state == "countdown" then
			bout.state = "live"
			pushAll(bout)
		end
	end)
end

-- ------------------------------------------------------------------ queue --

local function tryPair()
	while #queue >= 2 do
		local a = table.remove(queue, 1)
		local b = table.remove(queue, 1)
		-- Anyone who left while waiting is simply dropped rather than paired with a ghost.
		if a and b and a.Parent and b.Parent and a.Character and b.Character then
			begin(a, b)
		else
			if a and a.Parent then table.insert(queue, 1, a) end
			if b and b.Parent then table.insert(queue, 1, b) end
			return
		end
	end
end

function MatchService.Join(player: Player): boolean
	if boutOf[player] or indexOf(queue, player) then
		return false
	end
	table.insert(queue, player)
	push(player)
	tryPair()
	return true
end

function MatchService.Leave(player: Player): boolean
	local at = indexOf(queue, player)
	if at then
		table.remove(queue, at)
		push(player)
		return true
	end
	-- Leaving a live bout is a forfeit, not an escape.
	local bout = boutOf[player]
	if bout and bout.state ~= "over" then
		local opponent = bout.players[1] == player and bout.players[2] or bout.players[1]
		finish(bout, opponent, "forfeit")
		return true
	end
	return false
end

-- ------------------------------------------------------------------ hooks --

MatchService.Finished = Instance.new("BindableEvent")

--- Called by KillCredit's award path so a duel kill counts toward the bout.
function MatchService.RegisterKill(killer: Player?, victim: Player?)
	if not killer or not victim or killer == victim then
		return
	end
	local bout = boutOf[killer]
	if bout and boutOf[victim] == bout then
		scorePoint(killer)
	end
end

function MatchService.InBout(player: Player): boolean
	return boutOf[player] ~= nil
end

--- Duellists respawn INSIDE the arena, not at the world spawn.
local function onCharacterAdded(player: Player, character: Model)
	local bout = boutOf[player]
	if not bout or bout.state == "over" then
		return
	end
	character:WaitForChild("HumanoidRootPart", 10)
	local index = indexOf(bout.players, player) or 1
	placeAt(player, ArenaService.SpawnCFrame(index))
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		task.spawn(onCharacterAdded, player, character)
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayer(p)
end

Players.PlayerRemoving:Connect(function(player)
	local at = indexOf(queue, player)
	if at then
		table.remove(queue, at)
	end
	-- Their opponent gets the win rather than being left alone in an arena.
	local bout = boutOf[player]
	if bout and bout.state ~= "over" then
		local opponent = bout.players[1] == player and bout.players[2] or bout.players[1]
		finish(bout, opponent, "opponent left")
	end
	boutOf[player] = nil
	homeOf[player] = nil
end)

-- The clock. One loop for every bout rather than a thread each, so a bout can never outlive
-- its own timer.
task.spawn(function()
	while true do
		task.wait(1)
		for _, bout in pairs(bouts) do
			if bout.state == "live" and os.clock() >= bout.endsAt then
				local a, b = bout.players[1], bout.players[2]
				local sa, sb = bout.score[a] or 0, bout.score[b] or 0
				finish(bout, sa == sb and nil or (sa > sb and a or b), "time")
			elseif bout.state ~= "over" then
				pushAll(bout)
			end
		end
	end
end)

-- Nobody is left in the sky when the server closes.
game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		pcall(release, p)
	end
end)

-- ------------------------------------------------------------------ remote --

MatchAction.OnServerInvoke = function(player: Player, action: unknown)
	if action == "queue" then
		return MatchService.Join(player)
	elseif action == "leave" then
		return MatchService.Leave(player)
	elseif action == "state" then
		return describe(player)
	end
	return false
end

-- Duel kills score through KillCredit's existing award event rather than by editing it.
-- KillCredit already decides who gets credit, already refuses self-kills, and already knows
-- the victim; re-deriving any of that here would be a second opinion that could disagree.
KillCredit.KillAwarded.Event:Connect(function(killer: Player?, _humanoid: Humanoid?, victim: Player?)
	MatchService.RegisterKill(killer, victim)
end)

-- Damage between the two duellists, for the results screen. Only a live bout counts, and
-- only hits one duellist lands on the other -- a stray NPC in the way is not the duel.
KillCredit.Damaged.Event:Connect(function(humanoid: Humanoid, dealt: number, attacker: Player?)
	if not attacker then
		return
	end
	local victim = Players:GetPlayerFromCharacter(humanoid.Parent)
	local bout = boutOf[attacker]
	if not victim or not bout or bout.state ~= "live" or boutOf[victim] ~= bout or victim == attacker then
		return
	end
	bout.dealt[attacker] = (bout.dealt[attacker] or 0) + dealt
	bout.taken[victim] = (bout.taken[victim] or 0) + dealt
end)

print("[Match] duel queue open")

return MatchService
