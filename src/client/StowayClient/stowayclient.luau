local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

--Modules
local Binds = require(ReplicatedStorage.Shared.Binds)
local Janitor = require(ReplicatedStorage.Packages.Janitor)
local fusion = require(ReplicatedStorage.Packages.fusion)
local Types = require(ReplicatedStorage.Shared.Types)
local RarityValues = require(ReplicatedStorage.Shared.RarityValues)


-- RemoteEvents
local dropTool = ReplicatedStorage:WaitForChild("Remotes").DropTool :: RemoteEvent
local equipTool = ReplicatedStorage:WaitForChild("Remotes").EquipTool :: RemoteEvent
local unequipTool = ReplicatedStorage:WaitForChild("Remotes").UnEquipTool :: RemoteEvent
local swapSlots = ReplicatedStorage:WaitForChild("Remotes").SwapSlots :: RemoteEvent
local movetoendofback = ReplicatedStorage:WaitForChild("Remotes").MoveToEndofBackpack :: RemoteEvent


-- BindableEvents
local GetStowayFromServer = ReplicatedStorage:WaitForChild("Remotes").AskForStoway :: RemoteFunction

-- Others
local guis = ReplicatedStorage:WaitForChild("Gui") :: Folder
local slotbuttontemplate = guis.Slot.template :: Frame
local Player = Players.LocalPlayer :: Player
local Character = Player.Character or Player.CharacterAdded:Wait() :: Model
local inventoryFolder : Folder
local BackpackFolder : Folder
local HotbarFolder : Folder

local Settings : Types.Settings

local InventoryGui = Player.PlayerGui:FindFirstChild("StowayGui").Stoway :: ScreenGui
local DraggingGui = Player.PlayerGui:FindFirstChild("StowayGui").DraggingGui :: ScreenGui
local BackpackFrame = InventoryGui.Backpack :: Frame
local HotbarFrame = InventoryGui.Hotbar :: Frame
local ScrollingBackpack = BackpackFrame.ScrollingFrame :: ScrollingFrame
local WeightLabel = BackpackFrame.Weight :: TextLabel

local currentlyEquippedFrame = nil
local currentlyEquippedSlot = nil

local DragginOrigianlFrame = nil 
local DragginFakeFrame = nil
local DragginSlot = nil
local DragginConnection = nil
local DragginThresholdDistance = 5

local stowayclient = {}

--//Fusion Sections\\--
local scoped = fusion.scoped 
local peek = fusion.peek


--//HelperFuncs\\--
function stowayclient.ToggleBackpack(actionName, inputState, inputObject)
    if inputState and inputState ~= Enum.UserInputState.Begin then return end
    BackpackFrame.Visible = not BackpackFrame.Visible 
end

function stowayclient.GetToolData(toolInstance: Tool): Types.ItemData?
    if not toolInstance:IsA("Tool") or not toolInstance:GetAttribute("ItemType") then
        return nil
    end

    -- Ensure Amount attribute is a number, default to 1 if not present or not a number
    local amountAttribute = toolInstance:GetAttribute("Weight") -- Using "Weight" as per your GetToolData
    local initialAmount = math.max(1, amountAttribute) -- Ensure amount is at least 1
    

    local itemData = {
        ID = toolInstance:GetAttribute("Id"),
        Description = toolInstance.ToolTip or "No description.",
        Image = toolInstance.TextureId or "",
        Amount = initialAmount,
        IsGamepass = toolInstance:GetAttribute("IsGamepass") or false,
        Rarity = toolInstance:GetAttribute("Rarity"),
        Droppable = toolInstance:GetAttribute("Droppable") or Settings.Droppable, -- Default to global setting
        Type = toolInstance:GetAttribute("ItemType") :: string,
    } :: Types.ItemData

    return itemData
end

function stowayclient.SetSlotFrameUnequipped(slotframe)
    slotframe.selecticon.Visible = false
end

function stowayclient.SetSlotFrameEquipped(slotframe)
    slotframe.selecticon.Visible = true
end

function stowayclient.findSlotfromTool(Tool:Tool)
    for _, ObjectValue in HotbarFolder:GetChildren() do
        if ObjectValue.Value == Tool then return ObjectValue end
    end

    for _, ObjectValue in BackpackFolder:GetChildren() do
        if ObjectValue.Value == Tool then return ObjectValue end
    end

    return nil
end

