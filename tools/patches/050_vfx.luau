-- Imported visual effects.
--
-- Every .rbxm under assets/vfx becomes ReplicatedStorage.VFX.<file name>, exactly as it was
-- authored, and CombatFX.PlayVFX plays it. The effects come from a VFX plugin whose
-- convention is three attributes on each ParticleEmitter -- EmitDelay, EmitCount and
-- EmitDuration -- which say when it fires, how many it throws at once, and how long it
-- streams for. The template is stored switched off, so nothing ever plays just because it
-- was cloned; the player turns each emitter on when its attributes say.
--
-- Only made inert here, never restyled: anchored and out of physics, raycasts and touch, and
-- stripped of welds that pointed at a rig part the export did not include.
return function(ctx)
	local roblox = ctx.roblox
	local fs = ctx.fs
	if not fs.isDir("assets/vfx") then
		return
	end
	local rs = ctx.get("ReplicatedStorage")
	local folder = rs:FindFirstChild("VFX") or ctx.new("Folder", rs, { Name = "VFX" })

	local names = {}
	for _, file in fs.readDir("assets/vfx") do
		if string.sub(file, -5) == ".rbxm" then
			table.insert(names, file)
		end
	end
	table.sort(names)

	for _, file in names do
		local name = string.sub(file, 1, -6)
		local old = folder:FindFirstChild(name)
		if old then
			old.Parent = nil
		end
		local list = roblox.deserializeModel(fs.readFile("assets/vfx/" .. file))
		local root = list[1]
		if #list ~= 1 then
			root = roblox.Instance.new("Model")
			for _, inst in list do
				inst.Parent = root
			end
		end
		root.Name = name

		local emitters, beams = 0, 0
		local all = root:GetDescendants()
		table.insert(all, root)
		for _, d in all do
			if d:IsA("BasePart") then
				d.Anchored = true
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.CastShadow = false
				d.Massless = true
				d.Transparency = 1
			elseif d:IsA("ParticleEmitter") then
				d.Enabled = false
				emitters += 1
			elseif d:IsA("Beam") then
				d.Enabled = false
				beams += 1
			elseif d:IsA("JointInstance") or d:IsA("WeldConstraint") then
				d.Parent = nil
			end
		end
		root.Parent = folder
		print(`vfx {name}: {emitters} emitters, {beams} beams`)
	end
end
