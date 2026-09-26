--!strict
-- Enemies fighting the same person, fighting as a group.
--
-- Deliberately small. There is no squad leader and no plan -- just three rules that are
-- enough to stop a crowd reading as a crowd:
--
--   1. Everyone engaging one target has a ROLE. Brawlers and aggressive types push, keepers
--      hold at range, balanced ones split between holding and flanking, tactical ones flank.
--      No more than two push at once; the rest find something else to do -- unless the
--      target is reloading or badly hurt, when everyone with any nerve pushes at once.
--   2. Everyone gets their own SLOT around the target, spread by rank so two enemies never
--      want the same patch of ground, pulled in short of any wall between them and it.
--   3. Seeing someone is shared. An NPC that spots a player calls it out to nearby allies,
--      which turn to investigate rather than standing idle ten studs from a firefight.

local World = require(script.Parent.Parent.World)

local Squad = {}

local SLOT_REFRESH = 1.5          -- seconds a slot is kept before it is worked out again
local SLOT_TARGET_DRIFT = 8       -- or sooner, if the target moved this far
local SPREAD = math.rad(30)       -- angle between neighbours around the target
local MAX_PUSHERS = 2
local ALERT_RADIUS = 70
local ALERT_COOLDOWN = 1.5
local SEPARATION = 4

local engaged: { [Model]: { any } } = {}

local function members(target: Model): { any }
	local list = engaged[target]
	if not list then
		return {}
	end
	-- Prune anything that died, left, or moved on since it joined.
	for i = #list, 1, -1 do
		local other = list[i]
		if not other.alive or other.squadTarget ~= target then
			table.remove(list, i)
		end
	end
	return list
end

function Squad.Join(agent, target: Model)
	if agent.squadTarget == target then
		return
	end
	Squad.Leave(agent)
	local list = engaged[target]
	if not list then
		list = {}
		engaged[target] = list
	end
	table.insert(list, agent)
	-- Stable rank by spawn order, so roles do not reshuffle every time someone joins.
	table.sort(list, function(a, b)
		return a.id < b.id
	end)
	agent.squadTarget = target
	agent.slotPoint = nil
end

function Squad.Leave(agent)
	local target = agent.squadTarget
	if not target then
		return
	end
	local list = engaged[target]
	if list then
		local index = table.find(list, agent)
		if index then
			table.remove(list, index)
		end
		if #list == 0 then
			engaged[target] = nil
		end
	end
	agent.squadTarget = nil
	agent.role = nil
	agent.slotPoint = nil
end

-- A target caught out: reloading (its equipped gun says so) or badly hurt. The moment to
-- push, and everyone who is not a sniper takes it -- which is what makes a reload in the
-- open a mistake rather than a formality.
local PUNISH_HEALTH = 0.35
local function vulnerable(target: Model?): boolean
	if not target then
		return false
	end
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.MaxHealth > 0 and humanoid.Health / humanoid.MaxHealth <= PUNISH_HEALTH then
		return true
	end
	local tool = target:FindFirstChildOfClass("Tool")
	return tool ~= nil and tool:GetAttribute("Reloading") == true
end
Squad.Vulnerable = vulnerable

local function roleFor(agent, list, target: Model?): string
	local behaviour = agent.cfg.Behaviour
	if behaviour == "Keeper" then
		return "Overwatch"
	elseif behaviour == "Brawler" then
		return "Push"
	end
	if vulnerable(target) and (agent.cfg.Aggression or 0.5) >= 0.5 then
		return "Push"
	end
	local pushers = 0
	for _, other in ipairs(list) do
		if other ~= agent and other.role == "Push" then
			pushers += 1
		end
	end
	if behaviour == "Aggressive" then
		return pushers < MAX_PUSHERS and "Push" or "Flank"
	elseif behaviour == "Tactical" then
		return "Flank"
	end
	local rank = table.find(list, agent) or 1
	return rank % 2 == 1 and "Hold" or "Flank"
end

local function wrap(angle: number): number
	return (angle + math.pi) % (2 * math.pi) - math.pi
end

