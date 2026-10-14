# Example: Locked Slots

`example/locked-slots` — metadata-keyed hotbar slot unlocks through USE, not
possession.

A token carries `UnlocksHotbarSlot = N`; equipping it and clicking consumes
one unit, flips slot N out of `Settings.LockedHotbarSlots`, and FullSync
teaches the client permanently. Merely holding the token unlocks nothing.

```mermaid
flowchart TD
    A[Token metadata: UnlocksHotbarSlot = N] --> B[Equip token + click]
    B --> C{Slot N locked?}
    C -->|No| D[Nothing consumed]
    C -->|Yes| E[Consume 1 unit + flip the lock]
    E --> F[FullSync teaches the client]
```

Locks live in Settings with a server placement guard and a client visibility
guard sharing one pure rule (`SlotLocks.isUnlocked`). Check-consume-flip is
atomic per tick, so double-clicks can't double-consume.

Try it (chat commands on this branch): `/addhot PouchToken`, equip, click →
slot 9 unlocks. `/locks` shows verdicts, `/relock` re-locks. Full write-up in
the branch's [`AGENTS.md`](https://github.com/Zyn-ic/Stoway/blob/example/locked-slots/AGENTS.md)
showcase section.
