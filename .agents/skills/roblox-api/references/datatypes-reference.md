# Datatypes Reference

## Key Concepts

- Datatypes are Roblox value objects and helper containers, not Instance classes.
- Common datatypes include spatial values like `Vector3` and `CFrame`, colors like `Color3`, UI values like `UDim2`, helper containers like `RaycastParams` and `OverlapParams`, and timing or config objects like `TweenInfo` and `DateTime`.
- Datatypes can expose constructors, constants, properties, methods, and math operations.
- Some datatypes are immutable value types, while others are mutable containers whose properties can be edited after construction.

## Rules

- Use datatype constructors and methods exactly as documented; overloads matter.
- Do not confuse datatypes with services or Instances.
- Follow the type exactly when a class member expects a datatype.
- Treat helper containers such as `RaycastParams` and `OverlapParams` as configuration objects that must be populated before use.
- Prefer documented constructors or static helpers over guessed field assignments.
- When a datatype property type points to an enum, confirm the enum item separately.

## Patterns

### Pick the datatype by job

- Position, size, direction, velocity: `Vector2`, `Vector3`, `Vector2int16`, `Vector3int16`
- Position plus orientation: `CFrame`
- Color values: `Color3`, `BrickColor`, `ColorSequence`
- UI size and position: `UDim`, `UDim2`
- Ray or overlap configuration: `RaycastParams`, `OverlapParams`
- Tween configuration: `TweenInfo`
- Time and timestamps: `DateTime`
- Randomness: `Random`

### Know the mutable helpers

- `RaycastParams` is mutable after `RaycastParams.new()`.
- `OverlapParams` is mutable after `OverlapParams.new()`.
- Many numeric and vector-like datatypes are immutable; build new values instead of trying to mutate components directly.

### Read all available members

- Constructors define creation patterns.
- Constants expose reusable values like `Vector3.zero`.
- Properties expose components or state.
- Methods expose operations such as `CFrame:ToWorldSpace()` or `Vector3:Dot()`.
- Math operations describe valid operators and result types.

## Examples

### Configure a raycast

```lua
local params = RaycastParams.new()
params.FilterDescendantsInstances = {script.Parent}
params.FilterType = Enum.RaycastFilterType.Exclude
params.IgnoreWater = true
```

### Build a facing transform

```lua
local cf = CFrame.lookAt(Vector3.new(0, 5, 10), Vector3.zero)
```

### Configure a tween

```lua
local info = TweenInfo.new(0.4, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
```
