--@author: yyumchi
--@date: 2026-06-24
--[[@description:
	Stacking logic - determines if items can stack and manages stack operations
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Types = require("../CoreStore/Types")
local Metadata = require("../CoreStore/Metadata")
local State = require("../CoreStore/State")

local Stack = {}

-- CONSTANTS --
-----------------------------

-- PRIVATE FUNCTIONS --
-----------------------------

-- PUBLIC FUNCTIONS --
-----------------------------

function Stack.canStack(
	state: Types.InventoryState,
	existingItem: Types.Item,
	incomingItemId: string,
	incomingMetadata: Types.ItemMetadata
): boolean
	if not state.Settings.CanStack then
		return false
	end

	if existingItem.Id ~= incomingItemId then
		return false
	end

	if existingItem.Amount >= state.Settings.MaxStackSize then
		return false
	end

	if Metadata.isBlacklisted(existingItem.Metadata, state.Settings.StackBlacklist) then
		return false
	end

	if Metadata.isBlacklisted(incomingMetadata, state.Settings.StackBlacklist) then
		return false
	end

	return Metadata.matchesRequiredFields(
		existingItem.Metadata,
		incomingMetadata,
		state.Settings.StackRequiredFields
	)
end

function Stack.tryStack(
	state: Types.InventoryState,
	itemId: string,
	amount: number,
	metadata: Types.ItemMetadata
): (number, { number })
	local stackedAmount = 0
	local updates: { number } = {}

	local uuids = state.ItemsByID[itemId]

	if not uuids then
		return stackedAmount, updates
	end

	for _, uuid in ipairs(uuids) do
		if amount <= 0 then
			break
		end

		local existingItem = state.Items[uuid]

		if existingItem and Stack.canStack(state, existingItem, itemId, metadata) then
			local room = state.Settings.MaxStackSize - existingItem.Amount
			local toStack = math.min(room, amount)

			if toStack > 0 then
				existingItem.Amount += toStack
				amount -= toStack
				stackedAmount += toStack
				updates[uuid] = existingItem.Amount

				State.addWeight(state, toStack)
			end
		end
	end

	return stackedAmount, updates
end

-----------------------------
--MAIN--
-----------------------------

return Stack
