local module = {}
local Players = game:GetService("Players")

local PhysicsService = game:GetService("PhysicsService")

-- The group these limbs move to while ragdolled, so a loose body does not shove players
-- around or fight its own limbs. It was being used below without ever being registered,
-- which threw on the first death; registering it here is the fix.
local RAGDOLL_GROUP = "Ragdoll"
local ok = pcall(function()
	PhysicsService:RegisterCollisionGroup(RAGDOLL_GROUP)
end)
if ok then
	PhysicsService:CollisionGroupSetCollidable(RAGDOLL_GROUP, RAGDOLL_GROUP, false)
end

-- The torso part, whichever rig this is. R6 has one; R15 splits it and the lower half is
-- the one the root joint drives, so that is the half the ragdoll welds to.
local function torsoOf(char: Model): BasePart?
	return (char:FindFirstChild("LowerTorso") or char:FindFirstChild("Torso")) :: BasePart?
end

-- Which joints are allowed to go loose.
--
-- Every joint except Root needs an entry here, because going limp disables ALL the
-- Motor6Ds -- so a joint with no socket is not "rigid", it is DISCONNECTED. Leaving Waist
-- out to keep the torso stiff did exactly that: the upper half of the body came away from
-- the lower half and fell as a separate object. Root is the one exception, and only
-- because RagdollWeld welds the HumanoidRootPart to the LowerTorso by hand.
--
-- The waist is given a deliberately tight limit instead, which is what "stiff" actually
-- wants to mean.
local R15_SOCKETS = {
	Waist = { upper = 22, twist = 18 },
	Neck = { upper = 35, twist = 25 },
	LeftShoulder = { upper = 75, twist = 35 },
	RightShoulder = { upper = 75, twist = 35 },
	LeftElbow = { upper = 60, twist = 15 },
	RightElbow = { upper = 60, twist = 15 },
	LeftWrist = { upper = 30, twist = 15 },
	RightWrist = { upper = 30, twist = 15 },
	LeftHip = { upper = 60, twist = 25 },
	RightHip = { upper = 60, twist = 25 },
	LeftKnee = { upper = 55, twist = 10 },
	RightKnee = { upper = 55, twist = 10 },
	LeftAnkle = { upper = 25, twist = 10 },
	RightAnkle = { upper = 25, twist = 10 },
}

-- R15 needs no template parts. Every joint already carries the two frames a socket wants
-- -- its own C0 and C1 -- so the ragdoll is built from the rig itself. That is why there
-- is no R15 equivalent of RagdollParts: there is nothing left to author by hand, and a
-- hand-authored one would have to be redone for any rig change.
--
-- Named "...RagdollSocket" deliberately: ServerScriptService.RigNormalise strips the
-- engine's own "<Joint>BallSocket" rigging off R15 characters, and must not strip these.
local function buildR15Sockets(char: Model)
	for _, joint in ipairs(char:GetDescendants()) do
		local limits = joint:IsA("Motor6D") and R15_SOCKETS[joint.Name]
		if limits and joint.Part0 and joint.Part1 then
			local a0 = Instance.new("Attachment")
			a0.Name = joint.Name .. "RagdollAtt0"
			a0.CFrame = joint.C0
			a0.Parent = joint.Part0

			local a1 = Instance.new("Attachment")
			a1.Name = joint.Name .. "RagdollAtt1"
			a1.CFrame = joint.C1
			a1.Parent = joint.Part1

			local socket = Instance.new("BallSocketConstraint")
			socket.Name = joint.Name .. "RagdollSocket"
			socket.Attachment0 = a0
			socket.Attachment1 = a1
			socket.LimitsEnabled = true
			socket.TwistLimitsEnabled = true
			socket.UpperAngle = limits.upper
			socket.TwistLowerAngle = -limits.twist
			socket.TwistUpperAngle = limits.twist
			socket.Enabled = false
			socket.Parent = joint.Part1
		end
	end
end

-- The original R6 path, unchanged: the NPCs are still R6 rigs and still use these parts.
local function buildR6Sockets(char: Model)
	local clones = {}
	for _, v in pairs(script.Parent.RagdollParts:GetChildren()) do
		clones[v.Name] = v:Clone()
	end

	for _, v in pairs(clones) do
		if v:IsA("Attachment") then
			v.Parent = char[v:GetAttribute("Parent")]
		elseif v:IsA("BallSocketConstraint") then
			v.Parent = char.Torso
			v.Attachment0 = clones[v:GetAttribute("0")]
			v.Attachment1 = clones[v:GetAttribute("1")]
		else
			v.Part0 = char.HumanoidRootPart
			v.Part1 = char.Torso
			v.Parent = char.HumanoidRootPart
		end
	end
