--!nocheck
-- Weapon sound (WeaponAudio), checked without Studio:
--
--   * the old shotgun sample is gone from every weapon;
--   * the pump shotgun's shot is a deep report shaped by an equaliser, a boom layered under
--     it (with a reverb tail), and the pump racked after every shot -- a short, sharp cut of
--     the reload sample, a moment after the bang;
--   * the sniper has its own crack and tail; rifles and pistols are left as they were (no
--     equaliser, no layers, no pump), and re-stamping a weapon with another profile clears
--     whatever the last one added;
--   * every sound a shot plays is routed to the weapons bus by name (AudioMix).
--
--   lune run tools/uitest/audio.luau

local World = require("./world")
local R = World.R

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
local rs = World.service("ReplicatedStorage")
local WeaponAudio = World.require(rs.WeaponAudio)
local WeaponConfig = World.require(rs.WeaponConfig)

local function toolFor(name: string)
	local tool = R.new("Tool")
	tool.Name = name
	local handle = R.new("Part")
	handle.Name = "Handle"
	handle.Parent = tool
	tool.Parent = World.workspace
	WeaponAudio.Apply(tool, WeaponConfig.Get(name))
	return tool, handle
end

local OLD = "rbxassetid://108048485337530"

print("the pump shotgun")
local shotgun, sh = toolFor("Blackwood")
local fire, body, pump = sh:FindFirstChild("Fire"), sh:FindFirstChild("FireBody"), sh:FindFirstChild("Pump")
check(WeaponConfig.Get("Blackwood").Class == "Shotgun", "the Blackwood is the shotgun")
check(fire and fire.SoundId ~= OLD and fire.SoundId ~= "", "its shot is no longer the old sample (" .. tostring(fire and fire.SoundId) .. ")")
local eq = fire and fire:FindFirstChildOfClass("EqualizerSoundEffect")
check(eq and eq.LowGain > 0 and eq.HighGain < 0, "shaped deep: lows up, the harsh top cut")
check(fire and fire.PlaybackSpeed < 0.9, ("pitched down, heavy (%.2f)"):format(fire and fire.PlaybackSpeed or 0))
check(body and body.SoundId ~= "" and body.PlaybackSpeed < 0.7 and body:FindFirstChildOfClass("ReverbSoundEffect") ~= nil,
	"a boom under it, with a tail")
check(pump and pump.SoundId == WeaponAudio.SFX.Reload and pump.PlaybackSpeed > 1.3 and (pump:GetAttribute("Delay") or 0) > 0.1,
	"and the pump racked after it, fast")

local played = {}
R.ClassMethods.Sound.Play = function(self)
	table.insert(played, { name = self.Name, at = os.clock() })
end
R.ClassMethods.Sound.Stop = function() end
check(WeaponAudio.PlayFire(shotgun), "PlayFire plays it")
local names = {}
for _, p in ipairs(played) do
	names[p.name] = true
end
check(names.Fire and names.FireBody and not names.Pump, "the report and the boom together, at once")
World.advance(0.5)
names = {}
for _, p in ipairs(played) do
	names[p.name] = true
end
check(names.Pump, "then the pump, a moment later")

print("the rest")
local sniper, sn = toolFor("Longshot")
check(sn.Fire.SoundId ~= OLD and sn:FindFirstChild("FireBody") ~= nil and sn:FindFirstChild("Pump") == nil,
	"the sniper: its own crack and tail, no pump")
for name, cfg in pairs(WeaponConfig.Weapons) do
	if cfg.Type == "Gun" then
		local _, h = toolFor(name)
		local f = h:FindFirstChild("Fire")
		check(f == nil or f.SoundId ~= OLD, name .. ": not the old shotgun sample")
	end
end
local _, rifle = toolFor("Carbine")
check(rifle.Fire:FindFirstChildOfClass("EqualizerSoundEffect") == nil and rifle:FindFirstChild("FireBody") == nil
	and rifle:FindFirstChild("Pump") == nil, "a rifle is left as it was")
-- Re-stamped with another profile, the extras go.
WeaponAudio.Apply(shotgun, WeaponConfig.Get("Carbine"))
check(sh.Fire:FindFirstChildOfClass("EqualizerSoundEffect") == nil and sh:FindFirstChild("FireBody") == nil
	and sh:FindFirstChild("Pump") == nil, "re-stamped as a rifle, the shotgun's extras are cleared")

print("the mix")
local mix = require("@lune/fs").readFile("src/ServerScriptService/AudioMix.server.luau")
check(mix:find("FireBody = true", 1, true) ~= nil and mix:find("Pump = true", 1, true) ~= nil,
	"the boom and the pump go on the weapons bus")

if failures == 0 then
	print("\27[32mall audio checks passed\27[0m")
	require("@lune/process").exit(0)
else
	print(("\27[31m%d failed\27[0m"):format(failures))
	require("@lune/process").exit(1)
end
