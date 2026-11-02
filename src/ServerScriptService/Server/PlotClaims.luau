-- Who owns which plot. No yields anywhere, so two requests can never both win a plot. Works on any keys, so tests need no Studio objects.
local PlotClaims = {}
PlotClaims.__index = PlotClaims

function PlotClaims.new()
	return setmetatable({ownerOf = {}, plotOf = {}}, PlotClaims)
end

-- Returns true, or false and "already" (they own a plot) or "taken" (someone else owns this one)
function PlotClaims:claim(plot, player): (boolean, string?)
	if self.plotOf[player] ~= nil then return false, "already" end
	if self.ownerOf[plot] ~= nil then return false, "taken" end
	self.ownerOf[plot] = player
	self.plotOf[player] = plot
	return true
end

-- Frees the player's plot and returns it, or nil if they had none
function PlotClaims:release(player)
	local plot = self.plotOf[player]
	if plot == nil then return nil end
	self.plotOf[player] = nil
	self.ownerOf[plot] = nil
	return plot
end

return PlotClaims
