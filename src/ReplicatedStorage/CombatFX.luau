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
	-- Brighter and wider than it used to be: the flash has to light the space around the
	-- shooter for a frame or two, or sustained fire reads as a toy. Still short, so it never
	-- washes out the target.
	local light = muzzle:FindFirstChild("Flash")
	if light and light:IsA("PointLight") then
		light.Color = colour
		light.Range = 13
		light.Brightness = 5
		light.Shadows = false
		light.Enabled = true
		task.delay(0.05, function()
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
		Vector3.new(0.42, 0.42, 0.75),
		origin * CFrame.new(0, 0, -0.4),
		Color3.new(1, 1, 1):Lerp(colour, 0.3),
		Enum.Material.Neon
	)
	core.Transparency = 0.02
	track(core, 0.06)
	TweenService:Create(core, TweenInfo.new(0.055), {
		Size = Vector3.new(0.06, 0.06, 0.22),
		Transparency = 1,
	}):Play()

	-- A flat disc of light facing forward: the "bloom" a camera catches at the muzzle, and
	-- the thing that makes a shot readable from the side as well as from behind.
	local disc = decor(
		Vector3.new(0.05, 1.05, 1.05),
		origin * CFrame.new(0, 0, -0.25) * CFrame.Angles(0, math.pi / 2, 0),
		colour:Lerp(Color3.new(1, 1, 1), 0.25),
		Enum.Material.Neon
	)
	disc.Shape = Enum.PartType.Cylinder
	disc.Transparency = 0.35
	track(disc, 0.06)
	TweenService:Create(disc, TweenInfo.new(0.05), {
		Size = Vector3.new(0.02, 1.6, 1.6),
		Transparency = 1,
	}):Play()

	-- Three petals at a rolled angle, so consecutive shots do not stamp an identical
	-- shape. Three rather than four reads as a less symmetrical, more natural burst.
	local roll = math.random() * math.pi
	for i = 0, 2 do
		local angle = roll + i * (math.pi * 2 / 3)
		local petal = decor(
			Vector3.new(0.12, 0.85, 0.12),
			origin * CFrame.new(0, 0, -0.42) * CFrame.Angles(0, 0, angle) * CFrame.new(0, 0.36, 0),
			colour,
			Enum.Material.Neon
		)
		petal.Transparency = 0.15
		track(petal, 0.06)
		TweenService:Create(petal, TweenInfo.new(0.05), {
			Size = Vector3.new(0.03, 0.18, 0.03),
			Transparency = 1,
		}):Play()
	end

	-- Smoke drifting off the barrel, which is what makes a burst read as sustained fire
	-- rather than a string of unconnected flashes.
	if math.random() < 0.8 then
		local smoke = decor(
			Vector3.new(0.34, 0.34, 0.34),
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

-- ---------------------------------------------------------- where it fires --

--- Where the round leaves the weapon, as this client is drawing it right now.
---
--- The server's copy of a gun is not posed the way anyone sees it -- the arms, the aim and
--- the sway are all applied client side -- so a position that came from the server is
--- somewhere near the shooter, not at the barrel. Every tracer used to start there, and
--- that is why they visibly came out of the air beside the gun rather than out of it.
---
--- A fitted muzzle device moves the point to the front of the device, so a suppressed
--- rifle fires from the end of the can rather than from inside it.
function CombatFX.MuzzleCFrame(tool: Instance?): CFrame?
	if not tool or not tool.Parent then
		return nil
	end
	local muzzle = tool:FindFirstChild("Muzzle")
	if not muzzle or not muzzle:IsA("BasePart") then
		return nil
	end
	local cf = muzzle.CFrame
	local look = cf.LookVector
	local fitted = tool:FindFirstChild("Attachments")
	if fitted then
		local reach = 0
		for _, p in ipairs(fitted:GetChildren()) do
			if p:IsA("BasePart") and string.sub(p.Name, 1, 7) == "Muzzle_" then
				-- How far the device's front face sits past the marker, measured along the
				-- bore whatever way the part itself is turned.
				local half = math.abs(p.CFrame.RightVector:Dot(look)) * p.Size.X / 2
					+ math.abs(p.CFrame.UpVector:Dot(look)) * p.Size.Y / 2
					+ math.abs(p.CFrame.LookVector:Dot(look)) * p.Size.Z / 2
				reach = math.max(reach, (p.Position - cf.Position):Dot(look) + half)
			end
		end
		if reach > 0 then
			cf += look * reach
		end
	end
	return cf
end

--- The same, as a point, falling back to where the server said the shot came from.
---
--- The fallback is used when the weapon is not somewhere this client can draw it (dropped,
--- not streamed in) or when the drawn gun is implausibly far from the server's origin, which
--- happens for a frame after a teleport or a respawn and would otherwise fire a tracer across
--- the map.
function CombatFX.MuzzlePoint(tool: Instance?, fallback: Vector3?): Vector3?
	local cf = CombatFX.MuzzleCFrame(tool)
	if not cf then
		return fallback
	end
	if fallback and (cf.Position - fallback).Magnitude > 14 then
		return fallback
	end
	return cf.Position
end

-- ------------------------------------------------------------------ flight --
--
-- A tracer is a round you can see, so it is drawn as one: a short hot streak that leaves the
-- barrel, crosses the gap at the speed the weapon throws it, and is swallowed by whatever it
-- hits. The streak is two camera-facing beams -- a thin white-hot core and a wider coloured
-- sheath -- that taper from the head back to nothing at the tail, which is the shape the
-- eye actually sees when something bright moves fast. The old tracer drew the whole line at
-- once and faded it, which reads as a laser pointer.
--
-- Speeds are not real ballistics. A real rifle round crosses a duel arena in a hundredth of a
-- second, which is indistinguishable from a line. These are slow enough to watch and fast
-- enough that the round lands before the next trigger pull, and every weapon class throws at
-- its own pace, so a sniper's round cracks across the map while a pistol's visibly travels.

local TRACER_MAX_FLIGHT = 0.3 -- seconds; a very long shot is sped up to arrive promptly

-- Per class: studs per second, and how long the streak is. A pellet is short and slow; a
-- sniper's round is a long needle of light.
local BALLISTICS: { [string]: { speed: number, streak: number, trail: number } } = {
	Pistol = { speed = 620, streak = 7, trail = 0 },
	SMG = { speed = 760, streak = 8, trail = 0 },
	Rifle = { speed = 980, streak = 12, trail = 0 },
	Shotgun = { speed = 560, streak = 4.5, trail = 0 },
	Sniper = { speed = 1700, streak = 26, trail = 0.9 },
}
local DEFAULT_BALLISTICS = BALLISTICS.Rifle

local WeaponConfig: any = nil
local function ballisticsFor(weaponName: string?)
	if not weaponName then
		return DEFAULT_BALLISTICS
	end
	-- Required on first use: WeaponConfig is data and loads nothing back, but keeping this
	-- module's load order independent of it costs nothing.
	if WeaponConfig == nil then
		local module = ReplicatedStorage:FindFirstChild("WeaponConfig")
		local ok, loaded = pcall(function()
			return (require :: any)(module)
		end)
		WeaponConfig = (module and ok) and loaded or false
	end
	local cfg = WeaponConfig and WeaponConfig.Get(weaponName)
	local b = (cfg and BALLISTICS[cfg.Class]) or DEFAULT_BALLISTICS
	if cfg and (type(cfg.TracerSpeed) == "number" or type(cfg.TracerStreak) == "number") then
		b = {
			speed = cfg.TracerSpeed or b.speed,
			streak = cfg.TracerStreak or b.streak,
			trail = b.trail,
		}
	end
	return b
end

-- One anchored, invisible part carries every beam endpoint. Attachments on a part at the
-- world origin are positioned in world space directly, and one host means a shotgun blast
-- costs sixteen attachments rather than eight parts and eight welds.
local host: Part? = nil
local function beamHost(): Part
	if host and host.Parent then
		return host
	end
	local p = Instance.new("Part")
	p.Name = "TracerHost"
	p.Size = Vector3.new(0.05, 0.05, 0.05)
	p.CFrame = CFrame.new()
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Transparency = 1
	p.Parent = bin
	host = p
	return p
end

local function point(at: Vector3): Attachment
	local a = Instance.new("Attachment")
	a.Position = at
	a.Parent = beamHost()
	return a
end

-- A camera-facing ribbon from a0 (the tail) to a1 (the head). No texture: flat colour,
-- which is what sits with low-poly art.
local function ribbon(a0: Attachment, a1: Attachment, colour: Color3, tailWidth: number,
	headWidth: number, transparency: NumberSequence): Beam
	local b = Instance.new("Beam")
	b.Attachment0 = a0
	b.Attachment1 = a1
	b.Color = ColorSequence.new(colour)
	b.Width0 = tailWidth
	b.Width1 = headWidth
	b.Transparency = transparency
	b.LightEmission = 1
	b.LightInfluence = 0
	b.FaceCamera = true
	b.Segments = 1
	b.Parent = a0.Parent
	return b
end

-- Tail to head: nothing at the tail, hottest at the head.
local CORE_FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.45, 0.6),
	NumberSequenceKeypoint.new(1, 0),
})
local SHEATH_FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.6, 0.86),
	NumberSequenceKeypoint.new(1, 0.5),
})

