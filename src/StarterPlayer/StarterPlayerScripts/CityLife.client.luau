--!strict
-- The little things that make a city feel lived in, on this client only:
--
--   * Pigeons. Each "PigeonFlock" marker (Downtown puts one on the plaza, the forecourt and
--     the parks) gets its birds: the kit's pigeon from Blender where this device can make
--     meshes (MeshKitClient), little part birds where it cannot. They potter about pecking,
--     and anyone walking up -- or a shot or an impact nearby -- puts the whole flock up: wings
--     going, they climb, wheel round over the square for a while and glide back down
--     somewhere else on it.
--   * Steam rising from the manholes, and smoke curling off the chimney pots.
--
-- Cosmetic and local: every client has its own birds. Nothing far from the camera is moved,
-- and the GRAPHICS setting's PERFORMANCE turns the steam and smoke off and thins the flocks.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local RANGE = 320            -- studs from the camera past which a flock is put away
local SCARE = 9              -- someone this close puts the flock up
local SHOT_SCARE = 55        -- and a shot or impact this close
local WALK = 1.1             -- studs per second, pottering
local CITIES = { "Downtown", "Hanami" }

-- ---------------------------------------------------------------------- the birds --

local GREY = Color3.fromRGB(150, 154, 166)
local PAINT: { [string]: { colour: Color3, material: Enum.Material } } = {
	Body = { colour = GREY, material = Enum.Material.SmoothPlastic },
	Head = { colour = Color3.fromRGB(96, 116, 118), material = Enum.Material.SmoothPlastic },
	WingL = { colour = Color3.fromRGB(128, 132, 146), material = Enum.Material.SmoothPlastic },
	WingR = { colour = Color3.fromRGB(128, 132, 146), material = Enum.Material.SmoothPlastic },
	Feet = { colour = Color3.fromRGB(214, 116, 112), material = Enum.Material.SmoothPlastic },
}
-- Where the pieces sit on a bird (its own frame: feet on the origin, beak toward -Z), from the
-- kit's manifest when it is there.
local LAYOUT: { [string]: { size: Vector3, offset: Vector3 } } = {
	Body = { size = Vector3.new(0.57, 0.57, 1.38), offset = Vector3.new(0, 0.42, 0.22) },
	Head = { size = Vector3.new(0.34, 0.52, 0.45), offset = Vector3.new(0, 0.59, -0.36) },
	WingL = { size = Vector3.new(0.2, 0.15, 0.8), offset = Vector3.new(-0.27, 0.55, 0.22) },
	WingR = { size = Vector3.new(0.2, 0.15, 0.8), offset = Vector3.new(0.27, 0.55, 0.22) },
	Feet = { size = Vector3.new(0.22, 0.72, 0.68), offset = Vector3.new(0, 0.34, -0.33) },
}
local SHOULDER = { WingL = Vector3.new(-0.19, 0.58, -0.12), WingR = Vector3.new(0.19, 0.58, -0.12) }

local kitPieces: { [string]: BasePart }? = nil
local triedKit = false

local function partBird(role: string): BasePart
	local p = Instance.new("Part")
	if role == "Body" or role == "Head" then
		-- A ball that can be longer than it is wide.
		local round = Instance.new("SpecialMesh")
		round.MeshType = Enum.MeshType.Sphere
		round.Parent = p
	end
	return p
end

--- One bird's pieces, by role: the kit's meshes, or parts the same size.
local function newBird(): { [string]: BasePart }
	if not triedKit then
		triedKit = true
		local ok, MeshKitClient = pcall(function()
			return require(ReplicatedStorage:WaitForChild("MeshKitClient", 5) :: ModuleScript) :: any
		end)
		if ok and MeshKitClient then
			local data = MeshKitClient.Data.Pigeon
			local pieces = data and MeshKitClient.Pieces("Pigeon")
			if pieces then
				kitPieces = pieces
				for role, spec in pairs(data) do
					LAYOUT[role] = { size = spec.size, offset = spec.offset }
				end
			end
		end
	end
	local bird: { [string]: BasePart } = {}
	for role, spec in pairs(LAYOUT) do
		local p: BasePart = if kitPieces and kitPieces[role] then kitPieces[role]:Clone() else partBird(role)
		p.Name = "Pigeon" .. role
		p.Size = spec.size
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.CastShadow = role == "Body"
		p.Color = PAINT[role].colour
		p.Material = PAINT[role].material
		bird[role] = p
	end
	return bird
