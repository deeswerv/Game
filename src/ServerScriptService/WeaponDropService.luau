--!strict
-- Weapons dropped by dead NPCs, and picking them up.
--
-- The drop is the weapon's real model so it is recognisable on the ground, wearing a red
-- Highlight rather than any extra geometry. Pickup is a ProximityPrompt because the game
-- already uses those for the vendor, the quest giver and the hub portals -- one
-- interaction idiom rather than a second one.
--
-- Every check that matters happens here on the server: that the drop still exists, that
-- nobody has already claimed it, and that the player is actually next to it. The prompt is
-- only the invitation; it is not trusted.

local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local WeaponConfig = require(ReplicatedStorage.WeaponConfig)
-- Ownership and the loadout are ShopService's, so a weapon taken off a body is recorded the
-- same way a bought one is. Anything else would be a second, quieter idea of what you own.
local ShopService = require(ServerScriptService.ShopService)
local storeitems = ReplicatedStorage:WaitForChild("storeitems")
local highlightTemplate = ReplicatedStorage:WaitForChild("Highlight")

local WeaponDropService = {}

-- Told to the picker only: what they got, how rare it is, and whether it is new to them.
-- One remote rather than a second inventory push, because ShopService.Grant has already
-- updated the real record by the time this fires.
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local PickedUp = Remotes:FindFirstChild("WeaponPickedUp")
if not PickedUp then
	local created = Instance.new("RemoteEvent")
	created.Name = "WeaponPickedUp"
	created.Parent = Remotes
	PickedUp = created
end

WeaponDropService.Lifetime = 45          -- seconds before an unclaimed drop clears itself
local PICKUP_RANGE = 12                  -- studs; the prompt's own range plus a margin

local function dropFolder(): Folder
	local folder = workspace:FindFirstChild("WeaponDrops")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "WeaponDrops"
		folder.Parent = workspace
	end
	return folder :: Folder
end

-- Claimed flag lives on the model, so two players prompting at once cannot both win.
local function claim(model: Model): boolean
	if model:GetAttribute("Claimed") then
		return false
	end
	model:SetAttribute("Claimed", true)
	return true
end

--- Hand the weapon over for good. Returns whether the drop was consumed, and whether this
--- was the first time the player owned that weapon.
---
--- Picking something up used to clone the Tool straight into the backpack and stop there:
--- nothing was written to the profile, so the weapon vanished on rejoin and never appeared
--- in the inventory. A weapon you fought for should be yours, so ownership is recorded
--- through the same door a purchase uses -- which also fires OwnershipChanged, so the
--- inventory and the workshop see it arrive without another remote.
local function give(player: Player, weaponName: string): (boolean, boolean)
	local template = storeitems:FindFirstChild(weaponName)
	if not template or not template:IsA("Tool") then
		return false, false
	end

	local isNew = ShopService.Grant(player, "OwnedItems", weaponName)

	-- And put it in their hands now, if there is room in the loadout. EquipWeapon owns the
	-- two-slot rule, so a third weapon cannot arrive through this door.
	local character = player.Character
	local backpack = player:FindFirstChildOfClass("Backpack")
	local alreadyHolding = (backpack and backpack:FindFirstChild(weaponName))
		or (character and character:FindFirstChild(weaponName))
	if not alreadyHolding then
		pcall(ShopService.EquipWeapon, player, weaponName)
	end

	-- The drop is consumed either way: an owned weapon left lying there would just be a
	-- prompt that does nothing.
	return true, isNew
end

-- Put a weapon on the ground at `position`, free for anyone to take.
function WeaponDropService.Drop(weaponName: string, position: Vector3, velocity: Vector3?)
	local template = storeitems:FindFirstChild(weaponName)
	if not template then
		return nil
	end

	local model = Instance.new("Model")
	model.Name = weaponName
	model:SetAttribute("Weapon", weaponName)

	-- The weapon's own parts, welded into one rigid body that can be thrown about.
	local primary: BasePart? = nil
	for _, part in ipairs(template:GetDescendants()) do
		if part:IsA("BasePart") then
			local copy = part:Clone()
			for _, child in ipairs(copy:GetChildren()) do
				child:Destroy()
			end
			copy.Anchored = false
			copy.CanCollide = false
			copy.CanQuery = false
			copy.Massless = false
			copy.Parent = model
			if copy.Name == "Handle" or not primary then
				primary = copy
			end
		end
	end
	if not primary then
		model:Destroy()
		return nil
	end

	-- One collidable part carries the whole thing, so a dropped weapon is a single
	-- physics body rather than a dozen loose bricks.
	primary.CanCollide = true
	for _, part in ipairs(model:GetChildren()) do
		if part:IsA("BasePart") and part ~= primary then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = primary
			weld.Part1 = part
			weld.Parent = primary
		end
	end
	model.PrimaryPart = primary
	model:PivotTo(CFrame.new(position) * CFrame.Angles(0, math.random() * math.pi * 2, 0))

	local outline = highlightTemplate:Clone()
	outline.Name = "DropHighlight"
	outline.OutlineColor = Color3.fromRGB(255, 60, 60)
	outline.FillColor = Color3.fromRGB(255, 60, 60)
	outline.FillTransparency = 0.75       -- tinted, not painted over: the gun stays readable
	outline.OutlineTransparency = 0
	outline.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	outline.Adornee = model
	outline.Parent = model

	local cfg = WeaponConfig.Get(weaponName)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Pick up"
	prompt.ObjectText = weaponName .. (cfg and ("  \u{00B7}  " .. cfg.Rarity) or "")
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = primary

	prompt.Triggered:Connect(function(player)
		WeaponDropService.Pickup(player, model)
	end)

	model.Parent = dropFolder()
	if velocity then
		primary:ApplyImpulse(velocity * primary.AssemblyMass)
	end
	Debris:AddItem(model, WeaponDropService.Lifetime)
	return model
end

-- Server-side pickup. Nothing here trusts the caller beyond "this player pressed a prompt".
function WeaponDropService.Pickup(player: Player, model: Model): boolean
	if not model or not model.Parent or model.Parent ~= dropFolder() then
		return false                      -- gone, or never one of ours
	end
	local weaponName = model:GetAttribute("Weapon")
	if typeof(weaponName) ~= "string" or not WeaponConfig.IsWeapon(weaponName) then
		return false
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid or humanoid.Health <= 0 then
		return false
	end

	local primary = model.PrimaryPart
	if not primary or (primary.Position - root.Position).Magnitude > PICKUP_RANGE then
		return false                      -- too far: the prompt's range is not the authority
	end

	if not claim(model) then
		return false                      -- somebody else got there first
	end

	local delivered, isNew = give(player, weaponName)
	if not delivered then
		model:SetAttribute("Claimed", nil)
		return false
	end

	local cfg = WeaponConfig.Get(weaponName)
	PickedUp:FireClient(player, weaponName, cfg and cfg.Rarity or "Common", isNew)

	model:Destroy()                       -- takes the highlight and the prompt with it
	return true
end

return WeaponDropService
