--!nocheck
-- Hanami Valley's two new ways to fight, checked without Studio through the real code:
--
--   * a Shieldbearer (NPCService.Body) carries an iron shield in front: rounds from the front
--     stop dead on it -- the shot ends there, the holder takes nothing, you still get a
--     hitmarker -- and its health runs down until it breaks: the slab and its trim come off
--     and tumble away, and after that rounds go through to the body. Over the top of it, the
--     head is open; from the side, so is everything (GunHandler);
--   * a Shinobi (NPCService.AI.StateMachine) dashes in from a middling distance -- at its
--     charge pace, with the dust and the whoosh everyone sees -- and not again until its
--     cooldown; up close, it swings instead;
--   * a Shieldbearer squares up and walks in to its range behind the shield, and stops there --
--     never sidestepping; once the shield is gone it fights like anyone else.
--
--   lune run tools/uitest/shields.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R
local Vector3 = roblox.Vector3
local CFrame = World.CFrame -- the engine's lookAt (Lune's turns Z round)

require("@lune/task").delay(150, function()
	print("\27[31mtimed out\27[0m")
	require("@lune/process").exit(2)
end)

local failures = 0
local function check(ok: boolean, what: string)
	if ok then
		print("  ok    " .. what)
	else
		failures += 1
		print("\27[31m  FAIL  " .. what .. "\27[0m")
	end
end

-- Rays against the boxes of everything that can be hit (oriented, as parts are).
local hittable: { any } = {}
local function obbHit(origin: Vector3, direction: Vector3, p): number?
	local o = p.CFrame:PointToObjectSpace(origin)
	local d = p.CFrame:VectorToObjectSpace(direction)
	local half = p.Size / 2
	local enter, leave = -math.huge, math.huge
	for _, axis in ipairs({ "X", "Y", "Z" }) do
		local oa, da, h = o[axis], d[axis], half[axis]
		if math.abs(da) < 1e-9 then
			if oa < -h or oa > h then
				return nil
			end
		else
			local a, b = (-h - oa) / da, (h - oa) / da
			enter = math.max(enter, math.min(a, b))
			leave = math.min(leave, math.max(a, b))
		end
	end
	if enter <= leave and enter >= 0 and enter <= 1 then
		return enter
	end
	return nil
end
R.ClassMethods.Workspace.Raycast = function(_self, origin, direction, params)
	local skip = {}
	for _, inst in ipairs(params and params.FilterDescendantsInstances or {}) do
		skip[inst] = true
	end
	local best, bestT = nil, math.huge
	for _, p in ipairs(hittable) do
		local excluded = false
		local a = p
		while a do
			if skip[a] then
				excluded = true
				break
			end
			a = a.Parent
		end
		if not excluded and p.Parent and p.CanQuery ~= false then
			local t = obbHit(origin, direction, p)
			if t and t < bestT then
				bestT = t
				best = { Position = origin + direction * t, Normal = -direction.Unit, Instance = p,
					Material = roblox.Enum.Material.Plastic, Distance = t * direction.Magnitude }
			end
		end
	end
	return best
end

local toClients = {}
R.ClassMethods.RemoteEvent.FireClient = function(self, _player, ...)
	table.insert(toClients, { name = self.Name, args = { ... } })
end
R.ClassMethods.RemoteEvent.FireAllClients = function(self, ...)
	table.insert(toClients, { name = self.Name, args = { ... } })
end
R.ClassMethods.RemoteEvent.FireServer = function(_self, ...) end

local place = World.loadPlace("build/Game.rbxl")
local rs = World.service("ReplicatedStorage")
local sss = World.service("ServerScriptService")
local player = World.player
local Rig = require("./rig")
Rig.starter(World, place)
for _, name in ipairs({ "KillCredit", "GunHandler", "NPCService", "WeaponPose", "HolsterService", "WeaponDropService" }) do
	R.mirror(place:GetService("ServerScriptService"):FindFirstChild(name), sss)
end
local NPCConfig = World.require(rs.NPCConfig)
local Body = World.require(sss.NPCService.Body)

