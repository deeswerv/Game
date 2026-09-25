--!strict
-- The duel arena: a bounded, fair place for a 1v1 to actually resolve.
--
-- Built at y=3000, well clear of the world (which tops out at 477) and of the measuring lane
-- at 2000, so nothing here can be reached, shot into, or fallen out of by accident.
--
-- Laid out with 180-DEGREE ROTATIONAL symmetry, not mirror symmetry. That distinction is the
-- whole point of a duel map: rotate the arena half a turn and it is identical, so each player
-- sees exactly the same thing from their own spawn. A mirrored map looks symmetrical on
-- paper but hands one player the left-hand angle on every piece of cover.
--
-- Bake-aware like the rest of the world builds: once baked, this is ordinary geometry you can
-- drag around in Studio and the service leaves it alone.

local ServerScriptService = game:GetService("ServerScriptService")

local WorldBake = require(ServerScriptService.WorldBake)

local ArenaService = {}

ArenaService.CENTRE = Vector3.new(0, 3000, 0)
ArenaService.HALF_LENGTH = 60       -- along Z, spawn to spawn
ArenaService.HALF_WIDTH = 42        -- along X
ArenaService.WALL_HEIGHT = 34       -- double jump clears about 14, so this is not climbable

-- Where each duellist starts. Rotationally opposite, facing one another.
ArenaService.SPAWNS = {
	Vector3.new(0, 3003, -50),
	Vector3.new(0, 3003, 50),
}

-- The look: a night court on a rooftop. Dark asphalt, dark concrete, and neon -- magenta on
-- one side, cyan on the other -- with a lit city skyline standing beyond the walls, the way
-- the reference game's duel maps read. Colour marks the two halves; it is never tied to who
-- is winning, so it can never disagree with the scoreboard.
local FLOOR = Color3.fromRGB(34, 36, 44)
local FLOOR_ALT = Color3.fromRGB(26, 28, 34)
local WALL = Color3.fromRGB(28, 30, 38)
local COVER = Color3.fromRGB(122, 36, 52)        -- painted metal, side A
local COVER_DARK = Color3.fromRGB(26, 92, 110)   -- painted metal, side B
local LINE = Color3.fromRGB(235, 238, 255)
local SIDE_A = Color3.fromRGB(255, 60, 200)      -- magenta
local SIDE_B = Color3.fromRGB(40, 220, 255)      -- cyan
local WINDOW = {
	Color3.fromRGB(255, 214, 140), Color3.fromRGB(255, 214, 140), Color3.fromRGB(150, 220, 255),
	Color3.fromRGB(255, 120, 210), Color3.fromRGB(255, 236, 190),
}

local function folder(): Folder
	local f = workspace:FindFirstChild("Arena")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Arena"
		f.Parent = workspace
	end
	return f :: Folder
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame,
	colour: Color3, material: Enum.Material?, collide: boolean?): BasePart
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

--- Dressing: seen, never touched. No collision, no raycasts, no shadows -- a neon strip must
--- never stop a bullet or a camera, and the skyline must never darken the court.
local function decor(parent: Instance, name: string, size: Vector3, cf: CFrame,
	colour: Color3, material: Enum.Material?): BasePart
	local p = part(parent, name, size, cf, colour, material, false)
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	return p
end

--- Glowing text on an invisible board facing `facing`. SurfaceGui brightness above 1 is what
--- lets the bloom catch it, so it reads as a lit sign rather than a sticker.
local function sign(parent: Instance, text: string, centre: Vector3, facing: Vector3,
	width: number, height: number, colour: Color3, font: Enum.Font?)
	local board = decor(parent, "Sign_" .. text, Vector3.new(width, height, 0.1),
		CFrame.lookAt(centre, centre + facing), colour)
	board.Transparency = 1

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 14
	gui.LightInfluence = 0
	gui.Brightness = 2.6
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.Font = font or Enum.Font.FredokaOne
	label.TextColor3 = colour:Lerp(Color3.new(1, 1, 1), 0.35)
	label.Parent = gui

	local glow = Instance.new("UIStroke")
	glow.Color = colour
	glow.Thickness = 6
	glow.Transparency = 0.25
	glow.Parent = label
	return board
end

