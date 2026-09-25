--!strict
-- What an NPC is doing, and what makes it change its mind.
--
-- One state at a time, each with enter / update / exit. The states only DECIDE -- moving is
-- the Navigator's job, shooting is Combat's, turning and raising the weapon is Body's -- so
-- each state reads as a short description of behaviour rather than a pile of mechanics.
--
--   calm:    Idle -> Patrol -> Idle ...          Investigate (heard something)
--            Search (lost someone)               Returning (going home)
--   combat:  Alert (noticed; turning, raising)   Engage (aiming, firing, holding a slot)
--            Chase (closing, or following to where they were last seen)
--            TakeCover / Reload / Retreat / Reposition
--   either:  Stunned (a heavy hit) and Dead
--
-- The rules that apply whatever state it is in -- a stun, the leash, noticing a target,
-- losing one -- live in Think, above the states, so no state has to remember to check them.

local World = require(script.Parent.Parent.World)
local Body = require(script.Parent.Parent.Body)
local Combat = require(script.Parent.Parent.Combat)
local Perception = require(script.Parent.Perception)
local Squad = require(script.Parent.Squad)
local Cover = require(script.Parent.Cover)

local StateMachine = {}

local CALM = { Idle = true, Patrol = true, Investigate = true, Search = true, Returning = true }
local COMBAT = {
	Alert = true, Engage = true, Chase = true, TakeCover = true, Reload = true,
	Retreat = true, Reposition = true, Stunned = true,
}
StateMachine.Combat = COMBAT

local NEVER = -math.huge
local BODY = Vector3.new(2.2, 4.6, 2.2)

local STATES = {}

function StateMachine.Set(agent, name: string, now: number)
	if agent.state == name then
		return
	end
	local previous = STATES[agent.state]
	if previous and previous.exit then
		previous.exit(agent, now)
	end
	agent.state = name
	agent.stateAt = now
	agent.model:SetAttribute("State", name)
	local nextState = STATES[name]
	if nextState and nextState.enter then
		nextState.enter(agent, now)
	end
end

function StateMachine.InCombat(agent): boolean
	return COMBAT[agent.state] == true
end

function StateMachine.Stun(agent, now: number, duration: number)
	agent.stunUntil = math.max(agent.stunUntil or 0, now + duration)
end

-- ----------------------------------------------------------------- helpers --

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function failedSince(agent, since: number): boolean
	return agent.nav.failedAt >= since
end

--- A standable point between `minRadius` and `maxRadius` of `centre`, or nil.
local function pointNear(agent, centre: Vector3, minRadius: number, maxRadius: number): Vector3?
	for _ = 1, 5 do
		local angle = math.random() * math.pi * 2
		local radius = minRadius + math.random() * (maxRadius - minRadius)
		local candidate = centre + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local floor = World.GroundAt(candidate, 8, 14)
		if floor and World.IsClear(floor.Position, BODY) and not agent.nav:RecentlyFailed(floor.Position) then
			return floor.Position
		end
	end
	return nil
end
StateMachine.PointNear = pointNear

--- A spot at the keeper's range with a clear shot at the target, off to one side of where it
--- is now: the marksman's "move after shooting".
local function sightlinePoint(agent, info): Vector3?
	local cfg = agent.cfg
	local fromTarget = World.Flat(agent.root.Position - info.position)
	local bearing = fromTarget.Magnitude > 0.1 and math.atan2(fromTarget.Z, fromTarget.X) or 0
	local range = cfg.PreferredRange or 50
	local head = info.model:FindFirstChild("Head")
	local aim = head and head:IsA("BasePart") and head.Position or info.position + Vector3.new(0, 1.5, 0)
	for _, degrees in ipairs({ 25, -25, 45, -45, 65, -65 }) do
		local angle = bearing + math.rad(degrees)
		local distance = range * (0.9 + math.random() * 0.2)
		local candidate = info.position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
		local floor = World.GroundAt(candidate, 10, 20)
		if floor and not agent.nav:RecentlyFailed(floor.Position) then
			local eye = floor.Position + Vector3.new(0, 4.6, 0)
			local hit = workspace:Raycast(eye, aim - eye, World.SightParams())
			if not hit or hit.Instance:IsDescendantOf(info.model) then
				return floor.Position
			end
		end
	end
	return nil
end

