--!strict
-- The things a gun does to the world when it goes off: the flash, the tracer, the mark
-- it leaves and the brass it throws. Client-only decoration -- nothing in here decides
-- anything, and none of it is replicated.
--
-- Everything is built from Parts rather than ParticleEmitters on purpose. The game is
-- flat-shaded low poly, and a soft round particle sprite reads as being from a different
-- game entirely; hard-edged shards sit with the art.
--
-- Every spawn goes through `track`, which enforces a global ceiling. A shotgun firing
-- into a crowd is the case that matters: eight pellets times a burst of impacts is enough
-- to visibly cost frames if it is unbounded.

local Debris = game:GetService("Debris")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local CombatFX = {}

local MAX_LIVE = 140
local live = 0

local bin = workspace:FindFirstChild("CombatFX")
if not bin then
	bin = Instance.new("Folder")
	bin.Name = "CombatFX"
	bin.Parent = workspace
end

local function track(part: BasePart, lifetime: number)
	live += 1
	part.Parent = bin
	Debris:AddItem(part, lifetime)
	task.delay(lifetime, function()
		live -= 1
	end)
end

local function budget(): boolean
	return live < MAX_LIVE
end

-- A bare part with every interaction switched off. Decoration must never be something
-- the physics engine, a raycast, or a Touched handler has to think about.
local function decor(size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	return p
end

-- ------------------------------------------------------------------- muzzle --

--- A weapon that came with its own flash geometry wears that instead of the built one.
--
-- The imported model carries the flash the artist authored, already welded in the right
-- place and sitting invisible. Showing it for a few frames is both more faithful and
-- cheaper than building a generic flash out of fresh parts every shot. Any weapon whose
-- import has parts tagged DMRole = "MuzzleFlash" gets this automatically.
local function authoredFlash(tool: Tool): boolean
	local shown = nil
	for _, d in ipairs(tool:GetDescendants()) do
		if d:IsA("BasePart") and d:GetAttribute("DMRole") == "MuzzleFlash" then
			shown = shown or {}
			table.insert(shown, d)
			d.Transparency = 0
		end
	end
	if not shown then
		return false
	end
	-- Hidden again on a timer rather than a heartbeat loop: a flash is two or three frames
	-- and a per-frame connection per shot is how you make a fast weapon expensive.
	task.delay(0.045, function()
		for _, part in ipairs(shown) do
			if part.Parent then
				part.Transparency = 1
			end
		end
	end)
	return true
end

--- The flash at the barrel: a bright core, a four-point star, and a light.
function CombatFX.MuzzleFlash(tool: Tool, colour: Color3)
	local muzzle = tool:FindFirstChild("Muzzle")
	if not muzzle or not muzzle:IsA("BasePart") or not budget() then
		return
	end

	local origin = muzzle.CFrame

	-- Authored geometry wins. The light below still fires either way -- it is what sells a
	-- flash in a dim spot, and the artist's petals are geometry, not illumination.
	local authored = authoredFlash(tool)

	-- The light is what actually sells a flash in a dim spot -- the geometry alone reads
	-- as a sticker. Reuses the PointLight the weapon already carries when there is one.
	-- A short, tight pop of light. Deliberately restrained: a bright wide light at the
	-- barrel lights the shooter's own body and the wall behind them, which reads as a
	-- lens flare rather than a gunshot and washes out the target you are aiming at.
	local light = muzzle:FindFirstChild("Flash")
	if light and light:IsA("PointLight") then
		light.Color = colour
		light.Range = 9
		light.Brightness = 3.2
		light.Shadows = false
		light.Enabled = true
		task.delay(0.04, function()
			if light and light.Parent then
				light.Brightness = 0
				light.Enabled = false
			end
		end)
	end

	if authored then
		return
	end

	-- Hot core, pushed just clear of the barrel.
	local core = decor(
		Vector3.new(0.26, 0.26, 0.46),
		origin * CFrame.new(0, 0, -0.3),
		Color3.new(1, 1, 1):Lerp(colour, 0.35),
		Enum.Material.Neon
	)
	core.Transparency = 0.08
	track(core, 0.05)
	TweenService:Create(core, TweenInfo.new(0.045), {
		Size = Vector3.new(0.04, 0.04, 0.16),
		Transparency = 1,
	}):Play()

	-- Three petals at a rolled angle, so consecutive shots do not stamp an identical
	-- shape. Three rather than four reads as a less symmetrical, more natural burst.
	local roll = math.random() * math.pi
	for i = 0, 2 do
		local angle = roll + i * (math.pi * 2 / 3)
		local petal = decor(
			Vector3.new(0.08, 0.5, 0.08),
			origin * CFrame.new(0, 0, -0.32) * CFrame.Angles(0, 0, angle) * CFrame.new(0, 0.21, 0),
			colour,
			Enum.Material.Neon
		)
		petal.Transparency = 0.3
		track(petal, 0.05)
		TweenService:Create(petal, TweenInfo.new(0.04), {
			Size = Vector3.new(0.02, 0.1, 0.02),
			Transparency = 1,
		}):Play()
	end

	-- Smoke drifting off the barrel, which is what makes a burst read as sustained fire
	-- rather than a string of unconnected flashes.
	if math.random() < 0.55 then
		local smoke = decor(
			Vector3.new(0.3, 0.3, 0.3),
			origin * CFrame.new((math.random() - 0.5) * 0.2, 0.05, -0.5),
			Color3.fromRGB(150, 148, 142),
			Enum.Material.SmoothPlastic
		)
		smoke.Transparency = 0.55
		track(smoke, 0.4)
		TweenService:Create(smoke, TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(1.1, 1.1, 1.1),
			CFrame = origin * CFrame.new((math.random() - 0.5) * 0.6, 0.7, -0.8),
			Transparency = 1,
		}):Play()
	end
