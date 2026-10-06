--!strict
-- The people who stand still for a living -- shop clerks and quest givers (NPCService.Outfit
-- figures, tagged "Staff") -- given a life on each client:
--
--   * they breathe and shift their weight; a clerk waits with their arms folded;
--   * they look at you when you come close, and give you a wave the first time;
--   * talk to one (their prompt, or a shop's counter) and they turn to you and talk with
--     their hands for a few seconds;
--   * a robbery: the clerk of the shop being robbed (StickupService sets HandsUpAt,
--     HandsUpFor and RobberId on them) jolts, a "!" pops over their head, they turn to face
--     the robber and throw both hands up, and hold them there, shaking, until the time is up.
--
-- Presentation only, and local: the server's figure never moves. The root is anchored and
-- every other part hangs off it by the rig's Motor6Ds, so posing is writing C0 -- nothing
-- else animates these joints (no Animator, no Animate script), so the pose is simply
-- C0 = rest * pose. The poses themselves are ReplicatedStorage.StaffPose.

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local StaffPose = require(ReplicatedStorage:WaitForChild("StaffPose"))

local player = Players.LocalPlayer

local RANGE = 90             -- past this nobody is posed (and the joints are put back)
local NOTICE = 16            -- they look at whoever is closest inside this
local GREET = 11             -- and wave at you the first time you come this close
local GREET_AGAIN = 90       -- seconds before they wave at you again
local TALK = 4.5             -- seconds of talking after you interact with them

type Joint = { motor: Motor6D, rest: CFrame }
type Person = {
	model: Model,
	joints: { [string]: Joint },
	seed: number,
	clerk: boolean,
	bodyYaw: number,
	headYaw: number,
	headPitch: number,
	handsUp: number,          -- 0..1, eased
	handsUpAt: number?,       -- the robbery being reacted to (server time)
	talkUntil: number,
	waveAt: number?,
	greetedAt: number,
	posed: boolean,
}

local people: { [Model]: Person } = {}

local function jointsOf(model: Model): { [string]: Joint }
	local joints: { [string]: Joint } = {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part1 and d.Part1.Parent == model then
			joints[d.Part1.Name] = { motor = d, rest = d.C0 }
		end
	end
	return joints
end

local function personFor(model: Model): Person?
	local person = people[model]
	if person then
		-- A figure streamed out and back in comes back with new joints.
		local _, any = next(person.joints)
		if not any or not any.motor:IsDescendantOf(model) then
			person.joints = jointsOf(model)
		end
		return person
	end
	local joints = jointsOf(model)
	-- Something we cannot pose: no joints, or limbs welded solid.
	local torso = model:FindFirstChild("UpperTorso")
	if not next(joints) or (torso and torso:IsA("BasePart") and torso.Anchored) then
		return nil
	end
	local seed = 0
	for i = 1, #model.Name do
		seed += string.byte(model.Name, i) * i
	end
	local made: Person = {
		model = model, joints = joints, seed = (seed % 97) / 13, clerk = model.Name == "Clerk",
		bodyYaw = 0, headYaw = 0, headPitch = 0, handsUp = 0, handsUpAt = nil,
		talkUntil = 0, waveAt = nil, greetedAt = -math.huge, posed = false,
	}
	people[model] = made
	return made
end

local function release(person: Person)
	if not person.posed then
		return
	end
	person.posed = false
	for _, joint in pairs(person.joints) do
		if joint.motor.Parent then
			joint.motor.C0 = joint.rest
		end
	end
end

-- Where someone's eyes are: off the root, which every character has the moment it exists
-- (the head can be a moment behind, or missing on a stripped rig).
local function headOf(character: Model?): Vector3?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root.Position + Vector3.new(0, 1.6, 0) else nil
end

-- A "!" that pops up over a startled clerk and fades.
local function exclaim(person: Person)
	local head = person.model:FindFirstChild("Head")
	if not head or not head:IsA("BasePart") then
		return
	end
	local gui = Instance.new("BillboardGui")
	gui.Name = "Startled"
	gui.Size = UDim2.fromOffset(44, 44)
	gui.StudsOffsetWorldSpace = Vector3.new(0, 4.6, 0)
	gui.AlwaysOnTop = true
	gui.LightInfluence = 0
	gui.MaxDistance = 80
	gui.Parent = head
	local disc = Instance.new("Frame")
	disc.AnchorPoint = Vector2.new(0.5, 0.5)
	disc.Position = UDim2.fromScale(0.5, 0.5)
	disc.Size = UDim2.fromScale(0.2, 0.2)
	disc.BackgroundColor3 = Color3.fromRGB(232, 64, 56)
	disc.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = disc
	local edge = Instance.new("UIStroke")
	edge.Color = Color3.fromRGB(14, 14, 20)
	edge.Thickness = 3
	edge.Parent = disc
	local mark = Instance.new("TextLabel")
	mark.BackgroundTransparency = 1
	mark.Size = UDim2.fromScale(1, 1)
	mark.Font = Enum.Font.GothamBlack
	mark.TextScaled = true
	mark.Text = "!"
	mark.TextColor3 = Color3.new(1, 1, 1)
	mark.Parent = disc
	TweenService:Create(disc, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(1, 1) }):Play()
	task.delay(1.6, function()
		local fade = TweenInfo.new(0.35)
		TweenService:Create(disc, fade, { BackgroundTransparency = 1 }):Play()
		TweenService:Create(mark, fade, { TextTransparency = 1 }):Play()
		TweenService:Create(edge, fade, { Transparency = 1 }):Play()
	end)
	task.delay(2.1, function()
		gui:Destroy()
	end)
end

local function approach(current: number, target: number, rate: number, dt: number): number
	return current + (target - current) * math.clamp(rate * dt, 0, 1)
end

local function animate(person: Person, dt: number, now: number, serverNow: number)
	local model = person.model
	local root = model.PrimaryPart or model:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	local frame = root.CFrame

	-- A robbery: is one on, and since when?
	local at = model:GetAttribute("HandsUpAt")
	local hold = model:GetAttribute("HandsUpFor")
	local robbed = typeof(at) == "number" and typeof(hold) == "number"
		and serverNow >= at and serverNow - at < hold
	if robbed and at ~= person.handsUpAt then
		person.handsUpAt = at :: number
		-- Only the start of it is a surprise: arriving mid-robbery, the hands are just up.
		if serverNow - (at :: number) < 1 then
			exclaim(person)
		end
	end
	person.handsUp = approach(person.handsUp, if robbed then 1 else 0, if robbed then 14 else 2.5, dt)

	-- Who to look at: the robber, then whoever they are talking to, then whoever is nearest.
	local look: Vector3? = nil
	local face: Vector3? = nil
	if robbed then
		local robber = Players:GetPlayerByUserId(tonumber(model:GetAttribute("RobberId")) or 0)
		look = headOf(robber and robber.Character)
		face = look
	end
	local mine = headOf(player.Character)
	if not look and now < person.talkUntil and mine then
		look = mine
		face = mine
	end
	if not look then
		local best = NOTICE
		for _, p in ipairs(Players:GetPlayers()) do
			local head = headOf(p.Character)
			if head then
				local d = (head - frame.Position).Magnitude
				if d < best then
					best = d
					look = head
				end
			end
		end
	end
	-- The first time you come close, a wave.
	if mine and not robbed then
		local d = (mine - frame.Position).Magnitude
		if d < GREET and now - person.greetedAt > GREET_AGAIN then
			person.greetedAt = now
			person.waveAt = now
		end
	end

	-- The body turns to face whoever it must (the robber, you mid-conversation); the head does
	-- the rest of the looking.
	local wantYaw = 0
	if face then
		local dir = frame:PointToObjectSpace(face)
		wantYaw = math.clamp(math.atan2(-dir.X, -dir.Z), math.rad(-110), math.rad(110))
	end
	person.bodyYaw = approach(person.bodyYaw, wantYaw, if robbed then 9 else 4, dt)
	local headYaw, headPitch = 0, 0
	if look then
		local body = frame * CFrame.Angles(0, person.bodyYaw, 0)
		headYaw, headPitch = StaffPose.Look(body:PointToObjectSpace(look) - Vector3.new(0, 1.5, 0))
	end
	person.headYaw = approach(person.headYaw, headYaw, 7, dt)
	person.headPitch = approach(person.headPitch, headPitch, 7, dt)

	-- The pose: at rest, then whatever is going on over it.
	local poses = StaffPose.Idle(now, person.seed, if person.clerk then "folded" else nil)
	if now < person.talkUntil then
		local left = person.talkUntil - now
		poses = StaffPose.Blend(poses, StaffPose.Talk(now), math.clamp(math.min(TALK - left, left) * 3, 0, 1))
	end
	if person.waveAt then
		local t = now - person.waveAt
		if t < StaffPose.WAVE then
			poses = StaffPose.Blend(poses, StaffPose.Wave(t), 1)
		else
			person.waveAt = nil
		end
	end
	if person.handsUp > 1e-3 then
		local since = if person.handsUpAt then serverNow - person.handsUpAt else 10
		poses = StaffPose.Blend(poses, StaffPose.HandsUp(since, now), person.handsUp)
	end
	poses.LowerTorso = CFrame.Angles(0, person.bodyYaw, 0) * (poses.LowerTorso or CFrame.identity)
	poses.Head = StaffPose.Neck(person.headYaw, person.headPitch)

	for name, joint in pairs(person.joints) do
		local pose = poses[name]
		if joint.motor.Parent then
			joint.motor.C0 = if pose then joint.rest * pose else joint.rest
		end
	end
	person.posed = true
end

local function step(dt: number)
	local camera = workspace.CurrentCamera
	local eye = if camera then camera.CFrame.Position else Vector3.zero
	local now = os.clock()
	local serverNow = workspace:GetServerTimeNow()
	for _, model in ipairs(CollectionService:GetTagged("Staff")) do
		if model:IsA("Model") and model:IsDescendantOf(workspace) then
			local person = personFor(model)
			if person then
				local pivot = model.PrimaryPart
				local near = pivot ~= nil and (pivot.Position - eye).Magnitude < RANGE
				if near then
					animate(person, dt, now, serverNow)
				else
					release(person)
				end
			end
		end
	end
	for model in pairs(people) do
		if not model:IsDescendantOf(workspace) then
			people[model] = nil
		end
	end
end

-- Talking to one: their own prompt, or the counter of the shop they work in.
ProximityPromptService.PromptTriggered:Connect(function(prompt: ProximityPrompt)
	local anchor = prompt.Parent
	if not anchor then
		return
	end
	local model = anchor:FindFirstAncestorWhichIsA("Model")
	local staff: Model? = if model and model:HasTag("Staff") then model else nil
	if not staff and anchor.Parent then
		local clerk = anchor.Parent:FindFirstChild("Clerk")
		staff = if clerk and clerk:IsA("Model") and clerk:HasTag("Staff") then clerk else nil
	end
	local person = staff and personFor(staff)
	if person and prompt.Name ~= "StickupPrompt" then
		person.talkUntil = os.clock() + TALK
	end
end)

RunService:BindToRenderStep("StaffLife", Enum.RenderPriority.Last.Value - 2, step)
