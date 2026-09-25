--!nocheck
-- A small stand-in for the Roblox client runtime, enough to run the game's interface scripts
-- under Lune and catch what would break them in Studio.
--
-- Instances are plain tables backed by Roblox's own reflection database, so every property a
-- script reads or writes is checked the way the engine checks it: an unknown member, a
-- read-only property or a value of the wrong type is an error here exactly as it is there.
-- Events, services, tweens, remotes and a local player are simulated just far enough for
-- UI code to build, open, close and react.
--
-- Everything that goes wrong is collected in Runtime.errors -- a script erroring at the top
-- level, a handler erroring when a signal fires, and a WaitForChild that would yield forever.

local roblox = require("@lune/roblox")
local task = require("@lune/task")
local luau = require("@lune/luau")

local db = roblox.getReflectionDatabase()
local nativeTypeof = typeof

local Runtime = {}
Runtime.errors = {} :: { string }
Runtime.log = {} :: { string }
Runtime.quiet = false

local function report(kind: string, message: string)
	local line = ("[%s] %s"):format(kind, message)
	table.insert(Runtime.errors, line)
	if not Runtime.quiet then
		print("\27[31m" .. line .. "\27[0m")
	end
end
Runtime.report = report

-- ------------------------------------------------------------ reflection --

local classCache = {}
local function classOf(name: string)
	local cached = classCache[name]
	if cached ~= nil then
		return cached or nil
	end
	local ok, c = pcall(function()
		return db:GetClass(name)
	end)
	classCache[name] = (ok and c) or false
	return ok and c or nil
end

local function isA(className: string, target: string): boolean
	local name: string? = className
	while name do
		if name == target then
			return true
		end
		local c = classOf(name)
		name = c and c.Superclass or nil
	end
	return false
end

local propCache = {}
local function findProp(className: string, prop: string)
	local key = className .. "." .. prop
	local cached = propCache[key]
	if cached ~= nil then
		return cached or nil
	end
	local name: string? = className
	while name do
		local c = classOf(name)
		if not c then
			break
		end
		local p = c.Properties[prop]
		if p and p.Scriptability ~= "None" then
			propCache[key] = p
			return p
		end
		name = c.Superclass
	end
	propCache[key] = false
	return nil
end

local defaultCache = {}
local function defaultOf(className: string, prop: string)
	local key = className .. "." .. prop
	local cached = defaultCache[key]
	if cached ~= nil then
		return cached.value
	end
	local value = nil
	local name: string? = className
	while name do
		local c = classOf(name)
		if not c then
			break
		end
		local dp = c.DefaultProperties
		if dp and dp[prop] ~= nil then
			value = dp[prop]
			break
		end
		name = c.Superclass
	end
	defaultCache[key] = { value = value }
	return value
end

-- --------------------------------------------------------------- signals --

local SIGNAL = {}
SIGNAL.__index = SIGNAL
local CONNECTION = {}
CONNECTION.__index = CONNECTION
local mockKinds = setmetatable({}, { __mode = "k" })     -- table -> typeof name

local function runHandler(label: string, fn, ...)
	local args = table.pack(...)
	task.spawn(function()
		local ok, err = xpcall(function()
			return fn(table.unpack(args, 1, args.n))
		end, function(e)
			return debug.traceback(tostring(e), 2)
		end)
		if not ok then
			report("handler " .. label, tostring(err))
		end
	end)
end

local function newSignal(label: string)
	local s = setmetatable({ _label = label, _handlers = {}, _waiting = {} }, SIGNAL)
	mockKinds[s] = "RBXScriptSignal"
	return s
end
Runtime.newSignal = newSignal

function SIGNAL:Connect(fn)
	assert(type(fn) == "function", "Attempt to connect failed: Passed value is not a function")
	local c = setmetatable({ Connected = true, _signal = self, _fn = fn }, CONNECTION)
	mockKinds[c] = "RBXScriptConnection"
	table.insert(self._handlers, c)
	return c
end
SIGNAL.ConnectParallel = SIGNAL.Connect

function SIGNAL:Once(fn)
	local c
	c = self:Connect(function(...)
		c:Disconnect()
		fn(...)
	end)
	return c
end

function SIGNAL:Wait()
	local thread = coroutine.running()
	table.insert(self._waiting, thread)
	return coroutine.yield()
end

