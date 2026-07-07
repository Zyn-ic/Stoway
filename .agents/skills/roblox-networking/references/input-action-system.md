# Input Action System

## Key Concepts

- The Input Action System maps gameplay actions to device-specific bindings.
- Actions are a better network contract than raw hardware events.
- In authoritative gameplay, core simulation should consume action data rather than ad hoc local input events.
- Contexts let the same experience switch input sets safely across gameplay states.

## Rules

- Use action-oriented inputs for gameplay that must work across keyboard, gamepad, and touch.
- For authoritative simulation, prefer action data over direct `UserInputService.InputBegan` handling.
- Place `InputContext` objects where the owning player can use them correctly.
- Keep core simulation inputs distinct from local-only UI or camera controls.
- If writing custom input-derived data into authoritative systems, keep that write path outside the simulation callback when required by the engine model.

## Patterns

### Define gameplay actions

- `Jump`
- `Sprint`
- `Shoot`
- `Throttle`
- `LookDirection`

### Bind multiple devices to one action

```lua
local inputAction = script.Parent

inputAction.Pressed:Connect(function()
    print("Action pressed")
end)
```

- One action can represent a keyboard key, gamepad button, or touch button.
- Network code can reason about the action instead of platform-specific hardware.

### Separate action classes

- Core simulation actions: movement, jump, fire, drive, interact.
- Local presentation actions: camera-only or UI-only behaviors that do not change authoritative state.

## Examples

### Authoritative-friendly design

- Client records "sprint pressed" as an action.
- Server or shared simulation code decides whether sprint is allowed based on stamina and state.

### Avoid for core authority

```lua
UserInputService.InputBegan:Connect(function(input)
    -- Do not use raw device events as the primary authoritative input contract.
end)
```
