--@author: yyumchi
--@date: 2026-08-09
--[[@description:
	TEMP CoreStore stress/speed battery — NOT for git.
	Scans niche edge cases + verifies ALL invariants (INV-1..18 +
	MetadataIndex consistency) after every mutating operation.
	Run: lune run src/server/tests/corestore_speedtest_temp.luau
]]
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

local INDEXED_FIELDS: { string } = { "Rarity", "Type" }

-----------------------------
-- HARNESS --
-----------------------------

local function runTest(name: string, fn: () -> ())
	totalTests += 1
	local ok, err = pcall(fn)
	if ok then
		passCount += 1
		print(`  \27[32m[PASS]\27[0m {name}`)
	else
		failCount += 1
		print(`  \27[31m[FAIL]\27[0m {name} ({err})`)
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

local function assertResult(result: any, message: string?)
	assertTrue(result.success ~= false, `{message or "op"} | reason: {tostring(result.reason)}`)
end

-----------------------------
-- INVARIANT CHECKER --
-----------------------------

local function verifyInvariants(state: any): { string }
	local violations: { string } = {}

	-- INV-1: UUID Ownership (every slot reference resolves to an item)
	for slot, uuid in state.Hotbar do
		if uuid and not state.Items[uuid] then
			table.insert(violations, `Hotbar[{slot}] references missing UUID {uuid}`)
		end
	end
	for index, uuid in state.Storage do
		if not state.Items[uuid] then
			table.insert(violations, `Storage[{index}] references missing UUID {uuid}`)
		end
	end

	-- INV-2: Single Location (no dup refs; every item placed exactly once)
	local seen: { [any]: number } = {}
	for _, uuid in state.Hotbar do
		if uuid then
			seen[uuid] = (seen[uuid] or 0) + 1
			if seen[uuid] > 1 then
				table.insert(violations, `UUID {uuid} referenced multiple times in Hotbar`)
			end
		end
	end
	for _, uuid in state.Storage do
		seen[uuid] = (seen[uuid] or 0) + 1
		if seen[uuid] > 1 then
			table.insert(violations, `UUID {uuid} exists in both Hotbar and Storage`)
		end
	end
	for uuid in state.Items do
		if not seen[uuid] then
			table.insert(violations, `Item {uuid} is not placed in any slot`)
		end
	end

	-- INV-3: LocationByUUID Accuracy
	for uuid, loc in state.LocationByUUID do
		if not state.Items[uuid] then
			table.insert(violations, `LocationByUUID has stale entry for {uuid}`)
		elseif loc.Type == "Hotbar" then
			if state.Hotbar[loc.Slot] ~= uuid then
				table.insert(violations, `LocationByUUID[{uuid}] says Hotbar[{loc.Slot}] but actual is {tostring(state.Hotbar[loc.Slot])}`)
			end
		elseif loc.Type == "Storage" then
			if state.Storage[loc.Slot] ~= uuid then
				table.insert(violations, `LocationByUUID[{uuid}] says Storage[{loc.Slot}] but actual is {tostring(state.Storage[loc.Slot])}`)
			end
		end
	end

	-- INV-4,5: ItemsByID Consistency
	for itemId, uuids in state.ItemsByID do
		for _, uuid in uuids do
			if not state.Items[uuid] then
				table.insert(violations, `ItemsByID[{itemId}] has stale UUID {uuid}`)
			elseif state.Items[uuid].Id ~= itemId then
				table.insert(violations, `ItemsByID[{itemId}] has UUID {uuid} with wrong Id {state.Items[uuid].Id}`)
			end
		end
	end
	for uuid, item in state.Items do
		local idList = state.ItemsByID[item.Id]
		if not idList then
			table.insert(violations, `Items[{uuid}] has Id {item.Id} but ItemsByID has no entry`)
		else
			local found = false
			for _, id in idList do
				if id == uuid then
					found = true
					break
				end
			end
			if not found then
				table.insert(violations, `Items[{uuid}] has Id {item.Id} but not in ItemsByID list`)
			end
		end
	end

	-- INV-6: Weight Accuracy
	local expectedWeight = 0
	for _, item in state.Items do
		expectedWeight += item.Amount
	end
	if state.Weight ~= expectedWeight then
		table.insert(violations, `Weight is {state.Weight} but expected {expectedWeight}`)
	end

	-- INV-8: Hotbar Bounds
	for slot, uuid in state.Hotbar do
		if uuid and (slot < 1 or slot > state.Settings.MaxHotbarSlots) then
			table.insert(violations, `Hotbar key {slot} out of bounds (max {state.Settings.MaxHotbarSlots})`)
		end
	end

	-- INV-9: Storage Contiguity (no holes)
	local storageKeys: { [number]: boolean } = {}
	local storageMax = 0
	local storageCount = 0
	for index, _ in state.Storage do
		storageKeys[index] = true
		storageMax = math.max(storageMax, index)
		storageCount += 1
	end
	for i = 1, storageMax do
		if not storageKeys[i] then
			table.insert(violations, `Storage hole at index {i}`)
		end
	end
	if storageCount ~= #state.Storage then
		table.insert(violations, "Storage contiguity broken (len mismatch)")
	end

	-- INV-10: Dynamic hotbar must be packed
	if state.Settings.HotbarType == "Dynamic" then
		local seenNil = false
		for slot = 1, state.Settings.MaxHotbarSlots do
			if state.Hotbar[slot] == nil then
				seenNil = true
			elseif seenNil then
				table.insert(violations, `Dynamic hotbar has item at slot {slot} after a hole`)
			end
		end
	end

	-- INV-11: Equipped Validity
	if state.EquippedItemUUID and not state.Items[state.EquippedItemUUID] then
		table.insert(violations, `EquippedItemUUID references missing item {state.EquippedItemUUID}`)
	end

	-- INV-18: MaxStackSize Enforcement
	for uuid, item in state.Items do
		if item.Amount > state.Settings.MaxStackSize then
			table.insert(violations, `Items[{uuid}] has Amount {item.Amount} exceeding MaxStackSize {state.Settings.MaxStackSize}`)
		end
	end

	-- MetadataIndex: no stale entries + every indexed item is in its bucket
	for _, field in INDEXED_FIELDS do
		local index = state.MetadataIndex[field]
		if index then
			for strValue, bucket in index do
				for _, uuid in bucket do
					local item = state.Items[uuid]
					if not item then
						table.insert(violations, `MetadataIndex[{field}][{strValue}] has stale UUID {uuid}`)
					elseif tostring(item.Metadata[field]) ~= strValue then
						table.insert(violations, `MetadataIndex[{field}][{strValue}] has UUID {uuid} whose value is {tostring(item.Metadata[field])}`)
					end
				end
			end
		end
		for uuid, item in state.Items do
			local value = item.Metadata[field]
			if value ~= nil then
				local bucket = index and index[tostring(value)]
				if not bucket then
					table.insert(violations, `Item {uuid} has {field}={tostring(value)} but no MetadataIndex bucket`)
				else
					local found = false
					for _, bUuid in bucket do
						if bUuid == uuid then
							found = true
							break
						end
					end
					if not found then
						table.insert(violations, `Item {uuid} has {field}={tostring(value)} but not in MetadataIndex bucket`)
					end
				end
			end
		end
	end

	return violations
end

local function expectInvariants(state: any)
	local violations = verifyInvariants(state)
	if #violations > 0 then
		error(`INVARIANT VIOLATION: {violations[1]}`)
	end
end

-----------------------------
-- HELPERS --
-----------------------------

local function addAndGetUUID(state: any, itemData: any): string
	local result = CoreStore.add(state, itemData)
	assertResult(result, "add")
	if result.addedItems and result.addedItems[1] then
		return result.addedItems[1].uuid
	end
	local found = CoreStore.find(state, itemData.Id :: string)
	assertTrue(found[1] ~= nil, "expected existing stack after stacking")
	return found[1].UUID
end

local function itemCount(state: any): number
	local count = 0
	for _ in state.Items do
		count += 1
	end
	return count
end

local function slotOccurrences(state: any, uuid: string): number
	local count = 0
	for _, slotUUID in state.Hotbar do
		if slotUUID == uuid then count += 1 end
	end
	for _, slotUUID in state.Storage do
		if slotUUID == uuid then count += 1 end
	end
	return count
end

local function totalAmountOfId(state: any, itemId: string): number
	local total = 0
	local found = CoreStore.find(state, itemId)
	for _, item in found do
		total += item.Amount
	end
	return total
end

-- deterministic LCG (avoid env RNG differences)
local seed = 123456789
local function rand(): number
	seed = (seed * 1103515245 + 12345) % 2147483648
	return seed / 2147483648