--- Place a piece and its rotational twin in one call.
---
--- Taking the rotation rather than copying coordinates by hand is what guarantees the map
--- stays fair: there is no way to edit one side and forget the other. Side A's piece takes
--- the magenta paint and B's the cyan; the neon edge along each top follows its side.
local function pair(parent: Instance, name: string, size: Vector3, offset: Vector3,
	colour: Color3, material: Enum.Material?)
	local centre = ArenaService.CENTRE
	for index, at in ipairs({ offset, Vector3.new(-offset.X, offset.Y, -offset.Z) }) do
		local sideColour = index == 1 and SIDE_A or SIDE_B
		local paint = index == 1 and COVER or COVER_DARK
		local body = part(parent, name .. (index == 1 and "_A" or "_B"), size, CFrame.new(centre + at),
			material == Enum.Material.Slate and WALL or paint, material or Enum.Material.Metal)
		-- Neon along the top edges, so the silhouette of cover reads instantly mid-fight.
		local at3 = body.CFrame.Position
		local top = at3.Y + size.Y / 2
		for _, dx in ipairs({ -1, 1 }) do
			decor(parent, "Edge", Vector3.new(0.25, 0.25, size.Z + 0.1),
				CFrame.new(at3.X + dx * (size.X / 2), top, at3.Z), sideColour, Enum.Material.Neon)
		end
		for _, dz in ipairs({ -1, 1 }) do
			decor(parent, "Edge", Vector3.new(size.X + 0.1, 0.25, 0.25),
				CFrame.new(at3.X, top, at3.Z + dz * (size.Z / 2)), sideColour, Enum.Material.Neon)
		end
	end
end

