-- The rules for owned monsters, working only on a player's save table. No yields and no Studio objects, so requests
-- can't interleave and every rule can be tested in Edit mode. GameService checks who is asking and how far away they are.
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local Inventory = {}

local function count(d): number
	local n = 0
	for _ in d.Monsters do n += 1 end
	return n
end
Inventory.count = count

function Inventory.isFull(d): boolean
	return count(d) >= Config.INVENTORY_CAP
end

local function placedIn(d, uid): string?
	for slot, placedUid in d.Placed do
		if placedUid == uid then return slot end
	end
	return nil
end
Inventory.placedIn = placedIn

local function onHotbar(d, uid): number?
	return table.find(d.Hotbar, uid)
end

local function newUid(d, prefix: string): string
	local uid = prefix .. d.NextUid
	d.NextUid += 1
	return uid
end

-- gives the monster a new uid and fills a free hotbar slot; the caller has already checked isFull
function Inventory.add(d, monster): string
	local uid = newUid(d, "m")
	d.Monsters[uid] = monster
	d.Index[monster.Kind] = true
	if #d.Hotbar < Config.HOTBAR_SLOTS then table.insert(d.Hotbar, uid) end
	return uid
end

-- Returns true, or false and why: locked, occupied, missing (not one of theirs, or nothing held) or deployed
function Inventory.place(d, bedroomIndex: number, uid: string?, unlocked: number): (boolean, string?)
	if bedroomIndex > unlocked then return false, "locked" end
	local slot = tostring(bedroomIndex)
	if d.Placed[slot] then return false, "occupied" end
	if not uid or d.Monsters[uid] == nil then return false, "missing" end
	if placedIn(d, uid) then return false, "deployed" end
	d.Placed[slot] = uid
	local at = onHotbar(d, uid)
	if at then table.remove(d.Hotbar, at) end
	return true
end

-- Empties the slot and returns the uid, or nil if it was empty. The monster goes back on the hotbar if there's room.
function Inventory.pickUp(d, bedroomIndex: number): string?
	local slot = tostring(bedroomIndex)
	local uid = d.Placed[slot]
	if not uid then return nil end
	d.Placed[slot] = nil
	if #d.Hotbar < Config.HOTBAR_SLOTS then table.insert(d.Hotbar, uid) end
	return uid
end

-- Puts an unplaced monster on the hotbar, replacing the last slot if it's full. Only the view changes, nothing is lost.
function Inventory.putOnHotbar(d, uid: string): boolean
	if d.Monsters[uid] == nil or placedIn(d, uid) then return false end
	if onHotbar(d, uid) then return true end
	if #d.Hotbar >= Config.HOTBAR_SLOTS then d.Hotbar[#d.Hotbar] = uid else table.insert(d.Hotbar, uid) end
	return true
end

function Inventory.setFavorite(d, uid: string, on: boolean): boolean
	local monster = d.Monsters[uid]
	if not monster then return false end
	monster.Favorited = if on then true else nil
	return true
end

function Inventory.addBox(d, boxId: string): string
	local uid = newUid(d, "b")
	d.Boxes[uid] = boxId
	return uid
end

-- the tutorial's free box: once ever, checked and marked together. Returns the box's uid, or nil if already claimed.
function Inventory.claimFreeBox(d): string?
	if d.Tutorial.FreeBoxClaimed then return nil end
	d.Tutorial.FreeBoxClaimed = true
	return Inventory.addBox(d, Config.Balance.tutorial.freeBoxId)
end

-- uses up a box you own and gives one accessory. r is a uniform number in [0, 100). Returns its uid and id, or nil.
function Inventory.openBox(d, boxUid: string, r: number): (string?, string?)
	local boxId = d.Boxes[boxUid]
	if not boxId then return nil end
	local items = Config.BOX_ITEMS[boxId]
	local chosen = items[#items] -- float rounding at the very top of the range
	for _, item in items do
		if r < item.weight then
			chosen = item
			break
		end
		r -= item.weight
	end
	d.Boxes[boxUid] = nil
	local uid = newUid(d, "a")
	d.Accessories[uid] = chosen.id
	return uid, chosen.id
end

local function caseOf(d, accessoryUid): string?
	for slot, uid in d.CaseAccessories do
		if uid == accessoryUid then return slot end
	end
	return nil
end

-- one accessory per case and one case per accessory. A case that already has one swaps it back to your items.
function Inventory.equip(d, bedroomIndex: number, accessoryUid: string, unlocked: number): boolean
	if bedroomIndex > unlocked or d.Accessories[accessoryUid] == nil or caseOf(d, accessoryUid) then return false end
	d.CaseAccessories[tostring(bedroomIndex)] = accessoryUid
	return true
end

function Inventory.unequip(d, bedroomIndex: number): boolean
	local slot = tostring(bedroomIndex)
	if not d.CaseAccessories[slot] then return false end
	d.CaseAccessories[slot] = nil
	return true
end

-- what the client's panel shows; a copy, so nothing the client sends can touch the save
function Inventory.snapshot(d)
	local rows = {}
	for uid, m in d.Monsters do
		table.insert(rows, {
			uid = uid,
			kind = m.Kind,
			tier = m.Tier,
			baseFear = m.BaseFear,
			size = m.Size,
			mutation = m.Mutation,
			favorited = m.Favorited == true,
			placedIn = placedIn(d, uid),
			hotbar = onHotbar(d, uid),
			order = tonumber(string.sub(uid, 2)) or 0,
		})
	end
	local boxes = {}
	for uid, id in d.Boxes do table.insert(boxes, {uid = uid, id = id}) end
	local accessories = {}
	for uid, id in d.Accessories do
		table.insert(accessories, {uid = uid, id = id, mult = Config.ACCESSORY_MULT[id] or 1, slot = caseOf(d, uid)})
	end
	local index = {}
	for kind in d.Index do index[kind] = true end
	return {rows = rows, capacity = Config.INVENTORY_CAP, boxes = boxes, accessories = accessories, index = index}
end

return Inventory
