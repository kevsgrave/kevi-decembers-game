-- Furnishes a bedroom in one of three styles that match its tier: Cozy (Normal), Fancy (Silver), Gold Luxury (Gold and up).
-- Furniture models are AI-generated meshes stored in ServerStorage.Furniture; walls, floor, trim, rugs and lights are parts.
-- Spots are in room coordinates: u = studs in from the front (window) wall, w = studs along the room toward the display case.
-- The bed stands against the back wall with its long side facing the window, so the sleeping kid is seen side-on.
local ServerStorage = game:GetService("ServerStorage")
local BedHump = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("BedHump"))
local PlotFrame = require(script.Parent.PlotFrame)

local RoomStyles = {}

local function styleFor(tierName)
	if tierName == "Normal" then return "Cozy" end
	if tierName == "Silver" then return "Fancy" end
	return "Luxury"
end
RoomStyles.styleFor = styleFor

local GOLD = Color3.fromRGB(255, 200, 70)
local BED_W = -5 -- centre of the bed along the room, in the middle of the window's view

-- furniture entries: {model, u, w, facing, y?}. facing: "front" faces the window, "+w"/"-w" face along the room
-- (use them against the side walls), "ceiling" hangs from the ceiling, "back" is centred on the back wall.
local STYLES = {
	Cozy = {
		floor = {Color3.fromRGB(170, 120, 80), Enum.Material.WoodPlanks},
		walls = nil, -- keep each room's own pastel wallpaper
		ceiling = Color3.fromRGB(255, 245, 230),
		bed = "CozyBed",
		curtains = Color3.fromRGB(255, 220, 120),
		rug = {Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 255, 255)},
		furniture = {
			{"CozyNightstand", 26.3, 2.6, "front"},
			{"CozyBookshelf", 11, -12.3, "+w"},
			{"CozyDesk", 19, 11.6, "-w"},
			{"CozyToyChest", 26, 9, "front"},
			{"CozyRockingHorse", 8, 7, "front"},
		},
		lights = {{26.3, 2.6, 4.7, Color3.fromRGB(255, 170, 90)}}, -- nightstand lamp
	},
	Fancy = {
		floor = {Color3.fromRGB(235, 232, 240), Enum.Material.Marble},
		walls = Color3.fromRGB(222, 208, 245),
		wainscot = Color3.fromRGB(250, 250, 255),
		trim = Color3.fromRGB(200, 200, 215),
		crown = Color3.fromRGB(215, 215, 230),
		ceiling = Color3.fromRGB(250, 248, 255),
		bed = "FancyBed",
		curtains = Color3.fromRGB(190, 170, 235),
		rug = {Color3.fromRGB(205, 200, 220), Color3.fromRGB(240, 240, 250)},
		furniture = {
			{"FancyFloorLamp", 26.3, 2.4, "front"},
			{"FancyDresser", 11, -12.1, "+w"},
			{"FancyVanity", 21, 12.5, "-w"},
			{"FancyWardrobe", 11, 12, "-w"},
			{"FancyArmchair", 25.5, 9, "front"},
		},
		lights = {{26.3, 2.4, 6.2, Color3.fromRGB(220, 200, 255)}}, -- floor lamp shade
	},
	Luxury = {
		floor = {Color3.fromRGB(95, 55, 35), Enum.Material.WoodPlanks},
		walls = Color3.fromRGB(150, 30, 50),
		wainscot = Color3.fromRGB(110, 20, 35),
		trim = GOLD,
		crown = GOLD,
		ceiling = Color3.fromRGB(120, 20, 35),
		bed = "LuxuryBed",
		curtains = Color3.fromRGB(180, 20, 40),
		rug = {Color3.fromRGB(170, 25, 45), GOLD},
		furniture = {
			{"LuxurySideTable", 26.3, 2.6, "front"},
			{"LuxuryWardrobe", 12, -11.9, "+w"},
			{"LuxuryMirror", 8, 12.5, "-w"},
			{"LuxuryThrone", 25, 9.5, "front"},
			{"LuxuryChest", 17, 11.8, "-w"},
			{"LuxuryPainting", 0, 6, "back", 7.5}, -- over the bedside table, between canopy and corner
			{"LuxuryChandelier", 11, BED_W, "ceiling"},
		},
		lights = {{11, BED_W, 11, Color3.fromRGB(255, 190, 110)}, {26.3, 2.6, 4.4, Color3.fromRGB(255, 170, 90)}}, -- chandelier and candle, both dim
	},
}

local WALL_PARTS = {"BackWall", "SideWallA", "SideWallB", "FrontLow", "FrontHigh", "FrontLeft", "FrontRight"}
local OLD_FURNITURE = {"Rug", "Headboard", "Mattress", "Blanket", "Pillow", "Nightstand", "Lamp", "ToyBox", "Ball"}

