-- Same-species fusion: 4 Normal -> Large, 3 Large -> Mega, 3 Mega -> MASSIVE. Everything is checked before anything
-- changes, and nothing yields, so a fusion either completes in full or changes nothing. Works on a save table.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local DataTemplate = require(script.Parent.DataTemplate)
local Inventory = require(script.Parent.Inventory)

local F = Config.Balance.fusion
local recipeFrom = {}
for _, recipe in F.recipes do recipeFrom[recipe.from] = recipe end

local Fusion = {}

-- Fuses exactly these monsters. Returns the new uid, or nil and why.
-- The new monster has a new id and keeps the best base payout among those used, so a fusion never lowers it.
function Fusion.fuse(d, uids: {string}): (string?, string?)
	local first = d.Monsters[uids[1]]
	if not first then return nil, "missing" end
	local recipe = recipeFrom[first.Size]
	if not recipe then return nil, "maxSize" end
	if #uids ~= recipe.count then return nil, "count" end
	local best, seen = 0, {}
	for _, uid in uids do
		local m = d.Monsters[uid]
		if not m or seen[uid] then return nil, "missing" end
		seen[uid] = true
		if m.Kind ~= first.Kind or m.Tier ~= first.Tier or m.Size ~= first.Size then return nil, "different" end
		if F.requireSameMutation and m.Mutation ~= first.Mutation then return nil, "different" end
		if m.Favorited then return nil, "favorite" end
		if Inventory.placedIn(d, uid) then return nil, "placed" end
		best = math.max(best, m.BaseFear)
	end
	for _, uid in uids do
		d.Monsters[uid] = nil
		local at = table.find(d.Hotbar, uid)
		if at then table.remove(d.Hotbar, at) end
	end
	local result = DataTemplate.newMonster(first.Kind, first.Tier, best, "fusion", first.Mutation)
	result.Size = recipe.id
	return Inventory.add(d, result)
end

return Fusion
