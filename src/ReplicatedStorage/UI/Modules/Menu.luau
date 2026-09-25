--!strict
-- Menu: the shell every full-screen panel is built inside.
--
-- Inventory, Market, Armory, Profile and Daily all open the same way, sit in the same place,
-- use the same header and close on the same key, because they are all this.
--
-- The look is the reference inventory/shop: the world blurs and dims behind a charcoal glass
-- window; the header is an icon, a bold outlined title and a grey line under it; the round
-- red close button overlaps the window's top-right corner; categories are either a rail of
-- square icon tiles down the left (inventory) or a row of chunky tabs across the top (shop).
--
-- It also owns the two things a panel must never forget. It registers with UIState so the
-- shared UIOpen flag is correct (ShiftLock reads that to decide whether the player is in a
-- menu), and it releases the mouse while open and restores it on close.

local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local UISound = require(script.Parent.UISound)
local UIState = require(ReplicatedStorage:WaitForChild("UIState"))

local Menu = {}
Menu.__index = Menu

export type Category = { id: string, label: string, icon: string?, preview: string? }

export type Options = {
	id: string,                 -- unique; used as the UIState key and the frame name
	title: string,
	subtitle: string?,
	icon: string?,              -- emoji shown beside the title
	size: UDim2?,
	categories: { Category }?,
	tabs: string?,              -- "rail" (default) or "top"
	bare: boolean?,             -- no header row: the content is the whole card (profile)
}

local WHITE = Color3.new(1, 1, 1)
local RAIL_WIDTH = 96
local RAIL_TILE = Vector2.new(84, 70)
local TAB_HEIGHT = 50

-- ------------------------------------------------------------------ blur --

-- One blur for every menu, on the camera so it is local to this player. It is counted
-- through UIState rather than per menu, so closing one panel while another is open does not
-- snap the world back into focus.
local blur: BlurEffect? = nil

local function setBlur(on: boolean)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if not blur or blur.Parent ~= camera then
		if blur then
			blur:Destroy()
		end
		local created = Instance.new("BlurEffect")
		created.Name = "MenuBlur"
		created.Size = 0
		created.Parent = camera
		blur = created
	end
	TweenService:Create(blur :: BlurEffect, on and Theme.Tween.Value or Theme.Tween.Close, {
		Size = on and 16 or 0,
	}):Play()
end

-- --------------------------------------------------------------- category --

local function railTile(parent: GuiObject, category: Category, order: number, onPick: () -> ())
	local b = Instance.new("TextButton")
	b.Name = category.id
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = Theme.Colour.PanelRaised
	b.Size = UDim2.fromOffset(RAIL_TILE.X, RAIL_TILE.Y)
	b.LayoutOrder = order
	b.Parent = parent
	Components.Corner(b, 10)
	local rim = Components.Stroke(b, Theme.Colour.Outline, 2)
	Components.Gradient(b)
	local scale = Instance.new("UIScale")
	scale.Parent = b

	if category.preview then
		local holder = Instance.new("Frame")
		holder.Name = "Preview"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(1, -8, 0, 40)
		holder.Position = UDim2.fromOffset(4, 4)
		holder.Parent = b
		local ok, WeaponPreview = pcall(function()
			return require(ReplicatedStorage:WaitForChild("WeaponPreview")) :: any
		end)
		if ok then
			pcall(WeaponPreview.Icon, holder, category.preview, { Zoom = 1.2 })
		end
	else
		local icon = Components.Icon(b, category.icon or "⭐", 28)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 5)
	end

	local label = Components.Label(b, {
		text = category.label,
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		align = Enum.TextXAlignment.Center,
	})
	label.Size = UDim2.new(1, -4, 0, 20)
	label.Position = UDim2.new(0, 2, 1, -23)
	label.TextTruncate = Enum.TextTruncate.AtEnd

	local connections = {
		b.MouseEnter:Connect(function()
			TweenService:Create(scale, Theme.Tween.Hover, { Scale = 1.05 }):Play()
		end),
		b.MouseLeave:Connect(function()
			TweenService:Create(scale, Theme.Tween.Hover, { Scale = 1 }):Play()
		end),
		b.Activated:Connect(onPick),
	}

	return {
		instance = b,
		SetSelected = function(_, selected: boolean)
			-- Lit: the pale tile with a white rim, as the selected tile in the reference rail.
			TweenService:Create(b, Theme.Tween.Hover, {
				BackgroundColor3 = selected and Color3.fromRGB(150, 156, 170) or Theme.Colour.PanelRaised,
			}):Play()
			rim.Color = selected and WHITE or Theme.Colour.Outline
			rim.Thickness = selected and 3 or 2
		end,
		Destroy = function()
			for _, c in ipairs(connections) do
				c:Disconnect()
			end
			b:Destroy()
		end,
	}
