--!strict
-- The duel maps: a set of bounded, fair places for a 1v1 to actually resolve.
--
-- Each map is a module beside this one (ArenaService.Court, .Dockyard, ...) that knows how to
-- build itself around a centre point and where its two spawns are. This service builds them
-- all at y=3000 -- well clear of the world (which tops out at 477) and of the measuring lane
-- at 2000 -- a thousand studs apart along X, and hands them out to bouts: every duel gets a
-- map of its own, so two duels at once never share a floor, and a pair who just played one
-- map are sent to a different one next.
--
-- Every map is laid out with 180-DEGREE ROTATIONAL symmetry (Kit.Both), not mirror
-- symmetry: rotate it half a turn and it is identical, so each player sees exactly the same
-- thing from their own spawn.
--
-- Each map's folder carries its zone and its look (time of day, atmosphere, grade) as
-- attributes; the client (ArenaMood) reads them and lights the map while you are in it.
--
-- Bake-aware like the rest of the world builds: once baked, the maps are ordinary geometry
-- you can drag around in Studio and the service leaves them alone.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local WorldBake = require(ServerScriptService.WorldBake)
local Kit = require(script.Kit)

local ArenaService = {}

ArenaService.ORIGIN = Vector3.new(0, 3000, 0)
ArenaService.SPACING = 1000
ArenaService.FOLDER = "Arenas"

-- The court keeps the original centre (anything that remembered the old arena still lands
-- in it); the others line up beyond it.
local ORDER = { "Court", "Dockyard", "Rooftops", "Temple" }

export type MapInfo = {
	Id: string,
	Name: string,
	Tagline: string,
	HalfWidth: number,
	HalfLength: number,
	Height: number,
	Spawns: { Vector3 },
	Look: { [string]: { [string]: any } }?,
	Build: (Instance, Vector3) -> (),
	centre: Vector3,
}

local maps: { MapInfo } = {}
local byId: { [string]: MapInfo } = {}

for index, id in ipairs(ORDER) do
	local module = script:FindFirstChild(id)
	if module and module:IsA("ModuleScript") then
		local ok, map = pcall(require, module)
		if ok and type(map) == "table" then
			local info = map :: any
			info.centre = ArenaService.ORIGIN + Vector3.new((index - 1) * ArenaService.SPACING, 0, 0)
			table.insert(maps, info :: MapInfo)
			byId[info.Id] = info :: MapInfo
		else
			warn(("[Arena] map %s failed to load: %s"):format(id, tostring(map)))
		end
	end
end

-- Kept for anything written against the single arena.
ArenaService.CENTRE = ArenaService.ORIGIN

local function root(): Folder
	local f = workspace:FindFirstChild(ArenaService.FOLDER)
	if not f then
		f = Instance.new("Folder")
		f.Name = ArenaService.FOLDER
		f.Parent = workspace
	end
	return f :: Folder
end

--- The zone and the look, as attributes the client can read. Written even when the maps are
--- baked, so a change to a map's look does not need a re-bake.
local function describe(folder: Instance, map: MapInfo)
	folder:SetAttribute("MapName", map.Name)
	folder:SetAttribute("Tagline", map.Tagline)
	folder:SetAttribute("ZoneCentre", map.centre + Vector3.new(0, map.Height / 2 - 5, 0))
	folder:SetAttribute("ZoneHalf", Vector3.new(map.HalfWidth + 6, map.Height / 2 + 25, map.HalfLength + 6))
	for group, values in pairs(map.Look or {}) do
		for property, value in pairs(values) do
			folder:SetAttribute(("Look_%s_%s"):format(group, property), value)
		end
	end
end

function ArenaService.Build()
	local folder = root()
	local skip = WorldBake.Skip(ArenaService.FOLDER, "Arena")
	for _, map in ipairs(maps) do
		local f = folder:FindFirstChild(map.Id)
		if not skip then
			if f then
				f:Destroy()
			end
			f = Instance.new("Folder")
			f.Name = map.Id
			local ok, err = pcall(map.Build, f, map.centre)
			if not ok then
				warn(("[Arena] %s failed to build: %s"):format(map.Id, tostring(err)))
			end
			f.Parent = folder
			print(("[Arena] %s built at %s, %d parts"):format(map.Name, tostring(map.centre), #f:GetDescendants()))
		end
		if f then
			describe(f, map)
		end
	end
end

-- -------------------------------------------------------------- handing out --

local inUse: { [string]: number } = {}
local lastPlayed: { [Player]: string } = {}

--- Pick a map for a bout between `players`: a free one, and not the one either of them just
--- played if there is any choice. Always returns a map; if every one is busy, two bouts share.
function ArenaService.Claim(players: { Player }): string
	local function pick(allowBusy: boolean, allowRepeat: boolean): string?
		local options = {}
		for _, map in ipairs(maps) do
			local busy = (inUse[map.Id] or 0) > 0
			local repeated = false
			for _, p in ipairs(players) do
				if lastPlayed[p] == map.Id then
					repeated = true
				end
			end
			if (allowBusy or not busy) and (allowRepeat or not repeated) then
				table.insert(options, map.Id)
			end
		end
		if #options == 0 then
			return nil
		end
		return options[math.random(1, #options)]
	end
	local id = pick(false, false) or pick(false, true) or pick(true, false) or pick(true, true) or "Court"
	inUse[id] = (inUse[id] or 0) + 1
	for _, p in ipairs(players) do
		lastPlayed[p] = id
	end
	return id
end

function ArenaService.Release(id: string?)
	if id and inUse[id] then
		inUse[id] = math.max(0, inUse[id] - 1)
	end
end

Players.PlayerRemoving:Connect(function(player)
	lastPlayed[player] = nil
end)

function ArenaService.Get(id: string?): MapInfo
	return (id and byId[id]) or maps[1]
end

function ArenaService.List(): { MapInfo }
	return maps
end

--- Where duellist `index` starts on map `id`, looking at their opponent. Also accepts just
--- an index (the court), which is what the single-arena version took.
function ArenaService.SpawnCFrame(id: string | number, index: number?): CFrame
	local map: MapInfo
	local i: number
	if type(id) == "number" then
		map, i = maps[1], id
	else
		map, i = ArenaService.Get(id), index or 1
	end
	local position = map.centre + (map.Spawns[i] or map.Spawns[1])
	local opposite = map.centre + map.Spawns[i == 1 and 2 or 1]
	return Kit.Look(position, Vector3.new(opposite.X, position.Y, opposite.Z))
end

--- The map a position is inside, or nil. Used to catch anyone who has left a map by means
--- nobody anticipated, rather than trusting that they cannot.
function ArenaService.Contains(position: Vector3): string?
	for _, map in ipairs(maps) do
		local d = position - map.centre
		if math.abs(d.X) <= map.HalfWidth + 4 and math.abs(d.Z) <= map.HalfLength + 4
			and d.Y > -20 and d.Y < map.Height + 10 then
			return map.Id
		end
	end
	return nil
end

ArenaService.Build()

return ArenaService