type Flight = {
	from: Vector3,
	dir: Vector3,
	length: number,
	speed: number,
	streak: number,
	started: number,
	tail: Attachment,
	head: Attachment,
	beams: { Beam },
	tip: BasePart?,
	round: Model?,
	-- The faint vapour line a heavy round leaves hanging along its whole path.
	trail: Beam?,
	trailStart: Attachment?,
	trailEnd: Attachment?,
	trailStrength: number,
	landed: number?,
	frames: number,
}

local flights: { Flight } = {}
local flightLoop: RBXScriptConnection? = nil

local function dropFlight(f: Flight)
	for _, b in ipairs(f.beams) do
		b:Destroy()
	end
	f.tail:Destroy()
	f.head:Destroy()
	if f.tip then
		f.tip:Destroy()
		live -= 1
	end
	if f.round then
		f.round:Destroy()
	end
	if f.trail then
		f.trail:Destroy()
	end
	if f.trailStart then
		f.trailStart:Destroy()
	end
	if f.trailEnd then
		f.trailEnd:Destroy()
	end
	live -= 1
end

-- How long the vapour line hangs after the round lands.
local TRAIL_LINGER = 0.45
-- How long the streak stays joined to the barrel before it detaches and flies.
local MUZZLE_HOLD = 0.035

