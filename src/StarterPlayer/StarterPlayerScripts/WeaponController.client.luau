--!strict
-- Weapon feel, client side. Drives every Tool listed in ReplicatedStorage.WeaponConfig,
-- so adding a weapon needs no new script: aiming, firing input, recoil, spread,
-- crosshair, muzzle flash, tracers and the ammo readout all come from the config.
--
-- Nothing here decides damage or ammo. It sends intent and draws the result.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local WeaponConfig = require(ReplicatedStorage.WeaponConfig)
local ReloadAnimator = require(ReplicatedStorage:WaitForChild("ReloadAnimator"))
local ViewKick = require(ReplicatedStorage:WaitForChild("ViewKick"))
local CombatFX = require(ReplicatedStorage:WaitForChild("CombatFX"))
local WeaponAudio = require(ReplicatedStorage:WaitForChild("WeaponAudio"))

local player = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local GunAction = Remotes:WaitForChild("GunAction") :: RemoteEvent
local GunEffect = Remotes:WaitForChild("GunEffect") :: RemoteEvent
local MeleeAction = Remotes:WaitForChild("MeleeAction") :: RemoteEvent
local MeleeEffect = Remotes:WaitForChild("MeleeEffect") :: RemoteEvent

local camera = workspace.CurrentCamera

local equipped: Tool? = nil
local cfg = nil
local firing = false
-- Latches when the trigger is pulled on an empty magazine, so the dry-fire click is one
-- click per pull rather than one per frame. Cleared wherever `firing` is cleared.
local clickedEmpty = false

-- Which shot of the burst this is. The recoil pattern is keyed to it, so shot 4 of a burst
-- pulls the same way every magazine and the weapon can actually be learned. Reset once the
-- aim has settled, which is what makes tapping and holding feel different.
local shotIndex = 0
-- Resolved recoil for the equipped weapon, from its config block. Cached per equip rather
-- than rebuilt per shot.
local recoilProfile = nil
local ads = false
local heat = 0
local lastShot = 0
local baseFov = camera.FieldOfView

-- Camera recoil is tracked as an absolute angle we drift back from. ViewKick turns it
-- into a per-frame delta so it composes with normal camera control instead of fighting it.
local recoil = Vector2.new()

-- A small field-of-view punch per shot, decaying every frame. Folded into the FOV target
-- below rather than written to the camera, because this script is the FOV's one owner.
local fovKick = 0

-- ---------------------------------------------------------------- crosshair --

local gui = Instance.new("ScreenGui")
gui.Name = "WeaponHUD"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

-- A centre dot and four short arms, every piece edged in dark so it reads against pale sky
-- and dark walls alike -- the halo the old dot relied on disappeared against sand.
--
-- The arms are the weapon talking: they sit at the gun's real spread (the same cone the
-- server rolls, converted from degrees to pixels at the current FOV), bloom outward on every
-- shot and settle back as the aim recovers. Aiming down sights fades them and leaves the dot.
local CROSS_COLOUR = Color3.new(1, 1, 1)
local CROSS_EDGE = Color3.fromRGB(10, 10, 14)

local function crossPiece(size: Vector2, round: boolean): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.Size = UDim2.fromOffset(size.X, size.Y)
	f.BackgroundColor3 = CROSS_COLOUR
	f.BorderSizePixel = 0
	f.ZIndex = 3
	f.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = round and UDim.new(1, 0) or UDim.new(0, 1)
	c.Parent = f
	local e = Instance.new("UIStroke")
	e.Color = CROSS_EDGE
	e.Thickness = 1.3
	e.Transparency = 0.15
	e.Parent = f
	return f
end

local reticle = crossPiece(Vector2.new(4, 4), true)
reticle.Name = "Reticle"

local ARM_LENGTH = 9
local arms = {}
for _, dir in ipairs({ Vector2.new(0, -1), Vector2.new(0, 1), Vector2.new(-1, 0), Vector2.new(1, 0) }) do
	local size = dir.X == 0 and Vector2.new(2, ARM_LENGTH) or Vector2.new(ARM_LENGTH, 2)
	local arm = crossPiece(size, false)
	arm.Name = "Arm"
	table.insert(arms, { frame = arm, dir = dir })
end

-- Extra gap added by the last few shots, in pixels. Decays every frame.
local bloom = 0

