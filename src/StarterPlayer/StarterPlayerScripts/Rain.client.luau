--!strict
-- Rain you can see. WeatherService has long rolled a "Rain" state (thicker air, shorter sight
-- for the AI), but nothing fell. While it rains, this client draws it:
--
--   * streaks falling round the camera, slanting a little in the wind (Beams: no textures to
--     upload, and cheap -- a fixed pool, recycled, nothing created while it runs);
--   * splashes on the ground about you;
--   * wet streets: the cities' roads and paving take a sheen;
--   * a cooler, greyer grade, and now and then lightning -- a double flash, then the thunder
--     a moment later, further off the longer it takes.
--
-- Under a roof it eases off, so it never rains indoors. It fades in and out over a few
-- seconds as the weather changes, and the GRAPHICS setting scales it (fewer streaks and no
-- splashes on PERFORMANCE). Local and cosmetic: the server never hears of any of it.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

local STREAKS = { 50, 100, 160 }   -- by GRAPHICS level
local RADIUS = 44                   -- studs round the camera it falls in
local HEIGHT = 36                   -- how far above the camera a streak starts
local DEPTH = 22                    -- and below it, where it is recycled
local FALL = 95                     -- studs per second
local LENGTH = 2.8                  -- of a streak
local WIND = Vector3.new(0.12, 0, 0.06)    -- slant: sideways studs per stud fallen
local FADE = 0.35                   -- intensity per second, in and out
local WET = 0.14                    -- extra reflectance on the streets in full rain
local THUNDER_ID = "rbxassetid://1112042117"

-- Ground the rain wets: the big road and paving pieces of the cities, by name.
local GROUND: { [string]: boolean } = {
	Asphalt = true, Pavement = true, Walk = true, Forecourt = true, Lot = true, AlleyFloor = true, Road = true,
	Street = true, Plaza = true, Paving = true, Sidewalk = true,
}
local CITIES = { "Downtown", "Hanami" }

local level = 3
local intensity = 0           -- 0 dry .. 1 full rain, eased
local sheltered = false

-- ------------------------------------------------------------------------- the pool --

local folder = Instance.new("Folder")
folder.Name = "Rain"
local host = Instance.new("Part")
host.Name = "RainHost"
host.Anchored = true
host.CanCollide = false
host.CanQuery = false
host.CanTouch = false
host.Transparency = 1
host.Size = Vector3.new(1, 1, 1)
host.CFrame = CFrame.new()
host.Parent = folder

type Drop = { top: Attachment, bottom: Attachment, beam: Beam, at: Vector3 }
local drops: { Drop } = {}

local STREAK_COLOUR = ColorSequence.new(Color3.fromRGB(206, 220, 236))

local function newDrop(): Drop
	local top = Instance.new("Attachment")
	local bottom = Instance.new("Attachment")
	top.Parent = host
	bottom.Parent = host
	local beam = Instance.new("Beam")
	beam.Name = "Streak"
	beam.Attachment0 = top
	beam.Attachment1 = bottom
	beam.Width0 = 0.05
	beam.Width1 = 0.035
	beam.FaceCamera = true
	beam.Segments = 1
	beam.Color = STREAK_COLOUR
	beam.LightEmission = 0.25
	beam.LightInfluence = 0.8
	beam.Transparency = NumberSequence.new(1)
	beam.Enabled = false
	beam.Parent = host
	return { top = top, bottom = bottom, beam = beam, at = Vector3.new(0, 0, 0) }
end

--- Somewhere in the column round `eye`, anywhere from its top to its foot (`fresh` false:
--- spread through the whole fall, so the first frame is not one sheet at the top).
local function respawn(d: Drop, eye: Vector3, fresh: boolean)
	local a = math.random() * math.pi * 2
	local r = RADIUS * math.sqrt(math.random())
	local y = if fresh then HEIGHT * (0.7 + math.random() * 0.3) else -DEPTH + math.random() * (HEIGHT + DEPTH)
	d.at = eye + Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
end

-- ----------------------------------------------------------------------- splashes --

local splashHost = Instance.new("Part")
splashHost.Name = "Splashes"
splashHost.Anchored = true
splashHost.CanCollide = false
splashHost.CanQuery = false
splashHost.CanTouch = false
splashHost.Transparency = 1
splashHost.Size = Vector3.new(60, 0.1, 60)
splashHost.Parent = folder
local splash = Instance.new("ParticleEmitter")
splash.Name = "Splash"
splash.Texture = "rbxasset://textures/particles/smoke_main.dds"
splash.Shape = Enum.ParticleEmitterShape.Box
splash.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
splash.EmissionDirection = Enum.NormalId.Top
splash.Color = ColorSequence.new(Color3.fromRGB(214, 224, 236))
splash.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.15), NumberSequenceKeypoint.new(1, 0.55) })
splash.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(1, 1) })
splash.Lifetime = NumberRange.new(0.16, 0.3)
splash.Speed = NumberRange.new(1.5, 3.5)
splash.SpreadAngle = Vector2.new(35, 35)
splash.Acceleration = Vector3.new(0, -20, 0)
splash.LightEmission = 0.1
splash.Rate = 0
splash.Parent = splashHost

-- -------------------------------------------------------------------------- grade --

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "RainGrade"
grade.Enabled = false
grade.Parent = Lighting
local flash = 0          -- lightning brightness on top of the grade, decaying

-- ------------------------------------------------------------------------ wet ground --

