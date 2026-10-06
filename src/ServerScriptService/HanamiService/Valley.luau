--!strict
-- HANAMI VALLEY, built: the world past Downtown. A low-poly valley under cherry blossom, in
-- the soft, bright, faceted look of the duel maps and Downtown -- not a second city. Every
-- place in it has a shape you can pick out from across the valley:
--
--   HANAMURA        the village you arrive in: a red torii at the south gate, a stone street
--                   of wooden houses with white walls and dark tiled roofs, the GREAT SAKURA in
--                   the square, the shrine behind it, the five-storey pagoda, the teahouse.
--   BAMBOO HOLLOW   west of it: bamboo groves, mossy rocks, a waterfall off the cliff into the
--                   river, and the camp where the missing villagers are held.
--   THE PADDIES     east of it: flooded rice fields between dikes, a farmhouse, a scarecrow.
--   LANTERN ROW     over the river, north-west: narrow streets of two-storey shophouses under
--                   strings of red lanterns, stairs up to roofs to fight across.
--   THE IRONWORKS   north-east: the Kurogane foundry -- sheds, a smoking chimney, the furnace
--                   yard, container stacks, the big gantry crane over the dock.
--   KUROGANE KEEP   on the plateau to the north, up the Thousand Gates -- a stair under a run of
--                   red torii -- behind white walls: the Shogun's court, and the black keep.
--
-- Built at run time by HanamiService (like Downtown), in its own folder, the valley's frame
-- from HanamiConfig. Markers the service and the quests need are invisible named parts.

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ServerScriptService.ArenaService.Kit)
local HanamiConfig = require(ReplicatedStorage.HanamiConfig)

local Valley = {}

-- The valley's own light: warm and a little hazy, pink in the shadows, bright clouds.
Valley.Look = {
	Grade = { Saturation = 0.18, Contrast = 0.05, TintColor = Color3.fromRGB(255, 244, 246) },
	Clouds = { Cover = 0.55, Density = 0.45, Color = Color3.fromRGB(255, 246, 250) },
	Atmosphere = { Density = 0.32, Haze = 1.4, Color = Color3.fromRGB(250, 222, 232), Decay = Color3.fromRGB(150, 140, 170) },
}

local M = Enum.Material

-- ------------------------------------------------------------------ palette --

local GRASS = Color3.fromRGB(128, 186, 98)
local GRASS_DARK = Color3.fromRGB(100, 160, 82)
local MOSS = Color3.fromRGB(88, 138, 76)
local DIRT = Color3.fromRGB(190, 160, 120)
local PATH = Color3.fromRGB(222, 214, 198)
local PATH_DARK = Color3.fromRGB(196, 186, 168)
local STONE = Color3.fromRGB(176, 174, 168)
local STONE_DARK = Color3.fromRGB(128, 126, 124)
local ROCK = Color3.fromRGB(144, 138, 146)
local ROCK_LIGHT = Color3.fromRGB(172, 166, 172)
local WATER = Color3.fromRGB(104, 182, 218)
local FOAM = Color3.fromRGB(236, 248, 255)
local WOOD = Color3.fromRGB(126, 82, 54)
local WOOD_DARK = Color3.fromRGB(80, 52, 38)
local WOOD_LIGHT = Color3.fromRGB(196, 152, 104)
local PLASTER = Color3.fromRGB(246, 240, 228)
local PAPER = Color3.fromRGB(250, 242, 218)
local ROOF = Color3.fromRGB(60, 66, 84)
local ROOF_EDGE = Color3.fromRGB(44, 48, 62)
local VERMILION = Color3.fromRGB(218, 72, 52)
local GOLD = Color3.fromRGB(236, 190, 80)
local SAKURA = Color3.fromRGB(246, 176, 202)
local SAKURA_LIGHT = Color3.fromRGB(252, 214, 228)
local SAKURA_DEEP = Color3.fromRGB(232, 130, 168)
local BAMBOO = Color3.fromRGB(132, 184, 96)
local BAMBOO_DARK = Color3.fromRGB(96, 146, 72)
local LANTERN_RED = Color3.fromRGB(226, 76, 60)
local IRON = Color3.fromRGB(64, 66, 74)
local STEEL = Color3.fromRGB(120, 126, 136)
local RUST = Color3.fromRGB(162, 96, 64)
local KURO = Color3.fromRGB(36, 38, 46)          -- the clan's black iron
local CRIMSON = Color3.fromRGB(160, 36, 44)
local CREAM = Color3.fromRGB(250, 242, 222)
local CONTAINERS = {
	Color3.fromRGB(196, 78, 62), Color3.fromRGB(60, 112, 168), Color3.fromRGB(226, 170, 62),
	Color3.fromRGB(72, 136, 104), Color3.fromRGB(150, 156, 164),
}
local NOREN = { Color3.fromRGB(46, 70, 130), CRIMSON, Color3.fromRGB(60, 110, 84), Color3.fromRGB(110, 60, 120) }

-- ------------------------------------------------------------------ helpers --

local function vertical(at: Vector3): CFrame
	return CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90))
end

local function darker(c: Color3, t: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), t)
end

--- Lettering on a surface; `at` looks the way it is read from.
local function painted(b: Kit.Builder, text: string, at: CFrame, w: number, h: number, colour: Color3, font: Enum.Font?)
	b:sign(text, at, w, h, colour, { lit = true, glow = false, font = font or Enum.Font.GothamBlack,
		textColour = colour, brightness = 1 })
end

--- A painted board: a panel in a frame, lettering on it. `at` looks the way it is read from.
local function board(b: Kit.Builder, text: string, at: CFrame, w: number, h: number, bg: Color3, fg: Color3, font: Enum.Font?)
	local s = b:within(at)
	s:decor("SignFrame", Vector3.new(w + 0.5, h + 0.5, 0.3), Vector3.new(0, 0, 0.36), darker(bg, 0.45))
	s:decor("SignBoard", Vector3.new(w, h, 0.3), Vector3.new(0, 0, 0.2), bg)
	s:sign(text, CFrame.new(), w * 0.9, h * 0.76, fg, { lit = true, glow = false, font = font or Enum.Font.GothamBlack,
		textColour = fg, brightness = 1 })
end

--- An invisible marker the service or the quests look for by name.
local function marker(b: Kit.Builder, name: string, at: Vector3, attributes: { [string]: any }?): BasePart
	local p = b:decor(name, Vector3.new(1, 1, 1), at, CREAM, nil, { transparency = 1 })
	for k, v in pairs(attributes or {}) do
		p:SetAttribute(k, v)
	end
	return p
end

--- A climbable ladder (a truss) standing on `at` (its foot), `height` tall, on the builder's
--- axes. Plank ramps too steep to walk are not climbable; a truss is.
local function ladder(b: Kit.Builder, at: Vector3, height: number, colour: Color3?)
	local h = math.max(2, math.floor(height / 2 + 0.5) * 2)
	local truss = Instance.new("TrussPart")
	truss.Name = "Ladder"
	truss.Size = Vector3.new(2, h, 2)
	truss.CFrame = b:world(CFrame.new(at + Vector3.new(0, h / 2, 0)))
	truss.Color = colour or WOOD_DARK
	truss.Anchored = true
	truss.TopSurface = Enum.SurfaceType.Smooth
	truss.BottomSurface = Enum.SurfaceType.Smooth
	truss.Parent = b.parent
	return truss
end

--- A slab of ground: top at `top`, `colour`, from x0..x1, z0..z1. Solid.
local function ground(b: Kit.Builder, name: string, x0: number, x1: number, z0: number, z1: number, top: number,
	colour: Color3, material: Enum.Material?, depth: number?)
	local d = depth or 6
	return b:part(name, Vector3.new(x1 - x0, d, z1 - z0), Vector3.new((x0 + x1) / 2, top - d / 2, (z0 + z1) / 2), colour,
		material or M.Grass)
end

--- A flat strip laid on the ground (a path, a patch of gravel). Seen, not solid.
local function patch(b: Kit.Builder, name: string, x0: number, x1: number, z0: number, z1: number, y: number, colour: Color3,
	material: Enum.Material?)
	return b:decor(name, Vector3.new(x1 - x0, 0.1, z1 - z0), Vector3.new((x0 + x1) / 2, y + 0.05, (z0 + z1) / 2), colour,
		material or M.SmoothPlastic)
end

-- -------------------------------------------------------------- the props --

--- A paper lantern hanging from `at` (its top), the glowing body named LanternGlass so it
--- lights up at night (CityLights.client).
local function lantern(b: Kit.Builder, at: Vector3, colour: Color3?, size: number?)
	local s = size or 1
	b:decor("LanternCord", Vector3.new(0.08, 0.5 * s, 0.08), at - Vector3.new(0, 0.25 * s, 0), KURO)
	b:decor("LanternCap", Vector3.new(0.7 * s, 0.18 * s, 0.7 * s), at - Vector3.new(0, 0.55 * s, 0), KURO)
	b:decor("LanternGlass", Vector3.new(1.0 * s, 1.3 * s, 1.0 * s), at - Vector3.new(0, 1.3 * s, 0), colour or LANTERN_RED,
		nil, { shape = "Ball" })
	b:decor("LanternCap", Vector3.new(0.6 * s, 0.16 * s, 0.6 * s), at - Vector3.new(0, 2.02 * s, 0), KURO)
end

--- A stone lantern (toro) standing on the ground at the origin: plinth, post, the light box,
--- a wide cap and a jewel on top.
local function stoneLantern(b: Kit.Builder, scale: number?)
	local s = scale or 1
	b:part("ToroBase", Vector3.new(1.6 * s, 0.5 * s, 1.6 * s), Vector3.new(0, 0.25 * s, 0), STONE, M.Slate)
	b:part("ToroPost", Vector3.new(2.2 * s, 0.7 * s, 0.7 * s), vertical(Vector3.new(0, 1.6 * s, 0)), STONE, M.Slate, { shape = "Cylinder" })
	b:decor("ToroShelf", Vector3.new(1.5 * s, 0.3 * s, 1.5 * s), Vector3.new(0, 2.85 * s, 0), STONE, M.Slate)
	b:decor("LanternGlass", Vector3.new(0.9 * s, 0.9 * s, 0.9 * s), Vector3.new(0, 3.45 * s, 0), PAPER)
	for _, x in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -1, 1 }) do
			b:decor("ToroPillar", Vector3.new(0.18 * s, 1 * s, 0.18 * s), Vector3.new(x * 0.5 * s, 3.45 * s, z * 0.5 * s), STONE)
		end
	end
	b:decor("ToroCap", Vector3.new(2 * s, 0.35 * s, 2 * s), Vector3.new(0, 4.1 * s, 0) , STONE, M.Slate)
	b:decor("ToroCap", Vector3.new(1.2 * s, 0.35 * s, 1.2 * s), CFrame.new(0, 4.4 * s, 0) * CFrame.Angles(0, math.rad(45), 0), STONE, M.Slate)
	b:decor("ToroJewel", Vector3.new(0.45 * s, 0.45 * s, 0.45 * s), Vector3.new(0, 4.75 * s, 0), STONE, M.Slate, { shape = "Ball" })
end

--- A torii gate across the origin, `w` between the posts, `h` to the lower beam, facing Z.
local function torii(b: Kit.Builder, w: number, h: number, colour: Color3?)
	local c = colour or VERMILION
	local r = math.max(0.7, w * 0.06)
	for _, x in ipairs({ -w / 2, w / 2 }) do
		b:part("ToriiPost", Vector3.new(h + 2, r * 2, r * 2), vertical(Vector3.new(x, (h + 2) / 2, 0)), c, nil, { shape = "Cylinder" })
		b:decor("ToriiFoot", Vector3.new(r * 2.6, 1.2, r * 2.6), Vector3.new(x, 0.6, 0), KURO)
	end
	b:decor("Nuki", Vector3.new(w + r * 3, r * 0.9, r * 0.9), Vector3.new(0, h, 0), c)
	b:decor("Kasagi", Vector3.new(w + r * 7, r * 1.1, r * 1.6), Vector3.new(0, h + 2 + r * 0.55, 0), c)
	b:decor("KasagiTop", Vector3.new(w + r * 8, r * 0.7, r * 1.9), Vector3.new(0, h + 2 + r * 1.45, 0), KURO)
	-- The upturned ends.
	for _, s in ipairs({ -1, 1 }) do
		b:decor("KasagiTip", Vector3.new(r * 2, r * 0.7, r * 1.9),
			CFrame.new(s * (w / 2 + r * 4.5), h + 2 + r * 1.7, 0) * CFrame.Angles(0, 0, s * math.rad(14)), KURO)
	end
	b:decor("Gakuzuka", Vector3.new(r * 0.8, 2, r * 0.6), Vector3.new(0, h + 1, 0), c)
end

