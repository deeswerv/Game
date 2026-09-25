--!strict
-- The profile card: the numbers a player is identified by.
--
-- Modelled on the reference card -- name over handle, a row of headline figures, then the
-- weapons you actually use. This is the screen players screenshot, so the figures get the
-- weight and everything else gets out of the way.
--
-- Draws only, and only from the server's own summary. Every figure -- win rate, K/D, the
-- favourite weapons -- is derived server-side from the profile, so there is nothing here a
-- client could inflate by editing.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menu = require(script.Parent.Menu)
local WeaponPreview = require(ReplicatedStorage:WaitForChild("WeaponPreview"))

local Profile = {}
Profile.__index = Profile

-- Tier colours borrow the rarity ladder, so a rank and a rarity of the same standing read as
-- the same kind of achievement rather than two unrelated palettes.
local TIER_COLOUR = {
	Bronze = Theme.Rarity.Common.colour,
	Silver = Theme.Rarity.Uncommon.colour,
	Gold = Theme.Rarity.Legendary.colour,
	Platinum = Theme.Rarity.Rare.colour,
	Diamond = Theme.Rarity.Epic.colour,
	Champion = Theme.Rarity.Mythic.colour,
}

local function statTile(parent: GuiObject, order: number, label: string)
	local tile = Instance.new("Frame")
	tile.Name = label
	tile.BackgroundColor3 = Theme.Colour.Sunken
	tile.BorderSizePixel = 0
	tile.Size = UDim2.fromOffset(150, 74)
	tile.LayoutOrder = order
	tile.Parent = parent
	Components.Corner(tile, Theme.Radius.Card)

	local value = Components.Label(tile, {
		text = "-",
		font = Theme.Font.Display,
		size = Theme.Text.Huge,
		align = Enum.TextXAlignment.Center,
	})
	value.Size = UDim2.new(1, 0, 0, 40)
	value.Position = UDim2.fromOffset(0, 10)

	local caption = Components.Label(tile, {
		text = label,
		caps = true,
		size = Theme.Text.Micro,
		align = Enum.TextXAlignment.Center,
	})
	caption.Size = UDim2.new(1, 0, 0, 14)
	caption.Position = UDim2.fromOffset(0, 52)

	return value
end

