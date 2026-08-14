--@author: yyumchi
--@date: 2026-06-25
--[[@description:
	CoreStore swap/move/split/metadata/sort tests - visual pass/fail output
]]
-----------------------------
-- SERVICES --
-----------------------------

-----------------------------
-- DEPENDENCIES --
-----------------------------
local CoreStore = require("@CoreStore")

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

-- Validates every reverse reference touched when swapStack fully absorbs an
-- item. This detects stale UUIDs (the practical form of a retained-state leak)
-- as well as slot or index orphans.
local function assertStateIntegrity(state)
	local seen: { [string]: number } = {}
	local expectedWeight = 0

	for slot, uuid in state.Hotbar do
		assertTrue(state.Items[uuid] ~= nil, `Hotbar[{slot}] references a missing item`)
		seen[uuid] = (seen[uuid] or 0) + 1
		local location = state.LocationByUUID[uuid]
		assertTrue(location ~= nil and location.Type == "Hotbar" and location.Slot == slot, "hotbar location index is stale")
	end

	for slot, uuid in state.Storage do
		assertTrue(state.Items[uuid] ~= nil, `Storage[{slot}] references a missing item`)
		seen[uuid] = (seen[uuid] or 0) + 1
		local location = state.LocationByUUID[uuid]
		assertTrue(location ~= nil and location.Type == "Storage" and location.Slot == slot, "storage location index is stale")
	end

	for uuid, item in state.Items do
		assertEqual(seen[uuid], 1, "every item must have exactly one slot")
		assertTrue(table.find(state.ItemsByID[item.Id], uuid) ~= nil, "ItemsByID is missing an item UUID")
		expectedWeight += item.Amount
		for _, field in { "Rarity", "Type" } do
			local value = item.Metadata[field]
			if value ~= nil then
				local bucket = state.MetadataIndex[field] and state.MetadataIndex[field][tostring(value)]
				assertTrue(bucket ~= nil and table.find(bucket, uuid) ~= nil, "MetadataIndex is missing an item UUID")
			end
		end
	end

	for uuid in state.LocationByUUID do
		assertTrue(state.Items[uuid] ~= nil, "LocationByUUID contains an orphan UUID")
	end
	for _, uuids in state.ItemsByID do
		for _, uuid in uuids do
			assertTrue(state.Items[uuid] ~= nil, "ItemsByID contains an orphan UUID")
		end
	end
	for _, values in state.MetadataIndex do
		for _, bucket in values do
			for _, uuid in bucket do
				assertTrue(state.Items[uuid] ~= nil, "MetadataIndex contains an orphan UUID")
			end
		end
	end
	assertEqual(state.Weight, expectedWeight, "weight must equal the sum of item amounts")
end

-----------------------------
-- MAIN --
-----------------------------

-- ==================== SWAP TESTS ====================

runTest("Swap hotbar to hotbar exchanges positions", true, function()
	local state = CoreStore.new()
	local r1 = CoreStore.add(state, { Id = "Sword", Amount = 1 })
	local r2 = CoreStore.add(state, { Id = "Shield", Amount = 1 })
	local uuid1 = getFirstUUID(r1)
	local uuid2 = getFirstUUID(r2)

	local loc1 = state.LocationByUUID[uuid1]
	local loc2 = state.LocationByUUID[uuid2]

	local result = CoreStore.swap(state, loc1, loc2)
	assertTrue(result.success, "swap should succeed")

	local newLoc1 = state.LocationByUUID[uuid1]
	local newLoc2 = state.LocationByUUID[uuid2]
	assertEqual(newLoc1.Slot, loc2.Slot, "uuid1 should be in uuid2's old slot")
	assertEqual(newLoc2.Slot, loc1.Slot, "uuid2 should be in uuid1's old slot")
end)

runTest("Swap storage to storage exchanges positions", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local r1 = CoreStore.addToBackpack(state, { Id = "Potion", Amount = 1 })
	local r2 = CoreStore.addToBackpack(state, { Id = "Scroll", Amount = 1 })
	local uuid1 = getFirstUUID(r1)
	local uuid2 = getFirstUUID(r2)

	local loc1 = state.LocationByUUID[uuid1]
	local loc2 = state.LocationByUUID[uuid2]

	local result = CoreStore.swap(state, loc1, loc2)
	assertTrue(result.success, "swap should succeed")

	local newLoc1 = state.LocationByUUID[uuid1]
	local newLoc2 = state.LocationByUUID[uuid2]
	assertEqual(newLoc1.Slot, loc2.Slot, "uuid1 should be in uuid2's old slot")
	assertEqual(newLoc2.Slot, loc1.Slot, "uuid2 should be in uuid1's old slot")
end)

runTest("Swap hotbar to storage exchanges across containers", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local r1 = CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1 })
	local r2 = CoreStore.addToBackpack(state, { Id = "Potion", Amount = 1 })
	local uuid1 = getFirstUUID(r1)
	local uuid2 = getFirstUUID(r2)

	local fromRef = state.LocationByUUID[uuid1]
	local toRef = state.LocationByUUID[uuid2]

	local result = CoreStore.swap(state, fromRef, toRef)
	assertTrue(result.success, "swap should succeed")

	assertEqual(state.LocationByUUID[uuid1].Type, "Storage", "uuid1 should be in storage")
	assertEqual(state.LocationByUUID[uuid2].Type, "Hotbar", "uuid2 should be in hotbar")
end)

runTest("Swap fails when source is empty", true, function()
	local state = CoreStore.new()
	local result = CoreStore.swap(state, { Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 2 })
	assertFalse(result.success, "swap with empty source should fail")
	assertEqual(result.reason, "SOURCE_EMPTY")
end)

runTest("Swap fails when backpack disabled and storage involved", true, function()
	local state = CoreStore.new({ BackpackEnabled = false })
	local r1 = CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1 })
	local uuid1 = getFirstUUID(r1)
	local fromRef = state.LocationByUUID[uuid1]

	local result = CoreStore.swap(state, fromRef, { Type = "Storage", Slot = 1 })
	assertFalse(result.success, "swap should fail with backpack disabled")
	assertEqual(result.reason, "BACKPACK_DISABLED")
