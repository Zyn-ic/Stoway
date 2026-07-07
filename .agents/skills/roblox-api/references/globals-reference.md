# Globals Reference

## Key Concepts

- Roblox scripts expose both Luau globals and Roblox-specific globals.
- Luau globals include core functions such as `assert`, `error`, `ipairs`, `pairs`, `pcall`, `type`, and shared tables like `_G`.
- Roblox globals include engine-specific names such as `game`, `workspace`, `script`, `shared`, `plugin`, and `Enum`.
- Some older Roblox globals are deprecated in favor of modern library APIs.

## Rules

- Confirm that the symbol is truly global before using it without qualification.
- Prefer Roblox globals for canonical engine entry points:
  - `game` for the `DataModel`
  - `workspace` for the `Workspace` service
  - `script` for the currently running source container
  - `Enum` for enum families
- Treat `plugin` as context-specific; it exists only in Studio plugin execution.
- Prefer `task.wait()` and `task.delay()` over deprecated global `wait()` and `delay()`.
- Keep global lookup referential; do not turn `_G` or `shared` into broader architecture guidance.

## Patterns

### Common Roblox globals

- `game:GetService("Players")`
- `workspace.CurrentCamera`
- `script.Parent`
- `Enum.RaycastFilterType.Exclude`

### Luau global utility

- `assert(condition, message)` for invariant checks
- `pcall(fn)` for protected calls
- `type(value)` or `typeof(value)` when validating values in Roblox code

### Context-sensitive global

- `plugin` should be used only when code is executing as a Studio plugin.

## Examples

```lua
local Players = game:GetService("Players")
local camera = workspace.CurrentCamera

assert(camera ~= nil, "Expected a current camera")
task.wait()
```

- `game` and `workspace` are Roblox globals.
- `assert` is a Luau global.
- `task.wait()` is preferred over deprecated global `wait()`.
