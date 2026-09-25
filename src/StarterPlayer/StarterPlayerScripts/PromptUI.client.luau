--!strict
-- Interaction prompts, drawn by the game instead of by Roblox.
--
-- The stock ProximityPrompt is the single most recognisable "this is a default Roblox
-- experience" element on screen, and it appears every time the player walks up to a crate,
-- a vendor or a quest giver -- so it is worth replacing once, here, rather than living
-- with it everywhere.
--
-- One script covers every prompt in the game, present and future: nothing has to opt in,
-- and a prompt added later is styled automatically.

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))
local Theme = UIKit.Theme

local player = Players.LocalPlayer

local FADE = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

-- Live prompt -> the BillboardGui drawing it, so a prompt hidden mid-hold cleans up.
local active: { [ProximityPrompt]: BillboardGui } = {}

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

local function build(prompt: ProximityPrompt): BillboardGui
	local anchor = prompt.Parent
	if not anchor or not anchor:IsA("BasePart") then
		return nil :: any
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "PromptUI"
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.Size = UDim2.fromOffset(230, 54)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 1.6, 0)
	-- Parented to the part rather than to PlayerGui with an Adornee. Both render; this way
	-- the prompt follows the part for free and is destroyed with it, so an opened crate
	-- cannot strand its UI.
	--
	-- Created on the client, so it stays local and never replicates to anyone else.
	bb.Parent = anchor

	-- Everything lives inside one holder so the whole prompt can be scaled as a unit.
	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.AnchorPoint = Vector2.new(0.5, 0.5)
	holder.Position = UDim2.fromScale(0.5, 0.5)
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundTransparency = 1
	holder.Parent = bb

	local scale = Instance.new("UIScale")
	scale.Scale = 0.85
	scale.Parent = holder

	-- The pill.
	local body = Instance.new("Frame")
	body.Name = "Body"
	body.AnchorPoint = Vector2.new(0.5, 0.5)
	body.Position = UDim2.fromScale(0.5, 0.5)
	body.Size = UDim2.fromOffset(210, 44)
	body.BackgroundColor3 = Theme.Background
	body.BackgroundTransparency = 0.12
	body.BorderSizePixel = 0
	body.Parent = holder
	UIKit.corner(body, UDim.new(0, 10))
	UIKit.stroke(body, Theme.StrokeLight, 1, 0.5)
	UIKit.sheen(body, 0.07)

	-- Key cap on the left.
	local cap = Instance.new("Frame")
	cap.Name = "Cap"
	cap.AnchorPoint = Vector2.new(0, 0.5)
	cap.Position = UDim2.new(0, 7, 0.5, 0)
	cap.Size = UDim2.fromOffset(30, 30)
	cap.BackgroundColor3 = Theme.PanelLight
	cap.BorderSizePixel = 0
	cap.Parent = body
	UIKit.corner(cap, UDim.new(0, 7))
	UIKit.stroke(cap, Theme.StrokeLight, 1, 0.35)

	-- The hold indicator fills the cap from the bottom. Putting it on the key itself,
	-- rather than on a separate bar, keeps the eye in one place while holding.
	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.AnchorPoint = Vector2.new(0, 1)
	fill.Position = UDim2.fromScale(0, 1)
	fill.Size = UDim2.fromScale(1, 0)
	fill.BackgroundColor3 = Theme.Accent
	fill.BackgroundTransparency = 0.25
	fill.BorderSizePixel = 0
	fill.Parent = cap
	UIKit.corner(fill, UDim.new(0, 7))

	local capText = Instance.new("TextLabel")
	capText.Name = "Key"
	capText.Size = UDim2.fromScale(1, 1)
	capText.BackgroundTransparency = 1
	capText.Font = Theme.FontBold
	capText.TextSize = 14
	capText.TextColor3 = Theme.Text
	capText.Text = keyName(prompt)
	capText.ZIndex = 3
	capText.Parent = cap

	local action = Instance.new("TextLabel")
	action.Name = "Action"
	action.Position = UDim2.fromOffset(46, 6)
	action.Size = UDim2.new(1, -54, 0, 18)
	action.BackgroundTransparency = 1
	action.Font = Theme.FontBold
	action.TextSize = 14
	action.TextColor3 = Theme.Text
	action.TextXAlignment = Enum.TextXAlignment.Left
	action.TextTruncate = Enum.TextTruncate.AtEnd
	action.Text = prompt.ActionText ~= "" and prompt.ActionText or "Interact"
	action.Parent = body

	local object = Instance.new("TextLabel")
	object.Name = "Object"
	object.Position = UDim2.fromOffset(46, 23)
	object.Size = UDim2.new(1, -54, 0, 14)
	object.BackgroundTransparency = 1
	object.Font = Theme.Font
	object.TextSize = 11
	object.TextColor3 = Theme.TextDim
	object.TextXAlignment = Enum.TextXAlignment.Left
	object.TextTruncate = Enum.TextTruncate.AtEnd
	object.Text = prompt.ObjectText
	object.Visible = prompt.ObjectText ~= ""
	object.Parent = body

	-- Only one line of text: centre it rather than leaving it floating high.
	if not object.Visible then
		action.Position = UDim2.fromOffset(46, 0)
		action.Size = UDim2.new(1, -54, 1, 0)
	end

	-- Grow in.
	TweenService:Create(scale, FADE, { Scale = 1 }):Play()
	return bb
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

