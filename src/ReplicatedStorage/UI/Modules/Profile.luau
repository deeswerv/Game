--!strict
-- The profile card: the numbers a player is identified by.
--
-- Laid out like the reference card, because this is the screen players screenshot:
--   * your avatar's headshot in a ring, display name big over the @handle, the gold level
--     diamond and the platform you are on in the corner;
--   * the two headline pairs -- a trophy with Wins / Win Rate in gold, a target with
--     Kills / KD in red -- in outlined gradient numerals;
--   * "Most Played Weapons" as a row of green cards with the real weapon on each.
--
-- Draws only, and only from the server's own summary. Every figure is derived server-side,
-- so there is nothing here a client could inflate by editing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menu = require(script.Parent.Menu)
local WeaponPreview = require(ReplicatedStorage:WaitForChild("WeaponPreview"))

local Profile = {}
Profile.__index = Profile

local GOLD_TOP = Color3.fromRGB(255, 240, 120)
local GOLD_BOTTOM = Color3.fromRGB(255, 170, 20)
local RED_TOP = Color3.fromRGB(255, 90, 90)
local RED_BOTTOM = Color3.fromRGB(200, 10, 20)
local WEAPON_GREEN = Color3.fromRGB(40, 190, 70)

local TIER_COLOUR = {
	Bronze = Color3.fromRGB(205, 127, 72),
	Silver = Color3.fromRGB(196, 204, 218),
	Gold = Color3.fromRGB(255, 196, 40),
	Platinum = Color3.fromRGB(110, 224, 226),
	Diamond = Color3.fromRGB(120, 180, 255),
	Champion = Color3.fromRGB(255, 70, 110),
}

local function platformGlyph(): string
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "📱"
	elseif UserInputService.GamepadEnabled and not UserInputService.KeyboardEnabled then
		return "🎮"
	end
	return "🖥️"
end

--- A big outlined gradient number with a small caption under it.
local function figure(parent: GuiObject, caption: string, top: Color3, bottom: Color3, order: number): TextLabel
	local holder = Instance.new("Frame")
	holder.Name = caption
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(92, 60)
	holder.LayoutOrder = order
	holder.Parent = parent

	local value = Components.Label(holder, {
		text = "-",
		font = Theme.Font.Display,
		size = 32,
		colour = Color3.new(1, 1, 1),
		align = Enum.TextXAlignment.Center,
		outline = 2.6,
	})
	value.Size = UDim2.new(1, 0, 0, 36)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(top, bottom)
	g.Rotation = 90
	g.Parent = value

	local label = Components.Label(holder, {
		text = caption,
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		colour = bottom:Lerp(top, 0.3),
		align = Enum.TextXAlignment.Center,
	})
	label.Size = UDim2.new(1, 0, 0, 18)
	label.Position = UDim2.fromOffset(0, 38)
	return value
end

local function slash(parent: GuiObject, colour: Color3, order: number)
	local s = Components.Label(parent, {
		text = "/",
		font = Theme.Font.Display,
		size = 40,
		colour = colour,
		autoSize = true,
		layoutOrder = order,
	})
	s.Rotation = 8
end

local function statGroup(parent: GuiObject, glyph: string, position: UDim2): Frame
	local group = Instance.new("Frame")
	group.BackgroundTransparency = 1
	group.Size = UDim2.fromOffset(0, 60)
	group.AutomaticSize = Enum.AutomaticSize.X
	group.Position = position
	group.Parent = parent
	local row = Components.List(group, Enum.FillDirection.Horizontal, 4)
	row.VerticalAlignment = Enum.VerticalAlignment.Center
	local icon = Components.Icon(group, glyph, 40)
	icon.LayoutOrder = 0
	return group
end

