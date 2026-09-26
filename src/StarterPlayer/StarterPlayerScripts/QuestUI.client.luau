--!strict
-- Quest dialogue. (The objective tracker that used to live here is retired -- see below.)

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local UIKit = require(ReplicatedStorage.UIKit)
local UIState = require(game:GetService("ReplicatedStorage"):WaitForChild("UIState"))
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))
local Theme = UIKit.Theme

local player = Players.LocalPlayer
local remotes = ReplicatedStorage:WaitForChild("GameRemotes")
local OpenDialogue = remotes:WaitForChild("OpenDialogue") :: RemoteEvent
local QuestAction = remotes:WaitForChild("QuestAction") :: RemoteFunction
local QuestUpdated = remotes:WaitForChild("QuestUpdated") :: RemoteEvent

local gui = Instance.new("ScreenGui")
gui.Name = "QuestUI"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = player:WaitForChild("PlayerGui")

local state = nil
local offerId: string? = nil

-- --------------------------------------------------------------- tracker --

local tracker = UIKit.frame({
	Name = "Tracker",
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -20, 0, 20),
	Size = UDim2.fromOffset(240, 62),
	BackgroundColor3 = Theme.Background,
	BackgroundTransparency = 0.15,
	Visible = false,
	Parent = gui,
})
UIKit.corner(tracker, UDim.new(0, 10))
UIKit.stroke(tracker, Theme.Stroke, 1, 0.3)

local tTitle = UIKit.label({
	Position = UDim2.fromOffset(12, 8),
	Size = UDim2.new(1, -24, 0, 18),
	Text = "",
	Font = Theme.FontBold,
	TextColor3 = Theme.Accent,
	TextSize = 14,
	Parent = tracker,
})

local tObjective = UIKit.label({
	Position = UDim2.fromOffset(12, 26),
	Size = UDim2.new(1, -24, 0, 16),
	Text = "",
	TextColor3 = Theme.TextDim,
	TextSize = 12,
	Parent = tracker,
})

local tBarBg = UIKit.frame({
	Position = UDim2.fromOffset(12, 46),
	Size = UDim2.new(1, -24, 0, 6),
	BackgroundColor3 = Theme.PanelLight,
	Parent = tracker,
})
UIKit.corner(tBarBg, UDim.new(1, 0))
local tBarFill = UIKit.frame({
	Size = UDim2.fromScale(0, 1),
	BackgroundColor3 = Theme.Accent,
	Parent = tBarBg,
})
UIKit.corner(tBarFill, UDim.new(1, 0))

local function renderTracker()
	local active = state and state.active
	-- The tracker is RETIRED. ReplicatedStorage.UI.Modules.Objective draws the objective card
	-- now, off the same QuestUpdated broadcast, in the rebuilt interface's style. Two trackers
	-- reading the same state and drawing it twice is the duplicate-system problem, so this one
	-- stays hidden.
	--
	-- The frame and its labels are left in place rather than deleted because the dialogue half
	-- of this script -- which has NOT been replaced -- still shares this file, and unpicking
	-- the construction buys nothing.
	tracker.Visible = false
	if not active then
		return
	end
	tTitle.Text = active.title
	tObjective.Text = string.format("%s  %d / %d", active.label, active.progress, active.goal)
	local pct = active.goal > 0 and math.clamp(active.progress / active.goal, 0, 1) or 0
	TweenService:Create(tBarFill, TweenInfo.new(0.3), { Size = UDim2.fromScale(pct, 1) }):Play()
end

-- -------------------------------------------------------------- dialogue --

local panel = UIKit.frame({
	Name = "Dialogue",
	AnchorPoint = Vector2.new(0.5, 1),
	Position = UDim2.new(0.5, 0, 1, -90),
	Size = UDim2.fromOffset(620, 330),   -- scaled to fit below, see UIKit.fitToScreen
	BackgroundColor3 = Theme.Background,
	Visible = false,
	Parent = gui,
})
UIKit.corner(panel, UDim.new(0, 12))
UIKit.stroke(panel, Theme.AccentDim, 1, 0.2)
-- Anchored to the bottom of the screen, so it needs a smaller margin than the full
-- panels: 24px keeps it clear of the edge without floating away from it.
UIKit.fitToScreen(panel, 620, 330, 24)

local dGiver = UIKit.label({
	Position = UDim2.fromOffset(20, 14),
	Size = UDim2.new(1, -40, 0, 22),
	Text = "",
	Font = Theme.FontBold,
	TextColor3 = Theme.Accent,
	TextSize = 18,
	Parent = panel,
})

local dBody = UIKit.label({
	Position = UDim2.fromOffset(20, 42),
	Size = UDim2.new(1, -40, 0, 84),
	Text = "",
	TextColor3 = Theme.Text,
	TextSize = 14,
	TextWrapped = true,
	TextYAlignment = Enum.TextYAlignment.Top,
	Parent = panel,
})

local dRewards = UIKit.label({
	Position = UDim2.fromOffset(20, 130),
	Size = UDim2.new(1, -40, 0, 18),
	Text = "",
	Font = Theme.FontBold,
	TextColor3 = Theme.TextDim,
	TextSize = 12,
	Parent = panel,
})

-- Choice buttons are built per node rather than being a fixed set: which lines a player
-- can say depends on state the SERVER evaluated, so the panel renders whatever it was
-- handed and nothing more.
local dChoices = Instance.new("Frame")
dChoices.Name = "Choices"
dChoices.Position = UDim2.fromOffset(20, 156)
dChoices.Size = UDim2.new(1, -40, 0, 120)
dChoices.BackgroundTransparency = 1
dChoices.Parent = panel

