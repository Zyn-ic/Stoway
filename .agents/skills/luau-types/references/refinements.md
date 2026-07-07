# Refinements

## Key Concepts

- Refinement narrows a variable or property to a more specific type based on control flow.
- Luau refines through truthiness checks, `type(...)` guards, equality tests, and `assert(...)`.
- Compound boolean expressions can refine multiple values at once.
- Tagged unions depend on refinements to safely access case-specific fields.

## Rules

- Refine before reading fields or calling operations that only exist on one branch of a union.
- Use `type(x) == "..."` for primitive narrowing.
- Use equality against singleton values or discriminants for tagged unions.
- Use `assert(...)` when a failure should stop execution and narrow afterward.
- Keep branch logic simple enough that the narrowing remains obvious.

## Patterns

### Truthiness narrowing

```luau
--!strict

local maybeName: string? = nil

if maybeName then
    local name: string = maybeName
end
```

### Primitive type guard

```luau
--!strict

local function toNumber(value: string | number): number
    if type(value) == "number" then
        return value
    end

    return tonumber(value) or 0
end
```

### Assertion-based narrowing

```luau
--!strict

local value: string | number = "42"
assert(type(value) == "string")
local text: string = value
```

## Examples

### Narrow a discriminated union

```luau
--!strict

type Ready = { state: "ready", payload: string }
type Idle = { state: "idle" }
type Model = Ready | Idle

local function read(model: Model): string?
    if model.state == "ready" then
        return model.payload
    end

    return nil
end
```

### Compose guards

```luau
--!strict

local function normalize(x: string | number | nil): string?
    if x and type(x) == "string" then
        return x
    end

    return nil
end
```
