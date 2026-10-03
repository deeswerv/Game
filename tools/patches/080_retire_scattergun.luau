-- The Scattergun is out of the game. Its Tool leaves ReplicatedStorage.storeitems (which is
-- what the shop, drops and NPC hands all clone from), along with any loose copy left lying in
-- the world -- a display, a pickup, a copy in StarterPack. Its config, shop entry and NPC
-- loadouts are gone from src/, and PlayerDataManager.RetiredItems cleans saves that mention it.
return function(ctx)
	local removed = 0
	for _, root in ipairs({ ctx.game:GetService("ReplicatedStorage"), ctx.game:GetService("Workspace"),
		ctx.game:GetService("StarterPack"), ctx.game:GetService("ServerStorage") }) do
		for _, d in ipairs(root:GetDescendants()) do
			if d.Parent and d.Name == "Scattergun" then
				d:Destroy()
				removed += 1
			end
		end
	end
	print(("retired the Scattergun (%d instance%s)"):format(removed, if removed == 1 then "" else "s"))
end
