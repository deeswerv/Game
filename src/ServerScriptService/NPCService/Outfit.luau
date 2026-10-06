--!strict
-- What an NPC wears.
--
-- Every NPC is the players' own R15 rig (see Body), so what makes a Thug a Thug and the Don
-- the Don is what they have on. An outfit is a list of garments -- a beanie, a bandana, a
-- hoodie with its strings and pocket, sneakers with white soles -- and every garment is made
-- to measure: it reads the size of the body part it goes on and builds itself round it, so it
-- sits on the head it was made for, and follows the body when it is scaled up or ragdolls.
--
-- Crews are not clones. An archetype can give a palette -- hoodie colours, jeans, skin tones,
-- hair -- and each body draws its own from it, so five Thugs are five people in the same red
-- bandana rather than one person five times. What a crew shares (the bandana, the tracksuit
-- red) stays fixed, so they still read as a crew.
--
-- Dressing never changes a hitbox: every piece is massless and cannot be hit, touched or
-- collided with, so a shot at a hat goes straight through to the head.
--
--   Outfit.Dress(model, cfg, seed?)   colour the body and put the outfit on (cfg.Outfit,
--                                     cfg.Palette, and the old cfg.Accents still work)
--   Outfit.Figure(template, cfg, seed?) -> Model   a dressed, anchored, scriptless standing
--                                     figure (shop clerks, quest givers)
--   Outfit.Standing(cfg, seed?) -> Model?   the same on the players' rig (StarterCharacter)

local Outfit = {}

export type Look = { [string]: Color3 }
export type Garment = { [any]: any }

type Style = {
	shape: Enum.PartType?,
	material: Enum.Material?,
	shine: number?,
}

-- ------------------------------------------------------------------ colours --

local WHITE = Color3.fromRGB(240, 240, 236)
local BLACK = Color3.fromRGB(26, 26, 30)
local GOLD = Color3.fromRGB(250, 204, 60)
local SILVER = Color3.fromRGB(206, 210, 216)
local SOLE = Color3.fromRGB(236, 234, 228)

