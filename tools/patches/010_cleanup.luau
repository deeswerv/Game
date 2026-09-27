-- Removes instances that belonged to retired or dead systems. Scripts are retired by
-- deleting their file from src/; this handles what is left around them.
return function(ctx)
	-- The duplicate Q-dash's folder (its LocalScript and effect script are retired) and the
	-- empty folders the other retired scripts leave behind.
	ctx.remove("StarterPlayer/StarterCharacterScripts/StarterCharacterScripts/Movement")
	ctx.remove("StarterGui/StarterGui")

	-- The combo counter: its remote was never fired by anything, so the UI could never show.
	ctx.remove("StarterGui/ComboCounter")
	ctx.remove("ReplicatedStorage/Events")

	-- An old shop card template nothing references, and a model pack's readme folder.
	ctx.remove("ReplicatedStorage/ItemName")
	ctx.remove("Workspace/Anime Outline! (Open)")

	-- The rig is Motor6D (see RigNormalise). StarterCharacter was saved carrying the engine's
	-- constraint rig as well: an AnimationConstraint and a "<Joint>BallSocket" beside each
	-- Motor6D, the AnimationConstraint under the joint's own name and ahead of it, so a
	-- FindFirstChild("RightShoulder") handed back the constraint. RigNormalise strips them
	-- from every spawned body anyway; taking them out of the template means nothing -- a
	-- script reading a body before RigNormalise reaches it, an NPC cloned from the template --
	-- ever sees them. The ragdoll's own sockets are not in the template and are not touched.
	local starter = ctx.find("StarterPlayer/StarterCharacter")
	if starter then
		local stripped = 0
		for _, d in starter:GetDescendants() do
			if d.ClassName == "AnimationConstraint"
				or (d.ClassName == "BallSocketConstraint" and string.sub(d.Name, -10) == "BallSocket") then
				d.Parent = nil
				stripped += 1
			end
		end
		print(`StarterCharacter: {stripped} engine rig constraints removed`)
	end

	-- Two unused lighting preset folders. Effects inside a Folder never render, and nothing
	-- reads them; the live effects are the direct children of Lighting.
	local lighting = ctx.game:GetService("Lighting")
	for _, child in lighting:GetChildren() do
		if child.ClassName == "Folder" and child.Name == "Lighting" then
			print("removed Lighting preset folder")
			child.Parent = nil
		end
	end
end
