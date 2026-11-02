-- An arrow on the screen that points at a place in the world and always stays on screen, on any screen size.
-- The tutorial and the tracker share it.
local GuideArrow = {}
GuideArrow.__index = GuideArrow

local EDGE = 70 -- pixels it keeps from the screen edge

function GuideArrow.new(gui, color: Color3)
	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.AnchorPoint = Vector2.new(0.5, 0.5)
	arrow.Size = UDim2.fromOffset(72, 72)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextScaled = true
	arrow.Text = "➤"
	arrow.TextColor3 = color
	arrow.TextStrokeTransparency = 0
	arrow.Visible = false
	arrow.Parent = gui
	return setmetatable({arrow = arrow}, GuideArrow)
end

function GuideArrow:hide()
	self.arrow.Visible = false
end

-- at a spot on the screen, turned to an angle in degrees (0 points right, 90 points down)
function GuideArrow:pointAtScreen(position: Vector2, angle: number)
	local size = workspace.CurrentCamera.ViewportSize
	self.arrow.Position = UDim2.fromOffset(math.clamp(position.X, EDGE, math.max(EDGE, size.X - EDGE)), math.clamp(position.Y, EDGE, math.max(EDGE, size.Y - EDGE)))
	self.arrow.Rotation = angle
	self.arrow.Visible = true
end

-- bobbing above a place you can see; otherwise from the middle of the screen, toward it
function GuideArrow:pointAt(worldPosition: Vector3)
	local camera = workspace.CurrentCamera
	local screen, onScreen = camera:WorldToViewportPoint(worldPosition)
	if onScreen and screen.Z > 0 then
		self:pointAtScreen(Vector2.new(screen.X, screen.Y - 60 + math.sin(os.clock() * 5) * 8), 90)
		return
	end
	local middle = camera.ViewportSize / 2
	local toward = Vector2.new(screen.X, screen.Y) - middle
	if screen.Z < 0 then toward = -toward end
	if toward.Magnitude < 1 then toward = Vector2.new(0, 1) end
	local unit = toward.Unit
	self:pointAtScreen(middle + unit * math.min(middle.X - EDGE, middle.Y - EDGE), math.deg(math.atan2(unit.Y, unit.X)))
end

return GuideArrow
