local Types = require(script.Parent.Types)
local Metadata = require(script.Parent.Metadata)
local State = require(script.Parent.State)

type InventoryState = Types.InventoryState
type Item = Types.Item
type ItemMetadata = Types.ItemMetadata

local Stack = {}

function Stack.canStack(
    state: InventoryState,
    existingItem: Item,
    incomingItemId: string,
    incomingMetadata: ItemMetadata
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
    state: InventoryState,
    itemId: string,
    amount: number,
    metadata: ItemMetadata
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

return Stack