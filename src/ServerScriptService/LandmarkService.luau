--!strict
-- One thing per island you can see from anywhere on it.
--
-- Measured first: the tallest BUILT object in the entire world was a 40-stud stair tower.
-- Everything above it -- every single part over 55 studs -- was decorative cloud. From most
-- of the world you could not see any other part of it: 22 of 54 zone-to-zone sightlines were
-- clear, and the Reach could see nothing at all, in either direction. There was no way to
-- know where you were without opening a menu.
--
-- Heights are chosen from that measurement rather than by eye. The things that block a
-- distant view here -- tree canopies, bridge rails, ridge lines -- sit between 1.5 and 8
-- degrees above the horizon from a standing eye. A crown at ground + 110 reads at 12-15
-- degrees from 500 studs away, comfortably over all of it, and still below the cloud deck
-- that starts at 117.
--
-- Each island gets a DIFFERENT silhouette, because three identical towers would tell you a
-- landmark exists without telling you which one you are looking at:
--
--   Flats     a skeletal lattice mast   thin, tapering, see-through
--   Reach     a stepped stone spire      solid, triangular
--   Crossing  a round lantern tower      cylindrical, flared at the top
--
-- Crown colours match the travel gate that brings you there, so the world uses one colour
-- language: step through the green arch and the green light on the horizon is where you are.

local ServerScriptService = game:GetService("ServerScriptService")
local WorldBake = require(ServerScriptService.WorldBake)

local LandmarkService = {}

LandmarkService.FOLDER = "Landmarks"
LandmarkService.HEIGHT = 110      -- crown height above the ground it stands on

local STEEL = Color3.fromRGB(86, 90, 96)
local STEEL_DARK = Color3.fromRGB(62, 65, 70)
local SANDSTONE = Color3.fromRGB(196, 174, 136)
local SANDSTONE_DARK = Color3.fromRGB(162, 140, 106)
local PALE = Color3.fromRGB(214, 212, 206)
local PALE_DARK = Color3.fromRGB(172, 170, 166)

-- Sites were searched for, not picked: every 20 studs across each island, keeping only
-- ground with a clear 110-stud column and at least 60 studs from every NPC post, boss post
-- and travel pad, then scored by how many of that island's key viewpoints can actually see
-- the crown. Each of these is walkable-to from its own island, so it is a place in the
-- world rather than scenery on an unreachable ridge.
LandmarkService.Sites = {
	{ id = "Flats",    kind = "mast",    position = Vector3.new(-560, 1.3, 160),
	  crown = Color3.fromRGB(104, 204, 110), seen = "4 of 5 viewpoints" },
	{ id = "Crossing", kind = "lantern", position = Vector3.new(-200, 27.7, 60),
	  crown = Color3.fromRGB(255, 236, 198), seen = "5 of 5 viewpoints" },
	{ id = "Reach",    kind = "spire",   position = Vector3.new(290, 1.9, 220),
	  crown = Color3.fromRGB(236, 178, 72), seen = "5 of 5 viewpoints" },
}

local function folder(): Folder
	local existing = workspace:FindFirstChild(LandmarkService.FOLDER)
	if existing then
		return existing :: Folder
	end
	local f = Instance.new("Folder")
	f.Name = LandmarkService.FOLDER
	f.Parent = workspace
	return f
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.Slate
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

--- The lit crown every landmark ends in. Never solid: a landmark should not stop a bullet
--- or catch a body, it should be looked at.
local function crown(model: Model, centre: Vector3, colour: Color3, size: Vector3)
	local lamp = part(model, "Crown", size, CFrame.new(centre) * CFrame.Angles(0, math.rad(45), 0), colour, Enum.Material.Neon)
	lamp.CanCollide = false
	lamp.CanQuery = false
	local light = Instance.new("PointLight")
	light.Color = colour
	light.Brightness = 4
	light.Range = 60
	light.Parent = lamp
	return lamp
end

local function plinth(model: Model, base: Vector3, radius: number, colour: Color3)
	for i = 0, 1 do
		part(model, "Plinth", Vector3.new(radius * 2, 1.6, radius * 2),
			CFrame.new(base + Vector3.new(0, 0.8, 0)) * CFrame.Angles(0, math.rad(i * 45), 0), colour)
	end
end

