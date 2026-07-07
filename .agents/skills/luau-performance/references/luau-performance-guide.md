# Luau Performance Guide

## Key Concepts

- Luau is tuned for stable high performance in interpreted execution, not just for JIT-only workloads.
- Many optimizations reward idiomatic code instead of requiring unusual coding style.
- Runtime speed depends heavily on table access shape, builtin call shape, and avoiding unnecessary allocations.
- Fast paths are strongest when the environment remains pure and table structures stay predictable.

## Rules

- Measure first, then optimize the largest real bottleneck.
- Prefer locals, direct field access, and direct builtin calls in hot code.
- Keep object-like tables uniform in shape across calls.
- Use table literals for object construction and `table.create` only for array preallocation.
- Avoid environment features that invalidate imports or builtin fast paths.

## Patterns

### Favor predictable field access

- Use `obj.field` when the field name is known at compile time.
- Keep instance data on the table itself.
- Put methods on a metatable table referenced by `__index`.
- Avoid `__index` functions and deep metatable chains on hot paths.

### Keep global and builtin access cheap

- Luau can import chains like `math.max` when the environment is pure.
- Localizing a builtin can still be fine, but direct obvious calls are easy for the compiler to optimize.
- `getfenv`, `setfenv`, and `loadstring` can invalidate these optimizations.

### Build and grow tables intentionally

- Create object-like tables with all known fields in the literal when possible.
- Preallocate arrays with `table.create(n)` when capacity is known.
- If final size is unknown, append with `table.insert`.
- If final size is known, sequential indexed writes are often better.

### Choose iteration form for semantics, not folklore

- Generalized iteration `for k, v in t do` is a first-class optimized path.
- `pairs` and `ipairs` are also specialized, but not automatically better.
- Numeric loops over `1..#t` can be slightly slower for traversal because each element is read manually.

## Examples

### Object construction with stable shape

```luau
local function makePoint(x, y)
    return {
        x = x,
        y = y,
    }
end
```

### Sequential array fill

```luau
local function copyDoubles(values)
    local out = table.create(#values)

    for i, value in values do
        out[i] = value * 2
    end

    return out
end
```

### Direct builtin call

```luau
local function largest(a, b, c)
    return math.max(a, b, c)
end
```