end

type Bird = {
	pieces: { [string]: BasePart },
	at: Vector3, facing: Vector3,       -- on the ground
	target: Vector3, nextStep: number,  -- where it is pottering to, and when it next picks
	flying: boolean, t: number, duration: number,
	from: Vector3, land: Vector3, circleAt: number, radius: number, height: number, turn: number,
	last: Vector3, phase: number,
}
type Flock = {
	marker: BasePart, centre: Vector3, radius: number, inner: number, birds: { Bird }, folder: Folder,
	ground: number, calmUntil: number,
}

local flocks: { [BasePart]: Flock } = {}
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

local function groundAt(p: Vector3, fallback: number): number
	local ignore: { Instance } = {}
	for _, plr in ipairs(Players:GetPlayers()) do
		if plr.Character then
			table.insert(ignore, plr.Character)
		end
	end
	for _, f in pairs(flocks) do
		table.insert(ignore, f.folder)
	end
	groundParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(p.X, fallback + 30, p.Z), Vector3.new(0, -60, 0), groundParams)
	return if hit then hit.Position.Y else fallback
end

local function spot(f: Flock): Vector3
	local a = math.random() * math.pi * 2
	local r = f.inner + (f.radius - f.inner) * math.sqrt(math.random())
	local p = f.centre + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r)
	return Vector3.new(p.X, groundAt(p, f.ground), p.Z)
end

local function addFlock(marker: Instance)
	if not marker:IsA("BasePart") or flocks[marker] then
		return
	end
	local folder = Instance.new("Folder")
	folder.Name = "Pigeons"
	local f: Flock = {
		marker = marker, centre = marker.Position, radius = tonumber(marker:GetAttribute("Radius")) or 12,
		inner = tonumber(marker:GetAttribute("Inner")) or 2, birds = {}, folder = folder,
		ground = marker.Position.Y - 0.5, calmUntil = 0,
	}
	flocks[marker] = f
	local count = tonumber(marker:GetAttribute("Count")) or 5
	for i = 1, count do
		local at = spot(f)
		local a = math.random() * math.pi * 2
		local bird: Bird = {
			pieces = newBird(), at = at, facing = Vector3.new(math.cos(a), 0, math.sin(a)), target = at,
			nextStep = os.clock() + math.random() * 3, flying = false, t = 0, duration = 0, from = at, land = at,
			circleAt = 0, radius = 0, height = 0, turn = 1, last = at, phase = i * 1.7,
		}
		for _, p in pairs(bird.pieces) do
			p.Parent = folder
		end
		table.insert(f.birds, bird)
	end
end

local function removeFlock(marker: Instance)
	local f = flocks[marker :: BasePart]
	if f then
		f.folder:Destroy()
		flocks[marker :: BasePart] = nil
	end
end

--- Put a flock up: every bird off the ground, each on its own line round the square.
local function scare(f: Flock)
	local now = os.clock()
	if now < f.calmUntil then
		return
	end
	f.calmUntil = now + 1
	for _, b in ipairs(f.birds) do
		if not b.flying then
			b.flying = true
			b.t = -math.random() * 0.35               -- not all in the same instant
			b.duration = 9 + math.random() * 6
			b.from = b.at
			b.land = spot(f)
			b.radius = 14 + math.random() * 12
			b.height = 16 + math.random() * 12
			b.turn = if math.random() < 0.5 then -1 else 1
			local out = b.at - f.centre
			b.circleAt = math.atan2(out.Z, out.X)
		end
	end
end

--- Where a flying bird is `t` seconds into its flight.
local function flight(f: Flock, b: Bird, t: number): (Vector3, boolean)
	local rise, settle = 1.6, 2.4
	local function circle(s: number): Vector3
		local a = b.circleAt + b.turn * 0.55 * s
		return f.centre + Vector3.new(math.cos(a) * b.radius, f.ground - f.centre.Y + b.height + math.sin(s * 0.9) * 1.6,
			math.sin(a) * b.radius)
	end
	if t < rise then
		-- Up off the ground, wings beating, out onto the circle.
		local k = t / rise
		local e = 1 - (1 - k) * (1 - k)
		local p = b.from:Lerp(circle(0), e)
		return p + Vector3.new(0, math.sin(k * math.pi) * 2, 0), true
	elseif t < b.duration - settle then
		return circle(t - rise), (t % 3) < 0.9         -- a few beats, then a glide
	end
	-- Down onto the new spot, wings back up to land.
	local k = math.clamp((t - (b.duration - settle)) / settle, 0, 1)
	local p0 = circle(b.duration - settle - rise)
	local mid = b.land + Vector3.new(0, 6, 0)
	local a = p0:Lerp(mid, k)
	local c = mid:Lerp(b.land, k)
	return a:Lerp(c, k), k > 0.6