--- Flats: a lattice mast. Four legs leaning in to a point, braced by square rings -- it
--- reads as a skeleton against the sky, which no other landmark here does.
local function buildMast(model: Model, base: Vector3, colour: Color3)
	local H = LandmarkService.HEIGHT
	local baseR, topR = 9, 2.2
	plinth(model, base, 11, STEEL_DARK)

	local function corner(angle: number, r: number, y: number): Vector3
		return base + Vector3.new(math.cos(angle) * r, y, math.sin(angle) * r)
	end

	for i = 0, 3 do
		local a = math.rad(45 + i * 90)
		local foot = corner(a, baseR, 1.6)
		local head = corner(a, topR, H - 6)
		local mid = (foot + head) / 2
		part(model, "Leg", Vector3.new(1.2, 1.2, (head - foot).Magnitude), CFrame.lookAt(mid, head), STEEL, Enum.Material.Metal)
	end

	for level = 1, 6 do
		local t = level / 7
		local y = 1.6 + (H - 7.6) * t
		local r = baseR + (topR - baseR) * t
		for i = 0, 3 do
			local a1 = math.rad(45 + i * 90)
			local a2 = math.rad(45 + (i + 1) * 90)
			local c1, c2 = corner(a1, r, y), corner(a2, r, y)
			local mid = (c1 + c2) / 2
			part(model, "Brace", Vector3.new(0.7, 0.7, (c2 - c1).Magnitude), CFrame.lookAt(mid, c2), STEEL_DARK, Enum.Material.Metal)
		end
	end

	crown(model, base + Vector3.new(0, H, 0), colour, Vector3.new(5.5, 7, 5.5))
end

--- Reach: a stepped spire. Solid and triangular, the opposite silhouette to the mast.
local function buildSpire(model: Model, base: Vector3, colour: Color3)
	local H = LandmarkService.HEIGHT
	local levels = 14
	plinth(model, base, 14, SANDSTONE_DARK)
	local segment = (H - 8) / levels
	for i = 0, levels - 1 do
		local t = i / levels
		local w = 22 - 19 * t
		part(model, "Course", Vector3.new(w, segment, w),
			CFrame.new(base + Vector3.new(0, 1.6 + segment * (i + 0.5), 0)) * CFrame.Angles(0, math.rad(i * 6), 0),
			i % 2 == 0 and SANDSTONE or SANDSTONE_DARK)
	end
	crown(model, base + Vector3.new(0, H - 2, 0), colour, Vector3.new(4.4, 9, 4.4))
end

--- Crossing: a round lantern tower, flared at the top. The only curved thing on the skyline.
local function buildLantern(model: Model, base: Vector3, colour: Color3)
	local H = LandmarkService.HEIGHT
	plinth(model, base, 12, PALE_DARK)

	local function drum(name: string, diameter: number, height: number, y: number, colourIn: Color3, material: Enum.Material?)
		local p = part(model, name, Vector3.new(height, diameter, diameter),
			CFrame.new(base + Vector3.new(0, y + height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), colourIn, material)
		p.Shape = Enum.PartType.Cylinder
		return p
	end

	drum("Shaft", 15, H - 26, 1.6, PALE, Enum.Material.Sandstone)
	for i = 1, 3 do
		drum("Band", 16.4, 1.6, 1.6 + (H - 26) * (i / 4), PALE_DARK, Enum.Material.Sandstone)
	end
	drum("Gallery", 21, 3.2, H - 24.4, PALE_DARK, Enum.Material.Sandstone)
	local housing = drum("Housing", 17, 12, H - 21.2, colour, Enum.Material.Neon)
	housing.CanCollide = false
	housing.CanQuery = false
	drum("Cap", 19, 3, H - 9.2, PALE_DARK, Enum.Material.Sandstone)

	local light = Instance.new("PointLight")
	light.Color = colour
	light.Brightness = 4
	light.Range = 60
	light.Parent = housing

	crown(model, base + Vector3.new(0, H - 3, 0), colour, Vector3.new(3.4, 5, 3.4))
end

function LandmarkService.Build()
	if WorldBake.Skip(LandmarkService.FOLDER, "Landmarks") then
		return
	end
	local f = folder()
	f:ClearAllChildren()

	local parts = 0
	for _, site in ipairs(LandmarkService.Sites) do
		local model = Instance.new("Model")
		model.Name = "Landmark_" .. site.id
		model.Parent = f
		if site.kind == "mast" then
			buildMast(model, site.position, site.crown)
		elseif site.kind == "spire" then
			buildSpire(model, site.position, site.crown)
		else
			buildLantern(model, site.position, site.crown)
		end
		model:SetAttribute("Landmark", site.id)
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") then
				parts += 1
			end
		end
	end
	print(("[Landmarks] %d towers, %d parts, crowns at ground + %d")
		:format(#LandmarkService.Sites, parts, LandmarkService.HEIGHT))
end

LandmarkService.Build()

return LandmarkService
