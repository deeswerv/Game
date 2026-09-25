local UIS = game:GetService("UserInputService")
local CanDoubleJump = true
local CanSetCanDoubleJumpToTrue = false
local Character = game.Players.LocalPlayer.Character or game.Players.LocalPlayer.CharacterAdded:Wait()

UIS.JumpRequest:Connect(function()
    if CanDoubleJump then
        Character:WaitForChild("Humanoid").JumpPower = Character:WaitForChild("Humanoid").JumpPower * 1.5
        Character:WaitForChild("Humanoid"):ChangeState(Enum.HumanoidStateType.Jumping)
        CanDoubleJump = false
    end
end)

game.Players.LocalPlayer.Character:WaitForChild("Humanoid").StateChanged:Connect(function(old,new)
    if new == Enum.HumanoidStateType.Landed then
        CanDoubleJump = false
        CanSetCanDoubleJumpToTrue = true
        Character:WaitForChild("Humanoid").JumpPower = game:GetService("StarterPlayer").CharacterJumpPower
    elseif new == Enum.HumanoidStateType.Freefall then
        if CanSetCanDoubleJumpToTrue == true then
            wait(0.2)
            CanDoubleJump = true
            CanSetCanDoubleJumpToTrue = false
        end
    end
end)