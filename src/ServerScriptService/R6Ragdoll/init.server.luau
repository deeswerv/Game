-- SERVICES --
local CS = game:GetService("CollectionService")
local StarterPlayer = game:GetService("StarterPlayer")

-- MODULES --
local ragdollBuilder = require(script.RagdollBuilder)

script.RagdollClient.Parent = StarterPlayer.StarterPlayerScripts

-- Preparing a character is RagdollBuilder's job, and it knows both rigs. This used to
-- inline its own copy of the R6 clone-the-template code -- twice, once per branch -- which
-- meant three places to keep in step and threw "Torso is not a valid member" on every
-- spawn the moment the players moved to R15.
local function prepare(char: Model)
	-- The rig has to be assembled before its joints can be read.
	if not char:FindFirstChild("HumanoidRootPart") then
		char:WaitForChild("HumanoidRootPart", 10)
	end
	local ok, err = pcall(function()
		ragdollBuilder:Setup(char)
	end)
	if not ok then
		warn("[Ragdoll] could not prepare " .. char.Name .. ": " .. tostring(err))
	end
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(char)
		task.spawn(prepare, char)
	end)
	if player.Character then
		task.spawn(prepare, player.Character)
	end
end

game.Players.PlayerAdded:Connect(watch)
for _, player in ipairs(game.Players:GetPlayers()) do
	watch(player)
end

CS:GetInstanceAddedSignal("Ragdoll"):Connect(function(v)
	if v:IsA("Model") then
		ragdollBuilder:Ragdoll(v)
	end
end)

CS:GetInstanceRemovedSignal("Ragdoll"):Connect(function(v)
	if v:IsA("Model") then
		ragdollBuilder:Unragdoll(v)
	end
end)
