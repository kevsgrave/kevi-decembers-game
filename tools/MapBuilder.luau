-- Builds the whole map in Studio (Edit mode): a spooky-cute night hub with the egg shrine and shop stall,
-- 8 plots in a ring around it (one per player, 8 players a server), dirt paths, and scenery made from the
-- generated models in ServerStorage.MapKit. Run from Studio by requiring a copy of this module and calling
-- the steps in order; each step clears and rebuilds only its own folder, so any step can be re-run.
--
-- Layout data lives at the top: change a number and re-run the step.
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")

local MapBuilder = {}

MapBuilder.PLOT_COUNT = 8
MapBuilder.RING_RADIUS = 210 -- hub centre to each plot's local origin; plot fronts sit 62 studs closer
MapBuilder.PLAZA_RADIUS = 70
MapBuilder.RING_PATH = 12 -- width of the path circling the plaza
MapBuilder.TREE_RING = {300, 440} -- forest band beyond the plots
MapBuilder.SEED = 20261029

local STUDS = "rbxassetid://6372755229"
local PLOT_BLUE = Color3.fromRGB(70, 110, 230)
local CARPET_PINK = Color3.fromRGB(255, 50, 130)
local STONE = Color3.fromRGB(105, 98, 135)
local STONE_LIGHT = Color3.fromRGB(150, 142, 180)
local DIRT = Color3.fromRGB(125, 88, 60)
local PLAZA = Color3.fromRGB(92, 84, 120)
local GRASS = Color3.fromRGB(60, 170, 60)
local LANTERN = Color3.fromRGB(255, 170, 80)

--------------------------------------------------------------------------- helpers

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

local function deco(p) -- scenery defaults from the vault: anchored, no touch/query, small parts without shadows
	p.CanTouch = false p.CanQuery = false
	if p.Size.Magnitude < 4 then p.CastShadow = false end
	return p
end

local function stroke(t, th)
	local s = Instance.new("UIStroke") s.Thickness = th or 3 s.Color = Color3.fromRGB(20, 10, 40) s.Parent = t
end

local function label(part, face, text, color)
	local g = Instance.new("SurfaceGui") g.Face = face g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud g.PixelsPerStud = 40 g.Parent = part
	local t = Instance.new("TextLabel") t.Name = "Text" t.Size = UDim2.fromScale(1, 1) t.BackgroundTransparency = 1
	t.Font = Enum.Font.FredokaOne t.TextScaled = true t.Text = text t.TextColor3 = color or Color3.new(1, 1, 1) t.Parent = g
	stroke(t, 4)
	return t
end

-- a flat disc lying on the ground (Roblox cylinders run along X)
local function disc(parent, name, radius, thick, centre, color, mat)
	local p = P(parent, name, Vector3.new(thick, radius * 2, radius * 2), CFrame.new(centre) * CFrame.Angles(0, 0, math.pi / 2), color, mat)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- clone a generated kit model, scale it to a target height and stand it at cf (its pivot is the base centre)
local function kit(name, parent, cf, height)
	local src = ServerStorage.MapKit:FindFirstChild(name)
	if not src then return nil end
	local m = src:Clone()
	if height then
		local _, size = m:GetBoundingBox()
		m:ScaleTo(height / size.Y)
	end
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

local function lampLight(parent, pos, range)
	local glow = P(parent, "LampGlow", Vector3.new(0.5, 0.5, 0.5), CFrame.new(pos), LANTERN, Enum.Material.Neon, {Transparency = 1, CanCollide = false})
	deco(glow)
	local l = Instance.new("PointLight") l.Color = LANTERN l.Range = range or 16 l.Brightness = 1 l.Shadows = false l.Parent = glow
end

local function lamp(parent, cf, height)
	height = height or 10
	local m = kit("Lamp", parent, cf, height)
	lampLight(parent, (cf * CFrame.new(0, height * 0.88, 0)).Position, 18)
	return m
end

-- generated MaterialVariants live in MaterialService
local function hasMaterial(name)
	return game:GetService("MaterialService"):FindFirstChild(name, true) ~= nil
end

local function folder(name, parent)
	local old = (parent or workspace):FindFirstChild(name)
	if old then old:Destroy() end
	local f = Instance.new(name == "Plots" and "Folder" or "Folder")
	f.Name = name
	f.Parent = parent or workspace
	return f
