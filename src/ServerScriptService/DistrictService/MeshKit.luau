--!strict
-- The city kit: real meshes for Downtown's street props (tools/models/build_kit.py models them
-- in Blender), drawn in place of the part-built ones once they are in the place.
--
-- The kit is a model named "CityKit" in ServerStorage (or left in Workspace, where it is
-- tidied away): the Studio 3D importer's result for assets/models/CityKit.glb, or the build's
-- copy of assets/models/CityKit.rbxm. Inside it, wherever they sit, MeshParts named
-- "<Model>_<Role>" (Sedan_Body, StreetLamp_LanternGlass...). Until it is there, Place returns
-- nil and every prop builds from parts exactly as before.
--
-- MeshKitData (written by the same script) says where every piece goes and how big it is, in
-- studs, so the import's scale and position do not matter, and its layout says which way the
-- import ended up turned. A model whose pieces are missing or the wrong shape is not used at
-- all (a warning, and the part-built prop) rather than drawn wrong.
--
-- Meshes are only ever seen: no collision, no raycasts, no touch. A prop drawn by the kit keeps
-- its part-built solid pieces as invisible hulls, so it collides and stops bullets exactly as
-- it always has.
--
-- With no imported kit there is a second way, which needs nothing from anyone: Group puts the
-- part-built prop in a Model tagged "KitProp" that says where the kit's model goes and how to
-- paint it, and every client draws the kit over it itself from the meshes' own data
-- (CityMeshes, with EditableMesh), hiding the part-built pieces on its own screen only. Where a
-- client cannot, it simply sees the part-built prop.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local Kit = require(ServerScriptService.ArenaService.Kit)

local Data = require(ReplicatedStorage.MeshKitData) :: any

local MeshKit = {}

export type Paint = {
	colour: Color3,
	material: Enum.Material?,
	reflectance: number?,
	transparency: number?,
	shadow: boolean?,      -- casts a shadow (default: no)
	name: string?,         -- what the piece is called (default: its role)
}

export type Opts = {
	lift: number?,         -- studs up from the prop's origin to the model's ground
	scale: (number | Vector3)?,  -- uniform, or per axis in the prop's frame (1 by default)
	yaw: number?,          -- radians about the prop's up axis
}

type Piece = { template: BasePart, size: Vector3, offset: Vector3, turn: CFrame }

local templates: { [string]: { [string]: Piece } | false } = {}
local kitRoot: Instance? = nil

local function kit(): Instance?
	if kitRoot and kitRoot.Parent then
		return kitRoot
	end
	local found = ServerStorage:FindFirstChild("CityKit") or workspace:FindFirstChild("CityKit")
	if found and found.Parent == workspace then
		-- Imported straight into the world: put it away, nobody should see the originals.
		found.Parent = ServerStorage
	end
	kitRoot = found
	return found
end

local function sortedRoles(spec: { [string]: any }): { string }
	local roles = {}
	for role in pairs(spec) do
		table.insert(roles, role)
	end
	table.sort(roles)
	return roles
end

