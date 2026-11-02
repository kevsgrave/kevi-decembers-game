-- Builds the whole map in Studio (Edit mode) in the chunky brick style of the owner's references (docs/references/style):
-- bright studded checker ground, flared block trees and teal water, all from Parts. General spooky, not Halloween: twisty dead
-- trees, a few graves, ruins, a mansion, mist and ghosts. The ring of 8 plots and auto-assign are the owner's decisions.
-- Run from Studio by requiring a copy of this module and calling the steps; each clears and rebuilds only its own folder.
-- Layout data lives at the top: change a number and re-run the step.
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")

local MapBuilder = {}

MapBuilder.PLOT_COUNT = 8
MapBuilder.RING_RADIUS = 210 -- hub centre to each plot's local origin; plot fronts sit 84 studs closer, with the ramp
MapBuilder.PLAZA_RADIUS = 50
MapBuilder.ISLAND_RADIUS = 300 -- the main island
MapBuilder.TILE = 24
MapBuilder.SEED = 20261102
MapBuilder.WALK_SPEED = 30

local STUDS = "rbxassetid://6372755229"
local GRASS_A = Color3.fromRGB(150, 198, 104)
local GRASS_B = Color3.fromRGB(132, 182, 92)
local WATER = Color3.fromRGB(52, 196, 176)
local TRUNK = Color3.fromRGB(196, 124, 72)
local TRUNK_DARK = Color3.fromRGB(150, 94, 58)
local LEAF = Color3.fromRGB(70, 140, 92)
local ROCK = Color3.fromRGB(150, 148, 168)
local ROCK_DARK = Color3.fromRGB(118, 116, 140)
local DIRT = Color3.fromRGB(205, 158, 104)
local PLANK = Color3.fromRGB(120, 84, 60)
local PLOT_BLUE = Color3.fromRGB(70, 120, 240)
local CARPET_PINK = Color3.fromRGB(255, 60, 140)
local STONE = Color3.fromRGB(120, 112, 152)
local STONE_LIGHT = Color3.fromRGB(170, 162, 200)
local PLAZA_A = Color3.fromRGB(172, 166, 194)
local PLAZA_B = Color3.fromRGB(152, 146, 178)
local LANTERN = Color3.fromRGB(150, 255, 210) -- a cold spooky glow, not a warm Halloween one
local IRON = Color3.fromRGB(56, 54, 72)
local WOOD = Color3.fromRGB(86, 54, 38)

--------------------------------------------------------------------------- helpers

local function studs(p, tile, topOnly)
	local faces = topOnly and {Enum.NormalId.Top} or {Enum.NormalId.Top, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}
	for _, face in ipairs(faces) do
		local t = Instance.new("Texture") t.Texture = STUDS t.Face = face t.StudsPerTileU = tile or 4 t.StudsPerTileV = tile or 4
		t.Color3 = Color3.new(0, 0, 0) t.Transparency = 0.75 t.Parent = p
	end
	return p
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

local function folder(name, parent)
	local old = (parent or workspace):FindFirstChild(name)
	if old then old:Destroy() end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = parent or workspace
	return f
end

local function group(parent, name)
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- position on the ground at radius r and angle a (degrees, 0 = +Z), facing the hub centre
local function ringCF(r, a, y)
	local rad = math.rad(a)
	local pos = Vector3.new(math.sin(rad) * r, y or 0, math.cos(rad) * r)
	return CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
end
MapBuilder.ringCF = ringCF

local function polar(r, g) return Vector3.new(math.sin(math.rad(g)) * r, 0, math.cos(math.rad(g)) * r) end
local function plotAngle(i) return (i - 1) * 360 / MapBuilder.PLOT_COUNT end

-- the four islands off the main one, on the roads between plots
local ISLANDS = {
	{name = "Graveyard", angle = 22.5, r = 110},
	{name = "Mansion", angle = 112.5, r = 110},
	{name = "DarkWoods", angle = 202.5, r = 110},
	{name = "Ruins", angle = 292.5, r = 110},
}
local ISLAND_CENTRE = 450
local BOUNDARY = 600

--------------------------------------------------------------------------- props, all parts

local function deadTree(parent, cf, height)
	local m = group(parent, "DeadTree")
	local h = height or 22
	local w = h * 0.2
	-- a wide flared foot of stepped blocks, then a narrowing trunk
	studs(deco(P(m, "Foot", Vector3.new(w * 2.3, h * 0.1, w * 2.3), cf * CFrame.new(0, h * 0.05, 0), TRUNK)), 2)
	studs(deco(P(m, "Foot", Vector3.new(w * 1.7, h * 0.14, w * 1.7), cf * CFrame.new(0, h * 0.17, 0), TRUNK)), 2)
	studs(deco(P(m, "Trunk", Vector3.new(w * 1.2, h * 0.5, w * 1.2), cf * CFrame.new(0, h * 0.49, 0), TRUNK)), 2)
	studs(deco(P(m, "Trunk", Vector3.new(w * 0.8, h * 0.3, w * 0.8), cf * CFrame.new(w * 0.1, h * 0.86, 0) * CFrame.Angles(0, 0, -0.12), TRUNK_DARK)), 2)
	-- bare branches
	for i, a in ipairs({0.5, 2.2, 3.9, 5.4}) do
		local up = h * (0.62 + i * 0.07)
		local branch = cf * CFrame.new(0, up, 0) * CFrame.Angles(0, a, 0) * CFrame.Angles(0, 0, 0.7) * CFrame.new(h * 0.14, 0, 0)
		deco(P(m, "Branch", Vector3.new(h * 0.3, h * 0.05, h * 0.05), branch, TRUNK_DARK))
	end
	return m
end

local function leafTree(parent, cf, height)
	local m = group(parent, "LeafyTree")
	local h = height or 20
	local w = h * 0.16
	studs(deco(P(m, "Foot", Vector3.new(w * 2, h * 0.12, w * 2), cf * CFrame.new(0, h * 0.06, 0), TRUNK)), 2)
	studs(deco(P(m, "Trunk", Vector3.new(w, h * 0.6, w), cf * CFrame.new(0, h * 0.4, 0), TRUNK)), 2)
	studs(deco(P(m, "Canopy", Vector3.new(h * 0.8, h * 0.22, h * 0.8), cf * CFrame.new(0, h * 0.75, 0), LEAF)), 4)
	studs(deco(P(m, "Canopy", Vector3.new(h * 0.5, h * 0.18, h * 0.5), cf * CFrame.new(0, h * 0.95, 0), LEAF:Lerp(Color3.new(1, 1, 1), 0.1))), 4)
	return m
end

