# Glossary

**CoreStore**: pure-Luau engine. No Roblox types, no UI, no networking.

**Route**: a server function (`SwapSlots`, `Drop`…) that locks, mutates, and
dispatches to adapters.

**Adapter**: a function registered with `registerAdapter` that reacts to every
route result. Communications (the QuickNet bridge) is one; a logger or a
saver would be others.

**Replicate**: opt-in flag that echoes a server-side change to the client.
Omitted means silent.

**FullSync**: whole-inventory push — items, slots, equipped, weight, and the
settings snapshot. Heals any divergence wholesale.

**Optimistic**: the client applies first, the server corrects.

**Layout**: the engine that decides behavior (`HotbarType`).
**Skin**: the look. A layout mounts against a skin at boot.

**Atom**: a Fusion `Value` in `ClientStore` (`Items`, `Hotbar`, `Storage`,
`EquippedItemUUID`, `Weight`, `Settings`).

**Hotbar / Storage / Backpack**: Hotbar is the slot row; Storage is the
packed array; "Backpack" is the UI name for Storage.

**SlotRef**: `{ Type: "Hotbar"|"Storage", Slot: number }` — every slot
address in the system.
