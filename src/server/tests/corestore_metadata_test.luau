--@author: yyumchi
--@date: 2026-08-07
--[[@description:
	CUSTOM METADATA visual example.
	Shows how the `[string]: any` indexer on ItemMetadata lets consumers attach
	their own fields (beyond the six built-ins) and how they flow through the
	inventory: add -> store -> query -> updateMetadata.

	Built-ins:  Description, Image, IsGamepass, Rarity, Droppable, Type
	Custom:     anything else, e.g. Enchant, Durability, customFully, etc.

	Only Rarity and Type are O(1) reverse-indexed. Custom fields are queryable
	via .find with a metadata predicate that falls back to those indexes, or via
	.filter with a predicate. Custom fields live on the item's Metadata table;
	they are NOT dropped unless they collide with the special keys Amount and
	StackAmount (which CoreStore consumes as the stack amount).

	Delete a field with the sentinel: updateMetadata(state, uuid,
	{ Enchant = CoreStore.METADATA_DELETE }). A literal { Enchant = nil } is an
	empty table in Luau and deletes nothing.
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------

local CoreStore = require("../CoreStore")

-----------------------------
-- VARIABLES --
-----------------------------

local passCount = 0
local failCount = 0
local totalTests = 0

-----------------------------
-- HANDLERS --
-----------------------------

local function runTest(name: string, expectPass: boolean, fn: () -> ())
	totalTests += 1
	local ok, err = pcall(fn)
	if ok == expectPass then
		passCount += 1
		print(`  \27[32m[PASS]\27[0m {name}`)
	else
		failCount += 1
		local label = if expectPass then "UNEXPECTED FAIL" else "EXPECTED FAIL"
		print(`  \27[31m[FAIL]\27[0m {name} ({label}: {err})`)
	end
end

local function assertEqual(actual: any, expected: any, message: string?)
	if actual ~= expected then
		error(`{message or "assertEqual"} | expected: {tostring(expected)}, got: {tostring(actual)}`)
	end
end

local function assertTrue(value: any, message: string?)
	if not value then
		error(message or "assertTrue failed")
	end
end

-- Adds an item and returns a fresh UUID. When an add STACKS into an existing
-- stack, `addedItems` is empty, so fall back to finding a stack by Id.
local function addAndGetUUID(state, itemData): string
	local result = CoreStore.add(state, itemData)
	assertTrue(result.success)

	if result.addedItems and result.addedItems[1] then
		return result.addedItems[1].uuid
	end

	local found = CoreStore.find(state, itemData.Id :: string)
	assertTrue(found and found[1] ~= nil, "expected an existing stack after stacking")
	return found[1].UUID
end

-----------------------------
-- MAIN --
-----------------------------

-- ── 1. Adding an item with CUSTOM metadata (beyond the built-ins) ──────────

runTest("Custom metadata is stored verbatim on the item", true, function()
	local state = CoreStore.new()

	-- Built-in Rarity + two custom fields (Enchant, customFully).
	local uuid = addAndGetUUID(state, {
		Id = "MagicStaff",
		Metadata = {
			Rarity = "Legendary",
			Droppable = false,
			Enchant = "Fire",
			customFully = 100,
		},
	})

	local item = CoreStore.getItem(state, uuid)
	assertEqual(item.Metadata.Rarity, "Legendary", "built-in preserved")
	assertEqual(item.Metadata.Droppable, false, "built-in preserved")
	assertEqual(item.Metadata.Enchant, "Fire", "custom string preserved")
	assertEqual(item.Metadata.customFully, 100, "custom number preserved")
end)

-- ─────────────────────────────────────────────────────────────
-- NOTE: The two reserved metadata keys `Amount` and `StackAmount` are
-- treated as the stack amount by CoreStore and are stripped after extract.
-- A custom field with the same name is therefore NOT preserved.
-- ─────────────────────────────────────────────────────────────

runTest("Reserved Amount/StackAmount keys are consumed, not stored", true, function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, {
		Id = "Potion",
		Metadata = { Amount = 3, StackAmount = 9, Rarity = "Common" },
	})

	local item = CoreStore.getItem(state, uuid)
	assertEqual(item.Amount, 3, "Amount fed from metadata")
	assertEqual(item.Metadata.StackAmount, nil, "StackAmount stripped from metadata")
	assertEqual(item.Metadata.Amount, nil, "Amount stripped from metadata")
end)

-- ─────────────────────────────────────────────────────────────
-- Querying: Rarity and Type are indexed for O(1); custom fields
-- fall through to a scan (find with a metadata predicate on the
-- index that exists, or filter for fully custom predicate).
-- ─────────────────────────────────────────────────────────────

runTest("Custom fields are NOT in MetadataIndex (only Rarity/Type are)", true, function()
	local state = CoreStore.new()
	addAndGetUUID(state, { Id = "Sword", Metadata = { Enchant = "Fire", Rarity = "Legendary" } })

	-- Indexed field -> populated.
	assertTrue(state.MetadataIndex["Rarity"] ~= nil, "Rarity index exists")
	-- Custom field -> no bucket.
	assertEqual(state.MetadataIndex["Enchant"], nil, "Enchant has no reverse index")
end)

runTest("find with indexed built-in still works", true, function()
	local state = CoreStore.new()
	addAndGetUUID(state, { Id = "Potion", Metadata = { Rarity = "Legendary" } })
	addAndGetUUID(state, { Id = "Potion", Metadata = { Rarity = "Common" } })

	local legends = CoreStore.find(state, { Id = "Potion", Metadata = { Rarity = "Legendary" } })
	assertEqual(#legends, 1, "1 legendary potion")
	assertTrue(legends[1] ~= nil and legends[1].Metadata.Rarity == "Legendary")
end)

runTest("filter predicate can look at custom metadata", true, function()
	local state = CoreStore.new()
	addAndGetUUID(state, { Id = "Sword", Metadata = { Enchant = "Fire", Rarity = "Common" } })
	addAndGetUUID(state, { Id = "Sword", Metadata = { Enchant = "Ice", Rarity = "Common" } })

	local fiery = CoreStore.filter(state, function(item)
		return (item.Metadata.Enchant or "") == "Fire"
	end)
	assertEqual(#fiery, 1, "one fiery sword")
	assertEqual(fiery[1].Metadata.Enchant, "Fire")
end)

-- ─────────────────────────────────────────────────────────────
-- Mutating custom metadata: updates merge into the item, keep old
-- custom keys that are not touched, and clear keys set to nil.
-- ─────────────────────────────────────────────────────────────

runTest("updateMetadata adds new custom fields", true, function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, { Id = "Staff", Metadata = { Enchant = "Fire" } })

	local r = CoreStore.updateMetadata(state, uuid, { Durability = 120 })
	assertTrue(r.success)
	local item = CoreStore.getItem(state, uuid)
	assertEqual(item.Metadata.Enchant, "Fire", "old custom key preserved")
	assertEqual(item.Metadata.Durability, 120, "new custom key added")
end)

runTest("updateMetadata can mutate an existing custom field", true, function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, { Id = "Staff", Metadata = { Durability = 100 } })

	CoreStore.updateMetadata(state, uuid, { Durability = 50 })
	local item = CoreStore.getItem(state, uuid)
	assertEqual(item.Metadata.Durability, 50)
end)

runTest("GOTCHA: nil in updates omits the key, so it cannot delete", true, function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, { Id = "Staff", Metadata = { Enchant = "Fire", Durability = 10 } })

	-- Luau gotcha: { Enchant = nil } produces an EMPTY table — the key never
	-- exists, so the updateMetadata loop sees nothing and nothing is deleted.
	CoreStore.updateMetadata(state, uuid, { Enchant = nil })

	local item = CoreStore.getItem(state, uuid)
	assertEqual(item.Metadata.Enchant, "Fire", "no-op: Enchant untouched (nil unreachable in table)")
	assertEqual(item.Metadata.Durability, 10, "Durability untouched")

	-- To actually DELETE a field, use the METADATA_DELETE sentinel (below):
	CoreStore.updateMetadata(state, uuid, { Enchant = CoreStore.METADATA_DELETE })
	item = CoreStore.getItem(state, uuid)
	assertEqual(item.Metadata.Enchant, nil, "sentinel wipes the key")
end)

