# CoreStore API

Pure Luau, no Roblox types. Every mutation returns a `Result`
(`{ok:true,value}` / `{ok:false,error={kind,message}}`); error kinds:
`PermissionDenied`, `InvalidArgument`, `NotFound`, `NotAvailable`.
Auto-sort (Storage only) triggers after every mutating call when
`Sorting` is on.

## Shapes

Everything below is built from four shapes:

```luau
SlotRef = { Type: "Hotbar" | "Storage", Slot: number }
-- `from` / `to`: the two ends of a swap, move, or drag.
-- `dest`: where a split-off stack lands (explicit slot, else auto-placed).

ItemInput = { Id: string?, Amount: number?, Metadata: ItemMetadata? }
-- `input`: what to add. Amount falls back through input.Amount, then
-- metadata.Amount, then metadata.StackAmount, then 1 (strings coerced,
-- garbage falls through, both keys cleaned out after).

AddOptions = { Placement: ("Auto" | "Hotbar" | "Backpack" | "Slot")?, Slot: number?, SlotRef: SlotRef? }
-- `opts`: where adds may land. `addToBackpack` forces Backpack,
-- `addToHotbar` forces Hotbar (+ optional slot number), `addToSlot` takes
-- an exact SlotRef that must be empty.

SettingsOverrides = { HotbarType?, MaxHotbarSlots?, Limit?, ... }
-- `overrides` on `new()`: every engine setting, all optional, merged over
-- defaults. Anything omitted keeps the default (see Settings).
```

## Create & inspect

| Function | One line |
|----------|----------|
| `new(overrides?)` | Empty state; overrides merge over defaults |
| `getDefaultSettings()` | Cloned defaults |
| `getItem(state, uuid)` | O(1) lookup |
| `find(state, query)` | By `ItemId` and/or metadata (indexed on Rarity/Type) |
| `filter(state, predicate)` | Full scan |
| `getAllItems(state)` | Everything |
| `getHotbarItemCount` / `getStorageItemCount` | Counts |
| `isEquipped` / `isFull` / `hasHotbarSpace` | Predicates |
| `compact(state)` | Pack Dynamic hotbar (no-op on Static) |
| `setHotbarType(state, t)` | Switch packing (auto-compacts to Dynamic) |

## Mutate

| Function | One line |
|----------|----------|
| `add(state, input, opts?)` | Normalize → stack into existing → new stacks; `overflow` on cap |
| `addToBackpack` / `addToHotbar(state, input, slot?)` / `addToSlot` | Placement-forced adds |
| `remove(state, uuid, amount?)` | Partial decrements; full destroys + clears slot |
| `removeBySlot(type, slot, amount?)` | UUID lookup → `remove` |
| `swap(from, to)` | Positional exchange; absorbs when `StackOnSwap` allows |
| `swapStack(from, to)` | Delegates to `swap` (single stacking truth) |
| `move(from, to)` | Positional only — never stacks |
| `split(uuid, amount, dest?)` | Source keeps UUID; capped at `MaxStackSize`; rollback on failure |
| `updateMetadata(uuid, updates)` | Merge keys, no re-stack; delete via `CoreStore.METADATA_DELETE` |
| `sort(state)` | Storage only (hotbar never sorted) |
| `equip(uuid)` / `unequip()` | Set/clear `EquippedItemUUID`, idempotent |

## Stacking

`canStack` needs all five: `CanStack` on, same `Id`, room under
`MaxStackSize`, neither rarity blacklisted (Legendary/Mythic/Special), all
`StackRequiredFields` (`Rarity`, `Type`) equal. Only `add` and
`swap`/`swapStack` (with `StackOnSwap`) ever merge. Amount fallback chain:
`input.Amount` → `metadata.Amount` → `metadata.StackAmount` → 1 (strings
coerced, garbage falls through, keys cleaned, `Droppable` defaults true).

Deep rulebook lives in [Deep Dives](../specs/SwapRules.md): swap/move/split/
sorting/metadata-update rules, invariants, and complexity targets.
