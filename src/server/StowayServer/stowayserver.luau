-- ServerScriptService/Stoway/StowayServer.lua
local StowayServer = {}
StowayServer.__index = StowayServer

-- Services & Modules
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")

local Types = require(ReplicatedStorage:WaitForChild("Shared").Types)
local TemplateSettings = require(script.Parent.Settings) -- Assuming Settings.lua is in the same folder
local Janitor = require(ReplicatedStorage.Packages.janitor) -- Verify path

local Global_Janitor = Janitor.new() -- for playeradd and playerremoving

--//StartUP\\--
function StowayServer.new(Player:Player) 
    local self = setmetatable(StowayServer, {})

    self.PrivateJanitor = Janitor.new()

    self.Settings = TemplateSettings
    self.HotbarName = "Hotbar"
    self.BackpackName = "Backpack"
    self.InventoryName = "Inventory"

    self.InventoryFolder = Instance.new("Folder")
    self.InventoryFolder.Name = self.InventoryName

    self.HotBarFolder = Instance.new("Folder")
    self.HotBarFolder.Name = self.HotbarName
    self.HotBarFolder.Parent = self.InventoryFolder

    self.BackpackFolder = Instance.new("Folder")
    self.BackpackFolder.Name = self.BackpackName
    self.BackpackFolder.Parent = self.InventoryFolder

    for i=1, self.Settings.HotbarSettings.MaxSlots do
        local hotbarvalue = Instance.new("ObjectValue")
        hotbarvalue.Name = i
        hotbarvalue.Parent = self.HotBarFolder
    end

    self.InventoryFolder.Parent = Player

    self.PrivateJanitor:Add(self.InventoryFolder)
    return self
end

function StowayServer:Clean(Player:Player)
    print(self.BackpackFolder.Name)
    self["PrivateJanitor"]:Destroy()
    self.PrivateJanitor = nil

    Global_Janitor:Destroy()
    Global_Janitor = nil
end

Global_Janitor:Add(Players.PlayerAdded:Connect(StowayServer.new))
Global_Janitor:Add(Players.PlayerRemoving:Connect(function(plr) StowayServer:Clean(plr) end))
return StowayServer