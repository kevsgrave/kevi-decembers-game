-- Lets the HUD's buttons open screens built by other scripts, one at a time.
local Panels = {}

local openers = {}
local frames = {}

-- frame is what to hide when another screen opens; open is called to show it
function Panels.register(name: string, open: () -> (), frame: GuiObject)
	openers[name] = open
	frames[name] = frame
end

function Panels.closeAll()
	for _, frame in frames do frame.Visible = false end
end

function Panels.open(name: string)
	local open = openers[name]
	if not open then return end
	Panels.closeAll()
	open()
end

-- open it, or close it if it's already showing
function Panels.toggle(name: string)
	local frame = frames[name]
	if frame and frame.Visible then
		frame.Visible = false
	else
		Panels.open(name)
	end
end

return Panels