function SIGNAL:Fire(...)
	for _, c in ipairs(table.clone(self._handlers)) do
		if c.Connected then
			runHandler(self._label, c._fn, ...)
		end
	end
	local waiting = self._waiting
	self._waiting = {}
	for _, thread in ipairs(waiting) do
		task.spawn(thread, ...)
	end
end

function CONNECTION:Disconnect()
	if not self.Connected then
		return
	end
	self.Connected = false
	local list = self._signal._handlers
	for i, c in ipairs(list) do
		if c == self then
			table.remove(list, i)
			break
		end
	end
end

-- ------------------------------------------------------------- instances --

local state = setmetatable({}, { __mode = "k" })   -- instance -> internal record
local INSTANCE = {}                                -- metatable
local Methods = {}                                 -- every instance
local ClassMethods = {}                            -- per class (walked up the chain)
local Computed = {}                                -- read-only computed properties

local EVENTS = {}
for _, name in ipairs({
	"Changed", "ChildAdded", "ChildRemoved", "DescendantAdded", "DescendantRemoving", "AncestryChanged",
	"Destroying", "AttributeChanged",
	-- gui
	"Activated", "MouseButton1Click", "MouseButton1Down", "MouseButton1Up", "MouseButton2Click",
	"MouseButton2Down", "MouseButton2Up", "MouseEnter", "MouseLeave", "MouseMoved", "MouseWheelForward",
	"MouseWheelBackward", "InputBegan", "InputChanged", "InputEnded", "TouchTap", "TouchLongPress",
	"TouchPan", "TouchPinch", "TouchSwipe", "TouchRotate", "SelectionGained", "SelectionLost",
	"FocusLost", "Focused", "ReturnPressedFromOnScreenKeyboard",
	-- humanoid / character / parts
	"Died", "HealthChanged", "StateChanged", "Running", "Jumping", "FreeFalling", "MoveToFinished",
	"AnimationPlayed", "Touched", "TouchEnded", "Equipped", "Unequipped", "Deactivated",
	-- players
	"CharacterAdded", "CharacterRemoving", "CharacterAppearanceLoaded", "PlayerAdded", "PlayerRemoving",
	"Idled", "Chatted",
	-- remotes / bindables / tweens / sounds / animation
	"OnClientEvent", "OnServerEvent", "Event", "Completed", "Played", "Ended", "Stopped", "Loaded",
	"Paused", "Resumed", "DidLoop", "KeyframeReached", "Triggered", "TriggerEnded", "PromptShown",
	"PromptHidden", "PromptButtonHoldBegan", "PromptButtonHoldEnded",
	-- services
	"Heartbeat", "RenderStepped", "Stepped", "PreRender", "PreSimulation", "PostSimulation",
	"InputBegan", "LastInputTypeChanged", "WindowFocused", "WindowFocusReleased", "TextBoxFocused",
	"TextBoxFocusReleased", "JumpRequest", "MenuOpened", "MenuClosed", "PromptProductPurchaseFinished",
	"PromptGamePassPurchaseFinished", "PromptPurchaseFinished", "Close", "PromptTriggered",
	"PromptTriggerEnded", "GraphicsQualityChangeRequest", "UserCFrameChanged", "GamepadConnected",
	"GamepadDisconnected", "TouchStarted", "TouchEnded", "TouchMoved", "PointerAction", "Button1Down",
	"Button1Up", "CharacterAdded", "ReturnPressedFromOnScreenKeyboard", "OnInvoke", "PlaybackEnded",
	"MessageReceived", "SendingMessage", "ChildAdded",
}) do
	EVENTS[name] = true
end

local function isInstance(v): boolean
	return type(v) == "table" and state[v] ~= nil
end
Runtime.isInstance = isInstance

local function fullName(inst): string
	local st = state[inst]
	if not st then
		return "?"
	end
	local parts = {}
	local cur = inst
	while cur do
		local s = state[cur]
		if not s or s.class == "DataModel" then
			break
		end
		table.insert(parts, 1, s.props.Name or s.class)
		cur = s.parent
	end
	return table.concat(parts, ".")
end

local function signalFor(inst, name: string)
	local st = state[inst]
	local sig = st.signals[name]
	if not sig then
		sig = newSignal(fullName(inst) .. "." .. name)
		st.signals[name] = sig
	end
	return sig
end

local function fire(inst, name: string, ...)
	local st = state[inst]
	if st and st.signals[name] then
		st.signals[name]:Fire(...)
	end
end