local function stepFlights()
	local now = os.clock()
	local i = 1
	while i <= #flights do
		local f = flights[i]
		-- Never less than a frame of travel, so a point-blank shot still shows its streak
		-- for the one frame it exists instead of starting and ending at the muzzle.
		local travelled = math.max(now - f.started, 1 / 60) * f.speed
		local headAt = math.min(travelled, f.length)
		-- The tail keeps flying after the head has stopped, so the streak is swallowed by
		-- the impact rather than hanging at the wall and fading.
		local tailAt = math.clamp(travelled - f.streak, 0, headAt)
		-- For its first moment the streak is held to the barrel. A rifle round covers
		-- sixteen studs in one frame at 60 fps, so without this the first thing ever drawn
		-- is a streak already floating clear of the gun -- which is exactly the "tracers do
		-- not line up with the barrel" look. Held, it visibly leaves the muzzle.
		f.frames += 1
		if f.frames <= 1 or now - f.started < MUZZLE_HOLD then
			tailAt = 0
		end
		local head = f.from + f.dir * headAt
		f.head.Position = head
		f.tail.Position = f.from + f.dir * tailAt
		if f.tip then
			f.tip.CFrame = CFrame.new(head)
			f.tip.Transparency = travelled >= f.length and 1 or 0
		end
		if f.round then
			f.round:PivotTo(CFrame.lookAt(head, head + f.dir))
		end

		local done = tailAt >= f.length - 1e-3
		if f.trail and f.trailEnd then
			f.trailEnd.Position = head
			if done and not f.landed then
				f.landed = now
			end
			local faded = f.landed and math.clamp((now - f.landed) / TRAIL_LINGER, 0, 1) or 0
			local base = 1 - f.trailStrength * 0.16 * (1 - faded)
			f.trail.Transparency = NumberSequence.new(math.clamp(base, 0, 1))
			done = faded >= 1
		end

		if done then
			dropFlight(f)
			flights[i] = flights[#flights]
			flights[#flights] = nil
		else
			i += 1
		end
	end
	if #flights == 0 and flightLoop then
		flightLoop:Disconnect()
		flightLoop = nil
	end
end

--- Launches one round from `from` to `to`. Returns how long it takes to arrive, so the
--- impact can be timed to the moment it lands.
local function launch(from: Vector3, to: Vector3, colour: Color3, width: number, weaponName: string?,
	template: Model?): number
	local delta = to - from
	local length = delta.Magnitude
	local b = ballisticsFor(weaponName)
	local speed = math.max(b.speed, length / TRACER_MAX_FLIGHT)
	local flight = length / speed
	if length < 0.2 or not budget() then
		return flight
	end
	live += 1

	local dir = delta.Unit
	local tail = point(from)
	local head = point(from)
	local hot = Color3.new(1, 1, 1):Lerp(colour, 0.35)
	local beams = {
		ribbon(tail, head, colour, width * 0.5, width * 3.4, SHEATH_FADE),
		ribbon(tail, head, hot, width * 0.15, width * 1.1, CORE_FADE),
	}

	local f: Flight = {
		from = from,
		dir = dir,
		length = length,
		speed = speed,
		streak = b.streak,
		started = os.clock(),
		tail = tail,
		head = head,
		beams = beams,
		tip = nil,
		round = nil,
		trail = nil,
		trailStart = nil,
		trailEnd = nil,
		trailStrength = b.trail,
		landed = nil,
		frames = 0,
	}

	if template then
		-- An authored round rides the head of the streak.
		local round = template:Clone()
		round:PivotTo(CFrame.lookAt(from, from + dir))
		round.Parent = bin
		f.round = round
	elseif budget() then
		-- The glint at the head of the round: the one point of solid light the streak grows
		-- out of. Without it the streak's head is a soft edge and reads as a smear.
		local tip = decor(Vector3.new(width * 1.3, width * 1.3, width * 1.3), CFrame.new(from), hot,
			Enum.Material.Neon)
		tip.Shape = Enum.PartType.Ball
		tip.Parent = bin
		live += 1
		f.tip = tip
	end

	if b.trail > 0 then
		local s = point(from)
		local e = point(from)
		f.trailStart = s
		f.trailEnd = e
		f.trail = ribbon(s, e, Color3.fromRGB(226, 228, 232), width * 0.9, width * 1.6,
			NumberSequence.new(1))
	end

	table.insert(flights, f)
	if not flightLoop then
		flightLoop = RunService.Heartbeat:Connect(stepFlights)
	end
	-- A safety net: if the frame loop is ever starved, nothing is left in the air.
	task.delay(flight + TRAIL_LINGER + 1, function()
		local at = table.find(flights, f)
		if at then
			dropFlight(f)
			table.remove(flights, at)
		end
	end)
	return flight
end

--- The round in flight, from the barrel to where it landed.
---
--- Returns the flight time in seconds, so the caller can land the impact when the round
--- does rather than before it has left the gun.
function CombatFX.Tracer(from: Vector3, to: Vector3, colour: Color3, width: number, weaponName: string?): number
	return launch(from, to, colour, width, weaponName, authored(weaponName, "Tracer"))
end

--- How long a round from `from` to `to` is in the air, without drawing anything.
function CombatFX.FlightTime(from: Vector3, to: Vector3, weaponName: string?): number
	local length = (to - from).Magnitude
	return length / math.max(ballisticsFor(weaponName).speed, length / TRACER_MAX_FLIGHT)
end

--- How many rounds are in the air on this client right now. For tests.
function CombatFX.InFlight(): number
	return #flights
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

-- Bullet holes: a flat dark mark left on the surface, which is what makes a wall you have
-- been shooting at look shot. Capped and short-lived so a long firefight cannot litter the
-- map, and never left on a character.
local MAX_HOLES = 48
local HOLE_LIFETIME = 9
local holes: { BasePart } = {}

local function bulletHole(position: Vector3, normal: Vector3, surfaceColour: Color3)
	while #holes >= MAX_HOLES do
		local oldest = table.remove(holes, 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end
	local size = 0.22 + math.random() * 0.08
	local hole = decor(
		Vector3.new(size, size, 0.02),
		CFrame.lookAt(position + normal * 0.012, position + normal) * CFrame.Angles(0, 0, math.random() * math.pi),
		surfaceColour:Lerp(Color3.fromRGB(12, 10, 10), 0.82),
		Enum.Material.SmoothPlastic
	)
	hole.Name = "BulletHole"
	hole.Transparency = 0.1
	hole.Parent = bin
	table.insert(holes, hole)
	Debris:AddItem(hole, HOLE_LIFETIME + 1)
	task.delay(HOLE_LIFETIME, function()
		if hole.Parent then
			TweenService:Create(hole, TweenInfo.new(1), { Transparency = 1 }):Play()
		end
	end)
end

--- A red puff off a body, instead of dust and a bullet hole. Stylised -- a few flat-shaded
--- chunks, matching GoreEffects -- and short.
local function fleshHit(position: Vector3, normal: Vector3)
	local mist = decor(Vector3.new(0.5, 0.5, 0.5), CFrame.new(position + normal * 0.2),
		Color3.fromRGB(190, 26, 34), Enum.Material.SmoothPlastic)
	mist.Transparency = 0.25
	track(mist, 0.28)
	TweenService:Create(mist, TweenInfo.new(0.26, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(1.3, 1.3, 1.3),
		CFrame = CFrame.new(position + normal * 0.6),
		Transparency = 1,
	}):Play()
	for _ = 1, 3 do
		if not budget() then
			break
		end
		local s = 0.1 + math.random() * 0.1
		local chip = decor(Vector3.new(s, s, s),
			CFrame.new(position + normal * 0.1) * CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6),
			Color3.fromRGB(150, 16, 24), Enum.Material.SmoothPlastic)
		chip.Anchored = false
		chip.AssemblyLinearVelocity = normal * (8 + math.random() * 8)
			+ Vector3.new((math.random() - 0.5) * 8, 4 + math.random() * 4, (math.random() - 0.5) * 8)
		track(chip, 0.6)
		task.delay(0.35, function()
			if chip.Parent then
				TweenService:Create(chip, TweenInfo.new(0.25), { Transparency = 1 }):Play()
			end
		end)
	end
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
	local surfaceFound = false
	local flesh = false

	-- One short backtrack along the shot to recover the surface. Cheap, and without it
	-- there is no normal to orient the burst against and no material to react to.
	if origin then
		local dir = position - origin
		if dir.Magnitude > 0.01 then
			local hit = workspace:Raycast(position - dir.Unit * 1.5, dir.Unit * 3, impactParams)
			if hit then
				normal = hit.Normal
				group = MATERIAL_GROUP[hit.Material] or "Soft"
				surfaceFound = true
				if hit.Instance and hit.Instance:IsA("BasePart") then
					surfaceColour = hit.Instance.Color
				end
				local model = hit.Instance and hit.Instance:FindFirstAncestorOfClass("Model")
				flesh = model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
			end
		end
	end

	if flesh then
		fleshHit(position, normal)
		return
	end

	local spec = SURFACE[group]

	-- The flash at the point of contact: big enough to find at thirty studs.
	local spark = decor(Vector3.new(0.5, 0.5, 0.5), CFrame.new(position), spec.tint, Enum.Material.Neon)
	track(spark, 0.12)
	TweenService:Create(spark, TweenInfo.new(0.1), {
		Size = Vector3.new(0.04, 0.04, 0.04),
		Transparency = 1,
	}):Play()

	if surfaceFound then
		bulletHole(position, normal, surfaceColour)
	end

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
		text.Font = Enum.Font.FredokaOne
		text.TextStrokeTransparency = 1
		text.Parent = bb
		-- A proper thick outline rather than the thin built-in text stroke: the same dark
		-- edge every number in the HUD wears.
		local edge = Instance.new("UIStroke")
		edge.Name = "Edge"
		edge.Color = Color3.fromRGB(8, 8, 12)
		edge.Thickness = 2.4
		edge.LineJoinMode = Enum.LineJoinMode.Round
		edge.Parent = text

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

	local size
	if lethal then
		text.TextColor3 = Color3.fromRGB(255, 60, 60)
		size = 36
	elseif headshot then
		text.TextColor3 = Color3.fromRGB(255, 206, 60)
		size = 32
	else
		text.TextColor3 = Color3.fromRGB(255, 255, 255)
		size = 26
	end

	text.Text = headshot and ("%d!"):format(math.round(amount)) or tostring(math.round(amount))
	text.TextTransparency = 0
	local edge = text:FindFirstChild("Edge")
	if edge and edge:IsA("UIStroke") then
		edge.Transparency = 0
		TweenService:Create(edge, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
			Transparency = 1,
		}):Play()
	end
	bb.StudsOffset = Vector3.new(0, 0, 0)

	-- Slammed in oversized, then settling: a number that pops reads as an impact, one that
	-- merely appears reads as a label.
	text.TextSize = math.floor(size * 1.6)
	TweenService:Create(text, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		TextSize = size,
	}):Play()

	-- Rises and fades. Tweening StudsOffset rather than moving the part keeps it steady
	-- relative to the camera instead of drifting oddly when the player strafes.
	TweenService:Create(bb, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		StudsOffset = Vector3.new(0, 2.6, 0),
	}):Play()
	TweenService:Create(text, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		TextTransparency = 1,
	}):Play()
