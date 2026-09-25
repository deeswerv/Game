--!strict
-- The navigation dock: how you get into the menus.
--
-- A column of chunky icon tiles down the right edge -- the corners are spoken for (vitals
-- bottom-left, ammo and slots bottom-right, cash top-centre) and the middle of the screen is
-- the one place nothing else is allowed to live.
--
-- Each tile is a big colour icon with its name under it and its key in the corner, the way
-- the reference lobby dock reads: the picture is recognised before the word is read, and the
-- key is learned by glancing at it.
--
-- New players get speech-bubble hints on the tiles that matter first ("Unlock New Guns!"),
-- which is how the references teach a first-time player where to go. A hint goes away the
-- moment its tile is used, and all of them retire after the first couple of minutes.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local UISound = require(script.Parent.UISound)
local Components = require(script.Parent.Components)

local Nav = {}
Nav.__index = Nav

local TILE = 58
local GAP = 6
local HINT_LIFETIME = 120

local ICONS: { [string]: string } = {
	Inventory = "🎒",
	Market = "🛒",
	Workshop = "🔧",
	Duel = "⚔️",
	Profile = "🏆",
	Range = "🎯",
	Daily = "🎁",
	Journal = "📜",
	Settings = "⚙️",
	Contracts = "🎯",
}

export type Entry = {
	id: string, label: string, key: string?, icon: string?, hint: string?,
	onActivated: () -> (),
}

local function buildHint(tile: GuiObject, text: string): Frame
	local bubble = Instance.new("Frame")
	bubble.Name = "Hint"
	bubble.BackgroundColor3 = Color3.new(1, 1, 1)
	bubble.BorderSizePixel = 0
	bubble.AnchorPoint = Vector2.new(1, 0.5)
	bubble.Position = UDim2.new(0, -14, 0.5, 0)
	bubble.Size = UDim2.fromOffset(0, 30)
	bubble.AutomaticSize = Enum.AutomaticSize.X
	bubble.ZIndex = Theme.Layer.Tooltip
	bubble.Parent = tile
	Components.Corner(bubble, 6)
	Components.Stroke(bubble, Theme.Colour.Outline, 2).Transparency = 0.1
	Components.Padding(bubble, nil, 10, 0)

	local label = Components.Label(bubble, {
		text = text,
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		colour = Theme.Colour.Outline,
		autoSize = true,
		outline = false,
	})
	label.AnchorPoint = Vector2.new(0, 0.5)
	label.Position = UDim2.fromScale(0, 0.5)
	label.ZIndex = Theme.Layer.Tooltip + 1

	-- The pointer: a small rotated square poking out of the bubble toward the tile.
	local pointer = Instance.new("Frame")
	pointer.Name = "Pointer"
	pointer.BackgroundColor3 = Color3.new(1, 1, 1)
	pointer.BorderSizePixel = 0
	pointer.AnchorPoint = Vector2.new(0.5, 0.5)
	pointer.Position = UDim2.new(1, 10, 0.5, 0)
	pointer.Size = UDim2.fromOffset(10, 10)
	pointer.Rotation = 45
	pointer.ZIndex = Theme.Layer.Tooltip
	pointer.Parent = bubble

	-- A gentle bob, so the eye finds it.
	local rest = bubble.Position
	local bob = TweenService:Create(bubble, TweenInfo.new(0.7, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
		Position = rest + UDim2.fromOffset(-6, 0),
	})
	bob:Play()
	bubble.Destroying:Connect(function()
		bob:Cancel()
	end)
	return bubble
end

