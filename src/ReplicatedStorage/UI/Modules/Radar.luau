--!strict
-- The radar, top right: a round map of what is around you, turned the way you are looking.
--
--   * You in the middle, an arrow pointing the way your body faces. The rim is RANGE studs out
--     and the inner ring half that; N rides the rim, so north is always findable.
--   * A sweep goes round. (It is only a look: the radar does not need it to see.)
--   * People: other players white; the clan and the gangs red -- the ones close to you always,
--     any of them while your Radar killstreak is up (it marks them); bosses gold and bigger.
--     Someone well above or below you is drawn fainter, with a little arrow saying which.
--   * What the compass knows about (Wayfinding): your job as a gold diamond, turf wars, supply
--     drops, the MOST WANTED. Past the rim they sit on its edge, pointing the way.
--   * The name of the place you are in, under it.
--
-- Draws and reads the world, nothing else; it updates fifteen times a second.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local Radar = {}
Radar.__index = Radar

Radar.SIZE = 150            -- the dial, in pixels
Radar.RANGE = 160           -- studs from the middle to the rim
Radar.CLOSE = 55            -- enemies this close are always on it
Radar.SWEEP = 2.6           -- seconds for the sweep to go round
Radar.HEIGHT = 14           -- studs above or below before a blip fades
Radar.TOP = 12              -- pixels from the top of the screen

local RED = Color3.fromRGB(255, 70, 70)
local GOLD = Color3.fromRGB(255, 200, 48)
local WHITE = Color3.fromRGB(240, 244, 250)
local TEAL = Color3.fromRGB(80, 230, 200)

type Blip = { frame: Frame, dot: Frame, tag: TextLabel?, seen: boolean }

--- Where a world offset lands on the dial: right and up, in studs, the camera's forward up.
function Radar.Project(offset: Vector3, look: Vector3): (number, number)
	local f = Vector3.new(look.X, 0, look.Z)
	f = if f.Magnitude > 1e-4 then f.Unit else Vector3.new(0, 0, -1)
	local right = f:Cross(Vector3.new(0, 1, 0))
	return offset:Dot(right), offset:Dot(f)
end

local function circle(parent: Instance, name: string, size: number, colour: Color3, transparency: number): Frame
	local f = Instance.new("Frame")
	f.Name = name
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(size, size)
	f.BackgroundColor3 = colour
	f.BackgroundTransparency = transparency
	f.BorderSizePixel = 0
	f.Parent = parent
	Components.Corner(f, size)
	return f
end

