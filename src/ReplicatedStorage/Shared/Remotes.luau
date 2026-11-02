-- The remote contract: every remote, its direction and its arguments. docs/ARCHITECTURE.md has the server validation order.
-- live = in the game now. planned = its phase creates it by flipping this flag, so unused remotes never exist.
local Remotes = {}

local MAX_ID_LENGTH = 64
local MAX_LIST_LENGTH = 40

-- argument kinds a client may send
local CHECKS = {
	id = function(v) return type(v) == "string" and #v > 0 and #v <= MAX_ID_LENGTH end,
	boolean = function(v) return type(v) == "boolean" end,
	number = function(v) return type(v) == "number" and v == v and v ~= math.huge and v ~= -math.huge end,
	idList = function(v)
		if type(v) ~= "table" or #v == 0 or #v > MAX_LIST_LENGTH then return false end
		local count = 0
		for key, item in v do
			count += 1
			if type(key) ~= "number" or type(item) ~= "string" or #item == 0 or #item > MAX_ID_LENGTH then return false end
		end
		return count == #v
	end,
}

-- name, Event or Function, s2c (server to client) or c2s, arguments, live or planned, phase
Remotes.List = {
	{name = "Popup", kind = "Event", dir = "s2c", args = {"message"}, status = "live", phase = 0},
	{name = "Rebirth", kind = "Function", dir = "c2s", args = {}, status = "live", phase = 0},

	{name = "GetInventory", kind = "Function", dir = "c2s", args = {}, status = "live", phase = 3},
	{name = "HoldMonster", kind = "Event", dir = "c2s", args = {"id"}, status = "live", phase = 3},
	{name = "FavoriteMonster", kind = "Event", dir = "c2s", args = {"id", "boolean"}, status = "live", phase = 3},
	{name = "InventoryChanged", kind = "Event", dir = "s2c", args = {"state"}, status = "live", phase = 3},
	{name = "ManualCue", kind = "Event", dir = "s2c", args = {"state"}, status = "live", phase = 4},
	{name = "ManualTap", kind = "Event", dir = "c2s", args = {}, status = "live", phase = 4},
	{name = "HatchEgg", kind = "Function", dir = "c2s", args = {"id", "id"}, status = "live", phase = 5},
	{name = "TutorialStep", kind = "Event", dir = "s2c", args = {"state"}, status = "live", phase = 5},
	{name = "TutorialDone", kind = "Event", dir = "c2s", args = {}, status = "live", phase = 5},
	{name = "OpenBox", kind = "Function", dir = "c2s", args = {"id"}, status = "live", phase = 5},
	{name = "EquipAccessory", kind = "Function", dir = "c2s", args = {"id", "id"}, status = "live", phase = 5},
	{name = "UnequipAccessory", kind = "Function", dir = "c2s", args = {"id"}, status = "live", phase = 5},
	{name = "OpenCase", kind = "Event", dir = "s2c", args = {"state"}, status = "live", phase = 5},
	{name = "ShopChanged", kind = "Event", dir = "s2c", args = {}, status = "live", phase = 6},
	{name = "GetShop", kind = "Function", dir = "c2s", args = {}, status = "live", phase = 6},
	{name = "BuyShopItem", kind = "Function", dir = "c2s", args = {"id", "number"}, status = "live", phase = 6},
	{name = "ActivateTracker", kind = "Function", dir = "c2s", args = {"id"}, status = "live", phase = 6},
	{name = "Dig", kind = "Function", dir = "c2s", args = {"id"}, status = "live", phase = 6},
	{name = "TrackerState", kind = "Event", dir = "s2c", args = {"state"}, status = "live", phase = 6},
	{name = "HatchOwnedEgg", kind = "Function", dir = "c2s", args = {"id"}, status = "live", phase = 6},
	{name = "HatchReveal", kind = "Event", dir = "s2c", args = {"state"}, status = "live", phase = 6},
	{name = "FuseMonsters", kind = "Function", dir = "c2s", args = {"idList"}, status = "live", phase = 7},
	{name = "SetSetting", kind = "Event", dir = "c2s", args = {"id", "boolean"}, status = "planned", phase = 8},
}

local byName = {}
for _, remote in Remotes.List do
	assert(not byName[remote.name], "duplicate remote " .. remote.name)
	assert(remote.kind == "Event" or remote.kind == "Function", "bad kind on " .. remote.name)
	if remote.dir == "c2s" then
		for _, arg in remote.args do assert(CHECKS[arg], "unknown argument kind on " .. remote.name) end
	end
	byName[remote.name] = remote
end

-- First check on every client request: right count and right types. Returns ok, reason.
function Remotes.checkArgs(name: string, ...: any): (boolean, string?)
	local remote = byName[name]
	if not remote or remote.dir ~= "c2s" then return false, "unknown remote" end
	if select("#", ...) ~= #remote.args then return false, "wrong argument count" end
	for i, kind in remote.args do
		if not CHECKS[kind]((select(i, ...))) then return false, `argument {i} is not a valid {kind}` end
	end
	return true
end

-- Server only: makes every live remote through Net (the module is passed in so this file needs no game services).
function Remotes.createLive(net: any): {[string]: any}
	local made = {}
	for _, remote in Remotes.List do
		if remote.status == "live" then
			made[remote.name] = if remote.kind == "Event" then net.Event(remote.name) else net.Function(remote.name)
		end
	end
	return made
end

return Remotes
