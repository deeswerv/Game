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
local GunHandling = require(ReplicatedStorage:WaitForChild("GunHandling"))
local ReloadAnimator = require(ReplicatedStorage:WaitForChild("ReloadAnimator"))
local ViewKick = require(ReplicatedStorage:WaitForChild("ViewKick"))
local CombatFX = require(ReplicatedStorage:WaitForChild("CombatFX"))
local WeaponAudio = require(ReplicatedStorage:WaitForChild("WeaponAudio"))
local UISound = require(ReplicatedStorage:WaitForChild("UI"):WaitForChild("Modules"):WaitForChild("UISound"))

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
-- The reload in progress on the equipped weapon: when it started, how long the server said
-- it takes, and whether it is the quicker tactical one (a round still chambered).
local reloadStartedAt: number? = nil
local reloadDuration: number? = nil
local reloadTactical = false
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

-- ------------------------------------------------------------- class shapes --

-- A shotgun throws a cone, not a line, so its crosshair is a RING the size of the pellet
-- spread: everything inside it is what the next shot covers. Two circles, dark under white,
-- for the same outlined look as the arms.
local function ring(thickness: number, colour: Color3, z: number): Frame
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = UDim2.fromScale(0.5, 0.5)
	f.BackgroundTransparency = 1
	f.Visible = false
	f.ZIndex = z
	f.Parent = gui
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(1, 0)
	c.Parent = f
	local st = Instance.new("UIStroke")
	st.Color = colour
	st.Thickness = thickness
	st.Parent = f
	return f
end
local ringEdge = ring(3.4, CROSS_EDGE, 2)
ringEdge.Name = "RingEdge"
local ringLine = ring(1.6, CROSS_COLOUR, 3)
ringLine.Name = "Ring"

-- Under the crosshair: LOW AMMO, RELOAD [R], or a reload bar filling -- where the eye
-- already is, instead of down in the corner where the ammo count lives.
local callout = Instance.new("TextLabel")
callout.Name = "AmmoCallout"
callout.AnchorPoint = Vector2.new(0.5, 0)
callout.Position = UDim2.new(0.5, 0, 0.5, 40)
callout.Size = UDim2.fromOffset(220, 22)
callout.BackgroundTransparency = 1
callout.FontFace = Font.new("rbxasset://fonts/families/Oswald.json", Enum.FontWeight.Bold)
callout.TextSize = 20
callout.TextColor3 = Color3.new(1, 1, 1)
callout.Text = ""
callout.Visible = false
callout.ZIndex = 4
callout.Parent = gui
local calloutEdge = Instance.new("UIStroke")
calloutEdge.Color = CROSS_EDGE
calloutEdge.Thickness = 2
calloutEdge.Parent = callout

local reloadTrack = Instance.new("Frame")
reloadTrack.Name = "ReloadBar"
reloadTrack.AnchorPoint = Vector2.new(0.5, 0)
reloadTrack.Position = UDim2.new(0.5, 0, 0.5, 66)
reloadTrack.Size = UDim2.fromOffset(96, 6)
reloadTrack.BackgroundColor3 = CROSS_EDGE
reloadTrack.BackgroundTransparency = 0.25
reloadTrack.BorderSizePixel = 0
reloadTrack.Visible = false
reloadTrack.ZIndex = 4
reloadTrack.Parent = gui
local reloadCorner = Instance.new("UICorner")
reloadCorner.CornerRadius = UDim.new(1, 0)
reloadCorner.Parent = reloadTrack
local reloadFill = Instance.new("Frame")
reloadFill.Name = "Fill"
reloadFill.BackgroundColor3 = Color3.fromRGB(255, 206, 60)
reloadFill.BorderSizePixel = 0
reloadFill.Size = UDim2.fromScale(0, 1)
reloadFill.ZIndex = 5
reloadFill.Parent = reloadTrack
reloadCorner:Clone().Parent = reloadFill

