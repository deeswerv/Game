--!strict
-- Draws a weapon's own 3D model into a ViewportFrame.
--
-- The weapons in this game have no 2D artwork, so the model IS the icon. Rendering it
-- live means a new weapon gets a correct picture the moment it exists, with nothing to
-- upload and no image ids to keep in step with names -- which is the usual way one gun
-- ends up wearing another gun's picture.
--
-- Shared by the combat HUD's slot bar and the inventory so the two cannot drift apart.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local storeitems = ReplicatedStorage:WaitForChild("storeitems")

local WeaponPreview = {}

export type Options = {
	Size: UDim2?,
	Position: UDim2?,
	Angle: Vector3?,          -- direction the camera sits in, relative to the weapon
	Zoom: number?,            -- >1 pulls back, <1 pushes in
	Dim: number?,             -- 0 normal, higher fades the model for locked entries
	Name: string?,
	Tint: Color3?,            -- silhouette colour; defaults to the weapon's rarity colour
}

-- Returns the ViewportFrame, and whether a model was actually found. A caller that gets
-- `false` should draw its own fallback rather than leaving an empty box.
function WeaponPreview.Render(parent: Instance, weaponName: string, opts: Options?): (ViewportFrame, boolean)
	local o: Options = opts or {}

	local vp = Instance.new("ViewportFrame")
	vp.Name = o.Name or "Preview"
	vp.Size = o.Size or UDim2.fromScale(1, 1)
	vp.Position = o.Position or UDim2.fromOffset(0, 0)
	vp.BackgroundTransparency = 1
	vp.Ambient = Color3.fromRGB(184, 186, 196)
	vp.LightColor = Color3.fromRGB(255, 252, 244)
	vp.LightDirection = Vector3.new(-0.4, -1, -0.5)
	vp.ImageTransparency = o.Dim or 0
	vp.Parent = parent

	local template = storeitems:FindFirstChild(weaponName)
	if not template then
		return vp, false
	end

	local model = Instance.new("Model")
	for _, part in ipairs(template:GetDescendants()) do
		if part:IsA("BasePart") then
			local copy = part:Clone()
			-- Welds, sounds, lights and scripts have no business in a picture.
			for _, child in ipairs(copy:GetChildren()) do
				child:Destroy()
			end
			copy.Anchored = true
			copy.CanCollide = false
			copy.CanQuery = false
			copy.Massless = true
			copy.Parent = model
		end
	end
	if #model:GetChildren() == 0 then
		model:Destroy()
		return vp, false
	end
	model.Parent = vp

	local centre, size = model:GetBoundingBox()
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.Parent = vp
	vp.CurrentCamera = camera

	-- Framed to the longest dimension, so a pistol and a rifle both fill the tile.
	local angle = (o.Angle or Vector3.new(0.35, 0.42, 1)).Unit
	local reach = math.max(size.X, size.Y, size.Z) * (o.Zoom or 1.45) + 0.6
	camera.CFrame = CFrame.lookAt(centre.Position + angle * reach, centre.Position)

	return vp, true
end

