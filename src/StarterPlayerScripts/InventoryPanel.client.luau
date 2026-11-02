-- The inventory panel: Monsters, Items (boxes and accessories) and the Index, all from the server's list.
-- Every button only sends a request. The Roblox hotbar is a separate, smaller view of the same saved inventory.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Panels = require(Shared:WaitForChild("Panels"))
local Style = require(Shared:WaitForChild("Style"))

local player = Players.LocalPlayer
local changedRemote = Net.Event("InventoryChanged")
local getRemote = Net.Function("GetInventory")
local holdRemote = Net.Event("HoldMonster")
local favoriteRemote = Net.Event("FavoriteMonster")
local openBoxRemote = Net.Function("OpenBox")
local equipRemote = Net.Function("EquipAccessory")
local unequipRemote = Net.Function("UnequipAccessory")
local openCaseRemote = Net.Event("OpenCase")
local hatchOwnedRemote = Net.Function("HatchOwnedEgg")
local activateTrackerRemote = Net.Function("ActivateTracker")

local LIME, SILVER, GOLD = Style.GREEN, Style.GRAY, Style.GOLD
local label, button = Style.label, Style.button

local gui = Instance.new("ScreenGui") gui.Name = "InventoryPanel" gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local panel, title, closeButton = Style.panel(gui, "Panel", "Inventory", Style.ORANGE)

local tabs = {"Monsters", "Items", "Index"}
local TAB_COLOR = {Monsters = Style.ORANGE, Items = Style.PURPLE, Index = Style.CYAN}
local HEADER_TITLE = {Monsters = "🎒 Monsters", Items = "🎁 Items", Index = "📖 Index"}
local tabButtons = {}
for i, name in tabs do
	local b = button(name, panel, name, Style.GRAY)
	b.Position = UDim2.new((i - 1) / 3, if i == 1 then 12 else 4, 0, 62)
	b.Size = UDim2.new(1 / 3, -14, 0, 40)
	tabButtons[name] = b
end

local sortButton = button("Sort", panel, "", Style.BLUE)
sortButton.Position = UDim2.fromOffset(12, 110) sortButton.Size = UDim2.fromOffset(190, 36)
local hint = label("Hint", panel, "", Color3.fromRGB(235, 235, 245))
hint.Position = UDim2.fromOffset(12, 110) hint.Size = UDim2.new(1, -24, 0, 36)

local list = Style.list(panel, 152)

local rarityRank = {}
for rank, t in ipairs(Config.Balance.rarities) do rarityRank[t.id] = rank end

local SORTS = {
	{name = "Income", less = function(a, b) return a.baseFear > b.baseFear end},
	{name = "Rarity", less = function(a, b) return (rarityRank[a.tier] or 0) > (rarityRank[b.tier] or 0) end},
	{name = "Name", less = function(a, b) return a.kind < b.kind end},
	{name = "Newest", less = function(a, b) return a.order > b.order end},
}
local sortIndex = 1
local currentTab = "Monsters"
local current = nil
local caseSlot = nil -- the display case the panel was opened from, for equipping

-- BoneCharm reads as Bone Charm
local function spaced(id)
	return (string.gsub(id, "(%l)(%u)", "%1 %2"))
end

local function clearList()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
end

local function rowFrame(name, position, height, edge)
	return Style.card(name, list, position, height, edge)
end

local function twoLines(f, top, topColor, bottom, leftPad)
	local a = label("Top", f, top, topColor)
	a.Position = UDim2.fromOffset(leftPad, 6) a.Size = UDim2.new(1, -(leftPad + 110), 0, 30)
	local b = label("Bottom", f, bottom)
	b.Position = UDim2.fromOffset(leftPad, 38) b.Size = UDim2.new(1, -(leftPad + 110), 0, 26)
	return a, b
end

local function actionButton(f, text, color, onPress)
	local b = button("Action", f, text, color)
	b.AnchorPoint = Vector2.new(1, 0.5) b.Position = UDim2.new(1, -8, 0.5, 0) b.Size = UDim2.fromOffset(96, 48)
	b.Activated:Connect(onPress)
	return b
end

local function statusOf(row)
	if row.placedIn then return "In bedroom " .. row.placedIn end
	if row.hotbar then return "Hotbar " .. row.hotbar end
	return "In storage"
end

