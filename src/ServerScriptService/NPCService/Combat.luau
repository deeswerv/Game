--!strict
-- An NPC's weapons: what it carries, what is in the magazine, and pulling the trigger.
--
-- Everything that matters is decided here on the server. Where the round goes (the NPC's
-- accuracy becomes a real cone of error, not a dice roll on "did it hit"), what it hit
-- (a raycast that walls stop), and how much that hurt (through KillCredit, the same door
-- every other source of damage uses). The client is only told what to draw.
--
-- The weapons are the real store weapons, so a magazine holds what that weapon holds and a
-- reload takes exactly as long as that weapon's ReloadTime.

local ServerScriptService = game:GetService("ServerScriptService")

local KillCredit = require(ServerScriptService.KillCredit)
local WeaponConfig = require(game:GetService("ReplicatedStorage").WeaponConfig)
local World = require(script.Parent.World)
local Body = require(script.Parent.Body)
local Effects = require(script.Parent.Effects)
local Perception = require(script.Parent.AI.Perception)

local Combat = {}

-- The aim cone, in degrees, at Accuracy 0 and Accuracy 1. Nobody hits a moving target with
-- a rifle at eighty studs every time, and nobody at 0 is so bad they cannot hit a wall.
local SPREAD_WORST = 9
local SPREAD_BEST = 0.8

-- A head is worth more, but an enemy landing a player's full headshot multiplier through a
-- random cone would make deaths feel arbitrary.
local NPC_HEADSHOT_CAP = 1.5
local LIMB_MULTIPLIER = 0.8

local EQUIP_TIME = 0.45

