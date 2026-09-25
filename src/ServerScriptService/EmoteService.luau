--!strict
-- Emotes, started on the server so everyone sees them.
--
-- The client asks by ID only. The server decides whether that ID exists and whether the
-- player is in a state to emote -- so the worst a modified client can do is play one of the
-- emotes that were already on the wheel.
--
-- Classic emotes are animation assets, played here on the character's Animator (which
-- replicates to everyone). Keyframe emotes -- the emote pack, see EmoteConfig -- are not
-- assets, so there is nothing to play: the character is marked instead,
--
--   Emote   = the emote's id
--   EmoteAt = workspace:GetServerTimeNow() when it started
--
-- and every client's EmoteAnimator poses it from ReplicatedStorage.EmoteData, all of them in
-- step because they count from the same server clock. Clearing the attributes ends it.
--
-- Either kind stops when the player moves, jumps, falls, takes damage, draws a weapon or
-- dies. A play-once keyframe emote also ends by itself when its time is up.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmoteConfig = require(ReplicatedStorage.EmoteConfig)
local EmoteIndex = require(ReplicatedStorage.EmoteData.Index) :: { [string]: { length: number, loop: boolean, intro: number } }

local EmoteService = {}

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local EmotePlay = remotes:FindFirstChild("EmotePlay")
if not EmotePlay then
	EmotePlay = Instance.new("RemoteEvent")
	EmotePlay.Name = "EmotePlay"
	EmotePlay.Parent = remotes
end

type Active = { track: AnimationTrack?, character: Model?, token: number }

local active: { [Player]: Active } = {}
local lastAt: { [Player]: number } = {}
local tokens = 0

local function stop(player: Player)
	local current = active[player]
	if not current then
		return
	end
	active[player] = nil
	if current.track then
		local track = current.track
		pcall(function() track:Stop(0.15) end)
	end
	local character = current.character
	if character and character:GetAttribute("EmoteToken") == current.token then
		character:SetAttribute("Emote", nil)
		character:SetAttribute("EmoteAt", nil)
		character:SetAttribute("EmoteToken", nil)
	end
end

EmoteService.Stop = stop

--- Whether `player` is doing an emote right now, and which.
function EmoteService.Current(player: Player): string?
	local character = player.Character
	local id = character and character:GetAttribute("Emote")
	if type(id) == "string" then
		return id
	end
	return active[player] and "classic" or nil
end

--- How long a keyframe emote runs, or nil if it runs until stopped (looping, or a held pose).
function EmoteService.Duration(id: string): number?
	local info = EmoteIndex[id]
	if not info or info.loop or info.length <= 0 then
		return nil
	end
	return info.length + (info.intro or 0)
end

function EmoteService.Play(player: Player, id: string): boolean
	local spec = EmoteConfig.Get(id)
	if not spec then
		return false
	end
	if spec.keyframe and not EmoteIndex[id] then
		return false
	end
	local now = os.clock()
	if now - (lastAt[player] or -math.huge) < EmoteConfig.COOLDOWN then
		return false
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not character or not humanoid or humanoid.Health <= 0 then
		return false
	end
	-- Emoting mid-air or mid-sprint looks broken and is the usual way these get abused to
	-- slide around, so it is refused rather than corrected.
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping
		or state == Enum.HumanoidStateType.Swimming or state == Enum.HumanoidStateType.Seated then
		return false
	end
	if humanoid.MoveDirection.Magnitude > 0.1 then
		return false
	end

	stop(player)
	lastAt[player] = now
	tokens += 1
	local token = tokens

	if spec.keyframe then
		-- Hands free: a rifle held through a breakdance is not a look anyone wants, and the
		-- weapon hold would fight the emote for the arms.
		humanoid:UnequipTools()
		character:SetAttribute("EmoteToken", token)
		character:SetAttribute("EmoteAt", workspace:GetServerTimeNow())
		character:SetAttribute("Emote", id)
		active[player] = { character = character, token = token }
		local duration = EmoteService.Duration(id)
		if duration then
			task.delay(duration, function()
				local current = active[player]
				if current and current.token == token then
					stop(player)
				end
			end)
		end
		return true
	end

	if not animator or not spec.animation then
		return false
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = spec.animation
	local ok, track = pcall(function()
		return animator:LoadAnimation(anim)
	end)
	anim:Destroy()
	if not ok or not track then
		return false
	end

	track.Priority = Enum.AnimationPriority.Action
	track.Looped = spec.looping == true
	track:Play(0.15)
	active[player] = { track = track, token = token }

	if not spec.looping then
		task.delay((spec.length or 1) + 0.2, function()
			local current = active[player]
			if current and current.token == token then
				active[player] = nil
			end
		end)
	end
	return true
end

-- What ends an emote. Checked against the humanoid rather than input, so it works the same
-- however the player is controlling the character.
local function watch(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	local function cancel()
		if active[player] then
			stop(player)
		end
	end
	humanoid.Running:Connect(function(speed)
		if speed > 0.5 then
			cancel()
		end
	end)
	humanoid.StateChanged:Connect(function(_, new)
		if new == Enum.HumanoidStateType.Jumping or new == Enum.HumanoidStateType.Freefall
			or new == Enum.HumanoidStateType.Swimming or new == Enum.HumanoidStateType.Seated
			or new == Enum.HumanoidStateType.Ragdoll or new == Enum.HumanoidStateType.FallingDown then
			cancel()
		end
	end)
	local health = humanoid.Health
	humanoid.HealthChanged:Connect(function(now)
		if now < health - 0.5 then
			cancel()
		end
		health = now
	end)
	humanoid.Died:Connect(cancel)
	character.ChildAdded:Connect(function(child)
		if child:IsA("Tool") then
			cancel()
		end
	end)
end

EmotePlay.OnServerEvent:Connect(function(player, id)
	if typeof(id) ~= "string" then
		return
	end
	if id == "" then
		stop(player)
		return
	end
	EmoteService.Play(player, id)
end)

local function onPlayer(player: Player)
	if player.Character then
		task.spawn(watch, player, player.Character)
	end
	player.CharacterAdded:Connect(function(char)
		active[player] = nil
		watch(player, char)
	end)
end

Players.PlayerAdded:Connect(onPlayer)
for _, p in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayer, p)
end
Players.PlayerRemoving:Connect(function(player)
	active[player] = nil
	lastAt[player] = nil
end)

return EmoteService