function Nav.new(parent: GuiObject, entries: { Entry })
	local self = setmetatable({}, Nav)

	local root = Instance.new("Frame")
	root.Name = "Nav"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(1, 0.5)
	root.Position = UDim2.new(1, -Theme.Inset.Side, 0.5, 20)
	-- One column while it fits; two once the dock grows past six, so the column never runs
	-- down into the weapon dock in the bottom-right corner.
	local columns = #entries > 6 and 2 or 1
	root.Size = UDim2.fromOffset(TILE * columns + GAP * (columns - 1), 0)
	root.AutomaticSize = Enum.AutomaticSize.Y
	root.Parent = parent
	if columns == 1 then
		Components.List(root, Enum.FillDirection.Vertical, GAP, Enum.HorizontalAlignment.Right)
	else
		local grid = Instance.new("UIGridLayout")
		grid.CellSize = UDim2.fromOffset(TILE, TILE)
		grid.CellPadding = UDim2.fromOffset(GAP, GAP)
		grid.FillDirection = Enum.FillDirection.Horizontal
		grid.FillDirectionMaxCells = columns
		grid.HorizontalAlignment = Enum.HorizontalAlignment.Right
		grid.SortOrder = Enum.SortOrder.LayoutOrder
		grid.Parent = root
	end

	self._root = root
	self._tiles = {}
	self._hints = {}
	self._byId = {}

	for index, entry in ipairs(entries) do
		local tile = Instance.new("TextButton")
		tile.Name = entry.id
		tile.AutoButtonColor = false
		tile.Text = ""
		tile.BackgroundColor3 = Theme.Colour.Panel
		tile.BackgroundTransparency = 0.3
		tile.BorderSizePixel = 0
		tile.Size = UDim2.fromOffset(TILE, TILE)
		tile.LayoutOrder = index
		tile.Parent = root
		Components.Corner(tile, 12)
		Components.Stroke(tile, Theme.Colour.Outline, 2).Transparency = 0.2
		Components.Gradient(tile, Color3.new(1, 1, 1), Color3.fromRGB(140, 140, 146))

		local scale = Instance.new("UIScale")
		scale.Parent = tile

		local icon = Components.Icon(tile, entry.icon or ICONS[entry.id] or "⭐", 28)
		icon.AnchorPoint = Vector2.new(0.5, 0)
		icon.Position = UDim2.new(0.5, 0, 0, 2)

		local caption = Components.Label(tile, {
			text = string.upper(entry.label),
			font = Theme.Font.Bold,
			size = 11,
			align = Enum.TextXAlignment.Center,
		})
		caption.Size = UDim2.new(1, -2, 0, 12)
		caption.Position = UDim2.new(0, 1, 1, -16)
		caption.TextScaled = false

		local key = (entry.key or ""):gsub("[%[%]]", "")
		if key ~= "" then
			local keycap = Components.Label(tile, {
				text = key,
				font = Theme.Font.Display,
				size = 11,
				colour = Theme.Colour.TextDim,
			})
			keycap.Size = UDim2.fromOffset(14, 12)
			keycap.Position = UDim2.fromOffset(4, 2)
		end

		local connections = {
			tile.MouseEnter:Connect(function()
				TweenService:Create(scale, Theme.Tween.Hover, { Scale = 1.1 }):Play()
				TweenService:Create(tile, Theme.Tween.Hover, { BackgroundTransparency = 0.05 }):Play()
			end),
			tile.MouseLeave:Connect(function()
				TweenService:Create(scale, Theme.Tween.Hover, { Scale = 1 }):Play()
				TweenService:Create(tile, Theme.Tween.Hover, { BackgroundTransparency = 0.3 }):Play()
			end),
			tile.MouseButton1Down:Connect(function()
				TweenService:Create(scale, Theme.Tween.Press, { Scale = 0.94 }):Play()
			end),
			tile.Activated:Connect(function()
				UISound.Play("Click")
				TweenService:Create(scale, Theme.Tween.Pop, { Scale = 1 }):Play()
				self:DismissHint(entry.id)
				entry.onActivated()
			end),
		}

		if entry.hint then
			self._hints[entry.id] = buildHint(tile, entry.hint)
		end

		table.insert(self._tiles, { instance = tile, connections = connections })
		self._byId[entry.id] = tile
	end

	-- Hints are for the first minutes of a session, not forever.
	task.delay(HINT_LIFETIME, function()
		for id in pairs(self._hints) do
			self:DismissHint(id)
		end
	end)

	return self
end

--- Retire the hint on one tile -- called when the tile is used, or when its menu is opened
--- some other way (a hotkey).
function Nav:DismissHint(id: string)
	local bubble = self._hints[id]
	if not bubble then
		return
	end
	self._hints[id] = nil
	local info = TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	TweenService:Create(bubble, info, { BackgroundTransparency = 1 }):Play()
	for _, d in ipairs(bubble:GetDescendants()) do
		if d:IsA("TextLabel") then
			TweenService:Create(d, info, { TextTransparency = 1 }):Play()
		elseif d:IsA("Frame") then
			TweenService:Create(d, info, { BackgroundTransparency = 1 }):Play()
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, info, { Transparency = 1 }):Play()
		end
	end
	task.delay(0.22, function()
		bubble:Destroy()
	end)
end

--- A red count on a tile's corner (unspent stat points, say). Zero hides it.
function Nav:SetBadge(id: string, count: number)
	local tile = self._byId[id]
	if not tile then
		return
	end
	local badge = tile:FindFirstChild("Badge")
	if not badge then
		local b = Instance.new("Frame")
		b.Name = "Badge"
		b.BackgroundColor3 = Theme.Colour.Danger
		b.AnchorPoint = Vector2.new(0.5, 0.5)
		b.Position = UDim2.new(1, -4, 0, 4)
		b.Size = UDim2.fromOffset(0, 20)
		b.AutomaticSize = Enum.AutomaticSize.X
		b.ZIndex = 5
		b.Parent = tile
		Components.Corner(b, 10)
		Components.Stroke(b, Theme.Colour.Outline, 2)
		Components.Padding(b, nil, 5, 0)
		local text = Components.Label(b, {
			text = "",
			font = Theme.Font.Display,
			size = 14,
			autoSize = true,
			outline = 1.6,
		})
		text.Name = "Count"
		text.AnchorPoint = Vector2.new(0, 0.5)
		text.Position = UDim2.fromScale(0, 0.5)
		text.ZIndex = 6
		badge = b
	end
	local n = math.max(0, math.floor(count))
	;(badge :: Frame).Visible = n > 0
	local text = (badge :: Frame):FindFirstChild("Count") :: TextLabel
	text.Text = n > 99 and "99+" or tostring(n)
end

function Nav:SetVisible(visible: boolean)
	self._root.Visible = visible
end

function Nav:Destroy()
	for _, tile in ipairs(self._tiles) do
		for _, c in ipairs(tile.connections) do
			c:Disconnect()
		end
	end
	self._root:Destroy()
end

return Nav
