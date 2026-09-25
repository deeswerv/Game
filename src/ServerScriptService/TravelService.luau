--!strict
-- Travel gates -- the only way across this world's separate landmasses.
--
-- Measured before any of this was built. Standing on the player spawn you can walk to 3.7%
-- of the world (28,620 of 776,643 square studs), and NONE of the 13 combat NPCs are on it:
-- every NPC post and the Warlord of the Flats stand on the western island, the Warlord of
-- the Reach and 75% of the world's parts on the eastern one. There is no floor between them
-- at any height -- x -370..-360 and x -20..+50 return no ground over the whole depth of the
-- map -- and the live character could not path to either boss or to the Map2 arena.
--
-- Gates are PAIRED rather than a menu. An arch names exactly one destination, so there is
-- nothing to choose from and nothing for a client to send, and the arch doubles as a
-- signpost: it stands on the side of its pad that faces where it goes. Where two
-- destinations lie in nearly the same direction -- the islands are strung roughly east to
-- west, so two of them do -- the bearings are spread just far enough apart that the arches
-- do not overlap.
--
-- The client decides nothing here. A ProximityPrompt's activation distance is enforced on
-- the client and can be faked, so Send measures the distance again on the server before it
-- moves anybody.

local Players = game:GetService("Players")
local ServerScriptService = game:GetService("ServerScriptService")

local WorldBake = require(ServerScriptService.WorldBake)

local TravelService = {}

TravelService.FOLDER = "TravelGates"
TravelService.REACH = 8            -- the prompt's own range; see Arrival for why it is small
TravelService.SLACK = 9            -- how far past it the server still accepts, for latency
TravelService.COOLDOWN = 2.5
TravelService.MIN_SEPARATION = 52  -- degrees between two arches standing on the same pad

local STONE = Color3.fromRGB(150, 148, 152)
local STONE_DARK = Color3.fromRGB(112, 110, 116)

-- Every pad sits on ground measured flat to within 1.5 studs across its footprint, with
-- clear headroom, and far enough from hostile spawns that nobody arrives already in a fight:
-- the Flats pad is 107 studs from the nearest NPC post, the Reach pad 124 from its Warlord.
TravelService.Pads = {
	Hub        = { position = Vector3.new(-155, 1.25, 275), label = "The Crossing",   radius = 9, gateRadius = 12 },
	Flats      = { position = Vector3.new(-465, 1.00, 160), label = "The Flats",      radius = 7, gateRadius = 7 },
	Reach      = { position = Vector3.new(145, 1.90, 375),  label = "The Reach",      radius = 7, gateRadius = 7 },
	WatchPoint = { position = Vector3.new(-320, 6.00, 291), label = "The Watchpoint", radius = 7, gateRadius = 7 },
}

-- One entry per link. Each becomes two arches, one at either end, sharing a colour so the
-- gate you arrive through is recognisably the one that takes you back.
TravelService.Routes = {
	{ a = "Hub", b = "Flats",      colour = Color3.fromRGB(104, 204, 110) },
	{ a = "Hub", b = "Reach",      colour = Color3.fromRGB(236, 178, 72) },
	{ a = "Hub", b = "WatchPoint", colour = Color3.fromRGB(96, 170, 236) },
}

local lastTravel: { [Player]: number } = {}

local function folder(): Folder
	local existing = workspace:FindFirstChild(TravelService.FOLDER)
	if existing then
		return existing :: Folder
	end
	local f = Instance.new("Folder")
	f.Name = TravelService.FOLDER
	f.Parent = workspace
	return f
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, colour: Color3, material: Enum.Material?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = colour
	p.Material = material or Enum.Material.Slate
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function destinationsOf(padId: string): { string }
	local list = {}
	for _, route in ipairs(TravelService.Routes) do
		if route.a == padId then
			table.insert(list, route.b)
		elseif route.b == padId then
			table.insert(list, route.a)
		end
	end
	return list
end

local function colourOf(padId: string, destId: string): Color3
	for _, route in ipairs(TravelService.Routes) do
		if (route.a == padId and route.b == destId) or (route.b == padId and route.a == destId) then
			return route.colour
		end
	end
	return STONE
end

