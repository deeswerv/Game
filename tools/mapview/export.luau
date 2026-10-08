--!nocheck
-- Export a piece of the world to JSON for tools/mapview/view.html: every part's shape,
-- placement, size, colour and material, the lights, and the text on signs.
--
--   export.Parts(root, origin?) -> table   parts under `root` (a Lune instance)
--
-- Used by tools/mapview/arenas.luau (maps built by ArenaService) and region.luau (a slice of
-- the place itself).

local roblox = require("@lune/roblox")

local Export = {}

local function c3(c)
	return { math.floor(c.R * 255 + 0.5), math.floor(c.G * 255 + 0.5), math.floor(c.B * 255 + 0.5) }
end

local function safe(inst, key)
	local ok, v = pcall(function()
		return inst[key]
	end)
	return ok and v or nil
end

-- The city kit, as clients draw it (CityMeshes): a Model tagged KitProp says which of the
-- kit's models stands where and how it is painted; its part-built pieces are hidden (all but
-- the KitKeep ones). KIT=0 exports the part-built props instead.
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local process = require("@lune/process")

local function loadData(path)
	if not fs.isFile(path) then
		return nil
	end
	return luau.load(fs.readFile(path), { debugName = path, environment = { Vector3 = roblox.Vector3 } })()
end

local function kitOf(d)
	local m = d.Parent
	while m do
		if m.ClassName == "Model" and m:GetAttribute("KitModel") then
			return m
		end
		m = m.Parent
	end
	return nil
end

