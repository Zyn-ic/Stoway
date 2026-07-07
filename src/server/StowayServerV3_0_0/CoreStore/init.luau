--@author: yyumchi
--@date: 2026-06-24
--[[@description:
	Pure Luau inventory engine - public API facade
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Types = require("@CoreStore/Types")
local State = require("@CoreStore/State")
local Operations = require("@CoreStore/Operations")
local Query = require("@CoreStore/Query")
local Slots = require("@CoreStore/Slots")

local CoreStore = {}

-----------------------------
-- CONSTANTS --
-----------------------------

-- PRIVATE FUNCTIONS --
-----------------------------

-- Called after every mutating operation (add, remove, swap, etc.) when Settings.Sorting = true.
-- Sorts Storage only. Hotbar is never sorted (user-controlled).
local function triggerAutoSort(state: Types.InventoryState)
	if state.Settings.Sorting then
		Operations.sort(state)
	end
end

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function CoreStore.new(settingsOverrides: Types.SettingsOverrides?): Types.InventoryState
	return State.new(settingsOverrides)
end

function CoreStore.getDefaultSettings(): Types.Settings
	return State.getDefaultSettings()
end

function CoreStore.add(
	state: Types.InventoryState,
	itemData: Types.ItemInput,
	options: Types.AddOptions?
): Types.AddResult
	local result = Operations.add(state, itemData, options)
	triggerAutoSort(state)
	return result
end

-- Wrapper: forces Placement = "Backpack" so items go straight to storage.
-- Bypasses hotbar stacking entirely — useful for chest looting, admin grants, etc.
function CoreStore.addToBackpack(
	state: Types.InventoryState,
	itemData: Types.ItemInput,
	options: Types.AddOptions?
): Types.AddResult
	local finalOptions: Types.AddOptions = {}

	if options then
		for key, value in options :: any do
			(finalOptions :: any)[key] = value
		end
	end

	finalOptions.Placement = "Backpack"

	local result = Operations.add(state, itemData, finalOptions)
	triggerAutoSort(state)
	return result
end

function CoreStore.addToHotbar(
	state: Types.InventoryState,
	itemData: Types.ItemInput,
	slot: number?
): Types.AddResult
	local result = Operations.add(state, itemData, {
		Placement = "Hotbar",
		Slot = slot,
	})
	triggerAutoSort(state)
	return result
end

function CoreStore.addToSlot(
	state: Types.InventoryState,
	itemData: Types.ItemInput,
	slotRef: Types.SlotRef
): Types.AddResult
	local result = Operations.add(state, itemData, {
		Placement = "Slot",
		SlotRef = slotRef,
	})
	triggerAutoSort(state)
	return result
end

function CoreStore.remove(
	state: Types.InventoryState,
	uuid: string,
	amount: number?
): Types.RemoveResult
	local result = Operations.remove(state, uuid, amount)
	triggerAutoSort(state)
	return result
end

function CoreStore.swap(
	state: Types.InventoryState,
	fromRef: Types.SlotRef,
	toRef: Types.SlotRef
): Types.SwapResult
	local result = Operations.swap(state, fromRef, toRef)
	triggerAutoSort(state)
	return result
end

function CoreStore.move(
	state: Types.InventoryState,
	fromRef: Types.SlotRef,
	toRef: Types.SlotRef
): Types.MoveResult
	local result = Operations.move(state, fromRef, toRef)
	triggerAutoSort(state)
	return result
end

function CoreStore.split(
	state: Types.InventoryState,
	uuid: string,
	amount: number,
	destination: Types.SlotRef?
): Types.SplitResult
	local result = Operations.split(state, uuid, amount, destination)
	triggerAutoSort(state)
	return result
end

function CoreStore.updateMetadata(
	state: Types.InventoryState,
	uuid: string,
	updates: { [string]: any }
): Types.MetadataUpdateResult
	local result = Operations.updateMetadata(state, uuid, updates)
	triggerAutoSort(state)
	return result
end

function CoreStore.sort(state: Types.InventoryState): Types.SortResult
	return Operations.sort(state)
end

function CoreStore.getItem(state: Types.InventoryState, uuid: string): Types.Item?
	return Query.getItem(state, uuid)
end

function CoreStore.find(
	state: Types.InventoryState,
	query: string | { Id: string?, Metadata: Types.ItemMetadata? }
): { Types.Item }
	return Query.find(state, query)
end

function CoreStore.filter(state: Types.InventoryState, predicate: (Types.Item) -> boolean): { Types.Item }
	return Query.filter(state, predicate)
end

function CoreStore.getAllItems(state: Types.InventoryState): { Types.Item }
	return Query.getAllItems(state)
end

function CoreStore.removeBySlot(
	state: Types.InventoryState,
	slotType: Types.SlotType,
	slot: number,
	amount: number?
): Types.RemoveResult
	local result = Operations.removeBySlot(state, slotType, slot, amount)
	triggerAutoSort(state)
	return result
end

function CoreStore.getHotbarItemCount(state: Types.InventoryState): number
	return Slots.getHotbarItemCount(state)
end

function CoreStore.getStorageItemCount(state: Types.InventoryState): number
	return Slots.getStorageItemCount(state)
end

function CoreStore.isEquipped(state: Types.InventoryState, uuid: string): boolean
	return State.isEquipped(state, uuid)
end

function CoreStore.isFull(state: Types.InventoryState): boolean
	return State.isFull(state)
end

function CoreStore.hasHotbarSpace(state: Types.InventoryState): boolean
	return State.hasHotbarSpace(state)
end

function CoreStore.compact(state: Types.InventoryState): boolean
	return Slots.compactHotbar(state)
end

function CoreStore.setHotbarType(state: Types.InventoryState, newType: Types.HotbarType)
	state.Settings.HotbarType = newType
	if newType == "Dynamic" then
		Slots.compactHotbar(state)
	end
end

function CoreStore.equip(state: Types.InventoryState, uuid: string): Types.EquipResult
	return Operations.equip(state, uuid)
end

function CoreStore.unequip(state: Types.InventoryState): Types.UnequipResult
	return Operations.unequip(state)
end

-----------------------------
--MAIN--
-----------------------------

return CoreStore
