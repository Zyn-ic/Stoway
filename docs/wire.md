# Wire Reference

QuickNet events (`StowayRemotes`), one named table per event. Client ops run
silent; the server talks back on failures and on server-initiated changes.

## Server → client

| Event | When | Payload |
|---|---|---|
| `InventoryAdded` | Replicated add | `uuid`, `slotType`, `slot`, full `item` (server UUID wins) |
| `InventoryUpdated` | Stack absorb | `uuid`, `newAmount` |
| `InventoryRemoved` | Remove / drop | `uuid`, `slotType?`, `slot?` |
| `InventoryEquipped` / `InventoryUnequipped` | Equip changes | `uuid?`, `previousUUID?` |
| `InventoryFullSync` | Swap/move/split/metadata/sort pushes, every failure, join, sync requests | Items, Hotbar, Storage, equipped, weight, full settings snapshot |
| `InventoryRevert` | Failed swap/stack only | `success=false`, `fromSlot` (log-only on receipt) |
| `LayoutChanged` | Skin/layout switch | layout, skin |
| `SettingsChanged` | Sparse engine-setting change | Patch (all fields optional) |

## Client → server

One `FireServer` per op: `AddItem` / `AddToBackpack` (`input`, `options?`),
`AddToHotbar` (`input`, `preferredSlot?`), `RemoveItem`, `SwapSlots` /
`SwapStack` / `Move` (`from`, `to`), `Split`, `EquipSlot`, `UnequipSlot`
(bare), `UpdateMetadata` (`uuid`, `updates`), `Sort` (bare), `Drop`, plus
bare `RequestInventorySync`.

## Replicate matrix

| Origin | `replicate` | Client hears |
|---|---|---|
| Client op, accepted | `false` | Nothing (it already predicted) |
| Client op, rejected | `false` | `InventoryRevert` (swap only) + `FullSync` |
| Console / game code | `true` | Delta for add/remove/equip, `FullSync` otherwise |

## Throttle

Only `RequestInventorySync` is throttled: 15 s per player, stamped on every
push so a boot request racing the join push coalesces. Failure corrections
are not rate-limited.
