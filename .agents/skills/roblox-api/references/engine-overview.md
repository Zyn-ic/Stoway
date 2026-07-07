# Engine Overview

## Key Concepts

- Roblox engine API lookup usually lands on one of five surfaces: classes, datatypes, enums, globals, or built-in libraries.
- Classes represent engine objects and services. Their members are properties, methods, events, and callbacks.
- Datatypes represent value objects and helper containers such as `Vector3`, `CFrame`, `Color3`, `RaycastParams`, `TweenInfo`, and `DateTime`.
- Enums provide named constant families such as `Enum.RaycastFilterType`, `Enum.CameraType`, or `Enum.EasingStyle`.
- Globals are built-in names available in script contexts, including Luau globals and Roblox globals.
- Libraries are tables of functions and constants such as `task`, `math`, `string`, `table`, `os`, `utf8`, `coroutine`, `debug`, `buffer`, `bit32`, and `vector`.

## Rules

- Start with the smallest surface that answers the question.
- Use a class or service when the capability belongs to an engine object.
- Use a datatype when the API needs a value object, helper container, or result object.
- Use an enum when an API expects a preset choice rather than a free-form value.
- Use a global only when the symbol is actually built into the runtime context.
- Use a library when the behavior is a free function rather than a class or datatype member.
- Confirm member kind, parameter order, return type, and deprecation status before writing code.

## Patterns

### Map the question to a surface

- "What service owns this behavior?" -> class or service lookup.
- "What object do I pass here?" -> datatype lookup.
- "What value should this property be set to?" -> enum lookup.
- "Can I call this name directly in a script?" -> global lookup.
- "Is this helper under `task`, `math`, or `string`?" -> library lookup.

### Follow type dependencies

- If a method parameter is typed as a datatype, open the datatype reference next.
- If a property or parameter is typed as an enum family, confirm the correct enum item before coding.
- If a deprecated global points to a library replacement, prefer the library.

## Examples

### Raycast selection

- World query surface: class `Workspace`
- Configuration surface: datatype `RaycastParams`
- Choice surface: enum `Enum.RaycastFilterType`
- Result surface: datatype `RaycastResult`

### Tween selection

- Engine owner: class `TweenService`
- Configuration object: datatype `TweenInfo`
- Preset values: `Enum.EasingStyle` and `Enum.EasingDirection`

### Global versus library

- `game` is a Roblox global.
- `Enum` is a Roblox global that exposes enum families.
- `task.wait()` is a library call, not a global.
