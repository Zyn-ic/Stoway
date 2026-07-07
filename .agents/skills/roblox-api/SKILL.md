---
name: roblox-api
description: "Use for Roblox Engine API lookup during implementation: finding the correct engine class or service, confirming properties, methods, events, callbacks, datatypes, enums, globals, and built-in libraries, and verifying parameter, return, and property usage for a known engine task. Prefer this skill when the problem is referential rather than architectural."
---

# roblox-api

## When to Use

Use this skill when the task is mainly about identifying or confirming the correct Roblox engine surface:

- Finding which class or service owns a capability.
- Checking whether a member is a property, method, event, or callback.
- Confirming datatype constructors, properties, methods, constants, or math behavior.
- Choosing the correct enum family and item for a property or parameter.
- Looking up globals such as `game`, `workspace`, `script`, `plugin`, or `Enum`.
- Confirming built-in library behavior such as `task`, `math`, `string`, `table`, `os`, or `vector`.
- Verifying exact parameter shapes, return values, and deprecation status before writing code.

Do not use this skill when the task is mainly about:

- Overall Roblox project structure, code placement, or client-server responsibility.
- Remote security, replication architecture, persistence design, or Open Cloud workflows.
- Broader system design where API lookup is secondary to structural decisions.

## Decision Rules

- Use this skill if the main question is "what engine API should I call or read here?"
- Use this skill when a known problem needs the correct class, member, datatype, enum, global, or library surface.
- Start with the narrowest surface that matches the question:
  - Class or service for engine objects and services.
  - Datatype for value objects such as `Vector3`, `CFrame`, `RaycastParams`, or `TweenInfo`.
  - Enum for preset values such as `Enum.RaycastFilterType.Exclude`.
  - Global for always-available names like `game`, `workspace`, `script`, or `Enum`.
  - Library for free functions under tables like `task`, `math`, `table`, or `string`.
- If the task is really about where code belongs, which side owns state, or how systems should be arranged, hand off to `roblox-core`.
- If the task centers on remotes, trust boundaries, replication correctness, or server authority, hand off to `roblox-networking`.
- If the task centers on persistent storage, quotas, save design, or cross-server state, hand off to `roblox-data`.
- If the task centers on Open Cloud, OAuth, or external integrations, hand off to `roblox-cloud` or `roblox-oauth`.
- If a request mixes referential lookup with out-of-scope design, answer only the engine-reference portion and explicitly exclude the rest.

## Instructions

1. Identify the missing fact before searching:
   - Which engine object or service is responsible?
   - Which member kind is needed?
   - Which datatype or enum is expected by the API?
   - Which global or library helper fits the job?
2. Choose the correct reference file first:
   - `references/engine-overview.md` for surface selection.
   - `references/classes-reference.md` for class, service, and member lookup.
   - `references/datatypes-reference.md` for value types and their usage.
   - `references/enums-reference.md` for enum families and items.
   - `references/globals-reference.md` for Luau and Roblox globals.
   - `references/engine-library-yaml-files.md` for built-in libraries.
   - `references/datatype-yaml-files.md` for interpreting datatype YAML shape and overloads.
3. Confirm the exact API contract before coding:
   - Member name.
   - Member kind.
   - Parameter order and types.
   - Return type.
   - Property type.
   - Enum family and item names.
   - Deprecation or other tags.
4. Prefer the documented modern surface when an older global or legacy form also exists:
   - Prefer `task.wait()` over `wait()`.
   - Prefer `task.delay()` over `delay()`.
   - Prefer `game:GetService()` for service access when clarity matters.
5. When a datatype or library page shows overloads, read all overloads before choosing a call pattern.
6. When a parameter or property type points to another datatype or enum, follow that dependency and confirm it separately.
7. Keep the answer referential and implementation-facing:
   - Name the correct surface.
   - State the relevant signature or property type.
   - Mention any important enum values, tags, or constraints.
   - Do not drift into architecture, persistence, or security-system design.

## Using References

- Open `references/engine-overview.md` first when the user only knows the problem and not the engine surface.
- Open `references/classes-reference.md` when the question is about classes, services, or member discovery.
- Open `references/datatypes-reference.md` when a value object or helper container is involved.
- Open `references/enums-reference.md` when an API expects a preset constant.
- Open `references/globals-reference.md` when the question involves built-in names available in scripts.
- Open `references/engine-library-yaml-files.md` when the needed API lives under `task`, `math`, `string`, `table`, `os`, `utf8`, `coroutine`, `debug`, `buffer`, `bit32`, or `vector`.
- Open `references/datatype-yaml-files.md` when constructor overloads, mutable-vs-immutable behavior, constants, or member lists need careful interpretation.

## Checklist

- The missing fact is identified as class, member, datatype, enum, global, or library lookup.
- The chosen engine surface is the narrowest one that matches the problem.
- Member kind, parameter order, return type, and property type are confirmed before use.
- Required enum family and item names are spelled exactly.
- Datatype constructors or methods match the documented overload.
- Deprecated globals or legacy forms are not recommended unless necessary for compatibility.
- The response stays referential and does not drift into project architecture, persistence, or cloud workflows.
- Out-of-scope systems are handed off to the proper Roblox skill when needed.

## Common Mistakes

- Using `roblox-api` for project structure questions that belong to `roblox-core`.
- Guessing a member name without confirming whether it is a property, method, event, or callback.
- Passing raw numbers where an enum item is expected.
- Treating a datatype like an Instance class, or vice versa.
- Missing constructor overloads and choosing the wrong parameter order.
- Recommending deprecated globals like `wait()` or `delay()` when `task` equivalents are the modern surface.
- Assuming a global exists in every context, especially `plugin`.
- Expanding a simple API lookup into networking, data, or cloud-system design.

## Examples

### Choose the right surface for a raycast

- Class or service: `Workspace` (via `WorldRoot` behavior)
- Method: `Workspace:Raycast(origin, direction, raycastParams)`
- Datatype: `RaycastParams`
- Enum: `Enum.RaycastFilterType`
- Result datatype: `RaycastResult`

### Confirm a tween API call

- Class or service: `TweenService`
- Method: `TweenService:Create(instance, tweenInfo, propertyTable)`
- Datatype: `TweenInfo`
- Enums often involved: `Enum.EasingStyle`, `Enum.EasingDirection`

### Distinguish global, datatype, and enum usage

```lua
local Workspace = game:GetService("Workspace")

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local cf = CFrame.lookAt(Vector3.new(0, 5, 10), Vector3.zero)
```

- `game` is a Roblox global.
- `RaycastParams`, `CFrame`, and `Vector3` are datatypes.
- `Enum.RaycastFilterType.Exclude` is an enum item.
