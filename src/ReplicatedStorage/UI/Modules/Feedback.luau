--!strict
-- Feedback: what the screen itself does when something happens to you.
--
--   * Taking a hit flashes red in from the edges, scaled to how much it took.
--   * The hit also puts an arrow on the ring around the crosshair pointing at whoever fired,
--     turning with the camera until it fades -- so "where is that coming from" answers
--     itself without a scoreboard.
--   * Low health drains the colour out of the world and pulses the edges like a heartbeat.
--   * A level gained gets a moment in the centre of the screen.
--
-- Draws only. MainUI tells it about damage, threats and levels; this module never reads a
-- remote. Everything that runs per frame runs only while something is actually on screen.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local Feedback = {}
Feedback.__index = Feedback

local RED = Color3.fromRGB(210, 16, 20)
local LOW_HEALTH = 0.35
local THREAT_MEMORY = 0.6         -- a shot this recent can explain a hit
local ARROW_LIFE = 1.4
local MAX_ARROWS = 4

local function edge(parent: Instance, name: string, size: UDim2, position: UDim2, anchor: Vector2, rotation: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.BackgroundColor3 = RED
	f.BackgroundTransparency = 1
	f.BorderSizePixel = 0
	f.Size = size
	f.Position = position
	f.AnchorPoint = anchor
	f.Parent = parent
	local g = Instance.new("UIGradient")
	g.Rotation = rotation
	g.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(0.45, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	g.Parent = f
	return f
end

function Feedback.new(playerGui: Instance)
	local self = setmetatable({}, Feedback)

	local gui = Instance.new("ScreenGui")
	gui.Name = "CombatFeedback"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 5              -- under the HUD, over the world
	gui.Parent = playerGui
	-- Same responsive scale as the HUD, so the level call and the threat ring fit a phone.
	self._unbindScale = Components.BindScale(gui)
	self._gui = gui

	-- Vignette: four soft red edges. Their strength is one number, applied to all four.
	self._edges = {
		edge(gui, "Top", UDim2.fromScale(1, 0.32), UDim2.fromScale(0, 0), Vector2.zero, 90),
		edge(gui, "Bottom", UDim2.fromScale(1, 0.32), UDim2.fromScale(0, 1), Vector2.new(0, 1), -90),
		edge(gui, "Left", UDim2.fromScale(0.24, 1), UDim2.fromScale(0, 0), Vector2.zero, 0),
		edge(gui, "Right", UDim2.fromScale(0.24, 1), UDim2.fromScale(1, 0), Vector2.new(1, 0), 180),
	}
	self._flash = 0          -- decaying hit flash
	self._pulse = 0          -- low-health floor

	-- Threat arrows ride a ring around the crosshair.
	local ring = Instance.new("Frame")
	ring.Name = "ThreatRing"
	ring.BackgroundTransparency = 1
	ring.AnchorPoint = Vector2.new(0.5, 0.5)
	ring.Position = UDim2.fromScale(0.5, 0.5)
	ring.Size = UDim2.fromOffset(1, 1)
	ring.Parent = gui
	self._ring = ring
	self._arrows = {}
	self._threats = {}

	-- Low health: a local colour grade on the camera, invisible at full health.
	local grade = Instance.new("ColorCorrectionEffect")
	grade.Name = "LowHealthGrade"
	grade.Enabled = false
	self._grade = grade
	self:_parentGrade()
	workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		self:_parentGrade()
	end)

	-- Level up call.
	local banner = Instance.new("Frame")
	banner.Name = "LevelUp"
	banner.BackgroundTransparency = 1
	banner.AnchorPoint = Vector2.new(0.5, 0.5)
	banner.Position = UDim2.fromScale(0.5, 0.3)
	banner.Size = UDim2.fromOffset(520, 110)
	banner.Visible = false
	banner.Parent = gui
	local bannerScale = Instance.new("UIScale")
	bannerScale.Parent = banner
	local headline = Components.Label(banner, {
		text = "LEVEL UP!",
		font = Theme.Font.Display,
		size = 58,
		colour = Theme.Colour.Level,
		align = Enum.TextXAlignment.Center,
		outline = false,
	})
	headline.Size = UDim2.new(1, 0, 0, 64)
	Components.Outline(headline, 4, Theme.Colour.LevelEdge:Lerp(Color3.new(0, 0, 0), 0.35), 0)
	local g = Instance.new("UIGradient")
	g.Color = ColorSequence.new(Color3.fromRGB(255, 250, 190), Color3.fromRGB(255, 170, 30))
	g.Rotation = 90
	g.Parent = headline
	local sub = Components.Label(banner, {
		text = "",
		face = Theme.Face.Condensed,
		size = 30,
		align = Enum.TextXAlignment.Center,
		outline = 2.5,
	})
	sub.Size = UDim2.new(1, 0, 0, 34)
	sub.Position = UDim2.fromOffset(0, 66)
	self._levelBanner, self._levelScale, self._levelSub, self._levelHead = banner, bannerScale, sub, headline

	self._conn = RunService.RenderStepped:Connect(function(dt)
		self:_step(dt)
	end)

	return self
end

function Feedback:_parentGrade()
	local camera = workspace.CurrentCamera
	if camera then
		self._grade.Parent = camera
	end
end

function Feedback:_step(dt: number)
	-- Nothing live: skip the whole frame.
	if self._flash <= 0.001 and self._pulse <= 0.001 and #self._arrows == 0 then
		return
	end

	self._flash = math.max(0, self._flash - dt * 1.6)
	local strength = self._flash
	if self._pulse > 0 then
		-- A heartbeat: two quick thumps then a rest, roughly 80 bpm.
		local t = (os.clock() % 0.75) / 0.75
		local beat = math.max(0, 1 - math.abs(t - 0.1) * 9) + math.max(0, 1 - math.abs(t - 0.3) * 9) * 0.7
		strength = math.max(strength, self._pulse * (0.45 + 0.55 * beat))
	end
	local transparency = 1 - math.clamp(strength, 0, 0.85)
	for _, f in ipairs(self._edges) do
		f.BackgroundTransparency = transparency
	end

	-- Arrows follow the camera: each points at the world position it was made for.
	local camera = workspace.CurrentCamera
	local now = os.clock()
	for i = #self._arrows, 1, -1 do
		local arrow = self._arrows[i]
		local age = now - arrow.born
		if age >= ARROW_LIFE or not camera then
			arrow.holder:Destroy()
			table.remove(self._arrows, i)
		else
			local rel = (camera :: Camera).CFrame:PointToObjectSpace(arrow.origin)
			arrow.holder.Rotation = math.deg(math.atan2(rel.X, -rel.Z))
			local fade = math.clamp((age - (ARROW_LIFE - 0.5)) / 0.5, 0, 1)
			arrow.wedge.BackgroundTransparency = 0.05 + 0.95 * fade
			arrow.stroke.Transparency = 0.2 + 0.8 * fade
		end
	end
end

--- A shot aimed at us came from here. Remembered briefly so the damage it causes can point
--- back at it.
function Feedback:Threat(origin: Vector3)
	table.insert(self._threats, { origin = origin, at = os.clock() })
	while #self._threats > 8 do
		table.remove(self._threats, 1)
	end
end

function Feedback:_arrow(origin: Vector3)
	if #self._arrows >= MAX_ARROWS then
		local oldest = table.remove(self._arrows, 1)
		if oldest then
			oldest.holder:Destroy()
		end
	end
	local holder = Instance.new("Frame")
	holder.Name = "Threat"
	holder.BackgroundTransparency = 1
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromOffset(320, 320)
	holder.Parent = self._ring

	local wedge = Instance.new("Frame")
	wedge.Name = "Wedge"
	wedge.AnchorPoint = Vector2.new(0.5, 0)
	wedge.Position = UDim2.fromScale(0.5, 0)
	wedge.Size = UDim2.fromOffset(84, 12)
	wedge.BackgroundColor3 = Color3.fromRGB(255, 44, 44)
	wedge.BorderSizePixel = 0
	wedge.Parent = holder
	Components.Corner(wedge, 6)
	local stroke = Components.Stroke(wedge, Theme.Colour.Outline, 2)
	local fadeEnds = Instance.new("UIGradient")
	fadeEnds.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(0.5, 0),
		NumberSequenceKeypoint.new(1, 0.9),
	})
	fadeEnds.Parent = wedge

	local scale = Instance.new("UIScale")
	scale.Scale = 1.4
	scale.Parent = wedge
	TweenService:Create(scale, Theme.Tween.Pop, { Scale = 1 }):Play()

	table.insert(self._arrows, { holder = holder, wedge = wedge, stroke = stroke, origin = origin, born = os.clock() })
