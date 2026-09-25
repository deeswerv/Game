--!strict
-- What you see after you die: who did it, and their view until you respawn.
--
-- Camera handover is done by moving CameraSubject and nothing else. The PlayerModule keeps
-- owning the camera, so spectating inherits the game's own collision handling and zoom
-- rather than fighting them -- and there is no second script writing camera.CFrame, which is
-- the mistake this project has already paid for twice.
--
-- Every path restores the camera. Respawn restores it, a killer who dies or leaves mid-watch
-- restores it, and the countdown finishing restores it. A killcam that strands the camera on
-- someone else's body is worse than no killcam at all.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("UI"):WaitForChild("Modules")
local Theme = require(Modules:WaitForChild("Theme"))
local Components = require(Modules:WaitForChild("Components"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- ------------------------------------------------------------------ screen --
--
-- The reference's death card: YOU DIED slammed in red, and under it a chunky card with the
-- killer's face, their level diamond and name, what they used, and how much health they
-- had left -- the one number that tells you how close it was. Red at the screen's edges and
-- the colour drained from the world, so dying reads at a glance even mid-chaos.

local TweenService = game:GetService("TweenService")

local WHITE = Color3.new(1, 1, 1)
local BLOOD = Color3.fromRGB(70, 0, 8)
local CARD_WIDTH = 480

local screen = Instance.new("ScreenGui")
screen.Name = "Killcam"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 30          -- above the HUD and above the menus
screen.Enabled = false
screen.Parent = playerGui
Components.BindScale(screen)

-- A light wash rather than a solid block: you should still be able to see the fight you just
-- lost, because that is the whole point of a killcam. The red lives at the edges.
local scrim = Instance.new("Frame")
scrim.Name = "Scrim"
scrim.BackgroundColor3 = Theme.Colour.Scrim
scrim.BackgroundTransparency = 0.7
scrim.BorderSizePixel = 0
scrim.Size = UDim2.fromScale(1, 1)
scrim.Parent = screen

-- Four edge strips fading inwards make the vignette; UIGradient is linear, so one frame
-- per edge is the cheap way to get a frame of red around the screen.
for _, edge in ipairs({
	{ size = UDim2.new(1, 0, 0.3, 0), position = UDim2.fromScale(0, 0), rotation = 90 },
	{ size = UDim2.new(1, 0, 0.3, 0), position = UDim2.fromScale(0, 0.7), rotation = -90 },
	{ size = UDim2.new(0.22, 0, 1, 0), position = UDim2.fromScale(0, 0), rotation = 0 },
	{ size = UDim2.new(0.22, 0, 1, 0), position = UDim2.fromScale(0.78, 0), rotation = 180 },
}) do
	local strip = Instance.new("Frame")
	strip.Name = "Vignette"
	strip.BackgroundColor3 = BLOOD
	strip.BorderSizePixel = 0
	strip.Size = edge.size
	strip.Position = edge.position
	strip.Parent = screen
	local fade = Instance.new("UIGradient")
	fade.Rotation = edge.rotation
	fade.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.25),
		NumberSequenceKeypoint.new(1, 1),
	})
	fade.Parent = strip
end

local headline = Components.Label(screen, {
	text = "YOU DIED",
	face = Theme.Face.HeavyItalic,
	size = 64,
	colour = WHITE,                -- the gradient below supplies the red
	align = Enum.TextXAlignment.Center,
	outline = 4,
})
headline.AnchorPoint = Vector2.new(0.5, 0)
headline.Position = UDim2.new(0.5, 0, 0, 84)
headline.Size = UDim2.fromOffset(640, 70)
local headlineScale = Instance.new("UIScale")
headlineScale.Parent = headline
local sheen = Instance.new("UIGradient")
sheen.Color = ColorSequence.new(Color3.fromRGB(255, 120, 110), Color3.fromRGB(200, 10, 20))
sheen.Rotation = 90
sheen.Parent = headline

-- The card. A CanvasGroup so the whole thing can fade in as one.
local card = Instance.new("CanvasGroup")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0)
card.Position = UDim2.new(0.5, 0, 0, 176)
card.Size = UDim2.fromOffset(CARD_WIDTH, 150)
card.BackgroundTransparency = 1
card.Parent = screen

