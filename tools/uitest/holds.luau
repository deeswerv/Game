--!nocheck
-- Every gun in the hands, posed by the game's own WeaponPose, checked without Studio:
--
--   * one-handed guns point where the arm does;
--   * a two-handed gun is carried in front of the body the way the rest are -- not swung out
--     to the right where the off hand cannot reach it -- and its off hand is ON the weapon,
--     carrying and aiming.
--
-- The Warden - Dark Matter and the Longshot used to fail this: the reach fit chose between
-- the across-the-body carry and a swung-out one by the smaller slide down the barrel, the two
-- tied to a ten-thousandth of a stud, and both guns landed on the swung-out carry with the
-- off hand half a stud off the gun. The fit now puts the hand on the gun first.
--
--   lune run tools/uitest/holds.luau
local World = require("./world")
local Rig = require("./rig")
local Hold = require("../weapons/hold")

require("@lune/task").delay(280, function()
	print("\27[31mtimed out\27[0m")
	require("@lune/process").exit(2)
end)

local failures = 0
local function check(ok: boolean, what: string)
	if ok then
		print("  ok    " .. what)
	else
		failures += 1
		print("\27[31m  FAIL  " .. what .. "\27[0m")
	end
end

local place = World.loadPlace("build/Game.rbxl")
local rs = World.service("ReplicatedStorage")
local WeaponConfig = World.require(rs.WeaponConfig)
local ctx = Hold.setup(World, Rig, place)

-- How far the off hand may be from its spot on the weapon. The hand part is most of a stud
-- across, so a few tenths still reads as holding it: the loosest good hold is the Sparrow's
-- carry at 0.26, while the broken ones this guards against sat at 0.41 and 0.45.
local ON_WEAPON = 0.3

-- The rig the arm solver measures. StarterCharacter was once saved with the engine's own
-- constraint rig beside its joints -- an AnimationConstraint named like each Motor6D, listed
-- first -- so looking a joint up by name found the constraint, the solver threw, and no gun
-- in the game was ever posed. The build strips them; nothing by that name may be anything
-- but the joint.
print("the rig")
local template = place:GetService("StarterPlayer"):FindFirstChild("StarterCharacter")
local engineRig = 0
for _, d in ipairs(template:GetDescendants()) do
	if d.ClassName == "AnimationConstraint" or (d.ClassName == "BallSocketConstraint" and d.Name:sub(-10) == "BallSocket") then
		engineRig += 1
	end
end
check(engineRig == 0, ("StarterCharacter carries no engine constraint rig (%d found)"):format(engineRig))
local wrongJoint = {}
for _, j in ipairs({ { "RightUpperArm", "RightShoulder" }, { "RightLowerArm", "RightElbow" }, { "RightHand", "RightWrist" },
	{ "LeftUpperArm", "LeftShoulder" }, { "LeftLowerArm", "LeftElbow" }, { "LeftHand", "LeftWrist" },
	{ "UpperTorso", "Waist" }, { "Head", "Neck" } }) do
	local part = template:FindFirstChild(j[1])
	local found = part and part:FindFirstChild(j[2])
	if not (found and found.ClassName == "Motor6D") then
		table.insert(wrongJoint, j[2] .. "=" .. (found and found.ClassName or "missing"))
	end
end
check(#wrongJoint == 0, "each joint's name finds its Motor6D (" .. (#wrongJoint == 0 and "all" or table.concat(wrongJoint, ", ")) .. ")")

local names = {}
for _, tool in ipairs(rs:FindFirstChild("storeitems"):GetChildren()) do
	local cfg = WeaponConfig.Get(tool.Name)
	if tool:IsA("Tool") and cfg and cfg.Type == "Gun" then
		table.insert(names, tool.Name)
	end
end
table.sort(names)

for _, name in ipairs(names) do
	local cfg = WeaponConfig.Get(name)
	local twoHanded = (cfg.Hold or "TwoHanded") == "TwoHanded"
	print(name .. (twoHanded and "" or "  (one hand)"))
	for _, stance in ipairs({ "carry", "aim" }) do
		local ok, result = pcall(Hold.pose, ctx, name, stance)
		local r = ok and result.report or {}
		check(ok and r.solved, ("%s: WeaponPose solved a grip%s"):format(stance, ok and "" or (" -- " .. tostring(result))))
		if twoHanded then
			local miss = r.leftHandToSupport
			check(miss ~= nil and miss < ON_WEAPON,
				("%s: the off hand is on the weapon (%.2f studs off)"):format(stance, miss or -1))
			if stance == "carry" then
				check(r.yaw and r.yaw > 0 and r.yaw < 50,
					("carry: in front of the body like the other long guns, not swung out (yaw %.0f)"):format(r.yaw or 0))
			end
		else
			check(r.yaw ~= nil and math.abs(r.yaw) < 20, ("%s: points where the arm does (yaw %.0f)"):format(stance, r.yaw or 0))
		end
	end
end

print("")
if failures == 0 then
	print("\27[32mall hold checks passed\27[0m")
	require("@lune/process").exit(0)
else
	print(("\27[31m%d hold check(s) failed\27[0m"):format(failures))
	require("@lune/process").exit(1)
end
