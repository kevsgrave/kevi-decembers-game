-- Jumpscare RNG v1: claim plot, egg -> inventory -> place in showcase -> timed scares -> Fear
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local HttpService = game:GetService("HttpService")
local JeffRig = require(ReplicatedStorage:WaitForChild("JeffRig"))

local plot = workspace:WaitForChild("Plot")
local contents = plot:WaitForChild("Contents")
local claimPad = plot:WaitForChild("ClaimPad")
local template = ServerStorage:WaitForChild("PlotTemplate")
local BEDROOM_COUNT = #template.Bedrooms:GetChildren()

local EGG_COST = 250
local START_FEAR = 250
local START_BEDROOMS = 3
local MANUAL_BASE = 100
local MANUAL_COOLDOWN = 3

-- from the wiki: Tiers For Monsters (odds are a v1 guess)
local MONSTER_TIERS = {
	{name = "Common", chance = 60, interval = 15, min = 25, max = 400, color = Color3.fromRGB(200, 200, 200)},
	{name = "Rare", chance = 25, interval = 10, min = 200, max = 800, color = Color3.fromRGB(70, 160, 255)},
	{name = "Epic", chance = 10, interval = 8, min = 400, max = 1500, color = Color3.fromRGB(190, 90, 255)},
	{name = "Legendary", chance = 4, interval = 5, min = 800, max = 2500, color = Color3.fromRGB(255, 200, 40)},
	{name = "Mythic", chance = 0.9, interval = 5, min = 1200, max = 5000, color = Color3.fromRGB(255, 70, 90)},
	{name = "SPOOKY", chance = 0.1, interval = 3.5, min = 8000, max = 15000, color = Color3.fromRGB(40, 255, 160)},
}
local TIER_BY_NAME = {}
for _, t in ipairs(MONSTER_TIERS) do TIER_BY_NAME[t.name] = t end
-- Jeff is the only hatchable monster for now; the egg still rolls his rarity
local MONSTER_NAME = "Jeff"

-- from the wiki: Bedroom Tiers, chances in percent
local BEDROOM_TIERS = {
	{name = "GOD", chance = 0.001, mult = 16, color = Color3.fromRGB(255, 60, 200)},
	{name = "Diamond", chance = 0.05, mult = 4, color = Color3.fromRGB(120, 230, 255)},
	{name = "Platinum", chance = 1, mult = 2, color = Color3.fromRGB(220, 230, 240)},
	{name = "Gold", chance = 5, mult = 1.5, color = Color3.fromRGB(255, 200, 50)},
	{name = "Silver", chance = 20, mult = 1.2, color = Color3.fromRGB(190, 190, 200)},
}
local NORMAL_TIER = {name = "Normal", mult = 1, color = Color3.fromRGB(255, 255, 255)}

local GUEST_COLORS = {
	Color3.fromRGB(150, 110, 80), Color3.fromRGB(255, 200, 150), Color3.fromRGB(230, 120, 60),
	Color3.fromRGB(245, 245, 245), Color3.fromRGB(120, 200, 110), Color3.fromRGB(160, 160, 170),
}

local function rollMonsterTier()
	local r = Random.new():NextNumber(0, 100)
	for i = #MONSTER_TIERS, 1, -1 do -- rarest first so tiny chances are checked against the low end
		local t = MONSTER_TIERS[i]
		if r < t.chance then return t end
		r -= t.chance
	end
	return MONSTER_TIERS[1]
end

local function rollBedroomTier()
	local r = Random.new():NextNumber(0, 100)
	for _, t in ipairs(BEDROOM_TIERS) do
		if r < t.chance then return t end
		r -= t.chance
	end
	return NORMAL_TIER
end

local function rebirthCost(rebirths) return 5000 * (rebirths + 1) ^ 2 end
local function rebirthMult(rebirths) return 1 + 0.5 * rebirths end

local function short(n)
	if n >= 1e9 then return string.format("%.1fB", n / 1e9) end
	if n >= 1e6 then return string.format("%.1fM", n / 1e6) end
	if n >= 1e3 then return string.format("%.1fK", n / 1e3) end
	return tostring(math.floor(n))
end

