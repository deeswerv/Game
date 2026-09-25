--!strict
-- The player board you hold Tab for, drawn like the rest of the reference UI instead of the
-- stock Roblox list: each player's face, their level diamond, name, rank tier, kills, deaths,
-- KDR and what they are doing right now (in a duel, queued, roaming). You are the gold row.
--
-- Read-only and cheap. Rows are built once per player and reused; while the board is shut
-- nothing runs, and while it is open it re-reads what it shows twice a second -- every value
-- here already replicates (leaderstats, the Level / RankTier / DuelState attributes), so there
-- is no remote and nothing to ask the server.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local Scoreboard = {}
Scoreboard.__index = Scoreboard

local WHITE = Color3.new(1, 1, 1)
local WIDTH = 820
local ROW_HEIGHT = 50
local MAX_VISIBLE_ROWS = 10
local REFRESH = 0.5

local TIER_COLOURS: { [string]: Color3 } = {
	Bronze = Color3.fromRGB(214, 138, 70),
	Silver = Color3.fromRGB(196, 204, 218),
	Gold = Color3.fromRGB(255, 204, 40),
	Platinum = Color3.fromRGB(80, 232, 210),
	Diamond = Color3.fromRGB(96, 176, 255),
	Champion = Color3.fromRGB(255, 72, 116),
}

local STATUS = {
	duel = { text = "DUELING", colour = Color3.fromRGB(236, 44, 52) },
	queue = { text = "QUEUED", colour = Color3.fromRGB(255, 190, 32) },
}

-- Column x offsets and widths, shared by the header and every row so they line up.
local COLUMNS = {
	player = { x = 12, w = 330 },
	rank = { x = 350, w = 110 },
	kills = { x = 468, w = 64 },
	deaths = { x = 536, w = 64 },
	kdr = { x = 604, w = 70 },
	status = { x = 684, w = 124 },
}

local function stat(player: Player, name: string): number
	local stats = player:FindFirstChild("leaderstats")
	local value = stats and stats:FindFirstChild(name)
	if value and (value:IsA("IntValue") or value:IsA("NumberValue")) then
		return value.Value
	end
	return 0
end

local function cell(parent: GuiObject, column, options: Components.LabelOptions): TextLabel
	local label = Components.Label(parent, options)
	label.Position = UDim2.new(0, column.x, 0, 0)
	label.Size = UDim2.new(0, column.w, 1, 0)
	return label
end

local function chip(parent: GuiObject, column): (Frame, TextLabel)
	local frame = Instance.new("Frame")
	frame.AnchorPoint = Vector2.new(0, 0.5)
	frame.Position = UDim2.new(0, column.x, 0.5, 0)
	frame.Size = UDim2.fromOffset(column.w - 10, 26)
	frame.Parent = parent
	Components.Corner(frame, Theme.Radius.Chip)
	Components.Stroke(frame, Theme.Colour.Outline, 2)
	Components.Gradient(frame, WHITE, Color3.fromRGB(170, 170, 180))
	local text = Components.Label(frame, {
		text = "",
		face = Theme.Face.Condensed,
		size = 17,
		align = Enum.TextXAlignment.Center,
		outline = 1.6,
	})
	text.Size = UDim2.fromScale(1, 1)
	return frame, text
end

