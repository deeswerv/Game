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

local screen = Instance.new("ScreenGui")
screen.Name = "Killcam"
screen.ResetOnSpawn = false
screen.IgnoreGuiInset = true
screen.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
screen.DisplayOrder = 30          -- above the HUD and above the menus
screen.Enabled = false
screen.Parent = playerGui
Components.BindScale(screen)

-- A dim wash rather than a solid block: you should still be able to see the fight you just
-- lost, because that is the whole point of a killcam.
local scrim = Instance.new("Frame")
scrim.Name = "Scrim"
scrim.BackgroundColor3 = Theme.Colour.Scrim
scrim.BackgroundTransparency = 0.45
scrim.BorderSizePixel = 0
scrim.Size = UDim2.fromScale(1, 1)
scrim.Parent = screen

local banner = Instance.new("Frame")
banner.Name = "Banner"
banner.BackgroundTransparency = 1
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Position = UDim2.new(0.5, 0, 0, 90)
banner.Size = UDim2.fromOffset(560, 120)
banner.Parent = screen

local headline = Components.Label(banner, {
	text = "YOU DIED",
	font = Theme.Font.Display,
	size = Theme.Text.Title,
	colour = Theme.Colour.Danger,
	align = Enum.TextXAlignment.Center,
})
headline.Size = UDim2.new(1, 0, 0, 28)

local killerLabel = Components.Label(banner, {
	text = "",
	font = Theme.Font.Display,
	size = Theme.Text.Huge,
	align = Enum.TextXAlignment.Center,
})
killerLabel.Size = UDim2.new(1, 0, 0, 40)
killerLabel.Position = UDim2.fromOffset(0, 32)

local weaponLabel = Components.Label(banner, {
	text = "",
	caps = true,
	size = Theme.Text.Small,
	colour = Theme.Colour.TextDim,
	align = Enum.TextXAlignment.Center,
})
weaponLabel.Size = UDim2.new(1, 0, 0, 16)
weaponLabel.Position = UDim2.fromOffset(0, 76)

-- Countdown, bottom centre, clear of the banner.
local footer = Instance.new("Frame")
footer.Name = "Footer"
footer.BackgroundTransparency = 1
footer.AnchorPoint = Vector2.new(0.5, 1)
footer.Position = UDim2.new(0.5, 0, 1, -Theme.Inset.Bottom)
footer.Size = UDim2.fromOffset(320, 46)
footer.Parent = screen

local countdown = Components.Label(footer, {
	text = "",
	font = Theme.Font.Bold,
	size = Theme.Text.Body,
	colour = Theme.Colour.TextDim,
	align = Enum.TextXAlignment.Center,
})
countdown.Size = UDim2.new(1, 0, 0, 18)

local progressHolder = Instance.new("Frame")
progressHolder.BackgroundTransparency = 1
progressHolder.Size = UDim2.new(1, 0, 0, 4)
progressHolder.Position = UDim2.fromOffset(0, 24)
progressHolder.Parent = footer
local progress = Components.Bar(progressHolder, { height = 4, colour = Theme.Colour.Danger })

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

	if killerName then
		headline.Text = "KILLED BY"
		killerLabel.Text = killerName
		killerLabel.Visible = true
		weaponLabel.Text = weapon or ""
	else
		-- Falling, drowning, or your own grenade. Do not invent an attacker.
		headline.Text = "YOU DIED"
		killerLabel.Visible = false
		weaponLabel.Text = ""
	end

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
			countdown.Text = string.format("RESPAWNING IN %.0f", math.ceil(remaining))
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