--- Bearing from a pad to each of its destinations, spread apart where two nearly coincide.
-- Relaxation rather than fixed slots: an arch keeps pointing the true way whenever it can,
-- and only gives ground when a neighbour would otherwise overlap it.
local function bearingsOf(padId: string)
	local centre = TravelService.Pads[padId].position
	local list = {}
	for _, destId in ipairs(destinationsOf(padId)) do
		local to = TravelService.Pads[destId].position
		table.insert(list, { id = destId, angle = math.atan2(to.Z - centre.Z, to.X - centre.X) })
	end
	table.sort(list, function(a, b)
		return a.angle < b.angle
	end)
	if #list < 2 then
		return list
	end
	local minGap = math.rad(TravelService.MIN_SEPARATION)
	for _ = 1, 60 do
		local moved = false
		for i = 1, #list do
			local j = i % #list + 1
			local gap = (list[j].angle - list[i].angle) % (math.pi * 2)
			if gap < minGap then
				local push = (minGap - gap) / 2
				list[i].angle -= push
				list[j].angle += push
				moved = true
			end
		end
		if not moved then
			break
		end
	end
	return list
end

--- Attach the prompt to a gate.
--
-- Split out of the builder so a gate that came from the saved place -- one dragged somewhere
-- else in Studio -- behaves exactly like a freshly generated one. The destination rides on
-- the model as an attribute, so the arch keeps working wherever it is put.
local function wire(model: Model): boolean
	local veil = model:FindFirstChild("Veil")
	local prompt = veil and veil:FindFirstChildOfClass("ProximityPrompt")
	if not prompt or not model:GetAttribute("TravelTo") then
		return false
	end
	prompt.Triggered:Connect(function(player: Player)
		TravelService.Send(player, model)
	end)
	return true
end

local function buildPad(parent: Instance, padId: string): Model
	local spec = TravelService.Pads[padId]
	local centre = spec.position
	local model = Instance.new("Model")
	model.Name = "Pad_" .. padId
	model.Parent = parent

	-- An octagon the cheap way: two boxes crossed at 45 degrees, the way the islets are made.
	for i = 0, 1 do
		part(model, "PadStone", Vector3.new(spec.radius * 2, 1.2, spec.radius * 2),
			CFrame.new(centre + Vector3.new(0, 0.4, 0)) * CFrame.Angles(0, math.rad(i * 45), 0), STONE)
	end
	for i = 0, 1 do
		part(model, "PadRim", Vector3.new(spec.radius * 2.3, 0.7, spec.radius * 2.3),
			CFrame.new(centre + Vector3.new(0, -0.3, 0)) * CFrame.Angles(0, math.rad(i * 45), 0), STONE_DARK)
	end

	-- Invisible, non-colliding: it exists so the arrival point follows the pad if the pad is
	-- ever dragged somewhere else.
	local anchor = part(model, "PadAnchor", Vector3.new(2, 0.2, 2), CFrame.new(centre + Vector3.new(0, 1.05, 0)), STONE)
	anchor.Transparency = 1
	anchor.CanCollide = false
	anchor.CanQuery = false

	model.PrimaryPart = anchor
	model:SetAttribute("TravelPad", padId)
	return model
end

local function buildGate(parent: Instance, fromId: string, destId: string, angle: number): Model
	local spec = TravelService.Pads[fromId]
	local colour = colourOf(fromId, destId)
	local dir = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local base = spec.position + dir * spec.gateRadius
	local facing = CFrame.lookAt(base, base + dir)

	local model = Instance.new("Model")
	model.Name = ("Gate_%s_to_%s"):format(fromId, destId)
	model.Parent = parent

	for _, side in ipairs({ -1, 1 }) do
		part(model, "Pillar", Vector3.new(1.5, 9, 1.5), facing * CFrame.new(side * 3.4, 4.5, 0), STONE)
	end
	part(model, "Lintel", Vector3.new(9.6, 1.5, 2.1), facing * CFrame.new(0, 9.7, 0), STONE_DARK)
	part(model, "Keystone", Vector3.new(2.2, 2.2, 2.4), facing * CFrame.new(0, 10.6, 0) * CFrame.Angles(0, 0, math.rad(45)), colour, Enum.Material.Neon)

	local veil = part(model, "Veil", Vector3.new(6.2, 8, 0.4), facing * CFrame.new(0, 4.6, 0), colour, Enum.Material.Neon)
	veil.Transparency = 0.5
	veil.CanCollide = false
	veil.CanQuery = false      -- a gate never stops a bullet

	local light = Instance.new("PointLight")
	light.Color = colour
	light.Brightness = 2.4
	light.Range = 28
	light.Parent = veil

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Travel"
	prompt.ObjectText = TravelService.Pads[destId].label
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = TravelService.REACH
	prompt.RequiresLineOfSight = false
	prompt.Parent = veil

	model.PrimaryPart = veil
	model:SetAttribute("TravelFrom", fromId)
	model:SetAttribute("TravelTo", destId)
	wire(model)
	return model