function Scoreboard.new(playerGui: Instance)
	local self = setmetatable({}, Scoreboard)
	self._rows = {} :: { [Player]: any }
	self._open = false

	local gui = Instance.new("ScreenGui")
	gui.Name = "PlayerBoard"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 15             -- over the HUD, under the menus
	gui.Enabled = false
	gui.Parent = playerGui
	Components.BindScale(gui)
	self._gui = gui

	local panel = Instance.new("Frame")
	panel.Name = "Board"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 92)
	panel.Size = UDim2.fromOffset(WIDTH, 0)
	panel.AutomaticSize = Enum.AutomaticSize.Y
	panel.BackgroundColor3 = Theme.Colour.Panel
	panel.BackgroundTransparency = 0.08
	panel.Parent = gui
	Components.Corner(panel, Theme.Radius.Panel)
	Components.Stroke(panel, Theme.Colour.Outline, 3)
	Components.Gradient(panel, WHITE, Color3.fromRGB(200, 200, 210))
	Components.Padding(panel, 12)
	local stack = Components.List(panel, Enum.FillDirection.Vertical, 8)
	stack.HorizontalAlignment = Enum.HorizontalAlignment.Center
	self._panel = panel
	self._scale = Instance.new("UIScale")
	self._scale.Parent = panel

	-- Title bar: PLAYERS and the head count.
	local title = Instance.new("Frame")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0, 40)
	title.LayoutOrder = 1
	title.Parent = panel
	local heading = Components.Label(title, {
		text = "PLAYERS",
		face = Theme.Face.HeavyItalic,
		size = 34,
		outline = 3,
	})
	heading.Size = UDim2.new(0.6, 0, 1, 0)
	heading.Position = UDim2.fromOffset(8, 0)
	local count = Components.Label(title, {
		text = "",
		font = Theme.Font.Display,
		size = 24,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Right,
		outline = 2,
	})
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.new(1, -8, 0, 0)
	count.Size = UDim2.new(0.4, 0, 1, 0)
	self._count = count

	-- Column captions.
	local header = Instance.new("Frame")
	header.BackgroundTransparency = 1
	header.Size = UDim2.new(1, 0, 0, 20)
	header.LayoutOrder = 2
	header.Parent = panel
	for key, caption in pairs({ player = "PLAYER", rank = "RANK", kills = "K", deaths = "D", kdr = "KDR", status = "STATUS" }) do
		local centred = key ~= "player"
		local label = cell(header, COLUMNS[key], {
			text = caption,
			face = Theme.Face.Condensed,
			size = 16,
			colour = Theme.Colour.TextDim,
			align = centred and Enum.TextXAlignment.Center or Enum.TextXAlignment.Left,
			outline = 1.5,
		})
		if key == "player" then
			label.Position = UDim2.new(0, COLUMNS.player.x + 104, 0, 0)
		elseif key == "rank" or key == "status" then
			label.Size = UDim2.new(0, COLUMNS[key].w - 10, 1, 0)
		end
	end

	local list = Instance.new("ScrollingFrame")
	list.Name = "Rows"
	list.BackgroundTransparency = 1
	list.BorderSizePixel = 0
	list.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	list.CanvasSize = UDim2.new()
	list.AutomaticCanvasSize = Enum.AutomaticSize.Y
	list.ScrollBarThickness = 6
	list.ScrollBarImageColor3 = Theme.Colour.Stroke
	list.LayoutOrder = 3
	list.Parent = panel
	local rows = Components.List(list, Enum.FillDirection.Vertical, 6)
	rows.SortOrder = Enum.SortOrder.LayoutOrder
	self._list = list

	local foot = Components.Label(panel, {
		text = "Hold TAB to view  ·  Duel wins move your rank",
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		colour = Theme.Colour.TextMuted,
		align = Enum.TextXAlignment.Center,
	})
	foot.LayoutOrder = 4

	Players.PlayerRemoving:Connect(function(player)
		local row = self._rows[player]
		if row then
			row.frame:Destroy()
			self._rows[player] = nil
		end
		if self._open then
			self:_refresh()
		end
	end)
	Players.PlayerAdded:Connect(function()
		if self._open then
			self:_refresh()
		end
	end)

	return self
end

