--!strict
-- MainUI: the one place that binds the interface to the game.
--
-- Everything visual lives in ReplicatedStorage.UI.Modules and is told what to show. This
-- script is the only part that knows where the numbers come from -- leaderstats, the XPGained
-- remote, the Humanoid, the equipped Tool's attributes. Keeping the seam here is what lets
-- the interface be replaced without touching a single gameplay system.
--
-- Every connection made for a character is torn down when that character goes, so respawning
-- does not leave a second set of listeners running against a dead Humanoid.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Modules = ReplicatedStorage:WaitForChild("UI"):WaitForChild("Modules")
local Hud = require(Modules:WaitForChild("Hud"))
local Hotbar = require(Modules:WaitForChild("Hotbar"))
local KillFeed = require(Modules:WaitForChild("KillFeed"))
local Objective = require(Modules:WaitForChild("Objective"))
local Duel = require(Modules:WaitForChild("Duel"))
local Profile = require(Modules:WaitForChild("Profile"))
local Daily = require(Modules:WaitForChild("Daily"))
local Inventory = require(Modules:WaitForChild("Inventory"))
local Market = require(Modules:WaitForChild("Market"))
local Workshop = require(Modules:WaitForChild("Workshop"))
local Nav = require(Modules:WaitForChild("Nav"))
local Feedback = require(Modules:WaitForChild("Feedback"))
local Scoreboard = require(Modules:WaitForChild("Scoreboard"))
local Remote = require(Modules:WaitForChild("Remote"))
local Journal = require(Modules:WaitForChild("Journal"))
local Settings = require(Modules:WaitForChild("Settings"))
local BossBar = require(Modules:WaitForChild("BossBar"))
local Toast = require(Modules:WaitForChild("Toast"))
local Contracts = require(Modules:WaitForChild("Contracts"))
local WorldEvents = require(Modules:WaitForChild("WorldEvents"))
local Bounties = require(Modules:WaitForChild("Bounties"))
local LevelRoad = require(Modules:WaitForChild("LevelRoad"))
local Travel = require(Modules:WaitForChild("Travel"))
local Achievements = require(Modules:WaitForChild("Achievements"))
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))

local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- The old custom hotbar turned the Roblox backpack off and the new one replaces it, so this
-- has to move with it -- otherwise deleting that script quietly hands the default backpack
-- back and the player ends up with two hotbars. The stock player list goes the same way: the
-- Tab board below replaces it, and two lists on one key would fight over the corner.
task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
		end)
		if ok then
			return
		end
		task.wait(0.5)      -- CoreGui is not always ready on the first frame of a join
	end
end)

-- ------------------------------------------------------------------ screen --

local screen = Instance.new("ScreenGui")
screen.Name = "MainUI"
screen.ResetOnSpawn = false          -- the HUD survives death; rebuilding it every respawn
screen.IgnoreGuiInset = true         -- would drop connections and flicker
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 10
screen.Parent = playerGui

local Components = require(Modules:WaitForChild("Components"))
Components.BindScale(screen)

-- Every panel is built through this. One that throws while building is replaced by an inert
-- stand-in (every method a no-op) and named in the output, instead of stopping this script
-- and taking every panel after it down too -- which is exactly how the shop, the dock and
-- the menu hotkeys all went missing at once.
local function safe(name: string, build: () -> any): any
	local ok, result = pcall(build)
	if ok and result ~= nil then
		return result
	end
	warn(("[MainUI] %s failed to build: %s"):format(name, tostring(result)))
	return setmetatable({}, {
		__index = function()
			return function() end
		end,
	})
end

local hud = safe("HUD", function()
	return Hud.new(screen)
end)
local feedback = safe("Feedback", function()
	return Feedback.new(playerGui)
end)
local board = safe("Scoreboard", function()
	return Scoreboard.new(playerGui)
end)

-- Held, not toggled: Tab shows the board for exactly as long as you want to look at it.
UserInputService.InputBegan:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.Tab and not UserInputService:GetFocusedTextBox() then
		board:SetOpen(true)
	end
