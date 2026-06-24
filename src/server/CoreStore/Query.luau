--@author: yyumchi
--@date: 2026-06-24
--[[@description:
	Item query functions - find, filter, get by ID
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Types = require("../CoreStore/Types")

local Query = {}

-- CONSTANTS --
-----------------------------

-- PRIVATE FUNCTIONS --
-----------------------------

-- PUBLIC FUNCTIONS --
-----------------------------

function Query.getItem(state: Types.InventoryState, uuid: string): Types.Item?
	return state.Items[uuid]
end

function Query.getAllItems(state: Types.InventoryState): { Types.Item }
	local items: { Types.Item } = {}

	for _, item in pairs(state.Items) do
		table.insert(items, item)
	end

	return items
end

function Query.findById(state: Types.InventoryState, itemId: string): { Types.Item }
	local results: { Types.Item } = {}
	local uuids = state.ItemsByID[itemId]

	if not uuids then
		return results
	end

	for _, uuid in ipairs(uuids) do
		local item = state.Items[uuid]

		if item then
			table.insert(results, item)
		end
	end

	return results
end

function Query.find(state: Types.InventoryState, query: string | { Id: string?, Metadata: Types.ItemMetadata? }): { Types.Item }
	if type(query) == "string" then
		return Query.findById(state, query)
	end

	local results: { Types.Item } = {}

	for _, item in pairs(state.Items) do
		local matches = true

		if query.Id and item.Id ~= query.Id then
			matches = false
		end

		if matches and query.Metadata then
			for key, value in pairs(query.Metadata) do
				if item.Metadata[key] ~= value then
					matches = false
					break
				end
			end
		end

		if matches then
			table.insert(results, item)
		end
	end

	return results
end

function Query.filter(state: Types.InventoryState, predicate: (Types.Item) -> boolean): { Types.Item }
	local results: { Types.Item } = {}

	for _, item in pairs(state.Items) do
		if predicate(item) then
			table.insert(results, item)
		end
	end

	return results
end

-----------------------------
--MAIN--
-----------------------------

return Query