--- A cherry tree, its origin on the ground. `scale` grows it; `seed` shapes it.
local function sakura(b: Kit.Builder, seed: number, scale: number?)
	local s = scale or 1
	local rng = Random.new(seed)
	b:part("Trunk", Vector3.new(6 * s, 1.1 * s, 1.1 * s), vertical(Vector3.new(0, 3 * s, 0)), WOOD_DARK, M.Wood, { shape = "Cylinder" })
	for k = 1, 3 do
		local a = seed + k * 2.1
		local lean = CFrame.new(math.cos(a) * 1.1 * s, 6.4 * s, math.sin(a) * 1.1 * s)
			* CFrame.Angles(math.sin(a) * 0.6, 0, -math.cos(a) * 0.6) * CFrame.Angles(0, 0, math.rad(90))
		b:decor("Branch", Vector3.new(3.4 * s, 0.6 * s, 0.6 * s), lean, WOOD_DARK, M.Wood, { shape = "Cylinder" })
	end
	local shades = { SAKURA_DEEP, SAKURA, SAKURA_LIGHT }
	for _, blob in ipairs({
		{ Vector3.new(0, 8.2, 0), 6.2, 2 }, { Vector3.new(2.6, 7.6, 1), 4.6, 1 }, { Vector3.new(-2.5, 7.8, -1), 4.8, 2 },
		{ Vector3.new(-0.5, 7.4, 2.6), 4.2, 1 }, { Vector3.new(0.8, 9.8, -0.8), 4.6, 3 }, { Vector3.new(-1.4, 9.6, 1), 3.8, 3 },
		{ Vector3.new(1.8, 8.8, 2), 3, 3 },
	} :: { { any } }) do
		local size = blob[2] * rng:NextNumber(0.85, 1.15) * s
		local at = blob[1] * s + Vector3.new(rng:NextNumber(-0.4, 0.4), rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.4, 0.4))
		b:decor("Blossom", Vector3.new(size, size * 0.86, size), at, shades[blob[3]], nil, { shape = "Ball", shadow = true })
	end
	-- Fallen petals round its foot.
	b:decor("Petals", Vector3.new(0.06, 7 * s, 7 * s), CFrame.new(0, 0.04, 0) * CFrame.Angles(0, 0, math.rad(90)), SAKURA_LIGHT,
		nil, { shape = "Cylinder", transparency = 0.25 })
end

--- The Great Sakura: the village's tree, the valley's first landmark -- a thick old trunk that
--- splits into limbs, a canopy as big as a house, a sacred rope round it.
local function greatSakura(b: Kit.Builder)
	b:part("GreatTrunk", Vector3.new(18, 5, 5), vertical(Vector3.new(0, 9, 0)), WOOD_DARK, M.Wood, { shape = "Cylinder" })
	b:decor("GreatRoots", Vector3.new(1.6, 9, 9), CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90)), WOOD_DARK, M.Wood,
		{ shape = "Cylinder" })
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2 + 0.4
		local from = Vector3.new(0, 15, 0)
		local to = Vector3.new(math.cos(a) * 11, 22 + (k % 2) * 3, math.sin(a) * 11)
		local cf, len = Kit.Span(from, to)
		b:decor("GreatLimb", Vector3.new(2.2, 2.2, len + 1), cf, WOOD_DARK, M.Wood)
	end
	-- The rope (shimenawa) and its paper streamers.
	b:decor("Shimenawa", Vector3.new(0.9, 5.8, 5.8), CFrame.new(0, 6.5, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(216, 190, 130),
		nil, { shape = "Cylinder" })
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		b:decor("Shide", Vector3.new(0.5, 1.4, 0.08), CFrame.new(math.cos(a) * 2.95, 5.4, math.sin(a) * 2.95) * CFrame.Angles(0, -a, 0),
			PAPER)
	end
	local rng = Random.new(77)
	local shades = { SAKURA_DEEP, SAKURA, SAKURA_LIGHT }
	for k = 0, 17 do
		local a = k / 18 * math.pi * 2 + rng:NextNumber(-0.2, 0.2)
		local ring = if k % 3 == 0 then 6 else 13
		local size = rng:NextNumber(11, 16)
		local at = Vector3.new(math.cos(a) * ring, 24 + rng:NextNumber(-2, 5) + (if ring < 10 then 6 else 0), math.sin(a) * ring)
		b:decor("Blossom", Vector3.new(size, size * 0.8, size), at, shades[(k % 3) + 1], nil, { shape = "Ball", shadow = true })
	end
	b:decor("Blossom", Vector3.new(16, 12, 16), Vector3.new(0, 34, 0), SAKURA_LIGHT, nil, { shape = "Ball", shadow = true })
	b:decor("Petals", Vector3.new(0.06, 34, 34), CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)), SAKURA_LIGHT, nil,
		{ shape = "Cylinder", transparency = 0.3 })
	-- A low stone ring round it to sit on.
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		b:part("TreeRing", Vector3.new(3.4, 1.2, 1.4), CFrame.new(math.cos(a) * 7, 0.6, math.sin(a) * 7) * CFrame.Angles(0, -a + math.pi / 2, 0),
			STONE, M.Slate)
	end
end

--- A gable roof over a w x d footprint whose eaves sit at `y`, ridge along X, rising `rise`;
--- overhanging all round. Dark tiles, a ridge cap and a pale fascia under the eaves.
local function roof(b: Kit.Builder, w: number, d: number, y: number, rise: number, colour: Color3?)
	local c = colour or ROOF
	local ow, od = w + 2.4, d + 2.4
	b:part("Roof", Vector3.new(ow, rise, od / 2), Vector3.new(0, y + rise / 2, -od / 4), c, M.Slate, { shape = "Wedge" })
	b:part("Roof", Vector3.new(ow, rise, od / 2), CFrame.new(0, y + rise / 2, od / 4) * CFrame.Angles(0, math.pi, 0), c, M.Slate,
		{ shape = "Wedge" })
	b:decor("Ridge", Vector3.new(ow + 0.6, 0.6, 0.8), Vector3.new(0, y + rise + 0.2, 0), ROOF_EDGE)
	for _, s in ipairs({ -1, 1 }) do
		b:decor("Eave", Vector3.new(ow, 0.3, 0.4), Vector3.new(0, y - 0.05, s * (od / 2 - 0.2)), ROOF_EDGE)
		b:decor("RidgeTip", Vector3.new(0.8, 0.8, 1), CFrame.new(s * (ow / 2 + 0.2), y + rise + 0.45, 0) * CFrame.Angles(0, 0, s * math.rad(-20)),
			ROOF_EDGE)
	end
end

--- A house (machiya) facing -Z, origin at the middle of its front on the ground: a stone
--- plinth, a timber frame with white plaster between, slatted windows, a sliding door with
--- a cloth curtain over it, one or two storeys under dark tiles. `seed` picks the curtain.
local function house(b: Kit.Builder, w: number, d: number, storeys: number, seed: number, sign: string?)
	local h = 7.5 * storeys
	b:part("Plinth", Vector3.new(w + 0.6, 1, d + 0.6), Vector3.new(0, 0.5, d / 2), STONE, M.Slate)
	b:part("House", Vector3.new(w, h, d), Vector3.new(0, 1 + h / 2, d / 2), PLASTER)
	-- The frame: posts at the corners and every few studs, a beam at each floor.
	local bays = math.max(2, math.floor(w / 4.5))
	for k = 0, bays do
		local x = -w / 2 + k * (w / bays)
		b:decor("Post", Vector3.new(0.6, h, 0.3), Vector3.new(x, 1 + h / 2, -0.12), WOOD)
	end
	for f = 1, storeys do
		b:decor("Beam", Vector3.new(w + 0.2, 0.6, 0.3), Vector3.new(0, 1 + f * 7.5 - 0.3, -0.12), WOOD)
	end
	-- Ground floor: the door in the middle bay, slatted windows either side.
	b:decor("Door", Vector3.new(3.6, 5.6, 0.2), Vector3.new(0, 3.8, -0.1), PAPER)
	for k = -1, 1 do
		b:decor("DoorBar", Vector3.new(0.12, 5.6, 0.25), Vector3.new(k * 1.2, 3.8, -0.15), WOOD_DARK)
	end
	b:decor("DoorBar", Vector3.new(3.6, 0.12, 0.25), Vector3.new(0, 4.6, -0.15), WOOD_DARK)
	local noren = NOREN[seed % #NOREN + 1]
	for k = -1, 1 do
		b:decor("Noren", Vector3.new(1.15, 2, 0.08), Vector3.new(k * 1.22, 6.1, -0.45), noren, M.Fabric)
	end
	b:decor("NorenRod", Vector3.new(4, 0.15, 0.15), Vector3.new(0, 7.15, -0.45), WOOD_DARK)
	for _, s in ipairs({ -1, 1 }) do
		local x = s * math.min(w / 2 - 2.6, 5)
		b:decor("Lattice", Vector3.new(2.6, 2.2, 0.2), Vector3.new(x, 4.6, -0.1), WOOD_DARK)
		for k = -2, 2 do
			b:decor("LatticeSlat", Vector3.new(0.14, 2.2, 0.26), Vector3.new(x + k * 0.5, 4.6, -0.14), WOOD_LIGHT)
		end
	end
	if storeys >= 2 then
		-- Upstairs: a row of paper windows behind a little rail.
		for k = -1, 1 do
			b:decor("Shoji", Vector3.new(2.4, 2.6, 0.2), Vector3.new(k * 3.2, 11.6, -0.1), PAPER)
			b:decor("ShojiBar", Vector3.new(2.4, 0.12, 0.26), Vector3.new(k * 3.2, 11.6, -0.14), WOOD_DARK)
		end
		b:decor("Rail", Vector3.new(w - 1, 0.25, 0.25), Vector3.new(0, 10.4, -0.9), WOOD)
		b:decor("Ledge", Vector3.new(w + 0.4, 0.35, 1.4), Vector3.new(0, 8.7, -0.6), ROOF, M.Slate)
	end
	-- A lantern by the door, and the roof.
	lantern(b, Vector3.new(2.6, 7.4, -0.8), if seed % 2 == 0 then LANTERN_RED else PAPER, 0.8)
	roof(b:within(CFrame.new(0, 0, d / 2)), w, d, 1 + h, math.min(6, d * 0.32))
	if sign then
		board(b, sign, Kit.Look(Vector3.new(0, 8.6, -0.9), Vector3.new(0, 8.6, -6)), math.min(w - 2, 8), 1.4, WOOD_DARK, CREAM)
	end
end

--- A clump of bamboo at the origin: `n` tall stalks with their joints, leafy tops.
local function bamboo(b: Kit.Builder, seed: number, n: number)
	local rng = Random.new(seed)
	for _ = 1, n do
		local x, z = rng:NextNumber(-2.2, 2.2), rng:NextNumber(-2.2, 2.2)
		local h = rng:NextNumber(14, 22)
		local lean = CFrame.Angles(rng:NextNumber(-0.06, 0.06), 0, rng:NextNumber(-0.06, 0.06))
		local base = CFrame.new(x, 0, z) * lean
		b:part("Bamboo", Vector3.new(h, 0.55, 0.55), base * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.rad(90)),
			if rng:NextNumber() < 0.5 then BAMBOO else BAMBOO_DARK, nil, { shape = "Cylinder" })
		for y = 3, h - 2, 3.4 do
			b:decor("BambooNode", Vector3.new(0.18, 0.66, 0.66), base * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)),
				BAMBOO_DARK, nil, { shape = "Cylinder" })
		end
	end
	-- The leaves: a few long, flat sprays up in the tops, leaning out, rather than a ball on
	-- every stalk.
	-- (Flat blades, crossed: a ball part is always round, so it cannot be a spray of leaves.)
	for k = 1, 5 do
		local a = rng:NextNumber(0, 6.28)
		local y = rng:NextNumber(9, 17)
		local at = CFrame.new(math.cos(a) * 3, y, math.sin(a) * 3) * CFrame.Angles(0, a, 0)
		local colour = if k % 2 == 0 then Color3.fromRGB(120, 182, 88) else Color3.fromRGB(92, 152, 70)
		for _, turn in ipairs({ 0.45, -0.45 }) do
			b:decor("BambooLeaves", Vector3.new(rng:NextNumber(8, 11), 0.25, rng:NextNumber(2.4, 3.2)),
				at * CFrame.Angles(0, turn, rng:NextNumber(-0.35, -0.1)), colour, nil, { shadow = true })
		end
	end
end

--- A faceted rock at the origin, about `size` across: two or three turned blocks.
local function rock(b: Kit.Builder, size: number, seed: number)
	local rng = Random.new(seed)
	for k = 1, 3 do
		local s = size * rng:NextNumber(0.55, 1) * (if k == 1 then 1 else 0.7)
		b:part("Rock", Vector3.new(s, s * rng:NextNumber(0.6, 0.9), s * rng:NextNumber(0.7, 1)),
			CFrame.new(rng:NextNumber(-0.3, 0.3) * size, s * 0.3, rng:NextNumber(-0.3, 0.3) * size)
				* CFrame.Angles(rng:NextNumber(-0.4, 0.4), rng:NextNumber(0, 6), rng:NextNumber(-0.4, 0.4)),
			if k == 3 then ROCK_LIGHT else ROCK, M.Slate)
	end
	b:decor("Moss", Vector3.new(size * 0.6, 0.3, size * 0.5), CFrame.new(0, size * 0.62, 0) * CFrame.Angles(0, seed, 0.2), MOSS, M.Grass)
end

