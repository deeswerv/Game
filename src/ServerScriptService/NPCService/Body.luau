--!strict
-- The NPC's body: building it, dressing it, arming it, and turning it.
--
-- Every NPC is the SAME R15 rig the players wear -- StarterPlayer.StarterCharacter, the
-- locked ROBLOX Boy body -- recoloured per archetype. That one decision is what lets the
-- rest of the game treat an enemy exactly like a player:
--
--   * WeaponPose and ArmSolver measure their arm solve off StarterCharacter. An NPC with
--     identical proportions gets the identical, already-verified two-handed weapon hold.
--   * ReloadAnimator's hand targets and magazine drop land on the same hands.
--   * GunHandler's hit zones already name every R15 part, so headshots just work.
--   * RagdollBuilder already builds R15 sockets from the joints themselves.
--
-- The old body was whatever R6 rig happened to be lying in workspace first, with no Animate
-- script, which is why every enemy slid across the ground in a fixed pose.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local StarterPlayer = game:GetService("StarterPlayer")

local WeaponConfig = require(ReplicatedStorage.WeaponConfig)
local NPCAnimation = require(ReplicatedStorage.NPCAnimation)
local WeaponPose = require(ServerScriptService.WeaponPose)

local Body = {}

local REQUIRED_PARTS = {
	"HumanoidRootPart", "Head", "UpperTorso", "LowerTorso",
	"LeftUpperArm", "LeftLowerArm", "LeftHand", "RightUpperArm", "RightLowerArm", "RightHand",
	"LeftUpperLeg", "LeftLowerLeg", "LeftFoot", "RightUpperLeg", "RightLowerLeg", "RightFoot",
}

local REQUIRED_JOINTS = {
	Neck = "Head", Waist = "UpperTorso", Root = "LowerTorso",
	LeftShoulder = "LeftUpperArm", LeftElbow = "LeftLowerArm", LeftWrist = "LeftHand",
	RightShoulder = "RightUpperArm", RightElbow = "RightLowerArm", RightWrist = "RightHand",
	LeftHip = "LeftUpperLeg", LeftKnee = "LeftLowerLeg", LeftAnkle = "LeftFoot",
	RightHip = "RightUpperLeg", RightKnee = "RightLowerLeg", RightAnkle = "RightFoot",
}

-- The same rule RigNormalise applies to players. This Roblox build rigs R15 bodies with
-- AnimationConstraint + BallSocketConstraint pairs alongside the Motor6Ds, and while those
-- exist every Motor6D write in the game is silently ignored.
local function isEngineRigging(inst: Instance): boolean
	return inst:IsA("AnimationConstraint")
		or (inst:IsA("BallSocketConstraint") and inst.Name:sub(-10) == "BallSocket")
end

--- A Motor6D by name AND class; a same-named AnimationConstraint can sit beside it.
function Body.FindMotor(parent: Instance?, name: string): Motor6D?
	if not parent then
		return nil
	end
	for _, child in ipairs(parent:GetChildren()) do
		if child:IsA("Motor6D") and child.Name == name then
			return child
		end
	end
	return nil
end

local template: Model? = nil
local templateChecked = false

local function getTemplate(): Model?
	if templateChecked then
		return template
	end
	templateChecked = true

	local source = StarterPlayer:FindFirstChild("StarterCharacter")
	if not source or not source:IsA("Model") then
		warn("[NPC] StarterPlayer.StarterCharacter is missing -- NPCs use it as their R15 body")
		return nil
	end
	local rig = source:Clone()
	for _, d in ipairs(rig:GetDescendants()) do
		if d.Parent and (d:IsA("LuaSourceContainer") or isEngineRigging(d) or d:IsA("BodyColors")) then
			d:Destroy()
		end
	end

	local missing = {}
	for _, name in ipairs(REQUIRED_PARTS) do
		if not rig:FindFirstChild(name) then
			table.insert(missing, name)
		end
	end
	for joint, partName in pairs(REQUIRED_JOINTS) do
		if not Body.FindMotor(rig:FindFirstChild(partName), joint) then
			table.insert(missing, joint .. " (Motor6D)")
		end
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.RigType ~= Enum.HumanoidRigType.R15 then
		table.insert(missing, "R15 Humanoid")
	end
	if #missing > 0 then
		warn("[NPC] StarterCharacter is not a complete R15 rig; missing: " .. table.concat(missing, ", "))
		rig:Destroy()
		return nil
	end

	if not (humanoid :: Humanoid):FindFirstChildOfClass("Animator") then
		Instance.new("Animator").Parent = humanoid
	end
	template = rig
	return rig
