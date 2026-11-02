-- Makes the map move: ghosts drift and blink, machine parts spin, bob and glow. MapBuilder tags what moves and sets its
-- attributes. This is only decoration on this player's screen; the server never sees it.
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local MapMotion = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("MapMotion"))

local RANGE = 260 -- nothing moves further away than this, to keep phones running well
local STEP = 1 / 30

local blinked = {}
setmetatable(blinked, {__mode = "k"})

local function near(home, camera)
	return (home.Position - camera).Magnitude < RANGE
end

local function moveTo(inst, cf)
	if inst:IsA("Model") then inst:PivotTo(cf) elseif inst:IsA("BasePart") then inst.CFrame = cf end
end

local function setBlink(ghost, shut)
	if blinked[ghost] == shut then return end
	blinked[ghost] = shut
	for _, part in ghost:GetChildren() do
		if part.Name == "Eye" or part.Name == "Glint" then part.Transparency = shut and 1 or 0 end
		if part.Name == "Lid" then part.Transparency = shut and 0 or 1 end
	end
end

local waited = 0
RunService.Heartbeat:Connect(function(dt)
	waited += dt
	if waited < STEP then return end
	waited = 0
	local t = os.clock()
	local camera = workspace.CurrentCamera.CFrame.Position

	for _, ghost in CollectionService:GetTagged("Ghost") do
		local home = ghost:GetAttribute("Home")
		if home and near(home, camera) then
			local phase = ghost:GetAttribute("Phase") or 0
			moveTo(ghost, MapMotion.ghost(home, t, phase, ghost:GetAttribute("Drift") or 0))
			setBlink(ghost, MapMotion.blinking(t, phase))
		end
	end

	for _, inst in CollectionService:GetTagged("Life") do
		local home = inst:GetAttribute("Home")
		if home and near(home, camera) then
			local pulse = inst:GetAttribute("Pulse")
			if pulse then
				inst.Transparency = MapMotion.pulse(inst:GetAttribute("Base") or 0, t, pulse)
			end
			local spin, bob = inst:GetAttribute("Spin"), inst:GetAttribute("Bob") or 0
			if spin or bob ~= 0 then
				moveTo(inst, MapMotion.part(home, t, inst:GetAttribute("Phase") or 0, spin, bob, inst:GetAttribute("BobSpeed") or 1.5))
			end
		end
	end
end)