local function rocks(parent, cf, size)
	local m = group(parent, "Rocks")
	local s = size or 5
	studs(deco(P(m, "Rock", Vector3.new(s * 1.3, s * 0.8, s), cf * CFrame.new(0, s * 0.4, 0) * CFrame.Angles(0, 0.3, 0), ROCK)), 2)
	studs(deco(P(m, "Rock", Vector3.new(s * 0.8, s * 1.1, s * 0.7), cf * CFrame.new(s * 0.5, s * 0.55, s * 0.3) * CFrame.Angles(0, 0.8, 0), ROCK_DARK)), 2)
	studs(deco(P(m, "Rock", Vector3.new(s * 0.5, s * 0.4, s * 0.5), cf * CFrame.new(-s * 0.7, s * 0.2, s * 0.3) * CFrame.Angles(0, 1.4, 0), ROCK)), 2)
	return m
end

local function grave(parent, cf, lean)
	local m = group(parent, "Grave")
	deco(P(m, "Base", Vector3.new(4, 0.6, 2.4), cf * CFrame.new(0, 0.3, 0), ROCK_DARK))
	local stone = cf * CFrame.new(0, 2.2, 0) * CFrame.Angles(lean or 0, 0, (lean or 0) * 0.6)
	studs(deco(P(m, "Stone", Vector3.new(3, 3.6, 0.8), stone, ROCK)), 2)
	deco(P(m, "Top", Vector3.new(2, 0.6, 0.8), stone * CFrame.new(0, 2.1, 0), ROCK))
	return m
end

-- a crooked iron lamp with a cold glow
local function lamp(parent, cf, height)
	local m = group(parent, "Lamp")
	local h = height or 10
	deco(P(m, "Foot", Vector3.new(1.6, 0.5, 1.6), cf * CFrame.new(0, 0.25, 0), IRON))
	deco(P(m, "Post", Vector3.new(0.6, h, 0.6), cf * CFrame.new(0, h / 2, 0), IRON))
	deco(P(m, "Arm", Vector3.new(1.8, 0.4, 0.4), cf * CFrame.new(0.7, h - 0.2, 0), IRON))
	local head = deco(P(m, "LampGlow", Vector3.new(1.1, 1.3, 1.1), cf * CFrame.new(1.4, h - 1, 0), LANTERN, Enum.Material.Neon))
	local l = Instance.new("PointLight") l.Color = LANTERN l.Range = 14 l.Brightness = 0.4 l.Shadows = false l.Parent = head
	return m
end

local function fence(parent, a, b, height)
	local m = group(parent, "Fence")
	local h = height or 4
	local length = (b - a).Magnitude
	local mid = (a + b) / 2
	local along = CFrame.lookAt(mid + Vector3.new(0, h * 0.7, 0), b + Vector3.new(0, h * 0.7, 0))
	deco(P(m, "Rail", Vector3.new(0.3, 0.4, length), along, IRON))
	deco(P(m, "Rail", Vector3.new(0.3, 0.4, length), along * CFrame.new(0, -h * 0.4, 0), IRON))
	local posts = math.max(1, math.floor(length / 5))
	for k = 0, posts do
		local p = a + (b - a) * (k / posts)
		deco(P(m, "Post", Vector3.new(0.5, h + 0.8, 0.5), CFrame.new(p + Vector3.new(0, (h + 0.8) / 2, 0)), IRON))
	end
	return m
end

local function mushrooms(parent, cf)
	local m = group(parent, "Mushrooms")
	for _, s in ipairs({{0, 0, 3}, {2.4, 1, 2}, {-2, 1.6, 1.5}}) do
		local base = cf * CFrame.new(s[1], 0, s[2])
		deco(P(m, "Stem", Vector3.new(s[3] * 0.4, s[3], s[3] * 0.4), base * CFrame.new(0, s[3] / 2, 0), Color3.fromRGB(235, 230, 215)))
		studs(deco(P(m, "Cap", Vector3.new(s[3] * 1.2, s[3] * 0.4, s[3] * 1.2), base * CFrame.new(0, s[3] * 1.15, 0), Color3.fromRGB(150, 100, 210))), 2)
	end
	return m
end

local function reeds(parent, cf)
	local m = group(parent, "Reeds")
	for k = 1, 3 do
		local h = 2.5 + k * 0.7
		deco(P(m, "Reed", Vector3.new(0.3, h, 0.3), cf * CFrame.new(k * 0.7 - 1.4, h / 2, (k % 2) * 0.5), Color3.fromRGB(90, 150, 70)))
	end
	return m
end

-- a flat root snaking over the ground, as in the references
local function root(parent, cf)
	local m = group(parent, "Root")
	local at = cf
	for k = 1, 5 do
		local len = 5 + (k % 2) * 2
		deco(P(m, "Root", Vector3.new(1.2, 0.5, len), at * CFrame.new(0, 0.25, -len / 2), TRUNK))
		at = at * CFrame.new(0, 0, -len + 0.4) * CFrame.Angles(0, if k % 2 == 0 then 0.6 else -0.5, 0)
	end
	return m
end

local function ghostFigure(parent, pos)
	local m = Instance.new("Model") m.Name = "Ghost"
	local cf = CFrame.lookAt(pos, Vector3.new(0, pos.Y, 0))
	local white = Color3.fromRGB(240, 248, 255)
	local function part(size, offset, color)
		deco(P(m, "Part", size, cf * offset, color, Enum.Material.SmoothPlastic, {CanCollide = false, Transparency = 0.1}))
	end
	-- a blocky ghost: stepped body, wavy feet and two square eyes
	part(Vector3.new(3, 2.4, 3), CFrame.new(0, 1.2, 0), white)
	part(Vector3.new(2.2, 0.8, 2.2), CFrame.new(0, 2.8, 0), white)
	for _, x in ipairs({-1, 0, 1}) do part(Vector3.new(0.9, 0.9, 3), CFrame.new(x, -0.45, 0), white) end
	for _, x in ipairs({-0.6, 0.6}) do part(Vector3.new(0.55, 0.75, 0.2), CFrame.new(x, 1.6, -1.55), Color3.fromRGB(25, 15, 45)) end
	m.Parent = parent
end

-- a chunky building, open at the front with a sign and a stepped roof; returns the model and the sign's part
local function building(parent, name, cf, width, depth, height, wallColor, trimColor, signText, signColor)
	local m = group(parent, name)
	local function L(x, y, z) return cf * CFrame.new(x, y, z) end
	studs(P(m, "Floor", Vector3.new(width, 0.6, depth), L(0, 0.3, 0), STONE), 4)
	studs(P(m, "WallBack", Vector3.new(width, height, 1.5), L(0, height / 2, depth / 2 - 0.75), wallColor), 2)
	for _, s in ipairs({-1, 1}) do
		studs(P(m, "WallSide", Vector3.new(1.5, height, depth), L(s * (width / 2 - 0.75), height / 2, 0), wallColor), 2)
		studs(P(m, "Column", Vector3.new(2.4, height + 1, 2.4), L(s * (width / 2 - 0.5), (height + 1) / 2, -depth / 2 + 0.5), trimColor), 2)
	end
	-- stepped roof
	local w, d, y = width + 3, depth + 3, height + 0.6
	for k = 1, 3 do
		studs(P(m, "Roof", Vector3.new(w, 1.2, d), L(0, y, 0), trimColor:Lerp(Color3.new(0, 0, 0), 0.08 * k)), 4)
		w -= 6 d -= 5 y += 1.2
	end
	local sign = deco(P(m, name .. "Sign", Vector3.new(width - 1, 3, 0.6), L(0, height - 1, -depth / 2 - 0.4), WOOD, Enum.Material.WoodPlanks))
	label(sign, Enum.NormalId.Front, signText, signColor)
	local glow = deco(P(m, "Glow", Vector3.new(0.5, 0.5, 0.5), L(0, height - 3, -2), LANTERN, Enum.Material.Neon, {Transparency = 1, CanCollide = false}))
	local l = Instance.new("PointLight") l.Color = signColor l.Range = 24 l.Brightness = 1 l.Shadows = false l.Parent = glow
	return m, sign
