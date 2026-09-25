--!strict
-- Gates weapon abilities behind ownership.
--
-- Each ability is a LocalScript inside the Tool that binds its own key. Rather than
-- editing five combat scripts to add a permission check, this disables the script
-- outright when the player has not bought the ability, so the key simply does nothing.
-- Buying it re-enables the script on the spot.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local GameConfig = require(ReplicatedStorage.GameConfig)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)

local AbilityService = {}

local function ownedSet(player: Player): { [string]: boolean }
	local set = {}
	local ok, Replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
	end)
	if ok and Replica then
		for _, id in ipairs(Replica.Data.OwnedAbilities or {}) do
			set[id] = true
		end
	end
	return set
end

-- Turn the ability scripts inside one tool on or off to match what the player owns.
local function applyToTool(player: Player, tool: Tool, owned: { [string]: boolean })
	for _, entry in ipairs(GameConfig.GetAbilitiesForTool(tool.Name)) do
		local abilityScript = tool:FindFirstChild(entry.script)
		if abilityScript and abilityScript:IsA("LuaSourceContainer") then
			(abilityScript :: any).Disabled = not owned[entry.id]
		end
	end

	-- Mirrored onto the tool so client UI can show which keys are live without
	-- having to ask the server.
	for _, entry in ipairs(GameConfig.GetAbilitiesForTool(tool.Name)) do
		tool:SetAttribute("Ability_" .. entry.id, owned[entry.id] == true)
	end
end

-- Re-apply across everything the player is currently carrying.
function AbilityService.Refresh(player: Player)
	local owned = ownedSet(player)

	local containers = {}
	local backpack = player:FindFirstChildOfClass("Backpack")
	if backpack then
		table.insert(containers, backpack)
	end
	if player.Character then
		table.insert(containers, player.Character)
	end

	for _, container in ipairs(containers) do
		for _, tool in ipairs(container:GetChildren()) do
			if tool:IsA("Tool") then
				applyToTool(player, tool, owned)
			end
		end
	end

	-- Attributes on the player too, for anything that only has the player handy.
	for _, entry in ipairs(GameConfig.Abilities) do
		player:SetAttribute("Ability_" .. entry.id, owned[entry.id] == true)
	end
end

local function watchContainer(player: Player, container: Instance)
	container.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			-- Give the tool's own children a moment to replicate in.
			task.wait(0.1)
			applyToTool(player, child :: Tool, ownedSet(player))
		end
	end)
end

local function onPlayerAdded(player: Player)
	local function hookCharacter()
		local backpack = player:WaitForChild("Backpack", 10)
		if backpack then
			watchContainer(player, backpack)
		end
		if player.Character then
			watchContainer(player, player.Character)
		end
		task.wait(0.6)
		AbilityService.Refresh(player)
	end

	player.CharacterAdded:Connect(function()
		task.spawn(hookCharacter)
	end)
	if player.Character then
		task.spawn(hookCharacter)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

return AbilityService
