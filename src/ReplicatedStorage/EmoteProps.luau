--!strict
-- The props some emotes need: the toilet under Toilet Break, the couch under Couch Nap, the
-- board under Surf. The emote pack came with the poses only, so these are built here from
-- plain parts, in the same chunky low-poly style as the rest of the world.
--
-- Built on each client, never replicated: EmoteAnimator makes one when it starts posing a
-- character, moves it with that character every frame, and throws it away when the emote
-- ends. Anchored, no collision, no queries -- a prop is scenery, it can never block a shot
-- or be stood on.
--
-- Everything is laid out in the emote's own frame: origin on the floor directly under the
-- character, -Z the way the character faces. Where the body sits in each emote was
-- measured from the converted poses on the game's own rig (tools/emotes/render.luau and the
-- numbers in the comments below), so the seat is under the hips and the handle is in the
-- hands rather than roughly nearby.

local EmoteProps = {}

-- How far the root sits above the floor on the locked rig at rest. The poses are relative to
-- the root, so props are too: the rig's floor is this far under the root.
EmoteProps.ROOT_HEIGHT = 3.0

export type Prop = {
	kind: string,
	model: Model,
	update: ((prop: Prop, character: Model, floor: CFrame, elapsed: number) -> ())?,
	state: { [string]: any },
}

-- ------------------------------------------------------------------ parts --

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3,
	material: Enum.Material?, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then
		p.Shape = shape
	end
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Where each part of a group sits in the frame it was built in, so the group can be put
-- anywhere by setting CFrames directly -- no Model pivots to keep track of.
type Layout = { [BasePart]: CFrame }

local function layoutOf(container: Instance): Layout
	local layout: Layout = {}
	for _, d in ipairs(container:GetDescendants()) do
		if d:IsA("BasePart") then
			layout[d] = d.CFrame
		end
	end
	return layout
end

local function place(layout: Layout, base: CFrame)
	for p, offset in pairs(layout) do
		p.CFrame = base * offset
	end
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

