--!nocheck
-- Finds the things that make a low-poly map look broken, in any folder of parts:
--
--   zfight     two faces in the same plane, overlapping, in different colours or materials --
--              the flicker where one surface shows through another as the camera moves
--   duplicate  two parts in exactly the same place and size (flickers the same way)
--   floating   a small prop with nothing under it or beside it to stand on
--
--   lune run tools/mapview/audit.luau -- build/Game.rbxl [Folder ...]      static parts
--   lune run tools/mapview/audit.luau -- json out/map.json                 a mapview export
--
-- Ignores anything invisible or non-solid decoration (Transparency >= 0.95), and faces that
-- touch back to back (a wall standing on a floor shares no visible face). The findings list
-- the part names and where, most serious first; exit code 1 when there are any z-fights.

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local CFrame, Vector3 = roblox.CFrame, roblox.Vector3

local args = {}
for _, a in ipairs(process.args) do
	if a ~= "--" then
		table.insert(args, a)
	end
end

-- ------------------------------------------------------------------ parts --

type Box = { name: string, path: string, cf: any, size: any, colour: string, material: string, shape: string,
	lo: any, hi: any, anchored: boolean }

local boxes: { Box } = {}

local function addBox(name, path, cf, size, colour, material, shape, anchored)
	-- World-space bounds of the oriented box.
	local hx, hy, hz = size.X / 2, size.Y / 2, size.Z / 2
	local r, u, l = cf.RightVector, cf.UpVector, cf.LookVector
	local ex = math.abs(r.X) * hx + math.abs(u.X) * hy + math.abs(l.X) * hz
	local ey = math.abs(r.Y) * hx + math.abs(u.Y) * hy + math.abs(l.Y) * hz
	local ez = math.abs(r.Z) * hx + math.abs(u.Z) * hy + math.abs(l.Z) * hz
	local p = cf.Position
	table.insert(boxes, {
		name = name, path = path, cf = cf, size = size, colour = colour, material = material, shape = shape,
		lo = Vector3.new(p.X - ex, p.Y - ey, p.Z - ez), hi = Vector3.new(p.X + ex, p.Y + ey, p.Z + ez),
		anchored = anchored,
	})
end

if args[1] == "json" then
	local data = serde.decode("json", fs.readFile(args[2]))
	for i, p in ipairs(data.parts) do
		if (p.t or 0) < 0.95 then
			local cf = CFrame.new(p.p[1], p.p[2], p.p[3], p.r[1], p.r[2], p.r[3], p.r[4], p.r[5], p.r[6], p.r[7], p.r[8], p.r[9])
			local colour = type(p.c) == "table" and table.concat(p.c, ",") or tostring(p.c)
			addBox(p.n or ("#" .. i), (p.n or "") .. " #" .. i, cf, Vector3.new(p.z[1], p.z[2], p.z[3]), colour,
				tostring(p.m), p.s or "Block", true)
		end
	end
else
	local game = roblox.deserializePlace(fs.readFile(args[1] or "build/Game.rbxl"))
	local ws = game:GetService("Workspace")
	local roots = {}
	if #args > 1 then
		for i = 2, #args do
			local f = ws:FindFirstChild(args[i])
			assert(f, "no workspace." .. args[i])
			table.insert(roots, f)
		end
	else
		roots = { ws }
	end
	for _, root in ipairs(roots) do
		for _, d in ipairs(root:GetDescendants()) do
			if d:IsA("BasePart") and d.Transparency < 0.95 and not d:FindFirstAncestorOfClass("Tool") then
				local shape = "Block"
				if d:IsA("Part") then
					shape = d.Shape.Name
				elseif d.ClassName ~= "WedgePart" then
					shape = d.ClassName -- MeshPart, UnionOperation...: faces unknown
				else
					shape = "Wedge"
				end
				-- Humanoid rigs are characters, not map.
				local model = d:FindFirstAncestorOfClass("Model")
				if not (model and model:FindFirstChildOfClass("Humanoid")) then
					addBox(d.Name, d:GetFullName(), d.CFrame, d.Size, tostring(d.Color), d.Material.Name, shape, d.Anchored)
				end
			end
		end
	end
end

-- ------------------------------------------------------------------ faces --

-- A box's six faces: centre, outward normal, the two in-plane axes and half extents.
local function faces(b: Box)
	local cf, s = b.cf, b.size
	local out = {}
	local axes = {
		{ n = cf.RightVector, h = s.X / 2, a = cf.UpVector, ah = s.Y / 2, c = cf.LookVector, ch = s.Z / 2 },
		{ n = cf.UpVector, h = s.Y / 2, a = cf.RightVector, ah = s.X / 2, c = cf.LookVector, ch = s.Z / 2 },
		{ n = cf.LookVector, h = s.Z / 2, a = cf.RightVector, ah = s.X / 2, c = cf.UpVector, ch = s.Y / 2 },
	}
	for _, ax in ipairs(axes) do
		for _, sign in ipairs({ 1, -1 }) do
			table.insert(out, {
				centre = cf.Position + ax.n * (ax.h * sign),
				normal = ax.n * sign,
				u = ax.a, uh = ax.ah,
				v = ax.c, vh = ax.ch,
			})
		end
	end
	return out
