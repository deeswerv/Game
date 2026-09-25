--!strict
-- The lobby's 1v1 pads, the way the reference game queues: walk onto a pad and you are in the
-- duel queue; step off and you are out again. Two glowing pads side by side near the spawn,
-- magenta and cyan like the arena's two ends, with a 1V1 sign over them, the name of whoever
-- is standing on each, and a shimmering column while they wait.
--
-- A second door into the SAME queue, not a second queue. The PLAY diamond and J still work;
-- this one needs no cursor at all, which matters because the shift-lock camera keeps the
-- cursor pinned to the middle of the screen.
--
-- Placed by looking, not by coordinates. The lobby is terrain, grass meshes and rocks, and a
-- pad dropped at a fixed position could as easily end up floating over a dip or buried in a
-- boulder. So at start-up this tries sites in rings around the spawn and takes the first one
-- that is flat, dry, at spawn height and has nothing solid in the way -- measured with the
-- same raycasts and overlap queries the game uses for everything else.
--
-- Decoration only: nothing here collides, blocks a shot, or can be touched.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local MatchService = require(ServerScriptService.MatchService)

local DuelPads = {}

local PAD_RADIUS = 4               -- how close to a pad's centre counts as standing on it
local PAD_SIZE = 9.4               -- rim diameter
local PAD_GAP = 16                 -- centre to centre
local CHECK_INTERVAL = 0.2

local MAGENTA = Color3.fromRGB(255, 60, 200)
local CYAN = Color3.fromRGB(40, 220, 255)
local PLATE = Color3.fromRGB(30, 32, 40)
local FLAT = CFrame.Angles(0, 0, math.rad(90))      -- a Cylinder's axis is X; stand it up

-- ------------------------------------------------------------------ site --

local function spawnPoint(): Vector3
	local direct = workspace:FindFirstChildOfClass("SpawnLocation")
	if direct then
		return direct.Position
	end
	for _, d in ipairs(workspace:GetDescendants()) do
		if d:IsA("SpawnLocation") then
			return d.Position
		end
	end
	return Vector3.new(0, 2, 0)
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.RespectCanCollide = true
rayParams.IgnoreWater = false            -- land on water rather than on the pond's floor

local function isCharacterPart(part: Instance): boolean
	local model = part:FindFirstAncestorOfClass("Model")
	return model ~= nil and model:FindFirstChildOfClass("Humanoid") ~= nil
end

-- Level, dry ground under `at`. A ray that lands on somebody (a player, an NPC wandering
-- past) is not ground; that probe just fails and the next site is tried.
local function ground(at: Vector3): RaycastResult?
	local hit = workspace:Raycast(at + Vector3.new(0, 30, 0), Vector3.new(0, -60, 0), rayParams)
	if not hit or hit.Normal.Y < 0.9 or hit.Material == Enum.Material.Water or isCharacterPart(hit.Instance) then
		return nil
	end
	return hit
end

--- The first site in rings around the spawn that is level with it and clear.
local function findSite(origin: Vector3): CFrame?
	for _, radius in ipairs({ 22, 28, 34, 42, 50 }) do
		for step = 0, 15 do
			local angle = step / 16 * math.pi * 2
			local probe = origin + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
			local centreHit = ground(probe)
			if centreHit and math.abs(centreHit.Position.Y - origin.Y) < 5 then
				-- Line the pads up across the view from the spawn, so both read at a glance.
				local toSpawn = (origin - probe) * Vector3.new(1, 0, 1)
				local cf = CFrame.lookAt(centreHit.Position, centreHit.Position + toSpawn.Unit)
				local ok = true
				local floor: { Instance } = { centreHit.Instance }
				for _, side in ipairs({ -1, 1 }) do
					for _, edge in ipairs({ -1, 0, 1 }) do
						local at = (cf * CFrame.new(side * PAD_GAP / 2 + edge * PAD_SIZE / 2, 0, 0)).Position
						local hit = ground(at)
						if not hit or math.abs(hit.Position.Y - centreHit.Position.Y) > 1.2 then
							ok = false
							break
						end
						table.insert(floor, hit.Instance)
					end
					if not ok then
						break
					end
				end
				if ok then
					-- Nothing solid in the volume the pads and the people on them occupy.
					local overlap = OverlapParams.new()
					overlap.FilterType = Enum.RaycastFilterType.Exclude
					overlap.FilterDescendantsInstances = floor
					overlap.RespectCanCollide = true
					local parts = workspace:GetPartBoundsInBox(cf * CFrame.new(0, 4.6, 0),
						Vector3.new(PAD_GAP + PAD_SIZE + 2, 8, PAD_SIZE + 2), overlap)
					for _, part in ipairs(parts) do
						if not part:IsA("Terrain") and not isCharacterPart(part) then
							ok = false
							break
						end
					end
				end
				if ok then
					return cf
				end
			end
		end
	end
	return nil
