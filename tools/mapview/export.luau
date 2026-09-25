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

function Export.Parts(root, origin)
	origin = origin or roblox.Vector3.new(0, 0, 0)
	local parts, lights, signs = {}, {}, {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
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
	return { parts = parts, lights = lights, signs = signs }
end

return Export
