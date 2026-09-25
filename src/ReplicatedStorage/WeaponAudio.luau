--!strict
-- What each weapon sounds like.
--
-- Every gun in the place shipped sharing one fire sample at one pitch, and no reload
-- sound at all -- a pump shotgun and a machine pistol were literally the same noise. Sound
-- is most of what separates weapons in the hand, so this maps the sample, pitch and
-- loudness per class and stamps them onto the Tool templates.
--
-- Assignment is by class rather than by weapon name, so a weapon added later is covered
-- the moment it declares a Class in WeaponConfig.

local WeaponAudio = {}

-- Every id here was checked to load and report a non-zero length before being used; a
-- SoundId that fails to resolve is silent with no error, which is miserable to debug.
local SFX = {
	RifleShort = "rbxassetid://113450029049580", -- 0.43s, tight enough for automatic fire
	Shotgun = "rbxassetid://108048485337530", -- 1.19s
	Pistol = "rbxassetid://92967624763578", -- 0.88s
	Reload = "rbxassetid://117963160131194", -- 1.00s
	Swing = "rbxassetid://5789211405", -- 0.30s
}

-- REQUIRED ASSET -- NOT PROVIDED.
--
-- These three are wired end to end: the Sound instances are created on every weapon and the
-- code that plays them is live. They simply make no noise, because a Sound with an empty
-- SoundId is silent and harmless. Drop a real id in here and that slot starts working --
-- one line each, no other change anywhere.
--
-- Do not paste an id from another game: Roblox checks asset ownership at load, so a borrowed
-- id resolves to nothing and fails silently, which is exactly the miserable-to-debug case the
-- comment above warns about. Buy, upload, or record.
local PENDING = {
	Equip = "",     -- weapon coming up; short, mechanical
	Unequip = "",   -- weapon going away; quieter than equip
	Empty = "",     -- dry fire on an empty magazine; a click, not a bang
}

-- Pitch does the heavy lifting. The same crack at 0.9 reads as a heavier weapon and at
-- 1.25 as a lighter, faster one, which is far more convincing than volume alone.
type Profile = { fire: string, pitch: number, volume: number, reloadPitch: number }

local PROFILES: { [string]: Profile } = {
	Rifle = { fire = SFX.RifleShort, pitch = 1.00, volume = 0.5, reloadPitch = 1.0 },
	SMG = { fire = SFX.RifleShort, pitch = 1.22, volume = 0.4, reloadPitch = 1.15 },
	Shotgun = { fire = SFX.Shotgun, pitch = 0.95, volume = 0.65, reloadPitch = 0.85 },
	Pistol = { fire = SFX.Pistol, pitch = 1.05, volume = 0.5, reloadPitch = 1.1 },
	Sniper = { fire = SFX.Shotgun, pitch = 0.8, volume = 0.7, reloadPitch = 0.9 },
}

local MELEE: Profile = { fire = SFX.Swing, pitch = 1.0, volume = 0.45, reloadPitch = 1.0 }

-- Anything without its own entry falls back to the rifle profile rather than going silent.
local DEFAULT_GUN = PROFILES.Rifle

local function profileFor(cfg): Profile
	if cfg == nil then
		return DEFAULT_GUN
	end
	if cfg.Type == "Melee" then
		return MELEE
	end
	return PROFILES[cfg.Class] or DEFAULT_GUN
end

local function ensureSound(parent: Instance, name: string): Sound
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Sound") then
		return existing
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.Parent = parent
	return s
end

--- Stamp the right sounds onto one Tool. Safe to call repeatedly.
function WeaponAudio.Apply(tool: Tool, cfg)
	local handle = tool:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		return false
	end

	local p = profileFor(cfg)

	local fire = ensureSound(handle, "Fire")
	fire.SoundId = p.fire
	fire.Volume = p.volume
	fire.PlaybackSpeed = p.pitch
	-- Heard in the world, not in the head: a shot should get quieter with distance so a
	-- firefight across the map does not sit on top of the player's own weapon.
	fire.RollOffMode = Enum.RollOffMode.InverseTapered
	fire.RollOffMinDistance = 12
	fire.RollOffMaxDistance = 260

	local reload = ensureSound(handle, "Reload")
	reload.SoundId = SFX.Reload
	reload.Volume = 0.45
	reload.PlaybackSpeed = p.reloadPitch
	reload.RollOffMode = Enum.RollOffMode.InverseTapered
	reload.RollOffMinDistance = 8
	reload.RollOffMaxDistance = 90

	-- Handling sounds: close-range, quiet, and currently silent (see PENDING). They are
	-- created regardless so the slot is visible in the Explorer and fillable by hand too.
	for name, id in pairs(PENDING) do
		local sound = ensureSound(handle, name)
		sound.SoundId = id
		sound.Volume = name == "Empty" and 0.35 or 0.3
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
		sound.RollOffMinDistance = 6
		sound.RollOffMaxDistance = 45
	end

	return true
end

--- Play a one-shot sound already stamped on a tool.
---
--- A slot with no id is skipped rather than played, so an unfilled PENDING entry costs
--- nothing and never spams the log. Callers do not need to know which slots are filled.
function WeaponAudio.Play(tool: Tool?, name: string): boolean
	local handle = tool and tool:FindFirstChild("Handle")
	local sound = handle and handle:FindFirstChild(name)
	if sound and sound:IsA("Sound") and sound.SoundId ~= "" then
		sound:Play()
		return true
	end
	return false
end

--- A small random pitch shift per shot.
--- Held-down automatic fire replaying one identical sample is the single thing that makes
--- a gun sound like a loop instead of a weapon; a few percent of variation removes it.
function WeaponAudio.Vary(sound: Sound, basePitch: number?)
	local base = basePitch or sound:GetAttribute("BasePitch")
	if not base then
		base = sound.PlaybackSpeed
		sound:SetAttribute("BasePitch", base)
	end
	sound.PlaybackSpeed = base * (0.94 + math.random() * 0.12)
end

WeaponAudio.Profiles = PROFILES
WeaponAudio.SFX = SFX
WeaponAudio.Pending = PENDING

return WeaponAudio
