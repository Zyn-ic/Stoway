# CoreStore Specification

This document defines the exact behavior of every CoreStore operation as currently implemented. It is the source of truth for what the code does today.

New operations (swap, move, split, sort, updateMetadata) are defined in their own rule documents.

---

## InventoryState Shape

```luau
export type InventoryState = {
    -- O(1): UUID -> Item
    Items: { [string]: Item },

    -- O(1) to get all stack UUIDs for an item id
    -- ItemId -> array of UUIDs
    ItemsByID: { [string]: { string } },

    -- Slot -> UUID (Static: nil holes allowed)
    Hotbar: { string? },

    -- Array of UUIDs (Dynamic: packed, no holes)
    Storage: { string },

    -- O(1): UUID -> where this item currently lives
    LocationByUUID: { [string]: SlotRef },

    -- O(1): MetadataIndex[fieldName][fieldValue] -> array of UUIDs
    -- Indexed fields: Rarity, Type
    MetadataIndex: { [string]: { [string]: { string } } },

    EquippedItemUUID: string?,
    Weight: number,

    Settings: Settings,
}
```

### Field Rules

| Field | Type | Constraint |
|-------|------|-----------|
| Items | `{ [string]: Item }` | Every key is a UUID. Every value is a valid Item. |
| ItemsByID | `{ [string]: { string } }` | Every key is an ItemId. Every value is an array of UUIDs that exist in Items. |
| Hotbar | `{ string? }` | Indexed from 1 to MaxHotbarSlots. Values are UUIDs or nil. Static mode preserves holes. Dynamic mode is packed. |
| Storage | `{ string }` | Contiguous array of UUIDs. No nil holes. Indices shift on remove. |
| LocationByUUID | `{ [string]: SlotRef }` | Every key is a UUID that exists in Items. Value matches actual placement. |
| MetadataIndex | `{ [string]: { [string]: { string } } }` | Two-level index. First key is field name (e.g. "Rarity"). Second key is stringified field value (e.g. "Legendary"). Value is array of UUIDs with that metadata. Indexed fields: Rarity, Type. Updated on create, destroy, and metadata change. |
| EquippedItemUUID | `string?` | UUID of equipped item or nil. Must reference an existing item or be nil. |
| Weight | `number` | Sum of Amount across all items in Items. Always >= 0. |

---

## Settings

| Setting | Type | Default | Description |
|---------|------|---------|-------------|
| HotbarType | `"Static" \| "Dynamic"` | `"Static"` | Static allows holes. Dynamic compacts on remove. |
| MaxHotbarSlots | `number` | `10` | Maximum hotbar slot count. |
| Limit | `number` | `15` | Weight limit. 0 = infinite. |
| CanStack | `boolean` | `true` | Enable/disable stacking globally. |
| MaxStackSize | `number` | `5` | Maximum items per stack. |
| BackpackEnabled | `boolean` | `true` | Enable/disable storage container. |
| StackOnSwap | `boolean` | `false` | Allow stacking during swap and swapStack operations. Requires CanStack = true. |
| Sorting | `boolean` | `false` | Enable auto-sort after mutations. |
| SortOrder | `"None" \| "Name" \| "Rarity" \| "ItemType"` | `"None"` | Sort criteria when Sorting is enabled. |
| StackRequiredFields | `{ string }` | `{ "Rarity", "Type" }` | Metadata fields that must match for stacking. |
| StackBlacklist | `{ [string]: boolean }` | `{ Legendary = true, Mythic = true, Special = true }` | Rarities that cannot stack. |
| DefaultDroppable | `boolean` | `true` | Default Droppable value for new items. |

---

## Add Operation

**API:** `CoreStore.add(state, itemData, options?)`

### Flow

```
1. Normalize item data
   - Read Id or ID (case-insensitive key)
   - Read Amount, or metadata.Amount, or metadata.StackAmount
   - Parse string amounts to number
   - Remove Amount and StackAmount from metadata
   - Apply default Droppable = true if not set
   - Default amount = 1

2. Validate
   - ItemId must be a non-empty string
   - Amount must be a positive number

3. Check capacity
   - If Limit > 0 and remaining capacity <= 0: return FULL
   - Cap total amount to remaining capacity (partial fill)

4. Attempt stacking (if CanStack = true)
   - Pass Placement to tryStack for placement-aware stacking
   - Reduce amountLeft by stacked amount
   - Track updatedItems (UUID -> new Amount)

5. Place remaining amount as new stacks
   - Split into multiple stacks if amountLeft > MaxStackSize
   - Each new stack is capped at MaxStackSize
   - Placement priority based on options.Placement:

     Auto:    Hotbar -> Storage
     Backpack: Storage only
     Hotbar:  Hotbar only (optional slot number)
     Slot:    Specific SlotRef (future)

   - If no space for next stack: stop, overflow = remaining amount

6. Return result
   - addedAmount = total amount successfully placed
   - overflow = amount that could not be placed (no space)
```