--- The five-storey pagoda, the village's tall landmark: a stone base, five shrinking tiers
--- each with a wide dark roof turned up at the corners, and the bronze spire on top.
local function pagoda(b: Kit.Builder)
	b:part("PagodaBase", Vector3.new(16, 2, 16), Vector3.new(0, 1, 0), STONE, M.Slate)
	b:part("PagodaStep", Vector3.new(6, 1, 3), Vector3.new(0, 0.5, -9.2), STONE, M.Slate)
	local y = 2
	for tier = 0, 4 do
		local w = 11 - tier * 1.5
		local h = if tier == 0 then 7 else 5
		b:part("PagodaTier", Vector3.new(w, h, w), Vector3.new(0, y + h / 2, 0), if tier % 2 == 0 then VERMILION else PLASTER)
		for _, s in ipairs({ -1, 1 }) do
			for _, axis in ipairs({ "x", "z" }) do
				local at = if axis == "x" then Vector3.new(s * (w / 2 + 0.05), y + h / 2, 0) else Vector3.new(0, y + h / 2, s * (w / 2 + 0.05))
				local size = if axis == "x" then Vector3.new(0.2, h - 1, w * 0.5) else Vector3.new(w * 0.5, h - 1, 0.2)
				b:decor("PagodaPanel", size, at, WOOD_DARK)
			end
		end
		y += h
		local rw = w + 6 - tier * 0.4
		b:part("PagodaRoof", Vector3.new(rw, 1, rw), Vector3.new(0, y + 0.5, 0), ROOF, M.Slate)
		b:decor("PagodaRoofTop", Vector3.new(rw - 2.4, 0.8, rw - 2.4), Vector3.new(0, y + 1.4, 0), ROOF_EDGE, M.Slate)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				b:decor("PagodaHorn", Vector3.new(1.4, 0.5, 1.4),
					CFrame.new(sx * rw / 2, y + 1.1, sz * rw / 2) * CFrame.Angles(sz * math.rad(18), math.rad(45), sx * math.rad(-18)), ROOF_EDGE)
				lantern(b, Vector3.new(sx * (rw / 2 - 0.4), y + 0.1, sz * (rw / 2 - 0.4)), GOLD, 0.6)
			end
		end
		y += 2
	end
	b:decor("Sorin", Vector3.new(12, 0.6, 0.6), vertical(Vector3.new(0, y + 6, 0)), GOLD, M.Metal, { shape = "Cylinder" })
	for k = 0, 6 do
		b:decor("SorinRing", Vector3.new(0.25, 1.6 - k * 0.12, 1.6 - k * 0.12), vertical(Vector3.new(0, y + 2 + k * 1.2, 0)), GOLD, M.Metal,
			{ shape = "Cylinder" })
	end
	b:decor("SorinJewel", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, y + 12.4, 0), GOLD, M.Metal, { shape = "Ball" })
end

--- A shed of corrugated iron facing -Z, origin at its front middle: walls, a low gable roof,
--- a big roll-up door, a little office door, vents and its number painted big.
local function warehouse(b: Kit.Builder, w: number, d: number, h: number, colour: Color3, number: string)
	b:part("Shed", Vector3.new(w, h, d), Vector3.new(0, h / 2, d / 2), colour, M.CorrodedMetal)
	for x = -w / 2 + 1.5, w / 2 - 1.5, 3 do
		b:decor("Rib", Vector3.new(0.3, h, 0.2), Vector3.new(x, h / 2, -0.08), darker(colour, 0.2))
	end
	b:decor("RollDoor", Vector3.new(math.min(12, w * 0.45), h * 0.7, 0.3), Vector3.new(-w * 0.12, h * 0.35, -0.2), STEEL, M.Metal)
	for y = 1, h * 0.7 - 0.5, 0.9 do
		b:decor("DoorSlat", Vector3.new(math.min(12, w * 0.45), 0.12, 0.36), Vector3.new(-w * 0.12, y, -0.22), darker(STEEL, 0.25))
	end
	b:decor("OfficeDoor", Vector3.new(2.6, 5, 0.3), Vector3.new(w * 0.32, 2.5, -0.2), KURO)
	painted(b, number, Kit.Look(Vector3.new(w * 0.32, h * 0.62, -0.35), Vector3.new(w * 0.32, h * 0.62, -6)), 4, 3.4, CREAM)
	roof(b:within(CFrame.new(0, 0, d / 2)), w - 2.4, d - 2.4, h, 3.5, darker(colour, 0.35))
	for k = 0, 2 do
		b:decor("Vent", Vector3.new(1.4, 1.4, 1.4), Vector3.new(-w / 3 + k * w / 3, h + 3.4, d / 2), STEEL, M.Metal)
	end
end

--- A shipping container (8.6 x 8.6 x 20, long along Z) sitting on the origin: ribbed sides,
--- doors at the back. Solid.
local function container(b: Kit.Builder, colour: Color3)
	b:part("Container", Vector3.new(8.4, 8.6, 20), Vector3.new(0, 4.3, 0), colour, M.CorrodedMetal)
	for z = -9, 9, 1.5 do
		for _, s in ipairs({ -1, 1 }) do
			b:decor("ContainerRib", Vector3.new(0.2, 8, 0.6), Vector3.new(s * 4.25, 4.3, z), darker(colour, 0.2))
		end
	end
	b:decor("ContainerDoors", Vector3.new(7.8, 8, 0.2), Vector3.new(0, 4.3, 10.05), darker(colour, 0.12))
	for _, x in ipairs({ -1.4, 1.4 }) do
		b:decor("DoorBar", Vector3.new(0.18, 7.6, 0.3), Vector3.new(x, 4.3, 10.15), STEEL, M.Metal)
	end
end

--- A length of castle wall on X: a battered stone base, a white plastered wall with slit
--- windows, and a dark tiled cap. `len` long, the top of the plaster `h` up.
local function castleWall(b: Kit.Builder, len: number, h: number)
	b:part("WallBase", Vector3.new(len, 6, 5), Vector3.new(0, 3, 0), STONE, M.Slate)
	b:part("CastleWall", Vector3.new(len, h - 6, 2.6), Vector3.new(0, 6 + (h - 6) / 2, 0), PLASTER)
	for x = -len / 2 + 4, len / 2 - 4, 7 do
		for _, s in ipairs({ -1, 1 }) do
			b:decor("Loophole", Vector3.new(1.2, 1.6, 0.2), Vector3.new(x, h - 3, s * 1.32), KURO)
		end
	end
	b:part("WallCap", Vector3.new(len + 1, 1, 4.6), Vector3.new(0, h + 0.5, 0), ROOF, M.Slate)
	b:decor("WallCapRidge", Vector3.new(len + 1, 0.5, 1), Vector3.new(0, h + 1.25, 0), ROOF_EDGE)
end

--- A corner tower (yagura) at the origin: a stone base, a two-tier white body under dark roofs.
local function yagura(b: Kit.Builder)
	b:part("TowerBase", Vector3.new(14, 8, 14), Vector3.new(0, 4, 0), STONE, M.Slate)
	b:part("Yagura", Vector3.new(11, 8, 11), Vector3.new(0, 12, 0), PLASTER)
	b:decor("YaguraBand", Vector3.new(11.2, 1, 11.2), Vector3.new(0, 9, 0), KURO)
	b:part("YaguraRoof", Vector3.new(15, 1.2, 15), Vector3.new(0, 16.6, 0), ROOF, M.Slate)
	b:part("Yagura", Vector3.new(7.5, 5, 7.5), Vector3.new(0, 19.7, 0), PLASTER)
	roof(b:within(CFrame.new(0, 0, 0)), 7.5, 7.5, 22.2, 3.4)
end


-- ------------------------------------------------------------- the places --

--- A two-storey shophouse with a flat roof terrace you can climb to by the stair down its
--- side: the high ground in Lantern Row and at the teahouse. Faces -Z; origin at its front
--- middle on the ground. The terrace floor is 16 up.
local function terraceHouse(b: Kit.Builder, w: number, d: number, seed: number, sign: string?)
	house(b, w, d, 2, seed, sign)
	-- No gable on this one: a flat terrace with a parapet instead (house() roofed it; the
	-- roof parts are cleared below by the caller passing through `flatten`).
	b:part("Terrace", Vector3.new(w + 0.6, 0.6, d + 0.6), Vector3.new(0, 16.3, d / 2), WOOD, M.WoodPlanks)
	for _, s in ipairs({ -1, 1 }) do
		b:part("Parapet", Vector3.new(w + 0.6, 1.4, 0.4), Vector3.new(0, 17.3, d / 2 + s * (d / 2 + 0.1)), WOOD_DARK)
		b:part("Parapet", Vector3.new(0.4, 1.4, d + 0.6), Vector3.new(s * (w / 2 + 0.1), 17.3, d / 2), WOOD_DARK)
	end
	-- The stair up the right-hand side wall, from the street to the terrace.
	local x = w / 2 + 1.6
	local from = Vector3.new(x, 0, 1)
	local to = Vector3.new(x, 16.6, d - 1)
	local cf, len = Kit.Span(from + Vector3.new(0, 0.6, 0), to)
	b:part("Stair", Vector3.new(3, 0.6, len), cf, WOOD, M.WoodPlanks)
	b:decor("StairRail", Vector3.new(0.2, 0.2, len), cf * CFrame.new(1.4, 2.4, 0), WOOD_DARK)
	b:part("StairLanding", Vector3.new(3.4, 0.6, 3), Vector3.new(x, 16.3, d - 0.2), WOOD, M.WoodPlanks)
	for k = 0, 3 do
		local t = k / 3
		b:decor("StairPost", Vector3.new(0.25, 2.4, 0.25), (cf * CFrame.new(1.4, 1.2, -len / 2 + t * len)), WOOD_DARK)
	end
end

--- Take the gable off a house so a terrace can sit there: house() builds its roof as named
--- parts, and a terrace house wants a flat top instead.
local function flatten(folder: Instance, before: { [Instance]: boolean })
	for _, d in ipairs(folder:GetChildren()) do
		if not before[d] and (d.Name == "Roof" or d.Name == "Ridge" or d.Name == "RidgeTip" or d.Name == "Eave") then
			d:Destroy()
		end
	end
end

local function snapshot(folder: Instance): { [Instance]: boolean }
	local set = {}
	for _, d in ipairs(folder:GetChildren()) do
		set[d] = true
	end
	return set
end