local function propChanged(inst, prop: string)
	local st = state[inst]
	fire(inst, "Changed", prop)
	if prop == "Health" and st.class == "Humanoid" then
		fire(inst, "HealthChanged", st.props.Health)
	end
	local sig = st.propSignals[prop]
	if sig then
		sig:Fire()
	end
end

local function newInstance(className: string, source)
	local self = setmetatable({}, INSTANCE)
	state[self] = {
		class = className,
		props = {},
		children = {},
		parent = nil,
		attrs = {},
		signals = {},
		propSignals = {},
		attrSignals = {},
		source = source,
		destroyed = false,
		locked = false,
	}
	return self
end

local function classMethod(className: string, key: string)
	local name: string? = className
	while name do
		local m = ClassMethods[name]
		if m and m[key] then
			return m[key]
		end
		local c = classOf(name)
		name = c and c.Superclass or nil
	end
	return nil
end

-- Does `value` fit a property of this datatype?
local function fits(datatype: string, value): boolean
	local t = nativeTypeof(value)
	if isInstance(value) then
		t = "Instance"
	end
	if datatype == "Bool" then
		return t == "boolean"
	elseif datatype:sub(1, 5) == "Float" or datatype:sub(1, 3) == "Int" then
		return t == "number"
	elseif datatype == "String" or datatype == "ContentId" or datatype == "BinaryString" then
		return t == "string"
	elseif datatype == "Content" then
		return t == "string" or t == "Content"
	elseif datatype:sub(1, 5) == "Enum." then
		if t == "number" or t == "string" then
			return true
		end
		return t == "EnumItem" and tostring(value.EnumType) == datatype
	elseif datatype == "Ref" then
		return value == nil or t == "Instance"
	elseif datatype == "OptionalCFrame" then
		return value == nil or t == "CFrame"
	end
	return t == datatype
end

local function readProp(self, key: string)
	local st = state[self]
	local value = st.props[key]
	if value ~= nil then
		return value
	end
	if st.cleared and st.cleared[key] then
		return nil
	end
	local compute = Computed[key]
	if compute then
		return compute(self)
	end
	if st.source then
		local ok, v = pcall(function()
			return st.source[key]
		end)
		if ok and v ~= nil then
			if nativeTypeof(v) == "Instance" then
				return nil       -- references into the source place are not followed
			end
			return v
		end
	end
	return defaultOf(st.class, key)
end

-- Callbacks are not properties in the reflection database, but server code assigns them
-- (RemoteFunction.OnServerInvoke) and suites load server modules, so they are held here.
local CALLBACKS = { OnServerInvoke = true, OnClientInvoke = true, OnInvoke = true }

INSTANCE.__index = function(self, key)
	local st = state[self]
	if key == "ClassName" then
		return st.class
	elseif key == "Parent" then
		return st.parent
	elseif key == "Name" then
		return st.props.Name or (st.source and st.source.Name) or st.class
	end
	if CALLBACKS[key] then
		return st.props[key]
	end
	local m = Methods[key] or classMethod(st.class, key)
	if m then
		return m
	end
	-- A part's Position is its CFrame's, as in the engine.
	if key == "Position" and isA(st.class, "BasePart") then
		local cf = readProp(self, "CFrame")
		return cf and cf.Position or roblox.Vector3.zero
	end
	if findProp(st.class, key) or Computed[key] then
		return readProp(self, key)
	end
	for _, child in ipairs(st.children) do
		if child.Name == key then
			return child
		end
	end
	if EVENTS[key] then
		return signalFor(self, key)
	end
	error(("%s is not a valid member of %s \"%s\""):format(tostring(key), st.class, fullName(self)), 2)
end

local function setParent(self, parent)
	local st = state[self]
	if st.locked then
		error(("The Parent property of %s is locked, current parent: NULL, new parent %s"):format(
			fullName(self), parent and parent.Name or "NULL"), 3)
	end
	if parent ~= nil and not isInstance(parent) then
		error("Unable to assign property Parent. Instance expected, got " .. nativeTypeof(parent), 3)
	end
	local cur = parent
	while cur do
		if cur == self then
			error("Attempt to set " .. fullName(self) .. " as its own ancestor", 3)
		end
		cur = state[cur].parent
	end
	local old = st.parent
	if old == parent then
		return
	end
	if old then
		local list = state[old].children
		for i, c in ipairs(list) do
			if c == self then
				table.remove(list, i)
				break
			end
		end
		fire(old, "ChildRemoved", self)
	end
	st.parent = parent
	if parent then
		table.insert(state[parent].children, self)
		fire(parent, "ChildAdded", self)
		local up = parent
		while up do
			fire(up, "DescendantAdded", self)
			up = state[up].parent
		end
	end
	fire(self, "AncestryChanged", self, parent)
	propChanged(self, "Parent")
