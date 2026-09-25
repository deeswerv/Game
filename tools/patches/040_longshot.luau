-- Longshot: a bolt-action sniper, the one weapon class the roster was missing.
--
-- Built part by part the way the game's other data-built guns are (WeaponBuilder: every
-- shape is a box), and laid out in the same conventions they follow, so every system that
-- handles a weapon already understands it:
--
--   Handle space: -Z is the bore, +Y is up. Parts are massless, non-colliding and welded to
--   the Handle with WeldConstraints. The muzzle is a part named "Muzzle" carrying the
--   "MuzzlePoint" attachment and the "Flash" light; the Fire and Reload sounds sit on the
--   Handle (WeaponAudio re-stamps them by class). "Barrel" + "Muzzle" give WeaponPose the
--   bore, "Magazine" is what the reload drops, "Handguard" is where the off hand goes,
--   "Bolt" is what the charge action racks, and "Stock" hosts stock attachments.
--
-- There is deliberately no Rail/Receiver/Upper part and no Mount_Sight: the scope is built
-- in, so the Armory should not offer to bolt a red dot on top of it (AttachmentBuilder
-- only offers slots a weapon has somewhere to put).
return function(ctx)
	local roblox = ctx.roblox
	local Vector3, CFrame, Color3, Enum = roblox.Vector3, roblox.CFrame, roblox.Color3, roblox.Enum

	local store = ctx.find("ReplicatedStorage/storeitems")
	local template = store and store:FindFirstChild("Warden")
	if not store or not template then
		print("(storeitems/Warden not found; Longshot skipped)")
		return
	end
	local old = store:FindFirstChild("Longshot")
	if old then
		old:Destroy()
	end

	-- The tool itself: Warden's Tool properties, none of its parts.
	local tool = template:Clone()
	tool.Name = "Longshot"
	for _, child in tool:GetChildren() do
		if child.Name ~= "Handle" then
			child:Destroy()
		end
	end
	local handle = tool:FindFirstChild("Handle")
	for _, child in handle:GetChildren() do
		-- Keep the sounds; the mount points belong to Warden's shape.
		if not child:IsA("Sound") then
			child:Destroy()
		end
	end
	local origin = CFrame.new(0, 10, 0)
	handle.CFrame = origin

	local partTemplate = template:FindFirstChild("Barrel")
	local flashTemplate = nil
	for _, d in template:GetDescendants() do
		if d:IsA("PointLight") and d.Name == "Flash" then
			flashTemplate = d
		end
	end

	local BODY = Color3.fromRGB(30, 32, 38)          -- matte polymer
	local STEEL = Color3.fromRGB(62, 64, 72)
	local DARK = Color3.fromRGB(18, 18, 22)
	local GOLD = Color3.fromRGB(255, 192, 64)
	local GLASS = Color3.fromRGB(110, 190, 255)

	local count = 0
	local function part(name: string, size, pos, colour, material, extra, tilt: number?)
		local p = partTemplate:Clone()
		for _, c in p:GetChildren() do
			c:Destroy()
		end
		p.Name = name
		p.Size = size
		p.CFrame = origin * CFrame.new(pos) * CFrame.Angles(math.rad(tilt or 0), 0, 0)
		p.Color = colour
		p.Material = material or Enum.Material.SmoothPlastic
		p.Transparency = 0
		p.Reflectance = 0
		p.Massless = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
		p.Anchored = false
		if extra then
			for k, v in extra do
				p[k] = v
			end
		end
		p.Parent = tool
		local weld = roblox.Instance.new("WeldConstraint")
		weld.Part0 = handle
		weld.Part1 = p
		weld.Parent = p
		count += 1
		return p
	end
	local V = Vector3.new

	-- Action, trigger group and magazine.
	part("Action", V(0.30, 0.34, 1.50), V(0, 0.55, -0.25), STEEL, Enum.Material.Metal)
	part("ActionTop", V(0.22, 0.05, 1.30), V(0, 0.745, -0.25), DARK, Enum.Material.Metal)
	part("EjectionPort", V(0.02, 0.12, 0.34), V(0.151, 0.62, -0.05), DARK)
	part("TriggerGuard", V(0.06, 0.06, 0.40), V(0, 0.14, -0.06), STEEL, Enum.Material.Metal)
	part("TriggerGuardFront", V(0.06, 0.24, 0.06), V(0, 0.25, -0.24), STEEL, Enum.Material.Metal)
	part("Trigger", V(0.04, 0.16, 0.05), V(0, 0.27, -0.08), GOLD, Enum.Material.Metal)
	-- The Handle is the invisible hand-hold every weapon here has; this is the grip you see,
	-- raked back like a real one.
	part("Grip", V(0.24, 0.62, 0.32), V(0, 0.08, 0.16), BODY, nil, nil, -18)
	part("GripCap", V(0.25, 0.05, 0.33), V(0, -0.21, 0.26), GOLD, Enum.Material.Metal, nil, -18)
	part("Magazine", V(0.22, 0.42, 0.36), V(0, 0.24, -0.56), BODY)
	part("MagBasePlate", V(0.24, 0.05, 0.38), V(0, 0.02, -0.56), GOLD, Enum.Material.Metal)

	-- The bolt, its arm and the knob sticking out to the right.
	part("Bolt", V(0.10, 0.10, 0.52), V(0.17, 0.66, 0.02), STEEL, Enum.Material.Metal)
	part("BoltArm", V(0.26, 0.05, 0.05), V(0.30, 0.60, 0.16), STEEL, Enum.Material.Metal)
	part("BoltKnob", V(0.13, 0.13, 0.13), V(0.44, 0.56, 0.18), DARK, Enum.Material.Metal)

	-- Stock: body, cheek riser, hook, butt pad, and a gold line down each side.
	part("Stock", V(0.28, 0.46, 1.25), V(0, 0.50, 0.95), BODY)
	part("CheekRest", V(0.26, 0.16, 0.70), V(0, 0.80, 0.95), BODY)
	part("StockHook", V(0.26, 0.28, 0.35), V(0, 0.22, 1.35), BODY)
	part("ButtPad", V(0.30, 0.62, 0.10), V(0, 0.47, 1.62), DARK)
	for _, side in { -1, 1 } do
		part("StockStripe", V(0.02, 0.05, 1.00), V(side * 0.145, 0.62, 0.95), GOLD, Enum.Material.Neon)
	end

	-- Handguard with vent slots, then the barrel and the brake.
	part("Handguard", V(0.30, 0.30, 1.50), V(0, 0.52, -1.75), BODY)
	for _, z in { -1.30, -1.75, -2.20 } do
		for _, side in { -1, 1 } do
			part("Vent", V(0.02, 0.10, 0.26), V(side * 0.151, 0.55, z), DARK)
		end
	end
	part("HandguardStripe", V(0.02, 0.04, 1.40), V(0.152, 0.42, -1.75), GOLD, Enum.Material.Neon)
	part("Barrel", V(0.12, 0.12, 1.60), V(0, 0.62, -3.00), STEEL, Enum.Material.Metal)
	local muzzle = part("Muzzle", V(0.20, 0.18, 0.36), V(0, 0.62, -3.96), DARK, Enum.Material.Metal)
	for _, z in { -3.90, -4.02 } do
		part("BrakePort", V(0.24, 0.04, 0.05), V(0, 0.62, z), STEEL, Enum.Material.Metal)
	end
	local point = roblox.Instance.new("Attachment")
	point.Name = "MuzzlePoint"
	point.CFrame = CFrame.new(0, 0, -0.2)
	point.Parent = muzzle
	if flashTemplate then
		flashTemplate:Clone().Parent = muzzle
	end

	-- The scope: base, rings, tube, bell with a gold-rimmed lens, ocular, turrets.
	part("ScopeBase", V(0.18, 0.06, 1.10), V(0, 0.80, -0.30), STEEL, Enum.Material.Metal)
	part("ScopeRing", V(0.26, 0.22, 0.10), V(0, 0.90, -0.72), STEEL, Enum.Material.Metal)
	part("ScopeRing", V(0.26, 0.22, 0.10), V(0, 0.90, 0.06), STEEL, Enum.Material.Metal)
	part("ScopeTube", V(0.20, 0.20, 1.30), V(0, 0.98, -0.35), BODY, Enum.Material.Metal)
	part("ScopeBell", V(0.30, 0.30, 0.36), V(0, 0.98, -1.15), BODY, Enum.Material.Metal)
	part("ScopeRim", V(0.31, 0.31, 0.02), V(0, 0.98, -1.33), GOLD, Enum.Material.Neon)
	part("ScopeLens", V(0.24, 0.24, 0.02), V(0, 0.98, -1.345), GLASS, Enum.Material.Glass,
		{ Transparency = 0.15, Reflectance = 0.45 })
	part("ScopeEye", V(0.26, 0.26, 0.24), V(0, 0.98, 0.42), BODY, Enum.Material.Metal)
	part("ScopeEyeLens", V(0.20, 0.20, 0.02), V(0, 0.98, 0.545), GLASS, Enum.Material.Glass,
		{ Transparency = 0.2, Reflectance = 0.3 })
	part("TurretTop", V(0.12, 0.12, 0.12), V(0, 1.14, -0.35), STEEL, Enum.Material.Metal)
	part("TurretCap", V(0.13, 0.03, 0.13), V(0, 1.215, -0.35), GOLD, Enum.Material.Metal)
	part("TurretSide", V(0.12, 0.12, 0.12), V(0.16, 0.98, -0.35), STEEL, Enum.Material.Metal)

	-- A folded bipod under the handguard.
	part("BipodMount", V(0.16, 0.08, 0.10), V(0, 0.34, -2.40), STEEL, Enum.Material.Metal)
	for _, side in { -1, 1 } do
		part("BipodLeg", V(0.05, 0.05, 0.80), V(side * 0.09, 0.32, -2.05), DARK, Enum.Material.Metal)
	end

	tool.Parent = store
	print(("Longshot built: %d parts"):format(count))
end
