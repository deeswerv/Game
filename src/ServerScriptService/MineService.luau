--!strict
-- The Mine: behind the waterfall, down a shaft, into a cavern.
--
-- Crystals used to be fifteen nodes scattered on whatever flat ground an algorithm could
-- find, which is why they read as litter rather than as a place. They now live somewhere
-- you have to go: walk through the falls at the plunge pool, find the mine head in the
-- overhang, climb down the ladder.
--
-- Built in the empty volume UNDER the island (verified 0 parts in a 60x30x60 box at
-- y = -40) rather than tunnelled into the cliff mesh, because a tunnel bored through solid
-- terrain collision is a tunnel you cannot walk down.

local WorldBake = require(game:GetService("ServerScriptService").WorldBake)

local MineService = {}

MineService.HEAD = Vector3.new(-101, 0.5, 61)      -- in the open behind the falling water
MineService.TUNNEL_END_Z = 57
MineService.SHAFT_BOTTOM = -34
MineService.CAVERN = Vector3.new(-101, -40, 40)

local ROCK = Color3.fromRGB(96, 92, 96)
local ROCK_DARK = Color3.fromRGB(68, 65, 70)
local WOOD = Color3.fromRGB(104, 72, 46)
local WOOD_DARK = Color3.fromRGB(74, 50, 32)
local RAIL = Color3.fromRGB(120, 110, 96)
local LAMP = Color3.fromRGB(242, 186, 104)

local function folder(): Folder
	local f = workspace:FindFirstChild("Mine")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Mine"
		f.Parent = workspace
	end
	return f :: Folder
end

