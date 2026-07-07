# Unions and Intersections

## Key Concepts

- A union `A | B` means a value is one of several possible types.
- An intersection `A & B` means a value satisfies all combined types.
- Tagged unions use a shared discriminant field to support safe refinements.
- Intersections are useful for combining compatible record capabilities or function signatures.

## Rules

- Use unions for real alternative states, not as a replacement for missing design decisions.
- Prefer tagged unions over loose optional-field mixtures when cases differ structurally.
- Refine a union before using case-specific fields.
- Use intersections only when the combined shape is coherent.
- Do not write impossible primitive intersections such as `string & number`.

## Patterns

### Tagged union for operation results

```luau
--!strict

type Ok<T> = { kind: "ok", value: T }
type Err<E> = { kind: "err", error: E }
type Result<T, E> = Ok<T> | Err<E>
```

### Combine record capabilities with an intersection

```luau
--!strict

type Named = { name: string }
type Timed = { duration: number }
type NamedTimed = Named & Timed
```

### Overloaded function type declarations

```luau
--!strict

type Parse = ((string) -> number) & ((number) -> string)
```

## Examples

### Refine a tagged union by discriminant

```luau
--!strict

local function unwrap(result: Result<number, string>): number?
    if result.kind == "ok" then
        return result.value
    end

    return nil
end
```

### Require both parts of an intersection

```luau
--!strict

local value: NamedTimed = {
    name = "clip",
    duration = 3.5,
}
```
