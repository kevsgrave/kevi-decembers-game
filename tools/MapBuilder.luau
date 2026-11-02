-- Builds the whole map in Studio (Edit mode) in the chunky brick style of the owner's references (docs/references/style):
-- bright studded checker ground, flared block trees and teal water, all from Parts. General spooky, not Halloween: twisty dead
-- trees, a few graves, ruins, a mansion, mist and ghosts. The ring of 8 plots and auto-assign are the owner's decisions.
-- Machines, ghosts and props are parts too; what moves is tagged for MapLife.client, and titles are filled by StationStatus.client.
-- Run from Studio by requiring a copy of this module and calling the steps; each clears and rebuilds only its own folder.
-- Layout data lives at the top: change a number and re-run the step.
local ServerStorage = game:GetService("ServerStorage")
local Lighting = game:GetService("Lighting")
local CollectionService = game:GetService("CollectionService")

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
	t.Font = Enum.Font.FredokaOne t.TextScaled = true t.TextWrapped = true t.Text = text t.TextColor3 = color or Color3.new(1, 1, 1) t.Parent = g
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
	{name = "Graveyard", title = "Graveyard", angle = 22.5, r = 110},
	{name = "Mansion", title = "Old Mansion", angle = 112.5, r = 110},
	{name = "DarkWoods", title = "Dark Woods", angle = 202.5, r = 110},
	{name = "Ruins", title = "Ruins", angle = 292.5, r = 110},
}
local ISLAND_CENTRE = 450
-- small islets out on the water, too far to reach: scenery for the view
local ISLETS = {67.5, 157.5, 247.5, 337.5}
local ISLET_CENTRE, ISLET_RADIUS = 440, 34
-- tracker dig spots, in each island's frame. Props stay off them.
local DIG_SPOTS = {{-70, -30}, {70, -30}, {-48, -68}, {48, -68}, {-85, 10}}
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

-- marks something for MapLife.client to animate; attrs: Spin (radians a second), Bob, BobSpeed, Pulse, Base, Phase
local function life(inst, attrs)
	inst:SetAttribute("Home", if inst:IsA("Model") then inst:GetPivot() else inst.CFrame)
	for k, v in pairs(attrs) do inst:SetAttribute(k, v) end
	CollectionService:AddTag(inst, "Life")
	return inst
end

local function ball(parent, name, d, cf, color, mat)
	return deco(P(parent, name, Vector3.new(d, d, d), cf, color, mat, {Shape = Enum.PartType.Ball, CanCollide = false}))
end

-- a stretched sphere, for eyes, eggs and cheeks
local function oval(parent, name, size, cf, color, mat)
	local p = deco(P(parent, name, size, cf, color, mat, {CanCollide = false}))
	local shape = Instance.new("SpecialMesh") shape.MeshType = Enum.MeshType.Sphere shape.Parent = p
	return p
end