-- The hitmarker is four short diagonal strokes that snap outward, not a letter: legible in
-- a single frame at the centre of a busy screen. Outlined like the crosshair.
local hitStrokes = {}
for _, dir in ipairs({ Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) }) do
	local stroke = Instance.new("Frame")
	stroke.AnchorPoint = Vector2.new(0.5, 0.5)
	stroke.Size = UDim2.fromOffset(13, 3)
	stroke.BackgroundColor3 = Color3.new(1, 1, 1)
	stroke.BorderSizePixel = 0
	stroke.BackgroundTransparency = 1
	stroke.Rotation = (dir.X * dir.Y > 0) and 45 or -45
	stroke.ZIndex = 5
	stroke.Parent = gui
	local edge = Instance.new("UIStroke")
	edge.Color = CROSS_EDGE
	edge.Thickness = 1.3
	edge.Transparency = 1
	edge.Parent = stroke
	table.insert(hitStrokes, { frame = stroke, dir = dir, edge = edge })
end

-- The ammo readout lives in StarterPlayerScripts.CombatHUD now, alongside the weapon
-- slots and the kill feed. This script keeps the crosshair and the hitmarker.
local function refreshAmmo()
end

-- The hit confirm. The sample is 1.38s long, which would trail over the next three shots
-- of an automatic weapon, so only its attack is used: play it and cut it after 80ms. What
-- is wanted here is a click, and the click is the first few milliseconds of almost any
-- impact sound.
local HIT_CLICK_LENGTH = 0.08

local HIT_SOUND = Instance.new("Sound")
HIT_SOUND.Name = "HitConfirm"
HIT_SOUND.SoundId = "rbxassetid://3398620867"
HIT_SOUND.Volume = 0.4
HIT_SOUND.Parent = gui

