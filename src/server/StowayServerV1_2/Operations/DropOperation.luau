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
	droppedItem: any?
}

--// Main Execute function
function DropOperation.Execute(state: any, player: Player, slotType: string, slot: number): DropResult
	-- Get item
	local uuid = SlotManager.GetUUIDFromSlot(state, slotType, slot)
	if not uuid then
		return { success = false, reason = "SLOT_EMPTY" }
	end
	
	local item = state.Items[uuid]
	if not item then
		return { success = false, reason = "ITEM_NOT_FOUND" }
	end

	if not state.Droppable then
		return { success = false, reason = "INVENTORY_NOT_Droppable" }
	end

	if not item.Metadata.Droppable then
		return { success = false, reason = "ITEM_NOT_Droppable" }
	end
	
	-- Cache item data before removal
	local itemId = item.Id
	local itemAmount = item.Amount
	local itemMetadata = item.Metadata
	
	-- If equipped, unequip first (per spec: equipped items go through unequip flow)
	if state.EquippedItemUUID == uuid then
		EquipOperation.Unequip(state, player)
	end
	
	-- Remove from inventory
	local removeResult = RemoveOperation.Execute(state, uuid, itemAmount)
	if not removeResult.success then
		return { success = false, reason = removeResult.reason }
	end
	
	-- Spawn in world
	ItemSpawner.DropTool(player, itemId, itemAmount, itemMetadata)
	
	return { 
		success = true, 
		droppedItem = {
			Id = itemId,
			Amount = itemAmount,
			Metadata = itemMetadata
		}
	}
end

return DropOperation
