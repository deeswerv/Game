-- The city kit's meshes (DistrictService.MeshKit).
--
-- assets/models/CityKit.rbxm -- the Studio 3D importer's result for CityKit.glb, saved to
-- file (its MeshParts point at the meshes the importer uploaded) -- becomes
-- ServerStorage.CityKit, and Downtown draws its street props from it. No file, no kit: the
-- props stay part-built.
--
-- Only made inert here: anchored, out of physics, raycasts and touch, no shadow, no scripts or
-- joints, no texture over the game's own paint. Where each piece goes and how big it is comes
-- from MeshKitData, not from where the importer left it.
return function(ctx)
	local roblox = ctx.roblox
	local fs = ctx.fs
	local file = "assets/models/CityKit.rbxm"
	if not fs.isFile(file) then
		return
	end
	local ss = ctx.get("ServerStorage")
	local old = ss:FindFirstChild("CityKit")
	if old then
		old.Parent = nil
	end
	local list = roblox.deserializeModel(fs.readFile(file))
	local root = list[1]
	if #list ~= 1 then
		root = roblox.Instance.new("Model")
		for _, inst in list do
			inst.Parent = root
		end
	end
	root.Name = "CityKit"

	local meshes = 0
	local all = root:GetDescendants()
	for _, d in all do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.CastShadow = false
			if d:IsA("MeshPart") then
				meshes += 1
			end
		elseif d:IsA("LuaSourceContainer") or d:IsA("JointInstance") or d:IsA("WeldConstraint")
			or d:IsA("SurfaceAppearance") then
			d.Parent = nil
		end
	end
	root.Parent = ss
	print(`meshkit: {meshes} meshes`)
end