end)

runTest("StackOnSwap stacks items when enabled", true, function()
	local state = CoreStore.new({ StackOnSwap = true, CanStack = false, MaxStackSize = 10 })
	local r1 = CoreStore.addToHotbar(state, { Id = "Apple", Amount = 3 })
	local r2 = CoreStore.addToHotbar(state, { Id = "Apple", Amount = 2 })
	local uuid1 = getFirstUUID(r1)
	local uuid2 = getFirstUUID(r2)

	local fromRef = state.LocationByUUID[uuid1]
	local toRef = state.LocationByUUID[uuid2]

	state.Settings.CanStack = true
	local result = CoreStore.swap(state, fromRef, toRef)
	assertTrue(result.success, "swap should succeed")

	local toItem = state.Items[uuid2]
	assertEqual(toItem.Amount, 5, "destination should have stacked amount")

	local fromItem = state.Items[uuid1]
	assertTrue(fromItem == nil or fromItem.Amount == 0, "source should be absorbed")
end)

runTest("StackOnSwap does not stack when disabled", true, function()
	local state = CoreStore.new({ StackOnSwap = false, CanStack = false, MaxStackSize = 10 })
	local r1 = CoreStore.addToHotbar(state, { Id = "Apple", Amount = 3 })
	local r2 = CoreStore.addToHotbar(state, { Id = "Apple", Amount = 2 })
	local uuid1 = getFirstUUID(r1)
	local uuid2 = getFirstUUID(r2)

	local fromRef = state.LocationByUUID[uuid1]
	local toRef = state.LocationByUUID[uuid2]

	state.Settings.CanStack = true
	local result = CoreStore.swap(state, fromRef, toRef)
	assertTrue(result.success, "swap should succeed")

	local toItem = state.Items[uuid2]
	assertEqual(toItem.Amount, 2, "destination amount should be unchanged (positional swap)")

	local fromItem = state.Items[uuid1]
	assertEqual(fromItem.Amount, 3, "source amount should be unchanged (positional swap)")
end)

runTest("SwapStack fully absorbs source and cleans all references", true, function()
	local state = CoreStore.new({ StackOnSwap = true, CanStack = false, MaxStackSize = 10, Limit = 100 })
	local sourceResult = CoreStore.addToHotbar(state, { Id = "Apple", Amount = 3, Metadata = { Rarity = "Epic", Type = "Food" } })
	local targetResult = CoreStore.addToBackpack(state, { Id = "Apple", Amount = 2, Metadata = { Rarity = "Epic", Type = "Food" } })
	local sourceUUID = getFirstUUID(sourceResult)
	local targetUUID = getFirstUUID(targetResult)
	state.Settings.CanStack = true

	local result = CoreStore.swapStack(state, state.LocationByUUID[sourceUUID], state.LocationByUUID[targetUUID])
	assertTrue(result.success, "swapStack should succeed")
	assertEqual(state.Items[sourceUUID], nil, "fully absorbed source must be removed")
	assertEqual(state.Items[targetUUID].Amount, 5, "target must receive source amount")
	assertEqual(state.EquippedItemUUID, nil, "no equipped orphan should remain")
	assertStateIntegrity(state)
end)

runTest("SwapStack partially absorbs without moving either UUID", true, function()
	local state = CoreStore.new({ StackOnSwap = true, CanStack = false, MaxStackSize = 5, Limit = 100 })
	local sourceResult = CoreStore.addToHotbar(state, { Id = "Apple", Amount = 3 })
	local targetResult = CoreStore.addToBackpack(state, { Id = "Apple", Amount = 4 })
	local sourceUUID = getFirstUUID(sourceResult)
	local targetUUID = getFirstUUID(targetResult)
	state.Settings.CanStack = true

	local result = CoreStore.swapStack(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	assertTrue(result.success, "swapStack should succeed")
	assertEqual(state.Items[sourceUUID].Amount, 2, "source should retain the remainder")
	assertEqual(state.Items[targetUUID].Amount, 5, "target should cap at MaxStackSize")
	assertEqual(state.Hotbar[1], sourceUUID, "partial source must remain in place")
	assertEqual(state.Storage[1], targetUUID, "target must remain in place")
	assertStateIntegrity(state)
end)

runTest("SwapStack respects StackOnSwap and falls back to positional swap", true, function()
	local state = CoreStore.new({ StackOnSwap = false, CanStack = false, MaxStackSize = 10, Limit = 100 })
	local sourceResult = CoreStore.addToHotbar(state, { Id = "Apple", Amount = 3 })
	local targetResult = CoreStore.addToHotbar(state, { Id = "Apple", Amount = 2 })
	local sourceUUID = getFirstUUID(sourceResult)
	local targetUUID = getFirstUUID(targetResult)
	state.Settings.CanStack = true

	local result = CoreStore.swapStack(state, { Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 2 })
	assertTrue(result.success, "fallback swap should succeed")
	assertEqual(state.Hotbar[1], targetUUID, "target should move to source slot")
	assertEqual(state.Hotbar[2], sourceUUID, "source should move to target slot")
	assertEqual(state.Items[sourceUUID].Amount, 3, "source must not be absorbed when StackOnSwap is off")
	assertEqual(state.Items[targetUUID].Amount, 2, "target amount must not change when StackOnSwap is off")
	assertStateIntegrity(state)
end)

runTest("SwapStack compacts Dynamic hotbar after absorbing source", true, function()
	local state = CoreStore.new({ HotbarType = "Dynamic", StackOnSwap = true, CanStack = false, MaxStackSize = 10, Limit = 100 })
	local sourceResult = CoreStore.addToHotbar(state, { Id = "Apple", Amount = 3 })
	local survivorResult = CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1 })
	local targetResult = CoreStore.addToBackpack(state, { Id = "Apple", Amount = 2 })
	local sourceUUID = getFirstUUID(sourceResult)
	local survivorUUID = getFirstUUID(survivorResult)
	local targetUUID = getFirstUUID(targetResult)
	state.Settings.CanStack = true

	CoreStore.swapStack(state, state.LocationByUUID[sourceUUID], state.LocationByUUID[targetUUID])
	assertEqual(state.Hotbar[1], survivorUUID, "dynamic hotbar should compact the survivor")
	assertEqual(state.LocationByUUID[survivorUUID].Slot, 1, "survivor location must be updated")
	assertStateIntegrity(state)
