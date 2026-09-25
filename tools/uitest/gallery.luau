--!nocheck
-- Screens for looking at: builds the interface with fixture data, walks through every screen
-- and writes a snapshot of each to out/, ready for shoot.mjs.
--
--   lune run tools/uitest/gallery.luau && node tools/uitest/shoot.mjs out/ui out/ui/*.json

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local World = require("./world")
local snapshot = require("./snapshot")
local R = World.R
local Enum = roblox.Enum

local args = {}
for _, a in ipairs(process.args) do
	if a ~= "--" then
		table.insert(args, a)
	end
end
local outDir = args[1] or "out/ui"
fs.writeDir(outDir)

World.loadPlace("build/Game.rbxl")
World.serverRemotes({
	GameRemotes = {
		GetOwnership = "RemoteFunction", LoadoutAction = "RemoteFunction", PurchaseItem = "RemoteFunction",
		PurchaseCamo = "RemoteFunction", PurchaseAttachment = "RemoteFunction", PurchaseCosmetic = "RemoteFunction",
		OwnershipChanged = "RemoteEvent", PromptPurchase = "RemoteEvent", QuestUpdated = "RemoteEvent",
		ProgressionReward = "RemoteEvent", XPGained = "RemoteEvent", OpenVendor = "RemoteEvent",
		OpenDialogue = "RemoteEvent", QuestAction = "RemoteFunction",
	},
	Remotes = {
		MatchAction = "RemoteFunction", MatchUpdate = "RemoteEvent", RangeAction = "RemoteFunction",
		ProfileRequest = "RemoteFunction", DailyAction = "RemoteFunction", BuildAction = "RemoteFunction",
		StatAction = "RemoteFunction", SettingsAction = "RemoteFunction",
		KillFeed = "RemoteEvent", KillFeedAll = "RemoteEvent", DeathReport = "RemoteEvent",
		GunEffect = "RemoteEvent", NPCEffect = "RemoteEvent",
	},
})
require("./fixtures")(World)

local only = args[2]
local sps = World.service("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
for _, name in ipairs({ "MainUI", "Killcam", "QuestUI" }) do
	World.run(sps:FindFirstChild(name))
end
World.advance(1.5)
World.serverFire("GameRemotes", "XPGained", 0, 340, 1000, 14)
World.advance(0.5)

local shots = {}
local function shot(name: string)
	if only and only ~= name then
		return
	end
	World.advance(0.8)
	local path = ("%s/%s.json"):format(outDir, name)
	snapshot(World, path)
	table.insert(shots, path)
	print("snap", name)
end

local function toggle(key)
	World.pressKey(key)
	World.advance(0.8)
end

-- 1. The plain HUD with a gun out.
local tool = World.backpack:FindFirstChildOfClass("Tool")
if tool then
	tool.Parent = World.character
end
shot("01_hud")

-- 2..6. Every menu.
toggle(Enum.KeyCode.B)
shot("02_inventory")
toggle(Enum.KeyCode.B)
toggle(Enum.KeyCode.M)
shot("03_shop")
toggle(Enum.KeyCode.M)
toggle(Enum.KeyCode.K)
shot("04_armory")
toggle(Enum.KeyCode.K)
toggle(Enum.KeyCode.P)
shot("05_profile")
toggle(Enum.KeyCode.P)
toggle(Enum.KeyCode.N)
shot("06_daily")
toggle(Enum.KeyCode.N)

toggle(Enum.KeyCode.L)
shot("10_character")
-- Spend a point through the real button, then look again.
local addOne = World.find(World.playerGui, "AddOne", "TextButton")
if addOne then
	World.click(addOne)
	World.advance(0.5)
end
shot("10b_character_spent")
toggle(Enum.KeyCode.L)
toggle(Enum.KeyCode.O)
shot("11_journal")
toggle(Enum.KeyCode.O)
toggle(Enum.KeyCode.F1)
shot("12_settings")
toggle(Enum.KeyCode.F1)

-- 7. The Tab board.
World.holdKey(Enum.KeyCode.Tab, true)
shot("07_board")
World.holdKey(Enum.KeyCode.Tab, false)
World.advance(0.3)

-- A Warlord close by: the boss bar.
do
	local folder = R.new("Folder")
	folder.Name = "NPCs"
	folder.Parent = World.workspace
	local boss = R.new("Model")
	boss.Name = "The Warlord of the Flats"
	boss:SetAttribute("Boss", true)
	boss:SetAttribute("Level", 30)
	boss:SetAttribute("PhaseMarks", "0.66,0.33")
	boss:SetAttribute("Phase", 2)
	local root = R.new("Part")
	root.Name = "HumanoidRootPart"
	root.Parent = boss
	local humanoid = R.new("Humanoid")
	humanoid.MaxHealth = 900
	humanoid.Health = 520
	humanoid.Parent = boss
	boss.Parent = folder
	World.advance(1)
	shot("13_boss")
	boss:Destroy()
	World.advance(0.5)
end

-- 8. A kill: feed + ELIMINATED.
World.serverFire("Remotes", "KillFeed", "Bandit", tool and tool.Name or "Warden")
World.advance(0.3)
shot("08_kill")
World.advance(2.5)

-- 9. The death card. The character really dies first, as it would.
do
	local humanoid = World.character:FindFirstChildOfClass("Humanoid")
	humanoid.Health = 0
	R.fire(humanoid, "Died")
	World.advance(0.2)
end
World.serverFire("Remotes", "DeathReport", {
	killerName = "xXSniperXx", killerUserId = 2, killerLevel = 22, isNpc = false,
	killerHealth = 37, killerMaxHealth = 100, weapon = "Sentinel", respawnIn = 3,
})
World.advance(0.6)
shot("09_death")
World.advance(4)

print(("\n%d error(s)"):format(#R.errors))
for _, line in ipairs(R.log) do
	if line:find("failed to build") or line:find("%[UI%]") then
		print("  " .. line)
	end
end
fs.writeFile(outDir .. "/shots.txt", table.concat(shots, "\n"))
process.exit(#R.errors > 0 and 1 or 0)
