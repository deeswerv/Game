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
local Motion = require(ReplicatedStorage.Motion)
local WeaponPose = require(ServerScriptService.WeaponPose)
local Outfit = require(script.Parent.Outfit)

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

	-- What they wear (Outfit): each body draws its own colours from the archetype's palette.
	Outfit.Dress(model, cfg, cfg.OutfitSeed or math.random(1, 999999))

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

	if type(cfg.Shield) == "table" then
		Body.AttachShield(model, cfg.Shield)
	end

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

--- A Shieldbearer's shield: an iron slab held square in front of the body, from the neck to
--- the shins -- the head stays out, for anyone who can make the shot. The slab itself is what
--- stops rounds (GunHandler stops at anything with a ShieldHealth, takes the damage off it,
--- and breaks it at zero); its trim cannot be hit. Welded to the chest so it stays square
--- whatever the arms are doing.
function Body.AttachShield(model: Model, spec: { [string]: any })
	local torso = model:FindFirstChild("UpperTorso")
	if not torso or not torso:IsA("BasePart") then
		return
	end
	local scale = torso.Size.Y / 1.6
	local function piece(name: string, size: Vector3, offset: CFrame, colour: Color3, hittable: boolean, material: Enum.Material?): BasePart
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size * scale
		p.CFrame = torso.CFrame * CFrame.new(offset.Position * scale) * offset.Rotation
		p.Color = colour
		p.Material = material or Enum.Material.Metal
		p.Anchored = false
		p.Massless = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = hittable
		p.CastShadow = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = model
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = torso
		weld.Part1 = p
		weld.Parent = p
		return p
	end
	local front = CFrame.new(-0.25, -1.55, -1.35)
	local shield = piece("Shield", Vector3.new(3, 4.9, 0.35), front, Color3.fromRGB(40, 40, 48), true, Enum.Material.DiamondPlate)
	shield:SetAttribute("ShieldHealth", tonumber(spec.health) or 400)
	shield:SetAttribute("ShieldMax", tonumber(spec.health) or 400)
	for _, y in ipairs({ 2.35, -2.35 }) do
		piece("ShieldRim", Vector3.new(3.1, 0.25, 0.45), front * CFrame.new(0, y, 0), Color3.fromRGB(160, 36, 44), false)
	end
	for _, x in ipairs({ 1.5, -1.5 }) do
		piece("ShieldRim", Vector3.new(0.25, 4.9, 0.45), front * CFrame.new(x, 0, 0), Color3.fromRGB(160, 36, 44), false)
	end
	piece("ShieldCrest", Vector3.new(1.2, 1.2, 0.1), front * CFrame.new(0, 0.6, -0.22) * CFrame.Angles(0, 0, math.rad(45)),
		Color3.fromRGB(236, 190, 80), false)
	piece("ShieldSlit", Vector3.new(1.6, 0.18, 0.1), front * CFrame.new(0, 1.7, -0.22), Color3.fromRGB(14, 14, 18), false)
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
--- Crouch down (behind cover, bandaging) or stand back up. Everyone sees it the way they see
--- a player's crouch (the Crouching attribute; MotionAnimator bends the legs), and here the
--- hips really come down too, so a crouched NPC behind low cover is hidden from bullets as
--- well as from sight -- the server's hit boxes are the server's joints.
function Body.SetCrouch(agent: any, on: boolean)
	if (agent.crouching or false) == on then
		return
	end
	agent.crouching = on
	agent.model:SetAttribute("Crouching", on)
	local joint = Body.FindMotor(agent.model:FindFirstChild("LowerTorso"), "Root")
	if joint then
		agent.rootRest = agent.rootRest or joint.C0
		joint.C0 = if on then agent.rootRest * CFrame.new(0, -Motion.CROUCH_DROP * (agent.scale or 1), 0)
			else agent.rootRest
	end
end

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
