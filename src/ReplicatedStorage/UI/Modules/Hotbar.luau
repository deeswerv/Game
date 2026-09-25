--!strict
-- The weapon hotbar: what you are carrying, and which of it is in your hands.
--
-- Draws only. The controller tells it which tools exist and which is equipped; pressing a
-- slot or a number key is reported back through a callback rather than handled here, so the
-- bar has no opinion about how equipping works.
--
-- Tiles are compact on purpose. The references give the carried-weapon row very little space
-- because it is glanced at, not read -- the slot number and the silhouette carry it, and the
-- name is a quiet second line.

local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local WeaponPreview = require(ReplicatedStorage:WaitForChild("WeaponPreview"))

local Hotbar = {}
Hotbar.__index = Hotbar

local TILE = Vector2.new(86, 70)

export type Entry = { name: string, rarity: string?, equipped: boolean? }

function Hotbar.new(parent: GuiObject, onSlot: (index: number) -> ())
	local self = setmetatable({}, Hotbar)

	local root = Instance.new("Frame")
	root.Name = "Hotbar"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(1, 1)
	-- Sits above the weapon block in the bottom-right corner, sharing its right margin so the
	-- two read as one column rather than two things that happen to be nearby.
	root.Position = UDim2.new(1, -Theme.Inset.Side, 1, -(Theme.Inset.Bottom + 104))
	root.Size = UDim2.fromOffset(0, TILE.Y)
	root.AutomaticSize = Enum.AutomaticSize.X
	root.Parent = parent
	Components.List(root, Enum.FillDirection.Horizontal, Theme.Space.S, Enum.HorizontalAlignment.Right)

	self._root = root
	self._onSlot = onSlot
	self._tiles = {}
	return self
end

local function buildTile(parent: GuiObject, index: number, entry: Entry, onSlot: (number) -> ())
	local rarityColour = Theme.RarityColour(entry.rarity)

	local b = Instance.new("TextButton")
	b.Name = "Slot" .. index
	b.AutoButtonColor = false
	b.Text = ""
	b.BackgroundColor3 = Theme.Colour.Panel
	b.BackgroundTransparency = 0.1
	b.BorderSizePixel = 0
	b.Size = UDim2.fromOffset(TILE.X, TILE.Y)
	b.LayoutOrder = index
	b.Parent = parent
	Components.Corner(b, Theme.Radius.Small)
	local edge = Components.Stroke(b, entry.equipped and Theme.Colour.Accent or Theme.Colour.Stroke,
		entry.equipped and Theme.Stroke.Emphasis or Theme.Stroke.Hair)

	-- Rarity as a top edge, matching the inventory card so one weapon looks the same wherever
	-- it appears.
	local cap = Instance.new("Frame")
	cap.Name = "RarityCap"
	cap.BackgroundColor3 = rarityColour
	cap.BorderSizePixel = 0
	cap.Size = UDim2.new(1, 0, 0, 2)
	cap.Parent = b

	-- A real 3D preview; the game already renders these, so the hotbar shows the actual gun
	-- rather than a stand-in glyph.
	local holder = Instance.new("Frame")
	holder.Name = "Preview"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.new(1, -8, 0, 38)
	holder.Position = UDim2.fromOffset(4, 6)
	holder.Parent = b
	pcall(function()
		WeaponPreview.Render(holder, entry.name)
	end)

	local number = Components.Label(b, {
		text = tostring(index),
		font = Theme.Font.Display,
		size = Theme.Text.Micro,
		colour = entry.equipped and Theme.Colour.Accent or Theme.Colour.TextMuted,
	})
	number.Size = UDim2.fromOffset(12, 12)
	number.Position = UDim2.fromOffset(6, 4)

	local name = Components.Label(b, {
		text = entry.name,
		font = Theme.Font.Bold,
		size = Theme.Text.Micro,
		align = Enum.TextXAlignment.Center,
		colour = entry.equipped and Theme.Colour.Text or Theme.Colour.TextDim,
	})
	name.Size = UDim2.new(1, -6, 0, 14)
	name.Position = UDim2.new(0, 3, 1, -18)

	local disconnect = Components.MakeInteractive(b, b, { base = Theme.Colour.Panel, lift = false })
	local activated = b.Activated:Connect(function()
		onSlot(index)
	end)

	return {
		instance = b,
		edge = edge,
		Destroy = function()
			disconnect()
			activated:Disconnect()
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

	for index, entry in ipairs(entries) do
		table.insert(self._tiles, buildTile(self._root, index, entry, self._onSlot))
	end
	self._root.Visible = #entries > 0
end

--- Move the highlight without rebuilding: equipping happens constantly and must not churn
--- eight ViewportFrames every time.
function Hotbar:SetEquipped(index: number?)
	for i, tile in ipairs(self._tiles) do
		local on = i == index
		TweenService:Create(tile.edge, Theme.Tween.Hover, {
			Color = on and Theme.Colour.Accent or Theme.Colour.Stroke,
			Thickness = on and Theme.Stroke.Emphasis or Theme.Stroke.Hair,
		}):Play()
	end
end

function Hotbar:SetVisible(visible: boolean)
	self._root.Visible = visible
end

function Hotbar:Destroy()
	for _, tile in ipairs(self._tiles) do
		tile.Destroy()
	end
	table.clear(self._tiles)
	self._root:Destroy()
end

return Hotbar
