-- What the game reads: Balance checked by ConfigValidator, shaped for the server's rolls and the client's display.
-- A bad value in Balance stops the game here at startup, with a list of what to fix.
local Balance = require(script.Parent.Balance)
local ConfigValidator = require(script.Parent.ConfigValidator)

local Config = {}

local B, status = ConfigValidator.load(Balance)
Config.Balance = B -- plain values, for the phases that use the rest of the tables
Config.Status = status -- ["bedroomTiers.GOD.chance"] = {tag = "provisional", value = 0.001, note = "..."}

local LIVE_EGG = "SpookyEgg"
local eggsById = {}
for _, egg in B.eggs do eggsById[egg.id] = egg end

Config.EGG_COST = eggsById[LIVE_EGG].price
Config.START_FEAR = B.start.fear
Config.START_BEDROOMS = B.rebirth.startBedrooms
Config.BEDROOM_COUNT = B.rebirth.bedroomsPerFloor
Config.MANUAL_BASE = B.manual.baseFear
Config.MANUAL_COOLDOWN = B.manual.cooldownSeconds
Config.INVENTORY_CAP = B.economy.inventoryCap
Config.MAX_FEAR = B.economy.maxFear
Config.LIMITS = B.limits

-- Jeff is the only hatchable monster for now; the egg still rolls his rarity
Config.MONSTER_KIND = B.start.monsterKind

local RARITY_COLORS = {
	Common = Color3.fromRGB(200, 200, 200),
	Rare = Color3.fromRGB(70, 160, 255),
	Epic = Color3.fromRGB(190, 90, 255),
	Legendary = Color3.fromRGB(255, 200, 40),
	Mythic = Color3.fromRGB(255, 70, 90),
	SPOOKY = Color3.fromRGB(40, 255, 160),
	Secret = Color3.fromRGB(255, 120, 40),
}
local BEDROOM_COLORS = {
	GOD = Color3.fromRGB(255, 60, 200),
	Diamond = Color3.fromRGB(120, 230, 255),
	Platinum = Color3.fromRGB(220, 230, 240),
	Gold = Color3.fromRGB(255, 200, 50),
	Silver = Color3.fromRGB(190, 190, 200),
	Normal = Color3.fromRGB(255, 255, 255),
}

-- MONSTER_TIERS holds what the live egg can roll, in percent; TIER_BY_NAME holds every rarity
Config.MONSTER_TIERS = {}
Config.TIER_BY_NAME = {}
for _, r in B.rarities do
	local chance = eggsById[LIVE_EGG].odds[r.id] or 0
	local tier = {name = r.id, chance = chance, interval = r.scareSeconds, min = r.minFear, max = r.maxFear, color = RARITY_COLORS[r.id]}
	Config.TIER_BY_NAME[r.id] = tier
	if chance > 0 then table.insert(Config.MONSTER_TIERS, tier) end
end

-- BEDROOM_TIERS are rolled in order; Normal gets whatever is left
Config.BEDROOM_TIERS = {}
for _, t in B.bedroomTiers do
	local tier = {name = t.id, chance = t.chance, mult = t.mult, color = BEDROOM_COLORS[t.id]}
	if t.id == "Normal" then Config.NORMAL_TIER = tier else table.insert(Config.BEDROOM_TIERS, tier) end
end

-- r is a uniform number in [0, 100)
function Config.pickMonsterTier(r)
	for _, t in ipairs(Config.MONSTER_TIERS) do
		if r < t.chance then return t end
		r -= t.chance
	end
	return Config.MONSTER_TIERS[1] -- float rounding at the very top of the range
end

function Config.pickBedroomTier(r)
	for _, t in ipairs(Config.BEDROOM_TIERS) do
		if r < t.chance then return t end
		r -= t.chance
	end
	return Config.NORMAL_TIER
end

function Config.rebirthCost(rebirths) return B.rebirth.costBase * (rebirths + 1) ^ B.rebirth.costExponent end
function Config.rebirthMult(rebirths) return 1 + B.rebirth.multPerRebirth * rebirths end
function Config.unlockedBedrooms(rebirths) return math.min(Config.BEDROOM_COUNT, Config.START_BEDROOMS + rebirths * B.rebirth.bedroomsPerRebirth) end

-- rounds down, so 4,999 never reads as 5.0K next to a 5,000 price
function Config.short(n)
	local function cut(v, unit) return string.format("%.1f%s", math.floor(v * 10) / 10, unit) end
	if n >= 1e9 then return cut(n / 1e9, "B") end
	if n >= 1e6 then return cut(n / 1e6, "M") end
	if n >= 1e3 then return cut(n / 1e3, "K") end
	return tostring(math.floor(n))
end

-- odds label generated from the same table the server rolls from
function Config.oddsText()
	local lines = {}
	for _, t in ipairs(Config.MONSTER_TIERS) do
		table.insert(lines, string.format("%s %s%%", t.name, tostring(t.chance)))
	end
	return table.concat(lines, "\n")
end

-- how many values are settled and how many are still guesses, for the startup log
function Config.statusSummary()
	local confirmed, provisional = 0, 0
	for _, s in status do
		if s.tag == "confirmed" then confirmed += 1 else provisional += 1 end
	end
	return `{confirmed} confirmed, {provisional} provisional`
end

assert(Config.pickMonsterTier(0).name == "Common" and Config.pickMonsterTier(99.95).name == "SPOOKY", "monster roll order")
assert(Config.pickBedroomTier(0).name == "GOD" and Config.pickBedroomTier(99).name == "Normal", "bedroom roll order")
assert(Config.short(4999) == "4.9K" and Config.short(5000) == "5.0K", "short() must round down")

return Config
