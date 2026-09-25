--!strict
-- The inventory: everything you own, and what you are taking with you.
--
-- Laid out like the reference inventory: a rail of square category tiles down the left (each
-- showing a real weapon of that kind), a grid of rarity-flooded weapon cards, and the
-- selected weapon big on the right with its stat bars and one green button.
--
-- Ownership is ASKED FOR, never assumed. The panel invokes GetOwnership and draws what the
-- server says; equipping goes back through LoadoutAction and the server decides.
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

local CARD = Vector2.new(148, 140)

-- Weapon classes grouped the way a player thinks about them; anything unmapped falls into
-- OTHER, so a new class still shows up instead of vanishing.
local GROUPS = {
	Rifle = "Rifles", Carbine = "Rifles", LMG = "Rifles", Marksman = "Rifles",
	SMG = "SMGs",
	Shotgun = "Shotguns",
	Sniper = "Snipers",
	Pistol = "Pistols", Revolver = "Pistols",
}
local GROUP_ORDER = { "All", "Rifles", "SMGs", "Shotguns", "Snipers", "Pistols", "Melee", "Other" }
local GROUP_ICON = { All = "🎒", Melee = "🗡️", Other = "📦" }

local function groupFor(cfg): string
	if cfg.Type == "Melee" then
		return "Melee"
	end
	return GROUPS[cfg.Class] or "Other"
end

--- Only the groups that actually have a weapon in them become tiles, and each tile shows a
--- real weapon from its group.
local function buildCategories(): { Menu.Category }
	local present = { All = true }
	local sample: { [string]: string } = {}
	local names = {}
	for name in pairs(WeaponConfig.Weapons) do
		table.insert(names, name)
	end
	table.sort(names)
	for _, name in ipairs(names) do
		local group = groupFor(WeaponConfig.Get(name))
		present[group] = true
		if not sample[group] and WeaponConfig.HasModel(name) then
			sample[group] = name
		end
	end
	local categories = {}
	for _, id in ipairs(GROUP_ORDER) do
		if present[id] then
			table.insert(categories, {
				id = id,
				label = id,
				icon = GROUP_ICON[id],
				preview = not GROUP_ICON[id] and sample[id] or nil,
			})
		end
	end
	return categories
end

-- The headline numbers of a weapon, in the reference armory's terms. Returns rows of
-- { label, value 0..100, display }.
local function statRows(cfg): { { any } }
	if cfg.Type ~= "Gun" then
		return {
			{ "Damage", math.clamp((cfg.Damage or 0), 0, 100), tostring(math.floor(cfg.Damage or 0)) },
			{ "Range", math.clamp((cfg.MeleeRange or 0) / 14 * 100, 0, 100), string.format("%.0f", cfg.MeleeRange or 0) },
		}
	end
	local accuracy = math.clamp(100 - (cfg.SpreadMin or 0) * 14 - (cfg.RecoilPitch or 0) * 5, 5, 100)
	local rpm = 60 / math.max(cfg.FireRate or 1, 0.01)
	local damage = (cfg.Damage or 0) * (cfg.PelletsPerShot or 1)
	return {
		{ "Accuracy", accuracy, string.format("%d", math.floor(accuracy + 0.5)) },
		{ "Damage", math.clamp(damage, 0, 100), string.format("%d", math.floor(damage + 0.5)) },
		{ "Fire Rate", math.clamp(rpm / 1000 * 100, 0, 100), string.format("%d RPM", math.floor(rpm + 0.5)) },
		{ "Magazine", math.clamp((cfg.MagazineSize or 0) / 60 * 100, 0, 100), tostring(cfg.MagazineSize or 0) },
		{ "Range", math.clamp((cfg.Range or 0) / 500 * 100, 0, 100), tostring(math.floor(cfg.Range or 0)) },
		{ "Reload", math.clamp((1 - (cfg.ReloadTime or 0) / 4) * 100, 5, 100), string.format("%.1fs", cfg.ReloadTime or 0) },
	}
end
Inventory.StatRows = statRows

-- --------------------------------------------------------------- detail --

