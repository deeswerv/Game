--!strict
-- Vaulting a low wall: face one, press space.
--
-- Rewritten, and the reason matters. The original connected a NEW UserInputService.InputBegan
-- handler EVERY FRAME, from inside a RenderStepped loop, for as long as the player stood
-- near any surface that was not a vault wall. Nothing ever disconnected them. That is an
-- unbounded connection leak on every client, growing for the whole session, and each
-- surviving handler still held a closure over the character.
--
-- The detection was inverted on top of that: it set the "can vault" flag in the branch for
-- hitting a Vault part, but only created the handler in the branch for NOT hitting one, and
-- then tested the flag inside. Whether a vault fired depended on what you had been facing
-- the frame before.
--
-- Now: one connection, one raycast when the key is actually pressed, and no per-frame work
-- at all.

local Players = game:GetService("Players")

-- Taken from the script's own ancestry rather than player.Character: this script is cloned
-- into the character, so its ancestor IS the right character even on the frame a respawn
-- has not finished replacing player.Character yet.
local character = script:FindFirstAncestorWhichIsA("Model")
	 or Players.LocalPlayer.Character
	 or Players.LocalPlayer.CharacterAdded:Wait()
local root = character:WaitForChild("HumanoidRootPart") :: BasePart
local humanoid = character:WaitForChild("Humanoid") :: Humanoid
local animator = humanoid:FindFirstChildOfClass("Animator") or humanoid:WaitForChild("Animator")
local climb = animator:LoadAnimation(script:WaitForChild("ClimbAnim"))

-- Any real ledge, not a hand-tagged one.
--
-- The original only vaulted parts literally named "Vault". There are three of those in the
-- place file and NONE of them exist at runtime -- workspace.Map is not present in a running
-- game -- so the feature could never fire no matter how the script was written. Measuring
-- the geometry instead means it works on whatever the map actually has.
local REACH = 3.4          -- how close to the ledge you must be
-- The band is set against the ordinary jump, not picked by feel. JumpHeight is 7.2, so
-- anything under that is already clearable and a vault there would add nothing but a
-- surprise. This starts just above what a jump reaches and stops where a ledge stops being
-- something a person could haul themselves onto.
local MIN_LEDGE = 7.0
-- 14, not 13: a ledge measured at exactly the ceiling is rejected by floating point, and a
-- 13-stud test ledge duly failed while a 9-stud one cleared. Leave the boundary somewhere
-- no real ledge sits.
local MAX_LEDGE = 14.0
local HEADROOM = 3.0       -- clear space needed above the ledge to land in
local COOLDOWN = 0.75
local PUSH = 13            -- forward, to carry you over rather than straight up

local nextVaultAt = 0

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude
params.FilterDescendantsInstances = { character }

-- Returns how high the ledge in front is, or nil if there is nothing worth vaulting.
local function ledgeHeight(): number?
	local forward = root.CFrame.LookVector
	local feetY = root.Position.Y - humanoid.HipHeight - root.Size.Y * 0.5

	-- Cast from KNEE height, not from the root. The root sits at chest level, so a ray from
	-- there sails straight over anything low enough to actually be vaultable -- a 3-stud
	-- ledge passed clean underneath it and the check reported nothing ahead.
	local from = Vector3.new(root.Position.X, feetY + 1.0, root.Position.Z)
	local ahead = workspace:Raycast(from, forward * REACH, params)
	if not ahead then
		return nil
	end

	-- Find the top of whatever we just hit, by probing straight down from above it.
	local probeFrom = ahead.Position + forward * 0.6 + Vector3.new(0, MAX_LEDGE + 1, 0)
	local top = workspace:Raycast(probeFrom, Vector3.new(0, -(MAX_LEDGE + 2), 0), params)
	if not top then
		return nil                    -- nothing to stand on: a wall, not a ledge
	end

	local height = top.Position.Y - feetY
	if height < MIN_LEDGE or height > MAX_LEDGE then
		return nil
	end

	-- And somewhere to actually land.
	local headroom = workspace:Raycast(top.Position + Vector3.new(0, 0.2, 0),
		Vector3.new(0, HEADROOM, 0), params)
	if headroom then
		return nil
	end
	return height
end

-- Triggered off the JUMP ITSELF, not off the space bar.
--
-- Watching for the key is the wrong level to work at and it kept failing: Roblox's own
-- bindings claim these keys, InputBegan then arrives with gameProcessedEvent already true,
-- and a `processed` guard silently drops it. That has now bitten sprint (LeftShift), slide
-- (LeftControl) and this. The humanoid changing into Jumping is the actual event we care
-- about -- "they tried to jump at a ledge" -- and no input plumbing can swallow it.
humanoid.StateChanged:Connect(function(_, new)
	if new ~= Enum.HumanoidStateType.Jumping then
		return
	end
	if os.clock() < nextVaultAt or humanoid.Health <= 0 then
		return
	end
	local height = ledgeHeight()
	if not height then
		return
	end
	nextVaultAt = os.clock() + COOLDOWN

	-- Lift scaled to the ledge, with a margin, so a knee-high crate does not launch you and a
	-- chest-high wall is actually cleared. v = sqrt(2gh) is the speed needed to rise h.
	local gravity = workspace.Gravity
	local lift = math.sqrt(2 * gravity * (height + 1.2))

	-- Driven straight onto the assembly rather than through a BodyVelocity that then has to
	-- be cleaned up; there is nothing left behind if anything goes wrong mid-vault.
	root.AssemblyLinearVelocity = root.CFrame.LookVector * PUSH + Vector3.new(0, lift, 0)
	climb:Play()
end)