end

INSTANCE.__newindex = function(self, key, value)
	local st = state[self]
	if CALLBACKS[key] then
		if value ~= nil and type(value) ~= "function" then
			error(("Unable to assign %s: a function is expected"):format(key), 2)
		end
		st.props[key] = value
		return
	end
	if key == "Parent" then
		setParent(self, value)
		return
	end
	if key == "Name" then
		if type(value) ~= "string" and type(value) ~= "number" then
			error("Unable to assign property Name. string expected, got " .. nativeTypeof(value), 2)
		end
		st.props.Name = tostring(value)
		propChanged(self, "Name")
		return
	end
	if key == "Position" and isA(st.class, "BasePart") then
		if nativeTypeof(value) ~= "Vector3" then
			error("Unable to assign property Position. Vector3 expected, got " .. nativeTypeof(value), 2)
		end
		local cf = readProp(self, "CFrame") or roblox.CFrame.new()
		st.props.CFrame = roblox.CFrame.new(value) * (cf - cf.Position)
		propChanged(self, "CFrame")
		propChanged(self, "Position")
		return
	end
	local p = findProp(st.class, key)
	if not p then
		error(("%s is not a valid member of %s \"%s\""):format(tostring(key), st.class, fullName(self)), 2)
	end
	if p.Scriptability == "Read" or table.find(p.Tags, "ReadOnly") then
		error(("Unable to assign property %s. Property is read only"):format(key), 2)
	end
	if value == nil then
		if p.Datatype ~= "Ref" and p.Datatype ~= "OptionalCFrame" then
			error(("Unable to assign property %s. %s expected, got nil"):format(key, p.Datatype), 2)
		end
		st.props[key] = nil
		st.cleared = st.cleared or {}
		st.cleared[key] = true
	else
		if not fits(p.Datatype, value) then
			error(("Unable to assign property %s. %s expected, got %s"):format(key, p.Datatype,
				isInstance(value) and "Instance" or nativeTypeof(value)), 2)
		end
		if st.cleared then
			st.cleared[key] = nil
		end
		-- Enum props accept names and numbers; store the item.
		if p.Datatype:sub(1, 5) == "Enum." and nativeTypeof(value) ~= "EnumItem" then
			local enum = roblox.Enum[p.Datatype:sub(6)]
			for _, item in ipairs(enum:GetEnumItems()) do
				if item.Name == value or item.Value == value then
					value = item
					break
				end
			end
		end
		st.props[key] = value
	end
	propChanged(self, key)
end

INSTANCE.__tostring = function(self)
	return self.Name
end

-- -------------------------------------------------------------- methods --

function Methods:IsA(className: string): boolean
	return isA(state[self].class, className)
end

function Methods:GetChildren()
	return table.clone(state[self].children)
end

function Methods:GetDescendants()
	local out = {}
	local function walk(inst)
		for _, c in ipairs(state[inst].children) do
			table.insert(out, c)
			walk(c)
		end
	end
	walk(self)
	return out
end

function Methods:FindFirstChild(name: string, recursive: boolean?)
	for _, c in ipairs(state[self].children) do
		if c.Name == name then
			return c
		end
	end
	if recursive then
		for _, c in ipairs(state[self].children) do
			local found = c:FindFirstChild(name, true)
			if found then
				return found
			end
		end
	end
	return nil
end

function Methods:FindFirstChildOfClass(className: string)
	for _, c in ipairs(state[self].children) do
		if state[c].class == className then
			return c
		end
	end
	return nil
end

function Methods:FindFirstChildWhichIsA(className: string, recursive: boolean?)
	for _, c in ipairs(state[self].children) do
		if isA(state[c].class, className) then
			return c
		end
	end
	if recursive then
		for _, c in ipairs(state[self].children) do
			local found = c:FindFirstChildWhichIsA(className, true)
			if found then
				return found
			end
		end
	end
	return nil
end

function Methods:FindFirstAncestor(name: string)
	local cur = state[self].parent
	while cur do
		if cur.Name == name then
			return cur
		end
		cur = state[cur].parent
	end
	return nil
end

