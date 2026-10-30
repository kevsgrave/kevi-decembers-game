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
MapBuilder.PLAZA_RADIUS = 50
MapBuilder.RING_PATH = 12 -- width of the path circling the plaza
MapBuilder.SEED = 20261029
MapBuilder.WALK_SPEED = 30 -- the map is big: default 16 feels slow

local STUDS = "rbxassetid://6372755229"
local PLOT_BLUE = Color3.fromRGB(70, 110, 230)
local CARPET_PINK = Color3.fromRGB(255, 50, 130)
local STONE = Color3.fromRGB(105, 98, 135)
local STONE_LIGHT = Color3.fromRGB(150, 142, 180)
local DIRT = Color3.fromRGB(150, 112, 78)
local PLAZA = Color3.fromRGB(150, 140, 185)
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
-- the generated kit models face their local +X; turn them so cf's -Z (the CFrame.lookAt direction) is their front
local KIT_FRONT = CFrame.Angles(0, math.rad(90), 0)

local function kit(name, parent, cf, height)
	local src = ServerStorage.MapKit:FindFirstChild(name)
	if not src then return nil end
	local m = src:Clone()
	if height then
		local _, size = m:GetBoundingBox()
		m:ScaleTo(height / size.Y)
	end
	m:PivotTo(cf * KIT_FRONT)
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
	game:GetService("StarterPlayer").CharacterWalkSpeed = MapBuilder.WALK_SPEED
	Lighting.ClockTime = 0
	Lighting.Brightness = 2
	Lighting.Ambient = Color3.fromRGB(110, 90, 160)
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 110, 180)
	Lighting.ExposureCompensation = 0.3
	Lighting.FogColor = Color3.fromRGB(60, 45, 100)
	local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
	atm.Density = 0.22 atm.Offset = 0.05 atm.Color = Color3.fromRGB(150, 120, 220) atm.Decay = Color3.fromRGB(70, 50, 130) atm.Glare = 0 atm.Haze = 0.6
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
	studs(P(m, "Carpet", Vector3.new(12, 0.2, 128), L(0, 2.1, -10), CARPET_PINK, Enum.Material.Fabric), 4)
	for _, x in ipairs({-6.4, 6.4}) do -- gold edging along the carpet
		deco(P(m, "CarpetTrim", Vector3.new(0.8, 0.25, 128), L(x, 2.12, -10), Color3.fromRGB(255, 200, 70), Enum.Material.Metal))
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
	-- a stone landing carries the arch's front feet and a ramp walks up to it, so nothing hangs off the platform
	studs(P(m, "EntryLanding", Vector3.new(20, 2, 12), L(0, 1, -68), STONE_LIGHT, Enum.Material.Slate), 4)
	local rampLow, rampHigh = L(0, 0, -84).Position, L(0, 2, -74).Position
	local rampLen = (rampHigh - rampLow).Magnitude
	studs(P(m, "EntryRamp", Vector3.new(16, 1, rampLen), CFrame.lookAt(rampLow, rampHigh) * CFrame.new(0, -0.5, -rampLen / 2), STONE_LIGHT, Enum.Material.Slate), 4)
	local arch = kit("PlotArch", m, L(0, 2, -63), 15.3) -- 18 wide: exactly the gap in the front wall
	local archTop = 15.3
	if arch then local acf, asz = arch:GetBoundingBox() archTop = acf.Position.Y + asz.Y / 2 - frame.Position.Y end
	local sign = P(m, "OwnerSign", Vector3.new(14, 2.6, 0.5), L(0, archTop + 1.3, -63), Color3.fromRGB(80, 50, 35), Enum.Material.WoodPlanks)
	deco(sign)
	label(sign, Enum.NormalId.Front, "Free plot", Color3.fromRGB(120, 255, 140))
	-- lamps along the carpet, planters between the bedroom rows
	for _, z in ipairs({-52, -22, 8, 38}) do
		for _, x in ipairs({-8.5, 8.5}) do lamp(m, L(x, 2, z), 9) end
	end
	for _, z in ipairs({-16, 16}) do
		for _, x in ipairs({-9.5, 9.5}) do kit("Planter", m, L(x, 2, z) * CFrame.Angles(0, math.rad(x > 0 and 90 or -90), 0), 3) end
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
	disc(f, "DaisStep", 15, 0.6, Vector3.new(0, 0.9, 0), STONE_LIGHT, Enum.Material.Slate)
	disc(f, "Dais", 12.5, 1.2, Vector3.new(0, 1.2, 0), STONE, Enum.Material.Slate)
	local shrine = kit("EggShrine", f, CFrame.new(0, 1.8, 0), 7)
	local top = 1.8 + 7
	local egg = kit("SpookyEgg", f, CFrame.new(0, top, 0), 8)
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
	local board = P(f, "EggOdds", Vector3.new(7, 8, 0.5), CFrame.new(0, 5.2, -17), Color3.fromRGB(80, 50, 35), Enum.Material.WoodPlanks)
	board.CFrame = CFrame.lookAt(board.Position, Vector3.new(0, board.Position.Y, -60))
	label(board, Enum.NormalId.Front, "Odds", Color3.new(1, 1, 1))
	for _, x in ipairs({-3.2, 3.2}) do deco(P(f, "OddsPost", Vector3.new(0.5, 9, 0.5), board.CFrame * CFrame.new(x, -0.5, 0.3), Color3.fromRGB(70, 45, 30), Enum.Material.Wood)) end

	-- shop stall between two paths, facing the centre (the rotating shop is not built yet)
	local shopCF = ringCF(R - 12, 22.5, 0.6)
	kit("ShopStall", f, shopCF, 12)
	local shopSign = P(f, "ShopSign", Vector3.new(10, 2.4, 0.4), shopCF * CFrame.new(0, 13.5, -1), Color3.fromRGB(80, 50, 35), Enum.Material.WoodPlanks)
	deco(shopSign)
	label(shopSign, Enum.NormalId.Front, "Shop - opening soon", Color3.fromRGB(255, 200, 70))

	-- benches, lamps, pumpkins and a cauldron round the plaza; lamps mark each path's mouth
	for k = 1, MapBuilder.PLOT_COUNT do
		local a = plotAngle(k)
		for _, off in ipairs({-9, 9}) do lamp(f, ringCF(R + 4, a, 0.4) * CFrame.new(off, 0, 0), 10) end
		-- each gap between paths is laid out the same, mirrored about its centre; two gaps hold the shop and cauldron instead
		if k ~= 1 and k ~= 5 then kit("Bench", f, ringCF(R - 7, a + 22.5, 0.6), 3.2) end
		for _, off in ipairs({-7, 7}) do kit("Pumpkins", f, ringCF(R - 5, a + 22.5 + off, 0.6), 2.6) end
	end
	for k = 1, 8 do kit("Pumpkins", f, ringCF(14, k * 45 + 22.5, 1.5), 2.4) end
	kit("Cauldron", f, ringCF(R - 12, 202.5, 0.6), 5)
	-- planters ring the dais, and pine trees frame the plaza between the paths
	for k = 1, MapBuilder.PLOT_COUNT do
		kit("Planter", f, ringCF(20, plotAngle(k) + 22.5, 0.6), 3)
		kit("PineTree", f, ringCF(R - 1, plotAngle(k) + 22.5, 0.6), 18)
	end
	-- floating ghost lights over the plaza
	for k = 1, 6 do
		local a = math.rad(k * 60 + 30)
		local g = P(f, "GhostLight", Vector3.new(1, 1, 1), CFrame.new(math.sin(a) * 34, 14 + (k % 3) * 2, math.cos(a) * 34), Color3.fromRGB(150, 255, 220), Enum.Material.Neon, {Shape = Enum.PartType.Ball, Transparency = 0.4, CanCollide = false})
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
		studs(path, 4)
		for _, r in ipairs({inner + 14, inner + 38, outer - 6}) do
			for _, off in ipairs({-12, 12}) do lamp(f, ringCF(r, a, 0) * CFrame.new(off, 0, 0), 9) end
		end
		-- unbroken fence runs along the path edges, between the lamps (a height-3 fence section is 4 long)
		for _, r0 in ipairs({inner + 18, inner + 42}) do
			for k = 0, 4 do
				for _, off in ipairs({-10.5, 10.5}) do
					kit("Fence", f, ringCF(r0 + k * 4, a, 0) * CFrame.new(off, 0, 0) * CFrame.Angles(0, math.rad(90), 0), 3)
				end
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
		if k % 2 == 1 then
			-- dirt road through this gap, out to the terrain and the ring road
			local inner, outer = MapBuilder.PLAZA_RADIUS + MapBuilder.RING_PATH - 1, 285
			studs(P(f, "GapPath", Vector3.new(14, 0.3, outer - inner), ringCF((inner + outer) / 2, a, 0.15), DIRT, Enum.Material.Ground), 4)
			for _, r in ipairs({100, 150, 200, 250}) do
				for _, off in ipairs({-10, 10}) do lamp(f, ringCF(r, a) * CFrame.new(off, 0, 0), 9) end
			end
		else
		local base = ringCF(232, a)
		if kind == 0 then
			for g = 1, 4 do kit("Graves", f, base * CFrame.new(rng:NextNumber(-12, 12), 0, rng:NextNumber(-14, 14)) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), 3.6) end
			kit("SpookyTree", f, base * CFrame.new(0, 0, 18), 18)
			for s = -1, 1, 2 do
				for j = -4, 4 do kit("Fence", f, base * CFrame.new(s * 18, 0, j * 4) * CFrame.Angles(0, math.rad(90), 0), 3) end
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
	end

	return "scenery: " .. #f:GetChildren() .. " items"