end

-- position on the ground at radius r and angle a (degrees, 0 = +Z), facing the hub centre
local function ringCF(r, a, y)
	local rad = math.rad(a)
	local pos = Vector3.new(math.sin(rad) * r, y or 0, math.cos(rad) * r)
	return CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
end
MapBuilder.ringCF = ringCF

local function plotAngle(i) return (i - 1) * 360 / MapBuilder.PLOT_COUNT end

--------------------------------------------------------------------------- lighting

function MapBuilder.lighting()
	Lighting.ClockTime = 0
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(110, 90, 160)
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 110, 180)
	Lighting.ExposureCompensation = 0.3
	Lighting.FogColor = Color3.fromRGB(60, 45, 100)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
	atm.Density = 0.32 atm.Offset = 0.1 atm.Color = Color3.fromRGB(150, 120, 220) atm.Decay = Color3.fromRGB(70, 50, 130) atm.Glare = 0 atm.Haze = 1.2
	workspace.Baseplate.Color = GRASS
	return "lighting set"
end

--------------------------------------------------------------------------- cleanup of the single-plot map

function MapBuilder.clearOld()
	local removed = {}
	for _, n in ipairs({"Plot", "Decor", "StylePreview", "HumpPreview", "KidPreview"}) do
		local o = workspace:FindFirstChild(n)
		if o then o:Destroy() table.insert(removed, n) end
	end
	-- the egg moves from the plot to the hub's egg shrine
	for _, n in ipairs({"Egg", "EggPedestal"}) do
		local o = ServerStorage.PlotTemplate:FindFirstChild(n)
		if o then o:Destroy() table.insert(removed, "PlotTemplate." .. n) end
	end
	return "removed: " .. table.concat(removed, ", ")
end

--------------------------------------------------------------------------- plots

