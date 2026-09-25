--!nocheck
-- What the server answers, in the shapes the real services return, so every panel has
-- something true-to-life to draw.

return function(World)
	local R = World.R
	local rs = World.service("ReplicatedStorage")
	local WeaponConfig = World.require(rs:FindFirstChild("WeaponConfig"))

	local names = {}
	for name in pairs(WeaponConfig.Weapons) do
		table.insert(names, name)
	end
	table.sort(names)
	local owned = {}
	for i, name in ipairs(names) do
		if i % 2 == 1 then
			table.insert(owned, name)
		end
	end

	-- A few guns in the backpack so the hotbar has something to show.
	local storeitems = rs:FindFirstChild("storeitems")
	if storeitems then
		local n = 0
		for _, name in ipairs(owned) do
			local tool = storeitems:FindFirstChild(name)
			if tool and tool:IsA("Tool") and n < 4 then
				local copy = tool:Clone()
				copy.Parent = World.backpack
				copy:SetAttribute("Ammo", 18)
				n += 1
			end
		end
	end

	R.serverFunctions.GetOwnership = function()
		return {
			OwnedItems = owned,
			OwnedAbilities = {},
			OwnedCamos = {},
			OwnedAttachments = {},
			OwnedCosmetics = {},
			OwnedVariants = {},
		}
	end
	R.serverFunctions.LoadoutAction = function()
		return { ok = true }
	end
	R.serverFunctions.MatchAction = function(action)
		return { in_queue = false, queued = 0 }
	end
	R.serverFunctions.RangeAction = function()
		return false
	end
	R.serverFunctions.ProfileRequest = function()
		return {
			name = "Tester", handle = "@TestPlayer", level = 14, prestige = 0, rating = 1185, tier = "Gold",
			wins = 23, losses = 11, draws = 2, winRate = 67.6, decided = 34, streak = 4, bestStreak = 9,
			kills = 412, deaths = 233, kd = 1.77, flawless = false,
			weapons = { { name = owned[1] or "Warden", kills = 180 }, { name = owned[2] or "Sentinel", kills = 96 } },
			mastery = {}, titles = { "Rookie", "Sharpshooter" }, title = "Sharpshooter",
			nextUnlock = { name = "Redwood", level = 16 },
		}
	end
	-- DailyService.LADDER as shipped.
	local ladder = {
		{ coins = 250 }, { coins = 400 }, { coins = 600 }, { coins = 900 }, { coins = 1300 }, { coins = 1800 },
		{ coins = 3000, crystals = 10 },
	}
	R.serverFunctions.DailyAction = function(action)
		local status = {
			claimable = true, streak = 3, nextStreak = 4, bestStreak = 6, rung = 4, ladder = ladder,
			coins = 900, secondsUntilNext = 0,
		}
		if action == "claim" then
			return { ok = true, coins = 400, status = status }
		end
		return status
	end
	R.serverFunctions.BuildAction = function(action)
		return { ok = true, builds = {}, camos = {}, attachments = {} }
	end

	-- Character stats, spent the way CharacterService would.
	local stats = { points = 6, stats = { Strength = 12, Defense = 8, Stamina = 4 }, level = 14, exp = 340,
		maxExp = 1000, prestige = 0, max = 50, perLevel = 3, inDuel = false }
	World.player:SetAttribute("StatPoints", stats.points)
	World.player:SetAttribute("Crystals", 37)
	R.serverFunctions.StatAction = function(action, id, count)
		if action == "add" and stats.stats[id] then
			local n = math.min(tonumber(count) or 1, stats.points, stats.max - stats.stats[id])
			if n <= 0 then
				return { ok = false, reason = "No stat points left", state = stats }
			end
			stats.stats[id] += n
			stats.points -= n
			World.player:SetAttribute("StatPoints", stats.points)
			return { ok = true, spent = n, state = stats }
		elseif action == "reset" then
			local refund = 0
			for k, v in pairs(stats.stats) do
				refund += v
				stats.stats[k] = 0
			end
			stats.points += refund
			World.player:SetAttribute("StatPoints", stats.points)
			return { ok = true, refunded = refund, state = stats }
		end
		return stats
	end

	local saved = {}
	R.serverFunctions.SettingsAction = function(action, values)
		if action == "set" then
			for k, v in pairs(values) do
				saved[k] = v
			end
			return { ok = true }
		end
		return saved
	end

	R.serverFunctions.QuestAction = function(action)
		return {
			active = { id = "Marksmen", title = "Eyes on the Ridge", label = "Marksmen defeated", progress = 1, goal = 3 },
			completed = { "ClearTheCamp", "TheBrute", "ScoutTheFlats" },
			completedCount = 3, totalQuests = 10, level = 14,
		}
	end
end
