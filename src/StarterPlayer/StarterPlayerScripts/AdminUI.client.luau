--!strict
-- The owner panel (F4, or the ADMIN button top-left).
--
-- This builds nothing unless the SERVER says you are the owner, and even then the panel is
-- only a convenience: every button goes through AdminCommand, which re-checks ownership
-- before acting. Hiding the UI is not the security.
--
-- Built in the same shell as every other menu (UI.Modules.Menu), with a strip across the top
-- that always shows who you are acting on and their numbers AS THE SERVER HAS THEM -- level,
-- prestige, coins, crystals, kills -- re-read after every command, so a change you make is
-- one you can see land. The boxes are filled with those current values and keep whatever
-- you type in them; and the strip says plainly whether the profile is really being saved
-- (in Studio without API access nothing is, and every change is gone at the end of the test).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
local NPCConfig = require(ReplicatedStorage:WaitForChild("NPCConfig"))

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local AdminCheck = remotes:WaitForChild("AdminCheck") :: RemoteFunction
local AdminCommand = remotes:WaitForChild("AdminCommand") :: RemoteFunction

-- Ask the server. If it says no, this script does nothing at all.
local allowed = false
do
	local ok, result = pcall(function()
		return AdminCheck:InvokeServer()
	end)
	allowed = ok and result == true
end
if not allowed then
	return
end

local Modules = ReplicatedStorage:WaitForChild("UI"):WaitForChild("Modules")
local Theme = require(Modules:WaitForChild("Theme")) :: any
local Components = require(Modules:WaitForChild("Components")) :: any
local Menu = require(Modules:WaitForChild("Menu")) :: any

local gui = Instance.new("ScreenGui")
gui.Name = "AdminUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 40
gui.Parent = player:WaitForChild("PlayerGui")
Components.BindScale(gui)

local CATEGORIES = {
	{ id = "Progress", label = "Progress", icon = "📈" },
	{ id = "Weapons", label = "Weapons", icon = "🔫" },
	{ id = "NPCs", label = "NPCs", icon = "👾" },
	{ id = "Move", label = "Move", icon = "🧭" },
	{ id = "Self", label = "Self", icon = "🛡" },
	{ id = "World", label = "World", icon = "🌦" },
	{ id = "Data", label = "Data", icon = "📊" },
}

local menu = Menu.new(gui, {
	id = "Admin",
	title = "Owner Panel",
	subtitle = "Changes are made on the server and saved to the profile straight away",
	icon = "👑",
	size = UDim2.fromOffset(1020, 640),
	categories = CATEGORIES,
})

local WHITE = Color3.new(1, 1, 1)

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function card(parent: Instance, name: string, size: UDim2, colour: Color3?): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = colour or Theme.Colour.PanelRaised
	f.BorderSizePixel = 0
	f.Size = size
	f.Parent = parent
	Components.Corner(f, 12)
	Components.Stroke(f, Theme.Colour.Outline, 2)
	Components.Gradient(f)
	return f
end

-- ------------------------------------------------------------ the strip --

local content = menu.content
local strip = card(content, "Target", UDim2.new(1, 0, 0, 92))

-- Who the buttons act on: you, or anyone else here.
local targetName = player.Name
local knownPlayers: { string } = { player.Name }

local targetLabel = Components.Label(strip, { text = "ACTING ON", font = Theme.Font.Bold, size = 12,
	colour = Theme.Colour.TextDim })
targetLabel.Position = UDim2.fromOffset(14, 8)
targetLabel.Size = UDim2.fromOffset(200, 16)

local prevTarget = Components.Button(strip, { name = "PrevTarget", text = "◀", textSize = 18,
	size = UDim2.fromOffset(34, 34), position = UDim2.fromOffset(12, 30) })
local targetText = Components.Label(strip, { text = player.Name, face = Theme.Face.HeavyItalic, size = 22,
	outline = 2, align = Enum.TextXAlignment.Center })