function Methods:FindFirstAncestorOfClass(className: string)
	local cur = state[self].parent
	while cur do
		if state[cur].class == className then
			return cur
		end
		cur = state[cur].parent
	end
	return nil
end

function Methods:FindFirstAncestorWhichIsA(className: string)
	local cur = state[self].parent
	while cur do
		if isA(state[cur].class, className) then
			return cur
		end
		cur = state[cur].parent
	end
	return nil
end

function Methods:IsDescendantOf(ancestor)
	local cur = state[self].parent
	while cur do
		if cur == ancestor then
			return true
		end
		cur = state[cur].parent
	end
	return false
end

function Methods:IsAncestorOf(descendant)
	return isInstance(descendant) and descendant:IsDescendantOf(self)
end

-- How long a WaitForChild with no timeout may wait here before it counts as an infinite yield.
Runtime.infiniteYieldAfter = 3

function Methods:WaitForChild(name: string, timeout: number?)
	local found = self:FindFirstChild(name)
	if found then
		return found
	end
	local limit = timeout or Runtime.infiniteYieldAfter
	local waited = 0
	while waited < limit do
		task.wait(0.05)
		waited += 0.05
		found = self:FindFirstChild(name)
		if found then
			return found
		end
		if timeout and timeout > 1000 and waited > Runtime.infiniteYieldAfter * 4 then
			return nil      -- a "wait forever" listener; it is not the thing under test
		end
	end
	if not timeout then
		report("infinite yield", ('Infinite yield possible on %s:WaitForChild("%s")\n%s'):format(
			fullName(self), name, debug.traceback("", 2)))
		-- Keep the thread parked, as Roblox would.
		while true do
			task.wait(60)
		end
	end
	return nil
end

function Methods:GetFullName()
	return fullName(self)
end

function Methods:ClearAllChildren()
	for _, c in ipairs(table.clone(state[self].children)) do
		c:Destroy()
	end
end

function Methods:Destroy()
	local st = state[self]
	if st.destroyed then
		return
	end
	fire(self, "Destroying")
	for _, c in ipairs(table.clone(st.children)) do
		c:Destroy()
	end
	if st.parent then
		setParent(self, nil)
	end
	st.destroyed = true
	st.locked = true
end
Methods.Remove = Methods.Destroy

function Methods:Clone()
	local st = state[self]
	if st.props.Archivable == false then
		return nil
	end
	local copy = newInstance(st.class, st.source)
	local cst = state[copy]
	for k, v in pairs(st.props) do
		cst.props[k] = v
	end
	if st.cleared then
		cst.cleared = table.clone(st.cleared)
	end
	for k, v in pairs(st.attrs) do
		cst.attrs[k] = v
	end
	cst.extra = st.extra and table.clone(st.extra) or nil
	for _, c in ipairs(st.children) do
		local cc = c:Clone()
		if cc then
			state[cc].parent = copy
			table.insert(cst.children, cc)
		end
	end
	return copy
end

function Methods:GetAttribute(name: string)
	local st = state[self]
	local v = st.attrs[name]
	if v == nil and st.source and not st.attrsCleared then
		local ok, sv = pcall(function()
			return st.source:GetAttribute(name)
		end)
		if ok then
			return sv
		end
	end
	return v
end

function Methods:SetAttribute(name: string, value)
	local st = state[self]
	local t = nativeTypeof(value)
	if value ~= nil and not ({ boolean = 1, number = 1, string = 1, Vector3 = 1, Vector2 = 1, Color3 = 1,
		UDim2 = 1, UDim = 1, CFrame = 1, BrickColor = 1, NumberRange = 1, NumberSequence = 1,
		ColorSequence = 1, Rect = 1, Font = 1, EnumItem = 1 })[t] then
		error(("SetAttribute: %s is not a supported attribute type"):format(t), 2)
	end
	local old = self:GetAttribute(name)
	st.attrs[name] = value
	if value == nil and st.source then
		st.attrsCleared = true
	end
	if old ~= value then
		fire(self, "AttributeChanged", name)
		local sig = st.attrSignals[name]
		if sig then
			sig:Fire()
		end
	end
end

function Methods:GetAttributes()
	local out = {}
	local st = state[self]
	if st.source then
		local ok, attrs = pcall(function()
			return st.source:GetAttributes()
		end)
		if ok then
			for k, v in pairs(attrs) do
				out[k] = v
			end
		end
	end
	for k, v in pairs(st.attrs) do
		out[k] = v
	end
	return out
