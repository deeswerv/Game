--!nocheck
-- The game's own character rig, in the harness, with working joints -- for suites that pose
-- bodies (emotes, the head look).
--
--   local Rig = require("./rig")
--   local rig, rests = Rig.character(World, place)   -- becomes the local player's character
--   Rig.motor(rig, "Head")                            -- the joint that moves a part
--
-- The mirror does not carry references between instances, so each Motor6D's Part0/Part1 is
-- wired back up from the place. No animator runs here, so every joint's Transform is at rest.

local roblox = require("@lune/roblox")

local Rig = {}

-- Point every joint of a mirrored copy of `source` at the copy's own parts.
local function wire(World, source, copy, rests)
	for _, sourceMotor in ipairs(source:GetDescendants()) do
		if sourceMotor:IsA("Motor6D") and sourceMotor.Part0 and sourceMotor.Part1 then
			-- By class: the rig also carries AnimationConstraints with the joints' names.
			local motor = nil
			for _, c in ipairs(copy:FindFirstChild(sourceMotor.Parent.Name):GetChildren()) do
				if c.ClassName == "Motor6D" and c.Name == sourceMotor.Name then
					motor = c
				end
			end
			World.force(motor, "Part0", copy:FindFirstChild(sourceMotor.Part0.Name))
			World.force(motor, "Part1", copy:FindFirstChild(sourceMotor.Part1.Name))
			World.force(motor, "Transform", roblox.CFrame.new())
			if rests then
				rests[sourceMotor.Part1.Name] = sourceMotor.C0
			end
		end
	end
end

function Rig.character(World, place)
	local R = World.R
	local source = place:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
	local rig = R.mirror(source, World.workspace)
	rig.Name = World.player.Name
	local rests = {}
	wire(World, source, rig, rests)
	-- Scripts read rest poses off StarterPlayer.StarterCharacter, so wire that copy too.
	local starter = World.service("StarterPlayer"):FindFirstChild("StarterCharacter")
	if starter then
		wire(World, source, starter, nil)
	end
	World.force(World.player, "Character", rig)
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	local root = rig:FindFirstChild("HumanoidRootPart")
	rig.PrimaryPart = root
	root.CFrame = roblox.CFrame.new(0, 3, 0)
	-- Standing still: what the engine would report for a character that is not moving.
	World.force(humanoid, "MoveDirection", roblox.Vector3.new(0, 0, 0))
	World.force(humanoid, "Jump", false)
	World.force(root, "AssemblyLinearVelocity", roblox.Vector3.new(0, 0, 0))
	return rig, rests
end

--- The Motor6D that moves `partName`.
function Rig.motor(rig, partName: string)
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part1 and d.Part1.Name == partName then
			return d
		end
	end
	return nil
end

return Rig