end
local function randInt(n: number): number
	return math.floor(rand() * n) + 1
end

-----------------------------
-- MAIN --
-----------------------------

-- ============ HARNESS SELF-TEST ============

runTest("verifyInvariants passes on a fresh state", function()
	local state = CoreStore.new()
	expectInvariants(state)
end)

runTest("verifyInvariants detects a deliberately corrupted state", function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, { Id = "X", Amount = 1 })
	state.Hotbar[2] = uuid
	state.LocationByUUID[uuid] = { Type = "Hotbar", Slot = 2 }
	state.Weight = 999
	local violations = verifyInvariants(state)
	assertTrue(#violations > 0, "checker should flag corruption")
end)

-- ============ ADD / PLACEMENT ============

runTest("add goes to hotbar first (Auto placement)", function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, { Id = "Sword", Amount = 1 })
	assertEqual(state.Hotbar[1], uuid)
	assertEqual(state.LocationByUUID[uuid].Type, "Hotbar")
	expectInvariants(state)
end)

runTest("hotbar fills before storage spills", function()
	local state = CoreStore.new()
	local lastUuid
	for i = 1, 11 do
		lastUuid = addAndGetUUID(state, { Id = `Rock{i}`, Amount = 1 })
	end
	assertEqual(#state.Storage, 1, "exactly one item in storage")
	assertEqual(state.Storage[1], lastUuid, "the 11th item is in storage")
	assertEqual(CoreStore.getHotbarItemCount(state), 10)
	expectInvariants(state)
end)

runTest("addToBackpack skips hotbar entirely", function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, { Id = "Gift", Amount = 1 })
	local r = CoreStore.addToBackpack(state, { Id = "Gift2", Amount = 1 })
	local uuid2 = r.addedItems[1].uuid
	assertEqual(CoreStore.getHotbarItemCount(state), 1, "hotbar untouched by backpack add")
	assertEqual(CoreStore.getStorageItemCount(state), 1)
	assertEqual(state.LocationByUUID[uuid].Type, "Hotbar")
	assertEqual(state.LocationByUUID[uuid2].Type, "Storage")
	expectInvariants(state)
end)

runTest("addToHotbar places in a specific slot", function()
	local state = CoreStore.new()
	local r = CoreStore.addToHotbar(state, { Id = "Sword", Amount = 1 }, 7)
	assertResult(r)
	assertEqual(state.Hotbar[7], r.addedItems[1].uuid)
	expectInvariants(state)
end)

runTest("addToHotbar on occupied slot fails with no state change", function()
	local state = CoreStore.new()
	addAndGetUUID(state, { Id = "Sword", Amount = 1 }) -- hotbar[1]
	local before = itemCount(state)
	local r = CoreStore.addToHotbar(state, { Id = "Axe", Amount = 1 }, 1)
	assertFalse(r.success)
	assertEqual(r.reason, "HOTBAR_SLOT_OCCUPIED")
	assertEqual(itemCount(state), before, "no item leaked")
	expectInvariants(state)
end)

runTest("addToSlot places at exact hotbar slot", function()
	local state = CoreStore.new()
	local r = CoreStore.addToSlot(state, { Id = "Sword", Amount = 1 }, { Type = "Hotbar", Slot = 4 })
	assertResult(r)
	assertEqual(state.Hotbar[4], r.addedItems[1].uuid)
	expectInvariants(state)
end)

runTest("addToSlot hotbar out of bounds fails cleanly", function()
	local state = CoreStore.new()
	local before = itemCount(state)
	local r = CoreStore.addToSlot(state, { Id = "Sword", Amount = 1 }, { Type = "Hotbar", Slot = 99 })
	assertFalse(r.success)
	assertEqual(itemCount(state), before, "no item leaked")
	expectInvariants(state)
end)

runTest("addToSlot hotbar occupied fails cleanly", function()
	local state = CoreStore.new()
	addAndGetUUID(state, { Id = "Sword", Amount = 1 })
	local before = itemCount(state)
	local r = CoreStore.addToSlot(state, { Id = "Axe", Amount = 1 }, { Type = "Hotbar", Slot = 1 })
	assertFalse(r.success)
	assertEqual(itemCount(state), before, "no item leaked")
	expectInvariants(state)
end)

runTest("addToSlot storage middle index shifts and fixes LocationByUUID", function()
	local state = CoreStore.new()
	local uuidA = addAndGetUUID(state, { Id = "A", Amount = 1 }) -- storage[1]
	local r = CoreStore.addToSlot(state, { Id = "B", Amount = 1 }, { Type = "Storage", Slot = 1 })
	assertResult(r)
	local uuidB = r.addedItems[1].uuid
	assertEqual(state.Storage[1], uuidB)
	assertEqual(state.Storage[2], uuidA)
	assertEqual(state.LocationByUUID[uuidA].Slot, 2, "shifted item LocationByUUID updated")
	assertEqual(state.LocationByUUID[uuidB].Slot, 1)
	expectInvariants(state)
end)

runTest("addToSlot storage out-of-range fails cleanly (no crash, no hole)", function()
	local state = CoreStore.new()
	local before = itemCount(state)
	local r = CoreStore.addToSlot(state, { Id = "Sword", Amount = 1 }, { Type = "Storage", Slot = 99 })
	assertFalse(r.success, "out-of-range storage placement must be rejected")
	assertEqual(itemCount(state), before, "no item leaked")
	expectInvariants(state)
end)

runTest("add stacks across multiple stacks then spills to a new stack", function()
	local state = CoreStore.new()
	local uuid1 = addAndGetUUID(state, { Id = "Apple", Amount = 4 }) -- hotbar[1], room 1
	local r = CoreStore.add(state, { Id = "Apple", Amount = 2 })
	assertResult(r)
	assertEqual(state.Items[uuid1].Amount, 5, "first stack filled")
	local newUuid = r.addedItems[1].uuid
	assertEqual(state.Items[newUuid].Amount, 1, "spill became new stack")
	assertEqual(r.addedAmount, 2)
	expectInvariants(state)
end)

runTest("blacklisted rarity never stacks (two separate stacks)", function()
	local state = CoreStore.new()
	local r1 = CoreStore.add(state, { Id = "Axe", Amount = 2, Metadata = { Rarity = "Legendary" } })
	local r2 = CoreStore.add(state, { Id = "Axe", Amount = 3, Metadata = { Rarity = "Legendary" } })
	assertEqual(r1.addedItems[1] ~= nil and r2.addedItems[1] ~= nil, true, "both adds create new stacks")
	assertEqual(itemCount(state), 2, "two separate stacks")
	expectInvariants(state)
end)

runTest("mismatched required fields never stack", function()
	local state = CoreStore.new()
	local r1 = CoreStore.add(state, { Id = "Potion", Amount = 2, Metadata = { Type = "Heal" } })
	local r2 = CoreStore.add(state, { Id = "Potion", Amount = 3, Metadata = { Type = "Mana" } })
	assertEqual(itemCount(state), 2, "two separate stacks")
	expectInvariants(state)
end)

runTest("add amount 0 -> INVALID_AMOUNT", function()
	local state = CoreStore.new()
	local before = itemCount(state)
	local r = CoreStore.add(state, { Id = "X", Amount = 0 })
	assertFalse(r.success)
	assertEqual(r.reason, "INVALID_AMOUNT")
	assertEqual(itemCount(state), before)
	expectInvariants(state)
end)

runTest("add negative amount -> INVALID_AMOUNT", function()
	local state = CoreStore.new()
	local before = itemCount(state)
	local r = CoreStore.add(state, { Id = "X", Amount = -5 })
	assertFalse(r.success)
	assertEqual(r.reason, "INVALID_AMOUNT")
	assertEqual(itemCount(state), before)
	expectInvariants(state)
end)

runTest("add NaN amount -> INVALID_AMOUNT", function()
	local state = CoreStore.new()
	local before = itemCount(state)
	local r = CoreStore.add(state, { Id = "X", Amount = 0 / 0 })
	assertFalse(r.success)
	assertEqual(itemCount(state), before)
	expectInvariants(state)
end)

runTest("add fractional amount is allowed and tracked in weight", function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, { Id = "Slime", Amount = 3.5 })
	assertEqual(state.Items[uuid].Amount, 3.5)
	assertEqual(state.Weight, 3.5)
	expectInvariants(state)
end)

runTest("add string amount is normalized", function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, { Id = "Coin", Amount = "7" :: any })
	assertEqual(state.Items[uuid].Amount, 7)
	expectInvariants(state)
end)

