--!strict
-- World events on the HUD: the supply drop's banner, its marker, and who got to it.
--
-- The marker is a billboard pinned over the landing spot that shows through walls, with the
-- distance to it and -- while the crate is still in the air -- how long until it lands. It is
-- hidden while you are in a duel (the arenas are in the sky; a marker far below is noise).
--
-- SupplyDropService tells every client what is happening; this only draws it.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)

local WorldEvents = {}
WorldEvents.__index = WorldEvents

local CYAN = Color3.fromRGB(90, 220, 255)
local GOLD = Color3.fromRGB(255, 196, 60)

type Marker = {
	anchor: BasePart,
	gui: BillboardGui,
	distance: TextLabel,
	status: TextLabel,
	landsAt: number?,
	golden: boolean,
}

local function commas(n: number): string
	local s = tostring(math.floor(n))
	local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (out:gsub("^,", ""))
end

function WorldEvents.new(toast: any, playerGui: Instance)
	local self = setmetatable({}, WorldEvents)
	self._toast = toast
	self._gui = playerGui
	self._markers = {} :: { [number]: Marker }

	local accumulator = 0
	self._connection = RunService.Heartbeat:Connect(function(dt)
		accumulator += dt
		if accumulator < 0.1 then
			return
		end
		accumulator = 0
		self:_update()
	end)
	return self
end

function WorldEvents:_marker(id: number, position: Vector3, golden: boolean): Marker
	local existing = self._markers[id]
	if existing then
		return existing
	end
	local colour = golden and GOLD or CYAN

	-- A client-only anchor: nothing else needs to see it, and it cannot be touched or shot.
	local anchor = Instance.new("Part")
	anchor.Name = "SupplyMarker"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position + Vector3.new(0, 7, 0))
	anchor.Parent = workspace.CurrentCamera or workspace

	local gui = Instance.new("BillboardGui")
	gui.Name = "SupplyMarker"
	gui.Adornee = anchor
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.Size = UDim2.fromOffset(130, 86)
	gui.MaxDistance = 100000
	gui.ResetOnSpawn = false
	gui.Parent = self._gui

	local box = Instance.new("Frame")
	box.Name = "Icon"
	box.AnchorPoint = Vector2.new(0.5, 0)
	box.Position = UDim2.new(0.5, 0, 0, 2)
	box.Size = UDim2.fromOffset(40, 40)
	box.BackgroundColor3 = colour
	box.BorderSizePixel = 0
	box.Rotation = 45
	box.Parent = gui
	Components.Corner(box, 8)
	Components.Stroke(box, Theme.Colour.Outline, 3)
	Components.Gradient(box)
	local glyph = Components.Icon(box, "📦", 22)
	glyph.AnchorPoint = Vector2.new(0.5, 0.5)
	glyph.Position = UDim2.fromScale(0.5, 0.5)
	glyph.Rotation = -45

	local distance = Components.Label(gui, {
		text = "",
		font = Theme.Font.Display,
		size = 18,
		align = Enum.TextXAlignment.Center,
		outline = 2.2,
	})
	distance.Position = UDim2.fromOffset(0, 46)
	distance.Size = UDim2.new(1, 0, 0, 20)

	local status = Components.Label(gui, {
		text = golden and "ELITE SUPPLY" or "SUPPLY",
		face = Theme.Face.Condensed,
		size = 14,
		colour = colour,
		align = Enum.TextXAlignment.Center,
		outline = 1.8,
	})
	status.Position = UDim2.fromOffset(0, 66)
	status.Size = UDim2.new(1, 0, 0, 16)

	-- A slow pulse so it reads as live.
	local pulse = TweenService:Create(box, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Size = UDim2.fromOffset(46, 46) })
	pulse:Play()

	local marker: Marker = {
		anchor = anchor, gui = gui, distance = distance, status = status, landsAt = nil, golden = golden,
	}
	self._markers[id] = marker
	return marker
end

function WorldEvents:_remove(id: number)
	local marker = self._markers[id]
	if marker then
		marker.gui:Destroy()
		marker.anchor:Destroy()
		self._markers[id] = nil
	end
end

function WorldEvents:_update()
	local player = Players.LocalPlayer
	local camera = workspace.CurrentCamera
	local inDuel = player:GetAttribute("DuelState") == "duel"
	local from: Vector3? = nil
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and root:IsA("BasePart") then
		from = root.Position
	elseif camera then
		from = camera.CFrame.Position
	end
	local skyHigh = from ~= nil and from.Y > 1500
	for _, marker in pairs(self._markers) do
		marker.gui.Enabled = not inDuel and not skyHigh
		if from then
			local metres = (marker.anchor.Position - from).Magnitude
			marker.distance.Text = commas(metres) .. "m"
		end
		if marker.landsAt then
			local left = math.max(0, math.ceil(marker.landsAt - os.clock()))
			marker.status.Text = left > 0 and ("LANDS IN " .. left .. "s") or (marker.golden and "ELITE SUPPLY" or "SUPPLY")
		end
	end
end

--- Handle one SupplyEvent from the server.
function WorldEvents:Handle(kind: string, data: any)
	if type(data) ~= "table" then
		return
	end
	local id = tonumber(data.id) or 0
	local golden = data.golden == true
	local colour = golden and GOLD or CYAN
	if kind == "inbound" and typeof(data.position) == "Vector3" then
		local marker = self:_marker(id, data.position, golden)
		marker.landsAt = os.clock() + (tonumber(data.landsIn) or 15)
		self._toast:Banner({
			title = golden and "ELITE SUPPLY DROP INBOUND" or "SUPPLY DROP INBOUND",
			subtitle = string.format("%s  ·  FIRST TO OPEN IT KEEPS IT", tostring(data.zone or "SOMEWHERE")),
			colour = colour,
			sound = "Whoosh",
			duration = 3.6,
		})
	elseif kind == "landed" and typeof(data.position) == "Vector3" then
		local marker = self:_marker(id, data.position, golden)
		marker.landsAt = nil
		marker.status.Text = golden and "ELITE SUPPLY" or "SUPPLY"
		if data.late ~= true then
			self._toast:Push({ title = "Supply drop has landed", text = "Hold E on the crate to open it", icon = "📦",
				colour = colour })
		end
	elseif kind == "opened" then
		self:_remove(id)
		if data.by ~= Players.LocalPlayer.DisplayName then
			self._toast:Push({ title = tostring(data.by) .. " looted the supply drop", icon = "📦", colour = colour })
		end
	elseif kind == "gone" then
		self:_remove(id)
	elseif kind == "loot" then
		local parts = { "+$" .. commas(tonumber(data.coins) or 0), "+" .. commas(tonumber(data.xp) or 0) .. " XP" }
		if tonumber(data.crystals) and data.crystals > 0 then
			table.insert(parts, "+" .. tostring(data.crystals) .. " 💎")
		end
		self._toast:Banner({
			title = golden and "ELITE SUPPLY LOOTED" or "SUPPLY LOOTED",
			subtitle = table.concat(parts, "     "),
			colour = GOLD,
			sound = "Ring",
		})
	end
end

function WorldEvents:Destroy()
	self._connection:Disconnect()
	for id in pairs(self._markers) do
		self:_remove(id)
	end
end

return WorldEvents
