local Types = require(script.Parent.Types)
local Utils = require(script.Parent.Utils)

type Settings = Types.Settings
type SettingsOverrides = Types.SettingsOverrides
type InventoryState = Types.InventoryState

local State = {}

local DEFAULT_SETTINGS: Settings = {
    HotbarType = "Static",
    MaxHotbarSlots = 10,

    Limit = 15,
    CanStack = true,
    MaxStackSize = 5,
    BackpackEnabled = true,

    Sorting = false,
    SortOrder = "None",

    StackRequiredFields = { "Rarity", "Type" },
    StackBlacklist = {
        Legendary = true,
        Mythic = true,
        Special = true,
    },

    DefaultDroppable = true,
}

local function mergeSettings(overrides: SettingsOverrides?): Settings
    local settings = Utils.deepCopy(DEFAULT_SETTINGS) :: Settings

    if overrides then
        for key, value in pairs(overrides :: any) do
            (settings :: any)[key] = value
        end
    end

    return settings
end

function State.new(settingsOverrides: SettingsOverrides?): InventoryState
    return {
        Items = {},
        ItemsByID = {},

        Hotbar = {},
        Storage = {},

        LocationByUUID = {},

        EquippedItemUUID = nil,
        Weight = 0,

        Settings = mergeSettings(settingsOverrides),
    }
end

function State.getDefaultSettings(): Settings
    return Utils.deepCopy(DEFAULT_SETTINGS) :: Settings
end

function State.getCurrentWeight(state: InventoryState): number
    return state.Weight
end

function State.isLimitEnabled(state: InventoryState): boolean
    return state.Settings.Limit > 0
end

function State.getRemainingCapacity(state: InventoryState): number
    if not State.isLimitEnabled(state) then
        return math.huge
    end

    return math.max(0, state.Settings.Limit - State.getCurrentWeight(state))
end

function State.canAddAmount(state: InventoryState, amount: number): boolean
    if not State.isLimitEnabled(state) then
        return true
    end

    return State.getRemainingCapacity(state) >= amount
end

function State.addWeight(state: InventoryState, amount: number)
    state.Weight += amount
end

function State.removeWeight(state: InventoryState, amount: number)
    state.Weight = math.max(0, state.Weight - amount)
end

return State