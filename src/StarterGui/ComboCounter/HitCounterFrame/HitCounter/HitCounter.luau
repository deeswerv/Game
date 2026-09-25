local HitCounter = {}

local TweenService = game:GetService("TweenService")
local CounterFrame = script.Parent.Parent

local TimeLeftBar = CounterFrame.TimeLeft.Time

local Duration = 2

local Hits = 0
local CurrentActive = 0

function HitCounter:Add()
	
	local FunctionActive = os.clock()
	CurrentActive = FunctionActive
	
	CounterFrame.Visible = true
	local Tween = TweenService:Create(CounterFrame, TweenInfo.new(.15), {Position = UDim2.new(math.random(5,15)/100, .5,math.random(35 ,65)/100,0)})
	Tween:Play()
	Tween:Destroy()
	CounterFrame.Size = UDim2.new(.1, 0, .1, 0)
	TimeLeftBar.Size = UDim2.new(1,0, 1, 0)
	
	Hits += 1
	
	CounterFrame.TextLabel.Text = tostring(Hits).." Strike Combo!"
	
	
	CounterFrame:TweenSize(UDim2.new(.2, 0, .2, 0), Enum.EasingDirection.In, Enum.EasingStyle.Sine, .15, true)
	TimeLeftBar:TweenSize(UDim2.new(0,0,1,0), Enum.EasingDirection.Out, Enum.EasingStyle.Sine, Duration, true)
	local Tween = TweenService:Create(CounterFrame, TweenInfo.new(.15), {Rotation = math.random(-15, 15)})
	Tween:Play()
	Tween:Destroy()
	
	
	
	
	task.delay(Duration,function()
		if FunctionActive == CurrentActive then
			CounterFrame:TweenSize(UDim2.new(.25, 0, .25, 0), Enum.EasingDirection.In, Enum.EasingStyle.Sine, .1, true)
			task.wait(.1)
			CounterFrame:TweenSize(UDim2.new(0, 0, 0, 0), Enum.EasingDirection.In, Enum.EasingStyle.Quint, .1, true)
			task.wait(.11)
			CounterFrame.Visible = false
			Hits = 0
		end
	end)
	
end

return HitCounter
