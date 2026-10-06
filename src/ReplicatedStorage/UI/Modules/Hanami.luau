--!strict
-- Hanami City on the HUD: everything HanamiService tells a player while they are in it.
--
--   * The market raid: a bar under the banners with the wave, the raiders left and how much of
--     the auction floor is still held, draining red as they reach it.
--   * A clue: a paper card with what you found, held long enough to read.
--   * The jobs and the fights: freeing a captive, a seal, the bell, Foreman Tetsu, the Iron
--     Shogun's intro, phases and fall -- a banner if it is your moment, a card if it is news.
--
-- Nothing here decides anything; it only draws what the server said (HanamiEvent).

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local Hanami = {}
Hanami.__index = Hanami

local SAKURA = Color3.fromRGB(246, 150, 186)
local IRON = Color3.fromRGB(226, 64, 52)
local GOLD = Color3.fromRGB(255, 196, 40)
local GREEN = Color3.fromRGB(96, 214, 120)
local PAPER = Color3.fromRGB(242, 230, 204)
local INK = Color3.fromRGB(44, 34, 30)
-- The raid bar sits on the line the stick-up heat bar uses: you are never doing both.
local BAR_Y = -172

local function commas(n: any): string
	local s = tostring(math.floor(tonumber(n) or 0))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function payout(data: any): string
	local line = string.format("+$%s     +%s XP     +%s 💎", commas(data.coins), commas(data.xp), commas(data.crystals))
	if tonumber(data.cred) and data.cred > 0 then
		line ..= string.format("     +%s Street Cred", commas(data.cred))
	end
	return line
end

function Hanami.new(screen: GuiObject, toast: any)
	local self = setmetatable({}, Hanami)
	self._toast = toast

	-- The raid bar.
	local bar = Instance.new("Frame")
	bar.Name = "RaidBar"
	-- Bottom-left, over your name and health: out of the middle of the screen.
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.new(0, 24, 1, BAR_Y)
	bar.Size = UDim2.fromOffset(440, 50)
	bar.BackgroundColor3 = Color3.fromRGB(30, 20, 22)
	bar.BackgroundTransparency = 0.1
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.Parent = screen
	Components.Corner(bar, 12)
	local stroke = Components.Stroke(bar, SAKURA, 3)
	local icon = Components.Icon(bar, "🌾", 30)
	icon.AnchorPoint = Vector2.new(0, 0.5)
	icon.Position = UDim2.new(0, 6, 0.5, -2)
	local title = Components.Label(bar, {
		text = "DEFEND THE MARKET",
		face = Theme.Face.HeavyItalic,
		size = 20,
		colour = SAKURA,
		outline = 2,
	})
	title.Position = UDim2.fromOffset(50, 3)
	title.Size = UDim2.new(1, -150, 0, 22)
	local detail = Components.Label(bar, {
		text = "",
		font = Theme.Font.Bold,
		size = 14,
		outline = 1.2,
	})
	detail.Position = UDim2.fromOffset(50, 24)
	detail.Size = UDim2.new(1, -150, 0, 16)
	detail.TextTruncate = Enum.TextTruncate.AtEnd
	local integrity = Components.Label(bar, {
		text = "100%",
		font = Theme.Font.Display,
		size = 30,
		align = Enum.TextXAlignment.Right,
		outline = 2.4,
	})
	integrity.AnchorPoint = Vector2.new(1, 0)
	integrity.Position = UDim2.new(1, -12, 0, 4)
	integrity.Size = UDim2.fromOffset(100, 34)
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.AnchorPoint = Vector2.new(0.5, 1)
	track.Position = UDim2.new(0.5, 0, 1, -4)
	track.Size = UDim2.new(1, -16, 0, 4)
	track.BackgroundColor3 = Color3.fromRGB(12, 10, 8)
	track.BorderSizePixel = 0
	track.Parent = bar
	Components.Corner(track, 2)
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = GREEN
	fill.BorderSizePixel = 0
	fill.Parent = track
	Components.Corner(fill, 2)
	self._bar, self._barStroke, self._detail, self._integrity, self._fill = bar, stroke, detail, integrity, fill

	-- The clue card: a sheet of paper, low on the screen, out of the way of the crosshair.
	local card = Instance.new("Frame")
	card.Name = "ClueCard"
	card.AnchorPoint = Vector2.new(0.5, 1)
	card.Position = UDim2.new(0.5, 0, 1, -170)
	card.Size = UDim2.fromOffset(460, 96)
	card.BackgroundColor3 = PAPER
	card.BorderSizePixel = 0
	card.Visible = false
	card.Parent = screen
	Components.Corner(card, 6)
	Components.Stroke(card, Color3.fromRGB(120, 86, 60), 3)
	local seal = Components.Icon(card, "📜", 34)
	seal.Position = UDim2.fromOffset(12, 12)
	local heading = Components.Label(card, {
		text = "",
		face = Theme.Face.HeavyItalic,
		size = 20,
		colour = INK,
		outline = false,
	})
	heading.Position = UDim2.fromOffset(60, 10)
	heading.Size = UDim2.new(1, -150, 0, 24)
	local count = Components.Label(card, {
		text = "",
		font = Theme.Font.Bold,
		size = 14,
		colour = Color3.fromRGB(150, 60, 50),
		align = Enum.TextXAlignment.Right,
		outline = false,
	})
	count.AnchorPoint = Vector2.new(1, 0)
	count.Position = UDim2.new(1, -14, 0, 14)
	count.Size = UDim2.fromOffset(90, 18)
	local body = Components.Label(card, {
		text = "",
		font = Theme.Font.Medium,
		size = 16,
		colour = INK,
		wrap = true,
		outline = false,
	})
	body.Position = UDim2.fromOffset(60, 38)
	body.Size = UDim2.new(1, -74, 0, 48)
	body.TextYAlignment = Enum.TextYAlignment.Top
	local cardScale = Instance.new("UIScale")
	cardScale.Parent = card
	self._card, self._heading, self._count, self._body, self._cardScale = card, heading, count, body, cardScale
	self._cardToken = 0
	self._clues = {} :: { [string]: boolean }
	return self