end

-- ------------------------------------------------------------------ dressing --

local SKIN = { Head = true, LeftHand = true, RightHand = true, LeftLowerArm = true, RightLowerArm = true }
local SLEEVES = { LeftUpperArm = true, RightUpperArm = true }
local SHIRT = { UpperTorso = true }
local PANTS = {
	LowerTorso = true, LeftUpperLeg = true, RightUpperLeg = true,
	LeftLowerLeg = true, RightLowerLeg = true,
}
local BOOTS = { LeftFoot = true, RightFoot = true }

local function colourFor(partName: string, cfg): Color3?
	if SKIN[partName] then
		return cfg.Skin
	elseif SLEEVES[partName] then
		return cfg.Sleeves and cfg.Shirt or cfg.Skin
	elseif SHIRT[partName] then
		return cfg.Shirt
	elseif PANTS[partName] then
		return cfg.Pants
	elseif BOOTS[partName] then
		return cfg.Boots or (cfg.Pants :: Color3):Lerp(Color3.new(0, 0, 0), 0.45)
	end
	return nil
end

local function dress(model: Model, cfg)
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			local colour = colourFor(part.Name, cfg)
			if colour then
				part.Color = colour
			end
			part.Material = Enum.Material.SmoothPlastic
		end
	end

	for _, accent in ipairs(cfg.Accents or {}) do
		local host = model:FindFirstChild(accent.part)
		if host and host:IsA("BasePart") then
			local piece = Instance.new("Part")
			piece.Name = "Accent"
			piece.Size = accent.size
			piece.Color = accent.colour
			piece.Material = Enum.Material.SmoothPlastic
			piece.TopSurface = Enum.SurfaceType.Smooth
			piece.BottomSurface = Enum.SurfaceType.Smooth
			-- Dressing never changes a hitbox: shots pass straight through to the body,
			-- so a helmet does not turn a headshot into a miss.
			piece.CanCollide = false
			piece.CanQuery = false
			piece.CanTouch = false
			piece.Massless = true
			piece.CFrame = host.CFrame * CFrame.new(accent.offset)
			piece.Parent = model

			local weld = Instance.new("WeldConstraint")
			weld.Part0 = host
			weld.Part1 = piece
			weld.Parent = piece
		elseif accent.part then
			warn(("[NPC] %s accent names a part the R15 body does not have: %s")
				:format(tostring(cfg.Archetype), tostring(accent.part)))
		end
	end
end

