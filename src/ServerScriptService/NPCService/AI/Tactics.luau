--!strict
-- The things that make an enemy read as a soldier rather than a turret.
--
--   CALLOUTS     A short line over its head when something happens -- it spots you, it is
--                reloading, it throws, it lost you, a friend went down. Per voice ("Soldier",
--                "Bandit", "Guard", "Brute"), throttled so a squad talks, not a choir.
--   MARKS        A "?" when it hears something and goes to look, a "!" when it sees you. You
--                always know whether you have been noticed.
--   GRENADES     Hide behind a wall, or camp one spot, and a Soldier or Elite will lob one
--                at you: a real arc that has to clear the geometry, a blinking fuse you can
--                see land and run from, damage that falls off with distance and is mostly
--                stopped by a wall in between. Never onto its own side.
--   SUPPRESSION  Rounds cracking past its head throw its aim off, make it call it, and send
--                anything that uses cover looking for some.
--   PATCHING UP  Hurt and out of your sight, it stops to bandage itself -- which is your
--                window to push, because being hit again cancels it.
--   STRAFING     Holding its ground in a gunfight, it sidesteps between bursts instead of
--                standing still to be shot.
--   GETTING CLEAR A live grenade lands near it -- yours, or the other side's: once it has
--                seen it land (or heard it clatter close by) and had its reaction time, it
--                shouts, and runs out of the blast; close and with the fuse nearly done, it
--                dives into the same roll players do.
--
-- Decisions only. The states that use these live in StateMachine; everything the players
-- see goes out through Effects, and every point of damage through Combat.Hurt.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NPCConfig = require(ReplicatedStorage.NPCConfig)
local Motion = require(ReplicatedStorage.Motion)
local World = require(script.Parent.Parent.World)
local Effects = require(script.Parent.Parent.Effects)
local Combat = require(script.Parent.Parent.Combat)

local Tactics = {}

local NEVER = -math.huge
local BODY = Vector3.new(2.2, 4.6, 2.2)

-- Injected by NPCService: every live agent, for "not onto a friend" and blast victims.
Tactics.Agents = function(): { [Model]: any }
	return {}
end

-- ---------------------------------------------------------------- callouts --

local LINES: { [string]: { [string]: { string } } } = {
	Soldier = {
		Spot = { "Contact!", "Hostile spotted!", "Eyes on target!", "Contact front!" },
		Reload = { "Reloading!", "Changing mags!", "Cover me, reloading!" },
		Grenade = { "Frag out!", "Grenade out!", "Fire in the hole!" },
		Cover = { "Moving to cover!", "Taking cover!" },
		Flank = { "Flanking!", "Going round the side!", "Moving up the flank!" },
		ManDown = { "Man down!", "We lost one!", "They got him!" },
		Lost = { "Lost visual.", "Where'd they go?", "Anyone got eyes?" },
		Retreat = { "Falling back!", "I'm hit, pulling back!" },
		Heal = { "Patching up!", "Need a second!" },
		Suppressed = { "Taking fire!", "I'm pinned!", "Suppressed!" },
		Kill = { "Target down.", "Got 'em.", "Tango down." },
		Danger = { "Grenade!", "Grenade -- move!", "Get clear!" },
	},
	Bandit = {
		Spot = { "There they are!", "Get 'em!", "Fresh meat!", "Over there!" },
		Reload = { "Reloading!", "Hold on, hold on!" },
		Grenade = { "Catch!", "Boom time!" },
		Cover = { "Get down!", "Whoa -- cover!" },
		Flank = { "I'll go round!", "Cut 'em off!" },
		ManDown = { "They got one of us!", "Man down!" },
		Lost = { "Where'd they go?", "Come out, come out..." },
		Retreat = { "I'm outta here!", "Fall back!" },
		Heal = { "Hold up, I'm bleeding!" },
		Suppressed = { "Close one!", "Whoa!" },
		Kill = { "Too easy!", "Got 'em!" },
		Danger = { "Oh no-- RUN!", "Grenade!", "Move, move!" },
	},
	Guard = {
		Spot = { "Halt!", "Hostiles!", "Bandits on the line!" },
		Reload = { "Reloading!", "Cover me!" },
		Grenade = { "Grenade out!" },
		Cover = { "Taking cover!" },
		Flank = { "Flanking!" },
		ManDown = { "Guard down!", "Medic!" },
		Lost = { "Lost them.", "Stay sharp." },
		Retreat = { "Falling back!" },
		Heal = { "Patching up!" },
		Suppressed = { "Under fire!" },
		Kill = { "Hostile down.", "Area clear." },
		Danger = { "Grenade!", "Take cover!" },
	},
	Brute = {
		Spot = { "RAAAH!", "SMASH!", "FOUND YOU!" },
		ManDown = { "GRRR...", "YOU'LL PAY!" },
		Kill = { "HAH!", "WEAK!" },
		Suppressed = { "HAH! MISSED!" },
		Danger = { "HUH?!", "BOOM?!" },
	},
}
Tactics.Lines = LINES

