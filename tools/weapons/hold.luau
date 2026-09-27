--!nocheck
-- A character holding a weapon, posed by the game's own WeaponPose, in the Lune harness.
-- Shared by tools/weapons/holdview.luau (draws one) and tools/uitest/holds.luau (checks all).
--
--   local Hold = require("../weapons/hold")
--   local ctx = Hold.setup(World, Rig, place)
--   local result = Hold.pose(ctx, "Warden", "carry")   -- or "aim"
--   result.report  -> { yaw, pitch, leftHandToSupport, handToGrip, grip }
--   result.parts   -> the body and the weapon, laid out, for tools/weapons/preview.mjs
--
-- The rig is StarterPlayer.StarterCharacter. The tool goes in the right hand the way Roblox
-- welds it (RightGrip: C0 = the hand's RightGripAttachment, C1 = Tool.Grip), WeaponPose.Apply
-- solves the grip and both arms, and the body is laid out from its joints with the solved
-- shoulders, elbows and waist -- the pose the server publishes, before the client's sway.
local roblox = require("@lune/roblox")
local CFrame = roblox.CFrame

local Hold = {}

function Hold.setup(World, Rig, place)
	local R = World.R
	local sss = World.service("ServerScriptService")
	if not sss:FindFirstChild("WeaponPose") then
		R.mirror(place:GetService("ServerScriptService"):FindFirstChild("WeaponPose"), sss)
	end
	local rig = Rig.character(World, place)
	-- The mirror does not carry a joint's offsets; the arm solver measures the rig from them.
	-- The rig also carries AnimationConstraints named like its joints; the solver means the
	-- Motor6Ds, so the constraints are taken out of the copies it reads.
	local sourceChar = place:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
	for _, copy in ipairs({ rig, World.service("StarterPlayer"):FindFirstChild("StarterCharacter") }) do
		for _, d in ipairs(copy:GetDescendants()) do
			if d.ClassName == "AnimationConstraint" then
				d:Destroy()
			end
		end
		for _, m in ipairs(sourceChar:GetDescendants()) do
			if m:IsA("Motor6D") then
				local holder = copy:FindFirstChild(m.Parent.Name)
				for _, c in ipairs(holder and holder:GetChildren() or {}) do
					if c.ClassName == "Motor6D" and c.Name == m.Name then
						World.force(c, "C0", m.C0)
						World.force(c, "C1", m.C1)
					end
				end
			end
		end
		for _, a in ipairs(sourceChar:GetDescendants()) do
			if a:IsA("Attachment") then
				local holder = copy:FindFirstChild(a.Parent.Name)
				local c = holder and holder:FindFirstChild(a.Name)
				if c then
					World.force(c, "CFrame", a.CFrame)
				end
			end
		end
	end
	local joints = {}
	for _, m in ipairs(sourceChar:GetDescendants()) do
		if m:IsA("Motor6D") and m.Part0 and m.Part1 then
			table.insert(joints, { name = m.Name, p0 = m.Part0.Name, p1 = m.Part1.Name, c0 = m.C0, c1 = m.C1 })
		end
	end
	return {
		World = World, R = R, place = place, rig = rig, sourceChar = sourceChar, joints = joints,
		WeaponPose = World.require(sss.WeaponPose),
	}
end

local function copyAttachments(ctx, rawTool, copy, toolName)
	for _, a in ipairs(rawTool:GetDescendants()) do
		if a:IsA("Attachment") then
			local holder = a.Parent.Name == toolName and copy or copy:FindFirstChild(a.Parent.Name, true)
			local c = holder and holder:FindFirstChild(a.Name)
			if c then
				ctx.World.force(c, "CFrame", a.CFrame)
				ctx.World.force(c, "Position", a.CFrame.Position)
			end
		end
	end
end

function Hold.pose(ctx, toolName: string, stance: string?)
	local World, rig = ctx.World, ctx.rig
	rig:SetAttribute("Aiming", stance == "aim" or nil)

	-- The tool, in the hand. Attachment offsets (the authored mount points) do not come
	-- across in the mirror, so they are copied onto the equipped copy and the stored template
	-- both -- the solver reads the template.
	local store = World.service("ReplicatedStorage"):FindFirstChild("storeitems")
	local template = store:FindFirstChild(toolName)
	assert(template, "no such weapon: " .. tostring(toolName))
	local rawTool = ctx.place:GetService("ReplicatedStorage"):FindFirstChild("storeitems"):FindFirstChild(toolName)
	copyAttachments(ctx, rawTool, template, toolName)
	local tool = template:Clone()
	tool.Parent = rig
	copyAttachments(ctx, rawTool, tool, toolName)
	local hand = rig:FindFirstChild("RightHand")
	local gripAttachment = hand:FindFirstChild("RightGripAttachment")
	local weld = ctx.R.new("Weld")
	weld.Name = "RightGrip"
	World.force(weld, "Part0", hand)
	World.force(weld, "Part1", tool:FindFirstChild("Handle"))
	weld.C0 = gripAttachment and gripAttachment.CFrame or CFrame.new(0, -0.15, 0)
	weld.Parent = hand

	ctx.WeaponPose.Apply(rig, toolName)
	local grip = rig:GetAttribute("PoseGrip") or CFrame.new()

	-- Lay the body out from its joints, with the published pose in place of the rest pose.
	local override = {
		RightShoulder = rig:GetAttribute("PoseRightC0"),
		LeftShoulder = rig:GetAttribute("PoseLeftC0"),
		RightElbow = rig:GetAttribute("PoseRightElbow"),
		LeftElbow = rig:GetAttribute("PoseLeftElbow"),
		Waist = rig:GetAttribute("PoseWaist"),
	}
	local placed = { HumanoidRootPart = CFrame.new(0, 3, 0) }
	local progress = true
	while progress do
		progress = false
		for _, j in ipairs(ctx.joints) do
			if placed[j.p0] and not placed[j.p1] then
				placed[j.p1] = placed[j.p0] * (override[j.name] or j.c0) * j.c1:Inverse()
				progress = true
			end
		end
	end

	local parts = {}
	local function add(name, shape, size, cf, colour, material, transparency)
		local x, y, z, r00, r01, r02, r10, r11, r12, r20, r21, r22 = cf:GetComponents()
		table.insert(parts, {
			name = name, shape = shape, size = { size.X, size.Y, size.Z }, centre = { x, y, z },
			axes = { { r00, r01, r02 }, { r10, r11, r12 }, { r20, r21, r22 } },
			colour = colour, material = material, transparency = transparency or 0,
		})
	end
	for _, p in ipairs(ctx.sourceChar:GetChildren()) do
		if p:IsA("BasePart") and placed[p.Name] and p.Name ~= "HumanoidRootPart" then
			local tone = (p.Name:find("Hand") or p.Name == "Head") and { 0.93, 0.76, 0.6 } or { 0.35, 0.55, 0.85 }
			add(p.Name, "Block", p.Size, placed[p.Name], tone, "SmoothPlastic", 0)
		end
	end

	-- The weapon: Handle = hand * C0 * Grip^-1, and every part where it sits off the Handle.
	local handleCF = placed.RightHand * weld.C0 * grip:Inverse()
	local rawHandle = rawTool:FindFirstChild("Handle")
	for _, p in ipairs(rawTool:GetDescendants()) do
		if p:IsA("BasePart") and p ~= rawHandle and p.Transparency < 0.98 then
			local shape = "Block"
			if p:IsA("WedgePart") then
				shape = "Wedge"
			elseif p:IsA("Part") then
				shape = p.Shape.Name
			end
			add(p.Name, shape, p.Size, handleCF * rawHandle.CFrame:ToObjectSpace(p.CFrame),
				{ p.Color.R, p.Color.G, p.Color.B }, p.Material.Name, p.Transparency)
		end
	end

	local report = { grip = { grip:GetComponents() } }
	local gripPart = rawTool:FindFirstChild("Grip")
	if gripPart then
		local gripWorld = handleCF * rawHandle.CFrame:ToObjectSpace(gripPart.CFrame)
		report.handToGrip = (placed.RightHand.Position - gripWorld.Position).Magnitude
	end
	local onWeapon = rig:GetAttribute("PoseSupportOnWeapon")
	if onWeapon then
		report.leftHandToSupport = (placed.LeftHand.Position - handleCF * onWeapon).Magnitude
	end
	-- Which way the gun points, relative to the torso: yaw (positive = muzzle left) and pitch.
	local muzzle = rawTool:FindFirstChild("Muzzle")
	if muzzle then
		local bore = (handleCF * rawHandle.CFrame:ToObjectSpace(muzzle.CFrame)).Position - handleCF.Position
		local b = placed.UpperTorso:VectorToObjectSpace(bore.Unit)
		report.yaw = math.deg(math.atan2(-b.X, -b.Z))
		report.pitch = math.deg(math.asin(math.clamp(b.Y, -1, 1)))
	end

	weld:Destroy()
	tool:Destroy()
	return { report = report, parts = parts }
end

return Hold