-- a straight bar between two points, for pipes, cables, chains and branches
local function beam(parent, name, a, b, thick, color, mat)
	return deco(P(parent, name, Vector3.new(thick, thick, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, mat, {CanCollide = false}))
end

-- a curved pipe in a frame's XY plane, from angle a0 to a1 in degrees
local function arc(parent, name, cf, cx, cy, z, r, a0, a1, n, thick, color)
	local function at(a)
		return (cf * CFrame.new(cx + math.cos(math.rad(a)) * r, cy + math.sin(math.rad(a)) * r, z)).Position
	end
	for k = 1, n do
		local from, to = at(a0 + (a1 - a0) * (k - 1) / n), at(a0 + (a1 - a0) * k / n)
		local mid = (from + to) / 2
		local look = (to - from).Unit
		beam(parent, name, mid - look * ((to - from).Magnitude / 2 + thick / 4), mid + look * ((to - from).Magnitude / 2 + thick / 4), thick, color)
	end
end

-- a floating title with a bright gradient and a live line under it, as on the owner's fuse machine reference.
-- StationStatus.client fills in the live line.
local function title(part, text, top, bottom, station, firstLine, width, offset, guiName)
	local w = width or 22
	local bb = Instance.new("BillboardGui") bb.Name = guiName or "Title" bb.Size = UDim2.fromScale(w, w * 0.3) bb.StudsOffset = Vector3.new(0, offset or 0, 0)
	bb.MaxDistance = 170 bb.LightInfluence = 0 bb.Parent = part
	local t = Instance.new("TextLabel") t.Name = "Text" t.Size = UDim2.fromScale(1, 0.62) t.BackgroundTransparency = 1 t.Font = Enum.Font.FredokaOne
	t.TextScaled = true t.Text = text t.TextColor3 = Color3.new(1, 1, 1) t.Parent = bb
	stroke(t, 4)
	local g = Instance.new("UIGradient") g.Rotation = 90 g.Color = ColorSequence.new(top, bottom) g.Parent = t
	local status = Instance.new("TextLabel") status.Name = "Status" status.Position = UDim2.fromScale(0, 0.62) status.Size = UDim2.fromScale(1, 0.38)
	status.BackgroundTransparency = 1 status.Font = Enum.Font.FredokaOne status.TextScaled = true status.Text = firstLine or "" status.TextColor3 = Color3.new(1, 1, 1) status.Parent = bb
	stroke(status, 3)
	if station then
		status:SetAttribute("Station", station)
		CollectionService:AddTag(status, "StationStatus")
	end
	return bb
end

-- the ghosts: all original, built from parts, with a face you can read from a distance
local GHOSTS = {
	boo = {body = Color3.fromRGB(245, 250, 255), mouth = "smile", arms = "up"},
	wisp = {body = Color3.fromRGB(190, 240, 255), mouth = "o", size = 0.75, flame = true},
	sleepy = {body = Color3.fromRGB(216, 206, 255), eyes = "shut", mouth = "small", nightcap = true},
	grump = {body = Color3.fromRGB(192, 250, 216), brows = true, mouth = "tongue"},
	shy = {body = Color3.fromRGB(255, 226, 240), mouth = "small", arms = "cheeks", blush = 1.4},
	shopkeeper = {body = Color3.fromRGB(245, 250, 255), mouth = "smile", apron = Color3.fromRGB(70, 200, 90)},
	mechanic = {body = Color3.fromRGB(205, 232, 255), mouth = "smile", goggles = true},
	librarian = {body = Color3.fromRGB(235, 225, 255), mouth = "small", glasses = true},
	keeper = {body = Color3.fromRGB(255, 225, 250), mouth = "o", halo = true},
	digger = {body = Color3.fromRGB(245, 240, 220), mouth = "tongue", apron = Color3.fromRGB(160, 110, 70)},
	stone = {body = ROCK, eyes = "shut", mouth = "small", still = true},
}
local GHOST_ROTATION = {"boo", "wisp", "sleepy", "grump", "shy"}
local ghostCount = 0

-- `at` is a position (the ghost faces the hub) or a CFrame; `drift` is how far it wanders from there
local function ghostFigure(parent, at, kind, drift)
	ghostCount += 1
	local look = GHOSTS[kind or GHOST_ROTATION[ghostCount % #GHOST_ROTATION + 1]]
	local s = look.size or 1
	local cf = if typeof(at) == "CFrame" then at else CFrame.lookAt(at, Vector3.new(0, at.Y, 0))
	local m = Instance.new("Model") m.Name = "Ghost"
	local INK = Color3.fromRGB(28, 18, 50)
	local function L(x, y, z) return cf * CFrame.new(x * s, y * s, z * s) end
	local function face(x, y) return -math.sqrt(math.max(0, 6.25 - x * x - y * y)) end -- the head's surface in front
	local function onFace(x, y, lift) return cf * CFrame.new(x * s, y * s, (face(x, y) - (lift or 0)) * s) end

	local head = ball(m, "Head", 5 * s, L(0, 0, 0), look.body)
	deco(P(m, "Body", Vector3.new(4 * s, 5 * s, 5 * s), L(0, -2, 0) * CFrame.Angles(0, 0, math.pi / 2), look.body, nil, {Shape = Enum.PartType.Cylinder, CanCollide = false}))
	for k = 1, 6 do -- the wavy hem
		local a = math.rad(k * 60)
		ball(m, "Hem", 2.1 * s, L(math.cos(a) * 1.75, -4 - (k % 2) * 0.35, math.sin(a) * 1.75), look.body)
	end
	-- arms
	for _, side in ipairs({-1, 1}) do
		local y, x, z = -1.5, 2.8, -0.6
		if look.arms == "up" then y, x = 0.4, 3.1 end
		if look.arms == "cheeks" then y, x, z = -0.9, 1.9, -2.2 end
		ball(m, "Arm", 1.6 * s, L(side * x, y, z), look.body)
	end
	-- the face
	for _, side in ipairs({-1, 1}) do
		if look.eyes == "shut" then
			deco(P(m, "ShutEye", Vector3.new(1 * s, 0.22 * s, 0.2 * s), onFace(side * 0.9, 0.35, 0.02), INK, nil, {CanCollide = false}))
		else
			oval(m, "Eye", Vector3.new(0.95 * s, 1.35 * s, 0.4 * s), onFace(side * 0.9, 0.35), INK)
			ball(m, "Glint", 0.36 * s, onFace(side * 0.9 + 0.17, 0.72, 0.17), Color3.new(1, 1, 1))
			deco(P(m, "Lid", Vector3.new(1.05 * s, 0.22 * s, 0.2 * s), onFace(side * 0.9, 0.35, 0.1), INK, nil, {CanCollide = false, Transparency = 1}))
		end
		local blush = (look.blush or 1) * s
		oval(m, "Cheek", Vector3.new(0.95 * blush, 0.55 * blush, 0.2 * s), onFace(side * 1.55, -0.45, -0.02), Color3.fromRGB(255, 150, 185))
		if look.brows then
			deco(P(m, "Brow", Vector3.new(1.1 * s, 0.26 * s, 0.25 * s), onFace(side * 0.9, 1.2, 0.05) * CFrame.Angles(0, 0, side * 0.45), INK, nil, {CanCollide = false}))
		end
	end
	if look.mouth == "smile" or look.mouth == "tongue" then
		for _, b in ipairs({{-0.42, -0.72, -0.5}, {0, -0.9, 0}, {0.42, -0.72, 0.5}}) do
			deco(P(m, "Mouth", Vector3.new(0.68 * s, 0.28 * s, 0.25 * s), onFace(b[1], b[2], 0.03) * CFrame.Angles(0, 0, b[3]), INK, nil, {CanCollide = false}))
		end
		if look.mouth == "tongue" then oval(m, "Tongue", Vector3.new(0.6 * s, 0.75 * s, 0.2 * s), onFace(0.1, -1.2, 0.02), Color3.fromRGB(255, 110, 140)) end
	elseif look.mouth == "o" then
		oval(m, "Mouth", Vector3.new(1 * s, 1.25 * s, 0.3 * s), onFace(0, -0.95, 0.2), INK)
	else
		deco(P(m, "Mouth", Vector3.new(0.85 * s, 0.26 * s, 0.25 * s), onFace(0, -0.85, 0.14), INK, nil, {CanCollide = false}))
	end
	-- what each one wears
	if look.flame then oval(m, "Flame", Vector3.new(1.3 * s, 2.2 * s, 1.3 * s), L(0, 3, 0), Color3.fromRGB(110, 240, 255), Enum.Material.Neon) end
	if look.nightcap then
		local cap = Color3.fromRGB(90, 90, 200)
		deco(P(m, "Cap", Vector3.new(4.2 * s, 1 * s, 4.2 * s), L(0, 1.9, 0), cap, nil, {CanCollide = false}))
		deco(P(m, "Cap", Vector3.new(2.6 * s, 1 * s, 2.6 * s), L(0.3, 2.8, 0) * CFrame.Angles(0, 0, -0.3), cap, nil, {CanCollide = false}))
		ball(m, "Pom", 0.9 * s, L(1.1, 3.4, 0), Color3.new(1, 1, 1))
	end
	if look.apron then
		deco(P(m, "Apron", Vector3.new(2.8 * s, 2.4 * s, 0.3 * s), L(0, -2.7, -2.45), look.apron, nil, {CanCollide = false}))
		deco(P(m, "Cap", Vector3.new(0.9 * s, 4.1 * s, 4.1 * s), L(0, 1.55, 0) * CFrame.Angles(0, 0, math.pi / 2), look.apron, nil, {Shape = Enum.PartType.Cylinder, CanCollide = false}))
		deco(P(m, "Visor", Vector3.new(3 * s, 0.25 * s, 1.5 * s), L(0, 1.3, -2.3), look.apron, nil, {CanCollide = false}))
	end
	if look.goggles then
		deco(P(m, "Strap", Vector3.new(0.5 * s, 4.5 * s, 4.5 * s), L(0, 1.35, 0) * CFrame.Angles(0, 0, math.pi / 2), INK, nil, {Shape = Enum.PartType.Cylinder, CanCollide = false}))
		for _, side in ipairs({-1, 1}) do oval(m, "Goggle", Vector3.new(1.3 * s, 1.1 * s, 0.4 * s), onFace(side * 0.9, 1.4, 0.18), Color3.fromRGB(110, 240, 255), Enum.Material.Neon) end
	end
	if look.glasses then
		for _, side in ipairs({-1, 1}) do
			oval(m, "Rim", Vector3.new(1.75 * s, 2.05 * s, 0.2 * s), onFace(side * 0.9, 0.35, 0.02), INK)
			oval(m, "Lens", Vector3.new(1.4 * s, 1.7 * s, 0.26 * s), onFace(side * 0.9, 0.35, 0.03), Color3.fromRGB(235, 250, 255))
		end
		deco(P(m, "Glasses", Vector3.new(0.5 * s, 0.16 * s, 0.14 * s), onFace(0, 0.4, 0.12), INK, nil, {CanCollide = false}))
	end
	if look.halo then
		for k = 1, 10 do
			local a = math.rad(k * 36)
			ball(m, "Halo", 0.5 * s, L(math.cos(a) * 1.8, 2.9, math.sin(a) * 1.8), Color3.fromRGB(255, 225, 90), Enum.Material.Neon)
		end
	end
	m.WorldPivot = cf
	m.Parent = parent
	if look.still then return m end
	m:SetAttribute("Home", cf)
	m:SetAttribute("Phase", ghostCount * 1.7)
	m:SetAttribute("Drift", drift or 0)
	CollectionService:AddTag(m, "Ghost")
	if (drift or 0) > 0 then -- a soft trail while it wanders
		local a0 = Instance.new("Attachment") a0.Position = Vector3.new(0, 2 * s, 0) a0.Parent = head
		local a1 = Instance.new("Attachment") a1.Position = Vector3.new(0, -2 * s, 0) a1.Parent = head
		local trail = Instance.new("Trail") trail.Attachment0 = a0 trail.Attachment1 = a1 trail.Lifetime = 0.8 trail.Color = ColorSequence.new(look.body)
		trail.Transparency = NumberSequence.new(0.55, 1) trail.LightInfluence = 0 trail.FaceCamera = true trail.Parent = head
	end
	return m
end

MapBuilder.ghostFigure = ghostFigure

-- more plants and props, so the islands don't all look alike
local function pine(parent, cf, height)
	local m = group(parent, "PineTree")
	local h = height or 26
	studs(deco(P(m, "Foot", Vector3.new(h * 0.24, h * 0.08, h * 0.24), cf * CFrame.new(0, h * 0.04, 0), TRUNK_DARK)), 2)
	studs(deco(P(m, "Trunk", Vector3.new(h * 0.13, h * 0.5, h * 0.13), cf * CFrame.new(0, h * 0.3, 0), TRUNK_DARK)), 2)
	for k = 0, 3 do
		local w = h * (0.62 - k * 0.14)
		studs(deco(P(m, "Canopy", Vector3.new(w, h * 0.15, w), cf * CFrame.new(0, h * (0.42 + k * 0.17), 0) * CFrame.Angles(0, k * 0.4, 0), Color3.fromRGB(46, 112, 100):Lerp(Color3.fromRGB(80, 150, 120), k / 4))), 4)
	end
	return m
end

local function bush(parent, cf, size, color)
	local m = group(parent, "Bush")
	local s = size or 5
	local c = color or Color3.fromRGB(86, 158, 96)
	studs(deco(P(m, "Leaves", Vector3.new(s * 1.3, s * 0.7, s), cf * CFrame.new(0, s * 0.35, 0), c)), 2)
	studs(deco(P(m, "Leaves", Vector3.new(s * 0.8, s * 0.6, s * 0.8), cf * CFrame.new(s * 0.2, s * 0.9, 0) * CFrame.Angles(0, 0.5, 0), c:Lerp(Color3.new(1, 1, 1), 0.12))), 2)
	return m
end

local function flowers(parent, cf, color)
	local m = group(parent, "Flowers")
	for k = 1, 5 do
		local base = cf * CFrame.new(math.cos(k * 2.4) * k * 0.7, 0, math.sin(k * 2.4) * k * 0.7)
		deco(P(m, "Stem", Vector3.new(0.25, 1.4, 0.25), base * CFrame.new(0, 0.7, 0), Color3.fromRGB(80, 150, 70), nil, {CanCollide = false}))
		deco(P(m, "Bloom", Vector3.new(0.9, 0.5, 0.9), base * CFrame.new(0, 1.55, 0) * CFrame.Angles(0, k, 0), color or Color3.fromRGB(190, 140, 255), nil, {CanCollide = false}))
	end
	return m
end

local function stump(parent, cf, size)
	local m = group(parent, "Stump")
	local s = size or 4
	studs(deco(P(m, "Foot", Vector3.new(s * 1.3, s * 0.3, s * 1.3), cf * CFrame.new(0, s * 0.15, 0), TRUNK_DARK)), 2)
	studs(deco(P(m, "Log", Vector3.new(s, s * 0.8, s), cf * CFrame.new(0, s * 0.6, 0), TRUNK)), 2)
	deco(P(m, "Rings", Vector3.new(s * 0.75, 0.1, s * 0.75), cf * CFrame.new(0, s, 0), Color3.fromRGB(235, 200, 150)))
	return m
end

local function log(parent, cf, length)
	local m = group(parent, "Log")
	studs(deco(P(m, "Log", Vector3.new(length or 10, 2.4, 2.4), cf * CFrame.new(0, 1.2, 0), TRUNK)), 2)
	return m
end

local function bench(parent, cf)
	local m = group(parent, "Bench")
	studs(deco(P(m, "Seat", Vector3.new(7, 0.5, 2.2), cf * CFrame.new(0, 1.8, 0), PLANK, Enum.Material.WoodPlanks)), 2)
	deco(P(m, "Back", Vector3.new(7, 1.6, 0.4), cf * CFrame.new(0, 3.2, 1), PLANK, Enum.Material.WoodPlanks))
	for _, x in ipairs({-3, 3}) do deco(P(m, "Leg", Vector3.new(0.6, 1.8, 2), cf * CFrame.new(x, 0.9, 0), IRON)) end
	return m
end

local function crate(parent, cf, size, color)
	local s = size or 3
	local m = group(parent, "Crate")
	studs(deco(P(m, "Box", Vector3.new(s, s, s), cf * CFrame.new(0, s / 2, 0), color or Color3.fromRGB(170, 120, 75))), 2)
	deco(P(m, "Band", Vector3.new(s + 0.1, s * 0.15, s + 0.1), cf * CFrame.new(0, s * 0.8, 0), WOOD))
	deco(P(m, "Band", Vector3.new(s + 0.1, s * 0.15, s + 0.1), cf * CFrame.new(0, s * 0.2, 0), WOOD))
	return m
end

local function barrel(parent, cf, height, color)
	local h = height or 4
	local m = group(parent, "Barrel")
	deco(P(m, "Staves", Vector3.new(h, h * 0.8, h * 0.8), cf * CFrame.new(0, h / 2, 0) * CFrame.Angles(0, 0, math.pi / 2), color or Color3.fromRGB(150, 96, 62), nil, {Shape = Enum.PartType.Cylinder}))
	for _, y in ipairs({0.22, 0.78}) do
		deco(P(m, "Hoop", Vector3.new(h * 0.1, h * 0.84, h * 0.84), cf * CFrame.new(0, h * y, 0) * CFrame.Angles(0, 0, math.pi / 2), IRON, nil, {Shape = Enum.PartType.Cylinder, CanCollide = false}))
	end
	return m
end

-- a wooden signpost with an arrow board, facing -Z
local function signpost(parent, cf, text, color)
	local m = group(parent, "Signpost")
	deco(P(m, "Post", Vector3.new(0.8, 9, 0.8), cf * CFrame.new(0, 4.5, 0), PLANK))
	local board = deco(P(m, "Board", Vector3.new(8, 2.2, 0.4), cf * CFrame.new(0, 7.6, -0.5), WOOD, Enum.Material.WoodPlanks, {CanCollide = false}))
	label(board, Enum.NormalId.Front, text, color or Color3.new(1, 1, 1))
	return m
end

-- a block arch with its name on it, at the end of a bridge
local function nameArch(parent, cf, text, color)
	local m = group(parent, "NameArch")
	for _, x in ipairs({-9, 9}) do
		studs(deco(P(m, "Pillar", Vector3.new(3, 12, 3), cf * CFrame.new(x, 6, 0), STONE)), 2)
		studs(deco(P(m, "PillarTop", Vector3.new(4, 1, 4), cf * CFrame.new(x, 12.5, 0), STONE_LIGHT)), 2)
		local glow = deco(P(m, "LampGlow", Vector3.new(1.4, 1.4, 1.4), cf * CFrame.new(x, 13.8, 0), LANTERN, Enum.Material.Neon, {CanCollide = false}))
		local l = Instance.new("PointLight") l.Color = LANTERN l.Range = 16 l.Brightness = 0.5 l.Shadows = false l.Parent = glow
	end
	local sign = studs(deco(P(m, "Sign", Vector3.new(19, 3.4, 1.2), cf * CFrame.new(0, 11, 0), WOOD, Enum.Material.WoodPlanks)), 2)
	label(sign, Enum.NormalId.Front, text, color)
	return m
end

-- soft mist over a patch of ground, and fireflies
local function mist(parent, cf)
	local p = deco(P(parent, "Mist", Vector3.new(1, 1, 1), cf, Color3.new(1, 1, 1), nil, {Transparency = 1, CanCollide = false}))
	local smoke = Instance.new("Smoke") smoke.Color = Color3.fromRGB(235, 245, 245) smoke.Opacity = 0.05 smoke.RiseVelocity = 0.4 smoke.Size = 22 smoke.Parent = p
	return p
end

local function fireflies(parent, cf, size)
	local p = deco(P(parent, "Fireflies", Vector3.new(size, 8, size), cf, Color3.new(1, 1, 1), nil, {Transparency = 1, CanCollide = false}))
	local e = Instance.new("ParticleEmitter") e.Shape = Enum.ParticleEmitterShape.Box e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	e.Rate = 4 e.Lifetime = NumberRange.new(3, 6) e.Speed = NumberRange.new(0.3, 1) e.SpreadAngle = Vector2.new(180, 180) e.LightEmission = 1
	e.Color = ColorSequence.new(Color3.fromRGB(190, 255, 160)) e.Size = NumberSequence.new(0.35) e.Parent = p
	return p
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
	atm.Density = 0.16 atm.Offset = 0 atm.Color = Color3.fromRGB(190, 225, 225) atm.Decay = Color3.fromRGB(150, 205, 215) atm.Glare = 0 atm.Haze = 0.6
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
	-- water right out to the horizon, a little under the play area's sheet so the two never flicker
	local FAR = 2040
	for ix = -3, 3 do
		for iz = -3, 3 do
			local part = deco(P(f, "FarWater", Vector3.new(FAR, 8, FAR), CFrame.new(ix * FAR, -5.3, iz * FAR), WATER))
			part.CastShadow = false
			part.CanCollide = false
		end
	end
	local n = tiles(f, Vector3.zero, MapBuilder.ISLAND_RADIUS)
	for _, island in ipairs(ISLANDS) do
		n += tiles(f, polar(ISLAND_CENTRE, island.angle), island.r)
	end
	for _, angle in ipairs(ISLETS) do
		n += tiles(f, polar(ISLET_CENTRE, angle), ISLET_RADIUS)
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
	-- glowing strips and lanterns on the gate, so a plot reads from across the map
	for _, x in ipairs({-9, 9}) do
		deco(P(m, "GateGlow", Vector3.new(1.2, 10, 0.2), L(x, 9, -65.1), LANTERN, Enum.Material.Neon, {CanCollide = false}))
		local top = deco(P(m, "LampGlow", Vector3.new(1.8, 1.8, 1.8), L(x, 18.2, -63), LANTERN, Enum.Material.Neon, {CanCollide = false}))
		local l = Instance.new("PointLight") l.Color = LANTERN l.Range = 16 l.Brightness = 0.6 l.Shadows = false l.Parent = top
		studs(deco(P(m, "GateFoot", Vector3.new(6, 1, 6), L(x, 2.5, -63), STONE_LIGHT)), 2)
	end
	deco(P(m, "SignFrame", Vector3.new(15, 3.4, 0.4), L(0, 17.6, -62.6), IRON, nil, {CanCollide = false}))
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

	-- the egg hatchery in the middle: an incubator machine on stepped blocks, with the odds board facing the main approach
	local MACHINE = Color3.fromRGB(58, 60, 78)
	local TEAL = Color3.fromRGB(70, 225, 190)
	local hatch = group(f, "Hatchery")
	studs(P(f, "DaisStep", Vector3.new(26, 1, 26), CFrame.new(0, 0.9, 0), STONE_LIGHT), 4)
	studs(P(f, "Dais", Vector3.new(19, 1.4, 19), CFrame.new(0, 2.1, 0), MACHINE), 4)
	for a = 0, 3 do -- glowing edge on the dais, and a mini egg nest on each corner
		local turn = CFrame.Angles(0, a * math.pi / 2, 0)
		life(deco(P(hatch, "DaisGlow", Vector3.new(14, 0.3, 0.5), turn * CFrame.new(0, 2.7, -9.4), TEAL, Enum.Material.Neon)), {Pulse = 2, Phase = a})
		local corner = turn * CFrame.new(10.9, 1.4, -10.9)
		studs(deco(P(hatch, "Nest", Vector3.new(3.4, 0.8, 3.4), corner * CFrame.new(0, 0.4, 0), TRUNK)), 2)
		local eggColors = {Color3.fromRGB(255, 180, 90), Color3.fromRGB(170, 140, 255), Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 130, 190)}
		life(oval(hatch, "MiniEgg", Vector3.new(2, 2.6, 2), corner * CFrame.new(0, 2.1, 0), eggColors[a + 1]), {Bob = 0.25, BobSpeed = 2, Phase = a * 1.3})
	end
	studs(P(f, "EggShrine", Vector3.new(11, 3, 11), CFrame.new(0, 4.3, 0), Color3.fromRGB(44, 110, 170)), 2)
	deco(P(hatch, "ShrineTrim", Vector3.new(11.6, 0.6, 11.6), CFrame.new(0, 5.9, 0), MACHINE))
	for _, xz in ipairs({{-7.5, -7.5}, {7.5, -7.5}, {-7.5, 7.5}, {7.5, 7.5}}) do
		studs(deco(P(f, "ShrinePost", Vector3.new(2, 13, 2), CFrame.new(xz[1], 9.3, xz[2]), MACHINE)), 2)
		for _, face in ipairs({{0, -1.05}, {0, 1.05}}) do
			life(deco(P(hatch, "PostGlow", Vector3.new(0.7, 9, 0.2), CFrame.new(xz[1], 9.3, xz[2] + face[2]), TEAL, Enum.Material.Neon)), {Pulse = 1.5, Phase = xz[1] + xz[2]})
		end
		beam(hatch, "Pipe", Vector3.new(xz[1], 15.5, xz[2]), Vector3.new(0, 18.8, 0), 1.2, Color3.fromRGB(44, 110, 170))
		local g = deco(P(f, "LampGlow", Vector3.new(1.4, 1.4, 1.4), CFrame.new(xz[1], 16.4, xz[2]), LANTERN, Enum.Material.Neon))
		local l = Instance.new("PointLight") l.Color = LANTERN l.Range = 18 l.Brightness = 0.8 l.Shadows = false l.Parent = g
	end
	studs(deco(P(hatch, "Cap", Vector3.new(7, 1.4, 7), CFrame.new(0, 19, 0), MACHINE)), 2)
	studs(deco(P(hatch, "Cap", Vector3.new(4, 1.2, 4), CFrame.new(0, 20.3, 0), Color3.fromRGB(44, 110, 170))), 2)
	deco(P(hatch, "CapLight", Vector3.new(5, 0.3, 5), CFrame.new(0, 18.2, 0), Color3.fromRGB(190, 255, 240), Enum.Material.Neon))
	-- a ring of glowing bars turning around the egg
	local ring = group(hatch, "EggRing")
	for k = 1, 8 do
		local a = k * math.pi / 4
		deco(P(ring, "RingBar", Vector3.new(0.6, 0.6, 3.2), CFrame.new(math.cos(a) * 5, 9.6, math.sin(a) * 5) * CFrame.Angles(0, -a, 0), TEAL, Enum.Material.Neon, {CanCollide = false}))
	end
	ring.WorldPivot = CFrame.new(0, 9.6, 0)
	life(ring, {Spin = Vector3.new(0, 0.9, 0)})
	local eggPart = P(f, "Egg", Vector3.new(6, 8, 6), CFrame.new(0, 10.2, 0), Color3.fromRGB(130, 220, 200), Enum.Material.SmoothPlastic, {CanCollide = false})
	local shape = Instance.new("SpecialMesh") shape.MeshType = Enum.MeshType.Sphere shape.Parent = eggPart
	life(eggPart, {Bob = 0.5, BobSpeed = 1.4})
	local pp = Instance.new("ProximityPrompt") pp.Name = "HatchPrompt" pp.ActionText = "Open Eggs" pp.ObjectText = "Egg Hatchery" pp.HoldDuration = 0.3 pp.MaxActivationDistance = 14 pp.RequiresLineOfSight = false pp.Parent = eggPart
	title(eggPart, "Egg Hatchery", Color3.fromRGB(190, 255, 225), Color3.fromRGB(40, 210, 160), "Egg", "Hatch a monster", 24, 15, "BillboardGui")
	local glow = Instance.new("PointLight") glow.Color = Color3.fromRGB(130, 255, 220) glow.Range = 22 glow.Brightness = 1.5 glow.Parent = eggPart
	local board = P(f, "EggOdds", Vector3.new(7, 8, 0.5), CFrame.new(0, 5.2, -17), MACHINE)
	board.CFrame = CFrame.lookAt(board.Position, Vector3.new(0, board.Position.Y, -60))
	label(board, Enum.NormalId.Front, "Odds", Color3.new(1, 1, 1))
	deco(P(hatch, "OddsGlow", Vector3.new(7.4, 0.4, 0.7), board.CFrame * CFrame.new(0, 4.1, 0), TEAL, Enum.Material.Neon))
	for _, x in ipairs({-3.2, 3.2}) do deco(P(f, "OddsPost", Vector3.new(0.6, 9, 0.6), board.CFrame * CFrame.new(x, -0.5, 0.3), IRON)) end

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

-- a little toolbox for a station, working in its own frame: -Z faces the hub
local function kit(m, cf)
	local k = {}
	function k.L(x, y, z) return cf * CFrame.new(x, y, z) end
	function k.block(name, size, x, y, z, color, tile) return studs(deco(P(m, name, size, cf * CFrame.new(x, y, z), color)), tile or 2) end
	function k.trim(name, size, x, y, z, color) return deco(P(m, name, size, cf * CFrame.new(x, y, z), color, nil, {CanCollide = false})) end
	function k.glow(name, size, x, y, z, color, pulse)
		local g = deco(P(m, name, size, cf * CFrame.new(x, y, z), color, Enum.Material.Neon, {CanCollide = false}))
		if pulse then life(g, {Pulse = pulse, Phase = x + y}) end
		return g
	end
	function k.anchor(x, y, z) return deco(P(m, "TitleAnchor", Vector3.new(1, 1, 1), cf * CFrame.new(x, y, z), Color3.new(1, 1, 1), nil, {Transparency = 1, CanCollide = false})) end
	function k.light(part, color, range)
		local l = Instance.new("PointLight") l.Color = color l.Range = range or 24 l.Brightness = 1.2 l.Shadows = false l.Parent = part
	end
	return k
end

-- the hub's stations, from parts, on the plaza between the paths. Each keeps the prompt its panel opens from.
function MapBuilder.stations()
	local f = folder("Stations")
	local R = MapBuilder.PLAZA_RADIUS
	local DARK, DARKER = Color3.fromRGB(62, 64, 82), Color3.fromRGB(40, 42, 56)
	local BLUE = Color3.fromRGB(40, 90, 225)
	local CYAN = Color3.fromRGB(90, 230, 255)
	local WHITE = Color3.fromRGB(235, 250, 255)
	local RED = Color3.fromRGB(255, 50, 70)
	local GOLD = Color3.fromRGB(255, 215, 80)
	local GREEN = Color3.fromRGB(70, 200, 90)
	for _, n in ipairs({"ShopStall", "ShopSign"}) do
		local old = workspace.Hub:FindFirstChild(n)
		if old then old:Destroy() end
	end

	-- THE SHOP: a market stall with a striped awning, stocked shelves, a counter and a ghost shopkeeper
	do
		local cf = ringCF(R - 10, 22.5, 0.4)
		local shop = group(workspace.Hub, "ShopStall")
		local k = kit(shop, cf)
		studs(P(shop, "Deck", Vector3.new(28, 0.8, 16), k.L(0, 0.4, 0), PLANK, Enum.Material.WoodPlanks), 4)
		studs(P(shop, "BackWall", Vector3.new(26, 12, 1.2), k.L(0, 6.8, 7), WOOD), 2)
		for _, xz in ipairs({{-13, -6.5}, {13, -6.5}, {-13, 7}, {13, 7}}) do k.block("Post", Vector3.new(1.8, 13, 1.8), xz[1], 7.3, xz[2], TRUNK) end
		-- shelves of mystery boxes and eggs
		local goods = {Color3.fromRGB(255, 90, 130), Color3.fromRGB(90, 200, 255), Color3.fromRGB(255, 200, 70), Color3.fromRGB(150, 110, 255), Color3.fromRGB(110, 230, 120)}
		for row, y in ipairs({3.2, 6.4, 9.6}) do
			k.trim("Shelf", Vector3.new(24, 0.5, 2.2), 0, y, 5.6, TRUNK)
			for x = -10, 10, 4 do
				local c = goods[(x + row * 3) % #goods + 1]
				if (x + row) % 3 == 0 then
					oval(shop, "ShelfEgg", Vector3.new(1.8, 2.3, 1.8), k.L(x, y + 1.4, 5.6), c)
				else
					local box = k.block("ShelfBox", Vector3.new(2, 2, 2), x, y + 1.25, 5.6, c)
					box.CFrame *= CFrame.Angles(0, ((x + row) % 2) * 0.25, 0)
				end
			end
		end
		-- the striped awning, with a scalloped edge
		for i = 0, 8 do
			local x = (i - 4) * 3.2
			local c = if i % 2 == 0 then GREEN else Color3.fromRGB(245, 250, 240)
			local strip = deco(P(shop, "Awning", Vector3.new(3.2, 0.7, 11), k.L(x, 14.2, -1) * CFrame.Angles(-0.32, 0, 0), c))
			studs(strip, 2, true)
			deco(P(shop, "Scallop", Vector3.new(3.2, 1.3, 0.6), strip.CFrame * CFrame.new(0, -0.7, -5.4), c, nil, {CanCollide = false}))
		end
		k.block("RoofBack", Vector3.new(29, 1, 5), 0, 15.6, 6, DARK)
		-- the counter, with its displays
		studs(P(shop, "Counter", Vector3.new(20, 3.4, 3), k.L(0, 2.5, -2.5), TRUNK), 2)
		k.trim("CounterTop", Vector3.new(21, 0.5, 3.8), 0, 4.4, -2.5, WOOD)
		k.glow("CounterGlow", Vector3.new(18, 0.5, 0.2), 0, 3.4, -4.05, Color3.fromRGB(120, 255, 150), 1.6)
		for i, x in ipairs({-8, 8}) do
			k.block("DisplayStand", Vector3.new(2.4, 1, 2.4), x, 5.1, -2.5, DARK)
			life(oval(shop, "DisplayEgg", Vector3.new(2, 2.7, 2), k.L(x, 7.2, -2.5), goods[i]), {Bob = 0.3, BobSpeed = 2, Phase = i, Spin = Vector3.new(0, 1, 0)})
		end
		for i, x in ipairs({-4, -3.2, 3.6, 4.2}) do ball(shop, "Coin", 0.8, k.L(x, 5.05, -3 + i * 0.3), GOLD, Enum.Material.Neon) end
		-- hanging lanterns, crates and a chalkboard out front
		for _, x in ipairs({-9, 0, 9}) do
			beam(shop, "Chain", k.L(x, 12.6, -2.4).Position, k.L(x, 10.8, -2.4).Position, 0.2, IRON)
			local g = k.glow("Lantern", Vector3.new(1.3, 1.7, 1.3), x, 10, -2.4, LANTERN)
			k.light(g, LANTERN, 14)
		end
		crate(shop, k.L(-16, 0.4, -5), 4) crate(shop, k.L(-16.4, 4.4, -5) * CFrame.Angles(0, 0.4, 0), 2.6, goods[2])
		crate(shop, k.L(16, 0.4, -6), 3.4, goods[4]) barrel(shop, k.L(16.5, 0.4, 0), 4.4) barrel(shop, k.L(-16.5, 0.4, 1), 4)
		local chalk = studs(deco(P(shop, "Chalkboard", Vector3.new(5, 6, 0.4), k.L(-10, 3.6, -8.5) * CFrame.Angles(0.15, 0, 0), DARKER)), 2)
		label(chalk, Enum.NormalId.Front, "TODAY\nBoxes\nTrackers", Color3.fromRGB(235, 245, 220))
		ghostFigure(shop, k.L(0, 8.6, 2.4), "shopkeeper")
		-- the big sign with running bulbs: GameService and ShopPanel write to it
		local sign = studs(deco(P(workspace.Hub, "ShopSign", Vector3.new(16, 3.6, 0.8), k.L(0, 18.4, 3.6), WOOD, Enum.Material.WoodPlanks)), 2)
		label(sign, Enum.NormalId.Front, "Shop", Color3.fromRGB(170, 255, 170)).Parent.PixelsPerStud = 22
		for i = 0, 9 do
			life(ball(shop, "Bulb", 0.7, k.L(-7.2 + i * 1.6, 20.5, 3.2), GOLD, Enum.Material.Neon), {Pulse = 5, Phase = i * 0.7})
		end
		title(k.anchor(0, 25, 3), "Shop", Color3.fromRGB(190, 255, 170), Color3.fromRGB(50, 200, 80), "Shop", "Fresh stock", 26)
		local shopSpot = P(f, "ShopClaim", Vector3.new(4, 6, 1), k.L(0, 3, -8), Color3.new(1, 1, 1), nil, {Transparency = 1, CanCollide = false, CanTouch = false})
		prompt(shopSpot, "ShopPrompt", "Open Shop", "Shop", 14)
	end

	-- THE FUSE MACHINE, after the owner's reference: a blue machine with a big glowing window, pipes and a lever console
	do
		local cf = ringCF(R - 10, 202.5, 0.4)
		local m = group(f, "FusionForge")
		local k = kit(m, cf)
		studs(P(m, "Base", Vector3.new(30, 0.8, 16), k.L(0, 0.4, 0), DARKER), 4)
		studs(P(m, "BaseStep", Vector3.new(20, 0.8, 13), k.L(4, 1.2, 0), DARK), 4)
		-- the body around the window
		studs(P(m, "BackPlate", Vector3.new(19, 15, 2), k.L(4, 8.8, 4.2), BLUE), 2)
		for _, x in ipairs({-4, 12}) do
			studs(P(m, "SideColumn", Vector3.new(3, 15, 10), k.L(x, 8.8, 0), BLUE), 2)
			k.trim("ColumnTrim", Vector3.new(3.4, 1, 10.4), x, 2.2, 0, DARK)
			k.trim("ColumnTrim", Vector3.new(3.4, 1, 10.4), x, 15.8, 0, DARK)
		end
		k.block("TopBeam", Vector3.new(19, 2.6, 10), 4, 17.1, 0, DARK)
		k.block("Cap", Vector3.new(14, 1.4, 8), 4, 19.1, 0.4, BLUE)
		k.block("Cap", Vector3.new(9, 1.4, 6), 4, 20.5, 0.8, DARK)
		ball(m, "Dome", 6, k.L(4, 21.4, 0.8), DARKER)
		k.block("ScreenFrame", Vector3.new(6, 2.6, 0.8), 4, 17.2, -5.2, DARKER)
		k.glow("TopScreen", Vector3.new(5, 1.7, 0.2), 4, 17.2, -5.65, CYAN, 1.2)
		-- the window with the question mark
		local window = deco(P(m, "FuseWindow", Vector3.new(13, 12.5, 7), k.L(4, 8.6, -0.5), WHITE, Enum.Material.Neon))
		label(window, Enum.NormalId.Front, "?", Color3.fromRGB(50, 70, 120)).Parent.PixelsPerStud = 9 -- text can't scale past 100 pixels
		life(window, {Pulse = 1.1, Base = 0.02})
		k.light(window, CYAN, 26)
		-- the side strip and its housing
		k.block("SideHousing", Vector3.new(2.6, 11, 4), 14.8, 7, 0, DARK)
		k.glow("SideGlow", Vector3.new(1.1, 8.5, 0.2), 14.8, 7, -2.1, CYAN, 1.6)
		-- pipes arching from the console over onto the machine
		arc(m, "Pipe", cf, -6, 9.5, 2.6, 7, 180, 15, 9, 1.5, DARKER)
		arc(m, "Pipe", cf, -6, 9.5, -0.2, 7, 180, 30, 8, 1, DARK)
		-- the heart indicator
		k.block("HeartPanel", Vector3.new(2.6, 6.5, 1.2), -6.5, 7.8, -1, DARK)
		for i = 0, 2 do
			local h = k.glow("HeartLight", Vector3.new(1.6, 1.4, 0.2), -6.5, 5.9 + i * 1.9, -1.7, RED, 3)
			h:SetAttribute("Phase", i * 0.8)
			local g = Instance.new("SurfaceGui") g.Face = Enum.NormalId.Front g.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud g.PixelsPerStud = 40 g.Parent = h
			local t = Instance.new("TextLabel") t.Size = UDim2.fromScale(1, 1) t.BackgroundTransparency = 1 t.Font = Enum.Font.FredokaOne t.TextScaled = true t.Text = "♥" t.TextColor3 = Color3.new(1, 0.9, 0.9) t.Parent = g
		end
		-- the lever console
		k.block("ConsoleBase", Vector3.new(7, 3.6, 7), -11, 2.6, -1, DARK)
		k.trim("HazardStrip", Vector3.new(7.2, 0.5, 0.2), -11, 3.4, -4.6, GOLD)
		local star = k.block("StarPanel", Vector3.new(6.5, 6.5, 1), -11, 8, 1.8, BLUE)
		label(star, Enum.NormalId.Front, "★", WHITE).Parent.PixelsPerStud = 14
		k.glow("StarGlow", Vector3.new(5, 0.5, 0.2), -11, 5.4, 1.2, CYAN, 2)
		k.trim("LeverBase", Vector3.new(2.2, 0.6, 2.2), -12.5, 4.7, -1.8, DARKER)
		k.trim("Lever", Vector3.new(0.5, 3.8, 0.5), -12.5, 6.4, -2.2, IRON).CFrame *= CFrame.Angles(-0.35, 0, 0)
		ball(m, "LeverKnob", 1.2, k.L(-12.5, 8.2, -2.9), RED)
		k.block("ButtonBox", Vector3.new(3, 1, 3), -9, 4.9, -2, DARKER)
		life(k.glow("Button", Vector3.new(1.8, 0.4, 1.8), -9, 5.6, -2, RED), {Pulse = 4})
		k.trim("Antenna", Vector3.new(0.5, 7, 0.5), -14, 7.5, 3, DARKER)
		life(ball(m, "AntennaTip", 1, k.L(-14, 11.4, 3), RED, Enum.Material.Neon), {Pulse = 3})
		-- a slow fan on top
		local fan = group(m, "Fan")
		for i = 0, 1 do
			deco(P(fan, "Blade", Vector3.new(7, 0.3, 1), k.L(4, 24.6, 0.8) * CFrame.Angles(0, i * math.pi / 2, 0), GOLD, nil, {CanCollide = false}))
		end
		fan.WorldPivot = k.L(4, 24.6, 0.8)
		life(fan, {Spin = Vector3.new(0, 2, 0)})
		-- GameService doesn't write to this; the tests expect the plate by name
		local plate = deco(P(f, "FusingSign", Vector3.new(9, 1.4, 0.4), k.L(4, 1.6, -6.7), DARKER))
		label(plate, Enum.NormalId.Front, "FUSE", CYAN)
		ghostFigure(m, k.L(-19, 7, -3), "mechanic")
		title(k.anchor(2, 31, 0), "Fuse Machine", Color3.fromRGB(120, 245, 255), Color3.fromRGB(30, 130, 240), "Fuse", "0/4", 28)
		local fuseSpot = P(f, "FuseSpot", Vector3.new(4, 6, 1), k.L(4, 3, -8), Color3.new(1, 1, 1), nil, {Transparency = 1, CanCollide = false, CanTouch = false})
		prompt(fuseSpot, "FusePrompt", "Fuse Monsters", "Fuse Machine", 14)
	end

	-- THE REBIRTH PORTAL: a block arch around a swirling glow, fed by two big batteries
	do
		local cf = ringCF(R - 10, 112.5, 0.4)
		local m = group(f, "RebirthHall")
		local k = kit(m, cf)
		local PINK, PURPLE = Color3.fromRGB(255, 90, 190), Color3.fromRGB(150, 80, 235)
		studs(P(m, "RebirthBase", Vector3.new(30, 0.8, 18), k.L(0, 0.4, 0), DARKER), 4)
		studs(P(m, "Step", Vector3.new(22, 0.8, 8), k.L(0, 1.2, 3), DARK), 4)
		-- the arch
		for a = -10, 190, 25 do
			local r = math.rad(a)
			local b = studs(deco(P(m, "ArchBlock", Vector3.new(3.4, 3.4, 4), k.L(math.cos(r) * 9.5, 10 + math.sin(r) * 9.5, 3) * CFrame.Angles(0, 0, r), if (a + 10) % 50 == 0 then PURPLE else DARK)), 2)
			b.CanCollide = true
		end
		for _, x in ipairs({-10, 10}) do k.block("ArchFoot", Vector3.new(4.5, 8.6, 4.6), x, 5.6, 3, DARK) end
		local disc = deco(P(m, "PortalDisc", Vector3.new(0.6, 17, 17), k.L(0, 10, 3.2) * CFrame.Angles(0, math.pi / 2, 0), PINK, Enum.Material.Neon, {Shape = Enum.PartType.Cylinder, CanCollide = false}))
		life(disc, {Pulse = 1.2, Base = 0.1})
		k.light(disc, PINK, 28)
		local swirl = group(m, "Swirl")
		for i = 0, 2 do
			deco(P(swirl, "SwirlBar", Vector3.new(15, 1.1, 0.3), k.L(0, 10, 2.6) * CFrame.Angles(0, 0, i * math.pi / 3), Color3.fromRGB(255, 225, 250), Enum.Material.Neon, {CanCollide = false}))
		end
		swirl.WorldPivot = k.L(0, 10, 2.6)
		life(swirl, {Spin = Vector3.new(0, 0, 1)})
		k.block("Keystone", Vector3.new(5, 5, 5), 0, 20.5, 3, PURPLE)
		life(k.glow("KeystoneGem", Vector3.new(2.6, 2.6, 0.3), 0, 20.5, 0.4, GOLD), {Pulse = 2.2})
		-- batteries
		for _, x in ipairs({-14, 14}) do
			k.block("Battery", Vector3.new(4, 9, 4), x, 5.3, 3, BLUE)
			k.trim("BatteryCap", Vector3.new(4.6, 1, 4.6), x, 10.3, 3, DARK)
			k.trim("BatteryCap", Vector3.new(2, 1, 2), x, 11.3, 3, GOLD)
			for i = 0, 3 do
				local bar = k.glow("Charge", Vector3.new(2.4, 1, 0.2), x, 2.8 + i * 1.6, 0.9, CYAN, 3)
				bar:SetAttribute("Phase", i * 0.6)
			end
			beam(m, "Cable", k.L(x, 11.6, 3).Position, k.L(x * 0.45, 17, 3).Position, 0.8, DARKER)
		end
		local pad = deco(P(f, "RebirthPad", Vector3.new(9, 0.3, 7), k.L(0, 1.7, -3), Color3.fromRGB(255, 120, 210), Enum.Material.Neon, {CanCollide = false}))
		prompt(pad, "RebirthPrompt", "Rebirth", "Rebirth Portal", 12)
		life(pad, {Pulse = 1.8, Base = 0.05})
		ghostFigure(m, k.L(-17, 7, -5), "keeper")
		title(k.anchor(0, 27, 3), "Rebirth", Color3.fromRGB(255, 190, 240), Color3.fromRGB(235, 60, 180), "Rebirth", "Come back stronger", 24)
	end

	-- THE BOOK OF FRIGHTS: a giant open book between shelves, for the index, with a ghost librarian
	do
		local cf = ringCF(R - 10, 292.5, 0.4)
		local m = group(f, "BookOfFrights")
		local k = kit(m, cf)
		local colors = {Color3.fromRGB(255, 90, 90), Color3.fromRGB(90, 170, 255), Color3.fromRGB(255, 200, 70), Color3.fromRGB(130, 220, 120), Color3.fromRGB(190, 120, 255), Color3.fromRGB(255, 130, 190)}
		studs(P(m, "Floor", Vector3.new(30, 0.8, 16), k.L(0, 0.4, 0), STONE), 4)
		for _, side in ipairs({-1, 1}) do
			local x = side * 11
			studs(P(m, "Bookcase", Vector3.new(8, 14, 4), k.L(x, 7.8, 3), WOOD), 2)
			for row = 0, 3 do
				k.trim("CaseShelf", Vector3.new(7.4, 0.3, 0.4), x, 2.6 + row * 3.1, 0.9, TRUNK)
				for b = 0, 7 do
					k.trim("Tome", Vector3.new(0.7, 2.1 + (b % 3) * 0.2, 0.5), x - 3 + b * 0.85, 3.9 + row * 3.1, 0.8, colors[(b + row * 2) % #colors + 1])
				end
			end
			k.trim("CaseTop", Vector3.new(9, 1, 5), x, 15.3, 3, TRUNK)
		end
		k.block("Lintel", Vector3.new(16, 2.4, 4), 0, 14.6, 3, Color3.fromRGB(30, 150, 200))
		k.glow("LintelGlow", Vector3.new(13, 0.5, 0.2), 0, 14.6, 0.9, CYAN, 1.5)
		studs(P(m, "BackPanel", Vector3.new(14, 13, 1), k.L(0, 7.5, 5), DARK), 2)
		-- the lectern and the book
		k.block("Lectern", Vector3.new(7, 2, 5), 0, 1.8, -1.5, TRUNK)
		k.block("Lectern", Vector3.new(4, 2.6, 3), 0, 4, -1.5, WOOD)
		local tilt = k.L(0, 7, -1.5) * CFrame.Angles(-0.45, 0, 0)
		for _, side in ipairs({-1, 1}) do
			deco(P(m, "Cover", Vector3.new(6.6, 0.5, 7), tilt * CFrame.new(side * 3.1, -0.4, 0) * CFrame.Angles(0, 0, side * 0.14), Color3.fromRGB(120, 50, 170)))
			deco(P(m, "Page", Vector3.new(6, 0.7, 6.4), tilt * CFrame.new(side * 3, 0.1, 0) * CFrame.Angles(0, 0, side * 0.14), Color3.fromRGB(245, 240, 220), nil, {CanCollide = false}))
			deco(P(m, "Writing", Vector3.new(3.6, 0.05, 0.3), tilt * CFrame.new(side * 3, 0.5, -1.4) * CFrame.Angles(0, 0, side * 0.14), Color3.fromRGB(120, 110, 130), nil, {CanCollide = false}))
			deco(P(m, "Writing", Vector3.new(3.6, 0.05, 0.3), tilt * CFrame.new(side * 3, 0.5, 0) * CFrame.Angles(0, 0, side * 0.14), Color3.fromRGB(120, 110, 130), nil, {CanCollide = false}))
		end
		local bookGlow = deco(P(m, "BookGlow", Vector3.new(0.4, 0.4, 0.4), tilt * CFrame.new(0, 1.4, 0), CYAN, Enum.Material.Neon, {Transparency = 1, CanCollide = false}))
		k.light(bookGlow, CYAN, 18)
		for i, xy in ipairs({{-5, 12}, {0.5, 13.5}, {5.5, 11.5}}) do -- loose pages floating up
			life(deco(P(m, "LoosePage", Vector3.new(1.6, 0.1, 2), k.L(xy[1], xy[2], -2) * CFrame.Angles(0.4, i, 0.3), Color3.fromRGB(245, 240, 220), nil, {CanCollide = false})), {Bob = 0.7, BobSpeed = 1.1, Phase = i * 2, Spin = Vector3.new(0, 0.5, 0)})
		end
		ghostFigure(m, k.L(0, 9.5, 2.6), "librarian")
		title(k.anchor(0, 23, 2), "Book of Frights", Color3.fromRGB(170, 240, 255), Color3.fromRGB(150, 110, 255), "Index", "Every monster you find", 28)
		local bookSpot = P(f, "IndexSpot", Vector3.new(4, 6, 1), k.L(0, 3, -7), Color3.new(1, 1, 1), nil, {Transparency = 1, CanCollide = false, CanTouch = false})
		prompt(bookSpot, "IndexPrompt", "Open Index", "Book of Frights", 14)
	end

	-- THE DIG CAMP: a radar and tools for buried eggs. Trackers are sold in the shop, so its prompt opens the shop.
	do
		local cf = ringCF(R - 12, 67.5, 0.4)
		local m = group(f, "DigCamp")
		local k = kit(m, cf)
		local GREENGLOW = Color3.fromRGB(130, 255, 150)
		studs(P(m, "Floor", Vector3.new(16, 0.8, 11), k.L(0, 0.4, 0), PLANK, Enum.Material.WoodPlanks), 4)
		k.block("Console", Vector3.new(7, 4.6, 3.4), -1.5, 3.1, 2.5, DARK)
		local screen = k.glow("RadarScreen", Vector3.new(5, 2.8, 0.2), -1.5, 3.6, 0.7, GREENGLOW, 1.4)
		label(screen, Enum.NormalId.Front, "◎", Color3.fromRGB(20, 90, 50)).Parent.PixelsPerStud = 25
		k.trim("RadarMast", Vector3.new(1, 8, 1), -1.5, 9, 2.5, DARKER)
		local dish = group(m, "RadarDish")
		deco(P(dish, "Dish", Vector3.new(0.6, 6, 6), k.L(-1.5, 13.5, 2.5) * CFrame.Angles(0, math.pi / 2, 0.5), GOLD, nil, {Shape = Enum.PartType.Cylinder, CanCollide = false}))
		deco(P(dish, "DishStem", Vector3.new(0.5, 0.5, 2), k.L(-1.5, 13.8, 1.5), IRON, nil, {CanCollide = false}))
		dish.WorldPivot = k.L(-1.5, 13.5, 2.5)
		life(dish, {Spin = Vector3.new(0, 1.2, 0)})
		-- shovels on a rack, and the dirt they've moved
		k.trim("Rack", Vector3.new(0.5, 6, 4.4), 6.5, 3.8, 1.5, TRUNK)
		for _, z in ipairs({0.2, 1.8, 3.4}) do
			k.trim("ShovelHandle", Vector3.new(0.3, 5.4, 0.3), 5.9, 3.8, z, PLANK)
			k.trim("ShovelHead", Vector3.new(0.3, 1.5, 1.2), 5.9, 1.9, z, IRON)
		end
		studs(deco(P(m, "DirtPile", Vector3.new(4.5, 1.6, 4), k.L(5, 1.5, -2.8), DIRT)), 2)
		studs(deco(P(m, "DirtPile", Vector3.new(2.6, 1.2, 2.2), k.L(5.2, 2.8, -2.6), DIRT)), 2)
		crate(m, k.L(-6.4, 0.8, 2.6), 3)
		ghostFigure(m, k.L(-5.6, 7.5, -2.6), "digger")
		title(k.anchor(0, 19, 2), "Dig Camp", Color3.fromRGB(205, 255, 170), Color3.fromRGB(240, 180, 70), "Tracker", "No tracker active", 20)
		local camp = P(f, "DigCampSpot", Vector3.new(4, 6, 1), k.L(-1.5, 3, -2), Color3.new(1, 1, 1), nil, {Transparency = 1, CanCollide = false, CanTouch = false})
		prompt(camp, "TrackerPrompt", "See Trackers", "Dig Camp", 12)
	end

	-- ghosts drifting over the plaza and one at each plot's gate
	for k, angle in ipairs({67, 157, 247, 337, 0}) do
		local a = math.rad(angle)
		ghostFigure(f, Vector3.new(math.sin(a) * 26, 32 + (k % 3) * 3, math.cos(a) * 26), nil, 5)
	end
	for i = 1, MapBuilder.PLOT_COUNT do
		local cf = ringCF(MapBuilder.RING_RADIUS, plotAngle(i))
		ghostFigure(f, (cf * CFrame.new(-18, 11, -70)).Position, nil, 3)
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
		for _, off in ipairs({-8.4, 8.4}) do -- a stone edge
			studs(deco(P(f, "PathEdge", Vector3.new(1, 0.5, outer - inner), ringCF((inner + outer) / 2, a, 0.25) * CFrame.new(off, 0, 0), STONE_LIGHT)), 2, true)
		end
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
		for _, off in ipairs({-7.4, 7.4}) do
			studs(deco(P(f, "PathEdge", Vector3.new(1, 0.5, MapBuilder.ISLAND_RADIUS - inner), ringCF((inner + MapBuilder.ISLAND_RADIUS) / 2, island.angle, 0.25) * CFrame.new(off, 0, 0), STONE_LIGHT)), 2, true)
		end
		local a = island.angle
		local from = polar(MapBuilder.ISLAND_RADIUS - 6, a)
		local to = polar(ISLAND_CENTRE - island.r + 6, a)
		local mid = (from + to) / 2 + Vector3.new(0, 0.1, 0)
		local length = (to - from).Magnitude
		local cf = CFrame.lookAt(mid, to + Vector3.new(0, 0.1, 0))
		P(f, "Bridge", Vector3.new(14, 0.8, length), cf, PLANK, Enum.Material.WoodPlanks)
		for k = 0, math.floor(length / 3) do -- planks, a shade apart
			local z = -length / 2 + k * 3 + 1.5
			deco(P(f, "BridgePlank", Vector3.new(14.6, 0.2, 2.5), cf * CFrame.new(0, 0.45, z), if k % 2 == 0 then TRUNK else TRUNK_DARK, nil, {CanCollide = false}))
		end
		for _, side in ipairs({-1, 1}) do
			deco(P(f, "BridgeRail", Vector3.new(0.6, 0.6, length), cf * CFrame.new(side * 7, 3.4, 0), PLANK))
			deco(P(f, "BridgeRope", Vector3.new(0.3, 0.3, length), cf * CFrame.new(side * 7, 1.9, 0), Color3.fromRGB(225, 200, 150), nil, {CanCollide = false}))
			for k = -3, 3 do
				local post = cf * CFrame.new(side * 7, 1.6, k * length / 7)
				studs(deco(P(f, "BridgePost", Vector3.new(1, 5, 1), post, TRUNK_DARK)), 2)
				deco(P(f, "BridgeStilt", Vector3.new(1.4, 6, 1.4), post * CFrame.new(0, -4.8, 0), WOOD))
				if k % 2 == 0 then
					local g = deco(P(f, "LampGlow", Vector3.new(1.1, 1.3, 1.1), post * CFrame.new(0, 3.2, 0), LANTERN, Enum.Material.Neon, {CanCollide = false}))
					if k == 0 then local l = Instance.new("PointLight") l.Color = LANTERN l.Range = 16 l.Brightness = 0.5 l.Shadows = false l.Parent = g end
				end
			end
		end
		-- a signpost where the road leaves the plaza, and benches along it
		signpost(f, ringCF(inner + 2, a) * CFrame.new(-10.5, 0, 0), island.title, Color3.fromRGB(255, 240, 190))
		for _, r in ipairs({150, 210}) do
			for _, side in ipairs({-1, 1}) do
				bench(f, ringCF(r, a) * CFrame.new(side * 10, 0, 0) * CFrame.Angles(0, side * math.pi / 2, 0))
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
	while placed < 150 and tries < 3000 do
		tries += 1
		local p = polar(rng:NextNumber(70, R - 8), rng:NextNumber(0, 360))
		if clear(p) then
			local cf = CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0)
			local pick = placed % 14
			if pick <= 2 then deadTree(f, cf, rng:NextNumber(18, 30))
			elseif pick <= 4 then leafTree(f, cf, rng:NextNumber(16, 24))
			elseif pick == 5 then pine(f, cf, rng:NextNumber(20, 30))
			elseif pick == 6 then rocks(f, cf, rng:NextNumber(4, 7))
			elseif pick == 7 then mushrooms(f, cf)
			elseif pick == 8 then root(f, cf)
			elseif pick == 9 then bush(f, cf, rng:NextNumber(4, 7))
			elseif pick == 10 then flowers(f, cf, if placed % 3 == 0 then Color3.fromRGB(255, 255, 255) else nil)
			elseif pick == 11 then stump(f, cf, rng:NextNumber(3, 5))
			elseif pick == 12 then log(f, cf, rng:NextNumber(8, 13))
			else grave(f, cf, rng:NextNumber(-0.15, 0.15)) end
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

-- a window: a dark frame, a pane, and shutters if asked
local function window(m, cf, w, h, color, shutters)
	deco(P(m, "WindowFrame", Vector3.new(w + 0.8, h + 0.8, 0.4), cf, Color3.fromRGB(46, 38, 62), nil, {CanCollide = false}))
	deco(P(m, "Window", Vector3.new(w, h, 0.3), cf * CFrame.new(0, 0, -0.2), color, Enum.Material.Neon, {CanCollide = false}))
	deco(P(m, "WindowBar", Vector3.new(0.25, h, 0.2), cf * CFrame.new(0, 0, -0.4), Color3.fromRGB(46, 38, 62), nil, {CanCollide = false}))
	if shutters then
		for _, side in ipairs({-1, 1}) do
			deco(P(m, "Shutter", Vector3.new(w * 0.45, h + 0.4, 0.2), cf * CFrame.new(side * (w * 0.75 + 0.3), 0, -0.3), shutters, nil, {CanCollide = false}))
		end
	end
end

local function graveVariant(parent, cf, kind, rngLean)
	if kind == 1 then return grave(parent, cf, rngLean) end
	local m = group(parent, "Grave")
	deco(P(m, "Base", Vector3.new(4, 0.6, 2.6), cf * CFrame.new(0, 0.3, 0), ROCK_DARK))
	if kind == 2 then -- a rounded stone
		studs(deco(P(m, "Stone", Vector3.new(3.2, 2.4, 0.9), cf * CFrame.new(0, 1.7, 0), ROCK)), 2)
		deco(P(m, "Round", Vector3.new(0.9, 3.2, 3.2), cf * CFrame.new(0, 2.9, 0) * CFrame.Angles(0, math.pi / 2, 0), ROCK, nil, {Shape = Enum.PartType.Cylinder}))
	elseif kind == 3 then -- a cross
		studs(deco(P(m, "Stone", Vector3.new(0.9, 4.6, 0.9), cf * CFrame.new(0, 2.9, 0) * CFrame.Angles(rngLean, 0, rngLean), ROCK)), 2)
		deco(P(m, "Arm", Vector3.new(3, 0.8, 0.8), cf * CFrame.new(0, 3.7, 0) * CFrame.Angles(rngLean, 0, rngLean), ROCK))
	else -- a tall pointed marker
		studs(deco(P(m, "Stone", Vector3.new(2, 4.4, 2), cf * CFrame.new(0, 2.8, 0), ROCK_DARK)), 2)
		studs(deco(P(m, "Stone", Vector3.new(1.3, 1.6, 1.3), cf * CFrame.new(0, 5.8, 0), ROCK)), 2)
		deco(P(m, "Stone", Vector3.new(0.7, 1, 0.7), cf * CFrame.new(0, 7.1, 0), ROCK))
	end
	return m
end

function MapBuilder.islands()
	local f = folder("World")
	local rng = Random.new(MapBuilder.SEED + 1)
	local PURPLE_WALL, PURPLE_DARK, ROOF_DARK = Color3.fromRGB(122, 100, 150), Color3.fromRGB(96, 80, 118), Color3.fromRGB(70, 56, 96)
	local PANE = Color3.fromRGB(110, 210, 225)
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
		-- local +Z points away from the hub, so buildings at the far side open toward the bridge
		local function free(p, margin) -- open ground: off the road, and off every tracker spot
			if not clearOfRoad(island, p) then return false end
			for _, xz in ipairs(DIG_SPOTS) do
				if (look * Vector3.new(xz[1], 0, xz[2]) - p).Magnitude < (margin or 11) then return false end
			end
			return true
		end
		-- scatters a prop on open ground between two radii, keeping out of a square around the island's middle
		local function scatter(count, r0, r1, keepOut, make)
			local placed, tries = 0, 0
			while placed < count and tries < count * 30 do
				tries += 1
				local p = at(island, rng:NextNumber(r0, r1), rng:NextNumber(0, 360))
				local inFrame = look:PointToObjectSpace(p)
				if free(p) and not (keepOut and math.abs(inFrame.X) < keepOut[1] and inFrame.Z > keepOut[2] and inFrame.Z < keepOut[3]) then
					placed += 1
					make(CFrame.new(p) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), placed)
				end
			end
		end
		-- every island: a road in, and an arch with its name
		local rim = island.r - 4
		studs(P(f, "IslandPath", Vector3.new(12, 0.3, rim - 24), look * CFrame.new(0, 0.15, -(rim + 24) / 2), DIRT), 4, true)
		nameArch(f, look * CFrame.new(0, 0, -rim + 12), island.title, Color3.fromRGB(255, 240, 190))

		if island.name == "Graveyard" then
			-- rows of graves of different kinds, inside an iron fence with a gateway
			for row = -1, 2 do
				for col = -3, 3 do
					if col ~= 0 then
						graveVariant(f, look * CFrame.new(col * 9.5, 0, row * 12 + 6) * CFrame.Angles(0, rng:NextNumber(-0.1, 0.1), 0), (col + row) % 4 + 1, rng:NextNumber(-0.1, 0.1))
					end
				end
			end
			local c1, c2, c3, c4 = look * CFrame.new(-40, 0, -24), look * CFrame.new(40, 0, -24), look * CFrame.new(40, 0, 66), look * CFrame.new(-40, 0, 66)
			fence(f, c1.Position, (look * CFrame.new(-8, 0, -24)).Position, 5)
			fence(f, (look * CFrame.new(8, 0, -24)).Position, c2.Position, 5)
			fence(f, c2.Position, c3.Position, 5)
			fence(f, c3.Position, c4.Position, 5)
			fence(f, c4.Position, c1.Position, 5)
			for _, x in ipairs({-8.5, 8.5}) do
				studs(deco(P(f, "GatePost", Vector3.new(2.4, 10, 2.4), look * CFrame.new(x, 5, -24), ROCK_DARK)), 2)
				ball(f, "GateBall", 2.4, look * CFrame.new(x, 11.2, -24), ROCK)
			end
			deco(P(f, "GateBar", Vector3.new(17, 0.8, 0.8), look * CFrame.new(0, 9.6, -24), IRON, nil, {CanCollide = false}))
			-- the mausoleum
			local mz = look * CFrame.new(0, 0, 50)
			local mm = group(f, "Mausoleum")
			studs(P(mm, "Step", Vector3.new(30, 1, 22), mz * CFrame.new(0, 0.5, 0), ROCK_DARK), 4)
			studs(P(mm, "Step", Vector3.new(26, 1, 18), mz * CFrame.new(0, 1.5, 0), ROCK), 4)
			studs(P(mm, "Hall", Vector3.new(20, 13, 13), mz * CFrame.new(0, 8.5, 1.5), ROCK_DARK), 2)
			for _, x in ipairs({-9, -3.2, 3.2, 9}) do
				studs(deco(P(mm, "Column", Vector3.new(2, 13, 2), mz * CFrame.new(x, 8.5, -7), ROCK)), 2)
			end
			local w, d, y = 26, 20, 15.6
			for k = 1, 3 do
				studs(deco(P(mm, "Roof", Vector3.new(w, 1.6, d), mz * CFrame.new(0, y, 0), STONE_LIGHT:Lerp(STONE, k / 3))), 4)
				w -= 7 d -= 5 y += 1.6
			end
			deco(P(mm, "Door", Vector3.new(7, 9, 0.4), mz * CFrame.new(0, 6.5, -5.2), Color3.fromRGB(46, 38, 62)))
			local doorGlow = deco(P(mm, "DoorGlow", Vector3.new(5.6, 7.6, 0.2), mz * CFrame.new(0, 6.3, -5.5), PANE, Enum.Material.Neon, {CanCollide = false}))
			life(doorGlow, {Pulse = 1.1, Base = 0.25})
			local plate = deco(P(mm, "Plate", Vector3.new(12, 2.2, 0.6), mz * CFrame.new(0, 14, -7.5), WOOD, Enum.Material.WoodPlanks))
			label(plate, Enum.NormalId.Front, "Rest Easy", Color3.fromRGB(235, 230, 245))
			-- an open grave with a shovel, a stone ghost, and benches
			studs(deco(P(f, "DugEarth", Vector3.new(7, 1.2, 4), look * CFrame.new(-30, 0.6, 40), DIRT)), 2)
			deco(P(f, "OpenGrave", Vector3.new(3.4, 0.1, 6.4), look * CFrame.new(-23, 0.05, 40), Color3.fromRGB(40, 30, 40), nil, {CanCollide = false}))
			deco(P(f, "Shovel", Vector3.new(0.4, 5, 0.4), look * CFrame.new(-30, 3.2, 40) * CFrame.Angles(0.2, 0, 0.3), PLANK))
			ghostFigure(f, look * CFrame.new(28, 5.2, 42) * CFrame.Angles(0, math.pi + 0.5, 0), "stone")
			bench(f, look * CFrame.new(-28, 0, -14))
			bench(f, look * CFrame.new(28, 0, -14))
			mist(f, look * CFrame.new(-20, 1, 18))
			mist(f, look * CFrame.new(20, 1, 30))
			scatter(32, 46, island.r - 8, {44, -30, 70}, function(cf, k)
				local pick = k % 5
				if pick == 0 then flowers(f, cf)
				elseif pick == 1 then bush(f, cf, 5, Color3.fromRGB(100, 130, 120))
				elseif pick == 2 then stump(f, cf, 3.6)
				elseif pick == 3 then deadTree(f, cf, rng:NextNumber(18, 30))
				else graveVariant(f, cf, k % 4 + 1, rng:NextNumber(-0.2, 0.2)) end
			end)
			ghostFigure(f, look * CFrame.new(-16, 7, 8) * CFrame.Angles(0, math.pi, 0), "sleepy")
			ghostFigure(f, look * CFrame.new(18, 7, 14) * CFrame.Angles(0, math.pi, 0), "sleepy")
		elseif island.name == "Mansion" then
			-- the old mansion: a proper house on a block hill, with wings, towers, a porch and a garden
			local base = look * CFrame.new(0, 0, 46)
			local h = group(f, "Mansion")
			local function B(name, size, x, y, z, color, tile) return studs(P(h, name, size, base * CFrame.new(x, y, z), color), tile or 2) end
			B("Hill", Vector3.new(84, 2, 56), 0, 1, 0, ROCK, 4)
			B("Hill", Vector3.new(76, 2, 48), 0, 3, 2, ROCK_DARK, 4)
			for k = 0, 1 do -- steps up the front
				B("Stair", Vector3.new(18, 1, 2), 0, 0.5 + k, -28.5 + k * 1, ROCK_DARK)
				B("Stair", Vector3.new(18, 1, 2), 0, 2.5 + k, -24 + k * 1, ROCK)
			end
			B("MainBlock", Vector3.new(40, 24, 24), 0, 16, 8, PURPLE_WALL)
			for _, side in ipairs({-1, 1}) do
				B("Wing", Vector3.new(14, 17, 20), side * 27, 12.5, 8, PURPLE_DARK)
				B("WingRoof", Vector3.new(17, 1.6, 23), side * 27, 21.8, 8, ROOF_DARK, 4)
				B("WingRoof", Vector3.new(11, 1.6, 15), side * 27, 23.4, 8, ROOF_DARK:Lerp(Color3.new(0, 0, 0), 0.12), 4)
				-- corner towers
				B("Tower", Vector3.new(10, 34, 10), side * 37, 21, -3, PURPLE_DARK)
				for k = 0, 3 do
					B("TowerRoof", Vector3.new(13 - k * 3.2, 2.2, 13 - k * 3.2), side * 37, 39 + k * 2.2, -3, ROOF_DARK:Lerp(Color3.fromRGB(140, 80, 170), k / 5))
				end
				ball(h, "TowerTip", 1.4, base * CFrame.new(side * 37, 48.2, -3), LANTERN, Enum.Material.Neon)
				for _, y in ipairs({14, 22, 30}) do window(h, base * CFrame.new(side * 37, y, -8.2), 3, 4.4, PANE, nil) end
				for _, x in ipairs({-3.6, 3.6}) do window(h, base * CFrame.new(side * 27 + x, 13, -2.2), 3, 5, PANE, ROOF_DARK) end
				-- the front of the main block
				for _, x in ipairs({10, 17}) do
					window(h, base * CFrame.new(side * x, 12, -4.2), 3.4, 5.4, PANE, ROOF_DARK)
					window(h, base * CFrame.new(side * x, 21, -4.2), 3.4, 5.4, if x == 17 then Color3.fromRGB(60, 50, 80) else PANE, ROOF_DARK)
				end
				B("Chimney", Vector3.new(4, 10, 4), side * 14, 34, 14, ROOF_DARK)
				B("ChimneyTop", Vector3.new(5, 1, 5), side * 14, 39.5, 14, STONE_LIGHT)
			end
			-- stepped main roof
			local w, d, y = 44, 28, 28.8
			for k = 1, 4 do
				B("Roof", Vector3.new(w, 1.8, d), 0, y, 8, ROOF_DARK:Lerp(Color3.fromRGB(120, 70, 150), k / 6), 4)
				w -= 9 d -= 6 y += 1.8
			end
			-- the central front with its round window, balcony and door
			B("Front", Vector3.new(14, 30, 4), 0, 19, -5, PURPLE_DARK)
			for k = 0, 2 do B("FrontRoof", Vector3.new(17 - k * 5, 2, 6), 0, 35 + k * 2, -5, ROOF_DARK) end
			local round = deco(P(h, "RoundWindow", Vector3.new(0.3, 6, 6), base * CFrame.new(0, 29, -7.2) * CFrame.Angles(0, math.pi / 2, 0), PANE, Enum.Material.Neon, {Shape = Enum.PartType.Cylinder, CanCollide = false}))
			life(round, {Pulse = 0.9, Base = 0.05})
			window(h, base * CFrame.new(0, 21, -7.2), 5, 6, PANE, ROOF_DARK)
			B("Balcony", Vector3.new(16, 0.9, 5), 0, 17.2, -8.4, ROCK)
			for k = -3, 3 do deco(P(h, "BalconyRail", Vector3.new(0.5, 2.4, 0.5), base * CFrame.new(k * 2.5, 18.8, -10.6), IRON, nil, {CanCollide = false})) end
			deco(P(h, "BalconyRail", Vector3.new(16, 0.4, 0.4), base * CFrame.new(0, 20, -10.6), IRON, nil, {CanCollide = false}))
			deco(P(h, "Doorway", Vector3.new(8, 11, 0.4), base * CFrame.new(0, 9.5, -7.2), Color3.fromRGB(46, 38, 62), nil, {CanCollide = false}))
			for _, x in ipairs({-1.9, 1.9}) do
				deco(P(h, "Door", Vector3.new(3.4, 9.6, 0.4), base * CFrame.new(x, 8.9, -7.5), TRUNK_DARK, nil, {CanCollide = false}))
				ball(h, "DoorKnob", 0.6, base * CFrame.new(x * 0.5, 8.6, -7.8), Color3.fromRGB(255, 215, 80), Enum.Material.Neon)
			end
			-- the porch
			for _, x in ipairs({-7.5, 7.5}) do
				B("PorchColumn", Vector3.new(1.8, 12, 1.8), x, 10, -13, STONE_LIGHT)
				local g = deco(P(h, "LampGlow", Vector3.new(1.3, 1.7, 1.3), base * CFrame.new(x, 12.6, -11), LANTERN, Enum.Material.Neon, {CanCollide = false}))
				local l = Instance.new("PointLight") l.Color = LANTERN l.Range = 18 l.Brightness = 0.6 l.Shadows = false l.Parent = g
			end
			B("PorchRoof", Vector3.new(19, 1.2, 9), 0, 16.4, -11, ROOF_DARK)
			-- ivy climbing the walls
			for k = 1, 22 do
				local x = rng:NextNumber(-44, 44)
				local yy = rng:NextNumber(5, 24)
				if math.abs(x) > 9 then
					deco(P(h, "Ivy", Vector3.new(rng:NextNumber(1.5, 3.5), rng:NextNumber(1.5, 3.5), 0.5), base * CFrame.new(x, yy, if math.abs(x) > 32 then -8.5 elseif math.abs(x) > 20 then -2.6 else -4.5), Color3.fromRGB(80, 150, 90), nil, {CanCollide = false}))
				end
			end
			-- bats circling a tower
			local bats = group(h, "Bats")
			for k = 1, 3 do
				local a = k * 2.1
				local spot = base * CFrame.new(-37 + math.cos(a) * 15, 42 + k, -3 + math.sin(a) * 15) * CFrame.Angles(0, -a, 0)
				deco(P(bats, "BatBody", Vector3.new(0.9, 0.9, 1.4), spot, Color3.fromRGB(46, 38, 62), nil, {CanCollide = false}))
				for _, side in ipairs({-1, 1}) do
					deco(P(bats, "BatWing", Vector3.new(1.8, 0.2, 1.1), spot * CFrame.new(side * 1.2, 0.1, 0) * CFrame.Angles(0, 0, side * 0.35), Color3.fromRGB(46, 38, 62), nil, {CanCollide = false}))
				end
			end
			bats.WorldPivot = base * CFrame.new(-37, 42, -3)
			life(bats, {Spin = Vector3.new(0, 0.7, 0)})
			-- a ghost peeking from the balcony
			ghostFigure(h, base * CFrame.new(5, 22.5, -9), "shy")
			-- the garden: a fountain, hedges and a fence
			local fount = group(f, "Fountain")
			local fc = look * CFrame.new(0, 0, -2)
			deco(P(fount, "Basin", Vector3.new(2, 16, 16), fc * CFrame.new(0, 1, 0) * CFrame.Angles(0, 0, math.pi / 2), ROCK, nil, {Shape = Enum.PartType.Cylinder}))
			deco(P(fount, "Pool", Vector3.new(0.3, 14, 14), fc * CFrame.new(0, 2, 0) * CFrame.Angles(0, 0, math.pi / 2), WATER, nil, {Shape = Enum.PartType.Cylinder, CanCollide = false}))
			studs(deco(P(fount, "Stem", Vector3.new(2.4, 7, 2.4), fc * CFrame.new(0, 4.5, 0), ROCK_DARK)), 2)
			deco(P(fount, "Bowl", Vector3.new(0.8, 7, 7), fc * CFrame.new(0, 8, 0) * CFrame.Angles(0, 0, math.pi / 2), ROCK, nil, {Shape = Enum.PartType.Cylinder}))
			ghostFigure(fount, fc * CFrame.new(0, 12, 0) * CFrame.Angles(0, math.pi, 0), "wisp")
			for _, side in ipairs({-1, 1}) do
				for k = 0, 3 do
					studs(deco(P(f, "Hedge", Vector3.new(4, 4, 8), look * CFrame.new(side * 16, 2, -10 + k * 9), Color3.fromRGB(78, 150, 92))), 2)
				end
				leafTree(f, look * CFrame.new(side * 58, 0, 30), 30)
			end
			for k = 1, 4 do
				local pool = at(island, rng:NextNumber(62, 92), k * 90 + 40)
				if free(pool, 26) then
					deco(P(f, "Pond", Vector3.new(rng:NextNumber(16, 24), 0.3, rng:NextNumber(16, 24)), CFrame.new(pool + Vector3.new(0, 0.1, 0)), Color3.fromRGB(60, 190, 170)))
					reeds(f, CFrame.new(pool + Vector3.new(6, 0.2, 5)))
				end
			end
			scatter(26, 40, island.r - 10, {46, -32, 74}, function(cf, k)
				if k % 3 == 0 then flowers(f, cf, Color3.fromRGB(255, 180, 220)) elseif k % 3 == 1 then bush(f, cf, 6) else leafTree(f, cf, rng:NextNumber(18, 26)) end
			end)
		elseif island.name == "DarkWoods" then
			-- a thick wood of twisted trees and dark pines around a lost cabin and a cold campfire
			local keep = {26, -24, 66}
			scatter(22, 22, island.r - 14, keep, function(cf) deadTree(f, cf, rng:NextNumber(24, 42)) end)
			scatter(16, 22, island.r - 12, keep, function(cf) pine(f, cf, rng:NextNumber(20, 30)) end)
			scatter(8, 18, 90, keep, function(cf) root(f, cf) end)
			scatter(8, 18, 92, keep, function(cf) mushrooms(f, cf) end)
			scatter(6, 18, 92, keep, function(cf) stump(f, cf, rng:NextNumber(3, 6)) end)
			scatter(5, 18, 92, keep, function(cf) log(f, cf, rng:NextNumber(9, 15)) end)
			scatter(8, 18, 92, keep, function(cf) bush(f, cf, rng:NextNumber(4, 7), Color3.fromRGB(62, 118, 96)) end)
			-- big glowing mushrooms
			scatter(7, 20, 88, keep, function(cf, k)
				local m = group(f, "GlowShroom")
				local tall = 6 + k % 3 * 2.5
				studs(deco(P(m, "Stalk", Vector3.new(1.8, tall, 1.8), cf * CFrame.new(0, tall / 2, 0), Color3.fromRGB(235, 230, 215))), 2)
				local cap = studs(deco(P(m, "Cap", Vector3.new(tall * 0.9, 1.6, tall * 0.9), cf * CFrame.new(0, tall + 0.6, 0), Color3.fromRGB(120, 90, 220))), 2)
				deco(P(m, "CapTop", Vector3.new(tall * 0.5, 1, tall * 0.5), cf * CFrame.new(0, tall + 1.7, 0), Color3.fromRGB(150, 110, 240), nil, {CanCollide = false}))
				for j = 1, 4 do
					local a = j * math.pi / 2
					ball(m, "Spot", 0.8, cap.CFrame * CFrame.new(math.cos(a) * tall * 0.3, 0.8, math.sin(a) * tall * 0.3), Color3.fromRGB(150, 255, 230), Enum.Material.Neon)
				end
				local l = Instance.new("PointLight") l.Color = Color3.fromRGB(150, 200, 255) l.Range = 14 l.Brightness = 0.7 l.Shadows = false l.Parent = cap
			end)
			-- the cabin
			local cab = group(f, "LostCabin")
			local cc = look * CFrame.new(0, 0, 44)
			for y = 0, 6 do -- log walls, course by course
				local tint = if y % 2 == 0 then TRUNK else TRUNK_DARK
				studs(P(cab, "WallLog", Vector3.new(26, 1.8, 1.8), cc * CFrame.new(0, 0.9 + y * 1.8, -9), tint), 2)
				studs(P(cab, "WallLog", Vector3.new(26, 1.8, 1.8), cc * CFrame.new(0, 0.9 + y * 1.8, 9), tint), 2)
				studs(P(cab, "WallLog", Vector3.new(1.8, 1.8, 18), cc * CFrame.new(-12, 0.9 + y * 1.8, 0), tint), 2)
				studs(P(cab, "WallLog", Vector3.new(1.8, 1.8, 18), cc * CFrame.new(12, 0.9 + y * 1.8, 0), tint), 2)
			end
			local rw, rd, ry = 32, 24, 13.4
			for k = 1, 4 do
				studs(deco(P(cab, "CabinRoof", Vector3.new(rw, 1.6, rd), cc * CFrame.new(0, ry, 0), Color3.fromRGB(80, 130, 110):Lerp(Color3.fromRGB(60, 100, 90), k / 4))), 4)
				rw -= 6 rd -= 6 ry += 1.6
			end
			deco(P(cab, "CabinDoor", Vector3.new(5, 8.4, 0.5), cc * CFrame.new(-5, 4.2, -10.1), Color3.fromRGB(46, 38, 62), nil, {CanCollide = false}))
			window(cab, cc * CFrame.new(6, 7, -10.1), 5, 4, Color3.fromRGB(255, 200, 110), TRUNK_DARK)
			studs(P(cab, "CabinChimney", Vector3.new(4, 20, 4), cc * CFrame.new(10, 13, 5), ROCK_DARK), 2)
			local puff = deco(P(cab, "ChimneySmoke", Vector3.new(1, 1, 1), cc * CFrame.new(10, 23.5, 5), Color3.new(1, 1, 1), nil, {Transparency = 1, CanCollide = false}))
			local smoke = Instance.new("Smoke") smoke.Color = Color3.fromRGB(235, 240, 245) smoke.Opacity = 0.2 smoke.RiseVelocity = 4 smoke.Size = 3 smoke.Parent = puff
			-- a cold blue campfire, with log seats
			local fire = look * CFrame.new(0, 0, 18)
			for k = 1, 8 do
				local a = k * math.pi / 4
				deco(P(f, "FireStone", Vector3.new(1.6, 1, 1.6), fire * CFrame.new(math.cos(a) * 3.4, 0.5, math.sin(a) * 3.4) * CFrame.Angles(0, a, 0), ROCK))
			end
			local flame = oval(f, "ColdFlame", Vector3.new(2.6, 4.2, 2.6), fire * CFrame.new(0, 2.2, 0), Color3.fromRGB(110, 220, 255), Enum.Material.Neon)
			life(flame, {Pulse = 5, Base = 0.05, Bob = 0.2, BobSpeed = 6})
			local fireLight = Instance.new("PointLight") fireLight.Color = flame.Color fireLight.Range = 24 fireLight.Brightness = 1.2 fireLight.Parent = flame
			log(f, fire * CFrame.new(-8, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), 9)
			log(f, fire * CFrame.new(8, 0, 0) * CFrame.Angles(0, math.pi / 2, 0), 9)
			ghostFigure(f, fire * CFrame.new(-9, 6.6, 0) * CFrame.Angles(0, -math.pi / 2, 0), "boo")
			ghostFigure(f, fire * CFrame.new(9, 6.6, 0) * CFrame.Angles(0, math.pi / 2, 0), "grump")
			fireflies(f, look * CFrame.new(0, 5, 0), 170)
			mist(f, look * CFrame.new(-30, 1, -20))
			mist(f, look * CFrame.new(30, 1, -30))
			mist(f, look * CFrame.new(0, 1, 70))
		else
			-- the ruins: the tilting clock tower, a colonnade, broken arches, an aqueduct and a floating crystal
			local tower = group(f, "ClockTower")
			local base = look * CFrame.new(0, 0, 44)
			studs(deco(P(tower, "Base", Vector3.new(24, 2, 24), base * CFrame.new(0, 1, 0), ROCK_DARK)), 4)
			studs(deco(P(tower, "Base", Vector3.new(18, 4, 18), base * CFrame.new(0, 4, 0), ROCK)), 4)
			local lean = base * CFrame.new(0, 6, 0) * CFrame.Angles(0.06, 0, -0.04)
			studs(P(tower, "Shaft", Vector3.new(12, 42, 12), lean * CFrame.new(0, 21, 0), ROCK_DARK), 4)
			studs(deco(P(tower, "Crown", Vector3.new(15, 3, 15), lean * CFrame.new(0, 43.5, 0), ROCK)), 4)
			studs(deco(P(tower, "Crown", Vector3.new(10, 3, 10), lean * CFrame.new(0, 46.5, 0), ROOF_DARK)), 4)
			studs(deco(P(tower, "Crown", Vector3.new(5, 3, 5), lean * CFrame.new(0, 49.5, 0), ROOF_DARK)), 2)
			local face = deco(P(tower, "ClockFace", Vector3.new(0.4, 8, 8), lean * CFrame.new(0, 35, -6.2) * CFrame.Angles(0, math.pi / 2, 0), Color3.fromRGB(245, 240, 215), Enum.Material.Neon, {Shape = Enum.PartType.Cylinder, CanCollide = false}))
			local centre = lean * CFrame.new(0, 35, -6.6)
			deco(P(tower, "ClockHand", Vector3.new(0.5, 3.4, 0.3), centre * CFrame.new(0, 1.5, 0), IRON, nil, {CanCollide = false}))
			local hand = deco(P(tower, "ClockHand", Vector3.new(0.4, 3, 0.3), centre, IRON, nil, {CanCollide = false}))
			hand.CFrame = centre * CFrame.Angles(0, 0, 1) * CFrame.new(0, 1.4, 0)
			face.CastShadow = false
			-- a colonnade up the road, some columns fallen
			for k = 0, 4 do
				for _, side in ipairs({-1, 1}) do
					local z = -22 + k * 11
					local h = if (k + side) % 3 == 0 then 6 else 14
					studs(deco(P(f, "ColumnFoot", Vector3.new(4.4, 1, 4.4), look * CFrame.new(side * 15, 0.5, z), ROCK)), 2)
					studs(P(f, "RuinColumn", Vector3.new(3, h, 3), look * CFrame.new(side * 15, 1 + h / 2, z), ROCK), 2)
					if h > 6 then
						studs(deco(P(f, "ColumnTop", Vector3.new(4.4, 1, 4.4), look * CFrame.new(side * 15, h + 1.5, z), ROCK_DARK)), 2)
						if k % 2 == 0 then deco(P(f, "Ivy", Vector3.new(3.2, 5, 3.2), look * CFrame.new(side * 15, h * 0.55, z), Color3.fromRGB(80, 150, 90), nil, {CanCollide = false, Transparency = 0.1})) end
					else
						studs(deco(P(f, "FallenDrum", Vector3.new(3, 3, 5), look * CFrame.new(side * 21, 1.5, z + 1) * CFrame.Angles(0, 0.7, 0), ROCK)), 2)
					end
				end
			end
			-- the crystal on its altar, in the middle of the colonnade
			studs(P(f, "Altar", Vector3.new(10, 1.4, 10), look * CFrame.new(0, 0.7, 2), ROCK_DARK), 2)
			studs(P(f, "Altar", Vector3.new(6, 2, 6), look * CFrame.new(0, 2.4, 2), ROCK), 2)
			local crystal = deco(P(f, "Crystal", Vector3.new(3, 3, 3), look * CFrame.new(0, 7.5, 2) * CFrame.Angles(0.78, 0, 0.62), Color3.fromRGB(190, 130, 255), Enum.Material.Neon, {CanCollide = false}))
			life(crystal, {Bob = 0.6, BobSpeed = 1.3, Spin = Vector3.new(0, 0.8, 0), Pulse = 1.5})
			local crystalLight = Instance.new("PointLight") crystalLight.Color = crystal.Color crystalLight.Range = 26 crystalLight.Brightness = 1.2 crystalLight.Shadows = false crystalLight.Parent = crystal
			-- an aqueduct across the far side, with a broken span
			for k = -4, 4 do
				if k ~= 2 then
					local x = k * 16
					local height = 16 + (k % 2) * 2
					studs(P(f, "Pier", Vector3.new(5, height, 5), look * CFrame.new(x, height / 2, 82), ROCK), 2)
					if k < 4 and k ~= 1 then
						studs(deco(P(f, "Span", Vector3.new(16, 3, 5), look * CFrame.new(x + 8, height + 1, 82), ROCK_DARK)), 2)
						deco(P(f, "Channel", Vector3.new(14, 0.4, 3), look * CFrame.new(x + 8, height + 2.7, 82), WATER, nil, {CanCollide = false}))
					end
				end
			end
			-- broken walls, rubble and stone ghosts
			for k = 1, 8 do
				local p = at(island, rng:NextNumber(50, 95), k * 45 + 12)
				if free(p) then
					local cf = CFrame.lookAt(p, c)
					local height = rng:NextNumber(6, 14)
					studs(deco(P(f, "RuinWall", Vector3.new(rng:NextNumber(12, 22), height, 2.4), cf * CFrame.new(0, height / 2, 0), ROCK)), 2)
					studs(deco(P(f, "RuinWall", Vector3.new(5, height * 0.6, 2.6), cf * CFrame.new(5, height * 1.2, 0), ROCK_DARK)), 2)
					rocks(f, cf * CFrame.new(rng:NextNumber(-8, 8), 0, 5), rng:NextNumber(3, 5))
				end
			end
			ghostFigure(f, look * CFrame.new(-28, 5.2, 20) * CFrame.Angles(0, math.pi - 0.6, 0), "stone")
			ghostFigure(f, look * CFrame.new(30, 5.2, 12) * CFrame.Angles(0, math.pi + 0.6, 0), "stone")
			ghostFigure(f, look * CFrame.new(0, 13, 2) * CFrame.Angles(0, math.pi, 0), "wisp", 3)
			scatter(12, 44, island.r - 12, {30, -28, 90}, function(cf, n)
				if n % 3 == 0 then flowers(f, cf, Color3.fromRGB(255, 240, 130)) elseif n % 3 == 1 then bush(f, cf, 5) else rocks(f, cf, rng:NextNumber(3, 5)) end
			end)
		end
		-- a few things on every island's edge
		for k = 1, 8 do
			local p = at(island, island.r - 8, k * 45 + 12)
			if free(p) then
				if k % 2 == 0 then deadTree(f, CFrame.new(p), rng:NextNumber(18, 26)) else rocks(f, CFrame.new(p), rng:NextNumber(4, 6)) end
			end
		end
		-- ghosts wandering over each island
		for k = 1, 4 do
			ghostFigure(f, at(island, rng:NextNumber(24, 70), k * 90) + Vector3.new(0, rng:NextNumber(11, 20), 0), nil, 7)
		end
		task.wait()
	end

	-- islets out on the water, one with a lighthouse whose lamp turns
	for i, angle in ipairs(ISLETS) do
		local c = polar(ISLET_CENTRE, angle)
		local cf = CFrame.lookAt(c, Vector3.zero)
		if i == 1 then
			local lh = group(f, "Lighthouse")
			studs(deco(P(lh, "Rock", Vector3.new(24, 4, 24), cf * CFrame.new(0, 2, 0), ROCK)), 4)
			for k = 0, 5 do
				studs(deco(P(lh, "Stripe", Vector3.new(11 - k, 6, 11 - k), cf * CFrame.new(0, 7 + k * 6, 0), if k % 2 == 0 then Color3.fromRGB(245, 245, 240) else Color3.fromRGB(100, 90, 170))), 2)
			end
			studs(deco(P(lh, "Gallery", Vector3.new(10, 1, 10), cf * CFrame.new(0, 40.5, 0), IRON)), 2)
			deco(P(lh, "LampRoom", Vector3.new(4.5, 4.5, 4.5), cf * CFrame.new(0, 43.2, 0), LANTERN, Enum.Material.Neon))
			for k = 0, 2 do studs(deco(P(lh, "LampRoof", Vector3.new(7 - k * 2.2, 1.2, 7 - k * 2.2), cf * CFrame.new(0, 46 + k * 1.2, 0), Color3.fromRGB(100, 90, 170))), 2) end
			local turn = group(lh, "Beam")
			for _, side in ipairs({-1, 1}) do
				deco(P(turn, "LightBeam", Vector3.new(44, 2.4, 2.4), cf * CFrame.new(side * 24, 43.2, 0), Color3.fromRGB(220, 255, 240), Enum.Material.Neon, {Transparency = 0.75, CanCollide = false}))
			end
			turn.WorldPivot = cf * CFrame.new(0, 43.2, 0)
			life(turn, {Spin = Vector3.new(0, 0.5, 0)})
		else
			leafTree(f, cf * CFrame.new(-6, 0, 2), 22 + i * 3)
			deadTree(f, cf * CFrame.new(10, 0, -6), 20)
			rocks(f, cf * CFrame.new(4, 0, 12), 5)
			lamp(f, cf * CFrame.new(0, 0, -12), 9)
			ghostFigure(f, c + Vector3.new(0, 12, 0), nil, 6)
		end
	end
	-- a rowing boat, lily pads and rocks out on the water
	local boat = group(f, "Boat")
	local boatCF = CFrame.new(polar(330, 67.5)) * CFrame.new(0, -0.4, 0) * CFrame.Angles(0, 0.6, 0.05)
	studs(deco(P(boat, "Hull", Vector3.new(6, 2, 13), boatCF * CFrame.new(0, 0.6, 0), TRUNK)), 2)
	deco(P(boat, "Inside", Vector3.new(4.6, 0.3, 11), boatCF * CFrame.new(0, 1.65, 0), WOOD, nil, {CanCollide = false}))
	for _, z in ipairs({-3, 3}) do deco(P(boat, "BoatSeat", Vector3.new(4.8, 0.4, 1.4), boatCF * CFrame.new(0, 1.9, z), PLANK, nil, {CanCollide = false})) end
	deco(P(boat, "Oar", Vector3.new(0.3, 0.3, 8), boatCF * CFrame.new(3.2, 2, 0) * CFrame.Angles(0.15, 0.4, 0), PLANK, nil, {CanCollide = false}))
	ghostFigure(boat, boatCF * CFrame.new(0, 7, -3) * CFrame.Angles(0, math.pi, 0), "sleepy")
	local placed, tries = 0, 0
	while placed < 46 and tries < 1500 do
		tries += 1
		local p = polar(rng:NextNumber(308, 590), rng:NextNumber(0, 360))
		local onLand = false
		for _, island in ipairs(ISLANDS) do
			local centre, spread = polar(ISLAND_CENTRE, island.angle), island.r + 10
			if (p - centre).Magnitude < spread then onLand = true end
		end
		for _, angle in ipairs(ISLETS) do
			if (p - polar(ISLET_CENTRE, angle)).Magnitude < ISLET_RADIUS + 10 then onLand = true end
		end
		if not onLand then
			placed += 1
			if placed % 4 == 0 then
				rocks(f, CFrame.new(p + Vector3.new(0, -1.2, 0)) * CFrame.Angles(0, placed, 0), rng:NextNumber(3, 7))
			else
				local d = rng:NextNumber(3, 5)
				deco(P(f, "LilyPad", Vector3.new(0.2, d, d), CFrame.new(p + Vector3.new(0, -1.1, 0)) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(110, 200, 110), nil, {Shape = Enum.PartType.Cylinder, CanCollide = false}))
				if placed % 3 == 0 then ball(f, "LilyBloom", 1, CFrame.new(p + Vector3.new(0, -0.6, 0)), Color3.fromRGB(255, 190, 225)) end
			end
		end
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
		for _, xz in ipairs(DIG_SPOTS) do
			n += 1
			local spot = P(f, "Dig" .. n, Vector3.new(2, 1, 2), look * CFrame.new(xz[1], 0.5, xz[2]), Color3.new(1, 1, 1), nil, {Transparency = 1, CanCollide = false, CanTouch = false, CanQuery = false})
			-- the egg mound has to fit: scattered trees, roots and logs give way to a dig spot
			for _, part in ipairs(workspace:GetPartBoundsInRadius(spot.Position, 8)) do
				local model = part:FindFirstAncestorOfClass("Model")
				if model and (model.Name:find("Tree$") or model.Name == "Root" or model.Name == "Log") then model:Destroy() end
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
