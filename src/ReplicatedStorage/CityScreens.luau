--!strict
-- The giant screens on HANAMI CITY's buildings: what they show, and how a picture is painted.
--
-- The server builds each screen with its first picture (HanamiService.CityKit.Screen) and tags
-- the panel "AdScreen"; the client (StarterPlayerScripts.CityScreens) turns the pictures over
-- every few seconds with a wipe, the way the real ones do. The picture is a SurfaceGui the
-- light does not touch, so it shines by day as well as by night.

local CityScreens = {}

export type Ad = { head: string, sub: string, bg: Color3, bg2: Color3, fg: Color3, accent: Color3 }

CityScreens.TAG = "AdScreen"
CityScreens.HOLD = 9          -- seconds a picture stays up (each screen a little different)

CityScreens.ADS = {
	{ head = "SAKURA FESTIVAL", sub = "桜まつり  ·  HANAMI PARK  ·  EVERY NIGHT", bg = Color3.fromRGB(236, 86, 150),
	  bg2 = Color3.fromRGB(252, 176, 206), fg = Color3.fromRGB(255, 255, 255), accent = Color3.fromRGB(255, 236, 120) },
	{ head = "KUROGANE", sub = "鋼  ·  STRENGTH IN IRON", bg = Color3.fromRGB(30, 32, 40), bg2 = Color3.fromRGB(130, 28, 40),
	  fg = Color3.fromRGB(240, 196, 84), accent = Color3.fromRGB(220, 50, 50) },
	{ head = "ZEE COLA", sub = "ICE COLD  ·  冷たい  ·  ¥150", bg = Color3.fromRGB(206, 30, 40), bg2 = Color3.fromRGB(252, 120, 60),
	  fg = Color3.fromRGB(255, 255, 255), accent = Color3.fromRGB(255, 255, 255) },
	{ head = "NEO HANAMI 2099", sub = "NOW SHOWING  ·  上映中", bg = Color3.fromRGB(34, 26, 100), bg2 = Color3.fromRGB(30, 170, 230),
	  fg = Color3.fromRGB(255, 255, 255), accent = Color3.fromRGB(90, 250, 230) },
	{ head = "HANAMI AIR", sub = "FLY THE CHERRY ROUTE  ·  花見航空", bg = Color3.fromRGB(26, 100, 200), bg2 = Color3.fromRGB(130, 206, 252),
	  fg = Color3.fromRGB(255, 255, 255), accent = Color3.fromRGB(255, 196, 214) },
	{ head = "RAMEN ICHIBAN", sub = "ラーメン一番  ·  ¥780  ·  OPEN LATE", bg = Color3.fromRGB(252, 200, 40), bg2 = Color3.fromRGB(250, 134, 36),
	  fg = Color3.fromRGB(40, 26, 24), accent = Color3.fromRGB(200, 30, 30) },
	{ head = "MEGA DRIFT", sub = "ゲーム  ·  OUT NOW", bg = Color3.fromRGB(110, 36, 190), bg2 = Color3.fromRGB(236, 60, 160),
	  fg = Color3.fromRGB(255, 255, 255), accent = Color3.fromRGB(120, 250, 250) },
	{ head = "SORA LIVE", sub = "TONIGHT AT THE SCRAMBLE  ·  ライブ", bg = Color3.fromRGB(14, 150, 140), bg2 = Color3.fromRGB(60, 226, 180),
	  fg = Color3.fromRGB(255, 255, 255), accent = Color3.fromRGB(255, 240, 140) },
} :: { Ad }