### Overflow Example

```
Add Apple x12, MaxStackSize = 5, 5 slots available in Storage

Stack 1: Apple x5 -> Storage[1]
Stack 2: Apple x5 -> Storage[2]
Stack 3: Apple x2 -> Storage[3]  (remainder)

addedAmount = 12, overflow = 0
```

```
Add Apple x12, MaxStackSize = 5, 8 slots available total

Stack 1: Apple x5 -> Hotbar[1]
Stack 2: Apple x5 -> Hotbar[2]
Stack 3: Apple x2 -> Hotbar[3]

addedAmount = 12, overflow = 0
```

```
Add Apple x12, MaxStackSize = 5, Capacity = 10

Stack 1: Apple x5 -> placed
Stack 2: Apple x5 -> placed
No room for remainder

addedAmount = 10, overflow = 2
```

### Placement Modes

| Mode | Behavior |
|------|----------|
| `Auto` (default) | Try empty hotbar slot first. If hotbar full, try storage. |
| `Backpack` | Storage only. Bypasses hotbar entirely. |
| `Hotbar` | Hotbar only. Fails if no hotbar space. Optional `Slot` for specific slot. |
| `Slot` | Specific SlotRef placement. (Planned, not yet implemented) |

### Result Shape

```luau
{
    success: boolean,
    reason: string?,           -- "FULL", "PARTIAL", "ADD_FAILED", etc.
    addedItems: { AddedSlot }?, -- { uuid, slotType, slot } for each new stack
    updatedItems: { number }?,  -- { [uuid]: newAmount } for stacked-into items
    addedAmount: number?,       -- Total amount actually added
    overflow: number?,          -- Amount that could not be added
}
```

### Side Effects

- Creates Item entries in Items
- Updates ItemsByID
- Sets LocationByUUID for each new stack
- Increments Weight
- Appends to Storage or sets Hotbar slot

---

## Remove Operation

**API:** `CoreStore.remove(state, uuid, amount?)`

### Flow

```
1. Find item by UUID
   - If not found: return ITEM_NOT_FOUND

2. Determine amount to remove
   - Default: remove entire stack
   - Cap to item.Amount (cannot remove more than exists)

3. Partial removal (amount < item.Amount)
   - Reduce item.Amount
   - Decrement Weight
   - Return remaining amount

4. Full removal (amount >= item.Amount)
   a. Clear EquippedItemUUID if this item is equipped
   b. Decrement Weight by item.Amount
   c. Remove from Items
   d. Remove from ItemsByID (cleanup empty arrays)
   e. Remove from LocationByUUID
   f. Clear Hotbar slot or remove from Storage
   g. If HotbarType = "Dynamic": compact hotbar
```

### Result Shape

```luau
{
    success: boolean,
    reason: string?,            -- "ITEM_NOT_FOUND", "INVALID_AMOUNT"
    removedItem: Item?,         -- Copy of removed item data
    remaining: number?,         -- Amount remaining after partial remove
    slotType: SlotType?,        -- Where the item was
    slot: number?,              -- Slot index
}
```

### Side Effects

- Decrements Weight
- Removes Item from Items
- Removes UUID from ItemsByID
- Removes LocationByUUID entry
- Clears Hotbar slot or shifts Storage
- Compacts Hotbar if Dynamic

---

## Stack Rules

**Module:** `Stack.luau`

### canStack Conditions

All conditions must be true for stacking:

```
1. Settings.CanStack = true
2. existingItem.Id == incomingItemId
3. existingItem.Amount < Settings.MaxStackSize
4. existingItem.Metadata.Rarity NOT in Settings.StackBlacklist
5. incomingMetadata.Rarity NOT in Settings.StackBlacklist
6. Metadata.matchesRequiredFields passes for all Settings.StackRequiredFields
```

### tryStack Flow

```
1. Look up ItemsByID[itemId] for candidate UUIDs
2. For each candidate (in order):
   a. If Placement is specified and not "Auto":
      - Backpack: only stack into items in Storage
      - Hotbar: only stack into items in Hotbar
   b. Check canStack conditions
   c. Calculate room = MaxStackSize - existingItem.Amount
   d. Transfer min(room, amount) into existing stack
   e. Increment Weight by transfer amount
   f. Reduce amount by transfer
3. Return total stacked amount and updated items map
```

