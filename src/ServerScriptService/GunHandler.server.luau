--!strict
-- Weapon system, server side. Drives every weapon in ReplicatedStorage.WeaponConfig.
--
-- The client says "I fired, aiming roughly here". The server decides everything that
-- matters: whether enough time has passed, whether there was ammo, where the shot
-- actually goes (it applies its own spread), what it hit, and how much damage it did.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Debris = game:GetService("Debris")

local WeaponConfig = require(ReplicatedStorage.WeaponConfig)
local KillCredit = require(ServerScriptService.KillCredit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GunAction = Remotes:WaitForChild("GunAction") :: RemoteEvent

-- Fired back at clients so they can draw the shot everyone else sees.
local GunEffect = Remotes:FindFirstChild("GunEffect")
if not GunEffect then
	GunEffect = Instance.new("RemoteEvent")
	GunEffect.Name = "GunEffect"
	GunEffect.Parent = Remotes
end

local MAX_ORIGIN_DRIFT = 24     -- studs the muzzle may be from the shooter
local RATE_GRACE = 0.02         -- absorb a little network jitter on fire rate

-- ------------------------------------------------------------------ noise --
--
-- A shot is heard by anything nearby that is not already in a fight. NPCs are told a place,
-- never a name, so gunfire draws a patrol over to look rather than handing them your
-- position -- and a suppressor really does halve how far that reaches.
--
-- Required lazily: this script runs before GameBootstrap brings NPCService up, and requiring
-- it at the top would start the NPC world early, out of dependency order.
local NPCService: any = nil
local lastNoise: { [Player]: number } = {}

local function reportNoise(player: Player, origin: Vector3, cfg, tool: Tool)
	local now = os.clock()
	-- One noise per half second per shooter: a magazine is a firefight, not thirty separate
	-- events to sweep the crowd for.
	if now - (lastNoise[player] or -math.huge) < 0.5 then
		return
	end
	lastNoise[player] = now
	if NPCService == nil then
		local module = ServerScriptService:FindFirstChild("NPCService")
		local ok, service = pcall(require, module)
		NPCService = (ok and service) or false
	end
	if NPCService and NPCService.Noise and player.Character then
		NPCService.Noise(origin, WeaponConfig.NoiseRadius(cfg, tool), player.Character)
	end
end

-- Per-tool runtime state, keyed by the Tool instance so two players holding the same
-- weapon type never share a cooldown.
local state: { [Instance]: any } = {}

local function stateFor(tool: Tool, cfg)
	local st = state[tool]
	if not st then
		st = {
			lastShot = 0,
			heat = 0,
			lastHeatUpdate = os.clock(),
			reloading = false,
			-- Bumped every time a reload starts or is abandoned. A reload only completes if
			-- the token it captured is still current, which is what stops an interrupted
			-- reload from landing its ammo later.
			reloadToken = 0,
		}
		state[tool] = st
		tool.Destroying:Connect(function()
			state[tool] = nil
		end)
	end
	return st
end

-- Spread bleeds off over time; this brings it up to date before it is read or added to.
local function updateHeat(st, cfg)
	local now = os.clock()
	local dt = now - st.lastHeatUpdate
	st.lastHeatUpdate = now
	st.heat = math.max(0, st.heat - cfg.SpreadRecovery * dt)
end

local function currentSpread(st, cfg, ads: boolean): number
	updateHeat(st, cfg)
	local spread = math.clamp(cfg.SpreadMin + st.heat, cfg.SpreadMin, cfg.SpreadMax)
	if ads then
		spread *= cfg.AdsSpreadScale
	end
	return spread
end

-- Rotate a direction by a random cone of `degrees`.
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

-- ------------------------------------------------------- damage model --
--
-- Range used to decide only whether a shot CONNECTED. A Warden did its full damage at one
-- stud and at four hundred and forty nine, which makes every weapon a sniper and flattens
-- the difference between a shotgun and a rifle to nothing.
--
-- Falloff is expressed as fractions of each weapon's own Range, so all twelve get a sensible
-- curve with no new config, and any weapon that wants a different shape can still say so by
-- setting the absolute values in WeaponConfig.
local FALLOFF_START_FRACTION = 0.35   -- full damage out to here
local FALLOFF_END_FRACTION = 0.90     -- and the floor from here on
local FALLOFF_FLOOR = 0.45            -- never less than this fraction of the listed damage

local function falloffScalar(cfg, distance: number): number
	local range = cfg.Range or 300
	local startAt = cfg.FalloffStart or range * FALLOFF_START_FRACTION
	local endAt = cfg.FalloffEnd or range * FALLOFF_END_FRACTION
	local floor = cfg.FalloffMin or FALLOFF_FLOOR
	if distance <= startAt then
		return 1
	end
	if distance >= endAt then
		return floor
	end
	local t = (distance - startAt) / math.max(endAt - startAt, 1e-3)
	return 1 + (floor - 1) * t
end

-- Where on the body the round landed.
--
-- R15 splits a character across fifteen parts, so this maps them to the three zones that
-- actually matter rather than naming every one. R6 names are here too, because the NPCs are
-- still R6 rigs and a shot to a Bandit's arm should read the same as a shot to a player's.
local LIMB_PARTS: { [string]: boolean } = {
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true,
	RightUpperArm = true, RightLowerArm = true, RightHand = true,
	LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true,
	RightUpperLeg = true, RightLowerLeg = true, RightFoot = true,
	["Left Arm"] = true, ["Right Arm"] = true, ["Left Leg"] = true, ["Right Leg"] = true,
}

-- Returns the damage this hit deals, and whether it was a headshot.
local function damageFor(cfg, partName: string, distance: number): (number, boolean)
	local headshot = partName == "Head"
	local zone = 1
	if headshot then
		zone = cfg.HeadshotMultiplier or 1.5
	elseif LIMB_PARTS[partName] then
		-- Limbs are a genuine miss-adjacent hit. Anything else -- torso, root, accessories --
		-- is a clean body shot and takes full damage.
		zone = cfg.LimbMultiplier or 0.8
	end
	return cfg.Damage * zone * falloffScalar(cfg, distance), headshot
end

local function ensureAmmo(tool: Tool, cfg)
	if tool:GetAttribute("Ammo") == nil then
		tool:SetAttribute("Ammo", cfg.MagazineSize)
	end
	if tool:GetAttribute("MaxAmmo") ~= cfg.MagazineSize then
		tool:SetAttribute("MaxAmmo", cfg.MagazineSize)
	end
	-- Swapping to a build with a smaller magazine must not leave rounds hanging over the
	-- new capacity. Deliberately one-way: a bigger magazine does NOT hand out free rounds,
	-- or swapping builds would be a reload.
	local ammo = tool:GetAttribute("Ammo")
	if type(ammo) == "number" and ammo > cfg.MagazineSize then
		tool:SetAttribute("Ammo", cfg.MagazineSize)
	end
end

-- Abandon a reload in progress without giving out the ammo. Used when the weapon is put
-- away, the tool is destroyed, or the player dies mid-reload: the ammo is only ever
-- granted by the completion path, so an interrupted reload simply does not happen.
local function cancelReload(tool: Tool, player: Player?)
	local st = state[tool]
	if not st or not st.reloading then
		return
	end
	st.reloadToken += 1
	st.reloading = false
	if tool.Parent then
		tool:SetAttribute("Reloading", false)
	end
	-- The player, not the tool, identifies whose arms to put back: by the time a weapon
	-- is unequipped its parent is the backpack, so the tool no longer knows the character.
	GunEffect:FireAllClients("ReloadCancel", player or Players:GetPlayerFromCharacter(st.owner))
end

local function reload(player: Player, tool: Tool, cfg)
	local st = stateFor(tool, cfg)
	if st.reloading then
		return                       -- already reloading: ignore, do not restart
	end
	ensureAmmo(tool, cfg)

	local ammo = tool:GetAttribute("Ammo") or 0
	if ammo >= cfg.MagazineSize then
		return                       -- magazine already full
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 or tool.Parent ~= character then
		return                       -- dead, or the weapon is not actually in hand
	end

	-- Whether the action needs racking: only when the chamber ran dry. A partial reload
	-- leaves a round chambered, so the weapon does not get charged for no reason.
	local needsCharge = cfg.ChargePart ~= nil
		and (cfg.ChargeWhenEmpty == false or ammo <= 0)

	st.reloadToken += 1
	local token = st.reloadToken
	st.reloading = true
	st.owner = character          -- remembered so a cancel knows whose arms to reset
	tool:SetAttribute("Reloading", true)

	-- One broadcast for the whole reload. Every client animates it from here; the stages
	-- are timed client side rather than streamed, so this costs one remote, not seven.
	GunEffect:FireAllClients("Reload", player, tool, needsCharge, cfg.ReloadTime)

	task.delay(cfg.ReloadTime, function()
		-- The only place ammo is granted, and only if this exact reload is still the live
		-- one. Ammo cannot be duplicated by reload timing because nothing else adds it.
		if st.reloadToken ~= token or not st.reloading then
			return
		end
		st.reloading = false
		st.heat = 0
		if tool.Parent then
			tool:SetAttribute("Ammo", cfg.MagazineSize)
			tool:SetAttribute("Reloading", false)
		end
	end)
end

local function fire(player: Player, tool: Tool, cfg, aimPoint: Vector3, ads: boolean)
	local st = stateFor(tool, cfg)
	if st.reloading then
		return
	end

	ensureAmmo(tool, cfg)
	local ammo = tool:GetAttribute("Ammo") or 0
	if ammo <= 0 then
		reload(player, tool, cfg)
		return
	end

	-- Server-side rate limit. The client has its own, purely so the gun feels right.
	local now = os.clock()
	if now - st.lastShot < cfg.FireRate - RATE_GRACE then
		return
	end
	st.lastShot = now

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not character or not humanoid or humanoid.Health <= 0 then
		return
	end

	local muzzle = tool:FindFirstChild("Muzzle") or tool:FindFirstChild("Handle")
	if not muzzle or not muzzle:IsA("BasePart") then
		return
	end
	local origin = muzzle.Position

	local root = character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") and (origin - root.Position).Magnitude > MAX_ORIGIN_DRIFT then
		return -- muzzle nowhere near the shooter: ignore
	end

	tool:SetAttribute("Ammo", ammo - 1)

	local baseDir = aimPoint - origin
	if baseDir.Magnitude < 0.01 then
		return
	end
	baseDir = baseDir.Unit

	local spread = currentSpread(st, cfg, ads)
	st.heat = math.min(st.heat + cfg.SpreadPerShot, cfg.SpreadMax)

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character, workspace:FindFirstChild("Debris") }

	local endPoints = {}

	-- Victims are collected across the whole shot and broadcast once at the end. Firing a
	-- flash per pellet would send eight near-identical events to every client for a single
	-- shotgun blast, and they would all land on the same target anyway.
	--
	-- (falloff and hit zones are defined above this function; see damageFor)
	local struck: { [Model]: boolean } = {}
	local struckList: { Model } = {}
	local killed: { [Model]: boolean } = {}

	for _ = 1, cfg.PelletsPerShot do
		local dir = applySpread(baseDir, spread)
		local result = workspace:Raycast(origin, dir * cfg.Range, params)
		local hitPos = result and result.Position or (origin + dir * cfg.Range)
		table.insert(endPoints, hitPos)

		if result then
			local model = result.Instance:FindFirstAncestorOfClass("Model")
			local victim = model and model:FindFirstChildOfClass("Humanoid")
			if victim and victim ~= humanoid and victim.Health > 0 then
				local damage, headshot =
					damageFor(cfg, result.Instance.Name, (hitPos - origin).Magnitude)
				-- What actually lands after the victim's armour. KillCredit.Damage applies the
				-- armour itself; this is only so the number and the kill flag tell the truth.
				local dealt = KillCredit.Mitigate(victim, damage)
				-- Whether this round finishes them has to be decided before the damage is
				-- applied, or the health is already zero by the time it is read and every
				-- hit looks like a kill.
				local lethal = dealt >= victim.Health
				-- Where it landed, for the victim's hit reaction and death. Presentation only.
				victim:SetAttribute("LastHitPart", result.Instance.Name)
				-- Through KillCredit so kills and XP land on the shooter. The weapon and the
				-- direction of the shot ride along so a killing blow can throw the body the
				-- way the round was travelling.
				KillCredit.Damage(victim, damage, player, tool.Name, dir)
				GunEffect:FireClient(player, "Hitmarker", headshot, lethal)
				-- Only the shooter gets the number. Everyone seeing everyone's damage turns
				-- a firefight into unreadable confetti.
				GunEffect:FireClient(player, "Damage", hitPos, dealt, headshot, lethal)

				if model and not struck[model] then
					struck[model] = true
					table.insert(struckList, model)
				end
				if lethal and model then
					killed[model] = true
				end
			end
		end
	end

	-- Everyone draws the tracer, muzzle flash and impact locally.
	GunEffect:FireAllClients("Shot", player, tool, origin, endPoints)
	reportNoise(player, origin, cfg, tool)

	-- And everyone sees what was hit flare, which is the clearest read that a shot landed.
	if #struckList > 0 then
		local lethalFlags = table.create(#struckList)
		for i, m in ipairs(struckList) do
			lethalFlags[i] = killed[m] == true
		end
		GunEffect:FireAllClients("HitFlash", struckList, lethalFlags)
	end
end

GunAction.OnServerEvent:Connect(function(player, action, tool, aimPoint, ads)
	-- Only an equipped Tool (parented to the character) can act, and only one the
	-- config knows about.
	if typeof(tool) ~= "Instance" or not tool:IsA("Tool") then
		return
	end
	if not player.Character or tool.Parent ~= player.Character then
		return
	end
	-- .For rather than .Get: this is the weapon as the player's equipped build made it,
	-- so an extended magazine really holds more and a suppressor really costs range. The
	-- modified numbers were written onto the Tool by the server, never by the client.
	local cfg = WeaponConfig.For(tool)
	if not cfg or cfg.Type ~= "Gun" then
		return
	end

	if action == "shoot" then
		if typeof(aimPoint) ~= "Vector3" then
			return
		end
		fire(player, tool, cfg, aimPoint, ads == true)
	elseif action == "reload" then
		reload(player, tool, cfg)
	end
end)

-- Top the magazine up when a weapon is first handed out, and make sure a reload that is
-- interrupted by the weapon leaving the player's hands is dropped rather than left to
-- complete in the background.
local hooked: { [Tool]: boolean } = {}

local function prepareTool(tool: Tool)
	local cfg = WeaponConfig.For(tool)
	if not cfg or cfg.Type ~= "Gun" then
		return
	end
	ensureAmmo(tool, cfg)

	if hooked[tool] then
		return
	end
	hooked[tool] = true

	-- Putting the weapon away, or swapping to another one, abandons the reload.
	tool.Unequipped:Connect(function()
		cancelReload(tool)
	end)
	tool.Destroying:Connect(function()
		cancelReload(tool)
		hooked[tool] = nil
	end)

	-- Changing build changes the magazine, and the HUD reads MaxAmmo. Without this the
	-- ammo counter keeps the old capacity until the next shot or reload.
	tool:GetAttributeChangedSignal("Stat_MagazineSize"):Connect(function()
		local live = WeaponConfig.For(tool)
		if live and live.Type == "Gun" then
			ensureAmmo(tool, live)
		end
	end)
end

local function watchPlayer(player: Player)
	local function watch(container: Instance)
		container.ChildAdded:Connect(function(child)
			if child:IsA("Tool") then
				prepareTool(child)
			end
		end)
		for _, child in ipairs(container:GetChildren()) do
			if child:IsA("Tool") then
				prepareTool(child)
			end
		end
	end

	local function watchCharacter(char: Model)
		watch(char)
		-- Dying mid-reload drops it too, so respawning never hands back a free magazine.
		local humanoid = char:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				for _, child in ipairs(char:GetChildren()) do
					if child:IsA("Tool") then
						cancelReload(child, player)
					end
				end
			end)
		end
		local bp = player:WaitForChild("Backpack", 10)
		if bp then
			watch(bp)
		end
	end

	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		watch(backpack)
	end
	if player.Character then
		task.spawn(watchCharacter, player.Character)
	end
	player.CharacterAdded:Connect(watchCharacter)
end

Players.PlayerAdded:Connect(watchPlayer)
Players.PlayerRemoving:Connect(function(player)
	lastNoise[player] = nil
end)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(watchPlayer, p)
end
