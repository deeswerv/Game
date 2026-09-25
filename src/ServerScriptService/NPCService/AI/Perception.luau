--!strict
-- What an NPC knows: who it can see, who it heard, who hurt it, and which of them to fight.
--
-- Knowledge is held as MEMORY, not as a live lookup. Every other system asks "where do I
-- think they are?", never "where are they?", which is what stops an enemy tracking you
-- through a wall: once you break line of sight it only has the last place it saw you, and
-- that goes stale after MemoryTime.

local Players = game:GetService("Players")
local World = require(script.Parent.Parent.World)

local Perception = {}

-- How long a chosen target is kept before a better one may replace it. Without this an
-- enemy between two players flicks its aim back and forth every tick, which reads as a bug
-- rather than a decision.
local TARGET_LOCK = 2.5

-- How far along their last known movement a lost target is assumed to have gone.
local LEAD_SECONDS = 0.6

local function eyeOf(model: Model): Vector3
	local head = model:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		return head.Position
	end
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	return root.Position + Vector3.new(0, 1.5, 0)
end
Perception.EyeOf = eyeOf

local AIM_PARTS = { "Head", "UpperTorso", "Torso", "HumanoidRootPart" }

--- Line of sight from this NPC's eyes to any of the target's body. At most two rays: the
--- head, then the chest -- someone crouched behind a crate with their head showing is seen.
function Perception.CanSee(agent, target: Model): (boolean, Vector3?)
	local eye = eyeOf(agent.model)
	local params = World.SightParams()
	local cast = 0
	for _, name in ipairs(AIM_PARTS) do
		local part = target:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			cast += 1
			local hit = workspace:Raycast(eye, part.Position - eye, params)
			if not hit or hit.Instance:IsDescendantOf(target) then
				return true, part.Position
			end
			if cast >= 2 then
				break
			end
		end
	end
	return false, nil
end

local function memoryFor(agent, model: Model, now: number)
	local entry = agent.memory[model]
	if not entry then
		entry = { firstSeen = now, lastSeen = -math.huge, lastKnown = now, visible = false }
		agent.memory[model] = entry
	end
	return entry
end

--- Look around. `candidates` is every living thing this NPC's faction fights.
function Perception.Update(agent, now: number, candidates)
	local cfg = agent.cfg
	local root = agent.root
	local position = root.Position

	-- Weather shortens how far anything can notice anything. Read from the shared
	-- attribute rather than each agent deciding, so every NPC agrees what the fog is like.
	local weather = workspace:GetAttribute("WeatherSight")
	local range = cfg.AggroRange * (type(weather) == "number" and weather or 1)

	-- Once a fight has started it is looking for you everywhere, not just straight ahead.
	local alert = now - (agent.lastCombatAt or -math.huge) < 8
	if alert then
		range *= 1.2
	end
	local look = root.CFrame.LookVector
	local flatLook = Vector3.new(look.X, 0, look.Z)
	flatLook = flatLook.Magnitude > 0.01 and flatLook.Unit or Vector3.new(0, 0, -1)
	local fovCos = math.cos(math.rad((cfg.FieldOfView or 150) / 2))

	for _, candidate in ipairs(candidates) do
		local model = candidate.model
		if model ~= agent.model and candidate.root.Parent then
			local offset = candidate.root.Position - position
			local distance = offset.Magnitude
			if distance <= range then
				local flat = Vector3.new(offset.X, 0, offset.Z)
				local inView = alert
					or distance <= (cfg.HearingRange or 14)
					or flat.Magnitude < 0.01
					or flat.Unit:Dot(flatLook) >= fovCos
				if inView then
					local seen = not cfg.RequiresLineOfSight or Perception.CanSee(agent, model)
					if seen then
						local entry = memoryFor(agent, model, now)
						-- A fresh sighting after losing them resets how long it has been
						-- looking at them, which is what the aim settle reads.
						if now - entry.lastSeen > (cfg.MemoryTime or 6) then
							entry.firstSeen = now
						end
						entry.lastSeen = now
						entry.lastKnown = now
						entry.position = candidate.root.Position
						entry.velocity = candidate.root.AssemblyLinearVelocity
						entry.visible = true
						entry.seenThisPass = true
					end
				end
			end
		end
	end

	for model, entry in pairs(agent.memory) do
		if entry.seenThisPass then
			entry.seenThisPass = nil
		else
			entry.visible = false
		end
		local humanoid = model.Parent and model:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 or now - entry.lastKnown > (cfg.MemoryTime or 6) then
			agent.memory[model] = nil
			agent.threat[model] = nil
		end
	end