local function tryCover(agent, now: number, info, forReload: boolean): boolean
	local point = Cover.Find(agent, info.position, now)
	if not point or flatDistance(point, agent.root.Position) > 30 then
		return false
	end
	agent.coverForReload = forReload
	StateMachine.Set(agent, "TakeCover", now)
	return true
end

local function randomGlance(agent)
	local angle = math.random() * math.pi * 2
	Body.Face(agent, agent.root.Position + Vector3.new(math.cos(angle), 0, math.sin(angle)) * 10)
end

local function moveIfAway(agent, point: Vector3, pace: string, within: number?)
	if flatDistance(point, agent.root.Position) > (within or 1.5) then
		agent.nav:MoveTo(point, pace)
	end
end

-- ------------------------------------------------------------------ calm --

STATES.Idle = {
	enter = function(agent, now)
		agent.nav:Stop()
		Body.Face(agent, nil)
		Body.SetStance(agent, false, false)
		Squad.Leave(agent)
		Cover.Release(agent)
		agent.idleUntil = now + 2 + math.random() * 4
	end,
	update = function(agent, now)
		Combat.Tidy(agent, now)
		if (agent.cfg.PatrolRadius or 0) > 0 and now >= agent.idleUntil then
			StateMachine.Set(agent, "Patrol", now)
		end
	end,
}

STATES.Patrol = {
	enter = function(agent, now)
		local radius = agent.cfg.PatrolRadius or 0
		agent.patrolPoint = radius > 0 and pointNear(agent, agent.home, radius * 0.35, radius) or nil
		agent.giveUpAt = now + 15
	end,
	update = function(agent, now)
		Combat.Tidy(agent, now)
		local point = agent.patrolPoint
		if not point or now > agent.giveUpAt or failedSince(agent, agent.stateAt)
			or flatDistance(point, agent.root.Position) <= 3 then
			StateMachine.Set(agent, "Idle", now)
			return
		end
		agent.nav:MoveTo(point, "walk")
	end,
}

STATES.Investigate = {
	enter = function(agent, now)
		local alert = agent.alert
		agent.investigatePoint = alert and alert.position or nil
		agent.alert = nil
		agent.giveUpAt = now + 12
		agent.lookUntil = nil
		Body.SetStance(agent, false, false)
		Body.Face(agent, nil)
	end,
	update = function(agent, now)
		local point = agent.investigatePoint
		if not point or now > agent.giveUpAt then
			StateMachine.Set(agent, "Returning", now)
			return
		end
		if agent.lookUntil then
			if now >= (agent.nextGlanceAt or 0) then
				randomGlance(agent)
				agent.nextGlanceAt = now + 0.6
			end
			if now >= agent.lookUntil then
				agent.lastKnown = point
				StateMachine.Set(agent, "Search", now)
			end
			return
		end
		if flatDistance(point, agent.root.Position) <= 4 or failedSince(agent, agent.stateAt) then
			agent.nav:Stop()
			agent.lookUntil = now + 1.8
			return
		end
		local hurried = now - (agent.lastHurtAt or NEVER) < 4
		agent.nav:MoveTo(point, hurried and "run" or "walk")
	end,
}

STATES.Search = {
	enter = function(agent, now)
		agent.searchCentre = agent.lastKnown or agent.root.Position
		agent.searchUntil = now + (agent.cfg.SearchTime or 9)
		agent.searchPoint = nil
		agent.lookUntil = nil
		Squad.Leave(agent)
		Cover.Release(agent)
		Body.SetStance(agent, false, false)
		Body.Face(agent, nil)
	end,
	update = function(agent, now)
		Combat.Tidy(agent, now)
		if now >= agent.searchUntil then
			agent.lastKnown = nil
			StateMachine.Set(agent, "Returning", now)
			return
		end
		if agent.lookUntil then
			if now < agent.lookUntil then
				if now >= (agent.nextGlanceAt or 0) then
					randomGlance(agent)
					agent.nextGlanceAt = now + 0.7
				end
				return
			end
			agent.lookUntil = nil
			agent.searchPoint = nil
			Body.Face(agent, nil)
		end
		if not agent.searchPoint then
			agent.searchPoint = pointNear(agent, agent.searchCentre, 5, 16)
			if not agent.searchPoint then
				agent.lookUntil = now + 1.2
				return
			end
		end
		local point = agent.searchPoint :: Vector3
		if flatDistance(point, agent.root.Position) <= 3 or agent.nav:RecentlyFailed(point) then
			agent.nav:Stop()
			agent.lookUntil = now + 0.8 + math.random()
		else
			agent.nav:MoveTo(point, "walk")
		end
	end,
}

