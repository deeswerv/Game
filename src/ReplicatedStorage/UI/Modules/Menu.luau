--!strict
-- Menu: the shell every full-screen panel is built inside.
--
-- Inventory, Market and Workshop all open the same way, sit in the same place, use the same
-- header and close on the same key, because they are all this. The old interface built each
-- panel by hand and they drifted apart -- different margins, different close buttons, one of
-- them a different shade of grey.
--
-- It also owns the two things a panel must never forget. It registers with UIState so the
-- shared UIOpen flag is correct (ShiftLock reads that to decide whether the player is in a
-- menu; a panel that forgets to clear it leaves sprint broken with nothing on screen to
-- explain why), and it releases the mouse while open and restores it on close.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local UIState = require(ReplicatedStorage:WaitForChild("UIState"))

local player = Players.LocalPlayer

local Menu = {}
Menu.__index = Menu

export type Category = { id: string, label: string }

export type Options = {
	id: string,                 -- unique; used as the UIState key and the frame name
	title: string,
	subtitle: string?,
	size: UDim2?,
	categories: { Category }?,
}

function Menu.new(parent: Instance, options: Options)
	local self = setmetatable({}, Menu)

	self._id = options.id
	self._open = false
	self._categoryHandlers = {}
	self._categoryButtons = {}

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
		size = options.size or UDim2.fromOffset(920, 560),
		position = UDim2.fromScale(0.5, 0.5),
		anchor = Vector2.new(0.5, 0.5),
	})
	self._panel = panel

	-- ------------------------------------------------------------- header --

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, Theme.Size.HeaderHeight)
	header.Parent = panel
	-- Exposed so a panel can add its own line up here. Without this, parenting to menu.header
	-- silently parents to nil -- legal in Roblox, so the label just never appears.
	self.header = header

	local title = Components.Label(header, {
		text = options.title,
		font = Theme.Font.Bold,
		size = Theme.Text.Title,
	})
	title.Size = UDim2.new(1, -70, 0, 28)
	title.Position = UDim2.fromOffset(Theme.Space.L, Theme.Space.M)

	if options.subtitle then
		local sub = Components.Label(header, {
			text = options.subtitle,
			size = Theme.Text.Small,
			colour = Theme.Colour.TextDim,
		})
		sub.Size = UDim2.new(1, -70, 0, 16)
		sub.Position = UDim2.fromOffset(Theme.Space.L, Theme.Space.M + 26)
	end

	local divider = Instance.new("Frame")
	divider.Name = "Divider"
	divider.BackgroundColor3 = Theme.Colour.StrokeSoft
	divider.BorderSizePixel = 0
	divider.Size = UDim2.new(1, -Theme.Space.XL, 0, 1)
	divider.Position = UDim2.new(0, Theme.Space.L, 1, -1)
	divider.Parent = header

	local close = Components.Button(header, {
		name = "Close",
		text = "ESC",
		size = UDim2.fromOffset(46, 28),
		position = UDim2.new(1, -Theme.Space.L, 0, Theme.Space.M),
		anchor = Vector2.new(1, 0),
		textSize = Theme.Text.Micro,
		onActivated = function()
			self:Close()
		end,
	})
	self._close = close

	-- --------------------------------------------------------------- body --

	local bodyTop = Theme.Size.HeaderHeight + Theme.Space.M
	local railWidth = 0

	if options.categories and #options.categories > 0 then
		railWidth = 148

		local rail = Instance.new("Frame")
		rail.Name = "Rail"
		rail.BackgroundTransparency = 1
		rail.Size = UDim2.new(0, railWidth, 1, -(bodyTop + Theme.Space.L))
		rail.Position = UDim2.fromOffset(Theme.Space.L, bodyTop)
		rail.Parent = panel
		Components.List(rail, Enum.FillDirection.Vertical, Theme.Space.XS)

		for index, category in ipairs(options.categories) do
			local button = Components.Button(rail, {
				name = category.id,
				text = category.label,
				layoutOrder = index,
				size = UDim2.new(1, 0, 0, Theme.Size.ButtonHeightS),
				textSize = Theme.Text.Small,
				onActivated = function()
					self:SelectCategory(category.id)
				end,
			})
			button.instance.TextXAlignment = Enum.TextXAlignment.Left
			Components.Padding(button.instance, nil, Theme.Space.M, 0)
			self._categoryButtons[category.id] = button
		end

		self._firstCategory = options.categories[1].id
	end

	local content = Instance.new("Frame")
	content.Name = "Content"
	content.BackgroundTransparency = 1
	content.Size = UDim2.new(1, -(Theme.Space.XL + railWidth + (railWidth > 0 and Theme.Space.M or 0)),
		1, -(bodyTop + Theme.Space.L))
	content.Position = UDim2.fromOffset(Theme.Space.L + railWidth + (railWidth > 0 and Theme.Space.M or 0), bodyTop)
	content.Parent = panel
	self.content = content

	-- ---------------------------------------------------------- behaviour --

	-- Escape closes whatever is on top. gameProcessed is not checked here on purpose: the
	-- CoreScript menu also answers to Escape, and a player pressing it wants THIS panel shut.
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
		-- SetSelected rather than tweening the colour directly: the hover animation owns
		-- BackgroundColor3, and painting over it means the highlight dies the first time the
		-- mouse crosses the tab.
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
	self._restoreMouse = UserInputService.MouseBehavior
	UserInputService.MouseBehavior = Enum.MouseBehavior.Default

	self._root.Visible = true
	self._panel.BackgroundTransparency = 1
	self._panel.Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(0, Theme.Motion.Rise)
	TweenService:Create(self._root, Theme.Tween.Open, { BackgroundTransparency = 0.3 }):Play()
	TweenService:Create(self._panel, Theme.Tween.Open, {
		BackgroundTransparency = 0,
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()

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

	-- Only hand the mouse back if nothing else still wants it.
	if not UIState.IsAnyOpen() then
		UserInputService.MouseBehavior = Enum.MouseBehavior.Default
	end

	TweenService:Create(self._root, Theme.Tween.Close, { BackgroundTransparency = 1 }):Play()
	local out = TweenService:Create(self._panel, Theme.Tween.Close, {
		BackgroundTransparency = 1,
		Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(0, Theme.Motion.Rise),
	})
	out.Completed:Once(function()
		if not self._open then
			self._root.Visible = false
		end
	end)
	out:Play()
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

function Menu:Destroy()
	-- Clear the shared flag first. A panel destroyed while open used to leave UIOpen stuck
	-- true forever, which is the exact bug UIState was written to end.
	UIState.SetOpen(self._id, false)
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
