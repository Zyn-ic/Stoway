# Showcase Tour

After this page you can demo the system to a friend in under a minute.

`src/server/Showcase/` wires the place's own models — `cop`, `criminal`,
`Apple_Tree` — with prompts, using public Stoway routes exclusively. It
touches no inventory code. Studio only; production builds drop the folder
(see [builds](builds.md)).

## The three attractions

- **Thief** (`Thief.server.luau`) — `Risk it` (E) lets him steal a random
  item when you are not a cop (cops get a pass; empty pockets get mocked),
  then drops it nearby for the steal → drop → pickup loop. `Join the crew`
  (F) turns you criminal, stamping everything held and everything picked up
  afterwards.
- **Cop** (`Cop.server.luau`) — `Make me a cop` (E) confiscates the *entire*
  inventory of a criminal who talks to him, and turns anyone else into a cop
  (same stamping deal, blue instead of red). `Nothing, officer` (F) walks
  away.
- **Apple tree** (`AppleTree.server.luau`) — `Pick` (E) grants an apple into
  the hotbar through the normal route. Pick repeatedly and watch the stack
  badge climb.

Prompts on one NPC live on different parts (Head vs torso) so their UI never
stacks. Prompt input only reaches prompts the camera can see — face what you
press.

## Sides and future picks

`Sides.luau` tracks cop vs criminal per player and registers one team-guard
adapter: everything granted afterwards arrives pre-stamped with the player's
side, so picks never show grey. Engine-level note this surfaced: adapters run
inside the route while it still holds the per-player lock, so follow-up route
calls must be `task.defer`red or they fail with `OPERATION_IN_PROGRESS`.

## Known gap: pickup needs the backpack

`StowayPickup` grants through `AddToBackpack`, so on the default settings
(`BackpackEnabled = false`) picking anything back up fails with
`BACKPACK_DISABLED`. Enable the backpack in `Shared/Stoway/Settings.luau`
for the full steal → drop → pickup loop.