local function buildDetail(self, parent: GuiObject)
	local panel = Components.Panel(parent, {
		name = "Detail",
		colour = Theme.Colour.Sunken,
		radius = Theme.Radius.Card,
		size = UDim2.new(0.4, -Theme.Space.S, 1, 0),
		position = UDim2.new(0.6, Theme.Space.S, 0, 0),
		transparency = 0.2,
	})

	-- The stage: a soft spotlight wash behind the weapon.
	local stage = Instance.new("Frame")
	stage.Name = "Stage"
	stage.BackgroundColor3 = Color3.fromRGB(70, 76, 92)
	stage.BorderSizePixel = 0
	stage.Size = UDim2.new(1, -Theme.Space.L, 0, 150)
	stage.Position = UDim2.fromOffset(Theme.Space.S, Theme.Space.S)
	stage.Parent = panel
	Components.Corner(stage, 10)
	local wash = Instance.new("UIGradient")
	wash.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.95),
		NumberSequenceKeypoint.new(0.5, 0.55),
		NumberSequenceKeypoint.new(1, 0.95),
	})
	wash.Parent = stage

	local preview = Instance.new("Frame")
	preview.Name = "Preview"
	preview.BackgroundTransparency = 1
	preview.Size = UDim2.fromScale(1, 1)
	preview.Parent = stage

	local name = Components.Label(panel, {
		text = "",
		font = Theme.Font.Display,
		size = 28,
		align = Enum.TextXAlignment.Center,
		outline = 2.4,
	})
	name.Size = UDim2.new(1, -Theme.Space.L, 0, 32)
	name.Position = UDim2.fromOffset(Theme.Space.S, 162)

	local chipRow = Instance.new("Frame")
	chipRow.BackgroundTransparency = 1
	chipRow.Size = UDim2.new(1, 0, 0, 22)
	chipRow.Position = UDim2.fromOffset(0, 196)
	chipRow.Parent = panel
	local chips = Components.List(chipRow, Enum.FillDirection.Horizontal, 6, Enum.HorizontalAlignment.Center)
	chips.VerticalAlignment = Enum.VerticalAlignment.Center

	local description = Components.Label(panel, {
		text = "",
		font = Theme.Font.Medium,
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
		wrap = true,
	})
	description.Size = UDim2.new(1, -Theme.Space.XL, 0, 34)
	description.Position = UDim2.fromOffset(Theme.Space.M, 222)
	description.TextYAlignment = Enum.TextYAlignment.Top

	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.BackgroundTransparency = 1
	stats.Size = UDim2.new(1, -Theme.Space.L, 0, 170)
	stats.Position = UDim2.fromOffset(Theme.Space.XS, 262)
	stats.Parent = panel
	Components.List(stats, Enum.FillDirection.Vertical, 3)

	self._preview, self._name, self._chips, self._description, self._stats =
		preview, name, chipRow, description, stats
end

-- ------------------------------------------------------------------ api --