end

local function topTab(parent: GuiObject, category: Category, order: number, onPick: () -> ())
	local b = Instance.new("TextButton")
	b.Name = category.id
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = Theme.Colour.PanelRaised
	b.Size = UDim2.fromOffset(0, TAB_HEIGHT)
	b.AutomaticSize = Enum.AutomaticSize.X
	b.LayoutOrder = order
	b.Parent = parent
	Components.Corner(b, 12)
	local rim = Components.Stroke(b, Theme.Colour.Outline, 2)
	Components.Gradient(b)
	local pad = Components.Padding(b, nil, 14, 0)
	pad.PaddingLeft = UDim.new(0, 10)
	local row = Components.List(b, Enum.FillDirection.Horizontal, 6)
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	local scale = Instance.new("UIScale")
	scale.Parent = b

	if category.preview then
		local holder = Instance.new("Frame")
		holder.Name = "Preview"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.fromOffset(46, 34)
		holder.LayoutOrder = 1
		holder.Parent = b
		local ok, WeaponPreview = pcall(function()
			return require(ReplicatedStorage:WaitForChild("WeaponPreview")) :: any
		end)
		if ok then
			pcall(WeaponPreview.Icon, holder, category.preview, { Zoom = 1.1 })
		end
	else
		local icon = Components.Icon(b, category.icon or "⭐", 26)
		icon.LayoutOrder = 1
	end

	local label = Components.Label(b, {
		text = category.label,
		font = Theme.Font.Bold,
		size = 22,
		autoSize = true,
		layoutOrder = 2,
	})
	local labelEdge = label:FindFirstChildOfClass("UIStroke")

	local connections = {
		b.MouseEnter:Connect(function()
			TweenService:Create(scale, Theme.Tween.Hover, { Scale = 1.05 }):Play()
		end),
		b.MouseLeave:Connect(function()
			TweenService:Create(scale, Theme.Tween.Hover, { Scale = 1 }):Play()
		end),
		b.Activated:Connect(onPick),
	}

	return {
		instance = b,
		SetSelected = function(_, selected: boolean)
			-- The lit tab is white with dark type, exactly as the reference shop draws it.
			TweenService:Create(b, Theme.Tween.Hover, {
				BackgroundColor3 = selected and Color3.fromRGB(245, 246, 250) or Theme.Colour.PanelRaised,
			}):Play()
			label.TextColor3 = selected and Theme.Colour.Outline or WHITE
			if labelEdge then
				labelEdge.Transparency = selected and 1 or 0.1
			end
			rim.Color = selected and WHITE or Theme.Colour.Outline
		end,
		Destroy = function()
			for _, c in ipairs(connections) do
				c:Disconnect()
			end
			b:Destroy()
		end,
	}
end

-- ------------------------------------------------------------------ build --

