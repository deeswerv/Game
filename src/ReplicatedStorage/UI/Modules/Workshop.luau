--!strict
-- The armory: pick a gun, see it big, build it out.
--
-- Laid out like the reference armory screen:
--   left    every gun, grouped by kind, owned first; locked ones carry a padlock and the
--           level they open at
--   centre  the selected gun large on a lit stage -- WITH the build's attachments actually
--           fitted to the model -- turning slowly, draggable; the saved builds as cards under it
--   right   the stat bars (with green/red deltas for what the build changes) and the
--           attachment picker for the build being edited
--
-- Nothing is applied locally. Every change goes through BuildAction and the server re-checks
-- ownership before storing anything -- so editing this file gets you a nice-looking build and
-- no weapon. Camos are retired; a build's stored camo is passed through untouched.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menu = require(script.Parent.Menu)

local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
local WeaponPreview = require(ReplicatedStorage:WaitForChild("WeaponPreview"))
local AttachmentConfig = require(ReplicatedStorage:WaitForChild("AttachmentConfig"))
local AttachmentBuilder = require(ReplicatedStorage:WaitForChild("AttachmentBuilder"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local Workshop = {}
Workshop.__index = Workshop

local MAX_BUILDS = 8
local LIST_WIDTH = 214
local SIDE_WIDTH = 290
local GAP = 12
local WHITE = Color3.new(1, 1, 1)
local GOOD = Color3.fromRGB(80, 230, 110)
local BAD = Color3.fromRGB(255, 90, 90)

local GROUPS = {
	Rifle = "Rifles", Carbine = "Rifles", LMG = "Rifles", Marksman = "Rifles",
	SMG = "SMGs", Shotgun = "Shotguns", Sniper = "Snipers", Pistol = "Pistols", Revolver = "Pistols",
}
local GROUP_ORDER = { "Rifles", "SMGs", "Shotguns", "Snipers", "Pistols", "Other" }

local SLOT_ICON = {
	Sight = "🔭", Muzzle = "🔇", Underbarrel = "✊", Magazine = "📦", Stock = "🪵", Charm = "🍀",
}

-- Level each shop weapon opens at, for the padlock line.
local LEVEL_FOR: { [string]: number } = {}
for _, item in ipairs(GameConfig.ShopItems) do
	LEVEL_FOR[item.item or item.id] = item.levelRequired or 1
end

-- ------------------------------------------------------------------ stats --

-- label, value 0..100 for the bar, text, and the raw number used for the delta.
local function statLines(cfg)
	local accuracy = math.clamp(100 - (cfg.SpreadMin or 0) * 14 - (cfg.RecoilPitch or 0) * 5, 5, 100)
	local rpm = 60 / math.max(cfg.FireRate or 1, 0.01)
	local damage = (cfg.Damage or 0) * (cfg.PelletsPerShot or 1)
	local handling = math.clamp((cfg.AdsSpeed or 12) / 16 * 100, 5, 100)
	return {
		{ "Accuracy", accuracy, string.format("%d", math.floor(accuracy + 0.5)), accuracy },
		{ "Damage", math.clamp(damage, 0, 100), string.format("%d", math.floor(damage + 0.5)), damage },
		{ "Fire Rate", math.clamp(rpm / 10, 0, 100), string.format("%d RPM", math.floor(rpm + 0.5)), rpm },
		{ "Magazine", math.clamp((cfg.MagazineSize or 0) / 60 * 100, 0, 100), tostring(cfg.MagazineSize or 0), cfg.MagazineSize or 0 },
		{ "Range", math.clamp((cfg.Range or 0) / 5, 0, 100), tostring(math.floor(cfg.Range or 0)), cfg.Range or 0 },
		{ "Handling", handling, string.format("%d", math.floor(handling + 0.5)), handling },
	}
end

-- ------------------------------------------------------------------ build --

function Workshop.new(parent: Instance, remotes)
	local self = setmetatable({}, Workshop)

	self._remotes = remotes
	self._owned = {}
	self._weapon = nil
	self._builds = {}
	self._equippedId = nil
	self._selected = nil          -- the build being edited (nil = the default, not editable)
	self._rows = {}
	self._buildCards = {}
	self._yaw = 0
	self._dragging = false

	local menu = Menu.new(parent, {
		id = "Workshop",
		title = "Armory",
		subtitle = "Pick a gun, fit it out, save the build",
		icon = "🧰",
		size = UDim2.fromOffset(1060, 620),
	})
	self._menu = menu
	local content = menu.content

	-- ------------------------------------------------------ weapon list --

	local list = Instance.new("ScrollingFrame")
	list.Name = "Weapons"
	list.BackgroundColor3 = Theme.Colour.Sunken
	list.BackgroundTransparency = 0.3
	list.BorderSizePixel = 0
	list.Size = UDim2.new(0, LIST_WIDTH, 1, 0)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 4
	list.ScrollBarImageColor3 = Theme.Colour.Stroke
	list.Parent = content
	Components.Corner(list, 12)
	Components.List(list, Enum.FillDirection.Vertical, 4)
	Components.Padding(list, 6)
	self._list = list

	-- ------------------------------------------------------------ stage --

	local centreWidth = -(LIST_WIDTH + SIDE_WIDTH + GAP * 2)
	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BackgroundColor3 = Color3.fromRGB(56, 62, 78)
	stage.BorderSizePixel = 0
	stage.Size = UDim2.new(1, centreWidth, 0, 330)
	stage.Position = UDim2.fromOffset(LIST_WIDTH + GAP, 0)
	stage.Active = true
	stage.Parent = content
	Components.Corner(stage, 14)
	Components.Stroke(stage, Theme.Colour.Outline, 2).Transparency = 0.3
	-- A spotlight: bright in the middle, falling off to the edges.
	local light = Instance.new("UIGradient")
	light.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(60, 60, 66)),
		ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 255, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(60, 60, 66)),
	})
	light.Parent = stage
	self._stage = stage

	local floor = Instance.new("Frame")
	floor.Name = "Floor"
	floor.BackgroundColor3 = Color3.new(0, 0, 0)
	floor.BackgroundTransparency = 0.55
	floor.BorderSizePixel = 0
	floor.AnchorPoint = Vector2.new(0.5, 0)
	floor.Position = UDim2.new(0.5, 0, 0.8, 0)
	floor.Size = UDim2.new(0.62, 0, 0, 16)
	floor.Parent = stage
	Components.Corner(floor, 8)

	self._viewport = nil :: ViewportFrame?

	self._weaponName = Components.Label(stage, {
		text = "",
		font = Theme.Font.Display,
		size = 30,
		align = Enum.TextXAlignment.Left,
		outline = 2.6,
	})
	self._weaponName.Size = UDim2.new(1, -24, 0, 34)
	self._weaponName.Position = UDim2.fromOffset(14, 8)
	self._weaponName.ZIndex = 3

	self._weaponChips = Instance.new("Frame")
	self._weaponChips.BackgroundTransparency = 1
	self._weaponChips.Size = UDim2.new(1, -24, 0, 22)
	self._weaponChips.Position = UDim2.fromOffset(14, 44)
	self._weaponChips.ZIndex = 3
	self._weaponChips.Parent = stage
	Components.List(self._weaponChips, Enum.FillDirection.Horizontal, 6)

	local hint = Components.Label(stage, {
		text = "Drag to rotate",
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Right,
	})
	hint.Size = UDim2.new(1, -20, 0, 18)
	hint.Position = UDim2.new(0, 0, 1, -24)
	hint.ZIndex = 3

	stage.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._dragging = true
		end
	end)
	stage.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			self._dragging = false
		end
	end)
	stage.InputChanged:Connect(function(input: InputObject)
		if self._dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
			or input.UserInputType == Enum.UserInputType.Touch) then
			self._yaw -= input.Delta.X * 0.012
		end
	end)
	stage.MouseLeave:Connect(function()
		self._dragging = false
	end)

	-- ------------------------------------------------------------ builds --

	local buildsLabel = Components.Label(content, {
		text = "Builds",
		font = Theme.Font.Bold,
		size = 18,
		colour = Theme.Colour.TextDim,
	})
	buildsLabel.Size = UDim2.new(1, centreWidth, 0, 22)
	buildsLabel.Position = UDim2.fromOffset(LIST_WIDTH + GAP + 4, 338)

	local builds = Instance.new("ScrollingFrame")
	builds.Name = "Builds"
	builds.BackgroundTransparency = 1
	builds.BorderSizePixel = 0
	builds.Size = UDim2.new(1, centreWidth, 0, 118)
	builds.Position = UDim2.fromOffset(LIST_WIDTH + GAP, 362)
	builds.CanvasSize = UDim2.new()
	builds.AutomaticCanvasSize = Enum.AutomaticSize.X
	builds.ScrollingDirection = Enum.ScrollingDirection.X
	builds.ScrollBarThickness = 4
	builds.ScrollBarImageColor3 = Theme.Colour.Stroke
	builds.Parent = content
	local buildRow = Components.List(builds, Enum.FillDirection.Horizontal, 10)
	buildRow.VerticalAlignment = Enum.VerticalAlignment.Center
	Components.Padding(builds, 6)
	self._buildsRow = builds

	self._status = Components.Label(content, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
	})
	self._status.Size = UDim2.new(1, centreWidth, 0, 20)
	self._status.Position = UDim2.new(0, LIST_WIDTH + GAP, 1, -22)

	-- -------------------------------------------------------------- side --

	local side = Instance.new("Frame")
	side.Name = "Side"
	side.BackgroundColor3 = Theme.Colour.Sunken
	side.BackgroundTransparency = 0.3
	side.BorderSizePixel = 0
	side.AnchorPoint = Vector2.new(1, 0)
	side.Position = UDim2.fromScale(1, 0)
	side.Size = UDim2.new(0, SIDE_WIDTH, 1, 0)
	side.Parent = content
	Components.Corner(side, 12)

	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.BackgroundTransparency = 1
	stats.Size = UDim2.new(1, -16, 0, 6 * 26)
	stats.Position = UDim2.fromOffset(8, 10)
	stats.Parent = side
	Components.List(stats, Enum.FillDirection.Vertical, 2)
	self._stats = stats

	local editorLabel = Components.Label(side, {
		text = "Attachments",
		font = Theme.Font.Bold,
		size = 18,
		colour = Theme.Colour.TextDim,
	})
	editorLabel.Size = UDim2.new(1, -20, 0, 22)
	editorLabel.Position = UDim2.fromOffset(12, 176)

	local editor = Instance.new("ScrollingFrame")
	editor.Name = "Editor"
	editor.BackgroundTransparency = 1
	editor.BorderSizePixel = 0
	editor.Size = UDim2.new(1, -8, 1, -(200 + 58))
	editor.Position = UDim2.fromOffset(4, 200)
	editor.CanvasSize = UDim2.new()
	editor.AutomaticCanvasSize = Enum.AutomaticSize.Y
	editor.ScrollBarThickness = 4
	editor.ScrollBarImageColor3 = Theme.Colour.Stroke
	editor.Parent = side
	Components.List(editor, Enum.FillDirection.Vertical, 4)
	Components.Padding(editor, nil, 6, 2)
	self._editor = editor

	self._action = Components.Button(side, {
		name = "Action",
		text = "EQUIP BUILD",
		primary = true,
		textSize = 20,
		size = UDim2.new(1, -20, 0, 44),
		position = UDim2.new(0.5, 0, 1, -8),
		anchor = Vector2.new(0.5, 1),
		onActivated = function()
			self:_primaryAction()
		end,
	})

	menu:OnOpen(function()
		self:Refresh()
		self:_startSpin()
	end)
	menu:OnClose(function()
		self:_stopSpin()
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

-- ------------------------------------------------------------------ list --

function Workshop:_fillWeapons()
	for _, row in ipairs(self._rows) do
		row.Destroy()
	end
	table.clear(self._rows)

	-- Guns only: attachments fit guns.
	local grouped: { [string]: { string } } = {}
	for name, entry in pairs(WeaponConfig.Weapons) do
		local cfg = WeaponConfig.Get(name)
		if cfg.Type == "Gun" and WeaponConfig.HasModel(name) and not (entry :: any).Hidden then
			local group = GROUPS[cfg.Class] or "Other"
			grouped[group] = grouped[group] or {}
			table.insert(grouped[group], name)
		end
	end

	local order = 0
	local firstOwned: string? = nil
	for _, group in ipairs(GROUP_ORDER) do
		local names = grouped[group]
		if names and #names > 0 then
			table.sort(names, function(a, b)
				local oa, ob = self:_owns("OwnedItems", a), self:_owns("OwnedItems", b)
				if oa ~= ob then
					return oa
				end
				return (LEVEL_FOR[a] or 0) < (LEVEL_FOR[b] or 0)
			end)

			order += 1
			local heading = Components.Label(self._list, {
				text = string.upper(group),
				font = Theme.Font.Bold,
				size = 20,
				colour = Theme.Colour.TextMuted,
				layoutOrder = order,
			})
			heading.Size = UDim2.new(1, 0, 0, 28)
			table.insert(self._rows, { Destroy = function()
				heading:Destroy()
			end })

			for _, name in ipairs(names) do
				order += 1
				local owned = self:_owns("OwnedItems", name)
				firstOwned = firstOwned or (owned and name or nil)
				table.insert(self._rows, self:_weaponRow(name, owned, order))
			end
		end
	end

	local keep = self._weapon and WeaponConfig.Get(self._weapon) and self._weapon
	local pick = keep or firstOwned
	if not pick then
		for _, row in ipairs(self._rows) do
			if row.name then
				pick = row.name
				break
			end
		end
	end
	if pick then
		self:_selectWeapon(pick)
	end
end

function Workshop:_weaponRow(name: string, owned: boolean, order: number)
	local cfg = WeaponConfig.Get(name)
	local rarity = Theme.RarityColour(cfg.Rarity)

	local row = Instance.new("TextButton")
	row.Name = name
	row.AutoButtonColor = false
	row.Text = ""
	row.BackgroundColor3 = Theme.Colour.PanelRaised
	row.BackgroundTransparency = owned and 0.1 or 0.45
	row.Size = UDim2.new(1, -4, 0, 50)
	row.LayoutOrder = order
	row.Parent = self._list
	Components.Corner(row, 8)
	local rim = Components.Stroke(row, Theme.Colour.Outline, 1.5)

	local dot = Instance.new("Frame")
	dot.Name = "Rarity"
	dot.BackgroundColor3 = rarity
	dot.BorderSizePixel = 0
	dot.Size = UDim2.fromOffset(4, 34)
	dot.Position = UDim2.fromOffset(4, 8)
	dot.Parent = row
	Components.Corner(dot, 2)

	local label = Components.Label(row, {
		text = name,
		font = Theme.Font.Bold,
		size = 19,
		colour = owned and Theme.Colour.Text or Theme.Colour.TextMuted,
	})
	label.Size = UDim2.new(1, -86, 0, 22)
	label.Position = UDim2.fromOffset(14, 5)
	label.TextTruncate = Enum.TextTruncate.AtEnd

	local sub = Components.Label(row, {
		text = owned and string.upper(cfg.Rarity or "") or ("🔒 LEVEL " .. tostring(LEVEL_FOR[name] or 1)),
		font = Theme.Font.Bold,
		size = Theme.Text.Micro,
		colour = owned and Theme.Shade(rarity, 0.4) or Theme.Colour.TextMuted,
	})
	sub.Size = UDim2.new(1, -86, 0, 14)
	sub.Position = UDim2.fromOffset(14, 29)

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(1, 0.5)
	holder.Position = UDim2.new(1, -4, 0.5, 0)
	holder.Size = UDim2.fromOffset(70, 42)
	holder.Parent = row
	pcall(function()
		WeaponPreview.Icon(holder, name, { Dim = owned and 0 or 0.5, Zoom = 1.2 })
	end)

	local activated = row.Activated:Connect(function()
		self:_selectWeapon(name)
	end)

	return {
		name = name,
		instance = row,
		SetSelected = function(on: boolean)
			row.BackgroundColor3 = on and Color3.fromRGB(150, 156, 170) or Theme.Colour.PanelRaised
			rim.Color = on and WHITE or Theme.Colour.Outline
			rim.Thickness = on and 2.5 or 1.5
		end,
		Destroy = function()
			activated:Disconnect()
			row:Destroy()
		end,
	}
end

-- ---------------------------------------------------------------- stage --

--- The selected gun with `attachments` really fitted, in its own viewport.
function Workshop:_renderStage(name: string, attachments: { [string]: string }?)
	if self._viewport then
		self._viewport:Destroy()
		self._viewport = nil
	end
	local store = ReplicatedStorage:FindFirstChild("storeitems")
	local template = store and store:FindFirstChild(name)
	if not template then
		return
	end

	local vp = Instance.new("ViewportFrame")
	vp.Name = "Viewport"
	vp.BackgroundTransparency = 1
	vp.Size = UDim2.new(1, 0, 1, -30)
	vp.Position = UDim2.fromOffset(0, 26)
	vp.Ambient = Color3.fromRGB(170, 172, 186)
	vp.LightColor = Color3.fromRGB(255, 250, 240)
	vp.LightDirection = Vector3.new(-0.3, -1, -0.6)
	vp.ZIndex = 2
	vp.Parent = self._stage

	local copy = template:Clone()
	-- A picture must never run anything or make noise: this copy lives under PlayerGui, where
	-- a LocalScript would actually execute.
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("Light") or d:IsA("ProximityPrompt")
			or d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") then
			d:Destroy()
		end
	end
	pcall(AttachmentBuilder.Apply, copy, attachments)

	local model = Instance.new("Model")
	model.Name = "Weapon"
	copy.Parent = model
	model.Parent = vp

	local centre, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 30
	camera.Parent = vp
	vp.CurrentCamera = camera

	self._viewport = vp
	self._camera = camera
	self._centre = centre.Position
	self._reach = math.max(size.X, size.Y, size.Z) * 1.55 + 0.5
	self:_placeCamera()

	-- Arrive with a little pop.
	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = vp
	TweenService:Create(scale, Theme.Tween.Pop, { Scale = 1 }):Play()
end

function Workshop:_placeCamera()
	local camera = self._camera
	if not camera or not camera.Parent then
		return
	end
	-- The same three-quarter view the icons use, orbited about the vertical.
	local dir = CFrame.Angles(0, self._yaw, 0):VectorToWorldSpace(Vector3.new(0.35, 0.36, 1).Unit)
	camera.CFrame = CFrame.lookAt(self._centre + dir * self._reach, self._centre)
end

function Workshop:_startSpin()
	if self._spin then
		return
	end
	self._spin = RunService.RenderStepped:Connect(function(dt)
		if not self._dragging then
			self._yaw += dt * 0.35
		end
		self:_placeCamera()
	end)
end

function Workshop:_stopSpin()
	if self._spin then
		self._spin:Disconnect()
		self._spin = nil
	end
end

-- ---------------------------------------------------------------- weapon --

function Workshop:_selectWeapon(name: string)
	local changed = self._weapon ~= name
	self._weapon = name
	if changed then
		self._selected = nil
		self._yaw = 0
		self._builds = {}
		self._equippedId = nil
	end

	local cfg = WeaponConfig.Get(name)
	local rarity = Theme.RarityColour(cfg and cfg.Rarity)
	self._weaponName.Text = name
	self._weaponName.TextColor3 = Theme.Shade(rarity, 0.6)
	for _, child in ipairs(self._weaponChips:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if cfg then
		Components.Chip(self._weaponChips, cfg.Rarity or "Common", Theme.Shade(rarity, -0.2), { layoutOrder = 1 })
		Components.Chip(self._weaponChips, cfg.Class or "Gun", Theme.Colour.PanelRaised, { layoutOrder = 2 })
		Components.Chip(self._weaponChips, cfg.Automatic and "Auto" or "Semi", Theme.Colour.PanelRaised, { layoutOrder = 3 })
	end

	for _, row in ipairs(self._rows) do
		if row.SetSelected then
			row.SetSelected(row.name == name)
		end
	end

	self:_renderStage(name, nil)
	self:_refreshStats()
	self:_fillEditor()
	self:_refreshAction()

	if self:_owns("OwnedItems", name) then
		self:_loadBuilds()
	else
		self:_fillBuilds()
	end
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
		if weapon ~= self._weapon then
			return
		end
		if ok and type(response) == "table" and response.ok then
			self._builds = response.builds or {}
			self._equippedId = response.equipped
		else
			self._builds = {}
			self._equippedId = nil
		end
		-- Keep editing the same build across a reload, if it still exists.
		if self._selected then
			local found = nil
			for _, build in ipairs(self._builds) do
				if build.id == self._selected.id then
					found = build
				end
			end
			self._selected = found
		end
		if self._selected == nil and self._builds[1] then
			self._selected = self._builds[1]
		end
		self:_fillBuilds()
		self:_renderStage(weapon, self._selected and self._selected.attachments or nil)
		self:_refreshStats()
		self:_fillEditor()
		self:_refreshAction()
	end)
end

-- ---------------------------------------------------------------- builds --

function Workshop:_buildCard(build, label: string, order: number)
	local isEquipped = (build == nil and self._equippedId == nil) or (build ~= nil and self._equippedId == build.id)
	local isSelected = (build == nil and self._selected == nil) or (build ~= nil and self._selected == build)

	local card = Instance.new("TextButton")
	card.Name = build and build.id or "Default"
	card.AutoButtonColor = false
	card.Text = ""
	card.BackgroundColor3 = isSelected and Color3.fromRGB(64, 120, 220) or Theme.Colour.PanelRaised
	card.Size = UDim2.fromOffset(128, 96)
	card.LayoutOrder = order
	card.Parent = self._buildsRow
	Components.Corner(card, 12)
	Components.Stroke(card, isSelected and WHITE or Theme.Colour.Outline, isSelected and 3 or 2)
	Components.Gradient(card)

	local holder = Instance.new("Frame")
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, -10, 0, 46)
	holder.Position = UDim2.fromOffset(5, 6)
	holder.Parent = card
	pcall(function()
		WeaponPreview.Icon(holder, self._weapon or "", { Zoom = 1.2 })
	end)

	local fitted = 0
	for _ in pairs(build and build.attachments or {}) do
		fitted += 1
	end

	local title = Components.Label(card, {
		text = label,
		font = Theme.Font.Bold,
		size = 17,
		align = Enum.TextXAlignment.Center,
	})
	title.Size = UDim2.new(1, -8, 0, 20)
	title.Position = UDim2.new(0, 4, 1, -40)
	title.TextTruncate = Enum.TextTruncate.AtEnd

	local detail = Components.Label(card, {
		text = build and string.format("%d fitted", fitted) or "As issued",
		font = Theme.Font.Bold,
		size = Theme.Text.Micro,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
	})
	detail.Size = UDim2.new(1, -8, 0, 14)
	detail.Position = UDim2.new(0, 4, 1, -20)

	if isEquipped then
		local chip = Components.Chip(card, "✓ ON", Theme.Colour.AccentDim)
		chip.Position = UDim2.fromOffset(6, 6)
		chip.ZIndex = 3
	end

	local remove = nil
	if build then
		remove = Instance.new("TextButton")
		remove.Name = "Delete"
		remove.AutoButtonColor = false
		remove.Text = "✕"
		remove.Font = Theme.Font.Display
		remove.TextSize = 13
		remove.TextColor3 = WHITE
		remove.BackgroundColor3 = Theme.Colour.Danger
		remove.AnchorPoint = Vector2.new(1, 0)
		remove.Position = UDim2.new(1, -5, 0, 5)
		remove.Size = UDim2.fromOffset(20, 20)
		remove.ZIndex = 3
		remove.Parent = card
		Components.Corner(remove, 10)
		Components.Stroke(remove, Theme.Colour.Outline, 1.5)
	end

	local connections = {
		card.Activated:Connect(function()
			self._selected = build
			self:_fillBuilds()
			self:_renderStage(self._weapon :: string, build and build.attachments or nil)
			self:_refreshStats()
			self:_fillEditor()
			self:_refreshAction()
		end),
	}
	if remove then
		table.insert(connections, remove.Activated:Connect(function()
			self:_deleteBuild(build)
		end))
	end

	table.insert(self._buildCards, {
		Destroy = function()
			for _, c in ipairs(connections) do
				c:Disconnect()
			end
			card:Destroy()
		end,
	})