end

--- Brass out of the ejection port. Unanchored so it tumbles and lands.
function CombatFX.EjectShell(tool: Tool)
	local muzzle = tool:FindFirstChild("Muzzle")
	local handle = tool:FindFirstChild("Handle")
	local from = handle or muzzle
	if not from or not from:IsA("BasePart") or not budget() then
		return
	end

	local shell = decor(
		Vector3.new(0.09, 0.09, 0.22),
		from.CFrame * CFrame.new(0.2, 0.1, 0) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
		Color3.fromRGB(206, 168, 84),
		Enum.Material.Metal
	)
	shell.Anchored = false
	shell.CanCollide = true
	-- Thrown up and to the right in the weapon's own frame, so it ejects sideways however
	-- the player happens to be facing.
	shell.AssemblyLinearVelocity = from.CFrame:VectorToWorldSpace(
		Vector3.new(6 + math.random() * 3, 4 + math.random() * 2, 0)
	)
	shell.AssemblyAngularVelocity = Vector3.new(
		(math.random() - 0.5) * 30,
		(math.random() - 0.5) * 30,
		(math.random() - 0.5) * 30
	)
	track(shell, 1.6)
	task.delay(1.1, function()
		if shell.Parent then
			TweenService:Create(shell, TweenInfo.new(0.5), { Transparency = 1 }):Play()
		end
	end)
end

-- ------------------------------------------------------------------ tracer --

--- A weapon's own authored effect geometry, if it shipped any.
--
-- Convention: ReplicatedStorage.WeaponVFX.<WeaponName>.<Effect>. Any weapon that comes in
-- with authored effects gets them used automatically; everything else falls through to the
-- built-in versions below, so nothing has to be special-cased per gun.
local function authored(weaponName: string?, effect: string): Model?
	if not weaponName then
		return nil
	end
	local root = ReplicatedStorage:FindFirstChild("WeaponVFX")
	local folder = root and root:FindFirstChild(weaponName)
	local template = folder and folder:FindFirstChild(effect)
	return (template and template:IsA("Model")) and template or nil
end

-- How fast a round appears to travel. Not real ballistics -- real rifle rounds arrive in
-- three hundredths of a second over combat distances, which is indistinguishable from
-- instant. This is slow enough to read as a round crossing the gap and fast enough that it
-- still lands before you have finished pulling the trigger again.
local TRACER_SPEED = 700      -- studs per second
local TRACER_MAX_FLIGHT = 0.5 -- seconds; a very long shot still arrives promptly
local STREAK_LENGTH = 14      -- how far the light trails behind the round

