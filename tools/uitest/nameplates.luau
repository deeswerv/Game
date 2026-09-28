--!nocheck
-- Name tags (Nameplates.client), checked without Studio:
--
--   * an enemy gets a plate with its level and name, over a shorter distance than a player's,
--     and never through walls;
--   * an elite wears a star on the plate and a district boss a crown; nobody else does.
--
-- (The "!" and "?" over an enemy's head are the AI's own callouts: NPCAnimator draws them.)
--
--   lune run tools/uitest/nameplates.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R
local Vector3 = roblox.Vector3
local CFrame = World.CFrame

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

World.loadPlace("build/Game.rbxl")
local folder = R.new("Folder")
folder.Name = "NPCs"
folder.Parent = World.workspace

local function npc(name: string, attributes: { [string]: any })
	local model = R.new("Model")
	model.Name = name
	local head = R.new("Part")
	head.Name = "Head"
	head.CFrame = CFrame.new(Vector3.new(0, 5, -20))
	head.Parent = model
	local humanoid = R.new("Humanoid")
	humanoid.MaxHealth = 100
	humanoid.Health = 100
	humanoid.Parent = model
	for key, value in pairs(attributes) do
		model:SetAttribute(key, value)
	end
	model.Parent = folder
	return model, head
end

local _, thugHead = npc("Thug", { Archetype = "Thug", Level = 3, Faction = "Hostile", State = "Idle" })
World.run(World.service("StarterPlayer"):FindFirstChild("StarterPlayerScripts"):FindFirstChild("Nameplates"))
World.advance(0.3)

print("an enemy's plate")
local plate = thugHead:FindFirstChild("Nameplate")
local nameLabel = plate and plate:FindFirstChild("PlayerName")
check(plate and nameLabel and nameLabel.Text:find("Thug", 1, true) and nameLabel.Text:find("3", 1, true),
	"level and name: " .. tostring(nameLabel and nameLabel.Text))
check(plate and plate.MaxDistance < 150 and not plate.AlwaysOnTop, ("shown to %s studs, not through walls"):format(
	tostring(plate and plate.MaxDistance)))

print("who it is")
local _, eliteHead = npc("Quick Gangster", { Archetype = "Gangster", Level = 9, Faction = "Hostile", State = "Idle", Elite = true })
local _, bossHead = npc("The Kingpin", { Archetype = "Kingpin", Level = 12, Faction = "Hostile", State = "Idle" })
local _, guardHead = npc("Town Guard", { Archetype = "Guard", Level = 4, Faction = "Guard", State = "Idle" })
World.advance(0.3)
local function text(head)
	local p = head:FindFirstChild("Nameplate")
	local l = p and p:FindFirstChild("PlayerName")
	return l and l.Text or ""
end
check(text(eliteHead):find("★", 1, true) ~= nil, "an elite wears a star: " .. text(eliteHead))
check(text(bossHead):find("👑", 1, true) ~= nil, "the Kingpin a crown: " .. text(bossHead))
check(text(guardHead):find("Town Guard", 1, true) and not text(guardHead):find("★", 1, true)
	and not text(guardHead):find("👑", 1, true) and not text(thugHead):find("★", 1, true),
	"a guard or a plain Thug wears neither")

local bad = {}
for _, e in ipairs(R.errors or {}) do
	if tostring(e):match("Nameplates") then
		table.insert(bad, tostring(e))
	end
end
check(#bad == 0, "no errors" .. (#bad > 0 and (": " .. bad[1]) or ""))

print("")
if failures == 0 then
	print("\27[32mall nameplate checks passed\27[0m")
	require("@lune/process").exit(0)
else
	print(("\27[31m%d nameplate check(s) failed\27[0m"):format(failures))
	require("@lune/process").exit(1)
end