end)
UserInputService.InputEnded:Connect(function(input: InputObject)
	if input.KeyCode == Enum.KeyCode.Tab then
		board:SetOpen(false)
	end
end)
local killFeed = safe("KillFeed", function()
	return KillFeed.new(screen)
end)
local objective = safe("Objective", function()
	return Objective.new(screen)
end)
local bossBar = safe("BossBar", function()
	return BossBar.new(screen)
end)
local toast = safe("Toast", function()
	return Toast.new(screen)
end)
-- Supply drops: the banner, the marker over the crate, and who looted it.
local worldEvents = safe("WorldEvents", function()
	return WorldEvents.new(toast, playerGui, screen)
end)
Remote.get("Remotes", "TurfEvent").OnClientEvent:Connect(function(kind: unknown, data: unknown)
	if type(kind) == "string" then
		worldEvents:HandleTurf(kind, data)
	end
end)
Remote.get("Remotes", "SupplyEvent").OnClientEvent:Connect(function(kind: unknown, data: unknown)
	if type(kind) == "string" then
		worldEvents:Handle(kind, data)
	end
end)
-- Streaks and bounties: the calls, the WANTED tags, your own price.
local bounties = safe("Bounties", function()
	return Bounties.new(screen, playerGui, toast)
end)
Remote.get("Remotes", "BountyEvent").OnClientEvent:Connect(function(kind: unknown, data: unknown)
	if type(kind) == "string" then
		bounties:Handle(kind, data)
	end
end)

-- Remotes are held lazily (see UI.Modules.Remote): building the interface never waits on
-- the server, and a service that failed to start costs its own feature, not the whole UI.
local rangeAction = Remote.get("Remotes", "RangeAction")

-- The gun range is a place you go and come back from, not a panel. One key does both, and the
-- server owns where "back" is -- the client never says where to put you.
local function toggleRange()
	task.spawn(function()
		pcall(function()
			local inRange = rangeAction:InvokeServer("state") == true
			rangeAction:InvokeServer(inRange and "leave" or "enter")
		end)
	end)
end
local duel = safe("Duel", function()
	return Duel.new(screen, {
	matchAction = Remote.get("Remotes", "MatchAction") :: any,
	matchUpdate = Remote.get("Remotes", "MatchUpdate") :: any,
}, {
	-- The duel scoreboard takes the top of the screen; cash and level step aside for it.
	onScoreboard = function(visible: boolean)
		hud:SetIdentityVisible(not visible)
	end,
	-- The PLAY diamond lives bottom-left now, clear of the ELIMINATED call; nothing to move.
	onPlayVisible = function(_visible: boolean) end,
})
end)

-- --------------------------------------------------------------- objective --

local journalRef: any = nil      -- the quest journal, built with the menus further down
local roadRef: any = nil         -- the level road, likewise

-- QuestService already broadcasts the whole state on every change, so the card just redraws
-- from it. Rewards are read out of QuestConfig here because the active-quest block in that
-- payload carries only progress, not what it pays.
task.spawn(function()
	local okConfig, QuestConfig = pcall(function()
		return require(ReplicatedStorage:WaitForChild("QuestConfig"))
	end)

	local function rewardsFor(id: string?)
		if not okConfig or not id then
			return nil
		end
		local quest = QuestConfig.Get(id)
		return quest and quest.rewards or nil
	end

	Remote.get("GameRemotes", "QuestUpdated").OnClientEvent:Connect(function(state)
		if journalRef then
			journalRef:SetState(state)
		end
		local active = type(state) == "table" and state.active or nil
		objective:Set(active, active and rewardsFor(active.id) or nil)
	end)
end)

-- ----------------------------------------------------------------- hotbar --

-- Slot order has to be STABLE. Equipping moves a Tool from the Backpack into the character,
-- so anything derived from child order would reshuffle the bar every time you switched
-- weapons and the number keys would stop meaning what they meant a second ago. Sorting by
-- name gives the same order regardless of where each tool currently lives.
local function carried(): { Tool }
	local tools: { Tool } = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		for _, child in ipairs(backpack:GetChildren()) do
			if child:IsA("Tool") then
				table.insert(tools, child)
			end
		end
	end
	local character = player.Character
	if character then
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Tool") then
				table.insert(tools, child)
			end
		end
	end
	table.sort(tools, function(a, b)
		return a.Name < b.Name
	end)
	return tools
end

local function equipSlot(index: number)
	local tools = carried()
	local tool = tools[index]
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not tool or not humanoid then
		return
	end
	if tool.Parent == character then
		humanoid:UnequipTools()      -- pressing the slot you already hold puts it away
	else
		humanoid:EquipTool(tool)
	end
end

-- The hotbar joins the HUD's weapon dock, so the slots and the ammo count share one row
-- in the bottom-right corner the way the references lay them out.
local hotbar = safe("Hotbar", function()
	return Hotbar.new(hud.dock, equipSlot)
end)

