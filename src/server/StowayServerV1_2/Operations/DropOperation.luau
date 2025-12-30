-- src/server/StowayServerV1.2/Operations/DropOperation.luau
-- Handles Drop logic: If equipped → Unequip → Remove from inventory → Spawn in world

local DropOperation = {}

local SlotManager = require(script.Parent.Parent.Core.SlotManager)
local RemoveOperation = require(script.Parent.RemoveOperation)
local EquipOperation = require(script.Parent.EquipOperation)
local ItemSpawner = require(script.Parent.Parent.World.ItemSpawner)

export type DropResult = {
	success: boolean,
	reason: string?,
	droppedItem: any?,
	remaining: number?,
	UUID: string?
}

--// Main Execute function
function DropOperation.Execute(state: any, player: Player, slotType: string, slot: number, amount: number?): DropResult
	-- Get item
	local uuid = SlotManager.GetUUIDFromSlot(state, slotType, slot)
	if not uuid then
		return { success = false, reason = "SLOT_EMPTY" }
	end
	
	local item = state.Items[uuid]
	if not item then
		return { success = false, reason = "ITEM_NOT_FOUND" }
	end

	if not state.Settings.Droppable then
		return { success = false, reason = "INVENTORY_NOT_Droppable" }
	end

	if not item.Metadata.Droppable then
		return { success = false, reason = "ITEM_NOT_Droppable" }
	end
	
	-- Cache item data before removal
	local itemId = item.Id
	local itemAmount = item.Amount
	local itemMetadata = item.Metadata
	local dropAmount = amount or itemAmount

	if dropAmount > itemAmount then dropAmount = itemAmount end
	if dropAmount <= 0 then return {success = false, reason = "INVALID_AMOUNT"} end
	
	-- If equipped, unequip first (per spec: equipped items go through unequip flow)
	-- Only unequip if we are dropping the WHOLE item (or at least, the amount that exists)
	if state.EquippedItemUUID == uuid and (itemAmount - dropAmount) <= 0 then
		EquipOperation.Unequip(state, player)
	end
	
	-- Remove from inventory
	local removeResult = RemoveOperation.Execute(state, uuid, dropAmount)
	if not removeResult.success then
		return { success = false, reason = removeResult.reason }
	end
	
	-- Spawn in world
	ItemSpawner.DropTool(player, itemId, dropAmount, itemMetadata)
	
	return { 
		success = true, 
		droppedItem = {
			Id = itemId,
			Amount = dropAmount,
			Metadata = itemMetadata
		},
		remaining = removeResult.remaining,
		UUID = uuid
	}
end

return DropOperation