function Export.Parts(root, origin)
	origin = origin or roblox.Vector3.new(0, 0, 0)
	local parts, lights, signs = {}, {}, {}
	local useKit = process.env.KIT ~= "0"
	local kitData = useKit and loadData("src/ReplicatedStorage/MeshKitData.luau")
	local kitGeometry = useKit and loadData("src/ReplicatedStorage/MeshKitGeometry.luau")
	local kits, kitGeo = {}, {}
	if kitData and kitGeometry then
		for _, d in ipairs(root:GetDescendants()) do
			local name = d.ClassName == "Model" and d:GetAttribute("KitModel")
			local frame = name and d:GetAttribute("KitFrame")
			if name and frame and kitData[name] then
				local raw = d:GetAttribute("KitScale")
				local sc = if typeof(raw) == "Vector3" then raw else roblox.Vector3.new(raw or 1, raw or 1, raw or 1)
				local paint = {}
				for role in pairs(kitData[name]) do
					local c = d:GetAttribute("KitColour_" .. role)
					paint[role] = {
						c = c and c3(c) or { 160, 160, 160 },
						m = d:GetAttribute("KitMaterial_" .. role) or "SmoothPlastic",
						t = d:GetAttribute("KitClear_" .. role) or 0,
						rf = d:GetAttribute("KitShine_" .. role) or 0,
					}
				end
				local p = frame.Position - origin
				local x, y, z = frame.XVector, frame.YVector, frame.ZVector
				table.insert(kits, { k = name, p = { p.X, p.Y, p.Z }, r = { x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z },
					sc = { sc.X, sc.Y, sc.Z }, paint = paint })
				if not kitGeo[name] then
					kitGeo[name] = {}
					for role, spec in pairs(kitData[name]) do
						local g = kitGeometry[name][role]
						kitGeo[name][role] = { size = { spec.size.X, spec.size.Y, spec.size.Z },
							offset = { spec.offset.X, spec.offset.Y, spec.offset.Z }, verts = g.verts, tris = g.tris,
							data = (g.data:gsub("%s", "")) }
					end
				end
			end
		end
	end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") and #kits > 0 and kitOf(d) and not d:GetAttribute("KitKeep") then
			-- Drawn by the kit instead.
		elseif d:IsA("BasePart") then
			local transparency = safe(d, "Transparency") or 0
			local cf = safe(d, "CFrame")
			if cf and transparency < 0.98 then
				local p = cf.Position - origin
				local shape = "Block"
				if d:IsA("WedgePart") then
					shape = "Wedge"
				elseif d:IsA("CornerWedgePart") then
					shape = "CornerWedge"
				elseif d:IsA("Part") then
					local s = safe(d, "Shape")
					shape = s and s.Name or "Block"
				end
				local x, y, z = cf.XVector, cf.YVector, cf.ZVector
				table.insert(parts, {
					n = d.Name,
					s = shape,
					p = { p.X, p.Y, p.Z },
					r = { x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z },
					z = { d.Size.X, d.Size.Y, d.Size.Z },
					c = c3(safe(d, "Color") or roblox.Color3.new(0.6, 0.6, 0.6)),
					m = (safe(d, "Material") or roblox.Enum.Material.Plastic).Name,
					t = transparency,
					rf = safe(d, "Reflectance") or 0,
				})
			end
		elseif d:IsA("PointLight") or d:IsA("SpotLight") or d:IsA("SurfaceLight") then
			local host = d.Parent
			local cf = host and host:IsA("BasePart") and safe(host, "CFrame")
			if cf and safe(d, "Enabled") ~= false then
				local p = cf.Position - origin
				local dir = cf.LookVector
				if d:IsA("SpotLight") or d:IsA("SurfaceLight") then
					local face = safe(d, "Face")
					if face then
						if face.Name == "Bottom" then
							dir = -cf.UpVector
						elseif face.Name == "Top" then
							dir = cf.UpVector
						elseif face.Name == "Back" then
							dir = -cf.LookVector
						elseif face.Name == "Left" then
							dir = -cf.RightVector
						elseif face.Name == "Right" then
							dir = cf.RightVector
						end
					end
				end
				table.insert(lights, {
					k = d.ClassName,
					p = { p.X, p.Y, p.Z },
					d = { dir.X, dir.Y, dir.Z },
					c = c3(safe(d, "Color") or roblox.Color3.new(1, 1, 1)),
					b = safe(d, "Brightness") or 1,
					range = safe(d, "Range") or 16,
					angle = safe(d, "Angle") or 90,
				})
			end
		elseif d:IsA("SurfaceGui") then
			local host = d.Parent
			local label = d:FindFirstChildWhichIsA("TextLabel", true)
			local cf = host and host:IsA("BasePart") and safe(host, "CFrame")
			if cf and label then
				local face = safe(d, "Face")
				local faceName = face and face.Name or "Front"
				local size = host.Size
				-- Face centres, in part space, and the face's width and height.
				local faces = {
					Front = { off = roblox.Vector3.new(0, 0, -size.Z / 2), w = size.X, h = size.Y },
					Back = { off = roblox.Vector3.new(0, 0, size.Z / 2), w = size.X, h = size.Y },
					Top = { off = roblox.Vector3.new(0, size.Y / 2, 0), w = size.X, h = size.Z },
					Bottom = { off = roblox.Vector3.new(0, -size.Y / 2, 0), w = size.X, h = size.Z },
					Left = { off = roblox.Vector3.new(-size.X / 2, 0, 0), w = size.Z, h = size.Y },
					Right = { off = roblox.Vector3.new(size.X / 2, 0, 0), w = size.Z, h = size.Y },
				}
				local f = faces[faceName] or faces.Front
				local centre = cf:PointToWorldSpace(f.off) - origin
				local lc = safe(label, "TextColor3") or roblox.Color3.new(1, 1, 1)
				local stroke = label:FindFirstChildOfClass("UIStroke")
				local x, y, z = cf.XVector, cf.YVector, cf.ZVector
				table.insert(signs, {
					text = safe(label, "Text") or "",
					face = faceName,
					p = { centre.X, centre.Y, centre.Z },
					r = { x.X, y.X, z.X, x.Y, y.Y, z.Y, x.Z, y.Z, z.Z },
					w = f.w,
					h = f.h,
					c = c3(lc),
					sc = stroke and c3(safe(stroke, "Color")) or nil,
					tt = safe(label, "TextTransparency") or 0,
					rot = safe(label, "Rotation") or 0,
					ly = (safe(label, "Position") and label.Position.Y.Scale) or 0.5,
					lh = (safe(label, "Size") and label.Size.Y.Scale) or 1,
				})
			end
		end
	end
	return { parts = parts, lights = lights, signs = signs, kits = kits, kitGeo = kitGeo }
end

return Export
