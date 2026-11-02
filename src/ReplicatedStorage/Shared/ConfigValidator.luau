-- Turns tagged Balance data into plain values and refuses bad data at startup, listing every problem at once.
local ConfigValidator = {}

local REQUIRED_RARITIES = {"Common", "Rare", "Epic", "Legendary", "Mythic", "SPOOKY", "Secret"}
local REQUIRED_MUTATIONS = {"Golden", "Haunted", "Creepy", "Cursed", "UnHoly"}
local REQUIRED_BOXES = {"RareBox", "EpicBox", "LegendaryBox", "SecretBox"}
local TOTAL_TOLERANCE = 1e-9

-- Strips C()/P() tags. Returns plain data, {path = {tag, value, note}}, and a problem for each untagged number or boolean.
local function resolve(node: any, path: string, status: {[string]: any}, problems: {string}): any
	if type(node) ~= "table" then
		if type(node) == "number" or type(node) == "boolean" then
			table.insert(problems, `{path}: {node} has no C() or P() tag`)
		end
		return node
	end
	if node.__tag then
		status[path] = {tag = node.__tag, value = node.value, note = node.note}
		return node.value
	end
	local out = {}
	for key, child in node do
		-- list rows are addressed by id so a path still reads right after rows move
		local name = if type(child) == "table" and type(child.id) == "string" then child.id else tostring(key)
		out[key] = resolve(child, if path == "" then name else `{path}.{name}`, status, problems)
	end
	return out
end