end

function Hanami:_raid(data: any)
	local wave, waves = tonumber(data.wave) or 0, tonumber(data.waves) or 3
	local left = tonumber(data.left) or 0
	local health = math.clamp(tonumber(data.integrity) or 100, 0, 100)
	self._bar.Visible = true
	if wave == 0 or data.cleared then
		self._detail.Text = string.format("WAVE %d OF %d CLEARED  ·  MORE IN %ds", wave, waves,
			math.ceil(tonumber(data.incoming) or 0))
		if wave == 0 then
			self._detail.Text = string.format("RAIDERS INBOUND  ·  %d WAVES", waves)
		end
	else
		self._detail.Text = string.format("WAVE %d OF %d  ·  %d RAIDER%s LEFT", wave, waves, left, left == 1 and "" or "S")
	end
	self._integrity.Text = string.format("%d%%", health)
	self._integrity.TextColor3 = if health > 50 then Color3.new(1, 1, 1) elseif health > 25 then GOLD else IRON
	local colour = if health > 50 then GREEN elseif health > 25 then GOLD else IRON
	TweenService:Create(self._fill, TweenInfo.new(0.4), { Size = UDim2.fromScale(health / 100, 1), BackgroundColor3 = colour })
		:Play()
	if (self._lastIntegrity or 100) - health >= 1 then
		-- They are on the auction floor: the edge flashes.
		self._barStroke.Color = IRON
		TweenService:Create(self._barStroke, TweenInfo.new(0.6), { Color = SAKURA }):Play()
	end
	self._lastIntegrity = health
end

function Hanami:_clue(data: any)
	self._clues[tostring(data.id or "")] = true
	local found = 0
	for _ in pairs(self._clues) do
		found += 1
	end
	self._heading.Text = tostring(data.title or "A clue")
	self._body.Text = tostring(data.text or "")
	self._count.Text = if tonumber(data.total) then ("%d / %d"):format(found, data.total) else ""
	self._cardToken += 1
	local token = self._cardToken
	self._card.Visible = true
	self._card.BackgroundTransparency = 0
	self._cardScale.Scale = 0.85
	TweenService:Create(self._cardScale, TweenInfo.new(0.25, Enum.EasingStyle.Back), { Scale = 1 }):Play()
	task.delay(6, function()
		if self._cardToken == token then
			self._card.Visible = false
		end
	end)
