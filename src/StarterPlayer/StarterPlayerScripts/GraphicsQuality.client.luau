--!strict
-- The GRAPHICS setting (Settings panel; the player's "GraphicsQuality" attribute, 1-3), put
-- into effect on this client only:
--
--   PERFORMANCE (1)  no depth of field, sun rays or bloom; the cities' far skylines and their
--                    small trim (cornice brackets, wheel spokes, window units, chimneys...)
--                    are not drawn at all
--   BALANCED (2)     no depth of field or sun rays; everything drawn
--   ULTRA (3)        everything (the default)
--
-- Hiding is LocalTransparencyModifier: nothing is removed or changed for anyone else, a part
-- that streams in later is caught as it arrives, and raising the setting brings it all back.

local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local player = Players.LocalPlayer

-- Small trim, by part name: worth drawing up close, not worth the draw calls on a weak device.
local TRIM: { [string]: boolean } = {
	Bracket = true, Spoke = true, WindowUnit = true, UnitGrille = true, WindowBox = true, WindowBlooms = true,
	Handle = true, BeltLine = true, LampSurround = true, Exhaust = true, Aerial = true, AerialBar = true,
	Chimney = true, ChimneyCap = true, WheelWell = true, Mullion = true, CrownLip = true, BalconyBlooms = true,
	Shutter = true, Keystone = true, Lintel = true, Sill = true, BrickCourse = true, LeafBud = true,
}
local CITIES = { "Downtown", "Hanami" }

local level = 3
local anyHidden = false     -- whether anything was ever hidden (so ULTRA from the start costs nothing)

-- Trim is small by definition: a big part that happens to share a name (Hanami's steelworks
-- chimney) is a landmark, and stays.
local TRIM_SIZE = 14

local function isTrim(part: BasePart): boolean
	return TRIM[part.Name] == true and part.Size.Magnitude < TRIM_SIZE
end

local function hidden(part: BasePart): boolean
	if level > 1 then
		return false
	end
	return isTrim(part) or part:FindFirstAncestor("Skyline") ~= nil
end

local function apply(d: Instance)
	if level > 1 and not anyHidden then
		return
	end
	-- Anything that could ever be hidden is put right either way (a part named like trim but
	-- too big to be trim is shown).
	if d:IsA("BasePart") and (TRIM[d.Name] or d:FindFirstAncestor("Skyline")) then
		d.LocalTransparencyModifier = if hidden(d) then 1 else 0
	end
end

local watching: { [Instance]: RBXScriptConnection } = {}

local function watch(city: Instance)
	if watching[city] then
		return
	end
	watching[city] = city.DescendantAdded:Connect(apply)
	city.Destroying:Connect(function()
		local c = watching[city]
		if c then
			c:Disconnect()
		end
		watching[city] = nil
	end)
end

local function effects()
	local dof = Lighting:FindFirstChild("DepthOfField")
	if dof and dof:IsA("DepthOfFieldEffect") then
		dof.Enabled = level >= 3
	end
	local rays = Lighting:FindFirstChildOfClass("SunRaysEffect")
	if rays then
		rays.Enabled = level >= 3
	end
	local bloom = Lighting:FindFirstChild("Bloom")
	if bloom and bloom:IsA("BloomEffect") then
		bloom.Enabled = level >= 2
	end
end

local function refresh()
	local raw = tonumber(player:GetAttribute("GraphicsQuality"))
	level = if raw then math.clamp(math.floor(raw + 0.5), 1, 3) else 3
	effects()
	local sweep = level == 1 or anyHidden
	for _, name in ipairs(CITIES) do
		local city = workspace:FindFirstChild(name)
		if city then
			watch(city)
			if sweep then
				for _, d in ipairs(city:GetDescendants()) do
					apply(d)
				end
			end
		end
	end
	-- Once everything is shown again there is nothing left to undo.
	anyHidden = level == 1
end

player:GetAttributeChangedSignal("GraphicsQuality"):Connect(refresh)
workspace.ChildAdded:Connect(function(child: Instance)
	if table.find(CITIES, child.Name) then
		watch(child)
		if level == 1 then
			for _, d in ipairs(child:GetDescendants()) do
				apply(d)
			end
		end
	end
end)
refresh()
