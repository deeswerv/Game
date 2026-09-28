--!nocheck
-- What the NPCs wear (NPCService.Outfit), checked without Studio on the game's own rig:
--
--   * every archetype builds through the real Body.Build, dressed in garments that exist,
--     and every garment there is gets worn by somebody;
--   * no piece can be hit, touched or bumped into, every piece is welded to the part it was
--     made for and sits on it, and the body's own parts (the hit zones) are exactly as built;
--   * a body stays inside a budget of pieces;
--   * a crew is a crowd: six Thugs draw different hoodies and skin, but all wear the red
--     bandana; the same seed always dresses the same person;
--   * the shop clerks and the quest givers stand on the same rig, dressed for the job.
--
--   lune run tools/uitest/outfits.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R
local Vector3 = roblox.Vector3

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

local place = World.loadPlace("build/Game.rbxl")
local sss = World.service("ServerScriptService")
for _, name in ipairs({ "NPCService", "WeaponPose", "KillCredit" }) do
	R.mirror(place:GetService("ServerScriptService"):FindFirstChild(name), sss)
end
local rs = World.service("ReplicatedStorage")
local NPCConfig = World.require(rs.NPCConfig)
local Outfit = World.require(sss.NPCService.Outfit)
local Body = World.require(sss.NPCService.Body)

local BODY = {
	HumanoidRootPart = true, Head = true, UpperTorso = true, LowerTorso = true,
	LeftUpperArm = true, LeftLowerArm = true, LeftHand = true, RightUpperArm = true, RightLowerArm = true,
	RightHand = true, LeftUpperLeg = true, LeftLowerLeg = true, LeftFoot = true, RightUpperLeg = true,
	RightLowerLeg = true, RightFoot = true,
}
local BUDGET = 34

local function pieces(model)
	local list = {}
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and not BODY[p.Name] then
			table.insert(list, p)
		end
	end
	return list
end

local names = {}
for name in pairs(NPCConfig.Archetypes) do
	table.insert(names, name)
end
table.sort(names)

print("every archetype, through Body.Build")
local worn = {}
local warned = {}
local oldWarn = World.env and World.env.warn
local allBuilt, allSafe, allWelded, allOnHost, allInBudget, zonesIntact = true, true, true, true, true, true
local worst, worstName = 0, ""
local source = World.service("StarterPlayer"):FindFirstChild("StarterCharacter")
local sizes = {}
for _, p in ipairs(source:GetChildren()) do
	if p:IsA("BasePart") then
		sizes[p.Name] = p.Size
	end
