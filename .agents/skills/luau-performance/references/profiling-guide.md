# Profiling Guide

## Key Concepts

- Luau provides a sampling profiler that records execution stacks and can be visualized as a flame graph.
- A flame graph shows where total runtime accumulates; wider frames matter more than deeper-looking frames.
- Sampling profilers are statistical: they are reliable for repeated cost, not single short events.
- Poor naming of local anonymous functions makes attribution harder during investigation.

## Rules

- Profile optimized builds when possible; debug-style overhead can distort results.
- Reproduce the real workload before drawing conclusions.
- Investigate the widest stacks first, not the most visually complex code.
- Re-run the profiler after each meaningful optimization pass.
- Name hot local functions with `local function name()` when you want clearer profiler output.

## Patterns

### Use a profiler workflow

1. Capture a baseline profile for the real scenario.
2. Find the few functions dominating runtime.
3. Inspect whether the cost is algorithmic, allocation-driven, or call-dispatch-driven.
4. Change one hotspot at a time.
5. Re-profile and compare.

### Read flame graphs correctly

- Width represents cumulative sampled time.
- Nesting represents call stacks.
- Anonymous frames can still be traced by source location.
- Time spent in leaf C or builtin work may be attributed to the calling Luau function.

### Environment-specific profiling notes

- In Roblox tooling, use Script Profiler or related Luau profiling tools to validate whether a function is actually hot.
- Use `debug.profilebegin` and `debug.profileend` only to improve attribution when environment tooling supports them.
- Breakpoints and debugger attachment can change observed execution behavior in some environments, especially for native execution.

## Examples

### Name a hot helper for clearer attribution

```luau
local function accumulate(values)
    local total = 0

    for _, value in values do
        total += value
    end

    return total
end
```

### Compare before and after a focused rewrite

```luau
local function sumSquares(values)
    local total = 0

    for _, value in values do
        total += value * value
    end

    return total
end
```
