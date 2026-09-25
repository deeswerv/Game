--!strict
-- Quests: accepting, tracking, completing, rewarding.
--
-- Progress lives on the ProfileService profile (CurrentQuest / QuestProgress /
-- CompletedQuests), so it survives rejoins alongside everything else. Objectives are
-- advanced by listening to KillCredit rather than by each quest wiring up its own
-- hooks, which is what keeps adding a quest to a single config entry.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local QuestConfig = require(ReplicatedStorage.QuestConfig)
local DialogueConfig = require(ReplicatedStorage.DialogueConfig)
local ReputationService = require(ServerScriptService.ReputationService)
local CrystalService = require(ServerScriptService.CrystalService)
local CosmeticConfig = require(ReplicatedStorage.CosmeticConfig)
local ShopService = require(ServerScriptService.ShopService)
local NPCConfig = require(ReplicatedStorage.NPCConfig)
local PlayerDataManager = require(ServerScriptService.PlayerDataManager)
local KillCredit = require(ServerScriptService.KillCredit)
local LevelSystem = require(ServerScriptService.LevelSystem)

local QuestService = {}

local remotes = ReplicatedStorage:FindFirstChild("GameRemotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "GameRemotes"
	remotes.Parent = ReplicatedStorage
end

local function ensureRemote(className: string, name: string)
	local existing = remotes:FindFirstChild(name)
	if existing then
		return existing
	end
	local r = Instance.new(className)
	r.Name = name
	r.Parent = remotes
	return r
end

local OpenDialogue = ensureRemote("RemoteEvent", "OpenDialogue") :: RemoteEvent
local QuestAction = ensureRemote("RemoteFunction", "QuestAction") :: RemoteFunction
local QuestUpdated = ensureRemote("RemoteEvent", "QuestUpdated") :: RemoteEvent

local function profileOf(player: Player)
	local ok, replica = pcall(function()
		return PlayerDataManager:GetPlayerDataReplica(player):expect()
	end)
	if ok then
		return replica
	end
	return nil
end

local function completedSet(data): { [string]: boolean }
	local set = {}
	for _, id in ipairs(data.CompletedQuests or {}) do
		set[id] = true
	end
	return set
end

local function levelOf(player: Player): number
	local stats = player:FindFirstChild("Stats")
	local lv = stats and stats:FindFirstChild("Level")
	return (lv and lv:IsA("ValueBase")) and (lv :: any).Value or 1
end

-- What the client needs to draw the tracker and the dialogue.
function QuestService.GetState(player: Player)
	local replica = profileOf(player)
	if not replica then
		return nil
	end
	local data = replica.Data
	local completed = completedSet(data)

	local active = data.CurrentQuest ~= "" and QuestConfig.Get(data.CurrentQuest) or nil
	local offer = QuestConfig.NextAvailable("Quartermaster", levelOf(player), completed)

	return {
		active = active and {
			id = active.id,
			title = active.title,
			label = active.objective.label,
			progress = data.QuestProgress or 0,
			goal = active.objective.count,
		} or nil,
		offer = (not active and offer) and {
			id = offer.id,
			title = offer.title,
			dialogue = offer.dialogue,
			summary = offer.summary,
			label = offer.objective.label,
			goal = offer.objective.count,
			coins = offer.rewards.coins,
			xp = offer.rewards.xp,
			-- A contract is paid for up front, so the price has to reach the card. Charging
			-- without showing the number would be indefensible.
			cost = offer.cost,
			crystals = offer.rewards.crystals,
			repeatable = offer.repeatable,
		} or nil,
		completedCount = #(data.CompletedQuests or {}),
		totalQuests = #QuestConfig.Quests,
	}
end

local function push(player: Player)
	QuestUpdated:FireClient(player, QuestService.GetState(player))
end

-- ---------------------------------------------------------------- dialogue --
--
-- The client is sent a node that has already been resolved: the body variant that matched,
-- and only the choices whose conditions the player actually meets. It never evaluates a
-- condition, and a choice it sends back is re-checked against the node it claims to come
-- from, so a forged "accept" is just an unknown choice on a node that does not offer it.

local function contextFor(player: Player)
	local state = QuestService.GetState(player)
	return {
		state = state,
		level = levelOf(player),
		hasActive = state ~= nil and state.active ~= nil,
		hasOffer = state ~= nil and state.offer ~= nil,
		completed = state and state.completedCount or 0,
		rep = ReputationService.GetAll(player),
		crystals = CrystalService.Get(player),
	}
end

-- An unknown key counts as UNMET, not as ignored: a typo should hide the line rather than
-- show it unconditionally everywhere.
local function requirementsMet(requires, ctx): boolean
	if not requires then
		return true
	end
	for key, want in pairs(requires) do
		if not DialogueConfig.Conditions[key] then
			return false
		end
		if key == "minLevel" and ctx.level < want then
			return false
		elseif key == "maxLevel" and ctx.level > want then
			return false
		elseif key == "hasOffer" and ctx.hasOffer ~= want then
			return false
		elseif key == "hasActive" and ctx.hasActive ~= want then
			return false
		elseif key == "completedAtLeast" and ctx.completed < want then
			return false
		elseif key == "minCrystals" then
			if ctx.crystals < want then
				return false
			end
		elseif key == "minRep" or key == "maxRep" then
			-- want = { faction = "Guard", value = 30 }
			if type(want) ~= "table" or type(want.faction) ~= "string" then
				return false
			end
			local have = ctx.rep[want.faction] or 0
			if key == "minRep" and have < want.value then
				return false
			elseif key == "maxRep" and have > want.value then
				return false
			end
		end
	end
	return true
end

local function fillTokens(text: string, ctx): string
	local s = ctx.state
	local active = s and s.active
	local offer = s and s.offer
	local map = {
		quest = active and active.title or (offer and offer.title) or "that job",
		objective = active and active.label or (offer and offer.label) or "",
		goal = tostring(active and active.goal or (offer and offer.goal) or 0),
		progress = tostring(active and active.progress or 0),
		coins = tostring(offer and offer.coins or (active and "") or ""),
		xp = tostring(offer and offer.xp or ""),
		-- Contracts are paid for, so a dialogue line can name the price.
		cost = tostring((offer and offer.cost) or ""),
		crystals_reward = tostring((offer and offer.crystals) or ""),
		completed = tostring(s and s.completedCount or 0),
		total = tostring(s and s.totalQuests or 0),
		level = tostring(ctx.level),
		crystals = tostring(ctx.crystals or 0),
	}
	-- A quest in progress knows its own payout only through the offer that started it, so
	-- fall back to the quest table rather than printing an empty reward.
	if active then
		local q = QuestConfig.Get(active.id)
		if q then
			-- A contract pays no coins, and tostring(nil) is the string "nil" -- which would
			-- have been printed at the player as a reward.
			map.coins = q.rewards.coins and tostring(q.rewards.coins) or ""
			map.xp = q.rewards.xp and tostring(q.rewards.xp) or ""
			map.cost = q.cost and tostring(q.cost) or ""
			map.crystals_reward = q.rewards.crystals and tostring(q.rewards.crystals) or ""
			map.objective = q.objective.label
		end
	end
	return (text:gsub("{(%w+)}", function(k)
		return map[k] or ("{" .. k .. "}")
	end))
end

local function bodyFor(node, ctx): string
	for _, variant in ipairs(node.body) do
		if requirementsMet(variant.requires, ctx) then
			-- "@offer" means "the quest's own pitch", so offer text lives with the quest
			-- rather than being duplicated into the dialogue tree. Substituted wherever it
			-- appears, so a line can greet you and then make the offer.
			local text = variant.text
			if text:find("@offer", 1, true) then
				local offer = ctx.state and ctx.state.offer
				text = text:gsub("@offer", offer and (offer.dialogue or offer.summary) or "")
			end
			return fillTokens(text, ctx)
		end
	end
	return ""
end

--- Resolve `nodeId` of `giverId` for this player. Returns nil for an unknown giver or node.
function QuestService.ResolveNode(player: Player, giverId: string, nodeId: string?)
	local tree = DialogueConfig.Tree(giverId)
	if not tree then
		return nil
	end
	local id = nodeId or tree.entry
	local node = tree.nodes[id]
	if not node then
		return nil
	end
	local ctx = contextFor(player)
	local choices = {}
	for _, choice in ipairs(node.choices) do
		if requirementsMet(choice.requires, ctx) then
			table.insert(choices, { id = choice.id, text = choice.text })
		end
	end
	return { giver = giverId, node = id, body = bodyFor(node, ctx), choices = choices }
end

--- Take `choiceId` at `nodeId`. Every step is re-validated: the giver, the node, that the
--- choice exists ON that node, and that the player still meets its conditions.
function QuestService.Choose(player: Player, giverId: string, nodeId: string, choiceId: string)
	local tree = DialogueConfig.Tree(giverId)
	local node = tree and tree.nodes[nodeId]
	if not node then
		return { ok = false, reason = "Unknown dialogue" }
	end

	local chosen
	for _, c in ipairs(node.choices) do
		if c.id == choiceId then
			chosen = c
			break
		end
	end
	if not chosen or not requirementsMet(chosen.requires, contextFor(player)) then
		return { ok = false, reason = "You can't say that" }
	end

	local action = chosen.action
	if action.kind == "Close" then
		return { ok = true, close = true }
	elseif action.kind == "Goto" then
		return { ok = true, next = QuestService.ResolveNode(player, giverId, action.node) }
	elseif action.kind == "AcceptQuest" then
		local state = QuestService.GetState(player)
		local offer = state and state.offer
		if not offer then
			return { ok = false, reason = "Nothing on offer" }
		end
		local result = QuestService.Accept(player, offer.id)
		result.next = QuestService.ResolveNode(player, giverId, tree.entry)
		return result
	elseif action.kind == "CraftCosmetic" then
		-- Charge first, and only grant if the charge actually went through: the reverse
		-- order hands out the item and then discovers the player could not pay.
		local CrystalConfigLocal = require(ReplicatedStorage.CrystalConfig)
		local cost = CrystalConfigLocal.CRAFT_COST
		local pool = {}
		for _, item in ipairs(CosmeticConfig.Items) do
			if not ShopService.OwnsInField(player, "OwnedCosmetics", item.id) then
				table.insert(pool, item)
			end
		end
		if #pool == 0 then
			return { ok = false, reason = "You already own everything I could make" }
		end
		if not CrystalService.Spend(player, cost) then
			return { ok = false, reason = "Not enough crystals" }
		end
		local won = pool[math.random(#pool)]
		ShopService.Grant(player, "OwnedCosmetics", won.id)
		local result = { ok = true, reason = "He works the crystals into a " .. won.name }
		result.next = QuestService.ResolveNode(player, giverId, tree.entry)
		return result
	elseif action.kind == "AbandonQuest" then
		local result = QuestService.Abandon(player)
		result.next = QuestService.ResolveNode(player, giverId, tree.entry)
		return result
	end
	return { ok = false, reason = "Unknown action" }
end

function QuestService.Accept(player: Player, questId: string)
	local replica = profileOf(player)
	if not replica then
		return { ok = false, reason = "Your data is still loading" }
	end
	local data = replica.Data
	if data.CurrentQuest ~= "" then
		return { ok = false, reason = "Finish your current job first" }
	end

	local quest = QuestConfig.Get(questId)
	if not quest then
		return { ok = false, reason = "No such quest" }
	end
	-- A contract is meant to be taken again; only the story chain is once-only.
	if not quest.repeatable and completedSet(data)[questId] then
		return { ok = false, reason = "Already completed" }
	end
	if levelOf(player) < quest.levelRequired then
		return { ok = false, reason = "Requires level " .. quest.levelRequired }
	end

	-- Paid up front, and the price is read from the config here on the server. The client
	-- sends an id and nothing else; it never names a cost.
	if quest.cost and quest.cost > 0 then
		local stats = player:FindFirstChild("leaderstats")
		local coins = stats and stats:FindFirstChild("Coins")
		if not (coins and coins:IsA("IntValue")) then
			return { ok = false, reason = "Your purse is still loading" }
		end
		if coins.Value < quest.cost then
			return { ok = false, reason = string.format("That contract costs %d coins", quest.cost) }
		end
		coins.Value -= quest.cost
	end

	replica:SetValue("CurrentQuest", questId)
	replica:SetValue("QuestProgress", 0)
	push(player)
	return { ok = true, reason = "Accepted: " .. quest.title }
end

function QuestService.Abandon(player: Player)
	local replica = profileOf(player)
	if not replica then
		return { ok = false, reason = "Your data is still loading" }
	end
	replica:SetValue("CurrentQuest", "")
	replica:SetValue("QuestProgress", 0)
	push(player)
	return { ok = true, reason = "Abandoned" }
end

local function complete(player: Player, replica, quest)
	local data = replica.Data

	-- A repeatable contract is deliberately NOT recorded as completed: that is the whole
	-- mechanism by which it stays on the board.
	if not quest.repeatable then
		local done = table.clone(data.CompletedQuests or {})
		table.insert(done, quest.id)
		replica:SetValue("CompletedQuests", done)
	end
	replica:SetValue("CurrentQuest", "")
	replica:SetValue("QuestProgress", 0)

	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if coins and coins:IsA("IntValue") and quest.rewards.coins then
		coins.Value += quest.rewards.coins
	end
	if quest.rewards.xp then
		LevelSystem.AwardXP(player, quest.rewards.xp)
	end
	if quest.rewards.crystals then
		CrystalService.Award(player, quest.rewards.crystals)
	end

	QuestUpdated:FireClient(player, QuestService.GetState(player), {
		completed = quest.title,
		coins = quest.rewards.coins,
		xp = quest.rewards.xp,
		crystals = quest.rewards.crystals,
	})
end

--- Does this kill count toward this objective?
---
--- Pulled out of RegisterKill so it can be tested on its own: the rest of RegisterKill
--- needs a loaded profile with an active quest, which makes the matching rules -- the part
--- that actually has edge cases -- the hardest bit to exercise.
function QuestService.ObjectiveMatches(obj, victimArchetype: string?, ctx): boolean
	if obj.kind == "Kill" then
		if not victimArchetype then
			return false -- an NPC objective is not advanced by killing players
		end
		return obj.archetype == "Any" or obj.archetype == victimArchetype
	elseif obj.kind == "KillPlayer" then
		return victimArchetype == nil
	elseif obj.kind == "KillElite" then
		return victimArchetype ~= nil and ctx ~= nil and ctx.elite == true
	elseif obj.kind == "KillInZone" then
		if not victimArchetype or not ctx or ctx.zone ~= obj.zone then
			return false
		end
		return obj.archetype == nil or obj.archetype == "Any" or obj.archetype == victimArchetype
	end
	-- Reach and anything unknown are not advanced by kills.
	return false
end

-- Advance a kill objective. `victimArchetype` is nil when the victim was a player.
--
-- `ctx` carries what else was true about the victim -- whether it was an elite, and which
-- zone it died in -- both read off attributes NPCService already stamps on the model. That
-- is what lets "kill two elites" and "kill eight things in the Flats" exist without any new
-- tracking: the data was already there, it just was not being looked at.
function QuestService.RegisterKill(player: Player, victimArchetype: string?, ctx)
	local replica = profileOf(player)
	if not replica then
		return
	end
	local data = replica.Data
	if data.CurrentQuest == "" then
		return
	end

	local quest = QuestConfig.Get(data.CurrentQuest)
	if not quest then
		return
	end

	if not QuestService.ObjectiveMatches(quest.objective, victimArchetype, ctx) then
		return
	end

	local obj = quest.objective
	local progress = (data.QuestProgress or 0) + 1
	if progress >= obj.count then
		complete(player, replica, quest)
	else
		replica:SetValue("QuestProgress", progress)
		push(player)
	end
end

-- One hook for every quest, rather than each quest wiring its own.
KillCredit.KillAwarded.Event:Connect(function(killer: Player, victimHumanoid: Humanoid, victimPlayer: Player?)
	local archetype = nil
	local ctx = nil
	if not victimPlayer then
		local model = victimHumanoid.Parent
		archetype = model and model:GetAttribute("Archetype") or nil
		if not archetype then
			return -- a humanoid that is not one of our NPCs (training dummy, prop)
		end
		ctx = {
			elite = model:GetAttribute("Elite") == true,
			zone = model:GetAttribute("Zone"),
		}
	end
	task.spawn(QuestService.RegisterKill, killer, archetype, ctx)
end)

-- ------------------------------------------------------------------- travel --
--
-- "Go and look at X" objectives. Polled rather than driven by a touch part: a trigger
-- volume has to exist in the world, be streamed in, and be stood on precisely, whereas a
-- distance check works anywhere a config can name a point.
--
-- Only players actually carrying a Reach quest are examined, so this costs nothing for
-- everyone else.
function QuestService.RegisterReach(player: Player)
	local replica = profileOf(player)
	if not replica then
		return
	end
	local data = replica.Data
	if data.CurrentQuest == "" then
		return
	end
	local quest = QuestConfig.Get(data.CurrentQuest)
	local obj = quest and quest.objective
	if not obj or obj.kind ~= "Reach" then
		return
	end

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end
	-- Prefer a ZONE over a radius. A circle around a point either misses the edges of an
	-- island or spills onto the next one: measured, radius 110 on the Flats left both its
	-- east and west ends (173 and 167 studs out) not counting, while a radius wide enough
	-- to cover them came within 8 studs of the neighbouring island's centre. The zone
	-- bounds already describe the island exactly, so use them.
	if obj.zone then
		local zone = NPCConfig.ZoneAt(root.Position)
		if zone and zone.id == obj.zone then
			complete(player, replica, quest)
		end
		return
	end

	-- Horizontal distance only: standing on a roof above the marker still counts as having
	-- got there, and the islands sit at wildly different heights.
	local here = Vector3.new(root.Position.X, 0, root.Position.Z)
	local there = Vector3.new(obj.position.X, 0, obj.position.Z)
	if (here - there).Magnitude <= (obj.radius or 60) then
		complete(player, replica, quest)
	end
end

task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			QuestService.RegisterReach(player)
		end
	end
end)

QuestAction.OnServerInvoke = function(player, action, arg)
	if action == "state" then
		return QuestService.GetState(player)
	elseif action == "accept" then
		return QuestService.Accept(player, tostring(arg))
	elseif action == "abandon" then
		return QuestService.Abandon(player)
	elseif action == "dialogue" then
		-- arg = { giver = string, node = string? }
		if typeof(arg) ~= "table" then
			return nil
		end
		return QuestService.ResolveNode(player, tostring(arg.giver), arg.node and tostring(arg.node) or nil)
	elseif action == "choose" then
		-- arg = { giver = string, node = string, choice = string }
		if typeof(arg) ~= "table" then
			return { ok = false, reason = "Bad request" }
		end
		return QuestService.Choose(player, tostring(arg.giver), tostring(arg.node), tostring(arg.choice))
	end
	return { ok = false, reason = "Unknown action" }
end

-- ------------------------------------------------------------- the giver NPC --

-- A signpost beside the giver, in the same wood-and-lantern language as the market
-- stall. Without it the giver is a person standing in a field, which reads as scenery;
-- with it, the spot reads as somewhere to go.
local WOOD = Color3.fromRGB(94, 63, 42)
local WOOD_DARK = Color3.fromRGB(66, 44, 30)
local LAMP = Color3.fromRGB(226, 180, 92)

local function buildSignpost(base: CFrame, text: string): Model
	-- Its own Model rather than loose parts in the rig: a Humanoid's model should contain
	-- the rig and nothing else, or the pivot and bounding box stop meaning what they say.
	local parent = Instance.new("Model")
	parent.Name = "Signpost"

	local function slab(pName: string, size: Vector3, cf: CFrame, colour: Color3, collide: boolean)
		local p = Instance.new("Part")
		p.Name = pName
		p.Size = size
		p.CFrame = cf
		p.Color = colour
		p.Material = Enum.Material.WoodPlanks
		p.Anchored = true
		p.CanCollide = collide
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		p.Parent = parent
		return p
	end

	slab("PostBase", Vector3.new(1.6, 0.5, 1.6), base * CFrame.new(0, 0.25, 0), WOOD_DARK, true)
	slab("Post", Vector3.new(0.55, 8, 0.55), base * CFrame.new(0, 4, 0), WOOD_DARK, true)
	local board = slab("Board", Vector3.new(5.4, 1.9, 0.28), base * CFrame.new(0, 7.4, 0), WOOD, false)
	slab("BoardTrim", Vector3.new(5.8, 0.22, 0.34), base * CFrame.new(0, 8.45, 0), WOOD_DARK, false)

	-- Readable from both sides: a player coming the other way along the path should not
	-- have to walk round the post to find out what it says.
	for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
		local gui = Instance.new("SurfaceGui")
		gui.Face = face
		gui.CanvasSize = Vector2.new(540, 190)
		gui.Parent = board

		local label = Instance.new("TextLabel")
		label.Size = UDim2.fromScale(1, 1)
		label.BackgroundTransparency = 1
		label.Font = Enum.Font.GothamBold
		label.Text = text
		label.TextColor3 = LAMP
		label.TextScaled = true
		label.Parent = gui
	end

	local lantern = slab("Lantern", Vector3.new(0.8, 1.1, 0.8), base * CFrame.new(0, 9, 0), LAMP, false)
	lantern.Material = Enum.Material.Neon
	local light = Instance.new("PointLight")
	light.Color = LAMP
	light.Brightness = 2.5
	light.Range = 22
	light.Parent = lantern

	return parent
end

local function buildGiver(name: string, spec)
	local existing = workspace:FindFirstChild("QuestGiver_" .. name)
	if existing then
		existing:Destroy()
	end

	-- Reuse a rig from the world as the body, same as the merchant does.
	local template
	for _, d in ipairs(workspace:GetChildren()) do
		if d:IsA("Model") and d:FindFirstChildOfClass("Humanoid") and d:FindFirstChild("Head")
			and not Players:GetPlayerFromCharacter(d) then
			template = d
			break
		end
	end
	if not template then
		warn("[Quest] no rig available for the quest giver")
		return
	end

	local npc = template:Clone()
	npc.Name = "QuestGiver_" .. name
	-- Strip anything that came along from whichever body we borrowed. The nameplate and
	-- the prompt matter: the market shopkeeper is a valid rig, and cloning them without
	-- this leaves the quest giver wearing the market's sign.
	for _, s in ipairs(npc:GetDescendants()) do
		if s:IsA("LuaSourceContainer") or s:IsA("BodyColors")
			or s:IsA("BillboardGui") or s:IsA("ProximityPrompt") then
			s:Destroy()
		end
	end

	local hum = npc:FindFirstChildOfClass("Humanoid")
	if hum then
		hum.WalkSpeed = 0
		hum.JumpPower = 0
		hum.MaxHealth = math.huge
		hum.Health = math.huge
		hum.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	end

	for _, p in ipairs(npc:GetDescendants()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.CanCollide = false
			if p.Name == "Head" or p.Name:find("Arm") then
				p.Color = Color3.fromRGB(222, 186, 140)
			else
				p.Color = spec.colour
			end
		end
	end

	local facing = CFrame.lookAt(spec.position + Vector3.new(0, 3, 0),
		Vector3.new(spec.lookAt.X, spec.position.Y + 3, spec.lookAt.Z))
	npc:PivotTo(facing)
	npc.Parent = workspace

	-- The signpost stands at the giver's shoulder, turned the same way they are.
	local ground = CFrame.lookAt(spec.position, Vector3.new(spec.lookAt.X, spec.position.Y, spec.lookAt.Z))
	local sign = buildSignpost(ground * CFrame.new(2.6, 0, 0.4), spec.signText or "QUESTS")
	sign.Parent = npc

	local head = npc:FindFirstChild("Head")
	if head and head:IsA("BasePart") then
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.fromScale(10, 2.6)
		bb.StudsOffsetWorldSpace = Vector3.new(0, 3.2, 0)
		bb.AlwaysOnTop = true
		bb.MaxDistance = 90
		bb.Parent = head

		local title = Instance.new("TextLabel")
		title.Size = UDim2.fromScale(1, 0.55)
		title.BackgroundTransparency = 1
		title.Font = Enum.Font.GothamBold
		title.Text = spec.displayName
		title.TextColor3 = Color3.fromRGB(226, 180, 92)
		title.TextScaled = true
		title.Parent = bb

		local sub = Instance.new("TextLabel")
		sub.Position = UDim2.fromScale(0, 0.55)
		sub.Size = UDim2.fromScale(1, 0.45)
		sub.BackgroundTransparency = 1
		sub.Font = Enum.Font.GothamMedium
		sub.Text = "Press E to talk"
		sub.TextColor3 = Color3.fromRGB(150, 148, 142)
		sub.TextScaled = true
		sub.Parent = bb
	end

	local torso = npc:FindFirstChild("Torso") or npc:FindFirstChild("HumanoidRootPart")
	if torso and torso:IsA("BasePart") then
		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Talk"
		prompt.ObjectText = spec.displayName
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = torso

		prompt.Triggered:Connect(function(player)
			OpenDialogue:FireClient(player, name, spec.displayName,
				QuestService.GetState(player), QuestService.ResolveNode(player, name))
		end)
	end
end

for name, spec in pairs(QuestConfig.Givers) do
	buildGiver(name, spec)
end

local function onPlayerAdded(player: Player)
	task.spawn(function()
		task.wait(4)
		push(player)
	end)
end
Players.PlayerAdded:Connect(onPlayerAdded)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, p)
end

return QuestService