end

-- ---------------------------------------------------------------- kill burst --

local KILL_GOLD = Color3.fromRGB(255, 208, 60)

--- The moment a target goes down: a gold shockwave across the ground, shards flung out of
--- the body and a flash of light -- the burst the references play on every elimination.
--- Everyone sees it, which is the point: a kill should be readable across the map.
function CombatFX.KillBurst(model: Model)
	if not model or not model.Parent or not budget() then
		return
	end
	local root = model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart
	if not root or not root:IsA("BasePart") then
		return
	end
	local centre = root.Position

	-- Shockwave ring, flat on the ground under the body.
	groundParams.FilterDescendantsInstances = { bin, model }
	local floor = workspace:Raycast(centre, Vector3.new(0, -8, 0), groundParams)
	local ground = floor and floor.Position or (centre - Vector3.new(0, 2.8, 0))
	local ring = decor(Vector3.new(0.15, 2, 2), CFrame.new(ground + Vector3.new(0, 0.1, 0)) * CFrame.Angles(0, 0, math.pi / 2),
		KILL_GOLD, Enum.Material.Neon)
	ring.Shape = Enum.PartType.Cylinder
	ring.Transparency = 0.2
	track(ring, 0.45)
	TweenService:Create(ring, TweenInfo.new(0.42, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.05, 13, 13),
		Transparency = 1,
	}):Play()

	-- Light pop.
	local glow = decor(Vector3.new(0.2, 0.2, 0.2), CFrame.new(centre), KILL_GOLD, Enum.Material.Neon)
	glow.Transparency = 1
	local light = Instance.new("PointLight")
	light.Color = KILL_GOLD
	light.Range = 16
	light.Brightness = 6
	light.Shadows = false
	light.Parent = glow
	track(glow, 0.4)
	TweenService:Create(light, TweenInfo.new(0.38, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Brightness = 0,
	}):Play()

	-- Star shards out of the chest, gold and white, spinning as they go.
	for i = 1, 10 do
		if not budget() then
			break
		end
		local angle = (i / 10) * math.pi * 2 + math.random() * 0.5
		local dir = Vector3.new(math.cos(angle), 0.35 + math.random() * 0.9, math.sin(angle)).Unit
		local shard = decor(Vector3.new(0.22, 0.22, 0.9),
			CFrame.lookAt(centre, centre + dir),
			(i % 3 == 0) and Color3.new(1, 1, 1) or KILL_GOLD, Enum.Material.Neon)
		track(shard, 0.5)
		local reach = 4 + math.random() * 3
		TweenService:Create(shard, TweenInfo.new(0.45, Enum.EasingStyle.Quart, Enum.EasingDirection.Out), {
			CFrame = CFrame.lookAt(centre + dir * reach, centre + dir * (reach + 1)) * CFrame.Angles(0, 0, math.random() * 6),
			Size = Vector3.new(0.05, 0.05, 0.3),
			Transparency = 1,
		}):Play()
	end