local function absV(v: Vector3): Vector3
	return Vector3.new(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
end

--- Read one model out of the import: its pieces, the scale it came in at, and how it is turned.
--- false when it cannot be used.
local function load(name: string): { [string]: Piece } | false
	local spec = Data[name]
	local root = kit()
	if not spec or not root then
		return false
	end
	local found: { [string]: BasePart } = {}
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("BasePart") then
			local model, role = string.match(d.Name, "^(.-)_(.+)$")
			if model == name and role and spec[role] and not found[role] then
				found[role :: string] = d
			elseif d.Parent and d.Parent.Name == name and spec[d.Name] and not found[d.Name] then
				found[d.Name] = d
			end
		end
	end
	local roles = sortedRoles(spec)
	for _, role in ipairs(roles) do
		if not found[role] then
			warn(("[MeshKit] %s: no %s_%s in the kit; the part-built %s is used"):format(name, name, role, name))
			return false
		end
	end

	-- Which way round the import is: the quarter turn that best lines its pieces' layout up
	-- with the manifest's (an importer that faces models the other way, say). The reference is
	-- the first piece, so this is free of where it was dropped and of its scale.
	local ref = roles[1]
	local bestYaw, bestScore = 0, -math.huge
	for k = 0, 3 do
		local turn = CFrame.Angles(0, k * math.pi / 2, 0)
		local score = 0
		for _, role in ipairs(roles) do
			local want = turn:VectorToWorldSpace(spec[role].offset - spec[ref].offset)
			score += want:Dot(found[role].Position - found[ref].Position)
		end
		if score > bestScore + 1e-6 then
			bestYaw, bestScore = k * math.pi / 2, score
		end
	end
	local back = CFrame.Angles(0, -bestYaw, 0)

	-- The scale it came in at, over the whole model (studs, metres, whatever the importer chose).
	local want, have = 0, 0
	for _, role in ipairs(roles) do
		want += spec[role].size.Magnitude
		have += found[role].Size.Magnitude
	end
	if have <= 0 then
		return false
	end
	local s = want / have

	local pieces: { [string]: Piece } = {}
	for _, role in ipairs(roles) do
		local part = found[role]
		-- The piece's own rotation in the import, carried into the manifest's frame.
		local turn = back * part.CFrame.Rotation
		local size = part.Size * s
		local seen = absV(turn:VectorToWorldSpace(size))
		local target = spec[role].size
		local off = seen - target
		local tolerance = math.max(0.12, target.Magnitude * 0.06)
		if math.abs(off.X) > tolerance or math.abs(off.Y) > tolerance or math.abs(off.Z) > tolerance then
			warn(("[MeshKit] %s_%s is %s, expected %s; the part-built %s is used"):format(name, role, tostring(seen),
				tostring(target), name))
			return false
		end
		pieces[role] = { template = part, size = size, offset = spec[role].offset, turn = turn }
	end
	return pieces
end

--- The prop's frame (its origin, lifted and turned as `opts` say).
local function frameOf(b: any, opts: Opts?): CFrame
	local o: Opts = opts or {}
	return b:world(CFrame.new(0, o.lift or 0, 0) * CFrame.Angles(0, o.yaw or 0, 0)) :: CFrame
end

--- Whether the kit has a usable `name`.
function MeshKit.Has(name: string): boolean
	if templates[name] == nil then
		templates[name] = load(name)
	end
	return templates[name] ~= false
end

--- Draw model `name` from the kit at the builder's origin, each role painted as `paints` says
--- (a role with no paint is left as imported). Returns the pieces by role, or nil when the
--- kit has no usable `name` -- build the part-built prop instead.
function MeshKit.Place(b: any, name: string, paints: { [string]: Paint }, opts: Opts?): { [string]: BasePart }?
	if not MeshKit.Has(name) then
		return nil
	end
	local pieces = templates[name] :: { [string]: Piece }
	local raw = opts and opts.scale
	local scale = if typeof(raw) == "Vector3" then raw elseif type(raw) == "number" then Vector3.new(raw, raw, raw)
		else Vector3.new(1, 1, 1)
	local base = frameOf(b, opts)
	local placed: { [string]: BasePart } = {}
	for role, piece in pairs(pieces) do
		local p = piece.template:Clone()
		-- Only the mesh itself: no importer leftovers (welds, attachments, a SurfaceAppearance
		-- that would hide the paint).
		p:ClearAllChildren()
		local paint = paints[role]
		p.Name = if paint and paint.name then paint.name else role
		p.Size = piece.size * scale
		p.CFrame = base * CFrame.new(piece.offset * scale) * piece.turn
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.CastShadow = paint ~= nil and paint.shadow == true
		if paint then
			p.Color = paint.colour
			p.Material = paint.material or Enum.Material.SmoothPlastic
			p.Reflectance = paint.reflectance or 0
			p.Transparency = paint.transparency or 0
		end
		p.Parent = b.parent
		placed[role] = p
	end
	return placed
end

--- For a client to draw `name` itself: a Model for the part-built prop, tagged "KitProp", with
--- where the kit's model stands (KitFrame, KitScale) and each role's paint (KitColour_<role>,
--- KitMaterial_, KitShine_, KitClear_, KitShadow_, KitName_). Build the pieces the kit replaces into it;
--- a piece in it marked KitKeep stays drawn (raised by its KitRaise, if any, to sit on the
--- kit's model).
function MeshKit.Group(b: any, name: string, paints: { [string]: Paint }, opts: Opts?): Model
	local model = Instance.new("Model")
	model.Name = name
	model:SetAttribute("KitModel", name)
	model:SetAttribute("KitFrame", frameOf(b, opts))
	model:SetAttribute("KitScale", (opts and opts.scale) or 1)    -- a number, or a Vector3 per axis
	for role, paint in pairs(paints) do
		model:SetAttribute("KitColour_" .. role, paint.colour)
		model:SetAttribute("KitMaterial_" .. role, (paint.material or Enum.Material.SmoothPlastic).Name)
		if paint.reflectance then
			model:SetAttribute("KitShine_" .. role, paint.reflectance)
		end
		if paint.transparency then
			model:SetAttribute("KitClear_" .. role, paint.transparency)
		end
		if paint.shadow then
			model:SetAttribute("KitShadow_" .. role, true)
		end
		if paint.name then
			model:SetAttribute("KitName_" .. role, paint.name)
		end
	end
	model.Parent = b.parent
	model:AddTag("KitProp")
	return model
end

--- A prop the kit can draw, built by `b`. With the kit imported, its meshes are placed now
--- (`mesh`), and `body` builds only the prop's solid pieces, as invisible hulls, and none of
--- its trim. Without it, `body` builds into a Group the clients draw the kit over: build the
--- whole part-built prop into it. What stays drawn either way (a banner, a sign) goes on `b`.
function MeshKit.Prop(b: any, name: string, paints: { [string]: Paint }, opts: Opts?): ({ [string]: BasePart }?, any)
	-- A scaling builder (Hanami's CityKit.Scaled): the kit goes on the builder underneath with
	-- the scale folded in, and the part-built prop is built back through the same scaling.
	if type(b.scale) == "number" and b.base and b.rescale then
		local k = b.scale :: number
		local o: Opts = table.clone(opts or {})
		local raw = o.scale
		o.scale = if typeof(raw) == "Vector3" then raw * k elseif type(raw) == "number" then raw * k else k
		o.lift = (o.lift or 0) * k
		local mesh, body = MeshKit.Prop(b.base, name, paints, o)
		return mesh, b.rescale(body)
	end
	local mesh = MeshKit.Place(b, name, paints, opts)
	if mesh then
		local function hullsOf(real: any): any
			local hulls = setmetatable({}, { __index = real }) :: any
			function hulls.part(_, n: string, size: Vector3, at: any, colour: Color3, material: Enum.Material?, o: any): BasePart
				local solid = table.clone(o or {})
				solid.transparency = 1
				solid.shadow = false
				local p = real:part(n, size, at, colour, material, solid)
				if o and o.collide == false and not o.query then
					p.Parent = nil          -- nothing to stand in for: the mesh is all there is
				end
				return p
			end
			function hulls.decor(_, n: string, size: Vector3, at: any, colour: Color3, material: Enum.Material?, o: any): BasePart
				local p = real:decor(n, size, at, colour, material, o)
				p.Parent = nil
				return p
			end
			function hulls.within(_, offset: CFrame): any
				return hullsOf(real:within(offset))
			end
			return hulls
		end
		return mesh, hullsOf(b)
	end
	local body = Kit.new(MeshKit.Group(b, name, paints, opts), b.frame)
	body.side = b.side
	return nil, body
end

--- Forget what was read (tests, or a kit swapped while running).
function MeshKit.Reset()
	table.clear(templates)
	kitRoot = nil
end

return MeshKit
