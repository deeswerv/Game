--!strict
-- Global leaderboards for kills, money and time played, shown on a board in the hub.
--
-- Rankings use OrderedDataStore so they span every server, not just this one.
-- Nothing here ever writes a player's stats downward: it only reads them and pushes
-- them outward, so a leaderboard bug can never cost someone their progress.

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunService = game:GetService("RunService")

local PlayerDataManager = require(ServerScriptService.PlayerDataManager)

local LeaderboardService = {}

local BOARDS = {
	{ id = "Kills", title = "MOST KILLS", store = "LB_Kills_v1", suffix = "" },
	{ id = "Coins", title = "RICHEST", store = "LB_Coins_v1", suffix = " coins" },
	{ id = "TimePlayed", title = "MOST PLAYED", store = "LB_Time_v1", suffix = "" },
	-- The duel ladder. Ordered DataStores sort ascending-or-descending on a single integer,
	-- which is exactly what a rating is, so the ladder needs no special handling.
	{ id = "Rating", title = "TOP RANKED", store = "LB_Rating_v1", suffix = " elo" },
}

local stores = {}
for _, b in ipairs(BOARDS) do
	-- Guarded: throws in an unpublished place. A missing store just leaves its board empty;
	-- every read and write of it is already inside a pcall.
	local ok, store = pcall(function()
		return DataStoreService:GetOrderedDataStore(b.store)
	end)
	stores[b.id] = ok and store or nil
end

local REFRESH_INTERVAL = 60
local PUSH_INTERVAL = 45

-- Accumulated playtime, flushed to the profile periodically.
local sessionStart: { [Player]: number } = {}

local function readableTime(seconds: number): string
	local h = math.floor(seconds / 3600)
	local mn = math.floor((seconds % 3600) / 60)
	if h > 0 then
		return string.format("%dh %dm", h, mn)
	end
	return string.format("%dm", mn)
end

local function statFor(player: Player, id: string): number?
	if id == "Kills" then
		local ls = player:FindFirstChild("leaderstats")
		local k = ls and ls:FindFirstChild("Kills")
		return k and k.Value or nil
	elseif id == "Coins" then
		local ls = player:FindFirstChild("leaderstats")
		local c = ls and ls:FindFirstChild("Coins")
		return c and c.Value or nil
	elseif id == "Rating" then
		local ok, replica = pcall(function()
			return PlayerDataManager:GetPlayerDataReplica(player):expect()
		end)
		if ok and replica then
			-- Only ranked players appear on the ladder. Publishing everyone at their starting
			-- rating would fill the board with people who have never duelled.
			local played = (replica.Data.DuelWins or 0) + (replica.Data.DuelLosses or 0)
				+ (replica.Data.DuelDraws or 0)
			if played > 0 then
				return math.floor(replica.Data.Rating or 1000)
			end
		end
	elseif id == "TimePlayed" then
		local ok, replica = pcall(function()
			return PlayerDataManager:GetPlayerDataReplica(player):expect()
		end)
		if ok and replica then
			local banked = replica.Data.TimePlayed or 0
			local live = sessionStart[player] and (os.clock() - sessionStart[player]) or 0
			return math.floor(banked + live)
		end
	end
	return nil
end

-- Push this player's numbers outward. Never pulls anything back into their save.
function LeaderboardService.Publish(player: Player)
	for _, b in ipairs(BOARDS) do
		local value = statFor(player, b.id)
		if value and value > 0 then
			pcall(function()
				stores[b.id]:SetAsync(tostring(player.UserId), math.floor(value))
			end)
		end
	end
end

-- Bank the session's playtime onto the profile.
local function flushTime(player: Player)
	local started = sessionStart[player]
	if not started then
		return
	end
	local elapsed = math.floor(os.clock() - started)
	if elapsed <= 0 then
		return
	end
	sessionStart[player] = os.clock()

	pcall(function()
		local replica = PlayerDataManager:GetPlayerDataReplica(player):expect()
		-- Only ever increases.
		replica:SetValue("TimePlayed", (replica.Data.TimePlayed or 0) + elapsed)
	end)
