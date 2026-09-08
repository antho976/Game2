# Game2

A small, warm village hub built in Godot 4.7. The original crawler is the visual reference; only reused dependencies are included here.

## Run

```fish
./play.fish
```

Or import `project.godot` into Godot 4.7 and press F5. The launcher imports assets and isolates local data from the original game. The packed Blender sources are excluded from Godot's automatic importer, so Blender is only required when editing or regenerating assets.

## Controls

- WASD/arrows: walk; Shift: jog.
- F: interact with the nearest animal or activity.
- Mouse wheel: zoom. Middle mouse drag: rotate the elevated camera.
- Tab: village overview. H: hide interface. M: mute audio.
- R: return to the arrival path. F11: fullscreen. Escape: pause/menu.

## Things to try

Approach the feeding birds and watch them fly to another patch. Pet a friendly cat. Scatter feed at the pond dock and watch the ducks gather. Water the kitchen garden. Sit on the bench and move to stand up. Ring the village bell.

The blacksmith works at his anvil and the researcher reads at the pavilion. Their locations are present; purchasing, research, combat, and progression are intentionally deferred. Detailed resident schedules are also deferred. Your position and garden watering state are saved every 15 seconds and when returning to the main menu or quitting. Feeding remains a temporary activity. Continue restores the saved visit; New Game replaces it after confirmation.

The title screen orbits the live village. Options persist display mode, frame limit, VSync, 3D resolution scale, and volume. Defaults use 60 FPS and 85% 3D resolution while keeping the interface sharp. Fullscreen retains the screen aspect ratio, with the HUD anchored to its edges.

The traversal character is unarmed and uses the reused villager rig, extended with new pet, feed, water, and sit animations. It is a hub stand-in, not a finalized protagonist design.

## Sources and checks

- `art/hub/hub_library.blend`: reused editable architecture, scenery, and NPC source.
- `art/village/village_details.blend`: new ducks, tabby cat, dock, garden, watering can, and bell.
- `tools/village_details.py`: regenerate the new props.
- `tools/player_activities.py`: rebuild the hub character's added animations from the original rig.
- `docs/REUSED_ASSETS.md`: source provenance.
- `docs/STORY.md`: story direction.
- `docs/SYSTEMS.md`: progression requirements awaiting implementation.

```fish
./play.fish --headless -- --self-test
```

Native menu and fullscreen checks: `./play.fish -- --menu-test` (uses separate test saves/settings).

The runtime checks cover movement, interaction selection, imported animation clips, animal reactions, access paths, pond feeding, garden state, and bench exit. Visual captures can be generated locally with `./play.fish -- --capture`; these are not committed.
