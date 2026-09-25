--!strict
-- The ladder: a rating that moves when a duel resolves.
--
-- Uses Elo, because it answers the question a ladder is actually for -- "how much did this
-- result tell us?" -- rather than just counting wins. Beating someone far above you is worth
-- a great deal; beating someone far below you is worth almost nothing. A pure win counter
-- rewards farming weak opponents, which is the fastest way to make a ladder meaningless.
--
-- Server-only. Nothing here is reachable from a client: the rating changes exactly once per
-- resolved bout, driven by MatchService's own Finished event, and the client is never asked
-- what happened.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local MatchService = require(ServerScriptService.MatchService)

local RankService = {}

RankService.START = 1000
RankService.FLOOR = 100          -- a rating cannot spiral to nothing after a bad night

-- K decides how violently one result moves a rating. High while a player is new so their
-- rating finds its level quickly, then low so an established rating is stable.
RankService.K_NEW = 48
RankService.K_SETTLED = 24
RankService.PLACEMENT_MATCHES = 10

-- Named bands. A number alone means nothing to a player; "Gold" does.
RankService.TIERS = {
	{ id = "Bronze",   min = 0 },
	{ id = "Silver",   min = 900 },
	{ id = "Gold",     min = 1100 },
	{ id = "Platinum", min = 1300 },
	{ id = "Diamond",  min = 1500 },
	{ id = "Champion", min = 1750 },
}

local RATING_ATTRIBUTE = "Rating"
local TIER_ATTRIBUTE = "RankTier"

--- Which band a rating sits in.
function RankService.TierFor(rating: number): string
	local name = RankService.TIERS[1].id
	for _, tier in ipairs(RankService.TIERS) do
		if rating >= tier.min then
			name = tier.id
		end
	end
	return name
end

local function replicaOf(player: Player)
	local ok, replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
	end)
	return ok and replica or nil
end

--- Publish rating and tier as player attributes.
---
--- Attributes set on the server replicate READ-ONLY to clients, so the HUD can show a rank
--- that a client cannot forge. The profile stays the source of truth.
function RankService.Refresh(player: Player)
	local replica = replicaOf(player)
	if not replica then
		return
	end
	local rating = tonumber(replica.Data.Rating) or RankService.START
	player:SetAttribute(RATING_ATTRIBUTE, rating)
	player:SetAttribute(TIER_ATTRIBUTE, RankService.TierFor(rating))
end

function RankService.Get(player: Player): number
	local replica = replicaOf(player)
	return replica and (tonumber(replica.Data.Rating) or RankService.START) or RankService.START
end

--- Standard Elo expectation: the share of the result `self` is predicted to take.
local function expected(selfRating: number, otherRating: number): number
	return 1 / (1 + 10 ^ ((otherRating - selfRating) / 400))
end

local function kFor(matches: number): number
	return matches < RankService.PLACEMENT_MATCHES and RankService.K_NEW or RankService.K_SETTLED
end

--- Apply one resolved bout. `score` is 1 for a win, 0.5 for a draw, 0 for a loss.
local function applyResult(player: Player, opponentRating: number, score: number)
	local replica = replicaOf(player)
	if not replica then
		return
	end
	local data = replica.Data

	local rating = tonumber(data.Rating) or RankService.START
	local wins = tonumber(data.DuelWins) or 0
	local losses = tonumber(data.DuelLosses) or 0
	local draws = tonumber(data.DuelDraws) or 0
	local played = wins + losses + draws

	local delta = kFor(played) * (score - expected(rating, opponentRating))
	local updated = math.max(RankService.FLOOR, math.floor(rating + delta + 0.5))

	-- Streak is signed: positive while winning, negative while losing, reset by the opposite
	-- result. A draw leaves it alone, because a draw ends nothing.
	local streak = tonumber(data.DuelStreak) or 0
	if score == 1 then
		streak = streak >= 0 and streak + 1 or 1
		replica:SetValue("DuelWins", wins + 1)
	elseif score == 0 then
		streak = streak <= 0 and streak - 1 or -1
		replica:SetValue("DuelLosses", losses + 1)
	else
		replica:SetValue("DuelDraws", draws + 1)
	end

	replica:SetValue("Rating", updated)
	replica:SetValue("DuelStreak", streak)
	if streak > (tonumber(data.DuelBestStreak) or 0) then
		replica:SetValue("DuelBestStreak", streak)
	end

	RankService.Refresh(player)

	print(("[Rank] %s %s: %d -> %d (%+d), streak %d"):format(
		player.Name,
		score == 1 and "won" or score == 0 and "lost" or "drew",
		rating, updated, updated - rating, streak))
end

-- ------------------------------------------------------------------ hooks --

-- One bout, one rating change each. Both ratings are read BEFORE either is written, or the
-- second player would be scored against their opponent's already-updated number and the
-- exchange would not balance.
MatchService.Finished.Event:Connect(function(players, winner, _reason)
	if type(players) ~= "table" or #players < 2 then
		return
	end
	local a, b = players[1], players[2]
	if not a or not b or not a.Parent or not b.Parent then
		return
	end

	local ratingA, ratingB = RankService.Get(a), RankService.Get(b)

	if winner == nil then
		applyResult(a, ratingB, 0.5)
		applyResult(b, ratingA, 0.5)
	else
		applyResult(a, ratingB, winner == a and 1 or 0)
		applyResult(b, ratingA, winner == b and 1 or 0)
	end
end)

local function onPlayer(player: Player)
	task.spawn(function()
		-- The profile is not loaded the instant a player joins; Refresh reads it through the
		-- same promise everything else does, so a short wait is all that is needed.
		task.wait(3)
		RankService.Refresh(player)
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	onPlayer(p)
end

print("[Rank] ladder online")

return RankService
