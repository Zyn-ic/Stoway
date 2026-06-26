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
	local items = table.create(#state.Items)

	for _, item in state.Items do
		table.insert(items, item)
	end

	return items
end

function Query.findById(state: Types.InventoryState, itemId: string): { Types.Item }
	local uuids = state.ItemsByID[itemId]

	if not uuids then
		return {}
	end

	local results = table.create(#uuids)

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

	if query.Metadata then
		local metadataFields = {}

		for key, value in query.Metadata do
			table.insert(metadataFields, { key = key, value = value })
		end

		if #metadataFields == 1 then
			local field = metadataFields[1]
			local strValue = tostring(field.value)
			local bucket = state.MetadataIndex[field.key] and state.MetadataIndex[field.key][strValue]

			if bucket then
				local results = table.create(#bucket)

				for _, uuid in bucket do
					local item = state.Items[uuid]
					if item then
						if not query.Id or item.Id == query.Id then
							table.insert(results, item)
						end
					end
				end

				return results
			end

			return {}
		end

		if #metadataFields > 1 then
			local smallestKey: string? = nil
			local smallestBucket: { string }? = nil
			local smallestSize = math.huge

			for _, field in metadataFields do
				local strValue = tostring(field.value)
				local bucket = state.MetadataIndex[field.key] and state.MetadataIndex[field.key][strValue]

				if bucket and #bucket < smallestSize then
					smallestKey = field.key
					smallestBucket = bucket
					smallestSize = #bucket
				end
			end

			if smallestBucket then
				local results = table.create(#smallestBucket)

				for _, uuid in smallestBucket do
					local item = state.Items[uuid]
					if item then
						local matches = true

						if query.Id and item.Id ~= query.Id then
							matches = false
						end

						if matches then
							for _, field in metadataFields do
								if field.key ~= smallestKey and item.Metadata[field.key] ~= field.value then
									matches = false
									break
								end
							end
						end

						if matches then
							table.insert(results, item)
						end
					end
				end

				return results
			end

			return {}
		end
	end

	local results = table.create(math.min(#state.Items, 16))

	for _, item in state.Items do
		local matches = true

		if query.Id and item.Id ~= query.Id then
			matches = false
		end

		if matches then
			table.insert(results, item)
		end
	end

	return results
end

function Query.filter(state: Types.InventoryState, predicate: (Types.Item) -> boolean): { Types.Item }
	local results = table.create(math.min(#state.Items, 16))

	for _, item in state.Items do
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
