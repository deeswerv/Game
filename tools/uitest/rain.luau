--!nocheck
-- Rain (Rain.client), in the client emulator:
--
--   * dry, nothing is drawn and nothing is touched;
--   * when the weather turns to Rain it fades in: streaks fall round the camera (slanting,
--     recycled at the foot), splashes on the ground, the streets take a sheen, the grade
--     cools -- and lightning strikes now and then, thunder after it;
--   * under a roof it eases right off;
--   * PERFORMANCE draws fewer streaks and no splashes;
--   * when it stops it all fades away and the streets are as they were.
--
--   lune run tools/uitest/rain.luau

local process = require("@lune/process")
local task = require("@lune/task")
local World = require("./world")
local roblox = require("@lune/roblox")
local Vector3 = roblox.Vector3
local R = World.R

task.delay(120, function()
	print("\27[31mtimed out\27[0m")
	process.exit(2)
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

World.loadPlace("build/Game.rbxl")
local workspace = World.service("Workspace")
local lighting = World.service("Lighting")
local city = R.new("Folder")
city.Name = "Downtown"
city.Parent = workspace
local road = R.new("Part")
road.Name = "Asphalt"
road.Size = Vector3.new(400, 2, 400)
road.Reflectance = 0
road.Parent = city
World.camera.CFrame = roblox.CFrame.new(0, 20, 0)

local roof = nil
R.ClassMethods.Workspace.Raycast = function(_, origin, direction)
	if roof and direction.Y > 0 then
		return { Position = origin + Vector3.new(0, 6, 0), Instance = roof, Normal = Vector3.new(0, -1, 0) }
	end
	if direction.Y < 0 then
		return { Position = Vector3.new(origin.X, 1, origin.Z), Instance = road, Normal = Vector3.new(0, 1, 0) }
	end
	return nil
end

local sps = World.service("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
World.run(sps:FindFirstChild("Rain"))
World.advance(1)

local function streaks()
	local folder = World.camera:FindFirstChild("Rain")
	local shown, total, near = 0, 0, 0
	if folder then
		for _, d in ipairs(folder:GetDescendants()) do
			if d:IsA("Beam") then
				total += 1
				if d.Enabled then
					shown += 1
					local p = d.Attachment0.Position
					local top, bottom = d.Attachment0.Position, d.Attachment1.Position
					if (Vector3.new(p.X, 0, p.Z) - Vector3.new(0, 0, 0)).Magnitude < 52 and bottom.Y < top.Y then
						near += 1
					end
				end
			end
		end
	end
	return shown, total, near, folder
end
local function emitter()
	local folder = World.camera:FindFirstChild("Rain")
	local s = folder and folder:FindFirstChild("Splashes")
	return s and s:FindFirstChild("Splash")
end

print("dry")
local shown, _, _, folder = streaks()
check(shown == 0 and folder == nil and road.Reflectance == 0, "nothing drawn, nothing touched")

print("it starts to rain")
workspace:SetAttribute("Weather", "Rain")
World.advance(1)
local early = streaks()
World.advance(4)
local count, total, near = streaks()
check(early > 0 and early < count, ("it fades in (%d streaks, then %d)"):format(early, count))
check(count >= 150 and near == count, ("%d streaks falling round the camera"):format(count))
local first = nil
for _, d in ipairs(World.camera.Rain:GetDescendants()) do
	if d:IsA("Beam") and d.Enabled then
		first = d
		break
	end
end
local y0 = first.Attachment0.Position.Y
World.advance(0.1)
check(first.Attachment0.Position.Y < y0 or first.Attachment0.Position.Y > y0 + 20, "and they fall (or start again at the top)")
local slant = first.Attachment1.Position - first.Attachment0.Position
check(slant.Y < 0 and (slant.X ~= 0 or slant.Z ~= 0), "slanting in the wind")
local e = emitter()
check(e and e.Rate > 100, "splashes on the ground")
check(road.Reflectance > 0.1, ("the street takes a sheen (%.2f)"):format(road.Reflectance))
local grade = lighting:FindFirstChild("RainGrade")
check(grade and grade.Enabled and grade.Saturation < 0, "the grade cools")
World.advance(60)
local thunder = nil
for _, s in ipairs(World.service("SoundService"):GetChildren()) do
	if s.Name == "Thunder" then
		thunder = s
	end
end
local struck = thunder ~= nil
check(struck, "lightning, then thunder")

print("under a roof")
roof = R.new("Part")
roof.Parent = workspace
World.advance(4)
local under = streaks()
check(under < count * 0.3, ("it eases off indoors (%d streaks)"):format(under))
roof = nil
World.advance(4)

print("PERFORMANCE")
World.player:SetAttribute("GraphicsQuality", 1)
World.advance(0.5)
local few = streaks()
check(few <= 50 and few > 0 and emitter().Rate == 0, ("fewer streaks (%d), no splashes"):format(few))
World.player:SetAttribute("GraphicsQuality", 3)

print("it stops")
workspace:SetAttribute("Weather", "Clear")
World.advance(6)
local after, _, _, gone = streaks()
check(after == 0 and gone == nil, "the rain fades away")
check(road.Reflectance == 0 and not grade.Enabled, "and the streets are dry again")

print(if failures == 0 then "\27[32mall rain checks passed\27[0m" else ("\27[31m%d failed\27[0m"):format(failures))
process.exit(if failures == 0 then 0 else 1)