end)

runTest("Swap storage to hotbar (empty dest) moves item, no duplicate refs", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local r1 = CoreStore.addToBackpack(state, { Id = "Wood", Amount = 1 })
	local r2 = CoreStore.addToBackpack(state, { Id = "Chainsaw", Amount = 1 })
	local uuidA = getFirstUUID(r1)
	local uuidB = getFirstUUID(r2)

	assertEqual(#state.Storage, 2, "both items should be in storage")

	local result = CoreStore.swap(state, { Type = "Storage", Slot = 1 }, { Type = "Hotbar", Slot = 1 })
	assertTrue(result.success, "swap should succeed")

	assertEqual(state.Hotbar[1], uuidA, "hotbar dest should hold the moved item")

	local storageCount = 0
	for _, uuid in state.Storage do
		if uuid == uuidA then
			storageCount += 1
		end
	end
	assertEqual(storageCount, 0, "moved item must not remain in storage (INV-2)")
	assertEqual(#state.Storage, 1, "storage should keep only the other item")
	assertEqual(state.Storage[1], uuidB, "remaining storage item should be the other one")
	assertEqual(state.LocationByUUID[uuidA].Type, "Hotbar", "INV-3: LocationByUUID should be Hotbar")
	assertEqual(state.LocationByUUID[uuidA].Slot, 1, "INV-3: LocationByUUID slot should be 1")
	assertEqual(state.LocationByUUID[uuidB].Type, "Storage", "INV-3: other item should stay in Storage")
	assertEqual(state.LocationByUUID[uuidB].Slot, 1, "INV-3: other item shifted to slot 1")
end)

runTest("Removing after storage->hotbar swap leaves no orphan", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local r1 = CoreStore.addToBackpack(state, { Id = "Wood", Amount = 1 })
	local r2 = CoreStore.addToBackpack(state, { Id = "Chainsaw", Amount = 1 })
	local uuidA = getFirstUUID(r1)
	local uuidB = getFirstUUID(r2)

	local result = CoreStore.swap(state, { Type = "Storage", Slot = 1 }, { Type = "Hotbar", Slot = 1 })
	assertTrue(result.success, "swap should succeed")

	local rem = CoreStore.remove(state, uuidA)
	assertTrue(rem.success, "remove should succeed")
	assertEqual(state.Hotbar[1], nil, "hotbar slot should be cleared (no orphan UUID)")
	assertEqual(#state.Storage, 1, "storage should keep the other item")
	assertEqual(state.Storage[1], uuidB, "storage should hold the other item")
	assertEqual(state.Items[uuidA], nil, "item should be fully removed")
end)

-- ==================== MOVE TESTS ====================

runTest("Move hotbar to empty hotbar slot", true, function()
	local state = CoreStore.new()
	local r1 = CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1, Slot = 1 })
	local uuid1 = getFirstUUID(r1)

	local result = CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 5 })
	assertTrue(result.success, "move should succeed")

	assertEqual(state.Hotbar[1], nil, "source slot should be empty")
	assertEqual(state.Hotbar[5], uuid1, "destination slot should have the item")
	assertEqual(state.LocationByUUID[uuid1].Slot, 5, "LocationByUUID should be updated")
end)

runTest("Move hotbar to storage appends", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local r1 = CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1, Slot = 1 })
	local uuid1 = getFirstUUID(r1)

	local result = CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	assertTrue(result.success, "move should succeed")

	assertEqual(state.Hotbar[1], nil, "hotbar slot should be empty")
	assertEqual(state.LocationByUUID[uuid1].Type, "Storage", "item should be in storage")
end)

runTest("Move storage to empty hotbar slot", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local r1 = CoreStore.addToBackpack(state, { Id = "Potion", Amount = 1 })
	local uuid1 = getFirstUUID(r1)
	local storageSlot = state.LocationByUUID[uuid1].Slot

	local result = CoreStore.move(state, { Type = "Storage", Slot = storageSlot }, { Type = "Hotbar", Slot = 3 })
	assertTrue(result.success, "move should succeed")

	assertEqual(state.Hotbar[3], uuid1, "hotbar slot should have the item")
	assertEqual(state.LocationByUUID[uuid1].Type, "Hotbar", "item should be in hotbar")
end)

runTest("Move storage to storage reorders", true, function()
	local state = CoreStore.new({ Limit = 100, CanStack = false })
	--[[ local r1 =]] CoreStore.addToBackpack(state, { Id = "Potion", Amount = 1 })
	--[[ local r2 =]] CoreStore.addToBackpack(state, { Id = "Scroll", Amount = 1 })

	assertTrue(#state.Storage >= 2, "should have 2 items in storage, got " .. #state.Storage)

	local uuid1 = state.Storage[1]
	local uuid2 = state.Storage[2]

	assertTrue(uuid1 ~= nil, "uuid1 should exist in storage")
	assertTrue(uuid2 ~= nil, "uuid2 should exist in storage")
	assertTrue(uuid1 ~= uuid2, "uuid1 and uuid2 should be different")

	local result = CoreStore.move(state, { Type = "Storage", Slot = 1 }, { Type = "Storage", Slot = 2 })
	assertTrue(result.success, "move should succeed, reason: " .. tostring(result.reason))

	assertEqual(state.Storage[1], uuid2, "first slot should have uuid2")
	assertEqual(state.Storage[2], uuid1, "second slot should have uuid1")
end)

runTest("Move fails when destination is occupied", true, function()
	local state = CoreStore.new()
	--[[local r1 =]] CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1, Slot = 1 })
	--[[local r2 =]] CoreStore.addToHotbar(state, { Id = "Shield", Amount = 1, Slot = 2 })

	local result = CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 2 })
	assertFalse(result.success, "move to occupied slot should fail")
	assertEqual(result.reason, "DESTINATION_OCCUPIED")