local function refreshHotbar()
	local character = player.Character
	local entries = {}
	local equippedIndex: number? = nil
	for index, tool in ipairs(carried()) do
		local cfg = WeaponConfig.Weapons[tool.Name]
		local isEquipped = character ~= nil and tool.Parent == character
		if isEquipped then
			equippedIndex = index
		end
		table.insert(entries, { name = tool.Name, rarity = cfg and cfg.Rarity, equipped = isEquipped })
	end
	hotbar:Set(entries)
	hotbar:SetEquipped(equippedIndex)
end

-- Equipping fires several container events in a row; coalesce them into one rebuild so the
-- ViewportFrames are not torn down and remade three times per switch.
local rebuildQueued = false
local function queueHotbar()
	if rebuildQueued then
		return
	end
	rebuildQueued = true
	task.delay(0.08, function()
		rebuildQueued = false
		refreshHotbar()
	end)
end

-- ------------------------------------------------------------- progression --

-- Coins are kept on leaderstats by the server, so this reads rather than tracks.
task.spawn(function()
	-- No short timeout: if the leaderstats script is slow to start, the cash still arrives.
	local stats = player:WaitForChild("leaderstats", 1e6)
	local coins = stats and stats:WaitForChild("Coins", 1e6)
	if not coins or not coins:IsA("ValueBase") then
		return
	end
	local function refresh()
		hud:SetCurrency((coins :: any).Value)
	end
	refresh()
	coins.Changed:Connect(refresh)
end)

-- LevelSystem fires this once on join with the loaded profile, then again on every gain, so
-- there is a real starting value to draw rather than a placeholder that corrects itself.
-- Anything earned -- a level milestone, a weapon mastery tier -- comes down one channel and
-- is shown in the feed the kills already use, so a reward reads as part of the fight rather
-- than a popup that stops it.
do
	Remote.get("GameRemotes", "ProgressionReward").OnClientEvent:Connect(function(kind: unknown, a: unknown, b: unknown, c: unknown, d: unknown)
		if kind == "Milestone" then
			local level = tonumber(a) or 0
			local earned = type(b) == "table" and table.concat(b, ", ") or ""
			local note = type(c) == "string" and c or nil
			killFeed:Notice(("LEVEL %d"):format(level), note or earned)
		elseif kind == "PrestigeReady" then
			toast:Push({
				title = "MAX LEVEL  -  PRESTIGE IS OPEN",
				text = "Open the Level Road [Y] to prestige for coins, crystals, a title and +5% XP",
				icon = "⭐",
				colour = Color3.fromRGB(255, 206, 84),
				duration = 8,
			})
		elseif kind == "Mastery" then
			local weapon = tostring(a)
			local tier = tostring(b)
			local earned = type(c) == "table" and #c > 0 and ("  -  " .. table.concat(c, ", ")) or ""
			killFeed:Notice("MASTERY", ("%s %s%s"):format(weapon, string.upper(tier), earned))
		end
	end)
end

-- Somebody prestiged: everyone hears about it, the way the kill feed calls out a streak.
do
	local okConfig, GameConfig = pcall(function()
		return require(ReplicatedStorage:WaitForChild("GameConfig")) :: any
	end)
	Remote.get("GameRemotes", "PrestigeChanged").OnClientEvent:Connect(function(who: unknown, prestige: unknown)
		local n = tonumber(prestige)
		if typeof(who) ~= "Instance" or not n or n <= 0 then
			return
		end
		local tier = okConfig and GameConfig.GetPrestigeTier(n) or { name = "" }
		local name = who == player and "YOU" or string.upper((who :: Player).DisplayName)
		killFeed:Notice("PRESTIGE " .. n, ("%s reached %s"):format(name, string.upper(tostring(tier.name))))
	end)
end

do
	-- The first message is the loaded profile, not a gain; only a rise after that is a
	-- level-up worth celebrating.
	local lastLevel: number? = nil
	Remote.get("GameRemotes", "XPGained").OnClientEvent:Connect(function(amount: number, exp: number, maxExp: number, level: number)
		local now = math.floor(tonumber(level) or 1)
		hud:SetLevel(now, exp, maxExp)
		if roadRef then
			roadRef:SetLevel(now, tonumber(exp) or 0, tonumber(maxExp) or 1)
		end
		if lastLevel ~= nil and type(amount) == "number" and amount > 0 then
			hud:XpPopup(amount)
		end
		if lastLevel ~= nil and now > lastLevel then
			feedback:LevelUp(now)
			-- What the new level opened up, straight from the level road.
			for l = lastLevel + 1, now do
				for _, node in ipairs(LevelRoad.At(l)) do
					toast:Push({
						title = "UNLOCKED  " .. node.title,
						text = node.kind == "weapon" and "Now in the shop  [M]" or node.detail,
						icon = node.icon,
						colour = node.colour,
						duration = 5,
					})
				end
			end
		end
		lastLevel = now
	end)
