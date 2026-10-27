-- Rebuilds the map. Paste into the Studio command bar.
-- Workspace.Plot is the empty claimable platform; ServerStorage.PlotTemplate holds what appears once claimed.
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
for _, n in ipairs({"Plot", "Decor"}) do local o = workspace:FindFirstChild(n) if o then o:Destroy() end end
local oldT = ServerStorage:FindFirstChild("PlotTemplate") if oldT then oldT:Destroy() end

local STUDS = "rbxassetid://6372755229"
local function studs(p, tile)
	for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
		local t = Instance.new("Texture") t.Texture = STUDS t.Face = face t.StudsPerTileU = tile or 4 t.StudsPerTileV = tile or 4
		t.Color3 = Color3.new(0, 0, 0) t.Transparency = 0.75 t.Parent = p
	end
end
local function P(parent, name, size, cf, color, mat, extra)
	local p = Instance.new("Part")
	p.Name = name p.Size = size p.CFrame = cf p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(extra or {}) do p[k] = v end
	p.Parent = parent
	return p
end
local function stroke(t, th)
	local s = Instance.new("UIStroke") s.Thickness = th or 3 s.Color = Color3.fromRGB(20, 10, 40) s.Parent = t
end
local function label(part, face, text, color)
	local g = Instance.new("SurfaceGui") g.Face = face g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud g.PixelsPerStud = 40 g.Parent = part
	local t = Instance.new("TextLabel") t.Name = "Text" t.Size = UDim2.fromScale(1,1) t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne t.TextScaled = true t.Text = text t.TextColor3 = color or Color3.new(1,1,1) t.Parent = g
	stroke(t, 4)
	return t
end
local function pumpkin(parent, pos, size)
	P(parent, "Pumpkin", Vector3.new(size, size * 0.8, size), CFrame.new(pos + Vector3.new(0, size * 0.4, 0)), Color3.fromRGB(255, 130, 20), Enum.Material.SmoothPlastic, {Shape = Enum.PartType.Ball})
	P(parent, "Stem", Vector3.new(size * 0.15, size * 0.3, size * 0.15), CFrame.new(pos + Vector3.new(0, size * 0.9, 0)), Color3.fromRGB(60, 150, 40))
end

-- night that stays bright and readable for kids
Lighting.ClockTime = 0
Lighting.Brightness = 2
Lighting.Ambient = Color3.fromRGB(110, 90, 160)
Lighting.OutdoorAmbient = Color3.fromRGB(130, 110, 180)
Lighting.ExposureCompensation = 0.3
local atm = Lighting:FindFirstChildOfClass("Atmosphere")
if atm then atm.Density = 0.25 atm.Color = Color3.fromRGB(150, 120, 220) atm.Decay = Color3.fromRGB(80, 60, 140) end

-- green stud grass like the reference
workspace.Baseplate.Color = Color3.fromRGB(60, 170, 60)
local bt = workspace.Baseplate:FindFirstChildWhichIsA("Texture") bt.Color3 = Color3.new(0, 0, 0) bt.Transparency = 0.8

-- hidden spawn at the front of the plot
local sp = workspace.SpawnLocation
sp.CFrame = CFrame.new(0, 2.6, -60) sp.Size = Vector3.new(6, 1, 6)
sp.Transparency = 1 sp.CanCollide = false
for _, d in ipairs(sp:GetChildren()) do if d:IsA("Decal") then d:Destroy() end end

---------------------------------------------------------------- empty platform
local plot = Instance.new("Model") plot.Name = "Plot"
local floor = P(plot, "Floor", Vector3.new(96, 2, 116), CFrame.new(0, 1, -4), Color3.fromRGB(70, 110, 230)) studs(floor, 4)
for _, s in ipairs({-1, 1}) do
	studs(P(plot, "Border", Vector3.new(2, 3, 116), CFrame.new(s * 49, 1.5, -4), Color3.fromRGB(50, 80, 190)), 4)
