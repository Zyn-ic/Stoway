# Engine Library YAML Files

## Key Concepts

- Built-in engine and Luau libraries are documented as YAML records with a consistent shape.
- Common library files describe tables such as `task`, `math`, `string`, `table`, `os`, `utf8`, `coroutine`, `debug`, `buffer`, `bit32`, and `vector`.
- Library YAML files usually expose:
  - `name` and `type`
  - `summary` and `description`
  - `properties`
  - `functions`
  - `parameters`
  - `returns`
  - `tags`
  - `deprecation_message`

## Rules

- Read library files as free-function documentation, not class-member documentation.
- Check `properties` for constants such as `math.pi` or `vector.zero`.
- Check `functions` for callable helpers such as `task.delay()` or `math.clamp()`.
- Treat `tags` and `deprecation_message` as authoritative when choosing modern APIs.
- When a deprecated global has a modern library replacement, recommend the library.

## Patterns

### Interpret the YAML shape

- `properties` describe values on the library table.
- `functions` describe callable helpers on the library table.
- `parameters` define ordered arguments and types.
- `returns` define result types and count.

### Pick the right library

- Scheduling and yielding: `task`
- Numeric helpers: `math`
- Text operations: `string` and `utf8`
- Table manipulation: `table`
- Time and environment helpers: `os`
- Coroutines: `coroutine`
- Bitwise helpers: `bit32`
- Buffer operations: `buffer`
- Low-level debugging helpers: `debug`
- Vector primitive helpers: `vector`

## Examples

```lua
task.delay(0.25, function()
  print("later")
end)

local alpha = math.clamp(rawAlpha, 0, 1)
```

- `task.delay()` is the modern scheduled-call surface.
- `math.clamp()` is a library function with ordered numeric parameters.