local function renderMonsters()
	local rows = current and current.rows or {}
	title.Text = "🎒 Monsters " .. #rows .. " / " .. (current and current.capacity or Config.INVENTORY_CAP)
	sortButton.Text = "Sort: " .. SORTS[sortIndex].name
	local less = SORTS[sortIndex].less
	table.sort(rows, function(a, b)
		if less(a, b) then return true end
		if less(b, a) then return false end
		return a.order < b.order
	end)
	for position, row in ipairs(rows) do
		local tier = Config.TIER_BY_NAME[row.tier]
		local f = rowFrame(row.uid, position, 72, tier and tier.color)
		local star = button("Favorite", f, row.favorited and "★" or "☆", row.favorited and GOLD or SILVER)
		star.Position = UDim2.fromOffset(8, 14) star.Size = UDim2.fromOffset(44, 44)
		star.Activated:Connect(function() favoriteRemote:FireServer(row.uid, not row.favorited) end)
		local nameText = row.kind .. " - " .. row.tier
		local extras = {}
		if row.size and row.size ~= "Normal" then table.insert(extras, row.size) end
		if row.mutation then table.insert(extras, row.mutation) end
		if #extras > 0 then nameText ..= " (" .. table.concat(extras, ", ") .. ")" end
		twoLines(f, nameText, tier and tier.color or Color3.new(1, 1, 1), "👻 " .. Config.short(row.baseFear) .. " / scare, " .. statusOf(row), 60)
		if not row.placedIn then
			actionButton(f, "Hold", LIME, function() holdRemote:FireServer(row.uid) end)
		end
	end
end

local function boxOdds(boxId)
	local parts = {}
	for _, item in ipairs(Config.BOX_ITEMS[boxId] or {}) do
		table.insert(parts, string.format("%s %.1f%%", spaced(item.id), item.weight))
	end
	return table.concat(parts, ", ")
end

-- closes the panel so a hatch's reveal is in full view; set once the panel functions exist
local setOpenLater = function() end

local function renderItems()
	local boxes = current and current.boxes or {}
	local accessories = current and current.accessories or {}
	title.Text = HEADER_TITLE.Items
	hint.Text = if caseSlot then "Choose an accessory for bedroom " .. caseSlot else "Press F at a display case to equip an accessory there"
	local position = 0
	for _, box in ipairs(boxes) do
		position += 1
		local f = rowFrame(box.uid, position, 96)
		local top = label("Top", f, spaced(box.id), GOLD)
		top.Position = UDim2.fromOffset(12, 6) top.Size = UDim2.new(1, -120, 0, 30)
		local odds = label("Odds", f, boxOdds(box.id))
		odds.Position = UDim2.fromOffset(12, 38) odds.Size = UDim2.new(1, -120, 0, 50) odds.TextWrapped = true
		actionButton(f, "Open", LIME, function()
			local ok, success, result = pcall(openBoxRemote.InvokeServer, openBoxRemote, box.uid)
			if ok and success then
				hint.Text = "You got " .. spaced(result.id) .. ", x" .. result.mult .. " Fear!"
			end
		end)
	end
	for _, egg in ipairs(current and current.eggs or {}) do
		position += 1
		local details = Config.EGGS[egg.id]
		local parts = {}
		for _, r in ipairs(Config.Balance.rarities) do
			local chance = details and details.odds[r.id]
			if chance and chance > 0 then table.insert(parts, r.id .. " " .. tostring(chance) .. "%") end
		end
		local f = rowFrame(egg.uid, position, 72)
		twoLines(f, details and details.name or egg.id, GOLD, table.concat(parts, ", "), 12)
		actionButton(f, "Hatch", LIME, function()
			setOpenLater()
			pcall(hatchOwnedRemote.InvokeServer, hatchOwnedRemote, egg.uid)
		end)
	end
	for _, tracker in ipairs(current and current.trackers or {}) do
		position += 1
		local f = rowFrame(tracker.uid, position, 72)
		local active = tracker.state == "Activated"
		twoLines(f, "Tracker", Color3.fromRGB(120, 255, 220), if active then "Follow the arrow to your buried egg" else "Leads you to a secret egg you can dig up", 12)
		if not active then
			actionButton(f, "Use", LIME, function()
				pcall(activateTrackerRemote.InvokeServer, activateTrackerRemote, tracker.uid)
			end)
		end
	end
	table.sort(accessories, function(a, b) return a.mult > b.mult end)
	for _, item in ipairs(accessories) do
		position += 1
		local f = rowFrame(item.uid, position, 72)
		twoLines(f, spaced(item.id), Color3.fromRGB(180, 230, 255), "x" .. item.mult .. " Fear, " .. (item.slot and "on bedroom " .. item.slot or "not equipped"), 12)
		if item.slot then
			actionButton(f, "Remove", SILVER, function() pcall(unequipRemote.InvokeServer, unequipRemote, item.slot) end)
		elseif caseSlot then
			actionButton(f, "Equip", LIME, function() pcall(equipRemote.InvokeServer, equipRemote, caseSlot, item.uid) end)
		end
	end
	if position == 0 then
		local f = rowFrame("Empty", 1, 56)
		local t = label("Top", f, "No items yet. Boxes come from the shop.", Color3.new(1, 1, 1))
		t.Position = UDim2.fromOffset(12, 12) t.Size = UDim2.new(1, -24, 0, 32)
	end