targetText.Name = "TargetName"
targetText.Position = UDim2.fromOffset(50, 30)
targetText.Size = UDim2.fromOffset(160, 34)
targetText.TextTruncate = Enum.TextTruncate.AtEnd
local nextTarget = Components.Button(strip, { name = "NextTarget", text = "▶", textSize = 18,
	size = UDim2.fromOffset(34, 34), position = UDim2.fromOffset(214, 30) })

local saving = Components.Label(strip, { text = "● CHECKING SAVES...", font = Theme.Font.Bold, size = 12,
	colour = Theme.Colour.TextDim })
saving.Name = "Saving"
saving.Position = UDim2.fromOffset(14, 68)
saving.Size = UDim2.fromOffset(240, 16)

-- The numbers.
local statsRow = Instance.new("Frame")
statsRow.Name = "Stats"
statsRow.BackgroundTransparency = 1
statsRow.Position = UDim2.fromOffset(264, 8)
statsRow.Size = UDim2.new(1, -276, 1, -16)
statsRow.Parent = strip
Components.List(statsRow, Enum.FillDirection.Horizontal, 8)

local statValues: { [string]: TextLabel } = {}
local function statPill(id: string, label: string, colour: Color3, order: number, width: number)
	local pill = card(statsRow, id, UDim2.fromOffset(width, 76), Theme.Colour.Sunken)
	pill.LayoutOrder = order
	local top = Components.Label(pill, { text = label, font = Theme.Font.Bold, size = 12, colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center })
	top.Position = UDim2.fromOffset(0, 6)
	top.Size = UDim2.new(1, 0, 0, 16)
	local value = Components.Label(pill, { text = "-", face = Theme.Face.HeavyItalic, size = 26, colour = colour,
		outline = 2.2, align = Enum.TextXAlignment.Center })
	value.Name = "Value"
	value.Position = UDim2.fromOffset(4, 26)
	value.Size = UDim2.new(1, -8, 0, 34)
	value.TextScaled = true
	statValues[id] = value
	return pill
end

local levelPill = statPill("Level", "LEVEL", Theme.Colour.Level, 1, 106)
statPill("Prestige", "PRESTIGE", WHITE, 2, 116)
statPill("Coins", "COINS", Theme.Colour.Currency, 3, 136)
statPill("Crystals", "CRYSTALS", Color3.fromRGB(150, 210, 255), 4, 104)
statPill("Kills", "KILLS", Theme.Colour.Kill, 5, 94)

-- The emblem, for prestige.
local okBadge, PrestigeBadge = pcall(function()
	return require(ReplicatedStorage:WaitForChild("PrestigeBadge", 5) :: ModuleScript) :: any
end)
local emblem = nil
if okBadge and PrestigeBadge then
	local holder = statsRow:FindFirstChild("Prestige") :: Frame
	emblem = PrestigeBadge.Create(holder, 30)
	emblem.root.AnchorPoint = Vector2.new(0, 0.5)
	emblem.root.Position = UDim2.new(0, 6, 0, 43)
	local value = statValues.Prestige
	value.Position = UDim2.fromOffset(34, 26)
	value.Size = UDim2.new(1, -40, 0, 34)
end
levelPill.LayoutOrder = 1

-- ----------------------------------------------------------- the body --

local body = Instance.new("ScrollingFrame")
body.Name = "Body"
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.Position = UDim2.fromOffset(0, 104)
body.Size = UDim2.new(1, 0, 1, -104 - 40)
body.CanvasSize = UDim2.new()
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.ScrollBarThickness = 6
body.ScrollBarImageColor3 = Theme.Colour.Stroke
body.Parent = content
Components.List(body, Enum.FillDirection.Vertical, 10)
Components.Padding(body, nil, 0, 2)

local status = Components.Label(content, { text = "Ready.", font = Theme.Font.Bold, size = 16,
	colour = Theme.Colour.TextDim, align = Enum.TextXAlignment.Center })
