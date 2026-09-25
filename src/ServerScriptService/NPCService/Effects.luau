--!strict
-- The one way NPC presentation leaves the server.
--
-- Shots, reloads, swings, flinches and deaths are all things a client only needs to SEE:
-- every decision behind them has already been made here. So they go out one way, on one
-- remote, batched once per AI tick and only to the players close enough to care.
--
-- Batching is the point. Ten enemies firing automatic weapons is a hundred shots a second;
-- as individual remotes to every player that is a flood, as one batch per tick per player
-- it is twenty small packets.
--
-- Server to client only. Nothing listens for this remote on the server, so there is
-- nothing here a client could call.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Effects = {}

-- Further than this and a player cannot make out the muzzle flash anyway.
local RANGE = 320

local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local remote = Remotes:FindFirstChild("NPCEffect") :: RemoteEvent?
if not remote then
	local created = Instance.new("RemoteEvent")
	created.Name = "NPCEffect"
	created.Parent = Remotes
	remote = created
end

type Queued = { position: Vector3, event: { any } }
local queue: { Queued } = {}

--- Queue an event that happened at `position`. Arguments must not contain nil -- a hole in
--- the array would truncate it in transit -- so pass `false` for "none".
function Effects.Send(position: Vector3, kind: string, ...: any)
	table.insert(queue, { position = position, event = { kind, ... } })
end

function Effects.Flush()
	if #queue == 0 then
		return
	end
	local pending = queue
	queue = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local root = character and character:FindFirstChild("HumanoidRootPart")
		-- No body (dead, respawning, watching a killcam): they get everything rather than
		-- nothing, because the camera is somewhere we cannot see from here.
		local at = root and root:IsA("BasePart") and root.Position or nil
		local batch: { any }? = nil
		for _, item in ipairs(pending) do
			if not at or (item.position - at).Magnitude <= RANGE then
				batch = batch or {}
				table.insert(batch :: { any }, item.event)
			end
		end
		if batch then
			(remote :: RemoteEvent):FireClient(player, batch)
		end
	end
end

return Effects