end

local function pose(b: Bird, at: Vector3, facing: Vector3, flapping: boolean, flying: boolean, clock: number,
	walking: boolean)
	local flat = Vector3.new(facing.X, 0, facing.Z)
	if flat.Magnitude < 1e-3 then
		flat = Vector3.new(0, 0, -1)
	end
	local pitch = 0
	if flying then
		pitch = math.clamp(-facing.Y * 1.2, -0.6, 0.6)
	elseif not walking and math.sin(clock * 1.7 + b.phase) > 0.75 then
		pitch = 0.5                                     -- pecking
	end
	local root = CFrame.lookAt(at, at + flat) * CFrame.Angles(pitch, 0, 0)
	if walking then
		root *= CFrame.new(0, math.abs(math.sin(clock * 10 + b.phase)) * 0.06, 0)
	end
	for role, p in pairs(b.pieces) do
		local spec = LAYOUT[role]
		local shoulder = SHOULDER[role]
		if shoulder then
			local side = if role == "WingL" then -1 else 1
			local spread = if flying then side * math.rad(82) else 0
			local flap = 0
			if flying then
				flap = if flapping then math.sin(clock * 26 + b.phase) * 0.9 else 0.12
			end
			p.CFrame = root * CFrame.new(shoulder) * CFrame.Angles(0, 0, side * flap) * CFrame.Angles(0, spread, 0)
				* CFrame.new(spec.offset - shoulder)
		else
			p.CFrame = root * CFrame.new(spec.offset)
		end
	end
end

local function stepFlock(f: Flock, dt: number, clock: number, people: { Vector3 })
	for _, who in ipairs(people) do
		local flat = Vector3.new(who.X - f.centre.X, 0, who.Z - f.centre.Z).Magnitude
		if flat < f.radius + SCARE then
			for _, b in ipairs(f.birds) do
				if not b.flying and (who - b.at).Magnitude < SCARE then
					scare(f)
					break
				end
			end
		end
	end
	for _, b in ipairs(f.birds) do
		if b.flying then
			b.t += dt
			if b.t >= b.duration then
				b.flying = false
				b.at = b.land
				b.target = b.land
				b.nextStep = clock + 1 + math.random() * 2
				pose(b, b.at, b.facing, false, false, clock, false)
			elseif b.t > 0 then
				local at, flapping = flight(f, b, b.t)
				local v = at - b.last
				if v.Magnitude > 1e-3 then
					b.facing = v.Unit
				end
				b.last = at
				pose(b, at, b.facing, flapping, true, clock, false)
			end
		else
			b.last = b.at
			if clock > b.nextStep then
				b.nextStep = clock + 2 + math.random() * 3
				local p = b.at + Vector3.new(math.random() * 6 - 3, 0, math.random() * 6 - 3)
				local off = Vector3.new(p.X - f.centre.X, 0, p.Z - f.centre.Z)
				if off.Magnitude < f.inner or off.Magnitude > f.radius then
					p = spot(f)
				end
				b.target = Vector3.new(p.X, b.at.Y, p.Z)
			end
			local to = b.target - b.at
			local walking = to.Magnitude > 0.15
			if walking then
				b.facing = to.Unit
				b.at += to.Unit * math.min(to.Magnitude, WALK * dt)
			end
			pose(b, b.at, b.facing, false, false, clock, walking)
		end
	end
end

-- Gunfire anywhere near a flock puts it up.
task.spawn(function()
	local ok, CombatFX = pcall(function()
		return require(ReplicatedStorage:WaitForChild("CombatFX")) :: any
	end)
	if ok and CombatFX and CombatFX.Gunfire then
		CombatFX.Gunfire.Event:Connect(function(at: Vector3)
			for _, f in pairs(flocks) do
				if (f.centre - at).Magnitude < SHOT_SCARE + f.radius then
					scare(f)
				end
			end
		end)
	end
end)

-- ----------------------------------------------------------------- steam and smoke --

local level = 3
local plumes: { [BasePart]: ParticleEmitter } = {}
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

