# Sorting Rules

Sorting reorders items within containers based on configurable criteria. In CoreStore, sorting applies to **Storage only**. The Hotbar is never sorted — it is always user-controlled.

---

## API

```luau
CoreStore.sort(state) -> SortResult
```

### Result Shape

```luau
{
    success: boolean,
    storageOrder: { string }?,   -- New storage UUID order (if changed)
}
```

---

## Trigger Model

Sorting is automatic. It runs after any operation that mutates slot contents when `Settings.Sorting = true`.

### Operations That Trigger Sort

| Operation | Triggers Sort | Scope |
|-----------|--------------|-------|
| add | Yes | Storage only |
| addToBackpack | Yes | Storage only |
| addToHotbar | Yes | Storage only |
| remove | Yes | Storage (reorder remaining) |
| swap | Yes | Storage (if affected) |
| move | Yes | Storage (if affected) |
| split | Yes | Storage (if destination) |
| sort | No (already sorting) | N/A |

### Trigger Timing

Sort runs **after** the primary operation completes and all invariants are satisfied. It is the last step in any mutating operation.

```
1. Execute primary operation (add, remove, swap, etc.)
2. Verify invariants
3. If Settings.Sorting = true: run sort
4. Return result
```

---

## Scope

### Storage Only

Sorting only affects Storage. The Hotbar is never sorted — it is always user-controlled.

`Slots.sortHotbar()` exists as a utility function for callers who need it, but `Operations.sort()` and `triggerAutoSort()` only sort Storage.

---

## Sort Criteria

Determined by `Settings.SortOrder`:

### SortOrder = "Name"

Sort by `item.Id` alphabetically.

```
"Apple" < "Potion" < "Sword"
```

### SortOrder = "Rarity"

Sort by `item.Metadata.Rarity` using a fixed rarity rank. Items are sorted **descending** (highest rarity first):

```
Special = 7 (first)
Mythic = 6
Legendary = 5
Epic = 4
Rare = 3
Uncommon = 2
Common = 1 (last)
```

Unknown rarities sort after all known rarities (equivalent to rank 99).

Ties (same rarity) are broken alphabetically by `item.Id`.

### SortOrder = "ItemType"

Sort by `item.Metadata.Type` alphabetically.

```
"Ammo" < "Consumable" < "Food" < "Weapon"
```

### SortOrder = "None"

No sorting. Default behavior.

---

## Sort Stability

When two items have the same sort key, their relative order is preserved (stable sort). This means:

- Two "Potion" items with different Metadata maintain their insertion order
- Two "Common" rarity items maintain their insertion order

---

## Sort Algorithm

```
1. Read current item order from Storage
2. Sort items by SortOrder criteria
3. Write new UUID order back to Storage
4. Update LocationByUUID for all moved items
```

### Storage Sort

```
sortedUUIDs = stableSort(Storage, by SortOrder)
Storage = sortedUUIDs
Update LocationByUUID for each UUID at new index
```

---

## Invariants Preserved

Sorting preserves all state invariants:

- INV-1 (UUID Ownership): No items created or destroyed
- INV-2 (Single Location): Only reorders within container
- INV-3 (LocationByUUID): Updated for all moved items
- INV-4,5 (ItemsByID): Not affected (no item changes)
- INV-6 (Weight): Not affected (no amount changes)
- INV-9 (Storage Contiguity): Reorder maintains contiguity

---

## Manual Sort

In the future, `CoreStore.sort(state, { Order = "Rarity" })` may accept options to override Settings for a one-time sort. This is not yet implemented.

---

## Complexity

- Reading items: O(n)
- Sorting: O(n log n)
- Writing back: O(n)
- LocationByUUID updates: O(n)
- Total: O(n log n) where n = number of items in Storage
