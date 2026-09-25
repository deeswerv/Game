--!strict
-- Shows weapons on the body while they are stowed: large weapons across the back,
-- small ones at the hip. The visual is a scripts-free copy of the Tool's parts, so it
-- can never fire, damage, or be picked up.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local WeaponConfig = require(ReplicatedStorage.WeaponConfig)

local HolsterService = {}

local FOLDER_NAME = "Holstered"

-- Each slot is an anchor on the torso plus the direction the weapon's length should
-- point. Deriving the rotation from the weapon's own longest axis is what keeps a
-- 7.5-stud katana and a 2-stud pistol both sitting correctly.
local SLOTS = {
	-- Across the back, hilt up over the right shoulder.
	Large = {
		-- Grip sits behind the right shoulder; the blade runs down across the back.
		anchor = Vector3.new(0.62, 0.85, 0.72),
		direction = Vector3.new(-0.62, -1, 0.16).Unit,
		tuck = 0.30,   -- fraction of length pushed back so a long blade does not trail
	},
	-- At the right hip, muzzle down.
	Small = {
		anchor = Vector3.new(1.02, -0.35, 0.32),
		direction = Vector3.new(0.12, -1, 0.1).Unit,
		tuck = 0.25,
	},
}

-- Longest axis of the tool in the Handle's local space, and how long it is.
local function principalAxis(tool: Tool, handle: BasePart): (Vector3, number)
	local min, max = Vector3.new(math.huge, math.huge, math.huge), Vector3.new(-math.huge, -math.huge, -math.huge)
	for _, p in ipairs(tool:GetChildren()) do
		if p:IsA("BasePart") then
			local rel = handle.CFrame:ToObjectSpace(p.CFrame)
			local half = p.Size / 2
			for _, sx in ipairs({ -1, 1 }) do
				for _, sy in ipairs({ -1, 1 }) do
					for _, sz in ipairs({ -1, 1 }) do
						local corner = rel * CFrame.new(half.X * sx, half.Y * sy, half.Z * sz)
						local v = corner.Position
						min = Vector3.new(math.min(min.X, v.X), math.min(min.Y, v.Y), math.min(min.Z, v.Z))
						max = Vector3.new(math.max(max.X, v.X), math.max(max.Y, v.Y), math.max(max.Z, v.Z))
					end
				end
			end
		end
	end
	local size = max - min

	local axis
	local length
	if size.X >= size.Y and size.X >= size.Z then
		axis, length = Vector3.new(1, 0, 0), size.X
	elseif size.Y >= size.Z then
		axis, length = Vector3.new(0, 1, 0), size.Y
	else
		axis, length = Vector3.new(0, 0, 1), size.Z
	end

	-- The axis needs a sign, not just a line: a weapon extends away from where it is
	-- held. Tool.Grip is exactly that reference point in Handle space, and it works
	-- even for single-part weapons where a centre-of-mass test tells you nothing
	-- (the Blood Sword is one 7.5-stud part gripped near the +Z end, so its blade
	-- runs toward -Z).
	local grip = tool.Grip.Position
	local gripAlong = grip:Dot(axis)
	local maxAlong = max:Dot(axis)
	local minAlong = min:Dot(axis)

	if (gripAlong - minAlong) > (maxAlong - gripAlong) then
		axis = -axis
	end

	return axis, length
end

-- Rotation that turns `from` into `to`.
local function rotationBetween(from: Vector3, to: Vector3): CFrame
	local dot = math.clamp(from:Dot(to), -1, 1)
	if dot > 0.9999 then
		return CFrame.identity
	elseif dot < -0.9999 then
		-- Opposite: spin a half turn about any perpendicular axis.
		local perp = math.abs(from.X) < 0.9 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
		return CFrame.fromAxisAngle(from:Cross(perp).Unit, math.pi)
	end
	return CFrame.fromAxisAngle(from:Cross(to).Unit, math.acos(dot))
end

local function holsterFolder(character: Model): Folder
	local f = character:FindFirstChild(FOLDER_NAME)
	if not f then
		f = Instance.new("Folder")
		f.Name = FOLDER_NAME
		f.Parent = character
	end
	return f :: Folder
end

local function clearVisual(character: Model, toolName: string)
	local f = character:FindFirstChild(FOLDER_NAME)
	local existing = f and f:FindFirstChild(toolName)
	if existing then
		existing:Destroy()
	end
end

