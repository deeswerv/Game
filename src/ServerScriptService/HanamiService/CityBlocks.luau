--!strict
-- How HANAMI CITY's streets are put together: the tools the district builders (CitySouth,
-- CityMiddle, CityNorth) share. Rows of buildings along a street at the city's scale, the
-- blocks they stand round (a raised pavement with its kerb, buildings on every side you want,
-- a low roofscape filling the middle), road paint and crossings, the avenue's lamps and trees,
-- poles and their wires -- and the names over the shops.
--
-- Everything is in the city's frame (HanamiConfig): +Z north, +X west, the street at y = 0,
-- the pavements at y = WALK. Buildings are drawn by CityKit at its drawing size and built
-- through CityKit.Scaled at CityKit.SCALE; every width and depth here is in real studs.

local ServerScriptService = game:GetService("ServerScriptService")

local Kit = require(ServerScriptService.ArenaService.Kit)
local CityKit = require(ServerScriptService.HanamiService.CityKit)

local Blocks = {}

type B = Kit.Builder
local M = Enum.Material
local P = CityKit.P
local At = CityKit.At

local K = CityKit.SCALE
Blocks.K = K
Blocks.WALK = 0.5          -- the pavements' top, a kerb over the road
local WALK = Blocks.WALK

-- ------------------------------------------------------------------ names --

-- Shops: Japanese, English, colour, kind.
Blocks.SHOPS = {
	{ "ラーメン", "RAMEN", Color3.fromRGB(214, 52, 44), "noren" }, { "寿司", "SUSHI", Color3.fromRGB(32, 60, 110), "noren" },
	{ "喫茶", "CAFE", Color3.fromRGB(120, 76, 50), "glass" }, { "本", "BOOKS", Color3.fromRGB(36, 120, 84), "glass" },
	{ "花", "FLOWERS", Color3.fromRGB(236, 120, 160), "open" }, { "焼肉", "YAKINIKU", Color3.fromRGB(28, 30, 36), "glass" },
	{ "牛丼", "GYUDON", Color3.fromRGB(246, 140, 30), "glass" }, { "そば", "SOBA", Color3.fromRGB(70, 46, 34), "noren" },
	{ "うどん", "UDON", Color3.fromRGB(250, 214, 80), "noren" }, { "たこ焼き", "TAKOYAKI", Color3.fromRGB(220, 60, 50), "open" },
	{ "パン", "BAKERY", Color3.fromRGB(214, 160, 96), "glass" }, { "ゲーム", "GAMES", Color3.fromRGB(130, 70, 190), "glass" },
	{ "服", "CLOTHES", Color3.fromRGB(40, 40, 46), "glass" }, { "眼鏡", "GLASSES", Color3.fromRGB(40, 110, 200), "glass" },
	{ "不動産", "REALTY", Color3.fromRGB(30, 140, 110), "glass" }, { "美容室", "SALON", Color3.fromRGB(240, 240, 236), "glass" },
	{ "電気", "ELECTRIC", Color3.fromRGB(240, 196, 40), "glass" }, { "お茶", "TEA", Color3.fromRGB(70, 120, 70), "noren" },
	{ "和菓子", "SWEETS", Color3.fromRGB(196, 80, 120), "glass" }, { "餃子", "GYOZA", Color3.fromRGB(230, 70, 40), "noren" },
	{ "コーヒー", "COFFEE", Color3.fromRGB(46, 110, 80), "glass" }, { "古着", "VINTAGE", Color3.fromRGB(150, 90, 60), "open" },
	{ "漫画", "MANGA", Color3.fromRGB(250, 90, 60), "glass" }, { "酒", "SAKE", Color3.fromRGB(30, 50, 100), "noren" },
	{ "薬", "DRUGS", Color3.fromRGB(250, 212, 40), "glass" }, { "時計", "WATCHES", Color3.fromRGB(60, 64, 72), "shutter" },
	{ "文具", "STATIONERY", Color3.fromRGB(70, 150, 210), "glass" }, { "天ぷら", "TEMPURA", Color3.fromRGB(240, 170, 60), "noren" },
} :: { { any } }
Blocks.TENANTS = { "歯科", "英会話", "麻雀", "BAR", "ネイル", "整体", "塾", "ダンス", "占い", "スナック", "写真", "ヨガ", "CLINIC",
	"BEAUTY", "囲碁", "カフェ", "カラオケ", "焼肉", "ジム", "ホテル" }
