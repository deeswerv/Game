--!strict
-- The cities' people: Downtown's and Hanami's crowds walking their stretches of pavement
-- (DistrictService and HanamiService spawn them; Pedestrians.client walks them). Its own
-- module so a city can have a crowd without requiring the other's whole service.

local ServerScriptService = game:GetService("ServerScriptService")

local Crowd = {}

-- What the cities' people wear (NPCService.Outfit): street clothes, nothing a crew wears, each
-- drawing its own colours so no two are the same.
Crowd.CIVILIANS = {
	{   -- a student: hoodie, bag, sneakers
		Palette = { Skin = "tones", Shirt = { Color3.fromRGB(120, 170, 220), Color3.fromRGB(240, 196, 90),
			Color3.fromRGB(150, 210, 160) }, Pants = { Color3.fromRGB(64, 84, 120), Color3.fromRGB(52, 52, 60) } },
		Outfit = { { "Hair", style = "short" }, { "Hoodie" }, { "StrapBag", colour = Color3.fromRGB(40, 40, 46) },
			{ "Sneakers", colour = Color3.fromRGB(240, 238, 232) } } :: { any },
	},
	{   -- office: a suit, slick hair, loafers, a watch
		Palette = { Skin = "tones", Shirt = { Color3.fromRGB(52, 60, 82), Color3.fromRGB(96, 98, 104) },
			Pants = { Color3.fromRGB(44, 48, 62) } },
		Outfit = { { "Hair", style = "slick" }, { "Suit" }, { "Watch" }, { "Loafers" } } :: { any },
	},
	{   -- weekend: a tee, a cap, a watch
		Palette = { Skin = "tones", Shirt = { Color3.fromRGB(236, 120, 120), Color3.fromRGB(246, 244, 236),
			Color3.fromRGB(120, 200, 190) }, Pants = { Color3.fromRGB(70, 92, 130), Color3.fromRGB(196, 176, 140) } },
		Outfit = { { "Hair", style = "top" }, { "Tee" }, { "Cap", colour = Color3.fromRGB(46, 70, 120) }, { "Watch" },
			{ "Sneakers", colour = Color3.fromRGB(60, 60, 66) } } :: { any },
	},
	{   -- a jogger: a tracksuit, not red
		Palette = { Skin = "tones", Shirt = { Color3.fromRGB(60, 110, 200), Color3.fromRGB(110, 110, 118) },
			Pants = { Color3.fromRGB(40, 44, 52) } },
		Outfit = { { "Hair", style = "crop" }, { "Tracksuit", stripe = Color3.fromRGB(240, 240, 236) },
			{ "Sneakers", colour = Color3.fromRGB(240, 240, 236) } } :: { any },
	},
	{   -- an old gent: grey hair, a jacket, a fedora
		Palette = { Skin = "tones", Shirt = { Color3.fromRGB(200, 184, 150), Color3.fromRGB(130, 110, 90) },
			Pants = { Color3.fromRGB(90, 84, 76) } },
		Outfit = { { "Hair", style = "grey" }, { "Jacket", colour = Color3.fromRGB(150, 120, 90), inner = Color3.fromRGB(236, 230, 214) },
			{ "Fedora", colour = Color3.fromRGB(70, 60, 52) }, { "Loafers" } } :: { any },
	},
	{   -- a tourist: a tee, shades, a cap
		Palette = { Skin = "tones", Shirt = { Color3.fromRGB(250, 210, 80), Color3.fromRGB(200, 120, 220),
			Color3.fromRGB(90, 200, 230) }, Pants = { Color3.fromRGB(210, 196, 160), Color3.fromRGB(60, 80, 110) } },
		Outfit = { { "Hair", style = "short" }, { "Tee" }, { "Shades" }, { "Cap", colour = Color3.fromRGB(240, 238, 230) },
			{ "Sneakers", colour = Color3.fromRGB(230, 90, 80) } } :: { any },
	},
}

--- A city's people: a dressed figure for each of `walkers` ({ from, to, look, speed } about
--- `centre`; Downtown.Walkers, HanamiConfig.Walkers), standing at the start of
--- its stretch of sidewalk, tagged "Pedestrian" with the stretch on it (WalkFrom / WalkTo in
--- the world, WalkSpeed, WalkPhase) -- Pedestrians.client walks them, the same on every client
--- because it times them off the server clock. Not part of any fight: nothing can hit, touch
--- or stand on them, and they are not Staff (nobody poses them but their walk).
function Crowd.Spawn(folder: Instance, centre: Vector3, walkers: { { any } }, seed: number)
	if folder:FindFirstChild("Pedestrians") then
		return
	end
	local outfitModule = ServerScriptService:FindFirstChild("NPCService")
	outfitModule = outfitModule and outfitModule:FindFirstChild("Outfit")
	if not (outfitModule and outfitModule:IsA("ModuleScript")) then
		return
	end
	local ok, Outfit = pcall(require, outfitModule)
	if not ok or type(Outfit) ~= "table" then
		return
	end
	local holder = Instance.new("Folder")
	holder.Name = "Pedestrians"
	for i, walk in ipairs(walkers) do
		local look = Crowd.CIVILIANS[walk[3]] or Crowd.CIVILIANS[1]
		local figure = Outfit.Standing(look, seed + i * 7)
		if figure then
			figure.Name = "Pedestrian"
			figure:RemoveTag("Staff")
			for _, p in ipairs(figure:GetDescendants()) do
				if p:IsA("BasePart") then
					p.CanCollide = false
					p.CanQuery = false
					p.CanTouch = false
				end
			end
			local from = centre + walk[1]
			local to = centre + walk[2]
			local root = figure:FindFirstChild("HumanoidRootPart") :: BasePart?
			local humanoid = figure:FindFirstChildOfClass("Humanoid")
			local lift = (if humanoid then humanoid.HipHeight else 2) + (if root then root.Size.Y / 2 else 1)
			figure:PivotTo(CFrame.lookAt(from + Vector3.new(0, lift, 0), to + Vector3.new(0, lift, 0)))
			figure:SetAttribute("WalkFrom", from + Vector3.new(0, lift, 0))
			figure:SetAttribute("WalkTo", to + Vector3.new(0, lift, 0))
			figure:SetAttribute("WalkSpeed", walk[4])
			figure:SetAttribute("WalkPhase", (i * 0.37) % 1)
			figure:AddTag("Pedestrian")
			figure.Parent = holder
		end
	end
	holder.Parent = folder
end

return Crowd
