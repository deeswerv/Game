local DebrisModule = {}

local ts = game:GetService("TweenService")
local cs = game:GetService("CollectionService")
local rs = game:GetService("ReplicatedStorage")
local PS = game:GetService("PhysicsService")
local RunService = game:GetService("RunService")
local Debris = game:GetService("Debris")

local RS = rs

local partCacheMod = require(rs.Modules.PartCache)
local BoltModule = require(rs.Modules.LightningBolt)
local SparksModule = require(rs.Modules.LightningBolt.LightningSparks)

local cacheFolder = workspace:WaitForChild("Debris")

local floor = cs:GetTagged("Floor")

local partCache = partCacheMod.new(Instance.new("Part"), 1000, cacheFolder)

local function GetXAndZPositions(Angle, Radius)
	local X = math.cos(Angle) * Radius 
	local Z = math.sin(Angle) * Radius
	return X, Z
end

local function CreateCircle(Part, Number)
	local Attachments = { }
	local FullCircle = 2 * math.pi
	local Radius = 7

	for i = 1, Number do
		local Attachment = Instance.new('Attachment')
		Attachment.Parent = Part

		local Angle = i * (FullCircle / Number)
		local X, Z = GetXAndZPositions(Angle, Radius)

		local Position = ( Part.CFrame * CFrame.new(X, 0, Z) ).Position
		local LookAt = Part.Position

		Attachment.WorldCFrame = CFrame.lookAt(Position, LookAt)
		table.insert(Attachments, Attachment)
	end
	return Attachments
end

