--!strict
-- Where attachments actually bolt on, taken from the models themselves.
--
-- The authored .glb files carry explicit mount points -- MuzzlePoint, OpticPoint,
-- StockPoint and so on -- put there by whoever built the weapon. Roblox's 3D importer
-- throws them away, because they are empty nodes with no geometry, which is why
-- attachments have been placed by guessing at the weapon's shape instead. Guessing gets
-- close and then leaves a red dot hovering over the rail.
--
-- So the points are recorded here in the model's own coordinates, and mapped into the
-- imported weapon at runtime by matching parts that exist in both. Nothing has to be
-- re-imported, and a weapon with no entry here simply falls back to the old geometry.

local WeaponMounts = {}

-- Positions are in each source file's own space: +X down the bore, +Y up, +Z to the
-- right, in metres. `refs` are parts that survive the import (under the names
-- WeaponImporter renames them to) and are used to solve the transform.
WeaponMounts.Data = {
	Carbine = {
		refs = {
			{ "MuzzleTip", Vector3.new(0.327145, 0.204824, 0.000000) },
			{ "Grip", Vector3.new(-0.095351, 0.095126, 0.000000) },
			{ "MlokSlotL0", Vector3.new(0.116145, 0.200824, -0.019000) },
			{ "Stock", Vector3.new(-0.260855, 0.194824, 0.000000) },
		},
		mounts = {
			Sight = Vector3.new(-0.008855, 0.250824, 0.000000),
			Muzzle = Vector3.new(0.273145, 0.204824, 0.000000),
			Underbarrel = Vector3.new(0.177145, 0.162824, 0.000000),
			Magazine = Vector3.new(0.003145, 0.150824, 0.000000),
			Stock = Vector3.new(-0.168855, 0.196824, 0.000000),
			Charm = Vector3.new(-0.102855, 0.140824, 0.000000),
		},
	},
	Warden = {
		refs = {
			{ "MuzzleTip", Vector3.new(0.328447, 0.225907, 0.000000) },
			{ "Grip", Vector3.new(-0.103580, 0.124749, 0.000000) },
			{ "MlokSlotL0", Vector3.new(0.089447, 0.225907, -0.018000) },
			{ "Stock", Vector3.new(-0.270553, 0.217907, 0.000000) },
		},
		mounts = {
			Sight = Vector3.new(-0.060553, 0.270907, 0.000000),
			Muzzle = Vector3.new(0.279447, 0.225907, 0.000000),
			Underbarrel = Vector3.new(0.156447, 0.197907, 0.000000),
			Magazine = Vector3.new(-0.023553, 0.155907, 0.000000),
			Stock = Vector3.new(-0.153553, 0.219907, 0.000000),
		},
	},
	Blackwood = {
		refs = {
			{ "MuzzleTip", Vector3.new(0.484426, 0.095792, 0.000000) },
			{ "Stock", Vector3.new(-0.334574, 0.043792, 0.000000) },
			{ "StockCheckerL", Vector3.new(-0.329574, 0.039792, -0.021500) },
			{ "ReceiverBody", Vector3.new(-0.159574, 0.073792, 0.000000) },
		},
		mounts = {
			Sight = Vector3.new(-0.159574, 0.110792, 0.000000),
			Muzzle = Vector3.new(0.468426, 0.095792, 0.000000),
			Stock = Vector3.new(-0.267574, 0.065792, 0.000000),
			Underbarrel = Vector3.new(-0.159574, 0.073792, -0.024000),
		},
	},
	Sentinel = {
		refs = {
			{ "MuzzleTip", Vector3.new(0.109000, 0.168798, 0.000000) },
			{ "Grip", Vector3.new(-0.039224, 0.069031, 0.000000) },
			{ "SerrationL0", Vector3.new(-0.064000, 0.168798, -0.017000) },
			{ "FrameBody", Vector3.new(-0.008000, 0.131798, 0.000000) },
		},
		mounts = {
			Sight = Vector3.new(-0.042000, 0.192798, 0.000000),
			Muzzle = Vector3.new(0.114000, 0.168798, 0.000000),
			Underbarrel = Vector3.new(0.053000, 0.114798, 0.000000),
			Magazine = Vector3.new(-0.052000, 0.068798, 0.000000),
		},
	},
}