local LIMBS = {
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
	["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
}

-- Set by NPCService: tells the victim, if it is an NPC, who just hurt it. Injected rather
-- than required so this module does not depend on the service that owns it.
Combat.OnDamage = nil :: ((victim: Model, attacker: Model, amount: number) -> ())?

-- Same arrangement for gunfire being heard by everyone else nearby.
Combat.OnNoise = nil :: ((position: Vector3, radius: number, source: Model?) -> ())?

local function randomBetween(range: { number }): number
	return range[1] + math.random() * (range[2] - range[1])
end

-- Rotate a direction by a random cone of `degrees`, uniformly over the disc -- the same
-- distribution GunHandler uses for players, so the two are comparable.
local function applySpread(direction: Vector3, degrees: number): Vector3
	if degrees <= 0 then
		return direction
	end
	local angle = math.rad(degrees) * math.sqrt(math.random())
	local spin = math.random() * math.pi * 2
	local up = math.abs(direction.Y) > 0.99 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local right = direction:Cross(up).Unit
	local trueUp = right:Cross(direction).Unit
	local offset = (right * math.cos(spin) + trueUp * math.sin(spin)) * math.tan(angle)
	return (direction + offset).Unit
end

-- ----------------------------------------------------------------- loadout --

--- Build the weapons from the config and put the primary in hand.
function Combat.Setup(agent)
	agent.weapons = {}
	for _, name in ipairs({ agent.cfg.Weapon or false, agent.cfg.Secondary or false }) do
		if type(name) == "string" then
			local tool, wcfg = Body.MakeWeapon(name)
			if tool and wcfg then
				table.insert(agent.weapons, {
					name = name,
					tool = tool,
					cfg = wcfg,
					ranged = wcfg.Type == "Gun",
					magazine = wcfg.MagazineSize or 12,
					ammo = wcfg.MagazineSize or 12,
					reloadTime = wcfg.ReloadTime or 1.6,
					fireRate = math.max(wcfg.FireRate or 0.2, 0.06),
				})
			end
		end
	end
	agent.slot = 1
	agent.nextShotAt = 0
	agent.burstLeft = 0
	agent.burstIndex = 0
	if agent.weapons[1] then
		Body.Equip(agent, 1)
	end
end

function Combat.Current(agent)
	return agent.weapons and agent.weapons[agent.slot]
end

function Combat.IsBusy(agent, now: number): boolean
	return (agent.reloadUntil ~= nil) or (agent.equipUntil ~= nil and now < agent.equipUntil)
end

-- ------------------------------------------------------------------ reload --

function Combat.StartReload(agent, now: number): boolean
	local weapon = Combat.Current(agent)
	if not weapon or not weapon.ranged or agent.reloadUntil or weapon.ammo >= weapon.magazine then
		return false
	end
	agent.reloadUntil = now + weapon.reloadTime
	agent.burstLeft = 0
	-- Rack the action only when the chamber actually ran dry, the same rule GunHandler uses.
	local needsCharge = weapon.cfg.ChargePart ~= nil
		and (weapon.cfg.ChargeWhenEmpty == false or weapon.ammo <= 0)
	Effects.Send(agent.root.Position, "Reload", agent.model, weapon.tool, needsCharge, weapon.reloadTime)
	return true
end

function Combat.CancelReload(agent)
	if agent.reloadUntil then
		agent.reloadUntil = nil
		Effects.Send(agent.root.Position, "ReloadCancel", agent.model)
	end
end

-- ------------------------------------------------------------------ switch --

function Combat.Equip(agent, slot: number, now: number)
	if slot == agent.slot or not agent.weapons[slot] then
		return
	end
	Combat.CancelReload(agent)
	Body.Equip(agent, slot)
	agent.equipUntil = now + EQUIP_TIME
	agent.burstLeft = 0
	Effects.Send(agent.root.Position, "Equip", agent.model, agent.weapons[slot].tool)
end

--- Out of rounds with someone close: draw the sidearm rather than stand there reloading.
function Combat.TrySwitch(agent, now: number, distance: number): boolean
	if #agent.weapons < 2 or distance > (agent.cfg.SwitchRange or 30) then
		return false
	end
	for slot, weapon in ipairs(agent.weapons) do
		if slot ~= agent.slot and weapon.ranged and weapon.ammo > 0 then
			Combat.Equip(agent, slot, now)
			return true
		end
	end
	return false
end

--- Between fights: finish topping up, and go back to the primary.
function Combat.Tidy(agent, now: number)
	if Combat.IsBusy(agent, now) then
		return
	end
	local weapon = Combat.Current(agent)
	if not weapon then
		return
	end
	if weapon.ranged and weapon.ammo < weapon.magazine * (agent.cfg.ReloadThreshold or 0.3) then
		Combat.StartReload(agent, now)
	elseif agent.slot ~= 1 then
		Combat.Equip(agent, 1, now)
	end
end

-- -------------------------------------------------------------------- aim --

function Combat.Spread(agent, weapon, now: number, target: Model): number
	local cfg = agent.cfg
	local cone = SPREAD_WORST + (SPREAD_BEST - SPREAD_WORST) * math.clamp(cfg.Accuracy or 0.5, 0, 1)

	-- Settling onto a target that just appeared.
	local settle = math.clamp((now - (agent.acquiredAt or now)) / math.max((cfg.AimTime or 0.25) * 3, 0.3), 0, 1)
	cone *= 1 + (1 - settle) * 0.8

	-- Moving while shooting.
	if World.Flat(agent.root.AssemblyLinearVelocity).Magnitude > 3 then
		cone *= 1.45
	end
	-- Shooting at something that is moving.
	local targetRoot = target:FindFirstChild("HumanoidRootPart")
	if targetRoot and targetRoot:IsA("BasePart") and World.Flat(targetRoot.AssemblyLinearVelocity).Magnitude > 10 then
		cone *= 1.25
	end
	-- A long burst climbs.
	cone *= 1 + math.min(agent.burstIndex or 0, 8) * 0.07
	-- Just been hit.
	if agent.flinchUntil and now < agent.flinchUntil then
		cone *= 1.6
	end
	return cone + (weapon.cfg.SpreadMin or 0) * 0.5
end

local function aimPart(agent, target: Model): BasePart?
	if (agent.cfg.HeadAimChance or 0) > 0 and math.random() < agent.cfg.HeadAimChance then
		local head = target:FindFirstChild("Head")
		if head and head:IsA("BasePart") then
			return head
		end
	end
	for _, name in ipairs({ "UpperTorso", "Torso", "HumanoidRootPart" }) do
		local part = target:FindFirstChild(name)
		if part and part:IsA("BasePart") then
			return part
		end
	end
	return nil
end

local function zoneMultiplier(partName: string, weaponCfg): number
	if partName == "Head" then
		return math.min(weaponCfg.HeadshotMultiplier or 1.5, NPC_HEADSHOT_CAP)
	elseif LIMBS[partName] then
		return LIMB_MULTIPLIER
	end
	return 1
end

--- Damage a character on behalf of this NPC, and let an NPC victim know who did it.
function Combat.Hurt(agent, victimModel: Model, victim: Humanoid, amount: number, weaponName: string?,
	direction: Vector3, partName: string)
	victim:SetAttribute("LastHitPart", partName)
	if Combat.OnDamage then
		Combat.OnDamage(victimModel, agent.model, amount)
	end
	KillCredit.Damage(victim, amount, nil, weaponName, direction)
end

local function shoot(agent, weapon, target: Model, now: number)
	local cfg = agent.cfg
	local part = aimPart(agent, target)
	if not part then
		return
	end
	local muzzle = weapon.tool:FindFirstChild("Muzzle") or weapon.tool:FindFirstChild("Handle")
	local origin = Perception.EyeOf(agent.model)
	if muzzle and muzzle:IsA("BasePart") and (muzzle.Position - agent.root.Position).Magnitude < 8 then
		origin = muzzle.Position
	end

	-- Aim where the target WAS a moment ago. A worse shot is working from older information,
	-- so it trails a strafing player and misses naturally rather than by a coin flip.
	local velocity = part.AssemblyLinearVelocity
	local lag = (1 - (cfg.Accuracy or 0.5)) * 0.18
	local aimAt = part.Position - Vector3.new(velocity.X, velocity.Y * 0.3, velocity.Z) * lag

	local direction = aimAt - origin
	if direction.Magnitude < 0.1 then
		return
	end
	direction = applySpread(direction.Unit, Combat.Spread(agent, weapon, now, target))
	local range = math.min(weapon.cfg.Range or 300, cfg.AttackRange * 1.5)

	local result = workspace:Raycast(origin, direction * range, World.ShotParams(cfg.Faction))
	local endPoint = result and result.Position or origin + direction * range

	if result then
		local victimModel, victim = World.CharacterOf(result.Instance)
		if victimModel and victim and victimModel ~= agent.model and victim.Health > 0 then
			local damage = cfg.Damage * zoneMultiplier(result.Instance.Name, weapon.cfg)
			Combat.Hurt(agent, victimModel, victim, damage, weapon.name, direction, result.Instance.Name)
		end
	end

	agent.shotsFromSpot = (agent.shotsFromSpot or 0) + 1
	Effects.Send(origin, "Shot", agent.model, origin, endPoint)

	-- Heard by anyone not already busy. Throttled per NPC: a burst is one noise, not five,
	-- and the sweep is over agents rather than parts.
	if Combat.OnNoise and now - (agent.lastNoiseAt or -math.huge) > 0.75 then
		agent.lastNoiseAt = now
		Combat.OnNoise(origin, WeaponConfig.NoiseRadius(weapon.cfg, weapon.tool), agent.model)
	end
end

--- Keep a ranged NPC's trigger discipline. Call every tick while it has a target; `wantFire`
--- says whether the brain wants rounds going downrange right now.
---
--- Rounds are scheduled on a clock rather than one per tick, so a weapon's fire rate holds
--- no matter how often the AI thinks.
function Combat.Fire(agent, now: number, target: Model?, wantFire: boolean)
	local weapon = Combat.Current(agent)
	if not weapon or not weapon.ranged then
		return
	end
	if not wantFire or not target or Combat.IsBusy(agent, now) then
		agent.burstLeft = 0
		agent.burstIndex = 0
		return
	end
	if weapon.ammo <= 0 then
		return
	end
	-- Coming back to the trigger after a pause does not bank shots for the time spent away.
	if now - agent.nextShotAt > 0.25 then
		agent.nextShotAt = now
	end
	local fired = 0
	while now >= agent.nextShotAt and weapon.ammo > 0 and fired < 3 do
		if agent.burstLeft <= 0 then
			local burst = agent.cfg.Burst or { 1, 1 }
			agent.burstLeft = math.random(burst[1], burst[2])
			agent.burstIndex = 0
		end
		shoot(agent, weapon, target, now)
		weapon.ammo -= 1
		fired += 1
		agent.burstLeft -= 1
		agent.burstIndex += 1
		if agent.burstLeft <= 0 then
			agent.nextShotAt += weapon.fireRate + randomBetween(agent.cfg.BurstPause or { 0.4, 0.7 })
		else
			agent.nextShotAt += weapon.fireRate
		end
	end
end

--- Reloads and weapon swaps finishing. Runs every tick regardless of what the brain is doing,
--- so a reload started in cover completes even if the NPC has since moved on.
function Combat.Update(agent, now: number)
	if agent.reloadUntil and now >= agent.reloadUntil then
		agent.reloadUntil = nil
		local weapon = Combat.Current(agent)
		if weapon then
			weapon.ammo = weapon.magazine
		end
	end
	if agent.equipUntil and now >= agent.equipUntil then
		agent.equipUntil = nil
	end
	Combat.UpdateSwing(agent, now)
end

-- ------------------------------------------------------------------- melee --

function Combat.StartSwing(agent, now: number, target: Model): boolean
	if agent.swing or now < (agent.nextSwingAt or 0) then
		return false
	end
	local cfg = agent.cfg
	local windup = cfg.MeleeWindup or 0.3
	local recover = cfg.MeleeRecover or 0.35
	agent.swing = { target = target, hitAt = now + windup, endAt = now + windup + recover, landed = false }
	agent.nextSwingAt = now + windup + recover + (cfg.AttackCooldown or 1) * 0.5
	Effects.Send(agent.root.Position, "Swing", agent.model, windup, recover, cfg.HeavySwing == true)
	return true
end

function Combat.CancelSwing(agent)
	agent.swing = nil
end

--- The swing lands at the end of its windup, and only if the target is still in reach and
--- still in front. Stepping back out of a telegraphed swing works.
function Combat.UpdateSwing(agent, now: number)
	local swing = agent.swing
	if not swing then
		return
	end
	if not swing.landed and now >= swing.hitAt then
		swing.landed = true
		local target = swing.target
		local targetRoot = target and target:FindFirstChild("HumanoidRootPart")
		local victim = target and target:FindFirstChildOfClass("Humanoid")
		if targetRoot and targetRoot:IsA("BasePart") and victim and victim.Health > 0 then
			local offset = World.Flat(targetRoot.Position - agent.root.Position)
			local look = World.Flat(agent.root.CFrame.LookVector)
			local reach = agent.cfg.AttackRange + 2.5
			local inFront = offset.Magnitude < 1.5 or (look.Magnitude > 0 and offset.Unit:Dot(look.Unit) > 0.35)
			if offset.Magnitude <= reach and inFront then
				local weapon = Combat.Current(agent)
				Combat.Hurt(agent, target, victim, agent.cfg.Damage, weapon and weapon.name or nil,
					offset.Magnitude > 0 and offset.Unit or look, "UpperTorso")
			end
		end
	end
	if now >= swing.endAt then
		agent.swing = nil
	end
end

--- Put everything down: dead NPCs do not finish reloads or land swings.
function Combat.Stop(agent)
	agent.swing = nil
	agent.burstLeft = 0
	if agent.reloadUntil then
		agent.reloadUntil = nil
		Effects.Send(agent.root.Position, "ReloadCancel", agent.model)
	end
end

return Combat