end

local function prompt(parent, name, action, object, distance)
	local pp = Instance.new("ProximityPrompt") pp.Name = name pp.ActionText = action pp.ObjectText = object
	pp.HoldDuration = 0.2 pp.MaxActivationDistance = distance or 12 pp.RequiresLineOfSight = false pp.Parent = parent
	return pp
end

--------------------------------------------------------------------------- lighting

function MapBuilder.lighting()
	game:GetService("StarterPlayer").CharacterWalkSpeed = MapBuilder.WALK_SPEED
	Lighting.ClockTime = 14 -- a misty afternoon: bright enough for the colours, still a little spooky
	Lighting.GeographicLatitude = 30
	Lighting.Brightness = 1.8
	Lighting.Ambient = Color3.fromRGB(125, 120, 112)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 138, 126)
	Lighting.ExposureCompensation = -0.05
	Lighting.FogColor = Color3.fromRGB(150, 190, 180)
	for _, effect in ipairs(Lighting:GetChildren()) do
		-- the old night look's glow washes out the saturated brick colours
		if effect:IsA("BloomEffect") then effect.Intensity = 0.3 effect.Threshold = 1.5 end
		if effect:IsA("SunRaysEffect") then effect.Enabled = false end
		if effect:IsA("DepthOfFieldEffect") then effect.Enabled = false end
	end
	local atm = Lighting:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere", Lighting)
	atm.Density = 0.16 atm.Offset = 0 atm.Color = Color3.fromRGB(195, 205, 190) atm.Decay = Color3.fromRGB(105, 125, 115) atm.Glare = 0 atm.Haze = 0.6
	return "lighting set"
end

--------------------------------------------------------------------------- ground

-- studded checker tiles on a disc of land
local function tiles(f, centre, radius)
	local T = MapBuilder.TILE
	local n = 0
	local x0 = math.floor((centre.X - radius) / T)
	local z0 = math.floor((centre.Z - radius) / T)
	for ix = x0, x0 + math.ceil(radius * 2 / T) do
		for iz = z0, z0 + math.ceil(radius * 2 / T) do
			local pos = Vector3.new((ix + 0.5) * T, -0.5, (iz + 0.5) * T)
			if (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(centre.X, 0, centre.Z)).Magnitude <= radius then
				studs(P(f, "Tile", Vector3.new(T, 1, T), CFrame.new(pos), if (ix + iz) % 2 == 0 then GRASS_A else GRASS_B), 4, true)
				n += 1
				if n % 120 == 0 then task.wait() end
			end
		end
	end
	return n
end

function MapBuilder.ground()
	workspace.Terrain:Clear()
	local water = workspace.Baseplate
	for _, c in ipairs(water:GetChildren()) do c:Destroy() end
	water.Size = Vector3.new(1600, 8, 1600)
	water.CFrame = CFrame.new(0, -5.2, 0)
	water.Color = WATER
	water.Material = Enum.Material.SmoothPlastic
	local f = folder("Ground")
	-- more water out to the horizon, so the sea doesn't stop in a grey band
	for _, xz in ipairs({{-1, -1}, {0, -1}, {1, -1}, {-1, 0}, {1, 0}, {-1, 1}, {0, 1}, {1, 1}}) do
		deco(P(f, "FarWater", Vector3.new(1600, 8, 1600), CFrame.new(xz[1] * 1600, -5.2, xz[2] * 1600), WATER))
	end
	local n = tiles(f, Vector3.zero, MapBuilder.ISLAND_RADIUS)
	for _, island in ipairs(ISLANDS) do
		n += tiles(f, polar(ISLAND_CENTRE, island.angle), island.r)
	end
	-- an invisible ring so nobody walks off the edge of the world
	local wallLen = 2 * BOUNDARY * math.tan(math.rad(7.5)) + 2
	for k = 1, 24 do
		local p = polar(BOUNDARY, (k - 0.5) * 15) + Vector3.new(0, 150, 0)
		P(f, "Boundary", Vector3.new(wallLen, 320, 4), CFrame.lookAt(p, Vector3.new(0, 150, 0)), STONE, nil, {Transparency = 1, CanTouch = false, CanQuery = false})
	end
	return "ground tiles: " .. n
end

--------------------------------------------------------------------------- plots

