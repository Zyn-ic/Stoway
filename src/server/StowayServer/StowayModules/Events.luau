-- src/server/StowayServer/stowayserver_modules/Events.lua
local Events = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

-- Dependencies
local PlayerStoways
local Settings
local Janitor
local Actions

function Events.OnPlayerAdded(Player:Player)
	local PlayerStowy = {}
	PlayerStowy.PrivateJanitor = Janitor.new()
	PlayerStoways[Player] = PlayerStowy

	PlayerStowy.Settings = Settings

	PlayerStowy.InventoryFolder = Instance.new("Folder"); 
	PlayerStowy.InventoryFolder.Parent = Player;
	PlayerStowy.InventoryFolder.Name = "Inventory"
	PlayerStowy.InventoryFolder:SetAttribute("TotalWeight", 0)

	PlayerStowy.HotBarFolder = Instance.new("Folder"); 
	PlayerStowy.HotBarFolder.Parent = PlayerStowy.InventoryFolder
	PlayerStowy.HotBarFolder.Name = "Hotbar"

	PlayerStowy.BackpackFolder = Instance.new("Folder"); 
	PlayerStowy.BackpackFolder.Parent = PlayerStowy.InventoryFolder;
	PlayerStowy.BackpackFolder.Name = "Backpack"

	Actions.CreateHotbarValues(PlayerStowy)
	
	PlayerStowy.PrivateJanitor:Add(PlayerStowy.InventoryFolder)
	PlayerStowy.PrivateJanitor:Add(function() PlayerStoways[Player] = nil end)

	Events.TrackPlayerTools(Player)
end

function Events.OnPlayerRemoving(Player:Player)
    if PlayerStoways[Player] then
        PlayerStoways[Player].PrivateJanitor:Destroy()
    end
end

function Events.TrackPlayerTools(Player:Player)
	local PlayerStowy = PlayerStoways[Player]
	local janitor = PlayerStowy.PrivateJanitor

	janitor:Add(Player.CharacterAdded:Connect(function(char)
		Actions.Clear(PlayerStowy)
		Actions.UpdatePlayerTools(Player)

		janitor:Add(Player.Backpack.ChildAdded:Connect(function() Actions.UpdatePlayerTools(Player) end))
		janitor:Add(Player.Backpack.ChildRemoved:Connect(function() Actions.UpdatePlayerTools(Player) end))
		janitor:Add(char.ChildAdded:Connect(function() Actions.UpdatePlayerTools(Player) end))
		janitor:Add(char.ChildRemoved:Connect(function() Actions.UpdatePlayerTools(Player) end))
	end))
end

function Events:Init(context:Types.Context)
	PlayerStoways = context.PlayerStoways
	Settings = context.Settings
	Janitor = context.Janitor 
	Actions = context.Actions
end

return Events