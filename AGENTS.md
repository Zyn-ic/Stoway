# AGENTS.md

This file helps AI agents understand the Stoway project. Read this before making changes.

---

## Project Overview

Stoway is a Roblox inventory framework. The core is a pure Luau inventory engine called `CoreStore` — no Roblox types, no UI, no networking. It lives inside an orchestration layer called `StowayServerV3_0_0` that connects it to Roblox-specific systems.

**CoreStore lives at:** `src/server/Services/StowayServerV3_0_0/CoreStore/`

**Orchestration layer:** `src/server/Services/StowayServerV3_0_0/init.luau`

**Communications adapter:** `src/server/Services/StowayServerV3_0_0/Communications.luau`

**Old server code:** `src/server/StowayServerV1_2/` (legacy reference, may be deleted)

---

## Running Tests

Run from the repo root with Lune (supports `.luaurc` aliases; no luau.exe installed on this machine):

```
C:\Users\yum\.bin\lune.exe run "C:\Users\yum\Documents\Stoway\src\server\tests\corestore_operations_test.luau"
```

### Suites and expected results

| Suite | Command suffix | Expected |
|-------|---------------|----------|
| CoreStore operations (swap/swapStack/move/split/metadata/sort/index/equip/dynamic) | `corestore_operations_test.luau` | 66 passed, 0 failed |
| Stoway orchestration | `stoway_server_test.luau` | 21 passed, 0 failed |
| Add tests | `corestore_addtest.luau` | 25 passed, 0 failed |
| Metadata REPL | `corestore_metadata_test.luau` | 12 passed, 0 failed |

### Replication default

`replicate` is opt-in on every Stoway operation route: `nil` (omitted) means **no** replication; pass `true` to echo a server-side change to a client. Passing `false` is equivalent to omitting it.

### Web Test Tool

Open `src/server/tests/web/index.html` in a browser. No build step, no server needed. This is a full JS port of CoreStore.

---

## Require System

All modules use `.luaurc` aliases instead of relative paths. This works in both Luau CLI and luau-lsp.

**Root `.luaurc`:**

```json
{
  "aliases": {
    "CoreStore": "./src/server/Services/StowayServerV3_0_0/CoreStore",
    "Stoway": "./src/server/Services/StowayServerV3_0_0"
  }
}
```

**Usage in modules:**

```luau
local Types = require("@CoreStore/Types")
local Operations = require("@CoreStore/Operations")
```

**Usage in test files:**

```luau
local CoreStore = require("@CoreStore")
local Stoway = require("@Stoway")
```

**Do NOT use:**
- Relative paths like `require("../CoreStore/Types")` — break in luau-lsp Roblox mode
- Bare names like `require("CoreStore")` — Luau CLI requires `@` prefix for aliases
- Roblox-style paths like `require(game.ReplicatedStorage.CoreStore.Types)`

---

## Code Style

### ModuleScript Template (use `@` prefix in VS Code)

```luau
--@author: yyumchi
--@date: 2026-06-24
--[[@description:
	Short description here.
]]
-----------------------------
-- VARIABLES --
-----------------------------

local ModuleName = {}

-- CONSTANTS --
-----------------------------
-- PRIVATE FUNCTIONS --
-----------------------------
-- PUBLIC FUNCTIONS --
-----------------------------
--MAIN--
-----------------------------

return ModuleName
```

### Rules

- **Author:** Always `yyumchi`
- **Section separators:** ALL CAPS with dashes: `-- VARIABLES --`, `-- CONSTANTS --`, `-- PRIVATE FUNCTIONS --`, `-- PUBLIC FUNCTIONS --`
- **No emojis** in terminal output except test pass/fail visual output
- **No OOP:** No `:Init()` / `:Start()` in CoreStore modules. Use functional style.
- **No Roblox types:** CoreStore uses `@` aliases, not Roblox Instance paths

---

## Module Map

### StowayServerV3_0_0 (Orchestration Layer)

