--!native
--@author: yyumchi
--@date: 2026-06-24
--[[@description:
	Core inventory operations - add and remove items
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Types = require("../CoreStore/Types")
local Metadata = require("../CoreStore/Metadata")
local Slots = require("../CoreStore/Slots")
local Stack = require("../CoreStore/Stack")
local State = require("../CoreStore/State")
local Utils = require("../CoreStore/Utils")

local Operations = {}

-- CONSTANTS --
-----------------------------

-- PRIVATE FUNCTIONS --
-----------------------------

local function addToIndex(state: Types.InventoryState, itemId: string, uuid: string)
	if not state.ItemsByID[itemId] then
		state.ItemsByID[itemId] = {}
	end

	table.insert(state.ItemsByID[itemId], uuid)
end

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

local INDEXED_METADATA_FIELDS: { string } = { "Rarity", "Type" }

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

local function updateMetadataIndex(state: Types.InventoryState, uuid: string, oldMetadata: Types.ItemMetadata, newMetadata: Types.ItemMetadata)
	for _, field in INDEXED_METADATA_FIELDS do
		local oldValue = oldMetadata[field]
		local newValue = newMetadata[field]

		if oldValue ~= newValue then
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

local function destroyUnplacedItem(state: Types.InventoryState, item: Types.Item)
	state.Items[item.UUID] = nil
	state.LocationByUUID[item.UUID] = nil

	removeFromIndex(state, item.Id, item.UUID)
	removeFromMetadataIndex(state, item.UUID, item.Metadata)
	State.removeWeight(state, item.Amount)
end

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

local function placeItemInStorage(state: Types.InventoryState, item: Types.Item): (number?, string?)
	if not state.Settings.BackpackEnabled then
		return nil, "BACKPACK_DISABLED"
	end

	local slot = Slots.appendStorage(state, item.UUID)
	return slot, nil
end

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
			slot, reason = placeItemInStorage(state, item)

			if slot then
				slotType = "Storage"
				placed = true
			end
		elseif placement == "Hotbar" then
			slot, reason = placeItemInHotbar(state, item, options.Slot)

			if slot then
				slotType = "Hotbar"
				placed = true
			end
		elseif placement == "Slot" and options.SlotRef then
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
					Slots.moveToStorage(state, item.UUID, slotRef.Slot)
					slotType = "Storage"
					slot = slotRef.Slot
					placed = true
				else
					reason = "BACKPACK_DISABLED"
				end
			else
				reason = "INVALID_SLOT"
			end
		elseif placement == "Auto" then
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

function Operations.add(
	state: Types.InventoryState,
	itemData: Types.ItemInput,
	options: Types.AddOptions?
): Types.AddResult
	local opts: Types.AddOptions = options or {}

	local itemId, amount, metadata, normalizeError = Metadata.normalize(itemData)

	if normalizeError or not itemId or not amount or not metadata then
		return {
			success = false,
			reason = normalizeError or "INVALID_ITEM_DATA",
			addedAmount = 0,
			overflow = 0,
		}
	end

	local originalAmount = amount
	local remainingCapacity = State.getRemainingCapacity(state)

	if remainingCapacity <= 0 then
		return {
			success = false,
			reason = "FULL",
			addedAmount = 0,
			overflow = amount,
		}
	end

	local amountToAdd = math.min(amount, remainingCapacity)
	local amountLeft = amountToAdd

	local updatedItems: { number } = {}

	if state.Settings.CanStack then
		local stackedAmount, updates = Stack.tryStack(state, itemId, amountLeft, metadata, opts.Placement)

		amountLeft -= stackedAmount
		updatedItems = updates
	end

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

		if #addedItems == 0 and next(updatedItems) == nil then
			return {
				success = false,
				reason = placeReason or "ADD_FAILED",
				addedItems = addedItems,
				updatedItems = updatedItems,
				addedAmount = 0,
				overflow = originalAmount,
			}
		end
	end

	local addedAmount = amountToAdd - amountLeft
	local overflow = originalAmount - addedAmount

	return {
		success = addedAmount > 0,
		reason = overflow > 0 and "PARTIAL" or nil,
		addedItems = addedItems,
		updatedItems = updatedItems,
		addedAmount = addedAmount,
		overflow = overflow,
	}
end

function Operations.remove(
	state: Types.InventoryState,
	uuid: string,
	amount: number?
): Types.RemoveResult
	local item = state.Items[uuid]

	if not item then
		return {
			success = false,
			reason = "ITEM_NOT_FOUND",
		}
	end

	local amountToRemove = amount or item.Amount

	if not Utils.isPositiveNumber(amountToRemove) then
		return {
			success = false,
			reason = "INVALID_AMOUNT",
		}
	end

	amountToRemove = math.min(amountToRemove, item.Amount)

	local location = Slots.getLocation(state, uuid)
	local slotType = if location then location.Type else nil
	local slot = if location then location.Slot else nil

	local removedItem: Types.Item = {
		UUID = item.UUID,
		Id = item.Id,
		Amount = amountToRemove,
		Metadata = Utils.deepCopy(item.Metadata) :: Types.ItemMetadata,
	}

	if item.Amount > amountToRemove then
		item.Amount -= amountToRemove
		State.removeWeight(state, amountToRemove)

		return {
			success = true,
			removedItem = removedItem,
			remaining = item.Amount,
			slotType = slotType,
			slot = slot,
		}
	end

	State.removeWeight(state, item.Amount)

	state.Items[uuid] = nil
	state.LocationByUUID[uuid] = nil
	removeFromIndex(state, item.Id, uuid)
	removeFromMetadataIndex(state, uuid, item.Metadata)

	if state.EquippedItemUUID == uuid then
		state.EquippedItemUUID = nil
	end

	if slotType == "Hotbar" and slot then
		Slots.clearHotbarSlot(state, slot)
		Slots.compactHotbar(state)
	elseif slotType == "Storage" and slot then
		Slots.removeStorageAt(state, slot)
	end

	return {
		success = true,
		removedItem = removedItem,
		remaining = 0,
		slotType = slotType,
		slot = slot,
	}
end

function Operations.swap(
	state: Types.InventoryState,
	fromRef: Types.SlotRef,
	toRef: Types.SlotRef
): Types.SwapResult
	if not state.Settings.BackpackEnabled then
		if fromRef.Type == "Storage" or toRef.Type == "Storage" then
			return {
				success = false,
				reason = "BACKPACK_DISABLED",
			}
		end
	end

	if fromRef.Type == "Hotbar" then
		if not Slots.isValidHotbarSlot(state, fromRef.Slot) then
			return { success = false, reason = "INVALID_HOTBAR_SLOT" }
		end
	end

	if toRef.Type == "Hotbar" then
		if not Slots.isValidHotbarSlot(state, toRef.Slot) then
			return { success = false, reason = "INVALID_HOTBAR_SLOT" }
		end
	end

	if fromRef.Type == "Storage" then
		if not Slots.isValidStorageSlot(state, fromRef.Slot) then
			return { success = false, reason = "INVALID_STORAGE_SLOT" }
		end
	end

	local fromUUID = Slots.getUUIDFromSlot(state, fromRef.Type, fromRef.Slot)
	local toUUID = Slots.getUUIDFromSlot(state, toRef.Type, toRef.Slot)

	if not fromUUID then
		return { success = false, reason = "SOURCE_EMPTY" }
	end

	if fromUUID == toUUID then
		return { success = true }
	end

	if toUUID and state.Settings.StackOnSwap and state.Settings.CanStack then
		local fromItem = state.Items[fromUUID]
		local toItem = state.Items[toUUID]

		if fromItem and toItem and Stack.canStack(state, toItem, fromItem.Id, fromItem.Metadata) then
			local room = state.Settings.MaxStackSize - toItem.Amount
			local transfer = math.min(fromItem.Amount, room)

			toItem.Amount += transfer
			fromItem.Amount -= transfer

			if fromItem.Amount <= 0 then
				local loc = Slots.getLocation(state, fromUUID)
				state.Items[fromUUID] = nil
				state.LocationByUUID[fromUUID] = nil
				removeFromIndex(state, fromItem.Id, fromUUID)

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

			return { success = true }
		end
	end

	if fromRef.Type == "Hotbar" and toRef.Type == "Hotbar" then
		if state.Settings.HotbarType == "Dynamic" and not toUUID then
			return { success = false, reason = "DESTINATION_UNAVAILABLE" }
		end
	end

	local hotbarCompacted = Slots.swapSlots(state, fromRef, toRef)

	if toRef.Type == "Storage" and not toUUID then
		local fromItem = state.Items[fromUUID]
		if fromItem then
			if fromRef.Type == "Hotbar" then
				Slots.clearHotbarSlot(state, fromRef.Slot)
				hotbarCompacted = Slots.compactHotbar(state)
			end
		end
	end

	if fromRef.Type == "Storage" and not toUUID then
		local fromItem = state.Items[fromUUID]
		if fromItem then
			Slots.removeStorageAt(state, fromRef.Slot)
			Slots.appendStorage(state, fromUUID)
		end
	end

	return { success = true, hotbarCompacted = hotbarCompacted }
end

function Operations.move(
	state: Types.InventoryState,
	fromRef: Types.SlotRef,
	toRef: Types.SlotRef
): Types.MoveResult
	if not state.Settings.BackpackEnabled then
		if fromRef.Type == "Storage" or toRef.Type == "Storage" then
			return { success = false, reason = "BACKPACK_DISABLED" }
		end
	end

	if fromRef.Type == "Hotbar" then
		if not Slots.isValidHotbarSlot(state, fromRef.Slot) then
			return { success = false, reason = "INVALID_HOTBAR_SLOT" }
		end
	end

	if toRef.Type == "Hotbar" then
		if not Slots.isValidHotbarSlot(state, toRef.Slot) then
			return { success = false, reason = "INVALID_HOTBAR_SLOT" }
		end
	end

	if fromRef.Type == "Storage" then
		if not Slots.isValidStorageSlot(state, fromRef.Slot) then
			return { success = false, reason = "INVALID_STORAGE_SLOT" }
		end
	end

	local fromUUID = Slots.getUUIDFromSlot(state, fromRef.Type, fromRef.Slot)
	if not fromUUID then
		return { success = false, reason = "SOURCE_EMPTY" }
	end

	local toUUID = Slots.getUUIDFromSlot(state, toRef.Type, toRef.Slot)

	if fromRef.Type == "Storage" and toRef.Type == "Storage" then
		Slots.moveWithinStorage(state, fromRef.Slot, toRef.Slot)
		return { success = true }
	end

	if toUUID then
		return { success = false, reason = "DESTINATION_OCCUPIED" }
	end

	if fromRef.Type == "Hotbar" and toRef.Type == "Hotbar" then
		if state.Settings.HotbarType == "Dynamic" then
			return { success = false, reason = "DESTINATION_UNAVAILABLE" }
		end
		state.Hotbar[fromRef.Slot] = nil
		state.Hotbar[toRef.Slot] = fromUUID
		state.LocationByUUID[fromUUID] = { Type = "Hotbar", Slot = toRef.Slot }
		return { success = true }
	end

	if fromRef.Type == "Hotbar" and toRef.Type == "Storage" then
		state.Hotbar[fromRef.Slot] = nil
		--[[local insertedSlot =]] Slots.appendStorage(state, fromUUID)
		local hotbarCompacted =    Slots.compactHotbar(state)
		return { success = true, hotbarCompacted = hotbarCompacted }
	end

	if fromRef.Type == "Storage" and toRef.Type == "Hotbar" then
		if state.Settings.HotbarType == "Dynamic" then
			local appendSlot = Slots.findEmptyHotbarSlot(state)
			if toRef.Slot ~= appendSlot then
				return { success = false, reason = "DESTINATION_UNAVAILABLE" }
			end
		end
		Slots.removeStorageAt(state, fromRef.Slot)
		Slots.setHotbarSlot(state, toRef.Slot, fromUUID)
		return { success = true }
	end

	return { success = false, reason = "INVALID_OPERATION" }
end

function Operations.split(
	state: Types.InventoryState,
	uuid: string,
	amount: number,
	destination: Types.SlotRef?
): Types.SplitResult
	local item = state.Items[uuid]

	if not item then
		return { success = false, reason = "ITEM_NOT_FOUND" }
	end

	if not Utils.isPositiveNumber(amount) then
		return { success = false, reason = "INVALID_AMOUNT" }
	end

	if amount >= item.Amount then
		return { success = false, reason = "CANNOT_SPLIT_FULL" }
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
	State.addWeight(state, splitAmount)

	local newSlotType: Types.SlotType? = nil
	local newSlot: number? = nil
	local hotbarCompacted = false

	if destination then
		if destination.Type == "Hotbar" then
			if not Slots.isValidHotbarSlot(state, destination.Slot) then
				state.Items[newItem.UUID] = nil
				removeFromIndex(state, newItem.Id, newItem.UUID)
				State.removeWeight(state, splitAmount)
				item.Amount += splitAmount
				return { success = false, reason = "INVALID_HOTBAR_SLOT" }
			end

			if state.Hotbar[destination.Slot] then
				state.Items[newItem.UUID] = nil
				removeFromIndex(state, newItem.Id, newItem.UUID)
				State.removeWeight(state, splitAmount)
				item.Amount += splitAmount
				return { success = false, reason = "HOTBAR_SLOT_OCCUPIED" }
			end

			if state.Settings.HotbarType == "Dynamic" then
				local appendSlot = Slots.findEmptyHotbarSlot(state)
				if destination.Slot ~= appendSlot then
					state.Items[newItem.UUID] = nil
					removeFromIndex(state, newItem.Id, newItem.UUID)
					State.removeWeight(state, splitAmount)
					item.Amount += splitAmount
					return { success = false, reason = "DESTINATION_UNAVAILABLE" }
				end
			end

			Slots.setHotbarSlot(state, destination.Slot, newItem.UUID)
			newSlotType = "Hotbar"
			newSlot = destination.Slot
		elseif destination.Type == "Storage" then
			if not state.Settings.BackpackEnabled then
				state.Items[newItem.UUID] = nil
				removeFromIndex(state, newItem.Id, newItem.UUID)
				State.removeWeight(state, splitAmount)
				item.Amount += splitAmount
				return { success = false, reason = "BACKPACK_DISABLED" }
			end

			if not Slots.isValidStorageSlot(state, destination.Slot) then
				state.Items[newItem.UUID] = nil
				removeFromIndex(state, newItem.Id, newItem.UUID)
				State.removeWeight(state, splitAmount)
				item.Amount += splitAmount
				return { success = false, reason = "INVALID_STORAGE_SLOT" }
			end

			Slots.moveToStorage(state, newItem.UUID, destination.Slot)
			newSlotType = "Storage"
			newSlot = destination.Slot
		end
	else
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
			state.Items[newItem.UUID] = nil
			removeFromIndex(state, newItem.Id, newItem.UUID)
			State.removeWeight(state, splitAmount)
			item.Amount += splitAmount
			return { success = false, reason = "NO_SPACE" }
		end
	end

	return {
		success = true,
		sourceUUID = uuid,
		newUUID = newItem.UUID,
		sourceAmount = item.Amount,
		newAmount = splitAmount,
		newSlotType = newSlotType,
		newSlot = newSlot,
		hotbarCompacted = hotbarCompacted,
	}
end

function Operations.updateMetadata(
	state: Types.InventoryState,
	uuid: string,
	updates: { [string]: any }
): Types.MetadataUpdateResult
	local item = state.Items[uuid]

	if not item then
		return { success = false, reason = "ITEM_NOT_FOUND" }
	end

	local oldMetadata = table.clone(item.Metadata) :: Types.ItemMetadata
	local updatedFields: { string } = {}

	for key, value in updates do
		if value == nil then
			item.Metadata[key] = nil
		else
			item.Metadata[key] = value
		end
		table.insert(updatedFields, key)
	end

	updateMetadataIndex(state, uuid, oldMetadata, item.Metadata)

	return {
		success = true,
		updatedFields = updatedFields,
	}
end

function Operations.sort(
	state: Types.InventoryState
): Types.SortResult
	local sortOrder = state.Settings.SortOrder

	if sortOrder == "None" then
		return { success = true }
	end

	local hotbarChanged = Slots.sortHotbar(state, sortOrder)
	local storageChanged = Slots.sortStorage(state, sortOrder)

	return {
		success = true,
		hotbarOrder = if hotbarChanged then state.Hotbar :: { string } else nil,
		storageOrder = if storageChanged then state.Storage else nil,
	}
end

function Operations.removeBySlot(
	state: Types.InventoryState,
	slotType: Types.SlotType,
	slot: number,
	amount: number?
): Types.RemoveResult
	local uuid = Slots.getUUIDFromSlot(state, slotType, slot)

	if not uuid then
		return {
			success = false,
			reason = "SLOT_EMPTY",
		}
	end

	return Operations.remove(state, uuid, amount)
end

-----------------------------
--MAIN--
-----------------------------

return Operations
