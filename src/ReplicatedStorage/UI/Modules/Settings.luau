--!strict
-- The settings panel: how loud things are, how much the camera shakes, how wide you see.
--
-- Every change applies the instant a slider moves -- the sound mix, the camera, the view --
-- and is saved to the profile shortly after the last change (SettingsService), so it follows
-- the player to their next session. The saved values are loaded and applied on join whether
-- or not the panel is ever opened.
--
-- All of these are local by nature: a SoundGroup volume set on the client changes this
-- player's mix and nobody else's, and the camera is theirs alone.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local UserInputService = game:GetService("UserInputService")

local Theme = require(script.Parent.Theme)
local Components = require(script.Parent.Components)
local Menu = require(script.Parent.Menu)
local SettingsConfig = require(ReplicatedStorage:WaitForChild("SettingsConfig"))

local Settings = {}
Settings.__index = Settings

local WHITE = Color3.new(1, 1, 1)
local ROW_HEIGHT = 58
local SAVE_DELAY = 0.8

-- ----------------------------------------------------------------- apply --

local BUS = { Master = "Master", Weapons = "Weapons", World = "World", Interface = "UI" }

local function bus(name: string): SoundGroup?
	local master = SoundService:FindFirstChild("Master")
	if not master then
		return nil
	end
	if name == "Master" then
		return master :: SoundGroup
	end
	local g = master:FindFirstChild(name)
	return (g and g:IsA("SoundGroup")) and g or nil
end

--- Put one setting into effect.
local function apply(id: string, value: number)
	if BUS[id] then
		local g = bus(BUS[id])
		if g then
			g.Volume = value
		end
	elseif id == "Shake" then
		local ok, ViewKick = pcall(function()
			return require(ReplicatedStorage:WaitForChild("ViewKick")) :: any
		end)
		if ok then
			ViewKick.Intensity = value
		end
	elseif id == "Fov" then
		Players.LocalPlayer:SetAttribute("FovSetting", value)
	end
end

local function format(setting: SettingsConfig.Setting, value: number): string
	if setting.format == "degrees" then
		return string.format("%d°", math.floor(value + 0.5))
	end
	return string.format("%d%%", math.floor(value * 100 + 0.5))
end

-- ------------------------------------------------------------------- row --

local function row(self, parent: GuiObject, setting: SettingsConfig.Setting, order: number)
	local frame = Instance.new("Frame")
	frame.Name = setting.id
	frame.BackgroundColor3 = Theme.Colour.PanelRaised
	frame.Size = UDim2.new(1, 0, 0, ROW_HEIGHT)
	frame.LayoutOrder = order
	frame.Parent = parent
	Components.Corner(frame, Theme.Radius.Small)
	Components.Stroke(frame, Theme.Colour.Outline, 1.5)
	Components.Gradient(frame, WHITE, Color3.fromRGB(175, 175, 185))

	local label = Components.Label(frame, {
		text = setting.label,
		face = Theme.Face.Condensed,
		size = 20,
		outline = 2,
	})
	label.Position = UDim2.fromOffset(16, 6)
	label.Size = UDim2.fromOffset(240, 24)
	local hint = Components.Label(frame, {
		text = setting.hint,
		font = Theme.Font.Bold,
		size = 13,
		colour = Theme.Colour.TextMuted,
		outline = false,
	})
	hint.Position = UDim2.fromOffset(16, 32)
	hint.Size = UDim2.fromOffset(250, 16)

	local minus = Components.Button(frame, {
		name = "Minus",
		text = "-",
		textSize = 22,
		size = UDim2.fromOffset(34, 34),
		anchor = Vector2.new(0, 0.5),
		position = UDim2.new(0, 270, 0.5, 0),
		onActivated = function()
			self:Set(setting.id, (self._values[setting.id] or setting.default) - setting.step * (setting.format == "degrees" and 5 or 2))
		end,
	})
	minus.instance.Name = "Minus"

	-- The track: a meter you can grab anywhere and drag.
	local track = Instance.new("TextButton")
	track.Name = "Track"
	track.AutoButtonColor = false
	track.Text = ""
	track.BackgroundTransparency = 1
	track.AnchorPoint = Vector2.new(0, 0.5)
	track.Position = UDim2.new(0, 314, 0.5, 0)
	track.Size = UDim2.fromOffset(250, 30)
	track.Parent = frame
	local barHolder = Instance.new("Frame")
	barHolder.BackgroundTransparency = 1
	barHolder.AnchorPoint = Vector2.new(0, 0.5)
	barHolder.Position = UDim2.fromScale(0, 0.5)
	barHolder.Size = UDim2.new(1, 0, 0, 14)
	barHolder.Parent = track
	local bar = Components.Bar(barHolder, { height = 14, colour = Theme.Colour.Accent })
	local knob = Instance.new("Frame")
	knob.Name = "Knob"
	knob.BackgroundColor3 = WHITE
	knob.AnchorPoint = Vector2.new(0.5, 0.5)
	knob.Position = UDim2.fromScale(0, 0.5)
	knob.Size = UDim2.fromOffset(24, 24)
	knob.ZIndex = 3
	knob.Parent = track
	Components.Corner(knob, 12)
	Components.Stroke(knob, Theme.Colour.Outline, 2.5)
	Components.Gradient(knob, WHITE, Color3.fromRGB(190, 190, 200)).Rotation = 90

	local plus = Components.Button(frame, {
		name = "Plus",
		text = "+",
		textSize = 22,
		size = UDim2.fromOffset(34, 34),
		anchor = Vector2.new(0, 0.5),
		position = UDim2.new(0, 574, 0.5, 0),
		onActivated = function()
			self:Set(setting.id, (self._values[setting.id] or setting.default) + setting.step * (setting.format == "degrees" and 5 or 2))
		end,
	})
	plus.instance.Name = "Plus"

	local value = Components.Label(frame, {
		text = "",
		font = Theme.Font.Display,
		size = 22,
		align = Enum.TextXAlignment.Right,
		outline = 2,
	})
	value.AnchorPoint = Vector2.new(1, 0.5)
	value.Position = UDim2.new(1, -16, 0.5, 0)
	value.Size = UDim2.fromOffset(70, 26)

	local dragging = false
	local function fromInput(input: InputObject)
		local width = track.AbsoluteSize.X
		if width <= 0 then
			return
		end
		local fraction = math.clamp((input.Position.X - track.AbsolutePosition.X) / width, 0, 1)
		self:Set(setting.id, setting.min + (setting.max - setting.min) * fraction)
	end
	track.InputBegan:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = true
			fromInput(input)
		end
	end)
	UserInputService.InputChanged:Connect(function(input: InputObject)
		if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
			fromInput(input)
		end
	end)
	UserInputService.InputEnded:Connect(function(input: InputObject)
		if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
			dragging = false
		end
	end)

	self._rows[setting.id] = { bar = bar, knob = knob, value = value, setting = setting }