end

-- Overlap area of two coplanar rectangles, approximated by clipping on the first face's axes
-- (exact when the two are aligned in the plane, which is nearly always the case in a map).
local function overlapArea(f1, f2): number
	local function span(f, axis)
		local c = f.centre:Dot(axis)
		local e = math.abs(f.u:Dot(axis)) * f.uh + math.abs(f.v:Dot(axis)) * f.vh
		return c - e, c + e
	end
	local a1, b1 = span(f1, f1.u)
	local a2, b2 = span(f2, f1.u)
	local c1, d1 = span(f1, f1.v)
	local c2, d2 = span(f2, f1.v)
	local lo1, hi1 = math.max(a1, a2), math.min(b1, b2)
	local lo2, hi2 = math.max(c1, c2), math.min(d1, d2)
	local w, h = hi1 - lo1, hi2 - lo2
	if w <= 0 or h <= 0 then
		return 0, nil, 0, 0
	end
	-- Rotated in-plane: discount by how square the second face sits to the first.
	local align = math.max(math.abs(f1.u:Dot(f2.u)), math.abs(f1.u:Dot(f2.v)))
	local base = f1.centre - f1.u * f1.centre:Dot(f1.u) - f1.v * f1.centre:Dot(f1.v)
	local centre = base + f1.u * ((lo1 + hi1) / 2) + f1.v * ((lo2 + hi2) / 2)
	return w * h * (align > 0.999 and 1 or 0.5), centre, w, h
end

-- --------------------------------------------------------------- the scan --

local CELL = 16
local grid: { [string]: { number } } = {}
for i, b in ipairs(boxes) do
	for x = math.floor(b.lo.X / CELL), math.floor(b.hi.X / CELL) do
		for y = math.floor(b.lo.Y / CELL), math.floor(b.hi.Y / CELL) do
			for z = math.floor(b.lo.Z / CELL), math.floor(b.hi.Z / CELL) do
				local key = x .. "," .. y .. "," .. z
				local list = grid[key]
				if not list then
					list = {}
					grid[key] = list
				end
				table.insert(list, i)
			end
		end
	end
end

local findings = { zfight = {}, duplicate = {}, floating = {} }

-- Whether a point is inside some solid block other than the two being compared.
local function inside(p: Vector3, b: Box): boolean
	if b.shape ~= "Block" then
		return false
	end
	local rel = b.cf:PointToObjectSpace(p)
	return math.abs(rel.X) < b.size.X / 2 and math.abs(rel.Y) < b.size.Y / 2 and math.abs(rel.Z) < b.size.Z / 2
end
local function covered(p: Vector3, skipA: number, skipB: number): boolean
	local key = math.floor(p.X / CELL) .. "," .. math.floor(p.Y / CELL) .. "," .. math.floor(p.Z / CELL)
	for _, j in ipairs(grid[key] or {}) do
		if j ~= skipA and j ~= skipB and inside(p, boxes[j]) then
			return true
		end
	end
	return false
