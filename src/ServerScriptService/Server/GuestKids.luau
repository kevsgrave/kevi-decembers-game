-- The three sleepy guest kids: AI-generated chibi animal models in pajamas (ServerStorage.KidModels).
-- A kid lies asleep on its back in bed; when scared it sits up (GuestKids.wake), then the server makes it jump.
local ServerStorage = game:GetService("ServerStorage")

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
	-- lying: head top at the pillow point, back on the mattress
	m:PivotTo(spot * CFrame.new(0, -h / 2, -d / 2))
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

return GuestKids
