--!strict
-- Ways up.
--
-- Every island already HAS height -- a band around y=20-35, another near y=90 -- but nothing
-- connects the low ground to it, so every fight happens on one plane. This adds the missing
-- half without reshaping anything.
--
-- It is a free-standing SWITCHBACK TOWER, not a stair laid on the slope. The first version
-- assumed the bank between the low and high points was a ramp and interpolated treads along
-- it; probing the real profile showed it is a cliff -- flat to z=62, then 9 studs to 23 in
-- one jump -- so most of that staircase was buried inside the rock with terrain standing
-- above it. A tower stands on the flat and never touches the cliff at all; a short bridge
-- crosses at the top.

local WorldBake = require(game:GetService("ServerScriptService").WorldBake)

local AscentService = {}

local WOOD = Color3.fromRGB(104, 72, 46)
local WOOD_DARK = Color3.fromRGB(74, 50, 32)
local LAMP = Color3.fromRGB(232, 186, 108)

-- Measured pairs: a standable high spot and standable low ground nearby.
--
-- "Ridge" is the one that fixes a trap rather than adding a view. All three MapExpansion
-- bridges -- to the ProvingGround, the WatchPoint and the Hollow -- climb onto the same
-- crest and then end in a sheer one-step drop onto the middle island: 25.0, 20.0 and 25.7
-- studs. Walkable falling off, impossible climbing back, so those three islets could only
-- ever be left, never entered on foot. The three drop points are all on ONE connected crest
-- (measured: 554 cells of 3 studs, all reachable from each other), so a single tower at the
-- lowest of them serves all three. Footing is 30 studs out on ground flat to within 1.5
-- studs, and it is walkable from the player spawn.
AscentService.Stairs = {
	{ zone = "Harbour", top = Vector3.new(-156, 29.5, 39),  bottom = Vector3.new(-156, 1.0, 69) },
	{ zone = "Flats",   top = Vector3.new(-543, 35.9, 249), bottom = Vector3.new(-543, 1.0, 207) },
	{ zone = "Reach",   top = Vector3.new(364, 32.8, 254),  bottom = Vector3.new(406, 1.9, 254) },
	{ zone = "Ridge",   top = Vector3.new(-200, 21.0, 267), bottom = Vector3.new(-170, 1.2, 265), flights = 1 },
}

AscentService.WIDTH = 6
AscentService.SLOPE = 35                -- degrees; shallow enough that nothing has to jump
AscentService.FLIGHTS = 2

-- Two short ramps that repair the places a MapExpansion bridge stops short of the ridge it
-- was built to land on. Both ends are measured, not guessed, and both were found by walking
-- a humanoid at them and watching it stop:
--
--   ProvingGround  the bridge ends at x -224 y 15.4 and the ridge resumes 6 studs away at
--                  y 20.3, with nothing in between -- a gap that needs a jump.
--   Hollow         the bridge deck starts 2.7 studs above the crest, just over the 2-stud
--                  step a humanoid will make, so the walker simply stopped at the edge.
--
-- The WatchPoint crossing needs nothing; it was walked end to end.
AscentService.Approaches = {
	{ name = "ProvingGround", from = Vector3.new(-217.5, 20.3, 230), to = Vector3.new(-225.5, 15.2, 230) },
	{ name = "Hollow",       from = Vector3.new(-188, 27.5, 306.5), to = Vector3.new(-188, 30.4, 311.5) },
}

local function folder(): Folder
	local f = workspace:FindFirstChild("Ascents")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Ascents"
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
	p.Material = material or Enum.Material.Wood
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

