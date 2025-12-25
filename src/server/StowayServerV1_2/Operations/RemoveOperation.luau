-- src/server/StowayServerV1.2/Operations/RemoveOperation.luau
-- Handles full Remove logic flow: Validate → Reduce/Destroy → Shift if Storage

local RemoveOperation = {}

local SlotManager = require(script.Parent.Parent.Core.SlotManager)
local LimitChecker = require(script.Parent.Parent.Core.LimitChecker)

export type RemoveResult = {
	success: boolean,
	reason: string?,
	slotType: string?,
	slot: number?,
	remaining: number?
}

--// Destroy item completely from inventory
local function DestroyItem(state: any, uuid: string, itemId: string, itemAmount: number): RemoveResult
	-- Find which slot contains this item
	local slotType, slot = SlotManager.FindSlotByUUID(state, uuid)
	
	-- Unequip if currently equipped
	if state.EquippedItemUUID == uuid then
		state.EquippedItemUUID = nil
	end
	
	-- Remove weight
	LimitChecker.RemoveWeight(state, itemAmount)
	
	-- Remove from Items map
	state.Items[uuid] = nil
	
	-- Remove from ItemsByID lookup
	local uuids = state.ItemsByID[itemId]
	if uuids then
		for i, id in ipairs(uuids) do
			if id == uuid then
				table.remove(uuids, i)
				break
			end
		end
		if #uuids == 0 then
			state.ItemsByID[itemId] = nil
		end
	end
	
	-- Remove from slot
	if slotType == "Hotbar" and slot then
		SlotManager.ClearHotbarSlot(state, slot) -- Preserves hole (Static)
	elseif slotType == "Storage" and slot then
		SlotManager.RemoveStorageAt(state, slot) -- Shifts items (Dynamic)
	end
	
	return { success = true, slotType = slotType, slot = slot, remaining = 0 }
end

--// Main Execute function
function RemoveOperation.Execute(state: any, uuid: string, amount: number?): RemoveResult
	local item = state.Items[uuid]
	if not item then
		return { success = false, reason = "ITEM_NOT_FOUND" }
	end
	
	-- Default: remove all if no amount specified
	local _amount = amount or item.Amount
	
	-- Validate amount
	if _amount <= 0 then
		return { success = false, reason = "INVALID_AMOUNT" }
	end
	
	-- Cap to item amount (per spec: if more than stack, remove all)
	if _amount > item.Amount then
		_amount = item.Amount
	end
	
	-- Reduce or Destroy
	if item.Amount > _amount then
		item.Amount -= _amount
		LimitChecker.RemoveWeight(state, _amount :: number)
		local slotType, slot = SlotManager.FindSlotByUUID(state, uuid)
		return { success = true, slotType = slotType, slot = slot, remaining = item.Amount }
	else
		-- Full removal
		return DestroyItem(state, uuid, item.Id, item.Amount)
	end
end

--// Remove by slot (convenience wrapper)
function RemoveOperation.ExecuteBySlot(state: any, slotType: string, slot: number, amount: number?): RemoveResult
	local uuid = SlotManager.GetUUIDFromSlot(state, slotType, slot)
	if not uuid then
		return { success = false, reason = "SLOT_EMPTY" }
	end
	return RemoveOperation.Execute(state, uuid, amount)
end

return RemoveOperation
