--!strict
-- Where each player is looking, so everyone else can see their head turn.
--
-- A player's own client turns their head towards the camera (HeadLook, a client script) --
-- but a joint moved on one client moves on that client only. So the client also sends the
-- angles it chose, a few times a second, and they are published here as a character
-- attribute that every other client reads and eases towards:
--
--   HeadLook = Vector2(yaw, pitch), whole degrees; yaw positive to the character's left,
--              pitch positive up.
--
-- Clamped to what a neck can do and rate limited: the worst a modified client can do is
-- turn its own head as far as anyone's can turn, slightly more often.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HeadLookService = {}

HeadLookService.MAX_YAW = 75
HeadLookService.MAX_PITCH = 45
local MIN_INTERVAL = 0.08

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local LookUpdate = remotes:FindFirstChild("LookUpdate") :: RemoteEvent?
if not LookUpdate then
	local created = Instance.new("RemoteEvent")
	created.Name = "LookUpdate"
	created.Parent = remotes
	LookUpdate = created
end

local lastAccepted: { [Player]: number } = {}

--- Publish a look for `player`'s character. Returns whether it was taken.
function HeadLookService.Set(player: Player, yaw: unknown, pitch: unknown): boolean
	if typeof(yaw) ~= "number" or typeof(pitch) ~= "number" or yaw ~= yaw or pitch ~= pitch then
		return false
	end
	local character = player.Character
	if not character then
		return false
	end
	local now = os.clock()
	if lastAccepted[player] and now - lastAccepted[player] < MIN_INTERVAL then
		return false
	end
	lastAccepted[player] = now
	local y = math.floor(math.clamp(yaw, -HeadLookService.MAX_YAW, HeadLookService.MAX_YAW) + 0.5)
	local p = math.floor(math.clamp(pitch, -HeadLookService.MAX_PITCH, HeadLookService.MAX_PITCH) + 0.5)
	character:SetAttribute("HeadLook", Vector2.new(y, p))
	return true
end

;(LookUpdate :: RemoteEvent).OnServerEvent:Connect(function(player, yaw, pitch)
	HeadLookService.Set(player, yaw, pitch)
end)

Players.PlayerRemoving:Connect(function(player)
	lastAccepted[player] = nil
end)

return HeadLookService
