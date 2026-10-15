# Stoway
<img src="pics/testgif1.gif" alt="Stoway" width="240" align="left" style="margin-right:15px"/>

**An inventory you can trust, in layers you can swap.**
Pure-Luau CoreStore engine, server-authoritative orchestration, Fusion
client: drag an item and it moves instantly, because the server already
agreed. Use it as a base for RPG loadouts, survival backpacks, or
utility-heavy tool systems.

[Docs](https://zyn-ic.github.io/Stoway/) · [Releases](https://github.com/Zyn-ic/Stoway/releases)

<br clear="both"/>

## Features

### Hotbar

- Drag and drop between hotbar and storage, including sweep paint-to-move on the Jailbreak layout.
- Static slots or Dynamic packed display.
- Keybinds on PC, button combos on console, tap to equip on touch.

### Storage

- Items tracked as data (UUID-based), never live Tool instances.
- Stacking, limits, sorting, and grouping by item type.
- Optional backpack mode with its own popup.

### Systems

- Server-authoritative state with delta replication and FullSync correction.
- Per-team metadata, multi-skin UI, console and touch input.
- Debug console (Studio only) for inventory, settings, skins, and teams.

## Built around

| System | What | Read |
|---|---|---|
| **Categories** | Weapons, Consumables, Materials, Armor, Trinkets, Other: storage sections itself by item `Type` | [Metadata](https://zyn-ic.github.io/Stoway/metadata/) |
| **Rarities** | Common → Uncommon → Rare → Epic → Legendary → Mythic → Special, with rank sort and slot-frame tints | [Metadata](https://zyn-ic.github.io/Stoway/metadata/) |
| **Settings** | Hotbar type/slots, stacking + stack rules, backpack, limits (sparse-synced with a FullSync backstop) | [Settings](https://zyn-ic.github.io/Stoway/settings/) |
| **Sorting** | Storage auto-sorts by name, type, or rarity rank (descending), hotbar never touched | [Settings](https://zyn-ic.github.io/Stoway/settings/) |
| **Commands** | Conch debug console (Studio only): inventory ops, settings, skins, layouts, teams | [Debug Console](https://zyn-ic.github.io/Stoway/conch/) |

## Getting Started

1. Download the `.rbxm` (production = stripped, non-production = full) or the single playable `.rbxl` from [Releases](https://github.com/Zyn-ic/Stoway/releases).
2. Place server modules in `ServerScriptService`, client modules in `StarterPlayerScripts`, shared modules + `Packages` in `ReplicatedStorage`.
3. Boot the server:
   ```lua
   local Stoway = require(game.ServerScriptService.Services.StowayServerV3_0_0)
   local CoreStore = require(game.ReplicatedStorage.Shared.Stoway.CoreStore)
   Stoway.Init(CoreStore)
   ```
4. Press Play, open Conch (Backquote), try `help` then `inv`.

New here? [Quickstart](https://zyn-ic.github.io/Stoway/quickstart/) → [Life of a swap](https://zyn-ic.github.io/Stoway/life-of-a-swap/) → [Building on top](https://zyn-ic.github.io/Stoway/building-on-top/).

## Documentation

Full docs: [zyn-ic.github.io/Stoway](https://zyn-ic.github.io/Stoway/) (architecture, metadata, skins & layouts, wire reference, examples, API).

## Credits

1. [**HowToRoblox**](https://www.youtube.com/watch?v=kqa4u_9mSTQ&list=WL&index=6) - core backpack/hotbar mechanics lineage.
2. [**Knineteen19**](https://www.youtube.com/watch?v=d2tdaRmqGXI&list=WL&index=8) - inventory/hotbar, persistence, and stacking.
3. [**Avafe**](https://devforum.roblox.com/t/neohotbar-a-modern-customizable-backpack/2738850) - Fusion and reactive UI patterns.
4. [**Illusion**](https://devforum.roblox.com/t/illusions-inputactionsystem-currently-the-best-input-manager/4071242) - InputActionSystem module.
5. [**breadboardengineer1234**](https://github.com/breadboardengineer1234/QuickNet) - QuickNet networking.
