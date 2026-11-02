-- Player save shape, defaults and migrations (pattern from the LihFolk vault, "Saved Inventory End to End" 4.1)
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))

local CURRENT_VERSION = 3

export type Monster = {
	Kind: string, -- species id
	Tier: string, -- rarity id
	BaseFear: number, -- fixed when obtained, never rerolled
	Size: string, -- fusion size id
	Mutation: string?, -- mutation id, absent when none
	Provenance: string, -- egg, tutorial, dig, fusion, purchase or migrated
	Favorited: boolean?, -- protected from fusion and selling
}
export type Data = {
	SchemaVersion: number,
	Fear: number,
	TotalFearEarned: number,
	Rebirths: number,
	Monsters: {[string]: Monster}, -- uid -> monster
	Placed: {[string]: string}, -- bedroom index as a string -> uid
	NextUid: number,
	Hotbar: {string}, -- uids shown in the Roblox hotbar, in order: a view of Monsters, never the only copy
	Index: {[string]: boolean}, -- species discovered
	Boxes: {[string]: string}, -- uid -> accessory box id
	Accessories: {[string]: string}, -- uid -> accessory id
	CaseAccessories: {[string]: string}, -- bedroom index as a string -> accessory uid
	Eggs: {[string]: string}, -- uid -> unhatched egg id
	Trackers: {[string]: {State: string, Node: string?, ExpiresAt: number?}}, -- uid -> Owned or Activated; used up when dug
	ShopBought: {Rotation: number, Items: {[string]: number}}, -- how much of each item this rotation, so stock survives a rejoin
	Tutorial: {Step: number, Complete: boolean, FreeBoxClaimed: boolean, ManualDone: boolean, EggUsed: boolean, ScareSeen: boolean},
	Settings: {ReducedScares: boolean, MusicVolume: number, SfxVolume: number},
	Receipts: {[string]: boolean}, -- purchase ids already granted
}

local DataTemplate = {}
DataTemplate.CurrentVersion = CURRENT_VERSION

function DataTemplate.new(): Data
	return {
		SchemaVersion = CURRENT_VERSION,
		Fear = Config.START_FEAR,
		TotalFearEarned = 0,
		Rebirths = 0,
		Monsters = {},
		Placed = {},
		NextUid = 1,
		Hotbar = {},
		Index = {},
		Boxes = {},
		Accessories = {},
		CaseAccessories = {},
		Eggs = {},
		Trackers = {},
		ShopBought = {Rotation = 0, Items = {}},
		Tutorial = {Step = 0, Complete = false, FreeBoxClaimed = false, ManualDone = false, EggUsed = false, ScareSeen = false},
		Settings = {ReducedScares = false, MusicVolume = 1, SfxVolume = 1},
		Receipts = {},
	}
end