local function validate(b: any, problems: {string})
	local function bad(message: string) table.insert(problems, message) end

	-- number check that also catches missing values, wrong types, NaN and infinity
	local function num(path: string, v: any, min: number, max: number?, integer: boolean?)
		if type(v) ~= "number" or v ~= v or v == math.huge or v == -math.huge then
			bad(`{path}: expected a finite number, got {tostring(v)}`)
		elseif v < min or (max and v > max) then
			bad(`{path}: {v} is outside {min} to {if max then tostring(max) else "unlimited"}`)
		elseif integer and v ~= math.floor(v) then
			bad(`{path}: {v} must be a whole number`)
		end
	end
	local function price(path: string, v: any) num(path, v, 0, b.economy and b.economy.maxFear, true) end
	local function mult(path: string, v: any) num(path, v, 1) end
	local function section(path: string, t: any): any
		if type(t) ~= "table" then
			bad(`{path}: missing`)
			return {}
		end
		return t
	end

	-- a list whose ids are unique; returns the set of ids
	local function ids(path: string, list: any): {[string]: any}
		local seen = {}
		for i, row in section(path, list) do
			if type(row) ~= "table" or type(row.id) ~= "string" or row.id == "" then
				bad(`{path}[{i}]: missing id`)
			elseif seen[row.id] then
				bad(`{path}: duplicate id "{row.id}"`)
			else
				seen[row.id] = row
			end
		end
		return seen
	end
	local function required(path: string, seen: {[string]: any}, names: {string})
		for _, name in names do
			if not seen[name] then bad(`{path}: "{name}" is missing`) end
		end
	end
	local function total100(path: string, sum: number)
		if math.abs(sum - 100) > TOTAL_TOLERANCE then bad(`{path}: odds total {sum}%, expected 100%`) end
	end

	num("server.maxPlayers", section("server", b.server).maxPlayers, 1, nil, true)
	num("server.plots", section("server", b.server).plots, 1, nil, true)
	price("start.fear", section("start", b.start).fear)
	if type(b.start and b.start.monsterKind) ~= "string" then bad("start.monsterKind: expected a string") end
	num("economy.maxFear", section("economy", b.economy).maxFear, 1, 2 ^ 53, true)
	num("economy.inventoryCap", b.economy and b.economy.inventoryCap, 1, nil, true)
	num("economy.hotbarSlots", b.economy and b.economy.hotbarSlots, 1, 9, true)
	num("manual.baseFear", section("manual", b.manual).baseFear, 0, nil, true)
	num("manual.cooldownSeconds", b.manual and b.manual.cooldownSeconds, 0)
	num("manual.multPerRebirth", b.manual and b.manual.multPerRebirth, 0)
	num("manual.maxTimingBonus", b.manual and b.manual.maxTimingBonus, 1)
	num("manual.goodTimingBonus", b.manual and b.manual.goodTimingBonus, 1, b.manual and b.manual.maxTimingBonus)
	num("manual.perfectAt", b.manual and b.manual.perfectAt, 0, 1)
	num("manual.perfectWidth", b.manual and b.manual.perfectWidth, 0.01, b.manual and b.manual.goodWidth)
	num("manual.goodWidth", b.manual and b.manual.goodWidth, 0.01, 1)
	num("manual.crawlSeconds", b.manual and b.manual.crawlSeconds, 0)
	num("manual.cueSeconds", b.manual and b.manual.cueSeconds, 0.5)
	for name, limit in section("limits", b.limits) do
		num(`limits.{name}.capacity`, limit.capacity, 1)
		num(`limits.{name}.refillPerSecond`, limit.refillPerSecond, 0.001)
	end

	local rarities = ids("rarities", b.rarities)
	required("rarities", rarities, REQUIRED_RARITIES)
	for id, r in rarities do
		num(`rarities.{id}.minFear`, r.minFear, 1, nil, true)
		num(`rarities.{id}.maxFear`, r.maxFear, 1, nil, true)
		num(`rarities.{id}.scareSeconds`, r.scareSeconds, 0.1)
		if type(r.minFear) == "number" and type(r.maxFear) == "number" and r.minFear > r.maxFear then
			bad(`rarities.{id}: minFear {r.minFear} is above maxFear {r.maxFear}`)
		end
	end

	-- every species pays a fixed amount inside its rarity's band
	for id, m in ids("monsters", b.monsters) do
		if type(m.name) ~= "string" then bad(`monsters.{id}.name: expected a string`) end
		local r = rarities[m.rarity]
		if not r then
			bad(`monsters.{id}: unknown rarity "{tostring(m.rarity)}"`)
		elseif type(m.baseFear) ~= "number" or m.baseFear < r.minFear or m.baseFear > r.maxFear then
			bad(`monsters.{id}.baseFear: {tostring(m.baseFear)} is outside the {m.rarity} band`)
		end
		num(`monsters.{id}.baseFear`, m.baseFear, 1, nil, true)
	end

	local tiers = ids("bedroomTiers", b.bedroomTiers)
	if not tiers.Normal then bad(`bedroomTiers: "Normal" is missing`) end
	local tierSum = 0
	for id, t in tiers do
		num(`bedroomTiers.{id}.chance`, t.chance, 0, 100)
		mult(`bedroomTiers.{id}.mult`, t.mult)
		if type(t.chance) == "number" then tierSum += t.chance end
	end
	total100("bedroomTiers", tierSum)

	local eggs = ids("eggs", b.eggs)
	for id, egg in eggs do
		if type(egg.name) ~= "string" then bad(`eggs.{id}.name: expected a string`) end
		if type(egg.live) ~= "boolean" then bad(`eggs.{id}.live: expected true or false`) end
		if egg.source ~= "fear" and egg.source ~= "tutorial" and egg.source ~= "dig" then
			bad(`eggs.{id}.source: "{tostring(egg.source)}" is not fear, tutorial or dig`)
		end
		price(`eggs.{id}.price`, egg.price)
		local sum = 0
		for rarity, chance in section(`eggs.{id}.odds`, egg.odds) do
			if not rarities[rarity] then bad(`eggs.{id}.odds: unknown rarity "{rarity}"`) end
			num(`eggs.{id}.odds.{rarity}`, chance, 0, 100)
			if type(chance) == "number" then sum += chance end
		end
		total100(`eggs.{id}.odds`, sum)
	end

	local mutations = ids("mutations", b.mutations)
	required("mutations", mutations, REQUIRED_MUTATIONS)
	local mutationSum = 0
	for id, m in mutations do
		mult(`mutations.{id}.mult`, m.mult)
		num(`mutations.{id}.rollChance`, m.rollChance, 0, 100)
		if type(m.rollChance) == "number" then mutationSum += m.rollChance end
	end
	if mutationSum > 100 then bad(`mutations: rollChance totals {mutationSum}%, above 100%`) end

	local fusion = section("fusion", b.fusion)
	local sizes = ids("fusion.sizes", fusion.sizes)
	local lastMult = 0
	for i, size in section("fusion.sizes", fusion.sizes) do
		mult(`fusion.sizes.{size.id}.mult`, size.mult)
		num(`fusion.sizes.{size.id}.modelScale`, size.modelScale, 0.1)
		if type(size.mult) == "number" then
			if size.mult <= lastMult then bad(`fusion.sizes.{size.id}: mult must grow with size`) end
			lastMult = size.mult
		end
		if i == 1 and size.mult ~= 1 then bad(`fusion.sizes.{size.id}: the smallest size must be x1`) end
	end
	local recipes = ids("fusion.recipes", fusion.recipes)
	for id, recipe in recipes do
		if not sizes[id] then bad(`fusion.recipes.{id}: makes unknown size`) end
		if not sizes[recipe.from] then bad(`fusion.recipes.{id}: uses unknown size "{tostring(recipe.from)}"`) end
		num(`fusion.recipes.{id}.count`, recipe.count, 2, nil, true)
	end
	if type(fusion.requireSameMutation) ~= "boolean" then bad("fusion.requireSameMutation: expected true or false") end

	local rebirth = section("rebirth", b.rebirth)
	num("rebirth.startBedrooms", rebirth.startBedrooms, 1, rebirth.bedroomsPerFloor, true)
	num("rebirth.bedroomsPerFloor", rebirth.bedroomsPerFloor, 1, nil, true)
	num("rebirth.bedroomsPerRebirth", rebirth.bedroomsPerRebirth, 1, nil, true)
	num("rebirth.floorCap", rebirth.floorCap, 1, nil, true)
	num("rebirth.floorHeight", rebirth.floorHeight, 1)
	price("rebirth.costBase", rebirth.costBase)
	num("rebirth.costGrowth", rebirth.costGrowth, 1)
	num("rebirth.multPerRebirth", rebirth.multPerRebirth, 0)
	if type(rebirth.keepsRemainingFear) ~= "boolean" then bad("rebirth.keepsRemainingFear: expected true or false") end

	local accessories = section("accessories", b.accessories)
	num("accessories.slotsPerCase", accessories.slotsPerCase, 1, nil, true)
	local boxes = ids("accessories.boxes", accessories.boxes)
	required("accessories.boxes", boxes, REQUIRED_BOXES)
	local boxSums = {}
	for id, item in ids("accessories.items", accessories.items) do
		if not boxes[item.box] then bad(`accessories.items.{id}: unknown box "{tostring(item.box)}"`) end
		mult(`accessories.items.{id}.mult`, item.mult)
		num(`accessories.items.{id}.weight`, item.weight, 0, 100)
		if type(item.box) == "string" and type(item.weight) == "number" then
			boxSums[item.box] = (boxSums[item.box] or 0) + item.weight
		end
	end
	for id in boxes do
		total100(`accessories box {id}`, boxSums[id] or 0)
	end

	local shop = section("shop", b.shop)
	num("shop.rotationSeconds", shop.rotationSeconds, 1)
	num("shop.offersMin", shop.offersMin, 1, shop.offersMax, true)
	num("shop.offersMax", shop.offersMax, 1, nil, true)
	local shopItems = ids("shop.items", shop.items)
	for id, item in shopItems do
		if item.kind == "box" then
			if not boxes[id] then bad(`shop.items.{id}: no accessory box has this id`) end
		elseif item.kind ~= "tracker" then
			bad(`shop.items.{id}.kind: "{tostring(item.kind)}" is not box or tracker`)
		end
		price(`shop.items.{id}.price`, item.price)
		num(`shop.items.{id}.appearChance`, item.appearChance, 0, 100)
		num(`shop.items.{id}.stock`, item.stock, 1, nil, true)
	end

	local trackers = section("trackers", b.trackers)
	if not eggs[trackers.rewardEgg] then bad(`trackers.rewardEgg: unknown egg "{tostring(trackers.rewardEgg)}"`) end
	num("trackers.digExpireSeconds", trackers.digExpireSeconds, 1)
	num("trackers.digDistance", trackers.digDistance, 1)
	num("trackers.digHoldSeconds", trackers.digHoldSeconds, 0)
	if type(trackers.restoreOnExpire) ~= "boolean" then bad("trackers.restoreOnExpire: expected true or false") end

	local tutorial = section("tutorial", b.tutorial)
	if not eggs[tutorial.eggId] then bad(`tutorial.eggId: unknown egg "{tostring(tutorial.eggId)}"`) end
	if not boxes[tutorial.freeBoxId] then bad(`tutorial.freeBoxId: unknown box "{tostring(tutorial.freeBoxId)}"`) end
	num("tutorial.freeBoxClaims", tutorial.freeBoxClaims, 1, 1, true)
end

-- a row so malformed that the checks themselves trip still counts as a problem, not a confusing crash
local function validateSafely(plain: any, problems: {string})
	local ok, err = pcall(validate, plain, problems)
	if not ok then table.insert(problems, `a table is malformed: {err}`) end
end

-- Every problem in tagged data, as readable lines. An empty list means it is valid.
function ConfigValidator.problems(raw: any): {string}
	local problems = {}
	validateSafely(resolve(raw, "", {}, problems), problems)
	return problems
end

-- Plain values and the status of each one, or a startup error listing everything wrong.
function ConfigValidator.load(raw: any): (any, {[string]: any})
	local status, problems = {}, {}
	local plain = resolve(raw, "", status, problems)
	validateSafely(plain, problems)
	if #problems > 0 then
		table.sort(problems)
		error(`[Config] Balance has {#problems} problem(s), fix them before the game can start:\n  - {table.concat(problems, "\n  - ")}`, 0)
	end
	return plain, status
end

return ConfigValidator
