-- Player save shape, defaults and migrations (pattern from the LihFolk vault, "Saved Inventory End to End" 4.1)
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local CURRENT_VERSION = 1

export type Monster = {Kind: string, Tier: string}
export type Data = {
	SchemaVersion: number,
	Fear: number,
	Rebirths: number,
	Monsters: {[string]: Monster}, -- uid -> monster
	Placed: {[string]: string}, -- bedroom index as a string -> uid
	NextUid: number,
}

local DataTemplate = {}
DataTemplate.CurrentVersion = CURRENT_VERSION

function DataTemplate.new(): Data
	return {SchemaVersion = CURRENT_VERSION, Fear = Config.START_FEAR, Rebirths = 0, Monsters = {}, Placed = {}, NextUid = 1}
end

local function deepCopy(value: any): any
	if type(value) ~= "table" then return value end
	local out = {}
	for k, v in value do out[k] = deepCopy(v) end
	return out
end
DataTemplate.deepCopy = deepCopy

-- Fill missing fields; never overwrite existing ones. Empty template maps hold player content: do not recurse into them.
local function reconcile(target: {[string]: any}, template: {[string]: any})
	for key, defaultValue in template do
		local current = target[key]
		if current == nil then
			target[key] = deepCopy(defaultValue)
		elseif type(defaultValue) == "table" and type(current) == "table" and next(defaultValue) ~= nil then
			reconcile(current, defaultValue)
		end
	end
end

-- migrations[n] upgrades a version n-1 document to version n. Never edit a step after release.
local migrations: {[number]: (data: {[string]: any}) -> ()} = {}

local function finite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge
end

-- Ready-to-use data, or nil and a reason. Corrupt data never becomes defaults.
function DataTemplate.prepare(raw: any): (Data?, string?)
	if raw == nil then return DataTemplate.new(), nil end
	if type(raw) ~= "table" then return nil, "corrupt" end
	local version = if type(raw.SchemaVersion) == "number" then raw.SchemaVersion else 0
	if version > CURRENT_VERSION then return nil, "newer" end
	for v = version + 1, CURRENT_VERSION do
		local migrate = migrations[v]
		if migrate then migrate(raw) end
		raw.SchemaVersion = v
	end
	reconcile(raw, DataTemplate.new() :: any)
	if not finite(raw.Fear) or not finite(raw.Rebirths) or not finite(raw.NextUid) then return nil, "corrupt" end
	raw.Fear = math.clamp(math.floor(raw.Fear), 0, Config.MAX_FEAR)
	-- a placement pointing at a missing monster is dropped (the monster itself is never deleted)
	for index, uid in raw.Placed do
		if raw.Monsters[uid] == nil then raw.Placed[index] = nil end
	end
	return raw :: Data, nil
end

-- self-check
do
	local fresh = DataTemplate.prepare(nil)
	assert(fresh and fresh.Fear == Config.START_FEAR, "fresh profile")
	local _, why = DataTemplate.prepare({SchemaVersion = CURRENT_VERSION + 1})
	assert(why == "newer", "newer schema must be refused")
	local _, bad = DataTemplate.prepare({Fear = 0 / 0})
	assert(bad == "corrupt", "NaN Fear must be refused")
	local fixed = DataTemplate.prepare({Fear = 10, Monsters = {m1 = {Kind = "Jeff", Tier = "Rare"}}, Placed = {["1"] = "m1", ["2"] = "gone"}})
	assert(fixed and fixed.Placed["1"] == "m1" and fixed.Placed["2"] == nil and fixed.Rebirths == 0, "reconcile and placement repair")
end

return DataTemplate
