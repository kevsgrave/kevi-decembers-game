-- The three sleepy guest kids (chibi animal style from the Obsidian reference): big round head, huge eyes, pajamas.
-- Built from parts welded to an anchored Head, so the scare tween on the head moves the whole kid.
-- Eyes start closed (asleep); GuestKids.wake(model) opens them.
local GuestKids = {}

local INK = Color3.fromRGB(25, 20, 30)
local WHITE = Color3.new(1, 1, 1)
local BLUSH = Color3.fromRGB(255, 140, 160)

GuestKids.KINDS = {
	{
		name = "Clover Fawn",
		fur = Color3.fromRGB(205, 120, 60), muzzle = Color3.fromRGB(250, 225, 190), nose = INK,
		pajamas = Color3.fromRGB(110, 185, 235), pants = Color3.fromRGB(60, 120, 220), feet = Color3.fromRGB(150, 80, 40),
		ears = "droopy", extra = "antlers", hat = Color3.fromRGB(90, 170, 230),
	},
	{
		name = "Pip Bunny",
		fur = Color3.fromRGB(245, 240, 248), muzzle = Color3.fromRGB(255, 255, 255), nose = Color3.fromRGB(255, 120, 160),
		pajamas = Color3.fromRGB(255, 160, 200), pants = Color3.fromRGB(240, 110, 170), feet = Color3.fromRGB(245, 240, 248),
		ears = "long",
	},
	{
		name = "Bramble Bear Cub",
		fur = Color3.fromRGB(140, 95, 60), muzzle = Color3.fromRGB(220, 180, 135), nose = INK,
		pajamas = Color3.fromRGB(130, 205, 120), pants = Color3.fromRGB(80, 160, 90), feet = Color3.fromRGB(110, 70, 45),
		ears = "round",
	},
}

local function part(model, name, size, cf, color, shape, material)
	local p = Instance.new("Part")
	p.Name = name p.Size = size p.CFrame = cf p.Color = color
	p.Anchored = false p.CanCollide = false p.CanQuery = false p.Massless = true
	p.Material = material or Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then p.Shape = shape end
	p.Parent = model
	return p
end

local BALL, CYL = Enum.PartType.Ball, Enum.PartType.Cylinder
local FACE_ON = CFrame.Angles(0, math.pi / 2, 0) -- turns a Cylinder's X axis to face forward (-Z)

