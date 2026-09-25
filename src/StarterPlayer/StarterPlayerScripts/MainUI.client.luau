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
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))

local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- The old custom hotbar turned the Roblox backpack off and the new one replaces it, so this
-- has to move with it -- otherwise deleting that script quietly hands the default backpack
-- back and the player ends up with two hotbars.
task.spawn(function()
	for _ = 1, 10 do
		local ok = pcall(function()
			StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
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

local hud = Hud.new(screen)
local feedback = Feedback.new(playerGui)
local killFeed = KillFeed.new(screen)
local objective = Objective.new(screen)

local matchRemotes = ReplicatedStorage:WaitForChild("Remotes")
local rangeAction = matchRemotes:WaitForChild("RangeAction") :: RemoteFunction

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
local duel = Duel.new(screen, {
	matchAction = matchRemotes:WaitForChild("MatchAction") :: RemoteFunction,
	matchUpdate = matchRemotes:WaitForChild("MatchUpdate") :: RemoteEvent,
})

-- --------------------------------------------------------------- objective --

-- QuestService already broadcasts the whole state on every change, so the card just redraws
-- from it. Rewards are read out of QuestConfig here because the active-quest block in that
-- payload carries only progress, not what it pays.
task.spawn(function()
	local gameRemotesFolder = ReplicatedStorage:WaitForChild("GameRemotes", 30)
	local questUpdated = gameRemotesFolder and gameRemotesFolder:WaitForChild("QuestUpdated", 30)
	if not questUpdated or not questUpdated:IsA("RemoteEvent") then
		return
	end

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

	questUpdated.OnClientEvent:Connect(function(state)
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
local hotbar = Hotbar.new(hud.dock, equipSlot)

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
	local stats = player:WaitForChild("leaderstats", 30)
	local coins = stats and stats:WaitForChild("Coins", 30)
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
task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("GameRemotes", 30)
	local reward = remotes and remotes:WaitForChild("ProgressionReward", 30)
	if not reward or not reward:IsA("RemoteEvent") then
		return
	end
	reward.OnClientEvent:Connect(function(kind: unknown, a: unknown, b: unknown, c: unknown, d: unknown)
		if kind == "Milestone" then
			local level = tonumber(a) or 0
			local earned = type(b) == "table" and table.concat(b, ", ") or ""
			local note = type(c) == "string" and c or nil
			killFeed:Notice(("LEVEL %d"):format(level), note or earned)
		elseif kind == "Mastery" then
			local weapon = tostring(a)
			local tier = tostring(b)
			local earned = type(c) == "table" and #c > 0 and ("  -  " .. table.concat(c, ", ")) or ""
			killFeed:Notice("MASTERY", ("%s %s%s"):format(weapon, string.upper(tier), earned))
		end
	end)
end)

task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("GameRemotes", 30)
	local xpGained = remotes and remotes:WaitForChild("XPGained", 30)
	if not xpGained or not xpGained:IsA("RemoteEvent") then
		return
	end
	-- The first message is the loaded profile, not a gain; only a rise after that is a
	-- level-up worth celebrating.
	local lastLevel: number? = nil
	xpGained.OnClientEvent:Connect(function(_amount: number, exp: number, maxExp: number, level: number)
		local now = math.floor(tonumber(level) or 1)
		hud:SetLevel(now, exp, maxExp)
		if lastLevel ~= nil and now > lastLevel then
			feedback:LevelUp(now)
		end
		lastLevel = now
	end)
end)

-- ----------------------------------------------------------------- vitals --

-- One table of connections per character. Respawning clears it before rebinding, which is the
-- difference between a HUD that stays correct and one that slowly accumulates dead listeners.
local characterConnections: { RBXScriptConnection } = {}

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
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
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

task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
	local gunEffect = remotes and remotes:WaitForChild("GunEffect", 30)
	if gunEffect and gunEffect:IsA("RemoteEvent") then
		gunEffect.OnClientEvent:Connect(function(kind: unknown, shooter: unknown, _tool: unknown, origin: unknown, endPoints: unknown)
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
	end

	local npcEffect = remotes and remotes:WaitForChild("NPCEffect", 30)
	if npcEffect and npcEffect:IsA("RemoteEvent") then
		npcEffect.OnClientEvent:Connect(function(batch: unknown)
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
end)

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

local gameRemotes = ReplicatedStorage:WaitForChild("GameRemotes")
local inventory = Inventory.new(menuLayer, {
	getOwnership = gameRemotes:WaitForChild("GetOwnership") :: RemoteFunction,
	loadoutAction = gameRemotes:WaitForChild("LoadoutAction") :: RemoteFunction,
})

local market = Market.new(menuLayer, {
	getOwnership = gameRemotes:WaitForChild("GetOwnership") :: RemoteFunction,
	PurchaseItem = gameRemotes:WaitForChild("PurchaseItem") :: RemoteFunction,
	PurchaseCamo = gameRemotes:WaitForChild("PurchaseCamo") :: RemoteFunction,
	PurchaseAttachment = gameRemotes:WaitForChild("PurchaseAttachment") :: RemoteFunction,
	PurchaseCosmetic = gameRemotes:WaitForChild("PurchaseCosmetic") :: RemoteFunction,
	ownershipChanged = gameRemotes:WaitForChild("OwnershipChanged") :: RemoteEvent,
	promptPurchase = gameRemotes:WaitForChild("PromptPurchase") :: RemoteEvent,
})

local profile = Profile.new(menuLayer, {
	profileRequest = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ProfileRequest") :: RemoteFunction,
})

local daily = Daily.new(menuLayer, {
	dailyAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DailyAction") :: RemoteFunction,
})

local workshop = Workshop.new(menuLayer, {
	getOwnership = gameRemotes:WaitForChild("GetOwnership") :: RemoteFunction,
	buildAction = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("BuildAction") :: RemoteFunction,
})

-- Forward-declared: the nav is built below, but opening a menu by hotkey should still retire
-- that menu's first-time hint on the nav.
local nav: any

local NAV_ID = {
	[inventory] = "Inventory", [market] = "Market", [workshop] = "Workshop",
	[profile] = "Profile", [daily] = "Daily",
}

-- Opening one panel closes the others. Two full-screen menus stacked on each other is how a
-- player loses track of what Escape is going to do.
local function openOnly(target)
	for _, panel in ipairs({ inventory, market, workshop, profile, daily }) do
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
workshop:OnShop(function()
	openOnly(market)
end)

-- The vendor NPC asks for the market by name, so walking up to the stall still opens it.
task.spawn(function()
	local openVendor = gameRemotes:WaitForChild("OpenVendor", 30)
	if openVendor and openVendor:IsA("RemoteEvent") then
		openVendor.OnClientEvent:Connect(function()
			inventory:Close()
			market:Toggle()
		end)
	end
end)

-- Hints are the first-session teaching: the three things a new player should find first.
nav = Nav.new(screen, {
	{ id = "Inventory", label = "Items", key = "[B]", onActivated = function()
		openOnly(inventory)
	end },
	{ id = "Market", label = "Shop", key = "[M]", hint = "Unlock New Guns!", onActivated = function()
		openOnly(market)
	end },
	{ id = "Workshop", label = "Armory", key = "[K]", onActivated = function()
		openOnly(workshop)
	end },
	-- Not a menu: this one acts immediately rather than opening a panel, so it does not go
	-- through openOnly.
	{ id = "Duel", label = "1v1", key = "[J]", hint = "Queue A 1v1 Duel!", onActivated = function()
		duel:Toggle()
	end },
	{ id = "Profile", label = "Profile", key = "[P]", onActivated = function()
		openOnly(profile)
	end },
	{ id = "Range", label = "Range", key = "[V]", onActivated = toggleRange },
	{ id = "Daily", label = "Daily", key = "[N]", hint = "Free Daily Reward!", onActivated = function()
		openOnly(daily)
	end },
})

-- --------------------------------------------------------------- feed --

task.spawn(function()
	local remotes = ReplicatedStorage:WaitForChild("Remotes", 30)
	local feed = remotes and remotes:WaitForChild("KillFeed", 30)
	if not feed or not feed:IsA("RemoteEvent") then
		return
	end
	feed.OnClientEvent:Connect(function(victimName: unknown, weaponName: unknown)
		if type(victimName) ~= "string" then
			return
		end
		killFeed:Push(victimName, type(weaponName) == "string" and weaponName or nil)
		killFeed:Eliminated(victimName)
	end)
end)

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
		nav:DismissHint("Duel")
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
	hud:SetVisible(clear)
	hotbar:SetVisible(clear)
	killFeed:SetVisible(clear)
	nav:SetVisible(clear)
	objective:SetVisible(clear)
	duel:SetVisible(clear)
end
refreshMenuState()
player:GetAttributeChangedSignal("UIOpen"):Connect(refreshMenuState)