function stowayclient.updateEquippedTool()
    local tool = Character:FindFirstChildWhichIsA("Tool")

    if not tool then stowayclient.SetUnequipped(); return end
    local toolslot = stowayclient.findSlotfromTool(tool)
    
    if currentlyEquippedSlot == toolslot then return end
    stowayclient.SetEquipped(toolslot)
end

function stowayclient.BindKeyBinds(actionNamePrefix, slotfolder)
	-- Loop from 1 up to the max number of slots defined in settings.
	for i = 1, Settings.HotbarSettings.MaxSlots do
		-- Get the bind data for the current slot index from our ordered array.
		local bindData = Binds.KeyBinds[i]
		
		-- If we have more slots than defined keybinds, stop.
		if not bindData then
			break
		end

		-- The slot in the HotbarFolder is now directly referenced by the loop index 'i'.
		local slotNumberString = tostring(i)

		local function EquipThisSlot(actionName, inputState, inputObject)
			if inputState ~= Enum.UserInputState.Begin then return end

			local slotValue = slotfolder:FindFirstChild(slotNumberString)
			if not slotValue or not slotValue.Value then
				unequipTool:FireServer()
				return
			end
			stowayclient.EquipUnequipTool(slotValue)
		end

		-- Create a unique action name for each slot.
		local actionName = actionNamePrefix .. slotNumberString
		ContextActionService:BindAction(actionName, EquipThisSlot, false, unpack(bindData.Keys))
	end
end

function stowayclient.ResetDragginValues()
    DragginOrigianlFrame = nil 
    DragginFakeFrame = nil
    DragginSlot = nil
    DragginConnection = nil
end

function stowayclient.Release(inputObject, gameProcessedEvent)
    local inputtype = inputObject.UserInputType

    if inputtype == Enum.UserInputType.MouseButton1 or inputtype == Enum.UserInputType.Touch then
        if not DragginFakeFrame then return end
        if not DragginConnection then return end

        DragginConnection:Disconnect()
        stowayclient.SetSlotFrameHidden(DragginFakeFrame)
        

        if BackpackFrame.Visible and stowayclient.IsMouseInside(ScrollingBackpack, DragginFakeFrame) then
            local backpackslot, value = stowayclient.GetBackpackSlot()

            if backpackslot then
                if DragginSlot == value then
                    stowayclient.SetSlotFrameVisible(DragginOrigianlFrame)
                    if value == currentlyEquippedSlot then stowayclient.SetEquipped(value) end
                else
                    stowayclient.SwapSlots(DragginSlot, value)
                end
            else
                stowayclient.MoveToEndofBackpack(DragginSlot)
            end

        elseif stowayclient.IsMouseInside(HotbarFrame, DragginFakeFrame) then
            local hotbarslot, number = stowayclient.GetHotBarSlot()

            if hotbarslot then
                local slotvalue = HotbarFolder[tostring(number)]

                if DragginSlot == slotvalue then
                    stowayclient.SetSlotFrameVisible(DragginOrigianlFrame)
                    if slotvalue == currentlyEquippedSlot then stowayclient.SetEquipped(slotvalue) end
                else
                    stowayclient.SwapSlots(DragginSlot, slotvalue)
                end
            end

        else
            stowayclient.DropTool(DragginSlot)
        end

        DragginFakeFrame:Destroy()
        stowayclient.ResetDragginValues()
    end
end

function stowayclient.UpdateWeightValues()
    local value = inventoryFolder:GetAttribute("TotalWeight")
    WeightLabel.Text = Settings.BackpackSettings.Limit > 0 and tostring(value) .. "/" .. Settings.BackpackSettings.Limit or tostring(value) .. "/" .. "inf"

    local AllSlots = {}

    for _,v in HotbarFrame:GetChildren() do
        if not v:IsA("Frame") then continue end
        table.insert(AllSlots, v)
    end

    for _,v in ScrollingBackpack:GetChildren() do
        if not v:IsA("Frame") then continue end
        table.insert(AllSlots, v)
    end


    for _,v in AllSlots do
        local name = v.Name:gsub("_", "")
        local hotbarslot = HotbarFolder:FindFirstChild(name)
        local backpackslot = BackpackFolder:FindFirstChild(name)
        if hotbarslot then
            stowayclient.UpdateSlotFrame(v, hotbarslot.Value)
        end

        if backpackslot then
            stowayclient.UpdateSlotFrame(v, backpackslot.Value)
        end
    end
