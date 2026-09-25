--!strict
-- Players look like themselves.
--
-- Everyone spawns on the same locked body (StarterPlayer.StarterCharacter): one R15 rig with
-- Motor6D joints that WeaponPose, ArmSolver, ReloadAnimator and the ragdoll all measure off,
-- and one hitbox so nobody's avatar is harder to hit than anybody else's. That body is kept.
--
-- What was lost with it was the player: every character was the same blue-and-teal blank.
-- This dresses the locked body in the player's OWN clothes, skin tone, hair, hats and layered
-- clothing, read from their avatar. It starts from the description the body already wears,
-- so body parts, proportions, scales and animations are untouched and the rig stays exactly
-- what the rest of the game expects -- only the cosmetic fields are copied over.
--
-- Worn accessories are made massless and invisible to raycasts, so a big hat or long hair can
-- never catch a bullet meant for the body.

local Players = game:GetService("Players")

local AvatarLook = {}

-- Turn the whole thing off without touching anything else.
AvatarLook.Enabled = true

local CLOTHING_FIELDS = { "Shirt", "Pants", "GraphicTShirt" }
local COLOUR_FIELDS = {
	"HeadColor", "TorsoColor", "LeftArmColor", "RightArmColor", "LeftLegColor", "RightLegColor",
}
local RIGID_FIELDS = {
	"HatAccessory", "HairAccessory", "FaceAccessory", "NeckAccessory",
	"ShouldersAccessory", "FrontAccessory", "BackAccessory", "WaistAccessory",
}

-- One lookup per player per session; the avatar does not change mid-game.
local cache: { [number]: HumanoidDescription } = {}

local function descriptionFor(player: Player): HumanoidDescription?
	local cached = cache[player.UserId]
	if cached then
		return cached
	end
	-- Test players in Studio have negative ids and no avatar to read.
	if player.UserId <= 0 then
		return nil
	end
	local ok, result = pcall(function()
		return Players:GetHumanoidDescriptionFromUserIdAsync(player.UserId)
	end)
	if ok and result then
		cache[player.UserId] = result
		return result
	end
	warn("[AvatarLook] could not read the avatar of " .. player.Name .. ": " .. tostring(result))
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

	-- ApplyDescription needs the character in the world.
	local waited = 0
	while not character:IsDescendantOf(workspace) and waited < 5 do
		waited += task.wait(0.1)
	end
	if not character:IsDescendantOf(workspace) or humanoid.Health <= 0 then
		return
	end

	local theirs = descriptionFor(player)
	if not theirs or player.Character ~= character then
		return
	end

	local ok, err = pcall(function()
		-- Start from what the locked body already wears: its parts, scales and animations.
		local look = humanoid:GetAppliedDescription()
		for _, field in ipairs(CLOTHING_FIELDS) do
			(look :: any)[field] = (theirs :: any)[field]
		end
		for _, field in ipairs(COLOUR_FIELDS) do
			(look :: any)[field] = (theirs :: any)[field]
		end
		for _, field in ipairs(RIGID_FIELDS) do
			(look :: any)[field] = (theirs :: any)[field]
		end
		-- Layered clothing (jackets, hoodies, shoes) wraps onto the body's own cages.
		look:SetAccessories(theirs:GetAccessories(false), false)
		-- Never let the experience's avatar rules resize or re-body the locked rig. Guarded on
		-- its own: an engine without the property should still dress the player.
		pcall(function()
			look.UseAvatarSettings = false
		end)
		humanoid:ApplyDescriptionAsync(look)
	end)
	if not ok then
		warn("[AvatarLook] could not dress " .. player.Name .. ": " .. tostring(err))
	end

	for _, child in ipairs(character:GetChildren()) do
		harmless(child)
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
	cache[player.UserId] = nil
end)

return AvatarLook
