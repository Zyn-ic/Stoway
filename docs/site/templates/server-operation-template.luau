-- Stoway Server Operation Template
-- Copy this file to src/server/StowayServerV1_2/Operations/{{OperationName}}.luau
-- See docs/guides/add-server-features.html for complete instructions

--// ═══════════════════════════════════════════════════════════════════════════
--// {{OperationName}}.luau
--// Description: [Add description of what this operation does]
--// ═══════════════════════════════════════════════════════════════════════════

local {{OperationName}} = {}

--// Dependencies
local SlotManager = require(script.Parent.Parent.Core.SlotManager)
local LimitChecker = require(script.Parent.Parent.Core.LimitChecker)
local UUID = require(script.Parent.Parent.Utils.UUID)

--// Types
export type {{OperationName}}Result = {
	success: boolean,
	reason: string?,
	-- Add your result fields here:
	-- field1: type1?,
	-- field2: type2?,
}

--// ═══════════════════════════════════════════════════════════════════════════
--// Main Execute Function
--// ═══════════════════════════════════════════════════════════════════════════

function {{OperationName}}.Execute(
	state: InventoryStateType,
	-- Add your parameters here:
	param1: string,    -- Replace with actual parameter type
	param2: number     -- Replace with actual parameter type
): {{OperationName}}Result
	--// 1. Validate Inputs
	--------------------------------
	if not param1 then
		return { success = false, reason = "INVALID_PARAM1" }
	end

	--// 2. Perform Operation
	--------------------------------
	-- TODO: Add your operation logic here
	-- Examples of common operations:

	-- Find a slot:
	-- local slotType, slotIndex = SlotManager.FindSlotByUUID(state, uuid)

	-- Find empty hotbar slot:
	-- local emptySlot = SlotManager.FindEmptyHotbarSlot(state)

	-- Check weight limit:
	-- if LimitChecker.IsEnabled(state) then
	--     local remaining = LimitChecker.GetRemainingCapacity(state)
	--     if remaining <= 0 then
	--         return { success = false, reason = "FULL" }
	--     end
	-- end

	--// 3. Modify State
	--------------------------------
	-- TODO: Update state.Items, state.Hotbar, state.Storage as needed
	-- Example: state.Items[uuid] = { UUID = uuid, Id = "item", Amount = 1 }

	--// 4. Return Result
	--------------------------------
	return {
		success = true,
		-- Add your result fields here:
		-- field1 = value1,
		-- field2 = value2,
	}
end

return {{OperationName}}

--// ═══════════════════════════════════════════════════════════════════════════
--// QUICK REFERENCE: Common State Operations
--// ═══════════════════════════════════════════════════════════════════════════

--[[
-- Access Items by UUID (O(1)):
local item = state.Items[uuid]

-- Access Items by ID (for stacking):
local uuids = state.ItemsByID["sword"]  -- returns {uuid1, uuid2, ...}

-- Get hotbar slot:
local uuid = state.Hotbar[slotIndex]

-- Get storage slot:
local uuid = state.Storage[index]

-- Set hotbar slot:
SlotManager.SetHotbarSlot(state, slotIndex, uuid)

-- Append to storage:
SlotManager.AppendStorage(state, uuid)

-- Update weight:
LimitChecker.AddWeight(state, amount)
LimitChecker.RemoveWeight(state, amount)

-- Check if item is equipped:
local isEquipped = state.EquippedItemUUID == uuid
--]]

--// ═══════════════════════════════════════════════════════════════════════════
--// WIRING INSTRUCTIONS (Copy to docs/guides/add-server-features.html reference)
--// ═══════════════════════════════════════════════════════════════════════════

--[[
STEP 1: Add to init.luau imports
-------------------------------
local {{OperationName}} = require(script.Operations.{{OperationName}})

STEP 2: Add API method to InventoryService
-----------------------------------------
function InventoryService.{{OperationName}}(player, param1, param2, REPLICATE)
    local state = PlayerInventories[player]
    if not state then return { success = false, reason = "NO_INVENTORY" } end
    
    local result = {{OperationName}}.Execute(state, param1, param2)
    
    if result.success and REPLICATE then
        -- Add replication if needed:
        -- Replicator.SendSomething(player, ...)
    end
    
    return result
end

STEP 3: Wire to network protocol
--------------------------------
-- In Operations table:
[Operations.{{OPERATION_NAME}}] = "{{OperationName}}"

-- In OperationHandlers table:
[Operations.{{OPERATION_NAME}}] = function(player, args)
    return InventoryService.{{OperationName}}(player, args.param1, args.param2, false)
end
--]]
