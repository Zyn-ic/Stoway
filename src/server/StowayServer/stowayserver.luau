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

--- Checks if a player's inventory can accept an item with a given weight. returns boolean: True if the item can be added, false otherwise.
function _canAcceptWeight(PlayerStowy, weightToAdd) : boolean
    local PlayerLimit = PlayerStowy.Settings.BackpackSettings.Limit
    -- If limit is 0, it signifies infinite capacity, so always accept.
    if PlayerLimit == 0 then
        return true
    end

    local PlayerTotalWeight = PlayerStowy.InventoryFolder:GetAttribute("TotalWeight")
    -- Check if adding the new item would exceed the limit.
    if (PlayerTotalWeight + weightToAdd) > PlayerLimit then
        return false
    end

    return true
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
    self.InventoryFolder:SetAttribute("TotalWeight", 0)

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

function StowayServer:AddNewBackpackValue(Tool: Tool, Player: Player)
    local PlayerStowy = PlayerStoways[Player]

    -- This is a completely new tool being added to the system. Perform the weight check.
    if not StowayServer:FindValueFromTool(Tool, Player) then
        local ToolWeight = Tool:GetAttribute("Weight")
        if not _canAcceptWeight(PlayerStowy, ToolWeight) then
            Tool:Destroy() -- Destroy the tool as the player can't carry it or drop the tool
            return -- Exit the function
        end

        -- If the weight is acceptable, update the total weight attribute.
        local PlayerTotalWeight = PlayerStowy.InventoryFolder:GetAttribute("TotalWeight")
        PlayerStowy.InventoryFolder:SetAttribute("TotalWeight", PlayerTotalWeight + ToolWeight)
    end
    -- If the tool is already tracked (e.g., moving from hotbar), we don't need to re-check the weight limit. so findvaluefromtool will exit to out here

    -- Get all current slots to name the new backpack slot correctly.
    local folder = PlayerStowy.HotBarFolder:GetChildren()
    for _, v in PlayerStowy.BackpackFolder:GetChildren() do
        table.insert(folder, v)
    end

    local newbackpackValue = Instance.new("ObjectValue")
    newbackpackValue.Name = #folder + 1
    newbackpackValue.Value = Tool
    newbackpackValue.Parent = PlayerStowy.BackpackFolder
end

function StowayServer:FindSuitableHotbarSlot(Tool: Tool?, Player: Player) : ObjectValue?
    local PlayerStowy = PlayerStoways[Player] :: Types.Stoway
    local raritycheck = PlayerStowy.Settings.RarityCheck

    -- This block only runs if a tool is provided AND stacking is enabled in settings.
    if Tool and PlayerStowy.Settings.CanStack then
        local ToolWeight = Tool:GetAttribute("Weight")
        local result = FindSameSlotType(PlayerStowy.HotBarFolder:GetChildren(), Tool)

        -- if we find a slot with the same type in the hotbar we must check rarity (if enabled) and stack count.
        if result and result.Value then
            local resultRarity = result.Value:GetAttribute("Rarity")
            local toolRarity = Tool:GetAttribute("Rarity")
            print(resultRarity, toolRarity)
            local stackountiIsLessThanOr5 = ((ToolWeight + result.Value:GetAttribute("Weight")) <= PlayerStowy.Settings.MaxStackCount)

            -- if rarity check is enabled then we will find a suitable slot with the same type and rarity
            if raritycheck and resultRarity == toolRarity and stackountiIsLessThanOr5 then
                return result

            elseif not raritycheck and stackountiIsLessThanOr5 then
                -- Check if stacking in the found slot would exceed the item's individual max stack count.
                return result
            end
        end
    end

    -- If stacking is disabled, or no suitable stackable slot was found, find the next empty slot.
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

function StowayServer:UpdatePlayerTools(Player: Player)
    local PlayerStowy = PlayerStoways[Player] :: Types.Stoway
    local char = Player.Character
    local playerTools = StowayServer:getTools(Player.Backpack, char)
    local inventoryvalues = PlayerStowy.BackpackFolder:GetChildren()

    for _, v in PlayerStowy.HotBarFolder:GetChildren() do
        table.insert(inventoryvalues, v)
    end

    -- First, clean up any tracked values for tools that no longer exist.
    for _, value: ObjectValue in inventoryvalues do
        local tool = value.Value
        if tool and not table.find(playerTools, tool) then
            --This logic should also subtract the tool's weight from the total!
            local PlayerTotalWeight = PlayerStowy.InventoryFolder:GetAttribute("TotalWeight")
            PlayerStowy.InventoryFolder:SetAttribute("TotalWeight", PlayerTotalWeight - tool:GetAttribute("Weight"))
            
            value.Value = nil
            if value.Parent == PlayerStowy.BackpackFolder then StowayServer:ShiftBackpackValuesDown(value, Player) end
        end
    end

    -- Next, process any new, untracked tools.
    for _, tool: Tool in playerTools do
        if not StowayServer:FindValueFromTool(tool, Player) then
            local ToolWeight = tool:GetAttribute("Weight")

            -- 1. CENTRAL WEIGHT CHECK: Check if the player can carry this new tool.
            if not _canAcceptWeight(PlayerStowy, ToolWeight) then
                tool:Destroy()
                continue -- Skip to the next tool.
            end

            -- 2. Find a suitable slot in the hotbar (stackable or empty).
            local freehotbarslot = StowayServer:FindSuitableHotbarSlot(tool, Player)

            if freehotbarslot then
                -- If a hotbar slot was found, add the tool's weight to the total count.
                local PlayerTotalWeight = PlayerStowy.InventoryFolder:GetAttribute("TotalWeight")
                PlayerStowy.InventoryFolder:SetAttribute("TotalWeight", PlayerTotalWeight + ToolWeight)

                -- Check if the found slot is for stacking or for a new entry.
                if freehotbarslot.Value ~= nil then -- Stacking case
                    local combindedweight = freehotbarslot.Value:GetAttribute("Weight") + ToolWeight
                    freehotbarslot.Value:SetAttribute("Weight", combindedweight)
                    tool:Destroy() -- Destroy the new tool as its weight was absorbed.
                else -- New empty slot case
                    freehotbarslot.Value = tool
                end
            else
                -- 3. No suitable hotbar slot found, so attempt to add to backpack.
                -- AddNewBackpackValue will handle its own weight check and update.
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
    local PlayerStoway = PlayerStoways[Player] :: Types.Stoway
    if not slot then return end

    -- if a person's settings is set to droppable then we will check if an item has IsDroppable
    if PlayerStoway.Settings.Droppable then
        -- if the tool is a gamepass then is cannot be dropped but if its not and IsDroppable it will drop
        local candrop = Tool:GetAttribute("IsDroppable"); if Tool:GetAttribute("IsGamepass") == true then candrop = false end;
        if not candrop then return end
    else
        return
    end

    local PlayerStowy = PlayerStoways[Player]
    local character = Player.Character or Player.CharacterAdded:Wait()
    local root = character.PrimaryPart; local rootCframe = root.CFrame;
    local positionOffset = (rootCframe.LookVector * Vector3.new(1,0,1)) * PlayerStowy.Settings.DropToolDistance
    local ToolCframe = rootCframe + positionOffset
    local handle = Tool:FindFirstChild("Handle") or Tool.PrimaryPart
    if handle then handle.CFrame = ToolCframe end
    Tool.Parent = workspace
