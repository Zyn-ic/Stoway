# StowayClientV3 (branch: `client-v3-sonnet`)

Core-phase Fusion client: settings-driven Standard Hotbar + sectioned,
collapsible Storage, running off mock data with no server round trip yet.

## Scope of this pass

In, per the master plan (Phases 1, 3, and the render half of 4):

- Pure client-side CoreStore (Types/State/Query) mirroring the server's
  CoreStore philosophy — no Fusion, no Instances, fully testable in
  isolation.
- Fusion `RootScope` + reactive atoms (`Controller/ClientStore.luau`).
- `HotbarType` vs `UiSkin` separation (section 1 of the plan) via
  `Controller/LayoutManager.luau`, `Layouts/`, and `Skins/` — a real
  seam, not just a comment, so Carousel/Utility Belt land later without
  touching CoreStore, Controller, or `init.luau`.
- Static/Dynamic hotbar packing, sectioned storage grouped by
  `Metadata.Type` with collapsible headers driven by `Settings.Categories`.
- Grouping is presentation-only: `Storage` stays a flat, order-preserving
  array; collapsing a header hides slot frames, it never sorts, filters, or
  otherwise mutates the underlying data.

Deliberately out, saved for later phases:

- Dragging, `PointerDragService`, `GamepadNavigator`, `InputDirector`,
  `CameraController` (Phase 2 — Interactions).
- `HookFuncs`/`DefaultHooks` (the GUI already has a `HookFuncs` folder;
  not wired up yet).
- `NetworkReceiver` / `ClientInventoryController` — the client boots
  entirely from `Mock/MockData.luau`. Swapping in a real server snapshot
  is a one-line change in `init.luau` (`ClientStore.Init(snapshot)` takes
  the same `InventoryState` shape either way).
- `SearchFilter`, `DropMenu`, `SelectionCursor` — present in the GUI
  prefab, not hydrated yet.

## Layout

```
StowayClientV3/
├── CoreStore/          Pure state & query logic (Layer 1, no Fusion/Instances)
│   ├── Types.luau         Re-exports ReplicatedStorage.Shared.Stoway.Types
│   │                       + client-only shapes (SkinHandle, GroupedStorage)
│   ├── State.luau         Settings-derived defaults, slot-index builders
│   └── Query.luau         getItem, findSlotByUUID, packedHotbarOrder,
│                           groupStorageByType, orderedGroupKeys, ...
├── Controller/          Orchestration (Layer 2)
│   ├── ClientStore.luau    Fusion RootScope + atoms, wraps Query for reads
│   └── LayoutManager.luau  Mounts a Layouts[] engine against a Skins[]
│                            loader; owns LayoutScope, tears it down on swap
├── Layouts/              HotbarType layout engines (Layer 4)
│   └── StandardHotbarStorage/
│       ├── init.luau        Mount(scope, skin, store) contract
│       ├── HotbarView.luau
│       └── StorageView.luau
├── Skins/                UiSkin prefab loaders (Layer 4)
│   └── DefaultModern/
│       └── init.luau        Resolves ReplicatedStorage.Stoway.GUI.<name>
├── Slot/
│   └── SlotView.luau       Shared slot hydrator, reused by every layout
├── Mock/
│   └── MockData.luau       Seeded InventoryState snapshot
└── init.luau              Boots ClientStore + LayoutManager
```

## Extending to Carousel / Utility Belt

1. Add `Layouts/CarouselHotbar/init.luau` (or `UtilityBelt/`) exposing
   `Mount(scope, skin, store)`. Reuse `Slot/SlotView.luau` as-is.
2. Add its matching `Skins/<Name>/init.luau`, resolving whatever GUI prefab
   folder that layout expects under `ReplicatedStorage.Stoway.GUI`.
3. Register both in `Controller/LayoutManager.luau`'s `Layouts`/`Skins`
   tables.
4. Call `LayoutManager.SetLayout(..., "CarouselHotbar", "<SkinName>")`
   instead — `CoreStore`, `ClientStore`, and `init.luau` don't change.

## GUI prefab contract (DefaultModern / `ReplicatedStorage.Stoway.GUI.Default`)

Verified live in Studio (`ReplicatedStorage.Stoway.GUI.Default`):

```
StowayGui (Folder)
  Stoway (ScreenGui)          -> cloned into PlayerGui
    Hotbar (Frame)
    Backpack (Frame)
      ScrollingFrame
      Weight (TextLabel)
      SearchFilter (TextBox)   -- not hydrated yet
    BackpackStuff (ImageButton) -- not hydrated yet
  Slot (Folder)
    template (Frame)           -> slotbutton, stackcount, slotnumber,
                                   selecticon, rarityframe
    SelectionCursor (Frame)     -- not used yet (Phase 2)
    DropMenu (Frame)            -- not used yet (Phase 2)
  HookFuncs (Folder)            -- not wired up yet
```