end)

runTest("Move never stacks items", true, function()
	local state = CoreStore.new({ Limit = 100, CanStack = false })
	--[[local r1 =]] CoreStore.addToBackpack(state, { Id = "Apple", Amount = 3 })
	local r2 = CoreStore.addToHotbar(state, { Id = "Apple", Amount = 2, Slot = 1 })
	local uuid1 = state.Storage[1]
	local uuid2 = getFirstUUID(r2)

	state.Settings.CanStack = true
	local fromRef = state.LocationByUUID[uuid1]
	local result = CoreStore.move(state, fromRef, { Type = "Hotbar", Slot = 2 })
	assertTrue(result.success, "move should succeed")

	local toItem = state.Items[uuid2]
	assertEqual(toItem.Amount, 2, "destination should NOT be stacked")

	local fromItem = state.Items[uuid1]
	assertEqual(fromItem.Amount, 3, "source amount should be unchanged")
end)

-- ==================== SPLIT TESTS ====================

runTest("Split divides stack into two", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local r1 = CoreStore.addToHotbar(state, { Id = "Apple", Amount = 5, Slot = 1 })
	local uuid1 = getFirstUUID(r1)

	local result = CoreStore.split(state, uuid1, 2)
	assertTrue(result.success, "split should succeed")
	assertEqual(result.sourceUUID, uuid1, "source UUID should match")
	assertTrue(result.newUUID ~= nil, "new UUID should exist")
	assertEqual(result.sourceAmount, 3, "source should have 3 remaining")
	assertEqual(result.newAmount, 2, "new stack should have 2")
end)

runTest("Split fails when amount >= item amount", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local r1 = CoreStore.addToHotbar(state, { Id = "Apple", Amount = 3, Slot = 1 })
	local uuid1 = getFirstUUID(r1)

	local result = CoreStore.split(state, uuid1, 3)
	assertFalse(result.success, "split should fail for full amount")
	assertEqual(result.reason, "CANNOT_SPLIT_FULL")
end)

runTest("Split fails when item not found", true, function()
	local state = CoreStore.new()
	local result = CoreStore.split(state, "nonexistent-uuid", 1)
	assertFalse(result.success, "split should fail for missing item")
	assertEqual(result.reason, "ITEM_NOT_FOUND")
end)

runTest("Split places new stack in hotbar first", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local r1 = CoreStore.addToBackpack(state, { Id = "Apple", Amount = 5 })
	local uuid1 = getFirstUUID(r1)

	local result = CoreStore.split(state, uuid1, 2)
	assertTrue(result.success, "split should succeed")
	assertEqual(result.newSlotType, "Hotbar", "new stack should go to hotbar first")
end)

runTest("Split with specific destination", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local r1 = CoreStore.addToBackpack(state, { Id = "Apple", Amount = 5 })
	local uuid1 = getFirstUUID(r1)

	local result = CoreStore.split(state, uuid1, 2, { Type = "Hotbar", Slot = 3 })
	assertTrue(result.success, "split should succeed")
	assertEqual(result.newSlotType, "Hotbar", "new stack should be in hotbar")
	assertEqual(result.newSlot, 3, "new stack should be in slot 3")
	assertEqual(state.Hotbar[3], result.newUUID, "hotbar slot 3 should have new UUID")
end)

runTest("Split equipped item keeps equipped state", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local r1 = CoreStore.addToHotbar(state, { Id = "Sword", Amount = 3, Slot = 1 })
	local uuid1 = getFirstUUID(r1)
	state.EquippedItemUUID = uuid1

	local result = CoreStore.split(state, uuid1, 1)
	assertTrue(result.success, "split should succeed")
	assertEqual(state.EquippedItemUUID, uuid1, "equipped UUID should remain")
end)

runTest("Split caps at MaxStackSize", true, function()
	local state = CoreStore.new({ Limit = 100, MaxStackSize = 10 })
	local r1 = CoreStore.addToHotbar(state, { Id = "Apple", Amount = 10, Slot = 1 })
	local uuid1 = getFirstUUID(r1)
	assertEqual(state.Items[uuid1].Amount, 10, "should have 10 apples")

	-- Simulate runtime MaxStackSize change (admin lowers it)
	state.Settings.MaxStackSize = 5

	local result = CoreStore.split(state, uuid1, 8)
	assertTrue(result.success, "split should succeed")
	assertEqual(result.newAmount, 5, "new stack should be capped at MaxStackSize")
	assertEqual(state.Items[uuid1].Amount, 5, "source should keep excess")
end)

runTest("Split preserves weight after cap", true, function()
	local state = CoreStore.new({ Limit = 100, MaxStackSize = 10 })
	local r1 = CoreStore.addToHotbar(state, { Id = "Apple", Amount = 10, Slot = 1 })
	local uuid1 = getFirstUUID(r1)
	local oldWeight = state.Weight
	assertEqual(oldWeight, 10, "weight should be 10 before split")

	-- Simulate runtime MaxStackSize change
	state.Settings.MaxStackSize = 5

	local result = CoreStore.split(state, uuid1, 8)
	assertTrue(result.success, "split should succeed")
	assertEqual(state.Weight, oldWeight, "weight should not change after split")
end)

runTest("Split with normal amount (no cap needed)", true, function()
	local state = CoreStore.new({ Limit = 100, MaxStackSize = 10 })
	local r1 = CoreStore.addToHotbar(state, { Id = "Apple", Amount = 5, Slot = 1 })
	local uuid1 = getFirstUUID(r1)

	local result = CoreStore.split(state, uuid1, 3)
	assertTrue(result.success, "split should succeed")
	assertEqual(result.newAmount, 3, "new stack should have 3")
	assertEqual(state.Items[uuid1].Amount, 2, "source should have 2")
end)

-- ==================== UPDATE METADATA TESTS ====================

