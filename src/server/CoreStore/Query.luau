local Types = require(script.Parent.Types)

type InventoryState = Types.InventoryState
type Item = Types.Item
type ItemMetadata = Types.ItemMetadata

local Query = {}

function Query.getItem(state: InventoryState, uuid: string): Item?
    return state.Items[uuid]
end

function Query.getAllItems(state: InventoryState): { Item }
    local items: { Item } = {}

    for _, item in pairs(state.Items) do
        table.insert(items, item)
    end

    return items
end

function Query.findById(state: InventoryState, itemId: string): { Item }
    local results: { Item } = {}
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

function Query.find(state: InventoryState, query: string | { Id: string?, Metadata: ItemMetadata? }): { Item }
    if type(query) == "string" then
        return Query.findById(state, query)
    end

    local results: { Item } = {}

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

function Query.filter(state: InventoryState, predicate: (Item) -> boolean): { Item }
    local results: { Item } = {}

    for _, item in pairs(state.Items) do
        if predicate(item) then
            table.insert(results, item)
        end
    end

    return results
end

return Query