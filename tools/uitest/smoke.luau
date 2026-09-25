--!nocheck
-- Smoke test for the interface: builds build/Game.rbxl's client UI in the emulator, opens and
-- closes every menu the way a player would, and fails on any error.
--
--   lune run tools/uitest/smoke.luau            everything
--   lune run tools/uitest/smoke.luau -- nodata   the server answers nothing (services down)

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R
local Enum = roblox.Enum

local noData = table.find(process.args, "nodata") ~= nil
World.verbose = table.find(process.args, "verbose") ~= nil

local placePath = "build/Game.rbxl"
local dropped = {}
for _, arg in ipairs(process.args) do
	local path = arg:match("^place=(.+)$")
	if path then
		placePath = path
	end
	local list = arg:match("^drop=(.+)$")
	if list then
		for name in list:gmatch("[^,]+") do
			dropped[name] = true
		end
	end
end
World.loadPlace(placePath)

World.serverRemotes({
	GameRemotes = {
		GetOwnership = "RemoteFunction", LoadoutAction = "RemoteFunction", PurchaseItem = "RemoteFunction",
		PurchaseCamo = "RemoteFunction", PurchaseAttachment = "RemoteFunction", PurchaseCosmetic = "RemoteFunction",
		PurchaseAbility = "RemoteFunction", OwnershipChanged = "RemoteEvent", PromptPurchase = "RemoteEvent",
		PerksChanged = "RemoteEvent", QuestUpdated = "RemoteEvent", QuestAction = "RemoteFunction",
		OpenDialogue = "RemoteEvent", ProgressionReward = "RemoteEvent", XPGained = "RemoteEvent",
		LevelUp = "RemoteEvent", PrestigeChanged = "RemoteEvent", PrestigeRequest = "RemoteFunction",
		OpenVendor = "RemoteEvent", AdminCheck = "RemoteFunction", AdminCommand = "RemoteFunction",
	},
	Remotes = {
		MatchAction = "RemoteFunction", MatchUpdate = "RemoteEvent", RangeAction = "RemoteFunction",
		ProfileRequest = "RemoteFunction", DailyAction = "RemoteFunction", BuildAction = "RemoteFunction",
		StatAction = "RemoteFunction", SettingsAction = "RemoteFunction",
		ContractAction = "RemoteFunction", ContractUpdate = "RemoteEvent", SupplyEvent = "RemoteEvent", WorldReward = "RemoteEvent", BountyEvent = "RemoteEvent",
		KillFeed = "RemoteEvent", KillFeedAll = "RemoteEvent", DeathReport = "RemoteEvent",
		GunEffect = "RemoteEvent", NPCEffect = "RemoteEvent", ChestEffect = "RemoteEvent",
	},
})

-- Remotes a failed server service would never have made.
for _, folderName in ipairs({ "GameRemotes", "Remotes" }) do
	local folder = World.service("ReplicatedStorage"):FindFirstChild(folderName)
	for name in pairs(dropped) do
		local r = folder and folder:FindFirstChild(name)
		if r then
			r:Destroy()
		end
	end
end

if not noData then
	local ok, fixtures = pcall(require, "./fixtures")
	if ok then
		fixtures(World)
	else
		print("(no fixtures: " .. tostring(fixtures) .. ")")
	end
end

local sps = World.service("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
local SCRIPTS = { "MainUI", "Killcam", "QuestUI", "PromptUI", "ChestUI" }
for _, name in ipairs(SCRIPTS) do
	local template = sps:FindFirstChild(name)
	if template then
		World.run(template)
	else
		R.report("test", "missing script " .. name)
	end
end

World.advance(2)

local gui = World.playerGui
local function check(label: string, cond: boolean)
	if cond then
		print("  ok   " .. label)
	else
		R.report("check", label)
	end
end

-- The HUD and the menu layer exist.
check("MainUI screen built", gui:FindFirstChild("MainUI") ~= nil)
check("menu layer built", gui:FindFirstChild("MainUIMenus") ~= nil)

local function openPanels()
	local menus = gui:FindFirstChild("MainUIMenus")
	local open = {}
	if menus then
		for _, child in ipairs(menus:GetChildren()) do
			if child:IsA("GuiObject") and child.Visible then
				table.insert(open, child.Name)
			end
		end
	end
	return open
end

for _, case in ipairs({
	{ key = Enum.KeyCode.B, name = "inventory (B)" },
	{ key = Enum.KeyCode.M, name = "shop (M)" },
	{ key = Enum.KeyCode.K, name = "armory (K)" },
	{ key = Enum.KeyCode.P, name = "profile (P)" },
	{ key = Enum.KeyCode.N, name = "daily (N)" },
	{ key = Enum.KeyCode.O, name = "quests (O)" },
	{ key = Enum.KeyCode.F1, name = "settings (F1)" },
	{ key = Enum.KeyCode.L, name = "contracts (L)" },
	{ key = Enum.KeyCode.Y, name = "level road (Y)" },
}) do
	World.pressKey(case.key)
	World.advance(0.6)
	local open = openPanels()
	check(case.name .. " opens -> " .. table.concat(open, ","), #open == 1)
	World.pressKey(case.key)
	World.advance(0.6)
	check(case.name .. " closes", #openPanels() == 0)
end

-- The "+" beside the cash opens the shop.
local plus = gui:FindFirstChild("MainUI") and World.find(gui:FindFirstChild("MainUI"), "Shop", "TextButton")
check("\"+\" button exists", plus ~= nil)
if plus then
	World.click(plus)
	World.advance(0.6)
	local open = openPanels()
	check("\"+\" opens the shop -> " .. table.concat(open, ","), #open == 1)
	if #open == 1 then
		World.pressKey(Enum.KeyCode.M)
		World.advance(0.6)
	end
end

-- Hold Tab for the board.
World.holdKey(Enum.KeyCode.Tab, true)
World.advance(0.3)
local board = gui:FindFirstChild("PlayerBoard")
check("Tab shows the player board", board ~= nil and board.Enabled)
World.holdKey(Enum.KeyCode.Tab, false)
World.advance(0.3)

World.advance(1)

print(("\n%d error(s)"):format(#R.errors))
for _, line in ipairs(R.log) do
	if line:find("%[UI%]") or line:find("failed to build") then
		print("  " .. line)
	end
end
if #R.errors > 0 then
	process.exit(1)
end
process.exit(0)