-- HEADSHOT, popped over the crosshair for a moment -- the call every hit on the head earns.
local headshotLabel = Instance.new("TextLabel")
headshotLabel.Name = "HeadshotCall"
headshotLabel.AnchorPoint = Vector2.new(0.5, 1)
headshotLabel.Position = UDim2.new(0.5, 0, 0.5, -30)
headshotLabel.Size = UDim2.fromOffset(220, 24)
headshotLabel.BackgroundTransparency = 1
headshotLabel.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
headshotLabel.TextSize = 22
headshotLabel.TextColor3 = Color3.fromRGB(255, 206, 80)
headshotLabel.Text = "HEADSHOT"
headshotLabel.TextTransparency = 1
headshotLabel.ZIndex = 6
headshotLabel.Parent = gui
local headshotEdge = Instance.new("UIStroke")
headshotEdge.Color = CROSS_EDGE
headshotEdge.Thickness = 2
headshotEdge.Transparency = 1
headshotEdge.Parent = headshotLabel
local headshotScale = Instance.new("UIScale")
headshotScale.Parent = headshotLabel

-- The weapon's name and class, flashed under the crosshair when you swap to it.
local swapLabel = Instance.new("TextLabel")
swapLabel.Name = "SwapCall"
swapLabel.AnchorPoint = Vector2.new(0.5, 0)
swapLabel.Position = UDim2.new(0.5, 0, 0.5, 92)
swapLabel.Size = UDim2.fromOffset(320, 26)
swapLabel.BackgroundTransparency = 1
swapLabel.FontFace = Font.new("rbxasset://fonts/families/SourceSansPro.json", Enum.FontWeight.Heavy, Enum.FontStyle.Italic)
swapLabel.TextSize = 24
swapLabel.TextColor3 = Color3.new(1, 1, 1)
swapLabel.TextTransparency = 1
swapLabel.RichText = true
swapLabel.ZIndex = 4
swapLabel.Parent = gui
local swapEdge = Instance.new("UIStroke")
swapEdge.Color = CROSS_EDGE
swapEdge.Thickness = 2
swapEdge.Transparency = 1
swapEdge.Parent = swapLabel
local RARITY_HEX = {
	Common = "#b4bccc", Uncommon = "#4fe07a", Rare = "#4aa8ff", Epic = "#c070ff", Legendary = "#ffb42a", Mythic = "#ff4a78",
}

-- ---------------------------------------------------------------- the scope --
--
-- A sniper -- or any build zoomed tighter than SCOPE_FOV -- looks through glass: black all
-- round a round lens, fine reticle lines with mil-dots and a red centre, the faintest blue
-- in the glass. The dark surround is a single circle with an enormous stroke: a UIStroke
-- draws outward from the edge, so a stroke as wide as the screen blacks out everything
-- outside the lens without needing an image. It sits under the HUD, so ammo and health
-- stay readable.
local SCOPE_FOV = 32

local scopeGui = Instance.new("ScreenGui")
scopeGui.Name = "ScopeHUD"
scopeGui.ResetOnSpawn = false
scopeGui.IgnoreGuiInset = true
scopeGui.DisplayOrder = 1
scopeGui.Enabled = false
scopeGui.Parent = player:WaitForChild("PlayerGui")

local lens = Instance.new("Frame")
lens.Name = "Lens"
lens.AnchorPoint = Vector2.new(0.5, 0.5)
lens.Position = UDim2.fromScale(0.5, 0.5)
lens.Size = UDim2.fromScale(0.88, 0.88)
lens.SizeConstraint = Enum.SizeConstraint.RelativeYY
lens.BackgroundColor3 = Color3.fromRGB(120, 180, 255)
lens.BackgroundTransparency = 0.94
lens.Parent = scopeGui
local lensCorner = Instance.new("UICorner")
lensCorner.CornerRadius = UDim.new(1, 0)
lensCorner.Parent = lens
local surround = Instance.new("UIStroke")
surround.Color = Color3.new(0, 0, 0)
surround.Thickness = 1400
surround.Parent = lens
-- A soft dark ring just inside the rim, the way real glass darkens at its edge.
local rim = Instance.new("Frame")
rim.AnchorPoint = Vector2.new(0.5, 0.5)
rim.Position = UDim2.fromScale(0.5, 0.5)
rim.Size = UDim2.fromScale(1, 1)
rim.BackgroundTransparency = 1
rim.Parent = lens
lensCorner:Clone().Parent = rim
local rimStroke = Instance.new("UIStroke")
rimStroke.Color = Color3.new(0, 0, 0)
rimStroke.Thickness = 26
rimStroke.Transparency = 0.45
rimStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
rimStroke.Parent = rim

