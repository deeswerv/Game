--!strict
-- Finding your way: a compass across the top of the screen, the name of the place you have just
-- walked into, and a marker over wherever your job is.
--
--   COMPASS   your heading (north is up the avenue to ZEE TOWER), Downtown's landmarks as small
--             icons (named when you face them), and what is going on as bright markers with a
--             distance: your job, turf wars, supply drops, the MOST WANTED boss, anyone holding
--             a stick-up bag. A marker for something behind you sits at the edge with an arrow.
--   AREAS     walk into ZEE PLAZA, THE ALLEY, RAINBOW PARK... and its name comes up, big, for a
--             couple of seconds. Downtown marks its areas (parts tagged "Area").
--   JOB       a gold diamond floats over your job's spot, with how far, through walls.
--   NEW JOBS  with no job on, whoever has one for you (the Fixer, the Quartermaster) wears a
--             bobbing gold "!" over their head and goes up on the compass.
--
-- Draws and reads the world; the server says where jobs are (QuestService's waypoint), where
-- turf wars and drops are (their events), and Downtown's builder marks the landmarks ("Waypoint").

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local CollectionService = game:GetService("CollectionService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local QuestConfig = require(ReplicatedStorage:WaitForChild("QuestConfig"))

local Wayfinding = {}
Wayfinding.__index = Wayfinding

local WIDTH, HEIGHT = 460, 36
local SPAN = 150                  -- degrees of heading the strip shows, edge to edge
local Y = 78                      -- under the cash and the XP bar
local ICON_Y = 11                 -- markers ride the top half of the strip...
local LETTER_Y = 25               -- ...the letters and ticks the bottom
local TITLE_Y = 0.37              -- the area title: under where the banners come down
local LANDMARK_RANGE = 700        -- landmarks further off than this are not shown
local GOLD = Color3.fromRGB(255, 200, 48)
local RED = Color3.fromRGB(240, 64, 64)
local CYAN = Color3.fromRGB(80, 214, 255)
local DIM = Color3.fromRGB(200, 204, 214)

local CARDINALS = { [0] = "N", [45] = "NE", [90] = "E", [135] = "SE", [180] = "S", [225] = "SW", [270] = "W", [315] = "NW" }

--- What a quest giver is called on the compass (and on Downtown's landmark for them).
local function giverTitle(name: string): string
	local spec = QuestConfig.Givers and QuestConfig.Givers[name]
	return string.upper(tostring(spec and spec.displayName or name))
end


type JobMarker = { anchor: BasePart?, gui: BillboardGui? }

export type Marker = {
	key: string, kind: string, icon: string, colour: Color3, name: string?,
	position: Vector3?, part: BasePart?, model: Model?,
}

--- Degrees clockwise from north (+Z), with east at -X -- the way a compass reads when north
--- is ahead of you.
function Wayfinding.Bearing(dx: number, dz: number): number
	return math.deg(math.atan2(-dx, dz)) % 360
end

--- `a - b` as the short way round, in (-180, 180].
function Wayfinding.Relative(a: number, b: number): number
	local d = (a - b) % 360
	if d > 180 then
		d -= 360
	end
	return d
end

local function label(parent: GuiObject, text: string, size: number, colour: Color3?, font: Enum.Font?): TextLabel
	local l = Components.Label(parent, {
		text = text,
		font = font or Theme.Font.Bold,
		size = size,
		colour = colour,
		align = Enum.TextXAlignment.Center,
		outline = if size >= 16 then 1.6 else 1.1,
	})
	l.AnchorPoint = Vector2.new(0.5, 0.5)
	l.Size = UDim2.fromOffset(80, size + 4)
	return l
end

function Wayfinding.new(screen: GuiObject, playerGui: Instance)
	local self = setmetatable({}, Wayfinding)
	self._gui = playerGui
	self._hidden = false
	self._markers = {} :: { [string]: Marker }
	self._views = {} :: { [string]: { frame: Frame, icon: TextLabel, text: TextLabel, arrow: TextLabel } }
	self._areas = {} :: { [BasePart]: boolean }
	self._area = nil :: BasePart?
	self._shown = {} :: { [string]: number }
	self._titleToken = 0
	self._offers = {} :: { [string]: boolean }
	self._offerMarks = {} :: { [string]: BillboardGui }

	-- The strip.
	local strip = Instance.new("Frame")
	strip.Name = "Compass"
	strip.AnchorPoint = Vector2.new(0.5, 0)
	strip.Position = UDim2.new(0.5, 0, 0, Y)
	strip.Size = UDim2.fromOffset(WIDTH, HEIGHT)
	strip.BackgroundColor3 = Theme.Colour.Panel
	strip.BackgroundTransparency = 0.3
	strip.BorderSizePixel = 0
	strip.ClipsDescendants = true
	strip.Parent = screen
	Components.Corner(strip, 8)
	-- Fading out at both ends, so the strip reads as a window onto a wheel.
	local fade = Instance.new("UIGradient")
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.14, 0.15),
		NumberSequenceKeypoint.new(0.86, 0.15), NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = strip
	self._strip = strip

	-- Ticks every 15 degrees, a letter on every 45.
	self._ticks = {} :: { { angle: number, gui: GuiObject } }
	for angle = 0, 345, 15 do
		local card = CARDINALS[angle]
		local gui: GuiObject
		if card then
			local l = label(strip, card, if #card == 1 then 15 else 12, if card == "N" then GOLD else Color3.new(1, 1, 1),
				Theme.Font.Display)
			l.Position = UDim2.new(0.5, 0, 0, LETTER_Y)
			gui = l
		else
			local tick = Instance.new("Frame")
			tick.AnchorPoint = Vector2.new(0.5, 1)
			tick.Size = UDim2.fromOffset(2, 7)
			tick.BackgroundColor3 = Color3.new(1, 1, 1)
			tick.BackgroundTransparency = 0.45
			tick.BorderSizePixel = 0
			tick.Position = UDim2.new(0.5, 0, 1, -2)
			tick.Parent = strip
			gui = tick
		end
		table.insert(self._ticks, { angle = angle, gui = gui })
	end

	-- The heading mark: a gold needle down from the top edge of the middle.
	local caret = Instance.new("Frame")
	caret.Name = "CompassNeedle"
	caret.AnchorPoint = Vector2.new(0.5, 0)
	caret.Position = UDim2.new(0.5, 0, 0, Y)
	caret.Size = UDim2.fromOffset(3, 7)
	caret.BackgroundColor3 = GOLD
	caret.BorderSizePixel = 0
	caret.ZIndex = 3
	caret.Parent = screen
	self._caret = caret

	-- The markers ride a layer the same size as the strip that does not clip, so a distance can
	-- hang underneath it.
	local layer = Instance.new("Frame")
	layer.Name = "CompassMarkers"
	layer.AnchorPoint = Vector2.new(0.5, 0)
	layer.Position = strip.Position
	layer.Size = strip.Size
	layer.BackgroundTransparency = 1
	layer.Parent = screen
	self._layer = layer

	-- The area title.
	local title = Instance.new("CanvasGroup")
	title.Name = "AreaTitle"
	title.AnchorPoint = Vector2.new(0.5, 0.5)
	title.Position = UDim2.fromScale(0.5, TITLE_Y)
	title.Size = UDim2.fromOffset(640, 90)
	title.BackgroundTransparency = 1
	title.GroupTransparency = 1
	title.Visible = false
	title.Parent = screen
	local name = Components.Label(title, {
		text = "",
		face = Theme.Face.HeavyItalic,
		size = 50,
		align = Enum.TextXAlignment.Center,
		outline = 3,
	})
	name.Size = UDim2.new(1, 0, 0, 56)
	local sub = Components.Label(title, {
		text = "",
		font = Theme.Font.Bold,
		size = 17,
		colour = GOLD,
		align = Enum.TextXAlignment.Center,
		outline = 1.6,
	})
	sub.Position = UDim2.fromOffset(0, 60)
	sub.Size = UDim2.new(1, 0, 0, 22)
	for _, side in ipairs({ -1, 1 }) do
		local rule = Instance.new("Frame")
		rule.AnchorPoint = Vector2.new(0.5, 0.5)
		rule.Position = UDim2.new(0.5, side * 190, 0, 71)
		rule.Size = UDim2.fromOffset(110, 2)
		rule.BackgroundColor3 = GOLD
		rule.BorderSizePixel = 0
		rule.Parent = title
	end
	self._title, self._titleName, self._titleSub = title, name, sub

	-- The job marker in the world.
	self._job = {} :: JobMarker

	-- Landmarks and areas, as Downtown marks them (and as they stream in).
	for _, part in ipairs(CollectionService:GetTagged("Waypoint")) do
		self:_landmark(part)
	end
	CollectionService:GetInstanceAddedSignal("Waypoint"):Connect(function(part)
		self:_landmark(part)
	end)
	for _, part in ipairs(CollectionService:GetTagged("Area")) do
		if part:IsA("BasePart") then
			self._areas[part] = true
		end
	end
	CollectionService:GetInstanceAddedSignal("Area"):Connect(function(part)
		if part:IsA("BasePart") then
			self._areas[part] = true
		end
	end)

	RunService.RenderStepped:Connect(function()
		self:_update()
	end)
	task.spawn(function()
		while true do
			task.wait(0.35)
			self:_checkArea()
		end
	end)
	return self
end

function Wayfinding:_landmark(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local name = tostring(part:GetAttribute("WaypointName") or "")
	self._markers["landmark:" .. name] = {
		key = "landmark:" .. name, kind = "landmark", icon = tostring(part:GetAttribute("WaypointIcon") or "•"),
		colour = DIM, name = name, part = part,
	}
end

--- Put a marker up (or move it). `kind` decides how it looks: "job", "turf", "supply",
--- "wanted", "bag" are bright and always show a distance; "landmark" is quiet.
function Wayfinding:Set(key: string, kind: string, icon: string, colour: Color3, name: string?, where: any)
	local m: Marker = { key = key, kind = kind, icon = icon, colour = colour, name = name }
	if typeof(where) == "Vector3" then
		m.position = where
	elseif typeof(where) == "Instance" and where:IsA("BasePart") then
		m.part = where
	elseif typeof(where) == "Instance" and where:IsA("Model") then
		m.model = where
	end
	self._markers[key] = m
end

function Wayfinding:Clear(key: string)
	self._markers[key] = nil
	local view = self._views[key]
	if view then
		view.frame:Destroy()
		self._views[key] = nil
	end
end

local function positionOf(m: Marker): Vector3?
	if m.position then
		return m.position
	elseif m.part then
		return if m.part.Parent then m.part.Position else nil
	elseif m.model then
		local root = m.model.Parent and (m.model.PrimaryPart or m.model:FindFirstChild("HumanoidRootPart"))
		return if root and root:IsA("BasePart") then root.Position else nil
	end
	return nil
end

function Wayfinding:_view(m: Marker)
	local view = self._views[m.key]
	if view then
		return view
	end
	local frame = Instance.new("Frame")
	frame.Name = m.key
	frame.AnchorPoint = Vector2.new(0.5, 0)
	frame.Size = UDim2.fromOffset(90, 44)
	frame.BackgroundTransparency = 1
	frame.Parent = self._layer
	local icon = label(frame, m.icon, if m.kind == "landmark" then 13 else 16, m.colour)
	icon.Name = "Icon"
	icon.Position = UDim2.new(0.5, 0, 0, ICON_Y)
	local text = label(frame, "", 12, m.colour)
	text.Name = "Distance"
	text.Size = UDim2.fromOffset(140, 16)
	text.Position = UDim2.new(0.5, 0, 0, HEIGHT + 8)
	local arrow = label(frame, "", 13, m.colour, Theme.Font.Display)
	arrow.Name = "Arrow"
	arrow.Position = UDim2.new(0.5, 0, 0, ICON_Y)
	arrow.Visible = false
	view = { frame = frame, icon = icon, text = text, arrow = arrow }
	self._views[m.key] = view
	return view
end

-- ------------------------------------------------------------------ the job --

--- Your quest: its spot goes on the compass and gets the floating marker.
function Wayfinding:_setJobMarker(at: Vector3?, name: string?)
	local job: JobMarker = self._job
	if not at then
		if job.anchor then
			job.anchor:Destroy()
			job.anchor = nil
		end
		if job.gui then
			job.gui:Destroy()
			job.gui = nil
		end
		return
	end
	local anchor = job.anchor
	if not anchor then
		local made = Instance.new("Part")
		made.Name = "JobMarker"
		made.Anchored = true
		made.CanCollide = false
		made.CanQuery = false
		made.CanTouch = false
		made.Transparency = 1
		made.Size = Vector3.new(0.2, 0.2, 0.2)
		made.Parent = workspace
		anchor = made
		job.anchor = made
	end
	(anchor :: BasePart).CFrame = CFrame.new(at + Vector3.new(0, 5, 0))
	local gui = job.gui
	if not gui then
		local made = Instance.new("BillboardGui")
		made.Name = "JobMarker"
		made.AlwaysOnTop = true
		made.Size = UDim2.fromOffset(160, 72)
		made.MaxDistance = 3000
		made.LightInfluence = 0
		made.Parent = self._gui
		local diamond = label(made :: any, "◆", 34, GOLD, Theme.Font.Display)
		diamond.Name = "Diamond"
		diamond.Position = UDim2.new(0.5, 0, 0, 18)
		local caption = label(made :: any, "", 14, Color3.new(1, 1, 1))
		caption.Name = "Caption"
		caption.Size = UDim2.fromOffset(160, 18)
		caption.Position = UDim2.new(0.5, 0, 0, 44)
		local dist = label(made :: any, "", 13, GOLD)
		dist.Name = "Distance"
		dist.Size = UDim2.fromOffset(160, 16)
		dist.Position = UDim2.new(0.5, 0, 0, 61)
		gui = made
		job.gui = made
	end
	local billboard = gui :: BillboardGui
	billboard.Adornee = anchor :: BasePart
	local caption = billboard:FindFirstChild("Caption")
	if caption and caption:IsA("TextLabel") then
		caption.Text = string.upper(name or "")
	end
end

function Wayfinding:_updateJob(from: Vector3)
	local job: JobMarker = self._job
	local gui, anchor = job.gui, job.anchor
	if not gui or not anchor then
		return
	end
	local d = (anchor.Position - from).Magnitude
	-- Standing on it, the marker has nothing to say.
	gui.Enabled = not self._hidden and d > 14
	local dist = gui:FindFirstChild("Distance")
	if dist and dist:IsA("TextLabel") then
		dist.Text = ("%dm"):format(math.floor(d + 0.5))
	end
end

function Wayfinding:SetQuest(active: any)
	local at: Vector3? = if type(active) == "table" and typeof(active.waypoint) == "Vector3" then active.waypoint else nil
	local name: string? = if at then tostring(active.waypointName or active.title or "JOB") else nil
	if at and name then
		self:Set("job", "job", "◆", GOLD, name, at)
	else
		self:Clear("job")
	end
	self:_setJobMarker(at, name)
end

function Wayfinding:_update()
	local camera = workspace.CurrentCamera
	local visible = not self._hidden and camera ~= nil
	self._strip.Visible = visible
	self._caret.Visible = visible
	self._layer.Visible = visible
	if not visible then
		return
	end
	local look = camera.CFrame.LookVector
	local heading = Wayfinding.Bearing(look.X, look.Z)
	local pxPerDeg = WIDTH / SPAN
	for _, t in ipairs(self._ticks) do
		local rel = Wayfinding.Relative(t.angle, heading)
		t.gui.Visible = math.abs(rel) <= SPAN / 2 + 4
		t.gui.Position = UDim2.new(0.5, rel * pxPerDeg, t.gui.Position.Y.Scale, t.gui.Position.Y.Offset)
	end

	local me = Players.LocalPlayer
	local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	local from = if root and root:IsA("BasePart") then root.Position else camera.CFrame.Position
	local live: { [string]: boolean } = {}
	for key, m in pairs(self._markers) do
		local at = positionOf(m)
		local offset = at and (at - from)
		local distance = offset and Vector3.new(offset.X, 0, offset.Z).Magnitude or math.huge
		local show = at ~= nil and (m.kind ~= "landmark" or distance <= LANDMARK_RANGE) and distance > 6
		if show and offset then
			live[key] = true
			local view = Wayfinding._view(self :: any, m)
			local rel = Wayfinding.Relative(Wayfinding.Bearing(offset.X, offset.Z), heading)
			local half = SPAN / 2 - 6
			local edge = math.abs(rel) > half
			local x = math.clamp(rel, -half, half) * pxPerDeg
			view.frame.Position = UDim2.new(0.5, x, 0, 0)
			local metres = ("%dm"):format(math.floor(distance + 0.5))
			if m.kind == "landmark" then
				-- A landmark stays out of the way: off the edge it is simply not shown, and its
				-- name only comes up when you are looking right at it. (Nor is it shown twice:
				-- a giver with a new job for you is already up as that.)
				local offered = false
				for giver in pairs(self._offers) do
					offered = offered or giverTitle(giver) == m.name
				end
				view.frame.Visible = not edge and not offered
				view.text.Text = if math.abs(rel) < 9 then (m.name or "") .. "  " .. metres else ""
				view.icon.TextTransparency = if math.abs(rel) < 9 then 0 else 0.35
			else
				view.frame.Visible = true
				view.text.Text = if math.abs(rel) < 12 and m.name then m.name .. "  " .. metres else metres
				view.arrow.Visible = edge
				view.arrow.Text = if rel < 0 then "◀" else "▶"
				view.arrow.Position = UDim2.new(0.5, if rel < 0 then -16 else 16, 0, ICON_Y)
			end
			view.frame.ZIndex = if m.kind == "landmark" then 1 else 2
		end
	end
	for key, view in pairs(self._views) do
		if not live[key] then
			view.frame.Visible = false
		end
	end
	self:_updateJob(from)
end

-- ------------------------------------------------------------- live events --

function Wayfinding:HandleTurf(kind: string, data: any)
	if type(data) ~= "table" then
		return
	end
	local key = "turf:" .. tostring(data.id or data.zone or "?")
	if kind == "start" and typeof(data.position) == "Vector3" then
		self:Set(key, "turf", "⚔", RED, string.upper(tostring(data.zone or "TURF WAR")), data.position)
	elseif kind == "won" or kind == "lost" then
		self:Clear(key)
	end
end

function Wayfinding:HandleSupply(kind: string, data: any)
	if type(data) ~= "table" then
		return
	end
	local key = "supply:" .. tostring(data.id or 0)
	if (kind == "inbound" or kind == "landed") and typeof(data.position) == "Vector3" then
		self:Set(key, "supply", "📦", CYAN, if data.golden then "ELITE SUPPLY" else "SUPPLY DROP", data.position)
	elseif kind == "opened" or kind == "gone" then
		self:Clear(key)
	end
end

--- Things with a price on them, found from what everyone can already see: the MOST WANTED
--- boss (tagged), and anybody holding a stick-up bag.
function Wayfinding:Refresh()
	local seen: { [string]: boolean } = {}
	for _, model in ipairs(CollectionService:GetTagged("MostWanted")) do
		if model:IsA("Model") then
			local key = "wanted:" .. model:GetFullName()
			seen[key] = true
			if not self._markers[key] then
				self:Set(key, "wanted", "🎯", RED, "MOST WANTED", model)
			end
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		local key = "bag:" .. p.UserId
		if p ~= Players.LocalPlayer and (tonumber(p:GetAttribute("Bag")) or 0) > 0 and p.Character then
			seen[key] = true
			self:Set(key, "bag", "💰", GOLD, p.DisplayName, p.Character)
		end
	end
	for key, m in pairs(self._markers) do
		if (m.kind == "wanted" or m.kind == "bag") and not seen[key] then
			self:Clear(key)
		end
	end
	self:_refreshOffers()
end

-- ------------------------------------------------------------- new jobs --

--- Who has a new job for you (QuestService's `available`): nil or {} when nobody does.
function Wayfinding:SetOffers(available: any)
	local wanted: { [string]: boolean } = {}
	if type(available) == "table" then
		for name, yes in pairs(available) do
			if yes == true and type(name) == "string" then
				wanted[name] = true
			end
		end
	end
	self._offers = wanted
	self:_refreshOffers()
end

--- Put the "!" over each giver with a job (once their body is in the world), take it off
--- the rest.
function Wayfinding:_refreshOffers()
	local marks: { [string]: BillboardGui } = self._offerMarks
	for name, gui in pairs(marks) do
		local giver = workspace:FindFirstChild("QuestGiver_" .. name)
		if not self._offers[name] or not giver or not gui.Parent then
			gui:Destroy()
			marks[name] = nil
			self:Clear("offer:" .. name)
		end
	end
	for name in pairs(self._offers) do
		local giver = workspace:FindFirstChild("QuestGiver_" .. name)
		local head = giver and giver:FindFirstChild("Head")
		if head and head:IsA("BasePart") and not marks[name] then
			self:Set("offer:" .. name, "offer", "!", GOLD, giverTitle(name) .. " · NEW JOB", head)
			local gui = Instance.new("BillboardGui")
			gui.Name = "OfferMarker"
			gui.Adornee = head
			gui.Size = UDim2.fromOffset(60, 60)
			gui.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0)
			gui.AlwaysOnTop = true
			gui.MaxDistance = 260
			gui.LightInfluence = 0
			gui.ResetOnSpawn = false
			gui.Enabled = not self._hidden
			gui.Parent = self._gui
			local bang = label(gui :: any, "!", 50, GOLD, Theme.Font.Display)
			bang.Name = "Bang"
			bang.Size = UDim2.fromScale(1, 1)
			bang.Position = UDim2.fromScale(0.5, 0.5)
			-- A slow bob, so it catches the eye across a street without shouting.
			TweenService:Create(gui, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
				{ StudsOffsetWorldSpace = Vector3.new(0, 5.3, 0) }):Play()
			marks[name] = gui
		end
	end
end

-- ------------------------------------------------------------------- areas --

local function inside(part: BasePart, at: Vector3): boolean
	local rel = part.CFrame:PointToObjectSpace(at)
	local half = part.Size / 2
	return math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
end

--- The smallest named area around `at`, if any.
function Wayfinding:AreaAt(at: Vector3): BasePart?
	local best, bestVolume = nil, math.huge
	for part in pairs(self._areas) do
		if part.Parent == nil then
			self._areas[part] = nil
		elseif inside(part, at) then
			local v = part.Size.X * part.Size.Y * part.Size.Z
			if v < bestVolume then
				best, bestVolume = part, v
			end
		end
	end
	return best
end

function Wayfinding:_checkArea()
	self:Refresh()
	local me = Players.LocalPlayer
	local root = me.Character and me.Character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end
	local area = self:AreaAt(root.Position)
	if area == self._area then
		return
	end
	local previous = self._area
	self._area = area
	if not area then
		return
	end
	local name = tostring(area:GetAttribute("AreaName") or "")
	-- The district's own name only when you arrive in it, not every time you step out of a
	-- shop back into the street.
	if previous ~= nil and area.Size.Magnitude > 400 then
		return
	end
	-- And a place you were just in does not announce itself again as you cross its edge.
	local last = self._shown[name]
	if last and os.clock() - last < 25 then
		return
	end
	self._shown[name] = os.clock()
	self:ShowTitle(name, tostring(area:GetAttribute("AreaSub") or ""))
end

function Wayfinding:ShowTitle(name: string, sub: string)
	if self._hidden then
		return
	end
	local title = self._title
	self._titleName.Text = name
	self._titleSub.Text = sub
	title.Visible = true
	title.GroupTransparency = 1
	title.Position = UDim2.new(0.5, 0, TITLE_Y, 12)
	TweenService:Create(title, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ GroupTransparency = 0, Position = UDim2.fromScale(0.5, TITLE_Y) }):Play()
	local token = os.clock()
	self._titleToken = token
	task.delay(2.6, function()
		if self._titleToken ~= token then
			return
		end
		local out = TweenService:Create(title, TweenInfo.new(0.6), { GroupTransparency = 1 })
		out.Completed:Once(function()
			if self._titleToken == token then
				title.Visible = false
			end
		end)
		out:Play()
	end)
end

function Wayfinding:SetVisible(visible: boolean)
	self._hidden = not visible
	for _, gui in pairs(self._offerMarks :: { [string]: BillboardGui }) do
		gui.Enabled = visible
	end
	if not visible then
		self._title.Visible = false
	end
	local gui = (self._job :: JobMarker).gui
	if gui then
		gui.Enabled = visible
	end
end

return Wayfinding
