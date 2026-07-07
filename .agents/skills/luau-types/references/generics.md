# Generics

## Key Concepts

- Generics preserve relationships between values and types.
- Generic aliases parameterize reusable shapes such as pairs, lists, maps, and wrappers.
- Generic functions let Luau infer caller-specific types from arguments.
- Alias generics can have defaults; function generics cannot.

## Rules

- Use a generic when the output type depends on the input type.
- Prefer a type parameter over `any` when callers should retain specific types.
- Name type parameters clearly when more than one role exists, such as `K` and `V`.
- Add explicit generic annotations only when inference is insufficient or readability improves.
- Do not assign default generic parameters to functions.

## Patterns

### Generic aliases

```luau
--!strict

type Box<T> = {
    value: T,
}

type Dict<K, V> = {[K]: V}
```

### Generic functions that preserve element type

```luau
--!strict

local function identity<T>(value: T): T
    return value
end
```

### Generic modules with exported contracts

```luau
--!strict

export type Result<T, E> =
    { kind: "ok", value: T } |
    { kind: "err", error: E }
```

## Examples

### Preserve input and output correspondence

```luau
--!strict

local function last<T>(items: {T}): T?
    return items[#items]
end
```

### Use defaulted alias generics where sensible

```luau
--!strict

type Pair<T = string> = {
    first: T,
    second: T,
}

local words: Pair = {
    first = "a",
    second = "b",
}
```