local CALLOUT_COOLDOWN = 5       -- per NPC
local CHORUS_RADIUS = 18         -- one voice at a time among neighbours...
local CHORUS_GAP = 1.6           -- ...for this long
local recentCallouts: { { at: number, position: Vector3 } } = {}

--- Say something about `event`. `always` skips the chance roll and the cooldown (a grenade
--- warning is not optional); the "one voice at a time" rule still applies unless `always`.
function Tactics.Say(agent, now: number, event: string, always: boolean?)
	local voice = LINES[agent.cfg.Voice or "Soldier"]
	local lines = voice and voice[event]
	if not lines or #lines == 0 then
		return
	end
	if not always then
		if now - (agent.lastCalloutAt or NEVER) < CALLOUT_COOLDOWN or math.random() > 0.7 then
			return
		end
		local here = agent.root.Position
		for i = #recentCallouts, 1, -1 do
			local c = recentCallouts[i]
			if now - c.at > CHORUS_GAP then
				table.remove(recentCallouts, i)
			elseif (c.position - here).Magnitude < CHORUS_RADIUS then
				return
			end
		end
	end
	agent.lastCalloutAt = now
	table.insert(recentCallouts, { at = now, position = agent.root.Position })
	local urgent = event == "Grenade" or event == "Spot" or event == "Danger"
	Effects.Send(agent.root.Position, "Callout", agent.model, lines[math.random(#lines)], urgent)
end

--- The "?" / "!" over its head.
function Tactics.Mark(agent, glyph: string)
	Effects.Send(agent.root.Position, "Mark", agent.model, glyph)
end

-- ---------------------------------------------------------------- grenades --

local FUSE = 1.5                 -- seconds on the ground before it goes off
local targetGrenadeAt: { [Model]: number } = {}      -- one grenade per target at a time
local stillSince: { [Model]: { position: Vector3, since: number } } = {}

-- How long `model` has stayed within a few studs of one spot.
local function stationaryFor(model: Model, position: Vector3, now: number): number
	local s = stillSince[model]
	if not s or (s.position - position).Magnitude > 6 then
		stillSince[model] = { position = position, since = now }
		return 0
	end
	return now - s.since
end

local function arcPoint(from: Vector3, to: Vector3, apex: number, t: number): Vector3
	return from:Lerp(to, t) + Vector3.new(0, 4 * apex * t * (1 - t), 0)
end

-- Does a lob from `from` to `to` peaking `apex` above the line clear the world?
local function arcClear(from: Vector3, to: Vector3, apex: number): boolean
	local params = World.GroundParams()
	local previous = from
	for i = 1, 10 do
		local p = arcPoint(from, to, apex, i / 10)
		local hit = workspace:Raycast(previous, p - previous, params)
		if hit and (hit.Position - to).Magnitude > 3 then
			return false
		end
		previous = p
	end
	return true
end

--- Whether to throw at the current target now, and if so where: sets agent.grenadePlan.
function Tactics.WantsGrenade(agent, now: number, info): boolean
	local cfg = agent.cfg
	if (agent.grenadesLeft or 0) <= 0 or now - (agent.lastGrenadeAt or NEVER) < (cfg.GrenadeCooldown or 14) then
		return false
	end
	-- The checks below cast rays; once or twice a second is plenty.
	if now - (agent.grenadeCheckAt or NEVER) < 0.7 then
		return false
	end
	agent.grenadeCheckAt = now
	local target = info.model
	if now - (targetGrenadeAt[target] or NEVER) < 7 then
		return false
	end
	local entry = info.entry
	local sinceSeen = now - (entry.lastSeen or NEVER)
	local hidden = not info.visible and sinceSeen > 1 and sinceSeen < 6
	local camping = info.visible and stationaryFor(target, info.position, now) >= 4
	if not hidden and not camping then
		return false
	end
	local aim: Vector3 = hidden and info.lastPosition or info.position
	local distance = World.Flat(aim - agent.root.Position).Magnitude
	if distance < 14 or distance > (cfg.GrenadeRange or 60) then
		return false
	end
	-- Never onto its own side.
	for _, other in pairs(Tactics.Agents()) do
		if other.alive and other.cfg.Faction == cfg.Faction and (other.root.Position - aim).Magnitude < 11 then
			return false
		end
	end
	-- Worse throwers land further off.
	local miss = (1 - math.clamp(cfg.Accuracy or 0.5, 0, 1)) * 5
	local landing = aim + Vector3.new((math.random() * 2 - 1) * miss, 0, (math.random() * 2 - 1) * miss)
	local floor = World.GroundAt(landing, 6, 14) or World.GroundAt(aim, 6, 14)
	if not floor then
		return false
	end
	local to = floor.Position + Vector3.new(0, 0.45, 0)
	local from = agent.root.Position + Vector3.new(0, 2.6, 0)
	for _, apex in ipairs({ distance * 0.28 + 4, distance * 0.5 + 9 }) do
		if arcClear(from, to, apex) then
			agent.grenadePlan = { from = from, to = to, apex = apex, target = target, distance = distance }
			return true
		end
	end
	return false
end

--- Let go of the planned grenade. It flies, lands, blinks, and goes off; the damage is
--- the server's, the flight and the blast are drawn by every client in range.
function Tactics.Release(agent, now: number)
	local plan = agent.grenadePlan
	agent.grenadePlan = nil
	if not plan or not agent.alive then
		return
	end
	agent.grenadesLeft = (agent.grenadesLeft or 0) - 1
	agent.lastGrenadeAt = now
	targetGrenadeAt[plan.target] = now
	local from = agent.root.Position + Vector3.new(0, 2.6, 0)
	local flight = math.clamp(plan.distance / 30, 0.6, 1.6)
	Effects.Send(from, "Grenade", agent.model, from, plan.to, plan.apex, flight, FUSE)

	local cfg = agent.cfg
	local radius = cfg.GrenadeRadius or 14
	-- The other side sees it land and gets clear, if it is quick about it.
	Tactics.Danger(plan.to, radius, now + flight, now + flight + FUSE, cfg.Faction)
	local damage = cfg.GrenadeDamage or 45
	task.delay(flight + FUSE, function()
		local centre = plan.to + Vector3.new(0, 1.2, 0)
		Effects.Send(centre, "Explode", centre, radius)
		local params = World.GroundParams()
		local function blast(model: Model, humanoid: Humanoid, root: BasePart)
			local offset = root.Position - centre
			local d = offset.Magnitude
			if d > radius or humanoid.Health <= 0 then
				return
			end
			local share = math.max(0.15, 1 - (d / radius) ^ 1.3)
			-- A wall between you and it takes most of it.
			local wall = workspace:Raycast(centre, offset, params)
			if wall and (wall.Position - root.Position).Magnitude > 1.5 then
				share *= 0.2
			end
			local dir = d > 0.1 and offset.Unit or Vector3.new(0, 1, 0)
			Combat.Hurt(agent, model, humanoid, damage * share, "Grenade", dir, "UpperTorso")
		end
		if NPCConfig.IsHostileTo(cfg.Faction, "Player") then
			for _, entry in ipairs(World.LivingPlayers()) do
				blast(entry.model, entry.humanoid, entry.root)
			end
		end
		for model, other in pairs(Tactics.Agents()) do
			if other.alive and model ~= agent.model and NPCConfig.IsHostileTo(cfg.Faction, other.cfg.Faction) then
				blast(model, other.humanoid, other.root)
				if other.alive and (other.root.Position - centre).Magnitude < radius then
					local push = World.Flat(other.root.Position - centre)
					if push.Magnitude > 0.1 then
						other.root.AssemblyLinearVelocity += push.Unit * 18 + Vector3.new(0, 10, 0)
					end
				end
			end
		end
		if Combat.OnNoise then
			Combat.OnNoise(centre, 140, agent.model)
		end
	end)
end

-- --------------------------------------------------------------- dangers --

type Danger = { centre: Vector3, radius: number, landsAt: number, goesOffAt: number, spares: string? }
local dangers: { Danger } = {}

--- A live grenade: it comes to rest at `centre` at `landsAt` and goes off at `goesOffAt`
--- (os.clock). `spares` is the faction its blast leaves alone (an NPC's own side), nil for
--- a player's, which hurts everyone.
function Tactics.Danger(centre: Vector3, radius: number, landsAt: number, goesOffAt: number, spares: string?)
	table.insert(dangers, { centre = centre, radius = radius, landsAt = landsAt, goesOffAt = goesOffAt, spares = spares })
end

--- The live grenade `agent` is inside the blast of and knows about, if any: it has seen it
--- land, or it is close enough to have heard it, and had its reaction time since. The one
--- going off soonest.
function Tactics.DangerFor(agent: any, now: number): Danger?
	local here = agent.root.Position
	local best: Danger? = nil
	for i = #dangers, 1, -1 do
		local d = dangers[i]
		if now > d.goesOffAt + 0.5 then
			table.remove(dangers, i)
		elseif now < d.goesOffAt - 0.1 and (not d.spares or NPCConfig.IsHostileTo(d.spares, agent.cfg.Faction)) then
			local distance = World.Flat(here - d.centre).Magnitude
			local noticeAt = d.landsAt + (agent.cfg.ReactionTime or 0.45) * (agent.dangerSlowness or 1)
			if distance < d.radius + 3 and now >= noticeAt then
				local eye = here + Vector3.new(0, 1.5 * (agent.scale or 1), 0)
				local look = d.centre + Vector3.new(0, 0.4, 0)
				local hit = distance >= 8 and workspace:Raycast(eye, look - eye, World.SightParams()) or nil
				if (not hit or (hit.Position - look).Magnitude < 1.5) and (not best or d.goesOffAt < best.goesOffAt) then
					best = d
				end
			end
		end
	end
	return best
end

--- Somewhere out of `danger`'s blast to run to: straight away from it if there is floor
--- there, else as near that as there is.
function Tactics.EscapePoint(agent: any, danger: Danger): Vector3?
	local here = agent.root.Position
	local away = World.Flat(here - danger.centre)
	local bearing = if away.Magnitude > 0.5 then math.atan2(away.Z, away.X) else math.random() * math.pi * 2
	local reach = danger.radius + 4
	for _, degrees in ipairs({ 0, 35, -35, 70, -70, 110, -110 }) do
		local angle = bearing + math.rad(degrees)
		local candidate = Vector3.new(danger.centre.X + math.cos(angle) * reach, here.Y,
			danger.centre.Z + math.sin(angle) * reach)
		local floor = World.GroundAt(candidate, 8, 14)
		if floor and not agent.nav:RecentlyFailed(floor.Position) and World.IsClear(floor.Position, BODY) then
			return floor.Position
		end
	end
	return nil
end

--- Dive into a roll toward world direction `dir`: the roll players do (Motion), the body
--- pushed along the floor for its length. Clients see it from RollAt / RollDir, the same way
--- they see another player's.
function Tactics.Dive(agent: any, dir: Vector3, now: number): boolean
	local flat = World.Flat(dir)
	if flat.Magnitude < 0.1 or (agent.diveUntil and now < agent.diveUntil) then
		return false
	end
	flat = flat.Unit
	local root = agent.root
	local scale = agent.scale or 1
	agent.diveAt, agent.diveUntil, agent.diveDir = now, now + Motion.ROLL_TIME, flat
	local body = World.Flat(root.CFrame:VectorToObjectSpace(flat))
	agent.model:SetAttribute("RollDir", if body.Magnitude > 0.1 then body.Unit else Vector3.new(0, 0, -1))
	agent.model:SetAttribute("RollAt", workspace:GetServerTimeNow())

	local attachment = root:FindFirstChild("RootAttachment")
	if not attachment or not attachment:IsA("Attachment") then
		attachment = root:FindFirstChild("DiveAttachment")
		if not attachment then
			local made = Instance.new("Attachment")
			made.Name = "DiveAttachment"
			made.Parent = root
			attachment = made
		end
	end
	local push = Instance.new("LinearVelocity")
	push.Name = "DivePush"
	push.Attachment0 = attachment :: Attachment
	push.RelativeTo = Enum.ActuatorRelativeTo.World
	push.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	push.PrimaryTangentAxis = Vector3.new(1, 0, 0)
	push.SecondaryTangentAxis = Vector3.new(0, 0, 1)
	push.MaxForce = root.AssemblyMass * 900
	push.PlaneVelocity = Vector2.new(flat.X, flat.Z) * Motion.RollSpeed(0) * scale
	push.Parent = root
	if agent.divePush then
		agent.divePush:Destroy()
	end
	agent.divePush = push
	return true
end

--- Keep a dive going (the push eases off as the roll ends). True while it is diving.
function Tactics.UpdateDive(agent: any, now: number): boolean
	if not agent.diveUntil then
		return false
	end
	local push = agent.divePush
	if now >= agent.diveUntil or not agent.alive then
		if push then
			push:Destroy()
		end
		agent.divePush, agent.diveUntil = nil, nil
		return false
	end
	if push then
		local flat = agent.diveDir
		push.PlaneVelocity = Vector2.new(flat.X, flat.Z) * Motion.RollSpeed(now - agent.diveAt) * (agent.scale or 1)
	end
	return true
end

-- ------------------------------------------------------------- suppression --

--- A round went past close enough to hear it crack.
function Tactics.Suppress(agent, now: number)
	local fresh = now > (agent.suppressedUntil or 0)
	agent.suppressedUntil = now + 1.8
	if fresh then
		Tactics.Say(agent, now, "Suppressed")
	end
end

function Tactics.Suppressed(agent, now: number): boolean
	return now < (agent.suppressedUntil or 0)
end

-- ------------------------------------------------------------- patching up --

local HEAL_TIME = 3
local HEAL_SHARE = 0.4

--- Hurt, and nobody can see it right now: time to bandage up.
function Tactics.WantsHeal(agent, now: number, info): boolean
	if (agent.medkits or 0) <= 0 then
		return false
	end
	local humanoid = agent.humanoid
	if humanoid.Health / math.max(humanoid.MaxHealth, 1) > 0.45 then
		return false
	end
	if now - (agent.lastHurtAt or NEVER) < 2.5 then
		return false
	end
	if info and info.visible then
		return false
	end
	return true
end

function Tactics.StartHeal(agent, now: number)
	agent.medkits = (agent.medkits or 0) - 1
	agent.healDoneAt = now + HEAL_TIME
	Tactics.Say(agent, now, "Heal", true)
	Effects.Send(agent.root.Position, "Heal", agent.model, HEAL_TIME)
end

--- true once the bandage is on (and the health given); false while still working.
function Tactics.UpdateHeal(agent, now: number): boolean
	if now < (agent.healDoneAt or 0) then
		return false
	end
	local humanoid = agent.humanoid
	local amount = humanoid.MaxHealth * HEAL_SHARE
	humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + amount)
	Effects.Send(agent.root.Position, "Healed", agent.model, math.floor(amount + 0.5))
	return true
end

function Tactics.CancelHeal(agent)
	agent.healDoneAt = nil
	Effects.Send(agent.root.Position, "HealCancel", agent.model)
end

-- ---------------------------------------------------------------- strafing --

--- Holding a spot in a gunfight: a point a few studs to one side to step to, or nil to stand.
function Tactics.StrafePoint(agent, info, now: number): Vector3?
	if not agent.cfg.Strafe or not info.visible then
		return nil
	end
	if agent.strafePoint and now < (agent.strafeUntil or 0) then
		if World.Flat(agent.strafePoint - agent.root.Position).Magnitude < 1 then
			return nil
		end
		return agent.strafePoint
	end
	agent.strafeUntil = now + 1.1 + math.random() * 1.2
	local toTarget = World.Flat(info.position - agent.root.Position)
	if toTarget.Magnitude < 0.1 then
		return nil
	end
	local side = toTarget.Unit:Cross(Vector3.new(0, 1, 0))
	agent.strafeSide = -(agent.strafeSide or 1)
	for _, sign in ipairs({ agent.strafeSide, -agent.strafeSide }) do
		local candidate = agent.root.Position + side * sign * (3 + math.random() * 3)
		local floor = World.GroundAt(candidate, 4, 8)
		if floor and World.IsClear(floor.Position, BODY) and not agent.nav:RecentlyFailed(floor.Position) then
			agent.strafePoint = floor.Position
			return floor.Position
		end
	end
	agent.strafePoint = nil
	return nil
end

-- ------------------------------------------------------------------ memory --

function Tactics.Forget(model: Model)
	targetGrenadeAt[model] = nil
	stillSince[model] = nil
end

return Tactics
