--!nocheck
-- The city kit (DistrictService.MeshKit) in Downtown, checked without Studio:
--
--   * with no kit in the place, Downtown builds from parts exactly as it always has;
--   * with one (a stand-in here: plain parts named like the importer's MeshParts, scaled and
--     turned round the way an importer might leave them), the cars, lamps, trees, benches,
--     bins and hydrants are drawn from it -- every piece the manifest's size, the cars facing
--     the right way, the lamp globes still LanternGlass -- for far fewer parts;
--   * the meshes are only seen; the part-built solid pieces stay as invisible hulls, so
--     nothing collides or stops a bullet any differently;
--   * a model missing a piece is not used: that prop stays part-built.
--
--   lune run tools/uitest/meshkit.luau

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R

local Vector3, CFrame = roblox.Vector3, roblox.CFrame
local failures = 0
local function check(ok: boolean, what: string)
	if ok then
		print("  ok    " .. what)
	else
		failures += 1
		print("\27[31m  FAIL  " .. what .. "\27[0m")
	end
end

local place = World.loadPlace("build/Game.rbxl")
local sss = World.service("ServerScriptService")
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("ArenaService"), sss)
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("DistrictService"), sss)
local ss = World.service("ServerStorage")

local Downtown = World.require(sss.DistrictService.Downtown)
local MeshKit = World.require(sss.DistrictService.MeshKit)
local Data = World.require(sss.DistrictService.MeshKitData)
local centre = Vector3.new(-155, 1000, 1500)

local function build(name)
	local folder = R.new("Folder")
	folder.Name = name
	folder.Parent = World.workspace
	Downtown.Build(folder, centre)
	local count, byName = 0, {}
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") then
			count += 1
			byName[d.Name] = byName[d.Name] or {}
			table.insert(byName[d.Name], d)
		end
	end
	return folder, count, byName
end
local function n(byName, name)
	return byName[name] and #byName[name] or 0
end

print("no kit")
local plain, plainCount, plainNames = build("DowntownParts")
check(n(plainNames, "Paintwork") == 0 and n(plainNames, "Crook") > 0 and n(plainNames, "Slat") > 0,
	("part-built as before (%d parts)"):format(plainCount))
local lamps = n(plainNames, "LanternGlass")
plain.Parent = nil

-- The stand-in: every piece the manifest names, 3.2 times too big and the whole kit turned
-- half round, as an importer that works in other units and faces things the other way would.
local SCALE = 3.2
local turned = CFrame.Angles(0, math.pi, 0)
local function standIn(skip)
	local root = R.new("Model")
	root.Name = "CityKit"
	for model, spec in pairs(Data) do
		local group = R.new("Model")
		group.Name = model
		group.Parent = root
		for role, piece in pairs(spec) do
			if skip ~= model .. "_" .. role then
				local p = R.new("Part")
				p.Name = model .. "_" .. role
				p.Size = piece.size * SCALE
				p.CFrame = CFrame.new(40, 0, 70) * turned * CFrame.new(piece.offset * SCALE)
				p.Parent = group
			end
		end
	end
	return root
end

