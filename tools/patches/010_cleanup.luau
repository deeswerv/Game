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
