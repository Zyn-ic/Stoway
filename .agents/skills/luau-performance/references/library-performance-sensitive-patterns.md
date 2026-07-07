# Library Performance-Sensitive Patterns

## Key Concepts

- Many builtin functions have specialized fast paths when called directly in pure environments.
- Builtin specialization is strongest when argument types match common cases, especially numeric `math` calls.
- `string.byte` called as a builtin function is cheaper than method-style `s:byte(...)` when fastcall applies.
- `table` helpers are tuned for array-like data, but the right helper depends on whether size is known.
- `#t` is heavily optimized for array-like tables and usually inexpensive in practice.

## Rules

- Keep hot builtin calls direct and obvious.
- Pass the expected argument types to fast-path builtins.
- Use `table.create` only for arrays, not dictionaries.
- Use `table.insert` for append when capacity is unknown.
- Use indexed assignment when preallocated sequential writes are available.
- Use `pairs` or `ipairs` only when their specific semantics are needed; otherwise generalized iteration is fine.

## Patterns

### `math` library

- Direct numeric calls such as `math.abs`, `math.max`, `math.floor`, and `math.sqrt` are good fast-path candidates.
- Indirect wrappers can hide optimization opportunities.
- Non-numeric coercion cases are slower than already-correct numeric inputs.

### `string` library

- Prefer `string.byte(s, i)` over `s:byte(i)` in hot code when the builtin form is clear.
- Avoid repeated string-processing work when a parsed or cached representation can be reused.

### `table` library

- `table.insert(t, value)` is the best default append when array size is not known.
- `table.create(n)` preallocates array storage and pairs well with `t[i] = value`.
- `table.sort`, `table.move`, and related helpers are already tuned; use them instead of reimplementing them without evidence.

## Examples

### Direct numeric builtin calls

```luau
local function hypot2(x, y)
    return math.sqrt(x * x + y * y)
end
```

### Array preallocation plus indexed writes

```luau
local function mapDouble(values)
    local out = table.create(#values)

    for i, value in values do
        out[i] = value * 2
    end

    return out
end
```

### Unknown-size append path

```luau
local function collectPositives(values)
    local out = {}

    for _, value in values do
        if value > 0 then
            table.insert(out, value)
        end
    end

    return out
end
```
