# Testing Rules

How Stoway is tested, now that all legacy suites are purged. Two phases:
human-judged data output first, automated shape asserts later.

## Rules

1. **Observer-only tests.** A test subscribes to the bus and reads state; it
   never mutates inventory, never fires operations, never requires (and is
   never required by) production code. One-directional dependency, always.
2. **Direct store peeks over GUI scraping.** In-game `require` reaches the
   same module instances the game runs on (proven: the late
   `LockedSlotsVerify` printed live token metadata + verdicts). The
   no-table-access limit applies to out-of-game tooling, not to in-game
   scripts. GUI can't be trusted for core-functional verification — a
   correct state can render wrong and vice versa. Read atoms
   (`ClientStore`), mirror state (`ClientController.GetState()`), and bus
   events; read GUI only when the screen itself is the spec (keybind labels).
3. **Structured output.** Every line is prefixed `[TestName]` with `key=value`
   pairs. A human (Phase 1) or an assert (Phase 2) judges from Output.
4. **Self-disabling.** Each test disables itself after running
   (`script.Disabled = true`, session-only, file untouched). File present =
   runs once per play; toggle `Disabled` in Explorer pre-play to skip.
5. **No canon requires.** Tests live outside the runtime path. Production
   must boot and run identically with every test file deleted.

## Phase 1 — data-output tests (now)

One LocalScript per area. On boot it takes a baseline read; on every
relevant bus event it prints the delta. A human evaluates pass/fail.

First batch, mapped to proven pain:

| Test | Watches | Guards against |
|---|---|---|
| `SettingsVerify` | `SettingsChanged` applies; atoms-vs-`_state` parity per push | Sync-clobber (stale snapshot overwriting pushed settings) |
| `InventoryVerify` | Orphan/ghost scan (slot→uuid with no item entry) on add/remove/FullSync | "Other"-category orphans, silent divergence |
| `DragVerify` | Before/after slot dumps on drag start/end + swap results | Drop-router misses, unreverted optimistic forks |

Later: binds, backpack toggle, equip paths. Server side mirrors the pattern
(it has direct state access): chat-command-driven dumps, same print
convention.

## Phase 2 — automated shape asserts (later)

Same files plus inline `expect`-style asserts that error on mismatch, so
Output reads PASS/FAIL with no human in the loop. Keep the Phase 1 print
lines (asserts annotate, never replace, the data).