function Radar.new(screen: GuiObject, wayfinding: any?)
	local self = setmetatable({}, Radar)
	self._wayfinding = wayfinding
	self._hidden = false
	self._blips = {} :: { [any]: Blip }
	self._sweep = 0

	local S = Radar.SIZE
	local holder = Instance.new("Frame")
	holder.Name = "Radar"
	holder.BackgroundTransparency = 1
	-- Top right: the top left is the kill feed's, the toasts' and the turf chip's; the nav
	-- column starts below the place's name even on a short screen.
	holder.AnchorPoint = Vector2.new(1, 0)
	holder.Position = UDim2.new(1, -Theme.Inset.Side, 0, Radar.TOP)
	holder.Size = UDim2.fromOffset(S, S + 20)
	holder.Parent = screen
	self._holder = holder

	-- The dial: a canvas, so everything on it (the sweep included) is clipped to the circle.
	local dial = Instance.new("CanvasGroup")
	dial.Name = "Dial"
	dial.Size = UDim2.fromOffset(S, S)
	dial.BackgroundColor3 = Color3.fromRGB(10, 13, 20)
	dial.BackgroundTransparency = 0.22
	dial.BorderSizePixel = 0
	dial.Parent = holder
	Components.Corner(dial, S)
	local shade = Instance.new("UIGradient")
	shade.Rotation = 90
	shade.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(150, 160, 180))
	shade.Parent = dial
	self._dial = dial
	-- Rings and cross-hairs.
	local ring = circle(dial, "Ring", S / 2, Color3.new(0, 0, 0), 1)
	Components.Stroke(ring, WHITE, 1).Transparency = 0.82
	local outer = circle(dial, "Outer", S - 2, Color3.new(0, 0, 0), 1)
	Components.Stroke(outer, WHITE, 1.5).Transparency = 0.6
	for _, horizontal in ipairs({ true, false }) do
		local line = Instance.new("Frame")
		line.Name = "Cross"
		line.AnchorPoint = Vector2.new(0.5, 0.5)
		line.Position = UDim2.fromScale(0.5, 0.5)
		line.Size = if horizontal then UDim2.new(1, 0, 0, 1) else UDim2.new(0, 1, 1, 0)
		line.BackgroundColor3 = WHITE
		line.BackgroundTransparency = 0.88
		line.BorderSizePixel = 0
		line.Parent = dial
	end
	-- The field of view: a soft wedge up from the middle.
	local cone = Instance.new("Frame")
	cone.Name = "View"
	cone.AnchorPoint = Vector2.new(0.5, 1)
	cone.Position = UDim2.fromScale(0.5, 0.5)
	cone.Size = UDim2.fromOffset(S * 0.62, S / 2)
	cone.BackgroundColor3 = WHITE
	cone.BackgroundTransparency = 0.9
	cone.BorderSizePixel = 0
	cone.Parent = dial
	local coneFade = Instance.new("UIGradient")
	coneFade.Rotation = -90
	coneFade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	coneFade.Parent = cone
	-- The sweep: a beam with a fading trail behind it, turning about the middle.
	local sweep = Instance.new("Frame")
	sweep.Name = "Sweep"
	sweep.AnchorPoint = Vector2.new(0.5, 0.5)
	sweep.Position = UDim2.fromScale(0.5, 0.5)
	sweep.Size = UDim2.fromOffset(S, S)
	sweep.BackgroundTransparency = 1
	sweep.Parent = dial
	local trail = Instance.new("Frame")
	trail.Name = "Trail"
	trail.Size = UDim2.fromOffset(S / 2, S / 2)
	trail.BackgroundColor3 = TEAL
	trail.BorderSizePixel = 0
	trail.Parent = sweep
	local trailFade = Instance.new("UIGradient")
	trailFade.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.7) })
	trailFade.Parent = trail
	local beam = Instance.new("Frame")
	beam.Name = "Beam"
	beam.Position = UDim2.fromOffset(S / 2 - 1, 0)
	beam.Size = UDim2.fromOffset(2, S / 2)
	beam.BackgroundColor3 = TEAL
	beam.BackgroundTransparency = 0.35
	beam.BorderSizePixel = 0
	beam.Parent = sweep
	self._sweepFrame = sweep
	-- North, on the rim.
	local north = Components.Label(dial, { text = "N", face = Theme.Face.Condensed, size = 14, colour = GOLD, align = Enum.TextXAlignment.Center,
		outline = 1.5 })
	north.Name = "North"
	north.AnchorPoint = Vector2.new(0.5, 0.5)
	north.Size = UDim2.fromOffset(16, 16)
	north.ZIndex = 4
	self._north = north
	-- The blips live on their own layer, over the sweep.
	local layer = Instance.new("Frame")
	layer.Name = "Blips"
	layer.BackgroundTransparency = 1
	layer.Size = UDim2.fromScale(1, 1)
	layer.ZIndex = 3
	layer.Parent = dial
	self._layer = layer
	-- You.
	local me = Components.Label(dial, { text = "▲", font = Theme.Font.Bold, size = 18, colour = WHITE, align = Enum.TextXAlignment.Center,
		outline = 2 })
	me.Name = "You"
	me.AnchorPoint = Vector2.new(0.5, 0.5)
	me.Position = UDim2.fromScale(0.5, 0.5)
	me.Size = UDim2.fromOffset(20, 20)
	me.ZIndex = 5
	self._me = me
	-- The rim, outside the canvas so it stays crisp, and the place's name under the dial.
	local rim = circle(holder, "Rim", S, Color3.new(0, 0, 0), 1)
	rim.Position = UDim2.fromOffset(S / 2, S / 2)
	local rimStroke = Components.Stroke(rim, Color3.fromRGB(20, 22, 28), 3)
	rimStroke.Transparency = 0.1
	local glow = circle(holder, "Glow", S + 6, Color3.new(0, 0, 0), 1)
	glow.Position = UDim2.fromOffset(S / 2, S / 2)
	local glowStroke = Components.Stroke(glow, TEAL, 1.5)
	glowStroke.Transparency = 0.55
	local place = Components.Label(holder, { text = "", face = Theme.Face.Condensed, size = 15, colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center, outline = 1.5 })
	place.Name = "Place"
	place.Position = UDim2.fromOffset(0, S + 3)
	place.Size = UDim2.fromOffset(S, 16)
	place.TextTruncate = Enum.TextTruncate.AtEnd
	self._where = place

	local acc = 0
	self._conn = RunService.RenderStepped:Connect(function(dt: number)
		self._sweep = (self._sweep + dt / Radar.SWEEP) % 1
		sweep.Rotation = self._sweep * 360
		acc += dt
		if acc >= 1 / 15 then
			acc = 0
			self:_update()
		end
	end)
	return self
end

