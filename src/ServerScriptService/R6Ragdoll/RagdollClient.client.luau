-- SERVICES --
local CS = game:GetService("CollectionService")

-- OTHER VARIABLES --
local player = game.Players.LocalPlayer
local char = player.Character or player.CharacterAdded:Wait()
local hrp = char:WaitForChild("HumanoidRootPart")
local humanoid = char:WaitForChild("Humanoid")

-- FUNCTIONS --
humanoid:SetStateEnabled(Enum.HumanoidStateType.FallingDown, false)
humanoid:SetStateEnabled(Enum.HumanoidStateType.GettingUp, false)

-- R6's head was a plain Part, and rounding it off stopped a ragdoll catching its corners
-- on the floor. R15's head is a MeshPart: it has no Shape to set, and forcing it to a
-- 1x1x1 cube deforms the avatar, so this only applies to the old rig.
local head = char:WaitForChild("Head")
if head:IsA("Part") then
	head.Shape = Enum.PartType.Ball
	head.Size = Vector3.new(1, 1, 1)
end

CS:GetInstanceAddedSignal("Ragdoll"):Connect(function(v)
	if v == char then
		humanoid:ChangeState(Enum.HumanoidStateType.Physics)
		hrp:ApplyAngularImpulse(Vector3.new(90, 0, 0))
	end
end)

CS:GetInstanceRemovedSignal("Ragdoll"):Connect(function(v)
	if v == char then
		humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
end)