--- A fresh, dressed, scaled body for `cfg`. Not yet parented.
function Body.Build(cfg): (Model?, Humanoid?, BasePart?)
	local rig = getTemplate()
	if not rig then
		return nil, nil, nil
	end
	local model = rig:Clone()
	local humanoid = model:FindFirstChildOfClass("Humanoid") :: Humanoid
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart

	humanoid.MaxHealth = cfg.MaxHealth
	humanoid.Health = cfg.MaxHealth
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false

	dress(model, cfg)

	-- Size last: ScaleTo moves everything, welded accents and joint offsets included.
	if cfg.Scale and cfg.Scale ~= 1 then
		local ok, err = pcall(function()
			model:ScaleTo(cfg.Scale)
		end)
		if not ok then
			warn("[NPC] could not scale " .. tostring(cfg.Archetype) .. ": " .. tostring(err))
		end
	end
	-- After scaling, not before: ScaleTo multiplies WalkSpeed by the scale too, which gave a
	-- Warlord 14.85 instead of its 11 until the first time it moved.
	humanoid.WalkSpeed = cfg.WalkSpeed

	-- The whole body streams in and out together. A half-streamed rig on a client has
	-- joints with nothing on one end, which is how animation scripts end up erroring.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
	model.PrimaryPart = root

	-- Turning is done with a constraint rather than by writing the root's CFrame each tick.
	-- A CFrame write fights the humanoid's own physics and stutters on every client; this
	-- is solved inside the physics step and replicates as smooth motion.
	local attachment = Instance.new("Attachment")
	-- Named apart from the constraint: two children called the same thing and FindFirstChild
	-- hands back whichever it meets first.
	attachment.Name = "NPCFacingAttachment"
	attachment.Parent = root
	local align = Instance.new("AlignOrientation")
	align.Name = "NPCFacing"
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.Attachment0 = attachment
	align.MaxTorque = 400000
	align.Responsiveness = 22
	align.Enabled = false
	align.Parent = root

	return model, humanoid, root
end

--- Record the rest pose of every joint the death animation moves, AFTER scaling.
function Body.CaptureRest(agent)
	local rest = {}
	for joint, partName in pairs(NPCAnimation.JointPart) do
		local motor = Body.FindMotor(agent.model:FindFirstChild(partName), joint)
		if motor then
			rest[joint] = { motor = motor, c0 = motor.C0 }
		end
	end
	agent.rest = rest
end

--- Write a pose onto the joints on the SERVER. Used once, for the last frame of a death, so
--- the ragdoll starts from the pose every client just watched.
function Body.ApplyPose(agent, pose)
	local scale = agent.scale or 1
	for joint, key in pairs(pose) do
		local entry = agent.rest and agent.rest[joint]
		if entry and entry.motor.Parent then
			local base = entry.c0
			if joint == "Waist" then
				-- A gun holder's waist is bladed by the client from this attribute, not by the
				-- server, so the death has to start from that stance too.
				local bladed = agent.model:GetAttribute("PoseWaist")
				if typeof(bladed) == "CFrame" then
					base = bladed
				end
			end
			local posed = base * NPCAnimation.ToCFrame(key, scale)
			entry.motor.C0 = posed
			-- The ragdoll's socket for this joint was built around the REST pose, with angle
			-- limits measured from it. A knee bent past that limit would be snapped straight
			-- the instant the ragdoll took over, so the socket is re-centred on the pose.
			local part0 = entry.motor.Part0
			local socketFrame = part0 and part0:FindFirstChild(joint .. "RagdollAtt0")
			if socketFrame and socketFrame:IsA("Attachment") then
				socketFrame.CFrame = posed
			end
		end
	end
end

-- ------------------------------------------------------------------ weapons --

--- A Tool copy of a store weapon that is safe to put in an NPC's hands: no scripts, no
--- prompts, no collision, and invisible to raycasts so shooting the gun does not count as
--- shooting the body.
function Body.MakeWeapon(name: string): (Tool?, any)
	local store = ReplicatedStorage:FindFirstChild("storeitems")
	local source = store and store:FindFirstChild(name)
	if not source or not source:IsA("Tool") then
		warn("[NPC] weapon '" .. tostring(name) .. "' is not a Tool in ReplicatedStorage.storeitems")
		return nil, nil
	end
	local wcfg = WeaponConfig.Get(name)
	if not wcfg then
		warn("[NPC] weapon '" .. tostring(name) .. "' has no WeaponConfig entry")
		return nil, nil
	end
	local tool = source:Clone()
	for _, d in ipairs(tool:GetDescendants()) do
		if d.Parent then
			if d:IsA("LuaSourceContainer") or d:IsA("ProximityPrompt") or d:IsA("ClickDetector") then
				d:Destroy()
			elseif d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Massless = true
			end
		end
	end
	tool.CanBeDropped = false
	tool:SetAttribute("NPCWeapon", true)
	return tool, wcfg