local function block(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name p.Size = size p.CFrame = cf p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true p.CanCollide = false p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- the room's frame, read from its own walls in plot-local space, so it works on both sides of the aisle and on
-- every plot in the ring. at() gives world positions, dir() world directions, cf() a placement with the plot's rotation.
local function frame(bedroom)
	local P = PlotFrame.of(bedroom)
	local floor = P:PointToObjectSpace(bedroom.RoomFloor.Position)
	local side = math.sign(floor.X)
	local front = math.abs(P:PointToObjectSpace(bedroom.FrontLow.Position).X)
	local back = math.abs(P:PointToObjectSpace(bedroom.BackWall.Position).X)
	local floorTop = floor.Y + bedroom.RoomFloor.Size.Y / 2
	local zc = floor.Z
	local L = -side -- +w runs toward the display case (the room's left as seen from the aisle)
	local function at(u, w, y) return P:PointToWorldSpace(Vector3.new(side * (front + u), floorTop + (y or 0), zc + L * w)) end
	local function dir(x, y, z) return P:VectorToWorldSpace(Vector3.new(x, y, z)) end
	local function cf(u, w, y) return CFrame.new(at(u, w, y)) * P.Rotation end
	return {side = side, L = L, at = at, dir = dir, cf = cf, depth = back - front - 0.5, half = bedroom.RoomFloor.Size.Z / 2, floorTop = floorTop, height = bedroom.BackWall.Size.Y}
end

-- one-time cleanup of the old block furniture; the bed's old frame becomes an invisible anchor Jeff scares from
local function clearOld(bedroom)
	for _, name in ipairs(OLD_FURNITURE) do
		local p = bedroom:FindFirstChild(name)
		if p then p:Destroy() end
	end
	local bed = bedroom:FindFirstChild("BedFrame")
	if bed then
		bed.Transparency = 1
		bed.CanCollide = false
		for _, t in ipairs(bed:GetChildren()) do if t:IsA("Texture") then t:Destroy() end end
	end
	if bedroom:GetAttribute("Wallpaper") == nil then
		bedroom:SetAttribute("Wallpaper", bedroom.BackWall.Color)
	end
end

local function place(furnishing, f, modelName, u, w, facing, y)
	local src = ServerStorage.Furniture:FindFirstChild(modelName)
	if not src then return end
	local m = src:Clone()
	local _, size = m:GetBoundingBox()
	local look
	if facing == "+w" then look = f.dir(0, 0, f.L)
	elseif facing == "-w" then look = f.dir(0, 0, -f.L)
	else look = f.dir(-f.side, 0, 0) end -- front, back, ceiling: face the window
	if facing == "back" then u = f.depth - size.Z / 2 - 0.1 end
	local pos = f.at(u, w, y or 0)
	if facing == "ceiling" then pos = f.at(u, w, f.height - size.Y - 0.2) end
	m:PivotTo(CFrame.lookAt(pos, pos + look))
	m.Parent = furnishing
	return m
end

function RoomStyles.apply(bedroom, tierName)
	local name = styleFor(tierName)
	if bedroom:GetAttribute("Style") == name then return end
	bedroom:SetAttribute("Style", name)
	clearOld(bedroom)
	local style = STYLES[name]
	local f = frame(bedroom)
	local old = bedroom:FindFirstChild("Furnishing") if old then old:Destroy() end
	local furnishing = Instance.new("Folder") furnishing.Name = "Furnishing"

	-- walls and floor
	local wallColor = style.walls or bedroom:GetAttribute("Wallpaper")
	for _, w in ipairs(WALL_PARTS) do
		local p = bedroom:FindFirstChild(w)
		if p then p.Color = wallColor end
	end
	bedroom.RoomFloor.Color = style.floor[1]
	bedroom.RoomFloor.Material = style.floor[2]

	-- wainscot, trim and crown moulding along the back and side walls (inside faces), and a ceiling.
	-- Each layer stands out from the wall by a different amount so no two faces share a plane (that flickers).
	local wallFace = f.half - 0.5 -- side walls are 1 stud thick, centred on the room's edge
	local function alongWalls(prefix, height, y, color, material, thick)
		block(furnishing, prefix .. "Back", Vector3.new(thick, height, wallFace * 2), f.cf(f.depth - 0.02 - thick / 2, 0, y), color, material)
		for _, sgn in ipairs({-1, 1}) do
			block(furnishing, prefix .. "Side", Vector3.new(f.depth - 0.04, height, thick), f.cf(f.depth / 2, sgn * (wallFace - 0.02 - thick / 2), y), color, material)
		end
	end
	if style.wainscot then alongWalls("Wainscot", 4.5, 2.25, style.wainscot, nil, 0.2) end
	if style.trim then alongWalls("Trim", 0.45, 4.6, style.trim, Enum.Material.Metal, 0.35) end
	if style.crown then alongWalls("Crown", 0.6, f.height - 0.5, style.crown, Enum.Material.Metal, 0.35) end
	block(furnishing, "Ceiling", Vector3.new(f.depth + 0.5, 0.2, f.half * 2), f.cf(f.depth / 2, 0, f.height - 0.15), style.ceiling)

	-- curtains either side of the window (window spans w -12..2 on the front wall)
	for _, w in ipairs({-12.3, 2.3}) do
		block(furnishing, "Curtain", Vector3.new(0.4, 10, 1.6), f.cf(0.9, w, 8), style.curtains, Enum.Material.Fabric)
	end
	block(furnishing, "CurtainRod", Vector3.new(0.3, 0.3, 16.5), f.cf(0.9, -5, 13.2), GOLD, Enum.Material.Metal)

	-- bed against the back wall, headboard toward +w
	local bedSrc = ServerStorage.Furniture[style.bed]
	local _, bedSize = bedSrc:GetBoundingBox() -- X = width (runs in from the back wall), Z = length (along the room)
	local bedU = f.depth - bedSize.X / 2 - 0.2
	local bedPos = f.at(bedU, BED_W, 0)
	local bed = bedSrc:Clone()
	bed.Name = "Bed"
	bed:SetAttribute("BedKind", style.bed) -- clients swap in the lumpy-quilt version (Shared/BedHump)
	bed:PivotTo(CFrame.lookAt(bedPos, bedPos - f.dir(0, 0, f.L)))
	bed.Parent = furnishing
	-- Jeff's scare spot is computed from this anchor: in front of the bed, on the window side
	local anchor = bedroom:FindFirstChild("BedFrame")
	if anchor then
		anchor.Size = Vector3.new(bedSize.X, 2, bedSize.Z)
		anchor.CFrame = f.cf(bedU, BED_W, 1)
	end

	-- round rug in front of the bed
	local rugCf = f.cf(bedU - bedSize.X / 2 - 3, BED_W, 0.08) * CFrame.Angles(0, 0, math.pi / 2)
	block(furnishing, "RugBorder", Vector3.new(0.12, 11, 11), rugCf, style.rug[2], Enum.Material.Fabric).Shape = Enum.PartType.Cylinder
	block(furnishing, "Rug", Vector3.new(0.16, 9.6, 9.6), rugCf, style.rug[1], Enum.Material.Fabric).Shape = Enum.PartType.Cylinder

	for _, item in ipairs(style.furniture) do
		place(furnishing, f, item[1], item[2], item[3], item[4], item[5])
	end

	-- dim warm lights: the kids are asleep
	for _, l in ipairs(style.lights) do
		local glow = block(furnishing, "NightGlow", Vector3.new(0.6, 0.6, 0.6), f.cf(l[1], l[2], l[3]), l[4], Enum.Material.Neon)
		glow.Transparency = 1
		local light = Instance.new("PointLight") light.Color = l[4] light.Range = 13 light.Brightness = 0.6 light.Parent = glow
	end

	-- where the kid sleeps: shoulders at the quilt's lump (BedHump), body under it, head out on the sheet by the pillow.
	-- GuestSpot is the top of the kid's head, oriented as the kid lies: up axis toward the headboard (tilted a little)
	-- and facing the ceiling. SitPoint is where it sits up when scared.
	local hump = BedHump.BEDS[style.bed]
	local headEnd = BED_W + hump.fold + 3.2 -- head clear of the quilt edge, resting by the pillow
	local tilt = math.rad(18) -- head propped up on the pillow so the face shows
	local toHead = f.dir(0, 0, f.L)
	local kidUp = (toHead * math.cos(tilt) + Vector3.yAxis * math.sin(tilt))
	local kidFace = (Vector3.yAxis * math.cos(tilt) - toHead * math.sin(tilt))
	local pillow = f.at(bedU, headEnd, hump.mattressTop - 0.45)
	bedroom.GuestSpot.CFrame = CFrame.lookAt(pillow, pillow + kidFace, kidUp)
	local sit = f.at(bedU - 0.5, headEnd - 2.2, hump.mattressTop)
	bedroom.GuestSpot:SetAttribute("SitPoint", CFrame.lookAt(sit, sit + f.dir(-f.side, 0, 0)))

	furnishing.Parent = bedroom
end

return RoomStyles