STATES.Returning = {
	enter = function(agent, now)
		Squad.Leave(agent)
		Cover.Release(agent)
		Body.SetStance(agent, false, false)
		Body.Face(agent, nil)
		agent.target = nil
	end,
	update = function(agent, now)
		Combat.Tidy(agent, now)
		if flatDistance(agent.home, agent.root.Position) <= 4 or failedSince(agent, agent.stateAt) then
			StateMachine.Set(agent, "Idle", now)
			return
		end
		agent.nav:MoveTo(agent.home, "walk")
	end,
}

-- ---------------------------------------------------------------- combat --

STATES.Alert = {
	enter = function(agent, now)
		agent.nav:Stop()
		local cfg = agent.cfg
		-- Already shot at, or already fighting a moment ago: no time spent working out
		-- what is going on.
		local hurried = now - (agent.lastHurtAt or NEVER) < 2 and 0.5 or 1
		local seasoned = now - (agent.lastCombatAt or NEVER) < 8 and 0.5 or 1
		local reaction = (cfg.ReactionTime or 0.45) * hurried * seasoned
		agent.reactAt = now + reaction
		agent.raiseAt = now + reaction * 0.5
	end,
	update = function(agent, now, info)
		if not info then
			return
		end
		-- 1. turn toward it.  2. raise the weapon.  3. aim.  Engage then fires once AimTime
		-- has passed. Nothing opens fire the instant a player appears.
		Body.Face(agent, info.position)
		local weapon = Combat.Current(agent)
		if now >= agent.raiseAt and weapon and weapon.ranged then
			Body.SetStance(agent, true, false)
			Body.AimAt(agent, info.position + Vector3.new(0, 1, 0))
		end
		if now >= agent.reactAt then
			agent.acquiredAt = now
			agent.fireReadyAt = now + (agent.cfg.AimTime or 0.25)
			StateMachine.Set(agent, "Engage", now)
		end
	end,
}

local function engageMelee(agent, now: number, info)
	local cfg = agent.cfg
	Body.SetStance(agent, false, false)
	if agent.swing then
		agent.nav:Stop()
		Body.Face(agent, info.position)
		return
	end
	if info.visible and info.distance <= cfg.AttackRange + 0.5 then
		agent.nav:Stop()
		Body.Face(agent, info.position)
		local look = World.Flat(agent.root.CFrame.LookVector)
		local toTarget = World.Flat(info.position - agent.root.Position)
		if toTarget.Magnitude < 0.5 or (look.Magnitude > 0 and look.Unit:Dot(toTarget.Unit) > 0.6) then
			Combat.StartSwing(agent, now, info.model)
		end
		return
	end
	if not info.visible then
		StateMachine.Set(agent, "Chase", now)
		return
	end
	Body.Face(agent, nil)
	-- From a distance, approach through a slot so a pack spreads out around you; once
	-- close, go straight in.
	local destination = info.distance < 12 and info.position or Squad.SlotFor(agent, info, now)
	agent.nav:MoveTo(destination, "run")
end

