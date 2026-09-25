--!strict
-- The reload, as it is actually seen: the hands, the magazine and the weapon itself.
--
-- This is presentation only. It runs on every client, for every player's character, off
-- a SINGLE broadcast from GunHandler -- one remote per reload, not one per stage. It
-- never reads or writes ammo: the server owns that and changes it once, at completion.
-- If this module errors, or a client never runs it, the reload still works correctly;
-- it just looks plain.
--
-- Two rules keep it from breaking the weapon it is animating:
--
--   * It never touches a real weld. Parts that have to move are hidden and a clone is
--     animated in their place, so any failure leaves the weapon intact and cancelling is
--     just "unhide everything, delete the clones".
--   * Arm movement is published as hand TARGETS, which WeaponPoseHold blends towards from
--     the pose WeaponPose already set. The two never fight over the shoulder joints.

local Debris = game:GetService("Debris")
local RunService = game:GetService("RunService")

local ReloadAnimator = {}

-- Stage boundaries as fractions of the weapon's ReloadTime, so a weapon's existing
-- ReloadTime still sets the pace and the balance does not move.
local RELEASE      = 0.16   -- magazine unlatches and leaves the well
local FETCH        = 0.34   -- fresh magazine appears in the off hand
local INSERT_START = 0.52
local SEAT         = 0.74   -- magazine locks home
local CHARGE_START = 0.78
local CHARGE_END   = 0.92

local KICK_TIME = 0.18      -- how long the jolt of the magazine locking in lasts

-- Where the two hands meet, in torso space, while the weapon is being reloaded.
--
-- The first version of this only swung the off hand forward on its own side, and the
-- magazine then flew across the gap on its own -- because an arm physically cannot reach
-- the gun where it is held. Measured: the off hand topped out 1.4 studs short.
--
-- So the weapon comes IN to the chest as well, which is what a real reload does, and the
-- off hand meets it right under the magazine well -- the two land about a third of a stud
-- apart, vertically.
--
-- These are POINTS in UpperTorso space, not directions. This module used to turn them into
-- shoulder rotations itself, using R6's single-joint arm where "rotate the shoulder" and
-- "move the hand" were the same statement. On R15 they are not: with the elbow held bent
-- underneath it by the weapon pose, the same rotation swung the hand -- and the rifle
-- welded to it -- up and back into the character's head, 0.29 studs from the head centre.
--
-- So the reload now only says WHERE the hands should be, and ReplicatedStorage.ArmSolver
-- works out the shoulder and elbow that put them there.
local GUN_HAND = Vector3.new(0.10, 0.15, -0.95)
local OFF_HAND = Vector3.new(-0.05, -0.20, -0.95)

local active: { [Model]: any } = {}
local frameConn: RBXScriptConnection? = nil

-- ------------------------------------------------------------------- easing --

local function span(t: number, from: number, to: number): number
	if to <= from then
		return t >= to and 1 or 0
	end
	return math.clamp((t - from) / (to - from), 0, 1)
end

-- Smoothstep: eases in and out, so nothing starts or stops abruptly.
local function smooth(t: number): number
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

-- 0 -> 1 -> 0, for a movement that goes out and comes back.
local function pulse(t: number): number
	return math.sin(math.clamp(t, 0, 1) * math.pi)
end

