script.Parent.OnServerEvent:Connect(function(plr)
	local char = plr.Character
	if not char then
		return
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	-- Guarded because it was not: the asset went missing at some point and this threw on
	-- every single dash, so the effect never drew and the console filled up instead.
	local template = game.ReplicatedStorage.Effects:FindFirstChild("DashEffect")
	if not (root and template) then
		return
	end
	local Effect = template:Clone()
	game.Debris:AddItem(Effect,2)
	local Weld = Instance.new("Weld")
	Weld.Part0 = root
	Effect.Parent = root
	Weld.Part1 = Effect
	Weld.Parent = Effect
	task.wait(0.5)
	if Effect.Parent then
		local emitter = Effect:FindFirstChild("Attachment")
		emitter = emitter and emitter:FindFirstChild("ParticleEmitter")
		if emitter then
			emitter.Enabled = false
		end
	end
end)