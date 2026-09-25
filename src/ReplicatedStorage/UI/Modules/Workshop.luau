--!strict
-- The workshop: saved builds for a weapon -- attachments and camo, kept per weapon.
--
-- This is the PLAYER-facing half of weapon customisation. The other half, CustomiseAction, is
-- owner-only skin authoring that the server refuses for anybody else; it is a development
-- tool rather than part of the game, so it is deliberately not rebuilt here.
--
-- Nothing is applied locally. Every change goes through BuildAction and the server re-checks
-- that the attachment and the camo are actually owned before it stores anything -- so editing
-- this file gets you a nice-looking build and no weapon.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menu = require(script.Parent.Menu)

local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
local WeaponPreview = require(ReplicatedStorage:WaitForChild("WeaponPreview"))
local CamoConfig = require(ReplicatedStorage:WaitForChild("CamoConfig"))
local AttachmentConfig = require(ReplicatedStorage:WaitForChild("AttachmentConfig"))

local Workshop = {}
Workshop.__index = Workshop

local MAX_BUILDS = 8

function Workshop.new(parent: Instance, remotes)
	local self = setmetatable({}, Workshop)

	self._remotes = remotes
	self._owned = {}
	self._weapon = nil
	self._builds = {}
	self._equippedId = nil
	self._selected = nil
	self._rows = {}
	self._weaponButtons = {}

	local menu = Menu.new(parent, {
		id = "Workshop",
		title = "WORKSHOP",
		subtitle = "Attachments and camo, saved per weapon.",
		size = UDim2.fromOffset(980, 580),
	})
	self._menu = menu

	-- Weapons you own, down the left. Filled at open rather than construction, because what
	-- you own changes.
	local rail = Instance.new("ScrollingFrame")
	rail.Name = "Weapons"
	rail.BackgroundTransparency = 1
	rail.BorderSizePixel = 0
	rail.Size = UDim2.new(0, 150, 1, 0)
	rail.CanvasSize = UDim2.new()
	rail.AutomaticCanvasSize = Enum.AutomaticSize.Y
	rail.ScrollBarThickness = 3
	rail.ScrollBarImageColor3 = Theme.Colour.Stroke
	rail.Parent = menu.content
	Components.List(rail, Enum.FillDirection.Vertical, Theme.Space.XS)
	self._rail = rail

	-- Centre: the weapon itself, big.
	local stage = Components.Panel(menu.content, {
		name = "Stage",
		colour = Theme.Colour.Sunken,
		radius = Theme.Radius.Card,
		size = UDim2.new(0, 400, 0, 250),
		position = UDim2.fromOffset(162, 0),
	})
	self._stage = stage

	self._preview = Instance.new("Frame")
	self._preview.Name = "Preview"
	self._preview.BackgroundTransparency = 1
	self._preview.Size = UDim2.new(1, -Theme.Space.XL, 1, -60)
	self._preview.Position = UDim2.fromOffset(Theme.Space.M, Theme.Space.M)
	self._preview.Parent = stage

	self._weaponName = Components.Label(stage, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Large,
		align = Enum.TextXAlignment.Center,
	})
	self._weaponName.Size = UDim2.new(1, 0, 0, 22)
	self._weaponName.Position = UDim2.new(0, 0, 1, -42)

	self._weaponRarity = Components.Label(stage, {
		text = "",
		caps = true,
		size = Theme.Text.Micro,
		align = Enum.TextXAlignment.Center,
	})
	self._weaponRarity.Size = UDim2.new(1, 0, 0, 14)
	self._weaponRarity.Position = UDim2.new(0, 0, 1, -22)

	-- Under the stage: attachment slots and the camo shelf for the selected build.
	local editor = Instance.new("ScrollingFrame")
	editor.Name = "Editor"
	editor.BackgroundTransparency = 1
	editor.BorderSizePixel = 0
	editor.Size = UDim2.new(0, 400, 1, -262)
	editor.Position = UDim2.fromOffset(162, 262)
	editor.CanvasSize = UDim2.new()
	editor.AutomaticCanvasSize = Enum.AutomaticSize.Y
	editor.ScrollBarThickness = 3
	editor.ScrollBarImageColor3 = Theme.Colour.Stroke
	editor.Parent = menu.content
	Components.List(editor, Enum.FillDirection.Vertical, Theme.Space.S)
	self._editor = editor

	-- Right: the build slots.
	local slots = Instance.new("ScrollingFrame")
	slots.Name = "Builds"
	slots.BackgroundTransparency = 1
	slots.BorderSizePixel = 0
	slots.Size = UDim2.new(1, -574, 1, -52)
	slots.Position = UDim2.fromOffset(574, 0)
	slots.CanvasSize = UDim2.new()
	slots.AutomaticCanvasSize = Enum.AutomaticSize.Y
	slots.ScrollBarThickness = 3
	slots.ScrollBarImageColor3 = Theme.Colour.Stroke
	slots.Parent = menu.content
	Components.List(slots, Enum.FillDirection.Vertical, Theme.Space.XS)
	self._slots = slots

	self._newBuild = Components.Button(menu.content, {
		name = "NewBuild",
		text = "NEW BUILD",
		primary = true,
		size = UDim2.new(1, -574, 0, Theme.Size.ButtonHeight),
		position = UDim2.new(0, 574, 1, 0),
		anchor = Vector2.new(0, 1),
		onActivated = function()
			self:_createBuild()
		end,
	})

	menu:OnOpen(function()
		self:Refresh()
	end)

	return self
