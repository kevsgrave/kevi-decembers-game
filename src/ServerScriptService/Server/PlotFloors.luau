-- The structure of an upper floor, made of parts: a blue studded deck, a pink aisle, a low wall, and lift pads between floors.
-- Lift pads rather than stairs because a floor is 32 studs up, and stairs that long would fill the aisle.
local PlotLayout = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("PlotLayout"))

local PlotFloors = {}

local STUDS = "rbxassetid://6372755229"
local PLOT_BLUE = Color3.fromRGB(70, 110, 230)
local CARPET_PINK = Color3.fromRGB(255, 50, 130)
local STONE = Color3.fromRGB(105, 98, 135)
local PAD_PURPLE = Color3.fromRGB(170, 90, 255)
local FLOOR_TOP = 2 -- the plot's deck surface, in plot-local height

local function part(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name p.Size = size p.CFrame = cf p.Color = color p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true p.TopSurface = Enum.SurfaceType.Smooth p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function studs(p)
	for _, face in ipairs({Enum.NormalId.Top, Enum.NormalId.Bottom, Enum.NormalId.Front, Enum.NormalId.Back, Enum.NormalId.Left, Enum.NormalId.Right}) do
		local t = Instance.new("Texture") t.Texture = STUDS t.Face = face t.StudsPerTileU = 4 t.StudsPerTileV = 4
		t.Color3 = Color3.new(0, 0, 0) t.Transparency = 0.75 t.Parent = p
	end
end

local function pad(parent, name, cf, action)
	local p = part(parent, name, Vector3.new(8, 0.3, 8), cf, PAD_PURPLE, Enum.Material.Neon)
	p.CanCollide = false
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "LiftPrompt"
	prompt.ActionText = action
	prompt.ObjectText = "Lift"
	prompt.HoldDuration = 0.2
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = p
	return p
end

-- builds floor (2 or higher) on a plot and returns its folder, plus its two lift pads: up from the floor below, down from this one
function PlotFloors.build(parent, floor: number, frame: CFrame)
	local folder = Instance.new("Folder")
	folder.Name = "Floor" .. floor
	local y = PlotLayout.floorHeight(floor)
	local below = PlotLayout.floorHeight(floor - 1)
	local function L(x, h, z) return frame * CFrame.new(x, h, z) end

	studs(part(folder, "Deck", Vector3.new(96, 2, 116), L(0, y + 1, -4), PLOT_BLUE))
	local carpet = part(folder, "Carpet", Vector3.new(12, 0.2, 112), L(0, y + FLOOR_TOP + 0.1, -4), CARPET_PINK, Enum.Material.Fabric)
	studs(carpet)
	for _, z in ipairs({-40, 0, 40}) do
		local glow = part(folder, "AisleLight", Vector3.new(0.5, 0.5, 0.5), L(0, y + 12, z), Color3.fromRGB(255, 170, 80), Enum.Material.Neon)
		glow.Transparency = 1
		glow.CanCollide = false
		local light = Instance.new("PointLight") light.Color = glow.Color light.Range = 28 light.Brightness = 0.8 light.Shadows = false light.Parent = glow
	end
	-- a low wall all round, so nobody walks off the edge by accident
	for _, w in ipairs({
		{"WallLeft", Vector3.new(2, 4, 118), -49, -4},
		{"WallRight", Vector3.new(2, 4, 118), 49, -4},
		{"WallBack", Vector3.new(96, 4, 2), 0, 55},
		{"WallFront", Vector3.new(96, 4, 2), 0, -63},
	}) do
		studs(part(folder, w[1], w[2], L(w[3], y + FLOOR_TOP + 2, w[4]), STONE))
	end

	-- corner pillars, so the deck doesn't float
	local pillarHeight = y - (below + FLOOR_TOP)
	for _, xz in ipairs({{-47, -61}, {47, -61}, {-47, 53}, {47, 53}}) do
		studs(part(folder, "Pillar", Vector3.new(3, pillarHeight, 3), L(xz[1], below + FLOOR_TOP + pillarHeight / 2, xz[2]), STONE))
	end

	local up = pad(folder, "LiftUp", L(0, below + FLOOR_TOP + 0.35, 46), "Go Up")
	local down = pad(folder, "LiftDown", L(0, y + FLOOR_TOP + 0.35, -54), "Go Down")
	folder.Parent = parent
	return folder, up, down
end

return PlotFloors
