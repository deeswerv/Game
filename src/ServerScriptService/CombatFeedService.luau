--!strict
-- Two small things the combat HUD needs from the server: where a player is aiming, and
-- who they just killed.
--
-- Aim: the client reports its camera pitch, the server stamps it on the character as an
-- attribute, and that replicates to everyone. Attributes are the cheap way to do this --
-- one property write, no per-client remote traffic. The client throttles what it sends,
-- and the value is clamped here because nothing a client says is trusted.
--
-- Kills: KillCredit already announces every kill it attributes, so this just forwards
-- them to the killer for their feed rather than inventing a second kill system.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local KillCredit = require(ServerScriptService.KillCredit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local AimUpdate = Remotes:WaitForChild("AimUpdate") :: RemoteEvent
local KillFeed = Remotes:WaitForChild("KillFeed") :: RemoteEvent

local CombatFeedService = {}

-- How far the weapon is allowed to follow the camera. Past this it stops looking like
-- aiming and starts looking like the arm is broken.
local MAX_PITCH = 55

-- A floor on the gap between accepted updates, so a client cannot flood the server by
-- ignoring its own throttle.
local MIN_INTERVAL = 0.05
local lastAccepted: { [Player]: number } = {}

AimUpdate.OnServerEvent:Connect(function(player, pitch, aiming, sprinting)
	if typeof(pitch) ~= "number" or pitch ~= pitch then
		return                        -- not a number, or NaN
	end
	local character = player.Character
	if not character then
		return
	end

	-- The stance is not rate limited. These are booleans, they only change when the player
	-- presses or releases the aim button or breaks into a run, and throttling them would
	-- drop the press. Coerced rather than trusted: a client can send anything it likes.
	character:SetAttribute("Aiming", aiming == true)
	character:SetAttribute("Sprinting", sprinting == true)

	local now = os.clock()
	if lastAccepted[player] and now - lastAccepted[player] < MIN_INTERVAL then
		return
	end
	lastAccepted[player] = now
	character:SetAttribute("AimPitch", math.clamp(pitch, -MAX_PITCH, MAX_PITCH))
end)

Players.PlayerRemoving:Connect(function(player)
	lastAccepted[player] = nil
end)

-- Sent only to the killer: this is their feed, not a server-wide announcement.
KillCredit.KillAwarded.Event:Connect(function(killer, humanoid, victim)
	if not killer or not killer:IsA("Player") then
		return
	end
	local name = "Enemy"
	if typeof(victim) == "Instance" then
		if victim:IsA("Player") then
			name = victim.DisplayName ~= "" and victim.DisplayName or victim.Name
		elseif victim:IsA("Model") then
			name = victim.Name
		end
	elseif typeof(victim) == "string" then
		name = victim
	end
	-- What did it, so the feed can read killer / weapon / victim the way the reference does
	-- rather than just naming the victim. CombatDeath reads this same attribute to pick the
	-- death knockback, so it is an answer the game already trusts rather than a new one.
	local weapon: string? = nil
	if typeof(humanoid) == "Instance" and humanoid:IsA("Humanoid") then
		local last = humanoid:GetAttribute("LastHitWeapon")
		weapon = typeof(last) == "string" and last or nil
	end

	KillFeed:FireClient(killer, name, weapon)
end)

return CombatFeedService