-- one plot shell in its own frame (local origin = the plot's centre line; front toward local -Z)
local function plotShell(parent, i)
	local frame = ringCF(MapBuilder.RING_RADIUS, plotAngle(i))
	local m = Instance.new("Model")
	m.Name = "Plot" .. i
	m:SetAttribute("Frame", frame)
	local function L(x, y, z) return frame * CFrame.new(x, y, z) end

	studs(P(m, "Floor", Vector3.new(96, 2, 116), L(0, 1, -4), PLOT_BLUE), 4)
	studs(P(m, "Carpet", Vector3.new(12, 0.2, 128), L(0, 2.1, -10), CARPET_PINK, Enum.Material.Fabric), 4)
	for _, x in ipairs({-6.4, 6.4}) do -- gold edging along the carpet
		deco(P(m, "CarpetTrim", Vector3.new(0.8, 0.25, 128), L(x, 2.12, -10), Color3.fromRGB(255, 200, 70)))
	end
	-- low block wall with a lighter cap; a gap at the front for the gate
	local function wall(name, size, cf)
		studs(P(m, name, size, cf, STONE), 2)
		deco(P(m, name .. "Cap", Vector3.new(size.X + 0.4, 0.5, size.Z + 0.4), cf * CFrame.new(0, size.Y / 2 + 0.25, 0), STONE_LIGHT))
	end
	wall("WallLeft", Vector3.new(2, 3, 118), L(-49, 1.5, -4))
	wall("WallRight", Vector3.new(2, 3, 118), L(49, 1.5, -4))
	wall("WallBack", Vector3.new(96, 3, 2), L(0, 1.5, 55))
	wall("WallFrontL", Vector3.new(41, 3, 2), L(-29.5, 1.5, -63))
	wall("WallFrontR", Vector3.new(41, 3, 2), L(29.5, 1.5, -63))
	-- block pillars along the wall
	for _, xz in ipairs({{-49, -63}, {49, -63}, {-49, -34}, {49, -34}, {-49, -5}, {49, -5}, {-49, 24}, {49, 24}, {-49, 55}, {49, 55}}) do
		studs(deco(P(m, "StonePillar", Vector3.new(3.4, 7, 3.4), L(xz[1], 3.5, xz[2]), STONE_LIGHT)), 2)
	end
	-- a landing and ramp up to the gate
	studs(P(m, "EntryLanding", Vector3.new(20, 2, 12), L(0, 1, -68), STONE_LIGHT), 4)
	local rampLow, rampHigh = L(0, 0, -84).Position, L(0, 2, -74).Position
	local rampLen = (rampHigh - rampLow).Magnitude
	studs(P(m, "EntryRamp", Vector3.new(16, 1, rampLen), CFrame.lookAt(rampLow, rampHigh) * CFrame.new(0, -0.5, -rampLen / 2), STONE_LIGHT), 4)
	-- the gate: two block towers and a crossbeam, with the owner's name above
	for _, x in ipairs({-9, 9}) do
		studs(deco(P(m, "GateTower", Vector3.new(4, 14, 4), L(x, 9, -63), STONE)), 2)
		studs(deco(P(m, "GateTop", Vector3.new(5, 1.2, 5), L(x, 16.6, -63), STONE_LIGHT)), 2)
	end
	studs(deco(P(m, "GateBeam", Vector3.new(14, 2, 3), L(0, 15, -63), STONE)), 2)
	local sign = deco(P(m, "OwnerSign", Vector3.new(14, 2.6, 0.5), L(0, 17.6, -63), WOOD, Enum.Material.WoodPlanks))
	label(sign, Enum.NormalId.Front, "Free plot", Color3.fromRGB(120, 255, 140))
	-- lamps along the carpet
	for _, z in ipairs({-52, -22, 8, 38}) do
		for _, x in ipairs({-8.5, 8.5}) do lamp(m, L(x, 2, z) * CFrame.Angles(0, if x > 0 then math.pi else 0, 0), 9) end
	end
	-- where the owner arrives: just inside the gate, facing their bedrooms
	local spawn = P(m, "SpawnPoint", Vector3.new(4, 1, 4), L(0, 2.6, -56) * CFrame.Angles(0, math.pi, 0), Color3.new(1, 1, 1), nil, {Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false})
	spawn.CFrame = CFrame.lookAt(spawn.Position, (L(0, 2.6, 0)).Position)
	local contents = Instance.new("Folder") contents.Name = "Contents" contents.Parent = m
	m.WorldPivot = frame
	m.Parent = parent
	return m
end

function MapBuilder.plots()
	local f = folder("Plots")
	for i = 1, MapBuilder.PLOT_COUNT do
		plotShell(f, i)
		task.wait()
	end
	return "plots: " .. #f:GetChildren()
end

--------------------------------------------------------------------------- hub

function MapBuilder.hub()
	local f = folder("Hub")
	local R = MapBuilder.PLAZA_RADIUS
	-- plaza of checker stone tiles
	local T = 12
	for ix = -5, 4 do
		for iz = -5, 4 do
			local pos = Vector3.new((ix + 0.5) * T, 0.2, (iz + 0.5) * T)
			if Vector3.new(pos.X, 0, pos.Z).Magnitude <= R + 6 then
				studs(P(f, "Plaza", Vector3.new(T, 0.4, T), CFrame.new(pos), if (ix + iz) % 2 == 0 then PLAZA_A else PLAZA_B), 4, true)
			end
		end
	end

	-- egg shrine in the middle: stepped blocks and a big egg, with the odds board facing the main approach
	studs(P(f, "DaisStep", Vector3.new(26, 1, 26), CFrame.new(0, 0.9, 0), STONE_LIGHT), 4)
	studs(P(f, "Dais", Vector3.new(19, 1.4, 19), CFrame.new(0, 2.1, 0), STONE), 4)
	studs(P(f, "EggShrine", Vector3.new(10, 3, 10), CFrame.new(0, 4.3, 0), STONE_LIGHT), 2)
	for _, xz in ipairs({{-7.5, -7.5}, {7.5, -7.5}, {-7.5, 7.5}, {7.5, 7.5}}) do
		studs(deco(P(f, "ShrinePost", Vector3.new(1.6, 6, 1.6), CFrame.new(xz[1], 5.8, xz[2]), STONE)), 2)
		local g = deco(P(f, "LampGlow", Vector3.new(1.1, 1.1, 1.1), CFrame.new(xz[1], 9.3, xz[2]), LANTERN, Enum.Material.Neon))
		local l = Instance.new("PointLight") l.Color = LANTERN l.Range = 18 l.Brightness = 0.8 l.Shadows = false l.Parent = g
	end
	local eggPart = P(f, "Egg", Vector3.new(6, 8, 6), CFrame.new(0, 9.8, 0), Color3.fromRGB(130, 220, 200), Enum.Material.SmoothPlastic)
	local shape = Instance.new("SpecialMesh") shape.MeshType = Enum.MeshType.Sphere shape.Parent = eggPart
	local pp = Instance.new("ProximityPrompt") pp.Name = "HatchPrompt" pp.ActionText = "Open Eggs" pp.ObjectText = "Egg Shrine" pp.HoldDuration = 0.3 pp.MaxActivationDistance = 14 pp.RequiresLineOfSight = false pp.Parent = eggPart
	local bb = Instance.new("BillboardGui") bb.Size = UDim2.fromScale(12, 2.4) bb.StudsOffset = Vector3.new(0, 5.5, 0) bb.MaxDistance = 120 bb.Parent = eggPart
	local t = Instance.new("TextLabel") t.Name = "Text" t.Size = UDim2.fromScale(1, 1) t.BackgroundTransparency = 1 t.Font = Enum.Font.FredokaOne t.TextScaled = true
	t.TextColor3 = Color3.fromRGB(255, 220, 80) t.Text = "Egg Shrine" t.Parent = bb stroke(t, 4)
	local glow = Instance.new("PointLight") glow.Color = Color3.fromRGB(130, 255, 220) glow.Range = 22 glow.Brightness = 1.5 glow.Parent = eggPart
	local board = P(f, "EggOdds", Vector3.new(7, 8, 0.5), CFrame.new(0, 5.2, -17), WOOD, Enum.Material.WoodPlanks)
	board.CFrame = CFrame.lookAt(board.Position, Vector3.new(0, board.Position.Y, -60))
	label(board, Enum.NormalId.Front, "Odds", Color3.new(1, 1, 1))
	for _, x in ipairs({-3.2, 3.2}) do deco(P(f, "OddsPost", Vector3.new(0.5, 9, 0.5), board.CFrame * CFrame.new(x, -0.5, 0.3), IRON)) end

	-- lamps at each path's mouth, with twisty trees between
	for k = 1, MapBuilder.PLOT_COUNT do
		local a = plotAngle(k)
		for _, off in ipairs({-11, 11}) do lamp(f, ringCF(R + 8, a) * CFrame.new(off, 0, 0), 11) end
		if k % 2 == 0 then deadTree(f, ringCF(R + 6, a + 11), 16) end
	end

	-- the spawn is only used before a player's plot is assigned (a moment after joining)
	local sp = workspace:FindFirstChildOfClass("SpawnLocation")
	if sp then
		sp.CFrame = CFrame.new(0, 1.2, -24) sp.Size = Vector3.new(6, 1, 6)
		sp.Transparency = 1 sp.CanCollide = false
	end
	return "hub built: " .. #f:GetDescendants() .. " instances"
end

--------------------------------------------------------------------------- stations

-- the hub's four buildings, from parts, on the plaza between the paths. Each keeps the prompt its panel opens from.
function MapBuilder.stations()
	local f = folder("Stations")
	local R = MapBuilder.PLAZA_RADIUS
	local WALL_A = Color3.fromRGB(96, 84, 124)
	local old = workspace.Hub:FindFirstChild("ShopStall") if old then old:Destroy() end
	local oldSign = workspace.Hub:FindFirstChild("ShopSign") if oldSign then oldSign:Destroy() end

	-- the shop
	local shopCF = ringCF(R - 14, 22.5, 0.4)
	local shop, shopSign = building(workspace.Hub, "ShopStall", shopCF, 22, 16, 13, WALL_A, Color3.fromRGB(70, 200, 90), "Shop", Color3.fromRGB(170, 255, 170))
	shopSign.Name = "ShopSign"
	shopSign.Parent = workspace.Hub
	studs(P(shop, "Counter", Vector3.new(14, 3.2, 3), shopCF * CFrame.new(0, 1.6, -3), WOOD), 2)
	local shopSpot = P(f, "ShopClaim", Vector3.new(4, 6, 1), shopCF * CFrame.new(0, 3, -6), Color3.new(1, 1, 1), nil, {Transparency = 1, CanCollide = false, CanTouch = false})
	prompt(shopSpot, "ShopPrompt", "Open Shop", "Shop")

	-- the fusing forge
	local fuseCF = ringCF(R - 14, 202.5, 0.4)
	local forge, fuseSign = building(f, "FusionForge", fuseCF, 22, 16, 13, WALL_A, Color3.fromRGB(170, 80, 240), "Fusion Forge", Color3.fromRGB(225, 185, 255))
	fuseSign.Name = "FusingSign"
	fuseSign.Parent = f
	studs(P(forge, "Pedestal", Vector3.new(6, 2.4, 6), fuseCF * CFrame.new(0, 1.2, 1), STONE_LIGHT), 2)
	local core = deco(P(forge, "ForgeCore", Vector3.new(3, 3, 3), fuseCF * CFrame.new(0, 4.2, 1), Color3.fromRGB(190, 110, 255), Enum.Material.Neon))
	core.CFrame = core.CFrame * CFrame.Angles(0.6, 0.6, 0)
	local fuseSpot = P(f, "FuseSpot", Vector3.new(4, 6, 1), fuseCF * CFrame.new(0, 3, -6), Color3.new(1, 1, 1), nil, {Transparency = 1, CanCollide = false, CanTouch = false})
	prompt(fuseSpot, "FusePrompt", "Fuse Monsters", "Fusion Forge")

	-- the hall of rebirth
	local rebirthCF = ringCF(R - 14, 112.5, 0.4)
	local hall = building(f, "RebirthHall", rebirthCF, 22, 16, 15, WALL_A, Color3.fromRGB(70, 110, 230), "Hall of Rebirth", Color3.fromRGB(180, 220, 255))
	studs(P(hall, "RebirthBase", Vector3.new(12, 0.6, 10), rebirthCF * CFrame.new(0, 0.9, 0), STONE_LIGHT), 2)
	local pad = deco(P(f, "RebirthPad", Vector3.new(8, 0.3, 7), rebirthCF * CFrame.new(0, 1.3, 0), Color3.fromRGB(120, 170, 255), Enum.Material.Neon, {CanCollide = false}))
	prompt(pad, "RebirthPrompt", "Rebirth", "Hall of Rebirth", 12)
	local portal = deco(P(hall, "Portal", Vector3.new(9, 10, 0.6), rebirthCF * CFrame.new(0, 6, 6.6), Color3.fromRGB(120, 170, 255), Enum.Material.Neon))
	local light = Instance.new("PointLight") light.Color = portal.Color light.Range = 22 light.Brightness = 1.2 light.Shadows = false light.Parent = portal

	-- the book of frights: opens the index
	local bookCF = ringCF(R - 14, 292.5, 0.4)
	local museum = building(f, "BookOfFrights", bookCF, 22, 16, 13, WALL_A, Color3.fromRGB(30, 190, 230), "Book of Frights", Color3.fromRGB(170, 240, 255))
	studs(P(museum, "Lectern", Vector3.new(5, 3.4, 3), bookCF * CFrame.new(0, 1.7, 1), WOOD), 2)
	deco(P(museum, "Book", Vector3.new(4, 0.6, 3), bookCF * CFrame.new(0, 3.7, 1), Color3.fromRGB(235, 230, 215)))
	local bookSpot = P(f, "IndexSpot", Vector3.new(4, 6, 1), bookCF * CFrame.new(0, 3, -6), Color3.new(1, 1, 1), nil, {Transparency = 1, CanCollide = false, CanTouch = false})
	prompt(bookSpot, "IndexPrompt", "Open Index", "Book of Frights")

	-- floating ghosts over the plaza and one at each plot's gate
	for k, angle in ipairs({67, 157, 247, 337, 0}) do
		local a = math.rad(angle)
		ghostFigure(f, Vector3.new(math.sin(a) * 24, 14 + (k % 3) * 2, math.cos(a) * 24))
	end
	for i = 1, MapBuilder.PLOT_COUNT do
		local cf = ringCF(MapBuilder.RING_RADIUS, plotAngle(i))
		ghostFigure(f, (cf * CFrame.new(-18, 14, -68)).Position)
	end
	return "stations: " .. #f:GetChildren() .. " items"
end

--------------------------------------------------------------------------- paths

function MapBuilder.paths()
	local f = folder("Paths")
	local inner = MapBuilder.PLAZA_RADIUS + 4
	local outer = MapBuilder.RING_RADIUS - 83
	local function road(name, a, r0, r1, width)
		studs(P(f, name, Vector3.new(width, 0.3, r1 - r0), ringCF((r0 + r1) / 2, a, 0.15), DIRT), 4, true)
	end
	for i = 1, MapBuilder.PLOT_COUNT do
		local a = plotAngle(i)
		road("Path", a, inner, outer, 16)
		for _, r in ipairs({inner + 18, inner + 44}) do
			for _, off in ipairs({-12, 12}) do
				lamp(f, ringCF(r, a) * CFrame.new(off, 0, 0) * CFrame.Angles(0, if off > 0 then math.pi else 0, 0), 9)
			end
		end
		-- a low iron fence along each path
		local cf0, cf1 = ringCF(inner + 8, a), ringCF(outer - 4, a)
		for _, off in ipairs({-9.5, 9.5}) do
			fence(f, (cf0 * CFrame.new(off, 0, 0)).Position, (cf1 * CFrame.new(off, 0, 0)).Position, 3)
		end
		task.wait()
	end
	-- the four roads out to the islands, on the gaps between plots, with plank bridges over the water
	for _, island in ipairs(ISLANDS) do
		road("GapPath", island.angle, inner, MapBuilder.ISLAND_RADIUS, 14)
		local a = island.angle
		local from = polar(MapBuilder.ISLAND_RADIUS - 6, a)
		local to = polar(ISLAND_CENTRE - island.r + 6, a)
		local mid = (from + to) / 2 + Vector3.new(0, 0.1, 0)
		local length = (to - from).Magnitude
		local cf = CFrame.lookAt(mid, to + Vector3.new(0, 0.1, 0))
		P(f, "Bridge", Vector3.new(14, 0.8, length), cf, PLANK, Enum.Material.WoodPlanks)
		for _, s in ipairs({-1, 1}) do
			deco(P(f, "BridgeRail", Vector3.new(0.5, 0.5, length), cf * CFrame.new(s * 6.8, 3, 0), PLANK))
			for k = -2, 2 do
				deco(P(f, "BridgePost", Vector3.new(0.7, 3.5, 0.7), cf * CFrame.new(s * 6.8, 1.5, k * length / 5), PLANK))
			end
		end
		for _, r in ipairs({120, 180, 240, 280}) do
			for _, off in ipairs({-10, 10}) do
				lamp(f, ringCF(r, a) * CFrame.new(off, 0, 0) * CFrame.Angles(0, if off > 0 then math.pi else 0, 0), 9)
			end
		end
	end
	return "paths: " .. #f:GetChildren()
end

--------------------------------------------------------------------------- scenery and islands

function MapBuilder.scenery()
	local f = folder("Scenery")
	local rng = Random.new(MapBuilder.SEED)
	local R = MapBuilder.ISLAND_RADIUS
	local function clear(p)
		local r = p.Magnitude
		local a = math.deg(math.atan2(p.X, p.Z)) % 360
		-- plots fill a band around each 45 degree line, and paths run along them on the way in
		local offPlot = math.abs(((a + 22.5) % 45) - 22.5)
		local sideways = r * math.sin(math.rad(offPlot))
		if r > 118 and sideways < 62 then return false end
		if sideways < 16 then return false end
		-- the island roads
		local offRoad = math.abs(((a - 22.5 + 45) % 90) - 45)
		return r * math.sin(math.rad(offRoad)) > 12
	end
	local placed, tries = 0, 0
	while placed < 90 and tries < 2000 do
		tries += 1
		local p = polar(rng:NextNumber(70, R - 8), rng:NextNumber(0, 360))
		if clear(p) then
			local cf = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
			local pick = placed % 9
			if pick <= 2 then deadTree(f, cf, rng:NextNumber(18, 30))
			elseif pick <= 4 then leafTree(f, cf, rng:NextNumber(16, 24))
			elseif pick == 5 then rocks(f, cf, rng:NextNumber(4, 7))
			elseif pick == 6 then mushrooms(f, cf)
			elseif pick == 7 then root(f, cf)
			else rocks(f, cf, rng:NextNumber(3, 5)) end
			placed += 1
			if placed % 20 == 0 then task.wait() end
		end
	end
	-- docks and reeds on the shore
	for k = 1, 16 do
		local a = k * 22.5 + 8
		local onShore = CFrame.new(polar(R - 2, a)) * CFrame.Angles(0, math.rad(a), 0)
		if k % 4 == 0 then
			local dock = group(f, "Dock")
			studs(deco(P(dock, "Deck", Vector3.new(10, 0.6, 18), onShore * CFrame.new(0, -0.2, 8), PLANK, Enum.Material.WoodPlanks)), 2)
			for _, s in ipairs({-1, 1}) do
				deco(P(dock, "Stake", Vector3.new(0.9, 4, 0.9), onShore * CFrame.new(s * 4.6, -0.5, 15), IRON))
			end
		else
			reeds(f, onShore * CFrame.new(0, -0.3, 2))
		end
	end
	return "scenery: " .. placed
end

function MapBuilder.islands()
	local f = folder("World")
	local rng = Random.new(MapBuilder.SEED + 1)
	local function at(island, r, a)
		return polar(ISLAND_CENTRE, island.angle) + polar(r, a)
	end
	local function clearOfRoad(island, p)
		local inward = polar(1, island.angle)
		local offset = p - polar(ISLAND_CENTRE, island.angle)
		local along = offset:Dot(inward)
		local across = (offset - inward * along).Magnitude
		return not (along < 0 and across < 14)
	end
	for _, island in ipairs(ISLANDS) do
		local c = polar(ISLAND_CENTRE, island.angle)
		local look = CFrame.lookAt(c, Vector3.zero)
		-- local +Z now points away from the hub, so buildings at the far side open toward the bridge
		if island.name == "Graveyard" then
			-- a modest graveyard inside an iron fence, and a block crypt
			for row = -1, 1 do
				for col = -2, 2 do
					if col ~= 0 then grave(f, look * CFrame.new(col * 11, 0, row * 13 + 6) * CFrame.Angles(0, rng:NextNumber(-0.1, 0.1), 0), rng:NextNumber(-0.12, 0.12)) end
				end
			end
			building(f, "Crypt", look * CFrame.new(0, 0, 44), 24, 18, 14, ROCK_DARK, ROCK, "Crypt", Color3.fromRGB(235, 230, 245))
			local c1, c2, c3, c4 = look * CFrame.new(-44, 0, -28), look * CFrame.new(44, 0, -28), look * CFrame.new(44, 0, 60), look * CFrame.new(-44, 0, 60)
			fence(f, c1.Position, (look * CFrame.new(-10, 0, -28)).Position, 5)
			fence(f, (look * CFrame.new(10, 0, -28)).Position, c2.Position, 5)
			fence(f, c2.Position, c3.Position, 5)
			fence(f, c3.Position, c4.Position, 5)
			fence(f, c4.Position, c1.Position, 5)
		elseif island.name == "Mansion" then
			-- the old mansion on a block hill, with leafy trees and murky pools
			local baseCF = look * CFrame.new(0, 0, 42)
			studs(P(f, "MansionHill", Vector3.new(66, 3, 48), baseCF * CFrame.new(0, 1.5, 0), ROCK), 4)
			local house = building(f, "Mansion", baseCF * CFrame.new(0, 3, 0), 46, 30, 22, Color3.fromRGB(110, 92, 132), Color3.fromRGB(78, 62, 104), "Old Mansion", Color3.fromRGB(215, 200, 240))
			for _, s in ipairs({-1, 1}) do
				local towerCF = baseCF * CFrame.new(s * 26, 3, -4)
				studs(deco(P(house, "Tower", Vector3.new(11, 32, 11), towerCF * CFrame.new(0, 16, 0), Color3.fromRGB(96, 80, 118))), 2)
				for k = 0, 2 do
					studs(deco(P(house, "TowerRoof", Vector3.new(13 - k * 4, 2, 13 - k * 4), towerCF * CFrame.new(0, 33 + k * 2, 0), Color3.fromRGB(70, 56, 96))), 2)
				end
				local window = deco(P(house, "TowerWindow", Vector3.new(3, 4.5, 0.4), towerCF * CFrame.new(0, 24, -5.7), Color3.fromRGB(255, 235, 150), Enum.Material.Neon))
				window.CastShadow = false
			end
			for k = 1, 5 do
				local p = at(island, rng:NextNumber(55, 90), k * 72 + 10)
				if clearOfRoad(island, p) then
					deco(P(f, "Pool", Vector3.new(rng:NextNumber(16, 26), 0.3, rng:NextNumber(16, 26)), CFrame.new(p + Vector3.new(0, 0.1, 0)), Color3.fromRGB(70, 170, 150)))
					reeds(f, CFrame.new(p + Vector3.new(6, 0.2, 5)))
				end
				leafTree(f, CFrame.new(at(island, rng:NextNumber(60, 98), k * 72 + 46)), rng:NextNumber(20, 30))
			end
		elseif island.name == "DarkWoods" then
			for k = 1, 26 do
				local p = at(island, rng:NextNumber(14, 100), rng:NextNumber(0, 360))
				if clearOfRoad(island, p) then deadTree(f, CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), rng:NextNumber(24, 40)) end
			end
			for k = 1, 6 do root(f, CFrame.new(at(island, rng:NextNumber(20, 80), k * 60)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)) end
			for k = 1, 5 do mushrooms(f, CFrame.new(at(island, rng:NextNumber(20, 90), k * 72 + 12))) end
		else
			-- broken walls and a tilting clock tower
			local tower = group(f, "ClockTower")
			local base = look * CFrame.new(0, 0, 30)
			studs(deco(P(tower, "Base", Vector3.new(18, 4, 18), base * CFrame.new(0, 2, 0), ROCK)), 4)
			local lean = base * CFrame.new(0, 4, 0) * CFrame.Angles(0.08, 0, -0.05)
			studs(P(tower, "Shaft", Vector3.new(12, 40, 12), lean * CFrame.new(0, 20, 0), ROCK_DARK), 4)
			studs(deco(P(tower, "Crown", Vector3.new(14, 3, 14), lean * CFrame.new(0, 41.5, 0), ROCK)), 4)
			local face = deco(P(tower, "ClockFace", Vector3.new(7, 7, 0.4), lean * CFrame.new(0, 34, -6.2), Color3.fromRGB(245, 240, 215), Enum.Material.Neon))
			deco(P(tower, "ClockHand", Vector3.new(0.5, 3.2, 0.3), face.CFrame * CFrame.new(0, 1.4, -0.3), IRON))
			deco(P(tower, "ClockHand", Vector3.new(2.6, 0.5, 0.3), face.CFrame * CFrame.new(1.2, 0, -0.3), IRON))
			for k = 1, 7 do
				local p = at(island, rng:NextNumber(40, 90), k * 51)
				if clearOfRoad(island, p) then
					local cf = CFrame.lookAt(p, c)
					local h = rng:NextNumber(6, 14)
					studs(deco(P(f, "RuinWall", Vector3.new(rng:NextNumber(12, 22), h, 2.4), cf * CFrame.new(0, h / 2, 0), ROCK)), 2)
					rocks(f, cf * CFrame.new(rng:NextNumber(-8, 8), 0, 5), rng:NextNumber(3, 5))
				end
			end
		end
		-- a few things on every island's edge
		for k = 1, 8 do
			local p = at(island, island.r - 8, k * 45 + 12)
			if clearOfRoad(island, p) then
				if k % 2 == 0 then deadTree(f, CFrame.new(p), rng:NextNumber(18, 26)) else rocks(f, CFrame.new(p), rng:NextNumber(4, 6)) end
			end
		end
		-- ghosts drifting over each island
		for k = 1, 3 do
			ghostFigure(f, at(island, rng:NextNumber(20, 70), k * 120) + Vector3.new(0, rng:NextNumber(10, 18), 0))
		end
		task.wait()
	end
	return "islands: " .. #f:GetChildren() .. " items"
