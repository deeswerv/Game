--!strict
-- Opening a supply crate: the burst at the crate, and the card that says what you got.
--
-- Presentation only. The server has already decided and recorded the reward before this
-- runs, so nothing here can change what was won -- it is being told, not asked.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local ChestConfig = require(ReplicatedStorage:WaitForChild("ChestConfig"))
local UIKit = require(ReplicatedStorage:WaitForChild("UIKit"))

local player = Players.LocalPlayer
local ChestEffect = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("ChestEffect") :: RemoteEvent

-- ------------------------------------------------------------------- audio --

local openSound = Instance.new("Sound")
openSound.Name = "CrateOpen"
openSound.SoundId = "rbxassetid://117963160131194" -- the reload sample, pitched down: a solid mechanical clunk
openSound.Volume = 0.45
openSound.PlaybackSpeed = 0.65
openSound.Parent = SoundService

local rewardSound = Instance.new("Sound")
rewardSound.Name = "CrateReward"
rewardSound.SoundId = "rbxassetid://5789211405" -- short bright ring
rewardSound.Volume = 0.4
rewardSound.Parent = SoundService

-- ------------------------------------------------------------- world burst --

local bin = workspace:FindFirstChild("CombatFX") or workspace

-- A short column of light and a ring of shards. Scaled by tier, so a Common crate is a
-- small puff and a Legendary is worth looking up for -- without either being a firework.
local function burst(model: Model, tier: string)
	local spec = ChestConfig.Rarity[tier] or ChestConfig.Rarity.Common
	local base = model:FindFirstChild("Base")
	if not base or not base:IsA("BasePart") then
		return
	end
	local origin = base.Position + Vector3.new(0, 1, 0)

	local beam = Instance.new("Part")
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = spec.colour
	beam.Transparency = 0.4
	beam.Size = Vector3.new(1.6, 0.2, 1.6)
	beam.CFrame = CFrame.new(origin)
	beam.Parent = bin
	TweenService:Create(beam, TweenInfo.new(0.75, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(0.5, 11 + spec.glow * 9, 0.5),
		CFrame = CFrame.new(origin + Vector3.new(0, 5, 0)),
		Transparency = 1,
	}):Play()
	Debris:AddItem(beam, 0.85)

	local shards = 5 + math.floor(spec.glow * 7)
	for i = 1, shards do
		local angle = (i / shards) * math.pi * 2
		local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
		local shard = Instance.new("Part")
		shard.Anchored = true
		shard.CanCollide = false
		shard.CanQuery = false
		shard.CastShadow = false
		shard.Material = Enum.Material.Neon
		shard.Color = spec.colour
		shard.Size = Vector3.new(0.18, 0.18, 0.5)
		shard.CFrame = CFrame.new(origin, origin + dir)
		shard.Parent = bin
		TweenService:Create(shard, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(origin + dir * 5 + Vector3.new(0, 2.6, 0), origin + dir * 6),
			Size = Vector3.new(0.04, 0.04, 0.12),
			Transparency = 1,
		}):Play()
		Debris:AddItem(shard, 0.7)
	end
end

-- ------------------------------------------------------------ reward card --

local gui = Instance.new("ScreenGui")
gui.Name = "ChestReward"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 6
gui.Parent = player:WaitForChild("PlayerGui")

local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.34)
card.Size = UDim2.fromOffset(300, 92)
card.BackgroundColor3 = Color3.fromRGB(14, 14, 18)
card.BackgroundTransparency = 1
card.BorderSizePixel = 0
card.Visible = false
card.Active = false
card.Parent = gui

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 10)
cardCorner.Parent = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Thickness = 2
cardStroke.Transparency = 1
cardStroke.Parent = card

-- Rarity word, small and above the item, so the eye reads tier then reward.
local tierLabel = Instance.new("TextLabel")
tierLabel.Size = UDim2.new(1, 0, 0, 20)
tierLabel.Position = UDim2.fromOffset(0, 14)
tierLabel.BackgroundTransparency = 1
tierLabel.Font = Enum.Font.GothamBold
tierLabel.TextSize = 13
tierLabel.TextTransparency = 1
tierLabel.Parent = card