function Scoreboard:_row(player: Player)
	local existing = self._rows[player]
	if existing then
		return existing
	end
	local me = player == Players.LocalPlayer

	local frame = Instance.new("Frame")
	frame.Name = player.Name
	frame.Size = UDim2.new(1, -10, 0, ROW_HEIGHT)
	frame.BackgroundColor3 = me and Color3.fromRGB(255, 208, 90) or Theme.Colour.PanelRaised
	frame.BackgroundTransparency = me and 0.05 or 0.1
	frame.Parent = self._list
	Components.Corner(frame, Theme.Radius.Small)
	Components.Stroke(frame, Theme.Colour.Outline, 2)
	local shade = Components.Gradient(frame, WHITE, me and Color3.fromRGB(210, 150, 40) or Color3.fromRGB(150, 150, 160))
	shade.Rotation = 90

	local face = Instance.new("ImageLabel")
	face.Name = "Face"
	face.BackgroundColor3 = Theme.Colour.Sunken
	face.AnchorPoint = Vector2.new(0, 0.5)
	face.Position = UDim2.new(0, COLUMNS.player.x, 0.5, 0)
	face.Size = UDim2.fromOffset(40, 40)
	face.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", math.max(player.UserId, 1))
	face.Parent = frame
	Components.Corner(face, 20)
	Components.Stroke(face, Theme.Colour.Outline, 2)

	local badge, levelText = Components.LevelBadge(frame, 38)
	badge.AnchorPoint = Vector2.new(0, 0.5)
	badge.Position = UDim2.new(0, COLUMNS.player.x + 48, 0.5, 0)

	local name = Components.Label(frame, {
		text = player.DisplayName,
		font = Theme.Font.Bold,
		size = 21,
		colour = me and Theme.Colour.Outline or WHITE,
		outline = not me and 2 or false,
	})
	name.Position = UDim2.fromOffset(COLUMNS.player.x + 94, 4)
	name.Size = UDim2.fromOffset(COLUMNS.player.w - 94, 24)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local handle = Components.Label(frame, {
		text = "@" .. player.Name,
		font = Theme.Font.Bold,
		size = 13,
		colour = me and Color3.fromRGB(110, 70, 10) or Theme.Colour.TextMuted,
		outline = false,
	})
	handle.Position = UDim2.fromOffset(COLUMNS.player.x + 94, 27)
	handle.Size = UDim2.fromOffset(COLUMNS.player.w - 94, 16)
	handle.TextTruncate = Enum.TextTruncate.AtEnd

	local rankChip, rankText = chip(frame, COLUMNS.rank)

	local function number(column): TextLabel
		return cell(frame, column, {
			text = "0",
			font = Theme.Font.Display,
			size = 22,
			align = Enum.TextXAlignment.Center,
			outline = 2,
		})
	end
	local kills = number(COLUMNS.kills)
	kills.TextColor3 = Theme.Colour.Kill
	local deaths = number(COLUMNS.deaths)
	local kdr = number(COLUMNS.kdr)

	local statusChip, statusText = chip(frame, COLUMNS.status)

	local row = {
		frame = frame, badge = badge, level = levelText, rankChip = rankChip, rankText = rankText,
		kills = kills, deaths = deaths, kdr = kdr, statusChip = statusChip, statusText = statusText,
	}
	self._rows[player] = row
	return row
end

function Scoreboard:_refresh()
	local everyone = Players:GetPlayers()
	-- Most kills first; level breaks ties, then the name so the order never flickers.
	table.sort(everyone, function(a, b)
		local ka, kb = stat(a, "Kills"), stat(b, "Kills")
		if ka ~= kb then
			return ka > kb
		end
		local la, lb = tonumber(a:GetAttribute("Level")) or 0, tonumber(b:GetAttribute("Level")) or 0
		if la ~= lb then
			return la > lb
		end
		return a.Name < b.Name
	end)

	for order, player in ipairs(everyone) do
		local row = self:_row(player)
		row.frame.LayoutOrder = order

		local level = player:GetAttribute("Level")
		row.badge.Visible = type(level) == "number"
		row.level.Text = type(level) == "number" and tostring(level) or ""

		local tier = player:GetAttribute("RankTier")
		local tierName = type(tier) == "string" and tier or "Unranked"
		row.rankText.Text = string.upper(tierName)
		row.rankChip.BackgroundColor3 = TIER_COLOURS[tierName] or Theme.Colour.Stroke

		local k, d = stat(player, "Kills"), stat(player, "Deaths")
		row.kills.Text = tostring(k)
		row.deaths.Text = tostring(d)
		row.kdr.Text = string.format("%.2f", k / math.max(d, 1))

		local state = player:GetAttribute("DuelState")
		local status = type(state) == "string" and STATUS[state] or nil
		row.statusChip.Visible = status ~= nil
		if status then
			row.statusText.Text = status.text
			row.statusChip.BackgroundColor3 = status.colour
		end
	end

	local shown = math.clamp(#everyone, 1, MAX_VISIBLE_ROWS)
	self._list.Size = UDim2.new(1, 0, 0, shown * (ROW_HEIGHT + 6))
	self._count.Text = string.format("%d / %d", #everyone, Players.MaxPlayers)
end

function Scoreboard:SetOpen(open: boolean)
	if self._open == open then
		return
	end
	self._open = open
	if open then
		self:_refresh()
		self._gui.Enabled = true
		self._scale.Scale = 0.94
		TweenService:Create(self._scale, Theme.Tween.Pop, { Scale = 1 }):Play()
		local token = {}
		self._ticker = token
		task.spawn(function()
			while self._ticker == token do
				task.wait(REFRESH)
				if self._ticker == token then
					self:_refresh()
				end
			end
		end)
	else
		self._ticker = nil
		self._gui.Enabled = false
	end
end

function Scoreboard:Toggle()
	self:SetOpen(not self._open)
end

return Scoreboard