local ground: { [BasePart]: number } = {}     -- part -> its own reflectance
local wetApplied = 0

local function consider(d: Instance)
	if d:IsA("BasePart") and GROUND[d.Name] and not ground[d] and d.Size.X * d.Size.Z > 60 then
		ground[d] = d.Reflectance
		if wetApplied > 0 then
			d.Reflectance = ground[d] + WET * wetApplied
		end
	end
end

local function watchCity(city: Instance)
	for _, d in ipairs(city:GetDescendants()) do
		consider(d)
	end
	city.DescendantAdded:Connect(consider)
end
for _, name in ipairs(CITIES) do
	local city = workspace:FindFirstChild(name)
	if city then
		watchCity(city)
	end
end
workspace.ChildAdded:Connect(function(child)
	if table.find(CITIES, child.Name) then
		watchCity(child)
	end
end)

local function wet(k: number)
	if math.abs(k - wetApplied) < 0.02 and not (k == 0 and wetApplied > 0) then
		return
	end
	wetApplied = k
	for part, own in pairs(ground) do
		if part.Parent then
			part.Reflectance = own + WET * k
		else
			ground[part] = nil
		end
	end
end

-- ---------------------------------------------------------------------- the weather --

local function raining(): boolean
	return workspace:GetAttribute("Weather") == "Rain"
end

local function readLevel()
	local raw = tonumber(player:GetAttribute("GraphicsQuality"))
	level = if raw then math.clamp(math.floor(raw + 0.5), 1, 3) else 3
end
player:GetAttributeChangedSignal("GraphicsQuality"):Connect(readLevel)
readLevel()

local shelterParams = RaycastParams.new()
shelterParams.FilterType = Enum.RaycastFilterType.Exclude
local lastShelterCheck = 0

local function checkShelter(eye: Vector3)
	local ignore: { Instance } = { folder }
	local character = player.Character
	if character then
		table.insert(ignore, character)
	end
	shelterParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(eye, Vector3.new(0, 90, 0), shelterParams)
	sheltered = hit ~= nil
end

local nextBolt = os.clock() + 20 + math.random() * 20

local function lightning()
	flash = 0.42
	task.delay(0.12, function()
		flash = 0.28
	end)
	task.delay(0.6 + math.random() * 2, function()
		local thunder = Instance.new("Sound")
		thunder.Name = "Thunder"
		thunder.SoundId = THUNDER_ID
		thunder.PlaybackSpeed = 0.28 + math.random() * 0.08
		thunder.Volume = 0.45 * intensity
		thunder.Parent = SoundService
		thunder:Play()
		task.delay(8, function()
			thunder:Destroy()
		end)
	end)
end

RunService.RenderStepped:Connect(function(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local now = os.clock()
	if now - lastShelterCheck > 0.4 then
		lastShelterCheck = now
		checkShelter(eye)
	end
	local target = if raining() then (if sheltered then 0.12 else 1) else 0
	local step = FADE * dt
	intensity = if intensity < target then math.min(target, intensity + step) else math.max(target, intensity - step)

	if intensity <= 0 then
		if folder.Parent then
			folder.Parent = nil
			for _, d in ipairs(drops) do
				d.beam.Enabled = false
			end
			splash.Rate = 0
			grade.Enabled = false
			wet(0)
		end
		return
	end
	if not folder.Parent then
		folder.Parent = camera
	end

	-- The streaks: as many as the setting allows, each falling, recycled at the foot.
	local want = STREAKS[level]
	while #drops < want do
		local d = newDrop()
		respawn(d, eye, false)
		table.insert(drops, d)
	end
	local seen = math.floor(want * intensity + 0.5)
	local fall = Vector3.new(WIND.X, -1, WIND.Z) * FALL * dt
	local along = Vector3.new(WIND.X, -1, WIND.Z).Unit * LENGTH
	local alpha = NumberSequence.new(1 - 0.5 * math.min(1, intensity * 1.2))
	for i, d in ipairs(drops) do
		if i > seen then
			d.beam.Enabled = false
		else
			d.at += fall
			local rel = d.at - eye
			if rel.Y < -DEPTH or Vector3.new(rel.X, 0, rel.Z).Magnitude > RADIUS * 1.15 then
				respawn(d, eye, rel.Y < -DEPTH)
			end
			d.top.Position = d.at
			d.bottom.Position = d.at + along
			d.beam.Transparency = alpha
			d.beam.Enabled = true
		end
	end

	-- Splashes on the ground below.
	if level >= 2 then
		local below = workspace:Raycast(eye, Vector3.new(0, -60, 0), shelterParams)
		local y = if below then below.Position.Y else eye.Y - 8
		splashHost.CFrame = CFrame.new(eye.X, y + 0.05, eye.Z)
		splash.Rate = 140 * intensity
	else
		splash.Rate = 0
	end

	-- The grade, and lightning now and then in a proper storm.
	if intensity > 0.6 and now > nextBolt then
		nextBolt = now + 18 + math.random() * 26
		lightning()
	end
	flash = math.max(0, flash - dt * 3)
	grade.Enabled = true
	grade.TintColor = Color3.new(1, 1, 1):Lerp(Color3.fromRGB(214, 224, 240), intensity)
	grade.Saturation = -0.12 * intensity
	grade.Brightness = -0.03 * intensity + flash
	grade.Contrast = 0.04 * intensity
	wet(intensity)
end)