end

--//Setup Function\\--
function stowayclient.new()
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, false)
    StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.PlayerList, false)
    BackpackFrame.Visible = false
    
    if UserInputService.TouchEnabled or UserInputService.GamepadEnabled then
        InventoryGui.BackpackStuff.Visible = true
    end

    local stowayresult = GetStowayFromServer:InvokeServer("stoway") :: Types.Stoway
    if stowayresult then
        inventoryFolder = stowayresult.InventoryFolder
        BackpackFolder = stowayresult.BackpackFolder
        HotbarFolder = stowayresult.HotBarFolder
        if stowayresult.Settings then Settings = stowayresult.Settings end
    end

    local weight = inventoryFolder:GetAttribute("TotalWeight")
    WeightLabel.Text = Settings.BackpackSettings.Limit > 0 and weight .. "/" .. Settings.BackpackSettings.Limit or weight .. "/" .. "inf"

    stowayclient.CreateHotBarFrames()
    stowayclient.CreateBackpackFrames()
    stowayclient.BindKeyBinds("Equip_Hotbar_Slot_", HotbarFolder)
end

--//Core Helper Functions\\--
function stowayclient.SetSlotFrameHidden(SlotFrame)
    if not SlotFrame then return end
    if SlotFrame.Parent == ScrollingBackpack then SlotFrame.BackgroundTransparency = 1 end

    SlotFrame.slotbutton.Visible = false
    SlotFrame.stackcount.Visible = false
    SlotFrame.rarityframe.Visible = false
end

function stowayclient.SetSlotFrameVisible(SlotFrame)
    if not SlotFrame then return end
    if SlotFrame.Parent == ScrollingBackpack then SlotFrame.BackgroundTransparency = 0.8 end

    SlotFrame.slotbutton.Visible = true
    SlotFrame.stackcount.Visible = true
    SlotFrame.rarityframe.Visible = true
end

function stowayclient.UpdateSlotFrame(slotframe, tool:Tool) : any
    if not tool then return stowayclient.SetSlotFrameHidden(slotframe) end 
    if not slotframe then return end
    local data = stowayclient.GetToolData(tool)

    slotframe.stackcount.Text = tonumber(data.Amount) > 1 and Settings.CanStack and data.Amount .. "x" or "" --1 stack count doesnt end wit "x"
    slotframe.slotbutton.Image = data.Image
    
    if Settings.RarityCheck then
        slotframe.rarityframe.Visible = true;
        slotframe.rarityframe.BackgroundColor3 = RarityValues.rarityColors[data.Rarity]
    else
        slotframe.rarityframe.Visible = false;
    end

    return stowayclient.SetSlotFrameVisible(slotframe)
end

function stowayclient.CreateSlotFrameName(slotnumber:number): string
    local numberstring = tostring(slotnumber) :: string
    local slotframeName = ""
    local len = numberstring:len()

    if len > 1 then
        for i=1, (len - 1) do
            slotframeName ..= "_"
        end
    end

    slotframeName..= numberstring

    return slotframeName
end

function stowayclient.getKeyName(Keybinds, slotnumber)
	if not Keybinds or not slotnumber then return end

	-- Directly access the bind data for the slot using its numerical index.
	local bindData = Keybinds[slotnumber]
	if not bindData then return end

	-- The primary display key (e.g., "1", "0", "T") comes directly from the Display field.
	local primaryDisplay = "[" .. bindData.Display .. "]"
	
	-- If there's only one key bound, no need to add more text.
	if #bindData.Keys <= 1 then
		return primaryDisplay
	end
	
	-- Handle multiple keybinds for one slot (e.g., "[G]/[H]")
	local formattedKeyNames = { primaryDisplay }
	
	-- Loop through the *other* keys if they exist.
	for i = 2, #bindData.Keys do
		local keyCodeEnum = bindData.Keys[i]
		local nameParts = string.split(tostring(keyCodeEnum), ".")
		local keyName = nameParts[3]
		table.insert(formattedKeyNames, "[" .. keyName .. "]")
	end

	return table.concat(formattedKeyNames, "/")
end

