-- Every roster species except the Jeff stand-in. A model in ServerStorage.MonsterModels named after the species id is used
-- when one exists: that's the replacement hook, with no code to change. Otherwise it's a labelled placeholder made of parts.
local MonsterRig = {}

local SHAPES = {Enum.PartType.Ball, Enum.PartType.Block, Enum.PartType.Cylinder}

local function hash(id: string): number
	local h = 7
	for i = 1, #id do h = (h * 31 + id:byte(i)) % 104729 end
	return h
end

-- a stable colour and shape per species, so placeholders can be told apart
function MonsterRig.look(kind: string)
	local h = hash(kind)
	return {
		shape = SHAPES[h % #SHAPES + 1],
		color = Color3.fromHSV((h % 360) / 360, 0.55, 0.95),
		size = 3 + (h % 5) * 0.25,
	}
end

local function part(parent, name, shape, size, cf, color)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Parent = parent
	return p
end

local function placeholder(kind: string, origin: CFrame)
	local look = MonsterRig.look(kind)
	local model = Instance.new("Model")
	local s = look.size
	-- cylinders run along X, so stand them up
	local upright = if look.shape == Enum.PartType.Cylinder then CFrame.Angles(0, 0, math.pi / 2) else CFrame.identity
	part(model, "Body", look.shape, Vector3.one * s, origin * CFrame.new(0, s / 2, 0) * upright, look.color)
	local dark = Color3.fromRGB(25, 15, 45)
	for _, x in {-0.28, 0.28} do
		part(model, "Eye", Enum.PartType.Ball, Vector3.one * s * 0.22, origin * CFrame.new(x * s, s * 0.62, -s * 0.46), dark)
	end
	return model
end

-- origin is the spot under its feet, facing -Z. rig tells the client animator what to do; label names placeholders in the case.
function MonsterRig.build(parent, origin: CFrame, kind: string, rig: string, scale: number?, label: string?)
	local models = game:GetService("RunService"):IsServer() and game:GetService("ServerStorage"):FindFirstChild("MonsterModels")
	local custom = models and models:FindFirstChild(kind)
	local model
	if custom then
		model = custom:Clone()
		model:PivotTo(origin)
	else
		model = placeholder(kind, origin)
		if label then
			local bb = Instance.new("BillboardGui") bb.Size = UDim2.fromScale(7, 1) bb.StudsOffset = Vector3.new(0, 4.6, 0) bb.MaxDistance = 40
			local t = Instance.new("TextLabel") t.Size = UDim2.fromScale(1, 1) t.BackgroundTransparency = 1 t.Font = Enum.Font.FredokaOne t.TextScaled = true
			t.TextColor3 = Color3.new(1, 1, 1) t.TextStrokeTransparency = 0 t.Text = label .. " (placeholder)" t.Parent = bb
			bb.Parent = model:FindFirstChild("Body")
		end
	end
	model.Name = "Monster"
	model:SetAttribute("Rig", rig)
	model:SetAttribute("Kind", kind)
	model.WorldPivot = origin
	if scale and scale ~= 1 then model:ScaleTo(scale) end
	model.Parent = parent
	return model
end

-- the small version held in the hand, welded to the Tool's Handle
function MonsterRig.buildMini(tool, kind: string)
	local look = MonsterRig.look(kind)
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Shape = look.shape
	handle.Size = Vector3.one * 1.1
	handle.Color = look.color
	handle.Material = Enum.Material.SmoothPlastic
	handle.CanCollide = false
	handle.Massless = true
	handle.Parent = tool
	return handle
end

return MonsterRig
