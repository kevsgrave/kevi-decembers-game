-- The five-minute shop. The lineup is worked out from the rotation number, so every server shows the same one and nothing
-- needs storing. Stock is each player's own allotment, saved per rotation. Works on a save table with no yields, so a
-- purchase can't interleave with another. Prices and items only ever come from Config; the client just names what it wants.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
local Inventory = require(script.Parent.Inventory)
local Tracker = require(script.Parent.Tracker)

local B = Config.Balance.shop
local itemsById = {}
for _, item in B.items do itemsById[item.id] = item end

local Shop = {}

function Shop.rotationAt(now: number): number
	return math.floor(now / B.rotationSeconds)
end

function Shop.endsAt(rotation: number): number
	return (rotation + 1) * B.rotationSeconds
end

-- the item ids on sale in a rotation: each rolls its chance, then the list is held between offersMin and offersMax,
-- keeping the likeliest. The same rotation always gives the same lineup.
function Shop.lineup(rotation: number): {string}
	-- scrambled so neighbouring rotations can't roll alike
	local rng = Random.new((rotation * 48271) % 2147483647)
	for _ = 1, 8 do rng:NextNumber() end
	local chosen = {}
	local byChance = table.clone(B.items)
	table.sort(byChance, function(a, b) return a.appearChance > b.appearChance end)
	for _, item in byChance do
		if rng:NextNumber(0, 100) < item.appearChance then table.insert(chosen, item.id) end
	end
	for _, item in byChance do
		if #chosen >= B.offersMin then break end
		if not table.find(chosen, item.id) then table.insert(chosen, item.id) end
	end
	while #chosen > B.offersMax do table.remove(chosen) end
	return chosen
end

local function boughtIn(d, rotation: number)
	if d.ShopBought.Rotation ~= rotation then
		d.ShopBought.Rotation = rotation
		d.ShopBought.Items = {}
	end
	return d.ShopBought.Items
end

-- what this player sees right now
function Shop.stateFor(d, now: number)
	local rotation = Shop.rotationAt(now)
	local bought = boughtIn(d, rotation)
	local offers = {}
	for _, id in Shop.lineup(rotation) do
		local item = itemsById[id]
		table.insert(offers, {id = id, kind = item.kind, price = item.price, stock = item.stock, left = item.stock - (bought[id] or 0)})
	end
	return {rotation = rotation, endsAt = Shop.endsAt(rotation), offers = offers}
end

-- Returns true, or false and why: stale, unavailable, soldOut or poor.
-- The rotation is the one the client was looking at, so a slow purchase can't buy from a shop that has changed.
function Shop.buy(d, itemId: string, clientRotation: number, now: number): (boolean, string?)
	local rotation = Shop.rotationAt(now)
	if clientRotation ~= rotation then return false, "stale" end
	local item = itemsById[itemId]
	if not item or not table.find(Shop.lineup(rotation), itemId) then return false, "unavailable" end
	local bought = boughtIn(d, rotation)
	if (bought[itemId] or 0) >= item.stock then return false, "soldOut" end
	if d.Fear < item.price then return false, "poor" end
	d.Fear -= item.price
	bought[itemId] = (bought[itemId] or 0) + 1
	if item.kind == "box" then
		Inventory.addBox(d, itemId)
	else
		Tracker.add(d)
	end
	return true
end

return Shop
