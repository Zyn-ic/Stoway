-- src/server/StowayServerV1.2/Operations/SwapOperation.luau
-- Handles full Swap logic flow: Validate → Execute (preserve equipped) → Return delta
-- Uses state.Settings (per-player) for bounds checking

local SwapOperation = {}

local SlotManager = require(script.Parent.Parent.Core.SlotManager)

export type SlotRef = {
	type: "Hotbar" | "Storage",
	slot: number
}

export type SwapResult = {
	success: boolean,
	reason: string?
}

--// Validate swap request
local function ValidateSwap(state: any, from: SlotRef, to: SlotRef): (boolean, string?)
	local maxHotbar = state.Settings.MaxHotbarSlots
	
	-- Validate Hotbar bounds
	if from.type == "Hotbar" then
		if from.slot < 1 or from.slot > maxHotbar then
			return false, "INVALID_FROM_SLOT"
		end
	end
	
	if to.type == "Hotbar" then
		if to.slot < 1 or to.slot > maxHotbar then
			return false, "INVALID_TO_SLOT"
		end
	end
	
	-- Storage source MUST exist (can't swap from nothing)
	if from.type == "Storage" then
		if not state.Storage[from.slot] then
			return false, "FROM_SLOT_EMPTY"
		end
	end
	
	return true, nil
end

--// Main Execute function
function SwapOperation.Execute(state: any, from: SlotRef, to: SlotRef): SwapResult
	-- Validate
	local valid, reason = ValidateSwap(state, from, to)
	if not valid then
		return { success = false, reason = reason }
	end
	
	-- Get items
	local fromUUID = SlotManager.GetUUIDFromSlot(state, from.type, from.slot)
	local toUUID = SlotManager.GetUUIDFromSlot(state, to.type, to.slot)
	print(toUUID, fromUUID)
	
	-- Execute based on combination
	if from.type == "Hotbar" and to.type == "Hotbar" then
		-- Static ↔ Static: Simple swap (holes preserved)
		state.Hotbar[from.slot] = toUUID
		state.Hotbar[to.slot] = fromUUID
		
	elseif from.type == "Storage" and to.type == "Storage" then
		-- Dynamic ↔ Dynamic: Reorder (both must exist or we'd error above)
		state.Storage[from.slot] = toUUID
		state.Storage[to.slot] = fromUUID
		
	elseif from.type == "Hotbar" and to.type == "Storage" then
		-- Hotbar → Storage
		if toUUID then
			print(toUUID, fromUUID)
			-- Both exist: Swap
			state.Hotbar[from.slot] = toUUID
			state.Storage[to.slot] = fromUUID
		else
			-- Storage slot empty: Append to storage
			if fromUUID then
				print(toUUID, fromUUID)
				table.insert(state.Storage, fromUUID)
				state.Hotbar[from.slot] = nil
			end
		end
		
	elseif from.type == "Storage" and to.type == "Hotbar" then
		-- Storage → Hotbar
		if toUUID then
			-- Both exist: Swap
			state.Storage[from.slot] = toUUID
			state.Hotbar[to.slot] = fromUUID
		else
			-- Hotbar slot empty: Move & shift storage
			state.Hotbar[to.slot] = fromUUID
			table.remove(state.Storage, from.slot)
		end
    else
        return { success = false, reason = "INVALID_SLOT_TYPE_COMBINATION" }
	end
	
	-- Note: EquippedItemUUID doesn't change - it follows the UUID, not the slot
	return { success = true }
end

--// Convenience wrapper with raw parameters
function SwapOperation.ExecuteRaw(state: any, fromType: string, fromSlot: number, toType: string, toSlot: number): SwapResult
	return SwapOperation.Execute(state, 
		{ type = fromType :: "Hotbar" | "Storage", slot = fromSlot },
		{ type = toType :: "Hotbar" | "Storage", slot = toSlot }
	)
end

return SwapOperation