-- An orthonormal frame from three points, plus the scale of the first edge. Returns nil
-- if the three are collinear, which would leave the third axis undefined.
local function frameOf(a: Vector3, b: Vector3, c: Vector3)
	local e1 = b - a
	local span = e1.Magnitude
	if span < 1e-9 then
		return nil
	end
	e1 = e1 / span
	local w = c - a
	local e2 = w - e1 * w:Dot(e1)
	if e2.Magnitude < 1e-9 then
		return nil
	end
	e2 = e2.Unit
	return { origin = a, e1 = e1, e2 = e2, e3 = e1:Cross(e2), span = span }
end

-- The transform taking a point in the source model's coordinates to the tool's Handle
-- space. Both the import rotation and its scale factor fall out of the two frames, so
-- this needs to know nothing about what the importer did.
--
-- Returns the mapping function and the residual error, in studs, of a fourth reference
-- point that was NOT used to build the frame -- so a caller can tell whether the fit is
-- trustworthy rather than assuming it.
function WeaponMounts.Solve(tool: Instance, weaponName: string)
	local entry = WeaponMounts.Data[weaponName]
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not entry or not handle then
		return nil, nil
	end

	local src, dst = {}, {}
	for _, ref in ipairs(entry.refs) do
		local part = tool:FindFirstChild(ref[1])
		if part and part:IsA("BasePart") then
			table.insert(src, ref[2])
			table.insert(dst, handle.CFrame:PointToObjectSpace(part.Position))
		end
	end
	if #src < 3 then
		return nil, nil
	end

	local fs = frameOf(src[1], src[2], src[3])
	local fd = frameOf(dst[1], dst[2], dst[3])
	if not fs or not fd then
		return nil, nil
	end

	local k = fd.span / fs.span
	local function map(p: Vector3): Vector3
		local d = p - fs.origin
		return fd.origin + (fd.e1 * d:Dot(fs.e1) + fd.e2 * d:Dot(fs.e2) + fd.e3 * d:Dot(fs.e3)) * k
	end

	local residual = nil
	if #src >= 4 then
		residual = (map(src[4]) - dst[4]).Magnitude
	end
	return map, residual
end

-- Which slots the authored points can actually be used for.
--
-- The artist's points mark where a part BOLTS ON. For a sight, an underbarrel grip and a
-- stock that is exactly what we want, and the authored point beats the geometry guess by
-- anything up to a stud -- the Carbine's stock anchor was 0.91 studs out.
--
-- For the other three it is not: MuzzlePoint sits a little behind the bore end where a
-- device's threads start, and MagazinePoint sits up inside the magwell. Our attachments
-- are described as hanging off a SURFACE -- a muzzle device grows forward from the end of
-- the barrel, an extended magazine grows down from the bottom of the old one -- so those
-- three keep the geometry-derived anchor, which already encodes that intent.
WeaponMounts.AuthoredSlots = {
	Sight = true,
	Underbarrel = true,
	Stock = true,
}

-- Largest residual we will accept before deciding the fit is wrong and the old geometry
-- guess is the safer answer. A tenth of a stud is well under the size of any attachment.
local MAX_RESIDUAL = 0.10

-- Stamp the authored mount points onto the weapon as Attachments on its Handle.
-- AttachmentBuilder looks for these first. Returns how many were placed.
function WeaponMounts.Place(tool: Instance, weaponName: string): number
	local entry = WeaponMounts.Data[weaponName]
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not entry or not handle then
		return 0
	end

	local map, residual = WeaponMounts.Solve(tool, weaponName)
	if not map then
		return 0
	end
	if residual and residual > MAX_RESIDUAL then
		warn(string.format("[WeaponMounts] %s: fit is off by %.3f studs, leaving it to geometry",
			weaponName, residual))
		return 0
	end

	local placed = 0
	for slot, point in pairs(entry.mounts) do
		if WeaponMounts.AuthoredSlots[slot] then
			local name = "Mount_" .. slot
			local existing = handle:FindFirstChild(name)
			if existing then
				existing:Destroy()
			end
			local a = Instance.new("Attachment")
			a.Name = name
			a.Position = map(point)
			a.Parent = handle
			placed += 1
		end
	end
	return placed
end

return WeaponMounts
