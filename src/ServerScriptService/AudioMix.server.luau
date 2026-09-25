--!strict
-- A mixing bus, so the game's audio can be balanced at all.
--
-- There were no SoundGroups anywhere: every Sound in the place played at whatever volume it
-- happened to be authored with, and there was no way to pull gunfire down against ambience,
-- or duck everything for a UI moment, without editing every sound individually.
--
-- Routing only. No volumes are changed here -- each group sits at 1 and the existing
-- per-sound volumes are untouched, so this is audible only as the ability to mix.

local SoundService = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local function group(name: string, parent: Instance): SoundGroup
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("SoundGroup") then
		return existing
	end
	local made = Instance.new("SoundGroup")
	made.Name = name
	made.Volume = 1
	made.Parent = parent
	return made
end

local master = group("Master", SoundService)
local weapons = group("Weapons", master)
local world = group("World", master)
local ui = group("UI", master)

-- Which bus a sound belongs on, by the names this project actually uses.
local WEAPON_SOUNDS = {
	Fire = true, Reload = true, Empty = true, Charge = true,
	MagIn = true, MagOut = true, Swing = true, Hit = true,
	-- Handling sounds. Currently silent placeholders in WeaponAudio, but they must be on the
	-- weapons bus from the start: a sound routed to World once keeps that group for the life
	-- of the instance, so filling in an id later would otherwise produce a weapon sound that
	-- quietly ignores the weapons mix.
	Equip = true, Unequip = true,
}

local function route(sound: Sound)
	if sound.SoundGroup then
		return                          -- already routed; never override a deliberate choice
	end
	if WEAPON_SOUNDS[sound.Name] then
		sound.SoundGroup = weapons
	elseif sound:IsDescendantOf(SoundService) then
		sound.SoundGroup = ui
	else
		sound.SoundGroup = world
	end
end

local routed = 0
for _, root in ipairs({ workspace, ReplicatedStorage, SoundService }) do
	for _, d in ipairs(root:GetDescendants()) do
		if d:IsA("Sound") then
			route(d)
			routed += 1
		end
	end
end

-- Weapons are cloned constantly, so new sounds appear for the whole life of the server.
--
-- ReplicatedStorage is watched as well as workspace, and that is not belt-and-braces: the
-- weapon TEMPLATES live there and WeaponAudio stamps their sounds on at boot, so whether the
-- sweep above catches them depends purely on which of the two scripts bootstrap reaches
-- first. That race was visible in the log -- the same place reported 76 routed on one run
-- and 124 on the next. Watching both makes the count correct either way.
for _, root in ipairs({ workspace, ReplicatedStorage }) do
	root.DescendantAdded:Connect(function(d)
		if d:IsA("Sound") then
			route(d)
		end
	end)
end

print(string.format("[AudioMix] %d sounds routed to Master > Weapons / World / UI", routed))
