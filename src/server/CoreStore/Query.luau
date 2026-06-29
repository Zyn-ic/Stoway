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

-----------------------------
-- CONSTANTS --
-----------------------------

-- PRIVATE FUNCTIONS --
-----------------------------

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- Returns a single item by UUID. O(1) direct lookup.
function Query.getItem(state: Types.InventoryState, uuid: string): Types.Item?
	return state.Items[uuid]
end

-- Returns all items as an array. O(n) full scan.
function Query.getAllItems(state: Types.InventoryState): { Types.Item }
	local items = table.create(#state.Items)

	for _, item in state.Items do
		table.insert(items, item)
	end

	return items
end

-- Returns all items matching a given ItemId.
-- Uses the ItemsByID reverse index for O(k) lookup where k = number of stacks.
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

-- Finds items matching a query. Supports 3 tiers of optimization:
--
--   1. String query: delegates to findById (O(k) via ItemsByID index)
--
--   2. Table query with metadata:
--      - Single field: uses MetadataIndex for O(k) bucket lookup
--        Example: find({ Metadata = { Rarity = "Legendary" } })
--          -> MetadataIndex["Rarity"]["Legendary"] = { "uuid-1", "uuid-5" }
--          -> returns those items (filtered by Id if provided)
--
--      - Multiple fields: picks the smallest MetadataIndex bucket, then
--        filters remaining fields. O(k) where k = smallest bucket size.
--        Example: find({ Metadata = { Rarity = "Legendary", Type = "Weapon" } })
--          -> If "Legendary" bucket has 5 items and "Weapon" has 20,
--             start from "Legendary" bucket, filter for Type == "Weapon"
--
--   3. Table query with no metadata: full Items scan. O(n)
function Query.find(state: Types.InventoryState, query: string | { Id: string?, Metadata: Types.ItemMetadata? }): { Types.Item }
	-- String query -> delegate to findById
	if type(query) == "string" then
		return Query.findById(state, query)
	end

	if query.Metadata then
		local metadataFields = {}

		for key, value in query.Metadata do
			table.insert(metadataFields, { key = key, value = value })
		end

		-- Single metadata field -> direct MetadataIndex bucket lookup
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

		-- Multiple metadata fields -> pick smallest bucket, filter rest
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

						-- Filter remaining metadata fields
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

	-- Fallback: full Items scan (no metadata index or no metadata in query)
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

-- Returns all items matching a predicate. O(n) full scan.
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
