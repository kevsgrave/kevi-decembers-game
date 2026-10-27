-- Rebuilds Workspace.Plot (aisle, 6 bedrooms, showcases, egg). Paste into the Studio command bar.
local old = workspace:FindFirstChild("Plot") if old then old:Destroy() end
local plot = Instance.new("Model") plot.Name = "Plot"
local function P(parent, name, size, cf, color, mat, extra)
	local p = Instance.new("Part")
	p.Name = name p.Size = size p.CFrame = cf p.Color = color
	p.Material = mat or Enum.Material.SmoothPlastic p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth p.BottomSurface = Enum.SurfaceType.Smooth
	for k, v in pairs(extra or {}) do p[k] = v end
	p.Parent = parent
	return p
end
local function label(part, face, text, color)
	local g = Instance.new("SurfaceGui") g.Face = face g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud g.PixelsPerStud = 40 g.Parent = part
	local t = Instance.new("TextLabel") t.Name = "Text" t.Size = UDim2.fromScale(1,1) t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne t.TextScaled = true t.Text = text t.TextColor3 = color or Color3.new(1,1,1) t.Parent = g
	return t
end

-- floor and carpet aisle
P(plot, "Floor", Vector3.new(64, 1, 96), CFrame.new(0, 0.5, 0), Color3.fromRGB(70, 60, 110), Enum.Material.WoodPlanks)
P(plot, "Carpet", Vector3.new(10, 0.2, 96), CFrame.new(0, 1.1, 0), Color3.fromRGB(150, 40, 70), Enum.Material.Fabric)

