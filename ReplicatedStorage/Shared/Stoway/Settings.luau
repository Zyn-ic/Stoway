--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Shared settings defaults mirroring CoreStore State.luau. Categories drive
	the storage type-grouping order and group header styling on the client.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Types = require(script.Parent.Types)

local Settings = {}

-----------------------------
-- CONSTANTS --
-----------------------------

local DEFAULT_CATEGORIES: { [string]: Types.CategoryDef } = {
	Weapon = { DisplayName = "Weapons", Color = Color3.fromRGB(120, 115, 130), Order = 1 },
	Consumable = { DisplayName = "Consumables", Color = Color3.fromRGB(90, 130, 95), Order = 2 },
	Material = { DisplayName = "Materials", Color = Color3.fromRGB(130, 120, 90), Order = 3 },
	Armor = { DisplayName = "Armor", Color = Color3.fromRGB(100, 110, 145), Order = 4 },
}

local DEFAULT_SETTINGS: Types.Settings = {
	HotbarType = "Static",
	MaxHotbarSlots = 10,
	Limit = 15,
	CanStack = true,
	MaxStackSize = 5,
	BackpackEnabled = true,
	Sorting = false,
	SortOrder = "None",
	StackOnSwap = false,
	StackRequiredFields = { "Rarity", "Type" },
	StackBlacklist = { Legendary = true, Mythic = true, Special = true },
	DefaultDroppable = true,
	UiSkin = "Modern",
	Categories = DEFAULT_CATEGORIES,
	-- Demo toggle (see Types.luau) — on by default so the grouped/collapsible
	-- storage view is what you see out of the box; flip to false to render
	-- the plain ungrouped backpack ScrollingFrame instead.
	GroupByCategory = true,
}

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function Settings.getDefault(overrides: { [string]: any }?): Types.Settings
	local settings = table.clone(DEFAULT_SETTINGS) :: Types.Settings
	if overrides then
		for key, value in overrides do
			(settings :: any)[key] = value
		end
	end
	return settings
end

-- Known item types ordered by category Order (used for group ordering).
function Settings.getKnownTypes(): { string }
	local ordered: { string } = {}
	for itemType in DEFAULT_CATEGORIES do
		table.insert(ordered, itemType)
	end
	table.sort(ordered, function(a, b)
		return DEFAULT_CATEGORIES[a].Order < DEFAULT_CATEGORIES[b].Order
	end)
	return ordered
end

-----------------------------
-- MAIN --
-----------------------------

return Settings
