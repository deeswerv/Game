--!strict
-- Killstreak rewards: what a run of kills out in the world earns you, and when.
--
-- The streak is BountyService's -- players and fighters killed without dying, duels and the
-- range's dummies not counted -- so the rewards and the WANTED price climb together:
--
--   3  RADAR       every enemy near you shows through walls, for a while
--   5  OVERSHIELD  a shell of shield on top of your health and armour, until it breaks
--   8  AIRSTRIKE   one call: aim, press the key, and a jet lays a line of shells there;
--                  another every AIRSTRIKE_EVERY kills after that
--
-- Dying ends it: the streak goes back to zero and an unused airstrike goes with it.
-- Shared by StreakRewardService (which grants and runs them) and the client (which draws
-- them), so the numbers on the HUD are the numbers the server uses.

local StreakConfig = {}

export type Reward = {
	id: string,
	kills: number,
	name: string,
	icon: string,
	colour: Color3,
	blurb: string,
}

StreakConfig.Rewards = {
	{ id = "Radar", kills = 3, name = "RADAR", icon = "📡", colour = Color3.fromRGB(76, 214, 255),
		blurb = "Enemies near you show through walls" },
	{ id = "Overshield", kills = 5, name = "OVERSHIELD", icon = "🛡", colour = Color3.fromRGB(176, 123, 255),
		blurb = "A shield over your health until it breaks" },
	{ id = "Airstrike", kills = 8, name = "AIRSTRIKE", icon = "✈", colour = Color3.fromRGB(255, 122, 58),
		blurb = "Aim and call a bombing run" },
} :: { Reward }

-- After the first airstrike, another every this many kills (12, 16, 20 ...).
StreakConfig.AIRSTRIKE_EVERY = 4

StreakConfig.Radar = {
	duration = 12,       -- seconds it stays up
	range = 260,         -- studs; enemies further out are not shown
	maxShown = 24,       -- Roblox draws at most 31 Highlights at once; leave some for the game
}

StreakConfig.Overshield = {
	amount = 60,
}

StreakConfig.Airstrike = {
	key = Enum.KeyCode.U,
	range = 320,         -- how far from you it can be called in
	warning = 2.6,       -- seconds between the call and the first shell: time to get out
	shells = 6,
	gap = 0.2,           -- seconds between shells
	length = 26,         -- studs the line of shells covers, along the jet's run
	damage = 95,         -- each shell at its centre; falls off like a frag's
	radius = 12,
	altitude = 110,      -- the jet's height over the target
}

--- The reward (if any) that reaching `streak` earns.
function StreakConfig.RewardAt(streak: number): Reward?
	for _, reward in ipairs(StreakConfig.Rewards) do
		if reward.kills == streak then
			return reward
		end
	end
	local last = StreakConfig.Rewards[#StreakConfig.Rewards]
	if streak > last.kills and (streak - last.kills) % StreakConfig.AIRSTRIKE_EVERY == 0 then
		return last
	end
	return nil
end

--- The next streak that earns something, after `streak`.
function StreakConfig.NextAt(streak: number): number
	for _, reward in ipairs(StreakConfig.Rewards) do
		if reward.kills > streak then
			return reward.kills
		end
	end
	local last = StreakConfig.Rewards[#StreakConfig.Rewards].kills
	local every = StreakConfig.AIRSTRIKE_EVERY
	return last + (math.floor((streak - last) / every) + 1) * every
end

--- The reward called `id`.
function StreakConfig.Get(id: string): Reward?
	for _, reward in ipairs(StreakConfig.Rewards) do
		if reward.id == id then
			return reward
		end
	end
	return nil
end

return StreakConfig
