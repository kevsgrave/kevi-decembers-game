-- The one place for odds, payouts, prices and rebirth math. The server rolls and charges from it; the client only displays it.
local Config = {}

Config.EGG_COST = 250
Config.START_FEAR = 250
Config.START_BEDROOMS = 3
Config.BEDROOM_COUNT = 6
Config.MANUAL_BASE = 100
Config.MANUAL_COOLDOWN = 3
Config.INVENTORY_CAP = 50
Config.MAX_FEAR = 1e15 -- well below 2^53 so Fear stays an exact integer

-- Jeff is the only hatchable monster for now; the egg still rolls his rarity
Config.MONSTER_KIND = "Jeff"

-- from the wiki: Tiers For Monsters (odds are a v1 guess); chance is in percent and must total 100
Config.MONSTER_TIERS = {
	{name = "Common", chance = 60, interval = 15, min = 25, max = 400, color = Color3.fromRGB(200, 200, 200)},
	{name = "Rare", chance = 25, interval = 10, min = 200, max = 800, color = Color3.fromRGB(70, 160, 255)},
	{name = "Epic", chance = 10, interval = 8, min = 400, max = 1500, color = Color3.fromRGB(190, 90, 255)},
	{name = "Legendary", chance = 4, interval = 5, min = 800, max = 2500, color = Color3.fromRGB(255, 200, 40)},
	{name = "Mythic", chance = 0.9, interval = 5, min = 1200, max = 5000, color = Color3.fromRGB(255, 70, 90)},
	{name = "SPOOKY", chance = 0.1, interval = 3.5, min = 8000, max = 15000, color = Color3.fromRGB(40, 255, 160)},
}
Config.TIER_BY_NAME = {}
for _, t in ipairs(Config.MONSTER_TIERS) do Config.TIER_BY_NAME[t.name] = t end

-- from the wiki: Bedroom Tiers, chances in percent; Normal gets whatever is left
Config.BEDROOM_TIERS = {
	{name = "GOD", chance = 0.001, mult = 16, color = Color3.fromRGB(255, 60, 200)},
	{name = "Diamond", chance = 0.05, mult = 4, color = Color3.fromRGB(120, 230, 255)},
	{name = "Platinum", chance = 1, mult = 2, color = Color3.fromRGB(220, 230, 240)},
	{name = "Gold", chance = 5, mult = 1.5, color = Color3.fromRGB(255, 200, 50)},
	{name = "Silver", chance = 20, mult = 1.2, color = Color3.fromRGB(190, 190, 200)},
}
Config.NORMAL_TIER = {name = "Normal", mult = 1, color = Color3.fromRGB(255, 255, 255)}

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

function Config.rebirthCost(rebirths) return 5000 * (rebirths + 1) ^ 2 end
function Config.rebirthMult(rebirths) return 1 + 0.5 * rebirths end
function Config.unlockedBedrooms(rebirths) return math.min(Config.BEDROOM_COUNT, Config.START_BEDROOMS + rebirths) end

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

-- startup self-check: odds must total exactly 100%
local total = 0
for _, t in ipairs(Config.MONSTER_TIERS) do
	assert(t.chance > 0 and t.min <= t.max and t.interval > 0, "bad monster tier " .. t.name)
	total += t.chance
end
assert(math.abs(total - 100) < 1e-9, "monster odds total " .. total .. "%, expected 100%")
local bedroomTotal = 0
for _, t in ipairs(Config.BEDROOM_TIERS) do bedroomTotal += t.chance end
assert(bedroomTotal < 100, "bedroom tiers leave no room for Normal")
assert(Config.pickMonsterTier(0).name == "Common" and Config.pickMonsterTier(99.95).name == "SPOOKY", "monster roll order")
assert(Config.pickBedroomTier(0).name == "GOD" and Config.pickBedroomTier(99).name == "Normal", "bedroom roll order")
assert(Config.short(4999) == "4.9K" and Config.short(5000) == "5.0K", "short() must round down")

return Config
