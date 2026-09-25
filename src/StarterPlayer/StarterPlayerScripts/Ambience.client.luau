--!strict
-- World ambience. The place was completely silent apart from gunfire, which is the single
-- loudest tell that a game is unfinished -- a world with no sound in it reads as a test
-- level no matter how good it looks.
--
-- Deliberately quiet. Ambience is meant to be noticed only when it stops; anything loud
-- enough to identify while playing is too loud. It also ducks while shooting, so it never
-- competes with the thing the player is actually listening for.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

-- Pro Sound Effects' library, shipped free with Roblox: a 36-second seamless forest loop.
local AMBIENCE_ID = "rbxassetid://9112802475"

local BASE_VOLUME = 0.11
local DUCKED_VOLUME = 0.04
local DUCK_HOLD = 1.4 -- seconds of quiet after the last shot
local FADE_RATE = 2.5 -- volume units per second

local ambience = Instance.new("Sound")
ambience.Name = "WorldAmbience"
ambience.SoundId = AMBIENCE_ID
ambience.Looped = true
ambience.Volume = 0
ambience.Parent = SoundService
ambience:Play()

-- Fade in rather than starting at full volume, so joining the game does not open with a
-- sudden wall of birdsong.
local target = BASE_VOLUME
local lastShotAt = 0

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remotes = ReplicatedStorage:WaitForChild("Remotes")
local gunEffect = remotes:WaitForChild("GunEffect") :: RemoteEvent

gunEffect.OnClientEvent:Connect(function(kind, shooter)
	-- Only our own shots duck the mix. Someone else's firefight across the map should not
	-- silence the world around the player.
	if kind == "Shot" and shooter == player then
		lastShotAt = os.clock()
	end
end)

RunService.Heartbeat:Connect(function(dt)
	target = (os.clock() - lastShotAt < DUCK_HOLD) and DUCKED_VOLUME or BASE_VOLUME
	local step = FADE_RATE * dt
	if ambience.Volume < target then
		ambience.Volume = math.min(target, ambience.Volume + step)
	elseif ambience.Volume > target then
		ambience.Volume = math.max(target, ambience.Volume - step)
	end
end)
