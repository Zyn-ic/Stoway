--!strict

--@author: yyumchi
--@date: 2026-09-20
--[[@description:
	EXAMPLE (branch example/locked-slots, not canon): settings-keyed hotbar
	slot locks. A slot in the locked set stays unbound until the server
	flips it out (consume-on-use via the SlotUnlockExample script, pushed
	down in FullSync). Pure Luau, no Instances: shared by the client
	(HotbarView/Input) and the server (placement guards) so both sides
	enforce one rule.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local SlotLocks = {}

-- Metadata field declaring which slot a token unlocks when USED
-- (consumed via the SlotUnlockExample server script). Author it as a Tool
-- attribute; add paths copy it into item metadata untouched.
SlotLocks.UNLOCK_FIELD = "UnlocksHotbarSlot"

-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------

-- True when `slot` may bind: not in the locked set. Locks live in
-- Settings (flipped server-side on use); inventory presence plays no
-- role — merely holding a token unlocks nothing. Nil set fails open.
function SlotLocks.isUnlocked(locked: { [number]: boolean }?, slot: number): boolean
	return locked == nil or locked[slot] ~= true
end

-----------------------------
-- MAIN --
-----------------------------

return SlotLocks
