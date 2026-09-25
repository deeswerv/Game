-- Dev range only. Keeps the measuring targets on their feet: once a target has stopped
-- taking fire for a moment, it goes back to full health, so a damage pass never has to
-- stop and rebuild dummies halfway through.
local IDLE_BEFORE_RESET = 3
local targets = script.Parent:WaitForChild("Targets")

for _, model in ipairs(targets:GetChildren()) do
	local hum = model:FindFirstChildOfClass("Humanoid")
	if hum then
		local lastHit = 0
		hum.HealthChanged:Connect(function(health)
			if health < hum.MaxHealth then
				lastHit = os.clock()
			end
		end)
		task.spawn(function()
			while true do
				task.wait(1)
				if hum.Health < hum.MaxHealth and os.clock() - lastHit >= IDLE_BEFORE_RESET then
					hum.Health = hum.MaxHealth
				end
			end
		end)
	end
end
