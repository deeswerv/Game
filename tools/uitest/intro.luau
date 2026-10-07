--!nocheck
-- The intro film (ReplicatedStorage.IntroCutscene), played through in the client emulator:
--
--   * the film is made from what is there: Hanami City's four shots, ZEE TOWER, a duel arena,
--     and you last; a place that is missing drops its shot;
--   * the camera rails pass through their keyframes (Catmull-Rom), ends included;
--   * played through without skipping, it letterboxes, types each place's name in, lands the
--     logo on you, then ends on black and puts the camera, the lens and the lighting back;
--   * with INTRO_CAMS=path it writes frames sampled along Hanami's shots (in the city's frame)
--     for tools/mapview (CAMFILE=path) to render over the real city.
--
--   lune run tools/uitest/intro.luau

local fs = require("@lune/fs")
local process = require("@lune/process")
local roblox = require("@lune/roblox")
local serde = require("@lune/serde")
local task = require("@lune/task")
local World = require("./world")
local R = World.R
local Vector3 = roblox.Vector3

task.delay(260, function()
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
local rs = World.service("ReplicatedStorage")

-- Stand-ins for the places the film visits (the server builds the real ones).
for _, name in ipairs({ "Hanami", "Downtown" }) do
	if not workspace:FindFirstChild(name) then
		local f = R.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
end
local arenas = workspace:FindFirstChild("Arenas") or R.new("Folder")
arenas.Name = "Arenas"
arenas.Parent = workspace
local arena = R.new("Folder")
arena.Name = "Arena_Test"
arena:SetAttribute("ZoneCentre", Vector3.new(0, 3000, 0))
arena.Parent = arenas

local Intro = World.require(rs:FindFirstChild("IntroCutscene"))

print("the film")
local shots = Intro.Shots()
local ids = {}
for _, s in ipairs(shots) do
	table.insert(ids, s.id)
end
check(table.concat(ids, ",") == "Hanami,Scramble,LanternRow,Castle,Downtown,Duels,You",
	"Hanami's four shots, ZEE TOWER, a duel arena, and you last (" .. table.concat(ids, ",") .. ")")
local total = 0
for _, s in ipairs(shots) do
	total += s.length
end
check(total > 30 and total < 45, ("about half a minute of film (%.1fs)"):format(total))
local titled = 0
for _, s in ipairs(shots) do
	if s.title then
		titled += 1
	end
end
check(titled == #shots - 1, "every place has its title card (you do not)")

print("the rails")
local worst = 0
for _, s in ipairs(shots) do
	local first = Intro.Frame(s, 0, 0)
	local last = Intro.Frame(s, 1, 0)
	worst = math.max(worst, (first.Position - s.keys[1].pos).Magnitude, (last.Position - s.keys[#s.keys].pos).Magnitude)
end
check(worst < 0.01, ("every shot starts and ends on its keyframes (%.3f)"):format(worst))
local pts = { Vector3.new(0, 0, 0), Vector3.new(10, 0, 0), Vector3.new(20, 10, 0), Vector3.new(30, 10, 0) }
local mid = Intro.Spline(pts, 1 / 3)
check((mid - pts[2]).Magnitude < 1e-6, "the spline passes through its middle points")
local smooth = true
for _, s in ipairs(shots) do
	local prev = Intro.Frame(s, 0, 0).Position
	local prevStep = nil
	for k = 1, 60 do
		local p = Intro.Frame(s, k / 60, 0).Position
		local step = (p - prev).Magnitude
		if prevStep and step > prevStep * 3 + 2 then
			smooth = false
		end
		prev, prevStep = p, step
	end
end
check(smooth, "the camera never jumps along a rail")

-- Frames along Hanami's shots, for the map viewer.
if process.env.INTRO_CAMS then
	local centre = Vector3.new(1100, 1000, 1500)
	local cams = {}
	for _, s in ipairs(shots) do
		if s.id == "Hanami" or s.id == "Scramble" or s.id == "LanternRow" or s.id == "Castle" then
			for _, u in ipairs({ 0.05, 0.5, 0.95 }) do
				local cf, fov = Intro.Frame(s, u, 0)
				local p = cf.Position - centre
				local l = p + cf.LookVector * 100
				table.insert(cams, { pos = { p.X, p.Y, p.Z }, look = { l.X, l.Y, l.Z }, fov = fov })
			end
		end
	end
	fs.writeFile(process.env.INTRO_CAMS, serde.encode("json", cams))
	print("  (wrote " .. #cams .. " frames to " .. process.env.INTRO_CAMS .. ")")
end

print("played through")
local camera = workspace.CurrentCamera
camera.FieldOfView = 70
local done = false
task.spawn(function()
	Intro.Play()
	done = true
end)
World.advance(0.5)
local gui = World.playerGui:FindFirstChild("IntroCutscene")
check(gui ~= nil and Intro.Playing(), "it starts, on black, with PROJECT ZEE PRESENTS")
check(lighting:FindFirstChild("IntroGrade") and lighting:FindFirstChild("IntroFocus") and lighting:FindFirstChild("IntroBlur"),
	"its grade, depth of field and blur are in")
World.advance(2.8)
local card = gui and gui:FindFirstChild("Card")
local title = card and card:FindFirstChild("Title")
check(card and card.Visible and title and title.Text == "HANAMI CITY", "the first card: HANAMI CITY")
local top = gui and gui:FindFirstChild("BarTop")
check(top and top.Size.Y.Scale > 0.1, "letterboxed")
check(camera.CameraType == roblox.Enum.CameraType.Scriptable, "the film has the camera")
local seen = {}
local logoSeen = false
for _ = 1, 650 do
	World.advance(0.1)
	if title and title.Text ~= "" then
		seen[title.Text] = true
	end
	local logo = gui and gui:FindFirstChild("Logo")
	if logo and logo.Visible then
		logoSeen = true
	end
	if done then
		break
	end
end
local names = 0
for _ in pairs(seen) do
	names += 1
end
check(names == #shots - 1, ("every place's name came up (%d)"):format(names))
check(logoSeen, "the logo lands at the end")
check(done and not Intro.Playing(), "it ends by itself")
check(World.playerGui:FindFirstChild("IntroCutscene") == nil, "and takes its screen away")
check(not lighting:FindFirstChild("IntroGrade") and not lighting:FindFirstChild("IntroFocus") and not lighting:FindFirstChild("IntroBlur"),
	"and its lighting")
check(math.abs(camera.FieldOfView - 70) < 0.01, "the lens is put back")
local root = World.character and World.character:FindFirstChild("HumanoidRootPart")
check(root and (camera.CFrame.Position - root.Position).Magnitude < 16, "the last shot ends on you")

print(if failures == 0 then "\27[32mall intro checks passed\27[0m" else ("\27[31m%d failed\27[0m"):format(failures))
process.exit(if failures == 0 then 0 else 1)
