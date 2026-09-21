# Branch plan (updated 2026-09-20)

Goal: a bare-bones canon client, plus small example branches off it that
show off what the bare bones make possible.

- `client` (canon): minimal client. Owns the ghost-heal fix (`61abd94`)
  and the settings-sync work (sparse `SettingsChanged` + `FullSync`
  backstop, in progress).
- `example/locked-slots`: locked-slots demo ONLY, eventually. It currently
  also contains `c883754` (the same ghost heal, now canon as `61abd94`) —
  strip it from this branch later. Do not strip yet.

## Sequence (in order, do not skip)

1. Sparse settings batch (this batch, uncommitted): `SettingsChanged`
   all-optional, per-site sparse sends, client patch applier.
2. **Next prompt**: `FullSync` settings snapshot (convergence backstop),
   then **commit**.
3. Strip the NewItem example (glow lifecycle in `SlotView`, `/addnew`,
   `MarkNew` hook, mock/spec `IsNew` seeds — exact inventory TBD at strip
   time) into a new example branch. Canon keeps none of it.
4. Proper client test suite: no direct table access exists outside signals —
   only bus events plus GUI visuals, which can't be trusted for core-functional
   verification. Suite must work through those channels (bus-observer asserts
   à la `LockedSlotsVerify`, GUI assertions, enable/disable per playtest),
   with explicit PASS/FAIL output. Design TBD at that step.