end
studs(P(plot, "BorderBack", Vector3.new(100, 3, 2), CFrame.new(0, 1.5, 55), Color3.fromRGB(50, 80, 190)), 4)
studs(P(plot, "Carpet", Vector3.new(12, 0.2, 116), CFrame.new(0, 2.1, -4), Color3.fromRGB(255, 50, 130)), 4)
local claim = P(plot, "ClaimPad", Vector3.new(10, 0.4, 6), CFrame.new(0, 2.3, -58), Color3.fromRGB(80, 255, 120), Enum.Material.Neon)
local pp = Instance.new("ProximityPrompt") pp.Name = "ClaimPrompt" pp.ActionText = "Claim Plot" pp.ObjectText = "Empty Plot" pp.HoldDuration = 0.5 pp.MaxActivationDistance = 12 pp.RequiresLineOfSight = false pp.Parent = claim
local cbb = Instance.new("BillboardGui") cbb.Name = "Sign" cbb.Size = UDim2.fromScale(16, 3.5) cbb.StudsOffset = Vector3.new(0, 6, 0) cbb.Parent = claim
local ct = Instance.new("TextLabel") ct.Name = "Text" ct.Size = UDim2.fromScale(1,1) ct.BackgroundTransparency = 1 ct.Font = Enum.Font.FredokaOne ct.TextScaled = true
ct.TextColor3 = Color3.fromRGB(120, 255, 140) ct.Text = "Claim this plot!" ct.Parent = cbb stroke(ct, 4)
local contents = Instance.new("Folder") contents.Name = "Contents" contents.Parent = plot
plot.Parent = workspace

-- spooky-cute decor around the plot (always visible)
local decor = Instance.new("Folder") decor.Name = "Decor"
local rng = Random.new(7)
for i = 1, 22 do
	local s = i % 2 == 0 and 1 or -1
	pumpkin(decor, Vector3.new(s * rng:NextNumber(54, 80), 0, rng:NextNumber(-80, 70)), rng:NextNumber(2.5, 5))
end
for i = 1, 10 do
	local s = i % 2 == 0 and 1 or -1
	local pos = Vector3.new(s * rng:NextNumber(56, 85), 0, rng:NextNumber(-70, 70))
	studs(P(decor, "Grave", Vector3.new(4, 5, 1), CFrame.new(pos + Vector3.new(0, 2.5, 0)) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), Color3.fromRGB(130, 130, 150)), 2)
end
for i = 1, 6 do
	local s = i % 2 == 0 and 1 or -1
	local g = P(decor, "Ghost", Vector3.new(3, 4, 3), CFrame.new(s * rng:NextNumber(58, 75), rng:NextNumber(8, 14), rng:NextNumber(-60, 60)), Color3.fromRGB(220, 255, 255), Enum.Material.Neon, {Shape = Enum.PartType.Ball, Transparency = 0.2, CanCollide = false})
	local l = Instance.new("PointLight") l.Color = Color3.fromRGB(160, 255, 255) l.Range = 14 l.Brightness = 1 l.Parent = g
end
-- blocky spooky trees ringing the plot
for i = 1, 16 do
	local s = i % 2 == 0 and 1 or -1
	local pos = Vector3.new(s * rng:NextNumber(88, 110), 0, rng:NextNumber(-90, 90))
	studs(P(decor, "Trunk", Vector3.new(3, 10, 3), CFrame.new(pos + Vector3.new(0, 5, 0)), Color3.fromRGB(90, 60, 40)), 2)
	studs(P(decor, "Leaves", Vector3.new(12, 10, 12), CFrame.new(pos + Vector3.new(0, 14, 0)), Color3.fromRGB(40, 130, 50)), 4)
end
decor.Parent = workspace

