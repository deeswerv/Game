--!strict
-- Turns an imported 3D model into a weapon this game can use.
--
-- Roblox's 3D importer drops a Model of MeshParts into Workspace. That model knows nothing
-- about our conventions: it is usually in metres rather than studs, its bore can run down
-- any axis, and its parts are named after gunsmithing rather than after the six names our
-- pose solver and attachment mounts look for.
--
-- This measures the model instead of assuming anything about it, scales it to a sensible
-- size, and republishes it as a Tool with a Handle in our frame -- bore down -Z, up +Y.
-- Part positions are never touched; only the Handle's orientation changes, so an imported
-- model cannot be distorted by being brought in.
--
-- Usage, once a model is imported and sitting in Workspace:
--
--   local Importer = require(game.ServerScriptService.WeaponImporter)
--   Importer.Convert(workspace.CompactCarbine, "Carbine", { length = 3.6 })

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WeaponFinish = require(ReplicatedStorage.WeaponFinish)
local WeaponMounts = require(ReplicatedStorage.WeaponMounts)

local WeaponImporter = {}

-- Imported part name -> the name our systems look for. First match wins, so the more
-- specific patterns come first. Everything unmatched keeps its own name, which is fine:
-- only these few drive the pose solver, the reload and the attachment mounts.
local RENAME = {
	{ "^MuzzleBore$", "MuzzleTip" },          -- kept separate; the real Muzzle is a marker
	{ "^BarrelTube$", "Barrel" },

	-- Magazine body. Each exporter names the main box slightly differently, so the
	-- specific spellings are listed before the catch-all that files the rest as MagMid.
	{ "^MagBody0$", "Magazine" },
	{ "^MagBodyUpper$", "Magazine" },
	{ "^MagBody$", "Magazine" },
	{ "^MagBody", "MagMid" },
	{ "^MagFloorplate$", "MagFloor" },
	{ "^MagBaseplate$", "MagFloor" },
	{ "^MagBasePad$", "MagBase" },
	{ "^MagBaseGrip$", "MagBase" },

	-- Where an optic mounts. A gun without a rail still has a flat to put one on.
	{ "^RailBase$", "Rail" },
	{ "^OpticRailBase$", "Rail" },
	{ "^AccessoryRail$", "Rail" },
	{ "^ReceiverTopFlat$", "Rail" },

	{ "^StockBody$", "Stock" },
	{ "^StockWrist$", "Stock" },
	{ "^HandguardBody$", "LowerHandguard" },
	{ "^ForendBody$", "LowerHandguard" },   -- a pump forend is also the off hand's grip
	{ "^GripBody$", "Grip" },
	{ "^GripFrame$", "Grip" },
	{ "^SlideBody$", "Slide" },              -- what a pistol's charging action racks
}

-- Parts whose name begins with "Mag" but which belong to the gun, not the magazine.
-- Everything else starting with "Mag" leaves on a reload.
local MAG_KEEP = {
	MagWell = true, MagWellFlare = true, MagFunnel = true, MagRelease = true,
	MagReleasePaddle = true, MagFeedLips = true,
	-- A shotgun's magazine is a tube under the barrel. It does not go anywhere.
	MagTube = true, MagTubeCap = true,
}

local function renameFor(name: string): string?
	for _, entry in ipairs(RENAME) do
		if name:match(entry[1]) then
			return entry[2]
		end
	end
	return nil
end

-- Find a part by trying several names in order.
local function findAny(model: Instance, names: { string }): BasePart?
	for _, name in ipairs(names) do
		for _, d in ipairs(model:GetDescendants()) do
			if d:IsA("BasePart") and d.Name == name then
				return d
			end
		end
	end
	return nil
end

local function centroidOf(model: Instance): Vector3
	local sum, n = Vector3.zero, 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			sum += d.Position
			n += 1
		end
	end
	return n > 0 and (sum / n) or Vector3.zero
end

