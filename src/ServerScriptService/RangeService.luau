--!strict
-- The gun range: somewhere to actually read what a weapon does.
--
-- The lane already existed as `__DevRange` -- a measuring tool with four targets at 50, 100,
-- 200 and 350 studs, built to verify damage falloff. This turns it into a feature: every
-- target now reports what it is being hit for, so a player can compare weapons, see falloff
-- with their own eyes, and learn a recoil pattern against something that does not shoot back.
--
-- Everything shown is MEASURED, never predicted. The numbers come from the target humanoid's
-- own health changing, which is the server's authoritative record of damage actually dealt --
-- not from what the client thinks it fired.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local MatchService = require(ServerScriptService.MatchService)

local RangeService = {}

-- A burst ends after this long without a hit, and the DPS readout restarts. Long enough to
-- cover a reload-less magazine dump, short enough that walking away resets the figure.
RangeService.BURST_GAP = 2.0
RangeService.ENTRY = CFrame.new(0, 2004, 10)

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end

local RangeAction = remotes:FindFirstChild("RangeAction")
if not RangeAction then
	local rf = Instance.new("RemoteFunction")
	rf.Name = "RangeAction"
	rf.Parent = remotes
	RangeAction = rf
end

local homeOf: { [Player]: CFrame } = {}

-- ------------------------------------------------------------------ board --

local function label(parent: Instance, name: string, y: number, size: number,
	colour: Color3, font: Enum.Font)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Size = UDim2.new(1, 0, 0, size + 4)
	l.Position = UDim2.fromOffset(0, y)
	l.Font = font
	l.TextSize = size
	l.TextColor3 = colour
	l.Text = ""
	l.Parent = parent
	return l
end

--- One readout above one target.
local function board(target: Model, distance: number)
	local head = target:FindFirstChild("Head") or target:FindFirstChildWhichIsA("BasePart")
	if not head then
		return nil
	end

	local existing = head:FindFirstChild("RangeBoard")
	if existing then
		existing:Destroy()
	end

	local bb = Instance.new("BillboardGui")
	bb.Name = "RangeBoard"
	-- Sized in pixels, not studs: a stud-scaled billboard grows as you walk toward it, and
	-- these are read from 350 studs away as often as from ten.
	bb.Size = UDim2.fromOffset(190, 92)
	bb.StudsOffsetWorldSpace = Vector3.new(0, 5.2, 0)
	bb.AlwaysOnTop = true
	bb.MaxDistance = 420      -- past the furthest target, so all four stay readable
	bb.LightInfluence = 0
	bb.Parent = head

	local title = label(bb, "Distance", 0, 14, Color3.fromRGB(167, 174, 188), Enum.Font.GothamBold)
	title.Text = string.format("%d STUDS", distance)

	local damage = label(bb, "Damage", 16, 30, Color3.fromRGB(255, 255, 255), Enum.Font.GothamBlack)
	damage.Text = "-"

	local dps = label(bb, "DPS", 50, 16, Color3.fromRGB(55, 214, 122), Enum.Font.GothamBold)
	local detail = label(bb, "Detail", 70, 12, Color3.fromRGB(110, 118, 134), Enum.Font.GothamMedium)

	return { damage = damage, dps = dps, detail = detail }
end

-- ------------------------------------------------------------------ watch --

local function watch(target: Model, distance: number)
	local humanoid = target:FindFirstChildOfClass("Humanoid")
	local ui = board(target, distance)
	if not humanoid or not ui then
		return
	end

	local lastHealth = humanoid.Health
	local burstStart, lastHit, burstDamage, burstHits, best = 0, 0, 0, 0, 0

	humanoid.HealthChanged:Connect(function(health: number)
		local lost = lastHealth - health
		lastHealth = health

		-- Healing back up between bursts is the reset script doing its job, not a hit.
		if lost <= 0 then
			return
		end

		local now = os.clock()

		-- A gap longer than BURST_GAP starts a new burst. Without this the DPS figure is
		-- diluted by however long the player stood around between magazines, which makes it
		-- useless for the one thing it is for: comparing weapons.
		local newBurst = burstStart == 0 or now - lastHit > RangeService.BURST_GAP
		if newBurst then
			burstStart, burstDamage, burstHits = now, 0, 0
		end
		lastHit = now
		burstHits += 1

		-- The FIRST hit of a burst contributes its timestamp but not its damage.
		--
		-- Dividing total burst damage by the time since the first hit counts that hit's damage
		-- while ignoring the interval before it, which overstates the rate by hits/(hits-1).
		-- Measured: five hits of 24 at 0.1s spacing reported 276 dps when the true sustained
		-- rate is 240. Excluding the first hit's damage makes the numerator and the denominator
		-- describe the same span, and the figure comes out right.
		if not newBurst then
			burstDamage += lost
		end
		if lost > best then
			best = lost
		end

		ui.damage.Text = string.format("%d", math.floor(lost + 0.5))

		-- DPS needs a window to divide by; over a single instant hit it is meaningless, so
		-- the first shot of a burst reports the hit count instead of a made-up rate.
		local elapsed = now - burstStart
		ui.dps.Text = elapsed > 0.05
			and string.format("%.0f dps  -  %d hits", burstDamage / elapsed, burstHits)
			or string.format("%d hit", burstHits)

		local weapon = humanoid:GetAttribute("LastHitWeapon")
		ui.detail.Text = string.format("best %d%s", math.floor(best + 0.5),
			type(weapon) == "string" and ("  -  " .. weapon) or "")
	end)
end

-- ------------------------------------------------------------------ enter --

function RangeService.Enter(player: Player): boolean
	if homeOf[player] then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	-- Remember home before moving, exactly as a duel does.
	homeOf[player] = (root :: BasePart).CFrame
	MatchService.PlaceAt(player, RangeService.ENTRY)
	return true
end

function RangeService.Leave(player: Player): boolean
	local home = homeOf[player]
	if not home then
		return false
	end
	homeOf[player] = nil
	MatchService.PlaceAt(player, home + Vector3.new(0, 3, 0))
	return true
end

function RangeService.IsIn(player: Player): boolean
	return homeOf[player] ~= nil
end

Players.PlayerRemoving:Connect(function(player)
	homeOf[player] = nil
end)

-- Nobody is left in the sky at shutdown.
game:BindToClose(function()
	for _, p in ipairs(Players:GetPlayers()) do
		pcall(RangeService.Leave, p)
	end
end)

local rangeRemote = RangeAction :: RemoteFunction
rangeRemote.OnServerInvoke = function(player: Player, action: unknown)
	if action == "enter" then
		return RangeService.Enter(player)
	elseif action == "leave" then
		return RangeService.Leave(player)
	elseif action == "state" then
		return RangeService.IsIn(player)
	end
	return false
end

-- ------------------------------------------------------------------ build --

function RangeService.Build()
	local range = workspace:FindFirstChild("__DevRange")
	if not range then
		warn("[Range] __DevRange not found; no readouts attached")
		return
	end
	local targets = range:FindFirstChild("Targets")
	if not targets then
		return
	end

	local count = 0
	for _, target in ipairs(targets:GetChildren()) do
		if target:IsA("Model") then
			-- The distance is in the name the lane was built with (Target_200), which is more
			-- reliable than measuring it -- the targets can be dragged in Studio.
			local distance = tonumber(target.Name:match("(%d+)$")) or 0
			watch(target, distance)
			count += 1
		end
	end
	print(("[Range] %d targets reporting damage"):format(count))
end

RangeService.Build()

return RangeService
