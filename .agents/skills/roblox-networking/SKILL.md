---
name: roblox-networking
description: "Use for Roblox multiplayer communication across the client-server boundary: designing RemoteEvent, UnreliableRemoteEvent, and RemoteFunction flows; validating client requests; handling replication-aware gameplay; applying rate limits and anti-exploit checks; reasoning about network ownership, server-authority patterns, Input Action System use in authoritative gameplay, and streaming-sensitive multiplayer correctness."
---

# roblox-networking

## When to Use

Use this skill when the task is primarily about multiplayer communication, replication, or trust boundaries in a Roblox experience:

- Designing or reviewing `RemoteEvent`, `UnreliableRemoteEvent`, and `RemoteFunction` usage.
- Deciding what the client is allowed to send versus what the server must derive or verify.
- Choosing safe remote payload shapes, validating arguments, and handling replication timing.
- Protecting server logic from spam, malformed payloads, impossible requests, or exploit-driven abuse.
- Building interactions where the client initiates an action but the server remains authoritative.
- Reasoning about network ownership, client-predicted physics, or `Touched`-related exploit risk.
- Applying server-authority ideas, prediction, rollback-aware structure, or input routing for competitive or authoritative gameplay.
- Designing multiplayer logic that must remain correct when streaming affects what the client can currently see or access.

Do not use this skill when the task is mainly about:

- Persistent data architecture, save formats, trading storage, or DataStore and MemoryStore design.
- Broad engine API lookup as the primary task.
- Open Cloud, OAuth, or external web integrations.

## Decision Rules

- Use this skill if the main question is "how should client and server communicate safely and correctly?"
- Use this skill when a feature depends on remotes, replication timing, ownership of simulated parts, or server validation.
- Prefer `RemoteEvent` for one-way signals and state notifications; prefer `UnreliableRemoteEvent` only for disposable, continuously changing data; prefer `RemoteFunction` only when a synchronous reply is truly required.
- Treat the server as the authority for shared game state, rewards, combat outcomes, movement permission, and any action that affects other players.
- If a client can request an action, validate permission, context, type, structure, value range, and frequency on the server before mutating state or broadcasting results.
- If the task is mostly about where scripts live, core services, attributes, bindables, or basic runtime structure without a strong networking/security angle, hand off to `roblox-core`.
- If the task is mainly about data persistence or cross-server state, hand off to `roblox-data`.
- If the task is mainly about exhaustive class/member lookup, hand off to `roblox-api`.
- If a request mixes networking with out-of-scope systems, answer only the multiplayer and trust-boundary portion and explicitly exclude the rest.
- When unsure, omit material that would drift into persistence, cloud auth, or broad API catalog guidance.

## Instructions

1. Start by classifying each piece of information:
   - Client input intent.
   - Server-derived authoritative state.
   - Replicated presentation or notification.
   - Disposable telemetry or cosmetic updates.
2. Choose the narrowest network primitive that matches the job:
   - `RemoteEvent` for async one-way communication.
   - `UnreliableRemoteEvent` for frequent data where dropped or out-of-order updates are acceptable.
   - `RemoteFunction` only for short, bounded request-response flows where yielding is acceptable and server ownership of the decision is clear.
3. Keep remote contracts explicit and small:
   - Prefer stable argument order and dictionaries with string keys.
   - Do not rely on metatables, function values, mixed tables, non-replicated instances, or table identity surviving a network hop.
   - Pass identifiers, compact values, or validated replicated instances instead of arbitrary object trees.
4. Design remotes around intent, not outcome:
   - Client says "I pressed interact on this target" or "I attempted to fire from here toward this hit point."
   - Server decides whether the action is legal and computes the result.
   - Avoid remotes where the client directly declares rewards, damage, inventory changes, or unrestricted instance mutations.
5. Validate every client-triggered request on the server:
   - Permission/context: is the player alive, in range, in the right state, and allowed to do this now?
   - Type/shape: are the arguments the expected kinds, sizes, and instance classes?
   - Value sanity: reject impossible numbers, `NaN`, `inf`, out-of-range vectors, or unknown ids.
   - Timing: apply per-player rate limits or cooldowns before expensive work or broadcast fan-out.
6. Treat server-to-client rebroadcasts as privileged operations:
   - Never act as a blind relay from one client to other clients.
   - Validate first, then broadcast only the minimal safe data needed for presentation.
7. Use `RemoteFunction` conservatively:
   - Expect the caller to yield.
   - Keep the callback fast and deterministic.
   - Avoid `InvokeClient()` for critical flows because the server can hang or fail if the client errors, disconnects, or never returns.
