--!nocheck
-- The client world the interface scripts run in: services, a local player with a character,
-- leaderstats and a backpack, the place's real ReplicatedStorage and StarterPlayer, a
-- `require` that loads the real modules, and a clock that drives Heartbeat.
--
-- The server is not run. The remotes it would create are created here, and what they answer
-- comes from Runtime.serverFunctions / serverEvents, which a test fills in.

local roblox = require("@lune/roblox")
local task = require("@lune/task")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local serde = require("@lune/serde")

local R = require("./runtime")

local World = {}

local newInstance, state, fire, extra = R.newInstance, R.state, R.fire, R.extra
local CM = R.ClassMethods

-- Set a property underneath the read-only checks, the way the engine itself would.
local function force(inst, key, value)
	state[inst].props[key] = value
end
World.force = force

-- ------------------------------------------------------------- datatypes --

local RandomMT = {}
RandomMT.__index = RandomMT
local Random = {}
function Random.new(seed)
	local r = setmetatable({ _s = (tonumber(seed) or os.clock() * 1e6) % 2147483647 }, RandomMT)
	R.mockKinds[r] = "Random"
	return r
end
function RandomMT:_next()
	self._s = (self._s * 1103515245 + 12345) % 2147483648
	return self._s / 2147483648
end
function RandomMT:NextNumber(a, b)
	a = a or 0
	b = b or 1
	return a + (b - a) * self:_next()
end
function RandomMT:NextInteger(a, b)
	return a + math.floor(self:_next() * (b - a + 1))
end
function RandomMT:NextUnitVector()
	return roblox.Vector3.new(self:_next() - 0.5, self:_next() - 0.5, self:_next() - 0.5).Unit
end
function RandomMT:Shuffle(t)
	for i = #t, 2, -1 do
		local j = self:NextInteger(1, i)
		t[i], t[j] = t[j], t[i]
	end
end
function RandomMT:Clone()
	return Random.new(self._s)
end

local TweenInfo = {}
function TweenInfo.new(time, style, direction, repeatCount, reverses, delayTime)
	local info = {
		Time = time or 1,
		EasingStyle = style or roblox.Enum.EasingStyle.Quad,
		EasingDirection = direction or roblox.Enum.EasingDirection.Out,
		RepeatCount = repeatCount or 0,
		Reverses = reverses or false,
		DelayTime = delayTime or 0,
	}
	R.mockKinds[info] = "TweenInfo"
	return table.freeze(info)
end

local DateTime = {}
local function dateTime(unix)
	local d = { UnixTimestamp = math.floor(unix), UnixTimestampMillis = math.floor(unix * 1000) }
	function d:FormatLocalTime(fmt)
		return tostring(fmt)
	end
	function d:FormatUniversalTime(fmt)
		return tostring(fmt)
	end
	function d:ToIsoDate()
		return "2026-01-01T00:00:00Z"
	end
	function d:ToUniversalTime()
		return { Year = 2026, Month = 1, Day = 1, Hour = 0, Minute = 0, Second = 0, Millisecond = 0 }
	end
	d.ToLocalTime = d.ToUniversalTime
	R.mockKinds[d] = "DateTime"
	return d
end
function DateTime.now()
	return dateTime(os.time())
end
function DateTime.fromUnixTimestamp(t)
	return dateTime(t)
end
function DateTime.fromUnixTimestampMillis(t)
	return dateTime(t / 1000)
end

local function paramsFactory(kind)
	return {
		new = function()
			local p = {
				FilterDescendantsInstances = {},
				FilterType = roblox.Enum.RaycastFilterType.Exclude,
				IgnoreWater = false,
				CollisionGroup = "Default",
				RespectCanCollide = false,
				BruteForceAllSlow = false,
				MaxParts = 0,
			}
			function p:AddToFilter(x)
				table.insert(self.FilterDescendantsInstances, x)
			end
			R.mockKinds[p] = kind
			return p
		end,
	}
end

-- ----------------------------------------------------------------- game --

local game = newInstance("DataModel")
force(game, "Name", "Game")
World.game = game

local services = {}
local function service(className: string)
	local s = services[className]
	if s then
		return s
	end
	s = newInstance(className)
	force(s, "Name", className)
	state[s].parent = game
	table.insert(state[game].children, s)
	services[className] = s
	return s