-- ------------------------------------------------------------- silhouettes --
--
-- What to draw for a weapon that is configured but whose model has not been imported yet.
--
-- Not the first letter of its name, which is what the market and the inventory both used
-- to do: "W" told you nothing, and Wasp and Warden both showed it. These are built from
-- the weapon's CLASS, so a rifle looks like a rifle and a pistol like a pistol, and they
-- disappear on their own the moment the real model exists.
--
-- Each shape is { x, y, width, height, rotation, opacity } in fractions of the tile.
local SILHOUETTES: { [string]: { { number } } } = {
	Rifle = {
		{ 0.06, 0.40, 0.86, 0.07, 0, 1.0 },   -- barrel
		{ 0.30, 0.33, 0.34, 0.18, 0, 0.8 },   -- receiver
		{ 0.06, 0.36, 0.16, 0.13, 0, 0.6 },   -- stock
		{ 0.40, 0.50, 0.11, 0.26, 8, 0.7 },   -- magazine
		{ 0.56, 0.50, 0.09, 0.19, -6, 0.6 },  -- grip
		{ 0.40, 0.24, 0.18, 0.07, 0, 0.5 },   -- optic
	},
	SMG = {
		{ 0.16, 0.40, 0.62, 0.08, 0, 1.0 },
		{ 0.30, 0.32, 0.30, 0.18, 0, 0.8 },
		{ 0.10, 0.37, 0.12, 0.12, 0, 0.6 },
		{ 0.38, 0.49, 0.11, 0.30, 6, 0.7 },
		{ 0.58, 0.49, 0.09, 0.20, -6, 0.6 },
	},
	Shotgun = {
		{ 0.06, 0.38, 0.88, 0.07, 0, 1.0 },   -- barrel
		{ 0.24, 0.46, 0.56, 0.05, 0, 0.7 },   -- magazine tube
		{ 0.34, 0.32, 0.26, 0.15, 0, 0.8 },   -- receiver
		{ 0.06, 0.34, 0.20, 0.15, 0, 0.55 },  -- wood stock
		{ 0.40, 0.44, 0.18, 0.10, 0, 0.6 },   -- forend
	},
	Pistol = {
		{ 0.20, 0.30, 0.62, 0.13, 0, 1.0 },   -- slide
		{ 0.24, 0.41, 0.20, 0.32, 14, 0.75 }, -- grip
		{ 0.42, 0.42, 0.16, 0.05, 0, 0.6 },   -- trigger guard
		{ 0.74, 0.34, 0.10, 0.05, 0, 0.6 },   -- muzzle
	},
	Melee = {
		{ 0.44, 0.06, 0.12, 0.60, 0, 1.0 },   -- blade
		{ 0.32, 0.64, 0.36, 0.06, 0, 0.7 },   -- crossguard
		{ 0.46, 0.68, 0.08, 0.22, 0, 0.6 },   -- hilt
	},
	Other = {
		{ 0.18, 0.30, 0.64, 0.40, 0, 0.8 },
		{ 0.18, 0.24, 0.64, 0.10, 0, 1.0 },
	},
}

local SHAPE_FOR_CLASS = {
	Rifle = "Rifle", Carbine = "Rifle", LMG = "Rifle", Sniper = "Rifle", Marksman = "Rifle",
	SMG = "SMG",
	Shotgun = "Shotgun",
	Pistol = "Pistol", Revolver = "Pistol",
	Dagger = "Melee", Katana = "Melee", Warhammer = "Melee", Greatsword = "Melee",
}

-- Draw the silhouette for a weapon into `parent`. False if the name is not a weapon at
-- all, in which case there is nothing sensible to draw.
function WeaponPreview.Silhouette(parent: Instance, weaponName: string, tint: Color3?): boolean
	local WeaponConfig = require(script.Parent.WeaponConfig)
	local cfg = WeaponConfig.Get(weaponName)
	if not cfg then
		return false
	end
	local shape = SHAPE_FOR_CLASS[cfg.Class] or (cfg.Type == "Melee" and "Melee") or "Other"
	local colour = tint or WeaponConfig.RarityColors[cfg.Rarity] or Color3.fromRGB(170, 176, 186)

	for _, s in ipairs(SILHOUETTES[shape]) do
		local piece = Instance.new("Frame")
		piece.Name = "Silhouette"
		piece.BackgroundColor3 = colour
		piece.BackgroundTransparency = 1 - (s[6] * 0.75)
		piece.BorderSizePixel = 0
		piece.Rotation = s[5]
		piece.Position = UDim2.fromScale(s[1], s[2])
		piece.Size = UDim2.fromScale(s[3], s[4])
		piece.Parent = parent
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0, 2)
		corner.Parent = piece
	end
	return true
end

-- The one call every weapon tile should use: the real model when it exists, a class
-- silhouette when it does not. Returns "model", "silhouette" or "none", so a caller can
-- still say something of its own if the name is not a weapon.
function WeaponPreview.Icon(parent: Instance, weaponName: string, opts: Options?): string
	local vp, drew = WeaponPreview.Render(parent, weaponName, opts)
	if drew then
		return "model"
	end
	vp:Destroy()
	if WeaponPreview.Silhouette(parent, weaponName, (opts or {}).Tint) then
		return "silhouette"
	end
	return "none"
end

return WeaponPreview
