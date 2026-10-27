-- Jumpscare RNG v1: one plot, egg -> monster -> showcase -> timed scares -> Fear
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local plot = workspace:WaitForChild("Plot")
local bedrooms = plot:WaitForChild("Bedrooms")
local egg = plot:WaitForChild("Egg")

local EGG_COST = 250
local START_FEAR = 250
local START_BEDROOMS = 3
local MANUAL_BASE = 100
local MANUAL_COOLDOWN = 3

-- from the wiki: Tiers For Monsters (odds are a v1 guess)
local MONSTER_TIERS = {
	{name = "Common", chance = 60, interval = 15, min = 25, max = 400, color = Color3.fromRGB(180, 180, 180)},
	{name = "Rare", chance = 25, interval = 10, min = 200, max = 800, color = Color3.fromRGB(70, 140, 255)},
	{name = "Epic", chance = 10, interval = 8, min = 400, max = 1500, color = Color3.fromRGB(170, 80, 255)},
	{name = "Legendary", chance = 4, interval = 5, min = 800, max = 2500, color = Color3.fromRGB(255, 190, 40)},
	{name = "Mythic", chance = 0.9, interval = 5, min = 1200, max = 5000, color = Color3.fromRGB(255, 70, 90)},
	{name = "SPOOKY", chance = 0.1, interval = 3.5, min = 8000, max = 15000, color = Color3.fromRGB(40, 255, 160)},
}
-- placeholder kid-friendly names until the real monster models exist
local MONSTER_NAMES = {"Grinny Pup", "Fuzzy Blue", "Peeper", "Snooze Cat", "Stretchy", "Giggle Ghost", "Mr. Boo", "Wobble"}

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

local function makeMonster(spot, tier, name)
	local m = Instance.new("Model") m.Name = "Monster"
	local cf = spot.CFrame * CFrame.new(0, 2, 0)
	local body = part(m, "Body", Vector3.new(3, 3.4, 3), cf, tier.color, Enum.PartType.Ball)
	body.Anchored = true
	for _, x in ipairs({-0.6, 0.6}) do
		weld(body, part(m, "Eye", Vector3.new(0.9, 0.9, 0.9), cf * CFrame.new(x, 0.5, -1.25), Color3.new(1, 1, 1), Enum.PartType.Ball))
		weld(body, part(m, "Pupil", Vector3.new(0.4, 0.4, 0.4), cf * CFrame.new(x, 0.5, -1.65), Color3.new(0, 0, 0), Enum.PartType.Ball))
		weld(body, part(m, "Horn", Vector3.new(0.4, 0.9, 0.4), cf * CFrame.new(x * 1.2, 1.8, 0), Color3.fromRGB(255, 240, 220)))
	end
	weld(body, part(m, "Mouth", Vector3.new(1.4, 0.3, 0.3), cf * CFrame.new(0, -0.5, -1.4), Color3.fromRGB(60, 20, 40)))
	local bb = Instance.new("BillboardGui") bb.Size = UDim2.fromOffset(160, 50) bb.StudsOffset = Vector3.new(0, 2.8, 0) bb.Parent = body
	local t = Instance.new("TextLabel") t.Size = UDim2.fromScale(1, 1) t.BackgroundTransparency = 1 t.Font = Enum.Font.FredokaOne
	t.TextScaled = true t.TextStrokeTransparency = 0 t.TextColor3 = tier.color t.Text = name .. "\n" .. tier.name t.Parent = bb
	m.PrimaryPart = body
	m.Parent = spot.Parent
	return m
end

-- mild scare: monster hops toward the window, kid jumps with a "!" bubble
local function playScare(bedroom, monster)
	local guest = bedroom:FindFirstChild("Guest")
	if monster then
		local home = monster.PrimaryPart.CFrame
		local tw = TweenService:Create(monster.PrimaryPart, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out, 0, true), {CFrame = home * CFrame.new(0, 1, -0.6)})
		tw:Play()
	end
	if guest then
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

-- per-player state (v1 has one shared plot owned by the first player)
local owner
local state = {} -- [player] = {rebirths, unlocked, slots = {[idx] = {tier, name, bedroomTier}}}

local function fearOf(player) return player.leaderstats.Fear end

local function pay(player, amount, where)
	amount = math.floor(amount * rebirthMult(state[player].rebirths))
	fearOf(player).Value += amount
	popupRemote:FireClient(player, "+" .. amount .. " Fear", where)
	return amount
end

