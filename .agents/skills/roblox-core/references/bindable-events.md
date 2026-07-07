# Bindable Events

## Key Concepts

- `BindableEvent` and `BindableFunction` communicate only on the same side of the client-server boundary.
- `BindableEvent` is asynchronous and one-way.
- `BindableFunction` is synchronous and yields until `OnInvoke` returns.
- Tables passed through bindables are copied, not shared by identity.

## Rules

- Use bindables only for server-to-server or client-to-client script coordination.
- Prefer `BindableEvent` for notifications and `BindableFunction` only when synchronous return values are necessary.
- Do not rely on handler execution order when multiple functions connect to the same bindable event.
- Do not pass mixed tables with numeric and string keys through bindables.
- Avoid metatable-dependent table behavior across bindable calls; metatables are not preserved.

## Patterns

### Basic bindable event

```lua
local bindableEvent = Instance.new("BindableEvent")

bindableEvent.Event:Connect(function(message)
    print(message)
end)

bindableEvent:Fire("Round started")
```

### Basic bindable function

```lua
local bindableFunction = Instance.new("BindableFunction")

bindableFunction.OnInvoke = function(a, b)
    return a + b
end

print(bindableFunction:Invoke(2, 4))
```

### Module-owned bindable API

```lua
local RoundSignals = {}

local started = Instance.new("BindableEvent")
RoundSignals.Started = started.Event

function RoundSignals.fireStarted()
    started:Fire()
end

return RoundSignals
```

## Examples

### Same-side event coordination

```lua
local ServerScriptService = game:GetService("ServerScriptService")
local event = ServerScriptService:WaitForChild("RoundStarted")

event.Event:Connect(function()
    print("Update local server systems")
end)
```

### Avoid cross-boundary misuse

```lua
-- Bindables do not replace RemoteEvent or RemoteFunction.
-- Use them only when both scripts run on the same side.
```
