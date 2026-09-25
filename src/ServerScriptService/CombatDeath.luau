--!strict
-- What happens to a body when it dies: it goes limp, and the weapon that killed it
-- decides how hard it is thrown.
--
-- The ragdoll itself is the existing R6Ragdoll module -- this only drives it, so there is
-- one ragdoll implementation in the game rather than two. KillCredit records which weapon
-- landed the killing blow and from which direction, and the force is looked up from that
-- weapon's DeathKnockback in WeaponConfig.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local RagdollBuilder = require(ServerScriptService.R6Ragdoll.RagdollBuilder)
local WeaponConfig = require(ReplicatedStorage.WeaponConfig)

local CombatDeath = {}

-- How long a body lies there before it is cleared away. Every second of this is a loose
-- physics assembly the server is simulating, so it is deliberately short.
CombatDeath.RagdollLifetime = 4

-- Never simulate more than this many bodies at once. Past it the oldest is cleared early:
-- a pile of ragdolls is the thing that actually costs frames in a fight, not any one of
-- them.
local MAX_ACTIVE_RAGDOLLS = 6
local active: { Model } = {}

-- Impulse is mass-scaled, so this converts a DeathKnockback number into something the
-- physics engine reacts to at a sensible scale. Tuned so a pistol nudges and a warhammer
-- throws, without anything going into orbit.
-- Knockback is set as a velocity rather than an impulse. Impulses were unpredictable
-- here: applied to a body whose ragdoll constraints had only just been created, a 26 and
-- a 135 knockback both came out at the same 25 studs/s, so the weapon made no difference.
-- Setting the velocity directly is exact, mass-independent and cannot be swallowed by the
-- assembly reshuffling underneath it.
--
-- studs/s per point of DeathKnockback. A pistol (26) leaves at ~3, a warhammer (135) at
-- ~16 -- clearly different, and neither slides across the map.
local SPEED_PER_POINT = 0.12
local MAX_SPEED = 22

-- Prepared rigs, so Setup is never run twice on the same body.
local prepared: { [Model]: boolean } = {}

-- Bodies already dropped, so a body is never ragdolled twice.
--
-- Humanoid.Died is not the once-per-death signal it looks like. Going limp puts the
-- humanoid into Physics, a DEAD humanoid is immediately forced back to Dead, and that
-- re-fires Died -- which ragdolled it again, which set Physics again. Measured seven Died
-- events in 0.12s, each one pushing the same model onto `active` until it overflowed
-- MAX_ACTIVE_RAGDOLLS and the body deleted itself mid-fall. That is why players appeared
-- to simply vanish on death instead of ragdolling.
local killed: { [Model]: boolean } = {}

-- Keep one socket per joint name. This place ships a ragdoll rig of its own that builds
-- the same five (NS, RAS, LAS, RLS, LLS), and whichever of us runs second was leaving a
-- duplicate set -- ten constraints on a living body, and both systems firing on one death.
local function dedupeSockets(model: Model)
	local seen: { [string]: boolean } = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BallSocketConstraint") then
			if seen[d.Name] then
				d:Destroy()
			else
				seen[d.Name] = true
			end
		end
	end
end

-- Ragdoll needs its joints swapped for constraints before it can go limp, and that has to
-- happen while the rig is still alive and whole.
function CombatDeath.Prepare(model: Model)
	if prepared[model] then
		return
	end

	local ok, err = pcall(function()
		RagdollBuilder:Setup(model)
	end)

	-- This place already ships a ragdoll rig of its own, building the same five sockets
	-- (NS, RAS, LAS, RLS, LLS). Whichever of us runs second was leaving a duplicate set --
	-- ten constraints on a living body, and both systems firing on the same death.
	--
	-- Checking beforehand does not work, because the order is not fixed: on a fresh spawn
	-- this runs first and there is nothing to find yet. Clearing duplicates afterwards is
	-- order-independent, so it holds either way round.
	-- Run twice: once now, and once after the rig has finished assembling. On an NPC we
	-- are second and the immediate pass is the one that does the work; on a player we are
	-- first and the other system's set does not exist yet, so only the later pass sees it.
	if ok then
		dedupeSockets(model)
		task.delay(3, function()
			if model.Parent then
				dedupeSockets(model)
			end
		end)
	end
	if ok then
		prepared[model] = true
		model.Destroying:Connect(function()
			prepared[model] = nil
		end)
	else
		warn("[CombatDeath] could not prepare ragdoll for " .. model.Name .. ": " .. tostring(err))
	end
end

-- The weapon that landed the killing blow, and the direction it came from.
local function killingBlow(humanoid: Humanoid): (string?, Vector3?)
	local weapon = humanoid:GetAttribute("LastHitWeapon")
	local direction = humanoid:GetAttribute("LastHitDirection")
	return typeof(weapon) == "string" and weapon or nil,
		typeof(direction) == "Vector3" and direction or nil
end

-- Drop the body and throw it. Safe to call on anything with an R6 humanoid.
function CombatDeath.Kill(model: Model, lifetime: number?)
	if killed[model] then
		return
	end
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root then
		return
	end
	killed[model] = true

	local weapon, direction = killingBlow(humanoid)
	local cfg = weapon and WeaponConfig.Get(weapon)
	local force = cfg and cfg.DeathKnockback or WeaponConfig.Defaults.DeathKnockback

	local ok = pcall(function()
		RagdollBuilder:Ragdoll(model)
	end)
	if not ok then
		return                          -- not a rig this ragdoll can drive; leave it be
	end

	-- Thrown the way the shot was travelling, with a little lift so bodies tumble instead
	-- of skidding along the floor.
	local push = direction or root.CFrame.LookVector * -1
	push = (push + Vector3.new(0, 0.45, 0)).Unit

	local torso = (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")) :: BasePart?
	local target = torso or root
	local speed = math.min(force * SPEED_PER_POINT, MAX_SPEED)
	target.AssemblyLinearVelocity = push * speed
	-- A little spin so it tumbles rather than sliding, scaled the same way.
	target.AssemblyAngularVelocity = Vector3.new(
		(math.random() - 0.5) * speed * 0.6,
		(math.random() - 0.5) * speed * 0.6,
		(math.random() - 0.5) * speed * 0.6)

	-- Keep the number of simulated bodies bounded.
	table.insert(active, model)
	while #active > MAX_ACTIVE_RAGDOLLS do
		local oldest = table.remove(active, 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end
	model.Destroying:Connect(function()
		killed[model] = nil
		local i = table.find(active, model)
		if i then
			table.remove(active, i)
		end
	end)

	Debris:AddItem(model, lifetime or CombatDeath.RagdollLifetime)
end

-- ---------------------------------------------------------------- players --

-- Players ragdoll the same way NPCs do. Their bodies are not cleared away on a timer --
-- respawning removes the old character -- so the lifetime is left long enough to watch.
local function watchCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	CombatDeath.Prepare(character)
	humanoid.Died:Connect(function()
		-- Long enough to see yourself fall, short enough that the body is not still being
		-- simulated when you respawn. 120 here was leaving a physics assembly running for
		-- two minutes after every death.
		CombatDeath.Kill(character, 6)
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

return CombatDeath
