# Stoway Roadmap / Task Sheet

Living task list: client completion → connection → world integration.
Status: `[ ]` todo · `[/]` in progress · `[x]` done.

Commit `95fc83b` is the baseline (skin-attribute contract, flat skin tree,
ghost/layout hardening, sparse binds, deselect-on-empty).

---

## Phase 0 — Hooks/Signals `[ ]`

- [ ] Read `DefaultHooks`/`MetalHooks` contents in Studio; freeze event set
      (spec: `docs/specs/ClientEvents.md`)
- [ ] New `Controller/ClientEvents.luau` generic bus (11 signals, SignalPlus)
- [ ] Wire 6 call-site groups: SlotView click/hover/select-observer,
      PointerDragService begin/end, ClientController wrappers
- [ ] Skin adapter in `DefaultModern.Load`: require `HookFuncs`, `pcall`
      each function, scope-parent connections
- [ ] First external subscriber: notification example (toast + sound)
- [ ] Dual-solver green + Studio specs for fire sites
- Accept: every hook in the table fires with its documented payload on both
  skins; a throwing hook never breaks inventory (pcall); teardown leaks zero
  connections.

## Phase 1 — Small Client `[x]`

- [x] `New` white glow: `Metadata.IsNew` flag (seeded on SteelDagger +
      FireBow + HealthPotion; `normalize` passes it through), `SlotView`
      white `NewGlow` UIShadow halo on the CELL (`slotFrame`, Blur 0.3,
      Spread via `GlowSpread`, base Transparency 0.58 breathing 0.51<->0.66
      on a 1s sine) so the opaque Default button occludes while
      transparent Modern/Metal stay dark. `equipAndClearNew` (shared by
      `ClientController.Equip` + `signals.Equip`) deletes the key via
      `updateMetadata` + `METADATA_DELETE`. `SeenState` session set
      deleted. Test signal `Signals.MarkNew` stamps `IsNew` onto any uuid
      (LocalScript smoke: MarkNew / equip-deletes-IsNew pass, no
      `infiniteLoop`).
- [x] Modern backpack RivetLite: `GUI/Modern` panel → slot-cell charcoal
      (30,30,36 @ 0.15) + 8px corner + 2px edge stroke; dark inset search
      (white text, grey placeholder); white bold weight; bronze slim
      scrollbar + scroll inset. Code-built headers → 6px corner + 1px
      stroke + 0.35 transparency + label padding (category colors kept).
- [x] 1:1 skin mapping: generic `Skins/SkinLoader` + `Default`/`Modern`/
      `Metal` per-skin keys; `LayoutManager` uses the UiSkin key as the
      asset folder (no separate lookup), `Teardown` destroys the old clone
      — switching keys can never show another skin's GUI. `init.luau`
      passes through `Settings.UiSkin` (default `"Default"`). Proven by
      LocalScript skin-leak smoke tests.
- [x] Selection pop: `selecticon` equip feedback via Fusion tween (Back
      Out 0.18s + 0.06 delay, mount pop, instant off). Acyclic
      (`isEquipped` -> goal), zero detector errors.
- Accept: glow shows exactly until first equip; Modern backpack renders
  all skins' contracts unchanged.

## Phase 2 — Connection `[ ]`

- [ ] Slim snapshot on join (items + Hotbar/Storage + equipped + settings;
      indexes stay server-side), new `InventorySnapshot` remote, replaces
      `MockData` seed
- [ ] Server request router for all 12 ops; retire `Signals.luau` mock bus;
      optimistic apply + `InventoryRevert` rollback preserved
- [ ] Playtest matrix: Default + Metal, both solvers, rollback-under-lag
- Accept: cold join rebuilds identical UI from snapshot; failed ops roll
  back visibly; mock bus fully deleted.

## Phase 3 — World `[ ]`

- [ ] True Drop: X key + drag-outside → server `Drop` (world Tool from data
      snapshot, full/partial amounts, `Droppable=false` respected).
      Local `Remove` stays destroy-only.