ProximityPromptService.PromptShown:Connect(function(prompt)
	claim(prompt)
	if active[prompt] then
		return
	end
	local bb = build(prompt)
	if bb then
		active[prompt] = bb
	end
end)

local function dismiss(prompt: ProximityPrompt)
	local bb = active[prompt]
	if not bb then
		return
	end
	active[prompt] = nil
	local holder = bb:FindFirstChild("Holder")
	local scale = holder and holder:FindFirstChildOfClass("UIScale")
	if scale then
		TweenService:Create(scale, FADE, { Scale = 0.85 }):Play()
	end
	if holder then
		for _, d in ipairs(holder:GetDescendants()) do
			if d:IsA("TextLabel") then
				TweenService:Create(d, FADE, { TextTransparency = 1 }):Play()
			elseif d:IsA("Frame") then
				TweenService:Create(d, FADE, { BackgroundTransparency = 1 }):Play()
			elseif d:IsA("UIStroke") then
				TweenService:Create(d, FADE, { Transparency = 1 }):Play()
			end
		end
	end
	task.delay(0.18, function()
		bb:Destroy()
	end)
end

ProximityPromptService.PromptHidden:Connect(dismiss)

-- Holding: drive the fill on the key cap.
ProximityPromptService.PromptButtonHoldBegan:Connect(function(prompt)
	local bb = active[prompt]
	if not bb then
		return
	end
	local fill = bb:FindFirstChild("Fill", true)
	if fill and fill:IsA("Frame") then
		TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), {
			Size = UDim2.fromScale(1, 1),
		}):Play()
	end
end)

ProximityPromptService.PromptButtonHoldEnded:Connect(function(prompt)
	local bb = active[prompt]
	if not bb then
		return
	end
	local fill = bb:FindFirstChild("Fill", true)
	if fill and fill:IsA("Frame") then
		-- Snap back rather than easing, so an abandoned hold is unmistakably abandoned.
		TweenService:Create(fill, TweenInfo.new(0.1), { Size = UDim2.fromScale(1, 0) }):Play()
	end
end)

-- A completed interaction flashes the cap, which is the confirmation that the hold landed.
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	local bb = active[prompt]
	if not bb then
		return
	end
	local cap = bb:FindFirstChild("Cap", true)
	if cap and cap:IsA("Frame") then
		cap.BackgroundColor3 = Theme.Accent
		TweenService:Create(cap, TweenInfo.new(0.35), { BackgroundColor3 = Theme.PanelLight }):Play()
	end
end)

-- A prompt destroyed while shown (an opened crate, say) would otherwise strand its UI.
RunService.Heartbeat:Connect(function()
	for prompt, bb in pairs(active) do
		if not prompt.Parent or not prompt:IsDescendantOf(workspace) then
			active[prompt] = nil
			bb:Destroy()
		end
	end
end)