--- The picture for a number (any number: it wraps round the list).
function CityScreens.Get(n: number): Ad
	return CityScreens.ADS[(math.floor(n) - 1) % #CityScreens.ADS + 1]
end

local function label(parent: Instance, name: string, text: string, pos: UDim2, size: UDim2, colour: Color3, font: Enum.Font,
	align: Enum.TextXAlignment): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.BackgroundTransparency = 1
	l.Position = pos
	l.Size = size
	l.Text = text
	l.TextScaled = true
	l.Font = font
	l.TextColor3 = colour
	l.TextXAlignment = align
	l.Parent = parent
	return l
end

--- Paint picture `n` on a screen panel (its front face), building the picture the first time.
function CityScreens.Paint(panel: BasePart, n: number)
	local ad = CityScreens.Get(n)
	panel:SetAttribute("Ad", n)
	local gui = panel:FindFirstChild("Picture") :: SurfaceGui?
	if not gui then
		local g = Instance.new("SurfaceGui")
		g.Name = "Picture"
		g.Face = Enum.NormalId.Front
		g.LightInfluence = 0
		g.Brightness = 1.5
		g.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
		local aspect = panel.Size.X / math.max(0.1, panel.Size.Y)
		g.CanvasSize = Vector2.new(math.floor(360 * aspect + 0.5), 360)
		g.ClipsDescendants = true
		g.Parent = panel
		-- The headline first: it is the lettering the map viewer shows for the screen.
		local head = label(g, "Head", "", UDim2.fromScale(0.06, 0.16), UDim2.fromScale(0.88, 0.46), Color3.new(1, 1, 1),
			Enum.Font.GothamBlack, Enum.TextXAlignment.Left)
		head.ZIndex = 3
		local sub = label(g, "Sub", "", UDim2.fromScale(0.06, 0.66), UDim2.fromScale(0.7, 0.14), Color3.new(1, 1, 1),
			Enum.Font.GothamBold, Enum.TextXAlignment.Left)
		sub.ZIndex = 3
		local bg = Instance.new("Frame")
		bg.Name = "Back"
		bg.Size = UDim2.fromScale(1, 1)
		bg.BorderSizePixel = 0
		bg.ZIndex = 1
		bg.Parent = g
		local grad = Instance.new("UIGradient")
		grad.Rotation = 24
		grad.Parent = bg
		-- A light sweep across the picture, a bar of the accent colour, a corner tag.
		local sweep = Instance.new("Frame")
		sweep.Name = "Sweep"
		sweep.AnchorPoint = Vector2.new(0.5, 0.5)
		sweep.Position = UDim2.fromScale(0.72, 0.5)
		sweep.Size = UDim2.fromScale(0.5, 2.2)
		sweep.Rotation = 24
		sweep.BackgroundColor3 = Color3.new(1, 1, 1)
		sweep.BackgroundTransparency = 0.86
		sweep.BorderSizePixel = 0
		sweep.ZIndex = 2
		sweep.Parent = g
		local bar = Instance.new("Frame")
		bar.Name = "Bar"
		bar.Position = UDim2.fromScale(0.06, 0.6)
		bar.Size = UDim2.fromScale(0.24, 0.025)
		bar.BorderSizePixel = 0
		bar.ZIndex = 3
		bar.Parent = g
		local tag = Instance.new("Frame")
		tag.Name = "Tag"
		tag.AnchorPoint = Vector2.new(1, 1)
		tag.Position = UDim2.fromScale(0.97, 0.94)
		tag.Size = UDim2.fromScale(0.16, 0.12)
		tag.BorderSizePixel = 0
		tag.ZIndex = 3
		tag.Parent = g
		label(tag, "TagText", "LIVE", UDim2.fromScale(0.1, 0.12), UDim2.fromScale(0.8, 0.76), Color3.new(1, 1, 1), Enum.Font.GothamBlack,
			Enum.TextXAlignment.Center)
		-- The wipe the client runs between pictures.
		local wipe = Instance.new("Frame")
		wipe.Name = "Wipe"
		wipe.Size = UDim2.fromScale(0, 1)
		wipe.BorderSizePixel = 0
		wipe.BackgroundColor3 = Color3.new(1, 1, 1)
		wipe.ZIndex = 5
		wipe.Parent = g
		gui = g
	end
	local g = gui :: SurfaceGui
	panel.Color = ad.bg
	local head = g:FindFirstChild("Head") :: TextLabel
	local sub = g:FindFirstChild("Sub") :: TextLabel
	local back = g:FindFirstChild("Back") :: Frame
	local bar = g:FindFirstChild("Bar") :: Frame
	local tag = g:FindFirstChild("Tag") :: Frame
	head.Text = ad.head
	head.TextColor3 = ad.fg
	sub.Text = ad.sub
	sub.TextColor3 = ad.fg
	back.BackgroundColor3 = Color3.new(1, 1, 1)
	local grad = back:FindFirstChildOfClass("UIGradient")
	if grad then
		grad.Color = ColorSequence.new(ad.bg, ad.bg2)
	end
	bar.BackgroundColor3 = ad.accent
	tag.BackgroundColor3 = ad.accent
	local tagText = tag:FindFirstChild("TagText") :: TextLabel?
	if tagText then
		tagText.TextColor3 = ad.bg
	end
end

return CityScreens
