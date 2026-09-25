--!strict
-- The daily reward: a reason to come back tomorrow.
--
-- Timed entirely on the SERVER, from os.time(). The client is never asked what day it is and
-- never told when the next one starts in its own terms -- it is handed a number of seconds to
-- count down. A daily reward keyed off client time is a daily reward you can claim as often
-- as you can change your system clock.
--
-- The ladder cycles every seven days, so the streak is worth keeping without ever becoming
-- unreachable for somebody who joins late.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerDataManager = require(ServerScriptService.PlayerDataManager)

local DailyService = {}

local SECONDS_PER_DAY = 86400

-- Seven rungs, then it repeats. Day seven is deliberately a jump rather than one more step --
-- the point of a streak is that breaking it costs something.
DailyService.LADDER = {
	{ coins = 250 },
	{ coins = 400 },
	{ coins = 600 },
	{ coins = 900 },
	{ coins = 1300 },
	{ coins = 1800 },
	{ coins = 3000, crystals = 10 },
}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local DailyAction = remotes:FindFirstChild("DailyAction")
if not DailyAction then
	local rf = Instance.new("RemoteFunction")
	rf.Name = "DailyAction"
	rf.Parent = remotes
	DailyAction = rf
end

local function today(): number
	return math.floor(os.time() / SECONDS_PER_DAY)
end

local function replicaOf(player: Player)
	local ok, replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
	end)
	return ok and replica or nil
end

--- Which rung a given streak lands on, 1-indexed and cycling.
function DailyService.RungFor(streak: number): number
	local count = #DailyService.LADDER
	if streak <= 0 then
		return 1
	end
	return ((streak - 1) % count) + 1
end

--- What the player would get if they claimed right now, and whether they can.
function DailyService.Status(player: Player)
	local replica = replicaOf(player)
	if not replica then
		return nil
	end
	local data = replica.Data
	local last = tonumber(data.LastDailyDay) or 0
	local streak = tonumber(data.DailyStreak) or 0
	local day = today()

	local claimable = day > last
	-- The streak the NEXT claim would put them on: continuing if yesterday, restarting if
	-- they missed a day.
	local nextStreak = (last > 0 and day == last + 1) and streak + 1 or 1
	local rung = DailyService.RungFor(claimable and nextStreak or streak)
	local reward = DailyService.LADDER[rung]

	return {
		claimable = claimable,
		streak = streak,
		nextStreak = nextStreak,
		bestStreak = tonumber(data.BestDailyStreak) or 0,
		rung = rung,
		ladder = DailyService.LADDER,
		coins = reward.coins,
		crystals = reward.crystals,
		-- Seconds, not a timestamp: the client counts down rather than comparing clocks.
		secondsUntilNext = claimable and 0
			or ((last + 1) * SECONDS_PER_DAY) - os.time(),
	}
end

--- Claim today's reward. Refuses twice in one day, whatever the client asks.
function DailyService.Claim(player: Player)
	local replica = replicaOf(player)
	if not replica then
		return { ok = false, reason = "Profile not ready" }
	end
	local data = replica.Data
	local last = tonumber(data.LastDailyDay) or 0
	local day = today()

	if day <= last then
		return { ok = false, reason = "Already claimed today" }
	end

	-- Consecutive continues the streak; a gap of any size restarts it at one. `last > 0`
	-- guards a brand new profile, whose zero would otherwise look like an infinite gap.
	local streak = (last > 0 and day == last + 1) and (tonumber(data.DailyStreak) or 0) + 1 or 1
	local reward = DailyService.LADDER[DailyService.RungFor(streak)]

	-- Record the claim BEFORE paying. If a payout errors the player loses a reward, which is
	-- recoverable; if the claim is recorded after, an error leaves the day unclaimed and the
	-- reward can be taken again.
	replica:SetValue("LastDailyDay", day)
	replica:SetValue("DailyStreak", streak)
	if streak > (tonumber(data.BestDailyStreak) or 0) then
		replica:SetValue("BestDailyStreak", streak)
	end

	if reward.coins then
		local stats = player:FindFirstChild("leaderstats")
		local coins = stats and stats:FindFirstChild("Coins")
		if coins and coins:IsA("IntValue") then
			coins.Value += reward.coins
		end
	end
	if reward.crystals then
		replica:SetValue("Crystals", (tonumber(data.Crystals) or 0) + reward.crystals)
	end

	print(("[Daily] %s claimed day %d of the ladder (streak %d)"):format(
		player.Name, DailyService.RungFor(streak), streak))

	return {
		ok = true,
		streak = streak,
		coins = reward.coins,
		crystals = reward.crystals,
	}
end

local dailyRemote = DailyAction :: RemoteFunction
dailyRemote.OnServerInvoke = function(player: Player, action: unknown)
	if action == "status" then
		return DailyService.Status(player)
	elseif action == "claim" then
		local result = DailyService.Claim(player)
		-- Hand back the fresh status too, so the panel never has to guess what changed.
		result.status = DailyService.Status(player)
		return result
	end
	return { ok = false, reason = "Unknown action" }
end

print("[Daily] reward ladder online")

return DailyService