runTest("Update metadata changes field values", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local r1 = CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Common" } })
	local uuid1 = getFirstUUID(r1)

	local result = CoreStore.updateMetadata(state, uuid1, { Rarity = "Legendary" })
	assertTrue(result.success, "update should succeed")
	assertEqual(state.Items[uuid1].Metadata.Rarity, "Legendary", "rarity should be updated")
end)

runTest("Update metadata adds new fields", true, function()
	local state = CoreStore.new()
	local r1 = CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1 })
	local uuid1 = getFirstUUID(r1)

	local result = CoreStore.updateMetadata(state, uuid1, { CustomField = "hello" })
	assertTrue(result.success, "update should succeed")
	assertEqual(state.Items[uuid1].Metadata.CustomField, "hello", "new field should be added")
end)

runTest("Update metadata ignores nil values in updates table", true, function()
	local state = CoreStore.new()
	local r1 = CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Common" } })
	local uuid1 = getFirstUUID(r1)

	local result = CoreStore.updateMetadata(state, uuid1, { Rarity = nil, Damage = 10 })
	assertTrue(result.success, "update should succeed")
	assertEqual(state.Items[uuid1].Metadata.Rarity, "Common", "nil value should not overwrite existing")
	assertEqual(state.Items[uuid1].Metadata.Damage, 10, "non-nil value should be applied")
end)

runTest("Update metadata fails for nonexistent item", true, function()
	local state = CoreStore.new()
	local result = CoreStore.updateMetadata(state, "nonexistent", { Rarity = "Legendary" })
	assertFalse(result.success, "update should fail for missing item")
	assertEqual(result.reason, "ITEM_NOT_FOUND")
end)

runTest("Update metadata does not affect weight or position", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local r1 = CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Common" } })
	local uuid1 = getFirstUUID(r1)
	local oldWeight = state.Weight
	local oldLoc = state.LocationByUUID[uuid1]

	CoreStore.updateMetadata(state, uuid1, { Rarity = "Legendary", Damage = 100 })

	assertEqual(state.Weight, oldWeight, "weight should not change")
	assertEqual(state.LocationByUUID[uuid1].Slot, oldLoc.Slot, "position should not change")
end)

-- ==================== SORT TESTS ====================

runTest("Sort by name orders alphabetically", true, function()
	local state = CoreStore.new({ Limit = 100, Sorting = false, SortOrder = "Name" })
	CoreStore.addToBackpack(state, { Id = "Sword", Amount = 1 })
	CoreStore.addToBackpack(state, { Id = "Apple", Amount = 1 })
	CoreStore.addToBackpack(state, { Id = "Potion", Amount = 1 })

	local result = CoreStore.sort(state)
	assertTrue(result.success, "sort should succeed")
	assertTrue(result.storageOrder ~= nil, "storage order should be returned")

	local items = {}
	for _, uuid in ipairs(state.Storage) do
		table.insert(items, state.Items[uuid].Id)
	end
	assertEqual(items[1], "Apple", "first should be Apple")
	assertEqual(items[2], "Potion", "second should be Potion")
	assertEqual(items[3], "Sword", "third should be Sword")
end)

