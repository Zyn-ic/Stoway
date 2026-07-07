# Network Ownership

## Key Concepts

- Roblox can assign ownership of unanchored physics assemblies to a client or the server.
- Client ownership improves responsiveness because local simulation avoids a round trip.
- Ownership is also a security boundary because the server cannot directly verify every client-side physics step.
- `Touched` behavior is affected by ownership and can be abused if treated as authoritative proof.

## Rules

- Keep anchored parts server-owned; their ownership cannot be reassigned.
- Use manual ownership only when responsiveness clearly outweighs the validation burden.
- Prefer server ownership for gameplay-critical objects when exploit resistance matters more than feel.
- Revert temporary ownership with `SetNetworkOwnershipAuto()` when special control is no longer needed.
- Treat client-owned physics events as claims to validate, not facts to trust.

## Patterns

### Assign a driver-controlled vehicle

```lua
vehicleSeat.Changed:Connect(function(prop)
    if prop ~= "Occupant" then
        return
    end

    local humanoid = vehicleSeat.Occupant
    if humanoid then
        local player = Players:GetPlayerFromCharacter(humanoid.Parent)
        if player then
            vehicleSeat:SetNetworkOwner(player)
        end
    else
        vehicleSeat:SetNetworkOwnershipAuto()
    end
end)
```

- Give the driver responsiveness.
- Reset ownership when the seat is empty.

### Validate ownership-sensitive interactions

- For melee or projectiles, verify range and state on the server.
- Avoid trusting `Touched` alone for damage on client-owned parts.
- Anchor or server-own critical interactables when feasible.

## Examples

### Good use case

- A drivable vehicle that needs low-latency steering.

### Bad use case

- Letting a client-owned sword hitbox directly determine server damage with no additional checks.
