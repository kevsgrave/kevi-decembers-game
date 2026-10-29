-- Furnishes a bedroom in one of three styles that match its tier: Cozy (Normal), Fancy (Silver), Gold Luxury (Gold and up).
-- Furniture models are AI-generated meshes stored in ServerStorage.Furniture; walls, floor, trim, rugs and lights are parts.
-- All spots are given in room coordinates: u = studs in from the front wall, w = studs along the room toward the display case.
local ServerStorage = game:GetService("ServerStorage")

local RoomStyles = {}

local function styleFor(tierName)
	if tierName == "Normal" then return "Cozy" end
	if tierName == "Silver" then return "Fancy" end
	return "Luxury"
end
RoomStyles.styleFor = styleFor

local GOLD = Color3.fromRGB(255, 200, 70)
local STYLES = {
	Cozy = {
		floor = {Color3.fromRGB(170, 120, 80), Enum.Material.WoodPlanks},
		walls = nil, -- keep each room's own pastel wallpaper
		ceiling = Color3.fromRGB(255, 245, 230),
		mattressTop = 3.4,
		curtains = Color3.fromRGB(255, 220, 120),
		rug = {Color3.fromRGB(120, 200, 255), Color3.fromRGB(255, 255, 255)},
		furniture = {
			{"CozyBed", 15, -5, "bed"},
			{"CozyNightstand", 15, 3.2, "front"},
			{"CozyToyChest", 24, -11, "front"},
		},
		lights = {{15, 3.2, 4.6, Color3.fromRGB(255, 170, 90)}}, -- nightstand lamp
	},
	Fancy = {
		floor = {Color3.fromRGB(235, 232, 240), Enum.Material.Marble},
		walls = Color3.fromRGB(222, 208, 245),
		wainscot = Color3.fromRGB(250, 250, 255),
		trim = Color3.fromRGB(200, 200, 215),
		crown = Color3.fromRGB(215, 215, 230),
		ceiling = Color3.fromRGB(250, 248, 255),
		mattressTop = 3.6,
		curtains = Color3.fromRGB(190, 170, 235),
		rug = {Color3.fromRGB(205, 200, 220), Color3.fromRGB(240, 240, 250)},
		furniture = {
			{"FancyBed", 15, -5, "bed"},
			{"FancyDresser", 26, 6, "front"},
			{"FancyArmchair", 23, -11, "front"},
		},
		lights = {{27.3, 9, 9, Color3.fromRGB(220, 200, 255), "sconce"}}, -- wall light above the dresser
	},
	Luxury = {
		floor = {Color3.fromRGB(95, 55, 35), Enum.Material.WoodPlanks},
		walls = Color3.fromRGB(150, 30, 50),
		wainscot = Color3.fromRGB(110, 20, 35),
		trim = GOLD,
		crown = GOLD,
		ceiling = Color3.fromRGB(120, 20, 35),
		mattressTop = 3.6,
		curtains = Color3.fromRGB(180, 20, 40),
		rug = {Color3.fromRGB(170, 25, 45), GOLD},
		furniture = {
			{"LuxuryBed", 15, -5, "bed"},
			{"LuxuryThrone", 24, -11, "front"},
			{"LuxuryChest", 23, 8, "front"},
			{"LuxuryChandelier", 7, -5, "ceiling"}, -- in front of the canopy, seen through the window
		},
		lights = {{7, -5, 11, Color3.fromRGB(255, 190, 110)}}, -- chandelier, kept dim for sleeping kids
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

-- the room's frame, read from its own walls so it works on both sides of the aisle
local function frame(bedroom)
	local floor = bedroom.RoomFloor
	local side = math.sign(floor.Position.X)
	local front = math.abs(bedroom.FrontLow.Position.X)
	local back = math.abs(bedroom.BackWall.Position.X)
	local floorTop = floor.Position.Y + floor.Size.Y / 2
	local zc = floor.Position.Z
	local L = -side -- +w runs toward the display case (the room's left as seen from the aisle)
	local function at(u, w, y) return Vector3.new(side * (front + u), floorTop + (y or 0), zc + L * w) end
	return {side = side, L = L, at = at, depth = back - front, half = floor.Size.Z / 2, floorTop = floorTop, height = bedroom.BackWall.Size.Y}
end

-- one-time cleanup of the old block furniture; the bed's old frame stays as an invisible anchor
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

	-- wainscot, trim and crown moulding along the back and side walls (inside faces)
	local inset = 0.6
	local function alongWalls(prefix, height, y, color, material)
		local back = f.at(f.depth - inset, 0, y)
		block(furnishing, prefix .. "Back", Vector3.new(0.2, height, f.half * 2 - 1), CFrame.new(back), color, material)
		for _, sgn in ipairs({-1, 1}) do
			local p = f.at(f.depth / 2, sgn * (f.half - inset), y)
			block(furnishing, prefix .. "Side", Vector3.new(f.depth - 1, height, 0.2), CFrame.new(p), color, material)
		end
	end
	if style.wainscot then alongWalls("Wainscot", 4.5, 2.25, style.wainscot) end
	if style.trim then alongWalls("Trim", 0.45, 4.6, style.trim, Enum.Material.Metal) end
	if style.crown then alongWalls("Crown", 0.6, f.height - 0.5, style.crown, Enum.Material.Metal) end
	block(furnishing, "Ceiling", Vector3.new(f.depth, 0.2, f.half * 2), CFrame.new(f.at(f.depth / 2, 0, f.height - 0.15)), style.ceiling)

	-- curtains either side of the window (window spans w -12..2 on the front wall)
	for _, w in ipairs({-12.3, 2.3}) do
		block(furnishing, "Curtain", Vector3.new(0.4, 10, 1.6), CFrame.new(f.at(0.9, w, 8)), style.curtains, Enum.Material.Fabric)
	end
	block(furnishing, "CurtainRod", Vector3.new(0.3, 0.3, 16.5), CFrame.new(f.at(0.9, -5, 13.2)), GOLD, Enum.Material.Metal)

	-- a round rug with a border
	local rugCf = CFrame.new(f.at(9, -5, 0.08)) * CFrame.Angles(0, 0, math.pi / 2)
	block(furnishing, "RugBorder", Vector3.new(0.12, 11, 11), rugCf, style.rug[2], Enum.Material.Fabric).Shape = Enum.PartType.Cylinder
	block(furnishing, "Rug", Vector3.new(0.16, 9.6, 9.6), rugCf, style.rug[1], Enum.Material.Fabric).Shape = Enum.PartType.Cylinder

	-- furniture models
	for _, item in ipairs(style.furniture) do
		local modelName, u, w, facing = item[1], item[2], item[3], item[4]
		local src = ServerStorage.Furniture:FindFirstChild(modelName)
		if src then
			local m = src:Clone()
			m.Name = facing == "bed" and "Bed" or modelName
			local pos = f.at(u, w, 0)
			local cf
			if facing == "bed" then
				cf = CFrame.lookAt(pos, pos - Vector3.new(0, 0, f.L)) -- headboard toward +w
			elseif facing == "ceiling" then
				local _, size = m:GetBoundingBox()
				pos = f.at(u, w, f.height - size.Y - 0.2)
				cf = CFrame.lookAt(pos, pos + Vector3.new(-f.side, 0, 0))
			else
				cf = CFrame.lookAt(pos, pos + Vector3.new(-f.side, 0, 0)) -- face the window
			end
			m:PivotTo(cf)
			m.Parent = furnishing
		end
	end

	-- dim warm lights: the kids are asleep
	for _, l in ipairs(style.lights) do
		local glow = block(furnishing, "NightGlow", Vector3.new(0.6, 0.6, 0.6), CFrame.new(f.at(l[1], l[2], l[3])), l[4], Enum.Material.Neon)
		glow.Shape = Enum.PartType.Ball
		if l[5] == "sconce" then glow.Size = Vector3.new(0.5, 1.2, 0.8) glow.Shape = Enum.PartType.Block end
		glow.Transparency = l[5] == "sconce" and 0 or 1
		local light = Instance.new("PointLight") light.Color = l[4] light.Range = 13 light.Brightness = 0.6 light.Parent = glow
	end

	-- the kid sits up in this style's bed, head above the pillow end
	local spot = bedroom.GuestSpot
	local headY = f.floorTop + style.mattressTop + 2.6
	spot.CFrame = CFrame.new(spot.Position.X, headY, spot.Position.Z) * (spot.CFrame - spot.CFrame.Position)

	furnishing.Parent = bedroom
end

return RoomStyles