runTest("Sort by rarity orders by rarity rank", true, function()
	local state = CoreStore.new({ Limit = 100, Sorting = false, SortOrder = "Rarity" })
	CoreStore.addToBackpack(state, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Legendary" } })
	CoreStore.addToBackpack(state, { Id = "Shield", Amount = 1, Metadata = { Rarity = "Common" } })
	CoreStore.addToBackpack(state, { Id = "Potion", Amount = 1, Metadata = { Rarity = "Rare" } })

	CoreStore.sort(state)

	local rarities = {}
	for _, uuid in ipairs(state.Storage) do
		table.insert(rarities, state.Items[uuid].Metadata.Rarity)
	end
	assertEqual(rarities[1], "Legendary", "first should be Legendary")
	assertEqual(rarities[2], "Rare", "second should be Rare")
	assertEqual(rarities[3], "Common", "third should be Common")
end)

runTest("Sort preserves weight and item count", true, function()
	local state = CoreStore.new({ Limit = 100, Sorting = false, SortOrder = "Name" })
	CoreStore.addToBackpack(state, { Id = "Sword", Amount = 3 })
	CoreStore.addToBackpack(state, { Id = "Apple", Amount = 5 })
	local oldWeight = state.Weight
	local oldCount = 0
	for _ in state.Items do
		oldCount += 1
	end

	CoreStore.sort(state)

	assertEqual(state.Weight, oldWeight, "weight should not change")
	local newCount = 0
	for _ in state.Items do
		newCount += 1
	end
	assertEqual(newCount, oldCount, "item count should not change")
end)

runTest("Sort with None order does nothing", true, function()
	local state = CoreStore.new({ Limit = 100, Sorting = false, SortOrder = "None" })
	CoreStore.addToBackpack(state, { Id = "Sword", Amount = 1 })
	CoreStore.addToBackpack(state, { Id = "Apple", Amount = 1 })

	local oldStorage = {}
	for i, uuid in ipairs(state.Storage) do
		oldStorage[i] = uuid
	end

	CoreStore.sort(state)

	for i, uuid in ipairs(oldStorage) do
		assertEqual(state.Storage[i], uuid, `storage[{i}] should be unchanged`)
	end
end)

runTest("Auto-sort triggers after add when Sorting = true", true, function()
	local state = CoreStore.new({ Limit = 100, Sorting = true, SortOrder = "Name" })
	CoreStore.addToBackpack(state, { Id = "Sword", Amount = 1 })
	CoreStore.addToBackpack(state, { Id = "Apple", Amount = 1 })

	local firstId = state.Items[state.Storage[1]].Id
	assertEqual(firstId, "Apple", "auto-sort should place Apple first")
end)

-- ==================== METADATA INDEX TESTS ====================

runTest("MetadataIndex tracks Rarity on add", true, function()
	local state = CoreStore.new({ Limit = 100 })
	CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Legendary" } })
	CoreStore.addToHotbar(state, { Id = "Shield", Amount = 1, Metadata = { Rarity = "Common" } })

	local rarityIndex = state.MetadataIndex.Rarity
	assertTrue(rarityIndex ~= nil, "should have Rarity index")
	assertTrue(rarityIndex.Legendary ~= nil, "should have Legendary bucket")
	assertEqual(#rarityIndex.Legendary, 1, "should have 1 Legendary item")
	assertTrue(rarityIndex.Common ~= nil, "should have Common bucket")
	assertEqual(#rarityIndex.Common, 1, "should have 1 Common item")
end)

runTest("MetadataIndex tracks Type on add", true, function()
	local state = CoreStore.new({ Limit = 100 })
	CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1, Metadata = { Type = "Weapon" } })
	CoreStore.addToHotbar(state, { Id = "Apple", Amount = 1, Metadata = { Type = "Consumable" } })

	local typeIndex = state.MetadataIndex.Type
	assertTrue(typeIndex ~= nil, "should have Type index")
	assertTrue(typeIndex.Weapon ~= nil, "should have Weapon bucket")
	assertEqual(#typeIndex.Weapon, 1, "should have 1 Weapon")
	assertTrue(typeIndex.Consumable ~= nil, "should have Consumable bucket")
	assertEqual(#typeIndex.Consumable, 1, "should have 1 Consumable")
end)

runTest("MetadataIndex removes on full remove", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local r1 = CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Legendary" } })
	local uuid1 = getFirstUUID(r1)

	local legendary = state.MetadataIndex.Rarity.Legendary
	assertEqual(#legendary, 1, "should have 1 Legendary before remove")

	CoreStore.remove(state, uuid1)

	assertEqual(#legendary, 0, "Legendary bucket should be empty after remove")
end)

runTest("MetadataIndex updates on metadata change", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local r1 = CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Common" } })
	local uuid1 = getFirstUUID(r1)

	local common = state.MetadataIndex.Rarity.Common
	assertEqual(#common, 1, "should have 1 Common")
	local legendaryBucket = state.MetadataIndex.Rarity.Legendary
	local legendaryCount = if legendaryBucket then #legendaryBucket else 0
	assertEqual(legendaryCount, 0, "should have 0 Legendary")

	CoreStore.updateMetadata(state, uuid1, { Rarity = "Legendary" })

	local newCommon = state.MetadataIndex.Rarity.Common
	local newCommonCount = if newCommon then #newCommon else 0
	assertEqual(newCommonCount, 0, "Common bucket should be empty after update")

	local newLegendary = state.MetadataIndex.Rarity.Legendary
	assertTrue(newLegendary ~= nil, "should have Legendary bucket after update")
	assertEqual(#newLegendary, 1, "should have 1 Legendary after update")
end)

runTest("find uses MetadataIndex for single field", true, function()
	local state = CoreStore.new({ Limit = 100 })
	CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Legendary" } })
	CoreStore.addToHotbar(state, { Id = "Shield", Amount = 1, Metadata = { Rarity = "Common" } })
	CoreStore.addToHotbar(state, { Id = "Axe", Amount = 1, Metadata = { Rarity = "Legendary" } })

	local results = CoreStore.find(state, { Metadata = { Rarity = "Legendary" } })
	assertEqual(#results, 2, "should find 2 Legendary items")
end)

runTest("find uses MetadataIndex for multi-field", true, function()
	local state = CoreStore.new({ Limit = 100 })
	CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Legendary", Type = "Weapon" } })
	CoreStore.addToHotbar(state, { Id = "Shield", Amount = 1, Metadata = { Rarity = "Legendary", Type = "Armor" } })
	CoreStore.addToHotbar(state, { Id = "Axe", Amount = 1, Metadata = { Rarity = "Common", Type = "Weapon" } })

	local results = CoreStore.find(state, { Metadata = { Rarity = "Legendary", Type = "Weapon" } })
	assertEqual(#results, 1, "should find 1 Legendary Weapon")
	assertEqual(results[1].Id, "Sword", "should be Sword")
end)

	runTest("find returns empty for missing metadata value", true, function()
		local state = CoreStore.new({ Limit = 100 })
		CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Common" } })

		local results = CoreStore.find(state, { Metadata = { Rarity = "Legendary" } })
		assertEqual(#results, 0, "should find 0 Legendary items")
	end)

-- ==================== DYNAMIC HOTBAR REJECTION ==================

runTest("swap Hotbar->Hotbar empty dest rejected in Dynamic mode", true, function()
	local state = CoreStore.new({ Limit = 100, HotbarType = "Dynamic" })
	CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1 })
	CoreStore.addToHotbar(state, { Id = "Shield", Amount = 1 })
	CoreStore.addToHotbar(state, { Id = "Potion", Amount = 1 })

	local result = CoreStore.swap(state, { Type = "Hotbar", Slot = 2 }, { Type = "Hotbar", Slot = 5 })
	assertEqual(result.success, false, "should fail")
	assertEqual(result.reason, "DESTINATION_UNAVAILABLE", "should be DESTINATION_UNAVAILABLE")
end)

runTest("swap Hotbar->Hotbar occupied dest works in Dynamic mode", true, function()
	local state = CoreStore.new({ Limit = 100, HotbarType = "Dynamic" })
	CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1 })
	CoreStore.addToHotbar(state, { Id = "Shield", Amount = 1 })
	CoreStore.addToHotbar(state, { Id = "Potion", Amount = 1 })

	local result = CoreStore.swap(state, { Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 3 })
	assertEqual(result.success, true, "should succeed (reorder)")

	local item1 = CoreStore.getItem(state, state.Hotbar[1])
	local item3 = CoreStore.getItem(state, state.Hotbar[3])
	assertEqual(item1.Id, "Potion", "slot 1 should now be Potion")
	assertEqual(item3.Id, "Sword", "slot 3 should now be Sword")
end)

runTest("move Hotbar->Hotbar rejected in Dynamic mode", true, function()
	local state = CoreStore.new({ Limit = 100, HotbarType = "Dynamic" })
	CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1 })
	CoreStore.addToHotbar(state, { Id = "Shield", Amount = 1 })

	local result = CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 5 })
	assertEqual(result.success, false, "should fail")
	assertEqual(result.reason, "DESTINATION_UNAVAILABLE", "should be DESTINATION_UNAVAILABLE")
end)

runTest("move Storage->Hotbar non-append slot rejected in Dynamic mode", true, function()
	local state = CoreStore.new({ Limit = 100, HotbarType = "Dynamic" })
	CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1 })
	CoreStore.addToHotbar(state, { Id = "Shield", Amount = 1 })
	CoreStore.addToBackpack(state, { Id = "Map", Amount = 1 })

	local result = CoreStore.move(state, { Type = "Storage", Slot = 1 }, { Type = "Hotbar", Slot = 5 })
	assertEqual(result.success, false, "should fail")
	assertEqual(result.reason, "DESTINATION_UNAVAILABLE", "should be DESTINATION_UNAVAILABLE")
end)