runTest("add over capacity returns PARTIAL with correct overflow", function()
	local state = CoreStore.new({ Limit = 10 })
	local r = CoreStore.add(state, { Id = "Wood", Amount = 25 })
	assertResult(r)
	assertEqual(r.addedAmount, 10)
	assertEqual(r.overflow, 15)
	assertEqual(r.reason, "PARTIAL")
	assertEqual(state.Weight, 10)
	expectInvariants(state)
end)

runTest("add to exactly-full state -> FULL, weight unchanged", function()
	local state = CoreStore.new({ Limit = 10 })
	CoreStore.add(state, { Id = "Wood", Amount = 10 })
	local before = state.Weight
	local r = CoreStore.add(state, { Id = "Stone", Amount = 1 })
	assertFalse(r.success)
	assertEqual(r.reason, "FULL")
	assertEqual(state.Weight, before)
	expectInvariants(state)
end)

runTest("amount falls back to metadata.Amount then metadata.StackAmount", function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, { Id = "P", Metadata = { Amount = 3 } })
	assertEqual(state.Items[uuid].Amount, 3)
	local uuid2 = addAndGetUUID(state, { Id = "Q", Metadata = { StackAmount = 4 } })
	assertEqual(state.Items[uuid2].Amount, 4)
	expectInvariants(state)
end)

runTest("no amount anywhere defaults to 1", function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, { Id = "Nothing" })
	assertEqual(state.Items[uuid].Amount, 1)
	expectInvariants(state)
end)

runTest("large add creates correctly capped stacks", function()
	local state = CoreStore.new({ Limit = 0, MaxStackSize = 5 })
	local r = CoreStore.add(state, { Id = "Bulk", Amount = 27 })
	assertResult(r)
	assertEqual(#r.addedItems, 6, "5+5+5+5+5+2")
	assertEqual(state.Items[r.addedItems[6].uuid].Amount, 2, "last stack has remainder")
	assertEqual(state.Weight, 27)
	expectInvariants(state)
end)

runTest("BackpackEnabled=false: hotbar works, storage rejected, auto falls back", function()
	local state = CoreStore.new({ BackpackEnabled = false, MaxHotbarSlots = 3 })
	local r1 = CoreStore.add(state, { Id = "A", Amount = 1 })
	assertResult(r1)
	assertEqual(r1.addedItems[1].slotType, "Hotbar")
	for i = 2, 3 do
		CoreStore.add(state, { Id = `A{i}`, Amount = 1 })
	end
	local r4 = CoreStore.add(state, { Id = "D", Amount = 1 })
	assertFalse(r4.success, "no room with backpack disabled")
	expectInvariants(state)
end)

-- ============ REMOVE ============

runTest("partial remove reduces amount, keeps slot and indexes", function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, { Id = "Apple", Amount = 5 })
	local r = CoreStore.remove(state, uuid, 2)
	assertResult(r)
	assertEqual(state.Items[uuid].Amount, 3)
	assertEqual(state.Weight, 3)
	assertEqual(r.remaining, 3)
	expectInvariants(state)
end)

runTest("remove with amount >= stack amount is a full removal", function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, { Id = "Apple", Amount = 5 })
	local r = CoreStore.remove(state, uuid, 99)
	assertResult(r)
	assertEqual(state.Items[uuid], nil)
	assertEqual(state.Weight, 0)
	expectInvariants(state)
end)

runTest("remove from middle of storage shifts left and fixes LocationByUUID", function()
	local state = CoreStore.new()
	local uuids: { string } = {}
	for i = 1, 4 do
		table.insert(uuids, addAndGetUUID(state, { Id = `S{i}`, Amount = 1 }))
	end
	-- storage = [S1, S2, S3, S4]
	local r = CoreStore.remove(state, uuids[2])
	assertResult(r)
	assertEqual(state.Storage[2], uuids[3], "items shifted left")
	assertEqual(state.Storage[3], uuids[4])
	assertEqual(state.LocationByUUID[uuids[3]].Slot, 2)
	assertEqual(state.LocationByUUID[uuids[4]].Slot, 3)
	assertEqual(state.LocationByUUID[uuids[2]], nil, "no stale LocationByUUID")
	expectInvariants(state)
end)

runTest("remove nonexistent -> ITEM_NOT_FOUND, state untouched", function()
	local state = CoreStore.new()
	addAndGetUUID(state, { Id = "A", Amount = 1 })
	local before = state.Weight
	local r = CoreStore.remove(state, "not-a-uuid")
	assertFalse(r.success)
	assertEqual(r.reason, "ITEM_NOT_FOUND")
	assertEqual(state.Weight, before)
	expectInvariants(state)
end)

runTest("remove amount 0 -> INVALID_AMOUNT", function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, { Id = "A", Amount = 3 })
	local r = CoreStore.remove(state, uuid, 0)
	assertFalse(r.success)
	assertEqual(state.Items[uuid].Amount, 3)
	expectInvariants(state)
end)

runTest("remove last storage item empties storage cleanly", function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, { Id = "Solo", Amount = 1 }) -- hotbar[1]
	local r = CoreStore.remove(state, uuid)
	assertResult(r)
	assertEqual(CoreStore.getStorageItemCount(state), 0)
	expectInvariants(state)
end)

runTest("partial remove of equipped item keeps it equipped", function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, { Id = "Sword", Amount = 5 })
	CoreStore.equip(state, uuid)
	CoreStore.remove(state, uuid, 2)
	assertEqual(state.EquippedItemUUID, uuid)
	assertEqual(state.Items[uuid].Amount, 3)
	expectInvariants(state)
end)

runTest("full remove of equipped item auto-unequips and cleans all indexes", function()
	local state = CoreStore.new()
	local uuid = addAndGetUUID(state, { Id = "Sword", Amount = 3, Metadata = { Rarity = "Epic" } })
	CoreStore.equip(state, uuid)
	CoreStore.remove(state, uuid)
	assertEqual(state.EquippedItemUUID, nil)
	assertEqual(state.Items[uuid], nil)
	assertEqual(state.ItemsByID["Sword"], nil, "ItemsByID bucket removed")
	assertEqual(state.LocationByUUID[uuid], nil)
	assertEqual(state.MetadataIndex["Rarity"]["Epic"], nil, "MetadataIndex bucket removed")
	expectInvariants(state)
end)

runTest("removeBySlot works on hotbar and storage", function()
	local state = CoreStore.new()
	local uuid1 = addAndGetUUID(state, { Id = "H", Amount = 2 }) -- hotbar[1]
	local uuid2 = addAndGetUUID(state, { Id = "S", Amount = 3 }) -- hotbar[2]
	local r1 = CoreStore.removeBySlot(state, "Hotbar", 1, 1)
	assertResult(r1)
	assertEqual(state.Items[uuid1].Amount, 1)
	local r2 = CoreStore.removeBySlot(state, "Hotbar", 2)
	assertResult(r2)
	assertEqual(state.Items[uuid2], nil)
	expectInvariants(state)
end)

runTest("removeBySlot on empty slot -> SLOT_EMPTY", function()
	local state = CoreStore.new()
	local r = CoreStore.removeBySlot(state, "Hotbar", 1)
	assertFalse(r.success)
	assertEqual(r.reason, "SLOT_EMPTY")
	expectInvariants(state)
end)

runTest("remove evicts only the target UUID from a shared MetadataIndex bucket", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1, Metadata = { Rarity = "Common" } })
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1, Metadata = { Rarity = "Common" } })
	CoreStore.remove(state, u1)
	assertEqual(#state.MetadataIndex["Rarity"]["Common"], 1)
	assertEqual(state.MetadataIndex["Rarity"]["Common"][1], u2)
	expectInvariants(state)
end)

-- ============ SWAP ============

runTest("swap hotbar<->hotbar exchanges positions", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 })
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 })
	local r = CoreStore.swap(state, { Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 2 })
	assertResult(r)
	assertEqual(state.Hotbar[1], u2)
	assertEqual(state.Hotbar[2], u1)
	expectInvariants(state)
end)

runTest("swap hotbar->hotbar into empty slot (Static) works", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 }) -- slot 1
	local r = CoreStore.swap(state, { Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 5 })
	assertResult(r)
	assertEqual(state.Hotbar[1], nil)
	assertEqual(state.Hotbar[5], u1)
	assertEqual(state.LocationByUUID[u1].Slot, 5)
	expectInvariants(state)
end)

runTest("swap storage<->storage exchanges positions", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 }) -- hotbar[1]
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 }) -- hotbar[2]
	CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	CoreStore.move(state, { Type = "Hotbar", Slot = 2 }, { Type = "Storage", Slot = 1 })
	-- storage = [A, B]
	local r = CoreStore.swap(state, { Type = "Storage", Slot = 1 }, { Type = "Storage", Slot = 2 })
	assertResult(r)
	assertEqual(state.Storage[1], u2)
	assertEqual(state.Storage[2], u1)
	expectInvariants(state)
