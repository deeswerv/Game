--!strict
-- Owner-only admin panel.
--
-- This builds nothing unless the SERVER says you are the owner, and even then the
-- panel is only a convenience: every button goes through AdminCommand, which
-- re-checks ownership before acting. Hiding the UI is not the security.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(ReplicatedStorage.UIKit)
local WeaponConfig = require(ReplicatedStorage.WeaponConfig)
local NPCConfig = require(ReplicatedStorage.NPCConfig)
local UIState = require(game:GetService("ReplicatedStorage"):WaitForChild("UIState"))
local Theme = UIKit.Theme

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

local gui = Instance.new("ScreenGui")
gui.Name = "AdminUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 40
gui.Parent = player:WaitForChild("PlayerGui")

local isOpen = false

local panel = UIKit.frame({
	Name = "Panel",
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 16, 0, 54),
	Size = UDim2.fromOffset(330, 520),
	BackgroundColor3 = Theme.Background,
	Visible = false,
	Parent = gui,
})
UIKit.corner(panel, UDim.new(0, 12))
UIKit.stroke(panel, Color3.fromRGB(196, 64, 64), 1, 0.2)

local header = UIKit.frame({
	Name = "Header",
	Size = UDim2.new(1, 0, 0, 46),
	BackgroundColor3 = Theme.Panel,
	Parent = panel,
})
UIKit.corner(header, UDim.new(0, 12))

UIKit.label({
	Position = UDim2.fromOffset(16, 0),
	Size = UDim2.new(1, -60, 1, 0),
	Text = "ADMIN  ·  owner only",
	Font = Theme.FontBold,
	TextColor3 = Color3.fromRGB(226, 110, 110),
	TextSize = 15,
	Parent = header,
})

local closeBtn = UIKit.button({
	Name = "Close",
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -12, 0.5, 0),
	Size = UDim2.fromOffset(28, 28),
	Text = "X",
	TextSize = 14,
	Parent = header,
})
UIKit.corner(closeBtn, UDim.new(0, 6))
UIKit.hover(closeBtn, Theme.PanelLight, Theme.Danger)

-- A rail of categories across the top, one chip per section, and only the chosen section's
-- rows below it. Borrowed from the admin suite this replaced: its one genuinely good idea was
-- that a long command list is unusable until it is split into pages you can aim at.
local rail = UIKit.frame({
	Name = "Rail",
	Position = UDim2.fromOffset(10, 52),
	Size = UDim2.new(1, -20, 0, 58),
	BackgroundTransparency = 1,
	Parent = panel,
})

local railLayout = Instance.new("UIListLayout")
railLayout.FillDirection = Enum.FillDirection.Horizontal
-- Wrapped onto a second line rather than scrolled sideways: a category you cannot see is a
-- category you will not use, and there are eight of them in a 330-wide panel.
railLayout.Wraps = true
railLayout.Padding = UDim.new(0, 4)
railLayout.SortOrder = Enum.SortOrder.LayoutOrder
railLayout.Parent = rail

local body = Instance.new("ScrollingFrame")
body.Name = "Body"
body.Position = UDim2.fromOffset(10, 116)
body.Size = UDim2.new(1, -20, 1, -162)
body.BackgroundTransparency = 1
body.BorderSizePixel = 0
body.ScrollBarThickness = 4
body.ScrollBarImageColor3 = Theme.AccentDim
body.CanvasSize = UDim2.new()
body.AutomaticCanvasSize = Enum.AutomaticSize.Y
body.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 6)
-- Without this the layout defaults to sorting by NAME, which threw every section heading
-- to the bottom of the panel and left the buttons in one undifferentiated block -- the
-- LayoutOrder each row already sets was being ignored entirely.
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Parent = body

local status = UIKit.label({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -10),
	Size = UDim2.new(1, -20, 0, 32),
	Text = "",
	TextSize = 12,
	TextColor3 = Theme.TextDim,
	TextWrapped = true,
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = panel,
})

local function say(result)
	if typeof(result) ~= "table" then
		status.Text = "No response"
		status.TextColor3 = Theme.Danger
		return
	end
	status.Text = tostring(result.reason)
	status.TextColor3 = result.ok and Theme.Success or Theme.Danger
end

local function run(name, args)
	task.spawn(function()
		local ok, result = pcall(function()
			return AdminCommand:InvokeServer(name, args or {})
		end)
		say(ok and result or { ok = false, reason = "Request failed" })
	end)