end

--------------------------------------------------------------------------- terrain and the wider world

-- Everything beyond the plots: real terrain (r > TERRAIN_START) with trails from the hub's four main gaps out to
-- a lake, the mansion hill, a farm and a witch's hollow, four smaller clearings, a forest, and a mountain ring.
local TERRAIN_START = 276
local RING_ROAD = 296
local WATER_Y = -4
local BOUNDARY = 860
local LAKE_R, ISLAND_R = 95, 22

local function polar(r, g) return Vector3.new(math.sin(math.rad(g)) * r, 0, math.cos(math.rad(g)) * r) end
local function smooth(a, b, x) local t = math.clamp((x - a) / (b - a), 0, 1) return t * t * (3 - 2 * t) end
local function lerp(a, b, t) return a + (b - a) * t end

local ZONES = {
	lake = {c = polar(600, 22.5)},
	mansion = {c = polar(650, 112.5), r = 60, y = 48},
	farm = {c = polar(570, 202.5), r = 90, y = 3},
	hollow = {c = polar(580, 292.5), r = 80, y = -4},
	well = {c = polar(420, 67.5), r = 32, y = 1},
	graveyard = {c = polar(430, 157.5), r = 38, y = 1},
	rocks = {c = polar(420, 247.5), r = 32, y = 1},
	picnic = {c = polar(420, 337.5), r = 32, y = 1},
}
local function trail(y0, y1, ...)
	local pts, spec = {}, {...}
	for k, s in ipairs(spec) do
		local p = polar(s[1], s[2])
		table.insert(pts, Vector3.new(p.X, lerp(y0, y1, (k - 1) / (#spec - 1)), p.Z))
	end
	return pts
end
local TRAILS = {
	trail(0.5, 1, {276, 22.5}, {340, 22.5}, {440, 25}, {505, 22.5}, {544, 22.5}),
	trail(0.5, 48, {276, 112.5}, {340, 117}, {420, 108}, {500, 116}, {590, 112.5}),
	trail(0.5, 3, {276, 202.5}, {350, 198}, {420, 206}, {480, 202.5}),
	trail(0.5, -4, {276, 292.5}, {350, 297}, {430, 288}, {500, 292.5}),
	trail(0.5, 1, {296, 67.5}, {390, 67.5}),
	trail(0.5, 1, {296, 157.5}, {392, 157.5}),
	trail(0.5, 1, {296, 247.5}, {390, 247.5}),
	trail(0.5, 1, {296, 337.5}, {390, 337.5}),
}

-- nearest point on any trail: distance and the trail's height there
local function nearTrail(x, z)
	local best, y = math.huge, 0
	for _, pts in ipairs(TRAILS) do
		for k = 1, #pts - 1 do
			local a, b = pts[k], pts[k + 1]
			local dx, dz = b.X - a.X, b.Z - a.Z
			local t = math.clamp(((x - a.X) * dx + (z - a.Z) * dz) / (dx * dx + dz * dz), 0, 1)
			local ex, ez = x - (a.X + dx * t), z - (a.Z + dz * t)
			local d = ex * ex + ez * ez
			if d < best then best, y = d, lerp(a.Y, b.Y, t) end
		end
	end
	return math.sqrt(best), y
end

-- ground height and whether this column is a dirt road
local function ground(x, z)
	local r = math.sqrt(x * x + z * z)
	if r < TERRAIN_START then return -100, false end
	local n = math.noise(x / 180, z / 180, 7) + math.noise(x / 70, z / 70, 3) * 0.35
	local y = 0.5 + math.max(n + 0.25, -0.15) * 26 * smooth(330, 560, r) -- floor: no stray ponds in the dips
	y += smooth(760, 980, r) * (110 + math.noise(x / 120, z / 120, 9) * 70)
	for _, zone in pairs(ZONES) do
		if zone.r then
			local d = math.sqrt((x - zone.c.X) ^ 2 + (z - zone.c.Z) ^ 2)
			y = lerp(zone.y, y, smooth(zone.r, zone.r + 45, d))
		end
	end
	local lake = ZONES.lake.c
	local dl = math.sqrt((x - lake.X) ^ 2 + (z - lake.Z) ^ 2)
	y = lerp(-14, y, smooth(LAKE_R * 0.7, LAKE_R * 1.1, dl))
	y = lerp(1.5, y, smooth(ISLAND_R, ISLAND_R + 14, dl))
	local dt, ty = nearTrail(x, z)
	y = lerp(ty, y, smooth(8, 24, dt))
	local dr = math.abs(r - RING_ROAD)
	y = lerp(0.5, y, smooth(8, 22, dr))
	return y, dt < 7 or dr < 7
end
MapBuilder.ground = ground

-- writes in small chunks with a yield between them; run from task.spawn and poll the state table
function MapBuilder.terrain(state)
	state = state or {}
	local T = workspace.Terrain
	T:Clear()
	T:SetMaterialColor(Enum.Material.LeafyGrass, GRASS)
	T:SetMaterialColor(Enum.Material.Ground, Color3.fromRGB(135, 120, 85)) -- this material reads red if given DIRT
	T:SetMaterialColor(Enum.Material.Rock, STONE)
	T.WaterColor = Color3.fromRGB(40, 130, 140) T.WaterTransparency = 0.5 T.WaterReflectance = 0.6 T.WaterWaveSize = 0.05 T.WaterWaveSpeed = 6
	-- the baseplate only carries the plots; beyond it the terrain (and the lake bed) takes over
	workspace.Baseplate.Size = Vector3.new(620, 16, 620)
	local RES, EDGE, CHUNK, Y0, Y1 = 4, 1040, 260, -16, 224
	local ny = (Y1 - Y0) / RES
	-- LeafyGrass: plain Grass grows realistic blades that clash with the cartoon style
	local air, grass, dirt, rock, water = Enum.Material.Air, Enum.Material.LeafyGrass, Enum.Material.Ground, Enum.Material.Rock, Enum.Material.Water
	local done = 0
	for cx = -EDGE, EDGE - CHUNK, CHUNK do
		for cz = -EDGE, EDGE - CHUNK, CHUNK do
			local nh = CHUNK / RES
			local mats, occs, any = table.create(nh), table.create(nh), false
			for i = 1, nh do
				local mi, oi = table.create(ny), table.create(ny)
				for j = 1, ny do mi[j] = table.create(nh, air) oi[j] = table.create(nh, 0) end
				mats[i], occs[i] = mi, oi
				local x = cx + (i - 0.5) * RES
				for k = 1, nh do
					local z = cz + (k - 0.5) * RES
					local h, road = ground(x, z)
					if h > -100 then
						any = true
						local surface = road and dirt or (h > 75 and rock or grass)
						for j = 1, ny do
							local bottom = Y0 + (j - 1) * RES
							local occ = math.clamp((h - 2 - bottom) / RES, 0, 1) -- smooth terrain renders half a voxel above its occupancy
							if occ > 0 then
								mi[j][k] = bottom + RES < h - 6 and rock or surface
								oi[j][k] = occ
							elseif bottom < WATER_Y then
								mi[j][k] = water
								oi[j][k] = 1
							end
							if bottom > h and bottom >= WATER_Y then break end
						end
					end
				end
			end
			if any then
				T:WriteVoxels(Region3.new(Vector3.new(cx, Y0, cz), Vector3.new(cx + CHUNK, Y1, cz + CHUNK)), RES, mats, occs)
			end
			done += 1
			state.done = done
			task.wait()
		end
	end
	state.finished = true
	return state
end

function MapBuilder.world()
	local f = folder("World")
	local rng = Random.new(MapBuilder.SEED + 1)

	-- stand a kit on the ground; look = the point its front should face (the hub by default)
	local function put(name, pos, height, look)
		local y = ground(pos.X, pos.Z)
		local p = Vector3.new(pos.X, y - 0.2, pos.Z)
		local target = look and Vector3.new(look.X, p.Y, look.Z) or Vector3.new(0, p.Y, 0)
		return kit(name, f, CFrame.lookAt(p, target), height)
	end
	local function ghost(pos, y)
		local g = P(f, "GhostLight", Vector3.new(1.4, 1.4, 1.4), CFrame.new(pos.X, ground(pos.X, pos.Z) + y, pos.Z), Color3.fromRGB(150, 255, 220), Enum.Material.Neon, {Shape = Enum.PartType.Ball, Transparency = 0.4, CanCollide = false})
		deco(g)
		local l = Instance.new("PointLight") l.Color = Color3.fromRGB(160, 255, 255) l.Range = 22 l.Brightness = 1 l.Shadows = false l.Parent = g
	end
	local function fenceRun(a, b, height)
		local _, s = ServerStorage.MapKit.Fence:GetBoundingBox()
		local len = s.Z * height / s.Y
		local count = math.max(1, math.floor((b - a).Magnitude / len))
		local dir = (b - a).Unit
		for k = 0, count - 1 do
			local p = a + dir * ((k + 0.5) * (b - a).Magnitude / count)
			local base = Vector3.new(p.X, ground(p.X, p.Z) - 0.2, p.Z)
			-- a fence's length runs along its cf X
			kit("Fence", f, CFrame.lookAt(base, base + Vector3.new(dir.Z, 0, -dir.X)), height)
		end
	end
	local function around(zone, radius, a) return zone.c + polar(radius, a) end

	-- lamps down every trail, alternating sides, and round the ring road
	for _, pts in ipairs(TRAILS) do
		local side, carry = 11, 20
		for k = 1, #pts - 1 do
			local a, b = Vector3.new(pts[k].X, 0, pts[k].Z), Vector3.new(pts[k + 1].X, 0, pts[k + 1].Z)
			local dir, len = (b - a).Unit, (b - a).Magnitude
			local d = carry
			while d < len do
				local p = a + dir * d + Vector3.new(dir.Z, 0, -dir.X) * side
				lamp(f, CFrame.new(p.X, ground(p.X, p.Z) - 0.2, p.Z), 10)
				side = -side
				d += 48
			end
			carry = d - len
		end
	end
	for k = 1, 16 do
		local g = 11.25 + (k - 1) * 22.5
		put("Rocks", polar(RING_ROAD + 12, g), 3)
		local p = polar(RING_ROAD + 10, g + 11.25)
		lamp(f, CFrame.new(p.X, ground(p.X, p.Z) - 0.2, p.Z), 10)
	end

	-- the lake: an island gazebo reached by a bridge, docks, and rocks on the shore
	local lake = ZONES.lake
	put("Gazebo", lake.c, 18)
	local g0 = 22.5
	local bridgePos = polar(561, g0)
	local outward = polar(1, g0)
	local bridgeBase = Vector3.new(bridgePos.X, WATER_Y - 1, bridgePos.Z)
	local bridge = kit("Bridge", f, CFrame.lookAt(bridgeBase, bridgeBase + Vector3.new(outward.Z, 0, -outward.X)), 18)
	if bridge then
		for _, d in ipairs(bridge:GetDescendants()) do if d:IsA("BasePart") then d.CanCollide = false end end
		-- walk on two invisible ramps instead of the mesh's bumpy collision
		local top = Vector3.new(bridgePos.X, WATER_Y - 1 + 18 * 0.56, bridgePos.Z)
		local nearEnd = polar(544, g0) + Vector3.new(0, 1, 0)
		local farEnd = polar(578, g0) + Vector3.new(0, 1.5, 0)
		for _, seg in ipairs({{nearEnd, top}, {top, farEnd}}) do
			local len = (seg[2] - seg[1]).Magnitude
			P(f, "BridgeWalk", Vector3.new(9, 1, len), CFrame.lookAt(seg[1], seg[2]) * CFrame.new(0, -0.5, -len / 2), DIRT, nil, {Transparency = 1})
		end
	end
	for _, a in ipairs({100, 260}) do
		local edge = around(lake, LAKE_R * 0.92, a)
		local base = Vector3.new(edge.X, WATER_Y + 0.5, edge.Z)
		-- a dock's length runs along its cf X: point that at the lake's middle
		local inward = (lake.c - edge).Unit
		kit("Dock", f, CFrame.lookAt(base, base + Vector3.new(inward.Z, 0, -inward.X)), 7)
	end
	for k = 1, 22 do
		local a = k * 360 / 22 + rng:NextNumber(-5, 5)
		if math.abs(((a - 202.5 + 180) % 360) - 180) > 18 then -- leave the trail's end clear
			put(k % 3 == 0 and "LeafyTree" or "Rocks", around(lake, LAKE_R * 1.2 + rng:NextNumber(0, 16), a), k % 3 == 0 and 18 or rng:NextNumber(4, 8))
		end
	end
	for k = 1, 8 do ghost(around(lake, 45, k * 45), 10) end

	-- the mansion hill: an arch at the top of the trail, a matching fence line, graves and dead trees
	local mansion = ZONES.mansion
	local gateP = mansion.c - mansion.c.Unit * 52
	put("Mansion", mansion.c + mansion.c.Unit * 12, 60)
	put("PlotArch", gateP, 18)
	local tangent = Vector3.new(gateP.Unit.Z, 0, -gateP.Unit.X)
	for _, s in ipairs({-1, 1}) do
		put("StonePillar", gateP + tangent * s * 12, 8)
		fenceRun(gateP + tangent * s * 13, gateP + tangent * s * 48, 5)
		put("StonePillar", gateP + tangent * s * 49, 8)
		for row = 1, 3 do
			for col = 1, 3 do
				put("Graves", gateP + tangent * s * (10 + col * 10) + gateP.Unit * (8 + row * 10), 4)
			end
		end
		put("SpookyTree", gateP + tangent * s * 44 + gateP.Unit * 40, 26)
	end
	for k = 1, 8 do ghost(around(mansion, 54, k * 45 + 10), 16) end

	-- the farm: a barn and windmill at the back, two fenced pumpkin fields in straight rows
	local farm = ZONES.farm
	local toHub = -farm.c.Unit
	local across = Vector3.new(toHub.Z, 0, -toHub.X)
	put("Barn", farm.c - toHub * 40 - across * 24, 30)
	put("Windmill", farm.c - toHub * 42 + across * 34, 44)
	put("Wagon", farm.c - toHub * 12 - across * 2, 8)
	for _, s in ipairs({-1, 1}) do
		local field = farm.c + toHub * 28 + across * s * 38
		for row = -2, 2 do
			for col = -2, 2 do put("Pumpkins", field + toHub * (row * 8) + across * (col * 8), 3) end
		end
		put("Scarecrow", field, 9)
		local a, b, c, d = field + toHub * 22 - across * 22, field + toHub * 22 + across * 22, field - toHub * 22 + across * 22, field - toHub * 22 - across * 22
		fenceRun(a, b, 4) fenceRun(b, c, 4) fenceRun(c, d, 4) fenceRun(d, a, 4)
		for k = 0, 2 do put("HayBales", farm.c - toHub * 18 + across * s * (18 + k * 9), 6) end
	end

	-- the witch's hollow: a hut and cauldron in a dip, ringed by giant glowing mushrooms
	local hollow = ZONES.hollow
	local hTo = -hollow.c.Unit
	put("WitchHut", hollow.c - hTo * 14, 32)
	put("Cauldron", hollow.c + hTo * 10, 7)
	for k = 1, 12 do
		local a = k * 30
		local pos = around(hollow, 52, a)
		if (pos - hollow.c).Unit:Dot(hTo) < 0.9 then -- leave the trail's way in clear
			local m = put("GiantMushroom", pos, 16 + (k % 3) * 6, hollow.c)
			if m then
				local l = Instance.new("PointLight") l.Color = Color3.fromRGB(190, 110, 255) l.Range = 34 l.Brightness = 1.2 l.Shadows = false l.Parent = m:FindFirstChildWhichIsA("MeshPart", true)
			end
		end
		put("Mushrooms", around(hollow, 30, a + 15), 4, hollow.c)
	end
	for k = 1, 8 do ghost(around(hollow, 28, k * 45), 12) end

	-- smaller clearings on the other four trails
	local well = ZONES.well
	put("Well", well.c, 12)
	for k = 1, 4 do put("Bench", around(well, 18, k * 90 + 45), 3.2, well.c) end
	local yard = ZONES.graveyard
	local yTo = -yard.c.Unit
	local yAcross = Vector3.new(yTo.Z, 0, -yTo.X)
	put("IronGate", yard.c + yTo * 30, 12)
	local _, gs = ServerStorage.MapKit.IronGate:GetBoundingBox()
	local gateHalf = gs.Z * 12 / gs.Y / 2 -- fence meets the gate's posts whatever its proportions
	local c1, c2, c3, c4 = yard.c + yTo * 30 - yAcross * 30, yard.c + yTo * 30 + yAcross * 30, yard.c - yTo * 30 + yAcross * 30, yard.c - yTo * 30 - yAcross * 30
	fenceRun(yard.c + yTo * 30 + yAcross * gateHalf, c2, 5) fenceRun(c2, c3, 5) fenceRun(c3, c4, 5) fenceRun(c4, c1, 5) fenceRun(c1, yard.c + yTo * 30 - yAcross * gateHalf, 5)
	put("Crypt", yard.c - yTo * 18, 20)
	for row = 0, 1 do
		for col = -2, 2 do
			if col ~= 0 then put("Graves", yard.c + yTo * (6 + row * 12) + yAcross * (col * 9), 4) end
		end
	end
	local rocks = ZONES.rocks
	for k = 1, 9 do put("Rocks", around(rocks, 22, k * 40), 7 + (k % 3) * 3) end
	put("Cauldron", rocks.c, 6)
	local picnic = ZONES.picnic
	put("Gazebo", picnic.c, 16)
	for k = 1, 6 do put("Bench", around(picnic, 20, k * 60 + 30), 3.2, picnic.c) end

	-- the forest fills what is left, up the mountain sides
	local trees = {"PineTree", "PineTree", "PineTree", "SpookyTree", "SpookyTree", "LeafyTree"}
	local placed, tries = 0, 0
	while placed < 520 and tries < 6000 do
		tries += 1
		local p = polar(rng:NextNumber(312, 930), rng:NextNumber(0, 360))
		local clear = (p - lake.c).Magnitude > LAKE_R * 1.15
		for _, zone in pairs(ZONES) do
			if zone.r and (p - zone.c).Magnitude < zone.r + 12 then clear = false end
		end
		if clear and nearTrail(p.X, p.Z) > 20 and math.abs(p.Magnitude - RING_ROAD) > 16 then
			local name = trees[rng:NextInteger(1, #trees)]
			local h = (name == "PineTree" and 26 or name == "SpookyTree" and 20 or 18) * rng:NextNumber(0.85, 1.4)
			kit(name, f, CFrame.new(p.X, ground(p.X, p.Z) - 0.4, p.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), h)
			placed += 1
			if placed % 80 == 0 then task.wait() end
		end
	end
	for j = 1, 70 do
		local p = polar(rng:NextNumber(315, 780), rng:NextNumber(0, 360))
		if nearTrail(p.X, p.Z) > 14 and (p - lake.c).Magnitude > LAKE_R * 1.1 then
			kit(j % 2 == 0 and "Rocks" or "Mushrooms", f, CFrame.new(p.X, ground(p.X, p.Z) - 0.2, p.Z) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), j % 2 == 0 and rng:NextNumber(3, 7) or rng:NextNumber(2.5, 4))
		end
	end
	for j = 1, 16 do ghost(polar(rng:NextNumber(330, 700), j * 22.5 + 10), rng:NextNumber(12, 24)) end

	-- an invisible ring where the mountains begin, so nobody climbs out of the world
	local wallLen = 2 * BOUNDARY * math.tan(math.rad(3.75)) + 2
	for k = 1, 48 do
		local p = polar(BOUNDARY, (k - 0.5) * 7.5) + Vector3.new(0, 250, 0)
		P(f, "Boundary", Vector3.new(wallLen, 600, 4), CFrame.lookAt(p, Vector3.new(0, 250, 0)), STONE, nil, {Transparency = 1, CanTouch = false, CanQuery = false})
	end
	return "world: " .. placed .. " trees, " .. #f:GetChildren() .. " items"
end

--------------------------------------------------------------------------- budget report (vault: audit after every art pass)

function MapBuilder.audit()
	local out = {}
	for _, n in ipairs({"Hub", "Plots", "Paths", "Scenery", "World"}) do
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
local SIDING = { -- light tints: the siding material's own texture is darker
	Color3.fromRGB(255, 245, 235), Color3.fromRGB(235, 245, 255), Color3.fromRGB(240, 255, 235),
	Color3.fromRGB(255, 252, 225), Color3.fromRGB(248, 240, 255), Color3.fromRGB(255, 238, 232),
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
			-- keep clear of the crawl hole, which sits under the hole-side end of the window
			local span = ww - 5
			local n = math.max(1, math.floor(span / (bs.X * 0.95)))
			local mid = wz + L * 2.5 -- shift the row toward the display-case side
			for k = 1, n do
				local boxPos = Vector3.new(s * (front - 1.5), wy - wh / 2 - 1.75, mid + (k - (n + 1) / 2) * (span / n))
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