end

-- ----------------------------------------------------------------- vitals --

-- One table of connections per character. Respawning clears it before rebinding, which is the
-- difference between a HUD that stays correct and one that slowly accumulates dead listeners.
local characterConnections: { RBXScriptConnection } = {}
local dead = false          -- PLAY stays down while the death card is up

local function clearCharacter()
	for _, c in ipairs(characterConnections) do
		c:Disconnect()
	end
	table.clear(characterConnections)
end

local function track(connection: RBXScriptConnection)
	table.insert(characterConnections, connection)
end

-- ----------------------------------------------------------------- weapon --

local ammoConnections: { RBXScriptConnection } = {}

local function clearAmmo()
	for _, c in ipairs(ammoConnections) do
		c:Disconnect()
	end
	table.clear(ammoConnections)
end

local function bindTool(tool: Tool?)
	clearAmmo()

	if not tool then
		hud:SetWeapon(nil)
		hud:SetReloading(false)
		return
	end

	local cfg = WeaponConfig.Weapons[tool.Name]
	if not cfg then
		-- Something the player is holding that the config does not describe. Show the name and
		-- no ammo rather than inventing numbers for it.
		hud:SetWeapon(tool.Name, nil, nil)
		hud:SetAmmo(0, 0)
		return
	end

	local isGun = cfg.Type == "Gun"
	local fireMode = isGun and (cfg.Automatic and "AUTO" or "SEMI") or nil
	hud:SetWeapon(tool.Name, cfg.Rarity, fireMode)

	if not isGun then
		hud:SetAmmo(0, 0)
		hud:SetReloading(false)
		return
	end

	local capacity = cfg.MagazineSize or 0

	local function refreshAmmo()
		hud:SetAmmo(tonumber(tool:GetAttribute("Ammo")) or 0, capacity)
	end
	local function refreshReloading()
		hud:SetReloading(tool:GetAttribute("Reloading") == true)
	end

	refreshAmmo()
	refreshReloading()
	table.insert(ammoConnections, tool:GetAttributeChangedSignal("Ammo"):Connect(refreshAmmo))
	table.insert(ammoConnections, tool:GetAttributeChangedSignal("Reloading"):Connect(refreshReloading))
end

local function currentTool(character: Model): Tool?
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			return child
		end
	end
	return nil
end

-- ------------------------------------------------------------- character --

local function onCharacter(character: Model)
	clearCharacter()

	feedback:Reset()
	dead = false
	duel:SetPlayAllowed(player:GetAttribute("Scoped") ~= true)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		track(humanoid.Died:Connect(function()
			dead = true
			duel:SetPlayAllowed(false)
		end))
		local lastHealth = humanoid.Health
		local function refreshHealth()
			hud:SetHealth(humanoid.Health, humanoid.MaxHealth)
			-- The screen answers a hit: red from the edges, an arrow at the shooter, and the
			-- world draining of colour as health runs low.
			if humanoid.Health < lastHealth then
				feedback:Damaged(lastHealth - humanoid.Health, humanoid.MaxHealth)
			end
			lastHealth = humanoid.Health
			feedback:SetHealth(humanoid.Health, humanoid.MaxHealth)
		end
		refreshHealth()
		track(humanoid.HealthChanged:Connect(refreshHealth))
		track(humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refreshHealth))
	end

	-- Armour is optional: the meter stays hidden unless something sets the attribute.
	local function refreshArmour()
		hud:SetArmour(tonumber(character:GetAttribute("Armour")) or 0,
			tonumber(character:GetAttribute("MaxArmour")) or 0)
	end
	refreshArmour()
	track(character:GetAttributeChangedSignal("Armour"):Connect(refreshArmour))
	track(character:GetAttributeChangedSignal("MaxArmour"):Connect(refreshArmour))

	bindTool(currentTool(character))
	track(character.ChildAdded:Connect(function(child: Instance)
		if child:IsA("Tool") then
			bindTool(child)
			queueHotbar()
		end
	end))
	track(character.ChildRemoved:Connect(function(child: Instance)
		if child:IsA("Tool") then
			if not currentTool(character) then
				bindTool(nil)
			end
			queueHotbar()
		end
	end))

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		track(backpack.ChildAdded:Connect(queueHotbar))
		track(backpack.ChildRemoved:Connect(queueHotbar))
	end
	queueHotbar()
end

if player.Character then
	task.spawn(onCharacter, player.Character)
