local UIS = game:GetService("UserInputService")

-- Made by Vuuk Studios
-- controls the main movement and dashing system
local camera = workspace.CurrentCamera
local DKeyDown = false
local SKeyDown = false
local AKeyDown = false
local WKeyDown = false



local Blocking = false


local Player = game.Players.LocalPlayer
local Char = Player.Character or Player.CharacterAdded:Wait()
while Char.Parent == nil do
	Char.AncestryChanged:wait()
end
local HumRP = Char:WaitForChild("HumanoidRootPart")
local Hum = Char:WaitForChild("Humanoid")
local RollFrontAnim = Hum:LoadAnimation(script:WaitForChild("RollFront"))
local BackRollAnim = Hum:LoadAnimation(script:WaitForChild("BackRoll"))
local LeftRollAnim = Hum:LoadAnimation(script:WaitForChild("RightRoll"))
local RightRollAnim = Hum:LoadAnimation(script:WaitForChild("LeftRoll"))
-- The trail everyone sees is drawn by the server (ServerScriptService.DashFX). Looked up
-- lazily so a slow join can never stall the dash itself.
local function fireTrail()
	local remotes = game:GetService("ReplicatedStorage"):FindFirstChild("Remotes")
	local remote = remotes and remotes:FindFirstChild("DashEffect")
	if remote and remote:IsA("RemoteEvent") then
		remote:FireServer()
	end
end
local DashDebounce = false
local DashingDebounce = false
local isAttacking = Char:WaitForChild("IsAttacking")
local CanDoAnything = true
local d = script.Dash
local d2 = script.Dash
local d3 = script.Parent:WaitForChild("DashL")
local val = Char:WaitForChild("IsJumping")
local bt = Char:WaitForChild("BlockTime")

Hum.StateChanged:Connect(function(oldState, newState)
	if newState == Enum.HumanoidStateType.Jumping then
		val.Value = true
	elseif newState == Enum.HumanoidStateType.Landed then
		val.Value = false
	end
end)
	

UIS.InputBegan:Connect(function(Input,IsTyping)
	if IsTyping then return end
	if Char:FindFirstChild("PBSTUN") then return end


	if isAttacking.Value == true then return end
	if val.Value == true then return end
	if d3.Value == true then return end
	if bt.Value == true then return end

	if Char:FindFirstChild("noJump") then return end
	if CanDoAnything == true then
		if Input.UserInputType == Enum.UserInputType.MouseButton1 then
			
			-- blank
		elseif Input.KeyCode == Enum.KeyCode.Q then
			if DashDebounce == false and Char:FindFirstChild("Disabled") == nil then
				
				DashDebounce = true
				CanDoAnything = false
				delay(0.3,function()
					CanDoAnything = true
				end)
				delay(2.5,function()
					DashDebounce = false
				end)
				if WKeyDown then
					RollFrontAnim:Play()
					DashingDebounce = true
					d:Play()
					fireTrail()
					
					delay(0.25,function()
						DashingDebounce = false
					end)
					
					repeat
						
						HumRP.Velocity = HumRP.CFrame.lookVector * 130
						wait(0.1)
					until DashingDebounce == false
				elseif SKeyDown then
					DashingDebounce = true
					
					BackRollAnim:Play()
					d:Play()
					fireTrail()
					
					delay(0.25,function()
						DashingDebounce = false
					end)

					repeat
						
						HumRP.Velocity = HumRP.CFrame.lookVector * -130
						wait(0.1)
					until DashingDebounce == false
				elseif DKeyDown then
					DashingDebounce = true
					
					LeftRollAnim:Play()
					d2:Play()
					fireTrail()
					
					delay(0.25,function()
						DashingDebounce = false
					end)

					repeat
					
						HumRP.Velocity = HumRP.CFrame.rightVector * 145
						wait(0.11)
					until DashingDebounce == false
				elseif AKeyDown then
					DashingDebounce = true
					d2:Play()
					fireTrail()
					
					RightRollAnim:Play()
					
					delay(0.25,function()
						DashingDebounce = false
					end)

					repeat
						
						HumRP.Velocity = HumRP.CFrame.rightVector * -145
						wait(0.11)
					until DashingDebounce == false
				end	
			end	
			
	
			end
		end
	end)

local RunService = game:GetService("RunService")

RunService.RenderStepped:Connect(function()
	local Player = game.Players.LocalPlayer
	local Char = Player.Character
	local Hum = Char:FindFirstChild("Humanoid")
	
	if UIS:IsKeyDown(Enum.KeyCode.W)  then
		WKeyDown = true
	else
		WKeyDown = false
	end
	if UIS:IsKeyDown(Enum.KeyCode.A)  then
		AKeyDown = true
	else
		AKeyDown = false
	end
	if UIS:IsKeyDown(Enum.KeyCode.S) then
		SKeyDown = true
	else 
		SKeyDown = false
	end
	if UIS:IsKeyDown(Enum.KeyCode.D) then
		DKeyDown = true
	else 
		DKeyDown = false
	end
	

end)

