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


--//StartUP\\--
function StowayServer.Init(Player:Player) 
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

    self.InventoryFolder.Parent = Player

    self.PrivateJanitor:Add(self)
    return self
end
