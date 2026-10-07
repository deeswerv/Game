--!strict
-- Downtown's status, beside the radar (top right) while you are in the district: how the
-- streets stand.
--
--   DOWNTOWN            THREAT ▮▮▮▯▯
--   THE CAR PARK        HELD           (green: the street holds it, and it pays tribute)
--   THE COURTS          TURF WAR       (orange, beating: a crew is on it now)
--   THE ALLEY           CREW           (red: theirs -- step in to start a war)
--   THE PARK            QUIET          (grey: just fought over)
--   HOLDING 1/4          🎯 VINNIE RUSSO
--
-- Reads what the server publishes and nothing else: the threat (TurfThreat), each patch's
-- state (Turf_<id>), how many the street holds (TurfControl), and whoever is MOST WANTED (the
-- tagged boss). A RAID -- the crew back for a held patch -- beats red and orange.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local District = {}
District.__index = District

District.CENTRE = Vector3.new(-155, 1000, 1500)   -- DistrictService.CENTRE
District.REACH = 280                               -- TurfWarService.HOLD.district
District.PATCHES = {
	{ id = "CarPark", name = "THE CAR PARK" }, { id = "Courts", name = "THE COURTS" },
	{ id = "Alley", name = "THE ALLEY" }, { id = "Park", name = "THE PARK" },
}

local STATES: { [string]: { text: string, colour: Color3, beat: boolean? } } = {
	crew = { text = "CREW", colour = Color3.fromRGB(236, 64, 60) },
	war = { text = "TURF WAR", colour = Color3.fromRGB(255, 150, 40), beat = true },
	raid = { text = "RAID", colour = Color3.fromRGB(255, 96, 50), beat = true },
	held = { text = "HELD", colour = Color3.fromRGB(70, 214, 120) },
	quiet = { text = "QUIET", colour = Color3.fromRGB(150, 154, 164) },
}

local WIDTH = 214
local ROW = 15
-- Beside the radar, and short enough to end above the banners and the boss bar (y 134) where
-- they reach across on a narrow screen.
local RADAR_WIDTH = 150 + 12
local TOP = 12

