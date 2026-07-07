# Enums Reference

## Key Concepts

- Enums are named families of preset constants used by Roblox APIs.
- Access enum items through `Enum.EnumName.ItemName`.
- `Enum` is exposed through a Roblox global, while the underlying datatype system also includes `Enums`, `Enum`, and `EnumItem`.
- Enum values should usually be passed as named items, not as raw integers.

## Rules

- Match the exact enum family required by the property or parameter type.
- Use the named enum item instead of guessing the backing numeric value.
- Confirm spelling and capitalization exactly.
- When an API says a property type is an enum family such as `RaycastFilterType`, use `Enum.RaycastFilterType.<Item>`.
- Use enum helpers only when needed:
  - `Enum:GetEnumItems()` to inspect all items in a family.
  - `Enum:FromName()` or `Enum:FromValue()` when converting dynamically.

## Patterns

### Common enum usage

- Filtering choice: `Enum.RaycastFilterType.Exclude`
- Camera mode: `Enum.CameraType.Scriptable`
- Easing style: `Enum.EasingStyle.Quad`
- Easing direction: `Enum.EasingDirection.Out`

### Connect enum lookup to API types

- If a property type is an enum family, pick an item from that family only.
- If a datatype property points to an enum family, validate both the datatype and the enum item.
- If a constructor or method accepts multiple enum parameters, confirm each family independently.

## Examples

```lua
params.FilterType = Enum.RaycastFilterType.Exclude
camera.CameraType = Enum.CameraType.Scriptable
local info = TweenInfo.new(0.25, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
```

- `Enum.RaycastFilterType.Exclude` is an enum item used by `RaycastParams.FilterType`.
- `Enum.CameraType.Scriptable` is an enum item used by `Camera.CameraType`.
- `TweenInfo.new()` commonly combines more than one enum family.
