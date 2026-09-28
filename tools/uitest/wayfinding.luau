--!nocheck
-- Finding your way (UI.Modules.Wayfinding, and what Downtown marks for it), checked without
-- Studio on the real Downtown:
--
--   * the compass reads the way a compass does: north is up the avenue to ZEE TOWER (+Z), east
--     on your right (-X) -- and the street signs agree;
--   * Downtown marks its landmarks and its named areas, and the areas nest: a shop inside the
--     district, the plaza inside the district;
--   * facing north, N is in the middle of the strip and ZEE TOWER's icon over it; the job goes
--     up with its distance, a turf war and a supply drop come and go with their events;
--   * walking into a named area brings its name up; stepping back into the street does not
--     announce the district again; nobody is told the same place twice in a row;
--   * the job gets a marker in the world, which goes when the job does.
--
--   lune run tools/uitest/wayfinding.luau

local roblox = require("@lune/roblox")
local World = require("./world")
local R = World.R
local Vector3 = roblox.Vector3
local CFrame = World.CFrame

require("@lune/task").delay(120, function()
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
local sss = World.service("ServerScriptService")
local CS = World.service("CollectionService")
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("ArenaService"), sss)
R.mirror(place:GetService("ServerScriptService"):FindFirstChild("DistrictService"), sss)
local Downtown = World.require(sss.DistrictService.Downtown)
local CENTRE = Vector3.new(-155, 1000, 1500)
local folder = R.new("Folder")
folder.Name = "Downtown"
folder.Parent = World.workspace
Downtown.Build(folder, CENTRE)

local Wayfinding = World.require(rs.UI.Modules.Wayfinding)

print("which way is which")
check(Wayfinding.Bearing(0, 1) == 0 and Wayfinding.Bearing(-1, 0) == 90 and Wayfinding.Bearing(0, -1) == 180
	and Wayfinding.Bearing(1, 0) == 270, "north is +Z, east -X, south -Z, west +X")
check(Wayfinding.Relative(10, 350) == 20 and Wayfinding.Relative(350, 10) == -20, "the short way round")
local eastSign, westSign
for _, d in ipairs(folder:GetDescendants()) do
	if d.Name == "Sign_EAST END" then
		eastSign = d
	elseif d.Name == "Sign_WEST END" then
		westSign = d
	end
end
check(eastSign and westSign and eastSign.Position.X < CENTRE.X and westSign.Position.X > CENTRE.X,
	"the EAST END sign is on the compass's east side")

print("what Downtown marks")
local waypoints, areas = CS:GetTagged("Waypoint"), CS:GetTagged("Area")
local names = {}
for _, w in ipairs(waypoints) do
	names[w:GetAttribute("WaypointName")] = w
