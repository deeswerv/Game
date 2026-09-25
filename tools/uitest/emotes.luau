--!nocheck
-- The emote pack, checked without Studio:
--
--   * the wheel's list: forty emotes, five pages of eight, every keyframe emote has its data
--     and every data module is on the wheel, every prop exists;
--   * the converted tracks reproduce the pack's own keyframes (assets/emotes) to within a
--     hundredth of a stud and a degree, for all 32 emotes;
--   * sampling: loops wrap, play-once emotes hold their last frame, an intro plays first;
--   * the server marks and clears the character (EmoteService): attributes on, weapon away,
--     a play-once emote ends on time, the remote's "" stops it, taking damage stops it;
--   * every client poses the character from those attributes (EmoteAnimator) -- the joints
--     land exactly on rest * pose, the prop appears, and both go away when it ends;
--   * the wheel pages, and a slot key sends the right emote.
--
--   lune run tools/uitest/emotes.luau

local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R
local CFrame = roblox.CFrame

local failures = 0
local function check(ok: boolean, what: string)
	if ok then
		print("  ok    " .. what)
	else
		failures += 1
		print("\27[31m  FAIL  " .. what .. "\27[0m")
	end
end

local function angle(a, b): number
	local _, theta = (a.Rotation:Inverse() * b.Rotation):ToAxisAngle()
	return math.deg(math.abs(theta))
end

local sent = {}
R.ClassMethods.RemoteEvent.FireServer = function(self, ...)
	table.insert(sent, { name = self.Name, args = { ... } })
end

local place = World.loadPlace("build/Game.rbxl")
local rs = World.service("ReplicatedStorage")
local EmoteConfig = World.require(rs.EmoteConfig)
local EmotePlayer = World.require(rs.EmotePlayer)
local EmoteProps = World.require(rs.EmoteProps)
local Index = World.require(rs.EmoteData.Index)

-- ------------------------------------------------------------------ list --

print("the list")
local ids, total, keyframes = {}, 0, 0
local unique = true
for _, e in ipairs(EmoteConfig.Emotes) do
	total += 1
	if ids[e.id] then
		unique = false
	end
	ids[e.id] = true
	if e.keyframe then
		keyframes += 1
	end
end
check(unique and total == 40, ("forty emotes, no id twice (%d)"):format(total))
check(keyframes == 32, ("all 32 from the pack are on the wheel (%d)"):format(keyframes))
local pagesOk = #EmoteConfig.Pages == 5
for _, page in ipairs(EmoteConfig.Pages) do
	local n = #EmoteConfig.OnPage(page.name)
	if n ~= 8 then
		pagesOk = false
		print("    " .. page.name .. " has " .. n)
	end
end
check(pagesOk, "five pages of exactly eight")
local dataOk, missing = true, {}
for _, e in ipairs(EmoteConfig.Emotes) do
	if e.keyframe and (not rs.EmoteData:FindFirstChild(e.id) or not Index[e.id]) then
		dataOk = false
		table.insert(missing, e.id)
	end
	if not e.keyframe and not (e.animation and e.animation:match("^rbxassetid://%d+$")) then
		dataOk = false
		table.insert(missing, e.id .. " (no animation)")
	end
	if e.icon == "" or e.name == "" then
		dataOk = false
	end
