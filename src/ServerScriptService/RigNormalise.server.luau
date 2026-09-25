-- Keeps player characters on Motor6D rigging.
--
-- This Roblox build rigs R15 characters with AnimationConstraint + BallSocketConstraint
-- pairs instead of Motor6D. When both exist the Animator drives the constraints and every
-- Motor6D.C0 write in this game -- weapon pose, holster, reload, inspect -- silently does
-- nothing, because C0 is no longer what positions the limb. Measured: with the engine
-- rigging present the right shoulder moved 0.00003 over a run cycle; with it removed the
-- same clip moved it 1.32 and bent the elbow 0.65.
--
-- All 15 Motor6D joints are baked into StarterPlayer.StarterCharacter, so removing the
-- engine's constraint pass hands animation back to Motor6D, which is what the rest of the
-- codebase already speaks. The engine does not re-add them once removed.

local Players = game:GetService("Players")
local CollectionService = game:GetService("CollectionService")

-- Only the engine's own rigging. The ragdoll's sockets are named LAS/RAS/LLS/RLS/NS and
-- are deliberately left alone -- matching on the engine's "<Joint>BallSocket" suffix means
-- a ragdoll built later in the character's life is never touched.
local function isEngineRigging(inst: Instance): boolean
	if inst:IsA("AnimationConstraint") then
		return true
	end
	if inst:IsA("BallSocketConstraint") and inst.Name:sub(-10) == "BallSocket" then
		return true
	end
	return false
end

local function normalise(character: Model)
	for _, descendant in ipairs(character:GetDescendants()) do
		if isEngineRigging(descendant) then
			descendant:Destroy()
		end
	end

	-- Watch for the character's whole life, not just its first few seconds.
	--
	-- This used to stop after five seconds, on the assumption the engine only rigs at spawn.
	-- If that assumption is ever wrong -- an engine update, a rig rebuilt mid-game, an
	-- accessory added late -- the constraints come back, the Animator drives those instead,
	-- and every Motor6D.C0 write in the game becomes a silent no-op with no error to chase.
	-- That failure is invisible and would be brutal to diagnose; the connection is one cheap
	-- type check per descendant added, so it is not worth the risk to save it.
	local connection
	connection = character.DescendantAdded:Connect(function(descendant)
		if isEngineRigging(descendant) then
			descendant:Destroy()
		end
	end)

	-- Let go when the character does, so nothing is held alive after a respawn.
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			connection:Disconnect()
		end
	end)
end

local function watch(player: Player)
	player.CharacterAdded:Connect(normalise)
	if player.Character then
		normalise(player.Character)
	end
end

Players.PlayerAdded:Connect(watch)
for _, player in ipairs(Players:GetPlayers()) do
	watch(player)
end

-- NPCs wear the same R15 body (NPCService builds them from StarterCharacter), so they need
-- exactly the same protection: their weapon pose, reload and death animation all write
-- Motor6Ds. Tagged before they are parented, so this sees each one as it enters the world.
local function normaliseNPC(model: Instance)
	if model:IsA("Model") then
		normalise(model)
	end
end
CollectionService:GetInstanceAddedSignal("GameNPC"):Connect(normaliseNPC)
for _, model in ipairs(CollectionService:GetTagged("GameNPC")) do
	normaliseNPC(model)
end