STATES.Engage = {
	enter = function(agent, now)
		agent.fireReadyAt = math.max(agent.fireReadyAt or 0, now + (agent.cfg.AimTime or 0.25) * 0.4)
	end,
	exit = function(agent, now)
		Combat.Fire(agent, now, nil, false)
	end,
	update = function(agent, now, info)
		if not info then
			return
		end
		local cfg = agent.cfg
		Squad.Join(agent, info.model)
		local weapon = Combat.Current(agent)
		local health = agent.humanoid.Health / math.max(agent.humanoid.MaxHealth, 1)

		if (cfg.RetreatHealth or 0) > 0 and health < cfg.RetreatHealth and (cfg.Aggression or 0.5) < 0.8
			and now - (agent.retreatedAt or NEVER) > 15 then
			StateMachine.Set(agent, "Retreat", now)
			return
		end

		if not weapon or not weapon.ranged then
			engageMelee(agent, now, info)
			return
		end

		if weapon.ammo <= 0 and not agent.reloadUntil then
			if Combat.TrySwitch(agent, now, info.distance) then
				return
			end
			if cfg.UsesCover and tryCover(agent, now, info, true) then
				return
			end
			StateMachine.Set(agent, "Reload", now)
			return
		end

		if not info.visible or info.distance > cfg.AttackRange then
			StateMachine.Set(agent, "Chase", now)
			return
		end

		Body.Face(agent, info.position)
		Body.SetStance(agent, true, false)
		Body.AimAt(agent, info.root.Position + Vector3.new(0, 1, 0))
		Combat.Fire(agent, now, info.model, now >= (agent.fireReadyAt or 0))

		-- Taking hits out in the open is the cue to find cover -- not every hit, and not again
		-- straight after leaving it, or it spends the whole fight hiding.
		if cfg.UsesCover and now - (agent.lastHurtAt or NEVER) < 1.2
			and now - (agent.coverLeftAt or NEVER) > 4 + 6 * (cfg.Aggression or 0.5) then
			if tryCover(agent, now, info, false) then
				return
			end
		end

		if cfg.Behaviour == "Keeper" then
			if info.distance < (cfg.PreferredRange or 50) * 0.5 then
				local away = World.Flat(agent.root.Position - info.position)
				if away.Magnitude > 0.1 then
					agent.nav:MoveTo(agent.root.Position + away.Unit * 16, "run")
				end
				return
			end
			if cfg.RepositionShots and (agent.shotsFromSpot or 0) >= cfg.RepositionShots then
				StateMachine.Set(agent, "Reposition", now)
				return
			end
		end

		local slot = Squad.SlotFor(agent, info, now)
		local off = flatDistance(slot, agent.root.Position)
		if off > 5 then
			agent.nav:MoveTo(slot, (agent.role == "Push" or off > 25) and "run" or "walk")
		else
			agent.nav:Stop()
		end
	end,
}

STATES.Chase = {
	enter = function(agent, now)
		Body.Face(agent, nil)
	end,
	update = function(agent, now, info)
		if not info then
			return
		end
		local cfg = agent.cfg
		local weapon = Combat.Current(agent)
		local ranged = weapon ~= nil and weapon.ranged
		if info.visible then
			if ranged and info.distance <= cfg.AttackRange * 0.9 then
				agent.acquiredAt = now
				agent.fireReadyAt = now + (cfg.AimTime or 0.25) * 0.6
				StateMachine.Set(agent, "Engage", now)
				return
			elseif not ranged and info.distance <= math.max(cfg.AttackRange * 2, 12) then
				StateMachine.Set(agent, "Engage", now)
				return
			end
		end

		if not info.visible and flatDistance(info.lastPosition, agent.root.Position) < 4 then
			-- Reached the last place we saw them and they are not here. Mark the memory as
			-- searched so it is not chased again until they are actually seen or heard.
			info.entry.searchedAt = now
			agent.lastKnown = info.lastPosition
			agent.target = nil
			StateMachine.Set(agent, "Search", now)
			return
		end
		local destination = info.visible and info.position or info.lastPosition
		Body.SetStance(agent, false, ranged and info.distance > 18)
		agent.nav:MoveTo(destination, "run")
		if ranged and not info.visible and weapon.ammo < weapon.magazine * 0.35 then
			Combat.StartReload(agent, now)
		end
	end,
}

