
	local RunService = game:GetService("RunService")
local Players = game:GetService("Players")


	local Player = Players.LocalPlayer
local Character = script.Parent
local Humanoid = Character:WaitForChild"Humanoid"

-- WaitForChild, not a direct index: a character script can start before the rig has
-- finished assembling, and a plain index then throws "HumanoidRootPart is not a valid
-- member of Model" and kills the whole script. That is why this one has been erroring on
-- every spawn.
local HumanoidRootPart = Character:WaitForChild("HumanoidRootPart")

-- R15 joint layout. R6 kept every joint on the Torso; R15 splits the torso in two and
-- parents each joint to the limb it drives, so the hips live on the upper legs and the
-- root joint (named "Root", not "RootJoint") lives on the LowerTorso.
local LowerTorso = Character:WaitForChild("LowerTorso")
local LeftUpperLeg = Character:WaitForChild("LeftUpperLeg")
local RightUpperLeg = Character:WaitForChild("RightUpperLeg")

local RootJoint = LowerTorso:WaitForChild("Root")
local LeftHipJoint = LeftUpperLeg:WaitForChild("LeftHip")
local RightHipJoint = RightUpperLeg:WaitForChild("RightHip")

local function Lerp(a, b, c)
	return a + (b - a) * c
end

local Force = nil
local Direction = nil
local Value1 = 0
local Value2 = 0

local RootJointC0 = RootJoint.C0
local LeftHipJointC0 = LeftHipJoint.C0
local RightHipJointC0 = RightHipJoint.C0

RunService.RenderStepped:Connect(function()
	--> To get the force, we multiply the velocity by 1,0,1, we don't want the Y value so we set y to 0
	Force = HumanoidRootPart.Velocity * Vector3.new(1,0,1)
	if Force.Magnitude > 0.001 then
		--> This represents the direction
		Direction = Force.Unit	
		Value1 = HumanoidRootPart.CFrame.RightVector:Dot(Direction)
		Value2 = HumanoidRootPart.CFrame.LookVector:Dot(Direction)
	else
		Value1 = 0
		Value2 = 0
	end

	--> the values being multiplied are how much you want to rotate by

	RootJoint.C0 = RootJoint.C0:Lerp(RootJointC0 * CFrame.Angles(math.rad(Value2 * 12), math.rad(-Value1 * 20), 0), 0.2)
	LeftHipJoint.C0 = LeftHipJoint.C0:Lerp(LeftHipJointC0 * CFrame.Angles(math.rad(Value1 * 8), 0, 0), 0.2)
	RightHipJoint.C0 = RightHipJoint.C0:Lerp(RightHipJointC0 * CFrame.Angles(math.rad(-Value1 * 8), 0, 0), 0.2)
end)