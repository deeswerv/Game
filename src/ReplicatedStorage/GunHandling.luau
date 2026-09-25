--!strict
-- How a gun handles, beyond its listed numbers.
--
--   Movement   running widens the cone, and being in the air widens it a lot. Aiming
--              steadies the movement part, but only partly: a scoped sniper on the move
--              still throws rounds wide.
--   First shot a weapon that has been rested for a moment fires its first round tighter
--              than its listed spread, so tapping is a skill and spraying is a choice.
--   Tactical   reloading with a round still in the chamber is quicker than reloading dry.
--   Walls      rifles and snipers put rounds through thin cover (a crate, a door, glass)
--              for reduced damage; a pistol barely does, a shotgun never.
--
-- Shared on purpose. GunHandler applies these to the real shot and WeaponController draws
-- the crosshair from exactly the same numbers, so the crosshair never promises a shot the
-- server will not fire.

local GunHandling = {}

export type Traits = {
	MoveSpread: number,     -- extra degrees of cone at full running speed
	JumpSpread: number,     -- extra degrees in the air
	FirstShot: number,      -- multiplier on a rested weapon's cone
	Penetration: number,    -- studs of (plastic-hard) wall a round can pass through
	FirstShotAdsOnly: boolean?,  -- the first-shot bonus needs the scope up (no free no-scopes)
}

GunHandling.Class = {
	Pistol = { MoveSpread = 0.9, JumpSpread = 3, FirstShot = 0.4, Penetration = 0.8 },
	SMG = { MoveSpread = 0.6, JumpSpread = 2.4, FirstShot = 0.7, Penetration = 0.6 },
	Rifle = { MoveSpread = 1.6, JumpSpread = 5, FirstShot = 0.3, Penetration = 1.8 },
	Shotgun = { MoveSpread = 0.8, JumpSpread = 2.4, FirstShot = 1, Penetration = 0 },
	Sniper = { MoveSpread = 4.5, JumpSpread = 9, FirstShot = 0.15, Penetration = 3.4, FirstShotAdsOnly = true },
} :: { [string]: Traits }

local DEFAULT: Traits = { MoveSpread = 1.2, JumpSpread = 4, FirstShot = 0.5, Penetration = 1 }

GunHandling.RUN_SPEED = 16          -- this fast or faster carries the whole movement penalty
GunHandling.STILL_SPEED = 1.5       -- slower than this counts as standing still
GunHandling.ADS_MOVE_SCALE = 0.55   -- how much of the movement penalty survives aiming
GunHandling.TACTICAL_SCALE = 0.75   -- reload time with a round still chambered
GunHandling.WALL_DAMAGE = 0.62      -- damage a round keeps per wall it passes through
GunHandling.MAX_WALLS = 2

-- How hard a material is to shoot through, as a multiplier on its thickness.
GunHandling.Hardness = {
	Glass = 0.25, Fabric = 0.3, Cardboard = 0.3, Foil = 0.5, Wood = 0.6, WoodPlanks = 0.6,
	Plastic = 0.8, SmoothPlastic = 0.8, Neon = 0.8, Ice = 0.9, Rubber = 1,
	Metal = 1.4, CorrodedMetal = 1.3, DiamondPlate = 1.6, Brick = 1.4, Concrete = 1.5,
	Slate = 1.6, Marble = 1.6, Pebble = 1.6, Granite = 1.8, Cobblestone = 1.8, Rock = 2,
	Basalt = 2, Asphalt = 1.8, Plaster = 1.2,
} :: { [string]: number }

--- The weapon's handling traits: its class's, with any the weapon sets itself on top.
function GunHandling.Traits(cfg: any): Traits
	local base = GunHandling.Class[cfg and cfg.Class or ""] or DEFAULT
	return {
		MoveSpread = cfg and cfg.MoveSpread or base.MoveSpread,
		JumpSpread = cfg and cfg.JumpSpread or base.JumpSpread,
		FirstShot = cfg and cfg.FirstShot or base.FirstShot,
		Penetration = cfg and cfg.Penetration or base.Penetration,
		FirstShotAdsOnly = base.FirstShotAdsOnly,
	}
end

--- Extra cone for the way the shooter is moving.
function GunHandling.MovementSpread(cfg: any, speed: number, airborne: boolean, ads: boolean): number
	local traits = GunHandling.Traits(cfg)
	local run = math.clamp((speed - GunHandling.STILL_SPEED) / (GunHandling.RUN_SPEED - GunHandling.STILL_SPEED), 0, 1)
	local extra = traits.MoveSpread * run
	if airborne then
		extra += traits.JumpSpread
	end
	if ads then
		extra *= GunHandling.ADS_MOVE_SCALE
	end
	return extra
end

--- How long after a shot the weapon counts as rested again.
function GunHandling.RestTime(cfg: any): number
	return math.max((cfg.FireRate or 0.1) * 2.2, 0.28)
end

--- Whether the next shot gets first-shot accuracy.
function GunHandling.Rested(cfg: any, heat: number, sinceShot: number): boolean
	return sinceShot >= GunHandling.RestTime(cfg) and heat <= (cfg.SpreadPerShot or 0.5) * 0.25
end

--- The whole cone for a shot, in degrees: listed spread and heat, aiming, first-shot
--- accuracy and movement.
function GunHandling.Spread(cfg: any, heat: number, ads: boolean, speed: number, airborne: boolean,
	sinceShot: number): number
	local base = math.clamp(cfg.SpreadMin + heat, cfg.SpreadMin, cfg.SpreadMax)
	if ads then
		base *= cfg.AdsSpreadScale
	end
	local traits = GunHandling.Traits(cfg)
	if GunHandling.Rested(cfg, heat, sinceShot) and (ads or not traits.FirstShotAdsOnly) then
		base *= traits.FirstShot
	end
	return base + GunHandling.MovementSpread(cfg, speed, airborne, ads)
end

--- How long a reload takes, and whether it is the quick (tactical) one.
function GunHandling.ReloadTime(cfg: any, ammoLeft: number): (number, boolean)
	if ammoLeft > 0 then
		return cfg.ReloadTime * GunHandling.TACTICAL_SCALE, true
	end
	return cfg.ReloadTime, false
end

--- How a character is moving, read off its root and humanoid.
function GunHandling.Motion(character: Model?): (number, boolean)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid then
		return 0, false
	end
	local v = root.AssemblyLinearVelocity
	local speed = if typeof(v) == "Vector3" then Vector3.new(v.X, 0, v.Z).Magnitude else 0
	local airborne = humanoid.FloorMaterial == Enum.Material.Air and not humanoid.Sit
	return speed, airborne
end

--- What it costs a round to pass through `part` from `entry` along `dir`, and where it
--- comes out -- or nil when the round cannot get through with `budget` left.
function GunHandling.Through(part: BasePart, entry: Vector3, dir: Vector3, budget: number): (Vector3?, number)
	if part:IsA("Terrain") or budget <= 0 then
		return nil, 0
	end
	local hardness = GunHandling.Hardness[part.Material.Name] or 1
	local reach = budget / hardness
	-- Cast back toward the entry from as far as the round could possibly get. A ray that
	-- starts inside a part does not see it, so a wall thicker than the reach is never
	-- "found" and simply stops the round.
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { part }
	local start = entry + dir * (reach + 0.05)
	local back = workspace:Raycast(start, -dir * (reach + 0.05), params)
	if not back then
		return nil, 0
	end
	local thickness = (back.Position - entry).Magnitude
	return back.Position, thickness * hardness
end

return GunHandling
