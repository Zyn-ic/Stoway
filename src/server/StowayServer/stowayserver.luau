-- ServerScriptService/Stoway/StowayServer.lua
local StowayServer = {}
StowayServer.__index = StowayServer

-- Services & Modules
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Types = require(ReplicatedStorage:WaitForChild("Shared").Types)
local TemplateSettings = require(script.Parent.Settings) -- Assuming Settings.lua is in the same folder
local Janitor = require(ReplicatedStorage.Packages.Janitor) -- Verify pathit

-- Remotes
local dropTool = ReplicatedStorage:WaitForChild("Remotes").DropTool :: RemoteEvent
local equipTool = ReplicatedStorage:WaitForChild("Remotes").EquipTool :: RemoteEvent
local unequipTool = ReplicatedStorage:WaitForChild("Remotes").UnEquipTool :: RemoteEvent
local swapSlots = ReplicatedStorage:WaitForChild("Remotes").SwapSlots :: RemoteEvent
local movetoendofback = ReplicatedStorage:WaitForChild("Remotes").MoveToEndofBackpack :: RemoteEvent

local SendStowayToClient = ReplicatedStorage:WaitForChild("Remotes").AskForStoway :: RemoteFunction


local Global_Janitor = Janitor.new() -- for playeradd and playerremoving


--//HelperFuncs\\--
function CreateHotbarValues(self)
    for i=1, self.Settings.HotbarSettings.MaxSlots do
        local hotbarvalue = Instance.new("ObjectValue")
        hotbarvalue.Name = i
        hotbarvalue.Parent = self.HotBarFolder
    end
end

function CheckInventoryWeight(Folder: {ObjectValue}) : number
    if #Folder < 0 then return 0 end
    local weight = 0

    for _,v in Folder do
        if not v.Value then continue end
        weight += v.Value:GetAttribute("Weight") 
    end

    print(weight)
    return weight
end

function IsWeightAtMax(Folder: {ObjectValue}, MaxWeight: number) : boolean
    if #Folder < 0 then return false end
    local weight = 0

    for _, v in Folder do
        if not v.Value then continue end
        weight += v.Value:GetAttribute("Weight") 
    end

    if weight > MaxWeight then return true end
    return false
end

function FindEmptySlot(folder: {ObjectValue}, MaxSlots: number) : ObjectValue?

    for i=1, MaxSlots do
        if not folder[i].Value then
            return folder[i]
        end
    end

    return nil
end

function FindSameSlotType(folder: {ObjectValue}, Tool:Tool) : ObjectValue?
    for i=1, #folder do
        local currentValue = folder[i]
        if currentValue then
            local itemValue = currentValue.Value
            if itemValue then
                local ItemType = Tool:GetAttribute("ItemType")
                local itemTypeAttribute = itemValue:GetAttribute("ItemType")
                if itemTypeAttribute == ItemType and Tool.Name == itemValue.Name then
                    return currentValue
                end
            end
        end
    end
    return nil
end

function Clear(HotBarFolder: {ObjectValue}, BackpackFolder: {ObjectValue})
    for _,v in HotBarFolder do
        v.Value = nil
    end

    for _,v in BackpackFolder do 
        v:Destroy()
    end
end

function ValidateTool(Player:Player, Tool:Tool) : boolean
    if typeof(Tool) ~= "Instance" or not Tool:IsA("Tool") then return false end
    if Tool.Parent ~= Player.Backpack and Tool.Parent ~= Player.Character then return false end
    return true
end

function ValidateSlot(Slot:ObjectValue, self:any) : boolean
    print(Slot:IsA("ObjectValue"), Slot.Name, Slot.Parent)
    if typeof(Slot) ~= "Instance" or not Slot:IsA("ObjectValue") then return false end

    print(self.HotBarFolder, self.BackpackFolder)
    return Slot.Parent == self.HotBarFolder or Slot.Parent == self.BackpackFolder
end

function SendStowayorSettings(player:Player, arg:string) : Types.Stoway | Types.Settings | nil
    if player.Parent == nil or not player then return end
    if typeof(arg) ~= "string" then return nil end

    if arg == "stoway" then
        return StowayServer:GetStoway()
    elseif arg == "settings" then
        return StowayServer:GetSettings()
    end

    return nil
end

--//Setup Function\\--
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

    CreateHotbarValues(self)
    self.InventoryFolder.Parent = Player
    self.PrivateJanitor:Add(self.InventoryFolder)

    --TODO: other stuff
    self:TrackPlayerTools(Player)
    return self
end

--//Core Helper Functions\\--
function StowayServer:getTools(Backpack:Backpack ,character:Model) : {Tool}
    local tools = Backpack:GetChildren()

    if character then 
        local charactertool = character:FindFirstChildWhichIsA("Tool")
        if charactertool then table.insert(tools, charactertool) end
    end

    return tools