--- Is a point in Downtown (as the district's tribute counts it)?
function District.Inside(at: Vector3): boolean
	local d = at - District.CENTRE
	return Vector3.new(d.X, 0, d.Z).Magnitude <= District.REACH and d.Y > -20 and d.Y < 220
end

function District.new(screen: GuiObject)
	local self = setmetatable({}, District)
	self._hidden = false
	self._rows = {} :: { [string]: { chip: Frame, text: TextLabel, dot: Frame } }

	local card = Instance.new("Frame")
	card.Name = "District"
	card.AnchorPoint = Vector2.new(1, 0)
	card.Position = UDim2.new(1, -(Theme.Inset.Side + RADAR_WIDTH), 0, TOP)
	card.Size = UDim2.fromOffset(WIDTH, 0)
	card.AutomaticSize = Enum.AutomaticSize.Y
	card.BackgroundColor3 = Color3.fromRGB(12, 14, 20)
	card.BackgroundTransparency = 0.2
	card.BorderSizePixel = 0
	card.Visible = false
	card.Parent = screen
	Components.Corner(card, 12)
	Components.Stroke(card, Color3.fromRGB(255, 255, 255), 1).Transparency = 0.82
	Components.Padding(card, 6, 10, 6)
	Components.List(card, Enum.FillDirection.Vertical, 2)
	self._card = card

	-- The head: the district and the threat.
	local head = Instance.new("Frame")
	head.Name = "Head"
	head.BackgroundTransparency = 1
	head.Size = UDim2.new(1, 0, 0, 18)
	head.LayoutOrder = 1
	head.Parent = card
	local title = Components.Label(head, { text = "DOWNTOWN", face = Theme.Face.HeavyItalic, size = 15, outline = 2 })
	title.Size = UDim2.new(0.48, 0, 1, 0)
	local threat = Components.Label(head, { text = "", face = Theme.Face.Condensed, size = 13, colour = Color3.fromRGB(255, 120, 90),
		align = Enum.TextXAlignment.Right, outline = 1.5 })
	threat.Name = "Threat"
	threat.AnchorPoint = Vector2.new(1, 0)
	threat.Position = UDim2.fromScale(1, 0)
	threat.Size = UDim2.new(0.52, 0, 1, 0)
	self._threat = threat

	-- A row per patch.
	for i, patch in ipairs(District.PATCHES) do
		local row = Instance.new("Frame")
		row.Name = patch.id
		row.BackgroundTransparency = 1
		row.Size = UDim2.new(1, 0, 0, ROW)
		row.LayoutOrder = 1 + i
		row.Parent = card
		local dot = Instance.new("Frame")
		dot.Name = "Dot"
		dot.AnchorPoint = Vector2.new(0, 0.5)
		dot.Position = UDim2.new(0, 0, 0.5, 0)
		dot.Size = UDim2.fromOffset(7, 7)
		dot.BorderSizePixel = 0
		dot.Parent = row
		Components.Corner(dot, 4)
		local name = Components.Label(row, { text = patch.name, face = Theme.Face.Condensed, size = 14, outline = 1.5 })
		name.Position = UDim2.fromOffset(12, 0)
		name.Size = UDim2.new(1, -84, 1, 0)
		local chip = Instance.new("Frame")
		chip.Name = "State"
		chip.AnchorPoint = Vector2.new(1, 0.5)
		chip.Position = UDim2.new(1, 0, 0.5, 0)
		chip.Size = UDim2.fromOffset(70, ROW - 1)
		chip.BorderSizePixel = 0
		chip.Parent = row
		Components.Corner(chip, 7)
		local text = Components.Label(chip, { text = "", face = Theme.Face.Condensed, size = 12, align = Enum.TextXAlignment.Center,
			outline = 1.2 })
		text.Size = UDim2.fromScale(1, 1)
		self._rows[patch.id] = { chip = chip, text = text, dot = dot }
	end

	-- The foot: the street's hold, and who is MOST WANTED.
	local foot = Instance.new("Frame")
	foot.Name = "Foot"
	foot.BackgroundTransparency = 1
	foot.Size = UDim2.new(1, 0, 0, 15)
	foot.LayoutOrder = 10
	foot.Parent = card
	local hold = Components.Label(foot, { text = "", face = Theme.Face.Condensed, size = 13, colour = Theme.Colour.TextDim, outline = 1.2 })
	hold.Name = "Hold"
	hold.Size = UDim2.new(0.42, 0, 1, 0)
	self._hold = hold
	local wanted = Components.Label(foot, { text = "", face = Theme.Face.Condensed, size = 13, colour = Color3.fromRGB(255, 200, 48),
		align = Enum.TextXAlignment.Right, outline = 1.2 })
	wanted.Name = "Wanted"
	wanted.AnchorPoint = Vector2.new(1, 0)
	wanted.Position = UDim2.fromScale(1, 0)
	wanted.Size = UDim2.new(0.58, 0, 1, 0)
	wanted.TextTruncate = Enum.TextTruncate.AtEnd
	self._wanted = wanted

	local acc = 0
	self._conn = RunService.Heartbeat:Connect(function(dt: number)
		acc += dt
		if acc >= 0.25 then
			acc = 0
			self:_update()
		end
	end)
	return self
end

function District:_update()
	local player = Players.LocalPlayer
	local character = player and player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local here = root ~= nil and root:IsA("BasePart") and District.Inside(root.Position)
	self._card.Visible = here and not self._hidden
	if not self._card.Visible then
		return
	end
	local threat = math.clamp(tonumber(ReplicatedStorage:GetAttribute("TurfThreat")) or 1, 1, 5)
	self._threat.Text = "THREAT " .. string.rep("▮", threat) .. string.rep("▯", 5 - threat)
	local beat = math.floor(os.clock() * 2.5) % 2 == 0
	for _, patch in ipairs(District.PATCHES) do
		local row = self._rows[patch.id]
		local state = STATES[tostring(ReplicatedStorage:GetAttribute("Turf_" .. patch.id) or "crew")] or STATES.crew
		row.text.Text = state.text
		local colour = if state.beat and beat then state.colour:Lerp(Color3.new(1, 1, 1), 0.25) else state.colour
		row.chip.BackgroundColor3 = colour:Lerp(Color3.new(0, 0, 0), 0.35)
		row.dot.BackgroundColor3 = colour
	end
	local held = tonumber(ReplicatedStorage:GetAttribute("TurfControl")) or 0
	self._hold.Text = ("HOLDING %d/%d"):format(held, #District.PATCHES)
	self._hold.TextColor3 = if held == #District.PATCHES then Color3.fromRGB(70, 214, 120) else Theme.Colour.TextDim
	local wanted = CollectionService:GetTagged("MostWanted")[1]
	self._wanted.Text = if wanted and wanted:IsA("Model") and wanted.Parent then "🎯 " .. string.upper(wanted.Name) else ""
end

function District:SetVisible(visible: boolean)
	self._hidden = not visible
	self:_update()
end

function District:Destroy()
	self._conn:Disconnect()
	self._card:Destroy()
end

return District