-- Keyframes as {time, value}, smoothstepped between each pair. This is what gives the
-- off hand its natural acceleration between stages instead of constant-speed sliding.
local function sample(keys, t: number): number
	if t <= keys[1][1] then
		return keys[1][2]
	end
	for i = 1, #keys - 1 do
		local a, b = keys[i], keys[i + 1]
		if t <= b[1] then
			return a[2] + (b[2] - a[2]) * smooth(span(t, a[1], b[1]))
		end
	end
	return keys[#keys][2]
end

-- How far the off hand is reaching, over the whole reload: up to the mag well, down and
-- away with the old magazine, back up with the fresh one, press it home, then rest.
local REACH = {
	{ 0.00, 0.00 },
	{ RELEASE, 1.00 },
	{ FETCH, 0.30 },
	{ INSERT_START, 0.78 },
	{ SEAT, 1.00 },
	{ 1.00, 0.00 },
}

-- ------------------------------------------------------------------- sounds --

-- One Sound per beat, created once on the Handle and reused, so repeated reloads do not
-- pile up instances. An empty id plays nothing rather than erroring, which is why these
-- ship blank in WeaponConfig.
local function beat(tool: Tool, name: string, id: string?)
	if not id or id == "" then
		return
	end
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return
	end
	local sound = handle:FindFirstChild(name)
	if not sound then
		local made = Instance.new("Sound")
		made.Name = name
		made.Volume = 0.55
		made.RollOffMaxDistance = 70
		made.Parent = handle
		sound = made
	end
	if sound:IsA("Sound") then
		sound.SoundId = id
		sound:Play()
	end
end

-- ---------------------------------------------------------------- magazines --

-- Which parts leave the gun as one magazine.
--
-- Hand-built weapons list them by name in WeaponConfig. Imported weapons have far too
-- many -- an AR magazine is a body, a floorplate, a base pad and eight ribs -- so the
-- importer tags them with a MagPart attribute instead and they are collected here. The
-- attribute wins when it is present, so no imported weapon needs a name list.
local function magazineNames(tool: Tool, cfg): { string }
	local tagged = {}
	for _, p in ipairs(tool:GetChildren()) do
		if p:IsA("BasePart") and p:GetAttribute("MagPart") == true then
			table.insert(tagged, p.Name)
		end
	end
	if #tagged > 0 then
		-- Stable order so the first name is always the same part, which is the one the
		-- magazine's offset and PrimaryPart are measured from.
		table.sort(tagged)
		return tagged
	end
	return cfg.MagazineParts or {}
end

-- A standalone copy of the weapon's magazine parts, welded into one rigid assembly and
-- stripped of whatever was parented to the originals.
local function buildMagazine(tool: Tool, cfg): Model?
	local model = Instance.new("Model")
	model.Name = tool.Name .. "Magazine"
	local primary: BasePart? = nil

	for _, partName in ipairs(magazineNames(tool, cfg)) do
		local src = tool:FindFirstChild(partName)
		if src and src:IsA("BasePart") then
			local copy = src:Clone()
			for _, child in ipairs(copy:GetChildren()) do
				child:Destroy()          -- welds, sounds and lights do not come along
			end
			copy.Transparency = 0        -- the original may be hidden right now
			copy.Anchored = true
			copy.CanCollide = false
			copy.CanQuery = false
			copy.CanTouch = false
			copy.Massless = false
			copy.Parent = model
			primary = primary or copy
		end
	end

	if not primary then
		model:Destroy()
		return nil
	end
	model.PrimaryPart = primary
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and p ~= primary then
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = primary
			weld.Part1 = p
			weld.Parent = p
		end
	end
	return model
end

-- The spent magazine, thrown clear and left to tumble.
--
-- Spawned locally on each client rather than replicated: nothing about a piece of litter
-- needs to agree between machines, and it keeps the server free of physics objects and
-- the network free of traffic. Debris clears it whatever happens afterwards -- including
-- the player dying mid-reload -- so these cannot accumulate.
local function dropMagazine(tool: Tool, cfg, at: CFrame, inherit: Vector3)
	local model = buildMagazine(tool, cfg)
	if not model then
		return
	end
	model:PivotTo(at)
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") then
			p.Anchored = false
			p.CanCollide = true
		end
	end
	model.Parent = workspace

	local primary = model.PrimaryPart
	if primary then
		primary.AssemblyLinearVelocity = inherit + Vector3.new(
			(math.random() - 0.5) * 2, -1.5, (math.random() - 0.5) * 2)
		primary.AssemblyAngularVelocity = Vector3.new(
			(math.random() - 0.5) * 16,
			(math.random() - 0.5) * 10,
			(math.random() - 0.5) * 16)
	end
	Debris:AddItem(model, cfg.MagDropLifetime or 8)
end

-- Hidden by writing Transparency on this client only. Client property writes never reach
-- the server, so the stored weapon is untouched, and every client runs this same
-- animation for the same character, so everyone sees the magazine leave.
local function hide(st, tool: Tool, names: { string })
	for _, partName in ipairs(names) do
		local p = tool:FindFirstChild(partName)
		if p and p:IsA("BasePart") and st.hidden[p] == nil then
			st.hidden[p] = p.Transparency
			p.Transparency = 1
		end
	end
end

local function unhide(st)
	for part, transparency in pairs(st.hidden) do
		if part.Parent then
			part.Transparency = transparency
		end
	end
	table.clear(st.hidden)
end

-- ------------------------------------------------------------- per-frame bits --

local function updateCarried(character: Model, st, t: number)
	local mag = st.carried
	if not mag or not mag.PrimaryPart then
		return
	end
	local leftArm = (character:FindFirstChild("LeftHand") or character:FindFirstChild("Left Arm")) :: BasePart?
	local handle = st.tool:FindFirstChild("Handle") :: BasePart?
	if not leftArm or not handle then
		return
	end

	-- In the off hand, then guided into the magazine well. Lerping the whole CFrame is
	-- what stops it snapping into place.
	local inHand = leftArm.CFrame * CFrame.new(0, -1.05, -0.1)
	local seated = handle.CFrame * st.magOffset
	mag:PivotTo(inHand:Lerp(seated, smooth(span(t, INSERT_START, SEAT))))
end

local function updateCharge(st, t: number)
	local part = st.charge
	if not part then
		return
	end
	local handle = st.tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		return
	end
	-- +Z is backwards along the weapon, so this racks it back and lets it run forward.
	local back = pulse(span(t, CHARGE_START, CHARGE_END)) * 0.26
	part.CFrame = handle.CFrame * st.chargeOffset * CFrame.new(0, 0, back)
end

local function step()
	for character, st in pairs(active) do
		-- A character that has been removed mid-reload -- died, respawned, left -- would
		-- otherwise sit in this table holding its clones alive.
		if not character.Parent or not st.tool.Parent then
			ReloadAnimator.Cancel(character)
		else
			local t = (os.clock() - st.startedAt) / st.duration
			updateCarried(character, st, t)
			updateCharge(st, t)
		end
	end
end

-- ---------------------------------------------------------------- public API --

-- Where each hand should BE mid-reload, as points in UpperTorso space, and how much of the
-- way there it currently is. WeaponPoseHold blends from the weapon pose towards these and
-- lets ArmSolver work out the shoulder and elbow.
--
-- Returns nil targets and zero weights when nothing is reloading, so it is safe and cheap
-- to call for every player every frame.
function ReloadAnimator.Targets(character: Model): (Vector3?, Vector3?, number, number)
	local st = active[character]
	if not st then
		return nil, nil, 0, 0
	end

	local t = (os.clock() - st.startedAt) / st.duration
	if t >= 1 then
		return nil, nil, 0, 0
	end

	-- The gun hand brings the weapon in to the chest and holds it there for the reload,
	-- then takes it back out to the aim line.
	local bring = smooth(span(t, 0, RELEASE)) - smooth(span(t, CHARGE_END, 1))

	-- The jolt as the magazine locks home: a sharp kick that decays away.
	local kick = 0
	if st.kickAt then
		local k = 1 - math.clamp((os.clock() - st.kickAt) / KICK_TIME, 0, 1)
		kick = k * k
	end

	-- A slow drift so the weapon is never perfectly static, plus that jolt. Expressed as a
	-- movement of the hand rather than a roll of the shoulder: with an elbow in the chain a
	-- shoulder rotation no longer means a predictable amount of hand travel, which is the
	-- whole reason this module stopped emitting rotations.
	local wobble = Vector3.new(
		math.sin(t * math.pi * 2.7) * 0.030,
		math.cos(t * math.pi * 1.9) * 0.022 - 0.09 * kick,
		0)

	local reach = sample(REACH, t)
	return GUN_HAND + wobble, OFF_HAND + Vector3.new(0, 0.035 * kick, 0), bring, reach
end

function ReloadAnimator.IsPlaying(character: Model): boolean
	return active[character] ~= nil
end

-- Undo everything and leave the weapon exactly as it was found. Safe to call at any
-- point, including on a character that was never reloading.
function ReloadAnimator.Cancel(character: Model)
	local st = active[character]
	if not st then
		return
	end
	active[character] = nil

	unhide(st)
	if st.carried then
		st.carried:Destroy()
	end
	if st.charge then
		st.charge:Destroy()
	end

	if next(active) == nil and frameConn then
		frameConn:Disconnect()
		frameConn = nil
	end
end

function ReloadAnimator.Play(character: Model, tool: Tool, cfg, needsCharge: boolean, duration: number)
	if not character or not tool or not cfg then
		return
	end
	-- Reloading again while a reload is running restarts cleanly rather than stacking.
	ReloadAnimator.Cancel(character)

	local handle = tool:FindFirstChild("Handle") :: BasePart?
	if not handle then
		return
	end

	local st = {
		tool = tool,
		cfg = cfg,
		duration = math.max(duration or cfg.ReloadTime or 1.6, 0.3),
		startedAt = os.clock(),
		hidden = {},
		carried = nil,
		charge = nil,
		kickAt = nil,
		magOffset = CFrame.identity,
		chargeOffset = CFrame.identity,
	}

	-- Where the magazine sits relative to the Handle, captured before anything moves.
	local magParts = (cfg.MagFed ~= false) and magazineNames(tool, cfg) or {}
	local firstMag = magParts[1] and tool:FindFirstChild(magParts[1])
	if firstMag and firstMag:IsA("BasePart") then
		st.magOffset = handle.CFrame:ToObjectSpace(firstMag.CFrame)
	end

	active[character] = st
	if not frameConn then
		frameConn = RunService.PreRender:Connect(step)
	end

	local function still(): boolean
		return active[character] == st and tool.Parent ~= nil
	end

	local d = st.duration

	-- Magazine out. The real parts are hidden and a physical copy is thrown clear.
	if #magParts > 0 then
		task.delay(RELEASE * d, function()
			if not still() then
				return
			end
			local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local at = handle.CFrame * st.magOffset
			dropMagazine(tool, cfg, at, root and root.AssemblyLinearVelocity or Vector3.zero)
			hide(st, tool, magParts)
			beat(tool, "MagOut", cfg.MagOutSound)
		end)

		-- A fresh magazine appears in the off hand while the old one is still falling.
		task.delay(FETCH * d, function()
			if not still() then
				return
			end
			local fresh = buildMagazine(tool, cfg)
			if fresh then
				fresh.Parent = workspace
				st.carried = fresh
			end
		end)

		-- Seated: the copy goes away, the real magazine comes back, and the weapon jolts.
		task.delay(SEAT * d, function()
			if not still() then
				return
			end
			if st.carried then
				st.carried:Destroy()
				st.carried = nil
			end
			unhide(st)
			st.kickAt = os.clock()
			beat(tool, "MagIn", cfg.MagInSound)
		end)
	end

	-- Charging action, only when this weapon and this reload actually call for it.
	if needsCharge and cfg.ChargePart then
		task.delay(CHARGE_START * d, function()
			if not still() then
				return
			end
			local real = tool:FindFirstChild(cfg.ChargePart)
			if real and real:IsA("BasePart") then
				st.chargeOffset = handle.CFrame:ToObjectSpace(real.CFrame)
				local copy = real:Clone()
				for _, child in ipairs(copy:GetChildren()) do
					child:Destroy()
				end
				copy.Anchored = true
				copy.CanCollide = false
				copy.CanQuery = false
				copy.CanTouch = false
				copy.Transparency = 0
				copy.Parent = workspace
				st.charge = copy
				hide(st, tool, { cfg.ChargePart })
			end
			beat(tool, "Charge", cfg.ChargeSound)
		end)

		task.delay(CHARGE_END * d, function()
			if not still() then
				return
			end
			if st.charge then
				st.charge:Destroy()
				st.charge = nil
			end
			unhide(st)
		end)
	end

	-- Back to ready. Cancel is the cleanup path, so completing and being interrupted end
	-- up in exactly the same state.
	task.delay(d, function()
		if active[character] == st then
			ReloadAnimator.Cancel(character)
		end
	end)
end

return ReloadAnimator