function Radar._blip(self: any, key: any, kind: string): Blip
	local b = self._blips[key]
	if b then
		return b
	end
	local frame = Instance.new("Frame")
	frame.Name = kind
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundTransparency = 1
	frame.Size = UDim2.fromOffset(16, 16)
	frame.Parent = self._layer
	local size = if kind == "boss" then 11 elseif kind == "marker" then 0 else 7
	local colour = if kind == "boss" then GOLD elseif kind == "player" then WHITE else RED
	local dot = circle(frame, "Dot", size, colour, if kind == "marker" then 1 else 0)
	Components.Stroke(dot, Color3.fromRGB(10, 10, 14), 1.5).Transparency = if kind == "marker" then 1 else 0.2
	local tag: TextLabel? = nil
	if kind == "marker" or kind == "boss" then
		local t = Components.Label(frame, { text = "", font = Theme.Font.Bold, size = if kind == "boss" then 11 else 15,
			align = Enum.TextXAlignment.Center, outline = if kind == "marker" then 1.5 else false })
		t.Name = "Tag"
		t.AnchorPoint = Vector2.new(0.5, 0.5)
		t.Position = UDim2.fromScale(0.5, if kind == "boss" then -0.2 else 0.5)
		t.Size = UDim2.fromOffset(18, 18)
		tag = t
	end
	b = { frame = frame, dot = dot, tag = tag, seen = true }
	self._blips[key] = b
	return b
end

--- Put a blip at (x, y) studs from you (right, ahead). Clamped to the rim if `pin`, otherwise
--- hidden past it. Returns whether it is showing.
function Radar._put(self: any, b: Blip, x: number, y: number, pin: boolean): boolean
	local S = Radar.SIZE
	local scale = (S / 2) / Radar.RANGE
	local px, py = x * scale, -y * scale
	local d = math.sqrt(px * px + py * py)
	local limit = S / 2 - 9
	if d > limit then
		if not pin then
			b.frame.Visible = false
			return false
		end
		px, py = px / d * limit, py / d * limit
	end
	b.frame.Visible = true
	b.frame.Position = UDim2.fromOffset(S / 2 + px, S / 2 + py)
	return true
end

function Radar:_update()
	local camera = workspace.CurrentCamera
	local player = Players.LocalPlayer
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local visible = not self._hidden and camera ~= nil and root ~= nil and root:IsA("BasePart")
	self._holder.Visible = visible
	if not visible or not camera or not root or not root:IsA("BasePart") then
		return
	end
	local me = root.Position
	local look = camera.CFrame.LookVector
	for _, b in pairs(self._blips) do
		b.seen = false
	end
	-- North on the rim; your arrow turned the way your body faces.
	do
		local nx, ny = Radar.Project(Vector3.new(0, 0, 1), look)
		local S = Radar.SIZE
		self._north.Position = UDim2.fromOffset(S / 2 + nx * (S / 2 - 11), S / 2 - ny * (S / 2 - 11))
		local fx, fy = Radar.Project(root.CFrame.LookVector, look)
		self._me.Rotation = math.deg(math.atan2(fx, fy))
	end
	-- People.
	local function person(model: Model, kind: string)
		local body = model:FindFirstChild("HumanoidRootPart")
		local humanoid = model:FindFirstChildOfClass("Humanoid")
		if not (body and body:IsA("BasePart") and humanoid and humanoid.Health > 0) then
			return
		end
		local offset = body.Position - me
		local flat = Vector3.new(offset.X, 0, offset.Z).Magnitude
		local marked = model:FindFirstChild("RadarMark") ~= nil
		if kind == "enemy" and flat > Radar.CLOSE and not marked then
			return
		end
		local b = self:_blip(model, kind)
		b.seen = true
		local x, y = Radar.Project(offset, look)
		if self:_put(b, x, y, kind == "boss") then
			local far = math.abs(offset.Y) > Radar.HEIGHT
			b.dot.BackgroundTransparency = if far then 0.55 else 0
			if b.tag and kind == "boss" then
				b.tag.Text = "👑"
			end
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p ~= player and p.Character then
			person(p.Character, "player")
		end
	end
	for _, model in ipairs(CollectionService:GetTagged("GameNPC")) do
		if model:IsA("Model") then
			person(model, if model:GetAttribute("Boss") == true then "boss" else "enemy")
		end
	end
	-- What the compass knows about.
	local markers = if self._wayfinding and self._wayfinding.Markers then self._wayfinding:Markers() else {}
	for _, m in ipairs(markers) do
		if m.kind ~= "landmark" then
			local b = self:_blip("marker:" .. m.key, "marker")
			b.seen = true
			local x, y = Radar.Project(m.position - me, look)
			self:_put(b, x, y, true)
			if b.tag then
				b.tag.Text = if m.kind == "job" then "◆" else m.icon
				b.tag.TextColor3 = m.colour
			end
		end
	end
	for key, b in pairs(self._blips) do
		if not b.seen then
			b.frame:Destroy()
			self._blips[key] = nil
		end
	end
	-- Where you are.
	local area = if self._wayfinding and self._wayfinding.AreaAt then self._wayfinding:AreaAt(me) else nil
	local name = area and area:GetAttribute("AreaName")
	self._where.Text = if type(name) == "string" then string.upper(name) else ""
end

function Radar:SetVisible(visible: boolean)
	self._hidden = not visible
	self._holder.Visible = visible
end

function Radar:Destroy()
	self._conn:Disconnect()
	self._holder:Destroy()
end

return Radar
