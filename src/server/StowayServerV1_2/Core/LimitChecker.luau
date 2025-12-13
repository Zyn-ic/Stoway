-- src/server/StowayServerV1.2/Core/LimitChecker.luau
-- Pre-operation validation for inventory weight/limit (Amount-based)
-- Uses state.Settings (per-player) instead of global Settings
-- Limit = 0 means INFINITE (no weight checking)

local LimitChecker = {}

local SlotManager = require(script.Parent.SlotManager)

--// Check if weight system is enabled (Limit > 0)
function LimitChecker.IsEnabled(state: any): boolean
	return (state.Settings.Limit or 0) > 0
end

--// Get total weight (sum of all item amounts)
function LimitChecker.GetCurrentWeight(state: any): number
	return state.Weight or 0
end

--// Get remaining capacity (returns math.huge if Limit = 0)
function LimitChecker.GetRemainingCapacity(state: any): number
	if not LimitChecker.IsEnabled(state) then
		return math.huge -- Infinite
	end
	return math.max(0, state.Settings.Limit - LimitChecker.GetCurrentWeight(state))
end

--// Check if we can add amount to inventory
function LimitChecker.CanAddAmount(state: any, amount: number): boolean
	if not LimitChecker.IsEnabled(state) then
		return true -- No limit, always allowed
	end
	return LimitChecker.GetRemainingCapacity(state) >= amount
end

--// Check if inventory is completely full
function LimitChecker.IsFull(state: any): boolean
	if not LimitChecker.IsEnabled(state) then
		return false -- Never full if infinite
	end
	return LimitChecker.GetRemainingCapacity(state) == 0
end

--// Check if hotbar has space (for slot placement)
function LimitChecker.HasHotbarSpace(state: any): boolean
	return SlotManager.FindEmptyHotbarSlot(state) ~= nil
end

--// Add weight (call after adding items) - always track for stats
function LimitChecker.AddWeight(state: any, amount: number)
	state.Weight = (state.Weight or 0) + amount
end

--// Remove weight (call after removing items) - always track for stats
function LimitChecker.RemoveWeight(state: any, amount: number)
	state.Weight = math.max(0, (state.Weight or 0) - amount)
end

return LimitChecker


