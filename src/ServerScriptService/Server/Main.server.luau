-- The only server Script: start services (they create remotes and listen for profiles), then load player data
local PlayerData = require(script.Parent.PlayerData)
require(script.Parent.GameService).Start()
PlayerData.Start()