- [ ] Pickup: prompt/touch → Tool attributes → `Add` (reverse of
      `applyToolAttributes`), fires `OnItemAdd`/`OnItemRemove` both ends
- Accept: drop equipped full stack moves the live Tool to the world;
  partial drop splits amounts correctly; pickup round-trips attributes.

## Phase 4 — Lock-in `[ ]`

- [ ] Studio specs: snapshot, seen, drop, pickup, hooks fire sites
- [ ] `docs/specs/NetworkProtocol.md` update (snapshot + Drop request)
- [ ] Final dual-solver gate + playtest sign-off both skins

---

## Decisions Log

- Per-skin look pattern (kept re-exports reason): shared loaders/views stay
  generic and consume OPTIONAL per-skin data; the skin module stamps it.
  Precedent: `Skins/Modern` sets `SkinHandle.HeaderColors` (saturated jewel
  tones: crimson/emerald/amber/royal/violet per category); `StorageView`
  falls back to category colors when absent, so Default/Metal render
  exactly as before. Keys route through the per-skin modules (not
  SkinLoader directly) so stamps actually run. Same shape planned for
  `HookPayloads` (per-skin hook args, generic bus untouched).
- Same pattern for layout data: `Skins/Modern` stamps
  `DesktopHotbarXScale = 0.52` (shared default 0.57); `HotbarView`
  consumes it as the taper endpoint with fallback. Mobile taper
  untouched. Skin owns the what (bias value), view owns the how
  (taper math) — skins never supply builder functions.
- Same pattern for glow data: `Skins/Metal` stamps
  `GlowSpread = UDim2.new(0.5, 0, 0.5, 0)` (shared default 0.05);
  `SlotView` forwards `props.GlowSpread` into the `NewGlow` UIShadow
  with fallback. All three stamps (`HeaderColors`,
  `DesktopHotbarXScale`, `GlowSpread`) ride the `SkinHandle` optional
  fields — views fall back, skins never branch shared code.
- Fusion oscillator rule (learned the hard way): an `Observer` must
  never write state upstream of what it observes. The `NewGlow`
  breathe ping-pong (`glowTweened` observer setting `glowProgress`)
  tripped Fusion 0.3's `infiniteLoop` detector on EVERY flip — a goal
  guard can't help, the detector fires on the first re-entrant set.
  Oscillators use TweenService `Completed` chains; Fusion `Tween` is
  for one-shots and followers (`selecticon` pop, fade-outs). Verified:
  zero `infiniteLoop` after revert.
- `NewGlow` parents to the CELL (`slotFrame`), not the button: opaque
  Default art occludes the halo (behind-glow), transparent
  Modern/Metal cells don't light up. Same instance, both correct.

- Sparse binds: missing index = renders + drags + taps, red `!` badge, no
  fire. `[9]` Display-only demo state is committed intentionally.
- Empty-slot bind deselects equipped (PC + console, shared `doEquipSlot`).
- Skin declarations live in Studio attributes on the `Slot` folder
  (`GhostHidden`/`HideInStorage`/`HideInHotbar`/`SlotBleedPx`); absent =
  legacy behavior. No hardcoded skin names in shared code.
- Flat skin tree: one ScreenGui per skin folder, shared `GUI/DraggingGui`.
  No spare ScreenGuis inside skin folders (loader fail-fasts).
- Hooks split: generic bus (stable minimal payloads, open subscription) +
  skin-direct calls (per-skin `HookPayloads` types, 3-touchpoint change
  protocol). `SeenIds` is client-session local.
- Ghost policy: clone live slot, strip `GhostHidden` list, descendants +100
  ZIndex (Global-behavior `DraggingGui`).

## Open Flags

- `Signals.luau` mock bus still live — Phase 2 retires it (optimistic
  apply + `InventoryRevert` rollback preserved).
- Shared `DraggingGui` is reparented (not cloned) into PlayerGui at load —
  fine solo, revisit for multiplayer.
- LocalScript smoke (`game.StarterPlayer.StarterPlayerScripts.LocalScript`,
  Studio-only) is unmanaged by Rojo: `Disabled` reverts on serve, can't
  edit in Play.