end)

runTest("swap hotbar->storage occupied exchanges across containers", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 }) -- hotbar[1]
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 }) -- hotbar[2]
	CoreStore.move(state, { Type = "Hotbar", Slot = 2 }, { Type = "Storage", Slot = 1 })
	-- hotbar[1]=A, storage[1]=B
	local r = CoreStore.swap(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	assertResult(r)
	assertEqual(state.Hotbar[1], u2)
	assertEqual(state.Storage[1], u1)
	expectInvariants(state)
end)

runTest("swap hotbar->storage empty dest appends to storage", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 }) -- hotbar[1]
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 }) -- hotbar[2]
	CoreStore.move(state, { Type = "Hotbar", Slot = 2 }, { Type = "Storage", Slot = 1 })
	-- storage=[B], hotbar[1]=A, empty storage at index 2
	local r = CoreStore.swap(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 2 })
	assertResult(r)
	assertEqual(state.Hotbar[1], nil)
	assertEqual(state.Storage[2], u1)
	assertEqual(state.LocationByUUID[u1].Type, "Storage")
	expectInvariants(state)
end)

runTest("swap storage->hotbar occupied exchanges across containers", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 }) -- hotbar[1]
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 }) -- hotbar[2]
	CoreStore.move(state, { Type = "Hotbar", Slot = 2 }, { Type = "Storage", Slot = 1 })
	-- hotbar[1]=A, storage[1]=B
	local r = CoreStore.swap(state, { Type = "Storage", Slot = 1 }, { Type = "Hotbar", Slot = 1 })
	assertResult(r)
	assertEqual(state.Hotbar[1], u2)
	assertEqual(state.Storage[1], u1)
	expectInvariants(state)
end)

runTest("swap storage->hotbar empty dest moves item, no duplicates (INV-2)", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 }) -- hotbar[1]
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 }) -- hotbar[2]
	CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	-- storage=[A,B], hotbar empty at slot 1
	local r = CoreStore.swap(state, { Type = "Storage", Slot = 1 }, { Type = "Hotbar", Slot = 1 })
	assertResult(r)
	assertEqual(state.Hotbar[1], u1)
	assertEqual(slotOccurrences(state, u1), 1, "item referenced exactly once")
	assertEqual(#state.Storage, 1)
	assertEqual(state.Storage[1], u2)
	expectInvariants(state)
end)

runTest("swap same slot is a no-op success", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 })
	local r = CoreStore.swap(state, { Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 1 })
	assertResult(r)
	assertEqual(state.Hotbar[1], u1)
	expectInvariants(state)
end)

runTest("swap from empty source -> SOURCE_EMPTY", function()
	local state = CoreStore.new()
	local r = CoreStore.swap(state, { Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 2 })
	assertFalse(r.success)
	assertEqual(r.reason, "SOURCE_EMPTY")
	expectInvariants(state)
end)

runTest("StackOnSwap full absorption destroys source and cleans all indexes", function()
	local state = CoreStore.new({ StackOnSwap = true, CanStack = false, MaxStackSize = 10, Limit = 100 })
	local r1 = CoreStore.add(state, { Id = "Apple", Amount = 3, Metadata = { Rarity = "Common" } })
	local u1 = r1.addedItems[1].uuid
	local r2 = CoreStore.addToBackpack(state, { Id = "Apple", Amount = 2, Metadata = { Rarity = "Common" } })
	local u2 = r2.addedItems[1].uuid
	state.Settings.CanStack = true
	local r = CoreStore.swap(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	assertResult(r)
	assertEqual(state.Items[u2].Amount, 5, "destination absorbed source amount")
	assertEqual(state.Items[u1], nil, "source fully absorbed")
	assertEqual(state.ItemsByID["Apple"][1], u2, "ItemsByID cleaned")
	assertEqual(state.LocationByUUID[u1], nil, "LocationByUUID cleaned")
	assertEqual(state.MetadataIndex["Rarity"]["Common"][1], u2, "MetadataIndex must only hold the survivor")
	expectInvariants(state)
end)

runTest("StackOnSwap partial absorption keeps both, slots unchanged", function()
	local state = CoreStore.new({ StackOnSwap = true, CanStack = false, MaxStackSize = 10, Limit = 100 })
	local r1 = CoreStore.add(state, { Id = "Apple", Amount = 6, Metadata = { Rarity = "Common" } })
	local u1 = r1.addedItems[1].uuid
	local r2 = CoreStore.addToBackpack(state, { Id = "Apple", Amount = 6, Metadata = { Rarity = "Common" } })
	local u2 = r2.addedItems[1].uuid
	state.Settings.CanStack = true
	local r = CoreStore.swap(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	assertResult(r)
	assertEqual(state.Items[u2].Amount, 10, "destination capped at max")
	assertEqual(state.Items[u1].Amount, 2, "source keeps remainder")
	expectInvariants(state)
end)

runTest("StackOnSwap disabled -> positional swap", function()
	local state = CoreStore.new({ StackOnSwap = false, CanStack = false, MaxStackSize = 10 })
	local r1 = CoreStore.add(state, { Id = "Apple", Amount = 3, Metadata = { Rarity = "Common" } })
	local u1 = r1.addedItems[1].uuid
	local r2 = CoreStore.addToBackpack(state, { Id = "Apple", Amount = 2, Metadata = { Rarity = "Common" } })
	local u2 = r2.addedItems[1].uuid
	local r = CoreStore.swap(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	assertResult(r)
	assertEqual(state.Items[u1].Amount, 3, "no absorption")
	assertEqual(state.Hotbar[1], u2)
	assertEqual(state.Storage[1], u1)
	expectInvariants(state)
end)

runTest("StackOnSwap falls back to positional when dest is blacklisted", function()
	local state = CoreStore.new({ StackOnSwap = true, CanStack = false, MaxStackSize = 10 })
	local r1 = CoreStore.add(state, { Id = "Apple", Amount = 3, Metadata = { Rarity = "Common" } })
	local u1 = r1.addedItems[1].uuid
	local r2 = CoreStore.addToBackpack(state, { Id = "Apple", Amount = 2, Metadata = { Rarity = "Legendary" } })
	local u2 = r2.addedItems[1].uuid
	state.Settings.CanStack = true
	local r = CoreStore.swap(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	assertResult(r)
	assertEqual(state.Hotbar[1], u2, "positional swap happened")
	assertEqual(state.Storage[1], u1)
	expectInvariants(state)
end)

runTest("swap keeps equipped UUID across containers", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Sword", Amount = 1 })
	local u2 = addAndGetUUID(state, { Id = "Potion", Amount = 1 })
	CoreStore.equip(state, u1)
	CoreStore.move(state, { Type = "Hotbar", Slot = 2 }, { Type = "Storage", Slot = 1 })
	local r = CoreStore.swap(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	assertResult(r)
	assertEqual(state.EquippedItemUUID, u1, "equipped UUID follows the item")
	expectInvariants(state)
end)

runTest("swap storage->storage into out-of-range dest is rejected (no holes)", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 }) -- hotbar[1]
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 }) -- hotbar[2]
	CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	-- storage=[A,B]; slot 5 does not exist
	local r = CoreStore.swap(state, { Type = "Storage", Slot = 1 }, { Type = "Storage", Slot = 5 })
	assertFalse(r.success, "swap to nonexistent storage slot must be rejected")
	expectInvariants(state)
end)

runTest("swap hotbar->storage out-of-range dest is rejected (no holes)", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 }) -- hotbar[1]
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 }) -- hotbar[2]
	CoreStore.move(state, { Type = "Hotbar", Slot = 2 }, { Type = "Storage", Slot = 1 })
	-- storage=[B], hotbar[1]=A
	local r = CoreStore.swap(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 5 })
	assertFalse(r.success, "swap to nonexistent storage slot must be rejected")
	expectInvariants(state)
end)

runTest("swap storage->hotbar empty dest in Dynamic mode compacts", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 }) -- hotbar[1]
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 }) -- hotbar[2]
	local u3 = addAndGetUUID(state, { Id = "C", Amount = 1 }) -- hotbar[3]
	CoreStore.move(state, { Type = "Hotbar", Slot = 2 }, { Type = "Storage", Slot = 1 })
	CoreStore.setHotbarType(state, "Dynamic")
	-- hotbar=[A,C] packed; storage=[B]
	local r = CoreStore.swap(state, { Type = "Storage", Slot = 1 }, { Type = "Hotbar", Slot = 3 })
	assertResult(r)
	assertEqual(state.Hotbar[1], u1)
	assertEqual(state.Hotbar[2], u3)
	assertEqual(state.Hotbar[3], u2, "item appended at end")
	expectInvariants(state)
