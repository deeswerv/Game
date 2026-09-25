--!strict
-- Getting hit shoves the camera. Scaled by how big the hit was, so chip damage and a
-- shotgun to the back do not feel the same.
--
-- This used to run its own CameraShaker bound at RenderPriority.Camera, which is the same
-- point the stock camera module writes its CFrame -- so the shake was fighting for the
-- same frame and half of it never showed. It also indexed Character directly with no
-- wait, so it errored on any spawn where the Humanoid had not replicated yet. Both go
-- through ViewKick now, which the camera script applies once, after the camera module has
-- finished, alongside firing kick and landing.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ViewKick = require(ReplicatedStorage:WaitForChild("ViewKick"))

local player = Players.LocalPlayer
local character = script.Parent
local humanoid = character:WaitForChild("Humanoid") :: Humanoid

local lastHealth = humanoid.Health

humanoid.HealthChanged:Connect(function(health)
	local lost = lastHealth - health
	lastHealth = health
	if lost <= 0 then
		return
	end
	-- A quarter of the health bar in one go is a full-strength shove; anything smaller
	-- scales down from there so a poison tick is not the same event as a sniper round.
	ViewKick.Hurt(math.clamp(lost / (humanoid.MaxHealth * 0.25), 0.3, 2.2))
end)