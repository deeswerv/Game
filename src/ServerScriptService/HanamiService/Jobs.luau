--!strict
-- HANAMI CITY's jobs, out in the world. Each reports what happened to the quest tracker
-- (HanamiService.Note -> QuestService.RegisterEvent), so a quest can ask for any of them:
--
--   RESCUE    townsfolk tied to posts in the gang's hideout in the old rail shed: hold E to cut
--             them loose and they run for home ("rescue"). The gang takes more before long.
--   INSPECT   the clues the Kurogane left lying in the Steelworks: a ledger, crates, orders, a
--             map -- hold E to read one ("inspect", by clue).
--   COLLECT   iron seals hidden on the city's high and hidden places ("collect", by seal).
--   SURVIVE   the raid on the fish market: start it on the auction floor and hold the hall
--             through three waves of raiders while the catch is still there ("survive").
--             Raiders that reach the auction floor wear it down; lose it, or everybody, and
--             the raid is lost.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local HanamiConfig = require(ReplicatedStorage.HanamiConfig)

local Jobs = {}

Jobs.RETIE = 120               -- the camp has new captives this long after one is freed
Jobs.RAID_BREAK = 6            -- between waves
Jobs.RAID_COOLDOWN = 120       -- after a raid is won, before the next can start
Jobs.RAID_EMPTY = 20           -- nobody in the yard this long and the raid is lost
Jobs.HOUSE_WEAR = 2.2          -- what a raider on the auction floor takes from it each second
Jobs.RAID_REWARD = { coins = 1200, xp = 900, crystals = 4, cred = 6 }

local H: any = nil

function Jobs.Init(service: any)
	H = service
end

local function at(local_: Vector3): Vector3
	return HanamiConfig.CENTRE + local_
end

local function prompt(parent: Instance, action: string, object: string, hold: number, distance: number?): ProximityPrompt
	local p = Instance.new("ProximityPrompt")
	p.ActionText = action
	p.ObjectText = object
	p.KeyboardKeyCode = Enum.KeyCode.E
	p.HoldDuration = hold
	p.MaxActivationDistance = distance or 9
	p.RequiresLineOfSight = false
	p.Parent = parent
	return p
end