end
World.service = service

CM.DataModel = {
	GetService = function(_, name)
		if type(name) ~= "string" then
			error("GetService: name expected", 2)
		end
		local c = roblox.getReflectionDatabase():GetClass(name)
		if not c then
			error(("'%s' is not a valid Service name"):format(name), 2)
		end
		return service(name)
	end,
	FindService = function(_, name)
		return services[name]
	end,
	IsLoaded = function()
		return true
	end,
	BindToClose = function() end,
	GetJobsInfo = function()
		return {}
	end,
}
fire(game, "Loaded")

local workspace = service("Workspace")
local camera = newInstance("Camera")
force(camera, "Name", "Camera")
force(camera, "CFrame", roblox.CFrame.new(0, 10, 20))
force(camera, "FieldOfView", 70)
camera.Parent = workspace
force(workspace, "CurrentCamera", camera)
World.workspace = workspace
World.camera = camera

-- ------------------------------------------------------------- services --

local runService = service("RunService")
local renderSteps = {}
CM.RunService = {
	IsClient = function()
		return true
	end,
	IsServer = function()
		return false
	end,
	IsStudio = function()
		return true
	end,
	IsRunning = function()
		return true
	end,
	IsRunMode = function()
		return false
	end,
	IsEdit = function()
		return false
	end,
	BindToRenderStep = function(_, name, priority, fn)
		renderSteps[name] = fn
	end,
	UnbindFromRenderStep = function(_, name)
		renderSteps[name] = nil
	end,
}

local uis = service("UserInputService")
force(uis, "KeyboardEnabled", true)
force(uis, "MouseEnabled", true)
force(uis, "TouchEnabled", false)
force(uis, "GamepadEnabled", false)
force(uis, "VREnabled", false)
local keysDown = {}
World.keysDown = keysDown
CM.UserInputService = {
	GetMouseLocation = function()
		return roblox.Vector2.new(640, 360)
	end,
	IsKeyDown = function(_, key)
		return keysDown[key] == true
	end,
	IsMouseButtonPressed = function()
		return false
	end,
	GetFocusedTextBox = function()
		return nil
	end,
	GetLastInputType = function()
		return roblox.Enum.UserInputType.Keyboard
	end,
	GetConnectedGamepads = function()
		return {}
	end,
	GetGamepadConnected = function()
		return false
	end,
	GetKeysPressed = function()
		return {}
	end,
	GetMouseDelta = function()
		return roblox.Vector2.new(0, 0)
	end,
	GetStringForKeyCode = function(_, key)
		return key.Name
	end,
	GetImageForKeyCode = function()
		return ""
	end,
	GetMouseButtonsPressed = function()
		return {}
	end,
	GetNavigationGamepads = function()
		return {}
	end,
	GetSupportedGamepadKeyCodes = function()
		return {}
	end,
}

CM.StarterGui = {
	SetCoreGuiEnabled = function() end,
	GetCoreGuiEnabled = function()
		return true
	end,
	SetCore = function() end,
	GetCore = function()
		return nil
	end,
}

CM.ContentProvider = {
	PreloadAsync = function(_, list, cb)
		if cb then
			for _, item in ipairs(list) do
				cb(item, roblox.Enum.AssetFetchStatus.Success)
			end
		end
	end,
}