print("with the kit")
local kit = standIn("Bench_Paint")
kit.Parent = World.workspace     -- left in the world after importing: tidied into ServerStorage
MeshKit.Reset()
local folder, count, names = build("DowntownMeshes")
check(kit.Parent == ss, "a kit left in the world is put away in ServerStorage")
check(MeshKit.Has("Sedan") and MeshKit.Has("StreetLamp") and MeshKit.Has("Tree"), "the stand-in reads, turned and scaled")
check(count < plainCount - 1500, ("far fewer parts: %d, from %d"):format(count, plainCount))
local shells = names.Paintwork or {}
check(#shells >= 6, ("cars drawn from the kit (%d)"):format(#shells))
check(n(names, "LanternGlass") == lamps and n(names, "Crook") == 0,
	("every lamp from the kit, its globe still LanternGlass (%d)"):format(n(names, "LanternGlass")))
check(n(names, "Spoke") < n(plainNames, "Spoke") / 3, "no part-built wheels under the kit's cars")
check(n(names, "Slat") == n(plainNames, "Slat"), "a model missing a piece (the bench) stays part-built")

-- Each car's shell sits on its hull, the right size, nose toward the hull's -Z.
local good, worst = 0, ""
local visibleHull = 0
for _, shell in ipairs(shells) do
	local hullPart, best = nil, math.huge
	for _, b in ipairs(names.Body or {}) do
		local d = (b.Position - shell.Position).Magnitude
		if d < best and b.Parent == shell.Parent then
			hullPart, best = b, d
		end
	end
	local lamp = nil
	for _, h in ipairs(names.Headlight or {}) do
		if h.Parent == shell.Parent and (h.Position - shell.Position).Magnitude < 8 then
			lamp = h
		end
	end
	if hullPart and (hullPart.Transparency < 1 or not hullPart.CanCollide or not hullPart.CanQuery) then
		visibleHull += 1
	end
	if hullPart and lamp then
		local rel = hullPart.CFrame:PointToObjectSpace(shell.Position)
		local nose = hullPart.CFrame:PointToObjectSpace(lamp.Position)
		local sized = false
		for _, spec in pairs({ Data.Sedan.Body, Data.Hatch.Body, Data.SUV.Body }) do
			if (shell.Size - spec.size).Magnitude < 0.05 then
				sized = true
			end
		end
		if math.abs(rel.X) < 0.2 and math.abs(rel.Z) < 0.3 and nose.Z < -3 and sized then
			good += 1
		else
			worst = ("%s rel (%.2f, %.2f) nose z %.2f size %s"):format(shell:GetFullName(), rel.X, rel.Z, nose.Z, tostring(shell.Size))
		end
	end
end
check(good == #shells, ("every car shell on its hull, its size, nose forward (%d of %d) %s"):format(good, #shells, worst))

-- Seen, not touched; the hulls do the touching.
local solidMesh = 0
for _, p in ipairs(folder:GetDescendants()) do
	if p:IsA("BasePart") then
		if p.Name == "Paintwork" or p.Name == "Leaves" and p.Size.Magnitude > 6 or p.Name == "Iron" then
			if p.CanCollide or p.CanQuery then
				solidMesh += 1
			end
		end
	end
end
check(solidMesh == 0, "the meshes never collide or catch a bullet")
check(visibleHull == 0 and n(names, "Body") == n(plainNames, "Body") and n(names, "Cabin") == n(plainNames, "Cabin"),
	"every car keeps its solid body and cabin, as invisible hulls")
check(n(names, "Pole") == n(plainNames, "Pole") and n(names, "Trunk") == n(plainNames, "Trunk"), "lamp posts and trunks still solid")

-- A lamp's globe hangs where the part-built one did (half a stud higher: it stands on the pavement).
local pole, globe = nil, nil
for _, p in ipairs(names.Pole or {}) do
	for _, g in ipairs(names.LanternGlass or {}) do
		if not globe and p.Transparency == 1 and (g.Position - p.Position).Magnitude < 8 then
			pole, globe = p, g
		end
	end
end
local rel = pole and globe and pole.CFrame:PointToObjectSpace(globe.Position)
-- The pole is a cylinder turned upright, so its local X is up.
check(rel ~= nil and math.abs(rel.X - 5.6) < 0.3 and math.abs(Vector3.new(0, rel.Y, rel.Z).Magnitude - 3.8) < 0.3,
	("a lamp's globe hangs off its crook (%s)"):format(tostring(rel)))

print(if failures == 0 then "\27[32mall meshkit checks passed\27[0m" else ("\27[31m%d failed\27[0m"):format(failures))
process.exit(if failures == 0 then 0 else 1)
