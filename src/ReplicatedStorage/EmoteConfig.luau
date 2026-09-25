--!strict
-- Emotes.
--
-- Two kinds live here:
--
--   * Classic emotes are Roblox animation assets. Every id was verified to actually LOAD
--     before being listed: an Animation with a bad id does not error, it just never plays,
--     so each one was loaded on a real Animator and checked for a non-zero Length. The
--     durations below are those measured lengths.
--
--   * Keyframe emotes (`keyframe = true`) come from the emote pack in assets/emotes, which
--     tools/emotes/convert.luau turns into ReplicatedStorage.EmoteData. They are not
--     animation assets at all: the server marks the character as doing one (the `Emote` and
--     `EmoteAt` attributes) and every client poses that character itself -- see EmotePlayer
--     and EmoteAnimator. How long each runs and whether it loops is in EmoteData.Index.
--
-- The wheel (hold G) shows one page of eight at a time; pages are the order below.

local EmoteConfig = {}

EmoteConfig.WHEEL_KEY = Enum.KeyCode.G
EmoteConfig.COOLDOWN = 0.6

export type Emote = {
	id: string,
	name: string,
	icon: string,
	page: string,
	animation: string?,  -- classic: the asset
	length: number?,     -- classic: measured length
	looping: boolean?,   -- classic: runs until the player moves
	keyframe: boolean?,  -- from the emote pack: posed by every client
	prop: string?,       -- a prop built around the character while it plays (EmoteProps)
}

EmoteConfig.Pages = {
	{ name = "Classic", colour = Color3.fromRGB(88, 170, 255) },
	{ name = "Dances", colour = Color3.fromRGB(255, 120, 190) },
	{ name = "Moves", colour = Color3.fromRGB(255, 176, 60) },
	{ name = "Taunts", colour = Color3.fromRGB(236, 84, 70) },
	{ name = "Props", colour = Color3.fromRGB(96, 206, 120) },
}