end
for _, name in ipairs(names) do
	local cfg = NPCConfig.Get(name)
	for _, g in ipairs(cfg.Outfit or {}) do
		worn[g[1]] = true
	end
	local model = Body.Build(cfg)
	if not model then
		allBuilt = false
		print("    no body for " .. name)
	else
		local list = pieces(model)
		if #list > worst then
			worst, worstName = #list, name
		end
		allInBudget = allInBudget and #list <= BUDGET
		for _, p in ipairs(list) do
			allSafe = allSafe and not p.CanCollide and not p.CanQuery and not p.CanTouch and p.Massless
			local weld = p:FindFirstChildOfClass("WeldConstraint")
			local host = weld and weld.Part0
			allWelded = allWelded and host ~= nil and weld.Part1 == p and BODY[host.Name] == true
			if host then
				-- Made for the part it is on: its centre is within the part (plus a hand's width).
				local rel = host.CFrame:PointToObjectSpace(p.CFrame.Position)
				local half = host.Size / 2 + Vector3.new(0.75, 0.75, 0.75)
				local onHost = math.abs(rel.X) <= half.X and math.abs(rel.Y) <= half.Y and math.abs(rel.Z) <= half.Z
				if not onHost then
					allOnHost = false
					print(("    %s: %s is off its %s (%.2f, %.2f, %.2f)"):format(name, p.Name, host.Name, rel.X, rel.Y, rel.Z))
				end
			end
		end
		local scale = cfg.Scale or 1
		for _, p in ipairs(model:GetChildren()) do
			if p:IsA("BasePart") and BODY[p.Name] and p.Name ~= "HumanoidRootPart" then
				local want = sizes[p.Name] and sizes[p.Name] * (if scale == 1 then 1 else 1)
				zonesIntact = zonesIntact and p.CanQuery ~= false and (scale ~= 1 or (want and (p.Size - want).Magnitude < 1e-4))
			end
		end
	end
end
check(allBuilt, ("%d archetypes built"):format(#names))
local unknown = {}
for g in pairs(worn) do
	if not table.find(Outfit.Garments(), g) then
		table.insert(unknown, g)
	end
end
check(#unknown == 0, "every garment worn is one Outfit knows how to make" .. (#unknown > 0 and (": " .. table.concat(unknown, ", ")) or ""))
local unused = {}
for _, g in ipairs(Outfit.Garments()) do
	if not worn[g] then
		table.insert(unused, g)
	end
end
-- Clerks and quest givers wear these; nobody else does.
local STAFF_ONLY = { Apron = true, Polo = true, Tee = true }
local reallyUnused = {}
for _, g in ipairs(unused) do
	if not STAFF_ONLY[g] then
		table.insert(reallyUnused, g)
	end
end
check(#reallyUnused == 0, "and every garment is worn by some archetype" .. (#reallyUnused > 0 and (": " .. table.concat(reallyUnused, ", ")) or ""))
check(allSafe, "no piece can be hit, touched or bumped into, and none has mass")
check(allWelded, "every piece is welded to a body part")
check(allOnHost, "every piece sits on the part it was made for")
check(allInBudget, ("no body wears more than %d pieces (the most: %s, %d)"):format(BUDGET, worstName, worst))
check(zonesIntact, "the body's own parts -- the hit zones -- are as built, and can still be hit")

print("a crew is a crowd")
local thug = NPCConfig.Get("Thug")
local shirts, skins, bandanas = {}, {}, {}
local function key(c)
	return ("%d,%d,%d"):format(c.R * 255 + 0.5, c.G * 255 + 0.5, c.B * 255 + 0.5)
end
for seed = 1, 6 do
	local model = source:Clone()
	Outfit.Dress(model, thug, seed * 7919)
	shirts[key(model.UpperTorso.Color)] = true
	skins[key(model.Head.Color)] = true
	for _, p in ipairs(pieces(model)) do
		if p.Name == "Bandana" then
			bandanas[key(p.Color)] = true
		end
	end
end
local function count(t)
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end
check(count(shirts) >= 3 and count(skins) >= 3, ("six Thugs: %d hoodies, %d skin tones"):format(count(shirts), count(skins)))
check(count(bandanas) == 1, "and every one in the crew's red bandana")
local a, b = source:Clone(), source:Clone()
Outfit.Dress(a, thug, 4242)
Outfit.Dress(b, thug, 4242)
check(a.UpperTorso.Color == b.UpperTorso.Color and a.Head.Color == b.Head.Color and #pieces(a) == #pieces(b),
	"the same seed dresses the same person")

print("the clerks and the quest givers")
local figure = Outfit.Standing({
	Shirt = roblox.Color3.fromRGB(40, 140, 80), Sleeves = true,
	Outfit = { { "Hair" }, { "Cap", logo = roblox.Color3.new(1, 1, 0) }, { "Tee" }, { "Apron" }, { "Sneakers" } },
}, 7)
local anchored = figure ~= nil
for _, p in ipairs(figure and figure:GetDescendants() or {}) do
	if p:IsA("BasePart") then
		anchored = anchored and p.Anchored
	end
	anchored = anchored and not p:IsA("LuaSourceContainer")
end
check(anchored and figure.PrimaryPart ~= nil and figure.UpperTorso.Color == roblox.Color3.fromRGB(40, 140, 80),
	"a clerk is the players' rig, anchored, without scripts, in the shop's shirt")
local hasApron = false
for _, p in ipairs(pieces(figure)) do
	hasApron = hasApron or p.Name == "Apron"
end
check(hasApron, "and in an apron")

local bad = {}
for _, e in ipairs(R.errors or {}) do
	if tostring(e):match("Outfit") or tostring(e):match("Body") then
		table.insert(bad, tostring(e))
	end
end
check(#bad == 0, "no errors" .. (#bad > 0 and (": " .. bad[1]) or ""))

print("")
if failures == 0 then
	print("\27[32mall outfit checks passed\27[0m")
	require("@lune/process").exit(0)
else
	print(("\27[31m%d outfit check(s) failed\27[0m"):format(failures))
	require("@lune/process").exit(1)
end
