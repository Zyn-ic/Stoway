# Dependencies & Credits

## Runtime (vendored under `ReplicatedStorage/Packages`)

| Package | Version | Use |
|---|---|---|
| QuickNet | vendored (version unpinned) | Client/server wire (buffer-serialized remotes) |
| Fusion 0.3 (`isRelease=true`) | `acecateer/fusion@0.3.1` | Reactive client UI |
| Conch | vendored (version unpinned) | Studio debug console |
| SignalPlus | vendored single module | UI event bus |
| IllusionIAS | vendored (version unpinned) | Input Action System bindings |
| Janitor | `howmanysmall/janitor@1.18.3` | Cleanup scoping |

`wally.toml` pins versions for reference; the vendored copies under
`ReplicatedStorage/Packages/` are canonical — do not reinstall over them.

## Credits

- **HowToRoblox** — core backpack/hotbar mechanics lineage
- **Knineteen19** — inventory/hotbar, persistence, stacking series
- **Avafe** — Fusion and reactive UI patterns
- **Illusion** — InputActionSystem module
- **breadboardengineer1234** — [QuickNet](https://github.com/breadboardengineer1234/QuickNet)
