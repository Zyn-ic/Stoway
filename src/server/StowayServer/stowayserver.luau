-- ServerScriptService/Stoway/StowayServer.lua
local StowayServer = {}

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

local PlayerStoways = {} :: {Player: Types.Stoway}


--//HelperFuncs\\--
function CreateHotbarValues(self: Types.Stoway)
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
    if typeof(Slot) ~= "Instance" or not Slot:IsA("ObjectValue") then return false end

    return Slot.Parent == self.HotBarFolder or Slot.Parent == self.BackpackFolder
end

function SendStowayorSettings(player:Player, arg:string) : Types.Stoway | Types.Settings | nil
    if player.Parent == nil or not player then return end
    if typeof(arg) ~= "string" then return nil end

    if arg == "stoway" then
        return StowayServer:GetStoway(player)
    elseif arg == "settings" then
        return StowayServer:GetSettings(player)
    end

    return nil
end

--//Setup Function\\--
function StowayServer.new(Player:Player) 
    local self = {} :: Types.Stoway

    local HotbarName = "Hotbar"
    local BackpackName = "Backpack"
    local InventoryName = "Inventory"

    self.PrivateJanitor = Janitor.new()

    self.Settings = TemplateSettings
    
    self.InventoryFolder = Instance.new("Folder")
    self.InventoryFolder.Name = InventoryName

    self.HotBarFolder = Instance.new("Folder")
    self.HotBarFolder.Name = HotbarName
    self.HotBarFolder.Parent = self.InventoryFolder

    self.BackpackFolder = Instance.new("Folder")
    self.BackpackFolder.Name = BackpackName
    self.BackpackFolder.Parent = self.InventoryFolder

    CreateHotbarValues(self)
    self.InventoryFolder.Parent = Player
    self.PrivateJanitor:Add(self.InventoryFolder)
    self.PrivateJanitor:Add(function() PlayerStoways[Player] = nil; end)
    PlayerStoways[Player] = self
    

    --TODO: other stuff
    StowayServer:TrackPlayerTools(Player)
end

--//Core Helper Functions\\--
function StowayServer:getTools(Backpack:Backpack, character:Model) : {Tool}
    local tools = Backpack:GetChildren()

    if character then 
        local charactertool = character:FindFirstChildWhichIsA("Tool")
        if charactertool then table.insert(tools, charactertool) end
    end

    return tools
end

function StowayServer:FindValueFromTool(Tool:Tool, Player:Player) : ObjectValue?
    local PlayerStowy = PlayerStoways[Player]
    for _, ObjectValue:ObjectValue in PlayerStowy.HotBarFolder:GetChildren() do
        if ObjectValue.Value == Tool then return ObjectValue end
    end

    for _, ObjectValue:ObjectValue in PlayerStowy.BackpackFolder:GetChildren() do
        if ObjectValue.Value == Tool then return ObjectValue end
    end

    return nil
end

function StowayServer:AddNewBackpackValue(Tool:Tool, Player:Player)
    local PlayerStowy = PlayerStoways[Player]
    local folder = PlayerStowy.HotBarFolder:GetChildren()

    for _,v in PlayerStowy.BackpackFolder:GetChildren() do
        table.insert(folder, v) 
    end

    if IsWeightAtMax(folder, PlayerStowy.Settings.BackpackSettings.Limit) then Tool:Destroy(); return --[[TODO DROP SYSTEM ]] end

    local newbackpackValue = Instance.new("ObjectValue")
    newbackpackValue.Name = #folder + 1
    newbackpackValue.Value = Tool
    newbackpackValue.Parent = PlayerStowy.BackpackFolder
end