CM.TextService = {
	GetTextSize = function(_, text, size, font, frame)
		return roblox.Vector2.new(#tostring(text) * size * 0.52, size)
	end,
	GetTextBoundsAsync = function(_, params)
		local text = params.Text or ""
		local size = params.Size or 14
		return roblox.Vector2.new(#text * size * 0.52, size)
	end,
	FilterStringAsync = function(_, text)
		return { GetNonChatStringForBroadcastAsync = function()
			return text
		end }
	end,
}

CM.GuiService = {
	GetGuiInset = function()
		return roblox.Vector2.new(0, 58), roblox.Vector2.new(0, 0)
	end,
	IsTenFootInterface = function()
		return false
	end,
	CloseInspectMenu = function() end,
	SetMenuIsOpen = function() end,
}

CM.MarketplaceService = {
	PromptProductPurchase = function() end,
	PromptGamePassPurchase = function() end,
	PromptPurchase = function() end,
	UserOwnsGamePassAsync = function()
		return false
	end,
	GetProductInfo = function()
		return { Name = "Item", PriceInRobux = 0, Description = "" }
	end,
	PlayerOwnsAsset = function()
		return false
	end,
}

CM.HttpService = {
	JSONEncode = function(_, v)
		return serde.encode("json", v)
	end,
	JSONDecode = function(_, s)
		return serde.decode("json", s)
	end,
	GenerateGUID = function(_, braces)
		local g = ("%08x-%04x-%04x-%04x-%012x"):format(math.random(0, 0x7fffffff), math.random(0, 0xffff),
			math.random(0, 0xffff), math.random(0, 0xffff), math.random(0, 0x7fffffff))
		return braces == false and g or "{" .. g .. "}"
	end,
	UrlEncode = function(_, s)
		return s
	end,
}

CM.Debris = {
	AddItem = function(_, inst, lifetime)
		task.delay(math.min(lifetime or 10, 10), function()
			if R.isInstance(inst) then
				inst:Destroy()
			end
		end)
	end,
}

local tagged = {}
CM.CollectionService = {
	GetTagged = function(_, tag)
		return table.clone(tagged[tag] or {})
	end,
	GetInstanceAddedSignal = function(_, tag)
		return R.newSignal("tag+" .. tag)
	end,
	GetInstanceRemovedSignal = function(_, tag)
		return R.newSignal("tag-" .. tag)
	end,
	HasTag = function(_, inst, tag)
		return inst:HasTag(tag)
	end,
	AddTag = function(_, inst, tag)
		inst:AddTag(tag)
		tagged[tag] = tagged[tag] or {}
		table.insert(tagged[tag], inst)
	end,
	RemoveTag = function(_, inst, tag)
		inst:RemoveTag(tag)
	end,
	GetTags = function(_, inst)
		return inst:GetTags()
	end,
}

CM.ContextActionService = {
	BindAction = function() end,
	BindActionAtPriority = function() end,
	UnbindAction = function() end,
	SetTitle = function() end,
	SetImage = function() end,
	SetPosition = function() end,
	SetDescription = function() end,
	GetButton = function()
		return nil
	end,
	GetAllBoundActionInfo = function()
		return {}
	end,
}

CM.SoundService = {
	PlayLocalSound = function() end,
	SetListener = function() end,
}

CM.Lighting = {
	GetMinutesAfterMidnight = function()
		return 14 * 60
	end,
	SetMinutesAfterMidnight = function() end,
	GetSunDirection = function()
		return roblox.Vector3.new(0, 1, 0)
	end,
	GetMoonDirection = function()
		return roblox.Vector3.new(0, -1, 0)
	end,
}

CM.Workspace = {
	Raycast = function()
		return nil
	end,
	Blockcast = function()
		return nil
	end,
	Spherecast = function()
		return nil
	end,
	Shapecast = function()
		return nil
	end,
	GetPartBoundsInBox = function()
		return {}
	end,
	GetPartBoundsInRadius = function()
		return {}
	end,
	GetPartsInPart = function()
		return {}
	end,
	GetServerTimeNow = function()
		return os.clock()
	end,
	FindPartOnRay = function()
		return nil
	end,
	FindPartOnRayWithIgnoreList = function()
		return nil
	end,
	GetRealPhysicsFPS = function()
		return 60
	end,
}

CM.TweenService = {
	Create = function(_, target, info, goals)
		if not R.isInstance(target) then
			error("TweenService:Create: instance expected", 2)
		end
		if R.typeof(info) ~= "TweenInfo" then
			error("TweenService:Create: TweenInfo expected, got " .. R.typeof(info), 2)
		end
		for k in pairs(goals) do
			-- An unknown or read-only property is an error at Create time in the engine.
			local ok, err = pcall(function()
				local _ = target[k]
			end)
			if not ok then
				error(("TweenService:Create property named '%s' cannot be tweened: %s"):format(k, tostring(err)), 2)
			end
		end
		local tween = newInstance("Tween")
		local e = extra(tween)
		e.target, e.info, e.goals = target, info, goals
		force(tween, "PlaybackState", roblox.Enum.PlaybackState.Begin)
		return tween
	end,
	GetValue = function(_, alpha)
		return alpha
	end,
}

CM.PolicyService = {
	GetPolicyInfoForPlayerAsync = function()
		return { ArePaidRandomItemsRestricted = false, AllowedExternalLinkReferences = {}, IsSubjectToChinaPolicies = false }
	end,
}
CM.LocalizationService = {
	GetTranslatorForPlayerAsync = function()
		return { Translate = function(_, _, s)
			return s
		end }
	end,
}
CM.SocialService = {
	PromptGameInvite = function() end,
	CanSendGameInviteAsync = function()
		return false
	end,
}
CM.Teams = {
	GetTeams = function()
		return {}
	end,
}
CM.HapticService = {
	IsVibrationSupported = function()
		return false
	end,
	SetMotor = function() end,
}
CM.GroupService = {
	GetGroupsAsync = function()
		return {}
	end,
}

-- --------------------------------------------------------------- player --

local players = service("Players")
force(players, "MaxPlayers", 12)
local player = newInstance("Player")
force(player, "Name", "TestPlayer")
force(player, "DisplayName", "Tester")
force(player, "UserId", 1)
state[player].parent = players
table.insert(state[players].children, player)
force(players, "LocalPlayer", player)
R.localPlayer = player
World.player = player

CM.Players = {
	GetPlayers = function()
		local list = {}
		for _, c in ipairs(state[players].children) do
			if c:IsA("Player") then
				table.insert(list, c)
			end
		end
		return list
	end,
	GetPlayerFromCharacter = function(_, character)
		for _, c in ipairs(state[players].children) do
			if c:IsA("Player") and state[c].props.Character == character and character ~= nil then
				return c
			end
		end
		return nil
	end,
	GetPlayerByUserId = function(_, id)
		for _, c in ipairs(state[players].children) do
			if c:IsA("Player") and c.UserId == id then
				return c
			end
		end
		return nil
	end,
	GetUserThumbnailAsync = function(_, id)
		return ("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150"):format(id), true
	end,
	GetNameFromUserIdAsync = function(_, id)
		return "User" .. tostring(id)
	end,
	GetUserIdFromNameAsync = function()
		return 1
	end,
	GetHumanoidDescriptionFromUserId = function()
		return newInstance("HumanoidDescription")
	end,
	GetFriendsAsync = function()
		return { GetCurrentPage = function()
			return {}
		end, IsFinished = true }
	end,
}

local playerGui = newInstance("PlayerGui")
force(playerGui, "Name", "PlayerGui")
playerGui.Parent = player
local backpack = newInstance("Backpack")
force(backpack, "Name", "Backpack")
backpack.Parent = player
local playerScripts = newInstance("PlayerScripts")
force(playerScripts, "Name", "PlayerScripts")
playerScripts.Parent = player
World.playerGui = playerGui
World.backpack = backpack
World.playerScripts = playerScripts

local leaderstats = R.new("Folder")
leaderstats.Name = "leaderstats"
for name, value in pairs({ Kills = 37, Deaths = 21, Coins = 12450 }) do
	local v = R.new("IntValue")
	v.Name = name
	v.Value = value
	v.Parent = leaderstats
end
leaderstats.Parent = player

for k, v in pairs({ Level = 14, RankTier = "Gold", Rating = 1185, Prestige = 0 }) do
	player:SetAttribute(k, v)
end

local function makeCharacter()
	local character = R.new("Model")
	character.Name = player.Name
	local root = R.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = roblox.Vector3.new(2, 2, 1)
	root.Parent = character
	local head = R.new("Part")
	head.Name = "Head"
	head.Parent = character
	local torso = R.new("Part")
	torso.Name = "UpperTorso"
	torso.Parent = character
	local humanoid = R.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.Parent = character
	local animator = R.new("Animator")
	animator.Parent = humanoid
	character.PrimaryPart = root
	character.Parent = workspace
	force(player, "Character", character)
	return character
end
World.character = makeCharacter()

-- --------------------------------------------------------------- place --

--- Mirror the place's client-visible services from a .rbxl.
function World.loadPlace(path: string)
	local place = roblox.deserializePlace(fs.readFile(path))
	for _, name in ipairs({ "ReplicatedStorage", "ReplicatedFirst", "StarterPlayer", "StarterGui", "StarterPack", "Lighting", "SoundService" }) do
		local ok, src = pcall(function()
			return place:GetService(name)
		end)
		if ok and src then
			local target = service(name)
			for _, child in ipairs(src:GetChildren()) do
				R.mirror(child, target)
			end
		end
	end
	World.place = place
	return place
end

--- Create the remotes the server's services would, so the client finds them.
function World.serverRemotes(spec: { [string]: { [string]: string } })
	local rs = service("ReplicatedStorage")
	for folderName, remotes in pairs(spec) do
		local folder = rs:FindFirstChild(folderName)
		if not folder then
			folder = R.new("Folder")
			folder.Name = folderName
			folder.Parent = rs
		end
		for name, className in pairs(remotes) do
			if not folder:FindFirstChild(name) then
				local r = R.new(className)
				r.Name = name
				r.Parent = folder
			end
		end
	end
end

--- Fire a remote's OnClientEvent as the server would.
function World.serverFire(folderName: string, name: string, ...)
	local folder = service("ReplicatedStorage"):FindFirstChild(folderName)
	local remote = folder and folder:FindFirstChild(name)
	if not remote then
		R.report("test", "serverFire: no remote " .. folderName .. "." .. name)
		return
	end
	fire(remote, "OnClientEvent", ...)
end

-- --------------------------------------------------------------- scripts --

local shared = {}
local sharedG = {}
local loaded = {}
local loading = {}

local baseEnv = {}
for key, value in pairs(roblox) do
	if type(key) == "string" and key:match("^%u") then
		baseEnv[key] = value
	end
end

local function makeEnv(scriptInst)
	local env = {
		game = game,
		Game = game,
		workspace = workspace,
		Workspace = workspace,
		script = scriptInst,
		shared = shared,
		_G = sharedG,
		Instance = {
			new = function(className, parent)
				return R.new(className, parent)
			end,
			fromExisting = function(inst)
				return inst:Clone()
			end,
		},
		Enum = roblox.Enum,
		typeof = R.typeof,
		task = task,
		wait = task.wait,
		delay = task.delay,
		spawn = task.spawn,
		tick = os.clock,
		time = os.clock,
		elapsedTime = os.clock,
		Random = Random,
		TweenInfo = TweenInfo,
		DateTime = DateTime,
		RaycastParams = paramsFactory("RaycastParams"),
		OverlapParams = paramsFactory("OverlapParams"),
		settings = function()
			return { Rendering = { QualityLevel = 10 }, Physics = {}, Network = {} }
		end,
		UserSettings = function()
			return {
				GetService = function()
					return { SavedQualityLevel = roblox.Enum.SavedQualitySetting.Automatic,
						GetCameraYInvertValue = function()
							return 1
						end, MouseSensitivity = 1, RotationType = roblox.Enum.RotationType.MovementRelative }
				end,
			}
		end,
		warn = function(...)
			local parts = {}
			for i = 1, select("#", ...) do
				parts[i] = tostring(select(i, ...))
			end
			local line = table.concat(parts, " ")
			table.insert(R.log, "[warn] " .. line)
			if World.verbose then
				print("\27[33m[warn] " .. line .. "\27[0m")
			end
		end,
		print = function(...)
			if World.verbose then
				print(...)
			end
		end,
	}
	for k, v in pairs(baseEnv) do
		if env[k] == nil then
			env[k] = v
		end
	end
	env.require = World.require
	return setmetatable(env, { __index = _G })
end

function World.require(target)
	if not R.isInstance(target) or not target:IsA("ModuleScript") then
		error("Attempted to call require with invalid argument(s).", 2)
	end
	local cached = loaded[target]
	if cached then
		return cached.value
	end
	if loading[target] then
		error("Requested module was required recursively: " .. target:GetFullName(), 2)
	end
	loading[target] = true
	local source = target.Source
	local ok, fn = pcall(luau.load, source, {
		debugName = target:GetFullName(),
		environment = makeEnv(target),
	})
	if not ok then
		loading[target] = nil
		error("Syntax error in " .. target:GetFullName() .. ": " .. tostring(fn), 2)
	end
	local okRun, value = pcall(fn)
	loading[target] = nil
	if not okRun then
		error("Requested module experienced an error while loading: " .. target:GetFullName() .. "\n" .. tostring(value), 2)
	end
	loaded[target] = { value = value }
	return value
end

--- Run a LocalScript (a clone under PlayerScripts, as the engine does).
function World.run(template)
	local scriptInst = template:Clone()
	scriptInst.Parent = playerScripts
	local name = scriptInst:GetFullName()
	task.spawn(function()
		local ok, fn = pcall(luau.load, scriptInst.Source, {
			debugName = name,
			environment = makeEnv(scriptInst),
		})
		if not ok then
			R.report("syntax " .. name, tostring(fn))
			return
		end
		local okRun, err = xpcall(fn, function(e)
			return debug.traceback(tostring(e), 2)
		end)
		if not okRun then
			R.report("script " .. name, tostring(err))
		end
	end)
	return scriptInst
end

-- ---------------------------------------------------------------- clock --

local clock = 0
function World.advance(seconds: number)
	local frames = math.max(1, math.floor(seconds * 30))
	for _ = 1, frames do
		task.wait(1 / 30)
		clock += 1 / 30
		fire(runService, "Stepped", clock, 1 / 30)
		fire(runService, "Heartbeat", 1 / 30)
		fire(runService, "RenderStepped", 1 / 30)
		fire(runService, "PreRender", 1 / 30)
		for name, fn in pairs(renderSteps) do
			local ok, err = pcall(fn, 1 / 30)
			if not ok then
				R.report("renderstep " .. name, tostring(err))
				renderSteps[name] = nil
			end
		end
	end
end

-- ---------------------------------------------------------------- input --

local function inputObject(props)
	local io = newInstance("InputObject")
	for k, v in pairs(props) do
		force(io, k, v)
	end
	return io
end

function World.pressKey(key, holdFor: number?)
	keysDown[key] = true
	local down = inputObject({ KeyCode = key, UserInputType = roblox.Enum.UserInputType.Keyboard,
		UserInputState = roblox.Enum.UserInputState.Begin })
	fire(uis, "InputBegan", down, false)
	World.advance(holdFor or 0.1)
	keysDown[key] = nil
	local up = inputObject({ KeyCode = key, UserInputType = roblox.Enum.UserInputType.Keyboard,
		UserInputState = roblox.Enum.UserInputState.End })
	fire(uis, "InputEnded", up, false)
	World.advance(0.05)
end

function World.holdKey(key, down: boolean)
	keysDown[key] = down or nil
	local io = inputObject({ KeyCode = key, UserInputType = roblox.Enum.UserInputType.Keyboard,
		UserInputState = down and roblox.Enum.UserInputState.Begin or roblox.Enum.UserInputState.End })
	fire(uis, down and "InputBegan" or "InputEnded", io, false)
end

function World.click(button)
	local io = inputObject({ UserInputType = roblox.Enum.UserInputType.MouseButton1,
		UserInputState = roblox.Enum.UserInputState.Begin, KeyCode = roblox.Enum.KeyCode.Unknown })
	fire(button, "MouseEnter", 640, 360)
	fire(button, "InputBegan", io)
	fire(button, "MouseButton1Down", 640, 360)
	World.advance(0.05)
	fire(button, "MouseButton1Up", 640, 360)
	fire(button, "MouseButton1Click")
	fire(button, "Activated", io, 1)
	fire(button, "InputEnded", io)
	fire(button, "MouseLeave", 640, 360)
	World.advance(0.1)
end

--- The first descendant of `root` with this name (and optionally class).
function World.find(root, name: string, className: string?)
	for _, d in ipairs(root:GetDescendants()) do
		if d.Name == name and (not className or d:IsA(className)) then
			return d
		end
	end
	return nil
end

--- Visible means the object and every ancestor up to its ScreenGui are shown.
function World.shown(inst): boolean
	local cur = inst
	while cur and R.isInstance(cur) do
		if cur:IsA("GuiObject") and not cur.Visible then
			return false
		end
		if cur:IsA("LayerCollector") then
			return cur.Enabled
		end
		cur = cur.Parent
	end
	return false
end

World.R = R
return World
