--!strict
-- The boss health bar: when a Warlord is near, a long red bar drops in across the top of the
-- screen with its name, its level, the phase the fight is in and where the next phase turns
-- over -- the RPG boss-fight frame. Damage leaves a white trail that drains after it, so
-- every big hit reads as a chunk taken off.
--
-- Bosses are found by the Boss attribute BossService stamps on the model, looked for in the
-- NPC folder four times a second -- never per frame. The bar animates on Heartbeat only
-- while it is on screen.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local UISound = require(script.Parent.UISound)

local BossBar = {}
BossBar.__index = BossBar

local WHITE = Color3.new(1, 1, 1)
local RED = Color3.fromRGB(226, 32, 44)
local WIDTH = 620
local ENGAGE = 190           -- studs: the bar comes up inside this
local DISENGAGE = 260        -- and goes away outside this, so it does not flicker at the edge
local SCAN = 0.25

local function commas(n: number): string
	local s = tostring(math.floor(n))
	return (s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", ""))
end

function BossBar.new(parent: GuiObject)
	local self = setmetatable({}, BossBar)
	self._target = nil :: Model?
	self._trail = 1
	self._hidden = false

	local root = Instance.new("Frame")
	root.Name = "BossBar"
	root.BackgroundTransparency = 1
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.new(0.5, 0, 0, 92)
	root.Size = UDim2.fromOffset(WIDTH, 74)
	root.Visible = false
	root.Parent = parent
	self._root = root

	local skull = Components.Icon(root, "💀", 30)
	skull.Position = UDim2.fromOffset(-4, -4)

	local name = Components.Label(root, {
		text = "",
		face = Theme.Face.HeavyItalic,
		size = 26,
		colour = Color3.fromRGB(255, 214, 120),
		outline = 3,
	})
	name.Position = UDim2.fromOffset(36, 0)
	name.Size = UDim2.new(1, -170, 0, 28)
	name.TextTruncate = Enum.TextTruncate.AtEnd
	self._name = name

	local phase = Components.Label(root, {
		text = "",
		face = Theme.Face.Condensed,
		size = 18,
		colour = WHITE,
		align = Enum.TextXAlignment.Right,
		outline = 2,
	})
	phase.AnchorPoint = Vector2.new(1, 0)
	phase.Position = UDim2.new(1, 0, 0, 6)
	phase.Size = UDim2.fromOffset(130, 20)
	self._phase = phase

	-- The bar: a dark rimmed track, a white trail behind a red fill, phase marks on top.
	local track = Instance.new("Frame")
	track.Name = "Track"
	track.BackgroundColor3 = Color3.fromRGB(20, 10, 12)
	track.Position = UDim2.fromOffset(0, 32)
	track.Size = UDim2.new(1, 0, 0, 26)
	track.ClipsDescendants = true
	track.Parent = root
	Components.Corner(track, 6)
	Components.Stroke(track, Theme.Colour.Outline, 3)

	local trail = Instance.new("Frame")
	trail.Name = "Trail"
	trail.BackgroundColor3 = Color3.fromRGB(255, 240, 230)
	trail.BorderSizePixel = 0
	trail.Size = UDim2.fromScale(1, 1)
	trail.Parent = track
	Components.Corner(trail, 6)
	self._trailBar = trail

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.BackgroundColor3 = RED
	fill.BorderSizePixel = 0
	fill.Size = UDim2.fromScale(1, 1)
	fill.ZIndex = 2
	fill.Parent = track
	Components.Corner(fill, 6)
	Components.Gradient(fill, Color3.fromRGB(255, 150, 150), Color3.fromRGB(150, 20, 30)).Rotation = 90
	self._fill = fill

	local numbers = Components.Label(track, {
		text = "",
		font = Theme.Font.Display,
		size = 18,
		align = Enum.TextXAlignment.Center,
		outline = 2.2,
	})
	numbers.Size = UDim2.fromScale(1, 1)
	numbers.ZIndex = 4
	self._numbers = numbers

	self._marks = {}
	self._track = track

	-- A big call when the fight turns over into a new phase.
	local call = Components.Label(parent :: any, {
		text = "",
		face = Theme.Face.HeavyItalic,
		size = 44,
		colour = Color3.fromRGB(255, 90, 90),
		align = Enum.TextXAlignment.Center,
		outline = 4,
	})
	call.Name = "BossPhaseCall"
	call.AnchorPoint = Vector2.new(0.5, 0)
	call.Position = UDim2.new(0.5, 0, 0, 176)
	call.Size = UDim2.fromOffset(700, 50)
	call.Visible = false
	self._call = call

	-- Protected: one bad frame (a boss half-streamed-in, a model torn down mid-scan) must not
	-- end the loop for the rest of the session.
	task.spawn(function()
		while self._root.Parent do
			local ok, err = pcall(self._scan, self)
			if not ok then
				warn("[BossBar] " .. tostring(err))
			end
			task.wait(SCAN)
		end
	end)

	self._beat = RunService.Heartbeat:Connect(function(dt)
		if self._root.Visible then
			self:_step(dt)
		end
	end)

	return self
end

--- The nearest live boss in range, with a little stickiness so it does not flicker.
function BossBar:_scan()
	local character = Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local folder = workspace:FindFirstChild("NPCs")
	if not root or not root:IsA("BasePart") or not folder then
		self:_set(nil)
		return
	end
	local best, bestDistance = nil, math.huge
	for _, model in ipairs(folder:GetChildren()) do
		if model:IsA("Model") and model:GetAttribute("Boss") == true then
			local humanoid = model:FindFirstChildOfClass("Humanoid")
			local body = model:FindFirstChild("HumanoidRootPart")
			if humanoid and humanoid.Health > 0 and body and body:IsA("BasePart") then
				local d = (body.Position - root.Position).Magnitude
				local limit = model == self._target and DISENGAGE or ENGAGE
				if d <= limit and d < bestDistance then
					best, bestDistance = model, d
				end
			end
		end
	end
	self:_set(best)
end

function BossBar:_set(model: Model?)
	if model == self._target then
		return
	end
	self._target = model
	if self._phaseConn then
		self._phaseConn:Disconnect()
		self._phaseConn = nil
	end
	for _, mark in ipairs(self._marks) do
		mark:Destroy()
	end
	table.clear(self._marks)

	if not model then
		self._root.Visible = false
		return
	end
	local level = model:GetAttribute("Level")
	self._name.Text = string.upper(model.Name) .. (type(level) == "number" and ("  ·  LV " .. level) or "")
	for mark in tostring(model:GetAttribute("PhaseMarks") or ""):gmatch("[^,]+") do
		local at = tonumber(mark)
		if at then
			local tick = Instance.new("Frame")
			tick.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
			tick.BorderSizePixel = 0
			tick.AnchorPoint = Vector2.new(0.5, 0)
			tick.Position = UDim2.fromScale(at, 0)
			tick.Size = UDim2.new(0, 3, 1, 0)
			tick.ZIndex = 3
			tick.Parent = self._track
			table.insert(self._marks, tick)
		end
	end
	self._phaseConn = model:GetAttributeChangedSignal("Phase"):Connect(function()
		self:_callPhase(tonumber(model:GetAttribute("Phase")) or 1)
	end)
	self._trail = 1
	self._root.Visible = not self._hidden
	-- Slam in.
	local s = self._root:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	s.Parent = self._root
	;(s :: UIScale).Scale = 1.25
	TweenService:Create(s :: UIScale, Theme.Tween.Pop, { Scale = 1 }):Play()
	UISound.Play("Slam", 0.7, 0.8)
end

function BossBar:_callPhase(phase: number)
	self._call.Text = phase >= 3 and "FINAL PHASE" or ("PHASE " .. phase)
	self._call.Visible = not self._hidden
	self._call.TextTransparency = 0
	local s = self._call:FindFirstChildOfClass("UIScale") or Instance.new("UIScale")
	s.Parent = self._call
	;(s :: UIScale).Scale = 2
	TweenService:Create(s :: UIScale, Theme.Tween.Pop, { Scale = 1 }):Play()
	UISound.Play("Slam", 0.6)
	UISound.Play("Clunk", 0.5, 0.7)
	task.delay(1.6, function()
		TweenService:Create(self._call, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
	end)
end

function BossBar:_step(dt: number)
	local model = self._target
	local humanoid = model and model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local fraction = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
	self._fill.Size = UDim2.fromScale(fraction, 1)
	-- The trail holds for a moment, then drains down to the health.
	if self._trail < fraction then
		self._trail = fraction
	else
		self._trail = math.max(fraction, self._trail - dt * 0.35)
	end
	self._trailBar.Size = UDim2.fromScale(self._trail, 1)
	self._numbers.Text = string.format("%s / %s", commas(humanoid.Health), commas(humanoid.MaxHealth))
	local phase = tonumber(model and model:GetAttribute("Phase")) or 1
	self._phase.Text = phase >= 3 and "FINAL PHASE" or ("PHASE " .. phase)
	self._phase.TextColor3 = phase >= 3 and Color3.fromRGB(255, 90, 90) or WHITE
end

--- Menus and the duel scoreboard hide it; it comes back if the boss is still there.
function BossBar:SetVisible(visible: boolean)
	self._hidden = not visible
	self._root.Visible = visible and self._target ~= nil
	if not visible then
		self._call.Visible = false
	end
end

function BossBar:Destroy()
	self._beat:Disconnect()
	self._root:Destroy()
	self._call:Destroy()
end

return BossBar