end

-- ------------------------------------------------------------- ownership --

function Workshop:_owns(field: string, id: string): boolean
	local list = self._owned[field]
	return type(list) == "table" and table.find(list, id) ~= nil
end

function Workshop:Refresh()
	task.spawn(function()
		local ok, result = pcall(function()
			return self._remotes.getOwnership:InvokeServer()
		end)
		self._owned = (ok and type(result) == "table") and result or {}
		self:_fillWeapons()
	end)
end

function Workshop:_fillWeapons()
	for _, button in ipairs(self._weaponButtons) do
		button:Destroy()
	end
	table.clear(self._weaponButtons)

	local names = {}
	for name, cfg in pairs(WeaponConfig.Weapons) do
		-- Only guns take attachments and camo, and only what you own is worth showing.
		if cfg.Type == "Gun" and self:_owns("OwnedItems", name) then
			table.insert(names, name)
		end
	end
	table.sort(names)

	for index, name in ipairs(names) do
		local cfg = WeaponConfig.Weapons[name]
		local button = Components.Button(self._rail, {
			name = name,
			text = name,
			layoutOrder = index,
			size = UDim2.new(1, -6, 0, Theme.Size.ButtonHeightS),
			textSize = Theme.Text.Small,
			onActivated = function()
				self:_selectWeapon(name)
			end,
		})
		button.instance.TextXAlignment = Enum.TextXAlignment.Left
		Components.Padding(button.instance, nil, Theme.Space.S, 0)
		-- Rarity reads as a left edge here, the way it reads as a top edge on a card.
		local edge = Instance.new("Frame")
		edge.Name = "RarityEdge"
		edge.BackgroundColor3 = Theme.RarityColour(cfg.Rarity)
		edge.BorderSizePixel = 0
		edge.Size = UDim2.new(0, 2, 1, 0)
		edge.Parent = button.instance
		table.insert(self._weaponButtons, button)
	end

	if names[1] then
		local keep = self._weapon and table.find(names, self._weapon)
		self:_selectWeapon(keep and self._weapon or names[1])
	else
		self._weaponName.Text = "Nothing to work on"
		self._weaponRarity.Text = "BUY A GUN FIRST"
	end
end

-- ---------------------------------------------------------------- weapon --

function Workshop:_selectWeapon(name: string)
	self._weapon = name
	self._selected = nil

	local cfg = WeaponConfig.Weapons[name]
	self._weaponName.Text = name
	self._weaponRarity.Text = string.upper(cfg and cfg.Rarity or "")
	self._weaponRarity.TextColor3 = Theme.RarityColour(cfg and cfg.Rarity)

	self._preview:ClearAllChildren()
	pcall(function()
		WeaponPreview.Render(self._preview, name)
	end)

	for _, button in ipairs(self._weaponButtons) do
		button:SetSelected(button.instance.Name == name)
	end

	self:_loadBuilds()
end

function Workshop:_loadBuilds()
	local weapon = self._weapon
	if not weapon then
		return
	end
	task.spawn(function()
		local ok, response = pcall(function()
			return self._remotes.buildAction:InvokeServer("list", weapon)
		end)
		if ok and type(response) == "table" and response.ok then
			self._builds = response.builds or {}
			self._equippedId = response.equipped
		else
			self._builds = {}
			self._equippedId = nil
		end
		self:_fillBuilds()
	end)
end

-- ---------------------------------------------------------------- builds --

