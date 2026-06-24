--@author: yyumchi
--@date: 2026-06-24
--[[@description:
	CoreStore add/remove tests - visual pass/fail output with DELIBERATE failures
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

local function assertFalse(value: any, message: string?)
	if value then
		error(message or "assertFalse failed")
	end
end

local function getFirstUUID(result): string
	assertTrue(result.addedItems ~= nil, "expected addedItems")
	assertTrue(result.addedItems[1] ~= nil, "expected first added item")
	return result.addedItems[1].uuid
end

local function getAllUUIDs(result): { string }
	local uuids = {}
	if result.addedItems then
		for _, slot in result.addedItems do
			table.insert(uuids, slot.uuid)
		end
	end
	return uuids
end

-----------------------------
-- MAIN --
-----------------------------

-- PASS TESTS

runTest("New inventory is empty", true, function()
	local state = CoreStore.new()
	assertEqual(state.Weight, 0, "weight")
	assertEqual(#state.Storage, 0, "storage")
	assertEqual(state.EquippedItemUUID, nil, "equipped")
end)

runTest("Add goes to hotbar first", true, function()
	local state = CoreStore.new()
	local r = CoreStore.add(state, { Id = "Potion", Amount = 1, Metadata = { Rarity = "Common" } })
	assertTrue(r.success)
	assertEqual(state.Weight, 1)
	assertTrue(state.Hotbar[1] ~= nil)
	assertEqual(#state.Storage, 0)
end)

runTest("Hotbar fills before storage", true, function()
	local state = CoreStore.new({ MaxHotbarSlots = 2, MaxStackSize = 1, CanStack = false, Limit = 10 })
	CoreStore.add(state, { Id = "A", Amount = 1 })
	CoreStore.add(state, { Id = "B", Amount = 1 })
	CoreStore.add(state, { Id = "C", Amount = 1 })
	assertTrue(state.Hotbar[1] ~= nil)
	assertTrue(state.Hotbar[2] ~= nil)
	assertEqual(#state.Storage, 1, "third goes to storage")
	assertEqual(state.Weight, 3)
end)

runTest("addToBackpack skips hotbar", true, function()
	local state = CoreStore.new({ MaxHotbarSlots = 10, Limit = 10 })
	local r = CoreStore.addToBackpack(state, { Id = "IronOre", Amount = 1 })
	assertTrue(r.success)
	assertEqual(state.Hotbar[1], nil)
	assertEqual(#state.Storage, 1)
	assertEqual(state.Weight, 1)
end)

runTest("addToHotbar places in specific slot", true, function()
	local state = CoreStore.new({ MaxHotbarSlots = 5 })
	local r = CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1 }, 3)
	assertTrue(r.success)
	assertTrue(state.Hotbar[3] ~= nil)
	assertEqual(state.Hotbar[1], nil)
	assertEqual(state.Hotbar[2], nil)
end)

runTest("addToHotbar fails on occupied slot", true, function()
	local state = CoreStore.new({ MaxHotbarSlots = 2 })
	CoreStore.addToHotbar(state, { Id = "A", Amount = 1 }, 1)
	local r = CoreStore.addToHotbar(state, { Id = "B", Amount = 1 }, 1)
	assertFalse(r.success)
	assertEqual(r.reason, "HOTBAR_SLOT_OCCUPIED")
end)

runTest("StackAmount metadata alias", true, function()
	local state = CoreStore.new()
	local r = CoreStore.add(state, {
		Id = "Arrow",
		Metadata = { StackAmount = 3, Rarity = "Common", Type = "Ammo" },
	})
	assertTrue(r.success)
	assertEqual(r.addedAmount, 3)
	assertEqual(state.Weight, 3)
	local uuid = getFirstUUID(r)
	local item = CoreStore.getItem(state, uuid)
	assertEqual(item.Metadata.StackAmount, nil, "StackAmount stripped")
	assertEqual(item.Metadata.Amount, nil, "Amount stripped")
end)

runTest("Stacking two equal stacks", true, function()
	local state = CoreStore.new({ MaxStackSize = 5, CanStack = true, Limit = 10 })
	CoreStore.add(state, { Id = "Potion", Amount = 2, Metadata = { Rarity = "Common", Type = "Consumable" } })
	local items = CoreStore.find(state, "Potion")
	assertEqual(#items, 1, "should have 1 stack")
	local uuid = items[1].UUID
	local r2 = CoreStore.add(state, { Id = "Potion", Amount = 2, Metadata = { Rarity = "Common", Type = "Consumable" } })
	assertTrue(r2.success)
	local item = CoreStore.getItem(state, uuid)
	assertEqual(item.Amount, 4, "stacked to 4")
	assertEqual(state.Weight, 4)
	assertEqual(#state.Storage, 0)
end)

runTest("Blacklisted rarity doesn't stack", true, function()
	local state = CoreStore.new({ MaxStackSize = 5, CanStack = true, Limit = 10 })
	CoreStore.add(state, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Legendary", Type = "Weapon" } })
	CoreStore.add(state, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Legendary", Type = "Weapon" } })
	local items = CoreStore.find(state, "Sword")
	assertEqual(#items, 2, "two separate stacks")
	assertEqual(state.Weight, 2)
end)

runTest("Different required fields prevents stacking", true, function()
	local state = CoreStore.new({ MaxStackSize = 5, CanStack = true, Limit = 10 })
	CoreStore.add(state, { Id = "Potion", Amount = 1, Metadata = { Rarity = "Common", Type = "Consumable" } })
	CoreStore.add(state, { Id = "Potion", Amount = 1, Metadata = { Rarity = "Uncommon", Type = "Consumable" } })
	local items = CoreStore.find(state, "Potion")
	assertEqual(#items, 2, "different rarity = separate stacks")
end)

runTest("Partial remove reduces amount", true, function()
	local state = CoreStore.new({ MaxStackSize = 10 })
	local r = CoreStore.add(state, { Id = "Potion", Amount = 5 })
	local uuid = getFirstUUID(r)
	local rr = CoreStore.remove(state, uuid, 2)
	assertTrue(rr.success)
	assertEqual(rr.remaining, 3)
	assertEqual(state.Weight, 3)
	local item = CoreStore.getItem(state, uuid)
	assertTrue(item ~= nil)
	assertEqual(item.Amount, 3)
end)

runTest("Full remove destroys item", true, function()
	local state = CoreStore.new()
	local r = CoreStore.add(state, { Id = "Sword", Amount = 1 })
	local uuid = getFirstUUID(r)
	local rr = CoreStore.remove(state, uuid)
	assertTrue(rr.success)
	assertEqual(rr.remaining, 0)
	assertEqual(state.Weight, 0)
	assertEqual(CoreStore.getItem(state, uuid), nil)
	assertEqual(state.Hotbar[1], nil)
end)

runTest("Remove nonexistent item returns failure", true, function()
	local state = CoreStore.new()
	local rr = CoreStore.remove(state, "fake-uuid-999")
	assertFalse(rr.success)
	assertEqual(rr.reason, "ITEM_NOT_FOUND")
end)

runTest("Limit = 0 means infinite capacity", true, function()
	local state = CoreStore.new({ Limit = 0, MaxHotbarSlots = 100, MaxStackSize = 1 })
	for i = 1, 50 do
		local r = CoreStore.add(state, { Id = "Block", Amount = 1 })
		assertTrue(r.success, `block {i} should add`)
	end
	assertEqual(state.Weight, 50)
end)

runTest("Capacity overflow returns partial", true, function()
	local state = CoreStore.new({ Limit = 3, MaxStackSize = 10 })
	local r = CoreStore.add(state, { Id = "Gold", Amount = 10 })
	assertTrue(r.success)
	assertEqual(r.addedAmount, 3, "only 3 fit")
	assertEqual(r.overflow, 7, "7 overflow")
	assertEqual(state.Weight, 3)
end)

runTest("Backpack disabled prevents storage", true, function()
	local state = CoreStore.new({ MaxHotbarSlots = 1, MaxStackSize = 1, CanStack = false, BackpackEnabled = false, Limit = 10 })
	CoreStore.add(state, { Id = "A", Amount = 1 })
	local r = CoreStore.add(state, { Id = "B", Amount = 1 })
	assertFalse(r.success)
	assertEqual(r.reason, "BACKPACK_DISABLED")
end)

runTest("Find by string ID", true, function()
	local state = CoreStore.new({ CanStack = false, Limit = 10 })
	CoreStore.add(state, { Id = "Potion", Amount = 1 })
	CoreStore.add(state, { Id = "Sword", Amount = 1 })
	CoreStore.add(state, { Id = "Potion", Amount = 1 })
	local results = CoreStore.find(state, "Potion")
	assertEqual(#results, 2, "two potions")
	for _, item in results do
		assertEqual(item.Id, "Potion")
	end
end)

runTest("Filter by predicate", true, function()
	local state = CoreStore.new()
	CoreStore.add(state, { Id = "Potion", Amount = 3, Metadata = { Rarity = "Common" } })
	CoreStore.add(state, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Legendary" } })
	local results = CoreStore.filter(state, function(item)
		return item.Amount > 1
	end)
	assertEqual(#results, 1, "only potion has amount > 1")
	assertEqual(results[1].Id, "Potion")
end)

runTest("getItem returns nil for missing UUID", true, function()
	local state = CoreStore.new()
	assertEqual(CoreStore.getItem(state, "nonexistent"), nil)
end)

runTest("getAllItems returns all items", true, function()
	local state = CoreStore.new()
	CoreStore.add(state, { Id = "A", Amount = 1 })
	CoreStore.add(state, { Id = "B", Amount = 1 })
	local all = CoreStore.getAllItems(state)
	assertEqual(#all, 2, "two items total")
end)

-- EXPECTED FAILURE TESTS (deliberately wrong assertions)

runTest("[DELIBERATE] Wrong weight after add", false, function()
	local state = CoreStore.new()
	CoreStore.add(state, { Id = "Potion", Amount = 1 })
	assertEqual(state.Weight, 2, "deliberately wrong: weight is 1 not 2")
end)

runTest("[DELIBERATE] Wrong stack amount after stacking", false, function()
	local state = CoreStore.new({ MaxStackSize = 5, CanStack = true, Limit = 10 })
	CoreStore.add(state, { Id = "Potion", Amount = 2, Metadata = { Rarity = "Common", Type = "Consumable" } })
	CoreStore.add(state, { Id = "Potion", Amount = 2, Metadata = { Rarity = "Common", Type = "Consumable" } })
	local items = CoreStore.find(state, "Potion")
	assertEqual(items[1].Amount, 3, "deliberately wrong: amount is 4 not 3")
end)

runTest("[DELIBERATE] Hotbar not cleared after remove", false, function()
	local state = CoreStore.new()
	local r = CoreStore.add(state, { Id = "Sword", Amount = 1 })
	local uuid = getFirstUUID(r)
	CoreStore.remove(state, uuid)
	assertTrue(state.Hotbar[1] ~= nil, "deliberately wrong: slot is nil")
end)

runTest("[DELIBERATE] Storage not empty after backpack remove", false, function()
	local state = CoreStore.new({ MaxHotbarSlots = 1, MaxStackSize = 1, CanStack = false, Limit = 10 })
	local r1 = CoreStore.add(state, { Id = "A", Amount = 1 })
	local r2 = CoreStore.addToBackpack(state, { Id = "B", Amount = 1 })
	local uuid = getFirstUUID(r2)
	CoreStore.remove(state, uuid)
	assertEqual(#state.Storage, 1, "deliberately wrong: storage is 0")
end)

runTest("[DELIBERATE] getItem returns wrong item", false, function()
	local state = CoreStore.new()
	local r = CoreStore.add(state, { Id = "Sword", Amount = 1 })
	local uuid = getFirstUUID(r)
	local item = CoreStore.getItem(state, uuid)
	assertEqual(item.Id, "Potion", "deliberately wrong: item is Sword not Potion")
end)

-- RESULTS

print("")
print(string.rep("=", 44))
print(`  Results: {passCount} passed, {failCount} failed, {totalTests} total`)
print(string.rep("=", 44))

if failCount > 0 then
	local unexpected = failCount - 5
	if unexpected > 0 then
		print(`  ({unexpected} unexpected failure, {5} intentional [DELIBERATE] tests)`)
	else
		print(`  (all {failCount} failures are intentional [DELIBERATE] tests)`)
	end
end