function stowayclient.CreateSlotFrame(slotvalue:ObjectValue)
    local tool = slotvalue.Value :: Tool
    local slotnumber = tonumber(slotvalue.Name)
    local newslotframe = slotbuttontemplate:Clone()
    newslotframe.Name = stowayclient.CreateSlotFrameName(slotnumber)

    local keybindDisplay = nil
    if slotvalue.Parent == HotbarFolder then
        keybindDisplay = stowayclient.getKeyName(Binds.KeyBinds, slotnumber)
    end

    if keybindDisplay then
        newslotframe.slotnumber.Text = keybindDisplay
    else
        newslotframe.slotnumber.Visible = false
    end

    stowayclient.SetSlotFrameUnequipped(newslotframe)
    stowayclient.UpdateSlotFrame(newslotframe, tool)

    slotvalue.Destroying:Connect(function()
        newslotframe:Destroy()
    end)

    slotvalue:GetPropertyChangedSignal("Value"):Connect(function()
        local newtool = slotvalue.Value  
        if slotvalue.Parent == BackpackFolder and not newtool then
            newslotframe:Destroy()
            return
        end
        stowayclient.UpdateSlotFrame(newslotframe, newtool)
    end)

    newslotframe.slotbutton.MouseButton1Down:Connect(function()
        if not slotvalue.Value then return end

        DragginOrigianlFrame = newslotframe
        DragginSlot = slotvalue

        local InitialMousePosition = UserInputService:GetMouseLocation()
        while true do
            RunService.Heartbeat:Wait()

            local currentMousePosition = UserInputService:GetMouseLocation()
            local mousedistance = (currentMousePosition - InitialMousePosition).Magnitude

            if not DragginOrigianlFrame then return end
            if mousedistance >= DragginThresholdDistance then
                break
            end
        end
        DragginFakeFrame = DragginOrigianlFrame:Clone()
        DragginFakeFrame.slotnumber.Visible = false

        local screenx = DraggingGui.AbsoluteSize.X
        local screeny = DraggingGui.AbsoluteSize.Y
        local absolutebuttonsize = HotbarFrame["1"].AbsoluteSize
        local absolutemouseoffset = UserInputService:GetMouseLocation() - DragginOrigianlFrame.AbsolutePosition
        local scalemouseoffsetx = absolutemouseoffset.X / screenx - 0.02
        local scalemouseoffsety = absolutemouseoffset.Y / screeny - 0.098

        local function SetFrameSize()
            local sizeX = absolutebuttonsize.X / screenx
            local sizeY = absolutebuttonsize.Y / screeny
            DragginFakeFrame.Size = UDim2.new(sizeX, 0, sizeY, 0)
        end

        local function SetFramePos()
            local mousePosition = UserInputService:GetMouseLocation()
            DragginFakeFrame.Position = UDim2.new(
                mousePosition.X / screenx - scalemouseoffsetx, 0,
                mousePosition.Y / screeny - scalemouseoffsety, 0
            )
        end
        SetFrameSize()
        SetFramePos()

        DragginFakeFrame.Parent = DraggingGui
        stowayclient.SetSlotFrameHidden(DragginOrigianlFrame)
        stowayclient.SetSlotFrameUnequipped(DragginOrigianlFrame)

        DragginConnection = RunService.Heartbeat:Connect(function()
            if not DragginFakeFrame or DragginFakeFrame.Parent ~= DraggingGui then stowayclient.ResetDragginValues(); return; end

            screenx = DraggingGui.AbsoluteSize.X
            screeny = DraggingGui.AbsoluteSize.Y
            absolutebuttonsize = HotbarFrame["1"].AbsoluteSize
            SetFrameSize()
            SetFramePos()
        end)
    end)

    newslotframe.slotbutton.MouseButton1Click:Connect(function()
        stowayclient.ResetDragginValues()
        stowayclient.EquipUnequipTool(slotvalue)
    end)

    return newslotframe
end

function stowayclient.CreateHotBarFrames()
    for i=1, Settings.HotbarSettings.MaxSlots do
        local hotbarvalue = HotbarFolder[i]
        local slotframe = stowayclient.CreateSlotFrame(hotbarvalue)
        slotframe.Parent = HotbarFrame
    end 
end

function stowayclient.CreateBackpackFrames()
    for _, backpackvalue in BackpackFolder:GetChildren() do
        local backpackframename = stowayclient.CreateSlotFrameName(backpackvalue.Name)
        if not ScrollingBackpack:FindFirstChild(backpackframename) then
            local slotframe = stowayclient.CreateSlotFrame(backpackvalue)
            slotframe.Parent = ScrollingBackpack
        end
    end
end