-- Convert an imported model into a Tool in ReplicatedStorage.storeitems.
--
-- opts.length  finished length in studs (defaults to 3.6, about a carbine)
-- opts.grip    name of the part the hand should sit on
function WeaponImporter.Convert(model: Instance, weaponName: string, opts: { [string]: any }?)
	opts = opts or {}
	if not model then
		return "no model given"
	end

	local muzzle = findAny(model, { "MuzzleBore", "MuzzleCrown", "MuzzleTip", "Muzzle" })
	local grip = findAny(model, { opts.grip or "GripBody", "Grip", "Handle", "GripBackstrap" })
	if not muzzle then
		return "could not find a muzzle part -- expected MuzzleBore, MuzzleCrown or Muzzle"
	end
	if not grip then
		return "could not find a grip part -- expected GripBody, Grip or Handle"
	end

	-- Bore: body centre towards the muzzle. Measured, because an imported model's bore can
	-- run down any axis -- this one runs down X, not -Z like the models built in-engine.
	local centroid = centroidOf(model)
	local bore = muzzle.Position - centroid
	if bore.Magnitude < 1e-4 then
		return "degenerate bore"
	end
	bore = bore.Unit

	-- Up: the magazine hangs below the weapon, so magazine -> body points up it. Falls back
	-- to the rail when there is no magazine to measure from.
	local mag = findAny(model, { "MagBody0", "MagBodyUpper", "MagBody", "Magazine",
		"MagWell", "MagFloorplate" })
	local rail = findAny(model, { "RailBase", "Rail", "UpperReceiver" })
	local up
	if mag then
		up = centroid - mag.Position
	elseif rail then
		up = rail.Position - centroid
	else
		up = Vector3.new(0, 1, 0)
	end
	up = up - bore * up:Dot(bore)
	if up.Magnitude < 1e-4 then
		up = Vector3.new(0, 1, 0) - bore * Vector3.new(0, 1, 0):Dot(bore)
	end
	up = up.Unit
	local right = bore:Cross(up).Unit

	local existing = ReplicatedStorage.storeitems:FindFirstChild(weaponName)
	if existing then
		existing:Destroy()
	end

	local tool = Instance.new("Tool")
	tool.Name = weaponName
	tool.RequiresHandle = true
	tool.CanBeDropped = false

	-- The Handle carries our frame. Nothing else is moved.
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(0.3, 0.8, 0.42)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.CanQuery = false
	handle.Massless = true
	handle.CFrame = CFrame.fromMatrix(grip.Position, right, up, -bore)
	handle.Parent = tool

	local copied = 0
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			local copy = d:Clone()
			for _, child in ipairs(copy:GetDescendants()) do
				if not (child:IsA("DataModelMesh") or child:IsA("SurfaceAppearance")) then
					child:Destroy()
				end
			end
			copy.Anchored = false
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.Massless = true
			copy.CastShadow = false
			-- Tag the magazine before renaming, while the exporter's own naming is still
			-- intact. ReloadAnimator collects by this tag, so an imported weapon never
			-- needs its twelve magazine parts listed by hand in WeaponConfig.
			if copy.Name:sub(1, 3) == "Mag" and not MAG_KEEP[copy.Name] then
				copy:SetAttribute("MagPart", true)
			end
			local renamed = renameFor(copy.Name)
			if renamed then
				copy.Name = renamed
			end
			copy.Parent = tool
			copied += 1
		end
	end
	if copied == 0 then
		tool:Destroy()
		return "model had no parts"
	end

	-- Scale to a believable size. Imported models are usually authored in metres, so a
	-- carbine arrives about 0.66 studs long -- roughly a ninth of what it should be.
	local target = tonumber(opts.length) or 3.6
	local minZ, maxZ = math.huge, -math.huge
	for _, p in ipairs(tool:GetChildren()) do
		if p:IsA("BasePart") and p ~= handle then
			local z = handle.CFrame:PointToObjectSpace(p.Position).Z
			minZ = math.min(minZ, z)
			maxZ = math.max(maxZ, z)
		end
	end
	local span = maxZ - minZ
	local scale = (span > 1e-4) and (target / span) or 1
	if math.abs(scale - 1) > 0.01 then
		local origin = handle.CFrame
		local plan = {}
		for _, p in ipairs(tool:GetChildren()) do
			if p:IsA("BasePart") and p ~= handle then
				plan[p] = { rel = origin:ToObjectSpace(p.CFrame), size = p.Size }
			end
		end
		for p, m in pairs(plan) do
			p.Size = m.size * scale
			p.CFrame = origin * (m.rel - m.rel.Position + m.rel.Position * scale)
		end
	end

	-- Reference geometry the rest of the game needs. The Muzzle is where GunHandler starts
	-- its ray, so it goes just past the bore, and Barrel sits behind it on the same line.
	local tip = tool:FindFirstChild("MuzzleTip") :: BasePart?
	local tipLocal = tip and handle.CFrame:PointToObjectSpace(tip.Position)
		or Vector3.new(0, 0, -target * 0.5)
	local function marker(name: string, size: Vector3, offset: Vector3, transparency: number)
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Transparency = transparency
		p.Color = Color3.fromRGB(120, 128, 140)
		p.Material = Enum.Material.Metal
		p.CanCollide = false; p.CanQuery = false; p.Massless = true; p.CastShadow = false
		p.CFrame = handle.CFrame * CFrame.new(offset)
		p.Parent = tool
		return p
	end
	if not tool:FindFirstChild("Barrel") then
		marker("Barrel", Vector3.new(0.1, 0.1, 0.3), tipLocal + Vector3.new(0, 0, 0.4), 1)
	end
	local muzzleMarker = marker("Muzzle", Vector3.new(0.12, 0.12, 0.1),
		tipLocal - Vector3.new(0, 0, 0.04), 1)

	for _, p in ipairs(tool:GetChildren()) do
		if p:IsA("BasePart") and p ~= handle then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = handle
			weld.Part1 = p
			weld.Parent = p
		end
	end

	local fire = Instance.new("Sound")
	fire.Name = "Fire"
	fire.SoundId = "rbxassetid://1112042117"
	fire.Volume = 0.5
	fire.RollOffMaxDistance = 120
	fire.Parent = handle
	local reload = Instance.new("Sound")
	reload.Name = "Reload"
	reload.Volume = 0.5
	reload.Parent = handle

	local flash = Instance.new("PointLight")
	flash.Name = "Flash"
	flash.Color = Color3.fromRGB(255, 214, 140)
	flash.Brightness = 0
	flash.Range = 12
	flash.Enabled = false
	flash.Parent = muzzleMarker
	local point = Instance.new("Attachment")
	point.Name = "MuzzlePoint"
	point.Position = Vector3.new(0, 0, -0.05)
	point.Parent = muzzleMarker

	-- Record what each part is made of. The weapons are painted from a fixed material
	-- vocabulary, so this one pass is what lets the authored camos repaint any of them --
	-- including weapons imported later -- without a per-weapon table anywhere.
	local stamped = WeaponFinish.Stamp(tool)

	-- Put the model's own mount points back. The 3D importer drops them -- they are empty
	-- nodes with no geometry -- so they are recovered from the recorded source coordinates
	-- by matching parts that did survive.
	local mounts = WeaponMounts.Place(tool, weaponName)

	local tagged = 0
	for _, p in ipairs(tool:GetChildren()) do
		if p:IsA("BasePart") and p:GetAttribute("MagPart") == true then
			tagged += 1
		end
	end

	tool.Grip = CFrame.new()          -- WeaponPose solves this on equip
	tool.Parent = ReplicatedStorage.storeitems

	local check = handle.CFrame:VectorToObjectSpace(bore)
	return string.format(
		"%s: %d parts, scaled x%.2f to %.2f studs, bore (%+.2f, %+.2f, %+.2f) [want 0,0,-1]"
			.. "\n         %d parts matched to an authored material, %d tagged as magazine,"
			.. " %d authored mount points recovered",
		weaponName, copied, scale, span * scale, check.X, check.Y, check.Z, stamped, tagged, mounts)
