local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local InputManager = require(script.Parent.InputManager)
local InventoryController = require(script.Parent.Parent.Operations.InventoryController)
local IllusionIAS = require(ReplicatedStorage.Packages.IllusionIAS)

local SelectionManager = {}
local SelectionState = {
    enabled = false,
    step = 0,  -- 0: idle, 1: source selected
    sourceType = nil,
    sourceSlot = nil,
    sourceFrame = nil,
}

local HotbarFrame = nil
local BackpackFrame = nil

local Binds = require(ReplicatedStorage.Shared.Binds)

local ConsoleDropUI = require(script.Parent.ConsoleDropUI)

local swapAction = nil
local dropAction = nil 
local quickMoveAction = nil
local cancelAction = nil

-- Dynamic Drop Actions Container
local activeDropActions = {}
local dropIncreaseAction = nil
local dropDecreaseAction = nil
local HookManager = nil

SelectionManager.OnStateChanged = nil -- Call this function instead of firing a BindableEvent

function SelectionManager.Init(hotbarFrame, backpackFrame, hookManager)
    HotbarFrame = hotbarFrame
    BackpackFrame = backpackFrame
    HookManager = hookManager
    
    if HotbarFrame then HotbarFrame.SelectionGroup = true end
    if BackpackFrame then BackpackFrame.SelectionGroup = true end
    
    local inventoryActions = Binds.Global.InventoryActions
    
    -- 1. Swap Bind (Y)
    swapAction = IllusionIAS.new("ConsoleSwapAction")
    Binds.ApplyToAction(swapAction, inventoryActions.Swap, "Console")
    swapAction.Activated:Connect(function(active, pressed)
        if not SelectionState.enabled or not pressed then return end
        SelectionManager.HandleSwap()
    end)

    -- 2. Drop Bind (X)
    dropAction = IllusionIAS.new("ConsoleDropAction")
    Binds.ApplyToAction(dropAction, inventoryActions.Drop, "Console")
    dropAction.Activated:Connect(function(active, pressed)
        if not SelectionState.enabled or not pressed then return end
        SelectionManager.HandleDrop()
    end)

    -- 3. Quick Move Bind (A)
    quickMoveAction = IllusionIAS.new("ConsoleQuickMoveAction")
    Binds.ApplyToAction(quickMoveAction, inventoryActions.QuickMove, "Console")
    quickMoveAction.Activated:Connect(function(active, pressed)
        if not SelectionState.enabled or not pressed then return end
        SelectionManager.HandleQuickMove()
    end)
    
    -- 4. Cancel Bind (B)
    cancelAction = IllusionIAS.new("ConsoleCancelAction")
    Binds.ApplyToAction(cancelAction, inventoryActions.Cancel, "Console")
    cancelAction.Activated:Connect(function(active, pressed)
        if not SelectionState.enabled or not pressed then return end
        SelectionManager.CancelSelection()
    end)
    
    IllusionIAS.addContext(InputManager.ContextInventory, swapAction, dropAction, quickMoveAction, cancelAction)
end

function SelectionManager.LoadDropBinds()
    if next(activeDropActions) then return end -- Already loaded

    local dropActions = Binds.Global.DropActions

    dropIncreaseAction = IllusionIAS.new("DropIncrease")
    Binds.ApplyToAction(dropIncreaseAction, dropActions.Increase, "Console")
    
    dropDecreaseAction = IllusionIAS.new("DropDecrease")
    Binds.ApplyToAction(dropDecreaseAction, dropActions.Decrease, "Console")
    
    dropIncreaseAction.Activated:Connect(function(active, pressed) if pressed then ConsoleDropUI.ChangeAmount(1) end end)
    dropDecreaseAction.Activated:Connect(function(active, pressed) if pressed then ConsoleDropUI.ChangeAmount(-1) end end)
    
    IllusionIAS.addContext(InputManager.ContextDrop, dropIncreaseAction, dropDecreaseAction)
    
    table.insert(activeDropActions, dropIncreaseAction)
    table.insert(activeDropActions, dropDecreaseAction)
end

function SelectionManager.UnloadDropBinds()
    for _, action in ipairs(activeDropActions) do
        action:Destroy()
    end
    table.clear(activeDropActions)
    dropIncreaseAction = nil
    dropDecreaseAction = nil
end

function SelectionManager.GetSelectedSlotInfo()
    local selected = GuiService.SelectedObject
    if not selected then return nil end
    
    local slotFrame = selected.Parent 
    if not slotFrame then return nil end
    
    local slotType
    if slotFrame.Parent and slotFrame.Parent.Name == "Hotbar" then
        slotType = "Hotbar"
    elseif slotFrame.Parent and slotFrame.Parent.Name == "ScrollingFrame" and slotFrame.Parent.Parent.Name == "Backpack" then 
        slotType = "Storage"
    elseif slotFrame.Parent and slotFrame.Parent.Name == "Storage" then
         slotType = "Storage"
    end
    
    if not slotType then return nil end
    
    local slotName = slotFrame.Name:gsub("_", "")
    local slotIndex = tonumber(slotName)
    if not slotIndex then return nil end
    
    return {
        Type = slotType,
        Index = slotIndex,
        Frame = slotFrame
    }
end

function SelectionManager.GetStateDescription()
    if SelectionState.step == 2 then
        return "🗑️ DROPPING ITEM"
    elseif SelectionState.step == 1 then
        return "🔄 SWAPPING - SELECT TARGET"
    else
        return "👋 SELECTING"
    end
end

function SelectionManager.NotifyStateChanged()
    if SelectionManager.OnStateChanged then
         SelectionManager.OnStateChanged(SelectionManager.GetStateDescription())
    end