-- remotes
local remotes = Instance.new("Folder") remotes.Name = "Remotes" remotes.Parent = ReplicatedStorage
local rebirthRemote = Instance.new("RemoteEvent") rebirthRemote.Name = "Rebirth" rebirthRemote.Parent = remotes
local popupRemote = Instance.new("RemoteEvent") popupRemote.Name = "Popup" popupRemote.Parent = remotes

local function setLabel(part, text, color)
	local t = part:FindFirstChildWhichIsA("SurfaceGui").Text
	t.Text = text
	if color then t.TextColor3 = color end
end

local function weld(a, b)
	local w = Instance.new("WeldConstraint") w.Part0 = a w.Part1 = b w.Parent = a
end

local function part(model, name, size, cf, color, shape)
	local p = Instance.new("Part")
	p.Name = name p.Size = size p.CFrame = cf p.Color = color p.Anchored = false p.CanCollide = false
	p.Material = Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.Parent = model
	return p
end

-- shortcut: part-built stand-ins; swap for the art/guests and monster meshes once uploaded
local function makeGuest(spot)
	if spot.Parent:FindFirstChild("Guest") then return end
	local m = Instance.new("Model") m.Name = "Guest"
	local c = GUEST_COLORS[math.random(#GUEST_COLORS)]
	local cf = spot.CFrame
	local head = part(m, "Head", Vector3.new(2.4, 2.4, 2.4), cf, c, Enum.PartType.Ball)
	head.Anchored = true
	for _, x in ipairs({-0.8, 0.8}) do
		weld(head, part(m, "Ear", Vector3.new(0.8, 0.8, 0.8), cf * CFrame.new(x, 1.1, 0), c, Enum.PartType.Ball))
		weld(head, part(m, "Eye", Vector3.new(0.35, 0.35, 0.35), cf * CFrame.new(x * 0.5, 0.2, -1.1), Color3.new(0, 0, 0), Enum.PartType.Ball))
	end
	weld(head, part(m, "Body", Vector3.new(2, 1.6, 1.4), cf * CFrame.new(0, -1.7, 0.3), Color3.fromRGB(120, 170, 255)))
	m.PrimaryPart = head
	m.Parent = spot.Parent
	return m
end

-- Jeff built from the Blender model; a rarity-coloured outline shows his tier
local function makeMonster(spot, tier)
	local m = JeffRig.build(spot.Parent, spot.CFrame * CFrame.new(0, 0.25, 0))
	local h = Instance.new("Highlight") h.FillTransparency = 1 h.OutlineColor = tier.color h.Parent = m
	return m
end

-- mild scare: clients play Jeff's Blender scare, then the kid jumps with a "!" bubble
local function playScare(bedroom, monster)
	local guest = bedroom:FindFirstChild("Guest")
	if monster then
		monster:SetAttribute("ScareCount", (monster:GetAttribute("ScareCount") or 0) + 1)
		task.wait(JeffRig.PEAK)
	end
	if guest and guest.Parent then
		local head = guest.PrimaryPart
		local bb = Instance.new("BillboardGui") bb.Size = UDim2.fromOffset(60, 60) bb.StudsOffset = Vector3.new(0, 2.5, 0) bb.Parent = head
		local t = Instance.new("TextLabel") t.Size = UDim2.fromScale(1, 1) t.BackgroundTransparency = 1 t.Font = Enum.Font.FredokaOne
		t.TextScaled = true t.Text = "!" t.TextColor3 = Color3.fromRGB(255, 230, 60) t.TextStrokeTransparency = 0 t.Parent = bb
		TweenService:Create(head, TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out, 0, true), {CFrame = head.CFrame * CFrame.new(0, 2, 0)}):Play()
		task.wait(0.8)
		-- kid runs off, room resets with a new kid
		guest:Destroy()
		task.wait(0.4)
	end
end

local owner
local bedrooms -- the claimed plot's Bedrooms folder
local state = {} -- [player] = {rebirths, unlocked, slots = {[idx] = {tier, name}}}

local function fearOf(player) return player.leaderstats.Fear end

local function pay(player, amount)
	amount = math.floor(amount * rebirthMult(state[player].rebirths))
	fearOf(player).Value += amount
	popupRemote:FireClient(player, "+" .. short(amount) .. " Fear")
	return amount
end

local function setBedroomTier(bedroom, tier)
	bedroom:SetAttribute("Tier", tier.name)
	bedroom:SetAttribute("Mult", tier.mult)
	setLabel(bedroom.TierSign, tier.name .. " x" .. tier.mult, tier.color)
end

-- display case readout: monster name, then expected Fear per scare under it
local function showInfo(player, bedroom)
	local info = bedroom.ShowcaseLid.Info
	local slot = state[player].slots[bedroom:GetAttribute("Index")]
	if not slot then
		info.MonsterName.Text = "Empty"
		info.MonsterName.TextColor3 = Color3.new(1, 1, 1)
		info.Cash.Text = "Hatch an egg!"
		return
	end
	local avg = (slot.tier.min + slot.tier.max) / 2 * bedroom:GetAttribute("Mult") * rebirthMult(state[player].rebirths)
	info.MonsterName.Text = slot.name
	info.MonsterName.TextColor3 = slot.tier.color
	info.Cash.Text = "👻 " .. short(avg) .. " / scare"
end

local function refreshLocks(player)
	local s = state[player]
	for _, b in ipairs(bedrooms:GetChildren()) do
		local open = b:GetAttribute("Index") <= s.unlocked
		b.Lock.Transparency = open and 1 or 0.1
		b.Lock.CanCollide = not open
		b.Lock.SurfaceGui.Enabled = not open
		b.ShowcaseLid.Info.Enabled = open
		b.CrawlHole.ScarePrompt.Enabled = open
		b.ShowcaseGlass.PlacePrompt.Enabled = open
		if open then
			makeGuest(b.GuestSpot)
			showInfo(player, b)
		end
	end
end

local function runShowcase(player, bedroom, slot)
	local tier = slot.tier
	local monster = makeMonster(bedroom.MonsterSpot, tier)
	showInfo(player, bedroom)
	while state[player] and monster.Parent do
		task.wait(tier.interval)
		if not (state[player] and monster.Parent) then break end
		pay(player, math.random(tier.min, tier.max) * bedroom:GetAttribute("Mult"))
		playScare(bedroom, monster)
		setBedroomTier(bedroom, rollBedroomTier())
		showInfo(player, bedroom)
		makeGuest(bedroom.GuestSpot)
	end
end

-- inventory is the Backpack; a StarterGear copy keeps monsters through respawns
local function giveMonster(player, name, tier)
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.ToolTip = tier.name .. " - place in a display case"
	tool:SetAttribute("Tier", tier.name)
	tool:SetAttribute("Uid", HttpService:GenerateGUID(false))
	tool:Clone().Parent = player.StarterGear
	tool.Parent = player.Backpack
end

local function takeMonster(player)
	local held = player.Character and player.Character:FindFirstChildOfClass("Tool")
	local tool = (held and held:GetAttribute("Tier")) and held or nil
	if not tool then
		for _, t in ipairs(player.Backpack:GetChildren()) do
			if t:GetAttribute("Tier") then tool = t break end
		end
	end
	if not tool then return end
	for _, t in ipairs(player.StarterGear:GetChildren()) do
		if t:GetAttribute("Uid") == tool:GetAttribute("Uid") then t:Destroy() end
	end
	local name, tier = tool.Name, TIER_BY_NAME[tool:GetAttribute("Tier")]
	tool:Destroy()
	return name, tier
end

local function hatch(player)
	local s = state[player]
	if player ~= owner or not s then return end
	if fearOf(player).Value < EGG_COST then
		popupRemote:FireClient(player, "Need " .. EGG_COST .. " Fear")
		return
	end
	fearOf(player).Value -= EGG_COST
	local tier = rollMonsterTier()
	giveMonster(player, MONSTER_NAME, tier)
	popupRemote:FireClient(player, "You hatched " .. MONSTER_NAME .. " (" .. tier.name .. ")! Place him in a display case.")
end

-- display case prompt: place the held (or first) monster, or pick the current one back up
local function useShowcase(player, b)
	local s = state[player]
	if player ~= owner or not s or b:GetAttribute("Index") > s.unlocked then return end
	local i = b:GetAttribute("Index")
	local prompt = b.ShowcaseGlass.PlacePrompt
	if s.slots[i] then
		local slot = s.slots[i]
		s.slots[i] = nil
		local m = b:FindFirstChild("Monster") if m then m:Destroy() end
		giveMonster(player, slot.name, slot.tier)
		prompt.ActionText = "Place Monster"
		showInfo(player, b)
		return
	end
	local name, tier = takeMonster(player)
	if not name then
		popupRemote:FireClient(player, "Hatch an egg first!")
		return
	end
	local slot = {tier = tier, name = name}
	s.slots[i] = slot
	prompt.ActionText = "Pick Up"
	task.spawn(runShowcase, player, b, slot)
end

local function manualScare(player, b, last)
	if player ~= owner or not state[player] or not b:FindFirstChild("Guest") then return end
	if last[player] and os.clock() - last[player] < MANUAL_COOLDOWN then return end
	last[player] = os.clock()
	pay(player, MANUAL_BASE * b:GetAttribute("Mult"))
	playScare(b, nil)
	if not state[player].slots[b:GetAttribute("Index")] then
		setBedroomTier(b, rollBedroomTier())
	end
	makeGuest(b.GuestSpot)
end

-- the plot is empty until claimed; claiming copies the bedrooms and egg in
local function claim(player)
	if owner or not state[player] then return end
	owner = player
	for _, child in ipairs(template:GetChildren()) do child:Clone().Parent = contents end
	bedrooms = contents.Bedrooms
	contents.Egg.HatchPrompt.Triggered:Connect(hatch)
	for _, b in ipairs(bedrooms:GetChildren()) do
		setBedroomTier(b, NORMAL_TIER)
		local last = {}
		b.CrawlHole.ScarePrompt.Triggered:Connect(function(p) manualScare(p, b, last) end)
		b.ShowcaseGlass.PlacePrompt.Triggered:Connect(function(p) useShowcase(p, b) end)
	end
	claimPad.ClaimPrompt.Enabled = false
	claimPad.Transparency = 1
	claimPad.Sign.Text.Text = player.DisplayName .. "'s Plot"
	refreshLocks(player)
	popupRemote:FireClient(player, "Plot claimed! Hatch the Spooky Egg.")
end

local function unclaim()
	owner = nil
	bedrooms = nil
	contents:ClearAllChildren()
	claimPad.ClaimPrompt.Enabled = true
	claimPad.Transparency = 0
	claimPad.Sign.Text.Text = "Claim this plot!"
end

claimPad.ClaimPrompt.Triggered:Connect(claim)

rebirthRemote.OnServerEvent:Connect(function(player)
	local s = state[player]
	if player ~= owner or not s or s.unlocked >= BEDROOM_COUNT then return end
	local cost = rebirthCost(s.rebirths)
	if fearOf(player).Value < cost then return end
	fearOf(player).Value = 0
	s.rebirths += 1
	s.unlocked += 1
	player.leaderstats.Rebirths.Value = s.rebirths
	player:SetAttribute("RebirthCost", s.unlocked < BEDROOM_COUNT and rebirthCost(s.rebirths) or -1)
	player:SetAttribute("Multiplier", rebirthMult(s.rebirths))
	refreshLocks(player)
	popupRemote:FireClient(player, "Rebirth! New bedroom unlocked, x" .. rebirthMult(s.rebirths) .. " Fear")
end)

-- shortcut: no DataStore yet, progress resets when you leave
Players.PlayerAdded:Connect(function(player)
	local ls = Instance.new("Folder") ls.Name = "leaderstats" ls.Parent = player
	local fear = Instance.new("IntValue") fear.Name = "Fear" fear.Value = START_FEAR fear.Parent = ls
	local rb = Instance.new("IntValue") rb.Name = "Rebirths" rb.Parent = ls
	player:SetAttribute("RebirthCost", rebirthCost(0))
	player:SetAttribute("Multiplier", 1)
	-- shortcut: one plot on the map; a second player waits for it, per-player plots come with multiplayer
	state[player] = {rebirths = 0, unlocked = START_BEDROOMS, slots = {}}
end)

Players.PlayerRemoving:Connect(function(player)
	state[player] = nil
	if owner == player then unclaim() end
end)