status.Name = "Status"
status.AnchorPoint = Vector2.new(0, 1)
status.Position = UDim2.new(0, 0, 1, 0)
status.Size = UDim2.new(1, 0, 0, 30)
status.TextWrapped = true

-- ------------------------------------------------------------- commands --

local refreshState: () -> ()

local function say(result: any)
	if typeof(result) ~= "table" then
		status.Text = "No response from the server"
		status.TextColor3 = Theme.Colour.Danger
		return
	end
	status.Text = tostring(result.reason or (result.ok and "Done" or "Failed"))
	status.TextColor3 = result.ok and Theme.Colour.Accent or Theme.Colour.Danger
end

local function run(name: string, args: { [string]: any }?, after: ((any) -> ())?)
	local payload = table.clone(args or {})
	if targetName ~= player.Name then
		payload.target = targetName
	end
	status.Text = "..."
	status.TextColor3 = Theme.Colour.TextDim
	task.spawn(function()
		local ok, result = pcall(function()
			return AdminCommand:InvokeServer(name, payload)
		end)
		local answer = ok and result or { ok = false, reason = "Request failed" }
		say(answer)
		if after then
			after(answer)
		end
		refreshState()
	end)
end

-- ---------------------------------------------------------- page parts --

type Field = { box: TextBox, dirty: boolean, key: string? }
local fields: { Field } = {}
local pages: { [string]: { GuiObject } } = {}
local currentPage = "Progress"
local order = 0

local function place(page: string, item: GuiObject)
	order += 1
	item.LayoutOrder = order
	item.Visible = page == currentPage
	pages[page] = pages[page] or {}
	table.insert(pages[page], item)
end

local function heading(page: string, text: string)
	local label = Components.Label(body, { text = text, face = Theme.Face.HeavyItalic, size = 20,
		colour = Theme.Colour.Level, outline = 2 })
	label.Size = UDim2.new(1, 0, 0, 24)
	place(page, label)
end