local function scopeLine(size: UDim2, position: UDim2, colour: Color3?)
	local f = Instance.new("Frame")
	f.AnchorPoint = Vector2.new(0.5, 0.5)
	f.Position = position
	f.Size = size
	f.BackgroundColor3 = colour or Color3.new(0, 0, 0)
	f.BorderSizePixel = 0
	f.ZIndex = 2
	f.Parent = lens
	return f
end
-- Thick posts from the rim, thin wires across the middle, a gap at the centre.
scopeLine(UDim2.new(0.3, 0, 0, 4), UDim2.fromScale(0.15, 0.5))
scopeLine(UDim2.new(0.3, 0, 0, 4), UDim2.fromScale(0.85, 0.5))
scopeLine(UDim2.new(0, 4, 0.3, 0), UDim2.fromScale(0.5, 0.85))
scopeLine(UDim2.new(0.34, 0, 0, 1), UDim2.fromScale(0.5, 0.5))
scopeLine(UDim2.new(0, 1, 0.34, 0), UDim2.fromScale(0.5, 0.5))
for i = 1, 4 do
	for _, sign in ipairs({ -1, 1 }) do
		local d = scopeLine(UDim2.fromOffset(5, 5), UDim2.fromScale(0.5 + sign * i * 0.035, 0.5))
		Instance.new("UICorner", d).CornerRadius = UDim.new(1, 0)
		local v = scopeLine(UDim2.fromOffset(5, 5), UDim2.fromScale(0.5, 0.5 + sign * i * 0.035))
		Instance.new("UICorner", v).CornerRadius = UDim.new(1, 0)
	end
end
local centreDot = scopeLine(UDim2.fromOffset(4, 4), UDim2.fromScale(0.5, 0.5), Color3.fromRGB(255, 40, 40))
Instance.new("UICorner", centreDot).CornerRadius = UDim.new(1, 0)

local scoped = false
-- While looking through the scope your own body would fill the lens (the camera sits over
-- the shoulder), so the character is faded out locally -- nobody else sees any change.
local function setOwnBodyHidden(hidden: boolean)
	local character = player.Character
	if not character then
		return
	end
	for _, d in ipairs(character:GetDescendants()) do
		if d:IsA("BasePart") or d:IsA("Decal") then
			d.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
end

-- ------------------------------------------------------------- crosshair colour --

-- The Settings panel's CROSSHAIR COLOUR, published as an index on the player.
local SettingsConfig = require(ReplicatedStorage:WaitForChild("SettingsConfig"))
local CROSS_COLOURS = {}
for i, entry in ipairs(SettingsConfig.CrosshairColours) do
	CROSS_COLOURS[i] = entry.colour