local function plume(part: BasePart, steam: boolean)
	if plumes[part] then
		return
	end
	local top = part.Position + Vector3.new(0, part.Size.Magnitude * 0.15, 0)
	local attachment = Instance.new("Attachment")
	attachment.Name = if steam then "Steam" else "Smoke"
	attachment.CFrame = part.CFrame:ToObjectSpace(CFrame.new(top))
	attachment.Parent = part
	local e = Instance.new("ParticleEmitter")
	e.Name = attachment.Name
	e.Texture = SMOKE
	e.EmissionDirection = Enum.NormalId.Top
	e.RotSpeed = NumberRange.new(-20, 20)
	e.Rotation = NumberRange.new(0, 360)
	e.LightInfluence = 1
	if steam then
		e.Color = ColorSequence.new(Color3.fromRGB(236, 238, 242))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 5.5) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(2.5, 4)
		e.Speed = NumberRange.new(2.5, 4.5)
		e.SpreadAngle = Vector2.new(14, 14)
		e.Acceleration = Vector3.new(0.6, 0.4, 0.3)
		e.Rate = 4
	else
		e.Color = ColorSequence.new(Color3.fromRGB(176, 176, 182))
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.8), NumberSequenceKeypoint.new(1, 5) })
		e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.78), NumberSequenceKeypoint.new(1, 1) })
		e.Lifetime = NumberRange.new(4, 6.5)
		e.Speed = NumberRange.new(2, 3)
		e.SpreadAngle = Vector2.new(8, 8)
		e.Acceleration = Vector3.new(1.1, 0.3, 0.5)
		e.Rate = 1.2
	end
	e.Enabled = level >= 2
	e.Parent = attachment
	plumes[part] = e
	part.Destroying:Connect(function()
		plumes[part] = nil
	end)
end

local function consider(d: Instance)
	if not d:IsA("BasePart") then
		return
	end
	if d.Name == "Manhole" then
		plume(d, true)
	elseif d.Name == "ChimneyCap" and d.Size.Magnitude < 6 then
		plume(d, false)
	end
end

local function watchCity(city: Instance)
	for _, d in ipairs(city:GetDescendants()) do
		consider(d)
	end
	city.DescendantAdded:Connect(consider)
end
for _, name in ipairs(CITIES) do
	local city = workspace:FindFirstChild(name)
	if city then
		watchCity(city)
	end
end
workspace.ChildAdded:Connect(function(child)
	if table.find(CITIES, child.Name) then
		watchCity(child)
	end
end)

local function readLevel()
	local raw = tonumber(player:GetAttribute("GraphicsQuality"))
	level = if raw then math.clamp(math.floor(raw + 0.5), 1, 3) else 3
	for part, e in pairs(plumes) do
		if part.Parent then
			e.Enabled = level >= 2
		end
	end
end
player:GetAttributeChangedSignal("GraphicsQuality"):Connect(readLevel)
readLevel()

-- ------------------------------------------------------------------------- the loop --

RunService.RenderStepped:Connect(function(dt: number)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local eye = camera.CFrame.Position
	local clock = os.clock()
	local people: { Vector3 }? = nil
	for marker, f in pairs(flocks) do
		if not marker.Parent then
			removeFlock(marker)
		elseif (f.centre - eye).Magnitude > RANGE then
			f.folder.Parent = nil
		else
			if not f.folder.Parent then
				f.folder.Parent = workspace
			end
			if not people then
				local list = {}
				for _, plr in ipairs(Players:GetPlayers()) do
					local root = plr.Character and plr.Character:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						table.insert(list, root.Position - Vector3.new(0, 2.5, 0))
					end
				end
				people = list
			end
			-- PERFORMANCE: fewer birds about.
			local shown = if level == 1 then math.ceil(#f.birds / 2) else #f.birds
			for i, b in ipairs(f.birds) do
				for _, p in pairs(b.pieces) do
					p.LocalTransparencyModifier = if i > shown then 1 else 0
				end
			end
			stepFlock(f, math.min(dt, 0.1), clock, people :: { Vector3 })
		end
	end
end)

CollectionService:GetInstanceAddedSignal("PigeonFlock"):Connect(function(marker)
	task.spawn(addFlock, marker)
end)
CollectionService:GetInstanceRemovedSignal("PigeonFlock"):Connect(removeFlock)
for _, marker in ipairs(CollectionService:GetTagged("PigeonFlock")) do
	task.spawn(addFlock, marker)
end