local W = Color3.fromRGB(235, 215, 190)
local bedrooms = Instance.new("Folder") bedrooms.Name = "Bedrooms" bedrooms.Parent = plot
local zs = {-28, 0, 28}
local idx = 0
for row = 1, 3 do
	for _, s in ipairs({-1, 1}) do
		idx += 1
		local b = Instance.new("Model") b.Name = "Bedroom" .. idx b:SetAttribute("Index", idx)
		local z = zs[row]
		local cx = s * 23 -- room center, room spans |x| 15..31
		local fx = s * 15 -- front wall (faces aisle)
		local y0 = 1
		local face = s == -1 and Enum.NormalId.Right or Enum.NormalId.Left
		P(b, "RoomFloor", Vector3.new(16, 0.2, 20), CFrame.new(cx, y0 + 0.1, z), Color3.fromRGB(120, 170, 220), Enum.Material.Fabric)
		P(b, "BackWall", Vector3.new(1, 12, 20), CFrame.new(s * 31, y0 + 6, z), W)
		P(b, "SideWallA", Vector3.new(16, 12, 1), CFrame.new(cx, y0 + 6, z - 10), W)
		P(b, "SideWallB", Vector3.new(16, 12, 1), CFrame.new(cx, y0 + 6, z + 10), W)
		P(b, "Roof", Vector3.new(17, 1, 21), CFrame.new(cx, y0 + 12.5, z), Color3.fromRGB(90, 60, 50))
		-- front wall with window (window 10 wide, y 4..10) and crawl hole
		P(b, "FrontLow", Vector3.new(1, 3, 20), CFrame.new(fx, y0 + 1.5, z), W)
		P(b, "FrontHigh", Vector3.new(1, 2, 20), CFrame.new(fx, y0 + 11, z), W)
		P(b, "FrontSideA", Vector3.new(1, 7, 5), CFrame.new(fx, y0 + 6.5, z - 7.5), W)
		P(b, "FrontSideB", Vector3.new(1, 7, 5), CFrame.new(fx, y0 + 6.5, z + 7.5), W)
		P(b, "Window", Vector3.new(0.3, 7, 10), CFrame.new(fx, y0 + 6.5, z), Color3.fromRGB(200, 230, 255), Enum.Material.Glass, {Transparency = 0.7, CanCollide = true})
		local hole = P(b, "CrawlHole", Vector3.new(1.2, 2.4, 3), CFrame.new(fx, y0 + 1.2, z - 7.5), Color3.fromRGB(25, 20, 30), Enum.Material.SmoothPlastic, {CanCollide = false})
		local pp = Instance.new("ProximityPrompt") pp.Name = "ScarePrompt" pp.ActionText = "Scare!" pp.ObjectText = "Crawl in" pp.HoldDuration = 0.5 pp.MaxActivationDistance = 8 pp.Parent = hole
		-- bed + guest spot
		P(b, "Bed", Vector3.new(6, 2, 9), CFrame.new(s * 26, y0 + 1, z), Color3.fromRGB(240, 240, 250), Enum.Material.Fabric)
		P(b, "Blanket", Vector3.new(6.2, 0.4, 6), CFrame.new(s * 26, y0 + 2.2, z + 1.5), Color3.fromRGB(255, 170, 200), Enum.Material.Fabric)
		P(b, "Pillow", Vector3.new(4, 0.8, 2), CFrame.new(s * 26, y0 + 2.4, z - 3), Color3.new(1, 1, 1), Enum.Material.Fabric)
		P(b, "GuestSpot", Vector3.new(1, 1, 1), CFrame.new(s * 26, y0 + 4.5, z - 1) * CFrame.Angles(0, s == -1 and -math.pi/2 or math.pi/2, 0), Color3.new(1,1,1), nil, {Transparency = 1, CanCollide = false})
		-- tier sign above window
		local sign = P(b, "TierSign", Vector3.new(0.4, 2, 10), CFrame.new(fx + s * -0.7, y0 + 13.5, z), Color3.fromRGB(40, 40, 50))
		label(sign, face, "Normal x1")
		-- glass showcase between room and aisle
		local scx = s * 10
		P(b, "ShowcaseBase", Vector3.new(6, 1.5, 6), CFrame.new(scx, y0 + 0.75, z), Color3.fromRGB(60, 60, 80), Enum.Material.Marble)
		P(b, "ShowcaseGlass", Vector3.new(5.6, 6, 5.6), CFrame.new(scx, y0 + 4.5, z), Color3.fromRGB(200, 240, 255), Enum.Material.Glass, {Transparency = 0.8, CanCollide = true})
		P(b, "MonsterSpot", Vector3.new(1, 1, 1), CFrame.new(scx, y0 + 1.5, z) * CFrame.Angles(0, s == -1 and -math.pi/2 or math.pi/2, 0), Color3.new(1,1,1), nil, {Transparency = 1, CanCollide = false})
		local plate = P(b, "PayPlate", Vector3.new(0.4, 1.5, 5), CFrame.new(s * 6.6, y0 + 0.75, z), Color3.fromRGB(40, 180, 80))
		label(plate, face, "Empty")
		-- lock cover for locked bedrooms
		local lock = P(b, "Lock", Vector3.new(1.4, 12, 20.4), CFrame.new(fx + s * -0.8, y0 + 6, z), Color3.fromRGB(60, 60, 60), Enum.Material.Concrete, {Transparency = 0.15})
		label(lock, face, "🔒 Rebirth to unlock")
		b.Parent = bedrooms
	end
end

-- egg pedestal at the front of the aisle
P(plot, "EggPedestal", Vector3.new(6, 2, 6), CFrame.new(0, 2, -42), Color3.fromRGB(80, 70, 140), Enum.Material.Marble)
local egg = P(plot, "Egg", Vector3.new(4, 5, 4), CFrame.new(0, 5.5, -42), Color3.fromRGB(150, 110, 230), Enum.Material.SmoothPlastic, {Shape = Enum.PartType.Ball})
local pp = Instance.new("ProximityPrompt") pp.Name = "HatchPrompt" pp.ActionText = "Hatch" pp.ObjectText = "Spooky Egg" pp.HoldDuration = 0.5 pp.MaxActivationDistance = 10 pp.Parent = egg
local bb = Instance.new("BillboardGui") bb.Size = UDim2.fromOffset(220, 60) bb.StudsOffset = Vector3.new(0, 4.5, 0) bb.Parent = egg
local t = Instance.new("TextLabel") t.Name = "Text" t.Size = UDim2.fromScale(1,1) t.BackgroundTransparency = 1 t.Font = Enum.Font.FredokaOne t.TextScaled = true t.TextColor3 = Color3.new(1,1,1) t.TextStrokeTransparency = 0 t.Text = "Spooky Egg - 250 Fear" t.Parent = bb
plot.Parent = workspace

workspace.SpawnLocation.CFrame = CFrame.new(0, 1.7, -36)
workspace.SpawnLocation.Size = Vector3.new(6, 1, 6)
