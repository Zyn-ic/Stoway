# Swap Rules

Swap exchanges the positions of two items in the inventory. It is a positional operation that does not create or destroy items.

**Stacking during slot operations:** Swap is the only slot operation that can trigger stacking (via `StackOnSwap`). Move and split never stack. Note: add operations always attempt stacking when `CanStack = true` — that is separate from slot operations.

---

## API

```luau
CoreStore.swap(state, fromRef, toRef) -> SwapResult
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| state | InventoryState | The inventory state |
| fromRef | SlotRef | Source slot: `{ Type = "Hotbar" \| "Storage", Slot = number }` |
| toRef | SlotRef | Destination slot: `{ Type = "Hotbar" \| "Storage", Slot = number }` |

### Result Shape

```luau
{
    success: boolean,
    reason: string?,              -- Error code if failed
    hotbarCompacted: boolean?,    -- True if Dynamic hotbar was compacted
}
```

---

## Validation

Before any swap executes, these checks run:

```
1. BackpackEnabled check:
   If BackpackEnabled = false and either slot is Storage: return BACKPACK_DISABLED

2. Hotbar bounds check:
   If fromRef.Type == "Hotbar": slot must be in [1, MaxHotbarSlots]
   If toRef.Type == "Hotbar": slot must be in [1, MaxHotbarSlots]

3. Storage source existence:
   If fromRef.Type == "Storage": Storage[fromRef.Slot] must exist
   (Swapping FROM an empty storage slot is invalid)
```

---

## Swap Combinations

### Hotbar <-> Hotbar

Both slots are in the hotbar. Simple exchange.

**Static mode:** Both slots are valid. Holes are allowed.

```
fromUUID = Hotbar[fromSlot]
toUUID = Hotbar[toSlot]

Hotbar[fromSlot] = toUUID
Hotbar[toSlot] = fromUUID

Update LocationByUUID for both UUIDs
```

**Dynamic mode:** Only occupied slots are valid. The destination must contain an item (reorder). If the destination is nil (empty), the operation is rejected with `DESTINATION_UNAVAILABLE`. Dynamic hotbar is always packed — no holes exist, so swapping with an empty slot is meaningless.

```
if HotbarType == "Dynamic" and toUUID == nil:
    return { success = false, reason = "DESTINATION_UNAVAILABLE" }
```

### Storage <-> Storage

Both slots are in storage. Reorder within the array.

```
fromUUID = Storage[fromSlot]
toUUID = Storage[toSlot]

Storage[fromSlot] = toUUID
Storage[toSlot] = fromUUID

Update LocationByUUID for both UUIDs
```

### Hotbar -> Storage (destination occupied)

Move hotbar item into storage, storage item into hotbar.

```
fromUUID = Hotbar[fromSlot]
toUUID = Storage[toSlot]

Hotbar[fromSlot] = toUUID
Storage[toSlot] = fromUUID

Update LocationByUUID for both UUIDs
```

### Hotbar -> Storage (destination empty)

Move hotbar item to storage. Hotbar slot becomes nil (Static) or triggers compaction (Dynamic).

```
fromUUID = Hotbar[fromSlot]

Hotbar[fromSlot] = nil
table.insert(Storage, fromUUID)

Update LocationByUUID for fromUUID
hotbarCompacted = compactHotbar(state)
```

### Storage -> Hotbar (destination occupied)

Move storage item into hotbar, hotbar item into storage.

```
fromUUID = Storage[fromSlot]
toUUID = Hotbar[toSlot]

Storage[fromSlot] = toUUID
Hotbar[toSlot] = fromUUID

Update LocationByUUID for both UUIDs
```

### Storage -> Hotbar (destination empty)

Move storage item to hotbar. Storage shifts left.

```
fromUUID = Storage[fromSlot]

Hotbar[toSlot] = fromUUID
table.remove(Storage, fromSlot)

Update LocationByUUID for fromUUID
Update LocationByUUID for all shifted storage items
```

---

## StackOnSwap Behavior

**Setting:** `Settings.StackOnSwap` (system-level, not per-player)

When `StackOnSwap = true` AND `CanStack = true`:

Before executing the positional swap, CoreStore checks if the items can stack. If they can, the source item is absorbed into the destination stack instead of swapping positions.

```
If StackOnSwap AND CanStack:
    fromItem = Items[fromUUID]
    toItem = Items[toUUID]

    if toItem exists AND canStack(fromItem, toItem):
        -- Absorb source into destination
        room = MaxStackSize - toItem.Amount
        transfer = min(fromItem.Amount, room)

        toItem.Amount += transfer
        fromItem.Amount -= transfer

        if fromItem.Amount <= 0:
            -- Source destroyed, remove from all indexes
            remove(fromUUID)

        -- No positional swap happens
        return { success = true, stacked = true }
```

When `StackOnSwap = false` (default) OR `CanStack = false`:

Swap is purely positional. Items exchange slots regardless of whether they could stack.

---

## Equipped Item Behavior

EquippedItemUUID follows the UUID, not the slot. If the equipped item is swapped from slot A to slot B, EquippedItemUUID still points to the same UUID. No equip/unequip logic needed.

```
-- Before swap
state.EquippedItemUUID = "uuid_sword"
-- sword is in Hotbar[1]

-- After swap (Hotbar[1] <-> Storage[1])
state.EquippedItemUUID = "uuid_sword"
-- sword is now in Storage[1]
```

---

## Sorting Interaction

If `Settings.Sorting = true`, auto-sort runs after the swap completes. This may reorder Storage.

---

## Complexity

- Hotbar <-> Hotbar: O(1)
- Storage <-> Storage: O(1)
- Cross-container: O(n) for Storage shift (Dynamic) + O(1) for Hotbar
- With StackOnSwap + canStack: O(k) where k = candidate stacks