end

function Methods:GetAttributeChangedSignal(name: string)
	local st = state[self]
	local sig = st.attrSignals[name]
	if not sig then
		sig = newSignal(fullName(self) .. "@" .. name)
		st.attrSignals[name] = sig
	end
	return sig
end

function Methods:GetPropertyChangedSignal(prop: string)
	local st = state[self]
	if not findProp(st.class, prop) and prop ~= "Parent" and prop ~= "Name" and not Computed[prop] then
		error(("%s is not a valid property name."):format(prop), 2)
	end
	local sig = st.propSignals[prop]
	if not sig then
		sig = newSignal(fullName(self) .. "." .. prop .. "Changed")
		st.propSignals[prop] = sig
	end
	return sig
end

function Methods:GetTags()
	return table.clone(state[self].tags or {})
end
function Methods:HasTag(tag: string)
	return table.find(state[self].tags or {}, tag) ~= nil
end
function Methods:AddTag(tag: string)
	local st = state[self]
	st.tags = st.tags or {}
	if not table.find(st.tags, tag) then
		table.insert(st.tags, tag)
	end
end
function Methods:RemoveTag(tag: string)
	local st = state[self]
	local i = st.tags and table.find(st.tags, tag)
	if i then
		table.remove(st.tags, i)
	end
end

function Methods:GetActor()
	return nil
end

-- ---------------------------------------------------------- class methods --

local function extra(inst)
	local st = state[inst]
	st.extra = st.extra or {}
	return st.extra
end
Runtime.extra = extra

ClassMethods.GuiObject = {
	TweenPosition = function(self, pos)
		self.Position = pos
		return true
	end,
	TweenSize = function(self, size)
		self.Size = size
		return true
	end,
	TweenSizeAndPosition = function(self, size, pos)
		self.Size = size
		self.Position = pos
		return true
	end,
}

ClassMethods.TextBox = {
	CaptureFocus = function() end,
	ReleaseFocus = function() end,
	IsFocused = function()
		return false
	end,
}

ClassMethods.ScrollingFrame = {
	ScrollToTop = function() end,
}

ClassMethods.RemoteFunction = {
	InvokeServer = function(self, ...)
		local handler = Runtime.serverFunctions[self.Name]
		task.wait(0.01)
		if handler then
			return handler(...)
		end
		return nil
	end,
}

ClassMethods.RemoteEvent = {
	FireServer = function(self, ...)
		local handler = Runtime.serverEvents[self.Name]
		if handler then
			handler(...)
		end
	end,
}
ClassMethods.UnreliableRemoteEvent = ClassMethods.RemoteEvent

ClassMethods.BindableEvent = {
	Fire = function(self, ...)
		fire(self, "Event", ...)
	end,
}

ClassMethods.BindableFunction = {
	Invoke = function(self, ...)
		local f = extra(self).OnInvoke
		return f and f(...)
	end,
}

ClassMethods.Sound = {
	Play = function(self)
		fire(self, "Played")
	end,
	Stop = function() end,
	Pause = function() end,
	Resume = function() end,
}

ClassMethods.Humanoid = {
	TakeDamage = function(self, amount)
		self.Health = math.max(0, self.Health - amount)
	end,
	GetState = function()
		return roblox.Enum.HumanoidStateType.Running
	end,
	ChangeState = function() end,
	SetStateEnabled = function() end,
	GetStateEnabled = function()
		return true
	end,
	EquipTool = function(self, tool)
		tool.Parent = self.Parent
	end,
	UnequipTools = function(self)
		local character = self.Parent
		local player = Runtime.localPlayer
		local backpack = player and player:FindFirstChildOfClass("Backpack")
		for _, c in ipairs(character:GetChildren()) do
			if c:IsA("Tool") and backpack then
				c.Parent = backpack
			end
		end
	end,
	MoveTo = function() end,
	LoadAnimation = function()
		return Runtime.fakeTrack()
	end,
	GetAppliedDescription = function()
		return Runtime.new("HumanoidDescription")
	end,
	GetPlayingAnimationTracks = function()
		return {}
	end,
	ApplyDescription = function() end,
}

ClassMethods.Animator = {
	LoadAnimation = function()
		return Runtime.fakeTrack()
	end,
	GetPlayingAnimationTracks = function()
		return {}
	end,
}