end
player.CharacterAdded:Connect(onCharacter)
player.CharacterRemoving:Connect(function()
	clearCharacter()
	clearAmmo()
	hud:SetWeapon(nil)
end)

-- ---------------------------------------------------------------- threats --

-- Shots that land near us are remembered with where they came from, so the hit indicator can
-- point back along them. Both the players' remote and the NPCs' batched one are read; each
-- only ever tells us things every client is already shown.
local THREAT_RADIUS = 5

local function nearMe(point: unknown): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return typeof(point) == "Vector3" and root ~= nil and root:IsA("BasePart")
		and ((point :: Vector3) - root.Position).Magnitude <= THREAT_RADIUS
end

do
	Remote.get("Remotes", "GunEffect").OnClientEvent:Connect(function(kind: unknown, shooter: unknown, _tool: unknown, origin: unknown, endPoints: unknown)
			if kind ~= "Shot" or shooter == player or typeof(origin) ~= "Vector3" or type(endPoints) ~= "table" then
				return
			end
			for _, point in ipairs(endPoints :: { any }) do
				if nearMe(point) then
					feedback:Threat(origin :: Vector3)
					return
				end
			end
		end)

	Remote.get("Remotes", "NPCEffect").OnClientEvent:Connect(function(batch: unknown)
			if type(batch) ~= "table" then
				return
			end
			for _, event in ipairs(batch :: { any }) do
				-- { "Shot", model, origin, endPoint }
				if type(event) == "table" and event[1] == "Shot" and typeof(event[3]) == "Vector3" and nearMe(event[4]) then
					feedback:Threat(event[3])
				end
			end
		end)
end

-- ---------------------------------------------------------------- menus --

-- Menus live in their own ScreenGui above the HUD, so a panel can never be drawn underneath
-- the thing it is supposed to cover.
local menuLayer = Instance.new("ScreenGui")
menuLayer.Name = "MainUIMenus"
menuLayer.ResetOnSpawn = false
menuLayer.IgnoreGuiInset = true
menuLayer.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
menuLayer.DisplayOrder = 20
menuLayer.Parent = playerGui
Components.BindScale(menuLayer)

local function gameRemote(name: string): any
	return Remote.get("GameRemotes", name)
end
local function remote(name: string): any
	return Remote.get("Remotes", name)
end

local inventory = safe("Inventory", function()
	return Inventory.new(menuLayer, {
		getOwnership = gameRemote("GetOwnership"),
		loadoutAction = gameRemote("LoadoutAction"),
	})
end)

local market = safe("Shop", function()
	return Market.new(menuLayer, {
		getOwnership = gameRemote("GetOwnership"),
		PurchaseItem = gameRemote("PurchaseItem"),
		PurchaseCamo = gameRemote("PurchaseCamo"),
		PurchaseAttachment = gameRemote("PurchaseAttachment"),
		PurchaseVFX = gameRemote("PurchaseVFX"),
		VFXAction = gameRemote("VFXAction"),
		ownershipChanged = gameRemote("OwnershipChanged"),
		promptPurchase = gameRemote("PromptPurchase"),
	})
end)

local profile = safe("Profile", function()
	return Profile.new(menuLayer, {
		profileRequest = remote("ProfileRequest"),
	})
end)

local daily = safe("Daily", function()
	return Daily.new(menuLayer, {
		dailyAction = remote("DailyAction"),
	})
end)

local workshop = safe("Armory", function()
	return Workshop.new(menuLayer, {
		getOwnership = gameRemote("GetOwnership"),
		buildAction = remote("BuildAction"),
	})
end)

local journal = safe("Journal", function()
	return Journal.new(menuLayer, {
		questAction = gameRemote("QuestAction"),
	})
end)
journalRef = journal

local travel = safe("Travel", function()
	return Travel.new(menuLayer, {
		travelAction = remote("TravelAction"),
	}, menuLayer)
end)

local road = safe("LevelRoad", function()
	return LevelRoad.new(menuLayer)
end)
roadRef = road

local contracts = safe("Contracts", function()
	return Contracts.new(menuLayer, {
		contractAction = remote("ContractAction"),
	})
end)

-- Forward-declared: claiming from the panel shows a banner, and the toasts are built below.
local announceClaim: (any) -> () = function() end
local achievements = safe("Achievements", function()
	return Achievements.new(menuLayer, {
		achievementAction = remote("AchievementAction"),
	}, function(a)
		announceClaim(a)
	end)
end)