end

--------------------------------------------------------------------------- tracker dig spots

-- invisible spots trackers can pick, on open ground on the islands. Only the server uses them; each player sees their own mound.
function MapBuilder.digNodes()
	local f = folder("DigNodes")
	local n = 0
	for _, island in ipairs(ISLANDS) do
		local c = polar(ISLAND_CENTRE, island.angle)
		local look = CFrame.lookAt(c, Vector3.zero)
		-- on the near half of each island, clear of the big buildings at the far side
		for _, xz in ipairs({{-70, -30}, {70, -30}, {-48, -68}, {48, -68}, {-85, 10}}) do
			n += 1
			local spot = P(f, "Dig" .. n, Vector3.new(2, 1, 2), look * CFrame.new(xz[1], 0.5, xz[2]), Color3.new(1, 1, 1), nil, {Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false})
			-- the egg mound has to fit: scattered trees give way to a dig spot
			for _, part in ipairs(workspace:GetPartBoundsInRadius(spot.Position, 8)) do
				local model = part:FindFirstAncestorOfClass("Model")
				if model and model.Name:find("Tree$") then model:Destroy() end
			end
		end
	end
	return "dig spots: " .. n
end

--------------------------------------------------------------------------- bedroom exteriors (on the template)

-- Dresses the outside of every bedroom in ServerStorage.PlotTemplate in bricks: studded walls, corner blocks, a framed window
-- with shutters, a framed crawl hole, a cold lamp, a tier sign and a stepped block roof with a chimney.
-- Everything goes in the bedroom's "Exterior" model, so the interior styles never touch it.
local BRICK = {
	Color3.fromRGB(170, 146, 200), Color3.fromRGB(130, 170, 210), Color3.fromRGB(130, 190, 160),
	Color3.fromRGB(205, 170, 130), Color3.fromRGB(160, 136, 196), Color3.fromRGB(205, 146, 160),
}
local ROOF = {
	Color3.fromRGB(96, 72, 140), Color3.fromRGB(60, 92, 150), Color3.fromRGB(56, 118, 98),
	Color3.fromRGB(140, 92, 66), Color3.fromRGB(90, 70, 136), Color3.fromRGB(140, 72, 92),
}
local TRIM = Color3.fromRGB(240, 238, 230)

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
		local brick = BRICK[(idx - 1) % #BRICK + 1]
		local roofColor = ROOF[(idx - 1) % #ROOF + 1]
		local function wallPart(name, size, cf)
			return studs(deco(P(ex, name, size, cf, brick)), 2)
		end
		local outFront = s * (front - 0.5 - 0.07) -- just outside the front wall's aisle-facing face
		for _, n in ipairs({"FrontLow", "FrontHigh", "FrontLeft", "FrontRight"}) do
			local w = b[n]
			wallPart("Wall" .. n, Vector3.new(0.12, w.Size.Y, w.Size.Z), CFrame.new(outFront, w.Position.Y, w.Position.Z))
		end
		for _, sgn in ipairs({-1, 1}) do
			wallPart("WallSide", Vector3.new(depth + 1.2, H, 0.12), CFrame.new(cx, y0 + H / 2, zc + sgn * (half + 0.57)))
		end
		wallPart("WallBack", Vector3.new(0.12, H, half * 2 + 1.2), CFrame.new(s * (back + 0.57), y0 + H / 2, zc))
		-- corner blocks and a plinth all round
		for _, xx in ipairs({front - 0.4, back + 0.4}) do
			for _, sgn in ipairs({-1, 1}) do
				deco(P(ex, "CornerBlock", Vector3.new(1.1, H + 0.2, 1.1), CFrame.new(s * xx, y0 + H / 2, zc + sgn * (half + 0.45)), TRIM))
			end
		end
		studs(deco(P(ex, "PlinthFront", Vector3.new(0.5, 1.2, half * 2 + 1.4), CFrame.new(s * (front - 0.75), y0 + 0.6, zc), STONE)), 2)
		studs(deco(P(ex, "PlinthBack", Vector3.new(0.5, 1.2, half * 2 + 1.4), CFrame.new(s * (back + 0.75), y0 + 0.6, zc), STONE)), 2)
		for _, sgn in ipairs({-1, 1}) do
			studs(deco(P(ex, "PlinthSide", Vector3.new(depth + 1.6, 1.2, 0.5), CFrame.new(cx, y0 + 0.6, zc + sgn * (half + 0.75)), STONE)), 2)
		end

		-- window: white frame, shutters either side, a sill
		local win = b.Window
		local wz, wy = win.Position.Z, win.Position.Y
		local ww, wh = win.Size.Z, win.Size.Y
		local fx = s * (front - 0.8)
		deco(P(ex, "WindowTop", Vector3.new(0.6, 0.8, ww + 1.6), CFrame.new(fx, wy + wh / 2 + 0.4, wz), TRIM))
		deco(P(ex, "WindowSill", Vector3.new(0.9, 0.5, ww + 1.6), CFrame.new(s * (front - 0.95), wy - wh / 2 - 0.25, wz), TRIM))
		for _, sgn in ipairs({-1, 1}) do
			deco(P(ex, "WindowSide", Vector3.new(0.6, wh + 0.8, 0.8), CFrame.new(fx, wy, wz + sgn * (ww / 2 + 0.4)), TRIM))
			studs(deco(P(ex, "Shutter", Vector3.new(0.35, wh - 0.4, 2), CFrame.new(s * (front - 0.75), wy, wz + sgn * (ww / 2 + 1.8)), roofColor)), 2)
		end

		-- crawl hole: deeper so it shows over the brick, with a block frame
		local hole = b.CrawlHole
		hole.Size = Vector3.new(1.7, hole.Size.Y, hole.Size.Z)
		local hw = hole.Size.Z
		local top = hole.Position.Y + hole.Size.Y / 2
		for _, sgn in ipairs({-1, 1}) do
			deco(P(ex, "HolePost", Vector3.new(1.55, hole.Size.Y + 0.6, 0.7), CFrame.new(hole.Position.X, hole.Position.Y + 0.3, hole.Position.Z + sgn * (hw / 2 + 0.35)), WOOD))
		end
		deco(P(ex, "HoleBeam", Vector3.new(1.55, 0.8, hw + 1.4), CFrame.new(hole.Position.X, top + 0.4, hole.Position.Z), WOOD))

		-- a cold wall lamp above the display case
		local lampPos = Vector3.new(s * (front - 1), y0 + 12.2, zc + L * 9)
		deco(P(ex, "LampBracket", Vector3.new(1.2, 0.3, 0.3), CFrame.new(lampPos - Vector3.new(-s * 0.2, 0.8, 0)), IRON))
		local glow = deco(P(ex, "LampGlow", Vector3.new(0.9, 1.1, 0.9), CFrame.new(lampPos), LANTERN, Enum.Material.Neon))
		local light = Instance.new("PointLight") light.Color = LANTERN light.Range = 12 light.Brightness = 0.8 light.Shadows = false light.Parent = glow

		-- the tier sign is a wooden board under the eaves
		local sign = b.TierSign
		sign.Size = Vector3.new(0.5, 2.4, 11)
		sign.CFrame = CFrame.new(s * (front - 0.85), y0 + H - 1.35, zc + L * 2)
		sign.Color = WOOD
		sign.Material = Enum.Material.WoodPlanks

		-- the locked cover: boarded up planks
		b.Lock.Material = Enum.Material.WoodPlanks
		b.Lock.Color = Color3.fromRGB(130, 90, 60)

		-- a stepped block roof; the flat lid stays for collisions
		b.Roof.Transparency = 1
		local rw, rd = depth + 3, half * 2 + 3
		for k = 0, 3 do
			studs(deco(P(ex, "RoofStep", Vector3.new(rw - k * 6, 1.2, rd - k * 7), CFrame.new(cx, y0 + H + 0.6 + k * 1.2, zc), roofColor:Lerp(Color3.new(1, 1, 1), k * 0.05))), 4)
		end
		studs(deco(P(ex, "Chimney", Vector3.new(2.4, 7, 2.4), CFrame.new(s * (back - 6), y0 + H + 3.5, zc + L * 7), STONE)), 2)

		ex.Parent = b
		done += 1
	end
	return "exteriors on " .. done .. " bedrooms"
end

--------------------------------------------------------------------------- budget report (vault: audit after every art pass)

function MapBuilder.audit()
	local out = {}
	for _, n in ipairs({"Ground", "Hub", "Stations", "Plots", "Paths", "Scenery", "World"}) do
		local f = workspace:FindFirstChild(n)
		if f then
			local parts, meshes = 0, 0
			for _, d in ipairs(f:GetDescendants()) do
				if d:IsA("BasePart") then parts += 1 end
				if d:IsA("MeshPart") then meshes += 1 end
			end
			table.insert(out, string.format("%s: %d instances, %d parts, %d mesh parts", n, #f:GetDescendants(), parts, meshes))
		end
	end
	return table.concat(out, "\n")
end

return MapBuilder