end

--- Where a traveller lands, read from the parts in the world rather than the table above, so
--- a pad dragged somewhere else in Studio still delivers people onto itself.
function TravelService.Arrival(padId: string, fromId: string?): CFrame
	local spec = TravelService.Pads[padId]
	local f = workspace:FindFirstChild(TravelService.FOLDER)
	local centre = spec.position

	local padModel = f and f:FindFirstChild("Pad_" .. padId)
	local anchor = padModel and padModel:FindFirstChild("PadAnchor")
	if anchor and anchor:IsA("BasePart") then
		centre = anchor.Position - Vector3.new(0, 1.05, 0)
	end

	-- Which way the arch home lies, so arrivals can be put with their backs to it.
	local dir = Vector3.new(0, 0, 1)
	local back = fromId and f and f:FindFirstChild(("Gate_%s_to_%s"):format(padId, fromId))
	local veil = back and back:FindFirstChild("Veil")
	if veil and veil:IsA("BasePart") then
		local flat = Vector3.new(veil.Position.X - centre.X, 0, veil.Position.Z - centre.Z)
		if flat.Magnitude > 0.5 then
			dir = flat.Unit
		end
	end

	-- Land on the FAR side of the pad from the arch home, looking out at the new place.
	--
	-- Not a flourish. Arriving in the mouth of the return arch put the traveller 4.8 studs
	-- from its prompt, and a held key carried straight through and sent them back where they
	-- came from -- measured on the first live run: 318 studs out to the Flats and 318 back
	-- again. Standing them clear costs nothing and leaves REACH + 2 studs of margin.
	local stand = centre - dir * 3 + Vector3.new(0, 3.4, 0)
	return CFrame.lookAt(stand, stand - dir)
end

--- Move a player through a gate. The only entry point, and it trusts nothing it is told.
function TravelService.Send(player: Player, gate: Model): boolean
	local destId = gate:GetAttribute("TravelTo")
	if typeof(destId) ~= "string" or not TravelService.Pads[destId] then
		return false
	end

	local now = os.clock()
	if now - (lastTravel[player] or -math.huge) < TravelService.COOLDOWN then
		return false
	end

	local char = player.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if not char or not humanoid or not root or not root:IsA("BasePart") or humanoid.Health <= 0 then
		return false
	end

	-- The prompt's range is enforced on the client, so measure it again here.
	local veil = gate.PrimaryPart or gate:FindFirstChild("Veil")
	if veil and veil:IsA("BasePart") then
		local away = (root.Position - veil.Position).Magnitude
		if away > TravelService.REACH + TravelService.SLACK then
			warn(("[Travel] %s triggered %s from %.0f studs -- refused"):format(player.Name, gate.Name, away))
			return false
		end
	end

	lastTravel[player] = now
	local target = TravelService.Arrival(destId, gate:GetAttribute("TravelFrom") :: string?)
	root.AssemblyLinearVelocity = Vector3.zero
	root.AssemblyAngularVelocity = Vector3.zero
	if char.PrimaryPart then
		char:PivotTo(target)
	else
		root.CFrame = target
	end
	return true
end

function TravelService.Build()
	local f = folder()
	if WorldBake.IsBaked(TravelService.FOLDER) then
		local wired = 0
		for _, model in ipairs(f:GetChildren()) do
			if model:IsA("Model") and wire(model) then
				wired += 1
			end
		end
		print(("[Travel] baked copy kept -- %d gates rewired where they stand"):format(wired))
		return
	end

	f:ClearAllChildren()
	local pads, gates = 0, 0
	for padId in pairs(TravelService.Pads) do
		buildPad(f, padId)
		pads += 1
	end
	for padId in pairs(TravelService.Pads) do
		for _, bearing in ipairs(bearingsOf(padId)) do
			buildGate(f, padId, bearing.id, bearing.angle)
			gates += 1
		end
	end
	print(("[Travel] %d pads, %d gates across %d routes"):format(pads, gates, #TravelService.Routes))
end

Players.PlayerRemoving:Connect(function(player: Player)
	lastTravel[player] = nil
end)

TravelService.Build()

return TravelService
