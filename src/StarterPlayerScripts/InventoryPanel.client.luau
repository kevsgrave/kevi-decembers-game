-- The inventory panel: every monster you own, from the server's list. Holding or favoriting only sends a request.
-- The Roblox hotbar is a separate, smaller view of the same saved inventory.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))

local player = Players.LocalPlayer
local changedRemote = Net.Event("InventoryChanged")
local getRemote = Net.Function("GetInventory")
local holdRemote = Net.Event("HoldMonster")
local favoriteRemote = Net.Event("FavoriteMonster")

local DARK = Color3.fromRGB(20, 10, 40)
local PANEL = Color3.fromRGB(60, 40, 110)
local ROW = Color3.fromRGB(85, 60, 145)
local LIME = Color3.fromRGB(60, 200, 90)
local SILVER = Color3.fromRGB(150, 150, 165)
local GOLD = Color3.fromRGB(255, 200, 40)

local gui = Instance.new("ScreenGui") gui.Name = "InventoryPanel" gui.ResetOnSpawn = false
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(obj, r) Instance.new("UICorner", obj).CornerRadius = UDim.new(0, r) end
local function stroke(obj, border)
	local s = Instance.new("UIStroke") s.Thickness = 3 s.Color = DARK
	if border then s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border end
	s.Parent = obj
end
local function label(name, parent, text, color)
	local t = Instance.new("TextLabel") t.Name = name t.BackgroundTransparency = 1 t.Font = Enum.Font.FredokaOne
	t.TextScaled = true t.TextColor3 = color or Color3.new(1, 1, 1) t.Text = text t.TextXAlignment = Enum.TextXAlignment.Left t.Parent = parent
	return t
end
local function button(name, parent, text, color)
	local b = Instance.new("TextButton") b.Name = name b.BackgroundColor3 = color b.Font = Enum.Font.FredokaOne
	b.TextScaled = true b.TextColor3 = Color3.new(1, 1, 1) b.Text = text b.Parent = parent
	corner(b, 10) stroke(b, true)
	return b
end

local openButton = button("Open", gui, "Inventory", PANEL)
openButton.AnchorPoint = Vector2.new(0, 0.5)
openButton.Size = UDim2.fromOffset(150, 56)
openButton.Position = UDim2.new(0, 16, 0.5, 92) -- under the rebirth button

local panel = Instance.new("Frame") panel.Name = "Panel" panel.Visible = false
panel.AnchorPoint = Vector2.new(0.5, 0.5) panel.Position = UDim2.fromScale(0.5, 0.5) panel.Size = UDim2.fromScale(0.92, 0.82)
panel.BackgroundColor3 = PANEL panel.Parent = gui
corner(panel, 18) stroke(panel, true)
local cap = Instance.new("UISizeConstraint") cap.MaxSize = Vector2.new(640, 560) cap.Parent = panel

local title = label("Title", panel, "Inventory", Color3.new(1, 1, 1))
title.Position = UDim2.fromOffset(16, 10) title.Size = UDim2.new(1, -90, 0, 34)
local closeButton = button("Close", panel, "X", SILVER)
closeButton.AnchorPoint = Vector2.new(1, 0) closeButton.Position = UDim2.new(1, -10, 0, 8) closeButton.Size = UDim2.fromOffset(44, 44)
local sortButton = button("Sort", panel, "", ROW)
sortButton.Position = UDim2.fromOffset(16, 52) sortButton.Size = UDim2.fromOffset(190, 40)

local list = Instance.new("ScrollingFrame") list.Name = "List"
list.Position = UDim2.fromOffset(12, 100) list.Size = UDim2.new(1, -24, 1, -112)
list.BackgroundTransparency = 1 list.BorderSizePixel = 0 list.ScrollBarThickness = 8
list.CanvasSize = UDim2.new() list.AutomaticCanvasSize = Enum.AutomaticSize.Y list.Parent = panel
local layout = Instance.new("UIListLayout") layout.Padding = UDim.new(0, 6) layout.SortOrder = Enum.SortOrder.LayoutOrder layout.Parent = list

local rarityRank = {}
for rank, t in ipairs(Config.Balance.rarities) do rarityRank[t.id] = rank end

local SORTS = {
	{name = "Income", less = function(a, b) return a.baseFear > b.baseFear end},
	{name = "Rarity", less = function(a, b) return (rarityRank[a.tier] or 0) > (rarityRank[b.tier] or 0) end},
	{name = "Name", less = function(a, b) return a.kind < b.kind end},
	{name = "Newest", less = function(a, b) return a.order > b.order end},
}
local sortIndex = 1
local current = nil

local function statusOf(row)
	if row.placedIn then return "In bedroom " .. row.placedIn end
	if row.hotbar then return "Hotbar " .. row.hotbar end
	return "In storage"
end

local function addRow(row, position)
	local tier = Config.TIER_BY_NAME[row.tier]
	local f = Instance.new("Frame") f.Name = row.uid f.LayoutOrder = position f.Size = UDim2.new(1, -12, 0, 72)
	f.BackgroundColor3 = ROW f.Parent = list
	corner(f, 12)
	local star = button("Favorite", f, row.favorited and "★" or "☆", row.favorited and GOLD or SILVER)
	star.Position = UDim2.fromOffset(8, 14) star.Size = UDim2.fromOffset(44, 44)
	star.Activated:Connect(function() favoriteRemote:FireServer(row.uid, not row.favorited) end)
	local nameText = row.kind .. " - " .. row.tier
	local extras = {}
	if row.size and row.size ~= "Normal" then table.insert(extras, row.size) end
	if row.mutation then table.insert(extras, row.mutation) end
	if #extras > 0 then nameText ..= " (" .. table.concat(extras, ", ") .. ")" end
	local top = label("Name", f, nameText, tier and tier.color or Color3.new(1, 1, 1))
	top.Position = UDim2.fromOffset(60, 6) top.Size = UDim2.new(1, -170, 0, 30)
	local bottom = label("Info", f, "👻 " .. Config.short(row.baseFear) .. " / scare, " .. statusOf(row))
	bottom.Position = UDim2.fromOffset(60, 38) bottom.Size = UDim2.new(1, -170, 0, 26)
	if not row.placedIn then
		local hold = button("Hold", f, "Hold", LIME)
		hold.AnchorPoint = Vector2.new(1, 0.5) hold.Position = UDim2.new(1, -8, 0.5, 0) hold.Size = UDim2.fromOffset(92, 48)
		hold.Activated:Connect(function() holdRemote:FireServer(row.uid) end)
	end
end

local function render()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	local rows = current and current.rows or {}
	title.Text = "Inventory " .. #rows .. " / " .. (current and current.capacity or Config.INVENTORY_CAP)
	sortButton.Text = "Sort: " .. SORTS[sortIndex].name
	local less = SORTS[sortIndex].less
	table.sort(rows, function(a, b)
		if less(a, b) then return true end
		if less(b, a) then return false end
		return a.order < b.order
	end)
	for position, row in ipairs(rows) do addRow(row, position) end
end

local function setOpen(open)
	panel.Visible = open
	if open then render() end
end

changedRemote.OnClientEvent:Connect(function(state)
	current = state
	if panel.Visible then render() end
end)

openButton.Activated:Connect(function() setOpen(not panel.Visible) end)
closeButton.Activated:Connect(function() setOpen(false) end)
sortButton.Activated:Connect(function()
	sortIndex = sortIndex % #SORTS + 1
	render()
end)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.I then setOpen(not panel.Visible) end
end)

-- the panel may load after the server's first update
local ok, state = pcall(getRemote.InvokeServer, getRemote)
if ok and state and not current then current = state end