function  StowayServer:FindSuitableHotbarSlot(Tool:Tool?, Player:Player) : ObjectValue?
    -- check if there is a slot with the same type AND IS NOT MAX
    local PlayerStowy = PlayerStoways[Player]
    if Tool then
        if PlayerStowy.Settings.CanStack then

            local result = FindSameSlotType(PlayerStowy.HotBarFolder:GetChildren(), Tool)
            if result and ((Tool:GetAttribute("Weight") + result.Value:GetAttribute("Weight")) <= PlayerStowy.Settings.MaxStackCount)  then 
                return result 
            end
            
        end
    end

    return FindEmptySlot(PlayerStowy.HotBarFolder:GetChildren(), PlayerStowy.Settings.HotbarSettings.MaxSlots)
end

function StowayServer:ShiftBackpackValuesDown(StartingInventoryValue:ObjectValue, Player:Player)
    local PlayerStowy = PlayerStoways[Player]
    local currerntInventoryNum = tonumber(StartingInventoryValue.Name)
    if currerntInventoryNum then currerntInventoryNum += 1 end

    while PlayerStowy.BackpackFolder:FindFirstChild(currerntInventoryNum) do
        PlayerStowy.BackpackFolder[currerntInventoryNum-1].Value = PlayerStowy.BackpackFolder[currerntInventoryNum].Value
        currerntInventoryNum += 1
    end

    PlayerStowy.BackpackFolder[currerntInventoryNum-1]:Destroy()
end

function StowayServer:UpdatePlayerTools(Player:Player)
    local PlayerStowy = PlayerStoways[Player]
    local char = Player.Character
    local playerTools = StowayServer:getTools(Player.Backpack, char)

    local inventoryvalues = PlayerStowy.BackpackFolder:GetChildren()

    for _, v in PlayerStowy.HotBarFolder:GetChildren() do
        table.insert(inventoryvalues, v)
    end

    for _, value:ObjectValue in inventoryvalues do
        local tool = value.Value 
        if not table.find(playerTools, tool) then
            value.Value = nil
            if value.Parent == PlayerStowy.BackpackFolder then StowayServer:ShiftBackpackValuesDown(value, Player) end
        end
    end

    for _, tool:Tool in playerTools do
        if not StowayServer:FindValueFromTool(tool, Player) then

            local freehotbarslot = StowayServer:FindSuitableHotbarSlot(tool, Player)
            if freehotbarslot then

                if freehotbarslot.Value ~= nil then 
                    local combindedweight = freehotbarslot.Value:GetAttribute("Weight") + tool:GetAttribute("Weight")
                    freehotbarslot.Value:SetAttribute("Weight", combindedweight)
                    tool:Destroy()
                    continue
                end
                freehotbarslot.Value = tool
            else
                StowayServer:AddNewBackpackValue(tool, Player)
            end
        end
    end
end

function StowayServer:GetSettings(Player:Player) : Types.Settings
    local PlayerStowy = PlayerStoways[Player]
    local settings = {} :: Types.Settings
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

function StowayServer:GetStoway(Player:Player) : Types.Stoway
    local PlayerStowy = PlayerStoways[Player]
    local Stoway = {} :: Types.Stoway

    Stoway.BackpackFolder = PlayerStowy.BackpackFolder
    Stoway.HotBarFolder = PlayerStowy.HotBarFolder
    Stoway.InventoryFolder = PlayerStowy.InventoryFolder
    Stoway.PrivateJanitor = nil
    Stoway.Settings = StowayServer:GetSettings(Player)

    return Stoway
end

function StowayServer:TrackPlayerTools(Player:Player)
    local PlayerStowy = PlayerStoways[Player]

    PlayerStowy.PrivateJanitor:Add(Player.CharacterAdded:Connect(function(char:Model)
        Clear(PlayerStowy.HotBarFolder:GetChildren(), PlayerStowy.BackpackFolder:GetChildren())
        StowayServer:UpdatePlayerTools(Player)

        PlayerStowy.PrivateJanitor:Add(Player.Backpack.ChildAdded:Connect(function() StowayServer:UpdatePlayerTools(Player) end))
        PlayerStowy.PrivateJanitor:Add(Player.Backpack.ChildRemoved:Connect(function() StowayServer:UpdatePlayerTools(Player) end))

        PlayerStowy.PrivateJanitor:Add(char.ChildAdded:Connect(function() StowayServer:UpdatePlayerTools(Player) end))
        PlayerStowy.PrivateJanitor:Add(char.ChildRemoved:Connect(function() StowayServer:UpdatePlayerTools(Player) end))
    end))