local body = Instance.new("Frame")
body.Name = "Body"
body.BackgroundColor3 = Theme.Colour.Panel
body.BackgroundTransparency = 0.06
body.Position = UDim2.fromOffset(0, 16)
body.Size = UDim2.new(1, 0, 1, -16)
body.Parent = card
Components.Corner(body, Theme.Radius.Card)
Components.Stroke(body, Theme.Colour.Outline, 3)
Components.Gradient(body, WHITE, Color3.fromRGB(190, 190, 200))

local stripe = Instance.new("Frame")
stripe.Name = "Stripe"
stripe.BackgroundColor3 = Theme.Colour.Kill
stripe.BorderSizePixel = 0
stripe.Size = UDim2.new(0, 8, 1, 0)
stripe.Parent = body
Components.Corner(stripe, Theme.Radius.Card)

-- "KILLED BY" as a red tab stuck on the card's top edge.
local tab = Instance.new("Frame")
tab.Name = "Tab"
tab.BackgroundColor3 = Theme.Colour.Kill
tab.Position = UDim2.fromOffset(18, 2)
tab.Size = UDim2.fromOffset(120, 28)
tab.ZIndex = 3
tab.Parent = card
Components.Corner(tab, Theme.Radius.Chip)
Components.Stroke(tab, Theme.Colour.Outline, 2.5)
local tabText = Components.Label(tab, {
	text = "KILLED BY",
	face = Theme.Face.Condensed,
	size = 18,
	align = Enum.TextXAlignment.Center,
	outline = 2,
})
tabText.Size = UDim2.fromScale(1, 1)
tabText.ZIndex = 4

local portrait = Instance.new("Frame")
portrait.Name = "Portrait"
portrait.BackgroundColor3 = Theme.Colour.PanelRaised
portrait.Position = UDim2.fromOffset(22, 16)
portrait.Size = UDim2.fromOffset(102, 102)
portrait.Parent = body
Components.Corner(portrait, Theme.Radius.Small)
Components.Stroke(portrait, Theme.Colour.Kill, 3)
Components.Gradient(portrait, Color3.fromRGB(255, 150, 150), Color3.fromRGB(120, 40, 50))

local face = Instance.new("ImageLabel")
face.Name = "Face"
face.BackgroundTransparency = 1
face.Size = UDim2.fromScale(1, 1)
face.ScaleType = Enum.ScaleType.Fit
face.Parent = portrait
Components.Corner(face, Theme.Radius.Small)

local skull = Components.Icon(portrait, "💀", 56)
skull.AnchorPoint = Vector2.new(0.5, 0.5)
skull.Position = UDim2.fromScale(0.5, 0.5)

local info = Instance.new("Frame")
info.Name = "Info"
info.BackgroundTransparency = 1
info.Position = UDim2.fromOffset(140, 14)
info.Size = UDim2.new(1, -156, 1, -28)
info.Parent = body

local badge, levelText = Components.LevelBadge(info, 40)
badge.Position = UDim2.fromOffset(-4, -3)

local killerLabel = Components.Label(info, {
	text = "",
	face = Theme.Face.Heavy,
	size = 30,
	outline = 2.5,
})
killerLabel.Position = UDim2.fromOffset(40, 0)
killerLabel.Size = UDim2.new(1, -40, 0, 34)
killerLabel.TextTruncate = Enum.TextTruncate.AtEnd

local weaponLabel = Components.Label(info, {
	text = "",
	font = Theme.Font.Bold,
	size = 18,
	colour = Theme.Colour.TextDim,
	outline = 1.5,
})
weaponLabel.Position = UDim2.fromOffset(0, 38)
weaponLabel.Size = UDim2.new(1, 0, 0, 22)

local hpRow = Instance.new("Frame")
hpRow.Name = "Health"
hpRow.BackgroundTransparency = 1
hpRow.Position = UDim2.fromOffset(0, 70)
hpRow.Size = UDim2.new(1, 0, 0, 22)
hpRow.Parent = info

local hpCaption = Components.Label(hpRow, {
	text = "HP",
	face = Theme.Face.Condensed,
	size = 18,
	colour = Theme.Colour.TextDim,
	outline = 1.5,
})
hpCaption.Size = UDim2.new(0, 30, 1, 0)

