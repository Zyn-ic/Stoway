# Datatype YAML Files

## Key Concepts

- Datatype YAML files are the most detailed source for Roblox value-type lookup in this repository.
- A datatype file usually includes:
  - `name`, `type`, `summary`, and `description`
  - `constructors`
  - `constants`
  - `properties`
  - `methods`
  - `functions`
  - `math_operations`
  - `tags`
  - `deprecation_message`
- These files define both what a datatype is and how it must be used.

## Rules

- Read all constructor overloads before choosing a call shape.
- Use `constants` when they provide canonical values such as `Vector3.zero`.
- Check property types carefully; they often lead to other datatypes or enum families.
- Use `methods` for operations tied to a datatype instance.
- Read `math_operations` when operator support matters.
- Respect `tags` and `deprecation_message` exactly.
- Note mutability:
  - Helper containers like `RaycastParams` can be mutated after construction.
  - Many spatial and scalar datatypes are immutable and require creating new values.

## Patterns

### Read by question type

- "How do I construct it?" -> `constructors`
- "Does it have a built-in constant?" -> `constants`
- "What fields can I read?" -> `properties`
- "What can I call on it?" -> `methods`
- "Can I use operators with it?" -> `math_operations`

### Follow linked types

- `RaycastParams.FilterType` points to `RaycastFilterType`, so validate the enum item too.
- `CFrame` methods and constructors often depend on `Vector3`.
- `EnumItem.EnumType` points back to `Enum`.

## Examples

### Mutable configuration datatype

```lua
local params = RaycastParams.new()
params.FilterDescendantsInstances = {character}
params.FilterType = Enum.RaycastFilterType.Exclude
```

- Constructor comes from `constructors`.
- Editable fields come from `properties`.

### Overloaded constructor datatype

```lua
local cf = CFrame.new(0, 5, 0)
local look = CFrame.lookAt(Vector3.new(0, 5, 10), Vector3.zero)
```

- `CFrame` has multiple constructor shapes.
- The correct overload depends on the exact inputs you already have.
