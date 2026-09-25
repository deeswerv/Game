--!strict
-- Weapon inspection input: G to bring the weapon up, drag to turn it, G to put it back.
--
-- The motion itself lives in ReplicatedStorage.InspectController, which publishes shoulder
-- offsets that WeaponPoseHold layers into the hold pose. This script only decides WHEN to
-- inspect, which keeps the input rules in one place and the animation in another.
--
-- Inspection is deliberately a soft state: it never blocks shooting or reloading. Firing
-- or reloading simply puts the weapon back down, which is what a player expects when they
-- pull the trigger with the gun up.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local InspectController = require(ReplicatedStorage:WaitForChild("InspectController"))
local WeaponConfig = require(ReplicatedStorage:WaitForChild("WeaponConfig"))

local player = Players.LocalPlayer

-- Configurable, so a controller or touch button can be added later without touching the
-- animation. Anything that can produce an InputObject KeyCode will do.
local INSPECT_KEY = Enum.KeyCode.G

local DRAG_SENSITIVITY = 0.006

local function heldWeapon(): Tool?
	local character = player.Character
	if not character then
		return nil
	end
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			local cfg = WeaponConfig.Get(child.Name)
			if cfg and cfg.Type == "Gun" then
				return child
			end
		end
	end
	return nil
end

local function stop()
	local character = player.Character
	if character then
		InspectController.End(character)
	end
end

-- Anything that ends an inspection, in one place so none of them can be forgotten.
local function watchTool(tool: Tool)
	-- Firing or reloading takes the weapon straight back to the ready position.
	tool.Activated:Connect(stop)
	tool.Unequipped:Connect(stop)
	tool:GetAttributeChangedSignal("Reloading"):Connect(function()
		if tool:GetAttribute("Reloading") then
			stop()
		end
	end)
end

local function watchCharacter(character: Model)
	-- A fresh character never inherits an inspection, and a death clears any in progress.
	InspectController.Clear(character)

	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			watchTool(child)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child:IsA("Tool") then
			stop()          -- switching weapons puts the old one down
		end
	end)
	for _, child in ipairs(character:GetChildren()) do
		if child:IsA("Tool") then
			watchTool(child)
		end
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Died:Connect(function()
			InspectController.Clear(character)
		end)
	end
end

if player.Character then
	task.spawn(watchCharacter, player.Character)
end
player.CharacterAdded:Connect(watchCharacter)

-- ------------------------------------------------------------------- input --

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= INSPECT_KEY then
		return
	end
	-- Nothing to inspect with empty hands, and nothing to inspect while a panel is open.
	local tool = heldWeapon()
	if not tool or player:GetAttribute("UIOpen") == true then
		return
	end
	local character = player.Character
	if not character then
		return
	end

	if InspectController.IsActive(character) then
		InspectController.End(character)
	else
		InspectController.Begin(character)
	end
end)

-- Drag to turn the weapon over, but only while it is up -- otherwise this would fight
-- the camera.
UserInputService.InputChanged:Connect(function(input, processed)
	if processed or input.UserInputType ~= Enum.UserInputType.MouseMovement then
		return
	end
	local character = player.Character
	if not character or not InspectController.IsActive(character) then
		return
	end
	if not UserInputService:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
		return
	end
	InspectController.Turn(character,
		-input.Delta.X * DRAG_SENSITIVITY,
		-input.Delta.Y * DRAG_SENSITIVITY)
end)
