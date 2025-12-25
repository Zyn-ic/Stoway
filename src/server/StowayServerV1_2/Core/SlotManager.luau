-- src/server/StowayServerV1.2/Core/SlotManager.luau
-- Single source of truth for slot-level operations (Static Hotbar / Dynamic Storage)
-- Uses state.Settings (per-player) instead of global Settings

local SlotManager = {}

--// ═══════════════════════════════════════════════════════════════════════════
--// HOTBAR (Static Logic)
--// ═══════════════════════════════════════════════════════════════════════════

function SlotManager.SetHotbarSlot(state: any, slot: number, uuid: string)
	state.Hotbar[slot] = uuid
end

function SlotManager.ClearHotbarSlot(state: any, slot: number)
	
	state.Hotbar[slot] = nil -- Hole preserved (Static)
end

function SlotManager.FindEmptyHotbarSlot(state: any): number?
	local maxSlots = state.Settings.MaxHotbarSlots
	for i = 1, maxSlots do
		if not state.Hotbar[i] then
			return i
		end
	end
	return nil
end

function SlotManager.GetHotbarItemCount(state: any): number
	local count = 0
	local maxSlots = state.Settings.MaxHotbarSlots
	for i = 1, maxSlots do
		if state.Hotbar[i] then
			count += 1
		end
	end
	return count
end

--// ═══════════════════════════════════════════════════════════════════════════
--// STORAGE (Dynamic Logic)
--// ═══════════════════════════════════════════════════════════════════════════

function SlotManager.AppendStorage(state: any, uuid: string)
	table.insert(state.Storage, uuid)
end

function SlotManager.RemoveStorageAt(state: any, index: number)
	table.remove(state.Storage, index) -- Shifts items up (Dynamic)
end

function SlotManager.SwapStorageIndices(state: any, i: number, j: number)
	state.Storage[i], state.Storage[j] = state.Storage[j], state.Storage[i]
end

function SlotManager.GetStorageItemCount(state: any): number
	return #state.Storage
end

--// ═══════════════════════════════════════════════════════════════════════════
--// UTILITY
--// ═══════════════════════════════════════════════════════════════════════════

function SlotManager.FindSlotByUUID(state: any, uuid: string): (string?, number?)
	-- Check Hotbar
	for i, v in state.Hotbar do
		if v == uuid then
			return "Hotbar", i
		end
	end
	
	-- Check Storage
	for i, v in state.Storage do
		if v == uuid then
			return "Storage", i
		end
	end
	
	return nil, nil
end

function SlotManager.GetUUIDFromSlot(state: any, slotType: string, slot: number): string?
	if slotType == "Hotbar" then
		return state.Hotbar[slot]
	elseif slotType == "Storage" then
		return state.Storage[slot]
	end
	return nil
end

return SlotManager
