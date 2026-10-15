# Troubleshooting

| Symptom | Likely cause |
|---|---|
| Console does nothing | By design: Studio only |
| Client warns "skin has no Hotbar frame" / UI empty | Skin prefab missing from the place (a `rojo build` has none) |
| `ITEM_NOT_IN_TOOLS_FOLDER` | No template with that exact name in `ServerStorage.Tools` |
| `BACKPACK_DISABLED` | Default `BackpackEnabled = false` |
| Items won't stack | `CanStack` is false by default; also check `StackBlacklist`, `StackRequiredFields`, and that merges happen via `add` or swap with `StackOnSwap` (never move/split) |
| `OPERATION_IN_PROGRESS` | Another op holds the per-player lock (3 s timeout) |
| `[QuickNet] unknown event id N, dropping calls` | A call raced registration; the FullSync backstop heals it |
| `equip "uuid"` fails in console | UUIDs contain dots; quote them or use `equip-slot` |
| New-solver type noise on `Value`/`Computed` | Add explicit `:: Fusion.Value<T>` / `:: Fusion.Computed<T>` |

Next: [Glossary](glossary.md).
