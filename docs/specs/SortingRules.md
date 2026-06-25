# Sorting Rules

Sorting reorders items within containers based on configurable criteria. In CoreStore, sorting is automatic when enabled via `Settings.Sorting = true`.

---

## API

```luau
CoreStore.sort(state) -> SortResult
```

### Result Shape

```luau
{
    success: boolean,
    hotbarOrder: { string }?,    -- New hotbar UUID order (if changed)
    storageOrder: { string }?,   -- New storage UUID order (if changed)
}
```

---

## Trigger Model

Sorting is automatic. It runs after any operation that mutates slot contents when `Settings.Sorting = true`.

### Operations That Trigger Sort

| Operation | Triggers Sort | Scope |
|-----------|--------------|-------|
| add | Yes | Both Hotbar and Storage |
| addToBackpack | Yes | Storage only |
| addToHotbar | Yes | Hotbar only |
| remove | Yes | Both (reorder remaining) |
| swap | Yes | Both (reorder affected container) |
| move | Yes | Both (reorder affected container) |
| split | Yes | Both (reorder destination container) |
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

### Default: Both Containers

When `Settings.Sorting = true`, both Hotbar and Storage are sorted independently.

### Hotbar Sorting

Only affects Hotbar if HotbarType = "Dynamic". In Static mode, hotbar order is fixed by the player and should not be auto-sorted.

```
If HotbarType == "Static":
    Skip hotbar sorting
If HotbarType == "Dynamic":
    Sort hotbar items
```

### Storage Sorting

Always sorts Storage when enabled.

---

## Sort Criteria

Determined by `Settings.SortOrder`:

### SortOrder = "Name"

Sort by `item.Id` alphabetically.

```
"Apple" < "Potion" < "Sword"
```

### SortOrder = "Rarity"

Sort by `item.Metadata.Rarity` using a fixed rarity rank:

```
Common = 1
Uncommon = 2
Rare = 3
Epic = 4
Legendary = 5
Mythic = 6
Special = 7
```

Unknown rarities sort after all known rarities.

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
1. Read current item order from container
2. Sort items by SortOrder criteria
3. Write new UUID order back to container
4. Update LocationByUUID for all moved items
```

### Hotbar Sort (Dynamic)

```
currentUUIDs = [uuid for uuid in Hotbar if uuid ~= nil]
sortedUUIDs = stableSort(currentUUIDs, by SortOrder)
Hotbar = sortedUUIDs
Update LocationByUUID for each UUID
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

In the future, `CoreStore.sort(state, { Order = "Rarity", Scope = "Storage" })` may accept options to override Settings for a one-time sort. This is not yet implemented.

---

## Complexity

- Reading items: O(n)
- Sorting: O(n log n)
- Writing back: O(n)
- LocationByUUID updates: O(n)
- Total: O(n log n) where n = number of items in container
