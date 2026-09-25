--!strict
-- Death effects.
--
-- The server only announces that something died and where. Every client draws the
-- burst locally, so a busy fight does not replicate dozens of parts to everyone --
-- which is what makes gore expensive in most Roblox games.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.GameConfig)
local KillCredit = require(ServerScriptService.KillCredit)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GoreEffect = Remotes:FindFirstChild("GoreEffect")
if not GoreEffect then
	GoreEffect = Instance.new("RemoteEvent")
	GoreEffect.Name = "GoreEffect"
	GoreEffect.Parent = Remotes
end

local GoreService = {}

-- Rough colour of the body, so chunks match whatever died.
local function bodyColour(model: Model): Color3
	local torso = model:FindFirstChild("Torso") or model:FindFirstChild("UpperTorso")
	if torso and torso:IsA("BasePart") then
		return torso.Color
	end
	for _, d in ipairs(model:GetChildren()) do
		if d:IsA("BasePart") then
			return d.Color
		end
	end
	return Color3.fromRGB(160, 160, 160)
end

function GoreService.Burst(humanoid: Humanoid)
	if not GameConfig.Gore.Enabled then
		return
	end

	local model = humanoid.Parent
	if not model or not model:IsA("Model") then
		return
	end

	local root = model:FindFirstChild("HumanoidRootPart")
		or model:FindFirstChild("Torso")
		or model:FindFirstChildWhichIsA("BasePart")
	if not root or not root:IsA("BasePart") then
		return
	end

	-- Bigger creatures make a bigger mess.
	local scale = math.clamp(humanoid.MaxHealth / 100, 0.7, 2.2)

	GoreEffect:FireAllClients(root.Position, bodyColour(model), scale, root.AssemblyLinearVelocity)
end

KillCredit.HumanoidDied.Event:Connect(function(humanoid: Humanoid)
	-- Never let an effect failure interfere with the death itself.
	pcall(GoreService.Burst, humanoid)
end)

-- Players too: falls and the void do not route through KillCredit.
local function watchPlayer(player: Player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)
		if humanoid and humanoid:IsA("Humanoid") then
			humanoid.Died:Connect(function()
				pcall(GoreService.Burst, humanoid)
			end)
		end
	end)
end

Players.PlayerAdded:Connect(watchPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(watchPlayer, p)
end

return GoreService