--- A switchback RAMP, not a flight of separate treads.
--
-- The tread version did not work, and it took walking a character up one to see it. Driving a
-- humanoid step by step up the Ridge tower gained 0.0 studs: the lowest tread sat 2.07 studs
-- above the ground -- right on the limit of what a humanoid will step onto -- and the
-- switchback left a 4.3-stud hole between the two flights. Pathfinding agreed, and not only
-- for the new one: of the three towers already standing, Flats and Reach could not be
-- pathfound bottom to top either. They had been decorative since the day they were built.
--
-- Solid ramps at a fixed shallow angle have neither failure. There is nothing to step up
-- onto, no gap to cross, and the navmesh treats a ramp as ordinary floor.
local function build(spec)
	local model = Instance.new("Model")
	model.Name = "Ascent_" .. spec.zone
	model.Parent = folder()

	local top, bottom = spec.top, spec.bottom
	local flat = Vector3.new(top.X - bottom.X, 0, top.Z - bottom.Z)
	local dir = flat.Unit                       -- from low ground toward the cliff
	local right = Vector3.new(-dir.Z, 0, dir.X)
	local W = AscentService.WIDTH
	-- One flight where there is room for it: a single ramp has no second lane to collide
	-- with and nothing overhead, so it is the shape to prefer whenever the ground allows.
	local flights = spec.flights or AscentService.FLIGHTS

	local height = top.Y - bottom.Y
	local rise = height / flights
	local run = rise / math.tan(math.rad(AscentService.SLOPE))

	-- Stand the tower on the flat, clear of the cliff face.
	local baseCentre = bottom + dir * 4

	-- Flights run in SEPARATE LANES side by side, not stacked on one line.
	--
	-- Stacking them was the first thing I tried and it does not work: two ramps climbing in
	-- opposite directions over the same ground converge at the switchback, and the headroom
	-- above the lower one fell to 1.22 studs -- an agent 5.5 studs tall simply cannot get
	-- through. Measured that way round: the upper flight and the bridge both pathfound fine,
	-- the lower flight was NoPath. Side by side there is nothing overhead at all.
	local lane = W / 2 + 0.5
	local WIDE = W * 2 + 1              -- a landing spans both lanes so you can turn round

	local function pad(name: string, centre: Vector3)
		return part(model, name, Vector3.new(WIDE, 0.8, 7), CFrame.lookAt(centre, centre + right), WOOD)
	end

	for flight = 0, flights - 1 do
		local y0 = bottom.Y + rise * flight
		local y1 = y0 + rise
		local along = (flight % 2 == 0) and right or -right
		-- The LOW flight takes the lane on the cliff side. The bridge leaves the top landing
		-- towards the cliff and has to cross one lane to get there; crossing the low one it
		-- clears by about 19 studs, crossing the high one it cut straight through the ramp at
		-- deck height and walled it off. Measured that way round -- everything else in the
		-- tower pathfound and this one flight did not.
		local laneOff = dir * ((flight % 2 == 0) and lane or -lane)
		local startP = baseCentre + laneOff + along * (-run / 2) + Vector3.new(0, y0, 0)
		local endP = baseCentre + laneOff + along * (run / 2) + Vector3.new(0, y1, 0)
		local mid = (startP + endP) / 2
		local length = (endP - startP).Magnitude
		part(model, "Ramp", Vector3.new(W, 0.8, length + 1.4),
			CFrame.lookAt(mid, mid + (endP - startP).Unit), WOOD)
		-- the landing overlaps the top of this ramp and the foot of the next
		pad("Landing", baseCentre + along * (run / 2 + 2.6) + Vector3.new(0, y1 - 0.4, 0))
	end

	-- A pad where the first ramp meets the ground, so the climb starts flush with the floor.
	pad("Footing", baseCentre + right * (-run / 2 - 2.6) + Vector3.new(0, bottom.Y - 0.4, 0))

	for _, sx in ipairs({ -1, 1 }) do
		for _, sz in ipairs({ -1, 1 }) do
			local corner = baseCentre + right * (sx * run / 2) + dir * (sz * (lane + W / 2 + 0.6))
			part(model, "Post", Vector3.new(0.7, height, 0.7),
				CFrame.new(corner + Vector3.new(0, bottom.Y + height / 2, 0)), WOOD_DARK)
		end
	end

	-- Bridge from the top landing across to the real high ground.
	local lastAlong = ((flights - 1) % 2 == 0) and right or -right
	local towerTop = baseCentre + lastAlong * (run / 2 + 2.6) + Vector3.new(0, top.Y, 0)
	local bstart = towerTop
	local bend = Vector3.new(top.X, top.Y, top.Z)
	local span = (bend - bstart).Magnitude + 4
	local mid = (bstart + bend) / 2 - Vector3.new(0, 0.3, 0)
	part(model, "Bridge", Vector3.new(W, 0.6, span), CFrame.lookAt(mid, mid + (bend - bstart).Unit), WOOD)
	local bflat = Vector3.new(bend.X - bstart.X, 0, bend.Z - bstart.Z)
	local bright = (bflat.Magnitude > 0.01) and Vector3.new(-bflat.Unit.Z, 0, bflat.Unit.X) or right
	for _, side in ipairs({ -1, 1 }) do
		local railAt = mid + bright * (side * (W / 2 - 0.2)) + Vector3.new(0, 1.6, 0)
		part(model, "BridgeRail", Vector3.new(0.35, 2.6, span),
			CFrame.lookAt(railAt, railAt + (bend - bstart).Unit), WOOD_DARK, nil, false)
	end

	local lamp = part(model, "Lamp", Vector3.new(0.8, 1.0, 0.8),
		CFrame.new(towerTop + Vector3.new(0, 3.0, 0)), LAMP, Enum.Material.Neon, false)
	local light = Instance.new("PointLight")
	light.Color = LAMP
	light.Brightness = 1.8
	light.Range = 26
	light.Parent = lamp

	return model, flights
