--!strict
-- Players look like themselves.
--
-- Everyone spawns on the same locked body (StarterPlayer.StarterCharacter): one R15 rig with
-- Motor6D joints that WeaponPose, ArmSolver, ReloadAnimator and the ragdoll all measure off,
-- and one hitbox so nobody's avatar is harder to hit than anybody else's. That body is kept.
--
-- This dresses it in the player's OWN clothes, skin tone, hair, hats and layered clothing.
--
-- HOW, and why not ApplyDescription: the body's stored HumanoidDescription does not match
-- the meshes it actually wears (it lists a default head and older limb ids), so asking the
-- engine to apply any description makes it REBUILD every body part. The rebuilt parts come
-- rigged with the engine's AnimationConstraints, which RigNormalise deletes on sight so the
-- Motor6D code keeps working -- leaving a body with no joints at all. The character fell
-- apart and died on every spawn.
--
-- So the live body is never handed to the engine. The player's avatar is built OFF-SCREEN
-- as its own model (once per session), and only the pieces that sit on top of a body are
-- copied across: the Shirt/Pants/T-shirt, the skin colours, and each accessory attached the
-- ordinary way through Humanoid:AddAccessory. Nothing about the rig itself changes.
--
-- Worn accessories are made massless and invisible to raycasts, so a big hat or long hair can
-- never catch a bullet meant for the body.

local Players = game:GetService("Players")

local AvatarLook = {}

-- Turn the whole thing off without touching anything else.
AvatarLook.Enabled = true

local COLOUR_FIELDS = {
	"HeadColor3", "TorsoColor3", "LeftArmColor3", "RightArmColor3", "LeftLegColor3", "RightLegColor3",
}

-- The player's avatar, built once per session and never parented anywhere.
local built: { [number]: Model | false } = {}
local building: { [number]: boolean } = {}

local function avatarFor(player: Player): Model?
	local userId = player.UserId
	-- Test players in Studio's multi-client mode have negative ids and no avatar to read.
	if userId <= 0 then
		return nil
	end
	-- Two spawns racing each other share one build.
	while building[userId] do
		task.wait(0.1)
	end
	local cached = built[userId]
	if cached ~= nil then
		return cached or nil
	end
	building[userId] = true
	local ok, result = pcall(function()
		local description = Players:GetHumanoidDescriptionFromUserIdAsync(userId)
		return Players:CreateHumanoidModelFromDescriptionAsync(description, Enum.HumanoidRigType.R15)
	end)
	building[userId] = nil
	if ok and result then
		built[userId] = result
		return result
	end
	-- Remembered as a failure so a broken avatar service is not asked again every respawn.
	built[userId] = false
	warn("[AvatarLook] could not build the avatar of " .. player.Name .. ": " .. tostring(result))
	return nil
end

--- Accessories are decoration: no mass, no collision, and never hit by a shot.
local function harmless(accessory: Instance)
	if not accessory:IsA("Accoutrement") then
		return
	end
	for _, d in ipairs(accessory:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Massless = true
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
		end
	end
end

local function dress(player: Player, character: Model)
	if not AvatarLook.Enabled then
		return
	end
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end

	local source = avatarFor(player)
	if not source or player.Character ~= character or humanoid.Health <= 0 then
		return
	end

	local ok, err = pcall(function()
		-- Clothing: replace whatever the body came with.
		for _, child in ipairs(character:GetChildren()) do
			if child:IsA("Clothing") or child:IsA("ShirtGraphic") then
				child:Destroy()
			end
		end
		for _, child in ipairs(source:GetChildren()) do
			if child:IsA("Clothing") or child:IsA("ShirtGraphic") then
				child:Clone().Parent = character
			end
		end

		-- Skin: the body's own BodyColors takes the avatar's colours.
		local from = source:FindFirstChildOfClass("BodyColors")
		if from then
			local to = character:FindFirstChildOfClass("BodyColors")
			if not to then
				to = Instance.new("BodyColors")
				to.Parent = character
			end
			for _, field in ipairs(COLOUR_FIELDS) do
				(to :: any)[field] = (from :: any)[field]
			end
		end

		-- Accessories, attached the ordinary way. The copy's old weld points at the
		-- off-screen model, so it is removed and AddAccessory makes a fresh one.
		for _, child in ipairs(source:GetChildren()) do
			if child:IsA("Accessory") then
				local copy = child:Clone()
				for _, d in ipairs(copy:GetDescendants()) do
					if d:IsA("JointInstance") or d:IsA("WeldConstraint") then
						d:Destroy()
					end
				end
				harmless(copy)
				humanoid:AddAccessory(copy)
			end
		end
	end)
	if not ok then
		warn("[AvatarLook] could not dress " .. player.Name .. ": " .. tostring(err))
	end
end

local function watch(player: Player)
	player.CharacterAdded:Connect(function(character)
		-- Whatever joins the character later (a re-applied hat) gets the same treatment.
		character.ChildAdded:Connect(harmless)
		task.spawn(dress, player, character)
	end)
	if player.Character then
		player.Character.ChildAdded:Connect(harmless)
		task.spawn(dress, player, player.Character)
	end
end

Players.PlayerAdded:Connect(watch)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(watch, player)
end
Players.PlayerRemoving:Connect(function(player)
	local model = built[player.UserId]
	if model then
		model:Destroy()
	end
	built[player.UserId] = nil
end)

return AvatarLook
