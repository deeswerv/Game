local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Remotes = ReplicatedStorage:WaitForChild("Events"):WaitForChild("Remotes")

local HitCounterRemotes = Remotes:WaitForChild("HitCounter")

local HitCounterModule = require(script:WaitForChild("HitCounter"))

HitCounterRemotes.OnClientEvent:Connect(function()
	HitCounterModule:Add()
end)