-- ─────────────────────────────────────────────────────────────
-- DELETING metadata with the METADATA_DELETE sentinel.
-- Lua tables can never hold a nil value ({ Enchant = nil } is an
-- EMPTY table), so CoreStore accepts this unique namespaced string
-- as an explicit "remove this key" marker. It survives the wire as
-- a plain string, so clients can use StowayRemotes.METADATA_DELETE.
-- ─────────────────────────────────────────────────────────────

runTest("METADATA_DELETE removes a custom field", true, function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, { Id = "Staff", Metadata = { Enchant = "Fire", Durability = 10 } })

	CoreStore.updateMetadata(state, uuid, { Enchant = CoreStore.METADATA_DELETE })

	local item = CoreStore.getItem(state, uuid)
	assertEqual(item.Metadata.Enchant, nil, "Enchant deleted")
	assertEqual(item.Metadata.Durability, 10, "Durability untouched")
end)

runTest("METADATA_DELETE evicts indexed fields from MetadataIndex", true, function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, { Id = "Sword", Metadata = { Rarity = "Legendary", Type = "Weapon" } })

	-- Rarity is reverse-indexed, so a Legendary find returns the uuid first.
	local legendary = CoreStore.find(state, { Id = "Sword", Metadata = { Rarity = "Legendary" } })
	assertEqual(#legendary, 1, "Legendary indexed before delete")

	CoreStore.updateMetadata(state, uuid, { Rarity = CoreStore.METADATA_DELETE })

	local afterDelete = CoreStore.find(state, { Id = "Sword", Metadata = { Rarity = "Legendary" } })
	assertEqual(#afterDelete, 0, "Legendary bucket evicted after delete")
	local item = CoreStore.getItem(state, uuid)
	assertEqual(item.Metadata.Rarity, nil, "Rarity removed from item")
end)

runTest("METADATA_DELETE only matches the exact sentinel", true, function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, { Id = "Potion", Metadata = { Color = "Red" } })

	-- A look-alike string (different from the sentinel) is stored, not deleted.
	CoreStore.updateMetadata(state, uuid, { Color = "__STOWAY_DELETE" })
	local item = CoreStore.getItem(state, uuid)
	assertEqual(item.Metadata.Color, "__STOWAY_DELETE", "look-alike string stored, not deleted")

	-- Only the exact sentinel constant wipes.
	CoreStore.updateMetadata(state, uuid, { Color = CoreStore.METADATA_DELETE })
	item = CoreStore.getItem(state, uuid)
	assertEqual(item.Metadata.Color, nil, "exact sentinel deletes")
end)

