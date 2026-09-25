--!strict
-- Weapon inspection: bring the gun up, turn it over, put it back.
--
-- This is shaped exactly like ReloadAnimator -- it publishes a pair of shoulder offsets
-- that WeaponPoseHold multiplies into the hold pose. That is deliberate: inspection,
-- reloading and aiming all want to move the same two joints, and layering offsets means
-- they compose instead of fighting. Nothing here writes a joint directly.
--
-- Offsets are identity whenever nothing is being inspected, which is almost always, so
-- the cost when idle is one table lookup per character per frame.

local InspectController = {}

-- How long the weapon takes to come up and go back. Long enough to read as a movement,
-- short enough that it never feels like the game has taken the weapon off you.
local RAISE = 0.32
local LOWER = 0.26

-- How far the player can turn the weapon by dragging, in radians.
local YAW_LIMIT = math.rad(150)
local PITCH_LIMIT = math.rad(70)

-- The state of an inspection lives on the CHARACTER, as attributes, not inside this
-- module. Two reasons. It gives every script one source of truth to read and write --
-- input, animation and any test all agree by construction. And because attributes set on
-- the server replicate, the same code shows other players inspecting their weapons
-- without a second path for remote characters.
--
-- What stays local is the animation weight, because that is per client and per frame.
local ATTR_ACTIVE = "Inspecting"
local ATTR_YAW = "InspectYaw"
local ATTR_PITCH = "InspectPitch"

type State = {
	weight: number,       -- 0 = at the hold pose, 1 = fully inspecting
	lastStep: number,
}

local active: { [Model]: State } = {}

local function ease(t: number): number
	-- Smoothstep. Starts and stops gently, which is most of what makes it not look robotic.
	t = math.clamp(t, 0, 1)
	return t * t * (3 - 2 * t)
end

function InspectController.IsActive(character: Model): boolean
	return character:GetAttribute(ATTR_ACTIVE) == true
end

function InspectController.Begin(character: Model)
	character:SetAttribute(ATTR_ACTIVE, true)
end

function InspectController.End(character: Model)
	character:SetAttribute(ATTR_ACTIVE, false)
end

-- Drop everything, including the turn. Used when the weapon or the character goes away,
-- so a stale inspection cannot survive a respawn or a weapon switch.
function InspectController.Clear(character: Model)
	active[character] = nil
	character:SetAttribute(ATTR_ACTIVE, false)
	character:SetAttribute(ATTR_YAW, 0)
	character:SetAttribute(ATTR_PITCH, 0)
end

-- Turn the weapon by dragging. Clamped, so it can never wind up somewhere unreadable.
function InspectController.Turn(character: Model, dYaw: number, dPitch: number)
	if not InspectController.IsActive(character) then
		return
	end
	local yaw = (character:GetAttribute(ATTR_YAW) or 0) + dYaw
	local pitch = (character:GetAttribute(ATTR_PITCH) or 0) + dPitch
	character:SetAttribute(ATTR_YAW, math.clamp(yaw, -YAW_LIMIT, YAW_LIMIT))
	character:SetAttribute(ATTR_PITCH, math.clamp(pitch, -PITCH_LIMIT, PITCH_LIMIT))
end

-- Advance the animation. Called once a frame by WeaponPoseHold.
--
-- Rate based rather than timed from a start instant, so pressing the key again halfway
-- through simply reverses from wherever the weapon is instead of snapping to an end.
function InspectController.Step(character: Model)
	local want = InspectController.IsActive(character)
	local st = active[character]
	if not st then
		if not want then
			return
		end
		st = { weight = 0, lastStep = os.clock() }
		active[character] = st
	end

	local now = os.clock()
	local dt = math.clamp(now - st.lastStep, 0, 0.25)
	st.lastStep = now

	local rate = want and (1 / RAISE) or -(1 / LOWER)
	st.weight = math.clamp(st.weight + rate * dt, 0, 1)
	if st.weight <= 0 and not want then
		active[character] = nil
	end
end

-- The pair of shoulder offsets, in the same frame ReloadAnimator uses.
function InspectController.Offsets(character: Model): (CFrame, CFrame)
	local st = active[character]
	if not st or st.weight <= 0.001 then
		return CFrame.identity, CFrame.identity
	end
	-- Eased on read, so the stored weight can stay a simple linear ramp.
	local w = ease(st.weight)

	-- The inspection pose. The gun hand comes up and inwards so the weapon sits across the
	-- front of the body where it can be seen, and turns broadside rather than pointing at
	-- the camera. The off hand follows it in, so the support hand does not stay behind.
	--
	-- Everything is scaled by the weight, which is what makes it a movement rather than a
	-- cut, and what lets it blend with the reload and the aim rather than replacing them.
	local rightBase = CFrame.Angles(0, 0, math.rad(30) * w)
		* CFrame.Angles(math.rad(-26) * w, 0, 0)
	local leftBase = CFrame.Angles(0, 0, math.rad(-16) * w)
		* CFrame.Angles(math.rad(20) * w, 0, 0)

	-- A slow drift once it is up, so a weapon left held does not look frozen.
	local drift = (w > 0.98) and math.sin(os.clock() * 1.6) * math.rad(1.6) or 0

	-- The player's own turn, about the arm's length so the weapon spins in place.
	local yaw = (character:GetAttribute(ATTR_YAW) or 0) * w
	local pitch = (character:GetAttribute(ATTR_PITCH) or 0) * w
	local turn = CFrame.Angles(pitch, 0, 0) * CFrame.Angles(0, yaw, 0)

	return rightBase * turn * CFrame.Angles(drift, 0, 0), leftBase
end

return InspectController