runTest("move Storage->Hotbar append slot works in Dynamic mode", true, function()
	local state = CoreStore.new({ Limit = 100, HotbarType = "Dynamic" })
	CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1 })
	CoreStore.addToHotbar(state, { Id = "Shield", Amount = 1 })
	CoreStore.addToBackpack(state, { Id = "Map", Amount = 1 })

	local result = CoreStore.move(state, { Type = "Storage", Slot = 1 }, { Type = "Hotbar", Slot = 3 })
	assertEqual(result.success, true, "should succeed (slot 3 is append position)")

	local item = CoreStore.getItem(state, state.Hotbar[3])
	assertEqual(item.Id, "Map", "slot 3 should now be Map")
end)

runTest("add ignores preferred slot in Dynamic mode", true, function()
	local state = CoreStore.new({ Limit = 100, HotbarType = "Dynamic" })
	CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1 })
	CoreStore.addToHotbar(state, { Id = "Shield", Amount = 1 })

	CoreStore.addToHotbar(state, { Id = "Potion", Amount = 1 }, 5)

	assertEqual(state.Hotbar[5], nil, "slot 5 should be nil (preferred ignored)")
	local item = CoreStore.getItem(state, state.Hotbar[3])
	assertEqual(item.Id, "Potion", "Potion should be at slot 3 (append position)")
end)

runTest("split to non-append hotbar slot rejected in Dynamic mode", true, function()
	local state = CoreStore.new({ Limit = 100, HotbarType = "Dynamic", MaxStackSize = 10 })
	CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1 })
	CoreStore.addToHotbar(state, { Id = "Arrow", Amount = 10 })

	local arrowUUID = state.Hotbar[2]
	local result = CoreStore.split(state, arrowUUID, 3, { Type = "Hotbar", Slot = 5 })
	assertEqual(result.success, false, "should fail")
	assertEqual(result.reason, "DESTINATION_UNAVAILABLE", "should be DESTINATION_UNAVAILABLE")
end)

runTest("split to append hotbar slot works in Dynamic mode", true, function()
	local state = CoreStore.new({ Limit = 100, HotbarType = "Dynamic", MaxStackSize = 10 })
	CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1 })
	CoreStore.addToHotbar(state, { Id = "Arrow", Amount = 10 })

	local arrowUUID = state.Hotbar[2]
	local result = CoreStore.split(state, arrowUUID, 3, { Type = "Hotbar", Slot = 3 })
	assertEqual(result.success, true, "should succeed (slot 3 is append)")

	local newItem = CoreStore.getItem(state, result.newUUID)
	assertEqual(newItem.Amount, 3, "new stack should have 3")
end)

-- ==================== EQUIP / UNEQUIP ==================

runTest("equip sets EquippedItemUUID", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local addResult = CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1 })
	local uuid = addResult.addedItems[1].uuid

	local result = CoreStore.equip(state, uuid)
	assertEqual(result.success, true, "should succeed")
	assertEqual(result.uuid, uuid, "should return uuid")
	assertEqual(state.EquippedItemUUID, uuid, "state should have equipped uuid")
end)

runTest("equip fails for nonexistent item", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local result = CoreStore.equip(state, "fake-uuid")
	assertEqual(result.success, false, "should fail")
	assertEqual(result.reason, "ITEM_NOT_FOUND", "should be ITEM_NOT_FOUND")
end)

runTest("equip is idempotent", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local addResult = CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1 })
	local uuid = addResult.addedItems[1].uuid

	CoreStore.equip(state, uuid)
	local result = CoreStore.equip(state, uuid)
	assertEqual(result.success, true, "should succeed (idempotent)")
	assertEqual(state.EquippedItemUUID, uuid, "still equipped")
end)

runTest("equip replaces previous equipped item", true, function()
	local state = CoreStore.new({ Limit = 100 })
	CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1 })
	CoreStore.addToHotbar(state, { Id = "Shield", Amount = 1 })
	local swordUUID = state.Hotbar[1]
	local shieldUUID = state.Hotbar[2]

	CoreStore.equip(state, swordUUID)
	local result = CoreStore.equip(state, shieldUUID)
	assertEqual(result.success, true, "should succeed")
	assertEqual(result.previousUUID, swordUUID, "should return previous uuid")
	assertEqual(state.EquippedItemUUID, shieldUUID, "shield should be equipped")
end)

runTest("unequip clears EquippedItemUUID", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local addResult = CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1 })
	local uuid = addResult.addedItems[1].uuid

	CoreStore.equip(state, uuid)
	local result = CoreStore.unequip(state)
	assertEqual(result.success, true, "should succeed")
	assertEqual(result.previousUUID, uuid, "should return previous uuid")
	assertEqual(state.EquippedItemUUID, nil, "should be nil")
end)

runTest("unequip is idempotent", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local result = CoreStore.unequip(state)
	assertEqual(result.success, true, "should succeed (idempotent)")
	assertEqual(result.previousUUID, nil, "no previous")
end)

runTest("auto-unequip on full remove", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local addResult = CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1 })
	local uuid = addResult.addedItems[1].uuid

	CoreStore.equip(state, uuid)
	assertEqual(state.EquippedItemUUID, uuid, "should be equipped")

	CoreStore.remove(state, uuid, 1)
	assertEqual(state.EquippedItemUUID, nil, "should be auto-unequipped")