end

-- ---------------------------------------------------------------- cash burst --

--- Banknotes thrown out of a body you just dropped -- the reference's cash-on-kill beat.
--- Only the killer sees it (it is triggered from their own lethal hit), and it is one
--- BillboardGui with a handful of labels, gone in a second.
function CombatFX.CashBurst(position: Vector3)
	if not budget() then
		return
	end
	local holder = decor(Vector3.new(0.05, 0.05, 0.05), CFrame.new(position + Vector3.new(0, 1, 0)),
		Color3.new(), Enum.Material.SmoothPlastic)
	holder.Transparency = 1
	holder.Name = "CashBurst"
	track(holder, 1.3)

	local bb = Instance.new("BillboardGui")
	bb.Size = UDim2.fromOffset(260, 220)
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.MaxDistance = 250
	bb.Adornee = holder
	bb.Parent = holder

	for i = 1, 6 do
		local bill = Instance.new("TextLabel")
		bill.BackgroundTransparency = 1
		bill.Text = "💵"
		bill.TextSize = 30
		bill.Font = Enum.Font.SourceSansBold
		bill.AnchorPoint = Vector2.new(0.5, 0.5)
		bill.Position = UDim2.fromScale(0.5, 0.6)
		bill.Size = UDim2.fromOffset(40, 40)
		bill.Rotation = math.random(-30, 30)
		bill.Parent = bb
		local angle = (i / 6) * math.pi - math.pi + (math.random() - 0.5) * 0.5
		local reach = 70 + math.random() * 40
		local info = TweenInfo.new(0.9, Enum.EasingStyle.Quart, Enum.EasingDirection.Out)
		TweenService:Create(bill, info, {
			Position = UDim2.new(0.5, math.cos(angle) * reach, 0.6, math.sin(angle) * reach * 0.8 - 20),
			Rotation = bill.Rotation + math.random(-120, 120),
			TextSize = 22,
		}):Play()
		task.delay(0.55, function()
			if bill.Parent then
				TweenService:Create(bill, TweenInfo.new(0.4), { TextTransparency = 1 }):Play()
			end
		end)
	end
