# Split Rules

Split divides an existing stack into two stacks. The source stack keeps a reduced amount, and a new stack is created with the split amount.

---

## API

```luau
CoreStore.split(state, uuid, amount, destination?) -> SplitResult
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| state | InventoryState | The inventory state |
| uuid | string | UUID of the stack to split |
| amount | number | Amount to move to the new stack |
| destination | SlotRef? | Optional specific destination slot |

### Result Shape

```luau
{
    success: boolean,
    reason: string?,
    sourceUUID: string?,          -- UUID of original (reduced) stack
    newUUID: string?,             -- UUID of new stack
    sourceAmount: number?,        -- Amount remaining in source
    newAmount: number?,           -- Amount in new stack
    newSlotType: SlotType?,       -- Where the new stack was placed
    newSlot: number?,             -- Slot index of new stack
    hotbarCompacted: boolean?,
}
```

---

## Validation

```
1. UUID must exist in Items
2. Amount must be positive
3. Amount must be < item.Amount (cannot split entire stack; use remove instead)
4. If destination specified:
   a. Destination slot must exist
   b. Destination slot must be empty
   c. BackpackEnabled check if destination is Storage
```

---

## Flow

```
1. Validate split request
   - amount >= 1
   - amount < sourceItem.Amount

2. Cap split amount
   - splitAmount = min(amount, MaxStackSize)
   - This is unconditional: always enforced regardless of CanStack
   - Excess stays in source (e.g., split 8 with MaxStackSize=5 → splitAmount=5, source keeps 3)

3. Reduce source stack
   - sourceItem.Amount -= splitAmount
   - State.removeWeight(state, splitAmount)

4. Create new stack
   - Generate new UUID
   - Create Item with:
     - UUID = new UUID
     - Id = sourceItem.Id
     - Amount = splitAmount (capped at MaxStackSize)
     - Metadata = deep copy of sourceItem.Metadata

5. Place new stack
   - If destination specified: place in that slot
   - If no destination: follow placement chain (Auto -> Hotbar -> Storage)

6. Update indexes
   - Add new UUID to Items
   - Add new UUID to ItemsByID[itemId]
   - Set LocationByUUID for new UUID
   - Increment Weight by splitAmount

7. Return result
```

---

## Placement Chain (No Destination Specified)

When no destination is provided, the new stack follows the standard placement chain:

```
1. Try empty hotbar slot (first available)
2. If hotbar full, append to storage
3. If storage full (Limit reached), fail with NO_SPACE
```

### With Specific Destination

When a destination SlotRef is provided:

```
If destination.Type == "Hotbar":
    Validate slot bounds and emptiness
    Set Hotbar[destination.Slot] = newUUID

If destination.Type == "Storage":
    Validate BackpackEnabled
    Insert at destination.Slot in Storage
    Shift subsequent items if needed
```

---

## Stacking Interaction

Split does NOT attempt to stack the new stack into existing stacks at the destination. The new stack always goes to the next available slot via the placement chain.

```
If you want to stack after split:
  1. Split creates two separate stacks
  2. Use swap with StackOnSwap = true to merge them
```

This is consistent with the rule: **stacking during slot operations only happens via add (always) or swap with StackOnSwap = true.**

---

## Equipped Item Behavior

Split does not affect equipped state. The source UUID remains the same, so if it was equipped, it stays equipped with the reduced amount.

---

## Sorting Interaction

If `Settings.Sorting = true`, auto-sort runs after the split completes. This may move the new stack within Storage.

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| amount == 0 | Fail: INVALID_AMOUNT |
| amount >= item.Amount | Fail: CANNOT_SPLIT_FULL (use remove instead) |
| Split into max stack | New stack capped at MaxStackSize, excess stays in source. Always enforced, even if CanStack = false. |
| Split 8 from 10, MaxStackSize = 5 | splitAmount = min(8, 5) = 5. Source keeps 5, new stack gets 5. |
| Source has amount = 2, split 1 | Source becomes 1, new stack has 1 |
| No hotbar space, storage full | Fail: NO_SPACE |
| Splitting equipped item | Allowed, source keeps UUID and equipped state |

---

## Complexity

- Validation: O(1)
- Source reduction: O(1)
- New stack creation: O(1)
- Placement (auto): O(1) hotbar + O(1) storage append
- Placement (stacking): O(k) where k = candidate stacks
- Storage insert at position: O(n) for shift