function Workshop:_fillBuilds()
	for _, row in ipairs(self._rows) do
		row.Destroy()
	end
	table.clear(self._rows)

	-- The default is always there and cannot be deleted: it is the weapon as issued.
	self:_buildRow(nil, "DEFAULT", 0)
	for index, build in ipairs(self._builds) do
		self:_buildRow(build, build.name or string.format("BUILD %02d", index), index)
	end

	local room = #self._builds < MAX_BUILDS
	self._newBuild:SetEnabled(room)
	self._newBuild:SetText(room
		and string.format("NEW BUILD  %d/%d", #self._builds, MAX_BUILDS)
		or string.format("SLOTS FULL  %d/%d", MAX_BUILDS, MAX_BUILDS))

	if self._selected == nil and self._builds[1] then
		self._selected = self._builds[1]
	end
	self:_fillEditor()
end

function Workshop:_buildRow(build, label: string, order: number)
	local isEquipped = (build == nil and self._equippedId == nil)
		or (build ~= nil and self._equippedId == build.id)

	local row = Instance.new("TextButton")
	row.Name = build and build.id or "Default"
	row.AutoButtonColor = false
	row.Text = ""
	row.BackgroundColor3 = Theme.Colour.PanelRaised
	row.BorderSizePixel = 0
	row.Size = UDim2.new(1, -6, 0, 46)
	row.LayoutOrder = order
	row.Parent = self._slots
	Components.Corner(row, Theme.Radius.Small)
	local edge = Components.Stroke(row,
		isEquipped and Theme.Colour.Accent or Theme.Colour.Stroke,
		isEquipped and Theme.Stroke.Emphasis or Theme.Stroke.Hair)

	local name = Components.Label(row, {
		text = label,
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
	})
	name.Size = UDim2.new(1, -110, 0, 16)
	name.Position = UDim2.fromOffset(Theme.Space.M, 6)

	local fitted = 0
	for _ in pairs(build and build.attachments or {}) do
		fitted += 1
	end
	local detail = Components.Label(row, {
		text = build and string.format("%s  -  %d fitted", tostring(build.camo or "Factory"), fitted)
			or "As issued",
		size = Theme.Text.Micro,
		colour = Theme.Colour.TextMuted,
	})
	detail.Size = UDim2.new(1, -110, 0, 14)
	detail.Position = UDim2.fromOffset(Theme.Space.M, 24)

	local equip = Components.Button(row, {
		name = "Equip",
		text = isEquipped and "ON" or "USE",
		primary = not isEquipped,
		size = UDim2.fromOffset(46, 26),
		position = UDim2.new(1, -Theme.Space.S, 0.5, 0),
		anchor = Vector2.new(1, 0.5),
		textSize = Theme.Text.Micro,
		onActivated = function()
			self:_equipBuild(build)
		end,
	})
	equip:SetEnabled(not isEquipped)

	local remove
	if build then
		remove = Components.Button(row, {
			name = "Delete",
			text = "X",
			danger = true,
			size = UDim2.fromOffset(26, 26),
			position = UDim2.new(1, -(Theme.Space.S + 50), 0.5, 0),
			anchor = Vector2.new(1, 0.5),
			textSize = Theme.Text.Micro,
			onActivated = function()
				self:_deleteBuild(build)
			end,
		})
	end

	local disconnect = Components.MakeInteractive(row, row, { base = Theme.Colour.PanelRaised, lift = false })
	local activated = row.Activated:Connect(function()
		if build then
			self._selected = build
			self:_fillEditor()
		end
	end)

	table.insert(self._rows, {
		Destroy = function()
			disconnect()
			activated:Disconnect()
			equip:Destroy()
			if remove then
				remove:Destroy()
			end
			row:Destroy()
		end,
	})
end

-- ---------------------------------------------------------------- editor --

function Workshop:_fillEditor()
	for _, child in ipairs(self._editor:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local build = self._selected
	if not build then
		local hint = Components.Label(self._editor, {
			text = "Pick a build on the right, or make one.",
			size = Theme.Text.Small,
			colour = Theme.Colour.TextMuted,
			layoutOrder = 1,
		})
		hint.Size = UDim2.new(1, 0, 0, 20)
		return
	end

	local order = 0
	local function heading(text: string)
		order += 1
		local label = Components.Label(self._editor, {
			text = text,
			caps = true,
			size = Theme.Text.Micro,
			layoutOrder = order,
		})
		label.Size = UDim2.new(1, 0, 0, 16)
	end

	-- Slot label on its own line, options WRAPPING underneath. A single horizontal row looks
	-- tidier right up until a slot has five options, at which point the rest are clipped off
	-- the edge of the panel with nothing to say they exist.
	local CHIP = Vector2.new(92, 26)
	local PER_ROW = 4

	heading("Attachments")
	for _, slot in ipairs(AttachmentConfig.Slots) do
		local list = AttachmentConfig.Options[slot] or {}
		if #list == 0 then
			continue
		end

		order += 1
		local label = Components.Label(self._editor, {
			text = AttachmentConfig.SlotLabels[slot] or slot,
			size = Theme.Text.Small,
			colour = Theme.Colour.TextDim,
			layoutOrder = order,
		})
		label.Size = UDim2.new(1, -6, 0, 18)

		order += 1
		local options = Instance.new("Frame")
		options.Name = slot
		options.BackgroundTransparency = 1
		options.Size = UDim2.new(1, -6, 0, math.ceil(#list / PER_ROW) * (CHIP.Y + Theme.Space.XS))
		options.LayoutOrder = order
		options.Parent = self._editor
		Components.Grid(options, CHIP, Theme.Space.XS)

		local fitted = (build.attachments or {})[slot]
		for index, option in ipairs(list) do
			local stock = AttachmentConfig.IsStock(slot, option.id)
			local key = AttachmentConfig.Key(slot, option.id)
			-- Stock parts come with the gun; everything else has to be bought first.
			local owned = stock or self:_owns("OwnedAttachments", key)
			local on = (fitted == option.id) or (fitted == nil and stock)

			local chip = Components.Button(options, {
				name = option.id,
				text = option.name,
				layoutOrder = index,
				size = UDim2.fromOffset(CHIP.X, CHIP.Y),
				textSize = Theme.Text.Micro,
				onActivated = function()
					if not owned then
						return
					end
					build.attachments = build.attachments or {}
					build.attachments[slot] = (not stock) and option.id or nil
					self:_save()
				end,
			})
			chip:SetEnabled(owned)
			chip:SetSelected(on)
		end
	end

	heading("Camo")
	order += 1
	local camoHolder = Instance.new("Frame")
	camoHolder.Name = "Camos"
	camoHolder.BackgroundTransparency = 1
	camoHolder.Size = UDim2.new(1, -6, 0, math.ceil(#CamoConfig.Camos / PER_ROW) * (CHIP.Y + Theme.Space.XS))
	camoHolder.LayoutOrder = order
	camoHolder.Parent = self._editor
	Components.Grid(camoHolder, CHIP, Theme.Space.XS)

	for index, camo in ipairs(CamoConfig.Camos) do
		local owned = camo.factory == true or self:_owns("OwnedCamos", camo.id)
		local on = (build.camo == camo.id) or (build.camo == nil and camo.factory == true)
		local chip = Components.Button(camoHolder, {
			name = camo.id,
			text = camo.name,
			layoutOrder = index,
			size = UDim2.fromOffset(CHIP.X, CHIP.Y),
			textSize = Theme.Text.Micro,
			onActivated = function()
				if not owned then
					return
				end
				build.camo = (not camo.factory) and camo.id or nil
				self:_save()
			end,
		})
		chip:SetEnabled(owned)
		chip:SetSelected(on)
	end
end

-- --------------------------------------------------------------- actions --

function Workshop:_save()
	local weapon, build = self._weapon, self._selected
	if not weapon or not build then
		return
	end
	task.spawn(function()
		pcall(function()
			self._remotes.buildAction:InvokeServer("save", weapon, {
				id = build.id,
				name = build.name,
				attachments = build.attachments,
				camo = build.camo,
			})
		end)
		-- Reload rather than trusting the local edit: the server drops anything unowned, and the
		-- panel should show what was actually stored.
		self:_loadBuilds()
	end)
end

function Workshop:_createBuild()
	local weapon = self._weapon
	if not weapon then
		return
	end
	self._newBuild:SetText("...")
	task.spawn(function()
		local ok, response = pcall(function()
			return self._remotes.buildAction:InvokeServer("create", weapon, {
				name = string.format("BUILD %02d", #self._builds + 1),
			})
		end)
		if ok and type(response) == "table" and response.ok and response.build then
			self._selected = response.build
		end
		self:_loadBuilds()
	end)
end

function Workshop:_equipBuild(build)
	local weapon = self._weapon
	if not weapon then
		return
	end
	task.spawn(function()
		pcall(function()
			self._remotes.buildAction:InvokeServer("equip", weapon, build and { id = build.id } or nil)
		end)
		self:_loadBuilds()
	end)
end

function Workshop:_deleteBuild(build)
	local weapon = self._weapon
	if not weapon or not build then
		return
	end
	task.spawn(function()
		pcall(function()
			self._remotes.buildAction:InvokeServer("delete", weapon, { id = build.id })
		end)
		if self._selected == build then
			self._selected = nil
		end
		self:_loadBuilds()
	end)
end

function Workshop:Toggle()
	self._menu:Toggle()
end

function Workshop:Close()
	self._menu:Close()
end

function Workshop:Destroy()
	for _, row in ipairs(self._rows) do
		row.Destroy()
	end
	for _, button in ipairs(self._weaponButtons) do
		button:Destroy()
	end
	self._newBuild:Destroy()
	self._menu:Destroy()
end

return Workshop
