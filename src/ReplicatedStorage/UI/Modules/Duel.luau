--!strict
-- The duel card: queue state, then the score while you are in one.
--
-- Small and top-right on purpose. A duel HUD is glanced at between engagements, not read --
-- the thing that matters mid-fight is the crosshair, and anything large enough to compete
-- with it is in the way.
--
-- Draws and asks; decides nothing. Queueing and leaving are requests to MatchService, which
-- owns the queue, the score and every teleport. This card only ever shows what it was told.

local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local Duel = {}
Duel.__index = Duel

function Duel.new(parent: GuiObject, remotes)
	local self = setmetatable({}, Duel)
	self._remotes = remotes

	local card = Instance.new("Frame")
	card.Name = "Duel"
	card.BackgroundColor3 = Theme.Colour.Panel
	card.BackgroundTransparency = 0.25
	card.BorderSizePixel = 0
	card.AnchorPoint = Vector2.new(1, 0)
	card.Position = UDim2.new(1, -Theme.Inset.Side, 0, Theme.Inset.Top)
	card.Size = UDim2.fromOffset(230, 84)
	card.Visible = false
	card.Parent = parent
	Components.Corner(card, Theme.Radius.Card)
	Components.Gradient(card)
	self._stroke = Components.Stroke(card, Theme.Colour.Stroke, 2.5)
	self._card = card

	self._heading = Components.Label(card, {
		text = "",
		caps = true,
		size = Theme.Text.Micro,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
	})
	self._heading.Size = UDim2.new(1, -16, 0, 14)
	self._heading.Position = UDim2.fromOffset(8, 9)

	self._main = Components.Label(card, {
		text = "",
		font = Theme.Font.Display,
		size = 30,
		align = Enum.TextXAlignment.Center,
	})
	self._main.Size = UDim2.new(1, -16, 0, 32)
	self._main.Position = UDim2.fromOffset(8, 25)

	self._sub = Components.Label(card, {
		text = "",
		size = Theme.Text.Small,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
	})
	self._sub.Size = UDim2.new(1, -16, 0, 16)
	self._sub.Position = UDim2.fromOffset(8, 60)

	if remotes.matchUpdate then
		remotes.matchUpdate.OnClientEvent:Connect(function(state)
			self:_render(state)
		end)
	end

	return self
end

local function tint(self, colour: Color3)
	TweenService:Create(self._stroke, Theme.Tween.Value, { Color = colour }):Play()
	TweenService:Create(self._main, Theme.Tween.Value, { TextColor3 = colour }):Play()
end

function Duel:_render(state)
	if type(state) ~= "table" then
		self._active = false
		self._card.Visible = false
		return
	end

	-- Not queued and not fighting: the card has nothing to say, so it says nothing.
	if not state.in_match and not state.in_queue then
		self._active = false
		self._card.Visible = false
		return
	end
	self._active = true
	self._card.Visible = self._hidden ~= true

	if state.in_queue then
		self._heading.Text = "Searching"
		self._main.Text = "..."
		self._sub.Text = string.format("%d in queue  -  [J] to cancel", tonumber(state.queued) or 1)
		tint(self, Theme.Colour.Warning)
		return
	end

	local opponent = tostring(state.opponentName or "?")

	if state.state == "countdown" then
		self._heading.Text = "Duel  -  " .. opponent
		self._main.Text = "GET READY"
		self._sub.Text = ""
		tint(self, Theme.Colour.Warning)
	elseif state.state == "over" then
		self._heading.Text = "Duel  -  " .. opponent
		if state.draw then
			self._main.Text = "DRAW"
			tint(self, Theme.Colour.TextDim)
		elseif state.won then
			self._main.Text = "VICTORY"
			tint(self, Theme.Colour.Accent)
		else
			self._main.Text = "DEFEAT"
			tint(self, Theme.Colour.Danger)
		end
		self._sub.Text = tostring(state.reason or "")
	else
		-- Live. The score is the headline; the clock is the quiet line under it.
		local you = tonumber(state.you) or 0
		local them = tonumber(state.them) or 0
		self._heading.Text = "vs " .. opponent
		self._main.Text = string.format("%d  -  %d", you, them)
		local left = tonumber(state.secondsLeft) or 0
		self._sub.Text = string.format("first to %d  -  %d:%02d",
			tonumber(state.target) or 3, math.floor(left / 60), left % 60)
		tint(self, you > them and Theme.Colour.Accent
			or you < them and Theme.Colour.Danger
			or Theme.Colour.Text)
	end
end

--- Ask to join the queue, or to leave whatever we are in.
---
--- One key does both, because the answer to "what does J do right now" should always be
--- "the opposite of what is on screen".
function Duel:Toggle()
	local action = self._active and "leave" or "queue"
	task.spawn(function()
		local ok, state = pcall(function()
			self._remotes.matchAction:InvokeServer(action)
			return self._remotes.matchAction:InvokeServer("state")
		end)
		if ok then
			self:_render(state)
		end
	end)
end

function Duel:SetVisible(visible: boolean)
	-- Hides the card under a menu and brings it back afterwards -- but only if it still has
	-- something to say; it never forces an empty card up.
	self._hidden = not visible
	self._card.Visible = visible and self._active == true
end

function Duel:Destroy()
	self._card:Destroy()
end

return Duel
