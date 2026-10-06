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
	Pistol = "rbxassetid://92967624763578", -- 0.88s
	Reload = "rbxassetid://117963160131194", -- 1.00s
	Swing = "rbxassetid://5789211405", -- 0.30s
}
-- (The old shotgun sample, 108048485337530, is gone: players found it off-putting. The
-- shotgun and the sniper are now built from the samples above -- a report, a boom under it,
-- shaped with an equaliser -- and the pump gun racks after every shot.)

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
-- A layer is a second sound played with the shot (the boom under a shotgun's crack); `eq` is
-- an equaliser on the shot itself (low, mid, high gain in dB); `rack` is the pump worked
-- after every shot (the reload sample, fast and short), `rackDelay` seconds after it.
type Layer = { name: string, sound: string, pitch: number, volume: number, reverb: number? }
type Profile = {
	fire: string, pitch: number, volume: number, reloadPitch: number,
	eq: { number }?, layers: { Layer }?, rack: number?, rackDelay: number?,
}

local PROFILES: { [string]: Profile } = {
	Rifle = { fire = SFX.RifleShort, pitch = 1.00, volume = 0.5, reloadPitch = 1.0 },
	SMG = { fire = SFX.RifleShort, pitch = 1.22, volume = 0.4, reloadPitch = 1.15 },
	-- The pump gun: a deep, full report with the harsh top cut off, a heavy boom under it, and
	-- the pump racked straight after (ka-CHUNK).
	Shotgun = { fire = SFX.RifleShort, pitch = 0.74, volume = 0.62, reloadPitch = 0.85, eq = { 7, 1, -7 },
		layers = { { name = "FireBody", sound = SFX.Pistol, pitch = 0.52, volume = 0.5, reverb = 0.7 } },
		rack = 1.7, rackDelay = 0.32 },
	Pistol = { fire = SFX.Pistol, pitch = 1.05, volume = 0.5, reloadPitch = 1.1 },
	-- The bolt-action: a hard crack and a long rolling tail.
	Sniper = { fire = SFX.RifleShort, pitch = 0.82, volume = 0.66, reloadPitch = 0.9, eq = { 4, 2, -3 },
		layers = { { name = "FireBody", sound = SFX.Pistol, pitch = 0.44, volume = 0.42, reverb = 1.6 } } },
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
	-- The shot's shape: an equaliser on it where the profile has one (and none otherwise).
	local eq = fire:FindFirstChildOfClass("EqualizerSoundEffect")
	local gains = p.eq
	if gains then
		local e: EqualizerSoundEffect = (eq :: any) or Instance.new("EqualizerSoundEffect")
		e.Parent = fire
		e.LowGain, e.MidGain, e.HighGain = gains[1], gains[2], gains[3]
	elseif eq then
		eq:Destroy()
	end
	-- Layers played with the shot; any left over from another profile go.
	local wanted: { [string]: boolean } = {}
	for _, layer in ipairs(p.layers or {}) do
		wanted[layer.name] = true
		local s = ensureSound(handle, layer.name)
		s.SoundId = layer.sound
		s.Volume = layer.volume
		s.PlaybackSpeed = layer.pitch
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 14
		s.RollOffMaxDistance = 320
		local verb = s:FindFirstChildOfClass("ReverbSoundEffect")
		local decay = layer.reverb
		if decay then
			local r: ReverbSoundEffect = (verb :: any) or Instance.new("ReverbSoundEffect")
			r.Parent = s
			r.DecayTime = decay
			r.Density = 0.8
			r.Diffusion = 0.9
			r.DryLevel = 0
			r.WetLevel = -8
		elseif verb then
			verb:Destroy()
		end
	end
	for _, name in ipairs({ "FireBody" }) do
		local old = handle:FindFirstChild(name)
		if old and not wanted[name] then
			old:Destroy()
		end
	end
	-- The pump, worked after every shot.
	local rack = handle:FindFirstChild("Pump")
	if p.rack then
		local s = ensureSound(handle, "Pump")
		s.SoundId = SFX.Reload
		s.Volume = 0.42
		s.PlaybackSpeed = p.rack
		s.RollOffMode = Enum.RollOffMode.InverseTapered
		s.RollOffMinDistance = 8
		s.RollOffMaxDistance = 90
		s:SetAttribute("Delay", p.rackDelay or 0.3)
	elseif rack then
		rack:Destroy()
	end

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

--- Fire a weapon's shot sound: the report, every layer with it, and the pump after (where
--- the weapon has one), each nudged in pitch so held fire never loops one sample. Used by
--- the shooter's own client and by every client hearing someone else's shot.
function WeaponAudio.PlayFire(tool: Tool?): boolean
	local handle = tool and tool:FindFirstChild("Handle")
	local fire = handle and handle:FindFirstChild("Fire")
	if not (fire and fire:IsA("Sound")) then
		return false
	end
	WeaponAudio.Vary(fire)
	fire:Play()
	local body = (handle :: Instance):FindFirstChild("FireBody")
	if body and body:IsA("Sound") and body.SoundId ~= "" then
		WeaponAudio.Vary(body)
		body:Play()
	end
	local pump = (handle :: Instance):FindFirstChild("Pump")
	if pump and pump:IsA("Sound") and pump.SoundId ~= "" then
		local delay = tonumber(pump:GetAttribute("Delay")) or 0.3
		task.delay(delay, function()
			if pump.Parent then
				-- Just the first, sharp part of the reload sample: the slide going back and
				-- forward, not the whole reload.
				pump.TimePosition = 0
				pump:Play()
				task.delay(0.32, function()
					pump:Stop()
				end)
			end
		end)
	end
	return true
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
