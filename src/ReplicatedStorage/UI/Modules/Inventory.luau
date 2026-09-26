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
--
-- The ✨ VFX button beside EQUIP flips the stat bars over to the gun's VFX: which kill effect
-- and which tracer THIS gun uses. "Default" follows whatever is equipped in the shop, "None"
-- plays nothing on this gun, and any owned effect can be picked; the ones not owned yet are
-- shown locked so you know what there is. The server checks ownership (VFXAction).

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menu = require(script.Parent.Menu)
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))
local GunHandling = require(ReplicatedStorage:WaitForChild("GunHandling"))
local WeaponPreview = require(ReplicatedStorage:WaitForChild("WeaponPreview"))
local VFXConfig = require(ReplicatedStorage:WaitForChild("VFXConfig"))
local UISound = require(script.Parent.UISound)

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
	local traits = GunHandling.Traits(cfg)
	local mobility = math.clamp(100 - traits.MoveSpread * 16 - traits.JumpSpread * 3, 5, 100)
	local pierce = traits.Penetration
	local pierceWord = pierce <= 0 and "None" or (pierce < 1 and "Light" or (pierce < 2.5 and "Medium" or "Heavy"))
	local tactical = GunHandling.ReloadTime(cfg, 1)
	return {
		{ "Damage", math.clamp(damage, 0, 100), string.format("%d", math.floor(damage + 0.5)) },
		{ "Fire Rate", math.clamp(rpm / 1000 * 100, 0, 100), string.format("%d RPM", math.floor(rpm + 0.5)) },
		{ "Accuracy", accuracy, string.format("%d", math.floor(accuracy + 0.5)) },
		{ "Mobility", mobility, string.format("%d", math.floor(mobility + 0.5)) },
		{ "Range", math.clamp((cfg.Range or 0) / 500 * 100, 0, 100), tostring(math.floor(cfg.Range or 0)) },
		{ "Penetration", math.clamp(pierce / 3.4 * 100, 0, 100), pierceWord },
		{ "Magazine", math.clamp((cfg.MagazineSize or 0) / 60 * 100, 0, 100), tostring(cfg.MagazineSize or 0) },
		{ "Reload", math.clamp((1 - (cfg.ReloadTime or 0) / 4) * 100, 5, 100),
			string.format("%.1fs / %.1fs", tactical, cfg.ReloadTime or 0) },
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
	stage.Size = UDim2.new(1, -Theme.Space.L, 0, 124)
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
	name.Position = UDim2.fromOffset(Theme.Space.S, 134)

	local chipRow = Instance.new("Frame")
	chipRow.BackgroundTransparency = 1
	chipRow.Size = UDim2.new(1, 0, 0, 22)
	chipRow.Position = UDim2.fromOffset(0, 168)
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
	description.Position = UDim2.fromOffset(Theme.Space.M, 194)
	description.TextYAlignment = Enum.TextYAlignment.Top

	local stats = Instance.new("Frame")
	stats.Name = "Stats"
	stats.BackgroundTransparency = 1
	stats.Size = UDim2.new(1, -Theme.Space.L, 0, 200)
	stats.Position = UDim2.fromOffset(Theme.Space.XS, 232)
	stats.Parent = panel
	Components.List(stats, Enum.FillDirection.Vertical, 2)

	-- The VFX side: the same space as the stat bars, shown instead of them.
	local vfx = Instance.new("Frame")
	vfx.Name = "VFX"
	vfx.BackgroundTransparency = 1
	vfx.Size = UDim2.new(1, -Theme.Space.L, 0, 200)
	vfx.Position = UDim2.fromOffset(Theme.Space.S, 232)
	vfx.Visible = false
	vfx.Parent = panel
	Components.List(vfx, Enum.FillDirection.Vertical, 8)

	self._preview, self._name, self._chips, self._description, self._stats, self._vfx =
		preview, name, chipRow, description, stats, vfx
end

-- ------------------------------------------------------------------ vfx --

local TILE = 60
local ICON_DEFAULT, ICON_NONE = "↺", "⦸"

local function ownTracer(weapon: string): boolean
	local ok, has = pcall(function()
		local CombatFX = (require :: any)(ReplicatedStorage:FindFirstChild("CombatFX"))
		return CombatFX.HasOwnTracer(weapon)
	end)
	return ok and has == true
end

-- One choice: a square tile with its icon and a short name; the one in use is ringed white.
local function tile(parent: GuiObject, order: number, icon: string, label: string, colour: Color3, selected: boolean,
	locked: boolean, onPick: (() -> ())?): TextButton
	local t = Instance.new("TextButton")
	t.Name = label
	t.AutoButtonColor = false
	t.Text = ""
	t.LayoutOrder = order
	t.Size = UDim2.fromOffset(TILE, TILE + 12)
	t.BackgroundColor3 = if selected then colour:Lerp(Theme.Colour.Panel, 0.45) else Theme.Colour.PanelRaised
	t.BackgroundTransparency = if locked then 0.45 else 0
	t.Parent = parent
	Components.Corner(t, 8)
	local edge = Components.Stroke(t, if selected then Color3.new(1, 1, 1) else colour, if selected then 3 else 1.6)
	edge.Transparency = if locked then 0.6 else 0
	Components.Gradient(t)
	local glyph = Components.Icon(t, if locked then "🔒" else icon, 26)
	glyph.AnchorPoint = Vector2.new(0.5, 0)
	glyph.Position = UDim2.new(0.5, 0, 0, 6)
	glyph.Size = UDim2.fromOffset(TILE, 32)
	glyph.TextTransparency = if locked then 0.35 else 0
	local name = Components.Label(t, {
		text = string.upper(label),
		face = Theme.Face.Condensed,
		size = 12,
		align = Enum.TextXAlignment.Center,
		colour = if locked then Theme.Colour.TextMuted else Theme.Colour.Text,
		outline = 1.2,
	})
	name.Position = UDim2.new(0, 2, 1, -24)
	name.Size = UDim2.new(1, -4, 0, 20)
	name.TextWrapped = true
	name.TextScaled = true
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 12
	cap.MinTextSize = 8
	cap.Parent = name
	if selected then
		local tick = Components.Icon(t, "✓", 14)
		tick.AnchorPoint = Vector2.new(1, 0)
		tick.Position = UDim2.new(1, -2, 0, 1)
		tick.Size = UDim2.fromOffset(16, 16)
	end
	t.Activated:Connect(function()
		if onPick then
			onPick()
		else
			UISound.Play("Clunk")
		end
	end)
	return t
end

--- What this gun uses in `slot`: "default", "none", or an effect id.
function Inventory:_choice(weapon: string, slot: string): string
	local mine = self._vfxOverride[weapon]
	if mine and mine[slot] ~= nil then
		return mine[slot]
	end
	local published = VFXConfig.WeaponChoices(Players.LocalPlayer)[weapon]
	local id = published and published[slot]
	return if type(id) == "string" then id else "default"
end

function Inventory:_pickVFX(weapon: string, slot: string, choice: string)
	if self:_choice(weapon, slot) == choice or not self._remotes.vfxAction then
		return
	end
	UISound.Play("Click")
	self._vfxOverride[weapon] = self._vfxOverride[weapon] or {}
	self._vfxOverride[weapon][slot] = choice
	self:_drawVFX()
	task.spawn(function()
		local ok, result = pcall(function()
			return (self._remotes.vfxAction :: RemoteFunction):InvokeServer("equipWeapon", weapon, slot,
				if choice == "default" then nil else choice)
		end)
		if not ok or type(result) ~= "table" or not result.ok then
			-- Refused: put it back to what the server has.
			self._vfxOverride[weapon][slot] = nil
			self:_drawVFX()
		end
	end)
end

--- The VFX side for the selected gun: a row of kill effects and a row of tracers.
function Inventory:_drawVFX()
	local root = self._vfx
	if not root or not root.Visible then
		return
	end
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("GuiObject") then
			child:Destroy()
		end
	end
	local weapon = self._selected
	local cfg = weapon and WeaponConfig.Get(weapon)
	if not weapon or not cfg then
		return
	end
	local ownsGun = self._owned[weapon] == true
	local player = Players.LocalPlayer
	for order, slot in ipairs(VFXConfig.Slots) do
		local section = Instance.new("Frame")
		section.Name = slot
		section.BackgroundTransparency = 1
		section.LayoutOrder = order
		section.Size = UDim2.new(1, 0, 0, 96)
		section.Parent = root

		local current = self:_choice(weapon, slot)
		local equipped = player:GetAttribute(VFXConfig.Attribute[slot])
		local equippedItem = VFXConfig.Get(if type(equipped) == "string" then equipped else nil)
		local currentItem = VFXConfig.Get(current)
		local heading = Components.Label(section, {
			text = string.upper(VFXConfig.SlotLabels[slot] or slot),
			face = Theme.Face.Condensed,
			size = 16,
			colour = Theme.Colour.TextDim,
			outline = 1.4,
		})
		heading.Size = UDim2.new(0.5, 0, 0, 18)
		local now = Components.Label(section, {
			text = if currentItem then string.upper(currentItem.name)
				elseif current == VFXConfig.NONE then "NONE"
				else ("DEFAULT · " .. (if equippedItem then string.upper(equippedItem.name) else "NONE EQUIPPED")),
			face = Theme.Face.Condensed,
			size = 16,
			colour = if currentItem then Theme.RarityColour(currentItem.rarity) else Theme.Colour.Text,
			align = Enum.TextXAlignment.Right,
			outline = 1.4,
		})
		now.Position = UDim2.fromScale(0.3, 0)
		now.Size = UDim2.new(0.7, 0, 0, 18)

		local row = Instance.new("ScrollingFrame")
		row.Name = "Choices"
		row.BackgroundTransparency = 1
		row.BorderSizePixel = 0
		row.Position = UDim2.fromOffset(0, 22)
		row.Size = UDim2.new(1, 0, 0, TILE + 16)
		row.CanvasSize = UDim2.new()
		row.AutomaticCanvasSize = Enum.AutomaticSize.X
		row.ScrollingDirection = Enum.ScrollingDirection.X
		row.ScrollBarThickness = 3
		row.ScrollBarImageColor3 = Theme.Colour.Stroke
		row.Parent = section
		Components.List(row, Enum.FillDirection.Horizontal, 6)

		local note: string? = nil
		if not ownsGun then
			note = "Own this weapon to choose its VFX"
		elseif slot == "Tracer" and cfg.Type ~= "Gun" then
			note = "Melee weapons fire no tracer"
		elseif slot == "Tracer" and ownTracer(weapon) then
			note = "This gun fires its own tracer -- that look is what it is"
		end
		if note then
			local l = Components.Label(row, {
				text = note,
				font = Theme.Font.Medium,
				size = Theme.Text.Small,
				colour = Theme.Colour.TextMuted,
			})
			l.Size = UDim2.new(1, 0, 0, TILE)
			continue
		end

		tile(row, 1, ICON_DEFAULT, "Default", Theme.Colour.Info, current == "default", false, function()
			self:_pickVFX(weapon, slot, "default")
		end)
		tile(row, 2, ICON_NONE, "None", Theme.Colour.Stroke, current == VFXConfig.NONE, false, function()
			self:_pickVFX(weapon, slot, VFXConfig.NONE)
		end)
		local n = 2
		for _, item in ipairs(VFXConfig.Items) do
			if item.slot == slot then
				n += 1
				local owned = self._ownedVFX[item.id] == true
				tile(row, n, item.icon, item.name, Theme.RarityColour(item.rarity), current == item.id, not owned,
					if owned then function()
						self:_pickVFX(weapon, slot, item.id)
					end else nil)
			end
		end
	end
end

function Inventory:_showVFX(on: boolean)
	self._vfxShown = on
	self._vfx.Visible = on
	self._stats.Visible = not on
	self._vfxButton:SetText(on and "◀ STATS" or "✨ VFX")
	self._vfxButton:SetSelected(on)
	if on then
		self:_drawVFX()
	end
end

-- ------------------------------------------------------------------ api --

function Inventory.new(parent: Instance, remotes: { getOwnership: RemoteFunction, loadoutAction: RemoteFunction,
	vfxAction: RemoteFunction? })
	local self = setmetatable({}, Inventory)

	self._remotes = remotes
	self._cards = {}
	self._cardByName = {}
	self._owned = {}
	self._ownedVFX = {}
	self._vfxOverride = {}
	self._vfxShown = false
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
		size = UDim2.new(0.4, -Theme.Space.XL - 124, 0, 48),
		position = UDim2.new(0.6, Theme.Space.M + 4, 1, -Theme.Space.S),
		anchor = Vector2.new(0, 1),
		onActivated = function()
			self:_equipSelected()
		end,
	})
	self._equip:SetEnabled(false)
	self._vfxButton = Components.Button(menu.content, {
		name = "VFXToggle",
		text = "✨ VFX",
		textSize = 20,
		colour = Theme.Colour.Xp,
		size = UDim2.fromOffset(116, 48),
		position = UDim2.new(1, -Theme.Space.S, 1, -Theme.Space.S),
		anchor = Vector2.new(1, 1),
		onActivated = function()
			self:_showVFX(not self._vfxShown)
		end,
	})
	-- Choices made elsewhere (or confirmed by the server) come back as attributes.
	local player = Players.LocalPlayer
	for _, attribute in ipairs({ VFXConfig.WeaponAttribute, VFXConfig.Attribute.Kill, VFXConfig.Attribute.Tracer }) do
		player:GetAttributeChangedSignal(attribute):Connect(function()
			table.clear(self._vfxOverride)
			self:_drawVFX()
		end)
	end

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
		local owned, ownedVFX = {}, {}
		if ok and type(result) == "table" and type(result.OwnedItems) == "table" then
			for _, id in ipairs(result.OwnedItems) do
				owned[id] = true
			end
		end
		if ok and type(result) == "table" and type(result.OwnedVFX) == "table" then
			for _, id in ipairs(result.OwnedVFX) do
				ownedVFX[id] = true
			end
		end
		self._owned, self._ownedVFX = owned, ownedVFX
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
			height = 22,
		})
	end

	local owned = self._owned[name] == true
	self._equip:SetEnabled(owned)
	self._equip:SetText(owned and "EQUIP" or "🔒 LOCKED")
	self:_drawVFX()
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
	self._vfxButton:Destroy()
	self._menu:Destroy()
end

return Inventory
