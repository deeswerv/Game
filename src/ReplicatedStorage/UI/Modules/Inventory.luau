--!strict
-- The inventory: everything you own, and what you are taking with you.
--
-- Ownership is ASKED FOR, never assumed. The panel invokes GetOwnership and draws what the
-- server says; equipping goes back through LoadoutAction and the server decides. A client
-- that edits this file can make the grid show anything it likes and still not own a weapon,
-- which is the only arrangement worth having.
--
-- Categories are derived from WeaponConfig rather than typed here, so a class that does not
-- exist never gets a tab and a new one appears on its own.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menu = require(script.Parent.Menu)
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
local WeaponPreview = require(ReplicatedStorage:WaitForChild("WeaponPreview"))

local Inventory = {}
Inventory.__index = Inventory

-- Fourteen weapon classes would be fourteen tabs, which is a list rather than a choice. These
-- group them the way a player thinks about them; anything unmapped falls into OTHER, so a new
-- class still shows up instead of vanishing.
local GROUPS = {
	Rifle = "Rifles", Carbine = "Rifles", LMG = "Rifles", Marksman = "Rifles",
	SMG = "SMG",
	Shotgun = "Shotgun",
	Sniper = "Sniper",
	Pistol = "Sidearm", Revolver = "Sidearm",
}
local GROUP_ORDER = { "All", "Rifles", "SMG", "Shotgun", "Sniper", "Sidearm", "Melee", "Other" }

local function groupFor(cfg): string
	if cfg.Type == "Melee" then
		return "Melee"
	end
	return GROUPS[cfg.Class] or "Other"
end

--- Only the groups that actually have a weapon in them become tabs.
local function buildCategories(): { { id: string, label: string } }
	local present = { All = true }
	for name in pairs(WeaponConfig.Weapons) do
		present[groupFor(WeaponConfig.Weapons[name])] = true
	end
	local categories = {}
	for _, id in ipairs(GROUP_ORDER) do
		if present[id] then
			table.insert(categories, { id = id, label = id == "All" and "ALL WEAPONS" or string.upper(id) })
		end
	end
	return categories
end

-- --------------------------------------------------------------- detail --

local function buildDetail(parent: GuiObject)
	local panel = Components.Panel(parent, {
		name = "Detail",
		colour = Theme.Colour.Sunken,
		radius = Theme.Radius.Card,
		size = UDim2.new(0.38, 0, 1, 0),
		position = UDim2.new(0.62, Theme.Space.M, 0, 0),
	})

	local preview = Instance.new("Frame")
	preview.Name = "Preview"
	preview.BackgroundTransparency = 1
	preview.Size = UDim2.new(1, -Theme.Space.XL, 0, 150)
	preview.Position = UDim2.fromOffset(Theme.Space.M, Theme.Space.M)
	preview.Parent = panel

	local name = Components.Label(panel, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Large,
		align = Enum.TextXAlignment.Center,
	})
	name.Size = UDim2.new(1, -Theme.Space.XL, 0, 22)
	name.Position = UDim2.fromOffset(Theme.Space.M, 168)

	local rarity = Components.Label(panel, {
		text = "",
		caps = true,
		size = Theme.Text.Micro,
		align = Enum.TextXAlignment.Center,
	})
	rarity.Size = UDim2.new(1, -Theme.Space.XL, 0, 14)
	rarity.Position = UDim2.fromOffset(Theme.Space.M, 190)

	local description = Components.Label(panel, {
		text = "",
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
		wrap = true,
	})
	description.Size = UDim2.new(1, -Theme.Space.XL, 0, 40)
	description.Position = UDim2.fromOffset(Theme.Space.M, 210)

	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.BackgroundTransparency = 1
	stats.Size = UDim2.new(1, -Theme.Space.XL, 0, 140)
	stats.Position = UDim2.fromOffset(Theme.Space.M, 256)
	stats.Parent = panel
	Components.List(stats, Enum.FillDirection.Vertical, Theme.Space.XS)

	return panel, preview, name, rarity, description, stats
end

-- ------------------------------------------------------------------ api --

function Inventory.new(parent: Instance, remotes: { getOwnership: RemoteFunction, loadoutAction: RemoteFunction })
	local self = setmetatable({}, Inventory)

	self._remotes = remotes
	self._cards = {}
	self._owned = {}
	self._selected = nil

	local menu = Menu.new(parent, {
		id = "Inventory",
		title = "INVENTORY",
		subtitle = "Everything you own. Pick what you carry.",
		size = UDim2.fromOffset(940, 560),
		categories = buildCategories(),
	})
	self._menu = menu

	-- Grid on the left, detail on the right, as in the references.
	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Grid"
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = UDim2.new(0.62, -Theme.Space.M, 1, 0)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 3
	scroller.ScrollBarImageColor3 = Theme.Colour.Stroke
	scroller.Parent = menu.content
	Components.Grid(scroller, Theme.Size.SlotTile, Theme.Space.M)
	self._grid = scroller

	local _, preview, name, rarity, description, stats = buildDetail(menu.content)
	self._preview = preview
	self._name = name
	self._rarity = rarity
	self._description = description
	self._stats = stats

	self._equip = Components.Button(menu.content, {
		name = "Equip",
		text = "EQUIP",
		primary = true,
		size = UDim2.new(0.38, -Theme.Space.XL, 0, Theme.Size.ButtonHeight),
		position = UDim2.new(0.62, Theme.Space.M + Theme.Space.M, 1, -Theme.Space.M),
		anchor = Vector2.new(0, 1),
		onActivated = function()
			self:_equipSelected()
		end,
	})
	self._equip:SetEnabled(false)

	menu:OnCategory(function(id: string)
		self:_fill(id)
	end)
	menu:OnOpen(function()
		self:Refresh()
	end)

	return self
