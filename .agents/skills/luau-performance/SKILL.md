---
name: luau-performance
description: "Use for Luau performance work focused on profiling hotspots, allocation-aware code structure, table and iteration costs, builtin and function-call fast paths, compiler/runtime optimization behavior, and environment constraints that change execution speed."
---

# luau-performance

## When to Use

Use this skill when the task is primarily about Luau runtime cost:

- Profiling code to find real hotspots before changing implementation details.
- Reducing allocation churn, GC pressure, or closure creation in repeated paths.
- Choosing faster table construction, lookup, append, and iteration patterns.
- Making code cooperate with Luau fast paths for builtin calls, method calls, and imports.
- Explaining how compiler and runtime optimizations affect hot functions.
- Tuning a confirmed hot path while balancing readability and maintainability.
- Accounting for sandbox or environment behavior only when it changes Luau execution or deoptimizes code.

Do not use this skill when the task is mainly about:

- Teaching general Luau syntax, control flow, tables, or metatables from first principles.
- Designing deep type-system abstractions, analyzer behavior, or advanced type utilities.
- Roblox-specific replication, streaming, rendering, networking, physics, or other engine performance patterns.

## Decision Rules

- Start with measurement. If the code is non-trivial, profile or benchmark before making optimization claims.
- Fix algorithmic cost before micro-optimizing bytecode-level details.
- Prioritize changes that remove repeated work, repeated allocation, or repeated dynamic dispatch in hot paths.
- Keep performance-sensitive modules in a pure environment. Avoid `getfenv`, `setfenv`, and `loadstring` where speed matters.
- Prefer stable table shapes, direct field access, direct builtin calls, and simple call graphs in hot code.
- Use environment-specific compilation features only after measurement shows a likely win and the runtime actually supports them.
- If the task shifts into core language teaching, use `luau-core`.
- If the task shifts into types, inference, or annotations as the main subject, use `luau-types`.
- If the task depends on Roblox engine architecture instead of Luau execution behavior, hand off to the appropriate `roblox/*` skill.
- If a request mixes performance work with out-of-scope topics, answer only the Luau runtime portion and exclude the rest.

## Instructions

1. Define the workload first:
   - what runs often,
   - what allocates often,
   - what is on the critical path,
   - what metric matters most: wall time, frame budget, or memory churn.
2. Profile before rewriting. Use sampling or environment tooling to identify functions that actually dominate runtime.
3. Optimize the largest validated bottleneck first. Do not spread micro-optimizations across cold code.
4. Reduce allocation pressure in repeated paths:
   - avoid rebuilding tables every iteration,
   - avoid creating fresh closures in loops unless necessary,
   - avoid retaining tables or connections longer than needed.
5. Shape tables for the runtime:
   - use literals to create object-like tables with all known fields up front,
   - keep object layouts uniform across calls,
   - use `table.create` only for array-like tables with known capacity.
6. Choose iteration deliberately:
   - use generalized iteration `for k, v in t do` for normal table traversal,
   - use `ipairs` only when stop-at-first-`nil` behavior is required,
   - use numeric loops when the index itself is needed or sequential writes are part of the algorithm.
7. Keep builtin fast paths obvious:
   - call builtins directly, such as `math.max(x, y)` or `string.byte(s, 1)`,
   - do not hide hot builtin calls behind unnecessary indirection,
   - prefer builtin function form over method form when fastcall behavior depends on it.
8. Keep call sites compiler-friendly:
   - prefer `local function` for hot helpers,
   - avoid unnecessary mutation of captured values,
   - keep small helpers local to the module when that improves inlining opportunities.
9. Keep metatable usage cheap in hot code:
   - store data on the object itself,
   - point `__index` directly at a table,
   - avoid `__index` functions and deep lookup chains on critical paths.
10. Treat environment features as performance constraints:
   - `getfenv`, `setfenv`, and `loadstring` can deoptimize imports and fast builtin handling,
   - debugging and breakpoints can alter observed runtime behavior in some environments,
   - native compilation, where supported, should be applied selectively and measured.
11. Preserve practicality. Prefer the simplest change that removes measurable cost, even if a more aggressive rewrite is theoretically faster.

## Using References

- Open `references/luau-performance-guide.md` for the main Luau fast-path model: table access, imports, method calls, iteration, and allocation-aware table construction.
- Open `references/profiling-guide.md` for profiler workflow, interpreting flame graphs, naming functions for attribution, and environment-specific profiling notes.
- Open `references/runtime-and-compiler-optimization-notes.md` for compiler limits, inlining, constant folding, upvalues, closure caching, and selective native compilation guidance.
- Open `references/library-performance-sensitive-patterns.md` for practical choices around `math`, `string`, `table`, iteration helpers, and array-oriented APIs.
- Open `references/sandbox-constraints-relevant-to-runtime-behavior.md` for the environment rules that disable or weaken runtime optimizations.
- Do not open other skill references unless the task clearly crosses into another skill's scope.

## Checklist

- A measurement plan or profiler result exists for the claimed hotspot.
- The proposed change targets a path that runs often enough to matter.
- Algorithmic cost has been considered before micro-tuning syntax.
- Allocation churn is reduced where the code repeats.
- Table shape and iteration strategy match the data pattern.
- Builtin calls stay direct enough to preserve fast paths where possible.
- Environment deoptimizers such as `getfenv`, `setfenv`, or `loadstring` are avoided in hot modules.
- Any environment-specific compilation feature is justified by measurement, not guesswork.
- The guidance stays within Luau execution behavior and avoids Roblox engine performance topics.

## Common Mistakes

- Optimizing unmeasured code because it "looks hot."
- Using `table.create` for dictionaries instead of arrays.
- Assuming `pairs` or `ipairs` are automatically faster than generalized iteration.
- Rewriting `obj:Method()` into cached method locals even when Luau already optimizes method calls well.
- Hiding builtin calls behind wrappers or indirect dispatch on a hot path.
- Varying object table keys heavily and then expecting field lookup caching to stay effective.
- Using `getfenv` only for reads and assuming it has no optimization cost.
- Sprinkling native compilation directives everywhere without measuring memory, startup, or actual runtime wins.

## Examples

### Preallocate and fill arrays sequentially

```luau
local function buildSquares(count)
    local result = table.create(count)

    for i = 1, count do
        result[i] = i * i
    end

    return result
end
```

### Keep builtins direct in hot code

```luau
local function clamp01(x)
    return math.min(math.max(x, 0), 1)
end
```

### Use stable object layouts and direct `__index`

```luau
local Counter = {}
Counter.__index = Counter

function Counter.new(step)
    return setmetatable({
        value = 0,
        step = step,
    }, Counter)
end

function Counter:advance()
    self.value += self.step
    return self.value
end
```

### Avoid deoptimizing the environment in performance-sensitive modules

```luau
local function magnitude2(x, y)
    return math.sqrt(x * x + y * y)
end

return magnitude2
```
