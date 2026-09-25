--!strict
-- A grenade going off: a flash of fire, a ring of shockwave along the ground, smoke that rolls
-- up, chunks of debris, a scorch mark, a boom -- and a shove to the camera if it was close.
--
-- Client only. NPC grenades (NPCAnimator) and players' frags (Utility) both draw with this,
-- so a blast looks the same whoever threw it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local ViewKick = require(ReplicatedStorage:WaitForChild("ViewKick"))

local ExplosionFX = {}

local function myRoot(): BasePart?
	local character = Players.LocalPlayer and Players.LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return (root and root:IsA("BasePart")) and root or nil
end

local function sound(id: string, at: Vector3, volume: number, speed: number, range: number)
	local holder = Instance.new("Part")
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.2, 0.2, 0.2)
	holder.CFrame = CFrame.new(at)
	holder.Parent = workspace
	local s = Instance.new("Sound")
	s.SoundId = id
	s.Volume = volume
	s.PlaybackSpeed = speed
	s.RollOffMaxDistance = range
	s.Parent = holder
	s:Play()
	task.delay(4, function()
		holder:Destroy()
	end)
end

function ExplosionFX.Play(centre: Vector3, radius: number)
	local function ball(colour: Color3, size: number, transparency: number): Part
		local p = Instance.new("Part")
		p.Shape = Enum.PartType.Ball
		p.Size = Vector3.new(size, size, size)
		p.Color = colour
		p.Material = Enum.Material.SmoothPlastic
		p.Transparency = transparency
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = false
		p.CFrame = CFrame.new(centre)
		p.Parent = workspace
		return p
	end
	local function grow(p: BasePart, size: number, time: number, style: Enum.EasingStyle?)
		local tween = TweenService:Create(p, TweenInfo.new(time, style or Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Size = Vector3.new(size, size, size), Transparency = 1 })
		tween.Completed:Once(function()
			p:Destroy()
		end)
		tween:Play()
	end
	local fire = ball(Color3.fromRGB(255, 150, 50), 2, 0)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 170, 90)
	light.Range = radius * 2.2
	light.Brightness = 6
	light.Parent = fire
	TweenService:Create(light, TweenInfo.new(0.35), { Brightness = 0 }):Play()
	grow(fire, radius * 1.1, 0.3)
	grow(ball(Color3.fromRGB(255, 236, 150), 1.5, 0), radius * 0.6, 0.18)
	-- Shockwave along the ground.
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.3, 2, 2)
	ring.Color = Color3.fromRGB(246, 238, 222)
	ring.Material = Enum.Material.SmoothPlastic
	ring.Transparency = 0.3
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.CastShadow = false
	ring.CFrame = CFrame.new(centre - Vector3.new(0, 1, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = workspace
	local wave = TweenService:Create(ring, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.new(0.3, radius * 2.4, radius * 2.4), Transparency = 1 })
	wave.Completed:Once(function()
		ring:Destroy()
	end)
	wave:Play()
	-- Smoke rolling up.
	for i = 1, 6 do
		local a = i / 6 * math.pi * 2
		local puff = ball(Color3.fromRGB(96, 92, 90):Lerp(Color3.fromRGB(150, 146, 140), (i % 3) / 2), 2.5, 0.1)
		puff.CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * 1.5, 0, math.sin(a) * 1.5))
		local drift = TweenService:Create(puff, TweenInfo.new(1.4 + i * 0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(centre + Vector3.new(math.cos(a) * radius * 0.35, 4 + i % 3 * 2, math.sin(a) * radius * 0.35)),
			Size = Vector3.new(6, 6, 6),
			Transparency = 1,
		})
		drift.Completed:Once(function()
			puff:Destroy()
		end)
		drift:Play()
	end
	-- Debris: low-poly chunks thrown out and falling.
	for _ = 1, 8 do
		local chunk = Instance.new("Part")
		chunk.Size = Vector3.new(0.5, 0.5, 0.5) * (0.6 + math.random())
		chunk.Color = Color3.fromRGB(70, 64, 58)
		chunk.Material = Enum.Material.SmoothPlastic
		chunk.Anchored = true
		chunk.CanCollide = false
		chunk.CanQuery = false
		chunk.CanTouch = false
		chunk.CFrame = CFrame.new(centre)
		chunk.Parent = workspace
		local velocity = Vector3.new(math.random() * 2 - 1, 0.9 + math.random() * 0.8, math.random() * 2 - 1).Unit
			* (18 + math.random() * 14)
		local born = os.clock()
		local fly
		fly = RunService.Heartbeat:Connect(function()
			local t = os.clock() - born
			if t > 0.9 then
				fly:Disconnect()
				chunk:Destroy()
				return
			end
			chunk.CFrame = CFrame.new(centre + velocity * t + Vector3.new(0, -48 * t * t, 0)) * CFrame.Angles(t * 9, t * 6, 0)
		end)
	end
	-- A scorch mark that fades.
	local scorch = Instance.new("Part")
	scorch.Shape = Enum.PartType.Cylinder
	scorch.Size = Vector3.new(0.05, radius * 0.9, radius * 0.9)
	scorch.Color = Color3.fromRGB(34, 30, 28)
	scorch.Material = Enum.Material.SmoothPlastic
	scorch.Transparency = 0.25
	scorch.Anchored = true
	scorch.CanCollide = false
	scorch.CanQuery = false
	scorch.CanTouch = false
	scorch.CastShadow = false
	scorch.CFrame = CFrame.new(centre - Vector3.new(0, 1.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	scorch.Parent = workspace
	local fade = TweenService:Create(scorch, TweenInfo.new(6, Enum.EasingStyle.Linear), { Transparency = 1 })
	fade.Completed:Once(function()
		scorch:Destroy()
	end)
	fade:Play()
	-- The boom, and the shove.
	sound("rbxassetid://9117893517", centre, 1.2, 0.55, 260)
	sound("rbxassetid://1112042117", centre, 1, 0.42, 260)
	local root = myRoot()
	if root then
		local d = (root.Position - centre).Magnitude
		if d < radius * 3.5 then
			local strength = math.clamp(1 - d / (radius * 3.5), 0.15, 1)
			ViewKick.Punch(-4 * strength, (math.random() - 0.5) * 3 * strength, (math.random() - 0.5) * 5 * strength,
				0.45, 0.6)
		end
	end
end

return ExplosionFX
