-- LocalScript inside StarterPlayerScripts

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera
camera.CameraType = Enum.CameraType.Scriptable

local OFFSET = Vector3.new(0, 5, -10) -- Camera offset behind player
local SMOOTHNESS = 0.1 -- Lower is smoother (0.05–0.2 is a good range)

RunService:BindToRenderStep("SmoothCamera", Enum.RenderPriority.Camera.Value, function()
	local char = player.Character
	if not char or not char:FindFirstChild("HumanoidRootPart") then return end

	local rootPart = char.HumanoidRootPart
	local targetPosition = rootPart.Position + rootPart.CFrame:VectorToWorldSpace(OFFSET)
	local currentPosition = camera.CFrame.Position

	-- Interpolate (lerp) the position
	local newPosition = currentPosition:Lerp(targetPosition, SMOOTHNESS)
	local lookAt = rootPart.Position + Vector3.new(0, 2, 0)

	camera.CFrame = CFrame.new(newPosition, lookAt)
end)

