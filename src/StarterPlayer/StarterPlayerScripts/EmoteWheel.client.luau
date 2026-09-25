--!strict
-- The emote wheel. Hold G, point at an emote, let go.
--
-- Forty emotes do not fit on one wheel, so it has pages of eight -- Classic, Dances, Moves,
-- Taunts, Props -- switched with the mouse wheel, the arrow keys, or the tabs across the
-- top. It opens on the page you last used.
--
--   hold G, release over a slot     play it
--   tap G                           the wheel stays open; click a slot, or tap G again
--   1-8 while open                  play that slot
--   scroll / Left / Right           change page
--
-- The wheel only ever sends an emote id. Whether that emote may play is the server's call.

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local EmoteConfig = require(ReplicatedStorage.EmoteConfig)
local UIKit = require(ReplicatedStorage.UIKit)
local UIState = require(ReplicatedStorage:WaitForChild("UIState"))
local Theme = UIKit.Theme

local player = Players.LocalPlayer
local EmotePlay = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("EmotePlay") :: RemoteEvent

local RADIUS = 178
local SLOT = 108
local HUB = 150
local SIZE = RADIUS * 2 + SLOT + 20
local TAP = 0.3

local gui = Instance.new("ScreenGui")
gui.Name = "EmoteWheel"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 30
gui.Enabled = false
gui.Parent = player:WaitForChild("PlayerGui")

local scrim = UIKit.frame({
	Name = "Scrim",
	Size = UDim2.fromScale(1, 1),
	BackgroundColor3 = Color3.new(0, 0, 0),
	BackgroundTransparency = 0.55,
	Parent = gui,
})
local vignette = Instance.new("UIGradient")
vignette.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0.55),
	NumberSequenceKeypoint.new(0.5, 1),
	NumberSequenceKeypoint.new(1, 0.55),
})
vignette.Parent = scrim

local root = Instance.new("Frame")
root.Name = "Wheel"
root.AnchorPoint = Vector2.new(0.5, 0.5)
root.Position = UDim2.fromScale(0.5, 0.53)
root.Size = UDim2.fromOffset(SIZE, SIZE + 90)
root.BackgroundTransparency = 1
root.Parent = gui
UIKit.fitToScreen(root, SIZE, SIZE + 90, 30)

-- The wheel's own centre, below the page tabs.
local wheel = Instance.new("Frame")
wheel.Name = "Ring"
wheel.AnchorPoint = Vector2.new(0.5, 1)
wheel.Position = UDim2.fromScale(0.5, 1)
wheel.Size = UDim2.fromOffset(SIZE, SIZE)
wheel.BackgroundTransparency = 1
wheel.Parent = root

-- A faint ring behind the slots, so eight cards read as one wheel.
local ring = UIKit.frame({
	Name = "Track",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(RADIUS * 2, RADIUS * 2),
	BackgroundTransparency = 1,
	Parent = wheel,
})
UIKit.corner(ring, UDim.new(1, 0))
local ringStroke = UIKit.stroke(ring, Color3.new(1, 1, 1), 10, 0.88)

-- ------------------------------------------------------------------ hub --

local hub = UIKit.frame({
	Name = "Hub",
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(HUB, HUB),
	BackgroundColor3 = Theme.Panel,
	Parent = wheel,
})
-- One stroke per object is all Roblox draws, so the hub's edge itself takes the page colour.
local hubStroke = UIKit.chunky(hub, HUB // 2)
hubStroke.Thickness = 3
hubStroke.Transparency = 0.1

local hubIcon = UIKit.label({
	Name = "Icon",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 18),
	Size = UDim2.new(1, 0, 0, 56),
	Text = "💃",
	TextSize = 46,
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = hub,
})
local hubName = UIKit.label({
	Name = "EmoteName",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 78),
	Size = UDim2.new(1, -16, 0, 26),
	Text = "EMOTES",
	Font = Theme.FontBlack,
	TextSize = 18,
	TextScaled = false,
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = hub,
})
local hubSub = UIKit.label({
	Name = "Sub",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 0, 104),
	Size = UDim2.new(1, -16, 0, 18),
	Text = "",
	Font = Theme.FontBold,
	TextColor3 = Theme.TextDim,
	TextSize = 12,
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = hub,
})

-- ---------------------------------------------------------------- tabs --

local tabs = Instance.new("Frame")
tabs.Name = "Pages"
tabs.AnchorPoint = Vector2.new(0.5, 0)
tabs.Position = UDim2.fromScale(0.5, 0)
tabs.Size = UDim2.fromOffset(SIZE, 44)
tabs.BackgroundTransparency = 1
tabs.Parent = root
local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
tabLayout.VerticalAlignment = Enum.VerticalAlignment.Center
tabLayout.Padding = UDim.new(0, 8)
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabs

local pageIndex = 1
local tabButtons: { TextButton } = {}

local function arrow(text: string, order: number): TextButton
	local b = UIKit.button({
		Name = order < 0 and "Prev" or "Next",
		Size = UDim2.fromOffset(38, 38),
		Text = text,
		TextSize = 18,
		LayoutOrder = order,
		Parent = tabs,
	})
	UIKit.corner(b, UDim.new(1, 0))
	return b
