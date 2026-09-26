--!strict
-- The contracts panel: today's three jobs, how far along each is, what they pay, and the
-- bonus for finishing all three.
--
-- One card per contract, coloured by tier (green easy, blue medium, purple hard) the way the
-- reference colours its rarity cards, with a progress bar and the payout under it. A paid
-- contract is stamped COMPLETE and dims. Contracts pay themselves the moment they are done
-- (ContractService), so there is no claim button to forget.

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menu = require(script.Parent.Menu)
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(ReplicatedStorage:WaitForChild("GameConfig"))

local Contracts = {}
Contracts.__index = Contracts

local TIER_COLOUR = {
	Easy = Color3.fromRGB(88, 214, 110),
	Medium = Color3.fromRGB(70, 160, 255),
	Hard = Color3.fromRGB(190, 110, 255),
}

local function clock(seconds: number): string
	local hours = math.floor(seconds / 3600)
	local minutes = math.floor((seconds % 3600) / 60)
	if hours > 0 then
		return string.format("%dh %dm", hours, minutes)
	end
	return string.format("%dm", math.max(1, minutes))
end

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

local function rewardText(reward: any): string
	if type(reward) ~= "table" then
		return ""
	end
	local parts = { "$" .. commas(tonumber(reward.coins) or 0), commas(GameConfig.ShownXP(reward.xp)) .. " XP" }
	if tonumber(reward.crystals) and reward.crystals > 0 then
		table.insert(parts, "💎 " .. tostring(reward.crystals))
	end
	return table.concat(parts, "   ")
end
Contracts.RewardText = rewardText

function Contracts.new(parent: Instance, remotes)
	local self = setmetatable({}, Contracts)
	self._remotes = remotes
	self._cards = {}

	local menu = Menu.new(parent, {
		id = "Contracts",
		title = "Contracts",
		subtitle = "Three jobs a day -- they pay the moment they are done",
		icon = "📋",
		size = UDim2.fromOffset(940, 470),
	})
	self._menu = menu

	self._timer = Components.Label(menu.content, {
		text = "",
		font = Theme.Font.Bold,
		size = Theme.Text.Body,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
	})
	self._timer.Size = UDim2.new(1, 0, 0, 20)

	self._row = Instance.new("Frame")
	self._row.Name = "Cards"
	self._row.BackgroundTransparency = 1
	self._row.Size = UDim2.new(1, 0, 0, 262)
	self._row.Position = UDim2.fromOffset(0, 28)
	self._row.Parent = menu.content
	local row = Components.List(self._row, Enum.FillDirection.Horizontal, 16, Enum.HorizontalAlignment.Center)
	row.VerticalAlignment = Enum.VerticalAlignment.Center

	-- The bonus strip.
	local bonus = Instance.new("Frame")
	bonus.Name = "Bonus"
	bonus.BackgroundColor3 = Theme.Colour.PanelRaised
	bonus.BorderSizePixel = 0
	bonus.AnchorPoint = Vector2.new(0.5, 0)
	bonus.Position = UDim2.new(0.5, 0, 0, 302)
	bonus.Size = UDim2.new(0, 812, 0, 50)
	bonus.Parent = menu.content
	Components.Corner(bonus, 12)
	Components.Stroke(bonus, Theme.Colour.Outline, 2)
	local chest = Components.Icon(bonus, "🎁", 30)
	chest.AnchorPoint = Vector2.new(0, 0.5)
	chest.Position = UDim2.new(0, 14, 0.5, 0)
	self._bonusText = Components.Label(bonus, {
		text = "",
		face = Theme.Face.Condensed,
		size = 20,
		colour = Theme.Colour.Level,
	})
	self._bonusText.Position = UDim2.fromOffset(56, 0)
	self._bonusText.Size = UDim2.new(1, -220, 1, 0)
	self._bonusReward = Components.Label(bonus, {
		text = "",
		font = Theme.Font.Display,
		size = 20,
		colour = Theme.Colour.Currency,
		align = Enum.TextXAlignment.Right,
	})
	self._bonusReward.Position = UDim2.new(1, -16, 0, 0)
	self._bonusReward.AnchorPoint = Vector2.new(1, 0)
	self._bonusReward.Size = UDim2.new(0, 300, 1, 0)
	self._bonusBar = Components.Bar(bonus, { height = 4, colour = Theme.Colour.Level })
	self._bonusBar.instance.AnchorPoint = Vector2.new(0, 1)
	self._bonusBar.instance.Position = UDim2.new(0, 56, 1, -6)
	self._bonusBar.instance.Size = UDim2.new(1, -72, 0, 4)

	self._lifetime = Components.Label(menu.content, {
		text = "",
		size = Theme.Text.Small,
		colour = Theme.Colour.TextMuted,
		align = Enum.TextXAlignment.Center,
	})
	self._lifetime.Size = UDim2.new(1, 0, 0, 18)
	self._lifetime.Position = UDim2.fromOffset(0, 362)

	menu:OnOpen(function()
		self:Refresh()
	end)
	return self
end

function Contracts:Refresh()
	task.spawn(function()
		local ok, state = pcall(function()
			return self._remotes.contractAction:InvokeServer("state")
		end)
		if ok and type(state) == "table" then
			self:_render(state)
		else
			self._timer.Text = "Contracts are loading -- try again in a moment"
		end
	end)
end