-- Build the stowed copy and weld it to the torso.
local function buildVisual(character: Model, tool: Tool, cfg)
	local torso = character:FindFirstChild("Torso") or character:FindFirstChild("UpperTorso")
	local handle = tool:FindFirstChild("Handle")
	if not torso or not torso:IsA("BasePart") or not handle or not handle:IsA("BasePart") then
		return
	end

	clearVisual(character, tool.Name)

	local model = Instance.new("Model")
	model.Name = tool.Name

	local slot = SLOTS[cfg.Slot] or SLOTS.Small
	local axis, length = principalAxis(tool, handle)

	-- Lay the weapon's long axis along the slot direction, expressed in torso space.
	local worldDir = (torso.CFrame:VectorToWorldSpace(slot.direction)).Unit
	local worldAxis = (handle.CFrame:VectorToWorldSpace(axis)).Unit
	local rot = rotationBetween(worldAxis, worldDir)

	local anchorPos = (torso.CFrame * CFrame.new(slot.anchor)).Position

	-- `base` positions the Handle's centre, but what should sit on the shoulder is
	-- the point the weapon is actually held by. Tool.Grip gives that point in Handle
	-- space, so offset the centre by wherever the grip lands once rotated.
	local orientation = rot * handle.CFrame.Rotation
	local gripWorldOffset = orientation:VectorToWorldSpace(tool.Grip.Position)
	local placedPos = anchorPos - gripWorldOffset + worldDir * (length * slot.tuck)

	local base = CFrame.new(placedPos) * orientation

	local rootClone: BasePart? = nil
	for _, part in ipairs(tool:GetChildren()) do
		if part:IsA("BasePart") then
			local clone = part:Clone()
			-- Strip anything that could act: scripts, sounds, prompts, effects.
			for _, d in ipairs(clone:GetDescendants()) do
				if d:IsA("LuaSourceContainer") or d:IsA("Sound") or d:IsA("ProximityPrompt")
					or d:IsA("WeldConstraint") or d:IsA("JointInstance") or d:IsA("Attachment") then
					d:Destroy()
				end
			end
			clone.Anchored = false
			clone.CanCollide = false
			clone.CanQuery = false
			clone.CanTouch = false
			clone.Massless = true
			-- Keep each part's position relative to the Handle.
			clone.CFrame = base * handle.CFrame:ToObjectSpace(part.CFrame)
			clone.Parent = model
			if part == handle then
				rootClone = clone
			end
		end
	end

	if not rootClone then
		model:Destroy()
		return
	end

	-- Weld the pieces together, then the whole thing to the torso.
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and p ~= rootClone then
			local w = Instance.new("WeldConstraint")
			w.Part0 = rootClone
			w.Part1 = p
			w.Parent = p
		end
	end
	local anchorWeld = Instance.new("WeldConstraint")
	anchorWeld.Part0 = torso
	anchorWeld.Part1 = rootClone
	anchorWeld.Parent = rootClone

	model.PrimaryPart = rootClone
	model.Parent = holsterFolder(character)
end

-- A weapon shows on the body only while it is stowed in the backpack.
local function refresh(player: Player)
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not character or not backpack then
		return
	end

	local shouldShow: { [string]: Tool } = {}
	for _, tool in ipairs(backpack:GetChildren()) do
		if tool:IsA("Tool") then
			local cfg = WeaponConfig.Get(tool.Name)
			if cfg and cfg.Holster then
				shouldShow[tool.Name] = tool
			end
		end
	end

	local f = holsterFolder(character)
	-- Remove visuals for anything now equipped or gone.
	for _, model in ipairs(f:GetChildren()) do
		if not shouldShow[model.Name] then
			model:Destroy()
		end
	end
	-- Add visuals for anything newly stowed.
	for name, tool in pairs(shouldShow) do
		if not f:FindFirstChild(name) then
			buildVisual(character, tool, WeaponConfig.Get(name))
		end
	end
end

HolsterService.Refresh = refresh

local function onPlayerAdded(player: Player)
	local function hook()
		local character = player.Character
		local backpack = player:WaitForChild("Backpack", 10)
		if not character or not backpack then
			return
		end
		-- Torso has to exist before anything can be welded to it.
		-- R15: the torso is split in two and UpperTorso is the half things hang off.
	character:WaitForChild("UpperTorso", 10)
		task.wait(0.4)

		backpack.ChildAdded:Connect(function() task.wait(0.1) refresh(player) end)
		backpack.ChildRemoved:Connect(function() task.wait(0.1) refresh(player) end)
		character.ChildAdded:Connect(function(c)
			if c:IsA("Tool") then task.wait(0.1) refresh(player) end
		end)
		character.ChildRemoved:Connect(function(c)
			if c:IsA("Tool") then task.wait(0.1) refresh(player) end
		end)

		refresh(player)
	end

	player.CharacterAdded:Connect(function()
		task.spawn(hook)
	end)
	if player.Character then
		task.spawn(hook)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

return HolsterService
