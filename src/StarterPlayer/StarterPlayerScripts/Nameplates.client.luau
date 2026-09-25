--!strict
-- Who you are looking at, and how hurt they are.
--
-- There was nothing. Roblox's built-in name and health display is switched off on this
-- game's rig -- StarterPlayer.StarterCharacter sets DisplayDistanceType to None, because
-- the stock plate is a grey bar that floats miles above the head and ignores the art -- so
-- an enemy across the map read as an anonymous blue shape with no indication of whether
-- they were about to die or about to kill you.
--
-- Entirely client-side and entirely additive: BillboardGuis parented to other players'
-- heads. Nothing here is trusted for anything, it only draws what the Humanoid already
-- replicates.

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Past this a nameplate is noise rather than information, and BillboardGui.MaxDistance
-- culls it for free.
local MAX_DISTANCE = 150

local HEALTHY = Color3.fromRGB(86, 208, 96)
local HURT = Color3.fromRGB(226, 78, 72)

-- Hostiles get a warm name so a glance tells you what you are looking at before you have
-- read the word. Neutrals -- merchants, quest givers -- stay white.
local HOSTILE_NAME = Color3.fromRGB(255, 138, 128)
local NEUTRAL_NAME = Color3.fromRGB(255, 255, 255)

-- Where the things worth labelling live. Deliberately a list of containers rather than a
-- sweep for Humanoids: workspace holds about thirty of them, and most are animation source
-- rigs (AllAnimations, Sword.Swordhandler.Animations) that are not characters at all and
-- would each sprout a nameplate in mid-air.
local NPC_FOLDERS = { NPCs = true, Dummies = true }

