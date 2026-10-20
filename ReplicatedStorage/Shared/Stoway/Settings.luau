--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Shared settings defaults: the player-facing set that seeds every state
	via defaultOverrides (Dynamic hotbar, merging off, backpack off). This
	deliberately differs from the engine fallbacks in CoreStore State.luau
	(Static, merging on, backpack on). Categories drive the storage
	type-grouping order and group header styling on the client.
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
	Trinket = { DisplayName = "Trinkets", Color = Color3.fromRGB(130, 95, 150), Order = 5 },
	-- Catch-all for typeless items (groupStorageByType buckets them as
	-- "Other") and any Type with no dedicated entry. Sorted last so real
	-- categories always lead.
	Other = { DisplayName = "Other", Color = Color3.fromRGB(105, 105, 115), Order = 99 },
}

local DEFAULT_SETTINGS: Types.Settings = {
	HotbarType = "Dynamic",
	MaxHotbarSlots = 10,
	Limit = 15,
	CanStack = false, -- no merging into existing stacks; new stacks still cap at MaxStackSize
	MaxStackSize = 5,
	BackpackEnabled = false,
	Sorting = false,
	SortOrder = "None",
	StackOnSwap = false,
	StackRequiredFields = { "Rarity", "Type" },
	StackBlacklist = { Legendary = true, Mythic = true, Special = true },
	DefaultDroppable = true,
	DebugLogs = true,
	UiSkin = "Jailbreak",
	Layout = "JailbreakHotbar",
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