end)

-- ============ MOVE ============

runTest("move hotbar->hotbar (Static) fills empty slot", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 })
	local r = CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 6 })
	assertResult(r)
	assertEqual(state.Hotbar[1], nil)
	assertEqual(state.Hotbar[6], u1)
	assertEqual(state.LocationByUUID[u1].Slot, 6)
	expectInvariants(state)
end)

runTest("move hotbar->storage appends", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 })
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 })
	CoreStore.move(state, { Type = "Hotbar", Slot = 2 }, { Type = "Storage", Slot = 1 })
	local r = CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	assertResult(r)
	assertEqual(#state.Storage, 2)
	assertEqual(state.Storage[2], u1, "appended at end")
	expectInvariants(state)
end)

runTest("move storage->hotbar (Static) works and shifts storage", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 }) -- hotbar[1]
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 }) -- hotbar[2]
	local u3 = addAndGetUUID(state, { Id = "C", Amount = 1 }) -- hotbar[3]
	CoreStore.move(state, { Type = "Hotbar", Slot = 2 }, { Type = "Storage", Slot = 1 })
	CoreStore.move(state, { Type = "Hotbar", Slot = 2 }, { Type = "Storage", Slot = 1 })
	-- hotbar=[A,C], storage=[B, ...]
	local r = CoreStore.move(state, { Type = "Storage", Slot = 1 }, { Type = "Hotbar", Slot = 5 })
	assertResult(r)
	assertEqual(state.Hotbar[5], u2)
	assertEqual(state.Storage[1], nil, "storage shifted... ")
	expectInvariants(state)
end)

runTest("move storage->storage backward reorder updates all locations", function()
	local state = CoreStore.new()
	local uuids: { string } = {}
	for i = 1, 4 do
		local u = addAndGetUUID(state, { Id = `S{i}`, Amount = 1 })
		table.insert(uuids, u)
	end
	-- hotbar = [S1..S4] -> push all to storage
	for i = 1, 4 do
		CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	end
	-- storage=[S1,S2,S3,S4]
	local r = CoreStore.move(state, { Type = "Storage", Slot = 4 }, { Type = "Storage", Slot = 2 })
	assertResult(r)
	assertEqual(state.Storage[1], uuids[1])
	assertEqual(state.Storage[2], uuids[4])
	assertEqual(state.Storage[3], uuids[2])
	assertEqual(state.Storage[4], uuids[3])
	assertEqual(state.LocationByUUID[uuids[4]].Slot, 2)
	assertEqual(state.LocationByUUID[uuids[2]].Slot, 3)
	assertEqual(state.LocationByUUID[uuids[3]].Slot, 4)
	expectInvariants(state)
end)

runTest("move storage->storage forward reorder updates all locations", function()
	local state = CoreStore.new()
	local uuids: { string } = {}
	for i = 1, 4 do
		table.insert(uuids, addAndGetUUID(state, { Id = `S{i}`, Amount = 1 }))
	end
	for i = 1, 4 do
		CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	end
	-- storage=[S1,S2,S3,S4]
	local r = CoreStore.move(state, { Type = "Storage", Slot = 2 }, { Type = "Storage", Slot = 4 })
	assertResult(r)
	assertEqual(state.Storage[1], uuids[1])
	assertEqual(state.Storage[2], uuids[3])
	assertEqual(state.Storage[3], uuids[4])
	assertEqual(state.Storage[4], uuids[2])
	expectInvariants(state)
end)

runTest("move storage->storage out-of-range dest is rejected (no crash)", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 })
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 })
	CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	-- storage=[A,B]
	local r = CoreStore.move(state, { Type = "Storage", Slot = 1 }, { Type = "Storage", Slot = 9 })
	assertFalse(r.success, "move to nonexistent storage slot must be rejected")
	expectInvariants(state)
end)

runTest("move hotbar->storage with out-of-range toRef still appends cleanly", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 })
	local r = CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 99 })
	assertResult(r)
	assertEqual(#state.Storage, 1, "appended at end regardless of toRef")
	assertEqual(state.LocationByUUID[u1].Type, "Storage")
	expectInvariants(state)
end)

runTest("move to occupied destination -> DESTINATION_OCCUPIED, state unchanged", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 }) -- hotbar[1]
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 }) -- hotbar[2]
	local r = CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 2 })
	assertFalse(r.success)
	assertEqual(r.reason, "DESTINATION_OCCUPIED")
	assertEqual(state.Hotbar[1], u1)
	assertEqual(state.Hotbar[2], u2)
	expectInvariants(state)
end)

runTest("move from empty source -> SOURCE_EMPTY", function()
	local state = CoreStore.new()
	local r = CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	assertFalse(r.success)
	assertEqual(r.reason, "SOURCE_EMPTY")
	expectInvariants(state)
end)

runTest("move keeps equipped item equipped", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Sword", Amount = 1 })
	CoreStore.equip(state, u1)
	local r = CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	assertResult(r)
	assertEqual(state.EquippedItemUUID, u1, "equipped UUID follows")
	expectInvariants(state)
end)

runTest("move Hotbar->Hotbar in Dynamic mode rejected", function()
	local state = CoreStore.new()
	addAndGetUUID(state, { Id = "A", Amount = 1 })
	CoreStore.setHotbarType(state, "Dynamic")
	local r = CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Hotbar", Slot = 2 })
	assertFalse(r.success)
	assertEqual(r.reason, "DESTINATION_UNAVAILABLE")
	expectInvariants(state)
end)

runTest("move Storage->Hotbar in Dynamic mode: append only", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 }) -- hotbar[1]
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 }) -- hotbar[2]
	CoreStore.setHotbarType(state, "Dynamic")
	CoreStore.move(state, { Type = "Hotbar", Slot = 2 }, { Type = "Storage", Slot = 1 })
	-- hotbar=[A], storage=[B]
	local bad = CoreStore.move(state, { Type = "Storage", Slot = 1 }, { Type = "Hotbar", Slot = 1 })
	assertFalse(bad.success, "non-append slot rejected")
	local good = CoreStore.move(state, { Type = "Storage", Slot = 1 }, { Type = "Hotbar", Slot = 2 })
	assertResult(good)
	assertEqual(state.Hotbar[2], u2)
	assertEqual(#state.Storage, 0)
	expectInvariants(state)
end)

-- ============ SPLIT ============

runTest("split divides a stack into two", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Apple", Amount = 10 })
	local r = CoreStore.split(state, u1, 4)
	assertResult(r)
	assertEqual(state.Items[u1].Amount, 6)
	assertEqual(state.Items[r.newUUID].Amount, 4)
	assertEqual(state.Weight, 10)
	assertEqual(r.sourceUUID, u1)
	expectInvariants(state)
end)

runTest("split 1 from 2 makes two stacks of 1", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Apple", Amount = 2 })
	local r = CoreStore.split(state, u1, 1)
	assertResult(r)
	assertEqual(state.Items[u1].Amount, 1)
	assertEqual(state.Items[r.newUUID].Amount, 1)
	expectInvariants(state)
end)

runTest("split amount 0 -> INVALID_AMOUNT", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Apple", Amount = 5 })
	local r = CoreStore.split(state, u1, 0)
	assertFalse(r.success)
	assertEqual(r.reason, "INVALID_AMOUNT")
	assertEqual(state.Items[u1].Amount, 5)
	expectInvariants(state)
end)

runTest("split amount == stack amount -> CANNOT_SPLIT_FULL", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Apple", Amount = 5 })
	local r = CoreStore.split(state, u1, 5)
	assertFalse(r.success)
	assertEqual(r.reason, "CANNOT_SPLIT_FULL")
	expectInvariants(state)
end)

runTest("split amount > stack amount -> CANNOT_SPLIT_FULL", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Apple", Amount = 5 })
	local r = CoreStore.split(state, u1, 99)
	assertFalse(r.success)
	assertEqual(r.reason, "CANNOT_SPLIT_FULL")
	expectInvariants(state)
end)

runTest("split caps new stack at MaxStackSize, excess stays in source", function()
	local state = CoreStore.new({ MaxStackSize = 5 })
	local u1 = addAndGetUUID(state, { Id = "Apple", Amount = 10 })
	local r = CoreStore.split(state, u1, 8)
	assertResult(r)
	assertEqual(state.Items[r.newUUID].Amount, 5, "capped at max")
	assertEqual(state.Items[u1].Amount, 5, "source keeps 5")
	expectInvariants(state)
end)

