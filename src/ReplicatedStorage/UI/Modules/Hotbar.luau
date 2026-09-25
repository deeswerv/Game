--!strict
-- The weapon hotbar: what you are carrying, and which of it is in your hands.
--
-- Draws only. The controller tells it which tools exist and which is equipped; pressing a
-- slot or a number key is reported back through a callback rather than handled here, so the
-- bar has no opinion about how equipping works.
--
-- Styled on the reference slot row: dark glass tiles, the real weapon model as the icon, the
-- slot number tucked in the top-right corner and the name along the bottom. The equipped
-- tile lifts, brightens and turns its name gold.
--
-- Built to sit inside the HUD's weapon dock (a horizontal list), so it takes no position of
-- its own; given a plain parent it pins itself to the bottom-right corner instead.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local WeaponPreview = require(ReplicatedStorage:WaitForChild("WeaponPreview"))

local Hotbar = {}
Hotbar.__index = Hotbar

local TILE = Vector2.new(84, 68)
local MIN_TILE_WIDTH = 58
local MAX_ROW_WIDTH = 560
local GAP = 8
local GOLD = Color3.fromRGB(255, 196, 40)

export type Entry = { name: string, rarity: string?, equipped: boolean? }

function Hotbar.new(parent: GuiObject, onSlot: (index: number) -> ())
	local self = setmetatable({}, Hotbar)

	local root = Instance.new("Frame")
	root.Name = "Hotbar"
	root.BackgroundTransparency = 1
	root.Size = UDim2.fromOffset(0, TILE.Y)
	root.AutomaticSize = Enum.AutomaticSize.X
	root.LayoutOrder = 2
	if not parent:FindFirstChildOfClass("UIListLayout") then
		root.AnchorPoint = Vector2.new(1, 1)
		root.Position = UDim2.new(1, -Theme.Inset.Side, 1, -Theme.Inset.Bottom)
	end
	root.Parent = parent
	local layout = Components.List(root, Enum.FillDirection.Horizontal, GAP, Enum.HorizontalAlignment.Right)
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom

	self._root = root
	self._onSlot = onSlot
	self._tiles = {}
	return self
end

local function buildTile(parent: GuiObject, index: number, entry: Entry, width: number, onSlot: (number) -> ())
	local rarityColour = Theme.RarityColour(entry.rarity)

	local b = Instance.new("TextButton")
	b.Name = "Slot" .. index
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = Theme.Colour.Panel
	b.BackgroundTransparency = 0.3
	b.BorderSizePixel = 0
	b.Size = UDim2.fromOffset(width, TILE.Y)
	b.LayoutOrder = index
	b.Parent = parent
	Components.Corner(b, 10)
	local edge = Components.Stroke(b, Theme.Colour.Outline, 2)
	edge.Transparency = 0.25
	Components.Gradient(b, Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 150, 156))

	local scale = Instance.new("UIScale")
	scale.Parent = b

	-- Rarity as a thin line along the bottom, the way it tints the card border elsewhere.
	local cap = Instance.new("Frame")
	cap.Name = "RarityCap"
	cap.BackgroundColor3 = rarityColour
	cap.BackgroundTransparency = 0.2
	cap.BorderSizePixel = 0
	cap.AnchorPoint = Vector2.new(0.5, 1)
	cap.Size = UDim2.new(1, -16, 0, 3)
	cap.Position = UDim2.new(0.5, 0, 1, -2)
	cap.Parent = b
	Components.Corner(cap, 2)

	-- The real weapon, the same render the inventory and workshop use.
	local holder = Instance.new("Frame")
	holder.Name = "Preview"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, -8, 0, 40)
	holder.Position = UDim2.fromOffset(4, 4)
	holder.Parent = b
	pcall(function()
		WeaponPreview.Icon(holder, entry.name, { Zoom = 1.25 })
	end)

	local number = Components.Label(b, {
		text = tostring(index),
		font = Theme.Font.Display,
		size = 14,
		align = Enum.TextXAlignment.Right,
	})
	number.Name = "Number"
	number.Size = UDim2.fromOffset(20, 16)
	number.AnchorPoint = Vector2.new(1, 0)
	number.Position = UDim2.new(1, -5, 0, 2)

	local name = Components.Label(b, {
		text = entry.name,
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		align = Enum.TextXAlignment.Center,
		colour = Theme.Colour.TextDim,
	})
	name.Name = "WeaponName"
	name.Size = UDim2.new(1, -6, 0, 16)
	name.Position = UDim2.new(0, 3, 1, -21)
	name.TextTruncate = Enum.TextTruncate.AtEnd

	local connections = {
		b.MouseEnter:Connect(function()
			TweenService:Create(b, Theme.Tween.Hover, { BackgroundTransparency = 0.12 }):Play()
		end),
		b.MouseLeave:Connect(function()
			TweenService:Create(b, Theme.Tween.Hover, { BackgroundTransparency = b:GetAttribute("Rest") or 0.3 }):Play()
		end),
		b.Activated:Connect(function()
			onSlot(index)
		end),
	}

	return {
		instance = b,
		edge = edge,
		scale = scale,
		name = name,
		Destroy = function()
			for _, c in ipairs(connections) do
				c:Disconnect()
			end
			b:Destroy()
		end,
	}
end

--- Rebuild the bar. Called when the backpack changes, which is rare, so a full rebuild is
--- cheaper in complexity than diffing and costs nothing at this size.
function Hotbar:Set(entries: { Entry })
	for _, tile in ipairs(self._tiles) do
		tile.Destroy()
	end
	table.clear(self._tiles)

	-- Many weapons narrow the tiles rather than running the row into the health bar.
	local count = #entries
	local width = TILE.X
	if count > 0 then
		local fit = math.floor((MAX_ROW_WIDTH - GAP * (count - 1)) / count)
		width = math.clamp(fit, MIN_TILE_WIDTH, TILE.X)
	end

	for index, entry in ipairs(entries) do
		table.insert(self._tiles, buildTile(self._root, index, entry, width, self._onSlot))
	end
	self._root.Visible = count > 0
	self._equipped = nil
	for index, entry in ipairs(entries) do
		if entry.equipped then
			self:SetEquipped(index)
		end
	end
end

--- Move the highlight without rebuilding: equipping happens constantly and must not churn
--- ViewportFrames every time.
function Hotbar:SetEquipped(index: number?)
	for i, tile in ipairs(self._tiles) do
		local on = i == index
		local rest = on and 0.08 or 0.3
		tile.instance:SetAttribute("Rest", rest)
		TweenService:Create(tile.instance, Theme.Tween.Hover, { BackgroundTransparency = rest }):Play()
		TweenService:Create(tile.edge, Theme.Tween.Hover, {
			Color = on and GOLD or Theme.Colour.Outline,
			Thickness = on and 3 or 2,
			Transparency = on and 0 or 0.25,
		}):Play()
		TweenService:Create(tile.scale, Theme.Tween.Pop, { Scale = on and 1.08 or 1 }):Play()
		tile.name.TextColor3 = on and GOLD or Theme.Colour.TextDim
	end
	self._equipped = index
end

function Hotbar:SetVisible(visible: boolean)
	self._root.Visible = visible and #self._tiles > 0
end

function Hotbar:Destroy()
	for _, tile in ipairs(self._tiles) do
		tile.Destroy()
	end
	table.clear(self._tiles)
	self._root:Destroy()
end

return Hotbar