end

-- ------------------------------------------------------------------ build --

local function decor(parent: Instance, name: string, shape: Enum.PartType, size: Vector3, cf: CFrame,
	colour: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function billboard(adornee: BasePart, size: UDim2, offset: Vector3): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Size = size
	gui.StudsOffsetWorldSpace = offset
	gui.MaxDistance = 140
	gui.LightInfluence = 0
	gui.Adornee = adornee
	gui.Parent = adornee
	return gui
end

local function text(parent: Instance, content: string, size: UDim2, position: UDim2, colour: Color3,
	strokeColour: Color3, strokeThickness: number): TextLabel
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = size
	label.Position = position
	label.Text = content
	label.TextScaled = true
	label.FontFace = Font.new("rbxasset://fonts/families/FredokaOne.json")
	label.TextColor3 = colour
	label.Parent = parent
	local stroke = Instance.new("UIStroke")
	stroke.Color = strokeColour
	stroke.Thickness = strokeThickness
	stroke.Parent = label
	return label
end

type Pad = {
	centre: Vector3,
	colour: Color3,
	column: Part,
	core: Part,
	light: PointLight,
	name: TextLabel,
	status: TextLabel,
	shown: string?,        -- what the label currently says, so it is only written on change
}

local function buildPad(parent: Instance, cf: CFrame, colour: Color3): Pad
	decor(parent, "Rim", Enum.PartType.Cylinder, Vector3.new(0.24, PAD_SIZE, PAD_SIZE),
		cf * CFrame.new(0, 0.1, 0) * FLAT, colour, Enum.Material.Neon)
	decor(parent, "Plate", Enum.PartType.Cylinder, Vector3.new(0.3, PAD_SIZE - 1, PAD_SIZE - 1),
		cf * CFrame.new(0, 0.14, 0) * FLAT, PLATE, Enum.Material.Metal)
	decor(parent, "Ring", Enum.PartType.Cylinder, Vector3.new(0.32, 5.2, 5.2),
		cf * CFrame.new(0, 0.16, 0) * FLAT, colour, Enum.Material.Neon).Transparency = 0.35
	decor(parent, "Inner", Enum.PartType.Cylinder, Vector3.new(0.34, 4.4, 4.4),
		cf * CFrame.new(0, 0.18, 0) * FLAT, PLATE, Enum.Material.Metal)
	local core = decor(parent, "Core", Enum.PartType.Cylinder, Vector3.new(0.36, 2.2, 2.2),
		cf * CFrame.new(0, 0.2, 0) * FLAT, colour, Enum.Material.Neon)

	local light = Instance.new("PointLight")
	light.Color = colour
	light.Range = 12
	light.Brightness = 1.2
	light.Shadows = false
	light.Parent = core

	-- The waiting column: a shimmer of force-field material, shown while someone is queued.
	local column = decor(parent, "Column", Enum.PartType.Cylinder, Vector3.new(14, PAD_SIZE - 1.4, PAD_SIZE - 1.4),
		cf * CFrame.new(0, 7.2, 0) * FLAT, colour, Enum.Material.ForceField)
	column.Transparency = 1

	local gui = billboard(core, UDim2.fromScale(9, 2.6), Vector3.new(0, 7.6, 0))
	local name = text(gui, "OPEN", UDim2.fromScale(1, 0.6), UDim2.fromScale(0, 0), Color3.new(1, 1, 1),
		Color3.fromRGB(10, 10, 14), 3)
	local status = text(gui, "STEP ON TO QUEUE", UDim2.fromScale(1, 0.36), UDim2.fromScale(0, 0.62),
		colour:Lerp(Color3.new(1, 1, 1), 0.3), Color3.fromRGB(10, 10, 14), 2)

	return {
		centre = cf.Position, colour = colour, column = column, core = core, light = light,
		name = name, status = status, shown = nil,
	}
end

local function buildSign(parent: Instance, cf: CFrame)
	local anchor = decor(parent, "SignAnchor", Enum.PartType.Block, Vector3.new(1, 1, 1),
		cf * CFrame.new(0, 12.5, 0), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	anchor.Transparency = 1
	local gui = billboard(anchor, UDim2.fromScale(16, 6), Vector3.zero)
	local title = text(gui, "⚔ 1V1 ⚔", UDim2.fromScale(1, 0.66), UDim2.fromScale(0, 0), Color3.new(1, 1, 1),
		Color3.fromRGB(10, 10, 14), 4)
	-- Magenta into cyan across the title: the two pads' colours meeting.
	local blend = Instance.new("UIGradient")
	blend.Color = ColorSequence.new(MAGENTA:Lerp(Color3.new(1, 1, 1), 0.25), CYAN:Lerp(Color3.new(1, 1, 1), 0.25))
	blend.Parent = title
	text(gui, "STAND ON A PAD TO DUEL", UDim2.fromScale(1, 0.3), UDim2.fromScale(0, 0.68),
		Color3.fromRGB(255, 236, 150), Color3.fromRGB(10, 10, 14), 2.5)
end

-- ------------------------------------------------------------------ logic --

local pads: { Pad } = {}
local wasOn: { [Player]: boolean } = {}         -- seen on a pad last check
local joinedByPad: { [Player]: boolean } = {}   -- the pad, not PLAY, put them in the queue

local function show(pad: Pad, occupant: Player?)
	local key = "open"
	if occupant then
		key = occupant.Name .. (MatchService.InQueue(occupant) and ":q" or ":idle")
	end
	if pad.shown == key then
		return
	end
	pad.shown = key
	local queued = occupant ~= nil and MatchService.InQueue(occupant)
	if occupant then
		pad.name.Text = occupant.DisplayName
		pad.status.Text = queued and "SEARCHING..." or "STEP OFF AND ON TO QUEUE"
	else
		pad.name.Text = "OPEN"
		pad.status.Text = "STEP ON TO QUEUE"
	end
	pad.column.Transparency = queued and 0 or 1
	pad.core.Transparency = occupant and 0 or 0.15
	pad.light.Brightness = queued and 3 or 1.2
	pad.light.Range = queued and 16 or 12
end

local function padUnder(player: Player): Pad?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 then
		return nil
	end
	local position = root.Position
	for _, pad in ipairs(pads) do
		local d = position - pad.centre
		if Vector3.new(d.X, 0, d.Z).Magnitude <= PAD_RADIUS and d.Y > -2 and d.Y < 8 then
			return pad
		end
	end
	return nil
end

local function tick()
	local occupants: { [Pad]: Player } = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local pad = padUnder(player)
		if MatchService.InBout(player) then
			-- Coming home from a duel lands you back on the pad you left from; that is not a
			-- new step onto it, so it must not queue you straight back up.
			wasOn[player] = true
			joinedByPad[player] = nil
		elseif pad and not wasOn[player] then
			wasOn[player] = true
			if not MatchService.InQueue(player) and MatchService.Join(player) then
				joinedByPad[player] = true
			end
		elseif not pad and wasOn[player] then
			wasOn[player] = nil
			-- Only undo what the pad did: someone who queued with PLAY and walked across a
			-- pad stays queued.
			if joinedByPad[player] and MatchService.InQueue(player) then
				MatchService.Leave(player)
			end
			joinedByPad[player] = nil
		end
		if pad and not occupants[pad] then
			occupants[pad] = player
		end
	end
	for _, pad in ipairs(pads) do
		show(pad, occupants[pad])
	end
end

Players.PlayerRemoving:Connect(function(player)
	wasOn[player] = nil
	joinedByPad[player] = nil
end)

-- ------------------------------------------------------------------ start --

task.spawn(function()
	-- Let the rest of the world finish building first, so the clearance check sees it.
	task.wait(2)
	local origin = spawnPoint()
	local cf = findSite(origin)
	if not cf then
		warn("[DuelPads] no clear, level spot near the spawn; pads not placed")
		return
	end

	local model = Instance.new("Model")
	model.Name = "DuelPads"
	for index, side in ipairs({ -1, 1 }) do
		local colour = index == 1 and MAGENTA or CYAN
		table.insert(pads, buildPad(model, cf * CFrame.new(side * PAD_GAP / 2, 0, 0), colour))
	end
	buildSign(model, cf)
	model.Parent = workspace
	print(("[DuelPads] placed at %s"):format(tostring(cf.Position)))

	while true do
		task.wait(CHECK_INTERVAL)
		local ok, err = pcall(tick)
		if not ok then
			warn("[DuelPads] " .. tostring(err))
		end
	end
end)

return DuelPads