ClassMethods.PVInstance = {
	GetPivot = function(self)
		if self:IsA("BasePart") then
			return self.CFrame
		end
		local primary = self:IsA("Model") and self.PrimaryPart
		return primary and primary.CFrame or roblox.CFrame.new()
	end,
	PivotTo = function(self, cf)
		if self:IsA("BasePart") then
			self.CFrame = cf
		end
	end,
}

ClassMethods.Model = {
	GetBoundingBox = function(self)
		return self:GetPivot(), roblox.Vector3.new(4, 5, 2)
	end,
	GetExtentsSize = function()
		return roblox.Vector3.new(4, 5, 2)
	end,
	SetPrimaryPartCFrame = function(self, cf)
		if self.PrimaryPart then
			self.PrimaryPart.CFrame = cf
		end
	end,
	GetPrimaryPartCFrame = function(self)
		return self.PrimaryPart and self.PrimaryPart.CFrame or roblox.CFrame.new()
	end,
	ScaleTo = function() end,
	GetScale = function()
		return 1
	end,
}

ClassMethods.BasePart = {
	GetMass = function()
		return 1
	end,
	GetConnectedParts = function()
		return {}
	end,
	GetTouchingParts = function()
		return {}
	end,
	ApplyImpulse = function() end,
	SetNetworkOwner = function() end,
	GetNetworkOwner = function()
		return nil
	end,
	GetRootPart = function(self)
		return self
	end,
}

ClassMethods.Camera = {
	WorldToViewportPoint = function(_, p)
		return roblox.Vector3.new(640, 360, 10), true
	end,
	WorldToScreenPoint = function(_, p)
		return roblox.Vector3.new(640, 360, 10), true
	end,
	ViewportPointToRay = function(self, x, y)
		return roblox.Ray.new(self.CFrame.Position, roblox.Vector3.new(0, 0, -1))
	end,
	ScreenPointToRay = function(self, x, y)
		return roblox.Ray.new(self.CFrame.Position, roblox.Vector3.new(0, 0, -1))
	end,
	GetPartsObscuringTarget = function()
		return {}
	end,
}

ClassMethods.Player = {
	GetMouse = function(self)
		local e = extra(self)
		if not e.mouse then
			local m = { Hit = roblox.CFrame.new(), X = 640, Y = 360, Icon = "", Target = nil,
				Origin = roblox.CFrame.new(), UnitRay = roblox.Ray.new(roblox.Vector3.zero, roblox.Vector3.new(0, 0, -1)),
				ViewSizeX = 1280, ViewSizeY = 720 }
			for _, n in ipairs({ "Button1Down", "Button1Up", "Button2Down", "Button2Up", "Move", "WheelForward", "WheelBackward", "Idle", "KeyDown", "KeyUp" }) do
				m[n] = newSignal("Mouse." .. n)
			end
			e.mouse = m
		end
		return e.mouse
	end,
	GetRankInGroup = function()
		return 0
	end,
	IsInGroup = function()
		return false
	end,
	Kick = function() end,
	LoadCharacter = function() end,
	GetNetworkPing = function()
		return 0.05
	end,
	HasAppearanceLoaded = function()
		return true
	end,
	RequestStreamAroundAsync = function() end,
	GetFriendsOnline = function()
		return {}
	end,
	IsFriendsWith = function()
		return false
	end,
}

ClassMethods.Tween = {
	Play = function(self)
		local e = extra(self)
		local target, goals, info = e.target, e.goals, e.info
		state[self].props.PlaybackState = roblox.Enum.PlaybackState.Playing
		e.token = (e.token or 0) + 1
		local token = e.token
		-- Goals land when the tween finishes (no in-between frames are drawn), and Completed
		-- fires then, as in the engine -- so a delayed fade-out has not happened yet when a
		-- snapshot is taken straight after a hit.
		local function land()
			for k, v in pairs(goals) do
				local ok, err = pcall(function()
					target[k] = v
				end)
				if not ok then
					report("tween", tostring(err))
				end
			end
		end
		local duration = (info.Time or 0) + (info.DelayTime or 0)
		if info.RepeatCount and info.RepeatCount < 0 then
			return      -- looping forever: never completes
		end
		if duration <= 0 then
			land()
		end
		task.delay(math.min(duration, 5), function()
			if e.token == token then
				if duration > 0 then
					land()
				end
				state[self].props.PlaybackState = roblox.Enum.PlaybackState.Completed
				fire(self, "Completed", roblox.Enum.PlaybackState.Completed)
			end
		end)
	end,
	Cancel = function(self)
		extra(self).token = -1
		state[self].props.PlaybackState = roblox.Enum.PlaybackState.Cancelled
	end,
	Pause = function(self)
		extra(self).token = -1
		state[self].props.PlaybackState = roblox.Enum.PlaybackState.Paused
	end,
}

