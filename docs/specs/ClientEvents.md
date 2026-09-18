# Client Events (Hooks/Signals) Specification

Client-side UI event system for StowayClientV3. Any client system (notification
service, sounds, shine, tutorials) can subscribe; skin `HookFuncs` modules are
privileged subscribers, not the transport.

---

## Two-Layer Model

Generic payloads and skin-specific payloads are deliberately separate. There is
no generic typed thing for skin differences.

- **Layer 1 — generic bus** (`Controller/ClientEvents.luau`): fixed minimal
  payloads (`slotType`, `index`, `uuid`), typed once with SignalPlus, stable
  forever. External systems connect here.
- **Layer 2 — skin-direct calls**: skin `HookFuncs` functions are invoked
  directly at call sites with skin-specific args (`btn`, `frame`, scope parts),
  typed in that skin's own `HookPayloads` table. Passing a button on one skin
  and nothing on another is expected and type-checked per skin.

## Layer 1 — Generic Bus Catalog

| Signal | Payload | Fired from | When |
|---|---|---|---|
| `SlotClicked` | `(slotType: SlotType, index: number, uuid: string?)` | `SlotView` Activated | tap/click lands (post drag-guard) |
| `SlotHovered` | `(slotType, index)` | `SlotView` MouseEnter | hover begins (frame/btn available via lookup, not payload) |
| `DragStarted` | `(slotType, index)` | `PointerDragService` begin | threshold crossed, ghost created |
| `DragEnded` | `(slotType, index)` | `PointerDragService` end | release, before commit |
| `Equipped` | `(slotType, index)` | equip call sites | `res.ok` only |
| `Unequipped` | `(slotType, index)` | unequip call sites | `res.ok` only |
| `ItemAdded` | `(slotType, index)` | `ClientController` wrappers | post-success (covers binds, drag, server deltas) |
| `ItemRemoved` | `(slotType, index)` | `ClientController` wrappers | post-success |
| `Swapped` | `(fromType, fromSlot, toType, toSlot)` | `ClientController` wrappers | post-success |
| `Selected` | `(slotType, index)` | per-slot `Observer` on `isEquipped` | any equip source (click, bind, server) |
| `Deselected` | `(slotType, index)` | per-slot `Observer` on `isEquipped` | any unequip source |

`SlotType` is `"Hotbar" | "Storage"`. Payloads never contain frames, buttons,
or scopes — subscribers resolve visuals themselves.

## Layer 2 — Skin-Direct Calls

Skin functions keep their bespoke signatures (reference shape):

```luau
OnSlotClick(slotType, index, uuid)
OnSlotHover(btn: GuiButton, slotType, slotIndex)
OnDragStart(type, index) / OnDragEnd(type, index)
OnEquip(type, index) / OnUnequip(type, index)
OnItemAdd(type, index) / OnItemRemove(type, index)
OnSwap(type, index)
OnSelect(frame, slotType, slotIndex) / OnDeselect(frame, slotType, slotIndex)
```

Each skin owns a `HookPayloads` type table describing exactly what its
functions receive. `DefaultHooks` and `MetalHooks` may differ freely.

## Type-Change Protocol

Sending something new (or nothing where something was sent) touches exactly
three places, in order. Dual-solver `luau-lsp` analyze is the CI that catches
drift — a mismatched call site fails type-check, never silently:

1. **Skin `HookPayloads` type** — add/change the parameter type.
2. **Skin hook function** — add/change the parameter in the signature.
3. **Fire site(s)** — pass (or stop passing) the variable where the event fires.

Generic bus payloads (Layer 1) change only by full-team decision; they are
stability-locked once external subscribers exist.

## Handler Discipline

- Bus fires are synchronous. External handlers stay fast; defer heavy work
  with `task.defer`.
- Skin-direct calls go through `ClientEvents.CallHook`, which `task.spawn`s
  every invocation before `pcall`-wrapping it. Spawn is mandatory: stock
  `OnSlotHover` yields (two `task.wait`s in its tween) and a synchronous
  call would stall the input/drag thread. A throwing hook warns once with
  its name and never breaks inventory.
- Connections parent to the layout scope. `LayoutManager:Teardown` cleans
  them — same discipline as the input/pointer leak sweeps.
- Passed frames/buttons are borrowed, not owned. Subscribers must never
  destroy, reparent, or permanently restyle them (`OnSelect`'s highlight
  stroke must be removed by `OnDeselect`).
- Skin functions may assume only what the skin contract guarantees:
  a hovered `slotbutton` carries a `UIStroke` child (stock `OnSlotHover`
  tweens `Thickness` 0→5→0); `OnSelect` parents a `SelectionHighlight`
  `UIStroke` to the cell, `OnDeselect` destroys it.
- Operation events fire on `res.ok` only — subscribers never see phantom
  events. `OnSwap` reports the DESTINATION slot. Move/Split/SwapStack
  successes intentionally fire nothing (no signal/hook exists for them).

## Transport Separation

Operation `Signals` (`Add`/`Remove`/`Swap`/…) are the data transport that
QuickNet eventually replaces. UI events are presentation-only and survive
that migration untouched. See `NetworkProtocol.md` for the wire.

## Worked Example — Notification Service

```luau
ClientEvents.ItemAdded:Connect(function(slotType, index)
	task.defer(function()
		SoundService:Play("ItemGet")
		ToastBus:Show(("New item in %s #%d"):format(slotType, index))
	end)
end)
```

The `New`-item white glow reads `Metadata.IsNew`, not the bus: glow
while the flag is present, equip deletes the key via `updateMetadata` +
`METADATA_DELETE`. (`SeenIds`/`SeenState` session set is deleted.)