end

function module:Setup(char: Model)
	-- Player characters used to be rejected here on the assumption that something else
	-- handled them. Nothing did, so players simply never ragdolled; they are set up the
	-- same way as everything else now.
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	assert(humanoid, "No Humanoid was found in the provided rig")
	assert(humanoid.RootPart ~= nil, "No RootPart was found in the provided rig")
	assert(char:FindFirstChild("HumanoidRootPart"), "No HumanoidRootPart was found in the provided rig")
	assert(torsoOf(char), "No torso was found in the provided rig")

	-- Setting up twice would stack a second set of sockets on every joint, and the second
	-- set fights the first. Both the spawn hook and CombatDeath ask for this, so it has to
	-- be safe to ask twice.
	if char:FindFirstChild("RagdollTrigger") then
		return
	end

	-- Roblox destroys every Motor6D the moment a humanoid dies, which would take the
	-- ragdoll's joints with it and leave a pile of loose bricks instead of a body.
	humanoid.BreakJointsOnDeath = false
	-- R15 severs at the neck when that joint goes loose, and a humanoid with RequiresNeck
	-- set kills itself the moment that happens -- mid-ragdoll, which respawns the corpse.
	humanoid.RequiresNeck = false

	-- Network ownership is deliberately NOT touched here. Handing the limbs to the server
	-- at setup time froze every player the instant they spawned: a character the client does
	-- not own cannot be moved by the client, so a perfectly healthy humanoid with WalkSpeed
	-- 16 went nowhere, and even a direct Humanoid:Move() moved it 0.00 studs. The server only
	-- needs to own the limbs once they are actually a ragdoll, so that now happens in
	-- module:Ragdoll and is handed back in module:Unragdoll.
	--
	-- This was invisible until R15, because Setup used to reject non-R6 rigs before reaching
	-- the line that did it.

	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		buildR6Sockets(char)
	else
		buildR15Sockets(char)
	end

	-- Ragdoll trigger
	local trigger = Instance.new("BoolValue")
	trigger.Name = "RagdollTrigger"
	trigger.Parent = char

	trigger.Changed:Connect(function(bool)
		if bool then
			module:Ragdoll(char)
		else
			module:Unragdoll(char)
		end
	end)
end

function module:Ragdoll(char: Model)
	local hrp = char.HumanoidRootPart
	local humanoid = char.Humanoid
	local torso = torsoOf(char)
	if not torso then
		return
	end
	local weld = hrp:FindFirstChild("RagdollWeld")
	if not weld then
		weld = Instance.new("WeldConstraint")
		weld.Name = "RagdollWeld"
		weld.Part0 = hrp
		weld.Part1 = torso
		weld.Parent = hrp
	end

	weld.Enabled = true
	hrp.CanCollide = false
	humanoid.AutoRotate = false
	-- Only while it is still alive. A dead humanoid is forced straight back out of Physics
	-- into Dead, and that re-fires Humanoid.Died -- which ragdolls it again, which sets
	-- Physics again. Dead already gives up motor control, so the constraints do the work
	-- here and the state does not need touching at all.
	if humanoid.Health > 0 then
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	end

	-- The server simulates the corpse, so it takes the limbs here -- and only here.
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				part:SetNetworkOwner(nil)
			end)
		end
	end
	for i, v in pairs(char:GetDescendants()) do
		if v:IsA("BasePart") then
			v.CollisionGroup = RAGDOLL_GROUP     -- SetPartCollisionGroup is deprecated
		elseif v:IsA("Motor6D") then
			v.Enabled = false
		elseif v:IsA("BallSocketConstraint") then
			v.Enabled = true
		end
	end

	hrp:ApplyAngularImpulse(Vector3.new(90, 0, 0))
end

function module:Unragdoll(char: Model)
	local hrp = char.HumanoidRootPart
	local humanoid = char.Humanoid
	local weld = hrp.RagdollWeld

	weld.Enabled = false
	hrp.CanCollide = true
	humanoid.AutoRotate = true
	humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)

	-- Give the limbs back, or the player stands up unable to move.
	local owner = Players:GetPlayerFromCharacter(char)
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") then
			pcall(function()
				if owner then
					part:SetNetworkOwner(owner)
				else
					part:SetNetworkOwnershipAuto()
				end
			end)
		end
	end
	for i, v in pairs(char:GetDescendants()) do
		if v:IsA("BasePart") then
			v.CollisionGroup = "Default"
		elseif v:IsA("Motor6D") then
			v.Enabled = true
		elseif v:IsA("BallSocketConstraint") then
			v.Enabled = false
		end
	end
end

return module