--- A round that actually crosses the gap, drawing its own streak as it goes.
--
-- The built-in tracer draws the whole line at once, which reads as a laser: the eye gets no
-- sense of a thing travelling. This flies the authored head and tail from muzzle to target
-- and trails a streak behind them that is drawn from the muzzle and then shortens once the
-- round has outrun it -- so the light leaves the barrel, stretches, and is dragged after the
-- round rather than hanging in the air.
local function flyTracer(template: Model, from: Vector3, to: Vector3, colour: Color3, width: number)
	local delta = to - from
	local length = delta.Magnitude
	local dir = delta.Unit
	local flight = math.min(length / TRACER_SPEED, TRACER_MAX_FLIGHT)

	local round = template:Clone()
	for _, p in ipairs(round:GetDescendants()) do
		if p:IsA("BasePart") then
			live += 1
			Debris:AddItem(p, flight + 0.3)
			task.delay(flight + 0.3, function()
				live -= 1
			end)
		end
	end
	round.Parent = bin

	local streak = decor(Vector3.new(width * 0.9, width * 0.9, 0.2), CFrame.new(from),
		Color3.new(1, 1, 1):Lerp(colour, 0.5), Enum.Material.Neon)
	streak.Transparency = 0.3
	track(streak, flight + 0.3)

	local started = os.clock()
	local conn: RBXScriptConnection
	conn = RunService.Heartbeat:Connect(function()
		local a = math.clamp((os.clock() - started) / flight, 0, 1)
		local head = from + dir * (length * a)
		if round.PrimaryPart or round:FindFirstChildWhichIsA("BasePart") then
			round:PivotTo(CFrame.lookAt(head, head + dir))
		end
		-- The streak starts at the muzzle and is let go of once the round is far enough out.
		local behind = math.max(0, length * a - STREAK_LENGTH)
		local tail = from + dir * behind
		local seg = head - tail
		local segLen = seg.Magnitude
		if segLen > 0.05 and streak.Parent then
			streak.Size = Vector3.new(width * 0.9, width * 0.9, segLen)
			streak.CFrame = CFrame.lookAt(tail + seg / 2, head)
		end
		if a >= 1 then
			conn:Disconnect()
			if streak.Parent then
				TweenService:Create(streak, TweenInfo.new(0.1), { Transparency = 1 }):Play()
			end
			for _, p in ipairs(round:GetDescendants()) do
				if p:IsA("BasePart") then
					TweenService:Create(p, TweenInfo.new(0.12), { Transparency = 1 }):Play()
				end
			end
		end
	end)
	-- A safety net: if the frame loop is ever interrupted, nothing is left flying.
	task.delay(flight + 0.4, function()
		if conn.Connected then
			conn:Disconnect()
		end
		if round.Parent then
			round:Destroy()
		end
	end)
end

--- The round in flight. Bright core with a dimmer, wider sheath so it reads at distance.
function CombatFX.Tracer(from: Vector3, to: Vector3, colour: Color3, width: number, weaponName: string?)
	local delta = to - from
	local length = delta.Magnitude
	if length < 0.2 or not budget() then
		return
	end

	local template = authored(weaponName, "Tracer")
	if template then
		flyTracer(template, from, to, colour, width)
		return
	end

	local cf = CFrame.lookAt(from + delta / 2, to)

	-- A thin bright line with only a hint of a sheath. The point of a tracer is to say
	-- where the round went; a fat glowing beam says it louder than the shot itself and
	-- turns sustained fire into a wall of light you cannot see the enemy through.
	local core = decor(Vector3.new(width * 0.8, width * 0.8, length), cf, Color3.new(1, 1, 1):Lerp(colour, 0.55), Enum.Material.Neon)
	core.Transparency = 0.15
	track(core, 0.07)
	TweenService:Create(core, TweenInfo.new(0.065), { Transparency = 1 }):Play()

	local glow = decor(Vector3.new(width * 1.7, width * 1.7, length), cf, colour, Enum.Material.Neon)
	glow.Transparency = 0.82
	track(glow, 0.07)
	TweenService:Create(glow, TweenInfo.new(0.065), { Transparency = 1 }):Play()
end

-- ------------------------------------------------------------------ impact --

