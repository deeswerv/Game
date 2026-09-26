--!strict
-- Each duel map lit its own way, whatever time it is in the world (and Downtown graded and
-- clouded its own way, at whatever time it is).
--
-- The world's sky is the server's (AmbienceService runs one day/night cycle for everyone).
-- A duel map wants its own: night for the neon court, a low sun across the quay, dusk over
-- the temple. So while the camera is inside a map, this client holds Lighting, the
-- atmosphere, the grade and the bloom at that map's values -- every frame, because the
-- server keeps replicating its own -- and fades back to the world on the way out.
--
-- The looks come from the maps themselves: ArenaService writes each map's zone and look
-- onto its folder as attributes (Look_<Group>_<Property>). The world values to return to
-- are read from the World_ attributes AmbienceService publishes, because a property this
-- script has overwritten locally only comes back from the server when the server changes it.

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")

local FADE = 0.8              -- seconds to cross between the world and a map
local CHECK_EVERY = 0.4

type Look = { [string]: { [string]: any } }
type Zone = { name: string, centre: Vector3, half: Vector3, look: Look }

local GROUPS: { [string]: () -> Instance? } = {
	Lighting = function()
		return Lighting
	end,
	Atmosphere = function()
		return Lighting:FindFirstChildOfClass("Atmosphere")
	end,
	Grade = function()
		return Lighting:FindFirstChild("Grade")
	end,
	Bloom = function()
		return Lighting:FindFirstChildOfClass("BloomEffect")
	end,
	SunRays = function()
		return Lighting:FindFirstChildOfClass("SunRaysEffect")
	end,
	Clouds = function()
		local terrain = workspace:FindFirstChildOfClass("Terrain")
		return terrain and terrain:FindFirstChildOfClass("Clouds")
	end,
}

-- Stepping these through the values in between would sweep the sun across the sky.
local SNAP = { ClockTime = true, GeographicLatitude = true }

-- The gun range is not an ArenaService map, but it is another sky venue and reads best at
-- night the way it always has.
local RANGE: Zone = {
	name = "Range",
	centre = Vector3.new(0, 2010, -200),
	half = Vector3.new(60, 50, 250),
	look = {
		Lighting = {
			ClockTime = 21,
			Brightness = 1.5,
			Ambient = Color3.fromRGB(74, 72, 100),
			OutdoorAmbient = Color3.fromRGB(100, 98, 136),
		},
		Grade = {
			Brightness = -0.04,
			Contrast = 0.2,
			Saturation = 0.28,
			TintColor = Color3.fromRGB(222, 216, 255),
		},
		Clouds = { Cover = 0 },
	},
}

local function readZone(folder: Instance): Zone?
	local centre, half = folder:GetAttribute("ZoneCentre"), folder:GetAttribute("ZoneHalf")
	if typeof(centre) ~= "Vector3" or typeof(half) ~= "Vector3" then
		return nil
	end
	local look: Look = {}
	for name, value in pairs(folder:GetAttributes()) do
		local group, property = string.match(name, "^Look_(%a+)_(.+)$")
		if group and property and GROUPS[group] then
			look[group] = look[group] or {}
			look[group][property] = value
		end
	end
	return { name = folder.Name, centre = centre, half = half, look = look }
end

local function zones(): { Zone }
	local list = { RANGE }
	-- Downtown publishes a look of its own (a colour grade and big clouds, never the clock).
	local downtown = workspace:FindFirstChild("Downtown")
	local district = downtown and readZone(downtown)
	if district then
		table.insert(list, district)
	end
	local arenas = workspace:FindFirstChild("Arenas")
	if arenas then
		for _, folder in ipairs(arenas:GetChildren()) do
			local zone = readZone(folder)
			if zone then
				table.insert(list, zone)
			end
		end
	end
	return list
end

local function zoneAt(p: Vector3): Zone?
	for _, zone in ipairs(zones()) do
		local d = p - zone.centre
		if math.abs(d.X) <= zone.half.X and math.abs(d.Y) <= zone.half.Y and math.abs(d.Z) <= zone.half.Z then
			return zone
		end
	end
	return nil
end

-- --------------------------------------------------------------- blending --

-- What each property was before this script first touched it. For properties the server
-- never moves, this IS the world value; for the ones it does, World_ attributes win.
local snapshot: { [Instance]: { [string]: any } } = {}

local function worldValue(inst: Instance, property: string): any
	local published = inst:GetAttribute("World_" .. property)
	if published ~= nil then
		return published
	end
	local saved = snapshot[inst]
	return saved and saved[property]
end

local function blend(a: any, b: any, t: number, snap: boolean): any
	if a == nil then
		return b
	end
	if snap then
		return if t >= 0.5 then b else a
	end
	if type(a) == "number" and type(b) == "number" then
		return a + (b - a) * t
	end
	if typeof(a) == "Color3" and typeof(b) == "Color3" then
		return (a :: Color3):Lerp(b :: Color3, t)
	end
	return if t >= 0.5 then b else a
end

local function apply(look: Look, t: number)
	for group, values in pairs(look) do
		local inst = GROUPS[group]()
		if inst then
			local saved = snapshot[inst]
			if not saved then
				saved = {}
				snapshot[inst] = saved
			end
			for property, target in pairs(values) do
				if saved[property] == nil then
					local ok, current = pcall(function()
						return (inst :: any)[property]
					end)
					saved[property] = ok and current or target
				end
				local value = blend(worldValue(inst, property), target, t, SNAP[property] == true)
				pcall(function()
					(inst :: any)[property] = value
				end)
			end
		end
	end
end

local current: Zone? = nil      -- the map being shown (kept while fading out of it)
local inside = false
local alpha = 0
local accumulator = CHECK_EVERY

RunService:BindToRenderStep("ArenaMood", Enum.RenderPriority.First.Value, function(dt)
	accumulator += dt
	if accumulator >= CHECK_EVERY then
		accumulator = 0
		local camera = workspace.CurrentCamera
		local zone = camera and zoneAt(camera.CFrame.Position)
		if zone then
			if current and current.name ~= zone.name then
				-- Straight from one map to another: hand everything back, start the new one clean.
				apply(current.look, 0)
				alpha = 0
			end
			current = zone
			inside = true
		else
			inside = false
		end
	end

	if not current then
		return
	end
	local goal = inside and 1 or 0
	if alpha ~= goal then
		local step = dt / FADE
		alpha = if goal > alpha then math.min(goal, alpha + step) else math.max(goal, alpha - step)
	end
	apply(current.look, alpha)
	if alpha <= 0 and not inside then
		current = nil      -- the world is back; stop touching it
	end
end)
