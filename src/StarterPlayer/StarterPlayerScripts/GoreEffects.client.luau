--!strict
-- Draws the death effect locally: a few low-poly chunks, a puff of mist, and flat
-- marks on the ground. Stylised on purpose -- blocky pieces and flat decals, not
-- realistic viscera, so it sits with the rest of the art.
--
-- Everything here is capped: a burst limit, a distance cutoff, short lifetimes, and
-- no collisions or queries on any piece.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local GameConfig = require(ReplicatedStorage.GameConfig)
local Cfg = GameConfig.Gore

local GoreEffect = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("GoreEffect") :: RemoteEvent

local camera = workspace.CurrentCamera

-- Effects live in one folder so they are easy to find and cannot clutter Workspace.
local bin = workspace:FindFirstChild("GoreEffects")
if not bin then
	bin = Instance.new("Folder")
	bin.Name = "GoreEffects"
	bin.Parent = workspace
end

local active = 0

local function makePiece(size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material)
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = bin
	return p
end

-- Flat marks pressed onto whatever is underneath.
local function splatter(origin: Vector3, colour: Color3, scale: number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { bin, camera }

	for _ = 1, Cfg.SplatterCount do
		local offset = Vector3.new(
			(math.random() - 0.5) * 8 * scale,
			0,
			(math.random() - 0.5) * 8 * scale
		)
		local hit = workspace:Raycast(origin + offset + Vector3.new(0, 3, 0), Vector3.new(0, -14, 0), params)
		if hit then
			local size = (1.6 + math.random() * 2.2) * scale
			local mark = makePiece(
				Vector3.new(size, 0.06, size * (0.6 + math.random() * 0.7)),
				CFrame.new(hit.Position + hit.Normal * 0.03) * CFrame.Angles(0, math.random() * math.pi * 2, 0),
				colour,
				Enum.Material.SmoothPlastic
			)
			mark.Anchored = true
			mark.Transparency = 0.15

			-- Fade rather than vanish, so it does not pop out of existence.
			TweenService:Create(mark, TweenInfo.new(Cfg.SplatterLifetime, Enum.EasingStyle.Linear), {
				Transparency = 1,
			}):Play()
			Debris:AddItem(mark, Cfg.SplatterLifetime + 0.2)
		end
	end
end

local function burst(origin: Vector3, bodyColour: Color3, scale: number, inherited: Vector3?)
	-- A short-lived puff to sell the impact.
	local mist = makePiece(
		Vector3.new(1, 1, 1) * (2.6 * scale),
		CFrame.new(origin),
		Cfg.MistColor,
		Enum.Material.Neon
	)
	mist.Anchored = true
	mist.Shape = Enum.PartType.Ball
	mist.Transparency = 0.25
	TweenService:Create(mist, TweenInfo.new(0.35, Enum.EasingStyle.Quad), {
		Size = Vector3.new(1, 1, 1) * (5.5 * scale),
		Transparency = 1,
	}):Play()
	Debris:AddItem(mist, 0.4)

	-- Chunks: blocky, unphysical enough to stay cheap, thrown outward.
	local carried = inherited or Vector3.zero
	for _ = 1, Cfg.ChunkCount do
		local s = Cfg.ChunkSize * scale * (0.6 + math.random() * 0.9)
		local chunk = makePiece(
			Vector3.new(s, s * (0.6 + math.random() * 0.8), s),
			CFrame.new(origin + Vector3.new(
				(math.random() - 0.5) * 2,
				1.2 + (math.random() - 0.5) * 1.5,   -- start above the ground, not in it
				(math.random() - 0.5) * 2
			)) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
			-- Mostly body colour, occasionally a darker red piece.
			math.random() < 0.35 and Cfg.BloodColor or bodyColour,
			Enum.Material.SmoothPlastic
		)
		chunk.Anchored = false
		chunk.Massless = false
		-- Chunks need to land on something. CanTouch/CanQuery stay off so they are
		-- still cheap: they collide with the world and nothing else notices them.
		chunk.CanCollide = true
		chunk.AssemblyLinearVelocity = Vector3.new(
			(math.random() - 0.5) * 34,
			12 + math.random() * 18,
			(math.random() - 0.5) * 34
		) * scale + carried * 0.4
		chunk.AssemblyAngularVelocity = Vector3.new(
			(math.random() - 0.5) * 24,
			(math.random() - 0.5) * 24,
			(math.random() - 0.5) * 24
		)

		-- Hold opaque while they tumble, then fade over the last stretch.
		task.delay(Cfg.ChunkLifetime * 0.45, function()
			if chunk.Parent then
				TweenService:Create(chunk, TweenInfo.new(Cfg.ChunkLifetime * 0.55, Enum.EasingStyle.Linear), {
					Transparency = 1,
				}):Play()
			end
		end)
		Debris:AddItem(chunk, Cfg.ChunkLifetime + 0.2)
	end

	splatter(origin, Cfg.BloodColor, scale)
end

GoreEffect.OnClientEvent:Connect(function(origin, bodyColour, scale, inherited)
	if not Cfg.Enabled or typeof(origin) ~= "Vector3" then
		return
	end

	camera = workspace.CurrentCamera
	-- Do not draw what the player cannot meaningfully see.
	if camera and (camera.CFrame.Position - origin).Magnitude > Cfg.MaxDistance then
		return
	end
	-- Hard ceiling on simultaneous bursts, so a big fight cannot tank the framerate.
	if active >= Cfg.MaxConcurrent then
		return
	end

	active += 1
	local ok, err = pcall(burst, origin, bodyColour or Color3.fromRGB(160, 160, 160), scale or 1, inherited)
	if not ok then
		warn("[Gore] " .. tostring(err))
	end

	-- Release the slot once the spawn burst is over. The parts themselves are already
	-- capped by their own short lifetimes and by Debris.
	task.delay(Cfg.BurstWindow, function()
		active = math.max(0, active - 1)
	end)
end)