local function alive(player: Player): (Humanoid?, BasePart?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
		return humanoid, root
	end
	return nil, nil
end

-- ------------------------------------------------------------------ rescue --

local CAPTIVE_LOOKS: { { [string]: any } } = {
	{ Shirt = Color3.fromRGB(96, 140, 110), Pants = Color3.fromRGB(70, 60, 50), Sleeves = true,
	  Outfit = { { "Hair", style = "short" }, { "Obi", colour = Color3.fromRGB(196, 170, 110) }, { "Loafers" } } :: { any } },
	{ Shirt = Color3.fromRGB(176, 110, 90), Pants = Color3.fromRGB(60, 56, 64), Sleeves = true,
	  Outfit = { { "Hair", style = "slick", colour = Color3.fromRGB(40, 30, 26) }, { "Obi" }, { "Loafers" } } :: { any } },
	{ Shirt = Color3.fromRGB(110, 120, 170), Pants = Color3.fromRGB(56, 56, 60), Sleeves = true,
	  Outfit = { { "Hair", style = "top" }, { "Hachimaki", colour = Color3.fromRGB(246, 240, 228) }, { "Loafers" } } :: { any } },
}

type Captive = { spot: Vector3, figure: Model?, freedAt: number? }
local captives: { [number]: Captive } = {}

local function captivesLeft(): number
	local n = 0
	for _, c in pairs(captives) do
		if c.figure and c.figure:GetAttribute("Captive") then
			n += 1
		end
	end
	return n
end

local function free(index: number, player: Player)
	local c = captives[index]
	local figure = c and c.figure
	if not c or not figure or not figure:GetAttribute("Captive") then
		return
	end
	figure:SetAttribute("Captive", nil)
	figure:SetAttribute("Freed", true)
	local p = figure:FindFirstChildWhichIsA("ProximityPrompt", true)
	if p then
		p:Destroy()
	end
	H.Speak(figure, "Thank you! I'll run for the village -- tell the Elder!")
	H.Note(player, "rescue", { id = "Captive" .. index })
	H.Event:FireClient(player, "rescued", { left = captivesLeft() })
	task.delay(2.6, function()
		if figure.Parent then
			figure:Destroy()
		end
		c.figure = nil
		c.freedAt = H.Clock()
	end)
end

local function tie(index: number, folder: Instance)
	local c = captives[index]
	local figure = H.Figure(CAPTIVE_LOOKS[(index - 1) % #CAPTIVE_LOOKS + 1], 700 + index, "Captive Villager", "TIED UP")
	if not figure then
		return
	end
	figure:SetAttribute("Captive", true)
	-- Back to the post, facing out of the camp.
	H.PlaceFigure(figure, c.spot, c.spot + Vector3.new(0, 0, -10), folder)
	local root = figure:FindFirstChild("HumanoidRootPart")
	if root then
		local p = prompt(root, "Free", "Captive villager", 1.5)
		p.Triggered:Connect(function(player)
			free(index, player)
		end)
	end
	c.figure = figure
	c.freedAt = nil
end

-- ------------------------------------------------------------------- clues --

local function wireClue(part: BasePart)
	local id = tostring(part:GetAttribute("ClueId"))
	local clue = nil
	for _, c in ipairs(HanamiConfig.Clues) do
		if c.id == id then
			clue = c
		end
	end
	if not clue then
		return
	end
	local p = prompt(part, "Inspect", clue.title, 0.8)
	p.Triggered:Connect(function(player)
		H.Event:FireClient(player, "clue", { id = id, title = clue.title, text = clue.text, total = #HanamiConfig.Clues })
		H.Note(player, "inspect", { id = id })
	end)
end

-- ------------------------------------------------------------------- seals --

local function wireSeal(spot: BasePart, folder: Instance)
	local index = tonumber(spot:GetAttribute("Index")) or 0
	local seal = Instance.new("Part")
	seal.Name = "IronSeal"
	seal.Shape = Enum.PartType.Cylinder
	seal.Size = Vector3.new(0.4, 2.2, 2.2)
	seal.CFrame = CFrame.new(spot.Position) * CFrame.Angles(0, math.rad(index * 40), 0)
	seal.Color = Color3.fromRGB(46, 46, 54)
	seal.Material = Enum.Material.Metal
	seal.Anchored = true
	seal.CanCollide = false
	seal.CanTouch = false
	seal.Parent = folder
	local crest = Instance.new("Part")
	crest.Name = "SealCrest"
	crest.Size = Vector3.new(0.5, 1, 1)
	crest.CFrame = seal.CFrame * CFrame.Angles(math.rad(45), 0, 0)
	crest.Color = Color3.fromRGB(196, 40, 44)
	crest.Anchored = true
	crest.CanCollide = false
	crest.CanQuery = false
	crest.CanTouch = false
	crest.Parent = seal
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 90, 80)
	glow.Brightness = 1.2
	glow.Range = 9
	glow.Parent = seal
	seal:SetAttribute("SealIndex", index)
	local p = prompt(seal, "Take Seal", "Kurogane iron seal", 0.5)
	p.Triggered:Connect(function(player)
		H.Event:FireClient(player, "seal", { index = index, total = #HanamiConfig.Seals })
		H.Note(player, "collect", { id = "Seal" .. index })
	end)
end

-- -------------------------------------------------------------------- raid --

type Raid = {
	wave: number,
	enemies: { Model },
	integrity: number,
	nextWaveAt: number?,
	emptyFor: number,
	lastStep: number,
	defenders: { [Player]: boolean },
}
local raid: Raid? = nil
local raidReadyAt = 0
local farmers: { Model } = {}  -- the market hands on the auction floor

local function site(): Vector3
	return at(HanamiConfig.Raid.site)
end

local function inYard(root: BasePart): boolean
	local d = root.Position - site()
	return Vector3.new(d.X, 0, d.Z).Magnitude <= HanamiConfig.Raid.radius and math.abs(d.Y) < 20
end

-- Everyone near the market hears how the raid goes -- and whoever defended it hears the end of
-- it wherever they have got to.
local function tellRaid(kind: string, data: { [string]: any }, defenders: { [Player]: boolean }?)
	for _, p in ipairs(Players:GetPlayers()) do
		local _, root = alive(p)
		if (root and (root.Position - site()).Magnitude < HanamiConfig.Raid.radius * 4) or (defenders and defenders[p]) then
			H.Event:FireClient(p, kind, data)
		end
	end
end

local function scareFarmers(on: boolean)
	for _, f in ipairs(farmers) do
		if f.Parent then
			f:SetAttribute("HandsUpAt", if on then workspace:GetServerTimeNow() else nil)
			f:SetAttribute("HandsUpFor", if on then 600 else nil)
		end
	end
end

local function clearRaiders(r: Raid, after: number)
	local list = r.enemies
	task.delay(after, function()
		for _, m in ipairs(list) do
			if m.Parent then
				m:Destroy()
			end
		end
	end)
end

local function startWave(r: Raid)
	r.wave += 1
	r.nextWaveAt = nil
	local wave = HanamiConfig.Raid.waves[r.wave]
	local from = HanamiConfig.Raid.from
	for i, archetype in ipairs(wave) do
		local spot = from[(i - 1) % #from + 1] + Vector3.new(math.random(-6, 6), 0, math.random(-6, 6))
		local model = H.Spawn(archetype, spot, { HanamiRaid = true })
		if model then
			table.insert(r.enemies, model)
		end
	end
	tellRaid("raid", { wave = r.wave, waves = #HanamiConfig.Raid.waves, left = #wave, integrity = math.floor(r.integrity),
		started = true })
end

local function endRaid(won: boolean, why: string?)
	local r = raid
	if not r then
		return
	end
	raid = nil
	scareFarmers(false)
	if won then
		raidReadyAt = H.Clock() + Jobs.RAID_COOLDOWN
		for p in pairs(r.defenders) do
			if p.Parent then
				H.Pay(p, Jobs.RAID_REWARD)
				H.Note(p, "survive", { site = "Market" })
				H.Event:FireClient(p, "raidWon", { coins = Jobs.RAID_REWARD.coins, xp = Jobs.RAID_REWARD.xp,
					crystals = Jobs.RAID_REWARD.crystals })
			end
		end
	else
		raidReadyAt = H.Clock() + 30
		tellRaid("raidLost", { why = why or "The raiders took the market" }, r.defenders)
	end
	clearRaiders(r, if won then 4 else 8)
end

--- Start the raid on the market, as `player`. Returns whether it started, and why not.
function Jobs.StartRaid(player: Player): (boolean, string?)
	if raid then
		return false, "already on"
	end
	local now = H.Clock()
	if now < raidReadyAt then
		H.Event:FireClient(player, "note", { title = "The raiders are regrouping",
			text = ("They'll be back in %ds"):format(math.ceil(raidReadyAt - now)) })
		return false, "cooldown"
	end
	local _, root = alive(player)
	if not root or not inYard(root) then
		return false, "not in the yard"
	end
	raid = { wave = 0, enemies = {}, integrity = 100, nextWaveAt = now + 4, emptyFor = 0, lastStep = now,
		defenders = { [player] = true } }
	scareFarmers(true)
	tellRaid("raid", { wave = 0, waves = #HanamiConfig.Raid.waves, left = 0, integrity = 100, incoming = 4 })
	return true, nil
end

function Jobs.Raid(): Raid?
	return raid
end

local function stepRaid(now: number)
	local r = raid
	if not r then
		return
	end
	local dt = math.clamp(now - r.lastStep, 0, 2)
	r.lastStep = now
	-- Who is holding the yard.
	local anyone = false
	for _, p in ipairs(Players:GetPlayers()) do
		local _, root = alive(p)
		if root and inYard(root) then
			r.defenders[p] = true
			anyone = true
		end
	end
	r.emptyFor = if anyone then 0 else r.emptyFor + dt
	if r.emptyFor >= Jobs.RAID_EMPTY then
		endRaid(false, "Nobody held the market")
		return
	end
	-- The raiders: keep them coming at the yard, and let the ones at the door wear it down.
	local living = {}
	for _, m in ipairs(r.enemies) do
		local humanoid = m:FindFirstChildOfClass("Humanoid")
		local root = m:FindFirstChild("HumanoidRootPart")
		if m.Parent and humanoid and humanoid.Health > 0 and root and root:IsA("BasePart") then
			table.insert(living, m)
			local d = root.Position - site()
			if Vector3.new(d.X, 0, d.Z).Magnitude < 12 then
				r.integrity -= Jobs.HOUSE_WEAR * dt
			end
		end
	end
	r.enemies = living
	local NPCService = H.Service("NPCService")
	if NPCService and NPCService.Noise then
		pcall(NPCService.Noise, site(), 260, nil)
	end
	if r.integrity <= 0 then
		endRaid(false, "The market fell")
		return
	end
	if r.nextWaveAt then
		if now >= r.nextWaveAt then
			startWave(r)
		end
	elseif #living == 0 and r.wave > 0 then
		if r.wave >= #HanamiConfig.Raid.waves then
			endRaid(true)
			return
		end
		r.nextWaveAt = now + Jobs.RAID_BREAK
		tellRaid("raid", { wave = r.wave, waves = #HanamiConfig.Raid.waves, left = 0, integrity = math.floor(r.integrity),
			cleared = true, incoming = Jobs.RAID_BREAK })
		return
	end
	tellRaid("raidTick", { wave = r.wave, waves = #HanamiConfig.Raid.waves, left = #living, integrity = math.floor(r.integrity) })
end

-- ------------------------------------------------------------------ wiring --

function Jobs.Wire(folder: Instance)
	local jobs: Instance = folder:FindFirstChild("Jobs") or Instance.new("Folder")
	jobs.Name = "Jobs"
	jobs.Parent = folder
	for _, d in ipairs(folder:GetDescendants()) do
		if d:IsA("BasePart") then
			if d.Name == "CaptiveSpot" then
				local index = tonumber(d:GetAttribute("Index")) or (#captives + 1)
				if not captives[index] then
					captives[index] = { spot = HanamiConfig.Local(d.Position) - Vector3.new(0, 0.5, 0), figure = nil, freedAt = nil }
					tie(index, jobs)
				end
			elseif d.Name == "Clue" and d:GetAttribute("ClueId") and not d:FindFirstChildOfClass("ProximityPrompt") then
				wireClue(d)
			elseif d.Name == "SealSpot" and not d:GetAttribute("Wired") then
				d:SetAttribute("Wired", true)
				wireSeal(d, jobs)
			elseif d.Name == "RaidSite" and not d:FindFirstChildOfClass("ProximityPrompt") then
				local p = prompt(d, "Defend the Market", "The auction floor · 3 waves", 1, 12)
				p.Triggered:Connect(function(player)
					Jobs.StartRaid(player)
				end)
			end
		end
	end
	-- The market hands on the auction floor, who put their hands up when the raiders come.
	if #farmers == 0 then
		for i, spec in ipairs(HanamiConfig.Raid.workers) do
			local figure = H.Figure({ Shirt = Color3.fromRGB(236, 236, 230), Pants = Color3.fromRGB(40, 60, 100), Sleeves = true,
				Outfit = { { "Hachimaki", colour = Color3.fromRGB(240, 240, 236) }, { "Apron", colour = Color3.fromRGB(40, 70, 130) }, { "Boots", colour = Color3.fromRGB(240, 240, 236) } } :: { any } },
				820 + i, spec.name, "MARKET HAND")
			if figure then
				local here = spec.at
				H.PlaceFigure(figure, here, HanamiConfig.Raid.site, jobs)
				table.insert(farmers, figure)
			end
		end
	end
end

function Jobs.Step(now: number)
	for index, c in pairs(captives) do
		if not c.figure and c.freedAt and now - c.freedAt >= Jobs.RETIE then
			local folder = H.Folder()
			local jobs = folder and folder:FindFirstChild("Jobs")
			if jobs then
				tie(index, jobs)
			end
		end
	end
	stepRaid(now)
end

--- The valley emptied: end anything running.
function Jobs.Reset()
	if raid then
		endRaid(false, "The raiders took the market")
	end
end

return Jobs
