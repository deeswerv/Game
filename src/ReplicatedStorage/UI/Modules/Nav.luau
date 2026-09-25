--!strict
-- The navigation row: how you get into the menus.
--
-- Bottom centre, because the corners are already spoken for -- health left, weapon and hotbar
-- right -- and the middle of the screen is the one place nothing else is allowed to live.
--
-- COMPACT TILES, not labelled buttons. Seven full-width pills came to roughly a thousand
-- pixels of chrome across the bottom edge -- more furniture than the rest of the HUD put
-- together. The same seven fit in about four hundred as squares. The references do this for
-- the same reason: a row of small squares reads as a toolbar you ignore until you want it,
-- where a row of words reads as a menu demanding to be read.
--
-- The keybind letter IS the icon. Not a compromise for want of artwork -- a single glyph is as
-- legible as a symbol at this size, needs no asset, and teaches the shortcut every time the
-- player glances at it.
--
-- Only pass entries for menus that exist; an item here for a system that is not built is
-- worse than no item at all.

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local Nav = {}
Nav.__index = Nav

local TILE = 54

export type Entry = { id: string, label: string, key: string?, onActivated: () -> () }

function Nav.new(parent: GuiObject, entries: { Entry })
	local self = setmetatable({}, Nav)

	local root = Instance.new("Frame")
	root.Name = "Nav"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 1)
	root.Position = UDim2.new(0.5, 0, 1, -Theme.Inset.Bottom)
	root.Size = UDim2.fromOffset(0, TILE)
	root.AutomaticSize = Enum.AutomaticSize.X
	root.Parent = parent
	Components.List(root, Enum.FillDirection.Horizontal, Theme.Space.XS + 2,
		Enum.HorizontalAlignment.Center)

	self._root = root
	self._buttons = {}

	for index, entry in ipairs(entries) do
		local button = Components.Button(root, {
			name = entry.id,
			text = "",                      -- the tile's own labels do the talking
			layoutOrder = index,
			size = UDim2.fromOffset(TILE, TILE),
			onActivated = entry.onActivated,
		})

		-- The key, large and centred high.
		local glyph = Components.Label(button.instance, {
			text = (entry.key or ""):gsub("[%[%]]", ""),
			font = Theme.Font.Display,
			size = Theme.Text.Large,
			align = Enum.TextXAlignment.Center,
		})
		glyph.Size = UDim2.new(1, 0, 0, 22)
		glyph.Position = UDim2.fromOffset(0, 8)

		-- The name, small and quiet underneath.
		local caption = Components.Label(button.instance, {
			text = entry.label,
			caps = true,
			size = 9,
			align = Enum.TextXAlignment.Center,
			colour = Theme.Colour.TextMuted,
		})
		caption.Size = UDim2.new(1, -4, 0, 12)
		caption.Position = UDim2.fromOffset(2, 33)

		table.insert(self._buttons, button)
	end

	return self
end

function Nav:SetVisible(visible: boolean)
	self._root.Visible = visible
end

function Nav:Destroy()
	for _, button in ipairs(self._buttons) do
		button:Destroy()
	end
	self._root:Destroy()
end

return Nav