local function card(parent: GuiObject, entry: any, order: number): Frame
	local tier = tostring(entry.tier or "Easy")
	local colour = TIER_COLOUR[tier] or Theme.Colour.Info
	local paid = entry.paid == true
	local target = math.max(1, tonumber(entry.target) or 1)
	local progress = math.clamp(tonumber(entry.progress) or 0, 0, target)

	local tile = Instance.new("Frame")
	tile.Name = "Contract_" .. tostring(entry.id)
	tile.BackgroundColor3 = paid and Theme.Colour.Sunken or Theme.Shade(colour, -0.35)
	tile.BorderSizePixel = 0
	tile.Size = UDim2.fromOffset(260, 250)
	tile.LayoutOrder = order
	tile.Parent = parent
	Components.Corner(tile, 16)
	Components.Stroke(tile, paid and Theme.Colour.Stroke or colour:Lerp(Color3.new(1, 1, 1), 0.3), 3)
	if not paid then
		Components.Gradient(tile, Color3.new(1, 1, 1), Color3.fromRGB(150, 150, 160), 90)
	end

	local chip = Components.Chip(tile, string.upper(tier), colour, { filled = true })
	chip.AnchorPoint = Vector2.new(0.5, 0)
	chip.Position = UDim2.new(0.5, 0, 0, 12)

	local icon = Components.Icon(tile, tostring(entry.icon or "📋"), 46)
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.new(0.5, 0, 0, 40)

	local title = Components.Label(tile, {
		text = string.upper(tostring(entry.title or "")),
		face = Theme.Face.HeavyItalic,
		size = 28,
		align = Enum.TextXAlignment.Center,
		colour = paid and Theme.Colour.TextMuted or Theme.Colour.Text,
		outline = 3,
	})
	title.Position = UDim2.fromOffset(0, 96)
	title.Size = UDim2.new(1, 0, 0, 32)

	local text = Components.Label(tile, {
		text = tostring(entry.text or ""),
		font = Theme.Font.Medium,
		size = Theme.Text.Body,
		colour = Theme.Colour.TextDim,
		align = Enum.TextXAlignment.Center,
		wrap = true,
	})
	text.Position = UDim2.fromOffset(12, 128)
	text.Size = UDim2.new(1, -24, 0, 40)
	text.TextYAlignment = Enum.TextYAlignment.Top

	local bar = Components.Bar(tile, { height = 20, colour = paid and Theme.Colour.Accent or colour, rim = true })
	bar.instance.Position = UDim2.fromOffset(16, 172)
	bar.instance.Size = UDim2.new(1, -32, 0, 20)
	bar:SetFraction(progress / target)
	local count = Components.Label(bar.instance, {
		text = paid and "✓ COMPLETE" or string.format("%s / %s", commas(progress), commas(target)),
		font = Theme.Font.Bold,
		size = Theme.Text.Small,
		align = Enum.TextXAlignment.Center,
		outline = 1.5,
	})
	count.Size = UDim2.fromScale(1, 1)
	count.ZIndex = 5

	local reward = Components.Label(tile, {
		text = rewardText(entry.reward),
		font = Theme.Font.Display,
		size = 18,
		colour = paid and Theme.Colour.TextMuted or Theme.Colour.Currency,
		align = Enum.TextXAlignment.Center,
		outline = false,
	})
	Components.Outline(reward, 2, Theme.Colour.CurrencyEdge, paid and 0.6 or 0)
	reward.Position = UDim2.fromOffset(0, 206)
	reward.Size = UDim2.new(1, 0, 0, 24)

	if paid then
		-- A tick badge in the corner; the card itself stays readable.
		local badge = Instance.new("Frame")
		badge.Name = "Done"
		badge.BackgroundColor3 = Theme.Colour.Accent
		badge.BorderSizePixel = 0
		badge.AnchorPoint = Vector2.new(1, 0)
		badge.Position = UDim2.new(1, -10, 0, 10)
		badge.Size = UDim2.fromOffset(34, 34)
		badge.ZIndex = 6
		badge.Parent = tile
		Components.Corner(badge, 17)
		Components.Stroke(badge, Theme.Colour.Outline, 2.5)
		local tick = Components.Label(badge, {
			text = "✓",
			font = Theme.Font.Display,
			size = 22,
			align = Enum.TextXAlignment.Center,
			outline = 2,
		})
		tick.Size = UDim2.fromScale(1, 1)
		tick.ZIndex = 7
	end
	return tile
end

function Contracts:_render(state)
	for _, c in ipairs(self._cards) do
		c:Destroy()
	end
	table.clear(self._cards)

	local list = type(state.contracts) == "table" and state.contracts or {}
	for index, entry in ipairs(list) do
		table.insert(self._cards, card(self._row, entry, index))
	end

	local done = tonumber(state.done) or 0
	self._timer.Text = string.format("⏱ New contracts in %s", clock(tonumber(state.secondsLeft) or 0))
	if state.bonusPaid then
		self._bonusText.Text = "ALL THREE DONE -- BONUS PAID  ✓"
		self._bonusText.TextColor3 = Theme.Colour.Accent
	else
		self._bonusText.Text = string.format("FINISH ALL THREE FOR A BONUS   (%d / %d)", done, math.max(#list, 1))
		self._bonusText.TextColor3 = Theme.Colour.Level
	end
	self._bonusReward.Text = rewardText(state.bonus)
	self._bonusBar:SetFraction(#list > 0 and done / #list or 0)
	self._lifetime.Text = string.format("%d contracts completed all time", tonumber(state.lifetime) or 0)
end

function Contracts:Toggle()
	self._menu:Toggle()
end

function Contracts:Close()
	self._menu:Close()
end

function Contracts:IsOpen(): boolean
	return self._menu:IsOpen()
end

return Contracts