function Profile.new(parent: Instance, remotes)
	local self = setmetatable({}, Profile)
	self._remotes = remotes
	self._weaponCards = {}

	local menu = Menu.new(parent, {
		id = "Profile",
		title = "PROFILE",
		size = UDim2.fromOffset(700, 470),
	})
	self._menu = menu

	-- ------------------------------------------------------- identity --

	self._name = Components.Label(menu.content, {
		text = "",
		font = Theme.Font.Display,
		size = Theme.Text.Title,
	})
	self._name.Size = UDim2.new(1, -140, 0, 28)

	self._handle = Components.Label(menu.content, {
		text = "",
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
	})
	self._handle.Size = UDim2.new(1, -140, 0, 16)
	self._handle.Position = UDim2.fromOffset(0, 28)

	-- Rank sits opposite the name: the two things that say who you are.
	self._tier = Components.Label(menu.content, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Large,
		align = Enum.TextXAlignment.Right,
	})
	self._tier.Size = UDim2.fromOffset(200, 22)
	self._tier.Position = UDim2.new(1, -200, 0, 4)

	self._rating = Components.Label(menu.content, {
		text = "",
		caps = true,
		size = Theme.Text.Micro,
		align = Enum.TextXAlignment.Right,
	})
	self._rating.Size = UDim2.fromOffset(200, 14)
	self._rating.Position = UDim2.new(1, -200, 0, 28)

	-- ---------------------------------------------------------- stats --

	local row = Instance.new("Frame")
	row.Name = "Stats"
	row.BackgroundTransparency = 1
	row.Size = UDim2.new(1, 0, 0, 74)
	row.Position = UDim2.fromOffset(0, 58)
	row.Parent = menu.content
	Components.List(row, Enum.FillDirection.Horizontal, Theme.Space.M)

	self._wins = statTile(row, 1, "Wins")
	self._winRate = statTile(row, 2, "Win Rate")
	self._kills = statTile(row, 3, "Kills")
	self._kd = statTile(row, 4, "K/D")

	-- --------------------------------------------------------- record --

	self._record = Components.Label(menu.content, {
		text = "",
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
	})
	self._record.Size = UDim2.new(1, 0, 0, 18)
	self._record.Position = UDim2.fromOffset(0, 140)

	-- -------------------------------------------------------- weapons --

	local heading = Components.Label(menu.content, {
		text = "Most used weapons",
		caps = true,
		size = Theme.Text.Micro,
	})
	heading.Size = UDim2.new(1, 0, 0, 16)
	heading.Position = UDim2.fromOffset(0, 186)

	self._weapons = Instance.new("Frame")
	self._weapons.Name = "Weapons"
	self._weapons.BackgroundTransparency = 1
	self._weapons.Size = UDim2.new(1, 0, 0, 132)
	self._weapons.Position = UDim2.fromOffset(0, 208)
	self._weapons.Parent = menu.content
	Components.List(self._weapons, Enum.FillDirection.Horizontal, Theme.Space.M)

	-- The next rung of the unlock ladder, sat under the record so levelling has a visible
	-- destination rather than just a rising number.
	self._unlock = Components.Label(menu.content, {
		text = "",
		size = Theme.Text.Small,
		colour = Theme.Colour.Warning,
	})
	self._unlock.Size = UDim2.new(1, 0, 0, 18)
	-- Under the record line, not across it: the record sits at 140 and is 18 tall.
	self._unlock.Position = UDim2.fromOffset(0, 162)

	self._empty = Components.Label(menu.content, {
		text = "",
		size = Theme.Text.Small,
		colour = Theme.Colour.TextMuted,
	})
	self._empty.Size = UDim2.new(1, 0, 0, 18)
	self._empty.Position = UDim2.fromOffset(0, 214)

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
	self._name.Text = tostring(s.name or "")
	-- A title is the one line of identity the player earned rather than bought, so it sits
	-- with the name; the handle keeps its place when there is none.
	local title = type(s.title) == "string" and s.title ~= "" and s.title or nil
	self._handle.Text = title and (title .. "  ·  " .. tostring(s.handle or ""))
		or tostring(s.handle or "")

	local tier = tostring(s.tier or "Bronze")
	self._tier.Text = string.upper(tier)
	self._tier.TextColor3 = TIER_COLOUR[tier] or Theme.Colour.TextDim
	self._rating.Text = string.format("%d elo", math.floor(tonumber(s.rating) or 0))

	self._wins.Text = tostring(math.floor(tonumber(s.wins) or 0))

	-- An unplayed win rate is "-", not "0%". Nobody with no matches has a zero per cent
	-- record, and showing one reads as a judgement rather than an absence.
	local decided = tonumber(s.decided) or 0
	self._winRate.Text = decided > 0 and string.format("%.1f%%", tonumber(s.winRate) or 0) or "-"
	self._winRate.TextColor3 = decided == 0 and Theme.Colour.TextMuted
		or (tonumber(s.winRate) or 0) >= 50 and Theme.Colour.Accent
		or Theme.Colour.Danger

	self._kills.Text = tostring(math.floor(tonumber(s.kills) or 0))

	-- A ratio with no denominator is not a ratio. With zero deaths recorded the honest
	-- display is "-", exactly as for an unplayed win rate -- printing the kill count as a K/D
	-- claims a 894.0 ratio that nothing measured. Deaths were not recorded at all before
	-- StatsService existed, so every established profile starts here and fills in from the
	-- next death onward.
	local deaths = math.floor(tonumber(s.deaths) or 0)
	local kd = tonumber(s.kd) or 0
	if deaths > 0 then
		self._kd.Text = string.format("%.1f", kd)
		self._kd.TextColor3 = kd >= 1 and Theme.Colour.Accent or Theme.Colour.Text
	else
		self._kd.Text = "-"
		self._kd.TextColor3 = Theme.Colour.TextMuted
	end

	local streak = math.floor(tonumber(s.streak) or 0)
	local streakText = streak > 0 and string.format("  -  %d win streak", streak)
		or streak < 0 and string.format("  -  %d lost in a row", -streak)
		or ""
	self._record.Text = string.format("%d W  %d L  %d D%s  -  level %d%s",
		math.floor(tonumber(s.wins) or 0),
		math.floor(tonumber(s.losses) or 0),
		math.floor(tonumber(s.draws) or 0),
		streakText,
		math.floor(tonumber(s.level) or 1),
		(tonumber(s.prestige) or 0) > 0 and string.format("  -  prestige %d", s.prestige) or "")

	local unlock = type(s.nextUnlock) == "table" and s.nextUnlock or nil
	self._unlock.Text = unlock
		and string.format("Next unlock:  %s at level %d",
			tostring(unlock.name), math.floor(tonumber(unlock.level) or 0))
		or "Every weapon unlocked."
	self._unlock.TextColor3 = unlock and Theme.Colour.Warning or Theme.Colour.TextMuted

	-- ------------------------------------------------------- weapons --

	for _, card in ipairs(self._weaponCards) do
		card:Destroy()
	end
	table.clear(self._weaponCards)

	local weapons = type(s.weapons) == "table" and s.weapons or {}
	self._empty.Text = #weapons == 0 and "No kills recorded yet." or ""

	-- Mastery standing, keyed by weapon, so a card can say what carrying that gun has earned.
	local mastery = {}
	for _, entry in ipairs(type(s.mastery) == "table" and s.mastery or {}) do
		if type(entry) == "table" and entry.name then
			mastery[entry.name] = entry
		end
	end

	for index, entry in ipairs(weapons) do
		local rank = mastery[entry.name]
		local card = Components.Card(self._weapons, {
			title = tostring(entry.name),
			subtitle = string.format("%d kills  ·  %s", math.floor(tonumber(entry.kills) or 0),
				rank and rank.tier and string.upper(rank.tier) or "UNRANKED"),
			layoutOrder = index,
		})

		-- What the next tier costs, so a weapon you like has somewhere to go. Mastery reads
		-- the kill tally that was already being kept, so this is filled in for weapons you
		-- were using long before it existed.
		if rank and rank.nextTier then
			-- Above the weapon, not below it: the card's own title and subtitle own the bottom,
			-- and two labels in one place is how text ends up printed over itself.
			local toNext = Components.Label(card.instance, {
				text = string.format("%d to %s", math.floor(tonumber(rank.remaining) or 0),
					string.upper(tostring(rank.nextTier))),
				size = Theme.Text.Micro,
				colour = Theme.Colour.TextMuted,
				align = Enum.TextXAlignment.Center,
			})
			toNext.Size = UDim2.new(1, -8, 0, 12)
			toNext.Position = UDim2.fromOffset(4, 2)
		end
		local holder = Instance.new("Frame")
		holder.BackgroundTransparency = 1
		holder.Size = UDim2.new(1, -12, 0, 62)
		holder.Position = UDim2.fromOffset(6, 14)
		holder.Parent = card.instance
		pcall(function()
			WeaponPreview.Render(holder, tostring(entry.name))
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
