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
	-- ContractService.State: today's three, one part done, one paid.
	R.serverFunctions.ContractAction = function(action)
		return {
			contracts = {
				{ id = "hunter", tier = "Easy", title = "Hunter", text = "Eliminate 8 enemies", icon = "🎯",
					target = 8, progress = 8, paid = true, reward = { coins = 700, xp = 350 } },
				{ id = "marksman", tier = "Medium", title = "Marksman", text = "Land 10 headshots", icon = "🎖",
					target = 10, progress = 6, paid = false, reward = { coins = 1400, xp = 700, crystals = 2 } },
				{ id = "longshot", tier = "Hard", title = "Long Shot", text = "Get 4 kills from over 120 studs",
					icon = "🔭", target = 4, progress = 1, paid = false, reward = { coins = 2600, xp = 1300, crystals = 5 } },
			},
			done = 1, bonus = { coins = 2500, xp = 1000, crystals = 5 }, bonusPaid = false,
			secondsLeft = 5 * 3600 + 12 * 60, lifetime = 23,
		}
	end
	-- TravelService.Places as shipped.
	R.serverFunctions.TravelAction = function(action)
		if action == "go" then
			return { ok = true }
		end
		local rbx = require("@lune/roblox")
		local V3, C3 = rbx.Vector3, rbx.Color3
		return {
			places = {
				{ id = "Hub", label = "The Crossing", blurb = "Spawn, the 1v1 pads and the harbour.", icon = "⚓", levels = "LV 1-2",
					colour = C3.fromRGB(88, 176, 232), position = V3.new(-155, 1.25, 275) },
				{ id = "Downtown", label = "Downtown", blurb = "Shops, the Duel Hall, contracts and turf wars.", icon = "🏙",
					levels = "LV 4-7", colour = C3.fromRGB(236, 120, 150), position = V3.new(-155, 1000.5, 1330) },
				{ id = "Flats", label = "The Flats", blurb = "The bandit camp and the guard post, at war.", icon = "⚔",
					levels = "LV 3-5", colour = C3.fromRGB(214, 150, 70), position = V3.new(-465, 1, 160) },
				{ id = "Mine", label = "Crystal Mine", blurb = "Behind the falls: crystal seams to mine.", icon = "💎",
					levels = "LV 1-3", colour = C3.fromRGB(150, 110, 240), position = V3.new(-101, 4, 61) },
				{ id = "WatchPoint", label = "Watchpoint", blurb = "High ground over the western isles.", icon = "🔭",
					levels = "LV 2-4", colour = C3.fromRGB(110, 190, 140), position = V3.new(-320, 6, 291) },
				{ id = "Reach", label = "The Reach", blurb = "The far east. The toughest fights, the best loot.", icon = "🏔",
					levels = "LV 6-9", colour = C3.fromRGB(120, 150, 220), position = V3.new(145, 1.9, 375) },
			},
		}
	end
	R.serverFunctions.BuildAction = function(action)
		return { ok = true, builds = {}, camos = {}, attachments = {} }
	end

	World.player:SetAttribute("Crystals", 37)

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