function DebrisModule.lightningWaves(TargetPosition, Amount, Color)
	local PartMarker = Instance.new('Part')
	PartMarker.Name = 'Marker'
	PartMarker.Position = TargetPosition
	PartMarker.Anchored = true
	PartMarker.CanCollide = false
	PartMarker.CanTouch = false
	PartMarker.Transparency = 1
	PartMarker.Size = Vector3.new(1, 1, 1)
	PartMarker.Parent = workspace.Debris

	local Marker = Instance.new("Attachment")
	Marker.Parent = PartMarker

	local Circle = CreateCircle(PartMarker, Amount or 8)
	
	for _ = 1, math.random(5, 15) do
		local Lightning = BoltModule.new(Marker, Circle[math.random(#Circle)], 22)
		Lightning.MinRadius = 1
		Lightning.MaxRadius = 2
		Lightning.AnimationSpeed = 7
		Lightning.FadeLength = 0.7
		Lightning.PulseLength = 1
		Lightning.Thickness = math.random(0.5, 1.5)
		Lightning.PulseSpeed = math.random(8, 10)
		Lightning.Color = Color or Color3.fromRGB(203, 255, 254)
		SparksModule.new(Lightning)

		task.wait(0.02)
	end
end

function DebrisModule.sphereExp(targetPosition : Vector3, initialSize : number, targetSize : number, color : Color3)
	local Sphere = Instance.new('Part')
	Sphere.Anchored = true
	Sphere.CanCollide, Sphere.CastShadow, Sphere.CanTouch, Sphere.CanQuery = false, false, false, false
	Sphere.Size = Vector3.new(initialSize, initialSize, initialSize)
	Sphere.Position = targetPosition
	Sphere.Color = color
	Sphere.Material = Enum.Material.ForceField
	Sphere.Shape = Enum.PartType.Ball
	Sphere.Parent = workspace.Debris
	game:GetService("TweenService"):Create(Sphere, TweenInfo.new(0.75, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = Vector3.new(targetSize, targetSize, targetSize), Transparency = 1}):Play()
	Debris:AddItem(Sphere, 0.5)
end

function DebrisModule.lightningExplosion(Target, Amount, Color)
	coroutine.wrap(function()
		for _ = 1, Amount do
			local Attachment = Instance.new('Attachment')
			Attachment.WorldCFrame = Target.CFrame * CFrame.new(math.random(-45, 45), math.random(10, 25), math.random(-45, 45))
			Attachment.Parent = workspace.Terrain
			
			local Attachment1 = Instance.new('Attachment')
			Attachment1.Parent = Target
			local Bolt = BoltModule.new(Attachment1, Attachment, 11)
			Bolt.PulseSpeed = 4.25
			Bolt.PulseLength = 0.7
			--Bolt.FadeLength = 0.0001
			Bolt.Thickness = Random.new():NextNumber(0.6, 0.85)
			Bolt.MinThicknessMultiplier, Bolt.MaxThicknessMultiplier = 0.65, 1
			Bolt.AnimationSpeed = 6.25
			Bolt.MaxRadius = 10
			Bolt.MinTransparency, Bolt.MaxTransparency = 0, 1
			Bolt.ContractFrom = 1
			Bolt.Color = Color
			
			game.Debris:AddItem(Attachment, 2)
			game.Debris:AddItem(Attachment1, 2)
			
			task.wait(0.025)
		end
	end)()
end

function DebrisModule.BnWImpact()
	local ColorCorrection = Instance.new('ColorCorrectionEffect')
	ColorCorrection.Brightness = 0.1
	ColorCorrection.Saturation = -1
	ColorCorrection.Contrast = -5
	ColorCorrection.Parent = game.Lighting

	task.wait(0.05)
	ColorCorrection.Contrast = 1

	task.wait(0.05)
	ts:Create(ColorCorrection, TweenInfo.new(0.35, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Saturation = 0, Contrast = 0, Brightness = 0}):Play()
	Debris:AddItem(ColorCorrection, 0.35)
end

function DebrisModule.Shockwave(targetPos : Vector3, initialSize : number, targetSize : number)
	local Shockwave = script.Shockwave:Clone()
	Shockwave.Size = Vector3.new(4, initialSize, initialSize)
	Shockwave.Position = targetPos
	Shockwave.Parent = workspace.Debris
	ts:Create(Shockwave, TweenInfo.new(1, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), {Size = Vector3.new(4, targetSize, targetSize), Orientation = Shockwave.Orientation + Vector3.new(0, 240, 0)}):Play()
	task.wait(0.2)
	ts:Create(Shockwave, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Size = Vector3.new(0, targetSize, targetSize), Transparency = 1}):Play()
	Debris:AddItem(Shockwave, 0.5)
end

function DebrisModule.BlockExplosion(TargetCFrame, sizeMin, sizeMax, minAmount, maxAmount, onFire, Ice)
	
	local folder = workspace.Debris
	
	local random = Random.new(math.random(-20000, 20000))
	
	for partAdd = 1, math.random(minAmount, maxAmount) do
		local size = random:NextNumber(sizeMin, sizeMax)
		
		local origin = TargetCFrame.Position
		local direction = Vector3.new(0,-100,0)

		local floor = cs:GetTagged("Floor")

		local Params = RaycastParams.new()
		Params.FilterDescendantsInstances = floor
		Params.FilterType = Enum.RaycastFilterType.Whitelist

		local raycastResult = workspace:Raycast(origin, direction, Params)
		
		local ray = Ray.new(origin + Vector3.new(0, 3, 0), Vector3.new(0, -50, 0))
		local hit, vec2Pos, surfaceNormal = workspace:FindPartOnRayWithWhitelist(ray, floor)
		
		if hit then
			local hitPart = hit
			
			local Effect = partCache:GetPart() --script:WaitForChild("Block"):Clone()
			Effect.Transparency = 0
			Effect.Anchored = false
			
			Effect.Material = hitPart.Material
			Effect.Color = hitPart.Color
			Effect.Size = Vector3.new(size,size,size)

			Effect.CFrame = TargetCFrame * CFrame.Angles(math.rad(math.random(-180, 180)), math.rad(math.random(15, 165)), math.rad(math.random(-180, 180)))
			
			Effect.CanCollide = true
			Effect.CanTouch = false
			Effect.CanQuery = false
			
			if Ice then
				Effect.Material = Enum.Material.Sand
				Effect.BrickColor = BrickColor.new("Lily white")
			end
			
			if onFire then
				local fireFX1 = rs.FX.OnFire.OnFire:Clone()
				local fireFX2 = rs.FX.OnFire.OnFireWisps:Clone()
				local fireFX3 = rs.FX.OnFire.OnFireSparks:Clone()
				local fireLight = rs.FX.OnFire.PointLight:Clone()
				
				fireFX1.Parent = Effect
				fireFX2.Parent = Effect
				fireFX3.Parent = Effect
				fireLight.Parent = Effect
				
				task.delay(2, function()
					ts:Create(fireLight, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut), {Brightness = 0, Range = 0})
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
				local endTween = ts:Create(Effect, TweenInfo.new(0.6, Enum.EasingStyle.Back), {Size = Vector3.new(0,0,0)}):Play()
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

function DebrisModule.TreeDestruction(Tree, Tag, Hitbox)
	
	local function removalFX(Target)
		local bigCircle = RS.FX:FindFirstChild("BigCircle"):Clone()
		local Balls = RS.FX:FindFirstChild("Balls"):Clone()
		local Lines = RS.FX:FindFirstChild("Lines"):Clone()

		local attachment = Instance.new("Attachment")

		bigCircle.Parent = attachment
		Balls.Parent = Target
		Lines.Parent = Target

		attachment.Parent = Target

		Balls:Emit(30)
		Lines:Emit(20)

		task.delay(1.5, function()
			attachment:Destroy()
			Balls:Destroy()
			Lines:Destroy()
		end)
	end

	local function neonFlash(Target, originalMaterial, OriginalBrickColor)
		task.delay(0.05, function()
			local sfxStart = RS.Sounds:FindFirstChild("DebrisRemoving"):Clone()
			sfxStart.Parent = Target
			sfxStart:Play()

			Target.Material = Enum.Material.Neon
			Target.BrickColor = BrickColor.new("Persimmon")
			task.wait(0.05)
			Target.Material = originalMaterial
			Target.BrickColor = OriginalBrickColor

			task.delay(0.1, function()
				Target.Material = Enum.Material.Neon
				Target.BrickColor = BrickColor.new("Persimmon")
				task.wait(0.05)
				Target.Material = originalMaterial
				Target.BrickColor = OriginalBrickColor

				task.delay(0.1, function()
					Target.Material = Enum.Material.Neon
					Target.BrickColor = BrickColor.new("Persimmon")
					task.wait(0.05)
					Target.Material = originalMaterial
					Target.BrickColor = OriginalBrickColor
					task.delay(0.1, function()
						Target.Material = Enum.Material.Neon
						Target.BrickColor = BrickColor.new("Persimmon")
					end)
				end)
			end)
		end)
	end

	local function neonFlashSpawning(Target, originalMaterial, OriginalBrickColor)
		task.delay(0.05, function()
			local sfxStart = RS.Sounds:FindFirstChild("DebrisSpawning"):Clone()
			sfxStart.Volume = 0.07
			sfxStart.Parent = Target
			sfxStart:Play()

			Target.Material = Enum.Material.Neon
			Target.BrickColor = BrickColor.new("Shamrock")
			task.wait(0.05)
			Target.Material = originalMaterial
			Target.BrickColor = OriginalBrickColor

			task.delay(0.1, function()
				Target.Material = Enum.Material.Neon
				Target.BrickColor = BrickColor.new("Shamrock")
				task.wait(0.05)
				Target.Material = originalMaterial
				Target.BrickColor = OriginalBrickColor

				task.delay(0.1, function()
					Target.Material = Enum.Material.Neon
					Target.BrickColor = BrickColor.new("Shamrock")
					task.wait(0.05)
					Target.Material = originalMaterial
					Target.BrickColor = OriginalBrickColor
					task.delay(0.1, function()
						Target.Material = Enum.Material.Neon
						Target.BrickColor = BrickColor.new("Shamrock")
						task.wait(0.05)
						Target.Material = originalMaterial
						Target.BrickColor = OriginalBrickColor
					end)
				end)
			end)
		end)
	end
	
	--print("1")
	
	if cs:HasTag(Tree, "Tree") or cs:HasTag(Tree, "Bush") then
		--warn("2")
		local tag

		local target = Tree
		if cs:HasTag(target, "Tree") then
			tag = "Tree"
			cs:RemoveTag(target, tag)
		end
		
		if cs:HasTag(target, "Bush") then
			tag = "Bush"
			cs:RemoveTag(target, tag)
		end

		local Clone = target:Clone()
		Clone.Parent = RS.DebrisCache

		target.Parent = workspace.Debris

		task.delay(15, function()


			for i, v in pairs(Clone:GetChildren()) do
				local originalSize = Instance.new("Vector3Value")
				originalSize.Value = v.Size
				originalSize.Parent = v

				game.Debris:AddItem(originalSize, 1)

				local args = {
					Size = originalSize.Value;
					Transparency = 0
				}

				local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.In)

				v.Size = Vector3.new(0.05, 0.05, 0.05)
				v.Transparency = 1

				if Clone.Parent ~= workspace then
					Clone.Parent = workspace
					cs:AddTag(Clone, tag)
					cs:RemoveTag(Clone, Tag)
				end

				local tween = ts:Create(v, tweenInfo, args):Play()

				neonFlashSpawning(v, v.Material, v.BrickColor)

				task.delay(0.45, function()
					local endSfx = RS.Sounds:FindFirstChild("Pop"):Clone()
					endSfx.Parent = v
					endSfx:Play()
				end)
			end
		end)

		cs:AddTag(target, Tag)

		--if hit.Name == "Log" then
			local sfx = RS.Sounds:FindFirstChild("FallingTree"):Clone()
			sfx.Parent = Tree.Log
			sfx:Play()
		--end

		local args = {
			Size = Vector3.new(0.005, 0.005, 0.005);
			Transparency = 1
		}

		local tweenInfo = TweenInfo.new(0.5, Enum.EasingStyle.Elastic, Enum.EasingDirection.In)

		game.Debris:AddItem(target, 8)

		for i, v in pairs(target:GetChildren()) do
			PS:SetPartCollisionGroup(v, "Debris")

			if v:FindFirstChildWhichIsA("Weld") then
				v:FindFirstChildWhichIsA("Weld"):Destroy()
			end
			if v:FindFirstAncestorWhichIsA("WeldConstraint") then
				v:FindFirstAncestorWhichIsA("WeldConstraint"):Destroy()
			end
			if v:FindFirstAncestorWhichIsA("Motor6D") then
				v:FindFirstAncestorWhichIsA("Motor6D"):Destroy()
			end

			--Combat.StrongKnockback(v, 40, 65, 0.2, hitPart)
			--Misc.UpKnockback(v, 40, 65, 0.1, Hitbox)

			v.Anchored = false
			v.CanCollide = true
			v.CanTouch = false
			v.CanQuery = false
			
			
			
			local breakFX = RS.FX:FindFirstChild("DebrisBreak"):Clone()
			breakFX.Color = ColorSequence.new(v.Color)
			breakFX.Parent = v
			breakFX:Emit(40)
			task.delay(0.1, function()
				v:SetNetworkOwner(nil)
			end)

			task.delay(5, function()
				v.Anchored = true
				local tween = ts:Create(v, tweenInfo, args)
				tween:Play()
				task.delay(0.45, function()
					removalFX(v)
					local endSfx = RS.Sounds:FindFirstChild("Pop"):Clone()
					endSfx.Parent = v
					endSfx:Play()
				end)
				neonFlash(v, v.Material, v.BrickColor)
			end)
		end
	end
	
end

function DebrisModule.Ground(Pos, Distance, Size, filter, MaxRocks, Ice, despawnTime)
	local random = Random.new()

	local angle = 30
	local otherAngle = 360/MaxRocks
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Blacklist
	params.FilterDescendantsInstances = filter or {game.Players.LocalPlayer.Character, cacheFolder, workspace.Debris}
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
					ts:Create(part,TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),{Size = Vector3.new(.01, .01, .01)}):Play()
					ts:Create(hoof,TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),{Size = Vector3.new(.01, .01, .01), CFrame = part.CFrame * CFrame.new(0, part.Size.Y/2 - part.Size.Y / 2.1, 0)}):Play()

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
					ts:Create(part,TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),{Size = Vector3.new(.01, .01, .01)}):Play()
					ts:Create(hoof,TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),{Size = Vector3.new(.01, .01, .01), CFrame = part.CFrame * CFrame.new(0, part.Size.Y/2 - part.Size.Y / 2.1, 0)}):Play()

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

