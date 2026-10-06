--!strict
-- Interaction prompts, drawn by the game instead of by Roblox.
--
-- The stock ProximityPrompt is the single most recognisable "this is a default Roblox
-- experience" element on screen, and it appears every time the player walks up to a crate,
-- a vendor or a quest giver -- so it is worth replacing once, here, rather than living
-- with it everywhere.
--
--   [ E ]  Rob Register          a key cap you could press, the action in big type, what it
--          ZEE GUNS · HOLD       is on underneath (and HOLD when it must be held)
--
-- It grows and rises into place, the thing it belongs to is picked out with an outline while
-- it is up, holding fills the key and a bar along the bottom, and a completed press flashes
-- and pops. Anything that is a robbery wears the danger colour instead of the accent. The text
-- follows the prompt: "Rob Register" turns into "Emptied" in front of you.
--
-- One script covers every prompt in the game, present and future: nothing has to opt in,
-- and a prompt added later is styled automatically.

local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local Theme = UIKit.Theme

local IN = TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local FADE = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local OUT = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)

local CAP = 38                -- the key cap, px square
local HEIGHT = 52             -- the pill
local RISE = 10               -- px it rises as it appears

-- Live prompt -> what is drawing it, so a prompt hidden mid-hold cleans up.
type Shown = {
	gui: BillboardGui,
	holder: Frame,
	scale: UIScale,
	stroke: UIStroke,
	capStroke: UIStroke,
	fill: Frame,
	bar: Frame,
	action: TextLabel,
	object: TextLabel,
	tone: Color3,
	watch: { RBXScriptConnection },
	hold: Tween?,
}
local active: { [ProximityPrompt]: Shown } = {}

-- What the prompt belongs to, picked out while it is up: one outline, re-pointed at the
-- newest prompt (OutlineService keeps the rest of the budget for people).
local focus = Instance.new("Highlight")
focus.Name = "PromptFocus"
focus.FillColor = Color3.new(1, 1, 1)
focus.FillTransparency = 1
focus.OutlineTransparency = 1
focus.DepthMode = Enum.HighlightDepthMode.Occluded
focus.Enabled = false
focus.Parent = workspace.CurrentCamera
local focused: ProximityPrompt? = nil

local function keyName(prompt: ProximityPrompt): string
	-- Gamepad and touch get their own hints; keyboard shows the actual bound key.
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "TAP"
	end
	local code = prompt.KeyboardKeyCode
	if code == Enum.KeyCode.Unknown then
		return "E"
	end
	local name = code.Name
	-- "ButtonX" and friends are unreadable on a key cap; the short form is what players
	-- actually look for.
	return #name <= 3 and string.upper(name) or string.upper(name:sub(1, 3))
end

local function isRisky(prompt: ProximityPrompt): boolean
	return prompt.Name == "StickupPrompt" or prompt.ActionText:match("^Rob") ~= nil
end

local function objectLine(prompt: ProximityPrompt): string
	local text = prompt.ObjectText
	if prompt.HoldDuration > 0 then
		text = if text ~= "" then text .. "  ·  HOLD" else "HOLD"
	end
	return text
end

--- The thing to outline: a small model the part belongs to (a till, a cash machine, a quest
--- giver), else the part itself if it is small enough to be a thing rather than a place.
local function outlineTarget(prompt: ProximityPrompt): Instance?
	local part = prompt.Parent
	if not part or not part:IsA("BasePart") then
		return nil
	end
	local model = part.Parent
	if model and model:IsA("Model") and model ~= workspace then
		local ok, size = pcall(function()
			return model:GetExtentsSize()
		end)
		if ok and size.Magnitude < 16 then
			return model
		end
	end
	if part.Size.Magnitude < 10 and part.Transparency < 1 then
		return part
	end
	return nil
end

