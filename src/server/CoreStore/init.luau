local Types = require(script.Types)
local State = require(script.State)
local Operations = require(script.Operations)
local Query = require(script.Query)

type InventoryState = Types.InventoryState
type Settings = Types.Settings
type SettingsOverrides = Types.SettingsOverrides
type ItemInput = Types.ItemInput
type AddOptions = Types.AddOptions
type AddResult = Types.AddResult
type RemoveResult = Types.RemoveResult
type Item = Types.Item
type ItemMetadata = Types.ItemMetadata

local CoreStore = {}

function CoreStore.new(settingsOverrides: SettingsOverrides?): InventoryState
    return State.new(settingsOverrides)
end

function CoreStore.getDefaultSettings(): Settings
    return State.getDefaultSettings()
end

function CoreStore.add(
    state: InventoryState,
    itemData: ItemInput,
    options: AddOptions?
): AddResult
    return Operations.add(state, itemData, options)
end

function CoreStore.addToBackpack(
    state: InventoryState,
    itemData: ItemInput,
    options: AddOptions?
): AddResult
    local finalOptions: AddOptions = {}

    if options then
        for key, value in pairs(options :: any) do
            (finalOptions :: any)[key] = value
        end
    end

    finalOptions.Placement = "Backpack"

    return Operations.add(state, itemData, finalOptions)
end

function CoreStore.addToHotbar(
    state: InventoryState,
    itemData: ItemInput,
    slot: number?
): AddResult
    return Operations.add(state, itemData, {
        Placement = "Hotbar",
        Slot = slot,
    })
end

function CoreStore.remove(
    state: InventoryState,
    uuid: string,
    amount: number?
): RemoveResult
    return Operations.remove(state, uuid, amount)
end

function CoreStore.getItem(state: InventoryState, uuid: string): Item?
    return Query.getItem(state, uuid)
end

function CoreStore.find(
    state: InventoryState,
    query: string | { Id: string?, Metadata: ItemMetadata? }
): { Item }
    return Query.find(state, query)
end

function CoreStore.filter(state: InventoryState, predicate: (Item) -> boolean): { Item }
    return Query.filter(state, predicate)
end

function CoreStore.getAllItems(state: InventoryState): { Item }
    return Query.getAllItems(state)
end

return CoreStore