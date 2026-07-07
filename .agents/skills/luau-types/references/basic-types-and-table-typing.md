# Basic Types and Table Typing

## Key Concepts

- Builtin primitives include `nil`, `boolean`, `number`, and `string`.
- Special types matter for API design:
  - `unknown` requires narrowing before use.
  - `never` represents impossible values.
  - `any` opts out of type safety.
- Function types use `(input) -> output` syntax.
- Variadics use `...T`; function type packs use `...T` or tuple-like returns.
- Tables are analyzed as unsealed, sealed, or generic depending on how they are created and used.

## Rules

- Prefer precise concrete types over `any`.
- Use `unknown` when a value exists but must be validated before use.
- Use `T?` for optional values instead of ad hoc unions with `nil`.
- Use `{T}` for arrays and `{[K]: V}` for dictionaries.
- Expect returned or explicitly annotated tables to be sealed.
- Use explicit named record types for stable object shapes.

## Patterns

### Arrays and dictionaries

```luau
--!strict

local names: {string} = { "Ada", "Lin" }
local scores: {[string]: number} = {
    Ada = 10,
    Lin = 12,
}
```

### Optional fields in records

```luau
--!strict

type User = {
    id: number,
    nickname: string?,
}
```

### Seal a returned table intentionally

```luau
--!strict

local function makePoint(x: number, y: number): { x: number, y: number }
    return { x = x, y = y }
end
```

## Examples

### Use `unknown` when validation is required

```luau
--!strict

local function readNumber(value: unknown): number?
    if type(value) == "number" then
        return value
    end

    return nil
end
```

### Allow width subtyping with sealed records

```luau
--!strict

type Point1D = { x: number }
type Point2D = { x: number, y: number }

local point2: Point2D = { x = 1, y = 2 }
local point1: Point1D = point2
```
