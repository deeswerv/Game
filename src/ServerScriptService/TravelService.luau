--!strict
-- Travel: pick a place from the Travel menu and go there.
--
-- The world is separate landmasses (and a district in the sky), so getting around was a set
-- of stone arches on pads. They are gone: travel is a menu now (UI.Modules.Travel), and this
-- is the server half -- the list of places, and the one door that moves anybody.
--
-- The client only ever names a place. Everything else is decided here: whether you are
-- alive, whether you have been shot in the last few seconds (no escaping a fight by menu),
-- whether you are in a duel, and a short cooldown. The far end is asked to stream in before
-- you are moved, so you never arrive above a floor that has not loaded.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local TravelService = {}

TravelService.COOLDOWN = 6
TravelService.COMBAT_LOCK = 6          -- seconds after taking damage before you may travel

export type Place = {
	id: string,
	label: string,
	blurb: string,
	icon: string,
	levels: string,
	colour: Color3,
	position: Vector3,       -- where you land (on the ground)
	facing: Vector3,         -- which way you look on arrival
}

-- Arrival spots are measured ground (the same numbers the admin waypoints were raycast at),
-- each with a little room around it.
TravelService.Places = {
	{ id = "Hub", label = "The Crossing", blurb = "Spawn, the 1v1 pads and the harbour.", icon = "⚓",
		levels = "LV 1-2", colour = Color3.fromRGB(88, 176, 232),
		position = Vector3.new(-155, 1.25, 275), facing = Vector3.new(0, 0, -1) },
	{ id = "Downtown", label = "Downtown", blurb = "Shops, the Duel Hall, contracts and turf wars.", icon = "🏙",
		levels = "LV 4-7", colour = Color3.fromRGB(236, 120, 150),
		position = Vector3.new(-155, 1000.5, 1330), facing = Vector3.new(0, 0, 1) },
	{ id = "Flats", label = "The Flats", blurb = "The bandit camp and the guard post, at war.", icon = "⚔",
		levels = "LV 3-5", colour = Color3.fromRGB(214, 150, 70),
		position = Vector3.new(-465, 1, 160), facing = Vector3.new(-1, 0, -0.4) },
	{ id = "Mine", label = "Crystal Mine", blurb = "Behind the falls: crystal seams to mine.", icon = "💎",
		levels = "LV 1-3", colour = Color3.fromRGB(150, 110, 240),
		position = Vector3.new(-101, 4, 61), facing = Vector3.new(0, 0, -1) },
	{ id = "WatchPoint", label = "Watchpoint", blurb = "High ground over the western isles.", icon = "🔭",
		levels = "LV 2-4", colour = Color3.fromRGB(110, 190, 140),
		position = Vector3.new(-320, 6, 291), facing = Vector3.new(-1, 0, 0) },
	{ id = "Reach", label = "The Reach", blurb = "The far east. The toughest fights, the best loot.", icon = "🏔",
		levels = "LV 6-9", colour = Color3.fromRGB(120, 150, 220),
		position = Vector3.new(145, 1.9, 375), facing = Vector3.new(1, 0, 0) },
} :: { Place }

local byId: { [string]: Place } = {}
for _, place in ipairs(TravelService.Places) do
	byId[place.id] = place
end

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local TravelAction = (remotes :: Instance):FindFirstChild("TravelAction") :: RemoteFunction?
if not TravelAction then
	local made = Instance.new("RemoteFunction")
	made.Name = "TravelAction"
	made.Parent = remotes
	TravelAction = made
end

local lastTravel: { [Player]: number } = {}
local lastHurt: { [Player]: number } = {}

--- Where a traveller to `id` lands, looking the way the place faces. Spread a little so a
--- group arriving together does not stack on one spot.
function TravelService.Arrival(id: string): CFrame?
	local place = byId[id]
	if not place then
		return nil
	end
	local jitter = Vector3.new(math.random() * 4 - 2, 0, math.random() * 4 - 2)
	local stand = place.position + jitter + Vector3.new(0, 3.4, 0)
	local look = Vector3.new(place.facing.X, 0, place.facing.Z)
	if look.Magnitude < 0.01 then
		look = Vector3.new(0, 0, 1)
	end
	return CFrame.lookAt(stand, stand + look.Unit)
end

--- Why `player` may not travel right now, or nil if they may.
function TravelService.Blocked(player: Player): string?
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not humanoid or humanoid.Health <= 0 then
		return "You need to be alive to travel"
	end
	if player:GetAttribute("DuelState") == "duel" then
		return "Finish your duel first"
	end
	local now = os.clock()
	if now - (lastHurt[player] or -math.huge) < TravelService.COMBAT_LOCK then
		return "Not while you are under fire"
	end
	local wait = TravelService.COOLDOWN - (now - (lastTravel[player] or -math.huge))
	if wait > 0 then
		return ("Wait %d more second%s"):format(math.ceil(wait), math.ceil(wait) == 1 and "" or "s")
	end
	return nil
end

--- Move a player to a place. The only way anybody travels.
function TravelService.Go(player: Player, id: string): (boolean, string?)
	local target = TravelService.Arrival(id)
	if not target then
		return false, "Unknown place"
	end
	local why = TravelService.Blocked(player)
	if why then
		return false, why
	end
	lastTravel[player] = os.clock()
	pcall(function()
		player:RequestStreamAroundAsync(target.Position, 3)
	end)
	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return false, "You need to be alive to travel"
	end
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	char:PivotTo(target)
	-- Somewhere new, for the Explorer achievement.
	local ok, ContractService = pcall(require, ServerScriptService:FindFirstChild("ContractService") :: ModuleScript)
	if ok and type(ContractService) == "table" and ContractService.Note then
		task.spawn(ContractService.Note, player, "travel", 1, { place = id })
	end
	return true, nil
end

-- Being shot locks travel for a few seconds. Read off KillCredit's hit signal, so every
-- damage source counts.
task.spawn(function()
	local ok, KillCredit = pcall(require, ServerScriptService:WaitForChild("KillCredit", 30) :: ModuleScript)
	if ok and type(KillCredit) == "table" and KillCredit.Damaged then
		KillCredit.Damaged.Event:Connect(function(humanoid: Humanoid, dealt: number)
			local victim = humanoid.Parent and Players:GetPlayerFromCharacter(humanoid.Parent)
			if victim and type(dealt) == "number" and dealt > 0 then
				lastHurt[victim] = os.clock()
			end
		end)
	end
end)

local function listFor(player: Player)
	local list = {}
	for _, place in ipairs(TravelService.Places) do
		table.insert(list, {
			id = place.id, label = place.label, blurb = place.blurb, icon = place.icon, levels = place.levels,
			colour = place.colour, position = place.position,
		})
	end
	return { places = list, blocked = TravelService.Blocked(player) }
end

local travelRemote = TravelAction :: RemoteFunction
travelRemote.OnServerInvoke = function(player: Player, action: unknown, id: unknown)
	if action == "list" then
		return listFor(player)
	elseif action == "go" and type(id) == "string" then
		local ok, why = TravelService.Go(player, id)
		return { ok = ok, reason = why }
	end
	return nil
end

Players.PlayerRemoving:Connect(function(player: Player)
	lastTravel[player] = nil
	lastHurt[player] = nil
end)

-- The old arches and pads, if a saved place still carries them.
local oldGates = workspace:FindFirstChild("TravelGates")
if oldGates then
	oldGates:Destroy()
end

return TravelService
