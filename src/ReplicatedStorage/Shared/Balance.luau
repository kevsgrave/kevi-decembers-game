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
		fear = P(500, "exactly one Starter Egg, on top of the tutorial's free Promise Egg"),
		monsterKind = P("Jeff", "stand-in until original models exist, see docs/spec/OVERRIDES.md"),
	},

	economy = {
		maxFear = P(1e15, "well below 2^53 so Fear stays an exact integer"),
		inventoryCap = P(250),
		hotbarSlots = P(9, "the number keys; the rest of the inventory is in the panel"),
	},

	manual = {
		baseFear = C(100),
		cooldownSeconds = P(8),
		multPerRebirth = P(0.25, "same as automatic scares"),
		maxTimingBonus = P(1.2, "a Perfect tap on the timing bar"),
		goodTimingBonus = P(1.1, "a Good tap"),
		perfectAt = P(0.75, "where the mark sits on the bar, 0 to 1"),
		perfectWidth = P(0.1),
		goodWidth = P(0.3),
		crawlSeconds = P(0.8),
		cueSeconds = P(2.4),
	},

	-- server rate limits for prompts and remotes
	limits = {
		hatch = {capacity = P(3), refillPerSecond = P(1.5)},
		items = {capacity = P(6), refillPerSecond = P(3)},
		showcase = {capacity = P(4), refillPerSecond = P(2)},
		rebirth = {capacity = P(2), refillPerSecond = P(0.5)},
		inventory = {capacity = P(8), refillPerSecond = P(4)},
		manual = {capacity = P(4), refillPerSecond = P(2)},
	},

	-- least rare first; from Tiers For Monsters. Secret has no numbers in the notes.
	rarities = {
		{id = "Common", minFear = C(25), maxFear = C(400), scareSeconds = C(15)},
		{id = "Rare", minFear = C(200), maxFear = C(800), scareSeconds = C(10)},
		{id = "Epic", minFear = C(400), maxFear = C(1500), scareSeconds = C(8)},
		{id = "Legendary", minFear = C(800), maxFear = C(2500), scareSeconds = C(5)},
		{id = "Mythic", minFear = C(1200), maxFear = C(5000), scareSeconds = C(5)},
		{id = "SPOOKY", minFear = C(8000), maxFear = C(15000), scareSeconds = C(3.5)},
		{id = "Secret", minFear = P(20000), maxFear = P(35000), scareSeconds = P(3)},
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

	-- the design package's 42 original species. Data only until original models exist: hatches stay Jeff until then.
	monsters = {
		{id = "sock-goblin", name = "Sock Goblin", rarity = "Common", baseFear = P(50), concept = "Tiny stitched gremlin with runaway socks"},
		{id = "dust-bopper", name = "Dust Bopper", rarity = "Common", baseFear = P(85), concept = "Dustball creature with jelly legs"},
		{id = "boo-balloon", name = "Boo Balloon", rarity = "Common", baseFear = P(125), concept = "Floating balloon ghost with painted face"},
		{id = "puddle-imp", name = "Puddle Imp", rarity = "Common", baseFear = P(165), concept = "Rain puddle imp in boots"},
		{id = "pumpkin-peeker", name = "Pumpkin Peeker", rarity = "Common", baseFear = P(210), concept = "Miniature animated jack-o-lantern"},
		{id = "curtain-crawler", name = "Curtain Crawler", rarity = "Common", baseFear = P(270), concept = "Friendly six-armed cloth creature"},
		{id = "wobble-wisp", name = "Wobble Wisp", rarity = "Common", baseFear = P(335), concept = "Neon flame orb with drowsy eyes"},
		{id = "mothling", name = "Mothling", rarity = "Common", baseFear = P(390), concept = "Big moth with moon wings and antennae"},
		{id = "grinling-hound", name = "Grinling Hound", rarity = "Rare", baseFear = P(225), concept = "Patchwork hound with a crooked lantern smile"},
		{id = "lantern-jaw", name = "Lantern Jaw", rarity = "Rare", baseFear = P(300), concept = "Walking lantern with chatterbox teeth"},
		{id = "shiver-jack", name = "Shiver Jack", rarity = "Rare", baseFear = P(365), concept = "Tall scarf-wearing scarecrow prankster"},
		{id = "clockwork-clown", name = "Clockwork Clown", rarity = "Rare", baseFear = P(440), concept = "Wind-up toy clown with square spring limbs"},
		{id = "blanket-mimic", name = "Blanket Mimic", rarity = "Rare", baseFear = P(525), concept = "Blanket with bright glowing button eyes"},
		{id = "paper-shadow", name = "Paper Shadow", rarity = "Rare", baseFear = P(615), concept = "Origami silhouette with impossible folds"},
		{id = "mossy-howler", name = "Mossy Howler", rarity = "Rare", baseFear = P(700), concept = "Forest goblin with a bell collar"},
		{id = "sneakwood", name = "Sneakwood", rarity = "Rare", baseFear = P(790), concept = "Root creature with wooden mask"},
		{id = "plush-prowler", name = "Plush Prowler", rarity = "Epic", baseFear = P(450), concept = "Round-shouldered plush beast with mismatched colors"},
		{id = "dream-snatcher", name = "Dream Snatcher", rarity = "Epic", baseFear = P(590), concept = "Sleepy star-cat with a tiny crescent tail"},
		{id = "goggle-gremlin", name = "Goggle Gremlin", rarity = "Epic", baseFear = P(755), concept = "Triple-eyed mechanical goblin with copper goggles"},
		{id = "lullaby-lurker", name = "Lullaby Lurker", rarity = "Epic", baseFear = P(910), concept = "Musical marionette with a bell-shaped hood"},
		{id = "mirror-minnow", name = "Mirror Minnow", rarity = "Epic", baseFear = P(1090), concept = "Floating aquarium-fish ghost with mirror scales"},
		{id = "fuzzy-fury", name = "Fuzzy Fury", rarity = "Epic", baseFear = P(1270), concept = "Huge puffy monster with tiny feet and colorful horns"},
		{id = "hallway-marionette", name = "Hallway Marionette", rarity = "Epic", baseFear = P(1480), concept = "Porcelain hallway puppet on glowing strings"},
		{id = "velvet-beast", name = "Velvet Beast", rarity = "Legendary", baseFear = P(850), concept = "Horned velvet guardian with embroidered moon patches"},
		{id = "moonbite-mutt", name = "Moonbite Mutt", rarity = "Legendary", baseFear = P(1125), concept = "Spectral long-legged wolf with crystal collar"},
		{id = "jester-of-static", name = "Jester of Static", rarity = "Legendary", baseFear = P(1460), concept = "Television-faced royal jester"},
		{id = "crowned-candle", name = "Crowned Candle", rarity = "Legendary", baseFear = P(1800), concept = "Wax creature wearing a floating crown"},
		{id = "nightmare-astronaut", name = "Nightmare Astronaut", rarity = "Legendary", baseFear = P(2150), concept = "Patchwork astronaut filled with stars"},
		{id = "static-phantom", name = "Static Phantom", rarity = "Legendary", baseFear = P(2475), concept = "Ribbonlike phantom of crackling purple static"},
		{id = "wardrobe-king", name = "The Wardrobe King", rarity = "Mythic", baseFear = P(1400), concept = "Regal cedar wardrobe with many little doors"},
		{id = "starved-clock", name = "The Starved Clock", rarity = "Mythic", baseFear = P(2050), concept = "Animated grandfather clock made of floating numbers"},
		{id = "madame-eclipse", name = "Madame Eclipse", rarity = "Mythic", baseFear = P(2950), concept = "Masked celestial showwoman in crescent cape"},
		{id = "dread-leviathan", name = "Dread Leviathan", rarity = "Mythic", baseFear = P(3850), concept = "Long ribbon-serpent made of storm clouds"},
		{id = "pale-conductor", name = "The Pale Conductor", rarity = "Mythic", baseFear = P(4900), concept = "Ghostly orchestra conductor with spiderlike baton"},
		{id = "hollow-monarch", name = "The Hollow Monarch", rarity = "SPOOKY", baseFear = P(8200), concept = "Towering hollow porcelain monarch with orbiting masks"},
		{id = "night-parade", name = "The Night Parade", rarity = "SPOOKY", baseFear = P(9700), concept = "One collectible monster: a tiny ghost marching band"},
		{id = "mourning-bell", name = "The Mourning Bell", rarity = "SPOOKY", baseFear = P(11200), concept = "Floating gothic bell with cartoon eye"},
		{id = "candle-eater", name = "The Candle Eater", rarity = "SPOOKY", baseFear = P(13200), concept = "Lantern-winged moth giant with a hollow mask"},
		{id = "inkwell-witch", name = "The Inkwell Witch", rarity = "SPOOKY", baseFear = P(14850), concept = "Spinning ink spirit in paper dress"},
		{id = "zero-hour", name = "Zero Hour", rarity = "Secret", baseFear = P(21000), concept = "Transparent clock-shaped anomaly, no copyrighted analogues"},
		{id = "unseen-host", name = "The Unseen Host", rarity = "Secret", baseFear = P(26500), concept = "Empty tuxedo with floating invitation cards"},
		{id = "last-lantern", name = "The Last Lantern", rarity = "Secret", baseFear = P(34000), concept = "Ancient living lighthouse lantern with constellation eyes"},
	},

	-- odds in percent, each egg totals 100. Only the tutorial egg's odds come from the notes.
	-- live = false: defined, not offered in the game yet.
	eggs = {
		{
			id = "StarterEgg", name = "Starter Egg", live = C(true), source = "fear", price = P(500),
			odds = {Common = P(78), Rare = P(21), Epic = P(1)},
		},
		{
			id = "CreepyEgg", name = "Creepy Egg", live = P(true), source = "fear", price = P(6000),
			odds = {Rare = P(65), Epic = P(30), Legendary = P(5)},
		},
		{
			id = "MoonEgg", name = "Moon Egg", live = P(true), source = "fear", price = P(60000),
			odds = {Epic = P(65), Legendary = P(30), Mythic = P(5)},
		},
		{
			id = "HauntedEgg", name = "Haunted Egg", live = P(true), source = "fear", price = P(600000),
			odds = {Legendary = P(65), Mythic = P(33), SPOOKY = P(2)},
		},
		{
			id = "NightmareEgg", name = "Nightmare Egg", live = P(true), source = "fear", price = P(6000000),
			odds = {Mythic = P(85), SPOOKY = P(14.9), Secret = P(0.1)},
		},
		{
			id = "TutorialEgg", name = "Tutorial Promise Egg", live = P(false), source = "tutorial", price = P(0, "one-use voucher, so the tutorial can't soft-lock"),
			odds = {Epic = C(80), Legendary = C(20)},
		},
		{
			id = "BuriedMoonEgg", name = "Buried Moon Egg", live = P(false), source = "dig", price = P(0, "earned with a tracker"),
			odds = {Mythic = P(85), SPOOKY = P(14), Secret = P(1)},
		},
	},

	-- names from the notes; numbers are not. rollChance is percent per hatch, disclosed with the egg's odds.
	mutations = {
		{id = "Golden", mult = P(1.2), rollChance = P(2)},
		{id = "Haunted", mult = P(1.4), rollChance = P(0.9)},
		{id = "Creepy", mult = P(1.65), rollChance = P(0.35)},
		{id = "Cursed", mult = P(2), rollChance = P(0.13)},
		{id = "UnHoly", mult = P(2.5), rollChance = P(0.02)},
	},

	fusion = {
		-- smallest first; modelScale stays subtle, as the notes ask
		sizes = {
			{id = "Normal", mult = P(1), modelScale = P(1)},
			{id = "Large", mult = P(1.5), modelScale = P(1.07)},
			{id = "Mega", mult = P(2.25), modelScale = P(1.13)},
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
		floorHeight = P(32, "studs between floors, clear of the gable roofs"),
		costBase = P(50000, "cost = costBase * costGrowth ^ rebirths"),
		costGrowth = P(3),
		cooldownSeconds = P(3),
		multPerRebirth = P(0.25, "multiplier = 1 + multPerRebirth * rebirths"),
		keepsRemainingFear = P(true, "owner's decision, see docs/spec/OVERRIDES.md"),
	},

	accessories = {
		slotsPerCase = P(1),
		boxes = {{id = "RareBox"}, {id = "EpicBox"}, {id = "LegendaryBox"}, {id = "SecretBox"}},
		-- weight is percent within its box, each box totals 100: equal chances, shown to the player
		items = {
			{id = "BoneCharm", box = "RareBox", mult = P(1.1), weight = P(25)},
			{id = "SqueakyBat", box = "RareBox", mult = P(1.15), weight = P(25)},
			{id = "CobwebBanner", box = "RareBox", mult = P(1.2), weight = P(25)},
			{id = "LanternTag", box = "RareBox", mult = P(1.25), weight = P(25)},
			{id = "EnchantedChime", box = "EpicBox", mult = P(1.3), weight = P(25)},
			{id = "GhostCamera", box = "EpicBox", mult = P(1.35), weight = P(25)},
			{id = "MoonMirror", box = "EpicBox", mult = P(1.4), weight = P(25)},
			{id = "TrickLantern", box = "EpicBox", mult = P(1.5), weight = P(25)},
			{id = "ClockworkHalo", box = "LegendaryBox", mult = P(1.6), weight = P(100 / 3)},
			{id = "PhantomProjector", box = "LegendaryBox", mult = P(1.7), weight = P(100 / 3)},
			{id = "ShadowOrgan", box = "LegendaryBox", mult = P(1.85), weight = P(100 / 3)},
			{id = "RiftHourglass", box = "SecretBox", mult = P(2), weight = P(100 / 3)},
			{id = "HeartOfMidnight", box = "SecretBox", mult = P(2.2), weight = P(100 / 3)},
			{id = "LivingMoon", box = "SecretBox", mult = P(2.4), weight = P(100 / 3)},
		},
	},

	shop = {
		rotationSeconds = C(300),
		offersMin = P(1, "the package says 3, but with only 5 items that fills the shelf and makes Legendary appear about 90% of the time instead of 20%"),
		offersMax = P(5),
		-- appearChance is percent per shelf check; stock is each player's own allotment per rotation
		items = {
			{id = "RareBox", kind = "box", price = P(2500), appearChance = P(100), stock = P(3)},
			{id = "EpicBox", kind = "box", price = P(30000), appearChance = P(60), stock = P(2)},
			{id = "LegendaryBox", kind = "box", price = P(350000), appearChance = P(20), stock = P(1)},
			{id = "SecretBox", kind = "box", price = P(3000000), appearChance = P(3), stock = P(1)},
			{id = "Tracker", kind = "tracker", price = P(800000), appearChance = P(2), stock = P(1)},
		},
	},

	trackers = {
		rewardEgg = "BuriedMoonEgg",
		digExpireSeconds = P(900),
		digDistance = P(12, "how close you must be to dig"),
		digHoldSeconds = P(2),
		restoreOnExpire = P(true, "an abandoned dig gives the tracker back, so paid items are never lost"),
	},

	tutorial = {
		eggId = "TutorialEgg",
		freeBoxId = "RareBox",
		freeBoxClaims = C(1),
	},
}