function Menu.new(parent: Instance, options: Options)
	local self = setmetatable({}, Menu)

	self._id = options.id
	self._open = false
	self._categoryHandlers = {}
	self._categoryButtons = {}
	self._closeHandlers = {}

	local root = Instance.new("Frame")
	root.Name = options.id
	root.BackgroundColor3 = Theme.Colour.Scrim
	root.BackgroundTransparency = 1
	root.BorderSizePixel = 0
	root.Size = UDim2.fromScale(1, 1)
	root.Visible = false
	root.ZIndex = Theme.Layer.Menu
	root.Parent = parent
	self._root = root

	local panel = Components.Panel(root, {
		name = "Window",
		size = options.size or UDim2.fromOffset(940, 570),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
		transparency = 0.06,
	})
	self._panel = panel
	local windowScale = Instance.new("UIScale")
	windowScale.Parent = panel
	self._windowScale = windowScale

	-- ------------------------------------------------------------- header --

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, options.bare and 0 or Theme.Size.HeaderHeight)
	header.Parent = panel
	-- Exposed so a panel can add its own line up here.
	self.header = header

	local textLeft = Theme.Space.L
	if options.icon and not options.bare then
		local icon = Components.Icon(header, options.icon, 42)
		icon.Position = UDim2.fromOffset(Theme.Space.M, 10)
		icon.Rotation = -8
		textLeft = 70
	end

	local title = Components.Label(header, {
		text = options.title,
		font = Theme.Font.Bold,
		size = 32,
		outline = 2.4,
	})
	title.Size = UDim2.new(1, -(textLeft + 70), 0, 34)
	title.Position = UDim2.fromOffset(textLeft, 8)
	title.Visible = not options.bare
	self.title = title

	-- Always present, so a panel can write its own line (the market's standing) here.
	local sub = Components.Label(header, {
		text = options.subtitle or "",
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		colour = Theme.Colour.TextDim,
	})
	sub.Size = UDim2.new(1, -(textLeft + 70), 0, 18)
	sub.Position = UDim2.fromOffset(textLeft, 42)
	sub.Visible = not options.bare
	self.subtitle = sub

	-- The close button hangs off the window's corner.
	local close = Components.CloseButton(panel, function()
		self:Close()
	end, 48)
	close.instance.AnchorPoint = Vector2.new(0.5, 0.5)
	close.instance.Position = UDim2.new(1, -8, 0, 8)
	close.instance.ZIndex = 5
	self._close = close

	-- --------------------------------------------------------------- body --

	local bodyTop = options.bare and Theme.Space.L or (Theme.Size.HeaderHeight + Theme.Space.S)
	local leftInset = Theme.Space.L
	local topInset = bodyTop

	if options.categories and #options.categories > 0 then
		local top = options.tabs == "top"
		if top then
			local bar = Instance.new("Frame")
			bar.Name = "Tabs"
			bar.BackgroundTransparency = 1
			bar.Size = UDim2.new(1, -Theme.Space.L * 2, 0, TAB_HEIGHT)
			bar.Position = UDim2.fromOffset(Theme.Space.L, bodyTop)
			bar.Parent = panel
			local row = Components.List(bar, Enum.FillDirection.Horizontal, Theme.Space.S, Enum.HorizontalAlignment.Center)
			row.VerticalAlignment = Enum.VerticalAlignment.Center
			for index, category in ipairs(options.categories) do
				self._categoryButtons[category.id] = topTab(bar, category, index, function()
					self:SelectCategory(category.id)
				end)
			end
			topInset = bodyTop + TAB_HEIGHT + Theme.Space.M
		else
			-- The rail: a dark rounded well holding square tiles, scrolling if it must.
			local well = Instance.new("Frame")
			well.Name = "RailWell"
			well.BackgroundColor3 = Theme.Colour.Sunken
			well.BackgroundTransparency = 0.25
			well.BorderSizePixel = 0
			well.Size = UDim2.new(0, RAIL_WIDTH + 8, 1, -(bodyTop + Theme.Space.L))
			well.Position = UDim2.fromOffset(Theme.Space.L - 4, bodyTop)
			well.Parent = panel
			Components.Corner(well, 16)

			local rail = Instance.new("ScrollingFrame")
			rail.Name = "Rail"
			rail.BackgroundTransparency = 1
			rail.BorderSizePixel = 0
			rail.Size = UDim2.new(1, 0, 1, -12)
			rail.Position = UDim2.fromOffset(0, 6)
			rail.CanvasSize = UDim2.new()
			rail.AutomaticCanvasSize = Enum.AutomaticSize.Y
			rail.ScrollBarThickness = 0
			rail.Parent = well
			local list = Components.List(rail, Enum.FillDirection.Vertical, 8, Enum.HorizontalAlignment.Center)
			list.VerticalAlignment = Enum.VerticalAlignment.Top
			Components.Padding(rail, nil, 0, 4)

			for index, category in ipairs(options.categories) do
				self._categoryButtons[category.id] = railTile(rail, category, index, function()
					self:SelectCategory(category.id)
				end)
			end
			leftInset = Theme.Space.L + RAIL_WIDTH + 8 + Theme.Space.M
		end
		self._firstCategory = options.categories[1].id
	end

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, -(leftInset + Theme.Space.L), 1, -(topInset + Theme.Space.L))
	content.Position = UDim2.fromOffset(leftInset, topInset)
	content.Parent = panel
	self.content = content

	-- ---------------------------------------------------------- behaviour --

	-- Escape closes whatever is on top.
	self._escape = UserInputService.InputBegan:Connect(function(input: InputObject)
		if self._open and input.KeyCode == Enum.KeyCode.Escape then
			self:Close()
		end
	end)

	return self
