-- Plots stand in a ring at different angles, so room maths is done in plot-local space.
-- A plot Model carries its frame as the "Frame" attribute (local origin at the plot's centre line, front toward -Z).
local PlotFrame = {}

-- the frame of the plot an instance belongs to (identity for the un-placed template in ServerStorage)
function PlotFrame.of(inst)
	local node = inst
	while node do
		local frame = node:GetAttribute("Frame")
		if typeof(frame) == "CFrame" then return frame end
		node = node.Parent
	end
	return CFrame.identity
end

-- move a template copy (authored at the origin) into a plot frame, keeping every part's local placement
function PlotFrame.place(inst, frame)
	if inst:IsA("PVInstance") then
		inst:PivotTo(frame * inst:GetPivot())
	else
		for _, child in ipairs(inst:GetChildren()) do PlotFrame.place(child, frame) end
	end
end

return PlotFrame
