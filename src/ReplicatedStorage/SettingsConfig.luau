--!strict
-- The player's own settings: what they are, their ranges and defaults. Shared, so the panel
-- draws the same limits the server enforces (SettingsService) when it saves them.

local SettingsConfig = {}

export type Setting = {
	id: string,
	label: string,
	group: string,
	min: number,
	max: number,
	step: number,
	default: number,
	format: string,        -- "percent", "degrees" or "colour" (an index into CrosshairColours)
	hint: string,
}

SettingsConfig.Schema = {
	{ id = "Master", label = "MASTER VOLUME", group = "AUDIO", min = 0, max = 1, step = 0.05, default = 1,
		format = "percent", hint = "Everything you hear" },
	{ id = "Weapons", label = "WEAPONS", group = "AUDIO", min = 0, max = 1, step = 0.05, default = 1,
		format = "percent", hint = "Gunfire, reloads, melee" },
	{ id = "World", label = "WORLD & MUSIC", group = "AUDIO", min = 0, max = 1, step = 0.05, default = 1,
		format = "percent", hint = "Ambience, weather, footsteps" },
	{ id = "Interface", label = "INTERFACE", group = "AUDIO", min = 0, max = 1, step = 0.05, default = 1,
		format = "percent", hint = "Clicks, countdowns, kill sting" },
	{ id = "Shake", label = "CAMERA SHAKE", group = "CAMERA", min = 0, max = 1, step = 0.05, default = 1,
		format = "percent", hint = "Recoil kick, landings, hits" },
	{ id = "Fov", label = "FIELD OF VIEW", group = "CAMERA", min = 70, max = 100, step = 1, default = 70,
		format = "degrees", hint = "Wider sees more; aiming still zooms" },
	{ id = "Crosshair", label = "CROSSHAIR COLOUR", group = "COMBAT", min = 1, max = 6, step = 1, default = 1,
		format = "colour", hint = "Dot, arms and shotgun ring" },
} :: { Setting }

-- The crosshair colours, by index. The panel names them; WeaponController draws them.
SettingsConfig.CrosshairColours = {
	{ name = "WHITE", colour = Color3.new(1, 1, 1) },
	{ name = "GREEN", colour = Color3.fromRGB(80, 255, 120) },
	{ name = "CYAN", colour = Color3.fromRGB(80, 230, 255) },
	{ name = "PINK", colour = Color3.fromRGB(255, 100, 220) },
	{ name = "YELLOW", colour = Color3.fromRGB(255, 230, 70) },
	{ name = "RED", colour = Color3.fromRGB(255, 70, 70) },
}

function SettingsConfig.Get(id: string): Setting?
	for _, setting in ipairs(SettingsConfig.Schema) do
		if setting.id == id then
			return setting
		end
	end
	return nil
end

--- A value snapped to its setting's step and range, or the default if it is not a number.
function SettingsConfig.Clean(id: string, value: unknown): number?
	local setting = SettingsConfig.Get(id)
	if not setting then
		return nil
	end
	local n = tonumber(value)
	if not n or n ~= n then
		return setting.default
	end
	n = math.clamp(n, setting.min, setting.max)
	n = math.floor((n - setting.min) / setting.step + 0.5) * setting.step + setting.min
	return math.clamp(n, setting.min, setting.max)
end

--- Every setting, saved values over defaults.
function SettingsConfig.Resolve(saved: { [string]: any }?): { [string]: number }
	local out = {}
	for _, setting in ipairs(SettingsConfig.Schema) do
		local v = saved and saved[setting.id]
		out[setting.id] = v ~= nil and (SettingsConfig.Clean(setting.id, v) :: number) or setting.default
	end
	return out
end

return SettingsConfig
