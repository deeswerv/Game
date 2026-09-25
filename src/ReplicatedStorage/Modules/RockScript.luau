local GroundModule = {}
local TS = game:GetService("TweenService")
function GroundModule.Ground(part,ZSize,SC,Num,Time)
	local posi = CFrame.new(part.Position)
	local cfangle = posi * CFrame.Angles(0,math.rad(math.random(-360,360)),0)
	for v = 1,Num do
		local partclone = script.Part:Clone()
		partclone.Anchored = true
		partclone.CFrame = cfangle * CFrame.Angles(0,math.rad(360/Num*v),0)
		partclone.CFrame = partclone.CFrame * CFrame.new(0,-SC/2,0)
		local cf1 =  partclone.CFrame * CFrame.new(0,2,-10)
		local cf2 = partclone.CFrame * CFrame.new(0,2,-ZSize) * CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360)))
		game.Debris:AddItem(partclone,Time+1)
		local partonray,findrayatend = workspace:FindPartOnRayWithWhitelist(Ray.new(cf2.p+ Vector3.new(0,10,0),CFrame.new(cf2.p).UpVector*-20),{workspace})
		if partonray then
			local cf3 = nil
			partclone.Color = partonray.Color
			partclone.Material = partonray.Material
			cf3 = CFrame.new(findrayatend) * CFrame.Angles(math.rad(math.random(-360,360)),math.rad(math.random(-360,360)),math.rad(math.random(-360,360)))
			partclone.Parent = workspace
			if part == nil then
				TS:Create(partclone,TweenInfo.new(.27,Enum.EasingStyle.Exponential,Enum.EasingDirection.In,0,false,0),
{
						CFrame = cf3}):Play()
				TS:Create(partclone.Mesh,TweenInfo.new(.27,Enum.EasingStyle.Exponential,Enum.EasingDirection.InOut,0,false,0),
					{
						Scale = Vector3.new(SC,SC,SC)* (math.random(50,100)/100)
					}
				):Play()
			else
				partclone.CFrame = cf3
				partclone.Mesh.Scale = Vector3.new(SC,SC,SC)* (math.random(50,100)/100)
			end
			if part == nil then
				wait(.25)
			end
			local weld = nil
			if partonray:IsDescendantOf(workspace)== false and partonray.Anchored == false then
				weld = Instance.new("Weld",partclone)
				weld.C0 = partonray.CFrame:inverse()*partclone.CFrame
				weld.Part0 = partonray
				weld.Part1= partclone
				partclone.Anchored = false
			end
			delay(Time,function()
				if partclone and partclone:FindFirstChild("Mesh")==nil then
					partclone:Destroy()
					return
				end
				TS:Create(partclone.Mesh,TweenInfo.new(.5,Enum.EasingStyle.Cubic,Enum.EasingDirection.Out,0,false,0),
					{
						Scale = Vector3.new(0,0,0)
					}
				):Play()
				if weld ==nil then
					TS:Create(partclone,TweenInfo.new(.5,Enum.EasingStyle.Cubic,Enum.EasingDirection.Out,0,false,0),
						{
						CFrame = CFrame.new(partclone.CFrame.p)*CFrame.new(0,-partclone.Size.X,0)
						}
					):play()
				end
				game.Debris:AddItem(partclone,1)
			end)
		else
			partclone:Destroy()
		end
	end
end
return GroundModule
