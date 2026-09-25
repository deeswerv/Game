local CS = game:GetService("CollectionService")
local tag = "Ragdoll"

script.Parent.ChildAdded:Connect(function(v)
	if script.Parent:FindFirstChild("Ragdoll") then
		CS:AddTag(script.Parent, tag)
	end
	
	if script.Parent:FindFirstChild("OnFire") then
		CS:AddTag(script.Parent, "OnFire")
	end
end)

script.Parent.ChildRemoved:Connect(function(v)
	if not script.Parent:FindFirstChild("Ragdoll") then
		CS:RemoveTag(script.Parent, tag)
	end
	
	if not script.Parent:FindFirstChild("OnFire") then
		CS:RemoveTag(script.Parent, "OnFire")
	end
end)