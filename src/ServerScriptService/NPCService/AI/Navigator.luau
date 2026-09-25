--!strict
-- Getting an NPC from here to there without walking into things.
--
-- One Path object per NPC, reused. Paths are computed off the AI tick in their own thread
-- and only when something actually changed: a new destination, a destination that has
-- drifted, a path that reports itself blocked, or an NPC that has stopped making progress.
-- Short, clear, level moves skip pathfinding altogether and walk straight there.
--
-- "Stuck" is measured, not guessed: if an NPC that is supposed to be moving has covered a
-- fraction of the ground its speed says it should, it escalates -- jump, then force a real
-- path, then sidestep -- and finally gives the destination up for a few seconds so the
-- brain picks somewhere else instead of walking into the same wall forever.

local PathfindingService = game:GetService("PathfindingService")
local World = require(script.Parent.Parent.World)

local Navigator = {}
Navigator.__index = Navigator

local ARRIVE = 2.4               -- close enough to call a waypoint reached
local DIRECT_MAX = 26            -- longest move that may skip pathfinding
local REPATH_DRIFT = 6           -- destination moved this far: plan again
local REPATH_MIN_GAP = 0.7       -- but not more often than this
local REISSUE = 2.5              -- Humanoid:MoveTo gives up after 8s; refresh well before
local STUCK_WINDOW = 1.0
local FAIL_MEMORY = 5            -- seconds a failed destination is avoided

-- Speeds as a share of the archetype's full pace. The client matches the walk and run
-- animations to the speed that actually results, so these can be tuned freely.
Navigator.Pace = { run = 1, walk = 0.45, creep = 0.32 }

function Navigator.new(agent)
	local self = setmetatable({}, Navigator)
	local scale = agent.scale or 1
	self.agent = agent
	self.path = PathfindingService:CreatePath({
		AgentRadius = 1.4 * scale,
		AgentHeight = 5.2 * scale,
		AgentCanJump = true,
		AgentCanClimb = false,
		WaypointSpacing = 5,
		Costs = { Water = 20 },
	})
	self.goal = nil :: Vector3?
	self.waypoints = nil :: { PathWaypoint }?
	self.index = 0
	self.direct = false
	self.computing = false
	self.replan = false
	self.requestId = 0
	self.lastCompute = -math.huge
	self.lastIssue = -math.huge
	self.progressAt = 0
	self.progressPos = nil :: Vector3?
	self.stuck = 0
	self.forcePath = false
	self.failedGoal = nil :: Vector3?
	self.failedAt = -math.huge
	self.arrivedAt = -math.huge

	self.blockedConn = self.path.Blocked:Connect(function(blockedIndex: number)
		if self.waypoints and blockedIndex >= self.index and self.goal then
			self.forcePath = true
			self:_plan(os.clock())
		end
	end)
	return self
end