-- A Shieldbearer standing `at`, looking at `look`: the players' rig, a humanoid, the shield.
local starter = World.service("StarterPlayer"):FindFirstChild("StarterCharacter")
local function shieldbearer(at: Vector3, look: Vector3)
	local model = starter:Clone()
	model.Name = "Kurogane Shieldbearer"
	model:PivotTo(CFrame.lookAt(at, Vector3.new(look.X, at.Y, look.Z)))
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	humanoid.MaxHealth = NPCConfig.Get("Shieldbearer").MaxHealth
	humanoid.Health = humanoid.MaxHealth
	model:SetAttribute("Archetype", "Shieldbearer")
	model.Parent = World.workspace
	Body.AttachShield(model, NPCConfig.Get("Shieldbearer").Shield)
	for _, p in ipairs(model:GetDescendants()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			table.insert(hittable, p)
		end
	end
	return model, humanoid
end

-- The shooter, at the origin, a carbine in hand.
local character = World.character
character:FindFirstChild("HumanoidRootPart").CFrame = CFrame.new(0, 3, 0)
character:FindFirstChild("Head").CFrame = CFrame.new(0, 4.5, 0)
character:FindFirstChild("UpperTorso").CFrame = CFrame.new(0, 3.5, 0)
local tool = R.new("Tool")
tool.Name = "Carbine"
local handle = R.new("Part")
handle.Name = "Handle"
handle.Size = Vector3.new(0.3, 0.6, 2)
handle.CFrame = CFrame.new(1, 4, -1)
handle.Parent = tool
local muzzle = R.new("Part")
muzzle.Name = "Muzzle"
muzzle.Size = Vector3.new(0.1, 0.1, 0.1)
muzzle.CFrame = CFrame.new(1, 4.5, -2.4)
muzzle.Parent = tool
tool.Parent = character
local cfg = World.require(rs.WeaponConfig).Get("Carbine")
World.run(sss.GunHandler)
World.advance(0.2)

local function shoot(at: Vector3, from: Vector3?)
	if from then
		character:FindFirstChild("HumanoidRootPart").CFrame = CFrame.new(from)
		character:FindFirstChild("Head").CFrame = CFrame.new(from + Vector3.new(0, 1.5, 0))
		character:FindFirstChild("UpperTorso").CFrame = CFrame.new(from + Vector3.new(0, 0.5, 0))
		muzzle.CFrame = CFrame.lookAt(from + Vector3.new(0, 1.5, 0), at) * CFrame.new(0, 0, -2)
	end
	tool:SetAttribute("Ammo", cfg.MagazineSize)
	table.clear(toClients)
	R.fire(rs.Remotes.GunAction, "OnServerEvent", player, "shoot", tool, at, false, muzzle.Position)
	World.advance(cfg.FireRate + 0.05)
	local hitmarker, shot = false, nil
	for _, e in ipairs(toClients) do
		if e.name == "GunEffect" and e.args[1] == "Hitmarker" then
			hitmarker = true
		elseif e.name == "GunEffect" and e.args[1] == "Shot" then
			shot = e.args
		end
	end
	return hitmarker, shot
end

-- ------------------------------------------------------------------ the shield --

print("the shield")
local model, humanoid = shieldbearer(Vector3.new(0, 3, -40), Vector3.new(0, 3, 0))
local shield = model:FindFirstChild("Shield")
local torso = model:FindFirstChild("UpperTorso")
check(shield and shield:GetAttribute("ShieldHealth") == NPCConfig.Get("Shieldbearer").Shield.health
	and shield.CanQuery and not shield.Anchored and shield:FindFirstChildOfClass("WeldConstraint"),
	"a Shieldbearer carries a shield, welded on, that rounds can hit")
local trimHittable = false
for _, p in ipairs(model:GetChildren()) do
	if p:IsA("BasePart") and (p.Name == "ShieldRim" or p.Name == "ShieldCrest" or p.Name == "ShieldSlit") and p.CanQuery then
		trimHittable = true
	end
end
check(not trimHittable, "its trim is only for show: nothing stops on it but the slab")
local local_ = torso.CFrame:PointToObjectSpace(shield.Position)
check(local_.Z < -0.5, "it is held in front")
local head = model:FindFirstChild("Head")
check(shield.Position.Y + shield.Size.Y / 2 < head.Position.Y - head.Size.Y / 4,
	"and the head shows over the top of it")

local healthBefore = humanoid.Health
local hitmarker, shot = shoot(torso.Position)
local left = shield:GetAttribute("ShieldHealth")
check(left and left < NPCConfig.Get("Shieldbearer").Shield.health, ("a round at the chest stops on the shield (%d left)"):format(left or -1))
check(humanoid.Health == healthBefore, "the holder takes nothing")
check(hitmarker, "you still see the hit")
check(shot and shot[5] and #shot[5] > 0 and (shot[5][1] - shield.Position).Magnitude < 4, "the round ends at the shield")
shoot(model:FindFirstChild("LeftUpperLeg").Position)
check(shield:GetAttribute("ShieldHealth") < left and humanoid.Health == healthBefore, "so does one at the legs")
shoot(head.Position + Vector3.new(0, 0.2, 0))
check(humanoid.Health < healthBefore, ("one over the top finds the head (%d health)"):format(humanoid.Health))
humanoid.Health = humanoid.MaxHealth

local shots = 0
while model:GetAttribute("ShieldBroken") ~= true and shots < 80 do
	shoot(torso.Position)
	shots += 1
end
check(model:GetAttribute("ShieldBroken") == true, ("it breaks, after %d more rounds"):format(shots))
check(shots >= 6, "not in a couple of shots")
check(shield.Parent ~= model and not shield.CanQuery and shield:FindFirstChildOfClass("WeldConstraint") == nil
	and model:FindFirstChild("ShieldRim") == nil, "the slab and its trim come off and fall away")
healthBefore = humanoid.Health
shoot(torso.Position)
check(humanoid.Health < healthBefore, "after that, rounds reach the body")

print("from the side")
local model2, humanoid2 = shieldbearer(Vector3.new(30, 3, -40), Vector3.new(30, 3, 0))
local torso2 = model2:FindFirstChild("UpperTorso")
local before2 = humanoid2.Health
shoot(torso2.Position, Vector3.new(70, 3, -40))
check(humanoid2.Health < before2 and model2:FindFirstChild("Shield"):GetAttribute("ShieldHealth")
	== NPCConfig.Get("Shieldbearer").Shield.health, "flanked, the shield does not help")

-- ------------------------------------------------------------------- the AI --

print("the dash")
local StateMachine = World.require(sss.NPCService.AI.StateMachine)
local Effects = World.require(sss.NPCService.Effects)
local nextId = 0
local function agentFor(archetype: string, at: Vector3)
	local m = starter:Clone()
	m:PivotTo(CFrame.new(at))
	m.Parent = World.workspace
	local h = m:FindFirstChildOfClass("Humanoid")
	h.MaxHealth = NPCConfig.Get(archetype).MaxHealth
	h.Health = h.MaxHealth
	local moves = {}
	nextId += 1
	local agent = {
		id = nextId,
		cfg = NPCConfig.Get(archetype), model = m, root = m:FindFirstChild("HumanoidRootPart"),
		humanoid = m:FindFirstChildOfClass("Humanoid"), weapons = {}, slot = 1, state = "Engage", memory = {}, threat = {},
		nav = {
			failedAt = -math.huge,
			MoveTo = function(_, pos, pace)
				table.insert(moves, { pos = pos, pace = pace })
			end,
			Stop = function()
				table.insert(moves, { stop = true })
			end,
			RecentlyFailed = function()
				return false
			end,
			Update = function() end,
			Destroy = function() end,
		},
	}
	return agent, moves
end
local target = World.character
local function infoAt(agent, distance: number)
	local pos = agent.root.Position + Vector3.new(0, 0, -distance)
	target:FindFirstChild("HumanoidRootPart").CFrame = CFrame.new(pos)
	return { model = target, root = target:FindFirstChild("HumanoidRootPart"), position = pos, distance = distance, visible = true }
end
local sent = 0
local realSend = Effects.Send
Effects.Send = function(position, kind, ...)
	if kind == "Charge" then
		sent += 1
	end
	return realSend(position, kind, ...)
end
local shinobi, moves = agentFor("Shinobi", Vector3.new(200, 3, 0))
local charge = shinobi.cfg.Charge
local Engage = StateMachine.States.Engage
local now = 100
Engage.update(shinobi, now, infoAt(shinobi, 25))
check(#moves > 0 and moves[#moves].pace == "charge" and sent == 1, "from 25 studs, a Shinobi dashes in (and everyone sees it)")
now += charge.time * 0.5
Engage.update(shinobi, now, infoAt(shinobi, 14))
check(moves[#moves].pace == "charge", "and keeps going for the length of the dash")
now += charge.time
table.clear(moves)
Engage.update(shinobi, now, infoAt(shinobi, 20))
check(sent == 1 and (#moves == 0 or moves[#moves].pace ~= "charge"), "not again until its cooldown")
now += charge.cooldown
Engage.update(shinobi, now, infoAt(shinobi, 20))
check(sent == 2 and moves[#moves].pace == "charge", "then it can")
local close, closeMoves = agentFor("Shinobi", Vector3.new(220, 3, 0))
Engage.update(close, now, infoAt(close, close.cfg.AttackRange * 0.5))
check(close.swing ~= nil and (#closeMoves == 0 or closeMoves[#closeMoves].pace ~= "charge"), "up close it swings instead")
local Navigator = World.require(sss.NPCService.AI.Navigator)
check(Navigator.Pace.charge and Navigator.Pace.charge > 2, "the charge pace is a sprint and then some")
local animator = World.service("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
animator = animator and animator:FindFirstChild("NPCAnimator")
check(animator and animator.Source:find("handlers.Charge", 1, true) ~= nil, "every client draws the dash")

print("the shield wall")
local bearer, bearerMoves = agentFor("Shieldbearer", Vector3.new(300, 3, 0))
bearer.weapons = { { ranged = true, ammo = 12, magazine = 12, tool = { Name = "Sentinel", Parent = nil } } }
bearer.fireReadyAt = math.huge
local ok = pcall(Engage.update, bearer, now, infoAt(bearer, 40))
check(ok and bearerMoves[#bearerMoves] and bearerMoves[#bearerMoves].pace == "walk"
	and math.abs((bearerMoves[#bearerMoves].pos - bearer.root.Position).Magnitude - (40 - bearer.cfg.PreferredRange)) < 1,
	"a Shieldbearer walks straight in to its range")
table.clear(bearerMoves)
pcall(Engage.update, bearer, now + 1, infoAt(bearer, bearer.cfg.PreferredRange))
check(bearerMoves[#bearerMoves] and bearerMoves[#bearerMoves].stop, "and holds there, square on")

print(failures == 0 and "\27[32mall shield and dash checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
require("@lune/process").exit(failures == 0 and 0 or 1)
