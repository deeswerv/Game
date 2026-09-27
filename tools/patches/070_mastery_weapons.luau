-- Mastery Weapons rebuilt from their authored GLBs (tools/weapons/*.json, written by
-- tools/weapons/convert_glb.py). Each file becomes a Tool in ReplicatedStorage.storeitems,
-- named after the file, laid out the way every weapon in the game is:
--
--   Handle space: -Z is the bore, +Y is up. Parts are massless, non-colliding and welded to the
--   Handle with WeldConstraints. "Muzzle" is an invisible marker just past the front of the gun
--   carrying the "MuzzlePoint" attachment and the "Flash" light; "Barrel" + "Muzzle" give the
--   pose solver its bore, "Magazine"/"Rail" its up, "LowerHandguard" the off hand's place;
--   the magazine's pieces are tagged MagPart so the reload takes them all; "ChargingHandle" is
--   what the charge racks. The Fire and Reload sounds come from the base weapon's Handle.
--
-- A Dark Matter weapon also gets the Dark Matter carbine's authored muzzle flash -- its petals
-- are uploaded meshes, so they can be cloned onto any gun -- placed the same way off its muzzle.
--
-- A Tool that is already in storeitems under the same name is left alone: if the GLB is ever
-- brought in through Studio's 3D importer instead, the imported model wins.
return function(ctx)
	local roblox = ctx.roblox
	local fs = ctx.fs
	local serde = ctx.serde
	local Vector3, CFrame, Color3, Enum = roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum

	local store = ctx.find("ReplicatedStorage/storeitems")
	if not store or not fs.isDir("tools/weapons") then
		print("(no storeitems or tools/weapons; mastery weapons skipped)")
		return
	end

	-- Which base weapon lends each one its Tool properties and sounds.
	local BASE = { Warden_DarkMatter = "Warden" }
	-- Which already-imported weapon lends its authored flash.
	local FLASH_FROM = { Warden_DarkMatter = "Carbine_DarkMatter" }

	for _, file in fs.readDir("tools/weapons") do
		if string.sub(file, -5) ~= ".json" then
			continue
		end
		local name = string.sub(file, 1, -6)
		local data = serde.decode("json", fs.readFile("tools/weapons/" .. file))
		local existing = store:FindFirstChild(name)
		if existing and existing:GetAttribute("BuiltFrom") == nil then
			print(("%s: an imported Tool is already in storeitems; left alone"):format(name))
			continue
		end
		if existing then
			existing:Destroy()
		end
		local template = store:FindFirstChild(BASE[name] or "Warden")
		if not template then
			print(("%s: no base weapon to borrow a Tool from; skipped"):format(name))
			continue
		end

		local tool = template:Clone()
		tool.Name = name
		for _, child in tool:GetChildren() do
			if child.Name ~= "Handle" then
				child:Destroy()
			end
		end
		local handle = tool:FindFirstChild("Handle")
		for _, child in handle:GetChildren() do
			if not child:IsA("Sound") then
				child:Destroy()
			end
		end
		local origin = CFrame.new(0, 10, 0)
		handle.CFrame = origin
		tool.Grip = CFrame.new()
		tool:SetAttribute("BuiltFrom", data.source)

		local function weld(p)
			local w = roblox.Instance.new("WeldConstraint")
			w.Part0 = handle
			w.Part1 = p
			w.Parent = p
		end

		local frontZ, count = math.huge, 0
		for _, row in data.parts do
			local p = roblox.Instance.new(row.cls)
			p.Name = row.n
			if row.cls == "Part" then
				if row.s == "Cylinder" then
					p.Shape = Enum.PartType.Cylinder
				elseif row.s == "Ball" then
					p.Shape = Enum.PartType.Ball
				end
			end
			p.Size = Vector3.new(row.z[1], row.z[2], row.z[3])
			local c = row.cf
			p.CFrame = origin * CFrame.new(c[1], c[2], c[3], c[4], c[5], c[6], c[7], c[8], c[9], c[10], c[11], c[12])
			p.Color = Color3.new(row.c[1], row.c[2], row.c[3])
			p.Material = (Enum.Material :: any)[row.m]
			p.Reflectance = row.rf or 0
			p.Transparency = row.t or 0
			p.Anchored = false
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
			p.Massless = true
			p.CastShadow = false
			p.TopSurface = Enum.SurfaceType.Smooth
			p.BottomSurface = Enum.SurfaceType.Smooth
			p:SetAttribute("DMGroup", row.g)
			if row.mag then
				p:SetAttribute("MagPart", true)
			end
			p.Parent = tool
			weld(p)
			count += 1
			if row.g ~= "DarkMatterCrystals" and row.g ~= "DarkMatterEnergy" and row.g ~= "DarkMatterShimmer" then
				-- How far the part reaches along the Handle's Z: its rotation's third row.
				local z = c[3] - 0.5 * (math.abs(c[10]) * row.z[1] + math.abs(c[11]) * row.z[2] + math.abs(c[12]) * row.z[3])
				frontZ = math.min(frontZ, z)
			end
		end

		-- The muzzle marker: on the bore line (the authored MuzzlePoint), just past the front.
		local bore = data.points.MuzzlePoint or { 0, 0, frontZ }
		local muzzle = roblox.Instance.new("Part")
		muzzle.Name = "Muzzle"
		muzzle.Size = Vector3.new(0.12, 0.12, 0.1)
		muzzle.Transparency = 1
		muzzle.Anchored = false
		muzzle.CanCollide = false
		muzzle.CanQuery = false
		muzzle.CanTouch = false
		muzzle.Massless = true
		muzzle.CastShadow = false
		muzzle.CFrame = origin * CFrame.new(bore[1], bore[2], frontZ - 0.04)
		muzzle.Parent = tool
		weld(muzzle)
		local point = roblox.Instance.new("Attachment")
		point.Name = "MuzzlePoint"
		point.Position = Vector3.new(0, 0, -0.05)
		point.Parent = muzzle
		local light = roblox.Instance.new("PointLight")
		light.Name = "Flash"
		light.Color = Color3.fromRGB(176, 123, 255)
		light.Brightness = 0
		light.Range = 12
		light.Enabled = false
		light.Parent = muzzle

		-- The authored Dark Matter flash, off the carbine that has it.
		local flashes = 0
		local donor = FLASH_FROM[name] and store:FindFirstChild(FLASH_FROM[name])
		local donorMuzzle = donor and donor:FindFirstChild("Muzzle")
		if donorMuzzle then
			for _, d in donor:GetDescendants() do
				if d:IsA("BasePart") and d:GetAttribute("DMRole") == "MuzzleFlash" then
					local copy = d:Clone()
					for _, child in copy:GetChildren() do
						child:Destroy()
					end
					copy.CFrame = muzzle.CFrame * donorMuzzle.CFrame:ToObjectSpace(d.CFrame)
					copy.Parent = tool
					weld(copy)
					flashes += 1
				end
			end
		end

		tool.Parent = store
		print(("%s: %d parts from %s (x%.3f), muzzle at z %.2f, %d flash pieces"):format(
			name, count, data.source, data.scale, frontZ - 0.04, flashes))
	end
end
