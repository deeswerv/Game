--!nocheck
-- Where a round comes out of the gun and how it crosses the gap, checked without Studio:
--
--   * the barrel a client draws is where its tracers start -- not the server's origin, which
--     comes from an unposed copy of the gun -- and a fitted suppressor moves it to the can;
--   * a round flies at its class's speed, the streak grows out of the barrel and is
--     swallowed by the impact, a sniper's round leaves a vapour line, and nothing is left
--     in the air afterwards;
--   * the shot handler draws from the drawn barrel and lands the impact when the round does;
--   * the server fires from the barrel the client saw, but only when it is close to the
--     shooter's head and not through a wall.
--
--   lune run tools/uitest/tracers.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R
local Vector3, CFrame, Color3 = roblox.Vector3, roblox.CFrame, roblox.Color3

require("@lune/task").delay(120, function()
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
local function near(a: Vector3, b: Vector3, tolerance: number?): boolean
	return (a - b).Magnitude <= (tolerance or 1e-3)
end

-- One optional wall, as an axis-aligned box, plus any real parts listed in `targets` (tested
-- as boxes too, and returned as themselves so a hit knows what it hit).
local wall = nil
local targets = {}
local function slab(o, d, lo, hi)
	if math.abs(d) < 1e-9 then
		return (o >= lo and o <= hi) and -math.huge or math.huge, (o >= lo and o <= hi) and math.huge or -math.huge
	end
	local a, b = (lo - o) / d, (hi - o) / d
	return math.min(a, b), math.max(a, b)
end
local function boxHit(origin, direction, lo, hi)
	local x0, x1 = slab(origin.X, direction.X, lo.X, hi.X)
	local y0, y1 = slab(origin.Y, direction.Y, lo.Y, hi.Y)
	local z0, z1 = slab(origin.Z, direction.Z, lo.Z, hi.Z)
	local enter, leave = math.max(x0, y0, z0), math.min(x1, y1, z1)
	if enter <= leave and enter >= 0 and enter <= 1 then
		return enter
	end
	return nil
end
R.ClassMethods.Workspace.Raycast = function(_self, origin, direction)
	local best, bestT = nil, math.huge
	if wall then
		local t = boxHit(origin, direction, wall.min, wall.max)
		if t and t < bestT then
			bestT = t
			best = { Position = origin + direction * t, Normal = Vector3.new(0, 0, 1),
				Instance = { Name = "Wall" }, Material = roblox.Enum.Material.Concrete, Distance = t }
		end
	end
	for _, p in ipairs(targets) do
		local c, half = p.CFrame.Position, p.Size / 2
		local t = boxHit(origin, direction, c - half, c + half)
		if t and t < bestT then
			bestT = t
			best = { Position = origin + direction * t, Normal = Vector3.new(0, 0, 1),
				Instance = p, Material = roblox.Enum.Material.Plastic, Distance = t }
		end
	end
	return best
end
local emitted = {}
R.ClassMethods.ParticleEmitter = R.ClassMethods.ParticleEmitter or {}
R.ClassMethods.ParticleEmitter.Emit = function(self, count)
	emitted[self.Name] = (emitted[self.Name] or 0) + count
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
local CombatFX = World.require(rs.CombatFX)

local function part(name, cf, size)
	local p = R.new("Part")
	p.Name = name
	p.Size = size or Vector3.new(0.2, 0.2, 0.2)
	p.CFrame = cf
	return p
end

-- A carbine held out in front of the character, pointing down -Z.
local function carbine(parent)
	local tool = R.new("Tool")
	tool.Name = "Carbine"
	local handle = part("Handle", CFrame.new(1, 4, -1), Vector3.new(0.3, 0.6, 2))
	handle.Parent = tool
	local muzzle = part("Muzzle", CFrame.new(1, 4.5, -3.4), Vector3.new(0.12, 0.12, 0.1))
	muzzle.Parent = tool
	tool.Parent = parent
	return tool, muzzle
end

local function host()
	local bin = World.workspace:FindFirstChild("CombatFX")
	return bin and bin:FindFirstChild("TracerHost")
end
local function countIn(inst, className)
	local n = 0
	if inst then
		for _, c in ipairs(inst:GetChildren()) do
			if c.ClassName == className then
				n += 1
			end
		end
	end
	return n
end

-- ---------------------------------------------------------------- barrel --

print("where the round leaves the gun")
local held, heldMuzzle = carbine(World.workspace)
check(near(CombatFX.MuzzlePoint(held), heldMuzzle.Position), "the drawn Muzzle is the firing point")
local serverOrigin = heldMuzzle.Position + Vector3.new(2.5, -1.5, 1)
check(near(CombatFX.MuzzlePoint(held, serverOrigin), heldMuzzle.Position),
	"the drawn barrel wins over the server's origin a few studs off")
local faraway = heldMuzzle.Position + Vector3.new(60, 0, 0)
check(near(CombatFX.MuzzlePoint(held, faraway), faraway),
	"but not over one so far away the drawn gun must be stale (a teleport, a respawn)")
local loose = R.new("Tool")
loose.Name = "Carbine"
check(CombatFX.MuzzlePoint(loose, serverOrigin) == serverOrigin, "a gun this client cannot draw falls back to the server")

local fitted = R.new("Folder")
fitted.Name = "Attachments"
local can = part("Muzzle_Suppressor", heldMuzzle.CFrame * CFrame.new(0, 0, -0.5), Vector3.new(0.3, 0.3, 1.2))
can.Parent = fitted
fitted.Parent = held
local expected = heldMuzzle.Position + heldMuzzle.CFrame.LookVector * 1.1
check(near(CombatFX.MuzzlePoint(held), expected, 1e-2), "a suppressor moves it to the end of the can")
fitted:Destroy()

-- ---------------------------------------------------------------- flight --

print("the round in flight")
local from = Vector3.new(0, 5, 0)
local hundred = from + Vector3.new(0, 0, -100)
local pistol = CombatFX.FlightTime(from, hundred, "Vantage")
local rifle = CombatFX.FlightTime(from, hundred, "Carbine")
local sniper = CombatFX.FlightTime(from, hundred, "Longshot")
check(sniper < rifle and rifle < pistol, ("a sniper's round is fastest, a pistol's slowest (%.3f < %.3f < %.3f)")
	:format(sniper, rifle, pistol))
local across = CombatFX.FlightTime(from, from + Vector3.new(0, 0, -900), "Vantage")
check(across <= 0.3 + 1e-6, ("a shot across the map still lands promptly (%.2fs)"):format(across))

local target = from + Vector3.new(0, 0, -200)
local flight = CombatFX.Tracer(from, target, Color3.fromRGB(255, 214, 140), 0.09, "Carbine")
check(math.abs(flight - 200 / 980) < 1e-3, ("the tracer reports its flight time (%.3fs)"):format(flight))
check(CombatFX.InFlight() == 1, "one round in the air")
local h = host()
check(countIn(h, "Beam") == 2 and countIn(h, "Attachment") == 2, "a core and a sheath, sharing one host")
local tail, head
for _, beam in ipairs(h:GetChildren()) do
	if beam.ClassName == "Beam" then
		tail, head = beam.Attachment0, beam.Attachment1
	end
end
World.advance(1 / 30)
check(near(tail.Position, from), "the streak starts at the barrel")
check((head.Position - from).Magnitude > 0.5, "and the round is already out of it")
World.advance(0.05)
local headAt = (head.Position - from).Magnitude
local tailAt = (tail.Position - from).Magnitude
local offLine = (head.Position - (from + Vector3.new(0, 0, -headAt))).Magnitude
check(headAt > tailAt and headAt < 200 and offLine < 1e-3,
	("mid-flight the head leads the tail along the line (%.1f ahead of %.1f)"):format(headAt, tailAt))
check(headAt - tailAt <= 12 + 1e-3, ("a rifle's streak is at most 12 studs (%.1f)"):format(headAt - tailAt))
World.advance(0.4)
check(CombatFX.InFlight() == 0 and countIn(h, "Beam") == 0 and countIn(h, "Attachment") == 0,
	"once it lands nothing is left in the air")

CombatFX.Tracer(from, target, Color3.fromRGB(255, 214, 140), 0.12, "Longshot")
check(countIn(host(), "Beam") == 3, "a sniper's round also leaves a vapour line")
World.advance(0.15)
check(CombatFX.InFlight() == 1, "which hangs a moment after the round has landed")
World.advance(0.6)
check(CombatFX.InFlight() == 0 and countIn(host(), "Beam") == 0, "and then clears")

-- ------------------------------------------------------------ shot event --

print("the shot as every client draws it")
local shooterModel = R.new("Model")
shooterModel.Name = "Other"
shooterModel.Parent = World.workspace
local otherGun, otherMuzzle = carbine(shooterModel)
World.serverRemotes({ Remotes = { GunEffect = "RemoteEvent", GunAction = "RemoteEvent",
	MeleeAction = "RemoteEvent", MeleeEffect = "RemoteEvent" } })
World.run(World.service("StarterPlayer").StarterPlayerScripts.WeaponController)
World.advance(0.3)
local endPoint = otherMuzzle.Position + Vector3.new(0, 0, -150)
local stale = otherMuzzle.Position + Vector3.new(1.8, -2.2, 1.5)
World.serverFire("Remotes", "GunEffect", "Shot", { Name = "Other" }, otherGun, stale, { endPoint }, nil)
World.advance(1 / 60)
local drawnTail
for _, c in ipairs(host() and host():GetChildren() or {}) do
	if c.ClassName == "Beam" then
		drawnTail = c.Attachment0
	end
end
check(drawnTail ~= nil and near(drawnTail.Position, otherMuzzle.Position),
	"another player's tracer leaves their drawn barrel, not the server's stale origin")
local bin = World.workspace:FindFirstChild("CombatFX")
local before = #bin:GetChildren()
World.advance(1 / 30)
local early = #bin:GetChildren()
World.advance(0.3)
check(early <= before + 1 and #bin:GetChildren() > early,
	"the impact lands when the round arrives, not when it leaves")

-- ---------------------------------------------------------------- server --

print("the server's origin")
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("KillCredit"), sss)
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("GunHandler"), sss)
local character = World.character
character:FindFirstChild("HumanoidRootPart").CFrame = CFrame.new(0, 3, 0)
character:FindFirstChild("Head").CFrame = CFrame.new(0, 4.5, 0)
character:FindFirstChild("UpperTorso").CFrame = CFrame.new(0, 3.5, 0)
local gun, serverMuzzle = carbine(character)
local cfg = World.require(rs.WeaponConfig).Get("Carbine")
gun:SetAttribute("Ammo", cfg.MagazineSize)
World.run(sss.GunHandler)
World.advance(0.2)

