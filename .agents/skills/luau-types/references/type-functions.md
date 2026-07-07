# Type Functions

## Key Concepts

- Type functions run during analysis time, not runtime.
- They operate on types and can build or transform types programmatically.
- They are appropriate for advanced reusable patterns that cannot be expressed clearly with plain aliases alone.
- The `types` library provides primitives for inspecting and constructing types.

## Rules

- Use type functions only when simpler aliases, generics, unions, or intersections are insufficient.
- Keep type functions deterministic and narrowly scoped to type transformation.
- Validate inputs and raise clear errors when a type function expects a certain shape.
- Prefer a named alias wrapper around complex type-function results so consumers see a stable API.
- Do not drift into runtime logic; these execute during analysis only.

## Patterns

### Compute keys from a table type

```luau
type function simple_keyof(ty)
    if not ty:is("table") then
        error("expected table type")
    end

    local union = nil

    for property in ty:properties() do
        union = if union then types.unionof(union, property) else property
    end

    return if union then union else types.singleton(nil)
end
```

### Wrap a type-function result in an alias

```luau
type Person = {
    name: string,
    age: number,
}

type PersonKeys = simple_keyof<Person>
```

## Examples

### Restrict advanced logic to type-level utilities

```luau
type function require_table(ty)
    if not ty:is("table") then
        error("table expected")
    end

    return ty
end

type Checked = require_table<{ id: number }>
```

### Use plain aliases when that is enough

```luau
--!strict

type IdMap<T> = {[string]: T}
```
