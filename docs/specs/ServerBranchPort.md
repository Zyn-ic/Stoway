# Server Branch Port Ledger

Running list of changes made on the `client-v3-sonnet` branch touching
shared territory (`ReplicatedStorage/**`, `src/server/**`, `docs/specs/*`).
Replay each entry onto the server branch when the time comes. Client-only
files (`src/client/**`) never appear here.

Status: `[ ]` to port · `[x]` ported.

---

## Entry 1 — Request-event registration `[ ]`

- **File:** `ReplicatedStorage/Shared/Stoway/StowayRemotes.luau`
- **What:** registered 12 client→server QuickNet events from the existing
  `ClientPayloads` shapes (`AddItem`, `AddToBackpack`, `AddToHotbar`,
  `RemoveItem`, `SwapSlots`, `Move`, `Split`, `EquipSlot`, `UnequipSlot`,
  `UpdateMetadata`, `Sort`) plus a new `SwapStack` entry (`{SlotRef,
  SlotRef}`, same shape as `SwapSlots` — it had a schema-less hole).
  Registered under operation names, not `Inventory*` wire names.
- **Why:** the client `NetworkClient` FireServers these; the server branch
  listens on this same module so names stay in sync by construction.
- **Port:** copy the 12 lines in the return table plus the `SwapStack`
  `ClientPayloads` line. Server branch then adds `OnServerEvent`
  listeners per `docs/specs/NetworkProtocol.md`.
- **Note:** `NetworkProtocol.md` documents `SlotRef = {Container, Slot}`
  but the wire schema (and all code) uses `{Type, Slot}`. Decide the
  canonical shape during port; client sends `Type`.

## Entry 2 — Added push carries the full item `[ ]`

- **Files:** `ReplicatedStorage/Shared/Stoway/StowayRemotes.luau`,
  `src/server/Services/StowayServerV3_0_0/Communications.luau`
- **What:** new `ItemData` schema (`UUID`, `Id?`, `Amount?`, open
  `Metadata?`) + `AddedPayload` (`SlotChange` fields + required `item`);
  `InventoryAdded` re-registered on it. Adapter includes
  `state.Items[added.uuid]` (looked up via widened `StowayApi.get`,
  skips + warns when absent).
- **Why:** the old payload (`uuid`/`slotType`/`slot` only) gave the
  client nothing to insert. The client now inserts verbatim at the
  reported slot (server UUID authoritative).
- **Port:** copy the schema block, the registration line, and the adapter
  Add branch. Client listen side (`NetworkClient.Connect` +
  `ClientController.ApplyServer*`) needs no port — already here.
- **Known gaps (server-branch work, not this branch):** `RevertPayload`
  carries an error message where slot data belongs (client log-only);
  no pushes exist for Swap/Move/Split/Sort/UpdateMetadata — chat
  commands for those stay server-console-only.