end

-- ------------------------------------------------------------------ the set --
--
-- The models in "Gun Models", keyed by the name Roblox's 3D importer gives the Model it
-- drops into Workspace (the file name). `as` is the Tool name the rest of the game knows
-- the weapon by, and must match a WeaponConfig entry. `length` is the finished size in
-- studs -- these are authored in metres, so each arrives about a ninth of the right size.
-- `grip` names the part the hand closes around, when it is not the usual GripBody. A pump
-- shotgun has no pistol grip at all -- the hand goes on the wrist of the stock.
WeaponImporter.Set = {
	{ from = "ARCarbine",      as = "Warden",    length = 4.2 },
	{ from = "PumpShotgun",    as = "Blackwood", length = 4.4, grip = "StockWrist" },
	{ from = "HeavyPistol",    as = "Sentinel",  length = 1.7, grip = "GripFrame" },
	{ from = "CompactCarbine", as = "Carbine",   length = 3.6 },
}

-- Convert whichever of the set are sitting in Workspace, and say what happened to each.
-- Safe to re-run: anything not imported yet is reported as waiting rather than failing,
-- and a weapon that is already converted is simply rebuilt from the model.
function WeaponImporter.ConvertAll(destroySources: boolean?)
	local lines = {}
	for _, entry in ipairs(WeaponImporter.Set) do
		local model = workspace:FindFirstChild(entry.from)
		if not model then
			table.insert(lines, string.format("%-14s -> %-10s waiting: no Workspace.%s",
				entry.from, entry.as, entry.from))
		else
			local ok, result = pcall(WeaponImporter.Convert, model, entry.as,
				{ length = entry.length, grip = entry.grip })
			if ok then
				table.insert(lines, string.format("%-14s -> %s", entry.from, tostring(result)))
				if destroySources then
					model:Destroy()
				end
			else
				table.insert(lines, string.format("%-14s -> %-10s FAILED: %s",
					entry.from, entry.as, tostring(result)))
			end
		end
	end
	return table.concat(lines, "\n")
end

return WeaponImporter
