--!strict
-- The three character stats, their effects and their limits -- shared, so the Character panel
-- shows exactly the numbers the server applies.
--
-- Every level grants stat points (GameConfig.Leveling.STAT_POINTS_PER_LEVEL). They are spent
-- here, one stat at a time, and can be refunded all at once. Each stat stops at MAX_PER_STAT,
-- so a high level buys breadth rather than one absurd number.
--
-- None of it applies in a duel. The arena is a fair fight: everybody there has the same
-- health, speed and damage, whatever their level (see LevelSystem and KillCredit).

local CharacterConfig = {}

CharacterConfig.MAX_PER_STAT = 50

export type Stat = {
	id: string,            -- the profile field
	label: string,
	icon: string,
	colour: Color3,
	per: number,           -- effect per point, as a fraction
	effect: string,        -- what one point does, for the panel
	total: (points: number) -> string,
}

CharacterConfig.Stats = {
	{
		id = "Strength",
		label = "STRENGTH",
		icon = "⚔️",
		colour = Color3.fromRGB(255, 86, 86),
		per = 0.02,
		effect = "+2% damage against enemies and bosses",
		total = function(points: number): string
			return string.format("+%d%% damage", points * 2)
		end,
	},
	{
		id = "Defense",
		label = "DEFENSE",
		icon = "🛡️",
		colour = Color3.fromRGB(70, 160, 255),
		per = 0.02,
		effect = "+2% maximum health",
		total = function(points: number): string
			return string.format("+%d%% health", points * 2)
		end,
	},
	{
		id = "Stamina",
		label = "STAMINA",
		icon = "⚡",
		colour = Color3.fromRGB(255, 206, 50),
		per = 0.005,
		effect = "+0.5% movement speed",
		total = function(points: number): string
			return string.format("+%.1f%% speed", points * 0.5)
		end,
	},
} :: { Stat }

function CharacterConfig.Get(id: string): Stat?
	for _, stat in ipairs(CharacterConfig.Stats) do
		if stat.id == id then
			return stat
		end
	end
	return nil
end

--- The multiplier a stat gives at `points`, capped.
function CharacterConfig.Bonus(id: string, points: number?): number
	local stat = CharacterConfig.Get(id)
	if not stat then
		return 0
	end
	local n = math.clamp(math.floor(tonumber(points) or 0), 0, CharacterConfig.MAX_PER_STAT)
	return n * stat.per
end

return CharacterConfig
