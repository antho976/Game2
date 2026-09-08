# Current scope

## Agreed order

1. Build and polish the hub.
2. Build the character, without weapons.
3. Decide subsequent work with the author after those stages have been reviewed.

The current pass builds the hub with an unarmed traversal character. Blacksmith and researcher locations are included, but purchases and research systems are deferred. See SYSTEMS.md for the captured future direction.

## Visual direction

Use the original crawler game's hub as the visual starting point, enhanced with more detail and purposeful additions. The later hand-drawn side-scrolling and procedural 3D chamber demos are not the selected direction.

The overall ambition is a small, highly polished game with a shop and meaningful progression. Those are later intentions, not authorization to build everything during the first hub stage.

## Two-day experiment

The author wants to explore the best result achievable with AI over two days, with hands-on guidance and iteration. This is a scope constraint and experiment, not a guarantee of a completed game. Favor a small, cohesive result over feature count.

## Reuse policy

- Keep the full original crawler as a local reference outside this repository.
- Add only new work and source files/assets actually reused by Game2.
- Bring required dependencies alongside a reused file; avoid copying unrelated combat, dungeon, progression, or test assets.
- Do not commit Godot caches, local saves, credentials, or old output captures.
- Retain relevant source files and asset provenance when an asset is reused.

## Current state

The hub now reuses selected crawler scenery and adds original Blender props, animals, and skeletal interaction animations. The asymmetric village includes a pond, ducks, cats, reactive birds, garden watering, a bench, and a bell. More detailed NPC schedules and all progression systems remain deferred.
