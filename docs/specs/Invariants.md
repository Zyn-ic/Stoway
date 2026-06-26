# CoreStore Invariants

These are the structural guarantees that CoreStore maintains at all times. Every operation must preserve these invariants. Future operations must be designed to maintain them.

Violations of these invariants indicate a bug.

---

## State Invariants

### INV-1: UUID Ownership

Every UUID present in Hotbar or Storage must exist as a key in Items.

```
forall uuid in Hotbar[u]: Items[uuid] ~= nil
forall uuid in Storage[i]: Items[uuid] ~= nil
```

### INV-2: Single Location

Every Item exists in exactly one location. No UUID appears in both Hotbar and Storage simultaneously.

```
forall uuid in Items:
    (exists i: Hotbar[i] == uuid) XOR (exists j: Storage[j] == uuid)
```

### INV-3: LocationByUUID Accuracy

Every entry in LocationByUUID must match the item's actual placement. If an item is in Hotbar slot 3, LocationByUUID[uuid] must be `{ Type = "Hotbar", Slot = 3 }`.

```
forall uuid in Items:
    LocationByUUID[uuid].Type == "Hotbar" implies Hotbar[LocationByUUID[uuid].Slot] == uuid
    LocationByUUID[uuid].Type == "Storage" implies Storage[LocationByUUID[uuid].Slot] == uuid
```

### INV-4: ItemsByID Consistency

Every UUID in ItemsByID[itemId] must reference an existing item with that Id. No stale UUIDs.

```
forall itemId, forall uuid in ItemsByID[itemId]:
    Items[uuid] ~= nil
    Items[uuid].Id == itemId
```

### INV-5: ItemsByID Completeness

Every Item in Items must have its UUID present in ItemsByID[item.Id].

```
forall uuid in Items:
    uuid in ItemsByID[Items[uuid].Id]
```

---

## Weight Invariants

### INV-6: Weight Accuracy

Weight equals the sum of Amount across all items in Items.

```
state.Weight == sum(Items[uuid].Amount for all uuid in Items)
```

### INV-7: Weight Non-Negative

Weight is always >= 0.

```
state.Weight >= 0
```

---

## Slot Invariants

### INV-8: Hotbar Bounds

Hotbar indices are in the range [1, MaxHotbarSlots].

```
forall i in Hotbar:
    1 <= i <= MaxHotbarSlots
```

### INV-9: Storage Contiguity

Storage has no nil holes. Indices are contiguous from 1 to #Storage.

```
forall i in [1, #Storage]:
    Storage[i] ~= nil
```

### INV-10: Hotbar Static Holes

In Static mode, Hotbar may contain nil values. In Dynamic mode, Hotbar has no nil holes after compaction. The only available slot in Dynamic mode is the append position.

```
HotbarType == "Dynamic" implies:
    forall i in [1, writeIndex-1]: Hotbar[i] ~= nil
    findEmptyHotbarSlot(state) == writeIndex  (the append position)
```

---

## Equipped Invariant

### INV-11: Equipped Validity

EquippedItemUUID either references an existing item in Items or is nil.

```
state.EquippedItemUUID == nil or Items[state.EquippedItemUUID] ~= nil
```

---

## Settings Invariants

### INV-12: Settings Immutability

Settings are set at construction time via `State.new(overrides?)`. They do not change during the lifetime of an InventoryState. (Future: may add `updateSettings()` but this is not yet implemented.)

### INV-13: MaxStackSize Positive

MaxStackSize must be >= 1.

```
Settings.MaxStackSize >= 1
```

### INV-14: Limit Non-Negative

Limit must be >= 0. Limit = 0 means infinite.

```
Settings.Limit >= 0
```

---

## Operation Invariants

### INV-15: Add Preserves Existing Items

Adding items never modifies existing items except through stacking (increasing Amount).

### INV-16: Remove Preserves Other Items

Removing an item never modifies any other item in the inventory.

### INV-17: Partial Remove Preserves UUID

A partial remove (amount < item.Amount) keeps the same UUID. Only the Amount changes.

### INV-18: MaxStackSize Enforcement

No item's Amount may exceed MaxStackSize after any operation. This is enforced unconditionally — regardless of CanStack or StackOnSwap settings.

```
forall uuid in Items:
    Items[uuid].Amount <= Settings.MaxStackSize
```

**Why this matters:** MaxStackSize is a structural constant that defines what a valid stack looks like. If stacks can exceed it, `canStack` returns false for them (Amount >= MaxStackSize), making them invisible to stacking logic. This creates zombie stacks that can never receive more items. The cap is always enforced in `createItem` and `split`.

---

## Trigger Matrix

Operations that modify state and which invariants they must preserve:

| Operation | Modifies Items | Modifies Hotbar | Modifies Storage | Modifies Weight | Must Preserve |
|-----------|---------------|-----------------|------------------|-----------------|---------------|
| add | Yes (create) | Yes (set slot) | Yes (append) | Yes (+) | ALL |
| remove | Yes (reduce/destroy) | Yes (clear) | Yes (remove) | Yes (-) | ALL |
| swap | No | Yes (exchange) | Yes (exchange) | No | INV-1,2,3,4,5,8,9 |
| move | No | Yes (set/clear) | Yes (append/remove) | No | INV-1,2,3,4,5,8,9 |
| split | Yes (create) | Yes (set slot) | Yes (append) | Yes (+) | ALL |
| sort | No | No | Yes (reorder) | No | INV-1,2,3,4,5,9 |
| updateMetadata | Yes (modify) | No | No | No | ALL |

---

## Verification

These invariants can be checked by a debug function:

```luau
function CoreStore.verifyInvariants(state): { string }
    local violations = {}

    -- Check INV-1: UUID Ownership
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

    -- Check INV-2: Single Location
    local seen = {}
    for slot, uuid in state.Hotbar do
        if uuid then
            if seen[uuid] then
                table.insert(violations, `UUID {uuid} exists in multiple locations`)
            end
            seen[uuid] = true
        end
    end
    for _, uuid in state.Storage do
        if seen[uuid] then
            table.insert(violations, `UUID {uuid} exists in both Hotbar and Storage`)
        end
        seen[uuid] = true
    end

    -- Check INV-3: LocationByUUID Accuracy
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

    -- Check INV-4,5: ItemsByID Consistency
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
                if id == uuid then found = true; break end
            end
            if not found then
                table.insert(violations, `Items[{uuid}] has Id {item.Id} but not in ItemsByID list`)
            end
        end
    end

    -- Check INV-6: Weight Accuracy
    local expectedWeight = 0
    for _, item in state.Items do
        expectedWeight += item.Amount
    end
    if state.Weight ~= expectedWeight then
        table.insert(violations, `Weight is {state.Weight} but expected {expectedWeight}`)
    end

    -- Check INV-11: Equipped Validity
    if state.EquippedItemUUID and not state.Items[state.EquippedItemUUID] then
        table.insert(violations, `EquippedItemUUID references missing item {state.EquippedItemUUID}`)
    end

    -- Check INV-18: MaxStackSize Enforcement
    for uuid, item in state.Items do
        if item.Amount > state.Settings.MaxStackSize then
            table.insert(violations, `Items[{uuid}] has Amount {item.Amount} exceeding MaxStackSize {state.Settings.MaxStackSize}`)
        end
    end

    return violations
end
```
