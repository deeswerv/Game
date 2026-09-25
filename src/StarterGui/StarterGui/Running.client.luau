-- Made by Vuuk Studios
-- Main Running Script also contains weapon running so if you equip a weapon the running for it changes up
-- fov and animation playing also

local UIS = game:GetService("UserInputService")
local DefaultFOV = 70

local lastTime = tick()
local player = game.Players.LocalPlayer

local char = game:GetService("Players").LocalPlayer.Character
local hum = char:WaitForChild("Humanoid")
local run = false
local Track1 
local Track2


UIS.InputBegan:Connect(function(input,gameprocessed)
	if input.KeyCode == Enum.KeyCode.W then
	


		local now = tick()
		local difference = (now - lastTime)

		if difference <= 0.5 then

		
				run = true

				Track1 = game.Players.LocalPlayer.Character.Humanoid:LoadAnimation(script.Regular)
				

		
					Track1:Play()
			
		

				hum.WalkSpeed = 24.5
			
				local properties = {FieldOfView = DefaultFOV + 10}
				local Info = TweenInfo.new(0.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,0.1)
				local T = game:GetService("TweenService"):Create(game.Workspace.CurrentCamera,Info,properties)
				T:Play()


		

				end

		lastTime = tick()
	end
end)

UIS.InputEnded:Connect(function(input,gameprocessed)
	if (char:FindFirstChild("C") ~= nil and char.C.Value == true) then return end
	if input.KeyCode == Enum.KeyCode.W then
		run = false
		if Track1 then	
			Track1:Stop()
		
		end	

		hum.WalkSpeed = 16
		
		local properties = {FieldOfView = DefaultFOV}
		local Info = TweenInfo.new(0.5,Enum.EasingStyle.Sine,Enum.EasingDirection.InOut,0.1)
		local T = game:GetService("TweenService"):Create(game.Workspace.CurrentCamera,Info,properties)
		T:Play()

	end

end)

