local Character = script.Parent
local Humanoid = Character:WaitForChild("Humanoid")

Character.ChildAdded:Connect(function()
	if Character:FindFirstChild("noJump") then
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	else
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
end)

Character.ChildRemoved:Connect(function()
	if Character:FindFirstChild("noJump") then
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
	else
		Humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
	end
end)
-- Made by Vuuk Studios
-- Controls mid attack things like no jumping moving and doing weird stuff