end

-- ------------------------------------------------------------------- api --

function Settings.new(parent: Instance, remotes)
	local self = setmetatable({}, Settings)
	self._remotes = remotes
	self._rows = {}
	self._values = SettingsConfig.Resolve(nil)
	self._saveToken = nil

	local menu = Menu.new(parent, {
		id = "Settings",
		title = "Settings",
		subtitle = "Sound, camera and view -- saved to your profile",
		icon = "⚙️",
		size = UDim2.fromOffset(760, 600),
	})
	self._menu = menu

	local list = Instance.new("Frame")
	list.Name = "Rows"
	list.BackgroundTransparency = 1
	list.Size = UDim2.new(1, 0, 1, -60)
	list.Parent = menu.content
	Components.List(list, Enum.FillDirection.Vertical, 6)

	local order = 0
	local lastGroup = nil
	for _, setting in ipairs(SettingsConfig.Schema) do
		if setting.group ~= lastGroup then
			lastGroup = setting.group
			order += 1
			local header = Components.Label(list, {
				text = setting.group,
				face = Theme.Face.HeavyItalic,
				size = 20,
				colour = Theme.Colour.Level,
				outline = 2,
			})
			header.LayoutOrder = order
			header.Size = UDim2.new(1, 0, 0, 26)
		end
		order += 1
		row(self, list, setting, order)
	end

	Components.Button(menu.content, {
		name = "Defaults",
		text = "RESET TO DEFAULTS",
		textSize = 18,
		size = UDim2.fromOffset(240, 44),
		anchor = Vector2.new(0.5, 1),
		position = UDim2.fromScale(0.5, 1),
		onActivated = function()
			for _, setting in ipairs(SettingsConfig.Schema) do
				self:Set(setting.id, setting.default)
			end
		end,
	})

	self:_draw()
	for id, value in pairs(self._values) do
		apply(id, value)
	end
	return self
end

function Settings:_draw()
	for id, r in pairs(self._rows) do
		local setting = r.setting
		local value = self._values[id] or setting.default
		local fraction = (value - setting.min) / math.max(setting.max - setting.min, 1e-6)
		r.bar:SetFraction(fraction, false)
		r.knob.Position = UDim2.fromScale(fraction, 0.5)
		r.value.Text = format(setting, value)
	end
end

--- Change one setting: apply it now, redraw, and save once the player stops fiddling.
function Settings:Set(id: string, raw: number)
	local clean = SettingsConfig.Clean(id, raw)
	if clean == nil or clean == self._values[id] then
		return
	end
	self._values[id] = clean
	apply(id, clean)
	self:_draw()

	local token = {}
	self._saveToken = token
	task.delay(SAVE_DELAY, function()
		if self._saveToken ~= token then
			return
		end
		pcall(function()
			self._remotes.settingsAction:InvokeServer("set", self._values)
		end)
	end)
end

--- Fetch the saved settings and put them into effect. Called once on join.
function Settings:Load()
	task.spawn(function()
		local ok, saved = pcall(function()
			return self._remotes.settingsAction:InvokeServer("get")
		end)
		if ok and type(saved) == "table" then
			self._values = SettingsConfig.Resolve(saved)
			self:_draw()
		end
		-- The mix buses are made by the server; wait for them before applying volumes.
		SoundService:WaitForChild("Master", 20)
		for id, value in pairs(self._values) do
			apply(id, value)
		end
	end)
end

function Settings:Open()
	self._menu:Open()
end
function Settings:Close()
	self._menu:Close()
end
function Settings:Toggle()
	self._menu:Toggle()
end
function Settings:IsOpen(): boolean
	return self._menu:IsOpen()
end

return Settings