local impactParams = RaycastParams.new()
impactParams.FilterType = Enum.RaycastFilterType.Exclude
impactParams.FilterDescendantsInstances = { bin }

-- How each kind of surface answers a bullet.
--
--   sparks   how many bright hot fragments fly off (metal throws them, dirt does not)
--   chips    solid debris in the surface's own colour
--   dust     size of the standing puff; stone and dirt make a lot, metal almost none
--   tint     colour of the hot flash at the point of contact
local SURFACE = {
	Metal = { sparks = 5, chips = 1, dust = 0.25, tint = Color3.fromRGB(255, 240, 190) },
	Wood = { sparks = 0, chips = 4, dust = 0.7, tint = Color3.fromRGB(214, 170, 116) },
	Stone = { sparks = 1, chips = 3, dust = 1.25, tint = Color3.fromRGB(226, 220, 208) },
	Dirt = { sparks = 0, chips = 2, dust = 1.4, tint = Color3.fromRGB(206, 186, 150) },
	Glass = { sparks = 3, chips = 4, dust = 0.35, tint = Color3.fromRGB(226, 246, 255) },
	Soft = { sparks = 0, chips = 2, dust = 0.55, tint = Color3.fromRGB(255, 226, 180) },
}

-- Roblox ships far more materials than there are meaningful reactions, so they are
-- bucketed. Anything unlisted falls through to Soft, which is the neutral response.
local MATERIAL_GROUP: { [Enum.Material]: string } = {
	[Enum.Material.Metal] = "Metal",
	[Enum.Material.DiamondPlate] = "Metal",
	[Enum.Material.CorrodedMetal] = "Metal",
	[Enum.Material.Foil] = "Metal",

	[Enum.Material.Wood] = "Wood",
	[Enum.Material.WoodPlanks] = "Wood",

	[Enum.Material.Concrete] = "Stone",
	[Enum.Material.Brick] = "Stone",
	[Enum.Material.Slate] = "Stone",
	[Enum.Material.Cobblestone] = "Stone",
	[Enum.Material.Rock] = "Stone",
	[Enum.Material.Sandstone] = "Stone",
	[Enum.Material.Basalt] = "Stone",
	[Enum.Material.Limestone] = "Stone",
	[Enum.Material.Marble] = "Stone",
	[Enum.Material.Granite] = "Stone",
	[Enum.Material.Pavement] = "Stone",

	[Enum.Material.Grass] = "Dirt",
	[Enum.Material.LeafyGrass] = "Dirt",
	[Enum.Material.Ground] = "Dirt",
	[Enum.Material.Mud] = "Dirt",
	[Enum.Material.Sand] = "Dirt",
	[Enum.Material.Snow] = "Dirt",

	[Enum.Material.Glass] = "Glass",
	[Enum.Material.Ice] = "Glass",
	[Enum.Material.Neon] = "Glass",
}

--- Where the round landed. The surface decides what comes off it: metal throws sparks,
--- wood throws splinters, stone throws dust. Chips are tinted from the part that was
--- actually hit, so debris belongs to the wall rather than being generic orange sparks.
--- A weapon's authored impact burst, thrown outward from the point of the hit.
--
-- Played IN ADDITION to the surface reaction below, not instead of it. They answer different
-- questions: the surface reaction says what you hit -- metal, wood, stone -- and the authored
-- burst says what hit it. Losing either one makes the game read worse.
--
-- Each piece is flung along the direction it was authored at, away from the model's centre,
-- so the artist's arrangement decides the shape of the burst rather than a random cone.
local function burstImpact(template: Model, position: Vector3, facing: Vector3)
	local burst = template:Clone()
	local centre = burst:GetBoundingBox()
	local aim = CFrame.lookAt(position, position + facing)

	for _, p in ipairs(burst:GetDescendants()) do
		if p:IsA("BasePart") then
			local offset = centre:PointToObjectSpace(p.Position)
			local startAt = aim * offset
			p.CFrame = CFrame.new(startAt) * (p.CFrame - p.CFrame.Position)

			local smoke = p.Name:match("^ImpactSmoke") ~= nil
			local throw = smoke and 1.6 or 3.4
			local life = smoke and 0.42 or 0.24
			local outward = (offset.Magnitude > 1e-3) and (aim:VectorToWorldSpace(offset.Unit)) or facing
			-- Smoke lifts as it spreads; sparks just go.
			local drift = smoke and Vector3.new(0, 0.7, 0) or Vector3.zero

			live += 1
			Debris:AddItem(p, life + 0.1)
			task.delay(life + 0.1, function()
				live -= 1
			end)

			local info = TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(p, info, {
				CFrame = p.CFrame + outward * throw * (0.6 + math.random() * 0.8) + drift,
				Transparency = 1,
				Size = smoke and (p.Size * 2.2) or (p.Size * 0.4),
			}):Play()
		end
	end
	burst.Parent = bin
	Debris:AddItem(burst, 0.8)
