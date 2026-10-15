# Client Events & Hooks

The UI bus (`ClientEvents`) plus the `Store` atoms plus `SetLayout` are the
whole client surface feature code should touch.

## The bus

`SlotClicked`, `SlotHovered`, `DragStarted`, `DragEnded`, `Equipped`,
`Unequipped`, `ItemAdded`, `ItemRemoved`, `Swapped`, `Selected`,
`Deselected`. Subscribe, never emit (layouts own emission).

## The atoms

`ClientStore.Items / Hotbar / Storage / EquippedItemUUID / Weight /
Settings` — read with `Fusion.peek`, derive with `Computed`. Never write
them; `sync()` owns that.

## Layouts and hooks

`LayoutManager.SetLayout(scope, playerGui, store, hotbarType, skin)` mounts
live. Skins expose `Hooks` (`HookFuncs/` in the prefab); layouts invoke them
via `ClientEvents.CallHook` (spawned + pcall'd, so a throwing hook warns
once and never breaks inventory).

## Cookbook

Toast on `ItemAdded`, sound on `Equipped`:

```lua
ClientEvents.ItemAdded:Connect(function(slotType, slot)
	Toast.show(("Picked up something in %s %d"):format(slotType, slot))
end)

ClientEvents.Equipped:Connect(function()
	SoundService:PlayLocalSound(equipSound)
end)
```

A custom skin hook (in the prefab's `HookFuncs` module):

```lua
return {
	OnEquip = function(slotType, slot)
		-- flash the frame, play a tween, notify quests
	end,
}
```