local choiceLayout = Instance.new("UIListLayout")
choiceLayout.Padding = UDim.new(0, 6)
choiceLayout.SortOrder = Enum.SortOrder.LayoutOrder
choiceLayout.Parent = dChoices

local dClose = UIKit.button({
	Name = "Close",
	AnchorPoint = Vector2.new(1, 1),
	Position = UDim2.new(1, -20, 1, -16),
	Size = UDim2.fromOffset(140, 36),
	Text = "Leave",
	TextSize = 14,
	Parent = panel,
})
UIKit.corner(dClose, UDim.new(0, 8))
UIKit.hover(dClose, Theme.PanelLight, Theme.Danger)

local toast = UIKit.label({
	AnchorPoint = Vector2.new(0.5, 0),
	Position = UDim2.fromScale(0.5, 0.18),
	Size = UDim2.fromOffset(460, 40),
	Text = "",
	Font = Theme.FontBold,
	TextColor3 = Theme.Accent,
	TextSize = 20,
	TextXAlignment = Enum.TextXAlignment.Center,
	TextTransparency = 1,
	Parent = gui,
})

local function setDialogueOpen(open: boolean)
	panel.Visible = open
	UIState.SetOpen("Quest", open)   -- ShiftLock frees the cursor on this
end

local currentGiver: string? = nil
local currentNode: string? = nil

local function renderDialogue(giverName: string, node)
	dGiver.Text = giverName
	currentNode = node and node.node or nil

	dBody.Text = node and node.body or ""

	-- The reward line belongs to an offer, not to the conversation, so it shows only while
	-- one is actually on the table.
	if state and state.offer then
		local o = state.offer
		-- Built from whatever the offer actually pays rather than assuming coins and XP:
		-- a contract pays no coins at all, and formatting a nil with %d throws.
		local pays = {}
		if o.coins then
			table.insert(pays, string.format("%d coins", o.coins))
		end
		if o.xp then
			table.insert(pays, string.format("%d XP", GameConfig.ShownXP(o.xp)))
		end
		if o.crystals then
			table.insert(pays, string.format("%d crystals", o.crystals))
		end
		local line = string.format("Reward:  %s        Objective:  %s x%d",
			table.concat(pays, "   ·   "), o.label, o.goal)
		-- The price goes first. A contract is charged the moment it is accepted, so it has
		-- to be the first thing read, not a detail after the reward.
		if o.cost and o.cost > 0 then
			line = string.format("COSTS %d COINS        ", o.cost) .. line
		end
		dRewards.Text = line
	elseif state and state.active then
		local a = state.active
		dRewards.Text = string.format("Current:  %s — %d of %d", a.label, a.progress, a.goal)
	else
		dRewards.Text = state and string.format("Completed %d of %d", state.completedCount, state.totalQuests) or ""
	end

	for _, child in ipairs(dChoices:GetChildren()) do
		if child:IsA("TextButton") then
			child:Destroy()
		end
	end
	if not node then
		return
	end

	for i, choice in ipairs(node.choices) do
		local btn = UIKit.button({
			Name = choice.id,
			Size = UDim2.new(1, 0, 0, 30),
			Text = choice.text,
			TextSize = 14,
			LayoutOrder = i,
			Parent = dChoices,
		})
		btn.TextXAlignment = Enum.TextXAlignment.Left
		local pad = Instance.new("UIPadding")
		pad.PaddingLeft = UDim.new(0, 12)
		pad.Parent = btn
		UIKit.corner(btn, UDim.new(0, 8))
		UIKit.hover(btn, Theme.Panel, Theme.PanelLight)
		btn.TextColor3 = Theme.Text

		btn.MouseButton1Click:Connect(function()
			if not currentGiver or not currentNode then
				return
			end
			local result = QuestAction:InvokeServer("choose", {
				giver = currentGiver, node = currentNode, choice = choice.id,
			})
			if typeof(result) ~= "table" then
				return
			end
			state = QuestAction:InvokeServer("state")
			renderTracker()
			if result.close or not result.next then
				setDialogueOpen(false)
			else
				renderDialogue(giverName, result.next)
			end
		end)
	end
end

dClose.MouseButton1Click:Connect(function()
	setDialogueOpen(false)
end)

OpenDialogue.OnClientEvent:Connect(function(giverId, giverName, newState, node)
	state = newState
	currentGiver = giverId
	renderTracker()
	renderDialogue(giverName, node)
	setDialogueOpen(true)
end)

QuestUpdated.OnClientEvent:Connect(function(newState, completion)
	state = newState
	renderTracker()

	if completion then
		toast.Text = string.format("Quest complete — %s   (+%d coins, +%d XP)",
			completion.completed, completion.coins or 0, completion.xp or 0)
		toast.TextTransparency = 0
		task.delay(3, function()
			TweenService:Create(toast, TweenInfo.new(0.6), { TextTransparency = 1 }):Play()
		end)
	end
end)

-- Initial fetch, retried while the profile loads.
task.spawn(function()
	for _ = 1, 10 do
		local ok, result = pcall(function()
			return QuestAction:InvokeServer("state")
		end)
		if ok and result then
			state = result
			renderTracker()
			return
		end
		task.wait(2)
	end
end)
