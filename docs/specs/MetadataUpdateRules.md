# Metadata Update Rules

Metadata updates allow external systems to modify item metadata after creation. All metadata is mutable in CoreStore.

---

## API

```luau
CoreStore.updateMetadata(state, uuid, updates) -> MetadataUpdateResult
```

### Parameters

| Parameter | Type | Description |
|-----------|------|-------------|
| state | InventoryState | The inventory state |
| uuid | string | UUID of the item to update |
| updates | { [string]: any } | Key-value pairs to merge into metadata |

### Deleting a Field

Lua tables can never hold a nil value, so `{ Enchant = nil }` produces an **empty** table and deletes nothing. To remove a metadata field, set it to the `METADATA_DELETE` sentinel:

```luau
CoreStore.updateMetadata(state, uuid, { Enchant = CoreStore.METADATA_DELETE })
```

`CoreStore.METADATA_DELETE` is `"__STOWAY_DELETE__"`, a namespaced string exported from the CoreStore facade and from `ReplicatedStorage/StowayRemotes.luau`. It survives the wire as a plain string, so clients delete fields with `StowayRemotes.METADATA_DELETE`. Deleting an indexed field (Rarity/Type) also evicts the UUID from its `MetadataIndex` bucket.

### Result Shape

```luau
{
    success: boolean,
    reason: string?,
    updatedFields: { string }?,  -- List of fields that changed
    reStacked: boolean?,         -- True if stacking state changed
    unStacked: boolean?,         -- True if item was split from stack
}
```

---

## Flow

```
1. Validate
   - UUID must exist in Items

2. Apply updates
   - For each key in updates:
     - If key exists: overwrite value
     - If key does not exist: add key-value pair
     - If value is the `METADATA_DELETE` sentinel: remove key from metadata
       (note: `{ Key = nil }` is an empty table in Lua and deletes nothing)

3. Evaluate stacking impact
   - Check if metadata changes affect stacking eligibility
   - If item was stackable and now is not: potentially un-stack
   - If item was not stackable and now is: potentially re-stack

4. Return result
```

---

## Mutability Rules

**All metadata is mutable.** This includes fields that affect stacking behavior.

### Mutable Fields (Examples)

| Field | Effect of Change |
|-------|-----------------|
| Rarity | May affect stack blacklist eligibility |
| Type | May affect stack required fields matching |
| Description | No stacking impact |
| Damage | No stacking impact |
| Durability | No stacking impact |
| Droppable | No stacking impact (used by drop system) |
| Image | No stacking impact |
| Custom fields | No stacking impact (unless added to StackRequiredFields) |

---

## Stacking Impact

When metadata changes, CoreStore must decide what happens to existing stacks.

### Scenario 1: Metadata Change Does Not Affect Stacking

If the changed fields are not in `StackRequiredFields` and not in `StackBlacklist`, no stacking changes occur.

```
Example: Update Damage from 10 to 20
Result: Item unchanged in stacking. No re-stack needed.
```

### Scenario 2: Metadata Change Breaks Stacking

If the item was part of a stack and the metadata change makes it no longer stackable with its siblings, the item is **not** automatically un-stacked. The stack remains as-is until a future operation (like split or remove) separates it.

```
Example: Item has Rarity = "Common", stacked with other Commons
         Update Rarity to "Legendary" (blacklisted)
Result: Stack remains. But next time items are added, this stack
        will not accept new Legendary items from other stacks.
        CanStack check will reject new merges into this stack.
```

**Reason:** Automatically un-stacking would create cascading side effects. The caller should explicitly split if they want separation.

### Scenario 3: Metadata Change Enables Stacking

If the item was not stackable and now is, nothing happens immediately. Future add operations may stack into this item.

```
Example: Item has Rarity = "Legendary" (blacklisted)
         Update Rarity to "Common"
Result: Stack remains. Next add of Common items may stack into this one.
```

---

## Stacking Re-evaluation (Future)

A future `reStack(state, uuid)` function could be added to explicitly re-evaluate an item's stacking position:

```
-- Future API
CoreStore.reStack(state, uuid)
  - Remove item from current stack position
  - Re-run stacking logic to find best stack
  - If no compatible stack found, create standalone
```

This is not yet implemented. For now, metadata updates do not trigger automatic re-stacking.

---

## Index Updates

Metadata changes do not affect:
- Items (the Item object is modified in-place)
- ItemsByID (UUID stays the same, Id stays the same)
- LocationByUUID (position stays the same)
- Hotbar/Storage (slot stays the same)
- Weight (Amount is unchanged)

Only the Item.Metadata table is modified.

---

## Sorting Interaction

If `Settings.Sorting = true`, auto-sort runs after metadata update. This may reorder items if the metadata change affects sort order (e.g., changing Rarity changes rarity-based sort position).

---

## Edge Cases

| Scenario | Behavior |
|----------|----------|
| updates is empty | No change, return success with empty updatedFields |
| Key set to `CoreStore.METADATA_DELETE` | Remove key from metadata (and from MetadataIndex if indexed) |
| Key set to nil (inline) | No-op — `{ Key = nil }` produces an empty table, key untouched |
| Key set to same value | No change, but listed in updatedFields |
| Update equipped item | Allowed, no equip/unequip triggered |
| Update blacklisted item to un-blacklisted | No immediate re-stack |

---

## Complexity

- Validation: O(1)
- Apply updates: O(k) where k = number of fields updated
- Stacking evaluation: O(1) (check against settings)
- Sorting trigger: O(n log n) if Sorting enabled
- Total (no sort): O(k)
- Total (with sort): O(n log n)
