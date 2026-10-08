--!nocheck
-- City life (CityLife.client), in the client emulator:
--
--   * a flock marker gets its pigeons, on the ground about the square, pottering about;
--   * walk up to them and the flock goes up -- wings out, climbing, wheeling round -- and
--     comes back down somewhere else on the square a while later;
--   * a shot nearby puts them up too; one far off does not;
--   * far from the camera they are put away;
--   * manholes steam and chimney pots smoke, and PERFORMANCE turns that off.
--
--   lune run tools/uitest/citylife.luau

local process = require("@lune/process")
local task = require("@lune/task")
local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R
local Vector3, CFrame = roblox.Vector3, roblox.CFrame

task.delay(150, function()
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
local cs = World.service("CollectionService")
local rs = World.service("ReplicatedStorage")

local GROUND = 100
local centre = Vector3.new(500, GROUND + 0.6, 500)
local city = R.new("Folder")
city.Name = "Downtown"
city.Parent = workspace
local marker = R.new("Part")
marker.Name = "PigeonFlock"
marker.Position = centre
marker:SetAttribute("Radius", 30)
marker:SetAttribute("Inner", 12)
marker:SetAttribute("Count", 8)
marker.Parent = city
cs:AddTag(marker, "PigeonFlock")
local manhole = R.new("Part")
manhole.Name = "Manhole"
manhole.Size = Vector3.new(0.05, 2.6, 2.6)
manhole.Position = centre + Vector3.new(60, 0, 0)
manhole.Parent = city
local chimney = R.new("Part")
chimney.Name = "ChimneyCap"
chimney.Size = Vector3.new(2, 0.4, 2)
chimney.Position = centre + Vector3.new(0, 40, 60)
chimney.Parent = city

R.ClassMethods.Workspace.Raycast = function(_, origin, direction)
	if direction.Y < 0 then
		return { Position = Vector3.new(origin.X, GROUND, origin.Z), Normal = Vector3.new(0, 1, 0), Instance = marker }
	end
	return nil
end
World.camera.CFrame = CFrame.new(centre + Vector3.new(0, 20, 60), centre)
local root = World.character:FindFirstChild("HumanoidRootPart")
root.CFrame = CFrame.new(centre + Vector3.new(0, 3, 200))

local sps = World.service("StarterPlayer"):FindFirstChild("StarterPlayerScripts")
World.run(sps:FindFirstChild("CityLife"))
World.advance(2)

local function birds()
	local folder = workspace:FindFirstChild("Pigeons")
	local list = {}
	if folder then
		for _, p in ipairs(folder:GetChildren()) do
			if p.Name == "PigeonBody" then
				table.insert(list, p)
			end
		end
	end
	return list, folder
end
local function heights()
	local lo, hi = math.huge, -math.huge
	for _, b in ipairs(birds()) do
		lo = math.min(lo, b.Position.Y - GROUND)
		hi = math.max(hi, b.Position.Y - GROUND)
	end
	return lo, hi
end
local function inSquare()
	local n = 0
	for _, b in ipairs(birds()) do
		local d = Vector3.new(b.Position.X - centre.X, 0, b.Position.Z - centre.Z).Magnitude
		if d > 11 and d < 31 then
			n += 1
		end
	end
	return n
end

print("the flock")
local list, folder = birds()
check(#list == 8 and folder and #folder:GetChildren() == 40, ("eight pigeons, each in five pieces (%d)"):format(#list))
local lo, hi = heights()
check(lo >= 0 and hi < 1.2 and inSquare() == 8, ("on the ground about the square (%.2f..%.2f)"):format(lo, hi))
local before = {}
for i, b in ipairs(list) do
	before[i] = b.Position
end
World.advance(6)
local moved = 0
for i, b in ipairs(birds()) do
	if (b.Position - before[i]).Magnitude > 0.3 then
		moved += 1
	end
end
check(moved >= 3, ("pottering about (%d moved)"):format(moved))

print("walk up to them")
local near = birds()[1].Position
root.CFrame = CFrame.new(near + Vector3.new(3, 2.5, 0))
World.advance(1.8)
lo, hi = heights()
check(lo > 1.5, ("the whole flock goes up (lowest %.1f studs up)"):format(lo))
local wing = workspace.Pigeons:FindFirstChild("PigeonWingL")
local bodyPart = workspace.Pigeons:FindFirstChild("PigeonBody")
check(wing and math.abs(bodyPart.CFrame:PointToObjectSpace(wing.Position).X) > 0.4, "wings out")
root.CFrame = CFrame.new(centre + Vector3.new(0, 3, 200))
World.advance(4)
lo, hi = heights()
check(hi > 12, ("climbing and wheeling over the square (%.1f up)"):format(hi))
World.advance(16)
lo, hi = heights()
check(hi < 1.2 and inSquare() == 8, ("and back down on the square (%.2f..%.2f)"):format(lo, hi))

print("gunfire")
local CombatFX = World.require(rs:FindFirstChild("CombatFX"))
CombatFX.Gunfire:Fire(centre + Vector3.new(300, 0, 0))
World.advance(2)
lo = heights()
check(lo < 1.2, "a shot far off: they stay put")
CombatFX.Gunfire:Fire(centre + Vector3.new(40, 0, 0))
World.advance(2)
lo = heights()
check(lo > 1.5, "a shot nearby: up they go")

print("far away")
World.camera.CFrame = CFrame.new(centre + Vector3.new(0, 20, 900))
World.advance(0.5)
local _, gone = birds()
check(gone == nil, "put away when the camera is far off")

print("steam and smoke")
local steam = manhole:FindFirstChild("Steam")
local smoke = chimney:FindFirstChild("Smoke")
check(steam and steam:FindFirstChildOfClass("ParticleEmitter").Enabled, "the manhole steams")
check(smoke and smoke:FindFirstChildOfClass("ParticleEmitter").Enabled, "the chimney smokes")
check((manhole.CFrame * steam.CFrame).Position.Y > manhole.Position.Y, "from its top")
World.player:SetAttribute("GraphicsQuality", 1)
World.advance(0.2)
check(not steam:FindFirstChildOfClass("ParticleEmitter").Enabled and not smoke:FindFirstChildOfClass("ParticleEmitter").Enabled,
	"PERFORMANCE turns them off")

print(if failures == 0 then "\27[32mall city life checks passed\27[0m" else ("\27[31m%d failed\27[0m"):format(failures))
process.exit(if failures == 0 then 0 else 1)
