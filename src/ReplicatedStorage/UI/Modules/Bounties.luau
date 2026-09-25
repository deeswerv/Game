--!strict
-- Bounties on the HUD: streak calls, the WANTED tag over anybody with a price on their head,
-- and your own price while it is yours.
--
-- The tag is a billboard pinned over the WANTED player's head that shows through walls --
-- the point of a bounty is that everybody can find you. The price comes from the "Bounty"
-- attribute BountyService sets, so the tag and the payout can never disagree.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local Bounties = {}
Bounties.__index = Bounties

local RED = Color3.fromRGB(236, 44, 52)
local GOLD = Color3.fromRGB(255, 196, 40)

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function Bounties.new(screen: GuiObject, playerGui: Instance, toast: any)
	local self = setmetatable({}, Bounties)
	self._toast = toast
	self._gui = playerGui
	self._hidden = false
	self._tags = {} :: { [Player]: { gui: BillboardGui, amount: TextLabel, shown: number } }

	-- Your own price, under the cash bar while you are WANTED.
	local badge = Instance.new("Frame")
	badge.Name = "WantedBadge"
	badge.AnchorPoint = Vector2.new(0.5, 0)
	badge.Position = UDim2.new(0.5, 0, 0, 184)
	badge.Size = UDim2.fromOffset(250, 34)
	badge.BackgroundColor3 = RED
	badge.BorderSizePixel = 0
	badge.Visible = false
	badge.Parent = screen
	Components.Corner(badge, 17)
	Components.Stroke(badge, Theme.Colour.Outline, 3)
	Components.Gradient(badge)
	local label = Components.Label(badge, {
		text = "",
		face = Theme.Face.HeavyItalic,
		size = 22,
		align = Enum.TextXAlignment.Center,
		outline = 2.5,
	})
	label.Size = UDim2.fromScale(1, 1)
	local scale = Instance.new("UIScale")
	scale.Parent = badge
	TweenService:Create(scale, TweenInfo.new(0.6, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Scale = 1.06 }):Play()
	self._badge, self._badgeLabel = badge, label

	local accumulator = 0
	self._connection = RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.25 then
			return
		end
		accumulator = 0
		self:_refresh()
	end)
	return self
end

function Bounties:_tag(player: Player, head: BasePart)
	local gui = Instance.new("BillboardGui")
	gui.Name = "WantedTag"
	gui.Adornee = head
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 600
	gui.Size = UDim2.fromOffset(150, 52)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 3.4, 0)
	gui.ResetOnSpawn = false
	gui.Parent = self._gui

	local pill = Instance.new("Frame")
	pill.AnchorPoint = Vector2.new(0.5, 0)
	pill.Position = UDim2.new(0.5, 0, 0, 0)
	pill.Size = UDim2.fromOffset(110, 26)
	pill.BackgroundColor3 = RED
	pill.BorderSizePixel = 0
	pill.Parent = gui
	Components.Corner(pill, 13)
	Components.Stroke(pill, Theme.Colour.Outline, 2.5)
	local title = Components.Label(pill, {
		text = "🎯 WANTED",
		face = Theme.Face.HeavyItalic,
		size = 17,
		align = Enum.TextXAlignment.Center,
		outline = 2,
	})
	title.Size = UDim2.fromScale(1, 1)
	local amount = Components.Label(gui, {
		text = "",
		font = Theme.Font.Display,
		size = 18,
		colour = GOLD,
		align = Enum.TextXAlignment.Center,
		outline = 2.2,
	})
	amount.Position = UDim2.fromOffset(0, 28)
	amount.Size = UDim2.new(1, 0, 0, 22)
	self._tags[player] = { gui = gui, amount = amount, shown = 0 }
end

function Bounties:_refresh()
	local me = Players.LocalPlayer
	for _, player in ipairs(Players:GetPlayers()) do
		local price = tonumber(player:GetAttribute("Bounty")) or 0
		local character = player.Character
		local head = character and character:FindFirstChild("Head")
		local entry = self._tags[player]
		if player ~= me and price > 0 and head and head:IsA("BasePart") then
			if entry and entry.gui.Adornee ~= head then
				entry.gui:Destroy()
				self._tags[player] = nil
				entry = nil
			end
			if not entry then
				self:_tag(player, head)
				entry = self._tags[player]
			end
			if entry and entry.shown ~= price then
				entry.shown = price
				entry.amount.Text = "$" .. commas(price)
			end
		elseif entry then
			entry.gui:Destroy()
			self._tags[player] = nil
		end
	end
	for player, entry in pairs(self._tags) do
		if not player.Parent then
			entry.gui:Destroy()
			self._tags[player] = nil
		end
	end

	local mine = tonumber(me:GetAttribute("Bounty")) or 0
	self._badge.Visible = mine > 0 and not self._hidden and me:GetAttribute("DuelState") ~= "duel"
	if mine > 0 then
		self._badgeLabel.Text = "🎯 WANTED  $" .. commas(mine)
	end
end

--- Handle one BountyEvent from the server.
function Bounties:Handle(kind: string, data: any)
	if type(data) ~= "table" then
		return
	end
	local me = Players.LocalPlayer
	if kind == "streak" then
		local subtitle = string.format("%d KILLS WITHOUT DYING", tonumber(data.streak) or 0)
		if data.amount then
			subtitle ..= string.format("  ·  $%s ON YOUR HEAD", commas(tonumber(data.amount) or 0))
		end
		self._toast:Banner({ title = tostring(data.call or "STREAK"), subtitle = subtitle,
			colour = data.amount and RED or GOLD, sound = "Slam" })
	elseif kind == "wanted" then
		if data.userId ~= me.UserId then
			self._toast:Push({ title = tostring(data.name) .. " is WANTED",
				text = string.format("$%s for whoever takes them down", commas(tonumber(data.amount) or 0)),
				icon = "🎯", colour = RED, duration = 5 })
		end
	elseif kind == "claimed" then
		if data.killerId == me.UserId then
			self._toast:Banner({ title = "BOUNTY CLAIMED",
				subtitle = string.format("%s  ·  +$%s", string.upper(tostring(data.victim)), commas(tonumber(data.amount) or 0)),
				colour = GOLD, sound = "Ring" })
		elseif data.victimId == me.UserId then
			self._toast:Push({ title = "Your bounty was claimed", text = tostring(data.killer) .. " took $"
				.. commas(tonumber(data.amount) or 0), icon = "💀", colour = RED })
		else
			self._toast:Push({ title = tostring(data.killer) .. " claimed a bounty",
				text = string.format("%s  ·  $%s", tostring(data.victim), commas(tonumber(data.amount) or 0)),
				icon = "🎯", colour = GOLD })
		end
	end
end

function Bounties:SetVisible(visible: boolean)
	self._hidden = not visible
	if not visible then
		self._badge.Visible = false
	end
end

return Bounties
