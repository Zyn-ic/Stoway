# Troubleshooting

| Symptom | Likely cause |
|---|---|
| Console does nothing | By design: Studio only |
| Client warns "skin has no Hotbar frame" / UI empty | Skin prefab missing from the place (a `rojo build` has none) |
| `ITEM_NOT_IN_TOOLS_FOLDER` | No template with that exact name in `ServerStorage.Tools` |
| `BACKPACK_DISABLED` | Default `BackpackEnabled = false` |
| Items won't merge into existing stacks | `CanStack` is false by default; also check `StackBlacklist`, `StackRequiredFields`, and that merges happen via `add` or swap with `StackOnSwap` (never move/split) |
| `add x 5` gives one x5 stack | Normal: `CanStack` blocks merges, not stack size. `MaxStackSize` caps the new stack. Set `MaxStackSize = 1` for separate x1 items. |
| `OPERATION_IN_PROGRESS` | Another op holds the per-player lock (3 s timeout) |
| `[QuickNet] unknown event id N, dropping calls` | A call raced registration; the FullSync backstop heals it |
| UUID commands (`remove`, `drop`, `split`, `equip`) fail with `ITEM_NOT_FOUND` | UUIDs contain dots; quote the whole UUID (copy the quoted form from `inv`) or use a slot command |
| New-solver type noise on `Value`/`Computed` | Add explicit `:: Fusion.Value<T>` / `:: Fusion.Computed<T>` |

Next: [Glossary](glossary.md).