end

function StowayServer:SwapSlots(Player: Player, Slot1: ObjectValue, Slot2: ObjectValue, stack: boolean?)
	local PlayerStowy = PlayerStoways[Player] :: Types.Stoway
	if not ValidateSlot(Slot1, PlayerStowy) or not ValidateSlot(Slot2, PlayerStowy) then return end
	if Slot1 == Slot2 then return end

	local performStackAction = false -- Flag to determine which action to take
    local MaxStack = PlayerStowy.Settings.MaxStackCount
    local sourceWeight 
	local targetWeight 

	-- First, determine if a stack is even possible and allowed.
	if stack and PlayerStowy.Settings.CanStack then
		local slotbeingswapped = Slot1.Value
		local targetslot = Slot2.Value

		-- A stack is only possible if both slots contain an item.
		if slotbeingswapped and targetslot then
			local sourceItemType = slotbeingswapped:GetAttribute("ItemType")
			local targetItemType = targetslot:GetAttribute("ItemType")
            sourceWeight = slotbeingswapped:GetAttribute("Weight")
		    targetWeight = targetslot:GetAttribute("Weight")

			-- Check if items are identical based on Type and Name
			if sourceItemType == targetItemType and slotbeingswapped.Name == targetslot.Name then
				if PlayerStowy.Settings.RarityCheck then
					-- If RarityCheck is ON, rarities must also match.
					if slotbeingswapped:GetAttribute("Rarity") == targetslot:GetAttribute("Rarity") then
						performStackAction = true
					end
				else
					-- If RarityCheck is OFF, matching type and name is sufficient.
					performStackAction = true
				end
			end

            -- incase the client is trying to stack a slot that already is at max stack we will perform swapping
            if sourceWeight == MaxStack or targetWeight == MaxStack then performStackAction = false end
		end
	end

	-- Now, perform the action based on the flag.
	if performStackAction then
		-- --- STACKING LOGIC ---
		-- This block now only runs if all server-side checks pass.
		local slotbeingswapped = Slot1.Value
		local targetslot = Slot2.Value
		local spaceInTarget = MaxStack - targetWeight
		local amountToTransfer = math.min(sourceWeight, spaceInTarget)
		
		if amountToTransfer > 0 then
			targetslot:SetAttribute("Weight", targetWeight + amountToTransfer)
			slotbeingswapped:SetAttribute("Weight", sourceWeight - amountToTransfer)

			if slotbeingswapped:GetAttribute("Weight") <= 0 then
				slotbeingswapped:Destroy()
				Slot1.Value = nil -- Clear the ObjectValue reference
			end
		end
	else
		-- --- SWAPPING LOGIC ---
		-- This is the fallback for all other cases:
		-- 1. Client requested a swap (`stack` was false).
		-- 2. Stacking is disabled on the server.
		-- 3. One or both slots were empty.
		-- 4. Items were not identical (failed the validation checks).
		local oldslot1 = Slot1.Value
		Slot1.Value = Slot2.Value
		Slot2.Value = oldslot1
	end

	-- This shifting logic runs after either a stack or swap operation.
	if Slot1.Parent == PlayerStowy.BackpackFolder and not Slot1.Value then
		StowayServer:ShiftBackpackValuesDown(Slot1, Player)
	elseif Slot2.Parent == PlayerStowy.BackpackFolder and not Slot2.Value then
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
Global_Janitor:Add(swapSlots.OnServerEvent:Connect(function(plr, slot1, slot2, stack) StowayServer:SwapSlots(plr, slot1, slot2, stack) end))
Global_Janitor:Add(movetoendofback.OnServerEvent:Connect(function(plr, slot) StowayServer:MoveToEndofBackpack(slot, plr) end))

Global_Janitor:Add(function()
    if SendStowayToClient then
        SendStowayToClient.OnServerInvoke = nil
    end
end)

game:BindToClose(function() StowayServer:Clean() end)
return StowayServer