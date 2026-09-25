-- The gun range, dressed like the reference game's: a neon GUN RANGE gantry over the lane,
-- a huge sign glowing at the far end, neon lane edges, and a night city standing on both
-- sides. All of it is decoration -- no collision, no raycasts, no shadows -- so nothing about
-- shooting at the targets changes. Written into the place, so it can be moved in Studio.
return function(ctx)
	local roblox = ctx.roblox
	local Vector3, CFrame, Color3, Enum = roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum

	local range = ctx.find("Workspace/__DevRange")
	if not range then
		print("(range not found; skipped)")
		return
	end
	local dress = ctx.new("Folder", range, { Name = "NeonDressing" })

	local CYAN = Color3.fromRGB(40, 220, 255)
	local MAGENTA = Color3.fromRGB(255, 60, 200)
	local WINDOWS = {
		Color3.fromRGB(255, 214, 140), Color3.fromRGB(255, 214, 140), Color3.fromRGB(150, 220, 255),
		Color3.fromRGB(255, 120, 210), Color3.fromRGB(255, 236, 190),
	}

	-- Deterministic, so every build makes the same city.
	local seed = 2000
	local function rand(): number
		seed = (seed * 1103515245 + 12345) % 2147483648
		return seed / 2147483648
	end
	local function between(a: number, b: number): number
		return a + (b - a) * rand()
	end

	local function decor(name, size, cf, colour, material)
		local p = ctx.new("Part", dress, {
			Name = name,
			Size = size,
			CFrame = cf,
			Color = colour,
			Material = material or Enum.Material.SmoothPlastic,
			Anchored = true,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
			CastShadow = false,
		})
		return p
	end

	local function sign(text, centre, facing, width, height, colour)
		local board = decor("Sign_" .. text, Vector3.new(width, height, 0.1), CFrame.lookAt(centre, centre + facing), colour)
		board.Transparency = 1
		local gui = ctx.new("SurfaceGui", board, {
			Face = Enum.NormalId.Front,
			SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud,
			PixelsPerStud = 14,
			LightInfluence = 0,
			Brightness = 2.6,
		})
		local label = ctx.new("TextLabel", gui, {
			BackgroundTransparency = 1,
			Size = roblox.UDim2.fromScale(1, 1),
			Text = text,
			TextScaled = true,
			FontFace = roblox.Font.new("rbxasset://fonts/families/FredokaOne.json"),
			TextColor3 = colour:Lerp(Color3.new(1, 1, 1), 0.35),
		})
		ctx.new("UIStroke", label, { Color = colour, Thickness = 6, Transparency = 0.25 })
		return board
	end

	-- Lane edges, the full length of the floor (x = +/-40, z from 30 to -430, top at y 2000).
	for _, x in ipairs({ -39.7, 39.7 }) do
		decor("LaneEdge", Vector3.new(0.5, 0.3, 460), CFrame.new(x, 2000.1, -200), CYAN, Enum.Material.Neon)
	end

	-- The gantry over the lane, just downrange of the spawn.
	for _, x in ipairs({ -38, 38 }) do
		decor("GantryPost", Vector3.new(1.2, 22, 1.2), CFrame.new(x, 2011, -22), Color3.fromRGB(30, 32, 40),
			Enum.Material.Metal)
		decor("GantryGlow", Vector3.new(0.4, 20, 0.4), CFrame.new(x, 2011, -21.3), MAGENTA, Enum.Material.Neon)
	end
	decor("GantryBeam", Vector3.new(78, 1.4, 1.2), CFrame.new(0, 2022, -22), Color3.fromRGB(30, 32, 40),
		Enum.Material.Metal)
	decor("GantryBeamGlow", Vector3.new(76, 0.35, 0.4), CFrame.new(0, 2021.2, -21.3), CYAN, Enum.Material.Neon)
	sign("GUN RANGE", Vector3.new(0, 2017, -21.2), Vector3.new(0, 0, 1), 44, 7, CYAN)

	-- The far end: a huge sign behind the last target, and a glowing backstop.
	sign("GUN RANGE", Vector3.new(0, 2034, -440), Vector3.new(0, 0, 1), 80, 18, MAGENTA)
	decor("Backstop", Vector3.new(84, 22, 2), CFrame.new(0, 2010, -436), Color3.fromRGB(24, 26, 34),
		Enum.Material.Concrete)
	decor("BackstopGlow", Vector3.new(84, 0.5, 0.4), CFrame.new(0, 2021, -434.9), MAGENTA, Enum.Material.Neon)

	-- The city down both sides of the lane.
	local names = { "ZEE", "24/7", "ARCADE", "GG", "MOTEL", "AMMO", "PLAY", "BAR" }
	local count = 0
	for _, side in ipairs({ -1, 1 }) do
		for z = 40, -440, -32 do
			local w, d, h = between(16, 28), between(14, 24), between(60, 140)
			local base = Vector3.new(side * between(72, 110), 1960 + h / 2, z + between(-6, 6))
			local cf = CFrame.lookAt(base, Vector3.new(0, base.Y, base.Z))
			local body = decor("Tower", Vector3.new(w, h, d), cf,
				Color3.fromRGB(18 + math.floor(rand() * 8), 20 + math.floor(rand() * 8), 30 + math.floor(rand() * 10)))
			local rows = math.floor(h / 9)
			for r = 1, rows do
				local y = -h / 2 + 6 + r * 8
				if rand() < 0.7 and y < h / 2 - 3 then
					local lit = decor("Windows", Vector3.new(w * between(0.4, 0.85), 1.2, 0.2),
						body.CFrame * CFrame.new(between(-w * 0.1, w * 0.1), y, -d / 2 - 0.12),
						WINDOWS[1 + math.floor(rand() * #WINDOWS)], Enum.Material.Neon)
					lit.Transparency = between(0, 0.35)
				end
			end
			count += 1
			if count % 3 == 0 then
				local roof = body.CFrame * CFrame.new(0, h / 2 + 5, -d / 2 + 1)
				sign(names[(count // 3 - 1) % #names + 1], roof.Position, roof.LookVector, w * 0.9, 8,
					rand() < 0.5 and MAGENTA or CYAN)
			end
		end
	end
	print(("range dressed: %d parts"):format(#dress:GetDescendants()))
end
