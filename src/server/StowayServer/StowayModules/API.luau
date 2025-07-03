local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- src/server/StowayServer/stowayserver_modules/API.lua
local API = {}

-- Dependencies
local PlayerStoways
local Types = require(ReplicatedStorage.Shared.Types)

function API.GetSettings(Player:Player) : Types.Settings
	local PlayerStowy = PlayerStoways[Player]
	local settings = {}
	settings.BackpackSettings = {}
	settings.HotbarSettings = {}

	settings.BackpackSettings.CarryingType = PlayerStowy.Settings.BackpackSettings.CarryingType
	settings.BackpackSettings.Limit = PlayerStowy.Settings.BackpackSettings.Limit
	settings.BackpackSettings.Sorting = PlayerStowy.Settings.BackpackSettings.Sorting
	settings.HotbarSettings.HotbarType = PlayerStowy.Settings.HotbarSettings.HotbarType
	settings.HotbarSettings.MaxSlots = PlayerStowy.Settings.HotbarSettings.MaxSlots
	settings.CanStack = PlayerStowy.Settings.CanStack
	settings.Droppable = PlayerStowy.Settings.Droppable
	settings.MaxStackCount = PlayerStowy.Settings.MaxStackCount
	settings.RarityCheck = PlayerStowy.Settings.RarityCheck

	return settings
end

function API.GetStoway(Player:Player) : Types.Stoway
	local PlayerStowy = PlayerStoways[Player]
	local Stoway = {}

	Stoway.BackpackFolder = PlayerStowy.BackpackFolder
	Stoway.HotBarFolder = PlayerStowy.HotBarFolder
	Stoway.InventoryFolder = PlayerStowy.InventoryFolder
	Stoway.PrivateJanitor = nil
	Stoway.Settings = API.GetSettings(Player)

	return Stoway
end

function API:Init(context: Types.Context)
	PlayerStoways = context.PlayerStoways
end

return API