### Placement-Aware Stacking

Stacking respects the Placement parameter:

| Placement | Stacking Target |
|-----------|----------------|
| `Auto` or nil | Any existing stack of the same item |
| `Backpack` | Only stacks in Storage |
| `Hotbar` | Only stacks in Hotbar |

This ensures `addToBackpack` does not accidentally stack onto hotbar items.

---

## Query Rules

### getItem(state, uuid)

- **Complexity:** O(1)
- **Returns:** Item or nil
- **Behavior:** Direct lookup in Items[uuid]

### findById(state, itemId)

- **Complexity:** O(k) where k = number of stacks with this ItemId
- **Returns:** Array of Items
- **Behavior:** Reads ItemsByID[itemId], then looks up each UUID in Items

### find(state, query)

- **String query:** Delegates to findById. O(k).
- **Table query with single indexed metadata field:** Uses MetadataIndex for O(k) lookup where k = items matching that field value.
- **Table query with multiple indexed metadata fields:** Picks the smallest MetadataIndex bucket, then filters remaining fields. O(k) where k = smallest bucket size.
- **Table query with no indexed metadata fields:** Falls back to full Items scan. O(n).
- **Returns:** Array of Items matching all query fields

### filter(state, predicate)

- **Complexity:** O(n) where n = total items
- **Returns:** Array of Items where predicate returns true

### getAllItems(state)

- **Complexity:** O(n) where n = total items
- **Returns:** Array of all Items

---

## Slot Rules

### Hotbar (Static Mode)

- Fixed size: 1 to MaxHotbarSlots
- Nil holes allowed (slot 3 can be empty while slot 4 is filled)
- `setHotbarSlot(state, slot, uuid)` - sets slot and updates LocationByUUID
- `clearHotbarSlot(state, slot)` - sets slot to nil, removes LocationByUUID
- `findEmptyHotbarSlot(state)` - returns first nil slot, or nil
- `compactHotbar(state)` - no-op in Static mode

### Hotbar (Dynamic Mode)

- Same fixed size
- No nil holes allowed — always packed left
- The only available slot is the append position (first nil after the packed portion)
- Operations that target a non-append slot are rejected with `DESTINATION_UNAVAILABLE`
- `compactHotbar(state)` - shifts all items left to fill holes
  - Updates LocationByUUID for each shifted item
  - Only runs if HotbarType = "Dynamic"

### Dynamic Hotbar Slot Availability

In Dynamic mode, the hotbar is always `[item1, item2, ..., itemN, nil, nil, ...]`. The only "available" slot is `findEmptyHotbarSlot(state)` — the first nil after the packed portion.

Use `CoreStore.setHotbarType(state, "Dynamic")` to switch types — it auto-compacts the hotbar. Alternatively, call `CoreStore.compact(state)` after manually changing `Settings.HotbarType`.

| Operation | Dynamic Mode Behavior |
|-----------|----------------------|
| `add` (no preferred slot) | Appends to end via `findEmptyHotbarSlot` |
| `add` (preferred slot) | Preferred slot is ignored; always appends to end |
| `swap` Hotbar→Hotbar, dest occupied | Allowed (reorder within packed portion) |
| `swap` Hotbar→Hotbar, dest empty | Rejected: `DESTINATION_UNAVAILABLE` |
| `move` Hotbar→Hotbar | Rejected: `DESTINATION_UNAVAILABLE` (no empty slots in packed portion) |
| `move` Storage→Hotbar | Allowed only if `toRef.Slot == findEmptyHotbarSlot()` |
| `split` to Hotbar | Allowed only if `destination.Slot == findEmptyHotbarSlot()` |

### Storage

- Dynamic array, no holes
- `appendStorage(state, uuid)` - appends to end, updates LocationByUUID
- `removeStorageAt(state, index)` - removes and shifts all subsequent items left
  - Updates LocationByUUID for each shifted item

### LocationByUUID

- Always reflects actual placement
- Updated whenever an item moves between slots
- Entry created on item placement
- Entry removed on item destruction
- Entry updated on hotbar compaction

---

## Compaction

Compaction is the process of packing a Dynamic hotbar's items left to eliminate nil holes. It only applies when `HotbarType = "Dynamic"`. In Static mode, compaction is a no-op.

### Algorithm