end

function CombatFX.Impact(position: Vector3, origin: Vector3?, weaponName: string?)
	-- The authored burst first, so it is not lost if the surface work bails on budget.
	local template = authored(weaponName, "Impact")
	if template and budget() then
		local facing = origin and (origin - position)
		burstImpact(template, position,
			(facing and facing.Magnitude > 1e-3) and facing.Unit or Vector3.new(0, 1, 0))
	end

	if not budget() then
		return
	end

	local normal = Vector3.yAxis
	local surfaceColour = Color3.fromRGB(150, 150, 150)
	local group = "Soft"

	-- One short backtrack along the shot to recover the surface. Cheap, and without it
	-- there is no normal to orient the burst against and no material to react to.
	if origin then
		local dir = position - origin
		if dir.Magnitude > 0.01 then
			local hit = workspace:Raycast(position - dir.Unit * 1.5, dir.Unit * 3, impactParams)
			if hit then
				normal = hit.Normal
				group = MATERIAL_GROUP[hit.Material] or "Soft"
				if hit.Instance and hit.Instance:IsA("BasePart") then
					surfaceColour = hit.Instance.Color
				end
			end
		end
	end

	local spec = SURFACE[group]

	-- The flash at the point of contact.
	local spark = decor(Vector3.new(0.26, 0.26, 0.26), CFrame.new(position), spec.tint, Enum.Material.Neon)
	track(spark, 0.1)
	TweenService:Create(spark, TweenInfo.new(0.09), {
		Size = Vector3.new(0.02, 0.02, 0.02),
		Transparency = 1,
	}):Play()

	-- Dust standing off the surface, oriented to it. Scaled per material, so a metal
	-- railing does not throw the same cloud as a dirt bank.
	if spec.dust > 0.2 then
		local puff = decor(
			Vector3.new(0.45, 0.45, 0.45) * spec.dust,
			CFrame.new(position + normal * 0.15),
			surfaceColour:Lerp(Color3.new(1, 1, 1), 0.3),
			Enum.Material.SmoothPlastic
		)
		puff.Transparency = 0.4
		track(puff, 0.3)
		TweenService:Create(puff, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = Vector3.new(1.2, 1.2, 1.2) * spec.dust,
			CFrame = CFrame.new(position + normal * (0.6 * spec.dust)),
			Transparency = 1,
		}):Play()
	end

	-- Hot sparks. Thin, fast, and gone quickly -- these are what make metal read as metal.
	for _ = 1, spec.sparks do
		if not budget() then
			break
		end
		local dir = (normal + Vector3.new((math.random() - 0.5) * 1.6, math.random() * 0.8, (math.random() - 0.5) * 1.6)).Unit
		local len = 0.3 + math.random() * 0.45
		local streak = decor(
			Vector3.new(0.05, 0.05, len),
			CFrame.lookAt(position + normal * 0.1 + dir * (len * 0.5), position + normal * 0.1 + dir * len),
			spec.tint,
			Enum.Material.Neon
		)
		track(streak, 0.16)
		TweenService:Create(streak, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(position + normal * 0.1 + dir * (len * 2.6), position + normal * 0.1 + dir * (len * 3.2)),
			Size = Vector3.new(0.01, 0.01, len * 0.3),
			Transparency = 1,
		}):Play()
	end

	-- Solid debris thrown back out of the surface along its normal.
	for _ = 1, spec.chips do
		if not budget() then
			break
		end
		local s = 0.07 + math.random() * 0.09
		-- Wood splinters are long and thin; everything else chips roughly cubic.
		local shape = (group == "Wood")
			and Vector3.new(s * 0.4, s * 0.4, s * 2.2)
			or Vector3.new(s, s * 0.65, s)
		local chip = decor(
			shape,
			CFrame.new(position + normal * 0.1) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
			group == "Glass" and surfaceColour:Lerp(Color3.new(1, 1, 1), 0.5) or surfaceColour,
			group == "Glass" and Enum.Material.Glass or Enum.Material.SmoothPlastic
		)
		chip.Anchored = false
		chip.CanCollide = false
		chip.AssemblyLinearVelocity = normal * (10 + math.random() * 10)
			+ Vector3.new((math.random() - 0.5) * 9, math.random() * 5, (math.random() - 0.5) * 9)
		chip.AssemblyAngularVelocity = Vector3.new(
			(math.random() - 0.5) * 30,
			(math.random() - 0.5) * 30,
			(math.random() - 0.5) * 30
		)
		track(chip, 0.7)
		task.delay(0.4, function()
			if chip.Parent then
				TweenService:Create(chip, TweenInfo.new(0.3), { Transparency = 1 }):Play()
			end
		end)
	end