runTest("split to specific hotbar slot", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Apple", Amount = 6 })
	local r = CoreStore.split(state, u1, 2, { Type = "Hotbar", Slot = 5 })
	assertResult(r)
	assertEqual(state.Hotbar[5], r.newUUID)
	assertEqual(state.LocationByUUID[r.newUUID].Slot, 5)
	expectInvariants(state)
end)

runTest("split to middle storage slot shifts and fixes LocationByUUID", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Apple", Amount = 6 }) -- hotbar[1]
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 }) -- hotbar[2]
	local u3 = addAndGetUUID(state, { Id = "C", Amount = 1 }) -- hotbar[3]
	CoreStore.move(state, { Type = "Hotbar", Slot = 2 }, { Type = "Storage", Slot = 1 })
	CoreStore.move(state, { Type = "Hotbar", Slot = 2 }, { Type = "Storage", Slot = 1 })
	-- storage=[B,C], hotbar=[Apple]
	local r = CoreStore.split(state, u1, 2, { Type = "Storage", Slot = 2 })
	assertResult(r)
	assertEqual(state.Storage[2], r.newUUID)
	assertEqual(state.Storage[3], u3, "shifted right")
	assertEqual(state.LocationByUUID[u3].Slot, 3)
	expectInvariants(state)
end)

runTest("split to occupied destination rolls back fully", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Apple", Amount = 6 }) -- hotbar[1]
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 }) -- hotbar[2]
	local beforeWeight = state.Weight
	local r = CoreStore.split(state, u1, 2, { Type = "Hotbar", Slot = 2 })
	assertFalse(r.success)
	assertEqual(state.Items[u1].Amount, 6, "source amount restored")
	assertEqual(state.Weight, beforeWeight, "weight restored")
	assertEqual(itemCount(state), 2, "no phantom stack")
	expectInvariants(state)
end)

runTest("split with no room anywhere rolls back (NO_SPACE)", function()
	local state = CoreStore.new({ BackpackEnabled = false, MaxHotbarSlots = 1 })
	local u1 = addAndGetUUID(state, { Id = "Apple", Amount = 6 }) -- fills the only hotbar slot
	local beforeWeight = state.Weight
	local r = CoreStore.split(state, u1, 2)
	assertFalse(r.success)
	assertEqual(r.reason, "NO_SPACE")
	assertEqual(state.Items[u1].Amount, 6, "source restored")
	assertEqual(state.Weight, beforeWeight)
	expectInvariants(state)
end)

runTest("split equipped source keeps source equipped, new stack not equipped", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Sword", Amount = 6 })
	CoreStore.equip(state, u1)
	local r = CoreStore.split(state, u1, 2)
	assertResult(r)
	assertEqual(state.EquippedItemUUID, u1, "source keeps UUID + equipped")
	assertEqual(state.Items[r.newUUID].Amount, 2)
	expectInvariants(state)
end)

runTest("split new stack is findable via MetadataIndex", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Sword", Amount = 6, Metadata = { Rarity = "Epic" } })
	local r = CoreStore.split(state, u1, 2)
	assertResult(r)
	local found = CoreStore.find(state, { Id = "Sword", Metadata = { Rarity = "Epic" } })
	assertEqual(#found, 2, "both stacks must be in the Rarity bucket")
	expectInvariants(state)
end)

runTest("split then remove the new stack cleans all indexes", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Sword", Amount = 6, Metadata = { Rarity = "Epic" } })
	local r = CoreStore.split(state, u1, 2)
	local newUuid = r.newUUID
	CoreStore.remove(state, newUuid)
	assertEqual(state.Items[newUuid], nil)
	assertEqual(CoreStore.find(state, { Id = "Sword", Metadata = { Rarity = "Epic" } })[1].UUID, u1)
	expectInvariants(state)
end)

-- ============ METADATA UPDATES ============

runTest("updateMetadata changes values and reports updatedFields", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Sword", Amount = 1, Metadata = { Damage = 10 } })
	local r = CoreStore.updateMetadata(state, u1, { Damage = 25, Enchant = "Fire" })
	assertResult(r)
	assertEqual(state.Items[u1].Metadata.Damage, 25)
	assertEqual(state.Items[u1].Metadata.Enchant, "Fire")
	assertEqual(#r.updatedFields, 2)
	expectInvariants(state)
end)

runTest("updateMetadata on nonexistent item fails", function()
	local state = CoreStore.new()
	local r = CoreStore.updateMetadata(state, "nope", { Damage = 1 })
	assertFalse(r.success)
	expectInvariants(state)
end)

runTest("METADATA_DELETE removes a field", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Sword", Amount = 1, Metadata = { Enchant = "Fire" } })
	local r = CoreStore.updateMetadata(state, u1, { Enchant = CoreStore.METADATA_DELETE })
	assertResult(r)
	assertEqual(state.Items[u1].Metadata.Enchant, nil)
	expectInvariants(state)
end)

runTest("METADATA_DELETE on indexed Rarity evicts from MetadataIndex", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Legendary" } })
	local r = CoreStore.updateMetadata(state, u1, { Rarity = CoreStore.METADATA_DELETE })
	assertResult(r)
	assertEqual(state.MetadataIndex["Rarity"]["Legendary"], nil, "bucket evicted")
	expectInvariants(state)
end)

runTest("inline { Key = nil } deletes nothing", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Sword", Amount = 1, Metadata = { Enchant = "Fire" } })
	local r = CoreStore.updateMetadata(state, u1, { Enchant = nil })
	assertResult(r)
	assertEqual(state.Items[u1].Metadata.Enchant, "Fire", "key untouched")
	expectInvariants(state)
end)

runTest("metadata Rarity change to blacklisted does NOT re-stack or un-stack", function()
	local state = CoreStore.new()
	local r1 = CoreStore.add(state, { Id = "Apple", Amount = 3, Metadata = { Rarity = "Common" } })
	local r2 = CoreStore.add(state, { Id = "Apple", Amount = 2, Metadata = { Rarity = "Common" } })
	-- both stack into one stack (Amount 5)
	assertEqual(itemCount(state), 1)
	local u1 = CoreStore.find(state, "Apple")[1].UUID
	local r = CoreStore.updateMetadata(state, u1, { Rarity = "Legendary" })
	assertResult(r)
	assertEqual(state.Items[u1].Amount, 5, "stack intact")
	assertEqual(state.Items[u1].Metadata.Rarity, "Legendary")
	expectInvariants(state)
end)

runTest("updateMetadata on equipped item allowed, stays equipped", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Sword", Amount = 1 })
	CoreStore.equip(state, u1)
	local r = CoreStore.updateMetadata(state, u1, { Damage = 99 })
	assertResult(r)
	assertEqual(state.EquippedItemUUID, u1)
	expectInvariants(state)
end)

-- ============ SORT ============

runTest("sort by Name orders alphabetically", function()
	local state = CoreStore.new({ SortOrder = "Name" })
	local names = { "Cherry", "Apple", "Banana" }
	for _, name in names do
		local u = addAndGetUUID(state, { Id = name, Amount = 1 })
		CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	end
	local r = CoreStore.sort(state)
	assertResult(r)
	assertEqual(state.Storage[1], state.ItemsByID["Apple"][1])
	assertEqual(state.Storage[2], state.ItemsByID["Banana"][1])
	assertEqual(state.Storage[3], state.ItemsByID["Cherry"][1])
	expectInvariants(state)
end)

runTest("sort by Rarity: descending, unknown last, ties by Id", function()
	local state = CoreStore.new({ SortOrder = "Rarity", MaxStackSize = 100 })
	local uLegend = addAndGetUUID(state, { Id = "A", Amount = 1, Metadata = { Rarity = "Legendary" } })
	local uCommon = addAndGetUUID(state, { Id = "B", Amount = 1, Metadata = { Rarity = "Common" } })
	local uRare = addAndGetUUID(state, { Id = "C", Amount = 1, Metadata = { Rarity = "Rare" } })
	local uUnknown = addAndGetUUID(state, { Id = "D", Amount = 1, Metadata = { Rarity = "Alien" } })
	local uCommon2 = addAndGetUUID(state, { Id = "E", Amount = 1, Metadata = { Rarity = "Common" } })
	for _ = 1, 5 do
		CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	end
	CoreStore.sort(state)
	assertEqual(state.Storage[1], uLegend)
	assertEqual(state.Storage[2], uRare)
	assertEqual(state.Storage[3], uCommon, "Common before other Common by Id")
	assertEqual(state.Storage[4], uCommon2)
	assertEqual(state.Storage[5], uUnknown, "unknown rarity last")
	expectInvariants(state)
end)

runTest("sort by ItemType orders alphabetically", function()
	local state = CoreStore.new({ SortOrder = "ItemType" })
	local uWeapon = addAndGetUUID(state, { Id = "Sword", Amount = 1, Metadata = { Type = "Weapon" } })
	local uAmmo = addAndGetUUID(state, { Id = "Arrow", Amount = 1, Metadata = { Type = "Ammo" } })
	local uFood = addAndGetUUID(state, { Id = "Apple", Amount = 1, Metadata = { Type = "Food" } })
	for _ = 1, 3 do
		CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	end
	CoreStore.sort(state)
	assertEqual(state.Storage[1], uAmmo)
	assertEqual(state.Storage[2], uFood)
	assertEqual(state.Storage[3], uWeapon)
	expectInvariants(state)
end)

runTest("sort with SortOrder None is a no-op", function()
	local state = CoreStore.new({ SortOrder = "None" })
	local u1 = addAndGetUUID(state, { Id = "Zebra", Amount = 1 })
	local u2 = addAndGetUUID(state, { Id = "Aardvark", Amount = 1 })
	local r = CoreStore.sort(state)
	assertResult(r)
	assertEqual(state.Hotbar[1], u1, "order unchanged")
	assertEqual(state.Hotbar[2], u2)
	expectInvariants(state)
end)

runTest("auto-sort after add sorts storage, hotbar untouched", function()
	local state = CoreStore.new({ Sorting = true, SortOrder = "Rarity", MaxStackSize = 100 })
	local uLegend = addAndGetUUID(state, { Id = "A", Amount = 1, Metadata = { Rarity = "Legendary" } })
	local uCommon = addAndGetUUID(state, { Id = "B", Amount = 1, Metadata = { Rarity = "Common" } })
	CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	local uHot = addAndGetUUID(state, { Id = "C", Amount = 1, Metadata = { Rarity = "Common" } })
	assertEqual(state.Hotbar[1], uHot, "hotbar item stays in hotbar")
	assertEqual(state.Storage[1], uLegend, "storage sorted descending")
	assertEqual(state.Storage[2], uCommon)
	expectInvariants(state)
end)

runTest("auto-sort after remove and swap keeps invariants", function()
	local state = CoreStore.new({ Sorting = true, SortOrder = "Name" })
	local names = { "Charlie", "Alpha", "Bravo" }
	for _, name in names do
		local u = addAndGetUUID(state, { Id = name, Amount = 1 })
		CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	end
	-- storage = [Alpha, Bravo, Charlie]
	CoreStore.remove(state, state.ItemsByID["Bravo"][1])
	assertEqual(state.Storage[1], state.ItemsByID["Alpha"][1])
	assertEqual(state.Storage[2], state.ItemsByID["Charlie"][1])
	local swapFrom = state.LocationByUUID[state.ItemsByID["Charlie"][1]]
	CoreStore.swap(state, swapFrom, { Type = "Hotbar", Slot = 1 })
	expectInvariants(state)
end)

runTest("sort preserves weight and item count", function()
	local state = CoreStore.new({ SortOrder = "Rarity", MaxStackSize = 100 })
	local ids = { "A", "B", "C", "D" }
	for _, id in ids do
		addAndGetUUID(state, { Id = id, Amount = 3, Metadata = { Rarity = "Common" } })
	end
	local beforeWeight = state.Weight
	local beforeCount = itemCount(state)
	CoreStore.sort(state)
	assertEqual(state.Weight, beforeWeight)
	assertEqual(itemCount(state), beforeCount)
	expectInvariants(state)
end)

-- ============ EQUIP / UNEQUIP ============

runTest("equip sets EquippedItemUUID and isEquipped", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Sword", Amount = 1 })
	local r = CoreStore.equip(state, u1)
	assertResult(r)
	assertEqual(state.EquippedItemUUID, u1)
	assertEqual(CoreStore.isEquipped(state, u1), true)
	expectInvariants(state)
end)

runTest("equip nonexistent item fails", function()
	local state = CoreStore.new()
	local r = CoreStore.equip(state, "ghost")
	assertFalse(r.success)
	assertEqual(r.reason, "ITEM_NOT_FOUND")
	expectInvariants(state)
end)

runTest("equip same item twice is idempotent", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Sword", Amount = 1 })
	CoreStore.equip(state, u1)
	local r = CoreStore.equip(state, u1)
	assertResult(r)
	assertEqual(r.previousUUID, u1)
	assertEqual(state.EquippedItemUUID, u1)
	expectInvariants(state)
end)

runTest("equip A then B reports previousUUID = A", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Sword", Amount = 1 })
	local u2 = addAndGetUUID(state, { Id = "Axe", Amount = 1 })
	CoreStore.equip(state, u1)
	local r = CoreStore.equip(state, u2)
	assertResult(r)
	assertEqual(r.previousUUID, u1)
	assertEqual(state.EquippedItemUUID, u2)
	expectInvariants(state)
end)

runTest("unequip with nothing equipped succeeds with nil previousUUID", function()
	local state = CoreStore.new()
	local r = CoreStore.unequip(state)
	assertResult(r)
	assertEqual(r.previousUUID, nil)
	expectInvariants(state)
end)

runTest("equip then move to storage keeps equipped", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "Sword", Amount = 1 })
	CoreStore.equip(state, u1)
	CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	assertEqual(state.EquippedItemUUID, u1)
	expectInvariants(state)
end)