| File | Purpose | Public API |
|------|---------|-----------|
| `init.luau` | Orchestration facade | Init, createPlayer, get, removePlayer, getAll, registerAdapter, 12 operation routes |
| `Communications.luau` | Network adapter + gatekeeper | Init(Stoway, NetworkService, folder), QuickNet handlers, validation, replicate decisions, Stoway adapter |

### StowayClient (Client Layer)

| File | Purpose | Public API |
|------|---------|-----------|
| `init.luau` | Client entry point | Local cache, event listeners, optimistic updates, UI signals |

### CoreStore (Pure Luau Engine)

| File | Purpose | Public API |
|------|---------|-----------|
| `Types.luau` | Pure type exports (no runtime) | Types only |
| `Utils.luau` | deepCopy, shallowCopy, generateUUID, isPositiveNumber, clampAmount | Utility functions |
| `State.luau` | State creation, weight tracking, capacity checks | new, addWeight, removeWeight, getRemainingCapacity, isEquipped, isFull, hasHotbarSpace |
| `Metadata.luau` | normalize input, matchesRequiredFields, isBlacklisted | normalize, matchesRequiredFields, isBlacklisted |
| `Stack.luau` | canStack, tryStack logic | canStack, tryStack |
| `Slots.luau` | Hotbar/storage slot operations, compaction, sorting | setHotbarSlot, clearHotbarSlot, findEmptyHotbarSlot, compactHotbar, swapSlots, moveWithinStorage, moveToStorage, sortStorage, sortHotbar, getUUIDFromSlot, getHotbarItemCount, getStorageItemCount, validation helpers |
| `Operations.luau` | Core mutation logic | add, remove, removeBySlot, swap, swapStack, move, split, updateMetadata, sort, equip, unequip |
| `Query.luau` | Item lookups | getItem, find, findById, filter, getAllItems |
| `init.luau` | Public API facade | CoreStore.* (27 public functions) |

### Data Flow

```
User -> init.luau (facade) -> Operations.luau -> Slots/Stack/State/Query
```

### Key State Shape

```luau
InventoryState = {
    Items: { [string]: Item },           -- O(1): UUID -> Item
    ItemsByID: { [string]: { string } }, -- O(1): ItemId -> UUIDs
    Hotbar: { string? },                 -- 1..MaxHotbarSlots, Static has holes
    Storage: { string },                 -- packed array, no holes
    LocationByUUID: { [string]: SlotRef }, -- O(1): UUID -> where
    MetadataIndex: { [string]: { [string]: { string } } }, -- O(1): field -> value -> UUIDs
    EquippedItemUUID: string?,
    Weight: number,
    Settings: Settings,
}
```

### Settings Defaults

```luau
HotbarType = "Static"     -- or "Dynamic"
MaxHotbarSlots = 10
Limit = 15                -- 0 = infinite
CanStack = true
MaxStackSize = 5
BackpackEnabled = true
StackOnSwap = false       -- system-level, default off
Sorting = false
SortOrder = "None"        -- "None" | "Name" | "Rarity" | "ItemType"
StackRequiredFields = { "Rarity", "Type" }
StackBlacklist = { Legendary = true, Mythic = true, Special = true }
```

### Operations Summary

| Operation | What it does | Complexity |
|-----------|-------------|------------|
| add | Add item(s), stack into existing or create new | O(k) stack, O(1) new |
| remove | Partial or full removal | O(1) partial, O(h)/O(n) full |
| swap | Exchange two slot positions. StackOnSwap can absorb | O(1) same-container, O(n) cross-container |
| swapStack | Explicit stack route; follows swap's StackOnSwap behavior | Same as swap |
| move | Positional transfer, never stacks | O(1) HH, O(h) HS, O(n) SH/SS |
| split | Divide stack, cap at MaxStackSize | O(1) + placement |
| updateMetadata | Merge key-value pairs, all mutable | O(f) |
| sort | Auto-triggered, sorts Storage only | O(n log n) |

