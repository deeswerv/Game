--!strict
-- Car alarms: put a round into a parked car and it goes off. The hazards flash amber front and
-- back and it whoops its two-tone alarm for a few seconds, then settles. Every client does it
-- from the shots it already sees (CombatFX.Gunfire: every tracer's start and every impact), so
-- nothing goes over the network.
--
-- The cars are the city kit's: "KitProp" models of a car (CityMeshes draws them from the kit,
-- or they are still part-built where it cannot), in Downtown and Hanami City alike. Their lamps
-- are whichever lamp pieces are showing on this screen. A car already going off just keeps
-- going; a handful can sound at once, no more.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CARS: { [string]: boolean } = {
	Sedan = true, Hatch = true, SUV = true, MuscleCar = true, Pickup = true,
	Kei = true, JSedan = true, Van = true, KeiTruck = true,
}
local LAMPS: { [string]: boolean } = { Headlight = true, Taillight = true, HeadLamp = true, TailLamp = true }

local DURATION = 7          -- seconds an alarm sounds
local CHIRP = 0.18          -- seconds between the two tones
local FLASH = 0.4           -- seconds the hazards are on, then off
local MARGIN = 0.6          -- studs round a car's box a hit still counts
local MAX_SOUNDING = 4
local AMBER = Color3.fromRGB(255, 168, 36)
local TONE = "rbxasset://sounds/electronicpingshort.wav"

type Box = { cf: CFrame, half: Vector3 }

local boxes: { [Model]: Box | false } = {}
local sounding: { [Model]: boolean } = {}
local count = 0

local CarAlarms = {}

--- A car's box in its own frame (KitFrame), round every piece of it, worked out the first
--- time it is needed (cars are parked: it never moves).
local function boxOf(model: Model): Box?
	local known = boxes[model]
	if known ~= nil then
		if known == false then
			return nil
		end
		return known :: Box
	end
	local frame = model:GetAttribute("KitFrame")
	local lo, hi = Vector3.new(math.huge, math.huge, math.huge), -Vector3.new(math.huge, math.huge, math.huge)
	if typeof(frame) == "CFrame" then
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				local h = d.Size / 2
				for _, c in ipairs({ Vector3.new(-1, -1, -1), Vector3.new(1, -1, -1), Vector3.new(-1, 1, -1), Vector3.new(1, 1, -1),
					Vector3.new(-1, -1, 1), Vector3.new(1, -1, 1), Vector3.new(-1, 1, 1), Vector3.new(1, 1, 1) }) do
					local p = frame:PointToObjectSpace(d.CFrame:PointToWorldSpace(h * c))
					lo, hi = lo:Min(p), hi:Max(p)
				end
			end
		end
	end
	if typeof(frame) ~= "CFrame" or hi.X < lo.X then
		boxes[model] = false
		return nil
	end
	local box: Box = { cf = frame * CFrame.new((lo + hi) / 2), half = (hi - lo) / 2 + Vector3.new(MARGIN, MARGIN, MARGIN) }
	boxes[model] = box
	return box
end

local function inside(box: Box, at: Vector3): boolean
	local rel = box.cf:PointToObjectSpace(at)
	return math.abs(rel.X) <= box.half.X and math.abs(rel.Y) <= box.half.Y and math.abs(rel.Z) <= box.half.Z
end

--- The lamps showing on this screen: the kit's where it has drawn the car, else the part-built.
local function lampsOf(model: Model): { BasePart }
	local lamps = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") and LAMPS[d.Name] and d.Transparency < 1 and (d.LocalTransparencyModifier or 0) < 1 then
			table.insert(lamps, d)
		end
	end
	return lamps
end

--- Set `model`'s alarm off (nothing if it is already going, or enough are).
function CarAlarms.Trip(model: Model)
	if sounding[model] or count >= MAX_SOUNDING then
		return
	end
	local lamps = lampsOf(model)
	local anchor: BasePart? = lamps[1] or model:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then
		return
	end
	sounding[model] = true
	count += 1
	local was: { [BasePart]: { Color3 | Enum.Material } } = {}
	for _, lamp in ipairs(lamps) do
		was[lamp] = { lamp.Color, lamp.Material }
	end
	local glow = Instance.new("PointLight")
	glow.Name = "AlarmGlow"
	glow.Color = AMBER
	glow.Range = 16
	glow.Brightness = 2.5
	glow.Shadows = false
	glow.Enabled = false
	glow.Parent = anchor
	local tone = Instance.new("Sound")
	tone.Name = "CarAlarm"
	tone.SoundId = TONE
	tone.Volume = 0.55
	tone.RollOffMinDistance = 12
	tone.RollOffMaxDistance = 150
	tone.Parent = anchor

	task.spawn(function()
		local started = os.clock()
		local k = 0
		while os.clock() - started < DURATION and model.Parent do
			local on = math.floor((os.clock() - started) / FLASH) % 2 == 0
			for lamp in pairs(was) do
				lamp.Color = if on then AMBER else (was[lamp][1] :: Color3)
				lamp.Material = if on then Enum.Material.Neon else (was[lamp][2] :: Enum.Material)
			end
			glow.Enabled = on
			tone.PlaybackSpeed = if k % 2 == 0 then 1 else 1.42
			pcall(function()
				tone.TimePosition = 0
				tone:Play()
			end)
			k += 1
			task.wait(CHIRP)
		end
		for lamp, old in pairs(was) do
			lamp.Color = old[1] :: Color3
			lamp.Material = old[2] :: Enum.Material
		end
		glow:Destroy()
		tone:Destroy()
		sounding[model] = nil
		count -= 1
	end)
end

-- The cars there are (kept as they come and go, so a shot looks at the cars only).
local cars: { [Model]: boolean } = {}
local function added(model: Instance)
	if model:IsA("Model") and CARS[tostring(model:GetAttribute("KitModel"))] then
		cars[model] = true
	end
end
CollectionService:GetInstanceAddedSignal("KitProp"):Connect(added)
CollectionService:GetInstanceRemovedSignal("KitProp"):Connect(function(model: Instance)
	cars[model :: Model] = nil
	boxes[model :: Model] = nil
end)
for _, model in ipairs(CollectionService:GetTagged("KitProp")) do
	added(model)
end

--- A shot at `at`: the car it hit, if it hit one, goes off.
function CarAlarms.Shot(at: Vector3)
	for model in pairs(cars) do
		if not sounding[model] then
			local box = boxOf(model)
			if box and (box.cf.Position - at).Magnitude < 16 and inside(box, at) then
				CarAlarms.Trip(model)
			end
		end
	end
end

task.spawn(function()
	local ok, CombatFX = pcall(function()
		return require(ReplicatedStorage:WaitForChild("CombatFX")) :: any
	end)
	if ok and CombatFX and CombatFX.Gunfire then
		CombatFX.Gunfire.Event:Connect(CarAlarms.Shot)
	end
end)