local settings = safe("Settings", function()
	return Settings.new(menuLayer, {
		settingsAction = remote("SettingsAction"),
	})
end)
-- Saved volumes, camera shake and field of view take effect on join, panel open or not.
settings:Load()

-- Forward-declared: the nav is built below, but opening a menu by hotkey should still retire
-- that menu's first-time hint on the nav.
local nav: any

local NAV_ID = {
	[inventory] = "Inventory", [market] = "Market", [workshop] = "Workshop",
	[profile] = "Profile", [daily] = "Daily", [journal] = "Journal",
	[settings] = "Settings", [contracts] = "Contracts", [travel] = "Travel", [achievements] = "Achievements",
}
local PANELS = { inventory, market, workshop, profile, daily, journal, contracts, road, travel, achievements, settings }

-- Opening one panel closes the others. Two full-screen menus stacked on each other is how a
-- player loses track of what Escape is going to do.
local function openOnly(target)
	for _, panel in ipairs(PANELS) do
		if panel ~= target then
			panel:Close()
		end
	end
	target:Toggle()
	if nav and NAV_ID[target] then
		nav:DismissHint(NAV_ID[target])
	end
end

-- The "+" beside the cash goes straight to the shop, as it does in the references, and so
-- does the armory's "unlock in shop" on a gun you do not own yet.
hud:OnShop(function()
	openOnly(market)
end)
-- The level diamond opens the level road: where you are, and what the next levels pay.
hud:OnLevel(function()
	openOnly(road)
end)

-- Crystals: their own chip beside the cash, from an attribute the server publishes.
local function refreshCrystals()
	hud:SetCrystals(tonumber(player:GetAttribute("Crystals")) or 0)
end
player:GetAttributeChangedSignal("Crystals"):Connect(refreshCrystals)
refreshCrystals()
workshop:OnShop(function()
	openOnly(market)
end)

-- The vendor NPC asks for the market by name, so walking up to the stall still opens it.
gameRemote("OpenVendor").OnClientEvent:Connect(function()
	inventory:Close()
	market:Toggle()
end)

-- Hints are the first-session teaching: the three things a new player should find first.
nav = safe("Nav", function()
	-- Two columns; the tiles with a first-session hint (Shop, Daily) sit in the left one so
	-- their bubbles point out into open screen rather than across a neighbour.
	return Nav.new(screen, {
		{ id = "Market", label = "Shop", key = "[M]", hint = "Unlock New Guns!", onActivated = function()
			openOnly(market)
		end },
		{ id = "Inventory", label = "Items", key = "[B]", onActivated = function()
			openOnly(inventory)
		end },
		{ id = "Daily", label = "Daily", key = "[N]", hint = "Free Daily Reward!", onActivated = function()
			openOnly(daily)
		end },
		{ id = "Workshop", label = "Armory", key = "[K]", onActivated = function()
			openOnly(workshop)
		end },
		{ id = "Journal", label = "Quests", key = "[O]", onActivated = function()
			openOnly(journal)
		end },
		{ id = "Contracts", label = "Contracts", key = "[L]", onActivated = function()
			openOnly(contracts)
		end },
		{ id = "Achievements", label = "Awards", key = "[H]", onActivated = function()
			openOnly(achievements)
		end },
		{ id = "Profile", label = "Profile", key = "[P]", onActivated = function()
			openOnly(profile)
		end },
		-- Touch has no Tab key, so the board is a tile too (a tap opens it, another shuts it).
		{ id = "Players", label = "Players", key = "[Tab]", icon = "📋", onActivated = function()
			board:Toggle()
		end },
		{ id = "Travel", label = "Travel", key = "[T]", onActivated = function()
			openOnly(travel)
		end },
		{ id = "Settings", label = "Settings", key = "[F1]", onActivated = function()
			openOnly(settings)
		end },
	})
end)

-- ----------------------------------------------------------- world doors --

-- Downtown's shop doors and the contracts board carry a prompt that names a panel; walking
-- up and pressing E opens it, exactly as the hotkey would. Rewards found in the world (the
-- rooftop stash) come back as a banner.
do
	local ProximityPromptService = game:GetService("ProximityPromptService")
	local PANEL_FOR = { Market = market, Workshop = workshop, Contracts = contracts, Inventory = inventory }
	ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt, who: Player)
		if who ~= player then
			return
		end
		local target = PANEL_FOR[tostring(prompt:GetAttribute("OpenPanel") or "")]
		if target then
			openOnly(target)
		end
	end)

	remote("WorldReward").OnClientEvent:Connect(function(data: unknown)
		if type(data) ~= "table" then
			return
		end
		local info = data :: any
		if info.kind == "reward" then
			toast:Banner({
				title = tostring(info.title or "REWARD"),
				subtitle = string.format("+$%s     +%s XP     +%s 💎", tostring(info.coins or 0), tostring(info.xp or 0),
					tostring(info.crystals or 0)),
				colour = Color3.fromRGB(255, 196, 30),
				sound = "Ring",
			})
		else
			toast:Push({ title = tostring(info.title or ""), text = info.text and tostring(info.text) or nil, icon = "📦",
				colour = Color3.fromRGB(150, 156, 170) })
		end
	end)
