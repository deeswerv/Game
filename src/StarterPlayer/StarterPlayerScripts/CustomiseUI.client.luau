--!strict
-- Owner-only weapon customisation.
--
-- The whole screen is built only after the server confirms the viewer is the owner, and
-- every save is checked again on the server -- hiding the GUI is a convenience, not the
-- security. Opens with F2.
--
-- Not F3: Roblox reserves that for its own performance stats overlay, so the game never
-- receives the key at all.
--
-- The preview is the weapon's real model, dragged to rotate, so what is being painted is
-- the thing that ends up in people's hands.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
local CamoConfig = require(ReplicatedStorage:WaitForChild("CamoConfig"))
local AttachmentConfig = require(ReplicatedStorage:WaitForChild("AttachmentConfig"))
local AttachmentBuilder = require(ReplicatedStorage:WaitForChild("AttachmentBuilder"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local UIState = require(game:GetService("ReplicatedStorage"):WaitForChild("UIState"))
local Theme = UIKit.Theme

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local CustomiseAction = Remotes:WaitForChild("CustomiseAction") :: RemoteFunction
local BuildAction = Remotes:WaitForChild("BuildAction") :: RemoteFunction
local storeitems = ReplicatedStorage:WaitForChild("storeitems")

local player = Players.LocalPlayer

-- The workshop is now where everyone builds their weapons, so it opens for all players.
-- The owner keeps one extra thing on top: the per-part colour and material pass, which
-- sets the game-wide look of a weapon rather than one player's build. That stays gated,
-- and the server checks again on every save -- hiding the controls is convenience only.
local ownerOk, ownerResult = pcall(function()
	return CustomiseAction:InvokeServer("authorised")
end)
local ownerAuthorised = ownerOk and ownerResult == true

local MATERIALS = {
	"SmoothPlastic", "Plastic", "Metal", "DiamondPlate", "Neon",
	"Wood", "WoodPlanks", "Marble", "Slate", "CorrodedMetal", "Glass", "Foil",
}

-- A small spread of useful colours; the owner picks from these rather than typing RGB.
local SWATCHES = {
	{ 28, 30, 36 }, { 74, 78, 88 }, { 140, 146, 158 }, { 226, 230, 236 },
	{ 122, 74, 42 }, { 186, 122, 54 }, { 240, 178, 60 }, { 236, 226, 190 },
	{ 138, 42, 42 }, { 214, 74, 62 }, { 92, 140, 74 }, { 74, 156, 122 },
	{ 58, 96, 158 }, { 96, 132, 216 }, { 122, 82, 176 }, { 196, 96, 178 },
}

local gui = Instance.new("ScreenGui")
gui.Name = "CustomiseUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 12
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local panel = UIKit.frame({
	Name = "Panel",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(900, 580),
	BackgroundColor3 = Theme.Background,
	Parent = gui,
})
panel.ZIndex = 2
UIKit.corner(panel, UDim.new(0, 14))
UIKit.stroke(panel, Theme.StrokeLight, 1, 0.55)
UIKit.shadow(panel, 16)

-- Laid out at a fixed size and scaled to fit, from the shared helper -- the market and
-- the inventory now do the same, so all three behave identically when the window changes.
UIKit.fitToScreen(panel, 900, 580)

local header = UIKit.frame({
	Size = UDim2.new(1, 0, 0, 52),
	BackgroundColor3 = Theme.Panel,
	ZIndex = 3,
	Parent = panel,
})
UIKit.corner(header, UDim.new(0, 14))

UIKit.label({
	Position = UDim2.fromOffset(20, 0),
	Size = UDim2.new(0, 420, 1, 0),
	Text = "WEAPON WORKSHOP  [F2]",
	Font = Theme.FontBold,
	TextColor3 = Theme.Accent,
	TextSize = 20,
	Parent = header,
})

local status = UIKit.label({
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -62, 0, 0),
	Size = UDim2.fromOffset(360, 52),
	Text = ownerAuthorised and "Owner tools enabled" or "",
	TextColor3 = Theme.TextDim,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Right,
	Parent = header,
})

local closeBtn = UIKit.button({
	AnchorPoint = Vector2.new(1, 0.5),
	Position = UDim2.new(1, -14, 0.5, 0),
	Size = UDim2.fromOffset(32, 32),
	Text = "X",
	TextSize = 15,
	Parent = header,
})
UIKit.corner(closeBtn, UDim.new(0, 8))

-- ------------------------------------------------------------ weapon list --

local list = Instance.new("ScrollingFrame")
list.Position = UDim2.fromOffset(14, 64)
list.Size = UDim2.fromOffset(150, 502)
list.BackgroundColor3 = Theme.Panel
list.BorderSizePixel = 0
list.ScrollBarThickness = 3
list.CanvasSize = UDim2.new()
list.AutomaticCanvasSize = Enum.AutomaticSize.Y
list.Parent = panel
UIKit.corner(list, UDim.new(0, 10))
UIKit.pad(list, 8)

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 5)
listLayout.SortOrder = Enum.SortOrder.LayoutOrder
listLayout.Parent = list

-- --------------------------------------------------------------- preview --