end)

-- ==================== BOUNDS + INDEX REGRESSION TESTS ====================

runTest("Swap to out-of-range storage slot fails", true, function()
	local state = CoreStore.new({ Limit = 100 })
	CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1, Slot = 1 })

	local result = CoreStore.swap(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 99 })
	assertFalse(result.success, "swap to OOB storage slot should fail")
	assertEqual(result.reason, "INVALID_STORAGE_SLOT", "should return INVALID_STORAGE_SLOT")
	assertEqual(state.Hotbar[1] ~= nil, true, "source item must not be touched")
end)

runTest("Move to out-of-range storage slot fails", true, function()
	local state = CoreStore.new({ Limit = 100 })
	CoreStore.addToBackpack(state, { Id = "Potion", Amount = 1 })

	local result = CoreStore.move(state, { Type = "Storage", Slot = 1 }, { Type = "Storage", Slot = 5 })
	assertFalse(result.success, "move to OOB storage slot should fail")
	assertEqual(result.reason, "INVALID_STORAGE_SLOT", "should return INVALID_STORAGE_SLOT")
	assertEqual(#state.Storage, 1, "storage must be untouched")
end)

runTest("Move to append storage slot keeps storage packed", true, function()
	local state = CoreStore.new({ Limit = 100 })
	CoreStore.addToBackpack(state, { Id = "Potion", Amount = 1 })
	CoreStore.addToBackpack(state, { Id = "Scroll", Amount = 1 })
	local uuid1 = state.Storage[1]
	local uuid2 = state.Storage[2]

	local result = CoreStore.move(state, { Type = "Storage", Slot = 1 }, { Type = "Storage", Slot = 3 })
	assertTrue(result.success, "append move should succeed, reason: " .. tostring(result.reason))

	assertEqual(#state.Storage, 2, "storage must stay packed (no holes)")
	assertEqual(state.Storage[1], uuid2, "slot 1 should hold the second item")
	assertEqual(state.Storage[2], uuid1, "slot 2 should hold the moved item")
	assertEqual(state.LocationByUUID[uuid1].Slot, 2, "INV-3: moved item loc should be slot 2")
	assertEqual(state.LocationByUUID[uuid2].Slot, 1, "INV-3: other item loc should be slot 1")
end)

runTest("Add to out-of-range storage slot fails", true, function()
	local state = CoreStore.new({ Limit = 100 })
	CoreStore.addToBackpack(state, { Id = "Potion", Amount = 1 })

	local result = CoreStore.add(state, { Id = "Scroll", Amount = 1 }, {
		Placement = "Slot",
		SlotRef = { Type = "Storage", Slot = 7 },
	})
	assertFalse(result.success, "add to OOB storage slot should fail")
	assertEqual(result.reason, "INVALID_SLOT", "should return INVALID_SLOT")
	assertEqual(#state.Storage, 1, "storage must be untouched")
end)

runTest("StackOnSwap absorption cleans MetadataIndex", true, function()
	-- CanStack starts false so the two adds create genuinely separate stacks
	-- instead of silently merging at add-time (which would leave nothing for
	-- StackOnSwap to absorb and make this test pass vacuously).
	local state = CoreStore.new({ Limit = 100, StackOnSwap = true, CanStack = false, MaxStackSize = 10 })
	CoreStore.addToHotbar(state, { Id = "Sword", Amount = 2, Slot = 1, Metadata = { Rarity = "Epic" } })
	CoreStore.addToHotbar(state, { Id = "Sword", Amount = 2, Slot = 2, Metadata = { Rarity = "Epic" } })

	assertEqual(#state.MetadataIndex.Rarity.Epic, 2, "expected 2 separate indexed stacks before swap")

	-- Enable stacking only for the swap itself (same pattern as "StackOnSwap
	-- stacks items when enabled" above).
	state.Settings.CanStack = true
	local result = CoreStore.swap(state, { Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 2 })
	assertTrue(result.success, "stacking swap should succeed")

	-- Check the MetadataIndex bucket directly — find() defensively filters
	-- dead UUIDs against state.Items, so it can mask a leaked index entry.
	assertEqual(#state.MetadataIndex.Rarity.Epic, 1, "absorbed item UUID must be evicted from MetadataIndex")

	local found = CoreStore.find(state, { Metadata = { Rarity = "Epic" } })
	assertEqual(#found, 1, "find() should also report only 1 Epic item")
end)

runTest("Split indexes metadata and cleans up on rollback", true, function()
	local state = CoreStore.new({ Limit = 100 })
	local addRes = CoreStore.addToHotbar(state, { Id = "Apple", Amount = 5, Slot = 1, Metadata = { Rarity = "Rare" } })
	local uuid = getFirstUUID(addRes)

	local splitResult = CoreStore.split(state, uuid, 2)
	assertTrue(splitResult.success, "split should succeed")

	local found = CoreStore.find(state, { Rarity = "Rare" })
	local count = 0
	for _, _ in found do
		count += 1
	end
	assertEqual(count, 2, "both stacks should be indexed after split")

	local dynamic = CoreStore.new({ Limit = 100, HotbarType = "Dynamic" })
	local addRes2 = CoreStore.addToHotbar(dynamic, { Id = "Apple", Amount = 5, Metadata = { Rarity = "Rare" } })
	local uuid2 = getFirstUUID(addRes2)

	local failed = CoreStore.split(dynamic, uuid2, 2, { Type = "Hotbar", Slot = 3 })
	assertFalse(failed.success, "split to non-append dynamic slot should fail")

	local found2 = CoreStore.find(dynamic, { Rarity = "Rare" })
	local count2 = 0
	for _, _ in found2 do
		count2 += 1
	end
	assertEqual(count2, 1, "rolled-back split must not leave a stale index entry")
end)

-- ==================== RESULTS ==================

print()
print(`============================================`)
print(`  Results: {passCount} passed, {failCount} failed, {totalTests} total`)
print(`============================================`)
