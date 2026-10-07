--!strict
-- The city at night: as the day/night cycle (AmbienceService) runs down into dusk, the street
-- lamps come on, the lights under them brighten, and windows light up across the blocks --
-- a few at a time, not all at once, some warm, the odd one blue with a television -- and after
-- midnight most of them go dark again, one by one, until morning puts everything back.
--
-- By day nothing here is touched: every part is exactly as the builders made it (Downtown is
-- deliberately neon-free in daylight). Only at night do the lamp globes and the lit windows
-- glow. Client-side and cosmetic -- the server never hears about any of it.
--
-- Which parts: by name, wherever they are, so Downtown (built at runtime) and anything added
-- later are picked up as they arrive. Each one draws its own moment to switch from where it
-- stands, so the same window comes on at the same time for everybody.

local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AmbienceConfig = require(ReplicatedStorage:WaitForChild("AmbienceConfig"))

-- The globes of lamps: they glow when on.
local LAMPS: { [string]: boolean } = {
	LanternGlass = true, SoffitLamp = true, TunnelLamp = true, WalkLamp = true, LightPanel = true,
	CeilingLight = true, StashLamp = true, Downlight = true, LampHead = true,
	-- Hanami City's paper lanterns, and the lit signs and screens of a Japanese street at
	-- night: these glow in their own colours (OWN_COLOUR), not lamp-white.
	Chochin = true, Screen = true, ScreenGlow = true, TallSign = true, SignBand = true, Tenant = true,
	Billboard = true, NameBand = true, FurnaceMouth = true,
}
local OWN_COLOUR: { [string]: boolean } = {
	Chochin = true, Screen = true, ScreenGlow = true, TallSign = true, SignBand = true, Tenant = true,
	Billboard = true, NameBand = true, FurnaceMouth = true,
}
-- Facade windows (the opaque ones on the floors above the street; shop glass with a lit room
-- behind it is left alone).
local WINDOWS: { [string]: boolean } = { Windows = true, ArchGlass = true, BayGlass = true, TierGlass = true }

local LAMP_GLOW = Color3.fromRGB(255, 214, 150)
local WINDOW_WARM = {
	Color3.fromRGB(246, 204, 138), Color3.fromRGB(255, 188, 112), Color3.fromRGB(236, 222, 184),
	Color3.fromRGB(250, 196, 128),
}
local WINDOW_TV = Color3.fromRGB(150, 186, 255)
-- How many of the windows ever light up, and how see-through a lit one is (a soft glow).
local LIT_SHARE = 0.42
local WINDOW_GLOW = 0.3
-- Lights under the lamps are this much brighter at full night.
local NIGHT_BOOST = 0.6

type Entry = {
	part: BasePart, lamp: boolean, a: number, b: number, c: number,
	material: Enum.Material, colour: Color3, transparency: number, lit: boolean,
}
local entries: { [BasePart]: Entry } = {}
local lights: { [Light]: number } = {}

--- 0..1 from where a part stands: its own dice, the same on every machine.
local function seed(p: Vector3, k: number): number
	local v = math.sin(p.X * 12.9898 + p.Y * 78.233 + p.Z * 37.719 + k * 91.7) * 43758.5453
	return v - math.floor(v)
end

local function track(inst: Instance)
	if inst:IsA("BasePart") then
		local lamp = LAMPS[inst.Name] == true
		if (lamp or WINDOWS[inst.Name]) and not entries[inst] then
			local at = inst.CFrame.Position
			local a = seed(at, 1)
			-- Most windows stay dark all night; only the lit share is tracked at all.
			if lamp or a < LIT_SHARE then
				entries[inst] = {
					part = inst, lamp = lamp, a = a, b = seed(at, 2), c = seed(at, 3),
					material = inst.Material, colour = inst.Color, transparency = inst.Transparency, lit = false,
				}
			end
		end
	elseif inst:IsA("Light") and not lights[inst] then
		-- Only the lights of lamps and the like -- the ones the builders placed with the lamps.
		local parent = inst.Parent
		if parent and (LAMPS[parent.Name] or parent.Name == "Base" or parent.Name == "Lamp" or inst:FindFirstAncestor("Downtown")
			or inst:FindFirstAncestor("Hanami")) then
			lights[inst] = (inst :: any).Brightness
		end
	end
end

--- Whether a tracked part should be lit at `clock`, with the day at `daylight` (0 night, 1 day).
local function wanted(e: Entry, clock: number, daylight: number): boolean
	if e.lamp then
		-- Lamps come on through dusk, each at its own moment, and go off the same way at dawn.
		return daylight < 0.62 - 0.3 * e.b
	end
	-- Windows: lit as the evening comes on, at staggered moments...
	if daylight >= 0.72 - 0.55 * e.b then
		return false
	end
	-- ...and after midnight most go dark, one by one, as people go to bed.
	local bedtime = 0.4 + e.c * 4.2
	if clock < AmbienceConfig.DAWN and clock >= bedtime and e.c < 0.75 then
		return false
	end
	return true
end

local function apply(e: Entry, on: boolean)
	e.lit = on
	local p = e.part
	if not on then
		p.Material = e.material
		p.Color = e.colour
		p.Transparency = e.transparency
	elseif e.lamp then
		p.Material = Enum.Material.Neon
		-- A coloured sign or lantern keeps its colour, a touch brighter; a lamp glows warm white.
		p.Color = if OWN_COLOUR[p.Name] then e.colour:Lerp(Color3.new(1, 1, 1), 0.12) else LAMP_GLOW
	else
		p.Material = Enum.Material.Neon
		p.Color = if e.a < LIT_SHARE * 0.08 then WINDOW_TV else WINDOW_WARM[math.floor(e.b * #WINDOW_WARM) + 1]
		p.Transparency = math.max(e.transparency, WINDOW_GLOW)
	end
end

local lastBoost = -1
local function step()
	local clock = Lighting.ClockTime
	local daylight = AmbienceConfig.Daylight(clock)
	for part, e in pairs(entries) do
		if part.Parent == nil then
			entries[part] = nil
		else
			local on = wanted(e, clock, daylight)
			if on ~= e.lit then
				apply(e, on)
			end
		end
	end
	local boost = 1 + NIGHT_BOOST * (1 - daylight)
	if math.abs(boost - lastBoost) > 0.01 then
		lastBoost = boost
		for light, base in pairs(lights) do
			if light.Parent == nil then
				lights[light] = nil
			else
				(light :: any).Brightness = base * boost
			end
		end
	end
end

for _, d in ipairs(workspace:GetDescendants()) do
	track(d)
end
workspace.DescendantAdded:Connect(track)

task.spawn(function()
	while true do
		step()
		task.wait(1)
	end
end)