end

--- Ask the server what is owned, then redraw. Called on every open rather than cached, so a
--- purchase made in the market is reflected without any cross-panel message passing.
function Inventory:Refresh()
	task.spawn(function()
		local ok, result = pcall(function()
			return self._remotes.getOwnership:InvokeServer()
		end)
		local owned = {}
		if ok and type(result) == "table" and type(result.OwnedItems) == "table" then
			for _, id in ipairs(result.OwnedItems) do
				owned[id] = true
			end
		end
		self._owned = owned
		self:_fill(self._menu._category or "All")
	end)
end

function Inventory:_fill(group: string)
	for _, card in ipairs(self._cards) do
		card:Destroy()
	end
	table.clear(self._cards)

	-- Owned first, then by rarity, then alphabetically: what you can actually use is at the
	-- top, and the order never jitters between opens.
	local names = {}
	for name in pairs(WeaponConfig.Weapons) do
		local cfg = WeaponConfig.Weapons[name]
		if group == "All" or groupFor(cfg) == group then
			table.insert(names, name)
		end
	end
	table.sort(names, function(a, b)
		local ownedA, ownedB = self._owned[a] == true, self._owned[b] == true
		if ownedA ~= ownedB then
			return ownedA
		end
		local rarityA = Theme.Rarity[WeaponConfig.Weapons[a].Rarity or "Common"]
		local rarityB = Theme.Rarity[WeaponConfig.Weapons[b].Rarity or "Common"]
		local orderA = rarityA and rarityA.order or 0
		local orderB = rarityB and rarityB.order or 0
		if orderA ~= orderB then
			return orderA > orderB
		end
		return a < b
	end)

	for index, name in ipairs(names) do
		local cfg = WeaponConfig.Weapons[name]
		local owned = self._owned[name] == true
		local card = Components.Card(self._grid, {
			title = name,
			rarity = cfg.Rarity,
			subtitle = owned and cfg.Rarity or "LOCKED",
			locked = not owned,
			layoutOrder = index,
			onActivated = function()
				self:_select(name)
			end,
		})
		-- A real render of the weapon, the same one the hotbar and workshop show.
		local holder = Instance.new("Frame")
		holder.Name = "Preview"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(1, -12, 0, 62)
		holder.Position = UDim2.fromOffset(6, 14)
		holder.Parent = card.instance
		pcall(function()
			WeaponPreview.Render(holder, name)
		end)
		table.insert(self._cards, card)
	end

	-- Never leave the detail side blank. Keep the current selection if it survived the filter,
	-- otherwise fall to the first card -- an empty half-panel reads as broken.
	if self._selected and table.find(names, self._selected) then
		self:_select(self._selected)
	elseif names[1] then
		self:_select(names[1])
	end
end

function Inventory:_select(name: string)
	self._selected = name
	local cfg = WeaponConfig.Weapons[name]
	if not cfg then
		return
	end

	for _, card in ipairs(self._cards) do
		local label = card.instance:FindFirstChildOfClass("TextLabel")
		card:SetSelected(label ~= nil and label.Text == name)
	end

	self._preview:ClearAllChildren()
	pcall(function()
		WeaponPreview.Render(self._preview, name)
	end)

	self._name.Text = name
	self._rarity.Text = string.upper(cfg.Rarity or "")
	self._rarity.TextColor3 = Theme.RarityColour(cfg.Rarity)
	self._description.Text = cfg.Description or ""

	for _, child in ipairs(self._stats:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end

	-- Only stats the weapon actually has. A melee weapon has no magazine, and printing "0"
	-- for one is worse than leaving the row out.
	local rows = {
		{ "Damage", cfg.Damage, 120 },
		{ "Magazine", cfg.MagazineSize, 60 },
		{ "Range", cfg.Range, 400 },
		{ "Reload", cfg.ReloadTime, 5 },
	}
	local order = 0
	for _, row in ipairs(rows) do
		local label, value, maximum = row[1], row[2], row[3]
		if type(value) == "number" then
			order += 1
			Components.StatRow(self._stats, label, value, maximum, {
				layoutOrder = order,
				colour = Theme.RarityColour(cfg.Rarity),
			})
		end
	end

	local owned = self._owned[name] == true
	self._equip:SetEnabled(owned)
	self._equip:SetText(owned and "EQUIP" or "NOT OWNED")
end

function Inventory:_equipSelected()
	local name = self._selected
	if not name or not self._owned[name] then
		return
	end
	self._equip:SetText("...")
	task.spawn(function()
		local ok, result = pcall(function()
			return self._remotes.loadoutAction:InvokeServer("equip", name)
		end)
		-- The server is the authority on whether that worked; the button reports what it said
		-- rather than assuming success.
		self._equip:SetText(ok and result ~= false and "EQUIPPED" or "REFUSED")
		task.wait(1)
		if self._selected == name then
			self._equip:SetText("EQUIP")
		end
	end)
end

function Inventory:Toggle()
	self._menu:Toggle()
end

function Inventory:Close()
	self._menu:Close()
end

function Inventory:Destroy()
	for _, card in ipairs(self._cards) do
		card:Destroy()
	end
	self._equip:Destroy()
	self._menu:Destroy()
end

return Inventory