local hpTrack = Instance.new("Frame")
hpTrack.BackgroundTransparency = 1
hpTrack.AnchorPoint = Vector2.new(0, 0.5)
hpTrack.Position = UDim2.new(0, 32, 0.5, 0)
hpTrack.Size = UDim2.new(1, -110, 0, 14)
hpTrack.Parent = hpRow
local hpBar = Components.Bar(hpTrack, { height = 14, colour = Theme.Colour.Health })

local hpValue = Components.Label(hpRow, {
	text = "",
	font = Theme.Font.Display,
	size = 20,
	align = Enum.TextXAlignment.Right,
	outline = 2,
})
hpValue.AnchorPoint = Vector2.new(1, 0)
hpValue.Position = UDim2.fromScale(1, 0)
hpValue.Size = UDim2.new(0, 72, 1, 0)

-- Countdown, bottom centre, clear of the card.
local footer = Instance.new("Frame")
footer.Name = "Footer"
footer.BackgroundTransparency = 1
footer.AnchorPoint = Vector2.new(0.5, 1)
footer.Position = UDim2.new(0.5, 0, 1, -Theme.Inset.Bottom)
footer.Size = UDim2.fromOffset(340, 52)
footer.Parent = screen

local countdown = Components.Label(footer, {
	text = "",
	face = Theme.Face.Condensed,
	size = 24,
	align = Enum.TextXAlignment.Center,
	outline = 2,
})
countdown.Size = UDim2.new(1, 0, 0, 28)

local progressHolder = Instance.new("Frame")
progressHolder.BackgroundTransparency = 1
progressHolder.Size = UDim2.new(1, 0, 0, 8)
progressHolder.Position = UDim2.fromOffset(0, 34)
progressHolder.Parent = footer
local progress = Components.Bar(progressHolder, { height = 8, colour = Theme.Colour.Danger })

-- The world loses its colour while you are dead. Lives on the camera, made once.
local grade = Instance.new("ColorCorrectionEffect")
grade.Name = "DeathGrade"
grade.Enabled = false
local GRADE_ON = { Saturation = -0.75, Contrast = 0.12, Brightness = -0.04, TintColor = Color3.fromRGB(255, 212, 212) }
local GRADE_OFF = { Saturation = 0, Contrast = 0, Brightness = 0, TintColor = WHITE }
local gradeTween: Tween? = nil

local function healthColour(fraction: number): Color3
	if fraction > 0.5 then
		return Theme.Colour.Health
	elseif fraction > 0.25 then
		return Theme.Colour.Warning
	end
	return Theme.Colour.Danger
end

local function present(killed: boolean)
	-- Headline slams in, the card rises and fades in under it.
	headlineScale.Scale = 1.7
	TweenService:Create(headlineScale, TweenInfo.new(0.32, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }):Play()
	card.Visible = killed
	if killed then
		card.GroupTransparency = 1
		card.Position = UDim2.new(0.5, 0, 0, 206)
		local rise = TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, false, 0.12)
		TweenService:Create(card, rise, { GroupTransparency = 0, Position = UDim2.new(0.5, 0, 0, 176) }):Play()
	end

	local camera = workspace.CurrentCamera
	if camera then
		grade.Parent = camera
		grade.Enabled = true
		gradeTween = TweenService:Create(grade, TweenInfo.new(0.5, Enum.EasingStyle.Quad), GRADE_ON)
		;(gradeTween :: Tween):Play()
	end
end

local function restoreGrade()
	if gradeTween then
		gradeTween:Cancel()
		gradeTween = nil
	end
	for key, value in pairs(GRADE_OFF) do
		(grade :: any)[key] = value
	end
	grade.Enabled = false
end

-- ------------------------------------------------------------------ state --

local watching: Humanoid? = nil
local watchConnections: { RBXScriptConnection } = {}
local ticker: thread? = nil

local function ownHumanoid(): Humanoid?
	local character = player.Character
	return character and character:FindFirstChildOfClass("Humanoid")
end

local function clearWatch()
	for _, c in ipairs(watchConnections) do
		c:Disconnect()
	end
	table.clear(watchConnections)
	watching = nil
end