end

local cache: { [string]: { any } } = {}

function LeaderboardService.Fetch(id: string)
	local ok, pages = pcall(function()
		return stores[id]:GetSortedAsync(false, 10)
	end)
	if not ok or not pages then
		return cache[id] or {}
	end

	local rows = {}
	local okPage, page = pcall(function()
		return pages:GetCurrentPage()
	end)
	if okPage and page then
		for rank, entry in ipairs(page) do
			local userId = tonumber(entry.key)
			local name = "Player"
			if userId then
				local okName, resolved = pcall(function()
					return Players:GetNameFromUserIdAsync(userId)
				end)
				if okName then
					name = resolved
				end
			end
			table.insert(rows, { rank = rank, name = name, value = entry.value })
		end
	end
	cache[id] = rows
	return rows
end

-- ------------------------------------------------------ reading the board --

-- Three stone boards used to stand on the hub plaza. That plaza is gone, and hunting the map
-- for somewhere else to wedge them is the placement-by-algorithm that produces clutter. The
-- data layer below is untouched -- same ordered DataStores, same ranking, same refresh -- the
-- interface reads it now instead of it being printed onto geometry.

local Remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not Remotes then
	Remotes = Instance.new("Folder")
	Remotes.Name = "Remotes"
	Remotes.Parent = ReplicatedStorage
end

local BoardRequest = Remotes:FindFirstChild("LeaderboardRequest")
if not BoardRequest then
	local rf = Instance.new("RemoteFunction")
	rf.Name = "LeaderboardRequest"
	rf.Parent = Remotes
	BoardRequest = rf
end

local function refreshAll()
	for _, board in ipairs(BOARDS) do
		pcall(LeaderboardService.Fetch, board.id)
	end
end

--- Read-only, and deliberately served from the cache rather than calling Fetch. A client that
--- spams this must not be able to spend the game's DataStore budget: the refresh loop decides
--- when the store is actually read, and an invoke only ever returns what that loop last got.
local boardRemote = BoardRequest :: RemoteFunction
boardRemote.OnServerInvoke = function(_player: Player, id: unknown)
	if type(id) ~= "string" then
		return nil
	end
	for _, board in ipairs(BOARDS) do
		if board.id == id then
			return {
				id = board.id,
				title = board.title,
				suffix = board.suffix,
				rows = cache[id] or {},
			}
		end
	end
	return nil
end

--- Which boards exist, so the interface builds its tabs from here rather than repeating them.
function LeaderboardService.Boards()
	local out = {}
	for _, board in ipairs(BOARDS) do
		table.insert(out, { id = board.id, title = board.title, suffix = board.suffix })
	end
	return out
end

-- ------------------------------------------------------------------- lifecycle --

local function onPlayerAdded(player: Player)
	sessionStart[player] = os.clock()
	-- Mirror lifetime playtime onto leaderstats so it shows in the Roblox player list.
	task.spawn(function()
		task.wait(5)
		LeaderboardService.Publish(player)
	end)
end

local function onPlayerRemoving(player: Player)
	flushTime(player)
	LeaderboardService.Publish(player)
	sessionStart[player] = nil
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		pcall(flushTime, p)
		pcall(LeaderboardService.Publish, p)
	end
end)

function LeaderboardService.Build()
	task.spawn(function()
		task.wait(3)
		pcall(refreshAll)
		while true do
			task.wait(REFRESH_INTERVAL)
			pcall(refreshAll)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(PUSH_INTERVAL)
			for _, p in ipairs(Players:GetPlayers()) do
				pcall(flushTime, p)
				pcall(LeaderboardService.Publish, p)
			end
		end
	end)
end

LeaderboardService.Build()

return LeaderboardService
