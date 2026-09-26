-- Visible z-fighting in the pieces of the world that are baked into the place.
--
-- Found by tools/mapview/audit.luau: two faces in one plane, overlapping, in different colours,
-- which flicker between each other as the camera moves. The builders that make these pieces
-- are fixed too (MineService), but a baked copy is what players walk through until someone
-- re-bakes, so the same corrections are made to the saved parts here -- each one a few
-- hundredths of a stud, so nothing a player could notice moved.
return function(ctx)
	local roblox = ctx.roblox
	local Vector3, CFrame = roblox.Vector3, roblox.CFrame
	local fixed = 0

	-- The mine: the shaft's walls were the same planes as the cavern roof's cut edges and the
	-- tunnel floor's top; the tunnel roof ended where its walls did; the cavern's north wall
	-- met the roof slab's edge over the opening.
	local mine = ctx.find("Workspace/Mine")
	local shaft = mine and mine:FindFirstChild("Shaft")
	if shaft then
		-- The shaft's centre: the middle of its four walls.
		local sum, n = Vector3.new(0, 0, 0), 0
		for _, w in shaft:GetChildren() do
			if w:IsA("BasePart") and w.Name == "ShaftWall" then
				sum += w.CFrame.Position
				n += 1
			end
		end
		local centre = n > 0 and sum / n or Vector3.new(0, 0, 0)
		for _, w in shaft:GetChildren() do
			if w:IsA("BasePart") and w.Name == "ShaftWall" then
				local p = w.CFrame.Position
				local toward = Vector3.new(0, 0, 0)
				if w.Size.X < w.Size.Z then
					toward = Vector3.new(centre.X > p.X and 1 or -1, 0, 0)
				else
					toward = Vector3.new(0, 0, centre.Z > p.Z and 1 or -1)
				end
				w.Size = Vector3.new(w.Size.X, w.Size.Y - 0.05, w.Size.Z)
				w.CFrame = CFrame.new(p + toward * 0.05 - Vector3.new(0, 0.025, 0))
				fixed += 1
			end
		end
	end
	local tunnel = mine and mine:FindFirstChild("Tunnel")
	local roof = tunnel and tunnel:FindFirstChild("Roof")
	if roof and roof:IsA("BasePart") then
		roof.Size = Vector3.new(roof.Size.X, roof.Size.Y, roof.Size.Z + 0.06)
		fixed += 1
	end
	local cavern = mine and mine:FindFirstChild("Cavern")
	local wallN = cavern and cavern:FindFirstChild("WallN")
	if wallN and wallN:IsA("BasePart") then
		wallN.CFrame = wallN.CFrame + Vector3.new(0, 0, 0.03)
		fixed += 1
	end

	-- The flower pots on the main map: the soil's top was the rim's top.
	local map = ctx.find("Workspace/TheMap")
	if map then
		for _, pot in map:GetChildren() do
			if pot.Name == "Pink Flower Pot" then
				local dirt = pot:FindFirstChild("Dirt")
				if dirt and dirt:IsA("BasePart") then
					dirt.CFrame = dirt.CFrame - Vector3.new(0, 0.05, 0)
					fixed += 1
				end
			end
		end
	end

	print(`glitch fixes: {fixed} parts corrected`)
end