end

-- ----------------------------------------------------------- achievements --

-- An unlock is a banner and a badge on the Awards tile; the reward is claimed in the panel.
do
	local achievementAction = remote("AchievementAction")
	local function refreshBadge()
		task.spawn(function()
			local ok, state = pcall(function()
				return achievementAction:InvokeServer("state")
			end)
			if ok and type(state) == "table" and nav then
				nav:SetBadge("Achievements", tonumber(state.ready) or 0)
			end
		end)
	end
	remote("AchievementEvent").OnClientEvent:Connect(function(kind: unknown, data: unknown)
		if kind ~= "unlocked" or type(data) ~= "table" then
			return
		end
		local info = data :: any
		toast:Banner({
			title = "ACHIEVEMENT UNLOCKED",
			subtitle = ("%s  %s  ·  PRESS H TO CLAIM"):format(tostring(info.icon or "🏆"), string.upper(tostring(info.title or ""))),
			colour = Color3.fromRGB(255, 196, 40),
			sound = "Ring",
			duration = 4,
		})
		refreshBadge()
		if achievements:IsOpen() then
			achievements:Refresh()
		end
	end)
	announceClaim = function(a: any)
		local reward = a and a.reward or {}
		toast:Banner({
			title = string.upper(tostring(a and a.title or "REWARD")),
			subtitle = Achievements.RewardText(reward),
			colour = Color3.fromRGB(255, 196, 40),
			sound = "Ring",
			duration = 3.5,
		})
		refreshBadge()
	end
	task.delay(4, refreshBadge)
end

-- -------------------------------------------------------------- contracts --