function Profile.new(parent: Instance, remotes)
	local self = setmetatable({}, Profile)
	self._remotes = remotes
	self._weaponCards = {}

	local menu = Menu.new(parent, {
		id = "Profile",
		title = "Profile",
		size = UDim2.fromOffset(640, 420),
		bare = true,
	})
	self._menu = menu
	local content = menu.content

	-- ------------------------------------------------------- identity --

	local player = Players.LocalPlayer
	local avatar = Instance.new("ImageLabel")
	avatar.Name = "Avatar"
	avatar.BackgroundColor3 = Color3.fromRGB(70, 74, 86)
	avatar.Size = UDim2.fromOffset(96, 96)
	avatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", player.UserId)
	avatar.Parent = content
	Components.Corner(avatar, 48)
	Components.Stroke(avatar, Color3.new(1, 1, 1), 3).Transparency = 0.2
	Components.Gradient(avatar, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 160))

	self._name = Components.Label(content, {
		text = player.DisplayName,
		font = Theme.Font.Bold,
		size = 36,
		outline = 2.6,
	})
	self._name.Size = UDim2.new(1, -200, 0, 40)
	self._name.Position = UDim2.fromOffset(110, 8)
	self._name.TextTruncate = Enum.TextTruncate.AtEnd

	self._handle = Components.Label(content, {
		text = "@" .. player.Name,
		font = Theme.Font.Bold,
		size = 20,
		colour = Theme.Colour.TextMuted,
	})
	self._handle.Size = UDim2.new(1, -200, 0, 22)
	self._handle.Position = UDim2.fromOffset(110, 48)

	self._tier = Components.Label(content, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		colour = Theme.Colour.TextDim,
	})
	self._tier.Size = UDim2.new(1, -200, 0, 20)
	self._tier.Position = UDim2.fromOffset(110, 72)

	local badge, level = Components.LevelBadge(content, 60)
	badge.AnchorPoint = Vector2.new(1, 0)
	badge.Position = UDim2.new(1, -24, 0, 0)
	self._level = level

	local platform = Components.Icon(content, platformGlyph(), 34)
	platform.AnchorPoint = Vector2.new(0.5, 0)
	platform.Position = UDim2.new(1, -54, 0, 62)

	-- ---------------------------------------------------------- stats --

	local wins = statGroup(content, "🏆", UDim2.fromOffset(6, 110))
	self._wins = figure(wins, "Wins", GOLD_TOP, GOLD_BOTTOM, 1)
	slash(wins, GOLD_BOTTOM, 2)
	self._winRate = figure(wins, "Win Rate", GOLD_TOP, GOLD_BOTTOM, 3)

	local kills = statGroup(content, "🎯", UDim2.new(0.52, 0, 0, 110))
	self._kills = figure(kills, "Kills", RED_TOP, RED_BOTTOM, 1)
	slash(kills, RED_BOTTOM, 2)
	self._kd = figure(kills, "KD", RED_TOP, RED_BOTTOM, 3)

	-- --------------------------------------------------------- weapons --

	local heading = Components.Label(content, {
		text = "Most Played Weapons",
		font = Theme.Font.Bold,
		size = 18,
		colour = Theme.Colour.TextMuted,
		align = Enum.TextXAlignment.Center,
	})
	heading.Size = UDim2.new(1, 0, 0, 22)
	heading.Position = UDim2.fromOffset(0, 186)

	self._weapons = Instance.new("Frame")
	self._weapons.Name = "Weapons"
	self._weapons.BackgroundTransparency = 1
	self._weapons.Size = UDim2.new(1, 0, 0, 104)
	self._weapons.Position = UDim2.fromOffset(0, 214)
	self._weapons.Parent = content
	local row = Components.List(self._weapons, Enum.FillDirection.Horizontal, 14, Enum.HorizontalAlignment.Center)
	row.VerticalAlignment = Enum.VerticalAlignment.Center

	self._empty = Components.Label(content, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		colour = Theme.Colour.TextMuted,
		align = Enum.TextXAlignment.Center,
	})
	self._empty.Size = UDim2.new(1, 0, 0, 20)
	self._empty.Position = UDim2.fromOffset(0, 254)

	-- --------------------------------------------------------- record --

	self._record = Components.Label(content, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
	})
	self._record.Size = UDim2.new(1, 0, 0, 18)
	self._record.Position = UDim2.new(0, 0, 1, -40)

	-- The next rung of the unlock ladder, so levelling has a visible destination.
	self._unlock = Components.Label(content, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		colour = Theme.Colour.Level,
		align = Enum.TextXAlignment.Center,
	})
	self._unlock.Size = UDim2.new(1, 0, 0, 18)
	self._unlock.Position = UDim2.new(0, 0, 1, -20)

	menu:OnOpen(function()
		self:Refresh()
	end)

	return self
end

function Profile:Refresh()
	task.spawn(function()
		local ok, summary = pcall(function()
			return self._remotes.profileRequest:InvokeServer()
		end)
		if ok and type(summary) == "table" then
			self:_render(summary)
		end
	end)
end