end

function Workshop:_fillBuilds()
	for _, card in ipairs(self._buildCards) do
		card.Destroy()
	end
	table.clear(self._buildCards)

	local weapon = self._weapon
	if not weapon or not self:_owns("OwnedItems", weapon) then
		self._status.Text = "🔒 Unlock this gun in the shop to build it out"
		return
	end

	self:_buildCard(nil, "DEFAULT", 0)
	for index, build in ipairs(self._builds) do
		self:_buildCard(build, build.name or string.format("BUILD %02d", index), index)
	end

	-- The "+" card makes a new build.
	if #self._builds < MAX_BUILDS then
		local add = Instance.new("TextButton")
		add.Name = "New"
		add.AutoButtonColor = false
		add.Text = "+"
		add.Font = Theme.Font.Display
		add.TextSize = 40
		add.TextColor3 = WHITE
		add.BackgroundColor3 = Theme.Colour.Accent
		add.Size = UDim2.fromOffset(96, 96)
		add.LayoutOrder = 999
		add.Parent = self._buildsRow
		Components.Corner(add, 12)
		Components.Stroke(add, Theme.Colour.Outline, 2)
		Components.Gradient(add)
		Components.Outline(add, 2.4)
		local conn = add.Activated:Connect(function()
			self:_createBuild()
		end)
		table.insert(self._buildCards, {
			Destroy = function()
				conn:Disconnect()
				add:Destroy()
			end,
		})
	end

	self._status.Text = string.format("%d / %d builds saved", #self._builds, MAX_BUILDS)
end

-- ----------------------------------------------------------------- stats --

function Workshop:_refreshStats()
	for _, child in ipairs(self._stats:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local weapon = self._weapon
	local base = weapon and WeaponConfig.Get(weapon)
	if not base then
		return
	end
	local build = self._selected
	local modified = build and WeaponConfig.WithAttachments(base, build.attachments) or base

	local before = statLines(base)
	local after = statLines(modified)
	for i, line in ipairs(after) do
		local row = Instance.new("Frame")
		row.Name = line[1]
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, 24)
		row.LayoutOrder = i
		row.Parent = self._stats

		local name = Components.Label(row, {
			text = line[1],
			font = Theme.Font.Bold,
			size = Theme.Text.Body,
			align = Enum.TextXAlignment.Right,
		})
		name.Size = UDim2.new(0.32, 0, 1, 0)

		local track = Instance.new("Frame")
		track.BackgroundColor3 = Color3.fromRGB(92, 96, 108)
		track.BackgroundTransparency = 0.25
		track.BorderSizePixel = 0
		track.AnchorPoint = Vector2.new(0, 0.5)
		track.Position = UDim2.new(0.35, 0, 0.5, 0)
		track.Size = UDim2.new(0.5, 0, 0, 16)
		track.Parent = row
		Components.Corner(track, 3)
		local fill = Instance.new("Frame")
		fill.BackgroundColor3 = WHITE
		fill.BorderSizePixel = 0
		fill.Size = UDim2.fromScale(math.clamp(before[i][2] / 100, 0.02, 1), 1)
		fill.Parent = track
		Components.Corner(fill, 3)
		TweenService:Create(fill, Theme.Tween.Value, { Size = UDim2.fromScale(math.clamp(line[2] / 100, 0.02, 1), 1) }):Play()
		local value = Instance.new("TextLabel")
		value.BackgroundTransparency = 1
		value.Size = UDim2.fromScale(1, 1)
		value.Font = Theme.Font.Bold
		value.TextSize = 13
		value.TextColor3 = Theme.Colour.Outline
		value.Text = line[3]
		value.ZIndex = 2
		value.Parent = track
		Components.Outline(value, 1.1, WHITE, 0.35)

		-- The delta, coloured by whether it is actually better.
		local delta = line[4] - before[i][4]
		if math.abs(delta) > 0.05 then
			local d = Components.Label(row, {
				text = string.format("%s%s", delta > 0 and "▲" or "▼", string.format(math.abs(delta) >= 10 and "%d" or "%.1f", math.abs(delta))),
				font = Theme.Font.Bold,
				size = Theme.Text.Small,
				colour = delta > 0 and GOOD or BAD,
			})
			d.Size = UDim2.new(0.14, 0, 1, 0)
			d.Position = UDim2.new(0.86, 0, 0, 0)
		end
	end
end

-- ---------------------------------------------------------------- editor --

function Workshop:_fillEditor()
	for _, child in ipairs(self._editor:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	local weapon = self._weapon
	local build = self._selected
	if not weapon or not self:_owns("OwnedItems", weapon) then
		local hint = Components.Label(self._editor, {
			text = "Unlock this gun to fit attachments.",
			font = Theme.Font.Bold,
			size = Theme.Text.Body,
			colour = Theme.Colour.TextMuted,
			wrap = true,
			layoutOrder = 1,
		})
		hint.Size = UDim2.new(1, 0, 0, 40)
		return
	end
	if not build then
		local hint = Components.Label(self._editor, {
			text = "The default build is the gun as issued. Press + under the gun to start a build and fit attachments.",
			font = Theme.Font.Bold,
			size = Theme.Text.Body,
			colour = Theme.Colour.TextMuted,
			wrap = true,
			layoutOrder = 1,
		})
		hint.Size = UDim2.new(1, 0, 0, 64)
		return
	end

	local order = 0
	local CHIP = Vector2.new(84, 28)
	for _, slot in ipairs(AttachmentConfig.Slots) do
		local options = AttachmentConfig.Options[slot] or {}
		if #options == 0 then
			continue
		end

		order += 1
		local label = Components.Label(self._editor, {
			text = string.format("%s  %s", SLOT_ICON[slot] or "🔧", AttachmentConfig.SlotLabels[slot] or slot),
			font = Theme.Font.Bold,
			size = Theme.Text.Body,
			colour = Theme.Colour.TextDim,
			layoutOrder = order,
		})
		label.Size = UDim2.new(1, 0, 0, 20)

		order += 1
		local grid = Instance.new("Frame")
		grid.Name = slot
		grid.BackgroundTransparency = 1
		grid.Size = UDim2.new(1, 0, 0, math.ceil(#options / 3) * (CHIP.Y + 4))
		grid.LayoutOrder = order
		grid.Parent = self._editor
		Components.Grid(grid, CHIP, 4)

		local fitted = (build.attachments or {})[slot]
		for index, option in ipairs(options) do
			local stock = AttachmentConfig.IsStock(slot, option.id)
			local key = AttachmentConfig.Key(slot, option.id)
			local owned = stock or self:_owns("OwnedAttachments", key)
			local on = (fitted == option.id) or (fitted == nil and stock)

			local chip = Components.Button(grid, {
				name = option.id,
				text = owned and option.name or ("🔒 " .. option.name),
				layoutOrder = index,
				size = UDim2.fromOffset(CHIP.X, CHIP.Y),
				textSize = Theme.Text.Small,
				onActivated = function()
					if not owned then
						self._status.Text = "🔒 Buy " .. option.name .. " in the shop first"
						return
					end
					build.attachments = build.attachments or {}
					build.attachments[slot] = (not stock) and option.id or nil
					-- Instant preview; the save below makes it real (or not).
					self:_renderStage(weapon, build.attachments)
					self:_refreshStats()
					self:_save()
				end,
			})
			chip.instance.TextTruncate = Enum.TextTruncate.AtEnd
			if not owned then
				chip.instance.TextColor3 = Theme.Colour.TextMuted
			end
			chip:SetSelected(on)
		end
	end
end

-- --------------------------------------------------------------- actions --

function Workshop:_refreshAction()
	local weapon = self._weapon
	if not weapon then
		return
	end
	if not self:_owns("OwnedItems", weapon) then
		self._action:SetEnabled(self._onShop ~= nil)
		self._action:SetText("🛒 UNLOCK IN SHOP")
		return
	end
	local build = self._selected
	local equipped = (build == nil and self._equippedId == nil) or (build ~= nil and self._equippedId == build.id)
	self._action:SetEnabled(not equipped)
	self._action:SetText(equipped and "✓ EQUIPPED" or "EQUIP BUILD")
end

function Workshop:_primaryAction()
	local weapon = self._weapon
	if not weapon then
		return
	end
	if not self:_owns("OwnedItems", weapon) then
		if self._onShop then
			self._onShop()
		end
		return
	end
	self:_equipBuild(self._selected)
end

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
		-- Reload rather than trusting the local edit: the server drops anything unowned.
		self:_loadBuilds()
	end)
end

function Workshop:_createBuild()
	local weapon = self._weapon
	if not weapon then
		return
	end
	self._status.Text = "Creating build..."
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
	self._action:SetText("...")
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

--- Where "unlock in shop" goes; the controller owns which panel that is.
function Workshop:OnShop(handler: () -> ())
	self._onShop = handler
end

function Workshop:Toggle()
	self._menu:Toggle()
end

function Workshop:Close()
	self._menu:Close()
end

function Workshop:Destroy()
	self:_stopSpin()
	for _, row in ipairs(self._rows) do
		row.Destroy()
	end
	for _, card in ipairs(self._buildCards) do
		card.Destroy()
	end
	self._action:Destroy()
	self._menu:Destroy()
end

return Workshop