end
local appliedColour = 0
local function applyCrossColour()
	local index = math.clamp(math.floor(tonumber(player:GetAttribute("CrosshairColour")) or 1), 1, #CROSS_COLOURS)
	if index == appliedColour then
		return
	end
	appliedColour = index
	local colour = CROSS_COLOURS[index]
	reticle.BackgroundColor3 = colour
	for _, arm in ipairs(arms) do
		arm.frame.BackgroundColor3 = colour
	end
	local st = ringLine:FindFirstChildOfClass("UIStroke")
	if st then
		st.Color = colour
	end
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

local function flashHitmarker(headshot: boolean, lethal: boolean?, wallbang: boolean?)
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

	-- A hit on the head gets its own call and its own ding over the usual click, and so does
	-- a round put through a wall.
	if headshot or wallbang then
		local words = {}
		if wallbang then
			table.insert(words, "WALLBANG")
		end
		if headshot then
			table.insert(words, "HEADSHOT")
		end
		if lethal and #words == 1 then
			table.insert(words, "KILL")
		end
		headshotLabel.Text = table.concat(words, " ")
		headshotLabel.TextColor3 = lethal and Color3.fromRGB(255, 96, 80)
			or (wallbang and Color3.fromRGB(110, 226, 255) or Color3.fromRGB(255, 206, 80))
		headshotLabel.TextTransparency = 0
		headshotEdge.Transparency = 0
		headshotScale.Scale = 1.5
		TweenService:Create(headshotScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
			{ Scale = 1 }):Play()
		local fade = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.45)
		TweenService:Create(headshotLabel, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(headshotEdge, fade, { Transparency = 1 }):Play()
		UISound.Play("Ring", lethal and 1.6 or 2, 0.55)
	end

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
		local shooter, tool, origin, endPoints, wallHits = ...
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
		-- Where rounds went through a wall: the entry holes.
		if type(wallHits) == "table" then
			for _, p in ipairs(wallHits) do
				if typeof(p) == "Vector3" then
					CombatFX.Impact(p, origin, weaponName)
				end
			end
		end
	elseif kind == "Hitmarker" then
		local headshot, lethal, wallbang = ...
		flashHitmarker(headshot == true, lethal == true, wallbang == true)
	elseif kind == "Damage" then
		local position, amount, headshot, lethal = ...
		if typeof(position) == "Vector3" and type(amount) == "number" then
			CombatFX.DamageNumber(position, amount, headshot == true, lethal == true)
			-- Our own kill: cash flies out of the body.
			if lethal == true then
				CombatFX.CashBurst(position)
			end
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
		local shooter, tool, needsCharge, duration, tactical = ...
		local wcfg = tool and WeaponConfig.For(tool)
		if shooter == player and tool == equipped then
			reloadStartedAt = os.clock()
			reloadDuration = type(duration) == "number" and duration or nil
			reloadTactical = tactical == true
		end
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
	-- Holding Alt frees the cursor to click the HUD (ShiftLock); a click then is aimed at a
	-- button, not at anybody, so it is never a shot.
	if player:GetAttribute("CursorFree") == true then
		return
	end
	if (tool:GetAttribute("Ammo") or 0) <= 0 then
		-- Once per trigger pull, not once per frame. tryShoot runs every frame while the
		-- button is held, so an unguarded click here would machine-gun the empty sound.
		if not clickedEmpty then
			clickedEmpty = true
			WeaponAudio.Play(tool, "Empty")
			-- The weapon's own dry-fire sample is still unrecorded (WeaponAudio.PENDING), so
			-- the hammer falling is the short click the interface already uses, pitched down.
			UISound.Play("Click", 0.7, 1.6)
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
	reloadStartedAt = nil
	reloadDuration = nil
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
		local hex = RARITY_HEX[cfg.Rarity or "Common"] or "#ffffff"
		swapLabel.Text = string.format('<font color="%s">%s</font>  <font size="16">%s</font>',
			hex, string.upper(tool and tool.Name or ""), string.upper(cfg.Class or ""))
		swapLabel.TextTransparency = 0
		swapEdge.Transparency = 0
		local fade = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, 0.9)
		TweenService:Create(swapLabel, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(swapEdge, fade, { Transparency = 1 }):Play()
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
		if player:GetAttribute("CursorFree") == true then
			return
		end
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

-- -------------------------------------------------------------- scope glint --
--
-- Another player looking at you down a scope gives themselves away: a white-blue glint on
-- their lens, shown only while they are aiming a scoped weapon AND pointing roughly at you.
-- Everything it needs already replicates -- the Aiming attribute CombatFeedService stamps on
-- every character, and the tool in their hand -- so it costs no network traffic at all.
local GLINT_CONE = math.cos(math.rad(28))
local glints: { [Model]: BillboardGui } = {}

local function glintFor(character: Model, tool: Tool): BillboardGui?
	local existing = glints[character]
	if existing and existing.Parent then
		return existing
	end
	local lens = tool:FindFirstChild("ScopeLens") or tool:FindFirstChild("Handle")
	if not lens or not lens:IsA("BasePart") then
		return nil
	end
	local g = Instance.new("BillboardGui")
	g.Name = "ScopeGlint"
	g.Size = UDim2.fromScale(3.2, 3.2)
	g.LightInfluence = 0
	g.AlwaysOnTop = false
	g.MaxDistance = 1200
	g.Adornee = lens
	g.Parent = lens
	local core = Instance.new("Frame")
	core.AnchorPoint = Vector2.new(0.5, 0.5)
	core.Position = UDim2.fromScale(0.5, 0.5)
	core.Size = UDim2.fromScale(0.35, 0.35)
	core.BackgroundColor3 = Color3.fromRGB(230, 245, 255)
	core.Parent = g
	Instance.new("UICorner", core).CornerRadius = UDim.new(1, 0)
	for _, rot in ipairs({ 0, 90 }) do
		local ray = Instance.new("Frame")
		ray.AnchorPoint = Vector2.new(0.5, 0.5)
		ray.Position = UDim2.fromScale(0.5, 0.5)
		ray.Size = UDim2.fromScale(1, 0.06)
		ray.Rotation = rot
		ray.BackgroundColor3 = Color3.fromRGB(190, 230, 255)
		ray.BorderSizePixel = 0
		ray.Parent = g
		local fade = Instance.new("UIGradient")
		fade.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.5, 0), NumberSequenceKeypoint.new(1, 1),
		})
		fade.Parent = ray
	end
	glints[character] = g
	return g