end

local function renderIndex()
	local index = current and current.index or {}
	local found, total = 0, 0
	-- the stand-in first, because it's the only monster hatches give until original models exist
	local entries = {{id = Config.MONSTER_KIND, name = Config.MONSTER_KIND .. " (stand-in)", rarity = nil, known = index[Config.MONSTER_KIND]}}
	-- once the roster is on, the stand-in leaves the list unless this player owns one
	if Config.Balance.content.hatchRoster and not index[Config.MONSTER_KIND] then entries = {} end
	for _, m in ipairs(Config.Balance.monsters) do
		table.insert(entries, {id = m.id, name = m.name, rarity = m.rarity, baseFear = m.baseFear, concept = m.concept, known = index[m.id]})
	end
	for position, e in ipairs(entries) do
		if e.rarity then
			total += 1
			if e.known then found += 1 end
		end
		local tier = e.rarity and Config.TIER_BY_NAME[e.rarity]
		local f = rowFrame(e.id, position, 66, if e.known and tier then tier.color else nil)
		local a = label("Top", f, if e.known then e.name else "???", if e.known and tier then tier.color else Color3.new(0.75, 0.75, 0.8))
		a.Position = UDim2.fromOffset(12, 6) a.Size = UDim2.new(1, -24, 0, 28)
		local detail = if e.rarity then e.rarity else "Any rarity"
		if e.known and e.concept then detail ..= ": " .. e.concept end
		if not e.known then detail ..= ", not discovered yet" end
		local seen = current and current.seen and current.seen[e.id]
		if seen then
			local badges = {}
			if seen.BestSize and seen.BestSize ~= "Normal" then table.insert(badges, "Best size: " .. seen.BestSize) end
			for mutation in seen.Mutations or {} do table.insert(badges, mutation) end
			table.sort(badges)
			if #badges > 0 then detail ..= " [" .. table.concat(badges, ", ") .. "]" end
		end
		local b = label("Bottom", f, detail)
		b.Position = UDim2.fromOffset(12, 36) b.Size = UDim2.new(1, -24, 0, 24)
	end
	title.Text = "📖 Index " .. found .. " / " .. total
	hint.Text = if Config.Balance.content.hatchRoster then "Hatch eggs to discover every species" else "Species can't be found yet. Hatches are Jeff for now."
end

local function render()
	clearList()
	sortButton.Visible = currentTab == "Monsters"
	hint.Visible = currentTab ~= "Monsters"
	panel.Header.BackgroundColor3 = TAB_COLOR[currentTab]
	for name, b in tabButtons do
		b.BackgroundColor3 = if name == currentTab then TAB_COLOR[name] else Style.GRAY
	end
	if currentTab == "Monsters" then
		renderMonsters()
	elseif currentTab == "Items" then
		renderItems()
	else
		renderIndex()
	end
end

local function setOpen(open)
	panel.Visible = open
	if open then render() else caseSlot = nil end
end

setOpenLater = function() setOpen(false) end

local function showTab(name)
	currentTab = name
	render()
end
for name, b in tabButtons do
	b.Activated:Connect(function() showTab(name) end)
end

changedRemote.OnClientEvent:Connect(function(state)
	current = state
	if panel.Visible then render() end
end)

-- the server says this player used a case's Accessory prompt
openCaseRemote.OnClientEvent:Connect(function(slot)
	caseSlot = slot
	currentTab = "Items"
	setOpen(true)
end)

-- what the HUD's buttons and the book's prompt open
Panels.register("Inventory", function()
	currentTab = "Monsters"
	setOpen(true)
end, panel)
Panels.register("Index", function()
	currentTab = "Index"
	setOpen(true)
end, panel)
game:GetService("ProximityPromptService").PromptTriggered:Connect(function(prompt)
	if prompt.Name == "IndexPrompt" then Panels.open("Index") end
end)
closeButton.Activated:Connect(function() setOpen(false) end)
sortButton.Activated:Connect(function()
	sortIndex = sortIndex % #SORTS + 1
	render()
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.I then Panels.toggle("Inventory") end
end)

-- the panel may load after the server's first update
local ok, state = pcall(getRemote.InvokeServer, getRemote)
if ok and state and not current then current = state end
