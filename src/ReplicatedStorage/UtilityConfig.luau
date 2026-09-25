--!strict
-- Utility: what you carry besides your guns. The reference hotbar holds a Grenade, a
-- Flashbang and a Medkit beside the weapons, and a cyan armour bar sits over the health --
-- this is that kit.
--
--   F (hold)   aim the selected throwable -- an arc shows where it will go -- release to throw
--   X          switch throwable: Frag, Flashbang, Smoke
--   Z          use a medkit
--
-- Each life (and each duel round) starts with a fresh kit: how many of each you carry is
-- below, and each kind unlocks at a level, like the guns do. Armour does not come in the
-- kit: enemies drop plates, and a duel gives both fighters the same amount each round.
--
-- Shared, so the server that decides and the screen that shows agree on every number --
-- including the flight path, which both work out with Trajectory below.

local UtilityConfig = {}

UtilityConfig.Keys = {
	Throw = Enum.KeyCode.F,
	Cycle = Enum.KeyCode.X,
	Medkit = Enum.KeyCode.Z,
}

export type Throwable = {
	id: string,
	name: string,
	short: string,
	icon: string,
	colour: Color3,
	unlockLevel: number,
	perLife: number,
	fuse: number,          -- seconds from the throw (Smoke: from landing)
	radius: number,
	damage: number?,       -- Frag
	blind: number?,        -- Flash: longest blindness, seconds
	duration: number?,     -- Smoke: how long the cloud stands
}

UtilityConfig.Throwables = {
	Frag = {
		id = "Frag", name = "Frag Grenade", short = "FRAG", icon = "💣", colour = Color3.fromRGB(236, 84, 70),
		unlockLevel = 3, perLife = 2, fuse = 2.1, radius = 16, damage = 110,
	},
	Flash = {
		id = "Flash", name = "Flashbang", short = "FLASH", icon = "⚡", colour = Color3.fromRGB(255, 226, 90),
		unlockLevel = 7, perLife = 2, fuse = 1.4, radius = 50, blind = 3.4,
	},
	Smoke = {
		id = "Smoke", name = "Smoke Grenade", short = "SMOKE", icon = "☁", colour = Color3.fromRGB(190, 196, 206),
		unlockLevel = 1, perLife = 1, fuse = 0.4, radius = 13, duration = 15,
	},
} :: { [string]: Throwable }

UtilityConfig.Order = { "Frag", "Flash", "Smoke" }

UtilityConfig.Medkit = {
	name = "Medkit", short = "MEDKIT", icon = "✚", colour = Color3.fromRGB(96, 226, 110),
	unlockLevel = 1, perLife = 2,
	channel = 1.2,       -- seconds of patching up; moving is slowed, being hit does not cancel
	heal = 50,
	walkSpeed = 9,
}

UtilityConfig.Armour = {
	max = 75,            -- three segments of 25, the reference's cyan bar
	plate = 25,
	duel = 50,           -- both fighters, every round
	-- How likely an enemy is to drop a plate, by archetype; the rest use `default`.
	dropChance = { Grunt = 0.25, Soldier = 0.4, Marksman = 0.4, Brute = 0.7, Elite = 0.8, Guard = 0.3, Warlord = 1 },
	defaultDrop = 0.3,
	pickupRadius = 4.5,
	lifetime = 45,       -- seconds a dropped plate waits
}

-- Throwing.
UtilityConfig.THROW_SPEED = 76
UtilityConfig.THROW_LIFT = 10        -- added straight up, so a level throw still arcs
UtilityConfig.GRAVITY = 110
UtilityConfig.COOLDOWN = 0.8
UtilityConfig.STEP = 1 / 30
UtilityConfig.MAX_FLIGHT = 3.5
UtilityConfig.MAX_BOUNCES = 2
UtilityConfig.BOUNCE_KEEP = 0.38     -- speed kept off a wall

--- Everything a kind is, whether it is a throwable or the medkit.
function UtilityConfig.Get(id: string): any
	if id == "Medkit" then
		return UtilityConfig.Medkit
	end
	return UtilityConfig.Throwables[id]
end

--- How many of each a player at `level` carries into a life. Locked kinds carry none.
function UtilityConfig.KitFor(level: number): { [string]: number }
	local kit = {}
	for id, t in pairs(UtilityConfig.Throwables) do
		kit[id] = level >= t.unlockLevel and t.perLife or 0
	end
	kit.Medkit = level >= UtilityConfig.Medkit.unlockLevel and UtilityConfig.Medkit.perLife or 0
	return kit
end