local stage = UIKit.frame({
	Name = "Stage",
	Position = UDim2.fromOffset(176, 64),
	-- Forty pixels shorter than it was, to make room for the two stats the comparison
	-- panel gained. The preview is still the biggest thing on the screen.
	Size = UDim2.fromOffset(380, 252),
	BackgroundColor3 = Color3.fromRGB(18, 19, 24),
	Parent = panel,
})
UIKit.corner(stage, UDim.new(0, 10))
UIKit.stroke(stage, Theme.Stroke, 1, 0.4)

local viewport = Instance.new("ViewportFrame")
viewport.Size = UDim2.fromScale(1, 1)
viewport.BackgroundTransparency = 1
viewport.Ambient = Color3.fromRGB(150, 154, 168)
viewport.LightColor = Color3.fromRGB(255, 250, 238)
viewport.LightDirection = Vector3.new(-0.4, -1, -0.5)
viewport.Parent = stage

UIKit.label({
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -6),
	Size = UDim2.new(1, 0, 0, 14),
	Text = "drag to rotate  \u{00B7}  scroll to zoom",
	TextSize = 10,
	TextColor3 = Theme.TextDim,
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = stage,
})

-- ---------------------------------------------------------------- editors --

-- Attachment slots, one card each, laid out like a workbench.
-- Three editors share the right-hand column, one visible at a time.
local tabBar = UIKit.frame({
	Name = "Tabs",
	Position = UDim2.fromOffset(568, 64),
	Size = UDim2.fromOffset(318, 28),
	BackgroundTransparency = 1,
	Parent = panel,
})
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 6)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabBar

local function editorPanel(name: string)
	local frame = Instance.new("ScrollingFrame")
	frame.Name = name
	frame.Position = UDim2.fromOffset(568, 98)
	frame.Size = UDim2.fromOffset(318, 398)
	frame.BackgroundColor3 = Theme.Panel
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 3
	frame.CanvasSize = UDim2.new()
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.Visible = false
	frame.Parent = panel
	UIKit.corner(frame, UDim.new(0, 10))
	UIKit.pad(frame, 8)
	return frame
end

local slotGrid = editorPanel("Slots")
slotGrid.Visible = true
local camoGrid = editorPanel("Camos")
local buildList = editorPanel("Builds")

local slotLayout = Instance.new("UIListLayout")
slotLayout.Padding = UDim.new(0, 5)
slotLayout.SortOrder = Enum.SortOrder.LayoutOrder
slotLayout.Parent = slotGrid

local camoLayout = Instance.new("UIGridLayout")
camoLayout.CellSize = UDim2.fromOffset(96, 62)
camoLayout.CellPadding = UDim2.fromOffset(6, 6)
camoLayout.SortOrder = Enum.SortOrder.LayoutOrder
camoLayout.Parent = camoGrid

local buildLayout = Instance.new("UIListLayout")
buildLayout.Padding = UDim.new(0, 5)
buildLayout.SortOrder = Enum.SortOrder.LayoutOrder
buildLayout.Parent = buildList

-- Stat bars, under the preview. Filled in when a weapon is selected.
local statPanel = UIKit.frame({
	Name = "Stats",
	Position = UDim2.fromOffset(176, 324),
	Size = UDim2.fromOffset(380, 172),
	BackgroundColor3 = Theme.Panel,
	Parent = panel,
})
UIKit.corner(statPanel, UDim.new(0, 10))
UIKit.pad(statPanel, 8)

local statLayout = Instance.new("UIListLayout")
statLayout.Padding = UDim.new(0, 2)
statLayout.SortOrder = Enum.SortOrder.LayoutOrder
statLayout.Parent = statPanel

local partList = Instance.new("ScrollingFrame")
partList.Position = UDim2.fromOffset(176, 504)
partList.Size = UDim2.fromOffset(150, 62)
partList.BackgroundColor3 = Theme.Panel
partList.BorderSizePixel = 0
partList.ScrollBarThickness = 3
partList.CanvasSize = UDim2.new()
partList.AutomaticCanvasSize = Enum.AutomaticSize.Y
partList.Parent = panel
UIKit.corner(partList, UDim.new(0, 10))
UIKit.pad(partList, 8)

local partLayout = Instance.new("UIListLayout")
partLayout.Padding = UDim.new(0, 4)
partLayout.SortOrder = Enum.SortOrder.LayoutOrder
partLayout.Parent = partList

local palette = UIKit.frame({
	Name = "Palette",
	Position = UDim2.fromOffset(336, 504),
	Size = UDim2.fromOffset(220, 62),
	BackgroundColor3 = Theme.Panel,
	Parent = panel,
})
UIKit.corner(palette, UDim.new(0, 10))
UIKit.pad(palette, 8)

local paletteLayout = Instance.new("UIGridLayout")
paletteLayout.CellSize = UDim2.fromOffset(34, 26)
paletteLayout.CellPadding = UDim2.fromOffset(5, 5)
paletteLayout.Parent = palette

local saveBtn = UIKit.button({
	Position = UDim2.fromOffset(568, 506),
	Size = UDim2.fromOffset(154, 40),
	Text = "Save Build",
	Font = Theme.FontBold,
	TextSize = 15,
	BackgroundColor3 = Theme.Accent,
	TextColor3 = Color3.fromRGB(20, 18, 12),
	Parent = panel,
})
UIKit.corner(saveBtn, UDim.new(0, 8))

