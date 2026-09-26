--!strict
-- The bounty board on the side of the 24/7: MOST WANTED.
--
-- Left, the poster: a paper sheet with WANTED across the top, the target's face, their name
-- and street name, what they did and what they are worth. Between targets it is a blank
-- silhouette with the countdown to the next name, and the last one's fate stamped on it.
--
-- Right, the rest of the board: where the target was last seen and how long before they
-- skip town (with their health, once somebody has started on them), the WANTED players and
-- the price on each head, and how many you have brought in.
--
-- MostWantedService owns all of it; this reads the BountyBoard function and ticks the clocks
-- down between reads.

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menu = require(script.Parent.Menu)

local BountyBoard = {}
BountyBoard.__index = BountyBoard

local PAPER = Color3.fromRGB(236, 222, 186)
local PAPER_EDGE = Color3.fromRGB(176, 150, 104)
local INK = Color3.fromRGB(58, 38, 26)
local RED = Color3.fromRGB(214, 44, 40)
local GOLD = Color3.fromRGB(255, 196, 40)

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function clock(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function inkLabel(parent: GuiObject, text: string, size: number, face: Font?, colour: Color3?): TextLabel
	local l = Components.Label(parent, { text = text, size = size, colour = colour or INK, outline = false,
		align = Enum.TextXAlignment.Center })
	if face then
		l.FontFace = face
	end
	return l
end

function BountyBoard.new(parent: Instance, remotes)
	local self = setmetatable({}, BountyBoard)
	self._remotes = remotes
	self._rows = {} :: { Instance }
	self._state = nil :: any
	self._readAt = 0
	self._ticker = nil :: thread?

	local menu = Menu.new(parent, {
		id = "Bounties",
		title = "Most Wanted",
		subtitle = "Names on the board get paid for -- bring them in",
		icon = "🎯",
		size = UDim2.fromOffset(940, 480),
	})
	self._menu = menu
	local content = menu.content

	-- ---------------------------------------------------------- the poster --
	local poster = Instance.new("Frame")
	poster.Name = "Poster"
	poster.BackgroundColor3 = PAPER
	poster.BorderSizePixel = 0
	poster.Position = UDim2.fromOffset(6, 0)
	poster.Size = UDim2.fromOffset(318, 372)
	poster.Rotation = -1.2
	poster.Parent = content
	Components.Corner(poster, 6)
	Components.Stroke(poster, PAPER_EDGE, 3)
	Components.Gradient(poster, Color3.new(1, 1, 1), Color3.fromRGB(214, 196, 160), 90)
	-- Pins in the corners.
	for _, x in ipairs({ 0.06, 0.94 }) do
		local pin = Instance.new("Frame")
		pin.Name = "Pin"
		pin.AnchorPoint = Vector2.new(0.5, 0.5)
		pin.Position = UDim2.new(x, 0, 0, 12)
		pin.Size = UDim2.fromOffset(12, 12)
		pin.BackgroundColor3 = RED
		pin.BorderSizePixel = 0
		pin.Parent = poster
		Components.Corner(pin, 6)
		Components.Stroke(pin, Theme.Colour.Outline, 1.5)
	end
	local wanted = inkLabel(poster, "WANTED", 50, Theme.Face.Heavy, RED)
	wanted.Position = UDim2.fromOffset(0, 8)
	wanted.Size = UDim2.new(1, 0, 0, 50)
	local rule = Instance.new("Frame")
	rule.BackgroundColor3 = INK
	rule.BorderSizePixel = 0
	rule.Position = UDim2.new(0, 22, 0, 60)
	rule.Size = UDim2.new(1, -44, 0, 2)
	rule.Parent = poster

	local photo = Instance.new("Frame")
	photo.Name = "Photo"
	photo.BackgroundColor3 = Color3.fromRGB(64, 58, 52)
	photo.BorderSizePixel = 0
	photo.AnchorPoint = Vector2.new(0.5, 0)
	photo.Position = UDim2.new(0.5, 0, 0, 70)
	photo.Size = UDim2.fromOffset(170, 128)
	photo.Parent = poster
	Components.Corner(photo, 4)
	Components.Stroke(photo, INK, 3)
	Components.Gradient(photo, Color3.fromRGB(200, 190, 176), Color3.fromRGB(90, 84, 78), 90)
	-- Height lines behind the face, as on a booking photo.
	for i = 1, 4 do
		local line = Instance.new("Frame")
		line.BackgroundColor3 = Color3.fromRGB(40, 36, 32)
		line.BackgroundTransparency = 0.7
		line.BorderSizePixel = 0
		line.Position = UDim2.new(0, 0, 0, i * 25)
		line.Size = UDim2.new(1, 0, 0, 1)
		line.Parent = photo
	end
	self._face = Components.Icon(photo, "🕴️", 84)
	self._face.AnchorPoint = Vector2.new(0.5, 0.5)
	self._face.Position = UDim2.fromScale(0.5, 0.52)

	self._alias = inkLabel(poster, "", 26, Theme.Face.HeavyItalic, RED)
	self._alias.Position = UDim2.fromOffset(0, 204)
	self._alias.Size = UDim2.new(1, 0, 0, 28)
	self._name = inkLabel(poster, "", 20, Theme.Face.Condensed)
	self._name.Position = UDim2.fromOffset(0, 232)
	self._name.Size = UDim2.new(1, 0, 0, 22)
	self._crime = inkLabel(poster, "", 14, nil, Color3.fromRGB(96, 70, 50))
	self._crime.Font = Theme.Font.Medium
	self._crime.TextWrapped = true
	self._crime.Position = UDim2.fromOffset(18, 256)
	self._crime.Size = UDim2.new(1, -36, 0, 36)

	local rewardBand = Instance.new("Frame")
	rewardBand.Name = "Reward"
	rewardBand.BackgroundColor3 = INK
	rewardBand.BorderSizePixel = 0
	rewardBand.Position = UDim2.new(0, 14, 1, -70)
	rewardBand.Size = UDim2.new(1, -28, 0, 56)
	rewardBand.Parent = poster
	Components.Corner(rewardBand, 6)
	local rewardTitle = inkLabel(rewardBand, "REWARD", 14, Theme.Face.Heavy, PAPER)
	rewardTitle.Position = UDim2.fromOffset(0, 2)
	rewardTitle.Size = UDim2.new(1, 0, 0, 16)
	self._reward = Components.Label(rewardBand, { text = "", font = Theme.Font.Display, size = 24,
		colour = Theme.Colour.Currency, align = Enum.TextXAlignment.Center, outline = false })
	Components.Outline(self._reward, 2, Theme.Colour.CurrencyEdge, 0)
	self._reward.Position = UDim2.fromOffset(0, 20)
	self._reward.Size = UDim2.new(1, 0, 0, 32)

	-- The stamp across the poster once the target is gone.
	self._stamp = Components.Label(poster, { text = "", face = Theme.Face.Heavy, size = 40, colour = RED,
		align = Enum.TextXAlignment.Center, outline = false })
	self._stamp.AnchorPoint = Vector2.new(0.5, 0.5)
	self._stamp.Position = UDim2.new(0.5, 0, 0, 150)
	self._stamp.Size = UDim2.fromOffset(300, 56)
	self._stamp.Rotation = -14
	self._stamp.ZIndex = 5
	local stampRim = Instance.new("UIStroke")
	stampRim.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stampRim.Color = RED
	stampRim.Thickness = 4
	stampRim.Parent = self._stamp
	Components.Corner(self._stamp, 8)

	-- ---------------------------------------------------------- the side --
	local side = Instance.new("Frame")
	side.Name = "Side"
	side.BackgroundTransparency = 1
	side.Position = UDim2.fromOffset(346, 0)
	side.Size = UDim2.new(1, -346, 0, 372)
	side.Parent = content

	local status = Components.Panel(side, { name = "Status", colour = Theme.Colour.PanelRaised, radius = 12,
		size = UDim2.new(1, 0, 0, 124) })
	status.ClipsDescendants = true
	self._statusStrip = Instance.new("Frame")
	self._statusStrip.Name = "Strip"
	self._statusStrip.BorderSizePixel = 0
	self._statusStrip.BackgroundColor3 = RED
	self._statusStrip.Size = UDim2.new(0, 8, 1, 0)
	self._statusStrip.Parent = status
	self._statusChip = Components.Chip(status, "AT LARGE", RED)
	self._statusChip.Position = UDim2.fromOffset(22, 12)
	self._statusTitle = Components.Label(status, { text = "", face = Theme.Face.HeavyItalic, size = 26 })
	self._statusTitle.Position = UDim2.fromOffset(22, 38)
	self._statusTitle.Size = UDim2.new(1, -40, 0, 30)
	self._statusText = Components.Label(status, { text = "", size = Theme.Text.Body, colour = Theme.Colour.TextDim })
	self._statusText.Position = UDim2.fromOffset(22, 64)
	self._statusText.Size = UDim2.new(1, -40, 0, 20)
	self._timeBar = Components.Bar(status, { height = 12, colour = GOLD })
	self._timeBar.instance.Position = UDim2.new(0, 22, 1, -24)
	self._timeBar.instance.Size = UDim2.new(0.5, -30, 0, 12)
	self._healthBar = Components.Bar(status, { height = 12, colour = RED })
	self._healthBar.instance.AnchorPoint = Vector2.new(1, 0)
	self._healthBar.instance.Position = UDim2.new(1, -18, 1, -24)
	self._healthBar.instance.Size = UDim2.new(0.5, -30, 0, 12)
	self._timeCaption = Components.Label(status, { text = "", caps = true, size = 11 })
	self._timeCaption.Position = UDim2.new(0, 22, 1, -40)
	self._timeCaption.Size = UDim2.new(0.5, -30, 0, 16)
	self._healthCaption = Components.Label(status, { text = "HEALTH", caps = true, size = 11,
		align = Enum.TextXAlignment.Right })
	self._healthCaption.AnchorPoint = Vector2.new(1, 0)
	self._healthCaption.Position = UDim2.new(1, -18, 1, -40)
	self._healthCaption.Size = UDim2.new(0.5, -30, 0, 16)

	-- WANTED players.
	local listHead = Components.Label(side, { text = "WANTED PLAYERS", face = Theme.Face.Condensed, size = 20 })
	listHead.Position = UDim2.fromOffset(4, 136)
	listHead.Size = UDim2.new(1, 0, 0, 24)
	local listHint = Components.Label(side, { text = "5 kills without dying puts a price on you", size = 13,
		colour = Theme.Colour.TextMuted, align = Enum.TextXAlignment.Right })
	listHint.Position = UDim2.fromOffset(0, 136)
	listHint.Size = UDim2.new(1, -4, 0, 24)
	local list = Instance.new("Frame")
	list.Name = "Wanted"
	list.BackgroundColor3 = Theme.Colour.Sunken
	list.BackgroundTransparency = 0.2
	list.BorderSizePixel = 0
	list.Position = UDim2.fromOffset(0, 164)
	list.Size = UDim2.new(1, 0, 0, 150)
	list.Parent = side
	Components.Corner(list, 12)
	Components.Stroke(list, Theme.Colour.StrokeSoft, 1.5)
	local pad = Instance.new("UIPadding")
	pad.PaddingTop = UDim.new(0, 8)
	pad.PaddingLeft = UDim.new(0, 8)
	pad.PaddingRight = UDim.new(0, 8)
	pad.Parent = list
	Components.List(list, Enum.FillDirection.Vertical, 6)
	self._list = list

	self._footer = Components.Label(side, { text = "", size = Theme.Text.Body, colour = Theme.Colour.TextDim })
	self._footer.Position = UDim2.fromOffset(4, 324)
	self._footer.Size = UDim2.new(1, -8, 0, 20)
	self._how = Components.Label(side, {
		text = "The one who takes them down gets the full price and Street Cred. Help out and you get a cut.",
		size = 13, colour = Theme.Colour.TextMuted, wrap = true })
	self._how.Position = UDim2.fromOffset(4, 344)
	self._how.Size = UDim2.new(1, -8, 0, 30)

	menu:OnOpen(function()
		self:Refresh()
		if self._ticker then
			return
		end
		self._ticker = task.spawn(function()
			while self._menu:IsOpen() do
				task.wait(1)
				if not self._menu:IsOpen() then
					break
				end
				if os.clock() - self._readAt >= 5 then
					self:Refresh()
				elseif self._state then
					self:_render(self._state, os.clock() - self._readAt)
				end
			end
			self._ticker = nil
		end)
	end)
	return self
end

function BountyBoard:Refresh()
	task.spawn(function()
		local ok, state = pcall(function()
			return self._remotes.bountyBoard:InvokeServer("state")
		end)
		if ok and type(state) == "table" then
			self._state = state
			self._readAt = os.clock()
			self:_render(state, 0)
		else
			self._statusTitle.Text = "The board is loading"
			self._statusText.Text = "Try again in a moment"
		end
	end)
end

local function row(parent: GuiObject, entry: any, order: number): Frame
	local f = Instance.new("Frame")
	f.Name = "Row"
	f.BackgroundColor3 = entry.you and Theme.Shade(RED, -0.4) or Theme.Colour.PanelRaised
	f.BorderSizePixel = 0
	f.Size = UDim2.new(1, 0, 0, 38)
	f.LayoutOrder = order
	f.Parent = parent
	Components.Corner(f, 8)
	Components.Stroke(f, entry.you and RED or Theme.Colour.StrokeSoft, 1.5)
	local rank = Components.Label(f, { text = "#" .. order, font = Theme.Font.Display, size = 18, colour = GOLD })
	rank.Position = UDim2.fromOffset(12, 0)
	rank.Size = UDim2.new(0, 40, 1, 0)
	local name = Components.Label(f, { text = tostring(entry.name) .. (entry.you and "  (YOU)" or ""), size = 18 })
	name.Position = UDim2.fromOffset(52, 0)
	name.Size = UDim2.new(1, -200, 1, 0)
	local price = Components.Label(f, { text = "$" .. commas(tonumber(entry.amount) or 0), font = Theme.Font.Display,
		size = 20, colour = Theme.Colour.Currency, align = Enum.TextXAlignment.Right, outline = false })
	Components.Outline(price, 2, Theme.Colour.CurrencyEdge, 0)
	price.AnchorPoint = Vector2.new(1, 0)
	price.Position = UDim2.new(1, -12, 0, 0)
	price.Size = UDim2.new(0, 140, 1, 0)
	return f
end

function BountyBoard:_render(state: any, elapsed: number)
	local reward = type(state.reward) == "table" and state.reward or {}
	local target = type(state.target) == "table" and state.target or nil
	local rewardLine = "$" .. commas(tonumber(reward.coins) or 0)
	if (tonumber(reward.crystals) or 0) > 0 then
		rewardLine ..= "  💎" .. tostring(reward.crystals)
	end
	self._reward.Text = rewardLine

	if target then
		local left = math.max(0, (tonumber(target.secondsLeft) or 0) - elapsed)
		self._face.Text = "🕴️"
		self._face.TextTransparency = 0
		self._alias.Text = "“" .. tostring(target.alias) .. "”"
		self._name.Text = string.upper(tostring(target.name))
		self._crime.Text = tostring(target.crime or "")
		self._stamp.Visible = false
		self._statusStrip.BackgroundColor3 = RED
		self._statusChip.BackgroundColor3 = RED
		local chipText = self._statusChip:FindFirstChild("Text") :: TextLabel?
		if chipText then
			chipText.Text = "AT LARGE"
		end
		self._statusTitle.Text = "Last seen at " .. tostring(target.where)
		self._statusText.Text = string.format("Worth $%s, %s XP and +%s Street Cred to whoever brings them in",
			commas(tonumber(reward.coins) or 0), commas(tonumber(reward.xp) or 0), tostring(reward.cred or 0))
		self._timeCaption.Text = "SKIPS TOWN IN " .. clock(left)
		self._timeBar:SetFraction(left / 420, false)
		self._healthBar.instance.Visible = true
		self._healthCaption.Visible = true
		self._healthBar:SetFraction(tonumber(target.health) or 1)
	else
		local nextIn = math.max(0, (tonumber(state.nextIn) or 0) - elapsed)
		local last = type(state.last) == "table" and state.last or nil
		self._face.Text = "❓"
		self._face.TextTransparency = 0.2
		self._healthBar.instance.Visible = false
		self._healthCaption.Visible = false
		self._statusStrip.BackgroundColor3 = Theme.Colour.Stroke
		self._statusChip.BackgroundColor3 = Theme.Colour.Stroke
		local chipText = self._statusChip:FindFirstChild("Text") :: TextLabel?
		if chipText then
			chipText.Text = "QUIET"
		end
		self._statusTitle.Text = "Next name goes up in " .. clock(nextIn)
		self._timeCaption.Text = "THE STREET IS QUIET"
		self._timeBar:SetFraction(1 - math.clamp(nextIn / 210, 0, 1), false)
		if last then
			self._alias.Text = "“" .. tostring(last.alias) .. "”"
			self._name.Text = string.upper(tostring(last.name))
			self._crime.Text = last.escaped and "Got away. They will be back." or
				("Brought in by " .. tostring(last.by or "somebody") .. ".")
			self._stamp.Visible = true
			self._stamp.Text = last.escaped and "ESCAPED" or "CAUGHT"
			self._statusText.Text = last.escaped and (tostring(last.name) .. " skipped town before anyone got to them")
				or (tostring(last.name) .. " was taken down by " .. tostring(last.by or "somebody"))
		else
			self._alias.Text = "“ ??? ”"
			self._name.Text = "UNKNOWN"
			self._crime.Text = "Word on the street is somebody big is about to show."
			self._stamp.Visible = false
			self._statusText.Text = "Watch the board -- the whole server hears when a name goes up"
		end
	end

	for _, r in ipairs(self._rows) do
		r:Destroy()
	end
	table.clear(self._rows)
	local wanted = type(state.wanted) == "table" and state.wanted or {}
	for i, entry in ipairs(wanted) do
		if i > 3 then
			break
		end
		table.insert(self._rows, row(self._list, entry, i))
	end
	if #wanted == 0 then
		local empty = Components.Label(self._list, { text = "Nobody has a price on their head right now.",
			size = Theme.Text.Body, colour = Theme.Colour.TextMuted, align = Enum.TextXAlignment.Center })
		empty.Size = UDim2.new(1, 0, 0, 120)
		table.insert(self._rows, empty)
	end
	local n = tonumber(state.takedowns) or 0
	self._footer.Text = string.format("🎯  You have brought in %d this session", n)
end

function BountyBoard:Toggle()
	self._menu:Toggle()
end

function BountyBoard:Close()
	self._menu:Close()
end

function BountyBoard:IsOpen(): boolean
	return self._menu:IsOpen()
end

return BountyBoard