function Inventory.new(parent: Instance, remotes: { getOwnership: RemoteFunction, loadoutAction: RemoteFunction })
	local self = setmetatable({}, Inventory)

	self._remotes = remotes
	self._cards = {}
	self._cardByName = {}
	self._owned = {}
	self._selected = nil

	local menu = Menu.new(parent, {
		id = "Inventory",
		title = "Inventory",
		subtitle = "Equip & inspect every weapon you own",
		icon = "🎒",
		size = UDim2.fromOffset(980, 590),
		categories = buildCategories(),
	})
	self._menu = menu

	local scroller = Instance.new("ScrollingFrame")
	scroller.Name = "Grid"
	scroller.BackgroundTransparency = 1
	scroller.BorderSizePixel = 0
	scroller.Size = UDim2.new(0.6, -Theme.Space.S, 1, 0)
	scroller.CanvasSize = UDim2.new()
	scroller.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroller.ScrollBarThickness = 4
	scroller.ScrollBarImageColor3 = Theme.Colour.Stroke
	scroller.Parent = menu.content
	local grid = Components.Grid(scroller, CARD, Theme.Space.M)
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Center
	Components.Padding(scroller, 6)
	self._grid = scroller

	buildDetail(self, menu.content)

	self._equip = Components.Button(menu.content, {
		name = "Equip",
		text = "EQUIP",
		primary = true,
		textSize = 22,
		size = UDim2.new(0.4, -Theme.Space.XL, 0, 48),
		position = UDim2.new(0.6, Theme.Space.M + 4, 1, -Theme.Space.S),
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
	table.clear(self._cardByName)

	-- Owned first, then by rarity, then alphabetically: what you can actually use is at the
	-- top, and the order never jitters between opens.
	local names = {}
	for name in pairs(WeaponConfig.Weapons) do
		local cfg = WeaponConfig.Get(name)
		if group == "All" or groupFor(cfg) == group then
			table.insert(names, name)
		end
	end
	table.sort(names, function(a, b)
		local ownedA, ownedB = self._owned[a] == true, self._owned[b] == true
		if ownedA ~= ownedB then
			return ownedA
		end
		local rarityA = Theme.Rarity[WeaponConfig.Get(a).Rarity or "Common"]
		local rarityB = Theme.Rarity[WeaponConfig.Get(b).Rarity or "Common"]
		local orderA = rarityA and rarityA.order or 0
		local orderB = rarityB and rarityB.order or 0
		if orderA ~= orderB then
			return orderA > orderB
		end
		return a < b
	end)

	for index, name in ipairs(names) do
		local cfg = WeaponConfig.Get(name)
		local owned = self._owned[name] == true
		local card = Components.Card(self._grid, {
			title = name,
			rarity = cfg.Rarity,
			subtitle = owned and string.upper(cfg.Rarity or "") or "LOCKED",
			locked = not owned,
			layoutOrder = index,
			onActivated = function()
				self._picked = true
				self:_select(name)
			end,
		})
		card.instance.Size = UDim2.fromOffset(CARD.X, CARD.Y)
		-- A real render of the weapon, the same one the hotbar and armory show.
		local holder = Instance.new("Frame")
		holder.Name = "Preview"
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(1, -12, 0, 76)
		holder.Position = UDim2.fromOffset(6, 12)
		holder.Parent = card.instance
		pcall(function()
			WeaponPreview.Icon(holder, name, { Dim = owned and 0 or 0.45 })
		end)
		table.insert(self._cards, card)
		self._cardByName[name] = card
	end

	-- Never leave the detail side blank. Keep a selection the player made if it survived the
	-- filter; otherwise open on the first gun they OWN. The first draw happens before
	-- ownership arrives, and falling to "the first card" then parked the panel on a locked
	-- Mythic every time it opened.
	local firstOwned: string? = nil
	for _, name in ipairs(names) do
		if self._owned[name] then
			firstOwned = name
			break
		end
	end
	local keep = self._selected and table.find(names, self._selected)
		and (self._picked or self._owned[self._selected])
	if keep then
		self:_select(self._selected)
	elseif firstOwned then
		self:_select(firstOwned)
	elseif names[1] then
		self:_select(names[1])
	end
end

function Inventory:_select(name: string)
	self._selected = name
	local cfg = WeaponConfig.Get(name)
	if not cfg then
		return
	end

	for cardName, card in pairs(self._cardByName) do
		card:SetSelected(cardName == name)
	end

	self._preview:ClearAllChildren()
	pcall(function()
		WeaponPreview.Icon(self._preview, name, { Zoom = 1.15 })
	end)

	local rarityColour = Theme.RarityColour(cfg.Rarity)
	self._name.Text = name
	self._name.TextColor3 = Theme.Shade(rarityColour, 0.55)
	self._description.Text = cfg.Description or ""

	for _, child in ipairs(self._chips:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	Components.Chip(self._chips, cfg.Rarity or "Common", rarityColour, { layoutOrder = 1 })
	Components.Chip(self._chips, cfg.Class or cfg.Type or "", Theme.Colour.PanelRaised, { layoutOrder = 2 })
	if cfg.Type == "Gun" then
		Components.Chip(self._chips, cfg.Automatic and "Auto" or "Semi", Theme.Colour.PanelRaised, { layoutOrder = 3 })
	end

	for _, child in ipairs(self._stats:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	for order, row in ipairs(statRows(cfg)) do
		Components.StatRow(self._stats, row[1], row[2], 100, {
			layoutOrder = order,
			display = row[3],
		})
	end

	local owned = self._owned[name] == true
	self._equip:SetEnabled(owned)
	self._equip:SetText(owned and "EQUIP" or "🔒 LOCKED")
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
		-- The server is the authority on whether that worked.
		self._equip:SetText(ok and result ~= false and "EQUIPPED ✓" or "REFUSED")
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