Blocks.TALL = { "カラオケ", "ホテル", "居酒屋", "焼肉", "ラーメン", "マッサージ", "漫画喫茶", "サウナ", "クリニック", "ゲーム",
	"不動産", "質", "パチンコ", "ビデオ", "ボウリング" }
Blocks.IZAKAYA = {
	{ "居酒屋", "IZAKAYA" }, { "焼鳥", "YAKITORI" }, { "おでん", "ODEN" }, { "串カツ", "KUSHI" }, { "酒場", "TAVERN" },
	{ "もつ焼", "MOTSU" }, { "立ち飲み", "STAND BAR" }, { "海鮮", "SEAFOOD" }, { "鉄板", "TEPPAN" }, { "炉端", "ROBATA" },
	{ "ホルモン", "HORUMON" }, { "日本酒", "NIHONSHU" }, { "スナック", "SNACK" }, { "ラーメン", "RAMEN" }, { "餃子", "GYOZA" },
	{ "天ぷら", "TEMPURA" },
} :: { { string } }

--- A random shop sign from the list.
function Blocks.AnyShop(rng: Random, awning: boolean?): CityKit.Shop
	local s = Blocks.SHOPS[rng:NextInteger(1, #Blocks.SHOPS)]
	return { jp = s[1], en = s[2], colour = s[3], kind = s[4], awning = awning }
end

--- A builder at the city's scale, standing at (x, z) on the pavement, its front looking `facing`.
function Blocks.Site(root: B, x: number, z: number, facing: string, y: number?): B
	return CityKit.Scaled(At(root, x, z, facing, y or WALK), K)
end

--- One building at the city's scale (spec in drawn units, as CityKit.Building takes it, but its
--- `w` and `d` in real studs). Returns its height in real studs.
function Blocks.Building(root: B, x: number, z: number, facing: string, spec: any, y: number?): number
	spec.w, spec.d = spec.w / K, spec.d / K
	local b = Blocks.Site(root, x, z, facing, y)
	local top = if spec.izakaya then CityKit.Izakaya(b, spec) else CityKit.Building(b, spec)
	return top * K
end

-- ------------------------------------------------------------------ rows --

--- Buildings shoulder to shoulder along a street edge, in real studs: from `a0` to `a1` along
--- the street, their fronts on the line `line`, looking `facing`, `depth` deep. `pick(k, n, w,
--- rng)` says what each one is: a CityKit building spec without its size, { izakaya = true, ... },
--- { tower = <TowerSpec without w, d> }, or false for a gap. `size` is the usual width.
--- Returns { a0, a1, top } for each.
function Blocks.Row(root: B, a0: number, a1: number, line: number, facing: string, depth: number, seed: number,
	pick: (k: number, n: number, w: number, rng: Random) -> any, size: number?): { { number } }
	local rng = Random.new(seed)
	local total = a1 - a0
	local n = math.max(1, math.floor(total / (size or 22) + 0.5))
	local weights, sum = {}, 0
	for k = 1, n do
		weights[k] = rng:NextNumber(0.8, 1.2)
		sum += weights[k]
	end
	local out = {}
	local pos = a0
	local alongX = facing == "-z" or facing == "+z"
	-- Which end of the row is a building's left (as you face it) depends on which way it faces.
	local firstLeft = facing == "-z" or facing == "+x"
	for k = 1, n do
		local w = total * weights[k] / sum
		local mid = pos + w / 2
		local spec = pick(k, n, w, rng)
		if spec then
			local x, z = if alongX then mid else line, if alongX then line else mid
			local first, last = k == 1, k == n
			local top
			if spec.tower then
				local t = spec.tower
				t.w, t.d = w - 0.4, depth
				t.seed = t.seed or (seed * 31 + k)
				t.left = t.left or (if firstLeft then first else last)
				t.right = t.right or (if firstLeft then last else first)
				top = CityKit.Tower(At(root, x, z, facing, WALK), t)
			else
				spec.w, spec.d = w, depth
				spec.seed = spec.seed or (seed * 31 + k)
				spec.left = spec.left or (if firstLeft then first else last)
				spec.right = spec.right or (if firstLeft then last else first)
				if (first or last) and not spec.izakaya and spec.shop and spec.sideShops == nil then
					spec.sideShops = { Blocks.AnyShop(rng), Blocks.AnyShop(rng, true) }
				end
				top = Blocks.Building(root, x, z, facing, spec)
			end
			table.insert(out, { pos, pos + w, top })
		end
		pos += w
	end
	return out
end

--- A mid-rise for a city street: any style, a shop under it, now and then a tall sign off its
--- corner or a board on its roof.
function Blocks.CityPick(minFloors: number, maxFloors: number, tallSigns: number?, styles: { string }?)
	return function(k: number, n: number, w: number, rng: Random): any
		local list = styles or { "tile", "mansion", "zakkyo", "tile", "zakkyo", "office" }
		local style = list[rng:NextInteger(1, #list)]
		if w < 14 and style == "office" then
			style = "zakkyo"
		end
		local floors = rng:NextInteger(minFloors, maxFloors)
		local tenants = {}
		for i = 1, floors do
			tenants[i] = ("%dF %s"):format(i + 1, Blocks.TENANTS[rng:NextInteger(1, #Blocks.TENANTS)])
		end
		return {
			style = style, floors = floors, colour = CityKit.FACADES[rng:NextInteger(1, #CityKit.FACADES)],
			shop = Blocks.AnyShop(rng, rng:NextNumber() < 0.45), tenants = tenants,
			vsign = if rng:NextNumber() < (tallSigns or 0.35) then Blocks.TALL[rng:NextInteger(1, #Blocks.TALL)] else nil,
			vside = if rng:NextNumber() < 0.5 then -1 else 1,
			billboard = if floors >= 4 and rng:NextNumber() < 0.22 then Blocks.TALL[rng:NextInteger(1, #Blocks.TALL)] else nil,
			back = true,
		}
	end
end

-- ------------------------------------------------------------------ the ground --

--- A pavement: a raised slab from x0..x1, z0..z1 with its top at WALK, a granite kerb round it.
--- `kerbs` (default all) says which edges are kerbs onto a road: "-z", "+z", "-x", "+x".
function Blocks.Walk(root: B, x0: number, x1: number, z0: number, z1: number, kerbs: { string }?, colour: Color3?)
	root:part("Pavement", Vector3.new(x1 - x0, 2, z1 - z0), Vector3.new((x0 + x1) / 2, WALK - 1, (z0 + z1) / 2), colour or P.WALK,
		M.Pavement)
	for _, e in ipairs(kerbs or { "-z", "+z", "-x", "+x" }) do
		if e == "-z" or e == "+z" then
			local z = if e == "-z" then z0 + 0.45 else z1 - 0.45
			root:decor("Kerb", Vector3.new(x1 - x0, WALK + 0.06, 0.9), Vector3.new((x0 + x1) / 2, (WALK + 0.06) / 2, z), P.KERB, M.Granite)
		else
			local x = if e == "-x" then x0 + 0.45 else x1 - 0.45
			root:decor("Kerb", Vector3.new(0.9, WALK + 0.06, z1 - z0), Vector3.new(x, (WALK + 0.06) / 2, (z0 + z1) / 2), P.KERB, M.Granite)
		end
	end
end

export type BlockOpts = {
	walk: number?,                       -- the pavement's width all round (default 12)
	walks: { [string]: number }?,        -- or per side: ["-z"] = 14 ...
	depth: number?,                      -- how deep the buildings are (default 26)
	seed: number,
	pick: (number, number, number, Random) -> any,
	picks: { [string]: (number, number, number, Random) -> any }?,   -- a different pick for a side
	size: number?,
	sides: { string }?,                  -- which sides have buildings (default all four)
	core: number?,                       -- the height of the roofscape filling the middle (default 12; 0 none)
}

--- A city block between roads: x0..x1, z0..z1 are the road edges. A pavement all round, the
--- buildings fronting each side asked for, the middle filled. Returns the rows by side.
function Blocks.Block(root: B, x0: number, x1: number, z0: number, z1: number, o: BlockOpts): { [string]: { { number } } }
	Blocks.Walk(root, x0, x1, z0, z1)
	local function walk(side: string): number
		return (o.walks and o.walks[side]) or o.walk or 12
	end
	local depth = o.depth or 26
	local sides: { [string]: boolean } = {}
	for _, s in ipairs(o.sides or { "-z", "+z", "-x", "+x" }) do
		sides[s] = true
	end
	local ix0, ix1, iz0, iz1 = x0 + walk("-x"), x1 - walk("+x"), z0 + walk("-z"), z1 - walk("+z")
	local out = {}
	local function pick(side: string)
		return (o.picks and o.picks[side]) or o.pick
	end
	if sides["-z"] then
		out["-z"] = Blocks.Row(root, ix0, ix1, iz0, "-z", depth, o.seed, pick("-z"), o.size)
	end
	if sides["+z"] then
		out["+z"] = Blocks.Row(root, ix0, ix1, iz1, "+z", depth, o.seed + 1, pick("+z"), o.size)
	end
	local s0 = if sides["-z"] then iz0 + depth else iz0
	local s1 = if sides["+z"] then iz1 - depth else iz1
	if s1 - s0 > 8 then
		if sides["-x"] then
			out["-x"] = Blocks.Row(root, s0, s1, ix0, "-x", depth, o.seed + 2, pick("-x"), o.size)
		end
		if sides["+x"] then
			out["+x"] = Blocks.Row(root, s0, s1, ix1, "+x", depth, o.seed + 3, pick("+x"), o.size)
		end
	end
	local core = o.core or 12
	local cx0 = if sides["-x"] then ix0 + depth else ix0
	local cx1 = if sides["+x"] then ix1 - depth else ix1
	if core > 0 and cx1 - cx0 > 2 and s1 - s0 > 2 then
		root:part("BlockCore", Vector3.new(cx1 - cx0 + 1, core, s1 - s0 + 1), Vector3.new((cx0 + cx1) / 2, WALK + core / 2,
			(s0 + s1) / 2), P.CONCRETE_DARK, M.Concrete)
	end
	return out
end

-- ------------------------------------------------------------------ the roads --

--- Road paint: a road along X (or Z) from a0 to a1, centred on `mid`, `half` wide each side
--- of it. Solid edge lines; an avenue (half >= 18) has a double yellow line down the middle
--- and dashed lines between its lanes, a street a dashed white centre line.
function Blocks.Lanes(root: B, alongX: boolean, a0: number, a1: number, mid: number, half: number)
	local function line(name: string, off: number, width: number, colour: Color3, from: number?, to: number?)
		local f, t = from or a0, to or a1
		if alongX then
			root:decor(name, Vector3.new(t - f, 0.06, width), Vector3.new((f + t) / 2, 0.03, mid + off), colour)
		else
			root:decor(name, Vector3.new(width, 0.06, t - f), Vector3.new(mid + off, 0.03, (f + t) / 2), colour)
		end
	end
	local function dashed(off: number, dash: number, gap: number, colour: Color3)
		local a = a0 + gap / 2
		while a + dash <= a1 do
			line("LaneLine", off, 0.5, colour, a, a + dash)
			a += dash + gap
		end
	end
	for _, s in ipairs({ -1, 1 }) do
		line("EdgeLine", s * (half - 1.4), 0.5, P.LINE)
	end
	if half >= 18 then
		line("CentreLine", -0.6, 0.45, P.LINE_YELLOW)
		line("CentreLine", 0.6, 0.45, P.LINE_YELLOW)
		for _, s in ipairs({ -1, 1 }) do
			dashed(s * half / 2, 8, 8, P.LINE)
		end
	elseif half >= 7 then
		dashed(0, 6, 6, P.LINE)
	end
end

--- Zebra stripes across a road: the crossing's middle at (cx, cz), the road running along X
--- (`alongX`: the stripes lie along X, side by side across the road's width `width`) or Z.
--- `depth` is how far the stripes reach along the road.
function Blocks.Zebra(root: B, cx: number, cz: number, alongX: boolean, width: number, depth: number?)
	local dd = depth or 10
	local n = math.floor(width / 3.6)
	for k = 0, n - 1 do
		local o = -width / 2 + 1.8 + k * 3.6 + (width - n * 3.6) / 2
		if alongX then
			root:decor("Zebra", Vector3.new(dd, 0.07, 1.9), Vector3.new(cx, 0.04, cz + o), P.LINE)
		else
			root:decor("Zebra", Vector3.new(1.9, 0.07, dd), Vector3.new(cx + o, 0.04, cz), P.LINE)
		end
	end
end

--- A stop line across one half of a road, at `at` along it, on the side `side` (-1 / 1) of
--- the middle `mid`.
function Blocks.StopLine(root: B, alongX: boolean, at: number, mid: number, half: number, side: number)
	local o = mid + side * half / 2
	if alongX then
		root:decor("StopLine", Vector3.new(0.9, 0.06, half - 1), Vector3.new(at, 0.03, o), P.LINE)
	else
		root:decor("StopLine", Vector3.new(half - 1, 0.06, 0.9), Vector3.new(o, 0.03, at), P.LINE)
	end
end

--- Along a kerb: avenue lamps and street trees in turn, every `step` studs, from a0 to a1 on
--- the line `line` (the lamp's foot), their arms out over the road that lies `facing` of them.
--- Stretches in `skip` ({ { from, to } }) are left clear (crossings, doors).
function Blocks.Avenue(root: B, alongX: boolean, a0: number, a1: number, line: number, facing: string, step: number,
	seed: number, skip: { { number } }?, sakura: boolean?, guard: boolean?)
	local k = 0
	local a = a0
	local rail: number? = nil
	local function railTo(stop: number)
		if guard and rail and stop - (rail :: number) > 6 then
			local r0 = rail :: number
			local railLine = line + (if facing == "-z" or facing == "-x" then -1.6 else 1.6)
			if alongX then
				CityKit.Guardrail(root, Vector3.new(r0, WALK, railLine), Vector3.new(stop, WALK, railLine))
			else
				CityKit.Guardrail(root, Vector3.new(railLine, WALK, r0), Vector3.new(railLine, WALK, stop))
			end
		end
		rail = nil
	end
	while a <= a1 do
		local blocked = false
		for _, s in ipairs(skip or {} :: { { number } }) do
			if a >= s[1] - 2 and a <= s[2] + 2 then
				blocked = true
			end
		end
		if blocked then
			railTo(a - 3)
		else
			if guard and not rail then
				rail = a
			end
			local x, z = if alongX then a else line, if alongX then line else a
			if k % 2 == 0 then
				CityKit.AvenueLamp(At(root, x, z, facing, WALK), k % 4 == 0, false)
			else
				local back = if facing == "-z" then 3 elseif facing == "+z" then -3 else 0
				local side = if facing == "-x" then 3 elseif facing == "+x" then -3 else 0
				CityKit.TreeBed(root:within(CFrame.new(x + side, WALK, z + back)), seed + k * 7, sakura)
			end
			k += 1
		end
		a += step
	end
	railTo(a1)
end

--- Utility poles down a street, wired one to the next.
function Blocks.Poles(root: B, from: Vector3, to: Vector3, count: number, turned: boolean?)
	local last: { Vector3 }? = nil
	for k = 0, count - 1 do
		local t = if count == 1 then 0.5 else k / (count - 1)
		local at = from:Lerp(to, t)
		local hangs = CityKit.Pole(root, at, 30 + (k % 2) * 2, k % 3 == 1, turned)
		if last then
			CityKit.Wires(root, last, hangs)
		end
		last = hangs
	end
end

return Blocks
