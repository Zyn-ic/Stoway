-- src/server/StowayServerV1.2/Operations/EquipOperation.luau
-- Handles Equip/Unequip logic

local EquipOperation = {}

local SlotManager = require(script.Parent.Parent.Core.SlotManager)
local ItemSpawner = require(script.Parent.Parent.World.ItemSpawner)

export type EquipResult = {
	success: boolean,
	reason: string?,
	previousUUID: string?,
	currentUUID: string?
}

--// Equip item by UUID
function EquipOperation.Equip(state: any, player: Player, uuid: string): EquipResult
	local item = state.Items[uuid]
	if not item then
		return { success = false, reason = "ITEM_NOT_FOUND" }
	end
	
	local previousUUID = state.EquippedItemUUID
	
	-- Unequip current if different
	if previousUUID and previousUUID ~= uuid then
		EquipOperation.Unequip(state, player)
	end
	
	-- Set equipped
	state.EquippedItemUUID = uuid
	
	-- Spawn physical tool
	ItemSpawner.SpawnTool(player, item.Id, item.Metadata)
	
	return { success = true, previousUUID = previousUUID, currentUUID = uuid }
end

--// Equip by slot
function EquipOperation.EquipBySlot(state: any, player: Player, slotType: string, slot: number): EquipResult
	local uuid = SlotManager.GetUUIDFromSlot(state, slotType, slot)
	if not uuid then
		return { success = false, reason = "SLOT_EMPTY" }
	end
	return EquipOperation.Equip(state, player, uuid)
end

--// Unequip current item
function EquipOperation.Unequip(state: any, player: Player): EquipResult
	if not state.EquippedItemUUID then
		return { success = false, reason = "NOTHING_EQUIPPED" }
	end
	
	local previousUUID = state.EquippedItemUUID
	
	-- Clear equipped state
	state.EquippedItemUUID = nil
	
	-- Despawn physical tool
	local char = player.Character
	if char then
		local tool = char:FindFirstChildOfClass("Tool")
		if tool then
			ItemSpawner.DespawnTool(player, tool)
		end
	end
	
	return { success = true, previousUUID = previousUUID, currentUUID = nil }
end

--// Check if currently equipped item is valid, cleanup if not
function EquipOperation.ValidateEquipped(state: any, player: Player): boolean
	if not state.EquippedItemUUID then
		return true -- Nothing equipped is valid
	end
	
	local item = state.Items[state.EquippedItemUUID]
	if not item then
		-- Equipped item no longer exists, cleanup
		state.EquippedItemUUID = nil
		local char = player.Character
		if char then
			local tool = char:FindFirstChildOfClass("Tool")
			if tool then tool:Destroy() end
		end
		return false
	end
	
	return true
end

return EquipOperation
