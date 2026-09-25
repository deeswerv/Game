--!strict
-- Where smoke is standing right now, so enemies cannot see through it.
--
-- UtilityService adds a cloud when a smoke grenade pops; NPC perception asks whether a line
-- of sight passes through one. Players' own view is blocked by the cloud they can see (drawn
-- on every client); this is the same cloud as the AI understands it.

local UtilityConfig = require(game:GetService("ReplicatedStorage"):WaitForChild("UtilityConfig"))

local SmokeField = {}

type Cloud = { centre: Vector3, radius: number, untilAt: number }
local clouds: { Cloud } = {}

function SmokeField.Add(centre: Vector3, radius: number, duration: number)
	table.insert(clouds, { centre = centre, radius = radius, untilAt = os.clock() + duration })
end

--- Does the line from `a` to `b` pass through standing smoke?
function SmokeField.Blocks(a: Vector3, b: Vector3): boolean
	local now = os.clock()
	for i = #clouds, 1, -1 do
		local cloud = clouds[i]
		if now > cloud.untilAt then
			table.remove(clouds, i)
		elseif UtilityConfig.SegmentHitsSphere(a, b, cloud.centre, cloud.radius) then
			return true
		end
	end
	return false
end

function SmokeField.Count(): number
	return #clouds
end

function SmokeField.Clear()
	table.clear(clouds)
end

return SmokeField
