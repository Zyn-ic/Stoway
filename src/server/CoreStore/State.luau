--@author: yyumchi
--@date: 2026-06-24
--[[@description:
	Inventory state creation, weight tracking, and capacity management
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Types = require("../CoreStore/Types")
local Utils = require("../CoreStore/Utils")

local State = {}

local DEFAULT_SETTINGS: Types.Settings = {
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

-- CONSTANTS --
-----------------------------

-- PRIVATE FUNCTIONS --
-----------------------------

local function mergeSettings(overrides: Types.SettingsOverrides?): Types.Settings
	local settings = Utils.deepCopy(DEFAULT_SETTINGS) :: Types.Settings

	if overrides then
		for key, value in pairs(overrides :: any) do
			(settings :: any)[key] = value
		end
	end

	return settings
end

-- PUBLIC FUNCTIONS --
-----------------------------

function State.new(settingsOverrides: Types.SettingsOverrides?): Types.InventoryState
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

function State.getDefaultSettings(): Types.Settings
	return Utils.deepCopy(DEFAULT_SETTINGS) :: Types.Settings
end

function State.getCurrentWeight(state: Types.InventoryState): number
	return state.Weight
end

function State.isLimitEnabled(state: Types.InventoryState): boolean
	return state.Settings.Limit > 0
end

function State.getRemainingCapacity(state: Types.InventoryState): number
	if not State.isLimitEnabled(state) then
		return math.huge
	end

	return math.max(0, state.Settings.Limit - State.getCurrentWeight(state))
end

function State.canAddAmount(state: Types.InventoryState, amount: number): boolean
	if not State.isLimitEnabled(state) then
		return true
	end

	return State.getRemainingCapacity(state) >= amount
end

function State.addWeight(state: Types.InventoryState, amount: number)
	state.Weight += amount
end

function State.removeWeight(state: Types.InventoryState, amount: number)
	state.Weight = math.max(0, state.Weight - amount)
end

-----------------------------
--MAIN--
-----------------------------

return State
