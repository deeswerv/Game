--!strict
-- Rooms sound like rooms.
--
-- SoundService.AmbientReverb was NoReverb everywhere, so a shot fired inside a building
-- sounded exactly like one fired in an open field -- the single cheapest piece of spatial
-- information a shooter can give you, and it was switched off.
--
-- Deliberately geometric rather than zone-based: the map has no reverb volumes authored and
-- adding them by hand would mean touching every building. One upward raycast answers "is
-- there a roof over this player", which is what reverb actually depends on.

local Players = game:GetService("Players")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer

-- How far up to look before calling it open sky.
local CEILING_REACH = 45
-- A low ceiling is a small room; a high one is a hall.
local LOW_CEILING = 14

-- Sampled, not run per frame. Reverb is a property of where you are standing, and you
-- cannot move far enough in a fifth of a second for it to matter.
local INTERVAL = 0.2

local OPEN = Enum.ReverbType.NoReverb
local ROOM = Enum.ReverbType.Room
local HALL = Enum.ReverbType.Hallway

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local current = OPEN
SoundService.AmbientReverb = OPEN

local function reverbFor(character: Model): Enum.ReverbType
	local head = character:FindFirstChild("Head") :: BasePart?
	if not head then
		return OPEN
	end
	params.FilterDescendantsInstances = { character }
	local up = workspace:Raycast(head.Position, Vector3.new(0, CEILING_REACH, 0), params)
	if not up then
		return OPEN                    -- open sky
	end
	local clearance = up.Position.Y - head.Position.Y
	return clearance <= LOW_CEILING and ROOM or HALL
end

task.spawn(function()
	while true do
		task.wait(INTERVAL)
		local character = player.Character
		local wanted = character and reverbFor(character) or OPEN
		if wanted ~= current then
			current = wanted
			SoundService.AmbientReverb = wanted
		end
	end
end)
