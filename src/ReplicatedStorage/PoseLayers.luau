--!strict
-- Extra movement layered onto a held weapon pose, handed between two client scripts.
--
-- WeaponPoseHold is the ONE writer of the arm and waist joints on anyone holding a gun: it
-- divides the animation back out every frame, and a second script writing the same joints
-- would simply lose to whichever ran last, with no error to show for it. So nothing else
-- writes them. Anything that wants the upper body to move -- an NPC's recoil, a flinch, a
-- death -- publishes an offset here instead, and WeaponPoseHold folds it in.
--
-- Identity when nothing is set, so reading it for every character every frame is free.

local PoseLayers = {}

type Layer = { right: CFrame, left: CFrame, waist: CFrame }

local layers: { [Instance]: Layer } = {}

function PoseLayers.Set(character: Instance, right: CFrame?, left: CFrame?, waist: CFrame?)
	layers[character] = {
		right = right or CFrame.identity,
		left = left or CFrame.identity,
		waist = waist or CFrame.identity,
	}
end

function PoseLayers.Clear(character: Instance)
	layers[character] = nil
end

--- Right arm, left arm and waist offsets for `character`.
function PoseLayers.Get(character: Instance): (CFrame, CFrame, CFrame)
	local layer = layers[character]
	if not layer then
		return CFrame.identity, CFrame.identity, CFrame.identity
	end
	return layer.right, layer.left, layer.waist
end

return PoseLayers
