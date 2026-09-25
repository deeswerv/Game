--!strict
-- Emotes.
--
-- Every id here was verified to actually LOAD before being listed: an Animation with a bad
-- id does not error, it just never plays, so each one was loaded on a real Animator and
-- checked for a non-zero Length. The durations below are those measured lengths.

local EmoteConfig = {}

EmoteConfig.WHEEL_KEY = Enum.KeyCode.G
EmoteConfig.COOLDOWN = 0.6

-- `looping` emotes run until the player moves or emotes again; the rest play once.
EmoteConfig.Emotes = {
	{ id = "Wave",   name = "Wave",   animation = "rbxassetid://507770239",  length = 1.75, looping = false },
	{ id = "Point",  name = "Point",  animation = "rbxassetid://507770453",  length = 1.79, looping = false },
	{ id = "Cheer",  name = "Cheer",  animation = "rbxassetid://507770677",  length = 2.50, looping = false },
	{ id = "Laugh",  name = "Laugh",  animation = "rbxassetid://507770818",  length = 3.29, looping = false },
	{ id = "Dance",  name = "Dance",  animation = "rbxassetid://507771019",  length = 1.08, looping = true },
	{ id = "Dance2", name = "Groove", animation = "rbxassetid://507776043",  length = 2.04, looping = true },
	{ id = "Dance3", name = "Shuffle",animation = "rbxassetid://507777268",  length = 1.88, looping = true },
	{ id = "Sit",    name = "Sit",    animation = "rbxassetid://2506281703", length = 0.92, looping = true },
}

function EmoteConfig.Get(id: string)
	for _, e in ipairs(EmoteConfig.Emotes) do
		if e.id == id then
			return e
		end
	end
	return nil
end

return EmoteConfig