-- ------------------------------------------------------------- computed --

Runtime.viewport = roblox.Vector2.new(1280, 720)

local function absSize(inst): any
	local st = state[inst]
	if st.class == "ScreenGui" or st.class == "PlayerGui" or not inst:IsA("GuiObject") then
		return Runtime.viewport
	end
	local parent = st.parent
	local ps = parent and absSize(parent) or Runtime.viewport
	local size = inst.Size
	return roblox.Vector2.new(size.X.Scale * ps.X + size.X.Offset, size.Y.Scale * ps.Y + size.Y.Offset)
end

Computed.AbsoluteSize = function(inst)
	if inst:IsA("GuiBase2d") then
		return absSize(inst)
	end
	return nil
end
Computed.AbsolutePosition = function(inst)
	return roblox.Vector2.new(0, 0)
end
Computed.AbsoluteRotation = function()
	return 0
end
Computed.AbsoluteContentSize = function()
	return roblox.Vector2.new(0, 0)
end
Computed.AbsoluteCanvasSize = function()
	return roblox.Vector2.new(0, 0)
end
Computed.AbsoluteWindowSize = function()
	return roblox.Vector2.new(0, 0)
end
Computed.AbsoluteCellSize = function()
	return roblox.Vector2.new(0, 0)
end
Computed.AbsoluteCellCount = function()
	return roblox.Vector2.new(0, 0)
end
Computed.TextBounds = function(inst)
	local text = inst.Text or ""
	local size = inst.TextSize or 14
	return roblox.Vector2.new(#text * size * 0.5, size)
end
Computed.TextFits = function()
	return true
end
Computed.ViewportSize = function()
	return Runtime.viewport
end
Computed.IsLoaded = function()
	return true
end

-- ------------------------------------------------------------ constructors --

function Runtime.new(className: string, parent)
	local c = classOf(className)
	if not c then
		error(("Unable to create an Instance of type \"%s\""):format(tostring(className)), 2)
	end
	if table.find(c.Tags or {}, "NotCreatable") or table.find(c.Tags or {}, "Service") then
		error(("Unable to create an Instance of type \"%s\""):format(className), 2)
	end
	local inst = newInstance(className)
	if parent then
		inst.Parent = parent
	end
	return inst
end

function Runtime.fakeTrack()
	local track = {
		IsPlaying = false, Length = 1, Speed = 1, TimePosition = 0, WeightCurrent = 1, Looped = false,
		Priority = roblox.Enum.AnimationPriority.Action,
	}
	function track:Play()
		self.IsPlaying = true
	end
	function track:Stop()
		self.IsPlaying = false
	end
	function track:AdjustSpeed() end
	function track:AdjustWeight() end
	function track:GetMarkerReachedSignal()
		return newSignal("marker")
	end
	track.Stopped = newSignal("track.Stopped")
	track.Ended = newSignal("track.Ended")
	track.KeyframeReached = newSignal("track.KeyframeReached")
	track.DidLoop = newSignal("track.DidLoop")
	return track
end

--- Mirror a Lune instance tree (from the real place) into runtime instances. Properties are
--- read from the source on demand, so a large tree costs little until something looks at it.
function Runtime.mirror(source, parent)
	local className = source.ClassName
	if not classOf(className) then
		return nil
	end
	local inst = newInstance(className, source)
	state[inst].props.Name = source.Name
	if parent then
		state[inst].parent = parent
		table.insert(state[parent].children, inst)
	end
	for _, child in ipairs(source:GetChildren()) do
		Runtime.mirror(child, inst)
	end
	return inst
end

Runtime.newInstance = newInstance
Runtime.state = state
Runtime.fire = fire
Runtime.ClassMethods = ClassMethods
Runtime.serverFunctions = {} :: { [string]: (...any) -> ...any }
Runtime.serverEvents = {} :: { [string]: (...any) -> () }

-- --------------------------------------------------------------- typeof --

function Runtime.typeof(v)
	if isInstance(v) then
		return "Instance"
	end
	if type(v) == "table" and mockKinds[v] then
		return mockKinds[v]
	end
	return nativeTypeof(v)
end
Runtime.mockKinds = mockKinds

return Runtime
