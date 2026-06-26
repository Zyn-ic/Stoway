# Move Rules

Move transfers an item from one slot to another. It is a purely positional operation. Move never triggers stacking.

---

## API

```luau
CoreStore.move(state, fromRef, toRef) -> MoveResult
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| state | InventoryState | The inventory state |
| fromRef | SlotRef | Source slot |
| toRef | SlotRef | Destination slot (must be empty) |

### Result Shape

```luau
{
    success: boolean,
    reason: string?,
    hotbarCompacted: boolean?,
}
```

---

## Core Rule

**Move is swap where the destination is empty. Move is purely positional. Move never triggers stacking.**

If the destination is occupied, the operation fails. If you want to stack, use add (for new items) or swap with `StackOnSwap = true` (for existing items).

---

## Why Move Does Not Stack

Consider: Apple x3 in Storage, Apple x2 in Hotbar[1], Hotbar[2] is empty.

```
CanStack = true, StackOnSwap = false

Move Storage[1] -> Hotbar[2]:
  Apple x3 moves to Hotbar[2]
  Hotbar[1] still has Apple x2
  Result: Two separate stacks, no merging

Swap Storage[1] -> Hotbar[1] (with StackOnSwap = true):
  Apple x3 absorbs into Apple x2 (up to MaxStackSize)
  Result: Stacked
```

Stacking during move would create implicit behavior. If you want to stack, the caller must explicitly use swap with `StackOnSwap = true`.

---

## Move Combinations

### Hotbar -> Hotbar (empty slot)

Move item from one hotbar slot to another empty hotbar slot.

**Static mode:** Holes are allowed. The destination can be any empty slot.

```
fromUUID = Hotbar[fromSlot]

Hotbar[fromSlot] = nil
Hotbar[toSlot] = fromUUID

Update LocationByUUID for fromUUID
```

**Dynamic mode:** The hotbar is always packed. There are no empty slots within the packed portion. Any move to an empty slot is rejected with `DESTINATION_UNAVAILABLE` because the destination does not exist in the packed array.

```
if HotbarType == "Dynamic":
    return { success = false, reason = "DESTINATION_UNAVAILABLE" }
```

### Hotbar -> Storage (append)

Move item from hotbar to storage. Hotbar slot becomes nil (Static) or triggers compaction (Dynamic).

```
fromUUID = Hotbar[fromSlot]

Hotbar[fromSlot] = nil
table.insert(Storage, fromUUID)

Update LocationByUUID for fromUUID
hotbarCompacted = compactHotbar(state)
```

### Storage -> Hotbar (empty slot)

Move item from storage to an empty hotbar slot. Storage shifts left.

**Static mode:** The destination can be any empty hotbar slot.

```
fromUUID = Storage[fromSlot]

Hotbar[toSlot] = fromUUID
table.remove(Storage, fromSlot)

Update LocationByUUID for fromUUID
Update LocationByUUID for all shifted storage items
```

**Dynamic mode:** The destination must be the append position (the first nil slot after the packed portion). If `toRef.Slot != findEmptyHotbarSlot(state)`, the operation is rejected with `DESTINATION_UNAVAILABLE`.

```
if HotbarType == "Dynamic":
    appendSlot = findEmptyHotbarSlot(state)
    if toRef.Slot != appendSlot:
        return { success = false, reason = "DESTINATION_UNAVAILABLE" }

fromUUID = Storage[fromSlot]

Hotbar[toSlot] = fromUUID
table.remove(Storage, fromSlot)

Update LocationByUUID for fromUUID
Update LocationByUUID for all shifted storage items
```

### Storage -> Storage (reorder)

Move item within storage to a different index.

```
fromUUID = Storage[fromSlot]

table.remove(Storage, fromSlot)
table.insert(Storage, toSlot, fromUUID)

Update LocationByUUID for all affected storage items
```

---

## Validation

```
1. fromRef must contain an item
2. toRef must be empty
3. BackpackEnabled check (if destination is Storage)
4. Hotbar bounds check (if either slot is Hotbar)
```

---

## Equipped Item Behavior

EquippedItemUUID follows the UUID. Moving an equipped item from Hotbar[1] to Storage does not unequip it.

---

## Sorting Interaction

If `Settings.Sorting = true`, auto-sort runs after the move completes.

---

## Complexity

- Hotbar -> Hotbar: O(1)
- Hotbar -> Storage: O(1) append + O(h) compaction
- Storage -> Hotbar: O(n) for storage shift
- Storage -> Storage: O(n) for storage shift