-- Ground the slot, keep it on this side of any wall, and keep it off anyone else's.
local function settle(agent, point: Vector3, targetPos: Vector3, list): Vector3
	local from = targetPos + Vector3.new(0, 2, 0)
	local to = Vector3.new(point.X, targetPos.Y + 2, point.Z)
	local hit = workspace:Raycast(from, to - from, World.GroundParams())
	if hit then
		local back = (to - from).Unit * 2.5
		point = Vector3.new(hit.Position.X - back.X, point.Y, hit.Position.Z - back.Z)
	end

	for _, other in ipairs(list) do
		if other ~= agent and other.slotPoint then
			local gap = World.Flat(point - other.slotPoint)
			if gap.Magnitude < SEPARATION then
				local push = gap.Magnitude > 0.1 and gap.Unit or World.Flat(agent.root.CFrame.RightVector)
				point += push * (SEPARATION - gap.Magnitude)
			end
		end
	end

	local floor = World.GroundAt(point, 8, 20)
	if floor then
		return floor.Position
	end
	-- Nothing to stand on out there: fall back towards the target along the same line.
	return targetPos:Lerp(point, 0.5)
end

--- Where this NPC should be fighting from, relative to its target.
function Squad.SlotFor(agent, info, now: number): Vector3
	local target = info.model
	local targetPos = info.position
	-- A slot is kept a moment -- unless the target has just left themselves open, which is
	-- worth rethinking for straight away.
	local caughtOut = vulnerable(target) and agent.role ~= "Push" and agent.role ~= "Overwatch"
	if not caughtOut and agent.slotPoint and agent.slotTargetPos and now - (agent.slotAt or 0) < SLOT_REFRESH
		and World.Flat(agent.slotTargetPos - targetPos).Magnitude < SLOT_TARGET_DRIFT then
		return agent.slotPoint
	end

	local list = members(target)
	local role = roleFor(agent, list, target)
	agent.role = role
	local cfg = agent.cfg

	local distance: number
	if role == "Push" then
		distance = cfg.Ranged and math.max(10, (cfg.PreferredRange or 16) * 0.6)
			or math.max(2.5, cfg.AttackRange * 0.6)
	elseif role == "Overwatch" then
		distance = cfg.PreferredRange or 55
	elseif role == "Flank" then
		distance = (cfg.PreferredRange or 24) * 0.8
	else
		distance = cfg.PreferredRange or 30
	end

	-- The group's shared bearing from the target, so neighbours spread around ONE line of
	-- approach rather than each around their own.
	local centroid = Vector3.zero
	for _, other in ipairs(list) do
		centroid += other.root.Position
	end
	centroid = #list > 0 and centroid / #list or agent.root.Position
	local shared = World.Flat(centroid - targetPos)
	local mine = World.Flat(agent.root.Position - targetPos)
	local baseAngle = shared.Magnitude > 0.1 and math.atan2(shared.Z, shared.X)
		or math.atan2(mine.Z, mine.X)

	local angle: number
	if role == "Flank" then
		-- Out to the side the target is NOT facing, a little further each refresh rather
		-- than teleporting the slot a quarter turn round in one go.
		local facing = math.atan2(info.look.Z, info.look.X)
		local side = (agent.id % 2 == 0) and 1 or -1
		local wanted = facing + side * math.rad(100)
		local current = mine.Magnitude > 0.1 and math.atan2(mine.Z, mine.X) or baseAngle
		angle = current + math.clamp(wrap(wanted - current), -math.rad(45), math.rad(45))
	else
		local rank = table.find(list, agent) or 1
		angle = baseAngle + (rank - (#list + 1) / 2) * SPREAD
	end

	local point = targetPos + Vector3.new(math.cos(angle), 0, math.sin(angle)) * distance
	point = settle(agent, point, targetPos, list)
	if agent.nav:RecentlyFailed(point) then
		-- That spot could not be reached a moment ago; try a quarter turn round.
		local turned = targetPos + Vector3.new(math.cos(angle + math.pi / 2), 0, math.sin(angle + math.pi / 2)) * distance
		point = settle(agent, turned, targetPos, list)
	end

	agent.slotPoint = point
	agent.slotAt = now
	agent.slotTargetPos = targetPos
	return point
end

--- Tell nearby allies what we saw. They investigate; they do not get a free lock-on.
function Squad.Alert(agent, target: Model, position: Vector3, now: number, agents)
	if now - (agent.lastAlertAt or -math.huge) < ALERT_COOLDOWN then
		return
	end
	agent.lastAlertAt = now
	local origin = agent.root.Position
	for _, other in pairs(agents) do
		if other ~= agent and other.alive and other.cfg.Faction == agent.cfg.Faction
			and (other.root.Position - origin).Magnitude <= ALERT_RADIUS
			and not other.target then
			other.alert = { model = target, position = position, at = now }
		end
	end
end

return Squad
