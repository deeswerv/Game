--!strict
-- Zone bosses: one Warlord per island, standing at a landmark.
--
-- Built on the existing NPC machinery rather than a parallel AI -- a boss IS an NPC, it
-- just has phases, a guaranteed drop, and everyone hears about it. The phase logic watches
-- health rather than running its own tick.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local NPCService = require(ServerScriptService.NPCService)
local NPCConfig = require(ReplicatedStorage.NPCConfig)

local BossService = {}

-- Where each boss stands. Positions verified to sit on real walkable ground.
BossService.Posts = {
	{ zone = "Flats", position = Vector3.new(-625, 1.0, 88), title = "The Warlord of the Flats" },
	{ zone = "Reach", position = Vector3.new(244, 2.16, 300), title = "The Warlord of the Reach" },
}

-- Health fractions at which the fight changes. Adds are spawned from the zone's own
-- archetypes, so a boss escalates with the enemies that already live there.
BossService.Phases = {
	{ at = 0.66, adds = 2, addArchetype = "Grunt", damageScale = 1.15 },
	{ at = 0.33, adds = 3, addArchetype = "Marksman", damageScale = 1.35 },
}

local live: { [string]: Model } = {}

local function announce(text: string)
	-- One line in the server log and, when a feed exists, on screen. Deliberately not a
	-- bespoke remote: the kill feed already carries server-wide notices.
	print("[Boss] " .. text)
end

local function watchPhases(model: Model, post)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end
	local maxHealth = humanoid.MaxHealth
	local fired = {}

	humanoid.HealthChanged:Connect(function(health)
		local fraction = health / math.max(maxHealth, 1)
		for index, phase in ipairs(BossService.Phases) do
			if not fired[index] and fraction <= phase.at and health > 0 then
				fired[index] = true
				announce(("%s enters phase %d"):format(post.title, index + 1))
				-- For the boss health bar: which phase, so it can call it out.
				model:SetAttribute("Phase", index + 1)

				-- Adds appear AROUND the boss, spread so they do not stack inside it.
				local root = model:FindFirstChild("HumanoidRootPart")
				local centre = root and root.Position or post.position
				for i = 1, phase.adds do
					local angle = (i / phase.adds) * math.pi * 2
					local at = centre + Vector3.new(math.cos(angle) * 12, 0, math.sin(angle) * 12)
					-- Adds belong to this fight. Left on the default, each one respawned at the
					-- spot it was summoned forever, so every boss fight grew the population.
					task.spawn(NPCService.Spawn, phase.addArchetype, at, { respawn = false })
				end
			end
		end
	end)

	humanoid.Died:Connect(function()
		announce(post.title .. " has fallen")
		live[post.zone] = nil
		task.delay(NPCConfig.Get("Warlord").RespawnTime, function()
			BossService.SpawnAt(post)
		end)
	end)
end

function BossService.SpawnAt(post): Model?
	if live[post.zone] and live[post.zone].Parent then
		return live[post.zone]
	end
	-- This service brings the boss back itself (see watchPhases). NPCService's own respawn
	-- would add a SECOND, unmanaged Warlord -- no phases, no title -- every fifteen minutes.
	local model = NPCService.Spawn("Warlord", post.position, { respawn = false, ignoreCap = true })
	if not model then
		return nil
	end
	model.Name = post.title
	model:SetAttribute("Boss", true)
	-- The boss bar marks where the phases turn over, and shows which one the fight is in.
	local marks = {}
	for _, phase in ipairs(BossService.Phases) do
		table.insert(marks, tostring(phase.at))
	end
	model:SetAttribute("PhaseMarks", table.concat(marks, ","))
	model:SetAttribute("Phase", 1)
	live[post.zone] = model
	watchPhases(model, post)
	announce(post.title .. " stands at " .. post.zone)
	return model
end

function BossService.Live()
	local out = {}
	for zone, model in pairs(live) do
		if model.Parent then
			out[zone] = model
		end
	end
	return out
end

function BossService.Start()
	-- Guarded on the datamodel: require caches per Luau VM, so a second copy of this module
	-- would otherwise spawn a second set of bosses.
	if workspace:GetAttribute("BossesPlaced") then
		return
	end
	workspace:SetAttribute("BossesPlaced", true)
	for _, post in ipairs(BossService.Posts) do
		BossService.SpawnAt(post)
	end
end

BossService.Start()

return BossService
