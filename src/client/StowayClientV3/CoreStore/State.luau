--!strict

--@author: yyumchi
--@date: 2026-08-19
--[[@description:
	Pure client-local state helpers — settings-derived defaults and simple
	table builders consumed by the layout engines. No Fusion, no Instances,
	no game/Roblox services besides the Types require (type-only, erased at
	runtime). Mirrors the server's CoreStore/State.luau in spirit.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Types = require(script.Parent.Types)

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

-- { [1]=true, [2]=true, ..., [maxSlots]=true } — a stable key set for
-- scope:ForPairs to iterate hotbar slot positions over. A plain NumberRange
-- array would also work, but a keyed set matches ForPairs's {[key]=value}
-- input contract and keeps slot identity stable across settings changes.
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