---------------------------------------------------------------- claimed contents (template)
local template = Instance.new("Folder") template.Name = "PlotTemplate"
local bedrooms = Instance.new("Folder") bedrooms.Name = "Bedrooms" bedrooms.Parent = template
local WALLPAPERS = {Color3.fromRGB(255, 200, 230), Color3.fromRGB(190, 230, 255), Color3.fromRGB(210, 255, 200), Color3.fromRGB(255, 240, 180), Color3.fromRGB(225, 205, 255), Color3.fromRGB(255, 215, 190)}
local RUGS = {Color3.fromRGB(255, 120, 170), Color3.fromRGB(90, 170, 255), Color3.fromRGB(120, 220, 110), Color3.fromRGB(255, 190, 60), Color3.fromRGB(170, 110, 255), Color3.fromRGB(255, 140, 90)}
local zs = {-32, 0, 32}
local H = 16      -- wall height
local FRONT = 17  -- |x| of the front wall
local BACK = 45   -- |x| of the back wall
local HALF = 14   -- half width along z
local idx = 0
for row = 1, 3 do
	for _, s in ipairs({-1, 1}) do
		idx += 1
		local b = Instance.new("Model") b.Name = "Bedroom" .. idx b:SetAttribute("Index", idx)
		local z = zs[row]
		local L = -s -- +z is to the left for rooms on the -x side when you face them from the aisle
		local cx = s * (FRONT + BACK) / 2
		local depth = BACK - FRONT
		local y0 = 2
		local face = s == -1 and Enum.NormalId.Right or Enum.NormalId.Left
		local faceAisle = CFrame.Angles(0, s == -1 and -math.pi/2 or math.pi/2, 0)
		local wall = WALLPAPERS[idx]
		local trim = Color3.fromRGB(110, 70, 50)
		studs(P(b, "RoomFloor", Vector3.new(depth, 0.2, HALF * 2), CFrame.new(cx, y0 + 0.1, z), Color3.fromRGB(170, 120, 80)), 4)
		studs(P(b, "Rug", Vector3.new(12, 0.2, 12), CFrame.new(cx, y0 + 0.25, z), RUGS[idx]), 2)
		P(b, "BackWall", Vector3.new(1, H, HALF * 2), CFrame.new(s * BACK, y0 + H/2, z), wall)
		P(b, "SideWallA", Vector3.new(depth, H, 1), CFrame.new(cx, y0 + H/2, z - HALF), wall)
		P(b, "SideWallB", Vector3.new(depth, H, 1), CFrame.new(cx, y0 + H/2, z + HALF), wall)
		studs(P(b, "Roof", Vector3.new(depth + 2, 1.5, HALF * 2 + 2), CFrame.new(cx, y0 + H + 0.75, z), Color3.fromRGB(150, 60, 170)), 4)
		-- front wall: showcase on the left half, window on the right half
		local wz = z - L * 5     -- window center (right half)
		local fx = s * FRONT
		P(b, "FrontLow", Vector3.new(1, 4, HALF * 2), CFrame.new(fx, y0 + 2, z), wall)
		P(b, "FrontHigh", Vector3.new(1, 3, HALF * 2), CFrame.new(fx, y0 + H - 1.5, z), wall)
		P(b, "FrontLeft", Vector3.new(1, H - 7, HALF + 5 - 7), CFrame.new(fx, y0 + 4 + (H - 7)/2, z + L * (HALF - (HALF + 5 - 7)/2)), wall)
		P(b, "FrontRight", Vector3.new(1, H - 7, 2), CFrame.new(fx, y0 + 4 + (H - 7)/2, z - L * (HALF - 1)), wall)
		P(b, "Window", Vector3.new(0.3, H - 7, 14), CFrame.new(fx, y0 + 4 + (H - 7)/2, wz), Color3.fromRGB(200, 235, 255), Enum.Material.Glass, {Transparency = 0.75})
		P(b, "WindowSill", Vector3.new(1.6, 0.6, 15), CFrame.new(fx + s * -0.3, y0 + 4, wz), trim)
		local hole = P(b, "CrawlHole", Vector3.new(1.2, 3, 3.5), CFrame.new(fx, y0 + 1.5, z - L * (HALF - 3)), Color3.fromRGB(30, 20, 40), Enum.Material.SmoothPlastic, {CanCollide = false})
		local sp2 = Instance.new("ProximityPrompt") sp2.Name = "ScarePrompt" sp2.ActionText = "Scare!" sp2.ObjectText = "Crawl in" sp2.HoldDuration = 0.5 sp2.MaxActivationDistance = 8 sp2.Parent = hole
		-- bed, nightstand, lamp, toy box (bed sits in view of the window)
		local bx = s * (FRONT + 15)
		studs(P(b, "BedFrame", Vector3.new(8, 2.5, 11), CFrame.new(bx, y0 + 1.25, wz), Color3.fromRGB(140, 90, 60)), 2)
		P(b, "Headboard", Vector3.new(8, 5, 1), CFrame.new(bx, y0 + 2.5, wz + L * 5.5), Color3.fromRGB(140, 90, 60))
		P(b, "Mattress", Vector3.new(7.6, 1, 10), CFrame.new(bx, y0 + 3, wz), Color3.new(1, 1, 1), Enum.Material.Fabric)
		P(b, "Blanket", Vector3.new(7.8, 0.4, 6.5), CFrame.new(bx, y0 + 3.6, wz - L * 1.5), RUGS[(idx % 6) + 1], Enum.Material.Fabric)
		P(b, "Pillow", Vector3.new(5, 1, 2.4), CFrame.new(bx, y0 + 3.9, wz + L * 3.6), Color3.new(1, 1, 1), Enum.Material.Fabric)
		P(b, "GuestSpot", Vector3.new(1, 1, 1), CFrame.new(bx, y0 + 6, wz + L * 1.5) * faceAisle, Color3.new(1,1,1), nil, {Transparency = 1, CanCollide = false})
		local nsz = wz + L * 8
		studs(P(b, "Nightstand", Vector3.new(3, 3, 3), CFrame.new(bx + s * 2, y0 + 1.5, nsz), Color3.fromRGB(160, 110, 70)), 2)
		-- dim nightlight: the kids are asleep
		local lamp = P(b, "Lamp", Vector3.new(1, 1, 1), CFrame.new(bx + s * 2, y0 + 3.6, nsz), Color3.fromRGB(200, 130, 70), Enum.Material.Neon, {Shape = Enum.PartType.Ball})
		local ll = Instance.new("PointLight") ll.Color = Color3.fromRGB(255, 160, 80) ll.Range = 10 ll.Brightness = 0.5 ll.Parent = lamp
		studs(P(b, "ToyBox", Vector3.new(4, 3, 3), CFrame.new(s * (BACK - 4), y0 + 1.5, z + L * (HALF - 3)), Color3.fromRGB(255, 90, 90)), 2)
		P(b, "Ball", Vector3.new(2, 2, 2), CFrame.new(s * (FRONT + 6), y0 + 1.2, z + L * 4), Color3.fromRGB(80, 200, 255), Enum.Material.SmoothPlastic, {Shape = Enum.PartType.Ball})
		-- tier sign above the window
		local sign = P(b, "TierSign", Vector3.new(0.6, 2.6, 12), CFrame.new(fx + s * -0.8, y0 + H + 2.8, z), Color3.fromRGB(40, 30, 70))
		label(sign, face, "Normal x1")
		-- glass display case in front of the left half
		local scz = z + L * 7
		local scx = s * (FRONT - 5)
		studs(P(b, "ShowcaseBase", Vector3.new(8, 2, 8), CFrame.new(scx, y0 + 1, scz), Color3.fromRGB(40, 60, 160)), 2)
		P(b, "ShowcaseTrim", Vector3.new(8.4, 0.6, 8.4), CFrame.new(scx, y0 + 2.3, scz), Color3.fromRGB(255, 220, 80), Enum.Material.SmoothPlastic)
		P(b, "ShowcaseGlass", Vector3.new(7.4, 8, 7.4), CFrame.new(scx, y0 + 6.6, scz), Color3.fromRGB(200, 240, 255), Enum.Material.Glass, {Transparency = 0.6})
		local place = Instance.new("ProximityPrompt") place.Name = "PlacePrompt" place.ActionText = "Place Monster" place.ObjectText = "Display Case" place.HoldDuration = 0.3 place.MaxActivationDistance = 10 place.RequiresLineOfSight = false place.Parent = b.ShowcaseGlass
		for _, c in ipairs({{-1, -1}, {-1, 1}, {1, -1}, {1, 1}}) do
			P(b, "ShowcasePost", Vector3.new(0.6, 8, 0.6), CFrame.new(scx + c[1] * 3.9, y0 + 6.6, scz + c[2] * 3.9), Color3.fromRGB(255, 220, 80))
		end
		P(b, "ShowcaseLid", Vector3.new(8.4, 0.6, 8.4), CFrame.new(scx, y0 + 10.9, scz), Color3.fromRGB(255, 220, 80))
		P(b, "MonsterSpot", Vector3.new(1, 1, 1), CFrame.new(scx, y0 + 2.6, scz) * faceAisle, Color3.new(1,1,1), nil, {Transparency = 1, CanCollide = false})
		-- name + cash readout above the case
		local info = Instance.new("BillboardGui") info.Name = "Info" info.Size = UDim2.fromScale(9, 3.6) info.StudsOffset = Vector3.new(0, 7.5, 0) info.MaxDistance = 120 info.Parent = b.ShowcaseLid
		local nm = Instance.new("TextLabel") nm.Name = "MonsterName" nm.Size = UDim2.fromScale(1, 0.5) nm.BackgroundTransparency = 1 nm.Font = Enum.Font.FredokaOne nm.TextScaled = true
		nm.TextColor3 = Color3.new(1, 1, 1) nm.Text = "Empty" nm.Parent = info stroke(nm, 3)
		local cash = Instance.new("TextLabel") cash.Name = "Cash" cash.Size = UDim2.fromScale(1, 0.5) cash.Position = UDim2.fromScale(0, 0.5) cash.BackgroundTransparency = 1 cash.Font = Enum.Font.FredokaOne cash.TextScaled = true
		cash.TextColor3 = Color3.fromRGB(90, 255, 90) cash.Text = "Hatch an egg!" cash.Parent = info stroke(cash, 3)
		-- lock cover for locked bedrooms (hides the front and the case)
		local lock = P(b, "Lock", Vector3.new(FRONT - 6.5 + 1.2, H + 4, HALF * 2 + 0.4), CFrame.new(s * (6.5 + (FRONT + 0.6 - 6.5) / 2), y0 + (H + 4) / 2, z), Color3.fromRGB(70, 60, 90), Enum.Material.SmoothPlastic, {Transparency = 0.1})
		label(lock, face, "🔒 Rebirth to unlock")
		b.Parent = bedrooms
	end
