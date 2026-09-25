local Rocks = {}

local TS = game:GetService("TweenService")
local RS = game:GetService("ReplicatedStorage")
local PS = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")

local Modules = RS.Modules
local partCacheMod = require(Modules.PartCache)

local debrisFolder
if not workspace:FindFirstChild("Debris") then
	debrisFolder = Instance.new("Folder")
	debrisFolder.Name = "Debris"
	debrisFolder.Parent = workspace
else
	debrisFolder = workspace.Debris
end

local cacheFolder
if not debrisFolder:FindFirstChild("Parts") then
	cacheFolder = Instance.new("Folder")
	cacheFolder.Name = "Parts"
	cacheFolder.Parent = debrisFolder
else
	cacheFolder = workspace.Debris.Parts
end

local partCache = partCacheMod.new(Instance.new("Part"), 1000, cacheFolder)

function Rocks.BlockExplosion(TargetCFrame, sizeMin, sizeMax, minAmount, maxAmount, onFire)
	local random = Random.new(math.random(-20000, 20000))

	for partAdd = 1, math.random(minAmount, maxAmount) do
		local size = random:NextNumber(sizeMin, sizeMax)

		local origin = TargetCFrame.Position
		local direction = Vector3.new(0,-100,0)

		local Params = RaycastParams.new()
		Params.FilterDescendantsInstances = {debrisFolder}
		Params.FilterType = Enum.RaycastFilterType.Blacklist

		local raycastResult = workspace:Raycast(origin, direction, Params)

		local ray = Ray.new(origin + Vector3.new(0, 3, 0), Vector3.new(0, -50, 0))
		local hit, vec2Pos, surfaceNormal = workspace:FindPartOnRayWithIgnoreList(ray, {debrisFolder})

		if hit then
			local hitPart = hit

			local Effect = partCache:GetPart()
			Effect.Transparency = 0
			Effect.Anchored = false

			Effect.Material = hitPart.Material
			Effect.Color = hitPart.Color
			Effect.Size = Vector3.new(size,size,size)

			Effect.CFrame = TargetCFrame * CFrame.Angles(math.rad(math.random(-180, 180)), math.rad(math.random(15, 165)), math.rad(math.random(-180, 180)))

			Effect.CanCollide = true
			Effect.CanTouch = false
			Effect.CanQuery = false

			if onFire then
				local fireFX1 = script.OnFire.OnFire:Clone()
				local fireFX2 = script.OnFire.OnFireWisps:Clone()
				local fireFX3 = script.OnFire.OnFireSparks:Clone()
				local fireLight = script.OnFire.PointLight:Clone()

				fireFX1.Parent = Effect
				fireFX2.Parent = Effect
				fireFX3.Parent = Effect
				fireLight.Parent = Effect

				task.delay(2, function()
					TS:Create(fireLight, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Brightness = 0, Range = 0})
					fireFX1.Enabled = false
					fireFX2.Enabled = false
					fireFX3.Enabled = false
				end)

				game.Debris:AddItem(fireFX1, 3.5)
				game.Debris:AddItem(fireFX2, 3.5)
				game.Debris:AddItem(fireFX3, 3.5)
				game.Debris:AddItem(fireLight, 3.5)
			end

			local db = false

			task.delay(2.9, function()
				local endTween = TS:Create(Effect, TweenInfo.new(0.6, Enum.EasingStyle.Back), {Size = Vector3.new(0,0,0)}):Play()
			end)

			local EffectVelocity = Instance.new("BodyVelocity", Effect)
			EffectVelocity.MaxForce = Vector3.new(0.5, 2, 0.5) * 100000;
			EffectVelocity.Velocity = Vector3.new(0.5, 2, 0.5) * Effect.CFrame.LookVector * math.random(50, 70)

			game.Debris:AddItem(EffectVelocity, 0.3)
			task.delay(3.5, function()
				partCache:ReturnPart(Effect)
			end)
		end
	end
end

