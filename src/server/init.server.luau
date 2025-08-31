-- ServerScriptService/Stoway/StowayServer.lua
--local StowayServer = {}

-- Services & Modules
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Settings = require(script.StowayServer.Settings)
local API = require(script.StowayServer.StowayModules.API)
local Actions = require(script.StowayServer.StowayModules.Actions)
local Events = require(script.StowayServer.StowayModules.Events)
local Remotes = require(script.StowayServer.StowayModules.Remotes)
local Utils = require(script.StowayServer.StowayModules.Utils)
local Types = require(ReplicatedStorage:WaitForChild("Shared").Types)

local Janitor = require(ReplicatedStorage.Packages.Janitor) -- Verify pathit

-- Remotes
local dropTool = ReplicatedStorage:WaitForChild("Remotes").DropTool :: RemoteEvent
local equipTool = ReplicatedStorage:WaitForChild("Remotes").EquipTool :: RemoteEvent
local unequipTool = ReplicatedStorage:WaitForChild("Remotes").UnEquipTool :: RemoteEvent
local swapSlots = ReplicatedStorage:WaitForChild("Remotes").SwapSlots :: RemoteEvent
local movetoendofback = ReplicatedStorage:WaitForChild("Remotes").MoveToEndofBackpack :: RemoteEvent

local SendStowayToClient = ReplicatedStorage:WaitForChild("Remotes").AskForStoway :: RemoteFunction

local Global_Janitor = Janitor.new() -- for playeradd and playerremoving

local PlayerStoways = {} :: {[Player]: Types.Stoway}

local context:Types.Context = {
PlayerStoways = PlayerStoways,
Janitor = Janitor,
API = API,
Actions = Actions,
Utils = Utils,
Remotes = Remotes,
Settings = Settings
} 

Events.Init(context)
API.Init(context)
Actions.Init(context)
Utils.Init(context)
Remotes.Init(context)


--//Clean Function\\--
function Clean()
    for _,v in PlayerStoways do
        v.PrivateJanitor:Destroy()
    end

    table.clear(PlayerStoways)
    Global_Janitor:Destroy()
    Global_Janitor = nil
end

SendStowayToClient.OnServerInvoke = API.SendStowayorSettings

Global_Janitor:Add(Players.PlayerAdded:Connect(Events.OnPlayerAdded))
Global_Janitor:Add(Players.PlayerRemoving:Connect(function(Player) PlayerStoways[Player].PrivateJanitor:Destroy() end))
Global_Janitor:Add(equipTool.OnServerEvent:Connect(Remotes.OnEquipTool))
Global_Janitor:Add(unequipTool.OnServerEvent:Connect(Remotes.OnUnEquip))
Global_Janitor:Add(dropTool.OnServerEvent:Connect(function(Player, Tool) Remotes.OnDropTool(Player, Tool) end))
Global_Janitor:Add(swapSlots.OnServerEvent:Connect(function(plr, slot1, slot2, stack) Actions.SwapSlots(plr, slot1, slot2, stack) end))
Global_Janitor:Add(movetoendofback.OnServerEvent:Connect(function(plr, slot) Actions.MoveToEndofBackpack(slot, plr) end))

Global_Janitor:Add(function()
    if SendStowayToClient then
        SendStowayToClient.OnServerInvoke = nil
    end
end)

game:BindToClose(Clean)