### Key Behaviors

- **Stacking:** Only via `add` (always), `swap`, or `swapStack` when `StackOnSwap = true`. Move and split never stack.
- **MaxStackSize:** Enforced unconditionally. No item Amount may exceed it after any operation.
- **Dynamic hotbar:** Compacts after remove/swap/move. Static preserves holes. Use `CoreStore.setHotbarType(state, "Dynamic")` to switch types — it auto-compacts.
- **Auto-sort:** Triggers after any mutating operation when `Sorting = true`. Sorts Storage only. Hotbar is never sorted (user-controlled).
- **MetadataIndex:** Indexed fields: Rarity, Type. O(1) bucket lookups for find().

---

## Test Structure

### corestore_operations_test.luau (66 tests)

Tests for: swap, swapStack, move, split, metadata, sort, MetadataIndex, equip/unequip, dynamic hotbar. Visual pass/fail output.

### stoway_server_test.luau (21 tests)

Tests for: Stoway orchestration layer — player lifecycle, operation routing, adapter dispatch, concurrent operation blocking.

### corestore_addtest.luau (25 tests)

Tests for: add operations, stacking, overflow, capacity, weight, placement modes, blacklisting. 20 pass + 5 deliberate failures.

### manual_test.luau

Lune REPL for interactive testing. Load modules, save/load JSON state.

### Web Test Tool (12 scenarios)

Fill Hotbar, Stack Test, Overflow, Capacity, Blacklist, Swap, Move, Split, Sort by Rarity, Multi-Player, Dynamic Hotbar, Weight Tracking.

---

## Documentation Structure

```
docs/
  specs/
    CoreStoreSpecification.md   -- Full audit, InventoryState shape, complexity targets
    Invariants.md               -- 18 guarantees (INV-1 to INV-18) + verifyInvariants()
    SwapRules.md                -- 4 combos, StackOnSwap, equipped behavior
    MoveRules.md                -- Purely positional, never stacks
    SplitRules.md               -- Placement chain, MaxStackSize cap
    SortingRules.md             -- Auto-trigger model, sort criteria, descending rarity
    MetadataUpdateRules.md      -- All mutable, no auto re-stack
    NetworkProtocol.md          -- QuickNet event names, payloads, validation rules
    ReplicationRules.md         -- Origin tracking, replicate decision, rollback format
  site/                         -- Documentation website (vanilla HTML/CSS/JS)
```

---

## Common Pitfalls

1. **`setupDragHandlers()` must run once on init** — not inside `renderInventory()`. The web test tool's drag/drop uses document-level event delegation.
2. **`table.clone` not `Utils.deepCopy`** for flat settings tables — `deepCopy` is for nested item metadata.
3. **`split` always caps at MaxStackSize** regardless of CanStack — this is intentional.
4. **Move never stacks** — use `swap` or `swapStack` with `StackOnSwap = true` if you want to merge.
5. **Static hotbar preserves holes** — `compactHotbar` is a no-op. Only Dynamic compacts.
6. **Sort is descending for rarity** — Special > Mythic > Legendary > ... > Common.
7. **`StackOnSwap` does NOT stack during move** — it applies to swap and swapStack only. This is a common misconception.
8. **Nil values in `updateMetadata`** — In Luau, `{ Key = nil }` creates empty table. Nil values are silently ignored.
9. **MetadataIndex maintenance** — every `createItem`, `destroyUnplacedItem`, `remove`, and `updateMetadata` must update MetadataIndex.
10. **Dynamic Hotbar slot availability** — The only available slot is the append position (`findEmptyHotbarSlot`). Operations targeting non-append slots are rejected with `DESTINATION_UNAVAILABLE`. Preferred slot is ignored in Dynamic mode. Use `CoreStore.setHotbarType(state, "Dynamic")` to switch types — it auto-compacts the hotbar.
