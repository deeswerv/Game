--!strict
-- Hold G for the emote wheel; release over a segment to play it.
--
-- The wheel only ever sends an emote ID. Everything about whether that emote may play --
-- and the animation itself -- is the server's.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local EmoteConfig = require(ReplicatedStorage.EmoteConfig)
local UIKit = require(ReplicatedStorage.UIKit)
local UIState = require(ReplicatedStorage:WaitForChild("UIState"))
local Theme = UIKit.Theme

local player = Players.LocalPlayer
local EmotePlay = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EmotePlay") :: RemoteEvent

local RADIUS = 130
local BUTTON = 88

local gui = Instance.new("ScreenGui")
gui.Name = "EmoteWheel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 30
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local root = Instance.new("Frame")
root.Name = "Wheel"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.5)
root.Size = UDim2.fromOffset(RADIUS * 2 + BUTTON, RADIUS * 2 + BUTTON)
root.BackgroundTransparency = 1
root.Parent = gui

local hint = UIKit.label({
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(150, 40),
	Text = "EMOTE",
	Font = Theme.FontBold,
	TextColor3 = Theme.TextDim,
	TextSize = 14,
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = root,
})

-- One segment per emote, laid out on a circle starting at the top.
local segments = {}
for i, emote in ipairs(EmoteConfig.Emotes) do
	local angle = (i - 1) / #EmoteConfig.Emotes * math.pi * 2 - math.pi / 2
	local btn = UIKit.button({
		Name = emote.id,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, math.cos(angle) * RADIUS, 0.5, math.sin(angle) * RADIUS),
		Size = UDim2.fromOffset(BUTTON, BUTTON),
		Text = emote.name,
		TextSize = 13,
		Parent = root,
	})
	UIKit.corner(btn, UDim.new(1, 0))
	btn.TextColor3 = Theme.Text
	segments[i] = { button = btn, emote = emote }
end

local open = false

local function setOpen(value: boolean)
	open = value
	gui.Enabled = value
	UIState.SetOpen("Emote", value)
end

--- Which segment the mouse is nearest, or nil if it is parked in the middle. A wheel that
--- fires whatever is closest even when you have not moved the mouse picks something at
--- random every time you tap the key.
local function hovered()
	local mouse = UserInputService:GetMouseLocation()
	local centre = root.AbsolutePosition + root.AbsoluteSize / 2
	local delta = mouse - centre
	if delta.Magnitude < 42 then
		return nil
	end
	local best, bestDist
	for _, seg in ipairs(segments) do
		local pos = seg.button.AbsolutePosition + seg.button.AbsoluteSize / 2
		local d = (mouse - pos).Magnitude
		if not bestDist or d < bestDist then
			bestDist = d
			best = seg
		end
	end
	return best
end

RunService.RenderStepped:Connect(function()
	if not open then
		return
	end
	local hit = hovered()
	for _, seg in ipairs(segments) do
		local on = seg == hit
		seg.button.BackgroundColor3 = on and Theme.Accent or Theme.Panel
		seg.button.TextColor3 = on and Theme.Background or Theme.Text
	end
	hint.Text = hit and hit.emote.name:upper() or "EMOTE"
end)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or input.KeyCode ~= EmoteConfig.WHEEL_KEY then
		return
	end
	if UserInputService:GetFocusedTextBox() then
		return
	end
	setOpen(true)
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode ~= EmoteConfig.WHEEL_KEY or not open then
		return
	end
	local hit = hovered()
	setOpen(false)
	if hit then
		EmotePlay:FireServer(hit.emote.id)
	end
end)

setOpen(false)
