--!strict
-- Melee combat for any weapon whose config sets GenericMelee = true.
--
-- The Greatsword and Blood Sword keep their own bespoke scripts; this exists so new
-- melee weapons are a config entry rather than another pile of per-weapon code.
-- Same contract as the gun system: the client says "I swung", the server decides
-- cooldown, arc, damage and knockback.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")

local WeaponConfig = require(ReplicatedStorage.WeaponConfig)
local KillCredit = require(ServerScriptService.KillCredit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function ensureRemote(className: string, name: string)
	local existing = Remotes:FindFirstChild(name)
	if existing then
		return existing
	end
	local r = Instance.new(className)
	r.Name = name
	r.Parent = Remotes
	return r
end

local MeleeAction = ensureRemote("RemoteEvent", "MeleeAction") :: RemoteEvent
local MeleeEffect = ensureRemote("RemoteEvent", "MeleeEffect") :: RemoteEvent

local MeleeHandler = {}

local COMBO_RESET = 1.6   -- seconds of no swinging before the combo drops

-- Per-tool swing state, keyed by the Tool so two players never share a cooldown.
local state: { [Instance]: any } = {}

local function stateFor(tool: Tool)
	local st = state[tool]
	if not st then
		st = { lastSwing = 0, combo = 0 }
		state[tool] = st
		tool.Destroying:Connect(function()
			state[tool] = nil
		end)
	end
	return st
end

-- Everything with a Humanoid inside the cone in front of the attacker.
local function targetsInArc(character: Model, root: BasePart, cfg)
	local hits = {}
	local seen = {}
	local origin = root.Position
	local forward = root.CFrame.LookVector
	local halfArc = math.cos(math.rad(cfg.MeleeArc / 2))

	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }

	for _, part in ipairs(workspace:GetPartBoundsInRadius(origin, cfg.MeleeRange, params)) do
		local model = part:FindFirstAncestorOfClass("Model")
		local humanoid = model and model:FindFirstChildOfClass("Humanoid")
		if humanoid and not seen[humanoid] and humanoid.Health > 0 then
			local victimRoot = model:FindFirstChild("HumanoidRootPart") or model:FindFirstChild("Torso")
			if victimRoot and victimRoot:IsA("BasePart") then
				local toVictim = victimRoot.Position - origin
				local flat = Vector3.new(toVictim.X, 0, toVictim.Z)
				if flat.Magnitude > 0.01 and flat.Unit:Dot(Vector3.new(forward.X, 0, forward.Z).Unit) >= halfArc then
					seen[humanoid] = true
					table.insert(hits, { humanoid = humanoid, model = model, root = victimRoot })
				end
			end
		end
	end
	return hits
end

local function swing(player: Player, tool: Tool, cfg)
	local st = stateFor(tool)
	local now = os.clock()
	if now - st.lastSwing < cfg.SwingTime then
		return
	end

	-- Combo builds while you keep swinging, and lapses if you stop.
	if now - st.lastSwing > COMBO_RESET then
		st.combo = 0
	end
	st.lastSwing = now
	st.combo = (st.combo % cfg.ComboCount) + 1

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not character or not humanoid or not root or humanoid.Health <= 0 then
		return
	end

	-- Later hits in a combo land harder.
	local damage = cfg.Damage * (1 + (st.combo - 1) * cfg.ComboDamageStep)

	local hits = targetsInArc(character, root :: BasePart, cfg)
	local drained = 0
	for _, hit in ipairs(hits) do
		if hit.humanoid ~= humanoid then
			local dealt = damage

			-- Backstab: are we behind them, and facing the same way they are?
			if cfg.BackstabMultiplier and cfg.BackstabMultiplier > 1 then
				local victimForward = hit.root.CFrame.LookVector
				local attackerForward = (root :: BasePart).CFrame.LookVector
				if victimForward:Dot(attackerForward) > 0.4 then
					dealt *= cfg.BackstabMultiplier
				end
			end

			-- Weapon and swing direction ride along so a killing blow throws the body the
			-- way the swing was going.
			local swing = hit.root.Position - (root :: BasePart).Position
			KillCredit.Damage(hit.humanoid, math.floor(dealt), player, tool.Name,
				swing.Magnitude > 0.1 and swing.Unit or nil)

			-- A weapon that heals what it takes. Server side, off damage that has already been
			-- validated, so it cannot be farmed by a client claiming hits.
			if cfg.Lifesteal and cfg.Lifesteal > 0 then
				drained += dealt * cfg.Lifesteal
			end

			if cfg.Knockback > 0 then
				local dir = (hit.root.Position - root.Position)
				dir = Vector3.new(dir.X, 0, dir.Z)
				if dir.Magnitude > 0.01 then
					local push = Instance.new("BodyVelocity")
					push.MaxForce = Vector3.new(1e6, 1e6, 1e6)
					push.Velocity = dir.Unit * cfg.Knockback + Vector3.new(0, cfg.Knockback * 0.35, 0)
					push.Parent = hit.root
					Debris:AddItem(push, 0.18)
				end
			end
		end
	end

	-- Capped per swing, so cutting through a crowd tops you up rather than making you
	-- unkillable inside one.
	if drained > 0 and humanoid.Health > 0 then
		local cap = humanoid.MaxHealth * 0.15
		humanoid.Health = math.min(humanoid.MaxHealth, humanoid.Health + math.min(drained, cap))
	end

	MeleeEffect:FireAllClients(player, tool, st.combo, #hits)
end

MeleeAction.OnServerEvent:Connect(function(player, tool)
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
		return
	end
	-- Must actually be holding it.
	if not player.Character or tool.Parent ~= player.Character then
		return
	end
	local cfg = WeaponConfig.Get(tool.Name)
	if not cfg or cfg.Type ~= "Melee" or not cfg.GenericMelee then
		return
	end
	swing(player, tool, cfg)
end)

Players.PlayerRemoving:Connect(function(player)
	for tool in pairs(state) do
		if not tool.Parent then
			state[tool] = nil
		end
	end
end)

return MeleeHandler