--- Skin tones anyone can be drawn from (a palette's `Skin = "tones"`).
Outfit.SkinTones = {
	Color3.fromRGB(255, 219, 182), Color3.fromRGB(241, 194, 150), Color3.fromRGB(224, 172, 128),
	Color3.fromRGB(198, 142, 102), Color3.fromRGB(164, 112, 78), Color3.fromRGB(128, 86, 60),
	Color3.fromRGB(98, 66, 46),
}
--- Hair colours, likewise (`Hair = "natural"`, and the default for anyone with hair).
Outfit.HairColours = {
	Color3.fromRGB(28, 22, 20), Color3.fromRGB(50, 34, 24), Color3.fromRGB(84, 56, 34),
	Color3.fromRGB(20, 20, 22), Color3.fromRGB(128, 88, 52), Color3.fromRGB(36, 28, 24),
}
local NAMED_PALETTES: { [string]: { Color3 } } = { tones = Outfit.SkinTones, natural = Outfit.HairColours }

local function darker(c: Color3, k: number): Color3
	return c:Lerp(Color3.new(0, 0, 0), k)
end

local function lighter(c: Color3, k: number): Color3
	return c:Lerp(Color3.new(1, 1, 1), k)
end

--- A colour from a garment option: a Color3, or the name of one of the look's colours.
local function paint(value: any, look: Look, default: Color3): Color3
	if typeof(value) == "Color3" then
		return value
	elseif type(value) == "string" and look[value] then
		return look[value]
	end
	return default
end

--- The i-th draw from a list for a body with this seed: the same body always draws the same.
local function draw(list: { Color3 }, seed: number, salt: number): Color3
	local n = #list
	local i = math.floor(math.abs(math.sin(seed * 12.9898 + salt * 78.233) * 43758.5453)) % n
	return list[i + 1]
end

--- The look (named colours) for one body of `cfg`.
function Outfit.LookFor(cfg: any, seed: number?): Look
	local s = seed or 1
	local palette = cfg.Palette or {}
	local look: Look = {}
	local salt = 0
	local function pick(key: string, fallback: Color3?)
		salt += 1
		local options = palette[key]
		if type(options) == "string" then
			options = NAMED_PALETTES[options]
		end
		if type(options) == "table" and #options > 0 then
			look[key] = draw(options, s, salt)
		elseif fallback then
			look[key] = fallback
		end
	end
	pick("Skin", cfg.Skin or Color3.fromRGB(198, 164, 128))
	pick("Shirt", cfg.Shirt or Color3.fromRGB(90, 92, 100))
	pick("Pants", cfg.Pants or Color3.fromRGB(58, 60, 68))
	pick("Hair", draw(Outfit.HairColours, s, 99))
	pick("Accent", cfg.AccentColour or GOLD)
	pick("Shoes", cfg.Boots)
	look.Trim = cfg.Trim or WHITE
	return look
end

-- ------------------------------------------------------------------- pieces --

type Ctx = {
	model: Model,
	look: Look,
	cfg: any,
	count: number,
	host: (name: string) -> BasePart?,
	add: (host: string, name: string, size: Vector3, at: CFrame, colour: Color3, style: Style?) -> BasePart?,
	size: (host: string) -> Vector3,
}

local function makeCtx(model: Model, look: Look, cfg: any): Ctx
	local ctx = {} :: Ctx
	ctx.model, ctx.look, ctx.cfg, ctx.count = model, look, cfg, 0
	function ctx.host(name: string): BasePart?
		local p = model:FindFirstChild(name)
		return if p and p:IsA("BasePart") then p else nil
	end
	function ctx.size(name: string): Vector3
		local p = ctx.host(name)
		return if p then p.Size else Vector3.one
	end
	function ctx.add(hostName: string, name: string, size: Vector3, at: CFrame, colour: Color3, style: Style?): BasePart?
		local host = ctx.host(hostName)
		if not host then
			return nil
		end
		local piece = Instance.new("Part")
		if style and style.shape then
			piece.Shape = style.shape
		end
		piece.Name = name
		piece.Size = size
		piece.Color = colour
		piece.Material = style and style.material or Enum.Material.SmoothPlastic
		piece.Reflectance = style and style.shine or 0
		piece.TopSurface = Enum.SurfaceType.Smooth
		piece.BottomSurface = Enum.SurfaceType.Smooth
		piece.CanCollide = false
		piece.CanQuery = false
		piece.CanTouch = false
		piece.Massless = true
		piece.Anchored = host.Anchored
		-- Specks do not need a shadow of their own.
		piece.CastShadow = size.X * size.Y * size.Z > 0.03
		piece.CFrame = host.CFrame * at
		piece.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = host
		weld.Part1 = piece
		weld.Parent = piece
		ctx.count += 1
		return piece
	end
	return ctx
end

local function at(x: number, y: number, z: number): CFrame
	return CFrame.new(x, y, z)
end

local function tilt(x: number, y: number, z: number, degrees: number): CFrame
	return CFrame.new(x, y, z) * CFrame.Angles(0, 0, math.rad(degrees))
end

-- Sides: an R15 body's left is -X (it faces -Z).
local SIDES = { { part = "Left", x = -1 }, { part = "Right", x = 1 } }

-- ----------------------------------------------------------------- garments --
--
-- Each garment reads the sizes of the parts it goes on. Front is -Z, up is +Y, the body's
-- own left is -X. Options: `colour` (a Color3 or a look name: "Shirt", "Accent"...) and
-- whatever else the garment says.

local G: { [string]: (ctx: Ctx, g: Garment) -> () } = {}

-- Heads -------------------------------------------------------------------------------

G.Hair = function(ctx, g)
	local h = ctx.size("Head")
	local c = paint(g.colour, ctx.look, ctx.look.Hair)
	local style = g.style or "short"
	if style == "bald" then
		return
	end
	local top = h.Y / 2
	ctx.add("Head", "Hair", Vector3.new(h.X + 0.06, 0.2, h.Z + 0.06), at(0, top - 0.02, 0.02), c)
	ctx.add("Head", "Hair", Vector3.new(h.X + 0.06, h.Y * 0.55, 0.14), at(0, h.Y * 0.12, h.Z / 2 - 0.02), c)
	for _, s in ipairs(SIDES) do
		ctx.add("Head", "Hair", Vector3.new(0.1, h.Y * 0.34, h.Z * 0.5), at(s.x * h.X / 2, h.Y * 0.24, h.Z * 0.2), c)
	end
	if style == "crop" then
		ctx.add("Head", "Hair", Vector3.new(h.X * 0.9, 0.13, 0.1), at(0, top - 0.1, -(h.Z / 2 + 0.01)), c)
	elseif style == "slick" then
		-- Combed back: a raised, shiny top.
		ctx.add("Head", "Hair", Vector3.new(h.X * 0.92, 0.16, h.Z * 0.96), at(0, top + 0.1, 0.04), c, { shine = 0.15 })
	elseif style == "top" then
		ctx.add("Head", "Hair", Vector3.new(h.X * 0.86, 0.36, h.Z * 0.86), at(0, top + 0.2, 0.04), c)
	elseif style == "grey" then
		-- Distinguished: silver at the temples.
		for _, s in ipairs(SIDES) do
			ctx.add("Head", "Hair", Vector3.new(0.12, h.Y * 0.2, h.Z * 0.3), at(s.x * (h.X / 2 + 0.01), h.Y * 0.2, h.Z * 0.12),
				Color3.fromRGB(196, 196, 200))
		end
	end
end

G.Beanie = function(ctx, g)
	local h = ctx.size("Head")
	local c = paint(g.colour, ctx.look, BLACK)
	local top = h.Y / 2
	ctx.add("Head", "Beanie", Vector3.new(h.X + 0.1, 0.44, h.Z + 0.1), at(0, top - 0.08, 0.01), c)
	ctx.add("Head", "Beanie", Vector3.new(h.X * 0.8, 0.1, h.Z * 0.8), at(0, top + 0.19, 0.01), c)
	ctx.add("Head", "BeanieCuff", Vector3.new(h.X + 0.16, 0.17, h.Z + 0.16), at(0, top - 0.25, 0.01),
		paint(g.cuff, ctx.look, darker(c, 0.15)))
	if g.pom then
		ctx.add("Head", "Pom", Vector3.new(0.32, 0.32, 0.32), at(0, top + 0.32, 0.01), paint(g.pom, ctx.look, WHITE),
			{ shape = Enum.PartType.Ball })
	end
end

G.Cap = function(ctx, g)
	local h = ctx.size("Head")
	local c = paint(g.colour, ctx.look, BLACK)
	local top = h.Y / 2
	local back = g.backwards == true
	local dir = if back then 1 else -1
	ctx.add("Head", "Cap", Vector3.new(h.X + 0.08, 0.3, h.Z + 0.08), at(0, top - 0.02, 0), c)
	ctx.add("Head", "Cap", Vector3.new(h.X * 0.84, 0.08, h.Z * 0.84), at(0, top + 0.17, 0), c)
	ctx.add("Head", "CapButton", Vector3.new(0.14, 0.06, 0.14), at(0, top + 0.23, 0), paint(g.peak, ctx.look, c))
	ctx.add("Head", "CapPeak", Vector3.new(h.X * 0.82, 0.07, 0.54), at(0, top - 0.13, dir * (h.Z / 2 + 0.24)),
		paint(g.peak, ctx.look, c))
	if not back and g.logo then
		ctx.add("Head", "CapLogo", Vector3.new(0.34, 0.18, 0.04), at(0, top, -(h.Z / 2 + 0.06)), paint(g.logo, ctx.look, WHITE))
	end
end

G.Fedora = function(ctx, g)
	local h = ctx.size("Head")
	local c = paint(g.colour, ctx.look, BLACK)
	local top = h.Y / 2
	ctx.add("Head", "HatBrim", Vector3.new(h.X * 1.62, 0.07, h.Z * 1.62), at(0, top - 0.1, 0), c)
	ctx.add("Head", "Hat", Vector3.new(h.X * 1.02, 0.5, h.Z * 0.98), at(0, top + 0.16, 0), c)
	ctx.add("Head", "Hat", Vector3.new(h.X * 0.7, 0.08, h.Z * 0.8), at(0, top + 0.45, 0), c)
	ctx.add("Head", "HatBand", Vector3.new(h.X * 1.05, 0.14, h.Z * 1.01), at(0, top + 0.0, 0), paint(g.band, ctx.look, BLACK))
end

G.Helmet = function(ctx, g)
	local h = ctx.size("Head")
	local c = paint(g.colour, ctx.look, Color3.fromRGB(78, 84, 60))
	local top = h.Y / 2
	ctx.add("Head", "Helmet", Vector3.new(h.X + 0.2, 0.58, h.Z + 0.2), at(0, top - 0.02, 0.02), c)
	ctx.add("Head", "Helmet", Vector3.new(h.X * 0.82, 0.12, h.Z * 0.82), at(0, top + 0.32, 0.02), c)
	ctx.add("Head", "HelmetRim", Vector3.new(h.X + 0.28, 0.08, h.Z + 0.28), at(0, top - 0.3, 0.02), darker(c, 0.18))
	if g.visor then
		ctx.add("Head", "Visor", Vector3.new(h.X * 0.92, 0.28, 0.08), at(0, 0.1, -(h.Z / 2 + 0.07)),
			paint(g.visor, ctx.look, Color3.fromRGB(60, 150, 170)), { shine = 0.35 })
	elseif g.goggles then
		ctx.add("Head", "Goggles", Vector3.new(h.X + 0.22, 0.1, h.Z + 0.22), at(0, top - 0.02, 0.02), BLACK)
		for _, s in ipairs(SIDES) do
			ctx.add("Head", "Goggles", Vector3.new(0.34, 0.2, 0.08), at(s.x * 0.22, top - 0.02, -(h.Z / 2 + 0.13)),
				Color3.fromRGB(230, 170, 60), { shine = 0.4 })
		end
	end
	if g.crest then
		ctx.add("Head", "Crest", Vector3.new(0.16, 0.34, h.Z * 0.9), at(0, top + 0.5, 0.04), paint(g.crest, ctx.look, GOLD))
	end
end

G.Hood = function(ctx, g)
	local h = ctx.size("Head")
	local c = paint(g.colour, ctx.look, darker(ctx.look.Shirt, 0.1))
	local top = h.Y / 2
	ctx.add("Head", "Hood", Vector3.new(h.X + 0.2, 0.26, h.Z + 0.2), at(0, top + 0.02, 0.04), c)
	for _, s in ipairs(SIDES) do
		ctx.add("Head", "Hood", Vector3.new(0.12, h.Y * 0.96, h.Z + 0.16), at(s.x * (h.X / 2 + 0.07), -0.02, 0.06), c)
	end
	ctx.add("Head", "Hood", Vector3.new(h.X + 0.2, h.Y * 0.96, 0.14), at(0, -0.02, h.Z / 2 + 0.08), c)
	ctx.add("Head", "HoodPeak", Vector3.new(h.X + 0.1, 0.12, 0.16), at(0, top - 0.06, -(h.Z / 2 + 0.06)), darker(c, 0.1))
end

G.Bandana = function(ctx, g)
	local h = ctx.size("Head")
	local c = paint(g.colour, ctx.look, Color3.fromRGB(196, 40, 44))
	local front = -(h.Z / 2 + 0.02)
	ctx.add("Head", "Bandana", Vector3.new(h.X + 0.06, 0.36, h.Z + 0.06), at(0, -0.25, 0), c)
	ctx.add("Head", "Bandana", Vector3.new(h.X * 0.62, 0.18, 0.07), at(0, -0.5, front), c)
	ctx.add("Head", "Bandana", Vector3.new(h.X * 0.3, 0.14, 0.07), at(0, -0.64, front), c)
	ctx.add("Head", "BandanaKnot", Vector3.new(0.22, 0.2, 0.12), at(0, -0.2, h.Z / 2 + 0.08), darker(c, 0.12))
	if g.pattern then
		-- A paisley dot or two, so it reads as cloth and not a stripe of paint.
		for _, x in ipairs({ -0.28, 0.1, 0.34 }) do
			ctx.add("Head", "BandanaDot", Vector3.new(0.08, 0.08, 0.02), at(x, -0.22 + x * 0.1, -(h.Z / 2 + 0.04)),
				paint(g.pattern, ctx.look, WHITE))
		end
	end
end

G.Balaclava = function(ctx, g)
	local h = ctx.size("Head")
	local c = paint(g.colour, ctx.look, Color3.fromRGB(24, 24, 28))
	ctx.add("Head", "Balaclava", Vector3.new(h.X + 0.06, h.Y + 0.04, h.Z + 0.06), at(0, 0, 0), c)
	ctx.add("Head", "Balaclava", Vector3.new(h.X * 0.7, 0.1, h.Z * 0.7), at(0, h.Y / 2 + 0.06, 0), c)
	ctx.add("Head", "EyeSlit", Vector3.new(h.X * 0.76, 0.26, 0.04), at(0, 0.1, -(h.Z / 2 + 0.045)), ctx.look.Skin)
	for _, s in ipairs(SIDES) do
		ctx.add("Head", "Eye", Vector3.new(0.13, 0.15, 0.02), at(s.x * 0.2, 0.1, -(h.Z / 2 + 0.07)), Color3.fromRGB(20, 20, 24))
	end
end

G.Shades = function(ctx, g)
	local h = ctx.size("Head")
	local lens = paint(g.colour, ctx.look, Color3.fromRGB(20, 20, 26))
	local frame = paint(g.frame, ctx.look, lens)
	local front = -(h.Z / 2 + 0.04)
	for _, s in ipairs(SIDES) do
		ctx.add("Head", "Lens", Vector3.new(0.4, 0.2, 0.06), at(s.x * 0.24, 0.1, front), lens, { shine = 0.35 })
		ctx.add("Head", "ShadesArm", Vector3.new(0.05, 0.05, h.Z * 0.7), at(s.x * (h.X / 2 + 0.03), 0.15, -h.Z * 0.14), frame)
	end
	ctx.add("Head", "ShadesBridge", Vector3.new(0.12, 0.05, 0.05), at(0, 0.16, front), frame)
end

G.Beard = function(ctx, g)
	local h = ctx.size("Head")
	local c = paint(g.colour, ctx.look, ctx.look.Hair)
	local front = -(h.Z / 2 - 0.04)
	if g.style == "goatee" then
		ctx.add("Head", "Beard", Vector3.new(h.X * 0.32, 0.24, 0.16), at(0, -h.Y / 2 + 0.08, front), c)
		return
	end
	-- Chin, and a band along the jaw round to the ears (sides on their own read as holes).
	ctx.add("Head", "Beard", Vector3.new(h.X * 0.74, 0.26, 0.16), at(0, -h.Y / 2 + 0.09, front), c)
	ctx.add("Head", "Beard", Vector3.new(h.X + 0.04, 0.14, h.Z * 0.62), at(0, -h.Y / 2 + 0.05, -h.Z * 0.2), c)
end

G.Earring = function(ctx, g)
	local h = ctx.size("Head")
	ctx.add("Head", "Earring", Vector3.new(0.08, 0.12, 0.08), at(h.X / 2 + 0.03, -0.12, 0.06),
		paint(g.colour, ctx.look, GOLD), { shine = 0.3 })
end

-- Torsos ------------------------------------------------------------------------------

G.Hoodie = function(ctx, g)
	local t = ctx.size("UpperTorso")
	local c = paint(g.colour, ctx.look, ctx.look.Shirt)
	local front = -(t.Z / 2 + 0.03)
	if g.hood ~= false then
		ctx.add("UpperTorso", "HoodDown", Vector3.new(t.X * 0.64, 0.46, 0.46), at(0, t.Y / 2 - 0.1, t.Z / 2 + 0.08), darker(c, 0.1))
	end
	for _, s in ipairs(SIDES) do
		ctx.add("UpperTorso", "String", Vector3.new(0.05, 0.42, 0.04), at(s.x * 0.16, t.Y / 2 - 0.32, front), WHITE)
		ctx.add("UpperTorso", "String", Vector3.new(0.08, 0.08, 0.06), at(s.x * 0.16, t.Y / 2 - 0.55, front), Color3.fromRGB(180, 180, 176))
	end
	ctx.add("UpperTorso", "Pocket", Vector3.new(t.X * 0.56, 0.42, 0.06), at(0, -t.Y / 2 + 0.36, front), darker(c, 0.1))
	ctx.add("UpperTorso", "Pocket", Vector3.new(t.X * 0.56, 0.05, 0.07), at(0, -t.Y / 2 + 0.56, front), darker(c, 0.22))
	ctx.add("UpperTorso", "Hem", Vector3.new(t.X + 0.04, 0.14, t.Z + 0.04), at(0, -t.Y / 2 + 0.07, 0), darker(c, 0.14))
	if g.print then
		ctx.add("UpperTorso", "Print", Vector3.new(0.56, 0.3, 0.03), at(0, t.Y * 0.14, -(t.Z / 2 + 0.015)),
			paint(g.print, ctx.look, WHITE))
	end
end

G.Tee = function(ctx, g)
	local t = ctx.size("UpperTorso")
	if g.print then
		local c = paint(g.print, ctx.look, WHITE)
		ctx.add("UpperTorso", "Print", Vector3.new(0.6, 0.44, 0.03), at(0, t.Y * 0.1, -(t.Z / 2 + 0.015)), c)
		ctx.add("UpperTorso", "Print", Vector3.new(0.36, 0.22, 0.03), at(0, t.Y * 0.1, -(t.Z / 2 + 0.03)),
			paint(g.inner, ctx.look, ctx.look.Shirt))
	end
	ctx.add("UpperTorso", "Collar", Vector3.new(t.X * 0.42, 0.08, 0.05), at(0, t.Y / 2 - 0.06, -(t.Z / 2 + 0.02)),
		darker(paint(g.colour, ctx.look, ctx.look.Shirt), 0.15))
end

G.Tracksuit = function(ctx, g)
	local t = ctx.size("UpperTorso")
	local stripe = paint(g.stripe, ctx.look, WHITE)
	local front = -(t.Z / 2 + 0.02)
	ctx.add("UpperTorso", "Zip", Vector3.new(0.06, t.Y * 0.92, 0.04), at(0, -0.02, front), SILVER, { shine = 0.2 })
	ctx.add("UpperTorso", "ZipPull", Vector3.new(0.1, 0.16, 0.05), at(0, t.Y / 2 - 0.22, front - 0.02), SILVER, { shine = 0.2 })
	ctx.add("UpperTorso", "Collar", Vector3.new(t.X * 0.6, 0.22, t.Z * 0.86), at(0, t.Y / 2 + 0.02, 0.04), darker(ctx.look.Shirt, 0.08))
	for _, s in ipairs(SIDES) do
		for _, piece in ipairs({ "UpperArm", "LowerArm", "UpperLeg", "LowerLeg" }) do
			local name = s.part .. piece
			local size = ctx.size(name)
			ctx.add(name, "Stripe", Vector3.new(0.05, size.Y * 0.96, 0.14), at(s.x * (size.X / 2 + 0.01), 0, 0), stripe)
		end
	end
end

G.Jacket = function(ctx, g)
	local t = ctx.size("UpperTorso")
	local c = paint(g.colour, ctx.look, ctx.look.Shirt)
	local inner = paint(g.inner, ctx.look, WHITE)
	local front = -(t.Z / 2 + 0.02)
	ctx.add("UpperTorso", "Undershirt", Vector3.new(t.X * 0.32, t.Y * 0.94, 0.04), at(0, -0.01, front), inner)
	for _, s in ipairs(SIDES) do
		ctx.add("UpperTorso", "Lapel", Vector3.new(0.12, t.Y * 0.94, 0.07), at(s.x * (t.X * 0.16 + 0.06), -0.01, front - 0.01),
			darker(c, 0.16))
		ctx.add("UpperTorso", "CollarPoint", Vector3.new(0.34, 0.22, 0.07), tilt(s.x * 0.3, t.Y / 2 - 0.16, front - 0.03, s.x * 25),
			darker(c, 0.1))
		ctx.add("UpperTorso", "PocketFlap", Vector3.new(0.44, 0.08, 0.06), at(s.x * 0.52, -t.Y / 2 + 0.42, front), darker(c, 0.2))
	end
	ctx.add("UpperTorso", "Collar", Vector3.new(t.X * 0.84, 0.3, 0.2), at(0, t.Y / 2 - 0.02, t.Z / 2 + 0.06), darker(c, 0.1))
	if g.hem ~= false then
		ctx.add("UpperTorso", "Hem", Vector3.new(t.X + 0.04, 0.12, t.Z + 0.04), at(0, -t.Y / 2 + 0.06, 0), darker(c, 0.14))
	end
end

G.Suit = function(ctx, g)
	local t = ctx.size("UpperTorso")
	local c = paint(g.colour, ctx.look, ctx.look.Shirt)
	local inner = paint(g.inner, ctx.look, WHITE)
	local front = -(t.Z / 2 + 0.02)
	ctx.add("UpperTorso", "Shirt", Vector3.new(t.X * 0.3, t.Y * 0.54, 0.04), at(0, t.Y * 0.2, front), inner)
	if g.tie ~= false then
		local tie = paint(g.tie, ctx.look, BLACK)
		ctx.add("UpperTorso", "Tie", Vector3.new(0.16, t.Y * 0.56, 0.05), at(0, t.Y * 0.1, front - 0.02), tie)
		ctx.add("UpperTorso", "TieKnot", Vector3.new(0.2, 0.14, 0.06), at(0, t.Y / 2 - 0.14, front - 0.025), darker(tie, 0.15))
	end
	for _, s in ipairs(SIDES) do
		ctx.add("UpperTorso", "Lapel", Vector3.new(0.17, t.Y * 0.56, 0.06), tilt(s.x * 0.25, t.Y * 0.2, front - 0.015, -s.x * 14),
			paint(g.lapel, ctx.look, darker(c, 0.12)))
	end
	for _, y in ipairs({ -0.14, -0.46 }) do
		ctx.add("UpperTorso", "Button", Vector3.new(0.09, 0.09, 0.04), at(0, y, front), darker(c, 0.35))
	end
	ctx.add("UpperTorso", "PocketSquare", Vector3.new(0.22, 0.12, 0.05), at(-0.52, t.Y * 0.2, front),
		paint(g.square, ctx.look, inner))
	if g.flower then
		ctx.add("UpperTorso", "Flower", Vector3.new(0.3, 0.26, 0.1), at(-0.5, t.Y * 0.32, front - 0.04),
			paint(g.flower, ctx.look, Color3.fromRGB(214, 44, 48)), { shape = Enum.PartType.Ball })
	end
	-- Shirt cuffs out of the sleeves, and the sleeves themselves.
	for _, s in ipairs(SIDES) do
		local arm = ctx.size(s.part .. "LowerArm")
		ctx.add(s.part .. "LowerArm", "ShirtCuff", Vector3.new(arm.X + 0.03, 0.12, arm.Z + 0.03), at(0, -arm.Y / 2 + 0.06, 0), inner)
	end
end

G.Chain = function(ctx, g)
	local t = ctx.size("UpperTorso")
	local c = paint(g.colour, ctx.look, GOLD)
	local front = -(t.Z / 2 + 0.07)
	local style: Style = { shine = 0.3 }
	for _, s in ipairs(SIDES) do
		ctx.add("UpperTorso", "Chain", Vector3.new(0.07, 0.5, 0.06), tilt(s.x * 0.2, t.Y / 2 - 0.28, front, -s.x * 22), c, style)
	end
	ctx.add("UpperTorso", "Chain", Vector3.new(0.2, 0.07, 0.06), at(0, t.Y / 2 - 0.52, front), c, style)
	if g.pendant ~= false then
		ctx.add("UpperTorso", "Pendant", Vector3.new(0.2, 0.24, 0.06), at(0, t.Y / 2 - 0.66, front - 0.01),
			paint(g.pendant, ctx.look, c), style)
	end
end

G.Vest = function(ctx, g)
	local t = ctx.size("UpperTorso")
	local c = paint(g.colour, ctx.look, Color3.fromRGB(54, 58, 50))
	ctx.add("UpperTorso", "Vest", Vector3.new(t.X * 0.86, t.Y * 0.66, 0.2), at(0, -0.02, -(t.Z / 2 + 0.08)), c)
	ctx.add("UpperTorso", "Vest", Vector3.new(t.X * 0.86, t.Y * 0.66, 0.2), at(0, -0.02, t.Z / 2 + 0.08), c)
	for _, s in ipairs(SIDES) do
		ctx.add("UpperTorso", "VestStrap", Vector3.new(0.3, 0.12, t.Z + 0.36), at(s.x * 0.46, t.Y / 2 - 0.02, 0), c)
		ctx.add("UpperTorso", "VestSide", Vector3.new(0.14, t.Y * 0.42, t.Z * 0.9), at(s.x * (t.X / 2 + 0.05), -t.Y * 0.12, 0), darker(c, 0.1))
	end
	for _, x in ipairs({ -0.46, 0, 0.46 }) do
		ctx.add("UpperTorso", "Pouch", Vector3.new(0.36, 0.3, 0.14), at(x, -t.Y * 0.18, -(t.Z / 2 + 0.24)), darker(c, 0.14))
	end
	if g.patch then
		ctx.add("UpperTorso", "Patch", Vector3.new(0.42, 0.18, 0.03), at(0, t.Y * 0.18, -(t.Z / 2 + 0.195)), paint(g.patch, ctx.look, WHITE))
	end
end

G.Webbing = function(ctx, g)
	local t = ctx.size("UpperTorso")
	local c = paint(g.colour, ctx.look, Color3.fromRGB(74, 88, 108))
	for _, z in ipairs({ -(t.Z / 2 + 0.03), t.Z / 2 + 0.03 }) do
		for _, s in ipairs(SIDES) do
			ctx.add("UpperTorso", "Webbing", Vector3.new(0.16, t.Y * 1.1, 0.05), tilt(0, 0, z, s.x * 32), c)
		end
	end
	for _, x in ipairs({ -0.5, -0.17, 0.17, 0.5 }) do
		ctx.add("UpperTorso", "Pouch", Vector3.new(0.28, 0.34, 0.14), at(x, -t.Y / 2 + 0.3, -(t.Z / 2 + 0.08)), darker(c, 0.12))
	end
end

G.StrapBag = function(ctx, g)
	local t = ctx.size("UpperTorso")
	local l = ctx.size("LowerTorso")
	local c = paint(g.colour, ctx.look, BLACK)
	ctx.add("UpperTorso", "Strap", Vector3.new(0.12, t.Y * 1.16, 0.05), tilt(0, 0.02, -(t.Z / 2 + 0.035), 36), c)
	ctx.add("UpperTorso", "Strap", Vector3.new(0.12, t.Y * 1.16, 0.05), tilt(0, 0.02, t.Z / 2 + 0.035, 36), c)
	ctx.add("LowerTorso", "Bag", Vector3.new(0.54, 0.42, 0.26), at(l.X * 0.32, 0, -(l.Z / 2 + 0.13)), c)
	ctx.add("LowerTorso", "BagFlap", Vector3.new(0.56, 0.14, 0.28), at(l.X * 0.32, 0.15, -(l.Z / 2 + 0.14)),
		paint(g.flap, ctx.look, darker(c, 0.2)))
end

G.Bandolier = function(ctx, g)
	local t = ctx.size("UpperTorso")
	local c = paint(g.colour, ctx.look, Color3.fromRGB(64, 44, 38))
	ctx.add("UpperTorso", "Bandolier", Vector3.new(0.24, t.Y * 1.18, 0.07), tilt(0, 0, -(t.Z / 2 + 0.04), -34), c)
	ctx.add("UpperTorso", "Bandolier", Vector3.new(0.24, t.Y * 1.18, 0.07), tilt(0, 0, t.Z / 2 + 0.04, -34), c)
	for i = -2, 2 do
		local along = i * 0.24
		local angle = math.rad(-34)
		ctx.add("UpperTorso", "Shell", Vector3.new(0.08, 0.16, 0.05),
			tilt(-math.sin(angle) * along, math.cos(angle) * along, -(t.Z / 2 + 0.09), -34), Color3.fromRGB(214, 170, 60), { shine = 0.2 })
	end
end

G.Chestplate = function(ctx, g)
	local t = ctx.size("UpperTorso")
	local c = paint(g.colour, ctx.look, Color3.fromRGB(66, 64, 70))
	ctx.add("UpperTorso", "Chestplate", Vector3.new(t.X + 0.16, t.Y * 0.66, t.Z + 0.2), at(0, t.Y * 0.14, 0), c, { shine = 0.08 })
	ctx.add("UpperTorso", "Chestplate", Vector3.new(0.16, t.Y * 0.6, 0.06), at(0, t.Y * 0.14, -(t.Z / 2 + 0.13)), lighter(c, 0.12))
	for _, s in ipairs(SIDES) do
		ctx.add("UpperTorso", "Rivet", Vector3.new(0.1, 0.1, 0.04), at(s.x * 0.62, t.Y * 0.36, -(t.Z / 2 + 0.12)), lighter(c, 0.3))
	end
end

G.Pauldrons = function(ctx, g)
	local c = paint(g.colour, ctx.look, Color3.fromRGB(58, 56, 62))
	for _, s in ipairs(SIDES) do
		local name = s.part .. "UpperArm"
		local a = ctx.size(name)
		ctx.add(name, "Pauldron", Vector3.new(a.X + 0.34, 0.42, a.Z + 0.3), at(s.x * 0.08, a.Y / 2 - 0.08, 0), c, { shine = 0.08 })
		ctx.add(name, "Pauldron", Vector3.new(a.X + 0.1, 0.12, a.Z + 0.1), at(s.x * 0.08, a.Y / 2 + 0.18, 0), lighter(c, 0.12))
	end
end

G.Tabard = function(ctx, g)
	local t = ctx.size("UpperTorso")
	local c = paint(g.colour, ctx.look, Color3.fromRGB(96, 118, 100))
	for _, z in ipairs({ -(t.Z / 2 + 0.03), t.Z / 2 + 0.03 }) do
		ctx.add("UpperTorso", "Tabard", Vector3.new(t.X * 0.56, t.Y * 1.24, 0.05), at(0, -t.Y * 0.14, z), c)
	end
	ctx.add("UpperTorso", "Emblem", Vector3.new(0.34, 0.34, 0.03), at(0, t.Y * 0.14, -(t.Z / 2 + 0.06)) * CFrame.Angles(0, 0, math.rad(45)),
		paint(g.emblem, ctx.look, GOLD))
end

G.Cape = function(ctx, g)
	local t = ctx.size("UpperTorso")
	local c = paint(g.colour, ctx.look, Color3.fromRGB(120, 30, 34))
	ctx.add("UpperTorso", "Cape", Vector3.new(t.X * 0.96, t.Y * 1.3, 0.06), at(0, -t.Y * 0.16, t.Z / 2 + 0.07), c)
	ctx.add("UpperTorso", "Cape", Vector3.new(t.X * 1.02, 0.18, 0.2), at(0, t.Y / 2 - 0.04, t.Z / 2 + 0.02), darker(c, 0.15))
end

G.Apron = function(ctx, g)
	local t = ctx.size("UpperTorso")
	local l = ctx.size("LowerTorso")
	local c = paint(g.colour, ctx.look, Color3.fromRGB(120, 82, 52))
	ctx.add("UpperTorso", "Apron", Vector3.new(t.X * 0.68, t.Y * 0.7, 0.05), at(0, -t.Y * 0.14, -(t.Z / 2 + 0.03)), c)
	ctx.add("LowerTorso", "Apron", Vector3.new(l.X * 0.74, l.Y + 0.12, 0.05), at(0, -0.04, -(l.Z / 2 + 0.03)), c)
	ctx.add("LowerTorso", "ApronPocket", Vector3.new(l.X * 0.5, 0.26, 0.05), at(0, -0.06, -(l.Z / 2 + 0.06)), darker(c, 0.15))
	for _, s in ipairs(SIDES) do
		ctx.add("UpperTorso", "ApronStrap", Vector3.new(0.1, 0.5, 0.05), at(s.x * t.X * 0.3, t.Y / 2 - 0.26, -(t.Z / 2 + 0.03)), darker(c, 0.2))
	end
end

G.Polo = function(ctx, g)
	local t = ctx.size("UpperTorso")
	local c = paint(g.colour, ctx.look, ctx.look.Shirt)
	local front = -(t.Z / 2 + 0.02)
	for _, s in ipairs(SIDES) do
		ctx.add("UpperTorso", "Collar", Vector3.new(0.34, 0.14, 0.06), tilt(s.x * 0.2, t.Y / 2 - 0.08, front, s.x * 18), lighter(c, 0.12))
	end
	ctx.add("UpperTorso", "Placket", Vector3.new(0.14, 0.4, 0.04), at(0, t.Y / 2 - 0.26, front), darker(c, 0.12))
	ctx.add("UpperTorso", "Logo", Vector3.new(0.24, 0.18, 0.03), at(-0.48, t.Y * 0.2, front), paint(g.logo, ctx.look, GOLD))
end

-- Arms --------------------------------------------------------------------------------

G.Cuffs = function(ctx, g)
	local c = paint(g.colour, ctx.look, darker(ctx.look.Shirt, 0.14))
	for _, s in ipairs(SIDES) do
		local name = s.part .. "LowerArm"
		local a = ctx.size(name)
		ctx.add(name, "Cuff", Vector3.new(a.X + 0.04, 0.14, a.Z + 0.04), at(0, -a.Y / 2 + 0.07, 0), c)
	end
end

G.Gloves = function(ctx, g)
	local c = paint(g.colour, ctx.look, BLACK)
	for _, s in ipairs(SIDES) do
		local hand = ctx.host(s.part .. "Hand")
		if hand then
			hand.Color = c
		end
		local name = s.part .. "LowerArm"
		local a = ctx.size(name)
		ctx.add(name, "GloveCuff", Vector3.new(a.X + 0.04, 0.14, a.Z + 0.04), at(0, -a.Y / 2 + 0.07, 0), darker(c, 0.1))
	end
end

G.Watch = function(ctx, g)
	local a = ctx.size("LeftLowerArm")
	local c = paint(g.colour, ctx.look, GOLD)
	ctx.add("LeftLowerArm", "Watch", Vector3.new(a.X + 0.05, 0.13, a.Z + 0.05), at(0, -a.Y / 2 + 0.2, 0), darker(c, 0.25), { shine = 0.2 })
	ctx.add("LeftLowerArm", "WatchFace", Vector3.new(0.05, 0.2, 0.22), at(-(a.X / 2 + 0.04), -a.Y / 2 + 0.2, 0), c, { shine = 0.35 })
end

-- Legs and feet -----------------------------------------------------------------------

G.Belt = function(ctx, g)
	local l = ctx.size("LowerTorso")
	local c = paint(g.colour, ctx.look, Color3.fromRGB(40, 30, 26))
	ctx.add("LowerTorso", "Belt", Vector3.new(l.X + 0.04, 0.16, l.Z + 0.04), at(0, l.Y / 2 - 0.1, 0), c)
	ctx.add("LowerTorso", "Buckle", Vector3.new(0.26, 0.18, 0.05), at(0, l.Y / 2 - 0.1, -(l.Z / 2 + 0.04)),
		paint(g.buckle, ctx.look, SILVER), { shine = 0.3 })
end

G.Cargo = function(ctx, g)
	local c = paint(g.colour, ctx.look, darker(ctx.look.Pants, 0.12))
	for _, s in ipairs(SIDES) do
		local name = s.part .. "UpperLeg"
		local u = ctx.size(name)
		ctx.add(name, "CargoPocket", Vector3.new(0.1, 0.4, 0.42), at(s.x * (u.X / 2 + 0.04), -0.14, 0), c)
		ctx.add(name, "CargoPocket", Vector3.new(0.12, 0.08, 0.44), at(s.x * (u.X / 2 + 0.05), 0.09, 0), darker(c, 0.15))
	end
end

G.Kneepads = function(ctx, g)
	local c = paint(g.colour, ctx.look, BLACK)
	for _, s in ipairs(SIDES) do
		local name = s.part .. "LowerLeg"
		local k = ctx.size(name)
		ctx.add(name, "Kneepad", Vector3.new(k.X + 0.06, 0.36, 0.16), at(0, k.Y / 2 - 0.16, -(k.Z / 2 + 0.04)), c)
	end
end

G.Holster = function(ctx, g)
	local u = ctx.size("RightUpperLeg")
	local c = paint(g.colour, ctx.look, BLACK)
	ctx.add("RightUpperLeg", "Holster", Vector3.new(0.16, 0.56, 0.42), at(u.X / 2 + 0.08, -0.06, 0), c)
	for _, y in ipairs({ 0.12, -0.24 }) do
		ctx.add("RightUpperLeg", "HolsterStrap", Vector3.new(u.X + 0.04, 0.08, u.Z + 0.04), at(0, y, 0), darker(c, 0.2))
	end
end

local function footwear(ctx: Ctx, g: Garment, upper: Color3, sole: Color3, soleHeight: number)
	for _, s in ipairs(SIDES) do
		local name = s.part .. "Foot"
		local foot = ctx.host(name)
		if foot then
			foot.Color = upper
			local f = foot.Size
			ctx.add(name, "Sole", Vector3.new(f.X + 0.06, soleHeight, f.Z + 0.06), at(0, -f.Y / 2 + soleHeight / 2, 0), sole)
		end
	end
end

G.Sneakers = function(ctx, g)
	local upper = paint(g.colour, ctx.look, WHITE)
	footwear(ctx, g, upper, paint(g.sole, ctx.look, SOLE), 0.16)
	for _, s in ipairs(SIDES) do
		local name = s.part .. "Foot"
		local f = ctx.size(name)
		ctx.add(name, "ToeCap", Vector3.new(f.X * 0.9, 0.16, 0.3), at(0, -f.Y / 2 + 0.22, -(f.Z / 2 - 0.13)),
			paint(g.toe, ctx.look, lighter(upper, 0.3)))
		if g.stripe then
			ctx.add(name, "ShoeStripe", Vector3.new(0.04, 0.12, 0.52), at(s.x * (f.X / 2 + 0.01), -f.Y / 2 + 0.3, -0.02),
				paint(g.stripe, ctx.look, WHITE))
		end
	end
end

G.Boots = function(ctx, g)
	local upper = paint(g.colour, ctx.look, Color3.fromRGB(40, 32, 28))
	footwear(ctx, g, upper, paint(g.sole, ctx.look, darker(upper, 0.5)), 0.14)
	for _, s in ipairs(SIDES) do
		local name = s.part .. "LowerLeg"
		local k = ctx.size(name)
		ctx.add(name, "BootShaft", Vector3.new(k.X + 0.06, 0.42, k.Z + 0.06), at(0, -k.Y / 2 + 0.21, 0), upper)
		ctx.add(name, "BootLaces", Vector3.new(0.16, 0.36, 0.03), at(0, -k.Y / 2 + 0.22, -(k.Z / 2 + 0.045)), darker(upper, 0.3))
	end
end

G.Loafers = function(ctx, g)
	local upper = paint(g.colour, ctx.look, BLACK)
	footwear(ctx, g, upper, paint(g.sole, ctx.look, darker(upper, 0.4)), 0.08)
	for _, s in ipairs(SIDES) do
		local foot = ctx.host(s.part .. "Foot")
		if foot then
			foot.Reflectance = 0.12
		end
	end
end

-- ------------------------------------------------------------------ bodies --

local SKIN = { Head = true, LeftHand = true, RightHand = true, LeftLowerArm = true, RightLowerArm = true }
local SLEEVES = { LeftUpperArm = true, RightUpperArm = true }
local FOREARMS = { LeftLowerArm = true, RightLowerArm = true }
local SHIRT = { UpperTorso = true }
local PANTS = {
	LowerTorso = true, LeftUpperLeg = true, RightUpperLeg = true,
	LeftLowerLeg = true, RightLowerLeg = true,
}
local FEET = { LeftFoot = true, RightFoot = true }

local function colourFor(partName: string, cfg: any, look: Look): Color3?
	if cfg.LongSleeves and (FOREARMS[partName] or SLEEVES[partName]) then
		return look.Shirt
	elseif SKIN[partName] then
		return look.Skin
	elseif SLEEVES[partName] then
		return if cfg.Sleeves then look.Shirt else look.Skin
	elseif SHIRT[partName] then
		return look.Shirt
	elseif PANTS[partName] then
		return look.Pants
	elseif FEET[partName] then
		return look.Shoes or look.Pants:Lerp(Color3.new(0, 0, 0), 0.45)
	end
	return nil
end

--- The old way to dress: loose blocks at fixed offsets. Kept so an archetype that still
--- lists Accents looks as it did.
local function accents(ctx: Ctx, list: { any })
	for _, accent in ipairs(list) do
		local piece = ctx.add(accent.part, "Accent", accent.size, CFrame.new(accent.offset), accent.colour)
		if not piece and accent.part then
			warn(("[NPC] %s accent names a part the R15 body does not have: %s")
				:format(tostring(ctx.cfg.Archetype), tostring(accent.part)))
		end
	end
end

--- Colour `model`'s body for `cfg` and put its outfit on. `seed` picks from the palette (the
--- same seed dresses the same person). Returns how many pieces it added.
function Outfit.Dress(model: Model, cfg: any, seed: number?): number
	local look = Outfit.LookFor(cfg, seed)
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local colour = colourFor(part.Name, cfg, look)
			if colour then
				part.Color = colour
			end
			part.Material = Enum.Material.SmoothPlastic
		end
	end
	local ctx = makeCtx(model, look, cfg)
	for _, garment in ipairs(cfg.Outfit or {}) do
		local make = G[garment[1]]
		if make then
			make(ctx, garment)
		else
			warn(("[NPC] %s wears a garment nobody knows how to make: %s"):format(tostring(cfg.Archetype), tostring(garment[1])))
		end
	end
	accents(ctx, cfg.Accents or {})
	model:SetAttribute("OutfitSeed", seed or 1)
	return ctx.count
