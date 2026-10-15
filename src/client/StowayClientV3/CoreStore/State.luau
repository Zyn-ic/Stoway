--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Client-side state helpers and settings defaults.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Types = require("./Types")

local State = {}

-----------------------------
-- CONSTANTS --
-----------------------------

local DEFAULT_MAX_HOTBAR_SLOTS = 10

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

function State.getMaxHotbarSlots(settings: Types.Settings?): number
	return if settings then settings.MaxHotbarSlots else DEFAULT_MAX_HOTBAR_SLOTS
end

-- Stable key set for ForPairs iteration over hotbar slots.
function State.slotIndices(maxSlots: number): { [number]: boolean }
	local indices: { [number]: boolean } = {}
	for i = 1, maxSlots do
		indices[i] = true
	end
	return indices
end

function State.isBackpackEnabled(settings: Types.Settings?): boolean
	return settings ~= nil and settings.BackpackEnabled
end

-----------------------------
-- MAIN --
-----------------------------

return State