end

--- We lost `amount` health out of `maximum`.
function Feedback:Damaged(amount: number, maximum: number)
	if amount <= 0 or maximum <= 0 then
		return
	end
	self._flash = math.clamp(self._flash + 0.25 + (amount / maximum) * 1.6, 0, 0.85)

	-- Point at the most recent shot that could explain this.
	local now = os.clock()
	for i = #self._threats, 1, -1 do
		local threat = self._threats[i]
		if now - threat.at <= THREAT_MEMORY then
			self:_arrow(threat.origin)
			table.remove(self._threats, i)
			break
		end
	end
end

function Feedback:SetHealth(current: number, maximum: number)
	local fraction = maximum > 0 and math.clamp(current / maximum, 0, 1) or 1
	local low = current > 0 and fraction < LOW_HEALTH
	local depth = low and (1 - fraction / LOW_HEALTH) or 0
	self._pulse = low and (0.18 + depth * 0.3) or 0

	local grade = self._grade
	if depth > 0 then
		grade.Enabled = true
		TweenService:Create(grade, Theme.Tween.Value, {
			Saturation = -0.65 * depth,
			Contrast = 0.12 * depth,
			TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(255, 196, 196), depth),
		}):Play()
	else
		grade.Saturation = 0
		grade.Contrast = 0
		grade.TintColor = Color3.new(1, 1, 1)
		grade.Enabled = false
	end
