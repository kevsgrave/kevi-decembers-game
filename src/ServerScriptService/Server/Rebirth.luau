-- Rebirth: pays a rising cost from your Fear and keeps the rest, keeps every monster and item, and adds a room and a multiplier.
-- Keeping the leftover Fear is the owner's decision (docs/spec/OVERRIDES.md). Works on a save table with no yields.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Rebirth = {}

-- Returns true, or false and why: maxed, cooldown or poor (with the cost).
function Rebirth.apply(d, lastAt: number?, now: number): (boolean, string?, number?)
	if Config.unlockedBedrooms(d.Rebirths) >= Config.MAX_BEDROOMS then return false, "maxed" end
	if lastAt and now - lastAt < Config.Balance.rebirth.cooldownSeconds then return false, "cooldown" end
	local cost = Config.rebirthCost(d.Rebirths)
	if d.Fear < cost then return false, "poor", cost end
	d.Fear -= cost
	d.Rebirths += 1
	return true
end

return Rebirth
