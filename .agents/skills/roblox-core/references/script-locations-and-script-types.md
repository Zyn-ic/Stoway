# Script Locations And Script Types

## Key Concepts

- Roblox has three script types: `Script`, `LocalScript`, and `ModuleScript`.
- `Script` behavior depends on container placement and `RunContext`.
- `LocalScript` runs only on the client.
- `ModuleScript` is reusable code loaded with `require()`.
- Location in the data model determines what replicates and what can run.

## Rules

- Use `ServerScriptService` for server-only scripts and modules.
- Use `ServerStorage` for server-only assets or modules that do not need to replicate.
- Use `ReplicatedStorage` for shared modules and replicated assets.
- Use `ReplicatedFirst` only for earliest client initialization.
- Use `StarterPlayerScripts`, `StarterCharacterScripts`, `StarterGui`, and `StarterPack` for client behavior that is copied into each player.
- Prefer explicit `RunContext` when you need a `Script` to behave predictably outside legacy server-only placement.

## Patterns

### Choose script type by job

- `Script`: server logic or explicit run-context logic.
- `LocalScript`: player-local behavior.
- `ModuleScript`: reusable functions, constants, configuration, or abstractions.

### Shared module placement

```lua
-- ReplicatedStorage/Shared/InventoryConfig
local InventoryConfig = {
    MaxSlots = 20,
}

return InventoryConfig
```

### Safe client containers

- `StarterPlayerScripts` for general client controllers.
- `StarterCharacterScripts` for behavior attached to each spawned character.
- `StarterGui` for client UI scripts.
- `ReplicatedFirst` for minimal early-loading client work.

## Examples

### Server script placement

```lua
-- Script in ServerScriptService
print("Runs on the server")
```

### Client script placement

```lua
-- LocalScript in StarterPlayerScripts
print("Runs on the client")
```

### Module placement

```lua
-- ModuleScript in ReplicatedStorage
return {
    DisplayName = "Arena",
}
```