end

--- Put weapon slot `slot` in the NPC's hand, stowing whatever it held.
function Body.Equip(agent, slot: number)
	local entry = agent.weapons[slot]
	if not entry then
		return
	end
	local model = agent.model
	for _, child in ipairs(model:GetChildren()) do
		if child:IsA("Tool") and child ~= entry.tool then
			-- Out of the world but still referenced, so it can come back without rebuilding.
			child.Parent = nil
		end
	end
	if entry.tool.Parent ~= model then
		agent.humanoid:EquipTool(entry.tool)
	end
	agent.slot = slot

	-- The solved hold only exists for guns on an unscaled body, because ArmSolver measures
	-- the arm once, off the unscaled StarterCharacter. A melee weapon keeps the plain
	-- tool-hold animation and the client's swing layer.
	if entry.cfg.Type == "Gun" and agent.scale == 1 then
		agent.posable = true
		task.defer(function()
			if agent.alive and entry.tool.Parent == model then
				local ok, err = pcall(WeaponPose.Apply, model, entry.tool.Name)
				if not ok then
					warn("[NPC] weapon pose failed for " .. model.Name .. ": " .. tostring(err))
				end
			end
		end)
	else
		agent.posable = false
		-- Clear writes the UNSCALED rest shoulders back, which on a Brute's scaled body
		-- would pull both arms into its chest. Nothing was published for a scaled body, so
		-- there is nothing to clear there anyway.
		if agent.scale == 1 then
			pcall(WeaponPose.Clear, model)
		end
	end
end

-- ---------------------------------------------------------------- stance --

--- Raise or lower the weapon, or carry it at a run. Re-solves the hold only on a change.
function Body.SetStance(agent, aiming: boolean, sprinting: boolean)
	if agent.aiming == aiming and agent.sprinting == sprinting then
		return
	end
	agent.aiming, agent.sprinting = aiming, sprinting
	local model = agent.model
	model:SetAttribute("Aiming", aiming)
	model:SetAttribute("Sprinting", sprinting)
	local entry = agent.weapons and agent.weapons[agent.slot]
	if agent.posable and entry and entry.tool.Parent == model then
		pcall(WeaponPose.Apply, model, entry.tool.Name)
	end
end

--- Tilt the weapon toward a point. Published the same way a player's camera pitch is.
function Body.AimAt(agent, point: Vector3?)
	local pitch = 0
	if point then
		local head = agent.model:FindFirstChild("Head") :: BasePart?
		local from = head and head.Position or agent.root.Position
		local offset = point - from
		if offset.Magnitude > 0.1 then
			pitch = math.deg(math.asin(math.clamp(offset.Unit.Y, -1, 1)))
		end
	end
	pitch = math.clamp(pitch, -55, 55)
	if math.abs(pitch - (agent.aimPitch or 0)) >= 1.5 then
		agent.aimPitch = pitch
		agent.model:SetAttribute("AimPitch", pitch)
	end
end

--- Face a point, or hand facing back to the humanoid's own walk direction with nil.
function Body.Face(agent, point: Vector3?)
	local root = agent.root
	local align = root:FindFirstChild("NPCFacing")
	if not align or not align:IsA("AlignOrientation") then
		return
	end
	if point then
		local flat = Vector3.new(point.X - root.Position.X, 0, point.Z - root.Position.Z)
		if flat.Magnitude > 0.2 then
			align.CFrame = CFrame.lookAt(Vector3.zero, flat.Unit)
			if not align.Enabled then
				align.Enabled = true
				agent.humanoid.AutoRotate = false
			end
		end
	elseif align.Enabled then
		align.Enabled = false
		agent.humanoid.AutoRotate = true
	end
end

return Body
