-- src/server/StowayServerV1.2/Core/SlotManager.luau
-- Single source of truth for slot-level operations (Static Hotbar / Dynamic Storage)
-- Uses state.Settings (per-player) instead of global Settings

local SlotManager = {}
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Settings = require(ReplicatedStorage.Shared.Settings)

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

function SlotManager.IsDynamicHotbarEnabled(): boolean
	return Settings.Hotbar.Type == "Dynamic"
end

-- Dynamic hotbar keeps server slot data packed (no holes) while preserving item order.
function SlotManager.CompactHotbar(state: any): boolean
	if not SlotManager.IsDynamicHotbarEnabled() then
		return false
	end

	local maxSlots = state.Settings.MaxHotbarSlots
	local writeIndex = 1
	local changed = false
	local packedHotbar = {}

	for readIndex = 1, maxSlots do
		local uuid = state.Hotbar[readIndex]
		if uuid then
			if readIndex ~= writeIndex then
				changed = true
			end
			packedHotbar[writeIndex] = uuid
			writeIndex += 1
		end
	end

	if changed then
		state.Hotbar = packedHotbar
	end

	return changed
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
