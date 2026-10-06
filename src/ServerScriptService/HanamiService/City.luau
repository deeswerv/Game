--!strict
-- HANAMI CITY, built: the world past Downtown. A Japanese city in the game's painted low-poly
-- look, dense and lived-in, every street a little different (HanamiConfig has the map):
--
--   HANAMI STATION   where you arrive: the station under the railway viaduct, a train standing
--                    at the platform, the square with the Great Sakura, a taxi rank, the koban,
--                    the department store, a shrine through a red torii off the square, and
--                    HANAMI GINZA, the covered shopping arcade, running north to the canal.
--   THE RAIL YARD    the sidings, container wagons, the signal box, the old brick shed the
--                    gang uses as a hideout, the danchi blocks and their playground.
--   THE FISH MARKET  the auction hall, stalls of fish on ice, turret trucks, sushi counters,
--                    bars in the arches under the railway.
--   THE CANAL        cherry trees and lanterns along both banks, three bridges, a walk by the
--                    water.
--   THE SCRAMBLE     the big crossing, its corners stood round with tall buildings, giant
--                    screens and a round tower.
--   LANTERN ROW      the drinking alleys: two-storey wooden izakaya under strings of red
--                    lanterns, noren and crates and bikes, roof terraces up ladders.
--   THE STEELWORKS   the Kurogane foundry: warehouses, the furnace hall and its striped stacks,
--                    the yard, containers, the quay with its crane and a ship alongside.
--   KUROGANE CASTLE  on its stone base behind a moat, up the Thousand Gates: white walls, the
--                    court, and the black keep.
--
-- Built at run time by HanamiService, in its own folder, in the city's frame (HanamiConfig).
-- Markers the service and the quests need are invisible named parts. Everything that is not
-- the ground, a building's body, a pole, a vehicle or something to stand on is decoration
-- (no collision, no raycasts).

local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Kit = require(ServerScriptService.ArenaService.Kit)
local CityKit = require(ServerScriptService.HanamiService.CityKit)
local HanamiConfig = require(ReplicatedStorage.HanamiConfig)

local City = {}

type B = Kit.Builder
local M = Enum.Material
local P = CityKit.P
local darker, lighter = CityKit.Darker, CityKit.Lighter
local vertical = CityKit.Vertical
local At = CityKit.At
local text = CityKit.Text

-- The city's own light: a warm spring afternoon, a little hazy, pink in the distance.
City.Look = {
	Grade = { Saturation = 0.2, Contrast = 0.07, TintColor = Color3.fromRGB(255, 246, 242) },
	Clouds = { Cover = 0.5, Density = 0.42, Color = Color3.fromRGB(255, 248, 250) },
	Atmosphere = { Density = 0.3, Haze = 1.3, Color = Color3.fromRGB(246, 226, 232), Decay = Color3.fromRGB(150, 146, 176) },
}

-- Cameras for tools/mapview (city frame).
City.Preview = {
	{ pos = { 0, 6, -212 }, look = { 0, 8, -150 }, fov = 70 },          -- off the train: the square and the arcade
	{ pos = { -30, 5, -228 }, look = { -80, 8, -200 }, fov = 70 },      -- the shrine's torii
	{ pos = { 0, 5, -150 }, look = { 0, 6, -100 }, fov = 70 },          -- inside the arcade
	{ pos = { 30, 6, -94 }, look = { -40, 4, -76 }, fov = 70 },         -- along the canal
	{ pos = { 0, 5, -46 }, look = { 0, 14, 20 }, fov = 72 },            -- up the avenue to the scramble
	{ pos = { 13, 7, 30 }, look = { -6, 16, -6 }, fov = 75 },          -- the scramble from its corner
	{ pos = { -60, 5, 10 }, look = { -160, 8, 10 }, fov = 70 },         -- into Lantern Row
	{ pos = { -100, 5, 56 }, look = { -100, 6, -20 }, fov = 70 },       -- a Lantern Row side alley
	{ pos = { 60, 6, 10 }, look = { 160, 12, 40 }, fov = 70 },          -- into the Steelworks
	{ pos = { 150, 8, 20 }, look = { 160, 10, 80 }, fov = 70 },         -- the furnace yard
	{ pos = { 190, 8, -40 }, look = { 220, 20, 20 }, fov = 70 },        -- the quay and the ship
	{ pos = { 0, 6, 40 }, look = { 0, 30, 130 }, fov = 70 },            -- the Thousand Gates
	{ pos = { 0, 36, 136 }, look = { 0, 50, 230 }, fov = 72 },          -- the court and the keep
	{ pos = { -150, 6, -150 }, look = { -180, 6, -210 }, fov = 70 },    -- the rail yard and its shed
	{ pos = { 150, 6, -160 }, look = { 190, 8, -210 }, fov = 70 },      -- the fish market
	{ pos = { 0, 120, -330 }, look = { 0, 0, -40 }, fov = 60 },         -- over the station
	{ pos = { -330, 160, 0 }, look = { 0, 0, 20 }, fov = 60 },          -- over Lantern Row
}

-- ------------------------------------------------------------------ names --

-- Shops: Japanese, English, colour, kind.
local SHOPS: { { any } } = {
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
}
local TENANTS = { "歯科", "英会話", "麻雀", "BAR", "ネイル", "整体", "塾", "ダンス", "占い", "スナック", "写真", "ヨガ", "CLINIC",
	"BEAUTY", "囲碁", "カフェ" }
local TALL = { "カラオケ", "ホテル", "居酒屋", "焼肉", "ラーメン", "マッサージ", "漫画喫茶", "サウナ", "クリニック", "ゲーム",
	"不動産", "質" }
local IZAKAYA: { { string } } = {
	{ "居酒屋", "IZAKAYA" }, { "焼鳥", "YAKITORI" }, { "おでん", "ODEN" }, { "串カツ", "KUSHI" }, { "酒場", "TAVERN" },
	{ "もつ焼", "MOTSU" }, { "立ち飲み", "STAND BAR" }, { "海鮮", "SEAFOOD" }, { "鉄板", "TEPPAN" }, { "炉端", "ROBATA" },
	{ "ホルモン", "HORUMON" }, { "日本酒", "NIHONSHU" }, { "スナック", "SNACK" }, { "ラーメン", "RAMEN" },
}

-- ------------------------------------------------------------------ rows --

