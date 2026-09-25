--!strict
-- The Travel menu: every place you can go, as a card, and a button that takes you there.
--
-- Replaces the stone arches. Each card says what the place is, how tough it is and whether
-- you are standing in it; GO asks the server (TravelService), which decides -- not while
-- you are being shot at, not mid-duel, not twice in a few seconds. While it works the screen
-- fades to a "travelling to" card and back, so the jump reads as a journey, not a glitch.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menu = require(script.Parent.Menu)
local UISound = require(script.Parent.UISound)

local Travel = {}
Travel.__index = Travel

local CARD_W, CARD_H = 272, 162

function Travel.new(parent: Instance, remotes, overlayParent: Instance)
	local self = setmetatable({}, Travel)
	self._remotes = remotes
	self._cards = {}
	self._busy = false

	local menu = Menu.new(parent, {
		id = "Travel",
		title = "Travel",
		subtitle = "Go anywhere -- as long as nobody is shooting at you",
		icon = "🗺",
		size = UDim2.fromOffset(920, 468),
	})
	self._menu = menu

	self._note = Components.Label(menu.content, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
	})
	self._note.Size = UDim2.new(1, 0, 0, 20)

	local grid = Instance.new("Frame")
	grid.Name = "Places"
	grid.BackgroundTransparency = 1
	grid.Position = UDim2.fromOffset(0, 28)
	grid.Size = UDim2.new(1, 0, 1, -28)
	grid.Parent = menu.content
	local layout = Components.Grid(grid, Vector2.new(CARD_W, CARD_H), 14)
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	self._grid = grid

	-- The travelling card, over everything.
	local fade = Instance.new("Frame")
	fade.Name = "TravelFade"
	fade.BackgroundColor3 = Color3.fromRGB(8, 9, 12)
	fade.BackgroundTransparency = 1
	fade.Size = UDim2.fromScale(1, 1)
	fade.Visible = false
	fade.ZIndex = 50
	fade.Parent = overlayParent
	local title = Components.Label(fade, {
		text = "",
		face = Theme.Face.HeavyItalic,
		size = 48,
		align = Enum.TextXAlignment.Center,
		outline = 4,
	})
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, 0.48)
	title.Size = UDim2.new(1, 0, 0, 56)
	title.ZIndex = 51
	local sub = Components.Label(fade, {
		text = "TRAVELLING TO",
		face = Theme.Face.Condensed,
		size = 20,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
		outline = 2,
	})
	sub.AnchorPoint = Vector2.new(0.5, 1)
	sub.Position = UDim2.fromScale(0.5, 0.42)
	sub.Size = UDim2.new(1, 0, 0, 24)
	sub.ZIndex = 51
	self._fade, self._fadeTitle, self._fadeSub = fade, title, sub

	menu:OnOpen(function()
		self:Refresh()
	end)
	return self
end

--- Which place the local player is standing in: inside Downtown's box, or nearest within 160.
local function hereOf(places: { any }): string?
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return nil
	end
	local p = root.Position
	local best, bestDistance = nil, 160
	for _, place in ipairs(places) do
		if typeof(place.position) == "Vector3" then
			local d = (p - place.position).Magnitude
			if d < bestDistance then
				best, bestDistance = place.id, d
			end
		end
	end
	-- Downtown is big: anywhere in its box counts.
	if p.Y > 900 and p.Y < 1300 then
		return "Downtown"
	end
	return best
end

function Travel:Refresh()
	task.spawn(function()
		local ok, state = pcall(function()
			return self._remotes.travelAction:InvokeServer("list")
		end)
		if ok and type(state) == "table" and type(state.places) == "table" then
			self:_render(state)
		else
			self._note.Text = "Travel is not available right now"
		end
	end)
end

