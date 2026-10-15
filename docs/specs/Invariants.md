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

### INV-12: Settings Change Through Defined Paths

Settings start from construction-time overrides but do change during a
state's lifetime: `setHotbarType`, sparse `SettingsChanged` pushes, and the
debug console toggles all mutate them. What never happens is silent drift —
every change flows through one of those paths and replicates.

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

### INV-19: MetadataIndex Consistency

Every Item in Items with indexed fields (Rarity, Type) must have a corresponding entry in MetadataIndex. Conversely, every entry in MetadataIndex must reference an existing Item in Items.

```
forall uuid in Items:
    if Items[uuid].Metadata.Rarity ~= nil:
        uuid in MetadataIndex["Rarity"][tostring(Items[uuid].Metadata.Rarity)]
    if Items[uuid].Metadata.Type ~= nil:
        uuid in MetadataIndex["Type"][tostring(Items[uuid].Metadata.Type)]

forall field in MetadataIndex:
    forall value in MetadataIndex[field]:
        forall uuid in MetadataIndex[field][value]:
            Items[uuid] ~= nil
```

---

## Trigger Matrix

Operations that modify state and which invariants they must preserve:

| Operation | Modifies Items | Modifies Hotbar | Modifies Storage | Modifies Weight | Modifies MetadataIndex | Must Preserve |
|-----------|---------------|-----------------|------------------|-----------------|------------------------|---------------|
| add | Yes (create) | Yes (set slot) | Yes (append) | Yes (+) | Yes (add) | ALL |
| remove | Yes (reduce/destroy) | Yes (clear) | Yes (remove) | Yes (-) | Yes (remove) | ALL |
| swap | No (unless StackOnSwap absorbs) | Yes (exchange) | Yes (exchange) | No | Conditional (absorb destroys) | INV-1,2,3,4,5,8,9,19 |
| swapStack | No (unless StackOnSwap absorbs) | Yes (exchange) | Yes (exchange) | No | Conditional (absorb destroys) | INV-1,2,3,4,5,8,9,19 |
| move | No | Yes (set/clear) | Yes (append/remove) | No | No | INV-1,2,3,4,5,8,9,19 |
| split | Yes (create) | Yes (set slot) | Yes (append) | Yes (+) | Yes (add) | ALL |
| sort | No | No | Yes (reorder) | No | No | INV-1,2,3,4,5,9,19 |
| updateMetadata | Yes (modify) | No | No | No | Yes (update) | ALL |

The INV list above is the contract. There is no `verifyInvariants` checker in
the repo — operations preserve these by construction.
