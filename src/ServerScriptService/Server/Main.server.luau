-- The only server Script: start services (they create remotes and listen for profiles), then load player data
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared"):WaitForChild("Config"))
print("[Config] Balance is valid: " .. Config.statusSummary())
local PlayerData = require(script.Parent.PlayerData)
require(script.Parent.GameService).Start()
PlayerData.Start()
