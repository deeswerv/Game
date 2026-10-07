--!nocheck
-- The loading screen (ReplicatedFirst.LoadingScreen), run in the client emulator:
--
--   * it comes up at once, over everything, with the title, NOW ENTERING · DOWNTOWN, the bar
--     and a tip;
--   * once Downtown is there it opens onto it: the night thins away and the camera drifts up
--     the avenue toward ZEE TOWER (in the district, above the street, looking north);
--   * the bar fills; then it comes down by itself and hands the camera back.
--
--   lune run tools/uitest/loading.luau

local process = require("@lune/process")
local roblox = require("@lune/roblox")
local task = require("@lune/task")
local World = require("./world")
local R = World.R

task.delay(90, function()
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
local rf = World.service("ReplicatedFirst")
local downtown = R.new("Folder")
downtown.Name = "Downtown"
downtown.Parent = workspace

World.run(rf:FindFirstChild("LoadingScreen"))
World.advance(0.3)
local gui = World.playerGui:FindFirstChild("LoadingScreen")
check(gui ~= nil and gui.DisplayOrder >= 1000, "it comes up at once, over everything")
local backdrop = gui and gui:FindFirstChild("Backdrop")
local title = backdrop and World.find(backdrop, "Place")
local text = title and title:FindFirstChild("Text")
check(text ~= nil and text.Text:find("DOWNTOWN", 1, true) ~= nil, "NOW ENTERING · DOWNTOWN")
check(backdrop and World.find(backdrop, "Track") ~= nil and World.find(backdrop, "Tip") ~= nil, "a bar and a tip")

World.advance(1.6)
local camera = workspace.CurrentCamera
local night = backdrop and backdrop:FindFirstChild("Night")
check(camera.CameraType == roblox.Enum.CameraType.Scriptable, "Downtown is here: the screen takes the camera")
local p = camera.CFrame.Position
local centre = roblox.Vector3.new(-155, 1000, 1500)
local d = p - centre
check(math.abs(d.X) < 40 and d.Y > 15 and d.Y < 80 and d.Z < 0 and d.Z > -200,
	("over the avenue, south of the plaza (%.0f, %.0f, %.0f)"):format(d.X, d.Y, d.Z))
check(camera.CFrame.LookVector.Z > 0.5, "looking north, up toward ZEE TOWER")
check(night and night.BackgroundTransparency > 0.5, "the night thins away to show the city")
local caption = backdrop and backdrop:FindFirstChild("Caption")
check(caption and caption.Text:find("ZEE TOWER", 1, true) ~= nil, "and says where it is")
local before = camera.CFrame.Position
World.advance(1)
check((camera.CFrame.Position - before).Magnitude > 0.5, "the camera drifts")

for _ = 1, 120 do
	if not World.playerGui:FindFirstChild("LoadingScreen") then
		break
	end
	World.advance(0.25)
end
check(World.playerGui:FindFirstChild("LoadingScreen") == nil, "it comes down by itself")
check(camera.CameraType == roblox.Enum.CameraType.Custom, "and hands the camera back")

print(if failures == 0 then "\27[32mall loading checks passed\27[0m" else ("\27[31m%d failed\27[0m"):format(failures))
process.exit(if failures == 0 then 0 else 1)
