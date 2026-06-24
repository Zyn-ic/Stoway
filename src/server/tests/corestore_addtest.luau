local CoreStore = require(script.Parent.Parent.CoreStore)

local function assertEqual(actual, expected, message)
    if actual ~= expected then
        error(`{message or "assertEqual failed"} | expected: {tostring(expected)}, got: {tostring(actual)}`)
    end
end

local function assertTrue(value, message)
    if not value then
        error(message or "assertTrue failed")
    end
end

local function getFirstAddedUUID(result)
    assertTrue(result.addedItems ~= nil, "expected addedItems")
    assertTrue(result.addedItems[1] ~= nil, "expected first added item")

    return result.addedItems[1].uuid
end

local function testNewInventory()
    local state = CoreStore.new()

    assertEqual(state.Weight, 0, "new inventory weight should be 0")
    assertEqual(#state.Storage, 0, "new inventory storage should be empty")
    assertEqual(state.EquippedItemUUID, nil, "new inventory should not have equipped item")
end

local function testAddGoesToHotbarFirst()
    local state = CoreStore.new()

    local result = CoreStore.add(state, {
        Id = "Potion",
        Amount = 1,
        Metadata = {
            Rarity = "Common",
            Type = "Consumable",
        },
    })

    assertTrue(result.success, "add should succeed")
    assertEqual(result.addedAmount, 1, "added amount should be 1")
    assertEqual(state.Weight, 1, "weight should include hotbar item")
    assertTrue(state.Hotbar[1] ~= nil, "item should go to hotbar slot 1")
    assertEqual(#state.Storage, 0, "storage should still be empty")
end

local function testHotbarFillsBeforeStorage()
    local state = CoreStore.new({
        MaxHotbarSlots = 2,
        MaxStackSize = 1,
        CanStack = false,
        Limit = 10,
    })

    CoreStore.add(state, { Id = "A", Amount = 1 })
    CoreStore.add(state, { Id = "B", Amount = 1 })
    CoreStore.add(state, { Id = "C", Amount = 1 })

    assertTrue(state.Hotbar[1] ~= nil, "hotbar slot 1 should be filled")
    assertTrue(state.Hotbar[2] ~= nil, "hotbar slot 2 should be filled")
    assertEqual(#state.Storage, 1, "third item should go to storage")
    assertEqual(state.Weight, 3, "weight should count hotbar plus storage")
end

local function testAddToBackpackSkipsHotbar()
    local state = CoreStore.new({
        MaxHotbarSlots = 10,
        Limit = 10,
    })

    local result = CoreStore.addToBackpack(state, {
        Id = "IronOre",
        Amount = 1,
        Metadata = {
            Rarity = "Common",
            Type = "Resource",
        },
    })

    assertTrue(result.success, "addToBackpack should succeed")
    assertEqual(state.Hotbar[1], nil, "hotbar slot 1 should remain empty")
    assertEqual(#state.Storage, 1, "item should be added to storage")
    assertEqual(state.Weight, 1, "weight should include backpack item")
end

local function testMetadataAmountAlias()
    local state = CoreStore.new()

    local result = CoreStore.add(state, {
        Id = "Arrow",
        Metadata = {
            StackAmount = 3,
            Rarity = "Common",
            Type = "Ammo",
        },
    })

    assertTrue(result.success, "add should succeed")
    assertEqual(result.addedAmount, 3, "StackAmount should be used as amount")
    assertEqual(state.Weight, 3, "weight should be 3")

    local uuid = getFirstAddedUUID(result)
    local item = CoreStore.getItem(state, uuid)

    assertEqual(item.Metadata.StackAmount, nil, "StackAmount should not be stored in metadata")
    assertEqual(item.Metadata.Amount, nil, "Amount should not be stored in metadata")
end

local function testStacking()
    local state = CoreStore.new({
        MaxStackSize = 5,
        CanStack = true,
        Limit = 10,
    })

    local first = CoreStore.add(state, {
        Id = "Potion",
        Amount = 2,
        Metadata = {
            Rarity = "Common",
            Type = "Consumable",
        },
    })

    local uuid = getFirstAddedUUID(first)

    local second = CoreStore.add(state, {
        Id = "Potion",
        Amount = 2,
        Metadata = {
            Rarity = "Common",
            Type = "Consumable",
        },
    })

    local item = CoreStore.getItem(state, uuid)

    assertTrue(second.success, "second add should succeed")
    assertEqual(item.Amount, 4, "item should stack to 4")
    assertEqual(state.Weight, 4, "weight should include stacked amount")
    assertEqual(#state.Storage, 0, "no storage item should be created")
end

local function testRemovePartial()
    local state = CoreStore.new({
        MaxStackSize = 10,
    })

    local result = CoreStore.add(state, {
        Id = "Potion",
        Amount = 5,
    })

    local uuid = getFirstAddedUUID(result)

    local removeResult = CoreStore.remove(state, uuid, 2)

    assertTrue(removeResult.success, "remove should succeed")
    assertEqual(removeResult.remaining, 3, "remaining amount should be 3")
    assertEqual(state.Weight, 3, "weight should decrease")
    assertEqual(CoreStore.getItem(state, uuid).Amount, 3, "item amount should be 3")
end

local function testRemoveFull()
    local state = CoreStore.new()

    local result = CoreStore.add(state, {
        Id = "Sword",
        Amount = 1,
    })

    local uuid = getFirstAddedUUID(result)

    local removeResult = CoreStore.remove(state, uuid)

    assertTrue(removeResult.success, "remove full should succeed")
    assertEqual(removeResult.remaining, 0, "remaining should be 0")
    assertEqual(state.Weight, 0, "weight should be 0")
    assertEqual(CoreStore.getItem(state, uuid), nil, "item should be destroyed")
    assertEqual(state.Hotbar[1], nil, "hotbar slot should be cleared")
end

testNewInventory()
testAddGoesToHotbarFirst()
testHotbarFillsBeforeStorage()
testAddToBackpackSkipsHotbar()
testMetadataAmountAlias()
testStacking()
testRemovePartial()
testRemoveFull()

print("CoreStore add/remove tests passed")