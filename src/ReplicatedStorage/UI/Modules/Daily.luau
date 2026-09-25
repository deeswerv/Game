--!strict
-- The daily reward panel: the ladder, where you are on it, and one button.
--
-- Shows all seven rungs rather than only today's, because the reason to come back tomorrow is
-- seeing what tomorrow is worth. Claimed rungs are dimmed, today's is accented, the rest sit
-- quiet ahead of it.
--
-- The countdown is driven by a number of SECONDS handed over by the server, never by comparing
-- clocks. The client is not told what time the server thinks it is, so there is nothing to
-- disagree about.

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menu = require(script.Parent.Menu)

local Daily = {}
Daily.__index = Daily

local function clock(seconds: number): string
	if seconds <= 0 then
		return "now"
	end
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	if hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	end
	return string.format("%dm", math.max(1, minutes))
end

function Daily.new(parent: Instance, remotes)
	local self = setmetatable({}, Daily)
	self._remotes = remotes
	self._rungs = {}

	local menu = Menu.new(parent, {
		id = "Daily",
		title = "DAILY REWARD",
		size = UDim2.fromOffset(700, 340),
	})
	self._menu = menu

	self._streak = Components.Label(menu.content, {
		text = "",
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
	})
	self._streak.Size = UDim2.new(1, 0, 0, 18)

	self._ladder = Instance.new("Frame")
	self._ladder.Name = "Ladder"
	self._ladder.BackgroundTransparency = 1
	self._ladder.Size = UDim2.new(1, 0, 0, 110)
	self._ladder.Position = UDim2.fromOffset(0, 30)
	self._ladder.Parent = menu.content
	Components.List(self._ladder, Enum.FillDirection.Horizontal, Theme.Space.S)

	-- Named _claimButton, NOT _claim: a field and a method sharing a name means `self:_claim()`
	-- resolves to the field first and dies with "attempt to call a table value", which is
	-- exactly what happened the first time this ran.
	self._claimButton = Components.Button(menu.content, {
		name = "Claim",
		text = "CLAIM",
		primary = true,
		size = UDim2.new(0, 240, 0, Theme.Size.ButtonHeight),
		position = UDim2.new(0.5, 0, 0, 158),
		anchor = Vector2.new(0.5, 0),
		onActivated = function()
			self:Claim()
		end,
	})

	self._note = Components.Label(menu.content, {
		text = "",
		size = Theme.Text.Small,
		colour = Theme.Colour.TextMuted,
		align = Enum.TextXAlignment.Center,
	})
	self._note.Size = UDim2.new(1, 0, 0, 18)
	self._note.Position = UDim2.fromOffset(0, 206)

	menu:OnOpen(function()
		self:Refresh()
	end)

	return self
end

function Daily:Refresh()
	task.spawn(function()
		local ok, status = pcall(function()
			return self._remotes.dailyAction:InvokeServer("status")
		end)
		if ok and type(status) == "table" then
			self:_render(status)
		end
	end)
end

function Daily:Claim()
	self._claimButton:SetText("...")
	self._claimButton:SetEnabled(false)
	task.spawn(function()
		local ok, result = pcall(function()
			return self._remotes.dailyAction:InvokeServer("claim")
		end)
		if ok and type(result) == "table" then
			if result.ok then
				self._note.Text = string.format("Claimed %d coins%s",
					tonumber(result.coins) or 0,
					result.crystals and string.format(" and %d crystals", result.crystals) or "")
				self._note.TextColor3 = Theme.Colour.Accent
			else
				self._note.Text = tostring(result.reason or "Could not claim")
				self._note.TextColor3 = Theme.Colour.Danger
			end
			-- The server hands back fresh status with the result, so the panel never has to
			-- guess what its own claim changed.
			if type(result.status) == "table" then
				self:_render(result.status)
				return
			end
		end
		self:Refresh()
	end)
end

function Daily:_render(status)
	for _, rung in ipairs(self._rungs) do
		rung:Destroy()
	end
	table.clear(self._rungs)

	local ladder = type(status.ladder) == "table" and status.ladder or {}
	local current = tonumber(status.rung) or 1
	local claimable = status.claimable == true

	for index, entry in ipairs(ladder) do
		-- "Today" is only highlighted when it can actually be taken; once claimed the whole
		-- ladder reads as done-for-now rather than dangling a button that does nothing.
		local isToday = index == current and claimable
		local isPast = index < current

		local tile = Instance.new("Frame")
		tile.Name = "Day" .. index
		tile.BackgroundColor3 = isToday and Theme.Colour.PanelRaised or Theme.Colour.Sunken
		tile.BorderSizePixel = 0
		tile.Size = UDim2.fromOffset(88, 104)
		tile.LayoutOrder = index
		tile.Parent = self._ladder
		Components.Corner(tile, Theme.Radius.Card)
		if isToday then
			Components.Stroke(tile, Theme.Colour.Accent, Theme.Stroke.Emphasis)
		else
			Components.Stroke(tile)
		end

		local day = Components.Label(tile, {
			text = "Day " .. index,
			caps = true,
			size = Theme.Text.Micro,
			align = Enum.TextXAlignment.Center,
			colour = isToday and Theme.Colour.Accent or Theme.Colour.TextMuted,
		})
		day.Size = UDim2.new(1, 0, 0, 14)
		day.Position = UDim2.fromOffset(0, 10)

		local coins = Components.Label(tile, {
			text = tostring(entry.coins or 0),
			font = Theme.Font.Display,
			size = Theme.Text.Large,
			align = Enum.TextXAlignment.Center,
			colour = isPast and Theme.Colour.TextMuted or Theme.Colour.Currency,
		})
		coins.Size = UDim2.new(1, 0, 0, 24)
		coins.Position = UDim2.fromOffset(0, 32)

		local caption = Components.Label(tile, {
			text = "coins",
			size = Theme.Text.Micro,
			align = Enum.TextXAlignment.Center,
			colour = Theme.Colour.TextMuted,
		})
		caption.Size = UDim2.new(1, 0, 0, 14)
		caption.Position = UDim2.fromOffset(0, 56)

		if entry.crystals then
			local bonus = Components.Label(tile, {
				text = string.format("+%d crystals", entry.crystals),
				size = Theme.Text.Micro,
				align = Enum.TextXAlignment.Center,
				colour = Theme.Rarity.Epic.colour,
			})
			bonus.Size = UDim2.new(1, 0, 0, 14)
			bonus.Position = UDim2.fromOffset(0, 76)
		end

		table.insert(self._rungs, tile)
	end

	local streak = tonumber(status.streak) or 0
	self._streak.Text = string.format("%d day streak  -  best %d",
		streak, tonumber(status.bestStreak) or 0)

	self._claimButton:SetEnabled(claimable)
	self._claimButton:SetText(claimable and "CLAIM" or "CLAIMED")

	if not claimable then
		self._note.Text = string.format("Next reward in %s",
			clock(tonumber(status.secondsUntilNext) or 0))
		self._note.TextColor3 = Theme.Colour.TextMuted
	end
end

function Daily:Toggle()
	self._menu:Toggle()
end

function Daily:Close()
	self._menu:Close()
end

function Daily:Destroy()
	self._claimButton:Destroy()
	self._menu:Destroy()
end

return Daily
