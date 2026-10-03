--!strict
-- Crouch and roll, made visible to everyone.
--
-- The client moves its own character (ShiftLock: the speed, the roll's push) and poses its own
-- body at once; what other clients cannot see for themselves is that it is crouched or rolling,
-- so the server writes it on the character, where it replicates:
--
--   Crouching   true while the crouch key is held (also steadies the gun: GunHandling reads it
--               on both sides)
--   RollAt      server time the roll began        RollDir   its direction, body frame
--
-- Validated, never trusted: a crouch is a boolean, a roll a finite flat unit vector, and rolls
-- are rate-limited to what the client's own cooldown allows.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Motion = require(ReplicatedStorage:WaitForChild("Motion"))

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local remote = (remotes :: Instance):FindFirstChild("Movement")
if not remote then
	local made = Instance.new("RemoteEvent")
	made.Name = "Movement"
	made.Parent = remotes
	remote = made
end

local lastRoll: { [Player]: number } = {}
-- A little under the real gap between rolls, for latency.
local MIN_GAP = (Motion.ROLL_TIME + Motion.ROLL_COOLDOWN) * 0.8

local function finite(v: Vector3): boolean
	return v.X == v.X and v.Y == v.Y and v.Z == v.Z and math.abs(v.X) < 1e3 and math.abs(v.Z) < 1e3
end

(remote :: RemoteEvent).OnServerEvent:Connect(function(player: Player, kind: unknown, value: unknown)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end
	if kind == "crouch" and type(value) == "boolean" then
		if character:GetAttribute("Crouching") ~= value then
			character:SetAttribute("Crouching", value)
		end
	elseif kind == "roll" and typeof(value) == "Vector3" and finite(value) then
		local now = os.clock()
		if now - (lastRoll[player] or -math.huge) < MIN_GAP then
			return
		end
		local flat = Vector3.new(value.X, 0, value.Z)
		if flat.Magnitude < 0.5 then
			return
		end
		lastRoll[player] = now
		character:SetAttribute("RollDir", flat.Unit)
		character:SetAttribute("RollAt", workspace:GetServerTimeNow())
	end
end)

Players.PlayerRemoving:Connect(function(player)
	lastRoll[player] = nil
end)
