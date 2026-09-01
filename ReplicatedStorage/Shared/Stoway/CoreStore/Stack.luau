--!native
--@author: yyumchi
--@date: 2026-06-24
--[[@description:
	Stacking logic - determines if items can stack and manages stack operations
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Types = require("./Types")
local Metadata = require("./Metadata")
local State = require("./State")

local Stack = {}

-----------------------------
-- CONSTANTS --
-----------------------------

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-- PUBLIC FUNCTIONS --
-----------------------------

-- Checks if an incoming item can stack onto an existing item.
-- 5 conditions that must ALL pass:
--   1. CanStack setting is true
--   2. Same ItemId
--   3. Existing item not at MaxStackSize
--   4. Neither item has a blacklisted rarity
--   5. Required fields match (default: Rarity and Type must be equal)
function Stack.canStack(
	state: Types.InventoryState,
	existingItem: Types.Item,
	incomingItemId: string,
	incomingMetadata: Types.ItemMetadata
): boolean
	local settings = state.Settings

	if not settings.CanStack then
		return false
	end

	if existingItem.Id ~= incomingItemId then
		return false
	end

	if existingItem.Amount >= settings.MaxStackSize then
		return false
	end

	if Metadata.isBlacklisted(existingItem.Metadata, settings.StackBlacklist) then
		return false
	end

	if Metadata.isBlacklisted(incomingMetadata, settings.StackBlacklist) then
		return false
	end

	return Metadata.matchesRequiredFields(
		existingItem.Metadata,
		incomingMetadata,
		settings.StackRequiredFields
	)
end

-- Attempts to stack an incoming amount into existing stacks of the same ItemId.
--
-- Returns: (stackedAmount, updates)
--   stackedAmount: how much was absorbed into existing stacks
--   updates: { [uuid] = newAmount } for each stack that was modified
--
-- Placement filter: if placement is "Hotbar", only stacks into hotbar items.
-- If placement is "Backpack", only stacks into storage items. "Auto" stacks anywhere.
--
-- Example: tryStack(state, "Sword", 3, metadata)
--   Existing: Sword x2 in Hotbar[1], Sword x4 in Storage[1], MaxStackSize = 5
--   Iteration 1: Sword x2 -> room = 3, stacks 2, amount left = 1
--   Iteration 2: Sword x4 -> room = 1, stacks 1, amount left = 0
--   Returns: (3, { ["uuid-hotbar"] = 4, ["uuid-storage"] = 5 })
function Stack.tryStack(
	state: Types.InventoryState,
	itemId: string,
	amount: number,
	metadata: Types.ItemMetadata,
	placement: Types.PlacementMode?
): (number, { [string]: number })
	local stackedAmount = 0
	local updates: { [string]: number } = {}

	local uuids = state.ItemsByID[itemId]

	if not uuids then
		return stackedAmount, updates
	end

	local maxStackSize = state.Settings.MaxStackSize

	for _, uuid in ipairs(uuids) do
		if amount <= 0 then
			break
		end

		-- Placement filter: skip items not in the target container
		if placement and placement ~= "Auto" then
			local loc = state.LocationByUUID[uuid]
			local matchesPlacement = (placement == "Backpack" and loc and loc.Type == "Storage")
				or (placement == "Hotbar" and loc and loc.Type == "Hotbar")
			if not matchesPlacement then
				continue
			end
		end

		local existingItem = state.Items[uuid]

		if existingItem and Stack.canStack(state, existingItem, itemId, metadata) then
			local room = maxStackSize - existingItem.Amount
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
