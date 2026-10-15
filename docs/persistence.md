# Persistence

State is per session; nothing saves. `createPlayer` builds it,
`removePlayer` returns it — those two are your hook points.

```lua
Players.PlayerRemoving:Connect(function(player)
	local state = Stoway.removePlayer(player)
	if state then
		MySaver.save(player.UserId, state.Items, state.Hotbar, state.Storage)
	end
end)
```

Save items, slots, and backpack-relevant metadata; rebuild with
`createPlayer(player, overrides)` + `AddItem` on next join. Decide what
`EquippedItemUUID`, `Weight`, and volatile keys (cooldown ends, `IsNew`
glows) mean across sessions — usually: drop them.