end
check(#waypoints >= 8 and names["ZEE TOWER"] and names["ZEE GUNS"] and names["DUEL HALL"] and names["THE FIXER"],
	("%d landmarks, the tower, the shops, the hall and the Fixer among them"):format(#waypoints))
local tower = names["ZEE TOWER"]
check(math.abs(tower.Position.X - CENTRE.X) < 1 and tower.Position.Z > CENTRE.Z + 100, "ZEE TOWER is due north")
check(#areas >= 10, ("%d named areas"):format(#areas))
local invisible = true
for _, p in ipairs(waypoints) do
	invisible = invisible and p.Transparency == 1 and not p.CanCollide and not p.CanQuery
end
for _, p in ipairs(areas) do
	invisible = invisible and p.Transparency == 1 and not p.CanCollide and not p.CanQuery and not p.CanTouch
end
check(invisible, "none of it can be seen, walked into or shot")

local screen = R.new("ScreenGui")
local playerGui = World.service("Players").LocalPlayer:FindFirstChild("PlayerGui")
screen.Parent = playerGui
local way = Wayfinding.new(screen, playerGui)
local function areaName(offset)
	local a = way:AreaAt(CENTRE + offset)
	return a and a:GetAttribute("AreaName")
end
check(areaName(Vector3.new(0, 3, 0)) == "ZEE PLAZA", "the plaza is ZEE PLAZA")
check(areaName(Vector3.new(45, 3, -64)) == "ZEE GUNS", "inside ZEE GUNS is ZEE GUNS")
check(areaName(Vector3.new(-133, 3, -84)) == "THE ALLEY", "THE ALLEY")
check(areaName(Vector3.new(0, 3, -100)) == "DOWNTOWN", "the avenue between them is just DOWNTOWN")
check(areaName(Vector3.new(0, 3, -2000)) == nil, "and far off it, nowhere")

print("the compass")
local root = World.character:FindFirstChild("HumanoidRootPart")
root.CFrame = CFrame.new(CENTRE + Vector3.new(0, 3, -120))
local camera = World.workspace.CurrentCamera
World.force(camera, "CFrame", CFrame.lookAt(root.Position + Vector3.new(0, 6, -10), root.Position + Vector3.new(0, 4, 50)))
World.advance(0.2)
local strip = screen:FindFirstChild("Compass")
local layer = screen:FindFirstChild("CompassMarkers")
local function letterAt(text)
	for _, l in ipairs(strip:GetChildren()) do
		if l:IsA("TextLabel") and l.Text == text and l.Visible then
			return l.Position.X.Offset
		end
	end
	return nil
end
local n, e, w = letterAt("N"), letterAt("E"), letterAt("W")
check(n and math.abs(n) < 2, ("facing the tower, N is in the middle (%s)"):format(tostring(n)))
check(e == nil and w == nil, "E and W are off the strip (it shows 150 degrees)")
local towerView = layer:FindFirstChild("landmark:ZEE TOWER")
check(towerView and towerView.Visible and math.abs(towerView.Position.X.Offset) < 3, "ZEE TOWER's icon sits over N")
local gunsView = layer:FindFirstChild("landmark:ZEE GUNS")
check(gunsView and gunsView.Visible and gunsView.Position.X.Offset < 0,
	"ZEE GUNS, off to the west (+X), is left of centre")

way:SetQuest({ title = "Car Park Run", waypoint = CENTRE + Vector3.new(47, 1, -161), waypointName = "THE CAR PARK" })
World.advance(0.1)
local job = layer:FindFirstChild("job")
local jobText = job and job:FindFirstChild("Distance")
check(job and job.Visible and jobText and jobText.Text:match("%d+m$"), "the job goes up with its distance: "
	.. (jobText and jobText.Text or "none"))
local arrow = job and job:FindFirstChild("Arrow")
check(arrow and arrow.Visible and arrow.Text == "◀", "it is behind you and to the left, so it waits at the edge with an arrow")
local marker = playerGui:FindFirstChild("JobMarker")
check(marker and marker:IsA("BillboardGui") and marker.AlwaysOnTop and marker.Adornee
	and (marker.Adornee.Position - (CENTRE + Vector3.new(47, 6, -161))).Magnitude < 0.1, "and a marker floats over the spot")
way:SetQuest(nil)
World.advance(0.1)
check(layer:FindFirstChild("job") == nil and playerGui:FindFirstChild("JobMarker") == nil, "no job, no marker")

way:HandleTurf("start", { id = "Courts", zone = "THE COURTS", position = CENTRE + Vector3.new(54, 0, 80) })
way:HandleSupply("landed", { id = 7, position = CENTRE + Vector3.new(-20, 0, 30) })
World.advance(0.1)
check(layer:FindFirstChild("turf:Courts") and layer:FindFirstChild("supply:7"), "a turf war and a supply drop go up")
way:HandleTurf("won", { id = "Courts" })
way:HandleSupply("opened", { id = 7 })
World.advance(0.1)
check(layer:FindFirstChild("turf:Courts") == nil and layer:FindFirstChild("supply:7") == nil, "and come down when they are over")

print("the names of places")
local title = screen:FindFirstChild("AreaTitle")
local function shown()
	local label = nil
	for _, l in ipairs(title:GetChildren()) do
		if l:IsA("TextLabel") and l.TextSize >= 40 then
			label = l
		end
	end
	return title.Visible and label and label.Text or nil
end
World.advance(0.5)
check(shown() == "DOWNTOWN", "arriving in the district: DOWNTOWN (" .. tostring(shown()) .. ")")
World.advance(3.5)
root.CFrame = CFrame.new(CENTRE + Vector3.new(0, 3, 0))
World.advance(0.5)
check(shown() == "ZEE PLAZA", "walking into the plaza: ZEE PLAZA")
World.advance(3.5)
root.CFrame = CFrame.new(CENTRE + Vector3.new(0, 3, -100))
World.advance(0.5)
check(shown() == nil, "back out into the street: the district is not announced again")
root.CFrame = CFrame.new(CENTRE + Vector3.new(0, 3, 0))
World.advance(0.5)
check(shown() == nil, "and straight back into the plaza is not news either")

print("who has a new job")
local giver = R.new("Model")
giver.Name = "QuestGiver_Fixer"
local giverHead = R.new("Part")
giverHead.Name = "Head"
giverHead.CFrame = CFrame.new(CENTRE + Vector3.new(46, 5, 42))
giverHead.Parent = giver
giver.Parent = World.workspace
way:SetOffers({ Fixer = true })
World.advance(0.1)
local bang = playerGui:FindFirstChild("OfferMarker")
check(bang and bang:IsA("BillboardGui") and bang.Adornee == giverHead and bang.AlwaysOnTop,
	"the Fixer has a job for you: a \"!\" over their head")
local offerView = layer:FindFirstChild("offer:Fixer")
local fixerLandmark = layer:FindFirstChild("landmark:THE FIXER")
check(offerView ~= nil and (fixerLandmark == nil or not fixerLandmark.Visible),
	"and they go up on the compass, in place of their landmark")
way:SetOffers({})
World.advance(0.1)
check(playerGui:FindFirstChild("OfferMarker") == nil and layer:FindFirstChild("offer:Fixer") == nil,
	"taking the job takes the \"!\" down")
way:SetOffers({ Fixer = true })
World.advance(0.1)
way:SetVisible(false)
check(not playerGui:FindFirstChild("OfferMarker").Enabled, "and it hides with the rest of the compass in a menu")
way:SetVisible(true)
way:SetOffers(nil)
giver.Parent = nil

local bad = {}
for _, e in ipairs(R.errors or {}) do
	if tostring(e):match("Wayfinding") then
		table.insert(bad, tostring(e))
	end
end
check(#bad == 0, "no errors" .. (#bad > 0 and (": " .. bad[1]) or ""))

print("")
if failures == 0 then
	print("\27[32mall wayfinding checks passed\27[0m")
	require("@lune/process").exit(0)
else
	print(("\27[31m%d wayfinding check(s) failed\27[0m"):format(failures))
	require("@lune/process").exit(1)
end
