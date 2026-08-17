--!native

--@author: yyumchi
--@date: 2026-06-24
--[[@description:
	Core inventory operations - add, remove, swap, move, split, sort
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Result = require(ReplicatedStorage.Shared.Types.Result)
local Types = require("./Types")
local Metadata = require("./Metadata")
local Slots = require("./Slots")
local Stack = require("./Stack")
local State = require("./State")
local Utils = require("./Utils")

local Operations = {}

local EK = Result.ErrorKind

-----------------------------
-- CONSTANTS --
-----------------------------

-- These fields get a reverse index in MetadataIndex for O(1) bucket lookups.
-- Example: MetadataIndex["Rarity"]["Legendary"] = { "uuid-1", "uuid-5" }
local INDEXED_METADATA_FIELDS: { string } = { "Rarity", "Type" }

-- Sentinel for deleting a metadata field. Lua tables can never hold a nil
-- value, so updateMetadata accepts this unique string as a "remove this key"
-- marker. It is namespaced aggressively to avoid colliding with a real value.
local METADATA_DELETE = "__STOWAY_DELETE__"
Operations.METADATA_DELETE = METADATA_DELETE

-- Maps reason strings to Error objects for the Result type.
local REASON_TO_KIND: { [string]: Result.ErrorKind } = {
	BACKPACK_DISABLED = EK.PermissionDenied,
	NOT_DROPPABLE = EK.PermissionDenied,
	INVALID_HOTBAR_SLOT = EK.InvalidArgument,
	INVALID_STORAGE_SLOT = EK.InvalidArgument,
	INVALID_AMOUNT = EK.InvalidArgument,
	INVALID_ITEM_DATA = EK.InvalidArgument,
	INVALID_SLOT = EK.InvalidArgument,
	INVALID_PLACEMENT = EK.InvalidArgument,
	ITEM_NOT_IN_TOOLS_FOLDER = EK.InvalidArgument,
	INVALID_ITEM_ID = EK.InvalidArgument,
	CANNOT_SPLIT_FULL = EK.InvalidArgument,
	ITEM_NOT_FOUND = EK.NotFound,
	NO_STATE = EK.NotFound,
	SOURCE_EMPTY = EK.NotFound,
	SLOT_EMPTY = EK.NotFound,
	FULL = EK.NotAvailable,
	HOTBAR_FULL = EK.NotAvailable,
	HOTBAR_SLOT_OCCUPIED = EK.NotAvailable,
	DESTINATION_OCCUPIED = EK.NotAvailable,
	DESTINATION_UNAVAILABLE = EK.NotAvailable,
	OPERATION_IN_PROGRESS = EK.NotAvailable,
	NO_SPACE = EK.NotAvailable,
	ADD_FAILED = EK.NotAvailable,
}

local function Err(reason: string): { ok: false, error: Result.Error }
	return Result.Err({ kind = REASON_TO_KIND[reason] or EK.InvalidArgument, message = reason })
end

-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------

-- Adds a UUID to the ItemsByID reverse index.
-- ItemsByID lets you find all UUIDs for a given ItemId without scanning all items.
-- Example: ItemsByID["Sword"] = { "uuid-1", "uuid-3" }
local function addToIndex(state: Types.InventoryState, itemId: string, uuid: string)
	if not state.ItemsByID[itemId] then
		state.ItemsByID[itemId] = {}
	end

	table.insert(state.ItemsByID[itemId], uuid)
end

-- Removes a UUID from the ItemsByID reverse index.
-- Cleans up the bucket entirely if it becomes empty.
local function removeFromIndex(state: Types.InventoryState, itemId: string, uuid: string)
	local uuids = state.ItemsByID[itemId]

	if not uuids then
		return
	end

	local index = table.find(uuids, uuid)
	if index then
		table.remove(uuids, index)
	end

	if #uuids == 0 then
		state.ItemsByID[itemId] = nil
	end
end

-- Inserts a UUID into the MetadataIndex for each indexed field.
-- MetadataIndex is a 3-level nested table: field -> stringValue -> UUID array.
-- Example:
--   MetadataIndex["Rarity"]["Legendary"] = { "uuid-1", "uuid-5" }
--   MetadataIndex["Type"]["Weapon"] = { "uuid-1", "uuid-3", "uuid-7" }
local function addToMetadataIndex(state: Types.InventoryState, uuid: string, metadata: Types.ItemMetadata)
	for _, field in INDEXED_METADATA_FIELDS do
		local value = metadata[field]

		if value ~= nil then
			local strValue = tostring(value)

			if not state.MetadataIndex[field] then
				state.MetadataIndex[field] = {}
			end
			if not state.MetadataIndex[field][strValue] then
				state.MetadataIndex[field][strValue] = {}
			end

			table.insert(state.MetadataIndex[field][strValue], uuid)
		end
	end
end

-- Removes a UUID from the MetadataIndex for each indexed field.
-- Cleans up empty buckets to avoid memory leaks.
local function removeFromMetadataIndex(state: Types.InventoryState, uuid: string, metadata: Types.ItemMetadata)
	for _, field in INDEXED_METADATA_FIELDS do
		local value = metadata[field]

		if value ~= nil then
			local strValue = tostring(value)
			local bucket = state.MetadataIndex[field] and state.MetadataIndex[field][strValue]

			if bucket then
				local index = table.find(bucket, uuid)
				if index then
					table.remove(bucket, index)
				end
				if #bucket == 0 then
					state.MetadataIndex[field][strValue] = nil
				end
			end
		end
	end
end

-- Moves a UUID between MetadataIndex buckets when metadata changes.
-- Removes from the old bucket, inserts into the new bucket.
-- Example: Rarity changed from "Common" to "Legendary"
--   Removes uuid from MetadataIndex["Rarity"]["Common"]
--   Inserts uuid into MetadataIndex["Rarity"]["Legendary"]
local function updateMetadataIndex(state: Types.InventoryState, uuid: string, oldMetadata: Types.ItemMetadata, newMetadata: Types.ItemMetadata)
	for _, field in INDEXED_METADATA_FIELDS do
		local oldValue = oldMetadata[field]
		local newValue = newMetadata[field]

		if oldValue ~= newValue then
			-- Remove from old bucket
			if oldValue ~= nil then
				local strValue = tostring(oldValue)
				local bucket = state.MetadataIndex[field] and state.MetadataIndex[field][strValue]
				if bucket then
					local index = table.find(bucket, uuid)
					if index then
						table.remove(bucket, index)
					end
					if #bucket == 0 then
						state.MetadataIndex[field][strValue] = nil
					end
				end
			end

			-- Insert into new bucket
			if newValue ~= nil then
				local strValue = tostring(newValue)
				if not state.MetadataIndex[field] then
					state.MetadataIndex[field] = {}
				end
				if not state.MetadataIndex[field][strValue] then
					state.MetadataIndex[field][strValue] = {}
				end
				table.insert(state.MetadataIndex[field][strValue], uuid)
			end
		end
	end
end

-- Creates a new item and registers it across all lookup tables.
-- Touches: Items, ItemsByID, MetadataIndex, Weight.
-- Amount is capped at MaxStackSize unconditionally.
local function createItem(
	state: Types.InventoryState,
	itemId: string,
	amount: number,
	metadata: Types.ItemMetadata
): Types.Item
	local uuid = Utils.generateUUID()
	local finalAmount = math.min(amount, state.Settings.MaxStackSize)

	local item: Types.Item = {
		UUID = uuid,
		Id = itemId,
		Amount = finalAmount,
		Metadata = Utils.deepCopy(metadata) :: Types.ItemMetadata,
	}

	state.Items[uuid] = item
	addToIndex(state, itemId, uuid)
	addToMetadataIndex(state, uuid, item.Metadata)
	State.addWeight(state, finalAmount)

	return item
end

-- Rolls back an item that failed to place (no room in hotbar or storage).
-- Removes from all 4 tables: Items, LocationByUUID, ItemsByID, MetadataIndex.
-- Also subtracts weight. Used when addNewStacks hits a wall mid-loop.
local function destroyUnplacedItem(state: Types.InventoryState, item: Types.Item)
	state.Items[item.UUID] = nil
	state.LocationByUUID[item.UUID] = nil

	removeFromIndex(state, item.Id, item.UUID)
	removeFromMetadataIndex(state, item.UUID, item.Metadata)
	State.removeWeight(state, item.Amount)
end

-- Places an item into the hotbar.
-- Static mode: preferred slot first (if valid and empty), then scan for first nil.
-- Dynamic mode: preferred slot is ignored, always appends to end.
-- Returns (slot, nil) on success or (nil, reason) on failure.
local function placeItemInHotbar(
	state: Types.InventoryState,
	item: Types.Item,
	preferredSlot: number?
): (number?, string?)
	if preferredSlot and state.Settings.HotbarType ~= "Dynamic" then
		if not Slots.isValidHotbarSlot(state, preferredSlot) then
			return nil, "INVALID_HOTBAR_SLOT"
		end

		if state.Hotbar[preferredSlot] then
			return nil, "HOTBAR_SLOT_OCCUPIED"
		end

		Slots.setHotbarSlot(state, preferredSlot, item.UUID)
		return preferredSlot, nil
	end

	local slot = Slots.findEmptyHotbarSlot(state)

	if not slot then
		return nil, "HOTBAR_FULL"
	end

	Slots.setHotbarSlot(state, slot, item.UUID)
	return slot, nil
end

-- Places an item into storage (appends to end).
-- Returns (slot, nil) on success or (nil, reason) if backpack is disabled.
local function placeItemInStorage(state: Types.InventoryState, item: Types.Item): (number?, string?)
	if not state.Settings.BackpackEnabled then
		return nil, "BACKPACK_DISABLED"
	end

	local slot = Slots.appendStorage(state, item.UUID)
	return slot, nil
end

-- Creates and places new stacks in a loop until amountLeft = 0 or overflow.
--
-- Flow for each iteration:
--   1. createItem (capped at MaxStackSize)
--   2. Place via placement chain: Backpack -> Hotbar -> Auto (hotbar first, then storage)
--   3. If placement fails: destroyUnplacedItem (rollback), return overflow
--   4. If success: record AddedSlot, subtract from remaining, loop again
--
-- Example: Add Apple x12, MaxStackSize = 5, Capacity = 10
--   Iteration 1: createItem(5) -> placed in Hotbar[1], remaining = 7
--   Iteration 2: createItem(5) -> placed in Storage[1], remaining = 2
--   Iteration 3: createItem(2) -> no room -> destroyUnplacedItem, return overflow = 2
local function addNewStacks(
	state: Types.InventoryState,
	itemId: string,
	amount: number,
	metadata: Types.ItemMetadata,
	options: Types.AddOptions
): ({ Types.AddedSlot }, number, string?)
	local addedItems: { Types.AddedSlot } = {}
	local remaining = amount

	while remaining > 0 do
		local item = createItem(state, itemId, remaining, metadata)

		local placed = false
		local slotType: Types.SlotType? = nil
		local slot: number? = nil
		local reason: string? = nil

		local placement = options.Placement or "Auto"

		if placement == "Backpack" then
			-- Storage only — skip hotbar stacking entirely
			slot, reason = placeItemInStorage(state, item)

			if slot then
				slotType = "Storage"
				placed = true
			end
		elseif placement == "Hotbar" then
			-- Hotbar only — preferred slot (Static) or append (Dynamic)
			slot, reason = placeItemInHotbar(state, item, options.Slot)

			if slot then
				slotType = "Hotbar"
				placed = true
			end
		elseif placement == "Slot" and options.SlotRef then
			-- Exact slot placement — must be empty
			local slotRef = options.SlotRef

			if slotRef.Type == "Hotbar" then
				if Slots.isValidHotbarSlot(state, slotRef.Slot) and not state.Hotbar[slotRef.Slot] then
					Slots.setHotbarSlot(state, slotRef.Slot, item.UUID)
					slotType = "Hotbar"
					slot = slotRef.Slot
					placed = true
				else
					reason = "INVALID_SLOT"
				end
			elseif slotRef.Type == "Storage" then
				if state.Settings.BackpackEnabled then
					if slotRef.Slot >= 1 and slotRef.Slot <= #state.Storage + 1 then
						Slots.moveToStorage(state, item.UUID, slotRef.Slot)
						slotType = "Storage"
						slot = slotRef.Slot
						placed = true
					else
						reason = "INVALID_SLOT"
					end
				else
					reason = "BACKPACK_DISABLED"
				end
			else
				reason = "INVALID_SLOT"
			end
		elseif placement == "Auto" then
			-- Placement chain: Hotbar first, then Storage
			slot, reason = placeItemInHotbar(state, item, nil)

			if slot then
				slotType = "Hotbar"
				placed = true
			else
				slot, reason = placeItemInStorage(state, item)

				if slot then
					slotType = "Storage"
					placed = true
				end
			end
		else
			reason = "INVALID_PLACEMENT"
		end

		-- Placement failed — rollback this item and return what we added so far
		if not placed or not slotType or not slot then
			destroyUnplacedItem(state, item)
			return addedItems, remaining, reason
		end

		table.insert(addedItems, {
			uuid = item.UUID,
			slotType = slotType,
			slot = slot,
		})

		remaining -= item.Amount
	end

	return addedItems, 0, nil
end

-- PUBLIC FUNCTIONS --
-----------------------------

-- Adds item(s) to the inventory.
--
-- 3-step flow:
--   1. Normalize input (validate Id, extract Amount, default Metadata)
--   2. Try stacking into existing stacks (if CanStack = true)
--   3. Create new stacks for any remaining amount
--
-- Returns overflow if the total exceeds capacity.
function Operations.add(
	state: Types.InventoryState,
	itemData: Types.ItemInput,
	options: Types.AddOptions?
): Types.AddResult
	local opts: Types.AddOptions = options or {}

	-- Step 1: Normalize input
	local normResult = Metadata.normalize(itemData)

	if not normResult.ok then
		return Err(normResult.error.message)
	end

	local itemId = normResult.value.itemId
	local amount = normResult.value.amount
	local metadata = normResult.value.metadata

	local originalAmount = amount
	local remainingCapacity = State.getRemainingCapacity(state)

	if remainingCapacity <= 0 then
		return Result.Err({ kind = EK.NotAvailable, message = "FULL" })
	end

	-- Cap at remaining capacity — excess becomes overflow
	local amountToAdd = math.min(amount, remainingCapacity)
	local amountLeft = amountToAdd

	-- Step 2: Try stacking into existing stacks (reduces amountLeft)
	local updatedItems: { [string]: number } = {}

	if state.Settings.CanStack then
		local stackedAmount, updates = Stack.tryStack(state, itemId, amountLeft, metadata, opts.Placement)

		amountLeft -= stackedAmount
		updatedItems = updates
	end

	-- Step 3: Create new stacks for whatever didn't stack
	local addedItems: { Types.AddedSlot } = {}

	if amountLeft > 0 then
		local createdItems, leftover, placeReason = addNewStacks(
			state,
			itemId,
			amountLeft,
			metadata,
			opts
		)

		addedItems = createdItems
		amountLeft = leftover

		-- Nothing placed and nothing stacked — total failure
		if #addedItems == 0 and next(updatedItems) == nil then
			return Err(placeReason or "ADD_FAILED")
		end
	end

	local addedAmount = amountToAdd - amountLeft
	local overflow = originalAmount - addedAmount

	return Result.Ok({
		addedItems = addedItems,
		updatedItems = updatedItems,
		addedAmount = addedAmount,
		overflow = overflow,
	})
end

-- Removes an item (partial or full).
--
-- Partial: reduces Amount, item stays in place.
-- Full: destroys item from all tables (Items, LocationByUUID, ItemsByID,
--       MetadataIndex, EquippedItemUUID), clears slot, compacts hotbar in Dynamic.
function Operations.remove(
	state: Types.InventoryState,
	uuid: string,
	amount: number?
): Types.RemoveResult
	local item = state.Items[uuid]

	if not item then
		return Err("ITEM_NOT_FOUND")
	end

	local amountToRemove = amount or item.Amount

	if not Utils.isPositiveNumber(amountToRemove) then
		return Err("INVALID_AMOUNT")
	end

	amountToRemove = math.min(amountToRemove, item.Amount)

	local location = Slots.getLocation(state, uuid)
	local slotType = if location then location.Type else nil
	local slot = if location then location.Slot else nil

	-- Snapshot of what we're removing (returned to caller)
	local removedItem: Types.Item = {
		UUID = item.UUID,
		Id = item.Id,
		Amount = amountToRemove,
		Metadata = Utils.deepCopy(item.Metadata) :: Types.ItemMetadata,
	}

	-- Partial removal — item still has Amount > 0
	if item.Amount > amountToRemove then
		item.Amount -= amountToRemove
		State.removeWeight(state, amountToRemove)

		return Result.Ok({
			removedItem = removedItem,
			remaining = item.Amount,
			slotType = slotType,
			slot = slot,
		})
	end

	-- Full removal — destroy item from all tables
	State.removeWeight(state, item.Amount)

	state.Items[uuid] = nil
	state.LocationByUUID[uuid] = nil
	removeFromIndex(state, item.Id, uuid)
	removeFromMetadataIndex(state, uuid, item.Metadata)

	if state.EquippedItemUUID == uuid then
		state.EquippedItemUUID = nil
	end

	-- Clear the slot and compact if Dynamic hotbar
	if slotType == "Hotbar" and slot then
		Slots.clearHotbarSlot(state, slot)
		Slots.compactHotbar(state)
	elseif slotType == "Storage" and slot then
		Slots.removeStorageAt(state, slot)
	end

	return Result.Ok({
		removedItem = removedItem,
		remaining = 0,
		slotType = slotType,
		slot = slot,
	})
end

-- Swaps two slot positions. Handles 4 container combos:
--
--   Hotbar <-> Hotbar: exchange UUIDs in Hotbar table
--   Storage <-> Storage: exchange UUIDs in Storage array
--   Hotbar -> Storage: hotbar slot cleared, storage overwritten
--   Storage -> Hotbar: storage cleared (shifts left), hotbar overwritten
--
-- StackOnSwap path: if enabled and items can stack, source is absorbed
-- into destination stack. Source slot is destroyed on full absorption.
--
-- Dynamic Hotbar: H->H swap with empty dest is rejected (no holes allowed).
function Operations.swap(
	state: Types.InventoryState,
	fromRef: Types.SlotRef,
	toRef: Types.SlotRef
): Types.SwapResult
	if not state.Settings.BackpackEnabled then
		if fromRef.Type == "Storage" or toRef.Type == "Storage" then
			return Err("BACKPACK_DISABLED")
		end
	end

	if fromRef.Type == "Hotbar" then
		if not Slots.isValidHotbarSlot(state, fromRef.Slot) then
			return Err("INVALID_HOTBAR_SLOT")
		end
	end

	if toRef.Type == "Hotbar" then
		if not Slots.isValidHotbarSlot(state, toRef.Slot) then
			return Err("INVALID_HOTBAR_SLOT")
		end
	end

	if fromRef.Type == "Storage" then
		if not Slots.isValidStorageSlot(state, fromRef.Slot) then
			return Err("INVALID_STORAGE_SLOT")
		end
	end

	if toRef.Type == "Storage" then
		if toRef.Slot < 1 or toRef.Slot > #state.Storage + 1 then
			return Err("INVALID_STORAGE_SLOT")
		end
	end

	local fromUUID = Slots.getUUIDFromSlot(state, fromRef.Type, fromRef.Slot)
	local toUUID = Slots.getUUIDFromSlot(state, toRef.Type, toRef.Slot)

	if not fromUUID then
		return Err("SOURCE_EMPTY")
	end

	if fromUUID == toUUID then
		return Result.Ok({})
	end

	-- StackOnSwap: if both items can stack, absorb source into destination
	if toUUID and state.Settings.StackOnSwap and state.Settings.CanStack then
		local fromItem = state.Items[fromUUID]
		local toItem = state.Items[toUUID]

		if fromItem and toItem and Stack.canStack(state, toItem, fromItem.Id, fromItem.Metadata) then
			local room = state.Settings.MaxStackSize - toItem.Amount
			local transfer = math.min(fromItem.Amount, room)

			toItem.Amount += transfer
			fromItem.Amount -= transfer

			-- Source fully absorbed — destroy it
			if fromItem.Amount <= 0 then
				local loc = Slots.getLocation(state, fromUUID)
				state.Items[fromUUID] = nil
				state.LocationByUUID[fromUUID] = nil
				removeFromIndex(state, fromItem.Id, fromUUID)
				removeFromMetadataIndex(state, fromUUID, fromItem.Metadata)

				if loc and loc.Type == "Hotbar" then
					Slots.clearHotbarSlot(state, loc.Slot)
					Slots.compactHotbar(state)
				elseif loc and loc.Type == "Storage" then
					Slots.removeStorageAt(state, loc.Slot)
				end

				if state.EquippedItemUUID == fromUUID then
					state.EquippedItemUUID = nil
				end
			end

			return Result.Ok({})
		end
	end

	-- Dynamic Hotbar: reject swap to empty slot (no holes allowed)
	if fromRef.Type == "Hotbar" and toRef.Type == "Hotbar" then
		if state.Settings.HotbarType == "Dynamic" and not toUUID then
			return Err("DESTINATION_UNAVAILABLE")
		end
	end

	-- Positional swap — exchange UUIDs in both slots
	local hotbarCompacted = Slots.swapSlots(state, fromRef, toRef)

	-- Hotbar -> Storage (empty dest): clear old hotbar slot, compact if Dynamic
	if toRef.Type == "Storage" and not toUUID then
		local fromItem = state.Items[fromUUID]
		if fromItem then
			if fromRef.Type == "Hotbar" then
				Slots.clearHotbarSlot(state, fromRef.Slot)
				hotbarCompacted = Slots.compactHotbar(state)
			end
		end
	end

	-- Storage -> Hotbar (empty dest): swapSlots already moved the item into the
	-- hotbar; just collapse the storage hole left (INV-9 contiguity).
	if fromRef.Type == "Storage" and not toUUID then
		local fromItem = state.Items[fromUUID]
		if fromItem then
			Slots.removeStorageAt(state, fromRef.Slot)
		end
	end

	return Result.Ok({ hotbarCompacted = hotbarCompacted })
end

-- Explicit drag-and-drop stack operation. It deliberately delegates to swap so
-- StackOnSwap and CanStack remain the single source of truth for whether an
-- absorption may happen, while retaining swap's positional fallback behavior.
function Operations.swapStack(
	state: Types.InventoryState,
	fromRef: Types.SlotRef,
	toRef: Types.SlotRef
): Types.SwapResult
	return Operations.swap(state, fromRef, toRef)
end

-- Moves an item from one slot to another. Move is purely positional — never stacks.
--
-- 5 paths:
--   HH (Static): clear source, set dest, update LocationByUUID
--   HH (Dynamic): rejected (no empty slots in packed portion)
--   HS: clear source, append to storage, compact hotbar
--   SH: remove from storage, set hotbar slot. Dynamic: only if dest == append position
--   SS: reorder via moveWithinStorage (remove + insert at index)
function Operations.move(
	state: Types.InventoryState,
	fromRef: Types.SlotRef,
	toRef: Types.SlotRef
): Types.MoveResult
	if not state.Settings.BackpackEnabled then
		if fromRef.Type == "Storage" or toRef.Type == "Storage" then
			return Err("BACKPACK_DISABLED")
		end
	end

	if fromRef.Type == "Hotbar" then
		if not Slots.isValidHotbarSlot(state, fromRef.Slot) then
			return Err("INVALID_HOTBAR_SLOT")
		end
	end

	if toRef.Type == "Hotbar" then
		if not Slots.isValidHotbarSlot(state, toRef.Slot) then
			return Err("INVALID_HOTBAR_SLOT")
		end
	end

	if fromRef.Type == "Storage" then
		if not Slots.isValidStorageSlot(state, fromRef.Slot) then
			return Err("INVALID_STORAGE_SLOT")
		end
	end

	local fromUUID = Slots.getUUIDFromSlot(state, fromRef.Type, fromRef.Slot)
	if not fromUUID then
		return Err("SOURCE_EMPTY")
	end

	local toUUID = Slots.getUUIDFromSlot(state, toRef.Type, toRef.Slot)

	-- Storage -> Storage: reorder within the array
	if fromRef.Type == "Storage" and toRef.Type == "Storage" then
		if toRef.Slot < 1 or toRef.Slot > #state.Storage + 1 then
			return Err("INVALID_STORAGE_SLOT")
		end
		Slots.moveWithinStorage(state, fromRef.Slot, toRef.Slot)
		return Result.Ok({})
	end

	if toUUID then
		return Err("DESTINATION_OCCUPIED")
	end

	-- Hotbar -> Hotbar: Static allows, Dynamic rejects
	if fromRef.Type == "Hotbar" and toRef.Type == "Hotbar" then
		if state.Settings.HotbarType == "Dynamic" then
			return Err("DESTINATION_UNAVAILABLE")
		end
		state.Hotbar[fromRef.Slot] = nil
		state.Hotbar[toRef.Slot] = fromUUID
		state.LocationByUUID[fromUUID] = { Type = "Hotbar", Slot = toRef.Slot }
		return Result.Ok({})
	end

	-- Hotbar -> Storage: clear hotbar, append to storage, compact
	if fromRef.Type == "Hotbar" and toRef.Type == "Storage" then
		state.Hotbar[fromRef.Slot] = nil
		--[[local insertedSlot =]] Slots.appendStorage(state, fromUUID)
		local hotbarCompacted =    Slots.compactHotbar(state)
		return Result.Ok({ hotbarCompacted = hotbarCompacted })
	end

	-- Storage -> Hotbar: Dynamic only allows append position
	if fromRef.Type == "Storage" and toRef.Type == "Hotbar" then
		if state.Settings.HotbarType == "Dynamic" then
			local appendSlot = Slots.findEmptyHotbarSlot(state)
			if toRef.Slot ~= appendSlot then
				return Err("DESTINATION_UNAVAILABLE")
			end
		end
		Slots.removeStorageAt(state, fromRef.Slot)
		Slots.setHotbarSlot(state, toRef.Slot, fromUUID)
		return Result.Ok({})
	end

	return Err("INVALID_OPERATION")
end

-- Splits a stack into two. Source keeps its UUID (important if equipped).
--
-- Flow:
--   1. Validate (amount < source.Amount, positive number)
--   2. Cap splitAmount at MaxStackSize (excess stays in source)
--   3. Reduce source Amount, create new item
--   4. Place new item: destination slot if specified, else placement chain
--   5. On any failure: rollback (destroy new item, restore source Amount)
--
-- Rollback pattern (repeated in split):
--   delete Items[uuid], removeFromIndex, removeFromMetadataIndex,
--   removeWeight, item.Amount += splitAmount
function Operations.split(
	state: Types.InventoryState,
	uuid: string,
	amount: number,
	destination: Types.SlotRef?
): Types.SplitResult
	local item = state.Items[uuid]

	if not item then
		return Err("ITEM_NOT_FOUND")
	end

	if not Utils.isPositiveNumber(amount) then
		return Err("INVALID_AMOUNT")
	end

	if amount >= item.Amount then
		return Err("CANNOT_SPLIT_FULL")
	end

	-- Cap split amount at MaxStackSize. Excess stays in source.
	local splitAmount = math.min(amount, state.Settings.MaxStackSize)

	item.Amount -= splitAmount
	State.removeWeight(state, splitAmount)

	local newItem: Types.Item = {
		UUID = Utils.generateUUID(),
		Id = item.Id,
		Amount = splitAmount,
		Metadata = Utils.deepCopy(item.Metadata) :: Types.ItemMetadata,
	}

	state.Items[newItem.UUID] = newItem
	addToIndex(state, newItem.Id, newItem.UUID)
	addToMetadataIndex(state, newItem.UUID, newItem.Metadata)
	State.addWeight(state, splitAmount)

	local newSlotType: Types.SlotType? = nil
	local newSlot: number? = nil
	local hotbarCompacted = false

	if destination then
		-- Explicit destination — validate and place, or rollback
		if destination.Type == "Hotbar" then
			if not Slots.isValidHotbarSlot(state, destination.Slot) then
				state.Items[newItem.UUID] = nil
				removeFromMetadataIndex(state, newItem.UUID, newItem.Metadata)
				removeFromIndex(state, newItem.Id, newItem.UUID)
				State.removeWeight(state, splitAmount)
				item.Amount += splitAmount
				return Err("INVALID_HOTBAR_SLOT")
			end

			if state.Hotbar[destination.Slot] then
				state.Items[newItem.UUID] = nil
				removeFromMetadataIndex(state, newItem.UUID, newItem.Metadata)
				removeFromIndex(state, newItem.Id, newItem.UUID)
				State.removeWeight(state, splitAmount)
				item.Amount += splitAmount
				return Err("HOTBAR_SLOT_OCCUPIED")
			end

			-- Dynamic: only allow append position
			if state.Settings.HotbarType == "Dynamic" then
				local appendSlot = Slots.findEmptyHotbarSlot(state)
				if destination.Slot ~= appendSlot then
					state.Items[newItem.UUID] = nil
					removeFromMetadataIndex(state, newItem.UUID, newItem.Metadata)
					removeFromIndex(state, newItem.Id, newItem.UUID)
					State.removeWeight(state, splitAmount)
					item.Amount += splitAmount
					return Err("DESTINATION_UNAVAILABLE")
				end
			end

			Slots.setHotbarSlot(state, destination.Slot, newItem.UUID)
			newSlotType = "Hotbar"
			newSlot = destination.Slot
		elseif destination.Type == "Storage" then
			if not state.Settings.BackpackEnabled then
				state.Items[newItem.UUID] = nil
				removeFromMetadataIndex(state, newItem.UUID, newItem.Metadata)
				removeFromIndex(state, newItem.Id, newItem.UUID)
				State.removeWeight(state, splitAmount)
				item.Amount += splitAmount
				return Err("BACKPACK_DISABLED")
			end

			if not Slots.isValidStorageSlot(state, destination.Slot) then
				state.Items[newItem.UUID] = nil
				removeFromMetadataIndex(state, newItem.UUID, newItem.Metadata)
				removeFromIndex(state, newItem.Id, newItem.UUID)
				State.removeWeight(state, splitAmount)
				item.Amount += splitAmount
				return Err("INVALID_STORAGE_SLOT")
			end

			Slots.moveToStorage(state, newItem.UUID, destination.Slot)
			newSlotType = "Storage"
			newSlot = destination.Slot
		end
	else
		-- No destination — placement chain: Hotbar first, then Storage
		local slot = Slots.findEmptyHotbarSlot(state)
		if slot then
			Slots.setHotbarSlot(state, slot, newItem.UUID)
			newSlotType = "Hotbar"
			newSlot = slot
		elseif state.Settings.BackpackEnabled then
			Slots.appendStorage(state, newItem.UUID)
			newSlotType = "Storage"
			newSlot = #state.Storage
		else
			-- No room anywhere — rollback
			state.Items[newItem.UUID] = nil
			removeFromMetadataIndex(state, newItem.UUID, newItem.Metadata)
			removeFromIndex(state, newItem.Id, newItem.UUID)
			State.removeWeight(state, splitAmount)
			item.Amount += splitAmount
			return Err("NO_SPACE")
		end
	end

	return Result.Ok({
		sourceUUID = uuid,
		newUUID = newItem.UUID,
		sourceAmount = item.Amount,
		newAmount = splitAmount,
		newSlotType = newSlotType,
		newSlot = newSlot,
		hotbarCompacted = hotbarCompacted,
	})
end

-- Updates metadata fields on an item. All fields are mutable.
-- Nil values in updates delete the key. The MetadataIndex is maintained.
-- No auto re-stack occurs (metadata changes don't trigger stacking).
function Operations.updateMetadata(
	state: Types.InventoryState,
	uuid: string,
	updates: { [string]: any }
): Types.MetadataUpdateResult
	local item = state.Items[uuid]

	if not item then
		return Err("ITEM_NOT_FOUND")
	end

	local oldMetadata = table.clone(item.Metadata) :: Types.ItemMetadata
	local updatedFields: { string } = {}

	for key, value in updates do
		if value == METADATA_DELETE then
			item.Metadata[key] = nil
		else
			item.Metadata[key] = value
		end
		table.insert(updatedFields, key)
	end

	updateMetadataIndex(state, uuid, oldMetadata, item.Metadata)

	return Result.Ok({
		updatedFields = updatedFields,
	})
end

-- Sorts Storage only. Hotbar is never sorted (user-controlled).
-- Uses the SortOrder from Settings: Name, Rarity, or ItemType.
-- Rarity sorts descending (highest first). Ties broken alphabetically.
function Operations.sort(
	state: Types.InventoryState
): Types.SortResult
	local sortOrder = state.Settings.SortOrder

	if sortOrder == "None" then
		return Result.Ok({})
	end

	local storageChanged = Slots.sortStorage(state, sortOrder)

	return Result.Ok({
		storageOrder = if storageChanged then state.Storage else nil,
	})
end

-- Removes an item by slot reference. Delegates to Operations.remove after UUID lookup.
function Operations.removeBySlot(
	state: Types.InventoryState,
	slotType: Types.SlotType,
	slot: number,
	amount: number?
): Types.RemoveResult
	local uuid = Slots.getUUIDFromSlot(state, slotType, slot)

	if not uuid then
		return Err("SLOT_EMPTY")
	end

	return Operations.remove(state, uuid, amount)
end

-- Sets EquippedItemUUID. Pure state change, no Roblox dependency.
-- Idempotent: equipping the same item again returns success.
function Operations.equip(
	state: Types.InventoryState,
	uuid: string
): Types.EquipResult
	local item = state.Items[uuid]

	if not item then
		return Err("ITEM_NOT_FOUND")
	end

	local previousUUID = state.EquippedItemUUID

	if previousUUID == uuid then
		return Result.Ok({
			uuid = uuid,
			previousUUID = previousUUID,
		})
	end

	state.EquippedItemUUID = uuid

	return Result.Ok({
		uuid = uuid,
		previousUUID = previousUUID,
	})
end

-- Clears EquippedItemUUID. Pure state change, no Roblox dependency.
-- Idempotent: unequipping when nothing is equipped returns success.
function Operations.unequip(
	state: Types.InventoryState
): Types.UnequipResult
	local previousUUID = state.EquippedItemUUID
	state.EquippedItemUUID = nil

	return Result.Ok({
		previousUUID = previousUUID,
	})
end

-----------------------------
--MAIN--
-----------------------------

return Operations