--- The velocity a throw leaves the hand with.
function UtilityConfig.LaunchVelocity(direction: Vector3): Vector3
	local d = direction.Magnitude > 0 and direction.Unit or Vector3.new(0, 0, -1)
	return d * UtilityConfig.THROW_SPEED + Vector3.new(0, UtilityConfig.THROW_LIFT, 0)
end

export type Path = { points: { Vector3 }, times: { number }, rest: Vector3, restAt: number, landed: boolean }

--- Where a throw goes: a gravity arc, stepped and cast against the world, glancing off walls
--- (at most MAX_BOUNCES times) and stopping on the first floor it meets. `cast(from, delta)`
--- is the caller's raycast (so the server and the aim preview each use their own filter) and
--- returns a result with Position and Normal, or nil.
function UtilityConfig.Trajectory(origin: Vector3, velocity: Vector3,
	cast: (Vector3, Vector3) -> any): Path
	local g = Vector3.new(0, -UtilityConfig.GRAVITY, 0)
	local dt = UtilityConfig.STEP
	local pos, vel, t = origin, velocity, 0
	local points, times = { origin }, { 0 }
	local bounces = 0
	while t < UtilityConfig.MAX_FLIGHT do
		local nextVel = vel + g * dt
		local step = (vel + nextVel) * 0.5 * dt
		local hit = cast(pos, step)
		if hit then
			local travelled = (hit.Position - pos).Magnitude
			local fraction = step.Magnitude > 0 and math.clamp(travelled / step.Magnitude, 0, 1) or 1
			t += dt * fraction
			local normal: Vector3 = hit.Normal
			pos = hit.Position + normal * 0.35
			table.insert(points, pos)
			table.insert(times, t)
			if normal.Y > 0.6 or bounces >= UtilityConfig.MAX_BOUNCES then
				-- A floor, or out of bounces: it stops (dropping to a floor if it hit a wall).
				if normal.Y <= 0.6 then
					local drop = cast(pos, Vector3.new(0, -60, 0))
					if drop then
						local fall = (pos.Y - drop.Position.Y)
						t += math.sqrt(math.max(0, 2 * fall / UtilityConfig.GRAVITY))
						pos = drop.Position + Vector3.new(0, 0.35, 0)
						table.insert(points, pos)
						table.insert(times, t)
					end
				end
				return { points = points, times = times, rest = pos, restAt = t, landed = true }
			end
			-- Glance off: mirror the velocity in the surface and lose most of it.
			vel = (nextVel - 2 * nextVel:Dot(normal) * normal) * UtilityConfig.BOUNCE_KEEP
			bounces += 1
		else
			pos += step
			vel = nextVel
			t += dt
			table.insert(points, pos)
			table.insert(times, t)
		end
	end
	return { points = points, times = times, rest = pos, restAt = t, landed = false }
end

--- Where along a path something is at time `t` (it sits at rest once there).
function UtilityConfig.PositionAt(path: Path, t: number): Vector3
	local times = path.times
	if t >= times[#times] then
		return path.rest
	end
	for i = 2, #times do
		if times[i] >= t then
			local a, b = times[i - 1], times[i]
			local u = b > a and (t - a) / (b - a) or 1
			return path.points[i - 1]:Lerp(path.points[i], u)
		end
	end
	return path.rest
end

--- How much of a frag's damage lands at distance `d`: full at the middle, falling away to a
--- tenth at the edge, nothing past it.
function UtilityConfig.FragShare(d: number): number
	local r = UtilityConfig.Throwables.Frag.radius
	if d > r then
		return 0
	end
	return math.max(0.1, 1 - (d / r) ^ 1.25)
end

--- How long a flash blinds someone: longer close up and looking at it, shorter at the edge of
--- its range or facing away. `facing` is the dot of their view with the direction to it.
function UtilityConfig.BlindFor(distance: number, facing: number): number
	local flash = UtilityConfig.Throwables.Flash
	if distance > flash.radius then
		return 0
	end
	local near = 1 - (distance / flash.radius) ^ 1.5
	local look = facing >= 0.2 and (0.55 + 0.45 * facing) or (facing > -0.4 and 0.3 or 0.12)
	return (flash.blind :: number) * near * look
end

--- Does the segment from `a` to `b` pass through a sphere?
function UtilityConfig.SegmentHitsSphere(a: Vector3, b: Vector3, centre: Vector3, radius: number): boolean
	local ab = b - a
	local lengthSq = ab:Dot(ab)
	local t = lengthSq > 0 and math.clamp((centre - a):Dot(ab) / lengthSq, 0, 1) or 0
	return ((a + ab * t) - centre).Magnitude <= radius
end

return UtilityConfig
