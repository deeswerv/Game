--!strict
-- Black outlines on everyone and everything worth edging, matching the one the player
-- character already wears.
--
-- It reuses ReplicatedStorage.Highlight rather than defining a second look, so the
-- outline stays identical to the character's if that template is ever retuned.
--
-- Why a pool instead of one Highlight per model: Roblox only renders a limited number of
-- Highlights at once -- past roughly thirty they silently stop drawing -- and this place
-- already has 33 humanoid models before any dropped weapons are counted. Giving each its
-- own would quietly break the effect for whichever ones lost the race. Instead a fixed
-- pool is re-pointed at whatever is nearest the camera. Close up the look is identical,
-- and things far enough away that the edge is a pixel wide simply go without.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local template = ReplicatedStorage:WaitForChild("Highlight")
local player = Players.LocalPlayer

local MAX_OUTLINES = 22       -- comfortably under the point where Roblox starts dropping them
local RANGE = 260             -- studs; past this the outline is not readable anyway
local REFRESH = 0.25

-- Local-only, so none of this replicates to anyone else.
local holder = Instance.new("Folder")
holder.Name = "Outlines"
holder.Parent = workspace.CurrentCamera

local pool: { Highlight } = {}
for i = 1, MAX_OUTLINES do
	local h = template:Clone()
	h.Name = "Outline" .. i
	h.Adornee = nil
	h.Enabled = false
	h.Parent = holder
	pool[i] = h
end

-- Everything that should be outlined, kept up to date by events rather than rescanned.
-- Walking the whole workspace four times a second would cost more than the outlines do.
local tracked: { [Instance]: boolean } = {}

local function subject(inst: Instance): Instance?
	if inst:IsA("Humanoid") then
		local model = inst.Parent
		return (model and model:IsA("Model")) and model or nil
	end
	-- A weapon on the ground. Held ones are covered by their owner's own outline, which
	-- adorns the whole character and so includes whatever is parented into it.
	if inst:IsA("Tool") and inst.Parent == workspace then
		return inst
	end
	return nil
end

local function add(inst: Instance)
	local s = subject(inst)
	if s then
		tracked[s] = true
	end
end

local function remove(inst: Instance)
	local s = subject(inst)
	if s then
		tracked[s] = nil
	end
	tracked[inst] = nil
end

for _, d in ipairs(workspace:GetDescendants()) do
	add(d)
end
workspace.DescendantAdded:Connect(add)
workspace.DescendantRemoving:Connect(remove)

local function pivotOf(inst: Instance): Vector3?
	if inst:IsA("Model") then
		local ok, cf = pcall(function()
			return inst:GetPivot()
		end)
		return ok and cf.Position or nil
	end
	local handle = inst:FindFirstChild("Handle")
	return (handle and handle:IsA("BasePart")) and handle.Position or nil
end

local function refresh()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if holder.Parent ~= camera then
		holder.Parent = camera        -- the camera is replaced on respawn
	end
	local origin = camera.CFrame.Position
	local own = player.Character

	local near = {}
	for inst in pairs(tracked) do
		if not inst.Parent then
			tracked[inst] = nil
		elseif inst ~= own then        -- the player's own outline is applied by their character
			local position = pivotOf(inst)
			if position then
				local d = (position - origin).Magnitude
				if d <= RANGE then
					table.insert(near, { inst = inst, d = d })
				end
			end
		end
	end
	table.sort(near, function(a, b)
		return a.d < b.d
	end)

	for i, h in ipairs(pool) do
		local pick = near[i]
		if pick then
			if h.Adornee ~= pick.inst then
				h.Adornee = pick.inst
			end
			h.Enabled = true
		else
			h.Enabled = false
			h.Adornee = nil
		end
	end
end

task.spawn(function()
	while true do
		local ok, err = pcall(refresh)
		if not ok then
			warn("[OutlineService] " .. tostring(err))
		end
		task.wait(REFRESH)
	end
end)