function Travel:_card(place: any, here: boolean, order: number)
	local colour = typeof(place.colour) == "Color3" and place.colour or Theme.Colour.Info
	local card = Instance.new("Frame")
	card.Name = "Place_" .. tostring(place.id)
	card.BackgroundColor3 = here and Theme.Colour.PanelRaised or Theme.Shade(colour, -0.35)
	card.BorderSizePixel = 0
	card.Size = UDim2.fromOffset(CARD_W, CARD_H)
	card.LayoutOrder = order
	card.Parent = self._grid
	Components.Corner(card, 16)
	Components.Stroke(card, here and Theme.Colour.Stroke or colour:Lerp(Color3.new(1, 1, 1), 0.35), 3)
	if not here then
		Components.Gradient(card, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 160), 90)
	end

	local icon = Components.Icon(card, tostring(place.icon or "📍"), 40)
	icon.Position = UDim2.fromOffset(14, 12)
	local name = Components.Label(card, {
		text = string.upper(tostring(place.label or place.id)),
		face = Theme.Face.HeavyItalic,
		size = 24,
		outline = 2.5,
	})
	name.Position = UDim2.fromOffset(66, 12)
	name.Size = UDim2.new(1, -76, 0, 30)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	local levels = Components.Chip(card, tostring(place.levels or ""), colour, { filled = true })
	levels.Position = UDim2.fromOffset(66, 48)
	local blurb = Components.Label(card, {
		text = tostring(place.blurb or ""),
		font = Theme.Font.Medium,
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
		wrap = true,
	})
	blurb.Position = UDim2.fromOffset(14, 80)
	blurb.Size = UDim2.new(1, -28, 0, 34)
	blurb.TextYAlignment = Enum.TextYAlignment.Top

	local go = Components.Button(card, {
		name = "Go",
		text = here and "YOU ARE HERE" or "GO",
		primary = not here,
		textSize = 20,
		size = UDim2.new(1, -28, 0, 32),
		position = UDim2.new(0, 14, 1, -42),
		onActivated = function()
			if not here then
				self:Go(place)
			end
		end,
	})
	go:SetEnabled(not here)
	-- The whole card is a button too, under the GO button.
	local hit = Instance.new("TextButton")
	hit.Name = "Hit"
	hit.BackgroundTransparency = 1
	hit.Text = ""
	hit.Size = UDim2.fromScale(1, 1)
	hit.ZIndex = 0
	hit.Parent = card
	hit.Activated:Connect(function()
		if not here then
			self:Go(place)
		end
	end)
	return card
end

function Travel:_render(state)
	for _, c in ipairs(self._cards) do
		c:Destroy()
	end
	table.clear(self._cards)
	local here = hereOf(state.places)
	for i, place in ipairs(state.places) do
		table.insert(self._cards, self:_card(place, place.id == here, i))
	end
	if type(state.blocked) == "string" then
		self._note.Text = "⛔ " .. state.blocked
		self._note.TextColor3 = Theme.Colour.Danger
	else
		self._note.Text = "Pick a place. Travel is locked for a few seconds after you take damage."
		self._note.TextColor3 = Theme.Colour.TextDim
	end
end

--- Fade out, ask the server, fade back in on the other side (or with the reason it said no).
function Travel:Go(place: any)
	if self._busy then
		return
	end
	self._busy = true
	UISound.Play("Whoosh", 1.1, 0.5)
	self._fadeTitle.Text = string.upper(tostring(place.label or place.id))
	self._fade.Visible = true
	self._fade.BackgroundTransparency = 1
	TweenService:Create(self._fade, TweenInfo.new(0.25), { BackgroundTransparency = 0 }):Play()
	task.spawn(function()
		task.wait(0.25)
		local ok, result = pcall(function()
			return self._remotes.travelAction:InvokeServer("go", place.id)
		end)
		local moved = ok and type(result) == "table" and result.ok == true
		if moved then
			self._menu:Close()
			task.wait(0.6)
		else
			self._fadeSub.Text = "CAN'T TRAVEL"
			self._fadeTitle.Text = string.upper(ok and type(result) == "table" and tostring(result.reason or "Try again")
				or "Try again")
			task.wait(1.2)
		end
		local out = TweenService:Create(self._fade, TweenInfo.new(0.4), { BackgroundTransparency = 1 })
		out.Completed:Once(function()
			self._fade.Visible = false
			self._fadeSub.Text = "TRAVELLING TO"
		end)
		out:Play()
		self._busy = false
		if not moved and self._menu:IsOpen() then
			self:Refresh()
		end
	end)
end

function Travel:Toggle()
	self._menu:Toggle()
end

function Travel:Close()
	self._menu:Close()
end

function Travel:IsOpen(): boolean
	return self._menu:IsOpen()
end

return Travel
