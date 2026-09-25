--!strict
-- Emotes, played on the server so everyone sees them.
--
-- The client asks by ID only. The server decides whether that ID exists, whether the player
-- is in a state to emote, and loads the animation itself -- so the worst a modified client
-- can do is play one of the eight emotes that were already on the menu.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EmoteConfig = require(ReplicatedStorage.EmoteConfig)

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

local active: { [Player]: AnimationTrack } = {}
local lastAt: { [Player]: number } = {}

local function stop(player: Player)
	local track = active[player]
	if track then
		pcall(function() track:Stop(0.15) end)
		active[player] = nil
	end
end

EmoteService.Stop = stop

function EmoteService.Play(player: Player, id: string): boolean
	local spec = EmoteConfig.Get(id)
	if not spec then
		return false
	end
	local now = os.clock()
	if now - (lastAt[player] or -math.huge) < EmoteConfig.COOLDOWN then
		return false
	end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")
	if not humanoid or not animator or humanoid.Health <= 0 then
		return false
	end
	-- Emoting mid-air or mid-sprint looks broken and is the usual way these get abused to
	-- slide around, so it is refused rather than corrected.
	local state = humanoid:GetState()
	if state == Enum.HumanoidStateType.Freefall or state == Enum.HumanoidStateType.Jumping then
		return false
	end

	stop(player)
	lastAt[player] = now

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
	active[player] = track

	if not spec.looping then
		task.delay(spec.length + 0.2, function()
			if active[player] == track then
				active[player] = nil
			end
		end)
	end
	return true
end

-- Moving cancels a looping emote. Checked against the humanoid rather than input, so it
-- works the same however the player is controlling the character.
local function watch(player: Player, character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if not humanoid or not humanoid:IsA("Humanoid") then
		return
	end
	humanoid.Running:Connect(function(speed)
		if speed > 0.5 and active[player] then
			stop(player)
		end
	end)
	humanoid.Died:Connect(function()
		stop(player)
	end)
end

EmotePlay.OnServerEvent:Connect(function(player, id)
	if typeof(id) ~= "string" then
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