end

-- --------------------------------------------------------- authored bursts --
--
-- Imported effects live in ReplicatedStorage.VFX (tools/patches/050_vfx.luau puts them there,
-- switched off). They follow their plugin's convention: each ParticleEmitter says when it
-- fires (EmitDelay), how many it throws at once (EmitCount) and how long it streams for at its
-- own Rate (EmitDuration). An effect is therefore a timeline, not a single puff -- the gem
-- charge draws in for most of a second and then bursts -- and it is played as authored.

local function scaledSequence(seq: NumberSequence, k: number): NumberSequence
	local points = {}
	for _, p in ipairs(seq.Keypoints) do
		table.insert(points, NumberSequenceKeypoint.new(p.Time, p.Value * k, p.Envelope * k))
	end
	return NumberSequence.new(points)
end

-- Every size, speed and distance in an effect, multiplied. The imports are authored at ability
-- scale -- a five-stud core and a twenty-stud shock ring -- and a headshot wants the same
-- effect at the size of a head.
local function rescale(root: Instance, k: number)
	if math.abs(k - 1) < 1e-3 then
		return
	end
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			d.Size = scaledSequence(d.Size, k)
			d.Speed = NumberRange.new(d.Speed.Min * k, d.Speed.Max * k)
			d.Acceleration *= k
		elseif d:IsA("Beam") then
			d.Width0 *= k
			d.Width1 *= k
			d.CurveSize0 *= k
			d.CurveSize1 *= k
		elseif d:IsA("Attachment") then
			d.CFrame = d.CFrame.Rotation + d.CFrame.Position * k
		end
	end