local resetBtn = UIKit.button({
	Position = UDim2.fromOffset(732, 506),
	Size = UDim2.fromOffset(154, 40),
	Text = "Reset",
	TextSize = 14,
	Parent = panel,
})
UIKit.corner(resetBtn, UDim.new(0, 8))

-- ------------------------------------------------------------------ state --

local selectedWeapon: string? = nil
local selectedPart: string? = nil
local selectedCamo: string? = nil        -- what the preview is showing
local loadedBuildId: string? = nil       -- which saved build is open for editing, if any
local equippedBuildId: string? = nil
local isOwner = ownerAuthorised
local pending: { [string]: any } = {}       -- unsaved colour edits for the current weapon
local loadout: { [string]: string } = {}    -- unsaved attachment choices
-- What the build looked like when it was opened. The stat panel compares the two, so the
-- player can see what a change would cost BEFORE saving it -- which is the whole point of
-- previewing rather than editing in place.
local baseline: { [string]: string } = {}
local previewParts: { [string]: BasePart } = {}
local previewTool: Instance? = nil          -- the cloned model the preview is built from
local yaw, pitch, zoom = 0.6, 0.25, 1.5
local modelCentre, modelSpan = Vector3.zero, 4

local function frameCamera()
	local camera = viewport.CurrentCamera
	if not camera then
		return
	end
	local dir = CFrame.Angles(0, yaw, 0) * CFrame.Angles(pitch, 0, 0)
	camera.CFrame = CFrame.lookAt(modelCentre + dir * Vector3.new(0, 0, modelSpan * zoom), modelCentre)
end