local function setFocus(prompt: ProximityPrompt?)
	focused = prompt
	local target = if prompt then outlineTarget(prompt) else nil
	if not prompt or not target then
		focus.Enabled = false
		focus.Adornee = nil
		return
	end
	local tone = if isRisky(prompt) then Theme.Danger else Theme.AccentGlow
	focus.Adornee = target
	focus.OutlineColor = tone
	focus.FillColor = tone
	focus.FillTransparency = 1
	focus.OutlineTransparency = 1
	focus.Enabled = true
	TweenService:Create(focus, FADE, { FillTransparency = 0.88, OutlineTransparency = 0.15 }):Play()
end

local function refreshText(shown: Shown, prompt: ProximityPrompt)
	shown.action.Text = if prompt.ActionText ~= "" then prompt.ActionText else "Interact"
	shown.object.Text = objectLine(prompt)
	local two = shown.object.Text ~= ""
	shown.object.Visible = two
	-- One line of text sits in the middle; two share the height.
	shown.action.Position = UDim2.new(0, CAP + 22, 0, if two then 8 else 0)
	shown.action.Size = UDim2.new(1, -(CAP + 34), 0, if two then 22 else HEIGHT)
end

local function build(prompt: ProximityPrompt): Shown?
	local anchor = prompt.Parent
	if not anchor or not anchor:IsA("BasePart") then
		return nil
	end
	local tone = if isRisky(prompt) then Theme.Danger else Theme.Accent

	local bb = Instance.new("BillboardGui")
	bb.Name = "PromptUI"
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(280, 72)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 1.8, 0)
	-- Parented to the part rather than to PlayerGui with an Adornee. Both render; this way
	-- the prompt follows the part for free and is destroyed with it, so an opened crate
	-- cannot strand its UI.
	--
	-- Created on the client, so it stays local and never replicates to anyone else.
	bb.Parent = anchor

	-- Everything lives inside one holder so the whole prompt can be scaled and moved as a unit.
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.new(0.5, 0, 0.5, RISE)
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = bb

	local scale = Instance.new("UIScale")
	scale.Scale = 0.78
	scale.Parent = holder

	-- The pill, wide enough for its words.
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.Size = UDim2.fromOffset(250, HEIGHT)
	body.BackgroundColor3 = Theme.Background
	body.BackgroundTransparency = 0.08
	body.BorderSizePixel = 0
	body.ClipsDescendants = true
	body.Parent = holder
	UIKit.corner(body, UDim.new(0, 12))
	local stroke = UIKit.stroke(body, Theme.StrokeLight, 1.5, 0.35) :: UIStroke
	UIKit.sheen(body, 0.08)

	-- A strip of the tone down the left edge, behind the key.
	local edge = Instance.new("Frame")
	edge.Name = "Edge"
	edge.Size = UDim2.new(0, 4, 1, 0)
	edge.BackgroundColor3 = tone
	edge.BorderSizePixel = 0
	edge.Parent = body

	-- The key cap: a face sitting on its own darker base, so it reads as a key you press.
	local base = Instance.new("Frame")
	base.Name = "CapBase"
	base.AnchorPoint = Vector2.new(0, 0.5)
	base.Position = UDim2.new(0, 12, 0.5, 2)
	base.Size = UDim2.fromOffset(CAP, CAP)
	base.BackgroundColor3 = Theme.Background:Lerp(Color3.new(0, 0, 0), 0.4)
	base.BorderSizePixel = 0
	base.Parent = body
	UIKit.corner(base, UDim.new(0, 9))

	local cap = Instance.new("Frame")
	cap.Name = "Cap"
	cap.AnchorPoint = Vector2.new(0, 0.5)
	cap.Position = UDim2.new(0, 12, 0.5, -1)
	cap.Size = UDim2.fromOffset(CAP, CAP - 2)
	cap.BackgroundColor3 = Color3.fromRGB(244, 244, 248)
	cap.BorderSizePixel = 0
	cap.ClipsDescendants = true
	cap.Parent = body
	UIKit.corner(cap, UDim.new(0, 9))
	local capStroke = UIKit.stroke(cap, tone, 2, 1) :: UIStroke

	-- Holding fills the key from the bottom: the eye stays on the key while you hold it.
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.Size = UDim2.fromScale(1, 0)
	fill.BackgroundColor3 = tone
	fill.BackgroundTransparency = 0.1
	fill.BorderSizePixel = 0
	fill.Parent = cap

	local capText = Instance.new("TextLabel")
	capText.Name = "Key"
	capText.Size = UDim2.fromScale(1, 1)
	capText.BackgroundTransparency = 1
	capText.Font = Theme.FontBlack
	capText.TextSize = 20
	capText.TextColor3 = Color3.fromRGB(22, 24, 30)
	capText.Text = keyName(prompt)
	capText.ZIndex = 3
	capText.Parent = cap

	local action = Instance.new("TextLabel")
	action.Name = "Action"
	action.BackgroundTransparency = 1
	action.Font = Theme.FontBlack
	action.TextSize = 19
	action.TextColor3 = Theme.Text
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.TextTruncate = Enum.TextTruncate.AtEnd
	action.Parent = body

	local object = Instance.new("TextLabel")
	object.Name = "Object"
	object.Position = UDim2.fromOffset(CAP + 22, 30)
	object.Size = UDim2.new(1, -(CAP + 34), 0, 14)
	object.BackgroundTransparency = 1
	object.Font = Theme.FontBold
	object.TextSize = 12
	object.TextColor3 = Theme.TextDim
	object.TextXAlignment = Enum.TextXAlignment.Left
	object.TextTruncate = Enum.TextTruncate.AtEnd
	object.Parent = body

	-- The hold, along the bottom edge as well.
	local bar = Instance.new("Frame")
	bar.Name = "Bar"
	bar.AnchorPoint = Vector2.new(0, 1)
	bar.Position = UDim2.fromScale(0, 1)
	bar.Size = UDim2.new(0, 0, 0, 3)
	bar.BackgroundColor3 = tone
	bar.BorderSizePixel = 0
	bar.Parent = body

	local shown: Shown = {
		gui = bb, holder = holder, scale = scale, stroke = stroke, capStroke = capStroke, fill = fill, bar = bar,
		action = action, object = object, tone = tone, watch = {}, hold = nil,
	}
	refreshText(shown, prompt)
	-- The pill fits its words: no long empty tail after "Talk".
	local wide = math.max(#action.Text * 11, #object.Text * 7) + CAP + 46
	body.Size = UDim2.fromOffset(math.clamp(wide, 170, 270), HEIGHT)
	for _, property in ipairs({ "ActionText", "ObjectText", "HoldDuration" }) do
		table.insert(shown.watch, prompt:GetPropertyChangedSignal(property):Connect(function()
			refreshText(shown, prompt)
		end))
	end

	-- Fade everything in from nothing while it grows and rises.
	for _, d in ipairs(holder:GetDescendants()) do
		if d:IsA("TextLabel") then
			local to = d.TextTransparency
			d.TextTransparency = 1
			TweenService:Create(d, FADE, { TextTransparency = to }):Play()
		elseif d:IsA("Frame") then
			local to = d.BackgroundTransparency
			d.BackgroundTransparency = 1
			TweenService:Create(d, FADE, { BackgroundTransparency = to }):Play()
		end
	end
	TweenService:Create(scale, IN, { Scale = 1 }):Play()
	TweenService:Create(holder, IN, { Position = UDim2.fromScale(0.5, 0.5) }):Play()
	return shown
end

-- Style has to be set BEFORE the prompt is ever shown, not inside PromptShown.
--
-- Roblox builds its own default UI as part of showing a prompt, so switching to Custom at
-- that moment is a frame too late: the stock prompt is already on screen and stays there,
-- and the player sees two prompts stacked on top of each other. Claiming every prompt up
-- front -- and any added later -- means Roblox never draws one at all.
local function claim(inst: Instance)
	if inst:IsA("ProximityPrompt") and inst.Style ~= Enum.ProximityPromptStyle.Custom then
		inst.Style = Enum.ProximityPromptStyle.Custom
	end
end

for _, d in ipairs(workspace:GetDescendants()) do
	claim(d)
end
workspace.DescendantAdded:Connect(claim)

ProximityPromptService.PromptShown:Connect(function(prompt: ProximityPrompt)
	claim(prompt)
	if active[prompt] then
		return
	end
	local shown = build(prompt)
	if shown then
		active[prompt] = shown
		setFocus(prompt)
	end
end)

local function forget(prompt: ProximityPrompt, shown: Shown)
	active[prompt] = nil
	for _, c in ipairs(shown.watch) do
		c:Disconnect()
	end
	if focused == prompt then
		-- Back to whichever other prompt is still up, if any.
		setFocus((next(active)))
	end
end

local function dismiss(prompt: ProximityPrompt)
	local shown = active[prompt]
	if not shown then
		return
	end
	forget(prompt, shown)
	TweenService:Create(shown.scale, OUT, { Scale = 0.82 }):Play()
	TweenService:Create(shown.holder, OUT, { Position = UDim2.new(0.5, 0, 0.5, RISE / 2) }):Play()
	for _, d in ipairs(shown.holder:GetDescendants()) do
		if d:IsA("TextLabel") then
			TweenService:Create(d, FADE, { TextTransparency = 1 }):Play()
		elseif d:IsA("Frame") then
			TweenService:Create(d, FADE, { BackgroundTransparency = 1 }):Play()
		elseif d:IsA("UIStroke") then
			TweenService:Create(d, FADE, { Transparency = 1 }):Play()
		end
	end
	local gui = shown.gui
	task.delay(0.18, function()
		gui:Destroy()
	end)
end

ProximityPromptService.PromptHidden:Connect(dismiss)

-- Holding: fill the key and the bar, light the edges in the tone.
ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt: ProximityPrompt)
	local shown = active[prompt]
	if not shown then
		return
	end
	local linear = TweenInfo.new(math.max(prompt.HoldDuration, 0.05), Enum.EasingStyle.Linear)
	shown.hold = TweenService:Create(shown.fill, linear, { Size = UDim2.fromScale(1, 1) })
	;(shown.hold :: Tween):Play()
	TweenService:Create(shown.bar, linear, { Size = UDim2.new(1, 0, 0, 3) }):Play()
	TweenService:Create(shown.stroke, FADE, { Color = shown.tone, Transparency = 0 }):Play()
	TweenService:Create(shown.capStroke, FADE, { Transparency = 0 }):Play()
	TweenService:Create(shown.scale, FADE, { Scale = 1.04 }):Play()
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt: ProximityPrompt)
	local shown = active[prompt]
	if not shown then
		return
	end
	-- Snap back rather than easing, so an abandoned hold is unmistakably abandoned.
	local snap = TweenInfo.new(0.1)
	TweenService:Create(shown.fill, snap, { Size = UDim2.fromScale(1, 0) }):Play()
	TweenService:Create(shown.bar, snap, { Size = UDim2.new(0, 0, 0, 3) }):Play()
	TweenService:Create(shown.stroke, FADE, { Color = Theme.StrokeLight, Transparency = 0.35 }):Play()
	TweenService:Create(shown.capStroke, FADE, { Transparency = 1 }):Play()
	TweenService:Create(shown.scale, FADE, { Scale = 1 }):Play()
end)

-- A completed interaction flashes the key and pops the prompt: the hold landed.
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
	local shown = active[prompt]
	if not shown then
		return
	end
	local cap = shown.fill.Parent
	if cap and cap:IsA("Frame") then
		cap.BackgroundColor3 = shown.tone
		TweenService:Create(cap, TweenInfo.new(0.4), { BackgroundColor3 = Color3.fromRGB(244, 244, 248) }):Play()
	end
	shown.scale.Scale = 1.1
	TweenService:Create(shown.scale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1 }):Play()
end)

-- A prompt destroyed while shown (an opened crate, say) would otherwise strand its UI.
RunService.Heartbeat:Connect(function()
	for prompt, shown in pairs(active) do
		if not prompt.Parent or not prompt:IsDescendantOf(workspace) then
			forget(prompt, shown)
			shown.gui:Destroy()
		end
	end
	if focus.Enabled and (focus.Adornee == nil or not (focus.Adornee :: Instance):IsDescendantOf(workspace)) then
		setFocus((next(active)))
	end
end)
