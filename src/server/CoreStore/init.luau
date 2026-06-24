--@author: yyumchi
--@date: 2026-06-24
--[[@description:
	Pure Luau inventory engine - public API facade
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Types = require("./CoreStore/Types")
local State = require("./CoreStore/State")
local Operations = require("./CoreStore/Operations")
local Query = require("./CoreStore/Query")

local CoreStore = {}

-- CONSTANTS --
-----------------------------

-- PRIVATE FUNCTIONS --
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
	return Operations.add(state, itemData, options)
end

function CoreStore.addToBackpack(
	state: Types.InventoryState,
	itemData: Types.ItemInput,
	options: Types.AddOptions?
): Types.AddResult
	local finalOptions: Types.AddOptions = {}

	if options then
		for key, value in pairs(options :: any) do
			(finalOptions :: any)[key] = value
		end
	end

	finalOptions.Placement = "Backpack"

	return Operations.add(state, itemData, finalOptions)
end

function CoreStore.addToHotbar(
	state: Types.InventoryState,
	itemData: Types.ItemInput,
	slot: number?
): Types.AddResult
	return Operations.add(state, itemData, {
		Placement = "Hotbar",
		Slot = slot,
	})
end

function CoreStore.remove(
	state: Types.InventoryState,
	uuid: string,
	amount: number?
): Types.RemoveResult
	return Operations.remove(state, uuid, amount)
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

-----------------------------
--MAIN--
-----------------------------

return CoreStore