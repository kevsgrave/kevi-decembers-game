-- The fusing cauldron's panel: which monsters can fuse, exactly which ones would be used, what comes out, and a confirm step.
-- It only names the monsters; the server checks everything again and makes the new one.
local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared:WaitForChild("Config"))
local Net = require(Shared:WaitForChild("Net"))
local Panels = require(Shared:WaitForChild("Panels"))
local Style = require(Shared:WaitForChild("Style"))

local player = Players.LocalPlayer
local getRemote = Net.Function("GetInventory")
local changedRemote = Net.Event("InventoryChanged")
local fuseRemote = Net.Function("FuseMonsters")

local LIME, GOLD = Style.GREEN, Style.GOLD
local label, button = Style.label, Style.button

local gui = Instance.new("ScreenGui") gui.Name = "ForgePanel" gui.ResetOnSpawn = false gui.DisplayOrder = 2
gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
gui.Parent = player:WaitForChild("PlayerGui")

local panel, _, closeButton = Style.panel(gui, "Panel", "🔥 Fusion Forge", Style.PURPLE)
local message = label("Message", panel, "Fuse matching monsters into a bigger one. Placed and favorited monsters are never used.", Color3.fromRGB(235, 235, 245))
message.Position = UDim2.fromOffset(16, 60) message.Size = UDim2.new(1, -32, 0, 40)
local list = Style.list(panel, 106)

local sizeMult, recipeFrom = {}, {}
for _, s in ipairs(Config.Balance.fusion.sizes) do sizeMult[s.id] = s.mult end
for _, r in ipairs(Config.Balance.fusion.recipes) do recipeFrom[r.from] = r end

local REASONS = {
	different = "Those don't match",
	favorite = "A favorited monster is protected",
	placed = "Pick up placed monsters first",
	missing = "Those monsters have changed, have another look",
	count = "That's the wrong number of monsters",
	maxSize = "That's already the biggest size",
}

local current = nil
local confirming = nil -- the group waiting for a second press
local busy = false

local function render()
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
	end
	-- group what could be used: not placed, not favorited, and a size that can still grow
	local groups, order = {}, {}
	for _, row in ipairs(current and current.rows or {}) do
		if not row.placedIn and not row.favorited and recipeFrom[row.size] then
			local key = table.concat({row.kind, row.tier, row.size, row.mutation or ""}, "|")
			if not groups[key] then
				groups[key] = {key = key, kind = row.kind, tier = row.tier, size = row.size, mutation = row.mutation, rows = {}}
				table.insert(order, key)
			end
			table.insert(groups[key].rows, row)
		end
	end
	table.sort(order)
	local position = 0
	for _, key in ipairs(order) do
		local g = groups[key]
		local recipe = recipeFrom[g.size]
		table.sort(g.rows, function(a, b) return a.baseFear > b.baseFear end) -- uses the strongest, so the new one pays the most
		position += 1
		local ready = #g.rows >= recipe.count
		local tier = Config.TIER_BY_NAME[g.tier]
		local f = Style.card(key, list, if ready then position else position + 1000, 118, tier and tier.color)
		local name = g.size .. " " .. g.kind .. " - " .. g.tier .. (if g.mutation then " (" .. g.mutation .. ")" else "")
		local top = label("Name", f, name .. ": " .. #g.rows .. " of " .. recipe.count, tier and tier.color)
		top.Position = UDim2.fromOffset(12, 6) top.Size = UDim2.new(1, -130, 0, 28)
		local detail
		if ready then
			local uses = {}
			for i = 1, recipe.count do table.insert(uses, Config.short(g.rows[i].baseFear)) end
			local mult = sizeMult[recipe.id] or 1
			detail = "Uses: " .. table.concat(uses, ", ") .. " Fear per scare. Makes 1 " .. recipe.id .. ": " .. Config.short(g.rows[1].baseFear) .. " base, x" .. mult .. " size"
		else
			detail = "You need " .. recipe.count - #g.rows .. " more to make a " .. recipe.id
		end
		local info = label("Info", f, detail)
		info.Position = UDim2.fromOffset(12, 38) info.Size = UDim2.new(1, -130, 0, 72)
		if ready then
			local isConfirming = confirming == key
			local action = button("Fuse", f, if isConfirming then "Confirm" else "Fuse", if isConfirming then GOLD else LIME)
			action.AnchorPoint = Vector2.new(1, 0.5) action.Position = UDim2.new(1, -8, 0.5, 0) action.Size = UDim2.fromOffset(104, 60)
			action.Activated:Connect(function()
				if busy then return end
				if confirming ~= key then
					confirming = key
					render()
					return
				end
				local uids = {}
				for i = 1, recipe.count do table.insert(uids, g.rows[i].uid) end
				busy = true
				local ok, success, why = pcall(fuseRemote.InvokeServer, fuseRemote, uids)
				busy = false
				confirming = nil
				message.Text = if ok and success then "Fused! You made a " .. recipe.id .. " " .. g.kind .. "." else ((ok and REASONS[why]) or "That didn't go through, nothing was used")
			end)
		end
	end
	if position == 0 then
		local f = Style.card("Empty", list, 1, 60)
		local t = label("Text", f, "Nothing to fuse yet. Hatch more eggs!")
		t.Position = UDim2.fromOffset(12, 12) t.Size = UDim2.new(1, -24, 0, 36)
	end
end

changedRemote.OnClientEvent:Connect(function(state)
	current = state
	if panel.Visible then render() end
end)
closeButton.Activated:Connect(function()
	panel.Visible = false
	confirming = nil
end)
Panels.register("Forge", function()
	local ok, state = pcall(getRemote.InvokeServer, getRemote)
	if ok and state then current = state end
	confirming = nil
	panel.Visible = true
	render()
end, panel)
ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "FusePrompt" then Panels.open("Forge") end
end)