-- ============ CAPACITY / WEIGHT ============

runTest("weight equals sum of amounts across mixed ops", function()
	local state = CoreStore.new({ Limit = 0, MaxStackSize = 10 })
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 7 })
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 4 })
	CoreStore.add(state, { Id = "A", Amount = 3 }) -- stacks to 10
	CoreStore.split(state, u2, 2)
	CoreStore.remove(state, u1, 6)
	local expected = 0
	for _, item in state.Items do
		expected += item.Amount
	end
	assertEqual(state.Weight, expected)
	expectInvariants(state)
end)

runTest("Limit = 0 means infinite capacity", function()
	local state = CoreStore.new({ Limit = 0 })
	local r = CoreStore.add(state, { Id = "A", Amount = 100000 })
	assertResult(r)
	assertEqual(r.overflow, nil)
	assertEqual(state.Weight, 100000)
	expectInvariants(state)
end)

runTest("isFull when weight equals Limit", function()
	local state = CoreStore.new({ Limit = 5 })
	assertFalse(CoreStore.isFull(state))
	CoreStore.add(state, { Id = "A", Amount = 5 })
	assertEqual(CoreStore.isFull(state), true)
	assertEqual(CoreStore.getRemainingCapacity(state), 0)
	expectInvariants(state)
end)

runTest("hasHotbarSpace tracks hotbar availability", function()
	local state = CoreStore.new({ MaxHotbarSlots = 2 })
	assertEqual(CoreStore.hasHotbarSpace(state), true)
	addAndGetUUID(state, { Id = "A", Amount = 1 })
	addAndGetUUID(state, { Id = "B", Amount = 1 })
	assertEqual(CoreStore.hasHotbarSpace(state), false)
	expectInvariants(state)
end)

runTest("exactly fill Limit then one more is FULL", function()
	local state = CoreStore.new({ Limit = 10 })
	local r1 = CoreStore.add(state, { Id = "A", Amount = 10 })
	assertResult(r1)
	local r2 = CoreStore.add(state, { Id = "B", Amount = 1 })
	assertFalse(r2.success)
	assertEqual(r2.reason, "FULL")
	expectInvariants(state)
end)

-- ============ DYNAMIC HOTBAR ============

runTest("setHotbarType Dynamic auto-compacts holes", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 }) -- hotbar[1]
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 }) -- hotbar[2]
	local u3 = addAndGetUUID(state, { Id = "C", Amount = 1 }) -- hotbar[3]
	CoreStore.remove(state, u2)
	assertEqual(state.Hotbar[2], nil, "Static keeps the hole")
	CoreStore.setHotbarType(state, "Dynamic")
	assertEqual(state.Hotbar[1], u1)
	assertEqual(state.Hotbar[2], u3, "compacted")
	assertEqual(state.LocationByUUID[u3].Slot, 2)
	expectInvariants(state)
end)

runTest("Dynamic add ignores preferred slot and appends", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 })
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 })
	CoreStore.setHotbarType(state, "Dynamic")
	local r = CoreStore.addToHotbar(state, { Id = "C", Amount = 1 }, 1)
	assertResult(r)
	assertEqual(r.addedItems[1].slot, 3, "appended at 3, not preferred 1")
	expectInvariants(state)
end)