--- A random shop sign from the list.
local function anyShop(rng: Random, awning: boolean?): CityKit.Shop
	local s = SHOPS[rng:NextInteger(1, #SHOPS)]
	return { jp = s[1], en = s[2], colour = s[3], kind = s[4], awning = awning }
end


--- Buildings shoulder to shoulder along a street edge: from `a0` to `a1` along the street,
--- their fronts on the line `line`, looking `facing`, `depth` deep. `pick` says what each one
--- is (or false to leave a gap): a building spec without its size, or { izakaya = true, ... }.
--- Returns the parts of the row: { a0, a1, top } each.
local function row(root: B, a0: number, a1: number, line: number, facing: string, depth: number, seed: number,
	pick: (k: number, n: number, w: number, rng: Random) -> any, size: number?): { { number } }
	local rng = Random.new(seed)
	local total = a1 - a0
	local n = math.max(1, math.floor(total / (size or 14) + 0.5))
	local weights, sum = {}, 0
	for k = 1, n do
		weights[k] = rng:NextNumber(0.78, 1.22)
		sum += weights[k]
	end
	local out = {}
	local pos = a0
	for k = 1, n do
		local w = total * weights[k] / sum
		local mid = pos + w / 2
		local spec = pick(k, n, w, rng)
		if spec then
			local x, z = if facing == "-z" or facing == "+z" then mid else line, if facing == "-z" or facing == "+z" then line else mid
			local b = At(root, x, z, facing)
			-- The row's two ends have a side you can see; which local side that is depends on
			-- which way the row faces.
			local firstLeft = facing == "-z" or facing == "+x"
			local first, last = k == 1, k == n
			local top
			spec.w, spec.d = w, depth
			spec.seed = spec.seed or (seed * 31 + k)
			spec.left = spec.left or (if firstLeft then first else last)
			spec.right = spec.right or (if firstLeft then last else first)
			if (first or last) and not spec.izakaya and spec.shop and spec.sideShops == nil then
				spec.sideShops = { anyShop(rng), anyShop(rng) }
			end
			if spec.izakaya then
				top = CityKit.Izakaya(b, spec)
			else
				top = CityKit.Building(b, spec)
			end
			table.insert(out, { pos, pos + w, top })
		end
		pos += w
	end
	return out
end

--- A mid-rise for a city street: any style, a shop under it.
local function cityPick(minFloors: number, maxFloors: number, tallSigns: number?): (number, number, number, Random) -> any
	return function(k: number, n: number, w: number, rng: Random): any
		local styles = { "tile", "mansion", "zakkyo", "tile", "zakkyo", "office" }
		local style = styles[rng:NextInteger(1, #styles)]
		if w < 10 and style == "office" then
			style = "zakkyo"
		end
		local floors = rng:NextInteger(minFloors, maxFloors)
		local tenants = {}
		for i = 1, floors do
			tenants[i] = TENANTS[rng:NextInteger(1, #TENANTS)]
		end
		return {
			style = style, floors = floors, colour = CityKit.FACADES[rng:NextInteger(1, #CityKit.FACADES)],
			shop = anyShop(rng, rng:NextNumber() < 0.45), tenants = tenants,
			vsign = if rng:NextNumber() < (tallSigns or 0.35) then TALL[rng:NextInteger(1, #TALL)] else nil,
			vside = if rng:NextNumber() < 0.5 then -1 else 1, back = true,
		}
	end
end

--- A whole block ringed with buildings, a low roofscape filling the middle.
local function block(root: B, x0: number, x1: number, z0: number, z1: number, depth: number, seed: number,
	pick: (number, number, number, Random) -> any, size: number?)
	row(root, x0, x1, z0, "-z", depth, seed, pick, size)
	row(root, x0, x1, z1, "+z", depth, seed + 1, pick, size)
	if z1 - z0 > depth * 2 + 6 then
		row(root, z0 + depth, z1 - depth, x0, "-x", depth, seed + 2, pick, size)
		row(root, z0 + depth, z1 - depth, x1, "+x", depth, seed + 3, pick, size)
		local ix0, ix1, iz0, iz1 = x0 + depth, x1 - depth, z0 + depth, z1 - depth
		if ix1 - ix0 > 1 and iz1 - iz0 > 1 then
			root:part("BlockCore", Vector3.new(ix1 - ix0, 9, iz1 - iz0), Vector3.new((ix0 + ix1) / 2, 4.5, (iz0 + iz1) / 2), P.CONCRETE)
		end
	end
end

--- A pavement along a street edge: from a0 to a1, between `line` and `line + width * dir`.
local function pavement(root: B, alongX: boolean, a0: number, a1: number, line: number, width: number, tactile: boolean?)
	local lo, hi = math.min(line, line + width), math.max(line, line + width)
	if alongX then
		CityKit.Patch(root, "Pavement", a0, a1, lo, hi, 0.02, P.WALK)
		root:decor("Kerb", Vector3.new(a1 - a0, 0.26, 0.5), Vector3.new((a0 + a1) / 2, 0.13, if width < 0 then lo + 0.25 else hi - 0.25), P.KERB)
		if tactile then
			local z = (lo + hi) / 2
			CityKit.Tactile(root, Vector3.new(a0 + 1, 0.1, z), Vector3.new(a1 - 1, 0.1, z))
		end
	else
		CityKit.Patch(root, "Pavement", lo, hi, a0, a1, 0.02, P.WALK)
		root:decor("Kerb", Vector3.new(0.5, 0.26, a1 - a0), Vector3.new(if width < 0 then lo + 0.25 else hi - 0.25, 0.13, (a0 + a1) / 2), P.KERB)
		if tactile then
			local x = (lo + hi) / 2
			CityKit.Tactile(root, Vector3.new(x, 0.1, a0 + 1), Vector3.new(x, 0.1, a1 - 1))
		end
	end
end

--- Road paint along a road from a0 to a1, centred on `mid`, `width` across: edge lines and a
--- dashed centre line.
local function roadLines(root: B, alongX: boolean, a0: number, a1: number, mid: number, width: number, dashed: boolean?)
	for _, s in ipairs({ -1, 1 }) do
		local o = mid + s * (width / 2 - 0.8)
		if alongX then
			root:decor("EdgeLine", Vector3.new(a1 - a0, 0.06, 0.35), Vector3.new((a0 + a1) / 2, 0.03, o), P.LINE)
		else
			root:decor("EdgeLine", Vector3.new(0.35, 0.06, a1 - a0), Vector3.new(o, 0.03, (a0 + a1) / 2), P.LINE)
		end
	end
	if width >= 12 then
		local step = if dashed == false then (a1 - a0) else 9
		local len = if dashed == false then (a1 - a0) else 5
		local a = a0 + step / 2
		while a < a1 do
			if alongX then
				root:decor("CentreLine", Vector3.new(len, 0.06, 0.4), Vector3.new(a, 0.03, mid), P.LINE)
			else
				root:decor("CentreLine", Vector3.new(0.4, 0.06, len), Vector3.new(mid, 0.03, a), P.LINE)
			end
			a += step
		end
	end
end

--- Poles down a street, wired one to the next.
local function poleLine(root: B, from: Vector3, to: Vector3, count: number, turned: boolean?)
	local last: { Vector3 }? = nil
	for k = 0, count - 1 do
		local t = if count == 1 then 0.5 else k / (count - 1)
		local at = from:Lerp(to, t)
		local hangs = CityKit.Pole(root, at, 23 + (k % 2) * 1.5, k % 3 == 1, turned)
		if last then
			CityKit.Wires(root, last, hangs)
		end
		last = hangs
	end
end

-- ------------------------------------------------------------------ the station --

--- The railway along the south edge: a concrete viaduct on piers, two tracks, the overhead
--- line, a train at the platform over the station.
local function viaduct(root: B)
	local f = root:folder("Railway")
	local z0, z1 = -258, -242
	local zc = (z0 + z1) / 2
	f:part("Viaduct", Vector3.new(524, 2.4, z1 - z0), Vector3.new(0, 14.8, zc), P.CONCRETE, M.Concrete)
	f:decor("ViaductLip", Vector3.new(524, 1, 0.8), Vector3.new(0, 13.9, z1 + 0.3), P.CONCRETE_DARK)
	for _, z in ipairs({ z0 + 0.4, z1 - 0.4 }) do
		f:part("ViaductWall", Vector3.new(524, 2.4, 0.8), Vector3.new(0, 17.2, z), P.CONCRETE, M.Concrete)
	end
	for x = -252, 252, 24 do
		for _, z in ipairs({ z0 + 3, z1 - 3 }) do
			f:part("Pier", Vector3.new(2.4, 13.6, 2.4), Vector3.new(x, 6.8, z), P.CONCRETE, M.Concrete)
		end
		f:decor("PierCap", Vector3.new(3, 1.4, z1 - z0 - 1), Vector3.new(x, 12.9, zc), P.CONCRETE_DARK)
		if (x + 252) % 48 == 0 then
			-- The overhead line: a mast and an arm over both tracks.
			f:decor("Mast", Vector3.new(0.6, 11, 0.6), Vector3.new(x, 21.5, z0 + 1.2), P.STEEL)
			f:decor("MastArm", Vector3.new(0.4, 0.4, z1 - z0 - 2), Vector3.new(x, 26.6, zc), P.STEEL)
		end
	end
	for _, tz in ipairs({ zc - 3.6, zc + 3.6 }) do
		f:decor("Ballast", Vector3.new(524, 0.3, 4.6), Vector3.new(0, 16.15, tz), Color3.fromRGB(150, 140, 130), M.Slate)
		for _, o in ipairs({ -1.3, 1.3 }) do
			f:decor("Rail", Vector3.new(524, 0.35, 0.3), Vector3.new(0, 16.45, tz + o), P.STEEL, M.Metal)
		end
		f:decor("Catenary", Vector3.new(524, 0.12, 0.12), Vector3.new(0, 26, tz), P.KURO)
	end
	-- The platform over the station, its canopy, and a train standing in it.
	f:part("Platform", Vector3.new(120, 1.4, 4), Vector3.new(0, 16.9, zc), Color3.fromRGB(200, 196, 188), M.Concrete)
	f:decor("PlatformEdge", Vector3.new(120, 0.12, 0.8), Vector3.new(0, 17.66, zc - 1.6), P.TACTILE)
	f:decor("PlatformEdge", Vector3.new(120, 0.12, 0.8), Vector3.new(0, 17.66, zc + 1.6), P.TACTILE)
	for x = -54, 54, 12 do
		f:decor("CanopyPost", Vector3.new(0.6, 8, 0.6), Vector3.new(x, 21.6, zc), P.STEEL)
	end
	f:decor("Canopy", Vector3.new(124, 0.6, 18), Vector3.new(0, 25.8, zc), Color3.fromRGB(226, 228, 230), M.Metal)
	f:decor("CanopyEdge", Vector3.new(124, 1, 0.6), Vector3.new(0, 25.4, z1 + 1), Color3.fromRGB(40, 140, 90))
	local function car(x: number, cab: boolean)
		local t = f:within(CFrame.new(x, 16.3, zc - 3.6))
		t:part("TrainCar", Vector3.new(38, 6.6, 4.8), Vector3.new(0, 3.6, 0), Color3.fromRGB(240, 242, 244), M.Metal)
		t:decor("TrainWindows", Vector3.new(34, 1.8, 4.9), Vector3.new(0, 4.6, 0), Color3.fromRGB(60, 80, 100), M.Glass)
		t:decor("TrainStripe", Vector3.new(38.02, 0.7, 4.86), Vector3.new(0, 2.8, 0), Color3.fromRGB(40, 160, 90))
		t:decor("TrainStripe", Vector3.new(38.02, 0.4, 4.86), Vector3.new(0, 2.2, 0), Color3.fromRGB(236, 120, 160))
		for dx = -12, 12, 8 do
			t:decor("TrainDoor", Vector3.new(2.6, 5, 4.92), Vector3.new(dx, 3.2, 0), Color3.fromRGB(204, 208, 212))
		end
		t:decor("TrainRoof", Vector3.new(37, 0.6, 4), Vector3.new(0, 7.2, 0), Color3.fromRGB(150, 156, 164))
		t:decor("Pantograph", Vector3.new(3, 1.6, 0.3), Vector3.new(0, 8.4, 0), P.IRON)
		t:decor("Bogie", Vector3.new(8, 1.4, 4), Vector3.new(-12, 0.4, 0), P.KURO)
		t:decor("Bogie", Vector3.new(8, 1.4, 4), Vector3.new(12, 0.4, 0), P.KURO)
		if cab then
			t:decor("TrainNose", Vector3.new(3, 5.2, 4.6), Vector3.new(-20, 3.4, 0), Color3.fromRGB(40, 160, 90))
			t:decor("TrainScreen", Vector3.new(0.3, 2.2, 3.6), Vector3.new(-21.5, 5, 0), Color3.fromRGB(50, 64, 80), M.Glass)
		end
	end
	car(-40, true)
	car(-1, false)
	car(38, false)
end

--- The station building: glass doors under a canopy, its name, a clock, ticket gates inside.
local function station(root: B)
	local s = At(root, 0, -222, "+z")
	-- The hall, from the square back to the viaduct.
	s:part("StationHall", Vector3.new(80, 13.4, 20), Vector3.new(0, 6.7, 10), Color3.fromRGB(236, 232, 222))
	s:part("StationTop", Vector3.new(80, 6, 12), Vector3.new(0, 16.4, 6), Color3.fromRGB(236, 232, 222))
	s:decor("StationCornice", Vector3.new(81, 1, 13), Vector3.new(0, 19.9, 6), Color3.fromRGB(190, 186, 176))
	-- The glass front, the gates and the light inside.
	s:decor("Interior", Vector3.new(44, 9, 0.2), Vector3.new(0, 4.6, -0.1), Color3.fromRGB(230, 226, 214))
	for x = -18, 18, 4 do
		s:decor("TicketGate", Vector3.new(0.8, 2.2, 0.3), Vector3.new(x, 1.1, -0.3), Color3.fromRGB(150, 156, 166))
	end
	s:decor("Departures", Vector3.new(16, 2.4, 0.3), Vector3.new(0, 7.2, -0.4), Color3.fromRGB(30, 34, 44))
	text(s, "発車 DEPARTURES   10:42 快速  10:48 各停", CFrame.new(0, 7.2, -0.6), 15, 1.6, Color3.fromRGB(250, 196, 70),
		Enum.Font.Code)
	s:decor("StationGlass", Vector3.new(44, 9, 0.3), Vector3.new(0, 4.6, -0.7), P.GLASS, M.Glass, { transparency = 0.6, reflectance = 0.1 })
	for x = -22, 22, 5.5 do
		s:decor("Mullion", Vector3.new(0.4, 9, 0.5), Vector3.new(x, 4.6, -0.8), P.FRAME)
	end
	-- Pillars and the canopy over the doors.
	for x = -34, 34, 11.3 do
		if math.abs(x) > 24 then
			s:decor("StationPier", Vector3.new(2, 13.4, 1), Vector3.new(x, 6.7, -0.5), Color3.fromRGB(210, 204, 192))
		end
	end
	local canopy = s:decor("StationCanopy", Vector3.new(52, 0.8, 8), Vector3.new(0, 10.2, -4), Color3.fromRGB(70, 74, 82))
	canopy.CastShadow = true
	s:decor("CanopyTrim", Vector3.new(52, 0.4, 0.4), Vector3.new(0, 10.6, -8), Color3.fromRGB(40, 160, 90))
	-- The name over it all.
	s:decor("NameBoard", Vector3.new(40, 4.2, 0.6), Vector3.new(0, 15.6, -0.3), Color3.fromRGB(40, 140, 90))
	text(s, "花見駅", CFrame.new(8, 15.8, -0.66), 18, 3.4, P.WHITE, Enum.Font.GothamBlack)
	text(s, "HANAMI STATION", CFrame.new(-11, 15.2, -0.66), 15, 1.8, P.WHITE, Enum.Font.GothamBold)
	-- The clock.
	s:decor("Clock", Vector3.new(0.6, 4.4, 4.4), CFrame.new(-30, 15.8, -0.4) * CFrame.Angles(0, math.rad(90), 0), P.WHITE, nil,
		{ shape = "Cylinder" })
	s:decor("ClockRim", Vector3.new(0.4, 4.9, 4.9), CFrame.new(-30, 15.8, -0.2) * CFrame.Angles(0, math.rad(90), 0), P.KURO, nil,
		{ shape = "Cylinder" })
	s:decor("ClockHand", Vector3.new(0.25, 1.8, 0.1), CFrame.new(-30, 16.5, -0.78), P.KURO)
	s:decor("ClockHand", Vector3.new(1.4, 0.25, 0.1), CFrame.new(-29.4, 15.8, -0.78), P.KURO)
	-- Lockers and a ticket machine to one side.
	for k = 0, 2 do
		s:part("TicketMachine", Vector3.new(2.6, 5.6, 1.6), Vector3.new(26 + k * 3, 2.8, -1.2), Color3.fromRGB(222, 226, 232))
		s:decor("TicketScreen", Vector3.new(1.8, 1.6, 0.1), Vector3.new(26 + k * 3, 3.8, -2.06), Color3.fromRGB(70, 140, 210))
	end
	s:part("Lockers", Vector3.new(8, 7, 2), Vector3.new(-30, 3.5, -1.4), Color3.fromRGB(110, 150, 196))
	for k = -3, 3 do
		s:decor("LockerSeam", Vector3.new(0.1, 7, 0.1), Vector3.new(-30 + k * 1.1, 3.5, -2.44), darker(Color3.fromRGB(110, 150, 196), 0.3))
	end
end

--- The square: paving, the Great Sakura in its ring, benches, the taxi rank, the koban, the
--- dog statue everybody meets at.
local function square(root: B)
	local S = HanamiConfig.Sites
	local x0, x1, z0, z1 = -62, 62, -222, -166
	CityKit.Patch(root, "Square", x0, x1, z0, z1, 0.02, Color3.fromRGB(226, 216, 200), M.Slate)
	for x = x0 + 8, x1 - 8, 8 do
		root:decor("PavingLine", Vector3.new(0.2, 0.04, z1 - z0), Vector3.new(x, 0.14, (z0 + z1) / 2), Color3.fromRGB(204, 192, 176))
	end
	for z = z0 + 8, z1 - 8, 8 do
		root:decor("PavingLine", Vector3.new(x1 - x0, 0.04, 0.2), Vector3.new(0, 0.14, z), Color3.fromRGB(204, 192, 176))
	end
	-- The Great Sakura: a thick old trunk that splits into limbs, a canopy as big as a house,
	-- the sacred rope round it, in a raised stone ring you can sit on.
	local t = root:within(CFrame.new(S.GreatSakura))
	t:part("TreeRing", Vector3.new(1.6, 17, 17), vertical(Vector3.new(0, 0.8, 0)), P.STONE, M.Slate, { shape = "Cylinder" })
	t:decor("TreeSoil", Vector3.new(0.1, 15, 15), vertical(Vector3.new(0, 1.62, 0)), Color3.fromRGB(110, 84, 60), nil, { shape = "Cylinder" })
	t:part("GreatTrunk", Vector3.new(16, 4.4, 4.4), vertical(Vector3.new(0, 9.6, 0)), P.BARK, M.Wood, { shape = "Cylinder" })
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2 + 0.4
		local cf, len = Kit.Span(Vector3.new(0, 14, 0), Vector3.new(math.cos(a) * 10, 21 + (k % 2) * 3, math.sin(a) * 10))
		t:decor("GreatLimb", Vector3.new(2, 2, len + 1), cf, P.BARK, M.Wood)
	end
	t:decor("Shimenawa", Vector3.new(0.9, 5.4, 5.4), vertical(Vector3.new(0, 7, 0)), Color3.fromRGB(216, 190, 130), nil, { shape = "Cylinder" })
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		t:decor("Shide", Vector3.new(0.5, 1.4, 0.08), CFrame.new(math.cos(a) * 2.75, 5.9, math.sin(a) * 2.75) * CFrame.Angles(0, -a, 0), P.PAPER)
	end
	local rng = Random.new(77)
	local shades = { P.SAKURA_DEEP, P.SAKURA, P.SAKURA_LIGHT }
	for k = 0, 13 do
		local a = k / 14 * math.pi * 2
		local r = if k % 2 == 0 then 9 else 5
		local size = rng:NextNumber(8, 11)
		t:decor("Blossom", Vector3.new(size, size, size), Vector3.new(math.cos(a) * r, 22 + rng:NextNumber(-1.5, 3), math.sin(a) * r),
			shades[k % 3 + 1], nil, { shape = "Ball", shadow = true })
	end
	t:decor("Blossom", Vector3.new(13, 13, 13), Vector3.new(0, 27, 0), P.SAKURA, nil, { shape = "Ball", shadow = true })
	t:decor("Petals", Vector3.new(0.06, 34, 34), vertical(Vector3.new(0, 0.13, 0)), P.SAKURA_LIGHT, nil, { shape = "Cylinder", transparency = 0.4 })
	-- Benches round it, facing out.
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2 + math.pi / 6
		local at = Vector3.new(math.cos(a) * 13, 0, math.sin(a) * 13)
		CityKit.Bench(t:within(CFrame.lookAt(at, at * 2)), Color3.fromRGB(196, 150, 104))
	end
	-- The dog statue.
	local dog = root:within(CFrame.new(-34, 0, -206) * CFrame.Angles(0, math.rad(-120), 0))
	dog:part("StatuePlinth", Vector3.new(5, 3.4, 4), Vector3.new(0, 1.7, 0), P.STONE, M.Slate)
	local bronze = Color3.fromRGB(110, 92, 70)
	dog:decor("DogBody", Vector3.new(1.6, 1.6, 3.2), Vector3.new(0, 4.6, 0.2), bronze, M.Metal)
	dog:decor("DogChest", Vector3.new(1.6, 2.4, 1.4), Vector3.new(0, 5, -1.2), bronze, M.Metal)
	dog:decor("DogHead", Vector3.new(1.4, 1.4, 1.6), Vector3.new(0, 6.6, -1.6), bronze, M.Metal)
	dog:decor("DogSnout", Vector3.new(0.8, 0.7, 0.9), Vector3.new(0, 6.3, -2.6), bronze, M.Metal)
	for _, x in ipairs({ -0.5, 0.5 }) do
		dog:decor("DogEar", Vector3.new(0.4, 0.7, 0.3), Vector3.new(x, 7.5, -1.4), bronze, M.Metal)
		dog:decor("DogLeg", Vector3.new(0.5, 1.6, 0.5), Vector3.new(x, 4.2, -1.4), bronze, M.Metal)
	end
	dog:decor("DogTail", Vector3.new(0.4, 0.4, 1.4), CFrame.new(0, 5.6, 1.9) * CFrame.Angles(math.rad(-40), 0, 0), bronze, M.Metal)
	CityKit.Board(dog:within(CFrame.new(0, 0, -2)), "ハチ公", 0, 2.2, 2.8, 1, Color3.fromRGB(90, 76, 60), P.CREAM, 0.1)
	-- The taxi rank: a lane, an island, a shelter and a queue of cabs.
	CityKit.Patch(root, "TaxiLane", 30, 62, -218, -176, 0.04, P.ROAD, M.Asphalt)
	root:part("TaxiIsland", Vector3.new(4, 0.6, 30), Vector3.new(38, 0.3, -197), P.KERB)
	CityKit.Shelter(At(root, 38, -192, "+x"), 10, "TAXI のりば")
	for k, z in ipairs({ -212, -200, -188 }) do
		CityKit.Car(root:within(CFrame.new(48, 0.14, z) * CFrame.Angles(0, 0, 0)), "taxi", if k == 2 then Color3.fromRGB(240, 196, 40)
			else Color3.fromRGB(30, 32, 38))
	end
	for z = -216, -178, 6 do
		root:decor("LaneLine", Vector3.new(0.35, 0.06, 3), Vector3.new(55, 0.15, z), P.LINE)
	end
	-- The koban: the little police box on the corner, its red lamp over the door.
	local koban = At(root, -48, -170, "+z")
	koban:part("Koban", Vector3.new(10, 9, 9), Vector3.new(0, 4.5, 4.5), Color3.fromRGB(196, 180, 160))
	koban:decor("KobanDoor", Vector3.new(4, 6, 0.3), Vector3.new(0, 3, -0.15), P.GLASS, M.Glass, { transparency = 0.3 })
	koban:decor("KobanRoof", Vector3.new(11, 1, 10), Vector3.new(0, 9.5, 4.5), Color3.fromRGB(90, 90, 96))
	koban:decor("KobanLamp", Vector3.new(1, 1, 1), Vector3.new(0, 8.2, -0.6), Color3.fromRGB(230, 50, 46), nil, { shape = "Ball" })
	CityKit.Board(koban, "交番 KOBAN", 0, 7, 6, 1.1, P.WHITE, P.KURO, 0.2)
	-- Planters, lamps and bikes round the square's edge.
	for _, x in ipairs({ -54, -20, 20 }) do
		CityKit.Planter(root:within(CFrame.new(x, 0, -170)), 10, x, true)
	end
	for _, at in ipairs({ { -56, -216 }, { -56, -180 }, { 24, -216 }, { 24, -172 }, { -24, -172 } }) do
		CityKit.StreetLamp(At(root, at[1], at[2], "+z"), false)
	end
	CityKit.BikeRow(At(root, -40, -219, "+z"), 9, 4)
	CityKit.BikeRow(At(root, 14, -219, "+z"), 6, 5)
	CityKit.Vending(At(root, -46, -219.6, "+z"), Color3.fromRGB(220, 52, 52), 1)
	CityKit.Vending(At(root, -50, -219.6, "+z"), Color3.fromRGB(40, 96, 204), 2)
	CityKit.PostBox(At(root, 26, -219, "+z"))
	-- Bike parking either side of the station, under a roof.
	for _, x in ipairs({ -51, 51 }) do
		local bp = At(root, x, -224, "+z")
		bp:decor("BikeRoof", Vector3.new(20, 0.4, 8), Vector3.new(0, 7.6, 4), Color3.fromRGB(196, 200, 204))
		for _, px in ipairs({ -9.6, 9.6 }) do
			bp:part("BikeRoofPost", Vector3.new(0.4, 7.6, 0.4), Vector3.new(px, 3.8, 7.6), P.STEEL)
		end
		CityKit.BikeRow(bp:within(CFrame.new(-2, 0, 4)), 7, x)
	end
end

--- The shrine off the square: through a red torii, a stone path between pines and cherry
--- trees to the hall on its stone floor, its bell (pull it to rest and heal).
local function shrine(root: B)
	local f = root:folder("Shrine")
	-- The grounds: gravel, a low wall round them with the torii in it.
	CityKit.Patch(f, "Gravel", -98, -62, -242, -166, 0.02, P.GRAVEL, M.Pebble)
	CityKit.Patch(f, "Approach", -96, -62, -203, -197, 0.06, P.STONE, M.Slate)
	for _, seg in ipairs({ { -242, -207 }, { -193, -166 } }) do
		f:part("ShrineWall", Vector3.new(1.4, 3.2, seg[2] - seg[1]), Vector3.new(-62.7, 1.6, (seg[1] + seg[2]) / 2), P.STONE, M.Slate)
		f:decor("ShrineWallCap", Vector3.new(2, 0.5, seg[2] - seg[1]), Vector3.new(-62.7, 3.45, (seg[1] + seg[2]) / 2), P.TILE_ROOF)
	end
	f:part("ShrineWall", Vector3.new(36, 3.2, 1.4), Vector3.new(-80, 1.6, -166.7), P.STONE, M.Slate)
	CityKit.Torii(At(f, -64.5, -200, "-x"), 10, 11)
	CityKit.Board(At(f, -64.2, -200, "+x"), CityKit.Stacked("花見社"), 0, 11.9, 1.4, 2.2, P.KURO, P.GOLD, 0.2)
	-- The hall: a stone floor, steps, red pillars, white walls, a green copper roof.
	local h = At(f, -76, -200, "+x")
	h:part("ShrineFloor", Vector3.new(20, 1.5, 22), Vector3.new(0, 0.75, 11), P.STONE, M.Slate)
	for k = 0, 2 do
		h:part("ShrineStep", Vector3.new(8, 0.5 * (k + 1), 1.2), Vector3.new(0, 0.25 * (k + 1), -1.2 * (3 - k) + 0.6), P.STONE, M.Slate)
	end
	h:part("Honden", Vector3.new(16, 8, 11), Vector3.new(0, 5.5, 15.5), P.PLASTER)
	for _, x in ipairs({ -8, -3, 3, 8 }) do
		h:part("ShrinePillar", Vector3.new(8, 0.9, 0.9), vertical(Vector3.new(x, 5.5, 4.4)), P.VERMILION, nil, { shape = "Cylinder" })
	end
	h:decor("ShrineDoor", Vector3.new(6, 6, 0.2), Vector3.new(0, 4.5, 9.9), P.WOOD_DARK)
	local copper = Color3.fromRGB(80, 140, 118)
	h:part("ShrineRoof", Vector3.new(22, 4.6, 12), CFrame.new(0, 11.8, 4), copper, M.Slate, { shape = "Wedge", collide = false })
	h:part("ShrineRoof", Vector3.new(22, 4.6, 12), CFrame.new(0, 11.8, 16) * CFrame.Angles(0, math.pi, 0), copper, M.Slate,
		{ shape = "Wedge", collide = false })
	h:decor("RoofRidge", Vector3.new(23, 1, 1.2), Vector3.new(0, 14.5, 10), darker(copper, 0.2))
	h:decor("Shimenawa", Vector3.new(0.8, 12, 0.8), CFrame.new(0, 9, 4) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(216, 190, 130))
	h:part("OfferingBox", Vector3.new(4, 2, 2), Vector3.new(0, 2.5, 2.2), P.WOOD, M.Wood)
	local bell = h:decor("ShrineBell", Vector3.new(1.4, 1.4, 1.4), Vector3.new(0, 8.4, 3), P.GOLD, M.Metal, { shape = "Ball" })
	bell:SetAttribute("PromptText", "Pray")
	bell:SetAttribute("PromptObject", "The Shrine · rest and heal")
	h:decor("BellRope", Vector3.new(0.3, 5, 0.3), Vector3.new(0, 5.6, 3), P.CRIMSON, M.Fabric)
	-- Lion-dogs and stone lanterns on guard, prayer plaques, the water basin.
	for _, x in ipairs({ -6, 6 }) do
		local dog = h:within(CFrame.new(x, 0, -6))
		dog:part("KomainuBase", Vector3.new(2.2, 1.2, 2.2), Vector3.new(0, 0.6, 0), P.STONE_DARK, M.Slate)
		dog:decor("KomainuBody", Vector3.new(1.6, 1.8, 1.4), Vector3.new(0, 2.1, 0.2), P.STONE, M.Slate)
		dog:decor("KomainuHead", Vector3.new(1.5, 1.3, 1.3), Vector3.new(0, 3.5, -0.3), P.STONE, M.Slate)
		CityKit.StoneLantern(h:within(CFrame.new(x * 1.35, 0, -9)), 1.1)
	end
	local ema = At(f, -70, -212, "+z")
	ema:part("EmaRack", Vector3.new(8, 4.4, 0.6), Vector3.new(0, 2.2, 0), P.WOOD, M.Wood)
	for k = -3, 3 do
		ema:decor("Ema", Vector3.new(0.9, 0.7, 0.1), Vector3.new(k * 1.05, 3 + (k % 2) * 0.8, -0.35), P.WOOD_LIGHT)
	end
	local basin = At(f, -84, -183, "-z")
	basin:part("Chozuya", Vector3.new(4, 2.2, 2.4), Vector3.new(0, 1.1, 0), P.STONE, M.Slate)
	basin:decor("ChozuyaWater", Vector3.new(3.4, 0.1, 1.8), Vector3.new(0, 2.16, 0), P.WATER)
	for _, x in ipairs({ -2.4, 2.4 }) do
		basin:decor("ChozuyaPost", Vector3.new(0.4, 6, 0.4), Vector3.new(x, 3, 0), P.WOOD_DARK)
	end
	basin:decor("ChozuyaRoof", Vector3.new(6, 0.4, 4), Vector3.new(0, 6.2, 0), copper)
	-- Trees round the grounds.
	for i, at in ipairs({ { -92, -236 }, { -78, -236 }, { -92, -172 }, { -76, -174 }, { -66, -232 }, { -66, -176 }, { -94, -220 },
		{ -94, -182 } }) do
		if i % 2 == 0 then
			CityKit.Sakura(f:within(CFrame.new(at[1], 0, at[2])), i * 11, 1.05)
		else
			CityKit.Pine(f:within(CFrame.new(at[1], 0, at[2])), i * 7, 1.1)
		end
	end
end

--- The department store across the square: five floors of glass over a row of display
--- windows, its name on the roof.
local function department(root: B)
	CityKit.Building(At(root, 62, -204, "-x"), {
		w = 76, d = 36, floors = 4, style = "office", colour = Color3.fromRGB(240, 234, 222), trim = Color3.fromRGB(196, 170, 120),
		shop = { jp = "花見百貨店", en = "HANAMI DEPT. STORE", colour = Color3.fromRGB(150, 30, 46), kind = "glass", awning = true },
		billboard = "HANAMI 百貨店", bcolour = Color3.fromRGB(150, 30, 46), left = true, right = true, seed = 101,
	})
	-- Hanging banners down its front.
	for k, z in ipairs({ -236, -226, -182, -172 }) do
		local c = if k % 2 == 0 then P.SAKURA_DEEP else Color3.fromRGB(150, 30, 46)
		root:decor("Banner", Vector3.new(0.3, 18, 3.6), Vector3.new(61.3, 26, z), c, M.Fabric)
		text(At(root, 61.1, z, "-x"), CityKit.Stacked(if k % 2 == 0 then "春の祭" else "桜まつり"), CFrame.new(0, 26, 0), 3, 16, P.WHITE,
			Enum.Font.GothamBlack)
	end
end

--- HANAMI GINZA: the covered shopping street from Road A to the canal, its glass roof on
--- arched ribs, paper lanterns and hanging banners all the way along; shops both sides. The
--- trader's counter is out in front of one of them.
local function arcade(root: B)
	local f = root:folder("Arcade")
	local z0, z1 = -154, -100
	CityKit.Patch(f, "ArcadeFloor", -8, 8, z0, z1, 0.02, Color3.fromRGB(214, 200, 180), M.Slate)
	for z = z0 + 3, z1 - 3, 6 do
		f:decor("FloorBand", Vector3.new(16, 0.04, 1), Vector3.new(0, 0.14, z), Color3.fromRGB(184, 120, 110))
	end
	-- The shops, both sides, three floors over them.
	local pick = function(k: number, n: number, w: number, rng: Random): any
		local styles = { "tile", "zakkyo", "mansion" }
		return { style = styles[rng:NextInteger(1, 3)], floors = rng:NextInteger(1, 3), colour = CityKit.FACADES[rng:NextInteger(1, #CityKit.FACADES)],
			shop = anyShop(rng), tenants = { TENANTS[rng:NextInteger(1, #TENANTS)], TENANTS[rng:NextInteger(1, #TENANTS)], TENANTS[rng:NextInteger(1, #TENANTS)] },
			back = true }
	end
	row(f, z0, z1, 8, "-x", 14, 201, function(k: number, n: number, w: number, rng: Random): any
		local spec = pick(k, n, w, rng)
		if k == 3 then
			-- The trader's: an arms dealer that looks like a hardware shop.
			spec.shop = { jp = "金物", en = "TRADER", colour = Color3.fromRGB(40, 58, 110), kind = "glass", awning = false }
			spec.style = "tile"
		end
		return spec
	end, 11)
	row(f, z0, z1, -8, "+x", 14, 202, pick, 11)
	-- The roof: a gable of glass on arched ribs.
	for z = z0, z1, 9 do
		for _, side in ipairs({ -1, 1 }) do
			local cf, len = Kit.Span(Vector3.new(side * 8.6, 16, z), Vector3.new(side * 3, 19.4, z))
			f:decor("Rib", Vector3.new(0.5, 0.5, len), cf, Color3.fromRGB(110, 120, 130))
			f:decor("RibPost", Vector3.new(0.5, 16, 0.5), Vector3.new(side * 8.6, 8, z), Color3.fromRGB(110, 120, 130))
		end
		f:decor("Rib", Vector3.new(6, 0.5, 0.5), Vector3.new(0, 19.4, z), Color3.fromRGB(110, 120, 130))
	end
	for _, side in ipairs({ -1, 1 }) do
		local cf, len = Kit.Span(Vector3.new(side * 8.6, 16.2, 0), Vector3.new(side * 3, 19.6, 0))
		local pane = f:decor("ArcadeGlass", Vector3.new(z1 - z0 + 2, 0.3, len), CFrame.new(0, 0, (z0 + z1) / 2) * cf,
			Color3.fromRGB(200, 226, 236), M.Glass, { transparency = 0.55 })
		pane.CastShadow = false
	end
	f:decor("ArcadeGlass", Vector3.new(6, 0.3, z1 - z0 + 2), Vector3.new(0, 19.6, (z0 + z1) / 2), Color3.fromRGB(200, 226, 236), M.Glass,
		{ transparency = 0.55 })
	-- The gates at each end, with the street's name.
	for _, gz in ipairs({ z0, z1 }) do
		local facing = if gz == z0 then "-z" else "+z"
		local g = At(f, 0, gz, facing)
		g:decor("GateBeam", Vector3.new(18, 4.4, 1.4), Vector3.new(0, 21.4, -0.7), Color3.fromRGB(150, 30, 46))
		text(g, "花見銀座", CFrame.new(-3.4, 21.6, -1.46), 9, 3.2, P.WHITE, Enum.Font.GothamBlack)
		text(g, "HANAMI GINZA", CFrame.new(5.2, 21.2, -1.46), 6, 1.2, P.GOLD, Enum.Font.GothamBold)
		for _, x in ipairs({ -8.6, 8.6 }) do
			g:decor("GatePost", Vector3.new(1, 23.6, 1), Vector3.new(x, 11.8, -0.7), Color3.fromRGB(150, 30, 46))
		end
		g:decor("SakuraSpray", Vector3.new(4, 4, 4), Vector3.new(-9, 23.2, -1), P.SAKURA, nil, { shape = "Ball" })
		g:decor("SakuraSpray", Vector3.new(4, 4, 4), Vector3.new(9, 23.2, -1), P.SAKURA_LIGHT, nil, { shape = "Ball" })
	end
	-- Lanterns and banners all the way along.
	for z = z0 + 6, z1 - 4, 9 do
		CityKit.Chochin(f, Vector3.new(-4, 14.6, z), P.LANTERN, 0.9)
		CityKit.Chochin(f, Vector3.new(4, 14.6, z), P.PAPER, 0.9)
		local c = CityKit.SIGNS[(z // 9) % 7 + 1]
		f:decor("Banner", Vector3.new(4.6, 3, 0.15), Vector3.new(0, 15.8, z + 4.5), c, M.Fabric)
		text(f, "SALE  春", CFrame.new(0, 15.8, z + 4.4), 4, 1.8, CityKit.Ink(c), Enum.Font.GothamBlack)
	end
	-- The trader's counter, out under the arcade in front of his shop.
	local S = HanamiConfig.Sites
	local stall = At(f, S.Merchant.X, S.Merchant.Z, "-x")
	stall:part("StallCounter", Vector3.new(7, 3.2, 2), Vector3.new(0, 1.6, 0), P.WOOD, M.WoodPlanks)
	stall:decor("StallTop", Vector3.new(7.4, 0.3, 2.4), Vector3.new(0, 3.35, 0), P.WOOD_DARK)
	for k = 0, 2 do
		stall:decor("Goods", Vector3.new(1.4, 1, 1.4), Vector3.new(-2.4 + k * 2.4, 4, 0.2), CityKit.SIGNS[k + 1])
	end
	local counter = stall:decor("HanamiCounter", Vector3.new(6, 0.08, 3), Vector3.new(0, 0.05, -2.6), Color3.fromRGB(40, 58, 110), M.Fabric)
	counter:SetAttribute("PromptText", "Open Shop")
	counter:SetAttribute("PromptObject", "Trader · guns & gear")
	counter:SetAttribute("OpenPanel", "Market")
	-- Benches and planters down the middle.
	for _, z in ipairs({ -142, -112 }) do
		CityKit.Planter(f:within(CFrame.new(0, 0, z) * CFrame.Angles(0, math.pi / 2, 0)), 6, z, true)
	end
	CityKit.Vending(At(f, -6.4, -134, "+x"), Color3.fromRGB(40, 96, 204), 7)
end

--- The blocks either side of the arcade, between Road A and the canal.
local function stationBlocks(root: B)
	-- East of the side street: the corner konbini, the road frontage, the canal frontage with
	-- the ramen shop (its roof has a seal on it) and a coin car park.
	row(root, 32, 98, -154, "-z", 16, 301, function(k: number, n: number, w: number, rng: Random): any
		if k == 1 then
			return { style = "mansion", floors = 3, colour = Color3.fromRGB(242, 236, 224),
				shop = { jp = "ハナミマート", en = "24H", colour = Color3.fromRGB(36, 150, 90), kind = "konbini" }, back = true }
		end
		return cityPick(2, 5)(k, n, w, rng)
	end)
	local canal: { { any } } = {
		{ 32, 44, { style = "tile", floors = 3, colour = CityKit.FACADES[3], shop = { jp = "喫茶", en = "CAFE", colour = Color3.fromRGB(120, 76, 50), kind = "glass", awning = true } } },
		{ 44, 56, { style = "zakkyo", floors = 2, colour = Color3.fromRGB(240, 226, 176), roof = "terrace", ladder = -1,
			shop = { jp = "ラーメン", en = "RAMEN", colour = Color3.fromRGB(214, 52, 44), kind = "noren" }, vsign = "ラーメン",
			vcolour = Color3.fromRGB(214, 52, 44), tenants = { "2F 麺屋" } } },
		{ 74, 98, { style = "office", floors = 3, colour = Color3.fromRGB(250, 246, 240), shop = { jp = "パチンコ", en = "PACHINKO", colour = Color3.fromRGB(230, 40, 120),
			kind = "glass" }, billboard = "パチンコ 777", bcolour = Color3.fromRGB(250, 204, 44), vsign = "パチンコ", vcolour = Color3.fromRGB(230, 40, 120) } },
	}
	for i, c in ipairs(canal) do
		local spec = c[3] :: any
		spec.w, spec.d, spec.seed = c[2] - c[1], 16, 310 + i
		spec.left, spec.right, spec.back = true, true, true
		spec.open = spec.ladder
		local b = At(root, (c[1] + c[2]) / 2, -100, "+z")
		local top = CityKit.Building(b, spec)
		if spec.ladder then
			-- The ladder up the side, onto the roof.
			CityKit.Ladder(b, Vector3.new(spec.ladder * (spec.w / 2 + 1.05), 0, spec.d * 0.6), top + 1)
		end
	end
	-- The coin car park between them.
	CityKit.Patch(root, "CarPark", 56, 74, -116, -100, 0.03, P.ROAD_DARK, M.Asphalt)
	for x = 60, 70, 5 do -- (the bay by the ladder is kept clear)
		root:decor("BayLine", Vector3.new(0.3, 0.06, 10), Vector3.new(x, 0.1, -110), P.LINE)
	end
	CityKit.Car(root:within(CFrame.new(62.5, 0.13, -109)), "kei", Color3.fromRGB(240, 240, 236))
	CityKit.Car(root:within(CFrame.new(67.5, 0.13, -109)), "kei", Color3.fromRGB(150, 196, 220))
	local sign = At(root, 73, -101, "+z")
	sign:part("ParkSign", Vector3.new(0.4, 8, 0.4), Vector3.new(0, 4, 0), P.STEEL)
	CityKit.Board(sign, "P  ¥300/h", 0, 7.4, 3.6, 2, Color3.fromRGB(250, 204, 44), P.KURO, 0.3)
	-- The side-street frontages and the Market Street ones.
	row(root, -138, -116, 32, "-x", 16, 320, cityPick(2, 4))
	row(root, -138, -116, 98, "+x", 16, 321, cityPick(2, 4))
	root:part("BlockCore", Vector3.new(34, 9, 22), Vector3.new(65, 4.5, -127), P.CONCRETE)

	-- West of the arcade: the bathhouse with its chimney, the drugstore, books, a cafe on the
	-- canal.
	block(root, -98, -32, -154, -100, 16, 330, function(k: number, n: number, w: number, rng: Random): any
		if k == 1 and rng:NextNumber() < 0.5 then
			return { style = "tile", floors = 1, colour = Color3.fromRGB(244, 236, 222),
				shop = { jp = "ゆ", en = "SENTO", colour = Color3.fromRGB(40, 70, 140), kind = "noren" }, back = true }
		end
		return cityPick(2, 5)(k, n, w, rng)
	end)
	-- The bathhouse chimney over the block.
	root:part("SentoChimney", Vector3.new(4, 40, 4), Vector3.new(-66, 20, -127), Color3.fromRGB(176, 120, 96), M.Brick)
	root:decor("ChimneyBand", Vector3.new(4.3, 2, 4.3), Vector3.new(-66, 36, -127), P.WHITE)
	text(At(root, -66, -129.1, "-z"), CityKit.Stacked("ゆ"), CFrame.new(0, 30, 0), 3, 3, P.KURO, Enum.Font.GothamBlack)
end

-- ------------------------------------------------------------------ the south districts --

local function railYard(root: B)
	local f = root:folder("RailYard")
	local S = HanamiConfig.Sites
	-- The sidings: four tracks on ballast, a buffer stop at the end of each.
	for i, z in ipairs({ -234, -225, -216, -207 }) do
		CityKit.Patch(f, "Ballast", -258, -112, z - 2.8, z + 2.8, 0.02, Color3.fromRGB(150, 140, 130), M.Pebble)
		for _, o in ipairs({ -1.3, 1.3 }) do
			f:decor("Rail", Vector3.new(146, 0.35, 0.3), Vector3.new(-185, 0.3, z + o), P.STEEL, M.Metal)
		end
		for x = -256, -114, 4.4 do
			f:decor("Sleeper", Vector3.new(0.8, 0.16, 4), Vector3.new(x, 0.16, z), Color3.fromRGB(110, 90, 72))
		end
		local stop = At(f, -112, z, "-x")
		stop:part("BufferStop", Vector3.new(4, 2.6, 1.4), Vector3.new(0, 1.3, 0.7), Color3.fromRGB(200, 60, 50))
		stop:decor("BufferStripe", Vector3.new(4.02, 0.6, 1.42), Vector3.new(0, 2.2, 0.7), P.LINE_YELLOW)
		-- Wagons with containers on them (cover in the yard), not on the track through the shed.
		if i ~= 2 then
			for k = 0, (if i == 4 then 1 else 2) do
				local x = -248 + k * 30 + i * 6
				if x < -212 or x > -146 then
					local w = f:within(CFrame.new(x, 0, z))
					w:part("Wagon", Vector3.new(26, 1.6, 4.8), Vector3.new(0, 2.2, 0), Color3.fromRGB(70, 76, 86))
					w:decor("WagonWheels", Vector3.new(22, 1.2, 4), Vector3.new(0, 0.9, 0), P.KURO)
					local cols = { Color3.fromRGB(64, 120, 200), Color3.fromRGB(220, 120, 60), Color3.fromRGB(60, 150, 100), Color3.fromRGB(196, 60, 60) }
					for j = 0, 1 do
						local c = cols[(i + k + j) % 4 + 1]
						w:part("Container", Vector3.new(11.6, 6, 4.6), Vector3.new(-6.2 + j * 12.4, 6, 0), c, M.CorrodedMetal)
						w:decor("ContainerDoor", Vector3.new(0.1, 5.4, 4.2), Vector3.new(-6.2 + j * 12.4 + 5.86, 6, 0), darker(c, 0.2))
						text(w, "JR貨物", CFrame.new(-6.2 + j * 12.4, 7.2, -2.36), 6, 1.4, P.WHITE, Enum.Font.GothamBlack)
					end
				end
			end
		end
	end
	-- The old brick shed the gang has taken over: open at both ends, the tracks running through.
	local shed = f:within(CFrame.new(-178, 0, -211))
	local brick = Color3.fromRGB(150, 80, 64)
	for _, z in ipairs({ -21, 21 }) do
		shed:part("ShedWall", Vector3.new(56, 16, 2), Vector3.new(0, 8, z), brick, M.Brick)
		for x = -24, 24, 8 do
			shed:decor("ShedWindow", Vector3.new(4, 5, 2.2), Vector3.new(x, 10, z), Color3.fromRGB(70, 80, 90), M.Glass)
		end
	end
	for _, side in ipairs({ -1, 1 }) do
		shed:part("ShedRoof", Vector3.new(58, 7, 23), CFrame.new(0, 19.5, side * 11.5) * CFrame.Angles(0, if side < 0 then 0 else math.pi, 0),
			Color3.fromRGB(120, 124, 130), M.CorrodedMetal, { shape = "Wedge" })
		for _, x in ipairs({ -28, 28 }) do
			shed:part("ShedGable", Vector3.new(0.6, 4, 40), Vector3.new(x, 18, 0), brick, M.Brick)
		end
	end
	shed:decor("ShedName", Vector3.new(20, 2, 0.4), Vector3.new(0, 14, -22.2), Color3.fromRGB(240, 230, 210))
	text(shed, "第二機関庫", CFrame.new(0, 14, -22.45), 18, 1.6, P.KURO, Enum.Font.GothamBlack)
	-- Inside: the gang's camp -- a fire in a drum, tarps, crates, a table with plans on it.
	local camp = f:within(CFrame.new(S.Camp))
	camp:part("FireDrum", Vector3.new(2.4, 1.8, 1.8), vertical(Vector3.new(6, 1.2, 2)), Color3.fromRGB(90, 70, 60), M.CorrodedMetal,
		{ shape = "Cylinder" })
	camp:decor("Fire", Vector3.new(1.6, 1.6, 1.6), Vector3.new(6, 2.8, 2), Color3.fromRGB(255, 150, 60), M.Neon, { shape = "Ball", transparency = 0.2 })
	camp:light("Point", Vector3.new(6, 4, 2), Color3.fromRGB(255, 160, 80), 2, 22)
	camp:part("CampTable", Vector3.new(6, 2.6, 3), Vector3.new(-6, 1.3, 8), P.WOOD, M.WoodPlanks)
	camp:decor("CampPlans", Vector3.new(3, 0.1, 2), Vector3.new(-6, 2.66, 8), P.PAPER)
	for k = 0, 3 do
		camp:part("Crate", Vector3.new(3, 3, 3), Vector3.new(-14 + k * 3.2, 1.5, -8), P.WOOD_LIGHT, M.WoodPlanks)
	end
	camp:decor("Tarp", Vector3.new(10, 0.2, 8), CFrame.new(-12, 6, 10) * CFrame.Angles(0, 0, math.rad(10)), Color3.fromRGB(60, 100, 160), M.Fabric)
	for i, c in ipairs(HanamiConfig.Captives) do
		-- A post each captive is tied to.
		local post = f:within(CFrame.new(c))
		post:part("CaptivePost", Vector3.new(0.8, 7, 0.8), Vector3.new(0, 3.5, 1.4), P.WOOD_DARK)
		CityKit.Marker(post, "CaptiveSpot", Vector3.new(0, 0.5, 0), { Index = i })
	end
	-- The signal box on its stilts, a stair up to its balcony.
	local box = f:within(CFrame.new(S.SignalBox))
	for _, x in ipairs({ -7, 7 }) do
		for _, z in ipairs({ -7, 7 }) do
			box:part("Stilt", Vector3.new(1, 9.4, 1), Vector3.new(x, 4.7, z), P.STEEL)
		end
	end
	box:part("BoxFloor", Vector3.new(16, 0.8, 16), Vector3.new(0, 9.6, 0), Color3.fromRGB(120, 126, 132), M.DiamondPlate)
	box:part("BoxHut", Vector3.new(12, 7, 10), Vector3.new(0, 13.5, 3), Color3.fromRGB(230, 222, 200))
	box:decor("BoxWindows", Vector3.new(12.1, 2.6, 10.1), Vector3.new(0, 14.4, 3), Color3.fromRGB(80, 110, 130), M.Glass)
	box:decor("BoxRoof", Vector3.new(13.4, 0.8, 11.4), Vector3.new(0, 17.4, 3), Color3.fromRGB(110, 60, 50))
	-- A rail round the balcony, open on the side the stair comes up.
	box:part("BoxRail", Vector3.new(16, 3, 0.3), Vector3.new(0, 11.5, -7.85), P.STEEL)
	box:part("BoxRail", Vector3.new(0.3, 3, 6), Vector3.new(7.85, 11.5, -5), P.STEEL)
	local st = f:within(CFrame.new(S.SignalBox.X - 21, 0, S.SignalBox.Z - 5) * CFrame.Angles(0, math.pi / 2, 0))
	CityKit.Stairs(st, Vector3.new(0, 0, 0), 3.4, 10, 13, Color3.fromRGB(120, 126, 132), M.DiamondPlate, 0.9)
	-- The fence along the yard, open at its gate.
	for _, seg in ipairs({ { -258, -200 }, { -186, -112 } }) do
		f:decor("Fence", Vector3.new(seg[2] - seg[1], 6, 0.2), Vector3.new((seg[1] + seg[2]) / 2, 3, -198), Color3.fromRGB(150, 160, 160),
			M.DiamondPlate, { transparency = 0.55 })
		f:part("FenceRail", Vector3.new(seg[2] - seg[1], 0.3, 0.3), Vector3.new((seg[1] + seg[2]) / 2, 6, -198), P.STEEL)
		for x = seg[1] + 2, seg[2] - 2, 8 do
			f:part("FencePost", Vector3.new(0.4, 6.4, 0.4), Vector3.new(x, 3.2, -198), P.STEEL)
		end
	end
	-- The danchi: two long slabs of flats with a balcony per flat, and their playground.
	for i, seg in ipairs({ { -252, -186 }, { -176, -114 } }) do
		local w = seg[2] - seg[1]
		CityKit.Building(At(root, (seg[1] + seg[2]) / 2, -150, "-z"), {
			w = w, d = 14, floors = 4, style = "mansion", colour = Color3.fromRGB(226, 228, 220), trim = Color3.fromRGB(190, 196, 196),
			left = true, right = true, seed = 400 + i, billboard = nil,
		})
		text(At(root, (seg[1] + seg[2]) / 2, -150, "-z"), (if i == 1 then "3" else "4") .. "号棟", CFrame.new(w / 2 - 4, 42, -2.7), 5, 3,
			Color3.fromRGB(60, 110, 180), Enum.Font.GothamBlack)
	end
	local park = f:within(CFrame.new(-182, 0, -118))
	CityKit.Patch(park, "Playground", -36, 36, -14, 14, 0.02, Color3.fromRGB(214, 190, 150), M.Sand)
	-- A slide, swings, a climbing dome, benches.
	park:part("SlideTower", Vector3.new(4, 6, 4), Vector3.new(-20, 3, 0), Color3.fromRGB(60, 140, 210))
	park:decor("Slide", Vector3.new(2.4, 0.4, 10), CFrame.new(-20, 3, 7) * CFrame.Angles(math.rad(-30), 0, 0), Color3.fromRGB(250, 196, 50))
	for _, x in ipairs({ 0, 8 }) do
		park:decor("SwingFrame", Vector3.new(0.4, 9, 0.4), Vector3.new(x - 3, 4.5, 0), Color3.fromRGB(220, 70, 60))
		park:decor("SwingFrame", Vector3.new(0.4, 9, 0.4), Vector3.new(x + 3, 4.5, 0), Color3.fromRGB(220, 70, 60))
	end
	park:decor("SwingBar", Vector3.new(14.4, 0.4, 0.4), Vector3.new(4, 9, 0), Color3.fromRGB(220, 70, 60))
	for _, x in ipairs({ 1, 7 }) do
		park:decor("SwingSeat", Vector3.new(1.8, 0.3, 1), Vector3.new(x, 2, 0), Color3.fromRGB(250, 204, 60))
		park:decor("SwingChain", Vector3.new(0.1, 7, 0.1), Vector3.new(x, 5.5, 0), P.STEEL)
	end
	park:decor("Dome", Vector3.new(8, 8, 8), Vector3.new(22, 0, 2), Color3.fromRGB(80, 180, 120), nil, { shape = "Ball", transparency = 0.45 })
	for _, x in ipairs({ -30, 30 }) do
		CityKit.Bench(park:within(CFrame.new(x, 0, 10) * CFrame.Angles(0, math.pi, 0)))
		CityKit.StreetTree(park:within(CFrame.new(x, 0, -10)), x)
	end
	CityKit.Vending(At(f, -112, -126, "-x"), Color3.fromRGB(236, 236, 230), 9)
	CityKit.Vending(At(f, -112, -122, "-x"), Color3.fromRGB(220, 52, 52), 10)
end

local function fishMarket(root: B)
	local f = root:folder("FishMarket")
	local S = HanamiConfig.Sites
	-- The auction hall: a long roof on steel columns, open all round.
	local x0, x1, z0, z1 = 130, 236, -236, -172
	CityKit.Patch(f, "HallFloor", x0, x1, z0, z1, 0.02, Color3.fromRGB(190, 196, 200), M.Concrete)
	for x = x0, x1, 13.25 do
		for _, z in ipairs({ z0, z1 }) do
			f:part("HallColumn", Vector3.new(1.2, 16, 1.2), Vector3.new(x, 8, z), Color3.fromRGB(70, 120, 160))
		end
	end
	local zc = (z0 + z1) / 2
	local half = (z1 - z0) / 2
	for _, side in ipairs({ -1, 1 }) do
		local r = f:part("HallRoof", Vector3.new(x1 - x0 + 6, 6, half + 3), CFrame.new((x0 + x1) / 2, 19, zc + side * (half + 3) / 2)
			* CFrame.Angles(0, if side < 0 then 0 else math.pi, 0), Color3.fromRGB(150, 176, 190), M.CorrodedMetal, { shape = "Wedge" })
		r.CastShadow = true
	end
	f:decor("HallBeam", Vector3.new(x1 - x0, 1, 1), Vector3.new((x0 + x1) / 2, 16, z0), Color3.fromRGB(70, 120, 160))
	f:decor("HallBeam", Vector3.new(x1 - x0, 1, 1), Vector3.new((x0 + x1) / 2, 16, z1), Color3.fromRGB(70, 120, 160))
	CityKit.Board(At(f, (x0 + x1) / 2, z1, "+z"), "魚市場  UOICHIBA", 0, 14, 30, 3, Color3.fromRGB(30, 60, 120), P.WHITE, 0.5)
	-- Rows of stalls: counters of fish on ice in blue tubs and white boxes.
	local fish = { Color3.fromRGB(200, 210, 220), Color3.fromRGB(236, 120, 80), Color3.fromRGB(150, 160, 176), Color3.fromRGB(220, 70, 60) }
	for _, rz in ipairs({ -228, -182 }) do
		for x = if rz > -200 then 162 else 138, 230, 12 do
			local st = f:within(CFrame.new(x, 0, rz))
			st:part("StallCounter", Vector3.new(9, 3, 4), Vector3.new(0, 1.5, 0), Color3.fromRGB(230, 232, 234))
			st:decor("Ice", Vector3.new(8.4, 0.3, 3.4), Vector3.new(0, 3.1, 0), Color3.fromRGB(236, 246, 250))
			for k = 0, 3 do
				st:decor("Fish", Vector3.new(1.6, 0.5, 0.8), CFrame.new(-3 + k * 2, 3.4, (k % 2) * 0.8 - 0.4) * CFrame.Angles(0, 0.3 * k, 0),
					fish[(x // 12 + k) % 4 + 1])
			end
			st:decor("Tub", Vector3.new(2, 1.2, 2), Vector3.new(5.6, 0.6, 0), Color3.fromRGB(60, 120, 200))
			st:decor("FoamBoxes", Vector3.new(2.4, 2.4, 1.8), Vector3.new(-5.8, 1.2, 0), Color3.fromRGB(244, 246, 248))
			st:decor("PriceTag", Vector3.new(1.6, 1, 0.1), Vector3.new(0, 5, 0), P.PAPER)
		end
	end
	-- The auction floor in the middle: tuna laid out in rows, the bell on its post.
	for k = 0, 5 do
		local t = f:within(CFrame.new(166 + k * 6, 0, -214))
		t:decor("Pallet", Vector3.new(3, 0.4, 5), Vector3.new(0, 0.2, 0), P.WOOD_LIGHT)
		t:decor("Tuna", Vector3.new(2, 1.8, 4.4), Vector3.new(0, 1.3, 0), Color3.fromRGB(110, 120, 140))
		t:decor("TunaTag", Vector3.new(0.8, 0.1, 0.6), Vector3.new(0, 2.24, -1), Color3.fromRGB(230, 60, 60))
	end
	local bell = f:within(CFrame.new(S.Market.X, 0, S.Market.Z + 18))
	bell:part("BellPost", Vector3.new(0.6, 7, 0.6), Vector3.new(0, 3.5, 0), P.STEEL)
	bell:decor("AuctionBell", Vector3.new(1.2, 1.2, 1.2), Vector3.new(0, 7.4, 0), P.GOLD, M.Metal, { shape = "Ball" })
	CityKit.Marker(f, "RaidSite", S.Market + Vector3.new(0, 1.4, 0))
	-- The office in the corner.
	CityKit.Building(At(f, 141, -172, "+z"), { w = 22, d = 14, floors = 1, style = "tile", colour = Color3.fromRGB(226, 226, 216),
		shop = { jp = "事務所", en = "OFFICE", colour = Color3.fromRGB(30, 60, 120), kind = "glass" }, seed = 501, left = true, right = true })
	-- Turret trucks and stacks of boxes.
	for i, at in ipairs({ { 150, -196, 0.4 }, { 214, -190, -0.8 }, { 200, -230, 1.6 }, { 124, -190, 0.2 } }) do
		local t = f:within(CFrame.new(at[1], 0, at[2]) * CFrame.Angles(0, at[3], 0))
		t:part("TurretBed", Vector3.new(4, 1.4, 7), Vector3.new(0, 1.3, 1), Color3.fromRGB(60, 110, 190))
		t:decor("TurretDrum", Vector3.new(2.4, 2.4, 2.4), vertical(Vector3.new(0, 2.4, -3)), Color3.fromRGB(220, 220, 214), nil, { shape = "Cylinder" })
		t:decor("TurretWheel", Vector3.new(0.5, 1.2, 1.2), CFrame.new(0, 0.6, -3), P.KURO, nil, { shape = "Cylinder" })
		if i % 2 == 0 then
			t:decor("FoamBoxes", Vector3.new(3.4, 1.6, 5), Vector3.new(0, 2.8, 1.4), Color3.fromRGB(244, 246, 248))
		end
	end
	for _, at in ipairs({ { 120, -226 }, { 244, -200 }, { 244, -184 } }) do
		f:part("BoxStack", Vector3.new(4, 5, 3), Vector3.new(at[1], 2.5, at[2]), Color3.fromRGB(244, 246, 248))
		f:decor("BoxLines", Vector3.new(4.04, 0.15, 3.04), Vector3.new(at[1], 2.5, at[2]), Color3.fromRGB(200, 210, 220))
	end
	-- Bars in the arches under the railway at the far end.
	for x = 120, 216, 24 do
		local a = At(f, x, -242, "+z")
		do
			a:part("ArchShop", Vector3.new(20, 12.6, 6), Vector3.new(0, 6.3, 3), Color3.fromRGB(176, 120, 96), M.Brick)
			CityKit.Board(a, IZAKAYA[(x // 24) % #IZAKAYA + 1][1], 0, 8.5, 10, 2, P.KURO, P.WHITE, 0.3)
			a:decor("ArchDoor", Vector3.new(4, 6, 0.3), Vector3.new(-4, 3, -0.15), Color3.fromRGB(246, 214, 160))
			for k = -1, 1 do
				a:decor("Noren", Vector3.new(1.25, 2.2, 0.1), Vector3.new(-4 + k * 1.3, 5, -0.6), Color3.fromRGB(40, 58, 110), M.Fabric)
			end
			CityKit.Chochin(a, Vector3.new(2, 6, -0.9), P.LANTERN, 0.9)
			CityKit.Crates(At(f, x + 6, -238, "+z"), x)
		end
	end
	-- North of Road A: sushi counters and wholesalers, a fish alley between them.
	block(root, 108, 176, -154, -100, 16, 520, cityPick(1, 3, 0.25))
	block(root, 184, 258, -154, -100, 16, 530, cityPick(1, 3, 0.25))
end

-- ------------------------------------------------------------------ the canal --

local function canal(root: B)
	local f = root:folder("Canal")
	local C = HanamiConfig.CANAL
	f:part("CanalBed", Vector3.new(524, 2, C.z1 - C.z0), Vector3.new(0, C.floor - 1, (C.z0 + C.z1) / 2), Color3.fromRGB(70, 90, 96), M.Slate)
	local water = f:decor("Water", Vector3.new(524, C.water - C.floor, C.z1 - C.z0), Vector3.new(0, (C.water + C.floor) / 2, (C.z0 + C.z1) / 2),
		P.WATER, M.Glass, { transparency = 0.3, reflectance = 0.15 })
	water.Name = "CanalWater"
	-- Stone walls either side, and the walk along the water on the south side.
	for _, z in ipairs({ C.z0, C.z1 }) do
		f:decor("CanalWall", Vector3.new(524, -C.floor, 0.6), Vector3.new(0, C.floor / 2, z + (if z == C.z0 then 0.3 else -0.3)), P.STONE, M.Slate)
	end
	f:part("RiverWalk", Vector3.new(524, 4, 4), Vector3.new(0, -4, C.z0 + 2), P.STONE, M.Slate)
	f:decor("RiverWalkTop", Vector3.new(524, 0.1, 4), Vector3.new(0, -1.95, C.z0 + 2), Color3.fromRGB(206, 196, 180), M.Slate)
	-- Steps down from the street to the walk, by each bridge.
	for _, x in ipairs({ -40, 24, -196, 124, 196 }) do
		-- Down along -X from the street's edge... a short flight against the wall.
		local st = f:within(CFrame.new(x, 0, C.z0 + 2) * CFrame.Angles(0, math.pi / 2, 0))
		CityKit.Stairs(st, Vector3.new(0, -2, -6), 3.6, 2, 3, P.STONE, M.Slate, 0.5)
	end
	-- Railings along both banks, cherry trees and lanterns.
	for _, side in ipairs({ { -88.6, -1 }, { -61.4, 1 } }) do
		local z = side[1]
		f:part("CanalRail", Vector3.new(524, 0.3, 0.3), Vector3.new(0, 3.2, z), Color3.fromRGB(70, 74, 82))
		f:part("CanalRailLow", Vector3.new(524, 3.2, 0.2), Vector3.new(0, 1.6, z), Color3.fromRGB(70, 74, 82), nil, { transparency = 0.85 })
		for x = -256, 256, 16 do
			f:decor("RailPost", Vector3.new(0.3, 3.2, 0.3), Vector3.new(x, 1.6, z), Color3.fromRGB(70, 74, 82))
		end
	end
	local k = 0
	local last: Vector3? = nil
	for x = -252, 252, 16 do
		k += 1
		local skip = math.abs(x) < 16 or math.abs(math.abs(x) - 160) < 16
		for _, z in ipairs({ -90.5, -59.5 }) do
			if not skip then
				CityKit.Sakura(f:within(CFrame.new(x + (if z > -70 then 8 else 0), 0, z)), k * 13 + z, 1.15)
			end
		end
		-- Pink and white festival lanterns strung between the trees on the south bank.
		local hang = Vector3.new(x, 9.5, -90.5)
		if last and not skip and (last :: Vector3).X > x - 17 then
			CityKit.LanternString(f, last :: Vector3, hang, 3, { P.SAKURA_LIGHT, P.WHITE, P.SAKURA })
		end
		last = if skip then nil else hang
	end
	-- The bridges: the red one in the middle (the main road), stone and steel either side.
	for _, spec in ipairs({ { 0, "red" }, { 160, "steel" }, { -160, "stone" } } :: { { any } }) do
		local x: number = spec[1]
		local kind: string = spec[2]
		local b = f:within(CFrame.new(x, 0, (C.z0 + C.z1) / 2))
		local w = if kind == "red" then 22 else 16
		local len = C.z1 - C.z0 + 4
		b:part("BridgeDeck", Vector3.new(w, 1.2, len), Vector3.new(0, -0.6, 0), if kind == "red" then P.ROAD else P.STONE,
			if kind == "red" then M.Asphalt else M.Slate)
		local rail = if kind == "red" then P.VERMILION elseif kind == "steel" then Color3.fromRGB(60, 110, 170) else P.STONE
		for _, s in ipairs({ -1, 1 }) do
			b:part("BridgeRail", Vector3.new(0.8, 3, len), Vector3.new(s * (w / 2 - 0.4), 1.5, 0), rail, if kind == "stone" then M.Slate else nil,
				{ transparency = if kind == "steel" then 0 else 0 })
			b:decor("BridgeBeam", Vector3.new(1.2, 3, len), Vector3.new(s * (w / 2 - 0.6), -2.6, 0), darker(rail, 0.2))
			if kind == "red" then
				for _, z in ipairs({ -len / 2 + 0.6, len / 2 - 0.6, 0 }) do
					b:decor("Giboshi", Vector3.new(1.2, 1.2, 1.2), Vector3.new(s * (w / 2 - 0.4), 3.5, z), P.GOLD, M.Metal, { shape = "Ball" })
				end
				b:decor("BridgeLamp", Vector3.new(0.4, 6, 0.4), Vector3.new(s * (w / 2 - 0.4), 6, 0), P.KURO)
				CityKit.Chochin(b, Vector3.new(s * (w / 2 - 0.4), 8.6, 0), P.PAPER, 1.1)
			end
		end
		b:decor("BridgeArch", Vector3.new(w - 2, 1.6, len - 2), Vector3.new(0, -2, 0), darker(rail, 0.1))
		if kind == "red" then
			CityKit.Board(At(b, 0, len / 2, "+z"), "花見橋", 0, 4.2, 6, 1.6, P.VERMILION, P.WHITE, 0.2)
		end
	end
	-- Boats moored in the canal.
	for i, at in ipairs({ { -96, -80 }, { 88, -70 }, { -220, -78 } }) do
		local boat = f:within(CFrame.new(at[1], C.water, at[2]) * CFrame.Angles(0, if i % 2 == 0 then math.pi else 0, 0))
		boat:decor("Hull", Vector3.new(16, 1.6, 4.6), Vector3.new(0, 0.2, 0), Color3.fromRGB(240, 236, 226))
		boat:decor("HullStripe", Vector3.new(16.04, 0.4, 4.64), Vector3.new(0, 0.6, 0), Color3.fromRGB(40, 90, 160))
		boat:decor("Cabin", Vector3.new(7, 2.4, 3.6), Vector3.new(-2, 2.2, 0), Color3.fromRGB(226, 232, 236))
		boat:decor("CabinRoof", Vector3.new(7.6, 0.3, 4.2), Vector3.new(-2, 3.55, 0), Color3.fromRGB(200, 70, 60))
	end
end

-- ------------------------------------------------------------------ the scramble --

--- A giant screen on a building front: a dark frame, a bright panel and what is on it.
local function screen(b: B, x: number, y: number, w: number, h: number, bg: Color3, label: string, out: number?)
	local o = out or 0
	local frame = b:decor("ScreenFrame", Vector3.new(w + 1, h + 1, 0.8), Vector3.new(x, y, -0.4 - o), P.KURO)
	frame.CastShadow = true
	b:decor("Screen", Vector3.new(w, h, 0.2), Vector3.new(x, y, -0.9 - o), bg)
	b:decor("ScreenGlow", Vector3.new(w, h * 0.32, 0.22), Vector3.new(x, y - h * 0.34, -0.92 - o), lighter(bg, 0.25))
	text(b, label, CFrame.new(x, y + h * 0.08, -1.06 - o), w * 0.9, h * 0.62, CityKit.Ink(bg), Enum.Font.GothamBlack)
end

local function scramble(root: B)
	local f = root:folder("Scramble")
	-- The roads: the avenue north-south, the cross street east-west, pavements round them.
	roadLines(f, false, -50, 0, 0, 24)
	roadLines(f, false, 20, 50, 0, 24)
	pavement(f, false, -50, -4, -12, -4, true)
	pavement(f, false, -50, -4, 12, 4, true)
	pavement(f, false, 24, 50, -12, -4, true)
	pavement(f, false, 24, 50, 12, 4, true)
	pavement(f, true, -50, -16, 0, -4, true)
	pavement(f, true, 16, 50, 0, -4, true)
	pavement(f, true, -50, -16, 20, 4, true)
	pavement(f, true, 16, 50, 20, 4, true)
	-- The crossing: zebras on all four sides and both diagonals.
	CityKit.Crosswalk(f, 0, -2, false, 24, 4)
	CityKit.Crosswalk(f, 0, 22, false, 24, 4)
	CityKit.Crosswalk(f, -14, 10, true, 20, 4)
	CityKit.Crosswalk(f, 14, 10, true, 20, 4)
	for _, d in ipairs({ 1, -1 }) do
		for k = -5, 5 do
			local at = Vector3.new(k * 2.1, 0.04, 10 + k * 2.1 * d)
			f:decor("Zebra", Vector3.new(1.2, 0.06, 3.4), CFrame.new(at) * CFrame.Angles(0, math.rad(45 * d), 0), P.LINE)
		end
	end
	-- Traffic lights on all four corners.
	for _, c in ipairs({ { -14, -2, "+x" }, { 14, 22, "-x" }, { 14, -2, "+z" }, { -14, 22, "-z" } } :: { { any } }) do
		CityKit.TrafficLight(At(f, c[1], c[2], c[3]), 8)
	end
	-- Guard rails along the kerbs, gaps at the crossings.
	for _, spec in ipairs({ { -12.4, -46, -6 }, { 12.4, -46, -6 }, { -12.4, 26, 46 }, { 12.4, 26, 46 } }) do
		f:part("GuardRail", Vector3.new(0.3, 2.4, spec[3] - spec[2]), Vector3.new(spec[1], 1.2, (spec[2] + spec[3]) / 2), P.WHITE)
	end
	-- The four corners.
	-- South-west (+X, -Z): the screen building, its big screen facing the crossing.
	local sw = At(f, 33, -4, "+z")
	local corner = Random.new(600)
	CityKit.Building(sw, { w = 34, d = 42, floors = 7, style = "office", colour = Color3.fromRGB(230, 230, 226), seed = 601,
		sideShops = { anyShop(corner, true), anyShop(corner), anyShop(corner, true) },
		shop = { jp = "スターバックス", en = "COFFEE", colour = Color3.fromRGB(30, 110, 80), kind = "glass", awning = true }, right = true,
		left = true, vsign = "ゲームセンター", vcolour = Color3.fromRGB(130, 70, 190), vside = 1 })
	screen(sw, 0, 46, 28, 16, Color3.fromRGB(236, 86, 150), "SAKURA 桜 FESTIVAL", 0.3)
	-- North-west (+X, +Z): a block of shops with a billboard on top.
	CityKit.Building(At(f, 33, 24, "-z"), { w = 34, d = 26, floors = 5, style = "zakkyo", colour = Color3.fromRGB(250, 242, 222), seed = 602,
		shop = { jp = "ドラッグ", en = "DRUGSTORE", colour = Color3.fromRGB(250, 212, 40), kind = "glass", awning = false },
		tenants = { "2F カラオケ", "3F 焼肉", "4F 英会話", "5F BAR" }, billboard = "KUROGANE 鋼", bcolour = Color3.fromRGB(34, 36, 44),
		sideShops = { anyShop(corner), anyShop(corner, true) },
		vsign = "カラオケ", vcolour = Color3.fromRGB(220, 52, 52), left = true, right = true })
	-- North-east (-X, +Z): tall zakkyo, all tenant signs.
	CityKit.Building(At(f, -33, 24, "-z"), { w = 34, d = 26, floors = 8, style = "zakkyo", colour = Color3.fromRGB(196, 214, 230), seed = 603,
		shop = { jp = "ゲーム", en = "ARCADE", colour = Color3.fromRGB(40, 96, 204), kind = "glass", awning = false },
		tenants = { "2F 漫画喫茶", "3F ネイル", "4F 麻雀", "5F 歯科", "6F ダンス", "7F 占い", "8F スナック" }, vsign = "漫画喫茶",
		sideShops = { anyShop(corner, true), anyShop(corner) },
		vcolour = Color3.fromRGB(250, 204, 44), left = true, right = true })
	screen(At(f, -33, 24, "-z"), 0, 52, 22, 12, Color3.fromRGB(40, 160, 200), "HANAMI 花見 CITY", 0.3)
	-- South-east (-X, -Z): the round tower on the corner, lower buildings behind.
	local tower = f:within(CFrame.new(-30, 0, -22))
	local th = 64
	tower:part("RoundTower", Vector3.new(th, 26, 26), vertical(Vector3.new(0, th / 2, 0)), Color3.fromRGB(196, 200, 206), nil, { shape = "Cylinder" })
	for y = 12, th - 6, 7.5 do
		tower:decor("Windows", Vector3.new(3.4, 26.3, 26.3), vertical(Vector3.new(0, y + 1.4, 0)), P.GLASS_DARK, M.Glass, { shape = "Cylinder", reflectance = 0.15 })
	end
	tower:decor("TowerBase", Vector3.new(10, 26.4, 26.4), vertical(Vector3.new(0, 5, 0)), Color3.fromRGB(60, 64, 72), nil, { shape = "Cylinder" })
	tower:decor("TowerCrown", Vector3.new(2, 27, 27), vertical(Vector3.new(0, th, 0)), Color3.fromRGB(236, 86, 150), nil, { shape = "Cylinder" })
	-- Its tall sign up the corner, out toward the crossing.
	local ts = tower:within(CFrame.lookAt(Vector3.new(0, 0, 0), Vector3.new(1, 0, 1)) * CFrame.new(0, 0, -13))
	ts:decor("TallSign", Vector3.new(4, 34, 1.2), Vector3.new(0, 34, -0.6), P.KURO)
	text(ts, CityKit.Stacked("ハナミ109"), CFrame.new(0, 34, -1.26), 3.4, 32, P.WHITE, Enum.Font.GothamBlack)
	CityKit.Building(At(f, -33, -50, "-z"), { w = 34, d = 12, floors = 2, style = "zakkyo", colour = CityKit.FACADES[2], seed = 606,
		shop = anyShop(Random.new(606), true), tenants = { "2F 歯科", "3F 塾" }, left = true, right = true })
	-- Lamps, bikes and vending machines on the corners.
	for _, at in ipairs({ { -14.5, -30, "+x" }, { 14.5, -30, "-x" }, { -14.5, 36, "+x" }, { 14.5, 36, "-x" } } :: { { any } }) do
		CityKit.StreetLamp(At(f, at[1], at[2], at[3]), true)
	end
	CityKit.BikeRow(At(f, 14, -18, "-x"), 6, 61)
	CityKit.Vending(At(f, -15.4, 40, "+x"), Color3.fromRGB(220, 52, 52), 62)
	CityKit.Vending(At(f, -15.4, 43.2, "+x"), Color3.fromRGB(236, 236, 230), 63)
	-- The avenue on to the castle: the great torii over it, stone lanterns, cherry trees.
	CityKit.Patch(f, "StairPlaza", -30, 30, 50, 64, 0.02, P.STONE, M.Slate)
	CityKit.Torii(f:within(CFrame.new(0, 0, 56)), 22, 18, P.VERMILION)
	CityKit.Board(At(f, 0, 55.4, "-z"), "黒金城", 0, 19.8, 3, 5, P.KURO, P.GOLD, 0.3)
	for _, x in ipairs({ -26, -18, 18, 26 }) do
		CityKit.StoneLantern(f:within(CFrame.new(x, 0, 58)), 1.3)
	end
	CityKit.Marker(f, "StairFoot", HanamiConfig.Sites.StairFoot + Vector3.new(0, 0.5, 0))
	-- The castle park either side of the stair: lawns, paths, cherry trees, a koi pond.
	for _, s in ipairs({ -1, 1 }) do
		local x0, x1 = if s < 0 then -50 else 16, if s < 0 then -16 else 50
		CityKit.Patch(f, "Lawn", x0, x1, 64, 96, 0.03, Color3.fromRGB(128, 186, 98), M.Grass)
		CityKit.Patch(f, "ParkPath", x0, x1, 78, 82, 0.05, P.GRAVEL, M.Pebble)
		for k = 0, 2 do
			CityKit.Sakura(f:within(CFrame.new(s * (22 + k * 11), 0, if k % 2 == 0 then 70 else 90)), k * 17 + s * 5, 1.25)
		end
		CityKit.Bench(f:within(CFrame.new(s * 33, 0, 84)), P.WOOD_LIGHT)
	end
	local pond = f:within(CFrame.new(-34, 0, 72))
	pond:decor("PondWater", Vector3.new(0.2, 12, 12), vertical(Vector3.new(0, 0.12, 0)), P.WATER, nil, { shape = "Cylinder" })
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		pond:part("PondStone", Vector3.new(2.4, 0.9, 1.6), CFrame.new(math.cos(a) * 6.4, 0.45, math.sin(a) * 6.4) * CFrame.Angles(0, -a, 0), P.STONE, M.Slate)
	end
	for k, c in ipairs({ Color3.fromRGB(250, 140, 60), P.WHITE, Color3.fromRGB(230, 80, 60) }) do
		pond:decor("Koi", Vector3.new(1.2, 0.2, 0.4), CFrame.new(-2 + k * 1.6, 0.26, (k % 2) * 2 - 1) * CFrame.Angles(0, k, 0), c)
	end
end

-- ------------------------------------------------------------------ Lantern Row --

local function lanternRow(root: B)
	local f = root:folder("LanternRow")
	-- The gate: an arch over the street with the name on it.
	local g = At(f, -50, 10, "+x")
	for _, x in ipairs({ -10.5, 10.5 }) do
		g:part("GatePost", Vector3.new(1.4, 18, 1.4), Vector3.new(x, 9, 0), P.KURO)
	end
	g:decor("GateBeam", Vector3.new(24, 4, 1.2), Vector3.new(0, 17, 0), P.CRIMSON)
	text(g, "ちょうちん横丁", CFrame.new(0, 17.4, -0.66), 20, 2.6, P.WHITE, Enum.Font.GothamBlack)
	text(At(f, -50, 10, "-x"), "LANTERN ROW", CFrame.new(0, 17.2, -0.66), 18, 2.4, P.GOLD, Enum.Font.GothamBlack)
	for x = -9, 9, 3 do
		CityKit.Chochin(g, Vector3.new(x, 14, -0.9), P.LANTERN, 0.9)
	end

	-- Stone paving down the main row and every alley: these are walking streets.
	local paving = Color3.fromRGB(176, 166, 154)
	CityKit.Patch(f, "Paving", -258, -50, -50, 96, 0.02, paving, M.Slate)
	for x = -250, -54, 6 do
		f:decor("GutterLine", Vector3.new(0.3, 0.04, 20), Vector3.new(x, 0.14, 10), darker(paving, 0.12))
	end
	-- The streets: the main row (the cross street on from the scramble), a south and a north
	-- alley, three alleys across them. Blocks of izakaya between, back to back.
	local xr = { { -250, -224 }, { -216, -164 }, { -156, -104 }, { -96, -50 } }
	local zr = { { -50, -36 }, { -28, 0 }, { 20, 52 }, { 60, 92 } }
	local seed = 700
	local function izakayaPick(terraceAt: { [number]: boolean }?, minW: number?): (number, number, number, Random) -> any
		return function(k: number, n: number, w: number, rng: Random): any
			local name = IZAKAYA[rng:NextInteger(1, #IZAKAYA)]
			local terrace = terraceAt ~= nil and terraceAt[k] == true
			return { izakaya = true, jp = name[1], en = name[2], terrace = terrace, upper = not (w < 9 and rng:NextNumber() < 0.5),
				noren = ({ Color3.fromRGB(40, 58, 110), P.CRIMSON, Color3.fromRGB(48, 96, 74), P.KURO, Color3.fromRGB(110, 60, 120) })[rng:NextInteger(1, 5)] }
		end
	end
	for zi, z in ipairs(zr) do
		for xi, x in ipairs(xr) do
			seed += 10
			local depth = math.floor((z[2] - z[1]) / 2)
			local x0, x1 = x[1], x[2]
			-- (The middle block's corner by the alley is the two climbable terraces: terraces().)
			if zi == 3 and xi == 3 then
				x1 = -116
			end
			row(f, x0, x1, z[1], "-z", depth, seed, izakayaPick(nil), 11)
			row(f, x0, x1, z[2], "+z", depth, seed + 1, izakayaPick(nil), 11)
		end
	end
	-- Lantern strings across the streets, wires and poles, bikes and crates at the doors.
	for x = -246, -60, 12 do
		CityKit.LanternString(f, Vector3.new(x, 15, 0.5), Vector3.new(x + 4, 15, 19.5), 5)
		if x % 24 == 6 then
			CityKit.LanternString(f, Vector3.new(x, 14, -35.5), Vector3.new(x + 3, 14, -28.5), 2)
			CityKit.LanternString(f, Vector3.new(x, 14, 52.5), Vector3.new(x + 3, 14, 59.5), 2)
		end
	end
	poleLine(f, Vector3.new(-246, 0, -33), Vector3.new(-60, 0, -33), 8, true)
	poleLine(f, Vector3.new(-246, 0, 57), Vector3.new(-60, 0, 57), 8, true)
	for _, x in ipairs({ -223, -163, -103 }) do
		poleLine(f, Vector3.new(x, 0, -44), Vector3.new(x, 0, 80), 5, false)
	end
	local rng = Random.new(77)
	for x = -244, -60, 9 do
		for _, z in ipairs({ 2.2, 17.8 }) do
			local roll = rng:NextNumber()
			local b = At(f, x + rng:NextNumber(-2, 2), z, if z < 10 then "-z" else "+z")
			if roll < 0.25 then
				CityKit.Crates(b, x)
			elseif roll < 0.4 then
				CityKit.BikeRow(b, rng:NextInteger(1, 3), x)
			elseif roll < 0.5 then
				CityKit.Rubbish(b, x)
			elseif roll < 0.6 then
				CityKit.Pots(b, x)
			end
		end
	end
	CityKit.Vending(At(f, -97, -1.6, "+z"), Color3.fromRGB(220, 52, 52), 71)
	CityKit.Vending(At(f, -163, 21.6, "-z"), Color3.fromRGB(40, 96, 204), 72)
	CityKit.CurveMirror(At(f, -97, 21, "-z"))
	-- An inari shrine in a nook: little red torii and a fox each side.
	local inari = At(f, -100, 82, "+z")
	for k = 0, 3 do
		CityKit.Torii(inari:within(CFrame.new(0, 0, -2 - k * 2.5)), 3.4, 4, P.VERMILION)
	end
	inari:part("Hokora", Vector3.new(3, 3.4, 2.4), Vector3.new(0, 1.7, -11.5), P.WOOD, M.Wood)
	inari:decor("HokoraRoof", Vector3.new(4, 0.6, 3.4), Vector3.new(0, 3.7, -11.5), P.TILE_ROOF)
	for _, x in ipairs({ -2.2, 2.2 }) do
		inari:decor("Kitsune", Vector3.new(0.8, 1.6, 1), Vector3.new(x, 0.8, -10), P.WHITE)
	end
end

--- The two climbable roof terraces at the end of the middle block (the rifleman's post, and
--- an iron seal), each with a ladder up its side in the alley. Built after the rows (so they
--- stand where the row's corner houses would be: those are left out).
local function terraces(root: B)
	for _, spec in ipairs({ { -110, 20, "-z" }, { -110, 52, "+z" } } :: { { any } }) do
		local b = At(root, spec[1], spec[2], spec[3])
		local side = if spec[3] == "-z" then 1 else -1
		local top = CityKit.Izakaya(b, { w = 12, d = 16, seed = 790 + (spec[2] :: number), jp = "焼鳥", en = "YAKITORI", terrace = true,
			open = side, left = side < 0, right = side > 0 })
		CityKit.Ladder(b, Vector3.new(side * 7.05, 0, 10), top + 1, P.STEEL)
	end
end

-- ------------------------------------------------------------------ the Steelworks --

local function steelworks(root: B)
	local f = root:folder("Steelworks")
	local S = HanamiConfig.Sites
	-- The gate.
	local g = At(f, 52, 10, "-x")
	for _, x in ipairs({ -11, 11 }) do
		g:part("GatePier", Vector3.new(3, 12, 3), Vector3.new(x, 6, 0), Color3.fromRGB(150, 150, 146), M.Concrete)
	end
	g:decor("GateBeam", Vector3.new(26, 3.4, 1.4), Vector3.new(0, 13.4, 0), P.KURO)
	text(g, "黒金製鉄所  KUROGANE STEEL", CFrame.new(0, 13.4, -0.76), 24, 2.4, P.GOLD, Enum.Font.GothamBlack)
	g:decor("SlidingGate", Vector3.new(12, 5, 0.3), Vector3.new(-17, 2.5, 0.4), Color3.fromRGB(200, 200, 196), M.DiamondPlate, { transparency = 0.3 })
	-- The guard booth, and the map someone left on its table.
	local booth = f:within(CFrame.new(60, 0, 40))
	booth:part("Booth", Vector3.new(8, 8, 8), Vector3.new(0, 4, 0), Color3.fromRGB(226, 228, 220))
	booth:decor("BoothWindow", Vector3.new(8.1, 3, 6), Vector3.new(0, 5, 0), P.GLASS, M.Glass)
	booth:decor("BoothRoof", Vector3.new(9, 0.6, 9), Vector3.new(0, 8.3, 0), Color3.fromRGB(70, 110, 160))
	-- The yard road, lines and a pipe rack along it.
	roadLines(f, true, 56, 196, 10, 20)
	for x = 60, 192, 12 do
		f:part("RackPost", Vector3.new(0.8, 12, 0.8), Vector3.new(x, 6, 24), P.STEEL)
		f:decor("RackArm", Vector3.new(0.6, 0.6, 5), Vector3.new(x, 11.6, 24), P.STEEL)
	end
	for k, c in ipairs({ Color3.fromRGB(200, 196, 180), Color3.fromRGB(110, 140, 180), Color3.fromRGB(230, 200, 60) }) do
		f:decor("Pipe", Vector3.new(134, 0.9, 0.9), Vector3.new(126, 12.4, 22.4 + k * 1.1), c, nil, { shape = "Cylinder" })
	end
	-- Warehouse one: open to the road, the ledger in its office corner.
	local w1 = f:within(CFrame.new(92, 0, -27))
	local tin = Color3.fromRGB(196, 206, 214)
	w1:part("WarehouseWall", Vector3.new(64, 16, 1), Vector3.new(0, 8, -19.5), tin, M.CorrodedMetal)
	w1:part("WarehouseWall", Vector3.new(1, 16, 40), Vector3.new(-31.5, 8, 0), tin, M.CorrodedMetal)
	w1:part("WarehouseWall", Vector3.new(1, 16, 40), Vector3.new(31.5, 8, 0), tin, M.CorrodedMetal)
	for _, x in ipairs({ -26, 26 }) do
		w1:part("WarehouseWall", Vector3.new(12, 16, 1), Vector3.new(x, 8, 19.5), tin, M.CorrodedMetal)
	end
	w1:part("WarehouseRoof", Vector3.new(66, 6, 21), CFrame.new(0, 19, -10.5), Color3.fromRGB(150, 160, 170), M.CorrodedMetal, { shape = "Wedge" })
	w1:part("WarehouseRoof", Vector3.new(66, 6, 21), CFrame.new(0, 19, 10.5) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(150, 160, 170),
		M.CorrodedMetal, { shape = "Wedge" })
	w1:decor("WarehouseLintel", Vector3.new(40, 3, 1.2), Vector3.new(0, 14.5, 19.5), tin, M.CorrodedMetal)
	CityKit.Board(At(w1, 0, 20.1, "+z"), "第一倉庫  WAREHOUSE 1", 0, 14.5, 20, 2, Color3.fromRGB(60, 110, 170), P.WHITE, 0.3)
	for k = 0, 5 do
		w1:part("Crate", Vector3.new(4, 4, 4), Vector3.new(-22 + (k % 3) * 5, 2, -12 + (k // 3) * 6), P.WOOD_LIGHT, M.WoodPlanks)
	end
	local lift = w1:within(CFrame.new(14, 0, 4) * CFrame.Angles(0, 0.6, 0))
	lift:part("Forklift", Vector3.new(4, 3, 6), Vector3.new(0, 1.8, 0), Color3.fromRGB(240, 180, 40))
	lift:decor("ForkMast", Vector3.new(3, 8, 0.6), Vector3.new(0, 4, -3.2), P.KURO)
	lift:decor("Forks", Vector3.new(2.6, 0.3, 3), Vector3.new(0, 0.8, -5), P.KURO)
	-- Warehouse two, shut, with a stack of containers between them.
	CityKit.Building(At(f, 171, -8, "+z"), { w = 42, d = 38, floors = 1, style = "tile", colour = Color3.fromRGB(150, 176, 196), seed = 801,
		shop = { jp = "第二倉庫", en = "WAREHOUSE 2", colour = Color3.fromRGB(60, 110, 170), kind = "shutter" }, left = true, right = true })
	local cols = { Color3.fromRGB(196, 78, 62), Color3.fromRGB(60, 112, 168), Color3.fromRGB(226, 170, 62), Color3.fromRGB(72, 136, 104) }
	local function container(at: CFrame, c: Color3)
		local b = f:within(at)
		b:part("Container", Vector3.new(5, 5.6, 12), Vector3.new(0, 2.8, 0), c, M.CorrodedMetal)
		for z = -5, 5, 2 do
			b:decor("ContainerRib", Vector3.new(5.06, 5.2, 0.2), Vector3.new(0, 2.8, z), darker(c, 0.15))
		end
	end
	container(CFrame.new(128, 0, -30), cols[1])
	container(CFrame.new(128, 5.6, -30), cols[2])
	container(CFrame.new(140, 0, -40) * CFrame.Angles(0, math.pi / 2, 0), cols[3])
	-- The site office, the orders on the table under its awning.
	CityKit.Building(At(f, 80, 56, "-z"), { w = 24, d = 12, floors = 1, style = "tile", colour = Color3.fromRGB(226, 228, 220), seed = 802,
		shop = { jp = "現場事務所", en = "SITE OFFICE", colour = Color3.fromRGB(60, 110, 170), kind = "glass", awning = true }, left = true, right = true })
	-- The container stacks by the yard.
	for k = 0, 4 do
		container(CFrame.new(104, 0, 34 + k * 13) * CFrame.Angles(0, math.pi / 2, 0), cols[k % 4 + 1])
		if k % 2 == 0 then
			container(CFrame.new(104, 5.6, 34 + k * 13) * CFrame.Angles(0, math.pi / 2, 0), cols[(k + 2) % 4 + 1])
		end
	end
	-- The furnace yard: the hall across its north side, the furnace mouth glowing, the stacks.
	CityKit.Patch(f, "YardFloor", 118, 200, 28, 80, 0.03, Color3.fromRGB(120, 116, 112), M.Concrete)
	local hall = At(f, 160, 80, "-z")
	hall:part("FurnaceHall", Vector3.new(96, 30, 16), Vector3.new(0, 15, 8), Color3.fromRGB(120, 92, 80), M.CorrodedMetal)
	hall:decor("HallBand", Vector3.new(96.2, 3, 16.2), Vector3.new(0, 26, 8), Color3.fromRGB(80, 60, 52))
	hall:decor("FurnaceMouth", Vector3.new(14, 10, 0.4), Vector3.new(0, 5, -0.2), Color3.fromRGB(255, 120, 40), M.Neon)
	hall:decor("FurnaceHood", Vector3.new(18, 2, 4), Vector3.new(0, 11, -2), P.KURO)
	hall:light("Point", Vector3.new(0, 5, -4), Color3.fromRGB(255, 130, 60), 3, 36)
	text(hall, "黒金", CFrame.new(0, 21, -0.1), 18, 7, Color3.fromRGB(240, 220, 200), Enum.Font.GothamBlack)
	-- The hall's face: windows high up, pipes down it, a catwalk and a stair, a conveyor, a sign.
	for x = -42, 42, 12 do
		hall:decor("HallWindow", Vector3.new(8, 3, 0.3), Vector3.new(x, 24, -0.1), Color3.fromRGB(240, 170, 90), M.Glass)
	end
	for _, x in ipairs({ -30, -26, 26, 30 }) do
		hall:decor("HallPipe", Vector3.new(26, 1.2, 1.2), vertical(Vector3.new(x, 13, -0.9)), Color3.fromRGB(150, 150, 150), nil, { shape = "Cylinder" })
	end
	hall:part("Catwalk", Vector3.new(70, 0.5, 3), Vector3.new(0, 15, -1.6), Color3.fromRGB(110, 116, 122), M.DiamondPlate)
	hall:decor("CatwalkRail", Vector3.new(70, 0.2, 0.2), Vector3.new(0, 17.4, -3), P.LINE_YELLOW)
	for x = -34, 34, 8.5 do
		hall:decor("CatwalkPost", Vector3.new(0.2, 2.4, 0.2), Vector3.new(x, 16.2, -3), P.LINE_YELLOW)
	end
	CityKit.Stairs(hall:within(CFrame.new(-40, 0, -4) * CFrame.Angles(0, math.pi / 2, 0)), Vector3.new(0, 0, 0), 3, 15, 18,
		Color3.fromRGB(110, 116, 122), M.DiamondPlate, 1)
	CityKit.Board(hall, "安全第一  SAFETY FIRST", 14, 19.5, 14, 2, Color3.fromRGB(40, 150, 90), P.WHITE, 0.3)
	local conveyor = f:within(CFrame.new(200, 0, 60))
	local cf, len = Kit.Span(Vector3.new(0, 1.5, -16), Vector3.new(0, 20, 18))
	conveyor:decor("Conveyor", Vector3.new(3, 1, len), cf, Color3.fromRGB(70, 76, 84))
	for _, z in ipairs({ -10, 2, 14 }) do
		local t = (z + 16) / 34
		conveyor:part("ConveyorLeg", Vector3.new(0.8, 1.5 + t * 18.5, 0.8), Vector3.new(0, (1.5 + t * 18.5) / 2, z), P.STEEL)
	end
	-- Steam over the stacks.
	for _, x in ipairs({ -38, 38 }) do
		for k = 0, 2 do
			f:decor("Smoke", Vector3.new(8 + k * 4, 8 + k * 4, 8 + k * 4), Vector3.new(160 + x + k * 3, 86 + k * 7, 90 - k * 4),
				Color3.fromRGB(230, 230, 232), nil, { shape = "Ball", transparency = 0.35 + k * 0.15 })
		end
	end
	for _, x in ipairs({ -38, 38 }) do
		local stack = f:within(CFrame.new(160 + x, 0, 90))
		stack:part("Chimney", Vector3.new(80, 6, 6), vertical(Vector3.new(0, 40, 0)), P.WHITE, M.Concrete, { shape = "Cylinder" })
		for y = 48, 76, 14 do
			stack:decor("ChimneyBand", Vector3.new(7, 6.2, 6.2), vertical(Vector3.new(0, y, 0)), Color3.fromRGB(220, 60, 50), nil, { shape = "Cylinder" })
		end
	end
	CityKit.Marker(f, "ForemanSpot", S.Foundry + Vector3.new(0, 0.5, 16))
	for _, at in ipairs({ { 140, 40 }, { 180, 40 }, { 160, 32 } }) do
		CityKit.Marker(f, "ForemanAddSpot", Vector3.new(at[1], 0.5, at[2]))
	end
	-- Ladles, ingots and a skip in the yard: cover for the fight.
	for _, at in ipairs({ { 132, 64 }, { 190, 66 } }) do
		f:part("Ladle", Vector3.new(6, 6, 6), vertical(Vector3.new(at[1], 3, at[2])), Color3.fromRGB(70, 66, 64), M.CorrodedMetal, { shape = "Cylinder" })
		f:decor("Molten", Vector3.new(0.3, 5, 5), vertical(Vector3.new(at[1], 6.1, at[2])), Color3.fromRGB(255, 140, 50), M.Neon, { shape = "Cylinder" })
	end
	for _, at in ipairs({ { 146, 50 }, { 174, 52 } }) do
		f:part("Ingots", Vector3.new(6, 2.4, 4), Vector3.new(at[1], 1.2, at[2]), Color3.fromRGB(110, 114, 122), M.Metal)
	end
	-- The quay: an apron of concrete, bollards, the crane, a ship alongside.
	CityKit.Patch(f, "Quay", 196, 212, -50, 96, 0.03, Color3.fromRGB(176, 176, 170), M.Concrete)
	f:part("DockBed", Vector3.new(50, 2, 146), Vector3.new(237, -7, 23), Color3.fromRGB(60, 80, 90), M.Slate)
	f:decor("DockWater", Vector3.new(50, 3.4, 146), Vector3.new(237, -4.3, 23), Color3.fromRGB(64, 128, 160), M.Glass, { transparency = 0.25 })
	f:decor("QuayWall", Vector3.new(0.6, 6, 146), Vector3.new(212.3, -3, 23), P.CONCRETE_DARK)
	f:part("QuayEdge", Vector3.new(1, 1.2, 146), Vector3.new(211.5, 0.6, 23), P.LINE_YELLOW)
	for z = -44, 90, 14 do
		f:part("Bollard", Vector3.new(1.4, 1.6, 1.4), vertical(Vector3.new(209.5, 0.8, z)), P.KURO, nil, { shape = "Cylinder" })
	end
	-- The ship.
	local ship = f:within(CFrame.new(238, 0, 22))
	local hullC = Color3.fromRGB(40, 60, 100)
	ship:part("ShipHull", Vector3.new(26, 12, 112), Vector3.new(0, 0, 0), hullC, M.Metal)
	ship:decor("ShipBoot", Vector3.new(26.2, 2, 112.2), Vector3.new(0, -4.6, 0), Color3.fromRGB(170, 50, 46))
	ship:part("ShipBow", Vector3.new(18, 12, 10), Vector3.new(0, 0, -61), hullC, M.Metal)
	ship:part("ShipBow", Vector3.new(8, 12, 6), Vector3.new(0, 0, -69), hullC, M.Metal)
	ship:decor("ShipDeck", Vector3.new(24, 0.4, 110), Vector3.new(0, 6.2, 0), Color3.fromRGB(150, 70, 60))
	ship:part("ShipBridge", Vector3.new(20, 14, 10), Vector3.new(0, 13, 46), P.WHITE)
	ship:decor("BridgeWindows", Vector3.new(20.2, 2, 10.2), Vector3.new(0, 18, 46), P.GLASS_DARK, M.Glass)
	ship:decor("Funnel", Vector3.new(5, 8, 5), Vector3.new(0, 24, 50), Color3.fromRGB(220, 60, 50))
	text(At(ship, -13.1, 0, "-x"), "KUROGANE MARU", CFrame.new(0, 2, 0), 40, 4, P.WHITE, Enum.Font.GothamBlack)
	for k = 0, 5 do
		for j = 0, 1 do
			local c = cols[(k + j) % 4 + 1]
			ship:part("Container", Vector3.new(10, 5, 12), Vector3.new(-5.2 + j * 10.4, 9, -40 + k * 13), c, M.CorrodedMetal)
		end
	end
	-- The crane: four legs on the quay, a machinery house, the boom out over the water, and a
	-- walkway between the legs with a ladder up to it.
	local crane = f:within(CFrame.new(S.Crane))
	local craneC = Color3.fromRGB(230, 120, 50)
	for _, x in ipairs({ -8, 8 }) do
		for _, z in ipairs({ -8, 8 }) do
			crane:part("CraneLeg", Vector3.new(1.6, 36, 1.6), Vector3.new(x, 18, z), craneC)
		end
		crane:decor("CraneBrace", Vector3.new(1, 1, 16), Vector3.new(x, 14, 0), craneC)
	end
	crane:part("CraneWalk", Vector3.new(18, 0.8, 18), Vector3.new(0, 27.6, 0), Color3.fromRGB(120, 126, 132), M.DiamondPlate)
	for _, spec in ipairs({ { Vector3.new(18, 3, 0.3), Vector3.new(0, 29.5, -9) }, { Vector3.new(18, 3, 0.3), Vector3.new(0, 29.5, 9) },
		{ Vector3.new(0.3, 3, 18), Vector3.new(9, 29.5, 0) } }) do
		crane:part("CraneRail", spec[1], spec[2], P.LINE_YELLOW)
	end
	crane:part("CraneHouse", Vector3.new(14, 6, 10), Vector3.new(0, 39, 0), craneC)
	crane:part("CraneBoom", Vector3.new(80, 2.4, 3), Vector3.new(30, 42, 0), craneC)
	crane:decor("CraneTie", Vector3.new(0.4, 0.4, 44), CFrame.new(18, 47, 0) * CFrame.Angles(0, math.pi / 2, 0) * CFrame.Angles(math.rad(14), 0, 0), P.STEEL)
	crane:decor("CraneApex", Vector3.new(2, 12, 2), Vector3.new(-2, 48, 0), craneC)
	crane:decor("Hook", Vector3.new(1, 10, 1), Vector3.new(50, 36, 0), P.KURO)
	CityKit.Ladder(crane, Vector3.new(-10, 0, -8), 28, P.LINE_YELLOW)
	-- Containers on the quay, the crates with ZEE on them among them.
	for k = 0, 2 do
		container(CFrame.new(205, 0, 56 + k * 13), cols[k % 4 + 1])
	end
	container(CFrame.new(205, 5.6, 69), cols[4])
	local crate = f:within(CFrame.new(200, 0, 40))
	crate:part("ZeeCrate", Vector3.new(3, 3, 3), Vector3.new(3.6, 1.5, 0), P.WOOD_LIGHT, M.WoodPlanks)
	text(At(crate, 3.6, -1.56, "-z"), "ZEE", CFrame.new(0, 1.6, 0), 2.4, 1.2, P.CRIMSON, Enum.Font.GothamBlack)
end

-- ------------------------------------------------------------------ Kurogane Castle --

local function castle(root: B)
	local f = root:folder("Castle")
	local S = HanamiConfig.Sites
	local P30 = HanamiConfig.PLATEAU
	local stone = Color3.fromRGB(150, 146, 140)
	-- The stone base: a block with its walls battered outward at the foot, courses picked out.
	f:part("CastleBase", Vector3.new(280, P30 + 6, 142), Vector3.new(0, (P30 - 6) / 2, 187), stone, M.Slate)
	local frontZ = 116
	for _, x in ipairs({ -76, 76 }) do
		f:part("Batter", Vector3.new(128, P30 + 6, 6), CFrame.new(x, (P30 - 6) / 2, frontZ - 3), stone, M.Slate, { shape = "Wedge" })
	end
	for _, s in ipairs({ -1, 1 }) do
		f:part("Batter", Vector3.new(142, P30 + 6, 6), CFrame.new(s * 143, (P30 - 6) / 2, 187) * CFrame.Angles(0, s * math.pi / 2, 0), stone, M.Slate,
			{ shape = "Wedge" })
	end
	for y = 4, P30 - 2, 6 do
		f:decor("Course", Vector3.new(280.4, 0.3, 0.3), Vector3.new(0, y, frontZ + 0.1), darker(stone, 0.18))
	end
	f:decor("Lawn", Vector3.new(272, 0.1, 134), Vector3.new(0, P30 + 0.05, 189), Color3.fromRGB(128, 180, 98), M.Grass)
	-- The moat in front of it.
	for _, s in ipairs({ -1, 1 }) do
		local xc = s * 81
		f:part("MoatBed", Vector3.new(138, 2, 16), Vector3.new(xc, -7, 104), Color3.fromRGB(60, 80, 86), M.Slate)
		f:decor("MoatWater", Vector3.new(138, 3.4, 16), Vector3.new(xc, -4.3, 104), Color3.fromRGB(70, 130, 150), M.Glass, { transparency = 0.25 })
		f:decor("MoatWall", Vector3.new(138, 6, 0.6), Vector3.new(xc, -3, 96.3), P.STONE, M.Slate)
		f:part("MoatRail", Vector3.new(138, 1, 1), Vector3.new(xc, 0.5, 96.5), P.STONE, M.Slate)
		-- The causeway's stone faces, down into the moat.
		f:decor("Causeway", Vector3.new(0.6, 6, 16), Vector3.new(s * 12.3, -3, 104), P.STONE, M.Slate)
	end
	-- THE THOUSAND GATES: the stair from the park up to the gate, a torii every few steps.
	CityKit.Stairs(f, Vector3.new(0, 0, 62), 24, P30, 54, P.STONE, M.Slate, 1)
	for z = 66, 112, 2.6 do
		local y = math.floor((z - 62) / 54 * P30)
		CityKit.Torii(f:within(CFrame.new(0, y, z)), 18, 10, P.VERMILION)
	end
	for z = 70, 110, 10 do
		local y = math.floor((z - 62) / 54 * P30)
		for _, x in ipairs({ -10.8, 10.8 }) do
			CityKit.StoneLantern(f:within(CFrame.new(x, y, z)), 0.8)
		end
	end
	-- The outer wall: white plaster on a stone footing, a dark tiled cap, loopholes.
	local plaster = Color3.fromRGB(244, 240, 230)
	local function wallRun(a: Vector3, c: Vector3)
		local cf, len = Kit.Span(a, c)
		f:part("CastleWall", Vector3.new(2.4, 9, len), cf * CFrame.new(0, 4.5, 0), plaster)
		f:decor("WallFoot", Vector3.new(2.8, 2, len), cf * CFrame.new(0, 1, 0), stone, M.Slate)
		f:decor("WallCap", Vector3.new(4.2, 1.2, len + 1), cf * CFrame.new(0, 9.4, 0), P.TILE_ROOF)
		f:decor("WallCapRidge", Vector3.new(1.4, 0.6, len + 1), cf * CFrame.new(0, 10.2, 0), P.TILE_ROOF_EDGE)
		for t = 4, len - 4, 8 do
			f:decor("Loophole", Vector3.new(2.5, 1, 0.8), cf * CFrame.new(0, 6, -len / 2 + t), P.KURO)
		end
	end
	local y = P30
	wallRun(Vector3.new(-136, y, 120), Vector3.new(-14, y, 120))
	wallRun(Vector3.new(14, y, 120), Vector3.new(136, y, 120))
	wallRun(Vector3.new(-136, y, 120), Vector3.new(-136, y, 254))
	wallRun(Vector3.new(136, y, 120), Vector3.new(136, y, 254))
	wallRun(Vector3.new(-136, y, 254), Vector3.new(136, y, 254))
	-- The gate house over the opening, and the gate's great doors standing open.
	local gate = f:within(CFrame.new(0, y, 120))
	for _, x in ipairs({ -12, 12 }) do
		gate:part("GatePier", Vector3.new(4, 14, 8), Vector3.new(x, 7, 0), stone, M.Slate)
	end
	gate:part("GateHouse", Vector3.new(32, 8, 10), Vector3.new(0, 18, 0), plaster)
	gate:decor("GateHouseBand", Vector3.new(32.2, 1.4, 10.2), Vector3.new(0, 15, 0), P.KURO)
	gate:part("GateRoof", Vector3.new(36, 4, 7), CFrame.new(0, 24, -3.5), P.TILE_ROOF, M.Slate, { shape = "Wedge" })
	gate:part("GateRoof", Vector3.new(36, 4, 7), CFrame.new(0, 24, 3.5) * CFrame.Angles(0, math.pi, 0), P.TILE_ROOF, M.Slate, { shape = "Wedge" })
	for _, s in ipairs({ -1, 1 }) do
		gate:decor("GateDoor", Vector3.new(9, 12, 0.8), CFrame.new(s * 10, 6, 4) * CFrame.Angles(0, s * math.rad(75), 0), P.WOOD_DARK, M.Wood)
	end
	CityKit.Board(At(gate, 0, -5, "-z"), "黒金", 0, 18, 6, 3, P.KURO, P.GOLD, 0.2)
	CityKit.Marker(f, "KeepGate", S.KeepGate + Vector3.new(0, 0.5, 0))
	-- Corner turrets.
	for _, x in ipairs({ -128, 128 }) do
		local t = f:within(CFrame.new(x, y, 128))
		t:part("Turret", Vector3.new(14, 12, 14), Vector3.new(0, 6, 0), plaster)
		t:decor("TurretBand", Vector3.new(14.2, 1.6, 14.2), Vector3.new(0, 3, 0), P.KURO)
		t:part("TurretRoof", Vector3.new(18, 5, 9), CFrame.new(0, 14.5, -4.5), P.TILE_ROOF, M.Slate, { shape = "Wedge" })
		t:part("TurretRoof", Vector3.new(18, 5, 9), CFrame.new(0, 14.5, 4.5) * CFrame.Angles(0, math.pi, 0), P.TILE_ROOF, M.Slate, { shape = "Wedge" })
		t:part("TurretTop", Vector3.new(9, 6, 9), Vector3.new(0, 19, 0), plaster)
		t:part("TurretRoof", Vector3.new(12, 3.6, 6), CFrame.new(0, 23.8, -3), P.TILE_ROOF, M.Slate, { shape = "Wedge" })
		t:part("TurretRoof", Vector3.new(12, 3.6, 6), CFrame.new(0, 23.8, 3) * CFrame.Angles(0, math.pi, 0), P.TILE_ROOF, M.Slate, { shape = "Wedge" })
	end
	-- The court: raked gravel, a stone path, banners down both sides, fire baskets.
	local box = HanamiConfig.CourtBox
	CityKit.Patch(f, "CourtGravel", box.x0, box.x1, box.z0, box.z1, y + 0.02, P.GRAVEL, M.Pebble)
	CityKit.Patch(f, "CourtPath", -5, 5, 124, box.z1, y + 0.06, P.STONE, M.Slate)
	for z = box.z0 + 6, box.z1 - 6, 14 do
		for _, x in ipairs({ box.x0 + 2, box.x1 - 2 }) do
			f:decor("BannerPole", Vector3.new(0.4, 16, 0.4), Vector3.new(x, y + 8, z), P.KURO)
			f:decor("Nobori", Vector3.new(0.2, 11, 3.4), Vector3.new(x, y + 9.5, z + 1.9), P.CRIMSON, M.Fabric)
			text(At(f, x + (if x < 0 then 0.12 else -0.12), z + 1.9, if x < 0 then "+x" else "-x"), CityKit.Stacked("黒金"), CFrame.new(0, y + 10, 0), 2.6, 8, P.WHITE,
				Enum.Font.GothamBlack)
		end
	end
	for _, x in ipairs({ -30, 30 }) do
		local fb = f:within(CFrame.new(x, y, 150))
		fb:part("Brazier", Vector3.new(3, 3, 3), vertical(Vector3.new(0, 3.5, 0)), P.KURO, M.Metal, { shape = "Cylinder" })
		fb:decor("BrazierLegs", Vector3.new(2, 2, 2), Vector3.new(0, 1, 0), P.KURO)
		fb:decor("Flame", Vector3.new(2.4, 2.4, 2.4), Vector3.new(0, 5.6, 0), Color3.fromRGB(255, 150, 60), M.Neon, { shape = "Ball", transparency = 0.2 })
		fb:light("Point", Vector3.new(0, 7, 0), Color3.fromRGB(255, 160, 90), 2, 26)
	end
	CityKit.Marker(f, "CourtCentre", S.Court + Vector3.new(0, 0.5, 0))
	for _, at in ipairs({ { -50, 160 }, { 50, 160 }, { -60, 196 }, { 60, 196 }, { -24, 200 }, { 24, 200 } }) do
		CityKit.Marker(f, "CourtAddSpot", Vector3.new(at[1], y + 0.5, at[2]))
	end
	-- The throne on its dais, gold screens behind it.
	local dais = f:within(CFrame.new(S.Throne))
	dais:part("Dais", Vector3.new(24, 1.2, 12), Vector3.new(0, 0.6, 0), P.KURO, M.Wood)
	dais:part("DaisStep", Vector3.new(16, 0.6, 2), Vector3.new(0, 0.3, -7), P.KURO, M.Wood)
	dais:part("Throne", Vector3.new(5, 3, 3), Vector3.new(0, 2.7, 2), P.CRIMSON)
	dais:decor("ThroneBack", Vector3.new(5, 5, 0.8), Vector3.new(0, 5, 3.4), P.KURO)
	for k = -2, 2 do
		dais:decor("Byobu", Vector3.new(4.4, 7, 0.3), CFrame.new(k * 4.3, 4.7, 5.2) * CFrame.Angles(0, (k % 2) * 0.3 - 0.15, 0), P.GOLD, M.Metal)
	end
	CityKit.Marker(dais, "ShogunSpot", Vector3.new(0, 1.7, -4))
	-- THE KEEP: a black castle on its own stone base -- five tiers, each with a skirt roof, white
	-- trim, the gold fish on the ridge.
	local keep = f:within(CFrame.new(0, y, 238))
	keep:part("KeepBase", Vector3.new(68, 10, 30), Vector3.new(0, 5, 0), stone, M.Slate)
	local black = Color3.fromRGB(42, 42, 48)
	local tiers = { { 60, 24, 12 }, { 50, 20, 10 }, { 40, 16, 10 }, { 30, 13, 9 }, { 20, 10, 9 } }
	local yy = 10
	for i, t in ipairs(tiers) do
		local w, d, h = t[1], t[2], t[3]
		keep:part("KeepTier", Vector3.new(w, h, d), Vector3.new(0, yy + h / 2, 0), black)
		keep:decor("KeepTrim", Vector3.new(w + 0.2, 0.8, d + 0.2), Vector3.new(0, yy + h - 1.4, 0), plaster)
		for x = -w / 2 + 4, w / 2 - 4, 6 do
			keep:decor("KeepWindow", Vector3.new(2, 2.4, d + 0.3), Vector3.new(x, yy + h / 2, 0), plaster)
		end
		-- The skirt roof, four wedges round the tier's top.
		local ry = yy + h + 1.2
		for _, s in ipairs({ -1, 1 }) do
			keep:part("KeepRoof", Vector3.new(w + 6, 3, 4), CFrame.new(0, ry, s * (d / 2 + 1)) * CFrame.Angles(0, if s < 0 then 0 else math.pi, 0),
				P.TILE_ROOF, M.Slate, { shape = "Wedge" })
			keep:part("KeepRoof", Vector3.new(d + 6, 3, 4), CFrame.new(s * (w / 2 + 1), ry, 0) * CFrame.Angles(0, s * -math.pi / 2, 0),
				P.TILE_ROOF, M.Slate, { shape = "Wedge" })
		end
		if i == 2 or i == 4 then
			-- A gable on the front, like the real ones.
			keep:part("KeepGable", Vector3.new(w * 0.4, 4, 3), CFrame.new(0, ry + 1.6, -d / 2 - 1.4), P.TILE_ROOF, M.Slate, { shape = "Wedge" })
			keep:decor("GableFace", Vector3.new(w * 0.3, 2.4, 0.2), Vector3.new(0, ry + 1, -d / 2 - 0.2), plaster)
		end
		yy += h + 3
	end
	keep:part("KeepCap", Vector3.new(22, 4, 12), CFrame.new(0, yy + 1, -3), P.TILE_ROOF, M.Slate, { shape = "Wedge" })
	keep:part("KeepCap", Vector3.new(22, 4, 12), CFrame.new(0, yy + 1, 3) * CFrame.Angles(0, math.pi, 0), P.TILE_ROOF, M.Slate, { shape = "Wedge" })
	for _, x in ipairs({ -10, 10 }) do
		keep:decor("Shachihoko", Vector3.new(1.4, 3, 2), CFrame.new(x, yy + 4, 0) * CFrame.Angles(0, 0, x / 100), P.GOLD, M.Metal)
	end
	-- Raked gravel, stone lanterns down the path, low hedges round the court (gaps to come
	-- and go through), and a pine in a stone planter either side of the dais.
	for z = box.z0 + 4, box.z1 - 4, 4 do
		f:decor("Raked", Vector3.new(box.x1 - box.x0 - 4, 0.04, 0.3), Vector3.new(0, y + 0.14, z), darker(P.GRAVEL, 0.08))
	end
	for _, x in ipairs({ -9, 9 }) do
		for z = 150, 196, 23 do
			CityKit.StoneLantern(f:within(CFrame.new(x, y, z)), 1.2)
		end
	end
	for _, x in ipairs({ box.x0 - 1.5, box.x1 + 1.5 }) do
		for _, seg in ipairs({ { box.z0, 170 }, { 182, box.z1 } }) do
			f:part("Hedge", Vector3.new(2.6, 2.6, seg[2] - seg[1]), Vector3.new(x, y + 1.3, (seg[1] + seg[2]) / 2), P.LEAF_DARK, M.Grass)
		end
	end
	for _, x in ipairs({ -22, 22 }) do
		local pl = f:within(CFrame.new(x, y, 206))
		pl:part("PinePlanter", Vector3.new(6, 1.6, 6), Vector3.new(0, 0.8, 0), P.STONE, M.Slate)
		CityKit.Pine(pl:within(CFrame.new(0, 1.6, 0)), x, 1.1)
	end
	-- The palace hall along the court's west side: a long wooden building on a stone footing,
	-- white walls between dark posts, sliding screens, a deep tiled roof; a tea house and its
	-- pond on the east.
	local palace = At(f, 92, 182, "-x", y)
	palace:part("PalaceFooting", Vector3.new(60, 1.6, 24), Vector3.new(0, 0.8, 12), stone, M.Slate)
	palace:part("Palace", Vector3.new(56, 10, 18), Vector3.new(0, 6.6, 13), plaster)
	for k = -7, 7 do
		palace:decor("PalacePost", Vector3.new(0.8, 10, 0.6), Vector3.new(k * 4, 6.6, 3.8), P.WOOD_DARK)
		if k < 7 then
			palace:decor("Shoji", Vector3.new(3, 6, 0.2), Vector3.new(k * 4 + 2, 5.2, 3.9), P.PAPER)
		end
	end
	palace:decor("Engawa", Vector3.new(58, 0.4, 3), Vector3.new(0, 1.8, 2.3), P.WOOD_LIGHT, M.WoodPlanks)
	palace:part("PalaceRoof", Vector3.new(62, 6, 13), CFrame.new(0, 14.6, 6.5), P.TILE_ROOF, M.Slate, { shape = "Wedge" })
	palace:part("PalaceRoof", Vector3.new(62, 6, 13), CFrame.new(0, 14.6, 19.5) * CFrame.Angles(0, math.pi, 0), P.TILE_ROOF, M.Slate,
		{ shape = "Wedge" })
	palace:decor("PalaceRidge", Vector3.new(63, 1, 1.4), Vector3.new(0, 17.8, 13), P.TILE_ROOF_EDGE)
	local tea = f:within(CFrame.new(-104, y, 196))
	tea:decor("PondWater", Vector3.new(0.2, 26, 26), vertical(Vector3.new(0, 0.12, 0)), P.WATER, nil, { shape = "Cylinder" })
	for k = 0, 13 do
		local a = k / 14 * math.pi * 2
		tea:part("PondStone", Vector3.new(3, 1, 2), CFrame.new(math.cos(a) * 13.4, 0.5, math.sin(a) * 13.4) * CFrame.Angles(0, -a, 0), P.STONE, M.Slate)
	end
	local bridge = tea:within(CFrame.new(0, 0, 0))
	bridge:decor("PondBridge", Vector3.new(4, 1.2, 28), CFrame.new(0, 1.4, 0), P.VERMILION)
	local house = tea:within(CFrame.new(-6, 0, -24))
	house:part("TeaHouse", Vector3.new(12, 7, 10), Vector3.new(0, 3.5, 0), P.PLASTER)
	house:decor("TeaPosts", Vector3.new(12.4, 7, 10.4), Vector3.new(0, 3.5, 0), P.WOOD_DARK, nil, { transparency = 0.85 })
	house:part("TeaRoof", Vector3.new(15, 4, 7), CFrame.new(0, 9, -3.5), Color3.fromRGB(150, 120, 80), M.Grass, { shape = "Wedge" })
	house:part("TeaRoof", Vector3.new(15, 4, 7), CFrame.new(0, 9, 3.5) * CFrame.Angles(0, math.pi, 0), Color3.fromRGB(150, 120, 80), M.Grass,
		{ shape = "Wedge" })
	-- Gardens either side of the court: pines, cherry trees, stone lanterns.
	for i, at in ipairs({ { -100, 140 }, { -126, 160 }, { -86, 226 }, { -116, 236 }, { 100, 140 }, { 126, 150 }, { 96, 226 }, { 116, 236 },
		{ -84, 160 }, { 84, 146 } }) do
		local b = f:within(CFrame.new(at[1], y, at[2]))
		if i % 2 == 0 then
			CityKit.Pine(b, i * 3, 1.3)
		else
			CityKit.Sakura(b, i * 5, 1.3)
		end
	end
end

-- ------------------------------------------------------------------ the north blocks --

local function northBlocks(root: B)
	-- The road along the moat, and the towers either side of the castle.
	for _, s in ipairs({ -1, 1 }) do
		local x0, x1 = if s < 0 then -258 else 150, if s < 0 then -150 else 258
		roadLines(root, true, x0, x1, 104, 16)
	end
	-- Kurogane HQ: a tower of dark glass, its name at the top.
	local hq = At(root, 198, 120, "-z")
	CityKit.Building(hq, { w = 60, d = 60, floors = 16, style = "office", colour = Color3.fromRGB(46, 50, 60), trim = Color3.fromRGB(30, 32, 38),
		shop = { jp = "黒金株式会社", en = "KUROGANE HOLDINGS", colour = P.KURO, kind = "lobby" }, left = true, right = true, seed = 901,
		billboard = "黒金 KUROGANE", bcolour = P.KURO })
	-- The hotel on the other side.
	CityKit.Building(At(root, -198, 120, "-z"), { w = 60, d = 50, floors = 12, style = "tile", colour = Color3.fromRGB(240, 232, 214), seed = 902,
		shop = { jp = "ホテル桜", en = "HOTEL SAKURA", colour = Color3.fromRGB(150, 30, 46), kind = "lobby", awning = true }, left = true, right = true,
		vsign = "ホテル", vcolour = Color3.fromRGB(150, 30, 46), billboard = "HOTEL SAKURA" })
	for _, s in ipairs({ -1, 1 }) do
		for k = 0, 2 do
			CityKit.Sakura(root:within(CFrame.new(s * (160 + k * 30), 0, 116)), k * 9 + s, 1.1)
		end
		CityKit.Building(At(root, s * 198, 190, "-z"), { w = 60, d = 60, floors = 6, style = "mansion", colour = CityKit.FACADES[if s < 0 then 4 else 9],
			seed = 905 + s, left = true, right = true })
	end
end

-- ------------------------------------------------------------------ the skyline --

local function skyline(root: B)
	local f = root:folder("Skyline")
	local rng = Random.new(4242)
	local H = HanamiConfig.HALF
	-- A ring of towers beyond the edge, so the city goes on.
	for k = 0, 71 do
		local a = k / 72 * math.pi * 2 + rng:NextNumber(-0.02, 0.02)
		local r = H + 60 + rng:NextNumber(0, 130)
		local x, z = math.cos(a) * r, math.sin(a) * r
		local w = rng:NextNumber(24, 44)
		local d = rng:NextNumber(24, 44)
		local h = rng:NextNumber(40, 150)
		local glassy = rng:NextNumber() < 0.4
		local c = if glassy then ({ Color3.fromRGB(110, 150, 180), Color3.fromRGB(90, 140, 150), Color3.fromRGB(70, 84, 104) })[rng:NextInteger(1, 3)]
			else CityKit.FACADES[rng:NextInteger(1, #CityKit.FACADES)]
		-- Turned to face the middle of the city.
		local b = f:within(CFrame.lookAt(Vector3.new(x, 0, z), Vector3.new(0, 0, 0)))
		b:decor("Tower", Vector3.new(w, h, d), Vector3.new(0, h / 2, 0), c, if glassy then M.Glass else nil, { reflectance = if glassy then 0.12 else 0 })
		local band = if glassy then lighter(c, 0.35) else (if rng:NextNumber() < 0.5 then P.GLASS_DARK else P.GLASS)
		for y = 10, h - 6, if glassy then 9 else 7 do
			b:decor(if glassy then "Band" else "Windows", Vector3.new(w + 0.2, if glassy then 1 else 3, d + 0.2), Vector3.new(0, y, 0), band,
				if glassy then nil else M.Glass)
		end
		-- A setback and a crown on the taller ones, a sign on some, the lit mast on the tallest.
		if h > 100 then
			local sh = h * 0.18
			b:decor("Setback", Vector3.new(w * 0.7, sh, d * 0.7), Vector3.new(0, h + sh / 2, 0), c, if glassy then M.Glass else nil)
			b:decor("Crown", Vector3.new(w * 0.74, 2, d * 0.74), Vector3.new(0, h + sh + 1, 0), lighter(c, 0.3))
			h += sh
		else
			b:decor("TowerTop", Vector3.new(w * 0.5, 4, d * 0.5), Vector3.new(0, h + 2, 0), darker(c, 0.2))
		end
		if rng:NextNumber() < 0.3 then
			local sc = CityKit.SIGNS[rng:NextInteger(1, 7)]
			b:decor("Billboard", Vector3.new(w * 0.8, w * 0.3, 0.6), Vector3.new(0, h - w * 0.2, -d / 2 - 0.4), sc)
		end
		if h > 150 then
			b:decor("Mast", Vector3.new(0.6, 16, 0.6), Vector3.new(0, h + 12, 0), P.STEEL)
			b:decor("AirLight", Vector3.new(1, 1, 1), Vector3.new(0, h + 20, 0), Color3.fromRGB(240, 60, 50), M.Neon)
		end
	end
	-- The ground the skyline stands on, round the city.
	for _, spec in ipairs({ { 0, -H - 400, 1660, 800 }, { 0, H + 400, 1660, 800 }, { -H - 400, 0, 800, H * 2 }, { H + 400, 0, 800, H * 2 } }) do
		f:decor("OuterGround", Vector3.new(spec[3], 1, spec[4]), Vector3.new(spec[1], -0.6, spec[2]), Color3.fromRGB(96, 98, 104), M.Asphalt)
	end
	-- HANAMI TOWER, red and white, a lattice on four legs.
	local t = f:within(CFrame.new(-330, 0, 380))
	local red, white = Color3.fromRGB(232, 80, 40), Color3.fromRGB(250, 250, 246)
	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local cf, len = Kit.Span(Vector3.new(sx * 30, 0, sz * 30), Vector3.new(sx * 6, 110, sz * 6))
			t:decor("TowerLeg", Vector3.new(3, 3, len), cf, red)
		end
	end
	for _, band in ipairs({ { 30, 46 }, { 60, 34 }, { 110, 14 } }) do
		t:decor("TowerRing", Vector3.new(band[2], 2, band[2]), Vector3.new(0, band[1], 0), white)
	end
	t:decor("Deck", Vector3.new(24, 8, 24), Vector3.new(0, 118, 0), white)
	t:decor("DeckGlass", Vector3.new(24.2, 3, 24.2), Vector3.new(0, 119, 0), P.GLASS, M.Glass)
	for k = 0, 3 do
		t:decor("Spire", Vector3.new(6 - k * 1.2, 22, 6 - k * 1.2), Vector3.new(0, 133 + k * 22, 0), if k % 2 == 0 then red else white)
	end
	-- The mountain, far off: a snow-capped cone over the city's west.
	local fuji = f:within(CFrame.new(900, -10, 1300))
	local n = 12
	local R, Hh = 640, 520
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2
		local w = 2 * R * math.tan(math.pi / n) * 1.04
		local cf = CFrame.Angles(0, a, 0) * CFrame.new(0, Hh / 2, -R / 2)
		fuji:decor("Mountain", Vector3.new(w, Hh, R), cf, Color3.fromRGB(110, 130, 170), M.Slate, { shape = "Wedge" })
		local r2, h2 = R * 0.3, Hh * 0.3
		local w2 = 2 * r2 * math.tan(math.pi / n) * 1.04
		local cf2 = CFrame.Angles(0, a, 0) * CFrame.new(0, Hh - h2 / 2 + 0.5, -r2 / 2)
		fuji:decor("Snow", Vector3.new(w2, h2, r2), cf2, Color3.fromRGB(244, 246, 252), M.Snow, { shape = "Wedge" })
	end
end

-- ------------------------------------------------------------------ the streets --

--- The ground, the roads and their paint, the pavements, the poles.
local function streets(root: B)
	local H = HanamiConfig.HALF
	local C = HanamiConfig.CANAL
	local g = root:folder("Ground")
	CityKit.Ground(g, "Street", -H, H, -H, C.z0, 0, P.ROAD)
	CityKit.Ground(g, "Street", -H, H, C.z1, 96, 0, P.ROAD)
	CityKit.Ground(g, "Street", -12, 12, 96, 116, 0, P.ROAD)
	CityKit.Ground(g, "Street", -H, -150, 96, H, 0, P.ROAD)
	CityKit.Ground(g, "Street", 150, H, 96, H, 0, P.ROAD)
	CityKit.Ground(g, "Street", -150, -140, 112, H, 0, P.ROAD)
	CityKit.Ground(g, "Street", 140, 150, 112, H, 0, P.ROAD)
	-- Road A (Ekimae-dori), the canal roads, the side streets.
	roadLines(g, true, -H, H, -160, 12)
	roadLines(g, true, -H, H, -96, 8)
	roadLines(g, true, -H, -12, -54, 8)
	roadLines(g, true, 12, 50, -54, 8)
	for _, x in ipairs({ -27, 27 }) do
		roadLines(g, false, -154, -100, x, 10)
	end
	for _, x in ipairs({ -103, 103 }) do
		roadLines(g, false, -242, -100, x, 10)
	end
	-- Pavements along Road A and the canal roads, where the buildings front them.
	pavement(g, true, -98, 98, -154, -3, true)
	pavement(g, true, 32, 98, -166, 3, false)
	pavement(g, true, 108, 258, -154, -3, true)
	pavement(g, true, -258, -108, -154, -3, true)
	-- Crossings.
	for _, x in ipairs({ -27, 27, -103, 103 }) do
		CityKit.Crosswalk(g, x, -160, true, 12, 8)
	end
	CityKit.Crosswalk(g, 0, -160, true, 12, 14)
	for _, x in ipairs({ -27, 27, -103, 103 }) do
		CityKit.RoadText(g, "止まれ", Vector3.new(x, 0, -147), math.pi, 6, 2.4)
		g:decor("StopLine", Vector3.new(9, 0.06, 0.6), Vector3.new(x, 0.03, -152.6), P.LINE)
	end
	-- Poles and wires down the side streets and Road A.
	poleLine(g, Vector3.new(-23, 0, -150), Vector3.new(-23, 0, -104), 3, false)
	poleLine(g, Vector3.new(23, 0, -150), Vector3.new(23, 0, -104), 3, false)
	poleLine(g, Vector3.new(-256, 0, -164.5), Vector3.new(-110, 0, -164.5), 6, true)
	poleLine(g, Vector3.new(110, 0, -164.5), Vector3.new(256, 0, -164.5), 6, true)
	poleLine(g, Vector3.new(-99, 0, -238), Vector3.new(-99, 0, -170), 3, false)
	poleLine(g, Vector3.new(99, 0, -238), Vector3.new(99, 0, -170), 3, false)
	-- Street furniture.
	CityKit.CurveMirror(At(g, -22.5, -153, "-z"))
	CityKit.CurveMirror(At(g, 22.5, -101, "+z"))
	for _, at in ipairs({ { -30, -166.6 }, { 104, -166.6 }, { -150, -166.6 }, { 160, -166.6 } }) do
		CityKit.StreetLamp(At(g, at[1], at[2], "+z"), true)
	end
	for _, x in ipairs({ -70, 70 }) do
		CityKit.Car(g:within(CFrame.new(x, 0, -163) * CFrame.Angles(0, math.pi / 2, 0)), if x < 0 then "kei" else "truck",
			if x < 0 then Color3.fromRGB(240, 196, 60) else Color3.fromRGB(236, 236, 230))
	end
	CityKit.Car(g:within(CFrame.new(-130, 0, -157) * CFrame.Angles(0, -math.pi / 2, 0)), "taxi", Color3.fromRGB(30, 32, 38))
	CityKit.Car(g:within(CFrame.new(190, 0, -157) * CFrame.Angles(0, -math.pi / 2, 0)), "van", Color3.fromRGB(240, 240, 236))
end

-- ------------------------------------------------------------------ build --

function City.Build(parent: Instance, centre: Vector3)
	local root = Kit.new(parent, CFrame.new(centre))
	local H = HanamiConfig.HALF

	-- The city's look while you are in it (ArenaMood.client reads these).
	parent:SetAttribute("ZoneCentre", centre + Vector3.new(0, 70, 0))
	parent:SetAttribute("ZoneHalf", Vector3.new(H + 30, 150, H + 30))
	for group, values in pairs(City.Look) do
		for property, value in pairs(values) do
			parent:SetAttribute(("Look_%s_%s"):format(group, property), value)
		end
	end

	streets(root)
	viaduct(root)
	station(root)
	square(root)
	shrine(root)
	department(root)
	arcade(root)
	stationBlocks(root)
	railYard(root)
	fishMarket(root)
	canal(root)
	scramble(root)
	lanternRow(root)
	terraces(root)
	steelworks(root)
	castle(root)
	northBlocks(root)
	skyline(root)

	CityKit.Marker(root, "HanamiArrival", HanamiConfig.Sites.Arrival + Vector3.new(0, 0.5, 0))
	Kit.Bounds(root, H - 2, H - 2, 220)

	-- Finding your way: landmarks on the compass, and the named areas.
	local function waypoint(name: string, icon: string, at: Vector3)
		local m = CityKit.Marker(root, "Waypoint", at + Vector3.new(0, 3, 0))
		m:SetAttribute("WaypointName", name)
		m:SetAttribute("WaypointIcon", icon)
		m:AddTag("Waypoint")
	end
	local S = HanamiConfig.Sites
	waypoint("GREAT SAKURA", "🌸", S.GreatSakura)
	waypoint("SHRINE", "⛩", S.Shrine)
	waypoint("HANAMI GINZA", "🏮", S.Arcade)
	waypoint("THE SCRAMBLE", "🚦", S.Scramble)
	waypoint("LANTERN ROW", "🏮", S.LanternGate)
	waypoint("STEELWORKS", "🏭", S.IronGate)
	waypoint("THE THOUSAND GATES", "⛩", S.StairFoot)
	waypoint("KUROGANE CASTLE", "🏯", S.Court)
	waypoint("RAIL YARD", "🚃", S.Camp)
	waypoint("FISH MARKET", "🐟", S.Market)
	for _, a in ipairs(HanamiConfig.Areas) do
		local y = a.y or 0
		local box = root:decor("Area", Vector3.new(a.x1 - a.x0, 40, a.z1 - a.z0), Vector3.new((a.x0 + a.x1) / 2, y + 18, (a.z0 + a.z1) / 2),
			P.CREAM, nil, { transparency = 1 })
		box:SetAttribute("AreaName", a.name)
		box:SetAttribute("AreaSub", a.sub)
		box:AddTag("Area")
	end
	local all = root:decor("Area", Vector3.new(H * 2, 160, H * 2), Vector3.new(0, 60, 0), P.CREAM, nil, { transparency = 1 })
	all:SetAttribute("AreaName", HanamiConfig.NAME)
	all:SetAttribute("AreaSub", "THE NEXT CHAPTER")
	all:AddTag("Area")

	-- Clues and seals: their props, and a marker for the service to wire.
	for _, clue in ipairs(HanamiConfig.Clues) do
		local c = root:within(CFrame.new(clue.at))
		c:part("ClueTable", Vector3.new(3.4, 2.6, 2.2), Vector3.new(0, 1.3, 0), P.WOOD, M.WoodPlanks)
		local paper = c:decor("Clue", Vector3.new(1.4, 0.1, 1), Vector3.new(0, 2.66, 0), P.PAPER)
		paper:SetAttribute("ClueId", clue.id)
		c:decor("ClueWeight", Vector3.new(0.5, 0.4, 0.5), Vector3.new(0.6, 2.85, 0.2), P.KURO)
	end
	for i, at in ipairs(HanamiConfig.Seals) do
		CityKit.Marker(root, "SealSpot", at + Vector3.new(0, 1.6, 0), { Index = i })
	end
end

return City