end

--- Clear everything, for a respawn.
function Feedback:Reset()
	self._flash = 0
	self._pulse = 0
	table.clear(self._threats)
	for _, arrow in ipairs(self._arrows) do
		arrow.holder:Destroy()
	end
	table.clear(self._arrows)
	for _, f in ipairs(self._edges) do
		f.BackgroundTransparency = 1
	end
	self._grade.Enabled = false
end

function Feedback:LevelUp(level: number)
	self._levelToken = (self._levelToken or 0) + 1
	local token = self._levelToken
	local banner = self._levelBanner
	self._levelSub.Text = "LEVEL " .. tostring(level)
	banner.Visible = true
	for _, label in ipairs({ self._levelHead, self._levelSub }) do
		label.TextTransparency = 0
		local s = label:FindFirstChildOfClass("UIStroke")
		if s then
			s.Transparency = 0
		end
	end
	self._levelScale.Scale = 0.3
	TweenService:Create(self._levelScale, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	banner.Rotation = -4
	TweenService:Create(banner, TweenInfo.new(0.45, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Rotation = 0 }):Play()

	task.delay(2.2, function()
		if token ~= self._levelToken then
			return
		end
		local info = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		for _, label in ipairs({ self._levelHead, self._levelSub }) do
			TweenService:Create(label, info, { TextTransparency = 1 }):Play()
			local s = label:FindFirstChildOfClass("UIStroke")
			if s then
				TweenService:Create(s, info, { Transparency = 1 }):Play()
			end
		end
		task.delay(0.4, function()
			if token == self._levelToken then
				banner.Visible = false
			end
		end)
	end)
end

function Feedback:Destroy()
	self._conn:Disconnect()
	self._unbindScale()
	self._grade:Destroy()
	self._gui:Destroy()
end

return Feedback
