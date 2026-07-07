# Classes Reference

## Key Concepts

- Classes are engine objects and services exposed by Roblox.
- Class members fall into four main kinds: properties, methods, events, and callbacks.
- Service classes are commonly acquired with `game:GetService("ServiceName")`.
- Docs often express class references as `Class.Name` and member references as `Class.Name.Member`.
- API lookup for classes is about finding the owner of a capability and then confirming the exact member contract.

## Rules

- Identify the owning class before choosing a member.
- Distinguish service access from instance access:
  - Services come from `game:GetService()`.
  - Child instances come from hierarchy references such as `workspace.Part`.
- Confirm whether a member is read or write state, an action, an event signal, or a callback hook.
- Do not turn class lookup into architecture advice about where scripts belong or which side should own the system.
- If the target class belongs to networking, persistence, or cloud workflows as the main topic, hand off to the corresponding skill instead of expanding it here.

## Patterns

### Find the right owner

- World and spatial queries usually point to `Workspace` or `WorldRoot` behavior.
- Player lifecycle and player containers usually point to `Players` or `Player`.
- Animation and tween creation usually point to `TweenService`.
- Frame-step and runtime loop hooks usually point to `RunService`.
- Collision-group operations usually point to `PhysicsService`.

### Confirm member kind before use

- Property: read or assign state, such as `Camera.CameraType`.
- Method: call an action, such as `Workspace:Raycast()`.
- Event: connect to a signal, such as `Players.PlayerAdded`.
- Callback: assign a handler when the API exposes a callback member instead of an event.

### Read signatures literally

- Methods need exact parameter order and types.
- Properties need exact value type, often a datatype or enum item.
- Events and callbacks need the correct handler argument list.

## Examples

### Spatial query

```lua
local Workspace = game:GetService("Workspace")
local result = Workspace:Raycast(origin, direction, params)
```

- Owning class: `Workspace`
- Member kind: method
- Related datatype: `RaycastParams`

### Player lifecycle

```lua
local Players = game:GetService("Players")

Players.PlayerAdded:Connect(function(player)
  print(player.Name)
end)
```

- Owning class: `Players`
- Member kind: event

### Tween creation

```lua
local TweenService = game:GetService("TweenService")
local tween = TweenService:Create(part, tweenInfo, {Transparency = 1})
```

- Owning class: `TweenService`
- Member kind: method
- Related datatype: `TweenInfo`