local shots = 0
local function shoot(claimed, aim)
	table.clear(toClients)
	R.fire(rs.Remotes.GunAction, "OnServerEvent", player, "shoot", gun, aim or Vector3.new(0, 4.5, -300), false, claimed)
	World.advance(cfg.FireRate + 0.1)
	shots += 1
	for _, e in ipairs(toClients) do
		if e.name == "GunEffect" and e.args[1] == "Shot" then
			return e.args[4]
		end
	end
	return nil
end

local drawn = Vector3.new(0.9, 4.2, -2.6)
local origin = shoot(drawn)
check(origin ~= nil and near(origin, drawn), "the round leaves from the barrel the shooter's screen drew")
origin = shoot(Vector3.new(0, 4.5, -30))
check(origin ~= nil and near(origin, serverMuzzle.Position), "a barrel 30 studs from the head is not believed")
origin = shoot(Vector3.new(0 / 0, 4, -2))
check(origin ~= nil and near(origin, serverMuzzle.Position), "nor is one that is not a number")
origin = shoot(nil)
check(origin ~= nil and near(origin, serverMuzzle.Position), "an old client that sends none still fires")
-- A thin wall the held barrel pokes through. The shot is aimed along it, so the only thing
-- that can meet the wall is the check between the head and the barrel.
wall = { min = Vector3.new(-5, 0, -2.2), max = Vector3.new(5, 10, -1.8) }
origin = shoot(drawn, Vector3.new(-300, 4.3, -1.7))
check(origin ~= nil and origin.Z > -1.8, ("a barrel through a wall fires from this side of it (z %.2f)")
	:format(origin and origin.Z or 0))
