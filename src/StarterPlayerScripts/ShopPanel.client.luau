-- The shop's panel and countdown. It shows what the server sends and asks to buy; the server decides everything else.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Panels = require(Shared:WaitForChild("Panels"))
local Style = require(Shared:WaitForChild("Style"))
local Sounds = require(Shared:WaitForChild("Sounds"))

local player = Players.LocalPlayer
local getRemote = Net.Function("GetShop")
local buyRemote = Net.Function("BuyShopItem")
local changedRemote = Net.Event("ShopChanged")

local LIME, SILVER, GOLD = Style.GREEN, Style.GRAY, Style.GOLD
local label, button = Style.label, Style.button

local gui = Instance.new("ScreenGui") gui.Name = "ShopPanel" gui.ResetOnSpawn = false gui.DisplayOrder = 2
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local panel, title, closeButton = Style.panel(gui, "Panel", "🛒 Shop", Style.GREEN)
local message = label("Message", panel, "-- YOUR STOCK --", GOLD)
message.Position = UDim2.fromOffset(16, 60) message.Size = UDim2.new(1, -32, 0, 30) message.TextXAlignment = Enum.TextXAlignment.Center
local list = Style.list(panel, 94)

local current = nil
local busy = false

local REASONS = {
	stale = "The shop just changed, have a look at the new stock",
	unavailable = "That isn't on sale right now",
	soldOut = "You've bought all of your stock of that",
	poor = "You don't have enough Fear",
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
		local edge = if offer.kind == "tracker" then Style.CYAN elseif offer.id == "SecretBox" then Style.PINK elseif offer.id == "LegendaryBox" then Style.GOLD elseif offer.id == "EpicBox" then Style.PURPLE else Style.ORANGE
		local f = Style.card(offer.id, list, position, 112, edge)
		local top = label("Name", f, spaced(offer.id) .. " - " .. Config.short(offer.price) .. " Fear", GOLD)
		top.Position = UDim2.fromOffset(12, 6) top.Size = UDim2.new(1, -130, 0, 28)
		local info = label("Info", f, contents(offer))
		info.Position = UDim2.fromOffset(12, 36) info.Size = UDim2.new(1, -130, 0, 46) info.TextWrapped = true
		-- short descriptions would otherwise scale up larger than long ones
		local cap = Instance.new("UITextSizeConstraint") cap.MaxTextSize = 20 cap.Parent = info
		local stock = label("Stock", f, "Your stock: " .. offer.left .. " of " .. offer.stock, if offer.left > 0 then Color3.new(1, 1, 1) else SILVER)
		stock.Position = UDim2.fromOffset(12, 84) stock.Size = UDim2.new(1, -130, 0, 22)
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
Panels.register("Shop", function()
	refresh()
	panel.Visible = true
	render()
end, panel)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ShopPrompt" or prompt.Name == "TrackerPrompt" then Panels.open("Shop") end
end)

-- the countdown, in the panel and on the stall's own sign, from the server's clock
task.spawn(function()
	refresh()
	while true do
		task.wait(1)
		if current then
			local left = math.max(0, current.endsAt - workspace:GetServerTimeNow())
			local clock = string.format("%d:%02d", math.floor(left / 60), math.floor(left % 60))
			title.Text = "🛒 Shop - new stock in " .. clock
			local hub = workspace:FindFirstChild("Hub")
			local sign = hub and hub:FindFirstChild("ShopSign")
			local surface = sign and sign:FindFirstChildWhichIsA("SurfaceGui")
			if surface then surface.Text.Text = "Shop " .. clock end
		end
	end
end)