-- builds kid `kind` (1..3) with its head centred on cf, facing cf.LookVector
function GuestKids.build(parent, cf, kind)
	local k = GuestKids.KINDS[kind]
	local m = Instance.new("Model") m.Name = "Guest"
	m:SetAttribute("Kid", k.name)
	local head = part(m, "Head", Vector3.new(2.6, 2.5, 2.5), cf, k.fur, BALL)
	head.Anchored = true
	local function add(name, size, offset, color, shape)
		local p = part(m, name, size, cf * offset, color, shape)
		local w = Instance.new("WeldConstraint") w.Part0 = head w.Part1 = p w.Parent = p
		return p
	end

	-- face: muzzle, nose, blush, and big eyes (open set hidden while asleep)
	add("Muzzle", Vector3.new(1.1, 0.75, 0.7), CFrame.new(0, -0.5, -1.0), k.muzzle, BALL)
	add("Nose", Vector3.new(0.32, 0.24, 0.24), CFrame.new(0, -0.32, -1.36), k.nose, BALL)
	for _, x in ipairs({-1, 1}) do
		add("Blush", Vector3.new(0.4, 0.25, 0.2), CFrame.new(x * 0.82, -0.3, -0.92), BLUSH, BALL).Transparency = 0.25
		local eye = CFrame.new(x * 0.52, 0.18, -1.06) * CFrame.Angles(0, -x * 0.42, 0)
		add("EyeOpenWhite", Vector3.new(0.08, 0.85, 0.85), eye * FACE_ON, WHITE, CYL)
		add("EyeOpenPupil", Vector3.new(0.08, 0.62, 0.62), eye * CFrame.new(0, -0.03, -0.05) * FACE_ON, INK, CYL)
		add("EyeOpenShine", Vector3.new(0.16, 0.16, 0.16), eye * CFrame.new(x * 0.12, 0.12, -0.1), WHITE, BALL)
		add("EyeClosed", Vector3.new(0.55, 0.09, 0.09), eye * CFrame.new(0, -0.05, -0.04) * CFrame.Angles(0, 0, x * 0.15), INK)
	end

	-- ears and head extras
	for _, x in ipairs({-1, 1}) do
		if k.ears == "droopy" then
			add("Ear", Vector3.new(1.0, 0.42, 0.55), CFrame.new(x * 1.3, 0.3, 0) * CFrame.Angles(0, 0, -x * 0.45), k.fur, BALL)
			add("EarInner", Vector3.new(0.65, 0.2, 0.35), CFrame.new(x * 1.32, 0.3, -0.12) * CFrame.Angles(0, 0, -x * 0.45), BLUSH, BALL)
		elseif k.ears == "long" then
			add("Ear", Vector3.new(0.55, 1.9, 0.35), CFrame.new(x * 0.48, 1.95, 0.1) * CFrame.Angles(0, 0, -x * 0.12), k.fur, BALL)
			add("EarInner", Vector3.new(0.3, 1.45, 0.12), CFrame.new(x * 0.48, 1.95, -0.05) * CFrame.Angles(0, 0, -x * 0.12), BLUSH, BALL)
		else
			add("Ear", Vector3.new(0.8, 0.8, 0.45), CFrame.new(x * 0.98, 1.0, 0.1), k.fur, BALL)
			add("EarInner", Vector3.new(0.45, 0.45, 0.2), CFrame.new(x * 0.98, 1.0, -0.06), k.muzzle, BALL)
		end
		if k.extra == "antlers" then
			add("Antler", Vector3.new(0.2, 0.75, 0.2), CFrame.new(x * 0.55, 1.55, 0.15) * CFrame.Angles(0, 0, -x * 0.25), Color3.fromRGB(255, 200, 70))
			add("AntlerTip", Vector3.new(0.18, 0.4, 0.18), CFrame.new(x * 0.8, 1.75, 0.15) * CFrame.Angles(0, 0, -x * 0.9), Color3.fromRGB(255, 200, 70))
		end
	end
	if k.hat then -- a soft nightcap like the reference's round cap
		add("Cap", Vector3.new(2.2, 0.9, 2.2), CFrame.new(0, 1.0, 0.05), k.hat, BALL)
		add("CapBand", Vector3.new(0.28, 2.25, 2.25), CFrame.new(0, 0.72, 0.05) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(50, 110, 200), CYL)
	end

	-- small pajama body with mitten hands and stubby legs
	add("Body", Vector3.new(1.9, 1.8, 1.5), CFrame.new(0, -2.05, 0.05), k.pajamas, BALL)
	add("Collar", Vector3.new(0.25, 1.2, 1.2), CFrame.new(0, -1.25, 0.05) * CFrame.Angles(0, 0, math.pi / 2), WHITE, CYL)
	for i, y in ipairs({-1.75, -2.25}) do
		add("Button" .. i, Vector3.new(0.18, 0.18, 0.18), CFrame.new(0, y, -0.72), WHITE, BALL)
	end
	for _, x in ipairs({-1, 1}) do
		add("Arm", Vector3.new(0.55, 1.25, 0.55), CFrame.new(x * 1.05, -2.0, 0) * CFrame.Angles(0, 0, x * 0.35), k.pajamas, BALL)
		add("Hand", Vector3.new(0.55, 0.55, 0.55), CFrame.new(x * 1.3, -2.6, -0.1), WHITE, BALL)
		add("Leg", Vector3.new(0.7, 1.0, 0.7), CFrame.new(x * 0.45, -3.15, 0.05), k.pants, BALL)
		add("Foot", Vector3.new(0.75, 0.45, 0.95), CFrame.new(x * 0.45, -3.62, -0.12), k.feet, BALL)
	end

	GuestKids.sleep(m)
	m.PrimaryPart = head
	m.Parent = parent
	return m
end

local function setEyes(m, open)
	for _, p in ipairs(m:GetChildren()) do
		if p.Name:sub(1, 7) == "EyeOpen" then p.Transparency = open and 0 or 1 end
		if p.Name == "EyeClosed" then p.Transparency = open and 1 or 0 end
	end
end
function GuestKids.sleep(m) setEyes(m, false) end
function GuestKids.wake(m) setEyes(m, true) end

return GuestKids