--- A string of lanterns across a street, from `a` to `b` (both at the eaves' height).
local function lanternString(b: Kit.Builder, a: Vector3, c: Vector3, count: number)
	local mid = (a + c) / 2 - Vector3.new(0, 1.2, 0)
	for _, pair in ipairs({ { a, mid }, { mid, c } }) do
		local cf, len = Kit.Span(pair[1], pair[2])
		b:decor("LanternLine", Vector3.new(0.08, 0.08, len), cf, KURO)
	end
	for k = 1, count do
		local t = k / (count + 1)
		local sag = 1.2 * (1 - (2 * t - 1) ^ 2)
		local p = a:Lerp(c, t) - Vector3.new(0, sag, 0)
		lantern(b, p, if k % 2 == 0 then LANTERN_RED else PAPER, 0.75)
	end
end

local function hanamura(root: Kit.Builder, folder: Instance)
	local S = HanamiConfig.Sites
	-- The street: from the south gate up past the tree to the shrine, and on to the bridge.
	patch(root, "Street", -6, 6, -258, -92, 0, PATH, M.Slate)
	for _, x in ipairs({ -6.4, 6.4 }) do
		patch(root, "StreetEdge", x - 0.4, x + 0.4, -258, -92, 0.02, PATH_DARK, M.Slate)
	end
	patch(root, "Square", -32, 32, -194, -142, 0.01, PATH, M.Slate)
	-- The south gate.
	torii(root:within(CFrame.new(0, 0, -224)), 16, 13)
	board(root, "HANAMURA", Kit.Look(Vector3.new(0, 14.6, -224.9), Vector3.new(0, 14.6, -240)), 7, 1.6, KURO, GOLD)
	marker(root, "HanamiArrival", S.Arrival + Vector3.new(0, 0.5, 0))
	-- A low hedge along the south edge, open at the gate.
	for _, s in ipairs({ -1, 1 }) do
		root:part("Hedge", Vector3.new(86, 2.4, 2.4), Vector3.new(s * 52, 1.2, -252), GRASS_DARK, M.Grass)
	end
	-- The Great Sakura in the square, and benches round it.
	greatSakura(root:within(CFrame.new(S.GreatSakura)))
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + math.pi / 4
		local at = S.GreatSakura + Vector3.new(math.cos(a) * 18, 0, math.sin(a) * 18)
		local bench = root:within(CFrame.lookAt(at, S.GreatSakura))
		bench:part("Bench", Vector3.new(5, 0.4, 1.6), Vector3.new(0, 1.4, 0), WOOD, M.Wood)
		for _, x in ipairs({ -2, 2 }) do
			bench:decor("BenchLeg", Vector3.new(0.4, 1.2, 1.4), Vector3.new(x, 0.6, 0), WOOD_DARK)
		end
		bench:decor("BenchCloth", Vector3.new(5.04, 0.08, 1.64), Vector3.new(0, 1.62, 0), CRIMSON, M.Fabric)
	end
	-- The shrine: a raised stone floor, steps, red pillars, the offering box and the bell.
	local shrine = root:within(CFrame.new(S.Shrine.X, 0, S.Shrine.Z))
	shrine:part("ShrineFloor", Vector3.new(26, 1.5, 20), Vector3.new(0, 0.75, 6), STONE, M.Slate)
	for k = 0, 2 do
		shrine:part("ShrineStep", Vector3.new(10, 0.5, 1.2), Vector3.new(0, 0.25 + k * 0.5, -4.6 + k * 1.2 - 3.6), STONE, M.Slate)
	end
	shrine:part("Honden", Vector3.new(16, 8, 10), Vector3.new(0, 5.5, 10), PLASTER)
	for _, x in ipairs({ -8, -2.8, 2.8, 8 }) do
		shrine:part("ShrinePillar", Vector3.new(8, 0.9, 0.9), vertical(Vector3.new(x, 5.5, 4.4)), VERMILION, nil, { shape = "Cylinder" })
	end
	shrine:decor("ShrineDoor", Vector3.new(6, 6, 0.2), Vector3.new(0, 4.5, 4.9), WOOD_DARK)
	roof(shrine:within(CFrame.new(0, 0, 9)), 18, 13, 9.5, 5, Color3.fromRGB(70, 116, 100))
	shrine:decor("Shimenawa", Vector3.new(12, 0.8, 0.8), vertical(Vector3.new(0, 9.4, 4)) * CFrame.Angles(0, 0, math.rad(-90)),
		Color3.fromRGB(216, 190, 130), nil, { shape = "Cylinder" })
	shrine:part("OfferingBox", Vector3.new(4, 2, 2), Vector3.new(0, 2.5, 2.6), WOOD, M.Wood)
	local bell = shrine:decor("ShrineBell", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 8.2, 3.4), GOLD, M.Metal, { shape = "Ball" })
	bell:SetAttribute("PromptText", "Pray")
	bell:SetAttribute("PromptObject", "The Shrine · rest and heal")
	shrine:decor("BellRope", Vector3.new(0.3, 5, 0.3), Vector3.new(0, 5.4, 3.4), CRIMSON, M.Fabric)
	for _, x in ipairs({ -9, 9 }) do
		stoneLantern(shrine:within(CFrame.new(x, 1.5, -2)))
		-- A lion-dog on guard either side of the steps.
		local dog = shrine:within(CFrame.new(x * 0.62, 1.5, -4))
		dog:part("KomainuBase", Vector3.new(2.2, 1.2, 2.2), Vector3.new(0, 0.6, 0), STONE_DARK, M.Slate)
		dog:decor("KomainuBody", Vector3.new(1.6, 1.8, 1.4), Vector3.new(0, 2.1, 0.2), STONE, M.Slate)
		dog:decor("KomainuHead", Vector3.new(1.5, 1.3, 1.3), Vector3.new(0, 3.5, -0.3), STONE, M.Slate)
		dog:decor("KomainuMane", Vector3.new(1.9, 0.6, 1.5), Vector3.new(0, 3, -0.1), STONE_DARK, M.Slate)
	end
	-- A koi pond beside the shrine.
	local pond = root:within(CFrame.new(28, 0, -124))
	pond:decor("PondWater", Vector3.new(16, 0.2, 10), Vector3.new(0, 0.1, 0), WATER, nil, { transparency = 0.15 })
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		pond:part("PondStone", Vector3.new(2.4, 1, 1.6), CFrame.new(math.cos(a) * 8.4, 0.5, math.sin(a) * 5.4) * CFrame.Angles(0, -a, 0),
			STONE, M.Slate)
	end
	for k, c in ipairs({ Color3.fromRGB(250, 140, 60), PLASTER, Color3.fromRGB(230, 80, 60) }) do
		pond:decor("Koi", Vector3.new(1.2, 0.2, 0.4), CFrame.new(-3 + k * 2, 0.22, (k % 2) * 2 - 1) * CFrame.Angles(0, k, 0), c)
	end

	-- Houses down both sides of the street, turned to face it.
	local rows = {
		{ z = -236, w = 12, st = 1 }, { z = -221, w = 11, st = 2, sign = "SOBA" }, { z = -206, w = 12, st = 1 },
		{ z = -134, w = 11, st = 2 }, { z = -119, w = 12, st = 1 },
	}
	for i, r in ipairs(rows) do
		house(root:within(CFrame.new(-14, 0, r.z) * CFrame.Angles(0, math.rad(-90), 0)), r.w, 12, r.st, i,
			if i == 2 then r.sign else nil)
		if not (r.z > -140 and r.z < -100) then
			house(root:within(CFrame.new(14, 0, r.z) * CFrame.Angles(0, math.rad(90), 0)), r.w, 12, r.st, i + 3,
				if i == 3 then "TEA" else nil)
		end
	end
	-- The trader's stall in front of the east row: a counter under a cloth awning, crates of
	-- goods, the banner. Its counter opens the market.
	local stall = root:within(CFrame.new(S.Merchant.X, 0, S.Merchant.Z) * CFrame.Angles(0, math.rad(90), 0))
	stall:part("StallCounter", Vector3.new(8, 3.2, 2), Vector3.new(0, 1.6, 0), WOOD, M.WoodPlanks)
	stall:decor("StallTop", Vector3.new(8.4, 0.3, 2.4), Vector3.new(0, 3.35, 0), WOOD_DARK)
	for _, x in ipairs({ -3.8, 3.8 }) do
		stall:part("StallPost", Vector3.new(0.4, 7, 0.4), Vector3.new(x, 3.5, 1.6), WOOD_DARK)
	end
	stall:decor("StallAwning", Vector3.new(9, 0.25, 4.4), CFrame.new(0, 7, 0.6) * CFrame.Angles(math.rad(-12), 0, 0), Color3.fromRGB(46, 70, 130),
		M.Fabric)
	board(stall, "TRADER", Kit.Look(Vector3.new(0, 8.4, -0.2), Vector3.new(0, 8.4, -6)), 5, 1.2, Color3.fromRGB(46, 70, 130), CREAM)
	for k = 0, 2 do
		stall:decor("Goods", Vector3.new(1.4, 1, 1.4), Vector3.new(-2.4 + k * 2.4, 4, 0), CONTAINERS[k + 1])
	end
	local counter = stall:decor("HanamiCounter", Vector3.new(6, 0.08, 3), Vector3.new(0, 0.05, -2.6), Color3.fromRGB(46, 70, 130), M.Fabric)
	counter:SetAttribute("PromptText", "Open Shop")
	counter:SetAttribute("PromptObject", "Trader · guns & gear")
	counter:SetAttribute("OpenPanel", "Market")

	-- The pagoda, east of the square.
	pagoda(root:within(CFrame.new(S.Pagoda.X, 0, S.Pagoda.Z)))

	-- The teahouse, west of the square: a red parasol and benches out front, and a roof
	-- terrace up the stair at the back with the best view of the tree.
	local tea = root:within(CFrame.new(S.Teahouse.X, 0, S.Teahouse.Z) * CFrame.Angles(0, math.rad(-90), 0))
	local before = snapshot(folder)
	terraceHouse(tea, 14, 12, 7, "TEAHOUSE")
	flatten(folder, before)
	local front = root:within(CFrame.new(S.Teahouse.X + 8, 0, S.Teahouse.Z))
	front:decor("Parasol", Vector3.new(0.3, 9, 9), CFrame.new(0, 7, 0) * CFrame.Angles(0, 0, math.rad(90)), VERMILION, M.Fabric,
		{ shape = "Cylinder" })
	front:decor("ParasolPole", Vector3.new(0.25, 7, 0.25), Vector3.new(0, 3.5, 0), WOOD_DARK)
	for _, z in ipairs({ -3, 3 }) do
		front:part("TeaBench", Vector3.new(2, 1.2, 5), Vector3.new(0, 0.6, z), WOOD, M.Wood)
		front:decor("TeaCloth", Vector3.new(2.06, 0.08, 5.06), Vector3.new(0, 1.24, z), CRIMSON, M.Fabric)
	end

	-- Cherry trees and stone lanterns along the street, and round the edge of the village.
	for z = -246, -100, 22 do
		if z < -196 or z > -140 then
			for _, x in ipairs({ -8.6, 8.6 }) do
				stoneLantern(root:within(CFrame.new(x, 0, z + 6)), 0.8)
			end
		end
	end
	local trees = {
		{ -40, -238 }, { 40, -240 }, { -78, -226 }, { 80, -214 }, { -36, -178 }, { 44, -186 }, { -80, -160 },
		{ 86, -170 }, { -44, -120 }, { 46, -108 }, { -88, -110 }, { 88, -124 }, { -24, -100 }, { 64, -232 },
	}
	for i, t in ipairs(trees) do
		sakura(root:within(CFrame.new(t[1], 0, t[2])), i * 13, 1 + (i % 3) * 0.12)
	end
	-- A well and a cart in the square's corner.
	local well = root:within(CFrame.new(-26, 0, -148))
	well:part("Well", Vector3.new(2.6, 3.6, 3.6), vertical(Vector3.new(0, 1.3, 0)), STONE, M.Slate, { shape = "Cylinder" })
	well:decor("WellWater", Vector3.new(0.1, 3, 3), vertical(Vector3.new(0, 2.4, 0)), WATER, nil, { shape = "Cylinder" })
	for _, x in ipairs({ -1.6, 1.6 }) do
		well:decor("WellPost", Vector3.new(0.3, 4, 0.3), Vector3.new(x, 4, 0), WOOD_DARK)
	end
	well:decor("WellRoof", Vector3.new(4.6, 0.4, 3), Vector3.new(0, 6.1, 0), ROOF)
	local cart = root:within(CFrame.new(26, 0, -148) * CFrame.Angles(0, 0.4, 0))
	cart:part("Cart", Vector3.new(3.4, 1, 5), Vector3.new(0, 1.8, 0), WOOD, M.WoodPlanks)
	for _, x in ipairs({ -2, 2 }) do
		cart:decor("CartWheel", Vector3.new(0.3, 2.6, 2.6), vertical(Vector3.new(x, 1.3, 0)) * CFrame.Angles(0, 0, math.rad(-90)),
			WOOD_DARK, nil, { shape = "Cylinder" })
	end
	cart:decor("Hay", Vector3.new(3, 1.2, 4), Vector3.new(0, 2.8, 0), Color3.fromRGB(214, 190, 120), M.Grass)
end