STATES.TakeCover = {
	enter = function(agent, now)
		agent.coverArrived = false
		agent.peeking = false
		agent.coverUntil = nil
		agent.coverPhaseAt = now
		Combat.Fire(agent, now, nil, false)
	end,
	exit = function(agent, now)
		agent.coverLeftAt = now
		agent.peeking = false
		Cover.Release(agent)
	end,
	update = function(agent, now, info)
		if not info then
			return
		end
		local point = agent.coverPoint
		if not point then
			StateMachine.Set(agent, "Engage", now)
			return
		end
		local weapon = Combat.Current(agent)

		if not agent.coverArrived then
			Body.SetStance(agent, false, true)
			Body.Face(agent, nil)
			agent.nav:MoveTo(point, "run")
			if flatDistance(point, agent.root.Position) <= 2.5 then
				agent.coverArrived = true
				agent.nav:Stop()
				agent.coverPhaseAt = now
				agent.coverUntil = now + 2.5 + (1 - (agent.cfg.Aggression or 0.5)) * 3
			elseif failedSince(agent, agent.stateAt) or now - agent.stateAt > 6 then
				StateMachine.Set(agent, "Engage", now)
			end
			return
		end

		Body.Face(agent, info.position)

		if weapon and weapon.ranged and not agent.reloadUntil and not agent.peeking
			and weapon.ammo < weapon.magazine * 0.5 then
			Combat.StartReload(agent, now)
		end

		-- Someone walked round it: this is not cover any more.
		if not agent.peeking and now - agent.coverPhaseAt > 0.6 and not Cover.StillCovered(agent, info.position) then
			StateMachine.Set(agent, "Engage", now)
			return
		end

		if agent.reloadUntil then
			Body.SetStance(agent, false, false)
			moveIfAway(agent, point, "walk")
			return
		end

		local peek = agent.coverPeek
		if peek then
			if agent.peeking then
				moveIfAway(agent, point + peek, "walk", 0.8)
				Body.SetStance(agent, true, false)
				Body.AimAt(agent, info.root.Position + Vector3.new(0, 1, 0))
				Combat.Fire(agent, now, info.model, info.visible and now >= agent.coverPhaseAt + 0.3)
				if now - agent.coverPhaseAt > (agent.peekLength or 1.3) then
					agent.peeking = false
					agent.coverPhaseAt = now
					Combat.Fire(agent, now, nil, false)
				end
			else
				moveIfAway(agent, point, "walk", 0.8)
				Body.SetStance(agent, false, false)
				if now - agent.coverPhaseAt > 0.9 and weapon and (not weapon.ranged or weapon.ammo > 0) then
					agent.peeking = true
					agent.peekLength = 1.0 + math.random() * 0.8
					agent.coverPhaseAt = now
					agent.acquiredAt = now
				end
			end
		else
			-- Half cover: fight from where it stands, if there is anything to shoot at.
			Body.SetStance(agent, true, false)
			Body.AimAt(agent, info.root.Position + Vector3.new(0, 1, 0))
			Combat.Fire(agent, now, info.model, info.visible)
		end

		if agent.coverUntil and now >= agent.coverUntil and not agent.reloadUntil and not agent.peeking then
			StateMachine.Set(agent, "Engage", now)
		end
	end,
}

STATES.Reload = {
	enter = function(agent, now)
		Combat.StartReload(agent, now)
		-- Lower the weapon, and unless it is the charge-in type, step aside while doing it.
		Body.SetStance(agent, false, false)
		if agent.cfg.Behaviour ~= "Aggressive" and agent.cfg.Behaviour ~= "Brawler" then
			local side = agent.root.CFrame.RightVector * (math.random() < 0.5 and 6 or -6)
			local floor = World.GroundAt(agent.root.Position + side, 4, 8)
			if floor then
				agent.nav:MoveTo(floor.Position, "walk")
			end
		end
	end,
	update = function(agent, now, info)
		if info then
			Body.Face(agent, info.position)
		end
		if not agent.reloadUntil then
			local weapon = Combat.Current(agent)
			if weapon and weapon.ranged and weapon.ammo <= 0 then
				Combat.StartReload(agent, now)
				return
			end
			agent.fireReadyAt = now + (agent.cfg.AimTime or 0.25) * 0.5
			StateMachine.Set(agent, "Engage", now)
		end
	end,
}

STATES.Retreat = {
	enter = function(agent, now)
		agent.retreatedAt = now
		local info = agent.info
		local threat = info and info.position or agent.lastKnown
		local point: Vector3? = nil
		if threat and agent.cfg.UsesCover then
			point = Cover.Find(agent, threat, now)
		end
		if not point and threat then
			local away = World.Flat(agent.root.Position - threat)
			away = away.Magnitude > 0.1 and away.Unit or -World.Flat(agent.root.CFrame.LookVector)
			local floor = World.GroundAt(agent.root.Position + away * 22, 8, 14)
			point = floor and floor.Position or nil
		end
		agent.retreatPoint = point
	end,
	update = function(agent, now, info)
		local point = agent.retreatPoint
		if not point or now - agent.stateAt > 4 or failedSince(agent, agent.stateAt)
			or flatDistance(point, agent.root.Position) <= 3 then
			if agent.coverPoint then
				agent.coverForReload = false
				StateMachine.Set(agent, "TakeCover", now)
			else
				StateMachine.Set(agent, "Engage", now)
			end
			return
		end
		Body.SetStance(agent, false, true)
		Body.Face(agent, nil)
		agent.nav:MoveTo(point, "run")
		local weapon = Combat.Current(agent)
		if weapon and weapon.ranged and weapon.ammo < weapon.magazine * 0.6 then
			Combat.StartReload(agent, now)
		end
	end,
}