-- one plot shell in its own frame (local origin = the old single plot's origin; front toward local -Z)
local function plotShell(parent, i)
	local frame = ringCF(MapBuilder.RING_RADIUS, plotAngle(i))
	local m = Instance.new("Model")
	m.Name = "Plot" .. i
	m:SetAttribute("Frame", frame)
	local function L(x, y, z) return frame * CFrame.new(x, y, z) end

	-- platform
	studs(P(m, "Floor", Vector3.new(96, 2, 116), L(0, 1, -4), PLOT_BLUE), 4)
	studs(P(m, "Carpet", Vector3.new(12, 0.2, 117), L(0, 2.1, -4.5), CARPET_PINK, Enum.Material.Fabric), 4)
	for _, x in ipairs({-6.4, 6.4}) do -- gold edging along the carpet
		deco(P(m, "CarpetTrim", Vector3.new(0.8, 0.25, 117), L(x, 2.12, -4.5), Color3.fromRGB(255, 200, 70), Enum.Material.Metal))
	end
	-- low stone wall with a lighter cap; a gap at the front for the entrance arch
	local function wall(name, size, cf)
		studs(P(m, name, size, cf, STONE), 2)
		deco(P(m, name .. "Cap", Vector3.new(size.X + 0.4, 0.5, size.Z + 0.4), cf * CFrame.new(0, size.Y / 2 + 0.25, 0), STONE_LIGHT))
	end
	wall("WallLeft", Vector3.new(2, 3, 118), L(-49, 1.5, -4))
	wall("WallRight", Vector3.new(2, 3, 118), L(49, 1.5, -4))
	wall("WallBack", Vector3.new(96, 3, 2), L(0, 1.5, 55))
	wall("WallFrontL", Vector3.new(41, 3, 2), L(-29.5, 1.5, -63))
	wall("WallFrontR", Vector3.new(41, 3, 2), L(29.5, 1.5, -63))
	-- pillars with lanterns along the wall
	for _, xz in ipairs({{-49, -63}, {49, -63}, {-49, -34}, {49, -34}, {-49, -5}, {49, -5}, {-49, 24}, {49, 24}, {-49, 55}, {49, 55}, {-20, 55}, {20, 55}}) do
		kit("StonePillar", m, L(xz[1], 0, xz[2]), 7)
	end
	-- entrance arch at the front of the carpet, with the owner's name on it
	kit("PlotArch", m, L(0, 2, -63), 15)
	local sign = P(m, "OwnerSign", Vector3.new(14, 2.6, 0.5), L(0, 12.6, -64.4), Color3.fromRGB(80, 50, 35), Enum.Material.WoodPlanks)
	deco(sign)
	label(sign, Enum.NormalId.Front, "Free plot", Color3.fromRGB(120, 255, 140))
	-- lamps along the carpet, planters between the bedroom rows
	for _, z in ipairs({-52, -22, 8, 38}) do
		for _, x in ipairs({-8.5, 8.5}) do lamp(m, L(x, 2, z), 9) end
	end
	for _, z in ipairs({-16, 16}) do
		for _, x in ipairs({-9.5, 9.5}) do kit("Planter", m, L(x, 2, z) * CFrame.Angles(0, math.rad(90), 0), 3) end
	end
	for _, xz in ipairs({{-42, -57}, {42, -57}, {-42, 50}, {42, 50}}) do kit("Pumpkins", m, L(xz[1], 2, xz[2]) * CFrame.Angles(0, math.rad(xz[1] * 3), 0), 2.6) end
	-- where the owner arrives: just inside the arch, facing their bedrooms
	local spawn = P(m, "SpawnPoint", Vector3.new(4, 1, 4), L(0, 2.6, -56) * CFrame.Angles(0, math.pi, 0), Color3.new(1, 1, 1), nil, {Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false})
	spawn.CFrame = CFrame.lookAt(spawn.Position, (L(0, 2.6, 0)).Position)
	local contents = Instance.new("Folder") contents.Name = "Contents" contents.Parent = m
	m.WorldPivot = frame
	m.Parent = parent
	return m
end

function MapBuilder.plots()
	local f = folder("Plots")
	for i = 1, MapBuilder.PLOT_COUNT do plotShell(f, i) end
	return "plots: " .. #f:GetChildren()
end

--------------------------------------------------------------------------- hub

function MapBuilder.hub()
	local f = folder("Hub")
	local R = MapBuilder.PLAZA_RADIUS
	disc(f, "RingPath", R + MapBuilder.RING_PATH, 0.4, Vector3.new(0, 0.2, 0), DIRT, Enum.Material.Ground)
	local plaza = disc(f, "Plaza", R, 0.6, Vector3.new(0, 0.3, 0), PLAZA, Enum.Material.Cobblestone)
	if hasMaterial("PlazaStone") then plaza.MaterialVariant = "PlazaStone" end
	disc(f, "PlazaRim", R + 0.8, 0.5, Vector3.new(0, 0.25, 0), STONE_LIGHT)

	-- egg shrine in the middle: the core spend is the centrepiece and is visible from every path
	local shrine = kit("EggShrine", f, CFrame.new(0, 0.6, 0), 5)
	local top = 0.6 + 5
	local egg = kit("SpookyEgg", f, CFrame.new(0, top, 0), 6)
	local eggPart
	if egg then
		eggPart = egg:FindFirstChildWhichIsA("MeshPart", true)
		eggPart.Name = "Egg"
		eggPart.CanQuery = true
		eggPart.Parent = f
		egg:Destroy()
	else
		eggPart = P(f, "Egg", Vector3.new(4.5, 5.5, 4.5), CFrame.new(0, top + 2.75, 0), Color3.fromRGB(180, 130, 255), nil, {Shape = Enum.PartType.Ball})
	end
	local pp = Instance.new("ProximityPrompt") pp.Name = "HatchPrompt" pp.ActionText = "Hatch" pp.ObjectText = "Spooky Egg" pp.HoldDuration = 0.5 pp.MaxActivationDistance = 12 pp.RequiresLineOfSight = false pp.Parent = eggPart
	local bb = Instance.new("BillboardGui") bb.Size = UDim2.fromScale(12, 2.4) bb.StudsOffset = Vector3.new(0, 5.5, 0) bb.Parent = eggPart
	local t = Instance.new("TextLabel") t.Name = "Text" t.Size = UDim2.fromScale(1, 1) t.BackgroundTransparency = 1 t.Font = Enum.Font.FredokaOne t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 220, 80) t.Text = "Spooky Egg" t.Parent = bb stroke(t, 4)
	local glow = Instance.new("PointLight") glow.Color = Color3.fromRGB(190, 120, 255) glow.Range = 22 glow.Brightness = 1.5 glow.Parent = eggPart
	-- odds board facing the main approach
	local board = P(f, "EggOdds", Vector3.new(7, 8, 0.5), CFrame.new(0, 4.6, -12), Color3.fromRGB(80, 50, 35), Enum.Material.WoodPlanks)
	board.CFrame = CFrame.lookAt(board.Position, Vector3.new(0, board.Position.Y, -60))
	label(board, Enum.NormalId.Front, "Odds", Color3.new(1, 1, 1))
	for _, x in ipairs({-3.2, 3.2}) do deco(P(f, "OddsPost", Vector3.new(0.5, 9, 0.5), board.CFrame * CFrame.new(x, -0.5, 0.3), Color3.fromRGB(70, 45, 30), Enum.Material.Wood)) end

	-- shop stall between two paths, facing the centre (the rotating shop is not built yet)
	local shopCF = ringCF(R - 14, 22.5, 0.6)
	kit("ShopStall", f, shopCF, 12)
	local shopSign = P(f, "ShopSign", Vector3.new(10, 2.4, 0.4), shopCF * CFrame.new(0, 13.5, -1), Color3.fromRGB(80, 50, 35), Enum.Material.WoodPlanks)
	deco(shopSign)
	label(shopSign, Enum.NormalId.Front, "Shop - opening soon", Color3.fromRGB(255, 200, 70))

	-- benches, lamps, pumpkins and a cauldron round the plaza; lamps mark each path's mouth
	for k = 1, MapBuilder.PLOT_COUNT do
		local a = plotAngle(k)
		for _, off in ipairs({-9, 9}) do lamp(f, ringCF(R + 4, a, 0.4) * CFrame.new(off, 0, 0), 10) end
		if k ~= 1 then kit("Bench", f, ringCF(R - 6, a + 22.5, 0.6), 3.2) end
		kit("Pumpkins", f, ringCF(R - 3, a + 12, 0.6), 2.6)
	end
	for k = 1, 6 do kit("Pumpkins", f, ringCF(9, k * 60, 0.6), 2.2) end
	kit("Cauldron", f, ringCF(R - 16, 202.5, 0.6), 5)
	-- floating ghost lights over the plaza
	for k = 1, 6 do
		local a = math.rad(k * 60 + 30)
		local g = P(f, "GhostLight", Vector3.new(2.5, 3, 2.5), CFrame.new(math.sin(a) * 34, 14 + (k % 3) * 2, math.cos(a) * 34), Color3.fromRGB(220, 255, 255), Enum.Material.Neon, {Shape = Enum.PartType.Ball, Transparency = 0.25, CanCollide = false})
		deco(g)
		local l = Instance.new("PointLight") l.Color = Color3.fromRGB(160, 255, 255) l.Range = 16 l.Brightness = 0.8 l.Shadows = false l.Parent = g
	end

	-- the spawn is only used before a player's plot is assigned (a moment after joining)
	local sp = workspace:FindFirstChildOfClass("SpawnLocation")
	if sp then
		sp.CFrame = CFrame.new(0, 1.2, -24) sp.Size = Vector3.new(6, 1, 6)
		sp.Transparency = 1 sp.CanCollide = false
	end
	return "hub built: " .. #f:GetDescendants() .. " instances"