-- ─────────────────────────────────────────────────────────────
-- Custom metadata does not break stacking: StackRequiredFields
-- (Rarity, Type) are what gate whether two items merge. Custom
-- keys don't affect it.
-- ─────────────────────────────────────────────────────────────

runTest("Custom metadata does not block stacking", true, function()
	local state = CoreStore.new({ MaxStackSize = 5, CanStack = true, Limit = 10 })
	addAndGetUUID(state, { Id = "Potion", Metadata = { Rarity = "Common", Type = "Consumable", Enchant = "Fire" } })
	local uuid2 = addAndGetUUID(state, { Id = "Potion", Metadata = { Rarity = "Common", Type = "Consumable", Enchant = "Fire" } })

	-- Both stack into a single stack (Enchant is a custom field, not gated).
	local item = CoreStore.getItem(state, uuid2)
	assertEqual(item.Amount, 2, "two stacks merged")
	assertEqual(#CoreStore.find(state, "Potion"), 1, "one stack total")
end)

-- ─────────────────────────────────────────────────────────────
-- RESULTS
-- ─────────────────────────────────────────────────────────────

print("")
print(string.rep("=", 44))
print(`  Custom Metadata: {passCount} passed, {failCount} failed, {totalTests} total`)
print(string.rep("=", 44))
print("")
print("Try it yourself — add any key you like to Metadata:")
print('  CoreStore.add(state, { Id = "Sword", Metadata = { Enchant = "Fire" } })')