function stowayclient.SetUnequipped()
    if not currentlyEquippedFrame then return end
    stowayclient.SetSlotFrameUnequipped(currentlyEquippedFrame)
    currentlyEquippedSlot = nil
    currentlyEquippedFrame = nil
end

function stowayclient.SetEquipped(slot:ObjectValue)
    stowayclient.SetUnequipped()
    currentlyEquippedSlot = slot
    local slotnumber = tonumber(slot.Name)
    local slotframename = stowayclient.CreateSlotFrameName(slotnumber)

    if slot.Parent == BackpackFolder then
        currentlyEquippedFrame = ScrollingBackpack:WaitForChild(slotframename)
    elseif slot.Parent == HotbarFolder then
        currentlyEquippedFrame = HotbarFrame:FindFirstChild(slotframename)
    end
    stowayclient.SetSlotFrameEquipped(currentlyEquippedFrame)
end

function stowayclient.EquipUnequipTool(slotvalue:ObjectValue)
    if currentlyEquippedSlot == slotvalue then
        stowayclient.SetUnequipped()
        unequipTool:FireServer()
    elseif slotvalue.Value then
        stowayclient.SetEquipped(slotvalue)
        equipTool:FireServer(slotvalue.Value)
    end
end

function stowayclient.IsMouseInside(gui1, gui2)
    local gui1_topLeft,gui1_bottomRight = gui1.AbsolutePosition, gui1.AbsolutePosition + gui1.AbsoluteSize
	local gui2_topLeft,gui2_bottomRight = gui2.AbsolutePosition, gui2.AbsolutePosition + gui2.AbsoluteSize
	return ((gui1_topLeft.x < gui2_bottomRight.x and gui1_bottomRight.x > gui2_topLeft.x) and (gui1_topLeft.y < gui2_bottomRight.y and gui1_bottomRight.y > gui2_topLeft.y))
end

function stowayclient.GetHotBarSlot()

    for i=1, Settings.HotbarSettings.MaxSlots do
        local hotbarslot = HotbarFrame[stowayclient.CreateSlotFrameName(i)]
        if stowayclient.IsMouseInside(hotbarslot, DragginFakeFrame) then
            return hotbarslot, i 
        end
    end

    return
end

function stowayclient.GetBackpackSlot()

    for _, slotvalue in BackpackFolder:GetChildren() do
        local backpackslot = ScrollingBackpack[stowayclient.CreateSlotFrameName(slotvalue.Name)]
        if stowayclient.IsMouseInside(backpackslot, DragginFakeFrame) then
            return backpackslot, slotvalue
        end
    end

    return
end

function stowayclient.ShiftEquippedSlot(slot)
    if not currentlyEquippedSlot then return end

    if currentlyEquippedSlot.Parent == BackpackFolder and slot.Parent == BackpackFolder then
        if tonumber(currentlyEquippedSlot.Name) > tonumber(slot.Name) then
            local digit = tonumber(currentlyEquippedSlot.Name)
            local foundslot = BackpackFolder[digit - 1] 
            stowayclient.SetEquipped(foundslot)
        end
    end
end

