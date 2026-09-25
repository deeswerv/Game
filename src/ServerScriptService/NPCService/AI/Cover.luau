--!strict
-- Finding somewhere to stand that a bullet cannot reach.
--
-- Cover is anything solid between the NPC's chest and the threat's eyes, close enough to
-- the spot to be the thing hiding it. Two sources of candidates:
--
--   * Parts tagged "Cover" (CollectionService) -- a spot is proposed directly behind each,
--     on the side away from the threat. Tag crates, barricades and vehicles to make them
--     first choices.
--   * A ring of samples around the NPC, so ordinary walls, pillars, rocks and trees work
--     with no setup at all.
--
-- A spot that also has a clear line to the threat from a step to one side is preferred:
-- that is cover you can fight from, rather than cover you can only hide behind.
--
-- Searches are rationed per NPC and capped in rays, and a spot one NPC has claimed is not
-- offered to another.

local CollectionService = game:GetService("CollectionService")
local World = require(script.Parent.Parent.World)

local Cover = {}

Cover.Tag = "Cover"

local SEARCH_COOLDOWN = 2.5
local TAG_RADIUS = 45
local RING_RADII = { 8, 15 }
local RING_SAMPLES = 10
local MAX_RAYS = 64
local PEEK_STEP = 2.4
local CHEST = 2.6
local CLAIM_RADIUS = 4
local BODY = Vector3.new(2.2, 4.6, 2.2)

local claims: { [any]: Vector3 } = {}

local function claimedByOther(agent, point: Vector3): boolean
	for other, claimed in pairs(claims) do
		if other ~= agent and other.alive and World.Flat(claimed - point).Magnitude < CLAIM_RADIUS then
			return true
		end
	end
	return false
end

function Cover.Release(agent)
	claims[agent] = nil
	agent.coverPoint = nil
	agent.coverPeek = nil
end

--- The best nearby cover from `threat`, and the sideways step that lets it shoot from
--- there (nil if it can only hide). Returns nil when there is nothing worth moving to.
function Cover.Find(agent, threat: Vector3, now: number): (Vector3?, Vector3?)
	if now - (agent.coverSearchAt or -math.huge) < SEARCH_COOLDOWN then
		return agent.coverPoint, agent.coverPeek
	end
	agent.coverSearchAt = now

	local origin = agent.root.Position
	local candidates: { Vector3 } = {}

	for _, part in ipairs(CollectionService:GetTagged(Cover.Tag)) do
		if part:IsA("BasePart") and (part.Position - origin).Magnitude < TAG_RADIUS then
			local away = World.Flat(part.Position - threat)
			if away.Magnitude > 0.1 then
				local dir = away.Unit
				local depth = (math.abs(dir:Dot(part.CFrame.RightVector)) * part.Size.X
					+ math.abs(dir:Dot(part.CFrame.LookVector)) * part.Size.Z) / 2
				table.insert(candidates, part.Position + dir * (depth + 2))
			end
		end
	end
	for ring, radius in ipairs(RING_RADII) do
		for i = 0, RING_SAMPLES - 1 do
			local angle = (i / RING_SAMPLES) * math.pi * 2 + ring * 0.31
			table.insert(candidates, origin + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius))
		end
	end
	table.sort(candidates, function(a, b)
		return (a - origin).Magnitude < (b - origin).Magnitude
	end)

	local sight = World.SightParams()
	local eye = threat + Vector3.new(0, 1.5, 0)
	local myDistance = World.Flat(origin - threat).Magnitude
	local rays = 0
	local best: Vector3?, bestPeek: Vector3? = nil, nil
	local bestScore = -math.huge

	for _, candidate in ipairs(candidates) do
		if rays >= MAX_RAYS then
			break
		end
		local floor = World.GroundAt(candidate, 6, 10)
		rays += 1
		if floor and not claimedByOther(agent, floor.Position) and not agent.nav:RecentlyFailed(floor.Position) then
			local stand = floor.Position
			local chest = stand + Vector3.new(0, CHEST, 0)
			local towardThreat = World.Flat(threat - stand)
			if towardThreat.Magnitude > 8 then
				local block = workspace:Raycast(eye, chest - eye, sight)
				rays += 1
				-- Hidden, by something right next to the spot rather than a hill halfway to the
				-- threat that stops hiding it after two steps -- and actually standable: a
				-- sample that lands inside a pillar grounds on the floor beneath it and looks
				-- like perfect cover.
				if block and not World.CharacterOf(block.Instance) and (block.Position - chest).Magnitude < 6
					and World.IsClear(stand, BODY) then
					local side = towardThreat.Unit:Cross(Vector3.yAxis)
					local peek: Vector3? = nil
					for _, sign in ipairs({ 1, -1 }) do
						local step = side * PEEK_STEP * sign
						local from = chest + step
						local open = workspace:Raycast(from, eye - from, sight)
						rays += 1
						if not open or World.CharacterOf(open.Instance) then
							peek = step
							break
						end
					end
					local score = -(stand - origin).Magnitude + (peek and 12 or 0)
					-- A careful NPC does not run TOWARDS the threat to reach cover.
					if towardThreat.Magnitude < myDistance - 6 and (agent.cfg.Aggression or 0.5) < 0.7 then
						score -= 15
					end
					if score > bestScore then
						best, bestPeek, bestScore = stand, peek, score
					end
					if peek and score > -12 then
						break                 -- close, and fightable: good enough
					end
				end
			end
		end
	end

	agent.coverPoint, agent.coverPeek = best, bestPeek
	if best then
		claims[agent] = best
	else
		claims[agent] = nil
	end
	return best, bestPeek
end

--- Is the spot still hiding us from `threat`? Cover stops being cover when someone walks
--- around it.
function Cover.StillCovered(agent, threat: Vector3): boolean
	local point = agent.coverPoint
	if not point then
		return false
	end
	local eye = threat + Vector3.new(0, 1.5, 0)
	local chest = point + Vector3.new(0, CHEST, 0)
	local block = workspace:Raycast(eye, chest - eye, World.SightParams())
	return block ~= nil and not World.CharacterOf(block.Instance)
end

return Cover