end
local prevButton = arrow("◀", -1)
for i, page in ipairs(EmoteConfig.Pages) do
	local b = UIKit.button({
		Name = page.name,
		Size = UDim2.fromOffset(96, 38),
		Text = page.name:upper(),
		TextSize = 14,
		LayoutOrder = i,
		Parent = tabs,
	})
	UIKit.corner(b, UDim.new(0, 10))
	tabButtons[i] = b
end
local nextButton = arrow("▶", 100)

-- --------------------------------------------------------------- slots --

type Slot = { button: TextButton, icon: TextLabel, name: TextLabel, key: TextLabel, emote: EmoteConfig.Emote? }
local slots: { Slot } = {}

for i = 1, 8 do
	local angle = (i - 1) / 8 * math.pi * 2 - math.pi / 2
	local b = UIKit.button({
		Name = "Slot" .. i,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.5, math.cos(angle) * RADIUS, 0.5, math.sin(angle) * RADIUS),
		Size = UDim2.fromOffset(SLOT, SLOT),
		Text = "",
		Parent = wheel,
	})
	UIKit.corner(b, UDim.new(0, 18))
	local icon = UIKit.label({
		Name = "Icon",
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.new(0.5, 0, 0, 12),
		Size = UDim2.new(1, 0, 0, 48),
		TextSize = 40,
		TextXAlignment = Enum.TextXAlignment.Center,
		Parent = b,
	})
	local name = UIKit.label({
		Name = "EmoteName",
		AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.new(0.5, 0, 1, -10),
		Size = UDim2.new(1, -10, 0, 30),
		Font = Theme.FontBold,
		TextSize = 13,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Bottom,
		Parent = b,
	})
	local key = UIKit.label({
		Name = "Key",
		Position = UDim2.fromOffset(8, 5),
		Size = UDim2.fromOffset(18, 18),
		Text = tostring(i),
		Font = Theme.FontBlack,
		TextSize = 12,
		TextColor3 = Theme.TextFaint,
		Parent = b,
	})
	slots[i] = { button = b, icon = icon, name = name, key = key, emote = nil }
end

local hint = UIKit.label({
	Name = "Hint",
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.new(0.5, 0, 1, 10),
	Size = UDim2.fromOffset(SIZE + 120, 20),
	Text = "RELEASE TO PLAY  ·  SCROLL TO CHANGE PAGE  ·  1–8 QUICK PICK",
	Font = Theme.FontBold,
	TextSize = 12,
	TextColor3 = Theme.TextDim,
	TextXAlignment = Enum.TextXAlignment.Center,
	Parent = root,
})
hint.TextStrokeTransparency = 0.5

-- ---------------------------------------------------------------- state --

local open = false
local sticky = false
local openedAt = 0

local function currentPage()
	return EmoteConfig.Pages[pageIndex]
end

local function showPage(index: number)
	local count = #EmoteConfig.Pages
	pageIndex = (index - 1) % count + 1
	local page = currentPage()
	local list = EmoteConfig.OnPage(page.name)
	for i, slot in ipairs(slots) do
		local emote = list[i]
		slot.emote = emote
		slot.button.Visible = emote ~= nil
		if emote then
			slot.icon.Text = emote.icon
			slot.name.Text = emote.name:upper()
			slot.button:SetAttribute("EmoteId", emote.id)
		end
	end
	for i, b in ipairs(tabButtons) do
		local on = i == pageIndex
		local colour = EmoteConfig.Pages[i].colour
		b.BackgroundColor3 = on and colour or Theme.PanelLight
		b.TextColor3 = on and Color3.fromRGB(12, 12, 16) or Theme.TextDim
		b.TextStrokeTransparency = on and 1 or 0.6
	end
	hubStroke.Color = page.colour
	ringStroke.Color = page.colour
	player:SetAttribute("EmotePage", page.name)
end

--- Which slot the mouse is over, or nil while it is parked in the middle. A wheel that fires
--- whatever is closest even when you have not moved the mouse picks something at random
--- every time you tap the key.
local function hovered(): Slot?
	local mouse = UserInputService:GetMouseLocation()
	local centre = wheel.AbsolutePosition + wheel.AbsoluteSize / 2
	local delta = mouse - centre
	local scale = wheel.AbsoluteSize.X / SIZE
	if delta.Magnitude < (HUB / 2 + 4) * scale or delta.Magnitude > (RADIUS + SLOT) * scale then
		return nil
	end
	local best, bestDist = nil, math.huge
	for _, slot in ipairs(slots) do
		if slot.emote then
			local pos = slot.button.AbsolutePosition + slot.button.AbsoluteSize / 2
			local d = (mouse - pos).Magnitude
			if d < bestDist then
				bestDist = d
				best = slot
			end
		end
	end
	return best
end

local function play(emote: EmoteConfig.Emote?)
	if emote then
		EmotePlay:FireServer(emote.id)
	end
