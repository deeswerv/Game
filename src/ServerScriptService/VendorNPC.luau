--!strict
-- The market: a low-poly stall on the main path with a shopkeeper behind it. Talking to
-- them opens the same Market panel the [M] key does, so the shop is somewhere you can
-- walk to rather than only a keybind.
--
-- Built from code so the layout is reproducible and the whole thing can be rebuilt by
-- re-running this script. It used to sell abilities and stand beside spawn; the market
-- no longer has an abilities section, and it now stands on the path where players
-- actually go.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage.GameConfig)

local Theme = GameConfig.Theme

local remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "GameRemotes"
	remotes.Parent = ReplicatedStorage
end

local OpenVendor = remotes:FindFirstChild("OpenVendor")
if not OpenVendor then
	OpenVendor = Instance.new("RemoteEvent")
	OpenVendor.Name = "OpenVendor"
	OpenVendor.Parent = remotes
end

local VendorNPC = {}

-- Where the stall stands: the largest clear, flat patch beside the bend in the main
-- path, found by scanning the ground rather than by eye. It faces east across the path,
-- toward the quest giver on the far side of the bend.
local STALL_POSITION = Vector3.new(-75, 1.0, 151)
local FACING = Vector3.new(-58, 1.0, 154)

local WOOD = Color3.fromRGB(94, 63, 42)
local WOOD_DARK = Color3.fromRGB(66, 44, 30)
local CLOTH = Color3.fromRGB(122, 42, 48)

local function part(name: string, size: Vector3, cf: CFrame, color: Color3, parent: Instance): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Anchored = true
	p.CanCollide = true
	p.Material = Enum.Material.WoodPlanks
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function buildStall(root: Model, base: CFrame)
	-- Counter
	local counter = part("Counter", Vector3.new(10, 1, 3), base * CFrame.new(0, 3, 0), WOOD, root)
	counter.Material = Enum.Material.WoodPlanks

	part("CounterFront", Vector3.new(10, 3, 0.6), base * CFrame.new(0, 1.5, 1.2), WOOD_DARK, root)

	-- Posts
	for _, x in ipairs({ -4.6, 4.6 }) do
		part("Post", Vector3.new(0.6, 9, 0.6), base * CFrame.new(x, 4.5, -1.2), WOOD_DARK, root)
	end

	-- Canopy: two sloped cloth panels
	for _, sign in ipairs({ -1, 1 }) do
		local canopy = part("Canopy", Vector3.new(11, 0.4, 4),
			base * CFrame.new(0, 9.4, -1.2 + sign * 1.7) * CFrame.Angles(math.rad(sign * 18), 0, 0),
			CLOTH, root)
		canopy.Material = Enum.Material.Fabric
		canopy.CanCollide = false
	end

	-- Lantern, so the stall reads at night
	local lantern = part("Lantern", Vector3.new(0.9, 1.2, 0.9), base * CFrame.new(-4.6, 8.4, -1.2), Theme.Accent, root)
	lantern.Material = Enum.Material.Neon
	lantern.CanCollide = false

	local light = Instance.new("PointLight")
	light.Color = Theme.Accent
	light.Brightness = 3
	light.Range = 26
	light.Parent = lantern

	return counter
end

local function buildSign(root: Model, base: CFrame)
	local board = part("Sign", Vector3.new(7, 2.2, 0.3), base * CFrame.new(0, 11.4, -1.2), WOOD_DARK, root)
	board.CanCollide = false

	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(700, 220)
	gui.AlwaysOnTop = false
	gui.Parent = board

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Theme.FontBold
	label.Text = "MARKET"
	label.TextColor3 = Theme.Accent
	label.TextScaled = true
	label.Parent = gui
end

local function buildMerchant(root: Model, base: CFrame): Model?
	local template = workspace:FindFirstChild("Rig")
	if not template or not template:IsA("Model") then
		return nil
	end

	local npc = template:Clone()
	npc.Name = "Merchant"

	-- Animate is a LocalScript and will not run on a server-owned NPC; drop it so it
	-- does not sit there dead in the hierarchy.
	local animate = npc:FindFirstChild("Animate")
	if animate then
		animate:Destroy()
	end

	local hum = npc:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		-- Nothing should be able to kill the shopkeeper.
		hum.MaxHealth = math.huge
		hum.Health = math.huge
	end

	-- Dress them in the accent colour so they read as "the gold guy at the stall".
	for _, d in ipairs(npc:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
			if d.Name == "Torso" then
				d.Color = Color3.fromRGB(48, 40, 60)
			elseif d.Name == "Left Arm" or d.Name == "Right Arm" or d.Name == "Head" then
				d.Color = Color3.fromRGB(222, 186, 140)
			else
				d.Color = Color3.fromRGB(38, 34, 44)
			end
		elseif d:IsA("BodyColors") then
			d:Destroy()
		end
	end

	npc.Parent = root
	npc:PivotTo(base * CFrame.new(0, 3.2, -2.6))

	-- Floating nameplate
	local head = npc:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local bb = Instance.new("BillboardGui")
		bb.Name = "Nameplate"
		bb.Size = UDim2.fromScale(9, 2.4)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 90
		bb.Parent = head

		local title = Instance.new("TextLabel")
		title.Size = UDim2.fromScale(1, 0.55)
		title.BackgroundTransparency = 1
		title.Font = Theme.FontBold
		title.Text = "The Quartermaster's Market"
		title.TextColor3 = Theme.Accent
		title.TextScaled = true
		title.Parent = bb

		local sub = Instance.new("TextLabel")
		sub.Position = UDim2.fromScale(0, 0.55)
		sub.Size = UDim2.fromScale(1, 0.45)
		sub.BackgroundTransparency = 1
		sub.Font = Theme.Font
		sub.Text = "Press E to shop"
		sub.TextColor3 = Theme.TextDim
		sub.TextScaled = true
		sub.Parent = bb
	end

	return npc
end

function VendorNPC.Build()
	-- The old name is cleaned up too, so re-running this does not leave the retired
	-- ability stall standing beside spawn.
	for _, name in ipairs({ "MarketStall", "AbilityVendor" }) do
		local existing = workspace:FindFirstChild(name)
		if existing then
			existing:Destroy()
		end
	end

	local root = Instance.new("Model")
	root.Name = "MarketStall"

	local base = CFrame.lookAt(STALL_POSITION, Vector3.new(FACING.X, STALL_POSITION.Y, FACING.Z))

	local counter = buildStall(root, base)
	buildSign(root, base)
	buildMerchant(root, base)

	root.Parent = workspace
	root.PrimaryPart = counter

	-- Interaction lives on the counter so it triggers from the customer's side.
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open Market"
	prompt.ObjectText = "Market"
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	prompt.Triggered:Connect(function(player)
		OpenVendor:FireClient(player)
	end)

	return root
end

VendorNPC.Build()

return VendorNPC