function DebrisModule.SideRocks(cf2, duration, size, spread)
	local random = Random.new(math.random(-math.huge, math.huge))
	local sizeVariation = random:NextNumber(0.9, 1.05)
	
	local angle = 180
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Whitelist
	params.FilterDescendantsInstances = {floor}
	local rockf = workspace.Debris
	for i= 1,2 do
		local cf = cf2
		local newcf = cf * CFrame.fromEulerAnglesXYZ(0, math.rad(angle), 0) * CFrame.new(spread, 0, 0)
		local ray = game.Workspace:Raycast(newcf.Position, Vector3.new(0,-10,0), params)
		if ray then			
			local part = partCache:GetPart()
			part.Transparency = 0
			part.CanCollide = false
			part.CFrame = newcf * CFrame.new(Vector3.new(0,.5,0))
			part.Size = Vector3.new(size, size, size) * sizeVariation
			part.Position = ray.Position
			part.Material = ray.Instance.Material
			part.BrickColor = ray.Instance.BrickColor
			part.Anchored = true
			part.Orientation = Vector3.new(math.random(-180,180), math.random(-180,180), math.random(-180,180))
			angle += 180
			part.Parent = rockf
			
			task.delay(duration,function()
				local twi = TweenInfo.new(0.7)
				local goal = {Size = Vector3.new(.01,.01,.01)}
				local tween = ts:Create(part,twi,goal)
				tween:Play()

				task.delay(0.71, function()
					if part then
						partCache:ReturnPart(part)
					end
				end)
			end)
		end
	end
end

return DebrisModule