end

-- egg pedestal at the front of the aisle (shortcut: moves to a dedicated egg area later)
studs(P(template, "EggPedestal", Vector3.new(7, 2, 7), CFrame.new(0, 3, -48), Color3.fromRGB(255, 220, 80)), 2)
local egg = P(template, "Egg", Vector3.new(4.5, 5.5, 4.5), CFrame.new(0, 6.8, -48), Color3.fromRGB(180, 130, 255), Enum.Material.SmoothPlastic, {Shape = Enum.PartType.Ball})
local hp = Instance.new("ProximityPrompt") hp.Name = "HatchPrompt" hp.ActionText = "Hatch" hp.ObjectText = "Spooky Egg" hp.HoldDuration = 0.5 hp.MaxActivationDistance = 10 hp.Parent = egg
local bb = Instance.new("BillboardGui") bb.Size = UDim2.fromScale(10, 2.2) bb.StudsOffset = Vector3.new(0, 5, 0) bb.Parent = egg
local t = Instance.new("TextLabel") t.Name = "Text" t.Size = UDim2.fromScale(1,1) t.BackgroundTransparency = 1 t.Font = Enum.Font.FredokaOne t.TextScaled = true t.TextColor3 = Color3.fromRGB(255, 220, 80) t.Text = "Spooky Egg - 250 Fear" t.Parent = bb stroke(t, 4)
template.Parent = ServerStorage