local itemLabel = Instance.new("TextLabel")
itemLabel.Size = UDim2.new(1, -20, 0, 34)
itemLabel.Position = UDim2.fromOffset(10, 38)
itemLabel.BackgroundTransparency = 1
itemLabel.Font = Enum.Font.GothamBlack
itemLabel.TextSize = 24
itemLabel.TextColor3 = Color3.new(1, 1, 1)
itemLabel.TextScaled = false
itemLabel.TextTransparency = 1
itemLabel.Parent = card

local kindLabel = Instance.new("TextLabel")
kindLabel.Size = UDim2.new(1, 0, 0, 16)
kindLabel.Position = UDim2.fromOffset(0, 70)
kindLabel.BackgroundTransparency = 1
kindLabel.Font = Enum.Font.Gotham
kindLabel.TextSize = 11
kindLabel.TextColor3 = Color3.fromRGB(150, 150, 162)
kindLabel.TextTransparency = 1
kindLabel.Parent = card

UIKit.fitToScreen(card, 300, 92, 20)

local KIND_WORD = {
	coins = "ADDED TO YOUR BALANCE",
	camo = "CAMO UNLOCKED",
	attachment = "ATTACHMENT UNLOCKED",
}

local showToken = 0

local function showReward(tier: string, kind: string, label: string)
	local spec = ChestConfig.Rarity[tier] or ChestConfig.Rarity.Common
	showToken += 1
	local token = showToken

	tierLabel.Text = string.upper(tier)
	tierLabel.TextColor3 = spec.colour
	itemLabel.Text = label
	kindLabel.Text = KIND_WORD[kind] or ""
	cardStroke.Color = spec.colour

	card.Visible = true
	card.Size = UDim2.fromOffset(300, 92)
	card.BackgroundTransparency = 1

	local FADE_IN = TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
	TweenService:Create(card, FADE_IN, { BackgroundTransparency = 0.08 }):Play()
	TweenService:Create(cardStroke, FADE_IN, { Transparency = 0.15 }):Play()
	TweenService:Create(tierLabel, FADE_IN, { TextTransparency = 0 }):Play()
	TweenService:Create(itemLabel, FADE_IN, { TextTransparency = 0 }):Play()
	TweenService:Create(kindLabel, FADE_IN, { TextTransparency = 0.15 }):Play()

	rewardSound.PlaybackSpeed = 0.85 + spec.glow * 0.5
	rewardSound:Play()

	task.delay(2.4, function()
		-- A second crate opened during the hold replaces the card rather than letting an
		-- older timer fade the newer reward out from under it.
		if token ~= showToken then
			return
		end
		local OUT = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
		TweenService:Create(card, OUT, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(cardStroke, OUT, { Transparency = 1 }):Play()
		TweenService:Create(tierLabel, OUT, { TextTransparency = 1 }):Play()
		TweenService:Create(itemLabel, OUT, { TextTransparency = 1 }):Play()
		TweenService:Create(kindLabel, OUT, { TextTransparency = 1 }):Play()
		task.delay(0.32, function()
			if token == showToken then
				card.Visible = false
			end
		end)
	end)
end

ChestEffect.OnClientEvent:Connect(function(kind, ...)
	if kind == "Open" then
		local model, tier = ...
		if typeof(model) == "Instance" and model:IsA("Model") and model.Parent then
			burst(model, tier or "Common")
			local base = model:FindFirstChild("Base")
			if base and base:IsA("BasePart") then
				-- Positional, so someone else's crate across the map is quiet.
				local s = openSound:Clone()
				s.Parent = base
				s.RollOffMaxDistance = 90
				s:Play()
				Debris:AddItem(s, 3)
			end
		end
	elseif kind == "Reward" then
		local tier, rewardKind, label = ...
		if type(label) == "string" then
			showReward(tier or "Common", rewardKind or "coins", label)
		end
	end
end)
