-- Fits fixed-size interface pieces to the screen: full size on a PC, down to 60% on a phone, and it follows screen rotation.
local UiFit = {}

function UiFit.factor(width: number, height: number): number
	return math.clamp(math.min(width / 1100, height / 650), 0.6, 1)
end

function UiFit.scale(object: GuiObject)
	local scale = Instance.new("UIScale")
	local camera = workspace.CurrentCamera
	local function update()
		scale.Scale = UiFit.factor(camera.ViewportSize.X, camera.ViewportSize.Y)
	end
	camera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
	scale.Parent = object
end

return UiFit