local function part(parent, name, size, cf, colour, material, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.Slate
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function lantern(parent, cf)
	local l = part(parent, "Lantern", Vector3.new(0.7, 0.9, 0.7), cf, LAMP, Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = LAMP
	light.Brightness = 2.0
	light.Range = 22
	light.Parent = l
	return l
end

-- A timber support frame: two posts and a header, the motif that says "mine".
local function support(parent, cf, width, height)
	part(parent, "PostL", Vector3.new(0.8, height, 0.8), cf * CFrame.new(-width / 2, height / 2, 0), WOOD, Enum.Material.Wood)
	part(parent, "PostR", Vector3.new(0.8, height, 0.8), cf * CFrame.new(width / 2, height / 2, 0), WOOD, Enum.Material.Wood)
	part(parent, "Header", Vector3.new(width + 1.6, 0.9, 1.0), cf * CFrame.new(0, height, 0), WOOD_DARK, Enum.Material.Wood)
end

function MineService.Build()
	if WorldBake.Skip("Mine", "Mine") then
		return
	end
	local f = folder()
	f:ClearAllChildren()

	local head = MineService.HEAD
	local W, H = 9, 9                       -- tunnel bore
	local tunnelZ0, tunnelZ1 = head.Z, MineService.TUNNEL_END_Z
	local floorY = head.Y

	-- ---------------------------------------------------------------- mine head --
	local entrance = Instance.new("Model")
	entrance.Name = "MineHead"
	entrance.Parent = f

	local mouth = CFrame.new(head.X, floorY, tunnelZ0)
	support(entrance, mouth, W, H)
	part(entrance, "Lintel", Vector3.new(W + 5, 1.6, 2.4), mouth * CFrame.new(0, H + 1.4, 0), WOOD_DARK, Enum.Material.Wood)
	lantern(entrance, mouth * CFrame.new(-W / 2 - 0.9, H - 0.6, 0))
	lantern(entrance, mouth * CFrame.new(W / 2 + 0.9, H - 0.6, 0))

	local board = part(entrance, "Sign", Vector3.new(7, 2.2, 0.4), mouth * CFrame.new(0, H + 3.2, 0), WOOD_DARK, Enum.Material.Wood)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(560, 176)
	gui.LightInfluence = 0
	gui.Adornee = board
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.62)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "THE MINE"
	title.TextColor3 = Color3.fromRGB(186, 170, 255)
	title.TextScaled = true
	title.Parent = gui
	local sub = Instance.new("TextLabel")
	sub.Position = UDim2.fromScale(0, 0.62)
	sub.Size = UDim2.fromScale(1, 0.38)
	sub.BackgroundTransparency = 1
	sub.Font = Enum.Font.GothamMedium
	sub.Text = "Mind the ladder"
	sub.TextColor3 = Color3.fromRGB(226, 222, 214)
	sub.TextScaled = true
	sub.Parent = gui

	-- ------------------------------------------------------------------ tunnel --
	local tunnel = Instance.new("Model")
	tunnel.Name = "Tunnel"
	tunnel.Parent = f

	local length = tunnelZ0 - tunnelZ1
	local midZ = (tunnelZ0 + tunnelZ1) / 2
	part(tunnel, "Floor", Vector3.new(W, 1, length), CFrame.new(head.X, floorY - 0.5, midZ), ROCK_DARK)
	-- A touch longer than the walls, so its ends are not the walls' ends too (they flickered).
	part(tunnel, "Roof", Vector3.new(W + 2, 1, length + 0.06), CFrame.new(head.X, floorY + H + 0.5, midZ), ROCK_DARK)
	part(tunnel, "WallL", Vector3.new(1, H + 1, length), CFrame.new(head.X - W / 2 - 0.5, floorY + H / 2, midZ), ROCK)
	part(tunnel, "WallR", Vector3.new(1, H + 1, length), CFrame.new(head.X + W / 2 + 0.5, floorY + H / 2, midZ), ROCK)

	for z = tunnelZ0 - 4, tunnelZ1 + 2, -5 do
		support(tunnel, CFrame.new(head.X, floorY, z), W - 1.4, H - 0.8)
		lantern(tunnel, CFrame.new(head.X + W / 2 - 1.2, floorY + H - 1.6, z))
	end

	-- rails, because a mine has rails
	for _, side in ipairs({ -1.6, 1.6 }) do
		part(tunnel, "Rail", Vector3.new(0.3, 0.25, length - 1), CFrame.new(head.X + side, floorY + 0.15, midZ), RAIL, Enum.Material.Metal, false)
	end

	-- ------------------------------------------------------------------- shaft --
	local shaft = Instance.new("Model")
	shaft.Name = "Shaft"
	shaft.Parent = f

	local shaftZ = 54        -- the gap cut in the lake floor
	local top, bottom = floorY, MineService.SHAFT_BOTTOM
	local depth = top - bottom
	local SW = 10

	-- Walls of the shaft. Each stands a twentieth of a stud inside the opening and stops the
	-- same amount under the tunnel floor: exactly on those lines, their faces were the same
	-- planes as the cavern roof's cut edges and the floor's top, and the shaft flickered in a
	-- band all the way round where the ladder passes through the roof.
	local inset, wallH, wallY = 0.05, depth - 0.05, (top + bottom) / 2 - 0.025
	for _, spec in ipairs({
		{ Vector3.new(1, wallH, SW + 2), Vector3.new(head.X - SW / 2 - 0.5 + inset, wallY, shaftZ) },
		{ Vector3.new(1, wallH, SW + 2), Vector3.new(head.X + SW / 2 + 0.5 - inset, wallY, shaftZ) },
		{ Vector3.new(SW + 2, wallH, 1), Vector3.new(head.X, wallY, shaftZ - SW / 2 - 0.5 + inset) },
		{ Vector3.new(SW + 2, wallH, 1), Vector3.new(head.X, wallY, shaftZ + SW / 2 + 0.5 - inset) },
	}) do
		part(shaft, "ShaftWall", spec[1], CFrame.new(spec[2]), ROCK)
	end

	-- Truss, because it is the one part Roblox lets a character climb.
	local ladder = Instance.new("TrussPart")
	ladder.Name = "Ladder"
	ladder.Size = Vector3.new(2, depth, 2)
	ladder.CFrame = CFrame.new(head.X, (top + bottom) / 2, shaftZ - SW / 2 + 1.4)
	ladder.Color = WOOD
	ladder.Material = Enum.Material.Wood
	ladder.Anchored = true
	ladder.Parent = shaft

	for y = top - 8, bottom + 4, -10 do
		lantern(shaft, CFrame.new(head.X + SW / 2 - 1.0, y, shaftZ))
	end

	-- ----------------------------------------------------------------- cavern --
	local cavern = Instance.new("Model")
	cavern.Name = "Cavern"
	cavern.Parent = f

	local c = MineService.CAVERN
	local CW, CH, CD = 46, 15, 40
	part(cavern, "Floor", Vector3.new(CW, 2, CD), CFrame.new(c.X, c.Y - 1, c.Z), ROCK_DARK)
	-- Roof in four pieces around the shaft opening. A single slab here caps the shaft: a
	-- player falls the length of the ladder and lands ON the ceiling, inside the walls,
	-- with the cavern still sealed underneath them.
	do
		local hx0, hx1 = head.X - SW / 2, head.X + SW / 2
		local hz0, hz1 = shaftZ - SW / 2, shaftZ + SW / 2
		local x0, x1 = c.X - CW / 2, c.X + CW / 2
		local z0, z1 = c.Z - CD / 2, c.Z + CD / 2
		local function roofSlab(name, ax0, ax1, az0, az1)
			if ax1 - ax0 <= 0.01 or az1 - az0 <= 0.01 then return end
			part(cavern, name, Vector3.new(ax1 - ax0, 2, az1 - az0),
				CFrame.new((ax0 + ax1) / 2, c.Y + CH, (az0 + az1) / 2), ROCK_DARK)
		end
		roofSlab("RoofW", x0, hx0, z0, z1)
		roofSlab("RoofE", hx1, x1, z0, z1)
		roofSlab("RoofS", hx0, hx1, z0, hz0)
		roofSlab("RoofN", hx0, hx1, hz1, z1)
	end
	part(cavern, "WallW", Vector3.new(2, CH, CD), CFrame.new(c.X - CW / 2, c.Y + CH / 2, c.Z), ROCK)
	part(cavern, "WallE", Vector3.new(2, CH, CD), CFrame.new(c.X + CW / 2, c.Y + CH / 2, c.Z), ROCK)
	part(cavern, "WallS", Vector3.new(CW, CH, 2), CFrame.new(c.X, c.Y + CH / 2, c.Z - CD / 2), ROCK)
	-- Set back a hair so its face is not the roof's cut edge above the shaft opening.
	part(cavern, "WallN", Vector3.new(CW, CH, 2), CFrame.new(c.X, c.Y + CH / 2, c.Z + CD / 2 + 0.03), ROCK)

	-- a landing so the drop from the ladder is short
	part(cavern, "Landing", Vector3.new(SW + 4, 1, SW + 4), CFrame.new(head.X, bottom - 2, shaftZ), ROCK_DARK)
	-- ramp from the landing down to the cavern floor
	local run = (shaftZ - (c.Z + CD / 2 - 6))
	part(cavern, "Ramp", Vector3.new(8, 1, 26),
		CFrame.new(head.X, (bottom - 2 + c.Y) / 2, shaftZ - 13) * CFrame.Angles(math.rad(-16), 0, 0), ROCK_DARK)

	for _, z in ipairs({ -12, 0, 12 }) do
		support(cavern, CFrame.new(c.X - 12, c.Y, c.Z + z), 10, CH - 3)
		support(cavern, CFrame.new(c.X + 12, c.Y, c.Z + z), 10, CH - 3)
		lantern(cavern, CFrame.new(c.X - 12, c.Y + CH - 3.6, c.Z + z))
		lantern(cavern, CFrame.new(c.X + 12, c.Y + CH - 3.6, c.Z + z))
	end

	print(("[Mine] built: head at (%.0f, %.0f, %.0f), cavern at (%.0f, %.0f, %.0f)"):format(
		head.X, head.Y, head.Z, c.X, c.Y, c.Z))
	return f
end

--- Where crystal nodes should stand inside the cavern, laid out rather than scattered.
function MineService.NodePositions()
	local c = MineService.CAVERN
	local spots = {}
	-- two rows along the cavern, evenly spaced: a worked seam, not litter
	for _, side in ipairs({ -16, 16 }) do
		for i = -1, 1 do
			table.insert(spots, Vector3.new(c.X + side, c.Y, c.Z + i * 12))
		end
	end
	-- and a cluster at the far wall
	table.insert(spots, Vector3.new(c.X - 6, c.Y, c.Z - 15))
	table.insert(spots, Vector3.new(c.X + 6, c.Y, c.Z - 15))
	return spots
end

MineService.Build()

return MineService
