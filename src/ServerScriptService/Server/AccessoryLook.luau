-- What each accessory looks like on a display case: small original shapes made of parts, swappable for models later.
local AccessoryLook = {}

-- shape, size, colour; the rarer boxes glow
AccessoryLook.LOOKS = {
	BoneCharm = {shape = "Ball", size = 0.7, color = Color3.fromRGB(240, 235, 215)},
	SqueakyBat = {shape = "Block", size = 0.8, color = Color3.fromRGB(90, 60, 130)},
	CobwebBanner = {shape = "Block", size = 0.9, color = Color3.fromRGB(220, 225, 235)},
	LanternTag = {shape = "Cylinder", size = 0.8, color = Color3.fromRGB(255, 170, 70)},
	EnchantedChime = {shape = "Cylinder", size = 1, color = Color3.fromRGB(150, 230, 255), glow = 6},
	GhostCamera = {shape = "Block", size = 1, color = Color3.fromRGB(70, 70, 90), glow = 6},
	MoonMirror = {shape = "Ball", size = 1, color = Color3.fromRGB(205, 220, 255), glow = 7},
	TrickLantern = {shape = "Cylinder", size = 1.1, color = Color3.fromRGB(255, 120, 200), glow = 7},
	ClockworkHalo = {shape = "Cylinder", size = 1.4, color = Color3.fromRGB(255, 215, 90), glow = 10, neon = true},
	PhantomProjector = {shape = "Block", size = 1.3, color = Color3.fromRGB(120, 255, 220), glow = 10, neon = true},
	ShadowOrgan = {shape = "Block", size = 1.5, color = Color3.fromRGB(120, 60, 200), glow = 10, neon = true},
	RiftHourglass = {shape = "Cylinder", size = 1.6, color = Color3.fromRGB(255, 80, 200), glow = 14, neon = true},
	HeartOfMidnight = {shape = "Ball", size = 1.6, color = Color3.fromRGB(230, 30, 90), glow = 14, neon = true},
	LivingMoon = {shape = "Ball", size = 1.8, color = Color3.fromRGB(235, 240, 255), glow = 16, neon = true},
}

-- puts the look on top of a case's lid, replacing any old one; pass nil for an empty case
function AccessoryLook.show(bedroom, accessoryId: string?)
	local old = bedroom:FindFirstChild("CaseAccessory")
	if old then old:Destroy() end
	local look = accessoryId and AccessoryLook.LOOKS[accessoryId]
	if not look then return end
	local lid = bedroom.ShowcaseLid
	local p = Instance.new("Part")
	p.Name = "CaseAccessory"
	p.Shape = Enum.PartType[look.shape]
	p.Size = Vector3.one * look.size
	p.Color = look.color
	p.Material = if look.neon then Enum.Material.Neon else Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.CFrame = lid.CFrame * CFrame.new(0, lid.Size.Y / 2 + look.size / 2, 0)
	if look.glow then
		local light = Instance.new("PointLight")
		light.Color = look.color
		light.Range = look.glow
		light.Brightness = 0.8
		light.Shadows = false
		light.Parent = p
	end
	p.Parent = bedroom
end

return AccessoryLook
