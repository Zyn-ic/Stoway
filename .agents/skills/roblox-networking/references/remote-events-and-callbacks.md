# Remote Events And Callbacks

## Key Concepts

- `RemoteEvent` is the default primitive for async client-server communication.
- `UnreliableRemoteEvent` is for disposable, high-frequency updates where loss or reordering is acceptable.
- `RemoteFunction` is synchronous and causes the caller to yield until a response returns.
- Clients cannot talk directly to other clients; all cross-player communication goes through the server.
- Remote payloads are copied across the boundary and lose table identity and metatables.

## Rules

- Prefer `RemoteEvent` unless a true request-response contract is required.
- Use `UnreliableRemoteEvent` only for transient data such as frequent aiming or look updates.
- Avoid `RemoteFunction:InvokeClient()` for critical flows because the server can error or hang on client failure.
- Keep argument shapes simple: numbers, strings, booleans, vectors, replicated instances, and tables with string keys.
- Do not send functions, rely on metatables, or mix numeric and string keys in one table.
- Do not expect sender-only instances to survive replication; non-replicated objects arrive as `nil`.

## Patterns

### Choose direction by authority

- Client to server: send player intent or request attempts.
- Server to client: send authoritative results, UI updates, or local presentation instructions.
- Server to all clients: broadcast validated state changes or shared presentation events.

### Keep payloads compact

```lua
FireWeaponRemote:FireServer(origin, hitPosition, targetId)
```

- Send compact, validated facts.
- Let the server derive damage, ammo use, and legality.

### Use a function only for bounded lookups

```lua
local success, reason = BuyItemRemote:InvokeServer(itemId)
```

- Keep the callback fast.
- Return a small result, not authoritative ownership of the game state.

## Examples

### Safe server callback shape

```lua
BuyItemRemote.OnServerInvoke = function(player, itemId)
    if typeof(itemId) ~= "string" then
        return false, "invalid-item"
    end

    return true, "ok"
end
```

### Unsafe argument shape

```lua
Remote:FireServer({
    weapon = "Sword",
    [1] = "mixed-table",
})
```

- Mixed tables can serialize in surprising ways.
- Prefer either an array or a dictionary, not both.