end

--- Handle one HanamiEvent from the server.
function Hanami:Handle(kind: string, data: any)
	local info = if type(data) == "table" then data else {}
	local toast = self._toast
	if kind == "enter" then
		if not info.cleared then
			toast:Push({ title = "Hanami City", text = "Elder Hoshi waits at the shrine off the station square", icon = "🌸",
				colour = SAKURA, duration = 6 })
		end
	elseif kind == "note" then
		toast:Push({ title = tostring(info.title or ""), text = info.text and tostring(info.text) or nil, icon = "🌸",
			colour = Theme.Colour.TextMuted })
	elseif kind == "blessed" then
		toast:Push({ title = "The bell rings", text = "Healed, and the city is quiet around you for a moment", icon = "🔔",
			colour = SAKURA })
	elseif kind == "rescued" then
		local left = tonumber(info.left) or 0
		toast:Push({ title = "Captive freed", text = if left > 0 then ("%d still held in the shed"):format(left)
			else "Everyone is out -- they're running home", icon = "🙏", colour = GREEN })
	elseif kind == "clue" then
		self:_clue(info)
	elseif kind == "seal" then
		toast:Push({ title = "Iron seal found", text = "A Kurogane pass -- someone will want this", icon = "🔱",
			colour = GOLD })
	elseif kind == "raid" then
		self:_raid(info)
		if info.started and tonumber(info.wave) == 1 then
			toast:Banner({ title = "THE RAIDERS ARE COMING", subtitle = "HOLD THE MARKET  ·  KEEP THEM OFF THE AUCTION FLOOR",
				colour = SAKURA, sound = "Slam" })
		elseif info.started then
			toast:Push({ title = ("Wave %d"):format(tonumber(info.wave) or 0), text = "Raiders coming over the dikes",
				icon = "🌾", colour = IRON })
		end
	elseif kind == "raidTick" then
		self:_raid(info)
	elseif kind == "raidWon" then
		self._bar.Visible = false
		self._lastIntegrity = nil
		toast:Banner({ title = "THE MARKET STANDS", subtitle = payout(info), colour = GREEN, sound = "Ring" })
	elseif kind == "raidLost" then
		self._bar.Visible = false
		self._lastIntegrity = nil
		toast:Push({ title = "The market fell", text = tostring(info.why or ""), icon = "🔥", colour = IRON, duration = 6 })
	elseif kind == "bossIntro" then
		toast:Banner({ title = tostring(info.name or "BOSS"), subtitle = tostring(info.line or ""), colour = IRON,
			sound = "Slam", duration = 4 })
	elseif kind == "bossStart" then
		toast:Banner({ title = "FINAL BOSS", subtitle = ("%s  ·  %s HP"):format(tostring(info.name or "?"),
			commas(info.health)), colour = IRON, sound = "Slam" })
	elseif kind == "bossPhase" then
		toast:Banner({ title = tostring(info.name or "PHASE"), subtitle = tostring(info.line or ""), colour = IRON,
			sound = "Slam" })
	elseif kind == "bossWon" then
		toast:Banner({ title = tostring(info.name or "BOSS") .. " DEFEATED", subtitle = payout(info),
			colour = GOLD, sound = "Ring" })
		if info.title then
			toast:Push({ title = "NEW TITLE", text = tostring(info.title), icon = "🏯", colour = GOLD, duration = 7 })
		end
		if info.final and info.first then
			toast:Banner({ title = "HANAMI CITY IS FREE", subtitle = "The Kurogane are broken. The Sakura blooms again.",
				colour = SAKURA, sound = "Ring", duration = 5 })
		end
	elseif kind == "bossReset" then
		toast:Push({ title = "The court is empty", text = tostring(info.name or "The Shogun") .. " waits again",
			icon = "🏯", colour = Theme.Colour.TextMuted })
	elseif kind == "announce" and type(info.names) == "table" and #info.names > 0 then
		toast:Push({ title = tostring(info.title or ""), text = table.concat(info.names, ", "),
			icon = if info.big then "🏯" else "🔥", colour = if info.big then GOLD else SAKURA, duration = 6 })
	end
end

return Hanami
