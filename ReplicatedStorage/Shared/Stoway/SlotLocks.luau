--!strict

--@author: yyumchi
--@date: 2026-09-20
--[[@description:
	EXAMPLE (branch example/locked-slots, not canon): metadata-keyed hotbar
	slot locks. A slot in the locked set stays unbound until the player holds
	an item whose metadata carries UnlocksHotbarSlot == slot. Pure Luau, no
	Instances: shared by the client (HotbarView/Input) and the server
	(placement guards) so both sides enforce one rule.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local Types = require(script.Parent.Types)

local SlotLocks = {}

-- Metadata field declaring a slot unlock. Author it as a Tool attribute
-- (e.g. UnlocksHotbarSlot = 9 on a token tool); the pickup path copies
-- every tool attribute into item metadata untouched.
SlotLocks.UNLOCK_FIELD = "UnlocksHotbarSlot"

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- True when `slot` may bind: not locked, or a token item is held.
-- Nil lock set (unknown settings) fails open.
-- NOTE: items is typed as the shared Item (not a narrower structural
-- alias). The new solver matches table arguments exactly, so a bespoke
-- { Metadata ... } shape rejects real Item tables at call sites.
function SlotLocks.isUnlocked(
	items: { [string]: Types.Item },
	locked: { [number]: boolean }?,
	slot: number
): boolean
	if locked == nil or locked[slot] ~= true then
		return true
	end
	for _, item in items do
		local metadata = item.Metadata
		if metadata ~= nil and metadata[SlotLocks.UNLOCK_FIELD] == slot then
			return true
		end
	end
	return false
end

-----------------------------
-- MAIN --
-----------------------------

return SlotLocks