end

function StowayServer:FindValueFromTool(Tool:Tool) : ObjectValue?
    for _, ObjectValue:ObjectValue in self.HotBarFolder:GetChildren() do
        if ObjectValue.Value == Tool then return ObjectValue end
    end

    for _, ObjectValue:ObjectValue in self.BackpackFolder:GetChildren() do
        if ObjectValue.Value == Tool then return ObjectValue end
    end

    return nil
end

function StowayServer:AddNewBackpackValue(Tool:Tool)
    local folder = self.HotBarFolder:GetChildren()

    for _,v in self.BackpackFolder:GetChildren() do
        table.insert(folder, v) 
    end

    if IsWeightAtMax(folder, self.Settings.BackpackSettings.Limit) then Tool:Destroy(); return --[[TODO DROP SYSTEM ]] end

    local newbackpackValue = Instance.new("ObjectValue")
    newbackpackValue.Name = #folder + 1
    newbackpackValue.Value = Tool
    newbackpackValue.Parent = self.BackpackFolder
end

function  StowayServer:FindSuitableHotbarSlot(Tool:Tool?) : ObjectValue?
    -- check if there is a slot with the same type AND IS NOT MAX
    if Tool then
        if self.Settings.CanStack then

            local result = FindSameSlotType(self.HotBarFolder:GetChildren(), Tool)
            if result and ((Tool:GetAttribute("Weight") + result.Value:GetAttribute("Weight")) <= self.Settings.MaxStackCount)  then 
                return result 
            end
            
        end
    end

    return FindEmptySlot(self.HotBarFolder:GetChildren(), self.Settings.HotbarSettings.MaxSlots)
end

function StowayServer:ShiftBackpackValuesDown(StartingInventoryValue:ObjectValue)
    local currerntInventoryNum = tonumber(StartingInventoryValue.Name)
    if currerntInventoryNum then currerntInventoryNum += 1 end

    while self.BackpackFolder:FindFirstChild(currerntInventoryNum) do
        self.BackpackFolder[currerntInventoryNum-1].Value = self.BackpackFolder[currerntInventoryNum].Value
        currerntInventoryNum += 1
    end

    self.BackpackFolder[currerntInventoryNum-1]:Destroy()
end

function StowayServer:UpdatePlayerTools(Player:Player)
    local playerTools = self:getTools(Player.Backpack, Player.Character)

    local inventoryvalues = self.BackpackFolder:GetChildren()

    for _, v in self.HotBarFolder:GetChildren() do
        table.insert(inventoryvalues, v)
    end

    for _, value:ObjectValue in inventoryvalues do
        local tool = value.Value 
        if not table.find(playerTools, tool) then
            value.Value = nil
            if value.Parent == self.BackpackFolder then self:ShiftBackpackValuesDown(value) end
        end
    end

    for _, tool:Tool in playerTools do
        if not self:FindValueFromTool(tool) then

            local freehotbarslot = self:FindSuitableHotbarSlot(tool)
            if freehotbarslot then

                if freehotbarslot.Value ~= nil then 
                    local combindedweight = freehotbarslot.Value:GetAttribute("Weight") + tool:GetAttribute("Weight")
                    freehotbarslot.Value:SetAttribute("Weight", combindedweight)
                    tool:Destroy()
                    continue
                end
                freehotbarslot.Value = tool
            else
                self:AddNewBackpackValue(tool)
            end
        end
    end
end

function StowayServer:GetSettings() : Types.Settings
    local settings = {} :: Types.Settings
    settings.BackpackSettings = {}
    settings.HotbarSettings = {}

    settings.BackpackSettings.CarryingType = self.Settings.BackpackSettings.CarryingType
    settings.BackpackSettings.Limit = self.Settings.BackpackSettings.Limit
    settings.BackpackSettings.Sorting = self.Settings.BackpackSettings.Sorting

    settings.HotbarSettings.HotbarType = self.Settings.HotbarSettings.HotbarType
    settings.HotbarSettings.MaxSlots = self.Settings.HotbarSettings.MaxSlots

    settings.CanStack = self.Settings.CanStack
    settings.Droppable = self.Settings.Droppable
    settings.MaxStackCount = self.Settings.MaxStackCount
    settings.RarityCheck = self.Settings.RarityCheck

    return settings 
end

function StowayServer:GetStoway() : Types.Stoway
    local Stoway = {} :: Types.Stoway

    Stoway.BackpackFolder = self.BackpackFolder
    Stoway.HotBarFolder = self.HotBarFolder
    Stoway.InventoryFolder = self.InventoryFolder
    Stoway.PrivateJanitor = nil
    Stoway.Settings = self:GetSettings()

    return Stoway