local function styleCorner(inst: Instance, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = inst
end

local LEVEL_GOLD = "#FFC21E"

local function outline(label: TextLabel, thickness: number)
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(8, 8, 12)
	edge.Thickness = thickness
	edge.LineJoinMode = Enum.LineJoinMode.Round
	edge.Parent = label
end

local function buildPlate(displayName: string, character: Model, hostile: boolean, owner: Player?)
	local head = character:WaitForChild("Head", 10) :: BasePart?
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not head or not humanoid or not humanoid:IsA("Humanoid") then
		return
	end

	local existing = head:FindFirstChild("Nameplate")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("BillboardGui")
	gui.Name = "Nameplate"
	gui.Adornee = head
	gui.Size = UDim2.fromScale(5, 1.25)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 2.0, 0)
	gui.MaxDistance = MAX_DISTANCE
	-- Depth tested deliberately. A nameplate that shines through walls is a wallhack, and
	-- this is a shooter where knowing whether you can actually see someone is the game.
	gui.AlwaysOnTop = false
	gui.LightInfluence = 0
	gui.ResetOnSpawn = false
	gui.Parent = head

	local name = Instance.new("TextLabel")
	name.Name = "PlayerName"
	name.AnchorPoint = Vector2.new(0.5, 1)
	name.Position = UDim2.fromScale(0.5, 0.72)
	name.Size = UDim2.fromScale(1, 0.62)
	name.BackgroundTransparency = 1
	name.Font = Enum.Font.SourceSansBold
	name.TextScaled = true
	name.RichText = true
	name.TextColor3 = hostile and HOSTILE_NAME or NEUTRAL_NAME
	-- The map is lime grass and pale stone: a proper dark outline, the same edge every piece
	-- of text in the game wears, keeps the name readable on all of it.
	name.TextStrokeTransparency = 1
	outline(name, 2)
	name.Text = displayName
	-- The level leads the name as a gold diamond tag, the way the references tag players.
	-- NPCs also carry a name colour the server picked for them -- gold for an elite, green
	-- for a guard -- so the plate says how dangerous they are, not just what.
	local function levelTag()
		local level = if owner then owner:GetAttribute("Level") else character:GetAttribute("Level")
		if typeof(level) == "number" then
			name.Text = ('<font color="%s">◆%d</font>  %s'):format(LEVEL_GOLD, level, displayName)
		else
			name.Text = displayName
		end
	end
	levelTag()
	if owner then
		owner:GetAttributeChangedSignal("Level"):Connect(levelTag)
	else
		local tint = character:GetAttribute("NameColour")
		if typeof(tint) == "Color3" then
			name.TextColor3 = tint
		end
	end
	name.Parent = gui

	-- TextScaled sizes the name to the plate, and the plate is measured in studs, so walking
	-- right up to someone would otherwise put their name across half the screen.
	local cap = Instance.new("UITextSizeConstraint")
	cap.MaxTextSize = 20
	cap.MinTextSize = 8
	cap.Parent = name

	local barBack = Instance.new("Frame")
	barBack.Name = "Health"
	barBack.AnchorPoint = Vector2.new(0.5, 1)
	barBack.Position = UDim2.fromScale(0.5, 1)
	barBack.Size = UDim2.fromScale(0.8, 0.22)
	barBack.BackgroundColor3 = Color3.fromRGB(10, 10, 14)
	barBack.BackgroundTransparency = 0.2
	barBack.BorderSizePixel = 0
	barBack.Parent = gui
	styleCorner(barBack, 4)
	local rim = Instance.new("UIStroke")
	rim.Color = Color3.fromRGB(8, 8, 12)
	rim.Thickness = 2
	rim.Parent = barBack

	-- The white chip trails behind the fill after a hit, so the size of the hit reads.
	local chip = Instance.new("Frame")
	chip.Name = "Chip"
	chip.Size = UDim2.fromScale(1, 1)
	chip.BackgroundColor3 = Color3.new(1, 1, 1)
	chip.BorderSizePixel = 0
	chip.Parent = barBack
	styleCorner(chip, 4)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = HEALTHY
	fill.BorderSizePixel = 0
	fill.Parent = barBack
	styleCorner(fill, 4)
	local sheen = Instance.new("UIGradient")
	sheen.Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(170, 170, 170))
	sheen.Rotation = 90
	sheen.Parent = fill

	local lastRatio = 1
	local token = 0
	local function refresh()
		local max = humanoid.MaxHealth
		local ratio = max > 0 and math.clamp(humanoid.Health / max, 0, 1) or 0
		fill.Size = UDim2.fromScale(ratio, 1)
		fill.BackgroundColor3 = HURT:Lerp(HEALTHY, ratio)
		if ratio < lastRatio then
			token += 1
			local mine = token
			task.delay(0.35, function()
				if mine == token and chip.Parent then
					TweenService:Create(chip, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
						Size = UDim2.fromScale(ratio, 1),
					}):Play()
				end
			end)
		else
			chip.Size = UDim2.fromScale(ratio, 1)
		end
		lastRatio = ratio
		-- A full-health plate is clutter; it only earns the bar once someone is hurt.
		barBack.Visible = ratio < 0.999
	end

	refresh()
	-- Event driven rather than polled: health changes rarely and a per-frame loop over every
	-- player would cost more than the plate is worth.
	humanoid.HealthChanged:Connect(refresh)
	humanoid:GetPropertyChangedSignal("MaxHealth"):Connect(refresh)
	humanoid.Died:Connect(function()
		gui.Enabled = false
	end)
end

local function watch(target: Player)
	if target == player then
		return                      -- you do not need a label on your own head
	end
	target.CharacterAdded:Connect(function(character)
		task.spawn(buildPlate, target.DisplayName, character, true, target)
	end)
	if target.Character then
		task.spawn(buildPlate, target.DisplayName, target.Character, true, target)
	end
end

Players.PlayerAdded:Connect(watch)
for _, target in ipairs(Players:GetPlayers()) do
	watch(target)
end

-- ------------------------------------------------------------------- NPCs --
--
-- The things you actually fight in this game are NPCs, not other players, so labelling only
-- players would have left the readout off almost everything that can kill you.

local function watchFolder(folder: Instance, hostile: boolean)
	local function add(model: Instance)
		if model:IsA("Model") then
			task.spawn(buildPlate, model.Name, model, hostile)
		end
	end
	folder.ChildAdded:Connect(add)
	for _, model in ipairs(folder:GetChildren()) do
		add(model)
	end
end

local function considerFolder(child: Instance)
	if NPC_FOLDERS[child.Name] then
		watchFolder(child, child.Name == "NPCs")
	end
end

workspace.ChildAdded:Connect(considerFolder)
for _, child in ipairs(workspace:GetChildren()) do
	considerFolder(child)
end