end

-- ----------------------------------------------------------------- sections --
--
-- Every row belongs to the section that was opened last, and only the chosen section is
-- visible. Rows created later -- the waypoint buttons arrive from the server a moment after
-- the panel is built -- pass their section explicitly, so they land on the right page.

local order = 0
local sections: { { name: string, items: { Instance }, chip: TextButton } } = {}
local current
local showSection

local function register(inst: Instance, section)
	section = section or current
	if section then
		table.insert(section.items, inst)
		inst.Visible = section.chosen == true
	end
	return inst
end

local function heading(text)
	local section = { name = text, items = {}, chosen = false }
	table.insert(sections, section)

	local chip = UIKit.button({
		Name = text,
		Size = UDim2.fromOffset(0, 26),
		AutomaticSize = Enum.AutomaticSize.X,
		Text = "  " .. text .. "  ",
		TextSize = 11,
		LayoutOrder = #sections,
		Parent = rail,
	})
	UIKit.corner(chip, UDim.new(0, 6))
	chip.TextColor3 = Theme.TextDim
	chip.BackgroundColor3 = Theme.Panel
	chip.MouseButton1Click:Connect(function()
		showSection(section)
	end)
	section.chip = chip

	current = section
	return section
end

function showSection(section)
	for _, other in ipairs(sections) do
		local active = other == section
		other.chosen = active
		other.chip.BackgroundColor3 = active and Theme.AccentDim or Theme.Panel
		other.chip.TextColor3 = active and Theme.Background or Theme.TextDim
		for _, item in ipairs(other.items) do
			item.Visible = active
		end
	end
end

-- A row with a text box and a Set button.
local function valueRow(label, command, default, placeholder, section)
	order += 1
	local row = register(UIKit.frame({
		Size = UDim2.new(1, 0, 0, 34),
		BackgroundTransparency = 1,
		LayoutOrder = order,
		Parent = body,
	}), section)

	local box = Instance.new("TextBox")
	box.Size = UDim2.new(1, -96, 1, 0)
	box.BackgroundColor3 = Theme.PanelLight
	box.BorderSizePixel = 0
	box.Font = Theme.Font
	box.TextColor3 = Theme.Text
	box.TextSize = 13
	box.PlaceholderText = placeholder or label
	box.Text = default or ""
	box.ClearTextOnFocus = false
	box.Parent = row
	UIKit.corner(box, UDim.new(0, 6))

	local btn = UIKit.button({
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, 0, 0, 0),
		Size = UDim2.fromOffset(88, 34),
		Text = label,
		TextSize = 12,
		Parent = row,
	})
	UIKit.corner(btn, UDim.new(0, 6))
	UIKit.hover(btn, Theme.AccentDim, Theme.Accent)
	btn.TextColor3 = Theme.Background
	btn.MouseButton1Click:Connect(function()
		run(command, { value = box.Text })
	end)
	return box
end

local function actionButton(label, command, value, danger, section)
	order += 1
	local btn = register(UIKit.button({
		-- Named after what it does, so a button can be found and clicked by path rather than
		-- by pixel -- which is how this panel gets tested.
		Name = command .. (value ~= nil and ("_" .. tostring(value)) or ""),
		Size = UDim2.new(1, 0, 0, 32),
		Text = label,
		TextSize = 13,
		LayoutOrder = order,
		Parent = body,
	}), section)
	UIKit.corner(btn, UDim.new(0, 6))
	UIKit.hover(btn, danger and Theme.PanelLight or Theme.Panel, danger and Theme.Danger or Theme.PanelLight)
	btn.TextColor3 = Theme.Text
	btn.MouseButton1Click:Connect(function()
		run(command, { value = value })
	end)
	return btn
end

-- ------------------------------------------------------------------ contents --

heading("STATS")
valueRow("Coins", "SetCoins", "10000", "amount")
valueRow("Kills", "SetKills", "0", "amount")

heading("PROGRESSION")
valueRow("Level", "SetLevel", "20", "1 - 100")
-- Sets the rank straight out, without the level reset. For looking at an emblem.
valueRow("Prestige", "SetPrestige", "0", "0 - 10")
-- Runs the genuine prestige, level reset included, so the real flow can be exercised
-- without grinding to the cap first. Marked danger because it does actually reset.
actionButton("Run a real prestige (resets level)", "DoPrestige", nil, true)

