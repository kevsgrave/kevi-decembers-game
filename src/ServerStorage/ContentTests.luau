-- The roster, placeholders, settings and premium safety. Touches nothing in the place.
-- Studio command bar: print(require(game.ServerStorage.ContentTests)())
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local CONFIG_PATH = 'require%(game:GetService%("ReplicatedStorage"%):WaitForChild%("Shared"%):WaitForChild%("Config"%)%)'

return function(): string
	local lines, failed = {}, 0
	local function check(name: string, ok: boolean, detail: string?)
		if not ok then failed += 1 end
		table.insert(lines, `{if ok then "PASS" else "FAIL"}  {name}{if detail then " -> " .. detail else ""}`)
	end

	local server = ServerScriptService.Server:Clone()
	ReplicatedStorage.Shared:Clone().Parent = server
	for _, name in {"DataTemplate", "Premium", "Inventory"} do
		server[name].Source = server[name].Source:gsub(CONFIG_PATH, "require(script.Parent.Shared.Config)")
	end
	local Config = require(server.Shared.Config)
	local MonsterRig = require(server.Shared.MonsterRig)
	local Sounds = require(server.Shared.Sounds)
	local UiFit = require(server.Shared.UiFit)
	local Remotes = require(server.Shared.Remotes)
	local DataTemplate = require(server.DataTemplate)
	local Inventory = require(server.Inventory)
	local Premium = require(server.Premium)

	-- the roster
	local monsters = Config.Balance.monsters
	check("42 species", #monsters == 42)
	local banned = {"jeff", "smile dog", "huggy", "sulley", "james p", "wazowski", "sonic", "catnap", "alice"}
	local clean, named, scares = true, true, true
	for _, m in monsters do
		local lower = (m.name .. " " .. m.concept .. " " .. m.scare):lower()
		for _, word in banned do
			if lower:find(word, 1, true) then clean = false end
		end
		if m.name == "" or m.concept == "" then named = false end
		if m.scare == "" then scares = false end
	end
	check("no roster name or concept uses a character on the do-not-copy list", clean)
	check("every species has a name and concept", named)
	check("every species has its own scare direction", scares)

	-- picking a species
	for _, r in Config.Balance.rarities do
		local list = Config.SPECIES_BY_TIER[r.id]
		check(`{r.id} has species to hatch`, list ~= nil and #list > 0)
		local first, last = Config.pickSpecies(r.id, 0), Config.pickSpecies(r.id, 0.99999)
		check(`{r.id} rolls cover its list`, first == list[1] and last == list[#list])
	end
	local rng = Random.new(3)
	local seen = {}
	for _ = 1, 5000 do seen[Config.pickSpecies("Common", rng:NextNumber()).id] = true end
	local commons = 0
	for _ in seen do commons += 1 end
	check("every Common species can hatch", commons == #Config.SPECIES_BY_TIER.Common)
	check("names show instead of ids", Config.displayName("sock-goblin") == "Sock Goblin" and Config.displayName("Jeff") == "Jeff")
	check("a species pays its own listed amount, inside its band", (function()
		local s = Config.SPECIES.mothling
		local tier = Config.TIER_BY_NAME[s.rarity]
		return s.baseFear == 390 and s.baseFear >= tier.min and s.baseFear <= tier.max
	end)())
	check("the roster stays switched off until the owner approves it", Config.Balance.content.hatchRoster == false)

	-- placeholders, built off in nothing
	local allBuilt, labelled = true, true
	local looks = {}
	for _, m in monsters do
		local ok, model = pcall(MonsterRig.build, nil, CFrame.new(), m.id, "PlaceholderDisplay", 1, m.name)
		if not ok or not model:FindFirstChild("Body") then
			allBuilt = false
		else
			local bb = model.Body:FindFirstChildWhichIsA("BillboardGui")
			if not bb or not bb.TextLabel.Text:find("placeholder", 1, true) then labelled = false end
			local look = MonsterRig.look(m.id)
			looks[tostring(look.color) .. tostring(look.shape)] = true
			model:Destroy()
		end
	end
	check("every species can be built", allBuilt)
	check("every placeholder is labelled as one", labelled)
	local distinct = 0
	for _ in looks do distinct += 1 end
	check("placeholders can be told apart", distinct >= 35, distinct .. " distinct of 42")
	local sized = MonsterRig.build(nil, CFrame.new(), "sock-goblin", "PlaceholderRoom", 1.2)
	check("a fused placeholder is bigger", math.abs(sized:GetScale() - 1.2) < 0.001)
	sized:Destroy()

	-- sounds: nothing plays until approved
	local anyId = false
	for _, id in Sounds.IDS do anyId = true end
	check("no sound is in the game without approval", not anyId)
	check("playing an unset sound is safe", pcall(Sounds.play, "scare"))

	-- settings
	check("reduced scares is saved, off by default", DataTemplate.new().Settings.ReducedScares == false)
	check("the setting remote takes a key and on/off", Remotes.checkArgs("SetSetting", "ReducedScares", true) == true)
	check("the volume remote refuses NaN", Remotes.checkArgs("SetVolume", "MusicVolume", 0 / 0) == false)
	check("the volume remote refuses text", Remotes.checkArgs("SetVolume", "MusicVolume", "loud") == false)

	-- screen fit
	check("a PC gets full size", UiFit.factor(1920, 1080) == 1)
	check("a landscape phone shrinks, but stays readable", UiFit.factor(812, 375) == 0.6)
	check("a portrait phone shrinks, but stays readable", UiFit.factor(375, 812) == 0.6)
	check("a tablet sits between", UiFit.factor(1024, 768) < 1 and UiFit.factor(1024, 768) > 0.6)

	-- premium: nothing today, and idempotent when there is
	check("no Robux products are configured, so no Robux interface runs", not Premium.configured())
	local d = DataTemplate.new()
	local product = {id = "TestPack", productId = 1, grantFear = 1000}
	local before = d.Fear
	check("a receipt grants once", Premium.grant(d, "r1", product) == "granted" and d.Fear == before + 1000)
	check("a repeat of that receipt grants nothing", Premium.grant(d, "r1", product) == "already" and d.Fear == before + 1000)
	check("a different receipt grants again", Premium.grant(d, "r2", product) == "granted" and d.Fear == before + 2000)
	check("an unknown product grants nothing", Premium.grant(d, "r3", nil) == "unknown" and d.Receipts.r3 == nil and d.Fear == before + 2000)

	-- inventory shows names
	local inv = DataTemplate.new()
	Inventory.add(inv, DataTemplate.newMonster("sock-goblin", "Common", 50, "egg"))
	check("the panel shows a species' name", Inventory.snapshot(inv).rows[1].kind == "Sock Goblin")
	check("the index still uses the species id", inv.Index["sock-goblin"] == true)

	table.insert(lines, `{if failed == 0 then "ALL PASSED" else failed .. " FAILED"} ({#lines} checks)`)
	return table.concat(lines, "\n")
end