end
check(dataOk, "every keyframe emote has its data, every classic one its asset" ..
	(#missing > 0 and (": " .. table.concat(missing, ", ")) or ""))
local orphans = {}
for _, m in ipairs(rs.EmoteData:GetChildren()) do
	if m.Name ~= "Index" and not (EmoteConfig.Get(m.Name) and EmoteConfig.Get(m.Name).keyframe) then
		table.insert(orphans, m.Name)
	end
end
check(#orphans == 0, "every data module is on the wheel" .. (#orphans > 0 and (": " .. table.concat(orphans, ", ")) or ""))
local kinds = {}
for _, k in ipairs(EmoteProps.Kinds()) do
	kinds[k] = true
end
local propsOk = true
for _, e in ipairs(EmoteConfig.Emotes) do
	if e.prop and not kinds[e.prop] then
		propsOk = false
		print("    no prop " .. e.prop)
	end
end
check(propsOk, "every prop an emote asks for exists")

-- -------------------------------------------------------------- fidelity --

print("fidelity against the pack")
-- The converter's own table says which folder each emote came from.
local converter = fs.readFile("tools/emotes/convert.luau")
local folders = {}
for id, folder, main in converter:gmatch('{ "(%w+)", "([^"]+)", "(%w+)"') do
	folders[id] = { folder = folder, main = main }
end
local pack = roblox.deserializeModel(fs.readFile("assets/emotes/EmotePack_R15R6.rbxm"))[1]
local worstP, worstR, worstAt, compared = 0, 0, "", 0
for id, info in pairs(folders) do
	local clip = EmotePlayer.FromData(World.require(rs.EmoteData[id]))
	local r15 = pack:FindFirstChild(info.folder):FindFirstChild("R15")
	local sequence = r15:FindFirstChild(info.folder .. " R15 " .. info.main .. "_KeyframeSequence")
	for _, kf in ipairs(sequence:GetChildren()) do
		if kf:IsA("Keyframe") then
			for _, pose in ipairs(kf:GetDescendants()) do
				local track = pose:IsA("Pose") and pose.Weight > 0 and clip.joints[pose.Name]
				if track then
					-- Key times are stored to the millisecond, so look at the time as stored.
					-- (Many keys are "Constant" -- baked at 30 fps, stepping at exactly their
					-- time -- so a fraction of a millisecond either side is the previous frame.)
					local got = EmotePlayer.Sample(track, math.floor(kf.Time * 1000 + 0.5) / 1000)
					local dp = (got.Position - pose.CFrame.Position).Magnitude
					local dr = angle(got, pose.CFrame)
					compared += 1
					if dp > worstP then
						worstP, worstAt = dp, ("%s %s @%.2f"):format(id, pose.Name, kf.Time)
					end
					worstR = math.max(worstR, dr)
				end
			end
		end
	end
end
check(compared > 50000, ("compared %d keyframe poses across the pack"):format(compared))
check(worstP < 0.02, ("positions within 0.02 studs (worst %.4f, %s)"):format(worstP, worstAt))
check(worstR < 1.0, ("rotations within a degree (worst %.2f)"):format(worstR))

-- -------------------------------------------------------------- sampling --

print("sampling")
local dance = EmotePlayer.Load("OrangeJustice")
local a = EmotePlayer.PoseAt(dance, 1.3)
local b = EmotePlayer.PoseAt(dance, 1.3 + dance.length * 2)
local loopOk = true
for name, cf in pairs(a) do
	if (cf.Position - b[name].Position).Magnitude > 1e-4 or angle(cf, b[name]) > 0.01 then
		loopOk = false
	end
end
check(dance.loop and loopOk, "a looping emote is the same one lap later")
local bow = EmotePlayer.Load("DramaticBow")
local last, later = EmotePlayer.PoseAt(bow, bow.length), EmotePlayer.PoseAt(bow, bow.length + 30)
local holdOk = not bow.loop
for name, cf in pairs(last) do
	if (cf.Position - later[name].Position).Magnitude > 1e-4 then
		holdOk = false
	end
end
check(holdOk, "a play-once emote holds its last frame")
local toilet = EmotePlayer.Load("ToiletSit")
check(toilet.intro ~= nil and math.abs(EmotePlayer.Duration(toilet) - (toilet.length + toilet.intro.length)) < 1e-6,
	("Toilet Break sits down first (%.2fs) before it loops"):format(toilet.intro and toilet.intro.length or 0))
local early = EmotePlayer.PoseAt(toilet, 0.5)
local track = toilet.intro.joints.LowerTorso
check(track and (early.LowerTorso.Position - EmotePlayer.Sample(track, 0.5).Position).Magnitude < 1e-6,
	"half a second in, it is playing the intro")
local main = EmotePlayer.PoseAt(toilet, toilet.intro.length + 0.5)
check((main.LowerTorso.Position - EmotePlayer.Sample(toilet.joints.LowerTorso, 0.5).Position).Magnitude < 1e-6,
	"after the intro, the main loop from its start")
local tpose = EmotePlayer.Load("TPose")
check(tpose.length == 0 and EmotePlayer.PoseAt(tpose, 12).RightUpperArm ~= nil, "a single-frame emote (T-Pose) holds")

-- ----------------------------------------------------------------- props --

print("props")
for _, kind in ipairs(EmoteProps.Kinds()) do
	local prop = EmoteProps.Build(kind, World.workspace)
	local parts, solid = 0, 0
	for _, d in ipairs(prop.model:GetDescendants()) do
		if d:IsA("BasePart") then
			parts += 1
			if d.CanCollide or d.CanQuery or d.CanTouch or not d.Anchored then
				solid += 1
			end
		end
	end
	check(parts >= 4 and solid == 0, ("%s: %d parts, none that block or can be hit"):format(kind, parts))
	EmoteProps.Destroy(prop)
end

-- ---------------------------------------------------------------- server --

print("server")
local sss = World.service("ServerScriptService")
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("EmoteService"), sss)

-- The game's own rig, so there are real joints to pose.
local player = World.player
local source = place:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
local rig = R.mirror(source, World.workspace)
rig.Name = player.Name
-- The mirror does not carry references between instances; wire each joint's parts back up.
for _, sourceMotor in ipairs(source:GetDescendants()) do
	if sourceMotor:IsA("Motor6D") and sourceMotor.Part0 and sourceMotor.Part1 then
		local motor = nil
		for _, c in ipairs(rig:FindFirstChild(sourceMotor.Parent.Name):GetChildren()) do
			if c.ClassName == "Motor6D" and c.Name == sourceMotor.Name then
				motor = c
			end
		end
		World.force(motor, "Part0", rig:FindFirstChild(sourceMotor.Part0.Name))
		World.force(motor, "Part1", rig:FindFirstChild(sourceMotor.Part1.Name))
		-- No animator runs here, so the animated part of each joint is at rest.
		World.force(motor, "Transform", CFrame.new())
	end
end
World.force(player, "Character", rig)
local humanoid = rig:FindFirstChildOfClass("Humanoid")
humanoid.MaxHealth = 100
humanoid.Health = 100
local rigRoot = rig:FindFirstChild("HumanoidRootPart")
rig.PrimaryPart = rigRoot
rigRoot.CFrame = CFrame.new(0, 3, 0)
-- Standing still: what the engine would report for a character that is not moving.
World.force(humanoid, "MoveDirection", roblox.Vector3.new(0, 0, 0))
World.force(humanoid, "Jump", false)
World.force(rigRoot, "AssemblyLinearVelocity", roblox.Vector3.new(0, 0, 0))

local EmoteService = World.require(sss.EmoteService)
World.advance(0.1)

local tool = R.new("Tool")
tool.Name = "Pistol"
tool.Parent = rig
-- ChildAdded for the tool above would cancel an emote; start after it.
World.advance(0.05)
check(EmoteService.Play(player, "OrangeJustice") == true, "a keyframe emote starts")
check(rig:GetAttribute("Emote") == "OrangeJustice" and type(rig:GetAttribute("EmoteAt")) == "number",
	"the character is marked with the emote and when it began")
check(tool.Parent ~= rig, "the weapon is put away")
check(EmoteService.Play(player, "BoogieDown") == false, "not again inside the cooldown")
check(EmoteService.Play(player, "NoSuchDance") == false, "an unknown id is refused")
World.advance(0.7)
R.fire(rs.Remotes.EmotePlay, "OnServerEvent", player, "")
check(rig:GetAttribute("Emote") == nil and rig:GetAttribute("EmoteAt") == nil, "the remote's empty id stops it")
check(EmoteService.Duration("Threaten") == 4 and EmoteService.Duration("OrangeJustice") == nil
	and EmoteService.Duration("TPose") == nil, "play-once emotes have a length; loops and held poses do not")
World.advance(0.7)
EmoteService.Play(player, "ThumbsUp")
humanoid.Health = 80
check(rig:GetAttribute("Emote") == nil, "taking damage stops it")
humanoid.Health = 100

-- ---------------------------------------------------------------- client --

print("client")
local rests = {}
for _, d in ipairs(place:GetService("StarterPlayer").StarterCharacter:GetDescendants()) do
	if d:IsA("Motor6D") and d.Part1 then
		rests[d.Part1.Name] = d.C0
	end
end
local function motorFor(partName: string)
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("Motor6D") and d.Part1 and d.Part1.Name == partName then
			return d
		end
	end
	return nil
end

local scripts = World.service("StarterPlayer").StarterPlayerScripts
World.run(scripts.EmoteAnimator)
World.advance(0.1)
local startedAt = World.workspace:GetServerTimeNow()
rig:SetAttribute("EmoteAt", startedAt)
rig:SetAttribute("Emote", "Breakdance")
World.advance(0.6)
local shoulder = motorFor("RightUpperArm")
local clip = EmotePlayer.Load("Breakdance")
-- The frame's exact time is not visible from here, so find the moment it matches best.
local best = math.huge
local now = World.workspace:GetServerTimeNow() - startedAt
for step = 0, 60 do
	local t = now - step * 0.005
	if t >= 0 then
		local pose = EmotePlayer.PoseAt(clip, t)
		local want = rests.RightUpperArm * pose.RightUpperArm
		best = math.min(best, (shoulder.C0.Position - want.Position).Magnitude + angle(shoulder.C0, want) / 100)
	end
end
check(best < 0.01, ("a joint sits exactly at rest * pose (off by %.4f)"):format(best))
check(angle(shoulder.C0, rests.RightUpperArm) > 5, "and that is visibly away from rest")
check(EmotePlayer.Posing[rig] == true, "the head look is told to stand aside")

rig:SetAttribute("Emote", "ToiletSit")
World.advance(0.3)
check(World.workspace:FindFirstChild("EmoteProp_Toilet") ~= nil, "switching to Toilet Break brings the toilet")
rig:SetAttribute("Emote", nil)
rig:SetAttribute("EmoteAt", nil)
World.advance(0.6)
check(World.workspace:FindFirstChild("EmoteProp_Toilet") == nil, "and it goes when the emote ends")
local home = true
for name, rest in pairs(rests) do
	local motor = motorFor(name)
	if motor and ((motor.C0.Position - rest.Position).Magnitude > 1e-4 or angle(motor.C0, rest) > 0.01) then
		home = false
	end
end
check(home, "every joint is back at rest")
check(EmotePlayer.Posing[rig] == nil, "and the head look has it back")

-- ----------------------------------------------------------------- wheel --

print("wheel")
World.run(scripts.EmoteWheel)
World.advance(0.2)
local gui = World.playerGui:FindFirstChild("EmoteWheel")
check(gui ~= nil and not gui.Enabled, "the wheel is built, hidden")
World.holdKey(roblox.Enum.KeyCode.G, true)
World.advance(0.1)
check(gui.Enabled and player:GetAttribute("UIOpen") == true, "holding G opens it and frees the mouse")
local slot1 = World.find(gui, "Slot1")
check(slot1 and slot1:GetAttribute("EmoteId") == "Wave", "it opens on Classic")
World.click(World.find(gui, "Next"))
World.advance(0.1)
check(slot1:GetAttribute("EmoteId") == "OrangeJustice" and player:GetAttribute("EmotePage") == "Dances",
	"the next page is Dances")
World.click(World.find(gui, "Props"))
World.advance(0.1)
check(slot1:GetAttribute("EmoteId") == "ToiletSit", "the Props tab jumps straight there")
table.clear(sent)
World.holdKey(roblox.Enum.KeyCode.Two, true)
World.advance(0.05)
local fired = sent[1]
check(fired and fired.name == "EmotePlay" and fired.args[1] == "CouchNap", "2 plays the second slot (Couch Nap)")
check(not gui.Enabled, "and closes the wheel")
check(player:GetAttribute("UIOpen") == true, "holding the menu flag a moment, so 2 does not also draw a weapon")
World.holdKey(roblox.Enum.KeyCode.Two, false)
World.holdKey(roblox.Enum.KeyCode.G, false)
World.advance(0.3)
check(player:GetAttribute("UIOpen") ~= true, "then letting it go")

print(failures == 0 and "\27[32mall emote checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
require("@lune/process").exit(failures == 0 and 0 or 1)
