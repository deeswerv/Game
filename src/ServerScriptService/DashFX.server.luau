--!strict
-- The streak a dash leaves behind, drawn for everyone.
--
-- The client already moves the character (Dashing.Dash); this only answers "show my dash
-- trail" by welding ReplicatedStorage.Effects.DashEffect to the dasher for half a second.
--
-- It replaces a server Script that used to be cloned into every character alongside a second,
-- duplicate dash controller -- both bound to Q, so one key press ran two dashes at once. One
-- handler here, rate limited, is the whole of it now.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Debris = game:GetService("Debris")

local COOLDOWN = 0.6             -- the client's own dash cooldown is longer; this only stops spam
local TRAIL_TIME = 0.5

local remotes = ReplicatedStorage:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedStorage
end
local DashEffect = Instance.new("RemoteEvent")
DashEffect.Name = "DashEffect"
DashEffect.Parent = remotes

local last: { [Player]: number } = {}

DashEffect.OnServerEvent:Connect(function(player: Player)
	local now = os.clock()
	if now - (last[player] or -math.huge) < COOLDOWN then
		return
	end
	last[player] = now

	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local effects = ReplicatedStorage:FindFirstChild("Effects")
	local template = effects and effects:FindFirstChild("DashEffect")
	if not root or not root:IsA("BasePart") or not humanoid or humanoid.Health <= 0 or not template then
		return
	end

	local effect = template:Clone()
	if effect:IsA("BasePart") then
		effect.CanCollide = false
		effect.CanQuery = false
		effect.CanTouch = false
		effect.Massless = true
		effect.Anchored = false
		effect.CFrame = root.CFrame
	end
	local weld = Instance.new("Weld")
	weld.Part0 = root
	weld.Part1 = effect :: any
	weld.Parent = effect
	effect.Parent = root
	Debris:AddItem(effect, 2)

	task.delay(TRAIL_TIME, function()
		local attachment = effect.Parent and effect:FindFirstChild("Attachment")
		local emitter = attachment and attachment:FindFirstChildOfClass("ParticleEmitter")
		if emitter then
			emitter.Enabled = false
		end
	end)
end)

Players.PlayerRemoving:Connect(function(player)
	last[player] = nil
end)