function Profile:_render(s)
	if type(s.name) == "string" and s.name ~= "" then
		self._name.Text = s.name
	end
	if type(s.handle) == "string" and s.handle ~= "" then
		self._handle.Text = string.sub(s.handle, 1, 1) == "@" and s.handle or ("@" .. s.handle)
	end

	local tier = tostring(s.tier or "Bronze")
	local title = type(s.title) == "string" and s.title ~= "" and s.title or nil
	self._tier.Text = string.format("%s  ·  %d elo%s", string.upper(tier),
		math.floor(tonumber(s.rating) or 0), title and ("  ·  " .. title) or "")
	self._tier.TextColor3 = TIER_COLOUR[tier] or Theme.Colour.TextDim
	self._level.Text = tostring(math.floor(tonumber(s.level) or 1))

	self._wins.Text = tostring(math.floor(tonumber(s.wins) or 0))

	-- An unplayed win rate is "-", not "0%": nobody with no matches has a zero record.
	local decided = tonumber(s.decided) or 0
	self._winRate.Text = decided > 0 and string.format("%.1f%%", tonumber(s.winRate) or 0) or "-"

	self._kills.Text = tostring(math.floor(tonumber(s.kills) or 0))

	-- A ratio with no denominator is not a ratio.
	local deaths = math.floor(tonumber(s.deaths) or 0)
	local kd = tonumber(s.kd) or 0
	self._kd.Text = deaths > 0 and string.format("%.1f", kd) or "-"

	local streak = math.floor(tonumber(s.streak) or 0)
	local streakText = streak > 0 and string.format("  ·  %d win streak", streak)
		or streak < 0 and string.format("  ·  %d lost in a row", -streak)
		or ""
	-- Street Cred: standing with Downtown, published by the server (TurfWarService).
	local cred = tonumber(Players.LocalPlayer:GetAttribute("StreetCred")) or 0
	local credBand = if cred >= 75 then "Honoured" elseif cred >= 30 then "Friendly" else nil
	self._record.Text = string.format("%d W  ·  %d L  ·  %d D%s%s  ·  %d Street Cred%s",
		math.floor(tonumber(s.wins) or 0),
		math.floor(tonumber(s.losses) or 0),
		math.floor(tonumber(s.draws) or 0),
		streakText,
		(tonumber(s.prestige) or 0) > 0 and string.format("  ·  prestige %d", s.prestige) or "",
		math.floor(cred), if credBand then (" (" .. credBand .. ")") else "")

	local unlock = type(s.nextUnlock) == "table" and s.nextUnlock or nil
	self._unlock.Text = unlock
		and string.format("Next unlock:  %s at level %d", tostring(unlock.name), math.floor(tonumber(unlock.level) or 0))
		or "Every weapon unlocked"

	-- ------------------------------------------------------- weapons --

	for _, card in ipairs(self._weaponCards) do
		card:Destroy()
	end
	table.clear(self._weaponCards)

	local weapons = type(s.weapons) == "table" and s.weapons or {}
	self._empty.Text = #weapons == 0 and "No kills recorded yet  -  go get one!" or ""

	local mastery = {}
	for _, entry in ipairs(type(s.mastery) == "table" and s.mastery or {}) do
		if type(entry) == "table" and entry.name then
			mastery[entry.name] = entry
		end
	end

	for index, entry in ipairs(weapons) do
		if index > 3 then
			break
		end
		local rank = mastery[entry.name]
		local card = Components.Card(self._weapons, {
			title = tostring(entry.name),
			subtitle = string.format("%d kills%s", math.floor(tonumber(entry.kills) or 0),
				rank and rank.tier and ("  ·  " .. string.upper(rank.tier)) or ""),
			colour = WEAPON_GREEN,
			layoutOrder = index,
		})
		card.instance.Size = UDim2.fromOffset(150, 100)
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(1, -12, 0, 54)
		holder.Position = UDim2.fromOffset(6, 6)
		holder.Parent = card.instance
		pcall(function()
			WeaponPreview.Icon(holder, tostring(entry.name), { Zoom = 1.15 })
		end)
		table.insert(self._weaponCards, card)
	end
end

function Profile:Toggle()
	self._menu:Toggle()
end

function Profile:Close()
	self._menu:Close()
end

function Profile:Destroy()
	for _, card in ipairs(self._weaponCards) do
		card:Destroy()
	end
	self._menu:Destroy()
end

return Profile
