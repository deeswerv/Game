--!strict
-- The toolkit every duel map is built with.
--
-- A builder is a frame (the map's centre, possibly turned half round) plus a parent. Every
-- placement is given in the frame's own coordinates, so a map is written once, for one half,
-- and `Kit.Both` builds it a second time through a frame rotated 180 degrees about the
-- centre. That is what keeps every map fair: the twin of a crate is not typed in by hand, so
-- it cannot drift out of place when the first one is moved.
--
-- Coordinates: +Y up, -Z toward spawn A, +Z toward spawn B. Y = 0 is the top of the floor.

local Kit = {}

export type Opts = {
	shape: string?,          -- "Block" (default), "Cylinder", "Ball", "Wedge", "CornerWedge"
	collide: boolean?,       -- default true
	query: boolean?,         -- default = collide
	shadow: boolean?,        -- default = collide
	transparency: number?,
	reflectance: number?,
}

export type Builder = {
	parent: Instance,
	frame: CFrame,
	side: number,            -- 1 for the half as written, 2 for its rotated twin
	part: (self: Builder, name: string, size: Vector3, at: CFrame | Vector3, colour: Color3,
		material: Enum.Material?, opts: Opts?) -> BasePart,
	decor: (self: Builder, name: string, size: Vector3, at: CFrame | Vector3, colour: Color3,
		material: Enum.Material?, opts: Opts?) -> BasePart,
	neon: (self: Builder, name: string, size: Vector3, at: CFrame | Vector3, colour: Color3,
		transparency: number?) -> BasePart,
	light: (self: Builder, kind: string, at: CFrame | Vector3, colour: Color3, brightness: number,
		range: number, extra: { [string]: any }?) -> Instance,
	sign: (self: Builder, text: string, at: CFrame, width: number, height: number, colour: Color3,
		opts: { [string]: any }?) -> BasePart,
	world: (self: Builder, at: CFrame | Vector3) -> CFrame,
	within: (self: Builder, offset: CFrame) -> Builder,
	folder: (self: Builder, name: string) -> Builder,
}

local Builder = {}
Builder.__index = Builder

local function asCFrame(at: CFrame | Vector3): CFrame
	if typeof(at) == "Vector3" then
		return CFrame.new(at)
	end
	return at :: CFrame
end

function Kit.new(parent: Instance, frame: CFrame): Builder
	local self = setmetatable({
		parent = parent,
		frame = frame,
		side = 1,
	}, Builder)
	return (self :: any) :: Builder
end

--- The same builder, turned half a turn about the centre: side B.
function Kit.Turned(b: Builder): Builder
	local t = Kit.new(b.parent, b.frame * CFrame.Angles(0, math.pi, 0))
	t.side = b.side == 1 and 2 or 1
	return t
end

--- Build `fn` once as written and once rotated 180 degrees. `fn` receives the builder and the
--- side (1 or 2), so paint that marks each half can follow it.
function Kit.Both(b: Builder, fn: (Builder, number) -> ())
	fn(b, 1)
	fn(Kit.Turned(b), 2)
end

--- Build `fn` at each of the four quadrant mirrors (for dressing that is symmetric both
--- ways, like fence posts). Gameplay pieces use Both; this is for decoration only.
function Kit.Quad(b: Builder, fn: (Builder, number, number) -> ())
	for _, sx in ipairs({ 1, -1 }) do
		for _, sz in ipairs({ 1, -1 }) do
			fn(b, sx, sz)
		end
	end
end

function Builder.world(self: Builder, at: CFrame | Vector3): CFrame
	return self.frame * asCFrame(at)
end

--- A builder whose origin is `offset` inside this one: build a prop in its own local space
--- and place it anywhere, turned any way.
function Builder.within(self: Builder, offset: CFrame): Builder
	local b = Kit.new(self.parent, self.frame * offset)
	b.side = self.side
	return b
end

function Builder.folder(self: Builder, name: string): Builder
	local f = self.parent:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = self.parent
	end
	local b = Kit.new(f :: Instance, self.frame)
	b.side = self.side
	return b
end

function Builder.part(self: Builder, name: string, size: Vector3, at: CFrame | Vector3, colour: Color3,
	material: Enum.Material?, opts: Opts?): BasePart
	local o: Opts = opts or {}
	local p: BasePart
	local shape = o.shape or "Block"
	if shape == "Wedge" then
		p = Instance.new("WedgePart")
	elseif shape == "CornerWedge" then
		p = Instance.new("CornerWedgePart")
	else
		local block = Instance.new("Part")
		if shape == "Cylinder" then
			block.Shape = Enum.PartType.Cylinder
		elseif shape == "Ball" then
			block.Shape = Enum.PartType.Ball
		end
		p = block
	end
	p.Name = name
	p.Size = size
	p.CFrame = self:world(at)
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	local collide = o.collide ~= false
	p.CanCollide = collide
	p.CanQuery = if o.query ~= nil then o.query else collide
	p.CanTouch = collide
	p.CastShadow = if o.shadow ~= nil then o.shadow else collide
	p.Transparency = o.transparency or 0
	p.Reflectance = o.reflectance or 0
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = self.parent
	return p
end

--- Seen, never touched: no collision, no raycasts, no shadow. Trim, windows, the skyline.
function Builder.decor(self: Builder, name: string, size: Vector3, at: CFrame | Vector3, colour: Color3,
	material: Enum.Material?, opts: Opts?): BasePart
	local o: Opts = table.clone(opts or {})
	o.collide = false
	if o.query == nil then
		o.query = false
	end
	if o.shadow == nil then
		o.shadow = false
	end
	return self:part(name, size, at, colour, material, o)
end

function Builder.neon(self: Builder, name: string, size: Vector3, at: CFrame | Vector3, colour: Color3,
	transparency: number?): BasePart
	return self:decor(name, size, at, colour, Enum.Material.Neon, { transparency = transparency })
end

--- A light on an invisible anchor. `kind` is "Point" or "Spot" (a spot points down its
--- anchor's Front face, so aim the CFrame).
function Builder.light(self: Builder, kind: string, at: CFrame | Vector3, colour: Color3, brightness: number,
	range: number, extra: { [string]: any }?): Instance
	local anchor = self:decor("Light", Vector3.new(0.2, 0.2, 0.2), at, colour, nil, { transparency = 1 })
	local light: any
	if kind == "Spot" then
		light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Angle = 70
	else
		light = Instance.new("PointLight")
	end
	light.Color = colour
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	if extra then
		for key, value in pairs(extra) do
			light[key] = value
		end
	end
	light.Parent = anchor
	return light
end

--- Lettering on an invisible board whose Front faces the viewer: `at` looks the way the text
--- is read FROM. opts: font, glow (UIStroke colour or false), brightness, ppS.
function Builder.sign(self: Builder, text: string, at: CFrame, width: number, height: number, colour: Color3,
	opts: { [string]: any }?): BasePart
	local o = opts or {}
	local board = self:decor("Sign", Vector3.new(width, height, 0.1), at, colour, nil, { transparency = 1 })
	board.Name = "Sign_" .. text

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = o.ppS or 14
	gui.LightInfluence = if o.lit then 1 else 0
	gui.Brightness = o.brightness or 2.4
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Text = text
	label.TextScaled = true
	label.Font = o.font or Enum.Font.FredokaOne
	label.TextColor3 = o.textColour or colour:Lerp(Color3.new(1, 1, 1), 0.35)
	label.Parent = gui

	if o.glow ~= false then
		local glow = Instance.new("UIStroke")
		glow.Color = o.glow or colour
		glow.Thickness = o.stroke or 6
		glow.Transparency = 0.25
		glow.Parent = label
	end
	return board
end

-- ------------------------------------------------------------------ shell --

--- The part every map shares: invisible walls on all four sides and a lid, so a map is a
--- closed box whatever its dressing looks like. Walls stop players only (CanQuery off) --
--- never a bullet, never the camera.
function Kit.Bounds(b: Builder, halfWidth: number, halfLength: number, height: number)
	local f = b:folder("Bounds")
	local function wall(name: string, size: Vector3, at: Vector3)
		f:part(name, size, at, Color3.new(0, 0, 0), nil,
			{ transparency = 1, query = false, shadow = false })
	end
	for _, s in ipairs({ -1, 1 }) do
		wall("BoundX", Vector3.new(2, height + 10, halfLength * 2 + 4), Vector3.new(s * (halfWidth + 1), height / 2, 0))
		wall("BoundZ", Vector3.new(halfWidth * 2 + 4, height + 10, 2), Vector3.new(0, height / 2, s * (halfLength + 1)))
	end
	wall("Lid", Vector3.new(halfWidth * 2 + 4, 2, halfLength * 2 + 4), Vector3.new(0, height + 1, 0))
end

--- A spawn marker: a soft glowing ring on the floor where a duellist starts.
function Kit.SpawnPad(b: Builder, at: Vector3, colour: Color3)
	b:decor("SpawnRing", Vector3.new(0.12, 9, 9), CFrame.new(at + Vector3.new(0, 0.07, 0))
		* CFrame.Angles(0, 0, math.rad(90)), colour, Enum.Material.Neon, { shape = "Cylinder", transparency = 0.35 })
	b:decor("SpawnDisc", Vector3.new(0.14, 7.6, 7.6), CFrame.new(at + Vector3.new(0, 0.08, 0))
		* CFrame.Angles(0, 0, math.rad(90)), colour:Lerp(Color3.new(0, 0, 0), 0.55), Enum.Material.SmoothPlastic,
		{ shape = "Cylinder", transparency = 0.2 })
end

--- A run of evenly spaced parts between two points (fence rails, string-light bulbs, ribs).
function Kit.Run(from: Vector3, to: Vector3, count: number, fn: (Vector3, number) -> ())
	for i = 0, count - 1 do
		local t = if count == 1 then 0.5 else i / (count - 1)
		fn(from:Lerp(to, t), i + 1)
	end
end

--- CFrame.lookAt, built from explicit axes so it is well defined looking straight up or
--- down (a hanging cable) and exact along the axes. Same result as the engine's lookAt.
function Kit.Look(from: Vector3, to: Vector3): CFrame
	local look = to - from
	if look.Magnitude < 1e-6 then
		return CFrame.new(from)
	end
	look = look.Unit
	local up = if math.abs(look.Y) > 0.99 then Vector3.new(0, 0, 1) else Vector3.new(0, 1, 0)
	local right = look:Cross(up).Unit
	return CFrame.fromMatrix(from, right, right:Cross(look).Unit, -look)
end

--- A CFrame at the middle of `from`..`to`, looking along it: for beams, cables and rails
--- between two points. Returns the CFrame and the length.
function Kit.Span(from: Vector3, to: Vector3): (CFrame, number)
	local mid = (from + to) / 2
	local length = (to - from).Magnitude
	if length < 1e-3 then
		return CFrame.new(mid), 0
	end
	return Kit.Look(mid, to), length
end

--- Rotation about Y in degrees, as a CFrame at `at`.
function Kit.Yaw(at: Vector3, degrees: number): CFrame
	return CFrame.new(at) * CFrame.Angles(0, math.rad(degrees), 0)
end

return Kit