function Rocks.Ground(Pos, Distance, Size, filter, MaxRocks, Ice, despawnTime)
	local random = Random.new()
	
	local angle = 30
	local otherAngle = 360/MaxRocks
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = filter or {game.Players.LocalPlayer.Character, cacheFolder, debrisFolder}
	local size
	size = Size or Vector3.new(2, 2, 2)
	local pos = Pos
	despawnTime = despawnTime or 3
	
	local fxPart = Instance.new("Part")
	fxPart.Transparency = 1
	fxPart.Anchored = true
	fxPart.Position = Pos
	fxPart.Size = Vector3.new()
	
	fxPart.Parent = workspace.Debris
	
	local ray = workspace:Raycast(Pos + Vector3.new(0, 1, 0), Vector3.new(0, -25, 0), params)
	if ray then
		local dustFX = script.Dust:Clone()
		dustFX.Color = ColorSequence.new(ray.Instance.Color)
		
		dustFX.Parent = fxPart
		dustFX:Emit(dustFX:GetAttribute("EmitCount"))
	end
	
	
	
	game.Debris:AddItem(fxPart, 3)
	
	local function OuterRocksLoop ()
		for i = 1, MaxRocks do
			local cf = CFrame.new(Pos)
			local newCF = cf * CFrame.fromEulerAnglesXYZ(0, math.rad(angle), 0) * CFrame.new(Distance/2 + Distance/2.7, 10, 0)
			local ray = workspace:Raycast(newCF.Position, Vector3.new(0, -20, 0), params)
			angle += otherAngle
			if ray then
				local part = partCache:GetPart()
				local hoof = partCache:GetPart()
				
				part.CFrame = CFrame.new(ray.Position - Vector3.new(0, 0.5, 0), Pos) * CFrame.fromEulerAnglesXYZ(random:NextNumber(-.25, .5), random:NextNumber(-.25, .25), random:NextNumber(-.25, .25))
				part.Size = Vector3.new(size.X * 1.3, size.Y/1.4, size.Z * 1.3) * random:NextNumber(1, 1.5)
				
				hoof.Size = Vector3.new(part.Size.X * 1.01, part.Size.Y * 0.25, part.Size.Z * 1.01)
				hoof.CFrame = part.CFrame * CFrame.new(0, part.Size.Y/2 - hoof.Size.Y / 2.1, 0)
				
				part.Parent = cacheFolder
				hoof.Parent = cacheFolder
				
				if ray.Instance.Material == Enum.Material.Concrete or ray.Instance.Material == Enum.Material.Air or ray.Instance.Material == Enum.Material.Wood or ray.Instance.Material == Enum.Material.Neon or ray.Instance.Material == Enum.Material.WoodPlanks then
					part.Material = ray.Instance.Material	
					hoof.Material = ray.Instance.Material	
				else
					part.Material = Enum.Material.Concrete
					hoof.Material = ray.Instance.Material	
				end

				part.BrickColor = BrickColor.new("Dark grey")
				part.Anchored = true
				part.CanTouch = false
				part.CanCollide = false

				hoof.BrickColor = ray.Instance.BrickColor
				hoof.Anchored = true
				hoof.CanTouch = false
				hoof.CanCollide = false

				if Ice then
					part.BrickColor = BrickColor.new("Pastel light blue")
					hoof.BrickColor = BrickColor.new("Lily white")
					part.Material = Enum.Material.Ice
					hoof.Material = Enum.Material.Sand
				end
				
				task.delay(despawnTime, function()
					TS:Create(part,TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),{Size = Vector3.new(.01, .01, .01)}):Play()
					TS:Create(hoof,TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),{Size = Vector3.new(.01, .01, .01), CFrame = part.CFrame * CFrame.new(0, part.Size.Y/2 - part.Size.Y / 2.1, 0)}):Play()
					
					task.delay(0.6, function()
						partCache:ReturnPart(part)
						partCache:ReturnPart(hoof)
					end)
				end)
			end		
		end
	end

	local function InnerRocksLoop ()
		for i = 1, MaxRocks do
			local cf = CFrame.new(Pos)
			local newCF = cf * CFrame.fromEulerAnglesXYZ(0, math.rad(angle), 0) * CFrame.new(Distance/2 + Distance/10, 10, 0)
			local ray = game.Workspace:Raycast(newCF.Position, Vector3.new(0, -20, 0), params)
			angle += otherAngle
			if ray then
				local part = partCache:GetPart()
				local hoof = partCache:GetPart()

				part.CFrame = CFrame.new(ray.Position - Vector3.new(0, size.Y * 0.4, 0), Pos) * CFrame.fromEulerAnglesXYZ(random:NextNumber(-1,-0.3),random:NextNumber(-0.15,0.15),random:NextNumber(-.15,.15))
				part.Size = Vector3.new(size.X * 1.3, size.Y * 0.7, size.Z * 1.3) * random:NextNumber(1, 1.5)

				hoof.Size = Vector3.new(part.Size.X * 1.01, part.Size.Y * 0.25, part.Size.Z * 1.01)
				hoof.CFrame = part.CFrame * CFrame.new(0, part.Size.Y/2 - hoof.Size.Y / 2.1, 0)

				part.Parent = cacheFolder
				hoof.Parent = cacheFolder

				if ray.Instance.Material == Enum.Material.Concrete or ray.Instance.Material == Enum.Material.Air or ray.Instance.Material == Enum.Material.Wood or ray.Instance.Material == Enum.Material.Neon or ray.Instance.Material == Enum.Material.WoodPlanks then
					part.Material = ray.Instance.Material	
					hoof.Material = ray.Instance.Material	
				else
					part.Material = Enum.Material.Concrete --ray.Instance.Material	
					hoof.Material = ray.Instance.Material	
				end

				part.BrickColor = BrickColor.new("Dark grey") --ray.Instance.BrickColor
				part.Anchored = true
				part.CanTouch = false
				part.CanCollide = false

				hoof.BrickColor = ray.Instance.BrickColor
				hoof.Anchored = true
				hoof.CanTouch = false
				hoof.CanCollide = false

				if Ice then
					part.BrickColor = BrickColor.new("Pastel light blue")
					hoof.BrickColor = BrickColor.new("Lily white")
					part.Material = Enum.Material.Ice
					hoof.Material = Enum.Material.Sand
				end

				task.delay(despawnTime, function()
					TS:Create(part,TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),{Size = Vector3.new(.01, .01, .01)}):Play()
					TS:Create(hoof,TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),{Size = Vector3.new(.01, .01, .01), CFrame = part.CFrame * CFrame.new(0, part.Size.Y/2 - part.Size.Y / 2.1, 0)}):Play()

					task.delay(0.6, function()
						partCache:ReturnPart(part)
						partCache:ReturnPart(hoof)
					end)
				end)
			end		
		end
	end
	InnerRocksLoop()
	OuterRocksLoop()