local function setBedroomTier(bedroom, tier)
	bedroom:SetAttribute("Tier", tier.name)
	bedroom:SetAttribute("Mult", tier.mult)
	setLabel(bedroom.TierSign, tier.name .. " x" .. tier.mult, tier.color)
end

local function refreshLocks(player)
	local s = state[player]
	for _, b in ipairs(bedrooms:GetChildren()) do
		local open = b:GetAttribute("Index") <= s.unlocked
		b.Lock.Transparency = open and 1 or 0.15
		b.Lock.CanCollide = not open
		b.Lock.SurfaceGui.Enabled = not open
		b.CrawlHole.ScarePrompt.Enabled = open
		if open and not b:FindFirstChild("Guest") then makeGuest(b.GuestSpot) end
	end
end

local function runShowcase(player, bedroom, slot)
	local tier = slot.tier
	local monster = makeMonster(bedroom.MonsterSpot, tier, slot.name)
	setLabel(bedroom.PayPlate, tier.min .. "-" .. tier.max, Color3.new(1, 1, 1))
	while state[player] and monster.Parent do
		task.wait(tier.interval)
		if not (state[player] and monster.Parent) then break end
		local base = math.random(tier.min, tier.max)
		local got = pay(player, base * bedroom:GetAttribute("Mult"), bedroom.ShowcaseGlass.Position)
		setLabel(bedroom.PayPlate, "+" .. got, Color3.new(1, 1, 1))
		playScare(bedroom, monster)
		setBedroomTier(bedroom, rollBedroomTier())
		makeGuest(bedroom.GuestSpot)
	end
end

local function firstEmptyBedroom(player)
	local s = state[player]
	for i = 1, s.unlocked do
		if not s.slots[i] then return i, bedrooms["Bedroom" .. i] end
	end
end

egg.HatchPrompt.Triggered:Connect(function(player)
	local s = state[player]
	if player ~= owner or not s then return end
	local i, bedroom = firstEmptyBedroom(player)
	if not i then
		popupRemote:FireClient(player, "All showcases are full! Rebirth for more.")
		return
	end
	if fearOf(player).Value < EGG_COST then
		popupRemote:FireClient(player, "Need " .. EGG_COST .. " Fear")
		return
	end
	fearOf(player).Value -= EGG_COST
	local tier = rollMonsterTier()
	local slot = {tier = tier, name = MONSTER_NAMES[math.random(#MONSTER_NAMES)]}
	s.slots[i] = slot
	popupRemote:FireClient(player, "You hatched " .. slot.name .. " (" .. tier.name .. ")!")
	task.spawn(runShowcase, player, bedroom, slot)
end)

for _, b in ipairs(bedrooms:GetChildren()) do
	setBedroomTier(b, NORMAL_TIER)
	local last = {}
	b.CrawlHole.ScarePrompt.Triggered:Connect(function(player)
		if player ~= owner or not state[player] or not b:FindFirstChild("Guest") then return end
		if last[player] and os.clock() - last[player] < MANUAL_COOLDOWN then return end
		last[player] = os.clock()
		pay(player, MANUAL_BASE * b:GetAttribute("Mult"), b.CrawlHole.Position)
		playScare(b, nil)
		if not state[player].slots[b:GetAttribute("Index")] then
			setBedroomTier(b, rollBedroomTier())
		end
		makeGuest(b.GuestSpot)
	end)
end

rebirthRemote.OnServerEvent:Connect(function(player)
	local s = state[player]
	if not s or s.unlocked >= #bedrooms:GetChildren() then return end
	local cost = rebirthCost(s.rebirths)
	if fearOf(player).Value < cost then return end
	fearOf(player).Value = 0
	s.rebirths += 1
	s.unlocked += 1
	player.leaderstats.Rebirths.Value = s.rebirths
	player:SetAttribute("RebirthCost", s.unlocked < #bedrooms:GetChildren() and rebirthCost(s.rebirths) or -1)
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
	state[player] = {rebirths = 0, unlocked = START_BEDROOMS, slots = {}}
	-- shortcut: single plot, first player owns it; per-player plots come with multiplayer
	if not owner then
		owner = player
		refreshLocks(player)
	end
end)

Players.PlayerRemoving:Connect(function(player)
	state[player] = nil
	if owner == player then
		owner = nil
		for _, b in ipairs(bedrooms:GetChildren()) do
			local m = b:FindFirstChild("Monster") if m then m:Destroy() end
			setLabel(b.PayPlate, "Empty")
		end
	end
end)
