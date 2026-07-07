# Streaming And Replication Behavior

## Key Concepts

- With `Workspace.StreamingEnabled`, clients may not have the full world loaded.
- A remote or replicated property change does not guarantee a related workspace instance is already present locally.
- Models can stream in and out based on global and per-model settings.
- Replication focus affects what regions stream and continue simulating on the client.

## Rules

- Never assume distant workspace content exists on the client.
- Use `WaitForChild()`, streaming detection, or per-model streaming controls when client code depends on an object being present.
- Keep large 3D content in `Workspace`, not replicated containers, so streaming can manage it.
- When teleporting or moving a character far away, request streaming around the destination before relying on local presence.
- Do not use persistent streaming modes as a blanket workaround for weak client logic.

## Patterns

### Replication-aware remote follow-up

```lua
TeamChangedRemote.OnClientEvent:Connect(function()
    local character = player.Character or player.CharacterAdded:Wait()
    local badge = character:WaitForChild("PoliceBadge")
end)
```

- The event may arrive before the related instance does.
- Wait for the instance explicitly.

### Detect stream in and stream out

```lua
CollectionService:GetInstanceAddedSignal("Interactable"):Connect(function(instance)
    -- Initialize local behavior when the instance is present.
end)
```

- Use tags and one local controller instead of assuming a static workspace.

### Use model streaming deliberately

- `Atomic` when descendants must arrive together.
- `Persistent` only for rare, small always-present requirements.
- Additional replication foci only when the player truly needs multiple active areas.

## Examples

### Safe teleport flow

```lua
player:RequestStreamAroundAsync(targetPosition)
```

- Request the area before moving the character.
- Still treat completion as best effort, not a hard guarantee.

### Streaming-sensitive gameplay caution

- Client-side raycasts can miss distant objects that have not streamed in.
- Critical hit or interaction validation should remain on the server.