end

function Rocks.OneLayerGround(Target, ZoneSize, PartSize, Amount, Duration)
	local posi = CFrame.new(Target.Position)
	local cfangle = posi * CFrame.Angles(0,math.rad(math.random(-360,360)),0)

	local folder = debrisFolder

	for v = 1, Amount do
		local partclone = partCache:GetPart()
		partclone.Anchored = true
		partclone.CFrame = cfangle * CFrame.Angles(0,math.rad(360/Amount*v),0)
		partclone.CFrame = partclone.CFrame * CFrame.new(0,-PartSize/2,0)

		local cf1 =  partclone.CFrame * CFrame.new(0,2,-10)
		local cf2 = partclone.CFrame * CFrame.new(0,2,-ZoneSize) * CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360)))

		game.Debris:AddItem(partclone, Duration + 1)

		local partonray,findrayatend = workspace:FindPartOnRayWithIgnoreList(Ray.new(cf2.p+ Vector3.new(0,10,0),CFrame.new(cf2.p).UpVector*-20), {game.Players.LocalPlayer.Character, debrisFolder})

		if partonray then
			local cf3 = nil
			partclone.Color = partonray.Color
			partclone.Material = partonray.Material
			cf3 = CFrame.new(findrayatend) * CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360)))
			partclone.Parent = folder

			if Target == nil then
				TS:Create(partclone,TweenInfo.new(.27,Enum.EasingStyle.Quad,Enum.EasingDirection.In,0,false,0),
					{
						CFrame = cf3}):Play()
				TS:Create(partclone.Mesh,TweenInfo.new(.27,Enum.EasingStyle.Quad,Enum.EasingDirection.InOut,0,false,0),
					{
						Scale = Vector3.new(PartSize,PartSize,PartSize)* (math.random(50,100)/100)
					}
				):Play()
			else
				partclone.CFrame = cf3
				partclone.Mesh.Scale = Vector3.new(PartSize,PartSize,PartSize)* (math.random(50,100)/100)
			end

			if Target == nil then
				task.wait(.25)
			end

			local weld = nil

			if partonray:IsDescendantOf(workspace)== false and partonray.Anchored == false then
				weld = Instance.new("Weld", partclone)
				weld.C0 = partonray.CFrame:inverse() * partclone.CFrame
				weld.Part0 = partonray
				weld.Part1= partclone
				partclone.Anchored = false
			end

			task.delay(Duration, function()
				if partclone and partclone:FindFirstChild("Mesh")==nil then
					partCache:ReturnPart(partclone)
					return
				end

				TS:Create(partclone.Mesh,TweenInfo.new(.5,Enum.EasingStyle.Cubic,Enum.EasingDirection.Out,0,false,0),
					{
						Scale = Vector3.new(0,0,0)
					}
				):Play()

				if weld == nil then
					TS:Create(partclone,TweenInfo.new(.5,Enum.EasingStyle.Cubic,Enum.EasingDirection.Out,0,false,0),
						{
							CFrame = CFrame.new(partclone.CFrame.p)*CFrame.new(0,-partclone.Size.X,0)
						}
					):play()
				end

				game.Debris:AddItem(partclone,1)
			end)
		else
			partCache:ReturnPart(partclone)
		end
	end
end

return Rocks