end

task.spawn(function()
	while true do
		task.wait(0.15)
		local cam = workspace.CurrentCamera
		for _, other in ipairs(Players:GetPlayers()) do
			local character = other.Character
			if other ~= player and character then
				local tool = character:FindFirstChildOfClass("Tool")
				local wcfg = tool and WeaponConfig.Get(tool.Name)
				local scopedWeapon = wcfg ~= nil and (wcfg.Scoped == true or (wcfg.AdsFov or 99) <= SCOPE_FOV)
				local show = false
				if scopedWeapon and cam and character:GetAttribute("Aiming") == true then
					local head = character:FindFirstChild("Head")
					if head and head:IsA("BasePart") then
						local toMe = cam.CFrame.Position - head.Position
						show = toMe.Magnitude > 1 and head.CFrame.LookVector:Dot(toMe.Unit) > GLINT_CONE
					end
				end
				if show and tool then
					local g = glintFor(character, tool)
					if g then
						g.Enabled = true
						-- A slow twinkle, so it catches the eye.
						g.Size = UDim2.fromScale(2.8 + math.sin(os.clock() * 8) * 0.6, 2.8 + math.sin(os.clock() * 8) * 0.6)
					end
				elseif glints[character] then
					glints[character].Enabled = false
				end
			end
		end
		for character, g in pairs(glints) do
			if not character.Parent or not g.Parent then
				glints[character] = nil
			end
		end
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
	-- FIELD OF VIEW from the Settings panel, when set, is the resting view; aiming still
	-- narrows to the weapon's own ADS figure.
	local fovSetting = player:GetAttribute("FovSetting")
	local restFov = typeof(fovSetting) == "number" and fovSetting or baseFov
	local wantFov = ((cfg and ads) and cfg.AdsFov or restFov)
		+ (typeof(sprintFov) == "number" and sprintFov or 0)
		+ fovKick
	camera.FieldOfView += (wantFov - camera.FieldOfView) * math.clamp((cfg and cfg.AdsSpeed or 12) * dt, 0, 1)

	applyCrossColour()

	-- Through the scope: the lens overlay replaces the crosshair once the zoom is most of the
	-- way in, and your own body fades out of the way.
	local wantScope = cfg ~= nil and ads and (cfg.Scoped == true or (cfg.AdsFov or 99) <= SCOPE_FOV)
		and camera.FieldOfView <= (cfg.AdsFov or 0) + 12
	if wantScope ~= scoped then
		scoped = wantScope
		scopeGui.Enabled = scoped
		setOwnBodyHidden(scoped)
		-- MainUI clears the middle of the screen (PLAY, the side menu) while this is set.
		player:SetAttribute("Scoped", scoped)
		if scoped then
			UISound.Play("Whoosh", 1.9, 0.25)
		end
	end
	if scoped then
		surround.Thickness = math.max(camera.ViewportSize.X, camera.ViewportSize.Y) * 1.2
	end

	-- Ammo, where the eye is: LOW AMMO, RELOAD [R], or the reload bar filling.
	if cfg and equipped then
		local ammo = tonumber(equipped:GetAttribute("Ammo")) or 0
		local capacity = tonumber(equipped:GetAttribute("MaxAmmo")) or cfg.MagazineSize or 1
		local reloading = equipped:GetAttribute("Reloading") == true
		if reloading then
			if not reloadStartedAt then
				reloadStartedAt = os.clock()
			end
			local t = math.clamp((os.clock() - reloadStartedAt) / math.max(reloadDuration or cfg.ReloadTime or 1, 0.1), 0, 1)
			callout.Text = reloadTactical and "TACTICAL RELOAD" or "RELOADING"
			callout.TextColor3 = Color3.fromRGB(255, 206, 60)
			reloadFill.Size = UDim2.fromScale(t, 1)
		else
			reloadStartedAt = nil
			reloadDuration = nil
			reloadTactical = false
			if ammo <= 0 then
				callout.Text = "RELOAD  [R]"
				-- A slow red pulse, so an empty gun is noticed without shouting.
				local pulse = 0.5 + 0.5 * math.sin(os.clock() * 6)
				callout.TextColor3 = Color3.fromRGB(255, 70 + math.floor(pulse * 60), 70)
			elseif ammo <= math.max(1, math.floor(capacity * 0.25)) then
				callout.Text = "LOW AMMO"
				callout.TextColor3 = Color3.fromRGB(255, 206, 60)
			else
				callout.Text = ""
			end
		end
		callout.Visible = callout.Text ~= "" and not scoped
		reloadTrack.Visible = reloading and not scoped
	else
		callout.Visible = false
		reloadTrack.Visible = false
		reloadStartedAt = nil
	end

	-- Crosshair opens with spread.
	if cfg then
		heat = math.max(0, heat - cfg.SpreadRecovery * dt)
		-- The same cone the server will fire: running and jumping open it, a rested weapon
		-- closes it (GunHandling).
		local speed, airborne = GunHandling.Motion(player.Character)
		local spread = GunHandling.Spread(cfg, heat, ads, speed, airborne, os.clock() - lastShot)
		-- Convert the cone angle to pixels at the current FOV, plus whatever the last shots
		-- bloomed it by.
		bloom = math.max(0, bloom - bloom * math.min(10 * dt, 1))
		local pixelsPerDegree = camera.ViewportSize.Y / camera.FieldOfView
		local gap = 4 + spread * pixelsPerDegree + bloom + ARM_LENGTH / 2
		local armFade = ads and 0.75 or 0
		-- Pellet guns draw a ring the size of the spread instead of arms.
		local pellets = (cfg.PelletsPerShot or 1) > 1 or cfg.Class == "Shotgun"
		for _, arm in ipairs(arms) do
			arm.frame.Position = UDim2.new(0.5, arm.dir.X * gap, 0.5, arm.dir.Y * gap)
			arm.frame.BackgroundTransparency = armFade
			arm.frame.Visible = not pellets and not scoped
		end
		local diameter = math.max(18, (gap - ARM_LENGTH / 2) * 2)
		ringLine.Size = UDim2.fromOffset(diameter, diameter)
		ringEdge.Size = UDim2.fromOffset(diameter, diameter)
		ringLine.Visible = pellets and not scoped
		ringEdge.Visible = pellets and not scoped
		-- The ammo call sits just clear of whichever crosshair is showing.
		local below = pellets and math.max(40, diameter / 2 + 12) or 40
		callout.Position = UDim2.new(0.5, 0, 0.5, below)
		headshotLabel.Position = UDim2.new(0.5, 0, 0.5, -(pellets and math.max(30, diameter / 2 + 8) or 30))
		reloadTrack.Position = UDim2.new(0.5, 0, 0.5, below + 26)
		reticle.BackgroundTransparency = 0
		reticle.Visible = not scoped
	end
end)