local function buildPreview(weaponName: string)
	viewport:ClearAllChildren()
	table.clear(previewParts)

	local template = storeitems:FindFirstChild(weaponName)
	if not template then
		return
	end

	-- A working copy of the weapon, with the chosen attachments fitted by the same builder
	-- the server uses. The preview is therefore the real thing, not an impression of it.
	if previewTool then
		previewTool:Destroy()
	end
	previewTool = template:Clone()
	local working = previewTool :: Instance
	for _, d in ipairs(working:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		elseif d:IsA("Sound") or d:IsA("Light") then
			d:Destroy()
		end
	end
	AttachmentBuilder.Apply(working, loadout)

	local model = Instance.new("Model")
	for _, part in ipairs(working:GetDescendants()) do
		if part:IsA("BasePart") then
			local copy = part:Clone()
			for _, child in ipairs(copy:GetChildren()) do
				child:Destroy()
			end
			copy.Anchored = true
			copy.CanCollide = false
			copy.Parent = model
			-- Only the weapon's own parts are colourable; attachment parts carry their own
			-- colours and are named for their slot.
			if not part:IsDescendantOf(working:FindFirstChild("Attachments") or working) then
				previewParts[part.Name] = copy
			end
		end
	end
	model.Parent = viewport

	local cf, size = model:GetBoundingBox()
	modelCentre = cf.Position
	modelSpan = math.max(size.X, size.Y, size.Z) + 0.6

	local camera = Instance.new("Camera")
	camera.FieldOfView = 32
	camera.Parent = viewport
	viewport.CurrentCamera = camera
	frameCamera()
end

-- Paint the preview from the pending edits, so changes are visible before saving.
local function repaintPreview()
	for partName, entry in pairs(pending) do
		local part = previewParts[partName]
		if part then
			if entry.Colour then
				part.Color = Color3.fromRGB(entry.Colour[1], entry.Colour[2], entry.Colour[3])
			end
			if entry.Material then
				part.Material = (Enum.Material :: any)[entry.Material]
			end
		end
	end
end

local buildPartList        -- forward declaration

local function selectPart(name: string)
	selectedPart = name
	buildPartList()
end

function buildPartList()
	for _, child in ipairs(partList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not selectedWeapon then
		return
	end

	local names = {}
	for name in pairs(previewParts) do
		table.insert(names, name)
	end
	table.sort(names)

	for i, name in ipairs(names) do
		local active = name == selectedPart
		local row = UIKit.button({
			Name = name,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 26),
			Text = "",
			BackgroundColor3 = active and Theme.PanelLight or Theme.Background,
			Parent = partList,
		})
		UIKit.corner(row, UDim.new(0, 6))

		local swatch = Instance.new("Frame")
		swatch.Position = UDim2.fromOffset(6, 5)
		swatch.Size = UDim2.fromOffset(16, 16)
		swatch.BackgroundColor3 = previewParts[name].Color
		swatch.BorderSizePixel = 0
		swatch.Parent = row
		UIKit.corner(swatch, UDim.new(0, 4))

		UIKit.label({
			Position = UDim2.fromOffset(30, 0),
			Size = UDim2.new(1, -36, 1, 0),
			Text = name,
			TextSize = 12,
			TextColor3 = active and Theme.Text or Theme.TextDim,
			Parent = row,
		})

		row.MouseButton1Click:Connect(function()
			selectPart(name)
		end)
	end
end

local function edit(partName: string, key: string, value)
	pending[partName] = pending[partName] or {}
	pending[partName][key] = value
	repaintPreview()
	buildPartList()
end

-- ---------------------------------------------------------- attachment slots --

-- Forward declarations. refreshStats is declared up here rather than beside the camo
-- grid because cycleSlot below calls it, and a local declared later is not the same
-- variable -- it would silently be a nil global at this point.
local buildSlots, refreshStats

-- Step a slot to the next or previous option and rebuild the preview so the change is
-- visible immediately.
local function cycleSlot(slot: string, direction: number)
	local options = AttachmentConfig.Options[slot]
	if not options or #options == 0 or not selectedWeapon then
		return
	end
	local current = loadout[slot] or AttachmentConfig.Default(slot)
	local index = 1
	for i, option in ipairs(options) do
		if option.id == current then
			index = i
			break
		end
	end
	index = ((index - 1 + direction) % #options) + 1
	loadout[slot] = options[index].id

	buildPreview(selectedWeapon)
	repaintPreview()
	buildSlots()
	buildPartList()
	-- The bars are the whole reason for previewing rather than editing in place, so they
	-- have to move the moment the choice does.
	refreshStats()
	status.Text = AttachmentConfig.SlotLabels[slot] .. ": " .. options[index].name
end

function buildSlots()
	for _, child in ipairs(slotGrid:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not selectedWeapon then
		return
	end

	-- Only the slots this weapon can actually take. A pump shotgun has no detachable
	-- magazine and a pistol has no stock, so offering those would be offering a choice
	-- that changes nothing. Decided from the weapon's own parts rather than a per-weapon
	-- list, so a new gun needs no entry anywhere.
	local fitted = previewTool and storeitems:FindFirstChild(selectedWeapon)
	for i, slot in ipairs(AttachmentConfig.Slots) do
		if fitted and not AttachmentBuilder.Supports(previewTool, slot) then
			continue
		end
		local options = AttachmentConfig.Options[slot] or {}
		local current = loadout[slot] or AttachmentConfig.Default(slot)
		local index, option = 1, options[1]
		for n, entry in ipairs(options) do
			if entry.id == current then
				index, option = n, entry
				break
			end
		end

		local fitted = option and #option.parts > 0

		local card = UIKit.frame({
			Name = slot,
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 42),
			BackgroundColor3 = fitted and Theme.PanelLight or Theme.Background,
			Parent = slotGrid,
		})
		UIKit.corner(card, UDim.new(0, 7))
		if fitted then
			UIKit.stroke(card, Theme.Accent, 1, 0.55)
		end

		UIKit.label({
			Position = UDim2.fromOffset(9, 3),
			Size = UDim2.new(1, -18, 0, 15),
			Text = string.upper(AttachmentConfig.SlotLabels[slot] or slot),
			Font = Theme.FontBold,
			TextSize = 10,
			TextColor3 = fitted and Theme.Accent or Theme.TextDim,
			Parent = card,
		})

		UIKit.label({
			Name = "Value",
			Position = UDim2.fromOffset(34, 19),
			Size = UDim2.new(1, -68, 0, 18),
			Text = option and option.name or "-",
			TextSize = 12,
			TextColor3 = Theme.Text,
			TextXAlignment = Enum.TextXAlignment.Center,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Parent = card,
		})

		UIKit.label({
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -9, 0, 3),
			Size = UDim2.fromOffset(40, 15),
			Text = string.format("%d/%d", index, #options),
			TextSize = 10,
			TextColor3 = Theme.TextDim,
			TextXAlignment = Enum.TextXAlignment.Right,
			Parent = card,
		})

		for _, step in ipairs({ { "\u{25C0}", -1, 6 }, { "\u{25B6}", 1, -6 } }) do
			local arrow = UIKit.button({
				AnchorPoint = step[3] > 0 and Vector2.new(0, 0) or Vector2.new(1, 0),
				Position = step[3] > 0 and UDim2.fromOffset(6, 19) or UDim2.new(1, -6, 0, 19),
				Size = UDim2.fromOffset(22, 18),
				Text = step[1],
				TextSize = 10,
				Parent = card,
			})
			UIKit.corner(arrow, UDim.new(0, 4))
			local dir = step[2]
			arrow.MouseButton1Click:Connect(function()
				cycleSlot(slot, dir)
			end)
		end
	end
end

-- Colour swatches and material buttons, wired to whichever part is selected.
for i, rgb in ipairs(SWATCHES) do
	local b = UIKit.button({
		LayoutOrder = i,
		Text = "",
		BackgroundColor3 = Color3.fromRGB(rgb[1], rgb[2], rgb[3]),
		Parent = palette,
	})
	UIKit.corner(b, UDim.new(0, 5))
	b.MouseButton1Click:Connect(function()
		if selectedPart then
			edit(selectedPart, "Colour", { rgb[1], rgb[2], rgb[3] })
			status.Text = selectedPart .. " recoloured"
		else
			status.Text = "Pick a part first"
		end
	end)
end

for i, material in ipairs(MATERIALS) do
	local b = UIKit.button({
		LayoutOrder = #SWATCHES + i,
		Text = material:sub(1, 5),
		TextSize = 9,
		Parent = palette,
	})
	UIKit.corner(b, UDim.new(0, 5))
	b.MouseButton1Click:Connect(function()
		if selectedPart then
			edit(selectedPart, "Material", material)
			status.Text = selectedPart .. " \u{2192} " .. material
		else
			status.Text = "Pick a part first"
		end
	end)
end

-- ------------------------------------------------------------------- camos --

local buildCamoGrid, buildBuildList     -- forward declarations

-- Preview only. Nothing is written until Save Build, which is what keeps clicking
-- through the catalogue from quietly changing the weapon you already have.
local function pickCamo(id: string?)
	selectedCamo = id
	if selectedWeapon then
		buildPreview(selectedWeapon)
		repaintPreview()
	end
	buildCamoGrid()
	local camo = id and CamoConfig.Find(id)
	status.Text = camo and ("Preview: " .. camo.name) or "Preview: factory finish"
end

function buildCamoGrid()
	for _, child in ipairs(camoGrid:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	for i, camo in ipairs(CamoConfig.Camos) do
		local chosen = (selectedCamo == camo.id) or (selectedCamo == nil and camo.factory)
		local rarity = WeaponConfig.RarityColors[camo.rarity] or Theme.TextDim

		local card = UIKit.button({
			Name = camo.id,
			LayoutOrder = i,
			Text = "",
			BackgroundColor3 = chosen and Theme.PanelLight or Theme.Background,
			Parent = camoGrid,
		})
		UIKit.corner(card, UDim.new(0, 7))
		UIKit.stroke(card, chosen and Theme.Accent or rarity, chosen and 0 or 0.6)

		-- Three stripes standing in for the camo's own colours.
		if not camo.factory then
			for n, key in ipairs({ "primary", "secondary", "accent" }) do
				local swatch = UIKit.frame({
					Position = UDim2.fromOffset(8 + (n - 1) * 26, 8),
					Size = UDim2.fromOffset(24, 18),
					BackgroundColor3 = camo[key],
					Parent = card,
				})
				UIKit.corner(swatch, UDim.new(0, 4))
			end
		end

		UIKit.label({
			Position = UDim2.fromOffset(6, 28),
			Size = UDim2.new(1, -12, 0, 14),
			Text = camo.name,
			Font = Theme.FontBold,
			TextSize = 11,
			TextColor3 = chosen and Theme.Text or Theme.TextDim,
			Parent = card,
		})
		UIKit.label({
			Position = UDim2.fromOffset(6, 42),
			Size = UDim2.new(1, -12, 0, 12),
			Text = camo.reactive and "REACTIVE" or string.upper(camo.rarity),
			Font = Theme.FontBold,
			TextSize = 9,
			TextColor3 = camo.reactive and Theme.Accent or rarity,
			Parent = card,
		})

		card.MouseButton1Click:Connect(function()
			pickCamo(camo.factory and nil or camo.id)
		end)
	end
end

-- ------------------------------------------------------------------ builds --

local function refreshBuilds()
	if not selectedWeapon then
		return { builds = {}, max = 0 }
	end
	local response = BuildAction:InvokeServer("list", selectedWeapon)
	if type(response) == "table" and response.ok then
		equippedBuildId = response.equipped
		return response
	end
	return { builds = {}, max = 0 }
end

-- Load a saved build into the editor. Editing from here writes back to THIS build only.
local function openBuild(build)
	loadedBuildId = build and build.id or nil
	table.clear(loadout)
	table.clear(baseline)
	if build then
		for slot, id in pairs(build.attachments or {}) do
			loadout[slot] = id
			baseline[slot] = id
		end
		selectedCamo = build.camo
	else
		selectedCamo = nil
	end
	if selectedWeapon then
		buildPreview(selectedWeapon)
		repaintPreview()
	end
	buildSlots()
	buildCamoGrid()
	buildBuildList()
	refreshStats()
	status.Text = build and ("Editing " .. build.name) or "Editing the default weapon"
end

function buildBuildList()
	for _, child in ipairs(buildList:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	if not selectedWeapon then
		return
	end
	local data = refreshBuilds()

	local function row(order: number, title: string, subtitle: string, accent: Color3,
		active: boolean, onClick)
		local card = UIKit.frame({
			LayoutOrder = order,
			Size = UDim2.new(1, 0, 0, 46),
			BackgroundColor3 = active and Theme.PanelLight or Theme.Background,
			Parent = buildList,
		})
		UIKit.corner(card, UDim.new(0, 7))
		UIKit.stroke(card, accent, active and 0 or 0.65)
		UIKit.label({
			Position = UDim2.fromOffset(10, 5),
			Size = UDim2.new(1, -110, 0, 16),
			Text = title,
			Font = Theme.FontBold,
			TextSize = 12,
			TextColor3 = active and Theme.Text or Theme.TextDim,
			Parent = card,
		})
		UIKit.label({
			Position = UDim2.fromOffset(10, 23),
			Size = UDim2.new(1, -110, 0, 14),
			Text = subtitle,
			TextSize = 10,
			TextColor3 = Theme.TextDim,
			Parent = card,
		})
		local open = UIKit.button({
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -8, 0.5, 0),
			Size = UDim2.fromOffset(84, 30),
			Text = "",
			BackgroundTransparency = 1,
			Parent = card,
		})
		open.MouseButton1Click:Connect(onClick)
		return card
	end

	-- DEFAULT is always first, and is never a saved record -- it is the template itself.
	local defaultCard = row(1, "DEFAULT", equippedBuildId and "the untouched weapon" or "equipped",
		equippedBuildId and Theme.Stroke or Theme.Accent,
		loadedBuildId == nil, function()
			openBuild(nil)
		end)
	local equipDefault = UIKit.button({
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(60, 24),
		Text = equippedBuildId and "EQUIP" or "ON",
		TextSize = 10,
		Font = Theme.FontBold,
		Parent = defaultCard,
	})
	UIKit.corner(equipDefault, UDim.new(0, 5))
	equipDefault.MouseButton1Click:Connect(function()
		BuildAction:InvokeServer("equip", selectedWeapon, nil)
		status.Text = "Equipped the default " .. tostring(selectedWeapon)
		buildBuildList()
	end)

	for i, build in ipairs(data.builds or {}) do
		local live = equippedBuildId == build.id
		local count = 0
		for _ in pairs(build.attachments or {}) do
			count += 1
		end
		local camo = build.camo and CamoConfig.Find(build.camo)
		local card = row(i + 1, string.upper(build.name),
			string.format("%d attachment%s \u{00B7} %s", count, count == 1 and "" or "s",
				camo and camo.name or "factory"),
			live and Theme.Accent or Theme.Stroke,
			loadedBuildId == build.id, function()
				openBuild(build)
			end)

		local actions = { }
		table.insert(actions, { live and "ON" or "EQUIP", function()
			BuildAction:InvokeServer("equip", selectedWeapon, { id = build.id })
			status.Text = "Equipped " .. build.name
			buildBuildList()
		end })
		table.insert(actions, { "COPY", function()
			local res = BuildAction:InvokeServer("duplicate", selectedWeapon, { id = build.id })
			status.Text = res.ok and ("Copied " .. build.name) or tostring(res.reason)
			buildBuildList()
		end })
		table.insert(actions, { "DEL", function()
			local res = BuildAction:InvokeServer("delete", selectedWeapon, { id = build.id })
			if res.ok and loadedBuildId == build.id then
				openBuild(nil)
			end
			status.Text = res.ok and ("Deleted " .. build.name) or tostring(res.reason)
			buildBuildList()
		end })

		for n, action in ipairs(actions) do
			local b = UIKit.button({
				AnchorPoint = Vector2.new(1, 0.5),
				Position = UDim2.new(1, -8 - (n - 1) * 40, 0.5, 0),
				Size = UDim2.fromOffset(36, 24),
				Text = action[1],
				TextSize = 9,
				Font = Theme.FontBold,
				TextColor3 = action[1] == "DEL" and Theme.Danger or Theme.Text,
				Parent = card,
			})
			UIKit.corner(b, UDim.new(0, 5))
			if action[1] == "DEL" then
				-- Deleting a build was a single click with nothing between the player and
				-- losing a loadout they had spent coins assembling. Now it arms first and
				-- disarms itself after a couple of seconds if they meant something else.
				UIKit.confirm(b, "SURE?", Theme.Danger, action[2])
			else
				b.MouseButton1Click:Connect(action[2])
			end
		end
	end

	-- New build, from whatever is currently in the editor.
	local newBtn = UIKit.button({
		LayoutOrder = 999,
		Size = UDim2.new(1, 0, 0, 34),
		Text = string.format("+  NEW BUILD   (%d / %d)", #(data.builds or {}), data.max or 0),
		Font = Theme.FontBold,
		TextSize = 11,
		BackgroundColor3 = Theme.PanelLight,
		Parent = buildList,
	})
	UIKit.corner(newBtn, UDim.new(0, 7))
	newBtn.MouseButton1Click:Connect(function()
		local res = BuildAction:InvokeServer("create", selectedWeapon, {
			attachments = loadout, camo = selectedCamo,
		})
		if res.ok then
			loadedBuildId = res.build.id
			status.Text = "Created " .. res.build.name
		else
			status.Text = tostring(res.reason)
		end
		buildBuildList()
	end)
end

-- ------------------------------------------------------------------- stats --

-- Bars are drawn against a ceiling per stat so the lengths mean something across weapons.
--
-- The rows, the ceilings and which direction counts as better all come from
-- WeaponConfig.TunableStats -- the same table the server uses when it applies a build. So
-- these bars cannot drift from what the weapon actually does: they are computed with the
-- same function that computes the damage the bullets deal.
--
-- Each bar shows two things at once: where the SAVED build sits, and where the change
-- being previewed would put it. A gain is drawn in green past the current mark, a loss in
-- red back from it, so the cost of an attachment is visible before it is saved.
-- Quick enough not to be in the way, slow enough to be seen.
local GROW = TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function formatStat(row, value: number): string
	if row.decimals <= 0 then
		return tostring(math.floor(value + 0.5))
	end
	return string.format("%." .. row.decimals .. "f", value)
end

function refreshStats()
	for _, child in ipairs(statPanel:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local base = selectedWeapon and WeaponConfig.Get(selectedWeapon)
	if not base or base.Type ~= "Gun" then
		return
	end

	local saved = WeaponConfig.WithAttachments(base, baseline)
	local preview = WeaponConfig.WithAttachments(base, loadout)
	local anyChange = false

	for i, row in ipairs(WeaponConfig.TunableStats) do
		local current = saved[row.key]
		local wanted = preview[row.key]
		if type(current) == "number" and type(wanted) == "number" then
			local function goodness(v: number): number
				local f = math.clamp(v / row.ceiling, 0, 1)
				return row.higherIsBetter and f or (1 - f)
			end
			local currentFill, wantedFill = goodness(current), goodness(wanted)
			local changed = math.abs(wanted - current) > 1e-6
			local better = wantedFill > currentFill
			if changed then
				anyChange = true
			end

			local line = UIKit.frame({
				LayoutOrder = i,
				Size = UDim2.new(1, 0, 0, 15),
				BackgroundTransparency = 1,
				Parent = statPanel,
			})
			UIKit.label({
				Size = UDim2.fromOffset(70, 15),
				Text = row.label,
				TextSize = 10,
				TextColor3 = Theme.TextDim,
				Parent = line,
			})

			local track = UIKit.frame({
				Position = UDim2.fromOffset(74, 4),
				Size = UDim2.fromOffset(184, 7),
				BackgroundColor3 = Theme.Background,
				Parent = line,
			})
			UIKit.corner(track, UDim.new(0, 3))

			-- The part both builds share, then the difference on top of it. Both grow into
			-- place rather than appearing at full length -- the rows are rebuilt on every
			-- change, so without this a swapped attachment makes the whole panel jump.
			local shared = math.min(currentFill, wantedFill)
			local fill = UIKit.frame({
				Size = UDim2.fromScale(0, 1),
				BackgroundColor3 = Theme.Accent,
				Parent = track,
			})
			UIKit.corner(fill, UDim.new(0, 3))
			TweenService:Create(fill, GROW, { Size = UDim2.fromScale(shared, 1) }):Play()

			if changed then
				local diff = UIKit.frame({
					Position = UDim2.fromScale(shared, 0),
					Size = UDim2.fromScale(0, 1),
					BackgroundColor3 = better and Theme.Success or Theme.Danger,
					Parent = track,
				})
				UIKit.corner(diff, UDim.new(0, 3))
				TweenService:Create(diff, GROW, {
					Size = UDim2.fromScale(math.abs(wantedFill - currentFill), 1),
				}):Play()
			end

			UIKit.label({
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.new(1, 0, 0, 0),
				Size = UDim2.fromOffset(84, 15),
				Text = changed
					and string.format("%s \u{2192} %s", formatStat(row, current), formatStat(row, wanted))
					or formatStat(row, current),
				Font = Theme.FontBold,
				TextSize = 10,
				TextColor3 = changed and (better and Theme.Success or Theme.Danger) or Theme.Text,
				TextXAlignment = Enum.TextXAlignment.Right,
				Parent = line,
			})
		end
	end

	-- Say plainly whether what is on screen is saved or not. "Preview" and "equipped"
	-- looking identical is how a player ends up thinking they saved something they did not.
	UIKit.label({
		LayoutOrder = 100,
		Size = UDim2.new(1, 0, 0, 14),
		Text = anyChange and "PREVIEW  \u{00B7}  unsaved changes" or "CURRENT BUILD",
		Font = Theme.FontBold,
		TextSize = 9,
		TextColor3 = anyChange and Theme.Accent or Theme.TextDim,
		Parent = statPanel,
	})
end

-- -------------------------------------------------------------------- tabs --

local tabs = {
	{ "ATTACHMENTS", slotGrid },
	{ "CAMO", camoGrid },
	{ "BUILDS", buildList },
}
local tabButtons = {}

local function showTab(index: number)
	for i, entry in ipairs(tabs) do
		entry[2].Visible = (i == index)
		local button = tabButtons[i]
		if button then
			button.BackgroundColor3 = (i == index) and Theme.Accent or Theme.Panel
			button.TextColor3 = (i == index) and Color3.fromRGB(20, 18, 12) or Theme.TextDim
		end
	end
end

for i, entry in ipairs(tabs) do
	local button = UIKit.button({
		LayoutOrder = i,
		Size = UDim2.fromOffset(102, 28),
		Text = entry[1],
		Font = Theme.FontBold,
		TextSize = 10,
		Parent = tabBar,
	})
	UIKit.corner(button, UDim.new(0, 7))
	tabButtons[i] = button
	button.MouseButton1Click:Connect(function()
		showTab(i)
	end)
end
showTab(1)

-- ----------------------------------------------------------- weapon picking --

local function selectWeapon(name: string)
	selectedWeapon = name
	selectedPart = nil
	table.clear(pending)

	table.clear(loadout)

	local response = CustomiseAction:InvokeServer("describe", name)
	if type(response) == "table" and response.ok then
		if type(response.attachments) == "table" then
			for slot, id in pairs(response.attachments) do
				loadout[slot] = id
			end
		end
		if type(response.skin) == "table" then
			for partName, entry in pairs(response.skin) do
				pending[partName] = { Colour = entry.Colour, Material = entry.Material }
			end
		end
	end

	-- Open whichever build is live for this weapon, so the screen shows what you carry.
	local listing = BuildAction:InvokeServer("list", name)
	local live = nil
	if type(listing) == "table" and listing.ok then
		equippedBuildId = listing.equipped
		for _, build in ipairs(listing.builds or {}) do
			if build.id == listing.equipped then
				live = build
			end
		end
	end
	openBuild(live)
	buildPartList()
	status.Text = name .. (live and ("  \u{00B7}  " .. live.name) or "  \u{00B7}  DEFAULT")
end

do
	local names = {}
	for name in pairs(WeaponConfig.Weapons) do
		if storeitems:FindFirstChild(name) then
			table.insert(names, name)
		end
	end
	table.sort(names)
	for i, name in ipairs(names) do
		local cfg = WeaponConfig.Get(name)
		local b = UIKit.button({
			LayoutOrder = i,
			Size = UDim2.new(1, 0, 0, 30),
			Text = name,
			TextSize = 12,
			TextColor3 = WeaponConfig.RarityColors[cfg.Rarity] or Theme.Text,
			Parent = list,
		})
		UIKit.corner(b, UDim.new(0, 6))
		b.MouseButton1Click:Connect(function()
			selectWeapon(name)
		end)
	end
end

-- ------------------------------------------------------------- interaction --

local dragging = false
local lastPos = Vector2.zero
stage.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		lastPos = Vector2.new(input.Position.X, input.Position.Y)
	end
end)
stage.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if not gui.Enabled then
		return
	end
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement
		or input.UserInputType == Enum.UserInputType.Touch) then
		local pos = Vector2.new(input.Position.X, input.Position.Y)
		local delta = pos - lastPos
		lastPos = pos
		yaw -= delta.X * 0.01
		pitch = math.clamp(pitch - delta.Y * 0.01, -1.2, 1.2)
		frameCamera()
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		zoom = math.clamp(zoom - input.Position.Z * 0.12, 0.6, 3)
		frameCamera()
	end
end)

saveBtn.MouseButton1Click:Connect(function()
	if not selectedWeapon then
		status.Text = "Pick a weapon first"
		return
	end
	-- Writes to the open build, or makes a new one if the default is being edited. The
	-- default itself is never written to -- that is the whole point of the slots.
	local payload = { attachments = loadout, camo = selectedCamo }
	local response
	if loadedBuildId then
		payload.id = loadedBuildId
		response = BuildAction:InvokeServer("save", selectedWeapon, payload)
	else
		response = BuildAction:InvokeServer("create", selectedWeapon, payload)
		if type(response) == "table" and response.ok then
			loadedBuildId = response.build.id
		end
	end

	if type(response) == "table" and response.ok then
		status.Text = string.format("Saved %s%s", response.build and response.build.name or "build",
			response.saved and "" or " (this session only)")
		UIKit.pulse(saveBtn, Theme.Success)
	else
		status.Text = "Refused: " .. (type(response) == "table" and tostring(response.reason) or "?")
		UIKit.pulse(saveBtn, Theme.Danger)
	end

	-- The owner also keeps the game-wide colour pass, which is a separate thing.
	if isOwner and next(pending) then
		CustomiseAction:InvokeServer("save", selectedWeapon, pending)
	end
	buildBuildList()
end)

resetBtn.MouseButton1Click:Connect(function()
	if not selectedWeapon then
		return
	end
	table.clear(pending)
	openBuild(nil)
	status.Text = "Back to the default weapon"
end)

-- Owner-only controls: present for the owner, absent for everyone else.
partList.Visible = ownerAuthorised
palette.Visible = ownerAuthorised

local PANEL_SIZE = panel.Size

local function setOpen(open: boolean)
	gui.Enabled = open
	-- Shift lock keeps the mouse pinned to the middle of the screen with no cursor, which
	-- makes a click-driven screen unusable. Every other panel in the game raises this same
	-- attribute and ShiftLock releases the cursor on it; this one was missing it.
	UIState.SetOpen("Customise", open)
	if open then
		-- Same open motion as the market, from the same helper, so the two screens do not
		-- feel like they came from different games.
		UIKit.openPanel(panel, PANEL_SIZE)
	end
end
closeBtn.MouseButton1Click:Connect(function()
	setOpen(false)
end)

-- Now OWNER-ONLY, and deliberately so.
--
-- The player-facing half of this panel -- picking attachments and a camo for a saved build --
-- has been rebuilt as ReplicatedStorage.UI.Modules.Workshop, on [K]. Leaving this open to
-- everyone as well would mean two workshops disagreeing about the same builds, which is the
-- duplicate-system problem the interface rebuild exists to remove.
--
-- What survives here is the part that has no replacement: the per-part colour and material
-- pass that sets a weapon's game-wide look. That was always owner-gated; the whole window is
-- simply gated the same way now. The server still re-checks on every save -- hiding a control
-- has never been the security boundary.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not ownerAuthorised then
		return
	end
	if input.KeyCode == Enum.KeyCode.F2 then
		setOpen(not gui.Enabled)
	end
end)
