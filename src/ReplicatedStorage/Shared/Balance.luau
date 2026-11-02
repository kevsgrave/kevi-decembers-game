-- Every balance number in the game, tagged. C = settled by the design notes. P = provisional default, change freely.
-- ConfigValidator refuses any untagged number or boolean. No Roblox types here, so this file runs outside Studio too.
-- Not everything is wired up yet: docs/ARCHITECTURE.md says which phase uses what.
local function C(value: any, note: string?) return {__tag = "confirmed", value = value, note = note} end
local function P(value: any, note: string?) return {__tag = "provisional", value = value, note = note} end

return {
	server = {
		maxPlayers = C(8),
		plots = C(8),
	},

	start = {
		fear = P(250, "exactly one Spooky Egg"),
		monsterKind = P("Jeff", "only hatchable monster until the roster exists; name needs an owner decision, see docs/phase1/AUDIT.md"),
	},

	economy = {
		maxFear = P(1e15, "well below 2^53 so Fear stays an exact integer"),
		inventoryCap = P(50),
	},

	manual = {
		baseFear = C(100),
		cooldownSeconds = P(3),
		multPerRebirth = P(0.5, "master prompt wants its own curve; same value as automatic scares for now"),
	},

	-- server rate limits for prompts and remotes
	limits = {
		hatch = {capacity = P(3), refillPerSecond = P(1.5)},
		showcase = {capacity = P(4), refillPerSecond = P(2)},
		rebirth = {capacity = P(2), refillPerSecond = P(0.5)},
	},

	-- least rare first; from Tiers For Monsters. Secret has no numbers in the notes.
	rarities = {
		{id = "Common", minFear = C(25), maxFear = C(400), scareSeconds = C(15)},
		{id = "Rare", minFear = C(200), maxFear = C(800), scareSeconds = C(10)},
		{id = "Epic", minFear = C(400), maxFear = C(1500), scareSeconds = C(8)},
		{id = "Legendary", minFear = C(800), maxFear = C(2500), scareSeconds = C(5)},
		{id = "Mythic", minFear = C(1200), maxFear = C(5000), scareSeconds = C(5)},
		{id = "SPOOKY", minFear = C(8000), maxFear = C(15000), scareSeconds = C(3.5)},
		{id = "Secret", minFear = P(15000), maxFear = P(30000), scareSeconds = P(3)},
	},

	-- rolled top to bottom, in percent, totals 100. From Bedroom Tiers.
	bedroomTiers = {
		{id = "GOD", chance = P(0.001, "notes say .001 with no % sign; read as 0.001%, owner to confirm"), mult = C(16)},
		{id = "Diamond", chance = C(0.05), mult = C(4)},
		{id = "Platinum", chance = C(1), mult = C(2)},
		{id = "Gold", chance = C(5), mult = C(1.5)},
		{id = "Silver", chance = C(20), mult = C(1.2)},
		{id = "Normal", chance = P(73.949, "the rest of the %, so it moves if the GOD reading changes"), mult = C(1)},
	},

	-- odds in percent, each egg totals 100. Only the tutorial egg's odds come from the notes.
	-- live = false: defined, not offered in the game yet.
	eggs = {
		{
			id = "SpookyEgg", name = "Spooky Egg", live = C(true), source = "fear", price = P(250),
			odds = {Common = P(60), Rare = P(25), Epic = P(10), Legendary = P(4), Mythic = P(0.9), SPOOKY = P(0.1)},
		},
		{
			id = "MoonlitEgg", name = "Moonlit Egg", live = P(false), source = "fear", price = P(2500),
			odds = {Common = P(25), Rare = P(40), Epic = P(25), Legendary = P(8), Mythic = P(1.8), SPOOKY = P(0.2)},
		},
		{
			id = "GraveyardEgg", name = "Graveyard Egg", live = P(false), source = "fear", price = P(25000),
			odds = {Rare = P(30), Epic = P(40), Legendary = P(22), Mythic = P(7), SPOOKY = P(0.9), Secret = P(0.1)},
		},
		{
			id = "TutorialEgg", name = "Tutorial Egg", live = P(false), source = "tutorial", price = P(0, "free so the tutorial can't soft-lock"),
			odds = {Epic = C(80), Legendary = C(20)},
		},
		{
			id = "TrackerEgg", name = "Secret Egg", live = P(false), source = "dig", price = P(0, "paid for by the tracker"),
			odds = {Legendary = P(50), Mythic = P(30), SPOOKY = P(15), Secret = P(5)},
		},
	},

	-- names from the notes; numbers are not. rollChance is percent per hatch, disclosed with the egg's odds.
	mutations = {
		{id = "Golden", mult = P(1.5), rollChance = P(1)},
		{id = "Haunted", mult = P(2), rollChance = P(0.5)},
		{id = "Creepy", mult = P(2.5), rollChance = P(0.25)},
		{id = "Cursed", mult = P(3), rollChance = P(0.1)},
		{id = "UnHoly", mult = P(5), rollChance = P(0.01)},
	},

	fusion = {
		-- smallest first; modelScale stays subtle, as the notes ask
		sizes = {
			{id = "Normal", mult = P(1), modelScale = P(1)},
			{id = "Large", mult = P(1.5), modelScale = P(1.05)},
			{id = "Mega", mult = P(2.25), modelScale = P(1.1)},
			{id = "MASSIVE", mult = P(3.5), modelScale = P(1.2)},
		},
		recipes = {
			{id = "Large", from = "Normal", count = C(4)},
			{id = "Mega", from = "Large", count = C(3)},
			{id = "MASSIVE", from = "Mega", count = C(3)},
		},
		requireSameMutation = P(true),
	},

	rebirth = {
		startBedrooms = C(3),
		bedroomsPerFloor = C(6),
		bedroomsPerRebirth = C(1),
		floorCap = P(3),
		costBase = P(5000, "cost = costBase * (rebirths + 1) ^ costExponent"),
		costExponent = P(2),
		multPerRebirth = P(0.5, "multiplier = 1 + multPerRebirth * rebirths"),
		keepsRemainingFear = P(true, "master prompt's rule; the live game still wipes Fear until Phase 7"),
	},

	accessories = {
		slotsPerCase = P(1),
		boxes = {{id = "RareBox"}, {id = "EpicBox"}, {id = "LegendaryBox"}, {id = "SecretBox"}},
		-- weight is percent within its box, each box totals 100
		items = {
			{id = "CandleCharm", box = "RareBox", mult = P(1.1), weight = P(70)},
			{id = "SpiderBrooch", box = "RareBox", mult = P(1.15), weight = P(30)},
			{id = "BatWings", box = "EpicBox", mult = P(1.25), weight = P(70)},
			{id = "GhostLantern", box = "EpicBox", mult = P(1.35), weight = P(30)},
			{id = "PumpkinCrown", box = "LegendaryBox", mult = P(1.5), weight = P(70)},
			{id = "WitchStaff", box = "LegendaryBox", mult = P(1.75), weight = P(30)},
			{id = "MoonRelic", box = "SecretBox", mult = P(2.5), weight = P(100)},
		},
	},

	shop = {
		rotationSeconds = C(300),
		-- appearChance is percent per rotation; stock is drawn between stockMin and stockMax
		items = {
			{id = "RareBox", kind = "box", price = P(1000), appearChance = P(100), stockMin = P(3), stockMax = P(6)},
			{id = "EpicBox", kind = "box", price = P(10000), appearChance = P(50), stockMin = P(2), stockMax = P(4)},
			{id = "LegendaryBox", kind = "box", price = P(100000), appearChance = P(15), stockMin = P(1), stockMax = P(2)},
			{id = "SecretBox", kind = "box", price = P(1000000), appearChance = P(3), stockMin = P(1), stockMax = P(1)},
			{id = "Tracker", kind = "tracker", price = P(250000), appearChance = P(2), stockMin = P(1), stockMax = P(1)},
		},
	},

	trackers = {
		rewardEgg = "TrackerEgg",
		digExpireSeconds = P(900),
		restoreOnExpire = P(true, "an abandoned dig gives the tracker back, so paid items are never lost"),
	},

	tutorial = {
		eggId = "TutorialEgg",
		freeBoxId = "RareBox",
		freeBoxClaims = C(1),
	},
}