end

-- ------------------------------------------------------------------ landing --

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude
groundParams.FilterDescendantsInstances = { bin }

--- Dust kicked up where a character lands, tinted from the surface they landed on.
--- `strength` is roughly 0.25 for a hop and 2 for a long drop.
function CombatFX.LandDust(position: Vector3, strength: number, ignore: Instance?)
	if not budget() then
		return
	end

	local s = math.clamp(strength, 0.2, 2)
	-- A gentle step should not throw dirt. Below this it reads as noise rather than weight.
	if s < 0.45 then
		return
	end

	groundParams.FilterDescendantsInstances = ignore and { bin, ignore } or { bin }
	local hit = workspace:Raycast(position + Vector3.new(0, 2, 0), Vector3.new(0, -6, 0), groundParams)
	if not hit then
		return
	end

	local ground = hit.Position
	local tint = (hit.Instance and hit.Instance:IsA("BasePart"))
		and hit.Instance.Color:Lerp(Color3.new(1, 1, 1), 0.3)
		or Color3.fromRGB(190, 180, 165)

	-- A ring of flat shards pushed outward, rather than a puff sphere: flat-shaded chips
	-- read as dust in a low-poly world where a soft round sprite would look imported.
	local count = s > 1.2 and 7 or 5
	for i = 1, count do
		if not budget() then
			break
		end
		local angle = (i / count) * math.pi * 2 + math.random() * 0.4
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local size = (0.35 + math.random() * 0.35) * s

		local puff = decor(
			Vector3.new(size, size * 0.35, size),
			CFrame.new(ground + hit.Normal * 0.1 + dir * 0.4) * CFrame.Angles(0, angle, 0),
			tint,
			Enum.Material.SmoothPlastic
		)
		puff.Transparency = 0.35
		track(puff, 0.45)

		TweenService:Create(puff, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(ground + hit.Normal * (0.5 * s) + dir * (2.2 * s)) * CFrame.Angles(0, angle, 0),
			Size = Vector3.new(size * 1.9, size * 0.12, size * 1.9),
			Transparency = 1,
		}):Play()
	end
end

-- --------------------------------------------------------------- hit flash --

-- A struck target flares for a moment. This is the single clearest signal that a shot
-- connected -- clearer than the crosshair marker, because it is at the thing being shot
-- rather than in the middle of the screen.
--
-- A small fixed pool, for the same reason OutlineService uses one: Roblox stops drawing
-- Highlights past roughly thirty live at once, and the outline pool already claims most
-- of that budget. Four is enough for any realistic exchange and cannot starve the rest.
local FLASH_POOL = 4
local flashes: { Highlight } = {}
local flashNext = 1

local flashHolder = Instance.new("Folder")
flashHolder.Name = "HitFlashes"
flashHolder.Parent = workspace.CurrentCamera