end

--- Every garment there is, for tests and tools.
function Outfit.Garments(): { string }
	local names = {}
	for name in pairs(G) do
		table.insert(names, name)
	end
	table.sort(names)
	return names
end

--- A dressed person who just stands there: `template` (the R15 rig) cloned without its
--- scripts or engine rigging, coloured and dressed. For clerks and quest givers.
---
--- Only the root is anchored: the rest hangs off it by the rig's own Motor6Ds, so the body
--- stays put but every joint can still be posed -- each client gives these people a life
--- (breathing, looking at you, a clerk's hands going up in a robbery: StaffLife.client finds
--- them by the "Staff" tag). Streamed whole, so a client never gets half a person to pose.
function Outfit.Figure(template: Model, cfg: any, seed: number?): Model
	local figure = template:Clone()
	for _, d in ipairs(figure:GetDescendants()) do
		if d.Parent and (d:IsA("LuaSourceContainer") or d:IsA("BodyColors") or d:IsA("AnimationConstraint")
			or d:IsA("BallSocketConstraint") or d:IsA("BillboardGui") or d:IsA("ProximityPrompt")) then
			d:Destroy()
		end
	end
	for _, p in ipairs(figure:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = p.Name == "HumanoidRootPart"
			p.CanCollide = false
		end
	end
	pcall(function()
		figure.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	end)
	figure:AddTag("Staff")
	Outfit.Dress(figure, cfg, seed)
	local root = figure:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		figure.PrimaryPart = root
	end
	local humanoid = figure:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	end
	return figure
end

--- A dressed figure on the players' own rig, or nil if the place has none.
function Outfit.Standing(cfg: any, seed: number?): Model?
	local source = game:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
	if not source or not source:IsA("Model") or not source:FindFirstChild("UpperTorso") then
		return nil
	end
	return Outfit.Figure(source, cfg, seed)
end

return Outfit