EmoteConfig.Emotes = {
	-- ------------------------------------------------------------- classic --
	{ id = "Wave", name = "Wave", icon = "👋", page = "Classic", animation = "rbxassetid://507770239", length = 1.75, looping = false },
	{ id = "Point", name = "Point", icon = "👉", page = "Classic", animation = "rbxassetid://507770453", length = 1.79, looping = false },
	{ id = "Cheer", name = "Cheer", icon = "🙌", page = "Classic", animation = "rbxassetid://507770677", length = 2.50, looping = false },
	{ id = "Laugh", name = "Laugh", icon = "😂", page = "Classic", animation = "rbxassetid://507770818", length = 3.29, looping = false },
	{ id = "Dance", name = "Dance", icon = "🕺", page = "Classic", animation = "rbxassetid://507771019", length = 1.08, looping = true },
	{ id = "Dance2", name = "Groove", icon = "🎶", page = "Classic", animation = "rbxassetid://507776043", length = 2.04, looping = true },
	{ id = "Dance3", name = "Shuffle", icon = "👟", page = "Classic", animation = "rbxassetid://507777268", length = 1.88, looping = true },
	{ id = "Sit", name = "Sit", icon = "🪑", page = "Classic", animation = "rbxassetid://2506281703", length = 0.92, looping = true },

	-- -------------------------------------------------------------- dances --
	{ id = "OrangeJustice", name = "Orange Justice", icon = "🍊", page = "Dances", keyframe = true },
	{ id = "BoogieDown", name = "Boogie Down", icon = "🪩", page = "Dances", keyframe = true },
	{ id = "KazotskyKick", name = "Kazotsky Kick", icon = "🦵", page = "Dances", keyframe = true },
	{ id = "GamblerDance", name = "Gambler", icon = "🎲", page = "Dances", keyframe = true },
	{ id = "CompanyDance", name = "Company", icon = "💼", page = "Dances", keyframe = true },
	{ id = "ZombieDance", name = "Zombie", icon = "🧟", page = "Dances", keyframe = true },
	{ id = "NekoDance", name = "Neko", icon = "🐱", page = "Dances", keyframe = true },
	{ id = "CandyDance", name = "Candy", icon = "🍬", page = "Dances", keyframe = true },

	-- --------------------------------------------------------------- moves --
	{ id = "Breakdance", name = "Breakdance", icon = "🌀", page = "Moves", keyframe = true },
	{ id = "StarEmote", name = "Star", icon = "⭐", page = "Moves", keyframe = true },
	{ id = "ShadowStep", name = "Shadow Step", icon = "👣", page = "Moves", keyframe = true },
	{ id = "ParrotWiggle", name = "Parrot Wiggle", icon = "🦜", page = "Moves", keyframe = true },
	{ id = "HeadJuggle", name = "Head Juggle", icon = "⚽", page = "Moves", keyframe = true },
	{ id = "Beatbox", name = "Beatbox", icon = "🎤", page = "Moves", keyframe = true },
	{ id = "BlossomBreak", name = "Blossom", icon = "🌸", page = "Moves", keyframe = true },
	{ id = "HonoredOne", name = "Honored One", icon = "🔵", page = "Moves", keyframe = true },

	-- -------------------------------------------------------------- taunts --
	{ id = "TakeTheL", name = "Take the L", icon = "🇱", page = "Taunts", keyframe = true },
	{ id = "ThumbsUp", name = "Thumbs Up", icon = "👍", page = "Taunts", keyframe = true },
	{ id = "Threaten", name = "Threaten", icon = "😠", page = "Taunts", keyframe = true },
	{ id = "TPose", name = "T-Pose", icon = "✝", page = "Taunts", keyframe = true },
	{ id = "DramaticBow", name = "Bow", icon = "🎭", page = "Taunts", keyframe = true },
	{ id = "DapUp", name = "Dap Up", icon = "🤜", page = "Taunts", keyframe = true },
	{ id = "TrickOrTreat", name = "Trick or Treat", icon = "🎃", page = "Taunts", keyframe = true },
	{ id = "ShadowEmerge", name = "Emerge", icon = "🌑", page = "Taunts", keyframe = true },

	-- --------------------------------------------------------------- props --
	{ id = "ToiletSit", name = "Toilet Break", icon = "🚽", page = "Props", keyframe = true, prop = "Toilet" },
	{ id = "CouchNap", name = "Couch Nap", icon = "🛋", page = "Props", keyframe = true, prop = "Couch" },
	{ id = "Sunbath", name = "Sunbathe", icon = "🏖", page = "Props", keyframe = true, prop = "Lounger" },
	{ id = "IceCreamCart", name = "Ice Cream", icon = "🍦", page = "Props", keyframe = true, prop = "Cart" },
	{ id = "Surfer", name = "Surf", icon = "🏄", page = "Props", keyframe = true, prop = "Surfboard" },
	{ id = "CoconutLaunch", name = "Coconut Cannon", icon = "🥥", page = "Props", keyframe = true, prop = "Cannon" },
	{ id = "ReapersRide", name = "Reaper's Ride", icon = "💀", page = "Props", keyframe = true, prop = "Scythe" },
	{ id = "FloatingMeditation", name = "Meditate", icon = "🧘", page = "Props", keyframe = true, prop = "Aura" },
} :: { Emote }

local byId: { [string]: Emote } = {}
for _, e in ipairs(EmoteConfig.Emotes) do
	byId[e.id] = e
end

function EmoteConfig.Get(id: string): Emote?
	return byId[id]
end

--- The emotes on one page of the wheel, in order.
function EmoteConfig.OnPage(page: string): { Emote }
	local out = {}
	for _, e in ipairs(EmoteConfig.Emotes) do
		if e.page == page then
			table.insert(out, e)
		end
	end
	return out
end

return EmoteConfig