wall = nil
check(gun:GetAttribute("Ammo") == cfg.MagazineSize - shots, "every one of them cost a round")

-- ------------------------------------------------------------ gem charge --

print("the gem charge")
local vfx = rs:FindFirstChild("VFX")
local gem = vfx and vfx:FindFirstChild("gemstoneCharge")
local emitters, beams, anyOn = 0, 0, false
for _, d in ipairs(gem and gem:GetDescendants() or {}) do
	if d.ClassName == "ParticleEmitter" then
		emitters += 1
		anyOn = anyOn or d.Enabled
	elseif d.ClassName == "Beam" then
		beams += 1
		anyOn = anyOn or d.Enabled
	end
end
check(emitters == 22 and beams == 2, ("the imported effect is in the build as authored (%d emitters, %d beams)")
	:format(emitters, beams))
check(not anyOn and gem.Anchored and not gem.CanCollide, "stored switched off and out of physics")

local victim = R.new("Model")
victim.Name = "Victim"
local victimHead = part("Head", CFrame.new(0, 4.5, -60), Vector3.new(1.2, 1.2, 1.2))
victimHead.Parent = victim
victim.Parent = World.workspace
table.clear(emitted)
local lasts = CombatFX.PlayVFX("gemstoneCharge", victimHead.Position, victimHead, 0.5)
check(lasts ~= nil and lasts > 0.65, ("it plays as a timeline (%.2fs)"):format(lasts or 0))
local played
for _, c in ipairs(bin:GetChildren()) do
	if c.Name == "gemstoneCharge" then
		played = c
	end
end
local function emitter(name)
	for _, d in ipairs(played:GetDescendants()) do
		if d.Name == name and d.ClassName == "ParticleEmitter" then
			return d
		end
	end
	return nil