function DataTemplate.newMonster(kind: string, tier: string, baseFear: number, provenance: string): Monster
	return {Kind = kind, Tier = tier, BaseFear = baseFear, Size = "Normal", Provenance = provenance}
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
local migrations: {[number]: (data: {[string]: any}) -> ()} = {
	-- v2: monsters get a fixed payout (the middle of their rarity band), discovered species are recorded
	[2] = function(data)
		data.TotalFearEarned = if type(data.Fear) == "number" then data.Fear else 0
		data.Index = {}
		if type(data.Monsters) ~= "table" then return end
		for _, monster in data.Monsters do
			if type(monster) == "table" then
				local tier = Config.TIER_BY_NAME[monster.Tier]
				monster.BaseFear = if tier then math.floor((tier.min + tier.max) / 2) else 0
				monster.Size = "Normal"
				monster.Provenance = "migrated"
				if type(monster.Kind) == "string" then data.Index[monster.Kind] = true end
			end
		end
	end,
	-- v3: the hotbar becomes saved data; prepare() fills it from the unplaced monsters
	[3] = function(data)
		data.Hotbar = {}
	end,
}

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
	if not finite(raw.Fear) or not finite(raw.TotalFearEarned) or not finite(raw.Rebirths) or not finite(raw.NextUid) then return nil, "corrupt" end
	raw.Fear = math.clamp(math.floor(raw.Fear), 0, Config.MAX_FEAR)
	-- a damaged monster row refuses the save rather than quietly losing the monster
	for _, monster in raw.Monsters do
		if type(monster) ~= "table" or type(monster.Kind) ~= "string" or type(monster.Tier) ~= "string" or not finite(monster.BaseFear) then
			return nil, "corrupt"
		end
	end
	-- nobody with no monsters can be stuck below the first egg's price, like saves from when eggs and starting Fear were cheaper
	if next(raw.Monsters) == nil and raw.Fear < Config.START_FEAR then raw.Fear = Config.START_FEAR end
	-- a placement pointing at a missing monster, or a second placement of one monster, is dropped (the monster itself is never deleted)
	local placed = {}
	for index, uid in raw.Placed do
		if raw.Monsters[uid] == nil or placed[uid] then
			raw.Placed[index] = nil
		else
			placed[uid] = true
		end
	end
	-- the hotbar keeps its order but only lists real, unplaced monsters, once each, then fills any free slots
	local hotbar, listed = {}, {}
	for _, uid in raw.Hotbar do
		if raw.Monsters[uid] ~= nil and not placed[uid] and not listed[uid] and #hotbar < Config.HOTBAR_SLOTS then
			table.insert(hotbar, uid)
			listed[uid] = true
		end
	end
	local spare = {}
	for uid in raw.Monsters do
		if not placed[uid] and not listed[uid] then table.insert(spare, uid) end
	end
	table.sort(spare)
	for _, uid in spare do
		if #hotbar >= Config.HOTBAR_SLOTS then break end
		table.insert(hotbar, uid)
	end
	raw.Hotbar = hotbar
	-- an accessory on two cases, or one that no longer exists, is taken off (the accessory itself is kept)
	local equipped = {}
	for slot, uid in raw.CaseAccessories do
		if raw.Accessories[uid] == nil or equipped[uid] then
			raw.CaseAccessories[slot] = nil
		else
			equipped[uid] = true
		end
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
	assert(DataTemplate.prepare({SchemaVersion = CURRENT_VERSION, Fear = 1}).Fear == Config.START_FEAR, "a player with no monsters can always afford the first egg")
	local _, damaged = DataTemplate.prepare({SchemaVersion = CURRENT_VERSION, Monsters = {m1 = "not a monster"}})
	assert(damaged == "corrupt", "a damaged monster must refuse the save")
	-- a v1 save keeps everything it had and gains the v2 fields
	local v2 = DataTemplate.prepare({SchemaVersion = 1, Fear = 700, Rebirths = 2, NextUid = 3, Monsters = {m1 = {Kind = "Jeff", Tier = "Rare"}, m2 = {Kind = "Jeff", Tier = "Gone"}}, Placed = {["1"] = "m1"}})
	assert(v2 and v2.SchemaVersion == CURRENT_VERSION and v2.Fear == 700 and v2.TotalFearEarned == 700 and v2.Rebirths == 2 and v2.NextUid == 3, "v2 migration keeps progress")
	assert(v2.Monsters.m1.BaseFear == 500 and v2.Monsters.m1.Size == "Normal" and v2.Monsters.m1.Tier == "Rare" and v2.Monsters.m2.BaseFear == 0 and v2.Placed["1"] == "m1", "v2 migration keeps monsters")
	assert(#v2.Hotbar == 1 and v2.Hotbar[1] == "m2", "v3 migration fills the hotbar with unplaced monsters only")
	assert(v2.Index.Jeff == true and v2.Settings.ReducedScares == false and v2.Tutorial.Step == 0, "v2 migration adds the new fields")
end

return DataTemplate
