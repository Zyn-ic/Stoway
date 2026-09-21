# Settings Sync

How per-player engine settings (`MaxHotbarSlots`, `HotbarType`, `Sorting`, …)
travel server → client, and when to send what.

## Rules

1. **One remote, sparse payloads.** `SettingsChanged` carries ONLY the fields
   that changed (all-optional schema). Each mutation site fires its own
   literal, so intent is visible exactly where state changes. No remote zoo.
2. **Structural vs cosmetic.** A stale *structural* field forks state
   (optimistic ops apply under the wrong rules with no rollback); a stale
   *cosmetic* field only misrenders until the next update:

   | Setting | Kind | If stale/dropped |
   |---|---|---|
   | HotbarType, MaxHotbarSlots | Structural | Positional divergence (holes vs packed, phantom slots) |
   | CanStack, MaxStackSize, StackOnSwap, StackRequiredFields, StackBlacklist | Structural | Stacking rules differ per side |
   | Limit, BackpackEnabled, DefaultDroppable | Structural-lite | Capacity/gating checks differ |
   | Sorting, SortOrder | Cosmetic | Display order only, no state fork |

3. **Convergence backstop.** `FullSync` carries the full settings snapshot, so
   a dropped partial heals on the next op-driven resync. Sparse sends give
   immediacy; the snapshot gives convergence. Never rely on partials alone.
4. **Single atomic apply.** The client overlays present fields onto `_state`
   first, then one `sync()` fans out to atoms (`SetEngineSettings`). Later
   ops re-apply the same values instead of clobbering atoms with the boot
   snapshot. Unknown keys are ignored by construction.

## QuickNet findings (observed, not theorized)

- All traffic multiplexes through shared remotes with numeric event ids.
  The client logs `[QuickNet] unknown event id 7, dropping calls`: calls
  whose id isn't recognized are **dropped, not queued**. Any protocol that
  assumes delivery (like sparse partials) needs a convergence story — rule 3.
- Schemas are strict and stateful: table-nesting `optional()` wrappers mutate
  in place, so schema tables must be inline-fresh and registered exactly once
  (the single-use rule). Bare-enum optionals are safe to share.
- The wire is one static dict per event (`FireServer(a, b)` misaligns —
  proven live). Every payload is one named table.
- Serialization erases type nominals: schema types and domain types share
  shapes but not identities, hence the single `any` seam at the boundary
  with explicit annotations at call sites.

## If you use regular remotes instead

With plain `RemoteEvent`s (reliable, ordered, schemaless), drops are not a
factor — so the backstop matters less and sparse singles are beneficial
**mainly for intent clarity**: each mutation sends exactly what it changed,
nothing is over-sent, and readers see the contract per call site. Keep the
defensive habits anyway: `typeof` checks on receipt, unknown-key tolerance
on apply, atomic apply-then-fanout.