local function horizontal(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function lineIsClear(from: Vector3, to: Vector3): boolean
	local params = World.GroundParams()
	-- Knee height catches crates and low walls; chest height catches railings and beams.
	for _, lift in ipairs({ -1.6, 0.8 }) do
		local a = from + Vector3.new(0, lift, 0)
		local b = Vector3.new(to.X, from.Y + lift, to.Z)
		if workspace:Raycast(a, b - a, params) then
			return false
		end
	end
	-- And the far end has to have a floor under it.
	return World.GroundAt(to, 4, 10) ~= nil
end

function Navigator:SetPace(pace: string)
	local agent = self.agent
	local share = Navigator.Pace[pace] or 1
	local speed = agent.cfg.WalkSpeed * share
	if math.abs(agent.humanoid.WalkSpeed - speed) > 0.05 then
		agent.humanoid.WalkSpeed = speed
	end
end

--- Was `point` recently a destination we could not reach?
function Navigator:RecentlyFailed(point: Vector3): boolean
	return self.failedGoal ~= nil
		and os.clock() - self.failedAt < FAIL_MEMORY
		and horizontal(self.failedGoal :: Vector3, point) < 4
end

function Navigator:IsMoving(): boolean
	return self.goal ~= nil
end

function Navigator:MoveTo(destination: Vector3, pace: string?)
	self:SetPace(pace or "run")
	local now = os.clock()
	local goal = self.goal
	if goal then
		local drift = horizontal(goal, destination)
		if drift < 1.5 then
			return
		end
		-- Small drift on a live path: keep following it and just move the end point.
		if drift < REPATH_DRIFT and (self.waypoints or self.direct or self.computing) and now - self.lastCompute < 1.5 then
			self.goal = destination
			if self.direct then
				self.agent.humanoid:MoveTo(destination)
				self.lastIssue = now
			end
			return
		end
		if now - self.lastCompute < REPATH_MIN_GAP and (self.waypoints or self.computing) then
			self.goal = destination
			return
		end
	end
	self.goal = destination
	self:_plan(now)
end

function Navigator:_plan(now: number)
	local agent = self.agent
	local goal = self.goal
	if not goal or not agent.alive then
		return
	end
	local from = agent.root.Position
	self.lastCompute = now
	self.progressAt = now
	self.progressPos = from

	local offset = goal - from
	if not self.forcePath and horizontal(goal, from) < DIRECT_MAX and math.abs(offset.Y) < 4
		and lineIsClear(from, goal) then
		self.direct = true
		self.waypoints = nil
		self.requestId += 1
		agent.humanoid:MoveTo(goal)
		self.lastIssue = now
		return
	end

	self.forcePath = false
	self.direct = false
	self.requestId += 1
	local id = self.requestId
	if self.computing then
		-- The running compute will see its id is stale and plan again when it lands.
		self.replan = true
		return
	end
	self.computing = true
	task.spawn(function()
		local ok = pcall(function()
			self.path:ComputeAsync(from, goal)
		end)
		self.computing = false
		if not agent.alive then
			return
		end
		if self.replan then
			self.replan = false
			if self.goal then
				self.forcePath = true
				self:_plan(os.clock())
			end
			return
		end
		if id ~= self.requestId or not self.goal then
			return
		end
		if ok and self.path.Status == Enum.PathStatus.Success then
			self.waypoints = self.path:GetWaypoints()
			self.index = 2
			self:_follow(os.clock(), true)
		else
			-- No route. Walk straight at it and let stuck detection sort it out.
			self.waypoints = nil
			self.direct = true
			agent.humanoid:MoveTo(self.goal)
			self.lastIssue = os.clock()
		end
	end)
end

function Navigator:_follow(now: number, force: boolean?)
	local waypoints = self.waypoints
	if not waypoints then
		return
	end
	local agent = self.agent
	local position = agent.root.Position
	local advanced = force == true
	while self.index <= #waypoints and horizontal(waypoints[self.index].Position, position) <= ARRIVE do
		self.index += 1
		advanced = true
	end
	local waypoint = waypoints[self.index]
	if not waypoint then
		-- Path used up; finish the last stretch to the live goal directly.
		self.waypoints = nil
		self.direct = true
		if self.goal then
			agent.humanoid:MoveTo(self.goal)
			self.lastIssue = now
		end
		return
	end
	if advanced or now - self.lastIssue > REISSUE then
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			agent.humanoid.Jump = true
		end
		agent.humanoid:MoveTo(waypoint.Position)
		self.lastIssue = now
	end
end

function Navigator:Update(now: number)
	local agent = self.agent
	local goal = self.goal
	if not agent.alive or not goal then
		return
	end
	local position = agent.root.Position

	if horizontal(goal, position) <= ARRIVE then
		self:Stop()
		self.arrivedAt = now
		return
	end

	if self.waypoints then
		self:_follow(now)
		-- The destination walked away from the end of the path.
		local waypoints = self.waypoints
		local last = waypoints and waypoints[#waypoints]
		if last and horizontal(last.Position, goal) > REPATH_DRIFT and now - self.lastCompute > REPATH_MIN_GAP then
			self:_plan(now)
		end
	elseif self.direct and now - self.lastIssue > 0.6 then
		agent.humanoid:MoveTo(goal)
		self.lastIssue = now
	end

	-- Progress check.
	if now - self.progressAt >= STUCK_WINDOW then
		local moved = self.progressPos and horizontal(position, self.progressPos) or math.huge
		local expected = agent.humanoid.WalkSpeed * (now - self.progressAt)
		if not self.computing and moved < math.max(0.8, expected * 0.2) then
			self.stuck += 1
			if self.stuck == 1 then
				agent.humanoid.Jump = true
			elseif self.stuck == 2 then
				self.forcePath = true
				self:_plan(now)
			elseif self.stuck <= 4 then
				local side = agent.root.CFrame.RightVector * ((self.stuck % 2 == 0) and 5 or -5)
				agent.humanoid:MoveTo(position + side)
				self.lastIssue = now + 0.6
			else
				-- Give it up. The brain sees nothing to follow and chooses again.
				self.failedGoal = goal
				self.failedAt = now
				self:Stop()
			end
		else
			self.stuck = 0
		end
		self.progressAt = now
		self.progressPos = position
	end
end

function Navigator:Stop()
	local wasMoving = self.goal ~= nil
	self.goal = nil
	self.waypoints = nil
	self.direct = false
	self.stuck = 0
	self.requestId += 1
	-- Only when there was somewhere to stop going. The brain calls this every tick while an
	-- NPC stands and fights, and re-issuing a MoveTo each time would be wasted work.
	local agent = self.agent
	if wasMoving and agent.alive and agent.root.Parent then
		agent.humanoid:MoveTo(agent.root.Position)
	end
end

function Navigator:Destroy()
	self.goal = nil
	self.waypoints = nil
	self.requestId += 1
	if self.blockedConn then
		self.blockedConn:Disconnect()
	end
	self.path:Destroy()
end

return Navigator
