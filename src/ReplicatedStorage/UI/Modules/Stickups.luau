--!strict
-- Stick-ups on the HUD: the robber's heat bar, the bag tag over every robber, and the news.
--
--   * Your job: under the cash, a bar that says what is in the bag and how long to hold it,
--     draining as the heat runs down.
--   * Anyone holding a bag has a gold tag over their head with the amount, through walls --
--     the point of the heat is that everybody knows where the money is.
--   * The robbery, the getaway, the bag changing hands: a banner if it is about you, a card
--     for everyone else.
--
-- The bag and the heat come from the "Bag" / "Heat" attributes StickupService sets on the
-- player (Heat is the server time it ends), so the tags and the payout can never disagree.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local Stickups = {}
Stickups.__index = Stickups

local GOLD = Color3.fromRGB(255, 196, 40)
local RED = Color3.fromRGB(226, 52, 52)
local GREEN = Color3.fromRGB(76, 214, 110)
local CAPTION = Color3.fromRGB(255, 236, 200)
-- Under the banners that call the job, on the line the WANTED badge uses -- and a step below
-- it when you are wanted as well.
local BAR_Y = 202
local BAR_Y_WANTED = 244

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function clock(seconds: number): string
	local s = math.max(0, math.ceil(seconds))
	return ("%d:%02d"):format(s // 60, s % 60)
end

function Stickups.new(screen: GuiObject, playerGui: Instance, toast: any)
	local self = setmetatable({}, Stickups)
	self._toast = toast
	self._gui = playerGui
	self._hidden = false
	self._tags = {} :: { [Player]: BillboardGui }

	-- The robber's own bar.
	local bar = Instance.new("Frame")
	bar.Name = "HeatBar"
	bar.AnchorPoint = Vector2.new(0.5, 0)
	bar.Position = UDim2.new(0.5, 0, 0, BAR_Y)
	bar.Size = UDim2.fromOffset(440, 50)
	bar.BackgroundColor3 = Color3.fromRGB(38, 22, 16)
	bar.BackgroundTransparency = 0.1
	bar.BorderSizePixel = 0
	bar.Visible = false
	bar.Parent = screen
	Components.Corner(bar, 12)
	local stroke = Components.Stroke(bar, GOLD, 3)
	local scale = Instance.new("UIScale")
	scale.Parent = bar

	local bag = Components.Icon(bar, "💰", 30)
	bag.AnchorPoint = Vector2.new(0, 0.5)
	bag.Position = UDim2.new(0, 6, 0.5, -2)

	local title = Components.Label(bar, {
		text = "HOLD THE BAG",
		face = Theme.Face.HeavyItalic,
		size = 20,
		colour = GOLD,
		outline = 2,
	})
	title.Position = UDim2.fromOffset(50, 3)
	title.Size = UDim2.new(1, -140, 0, 22)
	local detail = Components.Label(bar, {
		text = "",
		font = Theme.Font.Bold,
		size = 14,
		outline = 1.2,
	})
	detail.Position = UDim2.fromOffset(50, 24)
	detail.Size = UDim2.new(1, -140, 0, 16)
	detail.TextTruncate = Enum.TextTruncate.AtEnd
	local timer = Components.Label(bar, {
		text = "0:00",
		font = Theme.Font.Display,
		size = 30,
		align = Enum.TextXAlignment.Right,
		outline = 2.4,
	})
	timer.AnchorPoint = Vector2.new(1, 0)
	timer.Position = UDim2.new(1, -12, 0, 4)
	timer.Size = UDim2.fromOffset(90, 34)

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
	fill.BackgroundColor3 = GOLD
	fill.BorderSizePixel = 0
	fill.Parent = track
	Components.Corner(fill, 2)

	self._bar, self._barStroke, self._barScale = bar, stroke, scale
	self._detail, self._timer, self._fill = detail, timer, fill
	self._heatLength = 60

	RunService.Heartbeat:Connect(function()
		self:_update()
	end)
	local function watch(p: Player)
		p:GetAttributeChangedSignal("Bag"):Connect(function()
			self:_refreshTag(p)
		end)
		p.CharacterAdded:Connect(function()
			task.defer(function()
				self:_refreshTag(p)
			end)
		end)
		self:_refreshTag(p)
	end
	Players.PlayerAdded:Connect(watch)
	for _, p in ipairs(Players:GetPlayers()) do
		watch(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		local tag = self._tags[p]
		if tag then
			tag:Destroy()
			self._tags[p] = nil
		end
	end)
	return self
end

--- The gold tag over someone holding a bag. Not over yourself: your own bar says it.
function Stickups:_refreshTag(p: Player)
	local amount = tonumber(p:GetAttribute("Bag")) or 0
	local head = p.Character and p.Character:FindFirstChild("Head")
	local existing = self._tags[p]
	if amount <= 0 or p == Players.LocalPlayer or not head then
		if existing then
			existing:Destroy()
			self._tags[p] = nil
		end
		return
	end
	if existing and existing.Adornee == head then
		local label = existing:FindFirstChild("Amount", true)
		if label and label:IsA("TextLabel") then
			label.Text = "💰 $" .. commas(amount)
		end
		return
	end
	if existing then
		existing:Destroy()
	end
	local tag = Instance.new("BillboardGui")
	tag.Name = "BagTag"
	tag.Adornee = head :: BasePart
	tag.AlwaysOnTop = true
	tag.Size = UDim2.fromOffset(150, 44)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	tag.MaxDistance = 1200
	tag.Enabled = not self._hidden
	tag.Parent = self._gui
	local pill = Instance.new("Frame")
	pill.BackgroundColor3 = Color3.fromRGB(38, 22, 16)
	pill.BackgroundTransparency = 0.1
	pill.Size = UDim2.fromScale(1, 0.72)
	pill.Parent = tag
	Components.Corner(pill, 10)
	Components.Stroke(pill, GOLD, 2.5)
	local label = Components.Label(pill, {
		text = "💰 $" .. commas(amount),
		font = Theme.Font.Display,
		size = 20,
		colour = GOLD,
		align = Enum.TextXAlignment.Center,
		outline = 2,
	})
	label.Name = "Amount"
	label.Size = UDim2.fromScale(1, 1)
	local caption = Components.Label(tag :: any, { text = "STICK-UP", caps = true, size = 11, colour = CAPTION })
	caption.Position = UDim2.fromScale(0, 0.72)
	caption.Size = UDim2.fromScale(1, 0.28)
	caption.TextXAlignment = Enum.TextXAlignment.Center
	self._tags[p] = tag
end

function Stickups:_update()
	local me = Players.LocalPlayer
	local amount = tonumber(me:GetAttribute("Bag")) or 0
	local endsAt = tonumber(me:GetAttribute("Heat")) or 0
	local left = endsAt - workspace:GetServerTimeNow()
	local on = amount > 0 and left > -1
	self._bar.Visible = on and not self._hidden
	if not on then
		return
	end
	local wanted = (tonumber(me:GetAttribute("Bounty")) or 0) > 0
	self._bar.Position = UDim2.new(0.5, 0, 0, if wanted then BAR_Y_WANTED else BAR_Y)
	self._detail.Text = ("$%s  ·  %s  ·  THEY ARE COMING"):format(commas(amount),
		string.upper(tostring(me:GetAttribute("HeatPlace") or "")))
	self._timer.Text = clock(left)
	self._fill.Size = UDim2.fromScale(math.clamp(left / self._heatLength, 0, 1), 1)
	-- The last ten seconds, the bar beats.
	local urgent = left <= 10
	self._timer.TextColor3 = if urgent then Color3.fromRGB(255, 120, 100) else Color3.new(1, 1, 1)
	self._barStroke.Color = if urgent and (math.floor(left * 2) % 2 == 0) then RED else GOLD
end

--- Handle one StickupEvent from the server.
function Stickups:Handle(kind: string, data: any)
	if type(data) ~= "table" then
		return
	end
	local me = Players.LocalPlayer
	local amount = "$" .. commas(tonumber(data.amount) or 0)
	local place = string.upper(tostring(data.place or ""))
	if kind == "alarm" then
		if data.robberId == me.UserId then
			self._heatLength = tonumber(data.seconds) or 60
			self._barScale.Scale = 1.25
			TweenService:Create(self._barScale, Theme.Tween.Pop, { Scale = 1 }):Play()
			self._toast:Banner({ title = "STICK-UP", subtitle = ("%s IN THE BAG  ·  HOLD IT FOR %ds"):format(amount,
				tonumber(data.seconds) or 60), colour = GOLD, sound = "Slam" })
		else
			self._toast:Push({ title = "ROBBERY · " .. place, text = ("%s has %s in a bag. Take it off them."):format(
				tostring(data.robber), amount), icon = "🚨", colour = GOLD, duration = 6 })
		end
	elseif kind == "getaway" then
		if data.robberId == me.UserId then
			self._toast:Banner({ title = "CLEAN GETAWAY", subtitle = ("+%s  ·  +%d XP"):format(amount, tonumber(data.xp) or 0),
				colour = GREEN, sound = "Ring" })
		else
			self._toast:Push({ title = tostring(data.robber) .. " got away", text = amount .. " from " .. tostring(data.place),
				icon = "💰", colour = GOLD, duration = 5 })
		end
	elseif kind == "stolen" then
		if data.killerId == me.UserId then
			self._toast:Banner({ title = "BAG TAKEN", subtitle = ("+%s  ·  OFF %s"):format(amount,
				string.upper(tostring(data.robber))), colour = GOLD, sound = "Ring" })
		elseif data.robberId == me.UserId then
			self._toast:Banner({ title = "THE BAG IS GONE", subtitle = ("%s TOOK %s"):format(
				string.upper(tostring(data.killer)), amount), colour = RED, sound = "Clunk" })
		else
			self._toast:Push({ title = tostring(data.killer) .. " took the bag", text = amount .. " off " .. tostring(data.robber),
				icon = "💰", colour = GOLD, duration = 5 })
		end
	elseif kind == "busted" then
		if data.robberId == me.UserId then
			self._toast:Banner({ title = "BUSTED", subtitle = "THE BAG IS GONE  ·  " .. amount, colour = RED, sound = "Clunk" })
		end
	elseif kind == "refused" then
		self._toast:Push({ title = "Nothing to take", text = tostring(data.text or ""), icon = "🔒",
			colour = Theme.Colour.TextDim, duration = 3 })
	end
end

function Stickups:SetVisible(visible: boolean)
	self._hidden = not visible
	for _, tag in pairs(self._tags) do
		tag.Enabled = visible
	end
	self:_update()
end

return Stickups