STATES.Reposition = {
	enter = function(agent, now)
		agent.shotsFromSpot = 0
		local info = agent.info
		agent.repositionPoint = info and sightlinePoint(agent, info) or nil
	end,
	update = function(agent, now, info)
		local point = agent.repositionPoint
		if not point or now - agent.stateAt > 5 or failedSince(agent, agent.stateAt)
			or flatDistance(point, agent.root.Position) <= 3 then
			agent.acquiredAt = now
			agent.fireReadyAt = now + (agent.cfg.AimTime or 0.25)
			StateMachine.Set(agent, "Engage", now)
			return
		end
		Body.SetStance(agent, false, true)
		Body.Face(agent, nil)
		agent.nav:MoveTo(point, "run")
	end,
}

STATES.Stunned = {
	enter = function(agent, now)
		agent.nav:Stop()
		Combat.CancelSwing(agent)
		Combat.Fire(agent, now, nil, false)
	end,
	update = function(agent, now, info)
		if now >= (agent.stunUntil or 0) then
			agent.stunUntil = nil
			agent.fireReadyAt = now + (agent.cfg.AimTime or 0.25) * 0.5
			StateMachine.Set(agent, info and "Engage" or "Idle", now)
		end
	end,
}

STATES.Dead = {
	update = function() end,
}

-- ------------------------------------------------------------------ think --

--- One decision. `agents` is every live NPC, for alerting allies.
function StateMachine.Think(agent, now: number, agents)
	if not agent.alive then
		return
	end
	Combat.Update(agent, now)
	local cfg = agent.cfg

	if agent.stunUntil and now < agent.stunUntil then
		if agent.state ~= "Stunned" then
			StateMachine.Set(agent, "Stunned", now)
		end
		return
	end

	-- Leash: dragged too far from its post, it lets go and walks back.
	local fromHome = flatDistance(agent.root.Position, agent.home)
	if fromHome > (cfg.LeashRange or 120) and agent.state ~= "Returning" then
		StateMachine.Disengage(agent)
		StateMachine.Set(agent, "Returning", now)
	end

	local info = Perception.TargetInfo(agent)
	if info and info.distance > (cfg.DeaggroRange or 90) then
		agent.memory[info.model] = nil
		agent.threat[info.model] = nil
		agent.target = nil
		info = nil
	end
	-- Walking home after the leash: ignore everything until properly back.
	if agent.state == "Returning" and fromHome > (cfg.LeashRange or 120) * 0.6 then
		info = nil
	end
	agent.info = info

	if info then
		agent.lastKnown = info.lastPosition
		agent.lastCombatAt = now
		if CALM[agent.state] then
			Squad.Alert(agent, info.model, info.position, now, agents)
			StateMachine.Set(agent, "Alert", now)
		end
	elseif COMBAT[agent.state] then
		StateMachine.Set(agent, agent.lastKnown and "Search" or "Returning", now)
	elseif agent.alert and now - agent.alert.at < 10
		and (agent.state == "Idle" or agent.state == "Patrol" or agent.state == "Returning") then
		StateMachine.Set(agent, "Investigate", now)
	end

	local state = STATES[agent.state]
	if state then
		state.update(agent, now, info)
	end
	agent.nav:Update(now)
end

--- Drop everything to do with the current fight.
function StateMachine.Disengage(agent)
	agent.target = nil
	agent.info = nil
	table.clear(agent.memory)
	table.clear(agent.threat)
	Squad.Leave(agent)
	Cover.Release(agent)
end

--- Everything stops, permanently.
function StateMachine.Kill(agent, now: number)
	StateMachine.Set(agent, "Dead", now)
	Combat.Stop(agent)
	Squad.Leave(agent)
	Cover.Release(agent)
	agent.nav:Destroy()
end

return StateMachine
