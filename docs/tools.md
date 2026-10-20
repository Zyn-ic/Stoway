# Tools & Templates

Items are data; Tools are what the character holds. Templates bridge them.

## The `ServerStorage.Tools` contract

- Template **name = item `Id`** (exact match). No template → `AddItem`
  fails with `ITEM_NOT_IN_TOOLS_FOLDER`.
- Template **attributes become metadata defaults**: `Description` (`""`),
  `Image` (`""`), `Droppable` (`true`; or the player's `DefaultDroppable`
  when the attribute is absent), `IsGamepass` (`false`),
  `Rarity` (`"Common"`), `Type` (`"Material"`). Caller metadata wins on
  conflict.
- Equipped clones get `UUID`, `Amount`, `Id`, plus every metadata key stamped
  as attributes.

## Equip, unequip, drop

- **Equip** clears stale character Tools, clones the template, removes the
  reserved world-drop tag, and parents to the Character (which equips it).
- **Unequip** clears character Tools.
- **Drop** reuses the equipped tool when dropping the whole stack, else
  clones; syncs the `Amount` attribute; touch-strips the handle, pivots 5
  studs ahead, parents to Workspace, and tags it `Stoway` — which is what
  `StowayPickup` watches for (ProximityPrompt → `AddToBackpack` on trigger,
  tool destroyed on success, 15 s claim lifetime otherwise).