-- A cylinder standing up (a Part cylinder's axis is X).
local function upright(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.pi / 2)
end

-- A cylinder lying along Z.
local function alongZ(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, math.pi / 2, 0)
end

-- A slab whose own Y axis is `up` (unit), centred at `centre`, facing along -Z-ish.
local function tilted(centre: Vector3, up: Vector3): CFrame
	local right = Vector3.xAxis
	local look = right:Cross(up).Unit
	return CFrame.fromMatrix(centre, right, up, -look)
end

local WHITE = Color3.fromRGB(240, 240, 236)
local CREAM = Color3.fromRGB(232, 222, 200)
local IRON = Color3.fromRGB(58, 60, 66)
local WOOD = Color3.fromRGB(128, 86, 54)
local DARK_WOOD = Color3.fromRGB(84, 56, 38)

-- ----------------------------------------------------------------- toilet --
-- Seated on it: hips at 1.57 above the floor, 0.55 behind the root; feet flat in front.

local function toilet(m: Model)
	part(m, "Base", Vector3.new(0.95, 1.05, 1.2), at(0, 0.53, 0.75), WHITE)
	part(m, "Bowl", Vector3.new(1.5, 0.4, 1.9), at(0, 1.22, 0.5), WHITE)
	part(m, "Seat", Vector3.new(1.6, 0.12, 1.95), at(0, 1.48, 0.5), CREAM)
	part(m, "Tank", Vector3.new(1.7, 1.5, 0.62), at(0, 2.0, 1.72), WHITE)
	part(m, "Lid", Vector3.new(1.85, 0.14, 0.76), at(0, 2.8, 1.72), CREAM)
	part(m, "Handle", Vector3.new(0.34, 0.1, 0.1), at(0.62, 2.55, 1.38), Color3.fromRGB(190, 196, 204), Enum.Material.Metal)
	-- A roll on a stand beside it, and a mat in front.
	part(m, "Stand", Vector3.new(1.3, 0.12, 0.12), upright(1.45, 0.65, 0.6), IRON)
	part(m, "Roll", Vector3.new(0.5, 0.55, 0.55), CFrame.new(1.45, 1.35, 0.6) * CFrame.Angles(0, math.pi / 2, 0), WHITE)
	part(m, "Mat", Vector3.new(2.2, 0.06, 1.5), at(0, 0.03, -0.55), Color3.fromRGB(96, 170, 196))
end

-- ------------------------------------------------------------------ couch --
-- Slumped back: hips on a seat at 1.5, back against a rest tipped 15 degrees, the head
-- lolling over its top edge, feet crossed on an ottoman, left arm hanging off the open end
-- and the right one along the top of the back.

local COUCH = Color3.fromRGB(214, 112, 70)
local CUSHION = Color3.fromRGB(236, 146, 96)

local function couch(m: Model)
	local backUp = Vector3.new(0, 0.97, 0.25)
	part(m, "Frame", Vector3.new(4.5, 0.75, 2.1), at(0.75, 0.72, 0.1), COUCH)
	part(m, "Cushion", Vector3.new(4.4, 0.42, 1.75), at(0.75, 1.3, -0.02), CUSHION)
	part(m, "Back", Vector3.new(4.5, 1.6, 0.5), tilted(Vector3.new(0.75, 2.12, 1.1), backUp), COUCH)
	part(m, "Arm", Vector3.new(0.6, 1.5, 2.3), at(3.3, 1.1, 0.25), COUCH)
	part(m, "ArmTop", Vector3.new(0.72, 0.2, 2.4), at(3.3, 1.9, 0.25), CUSHION)
	for _, x in ipairs({ -1.35, 2.85 }) do
		for _, z in ipairs({ -0.75, 0.95 }) do
			part(m, "Foot", Vector3.new(0.25, 0.34, 0.25), at(x, 0.17, z), DARK_WOOD, Enum.Material.Wood)
		end
	end
	part(m, "Ottoman", Vector3.new(2.3, 0.8, 1.4), at(0.5, 0.52, -1.95), COUCH)
	part(m, "OttomanTop", Vector3.new(2.2, 0.2, 1.3), at(0.5, 0.99, -1.95), CUSHION)
	part(m, "Rug", Vector3.new(6.4, 0.05, 5.2), at(0.75, 0.025, -0.7), Color3.fromRGB(226, 208, 170))
	part(m, "Pillow", Vector3.new(0.9, 0.75, 0.3), CFrame.new(2.55, 1.85, 0.75) * CFrame.Angles(math.rad(-12), math.rad(-20), 0),
		Color3.fromRGB(252, 214, 120))
end

-- --------------------------------------------------------------- lounger --
-- Leaning back in it: hips at 1.3, back against a rest tipped 27 degrees, legs stretched
-- down onto the foot of it at 0.55. A parasol over it.

local STRIPE_A = Color3.fromRGB(64, 176, 196)
local STRIPE_B = Color3.fromRGB(246, 244, 236)

local function lounger(m: Model)
	local backUp = Vector3.new(0, 0.89, 0.46)
	-- The back rest, just behind where the shoulders lie.
	part(m, "Back", Vector3.new(2.1, 2.7, 0.18), tilted(Vector3.new(0, 2.28, 1.25), backUp), STRIPE_A)
	part(m, "BackStripe", Vector3.new(0.7, 2.7, 0.2), tilted(Vector3.new(0, 2.28, 1.25), backUp), STRIPE_B)
	-- The seat slopes down from the hips to where the knees begin, then the leg rest is flat.
	local seatUp = Vector3.new(0, 0.92, -0.39).Unit
	part(m, "Seat", Vector3.new(2.1, 0.18, 1.6), tilted(Vector3.new(0, 0.86, 0.02), seatUp), STRIPE_A)
	part(m, "Legs", Vector3.new(2.1, 0.18, 1.9), at(0, 0.46, -1.65), STRIPE_A)
	part(m, "LegsStripe", Vector3.new(0.7, 0.2, 1.9), at(0, 0.47, -1.65), STRIPE_B)
	for _, x in ipairs({ -1.0, 1.0 }) do
		part(m, "Rail", Vector3.new(0.12, 0.12, 4.4), at(x, 0.3, -0.5), WHITE)
		for _, z in ipairs({ -2.5, -0.6, 1.4 }) do
			part(m, "Post", Vector3.new(0.12, 0.3, 0.12), at(x, 0.15, z), WHITE)
		end
	end
	-- Parasol, planted beside it.
	part(m, "Pole", Vector3.new(6.2, 0.16, 0.16), upright(1.9, 3.1, 0.9), WHITE)
	part(m, "Canopy", Vector3.new(0.35, 6.4, 6.4), CFrame.new(1.9, 6.1, 0.9) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(238, 92, 80), nil, Enum.PartType.Cylinder)
	part(m, "CanopyTop", Vector3.new(0.4, 3.6, 3.6), CFrame.new(1.9, 6.4, 0.9) * CFrame.Angles(0, 0, math.pi / 2),
		STRIPE_B, nil, Enum.PartType.Cylinder)
	part(m, "Finial", Vector3.new(0.4, 0.4, 0.4), at(1.9, 6.7, 0.9), Color3.fromRGB(238, 92, 80), nil, Enum.PartType.Ball)
	part(m, "Towel", Vector3.new(2.4, 0.04, 5.2), at(-0.1, 0.02, -0.4), Color3.fromRGB(252, 200, 90))
	part(m, "Glass", Vector3.new(0.45, 0.3, 0.3), upright(1.45, 0.25, -1.6), Color3.fromRGB(250, 140, 60), Enum.Material.Glass)
end

-- ------------------------------------------------------------------- cart --
-- Pushing it: both hands on the bar at 2.84, 1.3 in front.

local CART = Color3.fromRGB(246, 232, 214)
local CART_TRIM = Color3.fromRGB(236, 110, 150)

local function cart(m: Model)
	part(m, "Bar", Vector3.new(2.4, 0.2, 0.2), at(0, 2.84, -1.3), IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
	for _, x in ipairs({ -1.15, 1.15 }) do
		part(m, "Arm", Vector3.new(0.16, 0.16, 1.0), CFrame.new(x, 2.7, -1.75) * CFrame.Angles(math.rad(16), 0, 0), IRON, Enum.Material.Metal)
	end
	part(m, "Body", Vector3.new(3.1, 1.6, 2.5), at(0, 1.95, -3.35), CART)
	part(m, "Stripe", Vector3.new(3.14, 0.35, 2.54), at(0, 1.55, -3.35), CART_TRIM)
	part(m, "Lid", Vector3.new(3.2, 0.2, 2.6), at(0, 2.85, -3.35), Color3.fromRGB(200, 208, 214), Enum.Material.Metal)
	for _, x in ipairs({ -1.7, 1.7 }) do
		part(m, "Wheel", Vector3.new(0.3, 1.7, 1.7), at(x, 0.85, -3.35), IRON, nil, Enum.PartType.Cylinder)
		part(m, "Hub", Vector3.new(0.34, 0.5, 0.5), at(x, 0.85, -3.35), CART_TRIM, nil, Enum.PartType.Cylinder)
	end
	part(m, "Caster", Vector3.new(0.12, 1.0, 0.12), at(0, 0.65, -4.4), IRON)
	part(m, "Toe", Vector3.new(0.3, 0.5, 0.5), at(0, 0.25, -4.4), IRON, nil, Enum.PartType.Cylinder)
	-- Three scoops on cones along the lid.
	local flavours = { Color3.fromRGB(252, 176, 196), Color3.fromRGB(170, 232, 196), Color3.fromRGB(255, 244, 214) }
	for i, colour in ipairs(flavours) do
		local x = (i - 2) * 0.85
		part(m, "Cone", Vector3.new(0.4, 0.7, 0.4), at(x, 3.3, -3.0), Color3.fromRGB(214, 164, 96))
		part(m, "Scoop", Vector3.new(0.6, 0.6, 0.6), at(x, 3.8, -3.0), colour, nil, Enum.PartType.Ball)
	end
	-- Umbrella.
	part(m, "Pole", Vector3.new(3.4, 0.14, 0.14), upright(0, 4.6, -3.9), WHITE)
	part(m, "Canopy", Vector3.new(0.3, 5.0, 5.0), CFrame.new(0, 6.3, -3.9) * CFrame.Angles(0, 0, math.pi / 2),
		CART_TRIM, nil, Enum.PartType.Cylinder)
	part(m, "CanopyTop", Vector3.new(0.35, 2.8, 2.8), CFrame.new(0, 6.55, -3.9) * CFrame.Angles(0, 0, math.pi / 2),
		CART, nil, Enum.PartType.Cylinder)
end

-- -------------------------------------------------------------- surfboard --
-- The rider is up on a wave: front foot 2.9 up, back foot 1.4, the line between them tipped
-- 27 degrees. The board follows the feet every frame; the wave stays where it is.

local BOARD = Color3.fromRGB(252, 206, 70)
local WATER = Color3.fromRGB(56, 150, 206)
local FOAM = Color3.fromRGB(236, 248, 252)

local SURF_FRONT = Vector3.new(0.49, 2.90, -0.50)
local SURF_BACK = Vector3.new(0.21, 1.37, 2.45)

local function soleOf(foot: BasePart?): Vector3?
	if not foot then
		return nil
	end
	return (foot.CFrame * CFrame.new(0, -foot.Size.Y / 2, 0)).Position
end

local function boardFrame(front: Vector3, back: Vector3): CFrame?
	local along = front - back
	if along.Magnitude < 0.2 then
		return nil
	end
	local forward = along.Unit
	local right = forward:Cross(Vector3.yAxis)
	if right.Magnitude < 0.05 then
		return nil
	end
	right = right.Unit
	local up = right:Cross(forward)
	return CFrame.fromMatrix((front + back) / 2, right, up)
end

local function surfboard(m: Model, prop: Prop)
	local frame = boardFrame(SURF_FRONT, SURF_BACK) :: CFrame
	local up = frame.UpVector
	-- The wave: a slab of water under the board, running down to the floor behind.
	local wave = frame * CFrame.new(0, -0.75, 1.2)
	part(m, "Wave", Vector3.new(7, 1.0, 10), wave, WATER)
	part(m, "Crest", Vector3.new(7.2, 0.6, 1.2), frame * CFrame.new(0, -0.3, -3.6), FOAM)
	part(m, "Lip", Vector3.new(7.2, 0.35, 0.9), frame * CFrame.new(0, 0.05, -4.2), FOAM)
	part(m, "Pool", Vector3.new(0.15, 11, 11), CFrame.new(0, 0.07, 3.5) * CFrame.Angles(0, 0, math.pi / 2), WATER, nil,
		Enum.PartType.Cylinder)
	part(m, "Spray", Vector3.new(7.4, 0.3, 1.0), CFrame.new(0, 0.2, 7.6), FOAM)
	local board = part(m, "Board", Vector3.new(1.5, 0.2, 5.6), frame * CFrame.new(0, -0.1, 0), BOARD)
	part(board, "BoardStripe", Vector3.new(0.3, 0.21, 5.62), frame * CFrame.new(0, -0.1, 0), Color3.fromRGB(236, 84, 70))
	prop.state.board = board
	prop.state.up = up
end

local function surfUpdate(prop: Prop, character: Model, _floor: CFrame, _elapsed: number)
	local board = prop.state.board :: BasePart
	local front = soleOf(character:FindFirstChild("LeftFoot") :: BasePart?)
	local back = soleOf(character:FindFirstChild("RightFoot") :: BasePart?)
	local frame = front and back and boardFrame(front, back)
	if frame then
		board.CFrame = frame * CFrame.new(0, -0.1, 0)
		local stripe = board:FindFirstChild("BoardStripe") :: BasePart?
		if stripe then
			stripe.CFrame = board.CFrame
		end
	end
end

-- ----------------------------------------------------------------- cannon --
-- Lying along the top of the barrel, arms out towards the muzzle. It fires a coconut once
-- every loop, and kicks back as it does.

local CANNON_PERIOD = 3.0
local CANNON_FIRE_AT = 1.45

local function cannon(m: Model, prop: Prop)
	local barrel = Instance.new("Model")
	barrel.Name = "Barrel"
	barrel.Parent = m
	part(barrel, "Tube", Vector3.new(6.2, 1.7, 1.7), alongZ(0, 1.3, -0.1), IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
	part(barrel, "Muzzle", Vector3.new(0.45, 2.0, 2.0), alongZ(0, 1.3, -3.1), Color3.fromRGB(44, 46, 52), Enum.Material.Metal,
		Enum.PartType.Cylinder)
	part(barrel, "Bore", Vector3.new(0.5, 1.1, 1.1), alongZ(0, 1.3, -3.15), Color3.fromRGB(14, 14, 16), nil, Enum.PartType.Cylinder)
	part(barrel, "Band", Vector3.new(0.3, 1.9, 1.9), alongZ(0, 1.3, 0.9), Color3.fromRGB(196, 160, 72), Enum.Material.Metal,
		Enum.PartType.Cylinder)
	part(barrel, "Breech", Vector3.new(1.3, 1.3, 1.3), at(0, 1.3, 3.0), IRON, Enum.Material.Metal, Enum.PartType.Ball)
	part(m, "Carriage", Vector3.new(1.9, 0.7, 4.2), at(0, 0.6, 0.6), WOOD, Enum.Material.Wood)
	for _, x in ipairs({ -1.2, 1.2 }) do
		part(m, "Wheel", Vector3.new(0.35, 1.9, 1.9), at(x, 0.95, 1.0), DARK_WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
		part(m, "Hub", Vector3.new(0.4, 0.5, 0.5), at(x, 0.95, 1.0), IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
		part(m, "FrontWheel", Vector3.new(0.3, 1.2, 1.2), at(x * 0.9, 0.6, -1.4), DARK_WOOD, Enum.Material.Wood, Enum.PartType.Cylinder)
	end
	-- A little pile of ammunition beside it.
	for i, offset in ipairs({ Vector3.new(1.7, 0.35, 2.4), Vector3.new(2.3, 0.35, 2.2), Vector3.new(2.0, 0.85, 2.3) }) do
		part(m, "Pile" .. i, Vector3.new(0.75, 0.75, 0.75), CFrame.new(offset), Color3.fromRGB(116, 80, 48), Enum.Material.Wood,
			Enum.PartType.Ball)
	end
	prop.state.barrel = layoutOf(barrel)
	prop.state.lastLoop = -1
	prop.state.firedAt = -math.huge
	prop.state.shots = {}
end

local function cannonUpdate(prop: Prop, _character: Model, floor: CFrame, elapsed: number)
	local state = prop.state
	local loop = elapsed // CANNON_PERIOD
	local inLoop = elapsed % CANNON_PERIOD
	if loop ~= state.lastLoop and inLoop >= CANNON_FIRE_AT then
		state.lastLoop = loop
		state.firedAt = elapsed
		-- The coconut, and a puff of smoke at the muzzle.
		local muzzle = floor * CFrame.new(0, 1.3, -3.5)
		local nut = part(prop.model, "Coconut", Vector3.new(0.8, 0.8, 0.8), muzzle, Color3.fromRGB(110, 74, 44), Enum.Material.Wood,
			Enum.PartType.Ball)
		table.insert(state.shots, { part = nut, from = muzzle, at = elapsed, kind = "nut" })
		for i = 1, 3 do
			local puff = part(prop.model, "Smoke", Vector3.new(1, 1, 1), muzzle * CFrame.new((i - 2) * 0.5, 0.2 * i, -0.3 * i),
				Color3.fromRGB(236, 236, 236), nil, Enum.PartType.Ball)
			puff.CastShadow = false
			table.insert(state.shots, { part = puff, from = puff.CFrame, at = elapsed, kind = "smoke" })
		end
	end
	-- Recoil: a sharp kick back, then eased home.
	local since = elapsed - state.firedAt
	local kick = 0
	if since >= 0 and since < 0.08 then
		kick = since / 0.08 * 0.45
	elseif since >= 0.08 and since < 0.6 then
		kick = 0.45 * (1 - (since - 0.08) / 0.52) ^ 2
	end
	place(state.barrel, floor * CFrame.new(0, 0, kick))
	-- Shots in flight.
	for i = #state.shots, 1, -1 do
		local shot = state.shots[i]
		local t = elapsed - shot.at
		if shot.kind == "nut" then
			if t > 1.6 or t < 0 then
				shot.part:Destroy()
				table.remove(state.shots, i)
			else
				local velocity = Vector3.new(0, 22, -70)
				local offset = velocity * t + Vector3.new(0, -workspace.Gravity * 0.5 * t * t, 0)
				shot.part.CFrame = shot.from * CFrame.new(offset) * CFrame.Angles(t * 9, t * 4, 0)
			end
		else
			if t > 0.7 or t < 0 then
				shot.part:Destroy()
				table.remove(state.shots, i)
			else
				local grow = 1 + t * 5
				shot.part.Size = Vector3.new(grow, grow, grow)
				shot.part.Transparency = math.clamp(t / 0.7, 0, 1)
				shot.part.CFrame = shot.from * CFrame.new(0, t * 1.5, -t * 2)
			end
		end
	end
end

-- ----------------------------------------------------------------- scythe --
-- Held across the body in both hands, the blade up and in front. Follows the hands.

local function scythe(m: Model, prop: Prop)
	local tool = Instance.new("Model")
	tool.Name = "Scythe"
	tool.Parent = m
	-- Built along +Y from the butt at the origin; the blade at the top, curling forward.
	local shaft = Color3.fromRGB(46, 38, 34)
	local blade = Color3.fromRGB(200, 206, 214)
	part(tool, "Shaft", Vector3.new(0.18, 7.0, 0.18), at(0, 3.5, 0), shaft, Enum.Material.Wood)
	part(tool, "Collar", Vector3.new(0.3, 0.3, 0.3), at(0, 6.9, 0), IRON, Enum.Material.Metal)
	part(tool, "Blade1", Vector3.new(0.08, 0.5, 1.6), CFrame.new(0, 6.95, -0.8), blade, Enum.Material.Metal)
	part(tool, "Blade2", Vector3.new(0.08, 0.42, 1.4), CFrame.new(0, 6.72, -2.1) * CFrame.Angles(math.rad(-22), 0, 0), blade,
		Enum.Material.Metal)
	part(tool, "Blade3", Vector3.new(0.08, 0.3, 1.0), CFrame.new(0, 6.25, -3.0) * CFrame.Angles(math.rad(-48), 0, 0), blade,
		Enum.Material.Metal)
	-- A dark mist under the rider.
	local mist = part(m, "Mist", Vector3.new(0.12, 5.5, 5.5), CFrame.new(0, 0.08, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(40, 30, 56), nil, Enum.PartType.Cylinder)
	mist.Transparency = 0.35
	mist.CastShadow = false
	prop.state.tool = layoutOf(tool)
end

local function scytheUpdate(prop: Prop, character: Model, floor: CFrame, _elapsed: number)
	local left = character:FindFirstChild("LeftHand") :: BasePart?
	local right = character:FindFirstChild("RightHand") :: BasePart?
	if not (left and right) then
		return
	end
	local top, low = left.CFrame.Position, right.CFrame.Position
	local along = top - low
	if along.Magnitude < 0.3 then
		return
	end
	local up = along.Unit
	-- The blade curls the way the rider faces.
	local facing = floor.LookVector
	local side = facing:Cross(up)
	if side.Magnitude < 0.05 then
		side = floor.RightVector
	end
	side = side.Unit
	local forward = up:Cross(side)
	local butt = low - up * 1.6
	-- Local Y up the shaft, local -Z towards the blade's curl.
	place(prop.state.tool, CFrame.fromMatrix(butt, side, up, -forward))
end

-- ------------------------------------------------------------------- aura --
-- Floating cross-legged: a soft ring on the floor and four motes circling the body.

local function aura(m: Model, prop: Prop)
	local ring = part(m, "Ring", Vector3.new(0.08, 5.2, 5.2), CFrame.new(0, 0.05, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(196, 176, 255), nil, Enum.PartType.Cylinder)
	ring.Transparency = 0.45
	ring.CastShadow = false
	local inner = part(m, "Inner", Vector3.new(0.1, 3.4, 3.4), CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.pi / 2),
		Color3.fromRGB(236, 226, 255), nil, Enum.PartType.Cylinder)
	inner.Transparency = 0.55
	inner.CastShadow = false
	local motes = {}
	local colours = { Color3.fromRGB(255, 214, 120), Color3.fromRGB(170, 220, 255), Color3.fromRGB(255, 170, 214),
		Color3.fromRGB(190, 255, 200) }
	for i, colour in ipairs(colours) do
		local mote = part(m, "Mote", Vector3.new(0.35, 0.35, 0.35), CFrame.new(), colour, nil, Enum.PartType.Ball)
		mote.CastShadow = false
		motes[i] = mote
	end
	prop.state.motes = motes
	prop.state.ring = ring
end

local function auraUpdate(prop: Prop, _character: Model, floor: CFrame, elapsed: number)
	local motes = prop.state.motes :: { BasePart }
	for i, mote in ipairs(motes) do
		local angle = elapsed * 1.1 + (i - 1) * math.pi / 2
		local height = 2.9 + math.sin(elapsed * 1.7 + i) * 0.35
		mote.CFrame = floor * CFrame.new(math.cos(angle) * 2.1, height, math.sin(angle) * 2.1)
	end
	local ring = prop.state.ring :: BasePart
	ring.Transparency = 0.45 + math.sin(elapsed * 1.6) * 0.12
end

-- --------------------------------------------------------------- registry --

type Spec = { build: (Model, Prop) -> (), update: ((Prop, Model, CFrame, number) -> ())? }

local SPECS: { [string]: Spec } = {
	Toilet = { build = function(m) toilet(m) end },
	Couch = { build = function(m) couch(m) end },
	Lounger = { build = function(m) lounger(m) end },
	Cart = { build = function(m) cart(m) end },
	Surfboard = { build = surfboard, update = surfUpdate },
	Cannon = { build = cannon, update = cannonUpdate },
	Scythe = { build = scythe, update = scytheUpdate },
	Aura = { build = aura, update = auraUpdate },
}

--- Every prop kind there is.
function EmoteProps.Kinds(): { string }
	local out = {}
	for kind in pairs(SPECS) do
		table.insert(out, kind)
	end
	table.sort(out)
	return out
end

--- A new prop of `kind`, laid out around the origin, or nil if there is no such prop.
function EmoteProps.Build(kind: string, parent: Instance?): Prop?
	local spec = SPECS[kind]
	if not spec then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "EmoteProp_" .. kind
	local prop: Prop = { kind = kind, model = model, update = spec.update, state = {} }
	spec.build(model, prop)
	prop.state.layout = layoutOf(model)
	prop.state.pivot = CFrame.new()
	model.Parent = parent
	return prop
end

--- The frame props are laid out in, for a character's root: on the rig's floor, facing
--- the way the character faces.
function EmoteProps.FloorOf(root: CFrame): CFrame
	return root * CFrame.new(0, -EmoteProps.ROOT_HEIGHT, 0)
end

--- Put the prop where it belongs this frame.
function EmoteProps.Update(prop: Prop, character: Model, floor: CFrame, elapsed: number)
	-- Most props never move relative to the character, and the character barely moves while
	-- emoting, so only re-place the whole model when the character actually has.
	local pivot = prop.state.pivot :: CFrame
	if not prop.state.placed or not pivot:FuzzyEq(floor, 1e-3) then
		place(prop.state.layout, floor)
		prop.state.pivot = floor
		prop.state.placed = true
	end
	if prop.update then
		prop.update(prop, character, floor, elapsed)
	end
end

function EmoteProps.Destroy(prop: Prop)
	prop.model:Destroy()
end

return EmoteProps