function stowayclient.SwapSlots(slot1, slot2)
    local requestStackAction = false -- Flag to determine what action to request from the server.
    local MaxStack = Settings.MaxStackCount
    local slot1value = function() return slot1.Value end
    local slot2value = function() return slot2.Value end
    -- First, determine if a stack should be requested.
    -- This checks if stacking is enabled globally and if both slots actually contain items.
    if Settings.CanStack and slot1.Value and slot2.Value then
        local sourceWeight = slot1value():GetAttribute("Weight")
		local targetWeight = slot2value():GetAttribute("Weight")

        -- Check if the items have the same type and name.
        if slot1value():GetAttribute("ItemType") == slot2value():GetAttribute("ItemType") and slot1value().Name == slot2value().Name then
            -- If they do, now check the rarity based on the settings.
            if Settings.RarityCheck then
                -- If RarityCheck is ON, their rarities must also match.
                if slot1value():GetAttribute("Rarity") == slot2value():GetAttribute("Rarity") then
                    requestStackAction = true -- Conditions met for a rarity-checked stack.
                end
            else
                -- If RarityCheck is OFF, matching name and type is enough.
                requestStackAction = true -- Conditions met for a non-rarity-checked stack.
            end
        end

        if sourceWeight == MaxStack or targetWeight == MaxStack then requestStackAction = false end
    end

    -- Now, fire the remote event based on the validation result.
    if requestStackAction then
        -- Request a STACK action from the server.
        swapSlots:FireServer(slot1, slot2, true)

        -- Your existing client-side visual update logic for stacking.
        local slotframe1 = stowayclient.CreateSlotFrameName(slot1.Name)
        slotframe1 = HotbarFrame:FindFirstChild(slotframe1) or ScrollingBackpack:FindFirstChild(slotframe1)

        local slotframe2 = stowayclient.CreateSlotFrameName(slot2.Name)
        slotframe2 = HotbarFrame:FindFirstChild(slotframe2) or ScrollingBackpack:FindFirstChild(slotframe2)

        task.delay(0.1, function() 
            stowayclient.UpdateSlotFrame(slotframe1, slot1.Value)
            stowayclient.UpdateSlotFrame(slotframe2, slot2.Value) 
        end)
    else
        -- Request a normal SWAP action from the server.
        swapSlots:FireServer(slot1, slot2, false)
    end
    
    -- The rest of your logic for updating the equipped tool display remains the same.

    if slot1value() and slot1value().Parent == Character then
        return stowayclient.SetEquipped(slot2)
    elseif slot2value() and slot2value().Parent == Character then
        return stowayclient.SetEquipped(slot1)
    end

    if slot1.Parent == BackpackFolder and not slot2value() then
        if currentlyEquippedSlot == slot1 then return stowayclient.SetEquipped(slot2) end
        if currentlyEquippedFrame then 
            local number = currentlyEquippedSlot.Name; number = tonumber(number); number -= 1 
            stowayclient.SetEquipped(slot1.Parent[number]) end
    elseif slot2.Parent == BackpackFolder and not slot1value() then
        if currentlyEquippedSlot == slot2 then stowayclient.SetEquipped(slot1) end
    end
end

function stowayclient.MoveToEndofBackpack(slot)
    local numofbackpackslots = #BackpackFolder:GetChildren() + #HotbarFolder:GetChildren()
    movetoendofback:FireServer(slot)
    local slototequip = BackpackFolder:WaitForChild(numofbackpackslots + 1)
    

    if slototequip.Value.Parent == Character then
        if slot.Parent == HotbarFolder then
            stowayclient.SetEquipped(slototequip)
        else
            slototequip = BackpackFolder[numofbackpackslots]
            stowayclient.SetEquipped(slototequip)
        end
    elseif currentlyEquippedSlot then
        stowayclient.ShiftEquippedSlot(slot)
    end
end

function stowayclient.DropTool(slot)
    local tool = slot.Value
    dropTool:FireServer(tool)

    -- if you cannot drop a tool then we must show the frames for slots that hold that tool 
    if slot and slot.Value then   
        local hotbarframe = HotbarFrame:FindFirstChild(stowayclient.CreateSlotFrameName(slot.Name))
        local backpackframe = ScrollingBackpack:FindFirstChild(stowayclient.CreateSlotFrameName(slot.Name))

        if hotbarframe then 
            if currentlyEquippedFrame == hotbarframe then
                stowayclient.SetSlotFrameVisible(hotbarframe)
                stowayclient.SetEquipped(slot)
            else
                stowayclient.SetSlotFrameVisible(hotbarframe)
            end
        end

            
        if backpackframe then
            if currentlyEquippedFrame == backpackframe then
                stowayclient.SetSlotFrameVisible(backpackframe)
                stowayclient.SetEquipped(slot)
            else
                stowayclient.SetSlotFrameVisible(backpackframe)
            end 
        end
    end
end


stowayclient.new()
ContextActionService:BindAction("toggle_backpack", stowayclient.ToggleBackpack, false, unpack(Binds.BackpackBinds))
BackpackFolder.ChildAdded:Connect(stowayclient.CreateBackpackFrames)
Character.ChildAdded:Connect(stowayclient.updateEquippedTool)
Character.ChildRemoved:Connect(stowayclient.updateEquippedTool)
UserInputService.InputEnded:Connect(stowayclient.Release)
inventoryFolder:GetAttributeChangedSignal("TotalWeight"):Connect(stowayclient.UpdateWeightValues)

if InventoryGui.BackpackStuff.Visible then InventoryGui.BackpackStuff.MouseButton1Click:Connect(function() BackpackFrame.Visible = not BackpackFrame.Visible end) end

return stowayclient