end

--------------------------------------------------------------------------- paths

function MapBuilder.paths()
	local f = folder("Paths")
	local inner = MapBuilder.PLAZA_RADIUS + MapBuilder.RING_PATH - 1
	local outer = MapBuilder.RING_RADIUS - 63
	for i = 1, MapBuilder.PLOT_COUNT do
		local a = plotAngle(i)
		local mid = (inner + outer) / 2
		local cf = ringCF(mid, a, 0.15)
		local path = P(f, "Path", Vector3.new(16, 0.3, outer - inner + 2), cf, DIRT, Enum.Material.Ground)
		if hasMaterial("DirtPath") then path.MaterialVariant = "DirtPath" end
		studs(path, 4)
		for _, r in ipairs({inner + 14, inner + 38, outer - 6}) do
			for _, off in ipairs({-10, 10}) do lamp(f, ringCF(r, a, 0) * CFrame.new(off, 0, 0), 9) end
		end
		-- a few crooked fence sections along the path edges
		for _, r in ipairs({inner + 26, inner + 50}) do
			for _, off in ipairs({-9.5, 9.5}) do
				kit("Fence", f, ringCF(r, a, 0) * CFrame.new(off, 0, 0) * CFrame.Angles(0, math.rad(90), 0), 3)
			end
		end
	end
	return "paths built: " .. #f:GetChildren() .. " parts/models"