end

--- Something hurt us, or an ally called it out: we know roughly where it is without having
--- seen it.
function Perception.Hear(agent, model: Model, position: Vector3, now: number)
	if model == agent.model then
		return
	end
	local entry = memoryFor(agent, model, now)
	entry.lastKnown = now
	-- Do not overwrite a position we are actually looking at with a vaguer one.
	if not entry.visible then
		entry.position = position
		entry.velocity = Vector3.zero
	end
end

--- Record damage from `model`, decaying older damage so a player who shot it once a minute
--- ago does not outrank the one shooting it now.
function Perception.NoteThreat(agent, model: Model, amount: number, now: number)
	local entry = agent.threat[model]
	if entry then
		entry.amount = entry.amount * math.exp(-(now - entry.at) / 6) + amount
		entry.at = now
	else
		agent.threat[model] = { amount = amount, at = now }
	end
end

--- Pick who to fight. In order of weight: whoever is hurting us, whoever we can see, whoever
--- is closest, whoever is already in range -- with a lock so the choice sticks.
function Perception.ChooseTarget(agent, now: number): Model?
	local cfg = agent.cfg
	local position = agent.root.Position
	local current = agent.target
	local best, bestScore = nil, -math.huge
	local currentScore = -math.huge

	for model, entry in pairs(agent.memory) do
		-- A memory already chased to its end and found empty is not worth chasing again
		-- until something new -- a sighting, a shot -- refreshes it.
		local exhausted = entry.searchedAt ~= nil and entry.lastKnown <= entry.searchedAt
		if model.Parent and entry.position and not exhausted then
			local score = 0
			local threat = agent.threat[model]
			if threat then
				local age = now - threat.at
				if age < 6 then
					score += 100 + math.min(threat.amount, 100)
				end
				if age < 2 then
					score += 40
				end
			end
			if entry.visible then
				score += 40
			end
			local distance = (entry.position - position).Magnitude
			score += (1 - math.clamp(distance / math.max(cfg.AggroRange, 1), 0, 1)) * 30
			if distance <= cfg.AttackRange then
				score += 15
			end
			if model == current then
				score += 25
				currentScore = score
			end
			if score > bestScore then
				best, bestScore = model, score
			end
		end
	end

	local currentValid = current ~= nil and currentScore > -math.huge
	-- Hold on to the current target through the lock, and after it switch only for something
	-- clearly better, not a rounding difference.
	if currentValid and best ~= current then
		if now < (agent.targetSince or 0) + TARGET_LOCK or bestScore < currentScore + 20 then
			return current
		end
	end

	if best ~= current then
		agent.target = best
		agent.targetSince = now
	end
	return best
end

--- Everything the AI needs to know about its target this tick, or nil.
function Perception.TargetInfo(agent)
	local model = agent.target
	if not model or not model.Parent then
		return nil
	end
	local entry = agent.memory[model]
	local root = model:FindFirstChild("HumanoidRootPart")
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not entry or not entry.position or not root or not root:IsA("BasePart")
		or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local lastPosition = entry.position
	-- Only a target we can see has a live position. Everything else is a memory, pushed a
	-- little way along the direction they were last moving.
	local position = entry.visible and root.Position
		or lastPosition + World.Flat(entry.velocity or Vector3.zero) * LEAD_SECONDS
	local offset = position - agent.root.Position
	local look = World.Flat(root.CFrame.LookVector)
	return {
		model = model,
		root = root,
		entry = entry,
		visible = entry.visible,
		position = position,
		lastPosition = lastPosition,
		distance = offset.Magnitude,
		look = look.Magnitude > 0.01 and look.Unit or Vector3.new(0, 0, -1),
		isPlayer = Players:GetPlayerFromCharacter(model) ~= nil,
	}
end

return Perception
