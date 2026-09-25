local coin = script.Parent

coin.Touched:Connect(function(hit)
	
	local plr = game.Players:GetPlayerFromCharacter(hit.Parent)
	
	if plr then
		
		plr.leaderstats.Coins.Value = plr.leaderstats.Coins.Value +10
	end
	
	coin:Destroy()
end)