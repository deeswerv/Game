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

local FLOOR = Color3.fromRGB(58, 62, 74)
local FLOOR_ALT = Color3.fromRGB(48, 52, 62)
local WALL = Color3.fromRGB(38, 41, 50)
local COVER = Color3.fromRGB(104, 72, 46)
local COVER_DARK = Color3.fromRGB(74, 50, 32)
local LINE = Color3.fromRGB(55, 214, 122)

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

--- Place a piece and its rotational twin in one call.
---
--- Taking the rotation rather than copying coordinates by hand is what guarantees the map
--- stays fair: there is no way to edit one side and forget the other.
local function pair(parent: Instance, name: string, size: Vector3, offset: Vector3,
	colour: Color3, material: Enum.Material?)
	local centre = ArenaService.CENTRE
	part(parent, name .. "_A", size, CFrame.new(centre + offset), colour, material)
	-- 180 degrees about the arena's vertical axis: (x, z) -> (-x, -z).
	part(parent, name .. "_B", size,
		CFrame.new(centre + Vector3.new(-offset.X, offset.Y, -offset.Z)), colour, material)
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

	part(f, "Floor", Vector3.new(W * 2, 2, L * 2), CFrame.new(centre - Vector3.new(0, 1, 0)), FLOOR)

	-- A darker band across the middle, so both players can see where half way is. Reading the
	-- centre line is most of how a duellist judges an engagement.
	part(f, "Midfield", Vector3.new(W * 2, 2.1, 16), CFrame.new(centre - Vector3.new(0, 0.95, 0)), FLOOR_ALT)
	part(f, "Centreline", Vector3.new(W * 2, 2.2, 0.6), CFrame.new(centre - Vector3.new(0, 0.9, 0)), LINE,
		Enum.Material.Neon)

	for _, side in ipairs({ -1, 1 }) do
		part(f, "WallX", Vector3.new(2, H, L * 2 + 4),
			CFrame.new(centre + Vector3.new(side * (W + 1), H / 2 - 1, 0)), WALL)
		part(f, "WallZ", Vector3.new(W * 2 + 4, H, 2),
			CFrame.new(centre + Vector3.new(0, H / 2 - 1, side * (L + 1))), WALL)
	end

	-- A lid. The walls alone are not enough: a double jump off a crate against a wall is how
	-- players end up on top of a map, and an arena you can leave is not an arena.
	local lid = part(f, "Ceiling", Vector3.new(W * 2 + 4, 2, L * 2 + 4),
		CFrame.new(centre + Vector3.new(0, H - 1, 0)), WALL)
	lid.Transparency = 1
	lid.CanQuery = false      -- never stop a bullet or a camera raycast

	-- ------------------------------------------------------------ cover --

	-- Each entry is placed twice, half a turn apart. Kept deliberately sparse: a duel map
	-- wants sightlines broken, not a maze to hide in.
	pair(f, "CrateLow", Vector3.new(8, 4, 8), Vector3.new(14, 1, 22), COVER, Enum.Material.WoodPlanks)
	pair(f, "CrateTall", Vector3.new(6, 9, 6), Vector3.new(-20, 3.5, 12), COVER_DARK, Enum.Material.Wood)
	pair(f, "Pillar", Vector3.new(5, 14, 5), Vector3.new(26, 6, -6), WALL, Enum.Material.Slate)
	pair(f, "Barricade", Vector3.new(16, 5, 3), Vector3.new(-8, 1.5, -26), COVER, Enum.Material.WoodPlanks)

	-- Two shoulders of cover right at the centre, so crossing the middle is a decision.
	pair(f, "MidBlock", Vector3.new(4, 7, 12), Vector3.new(16, 2.5, 0), COVER_DARK, Enum.Material.Wood)

	-- ----------------------------------------------------------- spawns --

	for index, position in ipairs(ArenaService.SPAWNS) do
		local pad = part(f, "SpawnPad" .. index, Vector3.new(10, 0.4, 10),
			CFrame.new(position - Vector3.new(0, 3, 0)), LINE, Enum.Material.Neon)
		pad.CanCollide = false
		pad.Transparency = 0.5
	end

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