--- The skyline: dark towers with lit windows standing beyond the walls, some with a neon
--- sign on the roof. Seeded, so every server builds the same city.
local function skyline(parent: Instance)
	local centre = ArenaService.CENTRE
	local rng = Random.new(3000)
	local names = { "ZEE", "24/7", "MOTEL", "ARCADE", "GG", "HOTEL", "PLAY", "1V1", "BAR", "NEON" }
	local count = 0

	local function tower(x: number, z: number)
		local w = rng:NextNumber(14, 26)
		local d = rng:NextNumber(14, 24)
		local h = rng:NextNumber(70, 150)
		local base = Vector3.new(centre.X + x, centre.Y - 60 + h / 2, centre.Z + z)
		local look = Vector3.new(centre.X, base.Y, centre.Z)
		local cf = CFrame.lookAt(base, look)
		local body = decor(parent, "Tower", Vector3.new(w, h, d), cf,
			Color3.fromRGB(18 + rng:NextInteger(0, 8), 20 + rng:NextInteger(0, 8), 30 + rng:NextInteger(0, 10)))

		-- Rows of lit windows on the face that looks at the court.
		local rows = math.floor(h / 9)
		for r = 1, rows do
			if rng:NextNumber() < 0.7 then
				local y = -h / 2 + 6 + r * 8
				if y < h / 2 - 3 then
					local lit = decor(parent, "Windows", Vector3.new(w * rng:NextNumber(0.4, 0.85), 1.2, 0.2),
						body.CFrame * CFrame.new(rng:NextNumber(-w * 0.1, w * 0.1), y, -d / 2 - 0.12),
						WINDOW[rng:NextInteger(1, #WINDOW)], Enum.Material.Neon)
					lit.Transparency = rng:NextNumber(0, 0.35)
				end
			end
		end

		count += 1
		if count % 3 == 0 then
			local roof = body.CFrame * CFrame.new(0, h / 2 + 5, -d / 2 + 1)
			sign(parent, names[(count // 3 - 1) % #names + 1], roof.Position, roof.LookVector,
				w * 0.9, 8, rng:NextNumber() < 0.5 and SIDE_A or SIDE_B)
		end
	end

	for _, side in ipairs({ -1, 1 }) do
		for z = -150, 150, 30 do
			tower(side * rng:NextNumber(82, 120), z + rng:NextNumber(-6, 6))
		end
		for x = -90, 90, 30 do
			tower(x + rng:NextNumber(-6, 6), side * rng:NextNumber(110, 140))
		end
	end
end

function ArenaService.Build()
	if WorldBake.Skip("Arena", "Arena") then
		return
	end

	local f = folder()
	f:ClearAllChildren()

	local centre = ArenaService.CENTRE
	local L, W, H = ArenaService.HALF_LENGTH, ArenaService.HALF_WIDTH, ArenaService.WALL_HEIGHT

	-- ------------------------------------------------------------- shell --

	local floor = part(f, "Floor", Vector3.new(W * 2, 2, L * 2), CFrame.new(centre - Vector3.new(0, 1, 0)), FLOOR,
		Enum.Material.Asphalt)

	-- A darker band across the middle, so both players can see where half way is. Reading the
	-- centre line is most of how a duellist judges an engagement.
	part(f, "Midfield", Vector3.new(W * 2, 2.1, 16), CFrame.new(centre - Vector3.new(0, 0.95, 0)), FLOOR_ALT,
		Enum.Material.Asphalt)
	decor(f, "Centreline", Vector3.new(W * 2, 2.2, 0.5), CFrame.new(centre - Vector3.new(0, 0.9, 0)), LINE,
		Enum.Material.Neon)

	-- Court lines: a boundary a few studs inside the walls, painted white.
	for _, sx in ipairs({ -1, 1 }) do
		decor(f, "CourtLine", Vector3.new(0.4, 0.05, L * 2 - 6), CFrame.new(centre + Vector3.new(sx * (W - 3), 0.03, 0)),
			LINE).Transparency = 0.35
	end
	for _, sz in ipairs({ -1, 1 }) do
		decor(f, "CourtLine", Vector3.new(W * 2 - 6, 0.05, 0.4), CFrame.new(centre + Vector3.new(0, 0.03, sz * (L - 3))),
			LINE).Transparency = 0.35
	end

	-- A big faded logo painted on each half of the court, each turned to face its own spawn.
	local logo = Instance.new("SurfaceGui")
	logo.Face = Enum.NormalId.Top
	logo.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	logo.PixelsPerStud = 6
	logo.LightInfluence = 1
	logo.Parent = floor
	for i, y in ipairs({ 0.24, 0.76 }) do
		local logoText = Instance.new("TextLabel")
		logoText.BackgroundTransparency = 1
		logoText.AnchorPoint = Vector2.new(0.5, 0.5)
		logoText.Position = UDim2.fromScale(0.5, y)
		logoText.Size = UDim2.fromScale(0.8, 0.22)
		logoText.Rotation = i == 1 and 180 or 0
		logoText.Text = "ZEE"
		logoText.TextScaled = true
		logoText.Font = Enum.Font.FredokaOne
		logoText.TextColor3 = Color3.fromRGB(255, 255, 255)
		logoText.TextTransparency = 0.86
		logoText.Parent = logo
	end

	for _, side in ipairs({ -1, 1 }) do
		part(f, "WallX", Vector3.new(2, H, L * 2 + 4),
			CFrame.new(centre + Vector3.new(side * (W + 1), H / 2 - 1, 0)), WALL, Enum.Material.Concrete)
		part(f, "WallZ", Vector3.new(W * 2 + 4, H, 2),
			CFrame.new(centre + Vector3.new(0, H / 2 - 1, side * (L + 1))), WALL, Enum.Material.Concrete)
	end

	-- A lid. The walls alone are not enough: a double jump off a crate against a wall is how
	-- players end up on top of a map, and an arena you can leave is not an arena.
	local lid = part(f, "Ceiling", Vector3.new(W * 2 + 4, 2, L * 2 + 4),
		CFrame.new(centre + Vector3.new(0, H - 1, 0)), WALL)
	lid.Transparency = 1
	lid.CanQuery = false      -- never stop a bullet or a camera raycast

	-- ------------------------------------------------------------- neon --

	-- Trim along the inside of every wall, twice: at the top and at waist height. The half
	-- nearer spawn A is magenta, the half nearer B is cyan.
	for _, y in ipairs({ H - 2.5, 5 }) do
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				decor(f, "Trim", Vector3.new(0.3, 0.5, L),
					CFrame.new(centre + Vector3.new(sx * (W - 0.1), y, sz * L / 2)),
					sz < 0 and SIDE_A or SIDE_B, Enum.Material.Neon)
			end
		end
		for _, sz in ipairs({ -1, 1 }) do
			decor(f, "Trim", Vector3.new(W * 2, 0.5, 0.3),
				CFrame.new(centre + Vector3.new(0, y, sz * (L - 0.1))), sz < 0 and SIDE_A or SIDE_B, Enum.Material.Neon)
		end
	end
	-- Vertical light bars along the side walls.
	for z = -48, 48, 24 do
		for _, sx in ipairs({ -1, 1 }) do
			decor(f, "LightBar", Vector3.new(0.3, H - 8, 0.6),
				CFrame.new(centre + Vector3.new(sx * (W - 0.1), (H - 8) / 2 + 2, z)),
				z < 0 and SIDE_A or SIDE_B, Enum.Material.Neon).Transparency = 0.15
		end
	end

	-- The signs: a huge 1V1 over each spawn, and the game's name down both sides.
	sign(f, "1V1", centre + Vector3.new(0, H - 11, -(L - 0.4)), Vector3.new(0, 0, 1), 34, 13, SIDE_A)
	sign(f, "1V1", centre + Vector3.new(0, H - 11, L - 0.4), Vector3.new(0, 0, -1), 34, 13, SIDE_B)
	sign(f, "PROJECT ZEE", centre + Vector3.new(-(W - 0.4), H - 11, 0), Vector3.new(1, 0, 0), 60, 9, SIDE_B)
	sign(f, "PROJECT ZEE", centre + Vector3.new(W - 0.4, H - 11, 0), Vector3.new(-1, 0, 0), 60, 9, SIDE_A)

	-- ----------------------------------------------------------- lights --

	-- Stadium lamps hung under the lid, pointing down, and a coloured wash on each half.
	for i, z in ipairs({ -30, 30 }) do
		for _, x in ipairs({ -18, 18 }) do
			local lamp = decor(f, "Lamp", Vector3.new(4, 0.6, 2), CFrame.new(centre + Vector3.new(x, H - 3, z)),
				Color3.fromRGB(240, 244, 255), Enum.Material.Neon)
			local spot = Instance.new("SpotLight")
			spot.Face = Enum.NormalId.Bottom
			spot.Angle = 80
			spot.Range = 48
			spot.Brightness = 1.6
			spot.Color = Color3.fromRGB(235, 240, 255)
			-- Two of the four cast shadows: enough for depth, cheap enough for a duel.
			spot.Shadows = (i == 1 and x < 0) or (i == 2 and x > 0)
			spot.Parent = lamp
		end
	end
	for _, sz in ipairs({ -1, 1 }) do
		local wash = decor(f, "Wash", Vector3.new(1, 1, 1), CFrame.new(centre + Vector3.new(0, 10, sz * (L - 8))), WALL)
		wash.Transparency = 1
		local light = Instance.new("PointLight")
		light.Color = sz < 0 and SIDE_A or SIDE_B
		light.Range = 40
		light.Brightness = 1.2
		light.Shadows = false
		light.Parent = wash
	end

	-- ------------------------------------------------------------ cover --

	-- Each entry is placed twice, half a turn apart. Kept deliberately sparse: a duel map
	-- wants sightlines broken, not a maze to hide in.
	pair(f, "CrateLow", Vector3.new(8, 4, 8), Vector3.new(14, 1, 22), COVER, Enum.Material.Metal)
	pair(f, "CrateTall", Vector3.new(6, 9, 6), Vector3.new(-20, 3.5, 12), COVER_DARK, Enum.Material.Metal)
	pair(f, "Pillar", Vector3.new(5, 14, 5), Vector3.new(26, 6, -6), WALL, Enum.Material.Slate)
	pair(f, "Barricade", Vector3.new(16, 5, 3), Vector3.new(-8, 1.5, -26), COVER, Enum.Material.Concrete)

	-- Two shoulders of cover right at the centre, so crossing the middle is a decision.
	pair(f, "MidBlock", Vector3.new(4, 7, 12), Vector3.new(16, 2.5, 0), COVER_DARK, Enum.Material.Metal)

	-- ----------------------------------------------------------- spawns --

	for index, position in ipairs(ArenaService.SPAWNS) do
		local pad = part(f, "SpawnPad" .. index, Vector3.new(10, 0.4, 10),
			CFrame.new(position - Vector3.new(0, 3, 0)), index == 1 and SIDE_A or SIDE_B, Enum.Material.Neon)
		pad.CanCollide = false
		pad.CanQuery = false
		pad.Transparency = 0.45
	end

	-- ---------------------------------------------------------- skyline --

	local city = Instance.new("Folder")
	city.Name = "Skyline"
	city.Parent = f
	skyline(city)

	print(("[Arena] duel arena built at y=%d, %d x %d studs, %d parts")
		:format(centre.Y, W * 2, L * 2, #f:GetDescendants()))
end

--- Where duellist `index` starts, looking at their opponent.
function ArenaService.SpawnCFrame(index: number): CFrame
	local position = ArenaService.SPAWNS[index] or ArenaService.SPAWNS[1]
	local opposite = ArenaService.SPAWNS[index == 1 and 2 or 1]
	return CFrame.lookAt(position, Vector3.new(opposite.X, position.Y, opposite.Z))
end

--- True when a position is still inside the arena shell. Used to catch anyone who has left
--- it by means nobody anticipated, rather than trusting that they cannot.
function ArenaService.Contains(position: Vector3): boolean
	local c = ArenaService.CENTRE
	return math.abs(position.X - c.X) <= ArenaService.HALF_WIDTH + 4
		and math.abs(position.Z - c.Z) <= ArenaService.HALF_LENGTH + 4
		and position.Y > c.Y - 20
		and position.Y < c.Y + ArenaService.WALL_HEIGHT + 10
end

ArenaService.Build()

return ArenaService