-- Contract news: a card for progress, the banner for a finished one, and the nav tile's
-- badge counting what is still to do today.
do
	local TIER = {
		Easy = Color3.fromRGB(88, 214, 110),
		Medium = Color3.fromRGB(70, 160, 255),
		Hard = Color3.fromRGB(190, 110, 255),
	}
	local contractAction = remote("ContractAction")
	local function refreshBadge()
		task.spawn(function()
			local ok, state = pcall(function()
				return contractAction:InvokeServer("state")
			end)
			if ok and type(state) == "table" and type(state.contracts) == "table" then
				nav:SetBadge("Contracts", #state.contracts - (tonumber(state.done) or 0))
			end
		end)
	end
	remote("ContractUpdate").OnClientEvent:Connect(function(kind: unknown, data: unknown)
		if type(data) ~= "table" then
			return
		end
		local info = data :: any
		local colour = TIER[info.tier] or Color3.fromRGB(255, 196, 30)
		if kind == "progress" then
			local target = math.max(1, tonumber(info.target) or 1)
			local progress = tonumber(info.progress) or 0
			toast:Push({
				title = string.upper(tostring(info.title or "Contract")),
				text = string.format("%d / %d", progress, target),
				icon = tostring(info.icon or "📋"),
				colour = colour,
				progress = progress / target,
				duration = 2.6,
			})
		elseif kind == "complete" then
			toast:Banner({
				title = "CONTRACT COMPLETE",
				subtitle = string.upper(tostring(info.title or "")) .. "     " .. Contracts.RewardText(info.reward),
				colour = colour,
				sound = "Ring",
			})
			refreshBadge()
			if contracts:IsOpen() then
				contracts:Refresh()
			end
		elseif kind == "bonus" then
			toast:Banner({
				title = "ALL CONTRACTS DONE",
				subtitle = "BONUS     " .. Contracts.RewardText(info.reward),
				colour = Color3.fromRGB(255, 196, 30),
				sound = "Ring",
			})
		end
	end)
	task.delay(6, refreshBadge)
end

-- --------------------------------------------------------------- feed --

do
	Remote.get("Remotes", "KillFeed").OnClientEvent:Connect(function(victimName: unknown, weaponName: unknown)
		if type(victimName) ~= "string" then
			return
		end
		killFeed:Push(victimName, type(weaponName) == "string" and weaponName or nil)
		killFeed:Eliminated(victimName)
	end)

	-- Everyone else's player kills. Our own are already in the feed from the remote above.
	Remote.get("Remotes", "KillFeedAll").OnClientEvent:Connect(function(killer: unknown, victim: unknown, weapon: unknown, killerId: unknown, victimId: unknown)
		if killerId == player.UserId or type(killer) ~= "string" or type(victim) ~= "string" then
			return
		end
		killFeed:PushOther(killer, victim, type(weapon) == "string" and weapon or nil, victimId == player.UserId)
	end)
end

-- --------------------------------------------------------- number keys --

-- Roblox names the digit keys "One", "Two" and so on, with no digit in the name to read. The
-- values are the ASCII codes though, and the keypad row is contiguous the same way, so both
-- rows come out of arithmetic rather than a lookup table.
local ROW_ONE = Enum.KeyCode.One.Value
local PAD_ONE = Enum.KeyCode.KeypadOne.Value

UserInputService.InputBegan:Connect(function(input: InputObject, gameProcessed: boolean)
	-- gameProcessed is true when a CoreScript or a focused text box already took the key.
	-- Honouring it is what stops the hotbar firing while the player is typing in chat.
	if gameProcessed or input.UserInputType ~= Enum.UserInputType.Keyboard then
		return
	end
	-- The menu key is checked BEFORE the open-menu guard, or B could open the inventory and
	-- then be unable to close it again.
	if input.KeyCode == Enum.KeyCode.B or input.KeyCode == Enum.KeyCode.I then
		openOnly(inventory)
		return
	end
	if input.KeyCode == Enum.KeyCode.M then
		openOnly(market)
		return
	end
	if input.KeyCode == Enum.KeyCode.K then
		openOnly(workshop)
		return
	end
	if input.KeyCode == Enum.KeyCode.J then
		duel:Toggle()
		return
	end
	if input.KeyCode == Enum.KeyCode.P then
		openOnly(profile)
		return
	end
	if input.KeyCode == Enum.KeyCode.V then
		toggleRange()
		return
	end
	if input.KeyCode == Enum.KeyCode.N then
		openOnly(daily)
		return
	end
	if input.KeyCode == Enum.KeyCode.O then
		openOnly(journal)
		return
	end
	if input.KeyCode == Enum.KeyCode.F1 then
		openOnly(settings)
		return
	end
	if input.KeyCode == Enum.KeyCode.L then
		openOnly(contracts)
		return
	end
	if input.KeyCode == Enum.KeyCode.Y then
		openOnly(road)
		return
	end
	if input.KeyCode == Enum.KeyCode.T then
		openOnly(travel)
		return
	end
	if input.KeyCode == Enum.KeyCode.H then
		openOnly(achievements)
		return
	end

	-- Slot keys are gameplay, so they stop at the edge of a menu.
	if player:GetAttribute("UIOpen") == true then
		return
	end

	local value = input.KeyCode.Value
	local slot: number? = nil
	if value >= ROW_ONE and value <= ROW_ONE + 8 then
		slot = value - ROW_ONE + 1
	elseif value >= PAD_ONE and value <= PAD_ONE + 8 then
		slot = value - PAD_ONE + 1
	end
	if slot then
		equipSlot(slot)
	end
end)

-- ------------------------------------------------------------ menu state --

-- UIState counts open panels onto this attribute. The HUD steps out of the way rather than
-- showing through a panel -- and because it reads the shared flag, it cannot disagree with
-- ShiftLock about whether a menu is open.
local function refreshMenuState()
	local clear = player:GetAttribute("UIOpen") ~= true
	-- Looking through a scope: the lens gets the middle of the screen to itself.
	local scoped = player:GetAttribute("Scoped") == true
	hud:SetVisible(clear)
	hotbar:SetVisible(clear)
	killFeed:SetVisible(clear)
	nav:SetVisible(clear and not scoped)
	duel:SetPlayAllowed(not scoped and not dead)
	objective:SetVisible(clear)
	duel:SetVisible(clear)
	bossBar:SetVisible(clear)
	toast:SetVisible(clear)
	bounties:SetVisible(clear)
end
refreshMenuState()
player:GetAttributeChangedSignal("UIOpen"):Connect(refreshMenuState)

-- The title screen's "1V1 DUEL" shortcut: into the queue the moment the game is on screen.
player:GetAttributeChangedSignal("TitleAction"):Connect(function()
	if player:GetAttribute("TitleAction") == "duel" then
		player:SetAttribute("TitleAction", nil)
		duel:Toggle()
	end
end)
player:GetAttributeChangedSignal("Scoped"):Connect(refreshMenuState)