end

--//Connections Setup Functions\\--
function StowayServer:TrackPlayerTools(Player:Player)

    self.PrivateJanitor:Add(Player.CharacterAdded:Connect(function(char:Model)
        Clear(self.HotBarFolder:GetChildren(), self.BackpackFolder:GetChildren())
        self:UpdatePlayerTools(Player)

        self.PrivateJanitor:Add(Player.Backpack.ChildAdded:Connect(function() self:UpdatePlayerTools(Player) end))
        self.PrivateJanitor:Add(Player.Backpack.ChildRemoved:Connect(function() self:UpdatePlayerTools(Player) end))

        self.PrivateJanitor:Add(char.ChildAdded:Connect(function() self:UpdatePlayerTools(Player) end))
        self.PrivateJanitor:Add(char.ChildRemoved:Connect(function() self:UpdatePlayerTools(Player) end))
    end))
end

function StowayServer.UnEquip(Player:Player)
    local character = Player.Character or Player.CharacterAdded:Wait()
    if not character then return end

    local tool = character:FindFirstChildWhichIsA("Tool")
    if not tool then return end

    tool.Parent = Player.Backpack
end

function StowayServer.EquipTool(Player:Player, Tool:Tool)
    local character = Player.Character or Player.CharacterAdded:Wait()
    if not character then return end
    if not Tool then return end

    StowayServer.UnEquip(Player)
    if not ValidateTool(Player, Tool) then return end
    Tool.Parent = Player.Character
end

function StowayServer:DropTool(Player:Player, Tool:Tool)
    if not ValidateTool(Player, Tool) then return end
    local slot = self:FindValueFromTool(Tool)
    if not slot then return end

    local character = Player.Character or Player.CharacterAdded:Wait()
    local root = character.PrimaryPart; local rootCframe = root.CFrame;
    local positionOffset = (rootCframe.LookVector * Vector3.new(1,0,1)) * self.Settings.DropToolDistance
    local ToolCframe = rootCframe + positionOffset
    local handle = Tool:FindFirstChild("Handle") or Tool.PrimaryPart
    if handle then handle.CFrame = ToolCframe end
    Tool.Parent = workspace
end

function StowayServer:SwapSlots(Slot1:ObjectValue, Slot2:ObjectValue)
    if not ValidateSlot(Slot1, self) or not ValidateSlot(Slot2, self) then print(typeof(Slot1), typeof(Slot2)) return end
    if Slot1 == Slot2 then print("same item") return end

    print(Slot1.Name, Slot2.Name)

    --swapping slots
    local oldslot1 = Slot1.Value
    Slot1.Value = Slot2.Value
    Slot2.Value = oldslot1

    if Slot1.Parent == self.BackpackFolder and not Slot1.Value then
        self:ShiftBackpackValuesDown(Slot1)
    elseif Slot2.Parent == self.BackpackFolder and not Slot2.Value then
        self:ShiftBackpackValuesDown(Slot2)
    end
end

function StowayServer:MoveToEndofBackpack(Slot:ObjectValue)
    if not ValidateSlot(Slot, self) then return end
    if not Slot.Value then return end
    self:AddNewBackpackValue(Slot.Value)
    Slot.Value = nil

    if Slot.Parent == self.BackpackFolder then
        self:ShiftBackpackValuesDown(Slot)
    end
end



--//Clean Function\\--
function StowayServer:Clean()
    self["PrivateJanitor"]:Destroy()
    self.PrivateJanitor = nil
    self = nil
end

--//Connections\\--

SendStowayToClient.OnServerInvoke = SendStowayorSettings

Global_Janitor:Add(Players.PlayerAdded:Connect(StowayServer.new))
Global_Janitor:Add(Players.PlayerRemoving:Connect(function() StowayServer:Clean() end))
Global_Janitor:Add(equipTool.OnServerEvent:Connect(StowayServer.EquipTool))
Global_Janitor:Add(unequipTool.OnServerEvent:Connect(StowayServer.UnEquip))
Global_Janitor:Add(dropTool.OnServerEvent:Connect(function(Player, Tool) StowayServer:DropTool(Player, Tool) end))
Global_Janitor:Add(swapSlots.OnServerEvent:Connect(function(plr, slot1, slot2) StowayServer:SwapSlots(slot1, slot2) end))
Global_Janitor:Add(movetoendofback.OnServerEvent:Connect(function(plr, slot) StowayServer:MoveToEndofBackpack(slot) end))

Global_Janitor:Add(function()
    if SendStowayToClient then
        SendStowayToClient.OnServerInvoke = nil
    end
end)

game:BindToClose(function() Global_Janitor:Destroy(); Global_Janitor = nil; end)
return StowayServer