end

--- Build the towers, adding to a baked folder rather than refusing it.
--
-- The plain Skip() pattern was wrong for this one. A baked Ascents folder made the service
-- return immediately, so a tower ADDED to the table above could never appear on a running
-- server -- it would wait for someone to re-bake, with nothing in the console to say so.
-- Now a baked folder keeps every tower already standing in it, exactly as before, and only
-- the missing ones get built.
--- A plank laid across a gap, flush with the surface at either end.
local function buildApproach(spec)
	local model = Instance.new("Model")
	model.Name = "Approach_" .. spec.name
	model.Parent = folder()

	local a, b = spec.from, spec.to
	local mid = (a + b) / 2 - Vector3.new(0, 0.4, 0)
	local length = (b - a).Magnitude + 3
	part(model, "Plank", Vector3.new(7, 0.8, length), CFrame.lookAt(mid, mid + (b - a).Unit), WOOD)
	for _, side in ipairs({ -1, 1 }) do
		local flat = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
		local across = (flat.Magnitude > 0.01) and Vector3.new(-flat.Unit.Z, 0, flat.Unit.X) or Vector3.new(1, 0, 0)
		local railAt = mid + across * (side * 3.3) + Vector3.new(0, 1.6, 0)
		part(model, "Rail", Vector3.new(0.3, 2.4, length),
			CFrame.lookAt(railAt, railAt + (b - a).Unit), WOOD_DARK, nil, false)
	end
	return model
end

function AscentService.Build()
	local f = folder()
	local baked = WorldBake.IsBaked("Ascents")
	if not baked then
		f:ClearAllChildren()
	end

	local built, kept, total = 0, 0, 0
	for _, spec in ipairs(AscentService.Stairs) do
		if baked and f:FindFirstChild("Ascent_" .. spec.zone) then
			kept += 1
		else
			local _, steps = build(spec)
			total += steps
			built += 1
		end
	end

	local approaches = 0
	for _, spec in ipairs(AscentService.Approaches) do
		if not (baked and f:FindFirstChild("Approach_" .. spec.name)) then
			buildApproach(spec)
			approaches += 1
		end
	end

	if baked then
		print(("[Ascents] baked copy kept -- %d towers left where they stand, %d added, %d approaches")
			:format(kept, built, approaches))
	else
		print(("[Ascents] %d switchback towers, %d ramp flights, %d bridge approaches")
			:format(built, total, approaches))
	end
end

AscentService.Build()

return AscentService