8. Reason about replication explicitly:
   - A remote arriving does not guarantee a related instance or property has already replicated to the client.
   - With streaming enabled, clients may not currently have distant workspace content.
   - Use `WaitForChild()`, replication-aware design, tags, or model streaming controls instead of assuming presence.
9. Treat network ownership as a performance tool with security cost:
   - Client-owned physics can feel responsive.
   - Client-owned physics can also be abused, and `Touched`-based server logic becomes especially risky.
   - Keep gameplay-critical physics server-owned unless the responsiveness tradeoff is worth the validation burden.
10. For authoritative or competitive gameplay:
   - Prefer a server-authority mindset where the server is the source of truth and the client primarily contributes input.
   - Use the Input Action System for inputs that affect the core authoritative simulation.
   - Keep simulation state separate from local rendering and effects.
11. When discussing examples, stay inside scope:
   - Focus on multiplayer communication, validation, ownership, authority, and streaming correctness.
   - Do not expand into persistence architecture, cloud APIs, or general-purpose API catalogs.

## Using References

- Open `references/remote-events-and-callbacks.md` for remote selection, directionality, argument-shape limits, and safe payload design.
- Open `references/client-server-runtime.md` for replication timing, latency expectations, and side ownership of gameplay responsibilities.
- Open `references/security-and-defensive-design.md` for the security mindset, defensive design, and rate-limiting patterns.
- Open `references/client-server-boundary-guidance.md` for concrete validation layers, secure rebroadcast patterns, and protection of client-triggered interactions.
- Open `references/network-ownership.md` when physics responsiveness, client-owned parts, or `Touched` validity are part of the problem.
- Open `references/server-authority-model-and-techniques.md` for authoritative simulation, prediction, rollback-aware structure, and latency-conscious design.
- Open `references/input-action-system.md` when networked or authoritative gameplay depends on action-oriented, cross-platform input routing.
- Open `references/streaming-and-replication-behavior.md` when correctness depends on streamed workspace content, replication focus, or models that may not be locally present.

## Checklist

- The client-server contract is defined in terms of player intent, not client-declared outcomes.
- The chosen remote primitive matches the required reliability and response behavior.
- Remote payloads use stable, replication-safe shapes.
- The server validates permission, context, type, structure, and values before mutating shared state.
- The server applies rate limits or cooldowns to abuse-prone entry points.
- Server-to-client broadcasts happen only after validation and never as blind relays.
- `RemoteFunction` use is justified and bounded.
- Replication timing assumptions are explicit, especially when remotes reference freshly created or streamed content.
- Network ownership choices are deliberate and paired with server-side validation where needed.
- `Touched`, proximity, click, or drag interactions are not trusted just because the engine fired them.
- Authoritative gameplay uses client inputs and server-owned state rather than trusting client simulation results.
- Input guidance stays focused on networked or authoritative use of the Input Action System.
- No persistence architecture, Open Cloud, OAuth, or broad API catalog material is included.

## Common Mistakes

- Letting the client tell the server who was damaged, what reward was earned, or which state change already happened.
- Using `RemoteFunction` for convenience when an async `RemoteEvent` plus server-side state would be safer.
- Broadcasting one client's payload to every other client without validating it first.
- Passing mixed tables, metatable-backed objects, huge payloads, or sender-only instances across remotes.
- Forgetting to reject `NaN`, `inf`, oversized strings, or spoofed instance references.
- Assuming a remote means an associated part, attribute, or model has already replicated.
- Relying on client cooldowns without server-side rate limiting.
- Treating client-owned physics or `Touched` events as authoritative proof of contact.
- Using unreliable channels for state that must arrive in order.
- Mixing core authoritative simulation logic with local-only animation, camera, or VFX code.

## Examples

### Design a secure client-triggered interaction

```lua
-- Client: request an interaction attempt, not the reward itself.
InteractRemote:FireServer(targetId)
```

```lua
-- Server: verify range, state, and target validity before applying effects.
InteractRemote.OnServerEvent:Connect(function(player, targetId)
    -- Validate player state, target existence, distance, cooldown, and permissions.
    -- Then mutate shared state on the server.
end)
```

### Use unreliable remotes only for disposable updates

```lua
-- Suitable for frequent cosmetic aim or camera direction updates.
AimDirectionRemote:FireServer(lookVector)
```

- Accept dropped or out-of-order packets.
- Do not use this pattern for inventory, damage, scoring, or one-time transactions.

### Keep authoritative simulation separate from rendering

```lua
-- Core state changes live in shared/server-side simulation logic.
-- Local VFX and sounds react to the synchronized state afterward.
```