end

--- Which category is highlighted, and tell whoever is listening to refill the content.
function Menu:SelectCategory(id: string)
	self._category = id
	for categoryId, button in pairs(self._categoryButtons) do
		button:SetSelected(categoryId == id)
	end
	for _, handler in ipairs(self._categoryHandlers) do
		handler(id)
	end
end

function Menu:OnCategory(handler: (id: string) -> ())
	table.insert(self._categoryHandlers, handler)
end

function Menu:IsOpen(): boolean
	return self._open
end

function Menu:Open()
	if self._open then
		return
	end
	self._open = true

	-- Counted, not assigned: several panels can be open and each clears only its own entry.
	UIState.SetOpen(self._id, true)
	UISound.Play("Whoosh", 1.6, 0.35)
	self._restoreMouse = UserInputService.MouseBehavior
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	setBlur(true)

	self._root.Visible = true
	self._root.BackgroundTransparency = 1
	self._panel.Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(0, Theme.Motion.Rise)
	self._windowScale.Scale = 0.9
	TweenService:Create(self._root, Theme.Tween.Value, { BackgroundTransparency = 0.45 }):Play()
	TweenService:Create(self._panel, Theme.Tween.Open, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	TweenService:Create(self._windowScale, Theme.Tween.Open, { Scale = 1 }):Play()

	if self._firstCategory and not self._category then
		self:SelectCategory(self._firstCategory)
	end
	if self._onOpen then
		self._onOpen()
	end
end

function Menu:Close()
	if not self._open then
		return
	end
	self._open = false
	UIState.SetOpen(self._id, false)

	-- Only hand the mouse back and clear the blur if nothing else still wants them.
	if not UIState.IsAnyOpen() then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
		setBlur(false)
	end

	TweenService:Create(self._root, Theme.Tween.Close, { BackgroundTransparency = 1 }):Play()
	TweenService:Create(self._windowScale, Theme.Tween.Close, { Scale = 0.94 }):Play()
	local out = TweenService:Create(self._panel, Theme.Tween.Close, {
		Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(0, Theme.Motion.Rise),
	})
	out.Completed:Once(function()
		if not self._open then
			self._root.Visible = false
		end
	end)
	out:Play()

	for _, handler in ipairs(self._closeHandlers) do
		task.spawn(handler)
	end
end

function Menu:Toggle()
	if self._open then
		self:Close()
	else
		self:Open()
	end
end

function Menu:OnOpen(handler: () -> ())
	self._onOpen = handler
end

function Menu:OnClose(handler: () -> ())
	table.insert(self._closeHandlers, handler)
end

function Menu:Destroy()
	-- Clear the shared flag first. A panel destroyed while open used to leave UIOpen stuck
	-- true forever, which is the exact bug UIState was written to end.
	UIState.SetOpen(self._id, false)
	if not UIState.IsAnyOpen() then
		setBlur(false)
	end
	if self._escape then
		self._escape:Disconnect()
	end
	self._close:Destroy()
	for _, button in pairs(self._categoryButtons) do
		button:Destroy()
	end
	self._root:Destroy()
end

return Menu
