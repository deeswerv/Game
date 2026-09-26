--!nocheck
-- Achievements (AchievementConfig), checked without Studio:
--
--   * the list is well formed: unique ids, known categories, positive goals, every title
--     reward unique, every kind something the game actually reports;
--   * counting adds up totals and keeps the best for streaks and levels;
--   * unlocks happen exactly at the goal, and Completionist only after twenty others;
--   * every service that should report into it does (ContractService.Noted and the kinds
--     reported through ContractService.Note elsewhere).
--
--   lune run tools/uitest/achievements.luau

local fs = require("@lune/fs")
local World = require("./world")

local failures = 0
local function check(ok: boolean, what: string)
	if ok then
		print("  ok    " .. what)
	else
		failures += 1
		print("\27[31m  FAIL  " .. what .. "\27[0m")
	end
end

World.loadPlace("build/Game.rbxl")
local rs = World.service("ReplicatedStorage")
local Config = World.require(rs.AchievementConfig)

print("the list")
local ids, titles = {}, {}
local categories = {}
for _, c in ipairs(Config.Categories) do
	categories[c] = true
end
local wellFormed = true
for _, a in ipairs(Config.List) do
	if ids[a.id] or not categories[a.category] or a.goal <= 0 or type(a.reward.coins) ~= "number" then
		wellFormed = false
		print("    bad: " .. tostring(a.id))
	end
	ids[a.id] = true
	if a.reward.title then
		check(not titles[a.reward.title], "title \"" .. a.reward.title .. "\" is given once")
		titles[a.reward.title] = true
	end
end
check(wellFormed, ("%d achievements, well formed"):format(#Config.List))
check(#Config.List >= 20, "at least twenty to chase")

-- Every counted kind is reported somewhere in the server code.
local reported = {
	kill = "ContractService", headshot = "GunHandler", wallbang = "GunHandler", streak = "ContractService",
	longkill = "AchievementService", duel_win = "ContractService", duel_played = "ContractService",
	place = "AchievementService", boss = "ContractService", supply = "SupplyDropService",
	turf = "TurfWarService", stash = "DistrictService", crystal = "ContractService", bounty = "BountyService",
	contract = "ContractService", level = "AchievementService", achievement = "AchievementService",
	kingpin = "TurfWarService", streetcred = "TurfWarService",
}
for kind in pairs(Config.Kinds()) do
	local where = reported[kind]
	local path = where and ("src/ServerScriptService/" .. where .. (where == "GunHandler" and ".server.luau" or ".luau"))
	local source = path and fs.isFile(path) and fs.readFile(path) or ""
	check(where ~= nil and source:find('"' .. kind .. '"', 1, true) ~= nil,
		("\"%s\" is reported (%s)"):format(kind, tostring(where)))
end
local contracts = fs.readFile("src/ServerScriptService/ContractService.luau")
check(contracts:find("Noted:Fire", 1, true) ~= nil, "ContractService re-broadcasts what it counts")
local travel = fs.readFile("src/ServerScriptService/TravelService.luau")
check(travel:find('"travel"', 1, true) ~= nil, "TravelService reports where a player travelled")

print("counting")
local s = {}
s = Config.Count(s, "kill", 1)
s = Config.Count(s, "kill", 1)
check(s.kill == 2, "kills add up")
s = Config.Count(s, "streak", 4)
s = Config.Count(s, "streak", 2)
check(s.streak == 4, "a streak keeps the best run")
s = Config.Count(s, "level", 12)
s = Config.Count(s, "level", 9)
check(s.level == 12, "a level keeps the highest")

print("unlocking")
local newly = Config.Evaluate({ kill = 0 }, {})
check(#newly == 0, "nothing for nothing")
newly = Config.Evaluate({ kill = 1 }, {})
check(#newly == 1 and newly[1] == "first_blood", "the first kill unlocks First Blood")
newly = Config.Evaluate({ kill = 49 }, { first_blood = true })
check(#newly == 0, "49 kills is not Hunter")
newly = Config.Evaluate({ kill = 50 }, { first_blood = true })
check(table.find(newly, "hunter") ~= nil and #newly == 1, "50 is")
newly = Config.Evaluate({ kill = 300, streak = 16 }, {})
check(table.find(newly, "veteran") and table.find(newly, "unstoppable") and table.find(newly, "on_a_roll"),
	"several at once when a profile catches up")

-- Completionist: twenty others unlocked.
local nineteen = {}
local n = 0
for _, a in ipairs(Config.List) do
	if a.kind ~= "achievement" and n < 19 then
		nineteen[a.id] = true
		n += 1
	end
end
newly = Config.Evaluate({}, nineteen)
check(table.find(newly, "completionist") == nil, "Completionist waits at nineteen")
-- One more, unlocked in the same evaluation, tips it over.
local twentieth = nil
for _, a in ipairs(Config.List) do
	if a.kind ~= "achievement" and not nineteen[a.id] and not a.best then
		twentieth = a
		break
	end
end
local stats = {}
if twentieth then
	-- Only this one: give its kind exactly its goal, and check nothing cheaper in the same
	-- kind is missing from the nineteen (it would unlock too, which is fine).
	stats[twentieth.kind] = twentieth.goal
end
newly = Config.Evaluate(stats, nineteen)
check(twentieth ~= nil and table.find(newly, twentieth.id) ~= nil and table.find(newly, "completionist") ~= nil,
	("and unlocks with the twentieth (%s), in the same pass"):format(twentieth and twentieth.id or "?"))

print(failures == 0 and "\27[32mall achievement checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
require("@lune/process").exit(failures == 0 and 0 or 1)