end

-- How long a beam in an effect stays up: through the emitters' streaming phase, then faded.
local BEAM_FADE = 0.2

--- Plays ReplicatedStorage.VFX.<name> at `at`.
---
--- `follow`, when given, is a part the effect rides for its whole life -- a headshot's
--- effect stays on the head it hit as the body falls. `scale` shrinks or grows the whole
--- effect. Returns how long it lasts, or nil when there is no such effect.
function CombatFX.PlayVFX(name: string, at: Vector3, follow: BasePart?, scale: number?): number?
	local folder = ReplicatedStorage:FindFirstChild("VFX")
	local template = folder and folder:FindFirstChild(name)
	if not template then
		return nil
	end
	local fx = template:Clone()
	rescale(fx, scale or 1)
	local anchor: BasePart? = if fx:IsA("BasePart") then fx else fx:FindFirstChildWhichIsA("BasePart", true)
	if not anchor then
		fx:Destroy()
		return nil
	end
	anchor.Anchored = true
	anchor.Transparency = 1
	anchor.CFrame = CFrame.new(at)
	fx.Parent = bin

	local longest = 0
	local streaming = 0
	local beams: { Beam } = {}
	for _, d in ipairs(fx:GetDescendants()) do
		if d:IsA("ParticleEmitter") then
			local emitter = d
			local delay = tonumber(emitter:GetAttribute("EmitDelay")) or 0
			local count = tonumber(emitter:GetAttribute("EmitCount")) or 0
			local duration = tonumber(emitter:GetAttribute("EmitDuration")) or 0
			-- An emitter that says nothing at all fires once, rather than silently never.
			if count <= 0 and duration <= 0 and emitter:GetAttribute("EmitCount") == nil
				and emitter:GetAttribute("EmitDuration") == nil then
				count = 1
			end
			emitter.Enabled = false
			task.delay(delay, function()
				if not emitter.Parent then
					return
				end
				if count > 0 then
					emitter:Emit(math.floor(count + 0.5))
				end
				if duration > 0 then
					emitter.Enabled = true
					task.delay(duration, function()
						if emitter.Parent then
							emitter.Enabled = false
						end
					end)
				end
			end)
			streaming = math.max(streaming, delay + duration)
			longest = math.max(longest, delay + duration + emitter.Lifetime.Max)
		elseif d:IsA("Beam") then
			table.insert(beams, d)
		end
	end

	-- Beams carry no timing of their own; they stand for as long as anything is streaming,
	-- then fade, so the charge's ribbons go out as the burst goes off.
	local base: { [Beam]: NumberSequence } = {}
	for _, beam in ipairs(beams) do
		base[beam] = beam.Transparency
		beam.Enabled = true
	end
	local fadeFrom = streaming
	longest = math.max(longest, fadeFrom + BEAM_FADE)

	local started = os.clock()
	local conn: RBXScriptConnection? = nil
	if follow or #beams > 0 then
		conn = RunService.Heartbeat:Connect(function()
			local t = os.clock() - started
			if follow and follow.Parent then
				anchor.CFrame = CFrame.new(follow.Position)
			end
			if #beams > 0 then
				local fade = math.clamp((t - fadeFrom) / BEAM_FADE, 0, 1)
				for _, beam in ipairs(beams) do
					if fade >= 1 then
						beam.Enabled = false
					elseif fade > 0 then
						local points = {}
						for _, p in ipairs(base[beam].Keypoints) do
							table.insert(points, NumberSequenceKeypoint.new(p.Time, p.Value + (1 - p.Value) * fade))
						end
						beam.Transparency = NumberSequence.new(points)
					end
				end
			end
		end)
	end
	task.delay(longest + 0.1, function()
		if conn then
			conn:Disconnect()
		end
		fx:Destroy()
	end)
	return longest
end

return CombatFX
