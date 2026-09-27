--!strict
-- A robbed store's alarm: a red light beating over the till or the cash machine and a two-tone
-- ring out into the street, for as long as the robber's heat lasts (or until the job ends).
-- The bar and the tags are UI.Modules.Stickups; this is only the building going off.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local StickupEvent = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("StickupEvent") :: RemoteEvent

local RING = "rbxasset://sounds/electronicpingshort.wav"

local alarms: { [number]: () -> () } = {}

local function alarm(at: Vector3, seconds: number, robberId: number)
	local holder = Instance.new("Part")
	holder.Name = "StickupAlarm"
	holder.Anchored = true
	holder.CanCollide = false
	holder.CanQuery = false
	holder.CanTouch = false
	holder.Transparency = 1
	holder.Size = Vector3.new(0.4, 0.4, 0.4)
	holder.CFrame = CFrame.new(at + Vector3.new(0, 3, 0))
	holder.Parent = workspace
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 50, 40)
	light.Range = 26
	light.Brightness = 0
	light.Parent = holder
	local ring = Instance.new("Sound")
	ring.SoundId = RING
	ring.Volume = 0.9
	ring.RollOffMaxDistance = 160
	ring.Parent = holder

	local started = os.clock()
	local lastRing = -1
	local conn: RBXScriptConnection
	local function stop()
		if conn then
			conn:Disconnect()
		end
		holder:Destroy()
		if alarms[robberId] == stop then
			alarms[robberId] = nil
		end
	end
	conn = RunService.Heartbeat:Connect(function()
		local t = os.clock() - started
		if t > seconds then
			stop()
			return
		end
		-- Two beats a second, and a hi-lo ring on every other one.
		light.Brightness = if math.floor(t * 4) % 2 == 0 then 4 else 0.3
		local beat = math.floor(t / 0.55)
		if beat ~= lastRing then
			lastRing = beat
			ring.PlaybackSpeed = if beat % 2 == 0 then 1.25 else 0.95
			ring:Play()
		end
	end)
	if alarms[robberId] then
		alarms[robberId]()
	end
	alarms[robberId] = stop
end

StickupEvent.OnClientEvent:Connect(function(kind: unknown, data: unknown)
	if type(data) ~= "table" then
		return
	end
	local d = data :: any
	local robberId = tonumber(d.robberId) or 0
	if kind == "alarm" and typeof(d.at) == "Vector3" then
		alarm(d.at, tonumber(d.seconds) or 60, robberId)
	elseif (kind == "getaway" or kind == "stolen" or kind == "busted") and alarms[robberId] then
		alarms[robberId]()
	end
end)
