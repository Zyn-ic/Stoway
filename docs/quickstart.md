# Quickstart

!!! tip "Ten minutes, three commands"
    Install tools → open the place → press Play.

After this page you can run the inventory and poke it from the console.

## Prerequisites

- Roblox Studio with the [Rojo plugin](https://rojo.space/)
- [Rokit](https://github.com/rojo-rbx/rokit), then `rokit install` in the repo
  (installs Rojo, Wally, and luau-lsp from `rokit.toml`)

## Run it

1. Open `stoway.rbxl`. Skin prefabs and Tool templates live in the place file,
   not the repo, so a bare `rojo build` has no GUI.
2. `rojo serve`, then **Connect** in the Rojo plugin.
3. Press **Play** (solo).
4. Press ++backquote++ to open the Conch console, then try `help` and `inv`.

## What you will actually see

Players get their defaults from `Shared/Stoway/Settings.luau`, not the engine:

| Setting | You get | Engine default |
|---|---|---|
| Layout / skin | `JailbreakHotbar` / `Jailbreak` | n/a |
| `HotbarType` | `Dynamic` | `Static` |
| `CanStack` | `false` | `true` |
| `BackpackEnabled` | `false` | `true` |

So: a hotbar row, no storage toggle, and no stacking. `addback` returns
`BACKPACK_DISABLED`. To explore storage, set `BackpackEnabled = true` in
`Settings.luau` (there is no console toggle yet) and try
`set-layout StandardHotbarStorage` + `set-skin Default`.

## Poke it

```text
add sword 2
addhot Pickaxe 1 3
swap Hotbar 1 Hotbar 3
set-hotbar-type Static
toggle-stack
```

Item ids are exact-match names of templates in `ServerStorage.Tools`.

Next: [Life of a swap](life-of-a-swap.md).
