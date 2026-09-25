--!strict
-- The interface's sounds, in one place.
--
-- Until now the UI made no sound at all: a countdown with no beeps, a VS screen with no
-- whoosh, a round won in silence. The reference game leans hard on audio for exactly those
-- moments, so they get it here -- short, punchy one-shots, played locally.
--
-- Every id below is already in use somewhere in this place (weapon, chest and dash sounds),
-- apart from the ping, which ships with the Roblox client itself. Reusing known-good ids
-- means nothing here can fail to load for moderation or permission reasons, and pitch does
-- the work of making one sample serve several moments.
--
-- Routed to the UI bus AudioMix makes, when it exists, so the interface can be mixed
-- against gunfire without touching any of this.

local ContentProvider = game:GetService("ContentProvider")
local SoundService = game:GetService("SoundService")

local UISound = {}

type Spec = { id: string, volume: number, length: number? }

local SPECS: { [string]: Spec } = {
	-- The attack of the hit-confirm sample: a crisp click for buttons.
	Click = { id = "rbxassetid://3398620867", volume = 0.2, length = 0.07 },
	-- Countdown beeps.
	Tick = { id = "rbxasset://sounds/electronicpingshort.wav", volume = 0.45 },
	-- The dash whoosh: slabs sliding in, menus opening.
	Whoosh = { id = "rbxassetid://8653395088", volume = 0.5 },
	-- A sword impact, for text slamming onto the screen.
	Slam = { id = "rbxassetid://9117893517", volume = 0.5, length = 0.7 },
	-- The chest's bright ring: good news.
	Ring = { id = "rbxassetid://5789211405", volume = 0.5 },
	-- The reload sample, pitched down: a heavy mechanical thud for bad news.
	Clunk = { id = "rbxassetid://117963160131194", volume = 0.55, length = 0.5 },
}

local folder = Instance.new("Folder")
folder.Name = "UISounds"
folder.Parent = SoundService

local templates: { [string]: Sound } = {}
for name, spec in pairs(SPECS) do
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = spec.id
	sound.Volume = spec.volume
	sound.Parent = folder
	templates[name] = sound
end

-- Loaded up front, so the first beep of the first countdown is not the one that stalls.
task.spawn(function()
	pcall(function()
		ContentProvider:PreloadAsync(folder:GetChildren())
	end)
end)

local function uiBus(): SoundGroup?
	local master = SoundService:FindFirstChild("Master")
	local bus = master and master:FindFirstChild("UI")
	if bus and bus:IsA("SoundGroup") then
		return bus
	end
	return nil
end

-- The same sound twice inside this window is one sound: a burst of events (several buttons
-- built at once, two score pushes in a frame) must not stack into a blast.
local REPEAT_WINDOW = 0.04
local lastPlayed: { [string]: number } = {}

--- Play a one-shot. `pitch` scales playback speed (and so pitch); `volume` scales the
--- sound's own level.
function UISound.Play(name: string, pitch: number?, volume: number?)
	local template = templates[name]
	if not template then
		return
	end
	local now = os.clock()
	local last = lastPlayed[name]
	if last and now - last < REPEAT_WINDOW then
		return
	end
	lastPlayed[name] = now

	local speed = pitch or 1
	local sound = template:Clone()
	sound.PlaybackSpeed = speed
	sound.Volume = template.Volume * (volume or 1)
	sound.SoundGroup = uiBus()
	sound.Parent = folder
	sound:Play()

	-- Cut or cleaned up either way; a sample's length shrinks as its speed rises.
	local length = SPECS[name].length or 4
	task.delay(length / math.max(speed, 0.1), function()
		sound:Destroy()
	end)
end

--- Several notes in quick succession, for a flourish (a level up, a win).
function UISound.Sequence(name: string, pitches: { number }, gap: number, volume: number?)
	for i, pitch in ipairs(pitches) do
		task.delay((i - 1) * gap, function()
			UISound.Play(name, pitch, volume)
		end)
	end
end

return UISound