end
-- Whether there is anything under a point to stand on and look up from. An underside over
-- nothing (the bottom of a map's base slab) is never seen.
-- An underside resting on something (a gap under it too small to see into) is not either.
local function groundBelow(p: Vector3, skipA: number, skipB: number): boolean
	local cx, cz = math.floor(p.X / CELL), math.floor(p.Z / CELL)
	local top = math.floor(p.Y / CELL)
	local nearest = math.huge
	for cy = top, top - math.ceil(200 / CELL), -1 do
		for _, j in ipairs(grid[cx .. "," .. cy .. "," .. cz] or {}) do
			local b = boxes[j]
			if j ~= skipA and j ~= skipB and b.hi.Y <= p.Y + 0.02 and p.X >= b.lo.X and p.X <= b.hi.X
				and p.Z >= b.lo.Z and p.Z <= b.hi.Z then
				nearest = math.min(nearest, p.Y - b.hi.Y)
			end
		end
	end
	return nearest > 0.3 and nearest < 200
end
--- Whether any of a shared face could be seen: some of it not buried in a third part, and
--- for an underside, with something below to see it from.
local function visible(centre: Vector3, f, w: number, h: number, i: number, j: number): boolean
	local samples = { centre }
	for _, du in ipairs({ -0.35, 0.35 }) do
		for _, dv in ipairs({ -0.35, 0.35 }) do
			table.insert(samples, centre + f.u * (w * du) + f.v * (h * dv))
		end
	end
	for _, sample in ipairs(samples) do
		local out = sample + f.normal * 0.04
		if not covered(out, i, j) then
			if f.normal.Y < -0.5 then
				if groundBelow(out, i, j) then
					return true
				end
			else
				return true
			end
		end
	end
	return false
end
local seen: { [string]: boolean } = {}
local faceCache: { [number]: any } = {}
local function facesOf(i)
	local f = faceCache[i]
	if not f then
		f = faces(boxes[i])
		faceCache[i] = f
	end
	return f
end

local function touches(a: Box, b: Box, slack: number): boolean
	return a.lo.X <= b.hi.X + slack and a.hi.X >= b.lo.X - slack
		and a.lo.Y <= b.hi.Y + slack and a.hi.Y >= b.lo.Y - slack
		and a.lo.Z <= b.hi.Z + slack and a.hi.Z >= b.lo.Z - slack
end

for _, list in pairs(grid) do
	for x = 1, #list do
		for y = x + 1, #list do
			local i, j = list[x], list[y]
			local key = i < j and (i .. ":" .. j) or (j .. ":" .. i)
			if not seen[key] then
				seen[key] = true
				local a, b = boxes[i], boxes[j]
				if touches(a, b, 0.02) then
					-- Exact duplicates.
					if (a.cf.Position - b.cf.Position).Magnitude < 0.01 and (a.size - b.size).Magnitude < 0.01
						and a.shape == b.shape and a.cf.LookVector:Dot(b.cf.LookVector) > 0.9999
						and a.cf.UpVector:Dot(b.cf.UpVector) > 0.9999 then
						table.insert(findings.duplicate, { a = a, b = b, area = a.size.X * a.size.Z })
					elseif a.shape == "Block" and b.shape == "Block" then
						local same = a.colour == b.colour and a.material == b.material
						if not same then
							for _, f1 in ipairs(facesOf(i)) do
								for _, f2 in ipairs(facesOf(j)) do
									-- Same plane, facing the SAME way: both faces are visible
									-- surfaces at one depth. (Opposite normals are back to back.)
									if f1.normal:Dot(f2.normal) > 0.9995
										and math.abs((f2.centre - f1.centre):Dot(f1.normal)) < 0.012 then
										local area, centre, w, h = overlapArea(f1, f2)
										if area > 0.05 and visible(centre, f1, w, h, i, j) then
											table.insert(findings.zfight, { a = a, b = b, area = area, at = centre })
										end
									end
								end
							end
						end
					end
				end
			end
		end
	end
end

-- Floating: small anchored props (not big slabs) with nothing within a hair of any side.
for i, b in ipairs(boxes) do
	local volume = b.size.X * b.size.Y * b.size.Z
	if b.anchored and volume < 64 and b.lo.Y > 0.3 then
		local supported = false
		for x = math.floor((b.lo.X - 0.1) / CELL), math.floor((b.hi.X + 0.1) / CELL) do
			for y = math.floor((b.lo.Y - 0.1) / CELL), math.floor((b.hi.Y + 0.1) / CELL) do
				for z = math.floor((b.lo.Z - 0.1) / CELL), math.floor((b.hi.Z + 0.1) / CELL) do
					for _, j in ipairs(grid[x .. "," .. y .. "," .. z] or {}) do
						if j ~= i and touches(b, boxes[j], 0.08) then
							supported = true
							break
						end
					end
					if supported then
						break
					end
				end
				if supported then
					break
				end
			end
			if supported then
				break
			end
		end
		if not supported then
			table.insert(findings.floating, { a = b, area = volume })
		end
	end
end

-- ----------------------------------------------------------------- report --

local function where(v)
	return ("(%.0f, %.0f, %.0f)"):format(v.X, v.Y, v.Z)
end
table.sort(findings.zfight, function(p, q)
	return p.area > q.area
end)
table.sort(findings.floating, function(p, q)
	return p.area > q.area
end)
print(("%d parts checked: %d z-fights, %d duplicates, %d floating"):format(#boxes, #findings.zfight,
	#findings.duplicate, #findings.floating))
local limit = tonumber(process.env.AUDIT_LIMIT) or 40
for k, f in ipairs(findings.zfight) do
	if k > limit then
		break
	end
	print(("  zfight %5.1f sq  %s  <>  %s  at %s"):format(f.area, f.a.path, f.b.path, where(f.at)))
end
for k, f in ipairs(findings.duplicate) do
	if k > limit then
		break
	end
	print(("  duplicate  %s  ==  %s  at %s"):format(f.a.path, f.b.path, where(f.a.cf.Position)))
end
for k, f in ipairs(findings.floating) do
	if k > limit then
		break
	end
	print(("  floating  %s  at %s"):format(f.a.path, where(f.a.cf.Position)))
end
process.exit(#findings.zfight > 0 and 1 or 0)
