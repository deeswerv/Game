--!strict
-- Central kill attribution.
--
-- The old system read a "creator" ObjectValue off the dying Humanoid, but nothing
-- ever wrote one, so Kills never incremented. Every damage source now routes through
-- KillCredit.Damage, which stamps the attacker onto the victim before applying damage
-- and awards the kill when that victim dies.
--
-- Works for players and NPCs alike: anything with a Humanoid that takes damage
-- through this module is watched automatically, so future NPCs need no extra wiring.

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local KillCredit = {}

-- Fired after a kill is credited: (killer: Player, victimHumanoid: Humanoid, victimPlayer: Player?)
-- Progression listens to this so KillCredit stays unaware of levels and XP.
KillCredit.KillAwarded = Instance.new("BindableEvent")

-- Fired when any watched humanoid dies, whether or not anyone gets credit.
-- Gore listens to this so an NPC killed by another NPC still bursts.
KillCredit.HumanoidDied = Instance.new("BindableEvent")

local TAG_NAME = "creator"
-- How long a hit stays "fresh" enough to count as the kill. Without this, a player
-- who chipped someone an hour ago would steal the kill from whoever finished them.
local TAG_LIFETIME = 10

-- Humanoids we have already hooked, so repeated damage does not stack connections.
local watched: { [Humanoid]: boolean } = {}

local function awardKill(humanoid: Humanoid)
	local killer = KillCredit.GetKiller(humanoid)
	if not killer then
		return
	end

	-- Never credit a player for killing themselves.
	local victim = Players:GetPlayerFromCharacter(humanoid.Parent)
	if victim == killer then
		return
	end

	local stats = killer:FindFirstChild("leaderstats")
	local kills = stats and stats:FindFirstChild("Kills")
	if kills then
		kills.Value += 1
	end

	KillCredit.KillAwarded:Fire(killer, humanoid, victim)
end

local function watch(humanoid: Humanoid)
	if watched[humanoid] then
		return
	end
	watched[humanoid] = true

	-- NPC targets get revived by the Targets script, so a single humanoid can die
	-- more than once. Gate on a flag that clears when it comes back to life.
	local credited = false

	humanoid.HealthChanged:Connect(function(health: number)
		if health > 0 then
			credited = false
		end
	end)

	humanoid.Died:Connect(function()
		if credited then
			return
		end
		credited = true
		awardKill(humanoid)
		KillCredit.HumanoidDied:Fire(humanoid)
	end)

	humanoid.Destroying:Connect(function()
		watched[humanoid] = nil
	end)
end

-- Record that `player` is responsible for the current damage on `humanoid`.
function KillCredit.Tag(humanoid: Humanoid?, player: Player?)
	if not humanoid or not player then
		return
	end

	-- Most recent attacker wins, so drop any older tag.
	local existing = humanoid:FindFirstChild(TAG_NAME)
	if existing then
		existing:Destroy()
	end

	local tag = Instance.new("ObjectValue")
	tag.Name = TAG_NAME
	tag.Value = player
	tag.Parent = humanoid
	Debris:AddItem(tag, TAG_LIFETIME)

	watch(humanoid)
end

-- Who currently has credit for damaging `humanoid`, if anyone still in the game.
function KillCredit.GetKiller(humanoid: Humanoid?): Player?
	local tag = humanoid and humanoid:FindFirstChild(TAG_NAME)
	if not tag or not tag:IsA("ObjectValue") then
		return nil
	end

	local killer = tag.Value
	if killer and killer:IsA("Player") and killer.Parent == Players then
		return killer
	end
	return nil
end

-- Armour. A flat amount comes off every hit, but never more than ARMOUR_TAKES of it, so a
-- heavily armoured enemy shrugs off chip damage while a real hit still lands most of its
-- weight. Read from a SERVER-written attribute on the victim's model (NPCService sets it),
-- so nothing a client does can change it. Anything without the attribute is unaffected.
local ARMOUR_TAKES = 0.65

function KillCredit.Mitigate(humanoid: Humanoid?, amount: number): number
	local model = humanoid and humanoid.Parent
	local armour = model and model:GetAttribute("ArmorRating")
	if type(armour) ~= "number" or armour <= 0 or amount <= 0 then
		return amount
	end
	return math.max(amount - armour, amount * (1 - ARMOUR_TAKES))
end

-- Apply damage and attribute it. Use this instead of humanoid:TakeDamage.
-- `weapon` and `direction` are optional and only used for presentation: the ragdoll reads
-- them to know how hard, and which way, to throw the body. They are recorded on the
-- humanoid rather than passed through the death signal so that anything that already
-- calls Damage keeps working untouched.
function KillCredit.Damage(humanoid: Humanoid?, amount: number, player: Player?,
	weapon: string?, direction: Vector3?)
	if not humanoid or humanoid.Health <= 0 then
		return
	end

	if weapon then
		humanoid:SetAttribute("LastHitWeapon", weapon)
	end
	if typeof(direction) == "Vector3" and direction.Magnitude > 0 then
		humanoid:SetAttribute("LastHitDirection", direction.Unit)
	end

	KillCredit.Tag(humanoid, player)
	-- Tag() bails out when there is no attacking player, so watch here too: an NPC
	-- killed by another NPC still needs its death noticed.
	watch(humanoid)
	humanoid:TakeDamage(KillCredit.Mitigate(humanoid, amount))
end

return KillCredit
