--!strict
-- Tells a player what just killed them.
--
-- One remote, fired once, to the victim alone. Nothing here decides anything: the kill was
-- already credited by KillCredit and the body already dropped by CombatDeath. This only
-- reports, so if it fails the death still works and the player simply respawns without a
-- killcam.
--
-- Deliberately NOT broadcast. Only the person who died learns who killed them, and only
-- about their own death -- a FireAllClients here would hand every client a live feed of
-- where everyone is dying, which is map information nobody should get for free.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local KillCredit = require(ServerScriptService.KillCredit)

local KillcamService = {}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local DeathReport = remotes:FindFirstChild("DeathReport")
if not DeathReport then
	local event = Instance.new("RemoteEvent")
	event.Name = "DeathReport"
	event.Parent = remotes
	DeathReport = event
end

--- Who, with what, and is there anything left to look at.
local function report(humanoid: Humanoid)
	local character = humanoid.Parent
	if not character then
		return
	end

	local victim = Players:GetPlayerFromCharacter(character)
	if not victim then
		return      -- NPCs die constantly; only a player needs telling
	end

	local killer = KillCredit.GetKiller(humanoid)

	-- Suicide and environmental deaths are a real case, not an error: the panel just says so
	-- instead of naming somebody.
	if killer == victim then
		killer = nil
	end

	local killerCharacter = killer and killer.Character or nil
	local killerHumanoid = killerCharacter and killerCharacter:FindFirstChildOfClass("Humanoid")

	-- Only offer a camera subject if there is a living body to watch. Spectating a corpse or
	-- a character that has already been cleaned up gives a black screen, which reads as a bug.
	local watchable = nil
	if killerHumanoid and killerHumanoid.Health > 0 then
		watchable = killerHumanoid
	end

	DeathReport:FireClient(victim, {
		killerName = killer and killer.DisplayName or nil,
		killerUserId = killer and killer.UserId or nil,
		subject = watchable,
		-- Recorded on the humanoid by KillCredit.Damage at the moment of the hit.
		weapon = humanoid:GetAttribute("LastHitWeapon"),
		respawnIn = Players.RespawnTime,
	})
end

-- Player characters are watched DIRECTLY rather than through KillCredit.HumanoidDied.
--
-- That event only fires for humanoids KillCredit is already watching, and it only starts
-- watching one when it is damaged through Tag or Damage. So a fall, a drowning, or anything
-- else uncredited never fires it -- which is exactly the "YOU DIED with no killer" case. This
-- was found by killing a character with no attacker and getting no report at all.
--
-- GetKiller still works from here, because the credit tag lives on the humanoid either way.
local function watchCharacter(character: Model)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	end
	if not humanoid then
		return
	end

	-- Humanoid.Died is not once per death: CombatDeath's own comment records it firing seven
	-- times for one kill, because going limp re-triggers it. One report per character.
	local reported = false
	humanoid.Died:Connect(function()
		if reported then
			return
		end
		reported = true
		-- pcall so a presentation failure can never interfere with the death itself.
		local ok, err = pcall(report, humanoid)
		if not ok then
			warn("[Killcam] report failed: " .. tostring(err))
		end
	end)
end

local function onPlayer(player: Player)
	player.CharacterAdded:Connect(watchCharacter)
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
end

Players.PlayerAdded:Connect(onPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, player)
end

print("[Killcam] death reports armed")

return KillcamService