```
compactHotbar(state):
  1. If HotbarType ~= "Dynamic": return false (no-op)

  2. Create empty array packedHotbar
  3. writeIndex = 1

  4. For readIndex = 1 to MaxHotbarSlots:
     a. uuid = Hotbar[readIndex]
     b. If uuid exists:
        - packedHotbar[writeIndex] = uuid
        - If readIndex ~= writeIndex:
            Mark changed = true
            Update LocationByUUID[uuid].Slot = writeIndex
        - writeIndex += 1
     c. If uuid is nil: skip (hole eliminated)

  5. If changed: state.Hotbar = packedHotbar
  6. Return changed
```

### Example

```
Before (holes at slots 2, 4):
  Slot:  [1]  [2]  [3]  [4]  [5]
         "A"  nil  "B"  nil  "C"

After compaction:
  Slot:  [1]  [2]  [3]  [4]  [5]
         "A"  "B"  "C"  nil  nil

LocationByUUID updated:
  "A" -> Slot 1 (unchanged)
  "B" -> Slot 2 (was Slot 3)
  "C" -> Slot 3 (was Slot 5)
```

### When Compaction Runs

| Operation | Compacts? | Notes |
|-----------|-----------|-------|
| `remove()` | Yes | After clearing hotbar slot |
| `move()` hotbar→storage | Yes | After setting hotbar slot to nil |
| `swap()` hotbar→empty storage | Yes | After clearing hotbar slot |

### Static vs Dynamic Behavior

| Behavior | Static | Dynamic |
|----------|--------|---------|
| Holes after remove | Preserved (nil stays) | Eliminated (items shift left) |
| Slot indices after remove | Unchanged | All items after the hole shift down by 1 |
| Client visibility | All MaxHotbarSlots frames always visible | Empty frames hidden, visible ones reindexed |
| Full state sync needed | No | Yes (when compaction changes indices) |

---

## Complexity Targets

| Operation | Target | Notes |
|-----------|--------|-------|
| **Queries** | | |
| getItem | O(1) | Direct hash lookup |
| findById | O(k) | k = matching stacks with this ItemId |
| find (string) | O(k) | Delegates to findById |
| find (single metadata field) | O(k) | k = items in MetadataIndex bucket; O(1) when indexed field |
| find (multi metadata field) | O(k) | k = smallest bucket, then filter remaining fields |
| find (no metadata, table) | O(n) | Full scan when no indexed fields match |
| filter | O(n) | n = total items |
| getAllItems | O(n) | n = total items |
| **Mutations** | | |
| add (stack into existing) | O(k) | k = existing stacks of same item (via ItemsByID) |
| add (new stack) | O(1) | Amortized |
| remove (partial) | O(1) | In-place Amount decrement |
| remove (full, hotbar) | O(h) | h = compactHotbar in Dynamic mode |
| remove (full, storage) | O(n) | n = Storage shift left via table.remove |
| removeBySlot | Same as remove | Delegates to remove after slot lookup |
| **Slot Operations** | | |
| swap (HH or SS) | O(1) | Direct slot exchange |
| swap (HS, dest occupied) | O(1) | Direct slot exchange |
| swap (HS, dest empty) | O(h) | Hotbar compaction in Dynamic mode |
| swap (SH, dest occupied) | O(1) | Direct slot exchange |
| swap (SH, dest empty) | O(n) | Storage shift left via table.remove |
| swap (with StackOnSwap) | O(k) | k = candidate stacks for stacking |
| swapStack | Same as swap | Explicit route with the same StackOnSwap-gated behavior and positional fallback |
| move (HH) | O(1) | Direct slot assignment |
| move (HS) | O(h) | Hotbar compaction in Dynamic mode |
| move (SH) | O(n) | Storage shift left + set hotbar |
| move (SS reorder) | O(n) | Storage shift within array |
| split | O(1) | Creates new item + placement |
| **Maintenance** | | |
| compactHotbar | O(h) | h = MaxHotbarSlots; no-op in Static mode |
| sort (storage) | O(s log s) | s = number of storage items |
| updateMetadata | O(f) | f = number of fields updated; maintains MetadataIndex |
| canStack | O(f) | f = number of StackRequiredFields |
| Weight tracking | O(1) | Tracked incrementally via addWeight/removeWeight |
| MetadataIndex (add/remove) | O(f) | f = number of indexed fields (currently 2: Rarity, Type) |
| MetadataIndex (update) | O(f) | f = number of indexed fields; remove old + insert new |
| ItemsByID (add/remove) | O(1) | Amortized array insert/remove |

### Where h, s, n, k, f are defined:

- **h** = MaxHotbarSlots (hotbar size)
- **s** = #state.Storage (storage item count)
- **n** = total items across both containers
- **k** = matching items for a given ItemId or metadata value
- **f** = number of fields (StackRequiredFields for canStack, indexed fields for MetadataIndex, keys in updates for updateMetadata)