local function bambooHollow(root: Kit.Builder)
	local S = HanamiConfig.Sites
	patch(root, "Ground", -258, -98, -258, -90, 0.005, GRASS_DARK, M.Grass)
	-- A dirt path from the village's west lane to the camp, and on to the waterfall.
	for _, seg in ipairs({ { Vector3.new(-98, 0, -170), Vector3.new(-150, 0, -176) }, { Vector3.new(-150, 0, -176), Vector3.new(-178, 0, -176) },
		{ Vector3.new(-178, 0, -176), Vector3.new(-220, 0, -130) }, { Vector3.new(-220, 0, -130), Vector3.new(-238, 0, -112) } }) do
		local cf, len = Kit.Span(seg[1] + Vector3.new(0, 0.06, 0), seg[2] + Vector3.new(0, 0.06, 0))
		root:decor("Trail", Vector3.new(6, 0.12, len + 6), cf, DIRT, M.Ground)
	end
	-- Bamboo everywhere off the path.
	local rng = Random.new(404)
	local placed = 0
	for _ = 1, 220 do
		local x, z = rng:NextNumber(-252, -104), rng:NextNumber(-252, -96)
		local p = Vector3.new(x, 0, z)
		local nearPath = (p - Vector3.new(-178, 0, -176)).Magnitude < 22 or (p - S.Waterfall).Magnitude < 20
			or (math.abs(z + 173) < 9 and x > -178) or (p - Vector3.new(-200, 0, -153)).Magnitude < 9
		if not nearPath and placed < 52 then
			bamboo(root:within(CFrame.new(p)), placed * 7 + 3, 6)
			if placed % 2 == 0 then
				root:decor("Fern", Vector3.new(2.6, 2.6, 2.6), p + Vector3.new(3, 0.1, -2), MOSS, nil, { shape = "Ball" })
			end
			placed += 1
		end
	end
	for i, at in ipairs({ { -130, -120 }, { -210, -240 }, { -240, -200 }, { -120, -230 }, { -160, -110 }, { -200, -100 } }) do
		rock(root:within(CFrame.new(at[1], 0, at[2])), 5 + (i % 3) * 2, i * 11)
	end
	-- The camp: three tents round a fire, crates, a lookout platform, and the posts where the
	-- villagers are tied.
	local camp = root:within(CFrame.new(S.Camp))
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2 + 0.5
		local tent = camp:within(CFrame.new(math.cos(a) * 11, 0, math.sin(a) * 11) * CFrame.Angles(0, -a + math.pi / 2, 0))
		for _, s in ipairs({ -1, 1 }) do
			tent:part("Tent", Vector3.new(5, 4, 2.6), CFrame.new(0, 2, s * 1.3) * CFrame.Angles(0, if s > 0 then 0 else math.pi, 0),
				Color3.fromRGB(150, 128, 96), M.Fabric, { shape = "Wedge" })
		end
		tent:decor("TentPole", Vector3.new(0.2, 4.4, 0.2), Vector3.new(0, 2.2, -2.6), WOOD_DARK)
	end
	camp:decor("FireLog", Vector3.new(3, 0.5, 0.5), CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0.6, 0), WOOD_DARK)
	camp:decor("FireLog", Vector3.new(3, 0.5, 0.5), CFrame.new(0, 0.3, 0) * CFrame.Angles(0, -0.6, 0), WOOD_DARK)
	camp:decor("Fire", Vector3.new(1.2, 1.6, 1.2), CFrame.new(0, 1, 0) * CFrame.Angles(0, 0.8, 0), Color3.fromRGB(255, 150, 60), M.Neon)
	camp:light("Point", Vector3.new(0, 2.5, 0), Color3.fromRGB(255, 160, 80), 1.6, 22)
	for k = 0, 2 do
		camp:part("Crate", Vector3.new(2.6, 2.6, 2.6), CFrame.new(-6 + k * 2.7, 1.3, 8) * CFrame.Angles(0, k * 0.3, 0), WOOD_LIGHT, M.WoodPlanks)
	end
	local lookout = camp:within(CFrame.new(-14, 0, -2))
	for _, x in ipairs({ -2, 2 }) do
		for _, z in ipairs({ -2, 2 }) do
			lookout:part("LookoutLeg", Vector3.new(0.6, 9, 0.6), Vector3.new(x, 4.5, z), WOOD_DARK)
		end
	end
	lookout:part("LookoutFloor", Vector3.new(5.6, 0.5, 5.6), Vector3.new(0, 9.2, 0), WOOD, M.WoodPlanks)
	ladder(lookout, Vector3.new(0, 0, -3.8), 10)
	for i, at in ipairs(HanamiConfig.Captives) do
		local post = root:within(CFrame.new(at))
		post:part("CaptivePost", Vector3.new(0.8, 6, 0.8), Vector3.new(0, 3, 1.4), WOOD_DARK)
		marker(post, "CaptiveSpot", Vector3.new(0, 0.5, 0), { Index = i })
	end
	-- The waterfall: a rock cliff at the valley's west edge, the fall, the pool, the stream
	-- down to the river, and a gap behind the water.
	local fall = root:within(CFrame.new(S.Waterfall))
	-- The cliff in three pieces, leaving a dry nook behind the falling water.
	fall:part("Cliff", Vector3.new(4, 30, 40), Vector3.new(-13, 15, 0), ROCK, M.Slate)
	for _, s in ipairs({ -1, 1 }) do
		fall:part("Cliff", Vector3.new(8, 30, 16), Vector3.new(-7, 15, s * 12), ROCK, M.Slate)
	end
	fall:part("Cliff", Vector3.new(8, 22, 8), Vector3.new(-7, 19, 0), ROCK, M.Slate)
	-- Fallen rock either side of the fall (not in front of it: the nook stays open).
	for _, k in ipairs({ -1, 1 }) do
		fall:part("CliffRock", Vector3.new(8, 14, 10), CFrame.new(-4, 7 + 6, k * 14) * CFrame.Angles(0.2 * k, 0.3, 0.1), ROCK_LIGHT, M.Slate)
	end
	fall:decor("Fall", Vector3.new(1, 26, 8), Vector3.new(-2.6, 13, 0), FOAM, nil, { transparency = 0.25 })
	fall:decor("FallMist", Vector3.new(6, 2, 12), Vector3.new(0, 1, 0), FOAM, nil, { transparency = 0.5 })
	fall:decor("Pool", Vector3.new(16, 0.3, 18), Vector3.new(6, 0.05, 0), WATER, nil, { transparency = 0.1 })
	-- The stream from the pool to the river.
	root:decor("Stream", Vector3.new(6, 0.3, 26), Vector3.new(-236, 0.05, -97), WATER, nil, { transparency = 0.1 })
	root:part("PlankBridge", Vector3.new(8, 0.6, 4), Vector3.new(-236, 0.5, -98), WOOD, M.WoodPlanks)
end

local function paddies(root: Kit.Builder)
	local S = HanamiConfig.Sites
	-- Flooded fields between raised dikes.
	for _, x0 in ipairs({ 104, 154, 204 }) do
		for _, z0 in ipairs({ -252, -212, -132 }) do
			if x0 == 154 and z0 == -212 then
				continue      -- the farmyard is here
			end
			local field = root:within(CFrame.new(x0 + 22, 0, z0 + 18))
			field:decor("Paddy", Vector3.new(42, 0.12, 34), Vector3.new(0, 0.07, 0), Color3.fromRGB(118, 176, 172), nil, { reflectance = 0.15 })
			for r = -14, 14, 3.5 do
				field:decor("Sprouts", Vector3.new(40, 0.5, 0.5), Vector3.new(0, 0.35, r), Color3.fromRGB(122, 196, 92), M.Grass)
			end
		end
	end
	for _, x in ipairs({ 102, 152, 202, 252 }) do
		root:part("Dike", Vector3.new(3, 0.8, 166), Vector3.new(x, 0.4, -173), DIRT, M.Ground)
	end
	for _, z in ipairs({ -254, -214, -174, -134, -94 }) do
		root:part("Dike", Vector3.new(156, 0.8, 3), Vector3.new(178, 0.4, z), DIRT, M.Ground)
	end
	-- The farmhouse the raiders come for: a thatched roof, a porch, a haystack and a scarecrow.
	local farm = root:within(CFrame.new(S.Farmhouse.X, 0, S.Farmhouse.Z + 10) * CFrame.Angles(0, math.pi, 0))
	patch(root, "Farmyard", S.Farmhouse.X - 22, S.Farmhouse.X + 22, S.Farmhouse.Z - 16, S.Farmhouse.Z + 16, 0.9, DIRT, M.Ground)
	root:part("FarmyardFloor", Vector3.new(44, 0.9, 32), Vector3.new(S.Farmhouse.X, 0.45, S.Farmhouse.Z), DIRT, M.Ground)
	local fb = farm:within(CFrame.new(0, 0.9, 0))
	fb:part("Farmhouse", Vector3.new(18, 8, 12), Vector3.new(0, 4, 6), WOOD_LIGHT, M.WoodPlanks)
	fb:decor("FarmDoor", Vector3.new(3.4, 5.4, 0.2), Vector3.new(0, 2.7, -0.08), WOOD_DARK)
	for _, x in ipairs({ -5.5, 5.5 }) do
		fb:decor("FarmWindow", Vector3.new(2.6, 2, 0.2), Vector3.new(x, 4.6, -0.08), PAPER)
	end
	roof(fb:within(CFrame.new(0, 0, 6)), 18, 12, 8, 6, Color3.fromRGB(196, 168, 108))
	for _, x in ipairs({ -8, 8 }) do
		fb:part("PorchPost", Vector3.new(0.5, 7, 0.5), Vector3.new(x, 3.5, -3.6), WOOD_DARK)
	end
	fb:decor("Porch", Vector3.new(18, 0.4, 4), CFrame.new(0, 7.2, -2) * CFrame.Angles(math.rad(10), 0, 0), Color3.fromRGB(196, 168, 108))
	local yard = root:within(CFrame.new(S.Farmhouse))
	yard:part("Haystack", Vector3.new(6, 5, 6), Vector3.new(-14, 3.3, 6), Color3.fromRGB(222, 196, 120), M.Grass, { shape = "Ball" })
	yard:part("Haystack", Vector3.new(4.4, 3.8, 4.4), Vector3.new(-17, 2.7, 1), Color3.fromRGB(214, 186, 110), M.Grass, { shape = "Ball" })
	yard:decor("ScarecrowPole", Vector3.new(0.3, 6, 0.3), Vector3.new(14, 3.9, -6), WOOD_DARK)
	yard:decor("ScarecrowArms", Vector3.new(4, 0.3, 0.3), Vector3.new(14, 5.6, -6), WOOD_DARK)
	yard:decor("ScarecrowCoat", Vector3.new(2, 2.4, 0.8), Vector3.new(14, 4.6, -6), Color3.fromRGB(96, 110, 150), M.Fabric)
	yard:decor("ScarecrowHat", Vector3.new(0.4, 3, 3), vertical(Vector3.new(14, 7.2, -6)), Color3.fromRGB(214, 190, 120), nil, { shape = "Cylinder" })
	-- Sandbag walls the villagers threw up: cover for the raid.
	for k, at in ipairs({ { -9, 13.5 }, { 9, 13.5 }, { 19, 8 }, { -19, 9 } }) do
		yard:part("Sandbags", Vector3.new(6, 2.4, 1.6), CFrame.new(at[1], 2.1, at[2]) * CFrame.Angles(0, k * 0.5, 0),
			Color3.fromRGB(196, 176, 130), M.Fabric)
	end
	marker(root, "RaidSite", S.Farmhouse + Vector3.new(0, 1.4, 15))
	sakura(root:within(CFrame.new(S.Farmhouse.X + 20, 0.9, S.Farmhouse.Z + 12)), 991, 0.9)
end

