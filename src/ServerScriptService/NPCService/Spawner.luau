--!strict
-- Where an NPC is allowed to appear.
--
-- A spawn point in the config is a suggestion, not a promise. The actual spot is grounded
-- onto the floor beneath it and checked for a clear, person-sized space, searching outward
-- in rings if the point itself is blocked -- so a crate dropped on a spawn later does not
-- produce an enemy stuck inside it.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local NPCConfig = require(ReplicatedStorage.NPCConfig)
local World = require(script.Parent.World)

local Spawner = {}

local RINGS = { 3, 6, 9 }
local SAMPLES = 8

--- The floor point to spawn on, or nil if there is nowhere clear near `position`.
function Spawner.Resolve(position: Vector3, scale: number?): Vector3?
	local size = NPCConfig.SpawnRules.Clearance * (scale or 1)
	-- Look only a little way up: spawn points sit just above the floor, and starting high
	-- would put an NPC on top of whatever canopy or roof is overhead.
	local floor = World.GroundAt(position, 3, 30)
	local base = floor and floor.Position or position
	if World.IsClear(base, size) then
		return base
	end
	for _, radius in ipairs(RINGS) do
		for i = 0, SAMPLES - 1 do
			local angle = (i / SAMPLES) * math.pi * 2
			local candidate = base + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			local ground = World.GroundAt(candidate, 3, 12)
			if ground and World.IsClear(ground.Position, size) then
				return ground.Position
			end
		end
	end
	return nil
end

--- Is a living player standing close enough that an enemy appearing here would be unfair?
function Spawner.PlayerTooClose(position: Vector3, distance: number): boolean
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart")
			and (root.Position - position).Magnitude < distance then
			return true
		end
	end
	return false
end

return Spawner
