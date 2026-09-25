--!strict
-- Standing with each faction.
--
-- Server-authoritative in the strict sense: there is no remote here at all. The client
-- cannot ask to change reputation, only read what the replica already gives it, so the
-- only way standing moves is something on the server deciding it should.
--
-- Factions are the same names NPCConfig already uses ("Hostile", "Guard"), so no new
-- vocabulary is introduced -- an NPC's Faction field is the key.

local ServerScriptService = game:GetService("ServerScriptService")
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)

local ReputationService = {}

ReputationService.MIN = -100
ReputationService.MAX = 100

-- Bands, worst first. `atLeast` is inclusive; the first band the value does NOT clear is
-- the one below it, so this is read from the top down.
ReputationService.Bands = {
	{ id = "Honoured", atLeast = 75 },
	{ id = "Friendly", atLeast = 30 },
	{ id = "Neutral",  atLeast = -14 },
	{ id = "Disliked", atLeast = -49 },
	{ id = "Hated",    atLeast = -100 },
}

--- The band a raw value falls in.
function ReputationService.Band(value: number): string
	for _, band in ipairs(ReputationService.Bands) do
		if value >= band.atLeast then
			return band.id
		end
	end
	return "Hated"
end

-- The faction whose opinion the shops care about: the town.
ReputationService.TRADE_FACTION = "Guard"

-- What your standing does to a price. Refused outright at Hated -- the town does not sell
-- to someone who has been killing its guards, and a discount curve that never actually
-- closes the door makes standing a rounding error instead of a consequence.
ReputationService.PriceMultipliers = {
	Honoured = 0.85,
	Friendly = 0.93,
	Neutral = 1.00,
	Disliked = 1.15,
	Hated = nil,        -- nil means "will not trade with you"
}

-- Published as a player attribute so the shop UI can show the same number the server will
-- charge. Attributes set on the server replicate read-only to the client, so this is
-- display data the client cannot forge into a discount -- the price is recomputed server
-- side on every purchase regardless of what the UI drew.
ReputationService.PRICE_ATTRIBUTE = "ShopPriceMultiplier"

-- The band name, published alongside the multiplier. Sent as its own attribute rather than
-- derived from the number on the client: 0.93 -> "Friendly" is a mapping the client would
-- have to keep in step with this file forever, and it would silently mislabel the moment a
-- multiplier changed.
ReputationService.STANDING_ATTRIBUTE = "TownStanding"

local function replicaOf(player: Player)
	local ok, replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
	end)
	return ok and replica or nil
end

--- Standing with one faction. A faction never met is neutral, not an error.
function ReputationService.Get(player: Player, faction: string): number
	local replica = replicaOf(player)
	if not replica then
		return 0
	end
	local rep = replica.Data.Reputation
	return (rep and rep[faction]) or 0
end

--- Everything, as a plain copy. Used by dialogue and by the UI.
function ReputationService.GetAll(player: Player): { [string]: number }
	local replica = replicaOf(player)
	local out = {}
	if replica and replica.Data.Reputation then
		for k, v in pairs(replica.Data.Reputation) do
			out[k] = v
		end
	end
	return out
end

--- Move standing by `delta`, clamped. Returns the new value, or nil if the profile is not
--- loaded -- reputation is never silently dropped on the floor without saying so.
---
--- The whole Reputation table is written rather than one key: Replica replicates values,
--- and mutating the nested table in place would change the server's copy without telling
--- anyone about it.
function ReputationService.Add(player: Player, faction: string, delta: number): number?
	if type(faction) ~= "string" or faction == "" or delta == 0 then
		return nil
	end
	local replica = replicaOf(player)
	if not replica then
		return nil
	end
	local current = replica.Data.Reputation or {}
	local updated = {}
	for k, v in pairs(current) do
		updated[k] = v
	end
	local value = math.clamp((updated[faction] or 0) + delta, ReputationService.MIN, ReputationService.MAX)
	updated[faction] = value
	replica:SetValue("Reputation", updated)
	if faction == ReputationService.TRADE_FACTION then
		ReputationService.Refresh(player)
	end
	return value
end

--- The multiplier this player's standing earns them, or nil if the town refuses to trade.
function ReputationService.PriceMultiplier(player: Player): number?
	local band = ReputationService.Band(ReputationService.Get(player, ReputationService.TRADE_FACTION))
	return ReputationService.PriceMultipliers[band]
end

--- What `basePrice` actually costs this player. Rounded the same way on both sides so the
--- UI and the till never disagree by a coin.
function ReputationService.AdjustedPrice(basePrice: number, multiplier: number): number
	return math.floor(basePrice * multiplier + 0.5)
end

--- Push the current multiplier onto the player for the UI to read. Called whenever standing
--- moves, and once on join.
function ReputationService.Refresh(player: Player)
	if not player.Parent then
		return
	end
	local mult = ReputationService.PriceMultiplier(player)
	-- 0 is the signal for "refuses to trade": an attribute cannot be nil-and-meaningful,
	-- and a zero multiplier is never a real price.
	player:SetAttribute(ReputationService.PRICE_ATTRIBUTE, mult or 0)
	player:SetAttribute(ReputationService.STANDING_ATTRIBUTE,
		ReputationService.Band(ReputationService.Get(player, ReputationService.TRADE_FACTION)))
end

game:GetService("Players").PlayerAdded:Connect(function(player)
	-- The profile has to land first, or the multiplier is read off an empty table.
	task.spawn(function()
		for _ = 1, 20 do
			if replicaOf(player) then
				ReputationService.Refresh(player)
				return
			end
			task.wait(0.5)
		end
	end)
end)

return ReputationService