local function flashHitmarker(headshot: boolean, lethal: boolean?)
	local colour
	if lethal then
		colour = Color3.fromRGB(255, 80, 80)
	elseif headshot then
		colour = Color3.fromRGB(255, 196, 92)
	else
		colour = Color3.new(1, 1, 1)
	end

	-- A kill spreads further, grows, twists and holds a beat longer, so a finished target is
	-- distinguishable from a hit without having to read the health bar.
	local start = lethal and 9 or 6
	local finish = lethal and 22 or 13
	local life = lethal and 0.38 or 0.22
	local length = lethal and 18 or 13

	for _, s in ipairs(hitStrokes) do
		local base = (s.dir.X * s.dir.Y > 0) and 45 or -45
		s.frame.BackgroundColor3 = colour
		s.frame.BackgroundTransparency = 0
		s.edge.Transparency = 0.1
		s.frame.Size = UDim2.fromOffset(length, lethal and 4 or 3)
		s.frame.Rotation = base
		s.frame.Position = UDim2.new(0.5, s.dir.X * start, 0.5, s.dir.Y * start)
		local info = TweenInfo.new(life, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		TweenService:Create(s.frame, info, {
			BackgroundTransparency = 1,
			Position = UDim2.new(0.5, s.dir.X * finish, 0.5, s.dir.Y * finish),
			Rotation = base + (lethal and 20 or 0),
		}):Play()
		TweenService:Create(s.edge, info, { Transparency = 1 }):Play()
	end
	-- The arms flinch outward with the marker, so the whole crosshair answers the hit.
	bloom = math.max(bloom, lethal and 10 or 5)

	if HIT_SOUND.SoundId ~= "" then
		-- Pitch carries the same information as the colour: low for a kill, high for a
		-- headshot, so a player can tell what happened without looking at the crosshair.
		HIT_SOUND.PlaybackSpeed = lethal and 0.75 or (headshot and 1.35 or 1)
		HIT_SOUND.TimePosition = 0
		HIT_SOUND:Play()
		task.delay(lethal and HIT_CLICK_LENGTH * 2 or HIT_CLICK_LENGTH, function()
			HIT_SOUND:Stop()
		end)
	end
end

-- ------------------------------------------------------------------ effects --

--- The part of a shot that needs no server answer: the flash, the case, the bang.
---
--- Split out so the shooter can play it the instant the trigger goes down, and everyone
--- else can play it when the broadcast arrives.
local function fireFeedback(tool: Tool, wcfg)
	CombatFX.MuzzleFlash(tool, wcfg.MuzzleFlashColor)
	CombatFX.EjectShell(tool)
	local handle = tool:FindFirstChild("Handle")
	local sound = handle and handle:FindFirstChild("Fire")
	if sound and sound:IsA("Sound") then
		-- Nudge the pitch each shot. Without this, holding the trigger replays one identical
		-- sample and the weapon sounds like a looping effect rather than a gun.
		WeaponAudio.Vary(sound)
		sound:Play()
	end
end

-- Effects for every player's shots, including our own.
GunEffect.OnClientEvent:Connect(function(kind, ...)
	if kind == "Shot" then
		local shooter, tool, origin, endPoints = ...
		local wcfg = tool and WeaponConfig.Get(tool.Name)
		if not wcfg then
			return
		end
		-- Our own flash, case and gunshot already played the instant the trigger went down.
		-- Replaying them here would double every shot we fire.
		if shooter ~= player then
			fireFeedback(tool, wcfg)
		end
		-- The weapon's name is passed so a gun that shipped its own tracer and impact
		-- geometry uses those; anything else falls through to the built-in effects.
		local weaponName = tool and tool.Name
		for _, p in ipairs(endPoints) do
			CombatFX.Tracer(origin, p, wcfg.TracerColor, wcfg.TracerWidth, weaponName)
			CombatFX.Impact(p, origin, weaponName)
		end
	elseif kind == "Hitmarker" then
		local headshot, lethal = ...
		flashHitmarker(headshot == true, lethal == true)
	elseif kind == "Damage" then
		local position, amount, headshot, lethal = ...
		if typeof(position) == "Vector3" and type(amount) == "number" then
			CombatFX.DamageNumber(position, amount, headshot == true, lethal == true)
		end
	elseif kind == "HitFlash" then
		local models, lethalFlags = ...
		if type(models) == "table" then
			for i, m in ipairs(models) do
				if typeof(m) == "Instance" and m:IsA("Model") then
					local lethal = type(lethalFlags) == "table" and lethalFlags[i] == true or false
					CombatFX.HitFlash(m, lethal)
					if lethal then
						CombatFX.KillBurst(m)
					end
				end
			end
		end
	elseif kind == "Reload" then
		local shooter, tool, needsCharge, duration = ...
		local wcfg = tool and WeaponConfig.For(tool)
		local character = shooter and shooter.Character
		if not wcfg or not character then
			return
		end

		-- The existing one-shot reload sound still plays; the staged beats layered on top
		-- of it come from ReloadAnimator, off the same Handle.
		local handle = tool:FindFirstChild("Handle")
		local sound = handle and handle:FindFirstChild("Reload")
		if sound and sound:IsA("Sound") and sound.SoundId ~= "" then
			sound:Play()
		end

		-- Runs for every character, not just the local one, so other players are seen to
		-- reload properly too.
		ReloadAnimator.Play(character, tool, wcfg, needsCharge == true, duration or wcfg.ReloadTime)
	elseif kind == "ReloadCancel" then
		local shooter = ...
		local character = shooter and shooter.Character
		if character then
			ReloadAnimator.Cancel(character)
		end
	end
end)

-- -------------------------------------------------------------------- input --

local function aimPoint(): Vector3
	local mouse = UserInputService:GetMouseLocation()
	local ray = camera:ViewportPointToRay(mouse.X, mouse.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { player.Character, workspace:FindFirstChild("Debris") }
	local result = workspace:Raycast(ray.Origin, ray.Direction * (cfg and cfg.Range or 500), params)
	return result and result.Position or (ray.Origin + ray.Direction * (cfg and cfg.Range or 500))
end

local function tryShoot()
	local tool = equipped
	if not tool or not cfg or tool:GetAttribute("Reloading") then
		return
	end
	if (tool:GetAttribute("Ammo") or 0) <= 0 then
		-- Once per trigger pull, not once per frame. tryShoot runs every frame while the
		-- button is held, so an unguarded click here would machine-gun the empty sound.
		if not clickedEmpty then
			clickedEmpty = true
			WeaponAudio.Play(tool, "Empty")
		end
		GunAction:FireServer("reload", tool)
		return
	end
	clickedEmpty = false
	if os.clock() - lastShot < cfg.FireRate then
		return
	end
	lastShot = os.clock()

	-- Predictive kick so the gun feels instant; the server still rules on the shot.
	--
	-- The pattern comes from the weapon's own Recoil block rather than being generated here,
	-- so tuning a gun is a data edit. Horizontal follows a repeating wave keyed to the shot
	-- index instead of being re-rolled every shot: the old line was pure noise, which cannot
	-- be learned and so reads as the weapon being unreliable rather than powerful.
	shotIndex += 1
	local profile = recoilProfile or WeaponConfig.Recoil(cfg)
	local vertical, horizontal = WeaponConfig.RecoilStep(profile, shotIndex, ads)
	recoil = Vector2.new(recoil.X + vertical, recoil.Y + horizontal)
	heat = math.min(heat + cfg.SpreadPerShot, cfg.SpreadMax)

	-- Separate from recoil: recoil moves the aim and stays until pulled back down, this
	-- is the jolt that always returns. Aiming damps it, the way bracing a weapon does.
	ViewKick.Fire(profile.Kick * (ads and profile.AdsMultiplier or 1))
	fovKick = math.min(fovKick + (ads and 0.5 or 1.4), 4)
	bloom = math.min(bloom + 4, 16)

	GunAction:FireServer("shoot", tool, aimPoint(), ads)

	-- Played HERE, not when the server's broadcast comes back.
	--
	-- The camera kick was already instant; the flash, the case and the gunshot were not --
	-- they waited on GunEffect, which is a full round trip. In Studio that is invisible
	-- because the server is the same machine; on a live server it is the whole difference
	-- between a weapon that answers the trigger and one that feels like it is thinking
	-- about it.
	--
	-- The tracer and the impact are deliberately NOT predicted. Only the server knows what
	-- the shot actually hit, and a tracer drawn to a guessed endpoint would visibly disagree
	-- with the hitmarker. Those still come from the broadcast a few frames later, where
	-- arriving late is not something anyone can perceive.
	fireFeedback(tool, cfg)
end

local function setEquipped(tool: Tool?)
	equipped = tool
	-- .For, not .Get: the recoil, spread, rate and zoom the player feels have to be the
	-- ones their equipped build actually produces, or a scope would look like it steadies
	-- the weapon while the gun kicks exactly as hard as before.
	cfg = tool and WeaponConfig.For(tool) or nil
	if cfg and cfg.Type ~= "Gun" then
		cfg = nil
	end
	gui.Enabled = cfg ~= nil
	recoilProfile = cfg and WeaponConfig.Recoil(cfg) or nil
	shotIndex = 0
	firing = false
	clickedEmpty = false
	ads = false
	player:SetAttribute("ADS", false)
	heat = 0
	if cfg then
		refreshAmmo()
	end
end

-- A swing arc drawn in front of the player, coloured per weapon.
local function swingTrail(character: Model, wcfg)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local arc = Instance.new("Part")
	arc.Anchored = true
	arc.CanCollide = false
	arc.CanQuery = false
	arc.CastShadow = false
	arc.Material = Enum.Material.Neon
	arc.Color = wcfg.TrailColor
	arc.Transparency = 0.35
	arc.Size = Vector3.new(wcfg.MeleeRange * 1.4, 0.25, wcfg.MeleeRange * 1.4)
	arc.CFrame = root.CFrame * CFrame.new(0, 0.4, -wcfg.MeleeRange * 0.35)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Scale = Vector3.new(1, 0.12, 1)
	mesh.Parent = arc
	arc.Parent = workspace
	TweenService:Create(arc, TweenInfo.new(0.22), {
		Transparency = 1,
		Size = arc.Size * 1.25,
	}):Play()
	Debris:AddItem(arc, 0.25)
end

MeleeEffect.OnClientEvent:Connect(function(swinger, tool, combo, hitCount)
	local wcfg = tool and WeaponConfig.Get(tool.Name)
	if not wcfg then
		return
	end
	local character = swinger and swinger.Character
	swingTrail(character, wcfg)

	local handle = tool:FindFirstChild("Handle")
	local swing = handle and handle:FindFirstChild("Fire")
	if swing and swing:IsA("Sound") and swing.SoundId ~= "" then
		WeaponAudio.Vary(swing)
		swing:Play()
	end

	if swinger == player and hitCount and hitCount > 0 then
		flashHitmarker(false)
		-- A heavier weapon shoves the camera more.
		ViewKick.Melee(math.clamp(wcfg.Knockback / 90, 0.3, 2))
	end
end)

local function hookMelee(tool: Tool, wcfg)
	tool.Equipped:Connect(function()
		camera = workspace.CurrentCamera
		equipped = tool
		cfg = nil          -- melee has no ammo/crosshair state
		firing = false     -- never inherit a held mouse button from the last weapon
		gui.Enabled = false
	end)
	tool.Unequipped:Connect(function()
		if equipped == tool then
			equipped = nil
			firing = false
		end
	end)
	tool.Activated:Connect(function()
		firing = true
		MeleeAction:FireServer(tool)
	end)
	tool.Deactivated:Connect(function()
		firing = false
	end)
end

local function hookTool(tool: Tool)
	local wcfg = WeaponConfig.Get(tool.Name)
	if not wcfg then
		return
	end
	if wcfg.Type == "Melee" then
		-- Only config-driven melee; the Greatsword and Blood Sword keep their own scripts.
		if wcfg.GenericMelee then
			hookMelee(tool, wcfg)
		end
		return
	end
	tool.Equipped:Connect(function()
		camera = workspace.CurrentCamera
		baseFov = camera.FieldOfView
		setEquipped(tool)
		WeaponAudio.Play(tool, "Equip")
	end)
	tool.Unequipped:Connect(function()
		WeaponAudio.Play(tool, "Unequip")
		if equipped == tool then
			setEquipped(nil)
		end
	end)
	tool.Activated:Connect(function()
		firing = true
		tryShoot()
	end)
	tool.Deactivated:Connect(function()
		firing = false
		clickedEmpty = false      -- releasing the trigger re-arms the dry-fire click
	end)
	tool:GetAttributeChangedSignal("Ammo"):Connect(refreshAmmo)
	tool:GetAttributeChangedSignal("Reloading"):Connect(refreshAmmo)

	-- Equipping a different build re-stamps these while the weapon is still in hand, so
	-- the cached stats have to be picked up again rather than waiting for a re-equip.
	for _, row in ipairs(WeaponConfig.TunableStats) do
		tool:GetAttributeChangedSignal("Stat_" .. row.key):Connect(function()
			if equipped == tool then
				setEquipped(tool)
			end
		end)
	end
end

local function watch(container: Instance)
	container.ChildAdded:Connect(function(c)
		if c:IsA("Tool") then
			hookTool(c)
		end
	end)
	for _, c in ipairs(container:GetChildren()) do
		if c:IsA("Tool") then
			hookTool(c)
		end
	end
end

local function onCharacter(char: Model)
	watch(char)
	local bp = player:WaitForChild("Backpack", 10)
	if bp then
		watch(bp)
	end
	setEquipped(nil)
end

if player.Character then
	task.spawn(onCharacter, player.Character)
end
player.CharacterAdded:Connect(onCharacter)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or not equipped or not cfg then
		return
	end
	if input.KeyCode == Enum.KeyCode.R then
		GunAction:FireServer("reload", equipped)
	elseif input.UserInputType == Enum.UserInputType.MouseButton2 then
		ads = true
		-- The camera script frames the shot; it needs to know the stance, and an attribute
		-- is the cheapest way to say so without the two scripts requiring each other.
		player:SetAttribute("ADS", true)
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		ads = false
		player:SetAttribute("ADS", false)
	elseif input.UserInputType == Enum.UserInputType.MouseButton1
		or input.UserInputType == Enum.UserInputType.Touch then
		-- A second, independent way to release the trigger.
		--
		-- Tool.Deactivated remains the primary and is perfectly fine; this is belt-and-braces
		-- for the cases where it genuinely does not arrive -- the tool being unequipped or
		-- destroyed mid-hold, or the window losing focus with the button down. Whichever
		-- signal comes first stops the gun, and clearing an already-cleared latch is free.
		--
		-- Worth recording honestly: this was originally added because a 30ms synthetic press
		-- measured 318ms to Deactivated. That turned out to be the TEST HARNESS -- the same
		-- press measured 334ms through UserInputService, which is the input arriving late, not
		-- the Tool signal being slow. There was no bug. The handler is kept on its own merits.
		firing = false
		clickedEmpty = false
	end
end)

-- ---------------------------------------------------------------- aim report --

-- The weapon follows where the camera is pointed, and everyone needs to see that on
-- everyone else, so the pitch has to reach the server. Sent only while a gun is out,
-- only when it has actually moved, and at most ten times a second -- the pose is
-- smoothed on the receiving end, so nothing is gained by sending it faster.
local AimUpdate = Remotes:WaitForChild("AimUpdate") :: RemoteEvent
local lastSentPitch = 0
local lastSentAiming = false
local lastSentSprint = false
local lastSentAt = 0

-- StarterPlayerScripts.ShiftLock owns the sprint -- it decides it from the shift key, the
-- double-tap, whether a menu is open, whether the player is aiming, and whether they are
-- actually moving forwards -- and publishes the answer on the player. Reading that is
-- exact and costs nothing. Re-deriving it here from WalkSpeed would be a second opinion
-- that has to be kept in step with the first, and would quietly disagree the moment
-- anything else touched the humanoid's speed.
local function isSprinting(): boolean
	return player:GetAttribute("Sprinting") == true
end

local function reportAim()
	if not cfg then
		return
	end
	local now = os.clock()
	-- The camera's own pitch, in degrees, positive when looking up.
	local pitch = math.deg(math.asin(math.clamp(camera.CFrame.LookVector.Y, -1, 1)))
	local sprinting = isSprinting()

	-- Raising or lowering the weapon goes out at once, and so does breaking into or out of
	-- a sprint. Making a stance change wait on the ordinary throttle is the difference
	-- between the weapon feeling instant and feeling sticky, and both change far too rarely
	-- to be worth rate limiting.
	if ads == lastSentAiming and sprinting == lastSentSprint then
		if now - lastSentAt < 0.1 or math.abs(pitch - lastSentPitch) < 2 then
			return
		end
	end

	lastSentPitch = pitch
	lastSentAiming = ads
	lastSentSprint = sprinting
	lastSentAt = now
	AimUpdate:FireServer(pitch, ads, sprinting)
end

-- ------------------------------------------------------------- per-frame --

RunService.RenderStepped:Connect(function(dt)
	camera = workspace.CurrentCamera
	if not camera then
		return
	end

	-- Guns support held-down automatic fire; melee is strictly one swing per click,
	-- handled in Tool.Activated.
	if firing and equipped and cfg and cfg.Automatic then
		tryShoot()
	end

	reportAim()

	-- Recoil settles back toward zero. Published as an absolute angle rather than applied
	-- here, because the camera script is the only thing allowed to touch camera.CFrame --
	-- it folds this together with the firing kick into one delta per frame. Two scripts
	-- multiplying the same camera independently is how aim ends up drifting.
	if cfg then
		local profile = recoilProfile or WeaponConfig.Recoil(cfg)
		recoil = recoil:Lerp(Vector2.new(), math.clamp(profile.Recovery * dt, 0, 1))
		-- Once the aim has essentially settled, the burst is over and the next trigger pull
		-- starts the pattern again from shot one. Without this, a magazine emptied in bursts
		-- would climb as though it had been held down the whole time.
		if shotIndex > 0 and recoil.Magnitude < 0.02 then
			shotIndex = 0
		end
	else
		recoil = Vector2.new()
		shotIndex = 0
	end
	ViewKick.SetAimOffset(recoil.X, -recoil.Y)

	-- Aim down sights: narrow the FOV.
	--
	-- The sprint widen is folded in HERE rather than applied by ShiftLock. This line lerps
	-- towards an absolute target every frame, so anything another script adds to the camera
	-- gets dragged back out within a few frames -- which is exactly what was happening to the
	-- sprint boost. One owner for the property; everyone else contributes to the target.
	local sprintFov = player:GetAttribute("SprintFovAdd")
	fovKick *= math.exp(-16 * dt)
	local wantFov = ((cfg and ads) and cfg.AdsFov or baseFov)
		+ (typeof(sprintFov) == "number" and sprintFov or 0)
		+ fovKick
	camera.FieldOfView += (wantFov - camera.FieldOfView) * math.clamp((cfg and cfg.AdsSpeed or 12) * dt, 0, 1)

	-- Crosshair opens with spread.
	if cfg then
		heat = math.max(0, heat - cfg.SpreadRecovery * dt)
		local spread = math.clamp(cfg.SpreadMin + heat, cfg.SpreadMin, cfg.SpreadMax)
		if ads then
			spread *= cfg.AdsSpreadScale
		end
		-- Convert the cone angle to pixels at the current FOV, plus whatever the last shots
		-- bloomed it by.
		bloom = math.max(0, bloom - bloom * math.min(10 * dt, 1))
		local pixelsPerDegree = camera.ViewportSize.Y / camera.FieldOfView
		local gap = 4 + spread * pixelsPerDegree + bloom + ARM_LENGTH / 2
		local armFade = ads and 0.75 or 0
		for _, arm in ipairs(arms) do
			arm.frame.Position = UDim2.new(0.5, arm.dir.X * gap, 0.5, arm.dir.Y * gap)
			arm.frame.BackgroundTransparency = armFade
		end
		reticle.BackgroundTransparency = 0
	end
end)