--- A row: what it is, a box holding the value, a SET button, and quick buttons beside it.
--- `key` names the live value the box shows until you type in it.
local function valueRow(page: string, spec: { title: string, hint: string, command: string, key: string?,
	placeholder: string?, default: string?, quick: { { label: string, command: string, value: any, danger: boolean? } }? })
	local row = card(body, spec.command, UDim2.new(1, -8, 0, 64))
	place(page, row)

	local title = Components.Label(row, { text = spec.title, face = Theme.Face.Condensed, size = 20, outline = 2 })
	title.Position = UDim2.fromOffset(14, 6)
	title.Size = UDim2.fromOffset(200, 24)
	local hint = Components.Label(row, { text = spec.hint, font = Theme.Font.Medium, size = 12,
		colour = Theme.Colour.TextMuted })
	hint.Position = UDim2.fromOffset(14, 34)
	hint.Size = UDim2.fromOffset(200, 18)
	hint.TextTruncate = Enum.TextTruncate.AtEnd

	local box = Instance.new("TextBox")
	box.Name = "Input"
	box.BackgroundColor3 = Theme.Colour.Sunken
	box.BorderSizePixel = 0
	box.Position = UDim2.fromOffset(222, 12)
	box.Size = UDim2.fromOffset(170, 40)
	box.Font = Theme.Font.Bold
	box.TextSize = 20
	box.TextColor3 = WHITE
	box.PlaceholderText = spec.placeholder or ""
	box.PlaceholderColor3 = Theme.Colour.TextMuted
	box.Text = spec.default or ""
	box.ClearTextOnFocus = false
	box.Parent = row
	Components.Corner(box, 10)
	Components.Stroke(box, Theme.Colour.Stroke, 2)

	local field: Field = { box = box, dirty = false, key = spec.key }
	table.insert(fields, field)
	box.Focused:Connect(function()
		field.dirty = true
	end)

	Components.Button(row, {
		name = "Set",
		text = "SET",
		textSize = 18,
		primary = true,
		size = UDim2.fromOffset(78, 40),
		position = UDim2.fromOffset(400, 12),
		onActivated = function()
			local value = box.Text
			run(spec.command, { value = value }, function(result)
				if type(result) == "table" and result.ok then
					field.dirty = false
				end
			end)
		end,
	})

	local x = 490
	for _, q in ipairs(spec.quick or {}) do
		local width = math.max(58, #q.label * 11 + 20)
		Components.Button(row, {
			name = q.command .. "_" .. tostring(q.value),
			text = q.label,
			textSize = 16,
			danger = q.danger,
			size = UDim2.fromOffset(width, 40),
			position = UDim2.fromOffset(x, 12),
			onActivated = function()
				field.dirty = false
				run(q.command, { value = q.value })
			end,
		})
		x += width + 6
	end
	return box
end

--- A grid of one-press buttons.
local function grid(page: string, buttons: { { label: string, command: string, value: any?, danger: boolean? } }, name: string?)
	local holder = Instance.new("Frame")
	holder.Name = name or "Grid"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, -8, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.Parent = body
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = UDim2.fromOffset(202, 44)
	layout.CellPadding = UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = holder
	for i, b in ipairs(buttons) do
		local button = Components.Button(holder, {
			name = b.command .. (b.value ~= nil and ("_" .. tostring(b.value)) or ""),
			text = b.label,
			textSize = 15,
			danger = b.danger,
			layoutOrder = i,
			onActivated = function()
				run(b.command, { value = b.value })
			end,
		})
		button.instance.TextTruncate = Enum.TextTruncate.AtEnd
	end
	place(page, holder)
	return holder
end

-- ------------------------------------------------------------- progress --

heading("Progress", "LEVEL & PRESTIGE")
valueRow("Progress", {
	title = "LEVEL", hint = "1 to the cap; the bar starts empty", command = "SetLevel", key = "level",
	placeholder = "level",
	quick = {
		{ label = "-1", command = "AddLevels", value = -1 },
		{ label = "+1", command = "AddLevels", value = 1 },
		{ label = "+5", command = "AddLevels", value = 5 },
		{ label = "MAX", command = "SetLevel", value = 999 },
	},
})
valueRow("Progress", {
	title = "PRESTIGE", hint = "Sets the rank only; no level reset", command = "SetPrestige", key = "prestige",
	placeholder = "0 - 10",
})
do
	-- The real thing, level reset and all. Asks twice when it is aimed at you.
	local row = card(body, "RealPrestige", UDim2.new(1, -8, 0, 64))
	place("Progress", row)
	local title = Components.Label(row, { text = "RUN A REAL PRESTIGE", face = Theme.Face.Condensed, size = 20, outline = 2 })
	title.Position = UDim2.fromOffset(14, 6)
	title.Size = UDim2.fromOffset(420, 24)
	local hint = Components.Label(row, { text = "The genuine flow: needs max level, resets the level, pays the rewards",
		font = Theme.Font.Medium, size = 12, colour = Theme.Colour.TextMuted })
	hint.Position = UDim2.fromOffset(14, 34)
	hint.Size = UDim2.fromOffset(460, 18)
	local armed = false
	local button
	button = Components.Button(row, {
		name = "DoPrestige",
		text = "PRESTIGE",
		textSize = 18,
		danger = true,
		size = UDim2.fromOffset(250, 40),
		position = UDim2.fromOffset(490, 12),
		onActivated = function()
			if not armed and targetName == player.Name then
				armed = true
				button:SetText("PRESS AGAIN TO RESET")
				task.delay(4, function()
					armed = false
					button:SetText("PRESTIGE")
				end)
				return
			end
			armed = false
			button:SetText("PRESTIGE")
			run("DoPrestige", { confirm = true })
		end,
	})
end

heading("Progress", "CURRENCY & STATS")
valueRow("Progress", {
	title = "COINS", hint = "Saved on the profile", command = "SetCoins", key = "coins", placeholder = "amount",
	quick = {
		{ label = "+1K", command = "AddCoins", value = 1000 },
		{ label = "+10K", command = "AddCoins", value = 10000 },
		{ label = "+100K", command = "AddCoins", value = 100000 },
		{ label = "-1K", command = "AddCoins", value = -1000, danger = true },
	},
})
valueRow("Progress", {
	title = "CRYSTALS", hint = "Spent at the Quartermaster", command = "SetCrystals", key = "crystals",
	placeholder = "amount",
})
valueRow("Progress", {
	title = "KILLS", hint = "The leaderboard count", command = "SetKills", key = "kills", placeholder = "amount",
})

-- -------------------------------------------------------------- weapons --

heading("Weapons", "OWNERSHIP")
grid("Weapons", { { label = "UNLOCK EVERY WEAPON", command = "UnlockAllWeapons" } }, "Unlock")
heading("Weapons", "GIVE ONE (OWNED FOR GOOD, EQUIPPED NOW)")
do
	local names = {}
	for name in pairs(WeaponConfig.Weapons) do
		table.insert(names, name)
	end
	table.sort(names)
	local buttons = {}
	for _, name in ipairs(names) do
		table.insert(buttons, { label = name, command = "GiveWeapon", value = name })
	end
	grid("Weapons", buttons, "Give")
end

-- ----------------------------------------------------------------- NPCs --

heading("NPCs", "SPAWN IN FRONT OF YOU")
do
	local archetypes = {}
	for name in pairs(NPCConfig.Archetypes) do
		table.insert(archetypes, name)
	end
	table.sort(archetypes)
	local buttons = {}
	for _, name in ipairs(archetypes) do
		table.insert(buttons, { label = name, command = "SpawnNPC", value = name })
	end
	grid("NPCs", buttons, "Spawn")
end
heading("NPCs", "BOSSES & CLEAN-UP")
grid("NPCs", {
	{ label = "Flats Warlord", command = "SpawnBoss", value = "Flats" },
	{ label = "Reach Warlord", command = "SpawnBoss", value = "Reach" },
	{ label = "Kill all NPCs", command = "ClearNPCs", danger = true },
	{ label = "Clear dropped weapons", command = "ClearDrops", danger = true },
}, "Bosses")

-- ----------------------------------------------------------------- move --

heading("Move", "TO A PLAYER")
valueRow("Move", { title = "PLAYER", hint = "Start of their name", command = "Teleport", placeholder = "name" })
heading("Move", "WAYPOINTS")
local waypointGrid = grid("Move", {}, "Waypoints")
task.spawn(function()
	local ok, result = pcall(function()
		return AdminCommand:InvokeServer("Waypoints", {})
	end)
	if not ok or type(result) ~= "table" or type(result.waypoints) ~= "table" then
		return
	end
	for i, entry in ipairs(result.waypoints) do
		local button = Components.Button(waypointGrid, {
			name = "Teleport_" .. tostring(entry.id),
			text = tostring(entry.name),
			textSize = 15,
			layoutOrder = i,
			onActivated = function()
				run("Teleport", { value = entry.id })
			end,
		})
		button.instance.TextTruncate = Enum.TextTruncate.AtEnd
	end
end)

-- ----------------------------------------------------------------- self --

heading("Self", "SURVIVAL")
grid("Self", {
	{ label = "Toggle godmode", command = "Godmode" },
	{ label = "Heal to full", command = "Heal" },
}, "Survival")
valueRow("Self", { title = "WALK SPEED", hint = "Studs a second (16 is normal)", command = "Speed", placeholder = "16",
	default = "16",
	quick = { { label = "16", command = "Speed", value = 16 }, { label = "40", command = "Speed", value = 40 } } })

-- ---------------------------------------------------------------- world --

heading("World", "WEATHER")
grid("World", {
	{ label = "Clear", command = "Weather", value = "Clear" },
	{ label = "Overcast", command = "Weather", value = "Overcast" },
	{ label = "Fog", command = "Weather", value = "Fog" },
	{ label = "Rain", command = "Weather", value = "Rain" },
}, "Weather")
heading("World", "TIME")
valueRow("World", { title = "HOUR", hint = "0 - 24; pauses the clock", command = "TimeOfDay", placeholder = "12",
	default = "12", quick = { { label = "RESUME CLOCK", command = "ResumeTime", value = nil } } })

-- ----------------------------------------------------------------- data --

heading("Data", "SERVER")
grid("Data", { { label = "Diagnostics", command = "Diagnostics" } }, "Diagnostics")

-- --------------------------------------------------------------- state --

local busyState = false
function refreshState()
	if busyState then
		return
	end
	busyState = true
	task.spawn(function()
		local ok, state = pcall(function()
			return AdminCommand:InvokeServer("State", { target = targetName ~= player.Name and targetName or nil })
		end)
		busyState = false
		if not ok or type(state) ~= "table" or not state.ok then
			return
		end
		if type(state.players) == "table" then
			knownPlayers = state.players
		end
		targetText.Text = tostring(state.target or targetName)
		statValues.Level.Text = string.format("%d / %d", state.level or 1, state.maxLevel or 50)
		statValues.Prestige.Text = tostring(state.prestige or 0)
		statValues.Coins.Text = commas(tonumber(state.coins) or 0)
		statValues.Crystals.Text = commas(tonumber(state.crystals) or 0)
		statValues.Kills.Text = commas(tonumber(state.kills) or 0)
		if emblem then
			emblem:SetLevel(state.level or 1)
			emblem:SetPrestige(state.prestige or 0)
		end
		if state.saving then
			saving.Text = "● SAVING TO THE PROFILE"
			saving.TextColor3 = Theme.Colour.Accent
		else
			saving.Text = "● NOT SAVING (STUDIO API OFF)"
			saving.TextColor3 = Theme.Colour.Danger
		end
		-- The boxes show the live numbers, unless you are in the middle of typing one.
		for _, field in ipairs(fields) do
			if field.key and not field.dirty and not field.box:IsFocused() then
				local value = state[field.key]
				if value ~= nil then
					field.box.Text = tostring(value)
				end
			end
		end
	end)
end

local function cycleTarget(step: number)
	local index = table.find(knownPlayers, targetName) or 1
	index = (index - 1 + step) % math.max(1, #knownPlayers) + 1
	targetName = knownPlayers[index] or player.Name
	targetText.Text = targetName
	for _, field in ipairs(fields) do
		field.dirty = false
	end
	refreshState()
end
prevTarget.instance.Activated:Connect(function()
	cycleTarget(-1)
end)
nextTarget.instance.Activated:Connect(function()
	cycleTarget(1)
end)

-- ---------------------------------------------------------------- pages --

menu:OnCategory(function(id: string)
	currentPage = id
	for page, items in pairs(pages) do
		for _, item in ipairs(items) do
			item.Visible = page == id
		end
	end
	body.CanvasPosition = Vector2.zero
end)
menu:OnOpen(function()
	menu:SelectCategory(currentPage)
	refreshState()
end)

-- ---------------------------------------------------------------- open --

-- F4 is free and out of the way of the other menus.
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F4 and not UserInputService:GetFocusedTextBox() then
		menu:Toggle()
	end
end)

Components.Button(gui, {
	name = "OpenAdmin",
	text = "👑 ADMIN  [F4]",
	textSize = 14,
	size = UDim2.fromOffset(128, 34),
	position = UDim2.fromOffset(16, 16),
	colour = Color3.fromRGB(150, 44, 52),
	onActivated = function()
		menu:Toggle()
	end,
})

-- Keep the strip honest while it is open: anything else that moves these numbers (a kill,
-- a purchase) shows up without pressing anything.
task.spawn(function()
	while gui.Parent do
		task.wait(3)
		if menu:IsOpen() then
			refreshState()
		end
	end
end)