local function river(root: Kit.Builder)
	local R = HanamiConfig.RIVER
	local H = HanamiConfig.HALF
	local S = HanamiConfig.Sites
	ground(root, "RiverBed", -H, H, R.z0, R.z1, -R.depth, Color3.fromRGB(110, 120, 116), M.Ground)
	root:decor("River", Vector3.new(H * 2, 0.4, R.z1 - R.z0), Vector3.new(0, -1.2, (R.z0 + R.z1) / 2), WATER, nil,
		{ transparency = 0.2, reflectance = 0.1 })
	-- Stones along both banks, broken where a bridge lands.
	local rng = Random.new(31)
	for x = -H + 6, H - 6, 9 do
		local nearBridge = math.abs(x) < 10 or math.abs(x - S.WestBridge.X) < 9 or math.abs(x - S.EastBridge.X) < 9
		if not nearBridge then
			for _, z in ipairs({ R.z0 + 0.8, R.z1 - 0.8 }) do
				root:decor("BankStone", Vector3.new(rng:NextNumber(3, 5), rng:NextNumber(1, 1.8), 2),
					CFrame.new(x + rng:NextNumber(-2, 2), -0.4, z) * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0), STONE_DARK, M.Slate)
			end
		end
	end
	-- Steps down into the water every so often, so a swimmer can climb out.
	for _, x in ipairs({ -210, -90, 80, 230 }) do
		for _, side in ipairs({ -1, 1 }) do
			local z = if side < 0 then R.z0 + 1.5 else R.z1 - 1.5
			root:part("BankStep", Vector3.new(6, 1.6, 3), Vector3.new(x, -1.6, z), STONE, M.Slate)
		end
	end
	-- The red arched bridge north out of the village: a curved deck, red rails, gold caps.
	local span = (R.z1 - R.z0) + 14
	local bridge = root:within(CFrame.new(S.RedBridge))
	local n = 8
	for k = 0, n - 1 do
		local t0, t1 = k / n, (k + 1) / n
		local function at(t: number): Vector3
			return Vector3.new(0, 0.4 + math.sin(t * math.pi) * 3.4, -span / 2 + t * span)
		end
		local cf, len = Kit.Span(at(t0), at(t1))
		bridge:part("BridgeDeck", Vector3.new(10, 0.8, len + 0.3), cf, WOOD, M.WoodPlanks)
		for _, s in ipairs({ -1, 1 }) do
			bridge:decor("BridgeRail", Vector3.new(0.4, 0.4, len + 0.3), cf * CFrame.new(s * 4.8, 2.4, 0), VERMILION)
			bridge:decor("BridgePost", Vector3.new(0.5, 2.6, 0.5), cf * CFrame.new(s * 4.8, 1.3, -len / 2), VERMILION)
			bridge:decor("PostCap", Vector3.new(0.7, 0.7, 0.7), cf * CFrame.new(s * 4.8, 2.8, -len / 2), GOLD, M.Metal, { shape = "Ball" })
		end
	end
	-- The west bridge (planks and rope) and the east bridge (stone, for the foundry's carts).
	local west = root:within(CFrame.new(S.WestBridge))
	west:part("PlankBridge", Vector3.new(8, 0.6, span), Vector3.new(0, 0.2, 0), WOOD_LIGHT, M.WoodPlanks)
	for _, s in ipairs({ -1, 1 }) do
		west:decor("Rope", Vector3.new(0.18, 0.18, span), Vector3.new(s * 3.8, 2.6, 0), Color3.fromRGB(196, 170, 120))
		for z = -span / 2, span / 2, span / 4 do
			west:decor("RopePost", Vector3.new(0.4, 2.8, 0.4), Vector3.new(s * 3.8, 1.4, z), WOOD_DARK)
		end
	end
	local east = root:within(CFrame.new(S.EastBridge))
	east:part("StoneBridge", Vector3.new(12, 1, span), Vector3.new(0, 0, 0), STONE, M.Slate)
	for _, s in ipairs({ -1, 1 }) do
		east:part("BridgeWall", Vector3.new(0.8, 1.6, span), Vector3.new(s * 5.6, 1.3, 0), STONE_DARK, M.Slate)
	end
end

local function lanternRow(root: Kit.Builder, folder: Instance)
	local S = HanamiConfig.Sites
	-- The streets: the main street east-west, two lanes north-south.
	patch(root, "RowStreet", -250, -40, 14, 26, 0, PATH_DARK, M.Slate)
	for _, x in ipairs({ -104, -184 }) do
		patch(root, "RowLane", x - 5, x + 5, -58, 110, 0.01, PATH_DARK, M.Slate)
	end
	-- The gate arch: two dark posts, a beam with LANTERN ROW on it, lanterns hanging under.
	local gate = root:within(CFrame.new(S.LanternGate) * CFrame.Angles(0, math.rad(90), 0))
	for _, x in ipairs({ -7, 7 }) do
		gate:part("GatePost", Vector3.new(1.4, 14, 1.4), Vector3.new(x, 7, 0), WOOD_DARK)
	end
	gate:decor("GateBeam", Vector3.new(18, 1.4, 1.6), Vector3.new(0, 14.2, 0), WOOD_DARK)
	gate:decor("GateRoof", Vector3.new(20, 0.8, 3.2), Vector3.new(0, 15.3, 0), ROOF, M.Slate)
	board(gate, "LANTERN ROW", Kit.Look(Vector3.new(0, 12.4, -0.95), Vector3.new(0, 12.4, -8)), 10, 1.8, CRIMSON, CREAM)
	board(gate, "LANTERN ROW", Kit.Look(Vector3.new(0, 12.4, 0.95), Vector3.new(0, 12.4, 8)), 10, 1.8, CRIMSON, CREAM)
	for _, x in ipairs({ -4.5, 0, 4.5 }) do
		lantern(gate, Vector3.new(x, 11.2, 0), LANTERN_RED, 1.1)
	end
	-- Shophouses on both sides of the main street and the lanes. Names over some of them.
	local NAMES = { "RAMEN", "SAKE", "PACHINKO", "NOODLES", "KARAOKE", "PAWN", "DUMPLINGS", "TEA", "IZAKAYA", "ARCADE" }
	local count = 0
	local function shop(x: number, z: number, yaw: number, w: number, storeys: number, terrace: boolean?)
		count += 1
		local b = root:within(CFrame.new(x, 0, z) * CFrame.Angles(0, math.rad(yaw), 0))
		local name = if count % 2 == 0 then NAMES[(count // 2) % #NAMES + 1] else nil
		if terrace then
			local before = snapshot(folder)
			terraceHouse(b, w, 12, count, name)
			flatten(folder, before)
		else
			house(b, w, 12, storeys, count, name)
		end
	end
	-- North side of the main street (faces south), south side (faces north).
	for i, x in ipairs({ -60, -76, -128, -144, -160, -208, -224, -240 }) do
		shop(x, 32, 0, 14, if i % 3 == 0 then 1 else 2, x == -160)
		shop(x, 8, 180, 14, if i % 2 == 0 then 1 else 2, false)
	end
	-- Along the lanes, facing in.
	for _, z in ipairs({ -40, -24, 52, 68, 86, 102 }) do
		shop(-112, z, -90, 12, 2, z == 86)
		shop(-96, z, 90, 12, if z % 3 == 0 then 1 else 2, false)
		shop(-192, z, -90, 12, 2, false)
		shop(-176, z, 90, 12, 2, z == 86)
	end
	-- Lanterns strung across the main street.
	for x = -236, -50, 16 do
		lanternString(root, Vector3.new(x, 8.6, 8.4), Vector3.new(x, 8.6, 31.6), 3)
	end
	for _, lx in ipairs({ -104, -184 }) do
		for z = -48, 104, 18 do
			if math.abs(z - 20) > 12 then
				lanternString(root, Vector3.new(lx - 7.6, 8.6, z), Vector3.new(lx + 7.6, 8.6, z), 2)
			end
		end
	end
	-- Barrels and crates in the side streets: cover.
	for k, at in ipairs({ { -88, 20 }, { -132, 22 }, { -170, 14 }, { -200, 24 }, { -104, -10 }, { -104, 70 }, { -184, -14 }, { -184, 60 } }) do
		local c = root:within(CFrame.new(at[1], 0, at[2]) * CFrame.Angles(0, k, 0))
		c:part("Crate", Vector3.new(3, 3, 3), Vector3.new(0, 1.5, 0), WOOD_LIGHT, M.WoodPlanks)
		c:part("Barrel", Vector3.new(3, 2, 2), vertical(Vector3.new(2.6, 1.5, 0.4)), WOOD, M.Wood, { shape = "Cylinder" })
	end
end

local function crossroads(root: Kit.Builder)
	local S = HanamiConfig.Sites
	-- The road from the red bridge north to the foot of the stair.
	patch(root, "KeepRoad", -7, 7, -62, 64, 0, PATH, M.Slate)
	-- A Kurogane checkpoint across it: barricades and a black banner.
	for _, x in ipairs({ -10, 10 }) do
		root:part("Barricade", Vector3.new(8, 3, 1.4), Vector3.new(x, 1.5, 0), KURO, M.Wood)
		root:decor("BarricadeStripe", Vector3.new(8.1, 0.5, 1.5), Vector3.new(x, 2.4, 0), CRIMSON)
	end
	local tower = root:within(CFrame.new(24, 0, 10))
	for _, x in ipairs({ -2.4, 2.4 }) do
		for _, z in ipairs({ -2.4, 2.4 }) do
			tower:part("WatchLeg", Vector3.new(0.7, 12, 0.7), Vector3.new(x, 6, z), WOOD_DARK)
		end
	end
	tower:part("WatchFloor", Vector3.new(6.4, 0.5, 6.4), Vector3.new(0, 12.2, 0), WOOD, M.WoodPlanks)
	tower:decor("WatchRoof", Vector3.new(7.6, 0.5, 7.6), Vector3.new(0, 16, 0), ROOF)
	for _, x in ipairs({ -3, 3 }) do
		tower:decor("WatchRoofPost", Vector3.new(0.3, 3.6, 0.3), Vector3.new(x, 14.2, -3), WOOD_DARK)
		tower:decor("WatchRoofPost", Vector3.new(0.3, 3.6, 0.3), Vector3.new(x, 14.2, 3), WOOD_DARK)
	end
	ladder(tower, Vector3.new(0, 0, -4.2), 12)
	-- Sakura either side of the road.
	for i, at in ipairs({ { -22, -40 }, { 20, -46 }, { -24, 40 }, { 26, 46 } }) do
		sakura(root:within(CFrame.new(at[1], 0, at[2])), 500 + i, 1.1)
	end
	marker(root, "StairFoot", S.StairFoot + Vector3.new(0, 0.5, 0))
end

local function ironworks(root: Kit.Builder)
	local S = HanamiConfig.Sites
	patch(root, "Yard", 40, 254, -60, 112, 0.01, Color3.fromRGB(150, 146, 140), M.Concrete)
	-- The yard fence along the west side, open at the gate.
	for _, z in ipairs({ -32, 72 }) do
		root:part("YardFence", Vector3.new(1, 8, if z < 0 then 56 else 80), Vector3.new(40, 4, if z < 0 then -32 else 72), STEEL,
			M.DiamondPlate)
	end
	local gate = root:within(CFrame.new(S.IronGate) * CFrame.Angles(0, math.rad(-90), 0))
	for _, x in ipairs({ -8, 8 }) do
		gate:part("GatePillar", Vector3.new(2, 12, 2), Vector3.new(x, 6, 0), KURO)
	end
	gate:decor("GateBeam", Vector3.new(18, 1.6, 1.6), Vector3.new(0, 12.4, 0), KURO)
	board(gate, "KUROGANE IRONWORKS", Kit.Look(Vector3.new(0, 10.4, -1.0), Vector3.new(0, 10.4, -8)), 14, 1.8, KURO, Color3.fromRGB(255, 120, 80))
	-- Sheds.
	warehouse(root:within(CFrame.new(96, 0, 66)), 30, 30, 14, Color3.fromRGB(140, 150, 160), "01")
	warehouse(root:within(CFrame.new(210, 0, 82)), 36, 26, 16, Color3.fromRGB(176, 122, 92), "02")
	warehouse(root:within(CFrame.new(100, 0, -38) * CFrame.Angles(0, math.pi, 0)), 26, 18, 12, Color3.fromRGB(120, 140, 128), "03")
	-- The foundry: a tall black hall, its chimney, and the furnace yard in front where the
	-- Foreman works.
	local foundry = root:within(CFrame.new(S.Foundry.X, 0, S.Foundry.Z + 26))
	foundry:part("Foundry", Vector3.new(40, 22, 22), Vector3.new(0, 11, 11), KURO, M.CorrodedMetal)
	foundry:decor("FoundryMouth", Vector3.new(12, 10, 0.4), Vector3.new(0, 5, -0.1), Color3.fromRGB(255, 120, 40), M.Neon)
	roof(foundry:within(CFrame.new(0, 0, 11)), 38, 20, 22, 5, Color3.fromRGB(44, 46, 54))
	foundry:part("Chimney", Vector3.new(48, 6, 6), vertical(Vector3.new(14, 24, 16)), Color3.fromRGB(150, 74, 56), M.Brick, { shape = "Cylinder" })
	foundry:decor("ChimneyBand", Vector3.new(1.2, 6.4, 6.4), vertical(Vector3.new(14, 44, 16)), KURO, nil, { shape = "Cylinder" })
	local smoke = foundry:decor("Smoke", Vector3.new(1, 1, 1), Vector3.new(14, 48.5, 16), KURO, nil, { transparency = 1 })
	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/smoke_main.dds"
	emitter.Color = ColorSequence.new(Color3.fromRGB(90, 90, 96), Color3.fromRGB(190, 186, 190))
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 4), NumberSequenceKeypoint.new(1, 14) })
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1) })
	emitter.Lifetime = NumberRange.new(6, 9)
	emitter.Rate = 3
	emitter.Speed = NumberRange.new(4, 6)
	emitter.Acceleration = Vector3.new(2, 1, 0)
	emitter.Parent = smoke
	local yard = root:within(CFrame.new(S.Foundry))
	yard:decor("YardFloor", Vector3.new(44, 0.1, 34), Vector3.new(0, 0.06, 0), Color3.fromRGB(110, 106, 104), M.Concrete)
	for _, x in ipairs({ -14, 14 }) do
		yard:part("Crucible", Vector3.new(5, 4.4, 4.4), vertical(Vector3.new(x, 2.5, 6)), IRON, M.Metal, { shape = "Cylinder" })
		yard:decor("Molten", Vector3.new(0.2, 3.6, 3.6), vertical(Vector3.new(x, 5, 6)), Color3.fromRGB(255, 140, 40), M.Neon, { shape = "Cylinder" })
	end
	for k, at in ipairs({ { -18, -10 }, { 18, -10 }, { 0, -14 } }) do
		yard:part("IngotStack", Vector3.new(4, 2.4, 2.6), CFrame.new(at[1], 1.2, at[2]) * CFrame.Angles(0, k * 0.4, 0), STEEL, M.Metal)
	end
	marker(yard, "ForemanSpot", Vector3.new(0, 0.5, 2))
	for _, at in ipairs({ { -20, 4 }, { 20, 4 }, { 0, -16 } }) do
		marker(yard, "ForemanAddSpot", Vector3.new(at[1], 0.5, at[2]))
	end
	-- Containers stacked by the dock, two high where the stairs reach.
	for k, spec in ipairs({ { 170, -36, 0 }, { 170, -36, 1 }, { 180, -36, 0 }, { 222, -40, 0 }, { 232, -40, 0 }, { 222, -40, 1 },
		{ 244, -2, 0 }, { 150, -8, 0 } }) do
		container(root:within(CFrame.new(spec[1], spec[3] * 8.6, spec[2])), CONTAINERS[k % #CONTAINERS + 1])
	end
	local stairCf, stairLen = Kit.Span(Vector3.new(180, 0.6, -10), Vector3.new(180, 8.9, -26))
	root:part("ContainerStair", Vector3.new(4, 0.6, stairLen), stairCf, STEEL, M.DiamondPlate)
	-- The gantry crane over the dock: four legs, the beam, the trolley and its hook; a ladder
	-- up the near leg to the beam.
	local crane = root:within(CFrame.new(S.Crane))
	for _, x in ipairs({ -12, 12 }) do
		for _, z in ipairs({ -10, 10 }) do
			crane:part("CraneLeg", Vector3.new(1.6, 26, 1.6), Vector3.new(x, 13, z), Color3.fromRGB(236, 180, 50), M.Metal)
		end
		crane:decor("CraneBrace", Vector3.new(1, 1, 20), Vector3.new(x, 8, 0), Color3.fromRGB(236, 180, 50), M.Metal)
	end
	crane:part("CraneBeam", Vector3.new(28, 2, 4), Vector3.new(0, 26, -10), Color3.fromRGB(236, 180, 50), M.Metal)
	crane:part("CraneBeam", Vector3.new(28, 2, 4), Vector3.new(0, 26, 10), Color3.fromRGB(236, 180, 50), M.Metal)
	crane:part("CraneWalk", Vector3.new(4, 0.5, 20), Vector3.new(-4, 26.7, 0), STEEL, M.DiamondPlate)
	crane:decor("Trolley", Vector3.new(5, 3, 22), Vector3.new(4, 24, 0), KURO)
	crane:decor("CraneCable", Vector3.new(0.2, 12, 0.2), Vector3.new(4, 16.5, 0), KURO)
	crane:decor("Hook", Vector3.new(1.4, 1.6, 0.4), Vector3.new(4, 10, 0), STEEL, M.Metal)
	ladder(crane, Vector3.new(-14, 0, -10), 26, STEEL)
	crane:part("CraneLanding", Vector3.new(4, 0.5, 4), Vector3.new(-13, 26.7, -10), STEEL, M.DiamondPlate)
	-- The life of the yard: a rail line with a wagon, oil drums, pipes overhead between the
	-- sheds, yard lamps, a forklift, pallets of ingots.
	root:decor("Rail", Vector3.new(0.4, 0.3, 160), Vector3.new(66, 0.15, 26), STEEL, M.Metal)
	root:decor("Rail", Vector3.new(0.4, 0.3, 160), Vector3.new(70, 0.15, 26), STEEL, M.Metal)
	for z = -50, 104, 4 do
		root:decor("Sleeper", Vector3.new(6, 0.2, 0.8), Vector3.new(68, 0.1, z), WOOD_DARK)
	end
	local wagon = root:within(CFrame.new(68, 0, 0))
	wagon:part("Wagon", Vector3.new(6, 4, 14), Vector3.new(0, 3, 0), RUST, M.CorrodedMetal)
	for k = -1, 1 do
		wagon:decor("Ore", Vector3.new(4.6, 1.4, 4), CFrame.new(0, 5.3, k * 4) * CFrame.Angles(0.2 * k, k, 0.15), Color3.fromRGB(70, 66, 70), M.Slate)
	end
	for _, z in ipairs({ -4.5, 4.5 }) do
		for _, x in ipairs({ -2.2, 2.2 }) do
			wagon:decor("WagonWheel", Vector3.new(0.4, 2, 2), vertical(Vector3.new(x, 1, z)) * CFrame.Angles(0, 0, math.rad(-90)), KURO, nil,
				{ shape = "Cylinder" })
		end
	end
	for k, at in ipairs({ { 120, 48 }, { 124, 50 }, { 176, 28 }, { 240, 50 }, { 236, 54 }, { 150, -20 }, { 112, 8 }, { 228, 0 } }) do
		root:part("Drum", Vector3.new(3, 2.4, 2.4), vertical(Vector3.new(at[1], 1.5, at[2])), if k % 3 == 0 then CRIMSON else Color3.fromRGB(70, 100, 140),
			M.Metal, { shape = "Cylinder" })
	end
	for _, seg in ipairs({ { Vector3.new(111, 11, 80), Vector3.new(130, 11, 92) }, { Vector3.new(170, 13, 95), Vector3.new(192, 13, 95) } }) do
		local cf, len = Kit.Span(seg[1], seg[2])
		root:decor("Pipe", Vector3.new(1.4, 1.4, len), cf, RUST, M.Metal)
		root:decor("PipeSupport", Vector3.new(0.6, seg[1].Y, 0.6), Vector3.new((seg[1].X + seg[2].X) / 2, seg[1].Y / 2, (seg[1].Z + seg[2].Z) / 2), KURO)
	end
	for _, at in ipairs({ { 60, -10 }, { 60, 60 }, { 130, 30 }, { 200, 20 }, { 246, 70 } }) do
		root:decor("YardLampPost", Vector3.new(0.6, 14, 0.6), Vector3.new(at[1], 7, at[2]), KURO)
		root:decor("LampHead", Vector3.new(2.4, 0.6, 1.2), Vector3.new(at[1], 14, at[2]), Color3.fromRGB(255, 236, 190))
	end
	local lift = root:within(CFrame.new(134, 0, 12) * CFrame.Angles(0, 0.7, 0))
	lift:part("Forklift", Vector3.new(4, 3, 6), Vector3.new(0, 2, 0), Color3.fromRGB(236, 180, 50), M.Metal)
	lift:decor("ForkCage", Vector3.new(3.6, 3, 3), Vector3.new(0, 5, 0.8), KURO)
	lift:decor("ForkMast", Vector3.new(3, 6, 0.4), Vector3.new(0, 3, -3.2), KURO)
	for _, x in ipairs({ -1, 1 }) do
		lift:decor("Fork", Vector3.new(0.4, 0.2, 3), Vector3.new(x, 0.6, -4.8), STEEL, M.Metal)
	end
	for k, at in ipairs({ { 230, 30 }, { 236, 22 }, { 90, 20 } }) do
		local pal = root:within(CFrame.new(at[1], 0, at[2]) * CFrame.Angles(0, k, 0))
		pal:part("Pallet", Vector3.new(4, 0.6, 4), Vector3.new(0, 0.3, 0), WOOD_LIGHT, M.WoodPlanks)
		pal:part("Ingots", Vector3.new(3.4, 1.6, 3.4), Vector3.new(0, 1.4, 0), STEEL, M.Metal)
	end
	-- The dock: a pier out over the river, a boat tied up.
	local dock = root:within(CFrame.new(210, 0, -62))
	dock:part("Pier", Vector3.new(12, 0.8, 14), Vector3.new(0, -0.2, -6), WOOD, M.WoodPlanks)
	for _, x in ipairs({ -5.5, 5.5 }) do
		dock:decor("PierPost", Vector3.new(0.8, 5, 0.8), Vector3.new(x, -1.8, -12.6), WOOD_DARK)
	end
	dock:part("Boat", Vector3.new(6, 2.4, 14), Vector3.new(12, -0.8, -12), WOOD, M.WoodPlanks)
	dock:decor("BoatCabin", Vector3.new(4.4, 3, 5), Vector3.new(12, 1.9, -9), PLASTER)
end

local function keep(root: Kit.Builder)
	local S = HanamiConfig.Sites
	local P = HanamiConfig.PLATEAU
	local H = HanamiConfig.HALF
	-- The plateau and its cliff, rocks banked along the cliff's foot.
	ground(root, "Plateau", -H, H, 120, H, P - 0.6, ROCK, M.Slate, P + 5.4)
	ground(root, "PlateauTurf", -H, H, 120.6, H, P, GRASS_DARK, M.Grass, 0.6)
	local rng = Random.new(808)
	-- The cliff: a face of big faceted rocks, banked lower at its foot, broken by the stair.
	for x = -H + 10, H - 10, 13 do
		if math.abs(x) > 15 then
			local tall = rng:NextNumber(18, 30)
			root:part("CliffRock", Vector3.new(rng:NextNumber(14, 20), tall, rng:NextNumber(6, 10)),
				CFrame.new(x + rng:NextNumber(-3, 3), tall / 2 - 2, 117.5 + rng:NextNumber(-1, 1))
					* CFrame.Angles(rng:NextNumber(-0.25, 0.1), rng:NextNumber(-0.35, 0.35), rng:NextNumber(-0.15, 0.15)),
				if rng:NextNumber() < 0.5 then ROCK else ROCK_LIGHT, M.Slate)
			if rng:NextNumber() < 0.6 then
				root:part("CliffRock", Vector3.new(rng:NextNumber(8, 12), rng:NextNumber(5, 9), rng:NextNumber(6, 9)),
					CFrame.new(x + rng:NextNumber(-5, 5), 2, 112 + rng:NextNumber(-2, 2)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0.2),
					ROCK, M.Slate)
			end
			if rng:NextNumber() < 0.35 then
				sakura(root:within(CFrame.new(x, P, 124 + rng:NextNumber(0, 2))), math.floor(x), 0.9)
			end
		end
	end
	-- THE THOUSAND GATES: a stone stair straight up the cliff from the road, under a run of red
	-- torii, lanterns all the way up.
	local foot, top = S.StairFoot.Z, 120
	local len = top - foot
	root:part("Stair", Vector3.new(14, P, len), Vector3.new(0, P / 2, foot + len / 2), STONE, M.Slate, { shape = "Wedge" })
	for k = 0, math.floor(len / 2) - 1 do
		local z = foot + 1 + k * 2
		local y = (z - foot) / len * P
		root:decor("Step", Vector3.new(14, 0.3, 0.6), Vector3.new(0, y + 0.15, z), STONE_DARK, M.Slate)
	end
	for _, s in ipairs({ -1, 1 }) do
		root:part("StairWall", Vector3.new(1.6, P, len), CFrame.new(s * 7.8, P / 2 + 1, foot + len / 2), STONE_DARK, M.Slate, { shape = "Wedge" })
	end
	for k = 0, 8 do
		local z = foot + 4 + k * (len - 8) / 8
		local y = (z - foot) / len * P
		torii(root:within(CFrame.new(0, y, z)), 15, 9)
		if k % 2 == 0 then
			for _, s in ipairs({ -1, 1 }) do
				stoneLantern(root:within(CFrame.new(s * 9.8, y, z)), 0.7)
			end
		end
	end
	-- The landing at the top, and the gate in the front wall.
	patch(root, "Landing", -14, 14, 120, 140, P, PATH, M.Slate)
	-- The walls: the front (with the gate), the sides, the back. The corner towers.
	for _, s in ipairs({ -1, 1 }) do
		castleWall(root:within(CFrame.new(s * 72, P, 128)), 114, 16)
		castleWall(root:within(CFrame.new(s * 130, P, 192) * CFrame.Angles(0, math.rad(90), 0)), 124, 16)
		yagura(root:within(CFrame.new(s * 130, P, 128)))
		-- The gatehouse towers either side of the gate.
		local gt = root:within(CFrame.new(s * 12, P, 128))
		gt:part("GateTower", Vector3.new(8, 18, 8), Vector3.new(0, 9, 0), STONE, M.Slate)
		gt:part("GateTowerTop", Vector3.new(9, 6, 9), Vector3.new(0, 21, 0), PLASTER)
		gt:part("GateTowerRoof", Vector3.new(12, 1, 12), Vector3.new(0, 24.5, 0), ROOF, M.Slate)
	end
	castleWall(root:within(CFrame.new(0, P, 254)), 260, 16)
	-- Over the gate: a beam, a roof and the clan's crest.
	root:decor("GateBeam", Vector3.new(18, 2, 3), Vector3.new(0, P + 15, 128), KURO)
	roof(root:within(CFrame.new(0, 0, 128)), 18, 6, P + 16, 3)
	board(root, "KUROGANE", Kit.Look(Vector3.new(0, P + 13, 126.2), Vector3.new(0, P + 13, 110)), 9, 1.8, KURO, Color3.fromRGB(255, 200, 90))
	marker(root, "KeepGate", S.KeepGate + Vector3.new(0, 0.5, 0))
	-- The court: stone flags, raked gravel beds, cover -- lanterns, low walls, banners -- and
	-- the dais where the Shogun waits.
	local box = HanamiConfig.CourtBox
	patch(root, "Court", box.x0, box.x1, box.z0, box.z1, P, Color3.fromRGB(212, 204, 190), M.Slate)
	for _, gx in ipairs({ -50, 50 }) do
		patch(root, "Gravel", gx - 12, gx + 12, 160, 200, P + 0.02, Color3.fromRGB(232, 228, 218), M.Pebble)
		for k = 0, 4 do
			root:decor("Rake", Vector3.new(23, 0.06, 0.2), Vector3.new(gx, P + 0.12, 164 + k * 8), Color3.fromRGB(200, 196, 186))
		end
		rock(root:within(CFrame.new(gx + 4, P, 180)), 4, gx)
	end
	for _, at in ipairs({ { -30, 160 }, { 30, 160 }, { -30, 196 }, { 30, 196 } }) do
		stoneLantern(root:within(CFrame.new(at[1], P, at[2])), 1.3)
	end
	-- A paved way from the gate to the dais, banded in darker stone.
	patch(root, "CourtWay", -6, 6, 132, 210, P + 0.03, PATH_DARK, M.Slate)
	for z = 136, 206, 6 do
		root:decor("WayBand", Vector3.new(12, 0.08, 0.5), Vector3.new(0, P + 0.11, z), STONE_DARK)
	end
	-- Tall lanterns on posts down both sides, and big crimson drapes on the keep's face.
	for z = 142, 206, 16 do
		for _, x in ipairs({ -70, 70 }) do
			root:decor("LanternPost", Vector3.new(0.6, 9, 0.6), Vector3.new(x, P + 4.5, z), KURO)
			root:decor("LanternArm", Vector3.new(2.4, 0.4, 0.4), Vector3.new(x - math.sign(x) * 1, P + 8.8, z), KURO)
			lantern(root, Vector3.new(x - math.sign(x) * 2, P + 8.6, z), LANTERN_RED, 1.2)
		end
	end
	for _, x in ipairs({ -12, 12 }) do
		root:decor("KeepDrape", Vector3.new(5, 18, 0.3), Vector3.new(x, P + 19, 227.8), CRIMSON, M.Fabric)
		root:decor("KeepDrapeCrest", Vector3.new(3, 3, 0.34), CFrame.new(x, P + 24, 227.6) * CFrame.Angles(0, 0, math.rad(45)), KURO)
	end
	for _, at in ipairs({ { -16, 176 }, { 16, 176 } }) do
		root:part("CourtWall", Vector3.new(10, 3.2, 1.8), Vector3.new(at[1], P + 1.6, at[2]), STONE_DARK, M.Slate)
		root:decor("CourtWallCap", Vector3.new(10.4, 0.4, 2.2), Vector3.new(at[1], P + 3.4, at[2]), ROOF)
	end
	for _, x in ipairs({ -64, -40, 40, 64 }) do
		root:decor("BannerPole", Vector3.new(0.4, 16, 0.4), Vector3.new(x, P + 8, 214), KURO)
		root:decor("Banner", Vector3.new(3, 10, 0.2), Vector3.new(x, P + 10, 214.4), CRIMSON, M.Fabric)
		root:decor("BannerCrest", Vector3.new(1.8, 1.8, 0.24), CFrame.new(x, P + 12, 214.4) * CFrame.Angles(0, 0, math.rad(45)), KURO)
	end
	local dais = root:within(CFrame.new(S.Throne.X, P, S.Throne.Z))
	dais:part("Dais", Vector3.new(20, 1.6, 8), Vector3.new(0, 0.8, 0), STONE, M.Slate)
	dais:decor("DaisCloth", Vector3.new(16, 0.1, 6), Vector3.new(0, 1.65, 0), CRIMSON, M.Fabric)
	dais:part("Throne", Vector3.new(4, 6, 2), Vector3.new(0, 4.6, 2), KURO)
	dais:decor("ThroneCrest", Vector3.new(2.4, 2.4, 0.3), CFrame.new(0, 6.6, 0.9) * CFrame.Angles(0, 0, math.rad(45)), GOLD, M.Metal)
	marker(dais, "ShogunSpot", Vector3.new(0, 2.2, -4))
	marker(root, "CourtCentre", S.Court + Vector3.new(0, 0.5, 0))
	for _, at in ipairs({ { -56, 150 }, { 56, 150 }, { -60, 204 }, { 60, 204 }, { -20, 214 }, { 20, 214 } }) do
		marker(root, "CourtAddSpot", Vector3.new(at[1], P + 0.5, at[2]))
	end
	-- The keep itself: a battered stone base, three white tiers under dark roofs, gold fish on
	-- the ridge. The tallest thing in the valley.
	local k = root:within(CFrame.new(0, P, 240))
	k:part("KeepBase", Vector3.new(40, 10, 24), Vector3.new(0, 5, 0), STONE, M.Slate)
	local y = 10
	for tier, size in ipairs({ { 34, 11, 20 }, { 26, 9, 15 }, { 17, 8, 11 } }) do
		k:part("KeepTier", Vector3.new(size[1], size[2], size[3]), Vector3.new(0, y + size[2] / 2, 0), PLASTER)
		k:decor("KeepBand", Vector3.new(size[1] + 0.2, 1.2, size[3] + 0.2), Vector3.new(0, y + size[2] - 2, 0), KURO)
		for x = -size[1] / 2 + 3, size[1] / 2 - 3, 4.5 do
			k:decor("KeepWindow", Vector3.new(1.6, 2.2, 0.2), Vector3.new(x, y + size[2] / 2, -size[3] / 2 - 0.1), KURO)
		end
		y += size[2]
		k:part("KeepRoof", Vector3.new(size[1] + 7, 1.4, size[3] + 7), Vector3.new(0, y + 0.7, 0), ROOF, M.Slate)
		for _, sx in ipairs({ -1, 1 }) do
			for _, sz in ipairs({ -1, 1 }) do
				k:decor("KeepHorn", Vector3.new(2, 0.7, 2),
					CFrame.new(sx * (size[1] + 7) / 2, y + 1.5, sz * (size[3] + 7) / 2) * CFrame.Angles(sz * math.rad(18), math.rad(45), sx * math.rad(-18)),
					ROOF_EDGE)
			end
		end
		y += 1.4
		if tier == 3 then
			roof(k:within(CFrame.new(0, 0, 0)), size[1] - 2, size[3] - 1, y, 5)
			for _, sx in ipairs({ -1, 1 }) do
				k:decor("Shachihoko", Vector3.new(1.2, 2.6, 1.6), CFrame.new(sx * (size[1] / 2 + 1.4), y + 6.2, 0) * CFrame.Angles(0, 0, sx * math.rad(-15)),
					GOLD, M.Metal)
			end
		end
	end
	-- Sakura inside the walls.
	for i, at in ipairs({ { -100, 150 }, { 100, 150 }, { -104, 236 }, { 104, 236 }, { -86, 200 }, { 88, 196 } }) do
		sakura(root:within(CFrame.new(at[1], P, at[2])), 900 + i, 1.2)
	end
end

--- Build HANAMI VALLEY into `parent`, centred on `centre`.
function Valley.Build(parent: Instance, centre: Vector3)
	local root = Kit.new(parent, CFrame.new(centre))
	local H = HanamiConfig.HALF
	local R = HanamiConfig.RIVER

	-- The valley's look while you are in it (ArenaMood.client reads these).
	parent:SetAttribute("ZoneCentre", centre + Vector3.new(0, 70, 0))
	parent:SetAttribute("ZoneHalf", Vector3.new(H + 30, 150, H + 30))
	for group, values in pairs(Valley.Look) do
		for property, value in pairs(values) do
			parent:SetAttribute(("Look_%s_%s"):format(group, property), value)
		end
	end

	-- The valley floor either side of the river.
	ground(root, "Ground", -H, H, -H, R.z0, 0, GRASS)
	ground(root, "Ground", -H, H, R.z1, 120, 0, GRASS)

	hanamura(root, parent)
	bambooHollow(root)
	paddies(root)
	river(root)
	lanternRow(root, parent)
	crossroads(root)
	ironworks(root)
	keep(root)

	-- The valley's edges: invisible walls, and a ring of distant blossom hills to look at.
	Kit.Bounds(root, H - 2, H - 2, 220)
	-- Beyond the walls: a ring of faceted mountains, blossom on their lower slopes and the
	-- odd snowy peak, so the valley sits in a bowl rather than on a table.
	local hills = root:folder("Hills")
	local rng = Random.new(2024)
	-- Each mountain is a ridge: two wedges back to back, its long side to the valley, with a
	-- lighter cap of snow on the tall ones and blossom on the slope facing in.
	for k = 0, 29 do
		local a = k / 30 * math.pi * 2 + rng:NextNumber(-0.05, 0.05)
		local r = H + 80 + rng:NextNumber(0, 70)
		local w = rng:NextNumber(110, 170)
		local h = rng:NextNumber(70, 150)
		local d = h * 1.5
		local face = CFrame.lookAt(Vector3.new(math.cos(a) * r, -4, math.sin(a) * r), Vector3.new(0, -4, 0))
		local rockColour = if k % 2 == 0 then Color3.fromRGB(110, 136, 122) else Color3.fromRGB(126, 150, 128)
		hills:decor("Mountain", Vector3.new(w, h, d / 2), face * CFrame.new(0, h / 2, d / 4) * CFrame.Angles(0, math.pi, 0), rockColour,
			M.Slate, { shape = "Wedge" })
		hills:decor("Mountain", Vector3.new(w, h, d / 2), face * CFrame.new(0, h / 2, -d / 4), darker(rockColour, 0.12), M.Slate,
			{ shape = "Wedge" })
		if h > 115 then
			local capH = h * 0.24
			local capD = d * 0.24
			hills:decor("Snow", Vector3.new(w * 0.98, capH, capD / 2), face * CFrame.new(0, h - capH / 2 + 0.3, capD / 4) * CFrame.Angles(0, math.pi, 0),
				Color3.fromRGB(244, 246, 250), M.Snow, { shape = "Wedge" })
			hills:decor("Snow", Vector3.new(w * 0.98, capH, capD / 2), face * CFrame.new(0, h - capH / 2 + 0.3, -capD / 4),
				Color3.fromRGB(226, 232, 240), M.Snow, { shape = "Wedge" })
		end
		local grove = math.min(h * 0.4, d * 0.4)
		hills:decor("Grove", Vector3.new(grove, grove, grove), face * CFrame.new(0, grove * 0.2, -d * 0.36),
			if k % 3 == 0 then SAKURA else GRASS_DARK, nil, { shape = "Ball" })
	end
	-- Inside the walls, the valley floor rises into low grassy hills along its edges.
	-- (Each a low ridge of two wedges, gentle enough to walk up.)
	for k, spec in ipairs({ { -240, -240, 70 }, { 240, -240, 60 }, { -250, 40, 60 }, { 250, 30, 56 }, { -250, -40, 40 }, { 250, -50, 46 },
		{ -170, -255, 50 }, { 120, -258, 44 } }) do
		local w, h, d = spec[3], spec[3] * 0.16, spec[3] * 0.8
		local at = CFrame.new(spec[1], 0, spec[2]) * CFrame.Angles(0, k * 0.7, 0)
		root:part("Knoll", Vector3.new(w, h, d / 2), at * CFrame.new(0, h / 2, -d / 4), GRASS_DARK, M.Grass, { shape = "Wedge" })
		root:part("Knoll", Vector3.new(w, h, d / 2), at * CFrame.new(0, h / 2, d / 4) * CFrame.Angles(0, math.pi, 0), GRASS_DARK, M.Grass,
			{ shape = "Wedge" })
	end
	-- Wildflowers and grass in the open meadows.
	for _ = 1, 160 do
		local x, z = rng:NextNumber(-H + 6, H - 6), rng:NextNumber(-H + 6, 110)
		local a = HanamiConfig.AreaAt(Vector3.new(x, 0, z))
		local open = a and (a.id == "BambooHollow" or a.id == "Square" or (a.id == "Hanamura" and math.abs(x) > 40))
		if open and (z < HanamiConfig.RIVER.z0 - 3 or z > HanamiConfig.RIVER.z1 + 3) then
			if rng:NextNumber() < 0.6 then
				root:decor("Tuft", Vector3.new(1.4, 1.4, 1.4), Vector3.new(x, 0.1, z), GRASS_DARK, nil, { shape = "Ball" })
			else
				root:decor("Flowers", Vector3.new(0.8, 0.8, 0.8), Vector3.new(x, 0.3, z),
					({ SAKURA, Color3.fromRGB(250, 220, 90), PLASTER, Color3.fromRGB(170, 140, 230) })[rng:NextInteger(1, 4)], nil, { shape = "Ball" })
			end
		end
	end

	-- Finding your way: landmarks on the compass, and the named areas.
	local function waypoint(name: string, icon: string, at: Vector3)
		local m = marker(root, "Waypoint", at + Vector3.new(0, 3, 0))
		m:SetAttribute("WaypointName", name)
		m:SetAttribute("WaypointIcon", icon)
		m:AddTag("Waypoint")
	end
	local S = HanamiConfig.Sites
	waypoint("GREAT SAKURA", "🌸", S.GreatSakura)
	waypoint("SHRINE", "⛩", S.Shrine)
	waypoint("LANTERN ROW", "🏮", S.LanternGate)
	waypoint("IRONWORKS", "🏭", S.IronGate)
	waypoint("THE THOUSAND GATES", "⛩", S.StairFoot)
	waypoint("KUROGANE KEEP", "🏯", S.Court)
	waypoint("BAMBOO HOLLOW", "🎋", S.Camp)
	waypoint("THE PADDIES", "🌾", S.Farmhouse)
	for _, a in ipairs(HanamiConfig.Areas) do
		local y = a.y or 0
		local box = root:decor("Area", Vector3.new(a.x1 - a.x0, 40, a.z1 - a.z0), Vector3.new((a.x0 + a.x1) / 2, y + 18, (a.z0 + a.z1) / 2),
			CREAM, nil, { transparency = 1 })
		box:SetAttribute("AreaName", a.name)
		box:SetAttribute("AreaSub", a.sub)
		box:AddTag("Area")
	end
	-- The whole valley as one area too, for the title on arrival.
	local all = root:decor("Area", Vector3.new(H * 2, 160, H * 2), Vector3.new(0, 60, 0), CREAM, nil, { transparency = 1 })
	all:SetAttribute("AreaName", HanamiConfig.NAME)
	all:SetAttribute("AreaSub", "THE NEXT CHAPTER")
	all:AddTag("Area")

	-- Clues, seals and the like: their props, and a marker for the service to wire.
	for _, clue in ipairs(HanamiConfig.Clues) do
		local c = root:within(CFrame.new(clue.at))
		c:part("ClueTable", Vector3.new(3.4, 2.6, 2.2), Vector3.new(0, 1.3, 0), WOOD, M.WoodPlanks)
		local paper = c:decor("Clue", Vector3.new(1.4, 0.1, 1), Vector3.new(0, 2.66, 0), PAPER)
		paper:SetAttribute("ClueId", clue.id)
		c:decor("ClueWeight", Vector3.new(0.5, 0.4, 0.5), Vector3.new(0.6, 2.85, 0.2), KURO)
	end
	for i, at in ipairs(HanamiConfig.Seals) do
		marker(root, "SealSpot", at + Vector3.new(0, 1.6, 0), { Index = i })
	end
end

return Valley
