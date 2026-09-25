--!strict
-- The duel arena and the gun range at night, whatever time it is in the world.
--
-- The arena is a neon court (ServerScriptService.ArenaService), and neon reads best against
-- the dark. The world's lighting is the server's -- one sky for everyone, day and night -- so
-- this does not touch it. Instead, while the camera is inside the arena, a colour grade on
-- the local camera pulls the scene down and cools it, and lets it go again on the way out.
--
-- Checked twice a second, not per frame: you do not leave an arena between two frames.

local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

-- The two sky venues, each with a little margin: the duel arena (mirrors ArenaService's
-- shell) and the gun range lane.
local ZONES = {
	{ centre = Vector3.new(0, 3000, 0), half = Vector3.new(48, 40, 66) },
	{ centre = Vector3.new(0, 2010, -200), half = Vector3.new(60, 50, 250) },
}

local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "ArenaMood"
grade.Enabled = false

local IN = {
	Brightness = -0.1,
	Contrast = 0.16,
	Saturation = 0.22,
	TintColor = Color3.fromRGB(214, 206, 255),
}
local OUT = {
	Brightness = 0,
	Contrast = 0,
	Saturation = 0,
	TintColor = Color3.new(1, 1, 1),
}

local inside = false
local accumulator = 0

local function contains(p: Vector3): boolean
	for _, zone in ipairs(ZONES) do
		local d = p - zone.centre
		if math.abs(d.X) <= zone.half.X and math.abs(d.Y) <= zone.half.Y and math.abs(d.Z) <= zone.half.Z then
			return true
		end
	end
	return false
end

RunService.Heartbeat:Connect(function(dt)
	accumulator += dt
	if accumulator < 0.5 then
		return
	end
	accumulator = 0

	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	if grade.Parent ~= camera then
		grade.Parent = camera
	end

	local now = contains(camera.CFrame.Position)
	if now == inside then
		return
	end
	inside = now
	if now then
		grade.Enabled = true
		TweenService:Create(grade, TweenInfo.new(0.8, Enum.EasingStyle.Quad), IN):Play()
	else
		local out = TweenService:Create(grade, TweenInfo.new(0.8, Enum.EasingStyle.Quad), OUT)
		out.Completed:Once(function()
			if not inside then
				grade.Enabled = false
			end
		end)
		out:Play()
	end
end)