runTest("Dynamic remove compacts", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 })
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 })
	local u3 = addAndGetUUID(state, { Id = "C", Amount = 1 })
	CoreStore.setHotbarType(state, "Dynamic")
	CoreStore.remove(state, u2)
	assertEqual(state.Hotbar[1], u1)
	assertEqual(state.Hotbar[2], u3)
	assertEqual(state.Hotbar[3], nil)
	expectInvariants(state)
end)

runTest("Static -> Dynamic -> Static roundtrip keeps invariants", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1 }) -- 1
	local u2 = addAndGetUUID(state, { Id = "B", Amount = 1 }) -- 2
	local u3 = addAndGetUUID(state, { Id = "C", Amount = 1 }) -- 3
	CoreStore.remove(state, u2)
	CoreStore.setHotbarType(state, "Dynamic")
	CoreStore.setHotbarType(state, "Static")
	assertEqual(state.Hotbar[1], u1)
	assertEqual(state.Hotbar[2], u3)
	assertEqual(state.Hotbar[3], nil)
	expectInvariants(state)
end)

-- ============ QUERIES ============

runTest("find by Id uses ItemsByID", function()
	local state = CoreStore.new()
	addAndGetUUID(state, { Id = "Sword", Amount = 1 })
	addAndGetUUID(state, { Id = "Sword", Amount = 1 })
	addAndGetUUID(state, { Id = "Axe", Amount = 1 })
	local swords = CoreStore.find(state, "Sword")
	assertEqual(#swords, 2)
	expectInvariants(state)
end)

runTest("find single-field metadata via MetadataIndex", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1, Metadata = { Rarity = "Legendary" } })
	addAndGetUUID(state, { Id = "B", Amount = 1, Metadata = { Rarity = "Common" } })
	local found = CoreStore.find(state, { Metadata = { Rarity = "Legendary" } })
	assertEqual(#found, 1)
	assertEqual(found[1].UUID, u1)
end)

runTest("find multi-field picks smallest bucket", function()
	local state = CoreStore.new()
	local u1 = addAndGetUUID(state, { Id = "A", Amount = 1, Metadata = { Rarity = "Legendary", Type = "Weapon" } })
	addAndGetUUID(state, { Id = "B", Amount = 1, Metadata = { Rarity = "Common", Type = "Weapon" } })
	local found = CoreStore.find(state, { Metadata = { Rarity = "Legendary", Type = "Weapon" } })
	assertEqual(#found, 1)
	assertEqual(found[1].UUID, u1)
end)

runTest("find with Id + metadata combo", function()
	local state = CoreStore.new()
	addAndGetUUID(state, { Id = "Sword", Amount = 1, Metadata = { Rarity = "Legendary" } })
	addAndGetUUID(state, { Id = "Axe", Amount = 1, Metadata = { Rarity = "Legendary" } })
	local found = CoreStore.find(state, { Id = "Sword", Metadata = { Rarity = "Legendary" } })
	assertEqual(#found, 1)
end)

runTest("filter with custom predicate", function()
	local state = CoreStore.new()
	addAndGetUUID(state, { Id = "A", Amount = 5 })
	addAndGetUUID(state, { Id = "B", Amount = 2 })
	local big = CoreStore.filter(state, function(item: any)
		return item.Amount >= 5
	end)
	assertEqual(#big, 1)
end)

runTest("getAllItems returns every item", function()
	local state = CoreStore.new()
	addAndGetUUID(state, { Id = "A", Amount = 1 })
	addAndGetUUID(state, { Id = "B", Amount = 1 })
	addAndGetUUID(state, { Id = "C", Amount = 1 })
	assertEqual(#CoreStore.getAllItems(state), 3)
end)

-- ============ STRESS / FUZZ ============

runTest("add 1000 items keeps every invariant", function()
	local state = CoreStore.new({ Limit = 0 })
	for i = 1, 1000 do
		local r = CoreStore.add(state, { Id = `Item{i % 5}`, Amount = 1 })
		assertResult(r)
	end
	assertEqual(itemCount(state), 1000)
	assertEqual(state.Weight, 1000)
	assertEqual(CoreStore.getStorageItemCount(state), 990)
	assertEqual(CoreStore.getHotbarItemCount(state), 10)
	expectInvariants(state)
end)

runTest("bulk stack of 1000 bucketed at MaxStackSize", function()
	local state = CoreStore.new({ Limit = 0, MaxStackSize = 25 })
	local r = CoreStore.add(state, { Id = "Bulk", Amount = 1000 })
	assertResult(r)
	assertEqual(#CoreStore.find(state, "Bulk"), 40, "1000 / 25 = 40 stacks")
	assertEqual(state.Weight, 1000)
	for _, item in state.Items do
		assertTrue(item.Amount <= 25)
	end
	expectInvariants(state)
end)

runTest("remove 500 random items from 1000 keeps invariants", function()
	local state = CoreStore.new({ Limit = 0 })
	for i = 1, 1000 do
		CoreStore.add(state, { Id = `Item{i % 7}`, Amount = 1 })
	end
	for _ = 1, 500 do
		local uuid = next(state.Items)
		assertTrue(uuid ~= nil)
		CoreStore.remove(state, uuid)
	end
	assertEqual(itemCount(state), 500)
	assertEqual(state.Weight, 500)
	expectInvariants(state)
end)

runTest("sort 500 storage items keeps invariants and order", function()
	local state = CoreStore.new({ Limit = 0, MaxStackSize = 100, SortOrder = "Rarity" })
	local rarities = { "Common", "Uncommon", "Rare", "Epic", "Legendary" }
	for i = 1, 500 do
		local r = CoreStore.add(state, {
			Id = `Item{i}`,
			Amount = 1,
			Metadata = { Rarity = rarities[randInt(#rarities)] },
		})
		assertResult(r)
		CoreStore.move(state, { Type = "Hotbar", Slot = 1 }, { Type = "Storage", Slot = 1 })
	end
	CoreStore.sort(state)
	expectInvariants(state)
	-- verify descending rarity via LocationByUUID order
	local rank = { Common = 1, Uncommon = 2, Rare = 3, Epic = 4, Legendary = 5 }
	local lastRank = math.huge
	for _, uuid in state.Storage do
		local item = state.Items[uuid]
		local r = rank[item.Metadata.Rarity] or 99
		assertTrue(r <= lastRank, "storage must be non-increasing in rarity rank")
		lastRank = r
	end
end)

runTest("fuzz: 200 random chained ops keep every invariant", function()
	local state = CoreStore.new({ Limit = 5000, MaxStackSize = 20, CanStack = true })
	local itemPool = { "Apple", "Banana", "Cherry", "Dagger", "Elixir" }

	local function randomOccupiedHotbar(): number?
		local occupied: { number } = {}
		for i = 1, state.Settings.MaxHotbarSlots do
			if state.Hotbar[i] then
				table.insert(occupied, i)
			end
		end
		if #occupied == 0 then return nil end
		return occupied[randInt(#occupied)]
	end

	local function firstEmptyHotbar(): number?
		for i = 1, state.Settings.MaxHotbarSlots do
			if not state.Hotbar[i] then
				return i
			end
		end
		return nil
	end

	local opNames = { "add", "addBackpack", "remove", "swap", "move", "split" }
	for i = 1, 200 do
		local roll = randInt(6)
		if roll == 1 then
			CoreStore.add(state, { Id = itemPool[randInt(#itemPool)], Amount = randInt(30) })
		elseif roll == 2 then
			CoreStore.addToBackpack(state, { Id = itemPool[randInt(#itemPool)], Amount = randInt(30) })
		elseif roll == 3 then
			local uuid = next(state.Items)
			if uuid then
				CoreStore.remove(state, uuid, randInt(6))
			end
		elseif roll == 4 then
			local h = randomOccupiedHotbar()
			local s = randInt(#state.Storage)
			if h and s then
				CoreStore.swap(state, { Type = "Hotbar", Slot = h }, { Type = "Storage", Slot = s })
			end
		elseif roll == 5 then
			local s = randInt(#state.Storage)
			local empty = firstEmptyHotbar()
			if s and empty then
				CoreStore.move(state, { Type = "Storage", Slot = s }, { Type = "Hotbar", Slot = empty })
			end
		else
			local uuid, found = nil, false
			for u, item in state.Items do
				if item.Amount >= 2 then
					uuid = u
					found = true
					break
				end
			end
			if found then
				CoreStore.split(state, uuid, 1)
			end
		end

		local violations = verifyInvariants(state)
		if #violations > 0 then
			error(`fuzz op {i} ({opNames[roll]}): {violations[1]}`)
		end
	end

	expectInvariants(state)
end)

-----------------------------
-- SUMMARY --
-----------------------------

print("")
print("============================================")
print(`  Results: {passCount} passed, {failCount} failed, {totalTests} total`)
print("============================================")