end
World.advance(0.15)
check(emitter("Intake1").Enabled and emitted.Star == nil, "first the charge draws in, and the burst waits")
check(math.abs(emitter("CircleMARK(2)").Size.Keypoints[1].Value - 19.723051 * 0.5) < 1e-3,
	"at half the authored size")
victimHead.CFrame = CFrame.new(3, 2, -60)
World.advance(0.05)
check(near(played.CFrame.Position, victimHead.Position), "and it rides the head it hit as the body falls")
World.advance(0.6)
check(emitted.Star == 10 and emitted.EffectGB == 15 and not emitter("Intake1").Enabled,
	"then the charge stops and the burst goes off, as many as the effect asks for")
World.advance(lasts)
check(played.Parent == nil, "and it is cleared once the last particle is done")

print("which guns show it")
local dm = World.require(rs.WeaponConfig).Get("Carbine_DarkMatter")
local darkMatter = R.new("Tool")
darkMatter.Name = "Carbine_DarkMatter"
part("Handle", CFrame.new(1, 4, -1), Vector3.new(0.3, 0.6, 2)).Parent = darkMatter
local dmMuzzle = part("Muzzle", CFrame.new(1, 4.5, -3.4))
dmMuzzle.Parent = darkMatter
gun.Parent = nil
darkMatter.Parent = character
darkMatter:SetAttribute("Ammo", dm.MagazineSize)
local victimHumanoid = R.new("Humanoid")
victimHumanoid.MaxHealth = 1000
victimHumanoid.Health = 1000
victimHumanoid.Parent = victim
local victimTorso = part("UpperTorso", CFrame.new(0, 2.5, -60), Vector3.new(2, 2, 1))
victimTorso.Parent = victim
victimHead.CFrame = CFrame.new(0, 4.5, -60)
targets = { victimHead, victimTorso }
local function fireAt(tool, aim)
	table.clear(toClients)
	R.fire(rs.Remotes.GunAction, "OnServerEvent", player, "shoot", tool, aim, false, Vector3.new(0, 4.5, -2))
	World.advance(dm.FireRate + 0.1)
	for _, e in ipairs(toClients) do
		if e.name == "GunEffect" and e.args[1] == "HitVFX" then
			return e.args
		end
	end
	return nil
end
-- Pellet spread is random, so the part aimed at is made big enough that a straight shot cannot miss.
victimHead.Size = Vector3.new(4, 1.4, 4)
local sent = fireAt(darkMatter, Vector3.new(0, 4.5, -60))
check(sent ~= nil and sent[2] == "Carbine_DarkMatter" and sent[4] == victim and sent[5] == true,
	"a Dark Matter headshot tells everyone to play the big effect on that head")
victimHead.Size = Vector3.new(1.2, 1.2, 1.2)
victimTorso.Size = Vector3.new(6, 3, 4)
sent = fireAt(darkMatter, Vector3.new(0, 2.5, -60))
check(sent ~= nil and sent[5] == false and (sent[3] - Vector3.new(0, 2.5, -60)).Magnitude < 3,
	"a body shot plays one too, where the round struck")
victimHead.Size = Vector3.new(4, 1.4, 4)
darkMatter.Parent = nil
gun.Parent = character
gun:SetAttribute("Ammo", cfg.MagazineSize)
check(fireAt(gun, Vector3.new(0, 4.5, -60)) == nil, "and an ordinary carbine plays neither")

print("the body burst")
table.clear(emitted)
local quick = CombatFX.PlayVFX("gemstoneCharge", Vector3.new(0, 3, -60), nil, 0.3, true)
local burst
for _, c in ipairs(bin:GetChildren()) do
	if c.Name == "gemstoneCharge" then
		burst = c
	end
end
World.advance(1 / 30)
local streamed = false
for _, d in ipairs(burst:GetDescendants()) do
	if d.ClassName == "ParticleEmitter" and d.Enabled then
		streamed = true
	end
end
check(emitted.Star == 10 and not streamed and quick <= lasts,
	("a body hit bursts at once, with no build-up (%.2fs)"):format(quick or 0))
local beamsLeft = 0
for _, d in ipairs(burst:GetDescendants()) do
	if d.ClassName == "Beam" then
		beamsLeft += 1
	end
end
check(beamsLeft == 0, "and without the charge's ribbons")
World.advance(2)
local flareBefore = #bin:GetChildren()
CombatFX.GemFlare(Vector3.new(0, 4.5, -60))
check(#bin:GetChildren() > flareBefore + 8, "a headshot's crystal flare throws its shards at once")
targets = {}

print(failures == 0 and "\27[32mall tracer checks passed\27[0m" or ("\27[31m%d failed\27[0m"):format(failures))
require("@lune/process").exit(failures == 0 and 0 or 1)