for i = 1, FLASH_POOL do
	local h = Instance.new("Highlight")
	h.Name = "HitFlash" .. i
	h.FillTransparency = 1
	h.OutlineTransparency = 1
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Enabled = false
	h.Adornee = nil
	h.Parent = flashHolder
	flashes[i] = h
end

--- Flare a model that has just been hit.
function CombatFX.HitFlash(model: Model, lethal: boolean?)
	if not model or not model.Parent then
		return
	end

	local h = flashes[flashNext]
	flashNext = flashNext % FLASH_POOL + 1

	h.Adornee = model
	h.FillColor = lethal and Color3.fromRGB(255, 60, 60) or Color3.fromRGB(255, 236, 190)
	h.OutlineColor = lethal and Color3.fromRGB(255, 120, 120) or Color3.fromRGB(255, 255, 255)
	h.FillTransparency = lethal and 0.25 or 0.45
	h.OutlineTransparency = 0.2
	h.Enabled = true

	local life = lethal and 0.32 or 0.16
	TweenService:Create(h, TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		FillTransparency = 1,
		OutlineTransparency = 1,
	}):Play()

	task.delay(life + 0.02, function()
		-- Only stand down if nothing else has claimed this one in the meantime, or a rapid
		-- second hit would be cut short by the first hit's timer.
		if h.Adornee == model then
			h.Enabled = false
			h.Adornee = nil
		end
	end)
end

-- ----------------------------------------------------------- damage numbers --

-- Numbers are pooled. Creating and destroying a BillboardGui per pellet is enough churn
-- on a shotgun to be felt, and the pool caps how many can ever be on screen at once.
local POOL_SIZE = 14
local pool: { BillboardGui } = {}
local poolNext = 1

local function borrowLabel(): BillboardGui
	local bb = pool[poolNext]
	if not bb then
		bb = Instance.new("BillboardGui")
		bb.Name = "DamageNumber"
		bb.Size = UDim2.fromOffset(120, 40)
		bb.AlwaysOnTop = true
		bb.LightInfluence = 0
		bb.MaxDistance = 220
		bb.Adornee = nil
		bb.Parent = bin

		local text = Instance.new("TextLabel")
		text.Name = "Value"
		text.Size = UDim2.fromScale(1, 1)
		text.BackgroundTransparency = 1
		text.Font = Enum.Font.GothamBlack
		text.TextStrokeColor3 = Color3.fromRGB(8, 8, 12)
		text.Parent = bb

		pool[poolNext] = bb
	end
	poolNext = poolNext % POOL_SIZE + 1
	return bb
end

--- A floating number where the round landed.
function CombatFX.DamageNumber(position: Vector3, amount: number, headshot: boolean?, lethal: boolean?)
	local bb = borrowLabel()
	local text = bb:FindFirstChild("Value") :: TextLabel?
	if not text then
		return
	end

	-- Spread consecutive hits apart. Without the jitter a burst stacks every number in
	-- exactly the same place and reads as one flickering digit.
	local jitter = Vector3.new((math.random() - 0.5) * 1.6, 0, (math.random() - 0.5) * 1.6)

	-- A BillboardGui needs something in the world to hang off, so each number borrows a
	-- throwaway invisible part that expires with it.
	local holder = decor(Vector3.new(0.05, 0.05, 0.05), CFrame.new(position + jitter), Color3.new(), Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	holder.Name = "NumberAnchor"
	track(holder, 0.85)
	bb.Adornee = holder

	if lethal then
		text.TextColor3 = Color3.fromRGB(255, 86, 86)
		text.TextSize = 30
	elseif headshot then
		text.TextColor3 = Color3.fromRGB(255, 202, 92)
		text.TextSize = 27
	else
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		text.TextSize = 22
	end

	text.Text = headshot and ("%d!"):format(math.round(amount)) or tostring(math.round(amount))
	text.TextTransparency = 0
	text.TextStrokeTransparency = 0.4
	bb.StudsOffset = Vector3.new(0, 0, 0)

	-- Rises and fades. Tweening StudsOffset rather than moving the part keeps it steady
	-- relative to the camera instead of drifting oddly when the player strafes.
	TweenService:Create(bb, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 2.6, 0),
	}):Play()
	TweenService:Create(text, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
		TextStrokeTransparency = 1,
	}):Play()
end

return CombatFX
