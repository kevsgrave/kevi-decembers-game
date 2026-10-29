-- The three sleepy guest kids: AI-generated chibi animal models in pajamas (ServerStorage.KidModels).
-- A kid lies asleep on its back in bed; when scared it sits up (GuestKids.wake), then the server makes it jump.
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local GuestKids = {}

GuestKids.KINDS = {
	{name = "Clover Fawn", model = "KidFawn"},
	{name = "Pip Bunny", model = "KidBunny"},
	{name = "Bramble Bear Cub", model = "KidBear"},
}

-- builds kid `kind` (1..3) asleep at `spot`: a pillow point whose up axis runs toward the headboard and whose
-- look direction is the ceiling. `sitPoint` (a CFrame on the mattress facing out) is where it sits up when scared.
function GuestKids.build(parent, spot, kind, sitPoint)
	local k = GuestKids.KINDS[kind]
	local m = ServerStorage.KidModels[k.model]:Clone()
	m.Name = "Guest"
	m:SetAttribute("Kid", k.name)
	local h, d = m:GetAttribute("Height"), m:GetAttribute("Depth")
	-- lying: head top at the pillow point, back sunk a little into the pillow and mattress
	m:PivotTo(spot * CFrame.new(0, -h / 2, -(d / 2 - 0.35)))
	if sitPoint then
		-- sitting: upright on the mattress, legs sunk under the blanket
		m:SetAttribute("SitCFrame", sitPoint * CFrame.new(0, h / 2 - 1.2, 0))
	end
	m.Parent = parent
	return m
end

function GuestKids.wake(m)
	local sit = m:GetAttribute("SitCFrame")
	if sit then m:PivotTo(sit) end
end

-- the scare reaction (yields about 1.6 s): bolt upright, a startled hop with a shake and a "!", a tremble, then it runs off
function GuestKids.scare(m)
	GuestKids.wake(m)
	local body = m.PrimaryPart
	local base = body.CFrame
	local bb = Instance.new("BillboardGui") bb.Size = UDim2.fromScale(1.6, 1.6) bb.StudsOffset = Vector3.new(0, 3.4, 0) bb.AlwaysOnTop = true bb.Parent = body
	local t = Instance.new("TextLabel") t.Size = UDim2.fromScale(1, 1) t.BackgroundTransparency = 1 t.Font = Enum.Font.FredokaOne
	t.TextScaled = true t.Text = "!" t.TextColor3 = Color3.fromRGB(255, 230, 60) t.TextStrokeTransparency = 0 t.Parent = bb
	for i = 1, 12 do -- hop with a side-to-side shake that settles
		local p = i / 12
		local shake = math.rad(12) * (1 - p) * ((i % 2 == 0) and 1 or -1)
		body.CFrame = base * CFrame.new(0, math.sin(p * math.pi) * 1.8, 0) * CFrame.Angles(0, 0, shake)
		task.wait(0.04)
	end
	for i = 1, 8 do -- trembling
		body.CFrame = base * CFrame.Angles(0, 0, math.rad(((i % 2 == 0) and 3 or -3)))
		task.wait(0.04)
	end
	body.CFrame = base
	-- runs off: a quick fade
	TweenService:Create(body, TweenInfo.new(0.35), {Transparency = 1}):Play()
	TweenService:Create(t, TweenInfo.new(0.35), {TextTransparency = 1, TextStrokeTransparency = 1}):Play()
	task.wait(0.4)
end

return GuestKids
