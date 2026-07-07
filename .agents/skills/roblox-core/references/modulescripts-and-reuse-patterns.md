# ModuleScripts And Reuse Patterns

## Key Concepts

- `ModuleScript` objects package reusable Luau code and are loaded with `require()`.
- A module runs once per Luau environment and returns a cached value for later requires in that same environment.
- The returned value is usually a table, function, or configuration object.
- Shared modules often live in `ReplicatedStorage`; server-only modules often live in `ServerScriptService` or `ServerStorage`.

## Rules

- Make modules return exactly one non-`nil` value.
- Require modules once per script and reuse the returned reference.
- Avoid circular requires.
- Put modules in replicated or server-only containers according to who needs them.
- Keep shared modules side-agnostic unless they intentionally target only the client or server.

## Patterns

### Basic module shape

```lua
local module = {}

function module.greet(name)
    return "Hello, " .. name
end

return module
```

### Shared configuration module

```lua
local RoundConfig = {
    LengthSeconds = 120,
    MaxPlayers = 8,
}

return RoundConfig
```

### Module-owned custom event

```lua
local Switch = {}

local changed = Instance.new("BindableEvent")
Switch.Changed = changed.Event

function Switch.flip(state)
    changed:Fire(state)
end

return Switch
```

## Examples

### Require a shared module on the client

```lua
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RoundConfig = require(ReplicatedStorage:WaitForChild("RoundConfig"))
print(RoundConfig.LengthSeconds)
```

### Require a server-only module

```lua
local ServerStorage = game:GetService("ServerStorage")

local EnemySpawner = require(ServerStorage:WaitForChild("EnemySpawner"))
EnemySpawner.start()
```