end

--------------------------------------------------------------------------- scenery

function MapBuilder.scenery()
	local f = folder("Scenery")
	local rng = Random.new(MapBuilder.SEED)
	local gapAngles = {}
	for i = 1, MapBuilder.PLOT_COUNT do table.insert(gapAngles, plotAngle(i) + 180 / MapBuilder.PLOT_COUNT) end

	-- between neighbouring plots: alternate a little graveyard, a pumpkin patch and a mushroom grove
	for k, a in ipairs(gapAngles) do
		local kind = k % 3
		local base = ringCF(232, a)
		if kind == 0 then
			for g = 1, 4 do kit("Graves", f, base * CFrame.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-14, 14)) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), 3.6) end
			kit("SpookyTree", f, base * CFrame.new(0, 0, 18), 18)
			for s = -1, 1, 2 do
				for j = -2, 2 do kit("Fence", f, base * CFrame.new(s * 18, 0, j * 7.6) * CFrame.Angles(0, math.rad(90), 0), 3) end
			end
		elseif kind == 1 then
			for g = 1, 7 do kit("Pumpkins", f, base * CFrame.new(rng:NextNumber(-16, 16), 0, rng:NextNumber(-18, 18)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(2.4, 3.6)) end
			kit("Scarecrow", f, base * CFrame.new(0, 0, 4), 9)
		else
			for g = 1, 6 do kit("Mushrooms", f, base * CFrame.new(rng:NextNumber(-16, 16), 0, rng:NextNumber(-18, 18)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(2.5, 4)) end
			kit("Rocks", f, base * CFrame.new(rng:NextNumber(-10, 10), 0, 14), 4)
			kit("LeafyTree", f, base * CFrame.new(0, 0, 20), 16)
		end
		-- a lamp at the inner end of each gap, so walking round the plaza ring stays lit
		lamp(f, ringCF(150, a), 9)
	end

	-- the forest band beyond the plots
	local trees = {"PineTree", "PineTree", "PineTree", "SpookyTree", "SpookyTree", "LeafyTree"}
	local n = 0
	for ring = 1, 4 do
		local r0 = MapBuilder.TREE_RING[1] + (ring - 1) * 34
		local count = 34 + ring * 6
		for j = 1, count do
			local a = (j + rng:NextNumber(-0.35, 0.35)) * 360 / count + ring * 7
			local r = r0 + rng:NextNumber(-10, 10)
			local name = trees[rng:NextInteger(1, #trees)]
			local h = (name == "PineTree" and 22 or name == "SpookyTree" and 17 or 15) * rng:NextNumber(0.8, 1.35)
			kit(name, f, ringCF(r, a) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), h)
			n += 1
		end
	end
	for j = 1, 24 do
		local a = rng:NextNumber(0, 360)
		local r = rng:NextNumber(285, 420)
		kit(j % 2 == 0 and "Rocks" or "Mushrooms", f, ringCF(r, a) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), j % 2 == 0 and rng:NextNumber(3, 6) or rng:NextNumber(2.5, 4))
	end

	-- rolling hills and the haunted mansion on the skyline (behind a gap so it shows from the hub)
	for j = 1, 14 do
		local a = j * 360 / 14 + rng:NextNumber(-8, 8)
		local r = rng:NextNumber(470, 540)
		local w = rng:NextNumber(90, 150)
		local hill = P(f, "Hill", Vector3.new(w, rng:NextNumber(40, 70), w * rng:NextNumber(0.7, 1.1)), ringCF(r, a, 0), Color3.fromRGB(45, 130, 55), Enum.Material.Grass)
		local mesh = Instance.new("SpecialMesh") mesh.MeshType = Enum.MeshType.Sphere mesh.Parent = hill
		deco(hill)
	end
	local mansionA = gapAngles[3]
	local hill = P(f, "MansionHill", Vector3.new(120, 36, 110), ringCF(470, mansionA, 2), Color3.fromRGB(50, 120, 55), Enum.Material.Grass)
	local mm = Instance.new("SpecialMesh") mm.MeshType = Enum.MeshType.Sphere mm.Parent = hill
	deco(hill)
	kit("Mansion", f, ringCF(470, mansionA, 14) * CFrame.Angles(0, 0, 0), 60)
	lampLight(f, (ringCF(470, mansionA, 40)).Position, 60)

	-- a few ghost lights drifting over the forest
	for j = 1, 10 do
		local a = math.rad(j * 36 + 10)
		local r = rng:NextNumber(280, 360)
		local g = P(f, "GhostLight", Vector3.new(3, 3.6, 3), CFrame.new(math.sin(a) * r, rng:NextNumber(14, 26), math.cos(a) * r), Color3.fromRGB(220, 255, 255), Enum.Material.Neon, {Shape = Enum.PartType.Ball, Transparency = 0.25, CanCollide = false})
		deco(g)
		local l = Instance.new("PointLight") l.Color = Color3.fromRGB(160, 255, 255) l.Range = 20 l.Brightness = 0.8 l.Shadows = false l.Parent = g
	end
	return "scenery: " .. n .. " trees, " .. #f:GetChildren() .. " items"
end

--------------------------------------------------------------------------- budget report (vault: audit after every art pass)

function MapBuilder.audit()
	local out = {}
	for _, n in ipairs({"Hub", "Plots", "Paths", "Scenery"}) do
		local f = workspace:FindFirstChild(n)
		if f then
			local parts, meshes, tris = 0, 0, 0
			for _, d in ipairs(f:GetDescendants()) do
				if d:IsA("BasePart") then parts += 1 end
				if d:IsA("MeshPart") then meshes += 1 end
			end
			table.insert(out, string.format("%s: %d instances, %d parts, %d mesh parts", n, #f:GetDescendants(), parts, meshes))
		end
	end
	return table.concat(out, "\n")
end

--------------------------------------------------------------------------- bedroom exteriors (on the template)

-- Dresses the outside of every bedroom in ServerStorage.PlotTemplate: siding over the walls, corner boards,
-- a stone plinth, a framed window with shutters and a flower box, an arched crawl hole, a wall lantern,
-- a wooden tier sign under the eaves, a generated roof and a chimney with a little smoke.
-- Everything goes in the bedroom's "Exterior" model, so the interior styles never touch it.
local SIDING = {
	Color3.fromRGB(255, 232, 214), Color3.fromRGB(214, 230, 255), Color3.fromRGB(222, 248, 214),
	Color3.fromRGB(255, 243, 196), Color3.fromRGB(234, 222, 255), Color3.fromRGB(255, 222, 210),
}
local SHUTTER = {
	Color3.fromRGB(150, 70, 170), Color3.fromRGB(60, 110, 200), Color3.fromRGB(60, 150, 90),
	Color3.fromRGB(220, 130, 40), Color3.fromRGB(120, 80, 200), Color3.fromRGB(200, 70, 90),
}
local TRIM = Color3.fromRGB(250, 248, 240)

function MapBuilder.exteriors()
	local done = 0
	for _, b in ipairs(ServerStorage.PlotTemplate.Bedrooms:GetChildren()) do
		local idx = b:GetAttribute("Index")
		local old = b:FindFirstChild("Exterior") if old then old:Destroy() end
		local ex = Instance.new("Model") ex.Name = "Exterior"
		local floor = b.RoomFloor
		local s = math.sign(floor.Position.X)
		local L = -s
		local zc = floor.Position.Z
		local front = math.abs(b.FrontLow.Position.X)
		local back = math.abs(b.BackWall.Position.X)
		local y0 = floor.Position.Y - floor.Size.Y / 2
		local H = b.BackWall.Size.Y
		local half = floor.Size.Z / 2
		local depth = back - front
		local cx = s * (front + back) / 2
		local siding = SIDING[(idx - 1) % #SIDING + 1]
		local function sidingPart(name, size, cf)
			local p = P(ex, name, size, cf, siding, Enum.Material.WoodPlanks)
			if hasMaterial("HouseSiding") then p.MaterialVariant = "HouseSiding" end
			deco(p)
			return p
		end
		local outFront = s * (front - 0.5 - 0.07) -- just outside the front wall's aisle-facing face
		-- siding: the four front pieces, both side walls and the back wall
		for _, n in ipairs({"FrontLow", "FrontHigh", "FrontLeft", "FrontRight"}) do
			local w = b[n]
			sidingPart("Siding" .. n, Vector3.new(0.12, w.Size.Y, w.Size.Z), CFrame.new(outFront, w.Position.Y, w.Position.Z))
		end
		for _, sgn in ipairs({-1, 1}) do
			sidingPart("SidingSide", Vector3.new(depth + 1.2, H, 0.12), CFrame.new(cx, y0 + H / 2, zc + sgn * (half + 0.57)))
		end
		sidingPart("SidingBack", Vector3.new(0.12, H, half * 2 + 1.2), CFrame.new(s * (back + 0.57), y0 + H / 2, zc))
		-- corner boards and a stone plinth all round
		for _, xx in ipairs({front - 0.4, back + 0.4}) do
			for _, sgn in ipairs({-1, 1}) do
				deco(P(ex, "CornerBoard", Vector3.new(0.9, H + 0.2, 0.9), CFrame.new(s * xx, y0 + H / 2, zc + sgn * (half + 0.45)), TRIM))
			end
		end
		local stone = Color3.fromRGB(120, 112, 140)
		studs(deco(P(ex, "PlinthFront", Vector3.new(0.5, 1.2, half * 2 + 1.4), CFrame.new(s * (front - 0.75), y0 + 0.6, zc), stone)), 2)
		studs(deco(P(ex, "PlinthBack", Vector3.new(0.5, 1.2, half * 2 + 1.4), CFrame.new(s * (back + 0.75), y0 + 0.6, zc), stone)), 2)
		for _, sgn in ipairs({-1, 1}) do
			studs(deco(P(ex, "PlinthSide", Vector3.new(depth + 1.6, 1.2, 0.5), CFrame.new(cx, y0 + 0.6, zc + sgn * (half + 0.75)), stone)), 2)
		end

		-- window: white frame, shutters either side, flower box under the sill
		local win = b.Window
		local wz, wy = win.Position.Z, win.Position.Y
		local ww, wh = win.Size.Z, win.Size.Y
		local fx = s * (front - 0.8)
		deco(P(ex, "WindowTop", Vector3.new(0.6, 0.8, ww + 1.6), CFrame.new(fx, wy + wh / 2 + 0.4, wz), TRIM))
		for _, sgn in ipairs({-1, 1}) do
			deco(P(ex, "WindowSide", Vector3.new(0.6, wh + 0.8, 0.8), CFrame.new(fx, wy, wz + sgn * (ww / 2 + 0.4)), TRIM))
			local sh = P(ex, "Shutter", Vector3.new(0.35, wh - 0.4, 2), CFrame.new(s * (front - 0.75), wy, wz + sgn * (ww / 2 + 1.8)), SHUTTER[(idx - 1) % #SHUTTER + 1], Enum.Material.WoodPlanks)
			deco(sh)
			deco(P(ex, "ShutterSlat", Vector3.new(0.4, 0.25, 1.6), sh.CFrame * CFrame.new(0, 1.6, 0), SHUTTER[(idx - 1) % #SHUTTER + 1]:Lerp(Color3.new(0, 0, 0), 0.25)))
			deco(P(ex, "ShutterSlat", Vector3.new(0.4, 0.25, 1.6), sh.CFrame * CFrame.new(0, -1.6, 0), SHUTTER[(idx - 1) % #SHUTTER + 1]:Lerp(Color3.new(0, 0, 0), 0.25)))
		end
		-- the generated flower box is short, so a row of them fills the sill
		local probe = kit("FlowerBox", ex, CFrame.identity, 1.8)
		if probe then
			local _, bs = probe:GetBoundingBox()
			probe:Destroy()
			local n = math.max(1, math.floor(ww / (bs.X * 0.95)))
			for k = 1, n do
				local boxPos = Vector3.new(s * (front - 1.5), wy - wh / 2 - 1.75, wz + (k - (n + 1) / 2) * (ww / n))
				kit("FlowerBox", ex, CFrame.lookAt(boxPos, boxPos + Vector3.new(-s, 0, 0)), 1.8)
			end
		end

		-- crawl hole: deeper so it shows over the siding, with an arched top and a wooden frame
		local hole = b.CrawlHole
		hole.Size = Vector3.new(1.7, hole.Size.Y, hole.Size.Z)
		local hw = hole.Size.Z
		local top = hole.Position.Y + hole.Size.Y / 2
		local arch = P(ex, "HoleArch", Vector3.new(1.7, hw, hw), CFrame.new(hole.Position.X, top, hole.Position.Z) * CFrame.Angles(0, 0, 0), hole.Color, Enum.Material.SmoothPlastic, {Shape = Enum.PartType.Cylinder})
		deco(arch)
		local ring = P(ex, "HoleFrame", Vector3.new(1.55, hw + 1, hw + 1), arch.CFrame, Color3.fromRGB(120, 75, 45), Enum.Material.Wood, {Shape = Enum.PartType.Cylinder})
		deco(ring)
		for _, sgn in ipairs({-1, 1}) do
			deco(P(ex, "HolePost", Vector3.new(1.55, hole.Size.Y, 0.5), CFrame.new(hole.Position.X, hole.Position.Y, hole.Position.Z + sgn * (hw / 2 + 0.25)), Color3.fromRGB(120, 75, 45), Enum.Material.Wood))
		end

		-- wall lantern on the facade above the display case
		local lanternPos = Vector3.new(s * (front - 1.0), y0 + 12.2, zc + L * 9)
		kit("WallLantern", ex, CFrame.lookAt(lanternPos, lanternPos + Vector3.new(-s, 0, 0)) * CFrame.new(0, -1.2, 0), 2.6)
		lampLight(ex, lanternPos + Vector3.new(-s * 0.6, 0, 0), 12)

		-- the tier sign becomes a wooden board under the eaves
		local sign = b.TierSign
		sign.Size = Vector3.new(0.5, 2.4, 11)
		sign.CFrame = CFrame.new(s * (front - 0.85), y0 + H - 1.35, zc + L * 2)
		sign.Color = Color3.fromRGB(85, 55, 38)
		sign.Material = Enum.Material.WoodPlanks

		-- the locked cover: boarded up planks instead of a grey slab
		b.Lock.Material = Enum.Material.WoodPlanks
		b.Lock.Color = Color3.fromRGB(110, 75, 50)

		-- roof: the flat lid stays for collisions but hides under a generated gable roof
		b.Roof.Transparency = 1
		local roof = kit("Roof", ex, CFrame.new(cx, y0 + H, zc), nil)
		if roof then
			-- stretch the generated roof over the footprint plus an overhang, keeping a cartoon-low height
			local mp = roof:FindFirstChildWhichIsA("MeshPart", true)
			mp.Size = Vector3.new(depth + 3, 8, half * 2 + 3)
			mp.CFrame = CFrame.new(cx, y0 + H + 0.6 + 4, zc)
		end
		local chimney = P(ex, "Chimney", Vector3.new(2.4, 6, 2.4), CFrame.new(s * (back - 6), y0 + H + 7, zc + L * 7), Color3.fromRGB(150, 70, 60), Enum.Material.Brick)
		deco(chimney)
		local smoke = Instance.new("ParticleEmitter") smoke.Name = "Smoke"
		smoke.Rate = 2 smoke.Lifetime = NumberRange.new(3, 5) smoke.Speed = NumberRange.new(1.5, 2.5)
		smoke.Size = NumberSequence.new({NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 3.5)})
		smoke.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1)})
		smoke.Color = ColorSequence.new(Color3.fromRGB(200, 190, 220)) smoke.LightEmission = 0.1 smoke.EmissionDirection = Enum.NormalId.Top
		smoke.Parent = chimney

		ex.Parent = b
		done += 1
	end
	return "exteriors on " .. done .. " bedrooms"
end

return MapBuilder