--- Put the camera back on the player, whatever state it was in.
local function restoreCamera()
	clearWatch()
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end
	local humanoid = ownHumanoid()
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

local function hide()
	if ticker then
		task.cancel(ticker)
		ticker = nil
	end
	screen.Enabled = false
	restoreGrade()
	restoreCamera()
end

--- Watch the killer, but only while there is something worth watching.
local function watch(subject: Humanoid)
	local camera = workspace.CurrentCamera
	if not camera then
		return
	end

	watching = subject
	camera.CameraSubject = subject

	-- If the killer dies, leaves, or their character is cleaned up while we are watching, go
	-- back to our own body rather than sitting on a destroyed subject.
	table.insert(watchConnections, subject.Died:Connect(restoreCamera))
	table.insert(watchConnections, subject.AncestryChanged:Connect(function(_, parent)
		if not parent then
			restoreCamera()
		end
	end))
end

-- ------------------------------------------------------------------ report --

local DeathReport = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("DeathReport")

;(DeathReport :: RemoteEvent).OnClientEvent:Connect(function(info)
	if type(info) ~= "table" then
		return
	end

	local killerName = type(info.killerName) == "string" and info.killerName or nil
	local weapon = type(info.weapon) == "string" and info.weapon or nil
	local respawnIn = type(info.respawnIn) == "number" and info.respawnIn or 3
	local userId = type(info.killerUserId) == "number" and info.killerUserId or nil
	local level = type(info.killerLevel) == "number" and info.killerLevel or nil
	local health = type(info.killerHealth) == "number" and info.killerHealth or nil
	local maxHealth = type(info.killerMaxHealth) == "number" and info.killerMaxHealth or nil

	-- Falling, drowning, or your own grenade: YOU DIED and no card. Do not invent an attacker.
	headline.Text = "YOU DIED"
	if killerName then
		killerLabel.Text = killerName
		tabText.Text = info.isNpc == true and "TAKEN OUT BY" or "KILLED BY"
		tab.Size = UDim2.fromOffset(info.isNpc == true and 150 or 120, 28)
		weaponLabel.Text = weapon and ("🔫  " .. string.upper(weapon)) or ""
		weaponLabel.Visible = weapon ~= nil

		face.Image = userId and string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", userId) or ""
		face.Visible = userId ~= nil
		skull.Visible = userId == nil

		badge.Visible = level ~= nil
		levelText.Text = level and tostring(level) or ""
		killerLabel.Position = UDim2.fromOffset(level and 40 or 0, 0)
		killerLabel.Size = UDim2.new(1, level and -40 or 0, 0, 34)

		if health and maxHealth and maxHealth > 0 then
			hpRow.Visible = true
			local fraction = math.clamp(health / maxHealth, 0, 1)
			hpBar:SetColour(healthColour(fraction))
			hpBar:SetFraction(1, false)
			hpBar:SetFraction(fraction)
			-- Both went down together: say so rather than showing a sad empty bar.
			hpValue.Text = health <= 0 and "TRADED" or string.format("%d", health)
			hpValue.TextColor3 = health <= 0 and Theme.Colour.Warning or WHITE
		else
			hpRow.Visible = false
		end
	end
	present(killerName ~= nil)

	screen.Enabled = true
	progress:SetFraction(1, false)

	if typeof(info.subject) == "Instance" and info.subject:IsA("Humanoid") then
		watch(info.subject)
	end

	if ticker then
		task.cancel(ticker)
	end
	ticker = task.spawn(function()
		local remaining = respawnIn
		while remaining > 0 do
			countdown.Text = string.format("RESPAWNING IN %d", math.ceil(remaining))
			progress:SetFraction(math.clamp(remaining / respawnIn, 0, 1))
			task.wait(0.1)
			remaining -= 0.1
		end
		countdown.Text = "RESPAWNING"
		progress:SetFraction(0)
	end)
end)

-- Respawning is the authoritative end of the killcam: the moment a new character exists the
-- panel goes and the camera comes home, regardless of what the countdown thought.
player.CharacterAdded:Connect(function(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid and humanoid:IsA("Humanoid") then
		local camera = workspace.CurrentCamera
		if camera then
			camera.CameraSubject = humanoid
		end
	end
	hide()
end)
