--!strict
-- The giant screens of HANAMI CITY change their pictures: every few seconds a white wipe runs
-- across a screen and the next picture is under it. Each screen keeps its own time, so the
-- Scramble never flips all at once. Only the screens near the camera are turned over (nobody
-- sees the rest), and nothing here touches the server.

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local CityScreens = require(ReplicatedStorage:WaitForChild("CityScreens"))

local NEAR = 900              -- studs: screens further away than this are left as they are
local WIPE = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut)

type Entry = { panel: BasePart, next: number, hold: number }
local screens: { [BasePart]: Entry } = {}

local function add(inst: Instance)
	if inst:IsA("BasePart") and not screens[inst] then
		local p = inst.Position
		-- Each screen's own rhythm, from where it stands (the same for everybody).
		local r = math.abs(math.sin(p.X * 0.137 + p.Z * 0.071)) % 1
		local hold = CityScreens.HOLD + r * 4
		screens[inst] = { panel = inst, next = os.clock() + r * hold, hold = hold }
	end
end
for _, inst in ipairs(CollectionService:GetTagged(CityScreens.TAG)) do
	add(inst)
end
CollectionService:GetInstanceAddedSignal(CityScreens.TAG):Connect(add)
CollectionService:GetInstanceRemovedSignal(CityScreens.TAG):Connect(function(inst)
	screens[inst :: BasePart] = nil
end)

local function turn(e: Entry)
	local panel = e.panel
	local gui = panel:FindFirstChild("Picture")
	local wipe = gui and gui:FindFirstChild("Wipe") :: Frame?
	local n = ((panel:GetAttribute("Ad") :: number?) or 1) + 1
	if not wipe then
		CityScreens.Paint(panel, n)
		return
	end
	local w = wipe :: Frame
	w.AnchorPoint = Vector2.new(0, 0)
	w.Position = UDim2.fromScale(0, 0)
	w.Size = UDim2.fromScale(0, 1)
	w.BackgroundTransparency = 0.05
	local cover = TweenService:Create(w, WIPE, { Size = UDim2.fromScale(1, 1) })
	cover.Completed:Connect(function()
		CityScreens.Paint(panel, n)
		w.AnchorPoint = Vector2.new(1, 0)
		w.Position = UDim2.fromScale(1, 0)
		TweenService:Create(w, WIPE, { Size = UDim2.fromScale(0, 1), BackgroundTransparency = 0.4 }):Play()
	end)
	cover:Play()
end

task.spawn(function()
	while true do
		task.wait(0.5)
		local camera = workspace.CurrentCamera
		local eye = if camera then camera.CFrame.Position else Vector3.zero
		local now = os.clock()
		for panel, e in pairs(screens) do
			if panel.Parent == nil then
				screens[panel] = nil
			elseif now >= e.next then
				e.next = now + e.hold
				if (panel.Position - eye).Magnitude < NEAR then
					turn(e)
				end
			end
		end
	end
end)