end

function SelectionManager.HandleSwap()
    local selected = SelectionManager.GetSelectedSlotInfo()
    if not selected then return end
    
    if SelectionState.step == 2 then return end -- Block Swap while Dropping

    if SelectionState.step == 0 then
        -- Step 1: Select source
        SelectionState.step = 1
        SelectionState.sourceType = selected.Type
        SelectionState.sourceSlot = selected.Index
        SelectionState.sourceFrame = selected.Frame
        
        SelectionManager.ApplySelectionHighlight(selected.Frame)
        SelectionManager.NotifyStateChanged()
        
    elseif SelectionState.step == 1 then
        -- Step 2: Select destination
        if SelectionState.sourceType == selected.Type and SelectionState.sourceSlot == selected.Index then
             -- Toggling same slot deselects
             SelectionManager.CancelSelection()
             return
        end
        
        InventoryController.Swap(
            SelectionState.sourceType,
            SelectionState.sourceSlot,
            selected.Type,
            selected.Index,
            true
        )
        
        SelectionManager.CancelSelection()
    end
end

function SelectionManager.HandleDrop()
    local selected = SelectionManager.GetSelectedSlotInfo()
    if not selected then return end
    
    if SelectionState.step == 1 then return end -- Block Drop while Swapping
    
    -- Fetch Item Data using new helper
    local store = require(script.Parent.Parent.CoreState.InventoryStore)
    local item = store:GetItemFromSlot(selected.Type, selected.Index)
    
    if not item then return end

    SelectionState.step = 2 -- Dropping
    SelectionManager.NotifyStateChanged()
    
    InputManager.SetInventoryEnabled(false)
    InputManager.SetDropEnabled(true)
    
    SelectionManager.LoadDropBinds()
    
    -- Set up callbacks for button clicks
    ConsoleDropUI.OnDrop = function(amount)
        InventoryController.Drop(selected.Type, selected.Index, amount, true)
        SelectionManager.CloseDropUI()
    end
    
    ConsoleDropUI.OnDropAll = function()
        InventoryController.Drop(selected.Type, selected.Index, item.Amount, true)
        SelectionManager.CloseDropUI()
    end
    
    ConsoleDropUI.OnCancel = function()
        SelectionManager.CloseDropUI()
    end
    
    ConsoleDropUI.Show(item, 1)
end

function SelectionManager.CloseDropUI()
    ConsoleDropUI.Hide()
    InputManager.SetDropEnabled(false)
    InputManager.SetInventoryEnabled(true)
    
    SelectionManager.UnloadDropBinds()
    
    -- Clear callbacks
    ConsoleDropUI.OnDrop = nil
    ConsoleDropUI.OnDropAll = nil
    ConsoleDropUI.OnCancel = nil
    
    SelectionState.step = 0
    SelectionManager.NotifyStateChanged()
end

function SelectionManager.HandleQuickMove()
    local selected = SelectionManager.GetSelectedSlotInfo()
    if not selected then return end
    
    -- If in middle of swap, cancel it
    if SelectionState.step == 1 then
        SelectionManager.CancelSelection()
    end
    
    if SelectionState.step == 2 then return end -- Don't quick move while dropping

    -- Determine target type and find empty slot using helpers
    local store = require(script.Parent.Parent.CoreState.InventoryStore)
    local targetType = (selected.Type == "Hotbar") and "Storage" or "Hotbar"
    local emptySlotIndex
    
    if targetType == "Hotbar" then
        emptySlotIndex = store:FindFirstEmptyHotbarSlot()
    else
        emptySlotIndex = store:FindFirstEmptyStorageSlot()
    end
    
    if emptySlotIndex then
        InventoryController.Swap(
            selected.Type,
            selected.Index,
            targetType,
            emptySlotIndex,
            true
        )
    end
end

function SelectionManager.CancelSelection()
    if SelectionState.step == 2 then
        SelectionManager.CloseDropUI()
        return
    end

    if SelectionState.sourceFrame then
        SelectionManager.ClearSelectionHighlight(SelectionState.sourceFrame)
    end
    SelectionState.step = 0
    SelectionState.sourceType = nil
    SelectionState.sourceSlot = nil
    SelectionState.sourceFrame = nil
    
    SelectionManager.NotifyStateChanged()
end

function SelectionManager.SetEnabled(state: boolean)
    SelectionState.enabled = state
    GuiService.GuiNavigationEnabled = state
    
    if not state then
        SelectionManager.CancelSelection()
        SelectionManager.UnloadDropBinds() -- Cleanup drop binds if forced disabled
        GuiService.SelectedObject = nil
    end
end

function SelectionManager.ApplySelectionHighlight(frame)
    if HookManager then
        HookManager:Fire("OnSelect", frame)
    end
end

function SelectionManager.ClearSelectionHighlight(frame)
    if HookManager then
        HookManager:Fire("OnDeselect", frame)
    end
end

function SelectionManager.Destroy()
    SelectionManager.CancelSelection()
    SelectionManager.UnloadDropBinds()
    
    -- Destroy Drop UI completely
    ConsoleDropUI.Destroy()
    
    if swapAction then swapAction:Destroy(); swapAction = nil end
    if dropAction then dropAction:Destroy(); dropAction = nil end
    if quickMoveAction then quickMoveAction:Destroy(); quickMoveAction = nil end
    if cancelAction then cancelAction:Destroy(); cancelAction = nil end
    
    SelectionState.enabled = false
    GuiService.GuiNavigationEnabled = false
    HotbarFrame = nil
    BackpackFrame = nil
    
    SelectionManager.OnStateChanged = nil
end

return SelectionManager