heading("WEAPONS")
local weaponNames = {}
for name in pairs(WeaponConfig.Weapons) do table.insert(weaponNames, name) end
table.sort(weaponNames)
for _, name in ipairs(weaponNames) do
	actionButton("Give " .. name, "GiveWeapon", name)
end

heading("NPCS")
local archetypes = {}
for name in pairs(NPCConfig.Archetypes) do table.insert(archetypes, name) end
table.sort(archetypes)
for _, name in ipairs(archetypes) do
	actionButton("Spawn " .. name, "SpawnNPC", name)
end
actionButton("Spawn the Flats Warlord", "SpawnBoss", "Flats")
actionButton("Spawn the Reach Warlord", "SpawnBoss", "Reach")
actionButton("Kill all NPCs", "ClearNPCs", nil, true)
actionButton("Clear dropped weapons", "ClearDrops", nil, true)

-- The map's travel network is gone; this section remains because it is admin tooling, not a
-- way for a player to move -- every button is refused on the server for anyone but the owner.
heading("ADMIN MOVE")
valueRow("To player", "Teleport", "", "player name")

-- The destinations come FROM THE SERVER rather than being typed here, so there is one list
-- instead of a server copy and a menu copy to drift apart -- and so the destinations are not
-- something a non-owner client could read out of this script.
local moveSection = current
task.spawn(function()
	local ok, result = pcall(function()
		return AdminCommand:InvokeServer("Waypoints", {})
	end)
	if not ok or type(result) ~= "table" or type(result.waypoints) ~= "table" then
		return
	end
	for _, entry in ipairs(result.waypoints) do
		-- These arrive after the rest of the panel is built, so they name their section
		-- rather than landing on whichever page happened to be open last.
		actionButton("Go to " .. tostring(entry.name), "Teleport", entry.id, false, moveSection)
	end
end)


heading("SELF")
actionButton("Toggle godmode", "Godmode", nil)
actionButton("Heal", "Heal", nil)
valueRow("Walk speed", "Speed", "16", "studs per second")

-- The world's own dials, so a lighting or visibility problem can be reproduced on demand
-- instead of waited for: the day/night clock takes sixteen real minutes to come round.
heading("WORLD")
for _, state in ipairs({ "Clear", "Overcast", "Fog", "Rain" }) do
	actionButton("Weather: " .. state, "Weather", state)
end
valueRow("Set hour", "TimeOfDay", "12", "0 - 24, pauses the clock")
actionButton("Resume the day/night clock", "ResumeTime", nil)

heading("DATA")
actionButton("Diagnostics: population, tick, parts", "Diagnostics", nil)
-- Coins live in leaderstats and were being persisted by two legacy DataStores that can
-- disagree. This copies the HIGHEST of the three onto the profile and never lowers anything.
-- Nothing reads the profile figure yet: run it, read what it reports, then we switch over.
actionButton("Migrate my coins onto the profile", "MigrateCoins", nil, true)

-- Open on the first page rather than showing everything at once.
showSection(sections[1])

-- ------------------------------------------------------------------- toggle --

local function setOpen(open)
	isOpen = open
	panel.Visible = open
	UIState.SetOpen("Admin", open)
end

closeBtn.MouseButton1Click:Connect(function()
	setOpen(false)
end)

-- F4 is free and out of the way of the other menus.
UserInputService.InputBegan:Connect(function(input)
	if input.KeyCode == Enum.KeyCode.F4 then
		if not UserInputService:GetFocusedTextBox() then
			setOpen(not isOpen)
		end
	end
end)

local openBtn = UIKit.button({
	Name = "OpenAdmin",
	-- Top-left. It used to sit at x=232 to clear the HD Admin icon; that suite is gone, so
	-- the button takes the corner back.
	AnchorPoint = Vector2.new(0, 0),
	Position = UDim2.new(0, 16, 0, 16),
	Size = UDim2.fromOffset(104, 32),
	Text = "ADMIN  [F4]",
	TextSize = 12,
	Parent = gui,
})
UIKit.corner(openBtn, UDim.new(0, 8))
UIKit.stroke(openBtn, Color3.fromRGB(196, 64, 64), 1, 0.3)
UIKit.hover(openBtn, Theme.Panel, Theme.PanelLight)
openBtn.TextColor3 = Color3.fromRGB(226, 110, 110)
openBtn.MouseButton1Click:Connect(function()
	setOpen(not isOpen)
end)

setOpen(false)
