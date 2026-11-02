-- The shop's panel and countdown. It shows what the server sends and asks to buy; the server decides everything else.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Sounds = require(Shared:WaitForChild("Sounds"))

local player = Players.LocalPlayer
local getRemote = Net.Function("GetShop")
local buyRemote = Net.Function("BuyShopItem")
local changedRemote = Net.Event("ShopChanged")

local PANEL = Color3.fromRGB(60, 40, 110)
local ROW = Color3.fromRGB(85, 60, 145)
local LIME = Color3.fromRGB(60, 200, 90)
local SILVER = Color3.fromRGB(150, 150, 165)
local GOLD = Color3.fromRGB(255, 200, 40)

local gui = Instance.new("ScreenGui") gui.Name = "ShopPanel" gui.ResetOnSpawn = false gui.DisplayOrder = 2
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(obj, r) Instance.new("UICorner", obj).CornerRadius = UDim.new(0, r) end
local function label(name, parent, text, color)
	local t = Instance.new("TextLabel") t.Name = name t.BackgroundTransparency = 1 t.Font = Enum.Font.FredokaOne t.TextScaled = true
	t.TextColor3 = color or Color3.new(1, 1, 1) t.Text = text t.TextXAlignment = Enum.TextXAlignment.Left t.Parent = parent
	return t
end
local function button(name, parent, text, color)
	local b = Instance.new("TextButton") b.Name = name b.BackgroundColor3 = color b.Font = Enum.Font.FredokaOne b.TextScaled = true
	b.TextColor3 = Color3.new(1, 1, 1) b.Text = text b.Parent = parent
	corner(b, 10)
	return b
end

local panel = Instance.new("Frame") panel.Name = "Panel" panel.Visible = false panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.55) panel.Size = UDim2.fromScale(0.92, 0.76) panel.BackgroundColor3 = PANEL panel.Parent = gui
corner(panel, 18)
local cap = Instance.new("UISizeConstraint") cap.MaxSize = Vector2.new(640, 540) cap.Parent = panel
local title = label("Title", panel, "Shop", Color3.new(1, 1, 1))
title.Position = UDim2.fromOffset(16, 10) title.Size = UDim2.new(1, -90, 0, 34)
local closeButton = button("Close", panel, "X", SILVER)
closeButton.AnchorPoint = Vector2.new(1, 0) closeButton.Position = UDim2.new(1, -10, 0, 8) closeButton.Size = UDim2.fromOffset(44, 44)
local message = label("Message", panel, "Your stock: everyone has their own, so nobody can buy yours", Color3.fromRGB(235, 235, 245))
message.Position = UDim2.fromOffset(16, 52) message.Size = UDim2.new(1, -32, 0, 26)
local list = Instance.new("ScrollingFrame") list.Name = "List" list.Position = UDim2.fromOffset(12, 84) list.Size = UDim2.new(1, -24, 1, -96)
list.BackgroundTransparency = 1 list.BorderSizePixel = 0 list.ScrollBarThickness = 8 list.CanvasSize = UDim2.new() list.AutomaticCanvasSize = Enum.AutomaticSize.Y list.Parent = panel
local layout = Instance.new("UIListLayout") layout.Padding = UDim.new(0, 6) layout.SortOrder = Enum.SortOrder.LayoutOrder layout.Parent = list

local current = nil
local busy = false

local REASONS = {
	stale = "The shop just changed, have a look at the new stock",
	unavailable = "That isn't on sale right now",
	soldOut = "You've bought all of your stock of that",
	poor = "You don't have enough Fear",
	far = "Come back to the shop to buy",
}

local function spaced(id)
	return (string.gsub(id, "(%l)(%u)", "%1 %2"))
end

local function contents(offer)
	if offer.kind == "tracker" then return "Leads you to a secret egg you can dig up. Rare!" end
	local parts = {}
	for _, item in ipairs(Config.BOX_ITEMS[offer.id] or {}) do
		table.insert(parts, string.format("%s %.1f%% x%s", spaced(item.id), item.weight, tostring(item.mult)))
	end
	return table.concat(parts, ", ")
end

local function render()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	if not current then return end
	for position, offer in ipairs(current.offers) do
		local f = Instance.new("Frame") f.Name = offer.id f.LayoutOrder = position f.Size = UDim2.new(1, -12, 0, 104) f.BackgroundColor3 = ROW f.Parent = list
		corner(f, 12)
		local top = label("Name", f, spaced(offer.id) .. " - " .. Config.short(offer.price) .. " Fear", GOLD)
		top.Position = UDim2.fromOffset(12, 6) top.Size = UDim2.new(1, -130, 0, 28)
		local info = label("Info", f, contents(offer))
		info.Position = UDim2.fromOffset(12, 36) info.Size = UDim2.new(1, -130, 0, 40) info.TextWrapped = true
		local stock = label("Stock", f, "Your stock: " .. offer.left .. " of " .. offer.stock, if offer.left > 0 then Color3.new(1, 1, 1) else SILVER)
		stock.Position = UDim2.fromOffset(12, 78) stock.Size = UDim2.new(1, -130, 0, 20)
		local buy = button("Buy", f, if offer.left > 0 then "Buy" else "Sold out", if offer.left > 0 then LIME else SILVER)
		buy.AnchorPoint = Vector2.new(1, 0.5) buy.Position = UDim2.new(1, -8, 0.5, 0) buy.Size = UDim2.fromOffset(104, 60)
		buy.Activated:Connect(function()
			if busy or offer.left <= 0 then return end -- no second request until the first answers
			busy = true
			local ok, success, why, state = pcall(buyRemote.InvokeServer, buyRemote, offer.id, current.rotation)
			busy = false
			if not ok then
				message.Text = "That didn't go through, try again"
				return
			end
			if state then current = state end
			if success then Sounds.play("buy") end
			message.Text = if success then "Bought! Find it in your Inventory, under Items." else (REASONS[why] or "That didn't go through")
			render()
		end)
	end
end

local function refresh()
	local ok, state = pcall(getRemote.InvokeServer, getRemote)
	if ok and state then
		current = state
		if panel.Visible then render() end
	end
end

changedRemote.OnClientEvent:Connect(function()
	refresh()
	if panel.Visible then message.Text = "New stock is in!" end
end)

closeButton.Activated:Connect(function() panel.Visible = false end)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ShopPrompt" then
		refresh()
		panel.Visible = true
		render()
	end
end)

-- the countdown, in the panel and on the stall's own sign, from the server's clock
task.spawn(function()
	refresh()
	while true do
		task.wait(1)
		if current then
			local left = math.max(0, current.endsAt - workspace:GetServerTimeNow())
			local clock = string.format("%d:%02d", math.floor(left / 60), math.floor(left % 60))
			title.Text = "Shop - new stock in " .. clock
			local hub = workspace:FindFirstChild("Hub")
			local sign = hub and hub:FindFirstChild("ShopSign")
			local surface = sign and sign:FindFirstChildWhichIsA("SurfaceGui")
			if surface then surface.Text.Text = "Shop - new stock " .. clock end
		end
	end
end)