end

local function sinkScroll(_: string, state: Enum.UserInputState, input: InputObject): Enum.ContextActionResult
	if not open then
		return Enum.ContextActionResult.Pass
	end
	if state == Enum.UserInputState.Change then
		showPage(pageIndex + (input.Position.Z > 0 and -1 or 1))
	end
	return Enum.ContextActionResult.Sink
end

local function setOpen(value: boolean)
	if open == value then
		return
	end
	open = value
	gui.Enabled = value
	if value then
		UIState.SetOpen("Emote", true)
	else
		-- Let go of the screen a moment later rather than now. The hotbar reads the same key
		-- press that picked an emote (1-8), and if the menu flag dropped first it would draw a
		-- weapon -- which the server treats as cancelling the emote just asked for.
		task.delay(0.12, function()
			if not open then
				UIState.SetOpen("Emote", false)
			end
		end)
	end
	if value then
		sticky = false
		openedAt = os.clock()
		showPage(pageIndex)
		-- Scrolling pages the wheel instead of zooming the camera behind it.
		ContextActionService:BindActionAtPriority("EmoteWheelScroll", sinkScroll, false, 3000,
			Enum.UserInputType.MouseWheel)
	else
		ContextActionService:UnbindAction("EmoteWheelScroll")
	end
end

local function close(playHovered: boolean)
	local hit = playHovered and hovered() or nil
	setOpen(false)
	if hit then
		play(hit.emote)
	end
end

for _, slot in ipairs(slots) do
	slot.button.Activated:Connect(function()
		if open and slot.emote then
			local emote = slot.emote
			setOpen(false)
			play(emote)
		end
	end)
end
for i, b in ipairs(tabButtons) do
	b.Activated:Connect(function()
		showPage(i)
	end)
end
prevButton.Activated:Connect(function()
	showPage(pageIndex - 1)
end)
nextButton.Activated:Connect(function()
	showPage(pageIndex + 1)
end)

RunService.RenderStepped:Connect(function()
	if not open then
		return
	end
	local hit = hovered()
	local page = currentPage()
	for _, slot in ipairs(slots) do
		local on = slot == hit
		slot.button.BackgroundColor3 = on and page.colour or Theme.Panel
		slot.name.TextColor3 = on and Color3.fromRGB(12, 12, 16) or Theme.Text
		slot.key.TextColor3 = on and Color3.fromRGB(12, 12, 16) or Theme.TextFaint
		local scale = slot.button:FindFirstChildOfClass("UIScale")
		if scale then
			scale.Scale += ((on and 1.08 or 1) - scale.Scale) * 0.35
		end
	end
	if hit and hit.emote then
		hubIcon.Text = hit.emote.icon
		hubName.Text = hit.emote.name:upper()
		hubSub.Text = hit.emote.prop and "WITH PROP" or page.name:upper()
	else
		hubIcon.Text = "💃"
		hubName.Text = page.name:upper()
		hubSub.Text = ("PAGE %d / %d"):format(pageIndex, #EmoteConfig.Pages)
	end
end)

-- By name: the digit row and the keypad both count.
local DIGITS: { [string]: number } = {
	One = 1, Two = 2, Three = 3, Four = 4, Five = 5, Six = 6, Seven = 7, Eight = 8,
	KeypadOne = 1, KeypadTwo = 2, KeypadThree = 3, KeypadFour = 4,
	KeypadFive = 5, KeypadSix = 6, KeypadSeven = 7, KeypadEight = 8,
}

UserInputService.InputBegan:Connect(function(input, processed)
	if UserInputService:GetFocusedTextBox() then
		return
	end
	if input.KeyCode == EmoteConfig.WHEEL_KEY then
		if processed then
			return
		end
		if not open then
			setOpen(true)
		elseif sticky then
			close(true)
		end
		return
	end
	if not open then
		return
	end
	if input.KeyCode == Enum.KeyCode.Escape then
		setOpen(false)
	elseif input.KeyCode == Enum.KeyCode.Left then
		showPage(pageIndex - 1)
	elseif input.KeyCode == Enum.KeyCode.Right then
		showPage(pageIndex + 1)
	else
		local n = DIGITS[input.KeyCode.Name]
		local slot = n and slots[n]
		if slot and slot.emote then
			local emote = slot.emote
			setOpen(false)
			play(emote)
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.KeyCode ~= EmoteConfig.WHEEL_KEY or not open or sticky then
		return
	end
	-- A quick tap with nothing picked leaves the wheel up, so it can be clicked.
	if not hovered() and os.clock() - openedAt < TAP then
		sticky = true
		hint.Text = "CLICK AN EMOTE  ·  G TO CLOSE  ·  SCROLL TO CHANGE PAGE"
		return
	end
	close(true)
end)

gui:GetPropertyChangedSignal("Enabled"):Connect(function()
	if gui.Enabled then
		hint.Text = "RELEASE TO PLAY  ·  SCROLL TO CHANGE PAGE  ·  1–8 QUICK PICK"
	end
end)

showPage(1)
