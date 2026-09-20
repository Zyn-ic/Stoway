# Branch plan (note 2026-09-20, do not action yet)

Goal: a bare-bones canon client, plus small example branches off it that
show off what the bare bones make possible.

- `client-v3-sonnet` (canon): minimal client. Owns the ghost-heal fix
  (`61abd94` — ApplyServerAdded ghost healing, loud remove failures).
- `example/locked-slots`: locked-slots demo ONLY, eventually. It currently
  also contains `c883754` (the same ghost heal, cherry-picked to canon as
  `61abd94`). Strip `c883754` from `example/locked-slots` in the future so
  the branch shows just the example — NOT now.