end

--//Connections Setup Functions\\--
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
    local slot = StowayServer:FindValueFromTool(Tool, Player)
    if not slot then return end

    local PlayerStowy = PlayerStoways[Player]
    local character = Player.Character or Player.CharacterAdded:Wait()
    local root = character.PrimaryPart; local rootCframe = root.CFrame;
    local positionOffset = (rootCframe.LookVector * Vector3.new(1,0,1)) * PlayerStowy.Settings.DropToolDistance
    local ToolCframe = rootCframe + positionOffset
    local handle = Tool:FindFirstChild("Handle") or Tool.PrimaryPart
    if handle then handle.CFrame = ToolCframe end
    Tool.Parent = workspace
end

function StowayServer:SwapSlots(Player:Player, Slot1:ObjectValue, Slot2:ObjectValue)
    local PlayerStowy = PlayerStoways[Player]
    if not ValidateSlot(Slot1, PlayerStowy) or not ValidateSlot(Slot2, PlayerStowy) then return end
    if Slot1 == Slot2 then return end


    --swapping slots
    local oldslot1 = Slot1.Value
    Slot1.Value = Slot2.Value
    Slot2.Value = oldslot1

    if Slot1.Parent == PlayerStowy.BackpackFolder and not Slot1.Value then
        StowayServer:ShiftBackpackValuesDown(Slot1, Player)
    elseif Slot2.Parent ==PlayerStowy.BackpackFolder and not Slot2.Value then
        StowayServer:ShiftBackpackValuesDown(Slot2, Player)
    end
end

function StowayServer:MoveToEndofBackpack(Slot:ObjectValue, Player:Player)
    local PlayerStowy = PlayerStoways[Player]
    if not ValidateSlot(Slot, PlayerStowy) then return end
    if not Slot.Value then return end

    local tool = Slot.Value
    StowayServer:AddNewBackpackValue(tool, Player)
    Slot.Value = nil

    if Slot.Parent == PlayerStowy.BackpackFolder then
        StowayServer:ShiftBackpackValuesDown(Slot, Player)
    end
end



--//Clean Function\\--
function StowayServer:Clean()
    for _,v in PlayerStoways do
        v.PrivateJanitor:Destroy()
    end

    PlayerStoways = nil
    Global_Janitor:Destroy()
    Global_Janitor = nil
end

--//Connections\\--

SendStowayToClient.OnServerInvoke = SendStowayorSettings

Global_Janitor:Add(Players.PlayerAdded:Connect(StowayServer.new))
Global_Janitor:Add(Players.PlayerRemoving:Connect(function(Player) PlayerStoways[Player].PrivateJanitor:Destroy() end))
Global_Janitor:Add(equipTool.OnServerEvent:Connect(StowayServer.EquipTool))
Global_Janitor:Add(unequipTool.OnServerEvent:Connect(StowayServer.UnEquip))
Global_Janitor:Add(dropTool.OnServerEvent:Connect(function(Player, Tool) StowayServer:DropTool(Player, Tool) end))
Global_Janitor:Add(swapSlots.OnServerEvent:Connect(function(plr, slot1, slot2) StowayServer:SwapSlots(plr, slot1, slot2) end))
Global_Janitor:Add(movetoendofback.OnServerEvent:Connect(function(plr, slot) StowayServer:MoveToEndofBackpack(slot, plr) end))

Global_Janitor:Add(function()
    if SendStowayToClient then
        SendStowayToClient.OnServerInvoke = nil
    end
end)

game:BindToClose(function() StowayServer:Clean() end)
return StowayServer