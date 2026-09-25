--!strict
-- How an NPC goes down.
--
-- Five deaths (NPCAnimation.Deaths), picked from how the killing blow landed rather than at
-- pure random: a headshot snaps back or drops to the knees, a shot from behind pitches it
-- forward, one from the side spins it over sideways, a heavy hit staggers it backwards.
--
-- The sequence:
--   1. The AI is already off (NPCService stops it before calling this).
--   2. The root is anchored so the body cannot topple or slide while the death plays.
--   3. Every nearby client is told which death to play, and plays it locally.
--   4. When it ends, the server writes that death's LAST frame onto its own joints, waits
--      one physics step for the limbs to get there, and hands the body to the existing
--      ragdoll (CombatDeath), which throws it in the death's direction.
--
-- Step 4 is what makes it seamless: the ragdoll starts from the pose players just watched,
-- not from the upright rig the server would otherwise still be holding.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local NPCAnimation = require(ReplicatedStorage.NPCAnimation)
local CombatDeath = require(ServerScriptService.CombatDeath)
local WeaponPose = require(ServerScriptService.WeaponPose)
local Body = require(script.Parent.Body)
local Effects = require(script.Parent.Effects)

local Death = {}

local function pick(agent): (string, boolean)
	local humanoid = agent.humanoid
	local part = agent.lastHitPart or humanoid:GetAttribute("LastHitPart")
	local travel = humanoid:GetAttribute("LastHitDirection")
	local heavy = (agent.lastHitAmount or 0) >= humanoid.MaxHealth * 0.25

	local side = "Front"
	if typeof(travel) == "Vector3" then
		local fromShooter = agent.root.CFrame:VectorToObjectSpace(-travel)
		if math.abs(fromShooter.X) > math.abs(fromShooter.Z) then
			side = fromShooter.X > 0 and "Right" or "Left"
		else
			side = fromShooter.Z < 0 and "Front" or "Back"
		end
	end

	local roll = math.random()
	if part == "Head" then
		return roll < 0.55 and "Backward" or (roll < 0.85 and "Knees" or "Forward"), false
	elseif side == "Back" then
		return "Forward", false
	elseif side == "Left" or side == "Right" then
		-- Sideways is authored falling to the body's left; a hit from the LEFT throws it
		-- to the right, so that is the mirrored one.
		if roll < 0.7 then
			return "Sideways", side == "Left"
		end
		return roll < 0.85 and "Backward" or "Knees", false
	elseif heavy then
		return roll < 0.65 and "Stagger" or "Backward", false
	end
	if roll < 0.35 then
		return "Backward", false
	elseif roll < 0.6 then
		return "Knees", false
	elseif roll < 0.8 then
		return "Stagger", false
	end
	return "Forward", false
end

function Death.Play(agent)
	local model = agent.model
	local root = agent.root
	local style, mirror = pick(agent)
	local clip = NPCAnimation.Deaths[style]
	model:SetAttribute("DeathStyle", style)

	root.AssemblyLinearVelocity = Vector3.zero
	root.Anchored = true
	Effects.Send(root.Position, "Death", model, style, mirror)

	task.delay(clip.duration, function()
		if not model.Parent or not root.Parent then
			return
		end
		Body.ApplyPose(agent, NPCAnimation.DeathFinal(style, mirror))
		RunService.Heartbeat:Wait()
		if not model.Parent then
			return
		end

		-- Thrown the way the death was already falling, in the body's own frame.
		local push = clip.push
		if mirror then
			push = Vector3.new(-push.X, push.Y, push.Z)
		end
		agent.humanoid:SetAttribute("LastHitDirection", root.CFrame:VectorToWorldSpace(push))
		root.Anchored = false
		CombatDeath.Kill(model)
		-- The arms are loose now; stop every client holding a weapon pose on them.
		if agent.scale == 1 then
			pcall(WeaponPose.Clear, model)
		end
	end)
end

return Death
